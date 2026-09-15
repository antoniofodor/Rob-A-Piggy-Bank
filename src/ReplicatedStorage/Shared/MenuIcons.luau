--!strict
-- Static, transparent menu silhouettes. Drawn in the game's own palette,
-- with no image uploads and no dependency on the HUD's Motion animator.
local Theme = require(script.Parent.Theme)
local MenuIcons = {}

-- Authored at 96px, scaled as one illustration into the existing touch area.
local function part(parent: Instance, name: string, x: number, y: number,
	w: number, h: number, colour: Color3, radius: number, z: number,
	stroke: number?): Frame

	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = UDim2.fromOffset(x, y)
	frame.Size = UDim2.fromOffset(w, h)
	frame.BackgroundColor3 = colour
	frame.BorderSizePixel = 0
	frame.ZIndex = z
	Theme.corner(frame, radius)
	if stroke then Theme.outline(frame, stroke, Theme.INK) end
	frame.Parent = parent
	return frame
end

local function shine(parent: Instance, x: number, y: number, w: number, h: number)
	local p = part(parent, "Highlight", x, y, w, h, Theme.PAPER, h / 2, 2)
	p.BackgroundTransparency = 0.3
end

local function screw(parent: Instance, x: number, y: number, size: number)
	local p = part(parent, "Rivet", x, y, size, size, Theme.GOLD, size / 2, 4, 1)
	part(p, "Slot", size * 0.25, size * 0.45, size * 0.5, 1.5, Theme.MUTED, 1, 1)
end

local function options(icon: Frame)
	-- Broad teeth and a shaded rim give the cog its silhouette without a tile.
	for i = 0, 7 do
		local angle = math.rad(i * 45)
		local tooth = part(icon, "Tooth" .. i,
			48 + math.sin(angle) * 33 - 8, 48 - math.cos(angle) * 33 - 14,
			16, 27, Theme.SAND_DEEP, 4, 1, 2.5)
		tooth.Rotation = i * 45
		part(tooth, "Face", 2.5, 2, 11, 20, Theme.PAPER, 3, 1)
	end
	local rim = part(icon, "CogRim", 17, 19, 62, 62, Theme.SAND_DEEP, 31, 2, 2.5)
	Theme.shade(rim, 0.82)
	local face = part(icon, "CogFace", 17, 15, 62, 62, Theme.PAPER, 31, 3, 2.5)
	Theme.shade(face, 0.9)
	local bevel = part(face, "Bevel", 7, 7, 48, 48, Theme.GOLD_DEEP, 24, 1)
	Theme.outline(bevel, 1.5, Theme.MUTED)
	local inset = part(bevel, "Inset", 5, 5, 38, 38, Theme.SLAB, 19, 1, 1.5)
	Theme.shade(inset, 0.78)
	-- A recessed hex-like spindle and visible fasteners read as machinery.
	local hub = part(inset, "Hub", 9, 9, 20, 20, Theme.PAPER_DEEP, 5, 1, 1.5)
	hub.Rotation = 15
	part(hub, "Centre", 6, 6, 8, 8, Theme.SLAB_DEEP, 4, 1)
	for _, p in { Vector2.new(27, 3), Vector2.new(52, 27),
		Vector2.new(27, 52), Vector2.new(3, 27) } do
		screw(face, p.X, p.Y, 7)
	end
	shine(face, 13, 7, 12, 4)
end

local function stuff(icon: Frame)
	-- The carrying handle and two straps continue behind the bag itself.
	local handle = part(icon, "Handle", 31, 6, 33, 28, Theme.MUTED, 12, 1, 2.5)
	handle.BackgroundTransparency = 1
	Theme.outline(handle, 6, Theme.INK)
	local handleInlay = part(icon, "HandleInlay", 31, 6, 33, 28, Theme.MUTED, 12, 2)
	handleInlay.BackgroundTransparency = 1
	Theme.outline(handleInlay, 3, Theme.GOLD_DEEP)
	for _, x in { 20, 64 } do
		part(icon, "BackStrap", x, 19, 12, 65, Theme.MUTED, 6, 1, 2)
	end
	-- A rolled cream cloth and small green kit pouch peek out of the opening.
	local roll = part(icon, "RolledCloth", 10, 18, 46, 16, Theme.PAPER, 8, 2, 2)
	roll.Rotation = -12
	part(roll, "RollEnd", 3, 3, 10, 10, Theme.SAND_DEEP, 5, 1)
	part(roll, "Tie", 28, 0, 6, 16, Theme.MUTED, 2, 2)
	local pouch = part(icon, "KitPouch", 59, 16, 23, 26, Theme.GOOD, 6, 2, 2)
	pouch.Rotation = 12
	part(pouch, "Seam", 4, 7, 15, 3, Theme.GOOD_INK, 1, 1)
	local body = part(icon, "BagBody", 13, 30, 70, 57, Theme.PIG_DEEP, 15, 3, 3)
	Theme.shade(body, 0.82)
	part(body, "SideGusset", 56, 10, 10, 38, Theme.PIG_DEEP, 5, 1)
	local front = part(body, "Front", 4, 4, 57, 47, Theme.PIG, 11, 2)
	Theme.shade(front, 0.9)
	local flap = part(icon, "LeatherFlap", 12, 29, 72, 25, Theme.PIG, 10, 4, 2.5)
	Theme.shade(flap, 0.9)
	shine(flap, 8, 4, 31, 4)
	-- Chunky stitch marks remain distinct at the actual 64px display size.
	for _, x in { 10, 21, 49, 60 } do
		part(flap, "Stitch", x, 18, 5, 2, Theme.PAPER_DEEP, 1, 2)
	end
	local strap = part(icon, "ClaspStrap", 40, 43, 15, 28, Theme.MUTED, 4, 5, 1.5)
	local buckle = part(strap, "Buckle", 0, 6, 15, 13, Theme.GOLD, 3, 1, 1.5)
	part(buckle, "Opening", 4, 3, 7, 7, Theme.MUTED, 1, 1)
	part(buckle, "Pin", 6, 1, 3, 9, Theme.GOLD, 1, 2)
	-- A pig patch ties the collection bag to the same character as the HUD.
	local patch = part(icon, "PigPatch", 57, 61, 18, 15, Theme.PAPER, 7, 5, 1.5)
	for _, x in { 5, 11 } do
		part(patch, "Nostril", x, 5, 3, 6, Theme.PIG_DEEP, 2, 1)
	end
	for _, x in { 22, 32, 43 } do
		part(icon, "BottomStitch", x, 77, 5, 2, Theme.PAPER_DEEP, 1, 5)
	end
	screw(icon, 17, 48, 6)
	screw(icon, 75, 48, 6)
