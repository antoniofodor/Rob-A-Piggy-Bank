--!strict
-- Capacity HUD. All balances come from StateUpdate; only the fill and ETA
-- are derived here. Keeping the widget here also frees ClientMain registers.
local TweenService = game:GetService("TweenService")
local Config = require(script.Parent.Config)
local Theme = require(script.Parent.Theme)

local PiggyPanel = {}
local WIDTH, HEIGHT = 420, 128

local function shape(parent: Instance, name: string, x: number, y: number,
	w: number, h: number, colour: Color3, radius: number, z: number?): Frame

	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = UDim2.fromOffset(x, y)
	frame.Size = UDim2.fromOffset(w, h)
	frame.BackgroundColor3 = colour
	frame.BorderSizePixel = 0
	frame.ZIndex = z or 1
	Theme.corner(frame, radius)
	frame.Parent = parent
	return frame
end

local function label(parent: Instance, name: string, text: string, x: number,
	y: number, w: number, h: number, size: number, colour: Color3): TextLabel

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = name
	textLabel.Position = UDim2.fromOffset(x, y)
	textLabel.Size = UDim2.fromOffset(w, h)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Theme.FONT
	textLabel.TextSize = size
	textLabel.TextColor3 = colour
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.Text = text
	textLabel.Parent = parent
	return textLabel
end

-- A front-facing pig, drawn at its final HUD size. Its face never changes
-- colour with the balance: gold belongs to the adjacent capacity gauge.
local function buildPig(parent: Instance)
	local medallion = shape(parent, "Pig", 13, 17, 94, 94, Theme.SAND_DEEP, 47)
	Theme.outline(medallion, 2, Theme.MUTED)
	Theme.shade(medallion, 0.9)
	local ring = shape(medallion, "InnerRing", 5, 5, 84, 84, Theme.PAPER, 42)
	Theme.outline(ring, 1, Theme.PAPER_DEEP)
	for _, x in { 23, 55 } do
		local foot = shape(medallion, "Foot", x, 76, 15, 14, Theme.PIG_DEEP, 6, 2)
		Theme.outline(foot, 1.5, Theme.MUTED)
	end
	for _, x in { 12, 62 } do
		local ear = shape(medallion, "Ear", x, 13, 22, 29, Theme.PIG, 8, 3)
		ear.Rotation = if x == 12 then -24 else 24
		Theme.outline(ear, 1.5, Theme.PIG_DEEP)
		shape(ear, "InnerEar", 5, 5, 12, 18, Theme.PIG_DEEP, 5)
	end
	local head = shape(medallion, "Head", 12, 24, 71, 60, Theme.PIG, 29, 4)
	Theme.outline(head, 1.5, Theme.PIG_DEEP)
	Theme.shade(head, 0.9)
	local sheen = shape(head, "ForeheadShine", 15, 5, 27, 7, Theme.PAPER, 5)
	sheen.BackgroundTransparency = 0.65
	for _, x in { 17, 49 } do
		local eye = shape(head, "Eye", x, 20, 7, 11, Theme.INK, 4)
		shape(eye, "Catchlight", 1, 1, 3, 4, Theme.PAPER, 2)
	end
	for _, x in { 7, 56 } do
		local cheek = shape(head, "Cheek", x, 35, 10, 5, Theme.PIG_DEEP, 4)
		cheek.BackgroundTransparency = 0.55
	end
	local snout = shape(head, "Snout", 22, 32, 29, 21, Theme.PIG, 11, 2)
	Theme.outline(snout, 1.5, Theme.PIG_DEEP)
	Theme.shade(snout, 0.85)
	for _, x in { 7, 18 } do
		shape(snout, "Nostril", x, 7, 4, 8, Theme.PIG_DEEP, 3)
	end
	-- Small smile beneath the snout, with its upper half hidden by the snout.
	local smile = shape(head, "Smile", 31, 48, 12, 8, Theme.PIG_DEEP, 6)
	shape(smile, "SmileInset", 0, -3, 12, 8, Theme.PIG, 6)
	shape(medallion, "CoinSlot", 36, 20, 26, 5, Theme.INK, 3, 5)
	local coin = Theme.coin(medallion, 27, "Coin")
	coin.Position = UDim2.fromOffset(37, -5)
	coin.Rotation = 14
	coin.ZIndex = 6
	-- Use a neutral shading pass: gradients multiply their base colour.
	Theme.shade(coin, 0.83)
end

