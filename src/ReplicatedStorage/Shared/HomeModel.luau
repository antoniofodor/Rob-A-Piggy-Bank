--!strict
--[[
	HomeModel

	The two things you use on your own plot: the dog's guard-duty treat and the
	garden sprinkler. Shared for the same reason every other model here is --
	the shop tile, the hotbar slot and the object in the world all come from
	one builder, so the picture cannot drift from the thing.

	Built around the ORIGIN. The sprinkler is authored with y = 0 at the
	ground, since it stands on a lawn; the treat has no world placement at all
	and is only ever an icon, so it is simply centred.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local HomeModel = {}

type Add = (name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?) -> Part

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local builders: { [string]: (any, Add) -> () } = {}

builders.treat = function(spec, add)
	local BISCUIT = Color3.fromRGB(198, 146, 84)
	local ICING = Color3.fromRGB(238, 210, 160)

	-- A bone-shaped biscuit: a bar with a pair of lobes at each end. Reads as
	-- a dog treat at 48 pixels, which is the only size it is ever seen at.
	add("Bar", Vector3.new(2.4, 0.7, 0.7), CFrame.new(), BISCUIT)
	for _, sx in ipairs({ 1.2, -1.2 }) do
		for _, sy in ipairs({ 0.42, -0.42 }) do
			local lobe = add("Lobe", Vector3.new(0.95, 0.95, 0.8), CFrame.new(sx, sy, 0), BISCUIT)
			lobe.Shape = Enum.PartType.Ball
		end
	end

	-- A stripe of icing, so it is a TREAT and not the bone you throw at
	-- somebody else's dog. Those two do opposite things and must not look
	-- alike in a hotbar.
	add("Icing", Vector3.new(1.5, 0.16, 0.74), CFrame.new(0, 0.34, 0), ICING)
	add("Heart", Vector3.new(0.42, 0.42, 0.8), CFrame.new(0, 0.42, 0)
		* CFrame.Angles(0, 0, math.rad(45)), Color3.fromRGB(226, 96, 118))
end

builders.sprinkler = function(spec, add)
	local METAL = Color3.fromRGB(148, 154, 164)
	local GREEN = Color3.fromRGB(74, 132, 72)

	-- Stands on the lawn: y = 0 is the base plate.
	local base = add("Base", Vector3.new(0.4, 2.6, 2.6), CFrame.new(0, 0.2, 0) * UPRIGHT, GREEN)
	base.Shape = Enum.PartType.Cylinder

	local post = add("Post", Vector3.new(2.0, 0.5, 0.5), CFrame.new(0, 1.4, 0) * UPRIGHT, METAL,
		Enum.Material.Metal)
	post.Shape = Enum.PartType.Cylinder

	-- The spinning head, and three arms for it to fling water off. Static
	-- here; the service animates the one it puts on the lawn.
	local head = add("Head", Vector3.new(0.7, 1.1, 1.1), CFrame.new(0, 2.5, 0) * UPRIGHT, METAL,
		Enum.Material.Metal)
	head.Shape = Enum.PartType.Cylinder

	for i = 0, 2 do
		local a = (i / 3) * math.pi * 2
		add("Arm", Vector3.new(1.5, 0.18, 0.18),
			CFrame.new(math.sin(a) * 0.75, 2.5, math.cos(a) * 0.75) * CFrame.Angles(0, -a, 0),
			METAL, Enum.Material.Metal)
	end
	add("Nozzle", Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 2.95, 0),
		Color3.fromRGB(120, 200, 240), Enum.Material.Neon)
end

function HomeModel.build(key: string): Model
	local spec = Config.HOME_ITEMS[key]
	assert(spec, ("Unknown home item '%s'"):format(tostring(key)))

	local model = Instance.new("Model")
	model.Name = "Home_" .. key

	local function add(name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Anchored = true
		-- Nothing on a lawn may body-block a defender, a thief or the dog --
		-- the same rule every decoration follows, and for the same reason.
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
	assert(build, ("Home item '%s' has no builder for style '%s'"):format(key, tostring(spec.style)))
	build(spec, add)

	-- Authored origin, never the bounding-box centre: the sprinkler is placed
	-- by its feet on a lawn. No PrimaryPart -- several parts are rotated, and
	-- a PrimaryPart pivot REPLACES that rotation on the first PivotTo.
	model.WorldPivot = CFrame.new()

	return model
end

return HomeModel
