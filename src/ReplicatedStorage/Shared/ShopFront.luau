--!strict
--[[
	ShopFront

	The four shops on the street. One shell, four buildings.

	----------------------------------------------------------------------

	THEY WERE FOUR IDENTICAL BOXES AND THAT IS WHY THEY READ AS BORING.

	The first version was a shared shell with a different accent colour and a
	different word on the fascia, which is a colour swatch rather than a shop.
	Nothing about a box says what is inside it, four of them in a row say it
	four times, and a player walking past learns nothing they could not have
	read off the shop panel.

	So the shell stayed and everything else became per-STYLE: the roof line,
	the frontage, the lighting, what stands in the window and what stands on
	the pavement outside. A boutique with a pitched gable and a scalloped
	blind, a glasshouse with an open front, a workshop with a roller bay and a
	quarter pipe, and a strongroom with a castellated parapet and barred
	glass. From the road they are four different silhouettes before a single
	word is read.

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

	It does not turn. HouseFX spins PARTS and not models, so a turntable would
	either slide a disc out from under whatever was standing on it or need a
	second animator to drag a welded assembly -- and the motion that actually
	earns its place here is the neon, which costs one attribute per part.

	----------------------------------------------------------------------

	THE LIGHTING IS NEON DRIVEN BY HOUSEFX, WITH NO NEW ANIMATION CODE.

	Same argument the house tiers already settled: this game has no night, a
	PointLight in full sun is invisible from the street, and Neon is the one
	material that ignores the scene and blooms for free. Tagging a part and
	stamping an `FX` attribute on it is the whole cost -- the client animator
	that already runs for the houses picks it up, and its own `MAX_RATE`
	ceiling means nothing here can be authored into a strobe however it is
	tuned.

	----------------------------------------------------------------------

	AUTHORED FACING +Z, like everything else in this world, and the caller
	yaws it. Nothing collides and nothing answers a raycast: only the hills do
	that, because a chase has to be able to run through the scenery.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

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
local WIDTH = 18
local FORECOURT_OVERHANG = 2
local DEPTH = 14
local HEIGHT = 13

local WALL = Color3.fromRGB(226, 220, 208)
local WALL_DARK = Color3.fromRGB(150, 144, 134)
local FRAME = Color3.fromRGB(58, 54, 62)
local GLASS = Color3.fromRGB(176, 214, 226)
local STONE = Color3.fromRGB(198, 196, 188)
local CREAM = Color3.fromRGB(248, 246, 240)
local GOLD = Color3.fromRGB(212, 168, 60)

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
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	-- NON-COLLIDING, like every other thing NeighborhoodService puts on this
	-- street. Only the hills collide, because they are the edge of the world;
	-- a shop that could body-block a thief would be the first piece of cover
	-- on the map nobody paid for.
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A ROBLOX CYLINDER'S AXIS IS ITS X AXIS: Size.X is the LENGTH along it and
-- the other two are the cross-section. Written the other way round it becomes
-- a disc as wide as the height was tall, which this project has shipped five
-- times. These two wrappers are why it will not be a sixth.
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

-- ============================================================
-- STYLES
-- ============================================================
--
-- Each adds whatever makes this unit a different BUILDING from the one next
-- to it. The shell underneath is identical, which is what keeps four
-- buildings to one set of measurements.

type At = (x: number, y: number, z: number) -> CFrame
type Style = (model: Model, at: At, spec: Spec, frontZ: number) -> ()

local STYLES: { [string]: Style } = {}

-- A BOUTIQUE. Pitched gable, scalloped blind, rainbow neon: it sells the
-- skins and the effects, so it is the loudest of the four on purpose.
STYLES.boutique = function(model, at, spec, frontZ)
	-- A gable built as two leaning slabs. Two tilted boxes meeting at a ridge
	-- read as a roof from the street, which is the only place anybody stands.
	for _, sz in ipairs({ -1, 1 }) do
		add(model, "Gable", Vector3.new(WIDTH + 1.4, 0.6, 9.4),
			at(0, HEIGHT + 2.4, sz * 3.2) * CFrame.Angles(math.rad(sz * 26), 0, 0),
			spec.accent, Enum.Material.Slate)
	end
	add(model, "Tympanum", Vector3.new(WIDTH * 0.55, 2, 0.5),
		at(0, HEIGHT + 1.3, frontZ - 0.2), CREAM)

	-- A SCALLOPED BLIND: half-cylinders in a row, which is the shape a real
	-- shop awning makes and the one thing a flat slab cannot fake.
	local n = 6
	local w = WIDTH / n
	for i = 0, n - 1 do
		cylinderAlongX(model, "Scallop", w, 3.4,
			at(-WIDTH / 2 + w * (i + 0.5), 9.2, frontZ + 1.5),
			if i % 2 == 0 then spec.accent else CREAM)
	end

	-- A neon band under the blind, running the whole spectrum. It sells
	-- colour, so it advertises in colour.
	animate(add(model, "NeonStrip", Vector3.new(WIDTH - 1.4, 0.42, 0.42),
		at(0, 7.4, frontZ + 0.45), spec.accent, Enum.Material.Neon),
		"cycle", { Rate = 0.16, Sat = 0.78 })

	for _, sx in ipairs({ -1, 1 }) do
		add(model, "Planter", Vector3.new(2.6, 1.8, 2.6),
			at(sx * (WIDTH / 2 - 1.6), 1.3, frontZ + 4.4), STONE, Enum.Material.Concrete)
		ball(model, "Bloom", 2.2,
			at(sx * (WIDTH / 2 - 1.6), 2.7, frontZ + 4.4), Color3.fromRGB(226, 118, 156))
	end
end

-- A GLASSHOUSE. Open front under a lintel, glazed pitch, planting spilling
-- onto the pavement. The one unit with no display window, because a garden
-- centre does not have one -- its stock IS the frontage.
STYLES.garden = function(model, at, spec, frontZ)
	for _, sz in ipairs({ -1, 1 }) do
		local pane = add(model, "RoofGlass", Vector3.new(WIDTH + 1.2, 0.4, 9.4),
			at(0, HEIGHT + 2.2, sz * 3.2) * CFrame.Angles(math.rad(sz * 24), 0, 0),
			GLASS, Enum.Material.Glass)
		pane.Transparency = 0.5
		pane.Reflectance = 0.15
	end
	-- Glazing bars, so the roof reads as a greenhouse and not a skylight.
	for i = -2, 2 do
		add(model, "GlazingBar", Vector3.new(0.3, 0.5, 19),
			at(i * 3.4, HEIGHT + 2.6, 0), WALL_DARK, Enum.Material.Metal)
	end

	-- The open front: posts where the glass would be, and a lintel over them.
	for _, sx in ipairs({ -1, 1 }) do
		add(model, "Post", Vector3.new(0.9, 8.6, 0.9),
			at(sx * (WIDTH / 2 - 1.4), 4.3, frontZ), WALL_DARK, Enum.Material.Wood)
	end

	animate(add(model, "NeonStrip", Vector3.new(WIDTH - 1.4, 0.42, 0.42),
		at(0, 8.5, frontZ + 0.45), spec.accent, Enum.Material.Neon),
		"pulse", { Rate = 0.22, Hue = 0.32, Sat = 0.7, Dim = 0.45 })

	-- Trestles of plants across the front, which is what a garden centre
	-- actually looks like from a road.
	for i = -1, 1 do
		local x = i * 5.4
		add(model, "Trestle", Vector3.new(4.6, 0.4, 2.2),
			at(x, 2.2, frontZ + 4.2), Color3.fromRGB(122, 90, 62), Enum.Material.Wood)
		for j = -1, 1 do
			add(model, "Pot", Vector3.new(1.1, 1.1, 1.1),
				at(x + j * 1.5, 2.9, frontZ + 4.2), Color3.fromRGB(178, 96, 66))
			ball(model, "Shrub", 1.5, at(x + j * 1.5, 3.9, frontZ + 4.2),
				Color3.fromRGB(74, 142, 78), Enum.Material.Grass)
		end
	end
end

-- A WORKSHOP. Flat roof, tall parapet with a run of chasing bulbs, a roller
-- bay instead of a display window, and a quarter pipe on the forecourt.
STYLES.wheels = function(model, at, spec, frontZ)
	add(model, "Parapet", Vector3.new(WIDTH + 1.6, 4, DEPTH + 1.6),
		at(0, HEIGHT + 2, 0), WALL_DARK, Enum.Material.Concrete)
	add(model, "ParapetBand", Vector3.new(WIDTH + 1.8, 0.8, DEPTH + 1.8),
		at(0, HEIGHT + 3.7, 0), spec.accent)

	-- A CHASE, NOT A BLINK. Each bulb carries its own Phase, so one bright
	-- band travels the run -- which is what a bulb sign does, and is nowhere
	-- near the flash ceiling a switch would be flirting with.
	local n = 9
	for i = 0, n - 1 do
		local bulb = ball(model, "Bulb", 0.85,
			at(-WIDTH / 2 + (WIDTH / (n - 1)) * i, HEIGHT + 2.1, frontZ + 0.6),
			spec.accent, Enum.Material.Neon)
		animate(bulb, "chase",
			{ Rate = 0.5, Phase = i / n, Hue = 0.09, Sat = 0.85, Span = 0.28, Dim = 0.22 })
	end

	-- A roller shutter above the bay, half open.
	add(model, "Shutter", Vector3.new(WIDTH - 4, 2.4, 0.4),
		at(0, 9.2, frontZ + 0.25), Color3.fromRGB(126, 130, 140), Enum.Material.DiamondPlate)
	for i = 0, 3 do
		add(model, "ShutterRib", Vector3.new(WIDTH - 4, 0.18, 0.5),
			at(0, 8.3 + i * 0.6, frontZ + 0.32), Color3.fromRGB(96, 100, 110), Enum.Material.Metal)
	end

	-- A QUARTER PIPE, stacked from boxes on a circular arc.
	--
	-- Roblox has no curved ramp primitive, and a CSG union would be a MESH
	-- whose fidelity is a plugin-only property -- reaching for that took the
	-- whole server down once already, so it is not being reached for here.
	-- Eight steps read as a curve at street distance.
	local steps, radius = 8, 5.5
	for i = 0, steps - 1 do
		local a0 = (i / steps) * (math.pi / 2)
		local a1 = ((i + 1) / steps) * (math.pi / 2)
		local mid = (a0 + a1) / 2
		add(model, "Ramp", Vector3.new(6.4, 0.6, radius * (a1 - a0) + 0.6),
			at(WIDTH / 2 - 1.4,
				radius * (1 - math.cos(mid)) + 0.6,
				frontZ + 5.2 + radius * math.sin(mid))
				* CFrame.Angles(mid, 0, 0),
			Color3.fromRGB(150, 120, 88), Enum.Material.WoodPlanks)
	end

	cylinderUp(model, "Bollard", 3.2, 0.8,
		at(-WIDTH / 2 + 1.2, 1.6, frontZ + 4.8), GOLD, Enum.Material.Metal)
end

-- A STRONGROOM. Castellated parapet, barred glass, one slow blue lamp and a
-- vault dial on the pier. It sells both trees, so it reads as a place that
-- keeps things AND opens them.
STYLES.security = function(model, at, spec, frontZ)
	add(model, "Parapet", Vector3.new(WIDTH + 1.6, 2.2, DEPTH + 1.6),
		at(0, HEIGHT + 1.1, 0), STONE, Enum.Material.Concrete)
	local n = 7
	for i = 0, n - 1 do
		add(model, "Merlon", Vector3.new(WIDTH / (n * 2), 1.8, 1.6),
			at(-WIDTH / 2 + (WIDTH / (n - 1)) * i, HEIGHT + 3.1, frontZ - 0.6),
			STONE, Enum.Material.Concrete)
	end

	-- Bars across the glazing. Cylinders standing up, via the wrapper: the
	-- length is Size.X and the turn is what stands it on end.
	for i = -3, 3 do
		cylinderUp(model, "Bar", 6.4, 0.28,
			at(i * 1.5 - 2.2, 6.2, frontZ + 0.35),
			Color3.fromRGB(96, 100, 112), Enum.Material.Metal)
	end

	-- A security lamp: a lighthouse swell rather than a strobe, which is both
	-- what a rotating lamp actually looks like and what keeps it well under
	-- the flash guidance this project holds itself to.
	animate(ball(model, "Lamp", 1.6,
		at(0, HEIGHT + 3.4, frontZ - 0.4), spec.accent, Enum.Material.Neon),
		"beacon", { Rate = 0.42, Hue = 0.58, Sat = 0.75, Dim = 0.2 })

	-- A vault dial on the pier beside the door: the same motif the piggy's
	-- own lock uses, read at shop scale.
	local plateX = -WIDTH / 2 + 2.8
	local faceZ = frontZ + 0.3
	cylinderAlongX(model, "DialPlate", 0.5, 4.2,
		at(plateX, 5.6, faceZ) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(150, 154, 166), Enum.Material.Metal)
	cylinderAlongX(model, "DialHub", 0.7, 1.5,
		at(plateX, 5.6, faceZ + 0.3) * CFrame.Angles(0, math.rad(90), 0),
		GOLD, Enum.Material.Metal)
	for i = 0, 3 do
		add(model, "DialSpoke", Vector3.new(0.45, 3.6, 0.3),
			at(plateX, 5.6, faceZ + 0.2) * CFrame.Angles(0, 0, (i / 4) * math.pi * 2),
			GOLD, Enum.Material.Metal)
	end

	cylinderUp(model, "Bollard", 3, 0.9,
		at(WIDTH / 2 - 1.2, 1.5, frontZ + 4.8), STONE, Enum.Material.Concrete)
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

	local frontZ = DEPTH / 2
	local glazed = spec.style ~= "garden"

	-- A paved forecourt, so the unit meets the grass at a made edge rather
	-- than a wall growing out of a lawn. Proud of the ground, never level:
	-- two faces at one depth is the coplanar flicker this project has caught
	-- at the road, the moat and the guard dog's own eyes.
	add(model, "Forecourt", Vector3.new(WIDTH + FORECOURT_OVERHANG, 0.4, DEPTH + 7),
		at(0, 0.2, 3.4), STONE, Enum.Material.Concrete)

	add(model, "Back", Vector3.new(WIDTH, HEIGHT, 0.6),
		at(0, HEIGHT / 2, -DEPTH / 2), WALL_DARK, Enum.Material.Brick)
	for _, sx in ipairs({ -1, 1 }) do
		add(model, "Side", Vector3.new(0.6, HEIGHT, DEPTH),
			at(sx * (WIDTH / 2), HEIGHT / 2, 0), WALL, Enum.Material.Brick)
	end
	add(model, "Roof", Vector3.new(WIDTH + 1.4, 0.7, DEPTH + 1.4),
		at(0, HEIGHT + 0.35, 0), WALL_DARK, Enum.Material.Concrete)

	-- The frontage. A stall riser under the glass, glazing above it, a door to
	-- one side: the arrangement that says "shop" rather than "building with a
	-- hole in it". The glasshouse skips the glazing and takes an open front
	-- from its own style instead.
	add(model, "StallRiser", Vector3.new(WIDTH, 3, 0.6),
		at(0, 1.5, frontZ), FRAME, Enum.Material.WoodPlanks)

	local glassW = WIDTH * 0.58
	local glassX = -(WIDTH - glassW) / 2 + 0.3
	if glazed then
		local pane = add(model, "Glass", Vector3.new(glassW, 6.4, 0.25),
			at(glassX, 6.2, frontZ), GLASS, Enum.Material.Glass)
		pane.Transparency = 0.55
		pane.Reflectance = 0.2
		add(model, "Mullion", Vector3.new(0.35, 6.4, 0.4), at(glassX, 6.2, frontZ), FRAME)
	end

	local doorX = WIDTH / 2 - 3.2
	local door = add(model, "Door", Vector3.new(4.2, 8.4, 0.4),
		at(doorX, 4.2, frontZ), FRAME, Enum.Material.WoodPlanks)
	add(model, "DoorGlass", Vector3.new(3, 4.2, 0.2),
		at(doorX, 5.6, frontZ + 0.12), GLASS, Enum.Material.Glass).Transparency = 0.5
	cylinderUp(model, "Handle", 0.9, 0.22,
		at(doorX - 1.7, 4.4, frontZ + 0.3), GOLD, Enum.Material.Metal)

	-- AN OPEN SIGN, hung in the door glass. The one piece of neon every unit
	-- carries whatever its style, so the row reads as a parade of open shops
	-- at a glance rather than four buildings that may or may not be in use.
	local open = add(model, "OpenSign", Vector3.new(2.4, 0.9, 0.18),
		at(doorX, 7.1, frontZ + 0.3), Color3.fromRGB(255, 96, 96), Enum.Material.Neon)
	sign(open, Enum.NormalId.Back, "OPEN", Color3.fromRGB(255, 246, 246))
	animate(open, "pulse", { Rate = 0.3, Hue = 0.99, Sat = 0.62, Dim = 0.5 })

	add(model, "Header", Vector3.new(WIDTH, 1, 0.7), at(0, 9.9, frontZ), WALL)

	local fascia = add(model, "Fascia", Vector3.new(WIDTH, 2.6, 0.5),
		at(0, 11.4, frontZ + 0.1), spec.accent)
	sign(fascia, Enum.NormalId.Back, spec.name, CREAM)

	-- ---------- the bracket sign ----------
	--
	-- Square to the frontage, so it reads from UP and DOWN the street, which
	-- the fascia cannot: a player arrives along the road, and a flat fascia is
	-- edge-on from everywhere except stopped in front of it.
	--
	-- Thin on X, with its guis on Left and Right, because the street runs
	-- along X and those are the faces that point along it.
	local armX = -WIDTH / 2 + 2.4
	cylinderAlongX(model, "SignArm", 4.6, 0.32,
		at(armX, 10.6, frontZ + 2.6) * CFrame.Angles(0, math.rad(90), 0),
		FRAME, Enum.Material.Metal)
	local hang = add(model, "HangingSign", Vector3.new(0.34, 2.8, 6),
		at(armX, 8.8, frontZ + 3.4), spec.accent)
	sign(hang, Enum.NormalId.Left, spec.name, CREAM)
	sign(hang, Enum.NormalId.Right, spec.name, CREAM)
	for _, sz in ipairs({ -1, 1 }) do
		cylinderUp(model, "SignLink", 1.4, 0.16,
			at(armX, 10, frontZ + 3.4 + sz * 2.4), FRAME, Enum.Material.Metal)
	end

	-- ---------- whatever makes this one a different building ----------
	local style = STYLES[spec.style]
	if style then
		style(model, at, spec, frontZ)
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
			if longest > 0 then
				scaleModel(display, 4.4 / longest)
			end
			display.Name = "Display"
			add(model, "Plinth", Vector3.new(6.4, 3, 4),
				at(glassX, 1.5, frontZ - 2.4), FRAME, Enum.Material.WoodPlanks)
			-- Turned a little off square, so it reads as arranged rather than
			-- parked, and lifted onto the plinth rather than standing on the
			-- floor where the stall riser would hide it.
			display:PivotTo(at(glassX, 5.2, frontZ - 2.4) * CFrame.Angles(0, math.rad(24), 0))
			display.Parent = model
		elseif not ok then
			warn(("ShopFront: display for '%s' failed: %s"):format(spec.tab, tostring(display)))
		end
	end

	-- THE PROMPT, ON THE DOOR. It only ever opens a panel, and the server
	-- answers it -- see the note in NeighborhoodService about why a client
	-- cannot find these for itself. Short hold, because nothing is at stake:
	-- this is a shortcut past picking a tab, not a purchase.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = "SHOP"
	prompt.ObjectText = spec.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute(Config.PROMPT_KIND_ATTRIBUTE, "shop")
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
