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
	never a house, a skin or an upgrade.

	THE THIEF'S REWARD IS NOT THE VICTIM'S LOSS. A delivered haul is worth
	Config.HEIST_PAYOUT times what the victim lost (triple on revenge), plus
	loot, the currency the accessory collection costs. Bail, the rap sheet
	and totalStolen all measure the victim's figure. Stolen coins land in the
	thief's own pig and are stealable in turn, so the loot stays in play.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local PiggyBank = require(script.Parent.PiggyBank)
local UpgradeService = require(script.Parent.UpgradeService)
local SocialService = require(script.Parent.SocialService)
local GuardDog = require(script.Parent.GuardDog)
local EventService = require(script.Parent.EventService)
-- For the loot a delivery pays. SetService requires DataService and nothing
-- else, so this cannot be a cycle.
local SetService = require(script.Parent.SetService)
-- The neighbours on every unclaimed plot. Requires DataService and
-- PlotService and nothing else -- in particular it does not require this
-- file, so the dependency runs one way only.
local ResidentService = require(script.Parent.ResidentService)

local HeistService = {}

-- When each thief started holding a steal prompt, per victim plot.
--
-- The prompt's HoldDuration is one server-side property, but the real
-- required hold depends on the pair -- the victim's locks against the
-- thief's lockpicks. So the client shortens its own prompt for
-- responsiveness and the server times the hold itself and rejects anything
-- faster than that thief is entitled to. A client that sets HoldDuration to
-- zero gets a rejection, not free money.
local holdStarted: { [Player]: { plot: any, at: number } } = {}
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

local function targetCapacity(target: Target): number
	local player = asPlayer(target)
	if player then
		local data = DataService.get(player)
		return Config.getCapacity(if data then data.capacityLevel else 0)
	end
	return ResidentService.getCapacity(target :: ResidentService.Resident)
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

type Carry = {
	amount: number,
	victim: Target,
	loot: Model,
	highlight: Highlight,
	prompt: ProximityPrompt,
}

local carrying: { [Player]: Carry } = {}
-- When each player's join shield lapses, in os.clock() seconds.
local shieldUntil: { [Player]: number } = {}

-- WHAT EACH VICTIM HAS LOST IN THE CURRENT WINDOW. Keyed per victim and never
-- per thief, because a per-thief cap is no protection when seven of them take
-- turns. `since` is when the window opened; it re-opens once
-- Config.LOSS_CAP.window has passed. See lossAllowance.
-- Residents never appear in here. See `lossAllowance`.
local losses: { [Target]: { since: number, lost: number } } = {}

-- WHO HOLDS A GRUDGE AGAINST WHOM: [victim][thief] -> os.clock() expiry.
-- Written on a delivery, read when the victim robs that thief back inside
-- Config.REVENGE.window, and cleared the moment it pays out.
local grudge: { [Player]: { [Player]: number } } = {}

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
		entry = { since = now, lost = 0 }
		losses[victim] = entry
	end
	local allowance = Config.LOSS_CAP.fraction * (balance + entry.lost) - entry.lost
	return math.max(0, math.floor(allowance))
end

-- Coins that went home again -- a tag, a confiscation, a death -- were never
-- lost, so they come off the victim's window.
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
local function giveBack(victim: Target, amount: number)
	local resident = asResident(victim)
	if resident then
		-- Straight back into the pig it came out of. ResidentService owns
		-- republishing the pile, so the street sees it land.
		ResidentService.refund(resident, amount)
		return
	end

	local player = victim :: Player
	local victimData = DataService.get(player)
	if not victimData then
		return
	end
	victimData.coins += amount
	refund(victim, amount)
	local plot = PlotService.getPlot(player)
	if plot then
		PlotService.updatePile(plot, victimData.coins, Config.getCapacity(victimData.capacityLevel))
	end
end

local GOLD = Color3.fromRGB(238, 194, 72)

local function notify(player: Player, message: string, kind: string)
	Remotes.get("Notify"):FireClient(player, message, kind)
end

local function format(value: number): string
	local suffixes = { "", "K", "M", "B", "T" }
	local n = math.floor(value)
	local tier = 1
	while n >= 1000 and tier < #suffixes do
		n /= 1000
		tier += 1
	end
	if tier == 1 then
		return tostring(math.floor(n))
	end
	return ("%.1f%s"):format(n, suffixes[tier])
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function pushCarryState(player: Player)
	local carry = carrying[player]
	Remotes.get("CarryUpdate"):FireClient(player, if carry then math.floor(carry.amount) else 0)
end

-- ============================================================
-- ELIGIBILITY
-- ============================================================

