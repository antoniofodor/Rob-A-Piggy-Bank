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
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BoneModel = require(ReplicatedStorage.Shared.BoneModel)
local PigGear = require(ReplicatedStorage.Shared.PigGear)
local RideModel = require(ReplicatedStorage.Shared.RideModel)
local GadgetModel = require(ReplicatedStorage.Shared.GadgetModel)
local HomeModel = require(ReplicatedStorage.Shared.HomeModel)
local ThiefModel = require(ReplicatedStorage.Shared.ThiefModel)

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
-- Tabs are a vertical icon rail down the left edge.
--
-- The old horizontal text tabs cost a whole band of panel height and only fit
-- two before wrapping. A rail costs one narrow column, scales to as many tabs
-- as there are icons, and a glyph is faster to re-find than a word for a
-- player who is not reading carefully.
local RAIL_W = 54

local rail = Instance.new("Frame")
rail.Name = "TabRail"
rail.Size = UDim2.new(0, RAIL_W, 1, -52)
rail.Position = UDim2.new(0, 10, 0, 44)
rail.BackgroundTransparency = 1
rail.Parent = panel

local railLayout = Instance.new("UIListLayout")
railLayout.Padding = UDim.new(0, 8)
railLayout.SortOrder = Enum.SortOrder.LayoutOrder
railLayout.Parent = rail

-- Every view occupies the same area to the right of the rail, so adding a tab
-- never moves anything already on screen.
local VIEW_X = RAIL_W + 20
local function makeView(name: string): Frame
	local v = Instance.new("Frame")
	v.Name = name
	v.Size = UDim2.new(1, -VIEW_X - 16, 1, -56)
	v.Position = UDim2.new(0, VIEW_X, 0, 46)
	v.BackgroundTransparency = 1
	v.Visible = false
	v.Parent = panel
	return v
end

local upgradesView = makeView("UpgradesView")
local cosmeticsView = makeView("CosmeticsView")
local houseView = makeView("HouseView")
local decorView = makeView("DecorView")
local gearView = makeView("GearView")
local gadgetView = makeView("GadgetView")
local rideView = makeView("RideView")
local collectionView = makeView("CollectionView")
upgradesView.Visible = true

local TAB_ACTIVE = Color3.fromRGB(96, 76, 132)

local tabs: { { button: TextButton, view: Frame, title: string } } = {}

local function selectTab(index: number)
	for i, tab in ipairs(tabs) do
		local on = i == index
		tab.view.Visible = on
		tab.button.BackgroundColor3 = if on then TAB_ACTIVE else PANEL
	end
end

local function makeTab(icon: string, title: string, view: Frame, order: number)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, 48)
	button.LayoutOrder = order
	button.BackgroundColor3 = PANEL
	button.BorderSizePixel = 0
	button.Font = Enum.Font.FredokaOne
	button.TextSize = 24
	button.TextColor3 = Color3.fromRGB(236, 240, 248)
	button.Text = icon
	button.Parent = rail
	corner(button, 10)

	local index = #tabs + 1
	tabs[index] = { button = button, view = view, title = title }
	button.Activated:Connect(function()
		selectTab(index)
	end)
end

makeTab("⚔", "Defend / Rob", upgradesView, 1)
makeTab("🐷", "Your Piggy", cosmeticsView, 2)
makeTab("🏠", "Your House", houseView, 3)
makeTab("🌳", "Decorations", decorView, 4)
makeTab("🦴", "Bones", gearView, 5)
makeTab("🧹", "Gadgets", gadgetView, 6)
makeTab("🛹", "Rides", rideView, 7)
makeTab("🎁", "Collection", collectionView, 8)

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

-- Each tab gets its own scroll, built by the same helper.
--
-- Sections inside a scroll exist because a fixed-height row cannot grow:
-- effects once lived in a pinned row with a horizontal layout, and six of them
-- needed 688px against a 584px panel, so the last one and a half were clipped
-- with no scrollbar to reach them. A scroll with AutomaticCanvasSize grows
-- instead, and a new category costs a header and a grid.
local function makeScroll(parent: Frame): (ScrollingFrame, (string, number) -> (), (number) -> Frame)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, 0)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	local function header(text: string, order: number)
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -10, 0, 18)
		label.LayoutOrder = order
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextSize = 13
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Color3.fromRGB(150, 162, 178)
		label.Text = text
		label.Parent = scroll
	end

	-- AutomaticSize on the wrapper is what lets the grid inside push the
	-- canvas taller as rows are added, instead of clipping at a fixed height.
	-- `cell` is optional: the default 130x62 suits a swatch and two lines of
	-- text, but a tile carrying a rendered 3D icon needs room for the icon
	-- AND the text beside it.
	local function grid(order: number, cell: UDim2?): Frame
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, -10, 0, 0)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = order
		frame.Parent = scroll

		local g = Instance.new("UIGridLayout")
		g.CellSize = cell or UDim2.new(0, 130, 0, 62)
		g.CellPadding = UDim2.new(0, 8, 0, 8)
		g.SortOrder = Enum.SortOrder.LayoutOrder
		g.Parent = frame
		return frame
	end

	return scroll, header, grid
end

local _, piggyHeader, piggyGrid = makeScroll(cosmeticsView)
piggyHeader("PIGGY SKINS", 1)
local skinsGridFrame = piggyGrid(2)
piggyHeader("EFFECTS", 3)
local effectsGridFrame = piggyGrid(4)

local _, houseHeader, houseGrid = makeScroll(houseView)
houseHeader("MOVE UP THE STREET", 1)
local housesGridFrame = houseGrid(2)

local gadgetScroll, gadgetHeader, gadgetGrid = makeScroll(gadgetView)
gadgetHeader("THROW AT A ROBBER", 1)
local gadgetsGridFrame = gadgetGrid(2, UDim2.new(0, 164, 0, 66))

do
	-- Says what they are FOR, and the one limit that otherwise reads as a bug.
	--
	-- "Nobody is running off with anything" is the message a player gets almost
	-- every time they first try one, because almost always nobody is being
	-- robbed. Left unexplained that is indistinguishable from a broken item.
	local how = Instance.new("TextLabel")
	how.Size = UDim2.new(1, -10, 0, 112)
	how.LayoutOrder = 3
	how.BackgroundTransparency = 1
	how.Font = Enum.Font.Gotham
	how.TextSize = 13
	how.TextWrapped = true
	how.TextXAlignment = Enum.TextXAlignment.Left
	how.TextYAlignment = Enum.TextYAlignment.Top
	how.TextColor3 = Color3.fromRGB(130, 142, 158)
	how.Text = "These only work on somebody who is CARRYING STOLEN COINS right "
		.. "now -- you cannot throw one at anybody else, ever.\n\nThey slow a "
		.. "robber down so you can catch up. They never make them drop the "
		.. "coins: you still have to reach them and tag them. Thieves with maxed "
		.. "Speed Boots run as fast as you do, and this is how you catch those."
	how.Parent = gadgetScroll
end

gadgetHeader("AT HOME", 4)
local homeGridFrame = gadgetGrid(5, UDim2.new(0, 164, 0, 66))

gadgetHeader("SNEAKING", 6)
local stealthGridFrame = gadgetGrid(7, UDim2.new(0, 164, 0, 66))

do
	local how = Instance.new("TextLabel")
	how.Size = UDim2.new(1, -10, 0, 92)
	how.LayoutOrder = 8
	how.BackgroundTransparency = 1
	how.Font = Enum.Font.Gotham
	how.TextSize = 13
	how.TextWrapped = true
	how.TextXAlignment = Enum.TextXAlignment.Left
	how.TextYAlignment = Enum.TextYAlignment.Top
	how.TextColor3 = Color3.fromRGB(130, 142, 158)
	how.Text = "These are for ROBBING, not defending. Hide as a wheelie bin while "
		.. "you wait for somebody's piggy to fill or their guard dog to go off "
		.. "duty -- but move, or grab the loot, and you are a person again. The "
		.. "raincoat shrugs off one plunger or bubblegum; a Zapper still gets you."
	how.Parent = gadgetScroll
end

local rideScroll, rideHeader, rideGrid = makeScroll(rideView)
rideHeader("GET AROUND", 1)
-- Wide cells: these tiles carry a rendered 3D model AND three lines of text,
-- where the default 130x62 was drawn for a colour swatch and two.
local ridesGridFrame = rideGrid(2, UDim2.new(0, 200, 0, 76))

