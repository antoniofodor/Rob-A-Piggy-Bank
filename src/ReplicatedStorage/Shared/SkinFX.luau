--!strict
--[[
	SkinFX

	THE THIRD LAYER OF A LEGENDARY OG SKIN, AFTER PAINT AND PARTICLES. A skin
	is colour and material on the pig's body; `Config.skinAura` gives an epic
	or a legendary its particles. Neither can add SHAPE, and a legendary that
	is a better colour than an epic is still the same object -- geometry is
	the line between those two tiers. This builds the shape:
	crystal shards on the Diamond, a solar corona on Supernova, storm clouds on
	Stormcaller, a ring of prisms on Prismatic. A skin opts in with
	`fx = "<kind>"` in `Config.SKINS`.

	GEOMETRY RATHER THAN ONLY PARTICLES, because a ViewportFrame draws
	BaseParts and nothing else. The crate reel, the bag and the HUD all show a
	skin through one, so particles alone would be a legendary that looks like
	a rare everywhere it is chosen and only reveals itself on the lawn.

	SEATED IN THE SEAT FRAME `LegendaryModel` uses (the ordinary Body row's
	offset and half turn undone, scaled by `Size.X / 12`), so one table serves
	the twelve-stud lawn pig and the 2.2-stud mini alike. Seat units: y is up
	with the pig's centre at `CENTRE_Y`, z is the snout.

	WHERE IT MAY STAND is decided by what the player owns: the top of the pig is
	the hat anchor, the back is the cape and the tail, the face is the glasses.
	So everything here rides the FLANKS or rings the pig at radius 8-10, clear
	of every accessory anchor and of the rob badge over the head.

	MOTION IS CLIENT-SIDE, like the skin colours and the house light shows: the
	server builds the parts once and marks each with what it does, and every
	client moves them. `SkinFX.start` is that loop. It only drives an ANCHORED
	set -- the lawn pig. The carried mini is welded to a running thief and a
	part the client moved would fight its weld, so it stays still, exactly as
	the legendary idle rig does.

	No strobe: every colour change is a continuous curve and no rate may exceed
	`MAX_RATE` cycles a second (see HouseFX for the photosensitivity rule).
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(script.Parent.Config)

local SkinFX = {}

SkinFX.FOLDER = "SkinFX"
local CENTRE_Y = 6.62
local MAX_RATE = 0.9
local CULL = 260

local baseBody = (function()
	for _, entry in ipairs(Config.PIGGY_MESH) do
		if entry.part == "Body" then
			return entry
		end
	end
	return nil
end)()

type Ctx = {
	folder: Folder,
	seat: CFrame,
	s: number,
	anchored: boolean,
	body: BasePart,
}

type Motion = {
	orbit: number?, -- revolutions a second about the pig's vertical axis
	spin: number?, -- revolutions a second about the part's own vertical axis
	bob: number?, -- studs (seat units) of vertical bob
	bobRate: number?,
	cycle: number?, -- hue cycles a second
	pulse: number?, -- brightness pulses a second
	hue: number?,
	sat: number?,
	dim: number?,
	phase: number?,
}

-- Where a hat sits, in seat units: the generated body's own hat anchor
-- (`Config.ACCESSORY_SLOTS.hat.meshAnchors`), which is measured from the
-- same ground point the seat frame starts at.
local HAT_AT = (function()
	local slot = Config.ACCESSORY_SLOTS and Config.ACCESSORY_SLOTS.hat
	local anchors = slot and (slot.meshAnchors or slot.anchors)
	return (anchors and anchors[1]) or Vector3.new(0, 11.8, 1.9)
end)()

-- Where glasses sit, the same way: the body's own eye anchor.
local EYES_AT = (function()
	local slot = Config.ACCESSORY_SLOTS and Config.ACCESSORY_SLOTS.eyes
	local anchors = slot and (slot.meshAnchors or slot.anchors)
	return (anchors and anchors[1]) or Vector3.new(0, 9.134, 6.146)
end)()

-- Marks a part as standing in an accessory slot, so `PiggyBank` can take it
-- off while the player wears something of their own there.
SkinFX.SLOT_ATTRIBUTE = "FxSlot"

local function part(ctx: Ctx, name: string, size: Vector3, at: CFrame, colour: Color3,
	material: Enum.Material, motion: Motion?, shape: Enum.PartType?): Part

	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size * ctx.s
	p.CFrame = ctx.seat * CFrame.new(at.Position * ctx.s) * at.Rotation
	p.Color = colour
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Anchored = ctx.anchored
	if motion then
		for key, value in pairs(motion :: any) do
			p:SetAttribute("Fx" .. key, value)
		end
	end
	if not ctx.anchored then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = ctx.body
		weld.Part1 = p
		weld.Parent = p
	end
	p.Parent = ctx.folder
	return p
end

-- A point on a horizontal ring around the pig's centre, facing outward
-- (+Z of the returned frame points away from the centre).
local function onRing(radius: number, y: number, angle: number): CFrame
	local pos = Vector3.new(math.sin(angle) * radius, y, math.cos(angle) * radius)
	return CFrame.lookAt(pos, Vector3.new(0, y, 0)) * CFrame.Angles(0, math.pi, 0)
end

local builders: { [string]: (Ctx) -> () } = {}

-- DIAMOND: a crystal cluster breaking out of each flank, and five cut gems
-- circling the pig. Glass shards with a neon core, because glass alone against
-- a pale sky is nearly invisible and neon alone is a white hole.
builders.diamond = function(ctx)
	local glass = Color3.fromRGB(196, 240, 255)
	local core = Color3.fromRGB(60, 190, 255)
	local shards = {
		-- x, y, z, length, width, lean (deg outward), twist (deg)
		{ 5.0, 8.6, -0.8, 5.2, 1.5, 34, 10 },
		{ 4.4, 9.8, 1.0, 3.8, 1.2, 18, -14 },
		{ 5.4, 7.0, 0.8, 3.2, 1.1, 56, 30 },
		{ 4.2, 9.6, -2.4, 3.0, 1.0, 26, -30 },
		{ 5.6, 6.0, -1.8, 2.4, 0.9, 70, 15 },
	}
	for _, side in ipairs({ -1, 1 }) do
		for i, sh in ipairs(shards) do
			local x, y, z, len, w, lean, twist = sh[1] * side, sh[2], sh[3], sh[4], sh[5], sh[6], sh[7]
			-- Rooted in the body, leaning away from it, turned so a corner
			-- rather than a face points out: that is what reads as cut.
			local at = CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(-lean * side))
				* CFrame.Angles(0, math.rad(45 + twist), 0) * CFrame.new(0, len / 2 - 0.4, 0)
			local shard = part(ctx, "Shard" .. i, Vector3.new(w, len, w), at, glass, Enum.Material.Glass)
			shard.Transparency = 0.2
			shard.Reflectance = 0.3
			part(ctx, "ShardCore" .. i, Vector3.new(w * 0.4, len * 0.75, w * 0.4), at, core,
				Enum.Material.Neon, { pulse = 0.35, hue = 0.55, sat = 0.75, dim = 0.55, phase = i * 0.21 })
		end
	end
	for i = 1, 5 do
		local angle = (i - 1) / 5 * math.pi * 2
		local at = onRing(10, CENTRE_Y + 1.4, angle) * CFrame.Angles(math.rad(45), 0, math.rad(45))
		local gem = part(ctx, "Gem" .. i, Vector3.new(1.8, 1.8, 1.8), at, glass, Enum.Material.Glass,
			{ orbit = 0.06, spin = 0.35, bob = 0.35, bobRate = 0.4, phase = i * 0.2 })
		gem.Reflectance = 0.4
		gem.Transparency = 0.1
	end
end

-- THE PARTY PIGGY'S HAT: a striped cone with a pom-pom, cocked to one side.
-- There is no cone primitive, so it is a stack of cylinders narrowing to the
-- tip, alternating colours -- and the steps between them ARE the stripes, so
-- the thing that would be a flaw on a plain cone is the look of a party hat.
-- It stands in the HAT SLOT, which is the one exception to the rule above,
-- and it gives way: every part is marked, and a worn hat hides it.
builders.party = function(ctx)
	local stripes = {
		Color3.fromRGB(246, 96, 150),
		Color3.fromRGB(255, 214, 64),
		Color3.fromRGB(80, 190, 246),
	}
	local base = CFrame.new(HAT_AT) * CFrame.Angles(math.rad(-8), 0, math.rad(-14))
	local height, radius, steps = 6.0, 2.2, 8
	local up = CFrame.Angles(0, 0, math.rad(90)) -- a cylinder's axis is X
	for i = 1, steps do
		local t = (i - 1) / steps
		local r = radius * (1 - t) + 0.12
		local h = height / steps
		local p = part(ctx, "HatStripe" .. i, Vector3.new(h + 0.02, r * 2, r * 2),
			base * CFrame.new(0, h * (i - 0.5), 0) * up, stripes[(i - 1) % #stripes + 1],
			Enum.Material.SmoothPlastic, nil, Enum.PartType.Cylinder)
		p:SetAttribute(SkinFX.SLOT_ATTRIBUTE, "hat")
	end
	local pom = part(ctx, "HatPom", Vector3.new(1.4, 1.4, 1.4), base * CFrame.new(0, height + 0.35, 0),
		Color3.fromRGB(255, 250, 236), Enum.Material.SmoothPlastic, nil, Enum.PartType.Ball)
	pom:SetAttribute(SkinFX.SLOT_ATTRIBUTE, "hat")

	-- THE BALLOONS: three, tied to the left flank and floating up and out,
	-- clear of the hat, the rob badge over the head and the cape on the back.
	-- Each string and its balloon share one bob, so they move as one piece;
	-- they are out of step with each other, which is what makes a bunch.
	local tie = Vector3.new(-4.6, 8.2, 0.4)
	local balloons = {
		-- where it floats, colour, bob phase
		{ Vector3.new(-7.6, 19.0, -2.0), stripes[1], 0.0 },
		{ Vector3.new(-11.0, 16.4, 0.6), stripes[2], 0.33 },
		{ Vector3.new(-6.8, 15.6, 2.8), stripes[3], 0.66 },
	}
	for i, b in ipairs(balloons) do
		local top, colour, phase = b[1], b[2], b[3]
		local motion = { bob = 0.35, bobRate = 0.35, phase = phase }
		local knot = top - Vector3.new(0, 2.0, 0)
		local length = (knot - tie).Magnitude
		local mid = (knot + tie) / 2
		local string = part(ctx, "BalloonString" .. i, Vector3.new(0.08, 0.08, length),
			CFrame.lookAt(mid, knot), Color3.fromRGB(250, 246, 232), Enum.Material.SmoothPlastic, motion)
		string.Transparency = 0.1
		local balloon = part(ctx, "Balloon" .. i, Vector3.new(3.4, 3.4, 3.4), CFrame.new(top),
			colour, Enum.Material.SmoothPlastic, motion, Enum.PartType.Ball)
		balloon.Reflectance = 0.18
		-- Taller than wide, the one thing that says balloon rather than ball.
		local shape = Instance.new("SpecialMesh")
		shape.MeshType = Enum.MeshType.Sphere
		shape.Scale = Vector3.new(1, 1.2, 1)
		shape.Parent = balloon
		part(ctx, "BalloonKnot" .. i, Vector3.new(0.45, 0.45, 0.45), CFrame.new(knot + Vector3.new(0, 0.1, 0)),
			colour, Enum.Material.SmoothPlastic, motion, Enum.PartType.Ball)
	end
end

-- THE VELVET ROPE'S SHADES: black lenses in a gold frame, because a VIP
-- wears sunglasses. Two lenses rather than one flat band, each turned back
-- round the face so the ends follow the head instead of standing off it,
-- joined by a bridge and topped by a gold brow bar. They stand in the EYES
-- slot, so glasses the player actually wears would win and hide these.
builders.vip = function(ctx)
	local lensColour = Color3.fromRGB(18, 16, 22)
	local gold = Color3.fromRGB(226, 178, 72)
	local function mark(p: Part)
		p:SetAttribute(SkinFX.SLOT_ATTRIBUTE, "eyes")
	end
	for _, side in ipairs({ -1, 1 }) do
		local frame = CFrame.new(EYES_AT + Vector3.new(side * 1.5, 0, -0.2))
			* CFrame.Angles(0, math.rad(18 * side), 0)
		local lens = part(ctx, "ShadeLens", Vector3.new(2.5, 1.3, 0.3), frame, lensColour,
			Enum.Material.SmoothPlastic)
		lens.Reflectance = 0.35
		mark(lens)
		mark(part(ctx, "ShadeBrow", Vector3.new(2.7, 0.3, 0.36), frame * CFrame.new(0, 0.72, 0.02), gold,
			Enum.Material.SmoothPlastic))
		mark(part(ctx, "ShadeArm", Vector3.new(0.22, 0.22, 1.6),
			CFrame.new(EYES_AT + Vector3.new(side * 2.85, 0.35, -1.2)), gold, Enum.Material.SmoothPlastic))
	end
	mark(part(ctx, "ShadeBridge", Vector3.new(0.9, 0.24, 0.3), CFrame.new(EYES_AT + Vector3.new(0, 0.3, 0.05)),
		gold, Enum.Material.SmoothPlastic))
end

-- SUPERNOVA: a corona of rays standing out of the pig's middle, long and
-- short in turn, the whole ring turning and breathing gold to orange. The
-- aura (`sunburst`) throws the particles off the sphere itself.
builders.supernova = function(ctx)
	-- THE RAYS STAND STILL AND LEAVE THE SNOUT CLEAR. Photographed, the ray
	-- dead ahead ran straight across the face; a turning ring would carry one
	-- across it every few seconds. So the front three are left out and the
	-- corona breathes rather than turns.
	local n = 16
	for i = 1, n do
		if i == 1 or i == 2 or i == n then
			continue
		end
		local angle = (i - 1) / n * math.pi * 2
		local len = if i % 2 == 0 then 3.2 else 5.0
		local at = onRing(7.0 + len / 2, CENTRE_Y, angle)
		part(ctx, "Ray" .. i, Vector3.new(0.8, 0.8, len), at, Color3.fromRGB(255, 176, 40),
			Enum.Material.Neon, { pulse = 0.6, hue = 0.09, sat = 0.9, dim = 0.55,
				phase = (i % 4) * 0.25 })
	end
	-- A thin tilted halo above the rays, so the corona reads as a sphere of
	-- light rather than a flat collar.
	for i = 1, 10 do
		local angle = (i - 1) / 10 * math.pi * 2
		local at = onRing(9.5, CENTRE_Y + 3.2, angle)
		part(ctx, "Flare" .. i, Vector3.new(1.4, 1.4, 1.4), at, Color3.fromRGB(255, 214, 90),
			Enum.Material.Neon, { orbit = -0.08, pulse = 0.5, hue = 0.12, sat = 0.85, dim = 0.45,
				phase = i * 0.1 }, Enum.PartType.Ball)
	end
end

-- STORMCALLER: three small storm clouds circling above the flanks, each
-- dropping a bolt toward the pig. The bolts SWELL and fade -- a lighthouse
-- curve, never a switch -- so a storm reads without a strobe.
builders.stormcaller = function(ctx)
	for c = 1, 3 do
		local angle = (c - 1) / 3 * math.pi * 2
		local base = onRing(9.6, CENTRE_Y + 8, angle)
		local motion = { orbit = 0.05, bob = 0.3, bobRate = 0.35, phase = c * 0.33 }
		local puffs = {
			{ 0, 0, 0, 3.6 }, { 2.1, -0.3, 0.15, 2.7 }, { -2.0, -0.35, -0.15, 2.8 },
			{ 0.75, 1.05, -0.3, 2.4 }, { -0.9, 0.8, 0.45, 2.2 },
		}
		for i, p in ipairs(puffs) do
			part(ctx, "Cloud" .. c .. "_" .. i, Vector3.new(p[4], p[4], p[4]),
				base * CFrame.new(p[1], p[2], p[3]), Color3.fromRGB(104, 112, 138),
				Enum.Material.SmoothPlastic, motion, Enum.PartType.Ball)
		end
		-- The bolt: three segments zig-zagging down, lit together.
		local bolt = {
			{ 0.0, -2.1, 0.0, 2.1, 22 },
			{ 0.5, -3.8, 0.0, 1.8, -26 },
			{ 0.1, -5.3, 0.0, 1.7, 24 },
		}
		local lit = { orbit = 0.05, bob = 0.3, bobRate = 0.35, phase = c * 0.33,
			pulse = 0.55, hue = 0.6, sat = 0.5, dim = 0.1 }
		for i, b in ipairs(bolt) do
			part(ctx, "Bolt" .. c .. "_" .. i, Vector3.new(0.5, b[4], 0.5),
				base * CFrame.new(b[1], b[2], b[3]) * CFrame.Angles(0, 0, math.rad(b[5])),
				Color3.fromRGB(150, 196, 255), Enum.Material.Neon, lit)
		end
	end
end

-- PRISMATIC: a ring of seven prisms circling the pig, each a step further
-- round the colour wheel, so the ring is always a whole rainbow.
builders.prismatic = function(ctx)
	local n = 7
	for i = 1, n do
		local angle = (i - 1) / n * math.pi * 2
		local at = onRing(10, CENTRE_Y + 0.8, angle) * CFrame.Angles(0, math.rad(45), 0)
		part(ctx, "Prism" .. i, Vector3.new(1.2, 4.0, 1.2), at, Color3.fromHSV((i - 1) / n, 0.8, 1),
			Enum.Material.Neon, { orbit = 0.07, spin = 0.25, bob = 0.35, bobRate = 0.3,
				cycle = 0.18, hue = (i - 1) / n, sat = 0.8, phase = i / n })
	end
end

-- PEACOCK: a fan of seven eyed tail feathers standing up behind the body,
-- each eye a Neon gold point in a Neon blue disc on a green plume, swaying a
-- little out of step with each other. The animal shelf's `fx` epic.
--
-- BEHIND THE ANIMAL, ON -Z, which is the one side a viewer on the pavement
-- never has between them and the face -- so the fan frames the pig rather
-- than hiding it -- and it tops out at seat y 16, under the rob badge (the
-- body's 6 plus its 11). Seat units are the twelve-stud till like every
-- builder here; a mini takes them through `ctx.s`. The parts stand in the
-- BACK slot, where a cape would.
--
-- A DISC IS A FLATTENED BALL, the balloon's own trick: a `Ball` ignores a
-- non-uniform Size, a SpecialMesh sphere does not, and three of them
-- stacked at different radii are three curved surfaces that cannot share a
-- plane -- which is what keeps the layered eye off the coplanar rule.
-- RETIRED 2026-09-23 AND KEPT: `Config.SKINS.peacock` wears the authored
-- epic-v2 fan now (`Config.SKIN_ACCESSORIES.peacock`, ten meshes off one
-- palette sheet), so nothing names this builder. It stays because it is
-- the record of how the shape was solved out of primitives, and because
-- putting it back is one `fx = "peacock"` field. NEVER BOTH.
builders.peacock = function(ctx)
	local root = Vector3.new(0, 7.2, -5.2)
	local n, reach = 7, 8.6
	local plume = Color3.fromRGB(28, 122, 96)
	local outer = Color3.fromRGB(46, 170, 120)
	local ring = Color3.fromRGB(30, 96, 210)
	local core = Color3.fromRGB(255, 200, 60)
	local function flat(p: Part, k: number)
		local shape = Instance.new("SpecialMesh")
		shape.MeshType = Enum.MeshType.Sphere
		shape.Scale = Vector3.new(1, 1, k)
		shape.Parent = p
	end
	for i = 1, n do
		local t = (i - 1) / (n - 1)
		local angle = math.rad(-62 + 124 * t)
		local tip = root + Vector3.new(math.sin(angle) * reach, math.cos(angle) * reach, -2.4)
		local motion = { bob = 0.18, bobRate = 0.28, phase = i / n }
		local mid = (root + tip) / 2
		local length = (tip - root).Magnitude
		local made = {
			part(ctx, "Plume" .. i, Vector3.new(0.3, 0.3, length), CFrame.lookAt(mid, tip),
				plume, Enum.Material.SmoothPlastic, motion),
		}
		local face = CFrame.new(tip)
		local disc = part(ctx, "PlumeEye" .. i, Vector3.new(3.0, 3.0, 3.0), face, outer,
			Enum.Material.SmoothPlastic, motion, Enum.PartType.Ball)
		flat(disc, 0.22)
		local iris = part(ctx, "PlumeRing" .. i, Vector3.new(1.9, 1.9, 1.9),
			face * CFrame.new(0, 0, 0.14), ring, Enum.Material.Neon, motion, Enum.PartType.Ball)
		flat(iris, 0.22)
		local point = part(ctx, "PlumeCore" .. i, Vector3.new(0.9, 0.9, 0.9),
			face * CFrame.new(0, 0, 0.28), core, Enum.Material.Neon, motion, Enum.PartType.Ball)
		flat(point, 0.22)
		table.insert(made, disc)
		table.insert(made, iris)
		table.insert(made, point)
		for _, p in ipairs(made) do
			p:SetAttribute(SkinFX.SLOT_ATTRIBUTE, "back")
		end
	end
end

-- Builds (or clears) the skin's geometry on a pig. Called on every skin
-- change, so it always tears the last set down first.
function SkinFX.apply(model: Instance, body: BasePart, skinKey: string, anchored: boolean)
	local old = model:FindFirstChild(SkinFX.FOLDER)
	if old then
		old:Destroy()
	end
	local skin = Config.SKINS[skinKey]
	local kind = skin and (skin :: any).fx
	local build = kind and builders[kind]
	if not build or not baseBody then
		return
	end
	local s = body.Size.X / baseBody.size.X
	local seat = body.CFrame * (baseBody.rot or CFrame.identity):Inverse()
		* CFrame.new(-baseBody.offset * s)

	local folder = Instance.new("Folder")
	folder.Name = SkinFX.FOLDER
	local ctx: Ctx = { folder = folder, seat = seat, s = s, anchored = anchored, body = body }
	-- The frame everything moves about: the pig's centre, in the seat's
	-- orientation. Invisible, and the only part the client reads a pose from.
	local anchor = part(ctx, "Anchor", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, CENTRE_Y, 0),
		Color3.new(), Enum.Material.SmoothPlastic)
	anchor.Transparency = 1
	build(ctx)
	folder.Parent = model
end

-- ============================================================
-- CLIENT ANIMATOR
-- ============================================================

type Entry = {
	part: BasePart,
	rest: CFrame,
	orbit: number,
	spin: number,
	bob: number,
	bobRate: number,
	cycle: number,
	pulse: number,
	hue: number,
	sat: number,
	dim: number,
	phase: number,
}
type Set = { anchor: BasePart, folder: Folder, parts: { Entry } }

local sets: { [Folder]: Set } = {}
local started = false

local function num(p: Instance, key: string, fallback: number): number
	local v = p:GetAttribute("Fx" .. key)
	return if type(v) == "number" then v else fallback
end

local function track(folder: Folder)
	if sets[folder] then
		return
	end
	local anchor = folder:FindFirstChild("Anchor")
	if not anchor or not anchor:IsA("BasePart") or not anchor.Anchored then
		return
	end
	local set: Set = { anchor = anchor, folder = folder, parts = {} }
	for _, p in ipairs(folder:GetChildren()) do
		if p:IsA("BasePart") and p ~= anchor then
			local e: Entry = {
				part = p,
				rest = anchor.CFrame:ToObjectSpace(p.CFrame),
				orbit = math.clamp(num(p, "orbit", 0), -MAX_RATE, MAX_RATE),
				spin = math.clamp(num(p, "spin", 0), -MAX_RATE, MAX_RATE),
				bob = num(p, "bob", 0),
				bobRate = math.min(num(p, "bobRate", 0.4), MAX_RATE),
				cycle = math.min(num(p, "cycle", 0), MAX_RATE),
				pulse = math.min(num(p, "pulse", 0), MAX_RATE),
				hue = num(p, "hue", 0),
				sat = num(p, "sat", 0.8),
				dim = num(p, "dim", 0.4),
				phase = num(p, "phase", 0),
			}
			table.insert(set.parts, e)
		end
	end
	sets[folder] = set
end

local function scan()
	local plots = Workspace:FindFirstChild("Plots")
	if not plots then
		return
	end
	for _, plot in ipairs(plots:GetChildren()) do
		local pig = plot:FindFirstChild("PiggyBank")
		local folder = pig and pig:FindFirstChild(SkinFX.FOLDER)
		if folder and folder:IsA("Folder") then
			track(folder)
		end
	end
	for folder in pairs(sets) do
		if not folder.Parent then
			sets[folder] = nil
		end
	end
end

function SkinFX.start()
	require(script.Parent.ArcadeAnimator).start()
	require(script.Parent.SpectralFX).start()
	if started or not RunService:IsClient() then
		return
	end
	started = true
	task.spawn(function()
		while true do
			pcall(scan)
			task.wait(0.5)
		end
	end)
	local TAU = math.pi * 2
	RunService.Heartbeat:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		local t = os.clock()
		for folder, set in pairs(sets) do
			local anchor = set.anchor
			if not folder.Parent or not anchor.Parent then
				continue
			end
			local frame = anchor.CFrame
			if (frame.Position - eye).Magnitude > CULL then
				continue
			end
			-- Bob is authored in seat units; the anchor is 0.2 seat units, so
			-- its size gives the scale this pig was built at.
			local s = anchor.Size.X / 0.2
			for _, e in ipairs(set.parts) do
				local p = e.part
				if e.orbit ~= 0 or e.spin ~= 0 or e.bob ~= 0 then
					local cf = frame
					if e.orbit ~= 0 then
						cf *= CFrame.Angles(0, t * e.orbit * TAU, 0)
					end
					if e.bob ~= 0 then
						cf *= CFrame.new(0, math.sin((t * e.bobRate + e.phase) * TAU) * e.bob * s, 0)
					end
					cf *= CFrame.new(e.rest.Position)
					if e.spin ~= 0 then
						cf *= CFrame.Angles(0, t * e.spin * TAU, 0)
					end
					p.CFrame = cf * e.rest.Rotation
				end
				if e.cycle > 0 then
					p.Color = Color3.fromHSV((e.hue + t * e.cycle) % 1, e.sat, 1)
				elseif e.pulse > 0 then
					local v = (math.cos((t * e.pulse + e.phase) * TAU) + 1) / 2
					p.Color = Color3.fromHSV(e.hue, e.sat, e.dim + (1 - e.dim) * v)
				end
			end
		end
	end)
end

return SkinFX
