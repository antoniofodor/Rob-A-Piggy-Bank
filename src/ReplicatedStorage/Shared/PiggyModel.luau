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
local LegendaryModel = require(ReplicatedStorage.Shared.LegendaryModel)
local SkinFX = require(ReplicatedStorage.Shared.SkinFX)

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

-- THE +X EYEBALL, as a unit direction off the body centre; the other is its
-- mirror in X. Only `faceGap` reads it, and only a pattern whose pole is far
-- enough forward to run bands across the face ever asks for one.
--
-- ONE DIRECTION SERVES BOTH PIGGIES, which is measured rather than hoped for:
-- the plot piggy's eye sits at (0.403, 0.360, 0.841) and the mini's at
-- (0.326, 0.272, 0.906), which are 7.8 degrees apart, and this is the
-- midpoint -- 4.6 degrees off one and 3.8 off the other. An eyeball's own
-- silhouette is about 6 degrees across, so a gap of any useful size swallows
-- that disagreement whole. A second constant per piggy would be two numbers
-- that can drift apart to answer one question.
local EYE_DIR = Vector3.new(0.365, 0.317, 0.875).Unit

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
	shape: Enum.PartType, colour: Color3, opts: PatternOpts,
	material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Shape = shape
	p.Color = colour
	-- NIL MEANS THE PATTERN'S OWN, which is what every caller but the bolts
	-- wants. A lightning segment is Neon on a body that is not.
	p.Material = material or opts.material
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
-- and the rest of that disc is then a dinner plate sitting inside the pig.
-- That used to be visible, because the body was translucent; it is opaque
-- now, so the objection is weaker than it was. The band stays segments
-- anyway: the plate would still be there to be seen through the vault hatch,
-- and a ring of segments is the right shape regardless of who can see it.
-- Take a blocked interval out of a list of ascending, disjoint sweeps, which
-- is how a band gets cut around an eye. Returns a new list rather than editing
-- in place, because one band is cut up to six times and a cut can split a
-- sweep in two: iterating a table that is being inserted into is the kind of
-- bug that only shows up on the pig that happens to have two eyes in one band.
local function cutSpan(spans: { { number } }, lo: number, hi: number): { { number } }
	local kept: { { number } } = {}
	for _, s in ipairs(spans) do
		if hi <= s[1] or lo >= s[2] then
			table.insert(kept, s)
		else
			if lo > s[1] then
				table.insert(kept, { s[1], lo })
			end
			if hi < s[2] then
				table.insert(kept, { hi, s[2] })
			end
		end
	end
	return kept
end