end

local function shop(icon: Frame)
	-- A miniature street shop: masonry, dark joinery and a striped awning.
	part(icon, "SideWall", 65, 32, 18, 54, Theme.SAND_DEEP, 4, 1, 2.5)
	local wall = part(icon, "Shopfront", 13, 31, 62, 55, Theme.PAPER, 4, 2, 2.5)
	Theme.shade(wall, 0.92)
	part(icon, "Foundation", 9, 81, 78, 8, Theme.MUTED, 3, 5, 2)
	part(icon, "DoorFrame", 46, 48, 23, 34, Theme.MUTED, 3, 3, 2)
	local door = part(icon, "Door", 50, 52, 15, 28, Theme.SLAB, 2, 4)
	part(door, "DoorGlass", 2, 2, 11, 15, Theme.COOL, 2, 1)
	shine(door, 3, 3, 3, 10)
	screw(door, 9, 19, 4)
	local window = part(icon, "DisplayWindow", 18, 49, 23, 25, Theme.SLAB, 3, 3, 2)
	part(window, "Glass", 2, 2, 19, 20, Theme.COOL, 2, 1)
	shine(window, 4, 4, 3, 11)
	local coin = Theme.coin(window, 15, "DisplayCoin")
	coin.Position = UDim2.fromOffset(5, 7)
	coin.ZIndex = 2
	Theme.shade(coin, 0.86)
	part(icon, "WindowSill", 16, 74, 27, 4, Theme.GOLD_DEEP, 2, 4, 1)
	-- Five broad alternating stripes, each with its own rounded valance.
	part(icon, "AwningOutline", 6, 24, 84, 23, Theme.INK, 5, 5, 2)
	for i = 0, 4 do
		local colour = if i % 2 == 0 then Theme.GOOD else Theme.PAPER
		local stripe = part(icon, "AwningStripe" .. i, 8 + i * 16, 25,
			16, 22, colour, 4, 6)
		Theme.shade(stripe, 0.86)
		part(stripe, "Fold", 0, 13, 16, 2,
			if i % 2 == 0 then Theme.GOOD_INK else Theme.SAND_DEEP, 0, 1)
	end
	part(icon, "AwningRail", 9, 21, 78, 5, Theme.GOOD_INK, 2, 7, 1.5)
	-- Small pig sign above the roof; no lettering needed to read as a shop.
	local sign = part(icon, "PigSign", 32, 3, 32, 19, Theme.PIG, 8, 3, 2)
	Theme.shade(sign, 0.9)
	for _, x in { 9, 21 } do
		part(sign, "Nostril", x, 6, 4, 7, Theme.PIG_DEEP, 2, 1)
	end
	shine(sign, 7, 3, 10, 2)
end

local builders = { GEAR = options, SATCHEL = stuff, BASKET = shop }

function MenuIcons.makeButton(name: string, kind: string, label: string,
	size: UDim2, parent: Instance): TextButton

	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = size
	button.Text = ""
	button.BackgroundTransparency = 1
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button:SetAttribute("AccessibleLabel", label)
	button:SetAttribute("StaticIcon", true)
	button.Parent = parent

	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.Size = UDim2.fromOffset(96, 96)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.Parent = button
	local scale = Instance.new("UIScale")
	scale.Scale = math.min(size.X.Offset, size.Y.Offset) / 96
	scale.Parent = icon
	local builder = (builders :: any)[kind]
	assert(builder, "Unknown menu icon: " .. kind)
	builder(icon)
	return button
end

return MenuIcons
