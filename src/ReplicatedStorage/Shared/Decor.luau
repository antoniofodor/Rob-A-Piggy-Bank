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
-- THE VICTIM SHELF STANDS REAL PIGGIES, BUILT BY THE FUNCTION THAT
-- BUILDS THE ONE A THIEF CARRIES HOME.
--
-- Same argument as everything else in this file being shared: the shop
-- shows the REAL item. A second, smaller pig authored for a shelf would
-- drift from the carried one the first time either was touched, and the
-- whole point of the trophy is that it is recognisably somebody's
-- property -- the same object, at the same size, in their own skin.
--
-- No cycle: PiggyModel requires Config and nothing else.
local PiggyModel = require(ReplicatedStorage.Shared.PiggyModel)

local Decor = {}

-- How the server finds a trampoline mat. A TAG rather than a name walk,
-- because a plot's decor is rebuilt whenever an owner buys or puts away an
-- ornament, so there is no one moment at which a list could be collected --
-- the same reason the moat's bands are found by tag.
Decor.TRAMPOLINE_TAG = "TrampolineMat"
local TRAMPOLINE_TAG = Decor.TRAMPOLINE_TAG

local folder: Model

-- WHOSE SKIN THE TOPIARY IS CLIPPED IN.
--
-- Held as an upvalue beside `trophyState` rather than passed to each builder,
-- for the reason that one is: `builders` is a table of `(item, at)` functions
-- and widening that signature would touch all forty of them to serve one.
--
-- It is the KEY and not the colours, so this module reads `Config.SKINS`
-- itself. A caller passing two Color3s would be a second description of what
-- a skin is, and the day a skin grows a field -- which is exactly what
-- happened to the metal ones this week -- the copy is the one that does not
-- get it.
local skinKey: string = ""

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

-- THE TOPIARY IS CLIPPED IN ITS OWNER'S SKIN, AND IT TAKES THE COLOUR
-- WITHOUT THE MATERIAL.
--
-- `docs/MASTER-PLAN.md` asks for this as a near-free tie between two systems
-- that do not otherwise know about each other: a skin is bought, worn on a
-- pig behind a fence, and seen by almost nobody. A hedge cut into the same
-- shape is a second advertisement for it, on the one object on the lawn that
-- is already a pig.
--
-- WHAT IT MUST NOT TAKE IS THE MATERIAL, AND THAT IS THE WHOLE OF THE
-- DIFFERENCE BETWEEN A TOPIARY AND A STATUE. `Enum.Material.Grass` is what
-- says PLANT here; the colour is what says whose plant it is. Take both and
-- a Solid Gold topiary is a gold pig standing on a lawn -- which is a
-- perfectly good ornament and is not the one that was bought, and which would
-- quietly make this the only lawn object that renders a cosmetic at full
-- fidelity. Take the colour only and it stays a hedge with a colour, which is
-- what a clipped ornamental actually is.
--
-- IT ALSO DOES NOT TAKE `reflectance`, AND THAT IS THE SAME DECISION RATHER
-- THAN AN OVERSIGHT. The three metal skins carry one so the pig can be shiny;
-- a shiny hedge is a contradiction, and the flatness is the tell that this is
-- a plant rather than a second pig. Anything added to a skin that describes
-- its SURFACE belongs on the animal and not on the shrubbery -- which is the
-- test to apply to the next field, rather than wiring each one up as it
-- lands.
--
-- AN ANIMATED SKIN IS SAMPLED, NEVER DRIVEN. The client animator paints the
-- twenty-three cycling skins per frame and this deliberately does not join
-- it: a topiary that pulsed would be a second light show on a lawn that
-- already has the pig doing it, and the two out of phase would read as a
-- fault rather than as a set. It takes the palette's first colour, which is
-- where every one of those cycles starts.
builders.topiary = function(item, at)
	local skin = Config.SKINS[skinKey]
	local LEAF = Color3.fromRGB(84, 138, 72)
	local TRIM = LEAF
	if skin then
		-- A cycling skin has no single body colour, so take the first stop of
		-- its own palette rather than whatever `body` happens to hold -- on
		-- several of them that field is a base the animation never shows.
		local body = skin.body
		if skin.anim and type(skin.anim.palette) == "table" and skin.anim.palette[1] then
			body = skin.anim.palette[1]
		end
		-- Pulled toward the leaf rather than used raw. A hedge lit by the
		-- 14:30 sun is a MUTED version of whatever it is made of, and the pale
		-- skins otherwise produce a white bush that reads as dead rather than
		-- as clipped. It is a lerp and not a clamp so the darker skins keep
		-- their depth.
		LEAF = body:Lerp(Color3.fromRGB(84, 138, 72), 0.34)
		TRIM = (skin.trim or body):Lerp(Color3.fromRGB(68, 116, 58), 0.34)
	end
	part("Pot", Vector3.new(3.4, 1.6, 3.4), at * CFrame.new(0, 0.8, 0),
		Color3.fromRGB(158, 108, 82), Enum.Material.Slate)

	-- A pig, in hedge form: body, snout, ears, four stubby legs.
	ball("Body", 4.4, at * CFrame.new(0, 4.2, 0), LEAF, Enum.Material.Grass)
	-- The trim tone on the same parts the real pig wears it on, so a two-tone
	-- skin reads as two-tone here too rather than flattening to one green.
	ball("Snout", 1.5, at * CFrame.new(0, 3.9, 2.1), TRIM, Enum.Material.Grass)
	for _, side in ipairs({ -1, 1 }) do
		part("Ear", Vector3.new(0.9, 1.1, 0.5), at * CFrame.new(side * 1.1, 6, 1.2), TRIM, Enum.Material.Grass)
		for _, front in ipairs({ 1.2, -1.2 }) do
			part("Leg", Vector3.new(0.8, 1.6, 0.8), at * CFrame.new(side * 1.2, 2.2, front), TRIM, Enum.Material.Grass)
		end
	end
	ball("Tail", 0.7, at * CFrame.new(0, 4.6, -2.3), TRIM, Enum.Material.Grass)
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

