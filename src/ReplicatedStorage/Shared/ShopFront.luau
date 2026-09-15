--!strict
--[[
	ShopFront

	The four shops on the street. One shell, four buildings.

	----------------------------------------------------------------------

	THEY WERE FOUR IDENTICAL BOXES, AND THEN THEY WERE FOUR TEXTURED BOXES
	ON A STREET WHERE NOTHING ELSE HAD A TEXTURE LEFT.

	The first version was a shared shell with a different accent colour and a
	different word on the fascia, which is a colour swatch rather than a shop.
	The fix for that was per-STYLE geometry -- a different roof line, frontage
	and lighting for each -- and it was the right fix and it still stands: four
	silhouettes before a single word is read.

	What it did NOT touch is the vocabulary underneath, and that is what this
	pass is about. These units were built out of `Brick`, `Slate`, `Concrete`,
	`WoodPlanks`, `DiamondPlate` and `Grass` -- which is FIVE OF THE SIX
	TEXTURED MATERIALS THE HOUSE PASS REMOVED FROM EVERY OTHER BUILDING IN THE
	GAME. Photographed from the pavement with the rebuilt cottages sixty studs
	behind them, the shops were the only noisy objects in frame: grey speckled
	side walls, roofs that were bare sloping slabs where every house behind had
	courses and a ridge, and window glazing that was one flat rectangle where
	every house had a frame, a sill and a mullion cross.

	So the shops are rebuilt in the SAME toolkit the houses are, which now
	lives in `Shared/LowPoly.luau` rather than privately inside `House.luau`.
	That move is the point rather than a tidy-up: a shop and a house stand on
	one street with nothing between them, and two copies of the vocabulary are
	two ways for them to stop matching, silently, the first time either is
	touched.

	----------------------------------------------------------------------

	WHAT ACTUALLY MAKES A BUILDING READ, restated for a shop.

	The house pass measured four things against reference art and every one of
	them applies here:

	  * FLAT COLOUR, never a texture. `SmoothPlastic` throughout, and it is
	    the single biggest move and it is free.
	  * SOMETHING WHERE THE BUILDING MEETS THE GROUND. A plinth course is what
	    stops a shop looking like a box resting on paving.
	  * A HARD LINE AT EVERY CORNER. Flat shading loses a corner whenever the
	    two faces catch the sun equally; quoins are the nearest thing this
	    engine gives you to the ink outline the reference art uses.
	  * A ROOF WITH COURSES ON IT. Two bare wedges are a ramp.

	The fifth is a shop's own: A SHOPFRONT IS NOT A WALL WITH A HOLE IN IT. It
	is piers, a stall riser, glazing, a transom and a fascia -- five bands, in
	that order, and getting the order right is most of why the frontage reads
	as commercial rather than as a house with a big window.

	----------------------------------------------------------------------

	THE QUOINS SKIP THE FRONT, WHICH IS WHY `LowPoly.quoins` GREW A FLAG.

	Run round all four corners they land in the middle of the shopfront, where
	the glazing is -- masonry growing through a window. A shop gets them on the
	back pair and gets PIERS at the front instead, which is what a real one
	has. The houses pass nothing and keep all four, exactly as measured.

	----------------------------------------------------------------------

	THE BRACKET SIGN IS A FIX, NOT A FLOURISH.

	A fascia faces the ROAD and a player approaches ALONG the road -- so the
	one thing naming each shop was edge-on from every direction anybody
	actually arrives from, and legible only once you had already stopped in
	front of it. A projecting sign hung square to the frontage is how a real
	high street solves exactly that, and it carries the name on BOTH faces so
	it reads coming and going.

	Its panel is thin on X and its guis go on Left and Right, because the
	street runs along X and those are the faces pointing up and down it.

	----------------------------------------------------------------------

	THE WINDOW HOLDS THE REAL ITEM.

	A shop that renders the actual thing it sells is a rule this project keeps
	everywhere else -- the shop cards build real skins, real houses and real
	ornaments rather than a coloured square, because a skin is the one thing a
	stripe of colour cannot tell you. A window display is that argument
	standing on a pavement.

	The display is passed IN as a builder rather than required here, so this
	module stays geometry over Config instead of acquiring a dependency on
	Decor, RideModel and PiggyModel between them. The caller already has all
	three.

	----------------------------------------------------------------------

	THE LIGHTING IS NEON DRIVEN BY HOUSEFX, WITH NO NEW ANIMATION CODE.

	Same argument the house tiers already settled: this game has no night, a
	PointLight in full sun is invisible from the street, and Neon is the one
	material that ignores the scene and blooms for free. Tagging a part and
	stamping an `FX` attribute on it is the whole cost -- the client animator
	that already runs for the houses picks it up, and its own `MAX_RATE`
	ceiling means nothing here can be authored into a strobe however it is
	tuned.

	THE FX COUNTS ARE UNCHANGED BY THE REBUILD, deliberately: two tagged parts
	on the boutique and the garden centre, ten on the workshop, two on the
	strongroom. Effects were MOVED where the new geometry demanded it and
	never added or dropped, so nothing in the light show needs re-verifying.

	----------------------------------------------------------------------

	AUTHORED FACING +Z, like everything else in this world, and the caller
	yaws it. Nothing collides and nothing answers a raycast: only the hills do
	that, because a chase has to be able to run through the scenery.

	AND THE FOOTPRINT MAY NOT GROW. The verge band these stand in is solved
	rather than chosen -- see the note over `SHOPS` in NeighborhoodService --
	and the forecourt is `WIDTH + FORECOURT_OVERHANG` across, with everything
	standing on it inside that. A robbable piggy bank used to stand out there
	at shop-local (-16, +16); it is a vault on the back wall now, so the band
	is clear -- but the constraint is the verge's and it has not moved.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LowPoly = require(ReplicatedStorage.Shared.LowPoly)
-- THE BANNER IS A GuiObject, AND A GuiObject TAKES ITS COLOURS FROM `Theme`
-- WHEREVER IT IS BUILT. This file runs on the server, which is exactly the
-- scope rule the boards on the verge got wrong: "the UI files" is not the
-- same set as "the files that build UI", and eighteen hardcoded colours sat
-- on the leaderboard for months because of it. Theme requires nothing, so
-- taking it here costs nothing either.
local Theme = require(ReplicatedStorage.Shared.Theme)

local ShopFront = {}

ShopFront.TAG = "ShopDoor"
ShopFront.TAB_ATTRIBUTE = "ShopTab"

-- The animator that already runs for the house light show. Named here rather
-- than required: this module has no other reason to know that file exists,
-- and a string is all the tag ever is.
local FX_TAG = "HouseFX"

-- WIDTH IS SOLVED AGAINST WHAT THE UNIT HAS TO CLEAR, and the FORECOURT is
-- the number that sets it -- a first pass at 20 wide with a forecourt four
-- studs wider measured 24 across and left 0.4 studs to a fence. The building
-- was never the footprint.
-- READ FROM `Config` RATHER THAN OWNED HERE, AND THAT IS A FIX RATHER THAN
-- TIDINESS. Three files need the shell now: this one builds the walls,
-- `PlotService` stands a floor, a vault and a shopkeeper INSIDE them, and
-- `Config` prices the run home off where that vault ended up. Two copies of
-- a width is two chances to put a strongroom through a wall -- and the wall
-- does not collide, so nothing in the engine would ever have said so.
local WIDTH = Config.SHOP_UNIT.width
local DEPTH = Config.SHOP_UNIT.depth
local HEIGHT = Config.SHOP_UNIT.height
local FORECOURT_OVERHANG = 2

-- THE FIVE BANDS OF A SHOPFRONT, bottom to top, as one list of heights rather
-- than as numbers scattered through four style functions. Reading them in
-- order IS the elevation, and a band that moves moves everything sitting on
-- it -- which is the whole reason the first version's door, window head and
-- fascia never quite lined up with each other.
local PAVE_TOP = 0.4 -- top of the forecourt slab
local PLINTH_TOP = 1.6 -- top of the base course the walls stand on
local RISER_TOP = 4.2 -- top of the solid under the glazing
local GLAZE_TOP = 9.8 -- window head, and the door head with it
local TRANSOM_TOP = 10.6 -- the beam over both
-- and the fascia runs from there to HEIGHT.

local FRONT = DEPTH / 2

-- SINK, NOT STACK. Anything standing on something goes 0.1 INTO it, so the
-- two never share a face plane over a real overlap. That convention is what
-- took the rebuilt houses from 142 coplanar pairs to zero, and it costs
-- nothing: a tenth of a stud is invisible and the alternative is a strobing
-- seam along the bottom of every detail on the building.
local SINK = 0.1

-- HOW BIG A WINDOW DISPLAY IS, AND HOW FAR IT IS TURNED, AND THE TWO ARE ONE
-- DECISION BECAUSE THE BAY IS SOLVED AGAINST BOTH.
--
-- The span is measured against the WINDOW: 3.1 fills 59% of a 5.25-stud one,
-- where the 4.4 it shipped at filled 84% and pressed against the glass. The
-- yaw is what stops it reading as parked -- and it is also what decides how
-- much FLOOR the bay costs, because a near-cubic model presents its diagonal
-- rather than its side. `bayDepth` below is that arithmetic rather than a
-- number somebody liked the look of, which is what stopped the bay eating
-- the walkway behind it a second time.
local DISPLAY_SPAN = 3.1
local DISPLAY_YAW = 24

-- The structural palette, shared with the houses through LowPoly so a shop
-- window and a house window cannot be different blues.
local STONE = LowPoly.STONE
local TIMBER = LowPoly.TIMBER
local FRAME = Color3.fromRGB(64, 56, 66)
local GLASS = Color3.fromRGB(176, 210, 224)
-- THE TRIM WAS BLOOMING, AND IT WAS NOT THE GLASS AFTER ALL.
--
-- The window pane was the obvious suspect for the white cloud over the
-- boutique's frontage and fixing it did not clear it. Measured instead:
-- CREAM was (250, 248, 242), which is a RELATIVE LUMINANCE OF 0.973, and it
-- is on forty-five parts of every unit -- the quoins, both piers, the window
-- frame, the mullions, the sill, the door frame, the transom, the cornice,
-- the fascia rails, the bargeboards and the whole awning. Against a
-- BloomEffect thresholded at 1.1 and a sun at 14:30, an albedo that high
-- goes over the line and the entire trim set glows.
--
-- Not one of the nine rebuilt house tiers carries a trim above 0.92. This
-- was simply brighter than anything else on the street, and it took the
-- frontage with it.
--
-- 0.888 also buys the second thing the first palette pass was short of: the
-- walls are a pale tint and the trim was a fractionally paler one, so a unit
-- read as a single mass. Off-white against a tinted wall is a step you can
-- see.
local CREAM = Color3.fromRGB(236, 230, 217)
local GOLD = Color3.fromRGB(212, 168, 60)
local LEAD = Color3.fromRGB(118, 122, 132)

-- THE JOINERY IS DARK, AND THAT IS WHY A HOUSE WINDOW READS AND THE FIRST
-- SHOP WINDOW DID NOT.
--
-- The whole aperture rendered as a featureless white sheet and it took three
-- wrong diagnoses to get here: the pane was accused (dropped to 0.86
-- transparent, no change), the neon strip under it was accused (moved onto
-- the transom, no change), the display was accused (scaled down and given a
-- backboard, no change). Settled by tinting -- glass green, frame blue,
-- awning orange -- and re-shooting: EVERY PIECE WAS THERE AND CORRECTLY
-- PLACED. The frame, the mullion cross, the sill and the pale interior
-- behind them were simply all near-white, and near-white on near-white in
-- full sun is one sheet whatever the geometry underneath is doing.
--
-- `LowPoly.framedWindow` never had this problem because the tier it serves
-- hands it a DARK trim -- the cottage's is (120, 84, 58). The shop handed
-- its window the same near-white it uses for the piers and the cornice.
--
-- So the frontage is two families rather than one: light MASONRY (piers,
-- quoins, cornice, fascia rails) and dark JOINERY (window frame, mullions,
-- sill, door surround, transom). That is what a real shopfront is, it is
-- what makes the glazing read as a hole rather than as a panel, and it costs
-- one colour.
local JOINERY = Color3.fromRGB(72, 60, 66)

export type Spec = {
	name: string,
	tab: string,
	accent: Color3,
	style: string,
	-- Optional: returns the model that stands in the window. Scaled and
	-- placed here; a nil return costs the display and nothing else.
	display: (() -> Model?)?,
}

-- ============================================================
-- PRIMITIVES
-- ============================================================

local function add(parent: Instance, name: string, size: Vector3, cf: CFrame,
	colour: Color3, material: Enum.Material?): Part
	return LowPoly.part(parent, name, size, cf, colour, material or Enum.Material.SmoothPlastic)
end

-- A ROBLOX CYLINDER'S AXIS IS ITS X AXIS: Size.X is the LENGTH along it and
-- the other two are the cross-section. Written the other way round it becomes
-- a disc as wide as the height was tall, which this project has shipped five
-- times. These three wrappers are why it will not be a sixth.
local function cylinderAlongX(parent: Instance, name: string, length: number,
	d: number, cf: CFrame, colour: Color3, material: Enum.Material?): Part
	local p = add(parent, name, Vector3.new(length, d, d), cf, colour, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function cylinderUp(parent: Instance, name: string, height: number,
	d: number, cf: CFrame, colour: Color3, material: Enum.Material?): Part
	return cylinderAlongX(parent, name, height, d,
		cf * CFrame.Angles(0, 0, math.rad(90)), colour, material)
end

-- Axis along Z, which is what a scallop on a valance wants: seen from the
-- street it is a semicircle, and the length is how thick the cloth is.
local function cylinderForward(parent: Instance, name: string, length: number,
	d: number, cf: CFrame, colour: Color3, material: Enum.Material?): Part
	return cylinderAlongX(parent, name, length, d,
		cf * CFrame.Angles(0, math.rad(90), 0), colour, material)
end

local function ball(parent: Instance, name: string, d: number, cf: CFrame,
	colour: Color3, material: Enum.Material?): Part
	local p = add(parent, name, Vector3.new(d, d, d), cf, colour, material)
	p.Shape = Enum.PartType.Ball
	return p
end

-- Hands a part to the house animator. Everything it needs is an attribute, so
-- there is nothing to register here and nothing to tear down.
local function animate(part: Part, fx: string, opts: { [string]: number }?)
	part:SetAttribute("FX", fx)
	for key, value in pairs(opts or {}) do
		part:SetAttribute(key, value)
	end
	CollectionService:AddTag(part, FX_TAG)
end

-- Scales a model about its own pivot, for a display that has to fit a window.
local function scaleModel(model: Model, s: number)
	if s == 1 then
		return
	end
	local origin = model:GetPivot()
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local rel = origin:ToObjectSpace(part.CFrame)
			part.Size *= s
			part.CFrame = origin * CFrame.new(rel.Position * s) * (rel - rel.Position)
		end
	end
end

-- Words are DRAWN, never built. A print is flat and no arrangement of studs
-- holds a legible name at this size -- the same call the plot sign and the
-- lawn statue's shirt graphic already make.
local function sign(parent: BasePart, face: Enum.NormalId, text: string,
	colour: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign_" .. face.Name
	gui.Face = face
	gui.PixelsPerStud = 26
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = colour
	label.TextStrokeTransparency = 0.55
	label.Text = text
	label.Parent = gui
end

-- THE NAME GOES ON A BANNER OVER THE ROOF, NOT ON THE FASCIA.
--
-- It was drawn on the fascia -- a SurfaceGui on the coloured band over the
-- window -- and reported, correctly, as barely readable. Three things were
-- wrong with it at once and none of them was the font:
--
--   * IT FACED ONE WAY. A fascia is flat against the frontage and a player
--     walks ALONG the street, so the name was edge-on from every direction
--     anybody actually arrives from. That is the same fault the projecting
--     bracket sign was added to fix, and the fascia never stopped having it.
--   * IT WAS CREAM ON THE ACCENT, which is the shop's own mid-tone -- fine
--     on paper and thin in full sun with a BloomEffect running.
--   * IT WAS SMALL AND IT SHRANK WITH DISTANCE, like anything painted on a
--     surface. A shop is READ from the pavement, which is thirty studs away.
--
-- A `BillboardGui` fixes all three by construction: it faces the camera from
-- wherever you stand, it holds its size on screen as you walk away, and it
-- is drawn in the game's own vocabulary -- a rounded plaque with the ink
-- outline, which is what every other readable thing in this project is.
--
-- IT IS NOT `AlwaysOnTop`. A name that punches through the building it is
-- attached to reads as a HUD element rather than as a sign on a shop, and
-- this project already argues that at length about the street boards: the
-- physicality is the point. Occluded, it disappears behind the hill when the
-- shop does.
--
-- AND IT IS DISTANCE-CAPPED, because eight of these legible from anywhere on
-- a 350-stud street is a wall of text over the world. 260 covers the whole
-- verge either side of the plaza and stops at about the point the building
-- itself stops being a shape you can tell apart.
local function banner(model: Instance, at: At, spec: Spec)
	-- An invisible anchor rather than adorning a piece of the building: the
	-- roof line is a different height on all four styles, and hanging the
	-- name off whichever part happens to be highest would put it somewhere
	-- different on each.
	local anchor = add(model, "SignAnchor", Vector3.new(0.4, 0.4, 0.4),
		at(0, 19.8, FRONT - 1.0), spec.accent)
	anchor.Transparency = 1

	local gui = Instance.new("BillboardGui")
	gui.Name = "ShopBanner"
	gui.Adornee = anchor
	-- Sized in STUDS -- a BillboardGui's Scale component is world size -- so
	-- the plaque is a fixed 17 by 4.6 of the world and the text inside it
	-- scales to that rather than to somebody's window.
	gui.Size = UDim2.fromScale(17, 4.6)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 260
	gui.LightInfluence = 0
	gui.Parent = anchor

	-- A drop shadow, offset down and right. Two studs of parallax is what
	-- separates a plaque floating over a roof from a decal painted on the
	-- sky behind it.
	local shade = Instance.new("Frame")
	shade.Name = "Shadow"
	shade.Size = UDim2.fromScale(1, 1)
	shade.Position = UDim2.fromScale(0.012, 0.045)
	shade.BackgroundColor3 = Theme.INK
	shade.BackgroundTransparency = 0.55
	shade.BorderSizePixel = 0
	shade.ZIndex = 1
	shade.Parent = gui

	local body = Instance.new("Frame")
	body.Name = "Board"
	body.Size = UDim2.fromScale(1, 1)
	body.BackgroundColor3 = spec.accent
	body.BorderSizePixel = 0
	body.ZIndex = 2
	body.Parent = gui

	-- ROUNDED IN SCALE, NOT IN PIXELS, and `Theme.corner` is deliberately not
	-- used for it. That helper takes an offset radius, which is right for a
	-- HUD card on a fixed screen and wrong here: a billboard's pixel size
	-- falls with distance, so a 12-pixel corner would be a nick up close and
	-- a lozenge from across the street.
	for _, f in ipairs({ shade, body }) do
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.34, 0)
		c.Parent = f
	end
	Theme.outline(body, 4, Theme.INK)

	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.Size = UDim2.fromScale(0.88, 0.62)
	label.Position = UDim2.fromScale(0.06, 0.19)
	label.BackgroundTransparency = 1
	label.Font = Theme.FONT
	label.TextScaled = true
	label.TextColor3 = Theme.PAPER
	label.Text = spec.name
	label.ZIndex = 3
	label.Parent = body

	-- The ink line round the letters as well as round the board. On a
	-- saturated fill in full sun, paper type alone goes soft at distance --
	-- an outline is what keeps a nine-year-old able to read it from the far
	-- pavement.
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Color = Theme.INK
	st.Parent = label
end

-- A PIER: the vertical that frames a shopfront, with a plinth block and a cap
-- block on it. Same argument `LowPoly.column` makes about a base and a
-- capital being the whole difference between a column and a pipe -- a pier
-- without them is a post, and a post does not hold up a building.
--
-- The shaft stops short at both ends and the two blocks cover the gap, so
-- neither block shares a face plane with the shaft it caps.
local function pier(model: Instance, at: (number, number, number) -> CFrame,
	x: number, w: number, d: number, baseY: number, topY: number,
	shaft: Color3, trim: Color3)
	local shaftY0, shaftY1 = baseY + 0.7, topY - 0.8
	add(model, "PierShaft", Vector3.new(w, shaftY1 - shaftY0, d),
		at(x, (shaftY0 + shaftY1) / 2, FRONT - d / 2 + 0.3), shaft)
	add(model, "PierBase", Vector3.new(w + 0.6, 1.0, d + 0.5),
		at(x, baseY + 0.4, FRONT - d / 2 + 0.35), trim)
	add(model, "PierCap", Vector3.new(w + 0.5, 0.9, d + 0.4),
		at(x, topY - 0.55, FRONT - d / 2 + 0.32), trim)
end

-- A SHOP WINDOW, which is a house window at four times the size and with the
-- one thing a house window must never have: you can see through it.
--
-- `LowPoly.framedWindow` is deliberately not used. It paints its pane Neon
-- or opaque SmoothPlastic, because a house window's job is to say the house
-- is LIVED IN -- and a display case whose glass you cannot see through is a
-- display case with nothing in it. Everything else about it is copied: a
-- frame, a sill, a mullion cross, and the mullions shorter and shallower than
-- the glass and at two different depths so no two of the three share a plane.
local function shopWindow(model: Instance, at: (number, number, number) -> CFrame,
	x: number, w: number, y0: number, y1: number, trim: Color3)
	local h = y1 - y0
	local cy = (y0 + y1) / 2
	local z = FRONT - 0.55

	add(model, "WinFrame", Vector3.new(w + 1.1, h + 1.1, 0.5), at(x, cy, z), JOINERY)

	-- A PALE PANE WITH REFLECTANCE ON IT IS A WHITE HOLE, WHICH IS THE THIRD
	-- TIME THIS PROJECT HAS PAID FOR THAT LESSON.
	--
	-- At 0.62 transparent with 0.12 of reflectance, a five-by-six pane of
	-- (176, 210, 224) facing a 14:30 sun renders as a specular sheet, and the
	-- BloomEffect in WorldService takes it from there: photographed, the
	-- whole left half of the boutique was a soft white cloud with the display
	-- inside it invisible and the hanging sign washed out behind it. Same
	-- family as the first Martian skin, the palace's first lit colonnade and
	-- the manor's eleven neon windows.
	--
	-- A SHOP WINDOW'S JOB IS TO BE LOOKED THROUGH, so the fix is the honest
	-- one rather than a dimmer tint: nearly transparent, and no reflectance
	-- at all. What reads as glass is then the FRAME, the mullion cross and
	-- the sill -- which is how the reference art draws one anyway.
	local pane = add(model, "WinGlass", Vector3.new(w, h, 0.3), at(x, cy, z + 0.14), GLASS)
	pane.Transparency = 0.78
	pane.Reflectance = 0

	-- Two mullions at two depths, both undersized against the glass, for the
	-- reason the house window records: authored at the pane's own width and
	-- height they share its four edge planes, and authored at one depth they
	-- share both Z planes with EACH OTHER right across the middle of the
	-- brightest surface on the building.
	add(model, "MullionV", Vector3.new(0.32, h - 0.16, 0.38), at(x, cy, z + 0.3), JOINERY)
	add(model, "MullionH", Vector3.new(w - 0.16, 0.32, 0.3), at(x, cy, z + 0.22), JOINERY)

	-- 0.30 and not 0.24: at 0.24 the sill's back face landed 0.01 from the
	-- frame's own, which is inside the depth buffer's noise and reads as a
	-- flickering line under every window on the street.
	-- The sill keeps the light trim: it is a LEDGE, it catches the sun, and a
	-- dark one under a dark frame loses the shadow line that says the glazing
	-- is set back.
	add(model, "Sill", Vector3.new(w + 2.0, 0.5, 1.0), at(x, y0 - 0.62, z + 0.30), trim)
end

-- ============================================================
-- STYLES
-- ============================================================
--
-- Each adds whatever makes this unit a different BUILDING from the one next
-- to it. The shell underneath is identical, which is what keeps four
-- buildings to one set of measurements.

type At = (x: number, y: number, z: number) -> CFrame

-- WHERE THE FRONTAGE ACTUALLY LANDED, handed to the style rather than
-- re-derived by it. The window's width and centre fall out of the pier
-- spacing and the door width, so a style that wants to hang something OVER
-- the window -- a blind, a roller shutter, a lit strip -- either gets told
-- where it is or guesses. The workshop's shutter guessed, and sat centred on
-- the unit while the window it was covering sat well to the left of that.
export type Layout = {
	glassX: number, glassW: number,
	doorX: number, doorW: number,
	clear: number,
	-- The display bay, which every unit now has and which the shell builds
	-- before the style runs -- so a style that wants to dress it is handed
	-- where it landed rather than re-deriving it. `bayTop` is the walking
	-- surface of the cap, so anything stood on it is seated off one number.
	bayZ: number, bayTop: number,
	wall: Color3, trim: Color3, base: Color3,
}

type Style = (model: Model, at: At, spec: Spec, cf: CFrame, L: Layout) -> ()

local STYLES: { [string]: Style } = {}

-- A BOUTIQUE. Tiled gable, a scalloped blind, rainbow neon and planters: it
-- sells the skins and the effects, so it is the loudest of the four on
-- purpose.
STYLES.boutique = function(model, at, spec, cf, L)
	local roof = spec.accent:Lerp(Color3.new(0, 0, 0), 0.28)

	-- THE SAME TILED ROOF EVERY REBUILT HOUSE ON THIS STREET WEARS. It was
	-- two bare leaning slabs, which is a ramp: the courses, the ridge cap,
	-- the fascia boards and the bargeboards up the gable ends are the whole
	-- difference between a roof and a wedge, and not one of them costs a
	-- decision here because the toolkit already made them.
	LowPoly.tiledRoof(model, WIDTH + 1.8, DEPTH + 1.8, HEIGHT, 4.8, 4, roof, CREAM, cf)

	-- A GABLE OVER THE ENTRANCE, which is what stops the frontage being a
	-- flat band under a roof that runs the other way. `pediment` rather than
	-- `capRoof`: a pediment slopes across WIDTH and is a hand thick, which is
	-- exactly a shop's entrance gable seen from the street.
	LowPoly.pediment(model, 11.0, 0.9, HEIGHT + 0.1, 3.0, CREAM, cf * CFrame.new(0, 0, FRONT + 0.55))
	add(model, "PedimentBed", Vector3.new(11.6, 0.7, 1.4), at(0, HEIGHT - 0.25, FRONT + 0.62), CREAM)

	-- A SCALLOPED BLIND, AND THE FIRST ONE WAS SIX BOLSTERS.
	--
	-- It was six cylinders 3.4 studs ACROSS laid side by side over the whole
	-- frontage, which at shop scale is a row of barrels -- photographed, it
	-- read as a padded roll bolted over the window and it was the loudest
	-- wrong thing on the unit. A real blind is a sloping sheet of cloth with a
	-- SCALLOPED VALANCE at its front edge: the scallops are a detail on the
	-- hem, roughly a stud across, not the awning itself.
	-- PROJECTING 3.8 AND STOPPING AT 9.1, not 4.4 and 8.4. Photographed from
	-- the pavement the first blind covered the entire shopfront: its hem hung
	-- 1.4 studs BELOW the window head, so from eye level there was no window
	-- and no display at all. A blind shades the top of a window; it does not
	-- replace it.
	local outZ = FRONT + 3.8
	local canvasY0, canvasY1 = TRANSOM_TOP - 0.1, 9.1
	local run = math.sqrt((outZ - FRONT) ^ 2 + (canvasY0 - canvasY1) ^ 2)
	local tilt = math.atan2(canvasY0 - canvasY1, outZ - FRONT)

	-- IT SHADES THE WINDOW, AND IT USED TO SHADE THE DOOR AS WELL.
	--
	-- `span` was `WIDTH + 0.6`, the whole frontage, so the hem ran straight
	-- across the entrance. Measured on the built unit: the door opening is
	-- y 1.20 to 10.28 and the scalloped hem hung at 7.22, which is THREE
	-- STUDS OF CANVAS AND HALF-ROUND SCALLOPS across the top of the doorway
	-- -- reported, correctly, as a curtain over the door.
	--
	-- THE FIX IS THE ONE THE ROLLER SHUTTER ALREADY CARRIES, one style down
	-- this file: "OVER THE BAY IT IS SHUTTING. Centred on the unit it
	-- covered half the window and half the door, because the glazing does
	-- not sit in the middle of a shopfront -- the door takes one end of it."
	-- The shutter learned it and the blind did not.
	--
	-- AND THE ENTRY ABOVE IS WHY IT SURVIVED. The hem was already raised
	-- once, 8.4 to 9.1, because the blind "covered the entire shopfront" --
	-- a real fix, measured against the WINDOW head, on a piece of geometry
	-- that also crosses the DOOR head. The number it was solved against was
	-- never the number that was wrong. Sized off the glazing it cannot cross
	-- the door at any hem height, which is the difference between a fix and
	-- a third raising.
	local span = L.glassW + 1.6
	local spanX = L.glassX
	for i = 0, 5 do
		-- Alternating stripes, which is what a shop blind is. Each panel is
		-- its own part rather than one sheet with a pattern on it, because
		-- flat colour has no surface to put a pattern on.
		local pw = span / 6
		add(model, "Canvas", Vector3.new(pw, 0.42, run),
			at(spanX - span / 2 + pw * (i + 0.5), (canvasY0 + canvasY1) / 2, (FRONT + outZ) / 2)
				* CFrame.Angles(tilt, 0, 0),
			if i % 2 == 0 then spec.accent else CREAM)
	end

	-- THE VALANCE IS THE HEM, AND IT HAS TO BE BIG ENOUGH TO BE A HEM.
	-- The first pass hung 1.5-stud scallops off a 0.75 rail and they were
	-- half buried in it, so from the pavement the blind's front edge read as
	-- a plain bar. A scallop shows the bottom half of a circle or it shows
	-- nothing.
	-- THE COUNT IS DERIVED AND THE WIDTH IS THE CONSTANT, WHICH IS THE HALF
	-- THAT DOES NOT SURVIVE A NARROWER RUN ON ITS OWN. `cylinderForward`
	-- takes LENGTH then DIAMETER, so `sd` is the scallop's own SIZE rather
	-- than merely where it sits: nine of them over the old 19.2-stud rail
	-- were 2.13 across, and nine over the glazing would be 0.76 -- a row of
	-- beads rather than a hem, which is the failure the entry below already
	-- describes from the other direction. Pinning the WIDTH and solving the
	-- count keeps the shape a photograph approved, at any span.
	local SCALLOP_W = 2.13
	local n = math.max(3, math.floor(span / SCALLOP_W + 0.5))
	local sd = span / n
	add(model, "ValanceRail", Vector3.new(span + 0.6, 1.0, 0.8),
		at(spanX, canvasY1 - 0.35, outZ), CREAM)
	for i = 0, n - 1 do
		cylinderForward(model, "Scallop", 0.7, sd,
			at(spanX - span / 2 + sd * (i + 0.5), canvasY1 - 0.85, outZ),
			if i % 2 == 0 then spec.accent else CREAM)
	end

	-- A neon band under the transom, running the whole spectrum. It sells
	-- colour, so it advertises in colour.
	-- ABOVE THE GLAZING, NOT UNDER IT, AND THAT WAS THE THIRD THING BLAMED FOR
	-- ONE WHITE BLOWOUT.
	--
	-- The window rendered as a featureless white sheet with the display
	-- invisible inside it. The pane was the first suspect and was innocent --
	-- dropping it to 0.86 transparent with no reflectance changed nothing.
	-- The trim was the second and was guilty of something else. Isolated by
	-- hiding the pane outright and re-shooting, the mullion cross came back
	-- as faint white lines on white: THE WHOLE APERTURE WAS OVER-EXPOSED,
	-- which is not something a pane can do.
	--
	-- It is this strip. A saturated Neon bar under a BloomEffect throws a
	-- halo far wider than itself, and sat directly beneath the glazing it
	-- washed the entire window -- so the one part of the shopfront built to
	-- SHOW something was the one part you could not see into. The same
	-- family as the manor's eleven lit windows and the palace's first
	-- colonnade, arriving from underneath rather than from the wall.
	--
	-- Moved onto the transom band its halo lands on a plain course with
	-- nothing behind it to hide, which is also where a real shop's sign light
	-- goes. Shortened as well, so it stays clear of the hanging sign's
	-- bracket -- the sign reaches inboard and the two would otherwise share a
	-- face plane.
	animate(add(model, "NeonStrip", Vector3.new(L.glassW - 0.8, 0.4, 0.4),
		at(L.glassX, GLAZE_TOP + 0.35, FRONT + 0.68), spec.accent, Enum.Material.Neon),
		"cycle", { Rate = 0.16, Sat = 0.78 })

	-- Planters. Inboard of the forecourt edge, because a robbable piggy used
	-- to stand at
	-- shop-local (-16, +16) with an apron that reaches back onto this paving.
	--
	-- AND OUTBOARD OF THE DOOR APPROACH, which is the half that was missing.
	-- At `WIDTH / 2 - 2.0` the right-hand planter stood x 7.00..10.00 against
	-- a clear door opening ending at 7.35, so it took a bite out of the one
	-- patch of paving somebody walks across to get in. One stud further out
	-- clears it and is still 1.2 inside the forecourt's own edge.
	for _, sx in ipairs({ -1, 1 }) do
		local px = sx * (WIDTH / 2 - 1.0)
		add(model, "PlanterBox", Vector3.new(3.0, 1.9, 3.0), at(px, PAVE_TOP + 0.85, FRONT + 4.6), STONE)
		add(model, "PlanterRim", Vector3.new(3.4, 0.45, 3.4), at(px, PAVE_TOP + 1.9, FRONT + 4.6), CREAM)
		ball(model, "Bloom", 2.3, at(px, PAVE_TOP + 3.1, FRONT + 4.6), Color3.fromRGB(226, 118, 156))
		ball(model, "Bloom", 1.5, at(px - sx * 0.9, PAVE_TOP + 2.5, FRONT + 5.2), Color3.fromRGB(246, 172, 196))
	end
end

-- A GLASSHOUSE. Open front under a timber beam, a glazed pitch, planting
-- spilling onto the pavement. The one unit with no display window, because a
-- garden centre does not have one -- its stock IS the frontage.
STYLES.garden = function(model, at, spec, cf, L)
	-- A GLAZED PITCH, AND THE GLAZING BARS GO IN THE ROOF PLANE.
	--
	-- They were five boxes 19 studs long laid FLAT across the top of the
	-- panes -- so they stuck out over both eaves and read as scaffolding
	-- dropped on the roof rather than as the frame holding it together. A bar
	-- runs UP the slope, in the slope, and there is one at every pane
	-- boundary because that is where a real one is.
	local pitch, half = 4.2, (DEPTH + 1.8) / 2
	local slope = math.sqrt(pitch * pitch + half * half)
	local theta = math.atan2(pitch, half)
	local panes = 6
	local paneW = (WIDTH + 1.8) / panes
	for _, dir in ipairs({ -1, 1 }) do
		for i = 0, panes - 1 do
			local px = -(WIDTH + 1.8) / 2 + paneW * (i + 0.5)
			local pane = add(model, "RoofGlass", Vector3.new(paneW - 0.55, 0.34, slope - 0.2),
				at(px, HEIGHT + pitch / 2, dir * (DEPTH + 1.8) / 4) * CFrame.Angles(dir * theta, 0, 0),
				GLASS)
			pane.Transparency = 0.5
			pane.Reflectance = 0.15
		end
		-- The bars: one per pane boundary, standing PROUD of the glass along
		-- the slope normal rather than lying on top of it in world Y.
		-- PROUD ALONG THE SLOPE NORMAL, which for this pitch is
		-- (0, cos, dir*sin). Lifting in world Y instead is what buried every
		-- course of the first tiled roof, and it would bury these too.
		local liftY = math.cos(theta) * 0.24
		local liftZ = math.sin(theta) * 0.24
		for i = 0, panes do
			local bx = -(WIDTH + 1.8) / 2 + paneW * i
			add(model, "GlazingBar", Vector3.new(0.42, 0.5, slope),
				at(bx, HEIGHT + pitch / 2 + liftY, dir * ((DEPTH + 1.8) / 4 + liftZ))
					* CFrame.Angles(dir * theta, 0, 0),
				CREAM)
		end
	end
	-- A ridge along the top, so the two pitches meet at a line rather than in
	-- a seam, and a gutter at each eave.
	add(model, "Ridge", Vector3.new(WIDTH + 2.3, 0.9, 1.1), at(0, HEIGHT + pitch + 0.15, 0), CREAM)
	for _, dir in ipairs({ -1, 1 }) do
		add(model, "Gutter", Vector3.new(WIDTH + 2.3, 0.85, 0.6),
			at(0, HEIGHT - 0.25, dir * (half + 0.15)), CREAM)
	end

	-- AN OPENING NEEDS SOMETHING BEHIND IT, AND IT USED TO GET A PARTITION.
	--
	-- The reasoning was right and the object was not. With the shell hollow
	-- and pale, this unit's open front read as a pale panel rather than as a
	-- way in: there was nothing darker than the wall anywhere behind it. So
	-- it grew a planted wall -- `WIDTH - 2.2` across, which measured x -7.90
	-- to +7.90, WHICH IS THE WHOLE ROOM -- standing at z 0.8 between the door
	-- and this unit's own vault. It gave the opening its depth and it walled
	-- off the thing a thief walks in to rob.
	--
	-- THE SHELL BUILDS A DISPLAY BAY FOR EVERY UNIT NOW, including this one,
	-- and the backdrop this needed is that bay's own `CaseBack`. What is left
	-- here is the PLANTING: pots on the bay cap, the same three the trestles
	-- outside carry, so a glasshouse still reads as full of stock and the
	-- floor behind it is floor.
	--
	-- SEATED OFF `L.bayTop` RATHER THAN OFF `RISER_TOP`. The cap's height is
	-- the shell's to decide and this is the only thing standing on it; a
	-- second derivation here is a row of pots hanging in the air the first
	-- time the bay moves.
	for i = -1, 1 do
		local px = L.glassX + i * 2.0
		-- Sunk 0.05 into the cap rather than resting on it, which is the
		-- convention every rebuilt house tier keeps: anything standing on
		-- something shares its bottom plane with that thing's top the moment
		-- it is seated exactly.
		add(model, "Pot", Vector3.new(1.25, 1.2, 1.25),
			at(px, L.bayTop + 0.55, L.bayZ), Color3.fromRGB(196, 104, 70))
		add(model, "PotRim", Vector3.new(1.5, 0.32, 1.5),
			at(px, L.bayTop + 1.05, L.bayZ), Color3.fromRGB(168, 84, 56))
		ball(model, "InnerShrub", 1.7, at(px, L.bayTop + 2.0, L.bayZ),
			Color3.fromRGB(88, 152, 88))
	end

	-- The open front: a timber beam on the piers rather than glazing, which
	-- is the whole reason this unit reads differently up close.
	--
	-- OVER THE BAY, NOT OVER THE FRONTAGE, AND THIS ONE WAS THE WORSE OF THE
	-- TWO. The boutique's blind crossed the door head; this beam was
	-- `WIDTH - 3.0` at `RISER_TOP + 0.4`, which measured y 4.05 to 5.15
	-- across x -7.50 to +7.50 -- CHEST TO HEAD HEIGHT, straight through the
	-- entrance, on the one unit whose whole idea is that you can see into
	-- it. Nothing collides in this building, so a player walked through it
	-- rather than into it, which is exactly why nobody filed it as a wall.
	--
	-- The rafters had it too: authored at `i * 3.6`, the outermost landed at
	-- x 3.35..3.85 against a door at x 1.00..6.50, so one of the three ran
	-- across the doorway at y 9.00 to 9.60. Spread over the glazing instead,
	-- they cannot reach it at any count.
	local openW = L.glassW + 1.6
	add(model, "OpenBeam", Vector3.new(openW, 1.1, 1.4),
		at(L.glassX, RISER_TOP + 0.4, FRONT - 0.6), TIMBER)
	for i = -1, 1 do
		add(model, "Rafter", Vector3.new(0.5, 0.6, 3.0),
			at(L.glassX + i * (L.glassW / 3), GLAZE_TOP - 0.5, FRONT - 1.4), TIMBER)
	end

	-- AT THE BOUTIQUE'S OWN HEIGHT, WHICH IS WHERE IT SHOULD HAVE BEEN ANYWAY.
	--
	-- Up on the transom band it ran the full frontage at exactly the height
	-- the hanging sign crosses it, and chasing that with depth was chasing
	-- the wrong axis: moved out 0.10 it met the sign's lower rail, moved out
	-- again it met the board itself, because the whole sign assembly starts
	-- at FRONT + 0.3 and reaches out three and a half studs. THE ANSWER WAS
	-- THE OTHER AXIS -- drop it below the sign and there is nothing for it to
	-- share a plane with at any depth. It also puts the two neon strips on
	-- the street at one height, which is what a parade of shops looks like.
	-- Same placement as the boutique's, for the reason written over that one:
	-- a neon bar under a window blows the window out.
	animate(add(model, "NeonStrip", Vector3.new(L.glassW - 0.8, 0.4, 0.4),
		at(L.glassX, GLAZE_TOP + 0.35, FRONT + 0.68), spec.accent, Enum.Material.Neon),
		"pulse", { Rate = 0.22, Hue = 0.32, Sat = 0.7, Dim = 0.45 })

	-- Trestles of plants in front of the GLAZING, which is what a garden
	-- centre actually looks like from a road -- and which is the same rule
	-- the beam and the rafters above just took, applied to the paving.
	--
	-- THREE OF THEM ACROSS THE WHOLE FRONTAGE WALLED THE DOOR OFF. Authored
	-- at `i * 5.6` about the unit's centre, the right-hand trestle stood
	-- x 3.10..8.10 against a clear door opening of 3.15..7.35 -- a five-stud
	-- bench of pot plants directly across the entrance, photographed from the
	-- pavement as a hedge with a shop behind it. The unit's centre is not the
	-- window's centre, because the door takes one end of the frontage; that
	-- is the whole reason anything dressing this shopfront has to be sized
	-- and placed off the glazing.
	--
	-- TWO RATHER THAN THREE, because at a 5.0-stud trestle the third does not
	-- fit in front of the window without overlapping its neighbour -- and two
	-- trestles that read as a bench beat three that share a top face and
	-- flicker.
	for i = -1, 1, 2 do
		local x = L.glassX + i * 2.8
		add(model, "Trestle", Vector3.new(5.0, 0.45, 2.4), at(x, PAVE_TOP + 1.85, FRONT + 4.4), TIMBER)
		for _, sx in ipairs({ -1, 1 }) do
			add(model, "TrestleLeg", Vector3.new(0.45, 1.6, 0.45),
				at(x + sx * 2.0, PAVE_TOP + 0.85, FRONT + 4.4), TIMBER)
		end
		for j = -1, 1 do
			add(model, "Pot", Vector3.new(1.25, 1.2, 1.25),
				at(x + j * 1.6, PAVE_TOP + 2.55, FRONT + 4.4), Color3.fromRGB(196, 104, 70))
			add(model, "PotRim", Vector3.new(1.5, 0.32, 1.5),
				at(x + j * 1.6, PAVE_TOP + 3.05, FRONT + 4.4), Color3.fromRGB(168, 84, 56))
			ball(model, "Shrub", 1.7, at(x + j * 1.6, PAVE_TOP + 4.0, FRONT + 4.4),
				Color3.fromRGB(88, 152, 88))
		end
	end
end

-- A WORKSHOP. Flat roof behind a coped parapet, a run of chasing bulbs, a
-- roller bay instead of a display window, and a quarter pipe on the forecourt.
STYLES.wheels = function(model, at, spec, cf, L)
	-- A PARAPET RING, NOT A BLOCK. It was one solid slab `WIDTH + 1.6` by
	-- `DEPTH + 1.6` by four studs tall sitting on the roof -- which from the
	-- street is a second storey of blank wall, and from anywhere else is a
	-- lid. A parapet is a low wall round the EDGE of a flat roof with the
	-- roof visible inside it, which is what the toolkit's own helper builds.
	add(model, "RoofDeck", Vector3.new(WIDTH + 0.6, 0.6, DEPTH + 0.6),
		at(0, HEIGHT + 0.3, 0), Color3.fromRGB(96, 98, 106))
	LowPoly.parapet(model, WIDTH + 0.6, DEPTH + 0.6, HEIGHT + 0.5, 3.2, 1.1, L.wall, cf)
	-- The coping on top of it, a shade wider so it caps rather than continues.
	for _, sz in ipairs({ -1, 1 }) do
		add(model, "Coping", Vector3.new(WIDTH + 3.4, 0.65, 1.5),
			at(0, HEIGHT + 3.85, sz * ((DEPTH + 0.6) / 2 + 0.55)), spec.accent)
	end
	for _, sx in ipairs({ -1, 1 }) do
		add(model, "Coping", Vector3.new(1.5, 0.6, DEPTH + 0.5),
			at(sx * ((WIDTH + 0.6) / 2 + 0.55), HEIGHT + 3.8, 0), spec.accent)
	end

	-- A CHASE, NOT A BLINK. Each bulb carries its own Phase, so one bright
	-- band travels the run -- which is what a bulb sign does, and is nowhere
	-- near the flash ceiling a switch would be flirting with. Nine of them,
	-- exactly as before: the geometry moved outboard of the new coping and
	-- the light show did not change at all.
	local n = 9
	for i = 0, n - 1 do
		local bulb = ball(model, "Bulb", 0.95,
			at(-WIDTH / 2 + (WIDTH / (n - 1)) * i, HEIGHT + 2.0, (DEPTH + 0.6) / 2 + 1.35),
			spec.accent, Enum.Material.Neon)
		-- Dim 0.42 and not 0.22. A chase leaves most of its run at the dim
		-- end at any instant, and against the old grey parapet 0.22 read as
		-- an unlit bulb -- against the pale wall this unit has now, it read
		-- as a BROWN HOLE punched in the coping. The band still travels; the
		-- bulbs it has passed still look like bulbs.
		animate(bulb, "chase",
			{ Rate = 0.5, Phase = i / n, Hue = 0.09, Sat = 0.85, Span = 0.28, Dim = 0.42 })
	end

	-- A roller shutter, half open, over the bay. The ribs alternate depth as
	-- well as height: authored at one Z they shared both face planes with each
	-- other all the way down the shutter, which is four coplanar pairs on the
	-- flattest surface of the unit.
	-- HUNG OUTSIDE THE GLASS, which is where a real roller shutter hangs and
	-- is also what stops its own bottom face landing 0.005 from the window
	-- pane behind it.
	-- OVER THE BAY IT IS SHUTTING. Centred on the unit it covered half the
	-- window and half the door, because the glazing does not sit in the
	-- middle of a shopfront -- the door takes one end of it.
	local bayW, bayX = L.glassW + 1.6, L.glassX
	add(model, "Shutter", Vector3.new(bayW, 2.6, 0.5), at(bayX, GLAZE_TOP - 1.0, FRONT + 0.1), LEAD)
	for i = 0, 3 do
		add(model, "ShutterRib", Vector3.new(bayW - 0.5, 0.22, 0.52),
			at(bayX, GLAZE_TOP - 2.0 + i * 0.62, FRONT + 0.38 + (i % 2) * 0.06),
			LEAD:Lerp(Color3.new(0, 0, 0), 0.3))
	end
	add(model, "ShutterBox", Vector3.new(bayW + 0.8, 1.0, 1.1), at(bayX, GLAZE_TOP + 0.55, FRONT + 0.15), FRAME)

	-- A QUARTER PIPE, stacked from boxes on a circular arc.
	--
	-- Roblox has no curved ramp primitive, and a CSG union would be a MESH
	-- whose fidelity is a plugin-only property -- reaching for that took the
	-- whole server down once already, so it is not being reached for here.
	-- Eight steps read as a curve at street distance.
	--
	-- ON THE LEFT NOW, AND THE REASON IT WAS ON THE RIGHT HAS EXPIRED. That
	-- reason was "a robbable piggy used to stand out to the left" -- the
	-- till, which was retired when the target moved inside the building, and
	-- this file's own entry records that nothing of this game's stands on the
	-- verge any more. What the stale placement cost is that the ramp is six
	-- studs wide on the same side as the entrance: measured, it stood
	-- x 5.50..11.50 against a clear door opening of 3.15..7.35, so the
	-- quarter pipe was parked across the way in. It could not simply move
	-- outboard the way the boutique's planters did -- clearing the door
	-- would put its far edge a stud past the forecourt itself.
	--
	-- The bollard swaps to the right to keep the frontage balanced, and it is
	-- narrow enough to clear the opening where the ramp was not.
	local steps, radius = 8, 5.2
	for i = 0, steps - 1 do
		local a0 = (i / steps) * (math.pi / 2)
		local a1 = ((i + 1) / steps) * (math.pi / 2)
		local mid = (a0 + a1) / 2
		add(model, "Ramp", Vector3.new(6.0, 0.62, radius * (a1 - a0) + 0.62),
			at(-(WIDTH / 2 - 2.0),
				PAVE_TOP + radius * (1 - math.cos(mid)) + 0.5,
				FRONT + 5.0 + radius * math.sin(mid))
				* CFrame.Angles(mid, 0, 0),
			Color3.fromRGB(198, 158, 106))
	end
	add(model, "RampLip", Vector3.new(6.3, 0.5, 0.7),
		at(-(WIDTH / 2 - 2.0), PAVE_TOP + radius + 0.6, FRONT + 5.0), spec.accent)

	cylinderUp(model, "Bollard", 3.4, 0.85, at(WIDTH / 2 - 1.6, PAVE_TOP + 1.6, FRONT + 3.2), GOLD)
	ball(model, "BollardCap", 0.9, at(WIDTH / 2 - 1.6, PAVE_TOP + 3.3, FRONT + 3.2), GOLD)
end

-- A STRONGROOM. Castellated parapet, barred glass, one slow blue lamp and a
-- vault dial on the pier. It sells both trees, so it reads as a place that
-- keeps things AND opens them.
STYLES.security = function(model, at, spec, cf, L)
	add(model, "RoofDeck", Vector3.new(WIDTH + 0.6, 0.6, DEPTH + 0.6),
		at(0, HEIGHT + 0.3, 0), STONE:Lerp(Color3.new(0, 0, 0), 0.3))
	LowPoly.parapet(model, WIDTH + 0.6, DEPTH + 0.6, HEIGHT + 0.5, 2.0, 1.1, STONE, cf)

	-- MERLONS ON THE PARAPET, AND THEY MAY NOT SHARE A PLANE WITH IT.
	--
	-- The old row sat at exactly the parapet's own Z with exactly its own
	-- thickness, which is seven coplanar pairs in a line across the top of
	-- the building -- the single worst cluster on any of the four. They stand
	-- 0.16 proud on both faces now and sink into the coping they stand on.
	local n = 7
	local mw = (WIDTH + 0.6) / (n * 1.9)
	for i = 0, n - 1 do
		add(model, "Merlon", Vector3.new(mw, 2.0, 1.42),
			at(-(WIDTH + 0.6) / 2 + ((WIDTH + 0.6) / (n - 1)) * i, HEIGHT + 3.4,
				(DEPTH + 0.6) / 2 + 0.55),
			STONE)
	end
	for _, sz in ipairs({ -1, 1 }) do
		add(model, "Coping", Vector3.new(WIDTH + 3.2, 0.55, 1.34),
			at(0, HEIGHT + 2.65, sz * ((DEPTH + 0.6) / 2 + 0.55)), STONE:Lerp(CREAM, 0.35))
	end

	-- Bars across the glazing. Cylinders standing up, via the wrapper: the
	-- length is Size.X and the turn is what stands it on end.
	-- SPACED ACROSS THE GLAZING RATHER THAN COUNTED OUT FROM THE MIDDLE, so
	-- the run always fills the window whatever the pier spacing does next.
	local bars = 7
	for i = 1, bars do
		cylinderUp(model, "Bar", GLAZE_TOP - RISER_TOP + 0.4, 0.3,
			at(L.glassX - L.glassW / 2 + (L.glassW / (bars + 1)) * i,
				(RISER_TOP + GLAZE_TOP) / 2, FRONT - 0.18), LEAD)
	end
	for _, y in ipairs({ RISER_TOP + 0.55, GLAZE_TOP - 0.55 }) do
		add(model, "BarRail", Vector3.new(L.glassW - 0.3, 0.34, 0.36), at(L.glassX, y, FRONT - 0.16), LEAD)
	end

	-- A security lamp: a lighthouse swell rather than a strobe, which is both
	-- what a rotating lamp actually looks like and what keeps it well under
	-- the flash guidance this project holds itself to.
	add(model, "LampBase", Vector3.new(1.5, 0.7, 1.5), at(0, HEIGHT + 3.05, (DEPTH + 0.6) / 2 + 0.55), FRAME)
	animate(ball(model, "Lamp", 1.7,
		at(0, HEIGHT + 4.1, (DEPTH + 0.6) / 2 + 0.55), spec.accent, Enum.Material.Neon),
		"beacon", { Rate = 0.42, Hue = 0.58, Sat = 0.75, Dim = 0.2 })

	-- A vault dial on the pier beside the door: the same motif the piggy's
	-- own lock uses, read at shop scale. Each layer stands at its own depth,
	-- so the plate, the spokes and the hub cannot z-fight -- which is the rule
	-- the piggy's own dial was built to and this one was not.
	local plateX = -(L.clear + 1.4)
	local faceZ = FRONT + 0.62
	-- 3.6 across, not 4.4. The pier it is mounted on is 2.8 wide, so at 4.4
	-- the plate overhung it by 0.8 a side and read as a wheel bolted to the
	-- corner of the building rather than as a dial set into a pier.
	cylinderAlongX(model, "DialPlate", 0.5, 3.6,
		at(plateX, (RISER_TOP + GLAZE_TOP) / 2, faceZ) * CFrame.Angles(0, math.rad(90), 0),
		STONE:Lerp(CREAM, 0.2))
	for i = 0, 3 do
		add(model, "DialSpoke", Vector3.new(0.46, 2.9, 0.34),
			at(plateX, (RISER_TOP + GLAZE_TOP) / 2, faceZ + 0.34)
				* CFrame.Angles(0, 0, (i / 4) * math.pi * 2 + math.rad(22.5)),
			GOLD)
	end
	cylinderAlongX(model, "DialHub", 0.6, 1.3,
		at(plateX, (RISER_TOP + GLAZE_TOP) / 2, faceZ + 0.62) * CFrame.Angles(0, math.rad(90), 0),
		GOLD)

	cylinderUp(model, "Bollard", 3.2, 0.95, at(WIDTH / 2 - 1.8, PAVE_TOP + 1.5, FRONT + 3.4), STONE)
	ball(model, "BollardCap", 1.0, at(WIDTH / 2 - 1.8, PAVE_TOP + 3.1, FRONT + 3.4), STONE:Lerp(CREAM, 0.3))
end

-- ============================================================
-- THE SHELL
-- ============================================================

function ShopFront.build(cf: CFrame, groundY: number, spec: Spec, parent: Instance): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "Shop_" .. spec.tab

	-- Authored in the unit's own frame with y=0 AT THE GROUND, the contract
	-- the rides and the accessories keep: a builder that measures from its
	-- own middle cannot be stood on anything.
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end

	local glazed = spec.style ~= "garden"

	-- THE WALLS ARE A PALE TINT OF THE SHOP'S OWN COLOUR, AND THE FIRST BUILD
	-- MADE THEM ALL THE SAME WHITE.
	--
	-- Photographed, that was the one thing still wrong after the rebuild: the
	-- wall, the piers, the quoins, the plinth, the cornice and the transom
	-- were five near-identical off-whites, so a unit read as ONE WHITE MASS
	-- with a coloured roof on it -- and all four read as the same white mass.
	-- The four silhouettes were doing all the work and the four PALETTES were
	-- doing none.
	--
	-- Every rebuilt house on this street carries a real wall colour -- brick
	-- red, cream, near-black -- with its trim in something clearly different.
	-- A shop takes the same arrangement one step further: the wall is the
	-- accent lerped most of the way to white, so the boutique is pale pink,
	-- the garden centre pale green, the workshop pale amber and the
	-- strongroom pale blue. THE HUE IS THE SHOP, and it costs nothing, and it
	-- is readable from further away than any of the geometry is.
	--
	-- 0.82 rather than 0.7: this is a WALL, and a saturated one competes with
	-- the fascia and the roof, which are the two things carrying the accent
	-- at full strength. Measured against the four accents it lands between
	-- (225, 236, 221) and (248, 222, 213) -- all of them plainly tinted and
	-- none of them a colour anybody would call the shop.
	-- 0.70 rather than 0.82: at 0.82 the tint was there in the numbers and
	-- gone in the photograph, because the trim in front of it was lighter
	-- still. Pulled back, the wall is unmistakably the shop's own colour and
	-- the trim reads as trim.
	local WALL = spec.accent:Lerp(Color3.fromRGB(250, 247, 240), 0.70)
	local trim = CREAM
	-- Deeper than the paving it stands on, so the base course reads as a base
	-- course rather than as more pavement.
	local base = STONE:Lerp(Color3.new(0, 0, 0), 0.14)
	local wallH = HEIGHT - PLINTH_TOP + SINK

	-- A paved forecourt, so the unit meets the grass at a made edge rather
	-- than a wall growing out of a lawn. Proud of the ground, never level:
	-- two faces at one depth is the coplanar flicker this project has caught
	-- at the road, the moat and the guard dog's own eyes.
	add(model, "Forecourt", Vector3.new(WIDTH + FORECOURT_OVERHANG, PAVE_TOP, DEPTH + 7),
		at(0, PAVE_TOP / 2, 3.4), STONE)
	-- A kerb round the paving, which is the moat's own trick at a twentieth
	-- of the scale: nothing here can be DUG, so an edge is made by standing
	-- something PROUD rather than by sinking the middle.
	local kerbTone = STONE:Lerp(CREAM, 0.3)
	for _, sx in ipairs({ -1, 1 }) do
		add(model, "Kerb", Vector3.new(0.7, 0.68, DEPTH + 7.2),
			at(sx * ((WIDTH + FORECOURT_OVERHANG) / 2 + 0.2), 0.28, 3.4), kerbTone)
	end
	-- The threshold course across the front, standing a touch taller than the
	-- two beside it -- at a matched height it shares both its Y planes with
	-- them where they meet, which is the coplanar fault this whole pass is
	-- about arriving on the paving a player walks over to reach the door.
	add(model, "Kerb", Vector3.new(WIDTH + FORECOURT_OVERHANG + 1.4, 0.98, 0.8),
		at(0, 0.23, 3.4 + (DEPTH + 7.2) / 2 + 0.05), kerbTone)

	-- THE PLINTH. A base course under the walls, which is what stops a
	-- building looking like a box resting on paving -- one of the four things
	-- the house pass measured against reference art, and the only one of them
	-- these units had none of.
	--
	-- A RING RATHER THAN A RAFT, AND IT HAD TO BECOME ONE THE DAY THE SHOP
	-- ACQUIRED AN INSIDE. It was one solid slab across the whole footprint,
	-- 0.3 to 1.6, which is invisible and correct for as long as nobody stands
	-- in it. The interior floor's top is at `SHOP_UNIT.floorY` -- a plot slab
	-- above the pavement -- so a solid plinth stood SIX TENTHS OF A STUD
	-- PROUD of the floor across the entire room, and a shopkeeper behind the
	-- counter was buried to the shin in it.
	--
	-- Nothing about the outside changes: the only faces of a plinth anybody
	-- ever sees are its outer ones. What it costs is three extra parts and a
	-- rule -- the bars BUTT rather than cross at the corners, which is what
	-- keeps four pieces of one frame from being four coplanar pairs.
	--
	-- The inner faces are held clear of the floor slab on purpose, and the
	-- slab is a touch wider than the room so the two overlap rather than
	-- meeting: a hairline gap between a floor and its own base course is a
	-- crack you can see the world through.
	do
		local outerX, outerZ = (WIDTH + 1.5) / 2, (DEPTH + 1.5) / 2
		local h = PLINTH_TOP - PAVE_TOP + SINK
		local y = (PAVE_TOP - SINK + PLINTH_TOP) / 2
		local sideT, endT = 1.5, 1.4
		for _, sx in ipairs({ -1, 1 }) do
			add(model, "Plinth", Vector3.new(sideT, h, outerZ * 2),
				at(sx * (outerX - sideT / 2), y, 0), base)
		end
		for _, sz in ipairs({ -1, 1 }) do
			add(model, "Plinth", Vector3.new((outerX - sideT) * 2, h, endT),
				at(0, y, sz * (outerZ - endT / 2)), base)
		end
	end

	-- The shell. Flat colour, no texture: `Brick` on the sides and `Concrete`
	-- on the roof were the two loudest things on this street once every house
	-- behind them had stopped being textured.
	add(model, "Back", Vector3.new(WIDTH - 1.6, wallH, 0.8),
		at(0, PLINTH_TOP - SINK + wallH / 2, -DEPTH / 2 + 0.1), WALL)
	for _, sx in ipairs({ -1, 1 }) do
		add(model, "Side", Vector3.new(0.8, wallH, DEPTH - 0.4),
			at(sx * (WIDTH / 2 - 0.1), PLINTH_TOP - SINK + wallH / 2, 0), WALL)
	end

	-- QUOINS ON THE BACK CORNERS ONLY. Run round all four they stand in the
	-- middle of the shopfront; the front pair are PIERS instead, below.
	LowPoly.quoins(model, WIDTH, DEPTH, PLINTH_TOP - SINK, wallH, trim, cf, true)

	-- ---------- the room ----------
	--
	-- A SHOP IS SOMEWHERE YOU GO IN, and the plan is `Config.SHOP_ROOM`
	-- rather than a set of placements chosen here. See the entry over that
	-- table for the three measurements that moved it out of this file: the
	-- short version is that the counter, the shelves and the display case
	-- were each sized correctly and nobody had added them up against the
	-- twelve and a half studs of depth they share.
	--
	-- The floor and the vault are built by `PlotService`, because they belong
	-- to the PLOT -- the floor is an ordinary plot base and the vault is what
	-- a plot's money sits in, so the shopkeeper, the steal prompt, the rob
	-- badge and the lock ladder all arrive for nothing.
	--
	-- NONE OF THE FITTINGS COLLIDE, and that is deliberate rather than
	-- leftover. The barrier ring further down is the only thing in this
	-- building a player can walk into; a counter that body-blocked would be
	-- furniture standing in the one walk a robbery needs, and the bands in
	-- `SHOP_ROOM` are what keep it out of that walk instead.
	local R = Config.SHOP_ROOM
	do
		local floor = Config.SHOP_UNIT.floorY

		-- THE COUNTER, ACROSS THE FITTINGS SIDE AND WELL CLEAR OF THE AISLE.
		-- The door sits to one side of the frontage because the display
		-- window takes the other, and the vault stands on the door's own
		-- centre line -- so the walk in is a straight line to the thing being
		-- robbed and the counter is beside it rather than across it.
		--
		-- IT STOPS AT `counterRight` AND THE OLD ONE DID NOT. That reached
		-- x -0.70, which is 0.53 studs from the swept edge of the open vault
		-- door: two obstacles in a line with a slot between them rather than
		-- a way past. What paid for the POCKET behind it is not this counter
		-- moving -- it moved back, if anything -- it is the shelves leaving
		-- the back wall, so the wall itself is the pocket's rear edge now.
		--
		-- THE TOP OVERSAILS FORWARD ONLY, which is what a counter does and is
		-- also what keeps the arithmetic honest: `counterBack` is then the
		-- back face of BOTH pieces, so the pocket behind is one subtraction
		-- rather than a subtraction and a nosing somebody has to remember.
		--
		-- AND THE BODY IS SUNK 0.15 BEHIND THE TOP RATHER THAN FLUSH WITH IT.
		-- Flush, the two share their back plane over the whole run with 0.175
		-- studs of height to fight over -- a coplanar pair along the exact
		-- edge the shopkeeper stands at, which is this project's most
		-- repeated rendering fault arriving on the newest piece of furniture
		-- in the game. `counterBack` stays the TOP's back face, so the pocket
		-- is still one subtraction.
		local COUNTER_NOSING, COUNTER_TUCK = 0.4, 0.15
		local counterW = R.counterRight - R.counterLeft
		local counterX = (R.counterLeft + R.counterRight) / 2
		local topD = R.counterFront - R.counterBack
		local bodyD = topD - COUNTER_NOSING - COUNTER_TUCK
		local bodyZ = R.counterBack + COUNTER_TUCK + bodyD / 2
		add(model, "Counter", Vector3.new(counterW - 0.4, 3.1, bodyD),
			at(counterX, floor + 1.45, bodyZ), TIMBER)
		add(model, "CounterTop", Vector3.new(counterW, 0.35, topD),
			at(counterX, floor + 3.0, R.counterBack + topD / 2), trim)
		add(model, "CounterPanel", Vector3.new(counterW - 1.8, 1.8, 0.3),
			at(counterX, floor + 1.6, R.counterFront - COUNTER_NOSING + 0.05),
			TIMBER:Lerp(Color3.new(0, 0, 0), 0.22))
		-- A till on the counter, which is the one place a word like that
		-- still belongs now the piggy bank has come off the forecourt.
		add(model, "Register", Vector3.new(1.5, 1.1, 1.1),
			at(R.counterRight - 1.4, floor + 3.7, bodyZ), LEAD)

		-- SHELVES ALONG THE LEFT WALL, WHICH IS THE MOVE THAT MADE THE REST
		-- OF THE ROOM FIT. They stood on the BACK wall, where 1.3 studs of
		-- them came out of the room's depth -- the axis the counter, the
		-- pocket, the customer strip and the window bay were all bidding for.
		-- Turned onto the side wall they cost width instead, and nothing else
		-- in here wants width.
		--
		-- The uprights are still DEEPER than the boards rather than the same
		-- depth, and the axis that word means has turned with them: at a
		-- matched depth every board would share both its X planes with both
		-- uprights over a real patch, which is six coplanar pairs on one
		-- piece of shop fitting.
		--
		-- `shelfFace` IS THE UPRIGHT'S FACE, NOT THE BOARD'S, because the
		-- upright is the piece that reaches furthest into the room and the
		-- pocket behind starts at whatever does. Anchored on the boards
		-- instead the uprights stand 0.10 studs past the line the audit is
		-- measuring the pocket from -- true, small, and exactly the kind of
		-- off-by-a-part that makes a checked number stop describing the room.
		local SHELF_DEPTH, SHELF_UPRIGHT = 1.15, 1.35
		local shelfX = R.shelfFace - SHELF_UPRIGHT / 2
		local shelfZ = (R.shelfBack + R.shelfFront) / 2
		local shelfRun = R.shelfFront - R.shelfBack
		for _, sz in ipairs({ -1, 1 }) do
			add(model, "ShelfUpright", Vector3.new(SHELF_UPRIGHT, 4.4, 0.35),
				at(shelfX, floor + 2.1, shelfZ + sz * shelfRun / 2), TIMBER)
		end
		for i = 0, 2 do
			add(model, "Shelf", Vector3.new(SHELF_DEPTH, 0.28, shelfRun),
				at(shelfX, floor + 1.2 + i * 1.4, shelfZ), TIMBER)
			-- Stock. Three boxes a shelf in the shop's own colour, which is
			-- what stops a set of empty shelves reading as a closed unit.
			for j = -1, 1 do
				add(model, "Stock", Vector3.new(0.8, 0.9, 1.1),
					at(shelfX, floor + 1.79 + i * 1.4, shelfZ + j * 1.5),
					spec.accent:Lerp(CREAM, 0.35 + 0.12 * j))
			end
		end
	end

	-- ---------- the frontage ----------
	--
	-- Five bands: piers, a stall riser, glazing, a transom and a fascia. That
	-- order is what says SHOP rather than "house with a big window", and it
	-- is why the band heights are constants at the top of this file rather
	-- than numbers each style invents for itself.
	local pierW = 2.8
	local pierX = WIDTH / 2 - pierW / 2 - 0.2
	for _, sx in ipairs({ -1, 1 }) do
		pier(model, at, sx * pierX, pierW, 2.0, PLINTH_TOP - SINK, TRANSOM_TOP, WALL, trim)
	end

	local clear = pierX - pierW / 2 -- inner face of each pier
	local doorW = 4.2
	local doorX = clear - doorW / 2 - 0.15

	-- THE GLAZING IS SIZED AGAINST THE SILL, NOT AGAINST THE PANE. The sill
	-- oversails its own glass by a stud each side and the stall riser by
	-- more, so a window filling the clear span puts both of them through the
	-- door frame -- which is a merged ledge as well as a coplanar pair, and
	-- is exactly what `LowPoly.windowBand` exists to stop happening to the
	-- house window ranks. The 2.0 is what the widest piece of the assembly
	-- needs, not what looks about right.
	local winLeft = -clear + 0.4
	local winRight = doorX - doorW / 2 - 2.0
	local glassW = winRight - winLeft
	local glassX = (winLeft + winRight) / 2

	-- THE STALL RISER: the solid under the glass. It is the one band a shop
	-- has that a house does not, and without it a display window starts at
	-- the pavement and everything in it stands in a pit.
	add(model, "StallRiser", Vector3.new(glassW + 2.4, RISER_TOP - PLINTH_TOP + SINK, 0.9),
		at(glassX, (PLINTH_TOP - SINK + RISER_TOP) / 2, FRONT - 0.5), TIMBER)
	add(model, "RiserPanel", Vector3.new(glassW - 0.6, RISER_TOP - PLINTH_TOP - 1.1, 0.5),
		at(glassX, (PLINTH_TOP + RISER_TOP) / 2 - 0.1, FRONT - 0.2),
		TIMBER:Lerp(Color3.new(0, 0, 0), 0.22))

	-- ---------- the display bay ----------
	--
	-- BUILT FOR EVERY UNIT, INCLUDING THE ONE WITH NO WINDOW, and that is the
	-- fix for the worst thing in this building rather than a tidy-up. The
	-- garden centre had no bay, so its own "an opening needs something behind
	-- it" backdrop was a planted wall `WIDTH - 2.2` across -- measured, x
	-- -7.90 to +7.90, which is the WHOLE ROOM -- standing at z 0.8 between
	-- the door and the vault it is supposed to lead you to. Every other unit
	-- had the bay and the garden centre had a partition.
	--
	-- One bay, dressed differently: a model in a window here, a row of pots
	-- there. `STYLES.garden` plants it, which is why this is built before the
	-- styles run rather than after them.
	--
	-- IT IS SHALLOW NOW, AND THE DEPTH IS SOLVED RATHER THAN CHOSEN. The old
	-- one ran from z 1.10 to 6.00 -- 4.9 studs of a 12.6-stud room, with a
	-- full-height backboard at the back of it -- which is what left 1.45
	-- studs between it and the counter. The cap's own depth is what the
	-- DISPLAY needs: a near-cubic model at `DISPLAY_SPAN` turned
	-- `DISPLAY_YAW` presents 4.09 studs of z, so the plinth carries it
	-- with a hand's clearance to the backboard behind and to the glass in
	-- front, and not a stud more.
	local yaw = math.rad(DISPLAY_YAW)
	local BAY_CAP_DEPTH = DISPLAY_SPAN * (math.cos(yaw) + math.sin(yaw)) - 0.55
	local BAY_PLINTH_DEPTH = BAY_CAP_DEPTH - 0.4
	local bayZ = R.bayFront - BAY_CAP_DEPTH / 2

	-- A DISPLAY CASE HAS A BACK, AND WITHOUT ONE THE WINDOW IS A HOLE INTO A
	-- LIT WHITE BOX.
	--
	-- This is what one white blowout actually was, after the pane and the
	-- neon strip had both been accused and cleared. Probed by walking the
	-- model and testing the aperture point by hand -- spatial queries are
	-- useless in here, because every part this file builds is `CanQuery`
	-- false -- the only thing standing in the opening was the display's OWN
	-- BODY: a 3.7-stud sphere filling most of the window, pressed against the
	-- glass, in full sun, with the shop's interior behind it and a
	-- BloomEffect over the top. Nothing was broken. It was the entire view.
	local caseTone = spec.accent:Lerp(Color3.new(0, 0, 0), 0.62)
	add(model, "CaseBack", Vector3.new(R.caseWidth, GLAZE_TOP - PLINTH_TOP + 0.6, 0.6),
		at(glassX, (PLINTH_TOP + GLAZE_TOP) / 2, R.bayBack + 0.3), caseTone)

	-- AND A RETURN DOWN ITS AISLE SIDE, BECAUSE A BACKBOARD ONLY HIDES WHAT
	-- IS BEHIND IT AND THE DISPLAY IS IN FRONT OF THIS ONE.
	--
	-- Reported as the window item looking out of place from inside the shop,
	-- and measured, that is exactly what it is. The backboard stands at
	-- z 1.40..2.00 and the display sits at z 2.66..5.80, so the board hides
	-- it only from somebody DEEPER IN than z 2.00. The entry door is at
	-- z 6.50 -- the same band as the bay -- so a player walking in is beside
	-- the display looking at its back, with nothing behind it but the room.
	-- Photographed from just inside the boutique door: the display piggy
	-- reads as a giant pig standing on the counter.
	--
	-- The board was doing its job and was never asked the right question.
	-- What it answers is "what does the STREET see behind the display", and
	-- the entry above it says so in as many words -- an opening needs
	-- something behind it. What nothing answered is "what does the ROOM see
	-- of it", and on a frontage where the door takes one end of the glazing
	-- that is a different sightline entirely.
	--
	-- One panel closes it: the bay becomes a box open only to the street.
	-- It starts at the backboard's FRONT face rather than its back, so the
	-- two BUTT instead of sharing a face plane over the strip where they
	-- overlap -- the coplanar fault this file has now recorded on the road,
	-- the moat, the dog's eyes and the shopfront's own frontage.
	local caseFront = R.bayBack + 0.6
	local sideFront = FRONT - 0.5           -- the glazing's own line
	local caseH = GLAZE_TOP - PLINTH_TOP + 0.6
	local caseY = (PLINTH_TOP + GLAZE_TOP) / 2
	local sideX = glassX + R.caseWidth / 2
	add(model, "CaseSide", Vector3.new(0.6, caseH, sideFront - caseFront),
		at(sideX, caseY, (caseFront + sideFront) / 2), caseTone)

	-- AND THE ROOM SIDE OF BOTH IS WALL, WHICH IS THE OTHER HALF OF CLOSING
	-- THE BAY OFF.
	--
	-- `caseTone` is the accent taken 62% to black, and it is right for what
	-- it was chosen for: a dark ground behind a lit display, seen from the
	-- street. It is the wrong thing to point at a room. Photographed from
	-- inside after the return went in, the case read as a nine-stud slab of
	-- near-black filling half the shop -- the display stopped being visible,
	-- which was the fix, and what replaced it was a void.
	--
	-- A part carries one colour, so the two faces are two parts: the case
	-- keeps its dark back for the window and a thin lining in the shop's own
	-- WALL colour faces the room. Butted rather than overlapped, so the pair
	-- share no face plane -- and note the lining is what a customer stands
	-- closest to, so it is the surface that decides whether this room reads
	-- as a shop or as a set of hoardings.
	local LINING_T = 0.25
	add(model, "CaseLining", Vector3.new(R.caseWidth, caseH, LINING_T),
		at(glassX, caseY, R.bayBack - LINING_T / 2), WALL)
	add(model, "CaseSideLining", Vector3.new(LINING_T, caseH, sideFront - caseFront),
		at(sideX + 0.3 + LINING_T / 2, caseY, (caseFront + sideFront) / 2), WALL)

	-- The plinth whatever is on show stands on, with its own cap, so it is
	-- presented rather than parked on the floor where the stall riser would
	-- hide it. Set BACK off the riser rather than butted against it: butted,
	-- the plinth and the riser share both their top and bottom planes over
	-- the strip where they meet, and the cap shares a face with the window
	-- frame in front of it.
	add(model, "Plinth", Vector3.new(R.bayWidth - 0.4, RISER_TOP - PLINTH_TOP + SINK, BAY_PLINTH_DEPTH),
		at(glassX, (PLINTH_TOP - SINK + RISER_TOP) / 2, bayZ), TIMBER)
	local BAY_CAP_Y, BAY_CAP_T = RISER_TOP + 0.12, 0.45
	local bayTop = BAY_CAP_Y + BAY_CAP_T / 2
	add(model, "PlinthCap", Vector3.new(R.bayWidth, BAY_CAP_T, BAY_CAP_DEPTH),
		at(glassX, BAY_CAP_Y, bayZ), trim)

	-- THE ONE CHECK `Config.auditShopRoom` CANNOT MAKE, MADE WHERE THE NUMBER
	-- LIVES. The bay is centred on the WINDOW, and where the window lands
	-- falls out of the pier spacing and the door width a few lines above --
	-- none of which `Config` holds. So the aisle rule is enforced here, at
	-- the arithmetic that could break it, rather than restated over there
	-- against a glassX somebody would have to keep in step.
	if glassX + R.bayWidth / 2 > R.aisleX or glassX + R.caseWidth / 2 > R.aisleX then
		warn(("ShopFront: '%s' display bay reaches x %.2f, inside the aisle at %.2f")
			:format(spec.tab,
				math.max(glassX + R.bayWidth / 2, glassX + R.caseWidth / 2), R.aisleX))
	end

	if glazed then
		shopWindow(model, at, glassX, glassW, RISER_TOP, GLAZE_TOP, trim)
	end

	-- The door, framed. A slab in a hole is a hatch; a frame round it with a
	-- head over the top is a door somebody walks through.
	-- Its head stops BELOW the pier cap rather than level with it: level, the
	-- two share a top plane over the patch where the frame runs into the pier
	-- beside it.
	local frameTop, frameBase = 10.28, 1.2
	add(model, "DoorFrame", Vector3.new(doorW + 1.3, frameTop - frameBase, 0.62),
		at(doorX, (frameBase + frameTop) / 2, FRONT - 0.5), JOINERY)
	-- THE DOOR STANDS OPEN, AND THAT IS A FIX RATHER THAN A FLOURISH.
	--
	-- Nothing in this building collides, so a shut door was always something
	-- a player walked THROUGH -- which was invisible for as long as the only
	-- reason to approach one was a prompt on its face, and stopped being
	-- invisible the moment the target moved inside. A shop you are meant to
	-- walk into with a closed door on it is an instruction nobody would
	-- follow, and the fix is a rotation rather than a sign telling them to.
	--
	-- Hinged on the side AWAY from the display window and swung OUT onto the
	-- forecourt, which is where a real shop door goes and which leaves the
	-- room it opens into clear. Every piece of the leaf hangs off one hinge
	-- frame: written as separate absolute placements they would have to be
	-- kept in step by hand, and the handle drifting off the door is exactly
	-- the class of thing nobody reports.
	local hinge = at(doorX + doorW / 2, 0, FRONT - 0.28) * CFrame.Angles(0, math.rad(65), 0)
	local function onLeaf(dx: number, y: number, dz: number): CFrame
		return hinge * CFrame.new(-doorW / 2 + dx, y, dz)
	end

	local door = add(model, "Door", Vector3.new(doorW, GLAZE_TOP - PLINTH_TOP + SINK, 0.42),
		onLeaf(0, (PLINTH_TOP - SINK + GLAZE_TOP) / 2, 0), spec.accent:Lerp(FRAME, 0.55))
	local dGlass = add(model, "DoorGlass", Vector3.new(doorW - 1.4, 3.6, 0.26),
		onLeaf(0, GLAZE_TOP - 2.4, 0.22), GLASS)
	dGlass.Transparency = 0.55
	add(model, "DoorPanel", Vector3.new(doorW - 1.6, 2.0, 0.22),
		onLeaf(0, PLINTH_TOP + 1.7, 0.25), spec.accent:Lerp(FRAME, 0.3))
	cylinderUp(model, "Handle", 1.0, 0.24, onLeaf(-1.6, GLAZE_TOP - 4.6, 0.44), GOLD)

	-- AN OPEN SIGN, hung in the door glass. The one piece of neon every unit
	-- carries whatever its style, so the row reads as a parade of open shops
	-- at a glance rather than four buildings that may or may not be in use.
	local open = add(model, "OpenSign", Vector3.new(2.6, 0.95, 0.2),
		onLeaf(0, GLAZE_TOP - 1.2, 0.42), Color3.fromRGB(255, 96, 96), Enum.Material.Neon)
	sign(open, Enum.NormalId.Back, "OPEN", Color3.fromRGB(255, 246, 246))
	animate(open, "pulse", { Rate = 0.3, Hue = 0.99, Sat = 0.62, Dim = 0.5 })

	-- The transom beam over the whole frontage, and the fascia above it.
	-- The transom is joinery too -- it is the beam the glazing and the door
	-- both hang from -- so it takes the dark family and gives the fascia
	-- above it something to sit on.
	add(model, "Transom", Vector3.new(WIDTH + 0.5, TRANSOM_TOP - GLAZE_TOP, 1.0),
		at(0, (GLAZE_TOP + TRANSOM_TOP) / 2, FRONT - 0.05), JOINERY)

	-- A FASCIA WITH A MOULDING TOP AND BOTTOM. A flat coloured band with a
	-- word on it is a label; a band held between two projecting courses is a
	-- fascia, and the two courses are four studs of geometry.
	-- The fascia keeps its band and loses its lettering: the name moved to
	-- the banner over the roof, where it can be read from more than one
	-- direction. What is left is a clean course of the shop's own colour
	-- between two mouldings, which is what a fascia is when the sign is
	-- somewhere else.
	add(model, "Fascia", Vector3.new(WIDTH + 0.6, HEIGHT - TRANSOM_TOP - 0.5, 0.55),
		at(0, (TRANSOM_TOP + HEIGHT) / 2 - 0.25, FRONT + 0.4), spec.accent)
	-- PROJECTING CLEAR OF THE SIDE WALLS, not resting on them. Sat back at
	-- FRONT + 0.3 it overlapped each side wall by a tenth of a stud in plan
	-- AND shared its top plane with them, which is a pair on both corners of
	-- every unit. A cornice is meant to project anyway.
	add(model, "Cornice", Vector3.new(WIDTH + 1.6, 0.7, 1.3), at(0, HEIGHT - 0.35, FRONT + 0.6), trim)
	add(model, "FasciaRail", Vector3.new(WIDTH + 1.2, 0.5, 0.9), at(0, TRANSOM_TOP + 0.05, FRONT + 0.35), trim)

	-- ---------- the bracket sign ----------
	--
	-- Square to the frontage, so it reads from UP and DOWN the street, which
	-- the fascia cannot: a player arrives along the road, and a flat fascia is
	-- edge-on from everywhere except stopped in front of it.
	--
	-- Thin on X, with its guis on Left and Right, because the street runs
	-- along X and those are the faces that point along it.
	-- OUTBOARD ENOUGH TO CLEAR THE BAY BEHIND IT. At 2.6 in from the side the
	-- bracket hung over the workshop's roller-shutter housing and the two
	-- shared a face plane -- and the housing cannot simply be narrowed,
	-- because it is sized off the glazing it shuts and the glazing sits to
	-- one side of the frontage. The sign is the piece with somewhere else to
	-- go: at 1.8 it mounts on the pier, which is where a real bracket sign is
	-- bolted anyway.
	local armX = -WIDTH / 2 + 1.8
	cylinderAlongX(model, "SignArm", 4.8, 0.34,
		at(armX, TRANSOM_TOP + 0.9, FRONT + 2.7) * CFrame.Angles(0, math.rad(90), 0), FRAME)
	add(model, "SignBracket", Vector3.new(0.42, 1.9, 1.9),
		at(armX, TRANSOM_TOP - 0.15, FRONT + 1.0) * CFrame.Angles(math.rad(45), 0, 0), FRAME)
	local hang = add(model, "HangingSign", Vector3.new(0.36, 2.9, 6.2),
		at(armX, TRANSOM_TOP - 1.9, FRONT + 3.5), spec.accent)
	-- INK ON THE ACCENT, not cream. Cream on a mid-tone board is thin in full
	-- sun, and this sign is no longer the primary -- the banner over the roof
	-- is. What this one has to do is read at arm's length, and dark type on a
	-- coloured board does that far better than pale type does.
	sign(hang, Enum.NormalId.Left, spec.name, Theme.INK)
	sign(hang, Enum.NormalId.Right, spec.name, Theme.INK)
	-- A border round the board, which is what the ink outline does for
	-- everything else in this style and is the only thing stopping a hanging
	-- sign reading as a floating rectangle of colour.
	for _, sy in ipairs({ -1, 1 }) do
		add(model, "SignEdge", Vector3.new(0.46, 0.4, 6.4),
			at(armX, TRANSOM_TOP - 1.9 + sy * 1.35, FRONT + 3.5), CREAM)
	end
	for _, sz in ipairs({ -1, 1 }) do
		-- WIDER than the rails, not a hundredth narrower. At 0.44 against
		-- 0.46 the two shared their side planes to within 0.01, which is four
		-- pairs on a board hung at head height over the pavement.
		add(model, "SignEdge", Vector3.new(0.56, 3.3, 0.4),
			at(armX, TRANSOM_TOP - 1.9, FRONT + 3.5 + sz * 3.1), CREAM)
		cylinderUp(model, "SignLink", 1.5, 0.18,
			at(armX, TRANSOM_TOP + 0.15, FRONT + 3.5 + sz * 2.4), FRAME)
	end

	banner(model, at, spec)

	-- ---------- whatever makes this one a different building ----------
	local style = STYLES[spec.style]
	if style then
		style(model, at, spec, cf, {
			glassX = glassX, glassW = glassW,
			doorX = doorX, doorW = doorW, clear = clear,
			bayZ = bayZ, bayTop = bayTop,
			wall = WALL, trim = trim, base = base,
		})
	end

	-- ---------- the window display ----------
	--
	-- pcall'd, deliberately. A display is the one thing here built by somebody
	-- else's builder, and a shop losing its window dressing is a cosmetic
	-- fault while taking the street down with it is not -- the same call
	-- `Decor.prewarm` already makes, for the same reason.
	--
	-- A BUILDER'S ANCHORING IS A FACT ABOUT WHERE IT WAS DESIGNED TO GO, AND
	-- A DISPLAY CASE IS A THIRD PLACE THAT IS NEITHER.
	--
	-- `BoneModel` builds ANCHORED, because a bone lies in the grass.
	-- `RideModel` and `PiggyModel` build UNANCHORED and Massless, because
	-- both get welded to a character -- and an anchored part welded to a
	-- humanoid pins the humanoid, which is the reason they are that way
	-- round. Stood in a window with nothing to weld to, they simply FELL:
	-- three of the four displays vanished on the first build and only the
	-- bone survived, which is exactly the set that was already anchored.
	--
	-- The inverse of this is written up in `HeldItem`, which has to take the
	-- anchor OFF the same builders to weld them into a hand. Neither module
	-- can assume; both have to state what they need.
	--
	-- THE CASE ITSELF IS BUILT WITH THE SHELL NOW, not here. It has to be:
	-- the garden centre has no `display` and still needs the bay, and while
	-- this block owned it that unit grew a full-width partition instead. All
	-- that is left here is standing the model on it.
	if glazed and spec.display then
		local ok, display = pcall(spec.display)
		if ok and display then
			for _, d in ipairs(display:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanQuery = false
				end
			end
			local _, size = display:GetBoundingBox()
			local longest = math.max(size.X, size.Y, size.Z)
			-- 3.1 AND NOT 4.4. At 4.4 the model filled 84% of a 5.25-wide
			-- window and pressed against the glass, so there was no window
			-- left to look through.
			if longest > 0 then
				scaleModel(display, DISPLAY_SPAN / longest)
			end
			display.Name = "Display"
			-- Turned a little off square, so it reads as arranged rather than
			-- parked -- and that turn is what sets the bay's depth, since a
			-- near-cubic model at this span presents its DIAGONAL in z. It is
			-- `DISPLAY_YAW` up beside the span for that reason: the two are
			-- one decision and the bay is solved against both.
			display:PivotTo(at(glassX, RISER_TOP + 2.1, bayZ)
				* CFrame.Angles(0, math.rad(DISPLAY_YAW), 0))
			display.Parent = model
		elseif not ok then
			warn(("ShopFront: display for '%s' failed: %s"):format(spec.tab, tostring(display)))
		end
	end

	-- ---------- the way in ----------
	--
	-- A SHOP IS ENTERED THROUGH ITS DOOR NOW, AND UNTIL THIS IT WAS ENTERED
	-- THROUGH ANY WALL YOU LIKED. Every visible piece of this building is
	-- `CanCollide` false -- correctly, and that has not changed -- so the
	-- only solid thing in a shop was the floor slab, and a player could walk
	-- in through the back wall from the grass behind it. `Config.shopRoomHolds`
	-- exists partly because of that: it had to REFUSE a crack from a spot the
	-- geometry was happy to let somebody stand in, and the entry over it
	-- records the measurement -- a vault on a 0.8-stud back wall is TWO STUDS
	-- from the grass outside.
	--
	-- WHY THIS WAS REFUSED BEFORE, AND WHY THAT ARGUMENT DOES NOT HOLD.
	-- `Config.SHOP_UNIT` said in as many words that the interior must never
	-- become solid, because `PoliceService` and `GuardDog` walk in a straight
	-- line at their target with no pathfinding -- so a solid building would
	-- be somewhere nothing in the game can reach you. It names pathfinding
	-- and NEITHER OF THOSE TWO USES ANY: an officer, a guard dog and a
	-- shopkeeper are all ANCHORED parts driven by `Model:PivotTo` and by
	-- per-frame CFrame writes, with no physics body among them, so a
	-- collision hull is not something they walk into -- it is something they
	-- walk through. A thief who runs into a shop is caught exactly as before.
	--
	-- IT IS A BARRIER RING AND NOT THE WALLS THEMSELVES, which is the split
	-- `buildFence` already draws between a Barrier and a decorator: one
	-- invisible slab carries all the collision and everything visible stays
	-- off it, so the piers, the riser, the glazing and the four styles keep
	-- every clearance and every coplanar decision they were measured into.
	--
	-- THE GAP IS THE DOORWAY, DERIVED FROM THE DOOR. Written as its own pair
	-- of numbers it would be one edit away from a shop nobody can get into --
	-- which is a bug with no error, no warning and no way to tell it from the
	-- building simply being solid.
	do
		local T = 1.0
		local y0, y1 = -1.0, HEIGHT
		local h, cy = y1 - y0, (y0 + y1) / 2
		-- The inner faces, taken off the pieces a player can actually see:
		-- the side walls, the back wall and the stall riser.
		local inX = WIDTH / 2 - 0.5
		local inZ = -DEPTH / 2 + 0.5
		local frontZ = FRONT - 0.95
		local function barrier(size: Vector3, cframe: CFrame)
			local p = Instance.new("Part")
			p.Name = "Barrier"
			p.Size = size
			p.CFrame = cframe
			p.Anchored = true
			p.CanCollide = true
			-- `CanQuery` FALSE, WHICH IS NOT AN OVERSIGHT. A thrown gadget
			-- stops on the world by RAYCAST and a prompt's line of sight is a
			-- raycast too, so answering queries here would silently change
			-- what a shopfront does to both -- and neither of them was ever
			-- stopped by this building. What is new is the COLLISION, which
			-- is the only thing this ring is for.
			p.CanQuery = false
			p.CastShadow = false
			p.Transparency = 1
			p.Parent = model
		end

		barrier(Vector3.new(WIDTH + T, h, T), at(0, cy, inZ - T / 2))
		for _, sx in ipairs({ -1, 1 }) do
			barrier(Vector3.new(T, h, DEPTH + T), at(sx * (inX + T / 2), cy, 0))
		end
		-- The frontage, in two pieces with the doorway between them.
		local gapL, gapR = doorX - doorW / 2, doorX + doorW / 2
		local edge = inX + T / 2
		barrier(Vector3.new(gapL + edge, h, T),
			at((gapL - edge) / 2, cy, frontZ + T / 2))
		barrier(Vector3.new(edge - gapR, h, T),
			at((gapR + edge) / 2, cy, frontZ + T / 2))
	end

	-- THE PROMPT, ON THE DOOR. It only ever opens a panel, and the server
	-- answers it -- see the note in NeighborhoodService about why a client
	-- cannot find these for itself. Short hold, because nothing is at stake:
	-- this is a shortcut past picking a tab, not a purchase.
	--
	-- ITS REACH CAME DOWN FROM 12 TO 8, AND THAT IS A COLLISION RATHER THAN A
	-- TIDY-UP. Both prompts are on E and both are `OnePerButton`, so only one
	-- of them is live at a time -- and at 12 this one reached 9.9 studs into
	-- the room, which is exactly where a thief stands to crack the vault on
	-- the back wall. Measured: three of the four units let the steal prompt
	-- through and the fourth answered with SHOP instead, silently, with the
	-- engine raising no event for the prompt that was actually being held.
	--
	-- It is a door, so being at the door is the honest requirement: at 8 it
	-- still covers the whole forecourt out to the kerb and stops 0.6 studs
	-- inside the room. Same fix the collect prompt already took, which was
	-- reaching ten studs past its own piggy.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "SHOP"
	prompt.ObjectText = spec.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	Config.setPromptKind(prompt, "shop")
	prompt.Parent = door

	door:SetAttribute(ShopFront.TAB_ATTRIBUTE, spec.tab)
	CollectionService:AddTag(door, ShopFront.TAG)

	-- No PrimaryPart and an explicit pivot at the placement, so a later
	-- PivotTo moves the unit rigidly instead of replacing a rotation one of
	-- these parts happens to carry. The saucer learned that one the hard way.
	model.WorldPivot = CFrame.new(cf.Position)
	model.Parent = parent
	return model, door
end

return ShopFront