-- Returns nil if the grab is allowed, or a player-facing reason if not.
-- Every one of these is re-checked server-side on the trigger; the client
-- only decides which prompt to draw.
local function whyCannotSteal(thief: Player, victim: Target): string?
	if (thief :: any) == victim then
		return "That's your own piggy."
	end
	if carrying[thief] then
		return "You're already carrying loot. Take it home first."
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

	-- The per-victim cooldown DOES apply to a resident. It is what stops a
	-- thief standing on one lawn farming the same pig, and that is exactly as
	-- true of an empty house as of a real one -- the anti-camping job the
	-- retired `STEAL_MAX_PER_VICTIM` used to share.
	local last = (lastGrab[victim] and lastGrab[victim][thief]) or -math.huge
	local wait = Config.STEAL_COOLDOWN - (os.clock() - last)
	if wait > 0 then
		return ("Wait %ds before robbing %s again."):format(math.ceil(wait), name)
	end

	local coins = targetCoins(victim)
	if math.floor(coins) <= 0 then
		return ("%s's piggy is empty."):format(name)
	end

	-- The loss cap, named. A cap the thief cannot see reads as stealing being
	-- broken, and this is the one refusal that is about the VICTIM's hour
	-- rather than the thief's own cooldown.
	if lossAllowance(victim, coins) <= 0 then
		return ("%s has been robbed enough for now."):format(name)
	end

	return nil
end

-- ============================================================
-- CARRY VISUALS
-- ============================================================

-- Hands the thief a miniature of the VICTIM's piggy, wearing the victim's own
-- skin, held out in front of them where everyone can see it.
--
-- This used to be an abstract glowing ball floating over the thief's head.
-- Carrying somebody's actual piggy makes a chase legible from across the
-- street: you can see who is being robbed, not just that someone is running.
local function attachLoot(thief: Player, victim: Target, amount: number): (Model?, Highlight?, ProximityPrompt?)
	local root = getRoot(thief)
	if not root then
		return nil, nil, nil
	end

	-- A resident wears the default skin, which is what is standing on its own
	-- lawn -- `PlotService.release` sets exactly that. The miniature has to
	-- match the pig it came out of or the tell stops being one.
	local victimPlayer = asPlayer(victim)
	local victimData = if victimPlayer then DataService.get(victimPlayer) else nil
	local skinKey = if victimData then victimData.cosmetics.skin else Config.DEFAULT_SKIN
	local loot = PiggyBank.buildMini(skinKey)
	local body = loot.PrimaryPart :: BasePart

	-- Held in front of the chest, facing the way the thief runs. LookVector is
	-- -Z, so the pig is turned to match rather than staring backwards.
	loot:PivotTo(root.CFrame * CFrame.new(0, 0.3, -2.1) * CFrame.Angles(0, math.pi, 0))
	loot.Parent = root.Parent

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
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
	label.StudsOffset = Vector3.new(0, 2.2, 0)
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
	text.Text = ("%s's piggy  %s"):format(targetName(victim), format(amount))
	text.Parent = label

	-- Visible through walls: a thief must never be able to hide. The whole
	-- risk half of the trade depends on everyone being able to find them.
	local highlight = Instance.new("Highlight")
	highlight.FillColor = GOLD
	highlight.FillTransparency = 0.65
	highlight.OutlineColor = Color3.fromRGB(255, 120, 90)
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = thief.Character

	-- Anyone nearby can tag, not just the victim. Bystanders joining the
	-- chase is the bit that turns a robbery into a story.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TagPrompt"
	prompt.ActionText = "Tag Thief!"
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute(Config.PROMPT_KIND_ATTRIBUTE, "tag")
	prompt.ObjectText = thief.DisplayName
	prompt.HoldDuration = Config.TAG_HOLD
	prompt.MaxActivationDistance = Config.TAG_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	return loot, highlight, prompt
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

-- Cannot be tagged, caught or hit right now.
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

local function currentSpeed(player: Player): number
	-- A shock stops you dead. It outranks everything else, including boots.
	if isStunned(player) then
		return 0
	end

	local speed = Config.BASE_WALK_SPEED
	if carrying[player] then
		speed *= UpgradeService.getCarryMultiplier(player)
	end
	local snag = snagged[player]
	if snag and os.clock() < snag.until_ then
		speed *= snag.multiplier
	end
	speed *= rideMultiplier[player] or 1

	-- TIPTOE, and the two things it REFUSES to combine with are what make the
	-- whole mechanic safe rather than a hole in it.
	--
	-- NEVER WHILE CARRYING. The ordering the guard dog's `notice` speeds are
	-- built on is: tiptoe max (9.6) < notice < carry speed (12 to 16). Let a
	-- tiptoe multiply the carry penalty instead and it is 12 x 0.35 = 4.2,
	-- comfortably UNDER every threshold -- so a thief could creep home past
	-- the dog with the pig in their arms and the entire risk half of the
	-- trade would evaporate. You sneak IN; you never sneak the money OUT, and
	-- that is the rule this line enforces rather than merely describes.
	--
	-- NEVER WHILE CLIMBING, because two slows multiplied produce a number
	-- nobody designed: 0.35 x CLIMB_MULTIPLIER 0.35 is 0.12, about two studs
	-- a second, which is seven seconds to climb an eight-stud fence. That is
	-- the multiplicative-slow trap this project keeps recording, and a ladder
	-- is not somewhere anybody is being stealthy anyway.
	if tiptoeing[player] and not carrying[player] and not isClimbing(player) then
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
	end