-- A PUBLIC LITTER BIN, AND IT USED TO BE TWO HOUSEHOLD WHEELIE BINS.
--
-- The pair was wrong for where it stands. These sit on the VERGE, beside the
-- lamp posts, on ground that belongs to no plot -- and two domestic wheelie
-- bins parked in the middle of it read as somebody's bin day rather than as
-- street furniture, which is exactly how it was reported. A council bin on a
-- pavement is a thing nobody has to explain.
--
-- ONE BIN RATHER THAN TWO also settles a smaller oddity: only one of the pair
-- was ever hideable (the prompt hangs off a single `Hatch` that
-- NeighborhoodService seats on the prop's own centre line), so the second bin
-- was scenery that looked identical to the one thing on the street a thief
-- can climb into.
--
-- ROUND, ON A PLINTH, WITH A DOMED LID. A cylinder's own axis is X, so every
-- piece here is sized (LENGTH, diameter, diameter) and stood up with a
-- quarter turn about Z -- the mistake this project has now made five times
-- and which `cylinderY` exists to avoid making again.
--
-- The LID keeps its name and its shape: `StealthService` walks the model for
-- parts called "Lid" and hinges each one about its own local -Z edge, so a
-- disc tips open at the front exactly as the old flat lid did.
builders.bins = function(item, at)
	local BODY = Color3.fromRGB(58, 84, 66)
	local METAL = Color3.fromRGB(96, 102, 104)
	local DARK = Color3.fromRGB(34, 36, 38)

	-- The foot, wider than the body so the bin reads as standing on the
	-- pavement rather than growing out of it.
	cylinderY("BinFoot", 0.45, 2.9, at * CFrame.new(0, 0.22, 0), DARK, Enum.Material.SmoothPlastic)
	cylinderY("Bin", 3.0, 2.6, at * CFrame.new(0, 1.9, 0), BODY, Enum.Material.SmoothPlastic)
	-- Two hoops, 0.06 proud of the body: flush they would be a coplanar pair,
	-- and on a curved surface the only way to be seen at all is to stand off
	-- it. Same rule the squeaky ball's stripe followed.
	for _, y in ipairs({ 1.0, 2.7 }) do
		cylinderY("BinHoop", 0.22, 2.72, at * CFrame.new(0, y, 0), METAL, Enum.Material.SmoothPlastic)
	end
	-- The mouth: a dark ring under the lid, so the lid reads as a lid rather
	-- than as the top of the body.
	cylinderY("BinMouth", 0.3, 2.5, at * CFrame.new(0, 3.42, 0), DARK, Enum.Material.SmoothPlastic)
	part("Lid", Vector3.new(2.9, 0.3, 2.9), at * CFrame.new(0, 3.68, 0), METAL, Enum.Material.SmoothPlastic)
	ball("LidKnob", 0.5, at * CFrame.new(0, 3.9, 0), METAL, Enum.Material.SmoothPlastic)
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

-- One hollow oval link, cached for every resident. Alternating link planes
-- interlock around the neck; the pendant hangs from its own connecting bail.
local function dripChainTemplate(): BasePart?
	local dest = decorTemplateFolder()
	if not dest then return nil end
	local ready = dest:FindFirstChild("dripChainLink")
		or (if RunService:IsServer() then nil else dest:WaitForChild("dripChainLink", 10))
	if ready and ready:IsA("BasePart") then return ready end
	if not RunService:IsServer() then return nil end
	local scratch = Instance.new("Folder")
	scratch.Parent = workspace
	local outer = Instance.new("Part")
	outer.Shape = Enum.PartType.Ball
	-- Boolean a full-sized round ring, then squash the result into an oval.
	-- Roblox CSG can erase a small nonuniform Ball before subtracting its bore.
	outer.Size = Vector3.new(4, 4, 4)
	outer.Anchored = true
	outer.CFrame = CFrame.new()
	outer.Parent = scratch
	local bore = Instance.new("Part")
	bore.Shape = Enum.PartType.Cylinder
	bore.Size = Vector3.new(8, 2.5, 2.5)
	bore.CFrame = CFrame.Angles(0, math.pi / 2, 0)
	bore.Anchored = true
	bore.Parent = scratch
	local ok, link = pcall(function() return outer:SubtractAsync({bore}) end)
	scratch:Destroy()
	if not ok or not link then
		warn("[Decor] Could not build resident chain link: " .. tostring(link))
		return nil
	end
	link.Name = "dripChainLink"
	link.Size = Vector3.new(0.34, 0.56, 0.15)
	link.UsePartColor = true
	link.Color = GOLD
	link.Material = Enum.Material.Metal
	link.Anchored = true
	link.CanCollide = false
	link.CanQuery = false
	link.CanTouch = false
	link.CastShadow = false
	link.Parent = dest
	return link
end

local function dripNecklace(at: CFrame)
	local template = dripChainTemplate()
	local function linkAt(cf: CFrame, name: string)
		if not template then return end
		local link = template:Clone()
		link.Name = name
		link.CFrame = at * cf * template.CFrame
		link.Parent = folder
	end
	local function point(t: number): Vector3
		-- Keep the shoulder offset on BOTH halves of the loop. Restricting it
		-- to cos(t) > 0 jumps 0.6 studs at each side and breaks the necklace.
		return Vector3.new(1.52 * math.sin(t), 12.92 - 0.77 * math.max(0, math.cos(t)) ^ 1.8,
			0.15 + 1.16 * math.cos(t) + 0.60 * math.sin(t) ^ 2)
	end
	for i = 0, 31 do
		local t = i * math.pi * 2 / 32
		local tangent = (point(t + 0.001) - point(t - 0.001)).Unit
		local outward = Vector3.new(math.sin(t), 0, math.cos(t))
		local right = tangent:Cross(outward).Unit
		linkAt(CFrame.fromMatrix(point(t), right, tangent)
			* CFrame.Angles(0, if i % 2 == 0 then 0 else math.rad(65), 0), "ChainLink")
	end
	linkAt(CFrame.new(0, 11.99, 1.40) * CFrame.Angles(0, math.rad(65), 0), "PendantBail")
	cylinderZ("Pendant", 0.18, 1.05, at * CFrame.new(0, 11.57, 1.40), GOLD, Enum.Material.Metal)
	cylinderZ("PendantFace", 0.04, 0.85, at * CFrame.new(0, 11.57, 1.51),
		Color3.fromRGB(196, 133, 31), Enum.Material.Metal)
	local seal = ball("PendantSnout", 1, at * CFrame.new(0, 11.57, 1.56), GOLD, Enum.Material.Metal)
	seal.Size = Vector3.new(0.53, 0.34, 0.12)
	for _, x in ipairs({-0.105, 0.105}) do
		local nostril = ball("PendantNostril", 1, at * CFrame.new(x, 11.57, 1.619),
			Color3.fromRGB(109, 68, 21), Enum.Material.Metal)
		nostril.Size = Vector3.new(0.075, 0.14, 0.025)
	end
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

	dripNecklace(at)

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

	-- A POINTED NOSE IS A TAPER, AND NO PRIMITIVE IN THIS ENGINE TAPERS.
	--
	-- It was one 0.66 sphere, which is a bump; then it was FOUR balls
	-- shrinking 0.44 -> 0.17 along an axis pointing out and 27 degrees DOWN,
	-- which does taper and which reads -- close up and on every resident on
	-- the street -- as a stack of RINGS. That is not a spacing problem and it
	-- cannot be tuned away, which is the useful half of this entry.
	--
	-- WHY: consecutive spheres in that chain meet at a 33-degree NORMAL
	-- BREAK. Each ball is separately smooth-shaded, so where one emerges from
	-- the last there is a hard lighting seam -- and the eye reads a shading
	-- discontinuity far more strongly than the 2% groove in the geometry that
	-- causes it.
	--
	-- AND MORE BEADS MAKES IT WORSE, WHICH IS THE OPPOSITE OF WHAT THE
	-- ARITHMETIC PREDICTS. Eleven balls on the identical cone halves every
	-- individual break and renders as CORDUROY: a repeating fine crease reads
	-- as a texture, where three coarse ones read as three rings. Photographed
	-- side by side against four and against this, because the calculation
	-- said "smoother" and the picture said otherwise.
	--
	-- A PROLATE SPHEROID IS THE ONE SHAPE THAT IS BOTH TAPERED AND SEAMLESS,
	-- and `SpecialMesh` is how you get one without CSG: `MeshType.Sphere`
	-- takes a NON-UNIFORM `Scale`, where a Ball part silently ignores one --
	-- this file already records that three balls sized (6,6,6), (12,6,6) and
	-- (6,12,6) render pixel-identical. One part, no union, no server-only
	-- template to prewarm and clone, and no seam anywhere on it because there
	-- is only one surface.
	--
	-- SEATED TO REPRODUCE THE OLD PLACEMENT EXACTLY: centred on the chain's
	-- own start point with a half-length of 0.45 along the same axis, which
	-- puts the tip 0.293 proud of the skull against the chain's 0.289. The
	-- profile changed and the prominence did not, twice now.
	--
	-- THE WIDTH IS STILL SIZED BY THE EYES, and measuring it correctly
	-- reversed the answer. Sampling the WHOLE eyeball says this nose intrudes
	-- 0.012 into the white -- against the old chain's +0.038 of clearance --
	-- which reads as a regression and is not one. An eyeball is set INTO the
	-- skull, only 23% of its sphere is outside it, and every intruding sample
	-- is in the buried 77%. Against the VISIBLE surface the nose clears by
	-- +0.266, seven times what the four balls managed.
	--
	-- Same correction this file already records for the turtle's ear, where
	-- testing the convenient point put it 0.067 inside a hair ball it is
	-- nowhere near: TEST THE SURFACE THAT CAN BE SEEN, not the surface that
	-- is easy to enumerate.
	local NOSE_AXIS = Vector3.new(0, -0.45097, 0.89244)
	local noseAt = Vector3.new(0, 14.80, 2.11660)
	local NOSE_WIDE, NOSE_LONG = 0.42, 0.90
	local nose = part("Nose", Vector3.new(NOSE_WIDE, NOSE_WIDE, NOSE_WIDE),
		at * CFrame.lookAt(noseAt, noseAt + NOSE_AXIS),
		Color3.fromRGB(226, 178, 142), SMOOTH)
	local noseMesh = Instance.new("SpecialMesh")
	noseMesh.MeshType = Enum.MeshType.Sphere
	-- `Scale` MULTIPLIES the part's Size, so the long axis is a ratio rather
	-- than a length. Stretched on Z because `CFrame.lookAt` builds its frame
	-- around Z; which way round it points does not matter, since the shape is
	-- symmetric about its own middle.
	noseMesh.Scale = Vector3.new(1, 1, NOSE_LONG / NOSE_WIDE)
	noseMesh.Parent = nose
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
-- ============================================================
-- TROPHIES
-- ============================================================
--
-- WHAT THE FOUR BUILDERS BELOW READ, AND IT IS DECLARED UP HERE FOR THE
-- TWELFTH TIME THIS PROJECT HAS PAID FOR THAT LESSON.
--
-- `Decor.build` writes it and sits five hundred lines BELOW the builders
-- that read it. A `local` declared under a function that reads it is a
-- nil GLOBAL to that function and Luau says nothing at compile time -- so
-- left there, every trophy on every lawn would have rendered as an EMPTY
-- case with no error anywhere, because `trophyState and trophyState.x`
-- on a nil global is a perfectly legal nil. That is the silent failure
-- this file refuses above all others, and it is a worse shape than the
-- crashes the other eleven produced: nothing to notice.
--
-- Held as an upvalue beside `folder` rather than threaded through every
-- builder's signature, for exactly the reason `folder` is: eighteen
-- ornaments take no state at all, and widening all of their signatures to
-- carry an argument four of them read would be eighteen chances to leave
-- it out on the next one somebody writes.
local trophyState: any = nil

-- HOW BIG A TROPHY IS AUTHORED, AND IT IS NOT A SCALE FACTOR.
--
-- These were garden monuments: 5.8 to 8.2 studs, drawn to be read from a
-- pavement. `TrophyService.check` stopped claiming a lawn slot when they moved
-- indoors, so NOTHING IS EVER DISPLAYED AT THE SIZE IT WAS DRAWN FOR any more
-- -- and the retired in-house room (`Services/TrophyRoom`, gone 2026-09-22)
-- was compensating with `ScaleTo`, measured at between a
-- sixth and a ninth. At that factor a flame tier, a dial ring, a rank star and
-- a rosette are all authored around 0.85 and land at a TENTH OF A STUD: the
-- shape survives and everything that says which grade it is does not.
--
-- A SHRUNK MONUMENT IS NOT A KEEPSAKE, which is the whole reason this is a
-- size and not a multiplier. Three things change that no uniform scale can:
-- the PLINTH goes (a keepsake stands on the shelf, and its engraving was
-- 0.06 studs tall), the tall pieces are RE-PROPORTIONED (a 7.6-stud lamp post
-- shrunk to fit a shelf is a wire, so it becomes a stubby bollard), and
-- anything that GROWS WITH ITS GRADE is pinned (a grade-10 cup is 8.2 studs
-- and a keepsake may not be twice the size of its neighbour).
--
-- `monument` is the geometry as it always was, and it is what the Featured
-- mount and the Drip Statue's eventual place on the map still want -- which
-- is why this is a size rather than a rewrite. See `docs/TROPHY-DISPLAY-
-- PROPOSAL.md` for the measurements.
local trophySize: string = "monument"

local function keepsake(): boolean
	return trophySize == "keepsake"
end

-- What a trophy is a picture of when nobody has said -- see `showroom`
-- further down, which is what fills it for a shop card.
--
-- MONEY BUYS THE FRAME; ROBBERY BUYS THE PICTURE. Every one of these is
-- a bought PLINTH with an earned object standing on it, and the split is
-- literal rather than a metaphor: `trophyPlinth` below is the only part
-- of a trophy a coin can reach, and everything above it is a function of
-- something the player did.
--
-- THEY GROW. A badge that appears once and never changes again is spent
-- the moment it lands; a case that gains a pig, a safe that gains a bar
-- and a post that gains a lamp are worth walking past for the rest of an
-- account's life. That is the coin pile's own argument, on the one
-- surface in this game that is about the past rather than the present.

-- Colours the four share, so a shelf reads as a set rather than as four
-- ornaments that happen to have arrived together.
local TROPHY_DARK = Color3.fromRGB(58, 52, 48)
local TROPHY_WOOD = Color3.fromRGB(126, 88, 58)
local TROPHY_WOOD_DARK = Color3.fromRGB(96, 66, 44)
local TROPHY_STEEL = Color3.fromRGB(96, 100, 108)
-- GOLD IS FLAT, NEVER `Material.Metal`, AND THAT WAS DECIDED BY LOOKING.
--
-- Metal shades a colour by the environment rather than rendering it, so
-- the same (226, 186, 86) that reads as bright gold on a plinth came out
-- OLIVE on a stack of bars two studs away from it -- photographed side by
-- side, and the two are supposed to be the same metal. Everything else in
-- this game's buildings is flat-shaded for the same reason the houses were
-- rebuilt off `Brick` and `Slate`.
--
-- The STEEL keeps Metal, because a safe reading as a slightly different
-- grey is what a safe is, and there is nothing for it to disagree with.
local TROPHY_GOLD = Color3.fromRGB(226, 186, 86)

-- THE PLINTH, AND IT RETURNS THE HEIGHT IT REACHES.
--
-- Every caller stands its trophy on the number that comes back rather
-- than on a constant, which is what stops a taller plinth burying the
-- thing it is holding up -- the `TORSO_Y` lesson from the guard dog,
-- where one literal in three places was fine until a breed's legs moved.
--
-- THE CAP STANDS PROUD OF THE BASE AND IS NARROWER THAN IT, which is the
-- moat's kerb rule at a twentieth of the scale: nothing here can be dug,
-- so a moulding is made by standing something proud rather than by
-- sinking anything, and the eye takes the highest line as the surface.
-- Narrower also keeps its four side faces INBOARD of the base's, so no
-- two of them can ever share a plane.
local function trophyPlinth(at: CFrame, width: number, depth: number,
	label: string): number
	-- A KEEPSAKE STANDS ON THE SHELF, AND THE SHELF IS THE PLINTH.
	--
	-- Suppressed rather than scaled, for two reasons that are both
	-- measurements. It is 1.16 studs of a 5.8-to-8.2-stud object, so on a
	-- shelf it was eating a SIXTH of the thing it was holding up. And the one
	-- job it does that the shelf cannot -- the engraved plate -- is a
	-- `SurfaceGui` 0.5 studs tall authored for a lawn, which landed at 0.06:
	-- text nobody can read, occupying the room a keepsake needs.
	--
	-- THE PURCHASE IS NOT LOST, WHICH IS WHY THIS IS SAFE. The bought finish
	-- (`Config.TROPHY_PLINTHS`) is the only part of a trophy coins can reach,
	-- so it has to stay visible somewhere: the FEATURED mount builds at
	-- `monument` size and keeps its plinth, engraving and uplights, on the one
	-- object in the room a visitor actually walks up to. That is a better home
	-- for it than four shelf copies at a tenth of a stud.
	if keepsake() then
		return 0
	end

	local plinth = Config.trophyPlinth(trophyState and trophyState.plinth)

	local baseH, capH = 0.9, 0.26
	part("PlinthBase", Vector3.new(width, baseH, depth),
		at * CFrame.new(0, baseH / 2, 0), plinth.base, plinth.material)
	part("PlinthCap", Vector3.new(width - 0.7, capH, depth - 0.7),
		at * CFrame.new(0, baseH + capH / 2, 0), plinth.trim, plinth.material)

	-- THE ENGRAVING IS A RUNG RATHER THAN A FREEBIE, so a plain concrete
	-- plinth carries no plaque at all -- which is what makes the step up
	-- to marble a step from an object to a READOUT.
	--
	-- `Face` is Back, because Roblox's Front is -Z and plot-local +Z is the
	-- street on both rows. This is the same one-word mistake the plot
	-- signs already have a note about.
	if plinth.plaque then
		local plate = part("Plaque", Vector3.new(width * 0.62, 0.5, 0.12),
			at * CFrame.new(0, baseH * 0.62, depth / 2 + 0.05),
			plinth.trim, plinth.material)
		local surface = Instance.new("SurfaceGui")
		surface.Face = Enum.NormalId.Back
		surface.CanvasSize = Vector2.new(360, 72)
		-- Read from a couple of studs away by somebody standing on the
		-- lawn, never from the pavement -- a row of these legible across
		-- the street would be a wall of text over the world, which is the
		-- measurement the shop's own name plaques already settled at 260.
		surface.MaxDistance = 70
		surface.Parent = plate

		local text = Instance.new("TextLabel")
		text.Size = UDim2.new(1, -16, 1, -12)
		text.Position = UDim2.new(0, 8, 0, 6)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.FredokaOne
		-- Never write TextWrapped beside TextScaled; see the plot sign.
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(46, 34, 22)
		text.Text = label
		text.Parent = surface
	end

	-- THE UPLIGHT, AND IT IS NEON RATHER THAN A LIGHT.
	--
	-- `WorldService` sets ClockTime to 14.5 exactly once and nothing in
	-- this game ever moves it, so a PointLight on a lawn at half past two
	-- is a purchase nobody can see. Neon renders flat out whatever the sun
	-- is doing and the BloomEffect already in the world takes it from
	-- there -- which is why every celebration in this project is emissive
	-- geometry.
	-- ON THE BASE'S FRONT FACE, LOW, AND NOT ON TOP OF THE CAP -- which is
	-- where the first version put them and is the one place on this object
	-- there is no room. Every trophy stands ON the cap, so a lamp up there
	-- shares a bottom plane with whatever is standing on it: the shelf's
	-- own boards reach z 1.4 on a plinth whose cap reaches 1.35, so there
	-- is no clear ground at all. Low on the front is also what an uplight
	-- is, and it clears the plaque above it by a quarter of a stud.
	if plinth.glow then
		for _, side in ipairs({ -1, 1 }) do
			part("PlinthLamp", Vector3.new(0.6, 0.18, 0.18),
				at * CFrame.new(side * (width / 2 - 0.6), 0.15, depth / 2 + 0.04),
				plinth.glow, Enum.Material.Neon)
		end
	end

	return baseH + capH
end

-- ------------------------------------------------------------
-- THE VICTIM SHELF
-- ------------------------------------------------------------
--
-- One little pig per SKIN robbed, in that skin, built by the same
-- function that builds the one a thief runs home with.
--
-- IT IS THE ONLY THING IN THIS GAME THAT SHOWS SOMEBODY ELSE'S COSMETIC.
-- A skin is seen by its owner and by whoever happens to walk past their
-- plot, and by nothing else -- so forty-six authored piggies have exactly
-- one surface each. This gives every one of them a second: a reason for a
-- thief to care which pig they crack, and a reason for a defender to be
-- wearing something worth taking a copy of.
--
-- NINE SLOTS, RAREST FIRST, AND BOTH HALVES ARE MEASURED RATHER THAN
-- CHOSEN. A mini piggy is eleven parts before its pattern, so a case of
-- twenty-four would be most of a house tier standing on a lawn slot; nine
-- is about a hundred and thirty and sits between the villa and the manor.
-- And rarest first is what makes a full case still worth looking at once
-- the collection has outgrown it: a shelf that showed the first nine
-- robbed would freeze on somebody's first evening and never change again.
local SHELF_COLS, SHELF_ROWS = 3, 3
local SHELF_PITCH_X, SHELF_PITCH_Y = 3.0, 2.75

-- FOUR PIGS IN A WALL CASE RATHER THAN NINE, AND THE MENU IS WHY THAT IS NOT
-- A LOSS. A nine-slot case is 10.4 by 8.75 studs -- a lawn object -- and hung
-- in a room at a third of that the pigs inside it are smears. Two by two at
-- the same pitch keeps each mini piggy READABLE, which is the whole point of a
-- case that shows somebody else's skin, and the full collection log lives in
-- the bag where every skin is a card. The physical case is the boast; the menu
-- is the record. That is the brief's own split (`assets/houses/docs/HOUSE-TROPHY-ROOMS.md`:
-- display capacity may grow with the house, ACHIEVEMENT capacity never does).
local function shelfGrid(): (number, number)
	if keepsake() then
		return 2, 2
	end
	return SHELF_COLS, SHELF_ROWS
