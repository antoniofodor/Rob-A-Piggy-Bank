--!strict
--[[
	HeistService

	Stealing, carrying, tagging, and delivering loot.

	The rule that shapes everything here: only *uncollected* coins can be
	taken. Anything a player has banked is permanently safe. That means a
	robbery costs the victim a few minutes of idle income and never costs
	them progress -- which is what keeps this from being a bullying
	simulator, and it's why the caps below are hard limits rather than
	discouragements.

	Stolen coins land in the thief's own vault, not their bank. They're
	stealable in turn until the thief walks over and banks them, so the same
	rule applies to everyone and the loot stays in play.
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

type Carry = {
	amount: number,
	victim: Player,
	loot: Model,
	highlight: Highlight,
	prompt: ProximityPrompt,
}

local carrying: { [Player]: Carry } = {}
local joinedAt: { [Player]: number } = {}

-- [victim][thief] -> os.clock() of last grab, and count this session.
local lastGrab: { [Player]: { [Player]: number } } = {}
local grabCount: { [Player]: { [Player]: number } } = {}

-- Live servers get the full grace period. A Studio playtest would otherwise
-- spend its first 15 minutes unable to rob anything, which reads as "stealing
-- is broken" rather than "you are protected" -- and that is a bad way to find
-- out whether stealing actually works.
local SHIELD_SECONDS = if RunService:IsStudio() then 15 else Config.NEW_PLAYER_SHIELD

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
local function whyCannotSteal(thief: Player, victim: Player): string?
	if thief == victim then
		return "That's your own piggy."
	end
	if carrying[thief] then
		return "You're already carrying loot. Take it home first."
	end

	local shieldRemaining = (joinedAt[victim] or 0) + SHIELD_SECONDS - os.clock()
	if shieldRemaining > 0 then
		return ("%s is still protected for %d min."):format(victim.DisplayName, math.ceil(shieldRemaining / 60))
	end

	local count = (grabCount[victim] and grabCount[victim][thief]) or 0
	if count >= Config.STEAL_MAX_PER_VICTIM then
		return ("You've robbed %s enough this round. Find another target."):format(victim.DisplayName)
	end

	local last = (lastGrab[victim] and lastGrab[victim][thief]) or -math.huge
	local wait = Config.STEAL_COOLDOWN - (os.clock() - last)
	if wait > 0 then
		return ("Wait %ds before robbing %s again."):format(math.ceil(wait), victim.DisplayName)
	end

	local data = DataService.get(victim)
	if not data or math.floor(data.vault) <= 0 then
		return ("%s's piggy is empty."):format(victim.DisplayName)
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
local function attachLoot(thief: Player, victim: Player, amount: number): (Model?, Highlight?, ProximityPrompt?)
	local root = getRoot(thief)
	if not root then
		return nil, nil, nil
	end

	local victimData = DataService.get(victim)
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

	local label = Instance.new("BillboardGui")
	label.Size = UDim2.new(0, 170, 0, 40)
	label.StudsOffset = Vector3.new(0, 2.2, 0)
	label.AlwaysOnTop = true
	label.Parent = body

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = GOLD
	text.TextStrokeTransparency = 0.2
	-- Names the owner, so a bystander knows whose side to take.
	text.Text = ("%s's piggy  %s"):format(victim.DisplayName, format(amount))
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
		-- Jump has to go too. WalkSpeed 0 alone still lets a stunned thief hop
		-- the fence they just got shocked by.
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
local stealHandlers: { (Player, Player, number) -> () } = {}

function HeistService.onSteal(handler: (Player, Player, number) -> ())
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
local function clearCarry(thief: Player): Carry?
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

function HeistService.attemptSteal(thief: Player, victim: Player)
	local reason = whyCannotSteal(thief, victim)
	if reason then
		notify(thief, reason, "warn")
		return
	end

	local victimData = DataService.get(victim)
	if not victimData then
		return
	end

	-- Taken from the vault immediately so the same coins can't be grabbed
	-- twice by two thieves holding the prompt at once.
	-- Rush Hour doubles what a steal takes and nothing else -- not the hold,
	-- not the range, not the cooldown, not the getaway. One number, so there
	-- is one thing to reason about when it is running and nothing to
	-- recalibrate against BASE_WALK_SPEED. The multiplier is 1 whenever no
	-- event is live, which is what makes it safe to read unconditionally.
	local amount = math.floor(victimData.vault
		* UpgradeService.getStealFraction(thief)
		* EventService.getStealMultiplier())
	if amount <= 0 then
		notify(thief, ("%s's piggy is empty."):format(victim.DisplayName), "warn")
		return
	end
	victimData.vault -= amount

	local loot, highlight, prompt = attachLoot(thief, victim, amount)
	if not loot or not highlight or not prompt then
		victimData.vault += amount -- character vanished mid-grab; put it back
		return
	end

	carrying[thief] = {
		amount = amount,
		victim = victim,
		loot = loot,
		highlight = highlight,
		prompt = prompt,
	}

	lastGrab[victim] = lastGrab[victim] or {}
	lastGrab[victim][thief] = os.clock()
	grabCount[victim] = grabCount[victim] or {}
	grabCount[victim][thief] = (grabCount[victim][thief] or 0) + 1

	setCarrySpeed(thief, true)
	pushCarryState(thief)

	prompt.Triggered:Connect(function(tagger)
		HeistService.tag(tagger, thief)
	end)

	local victimPlot = PlotService.getPlot(victim)
	if victimPlot then
		PlotService.playAlarm(victimPlot)
		PlotService.updatePile(victimPlot, victimData.vault, Config.getCapacity(victimData.capacityLevel))

		-- Release the dog. It reads the thief's position fresh each frame, so
		-- if they're tagged or die mid-chase it ends on its own.
		--
		-- No level check here: the dog carries its own tier, set by
		-- PlotService.setDogLevel, and isReady returns false at tier 0.
		if GuardDog.isReady(victimPlot.dog) then
			-- The bark on the dog is a 3D sound that falls off with distance,
			-- which is right for the street and useless for the one player it
			-- is about: they are running AWAY from it, so the person who most
			-- needs to hear it is the one it fades for. This is the same
			-- snarl, flat and at the front, for them alone.
			notify(thief, "A guard dog is chasing you!", "chase")
			GuardDog.chase(victimPlot.dog, function(): BasePart?
				return if carrying[thief] then getRoot(thief) else nil
			end, function()
				HeistService.tag(victim, thief, true)
			end)
		end
	end

	notify(thief, ("Grabbed %s coins! Get to your plot."):format(format(amount)), "loot")
	-- The single most important message this game ever sends, and it spent its
	-- whole life as an orange bar that looked exactly like "you cannot afford
	-- that". It flashes the screen now.
	notify(victim, ("%s is robbing you! Tag them!"):format(thief.DisplayName), "alarm")

	-- Last, and spawned. A subscriber that errors or yields must not be able
	-- to take the steal down with it -- the coins have already moved.
	for _, handler in ipairs(stealHandlers) do
		task.spawn(handler, thief, victim, amount)
	end
end

-- Knocks the loot out of a thief's hands. Callable by anyone in range, or by
-- a guard dog on its owner's behalf (`byDog`, which has already done its own
-- proximity check and whose "tagger" may be nowhere near).
function HeistService.tag(tagger: Player, thief: Player, byDog: boolean?)
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
	-- never a way to launder someone else's money into your own vault.
	local victimData = DataService.get(victim)
	if victimData then
		victimData.vault += amount
		local plot = PlotService.getPlot(victim)
		if plot then
			PlotService.updatePile(plot, victimData.vault, Config.getCapacity(victimData.capacityLevel))
		end
		notify(victim, if byDog
			then ("Your guard dog caught %s. %s coins saved!"):format(thief.DisplayName, format(amount))
			else ("%s tagged %s. Your %s coins are back!"):format(tagger.DisplayName, thief.DisplayName, format(amount)),
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
	if tagger ~= victim and not byDog then
		notify(tagger, ("Nice tag! You saved %s's coins."):format(victim.DisplayName), "good")
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
function HeistService.confiscate(thief: Player): (number, Player?)
	local carry = carrying[thief]
	if not carry then
		return 0, nil
	end

	local victim, amount = carry.victim, carry.amount
	clearCarry(thief)

	-- Home to the victim, exactly as a tag would. The patrol is not a second
	-- thief and coins do not disappear into it.
	local victimData = DataService.get(victim)
	if victimData then
		victimData.vault += amount
		local plot = PlotService.getPlot(victim)
		if plot then
			PlotService.updatePile(plot, victimData.vault, Config.getCapacity(victimData.capacityLevel))
		end
	end

	return amount, victim
end

-- Thief reached their own plot: the loot becomes theirs, in their vault.
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

	-- Allowed to overflow capacity. Income stops above the cap anyway, so an
	-- overfull piggy is self-limiting -- and it nudges the thief to go bank.
	data.vault += amount
	data.totalStolen += amount
	-- The rap sheet, which is a different number from the lifetime one above:
	-- MOST WANTED is a contest within one session, so it has to be winnable by
	-- somebody who joined ten minutes ago. See SocialService.recordSteal.
	SocialService.recordSteal(thief, amount)

	local victimData = DataService.get(victim)
	if victimData then
		victimData.totalLost += amount
	end

	local plot = PlotService.getPlot(thief)
	if plot then
		PlotService.updatePile(plot, data.vault, Config.getCapacity(data.capacityLevel))
		PlotService.playBank(plot)
	end

	notify(thief, ("Delivered %s stolen coins!"):format(format(amount)), "money")
	notify(victim, ("%s got away with %s of your coins."):format(thief.DisplayName, format(amount)), "bad")

	-- Point the victim at the thief's plot. A successful robbery is exactly
	-- the moment a grievance exists, and a grievance is what creates the
	-- next session.
	SocialService.markRevenge(victim, thief)
end

-- ============================================================
-- LIFECYCLE
-- ============================================================

function HeistService.onPlayerAdded(player: Player)
	joinedAt[player] = os.clock()

	player.CharacterAdded:Connect(function()
		-- Dying drops the loot back to its owner. Otherwise the fastest way
		-- to escape a chase would be to reset.
		local carry = carrying[player]
		if carry then
			local victimData = DataService.get(carry.victim)
			if victimData then
				victimData.vault += carry.amount
			end
			carrying[player] = nil
			pushCarryState(player)
		end
		task.wait(0.2)
		setCarrySpeed(player, false)
	end)
end

-- Drops every restriction on robbing, for everyone in the server.
--
-- Testing aid only, driven by AdminService. Three separate things stop a
-- repeat robbery and they produce three different rejection messages, so
-- clearing only one of them looks like "the admin button did nothing":
--
--   * the new-player shield  (NEW_PLAYER_SHIELD, 15 min live / 15 s Studio)
--   * the per-victim cooldown (STEAL_COOLDOWN, 60s)
--   * the per-victim lifetime cap (STEAL_MAX_PER_VICTIM, 3)
--
-- Testing the guard dog means robbing the same person over and over, which
-- runs into the last two immediately. All three go together.
--
-- joinedAt is backdated rather than cleared so the field keeps its meaning
-- for every other reader.
function HeistService.openSeason(): (number, number)
	local shields = 0
	for _, player in ipairs(Players:GetPlayers()) do
		if joinedAt[player] then
			joinedAt[player] = os.clock() - SHIELD_SECONDS - 1
			shields += 1
		end
	end

	local pairsCleared = 0
	for victim in pairs(lastGrab) do
		for _ in pairs(lastGrab[victim]) do
			pairsCleared += 1
		end
	end
	table.clear(lastGrab)
	table.clear(grabCount)

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

	for _, plot in ipairs(PlotService.getAll()) do
		local prompt = plot.piggy.stealPrompt

		prompt.PromptButtonHoldBegan:Connect(function(thief)
			holdStarted[thief] = { plot = plot, at = os.clock() }
			-- The owner needs to see their lock being worked on, and the thief
			-- needs something happening while they stand there.
			PlotService.rattleLock(plot)
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
			local victim = plot.owner
			if not victim then
				return
			end

			-- The client is allowed to shorten its own prompt to match its
			-- lockpicks. It is not allowed to shorten it further than that,
			-- so the real hold is measured here.
			local required = UpgradeService.getStealHold(thief, victim)
			local started = holdStarted[thief]
			holdStarted[thief] = nil

			-- Never fail silently. A rejection the player cannot see is
			-- indistinguishable from a broken game, which is exactly how the
			-- bug above went unnoticed.
			if not started or started.plot ~= plot then
				notify(thief, "Hold the prompt to crack the lock.", "warn")
				return
			end

			local held = os.clock() - started.at
			if held < (required - HOLD_TOLERANCE) then
				notify(thief, "The lock held. Try again.", "warn")
				return
			end
			-- A hold begun and abandoned must not authorise a grab later on.
			if held > required + 30 then
				notify(thief, "The lock held. Try again.", "warn")
				return
			end

			HeistService.attemptSteal(thief, victim)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		-- Return anything in transit, then forget the player entirely.
		local carry = carrying[player]
		if carry then
			local victimData = DataService.get(carry.victim)
			if victimData then
				victimData.vault += carry.amount
			end
			carrying[player] = nil
		end

		joinedAt[player] = nil
		holdStarted[player] = nil
		snagged[player] = nil
		rideMultiplier[player] = nil
		warded[player] = nil
		prankedAt[player] = nil
		burst[player] = nil
		dodgeUntil[player] = nil
		dodgeImmuneUntil[player] = nil
		lastDodge[player] = nil
		lastGrab[player] = nil
		grabCount[player] = nil
		for _, byThief in pairs(lastGrab) do
			byThief[player] = nil
		end
		for _, byThief in pairs(grabCount) do
			byThief[player] = nil
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
