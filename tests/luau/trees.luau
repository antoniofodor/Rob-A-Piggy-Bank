-- The trees: one invisible TRUNK collider per tree (designer decision,
-- 2026-09-21 -- "real impassable trees so players and the piggies have to
-- walk around them"), and the herd veto those footprints feed. The real
-- NeighborhoodService builds the real grove and verge layout under a small
-- engine stub -- 3x3 CFrames and counted Instances, no rendering, no web
-- call -- and every collider is measured against the trunk and canopy it
-- stands under, the herd's corridors and kerb legs, the yards, the bins, the
-- shop forecourts and the boards. THE STUB IS THE INSTRUMENT AND NOT THE
-- THING: it proves where the parts are and what they are set to, and says
-- nothing about whether a character actually stops at one. That is the
-- coordinator's walk.
local Config, SOURCES = ...
local checks = 0
local function check(ok, message) assert(ok, message); checks += 1 end

-- ---- THE STUB (Grassland's, plus Clone, attributes and a MeshPart) --------
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
		local old = rawget(self, "Parent")
		if type(old) == "table" and rawget(old, "_kids") then
			local kids = rawget(old, "_kids")
			for i, kid in ipairs(kids) do if kid == self then table.remove(kids, i) break end end
		end
		rawset(self, "Parent", value)
		if type(value) == "table" and rawget(value, "_kids") then table.insert(rawget(value, "_kids"), self) end
		return
	end
	rawset(self, key, value)
end
local PART_CLASSES = { Part = true, WedgePart = true, MeshPart = true }
function INST:IsA(c)
	local cls = rawget(self, "ClassName")
	return cls == c or (c == "BasePart" and PART_CLASSES[cls] == true)
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
function INST:FindFirstChild(name)
	for _, kid in ipairs(rawget(self, "_kids")) do if rawget(kid, "Name") == name then return kid end end
	return nil
end
function INST:SetAttribute(key, value) rawget(self, "_attrs")[key] = value end
function INST:GetAttribute(key) return rawget(self, "_attrs")[key] end
function INST:Destroy() self.Parent = nil end
local Instance
function INST:Clone()
	local copy = Instance.new(rawget(self, "ClassName"))
	for k, v in pairs(self) do
		if k ~= "_kids" and k ~= "Parent" and k ~= "_attrs" then rawset(copy, k, v) end
	end
	for k, v in pairs(rawget(self, "_attrs")) do rawget(copy, "_attrs")[k] = v end
	return copy
end
Instance = { new = function(class)
	return setmetatable({ ClassName = class, Name = class, _kids = {}, _attrs = {}, Size = vec(1, 1, 1),
		CFrame = CFrame.identity, Shape = "PartType.Block" }, INST)
end }
local warnings = {}
local anyService = setmetatable({}, { __index = function() return function() end end })
local function stubModule()
	return setmetatable({}, { __index = function() return function() return nil end end })
end

-- Loads the real NeighborhoodService with everything it requires but Config
-- and SceneryTrees stubbed. `sceneryOverride` replaces SceneryTrees so the
-- measured-model route can be exercised; `configOverride` replaces Config so
-- the box-and-ball route can be.
-- The runner loads Config with plain-table vectors that carry no arithmetic,
-- and the mesh route multiplies `entry.size * scale`: the mesh spec is
-- re-issued with this stub's own vectors. Field reads elsewhere are fine.
local function livened(v) return vec(v.X, v.Y, v.Z) end
local function meshConfig(base)
	local mesh = base.treeMesh()
	if mesh then
		for _, e in ipairs(mesh.parts) do e.offset = livened(e.offset); e.size = livened(e.size) end
	end
	return setmetatable({ treeMesh = function() return mesh end }, { __index = base })
end
local function loadNeighborhood(sceneryOverride, configOverride)
	local cfg = configOverride or meshConfig(Config)
	local loaded = { Config = cfg }
	local env
	local shared = setmetatable({}, { __index = function(_, mod) return { __module = mod } end })
	local function req(token)
		local name = type(token) == "table" and token.__module or tostring(token)
		if loaded[name] then return loaded[name] end
		if name == "SceneryTrees" and sceneryOverride then
			loaded[name] = sceneryOverride
		elseif SOURCES[name] then
			local run = assert(loadstring(SOURCES[name], name))
			setfenv(run, env)
			loaded[name] = run()
		else
			loaded[name] = stubModule()
		end
		return loaded[name]
	end
	env = setmetatable({
		Color3 = Color3, Vector3 = { new = vec }, Vector2 = { new = vec }, CFrame = CFrame, Enum = Enum,
		Instance = Instance, require = req,
		warn = function(message) table.insert(warnings, tostring(message)) end,
		print = function() end,
		script = { Parent = { SceneryTrees = { __module = "SceneryTrees" }, Config = { __module = "Config" } } },
		workspace = { FindFirstChild = function() return nil end },
		game = { GetService = function(_, name)
			if name == "ReplicatedStorage" then return { Shared = shared } end
			if name == "ServerStorage" then return { FindFirstChild = function() return nil end } end
			if name == "InsertService" then
				return { CreateMeshPartAsync = function(_, id) local p = Instance.new("MeshPart"); p.MeshId = id; return p end }
			end
			return anyService
		end },
	}, { __index = getfenv() })
	return req({ __module = "NeighborhoodService" })
end

local T = Config.TREES
local groundY = -Config.PLOT_SIZE.Y / 2
local function dist(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end
-- A part's world-space half extent along one axis, per part through its own
-- CFrame -- the measurement CLAUDE.md prescribes for anything turned.
local function halfExtent(p, axis)
	local cf, s = p.CFrame, p.Size
	return math.abs(cf.RightVector[axis]) * s.X / 2 + math.abs(cf.UpVector[axis]) * s.Y / 2
		+ math.abs(cf.LookVector[axis]) * s.Z / 2
end
local function partsNamed(parent, name)
	local out = {}
	for _, p in ipairs(parent:GetChildren()) do if p.Name == name then table.insert(out, p) end end
	return out
end
local function nearest(list, x, z)
	local best, bestD = nil, math.huge
	for _, p in ipairs(list) do
		local d = dist(p.CFrame.Position.X, p.CFrame.Position.Z, x, z)
		if d < bestD then best, bestD = p, d end
	end
	return best, bestD
end

-- ---- THE MESH ROUTE: THE STREET AS IT SHIPS ------------------------------
local NS = loadNeighborhood()
local world = Instance.new("Folder")
NS.plantTrees(world)
local colliders = partsNamed(world, T.colliderName)
local trunks = partsNamed(world, "Trunk")
local canopies = partsNamed(world, "Canopy")
check(#trunks > 40, "the street has a grove and a verge on it: " .. #trunks .. " trees")
check(#colliders == #trunks, ("every tree has exactly one collider (%d colliders, %d trees)"):format(#colliders, #trunks))
check(#canopies == #trunks, "and one canopy")
check(#NS.trunkColliders() == #colliders, "the footprints the veto reads are the colliders that stand")

-- Every collider: invisible, solid, silent to queries and touches, upright.
for _, c in ipairs(colliders) do
	check(c.CanCollide == true, "a trunk collider collides")
	check(c.CanQuery == false, "and answers no query, so it cannot eat a raycast meant for a piggy")
	check(c.CanTouch == false, "and fires no Touched")
	check(c.Transparency == 1 and c.CastShadow == false and c.Anchored == true, "and is invisible, shadowless and anchored")
	check(c.Shape == "PartType.Cylinder", "and is a cylinder")
	-- A Roblox cylinder's axis is X, so an upright one has its RightVector vertical.
	check(math.abs(c.CFrame.RightVector.Y) > 0.999, "stood on end -- the cylinder's X axis is vertical")
	check(math.abs(c.Size.Y - c.Size.Z) < 1e-9, "round in cross-section")
end

-- THE RADIUS AND HEIGHT RULE, measured against the trunk and canopy each
-- collider stands under rather than against the constant it was built from:
-- radius within [0.8, 1.2] of the trunk part's rendered footprint times the
-- bole fraction, base sunk into the ground, top at or under the canopy's
-- underside and never up in the air above it.
local seen = {}
for _, c in ipairs(colliders) do
	local cx, cz = c.CFrame.Position.X, c.CFrame.Position.Z
	local trunk, d = nearest(trunks, cx, cz)
	check(d < 1e-6, ("a collider stands on its trunk (%.3f off)"):format(d))
	check(not seen[trunk], "and no trunk carries two")
	seen[trunk] = true
	-- The trunk part's own Size is its rendered footprint -- every tree is yawed,
	-- and a turned box read along world axes is up to root two too wide.
	local rendered = math.min(trunk.Size.X, trunk.Size.Z) / 2 * T.boleFraction
	local radius = c.Size.Y / 2
	check(radius >= 0.8 * rendered - 1e-9 and radius <= 1.2 * rendered + 1e-9,
		("radius %.3f within [0.8, 1.2] of the rendered bole %.3f"):format(radius, rendered))
	local top = c.CFrame.Position.Y + c.Size.X / 2
	local bottom = c.CFrame.Position.Y - c.Size.X / 2
	local canopy = nearest(canopies, cx, cz)
	local underside = canopy.CFrame.Position.Y - halfExtent(canopy, "Y")
	-- A WALL, NOT A STEP: the top clears a jump (`Config.jumpReach`, the same
	-- number every fence tier is held to) by the margin, and otherwise stops
	-- at the canopy's underside -- so it is the higher of the two and no more.
	local jumpFloor = groundY + Config.jumpReach() + T.jumpMargin
	check(top >= jumpFloor - 1e-6, ("top %.2f clears a jump: floor %.2f above ground"):format(top - groundY, jumpFloor - groundY))
	check(top <= math.max(underside, jumpFloor) + 1e-6,
		("top %.2f is the higher of the canopy's underside %.2f and the jump floor %.2f, not more"):format(top, underside, jumpFloor))
	check(top >= groundY + 5, ("and is a wall, not a kerb: %.2f above the ground"):format(top - groundY))
	check(bottom < groundY - 1e-6 and bottom > groundY - 2, "the base is sunk a little into the ground")
end
-- Every VISIBLE tree part is still decoration: the collision moved onto the
-- invisible part and nowhere else, which is the fence's own split.
for _, p in ipairs(world:GetChildren()) do
	if p.Name ~= T.colliderName then
		check(p.CanCollide == false and p.CanQuery == false and p.CastShadow == false,
			p.Name .. " stays non-colliding, non-query, shadowless scenery")
	end
end

-- ---- THE VETO -------------------------------------------------------------
local reachOf = {}
for _, c in ipairs(colliders) do
	local cx, cz = c.CFrame.Position.X, c.CFrame.Position.Z
	local r = c.Size.Y / 2
	check(NS.treeBlocks(vec(cx, groundY + 1, cz)), "blocks at the trunk's centre")
	check(NS.treeBlocks(vec(cx + r + T.margin - 0.05, groundY + 1, cz)), "blocks just inside a piggy's radius of the bark")
	-- One margin and a hair past the bark: clear, unless another trunk's own
	-- keep happens to cover that spot -- then it is the other trunk blocking.
	local px, pz = cx + r + T.margin + 0.5, cz
	local other = false
	for _, o in ipairs(colliders) do
		if o ~= c and dist(o.CFrame.Position.X, o.CFrame.Position.Z, px, pz) <= o.Size.Y / 2 + T.margin then other = true end
	end
	if not other then
		check(not NS.treeBlocks(vec(px, groundY + 1, pz)), "does not block one margin past the bark")
	end
	-- Under the canopy's edge -- the leaves do not block, only the wood.
	local canopy = nearest(canopies, cx, cz)
	local reach = math.max(halfExtent(canopy, "X"), halfExtent(canopy, "Z"))
	local ux, uz = cx + reach - 0.5, cz
	other = false
	for _, o in ipairs(colliders) do
		if dist(o.CFrame.Position.X, o.CFrame.Position.Z, ux, uz) <= o.Size.Y / 2 + T.margin then other = true end
	end
	if not other then
		check(not NS.treeBlocks(vec(ux, groundY + 1, uz)), "does not block under the canopy's edge")
	end
	reachOf[c] = reach
end
check(not NS.treeBlocks(vec(0, groundY + 1, 0)), "the middle of the road is not a trunk")

-- ---- THE HERD'S CORRIDORS AND KERB LEGS ---------------------------------
-- Every fixed leg of every route, sampled the way HerdService samples a path
-- (every `pathSample` studs, endpoints included) with the leader's own line
-- and a flank either side at `followSpacing` plus the jitter -- the pack is
-- three columns wide. A tree that stood on any of these has to have moved.
--
-- HERDS DROP IN FROM THE SKY NOW (designer, 2026-09-22) AND WALK NO FIXED
-- LEG AT ALL, so this is a claim about a route nothing takes. It is held
-- while `Config.herdRoute` is still standing and skipped once that function
-- is retired -- what replaces it is the BAND sweep below, which is the
-- ground a pack actually stands on. A guard rather than a deletion, because
-- a check that quietly stops running is worse than one that is not there.
local H = Config.HERDS
local flank = H.followSpacing + H.jitter
local corridorSamples = 0
for _, side in ipairs(if Config.herdRoute then { -1, 1 } else {}) do
	for _, entryEnd in ipairs({ -1, 1 }) do
		local route = Config.herdRoute(side, entryEnd, -entryEnd)
		for _, leg in ipairs({ route.enter, route.exit }) do
			for i = 1, #leg - 1 do
				local ax, az, bx, bz = leg[i][1], leg[i][2], leg[i + 1][1], leg[i + 1][2]
				local len = dist(ax, az, bx, bz)
				local n = math.max(1, math.ceil(len / H.pathSample))
				local px, pz = -(bz - az) / len, (bx - ax) / len
				for k = 0, n do
					local t = k / n
					local x, z = ax + (bx - ax) * t, az + (bz - az) * t
					for _, f in ipairs({ -flank, 0, flank }) do
						check(not NS.treeBlocks(vec(x + px * f, groundY + 1, z + pz * f)),
							("herd leg clear of every trunk at (%.1f, %.1f)"):format(x + px * f, z + pz * f))
						corridorSamples += 1
					end
				end
			end
		end
	end
end
check(corridorSamples > 300 or Config.herdRoute == nil,
	"the corridor and kerb legs were actually sampled: " .. corridorSamples)
-- The verge tree that stood on the corridor MOVED inward rather than the
-- route moving, and nothing else past the last plot was lost: two trees a
-- side past the end column, the second short of the corridor line.
local g = Config.herdGround()
local outer = Config.plotColumnX(Config.PLOTS_PER_ROW - 1)
for _, sx in ipairs({ -1, 1 }) do
	for _, sz in ipairs({ -1, 1 }) do
		local past = {}
		for _, c in ipairs(colliders) do
			local x, z = c.CFrame.Position.X, c.CFrame.Position.Z
			if x * sx > outer + 20 and math.abs(z) < 40 and z * sz > 0 then table.insert(past, math.abs(x)) end
		end
		table.sort(past)
		check(#past == 2, ("two verge trees stand past the last plot on each corner (%d)"):format(#past))
		check(math.abs(past[1] - (outer + 30)) < 1e-6, "the first where it always stood")
		check(past[2] < g.corridorX and past[2] > outer + 42, ("the second slid inward off the herd corridor to %.1f"):format(past[2]))
		check(past[2] > past[1] + 12, "and the two are still two trees")
	end
end

-- ---- PLAYER SAFETY ------------------------------------------------------
-- Nothing anybody is stood at or dropped onto is inside a collider: every
-- yard (join spawn, arrest release and the house-door exit all land inside a
-- fence), every bin hatch and its four-and-a-half-stud exit, every shop
-- forecourt and both boards' legs.
local m = Config.streetMetrics()
local yardNear, yardFar = m.fenceLine, Config.STREET_SPACING / 2 + Config.YARD_DEPTH
for _, c in ipairs(colliders) do
	local x, z, r = c.CFrame.Position.X, c.CFrame.Position.Z, c.Size.Y / 2
	for col = 0, Config.PLOTS_PER_ROW - 1 do
		local cx = Config.plotColumnX(col)
		local dx = math.max(0, math.abs(x - cx) - Config.PLOT_HALF_WIDTH)
		local dz = math.max(0, yardNear - math.abs(z), math.abs(z) - yardFar)
		check(math.sqrt(dx * dx + dz * dz) >= r + T.margin, ("a trunk stands clear of every yard (col %d)"):format(col))
	end
end
local function clearOfAll(px, pz, keep, what)
	for _, c in ipairs(colliders) do
		check(dist(c.CFrame.Position.X, c.CFrame.Position.Z, px, pz) >= c.Size.Y / 2 + keep,
			("%s at (%.1f, %.1f) is clear of every trunk"):format(what, px, pz))
	end
end
local perRow = Config.PLOTS_PER_ROW
local function gapX(col) return (Config.plotColumnX(col) + Config.plotColumnX(col + 1)) / 2 end
for _, side in ipairs({ -1, 1 }) do
	for col = 0, perRow - 2 do
		-- The hatch, and the 4.5-stud exit in any direction, plus a body.
		clearOfAll(gapX(col) + 5, side * (m.roadHalfWidth + 1.8), 4.5 + 1.5, "bin hatch")
	end
	for _, placement in ipairs(Config.SHOPS) do
		-- A forecourt runs from the unit's edge to the pavement; a character on
		-- its corner is a stud and a half of body from the paving's edge.
		for _, dx in ipairs({ -11, 0, 11 }) do
			for _, dz in ipairs({ -14, 0, 14 }) do
				clearOfAll(gapX(placement.gap) + dx, side * (m.shopZ + dz), 1.5, "shop forecourt")
			end
		end
	end
	-- The boards stand in the nearest free gap, as SocialService chooses it.
	local taken = {}
	for _, placement in ipairs(Config.SHOPS) do taken[placement.gap] = true end
	local boardX
	for gap = 0, perRow - 2 do
		if not taken[gap] then
			local x = gapX(gap)
			if boardX == nil or math.abs(x) < math.abs(boardX) then boardX = x end
		end
	end
	check(boardX ~= nil, "the boards have a gap")
	for _, dx in ipairs({ -15, -9.6, -5.12, 0, 5.12, 9.6, 15 }) do
		clearOfAll(boardX + dx, side * m.boardZ, 1.5, "board")
	end
end

-- ---- DETERMINISM --------------------------------------------------------
local function fingerprint(list)
	local out = {}
	for _, p in ipairs(list) do
		local c = p.CFrame.Position
		table.insert(out, ("%.4f,%.4f,%.4f|%.4f,%.4f,%.4f"):format(p.Size.X, p.Size.Y, p.Size.Z, c.X, c.Y, c.Z))
	end
	table.sort(out)
	return table.concat(out, ";")
end
local world2 = Instance.new("Folder")
NS.plantTrees(world2)
local colliders2 = partsNamed(world2, T.colliderName)
check(#colliders2 == #colliders, "a second plant stands the same number of colliders")
check(fingerprint(colliders2) == fingerprint(colliders), "and they are identical part for part")
check(#NS.trunkColliders() == #colliders, "and the footprints were reset rather than doubled")

-- ---- THE MEASURED ROUTE: A SceneryTrees MODEL --------------------------
-- When the template library is present, SceneryTrees stands a Model and the
-- collider is MEASURED off it: the bole is the lowest non-foliage part, the
-- top is the lowest foliage part's underside. A stand-in library with a
-- 2-wide trunk and a crown starting 7 up says so.
do
	local built = 0
	local scenery = { build = function(x, z, seed, scale, gy, parent)
		local model = Instance.new("Model")
		model.Name = "SceneryTree"
		model:SetAttribute("PlacementSeed", seed)
		local trunk = Instance.new("MeshPart"); trunk.Name = "Trunk"
		trunk.Size = vec(2, 10, 2); trunk.CFrame = CFrame.new(x, gy + 5, z) * CFrame.Angles(0, seed, 0)
		trunk.Parent = model
		local leaf = Instance.new("MeshPart"); leaf.Name = "Foliage_Crown"
		leaf.Size = vec(10, 6, 10); leaf.CFrame = CFrame.new(x, gy + 10, z)
		leaf.Parent = model
		model.Parent = parent
		built += 1
		return true
	end }
	local NS2 = loadNeighborhood(scenery)
	local w = Instance.new("Folder")
	NS2.plantTrees(w)
	local cs = partsNamed(w, T.colliderName)
	check(built == #colliders and #cs == built, ("the model route stands one collider per model (%d of %d)"):format(#cs, built))
	for _, c in ipairs(cs) do
		check(math.abs(c.Size.Y / 2 - 1.0 * T.boleFraction) < 1e-6, "the measured bole is the model's own trunk footprint times the fraction")
		local crown = groundY + math.max(7, Config.jumpReach() + T.jumpMargin)
		check(math.abs((c.CFrame.Position.Y + c.Size.X / 2) - crown) < 1e-6, "and its top is the crown's underside, or the jump floor if that is higher")
	end
end

-- ---- THE FALLBACK ROUTE: THE BOX-AND-BALL TREE --------------------------
-- No mesh ids: the box tree stands, and its 1.6-wide trunk IS the bole.
do
	local boxConfig = setmetatable({ treeMesh = function() return nil end }, { __index = Config })
	local NS3 = loadNeighborhood(nil, boxConfig)
	local w = Instance.new("Folder")
	NS3.plantTrees(w)
	local cs, ts = partsNamed(w, T.colliderName), partsNamed(w, "Trunk")
	check(#cs == #ts and #ts > 40, ("the box route stands one collider per tree (%d)"):format(#cs))
	for _, c in ipairs(cs) do
		check(math.abs(c.Size.Y / 2 - 0.8) < 1e-9, "a box trunk's collider is its own half width")
		local trunk = nearest(ts, c.CFrame.Position.X, c.CFrame.Position.Z)
		local top = c.CFrame.Position.Y + c.Size.X / 2
		check(top <= math.max(trunk.CFrame.Position.Y + trunk.Size.Y / 2, groundY + Config.jumpReach() + T.jumpMargin) + 1e-6,
			"and stops at the trunk's top, or the jump floor if that is higher")
	end
end

-- ---- THE JUMP FLOOR CAN FAIL ---------------------------------------------
-- Proved to fire rather than trusted: with the margin driven negative on a
-- copy of the table, the verge colliders fall back to their canopy underside
-- (4.9 on a scale-1 tree) and the check above would refuse them -- which is
-- the live walk that found this, a character on top of a trunk at y 8.6.
do
	local lowTrees = {}
	for k, v in pairs(T) do lowTrees[k] = v end
	lowTrees.jumpMargin = -3
	local lowConfig = setmetatable({ TREES = lowTrees }, { __index = meshConfig(Config) })
	local NS4 = loadNeighborhood(nil, lowConfig)
	local w = Instance.new("Folder")
	NS4.plantTrees(w)
	local under = 0
	for _, c in ipairs(partsNamed(w, T.colliderName)) do
		if c.CFrame.Position.Y + c.Size.X / 2 < groundY + Config.jumpReach() + T.jumpMargin - 1e-6 then under += 1 end
	end
	check(under >= 8, "with the margin removed the verge trunks drop under a jump, so the floor check has teeth: " .. under)
end

-- ---- THE WIRING ---------------------------------------------------------
-- Main registers the veto with the herd: a veto nobody wires is a trunk the
-- pack walks through. And the builder still records the grove for the
-- grassland exactly as before -- this lane added beside it, never over it.
check(SOURCES.Main:find("HerdService.addGroundVeto(NeighborhoodService.treeBlocks)", 1, true) ~= nil,
	"Main registers the trunk veto with the herd")
check(SOURCES.NeighborhoodService:find("table.insert(grovePlacements, { x = x, z = side * (rear + depth), reach = reach })", 1, true) ~= nil,
	"the grassland's placements are still recorded")
-- Two loads ran the real SceneryTrees against an empty ServerStorage, and each
-- said so once -- the live fallback's own warning, and nothing else spoke.
for _, w in ipairs(warnings) do
	check(w:find("[SceneryTrees] scenery templates unavailable", 1, true) ~= nil, "the only warning is the library fallback: " .. w)
end
check(#warnings == 3, "one library warning per real SceneryTrees load: " .. #warnings)

print(("trees: %d checks passed (%d trees, %d colliders, %d herd samples)"):format(checks, #trunks, #colliders, corridorSamples))