end

-- Rank a skin the way the shop borders it, so the case and the card can
-- never disagree about which of two pigs is the better trophy.
local RARITY_RANK = { common = 1, rare = 2, epic = 3, legendary = 4 }

local function shelfPicks(): { string }
	local held = (trophyState and trophyState.victims) or {}
	local keys: { string } = {}
	for _, key in ipairs(held) do
		if Config.SKINS[key] then
			table.insert(keys, key)
		end
	end

	-- Values computed into a map BEFORE the sort rather than inside the
	-- comparator. `table.sort` throws on an inconsistent order function and
	-- one that recomputes per comparison is one edit away from being one --
	-- the same note the auto-picked combine carries.
	local rank: { [string]: number } = {}
	for _, key in ipairs(keys) do
		rank[key] = RARITY_RANK[Config.rarityOf(Config.SKINS[key])] or 1
	end
	table.sort(keys, function(a, b)
		if rank[a] ~= rank[b] then
			return rank[a] > rank[b]
		end
		return a < b
	end)

	local cols, rows = shelfGrid()
	while #keys > cols * rows do
		table.remove(keys)
	end
	return keys
end

builders.victimshelf = function(_item, at)
	local cols, rows = shelfGrid()
	local width = cols * SHELF_PITCH_X + 1.4
	local depth = 3.4
	local picks = shelfPicks()
	local total = (trophyState and trophyState.skinTotal) or 0
	local held = #((trophyState and trophyState.victims) or {})
	local top = trophyPlinth(at, width, depth,
		("%d OF %d SKINS"):format(held, total))

	local inner = cols * SHELF_PITCH_X
	local caseH = rows * SHELF_PITCH_Y + 0.5

	-- The back panel and the two uprights. Everything is authored from the
	-- plinth top up, so a taller plinth carries the whole case with it.
	-- THE BACK PANEL IS SHORTER THAN THE UPRIGHTS, AND THE UPRIGHTS SINK
	-- INTO THE PLINTH. Both are the coplanar rule rather than taste: two
	-- parts that share a top AND a bottom plane with real overlap between
	-- them z-fight along both, and a case built the obvious way -- back and
	-- posts running the full height -- does exactly that. Standing anything
	-- 0.1 INTO what holds it up is this project's convention for the same
	-- reason.
	part("ShelfBack", Vector3.new(inner + 0.6, caseH - 0.4, 0.3),
		at * CFrame.new(0, top + caseH / 2, -depth / 2 + 0.35),
		TROPHY_WOOD_DARK, Enum.Material.SmoothPlastic)
	for _, side in ipairs({ -1, 1 }) do
		part("ShelfPost", Vector3.new(0.42, caseH + 0.1, depth - 0.6),
			at * CFrame.new(side * (inner / 2 + 0.4),
				top + (caseH + 0.1) / 2 - 0.1, 0.1),
			TROPHY_WOOD, Enum.Material.SmoothPlastic)
	end

	-- The boards, and the pigs standing on them. A shelf's TOP face is
	-- where a pig's feet go, so the seat is derived from the board rather
	-- than from the loop index -- move the pitch and the pigs follow.
	for row = 0, rows - 1 do
		local boardY = top + row * SHELF_PITCH_Y
		part("ShelfBoard", Vector3.new(inner + 0.5, 0.22, depth - 0.9),
			at * CFrame.new(0, boardY + 0.11, 0.1),
			TROPHY_WOOD, Enum.Material.SmoothPlastic)

		for col = 0, cols - 1 do
			-- Filled from the TOP shelf down, so the best of the collection
			-- is at eye height and a half-full case fills downward rather
			-- than leaving a gap where the good ones will go.
			local index = (rows - 1 - row) * cols + col + 1
			local key = picks[index]
			if key then
				local seat = at * CFrame.new(
					(col - (cols - 1) / 2) * SHELF_PITCH_X,
					boardY + 0.22, 0.1)
				local mini = PiggyModel.build(key)
				-- A BUILDER'S ANCHORING IS A FACT ABOUT WHERE IT WAS DESIGNED
				-- TO GO, and this one was designed to be welded to a running
				-- thief: unanchored and Massless, because an anchored part
				-- welded to a humanoid pins the humanoid. Stood on a shelf
				-- with nothing to weld to it would simply FALL -- which is
				-- exactly what three of the four shop displays did on their
				-- first build. So this anchors whatever it is handed, the same
				-- call `ShopFront` makes.
				for _, d in ipairs(mini:GetDescendants()) do
					if d:IsA("BasePart") then
						d.Anchored = true
					end
				end
				mini.Name = "Trophy_" .. key
				-- The animator reads this off a piggy exactly as it does off a
				-- real one on a plot, so a Rainbow on somebody's shelf cycles
				-- and none of that maths is written twice.
				mini:SetAttribute("SkinKey", key)
				-- PivotTo aims the PRIMARY PART, which on a mini is the body
				-- ball at local y 1.15 -- so seating one by the shelf's own
				-- surface without that offset buries it a stud into the wood.
				-- Third instance of this exact mismatch in the project.
				mini:PivotTo(seat * CFrame.new(0, 1.15, 0))
				mini.Parent = folder
			end
		end
	end

	-- The canopy, standing proud of the case on every side so the whole
	-- thing reads as a cabinet rather than as three boards on posts.
	part("ShelfRoof", Vector3.new(width - 0.6, 0.34, depth - 0.3),
		at * CFrame.new(0, top + caseH + 0.17, 0.05),
		TROPHY_WOOD_DARK, Enum.Material.SmoothPlastic)
