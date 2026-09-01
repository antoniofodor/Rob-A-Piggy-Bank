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
		return "You're already carrying loot -- take it home first."
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
				return "Can't ride while you're being robbed -- go tag them."
			end
		end
		return "Someone's being robbed -- everybody's on foot."
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
	if existing and now < existing.until_ then
		multiplier = math.min(multiplier, existing.multiplier)
		stunUntil = math.max(stunUntil, existing.stunUntil or 0)
	end

	snagged[player] = {
		multiplier = multiplier,
		until_ = now + penalty.duration,
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
		notify(player, ("The %s shocked you!"):format(penalty.label), "warn")
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
-- Returns the reason it found nobody, so a refusal can name it: "nobody is
-- robbing anyone" and "they are too far away" are completely different
-- situations to a player standing in the street, and one message for both is
-- how a working feature gets reported as broken.
--
-- Carrying is the ONLY thing that makes somebody a valid target. That is what
-- keeps this from being a griefing tool: there is no way to point a gadget at
-- a player who is not, at that moment, running off with somebody's coins.
function HeistService.nearestCarrier(from: Vector3, range: number, thrower: Player): (Player?, string?)
	local best, bestDist
	local anyCarrier = false

	for thief in pairs(carrying) do
		if thief ~= thrower then
			local root = getRoot(thief)
			if root then
				-- Counted at ANY distance, so "there is nobody to throw
				-- this at" can be told apart from "they got away from you".
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
		return nil, "Too far -- get closer to them."
	end
	return nil, "Nobody is running off with anything right now."
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

-- Charges a gadget's toll. Same state as a fence snag, different message.
function HeistService.applyGadget(thief: Player, thrower: Player, spec: any)
	if not carrying[thief] then
		return false
	end

	-- A raincoat stops the slows and nothing else.
	--
	-- Same shape as the Guard Duty Treat on the other side of this fight:
	-- cheap counters bounce, the expensive one gets through. It raises the
	-- price of stopping somebody from 1,500 to 22,000 rather than making them
	-- unstoppable, which is the only version that leaves both trees alive.
	if warded[thief] and (spec.stun or 0) <= 0 then
		warded[thief] = nil
		for _, handler in ipairs(wardUsedHandlers) do
			task.spawn(handler, thief, spec)
		end
		notify(thief, ("The %s slid off your raincoat!"):format(spec.name), "good")
		notify(thrower, ("%s was wearing a raincoat -- it bounced off."):format(thief.DisplayName), "warn")
		return true
	end

	applySlow(thief, {
		label = spec.name,
		slow = spec.slow,
		duration = spec.duration,
		stun = spec.stun or 0,
	})

	notify(thief, spec.hit or ("Hit by a %s!"):format(spec.name), "warn")
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
	local amount = math.floor(victimData.vault * UpgradeService.getStealFraction(thief))
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
			GuardDog.chase(victimPlot.dog, function(): BasePart?
				return if carrying[thief] then getRoot(thief) else nil
			end, function()
				HeistService.tag(victim, thief, true)
			end)
		end
	end

	notify(thief, ("Grabbed %s coins! Get to your plot."):format(format(amount)), "good")
	notify(victim, ("%s is robbing you! Tag them!"):format(thief.DisplayName), "warn")
end

-- Knocks the loot out of a thief's hands. Callable by anyone in range, or by
-- a guard dog on its owner's behalf (`byDog`, which has already done its own
-- proximity check and whose "tagger" may be nowhere near).
function HeistService.tag(tagger: Player, thief: Player, byDog: boolean?)
	local carry = carrying[thief]
	if not carry then
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
			then ("Your guard dog caught %s -- %s coins saved!"):format(thief.DisplayName, format(amount))
			else ("%s tagged %s -- your %s coins are back!"):format(tagger.DisplayName, thief.DisplayName, format(amount)),
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
		"warn")
	if tagger ~= victim and not byDog then
		notify(tagger, ("Nice tag! You saved %s's coins."):format(victim.DisplayName), "good")
	end
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

	local victimData = DataService.get(victim)
	if victimData then
		victimData.totalLost += amount
	end

	local plot = PlotService.getPlot(thief)
	if plot then
		PlotService.updatePile(plot, data.vault, Config.getCapacity(data.capacityLevel))
		PlotService.playBank(plot)
	end

	notify(thief, ("Delivered %s stolen coins!"):format(format(amount)), "good")
	notify(victim, ("%s got away with %s of your coins."):format(thief.DisplayName, format(amount)), "warn")

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