end

local function setCarrySpeed(player: Player, _carryingLoot: boolean)
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
	if carrying[player] then
		return "Can't ride while you're carrying loot."
	end

	-- NOBODY rides while loot is in transit, not just the two players
	-- involved.
	--
	-- Blocking only the victim left a hole big enough to drive a scrambler
	-- through: any BYSTANDER could stay mounted at 33.6 and run down a thief
	-- doing 12, and HeistService.tag lets anyone tag. That is not a chase, it
	-- is an execution, and it made robbery in a busy server pointless.
	--
	-- Server-wide is also the version that reads as a rule rather than as a
	-- restriction: when the alarm goes, the whole street is on foot. A carry
	-- lasts only a few seconds, so the cost is small and the drama is free.
	if HeistService.anyoneCarrying() then
		if carrying[player] then
			return "Can't ride while you're carrying loot."
		end
		for _, carry in pairs(carrying) do
			if carry.victim == player then
				return "Can't ride while you're being robbed. Go tag them."
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
		notify(player, "Not from inside a bin. Push a direction to climb out.", "warn")
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
end

-- Called by RideService and nobody else. 1 means on foot.
-- Start or stop sneaking. The server decides whether it is allowed; the
-- client only asks.
--
-- REFUSED WHILE CARRYING, which is the same guarantee `currentSpeed` already
-- enforces, made LOUD here instead of silent. A thief who grabs a pig while
-- tiptoeing has the sneak dropped out from under them, and being told so is
-- the difference between a rule and a bug: the button would otherwise go on
-- saying ON while they walked home at carry speed.
function HeistService.setTiptoe(player: Player, on: boolean)
	local want = on == true
	if want and carrying[player] then
		notify(player, "You cannot creep with a piggy bank in your arms.", "warn")
		want = false
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
function HeistService.nearestCarrier(from: Vector3, range: number, thrower: Player): (Player?, string?)
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

-- WHEN EACH PLAYER WAS LAST PRANKED. The one number that keeps an open aim
-- from being a harassment toy, and it is keyed by the person being HIT rather
-- than by the thrower: a thrower cooldown would be no protection at all,
-- since six players with plungers would simply take turns and the child in
-- the middle would never get to move. See Config.GADGET_FUN.
local prankedAt: { [Player]: number } = {}

function HeistService.canPrank(player: Player): boolean
	local at = prankedAt[player]
	return at == nil or os.clock() - at >= Config.GADGET_FUN.targetCooldown
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
function HeistService.nearestBystander(from: Vector3, range: number, thrower: Player): (Player?, string?)
	local best: Player? = nil
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
				if HeistService.canPrank(other) then
					if not bestDist or dist < bestDist then
						best, bestDist = other, dist
					end
				else
					cooling = true
				end
			end
		end
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
	return carrying[player] ~= nil
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
-- TWO HITS LIVE IN HERE and the branch between them is the whole design. A
-- target CARRYING LOOT takes the real thing, exactly as tuned: full duration,
-- full stun, raincoat in the way. Anybody else takes a PRANK -- a fraction of
-- the time, a capped stun, one per target per GADGET_FUN.targetCooldown, and
-- the raincoat never even looks at it.
--
-- Deciding it HERE rather than at the throw is what makes it honest across
-- the half-second of flight: somebody who picks loot up mid-flight catches
-- the real one, and a thief who delivers before it lands catches the joke
-- instead of nothing at all. The thrower cannot time their way around either.
function HeistService.applyGadget(target: Player, thrower: Player, spec: any): boolean
	-- Gone, dead, or hiding in a bin: the throw is refunded rather than
	-- landing on nobody.
	if not getRoot(target) or inBin[target] then
		return false
	end

	-- Checked BEFORE the raincoat, so a well-timed dodge does not burn a
	-- perfectly good coat that was never needed.
	if HeistService.isDodgeImmune(target) then
		notify(target, ("Dodged the %s!"):format(spec.name), "good")
		notify(thrower, ("%s dodged it."):format(target.DisplayName), "warn")
		return true
	end

	if carrying[target] then
		-- A raincoat stops the slows and nothing else.
		--
		-- Same shape as the Guard Duty Treat on the other side of this fight:
		-- cheap counters bounce, the expensive one gets through. It raises
		-- the price of stopping somebody from 1,500 to 22,000 rather than
		-- making them unstoppable, which is the only version that leaves both
		-- trees alive.
		--
		-- INSIDE the carrying branch on purpose. A coat is bought to survive
		-- a chase, and letting a 1,500-coin joke burn one would turn the
		-- cheapest item in the game into a way of stripping the defence off
		-- somebody who was not even robbing anybody yet.
		if warded[target] and (spec.stun or 0) <= 0 then
			warded[target] = nil
			for _, handler in ipairs(wardUsedHandlers) do
				task.spawn(handler, target, spec)
			end
			notify(target, ("The %s slid off your raincoat!"):format(spec.name), "good")
			notify(thrower, ("%s was wearing a raincoat. It bounced off."):format(target.DisplayName), "warn")
			return true
		end

		applySlow(target, {
			label = spec.name,
			slow = spec.slow,
			duration = spec.duration,
			stun = spec.stun or 0,
		})

		notify(target, spec.hit or ("Hit by a %s!"):format(spec.name), "warn")
		return true
	end

	-- THE PRANK. Re-tested here and not only at the throw, because half a
	-- second of flight is long enough for somebody else's to have landed
	-- first -- and two people freezing one player back to back is the exact
	-- thing the cooldown exists to stop.
	if not HeistService.canPrank(target) then
		return false
	end
	prankedAt[target] = os.clock()

	applySlow(target, {
		label = spec.name,
		slow = spec.slow,
		duration = Config.GADGET_FUN.duration,
		stun = math.min(spec.stun or 0, Config.GADGET_FUN.stunCap),
	})

	-- NAMES THE THROWER, which the serious hit deliberately does not. The
	-- whole point of a prank is throwing one back, and an unexplained wobble
	-- with nobody attached to it reads as lag.
	local line = if spec.prank
		then (spec.prank):format(thrower.DisplayName)
		else ("%s got you with a %s!"):format(thrower.DisplayName, spec.name)
	notify(target, line, "prank")
	return true
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
	zone: number,      -- 0..1 along the dial
	width: number,     -- 0..1
	lastTap: number,
	ending: boolean,
}

