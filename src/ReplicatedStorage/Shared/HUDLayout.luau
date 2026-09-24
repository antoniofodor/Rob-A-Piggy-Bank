--!strict
-- Shared safe-area measurements for the HUD's independent modules.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HUDLayout = {}

-- THE BALANCE CARD'S SIZE, AND WHY IT IS A COPY HERE RATHER THAN A REQUIRE.
--
-- The copy that stood here went stale by 228 pixels: `bankWidth` said 404 and
-- `bankHeight` 148, describing a "medallion panel" cut down to 176 x 64 long
-- before, with nothing erroring -- because the only readers use these to keep
-- CLEAR of the card, and a guard that is too big merely wastes screen. So the
-- first-job card and the rebirth button spent a while dodging 228 pixels of
-- nothing.
--
-- REQUIRING `PiggyPanel` FIXES THAT AND COSTS THIS FILE ITS INDEPENDENCE,
-- which is the one property its own header claims: "safe-area measurements
-- for the HUD's INDEPENDENT modules". Measured rather than assumed -- the
-- require was written, and two suites that load this module for its geometry
-- (`objective` and `shopui`) died on the first line, because a layout helper
-- suddenly dragged a widget, Config and Theme in behind it.
--
-- SO THE NUMBERS STAY AND A TEST HOLDS THEM, which is the trade this project
-- already makes wherever a derivation would cost a dependency:
-- `tests/luau/lobbyboard.luau` reads both files and refuses a mismatch. A
-- comment promising two files agree is what failed before; an assertion is
-- not that comment.
local CARD_W, CARD_H, CARD_COMPACT = 176, 64, 0.64

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
		-- THE BALANCE CARD'S DRAWN SIZE, and it is in the top-LEFT corner
		-- now (designer, 2026-09-23) -- the leaderboard took the right. The
		-- design is `CHIP_W` by the plate's own 8 + 56, and `compact` draws
		-- it at `PiggyPanel.COMPACT_SCALE`. `bankScale` is applied by the
		-- CALLER, as it always was, because two of the three readers want the
		-- unscaled figure for their own arithmetic.
		bankWidth = CARD_W * (if compact then CARD_COMPACT else 1),
		bankHeight = CARD_H * (if compact then CARD_COMPACT else 1),
		menuSize = if tablet then 72 else (if view.Y < 350 then 44 else (if short then 48 else (if compact then 56 else 64))),
		menuGap = if short then 4 else 8,
		actionSize = if tablet then 76 else (if compact then 52 else 64),
	}
end

-- HOW MUCH OF THE RIGHT EDGE IS SPOKEN FOR, MARGIN INCLUDED.
--
-- This used to be read off an attribute the corner board published on every
-- fit, which was right while the roster was ours to measure. It is Roblox's
-- own player list again (see `LobbyBoardService`), and A COREGUI CANNOT BE
-- MEASURED: there is no instance to read, nothing to publish, and the player
-- can collapse or expand it without one line of this game being told.
--
-- SO IT IS A BOUND AND NEVER A MEASUREMENT, and it is deliberately generous.
-- The only reader is a card that has to stay clear of that corner, and a
-- card that stops a little short of the list costs nothing where one that
-- runs underneath it is unreadable.
--
-- CAPPED IN PIXELS AS WELL AS IN FRACTION, because the list does not grow
-- with the screen. The old fallback was 0.45 of the width, which on a wide
-- desktop reserves most of the top edge for a roster occupying a third of
-- it -- a fraction alone is the wrong shape for a thing of fixed size.
HUDLayout.PLAYER_LIST_W = 360
function HUDLayout.rightClear(gui: ScreenGui): number
	return math.max(14, math.min(HUDLayout.PLAYER_LIST_W, gui.AbsoluteSize.X * 0.34))
end

