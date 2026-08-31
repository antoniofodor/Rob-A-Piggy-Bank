--!strict
--[[
	Config
	Every tunable number in the game lives here. Nothing else should hardcode
	a balance value -- if you find yourself typing a number in a service,
	it probably belongs in this file instead.

	All values are starting points from the design doc and expected to move
	once real players touch the game.
]]

local Config = {}

-- ============================================================
-- ECONOMY
-- ============================================================

-- Coins added to the vault per second, before upgrades and rebirths.
Config.BASE_INCOME = 10

-- How much the vault holds before income stops. A full vault is the
-- return hook -- it should fill in roughly 8 minutes at level 1.
Config.BASE_CAPACITY = 5000

-- Each income upgrade multiplies the rate by this.
Config.INCOME_GROWTH = 1.35

-- Each capacity upgrade multiplies storage by this.
Config.CAPACITY_GROWTH = 1.40

-- Highest purchasable tier for each track.
Config.MAX_INCOME_LEVEL = 20
Config.MAX_CAPACITY_LEVEL = 20

-- Cost of the first upgrade. Must be reachable in under a minute --
-- the first win has to land immediately.
Config.INCOME_BASE_COST = 400
Config.CAPACITY_BASE_COST = 600

-- Cost multiplier per level owned.
Config.INCOME_COST_GROWTH = 1.55
Config.CAPACITY_COST_GROWTH = 1.60

-- ============================================================
-- OFFLINE ACCRUAL
-- ============================================================

-- Vault keeps filling while logged off, up to this many seconds.
-- 8 hours deliberately covers a school day, so an after-school player
-- always comes back to a full vault. Income never decays past the cap.
Config.OFFLINE_CAP_SECONDS = 8 * 60 * 60

-- ============================================================
-- REBIRTH
-- ============================================================

Config.REBIRTH_THRESHOLD = 1000000

-- Permanent income bonus per rebirth, additive: 1 + (rebirths * 0.25)
Config.REBIRTH_MULTIPLIER = 0.25

-- ============================================================
-- SOCIAL
-- ============================================================

-- Income bonus per friend in the same server. This is the growth engine:
-- inviting someone is a mechanical advantage, not a favour you do the game.
Config.FRIEND_BONUS_PER = 0.10
Config.FRIEND_BONUS_MAX = 0.50

-- How long a "get them back" marker hangs over a thief's plot, for the
-- victim only. The revenge loop is the highest-value UI in the game: being
-- robbed creates a grievance, and a grievance creates a session.
Config.REVENGE_MARKER_SECONDS = 90

Config.LEADERBOARD_SIZE = 8
Config.LEADERBOARD_REFRESH = 5

-- ============================================================
-- FEEDBACK
-- ============================================================

-- Fill fractions that get a celebration. 100% matters most: income stops at
-- a full vault, so that one is functional feedback, not just a flourish.
Config.MILESTONES = { 0.25, 0.5, 0.75, 1.0 }

-- Free Creator Store audio. Swap these for your own uploads before launch --
-- some free assets ask for creator credit, and third-party audio can be
-- moderated out from under you without warning.
Config.SOUNDS = {
	COIN_DROP = "rbxassetid://4608067546",
	MILESTONE = "rbxassetid://2415965014",
	BANK = "rbxassetid://101396758527961",
	ALARM = "rbxassetid://1470797856",
}

-- ============================================================
-- THE HEIST
-- ============================================================
--
-- Every number below exists to stop one specific failure: a strong player
-- parking on a weak player's plot and farming them until they quit. They are
-- caps, not discouragements -- the griefing case has to be impossible, not
-- merely unrewarding.

-- Fraction of the victim's uncollected vault taken per successful grab.
Config.STEAL_FRACTION = 0.05

-- Seconds the thief must hold the prompt. Three is the tuned middle: instant
-- is a drive-by with no drama, ten and nobody ever succeeds.
Config.STEAL_HOLD = 3

-- How close a thief must be to the victim's piggy to start a grab.
Config.STEAL_RANGE = 11