local cracking: { [Player]: Crack } = {}

-- Where the marker sits at server time `t`, 0..1.
--
-- It PING-PONGS rather than wrapping, so a missed pass is not a missed step
-- -- the marker comes back. Wrapping would teleport it from the right edge
-- to the left, which reads as the dial resetting rather than as a sweep.
local function markerAt(crack: Crack, t: number): number
	local sweep = Config.CRACK.sweepSeconds
	local phase = (t - crack.stepStart) % (sweep * 2)
	return if phase <= sweep then phase / sweep else 2 - phase / sweep
end

-- Rolls the zone for the next slice and restarts the sweep.
--
-- The zone never starts at the very left, and that is not decoration: the
-- marker is at 0 the instant a step arms, so a zone touching 0 would be
-- landable by a tap already in flight. CRACK_MIN_OFFSET is about two tenths
-- of a second of travel, which is the marker having to actually reach the
-- target before anybody can claim it.
local function armStep(crack: Crack)
	local window = Config.getCrackWindow(crack.steps + 1, crack.locks, crack.picks)
	crack.width = math.clamp(window / Config.CRACK.sweepSeconds, 0.05, 1 - CRACK_MIN_OFFSET)
	crack.zone = CRACK_MIN_OFFSET + math.random() * (1 - crack.width - CRACK_MIN_OFFSET)
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
	local want = math.floor(crack.pig0
		* Config.getCrackSlice(crack.steps + 1, crack.sack)
		* EventService.getStealMultiplier())
	return math.max(0, math.min(want, lossAllowance(crack.victim, live), live))
end

local function pushCrack(thief: Player, crack: Crack?)
	if not crack then
		Remotes.get("CrackState"):FireClient(thief, nil)
		return
	end
	Remotes.get("CrackState"):FireClient(thief, {
		victim = targetName(crack.victim),
		-- The gauge: a pig that was this full, this much of it already in
		-- your hands, and a floor at the point Config.LOSS_CAP stops you. A
		-- resident's floor is zero, which is the cap not applying drawn
		-- rather than stated.
		pig = crack.pig0,
		banked = crack.banked,
		floor = math.max(0, crack.pig0 - crack.allowance0),
		step = crack.steps + 1,
		maxSteps = Config.CRACK.maxSteps,
		slice = sliceWorth(crack),
		zone = crack.zone,
		width = crack.width,
		startedAt = crack.stepStart,
		sweep = Config.CRACK.sweepSeconds,
	})
end

-- Repaints the figure over the carried piggy. It is written once by
-- attachLoot and then again after every slice, because the thing in a
-- thief's hands is a running total now.
local function setLootAmount(carry: Carry, victim: Target)
	local body = carry.loot and carry.loot.PrimaryPart
	local label = body and body:FindFirstChild("LootLabel")
	local text = label and label:FindFirstChild("Amount")
	if text and text:IsA("TextLabel") then
		text.Text = ("%s's piggy  %s"):format(targetName(victim), format(carry.amount))
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

