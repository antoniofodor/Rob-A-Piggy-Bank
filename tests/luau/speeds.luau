-- SPEED IS THE CURRENCY, AND `Config.BASE_WALK_SPEED` IS THE ONLY SPEED.
--
-- Designer decision (2026-09-21): "increase the walk speed and derive
-- everything else as a ratio to it so we can then freely increase/decrease
-- the walk speed and everything else can scale." So every speed in studs a
-- second that the game carries -- the carry penalty, the tiptoe, the climb,
-- the dodge and the two bursts, every dog tier, the officer, the patrol car,
-- the shopkeeper, the chasing neighbour, a strolling and a carrying
-- resident, the delivery van, the herd, every ride tier and the gadget
-- fallback throw -- is `BASE_WALK_SPEED * ratio`, and this suite holds three
-- things about that:
--
--   1. every speed-bearing field IS a ratio of the base, at the documented
--      ratio (the old absolute divided by 16), so a retune of the base moves
--      all of them together;
--   2. no absolute speed literal survives in Config or in the services that
--      write a WalkSpeed, so the next one typed is caught here rather than
--      found the day the base moves;
--   3. the orderings CLAUDE.md calls load-bearing -- carry < officer < walk,
--      maxed tiptoe < carry, Speed Boots never past 1.0, dog tiers strictly
--      increasing, herd < carry, car > officer, a neighbour always run down
--      -- hold at ANY base, asserted at 16, 20 and 12 by evaluating the ratios,
--      so a future base change cannot silently invert one.
--
-- What it deliberately does NOT pin: `THROW.gravity` (an acceleration; a
-- gadget's own flight speed is `sqrt(range * gravity)` and is a fact about the
-- world's physics over a FIXED range), `RIDE_STANCE_TURN_RATE` (degrees a
-- second, an angular rate), the bin's `exitHop` and the trampoline (vertical
-- launch velocities whose apex is set by gravity), the fence knockback and the
-- sprinkler nudge (impulses and distances), and `door.maxStep` (a distance per
-- tick, audited against the base by `auditHouseDoor` already).
local Config, sources = ...
local checks = 0
local function check(ok, message)
	assert(ok, message)
	checks += 1
end
local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-12)
end

local BASE = Config.BASE_WALK_SPEED
check(type(BASE) == "number" and BASE > 0, "BASE_WALK_SPEED is a positive number")

-- ---- 1. EVERY SPEED IS A RATIO OF THE BASE, AT THE DOCUMENTED RATIO ---------
-- Each row is {what, value in studs a second, ratio it must be}. The ratio is
-- the old absolute over 16 -- 34 / 16 is 2.125 -- so a row that stops matching
-- means somebody typed a new absolute rather than a new ratio.
local rows = {
	{ "POLICE.officerSpeed", Config.POLICE.officerSpeed, 0.90625 },
	{ "POLICE.carSpeed", Config.POLICE.carSpeed, 2.125 },
	{ "SHOPKEEPER.speed", Config.SHOPKEEPER.speed, 0.90625 },
	{ "NEIGHBOUR_CHASE.speed", Config.NEIGHBOUR_CHASE.speed, 0.6875 },
	{ "RESIDENTS.walk.speed", Config.RESIDENTS.walk.speed, 0.5625 },
	{ "RESIDENTS.walk.carrySpeed", Config.RESIDENTS.walk.carrySpeed, 0.4375 },
	{ "RESIDENTS.walk.roam.speed", Config.RESIDENTS.walk.roam.speed, 0.21875 },
	{ "THROW.speed", Config.THROW.speed, 3.75 },
	{ "DELIVERY.speed", Config.DELIVERY.speed, 1.25 },
	{ "herdSpeed()", Config.herdSpeed(), Config.HERDS.speedFraction },
	{ "maxRideSpeed()", Config.maxRideSpeed(), Config.RIDE_TIER_SPEED.legendary },
	{ "DOG_TIERS[1].speed", Config.DOG_TIERS[1].speed, 0.75 },
	{ "DOG_TIERS[2].speed", Config.DOG_TIERS[2].speed, 0.90625 },
	{ "DOG_TIERS[3].speed", Config.DOG_TIERS[3].speed, 1.0625 },
	{ "DOG_TIERS[4].speed", Config.DOG_TIERS[4].speed, 1.1875 },
	{ "DOG_TIERS[5].speed", Config.DOG_TIERS[5].speed, 1.3125 },
}
for _, row in ipairs(rows) do
	local what, value, ratio = row[1], row[2], row[3]
	check(type(value) == "number", what .. " is a number")
	check(near(value / BASE, ratio), ("%s is %.6f of the base walk, not %.6f"):format(what, value / BASE, ratio))
