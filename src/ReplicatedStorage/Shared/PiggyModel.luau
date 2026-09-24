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

-- HOW HIGH THE PIVOT SITS ABOVE THE MODEL'S OWN ORIGIN, exported because a
-- caller standing one of these on a surface needs exactly this number and has
-- no other way to get it.
--
-- `build` sets `WorldPivot = MINI_CENTRE` -- the BODY CENTRE, not the feet --
-- and the mesh path re-seats the whole model against that same point, so a
-- `PivotTo` places the middle of the animal rather than the bottom of it.
-- Anything seating a mini on a plinth therefore has to lift by this, and a
-- caller that guessed 1.1 off `MINI_R` would bury it by 0.05 studs: close
-- enough to look deliberate, which is the worst kind of wrong.
PiggyModel.MINI_CENTRE_Y = MINI_CENTRE.Y

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
	-- Where the REAL surface is along a direction from `frame`, in studs, or
	-- nil to trust `radius`. See `PiggyModel.surfaceSampler`.
	surface: ((Vector3) -> number)?,
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
-- ---- seating marks on the REAL body ---------------------------------------
--
-- A PATTERN IS PLACED ON A SPHERE AND THE MESH PIG IS NOT ONE, and until
-- 2026-09-21 every mark took the sphere's word for where the surface was.
-- Measured on a pedestal mini: body 6.03 x 5.80 x 6.43 studs, spots seated
-- 2.6 to 3.7 studs from the pattern centre against a 3.0 half-width --
-- buried on one side and floating a stud off the flank on the other, one
-- hanging beside an ear. Shards hid it by standing proud on purpose; discs
-- and bands could not, and it is the mechanism behind the retired Neon
-- pattern skins reading as "stuck ON the mesh pig" (see the note in
-- `Config.SKINS`).
--
-- THE FIX ASKS THE BODY. A raycast against the pig's own collision is
-- useless -- the body ships at Box fidelity, so a ray hits a crate -- so a
-- PROBE is made once per body size: the same mesh at
-- PreciseConvexDecomposition, invisible, parked far under the map, and
-- queried alone through an Include filter. A mark's direction is cast INWARD
-- from outside the probe (a ray that starts inside a part does not report
-- it) and the hit is the radius the sphere used to guess. Cached per mesh id
-- and size, so the till pig and the mini each cost one mesh creation per
-- peer and nothing per skin. Anything that fails hands back nil and the
-- sphere carries on: the pig looks as it did rather than losing its marks,
-- the same call `prewarm` makes when a mesh id is blank.
--
-- SHARDS DELIBERATELY DO NOT USE IT. They stand up to a third of a radius
-- proud by design, were photographed seated on the sphere, and two other
-- lanes build against that behaviour -- so `buildShards` reads `radius` as
-- it always did.
local PROBE_FOLDER = "PiggyModelProbes"
local PROBE_Y = -600
local probes: { [string]: any } = {}
local probeSlot = 0

