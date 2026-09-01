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
-- THE SILLY SHELF
-- ============================================================
--
-- The ornaments above are things a real garden has. These are not.
--
-- Every one is an ORIGINAL shape rather than a copy of a named meme. That is
-- a shipping requirement rather than caution: the specific ones a nine year
-- old would ask for by name are somebody's trademark or copyright, and a
-- takedown costs the whole experience rather than the one ornament. The genre
-- survives the rename intact -- nothing about an enormous rubber duck is
-- funnier for being licensed.

local SKIN = Color3.fromRGB(238, 196, 160)
local WHITE = Color3.fromRGB(244, 246, 248)
local BLACK = Color3.fromRGB(26, 26, 30)
local GOLD = Color3.fromRGB(232, 190, 74)
local SMOOTH = Enum.Material.SmoothPlastic

local function wedge(name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Size = size
	w.CFrame = cf
	w.Anchored = true
	w.CanCollide = false
	w.CanQuery = false
	w.CastShadow = false
	w.Color = colour
	w.Material = material
	w.Parent = folder
	return w
end

-- A cone, which Roblox has no primitive for: four shrinking discs and a ball
-- on the tip. Nobody sees a lawn ornament from closer than the pavement, and
-- at that range this is a cone.
local function cone(name: string, height: number, baseD: number, cf: CFrame,
	colour: Color3, material: Enum.Material)
	local steps = 4
	local h = height / steps
	for i = 0, steps - 1 do
		cylinderY(name, h * 1.06, baseD * (1 - (i / steps) * 0.82),
			cf * CFrame.new(0, h * (i + 0.5), 0), colour, material)
	end
	ball(name .. "Tip", baseD * 0.18, cf * CFrame.new(0, height, 0), colour, material)
end

-- Two bulging eyes on the +Z face. Every one of these ornaments has a face,
-- and a face is what makes an object read as a character rather than as a
-- prop -- which is the entire joke in six of the seven.
local function eyes(at: CFrame, spread: number, y: number, z: number, size: number)
	for _, sx in ipairs({ -1, 1 }) do
		ball("Eye", size, at * CFrame.new(sx * spread, y, z), WHITE, SMOOTH)
		ball("Pupil", size * 0.42, at * CFrame.new(sx * spread, y, z + size * 0.36), BLACK, SMOOTH)
	end
end

-- ------------------------------------------------------------
-- The statue's prints
-- ------------------------------------------------------------
--
-- The shirt graphic and the bag's monogram are DRAWN, on a SurfaceGui over an
-- invisible panel, rather than built out of parts. A print is flat, and no
-- arrangement of studs holds a legible word at three studs across.
--
-- Both marks are the game's own. A real fashion house's wordmark, its
-- interlocking emblem and its monogram canvas are each separately registered,
-- Roblox moderation strips branded assets, and the penalty falls on the
-- experience rather than on the one ornament -- which is not a trade worth
-- making for a lawn decoration. What actually carries the joke is the LAYOUT:
-- a serif wordmark stacked over a roundel, and a repeating monogram on a tan
-- holdall. Both of those are genres, not property, and a snout in place of
-- the emblem is funnier here anyway.

local function panel(name: string, width: number, height: number, cf: CFrame,
	canvasW: number, canvasH: number): SurfaceGui
	local p = part(name, Vector3.new(width, height, 0.08), cf, BLACK, SMOOTH)
	p.Transparency = 1
	local gui = Instance.new("SurfaceGui")
	-- Front is -Z on a Roblox part, and every one of these faces the street
	-- on +Z.
	gui.Face = Enum.NormalId.Back
	gui.CanvasSize = Vector2.new(canvasW, canvasH)
	gui.LightInfluence = 0
	gui.Parent = p
	return gui
end

local function rounded(parent: Instance, size: UDim2, pos: UDim2, colour: Color3, radius: number): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = colour
	f.BorderSizePixel = 0
	f.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(radius, 0)
	c.Parent = f
	return f
end

local function teeGraphic(cf: CFrame)
	local gui = panel("TeePrint", 3.1, 2.7, cf, 310, 270)

	local word = Instance.new("TextLabel")
	word.Size = UDim2.fromScale(1, 0.3)
	word.Position = UDim2.fromScale(0, 0.05)
	word.BackgroundTransparency = 1
	word.Font = Enum.Font.Garamond
	word.TextScaled = true
	word.TextColor3 = WHITE
	word.Text = "PIGGY"
	word.Parent = gui

	-- The roundel: a white ring with a snout inside it.
	local ring = rounded(gui, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.25, 0.42), WHITE, 0.5)
	ring.BackgroundTransparency = 1
	local stroke = Instance.new("UIStroke")
	stroke.Color = WHITE
	stroke.Thickness = 6
	stroke.Parent = ring

	local snout = rounded(ring, UDim2.fromScale(0.58, 0.44), UDim2.fromScale(0.21, 0.28), WHITE, 0.4)
	for _, x in ipairs({ 0.2, 0.58 }) do
		rounded(snout, UDim2.fromScale(0.22, 0.44), UDim2.fromScale(x, 0.28), BLACK, 0.5)
	end
