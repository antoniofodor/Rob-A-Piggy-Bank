--!strict
--[[
	RideModel

	What each ride looks like, built once and used from both sides -- the board
	under a player's feet on the street (server) and the tile in the shop
	(client, inside a ViewportFrame). Same reason PigGear and BoneModel are
	shared: two builders drift, and a shop picture that does not match the
	thing you end up riding is worse than no picture.

	THE AUTHORING CONTRACT, and it is not the same as PigGear's.

	Every ride is built facing +Z with y = 0 AT THE GROUND -- the underside of
	the wheels, or for the hoverboard the ground it floats above. That is the
	one point placement has to be right about: RideService seats a ride on the
	floor under the character, and a model authored around its own visual
	centre would sink half a wheel into the tarmac. It is the same principle as
	the accessory pivot rule (a hat is authored at its brim so it can sit ON a
	head) applied to the other end of the body.

	The shop icon wants the visual centre instead and computes it for itself in
	makeModelIcon, which re-centres its own copy.

	Nothing here collides or answers a raycast, and every part is Massless.
	A ride is welded to a moving character: give it mass and it changes how the
	character walks, give it collision and it catches on the kerb.

	NO NAMED BRANDS. The scrambler is the genre -- a stubby, torquey electric
	dirt bike -- and not any manufacturer's, for exactly the reason the lawn
	ornaments are originals: Roblox moderation strips branded assets and the
	penalty lands on the experience rather than the one item.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local RideModel = {}

type Add = (name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?) -> Part

-- Roblox cylinders have their flat faces on X.
--
-- For anything facing +Z that means a WHEEL needs no rotation at all -- X is
-- already the axle direction -- while a POST has to be turned onto Y. Written
-- the wrong way round a post becomes a disc as wide as it was tall, which is
-- the single most repeated bug in this project.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local TYRE = Color3.fromRGB(28, 28, 32)
local STEEL = Color3.fromRGB(178, 182, 190)
local DARK_STEEL = Color3.fromRGB(84, 88, 96)
local GRIP = Color3.fromRGB(38, 38, 42)
-- Darker than TYRE on purpose: tread standing 0.06 proud of a carcass the
-- same colour as itself is 0.06 of nothing.
local TREAD = Color3.fromRGB(16, 16, 20)

local builders: { [string]: (any, Add) -> () } = {}

-- A wheel: axle along X, so no rotation. `thickness` is the tyre's width.
local function wheel(add: Add, x: number, y: number, z: number, radius: number,
	thickness: number, rim: Color3?)
	local tyre = add("Tyre", Vector3.new(thickness, radius * 2, radius * 2),
		CFrame.new(x, y, z), TYRE)
	tyre.Shape = Enum.PartType.Cylinder

	if rim then
		local hub = add("Rim", Vector3.new(thickness + 0.06, radius * 1.05, radius * 1.05),
			CFrame.new(x, y, z), rim, Enum.Material.Metal)
		hub.Shape = Enum.PartType.Cylinder
	end
end

-- A round bar standing on Y.
local function post(add: Add, size: number, height: number, cf: CFrame,
	colour: Color3, material: Enum.Material?)
	local p = add("Tube", Vector3.new(height, size, size), cf * UPRIGHT, colour, material)
	p.Shape = Enum.PartType.Cylinder
end

-- ============================================================
-- THE RIDES
-- ============================================================

builders.skateboard = function(spec, add)
	local WHEEL_R = 0.34
	local DECK_Y = 0.86

	-- Four wheels and two trucks. The wheels are the reason the deck sits
	-- where it does, so everything is measured up from them rather than from
	-- a guessed ride height -- the same mistake that left the decor car
	-- hovering.
	for _, sz in ipairs({ 1.85, -1.85 }) do
		for _, sx in ipairs({ 0.62, -0.62 }) do
			wheel(add, sx, WHEEL_R, sz, WHEEL_R, 0.4, spec.trim)
		end
		add("Truck", Vector3.new(1.5, 0.34, 0.7), CFrame.new(0, 0.68, sz), STEEL, Enum.Material.Metal)
		add("Baseplate", Vector3.new(1.1, 0.18, 1.3), CFrame.new(0, DECK_Y - 0.12, sz), DARK_STEEL, Enum.Material.Metal)
	end

	add("Deck", Vector3.new(1.7, 0.22, 5.0), CFrame.new(0, DECK_Y, 0), spec.colour)
	add("Grip", Vector3.new(1.6, 0.06, 4.8), CFrame.new(0, DECK_Y + 0.14, 0), GRIP)

	-- The kicked nose and tail. Without them a skateboard is a plank, and the
	-- upward flick at each end is most of what identifies it in silhouette.
	for _, spec2 in ipairs({ { 2.72, 1 }, { -2.72, -1 } }) do
		local z, dir = spec2[1], spec2[2]
		add("Kick", Vector3.new(1.7, 0.22, 1.5),
			CFrame.new(0, DECK_Y + 0.24, z) * CFrame.Angles(math.rad(dir * 24), 0, 0),
			spec.colour)
	end
end

builders.bmx = function(spec, add)
	local WHEEL_R = 1.25
	local FRONT_Z, BACK_Z = 2.15, -2.15

	wheel(add, 0, WHEEL_R, FRONT_Z, WHEEL_R, 0.34, spec.trim)
	wheel(add, 0, WHEEL_R, BACK_Z, WHEEL_R, 0.34, spec.trim)

	-- Forks, both ends. Thin boxes rather than angled cylinders: at this scale
	-- the lean reads and the axis bookkeeping does not earn its keep.
	for _, sx in ipairs({ 0.42, -0.42 }) do
		add("Fork", Vector3.new(0.16, 2.1, 0.4),
			CFrame.new(sx, WHEEL_R + 0.7, FRONT_Z - 0.16) * CFrame.Angles(math.rad(-14), 0, 0),
			spec.colour, Enum.Material.Metal)
		add("Stay", Vector3.new(0.16, 0.34, 2.3),
			CFrame.new(sx, WHEEL_R + 0.1, BACK_Z + 1.1) * CFrame.Angles(math.rad(9), 0, 0),
			spec.colour, Enum.Material.Metal)
	end

	-- Frame: down tube, top tube, seat tube. Three bars is the whole diamond.
	add("DownTube", Vector3.new(0.24, 0.3, 3.1),
		CFrame.new(0, 2.0, 0.55) * CFrame.Angles(math.rad(24), 0, 0), spec.colour, Enum.Material.Metal)
	add("TopTube", Vector3.new(0.24, 0.28, 2.6),
		CFrame.new(0, 3.05, 0.2) * CFrame.Angles(math.rad(4), 0, 0), spec.colour, Enum.Material.Metal)
	post(add, 0.26, 1.5, CFrame.new(0, 2.7, -1.4), spec.colour, Enum.Material.Metal)

	-- Saddle and bars.
	add("Saddle", Vector3.new(0.6, 0.26, 1.5), CFrame.new(0, 3.5, -1.5), GRIP)
	post(add, 0.26, 1.9, CFrame.new(0, 3.0, FRONT_Z - 0.3), STEEL, Enum.Material.Metal)
	add("Bars", Vector3.new(2.5, 0.24, 0.24), CFrame.new(0, 3.85, FRONT_Z - 0.3), STEEL, Enum.Material.Metal)
	for _, sx in ipairs({ 1.1, -1.1 }) do
		add("Grip", Vector3.new(0.5, 0.3, 0.3), CFrame.new(sx, 3.85, FRONT_Z - 0.3), spec.accent)
		add("BarEnd", Vector3.new(0.22, 0.3, 0.7),
			CFrame.new(sx * 1.06, 3.85, FRONT_Z - 0.55), STEEL, Enum.Material.Metal)
	end

	-- Cranks and pedals, at the bottom bracket.
	post(add, 0.9, 0.34, CFrame.new(0, 0.95, -0.35) * CFrame.Angles(0, 0, math.rad(90)),
		DARK_STEEL, Enum.Material.Metal)
	for _, sx in ipairs({ 0.55, -0.55 }) do
		add("Pedal", Vector3.new(0.7, 0.14, 0.42), CFrame.new(sx, 0.55, -0.35), GRIP)
	end
end

builders.scooter = function(spec, add)
	local WHEEL_R = 0.66
	local DECK_Y = 0.72
	local STEM_Z = 2.0

	wheel(add, 0, WHEEL_R, STEM_Z, WHEEL_R, 0.36, spec.trim)
	wheel(add, 0, WHEEL_R, -2.0, WHEEL_R, 0.36, spec.trim)

	add("Deck", Vector3.new(1.5, 0.3, 4.0), CFrame.new(0, DECK_Y, 0), spec.colour)
	add("Grip", Vector3.new(1.4, 0.06, 3.7), CFrame.new(0, DECK_Y + 0.18, 0), GRIP)

	-- The battery slung under the deck: the one part that says electric rather
	-- than kick scooter.
	add("Battery", Vector3.new(1.0, 0.34, 2.4), CFrame.new(0, DECK_Y - 0.3, -0.2),
		DARK_STEEL, Enum.Material.Metal)

	-- Stem, leaning back the way a scooter's does.
	--
	-- `post` takes the CENTRE of the tube, not its base. Written as a base
	-- this ran from the deck DOWN through the road -- a metre of handlebar
	-- buried in the tarmac -- and left a gap between the top of the stem and
	-- the bars it was supposed to be holding up.
	post(add, 0.34, 3.7, CFrame.new(0, 2.54, STEM_Z + 0.02) * CFrame.Angles(math.rad(-9), 0, 0),
		STEEL, Enum.Material.Metal)
	add("Bars", Vector3.new(2.4, 0.24, 0.24), CFrame.new(0, 4.35, STEM_Z - 0.3),
		STEEL, Enum.Material.Metal)
	for _, sx in ipairs({ 1.05, -1.05 }) do
		add("Grip", Vector3.new(0.5, 0.3, 0.3), CFrame.new(sx, 4.35, STEM_Z - 0.3), spec.accent)
	end
	add("Display", Vector3.new(0.9, 0.5, 0.16), CFrame.new(0, 4.05, STEM_Z - 0.42), spec.accent,
		Enum.Material.Neon)

	-- Rear fender over the back wheel, and a headlight at the top of the stem.
	add("Fender", Vector3.new(0.7, 0.16, 1.5), CFrame.new(0, WHEEL_R + 0.62, -2.0), spec.colour)
	add("Light", Vector3.new(0.5, 0.4, 0.22), CFrame.new(0, 3.5, STEM_Z + 0.05),
		Color3.fromRGB(255, 246, 214), Enum.Material.Neon)
end

builders.hoverboard = function(spec, add)
	-- The one ride with no wheels, so the FLOAT is the whole idea and the gap
	-- under it has to be unmistakable. y = 0 is still the ground: the board
	-- itself starts most of a stud above it, and the glow underneath is what
	-- makes that gap read as lift rather than as a modelling mistake.
	local BOARD_Y = 1.15

	add("Board", Vector3.new(2.5, 0.42, 5.4), CFrame.new(0, BOARD_Y, 0), spec.colour)
	add("Deck", Vector3.new(2.3, 0.08, 5.0), CFrame.new(0, BOARD_Y + 0.25, 0), GRIP)

	-- Chamfered nose and tail, so it reads as a board rather than a brick.
	for _, sz in ipairs({ 1, -1 }) do
		add("Tip", Vector3.new(2.1, 0.34, 0.9),
			CFrame.new(0, BOARD_Y + 0.05, sz * 2.9) * CFrame.Angles(math.rad(sz * 12), 0, 0),
			spec.colour)
	end

	-- Underside glow. Two long strips plus a brighter pad at each end: the
	-- strips say "powered", the pads say "this is what is holding it up".
	for _, sx in ipairs({ 0.85, -0.85 }) do
		add("Glow", Vector3.new(0.55, 0.1, 4.4), CFrame.new(sx, BOARD_Y - 0.24, 0),
			spec.accent, Enum.Material.Neon)
	end
	for _, sz in ipairs({ 1.9, -1.9 }) do
		local pad = add("Thruster", Vector3.new(0.3, 1.5, 1.5),
			CFrame.new(0, BOARD_Y - 0.26, sz) * UPRIGHT, spec.accent, Enum.Material.Neon)
		pad.Shape = Enum.PartType.Cylinder
		pad.Transparency = 0.25
	end

	add("Trim", Vector3.new(2.56, 0.1, 4.6), CFrame.new(0, BOARD_Y + 0.1, 0), spec.trim,
		Enum.Material.Metal)
end

builders.scrambler = function(spec, add)
	-- A stubby electric dirt bike: fat knobbly tyres, a slab of battery where
	-- an engine would be, and bars high enough to stand up on. Deliberately
	-- NOT any manufacturer's -- see the header.
	local WHEEL_R = 1.75
	local FRONT_Z, BACK_Z = 2.75, -2.75

	wheel(add, 0, WHEEL_R, FRONT_Z, WHEEL_R, 0.72, spec.trim)
	wheel(add, 0, WHEEL_R, BACK_Z, WHEEL_R, 0.72, spec.trim)

	-- Knobbly tread: eight blocks around each tyre. A smooth cylinder reads as
	-- a road bike, and the tread is most of what says this one goes off it.
	--
	-- Set on a radius INSIDE the tyre, so each block ends 0.06 proud of the
	-- carcass rather than centred on it. Two reasons, and they pull opposite
	-- ways: centred on WHEEL_R the bottom block hung a quarter of a stud below
	-- the road, and flush with WHEEL_R it would be coplanar with the tyre and
	-- z-fight. Proud-but-barely is the only value that is neither.
	local TREAD_R = WHEEL_R - 0.19
	for _, z in ipairs({ FRONT_Z, BACK_Z }) do
		for i = 0, 7 do
			local a = (i / 8) * math.pi * 2
			add("Knobble", Vector3.new(0.8, 0.5, 0.34),
				CFrame.new(0, WHEEL_R + math.cos(a) * TREAD_R, z + math.sin(a) * TREAD_R)
					* CFrame.Angles(-a, 0, 0), TREAD)
		end
	end

	-- Battery slab: the visual mass, standing in for an engine.
	add("Battery", Vector3.new(1.5, 2.3, 3.4), CFrame.new(0, 3.0, 0.1), spec.colour)
	add("Vent", Vector3.new(1.56, 0.22, 2.6), CFrame.new(0, 3.5, 0.1), spec.accent, Enum.Material.Neon)
	add("Cell", Vector3.new(1.56, 0.18, 2.2), CFrame.new(0, 2.5, 0.1), DARK_STEEL, Enum.Material.Metal)

	-- Forks and swingarm.
	for _, sx in ipairs({ 0.55, -0.55 }) do
		add("Fork", Vector3.new(0.28, 3.0, 0.5),
			CFrame.new(sx, WHEEL_R + 1.15, FRONT_Z - 0.35) * CFrame.Angles(math.rad(-16), 0, 0),
			STEEL, Enum.Material.Metal)
		add("Swingarm", Vector3.new(0.26, 0.5, 2.9),
			CFrame.new(sx, WHEEL_R + 0.05, BACK_Z + 1.4) * CFrame.Angles(math.rad(7), 0, 0),
			DARK_STEEL, Enum.Material.Metal)
	end

	-- Seat, pegs and bars.
	add("Seat", Vector3.new(1.3, 0.55, 2.9), CFrame.new(0, 4.4, -1.4), GRIP)
	add("Tail", Vector3.new(1.0, 0.3, 1.1),
		CFrame.new(0, 4.6, -3.0) * CFrame.Angles(math.rad(12), 0, 0), spec.colour)
	for _, sx in ipairs({ 0.95, -0.95 }) do
		add("Peg", Vector3.new(0.9, 0.2, 0.4), CFrame.new(sx, 1.5, -0.6), STEEL, Enum.Material.Metal)
	end

	post(add, 0.36, 1.6, CFrame.new(0, 4.1, FRONT_Z - 0.9) * CFrame.Angles(math.rad(-16), 0, 0),
		STEEL, Enum.Material.Metal)
	add("Bars", Vector3.new(3.0, 0.28, 0.28), CFrame.new(0, 5.5, FRONT_Z - 1.25),
		DARK_STEEL, Enum.Material.Metal)
	for _, sx in ipairs({ 1.3, -1.3 }) do
		add("Grip", Vector3.new(0.6, 0.34, 0.34), CFrame.new(sx, 5.5, FRONT_Z - 1.25), spec.accent)
	end

	-- Number board and headlight: the front of a dirt bike, and the two things
	-- that give it a face.
	add("Plate", Vector3.new(1.9, 1.7, 0.22),
		CFrame.new(0, 4.6, FRONT_Z - 0.35) * CFrame.Angles(math.rad(-16), 0, 0), spec.trim)
	add("Light", Vector3.new(1.0, 0.7, 0.24),
		CFrame.new(0, 4.55, FRONT_Z - 0.18) * CFrame.Angles(math.rad(-16), 0, 0),
		Color3.fromRGB(255, 248, 220), Enum.Material.Neon)
	add("Fender", Vector3.new(1.3, 0.24, 2.2),
		CFrame.new(0, WHEEL_R + 1.5, FRONT_Z - 0.1) * CFrame.Angles(math.rad(-8), 0, 0), spec.colour)
end

-- ============================================================
-- BUILD
-- ============================================================

function RideModel.build(key: string): Model
	local spec = Config.RIDES[key]
	assert(spec, ("Unknown ride '%s'"):format(tostring(key)))

	local model = Instance.new("Model")
	model.Name = "Ride_" .. key

	local function add(name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		-- Anchored FALSE and Massless TRUE, because this gets welded to a
		-- character rather than left standing in the world. An anchored part
		-- welded to a humanoid pins the humanoid; a heavy one changes how it
		-- walks and jumps, which would make a ride a stat rather than a look.
		p.Anchored = false
		p.Massless = true
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
	assert(build, ("Ride '%s' has no builder for style '%s'"):format(key, tostring(spec.style)))
	build(spec, add)

	-- The pivot is the AUTHORED ORIGIN -- ground level, centred, facing +Z --
	-- and never the bounding-box centre. RideService seats this on the floor
	-- under a character, and a centre pivot would bury half of it in the road.
	--
	-- No PrimaryPart: several parts here are rotated, and a PrimaryPart pivot
	-- REPLACES that rotation on the first PivotTo rather than adding to it,
	-- which would lay every board on its side. Same trap as PigGear.
	model.WorldPivot = CFrame.new()

	return model
end

-- The speed streak, built only when a ride is actually mounted.
--
-- Kept out of `build` so the shop tile does not draw one: an icon spinning in
-- a 48-pixel viewport with a motion trail attached to it reads as a smear.
function RideModel.addTrail(model: Model, colour: Color3)
	local anchor = model:FindFirstChildWhichIsA("BasePart")
	if not anchor then
		return
	end

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(-0.9, 0.2, -1.4)
	a0.Parent = anchor
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0.9, 0.2, -1.4)
	a1.Parent = anchor

	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(colour)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = 0.45
	trail.LightEmission = 0.6
	trail.MinLength = 0.4
	trail.Parent = anchor
end

return RideModel
