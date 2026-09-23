-- Roaming herds (docs/HERDS-PLAN.md): the scheduler shape, the loose cap,
-- the per-member tier roll under an ABSOLUTE cap, the SKY DROP and the
-- recall that mirrors it, the announcement and its marker, the pick-up grant
-- through the Stage 1 placement path, the full-lawn refusal, and the
-- first-hold-wins race. Real Config and the real HerdService with the scene
-- stubbed: no Instance, no models, no Theme.
--
-- THE MOVEMENT IS NOT VERIFIED HERE AND CANNOT BE. A pack falling out of the
-- sky, keeping formation across the band and reading as a herd from the
-- pavement is a live-only thing -- what this file can pin is the STATE
-- MACHINE underneath it (drop -> roam -> recall -> gone), that nothing is
-- catchable until it has landed, and that every point the pack occupies or
-- aims at is inside the band, off the street and outside every yard.
--
-- SOME ASSERTIONS HERE READ `Config.HERDS.drop` THROUGH THE SAME FALLBACK
-- THE SERVICE DOES, because that table lands in a separate Config edit. The
-- suite passes either side of it: `DROP` below is the service's own answer
-- (`HerdService._dropSpec`), so the numbers under test are the numbers that
-- actually ran rather than a second copy of them.
local Config, sources = ...
local checks = 0
local function check(ok, msg) assert(ok, msg); checks += 1 end
-- ASSERTIONS THAT ARE WAITING ON A CONFIG BLOCK, recorded rather than
-- skipped. `Config.HERDS.followSpacing` and `.jitter` are solved against the
-- member's own size, and the member is the pedestal's size now -- so until
-- that block lands the formation numbers describe an animal a third of the
-- size of the one standing in it. A suite that asserted them anyway would go
-- red on a repo that is merely half-landed; one that said nothing would let
-- the edit be forgotten. It prints them at the end and they self-clear.
local pending = {}
local function whenScaled(scaled, ok, msg)
	if scaled then check(ok, msg) else table.insert(pending, msg) end
end
local names = setmetatable({}, { __index = function(_, k) return k end })

-- ---- A REAL ENOUGH VECTOR ---------------------------------------------------
-- The runner's Vector3 is an inert {X, Y, Z}; the service adds, scales and
-- normalises, so the suite supplies one that can.
local V = {}
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V) end
V.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V.__unm = function(a) return vec(-a.X, -a.Y, -a.Z) end
V.__mul = function(a, b)
	if type(a) == "number" then return vec(a * b.X, a * b.Y, a * b.Z) end
	return vec(a.X * b, a.Y * b, a.Z * b)
