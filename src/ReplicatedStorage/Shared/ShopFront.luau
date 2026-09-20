--!strict
-- Four walk-in shops. Geometry faces +Z; Config owns the footprint, vault
-- approach, shopkeeper pocket and counter bounds. ShopInterior dresses those
-- bands without adding collisions. Real openings preserve sightlines from
-- the street, and physical signs keep the roofs readable without floating UI.


local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LowPoly = require(ReplicatedStorage.Shared.LowPoly)
local Theme = require(ReplicatedStorage.Shared.Theme)
local ShopInterior = require(ReplicatedStorage.Shared.ShopInterior)

local ShopFront = {}

ShopFront.TAG = "ShopDoor"
ShopFront.TAB_ATTRIBUTE = "ShopTab"

local FX_TAG = "HouseFX"

local WIDTH = Config.SHOP_UNIT.width
local DEPTH = Config.SHOP_UNIT.depth
local HEIGHT = Config.SHOP_UNIT.height
local FORECOURT_OVERHANG = 2

local PAVE_TOP = 0.4 -- top of the forecourt slab
local PLINTH_TOP = 1.6 -- top of the base course the walls stand on
local RISER_TOP = 4.2 -- top of the solid under the glazing
local GLAZE_TOP = 9.8 -- window head, and the door head with it
local TRANSOM_TOP = 10.6 -- the beam over both

local FRONT = DEPTH / 2

local SINK = 0.1

local DISPLAY_SPAN = 3.1
local DISPLAY_YAW = 24

local STONE = LowPoly.STONE
local TIMBER = LowPoly.TIMBER
local FRAME = Color3.fromRGB(64, 56, 66)
local GLASS = Color3.fromRGB(176, 210, 224)
local CREAM = Color3.fromRGB(236, 230, 217)
local GOLD = Color3.fromRGB(212, 168, 60)
local LEAD = Color3.fromRGB(118, 122, 132)

local JOINERY = Color3.fromRGB(72, 60, 66)

export type Spec = {
	name: string,
	tab: string,
	accent: Color3,
	style: string,
	display: (() -> Model?)?,
}


local function add(parent: Instance, name: string, size: Vector3, cf: CFrame,
	colour: Color3, material: Enum.Material?): Part
	return LowPoly.part(parent, name, size, cf, colour, material or Enum.Material.SmoothPlastic)
end

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

local function animate(part: Part, fx: string, opts: { [string]: number }?)
	part:SetAttribute("FX", fx)
	for key, value in pairs(opts or {}) do
		part:SetAttribute(key, value)
	end
	CollectionService:AddTag(part, FX_TAG)
end

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