end

-- ------------------------------------------------------------
-- THE HAUL
-- ------------------------------------------------------------
--
-- An open safe that fills with bars as `data.totalStolen` climbs.
--
-- IT DOUBLES RATHER THAN COUNTING -- see `Config.TROPHIES.haulvault` --
-- because this is the one figure on a shelf that has to mean the same
-- thing to a level-1 thief and a level-40 one. Ten bars is 100K doubled
-- nine times.
builders.haulvault = function(_item, at)
	local width, depth = 7.0, 4.6
	local stolen = (trophyState and trophyState.stolen) or 0
	local bars = Config.trophyGrade("haulvault", stolen)
	local top = trophyPlinth(at, width, depth,
		("%s STOLEN"):format(Config.formatCoins(stolen)))

	local bodyW, bodyH, bodyD = 4.4, 4.2, 3.0
	local bodyY = top + bodyH / 2
	part("SafeBody", Vector3.new(bodyW, bodyH, bodyD),
		at * CFrame.new(-0.5, bodyY, -0.2), TROPHY_STEEL, Enum.Material.Metal)

	-- THE OPENING IS DARK AND THE FRAME AROUND IT STANDS PROUD, which is
	-- the only way to make a hole in this engine: nothing can be dug, so a
	-- recess is made by raising its edges and letting the eye take the
	-- highest line as the surface. Set flush instead and it is a black
	-- sticker on the front of a box, which is precisely what the piggy's
	-- own vault hatch became for a whole release.
	local openW, openH = bodyW - 1.0, bodyH - 1.0
	part("SafeVoid", Vector3.new(openW, openH, 0.2),
		at * CFrame.new(-0.5, bodyY, -0.2 + bodyD / 2 - 0.02),
		Color3.fromRGB(22, 22, 24), Enum.Material.SmoothPlastic)
	-- FOUR PIECES THAT BUTT RATHER THAN OVERLAP, which is the only
	-- arrangement of a rectangular frame that has no coplanar pair in it.
	-- The rails run the full outer width and the stiles fill only the gap
	-- between them, so every meeting is a lo-against-hi joint with zero
	-- overlap on the axis they share -- a butt joint, which is never a
	-- fight. Sized the obvious way instead, all four pieces sit at one
	-- depth and overlap at the corners, and the whole frame flickers.
	for _, edge in ipairs({
		{ Vector3.new(openW + 0.7, 0.35, 0.34), Vector3.new(0, openH / 2 + 0.175, 0) },
		{ Vector3.new(openW + 0.7, 0.35, 0.34), Vector3.new(0, -openH / 2 - 0.175, 0) },
		{ Vector3.new(0.35, openH, 0.34), Vector3.new(openW / 2 + 0.175, 0, 0) },
		{ Vector3.new(0.35, openH, 0.34), Vector3.new(-openW / 2 - 0.175, 0, 0) },
	}) do
		part("SafeFrame", edge[1],
			at * CFrame.new(Vector3.new(-0.5, bodyY, -0.2 + bodyD / 2 + 0.08) + edge[2]),
			TROPHY_DARK, Enum.Material.Metal)
	end

	-- The door, swung open on the right so the opening faces the street
	-- rather than the viewer's edge. A safe drawn shut says nothing about
	-- what is in it, which is the entire content of this trophy.
	local hinge = at * CFrame.new(-0.5 + openW / 2 + 0.4, bodyY, -0.2 + bodyD / 2)
	local door = hinge * CFrame.Angles(0, math.rad(-55), 0)
	part("SafeDoor", Vector3.new(openW + 0.5, openH + 0.5, 0.34),
		door * CFrame.new((openW + 0.5) / 2, 0, 0.2),
		TROPHY_STEEL, Enum.Material.Metal)
	cylinderZ("SafeDial", 0.3, 1.0,
		door * CFrame.new((openW + 0.5) / 2, 0, 0.45),
		TROPHY_GOLD, Enum.Material.SmoothPlastic)

	-- THE BARS, three to a course, stacked from the floor of the safe up.
	-- The tenth spills out onto the plinth, which is the one thing on this
	-- object that reads from further away than the plaque does.
	-- STACKED IN FRONT OF THE DARK PANEL RATHER THAN BEHIND IT, and that is
	-- forced rather than chosen: the safe body is a SOLID box, so a bar
	-- placed "inside" it is simply buried. Nothing in this engine can be
	-- hollowed out, which is the same fact the moat's kerbs and the piggy's
	-- own vault hatch are both built around. Standing them proud of the
	-- opening reads as an overfull safe, which is the better picture anyway.
	local barW, barH, barD = 1.15, 0.42, 0.7
	local barZ = -0.2 + bodyD / 2 + 0.3
	for i = 1, bars do
		local row = math.floor((i - 1) / 3)
		local col = (i - 1) % 3
		if row < 3 then
			part("GoldBar", Vector3.new(barW, barH, barD),
				at * CFrame.new(-0.5 + (col - 1) * (barW + 0.06),
					top + 0.35 + barH / 2 + row * (barH + 0.04), barZ),
				TROPHY_GOLD, Enum.Material.SmoothPlastic)
		else
			-- The overflow, on the open plinth BESIDE the safe rather than in
			-- front of it -- the one patch of this base nothing else stands on.
			-- Turned, so it reads as dropped rather than as placed.
			part("GoldBar", Vector3.new(barW, barH, barD),
				at * CFrame.new(2.5, top + barH / 2 - 0.08, 0.7 - col * 0.6)
					* CFrame.Angles(0, math.rad(18 + col * 26), 0),
				TROPHY_GOLD, Enum.Material.SmoothPlastic)
		end
	end
end

-- ------------------------------------------------------------
-- THE MEDAL BOARD
-- ------------------------------------------------------------
--
-- One rosette for every thief stopped on this lawn, and it is the half of
-- the shelf that answers a player who put their coins into fences, dogs
-- and locks. Without it a yard says "I rob" and offers that player
-- nothing at all.
--
-- NAMES MUST AGE OUT, which is why this counts and does not LIST. A
-- permanent public board of the children who failed on your lawn is the
-- wrong object for this audience -- the same argument that made the
-- robbery plaster expire rather than persist. A rosette says somebody was
-- stopped; it does not say who, and it cannot be read back later to find
-- out.
builders.medalboard = function(_item, at)
	local width, depth = 7.4, 2.6
	local caught = (trophyState and trophyState.caught) or 0
	local rosettes = Config.trophyGrade("medalboard", caught)
	local top = trophyPlinth(at, width, depth, ("%d CAUGHT"):format(caught))

	local boardW, boardH = 6.4, 3.9
	-- HUNG ON A WALL RATHER THAN STOOD ON POSTS, WHICH IS WHY THIS ONE NEVER
	-- BELONGED ON A SHELF.
	--
	-- A board on posts is SIGNAGE: 7.4 studs wide, drawn to be read across a
	-- lawn. Signage does not shrink -- at a shelf's budget the rosettes pinned
	-- to it land at a tenth of a stud and all that survives is the outline, a
	-- small rectangle on a stick, which is exactly the "cards with words"
	-- complaint. So indoors this goes on the `Wall` mount, flat, at very
	-- nearly the size it was drawn at: the posts and the ground lift go, and
	-- what is left is the board and everything pinned to it.
	local lift = if keepsake() then 0 else 1.5
	local boardY = top + lift + boardH / 2
	-- The posts overlap the board's own edge rather than standing clear of
	-- it: a board floating a tenth of a stud off the things holding it up
	-- is the same fault as a fence panel that does not reach its post.
	if not keepsake() then
		for _, side in ipairs({ -1, 1 }) do
			part("BoardPost", Vector3.new(0.42, lift + boardH + 0.5, 0.42),
				at * CFrame.new(side * (boardW / 2 + 0.1),
					top + (lift + boardH + 0.5) / 2, -0.1),
				TROPHY_WOOD_DARK, Enum.Material.SmoothPlastic)
		end
	end
	part("MedalBoard", Vector3.new(boardW, boardH, 0.36),
		at * CFrame.new(0, boardY, -0.1), TROPHY_WOOD, Enum.Material.SmoothPlastic)
	-- Sitting ON the board rather than floating above it: a butt joint,
	-- which is a meeting rather than a fight.
	part("BoardRail", Vector3.new(boardW + 1.2, 0.34, 0.6),
		at * CFrame.new(0, top + lift + boardH + 0.17, -0.1),
		TROPHY_WOOD_DARK, Enum.Material.SmoothPlastic)

	-- A rosette is a disc with two tails, and the tails are what stop three
	-- rows of discs reading as a control panel.
	for i = 1, rosettes do
		local row = math.floor((i - 1) / 3)
		local col = (i - 1) % 3
		local spot = at * CFrame.new((col - 1) * 2.0,
			boardY + 1.05 - row * 1.15, -0.1 + 0.18 + 0.09)
		cylinderZ("Rosette", 0.18, 0.92, spot,
			Color3.fromRGB(196, 72, 88), Enum.Material.SmoothPlastic)
		cylinderZ("RosetteHub", 0.24, 0.4, spot * CFrame.new(0, 0, 0.05),
			TROPHY_GOLD, Enum.Material.SmoothPlastic)
		for _, tail in ipairs({ -1, 1 }) do
			part("RosetteTail", Vector3.new(0.26, 0.72, 0.1),
				spot * CFrame.new(tail * 0.2, -0.62, -0.02)
					* CFrame.Angles(0, 0, math.rad(tail * 12)),
				Color3.fromRGB(168, 56, 72), Enum.Material.SmoothPlastic)
		end
	end
end