-- Per-victim limits. Both are per thief, so a popular target isn't drained
-- by one determined attacker.
Config.STEAL_COOLDOWN = 60
Config.STEAL_MAX_PER_VICTIM = 3

-- Grace period after joining. Long enough to learn the controls before
-- anyone is allowed to take anything from you.
Config.NEW_PLAYER_SHIELD = 15 * 60

-- Carrying is slow and obvious. This is the entire risk half of the trade.
Config.CARRY_SPEED_MULTIPLIER = 0.75
Config.BASE_WALK_SPEED = 16

-- Tagging a thief: anyone nearby can do it, including bystanders.
Config.TAG_HOLD = 0.4
Config.TAG_DISTANCE = 14
Config.STUN_SECONDS = 4

-- How close a thief must get to their own piggy to bank the loot.
--
-- Sized against PLOT_SPACING deliberately. STEAL_RANGE + DROPOFF_RADIUS must
-- stay well under the spacing, or a thief could stand in their own drop-off
-- zone and rob a neighbour without ever running -- and the run is the entire
-- risk half of the trade. At 11 + 16 against 64 the shortest possible
-- getaway is 37 studs, about 3 seconds at carry speed.
Config.DROPOFF_RADIUS = 16

-- How many coin discs make up a full piggy. Income and capacity scale
-- together, so a coin lands roughly every 15 seconds at every level -- the
-- drip cadence stays constant as you upgrade, which is what makes it feel
-- like a heartbeat rather than a progress bar.
Config.COIN_COUNT = 32

-- ============================================================
-- DEFENCE AND OFFENCE
-- ============================================================
--
-- The design pillar the whole game hangs on: a coin spent on one tree is
-- gone from the other. Nobody can buy both. Within a week players sort
-- themselves into turtles and bandits, argue about which is better, and have
-- a reason to keep playing that isn't a bigger number.
--
-- So these are priced against each other, not against income. If one tree is
-- clearly better value the identity split collapses and everyone builds the
-- same thing.

Config.UPGRADES = {
	locks = {
		tree = "defense", order = 1, name = "Vault Lock", max = 4,
		baseCost = 1800, growth = 2.1,
		blurb = "Thieves need longer to crack your piggy",
	},
	fences = {
		tree = "defense", order = 2, name = "Fence", max = 5,
		baseCost = 2600, growth = 2.4,
		blurb = "Slower and nastier to climb over",
	},
	dog = {
		tree = "defense", order = 3, name = "Guard Dog", max = 3,
		baseCost = 5000, growth = 2.6,
		blurb = "Chases thieves and tags them for you",
	},
	lockpicks = {
		tree = "offense", order = 1, name = "Lockpicks", max = 4,
		baseCost = 1800, growth = 2.1,
		blurb = "Crack piggies faster",
	},
	sack = {
		tree = "offense", order = 2, name = "Bigger Sack", max = 4,
		baseCost = 2600, growth = 2.4,
		blurb = "Take more coins per grab",
	},
	boots = {
		tree = "offense", order = 3, name = "Speed Boots", max = 4,
		baseCost = 3400, growth = 2.3,
		blurb = "Run faster while carrying loot",
	},
}

function Config.getUpgradeCost(key: string, currentLevel: number): number
	local def = Config.UPGRADES[key]
	if not def then
		return math.huge
	end
	return math.floor(def.baseCost * (def.growth ^ currentLevel))
end

-- Locks and lockpicks are the same axis pulled from both ends, which is what
-- makes the two trees feel like they're fighting rather than co-existing.
-- Floored well above zero: an instant grab is a drive-by with no drama, no
-- matter how many lockpicks someone bought.
function Config.getStealHold(victimLocks: number, thiefPicks: number): number
	local hold = Config.STEAL_HOLD + victimLocks * 1.5 - thiefPicks * 0.55
	return math.clamp(hold, 1.2, 12)
end

function Config.getStealFraction(thiefSack: number): number
	return Config.STEAL_FRACTION + thiefSack * 0.018
end

-- Caps at 1.0: boots cancel the carry penalty, they never make you faster
-- than everyone chasing you.
function Config.getCarryMultiplier(thiefBoots: number): number
	return math.min(1, Config.CARRY_SPEED_MULTIPLIER + thiefBoots * 0.065)