-- The rule, stated once, where somebody will read it before they spend four
-- and a half million coins on something that turns itself off.
--
-- It has to be here rather than only in a refusal toast, because the first
-- time a board vanishes is the moment a player decides the thing they bought
-- is broken -- and by then they are mid-robbery and not reading.
local rideNote = Instance.new("TextLabel")
rideNote.Size = UDim2.new(1, -10, 0, 62)
rideNote.LayoutOrder = 3
rideNote.BackgroundTransparency = 1
rideNote.Font = Enum.Font.Gotham
rideNote.TextSize = 12
rideNote.TextWrapped = true
rideNote.TextXAlignment = Enum.TextXAlignment.Left
rideNote.TextYAlignment = Enum.TextYAlignment.Top
rideNote.TextColor3 = Color3.fromRGB(150, 162, 178)
rideNote.Text = "Rides are for the street. You hop off at any garden gate, and "
	.. "you cannot ride while you are carrying loot or while somebody is robbing "
	.. "you -- a getaway is always run on foot."
rideNote.Parent = rideScroll

-- Decorations: the shell is here so the tab is real and the shape of the
-- feature is visible. Slots and items land next.
local decorScroll, decorHeader, decorGrid = makeScroll(decorView)
decorHeader("FRONT LAWN", 1)
local lawnGridFrame = decorGrid(2) -- filled by the decor items in phase 2
decorHeader("DRIVEWAY", 3)
local drivewayGridFrame = decorGrid(4)
decorHeader("BY THE KERB", 5)
local vergeGridFrame = decorGrid(6)

-- The collection: every accessory in the game, owned or not.
--
-- Locked items are shown, not hidden. A grid of question marks tells a player
-- there is more without telling them what, and "what" is the entire reason to
-- roll again. The silhouette is the advert.
local collectionScroll, collectionHeader, collectionGrid = makeScroll(collectionView)

local rollButton = Instance.new("TextButton")
rollButton.Size = UDim2.new(1, -10, 0, 62)
rollButton.LayoutOrder = 0
rollButton.BackgroundColor3 = Color3.fromRGB(150, 96, 190)
rollButton.BorderSizePixel = 0
rollButton.Font = Enum.Font.FredokaOne
rollButton.TextSize = 26
rollButton.TextColor3 = Color3.fromRGB(255, 250, 240)
rollButton.Text = "ROLL"
rollButton.Parent = collectionScroll
corner(rollButton, 12)

local rollNote = Instance.new("TextLabel")
rollNote.Size = UDim2.new(1, -10, 0, 34)
rollNote.LayoutOrder = 1
rollNote.BackgroundTransparency = 1
rollNote.Font = Enum.Font.Gotham
rollNote.TextSize = 13
rollNote.TextWrapped = true
rollNote.TextXAlignment = Enum.TextXAlignment.Left
rollNote.TextYAlignment = Enum.TextYAlignment.Top
rollNote.TextColor3 = Color3.fromRGB(130, 142, 158)
rollNote.Text = ""
rollNote.Parent = collectionScroll

rollButton.Activated:Connect(function()
	Remotes.get("CosmeticRequest"):FireServer("roll", "")
end)

-- Slots in their configured order. ACCESSORY_SLOTS is a dictionary, and pairs
-- has no defined order, so the sections would otherwise shuffle themselves
-- between sessions.
local slotOrder: { string } = {}
for slotKey in pairs(Config.ACCESSORY_SLOTS) do
	table.insert(slotOrder, slotKey)
end
table.sort(slotOrder, function(a, b)
	return Config.ACCESSORY_SLOTS[a].order < Config.ACCESSORY_SLOTS[b].order
end)

local slotGrids: { [string]: Frame } = {}
for i, slotKey in ipairs(slotOrder) do
	collectionHeader(Config.ACCESSORY_SLOTS[slotKey].label, 1 + i * 2)
	slotGrids[slotKey] = collectionGrid(2 + i * 2, UDim2.new(0, 164, 0, 66))
end

-- Bones: the only repeat purchase in the game, so a tile never reads as
-- "owned" -- it shows what you are holding and stays buyable forever.
local gearScroll, gearHeader, gearGrid = makeScroll(gearView)
gearHeader("THROW TO A GUARD DOG", 1)
local bonesGridFrame = gearGrid(2, UDim2.new(0, 164, 0, 66))

do
	local how = Instance.new("TextLabel")
	how.Size = UDim2.new(1, -10, 0, 96)
	how.LayoutOrder = 3
	how.BackgroundTransparency = 1
	how.Font = Enum.Font.Gotham
	how.TextSize = 13
	how.TextWrapped = true
	how.TextXAlignment = Enum.TextXAlignment.Left
	how.TextYAlignment = Enum.TextYAlignment.Top
	how.TextColor3 = Color3.fromRGB(130, 142, 158)
	how.Text = "Get within throwing distance of a dog and press G, or tap a bone "
		.. "in the corner of the screen. It trots over, eats it, and goes to "
		.. "its kennel. \n\nBigger dogs are harder to buy off, and only a Golden "
		.. "Bone will stop one that has already seen you."
	how.Parent = gearScroll
end

gearHeader("YOUR OWN DOG", 4)
local treatGridFrame = gearGrid(5, UDim2.new(0, 164, 0, 66))

do
	local how = Instance.new("TextLabel")
	how.Size = UDim2.new(1, -10, 0, 74)
	how.LayoutOrder = 6
	how.BackgroundTransparency = 1
	how.Font = Enum.Font.Gotham
	how.TextSize = 13
	how.TextWrapped = true
	how.TextXAlignment = Enum.TextXAlignment.Left
	how.TextYAlignment = Enum.TextYAlignment.Top
	how.TextColor3 = Color3.fromRGB(130, 142, 158)
	how.Text = "Use one before you head out. Your dog stays awake and refuses "
		.. "cheap bones, and its collar glows so robbers can see it is not worth "
		.. "trying. A Golden Bone still gets past -- this makes robbing you "
		.. "expensive, not impossible."
	how.Parent = gearScroll
