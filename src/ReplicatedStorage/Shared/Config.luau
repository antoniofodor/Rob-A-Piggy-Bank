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

	-- Dog audio, all from Roblox's licensed Pro Sound Effects library.
	--
	-- That library is the reason these are safe. The Creator Store is full of
	-- free-to-take dog barks that are lifted from Minecraft or Undertale --
	-- "free" there means costing no Robux, not cleared for use, and a
	-- copyright strike moderates the asset away and leaves a silent game.
	-- Every id below is Pro Sound Effects, which Roblox licensed wholesale.
	--
	-- The breed barks are coyotes, not dogs: the library has no domestic dog,
	-- and a coyote bark pitched up reads as a terrier far better than a
	-- pitched-down one reads as a mastiff. Pitch does the rest, per tier.
	DOG_SNARL = "rbxassetid://9120790555",  -- Wolf Snarl, 1.98s -- the catch
	DOG_SQUEAK = "rbxassetid://9125994773", -- Squeeze Toy, 0.51s -- the bone
	DOG_WHINE = "rbxassetid://9113952398",  -- Coyote whimper, 3.19s
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
		-- Voice. Pitch is what separates the breeds: same library, three
		-- animals. Volume climbs too, so a Titan is audible from further
		-- down the street than a terrier.
		bark = "rbxassetid://9113955391", pitch = 1.45, volume = 0.42,
		breed = "Terrier",
		speed = 12,
		catchRadius = 7,
		cooldown = 34,
		maxChase = 12,
		scale = 0.8,
		boneResist = 1.0,
		fur = Color3.fromRGB(198, 154, 98),
		furDark = Color3.fromRGB(158, 116, 68),
		collar = Color3.fromRGB(214, 68, 64),
		glow = false,
		blurb = "Small, loud, and quicker than a thief who skipped boots",
	},
	{
		name = "Rex",
		-- Voice. Pitch is what separates the breeds: same library, three
		-- animals. Volume climbs too, so a Titan is audible from further
		-- down the street than a terrier.
		bark = "rbxassetid://9113956178", pitch = 1.00, volume = 0.55,
		breed = "Shepherd",
		speed = 14.5,
		catchRadius = 8.2,
		cooldown = 29,
		maxChase = 15,
		scale = 1.0,
		boneResist = 0.8,
		fur = Color3.fromRGB(126, 94, 66),
		furDark = Color3.fromRGB(72, 52, 38),
		collar = Color3.fromRGB(66, 140, 220),
		glow = false,
		blurb = "Longer legs, longer chase, and a much wider set of jaws",
	},
	{
		name = "Titan",
		-- Voice. Pitch is what separates the breeds: same library, three
		-- animals. Volume climbs too, so a Titan is audible from further
		-- down the street than a terrier.
		bark = "rbxassetid://9113955086", pitch = 0.68, volume = 0.75,
		breed = "Mastiff",
		speed = 17,
		catchRadius = 9.5,
		cooldown = 24,
		maxChase = 18,
		scale = 1.3,
		boneResist = 0.6,
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
-- BONES
-- ============================================================
--
-- The first CONSUMABLE in the game. Every other purchase is a permanent
-- level; a bone is bought, thrown once, and gone.
--
-- It exists because the dog was the only thing in the defence tree with no
-- answer. Locks are answered by lockpicks, fences by taking the gate instead,
-- carry speed by boots -- but a Titan on a plot simply beat anyone who walked
-- in, and "you lose because they bought the expensive one" is the shape of a
-- wall. The same line that governs fences governs dogs: defence buys TIME,
-- never immunity.
--
-- Four things stop the bone from deleting the dog it counters:
--
--   * It costs coins EVERY TIME. Farming a guarded plot becomes an ongoing
--     expense that scales with how well guarded it is -- which is precisely
--     what the defender paid for.
--   * A nap is always shorter than that breed's own cooldown, so a bone buys
--     a window and never a full rest cycle. Waiting out a real chase is still
--     the cheaper option if you have the patience.
--   * Bigger dogs shrug it off (`boneResist` above). A Dog Bone worth nine
--     seconds against Scruffy is worth 5.4 against Titan.
--   * Only the top bone interrupts a chase in progress. The other two have to
--     be thrown BEFORE the dog notices you, which makes them a plan you
--     commit coins to rather than a panic button you mash when barking starts.
--
-- Prices sit deliberately between the two trees' rungs. A Golden Bone costs
-- more than a first Vault Lock, so stocking up is a real alternative to
-- levelling something, not pocket change on the way past.
Config.BONES = {
	bone = {
		name = "Dog Bone", order = 1, cost = 2500, nap = 9, breaksChase = false,
		style = "bone", colour = Color3.fromRGB(238, 230, 208),
		material = Enum.Material.SmoothPlastic,
		blurb = "Buys a getaway. Not long enough to crack a lock as well",
	},
	steak = {
		name = "Juicy Steak", order = 2, cost = 9000, nap = 18, breaksChase = false,
		style = "steak", colour = Color3.fromRGB(176, 68, 62),
		material = Enum.Material.SmoothPlastic,
		blurb = "Long enough for the whole job on most plots",
	},
	golden = {
		name = "Golden Bone", order = 3, cost = 30000, nap = 30, breaksChase = true,
		-- Same silhouette as the Dog Bone, in metal. The shape says "bone" and
		-- the finish says which one, which is how the skins ladder reads too.
		style = "bone", colour = Color3.fromRGB(246, 198, 52),
		material = Enum.Material.Metal,
		blurb = "The only one a dog will break off a chase for",
	},
}

-- How far from the thrower a dog can be lured.
--
-- Sized so a bone reaches the kennel from the KERB: the dog rests about 26
-- studs from the verge, so the whole point -- pre-baiting the dog before you
-- ever set foot on the lawn -- has to work from outside the fence. It stays
-- well under PLOT_SPACING (64) so it cannot casually reach next door's dog.
Config.BONE_THROW_RANGE = 42

-- Stops a held button from spraying bones and spawning a dozen models. It is
-- not a balance number; the coin cost is the balance number.
Config.BONE_THROW_COOLDOWN = 1.5

-- Arc time from hand to ground. The bone is lerped along a fixed parabola
-- rather than thrown with physics: an unanchored part rolls, falls through
-- thin geometry, and lands somewhere nobody aimed at. Everything else that
-- moves in this game is anchored and lerped for the same reason.
Config.BONE_FLIGHT = 0.55

-- Nap this bone buys against this dog. Never returns a useless number: even
-- the cheapest bone against Titan is worth more than a standing start.
function Config.getBoneNap(boneKey: string, dogLevel: number): number
	local bone = Config.BONES[boneKey]
	local tier = Config.getDogTier(dogLevel)
	if not bone or not tier then
		return 0
	end
	return bone.nap * tier.boneResist
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

	-- ANIMATED DROP POOL
	--
	-- Not for sale at any price. The only way in is rebirthing, which is what
	-- makes them worth chasing -- coins can buy every skin above this line.
	--
	-- `anim` is read by the CLIENT, never the server. Animating a colour
	-- server-side would replicate a property write per piggy per frame, which
	-- is 700+ writes a second across twelve plots for something every client
	-- can compute for itself from a single attribute.
	ember = {
		name = "Ember Glow", order = 30, rarity = "rare",
		body = Color3.fromRGB(226, 104, 52), trim = Color3.fromRGB(120, 44, 30),
		material = Enum.Material.Neon, transparency = 0.36,
		anim = { kind = "pulse", speed = 1.4, palette = {
			Color3.fromRGB(226, 104, 52), Color3.fromRGB(255, 176, 84),
		} },
	},
	frostbite = {
		name = "Frostbite", order = 31, rarity = "rare",
		body = Color3.fromRGB(186, 232, 248), trim = Color3.fromRGB(120, 176, 208),
		material = Enum.Material.Glass, transparency = 0.34,
		anim = { kind = "pulse", speed = 0.8, palette = {
			Color3.fromRGB(186, 232, 248), Color3.fromRGB(246, 252, 255),
		} },
	},
	toxic = {
		name = "Toxic Ooze", order = 32, rarity = "rare",
		body = Color3.fromRGB(140, 226, 84), trim = Color3.fromRGB(66, 122, 40),
		material = Enum.Material.Neon, transparency = 0.38,
		anim = { kind = "cycle", speed = 0.7, palette = {
			Color3.fromRGB(140, 226, 84), Color3.fromRGB(96, 190, 70), Color3.fromRGB(196, 240, 110),
		} },
	},
	candyswirl = {
		name = "Candy Swirl", order = 33, rarity = "rare",
		body = Color3.fromRGB(255, 150, 200), trim = Color3.fromRGB(255, 236, 244),
		material = Enum.Material.SmoothPlastic, transparency = 0.24,
		anim = { kind = "cycle", speed = 1.1, palette = {
			Color3.fromRGB(255, 150, 200), Color3.fromRGB(255, 244, 250), Color3.fromRGB(150, 210, 255),
		} },
	},

	aurora = {
		name = "Aurora", order = 40, rarity = "epic",
		body = Color3.fromRGB(96, 226, 190), trim = Color3.fromRGB(60, 110, 150),
		material = Enum.Material.Neon, transparency = 0.40,
		anim = { kind = "cycle", speed = 0.55, glow = 1.6, palette = {
			Color3.fromRGB(96, 226, 190), Color3.fromRGB(84, 160, 238),
			Color3.fromRGB(178, 118, 236), Color3.fromRGB(96, 226, 190),
		} },
	},
	magma = {
		name = "Magma Core", order = 41, rarity = "epic",
		body = Color3.fromRGB(210, 58, 30), trim = Color3.fromRGB(52, 20, 16),
		material = Enum.Material.Neon, transparency = 0.34,
		anim = { kind = "flicker", speed = 9, glow = 2.2, palette = {
			Color3.fromRGB(150, 32, 18), Color3.fromRGB(255, 148, 44),
		} },
	},
	voidsilk = {
		name = "Void Silk", order = 42, rarity = "epic",
		body = Color3.fromRGB(46, 30, 72), trim = Color3.fromRGB(22, 14, 36),
		material = Enum.Material.Glass, transparency = 0.30,
		anim = { kind = "pulse", speed = 0.5, glow = 1.4, palette = {
			Color3.fromRGB(46, 30, 72), Color3.fromRGB(140, 78, 220),
		} },
	},

	supernova = {
		name = "Supernova", order = 50, rarity = "legendary",
		body = Color3.fromRGB(255, 230, 150), trim = Color3.fromRGB(232, 128, 40),
		material = Enum.Material.Neon, transparency = 0.30,
		anim = { kind = "cycle", speed = 2.2, glow = 4.0, palette = {
			Color3.fromRGB(255, 248, 220), Color3.fromRGB(255, 196, 72),
			Color3.fromRGB(255, 110, 40), Color3.fromRGB(255, 248, 220),
		} },
	},
	stormcaller = {
		name = "Stormcaller", order = 51, rarity = "legendary",
		body = Color3.fromRGB(120, 176, 255), trim = Color3.fromRGB(40, 52, 92),
		material = Enum.Material.Neon, transparency = 0.32,
		anim = { kind = "flicker", speed = 14, glow = 4.5, palette = {
			Color3.fromRGB(64, 96, 176), Color3.fromRGB(232, 246, 255),
		} },
	},
	prismatic = {
		name = "Prismatic", order = 52, rarity = "legendary",
		body = Color3.fromRGB(255, 120, 120), trim = Color3.fromRGB(255, 255, 255),
		material = Enum.Material.Neon, transparency = 0.28,
		anim = { kind = "rainbow", speed = 0.35, glow = 3.5 },
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
	-- A "Storm Cloud" with no lightning and no light was a polite grey puff for
	-- 220,000 coins. It now boils, and the light strobes so it reads as a
	-- storm from the far end of the street rather than as fog up close.
	storm = {
		name = "Storm Cloud", order = 5, cost = 220000, texture = SMOKE,
		color = ColorSequence.new(Color3.fromRGB(168, 176, 198), Color3.fromRGB(54, 60, 82)),
		rate = 28, speed = NumberRange.new(1, 3), size = 7.0, lifetime = NumberRange.new(2.2, 3.6),
		drag = 3, accel = Vector3.new(0, 1, 0), spread = 75, rotSpeed = 12,
		light = { colour = Color3.fromRGB(170, 205, 255), brightness = 7, range = 26, kind = "strike" },
	},
	-- The most expensive thing in the shop should be the loudest. Roughly
	-- double the fire, half again the size, and a fire-coloured light that
	-- flickers, so it throws colour onto the lawn around it.
	inferno = {
		name = "Inferno", order = 6, cost = 600000, texture = FIRE,
		color = ColorSequence.new(Color3.fromRGB(255, 236, 170), Color3.fromRGB(226, 46, 30)),
		rate = 72, speed = NumberRange.new(7, 15), size = 3.6, lifetime = NumberRange.new(0.7, 1.4),
		drag = 0, accel = Vector3.new(0, 14, 0), spread = 34, rotSpeed = 90,
		light = { colour = Color3.fromRGB(255, 150, 60), brightness = 9, range = 30, kind = "flicker" },
	},
}

function Config.getSkin(key: string)
	return Config.SKINS[key] or Config.SKINS[Config.DEFAULT_SKIN]
end

function Config.getEffect(key: string)
	return Config.EFFECTS[key] or Config.EFFECTS[Config.DEFAULT_EFFECT]
end

-- A skin is available if it's free, already bought, or earned by rebirths.
-- ============================================================
-- REBIRTH DROPS
-- ============================================================
--
-- Every rebirth grants exactly one animated skin. The roll decides HOW RARE,
-- never WHETHER -- rebirth already costs a player every upgrade they own, and
-- handing back nothing for that is the fastest way to make people stop doing
-- it. There is no outcome where you get nothing.
--
-- Odds climb with rebirth count but a legendary is reachable on the very first
-- one, at about 3%. That matters: a ladder where the good stuff is gated behind
-- rebirth 20 tells a new player the chase is not for them yet.
--
-- Weights, not probabilities -- they are normalised at roll time, so tuning one
-- line cannot silently break the total.
function Config.getDropWeights(rebirths: number): { [string]: number }
	local r = math.clamp(rebirths, 0, 40)
	return {
		rare = math.max(10, 80 - r * 2.0),
		epic = 18 + r * 1.2,
		legendary = 2 + r * 0.8,
	}
end

-- Rebirths in a row without a legendary before one is guaranteed.
--
-- Pure chance has no floor: a player can be unlucky twelve times running and
-- reasonably conclude the drop is a lie. This caps the worst case at a number
-- somebody can actually see coming.
Config.LEGENDARY_PITY = 12

Config.DROP_RARITIES = { "rare", "epic", "legendary" }

Config.RARITY_COLOURS = {
	rare = Color3.fromRGB(96, 170, 240),
	epic = Color3.fromRGB(176, 110, 236),
	legendary = Color3.fromRGB(248, 190, 72),
}

-- Every skin of a given rarity. Rebuilt per call rather than cached: the pool
-- is tiny and a stale cache after a Config edit is a worse problem than the
-- handful of table allocations this costs.
function Config.getSkinsOfRarity(rarity: string): { string }
	local out = {}
	for key, skin in pairs(Config.SKINS) do
		if skin.rarity == rarity then
			table.insert(out, key)
		end
	end
	table.sort(out)
	return out
end

-- Picks a rarity for one rebirth. `rng` is passed in so the caller owns the
-- seed and the whole thing stays testable.
function Config.rollRarity(rebirths: number, sinceLegendary: number, rng: Random): string
	if sinceLegendary >= Config.LEGENDARY_PITY then
		return "legendary"
	end

	local weights = Config.getDropWeights(rebirths)
	local total = 0
	for _, rarity in ipairs(Config.DROP_RARITIES) do
		total += weights[rarity]
	end

	local roll = rng:NextNumber() * total
	for _, rarity in ipairs(Config.DROP_RARITIES) do
		roll -= weights[rarity]
		if roll <= 0 then
			return rarity
		end
	end
	return "rare"
end

function Config.isSkinUnlocked(key: string, owned: { [string]: boolean }, rebirths: number): boolean
	local skin = Config.SKINS[key]
	if not skin then
		return false
	end
	if skin.unlockRebirths then
		return rebirths >= skin.unlockRebirths
	end
	-- A drop-pool skin has no cost, but "no cost" must not read as "free".
	-- Without this, every legendary would be unlocked for everyone from the
	-- first second, because the fallback below treats cost 0 as unlocked.
	if skin.rarity then
		return owned[key] == true
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
-- stays the easy target and across the road is a choice.
--
-- Widened from 80 so the driveway has room for an actual car. At 80 the drive
-- was 6.4 studs against an 11.5-stud hatchback, so a parked car poked back
-- through its own gate and out into the road.
Config.STREET_SPACING = 104

-- The carriageway is a FIXED width, not whatever is left over.
--
-- It used to be derived from the moat, which meant widening the street just
-- widened the tarmac and the driveway never grew. Pinning the road is what
-- turns extra street space into driveway.
Config.ROAD_HALF_WIDTH = 8

-- How far the fence runs BACK from the plot centre to enclose the house.
--
-- Only the back moves. The front fence stays at PLOT_SIZE.X/2 + 1.6, which is
-- the line every heist number is tuned against -- a thief approaches from the
-- street, so lengthening the yard behind the piggy changes nothing about the
-- steal, the getaway or the drop-off.
Config.YARD_DEPTH = 70

Config.PLOTS_PER_ROW = 6

-- ============================================================
-- PERSISTENCE
-- ============================================================

Config.DATASTORE_NAME = "PiggyBank_Player"

-- Bumping this lets us migrate live saves later instead of wiping them.
-- v2 added the `upgrades` table for the defence and offence trees.
-- v3 added `cosmetics`, which rebirth deliberately does not reset.
-- ============================================================
-- PIG ACCESSORIES
-- ============================================================
--
-- Hats, glasses, capes and shoes, worn one per slot, all four at once. Skins
-- recolour the pig; these sit ON it, so a decorated piggy is a combination
-- rather than a single choice -- which is what makes it worth showing off.
--
-- Won by ROLLING, never bought directly, and a roll can only return something
-- you do not already own. That has three consequences worth stating, because
-- they are the whole design:
--
--   * There are no duplicates, so every roll is progress. A player is never
--     handed something they already have and told it was a prize.
--   * The collection therefore COMPLETES. This is a guaranteed ladder wearing
--     the clothes of a gamble, not a slot machine -- appropriate for an
--     audience that cannot consent to a real one.
--   * The price climbs with how many you own (see getRollCost), so the pace
--     is set by the collection rather than by whoever has the deepest vault.
--     Somebody sitting on ten million cannot clear the pool in one sitting.
--
-- ROLLS COST COINS, AND COINS MUST NEVER BE PURCHASABLE WITH ROBUX.
--
-- That is not a preference, it is the line that keeps this legal. Roblox
-- prohibits paid random-chance items for an under-13 audience, and "paid"
-- means reachable with real money -- selling coins for Robux would turn this
-- into a loot box on the spot, without a line of code changing here. If a
-- Robux coin pack is ever wanted, rolling has to move to a currency that can
-- only be earned by playing, BEFORE that pack ships. Selling a specific
-- accessory outright for Robux would be fine; selling the roll is not.
Config.ACCESSORY_RARITIES = {
	common    = { label = "Common",    weight = 100, colour = Color3.fromRGB(150, 162, 178) },
	rare      = { label = "Rare",      weight = 42,  colour = Color3.fromRGB(88, 156, 232) },
	epic      = { label = "Epic",      weight = 15,  colour = Color3.fromRGB(178, 118, 232) },
	legendary = { label = "Legendary", weight = 4,   colour = Color3.fromRGB(246, 198, 52) },
}

-- Where each slot hangs off the pig, in the same local space PiggyBank.build
-- uses -- so these move with the pig if its proportions ever change.
--
-- `anchors` is always a LIST. Three of the slots have exactly one attachment
-- point and the fourth has four, and a shoe slot that special-cased itself
-- everywhere it was read would be worse than one empty-looking loop.
Config.ACCESSORY_SLOTS = {
	hat = {
		order = 1, label = "HATS", empty = "Bare head",
		-- Where a hat's BRIM rests. The body is a 6-stud ball centred at y 8.5,
		-- so its top is 14.5; this sits a little into it so no gap opens under
		-- the brim. Every builder in this slot is authored with y=0 there.
		anchors = { Vector3.new(0, 14.15, 0) },
	},
	eyes = {
		order = 2, label = "GLASSES", empty = "No glasses",
		-- Eye height, and far enough forward to clear the eyeballs themselves.
		-- The eyes are balls at (+/-2.35, 10.6, 4.9) whose front faces reach
		-- z 5.53, and the head's surface at that height is z 5.62 -- so a lens
		-- at 5.5 was inside both. Sits 0.28 proud of the head instead.
		anchors = { Vector3.new(0, 10.6, 5.9) },
	},
	back = {
		order = 3, label = "BACKS", empty = "Nothing on the back",
		-- ON the back surface, not inside it. At y 11 the sphere's radius is
		-- 5.45, so z -5.6 sits a hair proud; -5.0 was 0.41 deep, which is why
		-- the jetpack came out of the middle of the pig.
		anchors = { Vector3.new(0, 11.0, -5.6) },
	},
	feet = {
		order = 4, label = "SHOES", empty = "Barefoot",
		-- One per leg. Legs stand at (+/-3.1, _, +/-3.1) and reach the ground
		-- at y 0.5, so a shoe centres just above that.
		-- ON THE LAWN (y 0.5 is the top of the plot slab), because both shoes
		-- are authored with y=0 as the point that touches the ground. Anchored
		-- at the middle of the shoe instead, the skates' wheels ended up under
		-- the grass.
		anchors = {
			Vector3.new(-3.1, 0.5, -3.1), Vector3.new(3.1, 0.5, -3.1),
			Vector3.new(-3.1, 0.5, 3.1), Vector3.new(3.1, 0.5, 3.1),
		},
	},
}

Config.ACCESSORIES = {
	-- HATS
	cap = {
		name = "Ball Cap", slot = "hat", rarity = "common", order = 1,
		colour = Color3.fromRGB(198, 72, 68), trim = Color3.fromRGB(240, 238, 230),
		blurb = "Worn backwards by absolutely everyone",
	},
	tophat = {
		name = "Top Hat", slot = "hat", rarity = "rare", order = 2,
		colour = Color3.fromRGB(32, 32, 40), trim = Color3.fromRGB(196, 46, 62),
		blurb = "For a pig with a portfolio",
	},
	crown = {
		name = "Gold Crown", slot = "hat", rarity = "epic", order = 3,
		colour = Color3.fromRGB(246, 198, 52), trim = Color3.fromRGB(226, 62, 88),
		blurb = "Rules over one lawn, absolutely",
	},
	halo = {
		name = "Halo", slot = "hat", rarity = "legendary", order = 4,
		colour = Color3.fromRGB(255, 238, 158), trim = Color3.fromRGB(255, 250, 220),
		blurb = "Innocent. Definitely never robbed anybody",
	},

	-- GLASSES
	nerd = {
		name = "Round Specs", slot = "eyes", rarity = "common", order = 5,
		colour = Color3.fromRGB(38, 34, 32), trim = Color3.fromRGB(198, 226, 240),
		blurb = "Has read the whole rulebook",
	},
	shades = {
		name = "Shades", slot = "eyes", rarity = "common", order = 6,
		colour = Color3.fromRGB(24, 24, 28), trim = Color3.fromRGB(52, 58, 72),
		blurb = "Did not see you there. Does not care",
	},
	visor = {
		name = "Cyber Visor", slot = "eyes", rarity = "epic", order = 7,
		colour = Color3.fromRGB(28, 30, 40), trim = Color3.fromRGB(88, 244, 226),
		blurb = "Scanning your vault. Probably",
	},

	-- BACKS
	cape = {
		name = "Hero Cape", slot = "back", rarity = "rare", order = 8,
		-- Puts the collar ON the shoulder surface; the flare does the rest.
		offset = Vector3.new(0, 1.8, 1.1),
		colour = Color3.fromRGB(196, 46, 62), trim = Color3.fromRGB(246, 198, 52),
		blurb = "Billows even indoors",
	},
	jetpack = {
		name = "Jetpack", slot = "back", rarity = "epic", order = 9,
		-- Stands off the back and rides high, clear of the tail ball.
		offset = Vector3.new(0, 1.0, -0.7),
		colour = Color3.fromRGB(188, 190, 198), trim = Color3.fromRGB(255, 146, 58),
		blurb = "Purely decorative. The pig is not going anywhere",
	},
	wings = {
		name = "Angel Wings", slot = "back", rarity = "legendary", order = 10,
		offset = Vector3.new(0, 0.4, -0.3),
		colour = Color3.fromRGB(252, 250, 244), trim = Color3.fromRGB(226, 236, 250),
		blurb = "Suspiciously well earned",
	},

	-- SHOES
	boots = {
		name = "Work Boots", slot = "feet", rarity = "common", order = 11,
		colour = Color3.fromRGB(124, 84, 52), trim = Color3.fromRGB(58, 44, 34),
		blurb = "Four of them. Obviously",
	},
	skates = {
		name = "Roller Skates", slot = "feet", rarity = "rare", order = 12,
		colour = Color3.fromRGB(240, 240, 246), trim = Color3.fromRGB(226, 62, 120),
		blurb = "Does not make the pig any faster",
	},
}

-- What a roll costs at `owned` accessories already collected.
--
-- Climbs steeply on purpose. The first is pocket money so everyone tries it;
-- the last is a real decision. Collecting the whole set comes to roughly
-- 900k, which sits it just under one rebirth -- expensive enough to be a
-- genuine coin sink at the top of the economy, cheap enough to finish.
Config.ROLL_BASE_COST = 12000
Config.ROLL_GROWTH = 1.30

function Config.getRollCost(owned: number): number
	return math.floor(Config.ROLL_BASE_COST * (Config.ROLL_GROWTH ^ math.max(0, owned)))
end

function Config.accessoryCount(): number
	local n = 0
	for _ in pairs(Config.ACCESSORIES) do
		n += 1
	end
	return n
end

-- ============================================================
-- HOUSES
-- ============================================================
--
-- The house behind your plot is pure prestige. It confers no advantage of any
-- kind, and that is deliberate: the power balance is already a closed system
-- of speed, time and distance, and hanging a stat off a status symbol would
-- reopen every one of those decisions.
--
-- Like skins, a house SURVIVES REBIRTH. It is the long tail of the collection
-- track -- the thing a player who has bought everything else is still working
-- toward, and the thing visible from across the street that says how long
-- somebody has been playing.
--
-- Priced well above the skins so it stays the last thing anyone finishes.
-- Everything is a linear ladder, not a set to pick from: you own tier N and
-- buy tier N+1.
-- `width` is the MAIN BLOCK, not the footprint. Wings, gables and roof slabs
-- all overhang it, so the actual extent can be half as wide again -- the Manor
-- measured 65 studs against a 51.2 fence interior and its wings stuck straight
-- through the side fence. House.build now measures what it actually built and
-- seats it from that; these numbers are trimmed so the measurement fits.
--
-- Each tier also owns its DRIVEWAY surface. The house itself stands 70 studs
-- behind the plot, so from the road the driveway is what actually announces
-- how far along someone is -- dirt, then gravel, then brick, and so on.
Config.HOUSE_TIERS = {
	{
		name = "Starter Shack", style = "shack", cost = 0,
		drive = { colour = Color3.fromRGB(122, 98, 74), material = Enum.Material.Ground, edge = false },
		width = 18, depth = 14, storeys = 1,
		walls = Color3.fromRGB(168, 152, 130), roof = Color3.fromRGB(112, 104, 96),
		trim = Color3.fromRGB(126, 108, 86),
		blurb = "Four walls and a leaky roof. Everyone starts here",
	},
	{
		name = "Cosy Cottage", style = "cottage", cost = 35000,
		drive = { colour = Color3.fromRGB(158, 154, 146), material = Enum.Material.Pebble, edge = false },
		width = 26, depth = 20, storeys = 1,
		walls = Color3.fromRGB(232, 216, 190), roof = Color3.fromRGB(142, 78, 62),
		trim = Color3.fromRGB(120, 84, 58),
		blurb = "Low, wide, and warm. Steep tiled roof and a real chimney",
	},
	{
		name = "Brick Townhouse", style = "townhouse", cost = 120000,
		drive = { colour = Color3.fromRGB(158, 96, 78), material = Enum.Material.Brick, edge = true },
		width = 20, depth = 16, storeys = 3,
		walls = Color3.fromRGB(148, 92, 76), roof = Color3.fromRGB(74, 70, 78),
		trim = Color3.fromRGB(238, 234, 226),
		blurb = "Three floors stacked narrow. Bay window and a stoop",
	},
	{
		name = "Suburban Villa", style = "villa", cost = 400000,
		drive = { colour = Color3.fromRGB(196, 194, 188), material = Enum.Material.Concrete, edge = true },
		width = 33, depth = 24, storeys = 2,
		walls = Color3.fromRGB(236, 228, 210), roof = Color3.fromRGB(96, 104, 100),
		trim = Color3.fromRGB(198, 188, 168),
		blurb = "Sprawling, low and wide, with a double garage",
	},
	{
		name = "Stone Manor", style = "manor", cost = 1400000,
		drive = { colour = Color3.fromRGB(206, 202, 192), material = Enum.Material.Slate, edge = true },
		width = 34, depth = 28, storeys = 3,
		walls = Color3.fromRGB(214, 210, 200), roof = Color3.fromRGB(70, 66, 80),
		trim = Color3.fromRGB(188, 182, 170),
		blurb = "Symmetrical wings, stone columns, and far too many windows",
	},
	{
		name = "Midnight Modern", style = "modern", cost = 5000000,
		drive = { colour = Color3.fromRGB(32, 33, 38), material = Enum.Material.Asphalt, edge = true, lit = true },
		width = 44, depth = 32, storeys = 2,
		walls = Color3.fromRGB(26, 27, 32), roof = Color3.fromRGB(18, 19, 23),
		trim = Color3.fromRGB(240, 202, 110),
		blurb = "Blacked-out glass box. Cantilevered upper floor, rooftop terrace",
	},

	-- The three tiers above here are the endgame ladder, and they are built
	-- around one idea: HEIGHT IS THE FLEX.
	--
	-- The house stands 70 studs behind its own piggy, which is why the driveway
	-- has been carrying the announcement so far -- from the road a house is a
	-- distant shape. Anything under about three storeys is only ever seen by
	-- somebody already standing on the lawn. These three go up instead of out,
	-- so they clear the treeline and read from anywhere on the street, and
	-- they light up at night so they read in the dark too. That is the whole
	-- reward: everyone can see it without leaving their own plot.
	--
	-- They still confer nothing. Prestige only.
	{
		name = "Neon Tower", style = "tower", cost = 15000000,
		drive = { colour = Color3.fromRGB(44, 42, 58), material = Enum.Material.Asphalt, edge = true, lit = true },
		width = 24, depth = 22, storeys = 6,
		walls = Color3.fromRGB(30, 32, 44), roof = Color3.fromRGB(22, 23, 32),
		trim = Color3.fromRGB(96, 232, 246),
		glow = Color3.fromRGB(96, 232, 246),
		blurb = "Six floors of glass with lit edges. Visible from the far end of the street",
	},
	{
		name = "Marble Palace", style = "palace", cost = 40000000,
		drive = { colour = Color3.fromRGB(228, 222, 206), material = Enum.Material.Marble, edge = true, lit = true },
		width = 46, depth = 30, storeys = 3,
		walls = Color3.fromRGB(244, 240, 230), roof = Color3.fromRGB(212, 176, 96),
		trim = Color3.fromRGB(246, 206, 108),
		glow = Color3.fromRGB(255, 226, 150),
		blurb = "Gold dome, colonnade, and lantern-lit steps. Unsubtle on purpose",
	},
	{
		name = "Sky Castle", style = "castle", cost = 100000000,
		drive = { colour = Color3.fromRGB(126, 122, 130), material = Enum.Material.Cobblestone, edge = true, lit = true },
		width = 40, depth = 34, storeys = 5,
		walls = Color3.fromRGB(158, 156, 166), roof = Color3.fromRGB(92, 52, 128),
		trim = Color3.fromRGB(212, 74, 96),
		glow = Color3.fromRGB(196, 128, 255),
		blurb = "Four turrets, battlements and a banner. The last thing anyone buys",
	},
}

-- Level 0 is the Starter Shack, which everyone owns from the first second.
function Config.getHouseTier(level: number)
	return Config.HOUSE_TIERS[math.clamp(level + 1, 1, #Config.HOUSE_TIERS)]
end

function Config.getHouseUpgradeCost(level: number): number?
	local next_ = Config.HOUSE_TIERS[level + 2]
	return if next_ then next_.cost else nil
end

Config.MAX_HOUSE_LEVEL = #Config.HOUSE_TIERS - 1

-- Which house is STANDING, as opposed to which is the highest one bought.
--
-- A house is prestige, and prestige is a matter of taste: someone who liked
-- the look of the Beach Villa should not be forced to live in a Neon Tower
-- forever because they bought one. So the ladder and the display are two
-- different numbers -- `houseLevel` is the rung reached, and decides what is
-- for sale next; `houseShown` is what is actually built on the plot.
--
-- Clamped against the ladder, so a save that somehow carries a shown tier
-- above the owned one builds the owned one rather than a house nobody paid
-- for. Missing means "the newest", which is how every pre-schema-9 save reads.
function Config.getShownHouseLevel(data: any): number
	local owned = data.houseLevel or 0
	local shown = data.houseShown
	if type(shown) ~= "number" then
		return owned
	end
	return math.clamp(math.floor(shown), 0, owned)
end

-- ============================================================
-- ADMIN
-- ============================================================
--
-- Roblox UserIds allowed to use the admin panel. A UserId is public
-- information -- anyone can read it off a profile page -- so there is nothing
-- secret here and nothing is weakened by this file being public.
--
-- The security is NOT this list. It is that AdminService re-checks every
-- single request against it on the SERVER before doing anything. The client
-- panel only exists to save the admin some typing; hiding a button protects
-- nothing, because anyone can fire a RemoteEvent.
--
-- The place owner is also admitted automatically, in AdminService, so this
-- keeps working if the experience is republished under another account.
Config.ADMINS = {
	[1403296598] = true,
}

function Config.isAdminUserId(userId: number): boolean
	return Config.ADMINS[userId] == true
end

-- Bumped for `sinceLegendary`. DataService.reconcile fills it in on old saves.
-- ============================================================
-- LAWN DECORATIONS
-- ============================================================
--
-- Bought, then placed AUTOMATICALLY into the next free slot for their zone.
--
-- There is deliberately no placement mode and no prompts on the lawn. A plot
-- already carries a collect prompt and a steal prompt, and adding six more
-- would clutter exactly the ground an owner is trying to defend on. Buying it
-- and having it appear is also one tap instead of four, which matters for the
-- age group and on touch.
--
-- Every decoration is non-colliding scenery, so none of this can body-block a
-- defender, a thief, or the dog.
--
-- Slot offsets are plot-local with +Z toward the street. They avoid the piggy
-- (centre), the kennel at (14, 4), and the sign post at (0, 22).
-- Where the road, verge and driveway sit between two facing rows.
--
-- Shared because PlotService now builds a per-house driveway and
-- NeighborhoodService still lays the road, and the two must agree exactly or
-- the driveway floats over the kerb. Returns plot-local Z distances measured
-- from a plot's own centre, with +Z toward the street.
function Config.streetMetrics()
	local streetHalf = Config.STREET_SPACING / 2
	local fenceOffset = Config.PLOT_SIZE.X / 2 + 1.6

	return {
		-- Street coordinates, measured from the road's centreline.
		roadHalfWidth = Config.ROAD_HALF_WIDTH,
		fenceLine = streetHalf - fenceOffset,

		-- Plot-local Z of the driveway's two ends: the fence, out to the kerb.
		driveNear = fenceOffset,
		driveFar = streetHalf - Config.ROAD_HALF_WIDTH,
	}
end

-- The driveway is the one strip of ground outside the fence that must stay
-- usable at every tier, so the top-tier moat leaves a causeway across it.
-- Deliberately independent of the fence gate: a bridge can be wide while the
-- gate behind it stays narrow, so this costs the defender nothing.
Config.DRIVEWAY_WIDTH = 13

-- Every slot faces the ROAD, and none of them carries a yaw.
--
-- Plot-local +Z is the street on both rows -- the far row is built with a
-- half-turn already in its plot CFrame -- and every ornament is authored
-- facing +Z. So the slot rotation that used to scatter them by 20, 90, 155,
-- 200 degrees was rotating each one AWAY from the only angle it is ever
-- viewed from.
--
-- That scatter was meant to read as a garden arranged by hand rather than a
-- showroom, and on a plan view it did. From the pavement it did not: the two
-- back slots were turned past 90 degrees, so the trophy showed its blank
-- back, the drip statue faced its own house, and the shark -- whose entire
-- silhouette is its side profile -- was nose-on again, which is the exact
-- bug its builder was rewritten to fix. An ornament has one good angle and
-- the viewer only ever stands in one place, so pointing it anywhere else
-- spends the ornament to buy a variety nobody is standing where they could
-- see.
--
-- It also fixed a spacing problem rather than causing one. The tight pairs
-- on this ring are the three front slots, separated along X at 17 studs;
-- with every item now square to the street their long axes run along X too,
-- and the two widest -- the gnome at 12.5 across the fists and the shark at
-- 13.7 nose to tail -- still clear each other. The side pairs are separated
-- along Z at 15 to 16, against a depth of about 5. Facing everything forward
-- turned the deepest ornaments side-on to their nearest neighbour.
--
-- `Decor.build` still reads `slot.yaw`, so a future slot that genuinely
-- wants an angle can carry one. Nothing here does.
Config.DECOR_SLOTS = {
	{ id = "lawnA", zone = "lawn", offset = Vector3.new(-17, 0, -16) },
	{ id = "lawnB", zone = "lawn", offset = Vector3.new(17, 0, -16) },
	{ id = "lawnC", zone = "lawn", offset = Vector3.new(-18, 0, 2) },
	{ id = "lawnD", zone = "lawn", offset = Vector3.new(-15, 0, 17) },
	{ id = "lawnE", zone = "lawn", offset = Vector3.new(15, 0, 18) },
	{ id = "lawnF", zone = "lawn", offset = Vector3.new(0, 0, -19) },
	-- One more, added with the silly ornaments, mirroring lawnC.
	--
	-- Only one, and out on the ring with the rest, because the lawn is 48
	-- studs across with a piggy bank in the middle of it and the widest
	-- ornament is a gnome measuring 12.5 across the fists. Six positions on
	-- that ring are 17 to 19 studs apart, which clears the two widest items
	-- standing side by side; a seventh squeezed between two of them would put
	-- an ornament through its neighbour. The obvious eighth spot -- front
	-- centre, at (0, 19) -- is the walk from the gate to the piggy, and is
	-- left empty on purpose.
	--
	-- Twelve lawn items against seven slots is deliberate. The lawn is a shelf
	-- you curate, not a checklist you complete: choosing what to leave in the
	-- shed IS the decoration.
	{ id = "lawnG", zone = "lawn", offset = Vector3.new(19, 0, 0) },

	-- On the driveway proper, between the gate and the kerb.
	{ id = "drive1", zone = "driveway", offset = Vector3.new(0, 0, 35) },

	-- Outside the fence, flanking the driveway. This is the ONLY ground out
	-- there that stays dry at every fence tier -- the moat takes the whole
	-- rest of the perimeter, so anything placed elsewhere would end up in the
	-- water the moment its owner bought tier 5.
	{ id = "vergeL", zone = "verge", offset = Vector3.new(-9.5, 0, 31) },
	{ id = "vergeR", zone = "verge", offset = Vector3.new(9.5, 0, 31) },
}

Config.DECOR_ITEMS = {
	flowerbed = {
		name = "Flower Bed", zone = "lawn", style = "flowers", order = 1,
		cost = 15000, swatch = Color3.fromRGB(214, 96, 132),
		blurb = "A splash of colour by the fence",
	},
	picnic = {
		name = "Picnic Table", zone = "lawn", style = "picnic", order = 2,
		cost = 45000, swatch = Color3.fromRGB(168, 124, 82),
		blurb = "Bench, table, parasol. Very neighbourly",
	},
	hoop = {
		name = "Basketball Hoop", zone = "lawn", style = "hoop", order = 3,
		cost = 110000, swatch = Color3.fromRGB(226, 116, 54),
		blurb = "Backboard and rim, out by the drive",
	},
	topiary = {
		name = "Topiary Piggy", zone = "lawn", style = "topiary", order = 4,
		cost = 260000, swatch = Color3.fromRGB(96, 150, 84),
		blurb = "A hedge trimmed into a pig. Obviously",
	},
	fountain = {
		name = "Stone Fountain", zone = "lawn", style = "fountain", order = 5,
		cost = 600000, swatch = Color3.fromRGB(198, 198, 190),
		blurb = "Three tiers and real running water",
	},

	-- ------------------------------------------------------------
	-- The silly shelf
	-- ------------------------------------------------------------
	--
	-- The first five lawn items are things a real garden has. These are not,
	-- and that is the point: a fountain says you are rich, a shark in trainers
	-- says you are rich AND you thought this was funny. Only the second one
	-- gets talked about, and being talked about is what a status item is FOR.
	--
	-- They are priced above the sensible ornaments for the same reason. The
	-- joke is the expensive part.
	--
	-- Every one of these is an ORIGINAL shape rather than a copy of a specific
	-- meme character. That is a shipping requirement, not squeamishness: the
	-- named ones -- brands, cartoon characters, the big brainrot names -- are
	-- somebody's trademark or copyright, Roblox moderation removes them, and a
	-- takedown costs the whole experience rather than the one ornament. The
	-- genre travels fine without the name: an enormous rubber duck is funny on
	-- its own, and a shark wearing trainers does not need to be anyone's
	-- shark.
	bigduck = {
		name = "Giant Rubber Duck", zone = "lawn", style = "bigduck", order = 10,
		cost = 80000, swatch = Color3.fromRGB(248, 208, 48),
		blurb = "Bath toy. Wrong scale. No explanation",
	},
	buffgnome = {
		name = "Swole Gnome", zone = "lawn", style = "buffgnome", order = 11,
		cost = 220000, swatch = Color3.fromRGB(212, 74, 68),
		blurb = "The gnome, but he lifts. Arms bigger than the hat",
	},
	tubeman = {
		name = "Wacky Waving Man", zone = "lawn", style = "tubeman", order = 12,
		cost = 500000, swatch = Color3.fromRGB(248, 118, 42),
		blurb = "The inflatable one from the car dealership",
	},
	looguy = {
		name = "Loo Guy", zone = "lawn", style = "looguy", order = 13,
		cost = 900000, swatch = Color3.fromRGB(238, 240, 244),
		blurb = "A toilet. With a head in it. Grinning at the street",
	},
	sharkshoes = {
		name = "Shark In Trainers", zone = "lawn", style = "sharkshoes", order = 14,
		cost = 2000000, swatch = Color3.fromRGB(86, 138, 190),
		blurb = "A shark. Standing on three white trainers",
	},
	trophy = {
		name = "Best Yard Trophy", zone = "lawn", style = "trophy", order = 15,
		cost = 4000000, swatch = Color3.fromRGB(232, 190, 74),
		blurb = "Nobody gave you this. You bought it yourself",
	},
	dripstatue = {
		name = "Drip Statue", zone = "lawn", style = "dripstatue", order = 16,
		cost = 12000000, swatch = Color3.fromRGB(28, 28, 32),
		blurb = "Big head, bigger chain, designer bag. Solid gold plinth",
	},

	bins = {
		name = "Wheelie Bins", zone = "verge", style = "bins", order = 6,
		cost = 30000, swatch = Color3.fromRGB(72, 128, 88),
		blurb = "Out by the kerb, exactly like everyone else's",
	},
	gnome = {
		name = "Garden Gnome", zone = "verge", style = "gnome", order = 7,
		cost = 180000, swatch = Color3.fromRGB(206, 68, 62),
		blurb = "Stands guard by the drive. Does nothing",
	},

	hatchback = {
		name = "Hatchback", zone = "driveway", style = "car", order = 8,
		cost = 200000, swatch = Color3.fromRGB(64, 118, 196),
		body = Color3.fromRGB(64, 118, 196), sporty = false,
		blurb = "Parked on the drive where everyone can see it",
	},
	sportscar = {
		name = "Sports Car", zone = "driveway", style = "car", order = 9,
		cost = 1200000, swatch = Color3.fromRGB(206, 54, 48),
		body = Color3.fromRGB(206, 54, 48), sporty = true,
		blurb = "Low, wide, and far too much for a cul-de-sac",
	},
}

-- First free slot in the item's zone, or nil when that zone is full.
function Config.firstFreeDecorSlot(zone: string, placed: { [string]: string }): string?
	for _, slot in ipairs(Config.DECOR_SLOTS) do
		if slot.zone == zone and placed[slot.id] == nil then
			return slot.id
		end
	end
	return nil
end

-- Bumped for `decor`. DataService.reconcile fills it in on existing saves.
Config.SCHEMA_VERSION = 9

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