end

-- The bag's monogram: a checked tan canvas with a snout stamped in every
-- light square. Reads as a designer holdall from the pavement, which is the
-- only distance it is ever seen from.
local function monogram(cf: CFrame)
	local gui = panel("BagPrint", 2.5, 1.7, cf, 250, 170)
	local COLS, ROWS = 7, 4
	local LIGHT = Color3.fromRGB(182, 146, 100)
	local DARK = Color3.fromRGB(148, 114, 74)

	for row = 0, ROWS - 1 do
		for col = 0, COLS - 1 do
			local light = (row + col) % 2 == 0
			local tile = Instance.new("Frame")
			tile.Size = UDim2.fromScale(1 / COLS, 1 / ROWS)
			tile.Position = UDim2.fromScale(col / COLS, row / ROWS)
			tile.BackgroundColor3 = if light then LIGHT else DARK
			tile.BorderSizePixel = 0
			tile.Parent = gui
			if light then
				local mark = rounded(tile, UDim2.fromScale(0.52, 0.38),
					UDim2.fromScale(0.24, 0.31), Color3.fromRGB(94, 68, 42), 0.4)
				for _, x in ipairs({ 0.2, 0.58 }) do
					rounded(mark, UDim2.fromScale(0.22, 0.42), UDim2.fromScale(x, 0.29),
						Color3.fromRGB(60, 42, 26), 0.5)
				end
			end
		end
	end
end

builders.bigduck = function(item, at)
	local YELLOW = Color3.fromRGB(248, 208, 48)
	local BEAK = Color3.fromRGB(240, 140, 36)

	ball("Body", 8.2, at * CFrame.new(0, 4.1, 0), YELLOW, SMOOTH)
	wedge("Tail", Vector3.new(3.0, 3.2, 3.4), at * CFrame.new(0, 4.8, -4.0)
		* CFrame.Angles(0, math.rad(90), 0), YELLOW, SMOOTH)

	ball("Head", 4.6, at * CFrame.new(0, 8.7, 1.5), YELLOW, SMOOTH)
	part("Beak", Vector3.new(2.1, 1.0, 2.6), at * CFrame.new(0, 8.3, 4.2), BEAK, SMOOTH)
	part("BeakTop", Vector3.new(2.3, 0.9, 2.2), at * CFrame.new(0, 9.1, 4.0), BEAK, SMOOTH)

	for _, sx in ipairs({ -1, 1 }) do
		ball("Pupil", 0.85, at * CFrame.new(sx * 1.25, 9.7, 2.9), BLACK, SMOOTH)
	end
end