end

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
	button.Parent = if kind == "effect" then effectsGridFrame
		elseif kind == "house" then housesGridFrame
		elseif kind == "decorLawn" then lawnGridFrame
		elseif kind == "decorDriveway" then drivewayGridFrame
		elseif kind == "decorVerge" then vergeGridFrame
		else skinsGridFrame
	corner(button, 10)

	local swatch: Frame? = nil
	if kind ~= "effect" then
		swatch = Instance.new("Frame")
		swatch.Size = UDim2.new(0, 14, 1, -16)
		swatch.Position = UDim2.new(0, 8, 0, 8)
		swatch.BackgroundColor3 = info.body or info.walls or info.swatch or Color3.new(1, 1, 1)
		swatch.BorderSizePixel = 0
		swatch.Parent = button
		corner(swatch, 4)
	end

	local left = if kind == "effect" then 10 else 28

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
		-- Lawn and driveway are separate GRIDS but one server-side kind; the
		-- item's own zone decides where it lands.
		local wire = if kind:sub(1, 5) == "decor" then "decor" else kind
		Remotes.get("CosmeticRequest"):FireServer(wire, key)
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

	-- Decorations. Bought once and placed automatically, so a tile is simply
	-- owned or for sale -- there is no equip state to show.
	for key, info in pairs(latestCosmetics.decor or {}) do
		local kind = if info.zone == "driveway" then "decorDriveway"
			elseif info.zone == "verge" then "decorVerge"
			else "decorLawn"
		local entry = ensureCosmeticButton(kind, key, info)
		entry.title.Text = info.name

		if info.owned and info.placed then
			entry.sub.Text = "OUT - tap to store"
			entry.sub.TextColor3 = Color3.fromRGB(120, 226, 170)
			entry.button.BackgroundColor3 = Color3.fromRGB(46, 88, 62)
		elseif info.owned then
			entry.sub.Text = "Stored - tap to place"
			entry.sub.TextColor3 = Color3.fromRGB(150, 162, 178)
			entry.button.BackgroundColor3 = Color3.fromRGB(46, 54, 68)
		else
			entry.sub.Text = format(info.cost)
			entry.sub.TextColor3 = GOLD
			entry.button.BackgroundColor3 = if latestCoins >= info.cost
				then Color3.fromRGB(58, 84, 62)
				else PANEL
		end
	end

	-- Houses are bought as a ladder and worn as a shelf: only the next tier is
	-- ever for sale, but every one already bought stays available to move back
	-- into for free. Which is why an owned tile reads as an action ("Tap to
	-- move in") rather than as a state -- "Moved out" described the situation
	-- accurately and gave no hint that tapping would undo it.
	for index, info in ipairs(latestCosmetics.houses or {}) do
		local entry = ensureCosmeticButton("house", tostring(index), info)
		entry.title.Text = info.name

		if info.current then
			entry.sub.Text = "YOU LIVE HERE"
			entry.sub.TextColor3 = Color3.fromRGB(120, 226, 170)
			entry.button.BackgroundColor3 = Color3.fromRGB(46, 88, 62)
		elseif info.owned then
			entry.sub.Text = "Tap to move in"
			entry.sub.TextColor3 = Color3.fromRGB(150, 162, 178)
			entry.button.BackgroundColor3 = Color3.fromRGB(46, 54, 68)
		elseif info.forSale then
			entry.sub.Text = format(info.cost)
			entry.sub.TextColor3 = GOLD
			entry.button.BackgroundColor3 = if latestCoins >= info.cost
				then Color3.fromRGB(58, 84, 62)
				else PANEL
		else
			entry.sub.Text = "Locked"
			entry.sub.TextColor3 = Color3.fromRGB(110, 120, 134)
			entry.button.BackgroundColor3 = Color3.fromRGB(38, 43, 54)
		end
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

-- ============================================================
-- BONES
-- ============================================================
--
-- Bones are the one thing here that is CONSUMED, so the usual owned/equipped
-- states do not apply: a tile is buyable forever and shows a running count
-- instead. Which is why they get their own builder rather than a sixth branch
-- inside ensureCosmeticButton.

local latestBones: { [string]: any }? = nil

-- The bar only exists while you are holding something. An empty row of greyed
-- slots is permanent clutter on a phone screen. Two renderers feed it now, so
-- each records whether IT has anything and the bar takes the union -- a single
-- `Visible = anyHeld` in either one would hide the other's slots.
local boneHeld = false
local gadgetHeld = false
local homeHeld = false
local stealthHeld = false

local boneTiles: { [string]: { title: TextLabel, sub: TextLabel, count: TextLabel, button: TextButton } } = {}
local boneSlots: { [string]: { button: TextButton, label: TextLabel, hotkey: TextLabel } } = {}

-- Quick-throw slots, stacked above the upgrade buttons in the bottom-right.
-- Reuses that frame's list layout, so it grows upward and never has to know
-- what else is on the HUD.
--
-- Carries BOTH bones and gadgets. They are the same gesture -- hold a stock,
-- pick one, throw it at something -- and two separate bars for one verb would
-- cost twice the screen on a phone to teach a distinction the game does not
-- actually make.
--
-- Rides are deliberately NOT here. Mounting is automatic and, by design, a
-- ride cannot be used during a chase, so a slot for one would be inert at
-- exactly the moment this bar matters. Choosing a board is a taste decision
-- made once, and taste decisions live in the shop.
local hotBar = Instance.new("Frame")
hotBar.Name = "HotBar"
hotBar.Size = UDim2.new(1, 0, 0, 54)
hotBar.LayoutOrder = 0
hotBar.BackgroundTransparency = 1
hotBar.Visible = false
hotBar.Parent = shop

local hotBarLayout = Instance.new("UIListLayout")
hotBarLayout.FillDirection = Enum.FillDirection.Horizontal
hotBarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
hotBarLayout.Padding = UDim.new(0, 6)
hotBarLayout.SortOrder = Enum.SortOrder.LayoutOrder
hotBarLayout.Parent = hotBar

local function refreshHotBar()
	hotBar.Visible = boneHeld or gadgetHeld or homeHeld or stealthHeld
end

local function throwBone(key: string)
	Remotes.get("BoneThrow"):FireServer(key)
end

local function throwGadget(key: string)
	Remotes.get("GadgetThrow"):FireServer(key)
end

-- One key per item, FIXED, never renumbered.
--
-- The obvious alternative -- number the slots you can currently see, 1..n --
-- reshuffles every time a stock runs out, so the key that threw a plunger a
-- moment ago now throws a zapper worth twenty-two thousand coins. A slot is
-- hidden when empty and its number simply goes unused; muscle memory survives.
local HOTKEYS = {
	bone = { key = Enum.KeyCode.One, label = "1" },
	steak = { key = Enum.KeyCode.Two, label = "2" },
	golden = { key = Enum.KeyCode.Three, label = "3" },
	plunger = { key = Enum.KeyCode.Four, label = "4" },
	gum = { key = Enum.KeyCode.Five, label = "5" },
	zapper = { key = Enum.KeyCode.Six, label = "6" },
	treat = { key = Enum.KeyCode.Seven, label = "7" },
	sprinkler = { key = Enum.KeyCode.Eight, label = "8" },
	disguise = { key = Enum.KeyCode.Nine, label = "9" },
	raincoat = { key = Enum.KeyCode.Zero, label = "0" },
}

-- A rendered 3D bone in a ViewportFrame, from the same model that gets thrown.
--
-- Not an image asset: a decal would be one more third-party ID to get moderated
-- away (see SOUNDS), and it could not stay in step with the geometry. A viewport
-- renders the real item, and a new bone style needs no art at all.
--
-- A viewport lights its contents from its own Ambient and LightDirection and
-- ignores every light in the scene, so the model is asked for WITHOUT its glow
-- and the framing is done here.
local spinners: { { model: Model, tilt: CFrame } } = {}

local function makeModelIcon(parent: GuiObject, model: Model, size: UDim2, position: UDim2, spin: boolean): ViewportFrame
	local vp = Instance.new("ViewportFrame")
	vp.Size = size
	vp.Position = position
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(196, 194, 200)
	vp.LightColor = Color3.fromRGB(255, 250, 238)
	vp.LightDirection = Vector3.new(-0.35, -1, -0.55)
	vp.Parent = parent

	model.Parent = vp

	local camera = Instance.new("Camera")
	camera.Parent = vp
	vp.CurrentCamera = camera

	-- Re-centred on its VISUAL centre, and only here.
	--
	-- A model's pivot is its authored origin, because that is the point world
	-- placement has to be right about -- a hat is authored at its brim so it
	-- can sit on a head. An icon wants the opposite: the middle of the shape,
	-- so it spins in place and the camera has a fixed thing to aim at. The two
	-- are different points, so this copy moves itself and leaves the contract
	-- everyone else depends on alone.
	local box, extent = model:GetBoundingBox()
	model:TranslateBy(-box.Position)
	model.WorldPivot = CFrame.new()

	-- Framed from the model's own bounding box rather than a hardcoded
	-- distance, so an item with a different footprint fills the tile the same
	-- way instead of overflowing it or sitting lost in the middle.
	local dist = extent.Magnitude * 0.95
	camera.CFrame = CFrame.lookAt(
		Vector3.new(dist * 0.42, dist * 0.5, dist * 0.72), Vector3.zero)

	local tilt = CFrame.Angles(math.rad(-12), math.rad(-25), math.rad(8))
	model:PivotTo(tilt)

	if spin then
		table.insert(spinners, { model = model, tilt = tilt })
	end

	return vp
end

local function ensureBoneTile(key: string, info: any)
	local existing = boneTiles[key]
	if existing then
		return existing
	end

	local button = Instance.new("TextButton")
	button.LayoutOrder = info.order or 99
	button.BackgroundColor3 = PANEL
	button.BorderSizePixel = 0
	button.Font = Enum.Font.FredokaOne
	button.Text = ""
	button.Parent = bonesGridFrame
	corner(button, 10)

	makeModelIcon(button, BoneModel.build(key, false), UDim2.new(0, 48, 0, 50), UDim2.new(0, 4, 0, 8), true)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -62, 0, 22)
	title.Position = UDim2.new(0, 56, 0, 10)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(236, 240, 248)
	title.Text = info.name
	title.Parent = button

	-- Held count sits ON the icon, bottom corner, exactly as it does on the
	-- quick-throw slot -- so the number means the same thing in both places.
	-- Kept out of the title line because a badge on the right squeezed "Juicy
	-- Steak" down to something unreadable.
	local count = Instance.new("TextLabel")
	count.Size = UDim2.new(0, 42, 0, 16)
	count.Position = UDim2.new(0, 4, 0, 42)
	count.BackgroundTransparency = 1
	count.Font = Enum.Font.FredokaOne
	count.TextScaled = true
	count.TextXAlignment = Enum.TextXAlignment.Right
	count.TextColor3 = Color3.fromRGB(150, 240, 190)
	count.TextStrokeTransparency = 0.2
	count.TextStrokeColor3 = Color3.fromRGB(18, 20, 26)
	count.Text = ""
	count.Parent = button

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -62, 0, 20)
	sub.Position = UDim2.new(0, 56, 0, 36)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamBold
	sub.TextScaled = true
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextColor3 = GOLD
	sub.Text = ""
	sub.Parent = button

	button.Activated:Connect(function()
		Remotes.get("GearRequest"):FireServer(key)
	end)

	local entry = { title = title, sub = sub, count = count, button = button }
	boneTiles[key] = entry
	return entry
