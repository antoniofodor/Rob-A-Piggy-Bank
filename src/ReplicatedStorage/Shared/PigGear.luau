--!strict
--[[
	PigGear

	What each accessory looks like, built once and used from both sides -- the
	pig standing on the plot (server) and the collection tile in the shop
	(client, inside a ViewportFrame). Same reason BoneModel is shared: two
	builders drift, and a shop picture that does not match the thing you end up
	wearing is worse than no picture.

	Every item is built around the ORIGIN, facing +Z, in pig-local studs. Where
	it hangs is not decided here -- Config.ACCESSORY_SLOTS owns the anchors, so
	the same hat model is placed on the crown by the pig and centred in a
	viewport by the shop without either knowing what the other does.

	Nothing here collides or answers a raycast. A hat is worn by the thing a
	thief has to reach; it must never be something they can get stuck on.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PigGear = {}

type Add = (name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?) -> Part

local builders: { [string]: (any, Add) -> () } = {}

-- Roblox cylinders have their flat faces on X, so a disc lying flat (brims,
-- wheels, lenses) has to be turned onto the axis it is meant to face. Naming
-- the two turns beats repeating the raw angles at fifteen call sites.
local FLAT = CFrame.Angles(0, 0, math.rad(90))    -- axis up: brims, discs
local FACING = CFrame.Angles(0, math.rad(90), 0)  -- axis forward: lenses, wheels

-- ============================================================
-- HATS
-- ============================================================

builders.cap = function(spec, add)
	-- Squashed rather than a round ball: a low dome reads as a cap, a sphere
	-- reads as a balloon tied to the pig's head.
	local dome = add("Crown", Vector3.new(3.6, 2.4, 3.8), CFrame.new(0, 0.5, 0), spec.colour)
	dome.Shape = Enum.PartType.Ball

	add("Peak", Vector3.new(3.2, 0.32, 2.0), CFrame.new(0, -0.2, 2.2), spec.colour)
	add("Button", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 1.6, 0), spec.trim)
end

builders.tophat = function(spec, add)
	local brim = add("Brim", Vector3.new(0.3, 5.0, 5.0), FLAT, spec.colour)
	brim.Shape = Enum.PartType.Cylinder

	local stack = add("Stack", Vector3.new(3.4, 3.4, 3.4), CFrame.new(0, 1.75, 0) * FLAT, spec.colour)
	stack.Shape = Enum.PartType.Cylinder

	local band = add("Band", Vector3.new(0.9, 3.6, 3.6), CFrame.new(0, 0.6, 0) * FLAT, spec.trim)
	band.Shape = Enum.PartType.Cylinder
end

builders.crown = function(spec, add)
	-- Wider than it looks like it needs to be. The head is a ball, so at the
	-- height hats sit its horizontal radius is under two studs -- a crown cut
	-- to actually fit there reads as a party hat. Every hat in this slot
	-- overhangs, and the top hat's 5-stud brim is the size to match.
	local band = add("Band", Vector3.new(1.4, 5.0, 5.0), FLAT, spec.colour, Enum.Material.Metal)
	band.Shape = Enum.PartType.Cylinder

	-- Points around the rim, each leaning outward, with a jewel on top. Eight
	-- reads as a crown; four reads as a paper hat.
	for i = 0, 7 do
		local angle = (i / 8) * math.pi * 2
		local at = CFrame.new(math.sin(angle) * 2.2, 0.95, math.cos(angle) * 2.2)
		-- A thin block turned to face outward. A real WedgePart would need its
		-- own code path through `add` for one visual detail nobody can resolve
		-- on a 0.55-stud spike seen from the street.
		add("Point", Vector3.new(0.62, 1.9, 0.62),
			at * CFrame.Angles(0, -angle, 0), spec.colour, Enum.Material.Metal)

		if i % 2 == 0 then
			local jewel = add("Jewel", Vector3.new(0.62, 0.62, 0.62),
				at * CFrame.new(0, 1.2, 0), spec.trim)
			jewel.Shape = Enum.PartType.Ball
		end
	end
end

builders.halo = function(spec, add)
	-- A ring of small neon spheres, not a flat disc.
	--
	-- A disc only reads as a halo from straight on; edge-on it is a line, and
	-- the pig is looked at from the street at a shallow angle almost all of
	-- the time. Beads hold the shape from every direction.
	for i = 0, 15 do
		local angle = (i / 16) * math.pi * 2
		local bead = add("Bead", Vector3.new(0.62, 0.62, 0.62),
			CFrame.new(math.sin(angle) * 2.3, 0, math.cos(angle) * 2.3),
			spec.colour, Enum.Material.Neon)
		bead.Shape = Enum.PartType.Ball
	end

	local glow = add("Glow", Vector3.new(0.4, 0.4, 0.4), CFrame.new(), spec.colour, Enum.Material.Neon)
	glow.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color = spec.colour
	light.Brightness = 1.6
	light.Range = 12
	light.Parent = glow
end

-- ============================================================
-- GLASSES
-- ============================================================

builders.nerd = function(spec, add)
	for _, x in ipairs({ -1.15, 1.15 }) do
		local rim = add("Rim", Vector3.new(0.28, 1.9, 1.9), CFrame.new(x, 0, 0) * FACING, spec.colour)
		rim.Shape = Enum.PartType.Cylinder
		local lens = add("Lens", Vector3.new(0.16, 1.5, 1.5), CFrame.new(x, 0, -0.12) * FACING, spec.trim)
		lens.Shape = Enum.PartType.Cylinder
		lens.Transparency = 0.35
	end
	add("Bridge", Vector3.new(1.0, 0.22, 0.22), CFrame.new(0, 0, 0), spec.colour)
	for _, x in ipairs({ -2.0, 2.0 }) do
		add("Arm", Vector3.new(0.2, 0.2, 1.4), CFrame.new(x, 0, -0.8), spec.colour)
	end
end

builders.shades = function(spec, add)
	-- One visor-like sweep rather than two lenses: sunglasses on a face this
	-- wide read better as a single dark band.
	add("Lens", Vector3.new(4.4, 1.25, 0.3), CFrame.new(0, 0, 0), spec.colour)
	add("Brow", Vector3.new(4.6, 0.34, 0.36), CFrame.new(0, 0.72, -0.02), spec.trim)
	for _, x in ipairs({ -2.2, 2.2 }) do
		add("Arm", Vector3.new(0.22, 0.22, 1.5), CFrame.new(x, 0.3, -0.85), spec.trim)
	end
end

builders.visor = function(spec, add)
	add("Shell", Vector3.new(4.8, 1.5, 0.42), CFrame.new(0, 0, 0), spec.colour)
	add("Scan", Vector3.new(4.2, 0.5, 0.3), CFrame.new(0, 0.05, 0.16), spec.trim, Enum.Material.Neon)
	for _, x in ipairs({ -2.5, 2.5 }) do
		add("Strap", Vector3.new(0.3, 0.5, 1.8), CFrame.new(x, 0, -1.0), spec.colour)
	end
end

-- ============================================================
-- BACKS
-- ============================================================

builders.cape = function(spec, add)
	add("Collar", Vector3.new(3.6, 0.7, 0.6), CFrame.new(0, 1.4, 0.1), spec.trim)
	-- Three panels stepping backwards and outwards, so the cloth reads as
	-- hanging away from a round body instead of being painted onto it.
	local panels = {
		{ size = Vector3.new(4.2, 2.2, 0.4), at = CFrame.new(0, 0.2, -0.35), tilt = math.rad(-8) },
		{ size = Vector3.new(4.8, 2.2, 0.4), at = CFrame.new(0, -1.8, -0.95), tilt = math.rad(-14) },
		{ size = Vector3.new(5.2, 2.0, 0.4), at = CFrame.new(0, -3.7, -1.75), tilt = math.rad(-18) },
	}
	for _, panel in ipairs(panels) do
		add("Cloth", panel.size, panel.at * CFrame.Angles(panel.tilt, 0, 0), spec.colour)
	end
end

builders.jetpack = function(spec, add)
	for _, x in ipairs({ -1.3, 1.3 }) do
		local tank = add("Tank", Vector3.new(3.2, 1.5, 1.5), CFrame.new(x, 0.3, -0.4) * FLAT,
			spec.colour, Enum.Material.Metal)
		tank.Shape = Enum.PartType.Cylinder
		local cone = add("Nozzle", Vector3.new(0.9, 1.1, 1.1), CFrame.new(x, -1.5, -0.4) * FLAT,
			Color3.fromRGB(72, 74, 82), Enum.Material.Metal)
		cone.Shape = Enum.PartType.Cylinder
		add("Flame", Vector3.new(0.85, 1.0, 0.85), CFrame.new(x, -2.3, -0.4), spec.trim, Enum.Material.Neon)
	end
	add("Harness", Vector3.new(3.4, 0.5, 0.7), CFrame.new(0, 1.0, -0.1), Color3.fromRGB(62, 64, 72))
end

builders.wings = function(spec, add)
	-- Each wing is three overlapping feathers fanning up and out. Symmetric
	-- through the mirrored x/tilt, so one description makes both sides.
	for _, side in ipairs({ -1, 1 }) do
		local feathers = {
			{ size = Vector3.new(3.4, 1.5, 0.42), at = Vector3.new(side * 2.2, 0.4, -0.2), roll = math.rad(side * 14) },
			{ size = Vector3.new(3.0, 1.3, 0.42), at = Vector3.new(side * 3.1, 1.7, -0.5), roll = math.rad(side * 30) },
			{ size = Vector3.new(2.4, 1.1, 0.42), at = Vector3.new(side * 3.5, 3.0, -0.8), roll = math.rad(side * 46) },
		}
		for _, f in ipairs(feathers) do
			add("Feather", f.size, CFrame.new(f.at) * CFrame.Angles(0, 0, f.roll), spec.colour)
		end
		add("Tip", Vector3.new(1.6, 0.9, 0.42),
			CFrame.new(side * 3.6, 4.1, -1.0) * CFrame.Angles(0, 0, math.rad(side * 58)), spec.trim)
	end
end

-- ============================================================
-- SHOES
-- ============================================================
--
-- Built as ONE shoe. The feet slot has four anchors and the placing code makes
-- a copy at each; a builder that produced all four would render four shoes
-- stacked in the middle of the shop tile.

builders.boots = function(spec, add)
	add("Upper", Vector3.new(1.9, 1.5, 1.9), CFrame.new(0, 0.55, 0), spec.colour)
	add("Toe", Vector3.new(1.9, 0.9, 1.0), CFrame.new(0, 0.15, 1.2), spec.colour)
	add("Sole", Vector3.new(2.1, 0.45, 3.1), CFrame.new(0, -0.35, 0.5), spec.trim)
	add("Lace", Vector3.new(1.5, 0.22, 0.22), CFrame.new(0, 1.0, 0.75), spec.trim)
end

builders.skates = function(spec, add)
	add("Boot", Vector3.new(1.8, 1.7, 2.4), CFrame.new(0, 0.85, 0.2), spec.colour)
	add("Plate", Vector3.new(1.9, 0.3, 2.9), CFrame.new(0, -0.05, 0.35), spec.trim)
	for _, z in ipairs({ -0.7, 1.4 }) do
		for _, x in ipairs({ -0.85, 0.85 }) do
			local wheel = add("Wheel", Vector3.new(0.5, 0.9, 0.9),
				CFrame.new(x, -0.5, z) * FACING, spec.trim)
			wheel.Shape = Enum.PartType.Cylinder
		end
	end
end

-- ============================================================
-- BUILD
-- ============================================================

function PigGear.build(key: string): Model
	local spec = Config.ACCESSORIES[key]
	assert(spec, ("Unknown accessory '%s'"):format(tostring(key)))

	local model = Instance.new("Model")
	model.Name = "Gear_" .. key

	local function add(name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Anchored = true
		-- Worn by the one thing in the game a thief has to walk up to and hold
		-- a prompt on. An accessory that collided, or that answered a raycast
		-- aimed at the piggy, would turn a hat into a defence upgrade.
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Color = colour
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	local build = builders[key]
	assert(build, ("Accessory '%s' has no builder"):format(key))
	build(spec, add)

	-- Pivot on the visual centre with no PrimaryPart, for the same reason
	-- BoneModel does: several of these have their first part rotated, and a
	-- PrimaryPart pivot would REPLACE that rotation on the first PivotTo
	-- rather than add to it -- laying every top hat on its side.
	local box = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(box.Position)

	return model
end

return PigGear
