--!strict
--[[
	Decor

	Builds the lawn ornaments a player has bought, from the style keys in
	Config.DECOR_ITEMS. Same pattern as House and the fence styles: a table of
	small builders, so a new ornament is a Config entry plus one function.

	NOTHING here collides, is queryable, or casts a shadow.

	That is a hard rule rather than a preference. These sit on the exact ground
	an owner defends and a thief runs across, so a solid fountain would be a
	pillar in the middle of a chase and a solid car would wall off the gate.
	They are things to look at, and that is all they are.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Decor = {}

local folder: Model

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
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

local function ball(name: string, size: number, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = part(name, Vector3.new(size, size, size), cf, color, material)
	p.Shape = Enum.PartType.Ball
	return p
end

local function cylinderY(name: string, height: number, diameter: number, cf: CFrame,
	color: Color3, material: Enum.Material): Part
	-- Roblox cylinders have their flat faces on X, so an upright one is rolled
	-- 90 degrees about Z and takes its length from the X component.
	local p = part(name, Vector3.new(height, diameter, diameter),
		cf * CFrame.Angles(0, 0, math.rad(90)), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- ============================================================
-- STYLES
-- ============================================================

local builders: { [string]: (any, CFrame) -> () } = {}

builders.flowers = function(item, at)
	part("Bed", Vector3.new(7, 0.8, 4.4), at * CFrame.new(0, 0.4, 0),
		Color3.fromRGB(96, 68, 48), Enum.Material.WoodPlanks)
	part("Soil", Vector3.new(6.2, 0.3, 3.6), at * CFrame.new(0, 0.85, 0),
		Color3.fromRGB(64, 48, 38), Enum.Material.Ground)

	local palette = {
		Color3.fromRGB(226, 96, 118),
		Color3.fromRGB(246, 196, 84),
		Color3.fromRGB(158, 122, 220),
		Color3.fromRGB(246, 246, 240),
	}
	local i = 0
	for x = -2.4, 2.4, 1.2 do
		for z = -1.1, 1.1, 1.1 do
			i += 1
			part("Stem", Vector3.new(0.16, 1.1, 0.16), at * CFrame.new(x, 1.5, z),
				Color3.fromRGB(88, 138, 74), Enum.Material.Grass)
			ball("Bloom", 0.8, at * CFrame.new(x, 2.15, z), palette[(i % #palette) + 1], Enum.Material.SmoothPlastic)
		end
	end
end

builders.picnic = function(item, at)
	local WOOD = Color3.fromRGB(168, 124, 82)
	part("Top", Vector3.new(7, 0.4, 3.2), at * CFrame.new(0, 3, 0), WOOD, Enum.Material.WoodPlanks)
	for _, side in ipairs({ -1, 1 }) do
		part("Bench", Vector3.new(7, 0.35, 1.2), at * CFrame.new(0, 1.8, side * 2.6), WOOD, Enum.Material.WoodPlanks)
		part("Leg", Vector3.new(0.4, 3, 3.2), at * CFrame.new(side * 3, 1.5, 0), WOOD, Enum.Material.Wood)
		part("BenchLeg", Vector3.new(0.35, 1.8, 0.35), at * CFrame.new(side * 2.4, 0.9, side * 2.6), WOOD, Enum.Material.Wood)
	end

	-- Parasol: the bit that makes it read as a picnic set from a distance.
	cylinderY("Pole", 8, 0.35, at * CFrame.new(0, 4, 0), Color3.fromRGB(120, 116, 110), Enum.Material.Metal)
	for i = 0, 5 do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Shade"
		wedge.Size = Vector3.new(3.4, 1.2, 3.4)
		wedge.CFrame = at * CFrame.new(0, 7.4, 0) * CFrame.Angles(0, math.rad(i * 60), 0) * CFrame.new(1.5, 0, 0)
		wedge.Anchored, wedge.CanCollide, wedge.CanQuery, wedge.CastShadow = true, false, false, false
		wedge.Color = if i % 2 == 0 then Color3.fromRGB(226, 96, 96) else Color3.fromRGB(244, 240, 232)
		wedge.Material = Enum.Material.Fabric
		wedge.Parent = folder
	end
end

builders.hoop = function(item, at)
	cylinderY("Post", 13, 0.7, at * CFrame.new(0, 6.5, -0.6), Color3.fromRGB(72, 74, 80), Enum.Material.Metal)
	part("Board", Vector3.new(6.4, 4.2, 0.35), at * CFrame.new(0, 12, 0),
		Color3.fromRGB(240, 240, 236), Enum.Material.SmoothPlastic)
	part("BoardBox", Vector3.new(2.6, 1.9, 0.45), at * CFrame.new(0, 11.4, 0.06),
		Color3.fromRGB(220, 80, 60), Enum.Material.SmoothPlastic)

	-- Rim as four short bars rather than a torus, which Roblox has no
	-- primitive for and which nobody will look at closely enough to miss.
	local RIM = Color3.fromRGB(232, 116, 46)
	for i = 0, 3 do
		part("Rim", Vector3.new(1.5, 0.22, 0.22),
			at * CFrame.new(0, 10.2, 1.1) * CFrame.Angles(0, math.rad(i * 45), 0),
			RIM, Enum.Material.Metal)
	end
	part("Net", Vector3.new(1.6, 1.4, 1.6), at * CFrame.new(0, 9.5, 1.1),
		Color3.fromRGB(238, 238, 238), Enum.Material.Fabric).Transparency = 0.45
end

builders.topiary = function(item, at)
	local LEAF = Color3.fromRGB(84, 138, 72)
	part("Pot", Vector3.new(3.4, 1.6, 3.4), at * CFrame.new(0, 0.8, 0),
		Color3.fromRGB(158, 108, 82), Enum.Material.Slate)

	-- A pig, in hedge form: body, snout, ears, four stubby legs.
	ball("Body", 4.4, at * CFrame.new(0, 4.2, 0), LEAF, Enum.Material.Grass)
	ball("Snout", 1.5, at * CFrame.new(0, 3.9, 2.1), LEAF, Enum.Material.Grass)
	for _, side in ipairs({ -1, 1 }) do
		part("Ear", Vector3.new(0.9, 1.1, 0.5), at * CFrame.new(side * 1.1, 6, 1.2), LEAF, Enum.Material.Grass)
		for _, front in ipairs({ 1.2, -1.2 }) do
			part("Leg", Vector3.new(0.8, 1.6, 0.8), at * CFrame.new(side * 1.2, 2.2, front), LEAF, Enum.Material.Grass)
		end
	end
	ball("Tail", 0.7, at * CFrame.new(0, 4.6, -2.3), LEAF, Enum.Material.Grass)
end

builders.fountain = function(item, at)
	local STONE = Color3.fromRGB(198, 198, 190)
	local WATER = Color3.fromRGB(96, 164, 210)

	part("Basin", Vector3.new(9, 1.4, 9), at * CFrame.new(0, 0.7, 0), STONE, Enum.Material.Slate)
	local pool = part("Pool", Vector3.new(7.6, 0.4, 7.6), at * CFrame.new(0, 1.5, 0), WATER, Enum.Material.SmoothPlastic)
	pool.Transparency = 0.3
	pool.Reflectance = 0.2

	cylinderY("Stem", 3.4, 1.6, at * CFrame.new(0, 3.2, 0), STONE, Enum.Material.Slate)
	cylinderY("Dish", 0.7, 5, at * CFrame.new(0, 5, 0), STONE, Enum.Material.Slate)
	cylinderY("Stem2", 2.4, 1, at * CFrame.new(0, 6.4, 0), STONE, Enum.Material.Slate)
	local top = cylinderY("Cap", 0.6, 2.8, at * CFrame.new(0, 7.7, 0), STONE, Enum.Material.Slate)

	local spray = Instance.new("ParticleEmitter")
	spray.Name = "Spray"
	spray.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	spray.Color = ColorSequence.new(Color3.fromRGB(214, 240, 255), WATER)
	spray.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	spray.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	spray.Lifetime = NumberRange.new(0.8, 1.3)
	spray.Rate = 26
	spray.Speed = NumberRange.new(6, 9)
	spray.SpreadAngle = Vector2.new(22, 22)
	spray.Acceleration = Vector3.new(0, -22, 0)
	spray.LightEmission = 0.5
	spray.Parent = top
end

builders.bins = function(item, at)
	for i, spec in ipairs({
		{ x = -1.6, colour = Color3.fromRGB(72, 128, 88) },
		{ x = 1.6, colour = Color3.fromRGB(64, 92, 142) },
	}) do
		part("Bin", Vector3.new(2.4, 3.4, 2.2), at * CFrame.new(spec.x, 1.7, 0),
			spec.colour, Enum.Material.SmoothPlastic)
		part("Lid", Vector3.new(2.6, 0.35, 2.4), at * CFrame.new(spec.x, 3.5, 0),
			spec.colour, Enum.Material.SmoothPlastic)
		part("BinWheel", Vector3.new(0.4, 0.5, 0.5), at * CFrame.new(spec.x, 0.25, -0.9),
			Color3.fromRGB(34, 34, 38), Enum.Material.SmoothPlastic)
	end
end

builders.gnome = function(item, at)
	local RED = Color3.fromRGB(206, 68, 62)
	local SKIN = Color3.fromRGB(238, 198, 168)
	part("Plinth", Vector3.new(2, 0.5, 2), at * CFrame.new(0, 0.25, 0),
		Color3.fromRGB(170, 168, 160), Enum.Material.Slate)
	part("Robe", Vector3.new(1.5, 1.6, 1.5), at * CFrame.new(0, 1.3, 0), RED, Enum.Material.SmoothPlastic)
	ball("Head", 1.1, at * CFrame.new(0, 2.5, 0), SKIN, Enum.Material.SmoothPlastic)
	ball("Beard", 0.9, at * CFrame.new(0, 2.2, 0.45), Color3.fromRGB(242, 242, 238), Enum.Material.SmoothPlastic)

	-- Cone hat, as a stack of shrinking discs. Roblox has no cone primitive
	-- and nobody looks at a gnome closely enough to notice.
	for i = 0, 3 do
		cylinderY("Hat", 0.45, 1.2 - i * 0.28, at * CFrame.new(0, 3.05 + i * 0.4, 0), RED, Enum.Material.SmoothPlastic)
	end
end

builders.car = function(item, at)
	local body = item.body or Color3.fromRGB(160, 160, 170)
	local sporty = item.sporty == true

	local length = if sporty then 13 else 11.5
	local width = if sporty then 5.6 else 5
	local cabinH = if sporty then 1.9 else 2.6

	-- Everything is measured up from the WHEEL, because the wheel is what
	-- touches the ground. Driving the layout off a separate "ride height"
	-- left the whole car hovering: the wheels ended up 0.6 studs clear of the
	-- tarmac and nothing in the builder noticed.
	local wheelR = if sporty then 1.15 else 1.3
	local chassis = wheelR * 2 - 0.6 -- body bottom, slightly below axle height
	local bodyH = 2.2
	local bodyY = chassis + bodyH / 2
	local roofY = chassis + bodyH

	part("Body", Vector3.new(width, bodyH, length), at * CFrame.new(0, bodyY, 0),
		body, Enum.Material.SmoothPlastic)
	part("Cabin", Vector3.new(width - 0.7, cabinH, length * 0.45),
		at * CFrame.new(0, roofY + cabinH / 2, -0.4), body, Enum.Material.SmoothPlastic)

	local glass = part("Glass", Vector3.new(width - 0.4, cabinH - 0.7, length * 0.44),
		at * CFrame.new(0, roofY + cabinH / 2, -0.4),
		Color3.fromRGB(52, 68, 84), Enum.Material.Glass)
	glass.Reflectance = 0.3

	-- No extra rotation. A Roblox cylinder already has its flat faces on X,
	-- which for a car facing +Z is exactly the axle direction. Rolling it 90
	-- degrees about Z stood each wheel up as a flat disc lying on its side.
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ 1, -1 }) do
			local wheel = part("Wheel", Vector3.new(1.1, wheelR * 2, wheelR * 2),
				at * CFrame.new(sx * (width / 2 - 0.2), wheelR, sz * (length * 0.3)),
				Color3.fromRGB(28, 28, 32), Enum.Material.SmoothPlastic)
			wheel.Shape = Enum.PartType.Cylinder
		end
	end

	part("Light", Vector3.new(width - 1.6, 0.6, 0.3),
		at * CFrame.new(0, bodyY, length / 2), Color3.fromRGB(255, 246, 214), Enum.Material.Neon)
	part("TailLight", Vector3.new(width - 1.6, 0.5, 0.3),
		at * CFrame.new(0, bodyY, -length / 2), Color3.fromRGB(226, 60, 48), Enum.Material.Neon)

	if sporty then
		part("Spoiler", Vector3.new(width - 0.6, 0.3, 1.4),
			at * CFrame.new(0, roofY + 1.1, -length / 2 + 0.9), body, Enum.Material.SmoothPlastic)
		for _, sx in ipairs({ -1, 1 }) do
			part("SpoilerLeg", Vector3.new(0.3, 1, 0.5),
				at * CFrame.new(sx * (width / 2 - 1), roofY + 0.6, -length / 2 + 0.9),
				body, Enum.Material.SmoothPlastic)
		end
	end
end

-- ============================================================
-- BUILD
-- ============================================================

-- Rebuilds every placed ornament for a plot. `placed` maps slot id -> item key.
--
-- `groundByZone` matters more than it looks. A plot is three different heights:
-- the lawn is the top of the plot slab, the driveway is paving laid on the
-- world ground, and the verge is the bare world ground half a stud lower
-- still. Using one height for all three left every car and bin hovering.
function Decor.build(placed: { [string]: string }, originCF: CFrame,
	groundByZone: { [string]: number }, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Decor"
	folder = model

	for _, slot in ipairs(Config.DECOR_SLOTS) do
		local key = placed[slot.id]
		local item = key and Config.DECOR_ITEMS[key]
		if item then
			local build = builders[item.style]
			if build then
				local groundY = groundByZone[slot.zone] or 0
			local at = originCF
					* CFrame.new(slot.offset + Vector3.new(0, groundY, 0))
					* CFrame.Angles(0, math.rad(slot.yaw or 0), 0)
				build(item, at)
			end
		end
	end

	model.Parent = parent
	return model
end

return Decor
