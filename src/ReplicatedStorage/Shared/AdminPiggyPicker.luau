--!strict
--[[
	AdminPiggyPicker

	THE ADMIN PANEL'S "SPAWN ANY PIGGY" SCREEN: every skin in the game, laid
	out by collection the way the crates tab lays out its shelves, where one
	press on a card stands that piggy on the ground in front of you so it can
	be looked at. A dev tool for judging how a skin actually reads on a lawn,
	which is the one question no card, no probe and no test can answer.

	A MODULE FOR THE REASON THE ADMIN PANEL IS ONE. `ClientMain` is at Luau's
	200-local ceiling, and a screen with sections, cards and a scroll is
	exactly the kind of thing that overflows it -- the last section to do that
	took down the ENTIRE HUD. It is initialised from the same `do` block that
	owns `iconFor`, holding no local up there at all, and opened by name from
	`AdminPanel`'s `open` rows.

	IT REUSES THE CARD, NOT A PICTURE OF ONE. The well, the tier ground and
	the icon come from `ShopSkinCards` and the injected `iconFor`, which are
	the same builders the crates, the inventory and the shop use -- so what
	the picker shows is what the game draws everywhere else, and a skin that
	renders wrong here renders wrong there too. The grouping is
	`Config.skinCollections`, derived from the skins' own chest tags, so a new
	shelf appears here with nothing to remember.

	CONVENIENCE ONLY. Pressing a card fires `AdminRequest("spawnpiggy")`, and
	the allowlist check at the top of AdminService's handler is the security;
	this screen is only ever built for a client the server has already told
	is an admin, and it grants nothing on its own.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)
local ShopStyle = require(ReplicatedStorage.Shared.ShopStyle)
local SkinCards = require(ReplicatedStorage.Shared.ShopSkinCards)

local Picker = {}

-- The inventory's card, at the inventory's size, so the two screens read as
-- the same catalogue.
local CARD_W = 156
local CARD_H = 196
local WELL_H = 120
local Z = 60

type Deps = {
	iconFor: ((kind: string, key: string, holder: GuiObject) -> ())?,
	fire: (command: string, targetId: number?, a: any, b: any) -> (),
}

local deps: Deps? = nil
local panel: Frame? = nil
local targetId: number? = nil
local wells: { [string]: GuiObject } = {}

local function label(parent: Instance, text: string, size: UDim2, pos: UDim2,
	font: Enum.Font, textSize: number, colour: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.Font = font
	l.TextSize = textSize
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = colour
	l.Text = text
	l.ZIndex = Z + 2
	l.Parent = parent
	return l
end

local function buildCard(parent: Instance, key: string, index: number)
	local skin = Config.SKINS[key]
	local tier = Config.rarityOf(skin)
	local rarity = Config.RARITIES[tier] or Config.RARITIES.common

	local button = Instance.new("TextButton")
	button.Name = "Spawn_" .. key
	button.LayoutOrder = index
	button.Size = UDim2.new(0, CARD_W, 0, CARD_H)
	button.BackgroundColor3 = ShopStyle.CARD
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Text = ""
	button.ZIndex = Z + 1
	button.Parent = parent
	ShopStyle.round(button, 14)
	ShopStyle.outline(button, if tier == "legendary" then 5 else 3, rarity.colour)

	local well = Instance.new("Frame")
	well.Name = "Well"
	well.Size = UDim2.new(1, -16, 0, WELL_H)
	well.Position = UDim2.new(0, 8, 0, 8)
	well.BackgroundColor3 = ShopStyle.SUNK
	well.BorderSizePixel = 0
	well.ZIndex = Z + 1
	well.Parent = button
	ShopStyle.round(well, 10)
	-- The whole card wears the tier, so the well is cleared before the icon
	-- goes in -- `iconFor` would otherwise lay a second ground inside it.
	SkinCards.dressCard(button, tier, { well })
	wells[key] = well
	if deps and deps.iconFor then
		deps.iconFor("skin", key, well)
	end

	local title = label(button, skin.name or key, UDim2.new(1, -16, 0, 22),
		UDim2.new(0, 8, 0, WELL_H + 12), Enum.Font.FredokaOne, 16, Theme.INK)
	title.TextTruncate = Enum.TextTruncate.AtEnd
	SkinCards.onTierText(title)

	local word = label(button, string.upper(rarity.label), UDim2.new(1, -16, 0, 16),
		UDim2.new(0, 8, 0, WELL_H + 36), Enum.Font.GothamBold, 11, Theme.INK)
	SkinCards.onTierText(word)

	local go = label(button, "TAP TO SPAWN", UDim2.new(1, -16, 0, 16),
		UDim2.new(0, 8, 1, -22), Enum.Font.GothamBold, 10, Theme.INK)
	go.TextXAlignment = Enum.TextXAlignment.Center
	SkinCards.onTierText(go)

	button.Activated:Connect(function()
		if deps then
			deps.fire("spawnpiggy", targetId, key, nil)
		end
	end)
end

local function buildSection(parent: Instance, group: any, order: number)
	local hue = group.tone or Theme.HUE.crates

	local frame = Instance.new("Frame")
	frame.Name = "Section_" .. group.key
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = ShopStyle.CARD
	frame.BorderSizePixel = 0
	frame.ZIndex = Z
	frame.Parent = parent
	ShopStyle.round(frame, 16)
	ShopStyle.outline(frame, 3, hue)

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.Parent = frame
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 10)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame

	local head = label(frame, ("%s   %d"):format(group.name, #group.skins),
		UDim2.new(1, 0, 0, 30), UDim2.new(), Enum.Font.FredokaOne, 24, ShopStyle.TEXT)
	head.LayoutOrder = 1

	local grid = Instance.new("Frame")
	grid.Name = "Cards"
	grid.LayoutOrder = 2
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.new(1, 0, 0, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.ZIndex = Z
	grid.Parent = frame
	local cells = Instance.new("UIGridLayout")
	cells.CellSize = UDim2.new(0, CARD_W, 0, CARD_H)
	cells.CellPadding = UDim2.new(0, 12, 0, 12)
	cells.SortOrder = Enum.SortOrder.LayoutOrder
	cells.Parent = grid

	for i, key in ipairs(group.skins) do
		buildCard(grid, key, i)
	end
end

-- Built once, on first open, because it renders a model per skin and the
-- picker is a thing a dev opens a few times a session, not something every
-- client should pay for at join.
local function build(gui: Instance)
	local p = Instance.new("Frame")
	p.Name = "AdminPiggyPicker"
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Position = UDim2.fromScale(0.5, 0.5)
	p.Size = UDim2.new(0.86, 0, 0.86, 0)
	p.BackgroundColor3 = ShopStyle.BASE
	p.BorderSizePixel = 0
	p.Visible = false
	p.ZIndex = Z
	p.Parent = gui
	ShopStyle.round(p, 18)
	ShopStyle.outline(p, 3)

	local title = label(p, "SPAWN A PIGGY", UDim2.new(1, -220, 0, 34),
		UDim2.new(0, 16, 0, 12), Enum.Font.FredokaOne, 26, ShopStyle.TEXT)
	title.Name = "Title"
	local note = label(p, "Tap a card to stand that piggy in front of the player the admin panel is acting on. "
		.. "Nothing is owned, saved or paid for.",
		UDim2.new(1, -220, 0, 18), UDim2.new(0, 16, 0, 46), Enum.Font.Gotham, 12, ShopStyle.MUTED)
	note.TextTruncate = Enum.TextTruncate.AtEnd

	local clear = Instance.new("TextButton")
	clear.Name = "Clear"
	clear.Size = UDim2.new(0, 150, 0, 34)
	clear.Position = UDim2.new(1, -212, 0, 14)
	clear.BackgroundColor3 = ShopStyle.BUY
	clear.BorderSizePixel = 0
	clear.Font = Enum.Font.FredokaOne
	clear.TextSize = 15
	clear.TextColor3 = ShopStyle.TEXT
	clear.Text = "CLEAR SPAWNED"
	clear.ZIndex = Z + 2
	clear.Parent = p
	ShopStyle.round(clear, 10)
	ShopStyle.outline(clear, 3)
	clear.Activated:Connect(function()
		if deps then
			deps.fire("spawnclear", targetId, nil, nil)
		end
	end)

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Size = UDim2.new(0, 40, 0, 34)
	close.Position = UDim2.new(1, -56, 0, 14)
	close.BackgroundColor3 = Theme.STOP
	close.BorderSizePixel = 0
	close.Font = Enum.Font.FredokaOne
	close.TextSize = 18
	close.TextColor3 = Theme.PAPER
	close.Text = utf8.char(0x00D7)
	close.ZIndex = Z + 2
	close.Parent = p
	ShopStyle.round(close, 10)
	ShopStyle.outline(close, 3)
	close.Activated:Connect(function()
		p.Visible = false
	end)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Shelves"
	scroll.Size = UDim2.new(1, -24, 1, -84)
	scroll.Position = UDim2.new(0, 12, 0, 72)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ZIndex = Z
	scroll.Parent = p
	-- A `Border` stroke draws OUTSIDE its frame into the region a scroll
	-- clips, which once cut the left edge off the first column of every
	-- cosmetic card. The clearance goes on the scroll.
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 4)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = scroll
	local stack = Instance.new("UIListLayout")
	stack.Padding = UDim.new(0, 14)
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Parent = scroll

	for i, group in ipairs(Config.skinCollections()) do
		buildSection(scroll, group, i)
	end

	-- Escape closes it, the same way it closes the shop.
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not p.Visible then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape then
			p.Visible = false
		end
	end)

	return p
end

-- `injected.iconFor(kind, key, holder)` draws the real item into a well;
-- `injected.fire(command, targetId, a, b)` is the admin remote, handed in so
-- this module knows nothing about Remotes.
function Picker.init(gui: Instance, injected: Deps)
	deps = injected
	-- Built lazily: see `build`.
	Picker.gui = gui
end

-- Opens the picker acting on `forUserId` (the admin panel's dropdown), or
-- closes it if it is already open. Safe to call before `init`: it says so
-- rather than failing silently, which is the rule every refusal here keeps.
function Picker.toggle(forUserId: number?)
	if not deps or not Picker.gui then
		warn("[AdminPiggyPicker] toggled before init")
		return
	end
	targetId = forUserId
	if not panel then
		panel = build(Picker.gui)
	end
	local p = panel :: Frame
	p.Visible = not p.Visible
end

-- After the mesh warm-up the cards want their icons again, exactly as the
-- crates and the inventory redraw theirs.
function Picker.rebuildIcons()
	if not deps or not deps.iconFor then
		return
	end
	for key, well in pairs(wells) do
		deps.iconFor("skin", key, well)
	end
end

Picker.gui = nil :: Instance?

return Picker