end

-- ============================================================
-- GUARD DOGS
-- ============================================================
--
-- Three breeds, not three copies of the same dog with a bigger number. The
-- dog is the most expensive thing in the defence tree, and a purchase nobody
-- can see doesn't feel like a purchase -- each tier has to read as an upgrade
-- from across the plot, before the chase ever happens.
--
-- Speeds are set against the thief, not in the abstract. Scruffy ties an
-- unbooted thief, so she only catches players who skipped Speed Boots; Titan
-- outruns a fully booted one. That keeps the dog a real answer to the offence
-- tree rather than a flat tax on robbing.
--
-- Everything else moves the same direction with each tier: wider jaws
-- (catchRadius), a longer leash (maxChase), and a shorter rest (cooldown).
-- Cooldown is the quiet one that matters most -- against a plot being farmed
-- repeatedly, Titan is back on duty ten seconds sooner than Scruffy.
Config.DOG_TIERS = {
	{
		name = "Scruffy",
		breed = "Terrier",
		speed = 12,
		catchRadius = 7,
		cooldown = 34,
		maxChase = 12,
		scale = 0.8,
		fur = Color3.fromRGB(198, 154, 98),
		furDark = Color3.fromRGB(158, 116, 68),
		collar = Color3.fromRGB(214, 68, 64),
		glow = false,
		blurb = "Small, loud, and quicker than a thief who skipped boots",
	},
	{
		name = "Rex",
		breed = "Shepherd",
		speed = 14.5,
		catchRadius = 8.2,
		cooldown = 29,
		maxChase = 15,
		scale = 1.0,
		fur = Color3.fromRGB(126, 94, 66),
		furDark = Color3.fromRGB(72, 52, 38),
		collar = Color3.fromRGB(66, 140, 220),
		glow = false,
		blurb = "Longer legs, longer chase, and a much wider set of jaws",
	},
	{
		name = "Titan",
		breed = "Mastiff",
		speed = 17,
		catchRadius = 9.5,
		cooldown = 24,
		maxChase = 18,
		scale = 1.3,
		fur = Color3.fromRGB(58, 56, 64),
		furDark = Color3.fromRGB(32, 31, 37),
		collar = Color3.fromRGB(246, 198, 52),
		glow = true,
		blurb = "Runs down fully booted thieves. Nothing leaves this plot",
	},
}

Config.DOG_START_DELAY = 0.9

-- Idle wander between chases. A dog frozen at a corner reads as scenery; one
-- that paces reads as on duty, which is most of what the purchase buys.
Config.DOG_PATROL_RADIUS = 8
Config.DOG_PATROL_SPEED = 0.28 -- fraction of the breed's chase speed
Config.DOG_PATROL_PAUSE = { 2.5, 6.0 }