function PiggyPanel.new(gui: ScreenGui)
	local root = shape(gui, "PiggyPanel", 0, 0, WIDTH, HEIGHT, Theme.PAPER, 25, 1)
	root.AnchorPoint = Vector2.new(1, 0)
	root.Position = UDim2.new(1, -18, 0, 72)
	Theme.outline(root, 2.5, Theme.MUTED)
	Theme.shade(root, 0.95)
	local scale = Instance.new("UIScale")
	scale.Parent = root

	-- Sibling shadow: a child would draw over its own card in Sibling mode.
	local shadow = shape(gui, "PiggyPanelShadow", 0, 0, WIDTH, HEIGHT, Theme.INK, 25, 0)
	shadow.AnchorPoint = root.AnchorPoint
	shadow.BackgroundTransparency = 0.6
	local shadowScale = Instance.new("UIScale")
	shadowScale.Parent = shadow
	local rim = shape(root, "InsetRim", 4, 4, WIDTH - 8, HEIGHT - 8, Theme.PAPER, 22)
	rim.BackgroundTransparency = 1
	Theme.outline(rim, 1, Theme.PAPER)
	buildPig(root)

	local title = label(root, "Title", "PIGGY BANK", 119, 12, 170, 18, 14, Theme.MUTED)
	local coins = label(root, "Coins", "0", 118, 30, 104, 38, 34, Theme.INK)
	local capacity = label(root, "Capacity", "/ 0", 224, 43, 77, 20, 15, Theme.MUTED)
	local ratePill = shape(root, "IncomePill", 305, 36, 99, 28,
		Theme.PAPER:Lerp(Theme.GOOD, 0.15), 14)
	Theme.outline(ratePill, 1, Theme.GOOD_INK:Lerp(Theme.PAPER, 0.6))
	local rate = label(ratePill, "Rate", "+0/s", 4, 0, 91, 28, 15, Theme.GOOD_INK)
	rate.TextXAlignment = Enum.TextXAlignment.Center

	local track = shape(root, "Track", 119, 76, 283, 22, Theme.SAND_DEEP, 11)
	Theme.outline(track, 1.5, Theme.MUTED)
	Theme.shade(track, 0.91)
	-- The rounded leading edge follows the balance, including when spending
	-- moves it backwards. Hide at zero so an empty pig has no gold sliver.
	local fill = shape(track, "Fill", 0, 0, 0, 22, Theme.GOLD, 11)
	fill.Visible = false
	Theme.shade(fill, 0.88)
	local highlight = shape(fill, "Highlight", 7, 3, 269, 4, Theme.PAPER, 3)
	highlight.Size = UDim2.new(1, -14, 0, 4)
	highlight.BackgroundTransparency = 0.58
	local percent = label(track, "Percent", "0%", 0, 0, 283, 22, 15, Theme.INK)
	percent.ZIndex = 3
	percent.TextXAlignment = Enum.TextXAlignment.Center
	local status = label(root, "Amount", "Waiting for your piggy...", 119, 103, 283, 18, 13, Theme.MUTED)
	status.Font = Theme.FONT_BODY
	status.TextXAlignment = Enum.TextXAlignment.Center

	local acorns = shape(root, "AcornBalance", 0, HEIGHT + 8, 146, 34, Theme.PAPER, 12)
	Theme.outline(acorns, 1.5, Theme.MUTED)
	local acornIcon = Theme.acorn(acorns, 26)
	acornIcon.Position = UDim2.fromOffset(4, 3)
	local acornCount = label(acorns, "Count", "0", 34, 0, 105, 34, 17, Theme.INK)
	acornCount.TextTruncate = Enum.TextTruncate.AtEnd

	local function layout()
		local viewport = gui.AbsoluteSize
		local metrics = require(script.Parent.HUDLayout).metrics(viewport)
		local compact = metrics.compact
		local factor = metrics.bankScale
		local height, width = metrics.bankHeight, metrics.bankWidth
		local top = metrics.bankTop
		root.Size = UDim2.fromOffset(width, height)
		root.Position = UDim2.new(1, -14, 0, top)
		acorns.Position = UDim2.fromOffset(0, height + 8)
		acorns.Size = UDim2.fromOffset(if compact then 108 else 146, if compact then 26 else 34)
		acornIcon.Size = UDim2.fromOffset(if compact then 22 else 26, if compact then 22 else 26)
		acornIcon.Position = UDim2.fromOffset(4, if compact then 2 else 3)
		acornCount.Position = UDim2.fromOffset(if compact then 30 else 34, 0)
		acornCount.Size = UDim2.new(1, if compact then -36 else -40, 1, 0)
		acornCount.TextSize = if compact then 14 else 17
		shadow.Size = root.Size
		rim.Size = UDim2.fromOffset(width - 8, height - 8)
		title.Visible = not compact
		status.Visible = not compact
		local pigScale = root.Pig:FindFirstChildOfClass("UIScale")
		if not pigScale then pigScale = Instance.new("UIScale"); pigScale.Parent = root.Pig end
		pigScale.Scale = if compact then 0.45 else 1
		root.Pig.Position = UDim2.fromOffset(if compact then 8 else 13, if compact then 12 else 17)
		coins.Position = UDim2.fromOffset(if compact then 58 else 118, if compact then 5 else 30)
		coins.Size = UDim2.fromOffset(if compact then 90 else 104, if compact then 28 else 38)
		coins.TextSize = if compact then 23 else 34
		capacity.Position = UDim2.fromOffset(if compact then 153 else 224, if compact then 13 else 43)
		capacity.Size = UDim2.fromOffset(if compact then 89 else 77, 20)
		capacity.TextSize = if compact then 12 else 15
		ratePill.Position = UDim2.fromOffset(if compact then 58 else 305, if compact then 37 else 36)
		ratePill.Size = UDim2.fromOffset(if compact then 82 else 99, if compact then 18 else 28)
		rate.Size = UDim2.new(1, -8, 1, 0)
		rate.TextSize = if compact then 11 else 15
		track.Position = UDim2.fromOffset(if compact then 148 else 119, if compact then 38 else 76)
		track.Size = UDim2.fromOffset(if compact then 94 else 283, if compact then 16 else 22)
		percent.Size = UDim2.fromScale(1, 1)
		percent.TextSize = if compact then 11 else 15
		status.Position = UDim2.fromOffset(119, 103)
		scale.Scale = factor
		shadowScale.Scale = factor
		shadow.Position = root.Position + UDim2.fromOffset(0, 5 * factor)
		-- These chips are built later by ClientMain and Wanted. Derive their
		-- positions from this card so resizing never makes the column overlap.
		for name, offset in { NextEvent = 0, Wanted = 42 } do
			local chip = gui:FindFirstChild(name)
			if chip and chip:IsA("GuiObject") then
				chip.Position = UDim2.new(1, -14, 0, top + height * factor + 8 + (if compact then offset * 0.7 else offset))
				local chipScale = chip:FindFirstChildOfClass("UIScale")
				if not chipScale then chipScale = Instance.new("UIScale"); chipScale.Parent = chip end
				chipScale.Scale = if compact then 0.75 else 1
			end
		end
	end
	layout()
	local layoutConnection = gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	local childConnection = gui.ChildAdded:Connect(function(child)
		if child.Name == "NextEvent" or child.Name == "Wanted" then
			task.defer(layout)
		end
	end)
	local tween: Tween? = nil
	local lastRatio: number? = nil
	root.Destroying:Connect(function()
		layoutConnection:Disconnect()
		childConnection:Disconnect()
		if tween then tween:Cancel() end
		shadow:Destroy()
	end)

	local controller = {}
	function controller:setAcorns(amount: number)
		local balance = math.max(0, math.floor(amount))
		acornCount.Text = Config.formatCoins(balance)
		acorns:SetAttribute("Balance", balance)
	end
	function controller:render(state: any)
		local balance = math.max(0, state.coins or 0)
		local limit = math.max(0, state.capacity or 0)
		local income = math.max(0, state.rate or 0)
		local ratio = if limit > 0 then math.clamp(balance / limit, 0, 1) else 0
		local full = state.full == true or (limit > 0 and balance >= limit)
		coins.Text = Config.formatCoins(balance)
		capacity.Text = "/ " .. Config.formatCoins(limit)
		rate.Text = ("+%s/s"):format(Config.formatCoins(income))
		-- A nearly full pig must never claim 100% before accrual stops.
		percent.Text = if full then "100%" else ("%d%%"):format(math.floor(ratio * 100))
		if full then
			status.Text = "FULL " .. utf8.char(0x00B7) .. " Spend to earn again"
		elseif income > 0 and limit > balance then
			local seconds = math.ceil((limit - balance) / income)
			status.Text = if seconds >= 3600
				then ("Full in %dh %02dm"):format(seconds // 3600, (seconds % 3600) // 60)
				else ("Full in %dm %02ds"):format(seconds // 60, seconds % 60)
		else
			status.Text = "Income paused"
		end
		if lastRatio ~= ratio then
			if tween then tween:Cancel() end
			fill.Visible = ratio > 0
			highlight.Visible = ratio >= 0.08
			-- Initial hydration is immediate; subsequent earning/spending animates.
			if lastRatio == nil then
				fill.Size = UDim2.fromScale(ratio, 1)
			else
				tween = TweenService:Create(fill,
					TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Size = UDim2.fromScale(ratio, 1) })
				tween:Play()
			end
			lastRatio = ratio
		end
	end
	return controller
end

return PiggyPanel
