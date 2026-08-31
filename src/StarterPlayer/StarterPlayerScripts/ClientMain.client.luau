--!strict
--[[
	ClientMain

	The phase-1 HUD: banked coins, a vault fill bar, and the two upgrade
	buttons.

	Everything here is display only. The client never computes a balance --
	it renders whatever the last StateUpdate said. If this file and the server
	ever disagree, the server is right by construction.

	Deliberately oversized type and chunky buttons: the whole HUD needs to be
	readable at a glance by a nine-year-old on a school laptop.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

-- Defined down in the prompt-visibility section; needed earlier so an
-- upgrade purchase can re-time the steal prompts immediately.
local refreshStealPrompts: () -> ()
local playerGui = player:WaitForChild("PlayerGui")

local GOLD = Color3.fromRGB(240, 196, 76)
local INK = Color3.fromRGB(28, 33, 44)
local PANEL = Color3.fromRGB(38, 45, 60)
local GOOD = Color3.fromRGB(86, 200, 148)
local WARN = Color3.fromRGB(232, 138, 108)

local function format(value: number): string
	local suffixes = { "", "K", "M", "B", "T" }
	local n = math.floor(value)
	local tier = 1
	while n >= 1000 and tier < #suffixes do
		n /= 1000
		tier += 1
	end
	if tier == 1 then
		return tostring(math.floor(n))
	end
	return ("%.1f%s"):format(n, suffixes[tier])
end

-- Shared render state, declared above everything that reads it: a local
-- declared *after* a function that uses it silently becomes a nil global.
local latestCoins = 0
local latestUpgrades: { [string]: any } = {}
local myLockpicks = 0

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

-- ============================================================
-- LAYOUT
-- ============================================================

local gui = Instance.new("ScreenGui")
gui.Name = "PiggyHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- Coin counter, top centre.
local coinPanel = Instance.new("Frame")
coinPanel.Size = UDim2.new(0, 260, 0, 62)
coinPanel.Position = UDim2.new(0.5, 0, 0, 16)
coinPanel.AnchorPoint = Vector2.new(0.5, 0)
coinPanel.BackgroundColor3 = INK
coinPanel.BackgroundTransparency = 0.12
coinPanel.BorderSizePixel = 0
coinPanel.Parent = gui
corner(coinPanel, 14)

local coinLabel = Instance.new("TextLabel")
coinLabel.Size = UDim2.new(1, -20, 1, 0)
coinLabel.Position = UDim2.new(0, 10, 0, 0)
coinLabel.BackgroundTransparency = 1
coinLabel.Font = Enum.Font.FredokaOne
coinLabel.TextColor3 = GOLD
coinLabel.TextScaled = true
coinLabel.Text = "0"
coinLabel.Parent = coinPanel

-- Vault fill bar, bottom centre. The bar is the important one: a full vault
-- stops earning, so this is what should pull a player back to their plot.
local vaultPanel = Instance.new("Frame")
vaultPanel.Size = UDim2.new(0, 320, 0, 74)
vaultPanel.Position = UDim2.new(0.5, 0, 1, -22)
vaultPanel.AnchorPoint = Vector2.new(0.5, 1)
vaultPanel.BackgroundColor3 = INK
vaultPanel.BackgroundTransparency = 0.12
vaultPanel.BorderSizePixel = 0
vaultPanel.Parent = gui
corner(vaultPanel, 14)

local vaultLabel = Instance.new("TextLabel")
vaultLabel.Size = UDim2.new(1, -24, 0, 26)
vaultLabel.Position = UDim2.new(0, 12, 0, 8)
vaultLabel.BackgroundTransparency = 1
vaultLabel.Font = Enum.Font.GothamBold
vaultLabel.TextColor3 = Color3.fromRGB(236, 240, 248)
vaultLabel.TextScaled = true
vaultLabel.TextXAlignment = Enum.TextXAlignment.Left
vaultLabel.Text = "Vault 0 / 0"
vaultLabel.Parent = vaultPanel

local rateLabel = Instance.new("TextLabel")
rateLabel.Size = UDim2.new(0, 110, 0, 26)
rateLabel.Position = UDim2.new(1, -122, 0, 8)
rateLabel.BackgroundTransparency = 1
rateLabel.Font = Enum.Font.GothamBold
rateLabel.TextColor3 = GOOD
rateLabel.TextScaled = true
rateLabel.TextXAlignment = Enum.TextXAlignment.Right
rateLabel.Text = "+0/s"
rateLabel.Parent = vaultPanel

local barBack = Instance.new("Frame")
barBack.Size = UDim2.new(1, -24, 0, 22)
barBack.Position = UDim2.new(0, 12, 0, 42)
barBack.BackgroundColor3 = PANEL
barBack.BorderSizePixel = 0
barBack.Parent = vaultPanel
corner(barBack, 8)

local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = GOLD
barFill.BorderSizePixel = 0
barFill.Parent = barBack
corner(barFill, 8)

-- Upgrade buttons, bottom right.
--
-- Height is AutomaticSize rather than a literal: this stack was hard-coded to
-- 128px while its children added up to 172, so the bottom button ran off the
-- screen edge -- and the button that got cut was the one that opens the shop.
-- Anchored bottom-right, so it grows upward and the bottom edge stays put.
local shop = Instance.new("Frame")
shop.Size = UDim2.new(0, 210, 0, 0)
shop.AutomaticSize = Enum.AutomaticSize.Y
shop.Position = UDim2.new(1, -18, 1, -22)
shop.AnchorPoint = Vector2.new(1, 1)
shop.BackgroundTransparency = 1
shop.Parent = gui

local shopLayout = Instance.new("UIListLayout")
shopLayout.Padding = UDim.new(0, 8)
shopLayout.SortOrder = Enum.SortOrder.LayoutOrder
shopLayout.Parent = shop

local function makeUpgradeButton(text: string, order: number): (TextButton, TextLabel)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, 58)
	button.LayoutOrder = order
	button.BackgroundColor3 = PANEL
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.FredokaOne
	button.Text = ""
	button.Parent = shop
	corner(button, 12)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -16, 0, 22)
	title.Position = UDim2.new(0, 8, 0, 7)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextColor3 = Color3.fromRGB(236, 240, 248)
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = text
	title.Parent = button

	local cost = Instance.new("TextLabel")
	cost.Size = UDim2.new(1, -16, 0, 20)
	cost.Position = UDim2.new(0, 8, 0, 31)
	cost.BackgroundTransparency = 1
	cost.Font = Enum.Font.GothamBold
	cost.TextColor3 = GOLD
	cost.TextScaled = true
	cost.TextXAlignment = Enum.TextXAlignment.Left
	cost.Text = "--"
	cost.Parent = button

	return button, cost