end
check(#Config.DOG_TIERS == 5, "every dog tier's speed is on the ratio list above")
check(Config.SHOPKEEPER.speed == Config.POLICE.officerSpeed, "the shopkeeper reads the officer's own number rather than a second copy of it")

-- The multipliers that were already ratios, held at their documented values
-- so the ordering checks below are about these numbers and no others.
check(Config.CARRY_SPEED_MULTIPLIER == 0.75, "the carry penalty is 0.75")
check(Config.TIPTOE.base == 0.35 and Config.TIPTOE.max == 0.6, "tiptoe runs 0.35 to 0.6 of the walk")
check(near(Config.TIPTOE.base + Config.UPGRADES.tiptoe.max * Config.TIPTOE.perLevel, Config.TIPTOE.max),
	"the Sneak rung count lands exactly on TIPTOE.max")
check(Config.CLIMB_MULTIPLIER == 0.35, "the climb is 0.35 of the walk")
check(Config.DODGE.multiplier == 1.9, "the dodge is 1.9 of whatever speed is left")
check(Config.BINS.exitBurst.peak == 1.30 and Config.DODGE.getUpBurst.peak == 1.25, "both bursts are multipliers")
check(Config.RIDE_TIER_SPEED.common == 1.5 and Config.RIDE_TIER_SPEED.rare == 1.65
	and Config.RIDE_TIER_SPEED.epic == 1.8 and Config.RIDE_TIER_SPEED.legendary == 2.1, "ride tiers are multipliers")
check(Config.DOG_PATROL_SPEED > 0 and Config.DOG_PATROL_SPEED < 1, "a patrolling dog is a fraction of its own chase speed")

-- ---- 2. NO ABSOLUTE SPEED LITERAL SURVIVES ----------------------------------
-- Every `<something>peed = <number>` on a non-comment line of Config and of
-- the services that drive a speed has to be zero (a stun, a stopped loop) or
-- something that is not a speed in studs: a skin animation's `speed` (which
-- always sits beside `kind =`), a particle emitter's `Speed = NumberRange`,
-- a sound's `PlaybackSpeed`, a fireworks burst. Anything else is an absolute
-- that the next base change will leave behind.
local function stripComments(source)
	-- Block comments first, then line comments; strings are not stripped, so
	-- a literal inside a string is still seen, which errs on the loud side.
	source = source:gsub("%-%-%[%[.-%]%]", "")
	source = source:gsub("%-%-%[=%[.-%]=%]", "")
	return source:gsub("%-%-[^\n]*", "")
end
local function scan(name, source)
	local found = {}
	local code = stripComments(source)
	local line = 0
	for text in (code .. "\n"):gmatch("([^\n]*)\n") do
		line += 1
		for key, number in text:gmatch("([%w_%.]*[sS]peed)%s*=%s*([%d%.]+)") do
			local n = tonumber(number)
			local particle = text:find("NumberRange", 1, true) ~= nil
			local anim = text:find("kind =", 1, true) ~= nil
			local sound = key:find("PlaybackSpeed", 1, true) ~= nil or key:find("burstSpeed", 1, true) ~= nil
			-- A particle's spin, in degrees a second: angular, like the ride
			-- stance's turn rate, and nothing to do with the walk.
			local angular = key:find("[rR]otSpeed$") ~= nil
			local base = key == "Config.BASE_WALK_SPEED"
			if n ~= 0 and not particle and not anim and not sound and not angular and not base then
				table.insert(found, ("%s:%d %s = %s"):format(name, line, key, number))
			end
		end
	end
	return found
