--!strict
--[[
	LassoModel -- the four lasso props: the coil in the hand, the capture loop
	that closes round a piggy, the snapped rope end a miss leaves behind, and
	the daze star that orbits a dropped piggy's head (docs/LASSO-PLAN.md
	section 6; the source art and its manifests are in assets/lassos).

	AN EMPTY ID IS A WORKING STATE. Every row of `Config.LASSO_MESH` is empty
	today, and each builder then draws a primitive version of the same prop at
	the same size and with the same origin as the exported mesh -- so the
	feature ships before the upload, and each piece starts using its mesh the
	moment its id lands, with nothing that places it having to change.

	PREWARMED AND CLONED, NEVER BUILT ON DEMAND, the call `LootMesh`,
	`CoinModel` and `PiggyModel` already make. `CreateMeshPartAsync` yields and
	is refused on a client, while `buildCoil` is called from shop cards and hot
	bar icons that must never stall. So the server loads each mesh once into a
	folder in ReplicatedStorage (`LassoModel.prewarm`, called from `Main`) and
	both ends clone. A folder that is absent is read as "not warmed", and the
	primitives stand in.

	THE ORIGINS ARE THE MANIFEST'S, NOT THE IMPORTER'S. Studio recentres a
	MeshPart on its own bounds, while the art is authored around a named point
	-- the coil's assembled centre, the loop's OPENING centre (not its
	knot-inclusive bounds), the snapped end's shaft midpoint, the star's radial
	centre. `MESH_ROWS` carries each part's bounds centre in that frame, read
	from assets/lassos/validation.json and converted to Roblox axes
	(x, z, -y), so a clone is seated where the art says it goes.

	TIER LOOKS ARE TEXTURES ON SHARED GEOMETRY (designer, 2026-09-23). With a
	texture id the part is white so the map is not multiplied darker; without
	one the part is tinted from the tier's `colour` and `trim`.

	Every part is anchored, massless and non-colliding, answers no query and
	casts no shadow. `HeldItem.attach` unanchors the coil in the same pass that
	welds it, which is the only place any of this is ever welded to anybody.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent:WaitForChild("Config"))

local LassoModel = {}

LassoModel.FOLDER = "LassoMeshTemplates"

-- The attachment points recorded in the manifests, in each model's own
-- frame at scale 1. Exported so the client can seat a Beam and a hand grip
-- without reading the model: a point stays right however the model is drawn.
LassoModel.COIL_HAND_GRIP = Vector3.new(0.0475, 0.97, 0)
LassoModel.COIL_ROPE_EXIT = Vector3.new(0.3675, -1.375, 0)
LassoModel.LOOP_ROPE_EXIT = Vector3.new(1.33, 0, 0)
-- The loop's clear opening, the number a piggy's girth is divided by.
LassoModel.LOOP_INNER_DIAMETER = 1.46
LassoModel.SNAPPED_INTACT_END = Vector3.new(-0.47, 0, 0)
LassoModel.SNAPPED_BREAK_ROOT = Vector3.new(0.44, 0, 0)
-- The rope's thickness in the coil, which the Beam's width is matched to.
LassoModel.ROPE_WIDTH = 0.176

local STAR_YELLOW = Color3.fromRGB(255, 218, 54)
local DEFAULT_ROPE = Color3.fromRGB(214, 176, 120)
local DEFAULT_TRIM = Color3.fromRGB(110, 70, 44)

type Row = { size: Vector3, offset: Vector3, rot: CFrame? }

-- Bounds per exported part, Roblox axes. EVERY ROW CARRIES A HALF TURN, and
-- that was measured on the 2026-09-23 import rather than assumed: the Studio
-- 3D Importer handed every part back with its X and Z offsets negated
-- against these (Grip at x -0.0475, the loop's knot side at -0.19, the
-- snapped end at -0.18), which is a half turn about Y -- the same one
-- `Config.LOOT_MESH` records for the bag. Turning each mesh by it puts the
-- geometry back in the frame the attachment constants below were solved in.
local HALF_TURN = CFrame.Angles(0, math.pi, 0)
local MESH_ROWS: { [string]: Row } = {
	Rope = { size = Vector3.new(2.1673, 2.7137, 0.1760), offset = Vector3.new(0, -0.0182, 0), rot = HALF_TURN },
	Grip = { size = Vector3.new(0.3700, 0.8100, 0.2550), offset = Vector3.new(0.0475, 0.9700, 0), rot = HALF_TURN },
	Loop = { size = Vector3.new(2.2746, 0.4340, 1.8892), offset = Vector3.new(0.1927, 0, 0), rot = HALF_TURN },
	SnappedEnd = { size = Vector3.new(1.2914, 0.4227, 0.4017), offset = Vector3.new(0.1757, 0.0100, 0.0002), rot = HALF_TURN },
	Star = { size = Vector3.new(0.9330, 0.8873, 0.2000), offset = Vector3.new(0, 0.0468, 0), rot = HALF_TURN },
}