local function releaseDog(thief: Player, victim: Target, plot: any)
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
		GuardDog.bark(plot.dog)
		markIntruder(thief)
		notify(thief, ("%s's dog has spotted you!"):format(targetName(victim)), "chase")
		notifyTarget(victim, "Your dog is barking at somebody on your lawn!", "alarm")
		return
	end
	-- The bark on the dog is a 3D sound that falls off with distance, which
	-- is right for the street and useless for the one player it is about:
	-- they are running AWAY from it. This is the same snarl, flat, for them.
	notify(thief, "A guard dog is chasing you!", "chase")
	GuardDog.chase(plot.dog, function(): BasePart?
		return getRoot(thief)
	end, function()
		-- CARRYING decides which ending this is, and it is asked at the
		-- CATCH rather than at the release. A dog let off by a fumbled slice
		-- may arrive at somebody who has since banked three more and is
		-- running for the gate, or at somebody standing empty-handed with
		-- nothing to drop -- and tag returns early with no loot, so without
		-- this the second case would be a dog that runs somebody down and
		-- then does nothing at all.
		if carrying[thief] then
			-- byDog is what the wording and the range check key off, so a
			-- resident standing in the tagger slot is never read as a
			-- player. A house with nobody in it still has a dog.
			HeistService.tag(victim :: any, thief, true)
		else
			HeistService.scare(thief, victim)
		end
	end)
end

-- Seen off rather than arrested. There is no loot to take, so the cost is
-- the attempt itself: the crack breaks and they are held still long enough
-- to have to make the whole approach again.
--
-- Being robbed has to stay survivable; so does FAILING to rob. A nine-year-
-- old who walks onto a lawn, fumbles a slice and gets nothing has already
-- paid, and taking coins they never had would be a debt for trying.
function HeistService.scare(thief: Player, victim: Target)
	endCrack(thief, "scared")
	notify(thief, ("%s's dog saw you off!"):format(targetName(victim)), "chase")
	notifyTarget(victim, "Your guard dog chased somebody off your lawn.", "good")
	HeistService.detain(thief, Config.DOG_WATCH.scareStun)
end

-- Ends an attempt and settles up. Every exit runs through here: a miss, the
-- fifth slice, the player pressing stop, walking out of range, being tagged,
-- being scared off, or leaving the server.
function endCrack(thief: Player, why: string)
	local crack = cracking[thief]
	if not crack or crack.ending then
		return
	end
	crack.ending = true
	cracking[thief] = nil
	pushCrack(thief, nil)

	local victim, plot, total = crack.victim, crack.plot, crack.banked

	if total > 0 then
		-- The per-victim cooldown is paid for by TAKING something. A thief
		-- who fumbles the first slice took nothing, so there is nothing to
		-- cool down and the plot is not spent -- what that attempt cost them
		-- is the dog, which is a steeper price and a more interesting one.
		lastGrab[victim] = lastGrab[victim] or {}
		lastGrab[victim][thief] = os.clock()
		Remotes.get("StealCooldown"):FireClient(thief, targetId(victim),
			workspace:GetServerTimeNow() + Config.STEAL_COOLDOWN)

		if plot then
			-- The plaster. A tell for the street and nothing else.
			PlotService.setRobbed(plot, Config.ROBBED_MARK_SECONDS)
		end

		-- Names what it is WORTH, which is the doubled figure: the number a
		-- thief is deciding whether to run for is the one they will bank.
		local worth = total * (if grudge[thief] and (grudge[thief][victim] or 0) > os.clock()
			then Config.REVENGE.payout else Config.HEIST_PAYOUT)
		if why == "done" then
			notify(thief, ("Cracked it clean! %s coins, worth %s at home. Run!"):format(
				format(total), format(worth)), "loot")
		elseif why ~= "lost" and why ~= "scared" then
			notify(thief, ("%d of %d slices. %s coins, worth %s at home. Run!"):format(
				crack.steps, Config.CRACK.maxSteps, format(total), format(worth)), "loot")
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
		notifyTarget(victim, ("%s is robbing you! Tag them!"):format(thief.DisplayName), "alarm")
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
	local grace = Config.CRACK.tapGrace / Config.CRACK.sweepSeconds
	local at = markerAt(crack, now)
	if at < crack.zone - grace or at > crack.zone + crack.width + grace then
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
		local loot, highlight, prompt = attachLoot(thief, victim, amount)
		if not loot or not highlight or not prompt then
			-- Character vanished mid-slice; put it back where it came from.
			giveBack(victim, amount)
			crack.banked -= amount
			endCrack(thief, "gone")
			return
		end
		carrying[thief] = {
			amount = amount,
			victim = victim,
			loot = loot,
			highlight = highlight,
			prompt = prompt,
		}

		-- THE FIRST SLICE IS THE GRAB, and everything the old code hung on a
		-- completed steal hangs here instead. You are a thief the moment a
		-- coin leaves somebody else's pig, not when the fifth one does.
		dropShield(thief)
		-- And you are visibly hauling a piggy bank, so the sneak is over.
		-- Dropped here rather than left to currentSpeed to ignore, because
		-- the client's button would otherwise go on saying ON.
		HeistService.setTiptoe(thief, false)
		setCarrySpeed(thief, true)
		pushCarryState(thief)

		prompt.Triggered:Connect(function(tagger)
			HeistService.tag(tagger, thief)
		end)
	end

	if crack.plot then
		PlotService.updatePile(crack.plot, targetCoins(victim), targetCapacity(victim))
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
-- IT READS SPEED, NOT A STEALTH FLAG, and that is the load-bearing half. A
-- boolean the dog has to check is a second piece of state that can disagree
-- with how fast somebody is actually moving; a threshold on speed cannot.
-- Everything else falls out for free -- a thief snagged on an electric fence
-- is quiet because they are slow, and a thief CARRYING is always loud,
-- because carry speed is above every tier's threshold by construction:
--
--     TIPTOE at max (9.6)  <  a dog's `notice`  <  CARRY_SPEED (12 to 16)
--
-- So you can sneak IN and you can never sneak the money OUT.
--
-- AND IT IS SPEED MEASURED, NEVER `WalkSpeed` READ. That distinction is the
-- whole feature: `WalkSpeed` is what a character is ALLOWED to do, so a
-- player standing perfectly still on a lawn reads 16 and would wake every dog
-- on the street for doing nothing at all. Standing still is never a crime
-- here, so the watcher differences positions between ticks and asks how far
-- somebody actually went.
local lastSeen: { [Player]: { pos: Vector3, at: number } } = {}

