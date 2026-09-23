--!strict
--[[
	UpgradePreview -- a picture of every rung of every upgrade tree.

	The Upgrades tab is a TIER LIST: each tree shows all of its levels as
	cards, the bought ones bright, the next one to buy outlined, and the rest
	faded and locked. A pip ladder said how far along you are; a row of
	pictures says what you are working TOWARD, which is the reason to buy the
	next one at all.

	Built around the ORIGIN and only ever seen in a ViewportFrame (the icon
	helper re-centres on the bounding box), so there is no ground line to
	respect -- the same contract ThiefModel and GadgetModel keep.

	WHERE EACH PICTURE COMES FROM:
	  * locks   -- the vault dial, from `Config.LOCK_TIERS`, the table the
	              piggy's own dial is built from.
	  * fences  -- a short run of the tier's style, in primitives. The real
	              panels are meshes loaded with CreateMeshPartAsync, which a
	              client cannot call.
	  * the rob tree -- small built objects that get fancier per level.
	  * income/capacity -- flat diagrams, and DELIBERATELY THE SAME AT EVERY
	              RUNG. Those two ladders run to `ABSOLUTE_MAX_LEVEL` (60), and
	              sixty near-identical pictures is the "4.4 pixels a pip"
	              complaint one level up. They are ICONS saying what the upgrade
	              IS; the NOW/NEXT comparison beside them says what a rung is
	              worth.

	Metal is SmoothPlastic here on purpose: this project has recorded
	`Material.Metal` rendering gold as olive beside a flat gold.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PiggyModel = require(ReplicatedStorage.Shared.PiggyModel)

local UpgradePreview = {}

local PLAIN = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon

-- Every rung's accent, cheap to dear: iron, bronze, silver, gold, and a
-- deep violet for a fifth rung. The rob-tree objects wear these.
local RUNG = {
	Color3.fromRGB(122, 128, 138),
	Color3.fromRGB(176, 122, 66),
	Color3.fromRGB(198, 204, 214),
	Color3.fromRGB(240, 198, 76),
	Color3.fromRGB(150, 84, 222),
}

local model: Model

local function add(name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?,
	shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Color = colour
	p.Material = material or PLAIN
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

-- Cylinders take their length on X: a disc facing +Z is (thickness, d, d)
-- turned a quarter about Y, which sends its local +X to world -Z (so a
-- part pushed toward the viewer at +Z takes a NEGATIVE local X).
local FACING_Z = CFrame.Angles(0, math.rad(90), 0)

-- The icon camera looks in from +X+Y+Z, so a dial authored facing +Z reads
-- nearly edge-on. Turned this far toward +X its spokes face the viewer.
local DIAL_TURN = CFrame.Angles(0, math.rad(40), 0)
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local builders: { [string]: (level: number) -> () } = {}

-- ============================================================
-- THE EARN PAIR (NOW ONE: `capacity` IS RETIRED WITH THE PIG'S CEILING)
-- ============================================================
--
-- BOTH OF THESE USED TO BE THE SAME PICTURE. `ShopUpgrades.modelFor` had one
-- branch -- income or capacity returned `Piggy.build(DEFAULT_SKIN)` -- so Earn
-- Faster and Bigger Piggy Bank were a plain piggy each, identical, on the two
-- cards a player has to choose between every time they have coins. This tab's
-- whole argument is that a PICTURE says what you are working toward where a
-- pip ladder only says how far along you are, and the one decision this
-- economy most needs a player to understand was the place it said nothing.
--
-- So: income is money going UP and capacity is the pig getting BIGGER, both
-- readable without the labels being read.
--
-- FLAT GRAPHICS ARE AUTHORED IN THE XY PLANE FACING +Z AND TURNED AT THE END.
-- The preview camera comes in along `Vector3.new(.65, .45, 1)` (ShopWidgets),
-- whose yaw is `atan(0.65 / 1)` = 33 degrees -- so a card authored facing +Z
-- reads obliquely until it is yawed to meet it. Same trick and same reason as
-- `DIAL_TURN` above, which the vault dial's spokes needed.
local FACE_CAMERA = CFrame.Angles(0, math.rad(33), 0)

local GOLD = RUNG[4]
local INK = Color3.fromRGB(38, 28, 32)
-- Green for the arrows rather than gold: gold is already the coins, and the
-- one thing an arrow has to say is UP.
local UP = Color3.fromRGB(86, 186, 104)

-- A bar lying in the XY plane. `angle` is degrees anticlockwise from +X, and
-- a Part takes its length on X, so this is one rotation about Z.
local function bar(name: string, x: number, y: number, length: number,
	thick: number, angle: number, colour: Color3): Part
	return add(name, Vector3.new(length, thick, thick * 0.9),
		CFrame.new(x, y, 0) * CFrame.Angles(0, 0, math.rad(angle)), colour)
end

-- A COIN SEEN FACE-ON, with a darker inner disc so it reads as struck rather
-- than as a flat counter -- the same two-piece trick `Theme.coin` draws in 2D.
local function coinFace(x: number, y: number, diameter: number)
	add("Coin", Vector3.new(0.18, diameter, diameter),
		CFrame.new(x, y, 0) * FACING_Z, GOLD, PLAIN, Enum.PartType.Cylinder)
	add("CoinFace", Vector3.new(0.12, diameter * 0.6, diameter * 0.6),
		CFrame.new(x, y, 0.06) * FACING_Z, GOLD:Lerp(INK, 0.3), PLAIN, Enum.PartType.Cylinder)
end

-- AN ARROW: a shaft and two head bars meeting at its tip.
--
-- Bars rather than a mirrored pair of WedgeParts, which is the other way this
-- project makes a triangle. A wedge's solid had to be RAYCAST to be believed
-- once already -- the field names do not say which way it slopes -- where two
-- bars at a known angle cannot be wrong about anything.
local function arrow(x: number, y: number, length: number, angle: number,
	thick: number, colour: Color3)
	local a = math.rad(angle)
	bar("Shaft", x, y, length, thick, angle, colour)
	local tipX, tipY = x + math.cos(a) * length / 2, y + math.sin(a) * length / 2
	local head = length * 0.42
	-- Swept back 145 degrees each side, so the head's included angle is 70.
	for _, sweep in ipairs({ 145, -145 }) do
		local b = a + math.rad(sweep)
		bar("Head", tipX + math.cos(b) * head / 2, tipY + math.sin(b) * head / 2,
			head, thick, angle + sweep, colour)
	end
end

-- THE REAL EXTENTS OF A BUILT MODEL, MEASURED PER PART THROUGH ITS OWN CFRAME.
--
-- Never `Model:GetBoundingBox()` for an EXTENT: it is oriented by the model's
-- PIVOT, which for a model with no PrimaryPart is whatever part the builder
-- happened to make first -- and this project has twice paid for that, once
-- reading a tube man's HEIGHT as its width and once measuring a castle's
-- orbiting shards sixty studs up. The POSITION it returns is safe, which is
-- all the centring below asks of it.
--
-- The projection is the one this project already wrote down for exactly this:
-- half the extent along an axis is the sum of each local axis' contribution to
-- it, so a part on any angle is measured correctly rather than conveniently.
local function extents(m: Model): (Vector3, Vector3)
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = Vector3.new(-math.huge, -math.huge, -math.huge)
	local found = false
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			found = true
			local part = d :: BasePart
			local cf, size = part.CFrame, part.Size
			local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
			local half = Vector3.new(
				math.abs(r.X) * size.X / 2 + math.abs(u.X) * size.Y / 2 + math.abs(l.X) * size.Z / 2,
				math.abs(r.Y) * size.X / 2 + math.abs(u.Y) * size.Y / 2 + math.abs(l.Y) * size.Z / 2,
				math.abs(r.Z) * size.X / 2 + math.abs(u.Z) * size.Y / 2 + math.abs(l.Z) * size.Z / 2)
			lo = lo:Min(cf.Position - half)
			hi = hi:Max(cf.Position + half)
		end
	end
	if not found then
		return Vector3.zero, Vector3.zero
	end
	return lo, hi
end

-- THE REAL PIGGY, SCALED, rather than a hand-built lookalike.
--
-- `PiggyModel.build` is the model a thief carries home, and this card already
-- rendered it -- so using it twice at two sizes cannot drift from what a piggy
-- bank looks like, where a second pig drawn out of balls and cylinders would
-- drift the first time either was touched. That is the argument
-- `Decor.buildOne` already makes about the disguise's wheelie bin.
--
-- SEATED BY ITS BOTTOM-LEFT CORNER, NOT ITS CENTRE, AND NOTHING ABOUT THE
-- ARRANGEMENT IS A NUMBER SOMEBODY TYPED.
--
-- Bottom-aligned is what makes the pair read as two pigs standing on one shelf
-- rather than as two pigs floating at one height -- the same call `House.build`
-- makes pinning a tier by its FRONT wall. Left-aligned is what lets the caller
-- lay them out from the measured width of what was actually built, so the two
-- cannot grow into each other if the pig model is ever resized. It returns its
-- own scaled size for exactly that.
local function pig(scale: number, left: number): Vector3
	local built = PiggyModel.build(Config.DEFAULT_SKIN)
	local lo, hi = extents(built)
	local size = (hi - lo) * scale
	for _, d in ipairs(built:GetDescendants()) do
		if d:IsA("BasePart") then
			local part = d :: BasePart
			-- Relative to the model's own bottom-left-back corner, so the scale
			-- and the seat are one expression and the corner lands on `left`.
			local rel = part.CFrame.Position - lo
			part.Size = part.Size * scale
			part.CFrame = CFrame.new(Vector3.new(left, 0, -size.Z / 2) + rel * scale)
				* part.CFrame.Rotation
			-- `PiggyModel` builds the CARRIED pig, which is unanchored and
			-- Massless because it gets welded to a running thief. A preview is the
			-- inverse case -- the same flip `ShopFront` makes when it anchors
			-- whatever it is handed for a window display.
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CastShadow = false
		end
	end
	for _, child in ipairs(built:GetChildren()) do
		child.Parent = model
	end
	built:Destroy()
	return size
end

-- Turn the whole flat arrangement to meet the camera. Collected FIRST, or the
-- loop turns parts it has already turned -- the same two-pass shape
-- `builders.locks` uses for `DIAL_TURN`.
local function faceCamera()
	local built = {}
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") then
			table.insert(built, part)
		end
	end
	for _, part in ipairs(built) do
		(part :: BasePart).CFrame = FACE_CAMERA * (part :: BasePart).CFrame
	end
end

-- EARN FASTER: coins climbing to the right and getting bigger, under a rising
-- arrow. THREE coins and not six -- this is 156 pixels on a phone, and the
-- read has to survive being that small.
builders.income = function()
	coinFace(-1.95, -1.3, 1.05)
	coinFace(-0.15, -0.6, 1.4)
	coinFace(1.85, 0.3, 1.75)
	arrow(0.1, 2.15, 4.3, 32, 0.32, UP)
	faceCamera()
end

-- BIGGER PIGGY BANK: a small pig, a big one, and an arrow over the gap.
--
-- LAID OUT FROM WHAT WAS BUILT. The small pig is seated first, the big one is
-- placed past its measured right edge plus a gap, and the arrow is seated
-- clear of whichever is taller and spans the gap between them. So there is no
-- number here that a change to `PiggyModel`'s own size could make wrong --
-- which is not hypothetical on this model: it is the mesh pig when a template
-- has loaded and the primitives pig when one has not, and a client cannot call
-- `CreateMeshPartAsync` at all.
-- `builders.capacity` (a small pig, an arrow, a big pig) stood here and is
-- retired with the Bigger Piggy Bank rung; the pig has no ceiling to grow.


-- THE VAULT DIAL: a plate, a hub and `spokes` handles, in the tier's metal.
builders.locks = function(level)
	local tier = Config.LOCK_TIERS[level]
	if not tier then
		return
	end
	-- Built facing +Z, then turned toward the icon camera at the end.
	local built = {}
	local r = tier.radius
	add("Door", Vector3.new(0.3, r * 2 + 0.5, r * 2 + 0.5), FACING_Z * CFrame.new(0.05, 0, 0),
		Color3.fromRGB(58, 60, 68), PLAIN, Enum.PartType.Cylinder)
	add("Plate", Vector3.new(0.3, r * 2, r * 2), FACING_Z * CFrame.new(-0.2, 0, 0),
		tier.metal, PLAIN, Enum.PartType.Cylinder)
	add("Hub", Vector3.new(0.4, 0.8, 0.8), FACING_Z * CFrame.new(-0.5, 0, 0),
		tier.metal:Lerp(Color3.new(0, 0, 0), 0.25), PLAIN, Enum.PartType.Cylinder)
	for i = 1, tier.spokes do
		local a = (i - 1) / tier.spokes * math.pi * 2
		add("Spoke", Vector3.new(0.22, r * 1.05, 0.22),
			CFrame.new(0, 0, 0.62) * CFrame.Angles(0, 0, a) * CFrame.new(0, r * 0.52, 0),
			tier.metal:Lerp(Color3.new(1, 1, 1), 0.15))
		add("Knob", Vector3.new(0.34, 0.34, 0.34),
			CFrame.new(0, 0, 0.62) * CFrame.Angles(0, 0, a) * CFrame.new(0, r * 1.05, 0),
			tier.metal, PLAIN, Enum.PartType.Ball)
	end
	for _, part in ipairs(model:GetChildren()) do
		table.insert(built, part)
	end
	for _, part in ipairs(built) do
		(part :: BasePart).CFrame = DIAL_TURN * (part :: BasePart).CFrame
	end
end

-- A SHORT RUN OF FENCE in the tier's style, at the tier's own height so the
-- ladder visibly climbs.
builders.fences = function(level)
	local tier = Config.FENCE_TIERS[level]
	if not tier then
		return
	end
	local h = tier.decorTop or tier.top or 4
	local style = tier.style
	local wood = Color3.fromRGB(122, 84, 52)
	if style == "rickety" then
		for i, x in ipairs({ -2.4, 0, 2.4 }) do
			add("Post", Vector3.new(0.45, h, 0.45),
				CFrame.new(x, h / 2, 0) * CFrame.Angles(0, 0, math.rad(({ 7, -4, 10 })[i])), wood)
		end
		add("Rail", Vector3.new(5.6, 0.35, 0.2), CFrame.new(0, h * 0.7, 0.3) * CFrame.Angles(0, 0, math.rad(-5)), wood)
		add("Rail", Vector3.new(3.0, 0.35, 0.2), CFrame.new(-1.3, h * 0.3, 0.3) * CFrame.Angles(0, 0, math.rad(8)), wood)
	elseif style == "picket" then
		local white = Color3.fromRGB(244, 242, 234)
		for i = -3, 3 do
			local x = i * 0.85
			add("Picket", Vector3.new(0.55, h - 0.4, 0.18), CFrame.new(x, (h - 0.4) / 2, 0), white)
			add("Tip", Vector3.new(0.39, 0.39, 0.18),
				CFrame.new(x, h - 0.4, 0) * CFrame.Angles(0, 0, math.rad(45)), white)
		end
		add("Rail", Vector3.new(6.2, 0.3, 0.16), CFrame.new(0, h * 0.72, -0.17), white)
		add("Rail", Vector3.new(6.2, 0.3, 0.16), CFrame.new(0, h * 0.25, -0.17), white)
	else
		-- Barbed, electric and the moat all stand on the same tall wall.
		local wall = if style == "barbed"
			then Color3.fromRGB(96, 100, 110)
			else Color3.fromRGB(48, 58, 84)
		for _, x in ipairs({ -3, 3 }) do
			add("Post", Vector3.new(0.5, h, 0.5), CFrame.new(x, h / 2, 0), wall)
		end
		add("Panel", Vector3.new(5.5, h * 0.72, 0.2), CFrame.new(0, h * 0.4, 0),
			wall:Lerp(Color3.new(1, 1, 1), 0.12))
		if style == "barbed" then
			for i = 0, 2 do
				add("Wire", Vector3.new(6.2, 0.1, 0.1), CFrame.new(0, h * 0.82 + i * 0.28, 0),
					Color3.fromRGB(170, 172, 178))
				for k = -2, 2 do
					add("Barb", Vector3.new(0.3, 0.08, 0.08),
						CFrame.new(k * 1.2, h * 0.82 + i * 0.28, 0) * CFrame.Angles(0, 0, math.rad(45)),
						Color3.fromRGB(170, 172, 178))
				end
			end
		else
			for i = 0, 1 do
				add("Live", Vector3.new(6.2, 0.14, 0.14), CFrame.new(0, h * 0.84 + i * 0.35, 0),
					Color3.fromRGB(40, 150, 255), NEON)
			end
		end
		if style == "moat" then
			add("Water", Vector3.new(7, 0.3, 2.4), CFrame.new(0, 0.15, 1.9), Color3.fromRGB(46, 120, 196))
			add("Bank", Vector3.new(7.4, 0.4, 0.4), CFrame.new(0, 0.2, 3.2), Color3.fromRGB(150, 146, 136))
		end
	end
end

-- NO GUARD BUILDER. The Guard rung is retired (`Config.DOG_LEVEL`): every plot
-- has the same dog and variety comes from coats, so there is no ladder to
-- draw. The dog rig lives in ServerStorage and is not replicated -- see the
-- note in GuardVisual before drawing one on a card again.

-- LOCKPICKS: a ring carrying one more pick per level.
builders.lockpicks = function(level)
	local metal = RUNG[level] or RUNG[1]
	add("Ring", Vector3.new(0.25, 1.8, 1.8), FACING_Z, Color3.fromRGB(70, 72, 80), PLAIN, Enum.PartType.Cylinder)
	add("Hole", Vector3.new(0.3, 1.1, 1.1), FACING_Z, Color3.fromRGB(236, 230, 214), PLAIN, Enum.PartType.Cylinder)
	for i = 1, level + 1 do
		local a = math.rad(-40 + (i - 1) * 22)
		local pick = CFrame.Angles(0, 0, a) * CFrame.new(0, -2.0, 0)
		add("Pick", Vector3.new(0.18, 2.4, 0.12), pick, metal)
		add("Tip", Vector3.new(0.4, 0.14, 0.12), pick * CFrame.new(0.12, -1.15, 0), metal)
	end
end

-- BIGGER SACK: the bag grows, and so does the pile spilling from it.
--
-- THE SHOP'S OWN ARTWORK IS THE SPEC (designer, 2026-09-22), and this builder
-- is not only a card: `HeistService.buildLootBag` builds the CARRIED LOOT out
-- of it at the thief's own sack level, so the shelf, the preview and the
-- getaway are one sack rather than three. The picture is
-- `assets/shop-ui/icon-system-v1/sack.png`, rendered from
-- `sources/sack.blend` -- a peach cloth drawstring sack with a rope bow at a
-- gathered neck, a wavy open mouth above it, a gold coin on its front stamped
-- with a pig snout, and coins at its foot. `assets/loot-bag/` holds that same
-- object exported for upload, and its UPLOADS.md carries the `Config.LOOT_MESH`
-- row that would swap this build for the mesh once the ids exist.
--
-- THE COLOURS ARE SAMPLED OFF THE RENDER RATHER THAN OFF THE BLEND, and the
-- two disagree. The blend is flat material colours lit by Cycles studio lamps,
-- so its raw `tan` is (231, 164, 83) -- an orange nothing in the artwork shows.
-- What the artwork READS as, measured across the body of `sack.png`, is a
-- light warm peach, and that is what a player compares this against.
--
-- SmoothPlastic throughout, like everything else in this file: `Fabric` is a
-- dark noisy texture rather than a colour, and a peach sack in it renders
-- muddy brown at any distance.
local CLOTH = Color3.fromRGB(226, 182, 146)
-- The inside of the mouth, seen down the throat. Deeper than the body, so an
-- opening reads as an opening.
local CLOTH_DEEP = Color3.fromRGB(198, 138, 110)
local ROPE = Color3.fromRGB(150, 96, 66)
-- The coin's FIELD is the game's own gold (`GOLD`) and its RIM is a deeper
-- one, so the rim can stand proud AROUND the field rather than being a line
-- drawn on a flat disc. Nothing here is dug: a recess is made by standing
-- something proud around the dark, never by sinking the dark.
local GOLD_DEEP = Color3.fromRGB(198, 150, 52)
-- The snout is pink because pink means the pig everywhere else in this game.
-- Its nostrils stand PROUD rather than being holes, for the reason above and
-- the same call `ShopScenes`' own piggy already makes.
local SNOUT = Color3.fromRGB(246, 206, 198)
local NOSTRIL = Color3.fromRGB(150, 84, 92)

builders.sack = function(level)
	local s = 0.8 + level * 0.18

	-- THE BODY. `Bag` keeps its name and its exact size, because
	-- `buildLootBag` renames it `Body` and makes it the PrimaryPart: that means
	-- `CarryPose.HOLD` lands on THIS ball's centre, and moving it moves the
	-- carried loot out of the thief's own hands.
	add("Bag", Vector3.new(2.40 * s, 2.60 * s, 2.20 * s), CFrame.new(0, 1.30 * s, 0),
		CLOTH, PLAIN, Enum.PartType.Ball)
	-- A sack sat down on the ground spreads at the bottom.
	--
	-- IT IS SIZED SO THAT IT NEVER REACHES PAST THE BODY ON ANY AXIS, and that
	-- is a clearance rather than a taste call. Seated at `CarryPose.HOLD` this
	-- bag is welded to a thief's chest, so anything wider or deeper than the
	-- `Bag` ball is a new thing to clash with their arms and legs -- a first
	-- pass at 2.56 x 2.30 put the flare 0.04 studs deeper into the thighs than
	-- the bare body already goes. At 2.38 x 2.08 against the body's 2.40 x 2.20
	-- its whole box is inside the body's, so the thief's clearances are exactly
	-- what they were before this builder was touched.
	--
	-- It still reads, because what matters is the body's width AT THIS HEIGHT
	-- rather than at its equator: the ellipsoid is 0.88 half-wide at y 0.42,
	-- so the flare stands 0.31 proud of it all the way round.
	add("Foot", Vector3.new(2.38 * s, 0.84 * s, 2.08 * s), CFrame.new(0, 0.42 * s, 0),
		CLOTH, PLAIN, Enum.PartType.Ball)

	-- THE NECK, THE ROPE AND THE MOUTH, in that order up the bag. Every span
	-- overlaps the next on purpose -- two cylinder ends at one height would be
	-- the coplanar flicker this project has already paid for three times:
	--   neck  2.25 .. 2.95 s   gathered cloth, radius 0.50
	--   wrap  2.57 .. 2.83 s   the drawstring wound round it, radius 0.60
	--   mouth 2.90 .. 3.42 s   the dark throat, radius 0.57
	add("Neck", Vector3.new(0.70 * s, 1.00 * s, 1.00 * s), CFrame.new(0, 2.60 * s, 0) * UPRIGHT,
		CLOTH, PLAIN, Enum.PartType.Cylinder)
	add("Wrap", Vector3.new(0.26 * s, 1.20 * s, 1.20 * s), CFrame.new(0, 2.70 * s, 0) * UPRIGHT,
		ROPE, PLAIN, Enum.PartType.Cylinder)
	add("Mouth", Vector3.new(0.52 * s, 1.14 * s, 1.14 * s), CFrame.new(0, 3.16 * s, 0) * UPRIGHT,
		CLOTH_DEEP, PLAIN, Enum.PartType.Cylinder)

	-- THE WAVY RIM IS SEVEN BALLS AND NOT A SECOND CYLINDER, because a cylinder
	-- is SOLID: a dark disc set inside one is a disc nobody can see, which is
	-- the water-bowl mistake this project already recorded. Seven at radius 0.70
	-- overlap each other by 0.07 -- six leave gaps and read as beads -- and they
	-- stand 0.22 above the mouth's own top, so the cloth is proud around the
	-- dark and the opening reads as an opening rather than as a plug.
	--
	-- AND THE RIM IS AS HIGH AS IT IS BECAUSE OF THE THIEF'S HEAD, WHICH IS A
	-- CLEARANCE RATHER THAN A TASTE CALL. Seated at `CarryPose.HOLD` this rim
	-- is the part of the bag nearest the carrier's face, and LOWERING IT MAKES
	-- THAT WORSE rather than better: dropped to 3.16 it stops passing over the
	-- head and starts passing in FRONT of it, and the worst level's clearance
	-- went 0.34 studs to 0.15. Measured sphere-to-box against a generous head
	-- -- x +-0.6, y 1.9 .. 3.0, z +-0.6, generous because HAIR AND HATS ARE
	-- THE PLAYER'S CHOICE and not this file's.
	for i = 1, 7 do
		local a = (i - 1) * (2 * math.pi / 7)
		local lift = if i % 2 == 0 then 0.12 * s else 0
		add("Frill", Vector3.new(0.68 * s, 0.68 * s, 0.68 * s),
			CFrame.new(math.cos(a) * 0.70 * s, 3.30 * s + lift, math.sin(a) * 0.70 * s),
			CLOTH, PLAIN, Enum.PartType.Ball)
	end

	-- THE BOW: two loops and two tails hung off a knot on the front of the wrap.
	-- A tail is a cylinder with a ball of the SAME DIAMETER on its end, which is
	-- tangent by construction and therefore has no rim at the join -- the
	-- dimension match the drip statue's holdall already turns on.
	add("Knot", Vector3.new(0.34 * s, 0.34 * s, 0.34 * s), CFrame.new(0, 2.70 * s, 0.60 * s),
		ROPE, PLAIN, Enum.PartType.Ball)
	for _, side in ipairs({ -1, 1 }) do
		add("Loop", Vector3.new(0.54 * s, 0.44 * s, 0.22 * s),
			CFrame.new(side * 0.44 * s, 2.84 * s, 0.56 * s)
				* CFrame.Angles(0, 0, math.rad(side * -22)),
			ROPE, PLAIN, Enum.PartType.Ball)
		local tail = CFrame.new(side * 0.30 * s, 2.40 * s, 0.62 * s)
			* CFrame.Angles(0, 0, math.rad(side * 18)) * UPRIGHT
		add("Tail", Vector3.new(0.60 * s, 0.15 * s, 0.15 * s), tail, ROPE, PLAIN, Enum.PartType.Cylinder)
		add("TailTip", Vector3.new(0.15 * s, 0.15 * s, 0.15 * s),
			tail * CFrame.new(-0.30 * s, 0, 0), ROPE, PLAIN, Enum.PartType.Ball)
	end

	-- THE COIN ON THE FRONT: four discs at four depths, no two of them sharing
	-- a face plane.
	--   rim    0.910 .. 1.210 s   deep gold, standing proud all the way round
	--   field  0.920 .. 1.140 s   the game's gold, recessed 0.07 inside the rim
	--   snout  1.100 .. 1.260 s   pale pink, embossed 0.05 past the rim
	--   holes  1.235 .. 1.335 s   two dots, proud rather than dug
	-- The body's own surface at this height is z 1.087 s, so the rim's outer
	-- edge is buried and the coin sits IN the cloth rather than on it.
	add("Mark", Vector3.new(0.30 * s, 1.16 * s, 1.16 * s),
		CFrame.new(0, 1.10 * s, 1.06 * s) * FACING_Z, GOLD_DEEP, PLAIN, Enum.PartType.Cylinder)
	add("MarkField", Vector3.new(0.22 * s, 0.86 * s, 0.86 * s),
		CFrame.new(0, 1.10 * s, 1.03 * s) * FACING_Z, GOLD, PLAIN, Enum.PartType.Cylinder)
	add("Snout", Vector3.new(0.16 * s, 0.50 * s, 0.50 * s),
		CFrame.new(0, 1.10 * s, 1.18 * s) * FACING_Z, SNOUT, PLAIN, Enum.PartType.Cylinder)
	for _, side in ipairs({ -1, 1 }) do
		add("Nostril", Vector3.new(0.10 * s, 0.11 * s, 0.11 * s),
			CFrame.new(side * 0.11 * s, 1.10 * s, 1.285 * s) * FACING_Z,
			NOSTRIL, PLAIN, Enum.PartType.Cylinder)
	end

	-- THE COINS AT ITS FOOT. ONE ALWAYS, THEN TWO MORE PER LEVEL: a level-0 bag
	-- with none reads as an empty sack rather than as a small haul, and this is
	-- the bag a thief carries from their very first robbery. The LADDER is still
	-- the thing that grows.
	--
	-- They hug the bag rather than spreading outward with `i`. The ring they
	-- replace grew by 0.2 a coin, so a maxed sack laid coins 3.7 studs off its
	-- own centre -- out past the thief's arms, on a model welded to their chest.
	--
	-- ITS CENTRE IS ABOVE ITS OWN RADIUS BECAUSE IT IS TILTED. Half of 0.94 is
	-- 0.47 and a disc seated there would stand exactly on the ground -- if it
	-- were upright. Leaned, its own axis-aligned reach grows, and at 0.47 it
	-- measured 0.0395 THROUGH the floor: the thing to seat is the tilted
	-- part's span, not the shape's radius.
	add("LeanCoin", Vector3.new(0.18 * s, 0.94 * s, 0.94 * s),
		CFrame.new(-1.16 * s, 0.52 * s, 0.70 * s)
			* CFrame.Angles(math.rad(10), math.rad(-32), 0) * FACING_Z,
		GOLD, PLAIN, Enum.PartType.Cylinder)
	for i = 1, level * 2 do
		local a = 0.9 + i * 2.39
		local r = 1.06 * s + 0.07 * s * (i % 4)
		-- EVERY COIN GETS ITS OWN HEIGHT, and that is the coplanar rule rather
		-- than tidiness: two flat discs sharing a height and overlapping share a
		-- face plane, and 2.39 radians of step wraps close enough to touch by
		-- the sixth coin.
		local h = 0.10 * s + 0.035 * s * (i % 5) + 0.16 * s * math.floor((i - 1) / 5)
		add("Coin", Vector3.new(0.17 * s, 0.76 * s, 0.76 * s),
			CFrame.new(math.cos(a) * r, h, math.sin(a) * r * 0.62 + 0.62 * s) * UPRIGHT,
			GOLD, PLAIN, Enum.PartType.Cylinder)
	end
end

-- A SHOE, used twice: boots for running out, sneakers for creeping in.
local function shoe(colour: Color3, sole: Color3, high: boolean, level: number, wings: boolean)
	add("Sole", Vector3.new(1.3, 0.35, 3.0), CFrame.new(0, 0.18, 0), sole)
	add("Toe", Vector3.new(1.3, 0.9, 1.3), CFrame.new(0, 0.7, 0.9), colour, PLAIN, Enum.PartType.Ball)
	add("Body", Vector3.new(1.25, 1.0, 1.9), CFrame.new(0, 0.8, -0.35), colour)
	if high then
		add("Shaft", Vector3.new(1.2, 1.6, 1.2), CFrame.new(0, 1.9, -0.7), colour)
	end
	-- A stripe per level on the side, which is the ladder you can count.
	for i = 1, level do
		add("Stripe", Vector3.new(0.08, 0.16, 0.5),
			CFrame.new(0.65, 0.55 + i * 0.22, -0.2 - i * 0.12) * CFrame.Angles(math.rad(-25), 0, 0),
			RUNG[level] or RUNG[1])
	end
	if wings and level >= 3 then
		for _, side in ipairs({ -1, 1 }) do
			add("Wing", Vector3.new(0.1, 0.9, 1.4),
				CFrame.new(side * 0.72, if high then 2.2 else 1.1, -0.9) * CFrame.Angles(math.rad(-30), 0, math.rad(side * 20)),
				Color3.fromRGB(250, 250, 250))
		end
	end
end

builders.boots = function(level)
	shoe(Color3.fromRGB(214, 74, 60):Lerp(RUNG[level] or RUNG[1], 0.35), Color3.fromRGB(40, 40, 46), true, level, true)
end

builders.tiptoe = function(level)
	shoe(Color3.fromRGB(96, 178, 226):Lerp(RUNG[level] or RUNG[1], 0.3), Color3.fromRGB(244, 242, 234), false, level, false)
end

-- The words under a tier card: the tier's own name where the catalogue has
-- one, otherwise just the level.
function UpgradePreview.label(key: string, level: number): string
	if key == "fences" then
		local tier = Config.FENCE_TIERS[level]
		return (tier and tier.label) or ("Lv " .. level)
	elseif key == "locks" then
		local tier = Config.LOCK_TIERS[level]
		return (tier and tier.name) or ("Lv " .. level)
	end
	return "Lv " .. level
end

-- A fresh model for one rung, or nil for an upgrade with no picture.
function UpgradePreview.build(key: string, level: number): Model?
	local build = builders[key]
	if not build then
		return nil
	end
	model = Instance.new("Model")
	model.Name = ("Tier_%s_%d"):format(key, level)
	local ok, err = pcall(build, level)
	if not ok then
		warn(("[UpgradePreview] %s tier %d failed: %s"):format(key, level, tostring(err)))
	end
	if #model:GetChildren() == 0 then
		model:Destroy()
		return nil
	end
	return model
end

return UpgradePreview
