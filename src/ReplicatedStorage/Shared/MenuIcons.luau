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


local function options(icon: Frame)
	-- A single cream cog with a gold hub, readable at the smallest HUD size.
	for i = 0, 7 do
		local angle = math.rad(i * 45)
		local tooth = part(icon, "Tooth" .. i,
			48 + math.sin(angle) * 30 - 8, 48 - math.cos(angle) * 30 - 11,
			16, 22, Theme.PAPER, 4, 1, 3)
		tooth.Rotation = i * 45
	end
	part(icon, "CogBody", 19, 19, 58, 58, Theme.PAPER, 29, 2, 3)
	-- Cover the inner ends of the teeth without an extra ring of detail.
	part(icon, "CogFace", 18, 18, 60, 60, Theme.PAPER, 30, 3)
	local hub = part(icon, "GoldHub", 31, 31, 34, 34, Theme.GOLD, 17, 4, 3)
	part(hub, "Centre", 10, 10, 14, 14, Theme.INK, 7, 1)
end

local function stuff(icon: Frame)
	-- The shop's pink backpack, with a gold flap and an open loop handle.
	require(script.Parent.ShopMarks).draw(icon, "bag", 96)
end

local function shop(icon: Frame)
	-- Keep the green storefront theme, with only the large identifying shapes.
	part(icon, "Shopfront", 15, 32, 66, 53, Theme.PAPER, 6, 1, 3)
	part(icon, "Door", 51, 49, 19, 36, Theme.SLAB, 4, 2, 2)
	part(icon, "Window", 25, 50, 18, 22, Theme.COOL, 4, 2, 2)
	part(icon, "DoorHandle", 54, 66, 4, 5, Theme.GOLD, 2, 3)
	part(icon, "AwningOutline", 7, 21, 82, 24, Theme.INK, 6, 3)
	for i = 0, 4 do
		local colour = if i % 2 == 0 then Theme.GOOD else Theme.PAPER
		part(icon, "AwningStripe" .. i, 10 + i * 15, 24, 15, 18, colour, 3, 4)
	end
	part(icon, "Roof", 10, 16, 76, 10, Theme.GOOD, 4, 5, 3)
end

local function board(icon: Frame)
	-- The trophy the shop's marks already draw: a leaderboard is a cup.
	require(script.Parent.ShopMarks).draw(icon, "trophy", 96)
end

local builders = { GEAR = options, SATCHEL = stuff, BASKET = shop, TROPHY = board }

-- `fill` is the share of the button the drawing takes, and it defaults to the
-- whole of it. The rail's tiles are bare silhouettes on the world and want
-- every pixel; an icon sitting on a CHIP wants a margin inside it, and the
-- cog's teeth reach the corners of its own 96-unit square, so at 1.0 they
-- break out of any round ground. Here rather than at the call site because
-- how big its drawing is inside the button it just made is this file's
-- business, and a caller reaching into `Icon`'s UIScale to shrink it would be
-- a coupling nothing states.
function MenuIcons.makeButton(name: string, kind: string, label: string,
	size: UDim2, parent: Instance, fill: number?): TextButton

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
	scale.Scale = math.min(size.X.Offset, size.Y.Offset) / 96 * (fill or 1)
	scale.Parent = icon
	local builder = (builders :: any)[kind]
	assert(builder, "Unknown menu icon: " .. kind)
	builder(icon)
	return button
end

return MenuIcons
