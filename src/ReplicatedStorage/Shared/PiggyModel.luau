--!strict
--[[
	PiggyModel

	The little piggy, built small: the one a thief carries away, and the one
	the shop renders in every skin tile.

	IN Shared BECAUSE THE SHOP RENDERS IT. PiggyBank itself is full of things
	the shop has no business loading -- prompts, sounds, the coin pile, the
	vault dial -- so only the shape moved, and PiggyBank now calls into here
	for the carried loot. One piggy, two callers, no chance of the shop
	showing a skin that no longer matches the thing on the lawn.

	SKIN PATTERNS LIVE HERE FOR THE SAME REASON, and they are the larger half
	of this file now. See the block below `PiggyModel.build`.

	Facing +Z like everything else in this world, and authored with its feet
	at y=0 so it can be dropped on a surface by its own origin.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PiggyModel = {}

local NEAR_BLACK = Color3.fromRGB(26, 26, 30)

-- The mini's body is a 2.2-stud ball centred here. Both numbers are needed by
-- the pattern call at the bottom of `build`, so they are named rather than
-- written twice.
local MINI_R = 1.1
local MINI_CENTRE = Vector3.new(0, 1.15, 0)

-- ============================================================
-- SKIN PATTERNS
-- ============================================================
--
-- A skin used to be two colours -- `body` on the sphere, `trim` on the snout,
-- tail, ears and legs -- so a "Zebra Piggy" could only ever be a white pig
-- with black legs. `pattern` is the third channel: marks laid ON the body
-- sphere, built out of parts like everything else in this project, because an
-- uploaded texture is a third-party asset that can be moderated away and take
-- the whole catalogue's readability with it.
--
-- IT LIVES HERE BECAUSE THE SHOP RENDERS THE REAL PIGGY. PiggyBank draws the
-- twelve on the street and PiggyModel draws the shop tile and the carried
-- loot, and a second near-identical copy of this drifts from the first the
-- moment either is touched -- the same argument the top of this file already
-- makes about the shape. One builder, two callers, one look.
--
-- EVERY MARK IS PLACED BY DIRECTION, NEVER BY A COORDINATE. Normalise a
-- direction, multiply by a radius solved against the body's own, and the mark
-- is seated on the curve by construction. This is the turtle's mottling in
-- Decor.luau, and the rule it records is the one that matters: a mark placed
-- by hand floats a tenth of a stud off a curved surface and reads as a bug
-- rather than as a marking.
--
-- EVERY SIZE IS A FRACTION OF THE BODY RADIUS, which is what lets one builder
-- serve a six-stud piggy on a lawn and a 1.1-stud piggy in a shop tile. A
-- stud figure written here would be right on one of them and wrong on the
-- other, and only one of the two is ever looked at closely.
--
-- DETERMINISTIC OR IT IS NOT THE SAME SKIN. Every jitter comes from
-- `Random.new(spec.seed)` making the same calls in the same order, so the
-- Zebra on your lawn, the Zebra in my shop tile and the Zebra a thief is
-- running off with are the same animal. An unseeded `math.random` would give
-- every client a different one wearing the same name.

local PATTERN_FOLDER = "Pattern"

-- How far proud of the body a mark stands at its highest point, as a fraction
-- of the body radius. Proud rather than flush for the reason the road, the
-- moat and the guard dog's eyes each learned: two surfaces at one depth give
-- the renderer nothing to sort by and flicker through each other.
local LIFT = 0.02

-- NOTHING THE GAME OWNS MAY STAND IN AN ACCESSORY ANCHOR, and the hat's is
-- the only one this can reach. It sits at y 14.15 against a body top of 14.5,
-- so a brim is authored 0.35 studs INSIDE the sphere and anything standing
-- further out than that at the crown swallows it -- exactly the Vault Lock
-- padlock bug, from the other direction.
--
-- Stripes are allowed up there and spots are not, and that is arithmetic
-- rather than taste. A stripe segment's top face clears the body by LIFT
-- alone (0.12 studs at R=6) plus the sag of one flat plate, so it passes
-- under a brim already a third of a stud in. A spot is a disc laid flat on a
-- curve, and a flat disc of radius `a` stands a*a/(2R) proud at its rim
-- before any lift at all -- 0.27 studs on a cow blotch, which is through the
-- brim. So spots stop below this latitude and stripes do not.
local CROWN_LIMIT = 0.72

-- The face is a snout, two nostrils and two eyeballs that already reach 0.45
-- studs proud of the sphere. A spot landing there reads as a bruise rather
-- than as markings, so the forward cap is skipped at anything near eye height.
local FACE_LIMIT = 0.70

local GOLDEN_ANGLE = 2.39996323

export type PatternOpts = {
	-- The BODY PART'S OWN CFrame, never a stored origin. The far row of plots
	-- is turned half round by one PivotTo after everything in it is built, so
	-- a position measured off an origin captured at build time is stale for
	-- half the piggies on the street; the body's own frame carries that turn.
	frame: CFrame,
	radius: number,
	anchored: boolean,
	weldTo: BasePart?,
	material: Enum.Material,
	transparency: number,
}

local function markPart(folder: Folder, name: string, size: Vector3, cf: CFrame,
	shape: Enum.PartType, colour: Color3, opts: PatternOpts): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Shape = shape
	p.Color = colour
	p.Material = opts.material
	p.Transparency = opts.transparency
	p.Anchored = opts.anchored
	-- The piggy stands on ground a thief runs across and a dog patrols, so a
	-- marking may never body-block, never be raycast and never throw a shadow
	-- -- the same three properties every lawn ornament carries, for the same
	-- reason.
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder

	-- Anchoring is a fact about where a thing was designed to go: the plot
	-- piggy is anchored to its lawn and the mini is welded to a thief. An
	-- anchored part welded to a humanoid pins the humanoid, so the caller
	-- says which it wants and this never assumes.
	if opts.weldTo then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = opts.weldTo
		weld.Part1 = p
		weld.Parent = p
	end
	return p
end

-- Bands girdling the body across the spine: zebra, tiger, bee, and the glowing
-- traces on the neon skins.
--
-- A BAND IS A ROW OF SEGMENTS, because one part cannot be an annulus. The same
-- shape as the vault's rim, and turned the same way: a segment sits at
-- (cos phi, sin phi) on its own ring, so its long axis is the TANGENT there
-- and its thickness axis is the RADIUS. Getting that the wrong way round is
-- what turned the vault rim into a sunburst of spikes.
--
-- A SOLID DISC WAS THE OBVIOUS ONE PART AND CANNOT WORK HERE. A cylinder on
-- the spine axis, sized to break the surface, gives a perfectly even band --
-- and the body is translucent so the coin pile shows through it, which means
-- the rest of that disc reads as a dinner plate sitting inside the pig.
local function buildStripes(folder: Folder, spec: any, opts: PatternOpts)
	local R = opts.radius
	local rng = Random.new(spec.seed or 1)
	local count = math.max(1, spec.count or 5)
	local width = math.clamp(spec.width or 0.18, 0.04, 0.5) * R
	local spread = math.clamp(spec.spread or 0.62, 0.1, 0.85)
	local arc = math.rad(math.clamp(spec.arc or 195, 40, 350))
	local wobble = math.clamp(spec.wobble or 0, 0, 1)
	local colour = spec.colour or Color3.new(0, 0, 0)

	local lift = LIFT * R
	-- The longest arc one segment may span, and it was MEASURED AGAINST A HAT
	-- rather than chosen for looks.
	--
	-- A segment is a flat plate on a curve, so its CORNERS stand
	-- sqrt((R+lift)^2 + L^2 + W^2) - R proud of the sphere -- both half-extents
	-- count, and the length term dominates. At 0.70 that came out at 0.60 to
	-- 0.66 studs, and the test that matters is not the number: the hat anchor
	-- is authored 0.35 studs INSIDE this sphere, so a band crossing the crown
	-- comes up through the top of a cap. Measured, column by column against
	-- all five hats: the bare BODY already stands above a hat in 4 to 22
	-- columns by up to 0.35, and at 0.70 the bands added a breach of up to
	-- 0.58 over 17 to 48 more.
	--
	-- 0.45 puts the bands back inside the tolerance the piggy's own sphere
	-- already spends, for about half again as many parts. Cutting further is
	-- the wrong lever -- the width term alone is worth 0.19 on the widest
	-- band, so no segment length reaches flush.
	local maxSeg = 0.45 * R

	for i = 1, count do
		local t = if count == 1 then 0 else (-1 + 2 * (i - 1) / (count - 1))
		local z0 = t * spread * R + rng:NextNumber(-1, 1) * wobble * spread * R / (count * 2)
		z0 = math.clamp(z0, -0.85 * R, 0.85 * R)

		local ring = math.sqrt(math.max(R * R - z0 * z0, 0))
		if ring > 0.2 * R then
			local segs = math.max(3, math.ceil((ring * arc) / maxSeg))
			local step = arc / segs
			-- Overlapped rather than butted, so a band reads as one mark and
			-- not as a dashed line: the join is exactly where the eye goes
			-- looking for a seam.
			local segLen = ring * step * 1.22
			local w = width * (1 + rng:NextNumber(-1, 1) * wobble * 0.45)
			-- EXACTLY AS THICK AS IT HAS TO BE, WHICH IS WHAT STOPS A BAND
			-- READING AS PLATES BOLTED ON. A segment only has to keep its
			-- INNER face buried where the sphere falls away under its own
			-- corners; every stud past that is visible edge standing over the
			-- neighbouring segment. It was a flat 0.16R -- 0.96 studs at R=6
			-- against a requirement of 0.37 -- and photographed as a wall of
			-- shingles. Solved from the corner rather than chosen.
			local reach = math.sqrt((segLen / 2) ^ 2 + (w / 2) ^ 2)
			local thick = lift + (R - math.sqrt(math.max(R * R - reach * reach, 0))) + 0.03 * R

			for s = 1, segs do
				-- Centred on straight up, so a band that is not a full ring
				-- covers the back and both flanks -- which is all of the pig
				-- anybody standing on the pavement can see anyway.
				local phi = math.pi / 2 - arc / 2 + (s - 0.5) * step
				local n = Vector3.new(ring * math.cos(phi), ring * math.sin(phi), z0).Unit
				local tangent = Vector3.new(-math.sin(phi), math.cos(phi), 0)
				-- Local Y is the radius, so the outer face lands exactly LIFT
				-- proud of the sphere at the segment's midpoint.
				local seat = n * (R + lift - thick / 2)
				markPart(folder, "Stripe", Vector3.new(segLen, thick, w),
					opts.frame * CFrame.fromMatrix(seat, tangent, n),
					Enum.PartType.Block, colour, opts)
			end
		end
	end
end

-- Round marks scattered over the body: cow blotches, dalmatian dots, a
-- ladybird's spots, and -- with `bump` -- a sheep's fleece.
--
-- A DISC RATHER THAN A BALL, AND THE ARITHMETIC IS THE WHOLE REASON. A ball
-- sunk until it stands only LIFT proud shows almost nothing: on the real
-- numbers, a 1.8-radius ball on a 6-radius body shows a mark 0.77 across, and
-- to get a 1.8 blotch out of a ball that nearly flush it has to grow to 4.28
-- -- eight and a half studs of sphere sitting inside a translucent pig. A
-- tangent cylinder shows its whole face at the size it actually is.
--
-- `bump` is the exception and is a ball on purpose: a fleece is meant to be
-- lumpy, and lumpy is the one thing a flat disc cannot be.
local function buildSpots(folder: Folder, spec: any, opts: PatternOpts)
	local R = opts.radius
	local rng = Random.new(spec.seed or 1)
	local count = math.max(1, spec.count or 12)
	local size = math.clamp(spec.size or 0.16, 0.04, 0.35) * R
	local vary = math.clamp(spec.vary or 0.3, 0, 0.8)
	local bump = spec.bump == true
	local proud = math.clamp(spec.proud or 0.55, 0.1, 0.9)
	local colour = spec.colour or Color3.new(0, 0, 0)

	local lift = LIFT * R

	-- THE SPIRAL STARTS AT THE CROWN LIMIT RATHER THAN AT THE POLE, and that
	-- is a real fix rather than a tidy-up. Sweeping the whole sphere and then
	-- rejecting the top of it threw away a fifth of every count -- measured,
	-- a ladybird asking for 11 spots placed 7 -- so a spec's number meant one
	-- thing when it was written and another when it was drawn. Spreading over
	-- the band the marks may actually occupy costs nothing and makes `count`
	-- honest.
	local topY = CROWN_LIMIT - 0.02
	local bottomY = -0.6
	local span = topY - bottomY

	for i = 1, count do
		-- A golden-angle spiral, so marks spread rather than clump however
		-- many there are -- the same distribution the coin pile uses. Jittered
		-- afterwards, because a perfect spiral reads as a printed pattern and
		-- a cow is not printed.
		local y = math.clamp(topY - (i - 0.5) / count * span + rng:NextNumber(-1, 1) * 0.07,
			bottomY, topY)
		local ringF = math.sqrt(math.max(1 - y * y, 0))
		local theta = i * GOLDEN_ANGLE + rng:NextNumber(-1, 1) * 0.28
		local dir = Vector3.new(ringF * math.cos(theta), y, ringF * math.sin(theta))
		local radius = size * (1 + rng:NextNumber(-1, 1) * vary)

		local inFace = dir.Z > FACE_LIMIT and dir.Y < 0.5
		local inCrown = dir.Y > CROWN_LIMIT
		if not inFace and not inCrown then
			local n = dir.Unit
			-- Any vector off the axis will do for the second column: a
			-- cylinder is symmetric about its own, so only the axis matters.
			local side = if math.abs(n.Y) > 0.97 then Vector3.zAxis else Vector3.yAxis
			local up = n:Cross(side):Cross(n).Unit

			if bump then
				markPart(folder, "Fleece", Vector3.new(radius * 2, radius * 2, radius * 2),
					opts.frame * CFrame.new(n * (R - (1 - proud) * radius)),
					Enum.PartType.Ball, colour, opts)
			else
				-- THICKNESS IS SOLVED, NOT CHOSEN, for the reason the stripe
				-- segments are: a disc only has to keep its inner face buried
				-- where the sphere drops away under its own RIM, and every
				-- stud past that is a visible edge that turns a marking into
				-- a coin lying on the pig. A flat 0.12R was 0.72 studs on a
				-- ladybird spot that needed 0.16, and it photographed exactly
				-- like a sticker.
				local sag = R - math.sqrt(math.max(R * R - radius * radius, 0))
				local thick = lift + sag + 0.03 * R
				-- A Roblox cylinder's axis is its X axis, so the radial
				-- direction goes in the first column and the diameter is
				-- Size.Y/Z. Written the other way round this is a disc
				-- standing on edge, which is the mistake this project has now
				-- made five separate times.
				markPart(folder, "Spot", Vector3.new(thick, radius * 2, radius * 2),
					opts.frame * CFrame.fromMatrix(n * (R + lift - thick / 2), n, up),
					Enum.PartType.Cylinder, colour, opts)
			end
		end
	end
end

-- Tears the old marks down and lays the new ones. Rebuilt rather than diffed
-- for the same reason applyAccessories is: a skin changes a handful of times
-- in a session, and the bookkeeping that would save that work is exactly what
-- quietly leaks a stripe when two changes land in the same frame.
function PiggyModel.applyPattern(container: Instance, skin: any, opts: PatternOpts): Folder?
	local existing = container:FindFirstChild(PATTERN_FOLDER)
	if existing then
		existing:Destroy()
	end

	local spec = skin and skin.pattern
	if not spec then
		return nil
	end

	local folder = Instance.new("Folder")
	folder.Name = PATTERN_FOLDER

	-- A pattern may overrule the skin's own material and transparency, and
	-- both overrides earn their keep. A glowing trace on a deep Neon body has
	-- to be opaque or the 34%-transparent shell it is painted on dims it into
	-- the body colour, and a fleece wants to be plastic on a body that is
	-- glass.
	local resolved: PatternOpts = {
		frame = opts.frame,
		radius = opts.radius,
		anchored = opts.anchored,
		weldTo = opts.weldTo,
		material = spec.material or opts.material,
		transparency = if spec.transparency ~= nil then spec.transparency else opts.transparency,
	}

	if spec.kind == "stripes" then
		buildStripes(folder, spec, resolved)
	elseif spec.kind == "spots" then
		buildSpots(folder, spec, resolved)
	else
		-- Never fail silently. A skin naming a pattern kind nobody built is a
		-- purchase that visibly does nothing, which from the outside is
		-- indistinguishable from a broken item.
		warn(("PiggyModel: skin pattern kind %q is not built"):format(tostring(spec.kind)))
	end

	folder.Parent = container
	return folder
end

-- ============================================================
-- BUILD
-- ============================================================

function PiggyModel.build(skinKey: string): Model
	local skin = Config.getSkin(skinKey)
	local model = Instance.new("Model")
	model.Name = "StolenPiggy"

	local function piece(name: string, size: Vector3, cf: CFrame, color: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		p.CastShadow = false
		p.Color = color
		-- Solid, unlike the plot piggy. That one is translucent so the coin
		-- pile shows through; this one has no pile and just needs to read.
		p.Material = skin.material
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	local body = piece("Body", Vector3.new(MINI_R * 2, MINI_R * 2, MINI_R * 2),
		CFrame.new(MINI_CENTRE), skin.body)
	body.Shape = Enum.PartType.Ball

	local snout = piece("Snout", Vector3.new(0.5, 0.85, 0.85),
		CFrame.new(0, 0.9, 1.05) * CFrame.Angles(0, math.rad(90), 0), skin.trim)
	snout.Shape = Enum.PartType.Cylinder

	local tail = piece("Tail", Vector3.new(0.45, 0.45, 0.45), CFrame.new(0, 1.4, -1.1), skin.trim)
	tail.Shape = Enum.PartType.Ball

	for _, side in ipairs({ -1, 1 }) do
		piece("Ear", Vector3.new(0.26, 0.5, 0.2), CFrame.new(side * 0.45, 2.0, 0.5), skin.trim)
		piece("Eye", Vector3.new(0.16, 0.16, 0.1), CFrame.new(side * 0.36, 1.45, 1.0), NEAR_BLACK)
		for _, front in ipairs({ 0.55, -0.55 }) do
			local leg = piece("Leg", Vector3.new(0.75, 0.34, 0.34),
				CFrame.new(side * 0.5, 0.375, front) * CFrame.Angles(0, 0, math.rad(90)), skin.trim)
			leg.Shape = Enum.PartType.Cylinder
		end
	end

	-- Welds rather than anchoring: the whole model rides on the thief, so it
	-- has to move as one piece without being pinned to the world.
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") and child ~= body then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = child
			weld.Parent = child
		end
	end

	-- AFTER that loop, and it has to be. The marks live in a Folder, so the
	-- loop above -- which only walks direct BasePart children -- would never
	-- see them; they are welded one at a time by `markPart` instead, and
	-- running this first would simply have done the same work twice.
	PiggyModel.applyPattern(model, skin, {
		frame = body.CFrame,
		radius = MINI_R,
		anchored = false,
		weldTo = body,
		material = skin.material,
		-- The mini is deliberately solid where the plot piggy is translucent,
		-- so its marks are too. Reading `skin.transparency` here would fade
		-- them against a body that never faded.
		transparency = 0,
	})

	model.PrimaryPart = body
	return model
end


return PiggyModel