end

local incomeButton, incomeCost = makeUpgradeButton("Earn Faster", 1)
local capacityButton, capacityCost = makeUpgradeButton("Bigger Vault", 2)

-- Labelled SHOP, not "Defend / Rob". The old label described the two trees
-- accurately but never said it was a shop, and this button is now the only
-- way into skins and effects as well -- players looked for a shop and did
-- not recognise this as one.
local shopToggle = Instance.new("TextButton")
shopToggle.Size = UDim2.new(1, 0, 0, 46)
shopToggle.LayoutOrder = 3
shopToggle.BackgroundColor3 = Color3.fromRGB(96, 76, 132)
shopToggle.BorderSizePixel = 0
shopToggle.Font = Enum.Font.FredokaOne
shopToggle.TextScaled = true
shopToggle.TextColor3 = Color3.fromRGB(240, 236, 250)
shopToggle.Text = "SHOP  [B]"
shopToggle.Parent = shop
corner(shopToggle, 12)

-- ============================================================
-- DEFENCE / OFFENCE PANEL
-- ============================================================
--
-- Both trees are shown side by side, always, with the coin balance above
-- them. That layout is the message: every coin you spend on one column is a
-- coin you can't spend on the other, and you should feel that at the moment
-- you choose.

local DEFENCE = Color3.fromRGB(66, 148, 122)
local OFFENCE = Color3.fromRGB(184, 82, 62)

-- Sized in scale with a max, not a flat 620x420. At a fixed size the panel
-- ran off the top of the screen on short viewports -- a wide laptop window or
-- a phone held sideways, which is a lot of this audience. Scale keeps it
-- inside the screen; the constraint stops it ballooning on a big monitor.
local panel = Instance.new("Frame")
panel.Size = UDim2.new(0.92, 0, 0.86, 0)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = INK
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
corner(panel, 16)

