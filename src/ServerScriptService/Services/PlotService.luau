--!strict
--[[
	PlotService

	Owns the pool of plots: builds them, hands one to each arriving player,
	and wipes it when they leave.

	Plots are generated in code rather than built by hand in Studio. That
	keeps the whole layout in source control and means changing the grid is
	a one-line edit instead of an afternoon of dragging parts.

	The piggy bank itself lives in PiggyBank.luau; this file only decides
	where the plots go and who owns which one.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PiggyBank = require(script.Parent.PiggyBank)
local GuardDog = require(script.Parent.GuardDog)
-- Geometry, in Shared because the shop renders these too.
local House = require(ReplicatedStorage.Shared.House)
local Decor = require(ReplicatedStorage.Shared.Decor)
local SoundKit = require(ReplicatedStorage.Shared.SoundKit)
local GrassTuft = require(ReplicatedStorage.Shared.GrassTuft)
-- The ladder a player stands against a fence. Shared geometry rather than a
-- second copy here, for the reason House and Decor live in Shared: the shop
-- renders the real item, and a near-identical copy drifts the first time
-- either is touched.
local ThiefModel = require(ReplicatedStorage.Shared.ThiefModel)

local PlotService = {}

export type Plot = {
	index: number,
	model: Model,
	base: Part,
	-- Position AND facing. Anything rebuilt after construction (the fence,
	-- the spawn point) has to work from this, not from base.Position, or it
	-- comes back unrotated on the far row.
	cframe: CFrame,
	piggy: PiggyBank.Refs,
	dog: GuardDog.Dog,
	fence: Folder,
	-- Which tier is standing. Kept here rather than re-derived from the
	-- geometry because the ladder has to ask whether this fence is one you
	-- could have jumped, and reading a height back off a barrier would be a
	-- second answer to a question `Config.FENCE_TIERS` already answers.
	fenceLevel: number,
	house: Model?,
	decor: Model?,
	-- THE GARDEN: a border along the fence, a path up to the pig, and boxes
	-- under the windows. Three models rather than one, because they are
	-- rebuilt on three different events -- the border follows the FENCE, the
	-- boxes follow the HOUSE, and the path follows neither.
	border: Model?,
	gardenPath: Model?,
	windowBoxes: Model?,
	-- WHAT IS EQUIPPED, HELD ON THE PLOT FOR THE REASON `trophies` IS.
	--
	-- `buildFence` and `setHouseLevel` both destroy geometry the garden hangs
	-- on, so both have to put it back -- and neither is called from a place
	-- that knows what the owner has equipped. Passing it to them would be two
	-- more positional arguments on two functions with several callers each,
	-- which is the trap `setDecor` already refused. Sticky here, every
	-- existing caller repaints correctly for free.
	garden: any?,
	-- The skin the pig is wearing, so the TOPIARY can be clipped in it.
	--
	-- Written by `applySkin` and by nothing else, so it cannot disagree with
	-- what the animal is actually painted -- the same single-writer rule that
	-- keeps `decorPlaced` honest.
	skinKey: string?,
	-- Two rows, not one. A single TextScaled label holding both the name and
	-- the boasts shrank the name to fit whatever the boasts happened to be, so
	-- the most important word on the board was the one that moved.
	signLabel: TextLabel,
	signBoast: TextLabel,
	-- THE PAID MARK, HELD ON THE PLOT RATHER THAN PASSED IN.
	--
	-- `updateSign` has four callers across four services, so a fifth
	-- positional argument would be four chances to leave it out -- and a
	-- missing argument reads as nil, which means NOT VIP, silently, on a
	-- sign nobody would think to check. That is exactly the shape of the
	-- `"LockLevel"` bug: an interface with no compiler behind it.
	--
	-- Sticky on the plot instead, so every existing caller repaints it
	-- correctly for free and only `setSignPass` and `release` can change it.
	signWord: string?,
	signColour: Color3?,
	-- The mailbox flag, and the prompt that opens what is in it. Held by
	-- REFERENCE from the build rather than looked up by name, because a plot
	-- is one flat model and `FindFirstChild` on a repeated name returns the
	-- first one -- the castle's four finials and the wheelie bin's pair of
	-- lids are the same trap.
	-- OPTIONAL, BECAUSE A SHOP HAS NO DAILY. `buildShopPlot` is a second
	-- builder returning the same shape, and a shop plot nobody can move into
	-- has nobody to hand a reward to -- so it gets no mailbox and every
	-- reader here guards. Widening a type finds every place that quietly
	-- assumed the narrow one, which is the lesson `Target = Player |
	-- Resident` already paid for.
	mailFlag: BasePart?,
	mailPrompt: ProximityPrompt?,
	-- THE DOORSTEP CRATE. Held the same way and for the same reason: a plot
	-- is one flat model, so a part looked back up by name is whichever the
	-- builder happened to make first.
	--
	-- `crateParts` is everything that has to appear and disappear together
	-- and `crateTint` is the subset painted in the CHEST'S own colour, so a
	-- Piggy Classics on the step is pink and a Dress-Up Crate is purple
	-- before anybody reads a word. Two lists rather than one walk of the
	-- folder, because the wood must never take the chest's colour.
	crateParts: { BasePart }?,
	crateTint: { BasePart }?,
	cratePrompt: ProximityPrompt?,
	-- THE TROPHY SHELF'S NUMBERS, HELD ON THE PLOT RATHER THAN PASSED IN.
	--
	-- Four of the lawn ornaments are TROPHIES, and what they are shaped
	-- like is a function of what their owner has done -- a pig per skin
	-- robbed, a bar per doubling of the haul. `setDecor` has five callers
	-- across four services, so a fifth positional argument would be five
	-- chances to leave it out, and a missing one reads as nil: an EMPTY
	-- case, silently, on a lawn nobody would think to check.
	--
	-- Sticky here instead, so every existing caller repaints correctly for
	-- free and only `setTrophyState` and `release` can change it. That is
	-- exactly the decision `signWord` records one field up, made a second
	-- time and for the same reason -- and it is the shape of the
	-- `"LockLevel"` bug avoided rather than repeated.
	trophies: any?,
	-- What is standing on the lawn right now, slot id -> item key.
	--
	-- Kept here rather than re-derived, for the reason `fenceLevel` is:
	-- `setTrophyState` has to rebuild the ornaments to change a trophy's
	-- shape, and reading the arrangement back off the geometry would be a
	-- second answer to a question `data.decor.placed` already answers
	-- exactly. Written by `setDecor` and by nothing else, so it cannot
	-- disagree with what is actually built.
	decorPlaced: { [string]: string }?,
	owner: Player?,
	-- The shop tab this plot is the inside of, or nil for an ordinary house.
	--
	-- It is what makes a plot UNCLAIMABLE -- `assign` skips anything carrying
	-- one -- and that is the whole of the supply floor: a plot no player can
	-- move into is a plot `ResidentService` is never asked to evict, so its
	-- resident stands there at every server population. See
	-- `Config.SHOPS` and `buildShopPlot`.
	shop: string?,
}

local plots: { Plot } = {}
local byPlayer: { [Player]: Plot } = {}
local plotsFolder: Folder

-- Registered by HeistService, which owns walkspeed state. PlotService builds
-- the fence and detects the crossing; it doesn't decide what that costs.
local fencePenaltyHandlers: { (Player, any, any) -> () } = {}

-- THE MAILBOX'S HANDLERS, DECLARED HERE RATHER THAN BESIDE THE FUNCTIONS
-- THAT REGISTER THEM -- AND THAT IS THE ELEVENTH TIME THIS FILE HAS PAID
-- FOR THAT LESSON.
--
-- `buildPlot` connects the prompt and walks this table, and it sits about
-- eighteen hundred lines ABOVE where the registry naturally belongs. A
-- `local` declared below a function that reads it is a nil GLOBAL to that
-- function -- Luau says nothing at compile time -- so the first press of a
-- mailbox would have thrown inside `ipairs(nil)`, naming a line that looks
-- fine. `KENNEL_X` did exactly this and took ten plots and every service
-- after them down with it.
--
-- Hoisting a constant to sit beside a RELATED one is not the same as
-- hoisting it above its READER, which is the half that keeps being missed.
local mailHandlers: { (Player, any) -> () } = {}

-- The doorstep crate's, hoisted for exactly the same reason and beside it
-- rather than beside the function that reads it: `buildPlot` connects the
-- prompt and walks this list, and a `local` declared below `buildPlot` is a
-- nil GLOBAL to it. Twelve instances of that in this project and one of
-- them took the whole server down.
local crateHandlers: { (Player, any) -> () } = {}

-- Filled in by ResidentService, which seats a neighbour on every plot nobody
-- is living on. A REGISTRY RATHER THAN A REQUIRE, and for the reason
-- `registerBounceVeto` and `SetService.registerPusher` already record:
-- ResidentService requires PlotService, so asking the other way round is a
-- cycle. This keeps PlotService's dependency list where it is and makes the
-- cycle impossible rather than merely absent today.
local claimHandlers: { (Plot, Player) -> () } = {}
local releaseHandlers: { (Plot) -> () } = {}

-- When each player may next be charged by a given fence, keyed
-- "<plot index>/<penalty label>".
--
-- A FENCE CHARGES ONCE PER CROSSING, AND WITHOUT THIS IT CHARGED PER FRAME.
-- `Touched` is not an entry event: it re-fires on every re-contact, and a
-- character resting against a part re-contacts it constantly. Measured on a
-- live rig standing in an electric fence's ClimbZone: 18 fires in 4 seconds.
--
-- That produced both halves of the bug at once. Eighteen notifications, and
-- eighteen calls to applySlow -- each of which re-stamped a 2.5-second stun,
-- so the stun never expired and the player was frozen for as long as they
-- were touching the fence. A stun is WalkSpeed 0 and JumpHeight 0, so they
-- could not walk out of the zone or jump off it: it renewed itself forever.
--
-- KEYED PER PLOT AND PER SOURCE, not per player. Per player alone would let a
-- thief cross a second neighbour's fence for free inside the window, and the
-- alley between two yards is 16 studs -- comfortably crossable in one. Per
-- source keeps the moat and the wire above it separate, so wading the water
-- cannot buy a free run at the fence behind it.
local fenceCooldown: { [Player]: { [string]: number } } = {}

-- Down about 30% when the ground lost its texture -- a material multiplies
-- Part.Color, so this had never been seen at its literal value until the
-- lawn went flat. See the note over GRASS in WorldService; the two move
-- together and this stays the lighter of the pair, because a mown lawn
-- should read as tended against the rougher world ground around it.
local LAWN = Color3.fromRGB(94, 128, 68)
local TRIM = Color3.fromRGB(196, 178, 148)
local POST = Color3.fromRGB(122, 88, 58)

-- Where the plot sign stands, in plot-local studs, and which way it is turned.
--
-- OUT ON THE VERGE, beyond the fence and beyond the moat, beside the driveway.
-- A sign is a thing to be read from the street, and inside the fence it spent
-- the whole late game behind barbed wire and then behind five studs of water.
--
-- The z is not a taste decision. Measured on a tier-5 plot, the front moat
-- runs z 26.1 to 31.1 with its outer bank to 32.1, broken only by the driveway
-- causeway at x -7.0 to +7.0. So the dry verge starts at 32.1 and the kerb is
-- at streetMetrics().driveFar, 44. Anything between those two is out of the
-- water at every tier; anything short of it is swimming the moment its owner
-- buys the fifth fence.
--
-- The x keeps it clear of two things: the causeway itself, which is the walk
-- from the street to the gate and must stay open, and the vergeL/vergeR decor
-- slots at (+/-9.5, 31). The board hangs left of its post, so a post at 16.2
-- puts the board across x 8.9 to 15.1 -- past the driveway edge at 6.5, and
-- five studs clear of the decor in z.
--
-- The yaw turns it a little toward the road it is addressed to.
local SIGN_SPOT = Vector3.new(12, 0, 36)

-- HOISTED ABOVE THE MAILBOX BLOCK BELOW, WHICH READS IT AT LOAD TIME.
--
-- `MAIL_YAW` is `-SIGN_YAW`, and a `local` declared below the line that reads
-- it is a nil GLOBAL there -- so this was `-nil` and threw while the module
-- was still loading, which takes PlotService, then Main, then every service
-- after it. Twelfth instance in this project, and the FIRST one caught by
-- pressing Play rather than by somebody reporting a dead game: a load-time
-- read cannot limp on the way a nil function call does, so it is total,
-- immediate, and names a line that looks perfectly fine.
local SIGN_YAW = 12

-- THE MAILBOX, MIRRORING THE SIGN ACROSS THE DRIVE.
--
-- Every constraint the sign is solved against applies here unchanged, so
-- the honest placement is the sign's own, negated. Restating them, because
-- the next person to move one of these will be reading whichever entry
-- they happen to open:
--
--   THE MOAT. On a tier-5 plot the front moat runs z 26.1 to 31.1 with its
--   outer bank to 32.1, broken only by the driveway causeway at x -7 to
--   +7. So anything on the verge either stands on the causeway or stands
--   past 32.1, and z 36 is past it at every tier. A mailbox that looked
--   right on a bare plot and stood in five studs of water the moment its
--   owner bought the fifth fence is exactly how the decoration slots got
--   this wrong the first time.
--
--   THE CAUSEWAY. x -7 to +7 is the walk from the street to the gate and
--   has to stay clear.
--
--   THE DECOR SLOTS. `vergeL` and `vergeR` sit at (-22, 31) and (22, 31),
--   so -12 is ten studs clear of the nearer one in x and five in z.
--
-- AND IT READS AS A PAIR, WHICH IS THE HALF THAT IS NOT ARITHMETIC. A sign
-- on one side of a drive and a mailbox on the other is what a street
-- actually looks like, and it costs nothing to get: the only free band was
-- always going to be this one.
local MAIL_SPOT = Vector3.new(-12, 0, 36)
-- Turned the same few degrees toward the road the sign is, mirrored. A box
-- square to the plot presents its side to everybody walking past.
--
-- DEGREES, like `SIGN_YAW`, and converted at every use. Storing one of
-- these pair in radians and the other in degrees is a 57x error that looks
-- like a placement mistake.
local MAIL_YAW = -SIGN_YAW

-- Where the mailbox stands, IN PLOT-LOCAL SPACE.
--
-- `buildPlot` authors everything at the plot's world POSITION with no
-- rotation and then turns the whole model with one `PivotTo` at the end, so
-- an offset written here is plot-local by construction and the far row's
-- half turn is carried for free. Anything that has to move a piece of this
-- LATER -- and the flag does, every time the daily state changes -- has to
-- compose against `plot.cframe` rather than remember a world CFrame taken
-- before that pivot ran.
local MAIL_BASE = CFrame.new(MAIL_SPOT.X, 0, MAIL_SPOT.Z)
	* CFrame.Angles(0, math.rad(MAIL_YAW), 0)

-- THE FLAG'S HINGE, AT ITS FOOT.
--
-- Turning a part about its own centre swings half of it into whatever it is
-- bolted to, which is what the guard dog's ears record. So the pivot is the
-- flag's BASE and the half-length is added back after the turn: 0 is
-- straight up, and a quarter turn lays it flat along the box with the foot
-- never moving.
--
-- DERIVED FROM `Decor` RATHER THAN RESTATED, WHICH IS THE OTHER HALF OF THE
-- BUG BELOW. The hinge offset and the flag's half-length are facts about the
-- mailbox's geometry and that geometry now lives in one place; a second copy
-- here is a second thing to keep in step with a box this file no longer
-- builds.
local MAIL_HINGE = MAIL_BASE
	* CFrame.new(0, -Config.PLOT_SIZE.Y / 2, 0)
	* Decor.MAILBOX_FLAG_HINGE
local MAIL_FLAG_HALF = Decor.MAILBOX_FLAG_HALF

-- WHERE THE DOORSTEP IS, AND IT IS DERIVED FROM THE HOUSE RATHER THAN
-- TYPED.
--
-- Every tier is seated by its FRONT wall on `Config.HOUSE_FRONT_LINE` --
-- that is what stops a Sky Castle standing on three decoration slots -- so
-- the front door is at plot-local z of minus that number on all nine, and
-- a crate placed off it follows a house that is ever re-seated. A pinned
-- number would describe the catalogue on the day somebody typed it, which
-- is exactly how the grove came to plant full-grown trees on people's
-- lawns.
--
-- x 0 IS THE ONE CLEAR COLUMN. The deepest lawn slots are lawnA..lawnD at
-- z -20, and their x offsets are -25, -8.5, 8.5 and 25 -- there is no slot
-- on the centre line, because that is the walk from the gate to the piggy.
-- So the front-centre approach to the door is the only strip of lawn where
-- nothing else can ever stand.
--
-- AND THE BAND IS 3.5 STUDS DEEP, WHICH IS THE WHOLE CLEARANCE BUDGET.
-- `HOUSE_FRONT_LINE`'s own note derives it: the deepest ornament that can
-- stand in the z -20 row reaches back to -24.5, and the wall is at -28. A
-- lid, which oversails by 0.17 a side, is what reaches both ends.
--
-- MEASURED ON THE BUILT PLOT rather than solved on paper, because the two
-- ends of a 3.5-stud band are not both slack: at 1.7 the lid stood 0.03
-- off the house wall and 0.13 off the ornament band, which is inside the
-- noise on the tight side. At 1.55 it SINKS 0.12 into the wall -- this
-- project's coplanar convention, where anything standing on something
-- sinks about a tenth of a stud into it -- and the whole 0.28 of clearance
-- goes to the side that has ornaments on it.
--
-- ANYTHING THAT DEEPENS AN ORNAMENT HAS TO RE-DERIVE BOTH NUMBERS, not
-- just the one `HOUSE_FRONT_LINE`'s own note names.
local CRATE_SPOT = Vector3.new(0, 0, -Config.HOUSE_FRONT_LINE + 1.55)
local CRATE_W = 3.0
local CRATE_H = 2.6

-- Up means there is something to collect. One writer, called from the build
-- and from `setMail`, so the two can never disagree about what down is.
local function seatMailFlag(plot: any, up: boolean)
	plot.mailFlag.CFrame = plot.cframe * MAIL_HINGE
		* CFrame.Angles(0, 0, if up then 0 else math.rad(-82))
		* CFrame.new(0, MAIL_FLAG_HALF, 0)
end
-- ============================================================
-- CONSTRUCTION
-- ============================================================

-- Where a plot sits AND which way it faces.
--
-- Everything on a plot -- sign, gate, snout, spawn point -- is authored with
-- +Z as its front. The far row is yawed 180 degrees so both rows face the
-- road rather than one row showing the street its back fence. That yaw is the
-- only place in the codebase that has to know the layout has two sides.
local function plotCFrame(index: number): CFrame
	local perRow = Config.PLOTS_PER_ROW
	local row = math.floor((index - 1) / perRow) -- 0 = near side, 1 = far side
	local col = (index - 1) % perRow

	-- Asked of Config rather than computed here, so this file and the scenery
	-- that lines up against it cannot drift. The row briefly had a hole in the
	-- middle for the town square and a column was NOT its own position; it is
	-- continuous again, and the one place that knows is Config.
	local x = Config.plotColumnX(col)
	local z = (if row == 0 then -0.5 else 0.5) * Config.STREET_SPACING
	local yaw = if row == 0 then 0 else math.pi

	return CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
end

-- WHERE THE KENNEL STANDS, in plot-local studs with +Z toward the street.
--
-- On `Config.DECOR_SLOTS`' own grid: the column at x 25 and the row at z 16,
-- which is the front-right corner and the mirror of the `lawnI` slot. The
-- yaw turns the doorway across the lawn rather than at the front fence --
-- see the GuardDog.build call in `buildPlot` for what that was costing.
--
-- **DECLARED HERE RATHER THAN DOWN WITH THE FENCES, AND THAT IS THE TENTH
-- FORWARD REFERENCE THIS PROJECT HAS HIT.** These three shipped 282 lines
-- BELOW `buildPlot`, which reads them -- so to that function they were nil
-- GLOBALS, and Luau says nothing about it. The failure was not subtle and it
-- was not local either: `CFrame.Angles(0, nil, 0)` threw "Argument 2 missing
-- or nil" inside `buildPlot`, which took `PlotService.start` and then the
-- whole of `Main` with it. Ten plots, every service after them, and no
-- "Ready" in the log at all.
--
-- Same shape as `glowPart`, `makeModelIcon` and `Config.LAWN_LIFT` before it:
-- the message names a line that looks fine and nothing points at the
-- declaration. When something reads nil and the error names nothing useful,
-- check declaration order first.
local KENNEL_X = 25
local KENNEL_Z = 16
local KENNEL_YAW = math.rad(-90)

local function buildPlot(index: number): Plot
	local cf = plotCFrame(index)
	local origin = cf.Position

	local model = Instance.new("Model")
	model.Name = "Plot" .. index

	-- Stone trim sits slightly proud of the lawn so each plot reads as a
	-- separate property rather than a patch of the same field.
	--
	-- IT RINGS THE WHOLE YARD, HOUSE INCLUDED, not just the front lawn. It
	-- used to be PLOT_SIZE + 4, a 52-stud square centred on the piggy, which
	-- stopped dead at the back of the lawn -- so a plot read as a bordered
	-- garden with an unbordered field of grass stuck on the back of it, and
	-- the border was exactly the thing saying where one property ended and the
	-- next began. It now runs from the pavement to two studs behind the back
	-- fence, which is the same rectangle buildFence encloses.
	--
	-- Sized off YARD_DEPTH rather than off the slab. Those were the same
	-- number until the yard was lengthened to hold the house, and this file
	-- already has one bug from measuring the wrong one -- the grove that
	-- planted full-grown trees on people's lawns.
	local TRIM_EDGE = 2
	local trimFront = Config.PLOT_SIZE.Z / 2 + TRIM_EDGE
	local trimBack = Config.YARD_DEPTH + TRIM_EDGE

	local trim = Instance.new("Part")
	trim.Name = "Trim"
	trim.Size = Vector3.new(
		Config.PLOT_SIZE.X + TRIM_EDGE * 2,
		Config.PLOT_SIZE.Y + 0.4,
		trimFront + trimBack)
	-- Authored around `origin` like everything else here; the PivotTo at the
	-- end turns the far row. Safe to resize because the model's PrimaryPart is
	-- the Base, so the pivot does not move when this part's bounds change.
	trim.Position = origin + Vector3.new(0, -0.4, (trimFront - trimBack) / 2)
	trim.Anchored = true
	trim.Material = Enum.Material.Concrete
	trim.Color = TRIM
	trim.TopSurface = Enum.SurfaceType.Smooth
	trim.Parent = model

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Config.PLOT_SIZE
	base.Position = origin
	base.Anchored = true
	-- The ground surface, from the one pair in Config that the whole street
	-- reads. A MaterialVariant naming something MaterialService does not hold
	-- falls back to the base material, so the worst either line can do is
	-- render the plain ground.
	base.Material = Config.GRASS_MATERIAL.material
	base.MaterialVariant = Config.GRASS_MATERIAL.name
	base.Color = LAWN
	base.TopSurface = Enum.SurfaceType.Smooth
	base.Parent = model

	-- The back of the yard, between the plot slab and the back fence.
	--
	-- The fence now encloses far more ground than the 48x48 slab covers, and
	-- without this the far half of a player's own garden is darker world
	-- ground -- one fenced yard in two obviously different greens. Butts up
	-- against the slab rather than overlapping it: two grass surfaces at the
	-- same height would z-fight along the seam.
	local yardDepth = Config.YARD_DEPTH - Config.PLOT_SIZE.Z / 2
	local yard = Instance.new("Part")
	yard.Name = "Yard"
	-- SAME WIDTH AS THE LAWN, so the stone border either side is a constant
	-- two studs from the pavement to the back fence. At 51.2 -- the full fence
	-- interior -- the grass grew 1.6 studs wider at the seam behind the piggy
	-- and the visible trim shrank from 2 studs to 0.4 at the same line, which
	-- reads as the border running out rather than as a wider garden. The strip
	-- between this grass and the fence is stone now, exactly as it already is
	-- along the front lawn.
	yard.Size = Vector3.new(Config.PLOT_SIZE.X, Config.PLOT_SIZE.Y, yardDepth)
	yard.Position = origin + Vector3.new(0, 0, -(Config.PLOT_SIZE.Z / 2 + yardDepth / 2))
	yard.Anchored = true
	-- Same surface as the front lawn, for the same reason it is the same
	-- COLOUR as the front lawn: one fenced yard in two different greens is
	-- exactly the seam this part was added to close.
	yard.Material = Config.GRASS_MATERIAL.material
	yard.MaterialVariant = Config.GRASS_MATERIAL.name
	yard.Color = LAWN
	yard.TopSurface = Enum.SurfaceType.Smooth
	yard.Parent = model

	-- The grass standing up out of both of them.
	--
	-- BUILT BEFORE THE `PivotTo` AT THE END OF THIS FUNCTION, which is what
	-- makes the far row correct for nothing: every tuft is authored in the
	-- same pre-rotation frame as the lawn it stands on, and the single turn
	-- at the end carries them along with everything else. Scattered ON the
	-- two parts rather than over a rectangle for the same reason -- a part
	-- carries its own frame, so this cannot get the rotation wrong.
	--
	-- NO VETO IS PASSED. The two things a lawn could have grass growing out
	-- of are the driveway and a tier-5 moat, and neither reaches this grass.
	--
	-- The DRIVEWAY is derived AND measured: `buildDriveway` runs from
	-- `driveNear` to `driveFar` in PLOT-LOCAL z, so it starts at 25.6 against
	-- a slab that ends at PLOT_SIZE.Z / 2, which puts the whole drive in
	-- front of the lawn rather than on it. Counted live across every plot at
	-- zero tufts standing on a driveway slab.
	--
	-- The MOAT is derivation only and is recorded as such under "Not yet
	-- verified": it takes the fence RING, which is outboard of this 64-wide
	-- grass with the stone trim in between, and nobody in a solo session owns
	-- a tier-5 fence for it to be measured against.
	--
	-- Its own folder so the count is one line to read and the whole lot is
	-- one line to remove.
	local grass = Instance.new("Folder")
	grass.Name = "Grass"
	grass.Parent = model
	GrassTuft.scatterOn(base, grass, index * 2)
	GrassTuft.scatterOn(yard, grass, index * 2 + 1)

	local piggy = PiggyBank.build(origin, model)

	-- The plot sign: a hanging shingle, off to the right of the gate.
	--
	-- It used to be an eleven-stud plank on a stick in the dead centre of the
	-- front edge, which put the least interesting object on the plot directly
	-- between the street and the piggy bank -- the one thing everybody is
	-- actually looking at, and the line everybody walks. Off to one side it
	-- stops blocking that and starts reading as a house sign rather than a
	-- billboard.
	--
	-- OUT ON THE VERGE, past the moat. See SIGN_SPOT for the measured numbers
	-- that decide exactly where "past the moat" is -- it is a narrow band, and
	-- the obvious spots on either side of it are underwater at tier 5.
	--
	-- Authored around `origin` and yawed in place, because the far row of
	-- plots is turned 180 degrees by the PivotTo at the end of this function
	-- and a sign built from raw positions comes back facing its own back
	-- fence.
	local signCF = CFrame.new(origin)
		* CFrame.new(SIGN_SPOT.X, 0, SIGN_SPOT.Z)
		* CFrame.Angles(0, math.rad(SIGN_YAW), 0)
	-- The VERGE, which is a different floor from the lawn.
	--
	-- A plot is three heights: the lawn is the top of the plot slab (+0.5),
	-- the driveway is paving on the world ground (-0.28), and the verge is
	-- bare world ground (-0.5). The sign used to stand on the lawn and read
	-- +0.5; moving it outside the fence without moving this number would have
	-- left the whole thing hovering a full stud, which is exactly how the
	-- decorations got it wrong the first time.
	local baseY = -Config.PLOT_SIZE.Y / 2

	local function signPart(name: string, size: Vector3, at: CFrame, colour: Color3,
		material: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = at
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Material = material
		p.Color = colour
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	-- The board hangs at local x = 0 and the post stands off to its OUTER
	-- side, away from the drive.
	--
	-- Inner side first, and the 20-degree yaw swung the pole toward the
	-- street: from the pavement it stood in front of the board it was holding
	-- up, covering the first third of the name. Out here it sits behind the
	-- board instead, and the board still turns to face the drive.
	--
	-- The anchor positions the BOARD, not the post -- the board is the part
	-- that has to clear the decor slots and stay inside the fence.
	signPart("SignPlinth", Vector3.new(2.4, 0.6, 2.4),
		signCF * CFrame.new(4.2, baseY + 0.3, 0), Color3.fromRGB(196, 190, 176), Enum.Material.Slate)
	signPart("SignPost", Vector3.new(0.7, 9.0, 0.7),
		signCF * CFrame.new(4.2, baseY + 5.1, 0), POST, Enum.Material.Wood)
	signPart("SignCap", Vector3.new(1.1, 0.5, 1.1),
		signCF * CFrame.new(4.2, baseY + 9.85, 0), POST, Enum.Material.Wood)
	signPart("SignArm", Vector3.new(7.3, 0.45, 0.45),
		signCF * CFrame.new(0.55, baseY + 9.35, 0), POST, Enum.Material.Wood)
	-- The brace that stops the arm reading as a plank stuck through a pole.
	signPart("SignBrace", Vector3.new(2.4, 0.3, 0.3),
		signCF * CFrame.new(3.3, baseY + 8.5, 0) * CFrame.Angles(0, 0, math.rad(-40)),
		POST, Enum.Material.Wood)
	for _, x in ipairs({ -2.4, 2.4 }) do
		signPart("SignLink", Vector3.new(0.22, 0.95, 0.22),
			signCF * CFrame.new(x, baseY + 8.9, 0), Color3.fromRGB(126, 130, 136), Enum.Material.Metal)
	end

	-- Frame and panel are separate parts so the panel can stand proud of the
	-- frame. Flush would put two faces at the same depth, which is the
	-- coplanar flicker this codebase has now hit three times.
	signPart("Sign", Vector3.new(6.2, 4.2, 0.35),
		signCF * CFrame.new(0, baseY + 6.35, 0), Color3.fromRGB(96, 64, 42), Enum.Material.WoodPlanks)
	local panel = signPart("SignPanel", Vector3.new(5.5, 3.5, 0.16),
		signCF * CFrame.new(0, baseY + 6.35, 0.2), Color3.fromRGB(244, 236, 218),
		Enum.Material.SmoothPlastic)

	local surface = Instance.new("SurfaceGui")
	-- Roblox's "Front" face is -Z. The board faces out toward the street on
	-- +Z, so that's Back.
	surface.Face = Enum.NormalId.Back
	surface.CanvasSize = Vector2.new(550, 350)
	surface.AlwaysOnTop = false
	-- Unlit, so the board stays readable at dusk. It is the one thing on the
	-- plot whose whole job is being read from the pavement.
	surface.LightInfluence = 0
	surface.Parent = panel

	local label = Instance.new("TextLabel")
	label.Name = "Owner"
	label.Size = UDim2.new(1, -30, 0.4, 0)
	label.Position = UDim2.new(0, 15, 0.05, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	-- NEVER write TextWrapped next to TextScaled. Setting TextWrapped = false
	-- after TextScaled = true silently turns TextScaled back OFF and drops the
	-- label to the default TextSize of 8 -- measured, and on a board this size
	-- it renders as a faint smudge. TextScaled implies wrapping; the way to
	-- stop text overflowing is to give the row enough height for the lines it
	-- will wrap into, which is what the boast row below does.
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(70, 46, 30)
	label.Text = "EMPTY PLOT"
	label.Parent = surface

	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.Size = UDim2.new(0.62, 0, 0, 4)
	rule.Position = UDim2.new(0.19, 0, 0.5, 0)
	rule.BackgroundColor3 = Color3.fromRGB(178, 150, 112)
	rule.BorderSizePixel = 0
	rule.Parent = surface

	local boast = Instance.new("TextLabel")
	boast.Name = "Boasts"
	-- Tall enough for the two lines a full boast list wraps into. At one row's
	-- height the second line fell off the bottom of the board and a maxed-out
	-- player's sign read "12*  ·  Neon Tower  ·" with the skin missing.
	boast.Size = UDim2.new(1, -14, 0.36, 0)
	boast.Position = UDim2.new(0, 7, 0.545, 0)
	boast.BackgroundTransparency = 1
	boast.Font = Enum.Font.GothamBold
	boast.TextScaled = true
	boast.TextColor3 = Color3.fromRGB(150, 104, 44)
	boast.Text = ""
	boast.Parent = surface

	-- ------------------------------------------------------- THE MAILBOX
	--
	-- WHAT IT IS FOR: the daily reward used to be reachable exactly once a
	-- session. The board opens itself 1.5 seconds after joining and there
	-- was no other route to it, so a player who closed it without claiming
	-- had lost the day -- with nothing on screen to say the reward was
	-- still sitting there. This is the way back, and the FLAG is the way
	-- you know to walk over.
	--
	-- Built with `signPart`, which means non-colliding and non-querying like
	-- everything else out here: the verge is ground a thief runs across and
	-- a dog patrols beside, and nothing decorative may body-block either.
	-- THE PLACEMENT IS `MAIL_BASE` ITSELF, AND WRITING IT OUT A SECOND TIME
	-- HERE IS WHAT PUT THE FLAG 44 DEGREES OFF THE BOX IT IS BOLTED TO.
	--
	-- This used to compose its own `CFrame.Angles(0, MAIL_YAW, 0)` -- MAIL_YAW
	-- RAW, which is DEGREES, fed to a function that takes RADIANS. -12
	-- radians is 32.45 degrees once it has wrapped, so the post, the body,
	-- the lid and the door all stood at 32.45 while the flag -- seated
	-- through `MAIL_HINGE`, which does say `math.rad` -- stood at -12.
	-- Measured on the built street: `MailBody` yaw 32.45, `MailFlag` yaw
	-- -12.00, on every plot, since the day it was written.
	--
	-- The comment above `MAIL_YAW` predicted this exactly -- *"storing one of
	-- these pair in radians and the other in degrees is a 57x error that
	-- looks like a placement mistake"* -- which is the point: a warning
	-- beside a constant does not stop a SECOND expression of the same
	-- placement being written three hundred lines away. The cure is not a
	-- better comment, it is having one expression. `MAIL_BASE` is that
	-- expression and this reads it.
	local mailCF = CFrame.new(origin) * MAIL_BASE

	-- THE GEOMETRY IS `Decor.buildMailbox` NOW, because the street grew a
	-- second mailbox and two hand-built ones is the copy that drifts. The
	-- kerbside one is scenery with no prompt behind it; this is the one the
	-- daily reward comes out of, and they have to be the same object or the
	-- flag stops being a tell and starts being decoration somebody has to
	-- learn to tell apart.
	--
	-- Parented flat into the plot model exactly as `signPart` did, and held
	-- by REFERENCE -- a plot is one flat model, so a part looked back up by
	-- name is whichever the builder happened to make first.
	local mail = Decor.buildMailbox(mailCF * CFrame.new(0, baseY, 0), model)
	local mailBody = mail.body
	local flag = mail.flag

	-- The prompt sits on the BODY rather than on the flag: the flag moves,
	-- and a prompt measures its range to the part's centre, so a reach that
	-- changed when the flag went down would be a range bug nobody would
	-- think to look for.
	local mailPrompt = Instance.new("ProximityPrompt")
	mailPrompt.Name = "MailPrompt"
	mailPrompt.ActionText = "Check the Post"
	mailPrompt.ObjectText = "Daily Reward"
	mailPrompt.HoldDuration = 0
	mailPrompt.MaxActivationDistance = 10
	mailPrompt.RequiresLineOfSight = false
	-- Off until there is something in it. See `setMail`.
	mailPrompt.Enabled = false
	Config.setPromptKind(mailPrompt, "post")
	mailPrompt.Parent = mailBody

	-- --------------------------------------------------- THE DOORSTEP CRATE
	--
	-- WHAT IT IS FOR: day seven of the daily ladder is the only rung that
	-- pays something PLAYING cannot -- a free crate, which lands on the
	-- permanent cosmetic track -- and it was opened inside the claim, so the
	-- reveal fired while the player was still looking at the daily board.
	-- The one reward on that ladder worth coming back for had no moment of
	-- its own. It is a delivery now: it stands on the step, it can be seen
	-- from the pavement, and opening it is a walk and a press.
	--
	-- Built hidden and never destroyed and rebuilt, the same call the tier-0
	-- dog makes: a crate arrives and goes about once a week, and a model
	-- that is only ever repainted cannot be half-built when somebody looks.
	local crateCF = CFrame.new(origin)
		* CFrame.new(CRATE_SPOT.X, 0, CRATE_SPOT.Z)
	local crateFloor = baseY + Config.PLOT_SIZE.Y

	local crateParts: { BasePart } = {}
	local crateTint: { BasePart } = {}
	local function cratePart(name: string, size: Vector3, at: CFrame,
		colour: Color3, tinted: boolean): BasePart
		local part = signPart(name, size, at, colour, Enum.Material.SmoothPlastic)
		table.insert(crateParts, part)
		if tinted then
			table.insert(crateTint, part)
		end
		return part
	end

	-- SUNK 0.1 INTO THE LAWN, which is this project's coplanar convention
	-- rather than a nudge: a box whose bottom face lands exactly on the
	-- grass shares that plane over its whole footprint, and two surfaces at
	-- one depth is the strobing seam the house rebuild fixed at a hundred
	-- sites.
	local body = cratePart("CrateBody",
		Vector3.new(CRATE_W, CRATE_H, CRATE_W),
		crateCF * CFrame.new(0, crateFloor + CRATE_H / 2 - 0.1, 0),
		Color3.fromRGB(176, 134, 88), false)

	-- The strapping, in the chest's own colour and sunk into the body for
	-- the same reason the mailbox door is. Two bands rather than one so the
	-- box reads as CRATED rather than as painted.
	for i, y in ipairs({ 0.72, 1.86 }) do
		cratePart(("CrateBand%d"):format(i),
			Vector3.new(CRATE_W + 0.08, 0.34, CRATE_W + 0.08),
			crateCF * CFrame.new(0, crateFloor + y - 0.1, 0),
			Color3.fromRGB(236, 138, 178), true)
	end

	-- The lid, oversailing the body a little so it reads as a lid rather
	-- than as the top of the box.
	cratePart("CrateLid",
		Vector3.new(CRATE_W + 0.34, 0.42, CRATE_W + 0.34),
		crateCF * CFrame.new(0, crateFloor + CRATE_H - 0.28, 0),
		Color3.fromRGB(236, 138, 178), true)

	-- The label on the face turned toward the street, so it reads on the
	-- approach rather than only once somebody has walked round the box.
	cratePart("CrateLabel",
		Vector3.new(1.5, 1.0, 0.12),
		crateCF * CFrame.new(0, crateFloor + 1.3 - 0.1, CRATE_W / 2 - 0.05),
		Color3.fromRGB(244, 238, 224), false)

	local cratePrompt = Instance.new("ProximityPrompt")
	cratePrompt.Name = "CratePrompt"
	cratePrompt.ActionText = "Open the Crate"
	cratePrompt.ObjectText = "Doorstep Delivery"
	cratePrompt.HoldDuration = 0
	cratePrompt.MaxActivationDistance = 10
	cratePrompt.RequiresLineOfSight = false
	-- Off until there is one on the step. See `setCrate`.
	cratePrompt.Enabled = false
	Config.setPromptKind(cratePrompt, "crate")
	cratePrompt.Parent = body

	local fence = Instance.new("Folder")
	fence.Name = "Fence"
	fence.Parent = model

	model.PrimaryPart = base
	model.Parent = plotsFolder

	-- Yaw the whole plot into place. Everything above is authored front-to-+Z
	-- around `origin`, so a single pivot turns the far row's sign, gate and
	-- snout to face the street instead of the backdrop.
	model:PivotTo(cf)

	-- One dog per plot, built hidden at tier 0. Cheaper than spawning and
	-- destroying a model every time someone buys or rebirths away the upgrade,
	-- and it means the chase can start the instant an alarm fires.
	--
	-- Built AFTER the pivot on purpose: the dog caches its home as a world
	-- Vector3 and drives itself with PivotTo, so rotating it underneath that
	-- cache would leave it walking back to the wrong corner forever.
	-- Takes a CFrame, not a position: the kennel's +Z is its doorway, and the
	-- dog rests in front of it, so the whole arrangement has to be turned to
	-- face into the plot rather than out through the back fence.
	-- (14, 4) -> (26, 17), OUT TO THE FRONT-RIGHT CORNER.
	--
	-- On a 48-wide lawn that spot was near the edge; on a 64-wide one it is a
	-- third of the way in, standing between the piggy and the decoration ring
	-- with the dog napping in the middle of somebody's garden. The corner is
	-- also what buys the ninth decoration slot: the grid is four rows of four
	-- and the kennel holds exactly one of the sixteen positions, so putting it
	-- anywhere in the middle would have cost two.
	--
	-- AND THE DOORWAY FACED THE FRONT FENCE, WHICH IS WHY THE DOG KEPT
	-- WALKING THROUGH IT. The comment above says the arrangement is turned to
	-- face into the plot; nothing turned it. Kennel-local +Z is the doorway,
	-- the call carried no rotation, so the doorway pointed at plot +Z -- the
	-- street -- and `REST_OFFSET` put the dog 5.5 studs FURTHER that way,
	-- 7.15 at a Mastiff's scale. Measured: the rest spot landed at plot z
	-- 24.15 against a front fence at `PLOT_FRONT_LINE` 25.6, so a dog 9.9
	-- studs long stood bodily through its owner's fence WITHOUT MOVING, and
	-- `DOG_PATROL_RADIUS` of 8 then took it to z 32, six studs out on the
	-- pavement.
	--
	-- A quarter turn points the doorway at plot -X, across the lawn toward
	-- the piggy, and the rest spot goes with it: (17.85, 16) at Mastiff
	-- scale, 15.75 studs off the side fence and 9.6 off the front. It reads
	-- better as well as measuring better -- the dog now lies BROADSIDE to the
	-- street, which is the one angle a dog's silhouette works from and the
	-- rule every lawn ornament here already follows.
	--
	-- 25 rather than 26 puts the kennel on the decor grid's own column, and
	-- 16 rather than 17 on its own row, so it mirrors `lawnI` at (-25, 16)
	-- exactly. Measured at that spot, with the turn: 3.23 studs off the front
	-- fence, 3.85 off the side, and 1.84 clear of the deepest ornament that
	-- can stand in `lawnH` behind it.
	--
	-- The plot's own CFrame goes in as well, and it is not decoration: it is
	-- the frame `GuardDog` clamps a patrol against, so no radius can put a
	-- dog through a fence again. See `clampToYard`.
	local dog = GuardDog.build(
		cf * CFrame.new(KENNEL_X, 0, KENNEL_Z) * CFrame.Angles(0, KENNEL_YAW, 0),
		model, cf)

	local plot: Plot = {
		index = index,
		model = model,
		base = base,
		cframe = cf,
		piggy = piggy,
		dog = dog,
		fence = fence,
		fenceLevel = 0,
		house = nil,
		decor = nil,
		signLabel = label,
		signBoast = boast,
		mailFlag = flag,
		mailPrompt = mailPrompt,
		crateParts = crateParts,
		crateTint = crateTint,
		cratePrompt = cratePrompt,
		owner = nil,
	}
	-- SEATED AFTER THE TABLE EXISTS, not during the build, because
	-- `seatMailFlag` composes against `plot.cframe` -- which is the whole
	-- reason the flag can be moved again later without remembering a world
	-- CFrame taken before `PivotTo` ran.
	seatMailFlag(plot, false)
	-- Hidden until there is something in it, for the reason the tier-0 dog
	-- is hidden rather than absent: every reader here guards on the fields
	-- being present, and a nil is a crash rather than a missing feature.
	PlotService.setCrate(plot, nil)

	-- The press. Connected here, where `plot` exists, rather than in `start`
	-- -- there is nothing to look the plot back up by, and holding the
	-- reference is the same call the sign labels and the dog's nameplate
	-- make about names that repeat across one flat model.
	--
	-- THE SERVER RE-CHECKS THE OWNER. The client refuses somebody else's
	-- mailbox through `PROMPT_OWNER_ATTRIBUTE`, which is a courtesy to the
	-- reader; this is the part that is load-bearing, because `Enabled`
	-- written on a client is a fact about that client's screen and nothing
	-- else.
	mailPrompt.Triggered:Connect(function(who: Player)
		if who ~= plot.owner then
			return
		end
		for _, fn in ipairs(mailHandlers) do
			task.spawn(fn, who, plot)
		end
	end)

	-- The crate, on the same terms: the client refuses somebody else's
	-- through `PROMPT_OWNER_ATTRIBUTE` and THIS is the check that is
	-- load-bearing, because `Enabled` written on a client is a fact about
	-- that client's screen and nothing else.
	cratePrompt.Triggered:Connect(function(who: Player)
		if who ~= plot.owner then
			return
		end
		for _, fn in ipairs(crateHandlers) do
			task.spawn(fn, who, plot)
		end
	end)

	return plot
end

-- A SHOP'S INSIDE, BUILT AS A PLOT NOBODY CAN MOVE INTO.
--
-- See `Config.SHOPS` for why this exists at all: resident houses are seated
-- on UNCLAIMED plots, so the supply of robbable pigs runs out exactly as the
-- server fills up, and `LOSS_CAP` means player-versus-player robbing can
-- never take over from it at any population. Four shops are the floor that
-- removes the whole failure.
--
-- IT IS A PLOT RATHER THAN A NEW KIND OF THING, AND THAT IS THE ENTIRE
-- IMPLEMENTATION. Everything a robbery touches is keyed off a plot -- the
-- steal prompt, the rob badge, the published pile, the lock attribute, the
-- per-victim cooldown id, casing, the crack, the coin drain and the rap
-- sheet -- so a duck-compatible plot gets all of it for nothing and
-- `ResidentService` seats a shopkeeper on it with no new branch. The
-- alternative was a third Target kind in HeistService, which is nine
-- accessors with a plot-shaped hole under every one of them.
--
-- AND IT STAYED A PLOT WHEN THE PIG BECAME A VAULT, which is the whole of
-- what moving inside cost. What used to stand here was a paving apron with a
-- twelve-stud piggy bank on it; what stands here now is a floor, a
-- strongroom on the back wall and a board over it. Nothing about the plot
-- record changed, and `PiggyBank.buildVault` returns the same `Refs` the pig
-- did -- so the fill, the dial, the plaster, the alarm and the milestone are
-- the piggy's own functions running on different parts.
--
-- WHAT IT LEAVES OUT IS THE POINT AS MUCH AS WHAT IT KEEPS. No lawn, no
-- yard, no house, no garden, no fence and no dog: the vault stands on the
-- BACK wall, which faces the houses, so it is about 23 studs of carry from
-- the nearest drop-off against 53 between two houses. That makes a shop the
-- FAST, CHEAP, LOUD target -- nothing to get past, a smaller pig, an alarm
-- that brings the patrol rather than a defender -- and leaves a house the
-- slow, rich, quiet one. The fence folder and the tier-0 dog are still
-- built, empty and invisible, because `plot.fence` and `plot.dog` are read
-- in seven places across four services and a nil there is a crash rather
-- than a missing feature.
local function buildShopPlot(index: number, spec: any): Plot
	-- THE PLOT AND THE BUILDING SHARE ONE FRAME, TO THE STUD. `NeighborhoodService`
	-- stands the shell at exactly this position and yaw, so everything below
	-- is authored in the same coordinates `ShopFront` builds its walls in.
	-- Two frames would be two chances to put a strongroom through a wall, and
	-- the wall does not collide, so nothing in the engine would say so.
	local cf = Config.shopUnitCFrame(spec)
	local u = Config.SHOP_UNIT

	-- THE ONE CONVERSION, WRITTEN DOWN ONCE. `ShopFront` measures its bands
	-- from the PAVEMENT and a plot's frame sits half a slab higher, because
	-- a plot origin is the middle of its own base. So `at` takes a shop-local
	-- height and every number below can be read straight off the elevation in
	-- that file rather than translated in somebody's head.
	local PAVE = -Config.PLOT_SIZE.Y / 2
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, PAVE + y, z)
	end

	local model = Instance.new("Model")
	model.Name = "Shop_" .. spec.tab

	-- THE FLOOR, WHICH IS AN ORDINARY PLOT BASE AND HAS TO BE ONE.
	--
	-- It is the plot's `base`: what `ResidentService` derives its ground
	-- height from, what the shopkeeper stands on and what the vault is
	-- authored around -- the same job a 64-stud slab does on a lawn, at the
	-- size a shop unit can actually hold. It is also the only thing in this
	-- building that COLLIDES, which is what makes walking in a step up onto a
	-- floor rather than a walk through a wall onto grass.
	--
	-- `floorY` is a plot slab thick above the pavement BY DERIVATION rather
	-- than by choice: the slab is centred on the plot origin, so its walkable
	-- top is half a slab up and the pavement is half a slab down.
	--
	-- WIDER THAN THE ROOM AND SUNK A TOUCH, and both of those are the coplanar
	-- convention rather than taste. It reaches to the wall faces so it tucks
	-- UNDER the plinth ring instead of stopping short of it -- a hairline gap
	-- between a floor and its own base course is a crack you can see the
	-- world through -- and it is 0.15 thicker than a plot slab so its bottom
	-- face does not land in the same plane as the forecourt's, which covers
	-- the same ground a tenth of a stud away.
	--
	-- What the extra thickness costs, stated because it is a real reader:
	-- `ResidentService.groundY` is `base.Position.Y - base.Size.Y / 2`, so a
	-- shopkeeper who goes out robbing walks the VERGE leg of its route 0.15
	-- studs low. The leg that matters -- `lawnY`, where they stand -- is
	-- derived from the TOP and is exact.
	local FLOOR_SINK = 0.15
	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(u.width - 1, Config.PLOT_SIZE.Y + FLOOR_SINK, u.depth - 1)
	base.CFrame = at(0, u.floorY - (Config.PLOT_SIZE.Y + FLOOR_SINK) / 2, 0)
	base.Anchored = true
	base.Material = Enum.Material.WoodPlanks
	base.Color = Color3.fromRGB(150, 122, 92)
	base.TopSurface = Enum.SurfaceType.Smooth
	base.Parent = model

	-- THE VAULT, ON THE BACK WALL, AND IT IS THIS PLOT'S PIGGY BANK IN EVERY
	-- SENSE THE REST OF THE CODEBASE CARES ABOUT. `PiggyBank.buildVault`
	-- returns the same `Refs` a piggy does, so the fill, the dial, the
	-- rattle, the plaster, the alarm, the milestone, the steal prompt and the
	-- raid drone's anchor all work here with no branch anywhere. See the
	-- entry over that function for what the alternative would have cost.
	local piggy = PiggyBank.buildVault(at(u.vaultX, u.floorY, u.vaultZ), model)

	-- THE BOARD OVER THE VAULT, and it is what carries the two sign labels
	-- every plot is required to have.
	--
	-- On the back wall INSIDE, where the old plaque stood on the apron
	-- outside. There is no room for a second name on the frontage -- the
	-- banner over the roof and the bracket sign already name this unit twice
	-- from the street -- and the thing that wants naming now is the strongroom
	-- rather than the building.
	local function boardPart(name: string, size: Vector3, cframe: CFrame,
		colour: Color3, material: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cframe
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Material = material
		p.Color = colour
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	local boardY = 9.6
	local boardZ = -u.roomDepth / 2
	boardPart("Board", Vector3.new(6.4, 2.2, 0.5),
		at(u.vaultX, boardY, boardZ - 0.05), Color3.fromRGB(96, 64, 42), Enum.Material.WoodPlanks)
	local panel = boardPart("BoardPanel", Vector3.new(5.7, 1.6, 0.2),
		at(u.vaultX, boardY, boardZ + 0.28), Color3.fromRGB(244, 236, 218),
		Enum.Material.SmoothPlastic)

	local surface = Instance.new("SurfaceGui")
	-- Roblox's "Front" face is -Z and this panel faces into the room on +Z,
	-- so Back. Same trap the plot sign records.
	surface.Face = Enum.NormalId.Back
	surface.CanvasSize = Vector2.new(500, 150)
	surface.AlwaysOnTop = false
	surface.LightInfluence = 0
	surface.Parent = panel

	-- NAMED `signLabel` AND `signBoast` BECAUSE THAT IS WHAT A PLOT CARRIES.
	-- `PlotService.updateSign` writes both without knowing which kind of plot
	-- it is holding, so a shop naming these anything else would need a branch
	-- there and in `ResidentService`.
	local label = Instance.new("TextLabel")
	label.Name = "Owner"
	label.Size = UDim2.new(1, -24, 0.56, 0)
	label.Position = UDim2.new(0, 12, 0.06, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	-- Never write TextWrapped beside TextScaled; see the plot sign.
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(70, 46, 30)
	label.Text = spec.name
	label.Parent = surface

	local boast = Instance.new("TextLabel")
	boast.Name = "Boasts"
	boast.Size = UDim2.new(1, -24, 0.32, 0)
	boast.Position = UDim2.new(0, 12, 0.62, 0)
	boast.BackgroundTransparency = 1
	boast.Font = Enum.Font.GothamBold
	boast.TextScaled = true
	boast.TextColor3 = Color3.fromRGB(150, 104, 44)
	boast.Text = "VAULT"
	boast.Parent = surface

	local fence = Instance.new("Folder")
	fence.Name = "Fence"
	fence.Parent = model

	model.PrimaryPart = base
	model.Parent = plotsFolder

	-- NO `PivotTo`, AND THAT IS DELIBERATE. A lawn plot is authored around an
	-- unrotated origin and turned once at the end; this one is authored
	-- through `at`, which already carries the unit's own rotation, so a pivot
	-- here would turn everything a second time. The plaque on the old apron
	-- shipped that way for a build and it was very nearly invisible -- the
	-- yaw is 0 or pi, so a double turn is 0 or 2pi and the board came out
	-- correct on both rows while its POSITION had been mirrored.

	-- The tier-0 dog. It never appears and never patrols; it exists because
	-- `plot.dog` is read in seven places across four services and a nil there
	-- is a crash rather than a missing feature. Tucked behind the counter,
	-- where the hidden model has nothing to be in the way of.
	local dog = GuardDog.build(at(-u.roomWidth / 2 + 2, u.floorY, -4), model)

	-- AND THE WHOLE THING IS HIDDEN, KENNEL INCLUDED, WHICH THE DOG'S OWN
	-- TIER 0 DOES NOT DO FOR YOU. A level-0 dog hides its fourteen body parts
	-- and clears its nameplate -- that is what "this plot has no dog yet"
	-- looks like on a LAWN, where an empty kennel is the correct picture and
	-- is what the upgrade is sold against. Inside a shop it is a dog kennel
	-- standing behind the counter, which is a thing nobody built and nobody
	-- can explain.
	--
	-- Safe to do once: the only thing that repaints a dog is `applyTier`
	-- behind `setDogLevel`, and `ResidentService.applyLevel` never calls it
	-- for a shop. BOTH MODELS, because the kennel is a separate one --
	-- deliberately, so a patrolling dog does not drag its own house behind
	-- it -- and hiding only `dog.model` leaves the kennel standing.
	for _, m in ipairs({ dog.model, dog.kennelModel }) do
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Transparency = 1
				d.CanCollide = false
				d.CanQuery = false
			elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
				d.Enabled = false
			end
		end
	end

	return {
		index = index,
		model = model,
		base = base,
		cframe = cf,
		piggy = piggy,
		dog = dog,
		fence = fence,
		fenceLevel = 0,
		house = nil,
		decor = nil,
		signLabel = label,
		signBoast = boast,
		owner = nil,
		-- THE FLAG THAT MAKES IT UNCLAIMABLE, and the only thing separating a
		-- shop from an ordinary plot anywhere else in the codebase.
		-- `PlotService.assign` skips it, so no player ever moves in and
		-- `ResidentService` is never asked to evict -- which is precisely the
		-- property the supply floor is made of.
		shop = spec.tab,
	}
end
-- ============================================================
-- FENCES
-- ============================================================
--
-- Collision and decoration are deliberately separate systems.
--
-- The old fence WAS its rails: two thin bars with a 2.95-stud hole between
-- them and open air above the top one, so a thief could slip straight
-- through. Now every side gets one invisible slab running ground-to-top --
-- the only colliding geometry on the whole fence -- and the visible fence is
-- pure decoration with CanCollide off. Styles can then look like anything
-- without ever changing the jump maths, which depends only on `tier.top`.

-- Fence sits on the world ground outside the plot slab, not on the slab.
local FENCE_BASE_Y = -Config.PLOT_SIZE.Y / 2

-- How far the driveway paving stands proud of the world ground. Shared with
-- the decor placement so a car sits ON the paving rather than sunk into it or
-- hovering over it.
local DRIVEWAY_LIFT = 0.22

local function alongVec(alongX: boolean, t: number): Vector3
	return if alongX then Vector3.new(t, 0, 0) else Vector3.new(0, 0, t)
end

local function spanSize(alongX: boolean, length: number, height: number, depth: number): Vector3
	return if alongX then Vector3.new(length, height, depth) else Vector3.new(depth, height, length)
end

-- Takes a CFrame, not a position: the far row of plots is yawed 180 degrees,
-- and decoration has to arrive already rotated into the plot's own frame.
local function decorPart(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Evenly spaced positions along a side that always include both ends, so
-- corners and gate mouths get a post instead of trailing off into nothing.
local function stepsAlong(length: number, spacing: number): { number }
	local count = math.max(1, math.round(length / spacing))
	local out = {}
	for i = 0, count do
		table.insert(out, -length / 2 + (length / count) * i)
	end
	return out
end

local function decorRickety(parent: Instance, originCF: CFrame, centre: Vector3, length: number, alongX: boolean, tier: any)
	local WOOD = Color3.fromRGB(124, 100, 76)
	local WOOD_PALE = Color3.fromRGB(152, 128, 98)

	-- Rails in broken segments. A rickety fence is defined by what's missing,
	-- so roughly one plank in four is simply never built.
	for row, height in ipairs({ 1.2, 2.5 }) do
		local segments = math.max(3, math.round(length / 5))
		local segLength = length / segments
		for i = 0, segments - 1 do
			if (i + row) % 4 ~= 2 then
				local t = -length / 2 + segLength * (i + 0.5)
				local rail = decorPart(parent, "Rail",
					spanSize(alongX, segLength * 0.9, 0.4, 0.35),
					originCF * CFrame.new(centre + alongVec(alongX, t) + Vector3.new(0, FENCE_BASE_Y + height, 0)))
				rail.Material = Enum.Material.WoodPlanks
				rail.Color = if i % 2 == 0 then WOOD else WOOD_PALE
			end
		end
	end

	for i, t in ipairs(stepsAlong(length, 5)) do
		local post = decorPart(parent, "Post", Vector3.new(0.55, tier.decorTop, 0.55),
			originCF * CFrame.new(centre + alongVec(alongX, t) + Vector3.new(0, FENCE_BASE_Y + tier.decorTop / 2, 0)))
		post.Material = Enum.Material.WoodPlanks
		post.Color = WOOD
		-- A few degrees of lean, alternating, so the line never looks surveyed.
		local lean = math.rad((i % 3 - 1) * 3.5)
		post.CFrame = post.CFrame
			* (if alongX then CFrame.Angles(lean, 0, 0) else CFrame.Angles(0, 0, lean))
	end
end

local function decorPicket(parent: Instance, originCF: CFrame, centre: Vector3, length: number, alongX: boolean, tier: any)
	local WHITE = Color3.fromRGB(246, 246, 240)

	for _, height in ipairs({ 1.3, 3.4 }) do
		local rail = decorPart(parent, "Rail", spanSize(alongX, length, 0.35, 0.28),
			originCF * CFrame.new(centre + Vector3.new(0, FENCE_BASE_Y + height, 0)))
		rail.Material = Enum.Material.SmoothPlastic
		rail.Color = WHITE
	end

	for _, t in ipairs(stepsAlong(length, 2.6)) do
		local base = centre + alongVec(alongX, t)
		local picket = decorPart(parent, "Picket", spanSize(alongX, 0.5, tier.top, 0.22),
			originCF * CFrame.new(base + Vector3.new(0, FENCE_BASE_Y + tier.top / 2, 0)))
		picket.Material = Enum.Material.SmoothPlastic
		picket.Color = WHITE

		-- Rotated cube reads as a point from the front, which is the entire
		-- silhouette of a picket fence, and costs one part instead of two wedges.
		local tip = decorPart(parent, "Tip", Vector3.new(0.42, 0.42, 0.42),
			originCF * CFrame.new(base + Vector3.new(0, FENCE_BASE_Y + tier.top + 0.2, 0)))
		tip.Material = Enum.Material.SmoothPlastic
		tip.Color = WHITE
		tip.CFrame = tip.CFrame
			* (if alongX then CFrame.Angles(0, 0, math.rad(45)) else CFrame.Angles(math.rad(45), 0, 0))
	end
end

local function decorBarbed(parent: Instance, originCF: CFrame, centre: Vector3, length: number, alongX: boolean, tier: any)
	local STEEL = Color3.fromRGB(104, 110, 120)

	for _, height in ipairs({ 1.4, 3.0, 4.6 }) do
		local wire = decorPart(parent, "Wire", spanSize(alongX, length, 0.16, 0.16),
			originCF * CFrame.new(centre + Vector3.new(0, FENCE_BASE_Y + height, 0)))
		wire.Material = Enum.Material.DiamondPlate
		wire.Color = STEEL
	end

	-- The top strand sits above the barrier, so the thing you have to clear is
	-- visibly the nasty bit rather than an invisible line.
	local top = decorPart(parent, "Wire", spanSize(alongX, length, 0.2, 0.2),
		originCF * CFrame.new(centre + Vector3.new(0, FENCE_BASE_Y + tier.decorTop, 0)))
	top.Material = Enum.Material.DiamondPlate
	top.Color = Color3.fromRGB(152, 158, 168)

	for _, t in ipairs(stepsAlong(length, 6)) do
		local post = decorPart(parent, "Post", Vector3.new(0.45, tier.decorTop, 0.45),
			originCF * CFrame.new(centre + alongVec(alongX, t) + Vector3.new(0, FENCE_BASE_Y + tier.decorTop / 2, 0)))
		post.Material = Enum.Material.Metal
		post.Color = STEEL
	end
end

local function decorElectric(parent: Instance, originCF: CFrame, centre: Vector3, length: number, alongX: boolean, tier: any)
	decorBarbed(parent, originCF, centre, length, alongX, tier)

	local LIVE = Color3.fromRGB(255, 226, 92)
	for _, height in ipairs({ 2.2, 4.6, tier.decorTop }) do
		local live = decorPart(parent, "Live", spanSize(alongX, length, 0.2, 0.2),
			originCF * CFrame.new(centre + Vector3.new(0, FENCE_BASE_Y + height, 0)))
		live.Material = Enum.Material.Neon
		live.Color = LIVE
	end

	-- One emitter per side rather than per strand: the arcing is atmosphere,
	-- and four emitters a plot is already plenty of particles.
	local arc = Instance.new("ParticleEmitter")
	arc.Name = "Arc"
	arc.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	arc.Color = ColorSequence.new(Color3.fromRGB(255, 244, 190), LIVE)
	arc.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	arc.Lifetime = NumberRange.new(0.2, 0.45)
	arc.Rate = 6
	arc.Speed = NumberRange.new(0.5, 2)
	arc.SpreadAngle = Vector2.new(180, 180)
	arc.LightEmission = 1
	arc.Parent = parent:FindFirstChild("Live") or parent
end

local function decorMoat(parent: Instance, originCF: CFrame, centre: Vector3, length: number, alongX: boolean, tier: any)
	-- The wall itself is unchanged from Electric; the water is the upgrade,
	-- and it is built once for the whole ring rather than per side.
	decorElectric(parent, originCF, centre, length, alongX, tier)
end

-- The meshed fence: one panel, cloned along the run.
--
-- Built ONCE per style and cloned, because `CreateMeshPartAsync` yields and a
-- fence is dozens of panels. Same shape as the trees and the grass tufts.
local fencePanels: { [string]: BasePart } = {}
local fencePanelChecked: { [string]: boolean } = {}

local function fencePanel(style: string): BasePart?
	if fencePanelChecked[style] then
		return fencePanels[style]
	end
	fencePanelChecked[style] = true

	local spec = Config.fenceMesh(style)
	if not spec then
		return nil
	end

	local ok, result = pcall(function()
		local part = game:GetService("InsertService"):CreateMeshPartAsync(spec.id,
			Enum.CollisionFidelity.Box, Enum.RenderFidelity.Automatic)
		-- `CreateMeshPartAsync` carries the mesh and NOT the map, which is how
		-- the trees shipped flat for a build with nothing in the log.
		if spec.texture then
			part.TextureID = spec.texture
		end
		return part
	end)

	if not ok then
		warn(("[PlotService] the %s fence panel could not be loaded, so the "
			.. "primitive fence is standing instead: %s"):format(style, tostring(result)))
		return nil
	end

	fencePanels[style] = result
	return result
end

-- Tiles the panel along one run. Returns false when there is no mesh for this
-- style, so the caller can fall through to the primitive decorator.
local function decorMeshPanel(parent: Instance, originCF: CFrame, centre: Vector3,
	length: number, alongX: boolean, tier: any): boolean

	local spec = Config.fenceMesh(tier.style)
	local template = spec and fencePanel(tier.style)
	if not (spec and template) then
		return false
	end

	-- UNIFORM off the authored height so the panel lands on `decorTop`; the
	-- run length then falls out of that and decides how many fit. Only the
	-- LENGTH is stretched afterwards, to tile the run exactly -- invisible on
	-- a flat panel seen side-on, where a stretched HEIGHT would not be.
	local scale = tier.decorTop / spec.size.Y
	local count = math.max(1, math.round(length / (spec.size.X * scale)))
	local actual = length / count

	for i = 0, count - 1 do
		local t = -length / 2 + actual * (i + 0.5)
		local panel = template:Clone()
		panel.Name = "Panel"
		-- SIZE BEFORE CFRAME: resizing a MeshPart scales it about its own
		-- centre, so a part seated first and scaled after moves off its spot.
		-- The mesh is authored with its run along X, so the part is turned a
		-- quarter when the fence runs along Z rather than swapping the size.
		panel.Size = Vector3.new(actual, tier.decorTop, spec.size.Z * scale)
		panel.CFrame = originCF
			* CFrame.new(centre + alongVec(alongX, t)
				+ Vector3.new(0, FENCE_BASE_Y + tier.decorTop / 2, 0))
			* (if alongX then CFrame.new() else CFrame.Angles(0, math.rad(90), 0))
		panel.Anchored = true
		-- The Barrier beside this is the only thing that collides, and the
		-- ClimbZone above it is the only thing queried. A decoration that did
		-- either would change what a fence COSTS to cross.
		panel.CanCollide = false
		panel.CanQuery = false
		panel.CastShadow = false
		if spec.tint then
			panel.Color = spec.tint
		end
		panel.Parent = parent
	end

	-- Wires strung the whole length of the run, under the panel's own.
	--
	-- OUTSIDE THE PANEL LOOP ON PURPOSE. One part per wire per SIDE rather
	-- than per panel is what keeps this from undoing the saving the panels
	-- bought: on the electric tier that is ten parts instead of sixty-eight.
	-- It is also what the primitive `decorElectric` already did.
	if spec.wires then
		for _, height in ipairs(spec.wires.heights) do
			local wire = decorPart(parent, "Wire",
				spanSize(alongX, length, spec.wires.thickness, spec.wires.thickness),
				originCF * CFrame.new(centre + Vector3.new(0, FENCE_BASE_Y + height, 0)))
			wire.Material = Enum.Material.SmoothPlastic
			wire.Color = spec.wires.colour
		end
	end
	return true
end

local FENCE_STYLES: { [string]: (Instance, CFrame, Vector3, number, boolean, any) -> () } = {
	rickety = decorRickety,
	picket = decorPicket,
	barbed = decorBarbed,
	electric = decorElectric,
	moat = decorMoat,
}

function PlotService.buildFence(plot: Plot, level: number)
	plot.fence:ClearAllChildren()
	plot.fenceLevel = math.max(level, 0)
	if level <= 0 then
		return
	end

	local tier = Config.FENCE_TIERS[math.clamp(level, 1, #Config.FENCE_TIERS)]
	-- The mesh panel first, per style, falling through to the primitive
	-- decorator whenever `Config.FENCE_MESH` has no row for it. That is what
	-- lets the five tiers be meshed one at a time.
	local primitive = FENCE_STYLES[tier.style] or decorRickety
	local decorate = function(parent, cf, centre, length, alongX, t)
		if not decorMeshPanel(parent, cf, centre, length, alongX, t) then
			primitive(parent, cf, centre, length, alongX, t)
		end
	end
	local originCF = plot.cframe
	-- THE SIDES AND THE FRONT ARE DIFFERENT NUMBERS. This was one `half` doing
	-- both jobs, which was right only while the plot was square -- see
	-- Config.PLOT_HALF_WIDTH.
	local half = Config.PLOT_HALF_WIDTH
	local frontZ = Config.PLOT_FRONT_LINE
	local gate = tier.gate

	local climbPenalty = {
		label = tier.label,
		slow = tier.slow,
		duration = tier.duration,
		stun = tier.stun or 0,
	}

	local function firePenalty(hit: BasePart, penalty: any, reject: Vector3?)
		local character = hit.Parent
		if not character or not character:FindFirstChildOfClass("Humanoid") then
			return
		end
		local crosser = Players:GetPlayerFromCharacter(character)
		-- Owners cross their own defences freely; they paid for them.
		if not crosser or crosser == plot.owner then
			return
		end

		-- ONE CHARGE PER CROSSING. See fenceCooldown -- without this the
		-- notification repeats about five times a second and, on a tier that
		-- stuns, the stun re-stamps itself faster than it can expire.
		local key = ("%d/%s"):format(plot.index, tostring(penalty.label))
		local now = os.clock()
		local perPlayer = fenceCooldown[crosser]
		if not perPlayer then
			perPlayer = {}
			fenceCooldown[crosser] = perPlayer
		end
		if now < (perPlayer[key] or 0) then
			return
		end
		perPlayer[key] = now + penalty.duration + Config.FENCE_PENALTY_GRACE

		-- THE SHOCK IS AUDIBLE, AND ONLY THE TIERS THAT ACTUALLY SHOCK MAKE
		-- THE NOISE. `penalty.stun > 0` is the same test that decides whether
		-- a crossing throws you off the fence, reused rather than re-derived:
		-- a rickety fence is meant to be climbable and merely slow, so it
		-- stays silent, and a sound on it would advertise a hazard that is
		-- not there.
		--
		-- IT SITS UNDER THE COOLDOWN, which is what makes it safe. `Touched`
		-- fires per character part -- measured at fourteen parts on the first
		-- contact frame and 18 fires over four seconds while resting -- so a
		-- sound placed above that stamp would be eighteen overlapping zaps
		-- rather than one. Every line from here down runs once per crossing.
		if (penalty.stun or 0) > 0 then
			SoundKit.on(hit, Config.SOUNDS.FENCE_ZAP,
				{ name = "FenceZap", volume = 0.55, distance = 90 })
		end

		for _, callback in ipairs(fencePenaltyHandlers) do
			task.spawn(callback, crosser, plot, penalty)
		end

		-- THROWN OFF THE FENCE, because the stun that comes with a shock would
		-- otherwise leave them standing in the volume that caused it -- unable
		-- to walk out, unable to jump off, waiting out the cooldown on top of
		-- the fence they were shocked by. Only tiers that stun throw; a
		-- rickety fence is meant to be climbable and merely slow.
		--
		-- HANDED TO THE CLIENT, exactly as the trampoline is: a server-side
		-- write to a player's AssemblyLinearVelocity is discarded, because the
		-- client owns its own physics. The server still owns every decision --
		-- who, whether, and which way.
		if reject and (penalty.stun or 0) > 0 then
			Remotes.get("FenceKnockback"):FireClient(crosser, reject)
		end
	end

	local function side(centre: Vector3, length: number, alongX: boolean)
		-- The one and only colliding part of the fence. Solid from the ground
		-- to `top` so there is nothing to slip between.
		local barrier = Instance.new("Part")
		barrier.Name = "Barrier"
		barrier.Size = spanSize(alongX, length, tier.top, 0.6)
		barrier.CFrame = originCF * CFrame.new(centre + Vector3.new(0, FENCE_BASE_Y + tier.top / 2, 0))
		barrier.Anchored = true
		barrier.CanCollide = true
		barrier.CanQuery = false
		barrier.Transparency = 1
		-- WHICH WAY THIS SEGMENT RUNS AND HOW LONG IT IS, published on the
		-- part rather than kept in a table beside it. `placeLadder` has to
		-- project a player's position onto a segment, and a square barrier
		-- cannot be asked which of its axes is the fence: at the moat's
		-- bands this file already writes `Span`/`AlongX` for exactly this.
		barrier:SetAttribute("AlongX", alongX)
		barrier:SetAttribute("Span", length)
		barrier.Parent = plot.fence

		decorate(plot.fence, originCF, centre, length, alongX, tier)

		-- THERE IS NO BUILT-IN WAY OVER, AND THERE USED TO BE.
		--
		-- Every segment carried a permanent climbing trellis. Three things
		-- were wrong with it and only the first was visible: it stood on
		-- tiers you can step over, so the cheapest fence in the game had a
		-- ladder bolted to it; it made a fence a slower floor rather than a
		-- wall, since the way across was always there and always free; and it
		-- left nothing for an item to sell, because the problem it would
		-- solve was already solved on every plot forever.
		--
		-- A fence is solid now and `Config.LADDER` is what crosses it. That
		-- does not make a plot uncrossable -- the gate below is always open,
		-- at every tier -- so what the fence actually stops is the side and
		-- back crossing, which is the alley shortcut, and the ladder buys a
		-- route that is not the front door.

		-- Snag volume, sitting above the barrier so it only catches players
		-- coming over the top, never anyone walking in through the gate.
		local zone = Instance.new("Part")
		zone.Name = "ClimbZone"
		zone.Size = spanSize(alongX, length, 5, 3)
		zone.CFrame = originCF * CFrame.new(centre + Vector3.new(0, FENCE_BASE_Y + tier.top + 2.5, 0))
		zone.Anchored = true
		zone.CanCollide = false
		zone.CanQuery = false
		zone.Transparency = 1
		zone.Parent = plot.fence

		-- WHICH WAY IS "OFF THE FENCE" is decided per hit, from the side the
		-- climber is already on -- never a fixed outward push.
		--
		-- A fence must reject you to where you were, and never carry you
		-- across itself. Always pushing outward would bounce a thief climbing
		-- IN back to the street, which is a defence, but it would also throw a
		-- thief climbing OUT into the street, which is a free getaway on the
		-- one tier that costs the most to buy. Rejecting to the near side can
		-- do neither: the most it ever gives anybody is a few studs deeper
		-- into the ground they were already standing on, paid for with two and
		-- a half seconds of being unable to move.
		--
		-- The normal is the axis the fence does NOT run along: a run along X
		-- is crossed in Z, and the other way round.
		local normal = if alongX then Vector3.zAxis else Vector3.xAxis
		local planeAt = if alongX then centre.Z else centre.X

		zone.Touched:Connect(function(hit)
			local root = hit.Parent and hit.Parent:FindFirstChild("HumanoidRootPart") :: BasePart?
			local reject: Vector3? = nil
			if root then
				local localPos = originCF:PointToObjectSpace(root.Position)
				local offset = (if alongX then localPos.Z else localPos.X) - planeAt
				-- Dead on the plane is vanishingly unlikely and has no near
				-- side to pick, so treat it as outward rather than as zero --
				-- a knockback of nothing would leave them in the zone.
				local sign = if offset < 0 then -1 else 1
				reject = originCF:VectorToWorldSpace(normal * sign)
			end
			firePenalty(hit, climbPenalty, reject)
		end)
	end

	-- The yard is a long rectangle, not a square: the front fence stays exactly
	-- where every heist number expects it, and the sides run BACK to enclose
	-- the house. A thief approaches from the street, so nothing behind the
	-- piggy affects the steal, the getaway or the drop-off.
	local backZ = Config.YARD_DEPTH
	-- The sides run from the FRONT LINE back to the back fence, so their length
	-- is a Z span and takes frontZ; their POSITION is an X offset and takes
	-- half. Mixing those is what a single `half` used to hide.
	local sideLength = frontZ + backZ
	local sideCentre = (frontZ - backZ) / 2

	side(Vector3.new(0, 0, -backZ), half * 2, true)
	side(Vector3.new(-half, 0, sideCentre), sideLength, false)
	side(Vector3.new(half, 0, sideCentre), sideLength, false)

	local wing = half - gate / 2
	if wing > 0 then
		local offset = gate / 2 + wing / 2
		side(Vector3.new(-offset, 0, frontZ), wing, true)
		side(Vector3.new(offset, 0, frontZ), wing, true)
	end

	-- THE GATE POST THAT CARRIES THE JAM PROMPT.
	--
	-- Built with the fence rather than with the plot, so it is rebuilt on every
	-- tier change and cannot be left standing at a gate that has moved: the
	-- opening is 24 studs at Rickety and 8 at the Moat, so its own position
	-- depends on the tier.
	--
	-- Invisible and non-colliding like everything else out here. It is an
	-- anchor for a prompt, not an object: a post a thief could run into at the
	-- one moment they are sprinting for the street would be the worst possible
	-- place in this game to put a collision.
	local jamPost = Instance.new("Part")
	jamPost.Name = "GatePost"
	jamPost.Size = Vector3.new(1, 1, 1)
	jamPost.CFrame = plot.cframe * CFrame.new(0, FENCE_BASE_Y + 3, frontZ)
	jamPost.Anchored = true
	jamPost.CanCollide = false
	jamPost.CanQuery = false
	jamPost.CastShadow = false
	jamPost.Transparency = 1
	jamPost.Parent = plot.fence

	local jamPrompt = Instance.new("ProximityPrompt")
	jamPrompt.Name = "JamPrompt"
	jamPrompt.ActionText = "Jam the Gate!"
	jamPrompt.ObjectText = ("%s coins"):format(Config.formatCoins(Config.GATE_JAM.cost))
	jamPrompt.HoldDuration = 0.35
	jamPrompt.MaxActivationDistance = 12
	jamPrompt.RequiresLineOfSight = false
	Config.setPromptKind(jamPrompt, "jam")
	jamPrompt.Parent = jamPost

	jamPrompt.Triggered:Connect(function(player)
		PlotService.fireGateJam(player, plot)
	end)

	-- Moat ------------------------------------------------------------
	--
	-- Sits in the one-stud step between the world ground and the plot slab, so
	-- it reads as dug rather than poured on top. The gate mouth is left dry:
	-- there is always a clean way in for anyone willing to take the long route.
	--
	-- WHY THIS IS NOT TERRAIN WATER. Roblox's real water -- the animated,
	-- refracting, swimmable kind -- only exists on Terrain, and Terrain is
	-- voxelised at four studs. This moat is five studs wide and about one
	-- stud deep, so a terrain fill would round it into a blocky four-stud
	-- gouge; the world ground it would have to cut through is a Part, not
	-- terrain, so there is nothing to carve; and dropping a player into the
	-- Swimming humanoid state would walk straight through the carry-speed
	-- model that every other number here is calibrated against. So it is
	-- parts, and the water-ness is built rather than inherited.
	--
	-- Three things do that, and the first matters most: a channel needs a
	-- VISIBLE EDGE. Flat blue laid on flat green is a carpet no matter what
	-- colour it is -- what says "dug" is the bank standing proud on either
	-- side, casting a line of shadow down onto the surface. Then depth: the
	-- surface is a thick translucent slab rather than a sheet, so you look
	-- down THROUGH a volume of blue into a dark bed. Then motion, which is
	-- client-side for the same reason the animated skins are (see
	-- ClientMain): the server tags the parts and publishes their span, and
	-- every machine works the ripples out for itself.
	if tier.moat then
		local m = tier.moat
		local moatPenalty = { label = "Moat", slow = m.slow, duration = m.duration, stun = 0 }
		-- `mid`/`reach` are the SIDE bands' X offsets and the FRONT band's Z, and
		-- those are no longer the same distance from the centre. The front pair
		-- is measured off the front line; the sides off the half width.
		local mid = half + 0.5 + m.width / 2
		local reach = half + 0.5 + m.width
		local frontMid = frontZ + 0.5 + m.width / 2
		local frontReach = frontZ + 0.5 + m.width

		-- Mirrors the fence rectangle: the back band sits behind the house and
		-- the side bands run the full length of the yard.
		local backMid = backZ + 0.5 + m.width / 2
		local backReach = backZ + 0.5 + m.width
		local sideMoatLength = frontReach + backReach
		local sideMoatCentre = (frontReach - backReach) / 2

		-- THE CHANNEL IS RAISED, NOT DUG, and it has to be.
		--
		-- The world ground is one solid slab and a Part cannot cut a hole in
		-- another Part, so a water surface set below ground level is not a
		-- trench -- it is simply invisible, hidden behind the grass that is
		-- still there above it. (Measured: at 0.16 under the ground the whole
		-- moat disappeared.) So every layer here sits PROUD of the ground, and
		-- the sunkenness is an illusion the banks do all the work for: kerbs
		-- standing 0.5 above the grass with a water surface 0.19 BELOW their
		-- top edge reads as a channel, because the eye takes the highest line
		-- as ground level.
		--
		-- Heights are all relative to FENCE_BASE_Y, the world ground:
		--     bank   -0.10 .. +0.50   (bottom buried, top is the kerb line)
		--     water  -0.19 .. +0.31   (a volume, seen into from above)
		--     bed    -0.47 .. +0.03   (opaque and dark, the thing you see)
		-- Nothing shares a face height with anything else, which is the rule
		-- the road and the old moat both broke.
		local BANK_H, BANK_W = 0.6, 1.0
		local BANK_Y = FENCE_BASE_Y + 0.20
		local DEEP = 0.5
		local WATER_Y = FENCE_BASE_Y + 0.06
		local SURFACE_Y = WATER_Y + DEEP / 2
		local BED_Y = FENCE_BASE_Y - 0.22
		local WATER = Color3.fromRGB(38, 104, 164)
		local BED = Color3.fromRGB(26, 52, 64)
		local STONE = Color3.fromRGB(112, 116, 118)

		local splashed: { [Player]: number } = {}
		local bandIndex = 0

		-- One kerb run. Built along the RING rather than per band -- see the
		-- rim pass below for why.
		local function bank(centre: Vector3, length: number, alongX: boolean)
			local b = Instance.new("Part")
			b.Name = "MoatBank"
			b.Size = spanSize(alongX, length, BANK_H, BANK_W)
			b.CFrame = originCF * CFrame.new(centre + Vector3.new(0, BANK_Y, 0))
			b.Anchored = true
			b.CanCollide = false
			b.CanQuery = false
			-- The one thing here that casts: the kerb's shadow falling across
			-- the water is most of what sells the depth.
			b.CastShadow = true
			b.Color = STONE
			b.Material = Enum.Material.Slate
			b.TopSurface = Enum.SurfaceType.Smooth
			b.BottomSurface = Enum.SurfaceType.Smooth
			b.Parent = plot.fence
		end

		local function channel(centre: Vector3, length: number, alongX: boolean)
			bandIndex += 1

			-- The bed: opaque, dark, and the thing actually seen through the
			-- water. Without it the translucent surface tints the grass
			-- underneath and the moat comes out pond-green.
			local bed = Instance.new("Part")
			bed.Name = "MoatBed"
			bed.Size = spanSize(alongX, length, 0.5, m.width)
			bed.CFrame = originCF * CFrame.new(centre + Vector3.new(0, BED_Y, 0))
			bed.Anchored = true
			bed.CanCollide = false
			bed.CanQuery = false
			bed.CastShadow = false
			bed.Color = BED
			bed.Material = Enum.Material.Slate
			bed.TopSurface = Enum.SurfaceType.Smooth
			bed.BottomSurface = Enum.SurfaceType.Smooth
			bed.Parent = plot.fence

			local w = Instance.new("Part")
			w.Name = "MoatWater"
			-- A VOLUME, not a sheet. A flat plane has nothing to see into;
			-- half a stud of translucent blue over a dark bed does.
			w.Size = spanSize(alongX, length, DEEP, m.width)
			w.CFrame = originCF * CFrame.new(centre + Vector3.new(0, WATER_Y, 0))
			w.Anchored = true
			w.CanCollide = false
			w.CanQuery = false
			w.CastShadow = false
			-- SmoothPlastic, not Glass. Glass plus reflectance washed out to
			-- near-white against the grass and stopped reading as water.
			w.Material = Enum.Material.SmoothPlastic
			w.Color = WATER
			w.Transparency = 0.38
			w.Reflectance = 0.07
			-- Everything the client's animation loop needs, and nothing it
			-- could work out for itself.
			w:SetAttribute("Phase", bandIndex * 0.83)
			w.Parent = plot.fence
			CollectionService:AddTag(w, "MoatWater")

			-- Splash, fired on entry rather than left running. A permanent
			-- emitter per band would be sixty of them across a full street to
			-- say something nobody looks at; a burst when someone goes in is
			-- the moment that actually wants marking.
			local splash = Instance.new("ParticleEmitter")
			splash.Name = "Splash"
			splash.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			splash.Color = ColorSequence.new(Color3.fromRGB(226, 244, 255), WATER)
			splash.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1.1),
				NumberSequenceKeypoint.new(1, 0),
			})
			splash.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(1, 1),
			})
			splash.Lifetime = NumberRange.new(0.4, 0.8)
			splash.Speed = NumberRange.new(9, 16)
			splash.SpreadAngle = Vector2.new(40, 40)
			splash.Acceleration = Vector3.new(0, -55, 0)
			splash.LightEmission = 0.6
			splash.Rate = 0
			splash.Enabled = false
			splash.Parent = w

			-- Two ripple crests per band, animated along it by the client.
			-- Anchored, non-colliding, and invisible until the client moves
			-- them: a server that never touches them again costs nothing.
			for i = 1, 2 do
				local r = Instance.new("Part")
				r.Name = "MoatRipple"
				r.Size = spanSize(alongX, 1.8, 0.08, m.width * 0.8)
				r.CFrame = originCF * CFrame.new(centre + Vector3.new(0, SURFACE_Y + 0.025, 0))
				r.Anchored = true
				r.CanCollide = false
				r.CanQuery = false
				r.CastShadow = false
				r.Material = Enum.Material.SmoothPlastic
				r.Color = Color3.fromRGB(178, 216, 240)
				r.Transparency = 1
				r:SetAttribute("Span", length)
				r:SetAttribute("AlongX", alongX)
				r:SetAttribute("Phase", (bandIndex * 2 + i) * 0.37)
				r.Parent = plot.fence
				CollectionService:AddTag(r, "MoatRipple")
			end

			w.Touched:Connect(function(hit)
				local character = hit.Parent
				local crosser = character and Players:GetPlayerFromCharacter(character)
				if crosser then
					local now = os.clock()
					if now - (splashed[crosser] or 0) > 1.2 then
						splashed[crosser] = now
						splash:Emit(22)
					end
				end
				firePenalty(hit, moatPenalty)
			end)
		end

		channel(Vector3.new(0, 0, -backMid), reach * 2, true)
		channel(Vector3.new(-mid, 0, sideMoatCentre), sideMoatLength, false)
		channel(Vector3.new(mid, 0, sideMoatCentre), sideMoatLength, false)

		-- The causeway is driveway-width, NOT gate-width. The driveway has to
		-- stay dry at every tier or the top tier drowns its own entrance, and
		-- widening a bridge does not widen the gate behind it, so this costs
		-- the defender nothing.
		local causeway = math.max(gate, Config.DRIVEWAY_WIDTH + 1)
		local moatWing = reach - causeway / 2
		if moatWing > 0 then
			local offset = causeway / 2 + moatWing / 2
			channel(Vector3.new(-offset, 0, frontMid), moatWing, true)
			channel(Vector3.new(offset, 0, frontMid), moatWing, true)
		end

		-- The rim, laid as TWO CLOSED RECTANGLES rather than a pair of kerbs
		-- per band.
		--
		-- Per band was the obvious way and it was wrong: the bands overlap at
		-- the four corners, so each one's kerb ran straight across its
		-- neighbour's water and the moat came out with stone bars lying
		-- across it like cattle grids. The ring does not care how the water
		-- was cut up -- there is an outer edge and an inner edge, and the
		-- kerb belongs on those.
		-- Three pairs, because the ring is a RECTANGLE and its three edges are
		-- now three different distances from the plot centre: the sides off the
		-- half width, the front off the front line, the back off YARD_DEPTH.
		-- The front pair used to be copied from the side pair, which was right
		-- only while the plot was square.
		local outerX, innerX = reach + BANK_W / 2, (half + 0.5) - BANK_W / 2
		local outerFrontZ, innerFrontZ = frontReach + BANK_W / 2, (frontZ + 0.5) - BANK_W / 2
		local outerBackZ, innerBackZ = -(backReach + BANK_W / 2), -((backZ + 0.5) - BANK_W / 2)

		-- Parameters named for the EDGE they are, not `frontZ`/`backZ`: those
		-- are now real values in the enclosing scope and shadowing them here
		-- would make this function read as though it used them.
		local function rim(x: number, frontEdge: number, backEdge: number)
			local span = frontEdge - backEdge
			local midZ = (frontEdge + backEdge) / 2
			-- Sides run the full depth; overlong by a kerb width at each end
			-- so the corners close square instead of showing a notch.
			for _, s in ipairs({ -1, 1 }) do
				bank(Vector3.new(s * x, 0, midZ), span + BANK_W, false)
			end
			bank(Vector3.new(0, 0, backEdge), x * 2, true)

			-- The front run is the only one with a hole in it, and it is the
			-- same hole the water leaves: the causeway.
			local wing = x - causeway / 2
			if wing > 0 then
				local offset = causeway / 2 + wing / 2
				bank(Vector3.new(-offset, 0, frontEdge), wing, true)
				bank(Vector3.new(offset, 0, frontEdge), wing, true)
			else
				bank(Vector3.new(0, 0, frontEdge), x * 2, true)
			end
		end

		rim(outerX, outerFrontZ, outerBackZ)
		rim(innerX, innerFrontZ, innerBackZ)
	end

	-- THE BORDER FOLLOWS THE FENCE, WHICH IS WHY IT IS NOT BUILT WITH THE
	-- ORNAMENTS. Both the height clamp and the gate opening come off the tier,
	-- so a fence upgrade that did not put the border back would leave last
	-- tier's planting standing across this tier's gate -- and an upgrade that
	-- rebuilt it too early would clamp against the tier being replaced.
	--
	-- Last line rather than first: `refreshBorder` reads `plot.fenceLevel`,
	-- which this call sets at the top, and it must run after the
	-- `ClearAllChildren` that opens the function rather than before it.
	PlotService.refreshBorder(plot)
end

-- ============================================================
-- THE GATE JAM
-- ============================================================
--
-- A thief drops this behind them on the way OUT. See `Config.GATE_JAM` for
-- why it is a snag rather than a wall, and why it is the inversion of the
-- owner-locked gate this design refused.
--
-- JAMMED ON THE WAY OUT, NEVER ON THE WAY IN. Jamming it on the approach
-- would lock the thief IN with the dog, which is funny once and then just
-- a mechanic nobody presses.
local jammed: { [number]: number } = {}

-- Is this plot's gate jammed right now? Asked by the prompt so it cannot be
-- double-paid, and by the volume so it stops snagging when it lapses.
function PlotService.isGateJammed(plot: any): boolean
	return os.clock() < (jammed[plot.index] or 0)
end

-- Stands a jam across the gate mouth for `Config.GATE_JAM.seconds`.
--
-- The gate is the GAP the front barrier leaves: two wings either side of a
-- `tier.gate`-wide opening centred on the plot's own x, at `PLOT_FRONT_LINE`.
-- So the jam is exactly that opening, and it is built from the plot's own
-- numbers rather than a remembered size -- a gate is 24 studs at Rickety and
-- 8 at the Moat, and a jam sized for one would leave a walkable gap at the
-- other.
function PlotService.jamGate(plot: any): boolean
	if PlotService.isGateJammed(plot) then
		return false
	end
	-- Indexed the same way `buildFence` does rather than through an accessor
	-- that does not exist: a level of 0 is a plot with no fence at all, and
	-- `FENCE_TIERS` is 1-based.
	local level = plot.fenceLevel or 0
	local tier = if level > 0
		then Config.FENCE_TIERS[math.clamp(level, 1, #Config.FENCE_TIERS)]
		else nil
	if not tier then
		-- NOTHING TO JAM ON A PLOT WITH NO FENCE. A bare plot has no gate,
		-- because it has no barrier for a gate to be a gap in -- so this is a
		-- refusal rather than an invisible no-op.
		return false
	end

	jammed[plot.index] = os.clock() + Config.GATE_JAM.seconds

	local width = tier.gate
	local height = tier.top
	local bar = Instance.new("Part")
	bar.Name = "GateJam"
	bar.Size = Vector3.new(width, height, 1)
	bar.CFrame = plot.cframe * CFrame.new(0, FENCE_BASE_Y + height / 2, Config.PLOT_FRONT_LINE)
	bar.Anchored = true
	-- NON-COLLIDING, WHICH IS THE WHOLE OWNER EXEMPTION. See Config: a solid
	-- part cannot tell one player from another, so the gate stays passable
	-- and passing it is what costs.
	bar.CanCollide = false
	bar.CanQuery = false
	bar.CastShadow = false
	bar.Color = Color3.fromRGB(214, 176, 72)
	bar.Material = Enum.Material.SmoothPlastic
	bar.Transparency = 0.35
	bar.Parent = plot.fence or plot.model

	local penalty = {
		label = "Jammed gate",
		slow = Config.GATE_JAM.slow,
		duration = Config.GATE_JAM.duration,
		stun = 0,
	}

	-- ONE CHARGE PER CROSSING, and this is the fence penalty's own lesson
	-- rather than a new one. `Touched` re-fires per character part -- measured
	-- at fourteen on the first contact frame -- so without a stamp the slow
	-- re-applies faster than it can expire, which is the freeze that once
	-- shipped on the electric fence.
	local charged: { [Player]: number } = {}
	bar.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character or not character:FindFirstChildOfClass("Humanoid") then
			return
		end
		local crosser = Players:GetPlayerFromCharacter(character)
		-- THE OWNER IS NEVER AFFECTED, and the precedent is exact:
		-- `firePenalty` returns early for the plot's own owner because owners
		-- cross their own defences freely, they paid for them. Here it is
		-- stronger than a courtesy -- a jam that could shut a child out of
		-- their own garden is the griefing case, and this kills it outright
		-- rather than making it merely unrewarding.
		if not crosser or crosser == plot.owner then
			return
		end
		if not PlotService.isGateJammed(plot) then
			return
		end
		local now = os.clock()
		if now < (charged[crosser] or 0) then
			return
		end
		charged[crosser] = now + penalty.duration + Config.FENCE_PENALTY_GRACE
		for _, callback in ipairs(fencePenaltyHandlers) do
			task.spawn(callback, crosser, plot, penalty)
		end
	end)

	task.delay(Config.GATE_JAM.seconds, function()
		if bar.Parent then
			bar:Destroy()
		end
	end)
	return true
end
-- WHO DECIDES WHETHER A JAM IS ALLOWED, and it is not this file.
--
-- Whether somebody is carrying loot, and whether they can pay, are
-- HeistService's and DataService's questions -- and HeistService already
-- requires PlotService, so asking directly would be a cycle. Same registry
-- shape as `registerBounceVeto` and `SetService.registerPusher`, and for the
-- same reason: it keeps the dependency list at one line and makes the cycle
-- impossible rather than merely absent today.
local jamHandlers: { (Player, any) -> () } = {}

function PlotService.onGateJam(callback: (Player, any) -> ())
	table.insert(jamHandlers, callback)
end

function PlotService.fireGateJam(player: Player, plot: any)
	for _, callback in ipairs(jamHandlers) do
		task.spawn(callback, player, plot)
	end
end

function PlotService.onFencePenalty(callback: (Player, any, any) -> ())
	table.insert(fencePenaltyHandlers, callback)
end

-- Rebuilt from scratch on every change, unlike the dog. House tiers differ in
-- footprint, storey count and which details exist at all, so there is no
-- shared skeleton to resize -- and this runs once per purchase, not per frame.
--
-- Sits well behind the plot: clear of the fence at 25.6 and a top-tier moat at
-- 31.1, facing the street so the front is what the road sees.
-- Rebuilds the whole ornament set. Cheap enough to redo wholesale on each
-- purchase, and wholesale avoids having to diff slots.
-- DECLARED ABOVE `setDecor`, WHICH IS ITS FIRST CALLER, AND THAT PLACEMENT IS
-- LOAD-BEARING. A `local` declared after a function that reads it does not
-- error in Luau -- it compiles as a nil GLOBAL and dies at the call naming
-- nothing useful. This file has lost six bugs to exactly that, and this block
-- was written 300 lines lower down before the line numbers gave it away.

-- ============================================================
-- TRAMPOLINES
-- ============================================================
--
-- The first decoration that does anything, and everything below exists to keep
-- it from being a power item.
--
-- IT MUST NOT CHANGE AN OUTCOME -- not the steal, the chase, the tag or the
-- getaway. A bounce is a toy. That is asserted twice over: once by making it
-- vertical only, and once by the veto below, which is what turns "it should
-- not matter in a chase" from an argument into a fact.
--
-- THE MAT IS A TRIGGER, NOT A SURFACE. Every ornament in this game is
-- CanCollide and CanQuery off, because they sit on the exact ground a defender
-- defends and a thief runs across. `Touched` fires on overlap without needing
-- collision, so that rule is untouched: a trampoline can never body-block
-- anybody and can never be stood behind as cover.
--
-- FOUND BY TAG, NEVER BY A LIST COLLECTED AT STARTUP. A plot's decor is torn
-- down and rebuilt every time an owner buys or puts away an ornament, so there
-- is no single moment at which trampolines could be enumerated -- the same
-- reason the moat's bands are tagged.
local bouncedAt: { [Player]: number } = {}
local bounceVetoes: { (Player) -> boolean } = {}

-- Registered by Main, for the reason SetService.registerPusher is: asking
-- "is this player carrying loot" means asking HeistService, and HeistService
-- already requires this file. A registry keeps the dependency list at one line
-- and makes the cycle impossible rather than merely absent today.
function PlotService.registerBounceVeto(fn: (Player) -> boolean)
	table.insert(bounceVetoes, fn)
end

local function bounce(hit: BasePart)
	local character = hit.Parent
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	-- Anything mid-heist is refused outright. This is the line that keeps a
	-- decoration out of the balance: a thief carrying somebody's coins cannot
	-- be launched, so the trampoline cannot lengthen a getaway, break a tag or
	-- get anyone over anything while it matters.
	for _, veto in ipairs(bounceVetoes) do
		if veto(player) then
			return
		end
	end

	local now = os.clock()
	if bouncedAt[player] and (now - bouncedAt[player]) < Config.TRAMPOLINE_COOLDOWN then
		return
	end
	bouncedAt[player] = now

	-- HANDED TO THE CLIENT, because a character's physics belong to the client
	-- that owns it and a server-side velocity write on somebody's root is
	-- simply discarded. Measured on a live rig: a raw write, a write after
	-- ChangeState(Jumping) and a write after ChangeState(Freefall) all left the
	-- character at exactly its 5.00-stud drop height. The server still owns the
	-- DECISION -- which mat, which player, the cooldown and the veto above are
	-- all decided here and none of it is sent.
	--
	-- The wheelie bin's exit hop gets away with a server write because it
	-- happens in the frame the root is unanchored, which is the one moment the
	-- server has authority over that assembly.
	Remotes.get("TrampolineBounce"):FireClient(player)
end

local function bindTrampoline(mat: Instance)
	if mat:IsA("BasePart") then
		mat.Touched:Connect(bounce)
	end
end

-- BOUND BY WALKING THE MODEL, NOT BY `GetInstanceAddedSignal`, AND THAT IS NOT
-- A PREFERENCE -- the signal version silently never fires.
--
-- `Decor.build` creates its Model DETACHED, runs every builder into it, and
-- parents it to the plot at the very end. So the tag is added while the part
-- is outside the DataModel, and CollectionService's added-signal only fires
-- for instances inside it. Measured: the mat was tagged, `GetTagged` returned
-- it, `Touched` fired fifteen times, and the handler had never been connected.
--
-- Note the moat does NOT have this problem and looked like a precedent for
-- doing it the other way: it parents each band to `plot.fence` as it builds,
-- and that folder is already in the world. Anything tagged inside a detached
-- model has to be bound after it lands.
local function bindTrampolinesIn(model: Instance)
	for _, d in ipairs(model:GetDescendants()) do
		if CollectionService:HasTag(d, Decor.TRAMPOLINE_TAG) then
			bindTrampoline(d)
		end
	end
end

-- ============================================================
-- THE GARDEN
-- ============================================================
--
-- HOW FAR INSIDE THE FENCE A BORDER STANDS, and it is the tightest clearance
-- on the lawn rather than a number chosen for looks.
--
-- The side fences run at `PLOT_HALF_WIDTH` and the outer ornament slots sit
-- at x +-25, so the free ground between them is what a border has to fit in.
-- The widest ornament in the game is the Shark In Trainers at 13.70 -- itself
-- a figure this project had to re-measure once, having spent months believing
-- the tube man's HEIGHT was a width -- so an ornament in a side slot reaches
-- to 31.85 and the fence line is 33.60. That is 1.75 studs, and everything
-- about the border's depth is solved inside it.
--
-- MEASURED ON A LIVE PLOT WITH THE WIDEST ORNAMENT IN EVERY SIDE SLOT AT
-- ONCE, which is the same check the slot grid itself was verified with.
local BORDER_INSET = 1.0
-- How far back the side runs go. The back ornament row is at z -20, so this
-- clears it and stops where the lawn does -- there is no point planting the
-- sixty studs of yard behind the house, which no camera in this game ever
-- sees and which would triple the part count to do it.
local BORDER_BACK = -22

-- Where the walk starts and stops. It runs UP THE CENTRE LINE, because that
-- is where the gate is at every tier -- the opening narrows from 24 studs to
-- 8 as the fence is upgraded, and x 0 is inside all five.
local PATH_FROM = Config.PLOT_FRONT_LINE - 2
-- Short of the animal rather than under it: the pig is twelve studs across,
-- so a slab any nearer is roofed by the thing it leads to.
local PATH_TO = 7.5

-- The stretches of fence worth planting, in plot-local studs.
--
-- FRONT WINGS AND THE SIDES, NEVER THE BACK. A border is looked at from the
-- pavement, and the back fence is ninety studs away behind a house -- so
-- planting it is parts nobody will ever see. This is the same call
-- `buildStreetTrees` makes about which side of a trunk gets detail.
local function borderRuns(plot: Plot): { { a: Vector3, b: Vector3 } }
	local tier = Config.FENCE_TIERS[math.clamp(plot.fenceLevel, 1, #Config.FENCE_TIERS)]
	local half = Config.PLOT_HALF_WIDTH - BORDER_INSET
	local frontZ = Config.PLOT_FRONT_LINE - BORDER_INSET
	-- Clear of the gate opening by a stud, so a border never grows across the
	-- one way in. The gate is 24 studs at Rickety and 8 at the Moat, so this
	-- has to come off the tier rather than off a constant.
	local gateEdge = tier.gate / 2 + 1

	local runs = {}
	if half > gateEdge then
		table.insert(runs, { a = Vector3.new(-half, 0, frontZ), b = Vector3.new(-gateEdge, 0, frontZ) })
		table.insert(runs, { a = Vector3.new(gateEdge, 0, frontZ), b = Vector3.new(half, 0, frontZ) })
	end
	table.insert(runs, { a = Vector3.new(-half, 0, frontZ), b = Vector3.new(-half, 0, BORDER_BACK) })
	table.insert(runs, { a = Vector3.new(half, 0, frontZ), b = Vector3.new(half, 0, BORDER_BACK) })
	return runs
end

-- Rebuilt whenever the FENCE changes, because the clamp and the gate both
-- come off the tier. Called from `buildFence` as well as from `setGarden`.
function PlotService.refreshBorder(plot: Plot)
	if plot.border then
		plot.border:Destroy()
		plot.border = nil
	end
	local key = plot.garden and plot.garden.border
	local spec = if type(key) == "string" then Config.BORDER_PLANTS[key] else nil
	-- A border needs a fence to stand along. At level 0 there is no fence and
	-- no `decorTop` to clamp against, and a row of plants floating on the line
	-- where a fence WOULD be is a cosmetic implying a tier -- the one rule
	-- every phase of the yard plan re-reads.
	if not spec or plot.fenceLevel <= 0 then
		return
	end
	plot.border = Decor.buildBorder(spec, Config.borderHeight(spec, plot.fenceLevel),
		borderRuns(plot), plot.cframe, Config.PLOT_SIZE.Y / 2, plot.model)
end

-- Rebuilt whenever the HOUSE changes, because `setHouseLevel` destroys the
-- model the boxes are hung on and a box left behind would be a planter
-- floating where a window used to be.
function PlotService.refreshWindowBoxes(plot: Plot)
	if plot.windowBoxes then
		plot.windowBoxes:Destroy()
		plot.windowBoxes = nil
	end
	local key = plot.garden and plot.garden.window
	local spec = if type(key) == "string" then Config.WINDOW_BOXES[key] else nil
	if not spec or not plot.house then
		return
	end
	plot.windowBoxes = Decor.buildWindowBoxes(spec, plot.house, plot.model)
end

-- WHAT THE OWNER HAS EQUIPPED, AND THE ONE PLACE ALL THREE ARE PUT UP.
--
-- Sticky on the plot, so the two functions that destroy garden geometry for
-- their own reasons can put it back without being told what it was.
function PlotService.setGarden(plot: Plot, garden: any?)
	plot.garden = garden

	if plot.gardenPath then
		plot.gardenPath:Destroy()
		plot.gardenPath = nil
	end
	local pathKey = garden and garden.path
	local pathSpec = if type(pathKey) == "string" then Config.GARDEN_PATHS[pathKey] else nil
	if pathSpec then
		-- No fence test here, unlike the border. A path is laid on the ground
		-- and hides nothing, so it is legal on a bare plot -- and it is the one
		-- garden item a brand new player can put down and see.
		plot.gardenPath = Decor.buildPath(pathSpec, PATH_FROM, PATH_TO,
			plot.cframe, Config.PLOT_SIZE.Y / 2, plot.model)
	end

	PlotService.refreshBorder(plot)
	PlotService.refreshWindowBoxes(plot)
end

function PlotService.setDecor(plot: Plot, placed: { [string]: string })
	plot.decorPlaced = placed
	if plot.decor then
		plot.decor:Destroy()
		plot.decor = nil
	end
	-- Three different floors, one per zone: the lawn is the top of the plot
	-- slab, the driveway is paving laid on the world ground, and the verge is
	-- the bare world ground. Passing a single height left everything outside
	-- the fence floating.
	local worldGround = -Config.PLOT_SIZE.Y / 2
	-- `plot.trophies` is the four trophy builders' own state and is nil on
	-- every plot that has never had an owner -- a resident's lawn, a shop
	-- shop, an empty plot. `Decor.build` treats a nil as a showroom, which
	-- is the right answer for a shop card and would be the wrong one on a
	-- lawn; nothing without an owner can have a trophy placed on it, so
	-- the case never arises. See Config.DECOR_ITEMS.
	plot.decor = Decor.build(placed, plot.cframe, {
		lawn = Config.PLOT_SIZE.Y / 2,
		driveway = worldGround + DRIVEWAY_LIFT,
		verge = worldGround,
	}, plot.model, plot.trophies, plot.skinKey)

	-- Anything functional in that model gets hooked up now that it is in the
	-- world. This runs on every decor change rather than once at startup,
	-- because a lawn is torn down and rebuilt whenever an owner buys or puts
	-- away an ornament -- there is no single moment at which they could all be
	-- collected. See bindTrampolinesIn for why a tag signal cannot do this.
	bindTrampolinesIn(plot.decor)
end

-- What the four trophy ornaments are shaped like, and a rebuild to show
-- it. Called by TrophyService whenever one of the numbers underneath
-- moves -- a skin robbed, a thief stopped, a patrol outrun.
--
-- IT REBUILDS THE WHOLE LAWN, which is what `setDecor` already does on
-- every purchase and put-away. A trophy changes shape a handful of times
-- an hour at most, and diffing one ornament out of a model would be
-- bookkeeping to save work nobody can measure -- the same call
-- `applyAccessories` makes about the pig's hats.
function PlotService.setTrophyState(plot: Plot, state: any?)
	plot.trophies = state
	local placed = plot.decorPlaced
	if placed then
		PlotService.setDecor(plot, placed)
	end
end

-- The strip of paving from the gate out to the kerb, surfaced by house tier.
--
-- Lives on the plot rather than in the neighbourhood scenery because it is
-- per-owner: it is the one part of the house upgrade visible from the road,
-- since the house itself stands 70 studs behind the piggy.
local function buildDriveway(plot: Plot, tier: any)
	local existing = plot.model:FindFirstChild("Driveway")
	if existing then
		existing:Destroy()
	end

	local drive = tier.drive
	if not drive then
		return
	end

	local m = Config.streetMetrics()
	local length = m.driveFar - m.driveNear
	if length <= 0 then
		return
	end

	local model = Instance.new("Model")
	model.Name = "Driveway"

	local function slab(name: string, size: Vector3, offset: Vector3, colour: Color3, material: Enum.Material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = plot.cframe * CFrame.new(offset)
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Color = colour
		p.Material = material
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	-- Same lift discipline as the road: the top face must clear the grass, or
	-- two coplanar surfaces z-fight and the lawn flickers through the paving.
	local groundY = -Config.PLOT_SIZE.Y / 2
	local thickness = 0.8
	local centreZ = (m.driveNear + m.driveFar) / 2

	slab("Surface", Vector3.new(Config.DRIVEWAY_WIDTH, thickness, length),
		Vector3.new(0, groundY + DRIVEWAY_LIFT - thickness / 2, centreZ), drive.colour, drive.material)

	if drive.edge then
		for _, side in ipairs({ -1, 1 }) do
			slab("Edge", Vector3.new(0.7, thickness, length),
				Vector3.new(side * (Config.DRIVEWAY_WIDTH / 2 - 0.35), groundY + DRIVEWAY_LIFT + 0.04 - thickness / 2, centreZ),
				Color3.fromRGB(228, 226, 218), Enum.Material.Concrete)
		end
	end

	if drive.lit then
		for _, side in ipairs({ -1, 1 }) do
			slab("DriveLight", Vector3.new(0.35, thickness, length - 2),
				Vector3.new(side * (Config.DRIVEWAY_WIDTH / 2 - 1.2), groundY + DRIVEWAY_LIFT + 0.08 - thickness / 2, centreZ),
				Color3.fromRGB(240, 202, 110), Enum.Material.Neon)
		end
	end

	model.Parent = plot.model
end

-- Is this world position inside anybody's yard?
--
-- The yard is the fence rectangle, not the plot slab: `half` in front and to
-- the sides, YARD_DEPTH behind, all in plot-local space, which is the same
-- rectangle buildFence runs its barriers around. Measuring from the slab
-- instead would call the whole back garden public ground -- the exact mistake
-- that put the grove inside people's fences.
--
-- Returns the plot, so a caller can tell "my own lawn" from "someone else's".
-- Nothing uses that yet; RideService only cares that it is somebody's.
-- ============================================================
-- LADDERS
-- ============================================================
--
-- A player-placed climbing point, standing for `Config.LADDER.seconds`.
--
-- THE CALLER SENDS NO POSITION, AND THAT IS THE LOAD-BEARING HALF OF LETTING
-- IT GO ANYWHERE. "Anywhere along the fence" is the whole appeal and a
-- coordinate on the wire is the obvious way to build it -- and then there is
-- one to forge and a range check to defeat, which is the exact trade
-- `BoneThrow` and `GadgetThrow` already refuse. So this takes the PLAYER and
-- reads their own character position: you choose the spot by standing there,
-- the server projects that onto the nearest segment, and the click means "use
-- it" rather than "use it there".
--
-- Returns the ladder, or nil AND A REASON CODE. The code is a machine word
-- rather than a sentence, because the wording belongs to the item's own
-- service -- the same split `CosmeticsService.awardTokens` draws with its
-- optional `why`.

type PlacedLadder = {
	model: Model,
	player: Player,
	expiresAt: number,
}

local ladders: { PlacedLadder } = {}
local ladderOf: { [Player]: Model } = {}

local function retireLadder(model: Model?)
	if not model then
		return
	end
	for i = #ladders, 1, -1 do
		if ladders[i].model == model then
			ladderOf[ladders[i].player] = nil
			table.remove(ladders, i)
		end
	end
	model:Destroy()
end

function PlotService.clearLadder(player: Player)
	retireLadder(ladderOf[player])
end

-- The segment of `plot`'s fence nearest `position`, the point on it, and how
-- far away it is. All of it in PLOT-LOCAL space, where the rectangle is
-- axis-aligned and the far row's half-turn has already been dealt with -- the
-- same frame `yardContaining` works in and for the same reason.
local function nearestSegment(plot: Plot, position: Vector3): (Vector3?, number, boolean)
	local margin = Config.LADDER.margin
	local here = plot.cframe:PointToObjectSpace(position)
	local best, bestDist, bestAlongX = nil, math.huge, true

	for _, part in ipairs(plot.fence:GetChildren()) do
		if part:IsA("BasePart") and part.Name == "Barrier" then
			local alongX = part:GetAttribute("AlongX")
			local span = part:GetAttribute("Span")
			if type(alongX) == "boolean" and type(span) == "number" then
				local centre = plot.cframe:PointToObjectSpace(part.Position)
				-- Clamped to the segment's own ends, less a margin, so a
				-- ladder cannot be wedged into the corner where two barriers
				-- meet and come out climbable from neither side.
				local reach = math.max(span / 2 - margin, 0)
				local point
				if alongX then
					point = Vector3.new(
						math.clamp(here.X, centre.X - reach, centre.X + reach), 0, centre.Z)
				else
					point = Vector3.new(
						centre.X, 0, math.clamp(here.Z, centre.Z - reach, centre.Z + reach))
				end
				-- Horizontal only. The player is standing on the lawn or on
				-- the street, a stud apart, and that difference is not a
				-- reason to prefer one segment over another.
				local d = (Vector3.new(here.X, 0, here.Z) - point).Magnitude
				if d < bestDist then
					best, bestDist, bestAlongX = point, d, alongX
				end
			end
		end
	end
	return best, bestDist, bestAlongX
end

function PlotService.placeLadder(player: Player): (Model?, string?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil, "nocharacter"
	end

	local bestPlot, bestPoint, bestDist, bestAlongX = nil, nil, math.huge, true
	for _, plot in ipairs(plots) do
		if plot.fenceLevel > 0 then
			local point, d, alongX = nearestSegment(plot, root.Position)
			if point and d < bestDist then
				bestPlot, bestPoint, bestDist, bestAlongX = plot, point, d, alongX
			end
		end
	end

	if not bestPlot or not bestPoint or bestDist > Config.LADDER.reach then
		return nil, "nofence"
	end

	local tier = Config.FENCE_TIERS[math.clamp(bestPlot.fenceLevel, 1, #Config.FENCE_TIERS)]
	-- ASKED OF THE TIER, NEVER OF THE HEIGHT. `isClimbedFence` is the same
	-- test the jump split is drawn with, so a ladder can never be refused on
	-- a fence somebody genuinely cannot hop, or allowed on one they can.
	if not Config.isClimbedFence(tier) then
		return nil, "hoppable"
	end

	retireLadder(ladderOf[player])

	local height = tier.top + Config.LADDER.overhang
	local model = ThiefModel.buildLadder(height)

	-- SQUARE TO THE FENCE, off the axis the chosen segment was BUILT on.
	-- A ladder is authored flat in its own X and Y, so a segment running
	-- along X needs no turn and one running along Z needs a quarter. The axis
	-- is carried back from `nearestSegment` rather than inferred from the
	-- point: a back fence and a side fence can share a coordinate, and
	-- guessing gets one of them a ladder lying across the fence.
	local yaw = if bestAlongX then CFrame.new() else CFrame.Angles(0, math.rad(90), 0)

	local seat = bestPlot.cframe
		* CFrame.new(Vector3.new(bestPoint.X, FENCE_BASE_Y + height / 2, bestPoint.Z))
		* yaw
	model:PivotTo(seat)

	-- WHAT ACTUALLY CLIMBS. The ladder is decoration, exactly like the fence
	-- it stands against: an invisible TrussPart inside it does the work, and
	-- it is climbed natively at a fixed fraction of WalkSpeed, so the climb
	-- inherits every speed rule through `HeistService.currentSpeed` with no
	-- movement code of its own.
	--
	-- It STRADDLES the barrier, so one ladder serves both ways over. A truss
	-- is locked to a 2x2 cross-section whatever is asked for, which is why
	-- the visible ladder is separate geometry rather than the truss itself.
	local truss = Instance.new("TrussPart")
	truss.Name = "Rungs"
	truss.Size = Vector3.new(2, height, 2)
	truss.CFrame = seat
	truss.Anchored = true
	truss.CanCollide = true
	truss.CanQuery = false
	truss.Transparency = 1
	truss.Parent = model

	-- Parented to the plot's own fence folder, so a rebuild or a release
	-- takes the ladder with it. The sweep below notices by asking whether the
	-- model still has a parent rather than by being told.
	model.Parent = bestPlot.fence

	table.insert(ladders, {
		model = model,
		player = player,
		expiresAt = os.clock() + Config.LADDER.seconds,
	})
	ladderOf[player] = model
	return model, nil
end

function PlotService.yardContaining(position: Vector3): Plot?
	-- TWO numbers, not one. `half` served as both the X extent and the front Z
	-- while the plot was square; the rectangle is 64 x 48 now, so a single
	-- value would test a square that is neither the fence nor the slab.
	local halfWidth = Config.PLOT_HALF_WIDTH
	local frontZ = Config.PLOT_FRONT_LINE

	for _, plot in ipairs(plots) do
		-- A SHOP HAS NO YARD, AND SKIPPING IT IS A FIX RATHER THAN A
		-- TIDY-UP. This rectangle is 64 by 122 studs, sized to a plot's fence
		-- -- so a shop plot, whose frame is the middle of an 18 by 14 room on
		-- the verge, would have claimed a yard reaching across the pavement,
		-- over the kerb and out into the carriageway, and the first plot in
		-- this list to match wins.
		--
		-- What that would have cost: this is the ride gate's veto and the
		-- fence penalty's owner test, so rides would have switched
		-- themselves off across a third of the street and the dog watcher
		-- would have had players standing in a yard that is not there.
		--
		-- Skipping is also the honest answer rather than merely the cheap
		-- one: a yard is the ground inside a fence, a shop has no fence, and
		-- the verge it stands on is street -- which `Config.isOnStreet`
		-- already says, and this must not contradict.
		if plot.shop then
			continue
		end

		-- Into plot-local space, where the rectangle is axis-aligned and the
		-- far row's half-turn has already been taken care of.
		local local_ = plot.cframe:PointToObjectSpace(position)
		if math.abs(local_.X) <= halfWidth
			and local_.Z <= frontZ
			and local_.Z >= -Config.YARD_DEPTH
		then
			return plot
		end
	end
	return nil
end

function PlotService.setHouseLevel(plot: Plot, level: number)
	if plot.house then
		plot.house:Destroy()
		plot.house = nil
	end
	-- The boxes hang off `Sill` parts inside the model being destroyed on the
	-- line above, so they have to come down with it and go back up against the
	-- new one. Done here rather than left to the next `applyToPlot`, because a
	-- house tier can be bought without anything else about the plot changing.
	local groundY = -Config.PLOT_SIZE.Y / 2
	-- Passed the PLOT ORIGIN, not a pre-computed spot: House.build measures
	-- what it actually built and seats itself against the back fence, because
	-- the archetypes range from 15 to 47 studs deep.
	plot.house = House.build(level, plot.cframe * CFrame.new(0, groundY, 0), plot.model)
	buildDriveway(plot, Config.getHouseTier(level))
	PlotService.refreshWindowBoxes(plot)
end

function PlotService.setDogLevel(plot: Plot, level: number)
	GuardDog.applyTier(plot.dog, level)
end

-- The coat the dog is wearing, or "" for the breed's own colours.
--
-- A thin pass-through for the same reason `setDogLevel` is one: `CosmeticsService`
-- owns what a plot should look like and `GuardDog` owns what a dog IS, and the
-- plot is the only thing that knows which dog belongs to which player. Reaching
-- through `plot.dog` from CosmeticsService would put that knowledge in a second
-- place.
--
-- A COAT IS PURE APPEARANCE AND MUST NEVER REACH THE TIER. `GuardDog.setCoat`
-- repaints through `applyTier` and touches `fur`, `furDark` and `collar` only --
-- never `scale` or `shape`, which are what a thief reads to price the risk. See
-- the header on `Config.DOG_COATS`.
function PlotService.setDogCoat(plot: Plot, key: string?)
	GuardDog.setCoat(plot.dog, key)
end

-- The kennel's skin. Walls and trim only -- the roof follows the coat, so a
-- kennel and a coat are two channels of one object and neither can overwrite
-- the other. See `Config.DOG_KENNELS`.
function PlotService.setDogKennel(plot: Plot, key: string?)
	GuardDog.setKennel(plot.dog, key)
end

-- Which toys are standing on the lawn. The whole set every time rather than
-- one key, because that is the shape the save has -- see `GuardDog.setToys`.
function PlotService.setDogToys(plot: Plot, out: { [string]: boolean }?)
	GuardDog.setToys(plot.dog, out)
end

-- The dog's name, on the nameplate and painted on its kennel.
--
-- ALREADY FILTERED before it gets this far -- `CosmeticsService.nameDog` owns
-- the `TextService` call and is the only thing that should ever reach either
-- this or `GuardDog.setName`. Nothing in this file inspects the string, which
-- is correct: a second place that "handles" moderation is how one of them ends
-- up being the one everybody trusts and nobody runs.
function PlotService.setDogName(plot: Plot, name: string?)
	GuardDog.setName(plot.dog, name)
end

-- Publishes the owner's lock level as an attribute, which is now the ONLY
-- place it is published.
--
-- It used to be baked into the steal prompt's HoldDuration as well, and the
-- attribute existed because the client re-times its own prompt for its
-- lockpicks: inferring the level from a duration it also writes meant reading
-- a number it owned, and a server change after that read would be clobbered
-- by the stale copy.
--
-- The duration is a flat Config.CRACK.openHold now and carries no level at
-- all -- the Vault Lock tree buys narrower zones in the crack instead -- so
-- the attribute is not merely the tidier source, it is the only one. Anything
-- that wants to know how good a lock is asks the plot.
function PlotService.setLockLevel(plot: Plot, level: number)
	plot.model:SetAttribute(Config.PLOT_LOCK_ATTRIBUTE, level)
	PiggyBank.setLockLevel(plot.piggy, level)
end

-- SOMEBODY ON THIS PLOT JUST REBIRTHED, and the street gets told.
--
-- Two attributes and nothing else: the server's whole share of this
-- feature is bumping a number, and every client builds the show for
-- itself. Same division of labour as the animated skins, the moat and
-- `HouseFX`, and for the same measured reason -- driving a hundred parts
-- of tween from here would replicate a property write per part per frame
-- to say what one number says.
--
-- THE RANK IS WRITTEN FIRST AND THE COUNTER SECOND, because the counter
-- is what `Fireworks` watches. Written the other way round, a client
-- would wake on the counter and read a rank belonging to the PREVIOUS
-- rebirth -- one shell short, every time, with nothing erroring and
-- nothing to notice.
function PlotService.fireFireworks(plot: Plot, rebirths: number)
	plot.model:SetAttribute(Config.PLOT_FIREWORK_RANK_ATTRIBUTE, rebirths)
	local count = plot.model:GetAttribute(Config.PLOT_FIREWORK_ATTRIBUTE)
	plot.model:SetAttribute(Config.PLOT_FIREWORK_ATTRIBUTE,
		(if type(count) == "number" then count else 0) + 1)
end

-- Shakes the padlock while a thief is working on it.
function PlotService.rattleLock(plot: Plot)
	PiggyBank.rattleLock(plot.piggy)
end

-- ============================================================
-- VISUALS
-- ============================================================

-- Returns how many coins newly appeared, so callers can decide whether that
-- deserves a sound.
function PlotService.updatePile(plot: Plot, vault: number, capacity: number): number
	-- Published here rather than at the call sites because this is the one
	-- function every path already goes through -- the accrual tick, a steal, a
	-- delivery, and `release` zeroing an abandoned plot. See
	-- Config.PLOT_VAULT_ATTRIBUTE for why a thief is allowed to read it.
	plot.model:SetAttribute(Config.PLOT_VAULT_ATTRIBUTE, math.floor(vault))
	return PiggyBank.setFill(plot.piggy, vault, capacity)
end

-- The plaster. Stamped on the plot as Config.PLOT_ROBBED_ATTRIBUTE in server
-- time so a client can read it, and cleared by whichever stamp is latest --
-- a second robbery inside the window extends the mark rather than letting
-- the first timer pull it off early.
function PlotService.setRobbed(plot: Plot, seconds: number)
	local until_ = workspace:GetServerTimeNow() + seconds
	plot.model:SetAttribute(Config.PLOT_ROBBED_ATTRIBUTE, until_)
	PiggyBank.setRobbed(plot.piggy, true)
	task.delay(seconds, function()
		if plot.model:GetAttribute(Config.PLOT_ROBBED_ATTRIBUTE) == until_ then
			plot.model:SetAttribute(Config.PLOT_ROBBED_ATTRIBUTE, nil)
			PiggyBank.setRobbed(plot.piggy, false)
		end
	end)
end

function PlotService.playCoinDrop(plot: Plot)
	PiggyBank.playCoinDrop(plot.piggy)
end

function PlotService.playMilestone(plot: Plot, index: number, total: number)
	PiggyBank.playMilestone(plot.piggy, index, total)
end

function PlotService.playBank(plot: Plot)
	PiggyBank.playBank(plot.piggy)
end

function PlotService.playAlarm(plot: Plot)
	PiggyBank.playAlarm(plot.piggy)
end

-- The sign advertises the skin as well as the rebirth count -- a cosmetic
-- nobody can identify from a distance isn't worth grinding for.
-- The sign is the only thing on a plot that is READ rather than looked at, and
-- it faces the road. So it carries whichever boasts the owner has actually
-- earned, hardest first: rebirths, then the house, then the skin.
--
-- The house is on here because it is otherwise the least visible expensive
-- thing anybody owns. It stands 70 studs back, and past the first few tiers a
-- passer-by cannot tell a 1.4M manor from a 40M palace at that range. Naming
-- it turns the whole ladder into something other people can see, which is the
-- only kind of reward a house is allowed to give.
--
-- The Starter Shack is never named: a sign announcing the free tier reads as a
-- jeer at players who have not bought anything yet.
-- WHAT AN UNMARKED SIGN'S NAME ROW IS PAINTED IN.
--
-- The same value `buildSign` sets on the label, kept here because
-- `updateSign` now has to be able to put it BACK -- a plot that loses its
-- mark on release must not keep the last owner's colour. Two copies of one
-- number, and the alternative is reading the label's colour at build time
-- into a field on the plot, which is a third place for it to live.
local SIGN_NAME_COLOUR = Color3.fromRGB(70, 46, 30)

-- Puts a pass's mark on this plot's sign, or takes it off with nil.
--
-- IT REPAINTS NOTHING ITSELF. The sign is rewritten by `updateSign` on
-- every income tick, every purchase and every rebirth, so a function that
-- also painted would be a second writer racing the first -- and the loser
-- would be whichever ran last, which is not a property anybody could
-- reason about. It stores, and the one writer reads.
-- ============================================================
-- THE MAILBOX
-- ============================================================
--
-- WHOEVER OWNS THE DAILY OWNS THIS, AND IT IS NOT PLOTSERVICE.
--
-- Same split as the fence penalty: PlotService builds the box, raises the
-- flag and detects the press; it does not decide what is in the post. The
-- handler is registered by `DailyService`, which already knows whether
-- there is anything to claim and owns every rule about streaks.
function PlotService.onMailCheck(fn: (Player, Plot) -> ())
	table.insert(mailHandlers, fn)
end

-- Flag up and prompt live, or neither.
--
-- ONE CALL FOR BOTH, because they are one fact seen from two distances:
-- the flag is what you read from the pavement and the prompt is what you
-- press when you get there. Two setters would be two states that could
-- disagree -- a flag up over a box that will not open is the silent
-- failure this project refuses above all others, wearing a picture.
function PlotService.setMail(plot: Plot, waiting: boolean)
	if not plot.mailFlag or not plot.mailPrompt then
		-- A shop. See the note on the type.
		return
	end
	-- HELD IN A LOCAL RATHER THAN INDEXED IN PLACE. `f(a, b)` followed by a
	-- line opening with `(` is parsed as a CALL ON THE RESULT, and a leading
	-- `;` to break it up is itself a parse error after a comment line in
	-- Luau -- which this project has already lost a whole HUD to.
	local prompt = plot.mailPrompt :: ProximityPrompt
	seatMailFlag(plot, waiting)
	prompt.Enabled = waiting
end

-- WHO THE MAILBOX IS FOR, published so the prompt can refuse itself on
-- everybody else's screen. See `Config.PROMPT_OWNER_ATTRIBUTE`.
function PlotService.setMailOwner(plot: Plot, player: Player?)
	if not plot.mailPrompt then
		return
	end
	local prompt = plot.mailPrompt :: ProximityPrompt
	prompt:SetAttribute(Config.PROMPT_OWNER_ATTRIBUTE,
		if player then player.UserId else nil)
end
-- ============================================================
-- THE DOORSTEP CRATE
-- ============================================================
--
-- Same split as the mailbox above, and for the same reason: PlotService
-- stands the box up, paints it and detects the press; it does not decide
-- what is in it or when one is owed. `DailyService` registers the handler,
-- because it owns the streak and the save field the crate is held in.
function PlotService.onCrateOpen(fn: (Player, Plot) -> ())
	table.insert(crateHandlers, fn)
end

-- A crate on the step, or none. ONE CALL FOR THE WHOLE THING -- the
-- geometry, the colour and the prompt -- for the reason `setMail` is one
-- call: a box you can see and cannot open is the silent failure wearing a
-- picture, and two setters are two states that can disagree.
--
-- IT TAKES A CHEST KEY RATHER THAN A BOOLEAN, so the box is painted in the
-- chest's OWN colour and a Piggy Classics on the step reads pink where a
-- Dress-Up Crate reads purple. That is the same argument the shop's own
-- cards make about rendering the real item: a coloured box says which
-- crate before a word is read, and it costs one lookup.
function PlotService.setCrate(plot: Plot, chestKey: string?)
	if not plot.crateParts or not plot.crateTint or not plot.cratePrompt then
		-- A shop. See the note on the type: a plot nobody can move into has
		-- nobody to deliver to.
		return
	end
	local parts = plot.crateParts :: { BasePart }
	local tint = plot.crateTint :: { BasePart }
	local prompt = plot.cratePrompt :: ProximityPrompt

	local chest = if chestKey then Config.CHESTS[chestKey] else nil
	-- A KEY NAMING NOTHING IS TREATED AS NOTHING rather than as a crate in a
	-- default colour. A retired chest would otherwise stand a box on
	-- somebody's step that opens into a refusal -- the same call
	-- `Decor.buildOne` makes for a retired ornament, and the reason the
	-- decoration prune asks the catalogue rather than a list of names.
	local showing = chest ~= nil

	for _, part in ipairs(parts) do
		part.Transparency = if showing then 0 else 1
	end
	if chest and chest.colour then
		for _, part in ipairs(tint) do
			part.Color = chest.colour
		end
	end
	prompt.Enabled = showing
	prompt.ObjectText = if chest then chest.name else "Doorstep Delivery"
end

-- WHO THE CRATE IS FOR, published so the prompt refuses itself on every
-- other screen. See `Config.PROMPT_OWNER_ATTRIBUTE`, and note the box
-- itself stays VISIBLE to the street -- a crate on a doorstep is somebody
-- announcing a seven-day streak, which is worth being able to see.
function PlotService.setCrateOwner(plot: Plot, player: Player?)
	if not plot.cratePrompt then
		return
	end
	local prompt = plot.cratePrompt :: ProximityPrompt
	prompt:SetAttribute(Config.PROMPT_OWNER_ATTRIBUTE,
		if player then player.UserId else nil)
end

function PlotService.setSignPass(plot: Plot, word: string?, colour: Color3?)
	plot.signWord = word
	plot.signColour = colour
end
function PlotService.updateSign(plot: Plot, ownerName: string?, rebirths: number,
	skinName: string?, houseName: string?)
	if not ownerName then
		plot.signLabel.Text = "EMPTY PLOT"
		plot.signLabel.TextColor3 = SIGN_NAME_COLOUR
		plot.signBoast.Text = "for sale"
		return
	end

	local boasts: { string } = {}
	-- FIRST IN THE ROW, AND THAT BREAKS THE ORDERING ON PURPOSE.
	--
	-- The boasts are hardest-first: rebirths, then the house, then the skin.
	-- A purchase has no place on a ladder of things you earned -- putting it
	-- at the end would rank it below a skin, and putting it in the middle
	-- would claim it sits between two achievements. It is a different CLASS
	-- of thing, so it goes in front of the ladder rather than on a rung of
	-- it.
	--
	-- IT IS ALSO THE SHORTEST THING THAT CAN GO THERE, which is not a
	-- coincidence. This row has clipped before -- a maxed player's sign once
	-- read "12* . Neon Tower ." with the skin missing off the end -- so a
	-- fourth boast is only affordable at three characters.
	if plot.signWord and plot.signWord ~= "" then
		table.insert(boasts, plot.signWord)
	end
	if rebirths > 0 then
		table.insert(boasts, ("%d*"):format(rebirths))
	end
	if houseName and houseName ~= Config.HOUSE_TIERS[1].name then
		table.insert(boasts, houseName)
	end
	if skinName and skinName ~= Config.getSkin(Config.DEFAULT_SKIN).name then
		table.insert(boasts, skinName)
	end

	-- The name owns the top row at a fixed size whatever the boasts say; the
	-- boasts get their own smaller row underneath. Sharing one TextScaled
	-- label meant buying a house shrank your own name.
	plot.signLabel.Text = ownerName
	-- THE SECOND CHANNEL, and it is on the NAME rather than on the word.
	-- Colour alone separates things only for players who can see the
	-- difference, which is the rule the rarity borders already follow -- so
	-- the word carries it at any distance and the gold is what makes it
	-- read from the pavement, where three characters will not.
	plot.signLabel.TextColor3 = plot.signColour or SIGN_NAME_COLOUR
	plot.signBoast.Text = table.concat(boasts, " · ")
end

function PlotService.applySkin(plot: Plot, skinKey: string)
	PiggyBank.applySkin(plot.piggy, skinKey)
	-- Remembered for the topiary, which is clipped in whatever the pig is
	-- wearing. `applyToPlot` calls this BEFORE `setDecor`, so the ornament
	-- rebuild that follows already has the new value -- and that ordering is
	-- the same one the trophies depend on, one line further down.
	plot.skinKey = skinKey
end

function PlotService.applyAccessories(plot: Plot, worn: { [string]: string })
	PiggyBank.applyAccessories(plot.piggy, worn)
end

function PlotService.applyEffect(plot: Plot, effectKey: string)
	PiggyBank.applyEffect(plot.piggy, effectKey)
end

-- ============================================================
-- ASSIGNMENT
-- ============================================================

-- Called when a plot passes to a real player, BEFORE the handover, so a
-- resident can be taken off a plot that is still nobody's.
function PlotService.onClaim(fn: (Plot, Player) -> ())
	table.insert(claimHandlers, fn)
end

-- Called when a plot goes back to nobody, AFTER `release` has stripped it,
-- so whatever seats a neighbour on it is seating onto a clean plot rather
-- than racing the reset.
function PlotService.onRelease(fn: (Plot) -> ())
	table.insert(releaseHandlers, fn)
end

function PlotService.assign(player: Player): Plot?
	if byPlayer[player] then
		return byPlayer[player]
	end

	for _, plot in ipairs(plots) do
		-- A SHOP PLOT IS NEVER HANDED TO ANYBODY, and this one line is what
		-- the entire economic floor rests on. See `Config.SHOPS`: the
		-- supply of robbable pigs used to be `PLOT_COUNT - players online`,
		-- because a resident is evicted the moment somebody moves in. A plot
		-- nobody can move into cannot run out.
		if plot.owner == nil and not plot.shop then
			-- Before the handover: the plot is still nobody's here, which is
			-- the state a resident is allowed to be removed in.
			for _, fn in ipairs(claimHandlers) do
				local ok, err = pcall(fn, plot, player)
				if not ok then
					warn("[PlotService] claim handler failed: " .. tostring(err))
				end
			end

			plot.owner = player
			byPlayer[player] = plot
			plot.model:SetAttribute("OwnerUserId", player.UserId)
			-- WHOSE MAILBOX THIS IS, so every OTHER client turns the prompt off
			-- for itself. The flag stays down until DailyService says there is
			-- something in it -- naming the owner is not the same question as
			-- whether the post has arrived, and one call doing both would raise a
			-- flag over an empty box on every join.
			PlotService.setMailOwner(plot, player)
			-- And the crate's, on the same terms and for the same reason. Whose
			-- it is and whether there is one are two questions; `DailyService`
			-- answers the second on its first push.
			PlotService.setCrateOwner(plot, player)
			PlotService.updateSign(plot, player.DisplayName, 0)
			return plot
		end
	end

	warn(("[PlotService] No free plot for %s"):format(player.Name))
	return nil
end

function PlotService.release(player: Player)
	local plot = byPlayer[player]
	if not plot then
		return
	end

	plot.owner = nil
	byPlayer[player] = nil
	plot.model:SetAttribute("OwnerUserId", nil)
	-- BEFORE `updateSign`, or the plot keeps the last owner's mark. Same
	-- class as the house `release` once forgot: a plot that nobody owns
	-- advertising the last person who did, with nothing erroring.
	PlotService.setSignPass(plot, nil, nil)
	-- THE FLAG COMES DOWN WITH THE OWNER, and this answers the question the
	-- roadmap asks of this feature: does a raised flag give away that
	-- somebody is offline? It cannot, because a plot is RELEASED the moment
	-- its owner leaves -- there is nobody to give away. What this line stops
	-- is the other half: a flag left standing over an unclaimed plot,
	-- advertising a reward for a player who is gone. That is exactly the bug
	-- `release` once had with houses, where somebody leaving with a Sky
	-- Castle left the Sky Castle standing.
	PlotService.setMail(plot, false)
	PlotService.setMailOwner(plot, nil)
	-- And the crate goes with it, for the reason the flag does: an unclaimed
	-- plot standing a delivery for a player who has gone is the last owner
	-- still being advertised. The Sky Castle bug, a third time.
	PlotService.setCrate(plot, nil)
	PlotService.setCrateOwner(plot, nil)
	-- And the rebirth counter, for the reason the flag comes down: an
	-- attribute left standing is the last owner still being advertised.
	-- Cleared to nil rather than to 0 -- `Fireworks` refuses a non-number
	-- outright, so a release can never be the thing that fires a show.
	plot.model:SetAttribute(Config.PLOT_FIREWORK_ATTRIBUTE, nil)
	plot.model:SetAttribute(Config.PLOT_FIREWORK_RANK_ATTRIBUTE, nil)
	-- AND THE TROPHY SHELF, for the reason the flag and the crate come
	-- down: a case full of somebody else's robberies standing on an
	-- unclaimed plot is the last owner still being advertised. The Sky
	-- Castle bug, a fourth time -- and this one would be the worst of the
	-- four, because a trophy is a record of what a specific person did.
	--
	-- Cleared BEFORE the ornaments are, so nothing rebuilds a shelf out of
	-- the old numbers on the way past.
	PlotService.setTrophyState(plot, nil)
	PlotService.updateSign(plot, nil, 0)
	PlotService.applySkin(plot, Config.DEFAULT_SKIN)
	PlotService.applyEffect(plot, Config.DEFAULT_EFFECT)
	PlotService.updatePile(plot, 0, Config.BASE_CAPACITY)
	plot.model:SetAttribute(Config.PLOT_ROBBED_ATTRIBUTE, nil)
	PiggyBank.setRobbed(plot.piggy, false)
	-- Wipe the previous owner's defences so the next arrival gets a bare
	-- plot -- and put the house back to the Starter Shack with them. It was
	-- the one thing release never reset, so a player leaving with a Sky
	-- Castle left the Sky Castle standing on an unclaimed plot until
	-- somebody else took it over.
	PlotService.buildFence(plot, 0)
	PlotService.setDogLevel(plot, 0)
	PlotService.setLockLevel(plot, 0)
	PlotService.setHouseLevel(plot, 0)

	-- Last, so a resident seats onto a plot that has already been stripped.
	-- Anything that ran before this reset would have its fence, dog and house
	-- torn straight back down by the four lines above.
	for _, fn in ipairs(releaseHandlers) do
		local ok, err = pcall(fn, plot)
		if not ok then
			warn("[PlotService] release handler failed: " .. tostring(err))
		end
	end
end

function PlotService.getPlot(player: Player): Plot?
	return byPlayer[player]
end

function PlotService.getAll(): { Plot }
	return plots
end

function PlotService.getSpawnCFrame(plot: Plot): CFrame
	return PiggyBank.getViewCFrame(plot.cframe)
end

function PlotService.getOwnerOf(model: Model): Player?
	for _, plot in ipairs(plots) do
		if plot.model == model then
			return plot.owner
		end
	end
	return nil
end


function PlotService.start()
	Players.PlayerRemoving:Connect(function(player)
		bouncedAt[player] = nil
		fenceCooldown[player] = nil
		PlotService.clearLadder(player)
	end)

	-- ONE SWEEP RATHER THAN A TIMER PER LADDER. A `task.delay` per placement
	-- is a state machine that ignores the world -- the same note the guard
	-- dog's patrol pause carries -- and it would go on holding a reference to
	-- a model the fence rebuild had already destroyed. This asks the world
	-- instead, and a destroyed ladder drops out because its Parent is gone.
	--
	-- THE LAST SECONDS FADE. A ladder that vanishes under a climber is fair;
	-- one that does it with no warning is a yank, and the whole design turns
	-- on a thief racing a timer they can see.
	task.spawn(function()
		while true do
			task.wait(0.2)
			local now = os.clock()
			for i = #ladders, 1, -1 do
				local entry = ladders[i]
				local left = entry.expiresAt - now
				if entry.model.Parent == nil or left <= 0 then
					retireLadder(entry.model)
				elseif left < Config.LADDER.fade then
					local t = 1 - left / Config.LADDER.fade
					for _, part in ipairs(entry.model:GetChildren()) do
						if part:IsA("BasePart") and part.Name ~= "Rungs" then
							part.Transparency = t * 0.85
						end
					end
				end
			end
		end
	end)

	-- The Brace Face turtle's headband is runtime CSG and CSG is
	-- server-only, so its template is built here, once, before any plot can
	-- possibly need it -- a saved lawn reconstructing on join is the one
	-- moment this would otherwise race a purchase.
	Decor.prewarm()

	local existing = workspace:FindFirstChild("Plots")
	if existing then
		existing:Destroy()
	end

	plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = workspace

	-- Every plot gets the Starter Shack standing on it before anyone owns
	-- it. Level 0 is the free tier that every player already has, so an
	-- unclaimed plot showing one is honest rather than generous -- and a
	-- bare slab reads as unfinished map rather than as an empty house.
	--
	-- It also builds the driveway, which only ever happened inside
	-- setHouseLevel, so an unowned plot had no drive either.
	for index = 1, Config.PLOT_COUNT do
		local plot = buildPlot(index)
		table.insert(plots, plot)
		PlotService.setHouseLevel(plot, 0)
	end

	-- THE SHOP PLOTS, NUMBERED ABOVE THE HOUSES SO THE TWO SPACES CANNOT
	-- COLLIDE. A plot's index is not decoration: `ResidentService` keys its
	-- residents on it and `HeistService.targetId` sends its NEGATIVE over the
	-- StealCooldown remote, so two plots sharing one would silently merge a
	-- resident and give two victims one cooldown badge.
	--
	-- They join `plots` rather than living in a list of their own, which is
	-- what makes every sweep over the street find them for free -- the
	-- resident tick, the bone search, the watching dog and the plot lookups
	-- all iterate `getAll()` and none of them needs to know.
	--
	-- No `setHouseLevel`: a shop has no house and no driveway, and seating a
	-- Starter Shack here would stand a building inside the unit this plot
	-- is the inside OF.
	for i, spec in ipairs(Config.SHOPS) do
		table.insert(plots, buildShopPlot(Config.PLOT_COUNT + i, spec))
	end

	Players.PlayerRemoving:Connect(function(player)
		PlotService.release(player)
	end)
end

return PlotService
