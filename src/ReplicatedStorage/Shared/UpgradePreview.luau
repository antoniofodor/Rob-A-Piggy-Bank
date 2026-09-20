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
-- THE EARN PAIR
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
builders.capacity = function()
	local GAP = 0.9
	local small = pig(0.5, 0)
	local big = pig(1.0, small.X + GAP)
	local tall = math.max(small.Y, big.Y)
	-- Across the gap: from over the small pig to over the big one.
	local from = small.X * 0.55
	local to = small.X + GAP + big.X * 0.45
	-- 0.6 and not 0.45: modelled against the 2.2-stud pig, the lower barb of
	-- the arrowhead came within 0.14 of the big pig's crown at 0.45, which is
	-- inside the noise this project calls a placement rather than a clearance.
	-- At 0.6 it is 0.29, and the head still points AT the pig, which is the read.
	arrow((from + to) / 2, tall + 0.6, to - from, 30, 0.28, UP)
	faceCamera()
end


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
builders.sack = function(level)
	local s = 0.8 + level * 0.18
	local cloth = Color3.fromRGB(176, 140, 96)
	add("Bag", Vector3.new(2.4 * s, 2.6 * s, 2.2 * s), CFrame.new(0, 1.3 * s, 0), cloth, PLAIN, Enum.PartType.Ball)
	add("Neck", Vector3.new(0.5 * s, 1.1 * s, 1.1 * s), CFrame.new(0, 2.6 * s, 0) * UPRIGHT,
		cloth:Lerp(Color3.new(0, 0, 0), 0.2), PLAIN, Enum.PartType.Cylinder)
	add("Tie", Vector3.new(0.2 * s, 1.25 * s, 1.25 * s), CFrame.new(0, 2.5 * s, 0) * UPRIGHT,
		RUNG[level] or RUNG[1], PLAIN, Enum.PartType.Cylinder)
	add("Mark", Vector3.new(0.9 * s, 0.9 * s, 0.1), CFrame.new(0, 1.3 * s, 1.08 * s),
		Color3.fromRGB(240, 198, 76), PLAIN, Enum.PartType.Ball)
	for i = 1, level * 2 do
		local a = i * 2.4
		add("Coin", Vector3.new(0.14, 0.7, 0.7),
			CFrame.new(math.cos(a) * (1.4 * s + 0.2 * i), 0.1 + (i % 3) * 0.08, math.sin(a) * 0.9 + 1.2 * s) * UPRIGHT,
			Color3.fromRGB(240, 198, 76), PLAIN, Enum.PartType.Cylinder)
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