-- Returns nil at level 0, which is how every caller checks "is there a dog".
function Config.getDogTier(level: number)
	if level <= 0 then
		return nil
	end
	return Config.DOG_TIERS[math.clamp(level, 1, #Config.DOG_TIERS)]
end

-- ============================================================
-- FENCES
-- ============================================================
--
-- Fences used to be unjumpable walls, which made them a binary: either you
-- could get in or you couldn't. Now they're low enough to vault, and going
-- over snags you.
--
-- That turns every approach into a real choice: hop the fence and land slow
-- and exposed, or run the long way round to the gate and lose the time
-- instead. A wall offers no decision; a hurdle does.
--
-- The gate always exists. A fully sealed plot would trap its owner, and a
-- fence costs its owner time too -- they come home with loot through the
-- same gap.
-- A character jumps BASE_JUMP_HEIGHT studs, so any solid barrier below that is
-- a one-hop vault and any barrier above it is an unclimbable wall. Rather than
-- race that number, every tier from Barbed Wire up stays at the same jumpable
-- 6.0 and escalates the *hazard* instead: wire, then live current, then water.
--
-- That is a deliberate design line. A fence nobody can cross would make its
-- owner un-robbable, which kills the offence tree and stalls the economy at
-- the top. Defence buys TIME, never immunity -- max tier turns a two-second
-- hop into an eight-second ordeal, which is comfortably inside the guard
-- dog's chase window. The fast route stays open; it just leaves you crawling
-- and lit up on somebody's lawn.
--
-- `top` is the solid barrier. `decorTop` is where the visuals reach, and is
-- cosmetic only -- wire and pickets never collide, so the jump maths only
-- ever depends on `top`.
Config.FENCE_TIERS = {
	{
		label = "Rickety Fence", style = "rickety",
		gate = 24, top = 3.6, decorTop = 4.2,
		slow = 0.80, duration = 1.5, stun = 0,
		blurb = "Leaning posts and missing planks. Mostly a statement",
	},
	{
		label = "White Picket", style = "picket",
		gate = 18, top = 4.8, decorTop = 5.6,
		slow = 0.62, duration = 2.5, stun = 0,
		blurb = "Neat, taller, and pointed at the top",
	},
	{
		label = "Barbed Wire", style = "barbed",
		gate = 13, top = 6.0, decorTop = 6.9,
		slow = 0.42, duration = 4.0, stun = 0,
		blurb = "Steel posts strung with wire. Going over it hurts",
	},
	{
		label = "Electric Fence", style = "electric",
		gate = 10, top = 6.0, decorTop = 6.9,
		slow = 0.50, duration = 3.0, stun = 2.5,
		blurb = "Live current. Touch it and you're not going anywhere",
	},
	{
		label = "Moat", style = "moat",
		gate = 8, top = 6.0, decorTop = 6.9,
		slow = 0.50, duration = 3.0, stun = 2.5,
		-- Outer edge must stay inside PLOT_SPACING/2 (32) or neighbouring
		-- moats overlap: half (25.6) + 0.5 + width must stay under 32.
		moat = { width = 5, slow = 0.30, duration = 4.0 },
		blurb = "Water on every side. Wade it, or take the long way round",
	},
}

-- What a character can clear from standing. Fence heights are set against it,
-- and a stun drops it to zero so a stunned thief can't hop the fence anyway.
Config.BASE_JUMP_HEIGHT = 7.2

-- ============================================================
-- COSMETICS
-- ============================================================
--
-- The permanent progression track, and the answer to "what am I grinding
-- for?".
--
-- Rebirth wipes every upgrade you own, so power is always temporary. Skins
-- and effects are never wiped -- they accumulate across every rebirth for
-- the life of the account. That split is deliberate: it means there is
-- always something ahead of you that a reset can't take away, and because
-- your piggy is visible from across the map, everything you buy is something
-- other people can see.
--
-- All of it is pure decoration. None of it touches balance, which is what
-- makes it safe to price aggressively.

Config.DEFAULT_SKIN = "classic"
Config.DEFAULT_EFFECT = "none"

Config.SKINS = {
	classic = {
		name = "Classic Pink", order = 1, cost = 0,
		body = Color3.fromRGB(244, 168, 194), trim = Color3.fromRGB(214, 122, 148),
		material = Enum.Material.SmoothPlastic, transparency = 0.30,
	},
	bubblegum = {
		name = "Bubblegum", order = 2, cost = 8000,
		body = Color3.fromRGB(255, 132, 190), trim = Color3.fromRGB(206, 78, 148),
		material = Enum.Material.SmoothPlastic, transparency = 0.30,
	},
	mint = {
		name = "Mint Choc", order = 3, cost = 20000,
		body = Color3.fromRGB(148, 226, 190), trim = Color3.fromRGB(88, 62, 52),
		material = Enum.Material.SmoothPlastic, transparency = 0.30,
	},
	sunset = {
		name = "Sunset", order = 4, cost = 45000,
		body = Color3.fromRGB(255, 158, 92), trim = Color3.fromRGB(206, 92, 108),
		material = Enum.Material.SmoothPlastic, transparency = 0.28,
	},
	midnight = {
		name = "Midnight", order = 5, cost = 90000,
		body = Color3.fromRGB(78, 84, 156), trim = Color3.fromRGB(44, 48, 96),
		material = Enum.Material.Glass, transparency = 0.34,
	},
	lava = {
		name = "Lava", order = 6, cost = 200000,
		body = Color3.fromRGB(232, 92, 48), trim = Color3.fromRGB(58, 30, 26),
		material = Enum.Material.Neon, transparency = 0.42,
	},
	galaxy = {
		name = "Galaxy", order = 7, cost = 500000,
		body = Color3.fromRGB(126, 82, 200), trim = Color3.fromRGB(52, 34, 92),
		material = Enum.Material.Neon, transparency = 0.40,
	},
	pearl = {
		name = "Pearl", order = 8, cost = 1200000,
		body = Color3.fromRGB(248, 244, 236), trim = Color3.fromRGB(206, 198, 220),
		material = Enum.Material.Glass, transparency = 0.26,
	},

	-- Earned by rebirthing rather than paid for, so the collection has two
	-- routes into it and a rebirth still hands you something to show off.
	bronze = {
		name = "Bronze", order = 20, unlockRebirths = 1,
		body = Color3.fromRGB(196, 132, 74), trim = Color3.fromRGB(150, 96, 50),
		material = Enum.Material.Metal, transparency = 0.28,
	},
	goldleaf = {
		name = "Gold Leaf", order = 21, unlockRebirths = 3,
		body = Color3.fromRGB(238, 190, 78), trim = Color3.fromRGB(198, 148, 44),
		material = Enum.Material.Metal, transparency = 0.26,
	},
	diamond = {
		name = "Diamond", order = 22, unlockRebirths = 6,
		body = Color3.fromRGB(150, 226, 236), trim = Color3.fromRGB(104, 190, 208),
		material = Enum.Material.Glass, transparency = 0.36,
	},
}

-- Named for what they actually look like. Roblox ships three particle
-- textures; everything here is those three recoloured and retimed, so
-- promising "hearts" or "confetti" would be writing a cheque the art
-- can't cash.
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

Config.EFFECTS = {
	none = { name = "None", order = 1, cost = 0 },
	-- Deliberately silver-lilac, rising and slow-turning.
	--
	-- The coin drip and the milestone burst are both small, fast, GOLD and
	-- falling. This effect used to be gold and falling too, on the same
	-- texture -- so a 15,000-coin cosmetic looked identical to the feedback
	-- every player already gets for free. The texture is shared (there are
	-- only three built-in ones), so the separation has to come from colour
	-- and motion: these rise, turn, and live twice as long.
	sparkle = {
		name = "Sparkles", order = 2, cost = 15000, texture = SPARK,
		color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(226, 188, 255)),
		rate = 11, speed = NumberRange.new(1, 2.5), size = 1.4, lifetime = NumberRange.new(1.4, 2.2),
		drag = 1.5, accel = Vector3.new(0, 2.5, 0), spread = 180, rotSpeed = 140,
	},
	embers = {
		name = "Embers", order = 3, cost = 40000, texture = FIRE,
		color = ColorSequence.new(Color3.fromRGB(255, 178, 92), Color3.fromRGB(214, 72, 40)),
		rate = 14, speed = NumberRange.new(3, 7), size = 1.3, lifetime = NumberRange.new(0.9, 1.6),
		drag = 1, accel = Vector3.new(0, 7, 0), spread = 45, rotSpeed = 40,
	},
	frost = {
		name = "Frost", order = 4, cost = 90000, texture = SPARK,
		color = ColorSequence.new(Color3.fromRGB(224, 246, 255), Color3.fromRGB(140, 200, 240)),
		rate = 16, speed = NumberRange.new(1, 3), size = 1.1, lifetime = NumberRange.new(1.6, 2.6),
		drag = 2, accel = Vector3.new(0, -4, 0), spread = 180, rotSpeed = 25,
	},
	storm = {
		name = "Storm Cloud", order = 5, cost = 220000, texture = SMOKE,
		color = ColorSequence.new(Color3.fromRGB(150, 158, 178), Color3.fromRGB(78, 84, 104)),
		rate = 10, speed = NumberRange.new(1, 2), size = 4.5, lifetime = NumberRange.new(1.8, 3.0),
		drag = 3, accel = Vector3.new(0, 1, 0), spread = 60, rotSpeed = 12,
	},
	inferno = {
		name = "Inferno", order = 6, cost = 600000, texture = FIRE,
		color = ColorSequence.new(Color3.fromRGB(255, 226, 140), Color3.fromRGB(226, 46, 30)),
		rate = 34, speed = NumberRange.new(5, 11), size = 2.6, lifetime = NumberRange.new(0.7, 1.3),
		drag = 0, accel = Vector3.new(0, 12, 0), spread = 30, rotSpeed = 90,
	},
}

function Config.getSkin(key: string)
	return Config.SKINS[key] or Config.SKINS[Config.DEFAULT_SKIN]
end

function Config.getEffect(key: string)
	return Config.EFFECTS[key] or Config.EFFECTS[Config.DEFAULT_EFFECT]
end

-- A skin is available if it's free, already bought, or earned by rebirths.
function Config.isSkinUnlocked(key: string, owned: { [string]: boolean }, rebirths: number): boolean
	local skin = Config.SKINS[key]
	if not skin then
		return false
	end
	if skin.unlockRebirths then
		return rebirths >= skin.unlockRebirths
	end
	return (skin.cost or 0) <= 0 or owned[key] == true
end

-- ============================================================
-- PLOTS
-- ============================================================

-- Two rows of six facing each other across a street, not a solid block.
--
-- The block was quietly unfair: in a 4x3 grid the two interior plots had four
-- adjacent neighbours and the corners had two, so how often you got robbed
-- was decided by what time you happened to log in. Facing rows give every
-- plot the same exposure -- two beside, one across -- and put a full piggy
-- permanently in your eyeline, which is the read the whole game runs on.
Config.PLOT_COUNT = 12
Config.PLOT_SIZE = Vector3.new(48, 1, 48)

-- Along the street, centre to centre. The heist maths depends on this being
-- the SHORTEST distance between two plots: STEAL_RANGE + DROPOFF_RADIUS (27)
-- must stay well under it, or a thief could stand in their own drop-off zone
-- and rob a neighbour without ever running.
Config.PLOT_SPACING = 64

-- Across the street, centre to centre. Wider than PLOT_SPACING so next door
-- stays the easy target and across the road is a choice. Must also clear two
-- facing moats: 2 x 31.1 = 62.2.
Config.STREET_SPACING = 80

Config.PLOTS_PER_ROW = 6

-- ============================================================
-- PERSISTENCE
-- ============================================================

Config.DATASTORE_NAME = "PiggyBank_Player"

-- Bumping this lets us migrate live saves later instead of wiping them.
-- v2 added the `upgrades` table for the defence and offence trees.
-- v3 added `cosmetics`, which rebirth deliberately does not reset.
Config.SCHEMA_VERSION = 3

Config.AUTOSAVE_INTERVAL = 60

-- A session lock older than this is treated as a crashed server and stolen.
Config.LOCK_STALE_SECONDS = 30 * 60

-- ============================================================
-- DERIVED VALUES
-- ============================================================

-- `friendBonus` is a 0..0.5 fraction and is deliberately optional: offline
-- accrual passes nothing, because your friends weren't in the server while
-- you were asleep and paying you for their absence would be a lie.
function Config.getIncomeRate(incomeLevel: number, rebirths: number, friendBonus: number?): number
	local base = Config.BASE_INCOME * (Config.INCOME_GROWTH ^ (incomeLevel - 1))
	return base * (1 + rebirths * Config.REBIRTH_MULTIPLIER) * (1 + (friendBonus or 0))
end

function Config.getCapacity(capacityLevel: number): number
	return math.floor(Config.BASE_CAPACITY * (Config.CAPACITY_GROWTH ^ (capacityLevel - 1)))
end

function Config.getIncomeCost(currentLevel: number): number
	return math.floor(Config.INCOME_BASE_COST * (Config.INCOME_COST_GROWTH ^ (currentLevel - 1)))
end

function Config.getCapacityCost(currentLevel: number): number
	return math.floor(Config.CAPACITY_BASE_COST * (Config.CAPACITY_COST_GROWTH ^ (currentLevel - 1)))
end


return Config
