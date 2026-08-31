--!strict
--[[
	House

	Builds the house that stands behind a player's plot, at whatever tier they
	have bought up to.

	Geometry is driven entirely by the tier spec in Config, so a new tier is a
	table entry rather than a new build function. The tiers grow along three
	axes at once -- footprint, storey count and detail -- because a house that
	only got taller, or only got wider, does not read as an upgrade from the
	far side of the street. Every tier has to be recognisable at a glance from
	the road, which is the only place anyone will ever see it from.

	Pure scenery: nothing here collides, is queryable, or casts a shadow. It is
	a status symbol, and it must never become an obstacle in a chase or eat a
	raycast meant for a piggy.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local House = {}

local STOREY = 9
local GLASS = Color3.fromRGB(158, 196, 214)
local DOOR = Color3.fromRGB(112, 78, 60)
local GOLD = Color3.fromRGB(240, 198, 96)

local function part(model: Model, name: string, size: Vector3, cf: CFrame,
	color: Color3, material: Enum.Material): Part
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
	p.Parent = model
	return p
end

-- A gable, as two wedges meeting at a ridge.
--
-- A WedgePart is full height at its -Z edge and slopes to nothing at +Z, so
-- the near half needs no rotation and the far half is the same wedge turned
-- around. Rotating on any other axis tips the slope onto its side.
local function gable(model: Model, width: number, depth: number, baseY: number,
	pitch: number, color: Color3, at: CFrame)
	for _, dir in ipairs({ -1, 1 }) do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Roof"
		wedge.Size = Vector3.new(width, pitch, depth / 2)
		wedge.CFrame = at
			* CFrame.new(0, baseY + pitch / 2, dir * depth / 4)
			* CFrame.Angles(0, if dir > 0 then 0 else math.pi, 0)
		wedge.Anchored = true
		wedge.CanCollide = false
		wedge.CanQuery = false
		wedge.CastShadow = false
		wedge.Color = color
		wedge.Material = Enum.Material.Slate
		wedge.Parent = model
	end
end

-- Builds the whole house in local space around `at`, which sits at ground
-- level with +Z facing the street.
function House.build(level: number, at: CFrame, parent: Instance): Model
	local tier = Config.getHouseTier(level)
	local model = Instance.new("Model")
	model.Name = "House"

	local width, depth = tier.width, tier.depth
	local height = tier.storeys * STOREY
	local front = depth / 2

	-- Body ------------------------------------------------------------
	part(model, "Walls", Vector3.new(width, height, depth),
		at * CFrame.new(0, height / 2, 0), tier.walls, Enum.Material.Brick)

	gable(model, width + 2, depth, height, tier.roofPitch, tier.roof, at)

	-- Door, always centred and always on the ground floor.
	part(model, "Door", Vector3.new(4.5, 7.5, 0.6),
		at * CFrame.new(0, 3.75, front), DOOR, Enum.Material.WoodPlanks)

	-- Windows ----------------------------------------------------------
	--
	-- One row per storey, skipping the middle of the ground floor where the
	-- door is. More storeys therefore means visibly more glass, which is most
	-- of what reads as "bigger" from the road.
	local columns = math.max(2, math.floor(width / 9))
	for storey = 1, tier.storeys do
		local y = (storey - 1) * STOREY + STOREY * 0.62
		for i = 1, columns do
			local x = -width / 2 + (width / (columns + 1)) * i
			local isDoorway = storey == 1 and math.abs(x) < 4
			if not isDoorway then
				part(model, "Window", Vector3.new(5, 4.5, 0.5),
					at * CFrame.new(x, y, front), GLASS, Enum.Material.Glass)
			end
		end
	end

	-- Detail -----------------------------------------------------------

	if tier.chimney then
		part(model, "Chimney", Vector3.new(3.2, 8, 3.2),
			at * CFrame.new(width / 3, height + 4, -depth / 5), tier.roof, Enum.Material.Brick)
	end

	if tier.porch then
		local porchDepth = 6
		part(model, "PorchFloor", Vector3.new(width * 0.7, 0.6, porchDepth),
			at * CFrame.new(0, 0.3, front + porchDepth / 2), tier.trim, Enum.Material.WoodPlanks)
		part(model, "PorchRoof", Vector3.new(width * 0.7, 0.6, porchDepth),
			at * CFrame.new(0, STOREY - 0.6, front + porchDepth / 2), tier.roof, Enum.Material.Slate)
		for _, side in ipairs({ -1, 1 }) do
			part(model, "PorchPost", Vector3.new(0.7, STOREY - 1, 0.7),
				at * CFrame.new(side * width * 0.32, (STOREY - 1) / 2, front + porchDepth - 0.6),
				tier.trim, Enum.Material.WoodPlanks)
		end
	end

	if tier.garage then
		local gw = width * 0.32
		part(model, "GarageDoor", Vector3.new(gw, 7, 0.6),
			at * CFrame.new(-width / 2 + gw / 2 + 1.5, 3.5, front + 0.2),
			tier.trim, Enum.Material.Metal)
	end

	if tier.columns then
		for _, side in ipairs({ -1, 1 }) do
			local column = part(model, "Column", Vector3.new(height, 2.2, 2.2),
				at * CFrame.new(side * (width / 2 - 2), height / 2, front + 1)
					* CFrame.Angles(0, 0, math.rad(90)),
				if tier.gold then GOLD else tier.trim, Enum.Material.Marble)
			column.Shape = Enum.PartType.Cylinder
		end
	end

	if tier.tower then
		-- Proportions matter more than height here. A tall tower under a
		-- steep roof reads as a spike rather than a turret, so the tower
		-- clears the ridge by about a third of a house and its roof is
		-- shallower than the main one rather than sharper.
		local towerH = height * 0.32
		local towerW = 11
		part(model, "Tower", Vector3.new(towerW, height + towerH, towerW),
			at * CFrame.new(width / 2 - towerW / 2, (height + towerH) / 2, -depth / 2 + towerW / 2),
			tier.walls, Enum.Material.Brick)
		gable(model, towerW + 1, towerW + 1, height + towerH, tier.roofPitch * 0.6, tier.roof,
			at * CFrame.new(width / 2 - towerW / 2, 0, -depth / 2 + towerW / 2))

		-- A window on the tower, or it reads as a chimney.
		part(model, "Window", Vector3.new(4, 4, 0.5),
			at * CFrame.new(width / 2 - towerW / 2, height + towerH * 0.5, -depth / 2 + towerW),
			GLASS, Enum.Material.Glass)
	end

	if tier.gold then
		-- A band under the eaves. Cheapest possible "this one is different"
		-- read from the far side of the street.
		for _, dz in ipairs({ front, -front }) do
			part(model, "GoldTrim", Vector3.new(width + 0.4, 1.1, 0.4),
				at * CFrame.new(0, height - 0.8, dz), GOLD, Enum.Material.Metal)
		end
	end

	model.Parent = parent
	return model
end

return House