local panelSize = Instance.new("UISizeConstraint")
panelSize.MaxSize = Vector2.new(620, 420)
panelSize.MinSize = Vector2.new(300, 240)
panelSize.Parent = panel

-- The header is three stacked bands with no overlap: title at 12, tabs at 44,
-- content from 86 down. The title used to sit at y = -2, i.e. above the
-- panel's own top edge, with the tabs starting at 22 and running through it.
local panelTitle = Instance.new("TextLabel")
panelTitle.Size = UDim2.new(1, -80, 0, 24)
panelTitle.Position = UDim2.new(0, 20, 0, 12)
panelTitle.BackgroundTransparency = 1
panelTitle.Font = Enum.Font.FredokaOne
panelTitle.TextScaled = true
panelTitle.TextXAlignment = Enum.TextXAlignment.Left
panelTitle.TextColor3 = Color3.fromRGB(236, 240, 248)
panelTitle.Text = "Pick a side"
panelTitle.Parent = panel

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 40, 0, 40)
closeButton.Position = UDim2.new(1, -50, 0, 10)
closeButton.BackgroundColor3 = PANEL
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.FredokaOne
closeButton.TextScaled = true
closeButton.TextColor3 = Color3.fromRGB(236, 240, 248)
closeButton.Text = "X"
closeButton.Parent = panel
corner(closeButton, 10)

-- Two views behind one panel: the power trees, and the collection.
local upgradesView = Instance.new("Frame")
upgradesView.Name = "UpgradesView"
upgradesView.Size = UDim2.new(1, 0, 1, -86)
upgradesView.Position = UDim2.new(0, 0, 0, 86)
upgradesView.BackgroundTransparency = 1
upgradesView.Parent = panel

local cosmeticsView = Instance.new("Frame")
cosmeticsView.Name = "CosmeticsView"
cosmeticsView.Size = UDim2.new(1, -36, 1, -100)
cosmeticsView.Position = UDim2.new(0, 18, 0, 88)
cosmeticsView.BackgroundTransparency = 1
cosmeticsView.Visible = false
cosmeticsView.Parent = panel

local function makeTab(text: string, order: number): TextButton
	local tab = Instance.new("TextButton")
	tab.Size = UDim2.new(0, 116, 0, 32)
	tab.Position = UDim2.new(0, 18 + (order - 1) * 124, 0, 44)
	tab.BackgroundColor3 = PANEL
	tab.BorderSizePixel = 0
	tab.Font = Enum.Font.FredokaOne
	-- Fixed TextSize, not TextScaled: scaled text fits each label to its own
	-- glyph widths, so "UPGRADES" and "MY PIGGY" came out visibly different
	-- sizes sitting side by side.
	tab.TextSize = 16
	tab.TextColor3 = Color3.fromRGB(236, 240, 248)
	tab.Text = text
	tab.Parent = panel
	corner(tab, 8)
	return tab
end

local upgradesTab = makeTab("UPGRADES", 1)
local cosmeticsTab = makeTab("MY PIGGY", 2)

local function showView(cosmetics: boolean)
	upgradesView.Visible = not cosmetics
	cosmeticsView.Visible = cosmetics
	upgradesTab.BackgroundColor3 = if cosmetics then PANEL else Color3.fromRGB(84, 70, 110)
	cosmeticsTab.BackgroundColor3 = if cosmetics then Color3.fromRGB(84, 70, 110) else PANEL
end

upgradesTab.Activated:Connect(function()
	showView(false)
end)
cosmeticsTab.Activated:Connect(function()
	showView(true)
end)