end
for name, source in pairs(sources) do
	local found = scan(name, source)
	check(#found == 0, ("absolute speed literal(s) in %s: %s"):format(name, table.concat(found, "; ")))
end
check(sources.Config ~= nil and sources.HeistService ~= nil and sources.PoliceService ~= nil
	and sources.ResidentService ~= nil and sources.TrafficService ~= nil and sources.HerdService ~= nil
	and sources.GuardDog ~= nil and sources.GadgetService ~= nil and sources.StealthService ~= nil,
	"the scan covers Config and every service that drives a speed")
-- And the one write that matters most reads the constant rather than a number.
check(stripComments(sources.HeistService):find("local speed = Config.BASE_WALK_SPEED", 1, true) ~= nil,
	"currentSpeed starts from Config.BASE_WALK_SPEED")
check(stripComments(sources.HeistService):find("humanoid.WalkSpeed = Config.BASE_WALK_SPEED", 1, true) ~= nil,
	"the stun's release writes Config.BASE_WALK_SPEED back")
check(stripComments(sources.HeistService):find("WalkSpeed = 16", 1, true) == nil, "nothing writes WalkSpeed = 16")

-- ---- 3. THE ORDERINGS HOLD AT ANY BASE ----------------------------------
-- Everything is linear in the base, so the orderings are base-invariant by
-- construction -- and that is exactly the claim worth asserting rather than
-- trusting. Each speed is rebuilt from its RATIO at three bases: today's,
-- a quarter up, a quarter down.
local ratio = {
	walk = 1.0,
	carry = Config.CARRY_SPEED_MULTIPLIER,
	officer = Config.POLICE.officerSpeed / BASE,
	car = Config.POLICE.carSpeed / BASE,
	shopkeeper = Config.SHOPKEEPER.speed / BASE,
	neighbour = Config.NEIGHBOUR_CHASE.speed / BASE,
	stroll = Config.RESIDENTS.walk.speed / BASE,
	residentCarry = Config.RESIDENTS.walk.carrySpeed / BASE,
	potter = Config.RESIDENTS.walk.roam.speed / BASE,
	van = Config.DELIVERY.speed / BASE,
	herd = Config.herdSpeed() / BASE,
	tiptoeMax = Config.getTiptoeMultiplier(Config.UPGRADES.tiptoe.max),
	tiptoeBase = Config.getTiptoeMultiplier(0),
	climb = Config.CLIMB_MULTIPLIER,
}
local dogRatio = {}
for i, tier in ipairs(Config.DOG_TIERS) do
	dogRatio[i] = tier.speed / BASE
end
local bootsMax = Config.UPGRADES.boots.max

for _, base in ipairs({ 16, 20, 12 }) do
	local at = ("at a base of %d"):format(base)
	local s = {}
	for key, r in pairs(ratio) do
		s[key] = base * r
	end
	-- The officer's balance: carry < officer < walk, so holding the loot
	-- loses ground and delivering wins it back.
	check(s.carry < s.officer and s.officer < s.walk, "carry < officer < walk " .. at)
	-- The shopkeeper is the officer, so the same sentence.
	check(s.carry < s.shopkeeper and s.shopkeeper < s.walk, "carry < shopkeeper < walk " .. at)
	-- A sneak can get IN and can never sneak the money OUT.
	check(s.tiptoeMax < s.carry, "a maxed tiptoe is slower than carrying " .. at)
	check(s.tiptoeBase < s.tiptoeMax, "the Sneak rung buys speed " .. at)
	-- Speed Boots never exceed the walk.
	for level = 0, bootsMax do
		check(base * Config.getCarryMultiplier(level) <= s.walk + 1e-9,
			("Speed Boots level %d never exceed the base walk %s"):format(level, at))
	end
	check(near(base * Config.getCarryMultiplier(bootsMax), s.walk, 1e-9),
		"maxed Speed Boots carry at exactly the walk, never past it " .. at)
	-- Dog tiers strictly increasing, and the cheapest still catches a carrier.
	for i = 2, #dogRatio do
		check(base * dogRatio[i] > base * dogRatio[i - 1], ("dog tier %d is faster than tier %d %s"):format(i, i - 1, at))
	end
	check(base * dogRatio[1] >= s.carry, "the slowest dog keeps pace with a carrying thief " .. at)
	-- A herd is catchable on foot even while carrying.
	check(s.herd < s.carry, "a herd is slower than a carrying player " .. at)
	-- The car outruns its own officer, and the van is slower than the car.
	check(s.car > s.officer, "the car is quicker than the officer " .. at)
	check(s.van < s.car, "the van is slower than the patrol " .. at)
	-- A neighbour can always be run down: every resident speed sits under
	-- the carry, and a chasing neighbour falls behind a carrying thief.
	check(s.neighbour < s.carry, "a chasing neighbour is slower than a carrying thief " .. at)
	check(s.stroll < s.carry and s.residentCarry < s.stroll and s.potter < s.stroll,
		"a resident strolls, carries and potters all under the carry speed " .. at)
	-- The climb is a multiplier under the walk.
	check(s.climb < s.walk, "a climb is slower than a walk " .. at)
end

-- ---- 4. WHAT DERIVES FROM THE BASE FOLLOWS IT --------------------------
-- The robbery cycle and the patrol leg read the ratios, never a copy of the
-- number, so both come out as the arithmetic says at whatever base is set.
do
	local distance = Config.PLOT_SPACING - Config.STEAL_RANGE - Config.DROPOFF_RADIUS
	local crack = Config.CRACK.openHold + Config.CRACK.maxSteps * Config.CRACK.sweepSeconds
	local want = distance / BASE + distance / (BASE * Config.CARRY_SPEED_MULTIPLIER) + crack
	check(near(Config.robberyCycleSeconds(Config.CRACK.maxSteps), want, 1e-9),
		"robberyCycleSeconds walks out at the base and home at the carry")
	local m = Config.streetMetrics()
	local legStuds = (m.roadEndX - 16) - (m.roadStartX + 16)
	local cruise = Config.policeCruise()
	check(near(cruise.legSeconds, legStuds / Config.POLICE.carSpeed, 1e-9), "a patrol leg is the street over carSpeed")
	check(cruise.legs % 2 == 1 and cruise.legs >= 1, "the leg count is odd, so the car leaves by the far tunnel")
	-- A gadget's flight is solved from its range and the world's gravity, and
	-- deliberately does not move with the base.
	check(near(Config.throwSpeed(Config.GADGETS.plunger), math.sqrt(Config.GADGETS.plunger.range * Config.THROW.gravity), 1e-9),
		"a thrown gadget's speed is sqrt(range * gravity)")
	check(near(Config.throwSpeed(nil), BASE * 3.75, 1e-9), "the fallback throw is 3.75 of the base walk")
end

print(("speeds: %d checks passed (base %g)"):format(checks, BASE))