local function buildStripes(folder: Folder, spec: any, opts: PatternOpts)
	local R = opts.radius
	local rng = Random.new(spec.seed or 1)
	local count = math.max(1, spec.count or 5)
	local width = math.clamp(spec.width or 0.18, 0.04, 0.5) * R
	local spread = math.clamp(spec.spread or 0.62, 0.1, 0.85)
	local arc = math.rad(math.clamp(spec.arc or 195, 40, 350))
	local wobble = math.clamp(spec.wobble or 0, 0, 1)
	-- How much narrower a band is at the ENDS of its arc than at its crest.
	-- Real stripes come to a point as they run under an animal; a band of one
	-- width the whole way round reads as a hoop rather than as a marking.
	local taper = math.clamp(spec.taper or 0, 0, 0.9)
	-- How much room to leave round each eyeball, in degrees. Zero for every
	-- pattern whose pole is far enough back that no band crosses the face --
	-- which is every one of them except the zebra -- and zero is the old
	-- behaviour to the byte.
	local faceGap = math.rad(math.clamp(spec.faceGap or 0, 0, 60))
	local colour = spec.colour or Color3.new(0, 0, 0)

	-- THE POLE THE BANDS GIRDLE, AND IT IS WHAT DECIDES WHICH ANIMAL THIS IS.
	-- It was hardcoded to the spine for as long as the only customers were a
	-- bee and a barcode. `+Z` is still the default, so every skin written
	-- before the zebra is untouched: at +Z the basis below comes out exactly
	-- (X, Y, Z) and every number downstream is the one it always was --
	-- checked against the bee, 32 segments before and 32 after, the same four
	-- rings at the same steps.
	--
	-- A BAND IS A CIRCLE OF CONSTANT ANGLE FROM THE POLE, so pointing the pole
	-- at the MUZZLE turns one family of bands into a zebra by itself: a ring
	-- on the FACE near the pole, a near-vertical stripe down the FLANK at
	-- ninety degrees, and a ring closing on the TAIL beyond it. The stripes
	-- radiate out of the face, run down the sides and converge at the rump,
	-- which is the whole of what a zebra's markings do.
	--
	-- NO AMOUNT OF TUNING A SPINE-GIRDLING BAND GETS THERE, which is why this
	-- is a new axis rather than new numbers. Measured on the shipped zebra:
	-- the nearest band sat 54 degrees off the snout, so there was nothing on
	-- the face at all, and the lowest one stopped 4.6 degrees ABOVE the
	-- equator -- a cap of bars pulled down over the head rather than a striped
	-- animal. On the muzzle pole the same nine bands wrap the snout at 32
	-- degrees and reach 22 below the equator.
	local pole: Vector3 = if typeof(spec.axis) == "Vector3" and spec.axis.Magnitude > 1e-4
		then spec.axis.Unit
		else Vector3.zAxis
	-- THE REST OF THE FRAME IS DERIVED, so a spec only ever says which way the
	-- animal is striped. `crest` is whichever way is UP once the pole is taken
	-- out of it, and it is the direction every band's arc is CENTRED on -- so
	-- an arc short of a full ring covers the back and both flanks and leaves
	-- the belly bare, at any pole, with nothing to re-derive. `flank`
	-- completes the frame. A pole that is itself vertical has no up left to
	-- project, so the reference swings to the spine: nothing ships that way,
	-- and it is one line against a divide by zero rather than a feature.
	local upRef = if math.abs(pole.Y) > 0.99 then Vector3.zAxis else Vector3.yAxis
	local crest = (upRef - pole * pole:Dot(upRef)).Unit
	local flank = crest:Cross(pole)

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
		-- How far along the pole this band sits. The clamp keeps a band off
		-- the poles themselves, where the ring shrinks to nothing -- and on a
		-- muzzle pole it is also what holds the forward-most band clear of the
		-- snout, which subtends 16.4 degrees and meets a band at 31.8.
		local h = t * spread * R + rng:NextNumber(-1, 1) * wobble * spread * R / (count * 2)
		h = math.clamp(h, -0.85 * R, 0.85 * R)

		local ring = math.sqrt(math.max(R * R - h * h, 0))
		if ring > 0.2 * R then
			local bandW = width * (1 + rng:NextNumber(-1, 1) * wobble * 0.45)

			-- THE ARC IS CUT AROUND THE EYES RATHER THAN DRAWN THROUGH THEM,
			-- and dropping whole segments was the version that did not work.
			-- A segment spans up to 26 degrees of its own ring, so skipping
			-- the one either side of an eye opens a 65-degree hole in the
			-- middle of a face about 100 degrees across: the pattern would
			-- have read as a bandage rather than as markings.
			--
			-- Solved instead, and it is one acos per eye per band. A point on
			-- this band is within `faceGap` of an eye exactly while
			-- amp * cos(phi - mid) >= (R cos gap - (eye . pole) * h) / ring,
			-- so the blocked sweep comes out in closed form and the stripe
			-- ENDS on the edge of the gap -- which is what a real zebra's face
			-- does anyway: the stripes stop at the eye and pick up past it.
			local spans = { { math.pi / 2 - arc / 2, math.pi / 2 + arc / 2 } }
			if faceGap > 0 then
				for _, side in ipairs({ 1, -1 }) do
					local eye = Vector3.new(EYE_DIR.X * side, EYE_DIR.Y, EYE_DIR.Z)
					local amp = math.sqrt(eye:Dot(crest) ^ 2 + eye:Dot(flank) ^ 2)
					if amp > 1e-4 then
						local k = (math.cos(faceGap) * R - eye:Dot(pole) * h) / (ring * amp)
						if k < 1 then
							local half = math.acos(math.max(k, -1))
							local mid = math.atan2(eye:Dot(crest), eye:Dot(flank))
							-- Three turns, because the arc runs from about -60
							-- to 300 degrees while atan2 answers in -180..180:
							-- one eye can block the same band from either end.
							for turn = -1, 1 do
								local centre = mid + turn * 2 * math.pi
								spans = cutSpan(spans, centre - half, centre + half)
							end
						end
					end
				end
			end

			-- A CUT BAND MAY LEAVE A STUB, and the three-segment floor is
			-- wrong for one -- it would draw a two-stud stump as three plates
			-- overlapping each other. The floor stands for a band nobody cut,
			-- where it has never actually bound: measured across all nine
			-- shipped stripe specs, the shortest ring any of them produces
			-- still asks for five segments.
			local floor = if #spans > 1 then 1 else 3

			for _, span in ipairs(spans) do
				local sweep = span[2] - span[1]
				-- Anything shorter than a third of a segment is a fleck rather
				-- than a stripe end, and a fleck beside an eye reads as dirt.
				if ring * sweep >= 0.30 * maxSeg then
					local segs = math.max(floor, math.ceil((ring * sweep) / maxSeg))
					local step = sweep / segs
					-- Overlapped rather than butted, so a band reads as one
					-- mark and not as a dashed line: the join is exactly where
					-- the eye goes looking for a seam.
					local segLen = ring * step * 1.22

					for s = 1, segs do
						local phi = span[1] + (s - 0.5) * step
						-- Measured from the WHOLE arc's crest and never from
						-- the stub's own middle, or a band cut in two by an
						-- eye would taper twice and read as two separate marks
						-- that happen to line up.
						local k = math.min(1, math.abs(phi - math.pi / 2) / (arc / 2))
						local w = bandW * (1 - taper * k * k)
						-- EXACTLY AS THICK AS IT HAS TO BE, WHICH IS WHAT STOPS
						-- A BAND READING AS PLATES BOLTED ON. A segment only
						-- has to keep its INNER face buried where the sphere
						-- falls away under its own corners; every stud past
						-- that is visible edge standing over the neighbouring
						-- segment. It was a flat 0.16R -- 0.96 studs at R=6
						-- against a requirement of 0.37 -- and photographed as
						-- a wall of shingles. Solved from the corner rather
						-- than chosen, and solved PER SEGMENT now, because a
						-- tapered band is not one width any more.
						local reach = math.sqrt((segLen / 2) ^ 2 + (w / 2) ^ 2)
						local thick = lift + (R - math.sqrt(math.max(R * R - reach * reach, 0))) + 0.03 * R

						-- Local Y is the radius, so the outer face lands
						-- exactly LIFT proud of the sphere at the segment's
						-- midpoint.
						local n = (pole * h + flank * (ring * math.cos(phi))
							+ crest * (ring * math.sin(phi))).Unit
						local tangent = crest * math.cos(phi) - flank * math.sin(phi)
						local seat = n * (R + lift - thick / 2)
						markPart(folder, "Stripe", Vector3.new(segLen, thick, w),
							opts.frame * CFrame.fromMatrix(seat, tangent, n),
							Enum.PartType.Block, colour, opts)
					end
				end
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
-- -- eight and a half studs of sphere sitting inside the pig, which was
-- visible while the body was translucent and is still the wrong solid. A
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