-- ============================================================
-- IDS AND COLOURS
-- ============================================================

local function uri(id: any): string?
	if type(id) ~= "string" or id == "" then
		return nil
	end
	return if id:match("^%d+$") then "rbxassetid://" .. id else id
end

local function specOf(key: string?): any
	return key and Config.LASSOS[key] or nil
end

function LassoModel.ropeColour(key: string?): Color3
	local spec = specOf(key)
	return (spec and spec.colour) or DEFAULT_ROPE
end

local function trimColour(key: string?): Color3
	local spec = specOf(key)
	return (spec and spec.trim) or DEFAULT_TRIM
end

local function textureFor(key: string?): string?
	local spec = specOf(key)
	local textures = Config.LASSO_MESH and Config.LASSO_MESH.textures
	if not (spec and spec.texture and textures) then
		return nil
	end
	return uri(textures[spec.texture])
end

-- ============================================================
-- PREWARM (server only)
-- ============================================================

local tried = false
local warned = false

local function templates(): Folder?
	local folder = ReplicatedStorage:FindFirstChild(LassoModel.FOLDER)
	return if folder and folder:IsA("Folder") then folder else nil
end

--[[
	Load every lasso mesh that has an id, once, into a folder the builders
	clone from. Server only and safe to call repeatedly. EACH ROW IS PCALLED
	ON ITS OWN, so a moderated star costs the star and nothing else -- but the
	coil is judged as a PAIR in `buildCoil`, because a mesh rope with a
	primitive grip is two art styles on one prop.

	Nothing is parented until the folder is full, and a load that finds no
	ids at all makes no folder: the absence is the "use primitives" signal.
]]
function LassoModel.prewarm(): boolean
	if tried or not RunService:IsServer() then
		return templates() ~= nil
	end
	tried = true

	local mesh = Config.LASSO_MESH
	if type(mesh) ~= "table" then
		return false
	end

	local folder = Instance.new("Folder")
	folder.Name = LassoModel.FOLDER
	local made = 0
	local insert = game:GetService("InsertService")
	for name, row in pairs(MESH_ROWS) do
		local id = uri(mesh[name])
		if id then
			local ok, result: any = pcall(function()
				return insert:CreateMeshPartAsync(id, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Automatic)
			end)
			if ok and result then
				local p = result :: MeshPart
				p.Name = name
				p.Size = row.size
				p.Color = Color3.new(1, 1, 1)
				p.Material = Enum.Material.SmoothPlastic
				p.Anchored = true
				p.Massless = true
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				p.CastShadow = false
				p.Parent = folder
				made += 1
			elseif not warned then
				warned = true
				warn(("[LassoModel] the lasso '%s' mesh could not be loaded, so the "
					.. "primitive one is standing instead: %s"):format(name, tostring(result)))
			end
		end
	end

	if made == 0 then
		folder:Destroy()
		return false
	end
	folder.Parent = ReplicatedStorage
	return true
end

-- ============================================================
-- PRIMITIVES
-- ============================================================

