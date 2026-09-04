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

-- ALIEN SET. Two stalks off a band, and the whole thing is authored with
-- y = 0 AT THE BAND -- the hat anchor is where a brim rests, so a headband
-- sits exactly there and everything else goes up from it. Authored around the
-- bounding-box centre instead, the band would sink into the skull.
builders.antenna = function(spec, add)
	local band = add("Band", Vector3.new(0.5, 5.0, 5.0), CFrame.new(0, 0.15, 0) * FLAT, spec.colour)
	band.Shape = Enum.PartType.Cylinder

	for _, side in ipairs({ -1, 1 }) do
		-- Stalks are cylinders, so the LENGTH is Size.X and the turn is what
		-- stands them up. Written Vector3.new(d, height, d) this is a disc as
		-- wide as it was meant to be tall, which this project has shipped six
		-- times.
		local stalk = add("Stalk", Vector3.new(2.3, 0.22, 0.22),
			CFrame.new(side * 1.5, 1.3, 0) * FLAT * CFrame.Angles(0, 0, math.rad(side * 12)),
			spec.colour, Enum.Material.Metal)
		stalk.Shape = Enum.PartType.Cylinder

		local bulb = add("Bulb", Vector3.new(0.85, 0.85, 0.85),
			CFrame.new(side * 1.95, 2.5, 0), spec.trim, Enum.Material.Neon)
		bulb.Shape = Enum.PartType.Ball
	end
end

-- ============================================================
-- GLASSES
-- ============================================================

-- EYE_X is where the pig's eyeballs actually are. Lenses have to line up with
-- them and arms have to clear them: the first version put both lenses between
-- the eyes and ran the arms straight through the eyeballs.
local EYE_X = 2.35
local ARM_X = 3.3   -- outside the eyeballs, which reach x = 2.98

builders.nerd = function(spec, add)
	for _, side in ipairs({ -1, 1 }) do
		local rim = add("Rim", Vector3.new(0.28, 2.3, 2.3),
			CFrame.new(side * EYE_X, 0, 0) * FACING, spec.colour)
		rim.Shape = Enum.PartType.Cylinder
		local lens = add("Lens", Vector3.new(0.16, 1.9, 1.9),
			CFrame.new(side * EYE_X, 0, -0.1) * FACING, spec.trim)
		lens.Shape = Enum.PartType.Cylinder
		lens.Transparency = 0.35
	end
	add("Bridge", Vector3.new(EYE_X * 2 - 2.1, 0.24, 0.24), CFrame.new(0, 0, 0), spec.colour)
	for _, side in ipairs({ -1, 1 }) do
		add("Arm", Vector3.new(0.22, 0.22, 1.3), CFrame.new(side * ARM_X, 0.15, -0.7), spec.colour)
	end
end

builders.shades = function(spec, add)
	-- One visor-like sweep rather than two lenses: sunglasses on a face this
	-- wide read better as a single dark band.
	add("Lens", Vector3.new(5.4, 1.3, 0.3), CFrame.new(0, 0, 0), spec.colour)
	add("Brow", Vector3.new(5.6, 0.34, 0.36), CFrame.new(0, 0.75, -0.02), spec.trim)
	-- Arms outboard of the eyeballs and kept short. At x = 2.2 they ran
	-- lengthwise straight through both eyes, which is what "poking the frame
	-- into its eyeballs" was.
	for _, side in ipairs({ -1, 1 }) do
		add("Arm", Vector3.new(0.24, 0.24, 1.1), CFrame.new(side * ARM_X, 0.3, -0.6), spec.trim)
	end
end

builders.visor = function(spec, add)
	add("Shell", Vector3.new(5.6, 1.5, 0.42), CFrame.new(0, 0, 0), spec.colour)
	add("Scan", Vector3.new(5.0, 0.5, 0.3), CFrame.new(0, 0.05, 0.16), spec.trim, Enum.Material.Neon)
	for _, side in ipairs({ -1, 1 }) do
		add("Strap", Vector3.new(0.3, 0.5, 1.4), CFrame.new(side * ARM_X, 0, -0.8), spec.colour)
	end
end

