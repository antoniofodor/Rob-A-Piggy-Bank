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
local LowPoly = require(ReplicatedStorage.Shared.LowPoly)

local House = {}

local STOREY = 9
-- Aliased rather than declared: `LowPoly.framedWindow` paints unlit panes
-- with this exact colour, and two files holding their own copy of one number
-- is how a window ends up a different blue from the window beside it.
local GLASS = LowPoly.GLASS
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
-- **A WedgePart IS FULL HEIGHT AT ITS +Z EDGE AND SLOPES TO NOTHING AT -Z.**
-- This comment asserted the opposite for the life of the project and the code
-- followed the comment, so EVERY GABLED HOUSE IN THIS GAME HAD ITS ROOF
-- INSIDE OUT: both halves rose toward the eaves and met in a valley over the
-- middle of the building.
--
-- It was never spotted because a roof is a single flat colour seen from
-- seventy studs away, where a valley and a ridge differ only by which way one
-- shading gradient runs -- and because nothing in the game reads a roof, so
-- nothing could fail. Measured on a live manor before the fix: y 23.69 at one
-- eave, 17.77 over the centre, 22.62 at the other. Measured on a bare test
-- wedge, which is what settled it: local z -4 -> top -3.20, z +4 -> top
-- +3.20, so the full-height edge is +Z.
--
-- Rotating on any other axis tips the slope onto its side.
local function gable(width: number, depth: number, baseY: number, pitch: number,
	color: Color3, at: CFrame)
	for _, dir in ipairs({ -1, 1 }) do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Roof"
		wedge.Size = Vector3.new(width, pitch, depth / 2)
		wedge.CFrame = at
			* CFrame.new(0, baseY + pitch / 2, dir * depth / 4)
			-- The near half is the one that needs turning, not the far half.
			* CFrame.Angles(0, if dir > 0 then math.pi else 0, 0)
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
-- ============================================================
-- THE REBUILT HOUSES (low poly)
-- ============================================================
--
-- A second set of builders, opted into per style by `Config.HOUSE_REBUILD`.
-- The originals above are untouched and still stand for every style not named
-- there. The argument for doing this in code rather than as a generated mesh
-- lives over that table.
--
-- The palette bits these share. Kept here rather than per tier because they
-- are STRUCTURAL colours -- what timber, stone and lit glass look like -- as
-- opposed to `tier.walls`/`roof`/`trim`, which are what makes one tier differ
-- from the next.
-- The structural colours and the whole low-poly vocabulary now live in
-- `Shared/LowPoly.luau`, because the SHOPS are built in it too and a second
-- copy is the duplicate this project keeps recording. What is left here is
-- nine one-line wrappers that hand it this build's own folder, so every tier
-- builder below reads exactly as it did when it was measured.
local TIMBER = LowPoly.TIMBER
local STONE = LowPoly.STONE
local WARM_GLASS = LowPoly.WARM_GLASS

local function tiledRoof(width: number, depth: number, baseY: number, pitch: number,
	rows: number, tile: Color3, trim: Color3, at: CFrame)
	LowPoly.tiledRoof(folder, width, depth, baseY, pitch, rows, tile, trim, at)
end

local function framedWindow(at: CFrame, w: number, h: number, trim: Color3,
	shutter: Color3?, unlit: boolean?)
	LowPoly.framedWindow(folder, at, w, h, trim, shutter, unlit)
end

local function windowBand(at: CFrame, span: number, y: number, z: number,
	count: number, w: number, h: number, trim: Color3, skipMiddle: boolean,
	shutter: Color3?, unlit: boolean?)
	LowPoly.windowBand(folder, at, span, y, z, count, w, h, trim, skipMiddle, shutter, unlit)
end

local function quoins(w: number, d: number, baseY: number, height: number,
	colour: Color3, at: CFrame)
	LowPoly.quoins(folder, w, d, baseY, height, colour, at)
end

local function column(height: number, diameter: number, cf: CFrame, shaft: Color3, trim: Color3)
	LowPoly.column(folder, height, diameter, cf, shaft, trim)
end

local function steps(count: number, width: number, tread: number, riser: number,
	baseY: number, zFront: number, colour: Color3, at: CFrame)
	LowPoly.steps(folder, count, width, tread, riser, baseY, zFront, colour, at)
end

local function parapet(w: number, d: number, y: number, height: number, thick: number,
	colour: Color3, at: CFrame)
	LowPoly.parapet(folder, w, d, y, height, thick, colour, at)
end

local function capRoof(width: number, depth: number, baseY: number, pitch: number,
	colour: Color3, at: CFrame)
	LowPoly.capRoof(folder, width, depth, baseY, pitch, colour, at)
end

local function pediment(width: number, thickness: number, baseY: number, rise: number,
	colour: Color3, at: CFrame)
	LowPoly.pediment(folder, width, thickness, baseY, rise, colour, at)
end

local rebuilt: { [string]: (any, CFrame) -> () } = {}

-- The cottage, rebuilt: plinth, half-timbered walls, a tiled gable.
rebuilt.cottage = function(tier, at)
	local w, d, h = tier.width, tier.depth, STOREY
	local plinth = 1.3

	part("Plinth", Vector3.new(w + 1.6, plinth, d + 1.6),
		at * CFrame.new(0, plinth / 2, 0), STONE, Enum.Material.SmoothPlastic)
	part("Walls", Vector3.new(w, h, d),
		at * CFrame.new(0, plinth + h / 2, 0), tier.walls, Enum.Material.SmoothPlastic)

	-- HALF TIMBERING: corner posts, a mid rail and a top plate. This is the
	-- single most identifiable thing about a storybook cottage, and it is four
	-- thin boxes rather than a texture.
	--
	-- EVERY PIECE OF IT STANDS PROUD OF THE WALL, AND THAT IS THE COPLANAR
	-- RULE RATHER THAN A LOOK. The first build sized the corner posts 0.7
	-- square and centred them at `w / 2 - 0.35`, which puts their outer faces
	-- at EXACTLY w / 2 -- the wall's own side plane -- and did the same again
	-- in Z. Two visible faces at one depth give the renderer nothing to sort
	-- by, so it picks per pixel and per camera angle and they strobe. The
	-- rails had it too: sized exactly `w` wide, their end caps landed in the
	-- wall's side plane.
	--
	-- Reported as the wood frame flickering and clipping, which is precisely
	-- what it was. Fifth time in this project -- the road against the grass,
	-- the moat against the grass, the guard dog's eyes against its own face,
	-- the drip statue's bag caps, and now this.
	--
	-- Half timbering is MEANT to be proud of the plaster anyway, so the fix
	-- costs nothing and is what the reference art shows.
	local PROUD = 0.15
	local midY = plinth + h * 0.58
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			-- Dropped 0.1 as well, so the post's top face is under the eaves
			-- rather than in the wall's top plane, and its base is buried in
			-- the plinth rather than sitting in the plinth's top plane.
			part("Post", Vector3.new(0.7, h, 0.7),
				at * CFrame.new(sx * (w / 2 - 0.35 + PROUD), plinth + h / 2 - 0.1,
					sz * (d / 2 - 0.35 + PROUD)),
				TIMBER, Enum.Material.SmoothPlastic)
		end
	end
	for _, sz in ipairs({ 1, -1 }) do
		-- Narrower than the wall so the ends die INSIDE the corner posts
		-- rather than in the wall's side plane. w - 0.7 puts each end at
		-- w/2 - 0.35, which is between the post's 0.55 and 0.15 faces.
		part("Rail", Vector3.new(w - 0.7, 0.6, 0.42),
			at * CFrame.new(0, midY, sz * (d / 2 + 0.05)),
			TIMBER, Enum.Material.SmoothPlastic)
		-- 0.1 below the posts' own tops, which it shared before.
		part("Plate", Vector3.new(w - 0.7, 0.7, 0.42),
			at * CFrame.new(0, plinth + h - 0.55, sz * (d / 2 + 0.05)),
			TIMBER, Enum.Material.SmoothPlastic)
	end

	-- The overhang and pitch are deliberately modest. The first build used
	-- +3.0 and a pitch of 10.5 against nine studs of wall, which made the roof
	-- the whole building -- a hat with a house under it rather than a cottage.
	tiledRoof(w + 2.0, d + 2.0, plinth + h, 8.5, 6, tier.roof, TIMBER, at)

	-- Door, framed and stepped, with the two front windows either side.
	local front = d / 2 + 0.05
	-- Both sunk 0.1 into the plinth. Sized to land their bottom faces exactly
	-- on `plinth`, they sat in the plinth's own top plane and strobed along
	-- the threshold for the same reason the posts did.
	part("DoorFrame", Vector3.new(6.0, 8.8, 0.5), at * CFrame.new(0, plinth + 4.3, front),
		TIMBER, Enum.Material.SmoothPlastic)
	part("Door", Vector3.new(4.6, 7.9, 0.42), at * CFrame.new(0, plinth + 3.75, front + 0.18),
		DOOR, Enum.Material.SmoothPlastic)
	part("Knob", Vector3.new(0.55, 0.55, 0.55),
		at * CFrame.new(1.5, plinth + 3.8, front + 0.45), tier.trim, Enum.Material.SmoothPlastic)
	part("Step", Vector3.new(7.2, 0.7, 2.2), at * CFrame.new(0, 0.30, front + 1.0),
		STONE, Enum.Material.SmoothPlastic)

	for _, sx in ipairs({ -1, 1 }) do
		framedWindow(at * CFrame.new(sx * w * 0.29, plinth + h * 0.55, front + 0.12), 4.4, 3.8, TIMBER)
	end

	-- A chimney with a cap, standing on the roof rather than beside it.
	part("Chimney", Vector3.new(3.6, 13.5, 3.6),
		at * CFrame.new(w / 3.2, plinth + h + 5.2, -d / 6), STONE, Enum.Material.SmoothPlastic)
	part("ChimneyCap", Vector3.new(4.4, 0.9, 4.4),
		at * CFrame.new(w / 3.2, plinth + h + 12.2, -d / 6), TIMBER, Enum.Material.SmoothPlastic)
end

