--!strict
--[[
	Decor

	Builds the lawn ornaments a player has bought, from the style keys in
	Config.DECOR_ITEMS. Same pattern as House and the fence styles: a table of
	small builders, so a new ornament is a Config entry plus one function.

	IN ReplicatedStorage BECAUSE THE SHOP RENDERS IT.

	This file was pure geometry over Config with no server-only API anywhere
	in it, so it moved here rather than being copied: the shop tiles show the
	REAL item, built by the same function that puts it on the lawn, and a
	second nearly-identical copy would drift from this one the first time
	either was touched. Same reasoning as BoneModel and PigGear, which have
	been shared this way from the start. It is one exception short of "no
	server-only API" now -- see the note below.

	NOTHING here collides, is queryable, or casts a shadow.

	That is a hard rule rather than a preference. These sit on the exact ground
	an owner defends and a thief runs across, so a solid fountain would be a
	pillar in the middle of a chase and a solid car would wall off the gate.
	They are things to look at, and that is all they are.

	ONE PIECE OF THIS FILE IS SERVER-ONLY: the Brace Face turtle's headband is
	runtime CSG, for the reason PlayerGear's mask is -- two cheaper attempts at
	a band that wraps a round head both failed, and the only thing in this
	engine that produces an actual continuous surface is a real union. See the
	note above `braceFaceBandTemplate`. It is built once on the SERVER and
	parked in ReplicatedStorage; every `builders.bracestatue` call, server or
	client, clones it -- the same split PlayerGear's mask already draws
	between "pure geometry over Config" and the one shape that needs the
	engine's own CSG.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local AlienModel = require(ReplicatedStorage.Shared.AlienModel)

local Decor = {}

-- How the server finds a trampoline mat. A TAG rather than a name walk,
-- because a plot's decor is rebuilt whenever an owner buys or puts away an
-- ornament, so there is no one moment at which a list could be collected --
-- the same reason the moat's bands are found by tag.
Decor.TRAMPOLINE_TAG = "TrampolineMat"
local TRAMPOLINE_TAG = Decor.TRAMPOLINE_TAG

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

-- A cylinder lying FRONT TO BACK, so its round profile is the one a viewer on
-- the pavement sees. A Roblox cylinder's axis is X, so this is a quarter turn
-- about Y -- the same gotcha `cylinderY` below answers, in the other axis.
--
-- What it is for: rounding the ENDS of a flat-sided box. A cylinder whose
-- diameter equals the box's height is TANGENT to the box's top and bottom, so
-- the two together make a stadium -- flat front, round ends, no step anywhere.
local function cylinderZ(name: string, length: number, diameter: number, cf: CFrame,
	color: Color3, material: Enum.Material): Part
	local p = part(name, Vector3.new(length, diameter, diameter),
		cf * CFrame.Angles(0, math.rad(90), 0), color, material)
	p.Shape = Enum.PartType.Cylinder
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

-- ============================================================
-- SHARED CSG SCAFFOLDING
-- ============================================================
--
-- Two ornaments now need runtime CSG -- the turtle's headband and the drip
-- statue's eyelids -- so the folder and the cache they share live up here,
-- ABOVE every builder that calls them.
--
-- That placement is load-bearing, not tidiness. A `local` declared after a
-- function that reads it is a nil GLOBAL to that function, and Luau does not
-- complain until the call dies with "attempt to call a nil value" naming
-- nothing useful. This project has hit that seven times. `builders.dripstatue`
-- sits 340 lines above where this block used to be, so leaving it there would
-- have been the eighth.
--
-- SERVER-ONLY, like every CSG call here: `UnionAsync` and `SubtractAsync`
-- both throw outright from a LocalScript, and these same statues are what the
-- shop's ViewportFrame renders on the CLIENT. Built once, parked in
-- ReplicatedStorage, cloned everywhere, and warmed by `Decor.prewarm` at
-- server start -- the alternative is the first ever call landing inside
-- whichever request needs it first, and CSG yields.
local DECOR_TEMPLATE_FOLDER = "DecorTemplates"
local decorTemplates: { [string]: BasePart } = {}

local function decorTemplateFolder(): Instance?
	local existing = ReplicatedStorage:FindFirstChild(DECOR_TEMPLATE_FOLDER)
	if existing then
		return existing
	end
	if not RunService:IsServer() then
		-- A client that asks before the server has finished waits briefly
		-- rather than building nothing: the shop is drawn at join, which is
		-- the one moment this can be a race.
		return ReplicatedStorage:WaitForChild(DECOR_TEMPLATE_FOLDER, 10)
	end
	local f = Instance.new("Folder")
	f.Name = DECOR_TEMPLATE_FOLDER
	f.Parent = ReplicatedStorage
	return f
end

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

-- ============================================================
-- THE CANDY GARDEN
-- ============================================================
--
-- A DELIBERATE MOVE AWAY FROM THE MEME SHELF, and the reasons are not only
-- taste. Nine of the fourteen lawn ornaments were internet jokes -- a tube
-- man, a swole gnome, a shark in trainers -- which is a genre this game shares
-- with every other stealing game on the platform, and it has two costs beyond
-- looking like everyone else.
--
-- A MEME HAS A SHELF LIFE AND A SHAPE DOES NOT. A reference from two years ago
-- is already tired and reads as dated rather than funny; a gummy bear is a
-- shape, nobody has to get it, and it will look the same in five years.
--
-- AND IT TAKES THE IP EXPOSURE TO ZERO. This file already carries several
-- paragraphs about building meme ornaments as ORIGINALS because the real ones
-- are somebody's property, moderation strips branded assets, and the penalty
-- lands on the EXPERIENCE rather than the one prop -- the Brace Face note even
-- records live litigation over exactly that class of character. Slime, jelly
-- and gummy are unownable. That whole category of risk simply is not here.
--
-- The meme ornaments STAY. They are built, priced and already on people's
-- lawns, and with eight curated slots a mixed garden is the point -- choosing
-- what to leave in the shed IS the decoration. This is what gets added.
--
-- THE ENVELOPE IS 22 WIDE BY 12 DEEP. Slot columns are 22 apart and rows 12
-- apart, so anything bigger than that overlaps its neighbour whatever the slot
-- layout does. Giants go UP.

-- A pond, and the whole difficulty is that NOTHING HERE CAN BE DUG.
--
-- The lawn is one solid Part and a Part cannot cut a hole in another Part, so
-- a slime surface set below ground level does not make a hollow -- it makes
-- an invisible slab hidden behind the grass that is still there above it. The
-- moat learned this the expensive way and its solution is what this reuses at
-- a fifth of the scale: every layer stands PROUD of the ground and the depth
-- is an illusion the RIM does all the work for, because the eye takes the
-- highest line in a shape as its ground level.
--
-- Three layers, and the order matters as much as the heights:
--     rim      0.00 .. 0.90   the highest line, so this reads as the edge
--     slime    0.20 .. 0.70   a VOLUME, 0.20 below the rim, seen into
--     bed      0.00 .. 0.30   opaque and dark, the thing actually seen
--
-- The opaque bed is not optional. Without it the translucent surface tints
-- the grass underneath and the pond comes out the colour of the lawn -- which
-- for a green slime is the one failure that would be hardest to spot.
builders.slimepond = function(item, at)
	local RIM = Color3.fromRGB(96, 104, 88)
	local BED = Color3.fromRGB(22, 46, 26)
	local SLIME = item.swatch or Color3.fromRGB(126, 222, 78)

	local W, D = 11, 8
	local RIM_W = 1.0

	-- The bed first: opaque, dark, and the thing you are actually looking at
	-- through the slime.
	part("Bed", Vector3.new(W, 0.30, D), at * CFrame.new(0, 0.15, 0), BED, Enum.Material.Slate)

	-- The slime: a THICK slab rather than a sheet. A flat plane has nothing to
	-- see into; half a stud of translucent green over a dark bed does.
	local pool = part("Slime", Vector3.new(W, 0.50, D), at * CFrame.new(0, 0.45, 0),
		SLIME, Enum.Material.SmoothPlastic)
	pool.Transparency = 0.35
	pool.Reflectance = 0.25

	-- The rim, as a closed ring rather than four separate kerbs, and the
	-- corners deliberately overlap: a gap at a corner is the one place the
	-- illusion breaks, because you can see the ground is flat.
	local ox, oz = W / 2 + RIM_W / 2, D / 2 + RIM_W / 2
	for _, spec in ipairs({
		{ sz = Vector3.new(W + RIM_W * 2, 0.90, RIM_W), at = Vector3.new(0, 0.45, oz) },
		{ sz = Vector3.new(W + RIM_W * 2, 0.90, RIM_W), at = Vector3.new(0, 0.45, -oz) },
		{ sz = Vector3.new(RIM_W, 0.90, D), at = Vector3.new(ox, 0.45, 0) },
		{ sz = Vector3.new(RIM_W, 0.90, D), at = Vector3.new(-ox, 0.45, 0) },
	}) do
		part("Rim", spec.sz, at * CFrame.new(spec.at), RIM, Enum.Material.Slate)
	end

	-- Bubbles, HALF SUNK. Their centres sit exactly on the slime's top face, so
	-- each shows a dome and reads as coming out of the surface rather than as a
	-- ball resting on it -- the same half-in-half-out rule the pig's nose and
	-- the statue's eyes are both cut against.
	for _, b in ipairs({
		{ x = -2.6, z = -1.4, d = 1.5 },
		{ x = 1.1, z = 1.8, d = 1.1 },
		{ x = 3.2, z = -0.9, d = 0.8 },
	}) do
		local bub = ball("Bubble", b.d, at * CFrame.new(b.x, 0.70, b.z), SLIME, Enum.Material.SmoothPlastic)
		bub.Transparency = 0.25
		bub.Reflectance = 0.3
	end

	-- One drip over the rim, so the slime reads as something with a viscosity
	-- rather than as coloured water.
	local drip = part("Drip", Vector3.new(1.6, 0.9, 0.7), at * CFrame.new(-3.4, 0.55, oz),
		SLIME, Enum.Material.SmoothPlastic)
	drip.Transparency = 0.3
end

-- The first decoration in the game that DOES anything, and the one line that
-- keeps it from being a power item: it must not change an OUTCOME.
--
-- Not the steal, not the chase, not the tag, not the getaway. A bounce is a
-- toy. The moment anyone wants "bounce higher" as a purchasable tier it has
-- become a movement upgrade, and the closed system of speed, time and distance
-- that every other number here is calibrated against is open.
--
-- THE MAT IS A TRIGGER, NOT A SURFACE. Everything in this file is CanCollide
-- and CanQuery off -- a hard rule, because these sit on the exact ground a
-- defender defends and a thief runs across -- and that stays true here. The
-- bounce comes off `Touched`, which fires on overlap and does not need
-- collision, so the trampoline can never body-block anybody and can never be
-- stood behind as cover. See PlotService for the server side.
--
-- Height turns out not to be the risk it looks like. Spring shoes were dropped
-- from this game, but not because jumping over fences was too strong: the
-- ClimbZone snag spans y 5.5 to 10.5 and catches a climber ON THE WAY UP
-- whatever their apex, so a bigger jump buys nothing at a fence.
builders.trampoline = function(item, at)
	local FRAME = item.swatch or Color3.fromRGB(72, 138, 226)
	local MAT = Color3.fromRGB(28, 32, 44)
	local LEG = Color3.fromRGB(150, 156, 168)

	local R, MAT_R = 5.0, 4.2
	local TOP = 2.1

	-- Legs at the diagonals, so the silhouette from the pavement is the frame
	-- rather than a leg standing in front of it.
	for _, a in ipairs({ 45, 135, 225, 315 }) do
		local rad = math.rad(a)
		cylinderY("Leg", TOP, 0.55,
			at * CFrame.new(math.sin(rad) * (R - 0.5), TOP / 2, math.cos(rad) * (R - 0.5)),
			LEG, Enum.Material.Metal)
	end

	-- The frame is a wide flat cylinder rather than a ring of boxes: a real
	-- annulus is not a thing a Part can be, and a dozen boxes bent round a
	-- circle reads as a dozen boxes. The mat sits INSIDE it and lower, which
	-- is what makes the frame read as a rim.
	cylinderY("Frame", 0.55, R * 2, at * CFrame.new(0, TOP, 0), FRAME, Enum.Material.SmoothPlastic)

	-- Named `Mat` and tagged, because the server hooks it by tag. Set 0.06
	-- below the frame's own top face -- two surfaces at one height is the
	-- coplanar flicker this project has caught four times.
	local mat = cylinderY("Mat", 0.35, MAT_R * 2, at * CFrame.new(0, TOP - 0.06, 0),
		MAT, Enum.Material.SmoothPlastic)
	mat.Name = "Mat"
	CollectionService:AddTag(mat, TRAMPOLINE_TAG)

	-- Springs, in the gap between the mat and the frame. Radial, so each one
	-- is turned to point at the centre rather than all facing the same way.
	for i = 0, 11 do
		local rad = (i / 12) * math.pi * 2
		local r = (R + MAT_R) / 2
		part("Spring", Vector3.new(0.22, 0.16, R - MAT_R),
			at * CFrame.new(math.sin(rad) * r, TOP + 0.04, math.cos(rad) * r)
				* CFrame.Angles(0, rad, 0),
			LEG, Enum.Material.Metal)
	end
end

-- Balls, because a gummy bear is a pile of round volumes and nothing else.
--
-- SMOOTHPLASTIC WITH TRANSPARENCY, never Glass: glass takes its look from what
-- is behind it and on a lawn that is grass, so a glass bear is a green bear
-- whatever colour it was authored. The colour is the whole point here, which
-- is the same reason the tube man is not Fabric.
builders.gummybear = function(item, at)
	local JELLY = item.swatch or Color3.fromRGB(226, 82, 96)

	local function blob(name: string, d: number, x: number, y: number, z: number)
		local b = ball(name, d, at * CFrame.new(x, y, z), JELLY, Enum.Material.SmoothPlastic)
		b.Transparency = 0.32
		b.Reflectance = 0.2
		return b
	end

	blob("Legs", 1.7, -1.25, 0.85, 0)
	blob("Legs", 1.7, 1.25, 0.85, 0)
	blob("Body", 3.5, 0, 2.35, 0)
	blob("Arm", 1.5, -2.0, 3.05, 0)
	blob("Arm", 1.5, 2.0, 3.05, 0)
	blob("Head", 2.5, 0, 4.55, 0)
	blob("Ear", 1.0, -1.0, 5.5, 0)
	blob("Ear", 1.0, 1.0, 5.5, 0)
	blob("Snout", 1.1, 0, 4.3, 1.0)

	-- Eyes and nose are OPAQUE on purpose: a translucent eye on a translucent
	-- head disappears entirely, and this is the only part of the shape that
	-- says which way it is facing.
	for _, sx in ipairs({ -1, 1 }) do
		ball("Eye", 0.34, at * CFrame.new(sx * 0.55, 4.95, 1.02),
			Color3.fromRGB(28, 20, 24), Enum.Material.SmoothPlastic)
	end
	ball("Nose", 0.4, at * CFrame.new(0, 4.42, 1.52), Color3.fromRGB(28, 20, 24), Enum.Material.SmoothPlastic)
end

-- A rounded cube, and the rounding is a TANGENCY problem rather than an
-- arrangement one -- the same rule the designer holdall's stadium prism is
-- built on. Two crossed boxes plus four corner cylinders whose RADIUS EQUALS
-- the amount each box is inset: get that number right and the seam disappears
-- with no CSG; get it wrong by any amount and no nudging hides the step.
--
-- Only the four VERTICAL edges are rounded. Those are the ones a viewer on the
-- pavement sees in silhouette; rounding the horizontal ones as well would cost
-- eight more parts to fix an edge nobody is looking at.
builders.jellycube = function(item, at)
	local JELLY = item.swatch or Color3.fromRGB(240, 176, 64)
	local S, H, R = 5.0, 4.6, 0.6

	local function slab(name: string, size: Vector3, cf: CFrame)
		local p = part(name, size, cf, JELLY, Enum.Material.SmoothPlastic)
		p.Transparency = 0.3
		p.Reflectance = 0.25
		return p
	end

	slab("Core", Vector3.new(S, H, S - R * 2), at * CFrame.new(0, H / 2, 0))
	slab("Core", Vector3.new(S - R * 2, H, S), at * CFrame.new(0, H / 2, 0))
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local c = cylinderY("Corner", H, R * 2,
				at * CFrame.new(sx * (S / 2 - R), H / 2, sz * (S / 2 - R)),
				JELLY, Enum.Material.SmoothPlastic)
			c.Transparency = 0.3
			c.Reflectance = 0.25
		end
	end

	-- A highlight slab just inside the top face. Proud by 0.02 rather than
	-- level with it, because two faces at one depth is the coplanar flicker
	-- this project keeps re-learning.
	local gloss = part("Gloss", Vector3.new(S - 1.8, 0.12, S - 1.8),
		at * CFrame.new(0, H + 0.02, 0), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic)
	gloss.Transparency = 0.55

	-- A cherry, so the thing has a front and a scale you can read.
	cylinderY("Stalk", 1.0, 0.16, at * CFrame.new(0, H + 0.5, 0),
		Color3.fromRGB(86, 132, 62), Enum.Material.SmoothPlastic)
	local cherry = ball("Cherry", 1.3, at * CFrame.new(0, H + 1.3, 0),
		Color3.fromRGB(206, 46, 62), Enum.Material.SmoothPlastic)
	cherry.Reflectance = 0.2
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

-- builders.car is gone with the Hatchback and the Sports Car. Nothing else
-- built a car: the patrol's is PoliceModel's own, deliberately, because it
-- has a light bar and a roundel that a parked ornament must never wear.

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
--
-- IT NEEDS A FLAT FACE, which is why the bag is a stadium prism rather than
-- the capsule it briefly was: on a 0.95-radius barrel a panel wide enough to
-- read stood its corners 0.73 studs off the curve, a plank stuck to a bag.
-- A box with rounded ENDS keeps the front flat and rounds the silhouette,
-- so the print lies down properly and the shape still reads as soft luggage.
local function monogram(cf: CFrame)
	-- Sized to FILL the bag's flat front (2.30 x 1.80) rather than float in
	-- the middle of it: a panel with a margin all round reads as a patch sewn
	-- onto a plain bag, and the reference is a bag that IS the canvas. It
	-- stops exactly at the box's edge, where the leather end caps take over.
	local gui = panel("BagPrint", 2.3, 1.76, cf, 230, 176)
	-- 7 x 5 rather than 6 x 4: on this panel that gives tiles 0.329 x 0.352,
	-- near enough square. The old split made them half again taller than
	-- wide, which reads as bricks instead of a check.
	local COLS, ROWS = 7, 5
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
-- ------------------------------------------------------------
-- THE DRIP STATUE'S EYELID
-- ------------------------------------------------------------
--
-- A CAP, BECAUSE A BALL CANNOT DO THIS. The lid has to cover the top of an
-- eyeball that already stands 0.39 proud of the skull, and a ball's top is
-- its centre plus its radius -- so riding the centre up far enough to cover
-- the eye carried the ball's crown into the hair. No radius or offset escapes
-- that; the shape is wrong, not the numbers.
--
-- A cap has no rest-of-the-sphere to stick up. Cut from a ball CONCENTRIC
-- with the eyeball it is a layer lying ON the eye and cannot exceed the eye's
-- own envelope: its crown lands at y 16.064 against a hairline at 16.677.
--
-- 0.86 puts it OUTSIDE the 0.84 outline shell, and the 0.02 gap between every
-- layer here is deliberate -- white 0.82, outline 0.84, lid 0.86, all sharing
-- one centre. Concentric surfaces never intersect, so none of them can
-- z-fight; see the outline's own note for what happens when they do.
--
-- Cut at 0.60 along its own axis, which is where the pupil stops: the pupil
-- reaches 0.5479 and anything shallower would clip it. Covers the top 19.3%.
local LID_R = 0.86
local LID_CUT = 0.60
-- Up, tilted forward toward the eye's own direction, so the cap sits on the
-- top FRONT of the eyeball rather than on its crown.
local LID_AXIS = Vector3.new(0.21525, 0.87725, 0.42907)

local function dripEyelidTemplate(): BasePart?
	local folder = decorTemplateFolder()
	if folder then
		local ready = folder:FindFirstChild("dripEyelid")
			or (if RunService:IsServer() then nil else folder:WaitForChild("dripEyelid", 10))
		if ready and ready:IsA("BasePart") then
			decorTemplates.dripEyelid = ready
			return ready
		end
	end
	if not RunService:IsServer() then
		return nil
	end
	local cached = decorTemplates.dripEyelid
	if cached then
		return cached
	end

	local scratch = Instance.new("Folder")
	scratch.Parent = workspace

	-- Built with the sphere's centre on the ORIGIN and the cap facing +Y, so
	-- the template's own space is "eye centre, lid pointing up". Seating it
	-- is then one CFrame per eye and no per-side geometry.
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(LID_R * 2, LID_R * 2, LID_R * 2)
	ball.CFrame = CFrame.new()
	ball.Anchored = true
	ball.Parent = scratch

	local below = Instance.new("Part")
	below.Size = Vector3.new(6, 6, 6)
	below.CFrame = CFrame.new(0, LID_CUT - 3, 0)
	below.Anchored = true
	below.Parent = scratch

	local ok, cap = pcall(function()
		return ball:SubtractAsync({ below })
	end)
	if not ok or not cap then
		scratch:Destroy()
		warn(("[Decor] SubtractAsync failed for the drip eyelid: %s"):format(tostring(cap)))
		return nil
	end

	cap.UsePartColor = true
	cap.Color = SKIN
	cap.Material = SMOOTH
	cap.Name = "dripEyelid"
	cap.Anchored = true
	cap.CanCollide = false
	cap.CanQuery = false
	cap.CastShadow = false

	scratch:Destroy()
	local dest = decorTemplateFolder()
	if dest then
		cap.Parent = dest
	end
	decorTemplates.dripEyelid = cap
	return cap
end

-- ------------------------------------------------------------
-- THE DRIP STATUE'S EYE OUTLINE
-- ------------------------------------------------------------
--
-- A CONCENTRIC SHELL WITH A BORE THROUGH IT, and the reason is that the
-- previous outline was NOISY -- a speckled, ragged fringe rather than a line.
--
-- It was a dark ball sunk BEHIND the white at a different centre, showing as
-- the sliver by which its silhouette exceeded the white's. Measured, those
-- two spheres crossed each other at 12.2 degrees. That is near-TANGENT: the
-- surfaces run alongside each other for the entire length of the ring, within
-- depth-buffer noise of one another, which is exactly what speckles. Making
-- the ring thinner made it worse, because thinner means closer.
--
-- Concentric surfaces never intersect AT ALL, so there is no tangency left to
-- fight. The dark shell shares the eyeball's centre at 0.84 against the
-- white's 0.82, and the ring is made by CUTTING a bore through it rather than
-- by peeking past another sphere. What is left crosses the head at 49.9
-- degrees, which is crisp.
--
-- The bore is 0.752 against the white's silhouette of 0.762, so the dark
-- starts just INSIDE where the white leaves the head and the two always
-- touch. Wider than 0.762 and a sliver of skin appears between the eye and
-- its own outline.
local OUTLINE_R = 0.84
local OUTLINE_BORE = 0.752

local function dripEyeOutlineTemplate(): BasePart?
	local folder = decorTemplateFolder()
	if folder then
		local ready = folder:FindFirstChild("dripEyeOutline")
			or (if RunService:IsServer() then nil else folder:WaitForChild("dripEyeOutline", 10))
		if ready and ready:IsA("BasePart") then
			decorTemplates.dripEyeOutline = ready
			return ready
		end
	end
	if not RunService:IsServer() then
		return nil
	end
	local cached = decorTemplates.dripEyeOutline
	if cached then
		return cached
	end

	local scratch = Instance.new("Folder")
	scratch.Parent = workspace

	-- Centre on the origin with the bore along +X, which is a Roblox
	-- cylinder's own axis -- so the template's space is "eye centre, looking
	-- out along +X" and seating it is one CFrame whose X axis is the eye's
	-- direction. The bore runs clean through; the far opening is buried in
	-- the skull and never seen.
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(OUTLINE_R * 2, OUTLINE_R * 2, OUTLINE_R * 2)
	ball.CFrame = CFrame.new()
	ball.Anchored = true
	ball.Parent = scratch

	local bore = Instance.new("Part")
	bore.Shape = Enum.PartType.Cylinder
	bore.Size = Vector3.new(4, OUTLINE_BORE * 2, OUTLINE_BORE * 2)
	bore.CFrame = CFrame.new()
	bore.Anchored = true
	bore.Parent = scratch

	local ok, ring = pcall(function()
		return ball:SubtractAsync({ bore })
	end)
	if not ok or not ring then
		scratch:Destroy()
		warn(("[Decor] SubtractAsync failed for the drip eye outline: %s"):format(tostring(ring)))
		return nil
	end

	ring.UsePartColor = true
	ring.Color = Color3.fromRGB(26, 26, 30)
	ring.Material = SMOOTH
	ring.Name = "dripEyeOutline"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CastShadow = false

	scratch:Destroy()
	local dest = decorTemplateFolder()
	if dest then
		ring.Parent = dest
	end
	decorTemplates.dripEyeOutline = ring
	return ring
end

-- ------------------------------------------------------------
-- THE DRIP STATUE'S HAIR, WITH THE CUT IN IT
-- ------------------------------------------------------------
--
-- A RAISED SPHERE CUTS THE HEAD IN A PLANE, SO ITS HAIRLINE IS ONE CONSTANT
-- HEIGHT ALL THE WAY ROUND -- and that is the whole reason the earlier hair
-- was wrong. The reference needs two different things at once: a hairline
-- that comes DOWN at the sides, near the ear, and a SHARP raised edge across
-- the forehead clear of the brows. One sphere cannot do both, and no amount
-- of moving or resizing it can, because it only ever has the one hairline.
--
-- The reference wants THREE heights, not two: high and sharp at the front,
-- down to halfway down the eye at the temple, angling behind the ear, and
-- lower again at the nape. A ball raised straight up gives the sides and the
-- back the SAME height, so it can never produce that last step.
--
-- TILTING THE OFFSET BACK IS WHAT ORDERS THEM. The hairline is a plane
-- perpendicular to the offset, so leaning the offset back tips that plane:
-- front highest, sides middle, back lowest, in one move and for free. A
-- pure-up offset was tried first and had to be abandoned for exactly the
-- missing nape. The lean is slight -- 6 degrees -- because the plane is long
-- and a little tilt travels a long way across it.
--
-- The ball is then sized so its own hairline lands at y 15.30 at the side,
-- which is HALFWAY DOWN THE EYEBALL, and it falls away to 15.05 at the back.
-- The forehead is CUT BACK from there by a plane, which is what produces the
-- sharp edge: a flat facet meeting the skull as a straight line, where a
-- sphere can only give a soft circle. It carries the front hairline to 16.90
-- and hands back to the natural line at y 15.40 -- just above the eye's
-- centre, which is where the reference's edge turns the corner.
--
-- THE RAZOR SLICE IS A WEDGE, AND A PLANE CANNOT MAKE ONE. The first attempt
-- used a third plane and produced a DARK PATCH rather than a cut: a plane at
-- a narrow angular radius only shaves the outer skin of the cap, and measured
-- it removed 0.052 of a coat 0.232 thick. What is left is a flat, hair-
-- coloured facet catching the light at a different angle -- which looks
-- exactly like a smudge on the head. To show scalp, a cutter has to pass
-- INSIDE the head's own surface, not merely inside the hair's.
--
-- Going deeper does not rescue a plane either, because depth and width are
-- the same number for one: a plane deep enough to reach the scalp opens a
-- 31-degree cap, which is a third of the head shaved flat.
--
-- A BOX gives depth without width, and is still not a slice: its thickness
-- bounds the slot equally at both ends, so it cuts a parallel-sided slit.
--
-- So the cutter is a mirrored PAIR OF WEDGES whose union is one symmetric
-- triangle -- measured widening 0.07 to 0.39 from tip to base. A WedgePart is
-- a triangular prism with its full height at +Z tapering to nothing at -Z,
-- extruded along X, which was verified by raycasting a test wedge rather than
-- assumed. Two of them because a single wedge grows from its own base edge
-- and would give a one-sided slash; mirroring is free, since SubtractAsync
-- takes the UNION of everything handed to it.
--
-- The prism runs 0.55 under the scalp and 0.45 clear of the hair, so it cuts
-- the coat through at every point along its length, and the base end passes
-- BEYOND the hairline so the slice opens into the edge instead of sitting in
-- the middle of the hair as an enclosed hole.
--
-- +X IS THE VIEWER'S RIGHT. A statue faces +Z and a camera looking at its
-- front looks down -Z, so its right vector is +X -- the cut lands on the same
-- side it does in the reference.
local HAIR_R = 2.39203
-- THE FRONT: a plane laid across the cap, which is where the sharp hairline
-- comes from. Everything in front of and above it goes.
local HAIR_FRONT_N = Vector3.new(0, -0.50000, 0.86603)
local HAIR_FRONT_P = 1.02776
-- THE RAZOR SLICE: two wedges above the right brow, mirrored about the slot's
-- own centreline. `vX` is the depth axis and is flipped on the second half
-- along with `vY` -- flipping only `vY` gives a LEFT-handed frame, which is
-- not a rotation; the prism is symmetric in depth, so the flip costs nothing.
local HAIR_SLICE = {
	{
		size = Vector3.new(1.2207, 0.2300, 1.3400),
		pos = Vector3.new(1.33206, 1.20332, 1.33090),
		vX = Vector3.new(0.63278, 0.50304, 0.58868),
		vY = Vector3.new(-0.69665, 0.70172, 0.14921),
		vZ = Vector3.new(-0.33803, -0.50452, 0.79448),
	},
	{
		size = Vector3.new(1.2207, 0.2300, 1.3400),
		pos = Vector3.new(1.49229, 1.04192, 1.29658),
		vX = Vector3.new(-0.63278, -0.50304, -0.58868),
		vY = Vector3.new(0.69665, -0.70172, -0.14921),
		vZ = Vector3.new(-0.33803, -0.50452, 0.79448),
	},
}

local function dripHairTemplate(): BasePart?
	local folder = decorTemplateFolder()
	if folder then
		local ready = folder:FindFirstChild("dripHair")
			or (if RunService:IsServer() then nil else folder:WaitForChild("dripHair", 10))
		if ready and ready:IsA("BasePart") then
			decorTemplates.dripHair = ready
			return ready
		end
	end
	if not RunService:IsServer() then
		return nil
	end
	local cached = decorTemplates.dripHair
	if cached then
		return cached
	end

	local scratch = Instance.new("Folder")
	scratch.Parent = workspace

	-- Centre on the ORIGIN, so the template's space is "hair centre", and
	-- seating it is one CFrame in the builder.
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(HAIR_R * 2, HAIR_R * 2, HAIR_R * 2)
	ball.CFrame = CFrame.new()
	ball.Anchored = true
	ball.Parent = scratch

	-- Each cutter is an 8-stud box with its near face ON its plane: the centre
	-- goes 4 further out along the normal than the plane is, so the face lands
	-- exactly on it and everything beyond is removed. The `up` vector only has
	-- to be perpendicular to the normal -- a plane is symmetric about its own
	-- axis, so which perpendicular is chosen makes no difference.
	local function planeCutter(normal: Vector3, dist: number, up: Vector3): BasePart
		local box = Instance.new("Part")
		box.Size = Vector3.new(8, 8, 8)
		box.CFrame = CFrame.fromMatrix(normal * (dist + 4), normal, normal:Cross(up).Unit)
		box.Anchored = true
		box.Parent = scratch
		return box
	end

	local cutters = { planeCutter(HAIR_FRONT_N, HAIR_FRONT_P, Vector3.new(1, 0, 0)) }
	for _, half in ipairs(HAIR_SLICE) do
		local wedge = Instance.new("WedgePart")
		wedge.Size = half.size
		wedge.CFrame = CFrame.fromMatrix(half.pos, half.vX, half.vY, half.vZ)
		wedge.Anchored = true
		wedge.Parent = scratch
		table.insert(cutters, wedge)
	end

	local ok, cut = pcall(function()
		return ball:SubtractAsync(cutters)
	end)
	if not ok or not cut then
		scratch:Destroy()
		warn(("[Decor] SubtractAsync failed for the drip hair: %s"):format(tostring(cut)))
		return nil
	end

	cut.UsePartColor = true
	cut.Color = Color3.fromRGB(120, 82, 52)
	cut.Material = SMOOTH
	cut.Name = "dripHair"
	cut.Anchored = true
	cut.CanCollide = false
	cut.CanQuery = false
	cut.CastShadow = false

	scratch:Destroy()
	local dest = decorTemplateFolder()
	if dest then
		cut.Parent = dest
	end
	decorTemplates.dripHair = cut
	return cut
end

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
		-- THE JEANS STOP SHORT OF THE SHOE so a little ankle shows, the way
		-- they do in the reference. They used to end at 4.10, exactly where
		-- the shoe begins, so denim met canvas with no leg between them.
		-- Cropped to 4.45 that leaves 0.35 of visible skin.
		part("Leg", Vector3.new(1.5, 3.85, 1.6), at * CFrame.new(sx * 1.1, 6.375, 0), DENIM, Enum.Material.Fabric)
		-- The ankle itself, tucked 0.125 up into the cuff and 0.075 down into
		-- the shoe so neither join can open a gap. Narrower than both -- 1.15
		-- against a 1.5-wide jean and a 1.7-wide shoe -- because an ankle is
		-- thinner than the calf above it and the shoe below it, and a cylinder
		-- that matched either would read as a peg rather than a leg.
		cylinderY("Ankle", 0.55, 1.15, at * CFrame.new(sx * 1.1, 4.30, 0), SKIN, SMOOTH)
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
	-- A BIGGER SKULL BUYS FACE, NOT A BIGGER FACE. 4.3 -> 4.7 across, centre
	-- lifted 15.30 -> 15.40 so the neck still shows 0.45 of itself. Every
	-- feature keeps its own size, so the same eyes on a wider head leave more
	-- skin all round them -- which is the whole point: the forehead band
	-- between the eye and the hairline goes 0.373 -> 0.620, and the brow
	-- finally has room to sit in it with skin above AND below.
	ball("Head", 4.7, at * CFrame.new(0, 15.40, 0), SKIN, SMOOTH)

	-- THE FACE IS SET INTO THE HEAD, NOT STUCK ONTO IT.
	--
	-- The eyes used to be two 1.9 balls centred 2.21 from the head's centre
	-- against a head radius of 2.15 -- so each one sat with its own centre
	-- OUTSIDE the skull and stood a full 1.01 studs proud of it. That is a
	-- googly eye glued to a sphere, and it is why the face read as a mask
	-- with something stuck to it rather than as a face.
	--
	-- Everything here is placed BY DIRECTION from the head's own centre at a
	-- measured distance instead, the same technique the turtle's mottling
	-- uses, so each piece sits in the surface with a chosen amount showing.
	-- The eyes still protrude 0.39 and show a disc 0.762 across on the larger
	-- skull. Their centres sit 1.72 apart against a 1.64 diameter, so the two
	-- whites stay separate by 0.08 -- close-set like the reference, without
	-- merging into one mass.
	local HEAD_C = Vector3.new(0, 15.40, 0)

	-- A ROUNDED CAP, NOT A DISC. The hair was a flat cylinder laid on the
	-- crown with a box fringe in front, which reads as a bowl balanced on the
	-- head. A sphere intersects the skull in a circle, so it covers the crown
	-- and follows it exactly. This one is BIG, sits LOW, and LEANS BACK -- the
	-- lean is what makes the nape lower than the sides, which a straight lift
	-- cannot do. Its own hairline runs 15.40 at the temple, 15.30 at the side
	-- and 15.05 at the back; the forehead is cut off that by a plane. See the
	-- template for why one sphere cannot deliver all three.
	-- Cloned from the template so it carries its notch; a plain ball if the
	-- client asked before the server had built one, because a statue with
	-- uncut hair is a far smaller fault than a bald one.
	local hairCap = dripHairTemplate()
	if hairCap then
		local cap = hairCap:Clone()
		cap.Name = "Hair"
		cap.CFrame = at * CFrame.new(0, 15.75591, -0.03829) * hairCap.CFrame
		cap.Parent = folder
	else
		ball("Hair", 4.78407, at * CFrame.new(0, 15.75591, -0.03829), HAIR, SMOOTH)
	end

	local eyelid = dripEyelidTemplate()
	local outline = dripEyeOutlineTemplate()
	-- The eye direction, and the axis its lid sits on. Both are shared by the
	-- white, the outline shell and the cap, which all hang off the SAME centre
	-- 1.92 out along it.
	local EYE_D = 1.92
	local EYE_U = Vector3.new(0.44792, -0.04688, 0.89284)
	for _, sx in ipairs({ -1, 1 }) do
		local eyeC = Vector3.new(sx * 0.86, 15.31, 1.71426)
		ball("Eye", 1.64, at * CFrame.new(eyeC), WHITE, SMOOTH)

		-- The outline: a bored shell seated on the SAME centre as the white,
		-- with its bore aimed straight out along the eye's direction. See the
		-- template's note -- concentric is what stopped it speckling.
		if outline then
			local u = Vector3.new(sx * EYE_U.X, EYE_U.Y, EYE_U.Z)
			local ring = outline:Clone()
			ring.Name = "EyeOutline"
			ring.CFrame = at
				* CFrame.fromMatrix(eyeC, u, u:Cross(Vector3.new(0, 1, 0)).Unit)
				* outline.CFrame
			ring.Parent = folder
		end
		-- THE PUPIL LOOKS FORWARD, NOT WHERE ITS OWN EYE POINTS.
		--
		-- Set radially, a pupil sits dead centre of the disc it is on -- and
		-- since each eye's disc faces 28.9 degrees OUTWARD on a round head,
		-- two centred pupils read as walleyed. They were worse at 36.5.
		-- Pushing them forward in z instead lands them 18% off the disc
		-- centre toward the nose, which is what "looking at you" looks like.
		-- Still 0.04 proud of the white, never flush: two surfaces at one
		-- depth is the coplanar flicker this file has caught three times.
		ball("Pupil", 0.60, at * CFrame.new(sx * 1.01, 15.284, 2.26986), BLACK, SMOOTH)

		-- The lid: a cap cloned from the template above and SEATED on the
		-- eyeball -- its own space is "eye centre, cap pointing up", so this
		-- is one CFrame and no mirrored geometry. `template.CFrame` has to
		-- ride along because a CSG result keeps its own origin wherever the
		-- subtract left it, which is not where the ball started.
		if eyelid then
			local axis = Vector3.new(sx * LID_AXIS.X, LID_AXIS.Y, LID_AXIS.Z)
			local seat = at
				* CFrame.fromMatrix(eyeC, axis:Cross(Vector3.new(0, 1, 0)).Unit, axis)
			local lid = eyelid:Clone()
			lid.Name = "Eyelid"
			lid.CFrame = seat * eyelid.CFrame
			lid.Parent = folder
		end

		-- THE BROW SITS IN THE BAND THE BIGGER SKULL FREED UP, with skin on
		-- BOTH sides of it: 0.198 down to the eye and 0.232 up to the hairline.
		-- On the old head the whole band was 0.373 and the brow had to crowd
		-- one edge of it.
		--
		-- ITS DEPTH DECIDES WHETHER IT EXISTS. An earlier one seated 0.03
		-- INSIDE the skull showed a 0.06 sliver -- present in the tree,
		-- invisible on the face. These stand 0.130 proud with 0.050 buried,
		-- and clear the hair BALL by 0.15, which is the surface that actually
		-- matters up here: it runs far closer to the forehead than the
		-- hairline circle suggests.
		--
		-- CURVED, in three short segments that ROTATE as well as step. The
		-- mouth already taught this file that stacking segments by height
		-- alone puts a visible staircase in a line; turning each one to follow
		-- the arc is what makes the same trick read as a curve instead. They
		-- overlap by 0.08 at 0.26 spacing, so it is one brow rather than three
		-- dashes.
		--
		-- The arc peaks in the middle and DROPS toward the outer end, which is
		-- the whole expression: lifting it reads as alert or startled, letting
		-- it fall reads as relaxed. Every sign follows `sx`, or the two brows
		-- mirror into a frown instead of matching.
		-- Re-centred in the taller forehead the raised hairline opened up:
		-- 0.24 of skin below the brow and about 0.2 above it, where before
		-- they sat almost on the eye with a 0.45 gap over them. They are
		-- checked against the front cut PLANE rather than against a hairline
		-- height, because the sharp edge is a plane and the only honest
		-- question is which side of it a brow falls on -- all three top
		-- corners land 0.31 to 0.50 into the cut-away region.
		for _, seg in ipairs({
			{ x = 0.62, y = 16.34, z = 2.10810, rot = -3 },
			{ x = 0.88, y = 16.37, z = 1.99920, rot = -8 },
			{ x = 1.14, y = 16.33, z = 1.88351, rot = -14 },
		}) do
			part("Brow", Vector3.new(0.34, 0.15, 0.18),
				at * CFrame.new(sx * seg.x, seg.y, seg.z)
					* CFrame.Angles(0, 0, math.rad(sx * seg.rot)),
				HAIR, SMOOTH)
		end

		-- DROPPED TO CLEAR THE HAIR, which is a consequence of the hairline
		-- rather than a taste call. The side hairline is now 15.28 where the
		-- ear is, and the old ear's top reached 15.70 -- so it was buried,
		-- 0.43 inside a cap that also stands 0.40 proud of the skull. At y
		-- 14.76 its top sits 0.02 under the edge, so the hair passes BEHIND
		-- it and the ear reads against skin. That lands it level with the
		-- nose, which is where an ear belongs anyway.
		ball("Ear", 1.00, at * CFrame.new(sx * 2.09332, 14.76000, -0.22000), SKIN, SMOOTH)
	end

	-- A POINTED NOSE IS A TAPER, AND ONE BALL CANNOT TAPER. It was a single
	-- 0.66 sphere, which is round by definition however it is placed -- the
	-- reference has a nose that narrows to a soft point and turns down.
	--
	-- Four balls shrinking 0.44 -> 0.17 along an axis pointing out and 27
	-- degrees DOWN do taper. The step between them is 0.12 against radii
	-- summing to about 0.4, so consecutive balls overlap several times over
	-- and the chain reads as one cone rather than as beads -- the same
	-- spacing-versus-radius test the turtle's band failed when its beads were
	-- too far apart. It ends 0.289 proud, near enough the 0.30 the round one
	-- had, so the profile changed and the prominence did not.
	--
	-- THE BASE IS SIZED BY THE EYES, not by taste. They sit close in on a
	-- head this size, and a wider base clips the eyeball: at 0.44 it clears
	-- the white by 0.038, and 0.50 does not clear it at all.
	local NOSE_AXIS = Vector3.new(0, -0.45097, 0.89244)
	local noseAt = Vector3.new(0, 14.80, 2.11660)
	for _, seg in ipairs({
		{ dia = 0.44, step = 0.00 },
		{ dia = 0.35, step = 0.12 },
		{ dia = 0.26, step = 0.12 },
		{ dia = 0.17, step = 0.12 },
	}) do
		noseAt += NOSE_AXIS * seg.step
		ball("Nose", seg.dia, at * CFrame.new(noseAt), Color3.fromRGB(226, 178, 142), SMOOTH)
	end
	-- A SMIRK, WHICH IS A LINE THAT DOES NOT END WHERE IT STARTED.
	--
	-- One straight box is a mouth with no opinion in it, and asymmetry is the
	-- whole of a smirk -- a symmetric curve is a smile and a flat bar is a
	-- deadpan. The first attempt built the rise out of three stacked segments,
	-- which is the right idea and the wrong construction: a 0.08 step between
	-- boxes 0.16 tall is HALF THE HEIGHT OF THE LINE, so close up it read as
	-- three offset blocks -- a staircase, not a mouth.
	--
	-- One bar TILTED in the face plane has no steps in it to see. Rotating
	-- about Z is what tilts it, because the face looks down +Z and Z is the
	-- axis coming out of it -- rotating about X or Y would pitch it into the
	-- skull instead. The short tick past its raised end overlaps the bar and
	-- turns up harder, which is the curl that stops it reading as a straight
	-- line drawn on a slant.
	-- SET LOW ON THE FACE: y 14.00 against eyes at 15.22 and the chin at
	-- 13.15, so it sits 59% of the way down from one to the other rather than
	-- crowding the nose. Lowering it is not just a y change -- the face is a
	-- SPHERE, so the surface falls away as you go down it, and z has to come
	-- back with it (1.885 -> 1.692) or the mouth pulls off the chin and hangs
	-- in front of it. Both pieces stay 0.11 proud, the same as before.
	part("Mouth", Vector3.new(1.0, 0.17, 0.26),
		at * CFrame.new(0, 13.98, 1.85030) * CFrame.Angles(0, 0, math.rad(8)),
		Color3.fromRGB(96, 62, 62), SMOOTH)
	part("Mouth", Vector3.new(0.34, 0.16, 0.25),
		at * CFrame.new(0.61, 14.09, 1.83079) * CFrame.Angles(0, 0, math.rad(30)),
		Color3.fromRGB(96, 62, 62), SMOOTH)

	-- THE BAG IS A STADIUM PRISM: a flat-sided box with a rounded cap on each
	-- end. Two earlier shapes were both wrong, in opposite directions.
	--
	-- A BOX with a ball stuck on each end -- the original -- had three flat
	-- faces meeting spheres that matched none of their dimensions, so every
	-- junction was a step and it read as a crate with rounded corners.
	--
	-- A CAPSULE fixed the smoothness and cost the print: a barrel has no flat
	-- side, so the checked canvas had nowhere to lie and was cut down to a
	-- small plate. But the canvas IS the reference -- a designer holdall is
	-- the monogram -- so the shape has to earn it back.
	--
	-- A cylinder whose diameter equals the box's HEIGHT is tangent to that
	-- box's top and bottom, so the two make one stadium with no step at the
	-- join: rounded ends, and a 2.30-wide flat front the canvas lies flat on.
	-- The caps are set 0.02 shallower than the box so their faces sit BEHIND
	-- its front rather than level with it -- two surfaces at one depth is the
	-- coplanar flicker this file has caught three times -- which also leaves
	-- the whole flat face clear for the print. They are LEATHER, which is
	-- what the reference does with its ends, and it makes the join read as
	-- trim rather than as a seam.
	--
	-- SmoothPlastic rather than Fabric: Fabric's weave is a dark noisy texture
	-- that turned the tan into a near-black lump at any distance.
	local BAG_C = Vector3.new(3.0, 5.35, 0.75)
	local BAG_H = 1.8
	local BAG_D = 1.45
	local BAG_BOX = 2.3

	part("Bag", Vector3.new(BAG_BOX, BAG_H, BAG_D), at * CFrame.new(BAG_C), BAG, SMOOTH)
	for _, sx in ipairs({ -1, 1 }) do
		cylinderZ("BagEnd", BAG_D - 0.04, BAG_H,
			at * CFrame.new(BAG_C + Vector3.new(sx * BAG_BOX / 2, 0, 0)),
			STRAP, Enum.Material.Leather)
		-- The handles lean back toward the hand rather than standing straight
		-- up, which is what puts the grip in it.
		part("BagHandle", Vector3.new(0.26, 1.0, 0.3),
			at * CFrame.new(BAG_C + Vector3.new(sx * 0.55, 1.4, -0.25)),
			STRAP, Enum.Material.Leather)
	end
	part("BagGrip", Vector3.new(1.4, 0.26, 0.3),
		at * CFrame.new(BAG_C + Vector3.new(0, 1.85, -0.3)), STRAP, Enum.Material.Leather)
	part("BagZip", Vector3.new(2.2, 0.1, 0.18),
		at * CFrame.new(BAG_C + Vector3.new(0, BAG_H / 2 + 0.03, 0)), GOLD, Enum.Material.Metal)

	-- Both faces. 0.02 proud of the flat front so the print never sits at the
	-- same depth as the panel it is printed on.
	monogram(at * CFrame.new(BAG_C + Vector3.new(0, 0, BAG_D / 2 + 0.02)))
	monogram(at * CFrame.new(BAG_C + Vector3.new(0, 0, -BAG_D / 2 - 0.02))
		* CFrame.Angles(0, math.pi, 0))
end

-- ------------------------------------------------------------
-- BRACE FACE
-- ------------------------------------------------------------
--
-- A GARDEN TURTLE WITH A MOUTHFUL OF ORTHODONTICS.
--
-- The reference was a still of a specific film turtle in a purple mask with
-- braces edited over its grin. Neither half of that is here: the mask is the
-- identifying mark of a registered children's property -- the colour is
-- literally which character it is -- and the still is separately somebody's
-- photograph. That is the same argument the statue's shirt makes two hundred
-- lines up, and it reaches the same place: Roblox strips branded assets and
-- the penalty lands on the EXPERIENCE, not the one ornament.
--
-- What is actually funny about the reference is the BRACES. A tough guy
-- undercut by a dentist is a joke, not a property, and it survives the thing
-- it was attached to. So the mask is gone entirely and the eye band below
-- stands in for it -- a dark natural marking rather than a tied bandana,
-- which is what keeps the identifying colour off the model without needing
-- anything on the skull to replace it. A garden turtle is a real suburban
-- ornament on its own, so this reads as a lawn statue before it reads as a
-- character at all.
--
-- AN EARLIER VERSION ALSO CARRIED ORTHODONTIC HEADGEAR -- a strap-and-bow
-- harness standing in for the bandana a second time. It is gone: the eye
-- band already did that job, so the headgear was solving a problem twice,
-- and everything it added was built from flat boxes laid over the head
-- BALL, which have no curvature to match a sphere's -- their corners sat
-- further from the head's own centre than their faces did, and broke the
-- surface by half a stud on the crown. It read as a pale slab shot through
-- the dome rather than as a strap sitting on it. The grin carries the joke
-- by itself now.
--
-- NO WEAPONS, which is a separate question from the copyright one and would
-- apply even if the mask were free. Roblox's maturity questionnaire is
-- answered by what is literally in the model and this game is for
-- under-twelves -- the same reason the patrol officer carries no baton.

-- The grin, DRAWN rather than built. Twenty teeth, twenty brackets and an
-- archwire is not something studs hold at three studs across, and this is the
-- one detail the whole ornament exists for -- see the note above the statue's
-- prints, which makes the same call for the same reason.
-- SIZED BY THE CALLER, because the muzzle it sits on is the thing that
-- decides how wide a grin is. Hard-coded at 3.4 x 1.5 it survived a rebuild
-- that took the muzzle down to 2.9 and promptly overhung it on both sides,
-- reading as a white box hung in front of the face instead of a mouth.
local function braces(cf: CFrame, width: number, height: number)
	local gui = panel("BracePrint", width, height, cf,
		math.floor(width * 100), math.floor(height * 100))

	-- GUMS ABOVE THE TEETH, which is most of what makes the reference read as
	-- a grin rather than as a grille. The mouth field is gum rather than a
	-- dark throat, and the tooth rows are pushed DOWN the panel so a wide pink
	-- band sits over the top row.
	local mouth = Instance.new("Frame")
	mouth.Size = UDim2.fromScale(1, 1)
	mouth.BackgroundColor3 = Color3.fromRGB(198, 112, 122)
	mouth.BorderSizePixel = 0
	mouth.Parent = gui
	local mc = Instance.new("UICorner")
	mc.CornerRadius = UDim.new(0.5, 0)
	mc.Parent = mouth

	-- Two rows, because a single row of teeth reads as a grille. The gap
	-- between them is the mouth line and is what makes it a grin.
	-- 0.24 of the panel is gum before the first tooth starts, against 0.08
	-- before. The lower row keeps a thinner band under it, the way a mouth
	-- actually looks.
	for row, top in ipairs({ 0.30, 0.64 }) do
		for i = 0, 7 do
			local tooth = Instance.new("Frame")
			tooth.Size = UDim2.fromScale(0.113, 0.30)
			tooth.Position = UDim2.fromScale(0.028 + i * 0.121, top)
			tooth.BackgroundColor3 = Color3.fromRGB(246, 244, 232)
			tooth.BorderSizePixel = 0
			tooth.Parent = mouth
			local tc = Instance.new("UICorner")
			tc.CornerRadius = UDim.new(0.22, 0)
			tc.Parent = tooth

			-- A bracket on every tooth, and the wire threaded through them.
			local bracket = Instance.new("Frame")
			bracket.Size = UDim2.fromScale(0.46, 0.3)
			bracket.Position = UDim2.fromScale(0.27, if row == 1 then 0.5 else 0.2)
			bracket.BackgroundColor3 = Color3.fromRGB(168, 174, 186)
			bracket.BorderSizePixel = 0
			bracket.Parent = tooth
		end

		local wire = Instance.new("Frame")
		wire.Size = UDim2.fromScale(0.95, 0.035)
		wire.Position = UDim2.fromScale(0.025, top + (if row == 1 then 0.185 else 0.085))
		wire.BackgroundColor3 = Color3.fromRGB(198, 204, 214)
		wire.BorderSizePixel = 0
		wire.Parent = mouth
	end
end

-- ------------------------------------------------------------
-- THE HEADBAND, BUILT WITH RUNTIME CSG
-- ------------------------------------------------------------
--
-- Two cheaper attempts came before this one, and both failed in ways worth
-- keeping on record.
--
-- BALLS, overlapping but never unioned, read as a strand of pearls rather
-- than as anything worn -- each one keeps its own round shading and its own
-- seam against its neighbours, and cloth has neither.
--
-- FLAT PANELS, tangent to the head at their own point and tiled edge to
-- edge across a real height, looked right from straight on and fell apart
-- from everywhere else. Two panels tangent at DIFFERENT points on a sphere
-- are not coplanar, so what looks like overlap from one angle is a
-- roof-ridge from the side -- the true 3D surfaces only touch along one
-- line and diverge either side of it. Measured on the shipped version: a
-- clean front elevation and a lattice of visible gaps from any oblique one,
-- exactly the "greenhouse pane" look this replaces.
--
-- CSG is the only thing in this engine that produces an actual continuous
-- surface rather than an arrangement of parts that merely look continuous
-- from one direction. This is a real union: a thin hollow shell, cut down to
-- a band of LATITUDE by two subtracts (`A minus (A minus KEEP)` is
-- `A intersect KEEP`, which is the only way to get an intersection out of an
-- API that only offers union and subtract), then two round eye holes cut the
-- same way PlayerGear's mask cuts its own eye slot.
--
-- Server-only and template-cached like every CSG shape here; see the shared
-- scaffolding note above the builders.
--
-- The head this is cut against: a 3.8-diameter ball centred at (0, 4.5, 3.1)
-- in the statue's own local space -- the same numbers `builders.bracestatue`
-- itself builds the head from, since the two have to agree on where the
-- skull actually is.
local BAND_HEAD_CENTER = Vector3.new(0, 4.5, 3.1)
local BAND_HEAD_R = 1.9

-- THE BAND SITS BEHIND THE EYES, WHICH IS WHY IT HAS NO EYE HOLES CUT IN IT.
--
-- Measured: an eyeball's centre is 1.701 from the head's centre and its own
-- radius is 0.55, so it reaches 2.251 -- a full 0.35 PROUD of the 1.9 skull.
-- A band at 1.97 therefore passes behind them and the eyes push through it on
-- their own, with no hole to cut and no rim to bevel.
--
-- Cutting holes was the first version and it was the wrong instinct twice
-- over: a sphere cutter through a curved shell leaves a thick rounded rim, so
-- the eyes read as sunk into a bulky mask rather than bulging out of a strip
-- of cloth -- and the holes had to be big enough to clear a 0.55 eyeball,
-- which on a band this tall meant they broke through its bottom edge anyway.
local BAND_R = 1.97

-- WHERE THE BAND STOPS, TOP AND BOTTOM, and both are measured against
-- something rather than chosen.
--
-- The bottom clears the SNOUT. The muzzle's top face is at y 4.750 and the
-- grin panel's top edge at 4.625, and a band that dips below either one cuts
-- across the face: the version that did produced a dark spike hanging down
-- between the eyes over the teeth, which is the "clipping with the head" this
-- fixes. 4.80 clears the muzzle by 0.05 and the grin by 0.175.
--
-- The top stops well short of the crown, which is at y 6.400 -- this is a
-- band across the eyes, never a cap. The eyes themselves span y 4.450 to
-- 5.550, so the strip covers them from just below their centre to 0.35 above
-- their top, and their lower third bulges out under its bottom edge.
local BAND_Y_LOW = 4.80
local BAND_Y_HIGH = 5.90
local BAND_COLOR = Color3.fromRGB(54, 68, 46)
-- The muzzle, shared with `builders.bracestatue` so the snout and the
-- clearance measured against it above cannot drift apart.
local MUZZLE_SIZE = Vector3.new(2.9, 1.5, 1.4)
local MUZZLE_CENTER = Vector3.new(0, 4.0, 4.3)

local function braceFaceBandTemplate(): BasePart?
	local folder = decorTemplateFolder()
	if folder then
		local ready = folder:FindFirstChild("bracestatueBand")
			or (if RunService:IsServer() then nil else folder:WaitForChild("bracestatueBand", 10))
		if ready and ready:IsA("BasePart") then
			decorTemplates.bracestatueBand = ready
			return ready
		end
	end
	if not RunService:IsServer() then
		return nil
	end

	local cached = decorTemplates.bracestatueBand
	if cached then
		return cached
	end

	local scratch = Instance.new("Folder")
	scratch.Parent = workspace

	-- A SOLID ZONE OF A SPHERE: one ball, with everything above and below the
	-- band sliced off by two boxes. That is the whole shape.
	--
	-- The version before this built a hollow SHELL and then intersected it
	-- with a slab, which needed the `A minus (A minus KEEP)` trick because
	-- Roblox offers no intersect -- three CSG passes to get a shape two
	-- subtracts produce directly. It was also worse geometry: a shell has an
	-- inner surface as well as an outer one, so every cut edge came out
	-- doubled and thick. This is solid, so an edge is just an edge, and the
	-- head it covers is inside it and never seen.
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(BAND_R * 2, BAND_R * 2, BAND_R * 2)
	ball.CFrame = CFrame.new(BAND_HEAD_CENTER)
	ball.Anchored = true
	ball.Parent = scratch

	local function slice(centreY: number, height: number): BasePart
		local box = Instance.new("Part")
		box.Size = Vector3.new(12, height, 12)
		box.CFrame = CFrame.new(BAND_HEAD_CENTER.X, centreY, BAND_HEAD_CENTER.Z)
		box.Anchored = true
		box.Parent = scratch
		return box
	end

	local above = slice(BAND_Y_HIGH + 6, 12)
	local below = slice(BAND_Y_LOW - 6, 12)

	local ok, band = pcall(function()
		return ball:SubtractAsync({ above, below })
	end)
	if not ok or not band then
		scratch:Destroy()
		warn(("[Decor] SubtractAsync failed for the Brace Face band: %s"):format(tostring(band)))
		return nil
	end

	-- `RenderFidelity` IS NOT WRITABLE FROM A GAME SCRIPT, and reaching for
	-- it took the whole server down.
	--
	-- A UnionOperation is a real MESH rather than the smooth-shaded primitive
	-- a `Ball` is, and on the default `Automatic` fidelity Roblox renders a
	-- decimated copy of it that sheds triangles with distance -- so setting
	-- `Precise` looks like exactly the right fix for a CSG shape that has to
	-- read as curved. It is plugin-security only: a plain assignment throws
	-- "The current thread cannot write 'RenderFidelity' (lacking capability
	-- Plugin)". It threw OUTSIDE the pcall around the subtract, so it took
	-- `Decor.prewarm` with it, then `PlotService.start`, then the whole of
	-- `Main` -- twelve plots and every service after it, gone, from one
	-- property write.
	--
	-- It also passes when tested from Studio's own command bar or an MCP
	-- sandbox, which run WITH plugin capability. That is the trap: the thing
	-- that proves it works is the one context that is not the game.
	--
	-- So the geometry carries the smoothness instead. This is a ball cut by
	-- two planes and nothing else -- the simplest solid there is to
	-- tessellate, and far simpler than the hollow shell with sphere-cut eye
	-- holes it replaced, which is what actually looked polygonal.
	--
	-- One colour for the whole solid. Without UsePartColor a union keeps
	-- whatever its source parts were, which here is plain grey.
	band.UsePartColor = true
	band.Color = BAND_COLOR
	band.Material = SMOOTH
	band.Name = "bracestatueBand"
	band.Anchored = true
	band.CanCollide = false
	band.CanQuery = false
	band.CastShadow = false

	scratch:Destroy()

	local dest = decorTemplateFolder()
	if dest then
		band.Parent = dest
	end
	decorTemplates.bracestatueBand = band
	return band
end

builders.bracestatue = function(item, at)
	local SHELL = Color3.fromRGB(126, 96, 50)
	local SHELL_DARK = Color3.fromRGB(92, 68, 34)
	local HIDE = Color3.fromRGB(126, 162, 76)
	local HIDE_DARK = Color3.fromRGB(96, 128, 56)
	local HIDE_SPOT = Color3.fromRGB(86, 114, 48)
	-- THE EYE BAND IS THE TURTLE'S OWN MARKING, not a tied cloth one.
	--
	-- A band across the eyes with the eyes showing through is a real reptile
	-- face and belongs to nobody. A COLOURED bandana on a green turtle is a
	-- different object: the colour is the thing that says which of the four
	-- brothers this is, which is exactly the identifying mark that could not
	-- be here. So this is dark and desaturated -- the same family as the
	-- mottling above it -- and reads as an animal rather than as a costume.
	-- Its own colour is `BAND_COLOR`, next to the CSG builder that uses it,
	-- rather than a second local here that could drift from it.
	local AMBER = Color3.fromRGB(238, 196, 92)

	-- THE SHELL IS THE BODY, AND THAT IS WHAT MAKES IT A TURTLE.
	--
	-- The first version was a bust: a head the same size as the mass under it,
	-- which rendered as a green lump with teeth. A turtle reads from two
	-- things and neither is the face -- a WIDE LOW DOME, and a head that comes
	-- out of the FRONT of it rather than sitting on top. So the dome is 6.4
	-- across and 2.1 tall, and the head is 3.6 hung off the front at z 3.
	--
	-- Stacked discs rather than a ball: a Roblox sphere is as tall as it is
	-- wide, and a shell that tall is a boulder. Same trick the gnome's hat
	-- uses, and nobody sees a lawn ornament from closer than the pavement.
	part("Plinth", Vector3.new(6.0, 1.5, 5.6), at * CFrame.new(0, 0.75, 0),
		Color3.fromRGB(170, 168, 160), Enum.Material.Slate)
	part("PlinthCap", Vector3.new(5.2, 0.4, 4.9), at * CFrame.new(0, 1.7, 0),
		Color3.fromRGB(200, 198, 190), Enum.Material.Marble)

	-- The rim proud of the dome on every side, which is what a shell's edge
	-- does and what stops the stack reading as a pile of plates.
	cylinderY("ShellRim", 0.55, 6.6, at * CFrame.new(0, 2.15, 0), SHELL_DARK, SMOOTH)
	for _, disc in ipairs({
		{ y = 2.6, d = 6.2 }, { y = 3.1, d = 5.5 },
		{ y = 3.5, d = 4.4 }, { y = 3.8, d = 2.9 },
	}) do
		cylinderY("ShellDome", 0.62, disc.d, at * CFrame.new(0, disc.y, 0), SHELL, SMOOTH)
	end
	-- Scutes, sunk into the dome's own surface so the shell has a pattern
	-- rather than a texture. Without them the dome is a brown hill.
	for _, sc in ipairs({
		{ x = 0, z = 0, y = 4.05, d = 1.9 },
		{ x = -1.7, z = 0.9, y = 3.5, d = 1.7 }, { x = 1.7, z = 0.9, y = 3.5, d = 1.7 },
		{ x = -1.7, z = -1.1, y = 3.5, d = 1.7 }, { x = 1.7, z = -1.1, y = 3.5, d = 1.7 },
		{ x = 0, z = -2.0, y = 3.3, d = 1.7 },
	}) do
		cylinderY("Scute", 0.16, sc.d, at * CFrame.new(sc.x, sc.y, sc.z), SHELL_DARK, SMOOTH)
	end

	-- Four stubby legs. A shell on a plinth with nothing under it is an
	-- upturned bowl; the legs are what say animal.
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			cylinderY("Leg", 1.0, 1.4, at * CFrame.new(sx * 2.1, 2.0, sz * 1.7), HIDE_DARK, SMOOTH)
		end
	end
	part("Tail", Vector3.new(0.5, 0.5, 1.2), at * CFrame.new(0, 2.5, -3.3), HIDE_DARK, SMOOTH)

	-- The head, OUT OF THE FRONT of the shell on a wrinkled neck.
	cylinderY("Neck", 1.6, 1.9, at * CFrame.new(0, 3.15, 2.1) * CFrame.Angles(math.rad(62), 0, 0),
		HIDE_DARK, SMOOTH)
	ball("Head", 3.8, at * CFrame.new(0, 4.5, 3.1), HIDE, SMOOTH)

	-- The muzzle carries the grin, and the print goes on ITS face rather than
	-- floating against the skull: a flat panel wide enough for eight teeth has
	-- its corners a stud clear of a sphere that curves away from it.
	-- Sized and placed from the same two constants the band's lower edge is
	-- measured against, so the snout and the clearance over it cannot drift.
	part("Muzzle", MUZZLE_SIZE, at * CFrame.new(MUZZLE_CENTER), HIDE, SMOOTH)
	-- THE HEADBAND. See `braceFaceBandTemplate` above for why this is a
	-- clone of a CSG solid rather than geometry assembled inline like
	-- everything else in this builder -- two cheaper attempts (overlapping
	-- balls, then tangent flat panels) both failed to read as cloth.
	local band = braceFaceBandTemplate()
	if band then
		local clone = band:Clone()
		clone.Name = "Band"
		clone.CFrame = at * band.CFrame
		clone.Parent = folder
	end

	-- Mottling, placed ON the sphere BY DIRECTION so every spot sits half sunk
	-- into the surface. Positioned by hand they float, and a spot floating a
	-- tenth of a stud off a curved surface reads as a bug rather than as a
	-- marking. Kept off the front, where the band and the eyes already are.
	for _, dir in ipairs({
		Vector3.new(-0.55, 0.72, 0.42), Vector3.new(0.62, 0.66, 0.42),
		Vector3.new(-0.90, 0.20, 0.38), Vector3.new(0.88, 0.30, 0.36),
		Vector3.new(0.05, 0.95, -0.30), Vector3.new(-0.40, 0.55, -0.73),
		Vector3.new(0.45, 0.48, -0.75),
	}) do
		ball("Spot", 0.62, at * CFrame.new(Vector3.new(0, 4.5, 3.1) + dir.Unit * 1.72),
			HIDE_SPOT, SMOOTH)
	end
	-- Proud of the muzzle face at 5.0, never flush with it: two surfaces at
	-- one depth is the flicker this file has caught three times.
	braces(at * CFrame.new(0, 3.95, 5.06), 2.75, 1.35)

	for _, sx in ipairs({ -1, 1 }) do
		ball("Eye", 1.1, at * CFrame.new(sx * 0.95, 5.0, 4.42), AMBER, SMOOTH)
		ball("Pupil", 0.5, at * CFrame.new(sx * 0.95, 5.0, 4.86), BLACK, SMOOTH)
		ball("Nostril", 0.24, at * CFrame.new(sx * 0.42, 4.62, 5.02), HIDE_DARK, SMOOTH)
	end

	-- NO HEADGEAR. It was orthodontic strap-and-bow geometry standing in for
	-- the reference's bandana -- see the note above the eye band, which is
	-- the piece that actually carries that job now. A dark band across the
	-- eyes already reads as the turtle's own marking rather than as a tied
	-- costume, so the strap harness was doubling up on a problem the band
	-- had already solved, and it is gone by request rather than repaired:
	-- the grin is the joke, on its own.
end

-- ============================================================
-- BUILD
-- ============================================================

-- Called once by the server at startup. Without it the first Brace Face ever
-- bought builds its CSG band inside whichever request needed it first -- a
-- purchase, or a join reconstructing a saved lawn -- and CSG yields.
function Decor.prewarm()
	if not RunService:IsServer() then
		return
	end
	-- PCALLED, BECAUSE A LAWN ORNAMENT MUST NEVER BE ABLE TO STOP THE SERVER
	-- STARTING. This is called from `PlotService.start`, which `Main` calls
	-- in sequence with every other service -- so anything that throws in here
	-- takes the plots, the economy and the whole game down with it. That is
	-- not hypothetical: a single unguarded `RenderFidelity` write did exactly
	-- that, and the console showed the build line, this stack, and then
	-- nothing -- no "Ready", no twelve plots, no services.
	--
	-- A statue that loses its headband is a cosmetic fault in one ornament.
	-- Losing the server is not, and the two should never be able to trade.
	for name, build in pairs({
		["Brace Face band"] = braceFaceBandTemplate,
		["drip statue eyelid"] = dripEyelidTemplate,
		["drip statue hair"] = dripHairTemplate,
		["drip statue eye outline"] = dripEyeOutlineTemplate,
	}) do
		local ok, err = pcall(build)
		if not ok then
			warn(("[Decor] prewarm failed, the %s will be missing: %s")
				:format(name, tostring(err)))
		end
	end
end

-- THE PUBLIC WHEELIE BIN, which is street furniture rather than a decoration
-- and therefore has no DECOR_ITEMS entry to look up.
--
-- buildOne() resolves a key through the catalogue, so it went on returning nil
-- the moment the purchasable Wheelie Bins were retired -- and returning nil is
-- exactly how the bins would have quietly stopped spawning with nothing in the
-- log to say so. This reaches the builder directly, which is honest about what
-- it is: shared geometry, not a shared item.
function Decor.buildStreetBin(at: CFrame, parent: Instance): Model?
	local build = builders.bins
	if not build then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Prop_bins"
	folder = model
	build({}, at)
	model.Parent = parent
	return model
end

-- One catalogue ornament, standing where you put it, outside the slot system
-- entirely. The shop's 3D tiles render through here, which is why this lives
-- in Shared rather than in a service.
-- ALIEN SET. The SAME builder the raid uses, tipped onto its side and left
-- smoking -- so the ornament on the lawn is literally the thing that was on
-- your piggy bank, and a trophy cannot drift from what it commemorates. A
-- second hand-built lookalike would be the copy that stops matching the first
-- time either is touched, which is the argument `Decor.buildOne` already
-- makes about the disguise's wheelie bin.
--
-- Built untagged: see AlienModel.buildDrone. A tagged one would be a
-- throwable target sitting on a lawn.
builders.crashedDrone = function(item, at)
	local drone = AlienModel.buildDrone(at, folder, false)

	-- Tipped 62 degrees and dropped so the hull rests in the grass rather than
	-- hovering at patrol height. Pivoted about the model rather than moving
	-- pieces, so the legs and the eye keep their relative geometry.
	drone.model:PivotTo(at * CFrame.new(0, 0.9, 0) * CFrame.Angles(math.rad(62), math.rad(24), 0))

	-- Reparented out of its own Model and into the decoration folder, because
	-- `Decor.build` places one flat set of parts and `Decor.buildOne` returns
	-- one Model. A nested Model would survive but would not be moved by the
	-- slot placement that follows.
	for _, child in ipairs(drone.model:GetChildren()) do
		child.Parent = folder
	end
	drone.model:Destroy()

	-- A scorch mark under it, and smoke. The scorch is what makes it read as
	-- CRASHED rather than as a ball somebody left on the grass.
	local scorch = part("Scorch", Vector3.new(0.12, 5.4, 5.4), at * CFrame.new(0, 0.06, 0)
		* CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(38, 34, 30), Enum.Material.Slate)
	scorch.Shape = Enum.PartType.Cylinder

	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(96, 104, 112), Color3.fromRGB(48, 52, 58))
	smoke.Size = NumberSequence.new(0.8, 3.2)
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Lifetime = NumberRange.new(1.6, 2.6)
	smoke.Rate = 9
	smoke.Speed = NumberRange.new(1.5, 3)
	smoke.SpreadAngle = Vector2.new(14, 14)
	smoke.Acceleration = Vector3.new(0.6, 2.4, 0)
	smoke.Parent = scorch
end

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