builders.buffgnome = function(item, at)
	local RED = Color3.fromRGB(212, 74, 68)
	local BLUE = Color3.fromRGB(72, 96, 168)
	local BOOT = Color3.fromRGB(92, 64, 44)

	for _, sx in ipairs({ -1, 1 }) do
		part("Boot", Vector3.new(1.5, 1.2, 2.2), at * CFrame.new(sx * 1.2, 0.6, 0.4), BOOT, SMOOTH)
		part("Leg", Vector3.new(1.3, 2.0, 1.3), at * CFrame.new(sx * 1.2, 2.2, 0), BLUE, SMOOTH)
	end
	part("Torso", Vector3.new(3.0, 3.0, 2.0), at * CFrame.new(0, 4.6, 0), RED, Enum.Material.Fabric)
	part("Belt", Vector3.new(3.2, 0.7, 2.2), at * CFrame.new(0, 3.3, 0), BOOT, SMOOTH)

	-- The arms are the joke, so they are built at roughly twice the scale the
	-- rest of the gnome would justify.
	for _, sx in ipairs({ -1, 1 }) do
		ball("Delt", 3.2, at * CFrame.new(sx * 2.4, 5.6, 0), SKIN, SMOOTH)
		local arm = part("Bicep", Vector3.new(3.6, 2.5, 2.5),
			at * CFrame.new(sx * 4.0, 4.3, 0) * CFrame.Angles(0, 0, math.rad(sx * 48)),
			SKIN, SMOOTH)
		arm.Shape = Enum.PartType.Cylinder
		ball("Fist", 2.5, at * CFrame.new(sx * 5.0, 2.7, 0.2), SKIN, SMOOTH)
	end

	ball("Head", 2.7, at * CFrame.new(0, 6.9, 0), SKIN, SMOOTH)
	part("Shades", Vector3.new(2.6, 0.7, 0.4), at * CFrame.new(0, 7.2, 1.2), BLACK, SMOOTH)
	for _, sx in ipairs({ -1, 1 }) do
		ball("Beard", 1.5, at * CFrame.new(sx * 0.7, 6.1, 0.8), Color3.fromRGB(240, 240, 236), SMOOTH)
	end
	ball("BeardTip", 1.3, at * CFrame.new(0, 5.4, 0.7), Color3.fromRGB(240, 240, 236), SMOOTH)
	cone("Hat", 4.4, 3.2, at * CFrame.new(0, 7.7, 0), RED, Enum.Material.Fabric)
end

-- The inflatable one outside a car dealership, frozen mid-flail.
--
-- Static on purpose. Animating it means a per-frame CFrame write per plot on
-- the server -- the same arithmetic the animated skins were moved to the
-- client to avoid -- to say something nobody standing on the pavement would
-- look at for more than three seconds. A bent pose reads as motion on its own.
builders.tubeman = function(item, at)
	local ORANGE = Color3.fromRGB(248, 118, 42)
	local PALE = Color3.fromRGB(250, 244, 228)

	cylinderY("Base", 0.7, 4.4, at * CFrame.new(0, 0.35, 0), Color3.fromRGB(48, 50, 56), SMOOTH)
	cylinderY("Fan", 1.6, 2.6, at * CFrame.new(0, 1.4, 0), Color3.fromRGB(64, 68, 76), Enum.Material.Metal)

	-- SmoothPlastic, not Fabric. Fabric's weave is a dark, noisy texture that
	-- turned a bright orange tube into a muddy brown one at any distance --
	-- and the whole point of this thing outside a car dealership is that it is
	-- the loudest object in the yard.
	local cf = at * CFrame.new(0, 2.1, 0)
	local leans = { 7, -16, 26, -34 }
	for i, deg in ipairs(leans) do
		cf = cf * CFrame.Angles(0, 0, math.rad(deg))
		cylinderY("Tube", 4.3, 2.3, cf * CFrame.new(0, 2.1, 0),
			if i % 2 == 1 then ORANGE else PALE, SMOOTH)
		cf = cf * CFrame.new(0, 4.1, 0)
	end

	-- Arms, thrown out at different angles: the one thing that separates this
	-- from a traffic bollard.
	for _, spec in ipairs({ { -1, 62 }, { 1, -18 } }) do
		local sx, deg = spec[1], spec[2]
		local armCF = cf * CFrame.new(sx * 1.0, -1.4, 0) * CFrame.Angles(0, 0, math.rad(deg))
		cylinderY("Arm", 5.0, 1.1, armCF * CFrame.new(0, 2.4, 0), ORANGE, SMOOTH)
	end

	ball("Head", 3.0, cf * CFrame.new(0, 1.2, 0), ORANGE, SMOOTH)
	eyes(cf * CFrame.new(0, 1.2, 0), 0.8, 0.4, 1.2, 0.9)
	part("Mouth", Vector3.new(1.5, 1.1, 0.4), cf * CFrame.new(0, 0.3, 1.35), BLACK, SMOOTH)