-- The shack, rebuilt: the only tier in the catalogue meant to look unwell,
-- and therefore the one that has to go on looking unwell after a graphics
-- pass. Everything here is an ordinary cottage part built slightly wrong on
-- purpose -- blocks instead of a plinth, boards that do not line up, a door
-- off its hinges -- because CHEAP reads as a set of DEFECTS rather than as an
-- absence of detail. A shack with nothing on it is just a small box.
rebuilt.shack = function(tier, at)
	local w, d, h = tier.width, tier.depth, STOREY
	local front = d / 2
	local plank = TIMBER:Lerp(Color3.new(1, 1, 1), 0.22)
	local siding = tier.walls:Lerp(TIMBER, 0.16)

	-- BLOCKS RATHER THAN A PLINTH, WHICH IS THE WHOLE TIER IN ONE DECISION.
	-- Every rung above this stands on a dressed stone course. A shack stands
	-- on whatever was lying around, so the corners take four mismatched
	-- blocks at four different heights -- and the daylight under the deck is
	-- the point rather than a gap somebody forgot to close.
	local floorY = 1.9
	for _, c in ipairs({ { -1, -1, 1.5 }, { 1, -1, 1.7 }, { -1, 1, 1.6 }, { 1, 1, 1.8 } }) do
		part("Block", Vector3.new(3.4, c[3], 3.4),
			at * CFrame.new(c[1] * (w / 2 - 2.1), c[3] / 2, c[2] * (d / 2 - 2.1)),
			STONE, Enum.Material.SmoothPlastic)
	end
	part("Deck", Vector3.new(w + 1.4, 0.6, d + 1.4),
		at * CFrame.new(0, floorY - 0.3, 0), TIMBER, Enum.Material.SmoothPlastic)
	part("Walls", Vector3.new(w, h, d),
		at * CFrame.new(0, floorY + h / 2, 0), siding, Enum.Material.SmoothPlastic)

	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			-- Dropped 0.35 rather than 0.2, so the post's foot is buried in
			-- the deck instead of landing in the wall's own bottom plane.
			part("Corner", Vector3.new(0.8, h - 0.4, 0.8),
				at * CFrame.new(sx * (w / 2 + 0.14), floorY + h / 2 - 0.35, sz * (d / 2 + 0.14)),
				TIMBER, Enum.Material.SmoothPlastic)
		end
	end

	-- WEATHERBOARDS, TWO OF THEM PATCHED AND ONE THAT HAS SLIPPED. Flat
	-- colour cannot say "shabby" by itself; a run of boards where one is a
	-- different shade and one is two degrees off its neighbours can.
	local boards = 6
	local pitchY = (h - 1.4) / boards
	for i = 0, boards - 1 do
		local tilt = if i == 3 then math.rad(2.5) else 0
		local shade = if i == 1 or i == 4 then plank else siding:Lerp(TIMBER, 0.22)
		part("Board", Vector3.new(w - 1.6 - (i % 2) * 1.6, pitchY * 0.66, 0.3),
			at * CFrame.new(0, floorY + 0.9 + i * pitchY, front + 0.16) * CFrame.Angles(0, 0, tilt),
			shade, Enum.Material.SmoothPlastic)
	end

	-- A LEAN-TO, the cheapest roof there is, falling toward the STREET -- so
	-- what a thief sees from the pavement is the low edge and the whole sag
	-- of it rather than a tidy ridge.
	local roofY = floorY + h
	local rw, rd, rise = w + 1.8, d + 1.8, 3.2
	local shed = Instance.new("WedgePart")
	shed.Name = "Roof"
	shed.Size = Vector3.new(rw, rise, rd)
	shed.CFrame = at * CFrame.new(0, roofY + rise / 2, 0) * CFrame.Angles(0, math.pi, 0)
	shed.Anchored, shed.CanCollide, shed.CanQuery, shed.CastShadow = true, false, false, false
	shed.Color, shed.Material = tier.roof, Enum.Material.SmoothPlastic
	shed.Parent = folder

	-- Corrugation ribs and one patch panel, laid ON the slope. `along` runs
	-- down toward the street and `lift` is along the surface NORMAL, which is
	-- the arithmetic `tiledRoof` records at length: a lift in world Y is not
	-- perpendicular to a slope, so a detail lifted that way sits INSIDE the
	-- thing it is meant to be standing proud of.
	local theta = math.atan2(rise, rd)
	local slope = math.sqrt(rise * rise + rd * rd)
	local function onSlope(name: string, size: Vector3, x: number, along: number,
		lift: number, colour: Color3)
		part(name, size, at * CFrame.new(x,
			roofY + rise / 2 - math.sin(theta) * along + math.cos(theta) * lift,
			math.cos(theta) * along + math.sin(theta) * lift)
			* CFrame.Angles(theta, 0, 0), colour, Enum.Material.SmoothPlastic)
	end
	for i = 0, 4 do
		onSlope("Rib", Vector3.new(0.55, 0.3, slope + 0.3),
			-rw / 2 + rw / 10 + i * rw / 5, 0, 0.26,
			tier.roof:Lerp(Color3.new(0, 0, 0), 0.30))
	end
	onSlope("Patch", Vector3.new(rw * 0.26, 0.32, slope * 0.3), rw * 0.2, -slope * 0.18, 0.5, plank)
	part("Fascia", Vector3.new(rw + 0.3, 0.7, 0.5),
		at * CFrame.new(0, roofY - 0.15, rd / 2 + 0.12), TIMBER, Enum.Material.SmoothPlastic)

	-- A DOOR HANGING OFF ITS HINGES, braced with a plank somebody nailed on.
	-- The tilt is what does it: a straight door in a straight frame reads as
	-- a small house, and this tier is meant to read as a bodged one.
	part("DoorFrame", Vector3.new(5.4, 8.2, 0.5),
		at * CFrame.new(-1.4, floorY + 3.9, front + 0.30), TIMBER, Enum.Material.SmoothPlastic)
	part("Door", Vector3.new(4.0, 7.3, 0.4),
		at * CFrame.new(-1.4, floorY + 3.6, front + 0.42) * CFrame.Angles(0, 0, math.rad(-2.5)),
		DOOR, Enum.Material.SmoothPlastic)
	part("Brace", Vector3.new(4.6, 0.44, 0.3),
		at * CFrame.new(-1.4, floorY + 3.6, front + 0.66) * CFrame.Angles(0, 0, math.rad(29)),
		plank, Enum.Material.SmoothPlastic)

	framedWindow(at * CFrame.new(w * 0.27, floorY + h * 0.58, front + 0.34), 3.2, 2.6, TIMBER)
	part("Boarded", Vector3.new(5.6, 0.6, 0.32),
		at * CFrame.new(w * 0.27, floorY + h * 0.58, front + 0.86) * CFrame.Angles(0, 0, math.rad(-14)),
		plank, Enum.Material.SmoothPlastic)

	part("Prop", Vector3.new(0.6, h + 1.6, 0.6),
		at * CFrame.new(w / 2 - 0.3, floorY + h / 2, front - 1.1)
			* CFrame.Angles(math.rad(7), 0, math.rad(-6)), TIMBER, Enum.Material.SmoothPlastic)

	-- A stove pipe, not a chimney. Nobody built this one a fireplace.
	local flue = part("Flue", Vector3.new(5.6, 1.2, 1.2),
		at * CFrame.new(-w / 3, roofY + 4.4, -d / 5) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(72, 68, 66), Enum.Material.SmoothPlastic)
	flue.Shape = Enum.PartType.Cylinder
	local cowl = part("Cowl", Vector3.new(0.6, 2.0, 2.0),
		at * CFrame.new(-w / 3, roofY + 7.4, -d / 5) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(72, 68, 66), Enum.Material.SmoothPlastic)
	cowl.Shape = Enum.PartType.Cylinder

	-- Three planks up to the deck. Every flight in this file starts a shade
	-- BELOW the ground and stops a shade below whatever it lands on: level
	-- with either, the treads share a face plane over a real area with the
	-- thing they meet, which is the coplanar flicker the cottage shipped.
	steps(3, 6.0, 1.1, (floorY - 0.1 + 0.1) / 3, -0.1, front + 3.6, TIMBER, at)
end

-- The townhouse, rebuilt: three floors on a small footprint, so everything
-- here is about VERTICAL rhythm. String courses at the floor lines, a cornice
-- at the top, pilasters at the corners and a bay running two storeys up the
-- frontage -- so the height reads as floors somebody lives on rather than as
-- one tall block of brick.
rebuilt.townhouse = function(tier, at)
	local w, d = tier.width, tier.depth
	local h = tier.storeys * STOREY
	local plinth = 2.2
	local front = d / 2

	part("Plinth", Vector3.new(w + 1.8, plinth, d + 1.8),
		at * CFrame.new(0, plinth / 2, 0), STONE, Enum.Material.SmoothPlastic)
	part("Walls", Vector3.new(w, h, d),
		at * CFrame.new(0, plinth + h / 2, 0), tier.walls, Enum.Material.SmoothPlastic)

	-- CORNER PILASTERS RATHER THAN QUOINS, and that is a part budget rather
	-- than a taste call: twenty-seven studs of quoin is six blocks a corner
	-- and twenty-four parts, which is most of a house on a building this
	-- narrow. One strip gives the same hard vertical line where two flat
	-- walls meet, which is the whole job.
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			-- Sunk 0.15 into the plinth. Sized to land its foot exactly on
			-- `plinth` it shared the wall's own bottom plane, which is the
			-- same fault the cottage's corner posts shipped with.
			part("Pilaster", Vector3.new(1.6, h - 0.6, 1.6),
				at * CFrame.new(sx * (w / 2 - 0.64), plinth - 0.15 + (h - 0.6) / 2, sz * (d / 2 - 0.64)),
				tier.trim, Enum.Material.SmoothPlastic)
		end
	end

	-- A band at every floor line. This is the one thing that makes a tall box
	-- read as three storeys from the pavement, and it is a part each.
	for storey = 1, tier.storeys - 1 do
		part("Course", Vector3.new(w + 0.9, 0.75, d + 0.9),
			at * CFrame.new(0, plinth + storey * STOREY, 0), tier.trim, Enum.Material.SmoothPlastic)
	end
	part("Cornice", Vector3.new(w + 2.6, 1.4, d + 2.6),
		at * CFrame.new(0, plinth + h + 0.7, 0), tier.trim, Enum.Material.SmoothPlastic)

	tiledRoof(w + 2.0, d + 2.0, plinth + h + 1.4, 6.5, 4, tier.roof, tier.trim, at)

	-- TWO DORMERS IN THE FRONT SLOPE. The original used a mansard cap to stop
	-- height reading as roof; a dormer says the same thing and puts a lit
	-- window at the top of the building while it is at it.
	local roofBase = plinth + h + 1.4
	for _, dx in ipairs({ -w * 0.24, w * 0.24 }) do
		part("Dormer", Vector3.new(5.2, 5.0, 4.6),
			at * CFrame.new(dx, roofBase + 2.6, 5.4), tier.walls, Enum.Material.SmoothPlastic)
		capRoof(6.0, 5.4, roofBase + 5.1, 1.9, tier.roof, at * CFrame.new(dx, 0, 5.4))
		framedWindow(at * CFrame.new(dx, roofBase + 2.7, 7.82), 2.8, 2.4, tier.trim, nil, true)
	end

	-- A BAY, TWO STOREYS OF IT, which is what makes a townhouse a townhouse
	-- rather than a narrow block of flats. It oversails the plinth, so it
	-- gets a stone base of its own instead of ending in mid-air.
	local bayX, bayW, bayD = -w * 0.30, 6.6, 3.0
	local bayH = STOREY * 2 - 1.2
	part("BayBase", Vector3.new(bayW + 1.2, plinth + 0.65, bayD + 1.2),
		at * CFrame.new(bayX, (plinth + 0.35) / 2, front + bayD / 2), STONE, Enum.Material.SmoothPlastic)
	part("Bay", Vector3.new(bayW, bayH, bayD),
		at * CFrame.new(bayX, plinth + bayH / 2 - 0.12, front + bayD / 2),
		tier.walls, Enum.Material.SmoothPlastic)
	part("BayCap", Vector3.new(bayW + 1.0, 0.8, bayD + 1.0),
		at * CFrame.new(bayX, plinth + bayH + 0.4, front + bayD / 2), tier.trim, Enum.Material.SmoothPlastic)
	capRoof(bayW + 1.0, bayD + 1.8, plinth + bayH + 0.8, 1.7, tier.roof,
		at * CFrame.new(bayX, 0, front + bayD / 2))
	for storey = 0, 1 do
		framedWindow(at * CFrame.new(bayX, plinth + storey * STOREY + STOREY * 0.52,
			front + bayD + 0.12), 4.2, 3.8, tier.trim, nil, storey == 1)
	end

	-- The stoop, the door, and a hood on brackets over it.
	steps(4, 7.4, 1.15, (plinth - 0.1 + 0.1) / 4, -0.1, front + 5.2, STONE, at)
	-- EVERY DOOR FRAME IN THE REBUILT SET SITS AT `front + 0.10` AND SINKS
	-- 0.1 INTO WHAT IT STANDS ON. At front + 0.05 its outer face landed 0.02
	-- from a neighbouring window frame's, and sized to land its foot on the
	-- plinth it shared the wall's bottom plane -- two coplanar pairs on the
	-- one part of a house somebody walks straight up to.
	part("DoorFrame", Vector3.new(5.6, 10.0, 0.55),
		at * CFrame.new(1.0, plinth + 4.9, front + 0.10), tier.trim, Enum.Material.SmoothPlastic)
	part("Door", Vector3.new(4.2, 8.5, 0.42),
		at * CFrame.new(1.0, plinth + 4.30, front + 0.24), DOOR, Enum.Material.SmoothPlastic)
	part("Knob", Vector3.new(0.5, 0.5, 0.5),
		at * CFrame.new(2.6, plinth + 4.2, front + 0.5), tier.trim, Enum.Material.SmoothPlastic)
	-- A fanlight over the door: the one warm thing at eye level on a frontage
	-- whose windows all start a storey up.
	-- A FANLIGHT IS THE EASIEST PART IN A HOUSE TO LEAVE COPLANAR, because
	-- it lives inside a door frame and just above a door, so it is boxed in
	-- on two axes at once. It sits clear of the door in Y and clear of the
	-- frame in Z, and both clearances are deliberate rather than spare room.
	part("Fanlight", Vector3.new(4.2, 0.9, 0.3),
		at * CFrame.new(1.0, plinth + 9.1, front + 0.26), WARM_GLASS, Enum.Material.Neon)
	part("Hood", Vector3.new(7.6, 0.65, 3.2),
		at * CFrame.new(1.0, plinth + 10.5, front + 1.5), tier.trim, Enum.Material.SmoothPlastic)
	for _, sx in ipairs({ -1, 1 }) do
		part("Bracket", Vector3.new(0.5, 1.9, 2.2),
			at * CFrame.new(1.0 + sx * 3.0, plinth + 9.4, front + 1.25),
			tier.trim, Enum.Material.SmoothPlastic)
	end

	framedWindow(at * CFrame.new(6.0, plinth + STOREY * 0.52, front + 0.12), 3.0, 3.6, tier.trim)
	for _, x in ipairs({ 1.0, 6.4 }) do
		framedWindow(at * CFrame.new(x, plinth + STOREY + STOREY * 0.52, front + 0.12),
			3.0, 3.8, tier.trim, nil, true)
	end
	for _, x in ipairs({ -6.0, 0.4, 6.4 }) do
		framedWindow(at * CFrame.new(x, plinth + 2 * STOREY + STOREY * 0.52, front + 0.12),
			2.8, 3.4, tier.trim, nil, true)
	end

	-- A stack with real pots on it. Three little cylinders is the detail that
	-- says terrace rather than office block.
	local cx, cz = w * 0.26, -d * 0.22
	part("Chimney", Vector3.new(4.0, 15.0, 3.4),
		at * CFrame.new(cx, plinth + h + 6.0, cz), STONE, Enum.Material.SmoothPlastic)
	part("ChimneyCap", Vector3.new(4.8, 1.0, 4.2),
		at * CFrame.new(cx, plinth + h + 14.0, cz), tier.trim, Enum.Material.SmoothPlastic)
	for i = -1, 1 do
		local pot = part("Pot", Vector3.new(2.2, 1.05, 1.05),
			at * CFrame.new(cx + i * 1.25, plinth + h + 15.4, cz) * CFrame.Angles(0, 0, math.rad(90)),
			tier.roof, Enum.Material.SmoothPlastic)
		pot.Shape = Enum.PartType.Cylinder
	end
