--!strict
--[[
	ThiefModel

	Icons for the thief consumables.

	THIS DESCRIBED A RETIRED ITEM until it was caught. The Disguise Kit is
	gone -- it never worked, and the wheelie-bin fantasy it was selling is
	delivered by the public bins on the kerb, which nobody buys. The note here
	explained at length why the kit's tile showed a holdall rather than a bin,
	which is reasoning about a tile that no longer exists.

	What is left is the raincoat, and it is genuinely the object it depicts,
	so the whole problem this note was about does not arise. Kept as a builder
	because Config.THIEF_KIT is a catalogue that can grow again.

	Built around the ORIGIN and only ever seen in a ViewportFrame, so there is
	no ground line to respect here -- unlike RideModel, which is placed in the
	world and is authored feet-first.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ThiefModel = {}

type Add = (name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?) -> Part

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local builders: { [string]: (any, Add) -> () } = {}

builders.disguise = function(spec, add)
	local CANVAS = Color3.fromRGB(96, 104, 88)
	local STRAP = Color3.fromRGB(58, 46, 34)

	-- A holdall: a rounded body with a strap over it. The lumps at each end do
	-- most of the work -- a plain box reads as a crate.
	add("Bag", Vector3.new(3.0, 1.6, 1.6), CFrame.new(), CANVAS)
	for _, sx in ipairs({ 1, -1 }) do
		local endCap = add("End", Vector3.new(1.55, 1.55, 1.55), CFrame.new(sx * 1.5, 0, 0), CANVAS)
		endCap.Shape = Enum.PartType.Ball
	end

	add("Strap", Vector3.new(0.5, 1.7, 1.7), CFrame.new(-0.3, 0, 0), STRAP, Enum.Material.Leather)
	add("Handle", Vector3.new(1.4, 0.18, 0.18), CFrame.new(0, 1.0, 0), STRAP, Enum.Material.Leather)
	for _, sx in ipairs({ 0.6, -0.6 }) do
		add("Grip", Vector3.new(0.18, 0.5, 0.18), CFrame.new(sx, 0.75, 0), STRAP, Enum.Material.Leather)
	end

	-- A bin lid poking out of the top, which is the only hint on the model of
	-- what is actually inside it.
	local lid = add("Lid", Vector3.new(0.22, 1.3, 1.3), CFrame.new(0.7, 0.95, 0.2) * UPRIGHT,
		Color3.fromRGB(64, 92, 142))
	lid.Shape = Enum.PartType.Cylinder
end

-- ============================================================
-- THE LADDER
-- ============================================================
--
-- ONE GEOMETRY, THREE PLACES: the shop card, the prop in the hand, and the
-- real one standing against somebody's fence. The last of those is built by
-- PlotService at the FENCE'S OWN HEIGHT, which is why the rungs are laid out
-- from a height argument rather than baked at one size -- a ladder that was
-- authored at 7 studs and stretched to fit a taller tier would come out with
-- rungs a foot apart.
--
-- It is only ever the PICTURE. What makes it climbable is an invisible
-- TrussPart PlotService stands inside it, for the same reason the fence's
-- collision is one invisible slab behind its decoration: measured, a truss at
-- Transparency 1 is still climbed natively, rising the full 8 studs and
-- entering the Climbing state, so the mechanism and the object can be
-- separate things and the object can look like whatever it should.
local LADDER_WIDTH = 1.9
local LADDER_RUNG_GAP = 1.05

-- IT HAS TWO FACES, AND THAT IS A MEASUREMENT RATHER THAN A FLOURISH.
--
-- Measured on a live climb: a climber's root settles 2.2 to 2.6 studs from
-- the truss centre, hugging its outer face -- a truss is locked to a 2x2
-- cross-section, so that is where Roblox puts anybody climbing one and no
-- amount of thinning the picture changes it. A single flat panel on the
-- fence plane therefore leaves the climber floating two studs off the thing
-- they are visibly climbing.
--
-- So the rails sit at the truss's own faces, one set each side of the fence.
-- Which is the honest object anyway: a ladder you put over a fence to get up
-- AND down is two ladders joined at the top, and it is the only shape that
-- explains how one placement serves both ways over.
local LADDER_FACE = 0.92

local function ladderParts(add: Add, height: number)
	-- High-vis rather than realistic. A ladder against a fence is a live
	-- signal that somebody is coming over RIGHT NOW, which is a better tell
	-- than the permanent trellis it replaced ever was, and it only works if
	-- it can be picked out from the pavement against wood, wire and steel.
	local RAIL = Color3.fromRGB(238, 148, 44)
	local RUNG = Color3.fromRGB(196, 202, 210)
	local FOOT = Color3.fromRGB(46, 50, 58)

	local halfW = LADDER_WIDTH / 2 - 0.09

	-- Rungs are laid from the TOP down, so the top one always lands at the
	-- top of the rails whatever height this is built at. Counting up from the
	-- foot instead leaves a ragged gap at the top on every fence tier but
	-- one, which is exactly the end somebody is looking at while they mantle.
	local rungs = math.max(2, math.floor((height - 0.6) / LADDER_RUNG_GAP))
	local topY = height / 2 - 0.35

	for _, sz in ipairs({ 1, -1 }) do
		for _, sx in ipairs({ 1, -1 }) do
			add("Rail", Vector3.new(0.18, height, 0.18),
				CFrame.new(sx * halfW, 0, sz * LADDER_FACE), RAIL, Enum.Material.Metal)
			-- Rubber feet. They are what stops the bottom reading as a
			-- cut-off pole, and they sit inside the rail's own span so the
			-- ladder's footprint is still the rails.
			add("Foot", Vector3.new(0.3, 0.26, 0.34),
				CFrame.new(sx * halfW, -height / 2 + 0.13, sz * LADDER_FACE),
				FOOT, Enum.Material.SmoothPlastic)
		end

		for i = 0, rungs - 1 do
			add("Rung", Vector3.new(LADDER_WIDTH, 0.14, 0.14),
				CFrame.new(0, topY - i * LADDER_RUNG_GAP, sz * LADDER_FACE),
				RUNG, Enum.Material.Metal)
		end
	end

	-- The two faces joined over the top. Without it this is two ladders
	-- standing near each other rather than one thing straddling a fence, and
	-- it is also the bar a climber's hands reach for at the mantle.
	for _, sx in ipairs({ 1, -1 }) do
		add("Cap", Vector3.new(0.18, 0.18, LADDER_FACE * 2 + 0.18),
			CFrame.new(sx * halfW, height / 2 - 0.09, 0), RAIL, Enum.Material.Metal)
	end
end

builders.ladder = function(spec, add)
	ladderParts(add, spec.height or 7)
end

builders.raincoat = function(spec, add)
	local COAT = Color3.fromRGB(238, 196, 62)
	local TRIM = Color3.fromRGB(52, 58, 72)

	-- Yellow, because a raincoat that is not yellow has to be explained.
	add("Body", Vector3.new(2.2, 2.4, 1.1), CFrame.new(0, -0.2, 0), COAT)
	for _, sx in ipairs({ 1, -1 }) do
		add("Sleeve", Vector3.new(0.75, 1.9, 0.95),
			CFrame.new(sx * 1.4, -0.1, 0) * CFrame.Angles(0, 0, math.rad(sx * 10)), COAT)
	end

	-- The hood is the silhouette. Without it this is a yellow rectangle.
	local hood = add("Hood", Vector3.new(1.7, 1.7, 1.7), CFrame.new(0, 1.3, -0.1), COAT)
	hood.Shape = Enum.PartType.Ball
	add("Brim", Vector3.new(1.5, 0.28, 0.8), CFrame.new(0, 1.1, 0.75), COAT)

	add("Placket", Vector3.new(0.28, 2.4, 0.14), CFrame.new(0, -0.2, 0.56), TRIM)
	for i = -1, 1 do
		add("Button", Vector3.new(0.24, 0.24, 0.14), CFrame.new(0, -0.2 + i * 0.7, 0.62), TRIM)
	end
end

-- The model and its `add` closure, shared by the catalogue path below and by
-- `buildLadder`, which reaches a builder directly rather than through a key.
-- Same shape and same reason as `Decor.buildStreetBin`: the world ladder is
-- shared GEOMETRY, not a shared item, and a second copy of this scaffolding
-- is the copy that drifts the first time either is touched.
local function newModel(modelName: string): (Model, Add)
	local model = Instance.new("Model")
	model.Name = modelName

	local function add(name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Anchored = true
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

	-- No PrimaryPart: some of these parts are rotated, and a PrimaryPart pivot
	-- REPLACES that rotation on the first PivotTo rather than adding to it.
	model.WorldPivot = CFrame.new()

	return model, add
end

function ThiefModel.build(key: string): Model
	local spec = Config.THIEF_KIT[key]
	assert(spec, ("Unknown thief item '%s'"):format(tostring(key)))

	local model, add = newModel("Thief_" .. key)
	local build = builders[spec.style]
	assert(build, ("Thief item '%s' has no builder for style '%s'"):format(key, tostring(spec.style)))
	build(spec, add)
	return model
end

-- The one that goes against a fence. Authored CENTRED on the origin like
-- every other builder here, because PlotService seats the barrier, the climb
-- volume and this from one shared `FENCE_BASE_Y + height / 2` -- three things
-- agreeing about where the middle of a fence is, rather than one of them
-- measuring from the foot.
function ThiefModel.buildLadder(height: number): Model
	local model, add = newModel("Ladder")
	ladderParts(add, height)
	return model
end

return ThiefModel