end

builders.looguy = function(item, at)
	local PORCELAIN = Color3.fromRGB(240, 242, 246)
	local CHROME = Color3.fromRGB(186, 190, 198)

	part("Pedestal", Vector3.new(2.4, 1.8, 2.8), at * CFrame.new(0, 0.9, -0.2), PORCELAIN, SMOOTH)
	cylinderY("Bowl", 2.6, 3.8, at * CFrame.new(0, 3.0, 0.1), PORCELAIN, SMOOTH)
	cylinderY("Seat", 0.45, 4.4, at * CFrame.new(0, 4.4, 0.1), PORCELAIN, SMOOTH)
	part("Cistern", Vector3.new(3.8, 3.0, 1.5), at * CFrame.new(0, 4.6, -2.1), PORCELAIN, SMOOTH)
	part("Lid", Vector3.new(4.0, 0.4, 1.7), at * CFrame.new(0, 6.3, -2.1), PORCELAIN, SMOOTH)
	cylinderY("Flush", 0.3, 0.8, at * CFrame.new(0, 6.6, -2.1), CHROME, Enum.Material.Metal)

	-- And a person coming out of it, which is the entire ornament.
	cylinderY("Neck", 2.4, 1.0, at * CFrame.new(0, 5.6, 0.1), CHROME, Enum.Material.Metal)
	ball("Head", 3.3, at * CFrame.new(0, 8.0, 0.1), SKIN, SMOOTH)
	cylinderY("Hair", 1.0, 3.2, at * CFrame.new(0, 9.3, 0.1), Color3.fromRGB(84, 58, 42), SMOOTH)
	eyes(at, 0.85, 8.4, 1.6, 0.95)
	part("Grin", Vector3.new(2.2, 0.7, 0.35), at * CFrame.new(0, 7.1, 1.55), BLACK, SMOOTH)
	part("Teeth", Vector3.new(2.0, 0.3, 0.3), at * CFrame.new(0, 7.3, 1.6), WHITE, SMOOTH)
end