end

-- The villa, rebuilt: WIDTH, where the townhouse below it was height. A
-- roofline has to break rather than run flat across thirty-three studs, so
-- the garage wing keeps its own lower ridge and the porch cuts across the
-- main block in front of it -- three planes stepping forward instead of one
-- wall.
rebuilt.villa = function(tier, at)
	local w, d = tier.width, tier.depth
	local h = tier.storeys * STOREY
	local plinth = 1.5
	local front = d / 2
	local shutter = tier.roof

	part("Plinth", Vector3.new(w + 1.8, plinth, d + 1.8),
		at * CFrame.new(0, plinth / 2, 0), STONE, Enum.Material.SmoothPlastic)
	part("Walls", Vector3.new(w, h, d),
		at * CFrame.new(0, plinth + h / 2, 0), tier.walls, Enum.Material.SmoothPlastic)
	part("Course", Vector3.new(w + 0.9, 0.7, d + 0.9),
		at * CFrame.new(0, plinth + STOREY, 0), tier.trim, Enum.Material.SmoothPlastic)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			part("Pilaster", Vector3.new(1.5, h - 0.5, 1.5),
				at * CFrame.new(sx * (w / 2 - 0.6), plinth - 0.15 + (h - 0.5) / 2, sz * (d / 2 - 0.6)),
				tier.trim, Enum.Material.SmoothPlastic)
		end
	end
	tiledRoof(w + 2.6, d + 2.6, plinth + h, 8.5, 5, tier.roof, tier.trim, at)

	-- THE GARAGE WING, lower and stepped forward, with its own roof. This is
	-- the tier's whole silhouette and it is why the villa is the one house in
	-- the game that is not symmetrical about its own centre -- which is also
	-- why `House.build` centres a house on its measured bounds rather than on
	-- its stated width.
	local gw, gd = w * 0.34, d * 0.72
	local gx, gz = -w / 2 - gw / 2 + 2.5, d * 0.10
	local gAt = at * CFrame.new(gx, 0, gz)
	part("GaragePlinth", Vector3.new(gw + 1.6, plinth + 0.27, gd + 1.6),
		gAt * CFrame.new(0, (plinth + 0.03) / 2, 0), STONE, Enum.Material.SmoothPlastic)
	part("Garage", Vector3.new(gw, STOREY, gd),
		gAt * CFrame.new(0, plinth + STOREY / 2 - 0.25, 0), tier.walls, Enum.Material.SmoothPlastic)
	tiledRoof(gw + 2.2, gd + 2.2, plinth + STOREY, 5.0, 3, tier.roof, tier.trim, gAt)

	-- A PANELLED DOOR. Five ribs standing proud is the difference between a
	-- garage door and a rectangle painted on a wall, and flat colour has no
	-- other way of saying it.
	local gFront = gd / 2
	part("GarageFrame", Vector3.new(gw - 2.0, 8.6, 0.5),
		gAt * CFrame.new(0, plinth + 4.35, gFront + 0.10), tier.trim, Enum.Material.SmoothPlastic)
	part("GarageDoor", Vector3.new(gw - 3.2, 7.8, 0.4),
		gAt * CFrame.new(0, plinth + 4.0, gFront + 0.24),
		tier.trim:Lerp(Color3.new(0, 0, 0), 0.28), Enum.Material.SmoothPlastic)
	for i = 0, 4 do
		part("Panel", Vector3.new(gw - 4.2, 0.9, 0.32),
			gAt * CFrame.new(0, plinth + 1.0 + i * 1.5, gFront + 0.46),
			tier.trim:Lerp(Color3.new(1, 1, 1), 0.14), Enum.Material.SmoothPlastic)
	end

	-- THE PORCH, across the main block only, so the frontage steps twice --
	-- garage, house, porch -- rather than presenting one flat wall.
	local px = w * 0.14
	local pw, pd = w * 0.52, 7.0
	part("PorchDeck", Vector3.new(pw + 1.4, 0.7, pd + 1.0),
		at * CFrame.new(px, plinth - 0.40, front + pd / 2), STONE, Enum.Material.SmoothPlastic)
	part("PorchRoof", Vector3.new(pw + 1.6, 0.8, pd + 1.4),
		at * CFrame.new(px, plinth + STOREY - 0.6, front + pd / 2), tier.trim, Enum.Material.SmoothPlastic)
	capRoof(pw + 1.6, pd + 2.0, plinth + STOREY - 0.2, 2.2, tier.roof,
		at * CFrame.new(px, 0, front + pd / 2))
	for _, sx in ipairs({ -1, 1 }) do
		column(STOREY - 1.0, 1.3, at * CFrame.new(px + sx * pw * 0.46, plinth, front + pd - 0.9),
			tier.trim, tier.trim:Lerp(Color3.new(1, 1, 1), 0.3))
		-- A rail between the posts, which is what stops a porch reading as a
		-- canopy on sticks.
		part("PorchRail", Vector3.new(pw * 0.30, 0.5, 0.42),
			at * CFrame.new(px + sx * pw * 0.31, plinth + 3.0, front + pd - 0.9),
			tier.trim, Enum.Material.SmoothPlastic)
	end
	steps(2, 8.0, 1.2, 0.75, -0.1, front + pd + 1.3, STONE, at)

	part("DoorFrame", Vector3.new(6.4, 9.4, 0.58),
		at * CFrame.new(px, plinth + 4.6, front + 0.10), tier.trim, Enum.Material.SmoothPlastic)
	part("Door", Vector3.new(5.0, 8.4, 0.42),
		at * CFrame.new(px, plinth + 4.3, front + 0.26), DOOR, Enum.Material.SmoothPlastic)
	part("Knob", Vector3.new(0.5, 0.5, 0.5),
		at * CFrame.new(px + 1.8, plinth + 4.2, front + 0.5), tier.trim, Enum.Material.SmoothPlastic)

	framedWindow(at * CFrame.new(w * 0.34, plinth + STOREY * 0.52, front + 0.12), 4.4, 3.8, tier.trim, shutter)
	framedWindow(at * CFrame.new(-w * 0.20, plinth + STOREY * 0.52, front + 0.12), 4.4, 3.8, tier.trim, shutter)
	-- Asked for four and given whatever the span will hold. Shutters make a
	-- window nearly twice as wide as its glass, so this rank runs unshuttered
	-- and the two big ground-floor ones -- which have eighteen studs between
	-- them -- keep theirs.
	windowBand(at, w - 4, plinth + STOREY + STOREY * 0.52, front + 0.12, 4, 3.6, 3.6,
		tier.trim, false, nil, true)

	local cx = w * 0.30
	part("Chimney", Vector3.new(4.2, 13.0, 3.8),
		at * CFrame.new(cx, plinth + h + 5.0, -d * 0.16), STONE, Enum.Material.SmoothPlastic)
	part("ChimneyCap", Vector3.new(5.0, 1.0, 4.6),
		at * CFrame.new(cx, plinth + h + 12.0, -d * 0.16), tier.trim, Enum.Material.SmoothPlastic)
end

