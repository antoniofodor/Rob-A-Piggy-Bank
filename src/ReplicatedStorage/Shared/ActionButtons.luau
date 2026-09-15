--!strict
local Theme = require(script.Parent.Theme)
local Input = game:GetService("UserInputService")
local ActionButtons = {}

local function piece(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, rotation: number?): Frame
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(w, h)
	f.Position = UDim2.fromOffset(x, y)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Rotation = rotation or 0
	f.ZIndex = 3
	f.Parent = parent
	Theme.corner(f, math.min(h / 2, 8))
	Theme.outline(f, 1.5, Theme.INK)
	return f
end

function ActionButtons.icon(parent: Instance, kind: string): Frame
	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.Size = UDim2.fromOffset(68, 48)
	icon.BackgroundTransparency = 1
	icon.ZIndex = 3
	icon.Parent = parent
	if kind == "RIDE" or kind == "TRICK" then
		piece(icon, 14, 26, 42, 10, Theme.PIG, -12)
		piece(icon, 22, 35, 9, 9, Theme.GOLD)
		piece(icon, 45, 30, 9, 9, Theme.GOLD)
		piece(icon, 24, 23, 23, 3, Theme.PAPER, -12)
	else
		-- A stitched sneaker with a white sole; wind streaks distinguish Dodge.
		piece(icon, 25, 10, 19, 24, if kind == "DODGE" then Theme.COOL else Theme.PIG, -18)
		piece(icon, 25, 27, 31, 12, if kind == "DODGE" then Theme.COOL else Theme.PIG, -5)
		piece(icon, 23, 37, 35, 5, Theme.PAPER, -5)
		for i = 0, 2 do piece(icon, 29, 18 + i * 5, 13, 2, Theme.PAPER, -18) end
		if kind == "DODGE" then
			for i = 0, 2 do piece(icon, 7 + i * 3, 19 + i * 7, 14 - i * 2, 3, Theme.PAPER) end
		end
	end
	return icon
end

function ActionButtons.surface(button: TextButton)
	button.AutoButtonColor = false
	button.BackgroundColor3 = Theme.PAPER
	Theme.corner(button, 34)
	Theme.outline(button, 2, Theme.INK)
	Theme.shade(button, 0.94)
end

function ActionButtons.make(name: string, kind: string, text: string, key: string, parent: Instance): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Size = UDim2.fromOffset(68, 68)
	button.Text = ""
	button.BorderSizePixel = 0
	button.Parent = parent
	ActionButtons.surface(button)
	ActionButtons.icon(button, kind)
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, -4, 0, 16)
	label.Position = UDim2.fromOffset(2, 46)
	label.BackgroundTransparency = 1
	label.Font = Theme.FONT
	label.TextSize = 12
	label.TextColor3 = Theme.INK
	label.Text = text
	label.ZIndex = 4
	label.Parent = button
	local chip = label:Clone()
	chip.Name = "Key"
	chip.Size = UDim2.fromOffset(22, 14)
	chip.Position = UDim2.fromOffset(2, 1)
	chip.Text = key
	chip.TextSize = 10
	chip.Parent = button
	local function fitKey() chip.Visible = not Input.TouchEnabled or chip.Text == "ON" end
	chip:GetPropertyChangedSignal("Text"):Connect(fitKey)
	Input:GetPropertyChangedSignal("TouchEnabled"):Connect(fitKey)
	fitKey()
	return button
end

return ActionButtons