-- Under this, somebody is standing still. A parked character still drifts a
-- little -- idle animation, the ground settling, network jitter -- and the
-- Titan's `notice` of 0 means ANY movement, so without a floor the top breed
-- would be permanently woken by nobody moving. Well under a tiptoe (5.6).
local IDLE_SPEED = 0.5

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

		local notice = GuardDog.noticeSpeed(dog)
		if not notice then
			continue
		end

		-- The LOUDEST intruder, not the first found. Two thieves on one lawn
		-- and the dog goes for the one making noise rather than for whichever
		-- happened to be earlier in a hash order -- which would also make the
		-- choice differ between ticks for no reason anybody could see.
		local loudest: Player? = nil
		local loudestSpeed = -1
		for player, yard in pairs(yards) do
			if yard == plot and player ~= owner then
				local speed = speeds[player] or 0
				if speed > IDLE_SPEED and speed > notice and speed > loudestSpeed then
					loudest, loudestSpeed = player, speed
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
			local victim: Target? = owner or ResidentService.get(plot)
			if victim then
				releaseDog(loudest, victim, plot)
			end
		end
	end
end

local function clearCarry(thief: Player): Carry?
	-- ANYTHING THAT TAKES THE LOOT ENDS THE ATTEMPT. A thief tagged, arrested
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

	if carry.loot then
		carry.loot:Destroy()
	end
	if carry.highlight then
		carry.highlight:Destroy()
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
-- proximity check and whose "tagger" may be nowhere near).
function HeistService.tag(tagger: Player, thief: Player, byDog: boolean?)
	-- YOU CANNOT TAG YOURSELF, AND THE PROMPT IS ON YOUR OWN BODY, so this is
	-- not a guard against a forged remote -- it is the default state of every
	-- robbery in the game. `attachLoot` welds the loot to the THIEF's own root
	-- and parents the tag prompt to it, deliberately, because the prompt
	-- exists so that everybody ELSE can reach it. The side effect is that the
	-- one player who must never press it stands permanently at distance zero,
	-- well inside `TAG_DISTANCE`, with `RequiresLineOfSight` off -- so a
	-- carrying thief has "Tag Thief!" over their own name for the whole
	-- getaway.
	--
	-- WHAT IT COSTS IS NOT AN EXPLOIT, and that is worth being exact about
	-- rather than overstating it: a self-tag returns the coins to the victim
	-- and stuns the thief, so it is pure self-harm and profits nobody. It
	-- still has to go, for two reasons. A nine-year-old with a stray thumb
	-- loses an entire robbery to a button the game should never have offered
	-- them -- the same argument the last-copy sell guard makes. And the
	-- messages it produces are nonsense in both directions: the thief is told
	-- "you dropped the loot" AND "nice tag!" in the same second, because
	-- `tagger ~= victim` is true when the tagger is the thief, and the victim
	-- is told somebody tagged themselves.
	--
	-- Same shape as the wheelie bin, where the occupant is refused their own
	-- OPEN prompt. Silent, because a legitimate client no longer asks: the
	-- prompt is disabled on the thief's own machine, so anything reaching
	-- here is forged.
	if tagger == thief then
		return
	end

	local carry = carrying[thief]
	if not carry then
		return
	end

	-- Dodged. Costs the tagger their whole TAG_HOLD and they must start again,
	-- which is the entire point: the immunity is paid for in the currency of
	-- the chase rather than in coins.
	if HeistService.isDodgeImmune(thief) then
		notify(thief, "Dodged!", "good")
		if not byDog then
			notify(tagger, ("%s dodged you!"):format(thief.DisplayName), "warn")
		end
		return
	end

	if not byDog then
		local taggerRoot, thiefRoot = getRoot(tagger), getRoot(thief)
		if not taggerRoot or not thiefRoot then
			return
		end
		-- Re-check distance server-side; the prompt's range is a client hint.
		if (taggerRoot.Position - thiefRoot.Position).Magnitude > Config.TAG_DISTANCE + 6 then
			return
		end
	end

	local victim = carry.victim
	local amount = carry.amount
	clearCarry(thief)

	-- Coins go home to the victim, not to the tagger. Tagging is defence,
	-- never a way to launder someone else's money into your own pig.
	giveBack(victim, amount)
	do
		notifyTarget(victim, if byDog
			then ("Your guard dog caught %s. %s coins saved!"):format(thief.DisplayName, format(amount))
			else ("%s tagged %s. Your %s coins are back!"):format(targetName(tagger), thief.DisplayName, format(amount)),
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
		then "A guard dog got you! You dropped the loot."
		else ("Tagged by %s! You dropped the loot."):format(tagger.DisplayName),
		"bad")
	if (tagger :: any) ~= victim and not byDog then
		notify(tagger, ("Nice tag! You saved %s's coins."):format(targetName(victim)), "good")
	end