end

local function ensureBoneSlot(key: string, info: any)
	local existing = boneSlots[key]
	if existing then
		return existing
	end

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 58, 1, 0)
	button.LayoutOrder = info.order or 99
	-- Dark tile behind the icon, not the bone's own colour. The colour is in
	-- the rendered model now; painting the tile the same colour as the thing
	-- standing on it flattens the one part that has to read at a glance.
	button.BackgroundColor3 = PANEL
	button.BackgroundTransparency = 0.15
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.FredokaOne
	button.Text = ""
	button.Parent = hotBar
	corner(button, 10)

	-- Static, unlike the shop tiles. These sit on the HUD for the whole
	-- session, and something turning in the corner of the screen forever pulls
	-- the eye away from the plot the player is meant to be watching.
	makeModelIcon(button, BoneModel.build(key, false), UDim2.new(1, -6, 1, -6), UDim2.new(0, 3, 0, 3), false)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -6, 0, 18)
	label.Position = UDim2.new(0, 3, 1, -20)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.TextColor3 = Color3.fromRGB(255, 252, 244)
	-- Stroked, because it is drawn over a rendered model whose brightness
	-- changes with the bone: cream, red and gold all sit behind this number.
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(18, 20, 26)
	label.Text = ""
	label.Parent = button

	local hotkey = Instance.new("TextLabel")
	hotkey.Size = UDim2.new(0, 22, 0, 14)
	hotkey.Position = UDim2.new(0, 3, 0, 2)
	hotkey.BackgroundTransparency = 1
	hotkey.Font = Enum.Font.GothamBold
	hotkey.TextScaled = true
	hotkey.TextXAlignment = Enum.TextXAlignment.Left
	hotkey.TextColor3 = Color3.fromRGB(180, 226, 255)
	hotkey.TextStrokeTransparency = 0.3
	hotkey.TextStrokeColor3 = Color3.fromRGB(18, 20, 26)
	hotkey.Text = ""
	hotkey.Parent = button

	button.Activated:Connect(function()
		throwBone(key)
	end)

	local entry = { button = button, label = label, hotkey = hotkey }
	boneSlots[key] = entry
	return entry
end

-- The bone G throws: the cheapest one held.
--
-- G deliberately never reaches for the expensive bone. A key that silently
-- spends a Golden when a Dog Bone would have done is a key players learn not
-- to press; picking a specific bone is what tapping its slot is for.
local function cheapestHeldBone(): string?
	local best: string? = nil
	local bestCost = math.huge
	for key, info in pairs(latestBones or {}) do
		if info.held > 0 and info.cost < bestCost then
			best, bestCost = key, info.cost
		end
	end
	return best
end

local function renderBones()
	if not latestBones then
		return
	end

	local anyHeld = false

	for key, info in pairs(latestBones) do
		local tile = ensureBoneTile(key, info)
		tile.title.Text = info.name
		tile.count.Text = if info.held > 0 then ("x%d"):format(info.held) else ""
		tile.sub.Text = ("%ds  %s"):format(info.nap, format(info.cost))
		tile.button.BackgroundColor3 = if latestCoins >= info.cost
			then Color3.fromRGB(58, 84, 62)
			else PANEL

		local slot = ensureBoneSlot(key, info)
		slot.button.Visible = info.held > 0
		slot.label.Text = tostring(info.held)
		-- Every slot shows its NUMBER, bones included.
		--
		-- This used to show "G" on the cheapest bone instead, which left the bar
		-- reading G,2,3,4,5,6 -- so the one key a player could work out by
		-- looking was the one that was not advertised anywhere. G still throws
		-- the cheapest bone, and the Bones tab still says so; it is a shortcut
		-- on top of the numbering rather than a hole in it.
		local hot = HOTKEYS[key]
		slot.hotkey.Text = if hot then hot.label else ""
		if info.held > 0 then
			anyHeld = true
		end
	end

	boneHeld = anyHeld
	refreshHotBar()
end

-- ONE Heartbeat loop for every shop icon, the same way animated skins are
-- driven. A connection per ViewportFrame would be three loops doing one
-- rotation each, and a fourth the moment another bone is added.
--
-- Only turns while the shop is actually open. These icons are offscreen for
-- almost the whole session, and rendering three viewports every frame to
-- animate something nobody is looking at is pure waste.
-- ============================================================
-- GADGETS
-- ============================================================

local latestGadgets: { [string]: any }? = nil
local gadgetTiles: { [string]: { title: TextLabel, sub: TextLabel, count: TextLabel, button: TextButton } } = {}
local gadgetSlots: { [string]: { button: TextButton, label: TextLabel, hotkey: TextLabel } } = {}

local function ensureGadgetTile(key: string, info: any)
	local existing = gadgetTiles[key]
	if existing then
		return existing
	end

	local button = Instance.new("TextButton")
	button.LayoutOrder = info.order or 99
	button.BackgroundColor3 = PANEL
	button.BorderSizePixel = 0
	button.Font = Enum.Font.FredokaOne
	button.Text = ""
	button.Parent = gadgetsGridFrame
	corner(button, 10)

	makeModelIcon(button, GadgetModel.build(key, false), UDim2.new(0, 48, 0, 50), UDim2.new(0, 4, 0, 8), true)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -62, 0, 20)
	title.Position = UDim2.new(0, 56, 0, 6)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(236, 240, 248)
	title.Text = info.name
	title.Parent = button

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -62, 0, 18)
	sub.Position = UDim2.new(0, 56, 0, 28)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamBold
	sub.TextSize = 12
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextColor3 = GOLD
	sub.Text = ""
	sub.Parent = button

	local count = Instance.new("TextLabel")
	count.Size = UDim2.new(1, -62, 0, 16)
	count.Position = UDim2.new(0, 56, 0, 46)
	count.BackgroundTransparency = 1
	count.Font = Enum.Font.GothamBold
	count.TextSize = 12
	count.TextXAlignment = Enum.TextXAlignment.Left
	count.TextColor3 = Color3.fromRGB(150, 162, 178)
	count.Text = ""
	count.Parent = button

	button.Activated:Connect(function()
		Remotes.get("GadgetRequest"):FireServer(key)
	end)

	local entry = { title = title, sub = sub, count = count, button = button }
	gadgetTiles[key] = entry
	return entry
end

