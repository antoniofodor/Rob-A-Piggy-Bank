--!strict
--[[
	NeighborhoodService

	The suburb the plots sit in: road, sidewalks, driveways, street furniture
	and the woodland that closes off the view behind the plots.

	None of it is interactive. Every part built here is CanCollide false,
	CanQuery false and CastShadow false -- it exists to make the street read
	as a place rather than twelve lawns in a field, and it must never get in
	the way of a chase or eat a raycast meant for a piggy.

	Three things here are exceptions and all three are deliberate. The road
	surface is walked on, and sits a few hundredths of a stud proud of the
	grass rather than flush with it -- see the LIFT_ constants for why flush
	is not an option. The VALLEY WALL is solid because a hill you can walk
	through is a hole in the map. And the LOWLAND APRON out past it is solid
	so that anybody who somehow gets over the wall lands on ground rather
	than falling out of the world.

	Everything is positioned off Config, so moving the plots moves the suburb
	with them. Nothing here hardcodes a plot coordinate.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local Decor = require(ReplicatedStorage.Shared.Decor)
local ShopFront = require(ReplicatedStorage.Shared.ShopFront)
local PiggyModel = require(ReplicatedStorage.Shared.PiggyModel)
local RideModel = require(ReplicatedStorage.Shared.RideModel)
local BoneModel = require(ReplicatedStorage.Shared.BoneModel)
local GrassTuft = require(ReplicatedStorage.Shared.GrassTuft)
local Grassland = require(ReplicatedStorage.Shared.Grassland)
local SceneryTrees = require(script.Parent.SceneryTrees)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
-- THE COMBINE MACHINE (designer, 2026-09-23) stands on this verge, and two
-- things built here have to keep off it: the grass and the verge trees. Only
-- the PURE half of that module is read -- where it stands and how big it is
-- -- so neither service has to run before the other. `CombineService` builds
-- the model itself and owns its prompt.
local CombineStation = require(ReplicatedStorage.Shared.CombineStation)

local NeighborhoodService = {}

-- Ground top. The plot slabs are centred on y=0 and one stud thick, so the
-- world outside them sits half a stud lower.
local GROUND_Y = -Config.PLOT_SIZE.Y / 2

local ROAD = Color3.fromRGB(74, 74, 82)
local ROAD_LINE = Color3.fromRGB(226, 206, 120)
local KERB = Color3.fromRGB(198, 196, 188)
local TRUNK = Color3.fromRGB(96, 68, 48)
local LEAF = Color3.fromRGB(84, 132, 66)
local LEAF_2 = Color3.fromRGB(102, 150, 78)

-- The two shades of canopy, as a MULTIPLY rather than as a colour.
--
-- The ball canopy took LEAF and LEAF_2 outright. A MeshPart multiplies its
-- Color against the texture it carries, so the meshed tree gets the same two
-- shades as a near-white tint instead: white is the map as painted, and the
-- second is a gentle darkening. Handed LEAF itself the canopy loses the baked
-- shading between its leaf clumps, which is the only thing making it read as
-- clumps at all. See the note over `Config.TREE_MESH`.
local CANOPY_TINT = Color3.fromRGB(255, 255, 255)
local CANOPY_TINT_2 = Color3.fromRGB(214, 234, 198)

-- The painted lawn surface, built by WorldService before this service runs.
-- Named rather than asked for: a dangling MaterialVariant falls back to the
-- BaseMaterial, so a name that did not build renders as the stock grass that
-- shipped before it existed.
local LAWN_VARIANT = Config.GRASS_MATERIAL.name

-- How much daylight a canopy has to leave between itself and a back fence.
local CANOPY_CLEARANCE = 1.5

-- Flat overlays must sit ABOVE the ground, never flush with it.
--
-- A part whose top face is exactly coplanar with the grass z-fights: two
-- surfaces at the same depth give the renderer nothing to sort by, so it
-- picks per pixel and per camera angle and the grass flickers through the
-- asphalt. Each overlay gets its own lift, which both clears the ground and
-- puts the layers in a defined order -- road, then its markings, then the
-- kerb, then the driveway crossing over the kerb like a real dropped kerb.
--
-- The largest of these is 0.22 studs. A character steps over that without
-- any change to how it walks, so nothing here can catch a fleeing thief.
local LIFT_ROAD = 0.06
local LIFT_LINE = 0.12
local LIFT_KERB = 0.16
local LIFT_DRIVE = 0.22

local folder: Folder

local function scenery(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder
	return p
end

-- Lays a flat surface whose TOP face lands at exactly GROUND_Y + lift,
-- regardless of how thick the slab is. Thickness only exists so the part has
-- volume; it is buried in the ground and never seen.
local function pave(name: string, width: number, depth: number, x: number, z: number,
	lift: number, color: Color3, material: Enum.Material): Part
	local thickness = 0.8
	return scenery(name, Vector3.new(width, thickness, depth),
		CFrame.new(x, GROUND_Y + lift - thickness / 2, z), color, material)
end

-- ============================================================
-- LAYOUT MATHS
-- ============================================================

-- Everything below is derived, so the suburb follows the plots if the grid
-- ever changes shape.
local function metrics()
	-- Every number here comes from Config.streetMetrics, which is the single
	-- source. This file used to keep its own copy of the arithmetic and the two
	-- drifted -- and the plaza and road extents have now moved there too,
	-- because RideService needs to know where the street is in order to keep
	-- vehicles on it, and a third copy would drift the same way.
	local street = Config.streetMetrics()

	return {
		perRow = Config.PLOTS_PER_ROW,
		halfPlot = Config.PLOT_SIZE.X / 2,
		endX = street.endX,
		rowZ = Config.STREET_SPACING / 2,

		-- Fixed carriageway; everything between it and the fence is verge and
		-- driveway, which is where the extra street width goes.
		roadHalfWidth = street.roadHalfWidth,
		vergeOuter = street.fenceLine,

		boardZ = street.boardZ,
		shopZ = street.shopZ,
		roadStartX = street.roadStartX,
		roadEndX = street.roadEndX,

		-- The hillsides at each end, and the bore through them.
		tunnelEastX = street.tunnelEastX,
		tunnelWestX = street.tunnelWestX,
		tunnelDepth = street.tunnelDepth,
		tunnelHalfWidth = street.tunnelHalfWidth,
		tunnelHeight = street.tunnelHeight,
	}
end

local function columnX(m: any, col: number): number
	return Config.plotColumnX(col)
end

-- The gap between two frontages, which is where everything that is not a
-- driveway goes. The row is continuous again, so a plot column IS a slot and
-- this is simply the midpoint of two neighbours -- there is no hole to step
-- over any more.
local function gapX(col: number): number
	return (Config.plotColumnX(col) + Config.plotColumnX(col + 1)) / 2
end

-- ============================================================
-- PIECES
-- ============================================================

local function buildRoad(m: any)
	local length = m.roadEndX - m.roadStartX
	local centreX = (m.roadStartX + m.roadEndX) / 2

	pave("Road", length, m.roadHalfWidth * 2, centreX, 0, LIFT_ROAD, ROAD, Enum.Material.Asphalt)

	for _, side in ipairs({ -1, 1 }) do
		pave("Kerb", length, 1.6, centreX, side * m.roadHalfWidth, LIFT_KERB,
			KERB, Enum.Material.Concrete)
	end

	-- Centre line, dashed, starting clear of the cul-de-sac lip.
	local dash = 7
	local gap = 9
	local x = m.roadStartX + 5
	while x < m.roadEndX - dash do
		pave("RoadLine", dash, 0.7, x + dash / 2, 0, LIFT_LINE, ROAD_LINE, Enum.Material.SmoothPlastic)
		x += dash + gap
	end
end

-- Driveways are NOT built here any more.
--
-- Each plot lays its own, surfaced according to the owner's house tier, so a
-- generic concrete strip per column would sit on top of it. See
-- PlotService.setHouseLevel.

-- ============================================================
-- THE GROVE
-- ============================================================
--
-- Twenty-six trees close the view behind the plots, which makes them the
-- largest thing in anybody's picture of this street after the grass itself.
-- What shipped was a brown box with a green ball balanced on top of it:
-- correct from a plan view, and a lollipop from the pavement.

local treeTemplates: { [string]: BasePart }? = nil
local treeChecked = false

-- Built ONCE and cloned per tree, because `CreateMeshPartAsync` yields and a
-- web call inside a build loop is twenty-six web calls to say one thing. The
-- same shape as `PiggyBank.ensureMeshTemplates` and `PlayerGear.prewarm`.
--
-- AND THE TEXTURE IS APPLIED HERE, BECAUSE THAT CALL DOES NOT CARRY ONE. It
-- takes a mesh id and returns an untextured part however the asset was
-- authored, which is how the first build of this shipped flat canopies with
-- nothing in the log to say so -- the failure was that the trees looked
-- worse, which is the quietest kind this file records. Inside a pcall,
-- because `MeshPart.MeshId` is capability-gated from a real Script and its
-- neighbour is a reasonable thing to expect the same of.
--
-- `RenderFidelity` IS `Automatic` HERE, WHICH IS THE OPPOSITE OF THE PIGGY'S
-- AND IS THE POINT RATHER THAN AN OVERSIGHT. The pig is `Precise` because it
-- is read from the pavement and is the one object a robbery is about, so
-- shedding its triangles with distance would show. A tree is backdrop and
-- there are a hundred of them, and shedding triangles with distance is
-- exactly what you want from a hundred backdrop objects.
local function ensureTreeTemplates(): { [string]: BasePart }?
	if treeChecked then
		return treeTemplates
	end
	treeChecked = true

	local spec = Config.treeMesh()
	if not spec then
		return nil
	end

	local ok, result = pcall(function()
		local insert = game:GetService("InsertService")
		local made: { [string]: BasePart } = {}
		for _, entry in ipairs(spec.parts) do
			local part = insert:CreateMeshPartAsync(entry.id,
				Enum.CollisionFidelity.Box, Enum.RenderFidelity.Automatic)
			if entry.texture then
				part.TextureID = entry.texture
			end
			made[entry.part] = part
		end
		return made
	end)

	if not ok then
		-- NEVER FAIL SILENTLY. A grove that quietly stayed as lollipops after
		-- somebody pasted two ids is indistinguishable from ids that did not
		-- take.
		warn(("[NeighborhoodService] the tree mesh could not be loaded, so the "
			.. "box-and-ball trees are standing instead: %s"):format(tostring(result)))
		return nil
	end

	treeTemplates = result
	return treeTemplates
end

local function treeScale(spec: any, seed: number): number
	return spec.scales[(seed % #spec.scales) + 1]
end

-- The furthest a canopy can reach horizontally from its own trunk, at any yaw.
--
-- THE DIAGONAL, NOT THE DEPTH, because every tree is turned on its own axis
-- for variety: a canopy twelve studs wide by ten and a half deep presents its
-- CORNER at forty-five degrees, which is eight studs rather than five. Taking
-- the depth alone gives a clearance that happens to be right for the trees
-- facing the street and wrong for the ones that are not, which is an
-- asymmetry no screenshot catches. Exactly the tube man that broke the side
-- fence on the four left-hand lawn slots and not the four right-hand ones.
local function canopyReach(spec: any, scale: number): number
	return math.sqrt(spec.width ^ 2 + spec.canopyDepth ^ 2) / 2 * scale
end

-- ============================================================
-- TRUNK COLLIDERS
-- ============================================================
--
-- EVERY TREE STOPS A CHARACTER AT ITS TRUNK, WHICH REVERSES THE RULE AT THE
-- TOP OF THIS FILE AND THE ONE CLAUDE.md RECORDS AS "hills are the only
-- scenery in NeighborhoodService that collides". Designer decision,
-- 2026-09-21: "make the trees around the map real impassable trees so
-- players and the piggies have to walk around them". A tree you run through
-- is a painted backdrop; one that stops you is a place.
--
-- IT IS THE FENCE'S OWN SPLIT, ONE OBJECT ALONG. Nothing VISIBLE collides:
-- the trunk mesh, the canopy and every SceneryTrees part stay CanCollide
-- false exactly as they were, and the collision lives on ONE invisible
-- cylinder standing where the bole is. So a tree can be re-meshed, re-scaled
-- or re-themed without the walk changing -- which is exactly what the fence
-- bought by putting all its collision on one invisible slab.
--
-- TRUNK ONLY, NEVER THE CANOPY. A player must be able to walk under the
-- leaves, so the collider is as wide as the BOLE rather than the crown and
-- nothing about the canopy collides.
--
-- AND IT IS TALLER THAN A JUMP, WHICH THE FIRST BUILD WAS NOT. It stopped at
-- the canopy's underside -- 4.9 studs on a verge tree -- on the argument that
-- an invisible wall in the air above a trunk must never be built. Walked
-- live with the client's default `AutoJumpEnabled` (touch controls, most of
-- this audience), the character hit the verge trunk, its root rose to y 8.6
-- and it walked OFF THE TOP seven studs later: a 4.9 trunk is a STEP. The
-- number a barrier has to beat is `Config.jumpReach()`, the collision float
-- plus the jump height (6.14), read exactly as `auditFences` reads it -- so
-- the top is the HIGHER of the canopy underside and `jumpReach() +
-- Config.TREES.jumpMargin`. The column runs up into the leaves where it can
-- meet nothing a player can reach: it is one bole wide and the canopy has
-- no collision, so the only character who can touch it up there is one
-- already standing on the trunk, which is exactly the case being closed.
--
-- CanQuery FALSE, DELIBERATELY. Collision does not need it, and a hundred
-- query-able cylinders would eat raycasts and prompts meant for piggies.
-- CanTouch false for the reason a fence panel carries it.
--
-- THE HERD READS THE SAME FOOTPRINTS. `NeighborhoodService.treeBlocks` is
-- registered with HerdService as a ground veto in Main, so a pack steers
-- round a trunk plus a piggy's own radius through the segment sampling it
-- already does for the ponds -- and NOT round a canopy, which would blanket
-- the whole band the herds wander.
export type TrunkFootprint = { x: number, z: number, radius: number }
local trunkColliders: { TrunkFootprint } = {}

-- The bole's radius from a trunk part's FOOTPRINT. A generated trunk part is
-- a bounding box carrying the root flare and the main limbs as well as the
-- bole -- 6.44 by 4.68 at scale 1 under a crown 12 wide -- so taking the box
-- as the trunk would build a wall as wide as a car. The bole is a FRACTION of
-- the smaller footprint axis (`Config.TREES.boleFraction`); the box-and-ball
-- fallback passes 1.0, because its trunk IS a bole.
local function boleRadius(footprintX: number, footprintZ: number, fraction: number): number
	return math.min(footprintX, footprintZ) / 2 * fraction
end

-- The generated tree's bole radius and canopy underside at `scale`, read off
-- `Config.TREE_MESH`'s own part table -- the same numbers `buildTree` sizes
-- and seats the mesh by, so the collider cannot drift from the picture. The
-- top is the LOWER of the canopy's underside and the trunk part's own top.
local function meshTrunkProfile(spec: any, scale: number, fraction: number): (number, number)
	local trunk, canopy
	for _, entry in ipairs(spec.parts) do
		if entry.part == "Trunk" then
			trunk = entry
		elseif entry.part == "Canopy" then
			canopy = entry
		end
	end
	if not (trunk and canopy) then
		-- The box tree's own bole, which needs no fraction.
		return 0.8, spec.height * scale * 0.5
	end
	local radius = boleRadius(trunk.size.X * scale, trunk.size.Z * scale, fraction)
	local top = math.min(canopy.offset.Y - canopy.size.Y / 2, trunk.offset.Y + trunk.size.Y / 2) * scale
	return radius, top
end

-- A part's world-space half extent along one axis, read per part through
-- its own CFrame: `Size.Y / 2` is wrong for anything turned, and a
-- SceneryTrees model is turned on its own axis for variety.
local function halfExtent(part: BasePart, axis: string): number
	local cf, s = part.CFrame, part.Size
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	return math.abs((r :: any)[axis]) * s.X / 2 + math.abs((u :: any)[axis]) * s.Y / 2
		+ math.abs((l :: any)[axis]) * s.Z / 2
end

-- A SceneryTrees model is MEASURED rather than assumed. The bole is the
-- non-foliage part standing lowest, and the top is the lowest foliage part's
-- underside -- so a species with a low crown gets a short collider and one
-- with a bare trunk gets a tall one, with nothing per species to remember.
-- The fallbacks are the generated tree's own profile, because SceneryTrees
-- fits every template to that envelope.
local function measureSceneryTree(model: Instance, fallbackRadius: number, fallbackTop: number): (number, number)
	local bole: BasePart? = nil
	local boleBottom = math.huge
	local leafBottom = math.huge
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			local bottom = p.CFrame.Position.Y - halfExtent(p, "Y")
			if string.find(string.lower(p.Name), "foliage", 1, true) then
				leafBottom = math.min(leafBottom, bottom)
			elseif bottom < boleBottom then
				boleBottom = bottom
				bole = p
			end
		end
	end
	if not bole then
		return fallbackRadius, fallbackTop
	end
	-- THE FOOTPRINT IS READ IN THE PART'S OWN FRAME, never off world axes: a
	-- turned box projects wider onto X and Z than it is, so a world-axis
	-- reading fattens every yawed trunk by up to root two. The vertical is
	-- whichever local axis stands closest to world Y; the other two are the
	-- footprint. The top and bottom ARE world-axis, because yaw cannot move Y.
	local cf, s = bole.CFrame, bole.Size
	local ry, uy, ly = math.abs(cf.RightVector.Y), math.abs(cf.UpVector.Y), math.abs(cf.LookVector.Y)
	local footX, footZ
	if ry >= uy and ry >= ly then
		footX, footZ = s.Y, s.Z
	elseif uy >= ly then
		footX, footZ = s.X, s.Z
	else
		footX, footZ = s.X, s.Y
	end
	local radius = boleRadius(footX, footZ, Config.TREES.boleFraction)
	local top = math.min(cf.Position.Y + halfExtent(bole, "Y"), leafBottom) - GROUND_Y
	if top <= 1 then
		return radius, fallbackTop
	end
	return radius, top
end

-- The model `SceneryTrees.build` just parented for `seed`, found by the
-- attribute it stamps rather than by position -- seeds are unique per tree.
local function sceneryTreeFor(seed: number): Instance?
	local kids = folder:GetChildren()
	for i = #kids, 1, -1 do
		local kid = kids[i]
		if kid.Name == "SceneryTree" and kid:GetAttribute("PlacementSeed") == seed then
			return kid
		end
	end
	return nil
end

local function plantTrunkCollider(x: number, z: number, radius: number, top: number)
	local t = Config.TREES
	-- Sunk `sink` into the ground so the base can never sit a hair proud of
	-- the grass as a lip somebody trips on. The top is the canopy's underside
	-- or a jump and a margin above the ground, whichever is HIGHER -- see the
	-- section note: a trunk a character can hop onto is a step, not a wall.
	top = math.max(top, Config.jumpReach() + t.jumpMargin)
	local height = top + t.sink
	local part = Instance.new("Part")
	part.Name = t.colliderName
	-- A ROBLOX CYLINDER'S AXIS IS ITS X AXIS (CLAUDE.md, five times over):
	-- the LENGTH goes first and the cross-section second, and a quarter turn
	-- about Z stands it up. Written the other way round it is a disc lying
	-- on the grass as wide as the tree is tall.
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(height, radius * 2, radius * 2)
	part.CFrame = CFrame.new(x, GROUND_Y - t.sink + height / 2, z) * CFrame.Angles(0, 0, math.pi / 2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = true
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = folder
	table.insert(trunkColliders, { x = x, z = z, radius = radius })
end

-- What shipped before the mesh. Kept, and reached whenever `Config.TREE_MESH`
-- has no ids in it, so a fresh empty place plus this repo still builds the
-- world this repo has always built. Returns the bole's radius and the
-- canopy's underside for the collider.
local function buildBoxTree(x: number, z: number, seed: number): (number, number)
	local height = 9 + (seed % 3) * 2
	scenery("Trunk", Vector3.new(1.6, height, 1.6),
		CFrame.new(x, GROUND_Y + height / 2, z), TRUNK, Enum.Material.Wood)

	local canopy = 8 + (seed % 3)
	local top = scenery("Canopy", Vector3.new(canopy, canopy, canopy),
		CFrame.new(x, GROUND_Y + height + canopy / 3, z),
		if seed % 2 == 0 then LEAF else LEAF_2, Enum.Material.Grass)
	top.Shape = Enum.PartType.Ball
	-- The ball's underside is `canopy / 6` below the trunk's top.
	return boleRadius(1.6, 1.6, 1.0), math.min(height, height + canopy / 3 - canopy / 2)
end

-- Builds one tree by whichever route is available and then ONE trunk collider
-- for it, whichever route that was -- so every tree on the street stops a
-- character the same way whatever it is drawn with.
local function buildTree(x: number, z: number, seed: number, scaleOverride: number?)
	local spec = Config.treeMesh()
	local scale = scaleOverride or treeScale(Config.TREE_MESH, seed)
	-- The generated tree's profile at this scale is the fallback for every
	-- route, because both mesh routes fit that envelope.
	local radius, top = meshTrunkProfile(Config.TREE_MESH, scale, Config.TREES.boleFraction)

	-- New scenery models fit the existing clearance envelope. The old tree is
	-- retained only as a fallback for places missing the synced model library.
	if SceneryTrees.build(x, z, seed, scale, GROUND_Y, folder) then
		local model = sceneryTreeFor(seed)
		if model then
			radius, top = measureSceneryTree(model, radius, top)
		end
		plantTrunkCollider(x, z, radius, top)
		return
	end
	local templates = spec and ensureTreeTemplates()
	if not (spec and templates) then
		radius, top = buildBoxTree(x, z, seed)
		plantTrunkCollider(x, z, radius, top)
		return
	end

	-- The grove picks its scale off the seed, which is what gives it a height
	-- spread. A street tree is placed against measured clearances instead, so
	-- it is handed one. (`scale` above: the two spec tables carry one ladder.)
	-- A turn per tree, stepped by the golden angle so consecutive seeds never
	-- land near each other. It costs nothing and it is the whole difference
	-- between a grove and a hundred copies of one tree.
	local base = CFrame.new(x, GROUND_Y, z)
		* CFrame.Angles(0, (seed * 2.39996) % (math.pi * 2), 0)

	for _, entry in ipairs(spec.parts) do
		local template = templates[entry.part]
		if template then
			local part = template:Clone()
			part.Name = entry.part
			-- SIZE BEFORE CFRAME. Resizing a MeshPart scales it about its own
			-- centre, so a part seated first and scaled afterwards moves off
			-- the spot it was seated on.
			part.Size = entry.size * scale
			part.CFrame = base * CFrame.new(entry.offset * scale)
			part.Anchored = true
			-- Everything in this file is scenery a chase has to be able to run
			-- through, and a cloned mesh does not inherit that from `scenery`.
			part.CanCollide = false
			part.CanQuery = false
			part.CastShadow = false
			if entry.part == "Canopy" then
				part.Color = if seed % 2 == 0 then CANOPY_TINT else CANOPY_TINT_2
			end
			part.Parent = folder
		end
	end
	plantTrunkCollider(x, z, radius, top)
end

-- `MAILBOX_HALF` went with the kerbside mailbox it placed: the street has no
-- mailbox of its own any more, so nothing out here has to clear a driveway.
-- The derivation is worth keeping in mind if anything else is ever stood
-- beside a drive -- the box's own reach at the yaw it is built with, never a
-- flat offset, which is what once left all ten of them standing on tarmac.

local function buildStreetFurniture(m: any)
	for _, side in ipairs({ -1, 1 }) do
		-- On the verge, just off the kerb. This used to be measured from the
		-- old full-corridor road edge, which put every lamp post and mailbox
		-- 4 studs INSIDE the player's fence.
		local z = side * (m.roadHalfWidth + 1.8)

		-- Lamp posts land in the gaps BETWEEN frontages, never in a driveway.
		-- They sit just off the kerb, in front of whatever else is in the gap:
		-- the verge is 38 studs deep now, so a lamp at 9.8 and a shop at 34
		-- are not competing for the same ground.
		for col = 0, m.perRow - 2 do
			local x = gapX(col)
			scenery("LampPost", Vector3.new(0.6, 14, 0.6),
				CFrame.new(x, GROUND_Y + 7, z), Color3.fromRGB(72, 74, 80), Enum.Material.Metal)
			-- A NEON LAMP HEAD WANTS A DEEP COLOUR, WHICH IS THE FOURTH TIME
			-- THIS PROJECT HAS LEARNED THAT SENTENCE. It was (255, 240, 190)
			-- -- a near-white cream chosen as "warm lamplight" -- and Neon
			-- renders a colour flat out, so what stood on the verge was not a
			-- bulb, it was a white hole with a bloom halo around it.
			-- Photographed down the street, the two nearest lamps were the
			-- brightest objects in frame, brighter than the sky.
			--
			-- The Martian skin, the palace's first lit colonnade and the
			-- townhouse's window rank are the other three, and the fix is the
			-- same every time: a colour a long way from white, so that
			-- rendering it at full brightness still leaves a HUE behind.
			-- Saturation is what survives the bloom, not value.
			local head = scenery("LampHead", Vector3.new(2.2, 0.8, 1.4),
				CFrame.new(x, GROUND_Y + 14, z), Color3.fromRGB(255, 176, 48), Enum.Material.Neon)
			head.CFrame = CFrame.new(head.Position)
		end

		-- PUBLIC WHEELIE BINS, between frontages rather than on them.
		--
		-- Beside the lamp post in the gap between two plots, which is the one
		-- stretch of verge that belongs to nobody: a plot's own verge decor
		-- slots sit at its centre +/- 9.5 and a driveway runs down its middle,
		-- so the midpoint is 27 studs clear of the nearest thing anyone can
		-- buy. That matters -- an owner with Wheelie Bins placed must not end
		-- up with a public one growing out of them.
		--
		-- One per gap -- three a side on a four-plot row, where it was five on
		-- a six-plot one. The COUNT fell with the map and the SPACING did not,
		-- which is the half that matters: cover is still 32 studs from any
		-- driveway, close enough to be a real option on a 37-stud getaway and
		-- far enough that reaching one is a decision.
		--
		-- Yawed to face the road, exactly like a plot: the far side of the
		-- street is turned 180 degrees, which is the correction the old
		-- disguise never made.
		for col = 0, m.perRow - 2 do
			local x = gapX(col) + 5
			local yaw = if side < 0 then 0 else math.pi
			local bin = Decor.buildStreetBin(
				CFrame.new(x, GROUND_Y, z) * CFrame.Angles(0, yaw, 0), workspace)
			if bin then
				bin.Name = "HideBin"

				-- Scenery here is explicitly non-colliding so a chase can run
				-- through it, and a bin is no different -- it must never body
				-- block a thief, a defender or the dog.
				for _, d in ipairs(bin:GetDescendants()) do
					if d:IsA("BasePart") then
						d.CanCollide = false
						d.Anchored = true
					end
				end

				-- One known reference point per bin, rather than whichever
				-- part FindFirstChild happens to return: the prompts hang off
				-- this and the hider is parked at it, so both have to mean the
				-- same place.
				local hatch = Instance.new("Part")
				hatch.Name = "Hatch"
				hatch.Size = Vector3.new(1, 1, 1)
				hatch.CFrame = CFrame.new(x, GROUND_Y + 1.9, z)
				hatch.Transparency = 1
				hatch.Anchored = true
				hatch.CanCollide = false
				hatch.CanQuery = false
				hatch.Parent = bin

				CollectionService:AddTag(bin, "HideBin")
			end
		end

		-- NO MAILBOX OUT HERE. There is exactly one per house and it is the
		-- PLOT'S OWN, which PlotService stands beside the driveway at plot-local
		-- (-12, 36) -- the one carrying the daily-reward prompt and the flag that
		-- says there is something in it.
		--
		-- This used to stand a second one at the kerb on the other side of the
		-- same drive, as street furniture. That was defensible while the two were
		-- different objects -- a red box on a stick out here, a five-part white
		-- box on the plot -- and it stopped being defensible the moment they were
		-- unified onto one builder so the street would have ONE KIND of mailbox
		-- on it. What it actually produced was one kind and TWO OF THEM, ten
		-- studs apart, of which only one could be opened.
		--
		-- The one that went is the SCENERY one, because the other carries a
		-- prompt, a flag, the van's delivery and `PlotService.setMail`. The rule
		-- underneath: where a real interactive object and a decorative lookalike
		-- end up beside each other, the decoration goes -- a player who cannot
		-- tell which of two identical things is the one that works has been given
		-- a puzzle nobody meant to set.
		--
		-- `Decor.buildMailbox` stays shared. It has one caller now, and the
		-- geometry belongs in Shared anyway for the reason its own header gives.
	end
end

-- Everything beyond the plots is woodland.
--
-- It used to be a row of generic houses standing on the far side of the
-- street, where no plot is. Now that every plot builds its own house at the
-- tier its owner bought, a second set out there read as unclaimed plots and
-- sent players wandering off to look for a piggy that was never going to be
-- built. Trees close the same sightline without promising anything.
--
-- The count is deliberate. This is scenery every client draws behind
-- everything that matters, so the strip is three thinning rows rather than a
-- forest -- roughly a hundred parts, in the same range as the houses it
-- replaced.
local GROVE_ROWS = {
	-- depth: studs beyond the back fence line of a row of plots.
	-- shift:  how far along the street the row slides, in plot spacings, so
	--         no two rows line up into an avenue.
	-- reach:  extra columns past each end of the street.
	-- step:   column stride; the back row is thinned to every other column.

	-- Depths are measured from the BACK FENCE, so the houses -- which all
	-- stand inside it -- are clear by construction. The first row is close
	-- enough to shut the sightline behind a plot without leaning over it.
	-- 14 while the canopy was a ten-stud ball. The meshed tree's canopy is
	-- half as wide again, so the front row moved back by the difference: the
	-- trees are bigger, so the same amount of green stands in front of the
	-- same amount of sky, and the row keeps its full inward jitter rather
	-- than half of it piling up against the clamp below.
	-- 22 -> 30 WITH THE CANOPY, which is the same move this note already
	-- records once: the clamp below keeps a canopy out of the fence, so a front
	-- row nearer than the canopy's own reach spends its inward jitter piling up
	-- against that clamp on one line, which reads as a hedge rather than as a
	-- treeline. The reach went 11.58 -> 19.96 with the new scales, so the row
	-- moved back by the difference.
	-- 76 -> 62 AND 102 -> 84 WHEN THE MAP CAME IN. The front row did not move:
	-- it is the one that shuts the sightline behind a plot, and its 30 is
	-- solved against the canopy's own reach (see the note above it). The two
	-- behind it are depth of WOOD rather than a sightline, so they are the
	-- cheap half of making the valley narrower -- three rows still read as a
	-- wood, and the wall's inner face comes in 30 studs with them.
	{ depth = 30, shift = -0.5, reach = 0, step = 1 },
	{ depth = 62, shift = 0.1, reach = 1, step = 1 },
	{ depth = 84, shift = -0.4, reach = 2, step = 2 },
}

-- Deterministic scatter, so the grove looks unplanted but every server builds
-- the identical suburb -- a tree that moves between sessions is a landmark
-- that lies.
local function scatter(seed: number, spread: number): number
	local n = math.sin(seed * 12.9898) * 43758.5453
	return (n - math.floor(n) - 0.5) * spread
end

-- Grass along the kerb.
--
-- THE BAND IS DERIVED FROM WHAT IS ALREADY STANDING OUT THERE rather than
-- chosen. It begins outboard of the lamp posts and the wheelie bins, which
-- sit on the 1.8-stud verge line at |z| 9.8, and stops short of the boards at
-- `boardZ` and the four shops set back behind them. So it is exactly the
-- strip of verge that nothing else occupies -- and it is the strip a player
-- walking down the pavement spends the whole walk looking at.
--
-- DRIVEWAYS ARE VETOED, because a driveway crosses this band rather than
-- running beside it: `buildDriveway` lays tarmac from the kerb to the fence
-- line, so every plot column punches a hole straight through the strip.
-- Grass growing out of somebody's driveway is the class of thing nobody files
-- a report about and everybody sees.
local function buildVergeGrass(m: any)
	local nearZ = m.roadHalfWidth + 3
	local farZ = m.boardZ - 3
	if farZ <= nearZ then
		return
	end
	local depth = farZ - nearZ

	-- Half a driveway plus a stud, so a blade never leans over the edging.
	local halfDrive = Config.DRIVEWAY_WIDTH / 2 + 1
	-- A tuft stands about 1.35 studs, so a blade whose ROOT is a stud outside
	-- the machine's plinth still leans over it. `GrassTuft.clearance` is the
	-- band rule this mirrors on a plot: a thing grass can grow through is a
	-- thing with grass-height air under it.
	local STATION_KEEP = 1
	local function offDriveway(pos: Vector3): boolean
		for col = 0, m.perRow - 1 do
			if math.abs(pos.X - columnX(m, col)) < halfDrive then
				return false
			end
		end
		-- THE MACHINE. Measured, its front face sits at |z| 21.7 against a
		-- band that runs to `boardZ - 3` (24.2), so about two and a half
		-- studs of it stands inside this strip -- and without this the grass
		-- grows through its plinth, which is the class of thing nobody files
		-- a report about and everybody sees.
		--
		-- AND THE BAND ABOVE IS DERIVED FROM WHAT WAS STANDING HERE WHEN IT
		-- WAS WRITTEN, which is the whole reason this needs adding by hand: a
		-- list of exceptions is a claim about what exists and it goes stale
		-- without erroring. The comment over this function still names only
		-- the lamp posts and the bins.
		if CombineStation.occupies(pos.X, pos.Z, STATION_KEEP) then
			return false
		end
		return true
	end

	-- Kept well inboard of the tunnel mouths, which is where the verge stops
	-- being verge and becomes hillside.
	local fromX = m.tunnelWestX + 24
	local toX = m.tunnelEastX - 24

	for i, side in ipairs({ -1, 1 }) do
		GrassTuft.scatterRect(
			CFrame.new((fromX + toX) / 2, GROUND_Y, side * (nearZ + depth / 2)),
			toX - fromX, depth, folder, 4000 + i, offDriveway)
	end
end

-- ============================================================
-- STREET TREES
-- ============================================================
--
-- Trees down the verge as well as behind the plots, so the neighbourhood has
-- them rather than just the backdrop.
--
-- THE SIGHTLINE IS WHAT CONSTRAINS THIS, NOT THE SPACE. A thief decides which
-- piggy is worth crossing the road for from the PAVEMENT -- that is what the
-- rob badge, the coin pile and the vault tell are all for, and this file
-- already measures how much of a pig reads over each fence tier. A tree is
-- taller than any fence, so one planted opposite a gate blanks exactly the
-- thing the decision is made on. Measured before planting: 69% of a pig reads
-- from the kerb, and that number is the one this must not move.
--
-- So they go where the lamp posts and the bins already go: the stretch of
-- verge BETWEEN two driveways, which belongs to no plot. That keeps every
-- trunk a plot-half away from the line a viewer looks down.
--
-- AND THEY ARE SMALLER THAN THE GROVE, WHICH IS A MEASUREMENT RATHER THAN A
-- STYLE CHOICE. `canopyReach` is the DIAGONAL, so a grove tree at its
-- shipped scales reaches 9.2 to 11.6 studs. The free band beside a shop is
-- `(PLOT_SPACING - DRIVEWAY_WIDTH) / 2` less the shop's own half width and
-- forecourt -- about 20.5 studs -- so a grove tree fits it with under two
-- studs to spare on both sides, which is not a fit, it is a coincidence
-- waiting for the next spacing edit. At 0.75 the reach is 5.99 and there are
-- four studs clear either side.
local STREET_TREE = {
	-- BIGGER, AND THIS ONE HAS A HARD CEILING THAT FAILS SILENTLY AT 1.19.
	--
	-- `clear(x)` vetoes a placement whose canopy would reach a driveway or a
	-- shop, and every candidate sits at the same `offset` -- so a scale that
	-- fails the test does not produce smaller trees or a warning, it produces
	-- NO VERGE TREES AT ALL. Measured from the shipped offset of 21: the tree
	-- is 21 studs from a gap centre (shop half-width 11) and 19 from a plot
	-- column (half a 17-stud driveway, plus one), and `canopyReach` is the
	-- diagonal at 7.986 per unit of scale. So the driveway binds first and the
	-- last scale that clears it is 1.19, with nothing left over.
	--
	-- 1.0 is 8.0 of reach with 2.0 clear of the shop and 1.5 of the driveway.
	-- It stood at 0.75 for a measured reason -- the note above records 4 studs
	-- clear and calls a 2-stud margin "not a fit, a coincidence" -- so this
	-- deliberately spends most of that margin and stops well short of the
	-- ceiling. The grove behind the plots is where the big trees are; these are
	-- on a verge with a road on one side and a fence on the other.
	scale = 1.0,
	-- Verge depth. The lamp posts and bins stand on the 1.8 line at |z| 9.8
	-- and the boards are at `boardZ`; this sits between them.
	z = 19,
	-- Out from a gap centre. The free band runs from the shop's edge to the
	-- driveway's, and this is its middle rather than a number that looked
	-- right.
	offset = 21,
}

local function buildStreetTrees(m: any)
	local spec = Config.treeMesh()
	local reach = if spec then canopyReach(spec, STREET_TREE.scale) else 6
	local perRow = Config.PLOTS_PER_ROW

	-- Where a canopy may not reach: a driveway crossing the verge, and the
	-- gap centres, which is where the shops and the boards stand.
	local halfDrive = Config.DRIVEWAY_WIDTH / 2 + 1
	local SHOP_HALF = 11 -- 18 wide plus its two-stud forecourt overhang
	-- AND THE HERD CORRIDOR, NOW THAT A TRUNK STOPS A PIGGY. A pack enters the
	-- street through a tunnel and walks the verge at `herdGround().corridorX`
	-- (|x| 221.8) from the kerb to the band behind the plots -- straight
	-- through the verge at |z| 19, where the past-the-plot trees stood at
	-- 190 and 220. Before the colliders a tree there was scenery the pack
	-- walked through; with `treeBlocks` registered it is a wall across the
	-- one line every herd has to take, so THE TREE MOVES AND NEVER THE
	-- ROUTE. The keep is the trunk's own bole plus the herd margin, plus a
	-- flank and the jitter, because the thing walking is a file three
	-- columns wide -- derived, so a fatter bole or a wider pack re-asks it.
	local ground = Config.herdGround()
	local boleR = meshTrunkProfile(Config.TREE_MESH, STREET_TREE.scale, Config.TREES.boleFraction)
	local herdKeep = boleR + Config.TREES.margin + Config.HERDS.followSpacing + Config.HERDS.jitter
	local function clear(x: number, side: number): boolean
		for col = 0, perRow - 1 do
			if math.abs(x - Config.plotColumnX(col)) < halfDrive + reach then
				return false
			end
		end
		for col = 0, perRow - 2 do
			if math.abs(x - gapX(col)) < SHOP_HALF + reach then
				return false
			end
		end
		-- A hair of tolerance, because the slide below lands a tree EXACTLY one
		-- keep off the line and float arithmetic would refuse its own answer.
		if math.abs(math.abs(x) - ground.corridorX) < herdKeep - 1e-6 then
			return false
		end
		-- THE TREES CAME BACK. A veto stood here for one release: four of
		-- these gaps carried a robbable piggy bank on the verge, 16 studs off
		-- the gap centre, in the only stretch wide enough to hold one -- so
		-- one of each gap's pair of trees gave up its place to a pig.
		--
		-- The pig is inside the shop now, so there is nothing on that band to
		-- clear and both trees stand again. Worth recording as a deletion
		-- rather than quietly dropping it: the veto took a SIDE argument,
		-- which it needed only because a till sat on the same side of its own
		-- SHOP rather than on the same side of the map.
		--
		-- AND THE SIDE ARGUMENT IS BACK, BECAUSE THE COMBINE MACHINE IS THAT
		-- NEXT THING. It stands in ONE gap on ONE shoulder, so a symmetric
		-- veto would cost the far row a tree for a machine that is not on it
		-- -- which is exactly the asymmetry the till's version needed and
		-- this entry predicted somebody would need again.
		--
		-- MEASURED, IT VETOES NOTHING TODAY. Gap 3's two candidates sit at
		-- x 99 and 141 against a machine whose nearest corner is 14.48 studs
		-- off either of them, and the canopy reaches 7.99 -- so both trees
		-- stand and frame it. This is here because a scale, an offset or a
		-- gap that moves would put one through the shell silently, and
		-- `tests/luau/combine.luau` drives it both ways.
		if CombineStation.blocksTree(x, side, reach) then
			return false
		end
		return true
	end

	local xs = {}
	-- Two per gap, either side of whatever is standing in it.
	for col = 0, perRow - 2 do
		table.insert(xs, gapX(col) - STREET_TREE.offset)
		table.insert(xs, gapX(col) + STREET_TREE.offset)
	end
	-- And on past the last plot, where the verge runs to the hillside with
	-- nothing on it at all. Stopped short of the tunnel mouth by the canopy's
	-- own reach, or the end trees stand buried in the hill -- the same
	-- mistake the grove's own rows already record.
	local outer = Config.plotColumnX(perRow - 1)
	local limit = m.tunnelEastX - 24 - reach
	local x = outer + 30
	local last = -math.huge
	while x <= limit do
		-- A candidate on the herd corridor slides INWARD to the corridor's
		-- edge rather than being dropped: 220 lands at 213.8 today, still
		-- two canopy reaches past the tree at 190. A second candidate that
		-- would slide onto the same spot is skipped.
		local placed = x
		if math.abs(placed - ground.corridorX) < herdKeep then
			placed = ground.corridorX - herdKeep
		end
		if placed - last >= 12 then
			table.insert(xs, placed)
			table.insert(xs, -placed)
			last = placed
		end
		x += 30
	end

	-- THE SIDE LOOP IS OUTSIDE AND `clear` KNOWS WHICH ROW IT IS ANSWERING
	-- FOR, which is how this started and how it is again.
	--
	-- A till sat on the same side of its own SHOP rather than on the same
	-- side of the map, so the tree it displaced was a different one on each
	-- row; that went with the till, `clear` became symmetric, and the
	-- combine machine brought the argument straight back -- it stands in one
	-- gap on one shoulder, so vetoing both rows would cost the far one a
	-- tree for something that is not on it.
	--
	-- THE SEED IS STILL DRAWN PER CANDIDATE WHETHER OR NOT IT IS PLANTED,
	-- which is the property that keeps the layout stable: a veto removes the
	-- tree it refuses and moves no other one. Same rule as `scatterRect`
	-- drawing before it accepts.
	local seed = 5000
	for _, side in ipairs({ -1, 1 }) do
		for _, tx in ipairs(xs) do
			seed += 1
			if clear(tx, side) then
				buildTree(tx, side * STREET_TREE.z, seed, STREET_TREE.scale)
			end
		end
	end
end

-- Where the grove's trunks stood and how far each canopy reaches, kept so
-- the grassland can be laid out against the trees that are actually there
-- rather than against the rows they were meant to follow. A pond under a
-- canopy is the grove-row-in-the-yard fault one object along.
local grovePlacements: { Grassland.Obstacle } = {}

local function buildTrees(m: any)
	grovePlacements = {}
	trunkColliders = {}
	local planOK, meadowPlan = pcall(function()
		return require(ReplicatedStorage.Shared.MeadowPlan)
	end)
	-- The back fence line -- YARD_DEPTH behind the plot centre, not half a
	-- plot.
	--
	-- This used to read `m.rowZ + m.halfPlot`, the back edge of the plot
	-- SLAB. That was right when a plot was only its slab, and silently wrong
	-- the moment the fence was lengthened to enclose the house: the first
	-- grove row landed 46 studs inside the yard, which put trees on people's
	-- lawns among their houses. Nothing here may sit inside the fence --
	-- trees are CanCollide false, but a canopy over a plot still hides a
	-- piggy.
	local rear = m.rowZ + Config.YARD_DEPTH
	local seed = 0
	-- Read once rather than per tree: it walks and rebuilds a table, and this
	-- loop runs about a hundred times.
	local treeSpec = Config.treeMesh()

	for _, side in ipairs({ -1, 1 }) do
		for _, row in ipairs(GROVE_ROWS) do
			local col = -row.reach
			while col <= m.perRow + row.reach do
				seed += 1
				-- Jittered FIRST, then tested. The guard used to run on the
				-- column position and the scatter could still push a tree eight
				-- studs into the hillside afterwards -- three of them ended up
				-- buried to the canopy.
				local x = columnX(m, col) + row.shift * Config.PLOT_SPACING + scatter(seed, 16)
				-- Nothing inside a hill. The rows reach two columns past the
				-- last plot, which is now hillside rather than lawn, and a tree
				-- planted there stands buried to its canopy in the mound.
				if x > m.tunnelEastX - 12 or x < m.tunnelWestX + 12 then
					col += row.step
					continue
				end
				-- Jittered, then CLAMPED so no canopy can reach inside a
				-- fence. That is the rule at the top of this function, and it
				-- used to hold because the depths here were chosen against a
				-- ten-stud ball; it holds by construction now.
				--
				-- Same argument as `Config.auditFences`: the failure is a
				-- number, nothing errors, nothing looks wrong from a plan
				-- view, and a canopy standing over somebody's piggy should
				-- not be something the next edit to `scales` can bring back.
				local depth = row.depth + scatter(seed + 97, 8)
				local reach = if treeSpec then canopyReach(treeSpec, treeScale(treeSpec, seed)) else 8
				if treeSpec then
					depth = math.max(depth, reach + CANOPY_CLEARANCE)
				end
				if not planOK or meadowPlan.treeClear(x, side * (rear + depth), reach) then
					buildTree(x, side * (rear + depth), seed)
					table.insert(grovePlacements, { x = x, z = side * (rear + depth), reach = reach })
				end
				col += row.step
			end
		end
	end
end


-- ============================================================
-- THE HILLS
-- ============================================================
--
-- A ridge closing each end of the street, with a tunnel through it.
--
-- It exists for the police car. A patrol used to appear at the end of the road
-- out of clear air and vanish the same way, which reads as a spawn rather than
-- as traffic. Now it drives out of a hillside and away into the far one, so it
-- comes from somewhere and leaves for somewhere.
--
-- THE ONLY BLACK IS INSIDE THE MOUTH, and getting that right meant rebuilding
-- the bore rather than moving the hill. The first version made the tunnel a
-- 2.5-stud skin of near-black concrete and left the domes to bury it, which
-- they did not: measured, the outer walls came out 45% exposed and the roof
-- 98%, so the tunnel read as a black box standing between two hills instead of
-- as a hole in one.
--
-- No arrangement of domes fixes that. A sphere sunk into the ground is at its
-- WIDEST at ground level, so any dome big enough to cover the roof at 16 studs
-- up reaches further forward at the road, and the same sphere that buries the
-- roof fills the bore underneath it. That is a fact about spheres, not a
-- tuning problem.
--
-- So the mass around the bore is EARTH: grass blocks thick enough to be a
-- hillside, with the near-black on thin liners a few inches inside the
-- opening. There is now nothing dark outside the mouth to be buried in the
-- first place, and the domes are shaping a skyline rather than hiding a
-- mistake.
--
-- These are the only parts in this file that COLLIDE. Everything else here is
-- scenery a chase must be able to run through; a hill is the edge of the world
-- and should stop you, and the banks are what stop a player wandering into the
-- void and discovering it is a cupboard.
-- LEFT ALONE WHEN THE LAWN CAME DOWN, AND THAT IS DELIBERATE. The ground and
-- the lawn were darkened about 30% once the texture came off them, which
-- leaves these NUMERICALLY LIGHTER than the ground they sit on -- the reverse
-- of how they started. Looked at rather than reasoned about: a hill is a
-- half-buried SPHERE and a lawn is a flat plane, so the two catch the 14:30
-- sun completely differently, and on screen the hills still read as the
-- deeper, further thing. Matching the numbers would make them read wrong.
-- Compare on a capture before touching these.
local HILL_ROCK = Color3.fromRGB(96, 122, 78)
local HILL_ROCK_2 = Color3.fromRGB(84, 108, 68)
local TUNNEL_STONE = Color3.fromRGB(128, 126, 122)
-- Near black, not merely dark. At (58, 57, 56) the lining still caught the sun
-- and read as two bright wedges either side of the opening, which makes the
-- mouth look like a shallow alcove. Everything in the bore is lit by the same
-- sky as everything outside it, so the only way to sell a tunnel is for the
-- surfaces themselves to be almost black.
local TUNNEL_DARK = Color3.fromRGB(17, 17, 19)

-- The earth around the bore. These are the numbers that stop the tunnel
-- reading as a box: a hillside, not a lining.
local BANK_SIDE = 9 -- earth either side of the bore
local BANK_BACK = 26 -- earth behind the void, so the ridge carries on past it
local BANK_SINK = 1 -- how far the banks are buried, so no face sits ON the grass
local HEAD_RISE = 4 -- masonry above the opening, and earth to the same line
local HEAD_DEPTH = 7 -- how far the headwall reaches back along the bore
local HEAD_PROUD = 1.2 -- and how far it stands out of the hillside
local LINER = 0.8 -- the dark lining, half buried in the earth it lines

-- Like `scenery`, but solid. A hill you can walk through is a hole in the map.
local function solid(name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material): Part
	local p = scenery(name, size, cf, colour, material)
	p.CanCollide = true
	return p
end

-- ONE CLIFF COLUMN: a block of rock with a cap of turf on top.
--
-- THE HILLS USED TO BE HALF-BURIED SPHERES, and they stood only at the two
-- ends of the street. Two things were wrong with that. A sunken sphere is
-- ROUND, which is the one shape this world has no other example of -- every
-- building, fence and ornament here is flat-shaded hard-edged geometry, so the
-- hills were the only soft thing on the map. And a map walled at two ends is a
-- CORRIDOR: the two long sides ran out to open ground and simply stopped.
--
-- A column is TWO parts and that pair is the whole trick. The rock is what
-- makes it a cliff; the turf cap is what makes it the same ground the street
-- stands on, carried up and broken off. Without the cap a wall of stone reads
-- as something built around the map rather than as the map being a floor in a
-- valley.
--
-- YAWED SLIGHTLY AND NEVER SQUARE. A run of axis-aligned boxes is a fence; the
-- same boxes turned a few degrees each read as rock that cracked. A FEW
-- degrees rather than many, because the columns have to go on overlapping
-- their neighbours: a gap in a valley wall is a hole in the map, and these are
-- the only parts in this file that collide.
local CLIFF_ROCK = Color3.fromRGB(196, 142, 112)
local CLIFF_ROCK_2 = Color3.fromRGB(176, 124, 98)
local CLIFF_CAP = 2.2 -- how thick the turf on top is
local function cliffColumn(x: number, z: number, width: number, depth: number,
	height: number, yaw: number, seed: number)
	local at = CFrame.new(x, GROUND_Y, z) * CFrame.Angles(0, yaw, 0)

	-- Buried a stud, so no face of the rock sits ON the grass -- the coplanar
	-- flicker this project has recorded five times, on parts big enough to be
	-- seen flickering from the far end of the street.
	local rock = solid("Cliff", Vector3.new(width, height + 1, depth),
		at * CFrame.new(0, (height + 1) / 2 - 1, 0),
		if seed % 2 == 0 then CLIFF_ROCK else CLIFF_ROCK_2,
		Enum.Material.SmoothPlastic)

	-- The cap oversails the rock by a few tenths on every side, so the turf
	-- reads as an overhang the rock was cut from under rather than as a lid
	-- resting flush on a box.
	local cap = solid("CliffCap", Vector3.new(width + 0.7, CLIFF_CAP, depth + 0.7),
		at * CFrame.new(0, height + CLIFF_CAP / 2 - 0.2, 0),
		if seed % 2 == 0 then HILL_ROCK else HILL_ROCK_2,
		Enum.Material.SmoothPlastic)
	-- A hill is ground, so its top wears what the ground wears. Without this
	-- the turf stops being the same surface as the lawn it grew out of.
	cap.Material = Config.GRASS_MATERIAL.material
	cap.MaterialVariant = LAWN_VARIANT
	return rock, cap
end

-- A RUN OF CLIFF ALONG ONE EDGE, from one point to another.
--
-- `inward` is the direction the map is in, and it is what the boulders at the
-- foot are offset along: a plain wall meets the grass along a single hard
-- line, and a few blocks spilled in front of it is what the reference art
-- does to break that line up. They are part of the wall rather than scattered
-- decoration -- being solid, they also stop anybody standing in the seam
-- between two columns.
--
-- DETERMINISTIC, from a seeded `Random`, for the reason the grass scatter is
-- seeded: every server builds the identical valley, so a screenshot taken
-- today describes the map somebody joins tomorrow.
local function cliffRun(fromX: number, fromZ: number, toX: number, toZ: number,
	inward: Vector2, rng: Random)
	local spanX, spanZ = toX - fromX, toZ - fromZ
	local length = math.sqrt(spanX * spanX + spanZ * spanZ)
	if length < 1 then
		return
	end
	local ux, uz = spanX / length, spanZ / length

	-- Stepped SHORTER than a column is wide, so consecutive columns always
	-- overlap however they are yawed. This is the number that makes the wall
	-- continuous, and it is the one to re-check if the yaw is ever widened.
	local step = 15
	local count = math.max(1, math.ceil(length / step))
	for i = 0, count do
		local t = math.min(i * step, length)
		local x, z = fromX + ux * t, fromZ + uz * t
		local width = 20 + rng:NextNumber() * 8
		local depth = 16 + rng:NextNumber() * 14
		local height = 20 + rng:NextNumber() * 16
		local yaw = math.rad((rng:NextNumber() - 0.5) * 16)
		-- Pushed OUT of the map by half its own depth, so the wall's inner
		-- face lands on the line it was asked for rather than the middle of
		-- the rock.
		cliffColumn(x - inward.X * depth / 2, z - inward.Y * depth / 2,
			width, depth, height, yaw, i)

		-- A boulder at the foot, on most columns rather than on all of them.
		if rng:NextNumber() < 0.55 then
			local size = 7 + rng:NextNumber() * 6
			local along = (rng:NextNumber() - 0.5) * step
			cliffColumn(
				x + inward.X * (size / 2 - 1) + ux * along,
				z + inward.Y * (size / 2 - 1) + uz * along,
				size, size, size * (0.5 + rng:NextNumber() * 0.4),
				math.rad(rng:NextNumber() * 90), i + 1)
		end
	end
end

-- The mouth: a bore lined in black, driven through a bank of earth, with a
-- concrete portal standing proud of the face.
--
-- `outward` is the direction the hill lies in, so the same builder does both
-- ends: +1 at the open end, -1 behind the plaza.
local function buildTunnel(m: any, mouthX: number, outward: number)
	local depth = m.tunnelDepth
	local half = m.tunnelHalfWidth
	local height = m.tunnelHeight
	local midX = mouthX + outward * depth / 2
	local wide = half + BANK_SIDE
	local mass = depth + BANK_BACK
	local massX = mouthX + outward * mass / 2

	local function earth(name: string, size: Vector3, cf: CFrame)
		local p = solid(name, size, cf, HILL_ROCK, Enum.Material.Grass)
		-- Same reason as `mound`: this is the hillside the bore is driven
		-- through, not a lining.
		p.Material = Config.GRASS_MATERIAL.material
		p.MaterialVariant = LAWN_VARIANT
		return p
	end

	-- A block on each side of the bore and a plug behind the void, all of it
	-- up to the ceiling. They overlap each other freely: it is all one hill,
	-- and an overlap inside a solid mass is invisible by definition.
	--
	-- Everything that meets the ground starts BANK_SINK below it, so no face
	-- is ever flush with the grass.
	for _, side in ipairs({ -1, 1 }) do
		earth("HillBank", Vector3.new(mass, height + BANK_SINK, BANK_SIDE),
			CFrame.new(massX, GROUND_Y + (height - BANK_SINK) / 2, side * (half + BANK_SIDE / 2)))
	end
	earth("HillBack", Vector3.new(BANK_BACK, height + BANK_SINK, wide * 2),
		CFrame.new(mouthX + outward * (depth + BANK_BACK / 2),
			GROUND_Y + (height - BANK_SINK) / 2, 0))

	-- The earth OVER the bore, and it stops level with the headwall.
	--
	-- No dome can go here, and that is geometry rather than taste. A sphere
	-- sunk into the ground is at its WIDEST at the ground, so one big enough to
	-- cover the ceiling is inside the tunnel underneath it; and one resting ON
	-- the ceiling carries its equator thirty studs up and overhangs the road
	-- like a mushroom.
	--
	-- Stepping it up in courses was tried and is worse: from any camera above
	-- the portal the steps read as a staircase cut into the hillside, which is
	-- a stranger thing to see than a flat top. One course finishing flush with
	-- the masonry reads as the top of a cutting, which is what it is, and the
	-- coping is then the edge the eye follows instead of a green corner.
	--
	-- Half a stud above the lintel rather than level with it, because level
	-- would put the earth's top face and the masonry's at exactly the same
	-- depth over the patch where they overlap, and two surfaces at one depth
	-- give the renderer nothing to sort by. The coping covers the difference.
	earth("HillCap", Vector3.new(mass, HEAD_RISE + 0.5, wide * 2),
		CFrame.new(massX, GROUND_Y + height + (HEAD_RISE + 0.5) / 2, 0))

	-- THE HEADWALL, and it is concrete for a reason.
	--
	-- The earth around a 14-stud bore is a 14-stud wall along the whole length
	-- of it, and no arrangement of domes buries the front of that: a dome close
	-- enough to cover it is standing in the carriageway, because a dome is
	-- widest exactly where the road is. Every version that tried ended up as a
	-- green box beside a green hill, which is the thing being complained about.
	--
	-- A portal wall is not a hole in that argument, it is the answer to it. A
	-- squared-off mass of MASONRY at the mouth is what a road tunnel actually
	-- looks like, so the one shape the domes cannot hide is the one shape that
	-- wants to be seen. It stands taller than the earth behind it, so from the
	-- street the whole silhouette is concrete and hillside with nothing green
	-- and rectangular between them.
	local headTop = height + HEAD_RISE
	local face = mouthX + outward * (HEAD_DEPTH / 2 - HEAD_PROUD)
	for _, side in ipairs({ -1, 1 }) do
		solid("TunnelWing", Vector3.new(HEAD_DEPTH, headTop + BANK_SINK, BANK_SIDE + 2),
			CFrame.new(face, GROUND_Y + (headTop - BANK_SINK) / 2,
				side * (half + (BANK_SIDE + 2) / 2)),
			TUNNEL_STONE, Enum.Material.Concrete)
	end
	solid("TunnelLintel", Vector3.new(HEAD_DEPTH, HEAD_RISE, (wide + 1) * 2),
		CFrame.new(face, GROUND_Y + height + HEAD_RISE / 2, 0),
		TUNNEL_STONE, Enum.Material.Concrete)
	-- A coping over the top edge, standing proud on every side. Without it the
	-- earth meets the wall at a bare seam and the wall reads as a painted
	-- rectangle rather than as something holding a hill back.
	solid("TunnelCoping", Vector3.new(HEAD_DEPTH + 1.6, 1, (wide + 2) * 2),
		CFrame.new(face, GROUND_Y + headTop + 0.5, 0),
		TUNNEL_STONE, Enum.Material.Concrete)

	-- The lining, and the only dark thing here.
	--
	-- Each slab is centred ON the earth face it lines, so half of it is buried
	-- and the visible half stands 0.4 proud. Laying it flush would put two
	-- surfaces at the same depth, which gives the renderer nothing to sort by.
	for _, side in ipairs({ -1, 1 }) do
		solid("TunnelLiner", Vector3.new(depth, height, LINER),
			CFrame.new(midX, GROUND_Y + height / 2, side * half),
			TUNNEL_DARK, Enum.Material.Slate)
	end
	solid("TunnelLiner", Vector3.new(depth, LINER, half * 2),
		CFrame.new(midX, GROUND_Y + height, 0),
		TUNNEL_DARK, Enum.Material.Slate)

	-- The carriageway carries on into the bore.
	--
	-- The road proper stops at the mouth, so without this the tunnel has GRASS
	-- in it and the illusion dies at the threshold. Darker than the road
	-- outside because it is under a roof, which also stops the two slabs
	-- reading as one continuous surface at the seam.
	pave("TunnelFloor", depth, half * 2, midX, 0, LIFT_ROAD,
		Color3.fromRGB(21, 21, 24), Enum.Material.Asphalt)

	-- The void at the back.
	--
	-- Neon on a black colour, which is the one material that ignores the light
	-- falling on it -- a dark SmoothPlastic slab still picks up the sun and
	-- reads as a grey wall at the end of a corridor. This reads as no wall.
	-- Held a hair clear of the earth plug behind it so their faces do not meet.
	local void = solid("TunnelVoid", Vector3.new(1, height, half * 2),
		CFrame.new(mouthX + outward * (depth - 0.6), GROUND_Y + height / 2, 0),
		Color3.new(0, 0, 0), Enum.Material.Neon)
	void.CastShadow = false
end

-- The ridge, parting either side of the mouth.
--
-- Every dome is placed against two things it must not reach: the BORE, which
-- it would fill with grass, and the open ground in front of the mouth, which
-- is the carriageway at one end and the arrival plaza at the other. A sunken
-- sphere is widest at ground level, so a dome that clears the mouth at head
-- height can still be standing in the road -- which is also why the earth over
-- the bore is a block and not a dome.
local function buildHill(m: any, mouthX: number, outward: number)
	buildTunnel(m, mouthX, outward)

	-- The mass behind the bore, as far forward as the bore allows: any closer
	-- and it is standing inside the tunnel. This is the only cliff here that
	-- is not part of a run -- the END WALLS in `buildValley` are what part
	-- around the mouth -- and what it stops is the void reading as a notch in
	-- the skyline when the road is looked at from the side.
	local backX = mouthX + outward * 62
	cliffColumn(backX, 0, m.tunnelHalfWidth * 2 + 40, 44, 40, 0, 2)
end

-- THE VALLEY: rock the whole way round the map, parting only for the tunnels.
--
-- The map is a floor between hillsides now rather than a street with a hill at
-- each end, and what that buys is the thing a border is FOR: the edge of the
-- world explains itself, so nobody walks to the end of the grass and finds out
-- that it simply stops.
--
-- EVERY WALL STANDS INSIDE THE GROUND SLAB, and the REASON for that changed
-- when the horizon shipped while the rule did not. It used to be that the
-- ground is one Part (`Config.GROUND_SIZE`, built by WorldService) and a wall
-- on its edge would have its outer half hanging over nothing. There is land
-- out there now. What keeps the wall inside the slab is simpler and is what
-- the boulders at the foot are offset INTO the map for: this wall is the inner
-- face of the valley, so it belongs on the ground the STREET stands on, and
-- everything on the far side of it is `buildHorizon`'s.
--
-- THE TUNNELS ARE THE ONLY GAPS, and they are gaps in the END walls alone.
-- The two long sides are unbroken: a hole in one of those is a way out of the
-- map on foot, where a tunnel is a hole nobody can use, since the void at the
-- back of the bore is solid.
--
-- IMPASSABLE IS MEASURED RATHER THAN ASSERTED. `Config.jumpReach` is 6.14
-- studs -- the collision hull's own apex, not the feet, which is the number
-- every fence tier in this game is checked against -- and the SHORTEST column
-- here is 20 studs of rock under a 2.2 cap. Nothing can be jumped, the columns
-- collide (`solid`, unlike the rest of this file), and there is no truss or
-- climbable surface anywhere on them, so the ladder cannot be used on one
-- either.
local function buildValley(m: any)
	-- Inside the slab by a margin wide enough for the deepest column.
	local edgeZ = Config.GROUND_SIZE.Y / 2 - 30

	-- THE LONG SIDES RUN BETWEEN THE TWO END WALLS rather than out to the
	-- corners of the slab. The end walls stand on the tunnel mouths, 252
	-- studs out, and the slab runs to 390 -- so a long side carried to the
	-- corner would be 140 studs of rock built in ground nobody can reach,
	-- behind a wall that already closed the map. About 150 parts for a view
	-- that does not exist.
	local wallWestX, wallEastX = m.tunnelWestX, m.tunnelEastX

	-- Clear of the bore, so the end walls part around the tunnel rather than
	-- filling it in. Derived from the tunnel's own half-width plus a column's
	-- worth of overlap.
	local gap = m.tunnelHalfWidth + 12

	-- THE TREELINE HAS TO FIT INSIDE THE WALL, AND THIS IS THE CHECK THAT
	-- SAYS SO OUT LOUD.
	--
	-- The grove is planted from the back fence outward -- `rear` plus a row
	-- depth, plus jitter, plus whatever the canopy clamp adds -- and it
	-- already reached |z| 276 against a slab that ended at 280. That is what
	-- made the map DEEPER rather than the wall closer in. Both numbers can
	-- move independently (a row depth here, `GROUND_SIZE` over there), and
	-- the failure is silent: trees buried to the canopy in rock, which is the
	-- exact fault the hill veto in `buildTrees` already records once. Same
	-- argument as `Config.auditFences` -- the failure is a number, so the
	-- moment to hear about it is while somebody is typing one.
	local deepest = 0
	for _, row in ipairs(GROVE_ROWS) do
		deepest = math.max(deepest, row.depth)
	end
	local treeSpec = Config.treeMesh()
	local treeOuter = m.rowZ + Config.YARD_DEPTH + deepest + 8
		+ (if treeSpec then canopyReach(treeSpec, treeSpec.scales[#treeSpec.scales]) else 8)
	if treeOuter > edgeZ - 8 then
		warn(("[Neighbourhood] the grove reaches |z| %.0f against a valley wall at %.0f"
			.. " -- widen Config.GROUND_SIZE or pull the back grove row in")
			:format(treeOuter, edgeZ))
	end

	local rng = Random.new(20260917)

	-- The two long sides, end wall to end wall, unbroken.
	cliffRun(wallWestX, edgeZ, wallEastX, edgeZ, Vector2.new(0, -1), rng)
	cliffRun(wallWestX, -edgeZ, wallEastX, -edgeZ, Vector2.new(0, 1), rng)

	-- The two ends, in two runs each: corner to the gap, then the gap to the
	-- far corner. The wall stands ON the tunnel mouth's own line, which is
	-- what makes the portal read as driven THROUGH the hillside rather than
	-- as parked in front of it.
	for _, side in ipairs({
		{ x = m.tunnelEastX, inward = -1 },
		{ x = m.tunnelWestX, inward = 1 },
	}) do
		local inward = Vector2.new(side.inward, 0)
		cliffRun(side.x, edgeZ, side.x, gap, inward, rng)
		cliffRun(side.x, -gap, side.x, -edgeZ, inward, rng)
	end
end

-- ==========================================================================
-- THE HORIZON: what the map sits IN, rather than what it stops at.
--
-- REPORTED AS "A SQUARE FLOATING IN THE SKY", which was a literal description.
-- `Config.GROUND_SIZE` is one 780 x 660 Part eight studs thick with a 920 x
-- 800 ring under it, and nothing else: a rectangular green plate with a
-- vertical cut edge and open sky beneath it.
--
-- THE VALLEY WALL ABOVE ONLY FIXED THAT FROM INSIDE, WHICH IS WHY IT DID NOT
-- READ AS FIXED. It explains the edge perfectly to somebody standing on the
-- street -- the grass stops because there is rock in the way -- and says
-- nothing whatever about the view from any camera ABOVE the rock. That is the
-- view this map is looked at from every time anybody is not playing it, and
-- it is the only view in which the shape of the world is visible at all.
--
-- FOUR RINGS, NEAREST FIRST, AND EACH ONE EXISTS TO BURY THE EDGE OF THE ONE
-- BEFORE IT. That is the whole structure, and it is why none of them can be
-- dropped without the ring inside it becoming the new visible edge:
--
--   APRON      one small step down, ragged, reaching 240 to 420 studs out.
--              It buries the slab's own cut edge and is what the foothills
--              stand on.
--   FOOTHILLS  44 to 96 studs of the valley wall's own rock, just outside
--              the slab. This is the skyline a player sees OVER the wall,
--              and it is the ring that does the most for the least.
--   SHELF      a second step down and a long way out, so the apron's ragged
--              edge has ground under it rather than sky.
--   RANGE      150 to 300 studs of cool grey rock on the shelf's rim. Tall
--              enough that a sightline clearing its tops also clears the
--              shelf behind it, so there is no cut edge left in view from
--              anywhere a player's camera can be.
--
-- RAGGED IS THE POINT, NOT A FLOURISH. A rectangle of any size is still a
-- rectangle from above, so making the map bigger would have bought nothing at
-- all: each segment of both land rings reaches its own distance, and the
-- outline that results is the one thing that stops this reading as a plate.
--
-- WHAT IS NOT SOLVED, STATED PLAINLY: from a few hundred studs up it is still
-- an island, and the undersides are flat. A camera at that altitude sees the
-- shelf's outer edge and sky past it. Closing that means a shell rather than
-- rings -- Part size is clamped to 2048 studs, so a ground plane wide enough
-- to fog out is about 36 parts on its own -- and it is a view nobody in the
-- game can reach. What it buys is the difference between a floating square
-- and a valley in a landscape, which is what was actually being asked for.

-- DISTANCE IS COOLER AND LIGHTER, NEVER MERELY SMALLER. The one thing that
-- separates a far mountain from a big near one is that air has got in the way,
-- and `Atmosphere` at Density 0.14 is too thin to do all of that by itself
-- over a thousand studs -- it is tuned not to bleach a 350-stud street, which
-- is the right call and leaves this to do. So the range is pre-shifted toward
-- the sky's own blue and the foothills are deliberately NOT: two rings in one
-- colour read as one ring however far apart they are.
--
-- SO THEY ARE AUTHORED WARM AND THE WORLD COOLS THEM, WHICH IS THE OPPOSITE
-- OF WHAT THE PARAGRAPH ABOVE FIRST PRESCRIBED. Two passes got this wrong in
-- the same direction. At (124, 138, 152) -- a modest blue-grey by its own RGB
-- -- they photographed as saturated blue slabs; pulled to a near-neutral
-- (140, 144, 146) they still read as ICE rather than as rock.
--
-- The cool is not coming from the colour at all. `WorldService` lights this
-- world with a deliberately BLUE ambient (OutdoorAmbient 88, 100, 132) under
-- a cream sun, and then grades the whole picture at Saturation 0.38 -- so a
-- big grey mass takes blue on every face the sun is not on, and the grade
-- multiplies what it takes. Authoring MORE blue into it is adding to a sum
-- that was already finished.
--
-- Warm mid-brown arrives on screen as the grey-brown these are meant to be,
-- and it ties the range to the foothills in front of it, which wear the
-- valley wall's own tan. Same lesson the lawn learned when its texture came
-- off and the literal value turned out to be an acid pastel: THE NUMBER IN
-- THE SOURCE IS NOT THE COLOUR ON THE SCREEN, and only a capture closes that
-- gap.
local FAR_ROCK = Color3.fromRGB(134, 116, 102)
local FAR_ROCK_2 = Color3.fromRGB(120, 103, 92)

-- The lowland: earth under a rougher turf than the mown street wears. That
-- material choice is INHERITED rather than invented. WorldService's apron ring
-- was deliberately LeafyGrass rather than the painted lawn variant, so that
-- the ground beyond the gardens reads as rough -- and this replaced that ring,
-- so it keeps its argument along with its job.
-- NUDGED TOWARD THE STREET'S OWN GRASS AFTER LOOKING AT IT. Against
-- WorldService's GRASS at (82, 114, 60) these were dark enough that the map
-- read as a bright green plateau sitting ON the lowland rather than as the
-- same ground one step lower, which is the whole illusion. A step in VALUE is
-- a step in what kind of thing it is.
local LOWLAND_EARTH = Color3.fromRGB(112, 88, 66)
local LOWLAND_TURF = Color3.fromRGB(78, 108, 58)
local LOWLAND_TURF_2 = Color3.fromRGB(70, 98, 54)

local SLAB_X = Config.GROUND_SIZE.X / 2
local SLAB_Z = Config.GROUND_SIZE.Y / 2

-- ONE SMALL STEP DOWN RATHER THAN A CLIFF, and this number is load-bearing in
-- a way it does not look. THE EXPOSED HEIGHT OF THE SLAB'S OWN CUT EDGE IS
-- THIS PLUS THE SEGMENT'S OWN SINK -- so at five studs there would be a
-- five-stud green wall running round the map wherever a foothill does not
-- happen to stand, which is the fault being fixed, smaller. At 0.5 against a
-- sink of up to 1.2 the worst case is 1.7 studs, and the lowland reads as the
-- same ground one step lower rather than as a plate on a plinth.
local APRON_LIFT = 0.5

-- Walks the four sides of a rectangle, handing each stop its position, the
-- unit vector ALONG that side, the one pointing OUT of the map, and THE ACTUAL
-- SPACING that run settled on.
--
-- `step` IS A CEILING AND THE SPACING IS DERIVED FROM IT, which is not a
-- refinement -- it is what makes a butt joint possible at all. Stepping by a
-- fixed amount and clamping the last stop to the end of the run leaves ONE
-- gap per run that is shorter than all the others, so the last two segments
-- overlap by the remainder: measured, 90 studs of overlap between two apron
-- lids and 130 between two shelf segments, which is a coplanar top-face pair
-- that the sink jitter can only fix by luck. Dividing the run into equal
-- spans instead means every gap is the same and a segment sized to the
-- spacing butts its neighbour everywhere, by construction.
--
-- THE TWO Z SIDES CARRY THE CORNERS. They run the full width including
-- whatever the X sides reach out to; the X sides then stop at the rectangle
-- itself. Cornering the other way round leaves a notch at each corner, and a
-- notch in a horizon is a hole with the sky behind it.
local function ringWalk(halfX: number, halfZ: number, reach: number, step: number,
	visit: (number, number, Vector2, Vector2, number, number) -> ())
	local index = 0
	local function run(ax: number, az: number, bx: number, bz: number, out: Vector2)
		local dx, dz = bx - ax, bz - az
		local length = math.sqrt(dx * dx + dz * dz)
		if length < 1 then
			return
		end
		local ux, uz = dx / length, dz / length
		local count = math.max(1, math.ceil(length / step))
		local spacing = length / count
		for k = 0, count do
			local t = k * spacing
			index += 1
			visit(ax + ux * t, az + uz * t, Vector2.new(ux, uz), out, index, spacing)
		end
	end
	local far = halfX + reach
	run(-far, halfZ, far, halfZ, Vector2.new(0, 1))
	run(-far, -halfZ, far, -halfZ, Vector2.new(0, -1))
	run(halfX, -halfZ, halfX, halfZ, Vector2.new(1, 0))
	run(-halfX, -halfZ, -halfX, halfZ, Vector2.new(-1, 0))
end

-- A box sized ALONG a side and OUT of the map. Both vectors are unit vectors
-- on X or Z, so one component of each is always zero and this is the same
-- expression on all four sides rather than a branch per side -- which is what
-- the two land rings and the two rock rings all share.
local function boxSize(along: Vector2, out: Vector2,
	length: number, depth: number, height: number): Vector3
	return Vector3.new(
		math.abs(along.X) * length + math.abs(out.X) * depth,
		height,
		math.abs(along.Y) * length + math.abs(out.Y) * depth)
end

-- ONE SEGMENT OF LAND, reaching out from `line` to whatever distance this
-- segment happens to want, and tucked `under` studs back under the ring inside
-- it so its inner face is buried rather than standing as a wall.
local function landSegment(x: number, z: number, along: Vector2, out: Vector2,
	length: number, under: number, reach: number, topY: number, drop: number,
	sink: number, seed: number, capped: boolean)
	local depth = under + reach
	local offset = depth / 2 - under
	local ox, oz = x + out.X * offset, z + out.Y * offset
	-- A RING OF GROUND IS ONE PLANE BY DEFINITION, WHICH IS THE COPLANAR RULE
	-- ARRIVING ON THE BIGGEST PARTS IN THE GAME. Left to itself every lid here
	-- sits at exactly `topY` and overlaps its neighbour by nine studs -- same
	-- facing, real overlap, which is the flicker this file has recorded five
	-- times, this time across the whole width of the world.
	--
	-- TWO THINGS FIX IT AND NEITHER IS ENOUGH ALONE, which took three passes
	-- and an audit to establish.
	--
	-- THE LIDS BUTT rather than overlap: each is exactly the spacing `ringWalk`
	-- derived, so two tops that share a plane touch along a LINE and have no
	-- overlapping AREA, which is what the coplanar test actually asks about. A
	-- butt joint between their side faces is two faces pointing at each other
	-- and is safe. The earth underneath still overlaps generously, so a
	-- float-width seam between two lids shows more earth rather than sky.
	--
	-- THE SINK is what covers the pairs butting cannot reach: a Z-side lid and
	-- an X-side lid genuinely overlap at each corner, and there is no way to
	-- corner a ring without that. It was 0.14 studs first and the audit came
	-- back with 170 pairs -- two draws from a range that small land inside a
	-- coplanar tolerance of each other about a quarter of the time, so jitter
	-- alone is a coin flip repeated eighty times. At 1.2 it is real undulation
	-- on a lowland, invisible to walk on, and leaves about four corner pairs
	-- with a one-in-sixty chance each.
	topY -= sink

	if not capped then
		-- The outer shelf gets no separate lid. Its top is nearly all of what
		-- is ever seen of it and the range stands on its rim hiding the rest,
		-- so a second part per segment would be thirty-two parts for nothing.
		scenery("Lowland", boxSize(along, out, length, depth, drop),
			CFrame.new(ox, topY - drop / 2, oz),
			if seed % 2 == 0 then LOWLAND_TURF else LOWLAND_TURF_2,
			Enum.Material.LeafyGrass)
		return
	end

	-- The earth is the one part here that MAY overlap its neighbour, because
	-- its top is six tenths under the lid and never seen.
	scenery("Lowland", boxSize(along, out, length + 10, depth, drop),
		CFrame.new(ox, topY - 0.6 - drop / 2, oz),
		LOWLAND_EARTH, Enum.Material.SmoothPlastic)

	-- The lid OVERSAILS the earth and is SUNK into it. Two boxes sharing a
	-- face plane z-fight, and these are the largest parts in the game, so a
	-- flush lid would flicker across the whole width of the map. Same pair of
	-- tenths every cliff cap in this file already carries.
	--
	-- Solid, unlike the earth under it: this is the ground somebody who gets
	-- over the valley wall lands on instead of falling out of the world.
	-- OVERSAILING IN THE OUT DIRECTION ONLY. Along the run it is exactly
	-- `length`, so consecutive lids butt; across it, the four tenths are what
	-- keep the lid's own side faces off the planes of the earth under it.
	solid("LowlandTurf", boxSize(along, out, length, depth + 0.8, 2.6),
		CFrame.new(ox, topY - 1.3, oz),
		if seed % 2 == 0 then LOWLAND_TURF else LOWLAND_TURF_2,
		Enum.Material.LeafyGrass)
end

-- A ROCK MASS AT ANY DEPTH. `cliffColumn` above does the same job and could
-- not do this one: it is pinned to GROUND_Y and to the valley wall's palette,
-- which is right for the wall, because the wall IS the ground the street
-- stands on carried up and broken off. The horizon stands on the lowland, a
-- stud and a bit lower, and its far ring has to be a different colour or it
-- reads as the near one.
--
-- `far` is one flag rather than four arguments because there are exactly two
-- kinds of thing here and every difference between them follows from which:
-- a foothill is the valley wall's own rock with turf on top and it collides,
-- a peak is grey, bare, tapered, and out past anything that can be reached.
local function horizonColumn(x: number, z: number, width: number, depth: number,
	height: number, baseY: number, yaw: number, seed: number, far: boolean)
	local at = CFrame.new(x, baseY, z) * CFrame.Angles(0, yaw, 0)
	local even = seed % 2 == 0

	if far then
		-- A PEAK TAPERS OR IT IS A SLAB, AND ONLY A PICTURE SAID SO. The first
		-- build was ONE box per peak, which measured exactly as designed --
		-- right height, right width, sealed against its neighbours -- and
		-- photographed from an orbiting camera as a ring of enormous
		-- flat-topped boxes standing round the map. A flat top at this scale
		-- is the one shape that cannot read as a mountain, and no amount of
		-- height or colour fixes it, because the fault is the silhouette.
		--
		-- THREE STEPS RATHER THAN TWO. Two is a plinth with a block on it and
		-- still reads as built; three is where the eye stops counting and
		-- starts seeing a slope. Each step keeps 0.62 of the one under it and
		-- they lean off the axis, so the ridge line wanders instead of
		-- stacking into a pyramid -- deterministic from `seed`, like every
		-- other scatter out here, so the skyline is the same on every server.
		local shares = { 0.46, 0.32, 0.22 }
		local rise = 0
		local w, d = width, depth
		for step, share in ipairs(shares) do
			local tall = height * share
			-- Leans by up to a fifth of the step's own width, drawn off the
			-- seed so two neighbours never lean the same way.
			local lean = math.sin((seed * 7 + step) * 12.9898) * 43758.5453
			lean = (lean - math.floor(lean) - 0.5) * 0.4
			local sway = math.sin((seed * 13 + step) * 78.233) * 43758.5453
			sway = (sway - math.floor(sway) - 0.5) * 0.4
			scenery("Peak", Vector3.new(w, tall + 2, d),
				at * CFrame.new(w * lean, rise + (tall + 2) / 2 - 2, d * sway),
				if (seed + step) % 2 == 0 then FAR_ROCK else FAR_ROCK_2,
				Enum.Material.SmoothPlastic)
			rise += tall
			w, d = w * 0.62, d * 0.62
		end
		return
	end

	-- Buried a couple of studs so no face of the rock sits ON the turf it
	-- stands in.
	solid("Foothill", Vector3.new(width, height + 2, depth),
		at * CFrame.new(0, (height + 2) / 2 - 2, 0),
		if even then CLIFF_ROCK else CLIFF_ROCK_2, Enum.Material.SmoothPlastic)
	solid("FoothillCap", Vector3.new(width + 0.7, CLIFF_CAP, depth + 0.7),
		at * CFrame.new(0, height + CLIFF_CAP / 2 - 0.2, 0),
		if even then HILL_ROCK else HILL_ROCK_2, Enum.Material.LeafyGrass)
end

-- ONE SEEDED SOURCE FOR ALL FOUR RINGS, drawn in a fixed order, for the reason
-- the grass scatter and the valley wall are both seeded: every server builds
-- the identical horizon, so a screenshot taken today describes the map
-- somebody joins tomorrow.
local function buildHorizon()
	local rng = Random.new(20260918)
	local apronTop = GROUND_Y - APRON_LIFT
	local shelfTop = GROUND_Y - 27

	-- 1. THE APRON, tucked sixty studs back under the slab so the seam
	-- between them is buried rather than being a joint anybody can see.
	ringWalk(SLAB_X, SLAB_Z, 420, 150, function(x, z, along, out, i, spacing)
		landSegment(x, z, along, out, spacing, 60, 240 + rng:NextNumber() * 180,
			apronTop, 180, rng:NextNumber() * 1.2, i, true)
	end)

	-- 2. THE FOOTHILLS, standing on the apron four studs outside the slab and
	-- PUSHED OUT by half their own depth, so the inner face lands on that line
	-- rather than the middle of the rock.
	--
	-- On the two LONG sides that is the constraint rather than a nicety. The
	-- valley wall's deepest column already reaches the slab edge there
	-- (`edgeZ` is GROUND_SIZE.Y / 2 - 30, and a column is up to 30 deep), so
	-- there is no room at all between the wall and the edge -- a foothill
	-- centred on this line would stand THROUGH the wall and be visible from
	-- the street as a mass in front of it.
	ringWalk(SLAB_X + 4, SLAB_Z + 4, 130, 120, function(x, z, along, out, i, _spacing)
		local depth = 60 + rng:NextNumber() * 60
		horizonColumn(x + out.X * depth / 2, z + out.Y * depth / 2,
			150 + rng:NextNumber() * 70, depth, 44 + rng:NextNumber() * 52,
			apronTop, math.rad((rng:NextNumber() - 0.5) * 20), i, false)

		-- A low mound further out on about half of them. Without these the
		-- apron is a flat green ring, which from above is the fault this whole
		-- block is about, one ring along and two shades greener.
		if rng:NextNumber() < 0.5 then
			local size = 50 + rng:NextNumber() * 70
			local away = 150 + rng:NextNumber() * 190
			local sideways = (rng:NextNumber() - 0.5) * 120
			horizonColumn(
				x + out.X * away + along.X * sideways,
				z + out.Y * away + along.Y * sideways,
				size, size * (0.7 + rng:NextNumber() * 0.6),
				12 + rng:NextNumber() * 26, apronTop,
				math.rad(rng:NextNumber() * 90), i + 1, false)
		end
	end)

	-- 3. THE OUTER SHELF. `under` is 160 rather than an average, because it
	-- has to be buried beneath the apron at the apron's SHORTEST reach: the
	-- gap would otherwise open exactly where the raggedness was most
	-- interesting, which is the one place anybody would be looking.
	-- REACHING 460 TO 600 RATHER THAN 400 TO 540, because the range stands on
	-- this and its deepest column reaches 1075: at 400 the shallowest shelf
	-- segment ended at exactly 1090, so a peak's outer face could land on the
	-- shelf's own outer face -- two same-facing planes, both enormous, on the
	-- one silhouette the whole ring exists to draw. 1150 leaves 75 studs.
	ringWalk(SLAB_X + 300, SLAB_Z + 300, 600, 300, function(x, z, along, out, i, spacing)
		landSegment(x, z, along, out, spacing, 160, 460 + rng:NextNumber() * 140,
			shelfTop, 300, rng:NextNumber() * 1.2, i, false)
	end)

	-- 4. THE RANGE, on the shelf's rim. Stepped 200 against widths of 300 to
	-- 430, so every column overlaps its neighbour by at least a hundred studs
	-- -- unlike the foothills, a gap here is a hole with the sky behind it,
	-- because there is nothing beyond this ring to back one.
	-- The DEPTH is 150 to 250 rather than wider for the same reason the shelf
	-- got longer: a column is centred on the ring line, so its faces have to
	-- clear the shelf's outer edge on one side and the apron's on the other,
	-- and 125 either way is what fits between 810 and 1150.
	--
	-- THE HEIGHTS CAME DOWN FROM 150..300 AFTER LOOKING AT IT. Against a map
	-- 720 studs across, peaks of 300 standing 920 out filled most of the frame
	-- from any orbiting camera -- the world read as a ring of mountains with a
	-- village lost in the middle rather than as a valley. At 110..210 they are
	-- a skyline. Note this is only ever judged from OUTSIDE: measured from the
	-- street, the houses, shops and treeline shut the sightline long before
	-- the horizon, so none of this ring is visible from inside the map at all.
	ringWalk(SLAB_X + 560, SLAB_Z + 560, 0, 200, function(x, z, along, out, i, _spacing)
		horizonColumn(x, z, 300 + rng:NextNumber() * 130,
			150 + rng:NextNumber() * 100, 110 + rng:NextNumber() * 100,
			shelfTop, math.rad((rng:NextNumber() - 0.5) * 24), i, true)
	end)
end

local function buildHills(m: any)
	local loaded, builder = pcall(function() return require(ReplicatedStorage.Shared.MeadowBuilder) end)
	if loaded and builder.buildBorder(folder, m) then return end
	if not loaded then warn("[NeighborhoodService] meadow border unavailable: " .. tostring(builder)) end
	buildHill(m, m.tunnelEastX, 1)
	buildHill(m, m.tunnelWestX, -1)
	buildValley(m)
	buildHorizon()
end

-- THE VERGE IS GRASS, AND THERE IS NO PAVING ON IT.
--
-- The town square was a paved rectangle in a hole in the row; closing the row
-- took the hole, and the paving followed it out here as two asphalt aprons
-- under the boards. That was one move too many. A verge is grass -- the lamp
-- posts, the wheelie bins, the mailboxes and now the shops all stand on it
-- without a slab under them, and two rectangles of tarmac in the middle of it
-- read as the last piece of something that had been removed.
--
-- So the only paved things on this street are the ones that are actually
-- road: the carriageway, its kerbs and its centre line, and the driveways
-- each plot lays for itself. Everything else stands on grass.
--
-- The shops keep their own forecourts, which is a different thing: a building
-- meeting a lawn at a made edge is what a forecourt is for, and it belongs to
-- the unit rather than to the street.

-- FOUR SHOPS, ONE PER TAB, ON THE VERGE.
--
-- They stood on the shoulders of the town square, in the hole in the row.
-- With the row closed up they line the STREET instead, in the gaps between
-- driveways -- the same stretch of verge the lamp posts and wheelie bins
-- already use, and the one piece of ground here that belongs to no plot.
--
-- WHERE THEY FIT IS SOLVED, NOT CHOSEN, and the widening is what makes it
-- solvable at all:
--
--   * ACROSS: a driveway is DRIVEWAY_WIDTH on each plot centre, so between
--     two of them the clear gap is `PLOT_SPACING - DRIVEWAY_WIDTH` -- 67 studs
--     at the current spacing, against 51 before the plot was widened. A unit
--     20 across at the midpoint has 23.5 either side. Derived rather than
--     written down, because both of those constants have moved once already.
--   * BACK: the verge runs from the kerb at 8 to the fence line at 46.4. At
--     `shopZ` (fence less 12) the building spans 27..41 -- 5.4 studs off the
--     fence behind, and 12 of pavement in front of its forecourt, which is
--     where the lamp post and the bin stand at 9.8.
--
-- At 104 none of that fitted: the band was 18.4 studs and a unit would have
-- been standing in the carriageway to have its back against the fence.
-- WHAT EACH UNIT IS, not just what it is called.
--
-- `style` picks the roof line, the frontage and the lighting; `display` is
-- the REAL item that stands in its window, built by the same function that
-- puts one on a lawn or under a rider. That is the rule the shop cards
-- already follow -- render the actual thing, because a coloured square cannot
-- tell you what a skin looks like -- applied to a building.
--
-- The garden centre has no `display` on purpose: its style has an open front
-- rather than a window, because its stock IS the frontage.
-- WHAT EACH UNIT LOOKS LIKE, KEYED BY THE TAB ITS DOOR OPENS -- and WHERE
-- it stands is `Config.SHOPS`, which is a change rather than a tidy-up.
--
-- This table used to carry a `gap`, a `side` and a `name` of its own while
-- `Config` carried the same three for the till on each forecourt. Two copies
-- of one arrangement, and for as long as the pig stood outside they could
-- disagree by a stud without anybody noticing. They cannot now: the vault is
-- a PLOT built inside this shell, so a table one gap out of step would put a
-- robbable strongroom in an empty patch of verge and leave the unit next
-- door with nothing in it.
--
-- Style, colour and window display are appearance and stay here. Placement
-- is arithmetic the economy is priced against and lives in Config.
local SHOPS = {
	piggy = {
		style = "boutique", accent = Color3.fromRGB(226, 118, 156),
		-- The mini piggy, the same 11-part model the carried loot uses.
		display = function()
			return PiggyModel.build(Config.DEFAULT_SKIN)
		end,
	},
	home = {
		style = "garden", accent = Color3.fromRGB(104, 172, 116),
	},
	gear = {
		style = "wheels", accent = Color3.fromRGB(232, 162, 72),
		-- A real BMX off RideModel. 23 parts, and it is the machine a player
		-- can actually buy on the tab this door opens.
		display = function()
			return RideModel.build("bmx")
		end,
	},
	defend = {
		style = "security", accent = Color3.fromRGB(96, 146, 216),
		-- A Golden Bone under glass: the most expensive consumable in the
		-- game, and the one thing on this tab that reads at a glance.
		display = function()
			return BoneModel.build("golden", false)
		end,
	},
}

local function buildShops(_m: any)
	for _, placement in ipairs(Config.SHOPS) do
		-- `any`, because the four rows are not one shape -- the garden centre
		-- has an open front and therefore no `display` -- and a fallback row
		-- assigned into an inferred type is a strict-mode fight over a table
		-- that is Config data either way.
		local shop: any = SHOPS[placement.tab]
		if not shop then
			-- A shop with no look is a misconfiguration and losing the unit
			-- is worse than losing its style: it is a robbable plot, and
			-- `PlotService` will have built one inside a building that is not
			-- there. Loud, and it does not skip.
			warn("[NeighborhoodService] no style for shop tab " .. tostring(placement.tab))
			shop = { style = "boutique", accent = Color3.fromRGB(200, 200, 200) }
		end
		-- THE UNIT'S FRAME COMES FROM `Config`, WHICH IS THE SAME CALL
		-- `PlotService` MAKES. Two builders, one placement: the walls and the
		-- vault inside them cannot end up in different gaps, and neither can
		-- drift when the street is next widened.
		--
		-- It sits at the PAVEMENT, half a slab below the plot frame that
		-- shares it -- `ShopFront` measures its own bands from the ground it
		-- stands on.
		local placeAt = Config.shopUnitCFrame(placement)
		local _, _, prompt = ShopFront.build(
			placeAt * CFrame.new(0, GROUND_Y, 0),
			GROUND_Y,
			{
				name = placement.name, tab = placement.tab, accent = shop.accent,
				style = shop.style, display = shop.display,
			},
			folder)

		-- Wired HERE, on the server, at the moment the counter exists. The
		-- client cannot do this for itself: these are built during startup
		-- and a tag set before parenting never fires
		-- GetInstanceAddedSignal on a peer it replicates to. See ShopFront.
		--
		-- THE PROMPT IS AT THE COUNTER, INSIDE (designer, 2026-09-23), and the
		-- server re-asks the room on every press: a prompt's range is a
		-- distance and the room is a rectangle, the same reason the vault
		-- makes this check rather than trusting its own reach. The remote is
		-- still called `ShopDoor` -- it names the event "you reached a shop's
		-- place of business", and renaming it is three files for no behaviour.
		if prompt then
			prompt.Triggered:Connect(function(player)
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if not root or not root:IsA("BasePart") then
					return
				end
				if not Config.shopRoomHolds(placeAt, root.Position) then
					return
				end
				Remotes.get("ShopDoor"):FireClient(player, placement.tab)
			end)
		else
			warn(("[NeighborhoodService] %s has no counter prompt; that shop cannot be used."):format(placement.name))
		end
	end
end

-- ============================================================
-- THE GRASSLAND
-- ============================================================
--
-- Ponds, flower drifts, rocks and a log in the band the herds wander,
-- behind the back fences on both sides. `Shared/Grassland` owns the
-- geometry and the layout; this hands it the grove's trunks so nothing it
-- stands lands under a canopy or inside a trunk. Pcalled for the reason
-- `Decor.prewarm` is: a pond that fails to build is a bare patch of grass,
-- and a bare patch of grass may never stop the server starting.
local function buildGrassland()
	local ok, err = pcall(function()
		local _, ponds, count = Grassland.build(folder, grovePlacements)
		print(("[NeighborhoodService] Grassland: %d ponds, %d parts"):format(#ponds, count))
		for _, pond in ipairs(ponds) do
			print(("[NeighborhoodService]   pond side %+d at (%.1f, %.1f) r %.1f, rim %.1f studs clear of the canopies")
				:format(pond.side, pond.x, pond.z, pond.radius, pond.clear))
		end
	end)
	if not ok then
		warn("[NeighborhoodService] the grassland did not build: " .. tostring(err))
	end
end

function NeighborhoodService.start()
	local existing = workspace:FindFirstChild("Neighborhood")
	if existing then
		existing:Destroy()
	end

	folder = Instance.new("Folder")
	folder.Name = "Neighborhood"
	folder.Parent = workspace

	local m = metrics()
	buildRoad(m)
	buildTrees(m)
	-- After the trees, whose trunks it is laid out against.
	buildGrassland()
	buildStreetTrees(m)
	buildStreetFurniture(m)
	-- After the furniture, so the band above can be read against what is
	-- actually standing on the verge rather than against what was meant to be.
	buildVergeGrass(m)
	buildHills(m)
	buildShops(m)

	print(("[NeighborhoodService] Built %d scenery parts, %d trunk colliders"):format(
		#folder:GetChildren(), #trunkColliders))
end

-- True inside a trunk collider's footprint plus a piggy's own radius
-- (`Config.TREES.margin`). XZ only, like `Grassland.blocks`: the herd asks
-- with a point at its own body height and a bole is upright. Registered
-- with HerdService in Main; a pack then paths round a trunk through the
-- segment sampling it already does. Canopies are deliberately NOT in this:
-- a canopy veto would blanket the whole band the herds wander.
function NeighborhoodService.treeBlocks(position: Vector3): boolean
	local margin = Config.TREES.margin
	for _, trunk in ipairs(trunkColliders) do
		local dx, dz = position.X - trunk.x, position.Z - trunk.z
		local keep = trunk.radius + margin
		if dx * dx + dz * dz <= keep * keep then
			return true
		end
	end
	return false
end

-- Where every trunk collider stands and how wide its bole is, for anything
-- that wants to measure the street against the trees that are actually there.
function NeighborhoodService.trunkColliders(): { TrunkFootprint }
	return trunkColliders
end

-- The grove and the verge trees alone, into a parent of the caller's: the
-- two calls `start` makes either side of the grassland, exposed so the trees
-- suite can build the real layout under an engine stub and measure it.
function NeighborhoodService.plantTrees(parent: Folder)
	folder = parent
	local m = metrics()
	buildTrees(m)
	buildStreetTrees(m)
end

return NeighborhoodService
