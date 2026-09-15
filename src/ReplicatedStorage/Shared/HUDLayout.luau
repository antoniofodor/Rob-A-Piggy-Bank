--!strict
-- Shared safe-area measurements for the HUD's independent modules.
local HUDLayout = {}

function HUDLayout.metrics(view: Vector2)
	local compact = view.X < 1180 or view.Y < 620
	local portrait = view.Y > view.X
	local short = view.Y < 500
	return {
		compact = compact,
		portrait = portrait,
		bankTop = if portrait then 72 else (if compact then 8 else 72),
		bankScale = 1,
		bankWidth = if compact then 252 else 420,
		bankHeight = if compact then 64 else 128,
		menuSize = if view.Y < 350 then 44 else (if short then 48 else (if compact then 56 else 64)),
		menuGap = if short then 4 else 8,
	}
end

function HUDLayout.bindMenu(menu: Frame, gui: ScreenGui)
	local scale = Instance.new("UIScale")
	scale.Parent = menu
	local function fit()
		local view = gui.AbsoluteSize
		local m = HUDLayout.metrics(view)
		menu.AnchorPoint = Vector2.zero
		menu.Position = UDim2.fromOffset(4, if m.compact then 78 else 144)
		menu.Size = UDim2.fromOffset(66, 192 + 2 * m.menuGap * 64 / m.menuSize)
		menu.AutomaticSize = Enum.AutomaticSize.None
		scale.Scale = m.menuSize / 64
		local layout = menu:FindFirstChildOfClass("UIListLayout")
		if layout then layout.Padding = UDim.new(0, m.menuGap * 64 / m.menuSize) end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
end

-- The right thumb operates these while the left thumb stays on the stick.
-- Dodge and a riding trick share a position because they are exclusive.
function HUDLayout.bindAction(button: GuiObject, gui: ScreenGui, index: number)
	local scale = Instance.new("UIScale")
	scale.Name = "ActionScale"
	scale.Parent = button
	local function fit()
		local m = HUDLayout.metrics(gui.AbsoluteSize)
		local size = if m.compact then 52 else 64
		scale.Scale = size / 68
		button.AnchorPoint = Vector2.new(1, 1)
		button.Position = UDim2.new(1, -14 - (3 - index) * (size + 8), 1, -108)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
end

function HUDLayout.bindRideExtras(picker: Frame, stance: GuiObject, gui: ScreenGui)
	local function fit()
		local m = HUDLayout.metrics(gui.AbsoluteSize)
		picker.AnchorPoint = Vector2.new(1, 1)
		picker.Position = UDim2.new(1, -14, 1, -172)
		stance.AnchorPoint = Vector2.new(1, 1)
		stance.Position = UDim2.new(1, if m.compact then -202 else -238, 1, -118)
		stance.Size = UDim2.fromOffset(118, 26)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
end

return HUDLayout
