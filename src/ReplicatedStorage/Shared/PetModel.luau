--!strict
--[[
	PetModel -- the little thing that trots after you.

	A pet CONFERS NOTHING. It is the same line houses already hold and it is
	the reason this can be sold for Robux at all: it changes no speed, no
	take, no cooldown and no chance, so there is nothing here for a paid
	product to buy that a coin player cannot have.

	IT MAY NEVER READ AS A GUARD DOG, WHICH IS THE ONE HARD CONSTRAINT ON
	EVERY SHAPE IN THIS FILE. The dog's POSTURE is a tell a thief reads from
	the pavement before committing -- up and trotting means somebody is home,
	curled up means the house is empty -- and it is the only signal the whole
	approach rests on. A second animal wandering a lawn would blur it, so:

	  * no nameplate. The dog has one, reading ON GUARD or OFF DUTY, and it
	    is half of what makes the dog legible from outside the fence.
	  * no collar, for the same reason -- the duty vest and the collar are
	    the dog's own vocabulary.
	  * no bark. This game has exactly ONE noise that means "a dog has seen
	    me", deliberately, and a bought object making it for no reason would
	    train players to ignore the real one.
	  * and no dog-shaped pets. Two of the four HOVER, which nothing in this
	    game's canine vocabulary does.

	The strongest separator is not visual at all and is worth stating because
	it is what makes the rest safe: A DOG IS ON A PLOT AND A PET IS BESIDE A
	PLAYER. A guard dog never leaves its yard -- `clampToYard` holds every
	destination inside the fence rectangle -- and a pet is never anywhere but
	at its owner's heel. The two can only be confused by somebody who is not
	looking at where they are.

	Geometry only. Where a pet GOES is `Shared/Pets.luau`, which runs on the
	client for the reason the animated skins and the moat do -- see the header
	there.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local PetModel = {}

local folder: Model

-- EVERY PART IS NON-COLLIDING, NON-QUERYABLE AND CASTS NO SHADOW, and the
-- first two of those are gameplay rules rather than housekeeping.
--
-- A pet stands on the exact ground a chase runs across. One that collided
-- could body-block a thief, a defender or the dog -- which is a cosmetic
-- changing an outcome, the one thing the whole yard plan forbids -- and one
-- that answered a query could eat a raycast meant for a piggy. Same rule
-- every lawn ornament and all 1,400 grass tufts already follow.
local function part(name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Color = colour
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder
	return p
end

local function ball(name: string, size: number, cf: CFrame, colour: Color3, material: Enum.Material): Part
	local p = part(name, Vector3.new(size, size, size), cf, colour, material)
	p.Shape = Enum.PartType.Ball
	return p
end

-- A stretched sphere, which a `Ball` will not give you -- three balls sized
-- (6,6,6), (12,6,6) and (6,12,6) render pixel-identical. A `SpecialMesh` with
-- `MeshType.Sphere` takes a non-uniform Scale and costs one part, where the
-- `UnionOperation` this project used to reach for costs a server-only
-- template and a prewarm.
local function blob(name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material): Part
	local p = part(name, Vector3.new(1, 1, 1), cf, colour, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = size
	mesh.Parent = p
	return p
end

-- A cylinder standing upright. Roblox cylinders have their flat faces on X,
-- so an upright one is rolled 90 degrees about Z and takes its length from
-- the X component -- the gotcha this project has now hit six times, most
-- memorably as a neon rod standing out of somebody's skull.
local function cylinderY(name: string, height: number, diameter: number, cf: CFrame,
	colour: Color3, material: Enum.Material): Part
	local p = part(name, Vector3.new(height, diameter, diameter),
		cf * CFrame.Angles(0, 0, math.rad(90)), colour, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- TWO EYES, AND THEY ARE WHAT MAKE ANY OF THESE READ AS A CREATURE.
--
-- Every ornament in this game with a face got one for the same reason: a face
-- is what makes an object a character rather than a prop. On something four
-- studs long it is also the cheapest detail available -- four parts against a
-- silhouette nobody would otherwise look at twice.
local function eyes(at: CFrame, spread: number, y: number, z: number, size: number)
	for _, side in ipairs({ -1, 1 }) do
		ball("Eye", size, at * CFrame.new(side * spread, y, z),
			Color3.fromRGB(250, 250, 250), Enum.Material.SmoothPlastic)
		ball("Pupil", size * 0.52, at * CFrame.new(side * spread, y, z + size * 0.3),
			Color3.fromRGB(24, 24, 28), Enum.Material.SmoothPlastic)
	end
end

local builders: { [string]: (any, CFrame) -> () } = {}

-- THE PIGLET. Thematic, and the shape furthest from a guard dog that this
-- game already knows how to draw.
--
-- Built from primitives here rather than from `PiggyModel`, deliberately.
-- That module builds the twelve-stud animal every skin, accessory, vault
-- hatch and coin pile is cut against, and borrowing it would tie a pet to a
-- mesh pipeline and a 46-skin colour system for a four-stud ornament -- and
-- would put a SECOND pig-shaped thing inside the system that paints the
-- first. A piglet is a piglet; it is not a small piggy bank.
builders.piglet = function(spec, at)
	local body, trim = spec.body, spec.trim
	blob("Body", Vector3.new(2.2, 1.9, 2.9), at * CFrame.new(0, 1.15, 0), body, Enum.Material.SmoothPlastic)
	ball("Head", 1.5, at * CFrame.new(0, 1.45, 1.35), body, Enum.Material.SmoothPlastic)
	-- The snout is the piglet's whole identity, so it stands well proud --
	-- half in and half out, which is the ratio that stops a ball on a face
	-- reading as a ball stuck on a face.
	blob("Snout", Vector3.new(0.75, 0.6, 0.5), at * CFrame.new(0, 1.32, 2.02), trim, Enum.Material.SmoothPlastic)
	for _, side in ipairs({ -1, 1 }) do
		part("Ear", Vector3.new(0.42, 0.5, 0.22),
			at * CFrame.new(side * 0.48, 2.05, 1.28) * CFrame.Angles(0, 0, math.rad(side * 14)),
			trim, Enum.Material.SmoothPlastic)
		for _, front in ipairs({ 0.85, -0.75 }) do
			part("Leg", Vector3.new(0.42, 0.72, 0.42),
				at * CFrame.new(side * 0.62, 0.36, front), trim, Enum.Material.SmoothPlastic)
		end
	end
	-- A curl rather than a stub: three small balls stepping round is what
	-- reads as a pig's tail at this size, where one ball reads as a lump.
	for i = 0, 2 do
		ball("Tail", 0.3 - i * 0.05,
			at * CFrame.new(math.sin(i * 1.5) * 0.22, 1.6 + i * 0.16, -1.42 - i * 0.06),
			trim, Enum.Material.SmoothPlastic)
	end
	eyes(at, 0.42, 1.62, 1.92, 0.26)
end

-- THE DUCKLING. Small, round and yellow -- the second cheapest thing to
-- build here and the one that reads at the greatest distance, because a
-- saturated yellow against grass is the highest-contrast pet in the set.
builders.duckling = function(spec, at)
	local body, trim = spec.body, spec.trim
	blob("Body", Vector3.new(1.8, 1.7, 2.2), at * CFrame.new(0, 1.0, 0), body, Enum.Material.SmoothPlastic)
	ball("Head", 1.25, at * CFrame.new(0, 1.85, 0.62), body, Enum.Material.SmoothPlastic)
	blob("Beak", Vector3.new(0.62, 0.3, 0.7), at * CFrame.new(0, 1.72, 1.28), trim, Enum.Material.SmoothPlastic)
	for _, side in ipairs({ -1, 1 }) do
		part("Foot", Vector3.new(0.5, 0.18, 0.62), at * CFrame.new(side * 0.36, 0.12, 0.3),
			trim, Enum.Material.SmoothPlastic)
		-- A wing each side, angled off the body so the silhouette is not just
		-- an egg. Flat and thin, because a duckling's wing is.
		part("Wing", Vector3.new(0.22, 0.62, 1.1),
			at * CFrame.new(side * 0.88, 1.05, -0.05) * CFrame.Angles(0, 0, math.rad(side * -12)),
			body, Enum.Material.SmoothPlastic)
	end
	eyes(at, 0.34, 2.0, 1.08, 0.24)
end

-- THE BUMBLEBEE. The first of the two that HOVER, which is most of why it is
-- in the set: nothing in this game's guard-dog vocabulary leaves the ground,
-- so a hovering pet cannot be mistaken for one at any distance.
builders.bee = function(spec, at)
	local body, trim = spec.body, spec.trim
	blob("Body", Vector3.new(1.5, 1.4, 2.0), at * CFrame.new(0, 2.2, 0), body, Enum.Material.SmoothPlastic)
	-- Stripes as rings around the body rather than as painted bands, because
	-- there is nothing to paint on: this project has no textures on anything
	-- it builds in code, on purpose.
	for i = -1, 1 do
		blob("Stripe", Vector3.new(1.56, 1.46, 0.34),
			at * CFrame.new(0, 2.2, i * 0.55), trim, Enum.Material.SmoothPlastic)
	end
	ball("Head", 1.0, at * CFrame.new(0, 2.28, 1.15), trim, Enum.Material.SmoothPlastic)
	for _, side in ipairs({ -1, 1 }) do
		-- Wings are translucent rather than solid: a bee's wing is the one
		-- part of it you see through, and at 0.55 it still catches the sun.
		local wing = blob("Wing", Vector3.new(0.12, 0.9, 1.5),
			at * CFrame.new(side * 0.75, 2.85, -0.1) * CFrame.Angles(0, 0, math.rad(side * -28)),
			Color3.fromRGB(226, 240, 248), Enum.Material.SmoothPlastic)
		wing.Transparency = 0.55
		part("Antenna", Vector3.new(0.08, 0.5, 0.08),
			at * CFrame.new(side * 0.24, 2.85, 1.3) * CFrame.Angles(math.rad(-18), 0, math.rad(side * 16)),
			trim, Enum.Material.SmoothPlastic)
	end
	eyes(at, 0.3, 2.4, 1.6, 0.28)
end

-- THE ROBO-PIG. The paid one, and it earns that by being the only pet whose
-- material does something: Neon eyes and a metal shell against three
-- SmoothPlastic animals.
--
-- ITS NEON IS A DEEP COLOUR AND NOT A PALE ONE, which is a rule this project
-- has now paid for four times -- a Martian skin, a lit colonnade, a rank of
-- townhouse windows and a street lamp all shipped as white holes. Neon
-- renders flat out and the BloomEffect takes it from there, so what survives
-- is SATURATION and never value.
builders.robopig = function(spec, at)
	local body, trim = spec.body, spec.trim
	blob("Shell", Vector3.new(2.0, 1.8, 2.7), at * CFrame.new(0, 2.3, 0), body, Enum.Material.Metal)
	ball("Head", 1.4, at * CFrame.new(0, 2.55, 1.3), body, Enum.Material.Metal)
	blob("Snout", Vector3.new(0.8, 0.65, 0.45), at * CFrame.new(0, 2.42, 1.95), trim, Enum.Material.Metal)
	for _, side in ipairs({ -1, 1 }) do
		part("Ear", Vector3.new(0.38, 0.46, 0.2),
			at * CFrame.new(side * 0.46, 3.12, 1.24), trim, Enum.Material.Metal)
		-- A thruster where a leg would be. It is what says this thing hovers
		-- rather than stands, which is the reading that keeps it clear of the
		-- guard dog.
		cylinderY("Thruster", 0.4, 0.5, at * CFrame.new(side * 0.62, 1.5, 0.35), trim, Enum.Material.Metal)
		local jet = cylinderY("Jet", 0.28, 0.36, at * CFrame.new(side * 0.62, 1.22, 0.35),
			spec.glow, Enum.Material.Neon)
		jet.Transparency = 0.25
		ball("EyeLamp", 0.34, at * CFrame.new(side * 0.4, 2.7, 1.9), spec.glow, Enum.Material.Neon)
	end
	for i = 0, 2 do
		ball("Tail", 0.28 - i * 0.05,
			at * CFrame.new(math.sin(i * 1.5) * 0.2, 2.7 + i * 0.15, -1.34 - i * 0.06),
			trim, Enum.Material.Metal)
	end
end

--[[
	Build one pet, unparented and unanchored to anything.

	It comes back ANCHORED, because a pet is driven by CFrame every frame
	rather than welded to anybody -- see `Shared/Pets.luau`. That is the
	opposite of what `RideModel` and `PiggyModel` return and it is the reason
	this file states it: an anchored part welded to a humanoid PINS the
	humanoid, and an unanchored part driven by CFrame falls. A builder's
	anchoring is a fact about where it was designed to go, and three displays
	fell out of a shop window the day that was assumed rather than checked.
]]
function PetModel.build(key: string, at: CFrame?): Model?
	local spec = Config.PETS[key]
	local build = spec and builders[spec.style]
	if not build then
		return nil
	end

	local model = Instance.new("Model")
	model.Name = "Pet_" .. key
	folder = model

	build(spec, CFrame.new())

	-- A PrimaryPart so the whole thing can be driven with one `PivotTo`, and
	-- the BODY rather than whatever was built first: a Model with no
	-- PrimaryPart takes its pivot from the first part created, and if that
	-- part carries a rotation -- every `cylinderY` here does -- the pivot
	-- inherits it and the bounding box comes back transposed. That has cost
	-- this project two separate decisions.
	local primary = model:FindFirstChild("Body") or model:FindFirstChild("Shell")
	if primary and primary:IsA("BasePart") then
		model.PrimaryPart = primary :: BasePart
	end
	model:PivotTo(at or CFrame.new())
	return model
end

-- What the shop card renders, and what a pet is worth in the world: the same
-- builder either way. A second, smaller version drawn for the tile is the
-- near-identical copy that drifts the first time either is touched -- which
-- is why nineteen lawn ornaments stopped being grey squares and became the
-- real thing.
function PetModel.styles(): { string }
	local out = {}
	for style in pairs(builders) do
		table.insert(out, style)
	end
	table.sort(out)
	return out
end

return PetModel