builders.sharkshoes = function(item, at)
	local SHARK = Color3.fromRGB(86, 138, 190)
	local BELLY = Color3.fromRGB(226, 232, 238)
	local SOLE = Color3.fromRGB(206, 210, 216)

	-- BROADSIDE to the street, not pointing at it.
	--
	-- Built nose-forward first, and from the pavement it was a blue disc with
	-- a horn: a body seen end-on is a circle, the three trainers stack into
	-- one white block, and the tail sticks up over the top looking like a fin.
	-- Everything that makes it read as a shark -- the long snout, the dorsal,
	-- the row of shoes -- is in the SIDE profile, so the long axis runs across
	-- the viewer. Which is free here: a cylinder's own axis is X, so this is
	-- the version with no rotation in it at all.
	local body = part("Body", Vector3.new(8.4, 3.8, 3.8), at * CFrame.new(0, 5.7, 0), SHARK, SMOOTH)
	body.Shape = Enum.PartType.Cylinder

	ball("Snout", 3.8, at * CFrame.new(3.8, 5.7, 0), SHARK, SMOOTH)
	ball("Nose", 2.8, at * CFrame.new(5.1, 6.0, 0), SHARK, SMOOTH)
	ball("Belly", 3.2, at * CFrame.new(0.4, 4.6, 0.5), BELLY, SMOOTH)

	-- A wedge's triangle is its YZ cross-section, extruded along X. This one
	-- wants the triangle side-on and the extrusion across the body, so it
	-- takes a quarter turn about Y -- negative, so the tall edge faces the
	-- nose and the slope runs back toward the tail.
	wedge("Dorsal", Vector3.new(0.55, 3.0, 3.4), at * CFrame.new(-0.2, 8.4, 0)
		* CFrame.Angles(0, math.rad(-90), 0), SHARK, SMOOTH)
	wedge("Tail", Vector3.new(0.55, 4.4, 3.6), at * CFrame.new(-5.4, 7.4, 0)
		* CFrame.Angles(0, math.rad(-90), 0), SHARK, SMOOTH)
	wedge("TailLow", Vector3.new(0.55, 2.6, 2.8), at * CFrame.new(-5.2, 4.3, 0)
		* CFrame.Angles(math.rad(180), math.rad(-90), 0), SHARK, SMOOTH)

	-- One pectoral fin toward the street, one away.
	for _, sz in ipairs({ -1, 1 }) do
		wedge("Fin", Vector3.new(0.45, 1.8, 2.8), at * CFrame.new(1.4, 4.7, sz * 1.9)
			* CFrame.Angles(0, math.rad(if sz > 0 then 0 else 180), math.rad(sz * 50)), SHARK, SMOOTH)
	end

	part("Mouth", Vector3.new(2.6, 0.7, 3.0), at * CFrame.new(3.6, 4.6, 0), BLACK, SMOOTH)
	for i = -1, 1 do
		part("Tooth", Vector3.new(0.45, 0.7, 0.5), at * CFrame.new(4.6, 4.9, i * 0.9), WHITE, SMOOTH)
	end
	-- An eye on each flank rather than a pair on one face: this is a profile.
	for _, sz in ipairs({ -1, 1 }) do
		ball("Eye", 1.1, at * CFrame.new(2.6, 6.7, sz * 1.5), WHITE, SMOOTH)
		ball("Pupil", 0.5, at * CFrame.new(2.6, 6.7, sz * 1.95), BLACK, SMOOTH)
	end

	-- Three trainers in a row down the belly. Two would be a shark with legs;
	-- three is the joke.
	for _, x in ipairs({ 2.4, 0, -2.4 }) do
		cylinderY("Leg", 3.0, 1.0, at * CFrame.new(x, 2.9, 0), SHARK, SMOOTH)
		-- The sole sits ON the grass: half its own thickness above zero, not
		-- at zero. Authored the lazy way it left the whole shark hovering a
		-- quarter of a stud, which is exactly the gap that reads as a bug.
		part("Sole", Vector3.new(1.9, 0.45, 3.4), at * CFrame.new(x, 0.225, 0.4), SOLE, SMOOTH)
		part("Shoe", Vector3.new(1.8, 1.2, 3.2), at * CFrame.new(x, 0.95, 0.4), WHITE, SMOOTH)
		part("Toe", Vector3.new(1.75, 0.9, 0.5), at * CFrame.new(x, 0.9, 2.1), SOLE, SMOOTH)
	end
end