local function ensureGadgetSlot(key: string, info: any)
	local existing = gadgetSlots[key]
	if existing then
		return existing
	end

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 58, 1, 0)
	-- After the bones in the bar, so the two kinds never interleave as stock
	-- comes and goes. Bones are thrown at dogs and gadgets at people; keeping
	-- them grouped means the hand knows which half it is reaching for.
	button.LayoutOrder = 10 + (info.order or 99)
	button.BackgroundColor3 = PANEL
	button.BackgroundTransparency = 0.15
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.FredokaOne
	button.Text = ""
	button.Parent = hotBar
	corner(button, 10)

	-- Static, like the bone slots: something turning in the corner of the
	-- screen forever pulls the eye off the plot the player should be watching.
	makeModelIcon(button, GadgetModel.build(key, false), UDim2.new(1, -6, 1, -6), UDim2.new(0, 3, 0, 3), false)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -6, 0, 18)
	label.Position = UDim2.new(0, 3, 1, -20)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.TextColor3 = Color3.fromRGB(255, 252, 244)
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(18, 20, 26)
	label.Text = ""
	label.Parent = button

	local hotkey = Instance.new("TextLabel")
	hotkey.Size = UDim2.new(0, 22, 0, 14)
	hotkey.Position = UDim2.new(0, 3, 0, 2)
	hotkey.BackgroundTransparency = 1
	hotkey.Font = Enum.Font.GothamBold
	hotkey.TextScaled = true
	hotkey.TextXAlignment = Enum.TextXAlignment.Left
	hotkey.TextColor3 = Color3.fromRGB(255, 190, 190)
	hotkey.TextStrokeTransparency = 0.3
	hotkey.TextStrokeColor3 = Color3.fromRGB(18, 20, 26)
	hotkey.Text = ""
	hotkey.Parent = button

	button.Activated:Connect(function()
		throwGadget(key)
	end)

	local entry = { button = button, label = label, hotkey = hotkey }
	gadgetSlots[key] = entry
	return entry
end

local function renderGadgets()
	if not latestGadgets then
		return
	end

	local anyHeld = false
	for key, info in pairs(latestGadgets) do
		local tile = ensureGadgetTile(key, info)
		tile.title.Text = info.name
		-- What it does, in the two numbers that matter: how much it takes off
		-- them and for how long. A full stop is called out separately, because
		-- "stops them" is a different promise from "slows them" and one number
		-- cannot make both.
		tile.sub.Text = if info.stops
			then ("STOPS them  -  %s"):format(format(info.cost))
			else ("-%d%% for %.1fs  -  %s"):format(info.slowPercent, info.duration, format(info.cost))
		tile.count.Text = ("range %d   %s"):format(
			info.range, if info.held > 0 then ("you have %d"):format(info.held) else "")
		tile.button.BackgroundColor3 = if latestCoins >= info.cost
			then Color3.fromRGB(58, 84, 62)
			else PANEL

		local slot = ensureGadgetSlot(key, info)
		slot.button.Visible = info.held > 0
		slot.label.Text = tostring(info.held)
		local hot = HOTKEYS[key]
		slot.hotkey.Text = if hot then hot.label else ""
		if info.held > 0 then
			anyHeld = true
		end
	end

	gadgetHeld = anyHeld
	refreshHotBar()
end

-- ============================================================
-- HOME ITEMS
-- ============================================================

local latestHome: any = nil
local homeTiles: { [string]: { title: TextLabel, sub: TextLabel, count: TextLabel, button: TextButton } } = {}
local homeSlots: { [string]: { button: TextButton, label: TextLabel, hotkey: TextLabel } } = {}

-- The treat sits under the bones and the sprinkler under the gadgets, because
-- each belongs with the thing it acts on. `parent` is passed in rather than
-- looked up so one builder serves both.
local function ensureHomeTile(key: string, info: any, parent: Frame)
	local existing = homeTiles[key]
	if existing then
		return existing
	end

	local button = Instance.new("TextButton")
	button.LayoutOrder = info.order or 99
	button.BackgroundColor3 = PANEL
	button.BorderSizePixel = 0
	button.Font = Enum.Font.FredokaOne
	button.Text = ""
	button.Parent = parent
	corner(button, 10)

	makeModelIcon(button, HomeModel.build(key), UDim2.new(0, 48, 0, 50), UDim2.new(0, 4, 0, 8), true)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -62, 0, 20)
	title.Position = UDim2.new(0, 56, 0, 6)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(236, 240, 248)
	title.Text = info.name
	title.Parent = button

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -62, 0, 18)
	sub.Position = UDim2.new(0, 56, 0, 28)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamBold
	sub.TextSize = 12
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextColor3 = GOLD
	sub.Text = ""
	sub.Parent = button

	local count = Instance.new("TextLabel")
	count.Size = UDim2.new(1, -62, 0, 16)
	count.Position = UDim2.new(0, 56, 0, 46)
	count.BackgroundTransparency = 1
	count.Font = Enum.Font.Gotham
	count.TextSize = 11
	count.TextXAlignment = Enum.TextXAlignment.Left
	count.TextColor3 = Color3.fromRGB(150, 162, 178)
	count.Text = ""
	count.Parent = button

	button.Activated:Connect(function()
		Remotes.get("HomeRequest"):FireServer(key)
	end)

	local entry = { title = title, sub = sub, count = count, button = button }
	homeTiles[key] = entry
	return entry
end

local function ensureHomeSlot(key: string, info: any)
	local existing = homeSlots[key]
	if existing then
		return existing
	end

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 58, 1, 0)
	-- Last on the bar, after the bones and the gadgets. These are used at
	-- home rather than thrown at anybody, so they are the least urgent thing
	-- on it and belong furthest from the thumb.
	button.LayoutOrder = 20 + (info.order or 99)
	button.BackgroundColor3 = PANEL
	button.BackgroundTransparency = 0.15
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.FredokaOne
	button.Text = ""
	button.Parent = hotBar
	corner(button, 10)

	makeModelIcon(button, HomeModel.build(key), UDim2.new(1, -6, 1, -6), UDim2.new(0, 3, 0, 3), false)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -6, 0, 18)
	label.Position = UDim2.new(0, 3, 1, -20)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.TextColor3 = Color3.fromRGB(255, 252, 244)
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(18, 20, 26)
	label.Text = ""
	label.Parent = button

	local hotkey = Instance.new("TextLabel")
	hotkey.Size = UDim2.new(0, 22, 0, 14)
	hotkey.Position = UDim2.new(0, 3, 0, 2)
	hotkey.BackgroundTransparency = 1
	hotkey.Font = Enum.Font.GothamBold
	hotkey.TextScaled = true
	hotkey.TextXAlignment = Enum.TextXAlignment.Left
	hotkey.TextColor3 = Color3.fromRGB(190, 255, 200)
	hotkey.TextStrokeTransparency = 0.3
	hotkey.TextStrokeColor3 = Color3.fromRGB(18, 20, 26)
	hotkey.Text = ""
	hotkey.Parent = button

	button.Activated:Connect(function()
		Remotes.get("HomeUse"):FireServer(key)
	end)

	local entry = { button = button, label = label, hotkey = hotkey }
	homeSlots[key] = entry
	return entry
end

local function renderHome()
	if not latestHome then
		return
	end

	local anyHeld = false
	for key, info in pairs(latestHome.items or {}) do
		local parent = if key == "treat" then treatGridFrame else homeGridFrame
		local tile = ensureHomeTile(key, info, parent)
		tile.title.Text = info.name
		tile.sub.Text = ("%s  -  %s"):format(
			if info.duration >= 60 then ("%d min"):format(info.duration / 60)
			else ("%ds"):format(info.duration),
			format(info.cost))
		tile.count.Text = if info.held > 0 then ("you have %d"):format(info.held) else (info.detail or "")
		tile.button.BackgroundColor3 = if latestCoins >= info.cost
			then Color3.fromRGB(58, 84, 62)
			else PANEL

		local slot = ensureHomeSlot(key, info)
		slot.button.Visible = info.held > 0
		slot.label.Text = tostring(info.held)
		local hot = HOTKEYS[key]
		slot.hotkey.Text = if hot then hot.label else ""
		if info.held > 0 then
			anyHeld = true
		end
	end

	-- The countdown, on the treat's own slot. Ten thousand coins with nothing
	-- on screen to show for it reads as a purchase that did not take -- and the
	-- one thing a defender actually wants to know is how long they have left
	-- before they should head home.
	local left = latestHome.guardSeconds or 0
	local treatSlot = homeSlots.treat
	if treatSlot then
		if left > 0 then
			treatSlot.button.Visible = true
			treatSlot.label.Text = ("%d:%02d"):format(math.floor(left / 60), left % 60)
			treatSlot.hotkey.Text = "ON"
			anyHeld = true
		else
			treatSlot.hotkey.Text = if HOTKEYS.treat then HOTKEYS.treat.label else ""
		end
	end

	homeHeld = anyHeld
	refreshHotBar()
end

-- ============================================================
-- THIEF KIT
-- ============================================================

