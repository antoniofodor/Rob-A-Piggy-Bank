--!strict
--[[
	BoneModel

	What a bone looks like, built once and used from both sides.

	This lives in ReplicatedStorage rather than beside BoneService because the
	same geometry has to appear in two places: the thing that lands on the lawn
	(server) and the icon on the shop tile and quick-throw slot (client, inside
	a ViewportFrame). Two builders would drift, and the icon has to be the item
	-- a shop picture that does not match what gets thrown is worse than no
	picture at all.

	Built centred on the origin and unrotated, so a caller can pivot it wherever
	it wants and a camera can frame it from its bounding box without knowing
	anything about which style it got.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local BoneModel = {}

local BONE_WHITE = Color3.fromRGB(240, 236, 220)
local FAT = Color3.fromRGB(232, 208, 188)

type Add = (name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material) -> Part

local builders: { [string]: (any, Add) -> () } = {}

-- The classic two-knuckle bone. A cylinder shaft rather than a block, because
-- at icon size the silhouette is all there is to read.
--
-- The shaft is yawed a quarter turn on purpose: a Roblox cylinder has its flat
-- faces on X, so its length lives in Size.X and the part has to be rotated to
-- lay that axis down Z. Skipping the rotation gives a coin standing on edge.
builders.bone = function(spec, add)
	local shaft = add("Shaft", Vector3.new(2.0, 0.52, 0.52),
		CFrame.Angles(0, math.pi / 2, 0), spec.colour, spec.material)
	shaft.Shape = Enum.PartType.Cylinder

	for _, z in ipairs({ -1.0, 1.0 }) do
		for _, x in ipairs({ -0.27, 0.27 }) do
			local knuckle = add("Knuckle", Vector3.new(0.68, 0.68, 0.68),
				CFrame.new(x, 0, z), spec.colour, spec.material)
			knuckle.Shape = Enum.PartType.Ball
		end
	end
end

-- A chop: a thick, irregular cut of meat with the rib bone sticking out of one
-- end. Deliberately not a bone in a different colour -- at 48 pixels the only
-- thing separating two items is their outline, so the mid tier gets a
-- different one.
--
-- The first attempt was a flat slab with a small rib and read as a red brick.
-- What fixed it was thickness, a rounded end so the silhouette is not a
-- rectangle, and a rib big enough to survive being drawn at icon size.
builders.steak = function(spec, add)
	-- Long axis on Z, exactly like the bone's shaft.
	--
	-- This is the whole reason the first two attempts read as a brick. The
	-- icon camera sits out on +Z, so anything running along Z is broadside to
	-- it and anything running along X points at it. The meat was long on X
	-- with the rib poking out on +Z -- straight down the barrel of the lens,
	-- foreshortened to a white dot. Turning the cut a quarter turn puts the
	-- rib across the view where it can be seen.
	add("Meat", Vector3.new(1.25, 0.8, 1.7), CFrame.new(), spec.colour, spec.material)

	-- Rounds off the far end, so the outline is a cut of meat, not a box.
	local lobe = add("Lobe", Vector3.new(1.15, 0.8, 1.15),
		CFrame.new(-0.05, 0, -0.72), spec.colour, spec.material)
	lobe.Shape = Enum.PartType.Ball

	-- Rim of fat down one long edge, and a paler marbled top.
	add("Fat", Vector3.new(0.3, 0.32, 1.6), CFrame.new(0.58, 0.24, 0.05), FAT, spec.material)
	add("Marble", Vector3.new(0.7, 0.14, 1.15), CFrame.new(-0.05, 0.4, 0.1),
		Color3.fromRGB(206, 108, 96), spec.material)

	-- The rib, continuing that long axis out of the near end. Sized to about a
	-- third of the whole silhouette: any smaller and it disappeared into the
	-- meat at icon size.
	local rib = add("Rib", Vector3.new(1.15, 0.34, 0.34),
		CFrame.new(0, -0.14, 1.3) * CFrame.Angles(0, math.pi / 2, 0), BONE_WHITE, spec.material)
	rib.Shape = Enum.PartType.Cylinder

	local nub = add("RibEnd", Vector3.new(0.5, 0.5, 0.5),
		CFrame.new(0, -0.14, 1.82), BONE_WHITE, spec.material)
	nub.Shape = Enum.PartType.Ball
end

-- `glow` adds a PointLight, which is wanted on the thing lying in the grass and
-- pointless inside a ViewportFrame -- a viewport lights its contents from its
-- own Ambient and LightDirection and ignores lights in the scene.
function BoneModel.build(key: string, glow: boolean?): Model
	local spec = Config.BONES[key]
	assert(spec, ("Unknown bone '%s'"):format(tostring(key)))

	local model = Instance.new("Model")
	model.Name = "Bone_" .. key

	local first: Part? = nil
	local function add(name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Anchored = true
		-- Never collides, never answers a raycast. A bone lies on exactly the
		-- strip of lawn a chase runs across; the one thing it must not do is
		-- body-block the dog it just baited.
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Color = colour
		p.Material = material
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		if not first then
			first = p
		end
		return p
	end

	local build = builders[spec.style] or builders.bone
	build(spec, add)

	local root = assert(first, "a bone builder must add at least one part")

	-- Pivot on the VISUAL centre, with no PrimaryPart.
	--
	-- A Model's pivot is its PrimaryPart's CFrame when it has one, and the
	-- obvious PrimaryPart here -- the shaft -- carries the quarter-turn that
	-- lays it down Z. PivotTo would then have replaced that rotation instead
	-- of adding to it, so the icon would spin around a point off to one side
	-- and the steak, whose rib pushes its centre forward, would wobble.
	-- WorldPivot only applies while PrimaryPart is nil, which is why it is.
	local box = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(box.Position)

	if glow then
		local light = Instance.new("PointLight")
		light.Color = spec.colour
		light.Brightness = 1.4
		light.Range = 10
		light.Parent = root
	end

	return model
end

return BoneModel
