--!strict
-- Small static illustrations for the boost pocket and event countdown.
local Theme = require(script.Parent.Theme)
local HUDLayout = require(script.Parent.HUDLayout)
local HUDWidgets = {}

local function part(parent: Instance, name: string, x: number, y: number,
	w: number, h: number, colour: Color3, radius: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = colour
	f.BorderSizePixel = 0
	f.Parent = parent
	Theme.corner(f, radius)
	return f
end

local function label(parent: Instance, name: string, x: number, y: number,
	w: number, h: number, size: number, text: string): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Position = UDim2.fromOffset(x, y)
	l.Size = UDim2.fromOffset(w, h)
	l.BackgroundTransparency = 1
	l.Font = Theme.FONT
	l.TextColor3 = Theme.INK
	l.TextSize = size
	l.Text = text
	l.Parent = parent
	return l
end

function HUDWidgets.boost(gui: ScreenGui): TextButton
	local root = Instance.new("TextButton")
	root.Name = "BoostPill"
	root.Size = UDim2.fromOffset(60, 44)
	root.BackgroundTransparency = 1
	root.Text = ""
	root.AutoButtonColor = false
	root.Visible = false
	root.Parent = gui
	local disc = part(root, "Token", 2, 1, 40, 40, Theme.PAPER, 20)
	Theme.outline(disc, 2, Theme.INK)
	local face = part(disc, "Face", 4, 4, 32, 32, Theme.GOLD, 16)
	Theme.shade(face, 0.86)
	label(face, "Multiplier", 0, 0, 32, 27, 19, "2x")
	label(face, "Caption", -1, 22, 34, 9, 8, "BOOST")
	local badge = part(root, "Stock", 32, 0, 26, 18, Theme.PAPER, 8)
	Theme.outline(badge, 1.5)
	label(badge, "Count", 0, 0, 26, 18, 11, "0")
	local timer = part(root, "Timer", 40, 7, 54, 29, Theme.PAPER, 10)
	Theme.outline(timer, 1.5)
	timer.Visible = false
	label(timer, "Time", 2, 0, 50, 29, 14, "0:00")
	local function fit()
		local m = HUDLayout.metrics(gui.AbsoluteSize)
		root.Position = UDim2.fromOffset(4 + math.ceil(66 * m.menuSize / 64) + 8,
			if m.compact then 80 else 146)
	end
	local connection = gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	root.Destroying:Connect(function() connection:Disconnect() end)
	fit()
	return root
end

function HUDWidgets.renderBoost(root: TextButton, count: number, seconds: number)
	local active = seconds > 0
	root.Visible = active or count > 0
	root.Size = UDim2.fromOffset(if active then 96 else 60, 44)
	root:SetAttribute("BoostActive", active)
	root:SetAttribute("Stock", count)
	local stock = root:FindFirstChild("Stock") :: Frame
	stock.Visible = not active
	local countLabel = stock:FindFirstChild("Count") :: TextLabel
	countLabel.Text = tostring(count)
	local timer = root:FindFirstChild("Timer") :: Frame
	timer.Visible = active
	local timeLabel = timer:FindFirstChild("Time") :: TextLabel
	timeLabel.Text = ("%d:%02d"):format(seconds // 60, seconds % 60)
end

function HUDWidgets.event(gui: ScreenGui): Frame
	local root = part(gui, "NextEvent", 0, 0, 176, 40, Theme.PAPER, 13)
	root.AnchorPoint = Vector2.new(1, 0)
	root.Visible = false
	Theme.outline(root, 2, Theme.INK)
	local watch = part(root, "Clock", 7, 7, 27, 27, Theme.ACORN_CAP, 14)
	Theme.outline(watch, 1.5)
	part(watch, "Crown", 10, -4, 7, 4, Theme.INK, 2)
	local face = part(watch, "Face", 4, 4, 19, 19, Theme.PAPER, 10)
	part(face, "Minute", 9, 3, 2, 8, Theme.INK, 1)
	local hand = part(face, "Hour", 9, 8, 6, 2, Theme.INK, 1)
	hand.Rotation = 25
	part(face, "Pin", 8, 8, 4, 4, Theme.INK, 2)
	local caption = label(root, "Caption", 42, 4, 122, 10, 10, "NEXT EVENT")
	caption.TextXAlignment = Enum.TextXAlignment.Left
	caption.TextColor3 = Theme.MUTED
	local time = label(root, "Time", 41, 13, 123, 21, 20, "--:--")
	time.TextXAlignment = Enum.TextXAlignment.Left
	local track = part(root, "Progress", 42, 34, 122, 3, Theme.SAND_DEEP, 2)
	local fill = part(track, "Fill", 0, 0, 0, 3, Theme.ACORN_CAP, 2)
	fill.Size = UDim2.fromScale(0, 1)
	return root
end

function HUDWidgets.renderEvent(root: Frame, seconds: number, total: number, soon: boolean)
	local left = math.max(0, math.ceil(seconds))
	local timeLabel = root:FindFirstChild("Time") :: TextLabel
	timeLabel.Text = ("%d:%02d"):format(left // 60, left % 60)
	local caption = root:FindFirstChild("Caption") :: TextLabel
	caption.Text = if soon then "GET READY" else "NEXT EVENT"
	local colour = if soon then Theme.GOLD else Theme.ACORN_CAP
	local watch = root:FindFirstChild("Clock") :: Frame
	watch.BackgroundColor3 = colour
	local track = root:FindFirstChild("Progress") :: Frame
	local fill = track:FindFirstChild("Fill") :: Frame
	fill.BackgroundColor3 = colour
	fill.Size = UDim2.fromScale(if total > 0 then math.clamp(1 - seconds / total, 0, 1) else 0, 1)
end

return HUDWidgets