local columns: { [string]: Frame } = {}
for index, spec in ipairs({
	{ tree = "defense", title = "DEFEND", color = DEFENCE },
	{ tree = "offense", title = "ROB", color = OFFENCE },
}) do
	local column = Instance.new("Frame")
	column.Size = UDim2.new(0.5, -26, 1, -18)
	column.Position = UDim2.new(0.5 * (index - 1), if index == 1 then 18 else 8, 0, 0)
	column.BackgroundTransparency = 1
	column.Parent = upgradesView

	local heading = Instance.new("TextLabel")
	heading.Size = UDim2.new(1, 0, 0, 24)
	heading.BackgroundColor3 = spec.color
	heading.BorderSizePixel = 0
	heading.Font = Enum.Font.FredokaOne
	heading.TextScaled = true
	heading.TextColor3 = Color3.fromRGB(255, 255, 255)
	heading.Text = spec.title
	heading.Parent = column
	corner(heading, 8)

	local list = Instance.new("Frame")
	list.Name = "List"
	list.Size = UDim2.new(1, 0, 1, -32)
	list.Position = UDim2.new(0, 0, 0, 32)
	list.BackgroundTransparency = 1
	list.Parent = column

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	columns[spec.tree] = list
end

local upgradeRows: { [string]: { button: TextButton, title: TextLabel, cost: TextLabel } } = {}

local function ensureRow(key: string, info: any)
	local existing = upgradeRows[key]
	if existing then
		return existing
	end

	local parent = columns[info.tree]
	local accent = if info.tree == "defense" then DEFENCE else OFFENCE

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, 66)
	button.LayoutOrder = info.order
	button.BackgroundColor3 = PANEL
	button.BorderSizePixel = 0
	button.Font = Enum.Font.FredokaOne
	button.Text = ""
	button.Parent = parent
	corner(button, 10)

	local stripe = Instance.new("Frame")
	stripe.Size = UDim2.new(0, 4, 1, -12)
	stripe.Position = UDim2.new(0, 6, 0, 6)
	stripe.BackgroundColor3 = accent
	stripe.BorderSizePixel = 0
	stripe.Parent = button
	corner(stripe, 2)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -22, 0, 20)
	title.Position = UDim2.new(0, 16, 0, 6)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(236, 240, 248)
	title.Text = info.name
	title.Parent = button

	local blurb = Instance.new("TextLabel")
	blurb.Size = UDim2.new(1, -22, 0, 16)
	blurb.Position = UDim2.new(0, 16, 0, 25)
	blurb.BackgroundTransparency = 1
	blurb.Font = Enum.Font.Gotham
	blurb.TextScaled = true
	blurb.TextXAlignment = Enum.TextXAlignment.Left
	blurb.TextColor3 = Color3.fromRGB(150, 162, 178)
	blurb.Text = info.blurb
	blurb.Parent = button

	local cost = Instance.new("TextLabel")
	cost.Size = UDim2.new(1, -22, 0, 18)
	cost.Position = UDim2.new(0, 16, 0, 43)
	cost.BackgroundTransparency = 1
	cost.Font = Enum.Font.GothamBold
	cost.TextScaled = true
	cost.TextXAlignment = Enum.TextXAlignment.Left
	cost.TextColor3 = GOLD
	cost.Text = ""
	cost.Parent = button

	button.Activated:Connect(function()
		Remotes.get("UpgradeRequest"):FireServer(key)
	end)

	local row = { button = button, title = title, cost = cost, blurb = blurb }
	upgradeRows[key] = row
	return row
end

-- ============================================================
-- COSMETICS VIEW
-- ============================================================

-- One scroll for the whole collection, split into labelled sections.
--
-- Effects used to live in a fixed-height row pinned to the bottom with a
-- horizontal list layout. Six effects need 688px of row and the panel is
-- 584px wide, so the last one and a half were clipped with no way to reach
-- them -- there was no scrollbar because a Frame does not scroll.
--
-- A single vertical scroll also means adding a third category later costs a
-- header and a grid rather than another fight for fixed space.
local collection = Instance.new("ScrollingFrame")
collection.Size = UDim2.new(1, 0, 1, 0)
collection.BackgroundTransparency = 1
collection.BorderSizePixel = 0
collection.ScrollBarThickness = 6
collection.CanvasSize = UDim2.new()
collection.AutomaticCanvasSize = Enum.AutomaticSize.Y
collection.Parent = cosmeticsView

local collectionLayout = Instance.new("UIListLayout")
collectionLayout.FillDirection = Enum.FillDirection.Vertical
collectionLayout.Padding = UDim.new(0, 10)
collectionLayout.SortOrder = Enum.SortOrder.LayoutOrder
collectionLayout.Parent = collection

local function sectionHeader(text: string, order: number)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -10, 0, 18)
	label.LayoutOrder = order
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(150, 162, 178)
	label.Text = text
	label.Parent = collection