builders.trophy = function(item, at)
	local WOOD = Color3.fromRGB(78, 52, 38)

	part("Base", Vector3.new(4.6, 1.3, 4.6), at * CFrame.new(0, 0.65, 0), WOOD, Enum.Material.Wood)
	part("Step", Vector3.new(3.6, 0.9, 3.6), at * CFrame.new(0, 1.75, 0),
		Color3.fromRGB(214, 214, 208), Enum.Material.Marble)
	cylinderY("Stem", 2.2, 1.0, at * CFrame.new(0, 3.3, 0), GOLD, Enum.Material.Metal)
	ball("Cup", 4.3, at * CFrame.new(0, 5.2, 0), GOLD, Enum.Material.Metal)
	cylinderY("Bowl", 2.4, 4.4, at * CFrame.new(0, 6.4, 0), GOLD, Enum.Material.Metal)
	cylinderY("Rim", 0.5, 5.0, at * CFrame.new(0, 7.6, 0), GOLD, Enum.Material.Metal)
	ball("Star", 1.5, at * CFrame.new(0, 8.4, 0), GOLD, Enum.Material.Neon)

	for _, sx in ipairs({ -1, 1 }) do
		part("Handle", Vector3.new(0.5, 3.0, 0.5), at * CFrame.new(sx * 3.0, 6.4, 0), GOLD, Enum.Material.Metal)
		part("HandleTop", Vector3.new(1.2, 0.5, 0.5), at * CFrame.new(sx * 2.5, 7.7, 0), GOLD, Enum.Material.Metal)
		part("HandleLow", Vector3.new(1.2, 0.5, 0.5), at * CFrame.new(sx * 2.5, 5.1, 0), GOLD, Enum.Material.Metal)
	end

	-- The plaque is the punchline, so it says so out loud.
	--
	-- Front is -Z on a Roblox part and this plaque faces the street on +Z, so
	-- the SurfaceGui goes on Back.
	local plaque = part("Plaque", Vector3.new(3.0, 1.1, 0.25),
		at * CFrame.new(0, 1.8, 1.85), GOLD, Enum.Material.Metal)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.CanvasSize = Vector2.new(300, 110)
	gui.Parent = plaque
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(58, 40, 12)
	label.Text = "#1 YARD"
	label.Parent = gui
end