-- The manor, rebuilt: symmetry, and enough of it that the eye reads the whole
-- frontage as one composition. Quoined corners, two lower wings, three ranks
-- of windows on a grid, and a real portico -- four columns, an entablature
-- and a pediment -- because the tier's entire job is to be the grand one.
rebuilt.manor = function(tier, at)
	local w, d = tier.width, tier.depth
	local h = tier.storeys * STOREY
	local plinth = 2.6
	local front = d / 2
	local pale = tier.trim:Lerp(Color3.new(1, 1, 1), 0.42)

	part("Plinth", Vector3.new(w + 2.2, plinth, d + 2.2),
		at * CFrame.new(0, plinth / 2, 0), STONE, Enum.Material.SmoothPlastic)
	part("Walls", Vector3.new(w, h, d),
		at * CFrame.new(0, plinth + h / 2, 0), tier.walls, Enum.Material.SmoothPlastic)
	quoins(w, d, plinth, h, tier.trim, at)
	part("Course", Vector3.new(w + 1.0, 0.7, d + 1.0),
		at * CFrame.new(0, plinth + STOREY, 0), tier.trim, Enum.Material.SmoothPlastic)
	part("Cornice", Vector3.new(w + 2.8, 1.5, d + 2.8),
		at * CFrame.new(0, plinth + h + 0.75, 0), tier.trim, Enum.Material.SmoothPlastic)
	-- DENTILS under the cornice: a row of little blocks, which is the one
	-- ornament that reads as classical at any distance and costs a part each.
	-- Deep enough to bury their back ends in the wall, or the row hangs in
	-- the air a stud off the building it is meant to be attached to.
	for i = 0, 15 do
		part("Dentil", Vector3.new((w + 2.4) / 16 * 0.5, 0.6, 1.6),
			at * CFrame.new(-(w + 2.4) / 2 + (w + 2.4) / 32 + i * (w + 2.4) / 16,
				plinth + h - 0.35, front + 0.7), tier.trim, Enum.Material.SmoothPlastic)
	end
	tiledRoof(w + 2.4, d + 2.4, plinth + h + 1.5, 9.5, 5, tier.roof, tier.trim, at)

	-- TWO LOWER WINGS, one each side, so the frontage STEPS. A manor built as
	-- one long slab is a school.
	local ww, wh = w * 0.20, h - STOREY
	for _, sx in ipairs({ -1, 1 }) do
		local wAt = at * CFrame.new(sx * (w / 2 + ww / 2 - 1.2), 0, 0)
		part("WingPlinth", Vector3.new(ww + 1.6, plinth + 0.3, d * 0.8 + 1.6),
			wAt * CFrame.new(0, (plinth + 0.06) / 2, 0), STONE, Enum.Material.SmoothPlastic)
		part("Wing", Vector3.new(ww, wh, d * 0.8),
			wAt * CFrame.new(0, plinth + wh / 2 - 0.15, 0), tier.walls, Enum.Material.SmoothPlastic)
		tiledRoof(ww + 2.0, d * 0.8 + 2.0, plinth + wh, 5.5, 3, tier.roof, tier.trim, wAt)
		for storey = 0, 1 do
			framedWindow(wAt * CFrame.new(0, plinth + storey * STOREY + STOREY * 0.55,
				d * 0.4 + 0.12), 3.4, 3.6, tier.trim, nil, storey == 1)
		end
	end

	-- THE PORTICO. The pediment is the reason `pediment` exists at all: a
	-- triangle across WIDTH, which no arrangement of `gable` produces.
	local pw, pd = w * 0.46, 9.0
	local ph = h * 0.62
	part("PorticoBase", Vector3.new(pw + 2.4, plinth + 0.6, pd + 1.6),
		at * CFrame.new(0, (plinth + 0.2) / 2, front + pd / 2), STONE, Enum.Material.SmoothPlastic)
	for i = -1.5, 1.5, 1 do
		column(ph, 2.4, at * CFrame.new(i * (pw / 3.2), plinth + 0.4, front + pd - 1.4), pale, tier.trim)
	end
	part("Entablature", Vector3.new(pw + 2.6, 2.0, pd + 1.2),
		at * CFrame.new(0, plinth + 0.4 + ph + 1.0, front + pd / 2 - 0.2),
		tier.trim, Enum.Material.SmoothPlastic)
	pediment(pw + 2.6, 1.4, plinth + 0.4 + ph + 2.0, 4.2, tier.trim,
		at * CFrame.new(0, 0, front + pd - 0.9))
	-- A pediment is a flat triangle with nothing on its face, which at this
	-- size is a blank sail. A roundel is the classical answer and it is one
	-- part.
	local roundel = part("Roundel", Vector3.new(0.4, 2.4, 2.4),
		at * CFrame.new(0, plinth + 0.4 + ph + 3.4, front + pd - 0.3) * CFrame.Angles(0, 0, math.rad(90)),
		pale, Enum.Material.SmoothPlastic)
	roundel.Shape = Enum.PartType.Cylinder

	steps(3, pw + 2.0, 1.4, 1.0, -0.1, front + pd + 2.4, STONE, at)

	part("DoorFrame", Vector3.new(7.4, 12.0, 0.55),
		at * CFrame.new(0, plinth + 5.9, front + 0.10), tier.trim, Enum.Material.SmoothPlastic)
	part("Door", Vector3.new(6.0, 10.6, 0.42),
		at * CFrame.new(0, plinth + 5.4, front + 0.26), DOOR, Enum.Material.SmoothPlastic)
	part("Fanlight", Vector3.new(5.6, 1.1, 0.36),
		at * CFrame.new(0, plinth + 11.3, front + 0.28), WARM_GLASS, Enum.Material.Neon)

	windowBand(at, w - 2, plinth + STOREY * 0.55, front + 0.12, 3, 4.4, 4.4, tier.trim, true)
	windowBand(at, w - 2, plinth + STOREY + STOREY * 0.55, front + 0.12, 5, 3.8, 4.2,
		tier.trim, false, nil, true)
	windowBand(at, w - 2, plinth + 2 * STOREY + STOREY * 0.55, front + 0.12, 5, 3.8, 3.6,
		tier.trim, false, nil, true)

	for _, sx in ipairs({ -1, 1 }) do
		local cx = sx * w * 0.28
		part("Chimney", Vector3.new(4.4, 16.0, 3.8),
			at * CFrame.new(cx, plinth + h + 7.0, -d * 0.18), STONE, Enum.Material.SmoothPlastic)
		part("ChimneyCap", Vector3.new(5.2, 1.0, 4.6),
			at * CFrame.new(cx, plinth + h + 15.5, -d * 0.18), tier.trim, Enum.Material.SmoothPlastic)
		for i = -1, 1 do
			local pot = part("Pot", Vector3.new(2.2, 1.05, 1.05),
				at * CFrame.new(cx + i * 1.3, plinth + h + 17.0, -d * 0.18)
					* CFrame.Angles(0, 0, math.rad(90)), tier.roof, Enum.Material.SmoothPlastic)
			pot.Shape = Enum.PartType.Cylinder
		end
	end
end


-- The Midnight Modern, rebuilt. Flat roofs and a cantilever were always the
-- right silhouette; what this tier never had was anything to look at up
-- close, because a black box with one sheet of glass on it is a black box.
--
-- THE FRONTAGE IS THREE MATERIALS NOW RATHER THAN ONE. Every low-poly modern
-- house in the reference set does the same thing: a warm TIMBER SLAT panel
-- against the dark mass, glazing divided by real mullions, and a solid entry
-- bay. Flat colour beside flat colour is two rectangles; the ribs are what
-- make one of them read as a material.
--
-- The two animated strips are untouched -- one part and six coping segments,
-- exactly as before. They are the quietest effect in the file on purpose:
-- the modern is the restrained tier, and that restraint is what makes the
-- Neon Tower above it read as loud.
rebuilt.modern = function(tier, at)
	local w, d = tier.width, tier.depth
	local ground, upper = STOREY + 2, STOREY + 1
	local inset = 5
	local gw, gd = w - inset * 2, d - 2
	local base = 0.9
	local slat = Color3.fromRGB(154, 104, 58)
	local pale = Color3.fromRGB(206, 202, 196)
	local concrete = Color3.fromRGB(66, 66, 72)

	local function tinted(name: string, size: Vector3, cf: CFrame): Part
		local p = part(name, size, cf, GLASS_TINT, Enum.Material.Glass)
		p.Reflectance = 0.35
		return p
	end

	-- A PODIUM, which is this tier's version of a plinth. It was the one
	-- house in the catalogue resting straight on the grass, and it needed the
	-- base more than any of them: there is no roof overhang and no trim here
	-- to break the silhouette either, so without it the whole building is a
	-- rectangle sitting on a lawn.
	part("Podium", Vector3.new(w + 4, base, d + 8),
		at * CFrame.new(0, base / 2, 3), concrete, Enum.Material.SmoothPlastic)
	part("Walls", Vector3.new(gw, ground, gd),
		at * CFrame.new(0, base + ground / 2, 0), tier.walls, Enum.Material.SmoothPlastic)

	local gFront = gd / 2
	local midY = base + ground / 2

	part("SlatBack", Vector3.new(10.0, ground - 1.6, 0.45),
		at * CFrame.new(-11.5, midY, gFront + 0.16),
		slat:Lerp(Color3.new(0, 0, 0), 0.45), Enum.Material.SmoothPlastic)
	for i = 0, 8 do
		part("Slat", Vector3.new(0.62, ground - 2.2, 0.42),
			at * CFrame.new(-16.0 + i * 1.12, midY, gFront + 0.42), slat, Enum.Material.SmoothPlastic)
	end

	tinted("Glazing", Vector3.new(16, ground - 2.6, 0.6), at * CFrame.new(2, midY, gFront))
	for i = -2, 2 do
		part("Mullion", Vector3.new(0.34, ground - 3.2, 0.52),
			at * CFrame.new(2 + i * 3.6, midY, gFront + 0.26), pale, Enum.Material.SmoothPlastic)
	end
	part("Transom", Vector3.new(16.4, 0.34, 0.5),
		at * CFrame.new(2, midY + 2.0, gFront + 0.2), pale, Enum.Material.SmoothPlastic)

	part("DoorFrame", Vector3.new(6.0, ground - 2.0, 0.55),
		at * CFrame.new(13.2, midY - 0.4, gFront + 0.05), pale, Enum.Material.SmoothPlastic)
	part("Door", Vector3.new(4.6, ground - 3.0, 0.42),
		at * CFrame.new(13.2, midY - 0.7, gFront + 0.24),
		Color3.fromRGB(16, 16, 20), Enum.Material.SmoothPlastic)
	-- One warm slot over the door. There is no night in this game, so this is
	-- not about darkness -- it is the only thing on a black building saying
	-- somebody lives in it.
	part("Hall", Vector3.new(3.6, 0.7, 0.3),
		at * CFrame.new(13.2, midY + 3.7, gFront + 0.22), WARM_GLASS, Enum.Material.Neon)

	-- The cantilevered upper floor: wider than the ground floor and pushed
	-- forward, so it visibly hangs in the air.
	local upperY = base + ground + upper / 2
	part("Soffit", Vector3.new(w + 0.8, 0.7, d - 0.6),
		at * CFrame.new(0, base + ground + 0.30, 2), concrete, Enum.Material.SmoothPlastic)
	part("Upper", Vector3.new(w, upper, d),
		at * CFrame.new(0, upperY, 2), tier.walls, Enum.Material.SmoothPlastic)
	tinted("UpperGlass", Vector3.new(w - 6, upper - 3.4, 0.6), at * CFrame.new(0, upperY, d / 2 + 2))
	for i = -4, 4 do
		part("Mullion", Vector3.new(0.34, upper - 4.0, 0.52),
			at * CFrame.new(i * (w - 6) / 9, upperY, d / 2 + 2.26), pale, Enum.Material.SmoothPlastic)
	end
	for _, sx in ipairs({ -1, 1 }) do
		tinted("SideGlass", Vector3.new(0.6, upper - 3.4, d - 6), at * CFrame.new(sx * w / 2, upperY, 2))
	end

	glowPart("Strip", Vector3.new(w - 1, 0.35, 0.5),
		at * CFrame.new(0, base + ground + 0.4, d / 2 + 2), fxColour(tier),
		{ fx = "pulse", rate = 0.16, dim = 0.45 })

	local roofY = base + ground + upper
	part("RoofSlab", Vector3.new(w + 1, 0.8, d + 1),
		at * CFrame.new(0, roofY + 0.4, 2), tier.roof, Enum.Material.SmoothPlastic)
	parapet(w + 1, d + 1, roofY + 0.8, 1.8, 0.6, tier.roof, at * CFrame.new(0, 0, 2))
	for i = 0, 5 do
		glowPart("Coping", Vector3.new((w + 1) / 6 - 0.4, 0.22, 0.4),
			at * CFrame.new(-(w + 1) / 2 + (w + 1) / 12 + i * (w + 1) / 6,
				roofY + 2.0, d / 2 + 3.2), fxColour(tier),
			{ fx = "chase", phase = i / 6, rate = 0.34, span = 0.4, dim = 0.3 })
	end

	for _, sx in ipairs({ -1, 1 }) do
		-- Size is (LENGTH, diameter, diameter), not (diameter, height,
		-- diameter). A Roblox cylinder's axis is its X axis, and written the
		-- other way round this was a wide disc that the Z-turn then laid
		-- flat -- two black plates hanging across the front of the house.
		local pillar = part("Piloti", Vector3.new(ground, 1.3, 1.3),
			at * CFrame.new(sx * (w / 2 - 2), base + ground / 2, d / 2 + 1.5)
				* CFrame.Angles(0, 0, math.rad(90)), concrete, Enum.Material.SmoothPlastic)
		pillar.Shape = Enum.PartType.Cylinder
	end

	part("Path", Vector3.new(9, 0.35, 14),
		at * CFrame.new(13.2, base + 0.18, d / 2 + 12), Color3.fromRGB(96, 96, 102),
		Enum.Material.SmoothPlastic)
	for _, sx in ipairs({ -1, 1 }) do
		part("Planter", Vector3.new(4.0, 1.7, 7.0),
			at * CFrame.new(13.2 + sx * 7.2, base + 0.85, d / 2 + 8), concrete, Enum.Material.SmoothPlastic)
		part("Shrub", Vector3.new(3.4, 1.3, 6.4),
			at * CFrame.new(13.2 + sx * 7.2, base + 2.05, d / 2 + 8),
			Color3.fromRGB(74, 108, 62), Enum.Material.SmoothPlastic)
	end