-- WHERE A SMALL ICON GOES IN THE TOPBAR ROW, BESIDE ROBLOX'S OWN BUTTONS.
--
-- `GuiService.TopbarInset` is the engine saying which part of that row is
-- yours: `Min.X` is the right edge of its own cluster -- the Roblox logo, the
-- menu and the chat pill -- and the Rect's height is the row. Measured live
-- at Rect(164, 0, 1366, 58) on a 1366-wide window, and NOT written down as a
-- number anywhere: that cluster moves with the platform, with chat being on
-- or off, and with whatever Roblox ships next. It is read on every fit, the
-- same call `jumpRect` makes by reading the live jump button rather than
-- copying TouchJump's own numbers.
--
-- WITH `IgnoreGuiInset` ON, AN OFFSET IS A SCREEN PIXEL, which is what makes
-- this Rect usable without converting anything. The ScreenGui covers the
-- whole screen and reports its `AbsolutePosition` 58 above its own origin --
-- this project's oldest gotcha -- and the other side of that is that an
-- offset of y = 0 lands on the top edge of the screen, where the Rect starts.
--
-- THE FALLBACK IS A BOUND, NOT A COPY OF TODAY'S NUMBER. It is only reached
-- on a build with no such property, and it errs to the RIGHT on purpose: an
-- icon too far in clears a cluster of any width, where one too far left sits
-- underneath it. Two numbers rather than a `Rect`, because a Rect built at
-- module scope is a constructor this file did not need -- and the suites that
-- load this module for its geometry stub Color3 and Vector2 and nothing else,
-- so it took `objective` and `shopui` down on their first line.
local FALLBACK_X, FALLBACK_BAND = 240, 58

-- The size the topbar icon is DRAWN at; `bindTopbar` scales from it, so the
-- caller builds at this and never at a number of its own.
HUDLayout.TOPBAR_SIZE = 44

function HUDLayout.topbarSlot(gui: ScreenGui): (UDim2, number)
	local left, top, band = FALLBACK_X, 0, FALLBACK_BAND
	-- READ INSIDE THE PCALL, not tested outside it: on a build without the
	-- property `live` is nil and the check itself is what throws.
	pcall(function()
		local live = GuiService.TopbarInset
		if live.Height > 4 then
			left, top, band = live.Min.X, live.Min.Y, live.Height
		end
	end)
	local size = math.clamp(band - 12, 26, HUDLayout.TOPBAR_SIZE)
	left += 10
	-- THE BALANCE CARD IS IN THIS ROW ON A COMPACT SCREEN and nowhere near it
	-- on a desktop -- `bankTop` is 8 there against 72 here -- so the slot
	-- starts at whichever of the two edges is further right. Without it the
	-- gear lands on the card at exactly the sizes with the least room to spot
	-- it, which is the failure this whole module exists to refuse.
	local m = HUDLayout.metrics(gui.AbsoluteSize)
	if m.bankTop < band then
		left = math.max(left, 14 + m.bankWidth * m.bankScale + 10)
	end
	return UDim2.fromOffset(left, top + (band - size) / 2), size
end

-- Holds a button in that slot, re-fitting when the window or the cluster
-- moves. A UIScale rather than a `Size` write, the call `bindAction` already
-- makes: whatever the button drew at its design size comes with it, and an
-- anchor of (0, 0) means scaling about the corner leaves the position exact.
function HUDLayout.bindTopbar(button: GuiObject, gui: ScreenGui)
	local scale = Instance.new("UIScale")
	scale.Name = "TopbarScale"
	scale.Parent = button
	local function fit()
		local position, size = HUDLayout.topbarSlot(gui)
		button.AnchorPoint = Vector2.zero
		button.Position = position
		scale.Scale = size / HUDLayout.TOPBAR_SIZE
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	pcall(function()
		GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(fit)
	end)
	fit()
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
		-- SIZED BY THE TILES IT HOLDS, never by a pinned three. A
		-- UIListLayout neither clips nor errors, so a fourth tile in a rail
		-- sized for three draws past the edge with nothing to say so -- the
		-- tab rail that ate two tabs. Floored at three so the rail keeps the
		-- height it has always had while the tiles are still being built.
		local tiles = 0
		for _, child in menu:GetChildren() do
			if child:IsA("GuiObject") and child.Visible then tiles += 1 end
		end
		tiles = math.max(tiles, 3)
		menu.Size = UDim2.fromOffset(66, tiles * 64 + (tiles - 1) * m.menuGap * 64 / m.menuSize)
		menu.AutomaticSize = Enum.AutomaticSize.None
		scale.Scale = m.menuSize / 64
		local layout = menu:FindFirstChildOfClass("UIListLayout")
		if layout then layout.Padding = UDim.new(0, m.menuGap * 64 / m.menuSize) end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	-- A tile added after the bind (the lobby board's is started thousands of
	-- lines later) re-fits the rail; deferred so the child's own layout
	-- properties have landed before it is counted.
	menu.ChildAdded:Connect(function() task.defer(fit) end)
	menu.ChildRemoved:Connect(function() task.defer(fit) end)
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