-- A WedgePart laid on the body, and the only reason this is a second builder
-- rather than an argument to `markPart` is that a wedge is a different CLASS.
-- `Part.Shape` runs to Ball, Cylinder and Block and no further, so there is no
-- flag to add: the instance itself has to change. Everything below the class
-- is the same contract -- never body-block, never answer a query, never throw
-- a shadow -- so it is copied deliberately rather than shared, because the two
-- lists diverging is a marking that can be raycast and nothing saying so.
--
-- THE MATERIAL IS AN ARGUMENT HERE AND NOT IN `markPart`, because this is the
-- first mark whose parts do not all agree about what they are made of: a rock
-- shard and the bolt arcing off it are one shape in two materials. Nil means
-- the pattern's own, which is what every existing caller wants.
local function markWedge(folder: Folder, name: string, size: Vector3, cf: CFrame,
	colour: Color3, opts: PatternOpts, material: Enum.Material?): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or opts.material
	p.Transparency = opts.transparency
	p.Anchored = opts.anchored
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Massless = true
	p.Parent = folder

	if opts.weldTo then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = opts.weldTo
		weld.Part1 = p
		weld.Parent = p
	end
	return p
end

-- A BOLT OF LIGHTNING, AND IT IS A CHAIN OF SEGMENTS RATHER THAN ONE SPIKE.
--
-- **THE FIRST TWO BUILDS DREW STRAIGHT LINES, AND THAT IS NOT WHAT LIGHTNING
-- IS.** Both reused the shard's own wedge in a different colour: the first at
-- the shards' proportions, which read as cyan SLABS, and the second long and
-- thin, which read as SPEARS. Both are one straight piece. A bolt is defined
-- by its KINKS -- it is a jointed polyline whose direction changes sharply and
-- alternately -- and a shape with no joints in it cannot be made into one by
-- any amount of tuning its length, its width or its colour.
--
-- That is the same finding one level up from Storm Wolf's own header, where a
-- warped-noise contour lost to a Voronoi net for drawing the baked forks:
-- branching and kinking are not decorations on lightning, they ARE lightning,
-- and no smooth primitive acquires them by being made thinner.
--
-- THE ZIGZAG IS PLANAR, AND THE PLANE IS PICKED ONCE PER BOLT. A polyline that
-- kinks in three dimensions reads as crumpled wire; the drawn lightning
-- everybody recognises is FLAT. So each segment is a thin ribbon lying in one
-- plane, and the plane is turned at random per BOLT rather than per joint --
-- which is also what stops eight of them reading as one motif stamped eight
-- times.
--
-- THE ANGLE ALTERNATES RATHER THAN WANDERING. `sign` flips every segment, so
-- the run oscillates ABOUT its own outward direction instead of curving away
-- from it. A bolt that always kinked the same way is an arc, which is the one
-- thing this had to stop being.
--
-- THE FIRST SEGMENT'S LENGTH IS SOLVED FROM THE TOTAL RATHER THAN TYPED. A
-- geometric run summing to `boltLen` means turning the segment COUNT changes
-- how jagged a bolt is and never how far it reaches -- which is the one
-- coupling that would otherwise make every other dial here lie.
local function boltChain(folder: Folder, spec: any, opts: PatternOpts,
	rng: Random, n: Vector3, R: number, colour: Color3,
	material: Enum.Material)
	local segs = math.clamp(math.floor(spec.boltSegs or 4), 2, 8)
	local total = math.clamp(spec.boltLen or 0.55, 0.10, 1.20) * R
	local kink = math.rad(math.clamp(spec.boltKink or 34, 0, 80))
	local wide = math.clamp(spec.boltWide or 0.075, 0.01, 0.40) * R
	local thin = math.clamp(spec.boltThin or 0.35, 0.05, 1.0)
	local taper = math.clamp(spec.boltTaper or 0.78, 0.30, 1.0)
	local rake = math.rad(math.clamp(spec.boltRake or 14, -60, 60))

	-- Outward, raked a little toward the tail so a bolt agrees with the crest
	-- it grows out of rather than standing square to it.
	local tail = Vector3.new(0, 0, -1)
	local along = tail - n * n:Dot(tail)
	if along.Magnitude < 1e-3 then
		along = Vector3.yAxis - n * n:Dot(Vector3.yAxis)
	end
	along = along.Unit
	local d0 = (n * math.cos(rake) + along * math.sin(rake)).Unit

	-- THE PLANE'S NORMAL, WHICH MUST BE PERPENDICULAR TO `d0` or the kinks
	-- stop being a zigzag and become a corkscrew. `along` and `n` are already
	-- perpendicular to each other and `d0` lies in their span, so their cross
	-- product is perpendicular to it by construction rather than by luck.
	local axis = along:Cross(n)
	if axis.Magnitude < 1e-3 then
		axis = Vector3.xAxis
	end
	axis = CFrame.fromAxisAngle(d0, rng:NextNumber(-1, 1) * math.pi)
		:VectorToWorldSpace(axis.Unit).Unit

	-- Seated a little INSIDE the surface, so a bolt grows out of the hide
	-- rather than starting on it with daylight under its first segment.
	local at = n * (R - wide)
	local len = if taper >= 0.999
		then total / segs
		else total * (1 - taper) / (1 - taper ^ segs)
	local w = wide

	for i = 1, segs do
		local sign = if i % 2 == 1 then 1 else -1
		local d = CFrame.fromAxisAngle(axis, kink * sign)
			:VectorToWorldSpace(d0).Unit
		-- Local Y runs along the segment and local Z is the plane's normal,
		-- so `Size` reads (across the plane, along the run, through the
		-- ribbon) and the segment lies flat in the plane it was solved in.
		local yl = d
		local zl = axis
		local xl = yl:Cross(zl)
		markPart(folder, "Bolt", Vector3.new(w, len, w * thin),
			opts.frame * CFrame.fromMatrix(at + d * (len / 2), xl, yl),
			Enum.PartType.Block, colour, opts, material)
		at = at + d * len
		len = len * taper
		w = w * taper
	end