-- ------------------------------------------------------------
-- THE SIREN POST
-- ------------------------------------------------------------
--
-- One lamp for every most-wanted patrol outrun. It reads `gear.escapes`,
-- which is ALREADY the unlock ladder for the Most Wanted gear -- so this
-- is a second READOUT of one number rather than a second counter, and the
-- two can never disagree about how many patrols somebody has survived.
--
-- BLUE NEON, which is the police's own colour everywhere else in this
-- game, and deep rather than pale: Neon renders a colour flat out and the
-- BloomEffect takes it from there, so a pale tint is a white hole and a
-- saturated one is a lamp. Fourth time this project has learned that.
builders.sirenpost = function(_item, at)
	local width = 3.2
	local escapes = (trophyState and trophyState.escapes) or 0
	local lamps = Config.trophyGrade("sirenpost", escapes)
	local top = trophyPlinth(at, width, width,
		("%d ESCAPED"):format(escapes))

	-- RE-PROPORTIONED ON A SHELF RATHER THAN SHRUNK, AND THIS IS THE ONE THAT
	-- NEEDED IT MOST. A 7.6-stud lamp post scaled to a shelf budget is a
	-- 0.1-stud-thick WIRE with beads on it: the silhouette that says "street
	-- lamp" on a lawn says "nothing" at a third of the size, because what
	-- reads at a distance is the post's HEIGHT against its width. A stubby
	-- bollard lamp is the same object honestly authored small, and the lamps
	-- still climb it -- the pitch comes down with the post so a full one is
	-- still a ladder rather than a stripe.
	local postH = if keepsake() then 2.6 else 6.4
	local lampFrom = if keepsake() then 0.55 else 1.5
	local lampPitch = if keepsake() then 0.62 else 1.0
	cylinderY("SirenPost", postH, 0.78,
		at * CFrame.new(0, top + postH / 2, 0), TROPHY_DARK, Enum.Material.Metal)

	-- The lamps climb the post, alternating sides so a full one reads as a
	-- ladder rather than as a stripe. The bracket is what stops each lamp
	-- looking glued to the pole.
	for i = 1, lamps do
		local side = if i % 2 == 1 then 1 else -1
		local y = top + lampFrom + (i - 1) * lampPitch
		-- A BOX RATHER THAN A CYLINDER, because `cylinderZ` already carries a
		-- quarter turn and a second one to point it sideways is two rotations
		-- doing the work of none. A Roblox cylinder's axis is its X in the
		-- first place, and this bracket is 0.6 studs long -- nobody is reading
		-- its cross-section.
		part("SirenArm", Vector3.new(0.8, 0.24, 0.24),
			at * CFrame.new(side * 0.6, y, 0),
			TROPHY_DARK, Enum.Material.Metal)
		cylinderY("SirenLamp", 0.8, 0.9,
			at * CFrame.new(side * 0.95, y, 0),
			Color3.fromRGB(48, 92, 226), Enum.Material.Neon)
		part("SirenCap", Vector3.new(1.0, 0.18, 1.0),
			at * CFrame.new(side * 0.95, y + 0.45, 0),
			TROPHY_STEEL, Enum.Material.Metal)
	end

	ball("SirenFinial", 0.86, at * CFrame.new(0, top + postH + 0.2, 0),
		TROPHY_STEEL, Enum.Material.Metal)
end

-- ------------------------------------------------------------
-- PHASE 5.2: SIX MORE TROPHIES
-- ------------------------------------------------------------
--
-- Same contract as the four above: each reads one number off
-- `trophyState`, grades it through `Config.trophyGrade`, stands on
-- `trophyPlinth`, and stays inside the medal board's footprint (7.4 x 2.6)
-- so the lawn slot grid's widest-ornament arithmetic does not move. Neon is
-- deep and saturated: a pale Neon is a white hole under the bloom.
-- UNVERIFIED IN STUDIO: authored from the builders above, not photographed.

builders.hotstreak = function(_item, at)
	local best = (trophyState and trophyState.bestSpree) or 0
	local grade = Config.trophyGrade("hotstreak", best)
	local top = trophyPlinth(at, 3.4, 3.4, ("BEST RUN %d"):format(best))
	-- A shorter stem on a shelf: the bowl and its flames are what this trophy
	-- IS, and on a lawn the stem is what lifts them to eye height. Indoors the
	-- shelf already did that, so the stem was spending a third of the budget
	-- holding the interesting part further away.
	local stemH = if keepsake() then 0.9 else 2.2
	cylinderY("BrazierStem", stemH, 0.7, at * CFrame.new(0, top + stemH / 2, 0),
		TROPHY_DARK, Enum.Material.SmoothPlastic)
	local bowlY = top + stemH + 0.35
	cylinderY("BrazierBowl", 0.7, 2.6, at * CFrame.new(0, bowlY, 0),
		TROPHY_STEEL, Enum.Material.SmoothPlastic)
	-- One flame tier per grade, each narrower and higher: the fire climbs.
	for i = 1, grade do
		local d = 2.0 - (i - 1) * 0.36
		local h = 0.9
		cylinderY("Flame", h, d, at * CFrame.new(0, bowlY + 0.35 + (i - 0.5) * h * 0.85, 0),
			if i % 2 == 1 then Color3.fromRGB(236, 92, 20) else Color3.fromRGB(246, 150, 20),
			Enum.Material.Neon)
	end
end

builders.oldhand = function(_item, at)
	local width, depth = 6.4, 2.4
	local rank = (trophyState and trophyState.rank) or 0
	local stars = Config.trophyGrade("oldhand", rank)
	local top = trophyPlinth(at, width, depth, ("RANK %d"):format(rank))
	local boardW, boardH = 5.6, 2.4
	-- Signage, so it hangs on the `Wall` mount indoors rather than standing on
	-- a shelf -- see `medalboard` above for the measurement.
	local lift = if keepsake() then 0 else 1.2
	local boardY = top + lift + boardH / 2
	if not keepsake() then
		for _, side in ipairs({ -1, 1 }) do
			part("OldHandPost", Vector3.new(0.4, lift + boardH + 0.3, 0.4),
				at * CFrame.new(side * (boardW / 2 + 0.1), top + (lift + boardH + 0.3) / 2, -0.1),
				TROPHY_WOOD_DARK, Enum.Material.SmoothPlastic)
		end
	end
	part("OldHandBoard", Vector3.new(boardW, boardH, 0.34),
		at * CFrame.new(0, boardY, -0.1), TROPHY_WOOD, Enum.Material.SmoothPlastic)
	-- A star is a gold diamond with a smaller one on it: legible at seventy
	-- studs where a five-pointed outline is not.
	for i = 1, stars do
		local x = (i - (stars + 1) / 2) * 1.25
		part("RankStar", Vector3.new(0.8, 0.8, 0.14),
			at * CFrame.new(x, boardY, -0.1 + 0.17 + 0.07) * CFrame.Angles(0, 0, math.rad(45)),
			TROPHY_GOLD, Enum.Material.SmoothPlastic)
		part("RankStarCore", Vector3.new(0.4, 0.4, 0.1),
			at * CFrame.new(x, boardY, -0.1 + 0.17 + 0.18) * CFrame.Angles(0, 0, math.rad(45)),
			Color3.fromRGB(255, 232, 150), Enum.Material.SmoothPlastic)
	end
end

builders.cleansheet = function(_item, at)
	local clean = (trophyState and trophyState.clean) or 0
	local rings = Config.trophyGrade("cleansheet", clean)
	local top = trophyPlinth(at, 3.6, 2.6, ("%d CLEAN"):format(clean))
	-- The dial IS the trophy and the stand only lifts it; on a shelf the shelf
	-- has already done the lifting.
	local standH = if keepsake() then 0.7 else 1.6
	part("DialStand", Vector3.new(0.6, standH, 0.6),
		at * CFrame.new(0, top + standH / 2, 0), TROPHY_DARK, Enum.Material.SmoothPlastic)
	local dialY = top + standH + (if keepsake() then 0.95 else 1.5)
	cylinderZ("DialFace", 0.4, 3.0, at * CFrame.new(0, dialY, 0),
		TROPHY_STEEL, Enum.Material.SmoothPlastic)
	-- Rings stack forward off the face, each smaller, so a full dial reads
	-- as a target rather than as a coin.
	for i = 1, rings do
		cylinderZ("DialRing", 0.12, 3.0 - i * 0.38,
			at * CFrame.new(0, dialY, 0.2 + i * 0.07),
			if i % 2 == 1 then TROPHY_GOLD else TROPHY_DARK, Enum.Material.SmoothPlastic)
	end
	part("DialPointer", Vector3.new(0.16, 1.1, 0.1),
		at * CFrame.new(0, dialY + 0.5, 0.26 + rings * 0.07 + 0.06), Color3.fromRGB(196, 72, 88),
		Enum.Material.SmoothPlastic)
end

builders.seasoncup = function(_item, at)
	local best = (trophyState and trophyState.seasonBest) or 0
	local grade = Config.trophyGrade("seasoncup", best)
	local top = trophyPlinth(at, 3.4, 3.4, ("BEST TIER %d"):format(best))
	-- The cup grows with the grade: tier 6 is a cup, tier 10 is a big one.
	--
	-- PINNED ON A SHELF, because a keepsake may not be twice the size of the
	-- one beside it. At grade 10 this reaches 8.2 studs, which on a shelf
	-- budget means the whole row is scaled to the luckiest object on it and
	-- every other trophy shrinks to pay for this one. The gems still count up.
	local s = if keepsake() then 1.0 else 0.8 + 0.15 * math.max(grade, 1)
	cylinderY("CupFoot", 0.3 * s, 1.8 * s, at * CFrame.new(0, top + 0.15 * s, 0),
		TROPHY_GOLD, Enum.Material.SmoothPlastic)
	cylinderY("CupStem", 1.0 * s, 0.5 * s, at * CFrame.new(0, top + 0.3 * s + 0.5 * s - 0.05, 0),
		TROPHY_GOLD, Enum.Material.SmoothPlastic)
	local bowlY = top + 1.3 * s + 0.8 * s - 0.1
	cylinderY("CupBowl", 1.6 * s, 2.0 * s, at * CFrame.new(0, bowlY, 0),
		TROPHY_GOLD, Enum.Material.SmoothPlastic)
	cylinderY("CupRim", 0.16 * s, 2.2 * s, at * CFrame.new(0, bowlY + 0.8 * s + 0.02, 0),
		Color3.fromRGB(255, 220, 120), Enum.Material.SmoothPlastic)
	for _, side in ipairs({ -1, 1 }) do
		part("CupHandle", Vector3.new(0.3 * s, 1.0 * s, 0.3 * s),
			at * CFrame.new(side * 1.2 * s, bowlY, 0), TROPHY_GOLD, Enum.Material.SmoothPlastic)
	end
	-- One gem per grade across the bowl's front.
	for i = 1, grade do
		ball("CupGem", 0.32 * s, at * CFrame.new((i - (grade + 1) / 2) * 0.36 * s, bowlY, 1.0 * s),
			Color3.fromRGB(150, 70, 230), Enum.Material.Neon)
	end
end

builders.wantedposter = function(_item, at)
	local width, depth = 6.4, 2.4
	local times = (trophyState and trophyState.wanted) or 0
	local posters = Config.trophyGrade("wantedposter", times)
	local top = trophyPlinth(at, width, depth, ("WANTED x%d"):format(times))
	local boardW, boardH = 5.6, 3.2
	-- Signage, so it hangs on the `Wall` mount indoors -- see `medalboard`.
	local lift = if keepsake() then 0 else 1.2
	local boardY = top + lift + boardH / 2
	if not keepsake() then
		for _, side in ipairs({ -1, 1 }) do
			part("PosterPost", Vector3.new(0.4, lift + boardH + 0.3, 0.4),
				at * CFrame.new(side * (boardW / 2 + 0.1), top + (lift + boardH + 0.3) / 2, -0.1),
				TROPHY_WOOD_DARK, Enum.Material.SmoothPlastic)
		end
	end
	part("PosterBoard", Vector3.new(boardW, boardH, 0.34),
		at * CFrame.new(0, boardY, -0.1), TROPHY_WOOD, Enum.Material.SmoothPlastic)
	for i = 1, posters do
		local row = math.floor((i - 1) / 3)
		local col = (i - 1) % 3
		local spot = at * CFrame.new((col - 1) * 1.7, boardY + 0.72 - row * 1.5, -0.1 + 0.17 + 0.05)
		part("Poster", Vector3.new(1.3, 1.3, 0.08), spot * CFrame.Angles(0, 0, math.rad((i % 2 == 0) and 4 or -4)),
			Color3.fromRGB(236, 222, 190), Enum.Material.SmoothPlastic)
		part("PosterBand", Vector3.new(1.1, 0.24, 0.06),
			spot * CFrame.new(0, 0.42, 0.06) * CFrame.Angles(0, 0, math.rad((i % 2 == 0) and 4 or -4)),
			Color3.fromRGB(196, 72, 88), Enum.Material.SmoothPlastic)
		ball("PosterPin", 0.2, spot * CFrame.new(0, 0.55, 0.1), TROPHY_STEEL, Enum.Material.SmoothPlastic)
	end
