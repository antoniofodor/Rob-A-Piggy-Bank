-- The grassland: ponds, flower drifts, rocks and a log in the band the herds
-- wander. The real builder runs under a small engine stub -- 3x3 CFrames and
-- counted Instances, no rendering -- and every pond is measured against the
-- band `Config.herdGround()` describes, the corridors a pack walks in by,
-- and the valley wall. THE STUB IS THE INSTRUMENT AND NOT THE THING: it
-- proves where the parts are and says nothing about what they look like.
local Config, SOURCES = ...
local checks = 0
local function check(ok, message) assert(ok, message); checks += 1 end

-- ---- THE STUB ------------------------------------------------------------
local V = {}
V.__index = V
local function vec(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, V) end
function V.__add(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
function V.__sub(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
function V.__mul(a, b)
	if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
local CF = {}
local function cframe(px, py, pz, r)
	return setmetatable({ p = vec(px, py, pz), r = r or { 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, CF)
end
function CF.__index(self, key)
	if key == "Position" then return rawget(self, "p") end
	if key == "X" then return rawget(self, "p").X end
	if key == "Y" then return rawget(self, "p").Y end
	if key == "Z" then return rawget(self, "p").Z end
	local r = rawget(self, "r")
	if key == "LookVector" then return vec(-r[3], -r[6], -r[9]) end
	if key == "ZVector" then return vec(r[3], r[6], r[9]) end
	if key == "XVector" or key == "RightVector" then return vec(r[1], r[4], r[7]) end
	if key == "YVector" or key == "UpVector" then return vec(r[2], r[5], r[8]) end
	return rawget(CF, key)
end
local function mul3(a, b)
	local o = {}
	for i = 0, 2 do for j = 0, 2 do
		local acc = 0
		for k = 0, 2 do acc += a[i * 3 + k + 1] * b[k * 3 + j + 1] end
		o[i * 3 + j + 1] = acc
	end end
	return o
end
local function apply(r, v)
	return vec(r[1] * v.X + r[2] * v.Y + r[3] * v.Z, r[4] * v.X + r[5] * v.Y + r[6] * v.Z,
		r[7] * v.X + r[8] * v.Y + r[9] * v.Z)
end
function CF.__mul(a, b)
	if getmetatable(b) == V then local w = apply(a.r, b); return vec(a.p.X + w.X, a.p.Y + w.Y, a.p.Z + w.Z) end
	local w = apply(a.r, b.p)
	return cframe(a.p.X + w.X, a.p.Y + w.Y, a.p.Z + w.Z, mul3(a.r, b.r))
end
local CFrame = {}
CFrame.new = function(x, y, z) if type(x) == "table" then return cframe(x.X, x.Y, x.Z) end return cframe(x or 0, y or 0, z or 0) end
CFrame.Angles = function(rx, ry, rz)
	rx, ry, rz = rx or 0, ry or 0, rz or 0
	local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
	return cframe(0, 0, 0, mul3(mul3({ 1, 0, 0, 0, cx, -sx, 0, sx, cx }, { cy, 0, sy, 0, 1, 0, -sy, 0, cy }), { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }))
end
CFrame.identity = cframe(0, 0, 0)
local CM = { __index = { Lerp = function(self) return self end } }
local Color3 = {
	fromRGB = function(r, g, b) return setmetatable({ r, g, b }, CM) end,
	new = function(r, g, b) return setmetatable({ r, g, b }, CM) end,
}
local Enum = setmetatable({}, { __index = function(_, group)
	return setmetatable({}, { __index = function(_, name) return group .. "." .. name end })
end })
local INST = {}
INST.__index = function(self, key) return rawget(INST, key) end
INST.__newindex = function(self, key, value)
	if key == "Parent" then
		rawset(self, "Parent", value)
		if type(value) == "table" and rawget(value, "_kids") then table.insert(rawget(value, "_kids"), self) end
		return
	end
	rawset(self, key, value)
end
function INST:IsA(c)
	local cls = rawget(self, "ClassName")
	return cls == c or (c == "BasePart" and (cls == "Part" or cls == "WedgePart"))
end
function INST:GetChildren() return rawget(self, "_kids") end
function INST:GetDescendants()
	local out = {}
	local function walk(node)
		for _, kid in ipairs(rawget(node, "_kids")) do
			table.insert(out, kid)
			walk(kid)
		end
	end
	walk(self)
	return out
end
local Instance = { new = function(class)
	return setmetatable({ ClassName = class, Name = class, _kids = {}, Size = vec(1, 1, 1),
		CFrame = CFrame.identity, Shape = "PartType.Block" }, INST)
end }
local warnings = {}
local anyService = setmetatable({}, { __index = function() return function() end end })
local shared = setmetatable({}, { __index = function(_, mod) return { __module = mod } end })
local function loadGrassland(source, configOverride)
	local loaded = { Config = configOverride or Config }
	local env
	local function req(token)
		local name = type(token) == "table" and token.__module or tostring(token)
		if loaded[name] then return loaded[name] end
		assert(name == "Grassland", "the grassland requires nothing but Config: " .. name)
		local run = assert(loadstring(source, name))
		setfenv(run, env)
		loaded[name] = run()
		return loaded[name]
	end
	env = setmetatable({
		Color3 = Color3, Vector3 = { new = vec }, Vector2 = { new = vec }, CFrame = CFrame, Enum = Enum,
		Instance = Instance, require = req,
		warn = function(message) table.insert(warnings, tostring(message)) end,
		game = { GetService = function(_, name) if name == "ReplicatedStorage" then return { Shared = shared } end return anyService end },
	}, { __index = getfenv() })
	return req({ __module = "Grassland" })
end

local Grassland = loadGrassland(SOURCES.Grassland)
local G = Config.GRASSLAND
local g = Config.herdGround()

-- ---- THE LAYOUT, AGAINST THE BAND ---------------------------------------
local ponds = Grassland.layout(g, {})
check(#ponds == 2 * #G.pondRadii, "three ponds a side: " .. #ponds)
local farLimit = math.min(g.bandFar, Config.GROUND_SIZE.Y / 2 - G.farInset)
local perSide = { [-1] = 0, [1] = 0 }
for i, pond in ipairs(ponds) do
	perSide[pond.side] += 1
	check(pond.z * pond.side > 0, ("pond %d stands on its own side"):format(i))
	local depth = math.abs(pond.z)
	check(depth - pond.rim >= g.bandNear + G.nearKeep - 1e-6,
		("pond %d's rim starts past the band's near edge (%.1f vs %.1f)"):format(i, depth - pond.rim, g.bandNear + G.nearKeep))
	check(depth + pond.rim <= farLimit + 1e-6,
		("pond %d's rim stops short of the valley wall (%.1f vs %.1f)"):format(i, depth + pond.rim, farLimit))
	check(math.abs(pond.x) + pond.rim <= g.corridorInner - G.entryKeep + 1e-6,
		("pond %d keeps out of the end corridor and the turn into the band (|x| %.1f)"):format(i, math.abs(pond.x) + pond.rim))
	check(pond.rim > pond.radius, "the rim reaches past the water")
end
check(perSide[-1] == #G.pondRadii and perSide[1] == #G.pondRadii, "both sides get their ponds")
for a = 1, #ponds do
	for b = a + 1, #ponds do
		if ponds[a].side == ponds[b].side then
			local dx, dz = ponds[a].x - ponds[b].x, ponds[a].z - ponds[b].z
			check(math.sqrt(dx * dx + dz * dz) >= G.pondSpacing - 1e-6, "two ponds on one side are two places")
		end
	end
end
-- The first pond a side prefers the fence and the second prefers depth.
for _, side in ipairs({ -1, 1 }) do
	local mine = {}
	for _, pond in ipairs(ponds) do
		if pond.side == side then table.insert(mine, pond) end
	end
	check(math.abs(mine[1].z) < math.abs(mine[2].z), ("side %+d: the first pond is nearer than the second"):format(side))
	for _, pond in ipairs(mine) do
		check(pond.radius >= 10, "no pond is smaller than the size that photographed as a sliver")
	end
end

-- The layout answers the trees it is handed: a canopy dropped on the first
-- pond's own spot moves that pond, and the moved pond is clear of it.
local first = ponds[1]
local crowded = Grassland.layout(g, { { x = first.x, z = first.z, reach = 15 } })
local moved = crowded[1]
check(moved.x ~= first.x or moved.z ~= first.z, "a tree on a pond's spot moves the pond")
local dx, dz = moved.x - first.x, moved.z - first.z
check(math.sqrt(dx * dx + dz * dz) - 15 >= moved.rim + G.canopyMargin - 1e-6,
	"and the moved pond's rim clears the canopy by the margin")
check(#crowded == #ponds, "and nothing else about the count changes")
-- With no trees at all the clearance is unbounded and nothing warns.
check(#warnings == 0, "an empty band draws no warning")

-- ---- THE BUILD -----------------------------------------------------------
local world = { _kids = {} }
local folder, built, count = Grassland.build(world, {})
check(folder.Parent == world, "the grassland lands in the parent it is given")
check(#built == #ponds, "the build stands the ponds the layout chose")
local parts = {}
for _, p in ipairs(folder:GetChildren()) do
	if p:IsA("BasePart") then table.insert(parts, p) end
end
check(#parts == count, ("the returned count is the part count (%d vs %d)"):format(count, #parts))
check(count <= G.budget, ("the whole grassland is under budget: %d of %d"):format(count, G.budget))
check(count > 200, "and it is not an empty field: " .. count)

-- Every part is scenery a pack and a thief can pass through -- EXCEPT the
-- rim stones, which collide so a pathfinding agent goes round the pond:
-- measured live, a PathfindingModifier on the non-colliding water did
-- nothing and only colliding geometry moved a path. They stay non-query
-- and non-touch, the trunk colliders' own flag set, so no raycast meant
-- for a piggy is eaten and nothing fires Touched.
local names = {}
for _, p in ipairs(parts) do
	if p.Name == "PondStone" then
		check(p.Anchored == true and p.CanCollide == true and p.CanQuery == false and p.CanTouch == false and p.CastShadow == false,
			"a rim stone is anchored, COLLIDING, non-query, non-touch and casts no shadow")
	elseif p.Name == "RimWall" then
		-- The navmesh steps a stone 1.6 proud (measured live), so every stone
		-- carries an invisible colliding column over jumpReach.
		check(p.Anchored == true and p.CanCollide == true and p.CanQuery == false and p.CanTouch == false and p.CastShadow == false,
			"a rim wall is anchored, COLLIDING, non-query, non-touch and casts no shadow")
		check(p.Transparency == 1, "and invisible: the rock is what a player sees")
		check(p.Shape == "PartType.Cylinder" and math.abs(p.CFrame.RightVector.Y) > 0.999, "an upright cylinder")
	else
		check(p.Anchored == true and p.CanCollide == false and p.CanQuery == false and p.CastShadow == false,
			p.Name .. " is anchored, non-colliding, non-query and casts no shadow")
	end
	check(p.Material == "Material.SmoothPlastic", p.Name .. " is flat SmoothPlastic")
	names[p.Name] = (names[p.Name] or 0) + 1
end
check((names.PondBed or 0) == #ponds and (names.PondWater or 0) == #ponds, "every pond has a bed and water")
check((names.PondStone or 0) >= 6 * #ponds, "every pond has a rim of stones")
check((names.RimWall or 0) == (names.PondStone or 0), "and one invisible wall per stone: " .. (names.RimWall or 0))
check((names.Bloom or 0) > 6 * G.flowerClustersPerSide, "the drifts are dense: " .. (names.Bloom or 0) .. " heads")
check((names.Stem or 0) > 0 and (names.Stem or 0) * (G.stemEvery - 1) <= (names.Bloom or 0), "a stem under about every third head")
check((names.Mound or 0) > 0 and (names.Mound or 0) <= 2 * G.flowerClustersPerSide, "every drift stands on one mound")
check((names.Bush or 0) >= 2 * 2 * G.bushesPerSide and (names.Bush or 0) <= 3 * 2 * G.bushesPerSide, "the bushes are two or three balls each")
check((names.Rock or 0) == 2 * G.rocksPerSide and (names.Log or 0) == 2 * G.logsPerSide, "rocks and logs at their counts")
for _, p in ipairs(parts) do
	if p.Name == "Bloom" then
		check(p.Size.X / 2 >= G.headRadius[1] - 1e-6 and p.Size.X / 2 <= G.headRadius[2] + 1e-6, "a head is the size that reads from forty studs")
	end
end

-- THE WATER SITS BELOW THE RIM AND ABOVE THE BED, all proud of the ground:
-- nothing here can be dug, so the depth is the rim standing over the water.
local groundY = g.groundY
for _, p in ipairs(parts) do
	if p.Name == "PondWater" then
		local top = p.CFrame.Position.Y + p.Size.X / 2 -- a disc's thickness is on X
		check(top > groundY and top < groundY + 1, "the water's surface is a hair proud of the grass")
		check(p.Transparency > 0.2 and p.Transparency < 0.6, "the water is translucent, not glass")
	elseif p.Name == "PondBed" then
		local top = p.CFrame.Position.Y + p.Size.X / 2
		check(top > groundY and top < groundY + 0.2, "the bed is just proud of the grass")
		check(p.Transparency == nil, "and opaque, or the water tints the grass under it")
	elseif p.Name == "PondStone" then
		local top = p.CFrame.Position.Y + p.Size.Y / 2
		check(top > groundY + 0.9, "a rim stone stands well over the water line")
		check(p.CFrame.Position.Y < groundY, "and is sunk, so its chord at the grass is wide")
	elseif p.Name == "RimWall" then
		-- A WALL, NOT A STEP: the top clears a jump by the margin, derived
		-- from `Config.jumpReach()` -- the number every fence tier and every
		-- trunk collider is held to -- and the base is sunk into the ground.
		local top = p.CFrame.Position.Y + p.Size.X / 2 -- a cylinder's length is on X
		local bottom = p.CFrame.Position.Y - p.Size.X / 2
		local floor = groundY + Config.jumpReach() + G.rimJumpMargin
		check(top >= floor - 1e-6, ("a rim wall's top %.2f clears the jump floor %.2f"):format(top - groundY, floor - groundY))
		check(top <= floor + 1e-6, "and is exactly the derived height, not a number somebody typed")
		check(bottom < groundY - 1e-6 and bottom > groundY - 2, "the base is sunk a little into the ground")
		-- The wall stands on its stone: same X and Z as exactly one stone, at
		-- that stone's own radius, so the ring-gap proof on the stones is the
		-- ring-gap proof on the walls.
		local onStone = 0
		for _, s in ipairs(parts) do
			if s.Name == "PondStone" and math.abs(s.CFrame.Position.X - p.CFrame.Position.X) < 1e-6
				and math.abs(s.CFrame.Position.Z - p.CFrame.Position.Z) < 1e-6 then
				onStone += 1
				check(math.abs(s.Size.X - p.Size.Y) < 1e-9, "at the stone's own radius")
			end
		end
		check(onStone == 1, "a wall stands on exactly one stone")
	end
end
-- PROVED TO FIRE: the same build under a NEGATIVE margin puts every wall
-- under the real floor, which is what the check above would refuse.
do
	local low = setmetatable({ GRASSLAND = setmetatable({ rimJumpMargin = -3 }, { __index = G }) }, { __index = Config })
	local Low = loadGrassland(SOURCES.Grassland, low)
	local lowFolder = Low.build({ _kids = {} }, {})
	local floor = groundY + Config.jumpReach() + G.rimJumpMargin
	local walls, under = 0, 0
	for _, p in ipairs(lowFolder:GetChildren()) do
		if p.Name == "RimWall" then
			walls += 1
			if p.CFrame.Position.Y + p.Size.X / 2 < floor - 1e-6 then under += 1 end
		end
	end
	check(walls > 0 and under == walls, ("a negative margin is caught: %d of %d walls under the floor"):format(under, walls))
end

-- ---- THE VETO ------------------------------------------------------------
for i, pond in ipairs(built) do
	check(Grassland.blocks(vec(pond.x, groundY + 1, pond.z)), ("blocks at pond %d's centre"):format(i))
	check(Grassland.blocks(vec(pond.x + pond.rim, groundY + 1, pond.z)), "blocks at the rim's edge")
	check(not Grassland.blocks(vec(pond.x + pond.rim + G.pondMargin + 10, groundY + 1, pond.z)),
		"does not block ten studs outside the footprint")
	check(not Grassland.blocks(vec(pond.x, groundY + 1, pond.z - pond.side * (pond.rim + G.pondMargin + 10))),
		"nor ten studs toward the fence")
end
check(not Grassland.blocks(vec(0, groundY + 1, 0)), "the street is not a pond")

-- ---- ZERO SAME-FACING COPLANAR PAIRS -------------------------------------
-- CLAUDE.md's rule: two AXIS-ALIGNED parts sharing a face plane that points
-- the same way (lo with lo or hi with hi, within 0.02) with real overlap on
-- the other two axes. A ball has no planes; a cylinder's only planes are its
-- two ends, so a disc stood on its axis is audited on Y alone and a rolled
-- or yawed log not at all. Rotated blocks are skipped, as the house audit
-- skips them, because their faces are not on any world plane.
local function coplanarPairs(list)
	local boxes = {}
	for _, p in ipairs(list) do
		-- A coplanar pair is a RENDER fault, and a fully transparent part
		-- (the rim walls) cannot flicker; the audit is about what is drawn.
		if p.Shape ~= "PartType.Ball" and p.Transparency ~= 1 then
			local cf, s = p.CFrame, p.Size
			local R, U, L = cf.RightVector, cf.UpVector, cf.LookVector
			local function unit(v) return math.abs(math.abs(v.X) - 1) < 1e-6 or math.abs(math.abs(v.Y) - 1) < 1e-6 or math.abs(math.abs(v.Z) - 1) < 1e-6 end
			if unit(R) and unit(U) and unit(L) then
				local hx = math.abs(R.X) * s.X / 2 + math.abs(U.X) * s.Y / 2 + math.abs(L.X) * s.Z / 2
				local hy = math.abs(R.Y) * s.X / 2 + math.abs(U.Y) * s.Y / 2 + math.abs(L.Y) * s.Z / 2
				local hz = math.abs(R.Z) * s.X / 2 + math.abs(U.Z) * s.Y / 2 + math.abs(L.Z) * s.Z / 2
				local axes = { true, true, true }
				if p.Shape == "PartType.Cylinder" then
					-- Only the axis' two end faces are planes. The axis is local X.
					axes = { math.abs(R.X) > 0.5, math.abs(R.Y) > 0.5, math.abs(R.Z) > 0.5 }
				end
				local c = cf.Position
				table.insert(boxes, { name = p.Name, axes = axes,
					lo = { c.X - hx, c.Y - hy, c.Z - hz }, hi = { c.X + hx, c.Y + hy, c.Z + hz } })
			end
		end
	end
	local pairs_ = {}
	for a = 1, #boxes do
		for b = a + 1, #boxes do
			local A, B = boxes[a], boxes[b]
			for k = 1, 3 do
				if A.axes[k] and B.axes[k]
					and (math.abs(A.lo[k] - B.lo[k]) < 0.02 or math.abs(A.hi[k] - B.hi[k]) < 0.02) then
					local overlap = true
					for j = 1, 3 do
						if j ~= k then
							if math.min(A.hi[j], B.hi[j]) - math.max(A.lo[j], B.lo[j]) <= 0.02 then overlap = false end
						end
					end
					if overlap then table.insert(pairs_, A.name .. "/" .. B.name) end
				end
			end
		end
	end
	return pairs_, #boxes
end
local coplanar, audited = coplanarPairs(parts)
check(audited > 100, "the audit has real parts to look at: " .. audited)
check(#coplanar == 0, "zero same-facing coplanar pairs (found " .. #coplanar .. ": " .. table.concat(coplanar, ", ", 1, math.min(#coplanar, 6)) .. ")")

-- AND THE AUDIT CAN FAIL: a second water disc at the same height, shifted
-- three studs so the two overlap, is exactly the pair it exists to catch --
-- and a third disc lifted a tenth of a stud is not.
do
	local water
	for _, p in ipairs(parts) do
		if p.Name == "PondWater" then water = p break end
	end
	local c = water.CFrame.Position
	local twin = Instance.new("Part")
	twin.Name = "Twin"; twin.Shape = water.Shape; twin.Size = water.Size
	twin.CFrame = CFrame.new(c.X, c.Y, c.Z + 3) * CFrame.Angles(0, 0, math.pi / 2)
	local found = coplanarPairs({ water, twin })
	check(#found == 1 and found[1] == "PondWater/Twin", "the audit catches two overlapping discs at one height")
	local lifted = Instance.new("Part")
	lifted.Name = "Lifted"; lifted.Shape = water.Shape; lifted.Size = water.Size
	lifted.CFrame = CFrame.new(c.X, c.Y + 0.1, c.Z + 3) * CFrame.Angles(0, 0, math.pi / 2)
	check(#coplanarPairs({ water, lifted }) == 0, "and passes the same pair a tenth of a stud apart")
end

-- ---- DETERMINISM ---------------------------------------------------------
local function fingerprint(list)
	local out = {}
	for _, p in ipairs(list) do
		local c = p.CFrame.Position
		table.insert(out, ("%s|%.4f,%.4f,%.4f|%.4f,%.4f,%.4f|%s"):format(p.Name, p.Size.X, p.Size.Y, p.Size.Z,
			c.X, c.Y, c.Z, table.concat(p.Color, ",")))
	end
	return table.concat(out, "\n")
end
local again = { _kids = {} }
local folder2, built2, count2 = Grassland.build(again, {})
local parts2 = {}
for _, p in ipairs(folder2:GetChildren()) do
	if p:IsA("BasePart") then table.insert(parts2, p) end
end
check(count2 == count and #built2 == #built, "a second build is the same size")
check(fingerprint(parts) == fingerprint(parts2), "two builds are identical part for part")

-- Adding a tree removes only what stood under it: the flowers elsewhere do
-- not move, because every draw is consumed whether or not the flower stood.
local shifted = { _kids = {} }
local folder3 = Grassland.build(shifted, { { x = 0, z = g.bandNear + 30, reach = 12 } })
local before, after = {}, {}
for _, p in ipairs(parts) do if p.Name == "Bloom" then before[("%.3f,%.3f"):format(p.CFrame.Position.X, p.CFrame.Position.Z)] = true end end
local kept, new = 0, 0
for _, p in ipairs(folder3:GetChildren()) do
	if p.Name == "Bloom" then
		local key = ("%.3f,%.3f"):format(p.CFrame.Position.X, p.CFrame.Position.Z)
		if before[key] then kept += 1 else new += 1 end
	end
end
check(new == 0, "a tree added to the band moves no flower that was not under it: " .. new .. " moved")
check(kept > 0, "and the rest of the drift still stands")

-- ---- THE WIRING ----------------------------------------------------------
-- The builder is handed the grove and built after it, and Main registers the
-- veto: a module nobody wires is a pond the herd walks through.
local ns = SOURCES.NeighborhoodService
check(ns:find("Grassland.build(folder, grovePlacements)", 1, true) ~= nil, "NeighborhoodService hands the builder the grove's trunks")
local treesAt = ns:find("\tbuildTrees(m)", 1, true)
local grassAt = ns:find("\tbuildGrassland()", 1, true)
check(treesAt and grassAt and grassAt > treesAt, "and builds the grassland after the trees")
check(ns:find("table.insert(grovePlacements, { x = x, z = side * (rear + depth), reach = reach })", 1, true) ~= nil,
	"every grove tree is recorded where buildTree stands it")
check(SOURCES.Main:find("HerdService.addGroundVeto(require(ReplicatedStorage.Shared.Grassland).blocks)", 1, true) ~= nil,
	"Main registers the pond veto with the herd")

print(("grassland: %d checks passed (%d parts, %d ponds)"):format(checks, count, #built))
