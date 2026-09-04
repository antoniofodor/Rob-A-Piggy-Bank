--!strict
--[[
	House

	Builds the house behind a player's plot at whatever tier they own.

	Each tier is a different ARCHETYPE, not the same house at a bigger scale.
	Scaling alone failed the only test that matters here: the house is seen
	from the street, at distance, next to eleven others, and two gabled boxes
	four studs apart in width are indistinguishable. So the ladder changes
	silhouette every rung -- low and wide, then tall and narrow, then sprawling,
	then symmetrical, then a flat-roofed black glass box. You can tell them
	apart as shapes before you can read any detail.

	Pure scenery: nothing here collides, is queryable, or casts a shadow. It is
	a status symbol and must never become an obstacle in a chase or eat a
	raycast meant for a piggy.

	IN ReplicatedStorage BECAUSE THE SHOP RENDERS IT.

	This file has always been pure geometry over Config, with no server-only
	API anywhere in it, so it moved here rather than being copied: the shop
	tiles show the REAL item, built by the same function that puts it on the
	lawn, and a second nearly-identical copy would drift from this one the
	first time either was touched. Same reasoning as BoneModel and PigGear,
	which have been shared this way from the start.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HouseFX = require(ReplicatedStorage.Shared.HouseFX)

local House = {}

local STOREY = 9
local GLASS = Color3.fromRGB(158, 196, 214)
local GLASS_DARK = Color3.fromRGB(96, 126, 148)
local DOOR = Color3.fromRGB(112, 78, 60)

-- Tinted almost to black, with reflectance doing the work instead of colour.
-- Ordinary window blue on a black building reads as "dark house with normal
-- windows"; blacked-out glazing is the whole look of the top tier.
local GLASS_TINT = Color3.fromRGB(30, 38, 48)

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

-- A pitched roof, as two wedges meeting at a ridge.
--
-- A WedgePart is full height at its -Z edge and slopes to nothing at +Z, so
-- the near half needs no rotation and the far half is the same wedge turned
-- around. Rotating on any other axis tips the slope onto its side.
local function gable(width: number, depth: number, baseY: number, pitch: number,
	color: Color3, at: CFrame)
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
		wedge.Parent = folder
	end
end

-- A row of windows across the front of one storey, skipping the middle of the
-- ground floor where the door goes.
local function windowRow(at: CFrame, width: number, front: number, y: number,
	skipMiddle: boolean, colour: Color3, w: number, h: number)
	local columns = math.max(2, math.floor(width / 9))
	for i = 1, columns do
		local x = -width / 2 + (width / (columns + 1)) * i
		if not (skipMiddle and math.abs(x) < 4) then
			part("Window", Vector3.new(w, h, 0.5), at * CFrame.new(x, y, front),
				colour, Enum.Material.Glass)
		end
	end
end

-- ============================================================
-- ARCHETYPES
-- ============================================================

-- AN ANIMATED EMISSIVE PART, which is what the endgame tiers are actually
-- built out of now.
--
-- The colour is written every frame by `HouseFX` on each CLIENT, from the
-- attributes stamped here. Nothing about the animation is replicated: the
-- server builds the geometry, tags it, and never touches it again.
--
-- Hue and saturation are DERIVED from the colour handed in rather than passed
-- separately, so a tier's palette stays one number in Config instead of a
-- colour here and a hue there that drift apart the first time somebody
-- retunes the gold.
-- THE FX PALETTE, WHICH IS NOT THE LANTERN PALETTE. `tier.glow` is tuned for
-- a soft PointLight and is deliberately pale on the two light-walled tiers;
-- Neon renders a colour flat out and blooms it, so the same value that reads
-- as a warm bulb reads as a white hole. Every animated part goes through here.
local function fxColour(tier): Color3
	return tier.fxGlow or tier.glow or tier.trim
end

local function glowPart(name: string, size: Vector3, cf: CFrame, colour: Color3, spec: { [string]: any }): Part
	local p = part(name, size, cf, colour, Enum.Material.Neon)
	local h, sv = colour:ToHSV()

	p:SetAttribute("FX", spec.fx)
	p:SetAttribute("Phase", spec.phase or 0)
	p:SetAttribute("Rate", spec.rate or 0.3)
	p:SetAttribute("Hue", spec.hue or h)
	p:SetAttribute("Sat", spec.sat or sv)
	if spec.span then p:SetAttribute("Span", spec.span) end
	if spec.dim then p:SetAttribute("Dim", spec.dim) end
	if spec.amount then p:SetAttribute("Amount", spec.amount) end

	-- Tagged LAST, so the attributes are all readable by the time the
	-- animator's added-signal fires. Tag first and a listener can register a
	-- part before the numbers describing it exist, which reads as an effect
	-- that works everywhere except the first house built after a join.
	CollectionService:AddTag(p, HouseFX.TAG)
	return p
end

local builders: { [string]: (any, CFrame) -> () } = {}

-- Tiny, crooked, patched together. Deliberately the only one that looks unwell.
builders.shack = function(tier, at)
	local w, d, h = tier.width, tier.depth, STOREY
	part("Walls", Vector3.new(w, h, d), at * CFrame.new(0, h / 2, 0), tier.walls, Enum.Material.WoodPlanks)

	-- Single lean-to slope rather than a gable: the cheapest roof there is,
	-- and it sets the shack apart from everything above it at a glance.
	local shed = Instance.new("WedgePart")
	shed.Name = "Roof"
	shed.Size = Vector3.new(w + 1.5, 3.5, d + 1.5)
	shed.CFrame = at * CFrame.new(0, h + 1.75, 0) * CFrame.Angles(0, math.pi, 0)
	shed.Anchored, shed.CanCollide, shed.CanQuery, shed.CastShadow = true, false, false, false
	shed.Color, shed.Material = tier.roof, Enum.Material.CorrodedMetal
	shed.Parent = folder

	part("Door", Vector3.new(4, 7, 0.5), at * CFrame.new(0, 3.5, d / 2), DOOR, Enum.Material.WoodPlanks)
	part("Window", Vector3.new(3.5, 3, 0.5), at * CFrame.new(-w / 3, 5.6, d / 2), GLASS_DARK, Enum.Material.Glass)

	-- A prop holding up the sagging corner.
	part("Prop", Vector3.new(0.5, h, 0.5),
		at * CFrame.new(w / 2 - 0.6, h / 2, d / 2 - 0.6) * CFrame.Angles(math.rad(6), 0, math.rad(-5)),
		tier.trim, Enum.Material.Wood)
end

-- Low, wide and warm, under a steep tiled roof. Horizontal by design, so the
-- townhouse above it reads as a completely different shape.
builders.cottage = function(tier, at)
	local w, d, h = tier.width, tier.depth, STOREY
	part("Walls", Vector3.new(w, h, d), at * CFrame.new(0, h / 2, 0), tier.walls, Enum.Material.Brick)
	gable(w + 2.5, d + 2, h, 9, tier.roof, at)

	part("Door", Vector3.new(4.5, 7.5, 0.6), at * CFrame.new(0, 3.75, d / 2), DOOR, Enum.Material.WoodPlanks)
	windowRow(at, w, d / 2, h * 0.62, true, GLASS, 5, 4.5)

	part("Chimney", Vector3.new(3.4, 12, 3.4), at * CFrame.new(w / 3, h + 5, -d / 5),
		tier.roof, Enum.Material.Brick)

	-- Window boxes and a porch canopy: the cottage's whole personality.
	for _, dx in ipairs({ -w / 4, w / 4 }) do
		part("Planter", Vector3.new(5.4, 0.8, 1.2), at * CFrame.new(dx, h * 0.62 - 2.6, d / 2 + 0.4),
			tier.trim, Enum.Material.WoodPlanks)
		part("Bloom", Vector3.new(4.6, 0.7, 0.9), at * CFrame.new(dx, h * 0.62 - 2.1, d / 2 + 0.5),
			Color3.fromRGB(206, 96, 120), Enum.Material.Grass)
	end
	part("Canopy", Vector3.new(9, 0.5, 3.5), at * CFrame.new(0, 8, d / 2 + 1.7), tier.roof, Enum.Material.Slate)
end

-- Tall and narrow: three floors on a small footprint. The opposite silhouette
-- to the cottage, which is the entire point of it sitting one rung above.
builders.townhouse = function(tier, at)
	local w, d = tier.width, tier.depth
	local h = tier.storeys * STOREY
	part("Walls", Vector3.new(w, h, d), at * CFrame.new(0, h / 2, 0), tier.walls, Enum.Material.Brick)

	-- Shallow mansard cap rather than a big gable, so height reads as floors
	-- rather than roof.
	part("Cap", Vector3.new(w + 2, 1.2, d + 2), at * CFrame.new(0, h + 0.6, 0), tier.roof, Enum.Material.Slate)
	gable(w + 2, d + 2, h + 1.2, 4, tier.roof, at)

	-- Stoop: steps up to a raised front door, which is what makes a townhouse
	-- a townhouse.
	for i = 0, 3 do
		part("Step", Vector3.new(7, 0.7, 1.2 + i * 0.9),
			at * CFrame.new(0, 0.35 + i * 0.7, d / 2 + 2.6 - i * 0.5), tier.trim, Enum.Material.Concrete)
	end
	part("Door", Vector3.new(4, 8, 0.6), at * CFrame.new(0, 7, d / 2), DOOR, Enum.Material.WoodPlanks)

	-- Bay window, full height, one side of the door.
	part("Bay", Vector3.new(7, h - 4, 2.4), at * CFrame.new(-w / 4 - 1, (h - 4) / 2 + 3, d / 2 + 1.2),
		tier.trim, Enum.Material.Brick)
	for storey = 1, tier.storeys do
		part("Window", Vector3.new(5.6, 5, 0.5),
			at * CFrame.new(-w / 4 - 1, (storey - 1) * STOREY + STOREY * 0.6 + 2, d / 2 + 2.5),
			GLASS, Enum.Material.Glass)
		part("Window", Vector3.new(4.4, 5, 0.5),
			at * CFrame.new(w / 4 + 1, (storey - 1) * STOREY + STOREY * 0.6 + 2, d / 2),
			GLASS, Enum.Material.Glass)
	end
end

-- Sprawling and low, with a garage. Reads as width where the townhouse read
-- as height.
builders.villa = function(tier, at)
	local w, d = tier.width, tier.depth
	local h = tier.storeys * STOREY
	part("Walls", Vector3.new(w, h, d), at * CFrame.new(0, h / 2, 0), tier.walls, Enum.Material.Brick)
	gable(w + 2, d + 2, h, 7, tier.roof, at)

	-- Single-storey garage wing, stepped forward and down so the roofline
	-- breaks instead of running flat across the whole frontage.
	local gw = w * 0.34
	part("Garage", Vector3.new(gw, STOREY, d * 0.7),
		at * CFrame.new(-w / 2 - gw / 2 + 2, STOREY / 2, d * 0.15), tier.walls, Enum.Material.Brick)
	gable(gw + 1.5, d * 0.7 + 1.5, STOREY, 4, tier.roof, at * CFrame.new(-w / 2 - gw / 2 + 2, 0, d * 0.15))
	part("GarageDoor", Vector3.new(gw - 4, 7, 0.6),
		at * CFrame.new(-w / 2 - gw / 2 + 2, 3.5, d * 0.15 + d * 0.35), tier.trim, Enum.Material.Metal)

	part("Door", Vector3.new(5, 8, 0.6), at * CFrame.new(w / 6, 4, d / 2), DOOR, Enum.Material.WoodPlanks)
	windowRow(at, w, d / 2, STOREY * 0.62, true, GLASS, 5.5, 4.5)
	windowRow(at, w, d / 2, STOREY + STOREY * 0.62, false, GLASS, 5.5, 4.5)

	-- Porch across the main block only.
	part("PorchRoof", Vector3.new(w * 0.6, 0.6, 6), at * CFrame.new(w / 8, STOREY - 0.6, d / 2 + 3),
		tier.roof, Enum.Material.Slate)
	for _, side in ipairs({ -1, 1 }) do
		part("PorchPost", Vector3.new(0.8, STOREY - 1, 0.8),
			at * CFrame.new(w / 8 + side * w * 0.28, (STOREY - 1) / 2, d / 2 + 5.6),
			tier.trim, Enum.Material.WoodPlanks)
	end
end

-- Symmetrical, columned, with wings. Grand and old-money, deliberately the
-- opposite of the modern box above it.
builders.manor = function(tier, at)
	local w, d = tier.width, tier.depth
	local h = tier.storeys * STOREY
	part("Walls", Vector3.new(w, h, d), at * CFrame.new(0, h / 2, 0), tier.walls, Enum.Material.Marble)
	gable(w + 2, d + 2, h, 8, tier.roof, at)

	-- Two lower wings, one each side, so the frontage steps rather than being
	-- one long slab.
	for _, side in ipairs({ -1, 1 }) do
		local ww = w * 0.16
		part("Wing", Vector3.new(ww, h - STOREY, d * 0.8),
			at * CFrame.new(side * (w / 2 + ww / 2 - 1), (h - STOREY) / 2, 0), tier.walls, Enum.Material.Marble)
		gable(ww + 1.5, d * 0.8 + 1.5, h - STOREY, 5, tier.roof,
			at * CFrame.new(side * (w / 2 + ww / 2 - 1), 0, 0))
	end

	part("Door", Vector3.new(6, 10, 0.6), at * CFrame.new(0, 5, d / 2), DOOR, Enum.Material.WoodPlanks)
	for storey = 1, tier.storeys do
		windowRow(at, w, d / 2, (storey - 1) * STOREY + STOREY * 0.62, storey == 1, GLASS, 5, 5)
	end

	-- Portico: four columns and a pediment over the entrance.
	part("Pediment", Vector3.new(w * 0.46, 1.4, 8), at * CFrame.new(0, h * 0.66, d / 2 + 4),
		tier.trim, Enum.Material.Marble)
	for i = -1.5, 1.5, 1 do
		local column = part("Column", Vector3.new(h * 0.66, 2.4, 2.4),
			at * CFrame.new(i * (w * 0.13), h * 0.33, d / 2 + 7) * CFrame.Angles(0, 0, math.rad(90)),
			tier.trim, Enum.Material.Marble)
		column.Shape = Enum.PartType.Cylinder
	end
end

-- Blacked-out glass box. Flat roofs, a cantilevered upper floor that oversails
-- the ground floor, and a warm strip light under the overhang.
--
-- The only tier with no pitched roof anywhere, which is what makes it read as
-- modern from across the street rather than merely dark.
builders.modern = function(tier, at)
	local w, d = tier.width, tier.depth
	local ground, upper = STOREY + 2, STOREY + 1
	local inset = 5

	-- Ground floor, set back on both sides so the upper can overhang it.
	part("Walls", Vector3.new(w - inset * 2, ground, d - 2),
		at * CFrame.new(0, ground / 2, 0), tier.walls, Enum.Material.Slate)

	-- Floor-to-ceiling glazing, nearly the whole frontage.
	local function tinted(name: string, size: Vector3, cf: CFrame): Part
		local p = part(name, size, cf, GLASS_TINT, Enum.Material.Glass)
		p.Reflectance = 0.35
		return p
	end

	tinted("Glazing", Vector3.new(w - inset * 2 - 4, ground - 2.5, 0.6),
		at * CFrame.new(0, ground / 2, (d - 2) / 2))

	-- Cantilevered upper floor: wider than the ground floor and pushed
	-- forward, so it visibly hangs in the air.
	local upperY = ground + upper / 2
	part("Upper", Vector3.new(w, upper, d), at * CFrame.new(0, upperY, 2), tier.walls, Enum.Material.Slate)
	tinted("UpperGlass", Vector3.new(w - 6, upper - 3, 0.6), at * CFrame.new(0, upperY, d / 2 + 2))
	for _, side in ipairs({ -1, 1 }) do
		tinted("SideGlass", Vector3.new(0.6, upper - 3, d - 6), at * CFrame.new(side * w / 2, upperY, 2))
	end

	-- The strip light under the overhang. One warm line on an otherwise black
	-- building, which is the whole look -- and now the one that BREATHES,
	-- because this is the first tier anybody reaches with money to spare and
	-- it should be the first that visibly does something. Deliberately the
	-- quietest effect in the file: the modern is the restrained one, and it
	-- is the contrast that makes the Neon Tower above it read as loud.
	glowPart("Strip", Vector3.new(w - 1, 0.35, 0.5),
		at * CFrame.new(0, ground + 0.4, d / 2 + 2), fxColour(tier),
		{ fx = "pulse", rate = 0.16, dim = 0.45 })

	-- A second line at the parapet, chasing the length of the roof. Two lines
	-- doing different things is what stops it reading as a strip somebody
	-- forgot to switch off.
	for i = 0, 5 do
		glowPart("Coping", Vector3.new((w + 1) / 6 - 0.4, 0.22, 0.4),
			at * CFrame.new(-(w + 1) / 2 + (w + 1) / 12 + i * (w + 1) / 6,
				ground + upper + 2.1, d / 2 + 2.3), fxColour(tier),
			{ fx = "chase", phase = i / 6, rate = 0.34, span = 0.4, dim = 0.3 })
	end

	-- Flat roof with a parapet: a rooftop terrace, not an attic.
	part("RoofSlab", Vector3.new(w + 1, 0.8, d + 1), at * CFrame.new(0, ground + upper, 2),
		tier.roof, Enum.Material.Slate)
	for _, spec in ipairs({
		{ Vector3.new(w + 1, 1.6, 0.5), Vector3.new(0, 0, d / 2 + 2) },
		{ Vector3.new(0.5, 1.6, d + 1), Vector3.new(-w / 2, 0, 2) },
		{ Vector3.new(0.5, 1.6, d + 1), Vector3.new(w / 2, 0, 2) },
	}) do
		part("Parapet", spec[1], at * CFrame.new(spec[2] + Vector3.new(0, ground + upper + 1.2, 0)),
			tier.roof, Enum.Material.Slate)
	end

	-- Pilotis holding up the overhang, and a slab entrance path.
	for _, side in ipairs({ -1, 1 }) do
		-- Size is (LENGTH, diameter, diameter), not (diameter, height, diameter).
		--
		-- A Roblox cylinder's axis is its X axis, so its length lives in Size.X
		-- and the other two are the cross-section. Written the other way round
		-- this was an 11-stud-wide disc 1.1 thick, and the Z-turn that was meant
		-- to stand a column upright instead laid that disc flat -- two big black
		-- plates hanging in the air across the front of the house.
		local pillar = part("Piloti", Vector3.new(ground, 1.1, 1.1),
			at * CFrame.new(side * (w / 2 - 2), ground / 2, d / 2 + 1.5)
				* CFrame.Angles(0, 0, math.rad(90)),
			tier.roof, Enum.Material.Metal)
		pillar.Shape = Enum.PartType.Cylinder
	end
	part("Door", Vector3.new(5, 9, 0.5), at * CFrame.new(0, 4.5, (d - 2) / 2 + 0.3),
		Color3.fromRGB(12, 12, 15), Enum.Material.Glass)
	part("Path", Vector3.new(10, 0.3, 14), at * CFrame.new(0, 0.15, d / 2 + 9),
		Color3.fromRGB(58, 58, 64), Enum.Material.Concrete)
end

-- ============================================================
-- THE ENDGAME THREE
-- ============================================================
--
-- These are built to be seen from the ROAD, not from the lawn.
--
-- A house sits 70 studs behind its own piggy, so at the six tiers below this
-- one the driveway has been doing the announcing and the building itself is a
-- distant shape somebody has to walk to. These go UP -- six, three tall and
-- five storeys against the manor's three -- so they clear the grove behind the
-- plots and read from anywhere on the street. Each also carries `tier.glow`,
-- which `lantern` turns into emissive detail so they read at night too.

-- A lit accent: neon geometry plus one real light. Two per house at most --
-- twelve plots' worth of PointLights is a real cost, and the neon does most of
-- the work on its own.
local function lantern(tier, size: Vector3, cf: CFrame, withLight: boolean)
	local glow = tier.glow or tier.trim
	local p = part("Glow", size, cf, glow, Enum.Material.Neon)
	if withLight then
		local light = Instance.new("PointLight")
		light.Color = glow
		-- Deliberately weak. This is a night-time accent, and the palace is
		-- the tier that proves it: white marble walls bounce a warm light
		-- straight back, so at brightness 2 over a 26-stud range the whole
		-- front of the building washed out in daylight. A lantern should read
		-- as a lit lamp, not as a floodlight aimed at the house.
		light.Brightness = tier.lanternBrightness or 0.9
		light.Range = tier.lanternRange or 18
		light.Shadows = false
		light.Parent = p
	end
	return p
end

-- Six slim floors with lit edges. The tallest silhouette in the game and the
-- only one that is narrower than it is high.
builders.tower = function(tier, at)
	local w, d = tier.width, tier.depth
	local floor = STOREY
	local h = tier.storeys * floor

	part("Core", Vector3.new(w, h, d), at * CFrame.new(0, h / 2, 0), tier.walls, Enum.Material.Slate)

	-- Glazing every storey, all four sides, so the tower reads as floors
	-- rather than as one tall slab.
	for level = 0, tier.storeys - 1 do
		local y = level * floor + floor * 0.55
		for _, spec in ipairs({
			{ Vector3.new(w - 5, floor * 0.55, 0.5), Vector3.new(0, y, d / 2) },
			{ Vector3.new(w - 5, floor * 0.55, 0.5), Vector3.new(0, y, -d / 2) },
			{ Vector3.new(0.5, floor * 0.55, d - 5), Vector3.new(w / 2, y, 0) },
			{ Vector3.new(0.5, floor * 0.55, d - 5), Vector3.new(-w / 2, y, 0) },
		}) do
			local glass = part("Glazing", spec[1], at * CFrame.new(spec[2]), GLASS_TINT, Enum.Material.Glass)
			glass.Reflectance = 0.4
		end
		-- A LIT BAND PER FLOOR, CYCLING, WITH A PHASE PER STOREY -- which
		-- together make one colour wave travelling up the building. This is
		-- the loudest thing available at a hundred studs, because it is the
		-- only effect that changes while nothing moves, and it is the reason
		-- the tier is called the Neon Tower rather than the Glass One.
		--
		-- Front and both sides now. The back is still skipped: nobody stands
		-- behind these, and eighteen emitters is already the largest single
		-- run in the game.
		local phase = level / tier.storeys
		local y = level * floor + floor - 0.6
		glowPart("Band", Vector3.new(w - 3, 0.4, 0.4),
			at * CFrame.new(0, y, d / 2 + 0.3), fxColour(tier),
			{ fx = "cycle", phase = phase, rate = 0.22 })
		for _, sx in ipairs({ -1, 1 }) do
			glowPart("Band", Vector3.new(0.4, 0.4, d - 3),
				at * CFrame.new(sx * (w / 2 + 0.3), y, 0), fxColour(tier),
				{ fx = "cycle", phase = phase, rate = 0.22 })
		end
	end

	-- Corner columns run the full height and are what actually makes it read
	-- as a tower rather than a stack of boxes.
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			part("Column", Vector3.new(1.6, h, 1.6),
				at * CFrame.new(sx * w / 2, h / 2, sz * d / 2), tier.roof, Enum.Material.Metal)
		end
	end

	-- A LIGHT RUNNING UP THE TWO FRONT CORNERS, cut into one segment per
	-- storey. A chase needs segments by construction: a single full-height
	-- strip can only get brighter and dimmer, and what reads as travel is a
	-- lit band arriving somewhere it was not a moment ago.
	--
	-- Front corners only. The two at the back face the grove.
	for _, sx in ipairs({ -1, 1 }) do
		for level = 0, tier.storeys - 1 do
			glowPart("Riser", Vector3.new(0.45, floor - 0.6, 0.45),
				at * CFrame.new(sx * (w / 2), level * floor + floor / 2, d / 2 + 0.95), fxColour(tier),
				{ fx = "chase", phase = level / tier.storeys, rate = 0.5, span = 0.3, dim = 0.12 })
		end
	end

	part("Cap", Vector3.new(w + 2.5, 0.9, d + 2.5), at * CFrame.new(0, h + 0.45, 0), tier.roof, Enum.Material.Slate)
	part("Mast", Vector3.new(0.7, 9, 0.7), at * CFrame.new(0, h + 5, 0), tier.roof, Enum.Material.Metal)

	-- The bit visible over the trees: a swelling beacon at the tip, and a ring
	-- turning around the mast under it. The ring is what sells it as a machine
	-- rather than a lamp -- it is the only thing on the street that MOVES at
	-- this distance, and movement out-reads colour at the far end of the road.
	glowPart("Beacon", Vector3.new(2.8, 2.8, 2.8), at * CFrame.new(0, h + 9.6, 0), fxColour(tier),
		{ fx = "beacon", rate = 0.45, dim = 0.1 })
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		glowPart("Halo", Vector3.new(1.6, 1.6, 1.6),
			at * CFrame.new(0, h + 6.2, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 4.4),
			fxColour(tier), { fx = "orbit", rate = 0.3, amount = 4.4 }).Shape = Enum.PartType.Ball
	end

	part("Door", Vector3.new(5, 8, 0.6), at * CFrame.new(0, 4, d / 2), Color3.fromRGB(14, 15, 20), Enum.Material.Glass)
	part("Podium", Vector3.new(w + 6, 0.6, 8), at * CFrame.new(0, 0.3, d / 2 + 3), tier.roof, Enum.Material.Concrete)
end

-- Wide, symmetrical, gold-domed. The opposite silhouette to the tower on
-- either side of it in the ladder.
builders.palace = function(tier, at)
	local w, d = tier.width, tier.depth
	local h = tier.storeys * STOREY

	part("Walls", Vector3.new(w, h, d), at * CFrame.new(0, h / 2, 0), tier.walls, Enum.Material.Marble)
	-- White, not gold. Cornice, columns and steps in trim as well as the dome
	-- turned the whole building into one yellow mass at a distance -- and the
	-- point of the dome is that it is the gold bit. Marble everywhere else.
	part("Cornice", Vector3.new(w + 3, 1.6, d + 3), at * CFrame.new(0, h + 0.8, 0), tier.walls, Enum.Material.Marble)

	-- Dome on a drum, centred. Built from a ball squashed to a half-height so
	-- it sits ON the roof instead of half-buried in it.
	local drum = part("Drum", Vector3.new(3, 14, 14),
		at * CFrame.new(0, h + 3.1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		tier.walls, Enum.Material.Marble)
	drum.Shape = Enum.PartType.Cylinder
	local dome = part("Dome", Vector3.new(15, 11, 15), at * CFrame.new(0, h + 5.2, 0), tier.roof, Enum.Material.Metal)
	dome.Shape = Enum.PartType.Ball
	part("Finial", Vector3.new(1.1, 4, 1.1), at * CFrame.new(0, h + 11.6, 0), tier.trim, Enum.Material.Metal)
	-- Gold band where the dome meets its drum, so the two read as one object.
	-- SHIMMERS rather than cycles: `sweep` walks a little way around the wheel
	-- and back, so the gold moves without ever stopping being gold. A full
	-- hue cycle here would turn the one thing that identifies this tier into
	-- the same rainbow the Neon Tower already owns.
	local collar = glowPart("DomeBand", Vector3.new(1.2, 14.6, 14.6),
		at * CFrame.new(0, h + 4.5, 0) * CFrame.Angles(0, 0, math.rad(90)), fxColour(tier),
		{ fx = "sweep", rate = 0.2, amount = 0.045 })
	collar.Shape = Enum.PartType.Cylinder

	-- A gold ring turning above the finial. The palace's answer to the tower's
	-- halo, and the reason it still reads from the road: everything else on
	-- this building is a static white mass.
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		glowPart("Halo", Vector3.new(1.8, 1.8, 1.8),
			at * CFrame.new(0, h + 15.5, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 6),
			fxColour(tier), { fx = "orbit", rate = 0.22, amount = 6 }).Shape = Enum.PartType.Ball
	end

	-- Colonnade across the whole frontage, on a stepped plinth, each column
	-- standing on its own uplight. The lights chase ACROSS the frontage,
	-- which is the one direction that reads from the street: a palace is
	-- looked at side-on from the road, so a wave travelling left to right
	-- crosses the viewer's eye instead of moving away from it.
	for i = 0, 5 do
		local x = -w / 2 + 4 + i * ((w - 8) / 5)
		local column = part("Column", Vector3.new(h - 2, 2.6, 2.6),
			at * CFrame.new(x, (h - 2) / 2 + 1, d / 2 + 5) * CFrame.Angles(0, 0, math.rad(90)),
			tier.walls, Enum.Material.Marble)
		column.Shape = Enum.PartType.Cylinder

		-- SEATED ON THE TOP STEP, not on the ground. The plinth stacks three
		-- steps to y 2.1 and the columns only emerge above it, so a light at
		-- the column's own base is a light buried inside solid marble --
		-- which is exactly where these were, and why the whole frontage came
		-- out as one white haze with nothing in it anybody could name.
		local uplight = glowPart("Uplight", Vector3.new(0.7, 3.8, 3.8),
			at * CFrame.new(x, 2.6, d / 2 + 5) * CFrame.Angles(0, 0, math.rad(90)), fxColour(tier),
			{ fx = "chase", phase = i / 6, rate = 0.3, span = 0.32, dim = 0.2 })
		uplight.Shape = Enum.PartType.Cylinder
	end
	part("Pediment", Vector3.new(w - 4, 2.4, 11), at * CFrame.new(0, h + 0.4, d / 2 + 4), tier.trim, Enum.Material.Marble)
	-- The steps, and a lit nosing on each. The chase runs UP them toward the
	-- door -- phases handed out from the bottom step rather than from `i`,
	-- which counts down: step 0 is the TOP one here, and a chase authored off
	-- the loop index would have run down the stairs and out into the garden.
	for i = 0, 2 do
		local depth = 12 + i * 2
		local y = 0.35 + (2 - i) * 0.7
		part("Step", Vector3.new(w - 6 + i * 3, 0.7, depth),
			at * CFrame.new(0, y, d / 2 + 8), tier.walls, Enum.Material.Marble)
		glowPart("Nosing", Vector3.new(w - 6 + i * 3 - 1, 0.42, 0.5),
			at * CFrame.new(0, y + 0.45, d / 2 + 8 + depth / 2 + 0.1), fxColour(tier),
			{ fx = "chase", phase = (2 - i) / 3, rate = 0.42, span = 0.36, dim = 0.18 })
	end

	for storey = 1, tier.storeys do
		windowRow(at, w, d / 2, (storey - 1) * STOREY + STOREY * 0.6, storey == 1, GLASS, 4.5, 5)
	end
	part("Door", Vector3.new(7, 11, 0.6), at * CFrame.new(0, 5.5, d / 2), tier.roof, Enum.Material.Metal)

	-- Lanterns flanking the entrance, which is where a palace is looked at.
	for _, side in ipairs({ -1, 1 }) do
		part("LampPost", Vector3.new(0.6, 7, 0.6),
			at * CFrame.new(side * (w / 2 - 2), 3.5, d / 2 + 12), tier.trim, Enum.Material.Metal)
		lantern(tier, Vector3.new(1.8, 1.8, 1.8),
			at * CFrame.new(side * (w / 2 - 2), 7.6, d / 2 + 12), true)
	end
end

-- Stone keep with four corner turrets and a banner. The only tier with a
-- crenellated roofline, which is what makes it read at a distance.
builders.castle = function(tier, at)
	local w, d = tier.width, tier.depth
	local h = tier.storeys * STOREY

	part("Keep", Vector3.new(w, h, d), at * CFrame.new(0, h / 2, 0), tier.walls, Enum.Material.Brick)

	-- Battlements: alternating blocks along the front and back edges.
	local merlons = math.floor(w / 5)
	for i = 0, merlons - 1 do
		local x = -w / 2 + 2.5 + i * (w / merlons)
		for _, sz in ipairs({ -1, 1 }) do
			part("Merlon", Vector3.new(2.6, 2.2, 1.6),
				at * CFrame.new(x, h + 1.1, sz * (d / 2 - 0.8)), tier.walls, Enum.Material.Brick)
		end
	end

	-- Four turrets, taller than the keep, each with a conical cap.
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local th = h + 7
			local turret = part("Turret", Vector3.new(th, 8, 8),
				at * CFrame.new(sx * w / 2, th / 2, sz * d / 2) * CFrame.Angles(0, 0, math.rad(90)),
				tier.walls, Enum.Material.Brick)
			turret.Shape = Enum.PartType.Cylinder

			-- Cone approximated by three stacked, shrinking discs. A wedge
			-- cannot make a cone and a ball reads as a mushroom.
			for step = 0, 2 do
				local cap = part("Cap", Vector3.new(1.8, 8 - step * 2.4, 8 - step * 2.4),
					at * CFrame.new(sx * w / 2, th + 0.9 + step * 1.7, sz * d / 2) * CFrame.Angles(0, 0, math.rad(90)),
					tier.roof, Enum.Material.Slate)
				cap.Shape = Enum.PartType.Cylinder
			end
			-- The four finials breathe, and they breathe OUT OF STEP: a
			-- quarter turn of phase each, so the castle has something moving
			-- at every moment rather than all four blinking together like a
			-- fault. Four corners pulsing in lockstep is the one arrangement
			-- that reads as a single flash, which is also the arrangement the
			-- flash guidance is about.
			local finial = glowPart("Finial", Vector3.new(1.6, 1.6, 1.6),
				at * CFrame.new(sx * w / 2, th + 6.6, sz * d / 2), fxColour(tier),
				{ fx = "pulse", phase = (sx + 1) * 0.125 + (sz + 1) * 0.25, rate = 0.3, dim = 0.2 })
			finial.Shape = Enum.PartType.Ball
			-- Held by reference, never looked back up by name: every part in
			-- a house lives in one flat folder, so `FindFirstChild("Finial")`
			-- returns the same first turret on all four passes -- and the
			-- palace builds a part with that name as well.
			if sz > 0 then
				local light = Instance.new("PointLight")
				light.Color = tier.glow
				light.Brightness = tier.lanternBrightness or 0.9
				light.Range = tier.lanternRange or 18
				light.Shadows = false
				light.Parent = finial
			end
		end
	end

	-- Gatehouse and portcullis, dead centre of the frontage.
	part("Gatehouse", Vector3.new(14, h * 0.8, 5), at * CFrame.new(0, h * 0.4, d / 2 + 2), tier.walls, Enum.Material.Brick)
	-- DOOR, not tier.roof. The roof colour on this tier is purple, which made
	-- the portcullis a purple wooden door.
	part("Gate", Vector3.new(8, 11, 0.8), at * CFrame.new(0, 5.5, d / 2 + 4.6), DOOR, Enum.Material.Wood)
	for i = 0, 2 do
		part("Merlon", Vector3.new(2.6, 2.0, 5),
			at * CFrame.new(-5 + i * 5, h * 0.8 + 1, d / 2 + 2), tier.walls, Enum.Material.Brick)
	end

	-- Banner down the front of the keep: the one splash of colour on all that
	-- grey, and the fastest way to tell whose castle it is from the road.
	-- Hung on the GATEHOUSE, above the gate and below its battlements, rather
	-- than up the keep behind it -- from the road that read as a stripe
	-- floating halfway up a wall with nothing holding it.
	--
	-- STILL FABRIC, and the light on it is a separate part standing proud.
	-- Fabric is a dark noisy texture rather than a colour, so animating the
	-- banner's own colour would have moved a muddy brown through a muddy
	-- purple. The cloth stays cloth and a neon device is pinned to it.
	part("Banner", Vector3.new(5.5, h * 0.4, 0.4),
		at * CFrame.new(0, h * 0.47, d / 2 + 4.9), tier.trim, Enum.Material.Fabric)
	glowPart("Sigil", Vector3.new(2.6, 2.6, 0.3),
		at * CFrame.new(0, h * 0.47, d / 2 + 5.2), fxColour(tier),
		{ fx = "pulse", rate = 0.26, dim = 0.35 })

	-- RUNES ACROSS THE KEEP, above the gatehouse and clear of it, chasing
	-- from one side to the other. The keep front is a forty-stud blank wall
	-- and this is the only tier whose walls are plain grey brick, so it is
	-- the one that most needed something written on it.
	for i = 0, 4 do
		glowPart("Rune", Vector3.new(2.2, 2.2, 0.35),
			at * CFrame.new(-12 + i * 6, h * 0.8 + 5, d / 2 + 0.4), fxColour(tier),
			{ fx = "chase", phase = i / 5, rate = 0.38, span = 0.3, dim = 0.15 })
	end

	-- A SKY CASTLE SHOULD HAVE SOMETHING IN THE SKY. Six rocks circling the
	-- keep above the turrets, each on its own radius, height and rate so the
	-- ring never resolves into a wheel. This is the tallest thing in the game
	-- and the only moving scenery above the treeline, which is what a
	-- hundred-million-coin house is buying: everyone on the street can see it
	-- without leaving their own plot.
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local radius = 26 + (i % 3) * 5
		local rock = part("Shard", Vector3.new(4.5 - (i % 3) * 0.8, 3.2, 4.5 - (i % 2) * 1.1),
			at * CFrame.new(0, h + 12 + (i % 3) * 5, 0)
				* CFrame.Angles(0, a, 0) * CFrame.new(0, 0, radius)
				* CFrame.Angles(math.rad(14 * (i % 2 == 0 and 1 or -1)), 0, math.rad(9)),
			tier.walls, Enum.Material.Slate)
		rock:SetAttribute("FX", "orbit")
		rock:SetAttribute("Rate", 0.05 + i * 0.012)
		rock:SetAttribute("Amount", radius)
		CollectionService:AddTag(rock, HouseFX.TAG)

		-- A lit underside on each, so they are visible against a bright sky.
		-- Rock against blue at a hundred studs is a grey dot; rock with a
		-- magenta edge is a floating island.
		glowPart("ShardGlow", Vector3.new(3.4 - (i % 3) * 0.6, 0.35, 3.4 - (i % 2) * 0.9),
			at * CFrame.new(0, h + 12 + (i % 3) * 5 - 1.9, 0)
				* CFrame.Angles(0, a, 0) * CFrame.new(0, 0, radius),
			fxColour(tier), { fx = "orbit", rate = 0.05 + i * 0.012, amount = radius })
	end

	for storey = 2, tier.storeys do
		windowRow(at, w, d / 2, (storey - 1) * STOREY + STOREY * 0.5, false, GLASS_DARK, 2.6, 4)
	end
end

-- ============================================================
-- BUILD
-- ============================================================

-- `at` is the PLOT ORIGIN at ground level. The house seats itself from there.
--
-- Each archetype has a different real footprint -- the modern box is 47 deep,
-- the shack 15 -- so a single hardcoded Z would either float the small ones in
-- the middle of the lawn or push the big ones through the back fence. Building
-- first and measuring after means every tier lands the same distance from the
-- fence regardless of how big it turned out.
function House.build(level: number, at: CFrame, parent: Instance): Model
	local tier = Config.getHouseTier(level)

	local model = Instance.new("Model")
	model.Name = "House"
	folder = model

	local build = builders[tier.style] or builders.shack
	build(tier, at)
	model.Parent = parent

	local box, size = model:GetBoundingBox()
	local localCentre = at:PointToObjectSpace(box.Position)

	-- SEATED BY ITS FRONT WALL, not its back, and centred sideways.
	--
	-- The back was pinned here for a long time, which sounds equivalent and is
	-- not: depth varies by 41 studs across the tiers, so pinning the back threw
	-- all of that forward onto the lawn and the three deepest houses ended up
	-- standing on decoration slots. See the note over Config.HOUSE_FRONT_LINE.
	--
	-- Centring matters because some archetypes are ASYMMETRIC: the villa's
	-- garage wing hangs off one side only, so a house whose stated width fits
	-- the yard can still put one corner straight through the side fence while
	-- leaving eight studs spare on the other.
	--
	-- ZVector, not LookVector: LookVector is the NEGATIVE Z axis, so using it
	-- here would shunt the house out toward the street.
	local wantFront = -Config.HOUSE_FRONT_LINE
	local haveFront = localCentre.Z + size.Z / 2
	model:TranslateBy(at.ZVector * (wantFront - haveFront))
	model:TranslateBy(at.RightVector * -localCentre.X)

	return model
end

return House