end

-- AutomaticSize on the wrapper is what lets the grid inside push the scroll
-- canvas taller as rows are added, instead of clipping at a fixed height.
local function sectionGrid(order: number): Frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, -10, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundTransparency = 1
	frame.LayoutOrder = order
	frame.Parent = collection

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0, 130, 0, 62)
	grid.CellPadding = UDim2.new(0, 8, 0, 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = frame
	return frame
end

sectionHeader("PIGGY SKINS", 1)
local skinsGridFrame = sectionGrid(2)
sectionHeader("EFFECTS", 3)
local effectsGridFrame = sectionGrid(4)

local cosmeticButtons: { [string]: { button: TextButton, title: TextLabel, sub: TextLabel, swatch: Frame? } } = {}

-- One builder for both grids. A skin entry gets a colour swatch; an effect
-- entry doesn't, since its colour lives in the particles rather than the tile.
local function ensureCosmeticButton(kind: string, key: string, info: any)
	local existing = cosmeticButtons[kind .. ":" .. key]
	if existing then
		return existing
	end

	local button = Instance.new("TextButton")
	-- No explicit Size: UIGridLayout drives cell dimensions for both kinds.
	button.LayoutOrder = info.order or 99
	button.BackgroundColor3 = PANEL
	button.BorderSizePixel = 0
	button.Font = Enum.Font.FredokaOne
	button.Text = ""
	button.Parent = if kind == "effect" then effectsGridFrame else skinsGridFrame
	corner(button, 10)

	local swatch: Frame? = nil
	if kind == "skin" then
		swatch = Instance.new("Frame")
		swatch.Size = UDim2.new(0, 14, 1, -16)
		swatch.Position = UDim2.new(0, 8, 0, 8)
		swatch.BackgroundColor3 = info.body or Color3.new(1, 1, 1)
		swatch.BorderSizePixel = 0
		swatch.Parent = button
		corner(swatch, 4)
	end

	local left = if kind == "skin" then 28 else 10

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -left - 8, 0, 22)
	title.Position = UDim2.new(0, left, 0, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(236, 240, 248)
	title.Text = info.name
	title.Parent = button

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -left - 8, 0, 20)
	sub.Position = UDim2.new(0, left, 0, 32)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamBold
	sub.TextScaled = true
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextColor3 = GOLD
	sub.Text = ""
	sub.Parent = button

	button.Activated:Connect(function()
		Remotes.get("CosmeticRequest"):FireServer(kind, key)
	end)

	local entry = { button = button, title = title, sub = sub, swatch = swatch }
	cosmeticButtons[kind .. ":" .. key] = entry
	return entry
end

local latestCosmetics: { skins: any, effects: any }? = nil

local function renderCosmetics()
	if not latestCosmetics then
		return
	end

	for kind, collection in pairs({ skin = latestCosmetics.skins, effect = latestCosmetics.effects }) do
		for key, info in pairs(collection) do
			local entry = ensureCosmeticButton(kind, key, info)
			entry.title.Text = info.name

			if info.equipped then
				entry.sub.Text = "EQUIPPED"
				entry.sub.TextColor3 = Color3.fromRGB(120, 226, 170)
				entry.button.BackgroundColor3 = Color3.fromRGB(46, 88, 62)
			elseif info.unlocked then
				entry.sub.Text = "Tap to wear"
				entry.sub.TextColor3 = Color3.fromRGB(150, 162, 178)
				entry.button.BackgroundColor3 = PANEL
			elseif info.unlockRebirths then
				entry.sub.Text = ("%d rebirths"):format(info.unlockRebirths)
				entry.sub.TextColor3 = Color3.fromRGB(190, 150, 220)
				entry.button.BackgroundColor3 = Color3.fromRGB(58, 46, 74)
			else
				entry.sub.Text = format(info.cost)
				entry.sub.TextColor3 = GOLD
				entry.button.BackgroundColor3 = if latestCoins >= info.cost
					then Color3.fromRGB(58, 84, 62)
					else PANEL
			end
		end
	end
end

Remotes.get("CosmeticState").OnClientEvent:Connect(function(snapshot)
	latestCosmetics = snapshot
	renderCosmetics()
end)

