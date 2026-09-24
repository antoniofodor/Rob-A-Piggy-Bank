--!strict
-- Shop fittings share the audited room plan with the vault and shopkeeper.
-- Everything is decorative; PlotService still owns the walkable base.
local Config = require(script.Parent.Config)
local LowPoly = require(script.Parent.LowPoly)
local Theme = require(script.Parent.Theme)

local ShopInterior = {}
local CREAM = Color3.fromRGB(231, 222, 202)
local INK = Color3.fromRGB(48, 49, 61)
local WOOD = Color3.fromRGB(153, 108, 71)
local GOLD = Color3.fromRGB(207, 159, 65)
local GREEN = Color3.fromRGB(70, 139, 85)

type At = (number, number, number) -> CFrame

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	return LowPoly.part(parent, name, size, cf, color, Enum.Material.SmoothPlastic)
end

local function label(p: BasePart, text: string, color: Color3, face: Enum.NormalId?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 48
	gui.LightInfluence = 0
	gui.Parent = p
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(0.9, 0.8)
	textLabel.Position = UDim2.fromScale(0.05, 0.1)
	textLabel.BackgroundTransparency = 1
	textLabel.Text = text
	textLabel.Font = Theme.FONT
	textLabel.TextScaled = true
	textLabel.TextColor3 = color
	textLabel.Parent = gui
end

local function cylinder(parent: Instance, name: string, cf: CFrame, height: number, diameter: number, color: Color3): Part
	local p = part(parent, name, Vector3.new(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.pi / 2), color)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function plant(parent: Instance, cf: CFrame, scale: number)
	cylinder(parent, "TerracottaPot", cf * CFrame.new(0, 0.4 * scale, 0), 0.8 * scale, 0.95 * scale, Color3.fromRGB(182, 98, 69))
	cylinder(parent, "PotLip", cf * CFrame.new(0, 0.8 * scale, 0), 0.2 * scale, 1.1 * scale, Color3.fromRGB(216, 136, 97))
	for i = 1, 5 do
		local angle = i * math.pi * 2 / 5
		local leaf = part(parent, "Leaf", Vector3.new(0.42, 1.25, 0.65) * scale,
			cf * CFrame.Angles(0, angle, 0) * CFrame.new(0, 1.2 * scale, 0.23 * scale) * CFrame.Angles(-0.45, 0, 0),
			GREEN:Lerp(CREAM, i * 0.055))
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = leaf
	end
end

function ShopInterior.build(parent: Instance, at: At, spec: any)
	local m = Instance.new("Model")
	m.Name = "Interior"
	m.Parent = parent
	local u, r = Config.SHOP_UNIT, Config.SHOP_ROOM
	local floor = u.floorY
	local accent = spec.accent:Lerp(INK, 0.3)
	local garden = spec.style == "garden"
	local boutique = spec.style == "boutique"
	local wheels = spec.style == "wheels"
	local floorColor = if garden then Color3.fromRGB(171, 147, 105)
		elseif boutique then Color3.fromRGB(216, 195, 183) else Color3.fromRGB(131, 146, 157)
	part(m, "FloorFinish", Vector3.new(u.roomWidth, 0.09, u.roomDepth), at(0, floor + 0.015, 0), floorColor)
	-- Inlaid seams, all below the avatar's feet. No new collision surface.
	for i = -3, 3 do
		part(m, "FloorJoint", Vector3.new(0.035, 0.015, u.roomDepth - 0.1), at(i * 2.5, floor + 0.067, 0), floorColor:Lerp(INK, 0.22))
	end
	for i = -2, 2 do
		part(m, "FloorJoint", Vector3.new(u.roomWidth - 0.1, 0.015, 0.035), at(0, floor + 0.067, i * 2.5), floorColor:Lerp(INK, 0.22))
	end
	local rug = part(m, "WelcomeMat", Vector3.new(3.6, 0.035, 2.0), at(u.vaultX, floor + 0.09, 5.15), accent)
	label(rug, "WELCOME", CREAM, Enum.NormalId.Top)
	-- Wainscot and continuous rails give the room a finished edge.
	for _, side in {-1, 1} do
		part(m, "WallPanel", Vector3.new(0.15, 2.0, 13.5), at(side * 9.93, floor + 0.9, 0), accent)
		part(m, "ChairRail", Vector3.new(0.23, 0.16, 13.5), at(side * 9.85, floor + 1.95, 0), CREAM)
		part(m, "Skirting", Vector3.new(0.25, 0.35, 13.5), at(side * 9.84, floor + 0.16, 0), INK)
	end
	part(m, "BackPanel", Vector3.new(19.5, 2.0, 0.15), at(0, floor + 0.9, -6.91), accent)
	part(m, "BackRail", Vector3.new(19.5, 0.16, 0.23), at(0, floor + 1.95, -6.83), CREAM)
	-- Counter bounds deliberately match SHOP_ROOM, including its nosing.
	local cx = (r.counterLeft + r.counterRight) / 2
	local cw = r.counterRight - r.counterLeft
	local cz = (r.counterBack + r.counterFront) / 2
	part(m, "Counter", Vector3.new(cw - 0.3, 2.75, 1.15), at(cx, floor + 1.3, cz - 0.1), accent)
	part(m, "CounterToe", Vector3.new(cw - 0.65, 0.3, 1.1), at(cx, floor + 0.12, cz - 0.1), INK)
	part(m, "CounterTop", Vector3.new(cw, 0.32, r.counterFront - r.counterBack), at(cx, floor + 2.8, cz), if garden then WOOD else CREAM)
	for i = -2, 2 do
		part(m, "CounterFlute", Vector3.new(0.11, 2.05, 0.08), at(cx + i * 0.78, floor + 1.35, cz + 0.52), accent:Lerp(CREAM, 0.4))
	end
	local badge = part(m, "CounterBadge", Vector3.new(2.3, 0.65, 0.1), at(cx, floor + 1.55, cz + 0.61), CREAM)
	label(badge, if garden then "GROW HAPPY" elseif boutique then "PIGGY & CO." elseif wheels then "THE PIT STOP" else "STAY SAFE", INK)
	part(m, "TillBase", Vector3.new(1.15, 0.2, 0.9), at(cx + 1.3, floor + 3.02, cz), INK)
	part(m, "TillStand", Vector3.new(0.18, 0.5, 0.2), at(cx + 1.3, floor + 3.3, cz), GOLD)
	local screen = part(m, "TillScreen", Vector3.new(1.0, 0.65, 0.15), at(cx + 1.3, floor + 3.6, cz) * CFrame.Angles(-0.14, 0, 0), INK)
	label(screen, "HELLO!", Color3.fromRGB(135, 220, 183))
	-- Product shelves occupy only the original left-wall band.
	local sx = r.shelfFace - 0.675
	local sz = (r.shelfBack + r.shelfFront) / 2
	for _, dz in {-1, 1} do
		part(m, "ShelfUpright", Vector3.new(1.35, 5.4, 0.18), at(sx, floor + 2.65, sz + dz * 2.3), accent)
	end
	for row = 0, 2 do
		local y = floor + 0.7 + row * 1.65
		part(m, "Shelf", Vector3.new(1.18, 0.2, 4.7), at(sx, y, sz), if garden then WOOD else CREAM)
		for col = -1, 1 do
			local item = at(sx, y + 0.12, sz + col * 1.5)
			if garden then
				plant(m, item, 0.66)
			elseif boutique then
				local color = ({spec.accent, Color3.fromRGB(149, 133, 192), Color3.fromRGB(119, 185, 180)})[col + 2]
				part(m, "GiftBox", Vector3.new(0.82, 0.8, 1.0), item * CFrame.new(0, 0.4, 0), color)
				part(m, "GiftRibbon", Vector3.new(0.86, 0.84, 0.13), item * CFrame.new(0, 0.41, 0), CREAM)
			else
				part(m, "KitCase", Vector3.new(0.82, 0.65, 0.96), item * CFrame.new(0, 0.35, 0), if wheels then Color3.fromRGB(205, 137, 62) else INK)
				part(m, "CaseLatch", Vector3.new(0.08, 0.18, 0.15), item * CFrame.new(0.45, 0.38, 0), GOLD)
				part(m, "CaseHandle", Vector3.new(0.18, 0.13, 0.5), item * CFrame.new(0, 0.76, 0), CREAM)
			end
		end
	end
	-- The brand wall is behind the keeper and left of the vault. Flush wall
	-- dressing never spends any of the keeper's standing space.
	part(m, "FeatureWall", Vector3.new(8.2, 6.0, 0.15), at(-5.1, floor + 6.7, -6.85), accent)
	local brand = part(m, "BrandPlaque", Vector3.new(7.0, 1.1, 0.15), at(-5.1, floor + 8.8, -6.71), CREAM)
	label(brand, if garden then "HOME GROWN" elseif boutique then "PIGGY OUTFITTERS" elseif wheels then "BUILT FOR ADVENTURE" else "UPGRADES", INK)
	if boutique then
		part(m, "MirrorFrame", Vector3.new(3.1, 3.7, 0.22), at(-5.2, floor + 6, -6.65), GOLD)
		local mirror = part(m, "Mirror", Vector3.new(2.7, 3.3, 0.08), at(-5.2, floor + 6, -6.48), Color3.fromRGB(161, 201, 212))
		mirror.Reflectance = 0.18
		for _, dx in {-2.4, 2.4} do
			part(m, "DisplayHook", Vector3.new(0.15, 0.15, 0.4), at(-5.2 + dx, floor + 6.8, -6.45), GOLD)
			part(m, "Swatch", Vector3.new(1.1, 1.5, 0.12), at(-5.2 + dx, floor + 6.0, -6.35), if dx < 0 then CREAM else spec.accent)
		end
	elseif garden then
		for row = 0, 1 do
			part(m, "PlantLedge", Vector3.new(7.0, 0.18, 0.65), at(-5.1, floor + 4.7 + row * 1.8, -6.4), WOOD)
			for i = -2, 2 do plant(m, at(-5.1 + i * 1.35, floor + 4.8 + row * 1.8, -6.4), 0.56) end
		end
	elseif wheels then
		-- A wall-mounted wheel, and a tidy tool rack.
		local wheelCF = at(-6.4, floor + 6.2, -6.45) * CFrame.Angles(math.pi / 2, 0, 0)
		cylinder(m, "WheelTyre", wheelCF, 0.28, 2.7, INK)
		cylinder(m, "WheelRim", wheelCF * CFrame.new(0, 0.2, 0), 0.12, 2.1, CREAM)
		cylinder(m, "WheelHub", wheelCF * CFrame.new(0, 0.29, 0), 0.14, 0.5, spec.accent)
		for i = 0, 2 do
			part(m, "ToolHandle", Vector3.new(0.2, 1.5, 0.2), at(-4.1 + i * 0.8, floor + 6.0, -6.4), CREAM)
			part(m, "ToolHead", Vector3.new(0.65, 0.35, 0.26), at(-4.1 + i * 0.8, floor + 6.8, -6.4), INK)
		end
	else
		for i = -1, 1 do
			local x = -5.1 + i * 2.1
			cylinder(m, "KeyBow", at(x, floor + 6.7, -6.4) * CFrame.Angles(math.pi / 2, 0, 0), 0.18, 0.85, GOLD)
			part(m, "KeyStem", Vector3.new(0.22, 1.3, 0.18), at(x, floor + 5.9, -6.4), GOLD)
			part(m, "KeyTooth", Vector3.new(0.6, 0.22, 0.18), at(x + 0.18, floor + 5.4, -6.4), GOLD)
		end
	end
	-- Pendants stay overhead, beyond the walk and the existing vault sign.
	for _, x in {-5.7, 4.6} do
		cylinder(m, "PendantCord", at(x, 11.3, 0), 2.2, 0.09, INK)
		cylinder(m, "PendantShade", at(x, 10.3, 0), 0.45, 1.5, accent)
		local bulb = cylinder(m, "WarmDiffuser", at(x, 10.04, 0), 0.12, 1.1, Color3.fromRGB(255, 202, 127))
		bulb.Material = Enum.Material.Neon
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 221, 179)
		light.Brightness = 0.6
		light.Range = 14
		light.Shadows = false
		light.Parent = bulb
	end
end

return ShopInterior