-- The flex statue.
--
-- Built as an ORIGINAL character rather than the cartoon it is obviously
-- riffing on, and with the game's own snout mark rather than a fashion
-- house's monogram. Both of those are somebody else's property, both get
-- moderated off Roblox, and neither is load-bearing: the joke is a smug
-- little guy with a huge head, a gold chain and a designer bag, and none of
-- those four things belongs to anyone.
builders.dripstatue = function(item, at)
	local TEE = Color3.fromRGB(28, 28, 32)
	local DENIM = Color3.fromRGB(102, 134, 186)
	local BAG = Color3.fromRGB(168, 132, 88)
	local STRAP = Color3.fromRGB(92, 66, 42)
	local HAIR = Color3.fromRGB(120, 82, 52)

	part("Plinth", Vector3.new(5.2, 2.4, 5.2), at * CFrame.new(0, 1.2, 0), GOLD, Enum.Material.Metal)
	part("PlinthCap", Vector3.new(4.4, 0.6, 4.4), at * CFrame.new(0, 2.7, 0),
		Color3.fromRGB(226, 226, 220), Enum.Material.Marble)

	for _, sx in ipairs({ -1, 1 }) do
		part("Shoe", Vector3.new(1.7, 1.1, 3.0), at * CFrame.new(sx * 1.1, 3.55, 0.5), WHITE, SMOOTH)
		part("Sole", Vector3.new(1.8, 0.4, 3.2), at * CFrame.new(sx * 1.1, 3.15, 0.5),
			Color3.fromRGB(208, 212, 218), SMOOTH)
		part("Leg", Vector3.new(1.5, 4.2, 1.6), at * CFrame.new(sx * 1.1, 6.2, 0), DENIM, Enum.Material.Fabric)
	end

	part("Tee", Vector3.new(4.3, 4.6, 2.3), at * CFrame.new(0, 10.4, 0), TEE, Enum.Material.Fabric)
	for _, sx in ipairs({ -1, 1 }) do
		part("Sleeve", Vector3.new(1.3, 1.8, 2.1), at * CFrame.new(sx * 2.7, 11.6, 0), TEE, Enum.Material.Fabric)
		cylinderY("Arm", 3.4, 1.1, at * CFrame.new(sx * 2.7, 9.0, 0), SKIN, SMOOTH)
		ball("Hand", 1.2, at * CFrame.new(sx * 2.7, 7.2, 0), SKIN, SMOOTH)
	end

	-- The shirt graphic: wordmark over a roundel, drawn rather than built.
	--
	-- A SurfaceGui, not geometry, because the reference is a printed tee and a
	-- print is flat. Six studs of parts could not hold a legible word at this
	-- size, and a decal would need an upload and a moderation pass.
	teeGraphic(at * CFrame.new(0, 10.2, 1.16))

	for i = -3, 3 do
		ball("Chain", 0.42, at * CFrame.new(i * 0.52, 12.15 + 0.13 * i * i, 1.24), GOLD, Enum.Material.Metal)
	end
	ball("Pendant", 0.95, at * CFrame.new(0, 11.75, 1.36), GOLD, Enum.Material.Metal)

	cylinderY("Neck", 1.0, 1.3, at * CFrame.new(0, 13.1, 0), SKIN, SMOOTH)
	ball("Head", 4.3, at * CFrame.new(0, 15.3, 0), SKIN, SMOOTH)
	cylinderY("Hair", 1.2, 4.15, at * CFrame.new(0, 16.9, 0), HAIR, SMOOTH)
	part("Fringe", Vector3.new(3.6, 0.9, 1.3), at * CFrame.new(0, 16.4, 1.5), HAIR, SMOOTH)
	eyes(at, 1.0, 15.6, 1.95, 1.9)
	-- A little nose, offset to one side and low, between the eyes and the
	-- mouth. Without it the face was two eyes and a line, which read as a
	-- mask rather than a face.
	ball("Nose", 0.62, at * CFrame.new(-0.28, 14.65, 2.12), Color3.fromRGB(226, 178, 142), SMOOTH)
	part("Mouth", Vector3.new(1.7, 0.24, 0.35), at * CFrame.new(0, 14.0, 2.1), Color3.fromRGB(96, 62, 62), SMOOTH)

	-- The bag, hanging off one hand.
	--
	-- SmoothPlastic rather than Fabric: Fabric's weave is a dark noisy texture
	-- that turned the tan into a near-black lump at any distance.
	part("Bag", Vector3.new(3.0, 2.0, 1.8), at * CFrame.new(2.7, 5.4, 0.3), BAG, SMOOTH)
	for _, sx in ipairs({ -1, 1 }) do
		ball("BagEnd", 1.95, at * CFrame.new(2.7 + sx * 1.5, 5.4, 0.3), BAG, SMOOTH)
		part("Strap", Vector3.new(0.3, 1.9, 0.3), at * CFrame.new(2.7 + sx * 0.45, 6.9, 0.3),
			STRAP, Enum.Material.Leather)
	end
	part("BagTrim", Vector3.new(3.1, 0.4, 1.9), at * CFrame.new(2.7, 6.3, 0.3), STRAP, Enum.Material.Leather)
	part("BagZip", Vector3.new(2.9, 0.16, 0.2), at * CFrame.new(2.7, 6.1, 0.32), GOLD, Enum.Material.Metal)
	-- A monogrammed designer holdall, both faces.
	--
	-- The z figures are absolute, not mirrored: the bag is centred on z = 0.3
	-- rather than on zero, so its faces sit at 1.2 and -0.6 and a symmetric
	-- +/-1.05 buried the front print inside the bag it was printed on.
	monogram(at * CFrame.new(2.7, 5.35, 1.27))
	monogram(at * CFrame.new(2.7, 5.35, -0.67) * CFrame.Angles(0, math.pi, 0))
end

-- ============================================================
-- BUILD
-- ============================================================

-- One ornament, standing where you put it, outside the slot system entirely.
--
-- Exists for the thief's disguise: a player pretending to be a wheelie bin
-- needs the SAME bin everybody else has bought, or the disguise is a different
-- object from the thing it is imitating and fools nobody. Reusing the builder
-- is the whole point -- a second, nearly-identical bin would drift from this
-- one the first time either was touched.
function Decor.buildOne(key: string, at: CFrame, parent: Instance): Model?
	local item = Config.DECOR_ITEMS[key]
	local build = item and builders[item.style]
	if not build then
		return nil
	end

	local model = Instance.new("Model")
	model.Name = "Prop_" .. key
	folder = model

	build(item, at)

	model.Parent = parent
	return model
end

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
				-- Square to the road unless the slot asks otherwise, and no
				-- slot currently does. Plot-local +Z is the street on both
				-- rows and every builder above authors its ornament facing
				-- +Z, so an unrotated slot points the one good angle at the
				-- one place anybody stands. See Config.DECOR_SLOTS.
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