shopToggle.Activated:Connect(function()
	panel.Visible = not panel.Visible
end)
closeButton.Activated:Connect(function()
	panel.Visible = false
end)

-- B opens the shop, Escape closes it. The button stays the primary route --
-- most of the audience is on a touchscreen and will never press a key.
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.B then
		panel.Visible = not panel.Visible
	elseif input.KeyCode == Enum.KeyCode.Escape and panel.Visible then
		panel.Visible = false
	end
end)

-- Rebirth button. Hidden entirely until you can afford it -- a permanently
-- greyed-out button you can't use for three hours is just a nag.
local rebirthButton = Instance.new("TextButton")
rebirthButton.Size = UDim2.new(0, 220, 0, 52)
rebirthButton.Position = UDim2.new(0.5, 0, 0, 96)
rebirthButton.AnchorPoint = Vector2.new(0.5, 0)
rebirthButton.BackgroundColor3 = Color3.fromRGB(150, 96, 190)
rebirthButton.BorderSizePixel = 0
rebirthButton.Font = Enum.Font.FredokaOne
rebirthButton.TextScaled = true
rebirthButton.TextColor3 = Color3.fromRGB(255, 250, 240)
rebirthButton.Text = "REBIRTH!"
rebirthButton.Visible = false
rebirthButton.Parent = gui
corner(rebirthButton, 12)

rebirthButton.Activated:Connect(function()
	Remotes.get("RebirthRequest"):FireServer()
end)

-- Friend bonus chip, only shown when it's actually earning you something.
local friendChip = Instance.new("TextLabel")
friendChip.Size = UDim2.new(0, 150, 0, 30)
friendChip.Position = UDim2.new(0, 18, 0, 18)
friendChip.BackgroundColor3 = Color3.fromRGB(46, 96, 78)
friendChip.BorderSizePixel = 0
friendChip.Font = Enum.Font.GothamBold
friendChip.TextScaled = true
friendChip.TextColor3 = Color3.fromRGB(140, 226, 190)
friendChip.Text = ""
friendChip.Visible = false
friendChip.Parent = gui
corner(friendChip, 8)

-- Carry banner. Only visible while holding stolen loot, and deliberately
-- loud -- a thief should feel exposed, because they are.
local carryBanner = Instance.new("Frame")
carryBanner.Size = UDim2.new(0, 340, 0, 52)
carryBanner.Position = UDim2.new(0.5, 0, 0, 140)
carryBanner.AnchorPoint = Vector2.new(0.5, 0)
carryBanner.BackgroundColor3 = Color3.fromRGB(150, 58, 42)
carryBanner.BorderSizePixel = 0
carryBanner.Visible = false
carryBanner.Parent = gui
corner(carryBanner, 12)

local carryLabel = Instance.new("TextLabel")
carryLabel.Size = UDim2.new(1, -18, 1, 0)
carryLabel.Position = UDim2.new(0, 9, 0, 0)
carryLabel.BackgroundTransparency = 1
carryLabel.Font = Enum.Font.FredokaOne
carryLabel.TextColor3 = GOLD
carryLabel.TextScaled = true
carryLabel.Text = ""
carryLabel.Parent = carryBanner

-- Toast, top centre under the coin counter.
local toast = Instance.new("TextLabel")
toast.Size = UDim2.new(0, 420, 0, 40)
toast.Position = UDim2.new(0.5, 0, 0, 88)
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.BackgroundColor3 = INK
toast.BackgroundTransparency = 1
toast.BorderSizePixel = 0
toast.Font = Enum.Font.GothamBold
toast.TextColor3 = Color3.fromRGB(236, 240, 248)
toast.TextTransparency = 1
toast.TextScaled = true
toast.Text = ""
toast.Parent = gui
corner(toast, 10)

-- ============================================================
-- BEHAVIOUR
-- ============================================================

local toastToken = 0

