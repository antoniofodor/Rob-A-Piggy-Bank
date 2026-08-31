--!strict
--[[
	GadgetModel

	What each defensive gadget looks like, built once and used from both sides
	-- the object in flight (server) and the shop tile and hotbar slot (client,
	inside a ViewportFrame). Same reason BoneModel, PigGear and RideModel are
	shared: two builders drift, and a picture that does not match the thing you
	throw is worse than no picture.

	Every one is built around the ORIGIN, small enough to read at 48 pixels in
	a hotbar slot and at twenty studs in the air. That second constraint is the
	real one: these spend most of their visible life mid-arc against the sky,
	where anything subtle is a dot. Each has one loud silhouette feature -- a
	red cup, a pink sphere, a pair of glowing prongs -- and nothing else that
	matters.

	Nothing here collides or answers a raycast. A gadget in flight must never
	body-block the chase it is part of.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local GadgetModel = {}

type Add = (name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?) -> Part

-- A Roblox cylinder's flat faces are on X, so standing one up is a quarter
-- turn about Z and the LENGTH goes in the X component. Written the other way
-- round it becomes a disc as wide as it was tall.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local builders: { [string]: (any, Add) -> () } = {}

builders.plunger = function(spec, add)
	-- The cup is the whole silhouette, so it is oversized relative to a real
	-- plunger. At the range this is actually seen, a correctly proportioned
	-- one reads as a stick.
	local cup = add("Cup", Vector3.new(1.5, 1.9, 1.9), CFrame.new(0, -0.5, 0) * UPRIGHT, spec.colour)
	cup.Shape = Enum.PartType.Cylinder

	local lip = add("Lip", Vector3.new(0.4, 2.2, 2.2), CFrame.new(0, -1.15, 0) * UPRIGHT, spec.colour)
	lip.Shape = Enum.PartType.Cylinder

	local handle = add("Handle", Vector3.new(2.8, 0.45, 0.45), CFrame.new(0, 1.0, 0) * UPRIGHT,
		spec.trim, Enum.Material.Wood)
	handle.Shape = Enum.PartType.Cylinder

	add("Grip", Vector3.new(0.6, 0.3, 0.6), CFrame.new(0, 2.35, 0), spec.trim, Enum.Material.Wood)
end

builders.gum = function(spec, add)
	local ball = add("Wad", Vector3.new(1.9, 1.9, 1.9), CFrame.new(), spec.colour)
	ball.Shape = Enum.PartType.Ball

	-- Lighter blobs stuck to it, so it reads as chewed rather than as a
	-- billiard ball. Three is enough; more just makes it lumpy.
	for i = 0, 2 do
		local a = (i / 3) * math.pi * 2
		local blob = add("Blob", Vector3.new(0.85, 0.85, 0.85),
			CFrame.new(math.sin(a) * 0.75, math.cos(a) * 0.55, 0.55), spec.trim)
		blob.Shape = Enum.PartType.Ball
	end

	-- The wrapper twist: the one bit that says this was a sweet a moment ago.
	for _, sx in ipairs({ 1, -1 }) do
		add("Twist", Vector3.new(0.7, 0.5, 0.14), CFrame.new(sx * 1.25, 0, 0)
			* CFrame.Angles(0, 0, math.rad(sx * 22)), spec.trim)
	end
end

builders.zapper = function(spec, add)
	add("Body", Vector3.new(1.0, 1.5, 0.75), CFrame.new(0, 0, 0), spec.colour)
	add("Grip", Vector3.new(0.8, 1.2, 0.6), CFrame.new(0, -1.15, -0.15)
		* CFrame.Angles(math.rad(14), 0, 0), Color3.fromRGB(32, 34, 42))

	-- Two prongs and the arc between them. The arc is the only part anyone
	-- can see at range, so it is the biggest neon thing on the model.
	for _, sx in ipairs({ 0.3, -0.3 }) do
		local prong = add("Prong", Vector3.new(1.1, 0.16, 0.16),
			CFrame.new(sx, 1.25, 0) * UPRIGHT, Color3.fromRGB(206, 210, 218), Enum.Material.Metal)
		prong.Shape = Enum.PartType.Cylinder
	end
	add("Arc", Vector3.new(0.85, 0.3, 0.22), CFrame.new(0, 1.85, 0), spec.trim, Enum.Material.Neon)
	add("Spark", Vector3.new(0.28, 0.7, 0.2), CFrame.new(0, 1.95, 0)
		* CFrame.Angles(0, 0, math.rad(30)), spec.trim, Enum.Material.Neon)

	add("Light", Vector3.new(0.34, 0.2, 0.12), CFrame.new(0, 0.45, 0.42), spec.trim, Enum.Material.Neon)
end

-- `glow` is for the one in flight, which has to be visible against a dark
-- street. The shop icon asks for the same model without it: a ViewportFrame
-- ignores lights in the scene, so it would be cost with no picture.
function GadgetModel.build(key: string, glow: boolean): Model
	local spec = Config.GADGETS[key]
	assert(spec, ("Unknown gadget '%s'"):format(tostring(key)))

	local model = Instance.new("Model")
	model.Name = "Gadget_" .. key

	local first: Part? = nil
	local function add(name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		-- Anchored and lerped, never simulated -- see GadgetService.arc for
		-- why nothing thrown in this game is left to physics.
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
		first = first or p
		return p
	end

	local build = builders[spec.style]
	assert(build, ("Gadget '%s' has no builder for style '%s'"):format(key, tostring(spec.style)))
	build(spec, add)

	if glow and first then
		local light = Instance.new("PointLight")
		light.Color = spec.trim
		light.Brightness = 1.6
		light.Range = 12
		light.Parent = first
	end

	-- Pivot at the authored origin, so GadgetService can fly it without
	-- guessing where its middle is. No PrimaryPart: several parts here are
	-- rotated, and a PrimaryPart pivot REPLACES that rotation on the first
	-- PivotTo rather than adding to it.
	model.WorldPivot = CFrame.new()

	return model
end

return GadgetModel
