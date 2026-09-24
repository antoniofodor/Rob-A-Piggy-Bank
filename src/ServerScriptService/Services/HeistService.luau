--!strict
--[[
	HeistService

	Stealing, carrying, tagging, and delivering loot.

	THE PIG IS THE WALLET, since the robbing pivot: everything a player has
	is in their piggy bank and all of it can be taken. Two things keep that
	from being a bullying simulator, and both are hard limits rather than
	discouragements. Config.LOSS_CAP bounds what a victim can lose in an
	hour, whoever is robbing them; and anything SPENT is gone from the pig
	and therefore permanently safe, so a robbery costs minutes of income and
	never a house or an upgrade. Eligible crate skins have separate theft rails.

	THE THIEF'S REWARD IS NOT THE VICTIM'S LOSS. A delivered haul is worth
	Config.HEIST_PAYOUT times what the victim lost (triple on revenge). Bail, the rap sheet
	and totalStolen all measure the victim's figure. Stolen coins land in the
	thief's own pig and are stealable in turn, so the loot stays in play.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SoundKit = require(ReplicatedStorage.Shared.SoundKit)
-- Only for `CarryPose.HOLD`. The pose itself is played on every client, off
-- the presence of the loot model; nothing about it runs on the server.
local CarryPose = require(ReplicatedStorage.Shared.CarryPose)
-- The money bag a thief carries is the Bigger Sack card's own model, so the
-- shop and the street draw one object. See `buildLootBag`.
local UpgradePreview = require(ReplicatedStorage.Shared.UpgradePreview)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local PiggyBank = require(script.Parent.PiggyBank)
local UpgradeService = require(script.Parent.UpgradeService)
local SocialService = require(script.Parent.SocialService)
local GuardDog = require(script.Parent.GuardDog)
-- For ownership and carried item grants. SetService requires DataService and nothing
-- else, so this cannot be a cycle.
local SetService = require(script.Parent.SetService)
-- FOR THE CATCH EFFECT AND NOTHING ELSE. Safe rather than a cycle:
-- CosmeticsService requires Config, Remotes, PlayerGear, DataService and
-- PlotService, none of which reaches back here.
local CosmeticsService = require(script.Parent.CosmeticsService)
-- The neighbours on every unclaimed plot. Requires DataService and
-- PlotService and nothing else -- in particular it does not require this
-- file, so the dependency runs one way only.
local ResidentService = require(script.Parent.ResidentService)
-- THE TROPHY SHELF, and it requires DataService and PlotService only --
-- which is what lets this file, GuardDog's catch path and the police all
-- reach it without a cycle anywhere.
local TrophyService = require(script.Parent.TrophyService)
local SeasonService = require(script.Parent.SeasonService)


local HeistService = {}

-- When each thief started holding a steal prompt, per victim plot.
--
-- The prompt's HoldDuration is one server-side property, but the real
-- required hold depends on the pair -- the victim's locks against the
-- thief's lockpicks. So the client shortens its own prompt for
-- responsiveness and the server times the hold itself and rejects anything
-- faster than that thief is entitled to. A client that sets HoldDuration to
-- zero gets a rejection, not free money.
-- WHICH PROMPT WAS BEING HELD, AND NOT ONLY WHICH PLOT.
--
-- A pig carries two entry prompts now -- steal on `E`, smash on `G` -- and
-- one record per thief cannot say which of them a hold belongs to. Without
-- the prompt here, beginning a smash hold and then completing a steal would
-- validate against the smash's own start time and duration: a 1.3s record
-- passed off as a 0.5s one, which is a real robbery started by the wrong
-- press. The two are on different keys and both are live at once, so a thief
-- with two fingers down is an ordinary thing rather than an exotic one.
local holdStarted: { [Player]: { plot: any, prompt: ProximityPrompt, at: number } } = {}
local HOLD_TOLERANCE = 0.2

-- ============================================================
-- WHO CAN BE ROBBED
-- ============================================================
--
-- A TARGET IS A PLAYER OR A RESIDENT, and everything below this line is
-- written against the pair rather than against `Player`.
--
-- This file was `victim: Player` from end to end, which meant the core
-- action of a game called Rob a Piggy Bank was only available when another
-- child happened to be standing on the street. `ResidentService` seats a
-- neighbour on every plot nobody lives on; this is what lets one be robbed.
--
-- THE TWO ARE NOT SYMMETRICAL AND THE ASYMMETRY IS THE POINT. A resident has
-- no `Config.LOSS_CAP` -- that cap exists so a real child cannot be emptied
-- by seven people taking turns, and there is nobody behind a resident to
-- protect. It holds no grudge, so no revenge marker points at an empty
-- house. It gets no notification, because nothing is reading them. Every one
-- of those differences is a rule about PEOPLE that has no meaning applied to
-- scenery, and each is handled at the one accessor that owns it rather than
-- by branching at the twenty call sites.
--
-- What is NOT different: the take, the hold, the carry, the getaway, the
-- dog, the tag, the patrol and the rap sheet. Robbing a resident is the same
-- robbery in every respect a player can feel.
type Target = Player | ResidentService.Resident

-- A Player is an Instance and a Resident is a plain table, so `typeof` is the
-- whole discriminator -- no flag to keep in step and nothing to get wrong.
local function asPlayer(target: Target): Player?
	return if typeof(target) == "Instance" then (target :: Player) else nil
end

local function asResident(target: Target): ResidentService.Resident?
	return if typeof(target) == "Instance" then nil else (target :: ResidentService.Resident)
end

local function targetName(target: Target): string
	local player = asPlayer(target)
	if player then
		return player.DisplayName
	end
	return (target :: ResidentService.Resident).name
end

-- The id the StealCooldown remote travels under, so a client can key its own
-- per-victim cooldown badge.
--
-- NEGATIVE PLOT INDEX FOR A RESIDENT. A real UserId is always positive, so
-- the two spaces can never collide, and it is stable across the resident
-- being re-seated -- which a table address would not be.
local function targetId(target: Target): number
	local player = asPlayer(target)
	if player then
		return player.UserId
	end
	return -(target :: ResidentService.Resident).plot.index
end

local function targetPlot(target: Target): any
	local player = asPlayer(target)
	if player then
		return PlotService.getPlot(player)
	end
	return (target :: ResidentService.Resident).plot
end

local function targetCoins(target: Target): number
	local player = asPlayer(target)
	if player then
		local data = DataService.get(player)
		return if data then data.coins else 0
	end
	return (target :: ResidentService.Resident).coins
end

-- What the target's pile reads as FULL on the lawn -- a readout, never a
-- limit. A player's pig has no ceiling (`Config.pigFullAt` is the rebirth
-- cash gate); a resident's is still `pigSeconds` of its own income.
local function targetFullAt(target: Target): number
	local player = asPlayer(target)
	if player then
		local data = DataService.get(player)
		return Config.pigFullAt(if data then data.rebirths else 0)
	end
	return ResidentService.getCapacity(target :: ResidentService.Resident)
end

-- WHICH PIGGY SKIN THE VICTIM IS WEARING, which is what the Victim Shelf
-- collects: one little pig per skin successfully robbed.
--
-- The tenth accessor, and it goes here for the reason the other nine do.
-- A resident keeps its own `skin` -- drawn from a shuffled bag when it is
-- seated, see `ResidentService` -- and a player's lives in their save, so
-- the asymmetry is one branch in one function rather than an `if` at the
-- call site. Branching there instead is how "is this a person" ends up in
-- twenty places and gets left out of the twenty-first.
local function targetSkin(target: Target): string?
	local player = asPlayer(target)
	if player then
		local data = DataService.get(player)
		return data and data.cosmetics and data.cosmetics.skin
	end
	return (target :: ResidentService.Resident).skin
end

-- The victim's Vault Lock level, which sets how long the hold is.
--
-- Read off the PLOT for a resident rather than from an upgrade record it
-- does not have. `PlotService.setLockLevel` publishes it there already,
-- because the client needs it to size its own prompt.
local function targetLockLevel(target: Target): number
	local player = asPlayer(target)
	if player then
		return UpgradeService.getLevel(player, "locks")
	end
	local plot = (target :: ResidentService.Resident).plot
	return (plot.model:GetAttribute(Config.PLOT_LOCK_ATTRIBUTE) :: number?) or 0
end

-- Silent for a resident. Nothing is reading it, and the alternative -- a
-- toast fired at nobody -- is the kind of call that quietly errors one day
-- when somebody adds a Player-typed field to the payload.
--
-- Deliberately does NOT call `notify` below: that is defined further down
-- this chunk, and a `local function` read from above it is a nil GLOBAL that
-- dies at the call naming nothing useful. Ninth time this project would have
-- hit that.
local function notifyTarget(target: Target, message: string, kind: string)
	local player = asPlayer(target)
	if player then
		Remotes.get("Notify"):FireClient(player, message, kind)
	end
end

-- Public, because `confiscate` hands a victim to PoliceService and it has to
-- be able to name one and speak to one without knowing which kind it is.
-- Exposing the two accessors is the alternative to teaching a second file
-- the same branch -- the near-identical copy that drifts.
HeistService.targetDisplayName = targetName
HeistService.notifyTarget = notifyTarget

-- Is this victim a real person? The one question outside this file that
-- genuinely needs the answer, rather than needing the branch.
function HeistService.isPlayerTarget(target: Target): boolean
	return asPlayer(target) ~= nil
end

-- ONE COSMETIC A ROBBERY IS BRINGING HOME, held rather than granted.
--
-- `victim` is who it came off, and it is what makes a LOSS honest: a thief
-- who is nabbed, arrested or killed has to give it back to the person they
-- took it from, exactly as the coins go back. A shop has nobody behind it, so
-- a shop's drop is simply gone -- which is the same asymmetry `lossAllowance`
-- already draws between a player and a resident.
type HotSkin = { expires: number, deadline: number, spare: boolean, reserved: boolean? }
type Grudge = {
	expires: number,
	skins: { [string]: HotSkin },
}

type Haul = {
	kind: string,
	key: string,
	victim: Player?,
	-- WHICH COPY WAS TAKEN, so giving it back gives back the same thing.
	-- A victim holding a spare loses the SPARE and goes on wearing the skin;
	-- one who was not insured loses the worn copy and reverts to the default.
	-- Returning the wrong one either duplicates a skin or leaves somebody
	-- wearing a skin they no longer own.
	spare: boolean?,
	wasWorn: boolean?,
	-- Recovery removes the stolen owned copy, bypassing ordinary insurance.
	-- The receipt restores the same hot claim if this getaway fails.
	hot: HotSkin?,
	recoveryOwner: Player?,
	loss: { since: number, lost: number }?,
}

type Carry = {
	claimant: Player, -- original grabber; preserved for the entire getaway
	holder: Player, -- player whose current character the loot is welded to
	kind: string?, -- nil is a legacy pig carry
	receipts: { any }?,
	amount: number,
	victim: Target,
	-- The mini piggy welded to the thief's chest. NOT the stolen items --
	-- see `haul`, and note the two nearly shared a name.
	loot: Model,
	-- WHAT IS COMING HOME BESIDES COINS, AND WHY IT IS CARRIED RATHER THAN
	-- GRANTED AT THE GRAB.
	--
	-- The skin steal shipped granting on the spot, which quietly made the one
	-- half of a robbery that is not coins immune to every risk the getaway
	-- exists to create. A thief could crack a pig, take somebody's Pearl skin
	-- and then walk into a guard dog with nothing to lose -- the run home is
	-- the risk half of the whole trade, and an item that was already yours is
	-- not in it.
	--
	-- Held here, the two halves of a haul are at stake together and the
	-- getaway is one decision rather than one decision and one formality.
	haul: { Haul },
	prompt: ProximityPrompt,
	-- WHETHER THEY ARE STANDING CLOSE ENOUGH TO THEIR OWN PIG TO DELIVER, and
	-- it lives on the carry record so the range poll can push on the EDGE
	-- rather than on every tick. Optional because a grab happens wherever the
	-- victim's pig is, which is never inside your own drop-off: nil and false
	-- mean the same thing and the first poll writes the real answer.
	inRange: boolean?,
	dropAction: string?,
	returnAvailable: boolean?,
	-- ALL FIVE SLICES LANDED. Stamped by `endCrack` on "done" and read by
	-- `deliver` for the Clean Sheet trophy -- on the delivery and never on the
	-- grab, for the reason every other count in this file is: loot nabbed out
	-- of your hands was never stolen. It used to pay the pig-crack acorn too,
	-- which went with the currency.
	clean: boolean?,
}

-- Construct only after attachment succeeds. Further slices/catches mutate this
-- record; they never assign a new claimant. Holder changes belong to handoff.
local function newCarry(grabber: Player, victim: Target, amount: number,
	loot: Model, prompt: ProximityPrompt, kind: string?, receipt: any?): Carry
	local carry: Carry = {
		claimant = grabber, holder = grabber, victim = victim, amount = amount,
		loot = loot, prompt = prompt, kind = kind, haul = {},
		receipts = if receipt then {receipt} else nil,
	}
	prompt.Triggered:Connect(function(nabber)
		HeistService.nab(nabber, carry.holder)
	end)
	return carry
end

-- Identity comes from the server carry, never the delivery request. The
-- claimant may have departed; their immutable identity still selects the rate.
local function canDeliverCarry(player: Player, carry: Carry): boolean
	return carry.holder == player and carry.claimant ~= nil
end

local carrying: { [Player]: Carry } = {}

-- ============================================================
-- THE OTHER THING A THIEF CAN BE CARRYING
-- ============================================================
--
-- `PiggyHaulService` owns lifting a piggy off a pedestal and carrying it
-- home. It is a whole separate haul: no amount, no victim balance, no loss
-- cap, no bail, no spree and no payout -- so it has none of the machinery
-- below and folding it into `Carry` would have meant branching `deliver`,
-- `nab`, `confiscate`, `dropAction`, `carryOptions` and `pushCarryState` on a
-- kind, which is six functions learning about an object none of them is
-- about.
--
-- WHAT IT CANNOT HAVE ITS OWN COPY OF IS THE RULES IN THIS FILE, and that is
-- the whole reason these two lines exist. `BASE_WALK_SPEED` is the number the
-- carry penalty, the dog's hearing, the getaway and every fence tier are
-- calibrated against, and a thief who could walk a stolen piggy home at full
-- speed on a scrambler would break all four at once. `haulingAnything` is
-- what makes "is this player carrying" one question with one answer, however
-- many kinds of thing there turn out to be.
--
-- REGISTERED RATHER THAN REQUIRED, the same shape as `SetService`'s pushers
-- and the trampoline's veto: `PiggyHaulService` requires THIS file, so asking
-- back would be a cycle. `Main` connects the two.
--
-- DECLARED HERE AND NOT BESIDE ITS REGISTRAR, which is the Luau forward
-- reference this project has lost more bugs to than anything else: a `local`
-- declared after a function that reads it is a nil GLOBAL to that function,
-- silently. `currentSpeed`, `whyCannotSteal` and the dog watcher all read
-- this and all sit above where the registration function naturally belongs.
local piggyHauling: ((Player) -> boolean)? = nil
local piggyNabbed: ((Player, Player, boolean?, string?) -> boolean)? = nil
local piggyConfiscated: ((Player) -> ())? = nil
-- WHICH PLOT a player's piggy haul was STOLEN from, or nil for an own piggy,
-- a lassoed catch or no haul at all. The lawn watcher asks it so a dog only
-- goes after its OWN yard's goods; see `stoleFrom`.
local piggyStolenFrom: ((Player) -> any?)? = nil

-- IS THIS PLAYER HOLDING ANYTHING THAT IS NOT THEIRS TO WALK OFF WITH? Coins
-- in a miniature pig, or a piggy off a plinth -- for every rule in this file
-- that is about the WEIGHT of a getaway rather than about money, they are the
-- same state and have to be asked as one.
local function haulingAnything(player: Player): boolean
	return carrying[player] ~= nil
		or (piggyHauling ~= nil and piggyHauling(player))
end

type Crack = {
	victim: Target,
	plot: any,
	sack: number,
	locks: number,
	picks: number,
	steps: number,
	banked: number,
	-- The pig and the allowance AS THEY WERE when the attempt opened. The
	-- gauge is drawn against these, so it cannot shift under the player
	-- while they are deciding whether to take one more.
	pig0: number,
	allowance0: number,
	stepStart: number, -- server time this sweep began
	zone: number,      -- 0..1 along the dial, the notch's resting place
	width: number,     -- 0..1
	sweep: number,     -- seconds per pass; the Vault Lock sets it
	drift: number,     -- how far the notch swings either side (Steel, Gold)
	spares: number,    -- misses the thief's Lockpicks will still forgive
	lastTap: number,
	ending: boolean,
}

local cracking: { [Player]: Crack } = {}

-- When each player's join shield lapses, in os.clock() seconds.
local shieldUntil: { [Player]: number } = {}

-- WHAT EACH VICTIM HAS LOST IN THE CURRENT WINDOW. Keyed per victim and never
-- per thief, because a per-thief cap is no protection when seven of them take
-- turns. `since` is when the window opened; it re-opens once
-- Config.LOSS_CAP.window has passed. See lossAllowance.
-- Residents never appear in here. See `lossAllowance`.
local losses: { [Target]: { since: number, lost: number, deadline: number } } = {}

-- HOW MANY SKINS EACH VICTIM HAS LOST IN THE CURRENT WINDOW, and it is the
-- same shape as `losses` directly above for the same reason: seven players
-- taking turns may not strip one child's collection, so the bound is on the
-- VICTIM and never on the thief. See `Config.SKIN_STEAL`, which carries the
-- argument for the whole feature.
local skinLosses: { [Player]: { since: number, lost: number } } = {}

-- Delivered theft opens a coin revenge window and, when applicable, a hot
-- skin claim. Spending the coin bonus does not erase an unexpired skin claim.
local grudge: { [Player]: { [Player]: Grudge } } = {}

local function isRevenge(thief: Player, victim: Target): boolean
	local entry = grudge[thief] and grudge[thief][victim :: Player]
	return entry ~= nil and entry.expires > os.clock()
end

local function recordGrudge(victim: Player, thief: Player, item: Haul?)
	local now = os.clock()
	grudge[victim] = grudge[victim] or {}
	local entry = grudge[victim][thief] or { expires = 0, skins = {} }
	entry.expires = now + Config.REVENGE.window
	-- Latest taker of THIS owner's skin wins. Unrelated skins, other owners
	-- and subsequent coin robberies never overwrite or extend a hot claim.
	if item then
		for _, older in pairs(grudge[victim]) do older.skins[item.key] = nil end
		entry.skins[item.key] = {
			expires = now + Config.REVENGE.window,
			deadline = workspace:GetServerTimeNow() + Config.REVENGE.window,
			spare = item.spare == true,
		}
	end
	grudge[victim][thief] = entry
end

-- A private view of the existing claims/haul, never a second recovery rule.
-- The client needs a wall-clock deadline because server os.clock() is local.
function HeistService.recoveryState(player: Player): any?
	local data = DataService.get(player)
	if not data then return nil end
	local now = os.clock()
	local season = Config.seasonIndex()
	local byKey: { [string]: any } = {}
	local priorities = { home = 1, chase = 2, recover = 3, buyback = 4 }
	local function offer(key: string, stage: string, robber: Player?, hot: HotSkin?, spare: boolean?)
		if not Config.isStealableSkin(key) then return end
		local owned = SetService.owns(data, "skin", key)
		-- Reacquiring an owned copy resolves its objective. An insured spare
		-- still has a real missing copy to recover even while the skin is worn.
		if owned and not spare then return end
		local cost = if not owned and data.claims and data.claims[key] == season
			then Config.buybackCost(key) else nil
		if stage == "buyback" and not cost then return end
		local row = { key = key, stage = stage, cost = cost,
			name = (if spare then "Spare " else "") .. Config.SKINS[key].name,
			robberId = if robber then robber.UserId else nil,
			robberName = if robber then robber.DisplayName else nil,
			expiresAt = if hot then hot.deadline else nil }
		local old = byKey[key]
		if not old or priorities[stage] < priorities[old.stage] then byKey[key] = row end
	end
	for key, index in pairs(data.claims or {}) do
		if index == season then offer(key, "buyback", nil, nil, false) end
	end
	for robber, entry in pairs(grudge[player] or {}) do
		local robberData = if robber.Parent then DataService.get(robber) else nil
		for key, hot in pairs(entry.skins) do
			if hot.expires > now and not hot.reserved and robberData
				and SetService.owns(robberData, "skin", key) then
				offer(key, "recover", robber, hot, hot.spare)
			end
		end
	end
	for carrier, carry in pairs(carrying) do
		if not carrier.Parent then continue end
		for _, item in ipairs(carry.haul) do
			if item.kind ~= "skin" then continue end
			if carrier == player and item.recoveryOwner == player then
				-- Once recovered it can be delivered even after the timer ends.
				offer(item.key, "home", item.victim, nil, item.hot and item.hot.spare)
			elseif item.victim == player and not item.hot then
				-- Theft precedes delivery: show the chase immediately, without
				-- pretending the ten-minute post-delivery window has started.
				offer(item.key, "chase", carrier, nil, item.spare)
			end
		end
	end
	local rows = {}
	for _, row in pairs(byKey) do table.insert(rows, row) end
	table.sort(rows, function(a, b) return a.key < b.key end)
	return { claims = rows, buybacksExpireAt = Config.seasonEndsAt() }
end

local objectiveLast: { [Player]: any } = {}
local objectiveReady: { [Player]: number } = {}
local function sameObjectives(a: any, b: any): boolean
	if not a or a.buybacksExpireAt ~= b.buybacksExpireAt or #a.claims ~= #b.claims then return false end
	for i, row in ipairs(a.claims) do
		local other = b.claims[i]
		for key, value in pairs(row) do if other[key] ~= value then return false end end
		for key, value in pairs(other) do if row[key] ~= value then return false end end
	end
	return true
end

local function pushObjectives(player: Player)
	local state = HeistService.recoveryState(player)
	if state and not sameObjectives(objectiveLast[player], state) then
		objectiveLast[player] = state
		Remotes.get("RecoveryObjective"):FireClient(player, state)
	end
end

local function startObjectives()
	-- Subscribe after connecting the client listener. This also repairs a
	-- late client start without a race against the initial player-data push.
	Remotes.get("RecoveryObjective").OnServerEvent:Connect(function(player)
		local now = os.clock()
		if objectiveReady[player] and now - objectiveReady[player] < 1 then return end
		objectiveReady[player] = now
		objectiveLast[player] = nil
		pushObjectives(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		objectiveLast[player] = nil
		objectiveReady[player] = nil
	end)
	task.spawn(function()
		while task.wait(0.25) do
			-- Ownership, disconnects and in-flight returns all flow through
			-- the existing tables. Emit only changes, not countdown packets.
			for player in pairs(objectiveReady) do pushObjectives(player) end
		end
	end)
end

-- [victim][thief] -> os.clock() of last grab, and count this session.
local lastGrab: { [Target]: { [Player]: number } } = {}

-- How long this player is protected for on this join. The long shield is
-- for a player's FIRST EVER SESSION and the short one for every later join --
-- see Config.JOIN_SHIELD for why fifteen minutes every time was a bug.
--
-- THE FIFTEEN-SECOND STUDIO OVERRIDE IS GONE, AND WHAT REMOVED IT WAS THE
-- REASON FOR IT CEASING TO BE TRUE.
--
-- It read: *a Studio playtest gets fifteen seconds either way: it would
-- otherwise spend its first minutes unable to rob anything.* That was
-- correct when the only robbable thing on the street was another player,
-- because a solo playtest then had no legal target at all and a real shield
-- made the whole system look broken.
--
-- Residents have no shield and every unclaimed plot has one, so a playtest
-- can rob from its first second regardless. The override now buys nothing
-- and costs something real: it means the one shield behaviour anybody ever
-- exercises in here is not the shield behaviour that ships. Same family as
-- every "works in Studio, refused live" entry in this project, pointed the
-- other way.
local function shieldSeconds(player: Player): number
	local data = DataService.get(player)
	if data and (data.sessions or 0) <= 1 then
		return Config.NEW_PLAYER_SHIELD
	end
	return Config.JOIN_SHIELD
end

-- YOUR SHIELD ENDS WHEN YOU TAKE SOMEBODY ELSE'S COINS.
--
-- The shield used to be a pure timer, and on a first session that timer was
-- ten minutes against sessions that run fifteen to twenty-five -- so a new
-- player spent essentially all of their first session unable to be robbed,
-- learned that this was an idle game, and then met the actual game on
-- session two as though it were a betrayal.
--
-- Tying it to the first robbery does three things a timer cannot. It TEACHES
-- THE RULE by being the rule: nobody can touch your piggy until you take
-- somebody else's. It makes the player CHOOSE the moment they become a
-- target, which is a fair trade rather than something that happens to them.
-- And it is self-clearing, so it needs no new save field and no flag that
-- can disagree with reality.
--
-- Fired on the GRAB rather than on the delivery. The grab is the moment you
-- decided to be a thief; whether you get home with it is the next question,
-- and a player who is robbed while carrying somebody else's coins is exactly
-- the situation this game is about.
local function dropShield(thief: Player)
	if (shieldUntil[thief] or 0) <= os.clock() then
		return
	end
	shieldUntil[thief] = 0
	-- The published copy too, or every badge in the server goes on saying
	-- PROTECTED over a plot that is now wide open.
	thief:SetAttribute(Config.PLAYER_SHIELD_ATTRIBUTE, 0)
	Remotes.get("Notify"):FireClient(thief,
		"You robbed somebody. Your piggy bank is fair game now.", "warn")
end

-- How much more a victim may lose right now under Config.LOSS_CAP.
--
-- Measured against what they HAD when the window opened -- the current
-- balance plus what has already gone -- so a pig cannot be emptied by inches
-- as each grab lowers the base the next one is measured against.
local function lossAllowance(victim: Target, balance: number): number
	-- A RESIDENT HAS NO CAP, AND THIS ONE LINE IS WHAT MAKES ROBBING THE
	-- PRIMARY INCOME POSSIBLE. `Config.LOSS_CAP` limits a victim to a quarter
	-- of their pig an hour, which -- multiplied out across eight players --
	-- caps ALL robbery in the game at roughly a tenth of what standing still
	-- earns. The cap is right and it protects a real child from being emptied
	-- by seven people taking turns. There is nobody behind a resident, so
	-- there is nothing to protect and no reason to hold the rate down.
	if not asPlayer(victim) then
		return math.max(0, math.floor(balance))
	end

	local now = os.clock()
	local entry = losses[victim]
	if not entry or now - entry.since > Config.LOSS_CAP.window then
		entry = { since = now, lost = 0, deadline = workspace:GetServerTimeNow() + Config.LOSS_CAP.window }
		losses[victim] = entry
	end
	local allowance = Config.LOSS_CAP.fraction * (balance + entry.lost) - entry.lost
	return math.max(0, math.floor(allowance))
end

-- Public street facts expose no claimant identities or private skin keys.
-- Reuse the same allowance and recovery snapshot as the actual actions.
function HeistService.streetState(): { [number]: any }
	local state: { [number]: any } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		state[player.UserId] = { cappedUntil = 0, hotUntil = 0 }
	end
	for _, player in ipairs(Players:GetPlayers()) do
		local entry = losses[player]
		if entry and targetCoins(player) >= 1 and lossAllowance(player, targetCoins(player)) <= 0 then
			state[player.UserId].cappedUntil = losses[player].deadline
		end
		local recovery = HeistService.recoveryState(player)
		for _, row in ipairs(if recovery then recovery.claims else {}) do
			local target = state[row.robberId]
			if target and row.stage == "recover" then target.hotUntil = math.max(target.hotUntil, row.expiresAt) end
		end
	end
	return state
end

local function startStreetState()
	task.spawn(function()
		while task.wait(0.25) do
			local state = HeistService.streetState()
			for _, plot in ipairs(PlotService.getAll()) do
				local row = plot.owner and state[plot.owner.UserId]
				plot.model:SetAttribute(Config.PLOT_CAPPED_ATTRIBUTE, if row then row.cappedUntil else 0)
				plot.model:SetAttribute(Config.PLOT_HOT_SKIN_ATTRIBUTE, if row then row.hotUntil else 0)
			end
		end
	end)
end

-- Coins that went home again -- a tag, a confiscation, a death -- were never
-- lost, so they come off the victim's window.
-- ============================================================
-- THE TUG
-- ============================================================
--
-- One tug per holder. Progress never moves currency; the full escrow moves
-- once at completion. Contributions choose an eligible winner without making
-- a crowd pull faster. Join order gives ties a stable, visible cause.
type Tug = {
	carry: Carry,
	nabbers: { [Player]: number },
	joined: { [Player]: number },
	joinCount: number,
	progress: number,
}
local tugs: { [Player]: Tug } = {}

-- WHEN A THIEF MAY BE NABBED AGAIN. Keyed on the THIEF rather than on the
-- nabber, which is the whole anti-swarm argument: a thrower cooldown is no
-- protection at all, because n players simply take turns.
local nabRest: { [Player]: number } = {}

local function refund(victim: Target, amount: number)
	-- A resident is never in `losses` at all, so this is already a no-op for
	-- one; the early return says so rather than leaving it to be inferred.
	local entry = losses[victim]
	if entry then
		entry.lost = math.max(0, entry.lost - amount)
	end
end

-- The one place a victim's balance changes because of a robbery. Repaints
-- the pile so the street sees it; the economy tick pushes the HUD.
--
-- IN FULL. The 4c.6 cap (returned coins filled only the room the pig had,
-- and the rest spilled) is reversed with the pig's ceiling: a pig holds
-- everything, so every returned coin goes back. Returns what was banked,
-- which is the whole amount.
local function notify(player: Player, message: string, kind: string)
	Remotes.get("Notify"):FireClient(player, message, kind)
end

local function giveBack(victim: Target, amount: number): number
	local resident = asResident(victim)
	if resident then
		-- Straight back into the pig it came out of, capped at that pig.
		-- ResidentService owns republishing the pile.
		return ResidentService.refund(resident, amount)
	end

	local player = victim :: Player
	local victimData = DataService.get(player)
	if not victimData then
		return 0
	end
	local banked = math.max(0, math.floor(amount))
	victimData.coins += banked
	refund(victim, amount)
	local plot = PlotService.getPlot(player)
	if plot then
		PlotService.updatePile(plot, victimData.coins, Config.pigFullAt(victimData.rebirths))
	end
	return banked
end

local GOLD = Color3.fromRGB(238, 194, 72)

-- WHAT A HAUL IS WORTH AT HOME, as the toast that ends a crack or a smash
-- says it. The same arithmetic `deliver` runs -- the payout and the spree --
-- so the number a thief decides to run for is the number they will bank if
-- nothing changes on the way. (It used to be capped at the room in the
-- thief's own pig and to say so; the pig has no ceiling now.) Returns the
-- phrase that follows "N coins, ".
local function homeWorthPhrase(thief: Player, victim: Target, amount: number): string
	local payout = (if isRevenge(thief, victim) then Config.revengePayout() else Config.HEIST_PAYOUT)
		* SocialService.getStarMultiplier(thief)
	local worth = math.floor(amount * payout)
	return ("worth %s at home"):format(Config.formatCoins(worth))
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- WHERE A VICTIM IS, whichever kind they are. Public for the same reason
-- `targetDisplayName` and `notifyTarget` are: a thrown gadget has to fly at
-- whoever is holding the coins, and it has no business knowing that a player
-- is found through their character while a resident carries its own walked
-- position.
--
-- Nil for a person with no character, which is a state a gadget in flight has
-- to be able to see -- it is what tells the arc that the thing it was aimed
-- at has gone.
--
-- IT LIVES HERE RATHER THAN WITH THE OTHER EIGHT ACCESSORS, and that is the
-- forward-reference trap rather than a filing choice. The accessor block sits
-- 190 lines above `getRoot`, and a `local function` read from above where it
-- is declared is not an error in Luau -- it compiles against a nil GLOBAL and
-- dies at the call naming nothing useful. Eleventh time this project would
-- have hit it, and the first one caught by looking at the line number rather
-- than by watching it fail.
function HeistService.targetPosition(target: Target): Vector3?
	local player = asPlayer(target)
	if player then
		local root = getRoot(player)
		return if root then root.Position else nil
	end
	return ResidentService.bodyAt(target :: ResidentService.Resident)
end

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- THE HAUL RIDES THE SAME PUSH AS THE COINS, as a second argument.
--
-- A nil/zero first argument has always meant "carrying nothing" and it still
-- does, so the banner's own logic is untouched. The list is what lets the HUD
-- say WHAT is being carried rather than only how much -- and the client spots
-- a NEW entry in it to fire the grab pop-up, which is the same trick the
-- crack's note ladder uses to see a slice land: the server sends state, and
-- an event is a state that went up.
local function returnCarryAmount(carry: Carry, amount: number)
	giveBack(carry.victim, amount)
end

-- ONE CARRY KIND NOW. There used to be two -- a stolen pig and an ACORN
-- BASKET shaken off somebody's tree -- and every function in this block
-- branched on which. The basket went with the acorn currency, so what is left
-- is the pig, measured to the plot's own base exactly as it always was.
local function carryNearHome(carry: Carry, plot: any, root: BasePart): boolean
	local target = plot.base
	if not target then return false end
	return (root.Position - target.Position).Magnitude <= Config.DROPOFF_RADIUS
end

local function returnPlot(carry: Carry): any?
	local victim = carry.victim
	local plot = targetPlot(victim)
	if not plot then return nil end
	local player = asPlayer(victim)
	if player then
		if not player.Parent or not DataService.get(player) or plot.owner ~= player then return nil end
	elseif plot.owner or ResidentService.get(plot) ~= victim then return nil end
	return plot
end

local function returnBounty(player: Player, carry: Carry): number
	-- A voluntary undo and an own harvest never mint a rescue reward.
	if player == carry.claimant or carry.claimant == carry.victim then return 0 end
	return math.floor(carry.amount * Config.NAB.bounty)
end

local function dropAction(player: Player, carry: Carry): string?
	if not canDeliverCarry(player, carry) or cracking[player] then return nil end
	local root, humanoid = getRoot(player), getHumanoid(player)
	if not root or not humanoid or humanoid.Health <= 0 then return nil end
	local destination = returnPlot(carry)
	-- THE ROBBER NEVER RETURNS THEIR OWN HAUL BY WALKING. Arriving is the
	-- delivery now, and a thief who has just cracked a pig is standing
	-- inside its ring -- so a return here would hand every robbery straight
	-- back. A return is for whoever took the loot OFF the robber.
	if destination and carry.claimant ~= player and carryNearHome(carry, destination, root) then return "return" end
	-- Recovering your own haul is always a return, never a keep payout.
	if carry.victim == player then return nil end
	local home = PlotService.getPlot(player)
	if home and carryNearHome(carry, home, root) then return "keep" end
	return nil
end

local function carryOptions(player: Player, carry: Carry): any
	local original = carry.claimant == player
	local ownReturn = carry.victim == player
	local worth
	if not original then worth = math.floor(carry.amount * Config.NAB.keepShare)
	else
		local payout = if isRevenge(player, carry.victim) then Config.revengePayout() else Config.HEIST_PAYOUT
		worth = math.floor(carry.amount * payout * SocialService.getStarMultiplier(player))
	end
	-- WHERE THE RINGS GO. The client draws a glowing ring on each place
	-- arriving would settle the haul, centred on the exact part
	-- `carryNearHome` measures from, so the ring and the rule are one circle.
	local function ringAt(plot: any?): any?
		if not plot or not plot.base then return nil end
		local target = plot.base
		local size = (plot.base :: any).Size
		return { at = target.Position,
			ground = if size then plot.base.Position.Y + size.Y / 2 else target.Position.Y }
	end
	local homeRing = if ownReturn then nil else ringAt(PlotService.getPlot(player))
	local returnRing = if original and not ownReturn then nil else ringAt(returnPlot(carry))
	return {
		action = dropAction(player, carry), canKeep = not ownReturn,
		homeRing = homeRing, returnRing = returnRing,
		canReturn = returnPlot(carry) ~= nil,
		victim = targetName(carry.victim), ownReturn = ownReturn,
		keepWorth = worth, bounty = returnBounty(player, carry),
	}
end

local function pushCarryState(player: Player)
	local carry = carrying[player]
	Remotes.get("CarryUpdate"):FireClient(player,
		if carry then math.floor(carry.amount) else 0,
		if carry then carry.haul else nil,
		if carry then carry.inRange == true else false,
		if carry then carry.kind or "pig" else nil,
		nil, false,
		if carry then carryOptions(player, carry) else nil)
end

-- ============================================================
-- ELIGIBILITY
-- ============================================================

-- Returns nil if the grab is allowed, or a player-facing reason if not.
-- Every one of these is re-checked server-side on the trigger; the client
-- only decides which prompt to draw.
-- IS THE THIEF INSIDE THE SHOP THEY ARE ROBBING? See
-- `Config.shopRoomHolds` for why a distance cannot answer this.
local function inShopRoom(thief: Player, plot: any): boolean
	local root = getRoot(thief)
	return root ~= nil and Config.shopRoomHolds(plot.cframe, root.Position)
end

local function whyCannotSteal(thief: Player, victim: Target): string?
	if (thief :: any) == victim then
		return "That's your own piggy."
	end
	if haulingAnything(thief) then
		return "You're already carrying stolen goods. Take it home first."
	end

	local name = targetName(victim)

	-- A SHIELD IS A FACT ABOUT A PERSON. A resident has none and can never
	-- have one: the shield exists to give a child time to learn the controls
	-- before anybody is allowed to take anything from them.
	local victimPlayer = asPlayer(victim)
	local shieldRemaining = (if victimPlayer then shieldUntil[victimPlayer] or 0 else 0) - os.clock()
	if shieldRemaining > 0 then
		return if shieldRemaining >= 60
			then ("%s is still protected for %d min."):format(name, math.ceil(shieldRemaining / 60))
			else ("%s is still protected for %ds."):format(name, math.ceil(shieldRemaining))
	end

	-- The per-victim cooldown applies to a resident too -- it is what stops a
	-- thief standing on one lawn farming the same pig, and that is as true of
	-- an empty house as of a real one -- but a resident's is SHORTER, because
	-- the rest of what this cooldown does is protect a victim and there is
	-- nobody there to protect. See `RESIDENTS.stealCooldown`: it is what keeps
	-- the robbing advantage flat as the street fills up.
	local last = (lastGrab[victim] and lastGrab[victim][thief]) or -math.huge
	local wait = Config.stealCooldownFor(asResident(victim) ~= nil) - (os.clock() - last)
	if wait > 0 then
		return ("Wait %ds before robbing %s again."):format(math.ceil(wait), name)
	end

	local coins = targetCoins(victim)
	if math.floor(coins) <= 0 then
		return ("%s piggy is empty."):format(Config.possessive(name))
	end

	-- The loss cap, named. A cap the thief cannot see reads as stealing being
	-- broken, and this is the one refusal that is about the VICTIM's hour
	-- rather than the thief's own cooldown.
	if lossAllowance(victim, coins) <= 0 then
		return ("%s has been robbed enough for now."):format(name)
	end

	return nil
end

-- WHY THIS PLAYER MAY NOT TAKE A PIGGY OFF THAT PLAYER'S PLINTH, or nil.
--
-- A SEPARATE QUESTION FROM `whyCannotSteal` AND DELIBERATELY A SHORTER ONE.
-- Most of that function is about the PIG: is there anything in it, has the
-- victim already lost their hour's worth, and the per-victim coin cooldown.
-- None of those is about an object standing on a plinth, and answering them
-- here would refuse a snatch because somebody's COINS were low -- two
-- unrelated robberies sharing one gate.
--
-- WHAT IT DOES SHARE IS THE SHIELD, and that is not a convenience. A player
-- whose first session has not ended yet may not be robbed, full stop -- and
-- being robbed of one of the seven things they own outright is strictly
-- worse than losing a slice of a pile that refills on its own. A second
-- answer to "is this person protected" is exactly the kind of second
-- implementation that drifts, and the one that drifts is always the one
-- nobody is testing.
--
-- `PiggyHaulService` OWNS ITS OWN COOLDOWN because it is a different clock
-- about a different thing: `Config.PIGGY_HAUL.victimCooldown` bounds how
-- often one lawn may be picked over, and folding it in here would have made
-- a coin crack and a snatch share a timer they have no reason to share.
function HeistService.whyCannotSnatch(thief: Player, victim: Player): string?
	if thief == victim then
		return "That's your own piggy."
	end
	local shieldRemaining = (shieldUntil[victim] or 0) - os.clock()
	if shieldRemaining > 0 then
		local name = victim.DisplayName
		return if shieldRemaining >= 60
			then ("%s is still protected for %d min."):format(name, math.ceil(shieldRemaining / 60))
			else ("%s is still protected for %ds."):format(name, math.ceil(shieldRemaining))
	end
	return nil
end

-- AND THE SHIELD COMES OFF ON A SNATCH EXACTLY AS IT DOES ON A CRACK.
--
-- *Nobody can touch your piggy until you take somebody else's* is the whole
-- rule, and it stops being true the moment there are two ways to take
-- somebody else's and only one of them ends your own protection. Exposed
-- rather than copied, so there is one definition of what dropping it means
-- and one notification saying so.
HeistService.dropShield = dropShield

-- ============================================================
-- CARRY VISUALS
-- ============================================================

-- Hands the thief a miniature of the VICTIM's piggy, wearing the victim's own
-- skin, held out in front of them where everyone can see it.
--
-- This used to be an abstract glowing ball floating over the thief's head.
-- Carrying somebody's actual piggy makes a chase legible from across the
-- street: you can see who is being robbed, not just that someone is running.
-- THE LOOT IS A BAG OF COINS, NOT A LITTLE PIG (designer decision
-- 2026-09-22). While the pig itself was what you took, a miniature of the
-- victim's pig was the honest picture; a thief cracks the bank for COINS now
-- and carries those home, and the pedestal piggies -- the things that ARE
-- carried off as themselves -- have their own snatch carry in
-- PiggyHaulService. The bag is the Bigger Sack card's own model at the
-- thief's own sack level, so a bigger sack is visibly a bigger bag on the
-- street and the shop and the getaway draw one object.
--
-- Named `Config.LOOT_MODEL_NAME` so `CarryPose` poses whoever carries it,
-- and stamped `Config.CARRY_KIND_ATTRIBUTE` = "sling" so the pose is the
-- SACK'S -- over the right shoulder, one-handed, the left arm left to the run
-- (designer, 2026-09-23) -- where a hauled piggy is hugged in both arms. Its
-- sack part is renamed `Body` and the model pivoted on it so the weld, the
-- trail and the nab prompt seat on it exactly as they did on the mini,
-- and every part unanchored and massless because an anchored part welded to
-- a humanoid pins the humanoid. The card's parts are anchored and loose;
-- here they are welded to the sack. A missing builder degrades to an empty
-- model and `attachLoot` refuses the carry rather than welding nothing.
local function buildLootBag(sackLevel: number): Model
	local bag = UpgradePreview.build("sack", sackLevel) or Instance.new("Model")
	bag.Name = Config.LOOT_MODEL_NAME
	bag:SetAttribute(Config.CARRY_KIND_ATTRIBUTE, "sling")
	local body = bag:FindFirstChild("Bag")
	if body and body:IsA("BasePart") then
		body.Name = "Body"
		-- THE PIVOT IS THE BODY'S CENTRE WITH NO ROTATION, AND DELIBERATELY NOT
		-- THE BODY AS PRIMARYPART. `PivotTo` writes the PrimaryPart's CFrame
		-- outright, rotation included -- so with the mesh bag (every part of
		-- which carries the importer's half turn, `Config.LOOT_MESH.rot`) the
		-- cloth would lose its turn on the first `PivotTo` while its coins and
		-- bow kept theirs: the mesh pig's eyes-in-its-rump bug and the alien
		-- saucer's, a third time. A WorldPivot at the body's centre seats the
		-- same point `CarryPose.HOLD` was measured against and moves every
		-- part rigidly. `lootBodyOf` finds the body by NAME.
		bag.WorldPivot = CFrame.new(body.Position)
	end
	for _, part in ipairs(bag:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Massless = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			if body and part ~= body then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = body
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
	return bag
end

local function lootBodyOf(loot: Model?): BasePart?
	if not loot then
		return nil
	end
	return loot.PrimaryPart or PiggyBank.lootBody(loot)
end

local function attachLoot(thief: Player, victim: Target, amount: number, kind: string?): (Model?, ProximityPrompt?)
	local root = getRoot(thief)
	if not root then
		return nil, nil
	end

	local loot: Model = buildLootBag(UpgradeService.getLevel(thief, "sack"))
	local body = lootBodyOf(loot)
	if not body then
		loot:Destroy()
		return nil, nil
	end

	-- WHERE IT SITS IS `CarryPose`'S TO DECIDE, NOT THIS FILE'S, because the
	-- thief is now posed HOLDING it and the two are one measurement: the arms
	-- were swept on a live rig, the hands were read back in root space, and
	-- `HOLD` is where a pig has to be for those hands to be on it. A number
	-- typed here would be a second opinion about the same thing, and the pose
	-- would lose -- an arm cannot reach a position somebody chose for it.
	--
	-- WELDED TO THE HAND (designer, 2026-09-23), so the sack moves with the
	-- arm rather than the arm sliding against a sack pinned to the root.
	-- `CarryPose.anchor` picks the part and the seat -- the right hand and
	-- its hand-space offset on an R15 rig, the root and `HOLD` otherwise --
	-- so this service and the piggy haul can never disagree about which limb
	-- carries. The offset is in the HAND'S frame, so it is right wherever the
	-- hand happens to be at the moment of the grab and settles with the pose.
	local anchor, seat = CarryPose.anchor(root.Parent, "sling")
	anchor = anchor or root
	loot:PivotTo(anchor.CFrame * seat)
	loot.Parent = root.Parent

	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0 = anchor
	weld.Part1 = body
	weld.Parent = body

	local trail = Instance.new("ParticleEmitter")
	trail.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	trail.Color = ColorSequence.new(GOLD)
	trail.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.8),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Lifetime = NumberRange.new(0.4, 0.8)
	trail.Rate = 20
	trail.Speed = NumberRange.new(0.5, 2)
	trail.SpreadAngle = Vector2.new(180, 180)
	trail.Acceleration = Vector3.new(0, -10, 0)
	trail.LightEmission = 0.8
	trail.Parent = body

	-- NAMED, because the figure on it is no longer written once. A crack
	-- banks a slice at a time and this label has to keep up, so something has
	-- to be able to find it -- the rule the rebirth panel's four `Frame`s
	-- already cost this project once.
	local label = Instance.new("BillboardGui")
	label.Name = "LootLabel"
	label.Size = UDim2.new(0, 170, 0, 40)
	-- ADORNED TO THE THIEF, NOT TO THE SACK. It rode a shoulder 1.31 studs
	-- off the centre line for a day, where a label hung off it orbited the
	-- thief as they turned -- `StudsOffset` is world-axis and cannot pull
	-- one back to centre. The hug is back and the load is centred again, so
	-- this could ride the body; it stays on the root so the next pose change
	-- cannot move it. The root is where the reader expects a
	-- name to sit; 2.5 above it is the height the label has always rendered
	-- at (root y 2.49 on the hug), clear of the head at 1.82 and under the
	-- character's own Roblox nameplate. It stays parented to the body so it
	-- lives and dies with the loot and `LootLabel` is still found there.
	label.Adornee = root
	label.StudsOffset = Vector3.new(0, 2.5, 0)
	label.AlwaysOnTop = true
	label.Parent = body

	local text = Instance.new("TextLabel")
	text.Name = "Amount"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = GOLD
	text.TextStrokeTransparency = 0.2
	-- Names the owner, so a bystander knows whose side to take.
	text.Text = ("%s coins  %s"):format(Config.possessive(targetName(victim)), Config.formatCoins(amount))
	text.Parent = label

	-- WHOSE COINS THESE ARE, published on the thief for the one player who is
	-- entitled to be told. See `Config.CARRY_VICTIM_ATTRIBUTE` for why this
	-- replaced a Highlight and what it costs.
	--
	-- Nil for a resident or a shop, deliberately: nobody's base is being
	-- robbed, so there is nobody to mark it for, and writing an id nobody
	-- matches would be a signal that can never fire.
	local owner = asPlayer(victim)
	thief.Character:SetAttribute(Config.CARRY_VICTIM_ATTRIBUTE,
		if owner then owner.UserId else nil)

	-- Anyone nearby can tag, not just the victim. Bystanders joining the
	-- chase is the bit that turns a robbery into a story.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "NabPrompt"
	prompt.ActionText = "Nab Thief!"
	Config.setPromptKind(prompt, "nab")
	prompt.ObjectText = thief.DisplayName
	prompt.HoldDuration = Config.NAB.hold
	prompt.MaxActivationDistance = Config.NAB.distance
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	return loot, prompt
end

-- Multiplier from a fence snag, expiring on its own.
local snagged: { [Player]: { multiplier: number, until_: number, stunUntil: number? } } = {}

local function isStunned(player: Player): boolean
	local snag = snagged[player]
	return snag ~= nil and snag.stunUntil ~= nil and os.clock() < snag.stunUntil
end

-- Set by RideService, and only while every one of its gates is open. 1 means
-- on foot.
--
-- The dependency runs one way on purpose. This module owns every speed in the
-- game and must not have to know what a skateboard is; RideService owns the
-- gates and pushes a number in. Requiring each other would be a cycle, and
-- the cycle would be the thing that eventually let a ride multiplier survive
-- into a chase.
local rideMultiplier: { [Player]: number } = {}

-- Who is currently sneaking. Declared HERE, above `currentSpeed`, rather than
-- beside the function that toggles it: a `local` read by a function defined
-- above it is a nil GLOBAL in Luau, which does not error and dies later
-- naming nothing useful. This project has lost nine bugs to that and every
-- piece of shared state in this file lives at the top because of it.
local tiptoeing: { [Player]: boolean } = {}

-- Dodge windows. Two of them, because the burst of speed is shorter than the
-- immunity it buys: the roll ends but you stay untouchable for the tail of it,
-- which is what makes a dodge feel like it worked rather than like it was
-- half a frame too early.
local dodgeUntil: { [Player]: number } = {}
local dodgeImmuneUntil: { [Player]: number } = {}
local lastDodge: { [Player]: number } = {}

-- A SHORT TAPERING BURST OF SPEED, pushed in from outside.
--
-- The wheelie bin hands one out when somebody vaults out of it. It lives here
-- rather than in StealthService for the reason the ride multiplier does: this
-- module owns every speed in the game and there must be exactly one place
-- they are combined. See Config.BINS.exitBurst.
--
-- Declared with the dodge state and above currentSpeed, because that is what
-- reads it. Luau binds a name where a function is WRITTEN, so a `local` below
-- a reader is silently a nil global -- six bugs and counting.
local burst: { [Player]: { peak: number, until_: number, span: number } } = {}

-- Cannot be nabbed, caught or hit right now.
function HeistService.isDodgeImmune(player: Player): boolean
	return os.clock() < (dodgeImmuneUntil[player] or 0)
end

-- ON A TRELLIS RIGHT NOW. Asked of the humanoid rather than tracked in a
-- table, because the engine owns this state and a table would be a second
-- copy of it that can disagree -- the same reason `RidePose` asks the animator
-- what it is playing instead of remembering.
local function isClimbing(player: Player): boolean
	local humanoid = getHumanoid(player)
	return humanoid ~= nil
		and humanoid:GetState() == Enum.HumanoidStateType.Climbing
end

-- IS THE TIPTOE ACTUALLY IN EFFECT, as opposed to merely asked for?
--
-- Pulled out of `currentSpeed` because it acquired a SECOND reader: the
-- animation. `Config.SNEAK_ATTRIBUTE` is published off this so that every
-- client can draw the creep, and the two must never be able to disagree --
-- a character drawn tiptoeing while moving at full walk speed is the same
-- class of bug as the resident pigs that published one number and held
-- another, where the world and the server disagreed silently and the server
-- was right.
--
-- CARRYING IS ALLOWED NOW, AND THAT REVERSES THIS FILE'S OLD RULE ON
-- PURPOSE: *you sneak IN and you never sneak the money OUT*.
--
-- The arithmetic that rule rested on is unchanged and is still the whole
-- point: a tiptoe multiplies the carry penalty, so 12 x 0.35 is 4.2 studs a
-- second, comfortably under every dog's `notice`. What changed is the
-- DESIGN -- creeping home is now the intended getaway, and the price is TIME
-- rather than noise: the 53-stud run home is about 12.6 seconds at a sneak
-- against 4.4 at a carry-run, which is long enough for the owner, the
-- patrol, or a neighbour with a gadget to arrive. So a thief chooses between
-- being quick and loud (chased) or slow and quiet (unheard), which is a
-- decision where there used to be none.
--
-- NEVER WHILE CLIMBING, because two slows multiplied produce a number nobody
-- designed: 0.35 x CLIMB_MULTIPLIER 0.35 is 0.12, about two studs a second,
-- or seven seconds to climb an eight-stud fence. That is the
-- multiplicative-slow trap this project keeps recording, and a ladder is not
-- somewhere anybody is being stealthy anyway. A climb starts and ends without
-- anybody pressing anything, which is why this cannot be computed once where
-- the button lands.
--
-- NEVER WHILE RIDING, AND THAT IS THE SAME TRAP ONE SIZE UP. A tiptoe is a
-- multiplier on `currentSpeed` and so is a ride, so the two compose into a
-- number nobody designed: 16 x 2.1 x 0.35 is 11.8 studs a second, which is a
-- Volt Scrambler moving SLOWER than a player on foot. Nothing about that is
-- what either purchase was sold as -- a sneak is for crossing somebody's lawn
-- unheard and there are no dogs on the street, and a ride is switched off
-- everywhere a sneak is worth having (`Config.isOnStreet`).
--
-- BELT AND BRACES RATHER THAN THE GUARD: `setTiptoe` refuses a sneak while a
-- ride is on and `setRideMultiplier` drops one when a ride begins, so this
-- term cannot fire today. It is here because a mount is AUTOMATIC -- you leave
-- your gate and you are on it -- which is the same reason the climb is checked
-- here rather than where the button lands, and because the two curves
-- multiplying is exactly the failure this project keeps recording.
local function tiptoeInEffect(player: Player): boolean
	return tiptoeing[player] == true
		and not isClimbing(player)
		and rideMultiplier[player] == nil
end

local function currentSpeed(player: Player): number
	-- A shock stops you dead. It outranks everything else, including boots.
	if isStunned(player) then
		return 0
	end

	local speed = Config.BASE_WALK_SPEED
	-- A PIGGY UNDER ONE ARM WEIGHS WHAT A PIG FULL OF COINS DOES. The carry
	-- penalty is the entire risk half of a getaway, so the one thing a second
	-- kind of haul may not do is arrive without it.
	if haulingAnything(player) then
		speed *= UpgradeService.getCarryMultiplier(player)
	end
	local snag = snagged[player]
	if snag and os.clock() < snag.until_ then
		speed *= snag.multiplier
	end
	speed *= rideMultiplier[player] or 1

	-- TIPTOE, which multiplies the carry penalty rather than being refused
	-- alongside it -- see `tiptoeInEffect` for why that reversed.
	if tiptoeInEffect(player) then
		speed *= Config.getTiptoeMultiplier(UpgradeService.getLevel(player, "tiptoe"))
	end

	-- CLIMBING IS A MULTIPLIER LIKE EVERYTHING ELSE HERE, which is the whole
	-- reason the climb needed no balance code of its own. Roblox climbs a
	-- truss at a fixed fraction of WalkSpeed and tracks it live, so scaling
	-- the walk scales the climb -- and every rule above this line comes with
	-- it: a stun has already returned 0 and freezes a climber where they are,
	-- carrying scales the climb off 12 rather than 16, and a fence snag slows
	-- the climb it was earned on.
	--
	-- Above the dodge and the burst deliberately. Both of those are written to
	-- multiply whatever is left, and a dodge is refused mid-climb anyway --
	-- there is nothing to roll off a wall into.
	if isClimbing(player) then
		speed *= Config.CLIMB_MULTIPLIER
	end
	-- Last, so it multiplies whatever is left after the carry penalty and any
	-- snag rather than replacing them. A dodge is proportional to how fast you
	-- were already going, which is what keeps it from being a way out of a
	-- defence somebody paid for.
	if os.clock() < (dodgeUntil[player] or 0) then
		speed *= Config.DODGE.multiplier
	end

	-- TAPERS to nothing rather than ending on a cliff, which is what keeps it
	-- slight: the mean excess is half the peak, so the ground a burst actually
	-- buys is half what a flat multiplier of the same size would. It sits
	-- alongside the dodge rather than replacing it -- both are proportional to
	-- whatever speed was already left after the carry penalty and any snag.
	local b = burst[player]
	if b then
		local left = (b.until_ - os.clock()) / b.span
		if left > 0 then
			speed *= 1 + (b.peak - 1) * left
		end
	end
	return speed
end

local function refreshSpeed(player: Player)
	local humanoid = getHumanoid(player)
	if humanoid then
		humanoid.WalkSpeed = currentSpeed(player)

		-- `UseJumpPower` HAS TO BE OFF OR THE LINE BELOW IS DECORATION, and it
		-- was on -- so writing JumpHeight here has never once changed a jump.
		--
		-- A Humanoid exposes two jump controls and obeys exactly one of them.
		-- With `UseJumpPower` true, which is the rig default, `JumpPower`
		-- governs and `JumpHeight` is stored and ignored. Measured on a live
		-- character: JumpHeight 5.50, JumpPower 50, apex 7.27 studs.
		--
		-- IT HID BECAUSE THE DEFAULT HAPPENED TO MATCH. JumpPower 50 is about
		-- a 7.27-stud apex and `BASE_JUMP_HEIGHT` was 7.2, so the number the
		-- fence tiers were tuned against was right by coincidence while the
		-- code that was supposed to set it did nothing at all.
		--
		-- The second half is the one that mattered before today: the stun has
		-- always dropped JumpHeight to zero and a stunned thief has always
		-- been able to jump anyway. The comment that used to sit here said
		-- "WalkSpeed 0 alone still lets a stunned thief hop the fence they
		-- just got shocked by" -- correct, and describing what actually
		-- shipped rather than what this line prevented.
		humanoid.UseJumpPower = false
		humanoid.JumpHeight = if isStunned(player) then 0 else Config.BASE_JUMP_HEIGHT

		-- AND THE SNEAK IS PUBLISHED IN THE SAME BREATH AS THE SPEED IT
		-- DESCRIBES, which is this project's own rule about the resident pigs
		-- arriving somewhere new: anything that changes a thing has to
		-- republish it in the same breath, or the world and the server drift
		-- apart silently and the server is right.
		--
		-- Here rather than in `setTiptoe` because THIS is the function every
		-- edge already calls -- the button, a grab, a snag, a mount, a stun,
		-- and both edges of a climb. Written where the button lands instead,
		-- a player who grabbed a ladder would go on being drawn creeping up it.
		--
		-- Cleared to nil rather than set false so a character carries the
		-- attribute only while it is true, and a respawn starts clean.
		local character = humanoid.Parent
		if character then
			character:SetAttribute(Config.SNEAK_ATTRIBUTE, tiptoeInEffect(player) or nil)
		end
	end
end

local function setCarrySpeed(player: Player, _carryingLoot: boolean)
	refreshSpeed(player)
end

-- WHERE THE PIGGY HAUL PLUGS IN. `Main` calls this once; nothing else does.
--
-- Three questions rather than one, because they are asked by three different
-- kinds of caller and only the first is asked often: `hauling` is read by
-- every speed, ride and dog rule in this file, `nabbed` is the seam every
-- catcher in the game already comes through, and `confiscated` is the
-- patrol's. Registering them together is what stops two of the three being
-- wired and the third being found months later by somebody being arrested
-- and keeping the loot.
function HeistService.registerPiggyHaul(
	hauling: (Player) -> boolean,
	nabbed: (Player, Player, boolean?, string?) -> boolean,
	confiscated: (Player) -> (),
	stolenFrom: ((Player) -> any?)?)
	piggyHauling, piggyNabbed, piggyConfiscated = hauling, nabbed, confiscated
	piggyStolenFrom = stolenFrom
end

-- A HAUL STARTING OR ENDING IS A SPEED CHANGE, and `refreshSpeed` is a local
-- in here that owns every rule that decides one. Exposed rather than
-- duplicated: a second implementation of the carry penalty is the one thing
-- `haulingAnything` exists to prevent.
function HeistService.haulChanged(player: Player)
	refreshSpeed(player)
end

-- ============================================================
-- RIDES
-- ============================================================

-- Why this player may not be on their ride right now, or nil if they may.
--
-- Every one of these is a system that BASE_WALK_SPEED is calibrated against,
-- and a ride multiplier laid over any of them breaks it:
--
--   * carrying -- the getaway is 37 studs at 12 studs/sec, which is the
--     entire risk half of a robbery. At 33.6 it is a second and a half.
--   * being robbed -- a defender on a scrambler catches every thief in the
--     game, which kills the offence tree.
--   * snagged or stunned -- the fence charges a toll in speed, and a ride
--     must not be a way to pay it off.
--
-- Returns a reason rather than a boolean because the player has to be able to
-- see why their board vanished. A rejection nobody can see is indistinguish-
-- able from a bug, which is how the silent-steal failure survived for weeks.
function HeistService.rideBlockReason(player: Player): string?
	-- NOT "stolen goods": a haul is also your own piggy on its way to a
	-- plinth, or a wild piggy you just lassoed.
	if haulingAnything(player) then
		return "Can't ride while your arms are full. Take it home first."
	end

	-- NOBODY rides while loot is in transit, not just the two players
	-- involved.
	--
	-- Blocking only the victim left a hole big enough to drive a scrambler
	-- through: any BYSTANDER could stay mounted at 33.6 and run down a thief
	-- doing 12, and HeistService.nab lets anyone nab. That is not a chase, it
	-- is an execution, and it made robbery in a busy server pointless.
	--
	-- Server-wide is also the version that reads as a rule rather than as a
	-- restriction: when the alarm goes, the whole street is on foot. A carry
	-- lasts only a few seconds, so the cost is small and the drama is free.
	if HeistService.anyoneCarrying() then
		if carrying[player] then
			return "Can't ride while you're carrying stolen goods."
		end
		for _, carry in pairs(carrying) do
			if carry.victim == player then
				return "Can't ride while you're being robbed. Go nab them."
			end
		end
		return "Someone's being robbed. Everybody's on foot."
	end

	if isStunned(player) then
		return "Can't ride while you're stunned."
	end
	local snag = snagged[player]
	if snag and os.clock() < snag.until_ then
		return "Can't ride while you're snagged."
	end

	return nil
end

-- ============================================================
-- DODGE
-- ============================================================

-- Returns seconds until the next dodge is available, for the HUD.
function HeistService.dodgeCooldownLeft(player: Player): number
	local ready = (lastDodge[player] or -math.huge) + Config.DODGE.cooldown
	return math.max(0, ready - os.clock())
end

local function pushDodge(player: Player)
	Remotes.get("DodgeState"):FireClient(player, HeistService.dodgeCooldownLeft(player))
end

function HeistService.dodge(player: Player)
	local humanoid = getHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	-- Every refusal says so. A control that silently does nothing is
	-- indistinguishable from a broken one, and this is the one input a player
	-- will press at the exact moment they most need to know why it failed.
	if isStunned(player) then
		notify(player, "You're stunned. You can't dodge.", "warn")
		return
	end

	-- You do not roll off a moving scrambler. Also stops a dodge multiplying a
	-- ride's 33.6 into something absurd; rides are already off during a heist,
	-- so nothing about a chase is affected either way.
	if rideMultiplier[player] then
		notify(player, "Not while you're riding.", "warn")
		return
	end

	if HeistService.isHidden(player) then
		notify(player, "Not from inside a bin. Use CLIMB OUT first.", "warn")
		return
	end

	local left = HeistService.dodgeCooldownLeft(player)
	if left > 0 then
		return
	end

	local now = os.clock()
	lastDodge[player] = now
	dodgeUntil[player] = now + Config.DODGE.duration
	dodgeImmuneUntil[player] = now + Config.DODGE.immunity
	refreshSpeed(player)
	-- Publishes the fact of a dodge and nothing else. Every client plays
	-- the roll on this character itself, the same shape as animated skins:
	-- the animation is registered per client as a hash:// id, which cannot
	-- replicate, and the defender needs to see the roll that just cost them
	-- their tag hold.
	--
	-- A counter rather than a boolean, so two dodges in a row are two
	-- distinct changes. A flag set true twice fires one signal.
	local character = player.Character
	if character then
		character:SetAttribute("DodgeRoll", (character:GetAttribute("DodgeRoll") or 0) + 1)
	end
	pushDodge(player)

	-- Speed comes back on its own. Everything else that touches WalkSpeed goes
	-- through refreshSpeed too, so whatever else is true by then -- a snag
	-- landing mid-roll, the loot being dropped -- is recomputed rather than
	-- overwritten.
	task.delay(Config.DODGE.duration + 0.02, function()
		refreshSpeed(player)
	end)

	-- THE PUSH OUT OF THE ROLL, on the frame the feet come back under the
	-- body. Asked again at that moment rather than decided now: a player who
	-- was stunned, nabbed, climbed into a bin or got on a ride during the
	-- roll has not "got up" into a sprint, so they get nothing.
	local getUpBurst = Config.DODGE.getUpBurst
	task.delay(Config.DODGE.rollSeconds * Config.DODGE.getUpAt, function()
		if player.Parent and not isStunned(player) and not rideMultiplier[player]
			and not HeistService.isHidden(player) then
			HeistService.giveBurst(player, getUpBurst.peak, getUpBurst.seconds)
		end
	end)
end

-- Called by RideService and nobody else. 1 means on foot.
-- Start or stop sneaking. The server decides whether it is allowed; the
-- client only asks.
--
-- ALLOWED WHILE CARRYING, and that refusal being here was the other half of
-- the rule `tiptoeInEffect` reversed: creeping home with the pig in your arms
-- is the quiet getaway now, paid for in time rather than refused. The button
-- and the speed agree because both go through `tiptoeInEffect`.
function HeistService.setTiptoe(player: Player, on: boolean)
	local want = on == true

	-- NOT WHILE RIDING, for the reason `tiptoeInEffect` gives: a sneak and a
	-- ride are both multipliers on one speed, and a scrambler creeping along
	-- at 11.8 studs a second is neither of the things a player bought.
	--
	-- LOUD, AND IT SHOULD NEVER BE HEARD. The client hides the SNEAK button
	-- and suppresses C while a ride is on, so this is the client declining to
	-- ask for a known no -- the same split the dodge, the number row and the
	-- dodge-while-riding suppression already make. The refusal is here anyway
	-- because the server owns this state and a remote exists for everybody:
	-- a rejection nobody can see is indistinguishable from a broken button.
	--
	-- Only a turn-ON is refused. `setRideMultiplier` drops an active sneak
	-- through this same function, and a refusal that caught that call would
	-- leave the flag set under a ride that has just started.
	if want and rideMultiplier[player] then
		notify(player, "Not while you're riding.", "warn")
		return
	end

	if want == (tiptoeing[player] == true) then
		return
	end
	tiptoeing[player] = want or nil
	refreshSpeed(player)
	-- Pushed back, always. The server can drop this without being asked, so
	-- the client must never be the thing that decides what it currently is.
	Remotes.get("TiptoeState"):FireClient(player, want)
end

function HeistService.isTiptoeing(player: Player): boolean
	return tiptoeing[player] == true
end

function HeistService.setRideMultiplier(player: Player, multiplier: number)
	local value = if multiplier > 1 then multiplier else nil
	if rideMultiplier[player] == value then
		return
	end
	rideMultiplier[player] = value

	-- A MOUNT DROPS THE SNEAK, WHICH IS THE CALL THE HELD ITEM ALREADY MAKES.
	-- `RideService.mount` puts away whatever is in your hand and NAMES it
	-- ("You put that away to ride."), because a prop leaving a player's own
	-- fist with nothing said reads as having lost the item. A mode switching
	-- itself off is the same thing: mounting is automatic, so a player who set
	-- a sneak on their lawn and wandered onto the street would otherwise find
	-- it gone for no reason they could see.
	--
	-- HERE RATHER THAN IN `RideService.mount`, which is where the held item's
	-- put-away sits: this is the one function every ride goes through -- its
	-- own comment says "called by RideService and nobody else" -- so a future
	-- mount path cannot forget it. Dropped rather than left inert so the state
	-- the client is holding is never one the hidden button cannot correct.
	--
	-- `rideMultiplier` is written ABOVE this deliberately, so the refusal
	-- inside `setTiptoe` is already true and the `refreshSpeed` it runs
	-- computes against the ride that has just begun rather than the sneak that
	-- has just ended.
	if value and HeistService.isTiptoeing(player) then
		HeistService.setTiptoe(player, false)
		notify(player, "You stopped sneaking to ride.", "warn")
	end

	refreshSpeed(player)
end

-- Someone crossed a defence the hard way -- over the fence, or through the
-- moat -- instead of walking round to the gate. Costs them speed for a few
-- seconds, and on the top tiers a dead stop first. That is the whole point of
-- the hurdle: the fast route stays available, it just leaves you crawling and
-- lit up on someone's lawn.
--
-- Takes a penalty rather than a fence tier, because the moat charges a
-- different toll from the wire above it.
--
-- Stacking is deliberately "take the worst", not multiply -- clipping three
-- zone parts on one vault shouldn't triple the penalty.
--
-- Factored out so gadgets can charge the same toll through the same state.
-- One slow table means the "take the worst, never multiply" rule holds
-- across BOTH sources for free -- a thief who catches a plunger on the way
-- over an electric fence gets the harsher of the two, not the product, which
-- would be a dead stop nobody could have seen coming.
local function applySlow(player: Player, penalty: any)
	local existing = snagged[player]
	local now = os.clock()

	local multiplier = penalty.slow
	local stunUntil = now + (penalty.stun or 0)
	local until_ = now + penalty.duration
	if existing and now < existing.until_ then
		multiplier = math.min(multiplier, existing.multiplier)
		stunUntil = math.max(stunUntil, existing.stunUntil or 0)
		-- THE END TIME IS PART OF "TAKE THE WORST", and it was not: until_
		-- used to be reset unconditionally, so a SHORT penalty landing on a
		-- long one CUT THE LONG ONE SHORT. Harmless while every source lasted
		-- roughly the same time, and an exploit the moment a 0.9s joke could
		-- be thrown at anybody -- a friend lobbing a plunger at a thief
		-- crawling off an electric fence would have wiped three seconds of
		-- that snag and handed them their speed back.
		until_ = math.max(until_, existing.until_)
	end

	snagged[player] = {
		multiplier = multiplier,
		until_ = until_,
		stunUntil = stunUntil,
	}
	refreshSpeed(player)

	if (penalty.stun or 0) > 0 then
		-- Speed is restored by the expiry pass below; this only needs to lift
		-- the zero-speed, zero-jump window.
		task.delay(penalty.stun + 0.05, function()
			refreshSpeed(player)
		end)
	end

	task.delay(penalty.duration + 0.05, function()
		local snag = snagged[player]
		if snag and os.clock() >= snag.until_ then
			snagged[player] = nil
			refreshSpeed(player)
		end
	end)
end

function HeistService.applyFencePenalty(player: Player, _plot: any, penalty: any)
	applySlow(player, penalty)

	if (penalty.stun or 0) > 0 then
		notify(player, ("The %s shocked you!"):format(penalty.label), "bad")
	else
		notify(player, ("Snagged on the %s!"):format(penalty.label), "warn")
	end
end

-- ============================================================
-- GADGETS
-- ============================================================

-- Is anybody in this server carrying loot right now?
--
-- Used by RideService: while a robbery is live, NOBODY rides. See
-- rideBlockReason for why that has to be server-wide rather than just the two
-- players involved.
function HeistService.anyoneCarrying(): boolean
	for _ in pairs(carrying) do
		return true
	end
	return false
end

-- The nearest thief carrying loot, within `range` of `from`.
--
-- Returns the reason it found nobody, so a refusal can name it -- but ONLY
-- for a carrier who is out of RANGE. "Nobody is robbing anyone" used to be
-- the other half of this and is now dropped, because it is no longer a reason
-- to refuse anything: with the aim open, an empty street still leaves every
-- neighbour standing on it as a valid target. Left in, it surfaced as the
-- refusal for a throw that had simply found nobody nearby -- measured, a
-- plunger thrown in an empty solo server came back "Nobody is running off
-- with anything right now", which is true, irrelevant, and reads as the item
-- refusing to work.
--
-- A reason that stops being a reason has to be DELETED, not left to be
-- outranked. It was still the first one found, so it still won.
--
-- Tried FIRST, ahead of the drone and ahead of the prank, so nothing about a
-- real chase changed when the aim was opened up: a gadget is still the answer
-- to somebody running off with your coins, and it only looks around for
-- somebody to prank when there is nobody in range to actually stop.
-- AND A CARRYING NEIGHBOUR IS A CARRIER, WHICH IT WAS NOT UNTIL NOW.
--
-- This swept `carrying`, which is keyed by Player, so the whole gadget tree
-- was blind to residents -- and residents are most of the thieves on this
-- street. A neighbour who had just emptied your pig could be walked up to and
-- TAGGED and could not be hit by a plunger, a bubblegum or a zapper from a
-- foot away. That is three purchases that visibly do nothing against the
-- commonest robbery in the game, which is the silent-failure rule wearing a
-- price tag.
--
-- Returning a `Target` rather than a Player is the same widening
-- `attemptSteal` already made, and it finds the same class of assumption on
-- the way out: everything downstream that said `Player` had to be asked
-- whether it meant "a person" or "whoever is holding the coins".
function HeistService.nearestCarrier(from: Vector3, range: number, thrower: Player): (Target?, string?)
	local best, bestDist
	local anyCarrier = false

	for thief in pairs(carrying) do
		if thief ~= thrower then
			local root = getRoot(thief)
			if root then
				-- Counted at ANY distance, so "they got away from you" can
				-- still be told apart from there being no robbery on -- and
				-- only the first of those is a refusal any more.
				anyCarrier = true
				local dist = (root.Position - from).Magnitude
				if dist <= range and (not bestDist or dist < bestDist) then
					best, bestDist = thief, dist
				end
			end
		end
	end

	-- Residents second, and compared on the SAME distance so a person and a
	-- neighbour standing side by side are picked between by who is actually
	-- closer rather than by which loop ran first.
	--
	-- `ResidentService.nearestCarrier` clamps to the range itself and hands
	-- back the distance, so a resident out of range simply does not appear --
	-- which means it cannot set `anyCarrier` and cannot turn "nobody nearby"
	-- into "too far" for a street where the only carrier is across the map.
	-- That is the honest reading: a neighbour halfway down the road is not
	-- somebody you were about to hit.
	local resident, residentDist = ResidentService.nearestCarrier(from, range)
	if resident then
		anyCarrier = true
		if not bestDist or residentDist < bestDist then
			best, bestDist = resident, residentDist
		end
	end

	if best then
		return best, nil
	end
	if anyCarrier then
		return nil, "Too far. Get closer to them."
	end
	return nil, nil
end

-- IN A BIN, pushed in by StealthService for the same reason the ward is: this
-- module cannot require the one that owns the state without making a cycle.
--
-- IT LIVES UP HERE, ABOVE nearestBystander, because that function reads it
-- to skip somebody who is hiding. Luau binds a name where the function is
-- WRITTEN rather than where it is called, so a `local` declared below a
-- reader is silently a nil GLOBAL -- and this file has now lost six bugs to
-- exactly that, every one of them dying somewhere that named neither the
-- variable nor the cause.
--
-- Somebody inside a wheelie bin may do exactly one thing, which is climb out.
-- No items, no prompts, no dodge. The client suppresses all of it so nobody
-- meets these refusals in normal play -- they are here because a remote
-- exists for every player whether or not their HUD offered them the button,
-- which is the same reason the admin console is authorised on the server.
local inBin: { [Player]: boolean } = {}

function HeistService.setHidden(player: Player, on: boolean)
	inBin[player] = if on then true else nil
end

function HeistService.isHidden(player: Player): boolean
	return inBin[player] == true
end

-- WHEN EACH PLAYER IS OPEN TO A GADGET AGAIN. The one number that keeps an
-- open aim from being a harassment toy, and it is keyed by the person being
-- HIT rather than by the thrower: a thrower cooldown would be no protection
-- at all, since six players with plungers would simply take turns and the
-- child in the middle would never get to move.
--
-- IT CARRIES THE WHOLE PROTECTION NOW, where it used to carry half of it.
-- The other half was a capped duration and a capped stun, and both are gone
-- -- see Config.GADGET_GUARD for what that bought and what it cost.
--
-- AN EXPIRY RATHER THAN A TIMESTAMP, because the rest a hit earns is derived
-- from that gadget's own duration (`Config.gadgetRest`). Stored the other way
-- round this table would also have to remember WHICH gadget landed in order
-- to know when somebody was free again, which is a second fact that can
-- disagree with the first.
local hitRestUntil: { [Player]: number } = {}

function HeistService.canHit(player: Player): boolean
	local until_ = hitRestUntil[player]
	return until_ == nil or os.clock() >= until_
end

-- The nearest player who is NOT carrying anything, for a gadget with nobody
-- to stop. Second choice after a carrier, third after a raid drone.
--
-- Anybody still cooling down from the last one is SKIPPED rather than
-- returned, so a throw lands on somebody else instead of being spent on a
-- refusal -- and `cooling` is remembered separately so the refusal, when
-- there is nothing else in range, can say which of the two things happened.
-- "Nobody is close enough" and "you only just hit them" are completely
-- different situations to a player standing in the street.
function HeistService.nearestBystander(from: Vector3, range: number, thrower: Player): (Target?, string?)
	local best: Target? = nil
	local bestDist: number? = nil
	local cooling = false

	for _, other in ipairs(Players:GetPlayers()) do
		-- Somebody in a wheelie bin is invisible and anchored, so a gadget
		-- sailing across the street to hit one would be the tell that gives
		-- their hiding place away.
		if other ~= thrower and not carrying[other] and not inBin[other] then
			local root = getRoot(other)
			local dist = if root then (root.Position - from).Magnitude else math.huge
			if dist <= range then
				if HeistService.canHit(other) then
					if not bestDist or dist < bestDist then
						best, bestDist = other, dist
					end
				else
					cooling = true
				end
			end
		end
	end

	-- AND A NEIGHBOUR WITH EMPTY ARMS, who takes a gadget as a player does.
	local resident, residentDist = ResidentService.nearestIdle(from, range)
	if resident and (not bestDist or residentDist < bestDist) then
		best, bestDist = resident, residentDist
	end

	if best then
		return best, nil
	end
	if cooling then
		return nil, "Give them a moment. They have only just been hit."
	end
	return nil, nil
end

-- Is this player carrying loot right now?
--
-- Public because the disguise has to break the instant somebody picks loot
-- up: the run home is the risk half of the entire trade and has to stay
-- visible, and StealthService cannot see this table.
function HeistService.isCarrying(player: Player): boolean
	return haulingAnything(player)
end

-- Raincoats, set by StealthService. A warded thief shrugs off the two cheap
-- gadgets; the Zapper still lands.
--
-- The dependency runs one way, the same as the ride multiplier: this module
-- owns the effect and StealthService pushes a flag in. Requiring each other
-- would be a cycle, and the cycle is what would eventually let a ward survive
-- something it was never meant to stop.
local warded: { [Player]: boolean } = {}
local wardUsedHandlers: { (Player, any) -> () } = {}

-- Fired after a steal actually succeeds, so PoliceService can decide whether
-- there is a patrol out to notice it.
--
-- Declared up here rather than beside the function that fires it: a `local`
-- declared AFTER a function that reads it silently becomes a nil global in
-- Luau, and this project has lost three bugs to exactly that. attemptSteal is
-- eighty lines below.
--
-- A hook rather than a require, for the same reason StealthService pushes its
-- flags in here instead of being read out: HeistService must not know what a
-- patrol is. It owns the loot; everyone else subscribes.
-- The victim may be a resident, so subscribers get a Target. PoliceService
-- is the only one, and it stores it on the alarm and hands it back to
-- `confiscate` -- neither of which needs to know which kind it is.
local stealHandlers: { (Player, Target, number) -> () } = {}

-- WHO TO TELL WHEN A SHOP HANDS OVER A CONSUMABLE.
--
-- `data.consumables` is one flat count table shared by four services, and
-- each of them pushes its own slice of it to the client -- so a drop that
-- wrote the count and told nobody would land a Golden Bone in a save and
-- leave the hot bar showing none until the next purchase. Asking those
-- services directly is a cycle: `GadgetService` requires this one.
--
-- Filled in by `Main`, which is the same shape `SetService.registerPusher`
-- uses and for the same reason -- it keeps this file's dependency list at
-- what it actually needs and makes the cycle impossible rather than merely
-- absent today.
local stockPushers: { (Player) -> () } = {}

function HeistService.registerStockPusher(fn: (Player) -> ())
	table.insert(stockPushers, fn)
end

function HeistService.onSteal(handler: (Player, Target, number) -> ())
	table.insert(stealHandlers, handler)
end

-- Hands a player a tapering speed burst for `seconds`.
--
-- Re-applying replaces rather than stacks, and never shortens: two sources
-- landing together give the better of the two, not the sum. Stacking is how a
-- multiplier on the one number every other speed here is measured against
-- turns into a way to outrun the whole game.
--
-- The taper has to be re-evaluated every frame, and refreshSpeed is only
-- called on events -- so a burst runs its own short loop and stops when it
-- expires. One player, about two seconds, and nothing to clean up if they
-- leave in the middle of it: the loop checks the table it is driven by.
function HeistService.giveBurst(player: Player, peak: number, seconds: number)
	local now = os.clock()
	local existing = burst[player]
	local live = existing ~= nil and now < existing.until_
	if existing and live then
		-- Against what the running one is worth RIGHT NOW, not its original
		-- peak: a burst two thirds spent is a small multiplier, and treating
		-- it as its opening value would let a second one inherit speed the
		-- first had already given back.
		peak = math.max(peak, 1 + (existing.peak - 1) * ((existing.until_ - now) / existing.span))
		seconds = math.max(seconds, existing.until_ - now)
	end

	burst[player] = { peak = peak, until_ = now + seconds, span = seconds }
	refreshSpeed(player)

	-- Only one loop, however many times this is called.
	if live then
		return
	end
	task.spawn(function()
		while true do
			local b = burst[player]
			if not b or os.clock() >= b.until_ then
				break
			end
			refreshSpeed(player)
			RunService.Heartbeat:Wait()
		end
		burst[player] = nil
		refreshSpeed(player)
	end)
end

function HeistService.setWard(player: Player, on: boolean)
	warded[player] = if on then true else nil
end

function HeistService.isWarded(player: Player): boolean
	return warded[player] == true
end

-- Fired when a ward actually absorbs something, so the HUD and the stock can
-- be updated by whoever owns them.
function HeistService.onWardUsed(handler: (Player, any) -> ())
	table.insert(wardUsedHandlers, handler)
end

-- Holds a player still for a moment, through the same state a fence stun uses.
--
-- Public because the patrol needs it and writing WalkSpeed directly would not
-- do: `isStunned` is what refuses a dodge, drops JumpHeight to zero and makes
-- currentSpeed return 0 before anything else is even considered. A hand-rolled
-- freeze would be a second kind of "held still" that none of those knew about
-- -- which would let a caught thief dodge out of being caught.
function HeistService.detain(player: Player, seconds: number)
	applySlow(player, { label = "Detained", slow = 1, duration = seconds, stun = seconds })
end

-- Charges a gadget's toll. Same state as a fence snag, different message.
--
-- ONE HIT LIVES IN HERE NOW AND THERE USED TO BE TWO. A target CARRYING LOOT
-- took the real thing and anybody else took a PRANK -- a fraction of the
-- duration, a capped stun, and the raincoat never even looked at it.
--
-- That branch is gone. The EFFECT is the same for everybody and what differs
-- is only how OFTEN it may land: a carrier can be hit again as fast as
-- somebody can throw, because being stopped mid-robbery is the entire point
-- of the item, and anybody else earns a rest afterwards. See
-- Config.GADGET_GUARD for why the protection moved off the effect and onto a
-- per-target cooldown, and Config.GADGETS for what leaving it where it was
-- had been costing: a defender standing on their own lawn while a friend
-- cracked their pig could be hit and could not be affected, so there was no
-- way for two children to rob a house together.
--
-- WHAT IS STILL DECIDED HERE RATHER THAN AT THE THROW is which state the
-- target is in when it arrives, and that is what keeps it honest across the
-- flight: somebody who picks loot up mid-flight is hit as a carrier, and a
-- thief who gets home first is hit as an ordinary player and gets the rest
-- that comes with it. Neither end can time their way around it.
--
-- THE SECOND RETURN IS WHETHER THE EFFECT LANDED. True/false above means
-- "was this throw used up"; a dodge and a raincoat both use it without the
-- effect happening, and GadgetService only draws a splat, a knockdown or
-- sparks when it did.
-- WHAT A WHOLE STREET MAY DO TO ONE CHILD, and it is a bound that did not
-- exist until a neighbour could throw.
--
-- `hitRestUntil` bounds gadget hits on somebody with EMPTY HANDS and
-- deliberately does not bound a CARRIER -- "being stopped mid-robbery is the
-- entire point of the item". That is right for a player throwing and wrong for
-- scenery: a thief fleeing a robbed neighbour is carrying BY DEFINITION, so
-- with no bound of its own, several neighbours landing several hits hold one
-- child at `max(until_)` continuously. `applySlow` stops hits STACKING and
-- does nothing about them CHAINING.
--
-- Keyed to the THIEF and never to the thrower, which is the shape
-- `Config.GADGET_GUARD` already uses and for the same reason: the bound on
-- what an entire street can do to one player has to be the same bound as what
-- one neighbour can do, however many of them are out.
local neighbourRest: { [Player]: number } = {}

-- A NEIGHBOUR'S THROW LANDING. Deliberately NOT `applyGadget`: that function
-- needs a Player thrower for its root, its display name and its notifies, and
-- three of its endings are about refunding a thrower's stock. Scenery has no
-- inventory to refund and nobody to tell.
--
-- IT CAN ONLY EVER SLOW THE THIEF IT WAS AIMED AT. The flight tests against
-- that one player and nothing else, so a neighbour cannot clip a bystander --
-- which is the harassment surface this game refuses everywhere, and refusing
-- it in the flight rather than in a guard means there is no case to get wrong.
function HeistService.neighbourHit(thief: Player, spec: any, name: string): boolean
	if not getRoot(thief) or inBin[thief] then
		return false
	end
	if os.clock() < (neighbourRest[thief] or 0) then
		return false
	end
	-- Before the coat, so a well-timed dodge does not burn a perfectly good one
	-- that was never needed. Same order `applyGadget` keeps below.
	if HeistService.isDodgeImmune(thief) then
		notify(thief, ("Dodged %s %s!"):format(Config.possessive(name), spec.name), "good")
		return false
	end
	if warded[thief] and not spec.pierce then
		warded[thief] = nil
		for _, handler in ipairs(wardUsedHandlers) do
			task.spawn(handler, thief, spec)
		end
		notify(thief, ("The %s slid off your raincoat!"):format(spec.name), "good")
		return false
	end
	neighbourRest[thief] = os.clock() + Config.NEIGHBOUR_CHASE.restAfterHit
	applySlow(thief, {
		label = spec.name,
		slow = spec.slow,
		duration = spec.duration,
		stun = spec.stun,
	})
	-- NAMED, because an unexplained wobble with nobody attached to it reads as
	-- lag rather than as the neighbour you just robbed. The prank tone, not the
	-- chase one: this costs a thief seconds and never the haul.
	notify(thief, ("%s threw a %s at you!"):format(name, spec.name), "prank")
	return true
end

function HeistService.applyGadget(target: Target, thrower: Player, spec: any): (boolean, boolean)
	-- A CARRYING NEIGHBOUR TAKES THE COINS BACK AND NOTHING ELSE, and the
	-- three things it does NOT do are each a rule from somewhere else in this
	-- file arriving here.
	--
	-- No SLOW and no STUN, because a resident has no Humanoid: it is a posed
	-- rig the server walks, so `applySlow` has nothing to write to and the
	-- whole speed system this gadget is expressed in does not reach it.
	-- And nothing at all when their arms are empty, for the same reason
	-- rather than for a second one: what a gadget does to a PERSON who is not
	-- carrying is a full slow, and a slow is the speed system a resident is
	-- not in either.
	--
	-- So what is left is exactly the outcome a TAG produces, through the same
	-- function the tag prompt calls: the coins go back to whoever they came
	-- from and the thrower is told what they recovered. That makes a gadget a
	-- tag AT RANGE against a neighbour, which is the honest shape -- and it
	-- keeps the standing rule that tagging recovers the loot, so a gadget is
	-- still setup rather than the terminal action.
	--
	-- Returning FALSE when there is nothing in their arms refunds the throw,
	-- which is the same answer this function already gives for a person who
	-- delivered mid-flight: an item spent on nothing is indistinguishable
	-- from an item that is broken.
	-- A NEIGHBOUR TAKES THE SAME HIT, through their own walker. See
	-- `ResidentService.applyGadget`: slowed, frozen or knocked flat by the
	-- same numbers, with the loot kept until somebody nabs it. Where it came
	-- from is the thrower's position, so a knockdown falls the right way.
	local resident = asResident(target)
	if resident then
		local throwerRoot = getRoot(thrower)
		local from = if throwerRoot then throwerRoot.Position else ResidentService.bodyAt(resident)
		local landed = ResidentService.applyGadget(resident, spec, from)
		return landed, landed
	end

	local player = target :: Player

	-- Gone, dead, or hiding in a bin: the throw is refunded rather than
	-- landing on nobody.
	if not getRoot(player) or inBin[player] then
		return false, false
	end

	-- Checked BEFORE the raincoat, so a well-timed dodge does not burn a
	-- perfectly good coat that was never needed.
	if HeistService.isDodgeImmune(player) then
		notify(player, ("Dodged the %s!"):format(spec.name), "good")
		notify(thrower, ("%s dodged it."):format(player.DisplayName), "warn")
		return true, false
	end

	-- A RAINCOAT STOPS THE SLOWS AND NOTHING ELSE, and it is asked here --
	-- above the carrying branch -- rather than inside it, which reverses
	-- where this check used to live.
	--
	-- Same shape as the Guard Duty Treat on the other side of this fight:
	-- cheap counters bounce, the expensive one gets through. It raises the
	-- price of stopping somebody from 1,500 to 22,000 rather than making them
	-- unstoppable, which is the only version that leaves both trees alive.
	--
	-- IT USED TO SIT INSIDE `carrying` ON PURPOSE, and the reason was good
	-- while it was true: "letting a 1,500-coin joke burn one would turn the
	-- cheapest item in the game into a way of stripping the defence off
	-- somebody who was not even robbing anybody yet." The joke is not a joke
	-- any more. A hit on somebody with empty arms is now the full slow, so a
	-- coat blocking it is a coat doing exactly the job it was sold for, and
	-- spending it is the honest price.
	--
	-- THE ITEM'S OWN SHOP COPY IS WHAT SETTLES IT. The Raincoat's `detail`
	-- reads "Stays on until something bounces" -- so a coat that blocked a
	-- gadget and survived would make a line a player has already read into a
	-- lie, which is the failure this project keeps finding as copy that
	-- outlived the thing it described.
	-- `pierce` rather than "has no stun": the plunger stuns now too, since
	-- it knocks you down, and the stun test would have let it through.
	if warded[player] and not spec.pierce then
		warded[player] = nil
		for _, handler in ipairs(wardUsedHandlers) do
			task.spawn(handler, player, spec)
		end
		notify(player, ("The %s slid off your raincoat!"):format(spec.name), "good")
		notify(thrower, ("%s was wearing a raincoat. It bounced off."):format(player.DisplayName), "warn")
		return true, false
	end

	if haulingAnything(player) then
		applySlow(player, {
			label = spec.name,
			slow = spec.slow,
			duration = spec.duration,
			stun = spec.stun or 0,
		})

		notify(player, spec.hit or ("Hit by a %s!"):format(spec.name), "warn")
		return true, true
	end

	-- NOT CARRYING ANYTHING, AND IT IS THE SAME HIT. The only thing that
	-- separates this from the branch above is the REST it earns.
	--
	-- Re-tested here and not only at the throw, because the flight is long
	-- enough for somebody else's to have landed first -- and two people
	-- freezing one player back to back is the exact thing this stops.
	if not HeistService.canHit(player) then
		return false, false
	end

	-- STAMPED BEFORE THE SLOW, so a throw that lands in the same frame as
	-- another one cannot find this player still open.
	hitRestUntil[player] = os.clock() + Config.gadgetRest(spec.duration)

	applySlow(player, {
		label = spec.name,
		slow = spec.slow,
		duration = spec.duration,
		stun = spec.stun or 0,
	})

	-- NAMES THE THROWER, which the carrier's version deliberately does not.
	-- Being hit while running off with somebody's coins explains itself;
	-- being stopped in the street with empty arms does not, and an
	-- unexplained freeze with nobody attached to it reads as lag. It is also
	-- the only credit a helper ever gets -- the person who was held knows who
	-- held them.
	local line = if spec.prank
		then (spec.prank):format(thrower.DisplayName)
		else ("%s got you with a %s!"):format(thrower.DisplayName, spec.name)
	notify(player, line, "prank")
	return true, true
end

-- Clears the carry state and returns what was being carried, or nil.
-- ============================================================
-- THE CRACK -- THE GREED DIAL
-- ============================================================
--
-- WHAT IT REPLACED WAS A TRANSACTION. A steal was one fixed hold that took
-- one fixed fraction, performed identically forty times an hour -- and the
-- hold is the one moment in this game where the game switches itself OFF.
-- Every tuned number in this file is a SPEED, and the central action of the
-- game named after it was standing still.
--
-- A crack is a sequence of slices. Each one landed banks a bigger share of
-- the pig than the last and narrows the zone for the next. The thief walks
-- away whenever they like and keeps what they have; a miss ends it and they
-- STILL keep what they have. So it is push-your-luck rather than a
-- checklist, and it is the first thing in this design that can produce a
-- PARTIAL outcome -- "I bailed at three because the dog turned round" --
-- which is what makes a repeated action generate stories instead of
-- receipts.
--
-- COINS LEAVE THE PIG PER SLICE, NOT AT THE END, and that is the decision
-- everything else here follows from. Banking a promise and settling up
-- afterwards would let two thieves cracking one pig both be promised the
-- same coins -- the exact double-spend the old code's "taken from the pig
-- immediately" comment exists to prevent -- and it would leave the pile on
-- the lawn frozen through the whole robbery. Taken per slice, the coin pile
-- visibly DRAINS while the thief works, which is the greed bar drawn in the
-- world rather than only on their screen.
--
-- THE SERVER OWNS THE CLOCK AND THE CLIENT OWNS NOTHING. `CrackTap` carries
-- no arguments: the sweep is deterministic from `stepStart`, which is
-- stamped in `workspace:GetServerTimeNow` so both ends read one clock, and
-- the server works out where the marker really was when the tap landed.
--
-- WHAT THAT BUYS IS FAIRNESS, NOT SECURITY, and it is worth being exact
-- because it looks like an anti-cheat. The best possible outcome of a
-- perfectly forged client is landing every slice -- which is also what a
-- good player gets, and what the five-step ceiling is tuned against. There
-- is no jackpot here to protect. What server timing actually stops is the
-- opposite failure: a client that decided its OWN hits would make a robbery
-- worth whatever somebody's ping happened to be.
local CRACK_MIN_OFFSET = 0.08
local CRACK_TAP_DEBOUNCE = 0.15



-- Where the marker sits at server time `t`, 0..1.
--
-- It PING-PONGS rather than wrapping, so a missed pass is not a missed step
-- -- the marker comes back. Wrapping would teleport it from the right edge
-- to the left, which reads as the dial resetting rather than as a sweep.
local function markerAt(crack: Crack, t: number): number
	local sweep = crack.sweep
	local phase = (t - crack.stepStart) % (sweep * 2)
	return if phase <= sweep then phase / sweep else 2 - phase / sweep
end

-- Where the notch's near edge is at server time `t`. It only moves on a
-- drifting lock, and it moves on the same clock as the marker, so the panel
-- draws the identical function and the notch you see is the notch judged.
local function zoneAt(crack: Crack, t: number): number
	if crack.drift <= 0 then
		return crack.zone
	end
	local phase = (t - crack.stepStart) / Config.CRACK_DRIFT_PERIOD * math.pi * 2
	return crack.zone + crack.drift * math.sin(phase)
end

-- Rolls the zone for the next slice and restarts the sweep.
--
-- The zone never starts at the very left, and that is not decoration: the
-- marker is at 0 the instant a step arms, so a zone touching 0 would be
-- landable by a tap already in flight. CRACK_MIN_OFFSET is about two tenths
-- of a second of travel, which is the marker having to actually reach the
-- target before anybody can claim it.
--
-- A drifting notch rests where its whole swing stays on the track, and a
-- notch too wide to swing its full amount swings less rather than running
-- off either end.
local function armStep(crack: Crack)
	local width, sweep = Config.getCrackZone(crack.steps + 1, crack.locks, crack.picks)
	crack.width = math.clamp(width, 0.05, 1 - CRACK_MIN_OFFSET)
	crack.sweep = sweep
	local room = 1 - crack.width - CRACK_MIN_OFFSET
	crack.drift = math.min(Config.crackLock(crack.locks).drift, room / 2)
	crack.zone = CRACK_MIN_OFFSET + crack.drift + math.random() * (room - crack.drift * 2)
	crack.stepStart = workspace:GetServerTimeNow()
end

-- What the NEXT slice would hand over, in coins, clamped exactly the way
-- banking it will be. The panel prints this, so the two have to be one
-- function or the dial advertises a number the pig does not pay.
--
-- A SLICE IS A SHARE OF THE PIG AS IT WAS WHEN THE ATTEMPT OPENED, NOT AS IT
-- IS NOW, and the first build had it the other way round. Measured on a live
-- resident: a clean five-slice run took 8.9K where the arithmetic in
-- Config.CRACK says 9.7K, because each slice was a fraction of a pig four
-- slices lighter -- so the documented 21.9% run was really 20.2%, and it
-- drifted differently again on a pig that was accruing while the thief
-- worked. Two curves multiplied without anybody checking the product, the
-- same shape as LOSS_CAP x HEIST_PAYOUT one level up.
--
-- Pinning to `pig0` also makes the gauge honest, which is the half that
-- matters more than the arithmetic: the bar is drawn against the pig at the
-- start, so a slice is a FIXED WIDTH on it and the player can see the next
-- one before deciding to take it. Against a shifting basis every segment
-- would be a different size for reasons nothing on screen could explain.
--
-- Still clamped against the LIVE balance, because however the share is
-- computed a pig cannot pay out coins it no longer holds.
local function sliceWorth(crack: Crack): number
	local live = math.floor(targetCoins(crack.victim))
	local want = math.floor(crack.pig0 * Config.getCrackSlice(crack.steps + 1, crack.sack))
	return math.max(0, math.min(want, lossAllowance(crack.victim, live), live))
end

-- `why` RIDES THE CLOSE AND NOTHING ELSE READS IT, which is what keeps this
-- from being a change to the panel. A nil payload has always meant "close",
-- and it still does; the reason arrives as a SECOND argument, so every line
-- of the client's render path sees exactly what it saw before.
--
-- It exists because the note ladder cannot tell the two quiet endings apart
-- without it. A MISS should fall and a WALK-AWAY should be silent -- nothing
-- went wrong, and the player chose it -- and from the client both are the
-- same nil.
-- WHICH OF THE VICTIM'S SKINS A CLEAN CRACK CAN TAKE: the one they are
-- wearing, if it can be taken, and every OTHER one they own that can. Both
-- halves obey the same rails -- stealable (never a Robux skin, never the free
-- default) and actually owned.
--
-- DUPLICATES ARE ALLOWED ON BOTH HALVES, and the first build had it otherwise:
-- a skin the thief already owned was skipped, which read as the whole feature
-- being dead rather than as a rail. On any save that has had `unlockall` run on
-- it the thief owns everything, so the pool was permanently empty and the crack
-- panel read SKIN 0% for ever -- which is exactly how it was reported. What the
-- thief gets for a duplicate is a SPARE (see `grantHaul`), so the victim still
-- loses the copy they lost and nothing is minted out of nowhere.
local function skinCandidates(_thiefData: any, victimData: any): (string?, { string })
	local worn = victimData.cosmetics.skin
	local function takeable(key: string): boolean
		return Config.isStealableSkin(key) and SetService.owns(victimData, "skin", key)
	end
	local others: { string } = {}
	for key in pairs(Config.SKINS) do
		if key ~= worn and takeable(key) then
			table.insert(others, key)
		end
	end
	table.sort(others)
	return if type(worn) == "string" and takeable(worn) then worn else nil, others
end

-- A HALF-AND-HALF ROLL: the skin on the pig or a random other one the victim
-- owns. When one half has nothing in it the other takes the whole chance, so
-- a clean crack only comes away empty when nothing at all can be taken.
-- `roll` false is the crack panel's preview, which must not draw.
local function skinLootChoice(thief: Player, victim: Player, roll: boolean?): (string?, HotSkin?, string?)
	local victimData, thiefData = DataService.get(victim), DataService.get(thief)
	if not victimData or not thiefData then return nil,nil,"Player unavailable" end
	local now = os.clock()
	local claim = grudge[thief] and grudge[thief][victim]
	local hot: HotSkin? = nil
	local hotKey: string? = nil
	local pending = false
	for key, candidate in pairs(if claim then claim.skins else {}) do
		if candidate.expires > now then
			pending = true
			if not candidate.reserved and SetService.owns(victimData,"skin",key)
				and (not hot or candidate.expires < hot.expires
					or (candidate.expires == hot.expires and key < (hotKey :: string))) then
				hot,hotKey = candidate,key
			end
		end
	end
	if pending and not hot then return nil,nil,"Recovery skin in transit" end
	local key: string? = hotKey
	if not hot then
		local worn, others = skinCandidates(thiefData, victimData)
		if not worn and #others == 0 then
			return nil,nil,"No skin here can be stolen"
		end
		if roll then
			local useWorn = worn ~= nil and (#others == 0 or math.random() < 0.5)
			key = if useWorn then worn else others[math.random(1, #others)]
		else
			key = worn or others[1]
		end
	end
	if type(key) ~= "string" or not Config.isStealableSkin(key) then return nil,nil,"This skin cannot be stolen" end
	if not SetService.owns(victimData,"skin",key) then return nil,nil,"Skin unavailable" end
	local entry = skinLosses[victim]
	if not hot and entry and now-entry.since <= Config.SKIN_STEAL.window and entry.lost >= Config.SKIN_STEAL.cap then
		return nil,nil,"Skin theft limit reached"
	end
	return key,hot,nil
end

local function robberyOdds(thief: Player, victim: Target): any
	local plot = targetPlot(victim)
	if plot and plot.shop then
		local data = DataService.get(thief)
		if not data then return {chance=0,kind="shop",reason="Player unavailable"} end
		local odds = Config.shopLootOdds(plot.shop,data.robberies,function(kind,key) return SetService.owns(data,kind,key) end)
		-- Only the probabilities go on each crack tick. The reveal receives
		-- the eligible model pool once, when a real item is discovered.
		odds.pool,odds.total = nil,nil
		return odds
	end
	local player = asPlayer(victim)
	if not player then return {chance=0,kind="resident",reason="Coins only"} end
	local key,hot,reason = skinLootChoice(thief,player)
	if not key then return {chance=0,kind="skin",reason=reason} end
	local spec = Config.getSkin(key)
	-- The panel names the worn skin and counts the rest, so a thief knows
	-- what the coin flip is between without the random half being given away.
	local victimData, thiefData = DataService.get(player), DataService.get(thief)
	local worn, others = nil, {}
	if not hot and victimData and thiefData then
		worn, others = skinCandidates(thiefData, victimData)
	end
	return {chance=1,kind="skin",name=spec.name,tier=Config.rarityOf(spec),
		worn=worn ~= nil, others=#others}
end

local function pushCrack(thief: Player, crack: Crack?, why: string?)
	if not crack then
		Remotes.get("CrackState"):FireClient(thief, nil, why)
		return
	end
	Remotes.get("CrackState"):FireClient(thief, {
		victim = targetName(crack.victim),
		loot = robberyOdds(thief, crack.victim),
		-- The gauge: a pig that was this full, this much of it already in
		-- your hands, and a floor at the point Config.LOSS_CAP stops you. A
		-- resident's floor is zero, which is the cap not applying drawn
		-- rather than stated.
		pig = crack.pig0,
		banked = crack.banked,
		floor = math.max(0, crack.pig0 - crack.allowance0),
		step = crack.steps + 1,
		maxSteps = Config.CRACK.maxSteps,
		-- The victim's Vault Lock tier, printed in the panel's header. Read
		-- only for the label: the lock's effect is already in `width`.
		lock = crack.locks,
		slice = sliceWorth(crack),
		zone = crack.zone,
		width = crack.width,
		startedAt = crack.stepStart,
		sweep = crack.sweep,
		drift = crack.drift,
		driftPeriod = Config.CRACK_DRIFT_PERIOD,
		spares = crack.spares,
	}, why)
end

-- Repaints the figure over the carried piggy. It is written once by
-- attachLoot and then again after every slice, because the thing in a
-- thief's hands is a running total now.
local function setLootAmount(carry: Carry, victim: Target)
	local body = lootBodyOf(carry.loot)
	local label = body and body:FindFirstChild("LootLabel")
	local text = label and label:FindFirstChild("Amount")
	if text and text:IsA("TextLabel") then
		text.Text = ("%s coins  %s"):format(Config.possessive(targetName(victim)), Config.formatCoins(carry.amount))
	end
end

-- Forward declaration. endCrack is read by releaseDog's catch and by
-- HeistService.scare, both written above where it is defined -- and a local
-- read by a function written earlier is a nil GLOBAL in Luau, which dies at
-- the call naming nothing useful. Ninth time this project has met it.
local endCrack: (Player, string) -> ()

-- Lets the dog off. Pulled out of attemptSteal because it no longer fires on
-- a completed robbery -- it fires on a MISS, and on the watcher noticing
-- somebody. See Config.CRACK_ALARM_ON_MISS.
-- MARKS AN INTRUDER FOR THE LENGTH OF THE DOG'S ALERT.
--
-- The alarm-only dog "barks at an intruder and marks them", and a bark alone
-- does not survive the owner looking the other way -- which would swap one
-- failure for its opposite: instead of a plot that is a wall, a plot that is
-- free whenever its owner happens to be facing the wrong direction.
--
-- It is the same Highlight a carrying thief already wears, in the alarm tone
-- rather than gold, and the thief can see it too. That is deliberate and is
-- this project's standing preference for a TELL over a fight: being marked is
-- information the thief can act on -- finish, or walk away -- rather than a
-- punishment they cannot see. It expires with `alertSeconds` on its own.
--
-- IT LIVES HERE AND NOT IN `GuardDog` because GuardDog owns the states it
-- puts a DOG into and knows nothing about players. A Highlight on somebody's
-- character is a fact about a player, so it belongs on this side of that line.
local marked: { [Player]: number } = {}

-- WHEN EACH DOG MAY BARK AGAIN. A dog barks at noise on its lawn and only
-- chases a robbery, so without this a neighbour standing on the grass would be
-- barked at every tick. Keyed on the dog rather than on the person: it is the
-- dog's own voice being rate-limited, and one bark covers however many people
-- are standing there.
--
-- IT IS DECLARED UP HERE BECAUSE `releaseDog` NEEDED ONE TOO, and a `local`
-- below its reader is a nil global -- the trap this project has walked into
-- ten times.
local barkedAt: { [any]: number } = {}

-- WHEN EACH DOG MAY RAISE THE ALARM ABOUT AN INTRUDER AGAIN, which is a
-- different event from the bark above and therefore a different window.
--
-- This is the fix for a real spam bug. `releaseDog`'s owner-home branch barks,
-- marks the intruder, tells both players and RETURNS WITHOUT SETTING ANY STATE
-- -- so `GuardDog.isWatching` stayed true and the 10Hz watcher re-entered it
-- every tick, for as long as a carrying thief stood on the lawn of an owner who
-- was home. Two notifications a tick to both players, and a dog roused ten
-- times a second.
--
-- It only ever showed up against a REAL PLAYER. On a resident's plot the same
-- call reaches `GuardDog.chase`, which sets `dog.chasing`, so `isWatching` goes
-- false and it cannot re-enter: the state change had been doing the
-- rate-limiting everywhere anybody had looked, and the one branch that sets no
-- state is the one nobody had. Same shape as the fence `Touched` handler that
-- re-stamped its own stun faster than it could expire -- correct once,
-- catastrophic repeated.
--
-- TWO WINDOWS AND NOT ONE, because the louder event must not be starved by the
-- quieter one. Sharing `barkedAt` looked tidier and is wrong in exactly one
-- direction: a thief who walks onto the lawn first gets a VISITOR bark, which
-- would then suppress the ROBBERY alarm -- no mark on them and nothing said to
-- the owner -- for the rest of the window, while the pig was being carried off.
-- A visitor bark and "somebody is robbing you" are different facts with
-- different audiences.
--
-- THE WINDOW IS THE MARK'S OWN LIFETIME, so the alarm becomes possible again at
-- exactly the moment the Highlight it came with expires.
local alertedAt: { [any]: number } = {}

local function markIntruder(thief: Player)
	local character = thief.Character
	if not character then
		return
	end

	-- Refresh rather than stack: a thief who keeps making noise gets one mark
	-- that keeps being renewed, never a pile of Highlights nothing removes.
	local existing = character:FindFirstChild("DogMark")
	local stamp = os.clock()
	marked[thief] = stamp

	if not existing then
		local mark = Instance.new("Highlight")
		mark.Name = "DogMark"
		mark.FillColor = Color3.fromRGB(230, 72, 64)
		mark.FillTransparency = 0.75
		mark.OutlineColor = Color3.fromRGB(230, 72, 64)
		mark.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		mark.Parent = character
	end

	task.delay(Config.DOG_WATCH.alertSeconds, function()
		-- Only the LAST mark clears it. Without this stamp check an early
		-- bark's timer would strip a mark a later bark had just renewed.
		if marked[thief] ~= stamp then
			return
		end
		marked[thief] = nil
		local current = thief.Character and thief.Character:FindFirstChild("DogMark")
		if current then
			current:Destroy()
		end
	end)
end

-- A DOG THAT CATCHES SOMEBODY IN ITS YARD THROWS THEM OUT OF IT.
--
-- The landing point is the nearest outside edge: the front (past the fence,
-- onto the driveway) or a side alley, and never the woodland at the back. A
-- side landing is capped at half the alley, so nobody is thrown into a
-- neighbour's yard. The client flies the arc (see `Remotes.DogKnockout`), and
-- the server places anybody still inside the yard once the throw should have
-- landed, so the rule holds even if the client never flies it.
local function knockOutOfYard(player: Player, plot: any)
	local character = player.Character
	local root = getRoot(player)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 or root.Anchored then
		return
	end
	if not plot or not plot.cframe or PlotService.yardContaining(root.Position) ~= plot then
		return
	end
	local k = Config.DOG_CHASE.knockout
	local cf: CFrame = plot.cframe
	local p = cf:PointToObjectSpace(root.Position)
	local halfX = Config.PLOT_HALF_WIDTH
	local frontZ = Config.PLOT_FRONT_LINE
	local sideMargin = math.min(k.margin, (Config.PLOT_SPACING / 2 - halfX))
	local inset = 4

	local toFront = frontZ - p.Z
	local toLeft = p.X + halfX
	local toRight = halfX - p.X
	local landingLocal
	if toFront <= toLeft and toFront <= toRight then
		landingLocal = Vector3.new(math.clamp(p.X, -halfX + inset, halfX - inset), 0, frontZ + k.margin)
	else
		local z = math.clamp(p.Z, -Config.YARD_DEPTH + inset, frontZ - inset)
		local x = if toLeft < toRight then -(halfX + sideMargin) else halfX + sideMargin
		landingLocal = Vector3.new(x, 0, z)
	end

	-- Find the ground there. Scenery is CanQuery off, so this hits the
	-- world ground, a driveway or a lawn.
	local above = cf * (landingLocal + Vector3.new(0, 30, 0))
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(above, Vector3.new(0, -80, 0), params)
	local groundY = if hit then hit.Position.Y else cf.Position.Y - Config.PLOT_SIZE.Y / 2
	local flat = cf * landingLocal
	local landing = Vector3.new(flat.X, groundY + humanoid.HipHeight + root.Size.Y / 2, flat.Z)

	Remotes.get("DogKnockout"):FireClient(player, landing, k.duration)

	task.delay(k.verifyAfter, function()
		local now = getRoot(player)
		if player.Character ~= character or not now or humanoid.Health <= 0 or now.Anchored then
			return
		end
		if PlotService.yardContaining(now.Position) == plot then
			character:PivotTo(CFrame.new(landing) * now.CFrame.Rotation)
		end
	end)
end

local function releaseDog(thief: Player, victim: Target, plot: any)
	-- A SHOP HAS NO DOG, AND THE SHOPKEEPER IS WHAT THIS FUNCTION DOES
	-- INSTEAD.
	--
	-- Every shop's dog is tier 0 -- `applyLevel`'s `plot.shop` branch ladders
	-- only the Vault Lock -- so the early return below has always fired here,
	-- and a figure standing three studs from the vault watched a robbery and
	-- did nothing. `docs/MASTER-PLAN.md` Part III D2 calls that worse than not being
	-- there at all.
	--
	-- IT GOES HERE RATHER THAN AT THE CALL SITES, which is what makes it
	-- cheap AND what makes it correct. Cheap, because all three of this
	-- function's callers are covered by one branch. Correct, because the
	-- third caller -- `watchLawns`, the footstep watcher -- only reaches it
	-- behind `GuardDog.isWatching`, which tests `level > 0`: so a shop
	-- excludes the footstep path BY CONSTRUCTION, and walking into a shop can
	-- never start a chase. It must not, because walking in is how you reach
	-- the vault. What is left is the fumbled slice and the smash, which are
	-- exactly the two loud paths -- see `Config.SHOPKEEPER` for why reacting
	-- to a clean crack would be invisible to `auditRobbery` and would quietly
	-- reprice the four targets that carry the supply floor.
	if plot and plot.shop then
		if ResidentService.alertShopkeeper(plot, thief) then
			PlotService.playAlarm(plot)
			notify(thief, "The shopkeeper has come out from behind the counter!", "chase")
		end
		return
	end

	-- No level check: the dog carries its own tier, set by
	-- PlotService.setDogLevel, and isReady returns false at tier 0.
	if not plot or not GuardDog.isReady(plot.dog) then
		return
	end

	-- AN OWNER WHO IS HOME IS THE DEFENCE, AND THEIR DOG IS ONLY THE ALARM.
	--
	-- `Config.DOG_WATCH` has said this in as many words since the watcher was
	-- designed -- "it barks at an intruder and marks them, and does not chase:
	-- the owner is the defence, and two things that can both hard-stop one
	-- thief on one lawn is how a plot becomes a wall" -- and nothing
	-- implemented it. The dog chased in both states, so a present owner got a
	-- chasing dog AND a tag of their own: the two independent hard-stops that
	-- rule exists to prevent, on the one plot that already has somebody
	-- standing in it. Same shape as every "a rule this file asserts is not a
	-- rule the code keeps" entry, and found the same way -- by reading the
	-- comment next to the code rather than by anything failing.
	--
	-- A RESIDENT'S OWNER IS NEVER HOME, so this cannot touch the supply side:
	-- every unclaimed plot still has an enforcer on it, which is what makes
	-- robbing work on a quiet server.
	if GuardDog.isOwnerHome(plot.dog) then
		-- ONE ALARM PER ALERT WINDOW. This branch sets no state -- it barks and
		-- returns -- so it is the one path into this function that a poller can
		-- re-enter for ever. `watchLawns` did exactly that at ten ticks a
		-- second. See `alertedAt`, declared above, for the whole post-mortem.
		--
		-- THE GATE IS ON THE BARK AND NOT ON THE FUNCTION, which is the half
		-- that matters: the moment the owner steps off their own lawn this
		-- branch stops being taken and the chase below fires on the very next
		-- tick, with no window to wait out. Putting the limit at the call site
		-- instead would have made a dog up to `alertSeconds` slow to start
		-- chasing somebody who was already carrying the piggy.
		local now = os.clock()
		if now >= (alertedAt[plot.dog] or 0) then
			alertedAt[plot.dog] = now + Config.DOG_WATCH.alertSeconds
			GuardDog.bark(plot.dog)
			markIntruder(thief)
			notify(thief, ("%s dog has spotted you!"):format(Config.possessive(targetName(victim))), "chase")
			notifyTarget(victim, "Your dog is barking at somebody on your lawn!", "alarm")
		end
		return
	end
	-- The bark on the dog is a 3D sound that falls off with distance, which
	-- is right for the street and useless for the one player it is about:
	-- they are running AWAY from it. This is the same snarl, flat, for them.
	notify(thief, "A guard dog is chasing you!", "chase")
	-- AND THE NEIGHBOUR GETS UP, to take over where the dog has to stop.
	--
	-- ARMED HERE AND NOT ABOVE THE READINESS TEST, which is what keeps a bone
	-- worth throwing. A dog that is napping on somebody's Golden Bone returns
	-- before this line, so no dog chase means no neighbour either: the bone
	-- still buys the whole window it is sold on. Bribe the dog and the lawn is
	-- quiet; make it loud and there are two of them, one after the other.
	--
	-- It no-ops on a player's plot, because `alertNeighbour` asks for a
	-- resident and a claimed plot has none -- so this is unreachable on a real
	-- child's lawn without a guard anybody has to remember.
	ResidentService.alertNeighbour(plot, thief)
	GuardDog.chase(plot.dog, function(): BasePart?
		-- OUT OF SIGHT ENDS A DOG CHASE TOO. A thief inside a wheelie bin was
		-- caught through the lid: their root is parked AT the bin, so the dog
		-- ran to it and the catch landed -- which made the one hiding place
		-- in the game worse than useless against the thing most likely to be
		-- chasing them. `GuardDog.chase` treats a nil root as "gone" and
		-- trots home, which is the behaviour a dog losing somebody should
		-- have. Same rule the patrol keeps; see `Config.POLICE.searchSeconds`
		-- for the version with a search in it.
		if HeistService.isHidden(thief) then
			return nil
		end
		return getRoot(thief)
	end, function(): boolean
		-- CARRYING decides which ending this is, and it is asked at the
		-- CATCH rather than at the release. A dog let off by a fumbled slice
		-- may arrive at somebody who has since banked three more and is
		-- running for the gate, or at somebody standing empty-handed with
		-- nothing to drop -- and tag returns early with no loot, so without
		-- this the second case would be a dog that runs somebody down and
		-- then does nothing at all.
		if haulingAnything(thief) then
			-- byDog is what the wording and the range check key off, so a
			-- resident standing in the nabber slot is never read as a
			-- player. A house with nobody in it still has a dog.
			--
			-- AND A REFUSED NAB IS REPORTED RATHER THAN SWALLOWED. `nab`
			-- returns false when the thief was DODGING at the moment the dog
			-- arrived, which is correct and is the dodge doing its job. What
			-- was wrong is what happened next: the knockback below fired
			-- anyway and `GuardDog.chase` had already committed to ending,
			-- so half a second of immunity bought a clean getaway -- shoved
			-- off the lawn, still holding the piggy, with the dog now on its
			-- cooldown. Against a rule that says a dodge buys a MOMENT and
			-- never an escape.
			if HeistService.nab(victim :: any, thief, true) == false then
				return false
			end
		else
			HeistService.scare(thief, victim)
		end
		-- Only on a catch that actually landed. A thief who dodged the pounce
		-- is still on the lawn with the dog still coming.
		knockOutOfYard(thief, plot)
		return true
	end)
end

-- Seen off rather than arrested. There is no loot to take, so the cost is
-- the attempt itself: the crack breaks and they are held still long enough
-- to have to make the whole approach again.
--
-- Being robbed has to stay survivable; so does FAILING to rob. A nine-year-
-- old who walks onto a lawn, fumbles a slice and gets nothing has already
-- paid, and taking coins they never had would be a debt for trying.
-- THE SHOPKEEPER'S CATCH, AND IT IS THE DOG'S ENDING WITH A PERSON ON THE
-- END OF IT.
--
-- Registered into `ResidentService` by `Main` rather than called from there,
-- because that file requires this one. Deliberately the SAME two endings the
-- dog picks between, asked in the same order and at the same moment: a
-- shopkeeper who ran somebody down has to cost exactly what a guard dog
-- costs, or a shop becomes cheaper or dearer than a house for a reason
-- nobody chose and nothing audits.
--
-- CARRYING IS ASKED AT THE CATCH, NOT AT THE ALARM, which is the half that
-- matters and is the dog's own lesson. A shopkeeper set off by a fumbled
-- slice may arrive at somebody who has since banked three more slices and is
-- running for the street, or at somebody standing empty-handed with nothing
-- to drop -- and `nab` returns early with no loot, so without this the second
-- case would be a shopkeeper who chases a thief down and then does nothing
-- at all.
--
-- `byDog` is passed for a person, which reads oddly and is right: that flag
-- does not choose the wording, it waives the self-nab guard and the range
-- check. The catcher's own radius decided this, and asking `NAB.distance` a
-- second time would let a thief who has taken one more step in the same
-- frame walk out of a catch that already happened.
function HeistService.shopkeeperCatch(resident: any, thief: Player)
	if haulingAnything(thief) then
		HeistService.nab(resident, thief, true, "The shopkeeper")
	else
		HeistService.scare(thief, resident, "The shopkeeper")
	end
end

-- `catcher` FOR THE SAME REASON `nab` GREW ONE. Both endings of a defender's
-- chase name the defender, and a shopkeeper reusing this path told the thief
-- "Piggy Outfitters's dog saw you off!" -- a dog that does not exist, on a
-- plot whose whole point is that it has no dog.
--
-- The line to the VICTIM is left naming a dog deliberately: a shop is an
-- un-claimable plot, so its victim is always a Resident and `notifyTarget`
-- is a no-op for one. Only the house path can reach it, and on a house it is
-- a dog.
function HeistService.scare(thief: Player, victim: Target, catcher: string?)
	endCrack(thief, "scared")
	notify(thief, if catcher
		then ("%s saw you off!"):format(catcher)
		else ("%s dog saw you off!"):format(Config.possessive(targetName(victim))), "chase")
	notifyTarget(victim, "Your guard dog chased somebody off your lawn.", "good")
	HeistService.detain(thief, Config.DOG_WATCH.scareStun)
end

-- WHAT A CLEAN CRACK ON A SHOP HANDS OVER BESIDES COINS.
--
-- PER COMPLETED RUN, NEVER PER SLICE. The crack is a greed dial and its whole
-- shape is that staying in is a decision; a drop that paid per slice would
-- pay for bailing out, which is the one thing it must not reward.
--
-- WEIGHTED ON THE RARITY LADDER EVERY CRATE ALREADY USES. `Config.RARITIES`
-- carries 100 / 42 / 15 / 4, so a legendary is a twenty-fifth as likely as a
-- common -- which matters because these pools are not flat: the ride shelf
-- runs 25,000 to 4,500,000 coins, and a uniform roll over six rides would
-- hand out a Volt Scrambler about once an hour of good robbing. Reusing the
-- ladder rather than inventing a second one is also what stops a shop and a
-- chest disagreeing about what "rare" is worth.
--
-- UNOWNED ONLY, which is the rule the accessory roll and every chest pool
-- already keep. A drop is progress or it is nothing, and a spare from a
-- robbery would be a second, quieter chest economy nobody asked for.
--
-- AND NOTHING EARNED ELSEWHERE. `Config.isEarnedElsewhere` is the one
-- predicate that answers this in ten places: a pass item falling out of a
-- shop vault would hand over a paid exclusive, and a set item would make an
-- event's attendance ladder reachable by robbing.
-- ============================================================
-- TAKING A SKIN OFF A PLAYER
-- ============================================================
--
-- `Config.SKIN_STEAL` carries the argument for this existing at all -- what
-- rule it spends, the four rails that make a real loss survivable, and the
-- measurement that says a high chance is arithmetic rather than nerve. What
-- is here is the three decisions that live in the code rather than in a
-- number.
--
-- Hot recovery is the exception to the rails below: it revokes the last
-- robber's stolen copy even if the owner reacquired one.
-- ONE: HALF AND HALF, AND DUPLICATES ARE ALLOWED (designer, 2026-09-19). A
-- clean crack takes the skin on the pig or a random other one the victim owns,
-- and it does NOT care whether the thief owns it already -- a duplicate lands
-- as a spare (`grantHaul`).
--
-- IT USED TO SKIP ANYTHING THE THIEF OWNED, on the argument that this made the
-- mechanic DIRECTIONAL -- rob the pig whose colour you want, and the street
-- becomes a shopping list. That reasoning is sound and it shipped a feature
-- that looked dead: on any save that has had `unlockall` run on it the thief
-- owns every skin, so the pool was empty, every clean crack took nothing and
-- the crack panel read SKIN 0% permanently. Reported as the skin not vending
-- at all.
--
-- A SPARE IS NOT A FAUCET HERE, WHICH IS THE OBJECTION WORTH ANSWERING.
-- `rollShopDrop` twenty lines up refuses to pay a duplicate in spares because
-- "a spare is fuel for `Config.COMBINE`, so a drop that produced one would be
-- a spare faucet outside the chest system entirely". That argument is about a
-- drop MINTING an item out of a shop's shelves. A theft MOVES one: the victim
-- lost exactly this copy, capped at one per victim per rolling hour, so the
-- number of copies of that skin on the street is unchanged. The arrow only
-- runs backwards if a theft ever pays a spare WITHOUT taking one, which is
-- why the spare branch sits behind `granted == false` rather than beside it.
--
-- TWO: A SPARE ABSORBS IT. A victim holding a second copy loses the SPARE and
-- goes on wearing the skin, so `data.spares` grows a second job and keeping
-- one of the skin you love is a real defensive purchase -- bought in the same
-- crates the thief is chasing. The loss only ever lands on somebody who chose
-- not to insure.
--
-- THREE: THE VICTIM'S LINE NAMES THE CRATE. `isStealableSkin` guarantees
-- there is one, and a nine-year-old who can see the route back is looking at
-- a setback rather than at something being taken away for good. That is the
-- same call the sell refusal and every bone rejection already make: never
-- fail silently, and never leave somebody without the next thing to do.
local function rollSkinSteal(thief: Player, victim: Player)
	local victimData = DataService.get(victim)
	local thiefData = DataService.get(thief)
	local carry = carrying[thief]
	-- A vanished character must not turn a stolen skin into an instant grant.
	if not victimData or not thiefData or not carry or carry.victim ~= victim then return end

	for _, item in ipairs(carry.haul) do
		if item.kind == "skin" and item.victim == victim then return end
	end
	local claim = grudge[thief] and grudge[thief][victim]
	if claim then
		for key, candidate in pairs(claim.skins) do
			if candidate.expires <= os.clock() then claim.skins[key] = nil end
		end
	end
	local key, hot = skinLootChoice(thief, victim, true)
	if not key then return end
	local entry = nil
	if not hot then
		entry = skinLosses[victim]
		if not entry or os.clock() - entry.since > Config.SKIN_STEAL.window then
			entry = {since=os.clock(),lost=0}
			skinLosses[victim] = entry
		end
	end

	local skin = Config.getSkin(key)
	local wasWorn = victimData.cosmetics.skin == key
	local spareEntry = "skin:" .. key
	local heldSpares = (victimData.spares and victimData.spares[spareEntry]) or 0
	local tookSpare = not hot and heldSpares > 0
	if tookSpare then
		local left = heldSpares - 1
		victimData.spares[spareEntry] = if left > 0 then left else nil
	else
		-- Recovery revokes the stolen owned copy even if the thief changed
		-- outfits, bought insurance or was already protected by the loss cap.
		victimData.claims = victimData.claims or {}
		Config.pruneBuybackClaims(victimData.claims)
		victimData.claims[key] = Config.seasonIndex()
		victimData.cosmetics.owned[key] = nil
		if wasWorn then victimData.cosmetics.skin = Config.DEFAULT_SKIN end
	end
	if entry then entry.lost += 1 end
	if hot then hot.reserved = true end -- reserve before any call can yield
	table.insert(carry.haul, {
		kind = "skin", key = key, victim = victim, spare = tookSpare,
		wasWorn = wasWorn, hot = hot, recoveryOwner = if hot then thief else nil,
		loss = entry,
	})
	-- Stage both sides before saving: a nab during a yielding save must find
	-- the skin on the carry so it can return it, never grant it a second time.
	pushCarryState(thief)
	if hot then
		notify(victim, ("%s took back their %s skin!"):format(thief.DisplayName, skin.name), "bad")
		notify(thief, ("You recovered %s! Get it home."):format(skin.name), "loot")
	elseif tookSpare then
		notify(victim, ("%s took your spare %s! You are still wearing yours."):format(
			thief.DisplayName, skin.name), "bad")
	else
		local crate = Config.CHESTS[skin.chest]
		notify(victim, ("%s stole your %s skin! Nab them now, or take it back after they deliver. %s can also replace it."):format(
			thief.DisplayName, skin.name, if crate then crate.name else "Its crate"), "bad")
	end
	if not hot then
		notify(thief, ("You lifted %s %s skin! Get it home."):format(Config.possessive(victim.DisplayName), skin.name), "loot")
	end
	CosmeticsService.applyToPlot(victim)
	CosmeticsService.push(victim)
	SetService.push(victim)
	DataService.save(victim)
end

local function rollShopDrop(thief: Player, tab: string)
	local data = DataService.get(thief)
	if not data or not Config.SHOP_VAULT_DROP.chance[tab] then return end
	local odds = Config.shopLootOdds(tab, data.robberies, function(kind, key)
		return SetService.owns(data, kind, key)
	end)
	if odds.chance <= 0 or math.random() >= odds.chance then return end
	local roll, acc = math.random() * odds.total, 0
	for _, entry in ipairs(odds.pool) do
		acc += entry.weight
		if roll > acc then continue end
		local mode, worth = "owned", 0
		if entry.kind == "consumable" then
			data.consumables = data.consumables or {}
			data.consumables[entry.key] = (data.consumables[entry.key] or 0) + 1
			for _, push in ipairs(stockPushers) do push(thief) end
			DataService.save(thief)
		elseif odds.resale then
			worth = Config.sellValue(entry.kind, entry.key)
			if worth <= 0 then return end
			mode = "sold"
			local plot = PlotService.getPlot(thief)
			-- Minted in full: the pig has no ceiling to fit.
			worth = math.max(0, math.floor(worth))
			data.coins += worth
			if plot then PlotService.updatePile(plot, data.coins, Config.pigFullAt(data.rebirths)) end
			DataService.save(thief)
		else
			local carry = carrying[thief]
			if carry then
				mode = "carried"
				table.insert(carry.haul, {kind=entry.kind,key=entry.key})
				pushCarryState(thief)
			elseif not SetService.grant(thief,entry.kind,entry.key) then return end
		end
		-- The award/escrow is committed before the cosmetic message. The client
		-- never rolls, grants, sells or changes the server's chosen winner.
		Remotes.get("RobberyLoot"):FireClient(thief, {
			pool=odds.pool,won=entry,tier=entry.tier,mode=mode,coins=worth,
			chance=odds.chance,odds=entry.odds,shop=tab,
		})
		local note = if mode == "carried" then " Get it home."
			elseif mode == "sold" then (if worth > 0
				then (" Sold your duplicate for %s coins."):format(Config.formatCoins(worth))
				else " You already had it, and your piggy is too full to sell it.") else ""
		notify(thief,("There was a %s in the vault!%s"):format(entry.name,note),"loot")
		return
	end
end

-- Ends an attempt and settles up. Every exit runs through here: a miss, the
-- fifth slice, the player pressing stop, walking out of range, being nabbed,
-- being scared off, or leaving the server.
function endCrack(thief: Player, why: string)
	local crack = cracking[thief]
	if not crack or crack.ending then
		return
	end
	crack.ending = true
	cracking[thief] = nil
	pushCrack(thief, nil, why)

	local victim, plot, total = crack.victim, crack.plot, crack.banked

	if total > 0 then
		-- The per-victim cooldown is paid for by TAKING something. A thief
		-- who fumbles the first slice took nothing, so there is nothing to
		-- cool down and the plot is not spent -- what that attempt cost them
		-- is the dog, which is a steeper price and a more interesting one.
		lastGrab[victim] = lastGrab[victim] or {}
		lastGrab[victim][thief] = os.clock()
		Remotes.get("StealCooldown"):FireClient(thief, targetId(victim),
			workspace:GetServerTimeNow() + Config.stealCooldownFor(asResident(victim) ~= nil))

		-- Names what it is WORTH AT HOME -- the payout: the number a thief
		-- is deciding whether to run for is the one they will bank. See
		-- homeWorthPhrase.
		local worth = homeWorthPhrase(thief, victim, total)
		if why == "done" then
			notify(thief, ("Cracked it clean! %s coins, %s. Run!"):format(
				Config.formatCoins(total), worth), "loot")
		elseif why ~= "lost" and why ~= "scared" then
			notify(thief, ("%d of %d slices. %s coins, %s. Run!"):format(
				crack.steps, Config.CRACK.maxSteps, Config.formatCoins(total), worth), "loot")
		end

		-- THE CARRY REMEMBERS A CLEAN RUN, so the delivery can credit Clean
		-- Sheet for it. On the record and not in a side table, because a
		-- hand-off moves the record and the claim goes with it.
		local carry = carrying[thief]
		if why == "done" and carry then
			carry.clean = true
		end

		-- A CLEAN RUN ON A SHOP MAY ALSO HAND OVER SOMETHING FROM ITS OWN
		-- SHELVES. Spawned for the same reason the handlers below are: the
		-- coins have already moved, and a drop that errors must not be able
		-- to take the robbery down with it.
		if why == "done" and plot and plot.shop then
			task.spawn(rollShopDrop, thief, plot.shop)
		end

		-- AND A CLEAN RUN ON A REAL PLAYER MAY TAKE THE SKIN OFF THEIR PIG.
		--
		-- CLEAN ONLY, which is the same line the shop drop draws and matters
		-- more here: a fumbled crack sounds the alarm and wakes the dog, and
		-- paying it a collectable as well would make the loud way in the
		-- better one. What a fumble costs is already the most interesting
		-- price in the game.
		--
		-- A PLAYER ONLY. A resident wears a skin drawn from a per-server bag
		-- and has no collection behind it -- taking one would mint a
		-- collectable out of scenery, at 120 cracks an hour against the two
		-- `LOSS_CAP` allows on a person, which is the faucet this whole
		-- feature is affordable without.
		--
		-- Skin recovery reads its own per-owner claim at the clean crack.
		-- Its deadline survives unrelated robberies and spent coin revenge.
		local victimPlayer = asPlayer(victim)
		if why == "done" and victimPlayer then
			task.spawn(rollSkinSteal, thief, victimPlayer)
		end

		-- Last, and spawned. A subscriber that errors or yields must not be
		-- able to take the robbery down with it: the coins have moved.
		for _, handler in ipairs(stealHandlers) do
			task.spawn(handler, thief, victim, total)
		end
	end

	if why == "miss" then
		-- THE ALARM FIRES ON A FUMBLE AND NEVER ON A CLEAN ROBBERY. A crack
		-- has five moments it could fire at, and the choice decides whether
		-- robbing a present player is possible at all: on the first slice
		-- the owner always wins, on completion they can never defend, only
		-- chase. On a MISS is the third answer and the one that makes skill
		-- worth having -- and it is what wakes the dog.
		--
		-- It does not make a clean robbery invisible. The thief still hauls
		-- a labelled miniature of this pig, still wears a Highlight visible
		-- through walls, and the pile on this lawn just shrank. What a
		-- silent crack buys is that nobody was TOLD.
		if plot then
			PlotService.playAlarm(plot)
		end
		notify(thief, "The lock snapped back!", "warn")
		notifyTarget(victim, ("%s is robbing you! Nab them!"):format(thief.DisplayName), "alarm")
		releaseDog(thief, victim, plot)
	elseif why == "range" and total > 0 then
		notify(thief, "You stepped away from the lock.", "warn")
	end
end

function HeistService.crackTap(thief: Player)
	local crack = cracking[thief]
	if not crack or crack.ending then
		return
	end
	local now = workspace:GetServerTimeNow()
	if now - crack.lastTap < CRACK_TAP_DEBOUNCE then
		return
	end
	crack.lastTap = now

	-- Slack either side, because the tap crossed the wire and is being judged
	-- on the clock at the far end of it. Symmetric: the most an early tap can
	-- buy is a zone it was already aiming at.
	local grace = Config.CRACK.tapGrace / crack.sweep
	local at = markerAt(crack, now)
	local zone = zoneAt(crack, now)
	if at < zone - grace or at > zone + crack.width + grace then
		-- A SPARE PICK FORGIVES IT. The pin snaps back and the same slice
		-- re-arms on a fresh notch: no alarm, no dog, nothing banked or
		-- lost. As far as the street is concerned the miss never happened,
		-- which is the whole of what the Lockpicks tree sells now.
		if crack.spares > 0 then
			crack.spares -= 1
			armStep(crack)
			pushCrack(thief, crack, "forgiven")
			return
		end
		endCrack(thief, "miss")
		return
	end

	local amount = sliceWorth(crack)
	if amount <= 0 then
		-- THE ALLOWANCE RAN OUT, AND IT IS SAID RATHER THAN CLAMPED. A slice
		-- silently worth nothing is the minigame reading as broken; this is
		-- the one refusal that is about the VICTIM's hour rather than the
		-- thief's own timing, so it ends the attempt out loud and the thief
		-- keeps everything they landed.
		notify(thief, ("%s has nothing left to give this hour."):format(
			targetName(crack.victim)), "warn")
		endCrack(thief, "capped")
		return
	end

	-- Out of the pig NOW. See the header: a promise is a double-spend.
	local victim = crack.victim
	local resident = asResident(victim)
	if resident then
		amount = ResidentService.take(resident, amount)
	else
		local victimPlayer = asPlayer(victim)
		local data = if victimPlayer then DataService.get(victimPlayer) else nil
		if not data then
			endCrack(thief, "gone")
			return
		end
		data.coins -= amount
		losses[victim].lost += amount
	end
	if amount <= 0 then
		endCrack(thief, "capped")
		return
	end

	crack.steps += 1
	crack.banked += amount

	local carry = carrying[thief]
	if carry then
		carry.amount += amount
		setLootAmount(carry, victim)
		pushCarryState(thief)
	else
		local loot, prompt = attachLoot(thief, victim, amount)
		if not loot or not prompt then
			-- Character vanished mid-slice; put it back where it came from.
			giveBack(victim, amount)
			crack.banked -= amount
			endCrack(thief, "gone")
			return
		end
		carrying[thief] = newCarry(thief, victim, amount, loot, prompt)

		-- THE FIRST SLICE IS THE GRAB, and everything the old code hung on a
		-- completed steal hangs here instead. You are a thief the moment a
		-- coin leaves somebody else's pig, not when the fifth one does.
		dropShield(thief)
		-- AND A SNEAK SURVIVES THE GRAB, which it did not use to. Creeping
		-- home is the quiet getaway now (see `tiptoeInEffect`), so a thief who
		-- crept in keeps creeping -- at 4.2 studs a second with the pig in
		-- their arms, which is the price. Switching it off here would make the
		-- one escape this design offers something a player has to re-press at
		-- the exact moment they are being chased.
		setCarrySpeed(thief, true)
		pushCarryState(thief)

	end

	if crack.plot then
		PlotService.updatePile(crack.plot, targetCoins(victim), targetFullAt(victim))
		PlotService.playCoinDrop(crack.plot)
		PlotService.rattleLock(crack.plot)
	end

	if crack.steps >= Config.CRACK.maxSteps then
		endCrack(thief, "done")
		return
	end

	armStep(crack)
	pushCrack(thief, crack)
end

function HeistService.crackStop(thief: Player)
	endCrack(thief, "stop")
end

function HeistService.isCracking(player: Player): boolean
	return cracking[player] ~= nil
end

-- DEV ONLY: tap the crack when the marker is in the middle of the zone, so a
-- solo Studio session can run a clean crack through the REAL judge. It never
-- decides a hit itself -- it waits until the server's own marker is inside
-- the server's own zone and then calls `crackTap`, which is the same call
-- the client's F press makes. `AdminService`'s `crack` command is the only
-- caller; it replaced the `smash` command when the smash was retired
-- (designer, 2026-09-23), because a coin carry still has to be testable in
-- a session whose viewport is not drawing and so can hold no prompt.
function HeistService.devTapInZone(thief: Player): boolean
	local crack = cracking[thief]
	if not crack or crack.ending then
		return false
	end
	local deadline = os.clock() + crack.sweep * 2 + 1
	while os.clock() < deadline do
		if cracking[thief] ~= crack or crack.ending then
			return false
		end
		local now = workspace:GetServerTimeNow()
		local at, zone = markerAt(crack, now), zoneAt(crack, now)
		if now - crack.lastTap >= CRACK_TAP_DEBOUNCE
			and at > zone + crack.width * 0.3 and at < zone + crack.width * 0.7 then
			HeistService.crackTap(thief)
			return true
		end
		task.wait()
	end
	return false
end

-- ============================================================
-- THE WATCHING DOG
-- ============================================================
--
-- Until now `GuardDog.chase` fired from ONE place: a completed steal. So
-- walking up somebody's drive and standing on their lawn working their lock
-- for twelve seconds carried no dog risk whatever, every bit of pressure in
-- this game sat on the run home, and the whole approach was free. Tiptoe
-- shipped into that: a slower walk that nothing in the game could notice.
--
-- THE WATCHER LIVES HERE AND NOT IN `GuardDog`, and that is a dependency
-- decision rather than a filing one. Deciding whether a dog should react
-- needs to know where every player is, which plot they are standing in, how
-- fast they are moving and who owns the ground -- and `GuardDog` knows none
-- of those, should not learn them, and would need PlotService and Players to
-- do it. This service already has all four. GuardDog keeps what a dog IS:
-- asleep or up, alerted or quiet, and how good its ears are.
--
-- DON'T WAKE THE DOG is the whole rule. A SLEEPING dog is woken by footsteps
-- and never by a sneak (`tiptoeInEffect`, the same answer the speed and the
-- creep animation read, so the three cannot disagree). An AWAKE dog -- owner
-- home, guard duty, or an alert running -- sees anybody who moves, sneaking
-- or not. So a clean sneak in, a clean crack and a sneak out is never heard,
-- and a thief who woke it cannot creep past it with the piggy.
--
-- It used to be a per-tier `notice` SPEED with tiptoe tuned under it. Dogs
-- have no tiers now, and a threshold 0.6 studs/sec above a maxed carry-sneak
-- was one that measurement jitter could cross by itself.
--
-- AND IT IS SPEED MEASURED, NEVER `WalkSpeed` READ. That distinction is the
-- whole feature: `WalkSpeed` is what a character is ALLOWED to do, so a
-- player standing perfectly still on a lawn reads 16 and would wake every dog
-- on the street for doing nothing at all. Standing still is never a crime
-- here, so the watcher differences positions between ticks and asks how far
-- somebody actually went.
local lastSeen: { [Player]: { pos: Vector3, at: number } } = {}

-- `barkedAt` is declared above `releaseDog`, which reads it too. See there.

-- Under this, somebody is standing still. A parked character still drifts a
-- little -- idle animation, the ground settling, network jitter -- and an
-- awake dog sees ANY movement, so without a floor it would be permanently
-- set off by nobody moving. Well under a tiptoe (5.6).
local IDLE_SPEED = 0.5

-- IS THIS PLAYER CARRYING SOMETHING TAKEN FROM THIS PLOT? Coins cracked out of
-- its pig, or a piggy lifted off its plinths. A dog guards ITS OWN yard's
-- goods and nothing else: a thief crossing a third lawn with somebody else's
-- sack, an owner carrying their own piggy home, and a lassoed wild catch are
-- all just visitors to it, and get barked at rather than chased. Before this
-- the watcher asked only whether anything was being carried, so every dog on
-- the street ran down whoever walked past with any load at all.
--
-- A resident victim is matched by identity and, failing that, by the plot it
-- was robbed on, so a neighbour evicted mid-getaway does not let the thief
-- walk back across the lawn they robbed.
local function stoleFrom(player: Player, plot: any, victim: Target?): boolean
	local carry = carrying[player]
	if carry and ((victim ~= nil and carry.victim == victim) or targetPlot(carry.victim) == plot) then
		return true
	end
	return piggyStolenFrom ~= nil and piggyStolenFrom(player) == plot
end

local function watchLawns()
	local now = os.clock()

	-- One pass over the players, because the inner questions are asked once
	-- per plot and there are eight of each: computing a yard per player per
	-- plot is 64 `yardContaining` calls a tick at ten ticks a second, and
	-- computing it per player is 8.
	local spots: { [Player]: Vector3 } = {}
	local speeds: { [Player]: number } = {}
	local yards: { [Player]: any } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local root = getRoot(player)
		if not root then
			lastSeen[player] = nil
			continue
		end
		local pos = root.Position
		local prev = lastSeen[player]
		local speed = 0
		if prev and now > prev.at then
			-- Flat: a fall is not a footstep, and the drop off a fence would
			-- otherwise be the loudest thing on the lawn.
			local moved = Vector3.new(pos.X - prev.pos.X, 0, pos.Z - prev.pos.Z)
			speed = moved.Magnitude / (now - prev.at)
		end
		lastSeen[player] = { pos = pos, at = now }
		spots[player] = pos
		speeds[player] = speed
		yards[player] = PlotService.yardContaining(pos)
	end

	for _, plot in ipairs(PlotService.getAll()) do
		local dog = plot.dog
		if not dog then
			continue
		end

		-- IS ANYBODY IN? A resident's owner is always away, which is what
		-- makes every unclaimed plot a dog's own plot to defend -- and what
		-- makes the police loop and the whole supply side work on a quiet
		-- server. `yardContaining` is the FENCE rectangle rather than the
		-- plot slab, so an owner standing on their own driveway counts as
		-- out; that is the right answer, since the driveway is where you are
		-- when you are leaving.
		local owner = plot.owner
		GuardDog.setOwnerHome(dog, owner ~= nil and yards[owner] == plot)

		if dog.level <= 0 then
			continue
		end

		-- DON'T WAKE THE DOG. A sleeping dog hears footsteps and never a
		-- sneak; an awake one sees anybody who moves, sneaking or not. So a
		-- thief who tiptoes in, cracks clean and tiptoes out with the piggy
		-- is never heard -- and one who woke it on the way in, or fumbled a
		-- slice, cannot creep past it on the way out.
		local awake = GuardDog.isAwake(dog)

		-- The LOUDEST intruder, not the first found. Two thieves on one lawn
		-- and the dog goes for the one making noise rather than for whichever
		-- happened to be earlier in a hash order -- which would also make the
		-- choice differ between ticks for no reason anybody could see.
		--
		-- EXCEPT THAT SOMEBODY RUNNING OFF WITH THIS YARD'S OWN GOODS OUTRANKS
		-- ANY AMOUNT OF NOISE. A visitor stamping past with a sack from down the
		-- street must not draw the dog's eye off the thief it is here to catch.
		local victimHere: Target? = owner or ResidentService.get(plot)
		local loudest: Player? = nil
		local loudestSpeed = -1
		local loudestOurs = false
		for player, yard in pairs(yards) do
			if yard == plot and player ~= owner then
				local speed = speeds[player] or 0
				local noticed = speed > IDLE_SPEED and (awake or not tiptoeInEffect(player))
				if noticed then
					local ours = stoleFrom(player, plot, victimHere)
					if (ours and not loudestOurs)
						or (ours == loudestOurs and speed > loudestSpeed) then
						loudest, loudestSpeed, loudestOurs = player, speed, ours
					end
				end
			end
		end
		if not loudest then
			continue
		end

		-- Heard. The dog does not pounce: `alert` stamps a stir a beat from
		-- now, and only `isWatching` -- which asks whether that beat has
		-- passed, whether the dog is on cooldown, lured or already chasing --
		-- lets it off.
		GuardDog.alert(dog)
		if GuardDog.isWatching(dog) then
			-- A DOG ONLY GOES AFTER A ROBBERY, AND THIS REVERSES WHAT THE
			-- LAWN WATCHER USED TO DO.
			--
			-- Walking loudly across a neighbour's lawn used to be enough to
			-- be run down, marked and reported to the owner -- so visiting
			-- somebody's base at all was a mistake, and this game has one
			-- friendly mechanic as it is. Now noise gets you BARKED AT, which
			-- is a tell for the visitor and for anybody watching, and nothing
			-- else: no chase, no mark on the character, and nothing said to
			-- the owner, because nothing has happened to their piggy.
			--
			-- ROBBING is walking off with somebody's piggy: carrying, with the
			-- crack CLOSED. Footsteps while the lock is still being worked get a
			-- bark and nothing more, even though the carry exists from the first
			-- slice -- shuffling round a vault is not a getaway, and the crack
			-- already has its own way to wake the dog: the fumbled slice. That
			-- and the smash are the other two callers of `releaseDog`, and both
			-- are untouched.
			--
			-- AND ONLY THIS YARD'S GOODS. Carrying something from ANOTHER plot
			-- across this lawn is a visit as far as this dog is concerned; see
			-- `stoleFrom`.
			local victim: Target? = victimHere
			local robbing = cracking[loudest] == nil and stoleFrom(loudest, plot, victim)
			if robbing and victim then
				releaseDog(loudest, victim, plot)
			elseif not robbing and now >= (barkedAt[dog] or 0) then
				-- Rate-limited, or a visitor standing on the lawn would be
				-- barked at ten times a second. One bark per alert window.
				barkedAt[dog] = now + Config.DOG_WATCH.alertSeconds
				GuardDog.bark(dog)
			end
		end
	end
end

-- ANYTHING IN TRANSIT GOES BACK TO WHOEVER IT CAME OFF, and this is a
-- function rather than a block inside `clearCarry` because THREE paths end a
-- carry and only one of them goes through there.
--
-- `clearCarry` covers the nab, the arrest and being scared off. The other two
-- write `carrying[player] = nil` directly and call `giveBack` for the COINS
-- -- a thief who DIES and a thief who QUITS -- and both were written when
-- coins were the only thing a robbery could be holding. Left alone, resetting
-- your character while carrying somebody else's skin would destroy it: gone
-- from the victim, never arrived for the thief, and nothing in any log.
--
-- Deliberately not folded into `giveBack`, which moves coins and is called in
-- places where there is no carry at all.
local function returnHaul(carry: Carry)
	-- THE SAME RULE THE COINS ALREADY KEEP. `recoverCoins` takes a tagged
	-- haul off the victim's loss window because coins that went home again
	-- were never lost -- you were caught. A skin is the same fact about a different object, and getting
	-- it wrong is worse: coins are fungible and a collection is not, so a
	-- thief who is nabbed while holding somebody's Pearl skin would otherwise
	-- destroy it -- gone from the victim, never arrived for the thief, and
	-- nothing in any log.
	--
	-- SHOP LOOT IS SIMPLY LOST, because there is nobody behind a shop to give
	-- it back to -- the same asymmetry `lossAllowance` already draws between
	-- a person and a resident. A `victim` of nil is what says so.
	local haul = carry.haul or {}
	carry.haul = {}
	for _, item in ipairs(haul) do
		local owner = item.victim
		if owner and owner.Parent then
			local data = DataService.get(owner)
			if data then
				if item.spare then
					-- The spare that absorbed it. Put the spare back.
					data.spares[item.kind .. ":" .. item.key] =
						(data.spares[item.kind .. ":" .. item.key] or 0) + 1
					SetService.push(owner)
					DataService.save(owner)
				else
					SetService.grant(owner, item.kind, item.key)
					if item.kind == "skin" and item.wasWorn ~= false then
						-- Back on their pig as well as back in their save.
						-- `grant` restores ownership and says nothing about
						-- what they are WEARING, and this took the worn one.
						CosmeticsService.equipSkin(owner, item.key)
					end
				end
				-- Off the victim's window too, for the reason the coins come
				-- off theirs: it was never lost.
				local window = skinLosses[owner]
				if window and window == item.loss then
					window.lost = math.max(0, window.lost - 1)
				end
				local recoveredFor = item.recoveryOwner
				local hot = item.hot
				if recoveredFor and hot and hot.expires > os.clock()
					and grudge[recoveredFor] and grudge[recoveredFor][owner]
					and grudge[recoveredFor][owner].skins[item.key] == hot then
					hot.reserved = nil
				end
				notify(owner, ("You got your %s skin back!"):format(
					Config.getSkin(item.key).name), "good")
			end
		end
	end
end

local function clearCarry(thief: Player): Carry?
	if tugs[thief] then
		tugs[thief] = nil
		nabRest[thief] = os.clock() + Config.NAB.cooldown
	end
	-- ANYTHING THAT TAKES THE LOOT ENDS THE ATTEMPT. A thief nabbed, arrested
	-- or killed part way through a crack would otherwise go on holding a
	-- panel over a pig they are no longer standing at, and their next tap
	-- would bank a slice into a carry that no longer exists. endCrack clears
	-- its own entry before doing anything, so this cannot recurse.
	endCrack(thief, "lost")

	local carry = carrying[thief]
	if not carry then
		return nil
	end
	carrying[thief] = nil

	returnHaul(carry)

	if carry.loot then
		carry.loot:Destroy()
	end
	-- The mark goes with the loot. Cleared rather than left to the character
	-- being rebuilt, because a thief who delivers keeps the same character --
	-- so a stale id here would leave a "!" hanging over somebody who is no
	-- longer carrying anything of yours.
	local character = thief.Character
	if character then
		character:SetAttribute(Config.CARRY_VICTIM_ATTRIBUTE, nil)
	end
	setCarrySpeed(thief, false)
	pushCarryState(thief)

	return carry
end

-- ============================================================
-- ACTIONS
-- ============================================================

-- OPENS a crack. The function of this name used to perform an entire
-- robbery in one call; it now does the part before the interesting part --
-- everything that decides WHETHER you may rob this pig, and nothing about
-- how much you get, which is now a decision rather than a constant.
function HeistService.attemptSteal(thief: Player, victim: Target)
	if cracking[thief] then
		return
	end
	local reason = whyCannotSteal(thief, victim)
	if reason then
		notify(thief, reason, "warn")
		return
	end

	local plot = targetPlot(victim)
	if not plot then
		return
	end

	-- THE ROOM IS THE RANGE, ON A SHOP AND NOWHERE ELSE. A vault stands on a
	-- back wall two studs from the grass behind it, so the prompt alone would
	-- let a thief rob one from outside -- and from out there the run home is
	-- shorter than the one the whole economy is priced against. Refused by
	-- name, because a refusal nobody can see is indistinguishable from a
	-- broken feature.
	if plot.shop and not inShopRoom(thief, plot) then
		notify(thief, "That vault is inside the shop. Go in.", "warn")
		return
	end

	local pig = math.floor(targetCoins(victim))
	local crack: Crack = {
		victim = victim,
		plot = plot,
		sack = UpgradeService.getLevel(thief, "sack"),
		-- Read from the PLOT rather than from UpgradeService, which asks the
		-- victim for an upgrade record a resident does not have. A resident
		-- carries its lock level exactly where a player's is published.
		locks = targetLockLevel(victim),
		picks = UpgradeService.getLevel(thief, "lockpicks"),
		steps = 0,
		banked = 0,
		pig0 = pig,
		allowance0 = lossAllowance(victim, pig),
		stepStart = 0,
		zone = 0,
		width = 0,
		sweep = Config.CRACK.sweepSeconds,
		drift = 0,
		spares = Config.lockpickPerk(UpgradeService.getLevel(thief, "lockpicks")).spares,
		lastTap = 0,
		ending = false,
	}
	cracking[thief] = crack
	armStep(crack)
	pushCrack(thief, crack)

	-- The dial turns, once here and once per landed slice below. It debounces
	-- itself and spins for 1.1 seconds, so one call at the start would have
	-- covered about a fifth of a crack and then stood still for the rest of
	-- it -- and this is the only animation the entire Vault Lock tree has.
	-- A notch per slice is also the honest picture: something gave.
	PlotService.rattleLock(plot)
end

-- Knocks the loot out of a thief's hands. Callable by anyone in range, or by
-- a guard dog on its owner's behalf (`byDog`, which has already done its own
-- proximity check and whose "nabber" may be nowhere near).
-- ============================================================
-- THE CATCH EFFECT
-- ============================================================
--
-- PUBLISHED AS TWO ATTRIBUTES ON THE THIEF'S OWN CHARACTER, AND RENDERED
-- BY EVERY CLIENT ITSELF.
--
-- The same split the animated skins, the moat and `HouseFX` already make,
-- and it is the right one for the same reason: a burst is a picture of
-- something the server has already decided, so replicating the picture
-- would be dozens of property writes a frame to say what one string
-- already says. An attribute also reaches EVERYBODY without a remote and
-- without a list of who is nearby -- which matters here, because the
-- audience for a catch effect is the street rather than the two people in
-- it.
--
-- A COUNTER AS WELL AS A KEY, and the key is written FIRST. `DodgeRoll`
-- already records why a flag will not do: an attribute set to the same
-- value twice fires one changed signal, so nabbing the same thief twice
-- with the same effect would animate once. The client watches the
-- COUNTER and reads the key, so the ordering is what stops a burst
-- rendering last catch's cosmetic.
--
-- IT CHANGES NOTHING. No speed write, no state change, no part with
-- collision or query on it, and the stun beside it is the NAB's and was
-- there before this existed.
local function fireCatchEffect(thief: Player, nabber: Player)
	CosmeticsService.fireCatchEffect(thief.Character, nabber)
end

-- Empty hands and a live, nearby character are required on every tick and
-- again at handoff. A winner can never overwrite another carry or pull a haul
-- into a missing character. Busy players finish their own activity first.
local function canReceiveCarry(nabber: Player, thief: Player): boolean
	if nabber == thief or not nabber.Parent or not DataService.get(nabber)
		or haulingAnything(nabber) or cracking[nabber]
		or inBin[nabber] or isStunned(nabber) or rideMultiplier[nabber] ~= nil then return false end
	local root, thiefRoot = getRoot(nabber), getRoot(thief)
	local humanoid = getHumanoid(nabber)
	return root ~= nil and thiefRoot ~= nil and humanoid ~= nil and humanoid.Health > 0
		and (root.Position - thiefRoot.Position).Magnitude <= Config.NAB.distance + 6
end

local function catchWinner(thief: Player, tug: Tug): Player?
	local best: Player? = nil
	local bestShare, bestOrder = -1, math.huge
	for nabber, share in pairs(tug.nabbers) do
		local order = tug.joined[nabber]
		if share > 0 and canReceiveCarry(nabber, thief)
			and (share > bestShare or (share == bestShare and order < bestOrder)) then
			best, bestShare, bestOrder = nabber, share, order
		end
	end
	return best
end

-- Move the same model, prompt, receipts and haul. No clearCarry here: that is
-- a losing path which refunds items and destroys the model. This transaction
-- performs no asset loading or yielding between validation and ownership swap.
local function handOff(thief: Player, winner: Player): boolean
	local carry = carrying[thief]
	local thiefHumanoid = getHumanoid(thief)
	if not carry or carry.holder ~= thief or not thief.Parent
		or not thiefHumanoid or thiefHumanoid.Health <= 0
		or not canReceiveCarry(winner, thief) then return false end
	local oldRoot, newRoot = getRoot(thief), getRoot(winner)
	local body = lootBodyOf(carry.loot)
	local weld = body and body:FindFirstChild("CarryWeld")
	-- The weld hangs off whatever `CarryPose.anchor` chose at the grab (the
	-- hand on an R15 rig), so that is the part it must still be on.
	local oldAnchor = if oldRoot then (CarryPose.anchor(oldRoot.Parent, "sling")) else nil
	if not oldRoot or not newRoot or carry.loot.Parent ~= oldRoot.Parent
		or not weld or not weld:IsA("WeldConstraint")
		or weld.Part0 ~= (oldAnchor or oldRoot) or weld.Part1 ~= body then return false end

	local newAnchor, seat = CarryPose.anchor(newRoot.Parent, "sling")
	newAnchor = newAnchor or newRoot
	weld.Part0 = nil
	carry.loot:PivotTo(newAnchor.CFrame * seat)
	carry.loot.Parent = newRoot.Parent
	weld.Part0 = newAnchor
	carrying[thief], carrying[winner] = nil, carry
	carry.holder, carry.inRange, carry.dropAction, carry.returnAvailable = winner, nil, nil, nil
	carry.prompt.ObjectText = winner.DisplayName
	nabRest[winner] = os.clock() + Config.NAB.cooldown
	oldRoot.Parent:SetAttribute(Config.CARRY_VICTIM_ATTRIBUTE, nil)
	local victim = asPlayer(carry.victim)
	newRoot.Parent:SetAttribute(Config.CARRY_VICTIM_ATTRIBUTE, if victim then victim.UserId else nil)
	setCarrySpeed(thief, false)
	dropShield(winner)
	setCarrySpeed(winner, true)
	pushCarryState(thief)
	pushCarryState(winner)
	return true
end

-- Rest belongs to whoever holds the haul after the tug. Failed/cancelled
-- tugs leave all escrow with the old holder and never award a catch or bounty.
local function endTug(thief: Player, why: string)
	local tug = tugs[thief]
	if not tug then return end
	tugs[thief] = nil
	local winner = if why == "emptied" and carrying[thief] == tug.carry
		and tug.progress + 0.000001 >= Config.NAB.recoverSeconds
		then catchWinner(thief, tug) else nil
	if winner and handOff(thief, winner) then
		fireCatchEffect(thief, winner)
		for nabber, share in pairs(tug.nabbers) do
			if nabber.Parent and share > 0 then
				TrophyService.recordCatch(nabber)
				-- Top Defenders (Phase 5.5): a thief stopped this week.
				SocialService.recordDefend(nabber)
			end
		end
		notify(thief, ("%s took the haul! You can chase it back."):format(winner.DisplayName), "bad")
		notify(winner, "You took the haul! Watch out for other nabbers.", "loot")
		if tug.carry.victim ~= winner then
			notifyTarget(tug.carry.victim,
				("%s is now carrying your piggy."):format(winner.DisplayName), "warn")
		end
	else
		nabRest[thief] = os.clock() + Config.NAB.cooldown
	end
end

-- One tick advances time only. The loop passes its own tug token so an old
-- coroutine cannot tick a replacement tug or a new carry on the same player.
local function tugTick(thief: Player, expected: Tug?): boolean
	local tug = tugs[thief]
	local carry = carrying[thief]
	local humanoid = getHumanoid(thief)
	if not tug or (expected and tug ~= expected) or carry ~= tug.carry
		or not carry or carry.holder ~= thief or not thief.Parent
		or not humanoid or humanoid.Health <= 0 then return false end
	if tug.progress + 0.000001 >= Config.NAB.recoverSeconds then return false end
	if HeistService.isDodgeImmune(thief) then
		for nabber in pairs(tug.nabbers) do
			if nabber.Parent then notify(nabber, ("%s dodged you!"):format(thief.DisplayName), "warn") end
		end
		notify(thief, "Dodged! You shook them off.", "good")
		return false
	end
	local holding: { Player } = {}
	for nabber in pairs(tug.nabbers) do
		if canReceiveCarry(nabber, thief) then table.insert(holding, nabber) end
	end
	if #holding == 0 then return false end
	local step = math.min(Config.NAB.tickRate, Config.NAB.recoverSeconds - tug.progress)
	tug.progress += step
	for _, nabber in ipairs(holding) do
		tug.nabbers[nabber] += step / #holding
	end
	return tug.progress + 0.000001 < Config.NAB.recoverSeconds
end

-- `catcher` IS THE WORDING AND `byDog` IS THE BEHAVIOUR, AND THEY HAD TO
-- BECOME TWO THINGS.
--
-- The comment further down says `byDog` is "a genuine asymmetry, not a
-- convenient flag for reusing an ending", and it is right: it waives the
-- self-nab guard and the range check, and everything below the tug branch is
-- dog-only. What it should never have been is the source of the SENTENCE.
-- The shopkeeper reuses this path -- correctly, because a defender's catch
-- has to cost exactly what a dog's catch costs -- and told the player "A
-- guard dog got you!" while standing in front of them in an apron.
--
-- That is worse than a cosmetic slip in this specific game: the dog's
-- posture is the tell a thief reads from the pavement, and a message naming
-- a dog that is not there is the tell lying. Caught by driving it, not by
-- reading it.
function HeistService.nab(nabber: Player, thief: Player, byDog: boolean?, catcher: string?)
	-- YOU CANNOT TAG YOURSELF, AND THE PROMPT IS ON YOUR OWN BODY, so this is
	-- not a guard against a forged remote -- it is the default state of every
	-- robbery in the game. `attachLoot` welds the loot to the THIEF's own root
	-- and parents the tag prompt to it, deliberately, because the prompt
	-- exists so that everybody ELSE can reach it. The side effect is that the
	-- one player who must never press it stands permanently at distance zero,
	-- well inside `NAB.distance`, with `RequiresLineOfSight` off -- so a
	-- carrying thief has "Nab Thief!" over their own name for the whole
	-- getaway.
	--
	-- WHAT IT COSTS IS NOT AN EXPLOIT, and that is worth being exact about
	-- rather than overstating it: a self-tag returns the coins to the victim
	-- and stuns the thief, so it is pure self-harm and profits nobody. It
	-- still has to go, for two reasons. A nine-year-old with a stray thumb
	-- loses an entire robbery to a button the game should never have offered
	-- them -- the same argument the last-copy sell guard makes. And the
	-- messages it produces are nonsense in both directions: the thief is told
	-- "you dropped the loot" AND "nice nab!" in the same second, because
	-- `nabber ~= victim` is true when the nabber is the thief, and the victim
	-- is told somebody nabbed themselves.
	--
	-- Same shape as the wheelie bin, where the occupant is refused their own
	-- OPEN prompt. Silent, because a legitimate client no longer asks: the
	-- prompt is disabled on the thief's own machine, so anything reaching
	-- here is forged.
	if nabber == thief then
		return
	end

	-- RETURNS FALSE WHEN IT TOOK NOTHING, and only the dog reads that. A
	-- player's nab is fired by a prompt and its caller has no use for an
	-- answer; a DOG's is fired by `GuardDog.chase`, which has to know whether
	-- to end the chase or keep running. Every other early return below is
	-- inside `if not byDog` and is therefore unreachable from the dog, which
	-- is why they are left returning nothing rather than threaded through.
	local carry = carrying[thief]
	if not carry then
		-- A PIGGY IS THE OTHER THING THEY COULD BE HOLDING, and everything
		-- below this line is about coins -- the amount, the victim's balance,
		-- the keep share, the bounty, the handoff tug. So the piggy haul gets
		-- its own ending in its own file and this is the one seam between
		-- them: every catcher in the game already comes through `nab`, so
		-- wiring it here is what makes a guard dog, a shopkeeper and a
		-- bystander all able to stop a piggy thief without one of them being
		-- the exception somebody forgot.
		--
		-- RETURNS TRUE SO THE DOG READS IT AS A CATCH. The chase loop ends on
		-- a true and keeps running on a false, and a dog that ran a piggy
		-- thief down and then reported nothing would fall through to `scare`
		-- -- seen off, empty-handed, with the piggy still under their arm.
		if piggyNabbed and piggyNabbed(nabber, thief, byDog, catcher) then
			return true
		end
		return false
	end

	-- Dodged. Costs the nabber their whole NAB.hold and they must start again,
	-- which is the entire point: the immunity is paid for in the currency of
	-- the chase rather than in coins. FOR A DOG, "start again" is the chase
	-- carrying on and another lunge a moment later -- see the pounce in
	-- `GuardDog.chase`, which is what makes that true rather than a comment.
	if HeistService.isDodgeImmune(thief) then
		notify(thief, "Dodged!", "good")
		if not byDog then
			notify(nabber, ("%s dodged you!"):format(thief.DisplayName), "warn")
		end
		return false
	end

	if not byDog then
		if not canReceiveCarry(nabber, thief) then return end
		local nabberRoot, thiefRoot = getRoot(nabber), getRoot(thief)
		if not nabberRoot or not thiefRoot then
			return
		end
		-- Re-check distance server-side; the prompt's range is a client hint.
		if (nabberRoot.Position - thiefRoot.Position).Magnitude > Config.NAB.distance + 6 then
			return
		end

		-- ------------------------------------------------------------------
		-- A PLAYER STARTS A TUG. THE DOG DOES NOT, AND THAT IS DELIBERATE.
		-- ------------------------------------------------------------------
		--
		-- Everything below this branch is the BINARY nab, and it is kept for
		-- the dog. A dog cannot tug and should not: it is the enforcer on an
		-- unclaimed lawn, it has no decision to make, and giving an NPC a
		-- partial outcome would be a mechanic nobody is playing. The same
		-- goes for the patrol, which does not come through here at all --
		-- `confiscate` is its own path and an arrest is a confiscation.

		-- THE REST IS ON THE HOLDER, including a player who just received
		-- the haul. Refused quietly rather than out loud: the prompt is on
		-- a moving target in a crowd, so a toast per refused press would be
		-- noise about somebody else's cooldown.
		if os.clock() < (nabRest[thief] or 0) then
			return
		end

		local existing = tugs[thief]
		if existing then
			-- Joining divides contribution credit without speeding the tug up.
			-- Repeated presses retain the original join order.
			if existing.nabbers[nabber] == nil then
				existing.joinCount += 1
				existing.joined[nabber] = existing.joinCount
				existing.nabbers[nabber] = 0
			end
			return
		end

		SoundKit.on(thiefRoot, Config.SOUNDS.NAB,
			{ name = "Nab", volume = 0.5, distance = 80 })

		-- Freeze the grab before the tug; further crack taps/catches cannot
		-- append to escrow while somebody is taking it from the current holder.
		endCrack(thief, "lost")
		local tug: Tug = {
			carry = carry, nabbers = { [nabber] = 0 },
			joined = { [nabber] = 1 }, joinCount = 1, progress = 0,
		}
		tugs[thief] = tug
		notify(thief, "Somebody has hold of you! Dodge to break free.", "chase")
		task.spawn(function()
			repeat
				task.wait(Config.NAB.tickRate)
			until not tugTick(thief, tug)
			if tugs[thief] ~= tug then return end
			local complete = carrying[thief] == tug.carry
				and tug.progress + 0.000001 >= Config.NAB.recoverSeconds
			endTug(thief, if complete then "emptied" else "broken")
		end)
		return
	end

	local victim = carry.victim
	local amount = carry.amount

	-- HEARD FROM THE THIEF, WHICH IS WHERE THE EVENT HAPPENED. Read off
	-- BEFORE `clearCarry`, because that is what takes the loot -- and the
	-- root is wanted whether or not it survives the next line.
	--
	-- A BLUNT IMPACT AND DELIBERATELY NOT A SNARL. The dog path already has
	-- its own voice: `GuardDog` plays DOG_SNARL on a catch, so a second
	-- sound layered under it would be two animals in one moment. This is
	-- the PLAYER's nab, and the two are told apart by `byDog` exactly as
	-- every other asymmetry in this function is.
	--
	-- It fires after every refusal above -- the dodge, the distance
	-- re-check, the missing carry -- so a nab that did not land is silent.
	-- A catch noise on a dodge would tell the whole street the wrong
	-- outcome, on the one mechanic whose entire point is that the thief can
	-- beat it.
	if not byDog then
		SoundKit.on(getRoot(thief), Config.SOUNDS.NAB,
			{ name = "Nab", volume = 0.5, distance = 80 })
	end

	clearCarry(thief)

	-- Coins go home to the victim, not to the nabber. Nabbing is defence,
	-- never a way to launder someone else's money into your own pig.
	returnCarryAmount(carry, amount)
	do
		notifyTarget(victim, if byDog
			then ("Your guard dog caught %s. %s coins saved!"):format(thief.DisplayName, Config.formatCoins(amount))
			else ("%s nabbed %s. Your %s coins are back!"):format(targetName(nabber), thief.DisplayName, Config.formatCoins(amount)),
			"good")
	end

	local humanoid = getHumanoid(thief)
	if humanoid then
		humanoid.WalkSpeed = 0
		task.delay(Config.STUN_SECONDS, function()
			if humanoid.Parent and not carrying[thief] then
				humanoid.WalkSpeed = Config.BASE_WALK_SPEED
			end
		end)
	end

	notify(thief, if byDog
		then ("%s got you! You dropped the haul."):format(catcher or "A guard dog")
		else ("Nabbed by %s! You dropped the haul."):format(nabber.DisplayName),
		"bad")

	-- ONE FOR THE MEDAL BOARD, AND IT IS THE VICTIM WHO GETS IT.
	--
	-- EVERYTHING BELOW THE TUG BRANCH IS DOG-ONLY, which is not obvious from
	-- here: every path inside `if not byDog` returns, so a player's nab never
	-- reaches this line and is credited in `endTug` instead. Writing the
	-- player half here as well would have been dead code that reads as a
	-- second, disagreeing answer to the same question.
	--
	-- A DOG BELONGS TO THE PLOT IT IS STANDING ON, so its catch is the
	-- VICTIM's: they bought the dog, they fed it the treat, and they may not
	-- even be on the street to see it happen. A RESIDENT'S DOG CREDITS
	-- NOBODY, which falls out of `asPlayer` returning nil rather than needing
	-- a branch -- and is correct, because there is no lawn to stand a rosette
	-- on.
	local owner = asPlayer(victim)
	if owner then
		TrophyService.recordCatch(owner)
		SocialService.recordDefend(owner)
	end
	if (nabber :: any) ~= victim and not byDog then
		notify(nabber, ("Nice nab! You saved %s coins."):format(Config.possessive(targetName(victim))), "good")
	end
	return true
end

-- ============================================================
-- CONFISCATION
-- ============================================================

-- Takes the loot off a thief on the patrol's behalf and sends it home.
--
-- Deliberately NOT HeistService.nab with one more flag. A nab is a player or a
-- dog defending a plot, and the range re-check, the "nice nab" thanks and the
-- wording all belong to that. The patrol defends nobody: it is the house's own
-- risk, it thanks nobody, and the bail it charges afterwards is PoliceService
-- policy rather than this file's business.
--
-- Returns (amount, victim), or (0, nil) if there was nothing to take -- which
-- includes a thief who already delivered. That is not a failure and the caller
-- must not treat it as one: outrunning the officer is what buys you out of a
-- patrol, and reaching your own plot is not the same thing as getting away.
--
-- Does NOT check dodge immunity. The dodge has to beat the CATCH, not the
-- paperwork, or a thief could roll at the moment of arrest and keep the loot
-- while the officer stood over them. PoliceService checks it before it decides
-- it has caught anybody.
function HeistService.confiscate(thief: Player): (number, Target?, string?)
	local carry = carrying[thief]
	if not carry then
		-- AND A PIGGY GOES BACK TOO, which is a different sentence from "there
		-- was nothing to take". The patrol pursues anybody `isCarrying` says
		-- is carrying, and that now includes somebody walking off with a
		-- pedestal -- so without this an arrest would hold them still, charge
		-- them nothing, and leave the piggy under their arm. An officer who
		-- catches a thief and confiscates nothing is the one ending this whole
		-- feature may not have.
		--
		-- IT STILL RETURNS ZERO COINS, deliberately: what this arrest was for
		-- is an object rather than a sum, so there is no haul to hand back.
		-- NOTE WHAT THAT DOES NOT MEAN ANY MORE. Bail used to be three times
		-- the haul, so a zero here was "no bail"; `PoliceService.chargeBail`
		-- is a flat share of the thief's OWN bank now and `arrest` charges it
		-- on every catch whatever was carried -- so a thief caught with a
		-- snatched piggy loses the piggy AND pays bail. Recorded as the
		-- behaviour that ships (2026-09-22); whether a confiscation should be
		-- exempt is a designer call not yet made.
		if piggyConfiscated then
			piggyConfiscated(thief)
		end
		return 0, nil
	end

	local victim, amount = carry.victim, carry.amount
	clearCarry(thief)

	-- Home to the victim, exactly as a tag would. The patrol is not a second
	-- thief and coins do not disappear into it.
	returnCarryAmount(carry, amount)

	return amount, victim, carry.kind
end

-- The carry is consumed before grants can yield/save. Recovery receipts still
-- belong to their original owner when another holder keeps that skin.
local function grantHaul(thief: Player, data: any, haul: { Haul }): { { kind: string, key: string } }
	local delivered: { { kind: string, key: string } } = {}
	for _, item in ipairs(haul) do
		local granted
		if item.hot and item.hot.spare and item.recoveryOwner == thief then
			-- Return the insured copy that was actually lost. An ordinary
			-- duplicate is handled below, and the two are separate because this
			-- one is a RECOVERY: the owner is taking back the spare that was
			-- taken off them, whoever is wearing what.
			local key = item.kind .. ":" .. item.key
			data.spares[key] = (data.spares[key] or 0) + 1
			SetService.push(thief)
			DataService.save(thief)
			granted = true
		else
			granted = SetService.grant(thief, item.kind, item.key)
			if not granted and not item.hot and item.kind == "skin" then
				-- A DUPLICATE IS A SPARE, NEVER NOTHING. `grant` refuses a skin
				-- the thief already owns, which would make a landed robbery pay
				-- out silently -- and duplicates are allowed on purpose, so the
				-- extra copy lands the way every other duplicate in this game
				-- does. No faucet: the victim lost exactly this copy.
				local key = item.kind .. ":" .. item.key
				data.spares[key] = (data.spares[key] or 0) + 1
				SetService.push(thief)
				DataService.save(thief)
				granted = true
			end
		end
		if granted then
			table.insert(delivered, { kind = item.kind, key = item.key })
			-- A hot skin brought home by its own owner is a defence too
			-- (Top Defenders, Phase 5.5).
			if item.hot and item.recoveryOwner == thief then
				SocialService.recordDefend(thief)
			end
			if item.kind == "skin" and Config.SKIN_STEAL.wear and not (item.hot and item.hot.spare and item.recoveryOwner == thief) then
				CosmeticsService.equipSkin(thief, item.key)
			end
		end
		if item.hot and item.victim then
			local recoveryOwner = item.recoveryOwner or thief
			local claim = grudge[recoveryOwner] and grudge[recoveryOwner][item.victim]
			if claim and claim.skins[item.key] == item.hot then
				claim.skins[item.key] = nil
			end
		end
		if item.kind == "skin" then
			local robbed = if item.hot then item.recoveryOwner else item.victim
			if robbed and robbed ~= thief and robbed.Parent then
				recordGrudge(robbed, thief, {kind=item.kind, key=item.key,
					spare=if item.hot then item.hot.spare else item.spare})
				SocialService.markRevenge(robbed, thief)
			end
		end
	end

	return delivered
end

local function returnCarry(player: Player)
	local carry = carrying[player]
	if not carry or not canDeliverCarry(player, carry) or not returnPlot(carry) then return end
	local data = DataService.get(player)
	if not data then return end
	local amount, victim = carry.amount, carry.victim
	local bounty = returnBounty(player, carry)
	local haul = carry.haul
	carry.haul = {}
	clearCarry(player) -- consume before refund/grant callbacks can yield
	returnCarryAmount(carry, amount)
	-- The coin bounty is minted in full: the pig has no ceiling.
	bounty = math.max(0, math.floor(bounty))
	data.coins += bounty
	carry.haul = haul
	returnHaul(carry)
	SetService.push(player)
	local home = PlotService.getPlot(player)
	if home then
		PlotService.updatePile(home, data.coins, Config.pigFullAt(data.rebirths))
	end
	notify(player, ("Returned %s coins and the haul. Bounty: %s coins."):format(
		Config.formatCoins(amount), Config.formatCoins(bounty)), "good")
	if victim ~= player then
		notifyTarget(victim, ("%s returned %s of your coins and the haul!"):format(player.DisplayName, Config.formatCoins(amount)), "good")
	end
end

-- Thief reached their own plot: the loot becomes theirs, in their pig.
local function deliver(thief: Player)
	local carry = carrying[thief]
	if not carry or not canDeliverCarry(thief, carry) then
		return
	end

	local data = DataService.get(thief)
	if not data then
		return
	end

	if carry.victim == thief and carry.claimant ~= thief then
		returnCarry(thief)
		return
	end
	local original = carry.claimant == thief

	local amount = carry.amount
	local victim = carry.victim
	-- LIFTED OFF THE CARRY BEFORE `clearCarry` SEES IT, because that function
	-- gives a haul BACK -- it is the losing path, and it cannot tell a
	-- delivery from a nabbing. Emptying the list here is what says "this one
	-- got home", and it has to happen before the call rather than after it:
	-- `clearCarry` is what destroys the carry record.
	local haul = carry.haul or {}
	carry.haul = {}
	local clean = carry.clean == true
	clearCarry(thief)

	-- REVENGE. The thief is robbing back somebody who robbed THEM inside the
	-- window: the payout steps up and the coin bonus is spent. Read before the
	-- coins move so the multiplier is decided by the state at delivery, and
	-- cleared so a second robbery of the same person is an ordinary one.
	local mine = grudge[thief]
	local revenge = original and isRevenge(thief, victim)
	if revenge and mine then
		mine[victim :: Player].expires = 0
	end

	-- STOLEN COINS COUNT DOUBLE (triple on revenge). The extra is minted, not
	-- taken from the victim -- see Config.HEIST_PAYOUT for why the thief's
	-- reward had to stop being the victim's loss.
	--
	-- BANKED IN FULL. This has now gone both ways twice: a delivery could
	-- overflow capacity, then 4c.6 capped it at the pig and spilled the rest,
	-- and the pig's ceiling is gone (designer decision 2026-09-21), so there
	-- is nothing to cap against. The victim loses the full `amount` -- that
	-- happened slice by slice, and every counter below measures it -- and
	-- the thief banks the whole payout.
	local payout = if not original then Config.NAB.keepShare
		elseif revenge then Config.revengePayout() else Config.HEIST_PAYOUT

	-- ROBBERIES IN A ROW ARE WORTH MORE. Read BEFORE `recordSteal` below,
	-- which is what bumps the run -- so the delivery that starts a run pays
	-- the plain rate and the one after it pays more, which is what a streak
	-- means. See Config.WANTED_STARS.
	--
	-- It multiplies the revenge payout too rather than replacing it: they are
	-- different things being rewarded (who you robbed, and how fast you are
	-- working), and a thief who lines up a revenge hit in the middle of a run
	-- has done both.
	if original then payout *= SocialService.getStarMultiplier(thief) end

	local worth = math.floor(amount * payout)
	local banked = math.max(0, worth)
	local fullAt = Config.pigFullAt(data.rebirths)
	data.coins += banked
	data.totalStolen += amount
	-- One completed getaway, regardless of target, payout or haul size.
	-- The carry is consumed above, so repeated delivery requests cannot count
	-- it twice. Record before any reward callback can save the player's data.
	local rankBefore = Config.getRapSheetRank(data.robberies)
	if amount > 0 or #haul > 0 then
		data.robberies += 1
	end
	-- The first delivery retires the onboarding line, for good and on every
	-- future session, because `totalStolen` is what it is derived from.
	thief:SetAttribute(Config.PLAYER_FIRST_JOB_ATTRIBUTE, false)
	-- The rap sheet, which is a different number from the lifetime one above:
	-- MOST WANTED is a contest within one session, so it has to be winnable by
	-- somebody who joined ten minutes ago. See SocialService.recordSteal.
	-- Both measure what the VICTIM lost, never the doubled figure.
	SocialService.recordSteal(thief, amount)
	-- AND THE WEEKLY LADDER, which is the same event counted on a longer
	-- clock. `amount` rather than `banked` for the reason the rap sheet uses
	-- it: what a board ranks has to be what was actually taken out of
	-- somebody's pig, never the doubled figure minted on the way home.
	SocialService.recordWeekly(thief, amount)

	local victimPlayer = asPlayer(victim)
	local victimData = if victimPlayer then DataService.get(victimPlayer) else nil
	if victimData then
		victimData.totalLost += amount
	end

	-- THE PIG-CRACK ACORN USED TO BE MINTED HERE: one acorn for a clean
	-- five-slice crack on a PLAYER's pig, two on revenge, doubled under a
	-- Midnight Heist. It went with the currency. What a clean crack pays now
	-- is what it always paid besides -- the coins, the skin roll, the spree
	-- and the rap sheet -- and `clean` is still read four lines down for the
	-- Clean Sheet trophy, so the flag has not gone inert.

	-- THE VICTIM SHELF, AND IT IS FILLED ON THE DELIVERY RATHER THAN ON
	-- THE GRAB.
	--
	-- Every other thing this game counts about a robbery is counted here
	-- for the same reason -- `totalStolen` two lines up, the rap sheet, the
	-- weekly board -- because loot nabbed out of your hands or confiscated
	-- by a patrol was never stolen: you were caught. A shelf that filled on
	-- the grab would let a thief collect all forty-six skins by cracking
	-- pigs and never once getting away with anything.
	TrophyService.recordVictim(thief, targetSkin(victim))

	local plot = PlotService.getPlot(thief)
	if plot then
		PlotService.updateRank(plot, data.robberies)
		PlotService.updatePile(plot, data.coins, fullAt)
		-- NO `playBank` HERE. The delivery toast below is the `money` kind,
		-- which already plays the cha-ching -- the 3D copy at the pig made it
		-- twice, on top of the coin pour and the summary sting, and a delivery
		-- was reported as too many sounds at once. One cha-ching is the sound.
	end
	-- THE PIG ITSELF, HANDED OVER RATHER THAN HUNTED FOR.
	--
	-- The delivery effect rushes coins into the actual bank on the lawn, and
	-- the client would otherwise have to work out which of the plots in
	-- `workspace` is its own -- which is a replication race at exactly the
	-- moment it matters, on a client that has just run across the street.
	-- The server already holds the answer three lines up.
	--
	-- An INSTANCE on the wire, which is safe in the one direction that
	-- matters: the client cannot do anything with it that it could not
	-- already do with a part it can plainly see, and it is the same part its
	-- own steal prompts and rob badges are bound to.
	local bank = if plot and plot.piggy then plot.piggy.body else nil

	-- AND THE HAUL LANDS HERE, which is the moment it becomes theirs.
	--
	-- `SetService.grant` returns false on something already owned, and that
	-- is the duplicate rule for ordinary theft. A recovery may also return
	-- a skin its original owner reacquired; no extra spare is minted for it.
	-- Only an explicitly tracked stolen spare is restored as a spare. Nothing is
	-- minted for it -- no spare, no coins -- for the reason `rollShopDrop`
	-- refuses to pay duplicates in spares: a spare is combine fuel, and a
	-- robbery that produced one would be a faucet outside the chest system.
	local delivered = grantHaul(thief, data, haul)

	-- PHASE 5. A clean crack that got home counts toward Clean Sheet; the
	-- victim's ledger learns who robbed them; and a new robber rank can land
	-- Old Hand. All after every counter above, because each of these may save.
	if original and clean and amount > 0 then
		TrophyService.recordClean(thief)
	end
	if victimPlayer then
		SeasonService.recordNemesis(victimPlayer, thief)
	end
	if Config.getRapSheetRank(data.robberies) ~= rankBefore then
		TrophyService.recheck(thief)
	end

	-- A BONUS NOBODY IS TOLD ABOUT IS A BONUS NOBODY BELIEVES, so the run is
	-- named in the line that reports the money rather than in a card of its
	-- own -- the same rule the event tokens follow, where one card carries
	-- both currencies. `steps` is read AFTER recordSteal, so it names the run
	-- this delivery has just extended rather than the one it started from.
	-- `getRun`, NOT `getStars`: the Most Wanted pin holds the leader's
	-- stars at five (SocialService.starsOf), and a trophy for "five in a
	-- row" handed over on a leader's FIRST delivery would be a record of a
	-- run nobody made. The run underneath the pin is what this measures.
	local runNow = SocialService.getRun(thief)
	-- THE BEST RUN THIS ACCOUNT HAS EVER PUT TOGETHER, kept because
	-- `Config.WANTED_STARS` deliberately does not: a run fades when you stop and
	-- is spent by being arrested, which is right for a live multiplier and
	-- means the best thing a player ever did evaporates the moment they do
	-- anything else. Read AFTER `recordSteal`, so it names the run this
	-- delivery has just extended rather than the one it started from --
	-- the same ordering `runNote` above depends on.
	TrophyService.recordSpree(thief, runNow)
	local runNote = if runNow > 1 then (" %dx IN A ROW!"):format(runNow) else ""

	-- THE SUMMARY, FIRED BEFORE THE TOAST so the panel is what the player
	-- looks at and the toast is the receipt behind it. Both, deliberately:
	-- see `Remotes.HeistDelivered` -- the summary is the half that could fail
	-- to build, and a payout nobody can see is indistinguishable from a
	-- broken feature, which is the rule this project refuses above all
	-- others.
	--
	-- IT CARRIES WHAT WAS EARNED AND NOT HOW TO DRAW IT. `delivered` is a
	-- list of `{kind, key}` and the client resolves names, tiers and models
	-- out of `Config` for itself -- the same split every other push here
	-- makes, and the reason a stolen skin needs no new field to be rendered
	-- as the real pig in a viewport.
	Remotes.get("HeistDelivered"):FireClient(thief, {
		amount = amount,
		banked = banked,
		run = runNow,
		revenge = revenge,
		items = delivered,
		victim = targetName(victim),
		bank = bank,
		-- What the pig reads as full on the lawn (the rebirth cash gate), so
		-- the coin stream can be sized to the haul against the pig it is
		-- pouring into rather than against a number that means something
		-- different at level 0 and level 60. A readout, never a limit: no
		-- `spilled` travels, because nothing spills.
		fullAt = fullAt,
	})

	notify(thief, if not original
		then ("Kept the haul! Half share: %s coins."):format(Config.formatCoins(banked))
		elseif revenge
		then ("REVENGE! %s stolen coins, %s banked.%s"):format(
			Config.formatCoins(amount), Config.formatCoins(banked), runNote)
		else ("Delivered %s stolen coins, %s banked.%s"):format(
			Config.formatCoins(amount), Config.formatCoins(banked), runNote),
		"money")
	notifyTarget(victim, ("%s got away with %s of your coins. Get them back for triple!"):format(
		thief.DisplayName, Config.formatCoins(amount)), "bad")

	-- The victim now holds a grudge: robbing this thief back inside the
	-- window pays triple, and the marker over the thief's plot says so for
	-- exactly that long. A successful robbery is the moment a grievance
	-- exists, and a grievance is what creates the next session.
	--
	-- A RESIDENT NEVER HOLDS ONE. Revenge is the day-two return hook and it
	-- is about a PERSON having been wronged; a marker hanging over a plot
	-- because an empty house was robbed would point at nobody, promise a
	-- triple payout that no one can collect, and put scenery on a board
	-- meant for players. The whole social layer stops at the doorstep.
	if victimPlayer then
		recordGrudge(victimPlayer, thief, nil)
		SocialService.markRevenge(victimPlayer, thief)
	end
end

-- ============================================================
-- LIFECYCLE
-- ============================================================

-- ARRIVING SETTLES THE HAUL. The range loop in `start` calls this the tick a
-- carrier steps into a glowing ring -- their own pig to keep it, the
-- owner's pig to return it -- and everything is re-derived here rather than
-- trusted. There was a DELIVER button; the ring replaced it, because a
-- player running from a dog should not have to find a button as well.
local function settleOnArrival(thief: Player)
	local carry = carrying[thief]
	if not carry or not canDeliverCarry(thief, carry) then
		return
	end
	local action = dropAction(thief, carry)
	if action == "return" then returnCarry(thief)
	elseif action == "keep" then deliver(thief) end
end

function HeistService.onPlayerAdded(player: Player)
	local seconds = shieldSeconds(player)
	shieldUntil[player] = os.clock() + seconds
	-- The same instant, published for every client to read off the Player. The
	-- badge over a piggy needs it and so does anybody deciding whether to walk
	-- up the drive; see Config.PLAYER_SHIELD_ATTRIBUTE for why it lives here.
	player:SetAttribute(Config.PLAYER_SHIELD_ATTRIBUTE,
		workspace:GetServerTimeNow() + seconds)

	-- Has this player ever got a robbery home? Read off `totalStolen` rather
	-- than a new save field, because that is already the answer. Published
	-- for the client, which turns it into the one line of onboarding this
	-- game has; see Config.PLAYER_FIRST_JOB_ATTRIBUTE.
	local data = DataService.get(player)
	player:SetAttribute(Config.PLAYER_FIRST_JOB_ATTRIBUTE,
		(data == nil) or (data.totalStolen or 0) <= 0)

	-- A CLIMB HAS TO PUSH THE SPEED, because `refreshSpeed` is event-driven
	-- rather than a per-frame loop: without this the climb multiplier would
	-- only land on whatever unrelated event happened next, which is usually
	-- the thief already being over the fence.
	--
	-- Both edges. Leaving the climb has to restore the walk, or a thief who
	-- has just come over the top runs the whole getaway at a third speed.
	local function watchClimb(character: Model)
		local humanoid = character:FindFirstChildWhichIsA("Humanoid")
		if not humanoid then
			return
		end
		humanoid.Died:Connect(function()
		end)
		humanoid.StateChanged:Connect(function(old, new)
			if old == Enum.HumanoidStateType.Climbing
				or new == Enum.HumanoidStateType.Climbing then
				refreshSpeed(player)
			end
		end)
		-- AND THE SPEED AND JUMP ARE PUSHED THE MOMENT THERE IS A HUMANOID TO
		-- PUSH THEM TO, which was a latent bug this change made visible.
		--
		-- `refreshSpeed` is the only thing that ever writes JumpHeight, and it
		-- ran only on a speed EVENT -- a grab, a snag, a mount. So a freshly
		-- spawned character kept the rig default until something happened to
		-- it. That was invisible for as long as the rig default and
		-- BASE_JUMP_HEIGHT were the same number, and they were: both 7.2.
		--
		-- Measured the moment they stopped agreeing: a player stood on their
		-- own lawn with JumpHeight 7.20 against a Config that said 5.50, and
		-- could hop a Barbed Wire fence they were never meant to clear.
		refreshSpeed(player)
	end
	if player.Character then
		watchClimb(player.Character)
	end
	player.CharacterAdded:Connect(watchClimb)

	player.CharacterAdded:Connect(function()
		-- Dying drops the loot back to its owner. Otherwise the fastest way
		-- to escape a chase would be to reset.
		local carry = carrying[player]
		if carry then
			returnCarryAmount(carry, carry.amount)
			returnHaul(carry)
			carrying[player] = nil
			pushCarryState(player)
		end
		task.wait(0.2)
		setCarrySpeed(player, false)
	end)
end

-- Drops every restriction on robbing, for everyone in the server.
--
-- Testing aid only, driven by AdminService. Two separate things stop a repeat
-- robbery and they produce two different rejection messages, so clearing only
-- one of them looks like "the admin button did nothing":
--
--   * the join shield         (JOIN_SHIELD / NEW_PLAYER_SHIELD, 15 s in Studio)
--   * the per-victim cooldown (STEAL_COOLDOWN, 60s)
--   * the loss cap            (LOSS_CAP), which a repeat-robbery test hits
--                             on the fourth grab of a full pig
--
-- Testing the guard dog means robbing the same person over and over, which
-- runs into the second immediately. Both go together.
--
-- There used to be a third, a per-victim lifetime cap; see the note where
-- STEAL_MAX_PER_VICTIM used to live in Config.
--
function HeistService.openSeason(): (number, number)
	local shields = 0
	for _, player in ipairs(Players:GetPlayers()) do
		if shieldUntil[player] then
			shieldUntil[player] = 0
			-- And the published copy with it, or every badge in the server goes
			-- on saying PROTECTED through the whole test.
			player:SetAttribute(Config.PLAYER_SHIELD_ATTRIBUTE, 0)
			shields += 1
		end
	end
	table.clear(losses)

	local pairsCleared = 0
	for victim in pairs(lastGrab) do
		for _ in pairs(lastGrab[victim]) do
			pairsCleared += 1
		end
	end
	table.clear(lastGrab)

	return shields, pairsCleared
end

function HeistService.isCarrying(player: Player): boolean
	return haulingAnything(player)
end

function HeistService.start()
	startObjectives()
	startStreetState()
	-- THE GATE JAM'S DECISION LIVED HERE -- is this player carrying, is it
	-- their own gate, and can they pay -- and went with the jam itself. See the
	-- retirement note in `PlotService`; nothing here reads `Config.GATE_JAM` now.

	PlotService.onFencePenalty(function(player, plot, penalty)
		HeistService.applyFencePenalty(player, plot, penalty)
	end)

	-- Carries no arguments at all. The cooldown, the window and the immunity
	-- are all decided here, so the only thing a client can do with this channel
	-- is ask -- and asking too often is simply refused.
	Remotes.get("DodgeRequest").OnServerEvent:Connect(function(player)
		HeistService.dodge(player)
	end)

	-- One boolean, and it is coerced rather than trusted: a client is welcome
	-- to send a table, a number or nothing at all, and every one of those has
	-- to mean "stop sneaking" rather than throwing inside a remote handler.
	Remotes.get("TiptoeRequest").OnServerEvent:Connect(function(player, on)
		HeistService.setTiptoe(player, on == true)
	end)

	-- BOTH WAYS IN ARE WIRED THROUGH ONE FUNCTION.
	--
	-- The guard below is the same guard for a steal and for a smash -- which
	-- plot, which prompt, and how long the hold really ran -- and a second
	-- copy of it is the near-identical duplicate this project keeps recording
	-- as the thing that drifts. What differs between the two is three
	-- arguments: the hold to validate, what to call, and what to say when it
	-- does not add up.
	--
	-- THE REFUSALS ARE PER PATH ON PURPOSE. "The lock held" is nonsense on a
	-- prompt that never touched a lock, and a message describing the wrong
	-- action is how a player learns to stop reading them.
	local function wireEntry(plot: any, prompt: ProximityPrompt, hold: number,
		refusal: string, act: (Player, Target) -> ())
		prompt.PromptButtonHoldBegan:Connect(function(thief)
			holdStarted[thief] = { plot = plot, prompt = prompt, at = os.clock() }
		end)

		-- There is deliberately NO PromptButtonHoldEnded handler.
		--
		-- Roblox fires HoldEnded BEFORE Triggered when a hold completes, and
		-- it fires at completion rather than on release -- measured at 0.584s
		-- and 0.584s on a 0.6s prompt. Clearing the record there meant
		-- Triggered always read nil and every single steal silently did
		-- nothing. It survived review because reproducing it needs two
		-- players.
		--
		-- Leaving the record is safe: the next HoldBegan overwrites it, and
		-- Triggered below validates which plot it belongs to, WHICH PROMPT it
		-- belongs to, and how long ago it started.
		prompt.Triggered:Connect(function(thief)
			-- The plot's owner if somebody lives here, otherwise the
			-- resident. A plot with neither is genuinely nobody's and there
			-- is nothing to rob -- which can only happen for the instant
			-- between a player leaving and ResidentService seating the next
			-- neighbour.
			local victim: Target? = plot.owner or ResidentService.get(plot)
			if not victim then
				return
			end

			-- THE HOLD IS A FIXED HALF SECOND NOW, AND IT IS STILL CHECKED.
			-- What used to be here measured a hold that scaled with the
			-- victim's Vault Lock, because that tree expressed itself in how
			-- long you stood there; it expresses itself in the crack's ZONE
			-- WIDTHS instead, and a difficulty gate in both places would
			-- charge for the same upgrade twice.
			--
			-- The check survives the shrink because a ProximityPrompt's
			-- HoldDuration is writable on the client that sees it, so an
			-- instant trigger is always forgeable. Half a second is not much
			-- to protect, but an attempt now drops your shield and wakes a
			-- dog on a miss, so it should never be startable by accident or
			-- by a stray remote. A smash protects a great deal more: it is
			-- the whole robbery on one press.
			local started = holdStarted[thief]
			holdStarted[thief] = nil

			-- Never fail silently. A rejection the player cannot see is
			-- indistinguishable from a broken game, which is exactly how the
			-- bug above went unnoticed.
			--
			-- The PROMPT test is what stops the two paths validating each
			-- other's holds: one record per thief, two prompts on one pig,
			-- and without it a 1.3-second smash hold would satisfy a
			-- half-second steal.
			if not started or started.plot ~= plot or started.prompt ~= prompt then
				notify(thief, refusal, "warn")
				return
			end
			local held = os.clock() - started.at
			if held < (hold - HOLD_TOLERANCE) or held > hold + 30 then
				notify(thief, refusal, "warn")
				return
			end

			act(thief, victim)
		end)
	end

	for _, plot in ipairs(PlotService.getAll()) do
		-- QUIET AND SLOW.
		wireEntry(plot, plot.piggy.stealPrompt, Config.CRACK.openHold,
			"The lock held. Try again.", HeistService.attemptSteal)

		-- THE SHAKE PROMPT STOOD HERE, on the acorn oak's own collider, and
		-- retired with it. H and J are both free keys again.
	end

	-- THE TAP CARRIES NOTHING AND THE STOP CARRIES NOTHING. Everything about
	-- where the marker is, what the slice is worth and whether it landed is
	-- decided above, on this machine, against this machine's clock.
	Remotes.get("CrackTap").OnServerEvent:Connect(function(player)
		HeistService.crackTap(player)
	end)
	Remotes.get("CrackStop").OnServerEvent:Connect(function(player)
		HeistService.crackStop(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		-- Before the carry, because ending an attempt settles it: a thief who
		-- quits mid-crack keeps nothing, but the victim has to get the coins
		-- that already left their pig back, and that happens through the
		-- carry below.
		endCrack(player, "lost")
		cracking[player] = nil

		-- Return anything in transit, then forget the player entirely.
		local carry = carrying[player]
		if carry then
			returnCarryAmount(carry, carry.amount)
			returnHaul(carry)
			carrying[player] = nil
		end

		shieldUntil[player] = nil
		tiptoeing[player] = nil
		marked[player] = nil
		losses[player] = nil
		-- Dropped with the rest, and it costs nothing to drop: a plot is
		-- RELEASED when its owner leaves, so nobody can be robbed while away
		-- and there is no window left to carry.
		skinLosses[player] = nil
		grudge[player] = nil
		for _, held in pairs(grudge) do
			held[player] = nil
		end
		holdStarted[player] = nil
		lastSeen[player] = nil
		snagged[player] = nil
		rideMultiplier[player] = nil
		warded[player] = nil
		hitRestUntil[player] = nil
		burst[player] = nil
		dodgeUntil[player] = nil
		dodgeImmuneUntil[player] = nil
		lastDodge[player] = nil
		lastGrab[player] = nil
		for _, byThief in pairs(lastGrab) do
			byThief[player] = nil
		end

		-- A TUG OUTLIVES ITS PARTICIPANTS UNLESS IT IS TOLD NOT TO, and both
		-- directions matter. A departing THIEF leaves a tug whose loop would go
		-- on ticking against a player who has gone; a departing NABBER leaves a
		-- share nobody can be paid. The same shape as a wheelie bin outliving
		-- its occupant, which once killed a bin for the rest of a server's life.
		tugs[player] = nil
		nabRest[player] = nil
		for _, tug in pairs(tugs) do
			tug.nabbers[player] = nil
		end
	end)

	-- THE LAWNS ARE WATCHED. Ten times a second, which is what the ride gate
	-- already runs at and far tighter than a dog needs -- but it is also the
	-- interval the speed measurement is taken over, and a longer one would
	-- average a burst of running in with the standing still either side of
	-- it and quietly let a sprint past a Titan.
	task.spawn(function()
		while true do
			task.wait(Config.DOG_WATCH.pollRate)
			-- Pcalled as a whole: this touches every plot and every player
			-- every tick, and a dog is a cosmetic-grade feature next to the
			-- heist loop running underneath it. The same argument that put a
			-- pcall around `Decor.prewarm` -- a lawn ornament may never stop
			-- the server starting -- says a watchdog may never stop the game
			-- being played.
			local ok, err = pcall(watchLawns)
			if not ok then
				warn("[HeistService] lawn watch: " .. tostring(err))
			end
		end
	end)

	-- A CRACK IS A PLACE AS WELL AS A MOMENT. The panel is opened by a prompt
	-- and closed by a tap, and neither of those notices somebody walking
	-- away, dying, or being carried off by a patrol car -- so the one thing
	-- that binds the attempt to the lawn it is happening on is polled.
	--
	-- Measured against STEAL_RANGE with slack, because that is the radius the
	-- prompt itself uses: an attempt should survive shuffling on the spot and
	-- end the moment somebody actually leaves.
	task.spawn(function()
		while true do
			task.wait(Config.DOG_WATCH.pollRate)
			for thief, crack in pairs(cracking) do
				local root = getRoot(thief)
				local piggy = crack.plot and crack.plot.piggy and crack.plot.piggy.body
				if not root or not piggy then
					endCrack(thief, "gone")
				elseif (root.Position - piggy.Position).Magnitude > Config.STEAL_RANGE + 4
					or (crack.plot ~= nil and crack.plot.shop ~= nil
						and not inShopRoom(thief, crack.plot)) then
					-- AND ON A SHOP, THE ROOM IS THE RANGE. A vault stands on
					-- a back wall two studs from the grass behind it, so a
					-- distance alone would let an attempt carry on from
					-- outside the building it is supposed to be happening in.
					-- Polled here rather than only checked at the door, for
					-- the reason this whole binding exists: an attempt is a
					-- PLACE as well as a moment.
					endCrack(thief, "range")
				else
					-- BEING HOME MEANS SOMETHING NOW, AND THIS IS WHAT THE DOG
					-- STOOD DOWN FOR.
					--
					-- `releaseDog` returns early when the owner is home -- the dog
					-- barks and marks and never chases -- because two things that
					-- can both hard-stop one thief on one lawn is how a plot
					-- becomes a wall. That was the right call and it left the
					-- owner with NOTHING: being robbed while standing on your own
					-- grass was a toast, a screen flash, and the option to chase
					-- somebody who already had the money.
					--
					-- So the owner is the defence, and reaching your own lock is
					-- how you use it.
					--
					-- IT ENDS THE CRACK AND TAKES NOTHING, which is what keeps it
					-- inside "defence buys TIME, never immunity". The thief walks
					-- away with every slice they already landed -- exactly as a
					-- miss or a walk-away leaves them -- so an owner arriving is a
					-- partial outcome rather than a robbery undone. What it costs
					-- the thief is the slices they had not taken yet, and those
					-- are the big ones: the ladder grows 1.4x a step, so an
					-- interruption at slice three costs more than the three it
					-- keeps.
					--
					-- NO STUN, NO ALARM, NO CONFISCATION. Each of those is a
					-- SECOND hard stop and the rule above forbids stacking them.
					-- The owner gets the interruption and the thief keeps their
					-- legs; if they want the coins back they have to nab, which is
					-- its own contest with its own counterplay.
					--
					-- A RESIDENT CANNOT DO THIS, and that is not an oversight. A
					-- resident's owner is never home by construction, which is the
					-- whole reason an unclaimed plot is the low-pressure income
					-- this economy runs on. `asPlayer` returns nil for one and the
					-- branch is skipped.
					local owner = crack.plot and crack.plot.owner
					if owner and owner ~= thief and owner.Parent then
						local ownerRoot = getRoot(owner)
						if ownerRoot
							and (ownerRoot.Position - piggy.Position).Magnitude
								<= Config.OWNER_INTERRUPT_RANGE then
							endCrack(thief, "chased")
							notify(thief, ("%s got to the lock! You had to run.")
								:format(owner.DisplayName), "warn")
							notify(owner, "You broke it up! They had to leave.", "good")
						end
					end
				end
			end
		end
	end)

	-- Range check. Polled rather than event-driven because the thief can
	-- arrive by any route, and four times a second is plenty for a footrace.
	--
	-- IT IS THE DELIVERY. The circle is DROPOFF_RADIUS round the pig itself
	-- (not the old sixteen round the plot), drawn on the client as a glowing
	-- ring, so the thief still walks right up to the thing the coins live in.
	--
	-- PUSHED ON THE EDGE, NEVER ON THE TICK. `inRange` is kept on the carry
	-- record so this can fire a push only when the answer CHANGES -- four
	-- FireClients a second per carrier, forever, to repeat a boolean nobody
	-- asked about again is the shape of thing that is invisible until a
	-- server is full.
	task.spawn(function()
		while true do
			task.wait(0.25)
			for thief, carry in pairs(carrying) do
				local action = dropAction(thief, carry)
				if action then
					-- ARRIVING IS THE DELIVERY. Walking into the ring banks the
					-- haul; there is no button to press.
					settleOnArrival(thief)
					continue
				end
				local canReturn = returnPlot(carry) ~= nil
				if action ~= carry.dropAction or canReturn ~= carry.returnAvailable then
					carry.dropAction, carry.returnAvailable = action, canReturn
					carry.inRange = action ~= nil
					pushCarryState(thief)
				end
			end
		end
	end)
end

-- ============================================================
-- A NEIGHBOUR ROBBING SOMEBODY
-- ============================================================
--
-- `ResidentService` owns the walk, the decision and the loot in their arms;
-- this owns THE COINS. That split is the whole design, and it is deliberately
-- not the `Target` union one level up.
--
-- WHY A RESIDENT THIEF IS NOT A `Target`. `Target = Player | Resident`
-- generalises the VICTIM axis, and it earns its keep at nine accessors. The
-- THIEF axis is `Player` in about thirty places -- `carrying`, `dropShield`,
-- `currentSpeed`, the dodge, the stun, the shield, bail, the hot bar -- and a
-- resident has none of those: no Humanoid, no WalkSpeed, no save, nothing to
-- confiscate. Widening it would be twenty branches for one caller, which is
-- exactly the trade the target abstraction's own note refuses in the other
-- direction.
--
-- WHAT MUST NOT BE DUPLICATED IS THE ACCOUNTING. `Config.LOSS_CAP` and the
-- `losses` window are the protection standing between a real child and being
-- emptied, and a second copy of that arithmetic is the near-identical
-- duplicate this file records for the mini piggy and `RideSound` -- except
-- this one drifts into taking a child's coins past their cap. So a neighbour
-- takes coins through the same `lossAllowance` a player's crack does, and the
-- answer it gets back is what the cap ACTUALLY allowed rather than what it
-- asked for.

-- Whoever's piggy bank this plot is: the player who owns it, or the resident
-- standing on it. Nil for a plot with neither, which is a plot mid-handover.
local function occupantOf(plot: any): Target?
	if plot.owner then
		return plot.owner
	end
	return ResidentService.get(plot)
end

-- Takes up to `want` coins out of `plot`'s pig on a resident's behalf, and
-- answers how much actually moved.
function HeistService.residentTake(plot: any, want: number, thiefName: string): number
	local victim = occupantOf(plot)
	if not victim or want <= 0 then
		return 0
	end

	local balance = targetCoins(victim)
	-- THE CAP IS ASKED, NEVER ASSUMED. A resident is exempt from `LOSS_CAP`
	-- as a VICTIM and that exemption is about who is being robbed, not about
	-- who is doing the robbing -- so a player on the other end of this is
	-- protected by exactly the allowance any thief is held to.
	local amount = math.floor(math.min(want, lossAllowance(victim, balance), balance))
	if amount <= 0 then
		return 0
	end

	local resident = asResident(victim)
	if resident then
		return ResidentService.take(resident, amount)
	end

	local player = victim :: Player
	local data = DataService.get(player)
	if not data then
		return 0
	end
	data.coins -= amount
	local entry = losses[victim]
	if entry then
		entry.lost += amount
	end
	PlotService.updatePile(plot, data.coins, Config.pigFullAt(data.rebirths))

	-- SAID OUT LOUD, because a balance that drops with nothing on screen is
	-- indistinguishable from a bug -- and because the answer to this is a
	-- verb the player already knows. They are being told so they can go and
	-- TAG the neighbour, which is the whole reason a resident carries the
	-- loot home slowly and visibly rather than banking it where it stood.
	notify(player, ("%s is robbing your piggy bank! Nab them before they get home."):format(
		thiefName), "alarm")
	return amount
end

-- Coins that never made it home. The exact inverse of the take, through the
-- one function that already owns putting coins back.
function HeistService.residentGiveBack(plot: any, amount: number)
	local victim = occupantOf(plot)
	if victim and amount > 0 then
		giveBack(victim, amount)
	end
end

return HeistService