local function showToast(message: string, kind: string)
	toastToken += 1
	local token = toastToken

	toast.Text = message
	toast.TextColor3 = if kind == "good" then GOOD elseif kind == "warn" then WARN else Color3.fromRGB(236, 240, 248)

	local fadeIn = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(toast, fadeIn, { TextTransparency = 0, BackgroundTransparency = 0.2 }):Play()

	task.delay(2.4, function()
		if token ~= toastToken then
			return
		end
		local fadeOut = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(toast, fadeOut, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
	end)
end

local function renderUpgrades()
	for key, info in pairs(latestUpgrades) do
		local row = ensureRow(key, info)
		row.title.Text = ("%s  Lv %d/%d"):format(info.name, info.level, info.max)
		-- Re-set every render: the dog's blurb names its next breed, so it
		-- changes with the level rather than being fixed at row creation.
		row.blurb.Text = info.blurb

		if info.level >= info.max then
			row.cost.Text = "MAXED"
			row.button.BackgroundColor3 = Color3.fromRGB(52, 62, 78)
		else
			row.cost.Text = format(info.cost)
			local affordable = latestCoins >= info.cost
			row.button.BackgroundColor3 = if affordable then Color3.fromRGB(58, 84, 62) else PANEL
		end
	end
	panelTitle.Text = ("%s coins"):format(format(latestCoins))
	renderCosmetics()
end

local function render(state: any)
	coinLabel.Text = format(state.coins)
	latestCoins = state.coins
	renderUpgrades()

	vaultLabel.Text = ("Vault  %s / %s"):format(format(state.vault), format(state.capacity))
	rateLabel.Text = ("+%s/s"):format(format(state.rate))

	local ratio = if state.capacity > 0 then math.clamp(state.vault / state.capacity, 0, 1) else 0
	TweenService:Create(
		barFill,
		TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(ratio, 1) }
	):Play()

	-- Turn the bar red at capacity: income has stopped, go bank it.
	barFill.BackgroundColor3 = if ratio >= 0.999 then WARN else GOLD

	if state.incomeLevel >= state.maxIncome then
		incomeCost.Text = "MAX"
	else
		incomeCost.Text = ("%s  -  Lv %d"):format(format(state.incomeCost), state.incomeLevel)
	end

	if state.capacityLevel >= state.maxCapacity then
		capacityCost.Text = "MAX"
	else
		capacityCost.Text = ("%s  -  Lv %d"):format(format(state.capacityCost), state.capacityLevel)
	end

	rebirthButton.Visible = state.rebirthReady == true
	if state.rebirthReady then
		rebirthButton.Text = ("REBIRTH  %d★"):format(state.rebirths + 1)
	end

	local bonus = state.friendBonus or 0
	friendChip.Visible = bonus > 0
	if bonus > 0 then
		friendChip.Text = ("Friends  +%d%%"):format(math.floor(bonus * 100))
	end

	local canBuyIncome = state.coins >= state.incomeCost and state.incomeLevel < state.maxIncome
	local canBuyCapacity = state.coins >= state.capacityCost and state.capacityLevel < state.maxCapacity
	incomeButton.BackgroundColor3 = if canBuyIncome then Color3.fromRGB(58, 84, 62) else PANEL
	capacityButton.BackgroundColor3 = if canBuyCapacity then Color3.fromRGB(58, 84, 62) else PANEL
end

Remotes.get("StateUpdate").OnClientEvent:Connect(render)
Remotes.get("Notify").OnClientEvent:Connect(showToast)

Remotes.get("UpgradeState").OnClientEvent:Connect(function(snapshot)
	latestUpgrades = snapshot
	myLockpicks = (snapshot.lockpicks and snapshot.lockpicks.level) or 0
	renderUpgrades()
	if refreshStealPrompts then
		refreshStealPrompts()
	end
end)

-- Revenge marker. Built client-side from a server ping so only the victim
-- sees it -- everyone else watching a red beacon over one plot would turn a
-- private grudge into a public pile-on.
local activeRevenge: BillboardGui? = nil

Remotes.get("RevengeMarker").OnClientEvent:Connect(function(plotModel: Model, thiefName: string, duration: number)
	if activeRevenge then
		activeRevenge:Destroy()
		activeRevenge = nil
	end
	if not plotModel or not plotModel.PrimaryPart then
		return
	end

	local marker = Instance.new("BillboardGui")
	marker.Name = "RevengeMarker"
	marker.Size = UDim2.new(0, 220, 0, 60)
	marker.StudsOffset = Vector3.new(0, 26, 0)
	marker.AlwaysOnTop = true
	marker.Adornee = plotModel.PrimaryPart
	marker.Parent = playerGui

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 122, 96)
	text.TextStrokeTransparency = 0.15
	text.Text = ("%s ROBBED YOU\nGET THEM BACK"):format(thiefName)
	text.Parent = marker

	activeRevenge = marker

	task.delay(duration, function()
		if activeRevenge == marker then
			marker:Destroy()
			activeRevenge = nil
		end
	end)