end

-- The Neon Tower, rebuilt. The light show is exactly what it was -- eighteen
-- cycling bands, twelve chasing risers, a beacon and an eight-ball halo -- so
-- everything here is about the building underneath it, which was a plain slab
-- with glass stuck on and four thin posts at the corners.
--
-- What makes a tower read as FLOORS rather than as one tall box is the
-- SPANDREL: the solid band between one storey's glazing and the next. It is
-- one part per level and it does more for the silhouette than the glass does.
rebuilt.tower = function(tier, at)
	local w, d = tier.width, tier.depth
	local floor = STOREY
	local h = tier.storeys * floor
	local base = 1.2
	local pale = Color3.fromRGB(196, 200, 210)

	part("Podium", Vector3.new(w + 8, base, d + 10),
		at * CFrame.new(0, base / 2, 3), tier.roof, Enum.Material.SmoothPlastic)
	part("Core", Vector3.new(w, h, d),
		at * CFrame.new(0, base + h / 2, 0), tier.walls, Enum.Material.SmoothPlastic)

	for level = 0, tier.storeys - 1 do
		local y = base + level * floor + floor * 0.55
		for _, spec in ipairs({
			{ Vector3.new(w - 5, floor * 0.55, 0.5), Vector3.new(0, y, d / 2) },
			{ Vector3.new(w - 5, floor * 0.55, 0.5), Vector3.new(0, y, -d / 2) },
			{ Vector3.new(0.5, floor * 0.55, d - 5), Vector3.new(w / 2, y, 0) },
			{ Vector3.new(0.5, floor * 0.55, d - 5), Vector3.new(-w / 2, y, 0) },
		}) do
			local glass = part("Glazing", spec[1], at * CFrame.new(spec[2]), GLASS_TINT, Enum.Material.Glass)
			glass.Reflectance = 0.4
		end
		part("Spandrel", Vector3.new(w + 0.7, floor * 0.28, d + 0.7),
			at * CFrame.new(0, base + level * floor + floor * 0.16, 0),
			tier.roof, Enum.Material.SmoothPlastic)
		for i = -2, 2 do
			part("Mullion", Vector3.new(0.36, floor * 0.5, 0.46),
				at * CFrame.new(i * (w - 5) / 5, y, d / 2 + 0.26), pale, Enum.Material.SmoothPlastic)
		end

		-- A LIT BAND PER FLOOR, CYCLING, PHASED PER STOREY -- one colour wave
		-- travelling up the building. This is the loudest thing available at
		-- a hundred studs, because it is the only effect that changes while
		-- nothing moves, and it is why the tier is called the Neon Tower
		-- rather than the Glass One. Front and both sides; the back faces
		-- the grove and nobody stands there.
		local phase = level / tier.storeys
		local bandY = base + level * floor + floor - 0.6
		glowPart("Band", Vector3.new(w - 3, 0.4, 0.4),
			at * CFrame.new(0, bandY, d / 2 + 0.5), fxColour(tier),
			{ fx = "cycle", phase = phase, rate = 0.22 })
		for _, sx in ipairs({ -1, 1 }) do
			glowPart("Band", Vector3.new(0.4, 0.4, d - 3),
				at * CFrame.new(sx * (w / 2 + 0.5), bandY, 0), fxColour(tier),
				{ fx = "cycle", phase = phase, rate = 0.22 })
		end
	end

	-- Corner columns run the full height and are what actually makes this
	-- read as a tower rather than a stack of boxes. Chunkier than they were,
	-- with a base and a cap, because they are the building's only vertical
	-- line and at six storeys a 1.6 post is a wire.
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			part("Column", Vector3.new(2.0, h - 0.5, 2.0),
				at * CFrame.new(sx * (w / 2 + 0.2), base - 0.15 + (h - 0.5) / 2, sz * (d / 2 + 0.2)),
				tier.roof, Enum.Material.SmoothPlastic)
			part("ColumnFoot", Vector3.new(2.8, 1.8, 2.8),
				at * CFrame.new(sx * (w / 2 + 0.2), base + 0.7, sz * (d / 2 + 0.2)),
				tier.roof:Lerp(Color3.new(1, 1, 1), 0.16), Enum.Material.SmoothPlastic)
		end
	end

	-- A LIGHT RUNNING UP THE TWO FRONT CORNERS, cut into a segment per
	-- storey. A chase needs segments by construction: a single full-height
	-- strip can only get brighter and dimmer, and what reads as travel is a
	-- lit band arriving somewhere it was not a moment ago. Moved outboard of
	-- the thicker columns, or they would be buried in them.
	for _, sx in ipairs({ -1, 1 }) do
		for level = 0, tier.storeys - 1 do
			glowPart("Riser", Vector3.new(0.45, floor - 0.6, 0.45),
				at * CFrame.new(sx * (w / 2), base + level * floor + floor / 2, d / 2 + 1.55),
				fxColour(tier),
				{ fx = "chase", phase = level / tier.storeys, rate = 0.5, span = 0.3, dim = 0.12 })
		end
	end

	-- A CROWN RATHER THAN A LID. The original stopped with a flat cap and a
	-- pole, which is where a tower most needs a shape -- it is the part that
	-- clears the treeline and is the only part half the street can see.
	local topY = base + h
	part("Cap", Vector3.new(w + 3.0, 1.0, d + 3.0),
		at * CFrame.new(0, topY + 0.5, 0), tier.roof, Enum.Material.SmoothPlastic)
	part("Crown", Vector3.new(w - 3, 3.4, d - 3),
		at * CFrame.new(0, topY + 2.7, 0), tier.walls, Enum.Material.SmoothPlastic)
	part("CrownCap", Vector3.new(w - 1.4, 0.7, d - 1.4),
		at * CFrame.new(0, topY + 4.75, 0), tier.roof, Enum.Material.SmoothPlastic)
	part("Mast", Vector3.new(0.8, 9, 0.8),
		at * CFrame.new(0, topY + 9.4, 0), tier.roof, Enum.Material.SmoothPlastic)

	glowPart("Beacon", Vector3.new(2.8, 2.8, 2.8),
		at * CFrame.new(0, topY + 12.6, 0), fxColour(tier), { fx = "beacon", rate = 0.45, dim = 0.1 })
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		glowPart("Halo", Vector3.new(1.6, 1.6, 1.6),
			at * CFrame.new(0, topY + 8.6, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 4.4),
			fxColour(tier), { fx = "orbit", rate = 0.3, amount = 4.4 }).Shape = Enum.PartType.Ball
	end

	-- The entrance: a canopy, a framed door and a lit reveal, so the bottom
	-- of the building is somewhere a person arrives rather than where the
	-- glazing happens to stop.
	local front = d / 2
	part("Canopy", Vector3.new(w * 0.6, 0.7, 6.4),
		at * CFrame.new(0, base + 8.0, front + 3.2), tier.roof, Enum.Material.SmoothPlastic)
	for _, sx in ipairs({ -1, 1 }) do
		local post = part("CanopyPost", Vector3.new(7.6, 0.7, 0.7),
			at * CFrame.new(sx * w * 0.24, base + 3.9, front + 5.6) * CFrame.Angles(0, 0, math.rad(90)),
			tier.roof, Enum.Material.SmoothPlastic)
		post.Shape = Enum.PartType.Cylinder
	end
	part("DoorFrame", Vector3.new(7.0, 9.0, 0.6),
		at * CFrame.new(0, base + 4.4, front + 0.10), pale, Enum.Material.SmoothPlastic)
	part("Door", Vector3.new(5.6, 8.0, 0.42),
		at * CFrame.new(0, base + 4.1, front + 0.26), Color3.fromRGB(14, 15, 20),
		Enum.Material.SmoothPlastic)
	part("Reveal", Vector3.new(6.6, 0.5, 0.3),
		at * CFrame.new(0, base + 8.6, front + 0.30), WARM_GLASS, Enum.Material.Neon)
	steps(2, 12.0, 1.6, 0.62, -0.1, front + 8.4, tier.roof, at)
end