end

-- Angular plates standing proud of the back: a storm-charged rock hide, and
-- the first pattern kind that changes the SILHOUETTE rather than the colour.
-- Every other mark in this file is paint -- a band, a disc, a lump -- and can
-- be judged on a flat render. This one is read from the side.
--
-- A WEDGE, BECAUSE IT IS THE ONLY TAPERING SOLID THE ENGINE HANDS OUT FOR
-- FREE, and a shard that does not come to a point is a brick glued to a pig.
-- Two mirrored wedges would make a symmetric spike; ONE reads as a slate
-- fragment, which is the shape the reference actually carries and is half the
-- parts.
--
-- ITS SOLID WAS RAYCAST RATHER THAN ASSUMED -- `CLAUDE.md` records the test:
-- full height at +Z falling to nothing at -Z, extruded along X. So the frame
-- below puts the tall edge OUTWARD along the normal and the slope toward the
-- NOSE, which is a fin raked back over the animal. Reading that off the field
-- names is the mistake `legRoll` and the cylinder axis are already recorded
-- for, five times between them.
--
-- THE CREST IS PARTED, AND THAT IS THE HAT ANCHOR RATHER THAN A STYLE CHOICE.
-- `CROWN_LIMIT` above records why a spot may not cross the crown: a brim is
-- authored 0.35 studs INSIDE this sphere, so anything standing proud up there
-- swallows something the player rolled for -- the Vault Lock padlock bug from
-- the other direction. A shard is the worst offender the catalogue has, at up
-- to a third of a radius tall, and it is also the mark that most wants to be
-- up there. `parting` is the answer `FUR_SETS.mane` already found: two rows
-- either side of the spine with the centre line left bare, so the crest reads
-- across the animal's WIDTH and a top hat still comes down between them.
--
-- The parting is enforced only ABOVE the crown limit. Down the flanks there is
-- no anchor to protect and no reason to leave a gap, so the ridge closes up as
-- it runs back over the rump -- which is what stops the whole thing reading as
-- two tidy rows.
local function buildShards(folder: Folder, spec: any, opts: PatternOpts)
	local R = opts.radius
	local rng = Random.new(spec.seed or 1)
	local count = math.max(1, spec.count or 18)
	-- HOW FAR IT STANDS OUT, as a fraction of the body radius, and it is the
	-- one number deciding whether this is a hide or a hedgehog. Clamped well
	-- under half a radius: past that the shards out-reach the ears and the
	-- animal underneath stops being a pig.
	local height = math.clamp(spec.size or 0.28, 0.06, 0.45) * R
	local vary = math.clamp(spec.vary or 0.35, 0, 0.8)
	-- ACROSS AND ALONG ARE FRACTIONS OF THE HEIGHT rather than of the radius,
	-- so a shard keeps its proportions when `size` is tuned. Thin across and
	-- deep along: a slate fragment, not a tooth.
	local thick = math.clamp(spec.thick or 0.30, 0.08, 1.0) * height
	local depth = math.clamp(spec.depth or 0.85, 0.20, 2.0) * height
	-- HOW FAR BACK IT LEANS. Zero is a spike standing on its own normal, which
	-- reads as a spine rather than as broken rock; the reference rakes every
	-- shard toward the tail together, which is what makes them look like one
	-- thing that happened to the animal instead of a row of decorations.
	local rake = math.rad(math.clamp(spec.rake or 26, -60, 60))
	-- AND HOW MUCH EACH ONE DISAGREES ABOUT IT. A crest whose plates are all
	-- coplanar is a comb. This is the whole difference between "shattered" and
	-- "moulded", and it costs nothing.
	local twist = math.rad(math.clamp(spec.twist or 22, 0, 80))
	local colour = spec.colour or Color3.new(0, 0, 0)

	-- THE BAND THEY OCCUPY, in the body's own units: `lo` down the flank and
	-- `hi` over the crown. The default stops well short of the belly, because
	-- a shard under a pig is a shard nobody will ever see and one more part on
	-- every piggy on the street.
	local lo = math.clamp(spec.lo or 0.10, -0.9, 0.9)
	local hi = math.clamp(spec.hi or 0.97, lo + 0.05, 1.0)
	-- Half-width of the bare centre line above `CROWN_LIMIT`. See above.
	local parting = math.clamp(spec.parting or 0.26, 0, 0.8)
	-- Nothing forward of this, on the same +Z-is-the-nose axis `FACE_LIMIT`
	-- uses. The eyeballs sit at Z 0.875 and already stand 0.45 studs proud, so
	-- a shard level with them is a shard growing out of a face.
	--
	-- BUT THE CAP IS A CHEEK RULE, NOT A FORWARD RULE, and the first build had
	-- it as the latter. Rejecting everything forward of `faceStop` at every
	-- latitude pushed the whole crest BEHIND the ears -- a ridge down the back
	-- of an otherwise ordinary pig, where the thing being copied crowns the
	-- BROW. `buildSpots` already had the right shape and it is one clause:
	-- the cap applies only BELOW `faceHigh`, so shards may come forward over
	-- the forehead and still never reach a cheek, a nostril or the snout.
	local faceStop = math.clamp(spec.faceStop or 0.45, -1, 1)
	local faceHigh = math.clamp(spec.faceHigh or 0.55, -1, 1)

	-- THE GLOWING ONES ARE THE SAME GEOMETRY IN A DIFFERENT MATERIAL, which is
	-- the whole reason this is one kind rather than two. `applyPattern`
	-- already lets a spec overrule the skin's material, and a Neon shard is
	-- REAL emission: it reaches the BloomEffect and halos, where the body's own
	-- baked coat measurably cannot -- a surface pack has no emissive channel
	-- and `Config.skinSurface` refuses Neon alongside one. So the light in a
	-- skin like this comes off the SILHOUETTE rather than out of the hide.
	local glowEvery = math.max(0, math.floor(spec.glowEvery or 0))
	local glowColour = spec.glowColour or colour
	local glowMaterial = spec.glowMaterial or Enum.Material.Neon
	-- HOW A BOLT IS SHAPED IS `boltChain`'S BUSINESS, not this loop's -- see
	-- the block above it. Every dial it reads is a `bolt*` key on this same
	-- spec, so a skin still says everything it wants in one table.

	-- COUNT IS HONEST, AND THE FIRST DRAFT DID NOT MANAGE IT. Sweeping the
	-- sphere and rejecting the face and the parting threw away better than a
	-- third of every count -- the exact failure `buildSpots` records for the
	-- crown, where a ladybird asking for 11 spots placed 7. The region here is
	-- not a latitude range, so it cannot be solved out the way that one was:
	-- it keeps DRAWING until it has placed what was asked for, with a cap so a
	-- spec that excludes everything cannot spin.
	local placed, attempt = 0, 0
	while placed < count and attempt < count * 10 do
		attempt += 1
		-- A golden-angle spiral over the band, the distribution the spots and
		-- the coin pile already use, jittered so it does not read as printed.
		local t = (attempt - 0.5) / count
		local y = math.clamp(hi - (t % 1) * (hi - lo) + rng:NextNumber(-1, 1) * 0.06, lo, hi)
		local ringF = math.sqrt(math.max(1 - y * y, 0))
		local theta = attempt * GOLDEN_ANGLE + rng:NextNumber(-1, 1) * 0.30
		local dir = Vector3.new(ringF * math.cos(theta), y, ringF * math.sin(theta))
		if dir.Magnitude > 1e-4 then
			local n = dir.Unit
			local inFace = n.Z > faceStop and n.Y < faceHigh
			local inParting = n.Y > CROWN_LIMIT and math.abs(n.X) < parting
			if not inFace and not inParting then
				placed += 1
				-- A LIT DRAW IS A DIFFERENT OBJECT AND NOT A RESIZED ONE, so
				-- it branches here rather than scaling the wedge below. Both
				-- come off the SAME spiral, which is what keeps the bolts
				-- spread through the crest rather than needing a second
				-- distribution that could disagree with this one about where
				-- the face and the parting are.
				if glowEvery > 0 and placed % glowEvery == 0 then
					boltChain(folder, spec, opts, rng, n, R,
						glowColour, glowMaterial)
					continue
				end
				local h = height * (1 + rng:NextNumber(-1, 1) * vary)
				local d = depth * (1 + rng:NextNumber(-1, 1) * vary * 0.6)
				local w = thick * (1 + rng:NextNumber(-1, 1) * vary * 0.6)

				-- THE FRAME IS DERIVED FROM THE NORMAL AND THE TAIL, never
				-- written out, so a shard is seated correctly wherever the
				-- spiral drops it. Local Y is the outward normal and local Z
				-- is tailward and tangent, so the wedge's tall +Z face lands
				-- at the BACK of the shard and its slope runs down toward the
				-- nose. Dead on the rump the tail direction has no tangent
				-- left, so the reference swings to up -- one line against a
				-- divide by zero rather than a case anybody ships.
				local tail = Vector3.new(0, 0, -1)
				local along = tail - n * n:Dot(tail)
				if along.Magnitude < 1e-3 then
					along = Vector3.yAxis - n * n:Dot(Vector3.yAxis)
				end
				local zl = along.Unit
				local yl = n
				local xl = yl:Cross(zl)

				local lean = rake * (1 + rng:NextNumber(-1, 1) * 0.35)
				local spin = rng:NextNumber(-1, 1) * twist
				local rot = CFrame.fromMatrix(Vector3.zero, xl, yl)
					* CFrame.Angles(lean, spin, 0)

				-- HOW DEEP THE BASE IS BURIED IS SOLVED, NOT PICKED, and it is
				-- the arithmetic `buildSpots` already does for a disc: a flat
				-- base of half-diagonal `a` on a sphere of radius R leaves its
				-- CORNERS a*a/(2R) outside the surface before any tilt at all,
				-- and the rake then lifts the leading edge by another
				-- (d/2)*sin(lean). Sink by both and the shard grows out of the
				-- hide; sink by neither and it is a plate resting on it with
				-- daylight under one corner, which is the sticker failure this
				-- project has already paid for twice.
				local halfDiag = math.sqrt(w * w + d * d) / 2
				local sink = halfDiag * halfDiag / (2 * R)
					+ math.abs(math.sin(lean)) * d / 2
					+ LIFT * R
				local base = n * (R - sink)
				local cf = opts.frame
					* (CFrame.new(base + rot.UpVector * (h / 2)) * rot)

				markWedge(folder, "Shard", Vector3.new(w, h, d), cf,
					colour, opts)
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
	elseif spec.kind == "shards" then
		buildShards(folder, spec, resolved)
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