end

-- `builders.goodharvest` STOOD HERE: a barrel whose heaped ACORNS were its
-- grade, filled from `trophies.harvested`. It went with the currency, and it
-- was already unreachable -- `Config.TROPHIES` is empty, so nothing could ask
-- for it.

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
		["resident chain link"] = dripChainTemplate,
	}) do
		local ok, err = pcall(build)
		if not ok then
			warn(("[Decor] prewarm failed, the %s will be missing: %s")
				:format(name, tostring(err)))
		end
	end
end

-- THE STANDING FIGURE, which is what every RESIDENT is built from and is no
-- longer a decoration at all.
--
-- `ResidentModel` used to reach it as `Decor.buildOne("dripstatue")`, and the
-- Drip Statue was retired from the lawn catalogue -- so that call would have
-- started returning nil and EVERY NEIGHBOUR ON THE STREET would have
-- disappeared behind `ResidentModel`'s own pcall, with the failure looking
-- exactly like a plot simply being vacant. That is the most expensive bug
-- this project has already had once, and it is the reason a retired item's
-- BUILDER is kept while its catalogue row goes.
--
-- Same shape and same reasoning as `buildStreetBin` below: reaching the
-- builder directly is honest about what this is -- shared geometry, not a
-- shared item.
function Decor.buildFigure(at: CFrame, parent: Instance): Model?
	local build = builders.dripstatue
	if not build then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Prop_figure"
	folder = model
	-- NEITHER `trophyState` NOR `skinKey` IS SET, and that is not laziness:
	-- the figure builder reads neither (it is not a trophy and it wears no
	-- piggy skin), and `showroom` -- which `buildOne` calls to default the
	-- state -- is declared 230 lines BELOW this. Calling it here read as a nil
	-- global and took every resident on the street down behind
	-- `ResidentService`'s own guard: "could not build a resident figure",
	-- fourteen times, which is the twelfth forward reference in this project
	-- and the second time it has emptied the neighbourhood.
	build({}, at)
	model.Parent = parent
	return model
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

-- THE MAILBOX, AND IT IS ONE OBJECT WITH TWO CALLERS.
--
-- `PlotService` stands one on every plot's verge -- the interactive one,
-- carrying the daily-reward prompt and the flag that says there is something
-- in it -- and `NeighborhoodService` stands one at the kerb beside each
-- driveway as street furniture. Those were TWO DIFFERENT OBJECTS: a
-- five-part white box out on the plot and a red box on a stick at the road.
-- So a street carried ten of each, both called a mailbox, and neither looked
-- like the other.
--
-- IN `Shared` FOR THE REASON `buildStreetBin` IS, and it is worth stating
-- because it is not the usual one. House, Decor and PiggyModel live here
-- because the SHOP renders them; nothing renders a mailbox in a shop and
-- nobody buys one. This is shared GEOMETRY rather than a shared ITEM: two
-- services simply have to agree about what a mailbox looks like, and a
-- second hand-built lookalike is the copy that stops matching the first time
-- either is touched -- the argument `Decor.buildStreetBin` already makes
-- about the disguise's wheelie bin.
--
-- `base` IS THE GROUND AT THE MAILBOX'S FOOT, ALREADY YAWED. Every offset
-- below is measured up from there, so a caller on a plot's verge and a
-- caller on the world ground pass their own floor and share everything else.
-- A builder that took a world position instead would have to know which of
-- this game's three floor heights it was standing on, which is exactly the
-- mistake that once left every ornament outside a fence hovering a stud.
--
-- PARTS ARE PARENTED FLAT rather than into a Model of their own, because a
-- plot is one flat model and the caller holds what it needs BY REFERENCE.
-- Looking a piece back up by name is the castle's four `Finial`s and the
-- wheelie bin's pair of `Lid`s, twice over: there are two mailboxes within
-- thirty studs of each other now.
Decor.MAILBOX_SHELL = Color3.fromRGB(196, 190, 176)
Decor.MAILBOX_DOOR = Color3.fromRGB(148, 142, 130)
Decor.MAILBOX_POST = Color3.fromRGB(122, 88, 58)
Decor.MAILBOX_FLAG = Color3.fromRGB(206, 62, 58)

-- THE FLAG'S HINGE, AT ITS FOOT, IN THE MAILBOX'S OWN SPACE.
--
-- Turning a part about its own centre swings half of it into whatever it is
-- bolted to -- the guard dog's ears record this exactly -- so the pivot is
-- the flag's BASE and the half-length is added back after the turn. 0 is
-- straight up and a quarter turn lays it flat along the box with the foot
-- never moving. Exported because `PlotService` raises and lowers it every
-- time the daily state changes, and two descriptions of one hinge is how the
-- flag and the box it is bolted to came to disagree in the first place.
--
-- IT TURNS ABOUT THE BOX'S SIDEWAYS AXIS (X), the way a real mailbox flag
-- does: up is a pole standing on the side of the box, down lies along the
-- box's length toward the back. It used to turn about Z, which swung a
-- single thin slab ACROSS the lid -- one straight bar either way, reported
-- as exactly that. The hinge sits forward of centre so the lowered pole
-- ends at the box's back edge rather than hanging off it.
Decor.MAILBOX_FLAG_HINGE = CFrame.new(-1.08, 4.6, 1.0)
-- Lowered, the pole lies 88 degrees back: not quite flat, so it reads as
-- folded down rather than as a stripe painted on the box.
Decor.MAILBOX_FLAG_DOWN = math.rad(-88)

-- WHERE EVERY PIECE OF THE FLAG SITS, IN THE HINGE'S OWN FRAME (up = +Y
-- along the pole, +Z toward the road). One table, read by the builder and
-- by `poseMailboxFlag`, so raising it cannot leave a piece behind.
--
-- A POLE AND A PENNANT, NOT A BAR. The pole is thin; the flag proper is a
-- broad panel at its top, sticking out toward the ROAD so it is the first
-- thing a player walking along the pavement sees. The panel is two halves
-- kinked a few degrees against each other, so it reads as cloth rather than
-- a sign board -- and 2.0 x 1.25 against the old 0.75-wide slab, so it reads
-- from across the street.
--
-- CLEARANCES, MEASURED AGAINST `buildMailbox`: everything sits at x -1.08
-- or further out, against a body 0.95 and a lid 0.91 wide, so no piece can
-- enter the box at any angle. Raised, the cloth flies forward past the
-- door toward the road. Lowered, the pole ends 0.25 behind the box's back
-- face and the cloth stands up beside the side face.
local FLAG_POLE = 2.6
local FLAG_W, FLAG_H = 2.0, 1.25
Decor.MAILBOX_FLAG_PIECES = {
	{ name = "MailFlag", size = Vector3.new(0.14, FLAG_POLE, 0.18),
		offset = CFrame.new(0, FLAG_POLE / 2, 0), colour = "post" },
	{ name = "MailFlagKnob", size = Vector3.new(0.22, 0.22, 0.22),
		offset = CFrame.new(0, FLAG_POLE + 0.06, 0), colour = "gold", ball = true },
	{ name = "MailFlagCloth", size = Vector3.new(0.1, FLAG_H, FLAG_W / 2 + 0.04),
		offset = CFrame.new(0, FLAG_POLE - FLAG_H / 2 - 0.08, FLAG_W / 4 + 0.05)
			* CFrame.Angles(0, math.rad(-6), 0), colour = "flag" },
	{ name = "MailFlagTail", size = Vector3.new(0.1, FLAG_H * 0.86, FLAG_W / 2),
		offset = CFrame.new(-0.1, FLAG_POLE - FLAG_H / 2 - 0.12, FLAG_W * 0.75 + 0.03)
			* CFrame.Angles(0, math.rad(4), 0), colour = "flag" },
	-- A white band across the cloth: the one detail that makes a red
	-- rectangle read as a FLAG from forty studs, not a red tile.
	{ name = "MailFlagStripe", size = Vector3.new(0.12, FLAG_H * 0.2, FLAG_W / 2 + 0.02),
		offset = CFrame.new(0, FLAG_POLE - FLAG_H / 2 - 0.08, FLAG_W / 4 + 0.05)
			* CFrame.Angles(0, math.rad(-6), 0), colour = "stripe" },
}

-- Puts every flag piece where the hinge says. `hinge` is the hinge in
-- WORLD space, unrotated; `up` raises it.
function Decor.poseMailboxFlag(pieces: { any }, hinge: CFrame, up: boolean)
	local turned = hinge * CFrame.Angles(if up then 0 else Decor.MAILBOX_FLAG_DOWN, 0, 0)
	for _, piece in ipairs(pieces) do
		piece.part.CFrame = turned * piece.offset
	end
end