end

-- ============================================================
-- CONFISCATION
-- ============================================================

-- Takes the loot off a thief on the patrol's behalf and sends it home.
--
-- Deliberately NOT HeistService.tag with one more flag. A tag is a player or a
-- dog defending a plot, and the range re-check, the "nice tag" thanks and the
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
function HeistService.confiscate(thief: Player): (number, Target?)
	local carry = carrying[thief]
	if not carry then
		return 0, nil
	end

	local victim, amount = carry.victim, carry.amount
	clearCarry(thief)

	-- Home to the victim, exactly as a tag would. The patrol is not a second
	-- thief and coins do not disappear into it.
	giveBack(victim, amount)

	return amount, victim
end

-- Thief reached their own plot: the loot becomes theirs, in their pig.
local function deliver(thief: Player)
	local carry = carrying[thief]
	if not carry then
		return
	end

	local data = DataService.get(thief)
	if not data then
		return
	end

	local amount = carry.amount
	local victim = carry.victim
	clearCarry(thief)

	-- REVENGE. The thief is robbing back somebody who robbed THEM inside the
	-- window: the payout steps up and the grudge is spent. Read before the
	-- coins move so the multiplier is decided by the state at delivery, and
	-- cleared so a second robbery of the same person is an ordinary one.
	local mine = grudge[thief]
	local revenge = mine ~= nil and (mine[victim] or 0) > os.clock()
	if revenge and mine then
		mine[victim] = nil
	end

	-- STOLEN COINS COUNT DOUBLE (triple on revenge). The extra is minted, not
	-- taken from the victim -- see Config.HEIST_PAYOUT for why the thief's
	-- reward had to stop being the victim's loss.
	--
	-- Allowed to overflow capacity: income stops above the cap anyway, so an
	-- overfull pig is self-limiting, and it is the juiciest target on the
	-- street, which is exactly the tension a robbery should create.
	local payout = if revenge then Config.REVENGE.payout else Config.HEIST_PAYOUT

	-- ROBBERIES IN A ROW ARE WORTH MORE. Read BEFORE `recordSteal` below,
	-- which is what bumps the run -- so the delivery that starts a spree pays
	-- the plain rate and the one after it pays more, which is what a streak
	-- means. See Config.SPREE.
	--
	-- It multiplies the revenge payout too rather than replacing it: they are
	-- different things being rewarded (who you robbed, and how fast you are
	-- working), and a thief who lines up a revenge hit in the middle of a run
	-- has done both.
	payout *= SocialService.getSpreeMultiplier(thief)

	local banked = math.floor(amount * payout)
	data.coins += banked
	data.totalStolen += amount
	-- The first delivery retires the onboarding line, for good and on every
	-- future session, because `totalStolen` is what it is derived from.
	thief:SetAttribute(Config.PLAYER_FIRST_JOB_ATTRIBUTE, false)
	-- The rap sheet, which is a different number from the lifetime one above:
	-- MOST WANTED is a contest within one session, so it has to be winnable by
	-- somebody who joined ten minutes ago. See SocialService.recordSteal.
	-- Both measure what the VICTIM lost, never the doubled figure.
	SocialService.recordSteal(thief, amount)

	local victimPlayer = asPlayer(victim)
	local victimData = if victimPlayer then DataService.get(victimPlayer) else nil
	if victimData then
		victimData.totalLost += amount
	end

	local plot = PlotService.getPlot(thief)
	if plot then
		PlotService.updatePile(plot, data.coins, Config.getCapacity(data.capacityLevel))
		PlotService.playBank(plot)
	end

	-- LOOT, granted silently and named in the delivery line, so one card
	-- carries both currencies -- the same rule the events follow.
	local loot = Config.LOOT.delivery + (if revenge then Config.REVENGE.loot else 0)
	SetService.award(thief, loot, nil)

	-- A BONUS NOBODY IS TOLD ABOUT IS A BONUS NOBODY BELIEVES, so the run is
	-- named in the line that reports the money rather than in a card of its
	-- own -- the same rule the event tokens follow, where one card carries
	-- both currencies. `steps` is read AFTER recordSteal, so it names the run
	-- this delivery has just extended rather than the one it started from.
	local runNow = SocialService.getSpree(thief)
	local runNote = if runNow > 1 then (" %dx IN A ROW!"):format(runNow) else ""
	notify(thief, if revenge
		then ("REVENGE! %s stolen coins, worth %s to you. +%d %s.%s"):format(
			format(amount), format(banked), loot, Config.lootWord(loot), runNote)
		else ("Delivered %s stolen coins, worth %s to you. +%d %s.%s"):format(
			format(amount), format(banked), loot, Config.lootWord(loot), runNote),
		"money")
	notifyTarget(victim, ("%s got away with %s of your coins. Get them back for triple!"):format(
		thief.DisplayName, format(amount)), "bad")

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
		grudge[victimPlayer] = grudge[victimPlayer] or {}
		grudge[victimPlayer][thief] = os.clock() + Config.REVENGE.window
		SocialService.markRevenge(victimPlayer, thief)
	end