-- ---- the same pig, at preview size ----------------------------------------
--
-- THE MINI WAS THE OLD BALL PIG LONG AFTER THE LAWN PIG STOPPED BEING ONE.
-- `PiggyBank.swapToMesh` put the modelled body on every plot; everything
-- else that draws a piggy -- the victim shelf on a lawn, the inventory's
-- collection log, the crate reel, the shop window, the loot a thief carries
-- home -- went on building eleven primitives. So the game showed two
-- different animals for the same skin depending on which one you were
-- looking at.
--
-- ONE FUNCTION FIXES ALL OF THEM, which is the whole reason this is here
-- rather than in each caller: every one of those surfaces goes through
-- `PiggyModel.build`.
--
-- PREWARMED AND CLONED, NEVER BUILT ON DEMAND. `CreateMeshPartAsync` YIELDS,
-- and `build` is called from inside render loops and from `iconFor`'s pcall
-- -- yielding there would stall a repaint or swallow the model. The template
-- is made once and cloned, which is the call `House`, `GrassTuft` and
-- `PiggyBank` all already make for the same reason.
--
-- AND IT FALLS BACK RATHER THAN FAILING. No ids, a dead asset, a client that
-- has not prewarmed yet: `build` hands back the primitives pig, which is a
-- pig that looks old rather than no pig at all -- the same call
-- `Config.piggyMesh` makes when an id is blank.
local meshTemplate: Model? = nil
local meshTried = false
-- Where a skin's pattern goes on the SCALED template, solved once at prewarm
-- so `build` does not redo it per card.
local meshPatternAt = Vector3.zero
local meshPatternR = 1

