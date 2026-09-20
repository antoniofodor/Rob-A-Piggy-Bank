--!strict
-- Shared safe-area measurements for the HUD's independent modules.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HUDLayout = {}

-- A TABLET IS A TOUCH SCREEN WHOSE SHORT SIDE IS OVER 500, which is the exact
-- test Roblox's own TouchJump uses to switch to its big 120-pixel jump button.
-- Borrowing the engine's threshold rather than inventing one means "we are on
-- a tablet" and "the big jump button is up" can never disagree.
--
-- An iPad in landscape (1024x768) is `compact` by width, which is right for
-- WHERE things go, and was wrong for how big they are: it got phone-sized
-- icons on a screen held at arm's length. `tablet` sizes up without touching
-- the compact arrangement.
local function isTablet(view: Vector2): boolean
	return UserInputService.TouchEnabled and math.min(view.X, view.Y) > 500
end

function HUDLayout.metrics(view: Vector2)
	local compact = view.X < 1180 or view.Y < 620
	local portrait = view.Y > view.X
	local short = view.Y < 500
	local tablet = isTablet(view)
	return {
		compact = compact,
		portrait = portrait,
		tablet = tablet,
		bankTop = if portrait then 72 else (if compact then 8 else 72),
		-- The whole piggy card, balance and all, is scaled on a tablet: the
		-- figure on it is the number this game is about and it was 23px there.
		-- 1.3 was reported too large on an iPad 10th gen (1080 x 810, compact,
		-- so 0.64 x 1.3 = 0.83 of the design): a third of the screen's width.
		bankScale = if tablet then 1.1 else 1,
		-- The medallion panel's DRAWN size, after its own compact UIScale
		-- (PiggyPanel.COMPACT_SCALE, 0.64, of a 404 x 148 / 404 x 140 design).
		bankWidth = if compact then 259 else 404,
		bankHeight = if compact then 90 else 148,
		menuSize = if tablet then 72 else (if view.Y < 350 then 44 else (if short then 48 else (if compact then 56 else 64))),
		menuGap = if short then 4 else 8,
		actionSize = if tablet then 76 else (if compact then 52 else 64),
	}
end

-- WHERE ROBLOX'S TOUCH JUMP BUTTON IS, in this gui's own offset space, or nil.
--
-- Read off the live button rather than assumed from TouchJump's numbers,
-- because those numbers are the engine's to change and a hardcoded copy
-- would go on dodging a button that had moved. Nil on a desktop, and nil
-- until the touch controls exist -- which is why callers re-fit when it
-- appears (see `watchJump`).
function HUDLayout.jumpRect(gui: ScreenGui): (Vector2?, Vector2?)
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	local touch = playerGui and playerGui:FindFirstChild("TouchGui")
	local frame = touch and touch:FindFirstChild("TouchControlFrame")
	local jump = frame and frame:FindFirstChild("JumpButton")
	if not (touch and touch:IsA("ScreenGui") and touch.Enabled and jump and jump:IsA("GuiObject") and jump.Visible) then
		return nil, nil
	end
	local at = jump.AbsolutePosition - gui.AbsolutePosition
	return at, jump.AbsoluteSize
end

-- Calls `fit` whenever the jump button appears, moves or changes size.
function HUDLayout.watchJump(fit: () -> ())
	local player = Players.LocalPlayer
	local playerGui = player and player:WaitForChild("PlayerGui", 10)
	if not playerGui then return end
	local hooked: { [Instance]: boolean } = {}
	local function hook(jump: Instance)
		if hooked[jump] or not jump:IsA("GuiObject") then return end
		hooked[jump] = true
		for _, property in { "AbsolutePosition", "AbsoluteSize", "Visible" } do
			jump:GetPropertyChangedSignal(property):Connect(function() task.defer(fit) end)
		end
		jump.Destroying:Connect(function() hooked[jump] = nil; task.defer(fit) end)
		task.defer(fit)
	end
	for _, d in playerGui:GetDescendants() do
		if d.Name == "JumpButton" then hook(d) end
	end
	playerGui.DescendantAdded:Connect(function(d)
		if d.Name == "JumpButton" then hook(d) end
	end)
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
--
-- ON A TABLET THE ROW SITS BESIDE THE JUMP BUTTON, NEVER UNDER IT. Roblox
-- draws a 120-pixel jump button 50 to 170 in from the right and 90 to 210 up
-- once the screen's short side passes 500, and this row used to end 108 up
-- and 14 in -- so on an iPad the RIDES slot sat entirely beneath it. When a
-- jump button is showing, the row's right end is placed 12 pixels left of it
-- and the row is centred on its height. On a phone the jump button is small
-- and low and the original position already clears it, so nothing moves.
function HUDLayout.actionFrame(gui: ScreenGui, index: number): (UDim2, number)
	local m = HUDLayout.metrics(gui.AbsoluteSize)
	local size = m.actionSize
	local jumpAt, jumpSize = HUDLayout.jumpRect(gui)
	if jumpAt and jumpSize and jumpSize.X > 90 then
		local right = jumpAt.X - 12 - (3 - index) * (size + 8)
		local bottom = jumpAt.Y + jumpSize.Y / 2 + size / 2
		return UDim2.fromOffset(right, bottom), size
	end
	return UDim2.new(1, -14 - (3 - index) * (size + 8), 1, -108), size
end

function HUDLayout.bindAction(button: GuiObject, gui: ScreenGui, index: number)
	local scale = Instance.new("UIScale")
	scale.Name = "ActionScale"
	scale.Parent = button
	local function fit()
		local position, size = HUDLayout.actionFrame(gui, index)
		scale.Scale = size / 68
		button.AnchorPoint = Vector2.new(1, 1)
		button.Position = position
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	task.spawn(HUDLayout.watchJump, fit)
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
