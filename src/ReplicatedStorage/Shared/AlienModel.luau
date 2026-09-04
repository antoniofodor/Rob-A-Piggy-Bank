--!strict
--[[
	AlienModel

	The saucer, its drones and the tractor beams, built in code like everything
	else in this world.

	AN ORIGINAL, for the same reason the patrol car is one. A saucer is a
	genre rather than a property -- a disc, a dome, a ring of lights -- and the
	moment it acquires somebody's specific ship, wordmark or character the
	penalty lands on the EXPERIENCE rather than on the one prop. The joke is
	carried by the LAYOUT, so this one is a flying saucer with a pig-snout
	underside light, which is funnier than a licensed one anyway.

	NOTHING HERE IS A WEAPON AND NOTHING HERE IS HARMED. There is no gun on the
	saucer, no explosion, and a drone that loses is knocked to the grass and
	sulks until it is recalled. Roblox's maturity questionnaire is answered by
	what is actually in the model, and this audience is under twelve -- the
	same reason the officer carries no baton and the catch is a tag.

	PIVOT, AND THE TRAP IT AVOIDS. `Model:PivotTo` aims the PRIMARY PART, not
	the model's origin, so anything driven per frame by a world position sinks
	by its own anchor height. The patrol car spent every patrol 1.6 studs into
	the tarmac exactly this way. Both builders here take a GROUND-LEVEL origin
	and offset every piece up from it, and both publish the pivot offset the
	caller has to add back -- derived from the geometry tables rather than
	written out again, so the number cannot drift.

	CYLINDERS. A Roblox cylinder's axis is its X axis, so `Size.X` is the
	LENGTH along it and the other two are the cross-section. A vertical column
	is `Vector3.new(height, d, d)` plus a quarter turn about Z. Written the
	other way round it becomes a disc as wide as the height was tall, which
	this project has now shipped five times -- the beams below are the sixth
	place it could have happened.
]]

local CollectionService = game:GetService("CollectionService")

local AlienModel = {}

-- Tagged so every client can animate them without the server writing a
-- property per part per frame. Same shape as the moat, the skins and HouseFX.
AlienModel.HULL_TAG = "RaidHull"
AlienModel.BEAM_TAG = "RaidBeam"
AlienModel.DRONE_TAG = "RaidDrone"

local HULL = Color3.fromRGB(126, 136, 158)
local HULL_DARK = Color3.fromRGB(74, 82, 100)
local GLASS = Color3.fromRGB(150, 240, 210)
local GLOW = Color3.fromRGB(96, 255, 176)
local SNOUT = Color3.fromRGB(240, 150, 176)

-- Half the saucer's overall height, which is what a ground origin has to be
-- lifted by before the hull disc is where it belongs. Stated once and exported.
local HULL_THICK = 3.2

type Add = (name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?) -> Part