end)

Remotes.get("CarryUpdate").OnClientEvent:Connect(function(amount: number)
	carryBanner.Visible = amount > 0
	if amount > 0 then
		carryLabel.Text = ("CARRYING %s  -  RUN HOME!"):format(format(amount))
	end
end)

-- ============================================================
-- PROMPT VISIBILITY
-- ============================================================
--
-- Each piggy carries both a "Bank Coins" and a "Steal Coins" prompt. Which
-- one you see depends on whether the plot is yours. Doing this on the client
-- is purely presentational -- the server re-checks ownership on every
-- trigger, so an exploiter re-enabling the wrong prompt gets nothing.

local boundPlots: { { model: Instance, collect: ProximityPrompt, steal: ProximityPrompt } } = {}

-- Re-times our own steal prompts so the bar we watch matches the time we
-- actually need: the owner's locks against our lockpicks.
--
-- Both values are read fresh -- the lock level from the plot's replicated
-- attribute, our lockpicks from the last UpgradeState -- and the duration is
-- recomputed from scratch. Nothing is cached, so a lock bought mid-session
-- lands immediately instead of being overwritten by a stale local baseline.
--
-- This is presentation only. The server times the real hold and rejects
-- anything faster than we're entitled to, so tampering here only ever costs
-- the client.
function refreshStealPrompts()
	for _, entry in ipairs(boundPlots) do
		local lockLevel = entry.model:GetAttribute("LockLevel") or 0
		entry.steal.HoldDuration = Config.getStealHold(lockLevel, myLockpicks)
	end
end

local function bindPlot(plotModel: Instance)
	local piggy = plotModel:WaitForChild("PiggyBank", 10)
	if not piggy then
		return
	end
	local body = piggy:WaitForChild("Body", 10) :: BasePart?
	if not body then
		return
	end

	local collectPrompt = body:WaitForChild("CollectPrompt", 10) :: ProximityPrompt
	local stealPrompt = body:WaitForChild("StealPrompt", 10) :: ProximityPrompt

	local function refresh()
		local ownerId = plotModel:GetAttribute("OwnerUserId")
		local isMine = ownerId == player.UserId
		local isOwned = ownerId ~= nil

		collectPrompt.Enabled = isMine
		stealPrompt.Enabled = isOwned and not isMine
	end

	plotModel:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh)
	refresh()

	table.insert(boundPlots, { model = plotModel, collect = collectPrompt, steal = stealPrompt })
	plotModel:GetAttributeChangedSignal("LockLevel"):Connect(refreshStealPrompts)
	refreshStealPrompts()
end

-- The leaderboard's SurfaceGui is built on the server and frequently never
-- gets drawn -- it stays blank indefinitely, while toggling Enabled with no
-- visual change at all makes it appear immediately. Reordering the build and
-- moving the board closer both failed to fix it on their own; nudging it once
-- from the client, after everything has replicated, is what actually works.
--
-- Purely cosmetic, and it costs one property write per player per session.
task.spawn(function()
	local world = workspace:WaitForChild("World", 30)
	local board = world and world:WaitForChild("Leaderboard", 30)
	local surface = board and board:FindFirstChildOfClass("SurfaceGui")
	if not surface then
		return
	end
	task.wait(1)
	surface.Enabled = false
	task.wait()
	surface.Enabled = true
end)

task.spawn(function()
	local plots = workspace:WaitForChild("Plots", 30)
	if not plots then
		return
	end
	for _, plotModel in ipairs(plots:GetChildren()) do
		task.spawn(bindPlot, plotModel)
	end
	plots.ChildAdded:Connect(function(child)
		task.spawn(bindPlot, child)
	end)
end)

incomeButton.Activated:Connect(function()
	Remotes.get("PurchaseRequest"):FireServer("income")
end)

capacityButton.Activated:Connect(function()
	Remotes.get("PurchaseRequest"):FireServer("capacity")
end)
