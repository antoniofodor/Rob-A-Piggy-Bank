--!strict
--[[
	ThiefModel

	Icons for the two thief consumables.

	Note what these are pictures OF. The disguise turns you into a wheelie bin,
	but the bin is built by Decor -- which lives in ServerScriptService and the
	client cannot reach -- and copying its builder here would be the second
	version that drifts from the first the moment either is touched. So the
	tile shows the KIT rather than its effect: a canvas holdall you buy, with
	the tab text saying what comes out of it.

	That is honest rather than a workaround. You are buying a kit; the bin is
	what it does. The raincoat is the same shape of thing, and it is genuinely
	the object.

	Built around the ORIGIN and only ever seen in a ViewportFrame, so there is
	no ground line to respect here -- unlike RideModel, which is placed in the
	world and is authored feet-first.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ThiefModel = {}

type Add = (name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?) -> Part

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local builders: { [string]: (any, Add) -> () } = {}

builders.disguise = function(spec, add)
	local CANVAS = Color3.fromRGB(96, 104, 88)
	local STRAP = Color3.fromRGB(58, 46, 34)

	-- A holdall: a rounded body with a strap over it. The lumps at each end do
	-- most of the work -- a plain box reads as a crate.
	add("Bag", Vector3.new(3.0, 1.6, 1.6), CFrame.new(), CANVAS)
	for _, sx in ipairs({ 1, -1 }) do
		local endCap = add("End", Vector3.new(1.55, 1.55, 1.55), CFrame.new(sx * 1.5, 0, 0), CANVAS)
		endCap.Shape = Enum.PartType.Ball
	end

	add("Strap", Vector3.new(0.5, 1.7, 1.7), CFrame.new(-0.3, 0, 0), STRAP, Enum.Material.Leather)
	add("Handle", Vector3.new(1.4, 0.18, 0.18), CFrame.new(0, 1.0, 0), STRAP, Enum.Material.Leather)
	for _, sx in ipairs({ 0.6, -0.6 }) do
		add("Grip", Vector3.new(0.18, 0.5, 0.18), CFrame.new(sx, 0.75, 0), STRAP, Enum.Material.Leather)
	end

	-- A bin lid poking out of the top, which is the only hint on the model of
	-- what is actually inside it.
	local lid = add("Lid", Vector3.new(0.22, 1.3, 1.3), CFrame.new(0.7, 0.95, 0.2) * UPRIGHT,
		Color3.fromRGB(64, 92, 142))
	lid.Shape = Enum.PartType.Cylinder
end

builders.raincoat = function(spec, add)
	local COAT = Color3.fromRGB(238, 196, 62)
	local TRIM = Color3.fromRGB(52, 58, 72)

	-- Yellow, because a raincoat that is not yellow has to be explained.
	add("Body", Vector3.new(2.2, 2.4, 1.1), CFrame.new(0, -0.2, 0), COAT)
	for _, sx in ipairs({ 1, -1 }) do
		add("Sleeve", Vector3.new(0.75, 1.9, 0.95),
			CFrame.new(sx * 1.4, -0.1, 0) * CFrame.Angles(0, 0, math.rad(sx * 10)), COAT)
	end

	-- The hood is the silhouette. Without it this is a yellow rectangle.
	local hood = add("Hood", Vector3.new(1.7, 1.7, 1.7), CFrame.new(0, 1.3, -0.1), COAT)
	hood.Shape = Enum.PartType.Ball
	add("Brim", Vector3.new(1.5, 0.28, 0.8), CFrame.new(0, 1.1, 0.75), COAT)

	add("Placket", Vector3.new(0.28, 2.4, 0.14), CFrame.new(0, -0.2, 0.56), TRIM)
	for i = -1, 1 do
		add("Button", Vector3.new(0.24, 0.24, 0.14), CFrame.new(0, -0.2 + i * 0.7, 0.62), TRIM)
	end
end

function ThiefModel.build(key: string): Model
	local spec = Config.THIEF_KIT[key]
	assert(spec, ("Unknown thief item '%s'"):format(tostring(key)))

	local model = Instance.new("Model")
	model.Name = "Thief_" .. key

	local function add(name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Color = colour
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	local build = builders[spec.style]
	assert(build, ("Thief item '%s' has no builder for style '%s'"):format(key, tostring(spec.style)))
	build(spec, add)

	-- No PrimaryPart: some of these parts are rotated, and a PrimaryPart pivot
	-- REPLACES that rotation on the first PivotTo rather than adding to it.
	model.WorldPivot = CFrame.new()

	return model
end

return ThiefModel