--[[
	Build the mesh pig once, sized to sit exactly where the primitives mini
	sat. Safe to call repeatedly and from both ends; the second call is free.

	THE FOOTPRINT IS MEASURED FROM THE PRIMITIVES PIG RATHER THAN TYPED, and
	that is what keeps every existing seat valid. A thief's hands are posed
	against a 2.2-stud pig (`CarryPose.HOLD` was solved on it), the victim
	shelf spaces its columns for one, and `makeModelIcon` frames whatever it
	is given. Matching the old bounding box means not one of those had to be
	re-derived -- and if the primitives pig is ever resized, this follows it.
]]
function PiggyModel.prewarm(): boolean
	if meshTried then
		return meshTemplate ~= nil
	end
	meshTried = true

	local spec = Config.piggyMesh()
	if not spec then
		return false
	end

	local face = Config.PIGGY_MESH_FACE
	local ok, made: any = pcall(function()
		local insert = game:GetService("InsertService")
		local m = Instance.new("Model")
		for _, entry in ipairs(spec) do
			-- Box collision and Precise render, the same pair the lawn pig
			-- takes: nothing queries a preview, and a shed triangle shows on
			-- a card read at arm's length.
			local p = insert:CreateMeshPartAsync(entry.id,
				Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
			p.Name = entry.part
			-- SIZE BEFORE CFRAME. Resizing a MeshPart scales it about its own
			-- centre, so a part seated first and sized second ends up seated
			-- for the size it used to be.
			p.Size = entry.size
			p.CFrame = CFrame.new(entry.offset) * (entry.rot or CFrame.identity)
			-- WHICH TONE IT TAKES, carried on the part rather than re-derived
			-- from its name. `Config.piggyMesh` already answers this and the
			-- answer changes when the trim splits into four separate meshes.
			p:SetAttribute("Trim", entry.trim == true)
			p.Parent = m
		end

		-- THE MESH CARRIES NO EYES. The modelled body has eye patches in a
		-- second material and the importer merged that material away, so the
		-- lawn pig seats primitive eyeballs on top -- and the mini has to do
		-- the same or every preview is a blank-faced pig. Same seat, from the
		-- same table, so the two cannot disagree.
		for _, side in ipairs({ -1, 1 }) do
			local e = Instance.new("Part")
			e.Name = "Eye"
			e.Shape = Enum.PartType.Ball
			e.Size = Vector3.new(face.eyeSize, face.eyeSize, face.eyeSize)
			e.CFrame = CFrame.new(side * face.eye.x, face.eye.y, face.eye.z)
			e.TopSurface = Enum.SurfaceType.Smooth
			e.BottomSurface = Enum.SurfaceType.Smooth
			e.Parent = m
		end
		return m
	end)

	if not ok or not made then
		-- NEVER FAIL SILENTLY, the same rule the lawn pig's swap follows: a
		-- preview that quietly stayed on primitives after somebody pasted an
		-- id is indistinguishable from an id that did not take.
		warn(("[PiggyModel] the preview pig mesh could not be loaded, so the "
			.. "primitives mini is standing instead: %s"):format(tostring(made)))
		return false
	end

	-- Measure the pig this replaces, and match it.
	local probe = PiggyModel.build(Config.DEFAULT_SKIN)
	local _, want = probe:GetBoundingBox()
	probe:Destroy()

	local atCF, size = made:GetBoundingBox()
	local longest = math.max(size.X, size.Y, size.Z)
	local target = math.max(want.X, want.Y, want.Z)
	local scale = if longest > 0 then target / longest else 1
	local centre = atCF.Position

	for _, d in ipairs(made:GetDescendants()) do
		if d:IsA("BasePart") then
			local rot = d.CFrame - d.CFrame.Position
			d.Size = d.Size * scale
			d.CFrame = CFrame.new(centre + (d.CFrame.Position - centre) * scale) * rot
		end
	end
	-- Sit it where the primitives pig sat, so a caller that positions the
	-- model by its pivot puts it in the same place it always did.
	local after = made:GetBoundingBox()
	made:PivotTo(made:GetPivot() + (MINI_CENTRE - after.Position))

	meshPatternAt = centre + (face.patternCentre - centre) * scale
		+ (MINI_CENTRE - after.Position)
	meshPatternR = face.patternRadius * scale

	-- THE LEGENDARIES LOAD HERE TOO, AND THIS WAITS FOR THEM, because every
	-- caller of `prewarm` rebuilds its icons the moment it returns and a
	-- card built before a legendary's meshes land keeps the swatch pig for
	-- the session. Loaded in parallel, so the wait is the slowest mesh.
	local pending = 0
	for key in pairs(Config.LEGENDARIES) do
		pending += 1
		task.spawn(function()
			LegendaryModel.load(key)
			pending -= 1
		end)
	end
	local waited = 0
	while pending > 0 and waited < 30 do
		waited += task.wait(0.1)
	end

	meshTemplate = made
	return true
end

function PiggyModel.build(skinKey: string): Model
	local skin = Config.getSkin(skinKey)

	-- THE MESH PIG WHEN THERE IS ONE. Everything below this branch is the
	-- primitives pig, kept as the fallback rather than deleted -- see the
	-- prewarm above for why it stays.
	local template = meshTemplate
	if template then
		local mesh = template:Clone()
		mesh.Name = Config.LOOT_MODEL_NAME
		local body: BasePart? = nil
		for _, d in ipairs(mesh:GetChildren()) do
			if d:IsA("BasePart") then
				-- THE MINI'S OWN CONVENTIONS, and they are the opposite of the
				-- lawn pig's. This one gets welded to a running thief, and an
				-- anchored part welded to a humanoid PINS the humanoid -- the
				-- rule `RideModel` and `PiggyModel` already share and that
				-- `ShopFront` and the victim shelf invert on purpose by
				-- anchoring whatever they are handed.
				d.Anchored = false
				d.CanCollide = false
				d.CanQuery = false
				d.Massless = true
				d.CastShadow = false
				if d.Name == "Eye" then
					d.Color = NEAR_BLACK
					d.Material = Enum.Material.SmoothPlastic
				elseif d:GetAttribute("Trim") == true then
					d.Color = skin.trim
					d.Material = skin.trimMaterial or skin.material
				else
					d.Color = skin.body
					d.Material = skin.material
					body = d
				end
			end
		end

		if body then
			for _, child in ipairs(mesh:GetChildren()) do
				if child:IsA("BasePart") and child ~= body then
					local weld = Instance.new("WeldConstraint")
					weld.Part0 = body
					weld.Part1 = child
					weld.Parent = child
				end
			end

			-- THE SAME SPHERE THE LAWN PIG PLACES MARKS ON, scaled. A pattern
			-- is positioned BY DIRECTION, so a mini that used its own body
			-- centre would put a zebra's bands somewhere else on the same
			-- skin -- which is the one way two pigs of one skin can visibly
			-- disagree. See `Config.PIGGY_MESH_FACE.patternCentre`.
			PiggyModel.applyPattern(mesh, skin, {
				frame = CFrame.new(meshPatternAt),
				radius = meshPatternR,
				anchored = false,
				weldTo = body,
				material = skin.material,
				transparency = 0,
			})
			-- The skin's shape geometry, welded and still: see `Shared/SkinFX`.
			SkinFX.apply(mesh, body, skinKey, false)
			-- See the note above `PiggyModel.bodyOf`: an identity-rotation
			-- pivot at the seat the primitives pig uses, and no PrimaryPart.
			-- A LEGENDARY STANDS OVER THE MINI exactly as it does over the plot's
			-- pig, welded rather than anchored because this one is carried.
			if Config.legendary(skinKey) then
				local hide: { BasePart } = {}
				for _, child in ipairs(mesh:GetDescendants()) do
					if child:IsA("BasePart") then
						table.insert(hide, child)
					end
				end
				LegendaryModel.dress(mesh, body, skinKey, { anchored = false, hide = hide })
			end
			mesh.WorldPivot = CFrame.new(MINI_CENTRE)
			return mesh
		end
		-- No body part in the template is not a state worth guessing at, so
		-- it falls through to the primitives pig rather than returning a
		-- model nothing can position.
		mesh:Destroy()
	end

	local model = Instance.new("Model")
	-- Through the constant, because a client now WATCHES for this name to
	-- decide whether to pose its owner as carrying. See Config.LOOT_MODEL_NAME.
	model.Name = Config.LOOT_MODEL_NAME

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
		-- Solid, like the plot piggy now is. This one carries no pile at all,
		-- so it never had a reason to be anything else.
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
		-- Pinned to 0 rather than read from `skin.transparency`. Every skin
		-- is opaque today, so the two agree -- but the day one is not, a mark
		-- read from the skin would fade against a mini body that never fades.
		transparency = 0,
	})

	-- The same contract the mesh branch above presents, and stated rather than
	-- inherited: this body happens to be unrotated, so a PrimaryPart here
	-- would be harmless today and would be the difference between the two
	-- branches tomorrow.
	model.WorldPivot = CFrame.new(MINI_CENTRE)
	return model
