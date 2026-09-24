--!strict
--[[
	CombineStation -- THE COMBINE MACHINE, AS A PLACE ON THE STREET.

	Designer, 2026-09-23: "move the combine machine outside of the shop and
	into a dedicated spot on the map where players can combine their piggies
	and pets there for a chance to get better one."

	The MECHANIC is not here and is not new: `ChestService.combine` has
	consumed `Config.COMBINE.need` spares of one tier and rolled one tier up
	since spares existed. What moved is WHERE you do it -- off a slim row
	inside a shop tab and onto a machine you walk up to -- and this file is
	the machine: where it stands, what it is made of, and the pure half of
	what its panel says.

	----------------------------------------------------------------------
	WHY A PLACE IS WORTH THE PARTS.

	A shop row is a control; a machine is somewhere you GO. The row was four
	chips reading "COMMON 2/3" under a header, and a nine-year-old had to
	already know what combining was to find it. A hopper, a ram and a chute
	say what the thing does before a word is read -- which is the same
	argument that put rendered models on the shop cards instead of nineteen
	identical grey squares.

	----------------------------------------------------------------------
	EVERY NUMBER IN THE PURE HALF IS A PLAIN NUMBER, NEVER A VECTOR OR A
	CFRAME.

	The offline suite loads this module under the harness that loads Config:
	`CFrame.new` there is an inert stub whose `__mul` returns its left side,
	so any CFrame arithmetic would come back as furniture rather than as a
	measurement. So `placement`, `bounds`, `boxes` and every clearance are
	numbers, and `build` is the only function that touches a CFrame. That is
	what lets the coplanar audit and the whole street survey run with no
	engine at all -- see `tests/luau/combine.luau`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LowPoly = require(ReplicatedStorage.Shared.LowPoly)

local CombineStation = {}

-- ============================================================
-- WHERE IT STANDS
-- ============================================================
--
-- THE VERGE, IN A GAP BETWEEN TWO DRIVEWAYS, WHICH IS THE ONE PIECE OF
-- GROUND ON THIS STREET THAT BELONGS TO NOBODY.
--
-- `Config.streetMetrics` says so in as many words -- "the band between the
-- kerb and the front fences, and the one piece of ground on this street that
-- belongs to nobody and is wide enough to build on" -- and everything out
-- there already follows the same rule: the lamp posts, the wheelie bins, all
-- four shops and both verge boards stand in a gap between frontages, because
-- a driveway runs down the middle of every plot column.
--
-- THE ARRIVAL PLAZA IS NOT A CANDIDATE, AND THAT IS A MEASUREMENT RATHER
-- THAN A PREFERENCE. It is gone: `Config.streetMetrics` carries no plaza
-- field, `NeighborhoodService` paves nothing but the carriageway, its kerbs
-- and its centre line, and the word survives only in two stale comments
-- (`isOnStreet`'s "the square", and a tunnel note). There is no wide paved
-- ground at either end of the street to stand a machine on.
--
-- WHICH GAP IS DERIVED, AND THE DERIVATION HAS TO AGREE WITH THE BOARDS.
-- `SocialService.boardX` takes the nearest gap to the middle of the row that
-- no shop stands in; at five a side with shops in gaps 0 and 2 that is gap 1
-- (x -40), and both boards stand there at `boardZ`. So the station takes the
-- NEXT one out -- the same ordering, one step along -- which is gap 3 at
-- x +120. A column added, or a shop moved to another gap, carries the boards
-- and the station together rather than standing either on somebody's tarmac.
--
-- THAT ORDERING IS REPRODUCED HERE RATHER THAN SHARED, AND IT IS WORTH
-- SAYING WHY. `boardX` is a local in `SocialService`, which this file may
-- not reach into; lifting it into `Config` is the right end state and its
-- own comment says so ("a third reader is the point at which this earns a
-- `Config.gapX`"). `freeGaps` below is that ordering written once, and the
-- suite asserts it returns the board's gap FIRST -- so the day the two
-- disagree, a test says so rather than two objects sharing a patch of grass.

-- Which side of the street. There is no asymmetry to derive this from: the
-- two rows are mirror images and either shoulder is as good. +1 is the
-- shoulder the LEADERBOARD stands on, so the two things on this verge that
-- a player walks up to and READS share a side, and the wanted poster keeps
-- the other. One constant, so it can be flipped without hunting.
CombineStation.SIDE = 1

-- THE PLINTH IS THE FOOTPRINT, and everything else is inside it. Both
-- numbers were sized against the box list rather than chosen: the widest
-- thing on the machine is the lever knob at |x| 6.85 and the furthest
-- forward is the chute lip at z 5.1, so the plinth clears the lot.
-- `boundsFromBoxes` re-derives the real extent anyway and the suite measures
-- the street clearances against THAT -- so a piece added later that
-- overhangs cannot quietly eat a clearance behind a geometry edit.
CombineStation.WIDTH = 14
CombineStation.DEPTH = 11

-- HOW FAR THE PROMPT REACHES, AND IT IS MEASURED AGAINST WHAT ELSE IS IN
-- REACH RATHER THAN CHOSEN FOR FEEL.
--
-- It hangs off `Focus`, an invisible part at the machine's own centre, so
-- the range is half the depth plus the standing room in front of it:
-- 4.5 + 3.5. Measured against every other prompt on this stretch of verge,
-- as the pair of reaches against the distance between them:
--
--     wheelie bin hatch   18.10 studs away, range 5   -> 13 of 18.10
--     plot mailbox        29.35 studs away, range 10  -> 18 of 29.35
--     shop door (gap 2)   ~74 studs away,   range 8   -> 16 of 74
--
-- So nothing can ever be live alongside it, which is what lets it keep `E`:
-- a ProximityPrompt is `OnePerButton` by default, and two prompts on one key
-- do not both work. The suite holds the bin pair, which is the tight one.
CombineStation.PROMPT_RANGE = 8
CombineStation.PROMPT_HOLD = 0.4
CombineStation.PROMPT_KIND = "combine"

-- The name over it. NOT `AlwaysOnTop`: a plate that punches through the
-- machine it belongs to reads as a HUD element, which is the argument the
-- shop fascia plaques already settled. Capped, because a legible sign from
-- anywhere on a 500-stud street is a wall of text over the world -- the
-- shops cap at 260 and this is one object rather than eight, so it can be
-- tighter and still be readable from the pavement opposite.
CombineStation.PLATE_DISTANCE = 170

-- ============================================================
-- THE GAP ORDERING
-- ============================================================

-- Gaps no shop stands in, nearest the middle of the row first.
--
-- `Config.SHOPS` is the one place that says which gaps are built on, and
-- reading it rather than restating it means a shop moved to another gap
-- moves this instead of landing on top of it. The tie-break is the GAP
-- INDEX, which reproduces `boardX`'s strict `<` on a row whose columns are
-- symmetric about zero -- at an even count the two middle gaps are equally
-- far out and the lower index wins there too.
function CombineStation.freeGaps(): { number }
	local taken: { [number]: boolean } = {}
	for _, placement in ipairs(Config.SHOPS) do
		taken[placement.gap] = true
	end
	local free: { number } = {}
	for gap = 0, Config.PLOTS_PER_ROW - 2 do
		if not taken[gap] then
			table.insert(free, gap)
		end
	end
	table.sort(free, function(a: number, b: number): boolean
		local ax, bx = math.abs(Config.shopGapX(a)), math.abs(Config.shopGapX(b))
		if ax ~= bx then
			return ax < bx
		end
		return a < b
	end)
	return free
end

-- Where the machine stands, in world coordinates.
--
-- EVERY GAP BEING SPOKEN FOR IS A REAL CONFIGURATION and it must not put the
-- station on a driveway or inside a board. Past the last column is the
-- honest fallback -- the verge runs to the hillside out there with nothing
-- on it -- and it is LOUD, because a machine nobody walks past is a smaller
-- failure than one standing in a drive, and a warning is what stops it being
-- a silent one. Same call `boardX` makes, and the tree veto below covers the
-- fallback spot by construction because it measures the real footprint.
function CombineStation.placement()
	local m = Config.streetMetrics()
	local free = CombineStation.freeGaps()
	-- [1] is the boards'. [2] is ours.
	local gap = free[2]
	local x
	if gap then
		x = Config.shopGapX(gap)
	else
		warn("[CombineStation] the boards and the shops take every gap on the row,"
			.. " so the combine machine stands past the end of it instead."
			.. " Free a gap in Config.SHOPS.")
		x = Config.plotColumnX(Config.PLOTS_PER_ROW - 1) + Config.PLOT_SPACING / 2
	end
	return {
		gap = gap,
		x = x,
		-- MID-VERGE, which is the band the boards use: it reads from the
		-- carriageway and from the pavement, and it leaves the back of the
		-- band (`shopZ`) free for a fifth shop.
		z = CombineStation.SIDE * m.boardZ,
		side = CombineStation.SIDE,
		-- FRONT TOWARD THE ROAD. Every model in this game is authored facing
		-- +Z, so the +Z shoulder takes a half turn and the -Z shoulder takes
		-- none -- which is `boardYaw`'s rule with the sign flipped, because
		-- a Roblox GUI faces -Z and a part authored by hand here faces +Z.
		yaw = if CombineStation.SIDE > 0 then math.pi else 0,
	}
end

-- ============================================================
-- THE GEOMETRY, AS DATA
-- ============================================================
--
-- A LIST OF BOXES RATHER THAN A SEQUENCE OF `Instance.new` CALLS, because
-- the coplanar audit has to be able to READ it.
--
-- "Surfaces must never be coplanar" is written three times in CLAUDE.md and
-- the rebuilt cottage broke it eighteen times; the shops started at 51 pairs
-- and the eight original house tiers still carry 32 between them. The rule
-- is same-facing shared face planes with real overlap on the other two axes,
-- and the only way to be sure is to sweep it -- which needs the geometry as
-- numbers, not as parts in a workspace nothing offline has.
--
-- So `boxes` is pure and `build` walks it. `tests/luau/combine.luau` runs the
-- sweep and asserts ZERO, and it does so on the same list the world is built
-- from rather than on a second description of it.
--
-- STATION-LOCAL: +Z is the FRONT (toward the road), +Y up, origin at the
-- pavement. A BALL is skipped by the audit and says so: a sphere has no flat
-- face to share a plane with.

local STONE = Color3.fromRGB(150, 141, 128)
local CASE = Color3.fromRGB(222, 118, 152)   -- the piggy pink, as the shell
local CASE_DEEP = Color3.fromRGB(168, 78, 108)
local TIMBER = LowPoly.TIMBER
local DARK = Color3.fromRGB(38, 31, 28)
local BRASS = Color3.fromRGB(226, 176, 72)
local GLASS = LowPoly.GLASS
-- DEEP ON PURPOSE, which is the fifth time this project has written that
-- sentence: Neon renders a colour flat out and the BloomEffect takes it from
-- there, so a pale "warm lamp" is a white hole with a halo round it. The
-- street lamp, the Martian skin, the palace colonnade and the townhouse
-- window rank are the other four.
local LAMP = Color3.fromRGB(96, 226, 132)

local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon

-- NOT ONE TEXTURED MATERIAL, AND `Metal` IS ON THAT LIST. `Brick`, `Slate`,
-- `WoodPlanks`, `DiamondPlate` and `Grass` are the five the house rebuild
-- took off every building in the game; `Metal` is the sixth and slips past
-- the word "textured" because it is not a texture -- it SHADES a colour by
-- the environment, so the same brass reads bright on one part and olive on
-- the one beside it. A colour that has to be a particular colour is flat.
local function box(name: string, sx: number, sy: number, sz: number,
	x: number, y: number, z: number, colour: Color3, material: Enum.Material?)
	return { name = name, sx = sx, sy = sy, sz = sz, x = x, y = y, z = z,
		colour = colour, material = material or SMOOTH, shape = "box" }
end

local function ball(name: string, d: number, x: number, y: number, z: number,
	colour: Color3, material: Enum.Material?)
	return { name = name, sx = d, sy = d, sz = d, x = x, y = y, z = z,
		colour = colour, material = material or SMOOTH, shape = "ball" }
end

-- Every level the pieces are seated against, named once. A detail that
-- STANDS ON something sinks 0.1 into it -- the convention the house rebuild
-- adopted after a hundred of its 142 coplanar pairs turned out to be one
-- mistake, a part sized to land its foot exactly on what it stands on.
local SINK = 0.1
local PLINTH_TOP = 1.2
-- The plinth's own cap stands PROUD of it, so the level the shell is seated
-- against is the cap's top rather than the plinth's. Sharing one number
-- there is exactly the "sized to land its foot on what it stands on" fault.
local CAP_TOP = 1.55
local BODY_TOP = 7.7
local CORNICE_TOP = 8.4
local BEAM_BOTTOM = 10.6
local BEAM_TOP = 11.5
-- The gantry and the hopper share the cornice and are SEPARATED IN Z rather
-- than stacked: a ram hanging on the machine's centre line would sit inside
-- the hopper mouth and fill the one dark opening it is there to show. The
-- press works at the back and you feed it at the front.
local GANTRY_Z = -2.1
local HOPPER_Z = 1.6

function CombineStation.boxes()
	local out = {}
	local function add(b) table.insert(out, b); return b end

	-- A PLINTH WHERE IT MEETS THE GROUND, which is the low-poly rule that
	-- separates a building from a box resting on grass -- and it is the one
	-- piece of this machine that is not the machine.
	--
	-- NO PAVED APRON UNDER IT. CLAUDE.md records the aprons the boards were
	-- given being removed again: a verge is GRASS, everything else standing
	-- on it does so with no slab underneath, and two rectangles of tarmac in
	-- the middle of it read as the leftover of something taken away.
	add(box("Plinth", CombineStation.WIDTH, PLINTH_TOP, CombineStation.DEPTH,
		0, PLINTH_TOP / 2, 0, STONE))
	-- A hard line where the plinth meets the shell: a course standing proud
	-- of both, so the corner reads as an edge rather than as a change of
	-- colour. Narrower than the plinth and wider than the body, so it shares
	-- a face plane with neither -- and its TOP is proud of the plinth's, so
	-- it is not the "flush foot" pair either.
	add(box("PlinthCap", 12.8, 0.5, 7.8, 0, CAP_TOP - 0.25, 0, TIMBER))

	-- The shell. Sunk into the cap, so its foot is never a shared plane.
	add(box("Body", 11.4, BODY_TOP - (CAP_TOP - SINK), 7.0,
		0, (CAP_TOP - SINK + BODY_TOP) / 2, 0, CASE))
	-- A darker band low on the shell, so a 6.5-stud wall is not one flat
	-- field of pink. Proud of the body by 0.15 and inside its own ends.
	add(box("Skirt", 11.7, 1.1, 7.3, 0, 2.05, 0, CASE_DEEP))

	-- The cornice: the hard line at the top corner, proud on every side.
	add(box("Cornice", 12.2, CORNICE_TOP - (BODY_TOP - SINK), 7.8,
		0, (BODY_TOP - SINK + CORNICE_TOP) / 2, 0, TIMBER))

	-- ------------------------------------------------------------
	-- THE WINDOW: what makes it a machine rather than a cabinet.
	-- ------------------------------------------------------------
	--
	-- A FRAMED opening, never a flat rectangle of glass -- "an unframed
	-- opening is a sticker; a frame, a sill and a mullion cross make it a
	-- window" is one of the four things the house pass measured against
	-- reference art. And two colour families: the shell is the light one and
	-- the joinery is DARK, which is what makes glazing read as a hole rather
	-- than as a panel. The shops shipped white-on-white once and it took
	-- four wrong diagnoses to find out the geometry had been fine all along.
	local FRONT = 3.5
	add(box("Glass", 6.0, 3.0, 0.3, 0, 4.8, FRONT + 0.1, GLASS))
	-- The mullion sits INSIDE the glass in Y and PROUD of it in Z, so it
	-- shares no plane with the glass, the sill or the lintel. Its first
	-- version was the glass's own height at the sill's own depth and was
	-- three pairs on its own.
	add(box("Mullion", 0.3, 2.7, 0.4, 0, 4.8, FRONT + 0.25, DARK))
	add(box("Sill", 7.8, 0.5, 0.8, 0, 3.1, FRONT + 0.4, DARK))
	add(box("Lintel", 7.0, 0.5, 0.8, 0, 6.5, FRONT + 0.4, DARK))
	for _, sx in ipairs({ -1, 1 }) do
		-- The jambs BUTT the sill and the lintel rather than reaching past
		-- them: a frame made of four pieces that cross at the corners is
		-- four coplanar pairs. They also sit a HAIR off the sill's own depth
		-- -- a frame whose uprights exactly span its rails is the shop
		-- window's own bug, and 0.08 of stagger is what settles it.
		add(box("Jamb", 0.6, 3.4, 0.7, sx * 3.3, 4.7, FRONT + 0.27, DARK))
	end

	-- ------------------------------------------------------------
	-- THE HOPPER, THE RAM AND THE CHUTE: in, down, out.
	-- ------------------------------------------------------------
	--
	-- Read in that order from the pavement, which is the whole reason this
	-- is a machine and not a kiosk. Spares go in the top, the ram comes
	-- down, and what you get comes out of the tray at the front.
	for _, sx in ipairs({ -1, 1 }) do
		-- Sunk into the cornice at the foot and into the beam at the head,
		-- so neither joint is a shared plane.
		add(box("GantryPost", 1.2, (BEAM_BOTTOM + SINK) - (CORNICE_TOP - SINK), 1.2,
			sx * 4.2, ((CORNICE_TOP - SINK) + (BEAM_BOTTOM + SINK)) / 2, GANTRY_Z, TIMBER))
	end
	add(box("GantryBeam", 10.4, BEAM_TOP - BEAM_BOTTOM, 2.0,
		0, (BEAM_BOTTOM + BEAM_TOP) / 2, GANTRY_Z, TIMBER))
	-- Hanging under the beam with daylight over the cornice, which is the
	-- gap a press works in.
	add(box("Ram", 3.6, (BEAM_BOTTOM + SINK) - (CORNICE_TOP + SINK), 2.6,
		0, ((CORNICE_TOP + SINK) + (BEAM_BOTTOM + SINK)) / 2, GANTRY_Z, BRASS))

	-- The hopper mouth: a ring of four bars standing PROUD of a dark plate.
	-- A recess is made by standing something proud around the dark, never by
	-- sinking the dark -- the eye takes the highest line as the surface, and
	-- flush it is a black sticker. Same rule as the moat's kerbs and the
	-- piggy's own vault rim.
	--
	-- THE FOUR BARS BUTT AND DO NOT CROSS. The front and back run the full
	-- width; the sides span only the gap BETWEEN their inner faces, so the
	-- overlap on every corner pair is exactly zero. A ring built as four
	-- crossing bars is four coplanar pairs, which is what the shop's own
	-- window frame paid for.
	local RIM_Y = CORNICE_TOP + 0.3
	add(box("HopperFloor", 4.6, 0.4, 3.0, 0, RIM_Y - 0.2, HOPPER_Z, DARK))
	add(box("HopperRimFront", 5.4, 0.7, 0.4, 0, RIM_Y, HOPPER_Z + 1.35, BRASS))
	add(box("HopperRimBack", 5.4, 0.7, 0.4, 0, RIM_Y, HOPPER_Z - 1.35, BRASS))
	for _, sx in ipairs({ -1, 1 }) do
		add(box("HopperRimSide", 0.4, 0.7, 2.3, sx * 2.5, RIM_Y, HOPPER_Z, BRASS))
	end

	-- The chute: a tray proud of the shell at waist height, under the
	-- window, so the front face reads top to bottom as IN, SEE, OUT. The lip
	-- is narrower and stands proud of the tray's own front edge, so the two
	-- share neither an X plane nor a Z one.
	add(box("ChuteTray", 5.6, 0.5, 1.6, 0, 1.9, FRONT + 0.6, BRASS))
	add(box("ChuteLip", 5.0, 0.7, 0.4, 0, 2.3, FRONT + 1.4, BRASS))
	add(box("ChuteMouth", 4.4, 0.9, 0.4, 0, 2.55, FRONT + 0.05, DARK))

	-- ------------------------------------------------------------
	-- THE LEVER, on the side, because the front is full.
	-- ------------------------------------------------------------
	add(box("LeverBox", 1.0, 1.6, 2.4, 5.95, 5.2, 0.8, TIMBER))
	add(box("LeverArm", 0.5, 2.4, 0.5, 6.4, 6.4, 0.8, BRASS))
	add(ball("LeverKnob", 0.9, 6.4, 7.5, 0.8, CASE_DEEP))

	-- The running lamp, so the thing reads as powered. Deep green, and it is
	-- the only Neon on the machine.
	for _, sx in ipairs({ -1, 1 }) do
		add(box("Lamp", 0.8, 0.8, 0.3, sx * 4.6, 6.5, FRONT + 0.05, LAMP, NEON))
	end

	return out
end

-- The footprint the box list actually produces, rather than the one the
-- constants above claim. A piece added later that overhangs the plinth grows
-- this, and the suite measures the street clearances against it -- so the
-- clearances cannot go stale behind a geometry edit.
function CombineStation.boundsFromBoxes()
	local minX, maxX, minZ, maxZ, maxY = math.huge, -math.huge, math.huge, -math.huge, -math.huge
	for _, b in ipairs(CombineStation.boxes()) do
		minX = math.min(minX, b.x - b.sx / 2)
		maxX = math.max(maxX, b.x + b.sx / 2)
		minZ = math.min(minZ, b.z - b.sz / 2)
		maxZ = math.max(maxZ, b.z + b.sz / 2)
		maxY = math.max(maxY, b.y + b.sy / 2)
	end
	return { minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ, height = maxY }
end

-- The station's own rectangle in WORLD coordinates, half-extents included.
--
-- The local frame is turned a half turn on the +Z shoulder, which swaps the
-- sign of local X and local Z and leaves the rectangle the same shape -- so
-- the world box is the local half-extents about the placement, and the yaw
-- does not enter it. Stated rather than assumed, because a rectangle read in
-- world axes on a row that carries a half turn is the third-most-recorded
-- probe mistake in this project.
function CombineStation.worldBox()
	local at = CombineStation.placement()
	local b = CombineStation.boundsFromBoxes()
	local halfX = math.max(math.abs(b.minX), math.abs(b.maxX))
	local halfZ = math.max(math.abs(b.minZ), math.abs(b.maxZ))
	return {
		x = at.x, z = at.z,
		halfX = halfX, halfZ = halfZ,
		minX = at.x - halfX, maxX = at.x + halfX,
		minZ = at.z - halfZ, maxZ = at.z + halfZ,
		height = b.height,
	}
end

-- Is this ground the machine's? XZ only, plus a margin for whatever is
-- asking. Two callers, both in `NeighborhoodService`:
--
--   the verge GRASS, which would otherwise grow through the plinth -- the
--   band runs |z| 11 to 24.2 and the machine's front face is at 22.7, so
--   about a stud and a half of it is inside the tuft strip; and
--
--   the verge TREES, whose `clear(x)` already vetoes a canopy over a
--   driveway or a shop.
--
-- A LIST OF EXCEPTIONS IS A CLAIM ABOUT WHAT EXISTS AND IT GOES STALE
-- WITHOUT ERRORING: `buildVergeGrass` was written when the only things on
-- the verge were lamp posts and bins, and its own comment still derives the
-- band from those. Adding a thing to the verge means adding its veto in the
-- same breath.
function CombineStation.occupies(x: number, z: number, margin: number?): boolean
	local w = CombineStation.worldBox()
	local keep = margin or 0
	return x >= w.minX - keep and x <= w.maxX + keep
		and z >= w.minZ - keep and z <= w.maxZ + keep
end

-- Would a verge tree planted here stand in the machine?
--
-- SIDE-AWARE, AND THAT ARGUMENT IS BACK ON PURPOSE. `buildStreetTrees` used
-- to take one, lost it when the shop tills moved indoors, and its own
-- comment says exactly this: "the next thing that stands on a verge will
-- have to bring that argument back with it." This is that thing. A symmetric
-- veto would cost the far row a tree for a machine that is not on it.
--
-- Measured at the shipped numbers it vetoes NOTHING: gap 3's two candidates
-- sit at x 99 and 141 with a canopy reach of 7.99, and the nearest corner of
-- the machine is 14.48 studs away, so both trees stand and frame it. The
-- veto is here because a scale, an offset or a gap that moves would put one
-- through the shell silently, and the suite drives it both ways.
function CombineStation.blocksTree(x: number, side: number, reach: number): boolean
	local at = CombineStation.placement()
	if side ~= at.side then
		return false
	end
	return CombineStation.occupies(x, at.z, reach)
end

-- ============================================================
-- THE MEASURED CLEARANCES
-- ============================================================
--
-- Every constraint the machine has to clear, as the gap in studs, derived
-- from Config rather than recorded from a session. The suite asserts each
-- one is positive and the boot line prints the tightest, so a street edit
-- that closes one says so at startup rather than in a screenshot.
--
-- POSITIONS TAKEN FROM THE FILES THAT BUILD THE THINGS, not from memory:
-- the kerb is `roadHalfWidth` with a 1.6-deep slab on it, so its outer face
-- is +0.8; the lamp posts and bins stand on the 1.8 verge line at |z| 9.8;
-- the bin sits `+5` along the gap from the lamp and is a 2.9-wide cylinder;
-- the front ClimbZone is `spanSize(true, length, 5, 3)` centred on the fence
-- line, so it stands 1.5 studs proud of it at |z| 44.9 -- and that is the
-- thing to measure a verge building against, never the fence LINE, which is
-- the mistake that left the shops 2.8 studs off it.
function CombineStation.clearances()
	local m = Config.streetMetrics()
	local at = CombineStation.placement()
	local w = CombineStation.worldBox()
	local absZ = math.abs(at.z)
	local nearZ = absZ - w.halfZ
	local farZ = absZ + w.halfZ

	-- The nearest driveway edge, either side.
	local halfDrive = Config.DRIVEWAY_WIDTH / 2
	local driveway = math.huge
	for col = 0, Config.PLOTS_PER_ROW - 1 do
		local edge = Config.plotColumnX(col)
		local gap = math.min(
			math.abs(w.minX - (edge + halfDrive)),
			math.abs((edge - halfDrive) - w.maxX))
		if (edge + halfDrive) < w.minX or (edge - halfDrive) > w.maxX then
			driveway = math.min(driveway, gap)
		else
			driveway = -gap
		end
	end

	-- The two verge trees in this gap, at the canopy's own reach. The tree
	-- table is NeighborhoodService's, so this reads the pair it plants: a
	-- candidate each side of the gap centre at its own `z`.
	local function cornerGap(tx: number, tz: number, reach: number): number
		local dx = math.max(w.minX - tx, tx - w.maxX, 0)
		local dz = math.max(nearZ - tz, tz - farZ, 0)
		return math.sqrt(dx * dx + dz * dz) - reach
	end

	return {
		-- Never in the carriageway: the pavement left in front of it.
		carriageway = nearZ - (m.roadHalfWidth + 0.8),
		-- Clear of the fence trigger, not the fence line.
		climbZone = (m.fenceLine - 1.5) - farZ,
		-- Outside every yard: `yardContaining` tests to the front fence.
		yard = m.fenceLine - farZ,
		-- Never on a driveway.
		driveway = driveway,
		-- The lamp post (0.6 square) and the wheelie bin (2.9 across), both
		-- on the verge line in this same gap.
		lamp = nearZ - (m.roadHalfWidth + 1.8 + 0.3),
		bin = math.sqrt(
			math.max(w.minX - (at.x + 5), (at.x + 5) - w.maxX, 0) ^ 2
			+ (nearZ - (m.roadHalfWidth + 1.8)) ^ 2) - 1.45,
		-- Both verge boards, the widest of which is 30 across.
		board = math.abs(at.x - Config.shopGapX(CombineStation.freeGaps()[1] or 0)) - 15 - w.halfX,
		-- The nearest shop unit, 21 wide with a two-stud forecourt overhang.
		shop = (function()
			local best = math.huge
			for _, placement in ipairs(Config.SHOPS) do
				best = math.min(best,
					math.abs(at.x - Config.shopGapX(placement.gap)) - 11.5 - w.halfX)
			end
			return best
		end)(),
		-- The herd corridor: the one line every pack crosses the verge on.
		herd = Config.herdGround().corridorX - w.maxX,
		-- Where the trees in this gap actually land, so a canopy edit shows
		-- up here rather than in the render.
		tree = math.min(
			cornerGap(at.x - 21, 19, 7.99),
			cornerGap(at.x + 21, 19, 7.99)),
		-- The tight prompt pair: the wheelie bin's hide/dig, five studs.
		promptBin = math.sqrt(25 + (absZ - (m.roadHalfWidth + 1.8)) ^ 2)
			- CombineStation.PROMPT_RANGE - Config.BINS.range,
	}
end

-- ============================================================
-- WHAT THE PANEL SAYS -- THE PURE HALF
-- ============================================================

-- THE TWO KINDS, AND THE SPARE KIND EACH ONE EATS.
--
-- `data.spares` is keyed `kind:key`, and the kinds are the catalogue names
-- `Config.catalogueFor` answers for. PIGGIES are skins; GUARDIANS are coats,
-- which is a catalogue the guardians workstream is adding -- so this table
-- names it and every reader below is nil-safe, because a kind whose
-- catalogue does not exist yet must refuse OUT LOUD rather than throw.
-- `one` is the singular, WRITTEN OUT rather than trimmed off `name`. The
-- first version chopped the last letter and told a nine-year-old it needed
-- "more spare piggie".
CombineStation.KINDS = {
	{ key = "piggy", name = "PIGGIES", one = "piggy", spareKind = "skin",
		blurb = "Three spare piggies of one rarity, for one better piggy." },
	{ key = "guardian", name = "GUARDIANS", one = "guardian", spareKind = "coat",
		blurb = "Three spare guardians of one rarity, for one better guardian." },
}

function CombineStation.kind(key: string)
	for _, entry in ipairs(CombineStation.KINDS) do
		if entry.key == key then
			return entry
		end
	end
	return nil
end

-- WHICH CRATE POOLS A KIND'S ROLL MAY LAND IN, derived from what is actually
-- stocked rather than listed here.
--
-- `ChestService.combine` takes a chest KEY and rolls out of that chest's own
-- pool, and `Crates` already teaches the rule the station keeps: the spares
-- are global per tier and THE SHELF IS WHERE THE ROLL LANDS. So a shelf is
-- offered for a kind when that kind is in the shelf's base pool at all --
-- walked through `Config.chestPool` and `Config.chestEntry`, which are the
-- same two functions the crates tab reads. Add a coat to a crate and the
-- guardian shelf appears with nothing to remember here.
--
-- THE ALIEN CACHE WAS DELETED ON 2026-09-23, so no chest is excluded here any
-- more and the paragraph below is the reasoning rather than a description of a
-- live crate. The refusal in `canCombineChest` is kept for the next event
-- crate. AS WRITTEN AT THE TIME:
-- Event-set crates are excluded by `canCombineChest`, which is why the Alien
-- Cache never shows up: ordinary spares may not bypass an event's own route.
--
-- AND A PRICED CRATE IS EXCLUDED TOO, BY MIRRORING THE SERVER'S OWN GATE
-- RATHER THAN BY INVENTING ONE. `ChestService.whyCannotOpen` refuses any
-- chest where `cost` or `currency` is set -- "FAIL CLOSED IF A FUTURE
-- CATALOGUE EDIT PUTS A PRICE BACK" -- and `combine` asks it before anything
-- else. So a shelf this offers with either field set would be a button that
-- lights and then refuses, which is the client failing to decline a known no.
--
-- `robux` IS DELIBERATELY NOT IN THAT TEST, AT EITHER END. The Guardian
-- Crate carries one (49, added 2026-09-23) and this offers it, because a
-- combine is not an OPEN of that crate: the chest key names a POOL, and what
-- pays for the roll is three coats the player already owns. It is a sink --
-- three in, one out -- so it mints nothing and bypasses no purchase, and
-- nothing random here is bought with Robux or with anything Robux can buy,
-- which is the line the whole paid-random-item position rests on.
--
-- IF THAT IS EVER THE WRONG CALL, the fix is one field: naming the Guardian
-- Crate's price `cost` instead of `robux` removes the guardian shelf from
-- this machine AND makes `combine` refuse it, from the same two tests.
function CombineStation.shelvesFor(kindKey: string)
	local kind = CombineStation.kind(kindKey)
	local out = {}
	if not kind then
		return out
	end
	for _, section in ipairs(Config.CRATE_SECTIONS) do
		local base = section.chests and section.chests[1]
		local chest = base and Config.CHESTS[base]
		local priced = chest ~= nil and (chest.cost ~= nil or chest.currency ~= nil)
		if base and not priced and Config.canCombineChest(base) then
			local pool = Config.chestPool(base)
			local holds = false
			for _, entries in pairs(pool) do
				for _, entry in ipairs(entries) do
					local entryKind = Config.chestEntry(base, entry)
					if entryKind == kind.spareKind then
						holds = true
						break
					end
				end
				if holds then
					break
				end
			end
			if holds then
				table.insert(out, { key = section.key, name = section.name, chest = base })
			end
		end
	end
	return out
end

-- The tiers a shelf can be climbed OUT of: every tier this shelf stocks
-- something ABOVE. A chip that can never light is worse than no chip, which
-- is `Crates`' own rule for its combine row -- and this is that rule
-- corrected in the one place it was too strict.
--
-- `Crates` offers "every STOCKED tier but the top one", which asks the wrong
-- question: the spares going IN are the player's own and are global per
-- tier, so what the shelf has to stock is the OUTPUT. Measured against the
-- live catalogue: the Arcade pool holds no commons at all, so its row hides
-- the common chip -- and a common combine there would land on a rare, an
-- epic or a legendary, all three of which it stocks. The station offers it.
--
-- WHAT IT CANNOT PROMISE, STATED PLAINLY: `ChestService.combine` rolls the
-- CLIMB (85/12/3) and then looks the target tier up, so a shelf with a hole
-- in the middle of its ladder can still refuse a two-step climb it happened
-- to roll. It refuses BEFORE consuming anything -- which is the property the
-- suite pins by reading that file's own order -- so the cost is a message
-- rather than three spares.
function CombineStation.tiersFor(chestKey: string): { string }
	local pool = Config.chestPool(chestKey)
	local top = 0
	for rank, tier in ipairs(Config.RARITY_ORDER) do
		if pool[tier] and #pool[tier] > 0 then
			top = rank
		end
	end
	local out = {}
	for rank, tier in ipairs(Config.RARITY_ORDER) do
		if rank < top then
			table.insert(out, tier)
		end
	end
	return out
end

-- The player's own spares of one kind at one tier, out of the `ChestState`
-- push. CHEAPEST FIRST, which is the order the machine consumes them in.
--
-- THIS IS A PICKER, NOT A SECOND COPY OF THE CONSUMER. `ChestService`
-- consumes `data.spares` and nothing here writes to it; what this decides is
-- WHICH three the panel offers to send, and the server rebuilds that list
-- from known-good parts through `validatePick` before touching a save.
--
-- It has to exist because the server's own `autoPick` pools ACROSS kinds --
-- deliberately, since three commons of any kind make a rare -- so a bare
-- `chosen = nil` at a station that says PIGGIES could eat a spare coat. The
-- RULE is the server's ("leave the valuable ones"), and it reads the `value`
-- the server already computed rather than re-deriving one.
function CombineStation.sparesOf(state: any, kindKey: string, tier: string?)
	local kind = CombineStation.kind(kindKey)
	local out = {}
	if not kind or type(state) ~= "table" or type(state.spares) ~= "table" then
		return out
	end
	for entry, record in pairs(state.spares) do
		if type(record) == "table" and record.kind == kind.spareKind
			and (tier == nil or record.tier == tier)
			and type(record.count) == "number" and record.count > 0
		then
			table.insert(out, {
				entry = entry, key = record.key, name = record.name,
				count = record.count, tier = record.tier, value = record.value or 0,
			})
		end
	end
	table.sort(out, function(a, b)
		if a.value ~= b.value then
			return a.value < b.value
		end
		return a.entry < b.entry
	end)
	return out
end

-- How many copies of one kind the player holds at one tier.
function CombineStation.countAt(state: any, kindKey: string, tier: string): number
	local total = 0
	for _, record in ipairs(CombineStation.sparesOf(state, kindKey, tier)) do
		total += record.count
	end
	return total
end

-- The `need` entries the machine would take, cheapest first, one line per
-- copy -- which is the shape `ChestCombine` wants and the multiset
-- `validatePick` counts.
function CombineStation.autoPick(state: any, kindKey: string, tier: string): { string }
	local take = {}
	local need = Config.COMBINE.need
	for _, record in ipairs(CombineStation.sparesOf(state, kindKey, tier)) do
		for _ = 1, record.count do
			if #take >= need then
				return take
			end
			table.insert(take, record.entry)
		end
	end
	return take
end

-- WHY THE BUTTON IS NOT LIT, IN THE PLAYER'S OWN WORDS, AND BEFORE ANYTHING
-- IS CONSUMED.
--
-- Every refusal here is said UP FRONT rather than after the machine has
-- swallowed three piggies, which is the rule the sell refusal and the bone
-- refusals already follow: a consumable spent for nothing is
-- indistinguishable from a broken item. The server refuses independently and
-- says so too -- this is the client declining to ask for a known no, the
-- same split the number row and the dodge-while-riding suppression make.
--
-- NOTHING LEFT TO WIN IS THE ONE THAT IS NEW HERE. A crate roll can hand
-- back a duplicate; a pool that is unowned-only cannot, so the failure at
-- the top of a collection is that there is nothing ABOVE this tier to give.
-- `ChestService.combine` checks it too and checks it before its own
-- consumption loop -- which the suite asserts by reading the order of that
-- file -- but a button that lights and then refuses is the thing this is for.
function CombineStation.refusal(state: any, kindKey: string, chestKey: string?,
	tier: string?): string?
	local kind = CombineStation.kind(kindKey)
	if not kind then
		return "That machine setting does not exist."
	end
	if not Config.catalogueFor(kind.spareKind) then
		return ("No %s can be combined yet."):format(kind.name:lower())
	end
	local shelves = CombineStation.shelvesFor(kindKey)
	if #shelves == 0 then
		return ("No %s crate is stocked yet, so there is nothing to win."):format(kind.one)
	end
	if not chestKey or not tier then
		return "Pick a rarity to combine."
	end
	local climbable = CombineStation.tiersFor(chestKey)
	if not table.find(climbable, tier) then
		-- Either the top of the shelf, or a tier it does not stock at all.
		-- Both mean the same thing to the player and it is the honest one.
		return "There is nothing better than that on this shelf yet."
	end
	local need = Config.COMBINE.need
	local have = CombineStation.countAt(state, kindKey, tier)
	if have < need then
		return ("Need %d more spare %s."):format(need - have, tier)
	end
	return nil
end

-- The odds, printed, from the one table the server rolls with.
--
-- NOTHING REQUIRES THIS -- a combine is an in-game reward for in-game items
-- and no crate here carries a price in any currency, so there is no paid
-- random outcome to disclose. It is drawn for the reason the crate odds are:
-- being outside the regulation is not a reason to stop, it is the reason it
-- costs nothing to comply with the spirit of it. And it is the SERVER'S own
-- numbers rather than a second copy, because two implementations of one
-- probability are two things that can disagree.
function CombineStation.oddsRows()
	local rows = {}
	local order = Config.RARITY_ORDER
	for steps = 1, #order - 1 do
		local weight = Config.COMBINE.odds[steps]
		if weight then
			table.insert(rows, { steps = steps, weight = weight })
		end
	end
	return rows
end

function CombineStation.oddsText(): string
	local parts = {}
	for _, row in ipairs(CombineStation.oddsRows()) do
		table.insert(parts, ("%d%% +%d"):format(row.weight, row.steps))
	end
	return table.concat(parts, "   ")
end

-- ============================================================
-- THE BUILD
-- ============================================================

-- The only function here that touches a CFrame, and therefore the only one
-- the offline suite never calls.
--
-- NOTHING COLLIDES, ANSWERS A QUERY OR CASTS A SHADOW, which is the rule the
-- whole of `NeighborhoodService` keeps: a chase runs through the street
-- furniture, and a machine a thief could hide behind would be cover nobody
-- bought. `Focus` is the one part anything reaches for, and it is invisible
-- -- a known reference point rather than whichever part `FindFirstChild`
-- happens to return, which is the call the wheelie bin's `Hatch` already
-- makes and the fault four `Finial`s on a castle already paid for.
function CombineStation.build(at: CFrame, groundY: number, parent: Instance)
	local model = Instance.new("Model")
	model.Name = "CombineStation"

	local base = at * CFrame.new(0, groundY, 0)
	for _, spec in ipairs(CombineStation.boxes()) do
		local part = LowPoly.part(model, spec.name,
			Vector3.new(spec.sx, spec.sy, spec.sz),
			base * CFrame.new(spec.x, spec.y, spec.z),
			spec.colour, spec.material)
		if spec.shape == "ball" then
			part.Shape = Enum.PartType.Ball
		end
	end

	local focus = Instance.new("Part")
	focus.Name = "Focus"
	focus.Size = Vector3.new(1, 1, 1)
	focus.CFrame = base * CFrame.new(0, (PLINTH_TOP + BODY_TOP) / 2, 0)
	focus.Anchored = true
	focus.CanCollide = false
	focus.CanQuery = false
	focus.CastShadow = false
	focus.Transparency = 1
	focus.Parent = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CombinePrompt"
	prompt.ActionText = "Combine"
	prompt.ObjectText = "Piggy Press"
	prompt.HoldDuration = CombineStation.PROMPT_HOLD
	prompt.MaxActivationDistance = CombineStation.PROMPT_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Parent = focus
	-- SETTING THE KIND AND SETTING THE STYLE ARE ONE CALL, which is what
	-- stops a prompt carrying a kind and still drawing Roblox's grey pill --
	-- two lines at a call site is two chances to write one of them, and the
	-- mailbox and the gate jam both shipped that way.
	--
	-- AND IT IS LOUD WHEN THE ROW IS MISSING. `Config.promptStyle` falls back
	-- to `collect` for a kind it does not know, so an unapplied `PROMPTS`
	-- row is a machine wearing a gold BANK COINS card -- which works and lies.
	if not (Config.PROMPTS :: any)[CombineStation.PROMPT_KIND] then
		warn(("[CombineStation] Config.PROMPTS.%s is missing, so the prompt will"
			.. " draw the collect card. Add the row."):format(CombineStation.PROMPT_KIND))
	end
	Config.setPromptKind(prompt, CombineStation.PROMPT_KIND)

	-- THE NAME PLATE, and it is a BillboardGui rather than type on the
	-- fascia for the three reasons the shop plaques record: a face painted on
	-- the frontage is edge-on from the direction anybody walks, it shrinks
	-- with distance, and thin light type blooms in full sun. Not
	-- `AlwaysOnTop` -- a name that punches through its own machine reads as a
	-- HUD element -- and capped, so eight of these could never be a wall of
	-- text over the world.
	local plateAnchor = Instance.new("Part")
	plateAnchor.Name = "Plate"
	plateAnchor.Size = Vector3.new(1, 1, 1)
	plateAnchor.CFrame = base * CFrame.new(0, CombineStation.boundsFromBoxes().height + 1.8, 0)
	plateAnchor.Anchored = true
	plateAnchor.CanCollide = false
	plateAnchor.CanQuery = false
	plateAnchor.CastShadow = false
	plateAnchor.Transparency = 1
	plateAnchor.Parent = model

	local plate = Instance.new("BillboardGui")
	plate.Name = "NamePlate"
	plate.Adornee = plateAnchor
	plate.Size = UDim2.new(0, 260, 0, 64)
	plate.AlwaysOnTop = false
	plate.LightInfluence = 0
	plate.MaxDistance = CombineStation.PLATE_DISTANCE
	plate.Parent = plateAnchor

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 38)
	title.Font = Enum.Font.FredokaOne
	title.Text = "PIGGY PRESS"
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 247, 232)
	title.Parent = plate
	-- CONTEXTUAL, NEVER `Border`. A border stroke outlines a label's
	-- invisible RECTANGLE, which over a drawing is a floating box; the
	-- default strokes the character itself. Two words' difference between a
	-- readout and a rectangle, which the rob badge and the event chip both
	-- record.
	local titleStroke = Instance.new("UIStroke")
	titleStroke.Thickness = 3
	titleStroke.Color = Color3.fromRGB(41, 32, 27)
	titleStroke.Parent = title

	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.new(0, 0, 0, 36)
	sub.Size = UDim2.new(1, 0, 0, 24)
	sub.Font = Enum.Font.GothamBold
	sub.Text = ("%d SPARES IN, ONE BETTER OUT"):format(Config.COMBINE.need)
	sub.TextScaled = true
	sub.TextColor3 = Color3.fromRGB(255, 203, 61)
	sub.Parent = plate
	local subStroke = Instance.new("UIStroke")
	subStroke.Thickness = 2.5
	subStroke.Color = Color3.fromRGB(41, 32, 27)
	subStroke.Parent = sub

	model.Parent = parent
	return model, prompt
end

return CombineStation