local latestStealth: any = nil
local stealthTiles: { [string]: { title: TextLabel, sub: TextLabel, count: TextLabel, button: TextButton } } = {}
local stealthSlots: { [string]: { button: TextButton, label: TextLabel, hotkey: TextLabel } } = {}

local function ensureStealthTile(key: string, info: any)
	local existing = stealthTiles[key]
	if existing then
		return existing
	end

	local button = Instance.new("TextButton")
	button.LayoutOrder = info.order or 99
	button.BackgroundColor3 = PANEL
	button.BorderSizePixel = 0
	button.Font = Enum.Font.FredokaOne
	button.Text = ""
	button.Parent = stealthGridFrame
	corner(button, 10)

	makeModelIcon(button, ThiefModel.build(key), UDim2.new(0, 48, 0, 50), UDim2.new(0, 4, 0, 8), true)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -62, 0, 20)
	title.Position = UDim2.new(0, 56, 0, 6)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(236, 240, 248)
	title.Text = info.name
	title.Parent = button

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -62, 0, 18)
	sub.Position = UDim2.new(0, 56, 0, 28)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamBold
	sub.TextSize = 12
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextColor3 = GOLD
	sub.Text = ""
	sub.Parent = button

	local count = Instance.new("TextLabel")
	count.Size = UDim2.new(1, -62, 0, 16)
	count.Position = UDim2.new(0, 56, 0, 46)
	count.BackgroundTransparency = 1
	count.Font = Enum.Font.Gotham
	count.TextSize = 11
	count.TextXAlignment = Enum.TextXAlignment.Left
	count.TextColor3 = Color3.fromRGB(150, 162, 178)
	count.Text = ""
	count.Parent = button

	button.Activated:Connect(function()
		Remotes.get("StealthRequest"):FireServer(key)
	end)

	local entry = { title = title, sub = sub, count = count, button = button }
	stealthTiles[key] = entry
	return entry
end

local function ensureStealthSlot(key: string, info: any)
	local existing = stealthSlots[key]
	if existing then
		return existing
	end

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 58, 1, 0)
	-- Last on the bar. The order across the whole thing is bones, gadgets,
	-- home, thief kit -- grouped by who you use them ON, so the hand knows
	-- which quarter it is reaching for without reading.
	button.LayoutOrder = 30 + (info.order or 99)
	button.BackgroundColor3 = PANEL
	button.BackgroundTransparency = 0.15
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.FredokaOne
	button.Text = ""
	button.Parent = hotBar
	corner(button, 10)

	makeModelIcon(button, ThiefModel.build(key), UDim2.new(1, -6, 1, -6), UDim2.new(0, 3, 0, 3), false)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -6, 0, 18)
	label.Position = UDim2.new(0, 3, 1, -20)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.TextColor3 = Color3.fromRGB(255, 252, 244)
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(18, 20, 26)
	label.Text = ""
	label.Parent = button

	local hotkey = Instance.new("TextLabel")
	hotkey.Size = UDim2.new(0, 22, 0, 14)
	hotkey.Position = UDim2.new(0, 3, 0, 2)
	hotkey.BackgroundTransparency = 1
	hotkey.Font = Enum.Font.GothamBold
	hotkey.TextScaled = true
	hotkey.TextXAlignment = Enum.TextXAlignment.Left
	hotkey.TextColor3 = Color3.fromRGB(210, 200, 255)
	hotkey.TextStrokeTransparency = 0.3
	hotkey.TextStrokeColor3 = Color3.fromRGB(18, 20, 26)
	hotkey.Text = ""
	hotkey.Parent = button

	button.Activated:Connect(function()
		Remotes.get("StealthUse"):FireServer(key)
	end)

	local entry = { button = button, label = label, hotkey = hotkey }
	stealthSlots[key] = entry
	return entry
end

local function renderStealth()
	if not latestStealth then
		return
	end

	local anyHeld = false
	for key, info in pairs(latestStealth.items or {}) do
		local tile = ensureStealthTile(key, info)
		tile.title.Text = info.name
		tile.sub.Text = format(info.cost)
		tile.count.Text = if info.held > 0 then ("you have %d"):format(info.held) else (info.detail or "")
		tile.button.BackgroundColor3 = if latestCoins >= info.cost
			then Color3.fromRGB(58, 84, 62)
			else PANEL

		local slot = ensureStealthSlot(key, info)
		slot.button.Visible = info.held > 0
		slot.label.Text = tostring(info.held)
		local hot = HOTKEYS[key]
		slot.hotkey.Text = if hot then hot.label else ""
		if info.held > 0 then
			anyHeld = true
		end
	end

	-- Both of these are STATES once used, and a state with nothing on screen
	-- reads as a purchase that did not take. The slot says so instead of the
	-- player having to guess whether they are still hidden.
	local d = stealthSlots.disguise
	if d then
		if latestStealth.disguised then
			d.button.Visible = true
			d.hotkey.Text = "HID"
			d.label.Text = ""
			anyHeld = true
		elseif HOTKEYS.disguise then
			d.hotkey.Text = HOTKEYS.disguise.label
		end
	end

	local r = stealthSlots.raincoat
	if r then
		if latestStealth.warded then
			r.button.Visible = true
			r.hotkey.Text = "ON"
			anyHeld = true
		elseif HOTKEYS.raincoat then
			r.hotkey.Text = HOTKEYS.raincoat.label
		end
	end

	stealthHeld = anyHeld
	refreshHotBar()
end

-- ============================================================
-- RIDES
-- ============================================================

local rideTiles: { [string]: { button: TextButton, title: TextLabel, sub: TextLabel } } = {}
local latestRides: any = nil

local function ensureRideTile(key: string, info: any)
	local existing = rideTiles[key]
	if existing then
		return existing
	end

	local button = Instance.new("TextButton")
	button.LayoutOrder = info.order or 99
	button.BackgroundColor3 = PANEL
	button.BorderSizePixel = 0
	button.Font = Enum.Font.FredokaOne
	button.Text = ""
	button.Parent = ridesGridFrame
	corner(button, 10)

	-- The real model, spinning, for the same reason the bones show one: a
	-- rendered board is the only honest picture of the board you get, and a
	-- coloured rectangle would have to be kept in sync with RideModel by hand.
	makeModelIcon(button, RideModel.build(key), UDim2.new(0, 66, 0, 68), UDim2.new(0, 4, 0, 4), true)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -80, 0, 20)
	title.Position = UDim2.new(0, 74, 0, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(236, 240, 248)
	title.Text = info.name
	title.Parent = button

	local blurb = Instance.new("TextLabel")
	blurb.Size = UDim2.new(1, -80, 0, 16)
	blurb.Position = UDim2.new(0, 74, 0, 30)
	blurb.BackgroundTransparency = 1
	blurb.Font = Enum.Font.Gotham
	blurb.TextSize = 11
	blurb.TextXAlignment = Enum.TextXAlignment.Left
	blurb.TextColor3 = Color3.fromRGB(140, 150, 166)
	blurb.Text = info.blurb or ""
	blurb.Parent = button

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -80, 0, 20)
	sub.Position = UDim2.new(0, 74, 0, 50)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamBold
	sub.TextSize = 13
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextColor3 = GOLD
	sub.Text = ""
	sub.Parent = button

	button.Activated:Connect(function()
		Remotes.get("RideRequest"):FireServer(key)
	end)

	local entry = { button = button, title = title, sub = sub }
	rideTiles[key] = entry
	return entry
end

local function renderRides()
	if not latestRides then
		return
	end

	for key, info in pairs(latestRides.rides or {}) do
		local tile = ensureRideTile(key, info)
		tile.title.Text = info.name

		if info.equipped then
			-- Says whether the board is actually under them right now, not just
			-- that it is selected. Those are different states -- standing on your
			-- own lawn is the second without the first -- and a tile that claimed
			-- "RIDING" while the player was plainly walking would read as a bug.
			tile.sub.Text = if latestRides.riding then "RIDING" else "READY -- HIT THE STREET"
			tile.sub.TextColor3 = Color3.fromRGB(120, 226, 170)
			tile.button.BackgroundColor3 = Color3.fromRGB(46, 88, 62)
		elseif info.owned then
			tile.sub.Text = ("Tap to ride  ·  +%d%%"):format(info.boost)
			tile.sub.TextColor3 = Color3.fromRGB(150, 162, 178)
			tile.button.BackgroundColor3 = PANEL
		else
			tile.sub.Text = ("%s  ·  +%d%%"):format(format(info.cost), info.boost)
			tile.sub.TextColor3 = if latestCoins >= info.cost then GOLD else Color3.fromRGB(150, 120, 120)
			tile.button.BackgroundColor3 = Color3.fromRGB(30, 34, 44)
		end
	end