local function sign(parent: BasePart, face: Enum.NormalId, text: string,
	colour: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign_" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.92, 0.84)
	label.Position = UDim2.fromScale(0.04, 0.08)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = colour
	label.TextStrokeTransparency = 1
	label.Text = text
	label.Parent = gui
end

local function banner(model: Instance, at: (number, number, number) -> CFrame, spec: Spec)
	local z, y = FRONT + 2.0, HEIGHT + 2.5
	cylinderForward(model, "BrandRoundel", 0.5, 4.0, at(0, y, z), JOINERY)
	cylinderForward(model, "BrandInset", 0.15, 3.5, at(0, y, z + 0.34), spec.accent)
	if spec.style == "boutique" then
		local nose = ball(model, "PigSnout", 2.15, at(0, y, z + 0.55), CREAM)
		nose.Size = Vector3.new(2.15, 1.35, 0.5)
		nose.Shape = Enum.PartType.Block
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = nose
		for _, x in {-0.5, 0.5} do
			ball(model, "Nostril", 0.32, at(x, y, z + 0.82), JOINERY)
		end
	elseif spec.style == "garden" then
		for _, side in {-1, 1} do
			local leaf = ball(model, "BrandLeaf", 1.5, at(side * 0.48, y + 0.2, z + 0.55)
				* CFrame.Angles(0, 0, side * -0.5), CREAM)
			leaf.Size = Vector3.new(0.85, 1.6, 0.3)
			leaf.Shape = Enum.PartType.Block
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = leaf
		end
		add(model, "BrandStem", Vector3.new(0.18, 1.8, 0.25), at(0, y - 0.25, z + 0.62), CREAM)
	elseif spec.style == "wheels" then
		cylinderForward(model, "BrandTyre", 0.2, 2.6, at(0, y, z + 0.55), JOINERY)
		cylinderForward(model, "BrandRim", 0.22, 1.9, at(0, y, z + 0.7), CREAM)
		cylinderForward(model, "BrandHub", 0.24, 0.5, at(0, y, z + 0.85), JOINERY)
	else
		cylinderForward(model, "BrandKeyBow", 0.2, 1.1, at(-0.6, y + 0.65, z + 0.55), CREAM)
		add(model, "BrandKeyStem", Vector3.new(0.3, 1.9, 0.22), at(0, y - 0.05, z + 0.57)
			* CFrame.Angles(0, 0, math.rad(40)), CREAM)
		add(model, "BrandKeyBit", Vector3.new(0.8, 0.28, 0.24), at(0.65, y - 0.65, z + 0.58), CREAM)
	end
end

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

local function shopWindow(model: Instance, at: (number, number, number) -> CFrame,
	x: number, w: number, y0: number, y1: number, trim: Color3)
	local h = y1 - y0
	local cy = (y0 + y1) / 2
	local z = FRONT - 0.55

	for _, side in {-1, 1} do
		add(model, "WinJamb", Vector3.new(0.45, h + 0.9, 0.5), at(x + side * (w / 2 + 0.225), cy, z), JOINERY)
		add(model, "WinRail", Vector3.new(w, 0.45, 0.5), at(x, cy + side * (h / 2 + 0.225), z), JOINERY)
	end

	local pane = add(model, "WinGlass", Vector3.new(w, h, 0.3), at(x, cy, z + 0.14), GLASS)
	pane.Transparency = 0.88
	pane.Reflectance = 0

	add(model, "MullionV", Vector3.new(0.32, h - 0.16, 0.38), at(x, cy, z + 0.3), JOINERY)
	add(model, "MullionH", Vector3.new(w - 0.16, 0.32, 0.3), at(x, y1 - 1.05, z + 0.22), JOINERY)

	add(model, "Sill", Vector3.new(w + 2.0, 0.5, 1.0), at(x, y0 - 0.62, z + 0.30), trim)
end


type At = (x: number, y: number, z: number) -> CFrame

export type Layout = {
	glassX: number, glassW: number,
	doorX: number, doorW: number,
	clear: number,
	bayZ: number, bayTop: number,
	wall: Color3, trim: Color3, base: Color3,
}

type Style = (model: Model, at: At, spec: Spec, cf: CFrame, L: Layout) -> ()

local STYLES: { [string]: Style } = {}

STYLES.boutique = function(model, at, spec, cf, L)
	local roof = spec.accent:Lerp(Color3.new(0, 0, 0), 0.28)

	LowPoly.tiledRoof(model, WIDTH + 1.8, DEPTH + 1.8, HEIGHT, 4.8, 4, roof, CREAM, cf)

	LowPoly.pediment(model, 11.0, 0.9, HEIGHT + 0.1, 3.0, CREAM, cf * CFrame.new(0, 0, FRONT + 0.55))
	add(model, "PedimentBed", Vector3.new(11.6, 0.7, 1.4), at(0, HEIGHT - 0.25, FRONT + 0.62), CREAM)

	local outZ = FRONT + 3.8
	local canvasY0, canvasY1 = TRANSOM_TOP - 0.1, 9.1
	local run = math.sqrt((outZ - FRONT) ^ 2 + (canvasY0 - canvasY1) ^ 2)
	local tilt = math.atan2(canvasY0 - canvasY1, outZ - FRONT)

	local span = L.glassW + 1.6
	local spanX = L.glassX
	for i = 0, 5 do
		local pw = span / 6
		add(model, "Canvas", Vector3.new(pw, 0.42, run),
			at(spanX - span / 2 + pw * (i + 0.5), (canvasY0 + canvasY1) / 2, (FRONT + outZ) / 2)
				* CFrame.Angles(tilt, 0, 0),
			if i % 2 == 0 then spec.accent else CREAM)
	end

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

	animate(add(model, "NeonStrip", Vector3.new(L.glassW - 0.8, 0.4, 0.4),
		at(L.glassX, GLAZE_TOP + 0.35, FRONT + 0.68), spec.accent, Enum.Material.Neon),
		"cycle", { Rate = 0.16, Sat = 0.78 })

	for _, sx in ipairs({ -1, 1 }) do
		local px = sx * (WIDTH / 2 - 1.0)
		add(model, "PlanterBox", Vector3.new(3.0, 1.9, 3.0), at(px, PAVE_TOP + 0.85, FRONT + 4.6), STONE)
		add(model, "PlanterRim", Vector3.new(3.4, 0.45, 3.4), at(px, PAVE_TOP + 1.9, FRONT + 4.6), CREAM)
		ball(model, "Bloom", 2.3, at(px, PAVE_TOP + 3.1, FRONT + 4.6), Color3.fromRGB(226, 118, 156))
		ball(model, "Bloom", 1.5, at(px - sx * 0.9, PAVE_TOP + 2.5, FRONT + 5.2), Color3.fromRGB(246, 172, 196))
	end
end

STYLES.garden = function(model, at, spec, cf, L)
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
	add(model, "Ridge", Vector3.new(WIDTH + 2.3, 0.9, 1.1), at(0, HEIGHT + pitch + 0.15, 0), CREAM)
	for _, dir in ipairs({ -1, 1 }) do
		add(model, "Gutter", Vector3.new(WIDTH + 2.3, 0.85, 0.6),
			at(0, HEIGHT - 0.25, dir * (half + 0.15)), CREAM)
	end

	for i = -1, 1 do
		local px = L.glassX + i * 2.0
		add(model, "Pot", Vector3.new(1.25, 1.2, 1.25),
			at(px, L.bayTop + 0.55, L.bayZ), Color3.fromRGB(196, 104, 70))
		add(model, "PotRim", Vector3.new(1.5, 0.32, 1.5),
			at(px, L.bayTop + 1.05, L.bayZ), Color3.fromRGB(168, 84, 56))
		ball(model, "InnerShrub", 1.7, at(px, L.bayTop + 2.0, L.bayZ),
			Color3.fromRGB(88, 152, 88))
	end

	local openW = L.glassW + 1.6
	add(model, "OpenBeam", Vector3.new(openW, 1.1, 1.4),
		at(L.glassX, RISER_TOP + 0.4, FRONT - 0.6), TIMBER)
	for i = -1, 1 do
		add(model, "Rafter", Vector3.new(0.5, 0.6, 3.0),
			at(L.glassX + i * (L.glassW / 3), GLAZE_TOP - 0.5, FRONT - 1.4), TIMBER)
	end

	animate(add(model, "NeonStrip", Vector3.new(L.glassW - 0.8, 0.4, 0.4),
		at(L.glassX, GLAZE_TOP + 0.35, FRONT + 0.68), spec.accent, Enum.Material.Neon),
		"pulse", { Rate = 0.22, Hue = 0.32, Sat = 0.7, Dim = 0.45 })

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

STYLES.wheels = function(model, at, spec, cf, L)
	add(model, "RoofDeck", Vector3.new(WIDTH + 0.6, 0.6, DEPTH + 0.6),
		at(0, HEIGHT + 0.3, 0), Color3.fromRGB(96, 98, 106))
	LowPoly.parapet(model, WIDTH + 0.6, DEPTH + 0.6, HEIGHT + 0.5, 3.2, 1.1, L.wall, cf)
	for _, sz in ipairs({ -1, 1 }) do
		add(model, "Coping", Vector3.new(WIDTH + 3.4, 0.65, 1.5),
			at(0, HEIGHT + 3.85, sz * ((DEPTH + 0.6) / 2 + 0.55)), spec.accent)
	end
	for _, sx in ipairs({ -1, 1 }) do
		add(model, "Coping", Vector3.new(1.5, 0.6, DEPTH + 0.5),
			at(sx * ((WIDTH + 0.6) / 2 + 0.55), HEIGHT + 3.8, 0), spec.accent)
	end

	local n = 9
	for i = 0, n - 1 do
		local bulb = ball(model, "Bulb", 0.95,
			at(-WIDTH / 2 + (WIDTH / (n - 1)) * i, HEIGHT + 2.0, (DEPTH + 0.6) / 2 + 1.35),
			spec.accent, Enum.Material.Neon)
		animate(bulb, "chase",
			{ Rate = 0.5, Phase = i / n, Hue = 0.09, Sat = 0.85, Span = 0.28, Dim = 0.42 })
	end

	local bayW, bayX = L.glassW + 1.6, L.glassX
	add(model, "Shutter", Vector3.new(bayW, 2.6, 0.5), at(bayX, GLAZE_TOP - 1.0, FRONT + 0.1), LEAD)
	for i = 0, 3 do
		add(model, "ShutterRib", Vector3.new(bayW - 0.5, 0.22, 0.52),
			at(bayX, GLAZE_TOP - 2.0 + i * 0.62, FRONT + 0.38 + (i % 2) * 0.06),
			LEAD:Lerp(Color3.new(0, 0, 0), 0.3))
	end
	add(model, "ShutterBox", Vector3.new(bayW + 0.8, 1.0, 1.1), at(bayX, GLAZE_TOP + 0.55, FRONT + 0.15), FRAME)

	local rackX = L.glassX
	add(model, "ServiceBench", Vector3.new(6.2, 0.4, 2.0), at(rackX, PAVE_TOP + 1.5, FRONT + 3.4), FRAME)
	for _, dx in {-2.4, 2.4} do
		add(model, "BenchLeg", Vector3.new(0.45, 1.4, 1.4), at(rackX + dx, PAVE_TOP + 0.65, FRONT + 3.4), spec.accent)
	end
	for i = -1, 1 do
		cylinderForward(model, "SpareTyre", 0.5, 1.6, at(rackX + i * 1.8, PAVE_TOP + 2.5, FRONT + 3.4), FRAME)
		cylinderForward(model, "SpareRim", 0.54, 0.9, at(rackX + i * 1.8, PAVE_TOP + 2.5, FRONT + 3.45), CREAM)
	end

	cylinderUp(model, "Bollard", 3.4, 0.85, at(WIDTH / 2 - 1.6, PAVE_TOP + 1.6, FRONT + 3.2), GOLD)
	ball(model, "BollardCap", 0.9, at(WIDTH / 2 - 1.6, PAVE_TOP + 3.3, FRONT + 3.2), GOLD)
end

STYLES.security = function(model, at, spec, cf, L)
	add(model, "RoofDeck", Vector3.new(WIDTH + 0.6, 0.6, DEPTH + 0.6),
		at(0, HEIGHT + 0.3, 0), STONE:Lerp(Color3.new(0, 0, 0), 0.3))
	LowPoly.parapet(model, WIDTH + 0.6, DEPTH + 0.6, HEIGHT + 0.5, 2.0, 1.1, STONE, cf)

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

	local bars = 7
	for i = 1, bars do
		cylinderUp(model, "Bar", GLAZE_TOP - RISER_TOP + 0.4, 0.3,
			at(L.glassX - L.glassW / 2 + (L.glassW / (bars + 1)) * i,
				(RISER_TOP + GLAZE_TOP) / 2, FRONT - 0.18), LEAD)
	end
	for _, y in ipairs({ RISER_TOP + 0.55, GLAZE_TOP - 0.55 }) do
		add(model, "BarRail", Vector3.new(L.glassW - 0.3, 0.34, 0.36), at(L.glassX, y, FRONT - 0.16), LEAD)
	end

	add(model, "LampBase", Vector3.new(1.5, 0.7, 1.5), at(0, HEIGHT + 3.05, (DEPTH + 0.6) / 2 + 0.55), FRAME)
	animate(ball(model, "Lamp", 1.7,
		at(0, HEIGHT + 4.1, (DEPTH + 0.6) / 2 + 0.55), spec.accent, Enum.Material.Neon),
		"beacon", { Rate = 0.42, Hue = 0.58, Sat = 0.75, Dim = 0.2 })

	local plateX = -(L.clear + 1.4)
	local faceZ = FRONT + 0.62
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


function ShopFront.build(cf: CFrame, groundY: number, spec: Spec, parent: Instance): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = "Shop_" .. spec.tab

	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end

	local glazed = spec.style ~= "garden"

	local WALL = spec.accent:Lerp(Color3.fromRGB(250, 247, 240), 0.70)
	local trim = CREAM
	local base = STONE:Lerp(Color3.new(0, 0, 0), 0.14)
	local wallH = HEIGHT - PLINTH_TOP + SINK

	add(model, "Forecourt", Vector3.new(WIDTH + FORECOURT_OVERHANG, PAVE_TOP, DEPTH + 7),
		at(0, PAVE_TOP / 2, 3.4), STONE)
	local kerbTone = STONE:Lerp(CREAM, 0.3)
	for _, sx in ipairs({ -1, 1 }) do
		add(model, "Kerb", Vector3.new(0.7, 0.68, DEPTH + 7.2),
			at(sx * ((WIDTH + FORECOURT_OVERHANG) / 2 + 0.2), 0.28, 3.4), kerbTone)
	end
	add(model, "Kerb", Vector3.new(WIDTH + FORECOURT_OVERHANG + 1.4, 0.98, 0.8),
		at(0, 0.23, 3.4 + (DEPTH + 7.2) / 2 + 0.05), kerbTone)

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

	add(model, "Back", Vector3.new(WIDTH - 1.6, wallH, 0.8),
		at(0, PLINTH_TOP - SINK + wallH / 2, -DEPTH / 2 + 0.1), WALL)
	for _, sx in ipairs({ -1, 1 }) do
		add(model, "Side", Vector3.new(0.8, wallH, DEPTH - 0.4),
			at(sx * (WIDTH / 2 - 0.1), PLINTH_TOP - SINK + wallH / 2, 0), WALL)
	end

	-- Corner trim stays outside the room, clear of the interior feature wall.
	for _, side in {-1, 1} do
		add(model, "BackCornerTrim", Vector3.new(0.45, wallH, 1.0),
			at(side * (WIDTH / 2 + 0.12), PLINTH_TOP - SINK + wallH / 2, -DEPTH / 2 + 0.35), trim)
	end

	local R = Config.SHOP_ROOM
	ShopInterior.build(model, at, spec)

	local pierW = 2.8
	local pierX = WIDTH / 2 - pierW / 2 - 0.2
	for _, sx in ipairs({ -1, 1 }) do
		pier(model, at, sx * pierX, pierW, 2.0, PLINTH_TOP - SINK, TRANSOM_TOP, WALL, trim)
	end

	local clear = pierX - pierW / 2 -- inner face of each pier
	local doorW = 4.2
	local doorX = clear - doorW / 2 - 0.15

	local winLeft = -clear + 0.4
	local winRight = doorX - doorW / 2 - 2.0
	local glassW = winRight - winLeft
	local glassX = (winLeft + winRight) / 2

	add(model, "StallRiser", Vector3.new(glassW + 2.4, RISER_TOP - PLINTH_TOP + SINK, 0.9),
		at(glassX, (PLINTH_TOP - SINK + RISER_TOP) / 2, FRONT - 0.5), TIMBER)
	add(model, "RiserPanel", Vector3.new(glassW - 0.6, RISER_TOP - PLINTH_TOP - 1.1, 0.5),
		at(glassX, (PLINTH_TOP + RISER_TOP) / 2 - 0.1, FRONT - 0.2),
		TIMBER:Lerp(Color3.new(0, 0, 0), 0.22))

	local yaw = math.rad(DISPLAY_YAW)
	local BAY_CAP_DEPTH = DISPLAY_SPAN * (math.cos(yaw) + math.sin(yaw)) - 0.55
	local BAY_PLINTH_DEPTH = BAY_CAP_DEPTH - 0.4
	local bayZ = R.bayFront - BAY_CAP_DEPTH / 2


	add(model, "Plinth", Vector3.new(R.bayWidth - 0.4, RISER_TOP - PLINTH_TOP + SINK, BAY_PLINTH_DEPTH),
		at(glassX, (PLINTH_TOP - SINK + RISER_TOP) / 2, bayZ), TIMBER)
	local BAY_CAP_Y, BAY_CAP_T = RISER_TOP + 0.12, 0.45
	local bayTop = BAY_CAP_Y + BAY_CAP_T / 2
	add(model, "PlinthCap", Vector3.new(R.bayWidth, BAY_CAP_T, BAY_CAP_DEPTH),
		at(glassX, BAY_CAP_Y, bayZ), trim)

	if glassX + R.bayWidth / 2 > R.aisleX or glassX + R.caseWidth / 2 > R.aisleX then
		warn(("ShopFront: '%s' display bay reaches x %.2f, inside the aisle at %.2f")
			:format(spec.tab,
				math.max(glassX + R.bayWidth / 2, glassX + R.caseWidth / 2), R.aisleX))
	end

	if glazed then
		shopWindow(model, at, glassX, glassW, RISER_TOP, GLAZE_TOP, trim)
	end

	local frameTop, frameBase = 10.28, 1.2
	for _, side in {-1, 1} do
		add(model, "DoorJamb", Vector3.new(0.48, frameTop - frameBase, 0.62),
			at(doorX + side * (doorW / 2 + 0.24), (frameBase + frameTop) / 2, FRONT - 0.5), JOINERY)
	end
	add(model, "DoorLintel", Vector3.new(doorW + 0.96, 0.45, 0.62),
		at(doorX, frameTop, FRONT - 0.5), JOINERY)
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

	local open = add(model, "OpenSign", Vector3.new(2.6, 0.95, 0.2),
		onLeaf(0, GLAZE_TOP - 1.2, 0.42), Color3.fromRGB(255, 96, 96), Enum.Material.Neon)
	sign(open, Enum.NormalId.Back, "OPEN", Color3.fromRGB(255, 246, 246))
	animate(open, "pulse", { Rate = 0.3, Hue = 0.99, Sat = 0.62, Dim = 0.5 })

	add(model, "Transom", Vector3.new(WIDTH + 0.5, TRANSOM_TOP - GLAZE_TOP, 1.0),
		at(0, (GLAZE_TOP + TRANSOM_TOP) / 2, FRONT - 0.05), JOINERY)

	local fascia = add(model, "Fascia", Vector3.new(WIDTH + 0.6, HEIGHT - TRANSOM_TOP - 0.5, 0.55),
		at(0, (TRANSOM_TOP + HEIGHT) / 2 - 0.25, FRONT + 0.4), spec.accent:Lerp(JOINERY, 0.5))
	sign(fascia, Enum.NormalId.Back, spec.name, CREAM)
	add(model, "Cornice", Vector3.new(WIDTH + 1.6, 0.7, 1.3), at(0, HEIGHT - 0.35, FRONT + 0.6), trim)
	add(model, "FasciaRail", Vector3.new(WIDTH + 1.2, 0.5, 0.9), at(0, TRANSOM_TOP + 0.05, FRONT + 0.35), trim)

	local armX = -WIDTH / 2 + 1.8
	cylinderAlongX(model, "SignArm", 4.8, 0.34,
		at(armX, TRANSOM_TOP + 0.9, FRONT + 2.7) * CFrame.Angles(0, math.rad(90), 0), FRAME)
	add(model, "SignBracket", Vector3.new(0.42, 1.9, 1.9),
		at(armX, TRANSOM_TOP - 0.15, FRONT + 1.0) * CFrame.Angles(math.rad(45), 0, 0), FRAME)
	local hang = add(model, "HangingSign", Vector3.new(0.36, 2.9, 6.2),
		at(armX, TRANSOM_TOP - 1.9, FRONT + 3.5), spec.accent)
	sign(hang, Enum.NormalId.Left, spec.name, Theme.INK)
	sign(hang, Enum.NormalId.Right, spec.name, Theme.INK)
	for _, sy in ipairs({ -1, 1 }) do
		add(model, "SignEdge", Vector3.new(0.46, 0.4, 6.4),
			at(armX, TRANSOM_TOP - 1.9 + sy * 1.35, FRONT + 3.5), CREAM)
	end
	for _, sz in ipairs({ -1, 1 }) do
		add(model, "SignEdge", Vector3.new(0.56, 3.3, 0.4),
			at(armX, TRANSOM_TOP - 1.9, FRONT + 3.5 + sz * 3.1), CREAM)
		cylinderUp(model, "SignLink", 1.5, 0.18,
			at(armX, TRANSOM_TOP + 0.15, FRONT + 3.5 + sz * 2.4), FRAME)
	end

	banner(model, at, spec)

	local style = STYLES[spec.style]
	if style then
		style(model, at, spec, cf, {
			glassX = glassX, glassW = glassW,
			doorX = doorX, doorW = doorW, clear = clear,
			bayZ = bayZ, bayTop = bayTop,
			wall = WALL, trim = trim, base = base,
		})
	end

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
				scaleModel(display, DISPLAY_SPAN / longest)
			end
			display.Name = "Display"
			display:PivotTo(at(glassX, RISER_TOP + 2.1, bayZ)
				* CFrame.Angles(0, math.rad(DISPLAY_YAW), 0))
			-- Builders have different pivot conventions. Seat the actual bottom
			-- on the pedestal, including bikes whose pivot is at ground level.
			local boundsCF, boundsSize = display:GetBoundingBox()
			local bottom = boundsCF.Position.Y - boundsSize.Y / 2
			local target = at(glassX, bayTop + 0.04, bayZ).Position.Y
			display:PivotTo(display:GetPivot() + Vector3.new(0, target - bottom, 0))
			display.Parent = model
		elseif not ok then
			warn(("ShopFront: display for '%s' failed: %s"):format(spec.tab, tostring(display)))
		end
	end

	do
		local T = 1.0
		local y0, y1 = -1.0, HEIGHT
		local h, cy = y1 - y0, (y0 + y1) / 2
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
			p.CanQuery = false
			p.CastShadow = false
			p.Transparency = 1
			p.Parent = model
		end

		barrier(Vector3.new(WIDTH + T, h, T), at(0, cy, inZ - T / 2))
		for _, sx in ipairs({ -1, 1 }) do
			barrier(Vector3.new(T, h, DEPTH + T), at(sx * (inX + T / 2), cy, 0))
		end
		local gapL, gapR = doorX - doorW / 2, doorX + doorW / 2
		local edge = inX + T / 2
		barrier(Vector3.new(gapL + edge, h, T),
			at((gapL - edge) / 2, cy, frontZ + T / 2))
		barrier(Vector3.new(edge - gapR, h, T),
			at((gapR + edge) / 2, cy, frontZ + T / 2))
	end

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

	model.WorldPivot = CFrame.new(cf.Position)
	model.Parent = parent
	return model, door
end

return ShopFront