-- The Marble Palace, rebuilt. Everything that made it read from the road --
-- the gold dome, the turning halo, the lit colonnade and the lit steps -- is
-- unchanged and still twenty animated parts. What it never had was anything
-- BETWEEN those: the wall was one flat white slab with a row of windows on
-- it, which at close range is the least palatial surface in the game.
--
-- The additions are all relief rather than colour, and that is deliberate.
-- This file already records what happened when the cornice, the columns and
-- the steps were all painted in the tier's gold: the whole building became
-- one yellow mass at a distance and the dome stopped being the gold bit. So
-- the quoins, the dentils and the balustrade are marble a shade darker than
-- the wall, and they read by SHADOW.
rebuilt.palace = function(tier, at)
	local w, d = tier.width, tier.depth
	local h = tier.storeys * STOREY
	local plinth = 3.0
	local front = d / 2
	local stone = tier.walls
	local shade = tier.walls:Lerp(Color3.new(0, 0, 0), 0.12)

	part("Plinth", Vector3.new(w + 3.2, 1.7, d + 3.2),
		at * CFrame.new(0, 0.85, 0), STONE, Enum.Material.SmoothPlastic)
	part("Base", Vector3.new(w + 2.0, 1.4, d + 2.0),
		at * CFrame.new(0, 2.35, 0), shade, Enum.Material.SmoothPlastic)
	part("Walls", Vector3.new(w, h, d),
		at * CFrame.new(0, plinth + h / 2, 0), stone, Enum.Material.SmoothPlastic)
	quoins(w, d, plinth, h, shade, at)
	part("Course", Vector3.new(w + 1.2, 0.8, d + 1.2),
		at * CFrame.new(0, plinth + STOREY, 0), shade, Enum.Material.SmoothPlastic)
	part("Cornice", Vector3.new(w + 3.4, 1.8, d + 3.4),
		at * CFrame.new(0, plinth + h + 0.9, 0), stone, Enum.Material.SmoothPlastic)
	for i = 0, 17 do
		part("Dentil", Vector3.new((w + 2.8) / 18 * 0.5, 0.7, 1.8),
			at * CFrame.new(-(w + 2.8) / 2 + (w + 2.8) / 36 + i * (w + 2.8) / 18,
				plinth + h - 0.45, front + 0.8), shade, Enum.Material.SmoothPlastic)
	end

	local roofY = plinth + h + 1.8
	part("RoofSlab", Vector3.new(w + 3.0, 0.8, d + 3.0),
		at * CFrame.new(0, roofY + 0.4, 0), stone, Enum.Material.SmoothPlastic)

	-- A BALUSTRADE ALONG THE FRONT ROOFLINE. Front only, and that is a part
	-- budget rather than a compromise: a palace is looked at from the ROAD,
	-- three runs would be fifty parts, and nobody is ever behind this one.
	local balZ = front + 0.6
	part("BalBottom", Vector3.new(w + 2.2, 0.5, 1.2),
		at * CFrame.new(0, roofY + 1.05, balZ), shade, Enum.Material.SmoothPlastic)
	for i = 0, 12 do
		local baluster = part("Baluster", Vector3.new(0.9, 1.9, 0.9),
			at * CFrame.new(-(w - 1) / 2 + i * (w - 1) / 12, roofY + 2.25, balZ)
				* CFrame.Angles(0, 0, math.rad(90)), stone, Enum.Material.SmoothPlastic)
		baluster.Shape = Enum.PartType.Cylinder
	end
	part("BalTop", Vector3.new(w + 2.8, 0.6, 1.5),
		at * CFrame.new(0, roofY + 3.5, balZ), stone, Enum.Material.SmoothPlastic)
	for _, sx in ipairs({ -1, 1 }) do
		part("Pedestal", Vector3.new(2.6, 3.6, 2.6),
			at * CFrame.new(sx * (w / 2 + 0.9), roofY + 2.4, balZ), shade, Enum.Material.SmoothPlastic)
		local urn = part("Urn", Vector3.new(2.6, 2.2, 2.2),
			at * CFrame.new(sx * (w / 2 + 0.9), roofY + 5.3, balZ) * CFrame.Angles(0, 0, math.rad(90)),
			tier.roof, Enum.Material.SmoothPlastic)
		urn.Shape = Enum.PartType.Cylinder
	end

	-- THE DOME. Drum, dome, and a lantern cupola on top of it -- the cupola
	-- is what stops the dome ending in a spike, and it is three parts.
	local drum = part("Drum", Vector3.new(3.5, 15, 15),
		at * CFrame.new(0, roofY + 1.75, 0) * CFrame.Angles(0, 0, math.rad(90)),
		stone, Enum.Material.SmoothPlastic)
	drum.Shape = Enum.PartType.Cylinder
	local dome = part("Dome", Vector3.new(16, 12, 16),
		at * CFrame.new(0, roofY + 3.0, 0), tier.roof, Enum.Material.SmoothPlastic)
	dome.Shape = Enum.PartType.Ball
	-- SHIMMERS rather than cycles: `sweep` walks a little way round the wheel
	-- and back, so the gold moves without ever stopping being gold. A full
	-- hue cycle here would turn the one thing that identifies this tier into
	-- the rainbow the Neon Tower already owns.
	local collar = glowPart("DomeBand", Vector3.new(1.3, 15.6, 15.6),
		at * CFrame.new(0, roofY + 3.3, 0) * CFrame.Angles(0, 0, math.rad(90)), fxColour(tier),
		{ fx = "sweep", rate = 0.2, amount = 0.045 })
	collar.Shape = Enum.PartType.Cylinder
	local cupola = part("Cupola", Vector3.new(3.4, 5.2, 5.2),
		at * CFrame.new(0, roofY + 10.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
		stone, Enum.Material.SmoothPlastic)
	cupola.Shape = Enum.PartType.Cylinder
	local capDome = part("CupolaCap", Vector3.new(5.6, 4.0, 5.6),
		at * CFrame.new(0, roofY + 13.0, 0), tier.roof, Enum.Material.SmoothPlastic)
	capDome.Shape = Enum.PartType.Ball
	part("Finial", Vector3.new(1.1, 4.4, 1.1),
		at * CFrame.new(0, roofY + 16.4, 0), tier.trim, Enum.Material.SmoothPlastic)

	-- A gold ring turning above the finial: the palace's answer to the
	-- tower's halo, and the reason it still reads from the road when
	-- everything else on the building is a static white mass.
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		glowPart("Halo", Vector3.new(1.8, 1.8, 1.8),
			at * CFrame.new(0, roofY + 20.0, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 6),
			fxColour(tier), { fx = "orbit", rate = 0.22, amount = 6 }).Shape = Enum.PartType.Ball
	end

	-- THE COLONNADE, on its own stylobate, each column standing on its own
	-- uplight. The lights chase ACROSS the frontage, which is the one
	-- direction that reads from the street: a palace is seen side-on from the
	-- road, so a wave travelling left to right crosses the viewer's eye
	-- instead of moving away from it.
	local colZ = front + 6.0
	local colH = h * 0.72
	part("Stylobate", Vector3.new(w + 1.0, plinth + 0.6, 11.0),
		at * CFrame.new(0, (plinth + 0.2) / 2, front + 5.0), STONE, Enum.Material.SmoothPlastic)
	for i = 0, 5 do
		local x = -w / 2 + 5 + i * ((w - 10) / 5)
		column(colH, 3.0, at * CFrame.new(x, plinth + 0.4, colZ), stone, shade)
		-- SEATED ON THE TOP STEP, not on the ground. The stylobate stacks to
		-- `plinth + 0.4` and the columns only emerge above it, so a light at
		-- a column's own base is a light buried inside solid marble -- which
		-- is exactly where these were, and why the whole frontage once came
		-- out as one white haze with nothing in it anybody could name.
		local uplight = glowPart("Uplight", Vector3.new(0.7, 4.2, 4.2),
			at * CFrame.new(x, plinth + 0.75, colZ) * CFrame.Angles(0, 0, math.rad(90)),
			fxColour(tier), { fx = "chase", phase = i / 6, rate = 0.3, span = 0.32, dim = 0.2 })
		uplight.Shape = Enum.PartType.Cylinder
	end
	part("Entablature", Vector3.new(w + 1.4, 2.6, 12.0),
		at * CFrame.new(0, plinth + 0.4 + colH + 1.3, front + 5.4), stone, Enum.Material.SmoothPlastic)
	pediment(w * 0.52, 1.6, plinth + 0.4 + colH + 2.6, 5.0, stone, at * CFrame.new(0, 0, colZ + 1.1))

	-- The steps, and a lit nosing on each. The chase runs UP them toward the
	-- door -- phases handed out from the bottom step rather than from `i`,
	-- which counts down: step 0 is the TOP one here, and a chase authored off
	-- the loop index would have run down the stairs and out into the garden.
	local stepsFront = front + 15.0
	steps(3, w - 8, 2.0, 1.05, -0.1, stepsFront, STONE, at)
	for i = 0, 2 do
		-- Nosing `i` rides step `2 - i`, so both the width and the Z have to
		-- count backwards with it. Authored off `i` directly, the lights walk
		-- down the stairs and out into the garden -- which is the same trap
		-- the phases already carry a note about.
		glowPart("Nosing", Vector3.new(w - 8 + i * 1.4 - 1.2, 0.42, 0.5),
			at * CFrame.new(0, -0.1 + (3 - i) * 1.05 - 0.28, stepsFront - (2 - i) * 2.0 + 0.18),
			fxColour(tier), { fx = "chase", phase = (2 - i) / 3, rate = 0.42, span = 0.36, dim = 0.18 })
	end

	part("DoorFrame", Vector3.new(9.0, 13.5, 0.72),
		at * CFrame.new(0, plinth + 6.65, front + 0.16), shade, Enum.Material.SmoothPlastic)
	part("Door", Vector3.new(7.4, 12.0, 0.45),
		at * CFrame.new(0, plinth + 6.1, front + 0.26), tier.roof, Enum.Material.SmoothPlastic)
	part("Fanlight", Vector3.new(7.0, 1.2, 0.32),
		at * CFrame.new(0, plinth + 12.6, front + 0.24), WARM_GLASS, Enum.Material.Neon)

	windowBand(at, w - 12, plinth + STOREY * 0.56, front + 0.12, 5, 3.6, 4.4, shade, true)
	windowBand(at, w - 10, plinth + STOREY + STOREY * 0.56, front + 0.12, 5, 4.0, 4.6,
		shade, false, nil, true)
	windowBand(at, w - 10, plinth + 2 * STOREY + STOREY * 0.56, front + 0.12, 5, 4.0, 4.0,
		shade, false, nil, true)

	-- Lanterns flanking the entrance, which is where a palace is looked at
	-- once somebody has actually walked up to it.
	for _, side in ipairs({ -1, 1 }) do
		part("LampPost", Vector3.new(0.7, 8.0, 0.7),
			at * CFrame.new(side * (w / 2 - 1.5), 4.0, stepsFront + 2.0), tier.trim, Enum.Material.SmoothPlastic)
		lantern(tier, Vector3.new(2.0, 2.0, 2.0),
			at * CFrame.new(side * (w / 2 - 1.5), 8.6, stepsFront + 2.0), true)
	end
end

-- The Sky Castle, rebuilt. The four breathing finials, the sigil, the five
-- chasing runes and the six floating shards are all exactly as they were --
-- twenty-two animated parts. Everything added is masonry.
--
-- THE KEEP WAS THE PROBLEM AND IT WAS A BLANK FORTY-STUD WALL. This is the
-- only tier whose walls are plain grey with no trim colour anywhere on them,
-- so it had nothing at all to break the face up -- which is why the runes
-- were put there in the first place. A batter at the base, a scatter of
-- proud blocks, a corbel table and a real wall walk give it the relief the
-- other eight tiers get from timber, quoins or courses.
rebuilt.castle = function(tier, at)
	local w, d = tier.width, tier.depth
	local h = tier.storeys * STOREY
	local plinth = 3.2
	local front = d / 2
	local stone = tier.walls
	local dark = tier.walls:Lerp(Color3.new(0, 0, 0), 0.16)
	local light = tier.walls:Lerp(Color3.new(1, 1, 1), 0.12)

	-- A BATTERED BASE: two courses, the lower one wider. A castle wall that
	-- meets the ground at ninety degrees is a wall; one that thickens toward
	-- the bottom is a fortification, and it is two parts.
	part("Plinth", Vector3.new(w + 4.4, 2.0, d + 4.4),
		at * CFrame.new(0, 1.0, 0), STONE, Enum.Material.SmoothPlastic)
	part("Batter", Vector3.new(w + 2.4, 1.4, d + 2.4),
		at * CFrame.new(0, 2.7, 0), dark, Enum.Material.SmoothPlastic)
	part("Keep", Vector3.new(w, h, d),
		at * CFrame.new(0, plinth + h / 2, 0), stone, Enum.Material.SmoothPlastic)

	-- A SCATTER OF PROUD BLOCKS, in two shades. Quoins would be forty parts
	-- at forty-five studs of wall, and a castle wants irregular masonry
	-- rather than dressed corners anyway. Laid out by hand rather than
	-- randomly: a scatter that moves between builds is a house that looks
	-- different every time somebody rejoins.
	local blocks = {
		{ -15.0, 7.0, 5.4, 3.0 }, { -8.2, 12.5, 4.2, 2.6 }, { -16.5, 19.0, 4.6, 3.2 },
		{ -6.0, 25.0, 5.8, 2.8 }, { -14.0, 31.5, 4.0, 3.0 }, { -8.6, 38.0, 5.0, 2.6 },
		{ 15.2, 8.5, 5.0, 3.2 }, { 8.0, 14.0, 4.4, 2.6 }, { 16.0, 21.5, 5.6, 2.8 },
		{ 7.4, 28.0, 4.2, 3.0 }, { 15.0, 34.4, 4.8, 2.6 }, { 8.8, 40.5, 5.2, 3.0 },
	}
	for i, b in ipairs(blocks) do
		part("Stone", Vector3.new(b[3], b[4], 0.34),
			at * CFrame.new(b[1], plinth + b[2], front + 0.10 + (i % 3) * 0.05),
			if i % 2 == 0 then dark else light, Enum.Material.SmoothPlastic)
	end

	-- ARROW SLITS. Warm and thin, and the only lit thing on the keep below
	-- the runes -- a castle with no light in it reads as a ruin.
	for _, sx in ipairs({ -1, 1 }) do
		for i = 0, 2 do
			part("SlitFrame", Vector3.new(1.5, 4.6, 0.4),
				at * CFrame.new(sx * 11.5, plinth + 11 + i * 11, front + 0.14),
				dark, Enum.Material.SmoothPlastic)
			part("Slit", Vector3.new(0.6, 3.4, 0.3),
				at * CFrame.new(sx * 11.5, plinth + 11 + i * 11, front + 0.30),
				WARM_GLASS, Enum.Material.Neon)
		end
	end

	-- CORBEL TABLE, WALL WALK AND CRENELLATIONS. The original had merlons
	-- sitting straight on top of the wall, which reads as teeth stuck on a
	-- box; a real parapet is a projecting course, a walk behind it, and the
	-- merlons on top of that.
	local keepTop = plinth + h
	part("Corbel", Vector3.new(w + 2.6, 1.1, d + 2.6),
		at * CFrame.new(0, keepTop + 0.55, 0), dark, Enum.Material.SmoothPlastic)
	part("Walk", Vector3.new(w + 1.8, 1.4, d + 1.8),
		at * CFrame.new(0, keepTop + 1.8, 0), stone, Enum.Material.SmoothPlastic)
	local merlons = math.floor(w / 5)
	for i = 0, merlons - 1 do
		local x = -w / 2 + (w / merlons) / 2 + i * (w / merlons)
		for _, sz in ipairs({ -1, 1 }) do
			part("Merlon", Vector3.new(w / merlons * 0.62, 2.6, 2.0),
				at * CFrame.new(x, keepTop + 3.8, sz * (d / 2 - 0.3)), stone, Enum.Material.SmoothPlastic)
		end
	end

	-- FOUR TURRETS, taller than the keep, each on a corbelled ring under a
	-- stepped cone. A wedge cannot make a cone and a ball reads as a
	-- mushroom, so the cone is four discs sunk into each other -- which is
	-- also exactly what the reference art draws.
	local th = keepTop + 7
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local turret = part("Turret", Vector3.new(th, 8.5, 8.5),
				at * CFrame.new(sx * w / 2, th / 2, sz * d / 2) * CFrame.Angles(0, 0, math.rad(90)),
				stone, Enum.Material.SmoothPlastic)
			turret.Shape = Enum.PartType.Cylinder
			local ring = part("TurretCorbel", Vector3.new(2.0, 10.2, 10.2),
				at * CFrame.new(sx * w / 2, th - 2.0, sz * d / 2) * CFrame.Angles(0, 0, math.rad(90)),
				dark, Enum.Material.SmoothPlastic)
			ring.Shape = Enum.PartType.Cylinder
			for step = 0, 3 do
				local cap = part("Cap", Vector3.new(1.9, 9.6 - step * 2.2, 9.6 - step * 2.2),
					at * CFrame.new(sx * w / 2, th + 1.4 + step * 1.5, sz * d / 2)
						* CFrame.Angles(0, 0, math.rad(90)), tier.roof, Enum.Material.SmoothPlastic)
				cap.Shape = Enum.PartType.Cylinder
			end
			-- The four finials breathe, and OUT OF STEP -- a quarter turn of
			-- phase each, so the castle has something moving at every moment
			-- rather than all four blinking together like a fault. Four
			-- corners pulsing in lockstep is the one arrangement that reads
			-- as a single full-screen flash.
			local finial = glowPart("Finial", Vector3.new(1.8, 1.8, 1.8),
				at * CFrame.new(sx * w / 2, th + 7.6, sz * d / 2), fxColour(tier),
				{ fx = "pulse", phase = (sx + 1) * 0.125 + (sz + 1) * 0.25, rate = 0.3, dim = 0.2 })
			finial.Shape = Enum.PartType.Ball
			-- Held by reference, never looked back up by name: every part in
			-- a house lives in one flat folder, so `FindFirstChild("Finial")`
			-- returns the same first turret on all four passes -- and the
			-- palace builds a part with that name as well.
			if sz > 0 then
				local pointLight = Instance.new("PointLight")
				pointLight.Color = tier.glow
				pointLight.Brightness = tier.lanternBrightness or 0.9
				pointLight.Range = tier.lanternRange or 18
				pointLight.Shadows = false
				pointLight.Parent = finial
			end
		end
	end

	-- THE GATEHOUSE, with an arched head and a real portcullis behind it.
	-- A gate is the one thing on this building anybody walks up to, and it
	-- was a plain rectangle with a wooden door in it.
	local gh = h * 0.62
	local gz = front + 3.0
	part("Gatehouse", Vector3.new(16, gh, 7.0),
		at * CFrame.new(0, plinth + gh / 2 - 0.15, gz), stone, Enum.Material.SmoothPlastic)
	part("GateCorbel", Vector3.new(17.4, 0.9, 8.4),
		at * CFrame.new(0, plinth + gh + 0.45, gz), dark, Enum.Material.SmoothPlastic)
	for i = 0, 2 do
		part("Merlon", Vector3.new(3.2, 2.2, 5.4),
			at * CFrame.new(-5.4 + i * 5.4, plinth + gh + 2.0, gz), stone, Enum.Material.SmoothPlastic)
	end
	local gFront = gz + 3.5
	part("Arch", Vector3.new(11.0, 15.0, 0.6),
		at * CFrame.new(0, plinth + 7.4, gFront + 0.05), dark, Enum.Material.SmoothPlastic)
	-- The arched head, as three stepped voussoir blocks. There is no curve
	-- available here, and three steps is what reads as an arch at this size.
	for i = 0, 2 do
		-- Narrower than the opening and a clear stone apart, so no two
		-- voussoirs share a face plane with each other or with the arch.
		part("Voussoir", Vector3.new(10.4 - i * 2.6, 0.9, 0.75),
			at * CFrame.new(0, plinth + 14.6 + i * 1.0, gFront + 0.18), light, Enum.Material.SmoothPlastic)
	end
	for i = 0, 4 do
		part("Bar", Vector3.new(0.5, 12.8, 0.42),
			at * CFrame.new(-4.0 + i * 2.0, plinth + 6.5, gFront + 0.28),
			Color3.fromRGB(64, 62, 60), Enum.Material.SmoothPlastic)
	end
	for i = 0, 3 do
		part("Bar", Vector3.new(9.6, 0.5, 0.34),
			at * CFrame.new(0, plinth + 1.6 + i * 3.2, gFront + 0.40),
			Color3.fromRGB(64, 62, 60), Enum.Material.SmoothPlastic)
	end
	steps(3, 14.0, 1.6, (plinth + 0.1) / 3, -0.1, gFront + 6.0, STONE, at)

	-- The banner, hung on the GATEHOUSE above the gate rather than up the
	-- keep behind it -- from the road that read as a stripe floating halfway
	-- up a wall with nothing holding it. STILL FABRIC, and the light on it is
	-- a separate part standing proud: Fabric is a dark noisy texture rather
	-- than a colour, so animating the banner's own colour would move a muddy
	-- brown through a muddy purple.
	part("BannerPole", Vector3.new(9.0, 0.5, 0.5),
		at * CFrame.new(0, plinth + gh - 1.6, gFront + 0.5), dark, Enum.Material.SmoothPlastic)
	part("Banner", Vector3.new(6.0, gh * 0.42, 0.4),
		at * CFrame.new(0, plinth + gh - 1.9 - gh * 0.21, gFront + 0.62), tier.trim, Enum.Material.Fabric)
	glowPart("Sigil", Vector3.new(2.8, 2.8, 0.3),
		at * CFrame.new(0, plinth + gh - 1.9 - gh * 0.21, gFront + 0.86), fxColour(tier),
		{ fx = "pulse", rate = 0.26, dim = 0.35 })

	-- RUNES ACROSS THE KEEP, above the gatehouse and clear of it, chasing
	-- from one side to the other.
	for i = 0, 4 do
		glowPart("Rune", Vector3.new(2.4, 2.4, 0.35),
			at * CFrame.new(-12 + i * 6, plinth + gh + 6.0, front + 0.48), fxColour(tier),
			-- `dim` 0.35 rather than the original 0.15. A chase spends most of
			-- its cycle at the dim end, and at 0.15 the magenta bottoms out near
			-- black -- which on pale grey stone reads as five rectangular HOLES
			-- punched in the keep rather than as runes waiting their turn.
			-- Photographed rather than reasoned about.
			{ fx = "chase", phase = i / 5, rate = 0.38, span = 0.3, dim = 0.35 })
	end

	-- A SKY CASTLE SHOULD HAVE SOMETHING IN THE SKY. Six rocks circling the
	-- keep above the turrets, each on its own radius, height and rate so the
	-- ring never resolves into a wheel. This is the tallest thing in the game
	-- and the only moving scenery above the treeline, which is what an
	-- eighty-million-coin house is buying: everyone on the street can see it
	-- without leaving their own plot.
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local radius = 26 + (i % 3) * 5
		local rock = part("Shard", Vector3.new(4.5 - (i % 3) * 0.8, 3.2, 4.5 - (i % 2) * 1.1),
			at * CFrame.new(0, keepTop + 12 + (i % 3) * 5, 0)
				* CFrame.Angles(0, a, 0) * CFrame.new(0, 0, radius)
				* CFrame.Angles(math.rad(14 * (i % 2 == 0 and 1 or -1)), 0, math.rad(9)),
			stone, Enum.Material.SmoothPlastic)
		rock:SetAttribute("FX", "orbit")
		rock:SetAttribute("Rate", 0.05 + i * 0.012)
		rock:SetAttribute("Amount", radius)
		CollectionService:AddTag(rock, HouseFX.TAG)

		-- A lit underside on each, so they read against a bright sky. Rock
		-- against blue at a hundred studs is a grey dot; rock with a magenta
		-- edge is a floating island.
		glowPart("ShardGlow", Vector3.new(3.4 - (i % 3) * 0.6, 0.35, 3.4 - (i % 2) * 0.9),
			at * CFrame.new(0, keepTop + 12 + (i % 3) * 5 - 1.9, 0)
				* CFrame.Angles(0, a, 0) * CFrame.new(0, 0, radius),
			fxColour(tier), { fx = "orbit", rate = 0.05 + i * 0.012, amount = radius })
	end

	for storey = 3, tier.storeys do
		-- Unlit. The castle's warmth is its ARROW SLITS, which are small and
		-- deliberate; a keep with every window blazing reads as an office.
		windowBand(at, w - 12, plinth + (storey - 1) * STOREY + STOREY * 0.5, front + 0.12,
			3, 2.6, 3.6, dark, false, nil, true)
	end
end
-- ============================================================
-- THE MESHED HOUSE
-- ============================================================
--
-- One generated mesh standing in for a tier's primitive builder, cloned per
-- house. Everything about why lives over `Config.HOUSE_MESH`; this is the
-- machinery.
--
-- CACHED PER STYLE BECAUSE `CreateMeshPartAsync` YIELDS, and eight plots plus
-- a shop tile per tier would otherwise be a web call each. Same shape as the
-- trees, the grass tufts and the fence panels.
--
-- THE CACHE IS IN THIS MODULE RATHER THAN ON THE SERVER, which is worth a
-- line because CSG is not: `UnionAsync` is server-only, so `PlayerGear` has to
-- build its shells on the server and clone them through ReplicatedStorage.
-- `CreateMeshPartAsync` is NOT gated that way -- measured from a real client
-- context, it returns a MeshPart at the authored size -- so the shop tile can
-- load its own house and there is no template folder to keep in step.
local meshes: { [string]: BasePart } = {}
local meshChecked: { [string]: boolean } = {}

local function houseMesh(style: string): BasePart?
	if meshChecked[style] then
		return meshes[style]
	end
	meshChecked[style] = true

	local spec = Config.houseMesh(style)
	if not spec then
		return nil
	end

	local ok, result = pcall(function()
		local p = game:GetService("InsertService"):CreateMeshPartAsync(spec.id,
			Enum.CollisionFidelity.Box, Enum.RenderFidelity.Automatic)
		-- `CreateMeshPartAsync` CARRIES THE MESH AND NOT THE MAP. The trees
		-- shipped flat for a whole build on exactly this, with nothing in the
		-- log: a generated mesh and its painted texture are two separate
		-- uploads and anything cloning one has to ask for both.
		if spec.texture then
			p.TextureID = spec.texture
		end
		return p
	end)

	if not ok then
		warn(("[House] the %s mesh could not be loaded, so the primitive house "
			.. "is standing instead: %s"):format(style, tostring(result)))
		return nil
	end

	meshes[style] = result
	return result
end

-- Builds the meshed house into `folder`. Returns false when this style has no
-- mesh, so the caller falls through to the builder that has always drawn it.
local function buildMeshHouse(tier, at: CFrame): boolean
	local spec = Config.houseMesh(tier.style)
	local template = spec and houseMesh(tier.style)
	if not (spec and template) then
		return false
	end

	-- THE LIGHT SHOW STAYS PRIMITIVE, because an emissive band is a MATERIAL
	-- rather than a shape and a mesh cannot supply one. The tier's own builder
	-- runs, and every solid part it made is then dropped -- what survives is
	-- exactly what it tagged for `HouseFX`.
	if spec.keepFX then
		local build = builders[tier.style]
		if build then
			build(tier, at)
			for _, d in ipairs(folder:GetChildren()) do
				if d:IsA("BasePart") and not CollectionService:HasTag(d, HouseFX.TAG) then
					d:Destroy()
				end
			end
		end
	end

	local p = template:Clone()
	p.Name = "House"

	-- UNIFORM off ONE stated target, so the house keeps the proportions it was
	-- generated with. Height is preferred because that is the axis the world
	-- is tuned on -- `STOREY` is 9 studs against a five-stud character -- and
	-- because the generator fits a mesh inside the size box at its OWN aspect
	-- rather than filling it, so pinning width can hand back a fifty-stud
	-- tower. See the note over `Config.HOUSE_MESH`.
	local authored = template.Size
	local scale = 1
	if spec.height and authored.Y > 0 then
		scale = spec.height / authored.Y
	elseif spec.width and authored.X > 0 then
		scale = spec.width / authored.X
	end
	-- SIZE BEFORE CFRAME: resizing a MeshPart scales it about its own centre,
	-- so a part seated first and scaled after walks off its spot.
	p.Size = authored * scale

	-- Seated with its BOTTOM on the ground, because `at` is the ground plane
	-- and every primitive builder in this file authors upward from it. A mesh
	-- part's origin is its own centre, so half the scaled height is the lift.
	p.CFrame = at
		* CFrame.new(0, p.Size.Y / 2, 0)
		* CFrame.Angles(0, math.rad(spec.yaw or 0), 0)
	p.Anchored = true
	-- Pure scenery, exactly as the primitive house is: a status symbol must
	-- never become an obstacle in a chase or eat a raycast meant for a piggy.
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	if spec.tint then
		p.Color = spec.tint
	end
	p.Parent = folder
	return true
end

-- A HOUSE WHOSE MODEL HAS NOT BEEN DRAWN YET, and it has to LOOK it.
--
-- Revision 2 of the catalogue landed before its art (Config.HOUSE_TIERS rows
-- carrying `placeholder`), so buying, moving in, the card and the sign could
-- all be proven end to end. What stands meanwhile is a block of the row's own
-- width x height x depth -- height is the brief's silhouette ladder, so the
-- street already reads which houses tower -- in its wall and roof colours,
-- wrapped in a yellow-and-black construction band so nobody mistakes it for
-- the finished house. Everything is parts, so the shop card renders it.
--
-- Coplanar-safe by construction: the plinth, block and cap nest with 0.1 of
-- overlap on every seam; the side bands stop short of the corners so they
-- never share a face plane with the front and back bands; and the band is
-- broken either side of the door rather than butting its edges.
local HAZARD = Color3.fromRGB(240, 196, 40)
local HAZARD_INK = Color3.fromRGB(34, 30, 30)
local PLACEHOLDER_DOOR = 2 -- half-width of the doorway
local function buildPlaceholder(tier, at: CFrame)
	local w, d = tier.width or 20, tier.depth or 20
	local h = tier.height or ((tier.storeys or 1) * STOREY)
	local smooth = Enum.Material.SmoothPlastic

	part("Plinth", Vector3.new(w + 1.2, 0.8, d + 1.2), at * CFrame.new(0, 0.3, 0), STONE, smooth)
	part("Block", Vector3.new(w, h - 1.4, d), at * CFrame.new(0, 0.6 + (h - 1.4) / 2, 0), tier.walls, smooth)
	part("Cap", Vector3.new(w + 1, 1, d + 1), at * CFrame.new(0, h - 0.4, 0), tier.roof, smooth)
	part("Door", Vector3.new(PLACEHOLDER_DOOR * 2, 7, 0.3),
		at * CFrame.new(0, 0.6 + 3.5, d / 2 + 0.15), tier.trim or DOOR, smooth)

	-- One band, laid as alternating tiles along each face at knee height.
	local bandY, bandH = 2.2, 1.6
	local function band(span: number, place: (number, number) -> CFrame, along: string, skipDoor: boolean)
		local count = math.max(2, math.floor(span / 2.4))
		local tile = span / count
		for i = 0, count - 1 do
			local from = -span / 2 + i * tile
			local to = from + tile
			if not (skipDoor and to > -PLACEHOLDER_DOOR - 0.6 and from < PLACEHOLDER_DOOR + 0.6) then
				local size = if along == "x"
					then Vector3.new(tile, bandH, 0.3)
					else Vector3.new(0.3, bandH, tile)
				part("Construction", size, place((from + to) / 2, bandY),
					if i % 2 == 0 then HAZARD else HAZARD_INK, smooth)
			end
		end
	end
	-- 0.2 wider than the block each side, so an end tile's face never lands
	-- in the block's own side plane.
	band(w + 0.4, function(x, y) return at * CFrame.new(x, y, d / 2 + 0.05) end, "x", true)
	band(w + 0.4, function(x, y) return at * CFrame.new(x, y, -d / 2 - 0.05) end, "x", false)
	for _, sx in ipairs({ -1, 1 }) do
		band(d - 0.4, function(z, y) return at * CFrame.new(sx * (w / 2 + 0.05), y, z) end, "z", false)
	end
end

function House.build(level: number, at: CFrame, parent: Instance): Model
	local tier = Config.getHouseTier(level)

	local model = Instance.new("Model")
	model.Name = "House"
	folder = model

	-- The mesh first, per style, falling through to the primitive builder
	-- whenever `Config.HOUSE_MESH` has no row for it. That is what lets the
	-- nine tiers be meshed one at a time -- and what keeps every house this
	-- game already ships standing while the catalogue is only half done.
	if not buildMeshHouse(tier, at) then
		-- The rebuilt low-poly builder when this style opts in, else the
		-- original. Both sets are kept: `Config.HOUSE_REBUILD` names the
		-- styles that have been redrawn, and every other tier stands exactly
		-- as it always has.
		-- A row still flagged `placeholder` stands the block even if a
		-- builder has since appeared, because residents read the same flag
		-- (Config.residentHouseLevel) and the two must agree. Unflagged with
		-- no builder at all also gets the block: a missing model should look
		-- unfinished, never silently borrow the shack.
		local build = (tier.placeholder and buildPlaceholder)
			or (Config.HOUSE_REBUILD[tier.style] and rebuilt[tier.style])
			or builders[tier.style] or buildPlaceholder
		build(tier, at)
	end
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