local function newModel(name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	return model
end

local function finish(model: Model): Model
	model.WorldPivot = CFrame.identity
	return model
end

local function part(model: Model, name: string, shape: Enum.PartType, size: Vector3, cf: CFrame, colour: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = model
	return p
end

-- A length of rope from `a` to `b`. A Roblox cylinder's axis is its X, so the
-- frame looks along the run and a quarter turn about Y lays X onto it -- the
-- turn this project has got wrong five times, written once here.
local function tube(model: Model, name: string, a: Vector3, b: Vector3, thick: number, colour: Color3): Part
	local run = b - a
	local mid = (a + b) / 2
	local up = if math.abs(run.Unit.Y) > 0.99 then Vector3.zAxis else Vector3.yAxis
	local cf = CFrame.lookAt(mid, b, up) * CFrame.Angles(0, math.pi / 2, 0)
	return part(model, name, Enum.PartType.Cylinder, Vector3.new(run.Magnitude, thick, thick), cf, colour)
end

-- A closed ring of `n` tubes along `point(t)`. Each piece is lengthened past
-- its chord so the joins overlap rather than leaving a notch on the outside.
local function ring(model: Model, name: string, n: number, thick: number, colour: Color3,
	point: (number) -> Vector3)
	for i = 0, n - 1 do
		local a = point(i / n * math.pi * 2)
		local b = point((i + 1) / n * math.pi * 2)
		local mid = (a + b) / 2
		local half = (b - a) * 0.56
		tube(model, name, mid - half, mid + half, thick, colour)
	end
end

-- A triangular point of the star, as two mirrored WedgeParts. A WedgePart is
-- full height at local +Z falling to nothing at -Z, extruded along X, so its
-- right angle sits at (-Y, +Z): that corner goes on the point's base centre,
-- local +Y runs to the tip and local -Z runs to the base corner.
local function starPoint(model: Model, angle: number, r0: number, r1: number, halfBase: number,
	thick: number, colour: Color3)
	local u = Vector3.new(math.cos(angle), math.sin(angle), 0)
	local perp = Vector3.new(-u.Y, u.X, 0)
	local base = u * r0
	local length = r1 - r0
	for _, side in ipairs({ 1, -1 }) do
		local v = perp * side
		local zAxis = -v
		local xAxis = u:Cross(zAxis)
		local centre = base + u * (length / 2) + v * (halfBase / 2)
		local p = Instance.new("WedgePart")
		p.Name = "Star"
		p.Size = Vector3.new(thick, length, halfBase)
		p.CFrame = CFrame.fromMatrix(centre, xAxis, u, zAxis)
		p.Color = colour
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Anchored = true
		p.Massless = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = model
	end
end

-- ============================================================
-- MESH CLONES
-- ============================================================

local function cloneMesh(model: Model, name: string, key: string?, colour: Color3): BasePart?
	local folder = templates()
	local template = folder and folder:FindFirstChild(name)
	local row = MESH_ROWS[name]
	if not (template and template:IsA("BasePart") and row) then
		return nil
	end
	local p = (template :: BasePart):Clone()
	p.Name = name
	p.Size = row.size
	p.CFrame = CFrame.new(row.offset) * (row.rot or CFrame.identity)
	local texture = if key then textureFor(key) else nil
	if texture and p:IsA("MeshPart") then
		p.TextureID = texture
		p.Color = Color3.new(1, 1, 1)
	else
		p.Color = colour
	end
	p.Parent = model
	return p
end

local function hasTemplate(name: string): boolean
	local folder = templates()
	return folder ~= nil and folder:FindFirstChild(name) ~= nil
end

-- ============================================================
-- BUILDERS
-- ============================================================

--[[
	The coil a player holds, at the manifest's size (2.17 wide, 2.75 tall,
	flat on Z) with its origin at the assembled centre. Two meshes, `Rope` and
	`Grip`; the primitive version is several parts carrying those two names,
	so anything that recolours by name still finds both halves.

	CHEAP BY DESIGN: it is on every shop card and hot bar tile. About fifty
	parts on the primitive path, two on the mesh path, and it never yields.
]]
function LassoModel.buildCoil(key: string): Model
	local model = newModel("LassoCoil")
	local rope = LassoModel.ropeColour(key)
	local trim = trimColour(key)

	if hasTemplate("Rope") and hasTemplate("Grip") then
		cloneMesh(model, "Rope", key, rope)
		cloneMesh(model, "Grip", key, trim)
		return finish(model)
	end

	-- Four nested turns, slightly taller than wide, centred a little above
	-- the origin so the outer turn's crown meets the manifest's top (1.34)
	-- and the open centre is about a third of the width.
	local thick = LassoModel.ROPE_WIDTH
	local cy = 0.09
	for k = 0, 3 do
		local a = 0.995 - k * 0.19
		local b = 1.16 - k * 0.19
		ring(model, "Rope", 12, thick, rope, function(t: number): Vector3
			return Vector3.new(a * math.cos(t), cy + b * math.sin(t), 0)
		end)
	end
	-- The outer turn bends down into a short straight tail ending at
	-- RopeExit, with a blunt rounded end.
	local from = Vector3.new(0.30, -1.0, 0)
	tube(model, "Rope", from, LassoModel.COIL_ROPE_EXIT, thick, rope)
	part(model, "Rope", Enum.PartType.Ball, Vector3.new(thick, thick, thick),
		CFrame.new(LassoModel.COIL_ROPE_EXIT), rope)

	-- The leather band across the crown, exactly the Grip mesh's bounds.
	-- Deeper on Z than the rope (0.255 against 0.176) so it stands proud of
	-- the turns it binds rather than sharing a face with them.
	part(model, "Grip", Enum.PartType.Block, MESH_ROWS.Grip.size, CFrame.new(MESH_ROWS.Grip.offset), trim)
	-- Two thin collars in the rope colour read as the band's stitched ends at
	-- thumbnail size, and stand 0.01 proud of it on every face.
	for _, y in ipairs({ 0.60, 1.34 }) do
		part(model, "Grip", Enum.PartType.Block, Vector3.new(0.39, 0.05, 0.275),
			CFrame.new(0.0475, y, 0), trim:Lerp(rope, 0.55))
	end
	return finish(model)
end

--[[
	The open capture loop, flat in XZ with its origin at the centre of the
	OPENING (clear diameter `LOOP_INNER_DIAMETER`), the knot and stub on +X
	ending at `LOOP_ROPE_EXIT`. Scale it by (girth + clearance) / 1.46.
]]
function LassoModel.buildLoop(key: string): Model
	local model = newModel("LassoLoop")
	local rope = LassoModel.ropeColour(key)
	if cloneMesh(model, "Loop", key, rope) then
		return finish(model)
	end
	-- Inner diameter 1.46 and outer 1.90: a 0.22 rope on a 0.84 centreline.
	local thick = 0.22
	ring(model, "Loop", 16, thick, rope, function(t: number): Vector3
		return Vector3.new(0.84 * math.cos(t), 0, 0.84 * math.sin(t))
	end)
	part(model, "Loop", Enum.PartType.Ball, Vector3.new(0.42, 0.42, 0.42), CFrame.new(0.98, 0, 0), rope)
	tube(model, "Loop", Vector3.new(1.08, 0, 0), LassoModel.LOOP_ROPE_EXIT, 0.2, rope)
	return finish(model)
end

--[[
	One frayed rope end: the shaft on X from the blunt intact end at -0.47 to
	the break at +0.44, splitting into four short lobes towards +X. Built
	twice for a miss, one turned round.
]]
function LassoModel.buildSnappedEnd(key: string): Model
	local model = newModel("LassoSnappedEnd")
	local rope = LassoModel.ropeColour(key)
	if cloneMesh(model, "SnappedEnd", key, rope) then
		return finish(model)
	end
	local thick = 0.17
	tube(model, "SnappedEnd", LassoModel.SNAPPED_INTACT_END, LassoModel.SNAPPED_BREAK_ROOT, thick, rope)
	part(model, "SnappedEnd", Enum.PartType.Ball, Vector3.new(thick, thick, thick),
		CFrame.new(LassoModel.SNAPPED_INTACT_END), rope)
	local root = LassoModel.SNAPPED_BREAK_ROOT - Vector3.new(0.04, 0, 0)
	for _, d in ipairs({ Vector3.new(1, 0.4, 0.4), Vector3.new(1, -0.4, 0.4),
		Vector3.new(1, 0.4, -0.4), Vector3.new(1, -0.4, -0.4) }) do
		local tip = root + d.Unit * 0.40
		tube(model, "SnappedEnd", root, tip, 0.09, rope)
		part(model, "SnappedEnd", Enum.PartType.Ball, Vector3.new(0.09, 0.09, 0.09), CFrame.new(tip), rope)
	end
	return finish(model)
end

--[[
	One chunky five-pointed daze star, upright with a point at +Y and its
	broad faces on +/-Z, centred on its radial centre. Always lemon yellow.
]]
function LassoModel.buildStar(): Model
	local model = newModel("LassoStar")
	if cloneMesh(model, "Star", nil, STAR_YELLOW) then
		return finish(model)
	end
	-- Each point's base sits inside the hub, and at the hub's rim a point is
	-- 27 degrees either side of its axis against 36 to its neighbour, so no
	-- two points' faces overlap outside the hub and fight each other.
	for k = 0, 4 do
		starPoint(model, math.pi / 2 + k * math.pi * 2 / 5, 0.12, 0.47, 0.13, 0.2, STAR_YELLOW)
	end
	-- The hub is a disc 0.02 deeper than the points, so its faces stand proud
	-- of theirs where they overlap rather than fighting them.
	part(model, "Star", Enum.PartType.Cylinder, Vector3.new(0.22, 0.4, 0.4),
		CFrame.Angles(0, math.pi / 2, 0), STAR_YELLOW)
	return finish(model)
end

return LassoModel