end
V.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
	if k == "Unit" then local m = t.Magnitude; return if m > 0 then vec(t.X / m, t.Y / m, t.Z / m) else vec() end
	if k == "Cross" then
		return function(a, b) return vec(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
	end
	return nil
end
local Vector3 = { new = vec, zero = vec(), zAxis = vec(0, 0, 1), yAxis = vec(0, 1, 0) }
local frame = setmetatable({}, { __mul = function(a) return a end })

-- ---- THE SERVICE, SCENE STUBBED ---------------------------------------------
local now = 1000
-- Server time is a DIFFERENT clock from os.clock: the dig stamp goes out in
-- the former, the service schedules in the latter, and the suite keeps them
-- a fixed distance apart so a stamp written from the wrong clock is caught.
local SERVER_OFFSET = 500000
local notices = {}
local saves = {}
local saved = {}
local grants, repaints = 0, 0
local warnings = {}
-- Who is on the street, for the drop announcement. A table the suite owns,
-- so a test can put players on and take them off.
local online = {}
local modules = {
	Config = Config,
	Remotes = { get = function() return { FireClient = function(_, player, msg, kind)
		table.insert(notices, { player = player, msg = msg, kind = kind })
	end } end },
	-- The beacon is stubbed in the tail, so `Theme` is only ever required
	-- rather than read; the fields are here so a fault shows up as a wrong
	-- colour rather than as an index of nil.
	Theme = {
		COOL = "COOL", COOL_INK = "COOL_INK", PAPER = "PAPER",
		MUTED = "MUTED", SAND_DEEP = "SAND_DEEP",
		card = function() end, outline = function() end,
		title = function() end, body = function() end,
	},
	PiggyModel = { MINI_CENTRE_Y = 1.15, build = function() error("live only") end, bodyOf = function() return nil end },
	DataService = {
		get = function(p) return saves[p] end,
		save = function(p) saved[p] = (saved[p] or 0) + 1 end,
	},
	SetService = {
		owns = function(data, kind, key) return data.cosmetics.owned[key] == true end,
		grant = function(player, kind, key)
			local d = saves[player]
			d.cosmetics.owned[key] = true
			Config.addPiggy(d, key, true)
			grants += 1
			return true
		end,
		repaint = function() repaints += 1 end,
	},
}
local env = setmetatable({
	require = function(name) return assert(modules[name], name) end,
	game = { GetService = function(_, name)
		if name == "ReplicatedStorage" then return { Shared = names } end
		if name == "RunService" then return { Heartbeat = { Connect = function() end } } end
		if name == "Workspace" then return { GetServerTimeNow = function() return now + SERVER_OFFSET end } end
		if name == "Players" then return { GetPlayers = function() return online end } end
		return {}
	end },
	script = { Parent = names },
	Vector3 = Vector3,
	CFrame = { lookAt = function() return frame end, Angles = function() return frame end, new = function() return frame end },
	os = { clock = function() return now end },
	task = { spawn = function() end, wait = function() end },
	warn = function(m) table.insert(warnings, m) end,
	built = 0,
	beaconsBuilt = 0,
	beaconsDestroyed = 0,
	puffs = 0,
	lastFade = -1,
}, { __index = getfenv() })
local tail = [[
buildMember = function(herd, member)
	-- A model stub that REMEMBERS its attributes, so a test can read back
	-- what the service published rather than only counting writes.
	local attrs = {}
	member.model = {
		Destroy = function() end,
		PivotTo = function() end,
		SetAttribute = function(_, name, value) attrs[name] = value end,
		GetAttribute = function(_, name) return attrs[name] end,
	}
	-- The catch prompt, stubbed down to the one property this suite is
	-- about: whether a member can be caught. The real builder starts it
	-- disabled unless the pack is already on the ground, and this mirrors
	-- that rather than inventing a second rule.
	member.prompt = { Enabled = herd.state == "roam" }
	built += 1
end
-- The drop-zone marker is Instances and Theme; what a suite can hold is that
-- one is put up at the drop, that it is taken down on the beacon's own clock
-- and that nothing outlives its herd.
buildBeacon = function(herd)
	beaconsBuilt += 1
	return { Destroy = function() beaconsDestroyed += 1 end }
end
fadeBeacon = function(_, alpha) lastFade = alpha end
landingPuff = function(member, when) puffs += 1 end
reach = function() return true end
HerdService._herds = herds
HerdService._next = function() return nextSpawnAt end
HerdService._setNext = function(t) nextSpawnAt = t end
HerdService._step = stepHerd
HerdService._stepAll = stepAll
HerdService._dropSpec = dropSpec
return HerdService
]]
local code, n = sources.HerdService:gsub("return HerdService%s*$", tail)
assert(n == 1, "HerdService's return line was not found")
local run = assert(loadstring(code, "HerdService"))
setfenv(run, env)
local H = run()
local HERDS = Config.HERDS
local DROP = H._dropSpec()
local ROUTED = Config.herdRoute ~= nil

local function save()
	return { piggies = { owned = {}, till = Config.DEFAULT_SKIN }, cosmetics = { owned = {} } }
end
local function player(name)
	local p = { Name = name }
	saves[p] = save()
	return p
end

-- ---- THE TABLE AND ITS AUDIT ------------------------------------------------
check(Config.rarityRank(HERDS.tierCap) >= 1, "the tier cap names a real tier on RARITY_ORDER")
check(Config.rarityRank(HERDS.tierCap) < #Config.RARITY_ORDER,
	"the cap is holding something back rather than admitting the whole ladder")
check(HERDS.maxLoose >= 1 and HERDS.spawnEverySeconds > 0, "a cap and a rate that can spawn at all")
check(HERDS.range == Config.COLLECT_RANGE and HERDS.hold == Config.PIGGY_HAUL.takeHold,
	"the catch prompt reads the pedestal take's own range and hold rather than a second number")
check(#Config.auditHerds() == 0, "the shipped placeholder table audits clean: " .. table.concat(Config.auditHerds(), "; "))

local function provoke(mutate, restore, wanted, why)
	mutate()
	local problems = Config.auditHerds()
	local fired = false
	for _, p in ipairs(problems) do
		if p:find(wanted, 1, true) then fired = true end
	end
	restore()
	check(fired, why)
	check(#Config.auditHerds() == 0, "audit clean again after: " .. why)
end
local cap = HERDS.tierCap
provoke(function() HERDS.tierCap = "mythical" end, function() HERDS.tierCap = cap end,
	"[herds.cap]", "audit refuses a cap that is not a tier")
provoke(function() HERDS.roster.stray.tiers.legendary = 5 end,
	function() HERDS.roster.stray.tiers.legendary = nil end,
	"[herds.roster]", "audit refuses a roster row weighting a tier above the cap")
local loose = HERDS.maxLoose
provoke(function() HERDS.maxLoose = 0 end, function() HERDS.maxLoose = loose end,
	"[herds.cap]", "audit refuses a cap of zero herds")
-- The dig table and the gap, the four ways they can be wrong on paper.
local everyMin, digSeconds = HERDS.dig.every.min, HERDS.dig.seconds
provoke(function() HERDS.dig.every.min = 0 end, function() HERDS.dig.every.min = everyMin end,
	"[herds.dig]", "audit refuses a dig interval band that cannot draw")
provoke(function() HERDS.dig.seconds = everyMin end, function() HERDS.dig.seconds = digSeconds end,
	"[herds.dig]", "audit refuses a dig as long as the shortest gap between digs")
provoke(function() table.insert(HERDS.dig.never, "wander") end, function() table.remove(HERDS.dig.never) end,
	"[herds.dig]", "audit refuses a never-state the herd does not have")
-- THE BORE CLEARANCE, WHILE THERE IS STILL A BORE TO CLEAR. A pack is
-- dropped in now, so no two packs can queue through a tunnel and this check
-- is a constraint on a walk nothing takes any more. It is asserted while
-- `Config.herdRoute` is still standing and skipped once the Config edit
-- retires it -- rather than deleted, because a check that quietly stops
-- being run is the thing this suite exists to prevent.
if ROUTED then
	local gap = HERDS.spawnEverySeconds
	provoke(function() HERDS.spawnEverySeconds = 1 end, function() HERDS.spawnEverySeconds = gap end,
		"[herds.rate]", "audit refuses a spawn gap that births a pack on the last one's tail")
end
local sample = HERDS.pathSample
provoke(function() HERDS.pathSample = 0 end, function() HERDS.pathSample = sample end,
	"[herds.ground]", "audit refuses a path sample of zero")

-- ---- THE DESIGNER'S TWO NUMBERS -------------------------------------------
check(HERDS.maxLoose == 5, "five herds loose at once")
check(HERDS.size.min == 10 and HERDS.size.max == 10, "a pack is exactly ten")
check(HERDS.spawnEverySeconds < HERDS.roam.min,
	"the entry gap is far shorter than a roam, so the cap fills at boot rather than one herd a roam")
check(HERDS.replaceDelay < HERDS.spawnEverySeconds, "a replacement is due sooner than a fresh entry")
-- The gap clears the bore, by the same arithmetic the audit holds -- while
-- there is still a bore. See the note above the provoke.
if ROUTED then
	local g0 = Config.herdGround()
	local fileLength = (HERDS.size.max - 1) * HERDS.followSpacing
	local kerbLeg = (g0.tunnelX + g0.tunnelDepth - 6) - g0.corridorX
	check(HERDS.spawnEverySeconds * Config.herdSpeed() >= fileLength + kerbLeg,
		("a pack has walked its file (%.1f) off the kerb leg (%.1f) before the next is born"):format(fileLength, kerbLeg))
end
provoke(function() HERDS.speedFraction = 1.2 end, function() HERDS.speedFraction = 0.4 end,
	"[herds.speed]", "audit refuses a herd faster than a walking player")

-- ---- THE DAMPED PICKER ------------------------------------------------------
-- Weighted, the last pick DAMPED rather than excluded. At two rows,
-- exclusion collapses into strict alternation and the weights do nothing;
-- damping keeps the repeat possible and the weights meaningful.
check(Config.pickWeighted({}, nil, 0.35, 0.5) == nil, "an empty roster picks nothing")
check(Config.pickWeighted({ a = 0, b = 0 }, nil, 0.35, 0.5) == nil, "an all-zero roster picks nothing")
check(Config.pickWeighted({ b = 1, a = 1 }, nil, 0.35, 0.1) == "a"
	and Config.pickWeighted({ b = 1, a = 1 }, nil, 0.35, 0.9) == "b",
	"keys are walked in sorted order, so the same ticket picks the same key everywhere")
do
	local repeats, sweeps = 0, 1000
	for i = 0, sweeps - 1 do
		if Config.pickWeighted({ a = 1, b = 1 }, "a", 0.35, i / sweeps) == "a" then repeats += 1 end
	end
	local share = repeats / sweeps
	check(share > 0.2 and share < 0.32,
		("the last pick repeats about 26%% of the time (0.35 / 1.35), never 0%% and never 50%%: got %.3f"):format(share))
end

-- The service picks its KIND through that same function with its own last
-- pick damped: the repeat is possible (never strict alternation) and rarer
-- than the undamped weights alone would make it.
do
	local total = 0
	for _, row in pairs(HERDS.roster) do total += row.weight end
	local herd = assert(H.spawn("stray"))
	check(herd.kind == "stray" and H.count() == 1, "an admin spawn names its kind and counts as loose")
	local again, sweeps = 0, 1000
	for i = 0, sweeps - 1 do
		if H.pickKind(i / sweeps) == "stray" then again += 1 end
	end
	local share = again / sweeps
	local undamped = HERDS.roster.stray.weight / total
	check(share > 0, "the kind that just spawned can spawn again -- it is damped, not excluded")
	check(share < undamped, ("a repeat is rarer than the raw weight says: %.3f against %.3f"):format(share, undamped))
	H.despawn(herd)
	check(H.count() == 0, "despawn takes the herd off the loose list")
end

-- ---- THE TIER ROLL UNDER AN ABSOLUTE CAP ------------------------------------
do
	local above = 0
	for i = 0, 199 do
		local tier = Config.herdRollTier({ common = 1, legendary = 100 }, "rare", i / 200)
		check(tier == "common", "a legendary weight of 100 under a rare cap rolls common every time, got " .. tostring(tier))
		if tier == "legendary" then above += 1 end
	end
	check(above == 0, "the cap is ABSOLUTE: an over-cap weight is dropped, never clamped onto the cap tier")
	check(Config.herdRollTier({ epic = 5 }, "rare", 0.5) == nil,
		"a row with nothing under the cap rolls nothing rather than promoting")
	local seen = {}
	for i = 0, 99 do
		seen[Config.herdRollTier({ common = 50, rare = 50 }, "rare", i / 100)] = true
	end
	check(seen.common and seen.rare and not seen.epic, "both weighted tiers under the cap can roll")
	check(Config.herdRollTier({ common = 1, bogus = 100 }, "rare", 0.99) == "common",
		"a tier the ladder does not know is never rolled")
end

-- ---- THE SKIN POOL ----------------------------------------------------------
for rank = 1, Config.rarityRank(HERDS.tierCap) do
	local tier = Config.RARITY_ORDER[rank]
	local pool = Config.herdSkinPool(tier)
	check(#pool > 0, "the " .. tier .. " pool is stocked")
	for _, key in ipairs(pool) do
		local spec = Config.SKINS[key]
		check(spec ~= nil and Config.rarityOf(spec) == tier, key .. " is a " .. tier)
		check(not Config.isEarnedElsewhere(spec) and spec.aura == nil,
			key .. " is neither earned elsewhere nor an aura")
	end
	for i = 2, #pool do
		check(pool[i - 1] < pool[i], "the pool is sorted, so a ticket is reproducible")
	end
end

-- A member roll lands under the cap, on a catalogue key, every time.
do
	for i = 0, 99 do
		local key, tier = Config.herdDraw(HERDS.roster.prize.tiers, i / 100, (i * 7 % 100) / 100)
		check(key ~= nil and Config.SKINS[key] ~= nil, "a draw hands back a catalogue key")
		check(Config.rarityRank(tier) <= Config.rarityRank(HERDS.tierCap), "a draw never exceeds the cap")
		check(Config.rarityOf(Config.SKINS[key]) == tier, "the key's own rarity is the tier it was rolled at")
	end
end

-- AN EMPTY TIER FALLS DOWN THE LADDER, NEVER UP. Provoked with a tier no
-- skin carries, appended to the ladder and set as the cap for the test.
do
	table.insert(Config.RARITY_ORDER, "herdtest")
	local oldCap = HERDS.tierCap
	HERDS.tierCap = "herdtest"
	local key, tier = Config.herdDraw({ herdtest = 100 }, 0.5, 0.5)
	check(key ~= nil, "a tier with no stock falls to one that has some")
	check(Config.rarityRank(tier) < Config.rarityRank("herdtest"), "and it falls DOWN, not up")
	HERDS.tierCap = oldCap
	table.remove(Config.RARITY_ORDER)
	check(Config.rarityRank("herdtest") == 0, "the ladder is restored")
end

-- ---- FORMATION --------------------------------------------------------------
do
	local seen = {}
	for i = 2, 6 do
		local right, back = H.formationOffset(i, 4)
		check(back > 0, "a follower stands BEHIND the leader")
		local k = right .. "," .. back
		check(not seen[k], "every follower has a slot of its own")
		seen[k] = true
	end
	local r0, b0 = H.formationOffset(1, 4)
	check(r0 == 0 and b0 == 0, "the leader's slot is the pack anchor itself")

	-- THREE ABREAST: ten is three rows deep, not five, and seven wide.
	local maxBack, maxRight, rows = 0, 0, {}
	for i = 2, 10 do
		local right, back = H.formationOffset(i, HERDS.followSpacing)
		maxBack = math.max(maxBack, back)
		maxRight = math.max(maxRight, math.abs(right))
		rows[back] = (rows[back] or 0) + 1
	end
	check(maxBack == 3 * HERDS.followSpacing, ("a pack of ten is three rows deep: %.1f studs"):format(maxBack))
	check(maxRight == HERDS.followSpacing, "and one spacing either side of the centre line")
	for back, n in pairs(rows) do
		check(n == 3, ("row at %.1f holds three"):format(back))
	end
	-- NEIGHBOURS IN A ROW CLEAR THE WIDEST MEMBER THAT CAN STAND THERE, and
	-- that width is now the PEDESTAL'S, not the mini's. A scale-1 member is
	-- 2.2 * PIGGY_PEDESTAL.display across and the band's ceiling is
	-- PIGGY_SCALE.max on top of that, so the spacing has to clear the
	-- product -- which is exactly what scaling the old 3.5 by the same
	-- display factor preserves.
	local widest = 2.2 * Config.PIGGY_PEDESTAL.display * Config.PIGGY_SCALE.max
	local scaled = math.abs(HERDS.followSpacing / Config.PIGGY_PEDESTAL.display - 3.5) < 1e-6
	whenScaled(scaled, HERDS.followSpacing > widest,
		("a row's neighbours clear the widest possible member (%.2f) -- followSpacing has to be %.4f, is %.4f")
			:format(widest, 3.5 * Config.PIGGY_PEDESTAL.display, HERDS.followSpacing))
	whenScaled(scaled, HERDS.followSpacing - widest > 2,
		("and by two studs, which is the 0.64 the 2.2-stud mini had times the display factor: %.2f")
			:format(HERDS.followSpacing - widest))
	-- The formation is the SAME multiple of a member it always was: the
	-- numbers moved with the animal rather than being re-picked.
	whenScaled(scaled, scaled,
		("followSpacing is the old 3.5 times the pedestal's display factor (%.4f)")
			:format(3.5 * Config.PIGGY_PEDESTAL.display))
	whenScaled(scaled, math.abs(HERDS.jitter / Config.PIGGY_PEDESTAL.display - 1.2) < 1e-6,
		("and jitter is the old 1.2 times the same factor (%.4f), is %.4f")
			:format(1.2 * Config.PIGGY_PEDESTAL.display, HERDS.jitter))

	-- ONE SHAPE, NOT TWO. The single-file kerb variant went with the tunnel
	-- walk: a third argument that silently did nothing would be worse than
	-- an absent one, so the parameter is gone rather than ignored.
	local right, back = H.formationOffset(3, HERDS.followSpacing, true)
	local right2, back2 = H.formationOffset(3, HERDS.followSpacing)
	check(right == right2 and back == back2,
		"formationOffset has no file mode left: a third argument changes nothing")
end

-- ---- THE CAP AND THE TIMER --------------------------------------------------
do
	H._setNext(now)
	check(H.canSpawn(now), "due and under the cap: may spawn")
	local a = assert(H.spawn())
	check(not H.canSpawn(now), "the gap holds the next one back")
	check(H._next() == now + HERDS.spawnEverySeconds, "the gap IS the one named constant")
	check(H.canSpawn(now + HERDS.spawnEverySeconds), "and it comes due again after exactly that")
	local spawned = { a }
	for i = 2, HERDS.maxLoose do
		table.insert(spawned, (assert(H.spawn())))
	end
	check(H.count() == HERDS.maxLoose, "five loose")
	local c, why = H.spawn()
	check(c == nil and why and why:find("cap", 1, true), "the sixth is refused by the cap, out loud: " .. tostring(why))
	check(not H.canSpawn(now + 10 * HERDS.spawnEverySeconds), "at the cap, no timer makes it spawn")
	H._setNext(now + HERDS.spawnEverySeconds)
	H.despawn(a)
	check(H._next() <= now + HERDS.replaceDelay, "when one exits, the next is due after the short replace delay")
	-- WHERE THE FIVE WENT: three-and-two across the bands. Which END of a
	-- band a pack lands on is free now -- a drop needs no corridor to arrive
	-- through, so there is nothing to queue and nothing to alternate.
	local sides = { [-1] = 0, [1] = 0 }
	for _, h in ipairs(spawned) do
		sides[h.side] += 1
		check(h.entryEnd == nil and h.exitEnd == nil and h.route == nil,
			"a dropped pack carries no tunnel end and no route")
	end
	check(math.abs(sides[-1] - sides[1]) == 1, ("five packs split three-and-two across the two bands: %d / %d"):format(sides[-1], sides[1]))
	for _, h in ipairs(spawned) do
		if h ~= a then H.despawn(h) end
	end
	check(H.count() == 0, "clear")
	check(H.spawn("nonsense") == nil, "an unknown kind is refused")
	check(#a.members == 10, "a pack is exactly ten")
	for _, m in ipairs(a.members) do
		check(Config.rarityRank(m.tier) <= Config.rarityRank(HERDS.tierCap), "every member is under the cap")
		check(Config.SKINS[m.key] ~= nil, "every member wears a catalogue skin")
	end
end

-- ---- FIVE LOOSE AT STEADY STATE, THROUGH THE REAL SCHEDULER --------------
-- `HerdService.tick` is the scheduler's own beat, driven here every half
-- second against the stubbed clock with every herd stepped in between, as
-- the Heartbeat would. Boot fills the cap one pack per gap from the first
-- spawn delay; from then on the count is five, dipping only inside the
-- replace delay after an exit, and never falls far.
do
	H.clear()
	H._setNext(now + HERDS.firstSpawnDelay)
	local t0 = now
	local births = {}
	local seen = 0
	local function poll()
		local c = H.count()
		if c > seen then
			for _ = seen + 1, c do table.insert(births, now - t0) end
		end
		seen = c
	end
	-- Fill.
	local fillBy = HERDS.firstSpawnDelay + (HERDS.maxLoose - 1) * HERDS.spawnEverySeconds
	while now - t0 <= fillBy + 0.5 do
		H.tick(now)
		H._stepAll(0.5)
		poll()
		now += 0.5
	end
	check(H.count() == HERDS.maxLoose, ("the cap is full %.0fs after boot"):format(fillBy))
	check(#births == HERDS.maxLoose, "five births")
	for i, t in ipairs(births) do
		local want = HERDS.firstSpawnDelay + (i - 1) * HERDS.spawnEverySeconds
		check(math.abs(t - want) <= 0.51, ("pack %d is born at %.1fs, one gap after the last (%.0f)"):format(i, t, want))
	end
	-- Run on: three full lifetimes past the fill, counting the loose herds
	-- on every beat.
	local samples, total, minLoose, exits = 0, 0, HERDS.maxLoose, 0
	local lastCount = H.count()
	local lifetime = HERDS.roam.max + 90
	while now - t0 <= fillBy + 3 * lifetime do
		H.tick(now)
		H._stepAll(0.5)
		local c = H.count()
		if c < lastCount then exits += lastCount - c end
		lastCount = c
		samples += 1
		total += c
		minLoose = math.min(minLoose, c)
		now += 0.5
	end
	check(exits >= HERDS.maxLoose * 2, ("packs cycled through: %d exits"):format(exits))
	-- THE DIP GOT DEEPER WHEN THE WALK WENT, and that is recorded rather than
	-- tuned away here. A pack used to spend 21.2 s walking in and 21.4 s
	-- walking out; it now spends 3.3 s falling and 3.0 s rising, so a life is
	-- about 36 s shorter, packs turn over faster, and exits cluster more --
	-- the cap refills at one pack per `spawnEverySeconds` whatever happens,
	-- so a burst of three exits is three packs short for a while. The MEAN
	-- below is the assertion that matters; the lever for the dip is
	-- `HERDS.roam`, and the arithmetic for restoring the shipped supply rate
	-- is in the report that came with the drop.
	check(minLoose >= HERDS.maxLoose - 3, ("never more than three packs short of the cap at once: min %d"):format(minLoose))
	local mean = total / samples
	check(mean >= HERDS.maxLoose - 0.5, ("on average %.2f of %d packs loose"):format(mean, HERDS.maxLoose))
	print(("herds: steady state over %.0fs -- mean %.2f loose, min %d, %d exits, %d births"):format(
		samples * 0.5, mean, minLoose, exits, exits + HERDS.maxLoose))
	check(H.count() == HERDS.maxLoose or H._next() - now <= HERDS.spawnEverySeconds,
		"at the end either the cap is full or the replacement is already due inside a gap")
	H.clear()
end

-- ---- THE GRANT: THE STAGE 1 PLACEMENT PATH ----------------------------------
do
	local p = player("catcher")
	local key = Config.herdSkinPool("common")[1]
	local ok, why = H.grant(p, key)
	check(ok and why == nil, "a first copy is granted")
	check(grants == 1 and repaints == 0, "the FIRST copy goes through SetService.grant, which owns the pushes")
	check(saves[p].piggies.owned[key] == 1 and Config.piggySlots(saves[p])[1].key == key,
		"and it stands on the front pedestal")
	ok = H.grant(p, key)
	check(ok, "a second copy is granted too -- a repeat is a second piggy, not a spare")
	check(grants == 1 and repaints == 1 and (saved[p] or 0) == 1,
		"the REPEAT steps around grant's early-out: addPiggy, repaint, save")
	check(saves[p].piggies.owned[key] == 2 and Config.piggySlots(saves[p])[2].key == key,
		"placement is ownership: two owned, two standing, front to back")
	check(not H.grant(p, "not-a-skin"), "a key outside the catalogue is refused")
	check(not H.grant({ Name = "nobody" }, key), "no save loaded is a refusal rather than a throw")

	-- A FULL LAWN REFUSES OUT LOUD AND MINTS NOTHING.
	while Config.firstFreePiggySlot(saves[p]) do
		Config.addPiggy(saves[p], key, true)
	end
	local ownedBefore = saves[p].piggies.owned[key]
	local ok2, why2 = H.grant(p, key)
	check(ok2 == false and type(why2) == "string" and why2:find("lawn is full", 1, true),
		"a full lawn is refused and the refusal names the fix: " .. tostring(why2))
	check(saves[p].piggies.owned[key] == ownedBefore, "and nothing was minted into a ghost")
end

-- ---- FIRST HOLD WINS --------------------------------------------------------
do
	H._setNext(now)
	local herd = assert(H.spawn("stray"))
	local size = #herd.members
	local member = herd.members[1]
	local p1, p2 = player("first"), player("second")
	notices = {}
	-- NOTHING IN THE AIR IS CATCHABLE, and the prompt being disabled is only
	-- half of that: `reach` is measured against a member's GROUND point, so a
	-- player standing on the landing zone is in range of a pig 120 studs over
	-- their head. Re-asked on the trigger, the way every reach here is.
	check(not H.claim(herd, member, p1), "a member still falling cannot be claimed")
	local yet = false
	for _, n in ipairs(notices) do
		if n.player == p1 and n.msg:find("not on the ground", 1, true) then yet = true end
	end
	check(yet, "and the refusal says why")
	while herd.state == "drop" do
		H._step(herd, 0.1, now)
		now += 0.1
	end
	notices = {}
	-- BASELINED, because `piggyPlacedCount` counts the TILL as well as the
	-- plinths and every fresh save's till is `Config.DEFAULT_SKIN` -- which is
	-- itself a common and therefore herd-eligible. Compared against a pinned
	-- 1 this was a one-in-nineteen flake that read as the grant being broken.
	local had1 = Config.piggyPlacedCount(saves[p1], member.key)
	local had2 = Config.piggyPlacedCount(saves[p2], member.key)
	check(H.claim(herd, member, p1), "the first player to finish the hold gets it")
	check(#herd.members == size - 1, "the member leaves the herd")
	check(Config.piggyPlacedCount(saves[p1], member.key) == had1 + 1, "and lands on the winner's lawn")
	check(not H.claim(herd, member, p2), "the second is refused")
	local told = false
	for _, n in ipairs(notices) do
		if n.player == p2 and n.kind == "warn" then told = true end
	end
	check(told, "and told so, out loud")
	check(Config.piggyPlacedCount(saves[p2], member.key) == had2, "the loser got nothing")
	local gotIt = false
	for _, n in ipairs(notices) do
		if n.player == p1 and n.kind == "good" then gotIt = true end
	end
	check(gotIt, "the winner is told what they caught")

	-- A refused grant hands the member BACK: still catchable by somebody with room.
	local full = player("full")
	local key = herd.members[1].key
	while Config.firstFreePiggySlot(saves[full]) do
		Config.addPiggy(saves[full], key, true)
	end
	local m2 = herd.members[1]
	check(not H.claim(herd, m2, full), "a full lawn cannot claim")
	check(m2.taken == false and herd.members[1] == m2, "and the piggy stays with the herd for the next player")

	-- Catch the whole pack: an empty herd ends and pulls the next spawn in.
	H._setNext(now + HERDS.spawnEverySeconds)
	while #herd.members > 0 do
		check(H.claim(herd, herd.members[1], player("greedy")), "every remaining member can be caught")
	end
	check(H.count() == 0, "a herd whose last member is caught is gone")
	check(H._next() <= now + HERDS.replaceDelay, "and its replacement is due after the replace delay")
end

-- ---- GROUND: OFF THE STREET, OUTSIDE EVERY YARD ------------------------------
-- The yard rectangle as PlotService.yardContaining tests it, rebuilt here
-- from the same constants, and registered as the veto Main registers.
local streetHalf = Config.STREET_SPACING / 2
local function inYard(x, z)
	if math.abs(z) < streetHalf - Config.PLOT_FRONT_LINE or math.abs(z) > streetHalf + Config.YARD_DEPTH then
		return false
	end
	for col = 0, Config.PLOTS_PER_ROW - 1 do
		if math.abs(x - Config.plotColumnX(col)) <= Config.PLOT_HALF_WIDTH then
			return true
		end
	end
	return false
end
H.addGroundVeto(function(p) return inYard(p.X, p.Z) end)

local g = Config.herdGround()
check(g.bandNear > streetHalf + Config.YARD_DEPTH, "the band starts behind the back fences")
check(g.bandFar < Config.GROUND_SIZE.Y / 2 and g.corridorOuter < Config.GROUND_SIZE.X / 2, "and stays on the slab")
check(g.corridorInner > Config.plotColumnX(Config.PLOTS_PER_ROW - 1) + Config.PLOT_HALF_WIDTH,
	"the end corridor is clear of the last yard's side fence")
check(g.corridorOuter < g.tunnelX, "and clear of the tunnel's earth bank")

-- THE BAND RECTANGLE IS ITS OWN TEST NOW, because a drop places ten slots at
-- once and `groundAllows` knows nothing about the band's edges: the slab runs
-- 45 studs past `bandFar`, and the valley wall stands its foreground columns
-- in to |z| 258, so "allowed ground" a few studs out of the band is rock.
check(H.inBand(vec(0, 0, (g.bandNear + g.bandFar) / 2)), "the middle of the band is in the band")
check(not H.inBand(vec(0, 0, g.bandFar + 1)), "a stud past bandFar is not")
check(not H.inBand(vec(0, 0, g.bandNear - 1)), "nor a stud inside bandNear")
check(not H.inBand(vec(g.corridorX + 1, 0, (g.bandNear + g.bandFar) / 2)), "nor past the corridor line on X")
check(g.bandFar + HERDS.edgeMargin <= Config.GROUND_SIZE.Y / 2,
	"and the band's own edge is the slab's less the edge margin")
-- The wander band itself, sampled on a grid.
for xi = -10, 10 do
	for zi = 0, 6 do
		local x = xi / 10 * g.corridorX
		local z = g.bandNear + zi / 6 * (g.bandFar - g.bandNear)
		for _, side in ipairs({ -1, 1 }) do
			local p = vec(x, 0, side * z)
			check(H.groundAllows(p), ("a band point is allowed: (%.0f, %.0f)"):format(x, side * z))
			check(not inYard(x, side * z) and not Config.isOnStreet(p), "and is neither yard nor street")
		end
	end
end
check(not H.groundAllows(vec(0, 0, 0)), "the road centre is refused")
check(not H.groundAllows(vec(Config.plotColumnX(0), 0, streetHalf)), "a plot centre is refused by the yard veto")

-- ---- THE DROP ---------------------------------------------------------------
-- The half the designer asked for and the half a suite can hold: a pack is
-- built OVER a landing zone every slot of which is legal, it is in the air
-- until the last member is down and settled, and nothing is catchable until
-- it lands.
do
	H.clear()
	online = { player("watcher-a"), player("watcher-b") }
	notices = {}
	local beaconsBefore = env.beaconsBuilt
	H._setNext(now)
	local herd = assert(H.spawn("stray"))
	check(herd.state == "drop", "a herd is born falling")
	check(#herd.members == 10, "ten of them")
	-- CAPTURED AT THE DROP, because the announcement names where the pack
	-- LANDED and the pack has wandered off it by the time the fall loop below
	-- has finished.
	local zoneAtDrop = H.zoneWords(herd.at)

	-- 1. THE ZONE. Every member's own slot, not the centre.
	for i, m in ipairs(herd.members) do
		check(H.inBand(m.at), ("member %d lands inside the band: (%.0f, %.0f)"):format(i, m.at.X, m.at.Z))
		check(H.groundAllows(m.at), ("member %d lands on allowed ground"):format(i))
		check(not inYard(m.at.X, m.at.Z), ("member %d lands outside every yard"):format(i))
		check(not Config.isOnStreet(m.at), ("member %d lands off the street"):format(i))
	end
	check(H.dropFits(herd.at, herd.facing, #herd.members), "and dropFits agrees about the zone it picked")
	-- The pack faces the houses, so the formation stacks AWAY from the back
	-- fences: the leader is the member nearest the street.
	for i = 2, #herd.members do
		check(math.abs(herd.members[i].at.Z) >= math.abs(herd.members[1].at.Z) - 1e-6,
			"the leader is the member nearest the street")
	end

	-- 2. THE FALL. Every member starts at the full height, none is catchable,
	-- and the height only ever comes down.
	for _, m in ipairs(herd.members) do
		check(math.abs(m.fall - DROP.height) < 1e-6, "every member starts at the drop height")
		check(m.landed == false, "and none has landed")
		check(m.prompt.Enabled == false, "so none can be caught")
	end
	local lastFall = DROP.height + 1
	local airborneFrames, landedAt = 0, {}
	local steps = 0
	while herd.state == "drop" and steps < 2000 do
		H._step(herd, 0.05, now)
		now += 0.05
		steps += 1
		airborneFrames += 1
		-- Monotone until it touches down; the settle hop after that is the
		-- one time a member's height goes back up on purpose.
		local leader = herd.members[1]
		if not leader.landed then
			check(leader.fall <= lastFall + 1e-6, "the leader's height never goes back up on the way down")
			lastFall = leader.fall
		end
		for i, m in ipairs(herd.members) do
			if m.landed and not landedAt[i] then
				landedAt[i] = now
				check(m.prompt.Enabled == true, ("member %d is catchable the moment it lands"):format(i))
			end
			-- Asked only while the pack is still falling: the frame it lands
			-- is the frame it starts walking, and that frame is inside this
			-- loop because the state flips before the member loop runs.
			if herd.state == "drop" then
				check(m.walked == 0, "nothing publishes a walk while it is in the air")
			end
		end
	end
	check(herd.state == "roam", "the drop ends in the band, roaming")
	check(steps * 0.05 >= DROP.seconds, ("the fall took its full %.1fs"):format(DROP.seconds))
	for i, m in ipairs(herd.members) do
		check(m.landed and landedAt[i] ~= nil, ("member %d landed"):format(i))
		check(m.fall == 0, ("and member %d is standing on the grass"):format(i))
		check(m.prompt.Enabled == true, ("and member %d can be caught"):format(i))
	end
	-- STAGGERED, so ten do not arrive on one frame.
	local first, last = math.huge, 0
	for _, t in pairs(landedAt) do
		first, last = math.min(first, t), math.max(last, t)
	end
	check(last - first > 0, ("the pack lands over %.2fs rather than on one frame"):format(last - first))
	check(last - first <= DROP.stagger + 0.1, "and inside drop.stagger")

	-- 3. THE ANNOUNCEMENT, to everybody, naming the batch and the place.
	local told = {}
	for _, n in ipairs(notices) do
		if n.msg:find("OBSERVER", 1, true) then
			told[n.player] = n
		end
	end
	for _, p in ipairs(online) do
		local n = told[p]
		check(n ~= nil, "every player on the street is told about the drop")
		check(n.msg == ("OBSERVER: Batch %d released. Landing zone: %s."):format(herd.id, zoneAtDrop),
			"and the message names the batch and the landing zone: " .. tostring(n and n.msg))
		check(n.kind == (if (Config.NOTIFY).herd then "herd" else "good"),
			"on the observer's own notify kind, or `good` until that row lands")
	end

	-- 4. THE MARKER. One per drop, and it goes on its own clock.
	check(env.beaconsBuilt == beaconsBefore + 1, "one beacon per drop")
	check(herd.beacon ~= nil, "and it is standing while the pack is still arriving")
	check(herd.beaconUntil > now, "with its fade still ahead of it")
	local destroyedBefore = env.beaconsDestroyed
	while herd.beacon and now < herd.beaconUntil + 1 do
		H._step(herd, 0.1, now)
		now += 0.1
	end
	check(herd.beacon == nil, ("the beacon is taken down on its own %.0fs clock"):format(DROP.beaconSeconds))
	check(env.beaconsDestroyed == destroyedBefore + 1, "and destroyed exactly once")
	check(env.lastFade > 0, "having faded rather than blinked out")
	H.clear()
	online = {}
end

-- ---- THE STATE MACHINE, STEPPED OFFLINE ------------------------------------
-- Not the movement -- the picture of a pack is live-only -- but its SHAPE:
-- dropped into the band, roams it, recalled into the sky, gone.
do
	H._setNext(now)
	local herd = assert(H.spawn("stray"))
	check(herd.state == "drop", "a herd is born falling")
	local steps = 0
	while herd.state == "drop" and steps < 20000 do
		H._step(herd, 0.1, now)
		now += 0.1
		steps += 1
	end
	check(herd.state == "roam", "the drop ends in the band, roaming")
	check(not Config.isOnStreet(herd.at) and not inYard(herd.at.X, herd.at.Z), "the leader arrives off the street and outside every yard")
	local roamed, targets = 0, 0
	while herd.state == "roam" and roamed < 200000 do
		H._step(herd, 0.1, now)
		now += 0.1
		roamed += 1
		if herd.target then
			targets += 1
			check(H.groundAllows(herd.target), "every wander target is allowed ground")
		end
		check(not inYard(herd.at.X, herd.at.Z), "the leader never walks through a yard while roaming")
		-- The bound is the deepest slot plus drift, plus what a member that
		-- stopped to DIG falls behind before the catch-up starts: the pack
		-- walks `dig.seconds` at herd speed while the digger stands still.
		local digLag = HERDS.dig.seconds * Config.herdSpeed()
		for i, m in ipairs(herd.members) do
			local d = (m.at - herd.at).Magnitude
			check(d <= (HERDS.followSpacing * 3 + HERDS.jitter * 2 + 4 + digLag), ("member %d stays with the pack: %.1f studs"):format(i, d))
		end
	end
	check(herd.state == "recall", "roam time up: the pack is called back up")
	check(targets > 0, "it actually wandered somewhere while roaming")
	-- THE RECALL IS THE DROP WITH THE SIGN FLIPPED: prompts off at once, the
	-- pack rises off the grass, and it is gone at the top.
	for i, m in ipairs(herd.members) do
		check(m.prompt.Enabled == false, ("member %d stops being catchable the frame it is recalled"):format(i))
	end
	-- And refused on the trigger too, which is the half a disabled prompt
	-- cannot cover: `landed` is TRUE of a rising pack, so the guard has to
	-- ask the herd's state as well as the member's.
	do
		local late = player("too-late")
		notices = {}
		check(not H.claim(herd, herd.members[1], late), "a recalled member cannot be claimed either")
		local said = false
		for _, n in ipairs(notices) do
			if n.msg:find("not on the ground", 1, true) then said = true end
		end
		check(said, "and the refusal says so")
	end
	local rose, top = 0, 0
	local left = 0
	while H.count() > 0 and left < 20000 do
		H._step(herd, 0.1, now)
		now += 0.1
		left += 1
		for _, m in ipairs(herd.members) do
			top = math.max(top, m.fall)
			if m.fall > 0 then rose += 1 end
		end
	end
	check(rose > 0, "the pack leaves the ground on the way out")
	check(top > DROP.height * 0.8, ("and reaches the drop height on the way up: %.0f"):format(top))
	check(H.count() == 0, "the recall ends with the herd gone")
	check(H.inBand(herd.at), "and it left from where it was standing rather than walking anywhere first")
end

-- ---- THE WALK'S ONE PUBLISH ---------------------------------------------
-- `Shared/PiggyWalk` poses a member from the studs it has walked, which this
-- service publishes as `Config.HERD_WALK_ATTRIBUTE`. Pinned here rather than
-- in the walk suite because it needs the stepped herd: the attribute goes out
-- only on a frame the member moved, only ever grows, and is the ground it
-- actually covered -- a phase built on anything else would desync from the
-- motion it depicts, which is the officer's rule.
do
	H._setNext(now)
	local herd = assert(H.spawn("stray"))
	-- ON THE GROUND FIRST: the publish is about ground covered, and a pack
	-- in the air covers none -- which is itself asserted in the drop block.
	while herd.state == "drop" do
		H._step(herd, 0.1, now)
		now += 0.1
	end
	local published = {}
	for i, m in ipairs(herd.members) do
		published[i] = {}
		m.model.SetAttribute = function(_, name, value)
			-- Two attributes go out on a member and this block is about one
			-- of them: a dig can fire inside the window now that the pack
			-- spends its first seconds falling, and a stamp is not a stride.
			check(name == Config.HERD_WALK_ATTRIBUTE or name == Config.HERD_DIG_ATTRIBUTE,
				"a member publishes only the walk and the dig, under their Config names")
			if name == Config.HERD_WALK_ATTRIBUTE then
				table.insert(published[i], value)
			end
		end
	end
	-- BASELINED, because the frame the pack lands is a frame it walks: the
	-- state flips before the member loop runs, so `walked` is already off
	-- zero by the time the publish is being watched.
	local covered, base = {}, {}
	for i, m in ipairs(herd.members) do covered[i], base[i] = 0, m.walked end
	for _ = 1, 100 do
		local was = {}
		for i, m in ipairs(herd.members) do was[i] = m.at end
		H._step(herd, 0.1, now)
		now += 0.1
		for i, m in ipairs(herd.members) do
			covered[i] += (m.at - was[i]).Magnitude
		end
	end
	for i, m in ipairs(herd.members) do
		local seq = published[i]
		check(#seq > 0, ("member %d published its distance while walking"):format(i))
		for k = 2, #seq do
			check(seq[k] >= seq[k - 1], "the published distance only grows")
		end
		check(math.abs((seq[#seq] - base[i]) - covered[i]) < 1e-3, ("and it is the ground member %d covered: %.3f vs %.3f"):format(i, seq[#seq] - base[i], covered[i]))
		check(m.walked == seq[#seq], "member.walked is exactly what was last published")
	end
	local n = #published[1]
	H._step(herd, 0, now)
	check(#published[1] == n, "a frame with no movement publishes nothing")
	H.clear()
	check(H.count() == 0, "and the walk test leaves no herd loose")
end

-- ---- THE PATH IS SAMPLED, NOT ONLY THE ENDPOINT -----------------------------
-- A ground veto registered mid-band -- the decoration lane's ponds -- has to
-- stop a pack WALKING THROUGH it, not only standing in it. The pond is a
-- disc in the +Z band; a target behind it is legal ground and is refused
-- because the line to it is not; the same target reached from the side is
-- accepted; and a roaming leader never sets foot in it.
do
	local pond = { x = 40, z = (g.bandNear + g.bandFar) / 2, r = 10 }
	local pondOn = true
	local function inPond(p)
		local dx, dz = p.X - pond.x, p.Z - pond.z
		return pondOn and dx * dx + dz * dz <= pond.r * pond.r
	end
	H.addGroundVeto(inPond)
	local y = g.groundY + 1.15
	local from = vec(pond.x - 40, y, pond.z)
	local behind = vec(pond.x + 40, y, pond.z)
	check(H.groundAllows(behind), "the point behind the pond is legal ground on its own")
	check(not H.pathClear(from, behind), "but the straight walk to it crosses the pond, so it is refused")
	check(H.pathClear(from, vec(pond.x - 40, y, pond.z + 40)), "a target with a clear line is accepted")
	check(not H.pathClear(from, vec(pond.x, y, pond.z)), "a target inside the pond is refused")
	-- The FLANKS are sampled too: a line that misses the pond by less than
	-- a column's width would drag the outside column through the water.
	local graze = vec(pond.x + 40, y, pond.z + pond.r + HERDS.followSpacing * 0.5)
	check(H.groundAllows(graze) and not H.pathClear(vec(pond.x - 40, y, graze.Z), graze),
		"a line skirting the pond inside one column is refused for the flank")
	local wide = vec(pond.x + 40, y, pond.z + pond.r + HERDS.followSpacing + 1.5)
	check(H.pathClear(vec(pond.x - 40, y, wide.Z), wide), "and one that clears the pond by a column is accepted")
	-- A veto as thick as one sample cannot fall between two samples.
	local wallOn = true
	local wall = { x = pond.x - 100 + 37.3, half = HERDS.pathSample / 2, z = pond.z - 50 }
	H.addGroundVeto(function(p) return wallOn and math.abs(p.X - wall.x) <= wall.half and math.abs(p.Z - wall.z) < 30 end)
	check(not H.pathClear(vec(pond.x - 100, y, wall.z), vec(pond.x, y, wall.z)),
		"a veto one pathSample thick across the line is always sampled")
	wallOn = false

	-- A roaming leader never walks into the pond: steer a pack onto the +Z
	-- band (the side picker seats the second pack on the other side from
	-- the first) and step it through its whole roam.
	H.clear()
	H._setNext(now)
	local herd = assert(H.spawn("stray"))
	if herd.side ~= 1 then
		local other = assert(H.spawn("stray"))
		H.despawn(herd)
		herd = other
	end
	check(herd.side == 1, "the pack roams the band the pond is in")
	local steps = 0
	while herd.state ~= "recall" and steps < 200000 do
		H._step(herd, 0.1, now)
		now += 0.1
		steps += 1
		if herd.state == "roam" then
			check(not inPond(herd.at), ("the leader never walks through the pond: (%.0f, %.0f)"):format(herd.at.X, herd.at.Z))
		end
	end
	check(herd.state == "recall", "and the pack still finished its roam with a pond in the band")
	H.clear()
	pondOn = false
end

-- ---- DIGGING ----------------------------------------------------------------
-- The server's half of the dig (Shared/PiggyDig plays the other): a member's
-- clock fires, the start goes out as `Config.HERD_DIG_ATTRIBUTE` in SERVER
-- time, the member stands still with its `Walked` frozen for `dig.seconds`,
-- and the attribute clears to nil. Never in the air -- the drop or the recall
-- -- never on a taken member, never the leader mid-walk, and never the whole
-- pack at once.
do
	local DIG, WALK = Config.HERD_DIG_ATTRIBUTE, Config.HERD_WALK_ATTRIBUTE
	local D = HERDS.dig
	H._setNext(now)
	local herd = assert(H.spawn("stray"))
	local function stamp(m) return m.model:GetAttribute(DIG) end

	-- 1. THE DROP. Nobody digs in mid-air, and a clock that comes due while
	-- the pack is falling is REDRAWN rather than held -- held, every clock
	-- that ripened during the fall would fire on the first roaming frame and
	-- the whole pack would dig in step. The clocks are FORCED due here rather
	-- than waited for: a fall is a few seconds against an `every.min` of 12,
	-- so waiting would assert nothing and would silently stop asserting it
	-- the day either number moved -- which is exactly how the leg version of
	-- this check went stale.
	local redrawn = 0
	check(H.mayDig(herd) == false, "no herd may dig while it is being dropped in")
	for _, m in ipairs(herd.members) do
		m.nextDigAt = now - 1
	end
	H._step(herd, 0.1, now)
	now += 0.1
	for _, m in ipairs(herd.members) do
		check(stamp(m) == nil and m.digUntil == 0, "nobody digs on the way down")
		check(m.nextDigAt >= now + D.every.min - 0.2, "and a due clock is redrawn every.min or more ahead")
		redrawn += 1
	end
	check(redrawn == #herd.members, "every member's clock was redrawn rather than fired")
	local steps = 0
	while herd.state == "drop" and steps < 20000 do
		H._step(herd, 0.1, now)
		now += 0.1
		steps += 1
		for _, m in ipairs(herd.members) do
			check(stamp(m) == nil and m.digUntil == 0, "nobody digs on the way down")
		end
	end
	check(herd.state == "roam", "into the band")
	check(H.mayDig(herd) == true, "and a pack on the grass may dig")

	-- 2. IN THE BAND: digs happen, and each one is the contract.
	local frozen = {}
	local digs, leaderDigs = 0, 0
	local startFrames = {}
	local roamed = 0
	while herd.state == "roam" and roamed < 6000 and digs < 40 do
		H._step(herd, 0.1, now)
		for i, m in ipairs(herd.members) do
			local s = stamp(m)
			local f = frozen[m]
			if s ~= nil and not f then
				digs += 1
				check(s == now + SERVER_OFFSET, ("the stamp is SERVER time, written the frame the dig began: %.1f"):format(s))
				check(math.abs(m.digUntil - (now + D.seconds)) < 1e-6, "digUntil is now + dig.seconds")
				startFrames[now] = (startFrames[now] or 0) + 1
				frozen[m] = { at = m.at, walked = m.model:GetAttribute(WALK), stamp = s, since = now }
				if i == 1 then
					leaderDigs += 1
					check(herd.target == nil, "the leader digs only while grazing with no target")
				end
			elseif s ~= nil and f then
				check(s == f.stamp, "the stamp does not change mid-dig")
				check(m.at.X == f.at.X and m.at.Z == f.at.Z, "a digging member does not move")
				check(m.model:GetAttribute(WALK) == f.walked, "and its Walked does not advance")
				check(now - f.since <= D.seconds + 0.11, "a dig does not outlast dig.seconds")
				if i == 1 then
					check(herd.target == nil, "the pack does not walk off while its leader digs")
				end
			elseif s == nil and f then
				check(now - f.since >= D.seconds - 1e-3, ("a dig lasts the full dig.seconds: %.2f"):format(now - f.since))
				check(m.digUntil == 0, "digUntil is cleared with the attribute")
				check(m.nextDigAt >= now + D.every.min, "and the next dig is at least every.min away")
				frozen[m] = nil
			end
		end
		now += 0.1
		roamed += 1
	end
	check(digs >= 10, ("digs happened in the band: %d"):format(digs))
	local distinct, biggest = 0, 0
	for _, n in pairs(startFrames) do
		distinct += 1
		biggest = math.max(biggest, n)
	end
	-- NOT IN LOCKSTEP, and the bound is a SHARE OF THE PACK rather than the
	-- flat two it was. That two was written when the pack walked a
	-- thirty-second enter leg on which every clock came due and was redrawn,
	-- which re-randomised them against a moving `now`; a dropped pack lands
	-- in three seconds carrying the clocks it was rolled with, which are a
	-- uniform spread over `every` and therefore collide on a frame about as
	-- often as birthdays do. A third of ten starting together is still a
	-- pack digging at its own pace; five would not be.
	local lockstep = math.max(2, math.ceil(#herd.members / 3))
	check(biggest <= lockstep,
		("no frame started more than %d digs -- not in lockstep: %d"):format(lockstep, biggest))
	check(distinct >= digs * 0.75, "dig starts are spread across frames")
	-- A dig is only on the model while the member is digging: sweep.
	for _, m in ipairs(herd.members) do
		check((stamp(m) ~= nil) == (m.digUntil > 0), "the attribute and digUntil agree")
	end

	-- 3. THE CATCH-UP: a member that dug comes back to the pack.
	local straggler = nil
	for _, m in ipairs(herd.members) do
		if m.digUntil > 0 then straggler = m end
	end
	if straggler and herd.state == "roam" then
		local before = straggler.walked
		for _ = 1, 150 do
			if herd.state ~= "roam" then break end
			H._step(herd, 0.1, now)
			now += 0.1
		end
		check(straggler.walked > before, "a member that dug walks again afterwards")
	end

	-- 4. A TAKEN MEMBER NEVER STARTS A DIG.
	if herd.state == "roam" then
		local m = herd.members[2]
		local wasNext = m.nextDigAt
		if m.digUntil > 0 then
			-- let the dig in progress end first
			while m.digUntil > 0 do H._step(herd, 0.1, now); now += 0.1 end
		end
		m.taken = true
		m.nextDigAt = now - 1
		H._step(herd, 0.1, now)
		now += 0.1
		check(stamp(m) == nil and m.digUntil == 0, "a taken member does not start a dig")
		check(m.nextDigAt == now - 1.1 or m.nextDigAt < now, "and its clock is left due rather than redrawn")
		m.taken = false
		H._step(herd, 0.1, now)
		check(stamp(m) ~= nil, "the same clock fires the frame the member is no longer taken")
		now += 0.1
		local _ = wasNext
	end

	-- 5. THE RECALL ENDS A DIG AT ONCE, AND NOBODY DIGS ON THE WAY UP. This
	-- is the one that would fail silently: a member caught mid-dig by the
	-- recall keeps its stamp forever, and a stamp with no dig under it is a
	-- piggy nose-down in the air on every client.
	check(herd.state == "roam", "still roaming for the recall check")
	local m3 = herd.members[3]
	while m3.digUntil > 0 do H._step(herd, 0.1, now); now += 0.1 end
	m3.nextDigAt = now
	H._step(herd, 0.1, now)
	now += 0.1
	check(stamp(m3) ~= nil and m3.digUntil > now, "a dig is in progress")
	herd.roamUntil = now
	H._step(herd, 0.1, now)
	now += 0.1
	check(herd.state == "recall", "roam time up: the pack is called back up")
	check(H.mayDig(herd) == false, "and no herd may dig while it is being recalled")
	H._step(herd, 0.1, now)
	now += 0.1
	check(stamp(m3) == nil and m3.digUntil == 0, "the dig ends as the pack leaves the ground")
	local left = 0
	while H.count() > 0 and left < 20000 do
		H._step(herd, 0.1, now)
		now += 0.1
		left += 1
		for _, m in ipairs(herd.members) do
			-- At the top the models are destroyed with the herd.
			if m.model then
				check(stamp(m) == nil and m.digUntil == 0, "nobody digs on the way up")
			end
		end
	end
	check(H.count() == 0, "and the pack is gone")
	check(leaderDigs >= 0, "leader digs are counted")
end

-- ---- THE SIZE PARITY --------------------------------------------------------
-- A HERD PIGGY IS THE SAME SIZE AS THE SAME SKIN ON A PEDESTAL (designer,
-- 2026-09-22). It was `Config.piggyScale` alone, which is the SKIN'S share of
-- the size rather than the size, so a pack member stood a third of plinth
-- size and fifteen of the nineteen animal skins were unrecognisable in the
-- grass. The assertion is the EXPRESSION rather than a number, because the
-- thing that must hold is that the two readers cannot drift.
do
	local sampled = 0
	for rank = 1, Config.rarityRank(HERDS.tierCap) do
		for _, key in ipairs(Config.herdSkinPool(Config.RARITY_ORDER[rank])) do
			local want = Config.PIGGY_PEDESTAL.display * Config.piggyScale(key)
			check(H.memberFactor(key) == want,
				("%s stands at the pedestal's own factor: %.4f"):format(key, want))
			sampled += 1
		end
	end
	check(sampled >= 20, ("every herd-eligible skin was checked: %d"):format(sampled))
	-- The two ends of the band, so a bee and a tiger are both the pedestal's
	-- size for their own skin rather than both the pedestal's size.
	local small, big = math.huge, 0
	for _, key in ipairs(Config.herdSkinPool("common")) do
		small = math.min(small, H.memberFactor(key))
		big = math.max(big, H.memberFactor(key))
	end
	check(big > small, "the skin's own scale still varies the member")
	check(small >= Config.PIGGY_PEDESTAL.display * Config.PIGGY_SCALE.min - 1e-9
		and big <= Config.PIGGY_PEDESTAL.display * Config.PIGGY_SCALE.max + 1e-9,
		"and every member sits inside the clamped band times the display factor")
	-- The lift is the same derivation the pedestal makes, so a member's feet
	-- are on the grass rather than a stud into it or a stud over it.
	local key = Config.herdSkinPool("common")[1]
	check(math.abs((1.15 * (H.memberFactor(key) - 1)) - (1.15 * H.memberFactor(key) - 1.15)) < 1e-9,
		"the lift is MINI_CENTRE_Y times (factor - 1), which is the pedestal's own seat less the ground offset")
end

-- ---- WHERE A DROP IS, IN WORDS ----------------------------------------------
-- The announcement has to name a place a nine-year-old can walk to, and the
-- only things this leaf may read to do it are the plot constants.
do
	local g2 = Config.herdGround()
	local mid = (g2.bandNear + g2.bandFar) / 2
	for col = 0, Config.PLOTS_PER_ROW - 1 do
		local x = Config.plotColumnX(col)
		check(H.plotBehind(vec(x, 0, -mid)) == col + 1,
			("the near row is plots 1..%d, west to east"):format(Config.PLOTS_PER_ROW))
		check(H.plotBehind(vec(x, 0, mid)) == Config.PLOTS_PER_ROW + col + 1,
			"and the far row is the ones after them")
		check(H.zoneWords(vec(x, 0, mid)) == ("the field behind Plot %d"):format(Config.PLOTS_PER_ROW + col + 1),
			"a point behind a column is named by that plot")
	end
	-- Past the last column there is no plot to be behind, so the END is
	-- named instead of a plot forty studs to one side of the drop.
	local past = Config.plotColumnX(Config.PLOTS_PER_ROW - 1) + Config.PLOT_HALF_WIDTH + 20
	check(H.zoneWords(vec(past, 0, mid)):find("east end", 1, true) ~= nil,
		"a drop past the last column is named by the end of the field: " .. H.zoneWords(vec(past, 0, mid)))
	check(H.zoneWords(vec(-past, 0, mid)):find("west end", 1, true) ~= nil,
		"and the other end is the other word")
	check(H.zoneWords(vec(past, 0, mid)):find("past Plot", 1, true) ~= nil,
		"with the nearest plot still on it, so it is still somewhere rather than a direction")
end

-- ---- THE PACK STILL FITS THE BAND AT THE FULL-SIZE SPACING -------------------
-- The spacing has to grow by the display factor or ten pedestal-sized
-- piggies stand inside each other -- and a formation three spacings deep is
-- 34.4 studs at the derived 11.45 against a band 97 deep. Held HERE rather
-- than only in the Config block, and driven at the DERIVED value whether or
-- not that block has landed, so the arithmetic in the report is the
-- arithmetic that ran.
do
	H.clear()
	local was, wasJ = HERDS.followSpacing, HERDS.jitter
	HERDS.followSpacing = 3.5 * Config.PIGGY_PEDESTAL.display
	HERDS.jitter = 1.2 * Config.PIGGY_PEDESTAL.display
	local g3 = Config.herdGround()
	local depth = 3 * HERDS.followSpacing
	check(depth < g3.bandFar - g3.bandNear,
		("a pack of ten is %.1f studs deep in a band %.1f deep"):format(depth, g3.bandFar - g3.bandNear))
	-- And the draw actually finds room: twenty packs in a row, every slot of
	-- every one of them in the band and on allowed ground.
	local fitted = 0
	for _ = 1, 20 do
		H._setNext(now)
		local herd = H.spawn("stray")
		if herd then
			fitted += 1
			for i, m in ipairs(herd.members) do
				check(H.inBand(m.at), ("full-size member %d is in the band"):format(i))
				check(H.groundAllows(m.at), ("full-size member %d is on allowed ground"):format(i))
			end
			H.despawn(herd)
		end
	end
	check(fitted == 20, ("twenty full-size packs all found a landing zone: %d"):format(fitted))
	HERDS.followSpacing, HERDS.jitter = was, wasJ
	H.clear()
end

-- ---- A BAND WITH NO ROOM IN IT REFUSES, OUT LOUD -----------------------------
-- `dropFits` tests every slot, so a band that is entirely vetoed cannot
-- produce a pack landing in it -- and `spawn` says so rather than dropping
-- one anywhere legal-ish, which is the silent failure this file refuses.
do
	H.clear()
	local blockOn = true
	H.addGroundVeto(function() return blockOn end)
	H._setNext(now)
	local herd, why = H.spawn("stray")
	check(herd == nil and type(why) == "string" and why:find("landing zone", 1, true) ~= nil,
		"a band with nowhere to land refuses out loud: " .. tostring(why))
	check(H.count() == 0, "and nothing was built")
	blockOn = false
	check(H.spawn("stray") ~= nil, "and it spawns again the moment there is room")
	H.clear()
end

check(#warnings == 0, "nothing warned: " .. table.concat(warnings, "; "))
print(("herds: %d checks passed"):format(checks))
if #pending > 0 then
	print(("herds: %d assertion(s) AWAITING the Config.HERDS block:"):format(#pending))
	for _, msg in ipairs(pending) do
		print("  - " .. msg)
	end
end