local function builder(model: Model): Add
	return function(name, size, cf, colour, material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Anchored = true
		-- Never solid, and never queryable. A saucer that could push a player
		-- would be a second way to move somebody, and the whole balance here
		-- is a closed system of speed, time and distance.
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
end

-- ============================================================
-- THE SAUCER
-- ============================================================

export type Saucer = { model: Model, hull: Part }

-- `originCF` is the saucer's CENTRE in the air. It is the one thing here that
-- does not take a ground origin, because a saucer has no ground contact and
-- inventing one would be a fake number for callers to add and subtract.
function AlienModel.buildSaucer(originCF: CFrame, parent: Instance): Saucer
	local model = Instance.new("Model")
	model.Name = "Saucer"
	local add = builder(model)

	-- The disc. Cylinder: LENGTH along X, so the quarter turn about Z is what
	-- lays it flat rather than what stands it up.
	local hull = add("Hull", Vector3.new(HULL_THICK, 34, 34), originCF * CFrame.Angles(0, 0, math.rad(90)),
		HULL, Enum.Material.Metal)
	hull.Shape = Enum.PartType.Cylinder

	-- A slightly wider, thinner rim just under it, so the silhouette has an
	-- edge rather than being one flat pill. Proud of the hull rather than
	-- flush: two faces at the same depth give the renderer nothing to sort by
	-- and it picks per pixel.
	local rim = add("Rim", Vector3.new(0.9, 39, 39), originCF * CFrame.new(0, -1.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
		HULL_DARK, Enum.Material.Metal)
	rim.Shape = Enum.PartType.Cylinder

	-- The dome, and a smaller one under it. A ball squashed on Y so it sits ON
	-- the disc instead of half inside it.
	local dome = add("Dome", Vector3.new(17, 11, 17), originCF * CFrame.new(0, 3.2, 0), GLASS, Enum.Material.Glass)
	dome.Shape = Enum.PartType.Ball
	dome.Reflectance = 0.3

	-- The underside light: a pig snout, because the patrol car already says
	-- PATROL over one and this is the same joke from the other side.
	local snout = add("Snout", Vector3.new(1.2, 9, 9), originCF * CFrame.new(0, -2.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
		SNOUT, Enum.Material.Neon)
	snout.Shape = Enum.PartType.Cylinder
	for _, sx in ipairs({ -1.9, 1.9 }) do
		local nostril = add("Nostril", Vector3.new(1.4, 2.4, 2.4),
			originCF * CFrame.new(sx, -2.9, 0) * CFrame.Angles(0, 0, math.rad(90)), HULL_DARK)
		nostril.Shape = Enum.PartType.Cylinder
	end

	-- A ring of lights around the rim, each carrying its own phase so the ring
	-- chases rather than blinking together. Four corners pulsing in lockstep is
	-- the one arrangement that reads as a single full-screen flash, which is
	-- also the arrangement the photosensitivity guidance is about.
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local lamp = add("RimLight", Vector3.new(2.2, 2.2, 2.2),
			originCF * CFrame.Angles(0, a, 0) * CFrame.new(0, -1.0, 17.4), GLOW, Enum.Material.Neon)
		lamp.Shape = Enum.PartType.Ball
		lamp:SetAttribute("Phase", i / 12)
		CollectionService:AddTag(lamp, AlienModel.HULL_TAG)
	end

	-- NO PRIMARYPART, AND AN EXPLICIT WORLDPIVOT. This is the trap HomeModel
	-- already writes down, met from the other side.
	--
	-- The hull is a cylinder and therefore carries a 90 degree roll of its
	-- own. Making it the PrimaryPart means the model's pivot carries that roll
	-- too, so the first `PivotTo(CFrame.new(somewhere))` -- an identity
	-- rotation -- REPLACES it, and the whole saucer rolls onto its edge and
	-- takes the dome round the side with it. Measured on the first flight:
	-- hull axis (1.00, 0.00, 0.00), which is a disc standing up like a wheel,
	-- and the dome at exactly hull height instead of above it.
	--
	-- An identity pivot at the centre means PivotTo moves everything rigidly
	-- and every relative rotation survives.
	model.WorldPivot = CFrame.new(originCF.Position)
	model.Parent = parent
	return { model = model, hull = hull }
end

-- ============================================================
-- A DRONE
-- ============================================================

export type Drone = { model: Model, body: Part }

-- How far the drone's PRIMARY PART sits above the ground origin handed in.
-- Anything driving one per frame from a ground position must add this, or the
-- drone converges on shin height in the grass -- measured on the officer at
-- -2.55 against a lawn at 0.50.
AlienModel.DRONE_PIVOT_Y = 1.5

-- `tagged` is FALSE for the lawn ornament and true for a live raid drone.
--
-- The tag is what GadgetService's target search looks for, so a Crashed Drone
-- sitting on somebody's lawn would otherwise be a valid throw target for the
-- whole server -- a decoration that eats gadgets, and a raid that can be
-- "won" by pelting an ornament.
function AlienModel.buildDrone(groundCF: CFrame, parent: Instance, tagged: boolean?): Drone
	local model = Instance.new("Model")
	model.Name = "Drone"
	local add = builder(model)

	local body = add("Body", Vector3.new(3.4, 3.0, 3.4), groundCF * CFrame.new(0, AlienModel.DRONE_PIVOT_Y, 0),
		HULL, Enum.Material.Metal)
	body.Shape = Enum.PartType.Ball

	local eye = add("Eye", Vector3.new(1.9, 1.9, 0.5), groundCF * CFrame.new(0, AlienModel.DRONE_PIVOT_Y, 1.6),
		GLOW, Enum.Material.Neon)
	eye.Shape = Enum.PartType.Ball

	-- Three legs, so a grounded one reads as landed rather than as dropped.
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2
		add("Leg", Vector3.new(1.4, 0.28, 0.28),
			groundCF * CFrame.Angles(0, a, 0) * CFrame.new(0, AlienModel.DRONE_PIVOT_Y - 1.2, 1.4)
				* CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(0, math.rad(38), 0),
			HULL_DARK, Enum.Material.Metal).Shape = Enum.PartType.Cylinder
	end

	model.PrimaryPart = body
	model.Parent = parent
	if tagged then
		CollectionService:AddTag(body, AlienModel.DRONE_TAG)
	end
	return { model = model, body = body }
end

-- ============================================================
-- A TRACTOR BEAM
-- ============================================================

-- Built as ONE cylinder spanning saucer to piggy, sized at build time. A beam
-- whose length is written every frame would be a replicated Size write per
-- beam per frame; the client tapers and scrolls it instead, from the tag.
--
-- `from` and `to` are world points. Vector3.new(LENGTH, d, d) with the length
-- on X, because that is where a cylinder's axis is.
function AlienModel.buildBeam(from: Vector3, to: Vector3, radius: number, parent: Instance): Part
	local span = (to - from)
	local length = math.max(span.Magnitude, 0.1)

	local p = Instance.new("Part")
	p.Name = "Beam"
	p.Size = Vector3.new(length, radius * 2, radius * 2)
	-- lookAt aims the LookVector, which is NEGATIVE Z, so the extra quarter
	-- turn about Y is what puts the cylinder's own X axis down the span.
	p.CFrame = CFrame.lookAt(from:Lerp(to, 0.5), to) * CFrame.Angles(0, math.rad(90), 0)
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Color = GLOW
	p.Material = Enum.Material.Neon
	p.Transparency = 0.55
	p.Parent = parent
	CollectionService:AddTag(p, AlienModel.BEAM_TAG)
	return p
end

return AlienModel