end

-- ============================================================
-- COLLECTION
-- ============================================================

local accessoryTiles: { [string]: {
	button: TextButton, title: TextLabel, sub: TextLabel,
	paint: { { part: BasePart, colour: Color3, material: Enum.Material } },
} } = {}

-- Light enough to read against the locked tile's own dark background. The
-- first value was barely brighter than the tile and the silhouette -- the
-- whole point of showing a locked item -- vanished into it.
local LOCKED_GREY = Color3.fromRGB(104, 110, 128)

local function ensureAccessoryTile(key: string, info: any)
	local existing = accessoryTiles[key]
	if existing then
		return existing
	end

	local button = Instance.new("TextButton")
	button.LayoutOrder = info.order or 99
	button.BackgroundColor3 = PANEL
	button.BorderSizePixel = 0
	button.Font = Enum.Font.FredokaOne
	button.Text = ""
	button.Parent = slotGrids[info.slot] or slotGrids[slotOrder[1]]
	corner(button, 10)

	local model = PigGear.build(key)

	-- Every part's real colour is recorded BEFORE the tile is ever dimmed.
	-- Reading it back off the parts later would mean reading whatever grey the
	-- silhouette last wrote, so an item would stay grey after it was won.
	local paint = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(paint, { part = d, colour = d.Color, material = d.Material })
		end
	end

	makeModelIcon(button, model, UDim2.new(0, 48, 0, 50), UDim2.new(0, 4, 0, 8), true)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -62, 0, 22)
	title.Position = UDim2.new(0, 56, 0, 10)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(236, 240, 248)
	title.Text = info.name
	title.Parent = button

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -62, 0, 20)
	sub.Position = UDim2.new(0, 56, 0, 36)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamBold
	sub.TextScaled = true
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextColor3 = GOLD
	sub.Text = ""
	sub.Parent = button

	button.Activated:Connect(function()
		Remotes.get("CosmeticRequest"):FireServer("accessory", key)
	end)

	local entry = { button = button, title = title, sub = sub, paint = paint }
	accessoryTiles[key] = entry
	return entry
end

local function renderCollection()
	if not latestCosmetics then
		return
	end

	for key, info in pairs(latestCosmetics.accessories or {}) do
		local tile = ensureAccessoryTile(key, info)
		tile.title.Text = info.name

		-- Locked items render as a grey silhouette: the shape is the advert,
		-- the colour is the reward.
		for _, entry in ipairs(tile.paint) do
			entry.part.Color = if info.owned then entry.colour else LOCKED_GREY
			entry.part.Material = if info.owned then entry.material else Enum.Material.SmoothPlastic
		end

		if info.worn then
			tile.sub.Text = "WEARING"
			tile.sub.TextColor3 = Color3.fromRGB(120, 226, 170)
			tile.button.BackgroundColor3 = Color3.fromRGB(46, 88, 62)
		elseif info.owned then
			tile.sub.Text = "Tap to wear"
			tile.sub.TextColor3 = Color3.fromRGB(150, 162, 178)
			tile.button.BackgroundColor3 = PANEL
		else
			-- Rarity, not the word "locked". What a player wants to know about
			-- something they cannot have yet is how hard it will be to get.
			tile.sub.Text = info.rarityLabel
			tile.sub.TextColor3 = info.rarityColour
			tile.button.BackgroundColor3 = Color3.fromRGB(30, 34, 44)
		end
	end

	local c = latestCosmetics.collection
	if not c then
		return
	end
	if c.cost then
		rollButton.Text = ("ROLL  %s"):format(format(c.cost))
		rollButton.BackgroundColor3 = if latestCoins >= c.cost
			then Color3.fromRGB(150, 96, 190)
			else Color3.fromRGB(72, 60, 88)
		rollNote.Text = ("%d of %d collected. A roll always gives something you "):format(c.owned, c.total)
			.. "do not own yet, so the set always finishes -- and gets pricier as it fills."
	else
		rollButton.Text = "COLLECTION COMPLETE"
		rollButton.BackgroundColor3 = Color3.fromRGB(46, 88, 62)
		rollNote.Text = ("All %d accessories collected. Nothing left to roll for."):format(c.total)
	end
end

RunService.Heartbeat:Connect(function()
	if not panel.Visible then
		return
	end
	local yaw = os.clock() * 0.9
	for _, spinner in ipairs(spinners) do
		spinner.model:PivotTo(CFrame.Angles(0, yaw, 0) * spinner.tilt)
	end
end)

Remotes.get("GearState").OnClientEvent:Connect(function(snapshot)
	latestBones = snapshot
	renderBones()
end)

Remotes.get("CosmeticState").OnClientEvent:Connect(function(snapshot)
	latestCosmetics = snapshot
	renderCosmetics()
	renderCollection()
end)

Remotes.get("GadgetState").OnClientEvent:Connect(function(snapshot)
	latestGadgets = snapshot
	renderGadgets()
end)

Remotes.get("HomeState").OnClientEvent:Connect(function(snapshot)
	latestHome = snapshot
	renderHome()
end)

Remotes.get("StealthState").OnClientEvent:Connect(function(snapshot)
	latestStealth = snapshot
	renderStealth()
end)

