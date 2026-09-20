--!strict
--[[
	VaultModel

	The strongroom that stands on the back wall of every shop, and the second
	kind of thing this game lets you rob.

	----------------------------------------------------------------------

	WHY THERE IS A SECOND KIND OF THING TO ROB AT ALL.

	`Config.SHOPS` carries the argument in full and the short version is that
	the rule it breaks was real. A shop target was allowed once, and only
	because what stood on its forecourt was the same twelve-stud piggy bank
	that stands on a lawn -- same hatch, same crack, same coin pile, same rob
	badge, nothing new invented to rob. That was true, and the picture it
	bought was wrong: a shop with its own piggy bank parked outside it reads
	as a game object on a pavement rather than as a place, and four of them
	read as it four times.

	So the noun is spent, deliberately, once. What is bought is that the
	shops stop being scenery with a target bolted to the front.

	----------------------------------------------------------------------

	IT IS STILL A PLOT, WHICH IS WHY IT COST ALMOST NOTHING.

	`plot.shop` is the whole implementation. Everything a robbery touches is
	keyed off a plot -- the steal prompt, the rob badge, the published pile,
	the lock attribute, the per-victim cooldown, casing, the crack, the coin
	drain, the drop-off and the rap sheet -- so this file builds GEOMETRY and
	`PiggyBank.buildVault` wraps it in exactly the `Refs` a piggy bank
	returns. Not one reader of `plot.piggy` changed, and the dial, the fill,
	the alarm and the milestone squash are the piggy's own functions running
	unmodified on different parts.

	----------------------------------------------------------------------

	THE FILL IS BARS, AND IT IS THE SAME NUMBER THE COIN PILE DRAWS.

	`Config.COIN_COUNT` of them, in a 4 x 8 grid filling bottom to top, so
	`PiggyBank.setFill` works with no branch and the stack visibly DRAINS
	while a thief cracks it -- the greed bar drawn in the world rather than
	only on their screen, which is the property the coin pile on a lawn has
	and the one thing a closed vault door would have thrown away.

	That is why the door stands OPEN rather than shut. A shut vault is a
	better picture of a vault and a worse readout of one, and a target whose
	value cannot be read from in front of it is the failure this project
	spends the most words on.

	----------------------------------------------------------------------

	NOTHING HERE IS HOLLOWED OUT, because nothing in this engine can be.

	A recess is made by standing something PROUD around the dark, never by
	sinking the dark -- the eye takes the highest line as the surface, which
	is the moat's kerb rule at a twentieth of the scale and the piggy's own
	vault rim at the same one. So: a near-black mouth standing 0.1 proud of
	the carcass face, a jamb standing proud of THAT, and the bars standing
	proud of the mouth. Bars set flush would be buried, which is the mistake
	the trophy safe made and had photographed out of it.

	AND EVERY DETAIL SINKS 0.1 INTO WHAT IT STANDS ON, which is the
	convention that took the rebuilt houses from 142 coplanar pairs to zero.
	The jamb's four bars BUTT rather than overlap for the same reason: two
	faces at one depth with real overlap is a strobing seam, and a frame made
	of four pieces that cross at the corners has four of them.

	----------------------------------------------------------------------

	THE GOLD IS FLAT AND THE STEEL IS NOT, and that is a measurement rather
	than a preference. `Material.Metal` SHADES a colour by its environment
	instead of rendering it: photographed on the trophy shelf, the same
	(226, 186, 86) came out bright gold on a plinth in SmoothPlastic and
	OLIVE on a stack of bars two studs away. A colour that has to be a
	particular colour is flat; Metal is right where the shading IS the thing
	being shown, which is what a safe body is.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local VaultModel = {}

-- ============================================================
-- THE SHAPE
-- ============================================================

-- Authored in the vault's own frame: origin ON THE SHOP FLOOR at the
-- carcass's centre in X and Z, +Z pointing into the room. Everything below
-- is in those studs, which is what lets `ShopFront` keep its counter clear
-- of the door swing by reading these numbers rather than by guessing.
VaultModel.SIZE = {
	width = 6.0,
	height = 6.4,
	depth = 2.4,
	-- The plinth the carcass stands on, which is what stops a strongroom
	-- looking like a box resting on a floor -- the same course every rebuilt
	-- house tier carries where it meets the ground.
	plinthHeight = 0.55,
	plinthOver = 0.6,
	-- HOW FAR THE OPEN DOOR REACHES INTO THE ROOM, which is the number
	-- anything else standing in this room has to clear -- read this rather
	-- than the angle. Measured on the built unit: the furthest part of the
	-- open leaf sits 5.7 studs in front of the vault's own frame.
	doorReach = 5.8,
	-- AND HOW FAR IT REACHES ACROSS IT, which is a different question and is
	-- the one a shop's fittings actually run into. `doorReach` says how far
	-- down the room the leaf goes and says nothing about the line it draws
	-- across it.
	--
	-- TWO NUMBERS, BECAUSE ONE OF THEM WAS ANSWERING BOTH QUESTIONS AND GOT
	-- THE IMPORTANT ONE WRONG. This was a single `doorAcross = 2.88`
	-- described as a blade "at x -2.88 to -1.83 in this frame". Re-measured
	-- on the built unit, the leaf spans -3.93 to -2.88: the range was the
	-- true one shifted a stud, and 2.88 is its INBOARD edge -- the side
	-- nearest the vault's own centre line, and the side a shop's fittings
	-- never meet.
	--
	-- WORSE, IT WAS THE LEAF ALONE. The lock dial is bolted to the leaf and
	-- swings with it, and a 3.9-stud dial plate on the outward face reaches
	-- a further 1.37 studs across the room -- so the blade a counter has to
	-- clear runs to 5.30, not 2.88. Nothing had ever measured the assembly;
	-- the leaf was measured correctly and the thing bolted to it was not.
	--
	-- `Config.SHOP_ROOM.vaultDoorNearX` and `.vaultDoorFarX` are these in the
	-- ROOM's frame, and they are copies on purpose: Config requires nothing
	-- and is not about to start requiring a model builder for two numbers.
	-- Move either and move both -- the shop's counter is measured against
	-- the MAX, and getting it wrong leaves a slot rather than a way past,
	-- silently, with the audit reporting a walkway twice its real width.
	--
	-- Anything else hung on this leaf goes in `doorAcrossMax` too, or it is
	-- invisible to every room that has to make space for it.
	doorAcrossMin = 2.88,
	doorAcrossMax = 5.30,
}

local S = VaultModel.SIZE

-- Where the carcass's front face sits, and everything measured off it.
local FACE_Z = S.depth / 2
local FLOOR_SINK = 0.1

-- The mouth. Sized so the jamb standing round it still lands inside the
-- carcass's own face rather than overhanging it.
local MOUTH_W = 4.6
local MOUTH_H = 4.6
local MOUTH_Y = 3.7

local JAMB_T = 0.5
local JAMB_D = 0.6

-- The door leaf, hinged OUTBOARD of the carcass on the -X side and swung
-- clear of its own opening.
--
-- 95 DEGREES RATHER THAN 55, AND THE ARITHMETIC PICKED IT. A leaf covers
-- `cos(angle)` of the opening it is hinged beside: at 55 degrees a 4.6-stud
-- door stands across 2.6 studs of a 4.6-stud mouth, which is most of the
-- readout hidden behind the thing that is meant to be open. Past 90 it
-- covers nothing at all.
--
-- What that costs is that the wheel faces sideways, which is what a fully
-- open vault door does in the world. The tier is readable from the pavement
-- anyway, by casing and by the rob badge's own pips.
--
-- AND HOW FAR IT REACHES IS THE CONSTRAINT, NOT HOW WIDE IT IS. A door
-- standing open is `hingeZ + width` deep into the room, and the room is not
-- empty: three of the four units carry a display case whose BACKBOARD stands
-- 6.3 studs in front of the vault. Measured on the first build, a 5.2-stud
-- leaf hinged at the carcass face reached 6.87 and stood through it -- and
-- the coplanar audit could not see it, because a rotated part is skipped.
-- Only a per-part sweep in the unit's own frame found it.
--
-- So the leaf is the mouth's own width and the hinge is set 0.1 INTO the
-- face rather than proud of it, which buys back 0.42 without touching the
-- swing. Reach 5.68, against 6.3 of room.
local DOOR_W = 4.6
local DOOR_H = 5.4
local DOOR_T = 0.65
local DOOR_ANGLE = math.rad(-95)
local HINGE_X = -(S.width / 2 + 0.2)
local HINGE_Z_SINK = 0.1

local STEEL = Color3.fromRGB(150, 156, 166)
local STEEL_DARK = Color3.fromRGB(92, 98, 108)
local STEEL_LIGHT = Color3.fromRGB(192, 198, 208)
local NEAR_BLACK = Color3.fromRGB(24, 22, 26)
local GOLD = Color3.fromRGB(226, 186, 86)
local GOLD_DARK = Color3.fromRGB(186, 148, 58)

export type Pieces = {
	model: Model,
	-- THE CARCASS, and it is the part every reader of `plot.piggy.body`
	-- lands on: the steal prompt, the four sounds, the emitters, the raid
	-- drone's anchor and the crack panel's camera. It is the one thing here
	-- that collides and answers a query, exactly as a piggy's body does --
	-- a vault is an object in a room, not scenery.
	body: Part,
	mouth: Part,
	bars: { Part },
	pile: Folder,
	door: Part,
	-- Where `PiggyBank.setLockLevel` seats its wheel. Its +X is the door
	-- leaf's outward normal, because the dial plate is a cylinder whose axis
	-- is the seat's own X.
	dialSeat: CFrame,
}

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame,
	colour: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = material or Enum.Material.Metal
	p.Color = colour
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- `cf` is the vault's own frame: on the shop floor, facing into the room.
function VaultModel.build(cf: CFrame, parent: Instance): Pieces
	local model = Instance.new("Model")
	model.Name = "ShopVault"

	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end

	-- ---------- the box ----------
	part(model, "Plinth",
		Vector3.new(S.width + S.plinthOver, S.plinthHeight + FLOOR_SINK, S.depth + S.plinthOver),
		at(0, (S.plinthHeight - FLOOR_SINK) / 2, 0), STEEL_DARK)

	local bodyY = S.plinthHeight + S.height / 2 - FLOOR_SINK
	-- NAMED `Body`, LIKE A PIGGY BANK'S, AND THAT IS AN INTERFACE RATHER
	-- THAN A LABEL. Three separate CLIENT lookups find a plot's money by
	-- NAME -- the steal prompt, the rob badge and the skin animator -- and a
	-- name is an interface with no compiler behind it. See
	-- `Config.waitForPlotBank`, which is the one place that knows both model
	-- names; the part inside it is `Body` on both so nothing has to know two.
	local body = part(model, "Body", Vector3.new(S.width, S.height + FLOOR_SINK, S.depth),
		at(0, bodyY, 0), STEEL)
	-- The one part here that is not scenery. See `Pieces.body`.
	body.CanCollide = true
	body.CanQuery = true

	-- A cap course over the top, so the carcass has a line where it stops
	-- rather than a bare edge -- the cornice argument at a shop's scale.
	part(model, "Cap", Vector3.new(S.width + 0.5, 0.45, S.depth + 0.5),
		at(0, S.plinthHeight + S.height - 0.12, 0), STEEL_LIGHT)

	-- ---------- the opening ----------
	--
	-- PROUD, NOT SUNK. The mouth stands 0.1 out of the carcass face and the
	-- jamb stands 0.2 out of the mouth; set flush the dark would read as a
	-- black sticker painted on a box, which is exactly what the piggy's own
	-- vault hatch became for a whole release when its rim was deleted.
	local mouth = part(model, "Mouth", Vector3.new(MOUTH_W, MOUTH_H, 0.4),
		at(0, MOUTH_Y, FACE_Z - 0.1), NEAR_BLACK, Enum.Material.SmoothPlastic)

	local jambZ = FACE_Z + 0.2
	local half = MOUTH_H / 2
	-- BUTTED, NEVER CROSSED. Four bars that overlap at the corners share
	-- both their Z planes over a real patch, which is four coplanar pairs on
	-- the one detail a thief stands two studs from.
	part(model, "Jamb", Vector3.new(MOUTH_W + JAMB_T * 2, JAMB_T, JAMB_D),
		at(0, MOUTH_Y + half + JAMB_T / 2, jambZ), STEEL_LIGHT)
	part(model, "Jamb", Vector3.new(MOUTH_W + JAMB_T * 2, JAMB_T, JAMB_D),
		at(0, MOUTH_Y - half - JAMB_T / 2, jambZ), STEEL_LIGHT)
	for _, sx in ipairs({ -1, 1 }) do
		part(model, "Jamb", Vector3.new(JAMB_T, MOUTH_H, JAMB_D),
			at(sx * (MOUTH_W + JAMB_T) / 2, MOUTH_Y, jambZ), STEEL_LIGHT)
	end

	-- ---------- what is in it ----------
	--
	-- `Config.COIN_COUNT` bars in a 4 x 8 grid, filled bottom row first, so
	-- `PiggyBank.setFill` -- which walks `refs.coins` in order and toggles
	-- transparency -- draws a stack whose LEVEL is the readout. Any other
	-- ordering makes a full vault and a nearly empty one the same picture
	-- with holes in it.
	local pile = Instance.new("Folder")
	pile.Name = "Bars"
	pile.Parent = model

	-- THE GAPS ARE THE POINT, AND THE FIRST BUILD HAD NONE. Photographed, a
	-- 0.95-wide bar on a 1.10 pitch left 0.15 of dark between columns and
	-- 0.04 between rows, which at this scale is a SOLID WALL OF GOLD with a
	-- black band above it -- the level still readable, the bars not. Narrower
	-- bars on the same pitch read as a stack of bars in a dark hole, which is
	-- what the object is.
	local COLS = 4
	local ROWS = Config.COIN_COUNT // COLS
	local BAR_W, BAR_H, BAR_D = 0.80, 0.32, 0.45
	local COL_STEP = 1.1
	local ROW_STEP = (MOUTH_H - 0.9) / ROWS
	local bars: { Part } = {}
	for row = 0, ROWS - 1 do
		for col = 0, COLS - 1 do
			local x = (col - (COLS - 1) / 2) * COL_STEP
			local y = MOUTH_Y - half + 0.45 + row * ROW_STEP
			-- Alternate rows sit a shade further back, so the stack has a
			-- depth to read rather than being a flat grid on one plane.
			local bar = part(pile, "Bar", Vector3.new(BAR_W, BAR_H, BAR_D),
				at(x, y, FACE_Z + 0.32 - (row % 2) * 0.09),
				if row % 2 == 0 then GOLD else GOLD_DARK,
				Enum.Material.SmoothPlastic)
			bar.Transparency = 1 -- setFill owns whether it shows
			table.insert(bars, bar)
		end
	end

	-- ---------- the door ----------
	local hinge = at(HINGE_X, S.plinthHeight + S.height / 2, FACE_Z - HINGE_Z_SINK)
		* CFrame.Angles(0, DOOR_ANGLE, 0)
	local leafCF = hinge * CFrame.new(DOOR_W / 2, 0, 0)

	local door = part(model, "VaultDoor", Vector3.new(DOOR_W, DOOR_H, DOOR_T), leafCF, STEEL)
	-- A raised panel on the face, so the leaf reads as a slab of steel with
	-- something on it rather than as a rectangle. Sunk into the leaf like
	-- every other detail here.
	part(model, "DoorPanel", Vector3.new(DOOR_W - 1.0, DOOR_H - 1.0, 0.3),
		leafCF * CFrame.new(0, 0, DOOR_T / 2 - 0.05), STEEL_LIGHT)

	-- The bolts down the closing edge, which is the one part of a vault door
	-- that says it is a vault door rather than a cupboard.
	for i = -1, 1 do
		part(model, "Bolt", Vector3.new(0.5, 0.6, DOOR_T + 0.9),
			leafCF * CFrame.new(DOOR_W / 2 - 0.15, i * 1.7, 0), STEEL_DARK)
	end

	-- The two hinge knuckles, on the other edge.
	for _, sy in ipairs({ -1, 1 }) do
		local knuckle = part(model, "Hinge", Vector3.new(0.9, 0.7, 0.7),
			hinge * CFrame.new(0.15, sy * 1.9, 0) * CFrame.Angles(0, 0, math.rad(90)),
			STEEL_DARK)
		knuckle.Shape = Enum.PartType.Cylinder
	end

	-- WHERE THE WHEEL GOES. `PiggyBank.buildWheel` builds a cylinder whose
	-- axis is the seat's own +X, so the seat has to be turned a quarter so
	-- that its RightVector is the leaf's outward normal. `CFrame.Angles(0,
	-- -90deg, 0)` is the turn that does it; +90 points the plate INTO the
	-- door, which is invisible and looks exactly like a lock that failed to
	-- build.
	local dialSeat = leafCF
		* CFrame.Angles(0, math.rad(-90), 0)
		* CFrame.new(DOOR_T / 2 + 0.2, 0, 0)

	-- NO JEMMY SCARS ON THE DOOR. Two crossed marks stood here, hidden until
	-- somebody got in, mirroring the plaster on a piggy's forehead -- both are
	-- retired together, on the designer's call. See Config, where the constants
	-- were.

	model.PrimaryPart = body
	model.Parent = parent

	return {
		model = model,
		body = body,
		mouth = mouth,
		bars = bars,
		pile = pile,
		door = door,
		dialSeat = dialSeat,
	}
end

return VaultModel