function Decor.buildMailbox(base: CFrame, parent: Instance): { [string]: any }
	local function piece(name: string, size: Vector3, cf: CFrame, colour: Color3,
		material: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Anchored = true
		-- The verge is ground a thief runs across and a dog patrols beside,
		-- so nothing decorative out here may body-block either, and nothing
		-- may eat a raycast meant for a piggy.
		p.CanCollide = false
		p.CanQuery = false
		-- SHADOW OFF, WHICH IS A CHANGE TO THE PLOT'S OWN MAILBOX AND IS
		-- STATED RATHER THAN SLIPPED IN. Everything else standing on this
		-- verge -- the lamp posts, the bins, the trees, the shops -- already
		-- carries it, and the plot's five mailbox parts were the odd ones out
		-- only because `signPart` never set the property at all.
		p.CastShadow = false
		p.Color = colour
		p.Material = material
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = parent
		return p
	end

	local post = piece("MailPost", Vector3.new(0.45, 4.2, 0.45),
		base * CFrame.new(0, 2.1, 0), Decor.MAILBOX_POST, Enum.Material.Wood)
	local body = piece("MailBody", Vector3.new(1.9, 1.5, 2.7),
		base * CFrame.new(0, 4.95, 0), Decor.MAILBOX_SHELL, Enum.Material.SmoothPlastic)

	-- THE ROUNDED TOP IS A CYLINDER LYING ALONG THE BOX'S LENGTH, half sunk
	-- into it -- and a Roblox cylinder's AXIS IS ITS X, with Size.X the
	-- length and Y/Z the cross-section. Written the other way round it comes
	-- out a disc as wide as the height was tall, which is a mistake this
	-- project has now made five times.
	--
	-- AND IT IS SET INSIDE THE BOX'S OWN CROSS-SECTION, WHICH IT WAS NOT.
	-- At 2.7 long it was EXACTLY the body's depth, so its two flat end caps
	-- sat in the body's own end planes -- same depth, same facing, real
	-- overlap, which is the coplanar flicker this project has now fixed at a
	-- hundred sites across the houses. At 1.9 across it was exactly the
	-- body's width too, so the curved side was TANGENT to the body's side
	-- plane along a line landing on the body's top edge, which is the
	-- near-tangent speckle the piggy's eye outline records. Neither was
	-- introduced by sharing this builder; both were on ten mailboxes and are
	-- now on twenty, which is why they are worth the four hundredths.
	--
	-- 2.58 by 1.82 puts the caps 0.06 inside the ends and the tangent 0.04
	-- inside the sides, and the centre lifts to 5.78 so the widest line
	-- clears the body's top plane rather than sitting in it. The lid still
	-- stands 0.99 proud, which is the whole silhouette.
	local lid = piece("MailLid", Vector3.new(2.58, 1.82, 1.82),
		base * CFrame.new(0, 5.78, 0) * CFrame.Angles(0, math.rad(90), 0),
		Decor.MAILBOX_SHELL, Enum.Material.SmoothPlastic)
	lid.Shape = Enum.PartType.Cylinder

	-- The door, on the face turned toward the road. SUNK 0.09 INTO THE BODY
	-- rather than laid flush on it: a detail sized to land exactly on the
	-- face it stands on shares that face's plane over the whole overlap,
	-- which is the strobing seam this project fixed at a hundred sites across
	-- the houses. Anything standing on something sinks about a tenth of a
	-- stud into it.
	local door = piece("MailDoor", Vector3.new(1.55, 1.2, 0.12),
		base * CFrame.new(0, 5.0, 1.32), Decor.MAILBOX_DOOR, Enum.Material.SmoothPlastic)

	-- Built AT REST, lying along the box. A caller with something to say
	-- raises it; a caller with nothing to say -- the street furniture at the
	-- kerb, which has no daily reward behind it -- leaves it exactly here,
	-- which is the honest picture of an empty postbox.
	local colours = {
		post = Color3.fromRGB(70, 66, 62), gold = Color3.fromRGB(232, 184, 72),
		flag = Decor.MAILBOX_FLAG, stripe = Color3.fromRGB(246, 238, 222),
	}
	local flagPieces = {}
	for _, spec in ipairs(Decor.MAILBOX_FLAG_PIECES) do
		local part = piece(spec.name, spec.size, CFrame.new(), colours[spec.colour],
			Enum.Material.SmoothPlastic)
		if spec.ball then
			part.Shape = Enum.PartType.Ball
		end
		table.insert(flagPieces, { part = part, offset = spec.offset })
	end
	Decor.poseMailboxFlag(flagPieces, base * Decor.MAILBOX_FLAG_HINGE, false)

	return { post = post, body = body, lid = lid, door = door,
		flag = flagPieces[1].part, flagPieces = flagPieces :: any }
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

-- WHAT A TROPHY IS A PICTURE OF, WHEN NOBODY HAS SAID.
--
-- A shop card renders the real item through the same builders a lawn
-- does, and a trophy's builder needs numbers no card has: how many skins
-- have been robbed, how much has been stolen, which plinth is standing.
-- So a missing state is a SHOWROOM rather than an empty case.
--
-- IT IS DELIBERATELY MODEST. The card is advertising something nobody
-- has earned yet, and a full shelf on it would be a promise the game
-- has not made -- the same reason the crate cards draw their odds to
-- scale rather than leading with the legendary. Three pigs and a third
-- of each ladder says what the object IS without claiming it is yours.
--
-- The skins are the catalogue's own first three by key, so the card is
-- the same card on every machine and in every session. A random three
-- would make the shop tile flicker between renders for no reason a
-- player could name.
local function showroom(): any
	-- Off the SAME pool a neighbour's pig draws from, which means anything
	-- earned elsewhere is out. A pass skin standing on a shop card advertising
	-- a trophy would imply that robbing somebody could get you one, which is
	-- exactly what a paid exclusive must never look like.
	local keys = {}
	for key, spec in pairs(Config.SKINS) do
		if not Config.isEarnedElsewhere(spec) then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	return {
		victims = { keys[1], keys[2], keys[3] },
		skinTotal = #keys,
		stolen = 400000,
		caught = 3,
		escapes = 2,
		bestSpree = 5,
		rank = 2,
		clean = 40,
		seasonBest = 8,
		wanted = 4,
		plinth = "",
	}
end


-- ============================================================
-- THE GARDEN
-- ============================================================
--
-- Three plot-wide cosmetics that consume no ornament slot -- see
-- `Config.BORDER_PLANTS` for why that is the whole point of them. Each takes
-- geometry the plot already has and dresses it: the fence line, the gate
-- walk, and the windows of whatever house is standing.
--
-- They build into their OWN models rather than into the decor model, because
-- they are rebuilt on different events. An ornament changes when somebody
-- buys one; a border changes when the FENCE does, and a window box when the
-- HOUSE does. Sharing a model would mean rebuilding forty ornaments to
-- repaint a planter, and -- worse -- would put the border's lifetime in the
-- hands of `setDecor`, which is called on a plot whose fence may not have
-- been built yet.

-- AN ELLIPSOID, WHICH IS THE ONE SHAPE A `Ball` PART WILL NOT GIVE YOU.
--
-- Three balls sized (6,6,6), (12,6,6) and (6,12,6) render pixel-identical --
-- this project measured that once and reached for a `UnionOperation` to get
-- round it. A `SpecialMesh` with `MeshType.Sphere` takes a non-uniform
-- `Scale` and is the far cheaper escape for a shape that is only a stretched
-- sphere: one part, no CSG, no server-only template to prewarm and clone past
-- the client, and no seam anywhere on it because there is only one surface.
--
-- WHY A BORDER NEEDS ONE: the band a plant has to live in is 1.75 studs deep
-- (see `BORDER_BAND` below) and a rose bush is a four-stud ball. Round, it
-- either grows through the fence or stands in the ornament beside it; flattened
-- across the run it is the same bush from the one angle anybody looks at it.
local function blob(name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material): Part
	local p = part(name, Vector3.new(1, 1, 1), cf, colour, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = size
	mesh.Parent = p
	return p
end

-- HOW DEEP A BORDER PLANT MAY BE, ACROSS ITS OWN RUN.
--
-- This is the one number in the garden that is a CLEARANCE rather than a
-- taste, and it is derived from the two things already standing where a
-- border goes. The side fences run at `PLOT_HALF_WIDTH` 33.60 and the outer
-- ornament slots sit at x +-25; the widest ornament in the game is the Shark
-- In Trainers at 13.70, so an ornament in a side slot reaches 31.85. That
-- leaves 1.75 studs, and a plant deeper than it either grows through the
-- fence or stands inside whatever the owner put on their shelf.
--
-- THE BORDER CANNOT SIMPLY MOVE INWARD TO GET MORE ROOM, which is the
-- tempting fix and is the one that quietly breaks the height guarantee.
-- `Config.borderHeight` clamps a plant to the fence's own `decorTop` and the
-- proof is that a plant ON THE FENCE LINE occludes exactly what a fence of
-- that height occludes. Move it toward the pig and that stops being true --
-- a nearer occluder of the same height hides MORE of the animal, because the
-- sightline over its top lands higher up the pig. So the plant is what gives
-- way, not its position.
-- 1.4 rather than the 1.75 the band allows, because the clearance has to
-- survive the ROUNDING as well as the arithmetic: at 1.6 a Box Hedge's inner
-- face measured 31.80 against an ornament reaching 31.85, which is a fail by
-- five hundredths and is exactly the kind of margin this project has recorded
-- shipping twice -- a label reporting `TextFits` true while touching its own
-- frame, and a tab clearing its rail by one pixel.
local BORDER_BAND = 1.4

-- HOW FAR A PLANT REACHES ALONG ITS OWN RUN, measured from its centre.
--
-- A RUN ENDS ON THE FENCE CORNER, SO THE END PLANT OVERHANGS IT BY EXACTLY
-- THIS. Measured on the first build: a Box Hedge reached |x| 34.21 against a
-- fence line at 33.60 and z 26.21 against a front line at 25.60 -- the same
-- 0.61 at both, which is a hedge box's own half-length, growing out through
-- the fence it was bought to stand beside.
--
-- Derived per style rather than solved once, because the styles do not agree
-- about what their footprint IS: a hedge's is a function of the SPACING (its
-- box is sized to overlap its neighbour), a rose bush's is a function of the
-- clamped HEIGHT (it is a ball), and a lavender spike's is neither. A single
-- constant would be right for one of them and would fail silently on the
-- other two -- the shape of the `Bigger Sack` rungs and the vault opening,
-- both solved at one end of a range and left wrong at the other.
local function footprint(spec: any, up: number): number
	local style = spec.style
	if style == "hedge" then
		return spec.spacing * 0.67
	elseif style == "spikes" then
		return 0.5
	elseif style == "tall" then
		-- The leaf, not the stalk: it is 2.0 long and is what actually sticks
		-- out sideways.
		return 1.0
	end
	-- "bush": a ball of `up * 0.95`.
	return up * 0.475
end

-- ONE PLANT. `up` is the clamped height from `Config.borderHeight`, so
-- nothing in here has to know about a fence at all.
local function plant(spec: any, at: CFrame, up: number)
	local style = spec.style
	if style == "hedge" then
		-- A hedge is a RUN rather than a row of bushes, so its box is sized to
		-- overlap its neighbour by a third of the spacing. Butted exactly, the
		-- seams read as a line of separate blocks -- and worse, two boxes
		-- meeting at one plane is the coplanar flicker this project has now
		-- recorded on the road, the moat, the dog's eyes and every rebuilt
		-- house.
		part("Hedge", Vector3.new(spec.spacing * 1.34, up, BORDER_BAND),
			at * CFrame.new(0, up / 2, 0), spec.leaf, Enum.Material.Grass)
		return
	end

	if style == "spikes" then
		-- A STEM AND ONE HEAD, AND THE HEAD IS A STRETCHED SPHERE RATHER THAN A
		-- CONE.
		--
		-- `cone` is five parts -- four shrinking discs and a tip ball -- which
		-- is the right trade for a gnome's hat, of which there is one on a
		-- lawn, and the wrong one for something that repeats forty-eight times
		-- around a fence. Measured: a lavender border came to 288 parts against
		-- a Box Hedge's 60, for a shape nobody is standing close enough to
		-- count the facets of. As a `blob` it is one part and 96 for the run.
		--
		-- IT ALSO OVERSHOT ITS OWN CLAMP, which is the half that mattered.
		-- `cone` takes its CFrame as the BASE and adds a tip ball on top, so a
		-- head standing at `up * 0.55` with a body of `up * 0.5` reached
		-- `up * 1.05` plus the tip -- measured at 2.83 against a cap of 2.60,
		-- which is a border poking over the fence that is supposed to bound it.
		-- A blob is centred, so its top is arithmetic rather than a stack.
		part("Stem", Vector3.new(0.7, up * 0.5, 0.7),
			at * CFrame.new(0, up * 0.25, 0), spec.leaf, Enum.Material.Grass)
		local headH = up * 0.52
		blob("Bloom", Vector3.new(1.0, headH, math.min(1.0, BORDER_BAND)),
			at * CFrame.new(0, up - headH / 2, 0), spec.bloom, Enum.Material.Grass)
		return
	end

	if style == "tall" then
		-- A sunflower is a STALK and a FACE, and the face is what has to clear
		-- the leaves or it reads as a ball dropped in a bush.
		cylinderY("Stalk", up * 0.82, 0.42, at * CFrame.new(0, up * 0.41, 0),
			spec.leaf, Enum.Material.Grass)
		part("Leaf", Vector3.new(2.0, 0.28, 0.9),
			at * CFrame.new(0, up * 0.5, 0) * CFrame.Angles(0, 0, math.rad(18)),
			spec.leaf, Enum.Material.Grass)
		-- The face is the widest thing on a sunflower and was therefore the
		-- part deciding the whole border's clearance: round, it measured an
		-- inner face of exactly 31.85 against an ornament reaching 31.85, which
		-- is a pass by nothing at all. Flattened to the band like the bush, it
		-- clears by 0.05 and is the same flower from the pavement.
		-- SEATED SO ITS TOP LANDS ON `up`, not at a fraction of it.
		--
		-- The face is a FIXED 1.5 across and the clamp is not, so a proportional
		-- placement overshoots at the short end: at `up * 0.88` it measured 4.45
		-- against a cap of 4.20 on a rickety fence and cleared it comfortably on
		-- a moat. A flower is the same size on every fence and it is where it
		-- SITS that has to give -- the same call the window box makes when it
		-- takes its width from the sill rather than from a constant.
		local faceD = 1.5
		blob("Face", Vector3.new(faceD, faceD, math.min(faceD, BORDER_BAND)),
			at * CFrame.new(0, up - faceD / 2, 0), spec.bloom, Enum.Material.SmoothPlastic)
		return
	end

	-- "bush": a mound with two heads on it, FLATTENED ACROSS THE RUN.
	--
	-- Full width and height and only its depth given up, so from the pavement
	-- -- which is the one angle a border is ever read from -- it is the same
	-- bush a round one would have been. A `Ball` cannot do this at any size,
	-- which is what `blob` is for.
	local d = up * 0.95
	blob("Bush", Vector3.new(d, d, math.min(d, BORDER_BAND)),
		at * CFrame.new(0, up * 0.42, 0), spec.leaf, Enum.Material.Grass)
	ball("Bloom", 0.8, at * CFrame.new(-0.5, up * 0.78, 0.2), spec.bloom, Enum.Material.SmoothPlastic)
	ball("Bloom", 0.7, at * CFrame.new(0.55, up * 0.66, -0.2), spec.bloom, Enum.Material.SmoothPlastic)
end

-- PLANTS ALONG THE FENCE LINE.
--
-- `runs` are plot-local segments `{a, b}` and they are the caller's business
-- rather than this file's, because WHICH stretches of fence are worth
-- planting is a fact about where a viewer stands -- see `PlotService`.
function Decor.buildBorder(spec: any, up: number, runs: { { a: Vector3, b: Vector3 } },
	originCF: CFrame, groundY: number, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Border"
	folder = model

	for _, run in ipairs(runs) do
		local delta = run.b - run.a
		local full = delta.Magnitude
		-- PULLED IN AT BOTH ENDS BY THE PLANT'S OWN REACH, so a border stops AT
		-- the fence corner rather than growing through it. What it costs is a
		-- small gap where two runs meet, which reads as a corner rather than as
		-- a mistake -- and is the honest picture anyway, since a real border is
		-- planted inside a boundary rather than welded to it.
		local reach = footprint(spec, up)
		local length = full - reach * 2
		if length > 0.01 then
			local dir = delta.Unit
			run = { a = run.a + dir * reach, b = run.b - dir * reach }
			-- Fitted to the run rather than stepped from one end, so a border
			-- starts and ends ON the fence it belongs to instead of stopping
			-- short by whatever the remainder happened to be. The same reason
			-- the fence panels are stretched to tile their own span exactly.
			local count = math.max(1, math.floor(length / spec.spacing))
			local step = length / count
			-- TURNED TO FACE ALONG ITS OWN RUN, AND EVERY PLANT IS AUTHORED IN
			-- THAT FRAME RATHER THAN IN THE PLOT'S.
			--
			-- The first build did not do this and the hedge was the thing that
			-- showed it: its box is `spacing * 1.34` long so that consecutive
			-- boxes overlap into a run, and with no rotation that length is
			-- always on X -- correct on the two FRONT wings, which run along X,
			-- and lying broadside across the fence on the two SIDES, which do
			-- not. Measured before the fix: the border reached |x| 34.21 against
			-- a fence line at 33.60, so a hedge bought for a lawn was standing
			-- through its own fence and out over the alley.
			--
			-- Solved here rather than in each style, so a plant added later is
			-- authored once, along +X, and is correct on every run by
			-- construction. A rotation about Y by `t` maps local +X to
			-- (cos t, 0, -sin t), so aligning that with `dir` is atan2(-Z, X).
			local yaw = math.atan2(-dir.Z, dir.X)
			for i = 0, count do
				local at = run.a + dir * (step * i)
				plant(spec, originCF
					* CFrame.new(at + Vector3.new(0, groundY, 0))
					* CFrame.Angles(0, yaw, 0), up)
			end
		end
	end

	model.Parent = parent
	return model
end

-- THE WALK FROM THE GATE TO THE PIG.
--
-- Laid along plot-local +Z on the centre line, because that is where the gate
-- is and where the piggy is. It stops short of both: a slab under the gate
-- post would read as pavement rather than as a garden path, and one under the
-- pig would be hidden by the animal standing on it.
function Decor.buildPath(spec: any, fromZ: number, toZ: number,
	originCF: CFrame, groundY: number, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "GardenPath"
	folder = model

	local pitch = spec.slab + spec.gap
	local span = fromZ - toZ
	if span > pitch then
		local count = math.max(1, math.floor(span / pitch))
		local step = span / count
		for i = 0, count do
			local z = fromZ - step * i
			part("Slab", Vector3.new(spec.width, 0.2, spec.slab),
				originCF * CFrame.new(0, groundY + Config.GARDEN_PATH_LIFT, z),
				spec.colour, spec.material)
		end
	end

	model.Parent = parent
	return model
end

-- WINDOW BOXES, HUNG ON A HOUSE THAT IS ALREADY BUILT.
--
-- A POST-PASS RATHER THAN AN ARGUMENT THREADED THROUGH NINE TIER BUILDERS --
-- see `Config.WINDOW_BOXES` for that trade in full. It finds its own windows
-- by walking for the name `LowPoly.framedWindow` gives every ledge in the
-- game, which means a tier added later gets boxes for free and a tier that
-- stops using the toolkit correctly gets none rather than getting them in the
-- wrong place.
--
-- GROUND FLOOR ONLY, and the floor is DERIVED from the sills that are
-- actually there rather than from a height anybody typed: the lowest sill on
-- the building sets the rank, and everything within a storey of it belongs to
-- it. A pinned Y would be wrong on nine tiers of different heights, and would
-- be wrong again the first time one of them moved.
function Decor.buildWindowBoxes(spec: any, house: Instance, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "WindowBoxes"
	folder = model

	local sills = {}
	local lowest = math.huge
	for _, d in ipairs(house:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Sill" then
			table.insert(sills, d)
			if d.Position.Y < lowest then
				lowest = d.Position.Y
			end
		end
	end

	-- A STOREY, not a tolerance. Window ranks on these tiers are a floor
	-- apart, so anything within one of the lowest sill is on the ground floor
	-- and anything above it is not -- which survives a tier whose ground floor
	-- is taller than another's.
	local STOREY = 7
	for _, sill in ipairs(sills) do
		if sill.Position.Y <= lowest + STOREY then
			-- Sized off the sill it hangs from rather than off a constant: a
			-- sill is `w + 1.8` wide and w varies by tier, so a fixed box is
			-- narrower than the window on one building and wider on the next.
			local w = sill.Size.X * 0.86
			local at = sill.CFrame * CFrame.new(0, -0.52, 0.22)
			part("Box", Vector3.new(w, 0.72, 1.05), at, spec.box, Enum.Material.SmoothPlastic)
			-- The planting stands PROUD of its box, because the box is the
			-- thing with the hard edge and the eye takes the highest line as
			-- the surface -- the moat's kerb rule at a fortieth of the scale.
			part("Foliage", Vector3.new(w * 0.9, 0.5, 0.9), at * CFrame.new(0, 0.5, 0),
				spec.leaf, Enum.Material.Grass)
			local heads = math.max(2, math.floor(w / 1.6))
			for i = 1, heads do
				local t = (i - 0.5) / heads - 0.5
				ball("Bloom", 0.52, at * CFrame.new(t * w * 0.82, 0.78, 0),
					spec.bloom, Enum.Material.SmoothPlastic)
			end
		end
	end

	model.Parent = parent
	return model
end

-- `size` is "monument" (the default, and the geometry this has always built)
-- or "keepsake" -- see `trophySize` at the top for what the difference is and
-- why it is a size rather than a scale factor. Only the trophies read it.
function Decor.buildOne(key: string, at: CFrame, parent: Instance, state: any?,
	size: string?): Model?
	local item = Config.DECOR_ITEMS[key]
	local build = item and builders[item.style]
	if not build then
		return nil
	end

	local model = Instance.new("Model")
	model.Name = "Prop_" .. key
	folder = model
	trophyState = state or showroom()
	trophySize = size or "monument"
	-- A shop card has no owner, so the topiary on one is clipped in the skin
	-- every save starts with rather than in nobody's.
	skinKey = Config.DEFAULT_SKIN

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
-- `state` is what the four TROPHIES read and the eighteen ornaments
-- ignore -- see `showroom` above for what a nil one means and why a card
-- may pass none.
function Decor.build(placed: { [string]: string }, originCF: CFrame,
	groundByZone: { [string]: number }, parent: Instance, state: any?, skin: string?): Model
	local model = Instance.new("Model")
	model.Name = "Decor"
	folder = model
	trophyState = state or showroom()
	-- SET RATHER THAN LEFT, for the reason `skinKey` below is: these are
	-- upvalues, so whatever the LAST caller asked for is what this one gets if
	-- it does not say. A shop card rendering a lawn ornament after a trophy
	-- room had been filled would otherwise draw a plinthless keepsake.
	trophySize = "monument"
	-- A SIXTH ARGUMENT HERE AND DELIBERATELY NOT A SIXTH ONE ON `setDecor`.
	-- That function has five callers across four services and this file's
	-- parent records the decision not to grow its signature: a missed
	-- positional argument reads as nil, which is a silent EMPTY on a lawn
	-- nobody would think to check. `Decor.build` has exactly one caller, so
	-- the same argument does not apply to it -- the plot holds the skin and
	-- `setDecor` passes it on.
	skinKey = skin or Config.DEFAULT_SKIN

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
