-- THE COMBINE MACHINE, MEASURED WITHOUT AN ENGINE.
--
-- Everything asserted here is either arithmetic over `Config` or a claim
-- about the SOURCE of a file that has to keep a rule. Nothing is built: the
-- station's placement, its box list, its clearances and every refusal its
-- panel can print are pure functions for exactly this reason -- the harness
-- has no workspace, no plots and no ProximityPrompt, and a probe that needed
-- one could not run at all.
--
-- WHAT THIS DOES NOT CHECK. No pixel was looked at, no prompt was held and
-- the model has never been built, so the reveal, the hold and the panel's
-- layout are unverified here and are recorded as such.
local Config, sources = ...
local checks = 0
local function check(ok, message)
	checks += 1
	assert(ok, message)
end
local function near(a, b, tol, message)
	check(math.abs(a - b) <= (tol or 1e-6), ("%s (%.4f vs %.4f)"):format(message, a, b))
end

-- ============================================================
-- LOADING THE TWO MODULES THAT HAVE A PURE HALF
-- ============================================================

-- A `Color3` STUB THAT CARRIES ITS CHANNELS, so the panel's own grounds can
-- be MEASURED rather than described. `Theme` requires nothing, so it loads
-- here for real -- and every label in the panel is ink or muted on one of
-- four grounds, which is exactly the check no screenshot of this can make
-- and no other suite covers.
local function fromHSV(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	local r, g, b
	local k = i % 6
	if k == 0 then r, g, b = v, t, p
	elseif k == 1 then r, g, b = q, v, p
	elseif k == 2 then r, g, b = p, v, t
	elseif k == 3 then r, g, b = p, q, v
	elseif k == 4 then r, g, b = t, p, v
	else r, g, b = v, p, q end
	return r, g, b
end
local rgb
-- `Theme.readable` walks a tone through HSV, so the stub does the real
-- conversion rather than handing back the tone unchanged. A stub that lied
-- here would make every contrast check below measure the wrong colour.
local function rgb01(r, g, b)
	local c
	c = { R = r, G = g, B = b }
	function c.ToHSV()
		local mx, mn = math.max(r, g, b), math.min(r, g, b)
		local v = mx
		local s = if mx == 0 then 0 else (mx - mn) / mx
		local h = 0
		if mx ~= mn then
			if mx == r then h = ((g - b) / (mx - mn)) % 6
			elseif mx == g then h = (b - r) / (mx - mn) + 2
			else h = (r - g) / (mx - mn) + 4 end
			h /= 6
		end
		return h, s, v
	end
	function c.Lerp(_, other, t)
		if type(other) ~= "table" or other.R == nil then
			return c
		end
		return rgb01(r + (other.R - r) * t, g + (other.G - g) * t, b + (other.B - b) * t)
	end
	return c
end
function rgb(r, g, b)
	local c = rgb01((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
	function c.Lerp(_, other, t)
		if type(other) ~= "table" or other.R == nil then
			return c
		end
		return rgb((c.R + (other.R - c.R) * t) * 255,
			(c.G + (other.G - c.G) * t) * 255,
			(c.B + (other.B - c.B) * t) * 255)
	end
	return c
end
local colour = setmetatable({}, { __index = function() return function() return nil end end })
local function vec(x, y, z) return { X = x or 0, Y = y or 0, Z = z or 0 } end
local instances = {}
local function instance(class)
	local o = { ClassName = class, Name = "", _attributes = {} }
	function o:SetAttribute(key, value) self._attributes[key] = value end
	function o:GetAttribute(key) return self._attributes[key] end
	function o:FindFirstChildOfClass() return nil end
	function o:IsA(c) return c == self.ClassName end
	table.insert(instances, o)
	return o
end

-- `Remotes` IS PRE-SEEDED RATHER THAN LOADED, and its source is still read
-- below. That module decides at load time whether it is the server (and
-- creates the folder) or the client (and `WaitForChild`s it), and neither
-- exists here -- so the real one is a channel list rather than anything with
-- logic in it, and a stub that records what was fired is more useful than a
-- folder full of nothing.
local fired = {}
local loaded = {
	Config = Config,
	Remotes = {
		get = function(name)
			return {
				FireServer = function(_, ...) table.insert(fired, { name = name, ... }) end,
				FireClient = function(_, ...) table.insert(fired, { name = name, ... }) end,
				OnClientEvent = { Connect = function() return { Disconnect = function() end } end },
				OnServerEvent = { Connect = function() return { Disconnect = function() end } end },
			}
		end,
	},
}
local env
local shared = setmetatable({}, { __index = function(_, mod) return { __module = mod } end })
local warnings = {}
local function req(token)
	local name = type(token) == "table" and token.__module or tostring(token)
	if loaded[name] then
		return loaded[name]
	end
	if sources[name] then
		local run = assert(loadstring(sources[name], name))
		setfenv(run, env)
		loaded[name] = run()
	else
		loaded[name] = setmetatable({}, { __index = function() return function() return nil end end })
	end
	return loaded[name]
end
env = setmetatable({
	Color3 = {
		fromRGB = rgb,
		new = function(r, g, b) return rgb01(r or 0, g or 0, b or 0) end,
		fromHSV = function(h, s, v) return rgb01(fromHSV(h or 0, s or 0, v or 0)) end,
	},
	Vector3 = { new = vec }, Vector2 = { new = vec, zero = vec(0, 0) },
	CFrame = setmetatable({ new = function() return colour end, Angles = function() return colour end },
		{ __index = function() return function() return colour end end }),
	UDim2 = { new = function() return colour end, fromOffset = function() return colour end,
		fromScale = function() return colour end },
	UDim = { new = function() return colour end },
	Enum = setmetatable({}, { __index = function(_, group)
		return setmetatable({}, { __index = function(_, key) return group .. "." .. key end })
	end }),
	Instance = { new = instance },
	require = req,
	-- `Config` is a LOCAL of this chunk, so a lifted function body resolves
	-- it as a global and needs it here. That is what `boardX` does.
	Config = Config,
	warn = function(message) table.insert(warnings, tostring(message)) end,
	print = function() end,
	workspace = { FindFirstChild = function() return nil end },
	script = { Parent = setmetatable({}, { __index = function(_, mod) return { __module = mod } end }) },
	game = { GetService = function(_, name)
		if name == "ReplicatedStorage" then return { Shared = shared } end
		return setmetatable({}, { __index = function() return function() return nil end end })
	end },
}, { __index = getfenv() })

local Theme = req({ __module = "Theme" })
local Station = req({ __module = "CombineStation" })
local Panel = req({ __module = "CombinePanel" })

-- ============================================================
-- 1. WHERE IT STANDS
-- ============================================================

local m = Config.streetMetrics()
local at = Station.placement()
local world = Station.worldBox()

-- THE GAP ORDERING HAS TO AGREE WITH `SocialService.boardX`, and that is
-- asserted by running THAT function rather than by restating its rule.
--
-- `boardX` is a local in a file this workstream may not touch, so the
-- ordering is reproduced in `CombineStation.freeGaps` -- and a reproduction
-- nobody checks is the drift this project records more than any other. Its
-- body is lifted out of the source and run, exactly the way the shop UI
-- suite runs `Theme.floatClose`.
local boardBody = sources.SocialService:match("local function boardX%(%)(.-)\nend")
check(boardBody ~= nil, "SocialService still has a boardX to compare against")
local boardX = assert(loadstring("return function()" .. boardBody .. "\nend"))
setfenv(boardX, env)
boardX = boardX()()
local free = Station.freeGaps()
check(#free >= 1, "the row has at least one gap no shop stands in")
near(Config.shopGapX(free[1]), boardX, 1e-9,
	"the boards take the first free gap, so the station must not")
check(free[2] ~= nil, "there is a second free gap for the station to take")
near(at.x, Config.shopGapX(free[2]), 1e-9, "the station stands in the second free gap")
check(math.abs(at.x - boardX) > 1e-6, "the station is not in the boards' gap")

-- DERIVED, NOT PINNED: widening the street has to move it.
do
	local original = Config.STREET_SPACING
	local metrics = Config.streetMetrics()
	check(math.abs(at.z) == metrics.boardZ, "the station stands on the mid-verge line")
	-- `boardZ` is `(roadHalfWidth + fenceLine) / 2`, so it is a function of
	-- STREET_SPACING by construction. Asserted as the identity rather than by
	-- rebuilding the memoised metrics table, which this harness cannot clear.
	near(metrics.boardZ, (Config.ROAD_HALF_WIDTH + metrics.fenceLine) / 2, 1e-9,
		"the mid-verge line is derived from the street's own width")
	near(metrics.fenceLine, original / 2 - Config.PLOT_FRONT_LINE, 1e-9,
		"the verge's far edge is derived from the street spacing and the fence line")
end

-- EVERY CLEARANCE, and every one has to be positive with room in it.
--
-- The floors are not all the same number on purpose: a clearance of two
-- studs is what CLAUDE.md calls "not a fit, a coincidence waiting for the
-- next spacing edit", so anything the street could plausibly move gets four.
local clearances = Station.clearances()
local FLOORS = {
	carriageway = 6,   -- never in the road
	climbZone = 4,     -- the fence TRIGGER, not the fence line
	yard = 4,          -- outside every plot's own rectangle
	driveway = 6,      -- never on a drive
	lamp = 4,
	bin = 4,
	board = 20,
	shop = 20,
	herd = 20,         -- the line every pack crosses the verge on
	tree = 3,          -- against the canopy's own reach
	promptBin = 1,     -- two prompts on one key do not both work
}
for name, floor in pairs(FLOORS) do
	local gap = clearances[name]
	check(type(gap) == "number", "the station measures its clearance to the " .. name)
	check(gap >= floor,
		("the station clears the %s by %.2f studs, floor %.1f"):format(name, gap or -1, floor))
end
for name, gap in pairs(clearances) do
	check(FLOORS[name] ~= nil, "every measured clearance has a floor asserted: " .. name)
	check(gap > 0, ("the station is not inside the %s (%.2f)"):format(name, gap))
end

-- THE WHOLE MACHINE IS ON THE STREET, so a ride carries a player to it and
-- switches off inside a fence rather than out here.
for _, x in ipairs({ world.minX, world.maxX }) do
	for _, z in ipairs({ world.minZ, world.maxZ }) do
		check(Config.isOnStreet(vec(x, 0, z)),
			("the station's corner (%.1f, %.1f) is on the street"):format(x, z))
	end
end

-- AND NOT INSIDE ANY YARD. `PlotService.yardContaining` tests |local X| <=
-- PLOT_HALF_WIDTH and local Z from -YARD_DEPTH to PLOT_FRONT_LINE, which in
-- world terms is everything at |z| >= fenceLine behind a plot column. The
-- rectangle is reproduced here rather than the service loaded, because a
-- yard is two constants and loading PlotService needs a world.
for _, z in ipairs({ world.minZ, world.maxZ }) do
	check(math.abs(z) < m.fenceLine,
		("the station's z %.2f is outside every front fence (%.2f)"):format(z, m.fenceLine))
end

-- ============================================================
-- 2. THE GEOMETRY
-- ============================================================

local boxes = Station.boxes()
check(#boxes > 10, "the machine is built out of real geometry")

-- NOT ONE TEXTURED MATERIAL, and `Metal` counts. Those six are what the
-- house rebuild took off every building in the game; `Metal` is the one that
-- slips past the word "textured" because it SHADES a colour rather than
-- patterning it, which is how the trophies shipped a gold that rendered
-- olive two studs from the same gold rendered flat.
local REFUSED = { Brick = true, Slate = true, WoodPlanks = true, DiamondPlate = true,
	Grass = true, Metal = true, Cobblestone = true, Wood = true, Marble = true,
	Concrete = true, Sand = true, Fabric = true, Granite = true, Pebble = true }
for _, b in ipairs(boxes) do
	local name = tostring(b.material):match("([^%.]+)$")
	check(not REFUSED[name],
		("%s uses a flat material, not %s"):format(b.name, tostring(name)))
end

-- THE COPLANAR SWEEP: same-facing shared face planes with real overlap on
-- the OTHER TWO axes. The rule is the corrected one -- a plain "shared face
-- plane" test flags every honest butt joint in the building, which is what
-- made the shops' first sweep report 123 pairs that were mostly fine.
--
-- Balls are skipped and say why: a sphere has no flat face to share.
do
	local TOL = 1e-6
	local OVERLAP = 0.02
	local function span(b, axis)
		local s = if axis == "x" then b.sx elseif axis == "y" then b.sy else b.sz
		local c = if axis == "x" then b.x elseif axis == "y" then b.y else b.z
		return c - s / 2, c + s / 2
	end
	local function overlaps(a, c, axis)
		local alo, ahi = span(a, axis)
		local clo, chi = span(c, axis)
		return math.min(ahi, chi) - math.max(alo, clo) > OVERLAP
	end
	local AXES = { { "x", "y", "z" }, { "y", "x", "z" }, { "z", "x", "y" } }
	local found = {}
	for i = 1, #boxes do
		for j = i + 1, #boxes do
			local a, c = boxes[i], boxes[j]
			if a.shape == "box" and c.shape == "box" then
				for _, axis in ipairs(AXES) do
					local alo, ahi = span(a, axis[1])
					local clo, chi = span(c, axis[1])
					if (math.abs(alo - clo) < TOL or math.abs(ahi - chi) < TOL)
						and overlaps(a, c, axis[2]) and overlaps(a, c, axis[3])
					then
						table.insert(found, ("%s/%s on %s"):format(a.name, c.name, axis[1]))
					end
				end
			end
		end
	end
	check(#found == 0, "the machine has no coplanar pairs: " .. table.concat(found, ", "))

	-- AND THE SWEEP IS PROVED TO FIRE, because a sweep that cannot find a
	-- pair reports clean on anything. Two slabs sharing a top plane with real
	-- overlap is the exact fault a hundred of the house rebuild's 142 pairs
	-- were: a detail sized to land its foot on what it stands on.
	local flush = {
		{ name = "A", sx = 4, sy = 2, sz = 4, x = 0, y = 1, z = 0, shape = "box" },
		{ name = "B", sx = 2, sy = 1, sz = 2, x = 0, y = 1.5, z = 0, shape = "box" },
	}
	local hits = 0
	for _, axis in ipairs(AXES) do
		local alo, ahi = span(flush[1], axis[1])
		local clo, chi = span(flush[2], axis[1])
		if (math.abs(alo - clo) < TOL or math.abs(ahi - chi) < TOL)
			and overlaps(flush[1], flush[2], axis[2]) and overlaps(flush[1], flush[2], axis[3])
		then
			hits += 1
		end
	end
	check(hits == 1, "the coplanar sweep finds a flush-topped detail")
end

-- NOTHING OVERHANGS THE PLINTH, which is what makes the clearances above
-- measurements of the machine rather than of its footprint constant.
do
	local b = Station.boundsFromBoxes()
	check(b.maxX <= Station.WIDTH / 2 + 1e-9 and -b.minX <= Station.WIDTH / 2 + 1e-9,
		("nothing reaches past the plinth across (%.2f..%.2f of %.1f)"):format(
			b.minX, b.maxX, Station.WIDTH))
	check(b.maxZ <= Station.DEPTH / 2 + 1e-9 and -b.minZ <= Station.DEPTH / 2 + 1e-9,
		("nothing reaches past the plinth through (%.2f..%.2f of %.1f)"):format(
			b.minZ, b.maxZ, Station.DEPTH))
	check(b.height > 6 and b.height < 20, "the machine is street furniture rather than a tower")
end

-- ============================================================
-- 3. THE TWO VETOES ON THE VERGE
-- ============================================================

-- `occupies` has to answer for the ground the machine is on and not for the
-- ground beside it, or the grass either grows through the plinth or leaves a
-- bald patch shaped like nothing.
check(Station.occupies(at.x, at.z), "the machine's own centre is its ground")
check(not Station.occupies(at.x, -at.z), "the far shoulder is not its ground")
check(not Station.occupies(at.x, 0), "the carriageway is not its ground")
check(Station.occupies(world.maxX - 0.1, at.z), "its own corner is its ground")
check(not Station.occupies(world.maxX + 2, at.z), "two studs clear of it is not")
check(Station.occupies(world.maxX + 2, at.z, 3), "a margin widens it")

-- THE TREE VETO, DRIVEN BOTH WAYS. It must be side-aware and it must cost
-- the street NOTHING at the shipped numbers.
local REACH = 7.99
check(Station.blocksTree(at.x, at.side, REACH), "a tree on the machine is vetoed")
check(not Station.blocksTree(at.x, -at.side, REACH),
	"the same x on the FAR row is not vetoed: the machine is on one shoulder")
for _, offset in ipairs({ -21, 21 }) do
	check(not Station.blocksTree(at.x + offset, at.side, REACH),
		("the verge tree at x %+d still stands"):format(offset))
end

-- AND `NeighborhoodService` ACTUALLY ASKS. A veto nobody wires is a tree
-- through the shell and grass through the plinth, and both look exactly like
-- the geometry being wrong.
do
	local src = sources.NeighborhoodService
	check(src:find("CombineStation", 1, true) ~= nil,
		"NeighborhoodService reads the station's placement")
	check(src:find("CombineStation.blocksTree", 1, true) ~= nil,
		"the verge trees ask the station before planting")
	check(src:find("CombineStation.occupies", 1, true) ~= nil,
		"the verge grass asks the station before scattering")
	-- The side argument is back, which is what makes the tree veto honest.
	check(src:find("clear(tx, side)", 1, true) ~= nil,
		"the tree veto is told which row it is answering for")
	check(src:find("local function clear(x: number, side: number)", 1, true) ~= nil,
		"and it takes that argument")
end

-- ============================================================
-- 4. THE PROMPT
-- ============================================================

check(Station.PROMPT_KIND == "combine", "the prompt has its own kind")
check(Station.PROMPT_RANGE > 0 and Station.PROMPT_RANGE < 12,
	"the prompt's reach is a walk-up rather than a shout")
-- TWO PROMPTS ON ONE KEY DO NOT BOTH WORK, and a ProximityPrompt is
-- `OnePerButton` by default -- so `E` is only safe here because nothing
-- else's reach can touch this one's. The bin is the tight pair.
check(clearances.promptBin > 0,
	("the bin's prompt and the machine's never overlap (%.2f studs of slack)"):format(
		clearances.promptBin))
-- The plot mailbox and the doorstep crate are both 10, and both live behind
-- the fence line -- so the Z separation alone settles them.
check(m.fenceLine - math.abs(at.z) > Station.PROMPT_RANGE,
	"nothing behind a fence can be in reach of the machine's prompt")

-- AND THE CONFIG ROW IS THE ONE THING THIS CANNOT SHIP WITHOUT.
--
-- `Config.promptStyle` falls back to `collect` for a kind it does not know,
-- so a missing row is a machine wearing a gold BANK COINS card: it works and
-- it lies. `CombineStation.build` warns about it, and this is the check that
-- turns the warning into a failure once the row lands.
if (Config.PROMPTS :: any)[Station.PROMPT_KIND] then
	local row = (Config.PROMPTS :: any)[Station.PROMPT_KIND]
	check(type(row.verb) == "string" and #row.verb > 0, "the combine prompt names its verb")
	check(row.glyph ~= nil, "the combine prompt carries a glyph")
	check(row.tone ~= nil, "the combine prompt carries a tone")
	-- NOT PLAIN, AND THE CLASS IT IS NOT IN GOT SMALLER ON 2026-09-23. `plain`
	-- was "the eight prompts on a piggy or a plinth" and is now anything a
	-- player meets over and over -- the shop doors and the bins went plain the
	-- same day, so naming them here as fellow card-carriers would be a second
	-- stale list a week behind the first. This is a machine on the verge with
	-- exactly one prompt on it, in the class the post, the crate and a thief's
	-- nab are in -- and the card's verb and glyph are what say what an
	-- unfamiliar object does before anybody holds it.
	check(row.plain ~= true, "the combine prompt keeps its card")
else
	print("[combine] PENDING: Config.PROMPTS.combine is not applied yet;"
		.. " the prompt will draw the collect card until it is.")
end

-- ============================================================
-- 5. WHAT THE PANEL SAYS
-- ============================================================

-- THE ODDS PRINTED ARE THE ODDS THE SERVER ROLLS WITH, not a second copy.
do
	local rows = Station.oddsRows()
	local total = 0
	for _, row in ipairs(rows) do
		near(row.weight, Config.COMBINE.odds[row.steps], 1e-9,
			("the printed climb chance for +%d is Config's own"):format(row.steps))
		total += row.weight
	end
	check(total == 100, ("the climb chances sum to 100 (%d)"):format(total))
	check(#rows == #Config.RARITY_ORDER - 1,
		"there is a printed chance for every climb the ladder allows")
	local text = Station.oddsText()
	for _, row in ipairs(rows) do
		check(text:find(("%d%%"):format(row.weight), 1, true) ~= nil,
			("the odds line prints %d%%"):format(row.weight))
	end
end

-- TWO KINDS, AND EACH ONE NAMES THE SAVE FIELD IT EATS.
do
	check(#Station.KINDS == 2, "the machine offers piggies and guardians")
	local seen = {}
	for _, kind in ipairs(Station.KINDS) do
		check(not seen[kind.key], "kind keys are unique")
		check(not seen[kind.spareKind], "two kinds never eat one spare kind")
		seen[kind.key] = true
		seen[kind.spareKind] = true
		check(type(kind.name) == "string" and kind.name == kind.name:upper(),
			"a kind's label is a heading")
		check(type(kind.one) == "string" and #kind.one > 0,
			"a kind carries its own singular rather than a trimmed plural")
		check(kind.one:sub(-2) ~= "ie", "the singular is not a chopped plural: " .. kind.one)
	end
	check(Station.kind("piggy") ~= nil, "the piggy setting exists")
	check(Station.kind("nonsense") == nil, "an invented setting does not")
end

-- SHELVES ARE DERIVED FROM WHAT THE POOLS STOCK.
do
	local piggy = Station.shelvesFor("piggy")
	check(#piggy > 0, "the piggy setting has shelves to roll into")
	-- EVERY SHELF EITHER KIND OFFERS, AGAINST THE SERVER'S OWN TWO GATES.
	--
	-- `combine` calls `canCombineChest` and then `whyCannotOpen`, and the
	-- second refuses anything with a `cost` or a `currency` on it. A shelf
	-- this machine offers that fails either one is a button that lights and
	-- then refuses, which is the client failing to decline a known no.
	for _, kind in ipairs(Station.KINDS) do
		for _, shelf in ipairs(Station.shelvesFor(kind.key)) do
			local chest = Config.CHESTS[shelf.chest] :: any
			check(chest ~= nil, shelf.chest .. " is a real chest")
			check(Config.canCombineChest(shelf.chest),
				shelf.chest .. " is an ordinary crate, never an event set")
			check(chest.kind ~= "set", shelf.chest .. " is not a set crate")
			check(chest.set == nil, shelf.chest .. " belongs to no event set")
			check(chest.cost == nil and chest.currency == nil,
				shelf.chest .. " is not a crate `whyCannotOpen` would refuse")
			-- And it really stocks the kind it is offered for.
			local holds = false
			for _, entries in pairs(Config.chestPool(shelf.chest)) do
				for _, entry in ipairs(entries) do
					if Config.chestEntry(shelf.chest, entry) == kind.spareKind then
						holds = true
					end
				end
			end
			check(holds, ("%s really stocks %s"):format(shelf.chest, kind.name:lower()))
		end
	end
	check(Station.shelvesFor("nonsense")[1] == nil, "an invented kind has no shelves")
	-- A KIND'S SHELVES NEVER OVERLAP ANOTHER'S TODAY, which is what makes
	-- the kind toggle mean anything -- a shelf stocking both would be offered
	-- twice and roll whichever it felt like. Recorded rather than enforced:
	-- `chestPool` could legitimately hold both one day, and the tier chips
	-- would still be right.
	do
		local owner = {}
		for _, kind in ipairs(Station.KINDS) do
			for _, shelf in ipairs(Station.shelvesFor(kind.key)) do
				check(owner[shelf.chest] == nil,
					("%s is offered for one kind only (%s and %s)"):format(
						shelf.chest, tostring(owner[shelf.chest]), kind.key))
				owner[shelf.chest] = kind.key
			end
		end
	end
end

-- CLIMBABLE TIERS ARE THE ONES WITH SOMETHING ABOVE THEM ON THAT SHELF.
do
	for _, shelf in ipairs(Station.shelvesFor("piggy")) do
		local tiers = Station.tiersFor(shelf.chest)
		local pool = Config.chestPool(shelf.chest)
		local top = 0
		for rank, tier in ipairs(Config.RARITY_ORDER) do
			if pool[tier] and #pool[tier] > 0 then
				top = rank
			end
		end
		check(#tiers == math.max(0, top - 1),
			("%s offers every tier it stocks something above (%d)"):format(shelf.chest, #tiers))
		for _, tier in ipairs(tiers) do
			check(Config.rarityRank(tier) < top,
				("%s: %s has something better above it"):format(shelf.chest, tier))
		end
		check(not table.find(tiers, Config.RARITY_ORDER[top]),
			"the top stocked tier is never offered as an input")
	end
end

-- ============================================================
-- 6. THE REFUSALS, ALL OF THEM BEFORE ANYTHING IS CONSUMED
-- ============================================================

local need = Config.COMBINE.need
local shelf = Station.shelvesFor("piggy")[1].chest
local tier = Station.tiersFor(shelf)[1]

-- A state shaped exactly like the `ChestState` push: the records carry
-- kind/key/name/count/tier/value/inUse, which is what `ChestService.push`
-- sends and therefore the only shape the panel is ever handed.
local function pushed(spares)
	return { spares = spares, need = need, combineOdds = Config.COMBINE.odds }
end
local function record(kind, key, count, recordTier, value)
	return { kind = kind, key = key, name = key:upper(), count = count,
		tier = recordTier, value = value or 100, inUse = false }
end

-- NOTHING AT ALL.
check(Station.refusal(pushed({}), "piggy", shelf, tier) ~= nil,
	"an empty bag cannot combine")
check(Station.refusal(pushed({}), "piggy", shelf, tier):find(tostring(need)) ~= nil,
	"and the refusal says how many more are needed")

-- FEWER THAN `need`.
for held = 1, need - 1 do
	local state = pushed({ ["skin:one"] = record("skin", "one", held, tier) })
	local reason = Station.refusal(state, "piggy", shelf, tier)
	check(reason ~= nil, ("%d of %d spares cannot combine"):format(held, need))
	check(reason:find(tostring(need - held)) ~= nil,
		("the refusal names the %d still missing"):format(need - held))
	check(#Station.autoPick(state, "piggy", tier) == held,
		"auto pick can only offer what is held")
end

-- EXACTLY `need`, ACROSS SEVERAL ITEMS, IS ENOUGH.
do
	local state = pushed({
		["skin:one"] = record("skin", "one", 1, tier, 500),
		["skin:two"] = record("skin", "two", 1, tier, 50),
		["skin:three"] = record("skin", "three", 1, tier, 900),
	})
	check(Station.refusal(state, "piggy", shelf, tier) == nil,
		"three spares of one tier across three items can combine")
	check(Station.countAt(state, "piggy", tier) == 3, "the count pools across items")
	local take = Station.autoPick(state, "piggy", tier)
	check(#take == need, "auto pick takes exactly what the machine needs")
	-- CHEAPEST FIRST, which is the server's own rule: a nine-year-old who
	-- just presses the button keeps the ones worth most sold.
	check(take[1] == "skin:two", "auto pick spends the cheapest spare first")
	check(take[#take] == "skin:three", "and leaves the dearest for last")
end

-- THREE COPIES OF ONE ITEM IS ALSO ENOUGH, and the pick is one line per copy
-- because `validatePick` counts a multiset.
do
	local state = pushed({ ["skin:one"] = record("skin", "one", need, tier) })
	check(Station.refusal(state, "piggy", shelf, tier) == nil, "three of one item can combine")
	local take = Station.autoPick(state, "piggy", tier)
	check(#take == need, "the pick has one entry per copy")
	for _, entry in ipairs(take) do
		check(entry == "skin:one", "and every entry is that item")
	end
end

-- A KIND THE PLAYER HAS NO SPARES OF IS REFUSED, AND THE WRONG KIND IS NEVER
-- EATEN. `sparesAt` on the server pools ACROSS kinds deliberately, so a bare
-- `chosen = nil` at a station that says PIGGIES could spend a spare coat --
-- which is exactly why this picker is kind-filtered and always explicit.
do
	local state = pushed({
		["coat:glacier"] = record("coat", "glacier", 9, tier),
		["ride:bmx"] = record("ride", "bmx", 9, tier),
	})
	check(Station.refusal(state, "piggy", shelf, tier) ~= nil,
		"nine spare coats and rides do not make a piggy combine")
	check(Station.countAt(state, "piggy", tier) == 0, "and none of them counts as a piggy")
	check(#Station.sparesOf(state, "piggy", tier) == 0, "nor is any of them offered")
	check(#Station.autoPick(state, "piggy", tier) == 0, "nor picked")
end

-- NOTHING LEFT TO WIN. Two shapes of it, and both are said BEFORE a spare is
-- named: a kind whose catalogue does not exist, and a kind with no crate.
do
	local plenty = pushed({ ["coat:glacier"] = record("coat", "glacier", 99, tier) })
	local guardianShelves = Station.shelvesFor("guardian")
	if #guardianShelves == 0 then
		local reason = Station.refusal(plenty, "guardian", nil, nil)
		check(reason ~= nil, "a kind with nothing to win refuses")
		check(reason:lower():find("yet") ~= nil,
			"and says it is not stocked YET rather than blaming the player: " .. reason)
		-- The refusal has to arrive with NO shelf and NO tier chosen, which
		-- is the state the panel is in before anything is picked -- so the
		-- button can never light on a kind with no pool behind it.
		check(Station.refusal(plenty, "guardian", "og", tier) ~= nil,
			"and it refuses even when a piggy shelf is named")
	else
		check(Station.refusal(plenty, "guardian", guardianShelves[1].chest, tier) == nil,
			"once a guardian crate is stocked, 99 spare coats combine")
	end
	check(Station.refusal(plenty, "nonsense", shelf, tier) ~= nil,
		"an invented kind refuses rather than throwing")
end

-- A TIER WITH NOTHING ABOVE IT ON THIS SHELF IS REFUSED, which is the
-- top-of-the-ladder case: `ChestService` would roll a climb and find an empty
-- pool, and the player would have pressed a button for a sentence.
do
	local top = Config.RARITY_ORDER[#Config.RARITY_ORDER]
	local state = pushed({ ["skin:one"] = record("skin", "one", 99, top) })
	check(Station.refusal(state, "piggy", shelf, top) ~= nil,
		"the top tier has nothing to climb to")
end

-- THE BUTTON'S WORDS NEVER SAY COMBINE WHEN IT CANNOT.
do
	local text, ready = Panel.buttonText("Need 2 more spare common", 0, need)
	check(not ready and text:find("NEED") ~= nil, "a refusal replaces the verb")
	text, ready = Panel.buttonText(nil, need - 1, need)
	check(not ready and text:find(tostring(1)) ~= nil, "an incomplete pick says how many more")
	text, ready = Panel.buttonText(nil, need, need)
	check(ready and text == "COMBINE", "a full pick is the only thing that says COMBINE")
end

-- A TILE PRINTS SPARE COPIES, and a picked tile prints the pick.
do
	local name, right = Panel.tileText({ name = "Bubblegum", key = "bubblegum", count = 4 }, 0)
	check(name == "Bubblegum" and right == "x4", "an unpicked tile prints its spare count")
	name, right = Panel.tileText({ name = "Bubblegum", key = "bubblegum", count = 4 }, 2)
	check(right == "2 / 4", "a picked tile prints how many of them are going in")
	name = Panel.tileText({ key = "nameless", count = 1 }, 0)
	check(name == "nameless", "a record with no name falls back to its key")
end

-- EVERY GROUND THE PANEL PRINTS ON CARRIES INK, MEASURED.
--
-- This is the one thing a picture of this panel could not settle and a probe
-- can: WCAG relative luminance, 4.5 for body type, on the four grounds the
-- panel actually paints. `Theme` is loaded for real here -- it requires
-- nothing -- and the stub's Color3 carries its channels so the arithmetic is
-- the same one `Theme.readable` does.
do
	local function luminance(c)
		local function channel(v)
			return if v <= 0.03928 then v / 12.92 else ((v + 0.055) / 1.055) ^ 2.4
		end
		return 0.2126 * channel(c.R) + 0.7152 * channel(c.G) + 0.0722 * channel(c.B)
	end
	local function ratio(a, b)
		local la, lb = luminance(a), luminance(b)
		local hi, lo = math.max(la, lb), math.min(la, lb)
		return (hi + 0.05) / (lo + 0.05)
	end
	local function toneOf(name)
		local hue = name:match("^HUE%.(.+)$")
		return if hue then Theme.HUE[hue] else (Theme :: any)[name]
	end
	-- `Config` IS LOADED BY THE RUNNER, NOT BY THIS CHUNK, so its colours are
	-- the runner's own positional `{r, g, b}` stub rather than this suite's
	-- channel-carrying one. Converted rather than assumed: reading `.R` off
	-- one of those is nil, which is what threw the first time this ran.
	local function measurable(c)
		if type(c) ~= "table" then
			return nil
		end
		if c.R ~= nil then
			return c
		end
		if type(c[1]) == "number" then
			return rgb(c[1], c[2], c[3])
		end
		return nil
	end
	for role, name in pairs(Panel.GROUNDS) do
		local ground = toneOf(name)
		check(ground ~= nil and ground.R ~= nil,
			("the panel's %s ground names a real Theme colour (%s)"):format(role, name))
		local ink = ratio(Theme.INK, ground)
		check(ink >= 4.5,
			("ink reads on the panel's %s ground (%s): %.2f"):format(role, name, ink))
	end
	-- AND THE PICKED TILE IS WHY THE COUNT LABEL CHANGES COLOUR. Muted is
	-- fine on the unpicked tile and fails on the magenta one, so the panel
	-- switches to ink rather than leaving a grey label on the one state that
	-- is about the pick.
	check(ratio(Theme.MUTED, toneOf(Panel.GROUNDS.tile)) >= 4.5,
		"muted reads on an unpicked tile")
	check(ratio(Theme.MUTED, toneOf(Panel.GROUNDS.picked)) < 4.5,
		"and does NOT on a picked one, which is why the panel switches to ink")
	check(sources.CombinePanel:find("countLabel.TextColor3 = if picked > 0 then Theme.INK", 1, true) ~= nil,
		"the count label switches to ink when its tile is picked")
	-- EVERY RARITY COLOUR IS A TIER CHIP'S GROUND, so ink has to read on all
	-- four of those too.
	for tier, spec in pairs(Config.RARITIES) do
		local ground = measurable((spec :: any).colour)
		check(ground ~= nil, ("the %s tier has a colour to measure"):format(tier))
		local ink = ratio(Theme.INK, ground)
		check(ink >= 4.5, ("ink reads on the %s chip: %.2f"):format(tier, ink))
	end
	-- The close button is the one place PAPER prints on a saturated fill, and
	-- it is a 30px glyph, so the large-type floor is the one that applies.
	check(ratio(Theme.PAPER, Theme.STOP) >= 3.0,
		"the close button's cross reads on its own red")
end

-- MALFORMED STATE IS ANSWERED, NEVER THROWN ON. `ChestState` arrives after
-- the panel is built, so every reader here runs at least once against nil.
for _, bad in ipairs({ "nil", "number", "string", "empty", "junk" }) do
	local state: any = nil
	if bad == "number" then state = 7
	elseif bad == "string" then state = "spares"
	elseif bad == "empty" then state = {}
	elseif bad == "junk" then state = { spares = { ["skin:x"] = 4, [1] = "no" } } end
	check(#Station.sparesOf(state, "piggy", tier) == 0, "no spares out of a " .. bad .. " push")
	check(Station.countAt(state, "piggy", tier) == 0, "no count out of a " .. bad .. " push")
	check(#Station.autoPick(state, "piggy", tier) == 0, "no pick out of a " .. bad .. " push")
	check(Station.refusal(state, "piggy", shelf, tier) ~= nil, "and it refuses")
end

-- ============================================================
-- 7. THE SERVER FORWARDS AND OWNS NO ARITHMETIC
-- ============================================================

do
	local src = sources.CombineService

	-- IT CALLS `combine` AND NOTHING ELSE MOVES A SPARE. `data.spares` is a
	-- save field, and a second writer that got the decrement wrong would be
	-- a save bug rather than a broken feature.
	-- CODE-SHAPED PATTERNS, NEVER BARE WORDS. Every name below appears in
	-- that file's own header explaining why it must NOT be reached, so a
	-- plain `find` on "data.spares" would fail on the comment that promises
	-- it is not used -- which is the check marking its own reasoning wrong.
	check(src:find("ChestService.combine(player", 1, true) ~= nil,
		"the station forwards to ChestService.combine")
	check(src:find("data.spares[", 1, true) == nil,
		"the station never indexes the spares table itself")
	-- IT REACHES THE SAVE FOR ITS OWN FIELD AND FOR NOTHING ELSE.
	--
	-- This used to forbid the DataService require outright, and that was a
	-- PROXY rather than the rule. The rule is the paragraph above: a second
	-- writer to a SHARED save field is a save bug rather than a broken
	-- feature, and `data.spares` is shared. The proxy stopped fitting when
	-- the press grew a hopper of its own -- `data.press` has exactly one
	-- writer, this file, so nothing above reaches it.
	--
	-- So the check is now the thing it was standing in for: every save field
	-- this file ASSIGNS has to be its own. A `require` ban could not see a
	-- second writer arriving through a service it already held, and this can.
	check(src:find("data.press", 1, true) ~= nil,
		"the station owns the press hopper")
	do
		local strayed = nil
		-- The ASSIGNMENT, never the read: this file legitimately reads other
		-- fields through the services that own them.
		for field in src:gmatch("data%.(%w+)%s*=[^=]") do
			if field ~= "press" then
				strayed = field
			end
		end
		check(strayed == nil,
			("the station assigns no save field but its own (found %s)")
				:format(tostring(strayed)))
	end
	check(src:find("COMBINE.odds[", 1, true) == nil,
		"nor rolls the climb itself")
	check(src:find("math.random", 1, true) == nil,
		"nor rolls anything at all")
	check(src:find("takeSpare", 1, true) == nil,
		"nor consumes a spare")

	-- THE CAPABILITY IS CHECKED, because ChestService is being edited by
	-- another workstream: a missing function must warn loudly and refuse out
	-- loud rather than error inside a prompt handler.
	check(src:find("pcall", 1, true) ~= nil, "the require is guarded")
	check(src:find('type(ChestService.combine) == "function"', 1, true) ~= nil,
		"and the one function it uses is checked by name")
	check(src:find("warn(", 1, true) ~= nil, "a missing capability is loud")
	check(src:find("Notify", 1, true) ~= nil, "and the refusal reaches the player")

	-- EVERY ARGUMENT OFF THE WIRE IS CHECKED AGAINST A REAL LIST.
	check(src:find("Config.RARITY_ORDER", 1, true) ~= nil,
		"the tier is checked against the real ladder")
	check(src:find("CombineStation.shelvesFor", 1, true) ~= nil,
		"the chest is checked against the shelves the machine actually offers")
	check(src:find("CombineStation.kind", 1, true) ~= nil,
		"the kind is checked against the real list")
	check(src:find("Config.COMBINE.need", 1, true) ~= nil,
		"the entry list is bounded rather than walked wholesale")
end

-- AND `ChestService` STILL REFUSES BEFORE IT CONSUMES.
--
-- This is the one property the station cannot enforce for itself: every
-- refusal in `combine` has to come before the loop that calls `takeSpare`,
-- or a player loses three piggies to a message. Asserted by reading that
-- file's own order, which is the only way to check it without a save.
do
	local src = sources.ChestService
	local consume = src:find("takeSpare(data, consumed)", 1, true)
	check(consume ~= nil, "ChestService still consumes spares in one place")
	for _, guard in ipairs({
		"whyCannotOpen(player, chestKey)",   -- lawn full, unstocked, priced
		"Need %d more spare",                -- fewer than need
		"Those are not %d spare",            -- a pick the player does not hold
		"Legendary is the top tier",         -- nothing above
		"has no %s to give yet",             -- nothing left to win at the target
	}) do
		local where = src:find(guard, 1, true)
		check(where ~= nil, "ChestService still refuses: " .. guard)
		check(where < consume,
			("the refusal %q comes before any spare is consumed"):format(guard))
	end
end

-- ============================================================
-- 8. THE WIRING
-- ============================================================
--
-- A MODULE NOBODY WIRES IS THE SILENT FAILURE THIS PROJECT RECORDS MORE THAN
-- ANY OTHER, so both hooks are checked. `Main.server.luau` and `ClientMain`
-- are the lead's files rather than this workstream's, so an unapplied hook
-- prints PENDING rather than failing -- and the moment the two lines land,
-- these become asserts by deleting the `if`.
do
	local main = sources.Main
	if main:find("CombineService", 1, true) then
		check(main:find("CombineService).start()", 1, true) ~= nil
			or main:find("CombineService.start()", 1, true) ~= nil,
			"Main starts the combine service")
	else
		print("[combine] PENDING: Main.server.luau does not start CombineService yet,"
			.. " so the machine is not built and its remote is not connected.")
	end

	local client = sources.ClientMain
	if client:find("CombinePanel", 1, true) then
		check(client:find("CombinePanel).start(", 1, true) ~= nil,
			"ClientMain starts the combine panel")
	else
		print("[combine] PENDING: ClientMain does not start CombinePanel yet,"
			.. " so the prompt fires a remote nothing is listening to.")
	end

	-- The panel publishes its own flag so the pair can be made exclusive
	-- from `ClientMain` in one line. It also closes ITSELF when a menu
	-- opens, so the flag only buys the other direction.
	local panel = sources.CombinePanel
	check(panel:find('CombinePanel.ATTRIBUTE = "CombineOpen"', 1, true) ~= nil,
		"the panel publishes an attribute for the menus to read")
	check(panel:find('gui:GetAttributeChangedSignal(name)', 1, true) ~= nil,
		"and watches the menu flags to close itself")
	check(panel:find('"BagOpen"', 1, true) ~= nil, "including the bag")
	check(panel:find('GetPropertyChangedSignal("DisplayOrder")', 1, true) ~= nil,
		"and the shop, which raises the HUD's DisplayOrder rather than a flag")
	-- AND IT MUST NOT WRITE `BagOpen`: `setBag` sets the flag AND the frame
	-- separately, so an outside write to the flag leaves the bag on screen
	-- with the HUD believing it shut.
	check(panel:find('SetAttribute("BagOpen"', 1, true) == nil,
		"the panel never writes the bag's flag from outside")
	-- The reveal is Crates', reached through the remote ClientMain already
	-- connects. A second one here would be two reveals on one result.
	-- Code-shaped again: the panel's own header explains that the reveal is
	-- `Crates`' and names SpinWheel while doing it.
	check(panel:find("Shared.SpinWheel", 1, true) == nil, "the panel draws no second reveal")
	check(panel:find("Shared.Crates", 1, true) == nil, "nor reaches into the crates tab")
	check(panel:find("ChestState", 1, true) ~= nil, "it reads the server's own spare push")
end

-- ============================================================
-- 9. THE REMOTES
-- ============================================================
do
	local src = sources.Remotes
	for _, name in ipairs({ "CombineOpen", "CombineRequest" }) do
		check(src:find(name .. ' = "RemoteEvent"', 1, true) ~= nil,
			name .. " is declared in the one list")
	end
	-- The open carries nothing: the hold means "open it", never "open it
	-- with this in it".
	check(sources.CombineService:find('Remotes.get("CombineOpen"):FireClient(player)', 1, true) ~= nil,
		"the prompt's remote carries no payload")
end

print(("combine: %d checks passed (station gap %s at x %.0f z %.1f, %d parts,"
	.. " 0 coplanar pairs, tightest clearance %.2f studs)"):format(
	checks, tostring(at.gap), at.x, at.z, #boxes,
	(function()
		local worst = math.huge
		for _, gap in pairs(clearances) do worst = math.min(worst, gap) end
		return worst
	end)()))