local function probeFor(body: BasePart): any
	if not body:IsA("MeshPart") or body.MeshId == "" then
		return nil
	end
	local key = body.MeshId .. "|" .. tostring(body.Size)
	local known = probes[key]
	if known ~= nil then
		return known or nil
	end
	local ok, part = pcall(function()
		local insert = game:GetService("InsertService")
		local p = insert:CreateMeshPartAsync(body.MeshId,
			Enum.CollisionFidelity.PreciseConvexDecomposition, Enum.RenderFidelity.Automatic)
		p.Size = body.Size
		return p
	end)
	if not ok or not part then
		-- Remembered, so a dead asset costs one failed fetch rather than one
		-- per skin change.
		probes[key] = false
		return nil
	end
	part.Name = "Probe"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = false
	part.Transparency = 1
	local folder = workspace:FindFirstChild(PROBE_FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = PROBE_FOLDER
		folder.Parent = workspace
	end
	probeSlot += 1
	part.CFrame = CFrame.new(probeSlot * 100, PROBE_Y, 0)
	part.Parent = folder
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { part }
	local entry = { part = part, params = params }
	probes[key] = entry
	return entry
end

-- A function from a direction in `frame`'s space to the distance from
-- `frame`'s origin to the body's real surface along it. `radius` is the
-- sphere the pattern was authored on and is what a miss falls back to. nil
-- when there is nothing better than the sphere -- a primitives Ball body, or
-- a probe that could not be made.
function PiggyModel.surfaceSampler(body: BasePart, frame: CFrame, radius: number): ((Vector3) -> number)?
	local probe = probeFor(body)
	if not probe then
		return nil
	end
	-- The body's pose in the pattern frame is what the probe has to
	-- reproduce: the probe stands with an identity rotation, so the pattern
	-- frame in probe space is the probe's frame with that pose undone. The
	-- far row's half turn is in both `frame` and `body.CFrame` and cancels.
	local rel = frame:ToObjectSpace(body.CFrame)
	local reach = radius * 3
	return function(n: Vector3): number
		local pf = probe.part.CFrame * rel:Inverse()
		local dir = pf:VectorToWorldSpace(n.Unit)
		local outside = pf.Position + dir * reach
		local hit = workspace:Raycast(outside, -dir * reach, probe.params)
		if hit then
			return math.max((hit.Position - pf.Position):Dot(dir), radius * 0.25)
		end
		return radius
	end
end

local function radiusAt(opts: PatternOpts, n: Vector3, R: number): number
	if opts.surface then
		return opts.surface(n)
	end
	return R
end

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
						local seat = n * (radiusAt(opts, n, R) + lift - thick / 2)
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
					opts.frame * CFrame.new(n * (radiusAt(opts, n, R) - (1 - proud) * radius)),
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
					opts.frame * CFrame.fromMatrix(n * (radiusAt(opts, n, R) + lift - thick / 2), n, up),
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
		surface = opts.surface,
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

-- DECLARED ABOVE `prewarm`, WHICH READS `ensureFurTemplate` AND `furSetsInUse`.
-- The first build of this block sat below `prewarm`, so at boot both names
-- were nil globals and `task.spawn(nil)` took the server's `Main` and the
-- client's HUD down together: the twelfth forward reference this project has
-- recorded, and the first inside a `task.spawn`, where the message names the
-- caller and not the missing function.
-- ============================================================
-- THE COAT, THE FUR AND THE AURA -- ONE IMPLEMENTATION, TWO PIGS
-- ============================================================
--
-- A MINI USED TO WEAR THE SWATCH. `Config.SURFACE_PACKS`' own note records
-- that a skin's `body` and `trim` colours were "kept because the shop swatch,
-- the topiary and the mini still read them" -- true, and accepted while the
-- mini was carried loot glimpsed for a few seconds. The piggy collection put
-- six of them on plinths on every lawn, in every herd and on every shop card,
-- and a Bengal Tiger on a plinth was an orange pig with cream trim. Fifteen
-- of the nineteen animal skins were unrecognisable on the one surface the
-- collection is displayed on. Designer, 2026-09-21: "we need the minis to
-- look exactly like they were built".
--
-- SO THE COAT, THE RUFF, THE GLOWING EYES, THE PER-PART COLOURS AND THE AURA
-- ARE BUILT HERE, and `PiggyBank` calls in for the lawn pig rather than
-- keeping its own copies -- the same move `House`, `Decor` and this file's
-- own pattern builder made when the shop started rendering the real item. A
-- second near-identical `applySurface` in PiggyBank was the copy that would
-- have drifted, and the mini is now the MORE-seen of the two pigs.
--
-- WHAT A MINI STILL DOES NOT CARRY IS A LIGHT. `AuraLight` and `Glow` belong
-- to the till, where an equipped effect and the vault fill drive them; a
-- point light inside every one of sixty pedestal minis and fifty herd members
-- is a hundred and ten lamps on a street that CLAUDE.md already records
-- washing out from one.

-- What a surface pack is called once it is hanging on a part, so it can be
-- found again and taken off when the next skin does not want one.
local SURFACE_NAME = "SkinSurface"

-- The till's authored body, which every scale on a mini is measured against
-- -- the same lookup `SkinFX` makes, and for the same reason: a mini is the
-- till's mesh at a fraction, and a fur mesh or an aura authored for twelve
-- studs has to shrink by exactly that fraction.
local baseBody = (function()
	for _, entry in ipairs(Config.PIGGY_MESH) do
		if entry.part == "Body" then
			return entry
		end
	end
	return nil
end)()

-- How much smaller (or larger) this body is than the till's. 1 on the lawn
-- pig, about 0.18 on a freshly built mini, and whatever a pedestal or a herd
-- has scaled it to since -- read off the part rather than remembered, so a
-- `ScaleTo` after the build is seen by everything derived from it.
local function bodyScale(body: BasePart): number
	if baseBody and baseBody.size and baseBody.size.X > 0 then
		return body.Size.X / baseBody.size.X
	end
	return 1
end

-- Dress one part in a skin's surface pack, or strip whatever it is wearing.
--
-- MESHPARTS ONLY, which is not defensiveness. A SurfaceAppearance does
-- nothing on an ordinary Part, so on the primitives fallback pig -- the one
-- that stands up when a mesh id is missing -- attaching one would create
-- instances that silently do nothing on every piggy on the street. The pig
-- renders as a plain skin there instead, which is what the fallback is for.
--
-- `isTrim` PICKS A DIFFERENT TEMPLATE, AND IT IS NOT A REFINEMENT. The ears,
-- snout, tail and legs share the body's cylindrical unwrap, so handing them a
-- PATTERN map runs tiger bars across a snout and leopard rosettes down a leg.
-- An animal pack names a `trimTemplate` carrying the coat and no markings;
-- anything without one hands both the same template, which is what the metal
-- bands want and why this is opt-in rather than a branch on skin kind.
--
-- CLONED, NEVER BUILT, AND THAT IS A REFUSAL RATHER THAN A PREFERENCE.
-- `SurfaceAppearance.ColorMap` is plugin-gated: assembling one threw `The
-- current thread cannot write 'ColorMap' (lacking capability Plugin)` from a
-- real server and took the whole of `applySkin` with it, so every skin change
-- in the game failed. A clone copies the maps without writing them, which is
-- the same escape `MaterialVariant` had to take. And REPLACED rather than
-- patched, because the properties that would need patching are the gated
-- ones.
function PiggyModel.applySurface(part: BasePart, tier: any, isTrim: boolean?)
	-- Smooth texture alpha needs the blended queue, not opaque alpha coverage.
	-- Restore ordinary opacity when this same lawn mesh changes skins.
	if part:GetAttribute("SpectralCoat") == true and tier.spectral ~= true then
		part.Transparency = tier.transparency or 0
		part:SetAttribute("SpectralCoat", nil)
	end
	local pack = Config.skinSurface(tier)
	local worn = part:FindFirstChild(SURFACE_NAME)

	if not pack or not part:IsA("MeshPart") then
		if worn then
			worn:Destroy()
		end
		return
	end

	local template: Instance? = ReplicatedStorage:FindFirstChild("Shared")
	template = template and template:FindFirstChild("SurfacePacks")
	template = template and template:FindFirstChild(
		(isTrim and pack.trimTemplate) or pack.template)
	if not template then
		-- A MISSING TEMPLATE IS A PLAIN PIG, NEVER AN ERROR. The skin still
		-- has its colours and its `material`, so what a player sees is an
		-- ordinary skin rather than a broken one -- the same way an empty mesh
		-- id leaves the piggy on primitives instead of standing up half a
		-- model.
		if worn then
			worn:Destroy()
		end
		return
	end

	if worn then
		worn:Destroy()
	end
	local sa = template:Clone()
	sa.Name = SURFACE_NAME
	sa.Parent = part
	if tier.authoredCoat == true then part.Color = Color3.new(1, 1, 1) end
	if tier.spectral == true then
		-- Alpha now controls transparency, so keep the authored RGB untinted.
		part.Color = Color3.new(1, 1, 1)
		part.Transparency = 0.02
		part:SetAttribute("SpectralCoat", true)
	end
end

-- ------------------------------------------------------------
-- RAISED FUR
-- ------------------------------------------------------------

local FUR_NAME = "FurTufts"

-- The folder a skin's accessory geometry hangs in, and the skin it was
-- built for. A FOLDER rather than loose parts because a set is 6 to 12
-- MeshParts and the pig already carries a Body, a Trim, four legs, an aura
-- and sometimes a ruff -- and because stripping one is then a single
-- Destroy rather than a walk that has to know every part name it made.
local ACCESSORY_NAME = "SkinAccessories"
local ArcadeAnimator = require(script.Parent.ArcadeAnimator)
local SpectralFX = require(script.Parent.SpectralFX)

-- WHICH SKIN'S SET IS HANGING THERE, for the reason `FUR_SET_ATTRIBUTE`
-- exists: reusing Rockslide's plates on Quartz would be one animal's
-- geometry at another's coordinates, with nothing erroring.
local ACCESSORY_SET_ATTRIBUTE = "AccessorySet"

-- Where the SERVER parks each built set so every client can clone it.
--
-- `InsertService` IS SERVER-ONLY, AND THAT IS THE WHOLE REASON THIS
-- EXISTS. Measured, from a real client: `LoadAsset` returns
-- `InsertService cannot be used to load assets from the client`, and the
-- per-mesh fallback cannot fetch a sub-asset of a Model either. So a shop
-- card, a pedestal mini and a herd member -- all built on the client --
-- would have shown the coat and no geometry while the lawn pig wore both.
--
-- THE SERVER BUILDS ONCE AND EVERYBODY CLONES, which is the same escape
-- CLAUDE.md already records for CSG: the player-gear shells are built
-- server-side and parked in ReplicatedStorage because `UnionAsync` is
-- server-only too. Same problem, same shape, same answer.
local ACCESSORY_TEMPLATE_FOLDER = "SkinAccessoryTemplates"

-- WHICH SET A WORN TUFT CAME FROM, WRITTEN ON THE PART ITSELF.
--
-- A skin is changed INTO rather than applied to a fresh pig, so going from
-- the tiger to the zebra has to SWAP the mesh and not merely recolour it --
-- and there is nothing on a MeshPart that says which set it was cloned from.
-- Comparing `MeshId` would work and is the wrong instrument: it reads an
-- asset id back out of the engine to answer a question about this game's own
-- catalogue, so an unfilled set (id "") has no id to compare and a re-upload
-- of the same mane would read as a different set. An attribute is the fact
-- itself. Same call `SkinKey` already makes on the body.
local FUR_SET_ATTRIBUTE = "FurSet"

-- ONE TEMPLATE PER SET, CACHED SEPARATELY. `CreateMeshPartAsync` yields and
-- there are ten pigs on a street and sixty minis, so this is the same cache
-- the body and trim already keep -- it just has to be keyed, or the first set
-- loaded would be handed to every animal for the rest of the server's life.
local furTemplates: { [string]: BasePart } = {}
local accessoryTemplates: { [string]: Model } = {}
local accessoryChecked: { [string]: boolean } = {}
local furChecked: { [string]: boolean } = {}

local function ensureFurTemplate(setName: string): BasePart?
	if furChecked[setName] then
		return furTemplates[setName]
	end
	-- STAMPED BEFORE THE LOAD, NOT AFTER, so a set whose mesh fails to load is
	-- attempted once rather than on every skin change for the rest of the
	-- session -- which on a failing asset is a web call per pig per swap.
	furChecked[setName] = true
	local spec = Config.furMesh(setName)
	if not spec then
		return nil
	end
	local ok, part = pcall(function()
		-- BOX COLLISION AND NO QUERY, because this is decoration standing on
		-- the one object a thief runs at and a dog patrols around. Precise
		-- collision on 6,080 triangles of wool would cost every one of them a
		-- physics query to buy nothing.
		local p = game:GetService("InsertService"):CreateMeshPartAsync(
			spec.id, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
		-- THE MESH KEEPS ITS OWN SIZE, AND CONFIG'S IS A CHECK RATHER THAN AN
		-- INSTRUCTION. Writing `Size` here scales the mesh to whatever number
		-- happens to be in Config -- so a value measured off an older build
		-- silently SHRINKS the tufts toward their own centre and buries them
		-- in the body, which is precisely what shipped. A wrong number should
		-- be loud; this one was invisible.
		if (p.MeshSize - spec.size).Magnitude > 0.05 then
			warn(string.format(
				"[PiggyModel] Config.FUR_SETS.%s.size is stale: mesh is %.4f,"
				.. " %.4f, %.4f but Config says %.4f, %.4f, %.4f -- re-run"
				.. " make_fur_tufts.py with FUR_SET=%s and paste the block it"
				.. " prints.",
				setName, p.MeshSize.X, p.MeshSize.Y, p.MeshSize.Z,
				spec.size.X, spec.size.Y, spec.size.Z, setName))
		end
		p.Name = FUR_NAME
		p:SetAttribute(FUR_SET_ATTRIBUTE, setName)
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		return p
	end)
	if not ok then
		-- NEVER FAIL SILENTLY, and never take the skin down with it. A pig
		-- with no ruff is a cosmetic fault; a build throwing is every skin
		-- change in the game failing, which is what the surface pack
		-- already cost once.
		warn(string.format("[PiggyModel] fur mesh for set %q failed to load: %s",
			setName, tostring(part)))
		return nil
	end
	furTemplates[setName] = part
	return part
end

-- The fur sets any skin in the catalogue asks for, so `prewarm` can load
-- them up front and `applyFur` never yields inside a build -- which matters
-- because `build` runs inside a pedestal dress on the economy tick and inside
-- a shop card on the client, and a web call in either is a stall.
local function furSetsInUse(): { string }
	local seen: { [string]: boolean } = {}
	local names: { string } = {}
	for _, skin in pairs(Config.SKINS) do
		local s = skin :: any
		if s.fur ~= nil then
			local setName = s.furSet or Config.DEFAULT_FUR_SET
			if not seen[setName] then
				seen[setName] = true
				table.insert(names, setName)
			end
		end
	end
	table.sort(names)
	return names
end

-- Give a pig its ruff, or take it off.
--
-- STRIPPED ON EVERY SKIN THAT DOES NOT WANT ONE, not only added to those that
-- do. A skin is changed INTO, so a conditional that only ever attaches would
-- leave a Solid Gold pig wearing the tiger's wool -- the same trap
-- `reflectance` already fell into on the lawn.
--
-- SCALED OFF THE BODY IT IS ON. The mesh and its offset are authored against
-- the twelve-stud till, and a mini is that body at `bodyScale`, so the clone
-- takes the same fraction in size AND in seat -- a ruff at till size on a
-- 2.2-stud mini would be a cloud six times the animal.
--
-- `anchored` IS THE CALLER'S CONVENTION, not this function's: the lawn pig is
-- anchored part by part and the mini is welded to its body because it rides
-- a running thief. Same split every builder in this file already keeps.
function PiggyModel.applyFur(model: Instance, body: BasePart, tier: any, anchored: boolean)
	local worn = model:FindFirstChild(FUR_NAME)

	-- THE MESH IS THE FLAG. A skin asks for fur by carrying a `fur` colour,
	-- which is also the colour the lobes are painted -- one field rather
	-- than a boolean and a colour that could disagree.
	local wants = tier and tier.fur ~= nil and body:IsA("MeshPart")
	if not wants then
		if worn then
			worn:Destroy()
		end
		return
	end

	-- THE SET IS A PROPERTY OF THE SKIN AND FALLS BACK TO THE DEFAULT, so a
	-- skin that predates sets carries no `furSet` and gets the mane.
	local setName = tier.furSet or Config.DEFAULT_FUR_SET

	-- A WORN TUFT FROM A DIFFERENT SET IS DESTROYED RATHER THAN REUSED, and
	-- this is the whole reason the attribute exists. Reusing it would recolour
	-- the tiger's ruff, seat it at the crest's offset and call it a zebra --
	-- geometry from one animal at another's coordinates, with nothing erroring.
	if worn and worn:GetAttribute(FUR_SET_ATTRIBUTE) ~= setName then
		worn:Destroy()
		worn = nil
	end

	local template = ensureFurTemplate(setName)
	if not template then
		if worn then
			worn:Destroy()
		end
		return
	end

	local s = bodyScale(body)
	local part = worn :: BasePart?
	if not part then
		part = template:Clone()
	end
	assert(part)
	-- SIZE BEFORE CFRAME, the rule the prewarm keeps for the body: resizing a
	-- MeshPart scales it about its own centre, so seat it after.
	part.Size = template.Size * s
	part.Color = tier.fur
	part.Material = tier.material
	part.Transparency = tier.transparency
	part.Anchored = anchored
	part.Massless = not anchored

	-- THE RUFF WEARS THE BODY'S PACK, NOT THE TRIM'S, and that is the whole
	-- reason it can exist on a patterned animal at all. The lobe mesh is
	-- unwrapped on the SAME cylinder as the body, so handing it the body's
	-- ColorMap makes the spots and stripes carry straight over the fur --
	-- where a flat colour was a patch lying on top of the pattern whatever
	-- shade it was given.
	--
	-- UNLESS THE SKIN SAYS `furFlat`, in which case the ruff is its own
	-- `fur` colour and nothing else. A pack through the cylinder unwrap is
	-- right where the fur is a few tufts ON a marking; it is wrong where the
	-- fur IS the marking -- the lion's ruff sampled the sheet's top edge on
	-- the crown (black) and the face window on the cheeks (tawny) -- and a
	-- mane is one colour. `applySurface` with no pack also STRIPS a worn one,
	-- so a skin change from a packed fur to a flat one undresses the ruff.
	if tier.furFlat then
		local worn = part:FindFirstChild(SURFACE_NAME)
		if worn then
			worn:Destroy()
		end
	else
		PiggyModel.applySurface(part, tier, false)
	end

	-- SEATED OFF THE BODY'S OWN CFRAME, never off the plot's. Both meshes come
	-- out of one Blender scene, so the fur's offset and the body's are in the
	-- same frame -- and the far row of plots carries a half turn, which is the
	-- error this project records three times for anything measured in world
	-- axes.
	local spec = Config.furMesh(setName)
	part.CFrame = body.CFrame * CFrame.new(spec.offset * s)
	if not anchored and not part:FindFirstChildOfClass("WeldConstraint") then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = part
		weld.Parent = part
	end
	part.Parent = model
end

-- Build one skin's accessory set once and keep it to clone from.
--
-- A MODEL OF PARTS AT THEIR OWN SEATS, so a clone is already the right
-- SHAPE and `applyAccessories` only has to move and scale it. The seats,
-- sizes and colours are read back out of Config at apply time rather than
-- baked in, which is what lets a retuned offset take effect on the next
-- dress instead of on the next server.
--
-- THE MODEL IS LOADED WHOLE RATHER THAN MESH BY MESH, and that is not an
-- optimisation -- it is the only route that works. These meshes are
-- sub-assets of an FBX uploaded as a Model, and a real Script cannot
-- fetch one: measured, the running server failed the same two ids four
-- times each with `could not fetch` while the MCP sandbox resolved both
-- seconds later. See the note above `Config.SKIN_ACCESSORY_MODELS`. Loading
-- the model hands back the identical MeshParts with their MeshIds already
-- resolved, and costs ONE web call per skin instead of twelve.
--
-- THE PER-PART IDS STAY IN CONFIG AND ARE THE FALLBACK, for the day those
-- meshes are re-uploaded standalone through the 3D Importer -- which is
-- what `tools/upload_images.py` recommends and what every other mesh in
-- this game already is.
--
-- STAMPED BEFORE THE LOAD, the rule `ensureFurTemplate` keeps: a set is
-- attempted ONCE rather than on every skin change for the rest of the
-- session, which on a failing asset is a web call per pig per swap.
local function ensureAccessoryTemplate(key: string): Model?
	if accessoryChecked[key] then
		return accessoryTemplates[key]
	end

	local spec = Config.skinAccessories(key)
	if not spec then
		accessoryChecked[key] = true
		return nil
	end

	-- A CLIENT TAKES THE SERVER'S COPY AND NEVER LOADS ITS OWN, for the
	-- reason above ACCESSORY_TEMPLATE_FOLDER.
	--
	-- AND IT DOES NOT CACHE A MISS, which is the one place this differs from
	-- every other template cache in this file. Those stamp before the load so
	-- a dead asset costs ONE web call rather than one per pig per swap; a
	-- client does no web call at all here, it waits on replication. Stamping
	-- the miss made the client permanently bare: measured, the client's own
	-- prewarm ran while the server was still warming five sets, timed out,
	-- cached nil, and then every shop card for the rest of the session showed
	-- the coat and no geometry -- on a shelf that had the set by then.
	if not game:GetService("RunService"):IsServer() then
		local shelf = ReplicatedStorage:FindFirstChild(ACCESSORY_TEMPLATE_FOLDER)
		local shared = shelf and shelf:FindFirstChild(key)
		if shared and shared:IsA("Model") then
			local copy = shared:Clone()
			copy.Name = ACCESSORY_NAME
			accessoryTemplates[key] = copy
			accessoryChecked[key] = true
			return copy
		end
		-- Not an error, and not final: the server may simply not have
		-- published this set yet. The next dress asks again.
		return nil
	end

	accessoryChecked[key] = true
	local insert = game:GetService("InsertService")
	local holder = Instance.new("Model")
	holder.Name = ACCESSORY_NAME

	-- The parts this set's meshes will come from, keyed by the name the FBX
	-- exported them under -- which is the same name Config's rows carry.
	local source: { [string]: BasePart } = {}
	local modelId = Config.SKIN_ACCESSORY_MODELS[key]
	if type(modelId) == "string" and modelId ~= "" then
		for attempt = 1, 3 do
			local got, res = pcall(function()
				return insert:LoadAsset(tonumber(modelId) or 0)
			end)
			if got and res then
				for _, d in ipairs(res:GetDescendants()) do
					if d:IsA("BasePart") then
						source[d.Name] = d
					end
				end
				break
			end
			if attempt == 3 then
				warn(string.format(
					"[PiggyModel] LoadAsset(%s) for %q failed: %s",
					modelId, key, tostring(res)))
			end
			-- Backing off rather than hammering: what is being waited out is a
			-- queue, not a broken asset.
			task.wait(0.4 * attempt)
		end
	end

	local built, missing = 0, 0
	for _, entry in ipairs(spec) do
		local mesh: any = source[entry.part]
		if mesh then
			mesh = mesh:Clone()
		else
			-- No model, or a part the model did not carry: try the standalone
			-- mesh id, which is what a 3D Importer upload would give.
			local got, res = pcall(function()
				-- Box collision and no query, for the reason the ruff takes
				-- them: this is decoration standing on the one object a thief
				-- runs at and a dog patrols around, and precise collision on a
				-- storm cloud buys nothing and costs a physics query per pig.
				return insert:CreateMeshPartAsync(entry.id,
					Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
			end)
			mesh = if got then res else nil
		end

		if not mesh then
			missing += 1
		else
			-- SIZE IS WRITTEN HERE AND THE MESH'S OWN IS CHECKED, which is the
			-- opposite of what the ruff does and is deliberate. A ruff is ONE
			-- mesh whose authored size is the truth; these come out of an FBX
			-- exported at a hundred times scale, so the mesh reads 233 studs
			-- for a plate that is 2.33 -- the report's `sizeRobloxStuds` is the
			-- real number and Config carries it. The RATIO is checked rather
			-- than the size, because a silently wrong size is what buried the
			-- lion's mane in its own body.
			local authored = mesh.Size
			local ratio = if authored.Magnitude > 0
				then entry.size.Magnitude / authored.Magnitude
				else 0
			if ratio > 0 and (ratio < 0.005 or ratio > 1.5) then
				warn(string.format(
					"[PiggyModel] %s accessory %s: source is %.1f,%.1f,%.1f and"
					.. " Config says %.3f,%.3f,%.3f (ratio %.4f) -- re-read"
					.. " package/og-v1-asset-report.json for this skin.",
					key, entry.part, authored.X, authored.Y, authored.Z,
					entry.size.X, entry.size.Y, entry.size.Z, ratio))
			end
			mesh.Name = entry.part
			mesh.Size = entry.size
			mesh.Color = entry.colour
			mesh.Material = entry.material
			mesh.Transparency = entry.transparency or 0
			mesh.Anchored = true
			mesh.CanCollide = false
			mesh.CanQuery = false
			mesh.CanTouch = false
			mesh.CastShadow = false
			-- An FBX part can arrive wearing its own SurfaceAppearance or a
			-- texture, and Config's colour is the one that decides here.
			for _, child in ipairs(mesh:GetChildren()) do
				if child:IsA("SurfaceAppearance") then
					child:Destroy()
				end
			end
            if entry.surfaceTemplate then
                local packs = ReplicatedStorage.Shared:FindFirstChild("SurfacePacks")
                local surface = packs and packs:FindFirstChild(entry.surfaceTemplate)
                if surface then surface:Clone().Parent = mesh end
            end
            mesh:SetAttribute("ArcadeBaseSize", entry.size)
			mesh.Parent = holder
			built += 1
		end
	end

	if built == 0 then
		-- NEVER TAKE THE SKIN DOWN WITH IT. A pig with no plates is a
		-- cosmetic fault; a build that throws is every skin change in the
		-- game failing, which is what the surface pack already cost once.
		warn(string.format(
			"[PiggyModel] accessory set %q loaded none of its %d parts -- the"
			.. " pig wears its coat and no geometry.", key, #spec))
		holder:Destroy()
		return nil
	end
	if missing > 0 then
		warn(string.format("[PiggyModel] accessory set %q is %d of %d parts",
			key, built, built + missing))
	end

	-- PARKED FOR THE CLIENTS, under the skin's own key. Replicating a Model
	-- of MeshParts is what lets a shop card clone geometry it could never
	-- have loaded itself.
	local shelf = ReplicatedStorage:FindFirstChild(ACCESSORY_TEMPLATE_FOLDER)
	if not shelf then
		shelf = Instance.new("Folder")
		shelf.Name = ACCESSORY_TEMPLATE_FOLDER
		shelf.Parent = ReplicatedStorage
	end
	local published = holder:Clone()
	published.Name = key
	published.Parent = shelf

	accessoryTemplates[key] = holder
	return holder
end

-- The skins whose accessory sets exist, so `prewarm` can load them up
-- front and no dress ever yields on a web call.
local function accessorySetsInUse(): { string }
	local names: { string } = {}
	for key in pairs(Config.SKIN_ACCESSORIES) do
		if Config.skinAccessories(key) then
			table.insert(names, key)
		end
	end
	table.sort(names)
	return names
end

-- Give a pig its plates, points, flames, prisms or clouds -- or take them
-- off.
--
-- STRIPPED ON EVERY SKIN THAT DOES NOT WANT A SET, not only added to those
-- that do, which is the trap `applyFur` records: a conditional that only
-- ever attaches leaves a Marble pig wearing Stormcaller's clouds.
--
-- KEYED ON THE SKIN `key` RATHER THAN A FIELD ON THE ROW, because the set
-- IS the skin -- there is no world in which two skins share one set the way
-- two animals share a mane, so an `accessorySet` field would be a second
-- name for something the row already has and one more thing to disagree.
--
-- SCALED OFF THE BODY IT IS ON, the same as the ruff: the seats are authored
-- against the twelve-stud till and a mini is that body at `bodyScale`, so a
-- storm cloud at till size on a 2.2-stud plinth pig would be a fog bank.
function PiggyModel.applyAccessories(model: Instance, body: BasePart, key: string?, anchored: boolean)
	-- Restore any base piece hidden by the previous accessory set.
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") then
			local previous = part:GetAttribute("AccessoryHiddenFrom")
			if type(previous) == "number" then
				-- applySkin may already have assigned the next coat's alpha.
				if part.Transparency == 1 then part.Transparency = previous end
				part:SetAttribute("AccessoryHiddenFrom", nil)
			end
		end
	end
	SpectralFX.attach(model, body, key)
	-- Reseat the Mecha eyes against its face plate; undo this on skin change.
	local visual = key and Config.getSkin(key)
	local eyeForward = visual and visual.eyeForward or 0
	for _, eye in ipairs(model:GetChildren()) do
		if eye:IsA("BasePart") and eye.Name == "Eye" then
			local delta = eyeForward - (eye:GetAttribute("SkinEyeForward") or 0)
			if delta ~= 0 then
				local welds = {}
				for _, w in ipairs(eye:GetChildren()) do
					if w:IsA("WeldConstraint") and w.Enabled then w.Enabled = false; table.insert(welds, w) end
				end
				eye.CFrame += body.CFrame:VectorToWorldSpace(Vector3.new(0, 0, -delta * bodyScale(body)))
				for _, w in ipairs(welds) do w.Enabled = true end
			end
			eye:SetAttribute("SkinEyeForward", eyeForward)
		end
	end
	local worn = model:FindFirstChild(ACCESSORY_NAME)
	local spec = if body:IsA("MeshPart") then Config.skinAccessories(key) else nil

	if not spec then
		ArcadeAnimator.attach(model, body, key)
		if worn then
			worn:Destroy()
		end
		return
	end

	-- A SET FROM A DIFFERENT SKIN IS DESTROYED RATHER THAN RESEATED, for the
	-- reason the ruff's attribute exists: the part NAMES differ between sets,
	-- so reusing one would leave Rockslide's plates standing among Quartz's
	-- points with nothing erroring.
	if worn and worn:GetAttribute(ACCESSORY_SET_ATTRIBUTE) ~= key then
		worn:Destroy()
		worn = nil
	end

	local template = ensureAccessoryTemplate(key :: string)
	if not template then
		if worn then
			worn:Destroy()
		end
		return
	end

	local folder = worn :: Model?
	if not folder then
		folder = template:Clone()
		assert(folder)
		folder:SetAttribute(ACCESSORY_SET_ATTRIBUTE, key)
	end
	assert(folder)

	local s = bodyScale(body)
	for _, entry in ipairs(spec) do
		local part = folder:FindFirstChild(entry.part)
		if part and part:IsA("BasePart") then
			-- SIZE BEFORE CFRAME, the rule every mesh in this file keeps:
			-- resizing a MeshPart scales it about its own centre, so a part
			-- seated first and sized second sits where it used to be.
			part.Size = entry.size * s
			if entry.replaces then
				local base = model:FindFirstChild(entry.replaces)
				if base and base:IsA("BasePart") then
					base:SetAttribute("AccessoryHiddenFrom", base.Transparency)
					base.Transparency = 1
				end
			end
			-- SEATED OFF THE BODY'S OWN CFRAME, never off the plot's. The far
			-- row of plots carries a half turn, which is the error this
			-- project has recorded three times for anything in world axes.
			--
			-- `rot` IS OPTIONAL AND TURNS THE PART ABOUT ITS OWN SEAT, which
			-- is what the TRAILING multiply buys: `CFrame.new(offset) * rot`
			-- places first and then spins in place, where `rot * CFrame.new`
			-- would swing the part around the pig instead.
			--
			-- ALMOST NOTHING CARRIES ONE, AND THAT IS THE POINT. A set is
			-- authored against the body part, which already wears
			-- `Config.PIGGY_MESH`'s own half turn -- so a set that came in
			-- mirrored the same way the body did is square here for free and
			-- must NOT be turned again, or the two cancel. What `rot` is for
			-- is the set that came in mirrored relative to the body, which
			-- is one of them: `SKIN_ACCESSORIES.prismatic`, whose ring was
			-- measured hanging across the pig's snout.
			--
			-- A HALF TURN RATHER THAN A NEGATED OFFSET, because only the
			-- first is a motion a part can make: flipping the offset alone
			-- moves a mirrored ring to the right place still facing the
			-- wrong way. See the notes on both tables in `Config`.
			local seat = CFrame.new(entry.offset * s)
			if entry.rot then
				seat *= entry.rot
			end
			part.CFrame = body.CFrame * seat
			part.Anchored = anchored
			part.Massless = not anchored
			if not anchored and not part:FindFirstChildOfClass("WeldConstraint") then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = body
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end

	folder.Parent = model
	ArcadeAnimator.attach(model, body, key)
end

-- ------------------------------------------------------------
-- THE SKIN'S OWN AURA
-- ------------------------------------------------------------

PiggyModel.AURA_NAME = "SkinAura"

-- The emitter an epic or a legendary throws its particles from, built once
-- per body and left DISABLED until a skin configures it.
--
-- INWARD RATHER THAN OUTWARD, which is the one property that differs from an
-- equipped effect and is doing real work. With only three built-in particle
-- textures, emission SHAPE is what keeps two effects on one animal from
-- reading as one noisy one: an equipped effect blooms outward off the
-- surface; a skin's own aura falls inward toward it, so a legendary reads as
-- something coming OFF the animal rather than as a second copy of the same
-- cloud. A row's `inOut` may still override it.
function PiggyModel.buildSkinAura(body: BasePart): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = PiggyModel.AURA_NAME
	e.Enabled = false
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.LightEmission = 0.55
	e.Parent = body
	return e
end

-- Write one `Config.SKIN_AURAS` (or `Config.EFFECTS`) row onto an emitter.
--
-- `scale` IS THE BODY'S OWN, and the two properties measured in studs take
-- it. A row is authored against the twelve-stud till: a 1.3-stud spark on a
-- 2.2-stud mini is a snowball, and the same spark on a pedestal display at
-- 3.3x is right again. Rate, lifetime, drag and spread are unitless or in
-- seconds and are left alone.
function PiggyModel.configureAura(sa: ParticleEmitter, spec: any, scale: number?)
	local s = scale or 1
	sa.Texture = spec.texture
	sa.Color = spec.color
	sa.Rate = spec.rate
	local speed = spec.speed
	sa.Speed = if typeof(speed) == "NumberRange"
		then NumberRange.new(speed.Min * s, speed.Max * s)
		else NumberRange.new((tonumber(speed) or 0) * s)
	sa.Lifetime = spec.lifetime
	sa.Drag = spec.drag
	sa.Acceleration = spec.accel * s
	sa.SpreadAngle = Vector2.new(spec.spread, spec.spread)
	sa.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, spec.size * s),
		NumberSequenceKeypoint.new(1, 0),
	})
	local spin = spec.rotSpeed or 0
	sa.Rotation = NumberRange.new(0, 360)
	sa.RotSpeed = NumberRange.new(-spin, spin)
	sa.ShapeInOut = if spec.inOut == "Outward"
		then Enum.ParticleEmitterShapeInOut.Outward
		else Enum.ParticleEmitterShapeInOut.Inward
	sa.Enabled = true
end

-- Scale a mini for wherever it is standing, and keep everything on it that is
-- measured in studs in step. `Model:ScaleTo` carries the parts, the welds and
-- the fur; the aura's spark size and speed are re-derived from the row against
-- the body's NEW size, so a pedestal's 3.3x and a herd's 0.75 get the same
-- particles the till would at that size rather than the mini's.
--
-- THIS IS THE ONE PLACE A DISPLAY SCALE IS APPLIED. The pedestal and the herd
-- call it with `Config.piggyScale`; the carried loot and the till never do --
-- see that function for why the scale is a property of the placement.
function PiggyModel.scale(model: Model, factor: number)
	model:ScaleTo(model:GetScale() * factor)
	local body = PiggyModel.bodyOf(model)
	local key = model:GetAttribute("SkinKey")
	local sa = body and body:FindFirstChild(PiggyModel.AURA_NAME)
	if body and sa and sa:IsA("ParticleEmitter") and type(key) == "string" then
		local spec = Config.skinAura(Config.getSkin(key))
		if spec and spec.texture then
			PiggyModel.configureAura(sa, spec, bodyScale(body))
		end
	end
end

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
local meshPatternSurface: ((Vector3) -> number)? = nil

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
	-- And where the body actually is along every direction from that
	-- centre, so a mini's discs sit on its flank rather than on a sphere
	-- the flank is not on. Sampled once here; every clone keeps the pose.
	local templateBody = made:FindFirstChild("Body")
	meshPatternSurface = if templateBody and templateBody:IsA("BasePart")
		then PiggyModel.surfaceSampler(templateBody, CFrame.new(meshPatternAt), meshPatternR)
		else nil

	-- AND THE FUR, for the reason `furSetsInUse` gives: a ruff loaded inside
	-- a build would yield a pedestal dress on the economy tick.
	for _, setName in ipairs(furSetsInUse()) do
		task.spawn(ensureFurTemplate, setName)
	end

	-- AND THE ACCESSORY SETS, for exactly the same reason: five skins carry
	-- 6 to 12 meshes each, and loading them inside a dress would yield a
	-- pedestal on the economy tick and a shop card on the client.
	--
	-- ONE THREAD FOR ALL FIVE RATHER THAN ONE EACH, which is the other half of
	-- the throttling fix in `ensureAccessoryTemplate`. Spawned per set, the
	-- five raced each other for the same fetch queue and every one of them
	-- lost its first mesh; walked in order they simply take turns. It is still
	-- off the boot path, so the street does not wait for 41 meshes.
	task.spawn(function()
		for _, key in ipairs(accessorySetsInUse()) do
			ensureAccessoryTemplate(key)
		end
	end)

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
		-- THE KEY RIDES THE MODEL, exactly as it does on the lawn pig
		-- (`PiggyBank.applySkin`): the client animator reads it to drive an
		-- `anim` skin's colours, and `PiggyModel.scale` reads it to re-derive
		-- the aura. Written BEFORE the model is parented, so it replicates
		-- with it and a client's DescendantAdded sees a finished mini.
		mesh:SetAttribute("SkinKey", skinKey)
		local overrides = (skin :: any).parts
		local glowEyes = (skin :: any).glowEyes == true
		local body: BasePart? = nil
		local trimParts: { BasePart } = {}
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
				-- THE SAME THREE READS THE LAWN PIG MAKES, and in the same
				-- order: a per-part override wins, then the tier's own colour,
				-- and an eye goes Neon on a `glowEyes` skin. A mini that read
				-- fewer fields than the till was the "reads as a plain common
				-- on a plinth" report.
				if d.Name == "Eye" then
					d.Color = (overrides and overrides[d.Name]) or NEAR_BLACK
					d.Material = if glowEyes then Enum.Material.Neon else Enum.Material.SmoothPlastic
				elseif d:GetAttribute("Trim") == true then
					d.Color = (overrides and overrides[d.Name]) or skin.trim
					d.Material = skin.trimMaterial or skin.material
					d.Reflectance = skin.reflectance or 0
					table.insert(trimParts, d)
				else
					d.Color = skin.body
					d.Material = skin.material
					d.Reflectance = skin.reflectance or 0
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
				surface = meshPatternSurface,
				anchored = false,
				weldTo = body,
				material = skin.material,
				transparency = 0,
			})
			-- The skin's shape geometry, welded and still: see `Shared/SkinFX`.
			SkinFX.apply(mesh, body, skinKey, false)

			-- THE COAT, ON THE BODY AND ON THE TRIM, then the ruff over the
			-- coat, then the aura -- the lawn pig's own order (`applySkin`),
			-- because the ruff reads the body's pack and the aura hangs off
			-- the body. See the block above `build`.
			PiggyModel.applySurface(body, skin)
			for _, p in ipairs(trimParts) do
				PiggyModel.applySurface(p, skin, true)
			end
			PiggyModel.applyFur(mesh, body, skin, false)
			-- THE ACCESSORY GEOMETRY LAST OF THE SOLID THINGS, because it is
			-- the only one seated off the body that does NOT read the coat:
			-- a rock plate carries its own colour, so it neither needs the
			-- pack nor wants the ruff's cylinder unwrap. Welded rather than
			-- anchored here, the same as everything else on a mini -- this
			-- pig gets carried by a running thief.
			PiggyModel.applyAccessories(mesh, body, skinKey, false)
			local auraSpec = Config.skinAura(skin)
			if auraSpec and auraSpec.texture then
				PiggyModel.configureAura(PiggyModel.buildSkinAura(body), auraSpec, bodyScale(body))
			end
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
			-- Thicker approved boots keep the original sole clearance on displays.
			local lift = (skin.groundLift or 0) * bodyScale(body)
			if lift ~= 0 then mesh:PivotTo(mesh:GetPivot() + Vector3.new(0, lift, 0)) end
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
	-- The fallback carries the key too, so an `anim` skin still cycles on it
	-- -- a coat cannot land on a Ball, but a colour can.
	model:SetAttribute("SkinKey", skinKey)

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