end

-- WHY THIS MODEL HAS NO PRIMARYPART, WHICH IS THE WHOLE OF WHY IT USED TO
-- FACE BACKWARDS.
--
-- `Model:PivotTo` aims the PRIMARYPART when there is one, and it SETS that
-- part's CFrame outright -- rotation included. The mesh body is the one part
-- here that has to carry a rotation: the importer mirrors Z, so
-- `Config.PIGGY_MESH` turns every mesh a half turn to put the snout back at
-- +Z and the vault at -Z. Making that same part the pivot meant the first
-- `PivotTo` REPLACED the half turn with whatever the caller passed, and the
-- correction was gone -- eyes in the rump, dial on the face.
--
-- IT HIT EVERY CONSUMER AT ONCE, because they all pivot: `makeModelIcon`
-- (every crate and skin tile), `HeistService.attachLoot` and `handCarryTo`
-- (the pig a thief carries), `ResidentService` (a neighbour's mini) and
-- `Decor` (the victim shelf). The primitives pig below was immune, because
-- its body is a Ball with no rotation -- which is exactly why this appeared
-- when the mesh ids landed and why the LAWN pig was never affected: that one
-- is placed part by part and never pivoted.
--
-- THIS PROJECT HAS PAID FOR IT ONCE ALREADY, on the alien saucer: "a
-- PrimaryPart that is itself rotated loses its rotation on the first
-- PivotTo... No PrimaryPart and an explicit identity WorldPivot at the centre
-- moves everything rigidly and every relative rotation survives." Same fix.
--
-- `makeModelIcon` was ALREADY DOING THE RIGHT THING and being ignored -- it
-- sets `model.WorldPivot = CFrame.new()` before it pivots, and WorldPivot is
-- not consulted while a PrimaryPart exists.
--
-- BOTH BRANCHES DROP IT, not just the mesh one. The primitives pig does not
-- need the fix and would present a different contract without it, and two
-- branches of one builder disagreeing about how they are positioned is how
-- this comes back the next time a mesh id is empty.
--
-- What still needs the body part is the WELDING and the loot label, so
-- `PiggyModel.bodyOf` is how a caller asks for it.
function PiggyModel.bodyOf(model: Model): BasePart?
	-- PrimaryPart FIRST, because the acorn basket is built elsewhere, does set
	-- one, and goes through the same carry code. Then the name, which is
	-- "Body" on both of this file's branches -- and is unique within a mini,
	-- unlike the castle's four `Finial`s or the wheelie bin's pair of `Lid`s.
	local part = model.PrimaryPart or model:FindFirstChild("Body")
	return if part and part:IsA("BasePart") then part else nil
end


return PiggyModel