end

-- ============================================================
-- LIFECYCLE
-- ============================================================

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
			giveBack(carry.victim, carry.amount)
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
	return carrying[player] ~= nil
end

function HeistService.start()
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

	for _, plot in ipairs(PlotService.getAll()) do
		local prompt = plot.piggy.stealPrompt

		prompt.PromptButtonHoldBegan:Connect(function(thief)
			holdStarted[thief] = { plot = plot, at = os.clock() }
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
		-- Triggered below validates both which plot it belongs to and how
		-- long ago it started.

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
			-- by a stray remote.
			local started = holdStarted[thief]
			holdStarted[thief] = nil

			-- Never fail silently. A rejection the player cannot see is
			-- indistinguishable from a broken game, which is exactly how the
			-- bug above went unnoticed.
			if not started or started.plot ~= plot then
				notify(thief, "Hold the prompt to get at the lock.", "warn")
				return
			end
			local held = os.clock() - started.at
			if held < (Config.CRACK.openHold - HOLD_TOLERANCE) or held > Config.CRACK.openHold + 30 then
				notify(thief, "The lock held. Try again.", "warn")
				return
			end

			HeistService.attemptSteal(thief, victim)
		end)
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
			giveBack(carry.victim, carry.amount)
			carrying[player] = nil
		end

		shieldUntil[player] = nil
		tiptoeing[player] = nil
		marked[player] = nil
		losses[player] = nil
		grudge[player] = nil
		for _, held in pairs(grudge) do
			held[player] = nil
		end
		holdStarted[player] = nil
		lastSeen[player] = nil
		snagged[player] = nil
		rideMultiplier[player] = nil
		warded[player] = nil
		prankedAt[player] = nil
		burst[player] = nil
		dodgeUntil[player] = nil
		dodgeImmuneUntil[player] = nil
		lastDodge[player] = nil
		lastGrab[player] = nil
		for _, byThief in pairs(lastGrab) do
			byThief[player] = nil
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
				elseif (root.Position - piggy.Position).Magnitude > Config.STEAL_RANGE + 4 then
					endCrack(thief, "range")
				end
			end
		end
	end)

	-- Delivery check. Polled rather than event-driven because the thief can
	-- arrive by any route, and four times a second is plenty for a footrace.
	task.spawn(function()
		while true do
			task.wait(0.25)
			for thief in pairs(carrying) do
				local plot = PlotService.getPlot(thief)
				local root = getRoot(thief)
				if plot and root then
					local flat = Vector3.new(root.Position.X, plot.base.Position.Y, root.Position.Z)
					if (flat - plot.base.Position).Magnitude <= Config.DROPOFF_RADIUS then
						deliver(thief)
					end
				end
			end
		end
	end)
end

return HeistService