Remotes.get("RideState").OnClientEvent:Connect(function(snapshot)
	latestRides = snapshot
	renderRides()
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
	elseif input.KeyCode == Enum.KeyCode.G then
		local key = cheapestHeldBone()
		if key then
			throwBone(key)
		end
	else
		-- One fixed key per item, driven from the PUSHED state and never from an
		-- assumed stock: pressing a number for something you do not hold has to
		-- do nothing, rather than fire a remote the server will only reject.
		for key, hot in pairs(HOTKEYS) do
			if input.KeyCode == hot.key then
				local bone = latestBones and latestBones[key]
				local gadget = latestGadgets and latestGadgets[key]
				local home = latestHome and latestHome.items and latestHome.items[key]
				if bone and bone.held > 0 then
					throwBone(key)
				elseif gadget and gadget.held > 0 then
					throwGadget(key)
				elseif home and home.held > 0 then
					Remotes.get("HomeUse"):FireServer(key)
				else
					local kit = latestStealth and latestStealth.items and latestStealth.items[key]
					if kit and kit.held > 0 then
						Remotes.get("StealthUse"):FireServer(key)
					end
				end
				break
			end
		end
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

-- The rebirth button is a HUD overlay pinned near the top of the screen,
-- which is exactly where the shop panel's own header and first row sit. It
-- was covering the roll button outright. `rebirthReady` is what it wants to
-- be; whether the shop is open decides whether it gets to be it.
local rebirthReady = false
local function syncRebirthButton()
	rebirthButton.Visible = rebirthReady and not panel.Visible
end

-- Watched rather than called from the three places that toggle the panel --
-- the button, the close X, and the B/Escape keybind, all of which are defined
-- above this point and could not call it anyway. Watching the property also
-- covers anything that opens the panel later without knowing about this.
panel:GetPropertyChangedSignal("Visible"):Connect(syncRebirthButton)
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
	renderBones()
	renderCollection()
	renderGadgets()
	renderHome()
	renderStealth()
	renderRides()
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

	rebirthReady = state.rebirthReady == true
	syncRebirthButton()
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
		local hold = Config.getStealHold(lockLevel, myLockpicks)
		entry.steal.HoldDuration = hold

		-- Put the number on the prompt. The hold was always the mechanic, but
		-- a ProximityPrompt animates its ring over whatever duration it is
		-- given, so three seconds and nine seconds looked identical and the
		-- whole lock/lockpick axis read as decorative.
		entry.steal.ActionText = ("Crack Lock  %.1fs"):format(hold)
		entry.steal.ObjectText = if lockLevel > 0
			then ("Vault Lock Lv%d"):format(lockLevel)
			else "Unlocked Piggy"
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

-- ============================================================
-- ADMIN PANEL
-- ============================================================
--
-- Built only after the SERVER says this player is an admin. That is a
-- convenience, not a security control: the AdminRequest remote exists for
-- everyone, and AdminService re-authorises every request against its
-- allowlist before reading a single argument. Nothing here grants anything --
-- if this whole block were deleted, or if a non-admin recreated it with an
-- exploit, the server would behave identically.

local adminGui: Frame? = nil

local function buildAdminPanel()
	if adminGui then
		return
	end

	local panelFrame = Instance.new("Frame")
	panelFrame.Name = "AdminPanel"
	panelFrame.Size = UDim2.new(0, 300, 0, 0)
	panelFrame.AutomaticSize = Enum.AutomaticSize.Y
	panelFrame.Position = UDim2.new(0, 18, 0.5, 0)
	panelFrame.AnchorPoint = Vector2.new(0, 0.5)
	panelFrame.BackgroundColor3 = Color3.fromRGB(24, 20, 32)
	panelFrame.BackgroundTransparency = 0.05
	panelFrame.BorderSizePixel = 0
	panelFrame.Visible = false
	panelFrame.Parent = gui
	corner(panelFrame, 12)
	adminGui = panelFrame

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = panelFrame

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = panelFrame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 24)
	title.LayoutOrder = 0
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(226, 172, 83)
	title.Text = "ADMIN  [F2]"
	title.Parent = panelFrame

	local order = 1
	local function button(label: string, command: string, a: any, b: any)
		order += 1
		local b2 = Instance.new("TextButton")
		b2.Size = UDim2.new(1, 0, 0, 30)
		b2.LayoutOrder = order
		b2.BackgroundColor3 = Color3.fromRGB(52, 44, 68)
		b2.BorderSizePixel = 0
		b2.Font = Enum.Font.GothamBold
		b2.TextSize = 14
		b2.TextColor3 = Color3.fromRGB(236, 232, 244)
		b2.Text = label
		b2.Parent = panelFrame
		corner(b2, 8)
		b2.Activated:Connect(function()
			Remotes.get("AdminRequest"):FireServer(command, a, b)
		end)
		return b2
	end

	button("+100K coins", "coins", 100000)
	button("+10M coins", "coins", 10000000)
	button("Fill vault", "vault", 1000000)
	button("Max all upgrades", "maxupgrades")
	button("Unlock all skins / effects / houses / gear", "unlockall")
	button("Open season (shield + cooldowns)", "shield")
	button("Guard dog -> Titan (Lv3)", "upgrade", "dog", 3)
	button("No guard dog (Lv0)", "upgrade", "dog", 0)
	button("Send dog to bed (20s)", "dognap", 20)
	button("Give 10 of every bone", "bones", 10)
	button("Empty accessory collection", "cleargear")
	button("Set 5 rebirths", "rebirths", 5)
	button("WIPE MY SAVE", "reset").BackgroundColor3 = Color3.fromRGB(96, 40, 40)

	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(1, 0, 0, 30)
	hint.LayoutOrder = 99
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 11
	hint.TextWrapped = true
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextColor3 = Color3.fromRGB(130, 122, 148)
	hint.Text = "Every action is re-checked and logged server-side."
	hint.Parent = panelFrame
end

Remotes.get("AdminState").OnClientEvent:Connect(function(isAdmin)
	if not isAdmin then
		return
	end
	buildAdminPanel()
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not adminGui then
		return
	end
	if input.KeyCode == Enum.KeyCode.F2 then
		adminGui.Visible = not adminGui.Visible
	end
end)

-- ============================================================
-- ANIMATED SKINS
-- ============================================================
--
-- Runs entirely on the client. The server publishes a SkinKey attribute on
-- each piggy and nothing else; every machine computes the colours itself.
--
-- Doing this server-side would mean a Color write per animated piggy per
-- frame, replicated to everyone -- roughly 700 property updates a second
-- across twelve plots, to say something each client could have worked out
-- from a single string.
--
-- One Heartbeat loop drives every piggy on the map rather than one loop each.

local ANIMATED_TRIM = { "Snout", "Tail", "Ear", "Leg" }

local animatedPiggies: {
	{ model: Instance, body: BasePart, trim: { BasePart }, glow: PointLight?, auraLight: PointLight? }
} = {}

local function paletteAt(palette: { Color3 }, t: number): Color3
	-- Wraps, so a palette is a loop rather than a ramp that snaps at the end.
	local span = #palette
	local scaled = (t % 1) * span
	local index = math.floor(scaled)
	local frac = scaled - index
	local a = palette[(index % span) + 1]
	local b = palette[((index + 1) % span) + 1]
	return a:Lerp(b, frac)
end

local function skinColourAt(anim: any, clock: number, seed: number): Color3?
	local kind = anim.kind
	local speed = anim.speed or 1

	if kind == "rainbow" then
		return Color3.fromHSV((clock * speed + seed) % 1, 0.72, 1)
	elseif kind == "cycle" then
		return paletteAt(anim.palette, clock * speed * 0.25 + seed)
	elseif kind == "pulse" then
		local t = (math.sin(clock * speed * math.pi * 2 + seed * 6) + 1) / 2
		return anim.palette[1]:Lerp(anim.palette[2], t)
	elseif kind == "flicker" then
		-- Deliberately not smooth: fire and lightning read as unsteady, so this
		-- stacks two out-of-phase waves to avoid an obvious pulse rhythm.
		local a = math.sin(clock * speed + seed * 5)
		local b = math.sin(clock * speed * 2.7 + seed * 11)
		local t = math.clamp((a + b) / 2 * 0.5 + 0.5, 0, 1)
		return anim.palette[1]:Lerp(anim.palette[2], t * t)
	end
	return nil
end

local function collectAnimated(piggy: Instance)
	local body = piggy:FindFirstChild("Body") :: BasePart?
	if not body then
		return
	end
	local trim: { BasePart } = {}
	for _, child in ipairs(piggy:GetChildren()) do
		if child:IsA("BasePart") and table.find(ANIMATED_TRIM, child.Name) then
			table.insert(trim, child)
		end
	end
	table.insert(animatedPiggies, {
		model = piggy,
		body = body,
		trim = trim,
		glow = body:FindFirstChild("Glow") :: PointLight?,
		auraLight = body:FindFirstChild("AuraLight") :: PointLight?,
	})
end

task.spawn(function()
	local plots = workspace:WaitForChild("Plots", 30)
	if not plots then
		return
	end
	for _, plot in ipairs(plots:GetChildren()) do
		local piggy = plot:FindFirstChild("PiggyBank")
		if piggy then
			collectAnimated(piggy)
		end
	end

	RunService.Heartbeat:Connect(function()
		local clock = os.clock()
		for index, entry in ipairs(animatedPiggies) do
			local key = entry.model:GetAttribute("SkinKey")
			local skin = if type(key) == "string" then Config.SKINS[key] else nil
			local anim = skin and skin.anim

			if anim then
				-- Seeded per plot so twelve animated piggies are not all
				-- pulsing in lockstep, which reads as one effect rather than
				-- twelve separate players.
				local colour = skinColourAt(anim, clock, index * 0.137)
				if colour then
					entry.body.Color = colour
					for _, p in ipairs(entry.trim) do
						p.Color = colour:Lerp(skin.trim, 0.55)
					end
				end
				if anim.glow and entry.glow then
					-- Left alone otherwise: EconomyService drives this light to
					-- show vault fill, and stomping it every frame would erase
					-- that signal.
					entry.glow.Color = entry.body.Color
				end
			end

			-- Effect light. Storm strikes; Inferno breathes.
			local light = entry.auraLight
			if light and light.Enabled then
				local kind = entry.model:GetAttribute("LightKind")
				local seed = index * 0.61
				if kind == "strike" then
					-- Mostly dark with occasional sharp flashes, so it reads as
					-- lightning rather than as a lamp someone left on.
					local wave = math.sin(clock * 1.7 + seed) * math.sin(clock * 0.53 + seed * 3)
					local flash = math.max(0, wave) ^ 8
					light.Brightness = 0.6 + flash * 14
				elseif kind == "flicker" then
					local a = math.sin(clock * 11 + seed * 5)
					local b = math.sin(clock * 27 + seed * 13)
					light.Brightness = 7 + (a + b) * 1.6
				end
			end
		end
	end)
end)

selectTab(1)