-- ALIEN SET. A single wrapped lens with a lit scan bar, sized off the same
-- numbers `shades` and `visor` already use: the arms sit at ARM_X so they
-- clear the eyeballs, which are balls at x +/-2.35 reaching z 5.53. At the
-- obvious x = 2.2 an arm runs lengthwise straight through both of them.
builders.abductor = function(spec, add)
	add("Shell", Vector3.new(5.8, 1.8, 0.44), CFrame.new(0, 0, 0), spec.colour)
	-- Two lit ovals rather than one bar, so it reads as EYES looking at you
	-- rather than as another visor. The pig has two eyes; so does this.
	--
	-- OVER THE EYEBALLS AT x +-2.35, NOT BETWEEN THEM. Authored at +-1.4 they
	-- measured x[-2.25 -0.55] and x[0.55 2.25] -- two lit ovals sitting in the
	-- gap between the pig's actual eyes, which is the exact clipping failure
	-- this project has already recorded ("lenses placed between the eyes
	-- instead of over them"). Narrowed to 1.1 at the same time so the pair
	-- still fits inside the 5.8-wide shell rather than poking past its edge.
	for _, side in ipairs({ -1, 1 }) do
		local eye = add("Eye", Vector3.new(1.1, 0.8, 0.34),
			CFrame.new(side * 2.35, 0.05, 0.16), spec.trim, Enum.Material.Neon)
		eye.Shape = Enum.PartType.Ball
	end
	add("Rim", Vector3.new(6.0, 0.3, 0.4), CFrame.new(0, 0.9, -0.02), spec.trim, Enum.Material.Metal)
	for _, side in ipairs({ -1, 1 }) do
		add("Strap", Vector3.new(0.3, 0.5, 1.4), CFrame.new(side * ARM_X, 0, -0.8), spec.colour)
	end
end

-- ============================================================
-- BACKS
-- ============================================================

builders.cape = function(spec, add)
	-- A continuous sheet leaving the shoulders and flaring hard backwards.
	--
	-- The flare angle is not a style choice, it is forced. The tail is a ball
	-- standing 1.37 studs proud of the body at y 9.7, and the cloth has to be
	-- BEHIND it there or the tail pokes through the cape -- there is no gap to
	-- thread, because in front of the tail is inside the pig. Clearing it from
	-- a shoulder attachment needs about 50 degrees, which is why this cape
	-- billows rather than hangs. Anything gentler clips.
	--
	-- Panels lie ALONG the hang line and are longer than the step between
	-- them, so the cloth stays continuous as it flares. An earlier attempt
	-- stepped level slabs apart far enough to clear the tail and left three
	-- separate red boards trailing behind the pig with daylight between them.
	local FLARE = math.rad(50)
	local step, panelLen = 2.0, 2.4   -- 0.4 of overlap between panels
	local down, back = math.cos(FLARE), math.sin(FLARE)

	add("Collar", Vector3.new(3.6, 0.7, 0.6), CFrame.new(0, 0.4, 0.6), spec.trim)

	local widths = { 4.2, 4.8, 5.2 }
	for i, width in ipairs(widths) do
		local along = panelLen / 2 + (i - 1) * step
		-- +FLARE, not -FLARE.
		--
		-- The sign decides which way each panel LEANS, and getting it wrong
		-- tilts the sheet across the hang line instead of along it: every
		-- panel's lower end swung forward into the pig, which put the middle
		-- one straight through the tail no matter how far back the cape was
		-- moved. Rotating the other way makes the panel axis parallel to the
		-- centre-to-centre direction, so the panels line up end to end.
		add("Cloth", Vector3.new(width, panelLen, 0.4),
			CFrame.new(0, -along * down, -along * back) * CFrame.Angles(FLARE, 0, 0),
			spec.colour)
	end
end

builders.jetpack = function(spec, add)
	for _, x in ipairs({ -1.6, 1.6 }) do
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
	-- y=0 is the SOLE, not the middle of the boot. The feet anchor sits on the
	-- lawn, so a shoe authored around its own centre buries half of itself.
	add("Sole", Vector3.new(2.1, 0.45, 3.1), CFrame.new(0, 0.23, 0.5), spec.trim)
	add("Upper", Vector3.new(1.9, 1.5, 1.9), CFrame.new(0, 1.15, 0), spec.colour)
	add("Toe", Vector3.new(1.9, 0.9, 1.0), CFrame.new(0, 0.75, 1.2), spec.colour)
	add("Lace", Vector3.new(1.5, 0.22, 0.22), CFrame.new(0, 1.6, 0.75), spec.trim)
end

builders.skates = function(spec, add)
	-- y=0 is where the WHEELS touch, so the whole skate is measured up from
	-- the road. Authored around the boot instead, the wheels sank under the
	-- lawn and the one detail that says "skate" was the part nobody could see.
	local wheelR = 0.45
	add("Boot", Vector3.new(1.8, 1.7, 2.4), CFrame.new(0, 1.85, 0.2), spec.colour)
	add("Plate", Vector3.new(1.9, 0.3, 2.9), CFrame.new(0, 0.95, 0.35), spec.trim)
	for _, z in ipairs({ -0.7, 1.4 }) do
		for _, x in ipairs({ -0.85, 0.85 }) do
			local wheel = add("Wheel", Vector3.new(0.5, wheelR * 2, wheelR * 2),
				CFrame.new(x, wheelR, z) * FACING, spec.trim)
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

	-- The pivot is the AUTHORED ORIGIN, not the visual centre.
	--
	-- This is the placement contract, and getting it wrong was the bug behind
	-- almost every clipping report: pivoting on the bounding-box centre meant
	-- PivotTo placed the middle of the shape at the anchor rather than the
	-- point each builder was written around. A top hat is authored with y=0 at
	-- the brim so it can sit ON the head; centre-pivoting dropped it 1.65
	-- studs and buried the brim two studs inside the skull.
	--
	-- The shop icon wants the other point, and computes it for itself -- see
	-- makeModelIcon, which re-centres its own copy. A model cannot serve both
	-- from one pivot, so it serves the one that has to be right in the world.
	--
	-- Still no PrimaryPart: several of these have a rotated first part, and a
	-- PrimaryPart pivot would REPLACE that rotation on the first PivotTo
	-- rather than add to it, laying every top hat on its side.
	model.WorldPivot = CFrame.new()

	return model
end

return PigGear
