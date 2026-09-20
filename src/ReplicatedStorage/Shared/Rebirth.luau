--!strict
--[[
	Rebirth

	The rebirth button, and the decision page it opens. Built to
	docs/REBIRTH-UI-REDESIGN.md with the art in assets/ui/rebirth-icons-v1.

	A module for the reason `HouseFX`, `SpinWheel`, `AdminPanel` and `HotBar`
	are: `ClientMain` is one chunk against Luau's 200-local ceiling.

	----------------------------------------------------------------------

	THE HUD BUTTON ALWAYS OPENS THE PAGE. It used to open it on the FIRST
	rebirth only (`FIRST_TIME_ONLY`, keyed on `rebirths == 0`) and fire the
	remote straight from the HUD on every one after, on the argument that a
	confirmation everybody taps through is worse than none. What that shipped
	was a button that, from rebirth two onward, silently reset a player's
	coins and upgrades on ONE tap with nothing on screen first -- reported as
	the page having "stopped showing". Only the page's own REBIRTH TO N sends
	the request now, every time.

	The tap-through argument is answered by what the page SAYS rather than by
	skipping it: it leads with what the next rebirth BUYS (current -> next,
	from the same Config helpers the server pays with), so a veteran reads a
	new number every time rather than the same warning.

	----------------------------------------------------------------------

	THE NUMBERS ARE REAL. Every value comes from a Config helper the server
	also reads (`rebirthBonusPercent`, `maxLevel`, `treeRebirthFactor`,
	`getRebirthThreshold`, `rebirthCratesOpen`, `rebirthCrateBonus`) or from a
	push (`StateUpdate`, `UpgradeState`, `CosmeticState`, `ChestState`). The
	crate odds are `ChestState`'s -- what `liveOdds` actually rolls with -- and
	are simply not printed until that push has arrived, because a drawn
	probability the server did not use is worse than none.

	Only levels ABOVE the start are listed as resets. An upgrade never bought
	is not a loss, and the dog is not one at all: rebirth never touches it.

	----------------------------------------------------------------------

	THE PAGE STAYS OPEN THROUGH A STATE CHANGE. Coins dropping under the
	requirement while somebody reads (a robbery, a purchase) used to CLOSE it;
	now the requirement row repaints and the confirm disables, so the page
	never vanishes from under a reader. A confirm is sent ONCE, the button
	reads "Rebirthing..." until the server answers, and the page closes only
	when the rebirth count actually rises. A refusal leaves the page up with
	its values refreshed -- the server's own toast says why.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Theme = require(ReplicatedStorage.Shared.Theme)
local Config = require(ReplicatedStorage.Shared.Config)

local Rebirth = {}

local PLUM = Theme.PRESTIGE
local PLUM_LIGHT = PLUM:Lerp(Theme.PAPER, 0.18)
local ICONS = Config.UI_ICONS or {}

-- Measured present in both fonts before use; see CLAUDE.md on tofu glyphs.
local ARROW = utf8.char(0x2192)
local TICK = utf8.char(0x2713)
local CROSS = utf8.char(0x00D7)
local CHEVRON = utf8.char(0x203A)
local DOT = utf8.char(0x2022)
local ELLIPSIS = utf8.char(0x2026)

local function hex(c: Color3): string
	return ("#%02X%02X%02X"):format(
		math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local PLUM_HEX = hex(PLUM)
local GOLD_HEX = hex(Theme.GOLD)
local MUTED_HEX = hex(Theme.MUTED)

-- Set by ClientMain: the button is a HUD overlay near the top of the screen,
-- which is exactly where the shop panel's header sits.
Rebirth.canShow = nil :: (() -> boolean)?
local onConfirm: (() -> ())? = nil

local seen = {
	coins = 0,
	incomeLevel = 1,
	capacityLevel = 1,
	rebirths = 0,
	ready = false,
	upgrades = nil :: any,
	cosmetics = nil :: any,
	rides = nil :: any,
	chests = nil :: any,
	treeLevel = nil :: number?,
}

-- The confirm is in flight. `from` is the rebirth count it was sent at, so
-- success is "the count rose" rather than a guess at a timer.
local pending = { active = false, from = 0, token = 0 }
local expanded = { crate = false, upgrades = false }

local ui = {} :: any

-- ============================================================
-- SMALL BUILDERS
-- ============================================================

-- Depth decides the layering, explicitly, so the page renders the same under
-- `Sibling` or `Global` ZIndexBehavior. `ZBoost` lifts a subtree (the floating
-- header and the X) over siblings that were built after it.
local function layer(root: Instance, z: number)
	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("GuiObject") then
			local lifted = z + ((child:GetAttribute("ZBoost") :: number?) or 0)
			child.ZIndex = lifted
			layer(child, lifted + 1)
		end
	end
end

local function frame(parent: Instance, name: string, colour: Color3?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	if colour then
		f.BackgroundColor3 = colour
	else
		f.BackgroundTransparency = 1
	end
	f.Parent = parent
	return f
end

local function text(parent: Instance, name: string, value: string, size: number,
	colour: Color3?, font: Enum.Font?): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Font = font or Theme.FONT
	t.TextSize = size
	t.TextColor3 = colour or Theme.INK
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.RichText = true
	t.Text = value
	t.Parent = parent
	return t
end

-- Cream type with a dark line round each GLYPH. Contextual, not Border:
-- `Theme.outline` strokes the label's invisible rectangle.
local function inked(label: TextLabel, thickness: number)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Color = Theme.INK
	s.Thickness = thickness
	s.Parent = label
end

local function image(parent: Instance, name: string, id: string?, scale: number): ImageLabel?
	if not id or id == "" then
		return nil
	end
	local img = Instance.new("ImageLabel")
	img.Name = name
	img.BackgroundTransparency = 1
	img.Image = id
	img.ScaleType = Enum.ScaleType.Fit
	img.AnchorPoint = Vector2.new(0.5, 0.5)
	img.Position = UDim2.fromScale(0.5, 0.5)
	img.Size = UDim2.fromScale(scale, scale)
	img.Parent = parent
	return img
end

-- Every arrow ring that turns. One Heartbeat drives them all, and only while
-- the thing they sit on is on screen.
local spinners: { ImageLabel } = {}
-- Degrees a second: a slow, steady turn that says "cycle" without pulling
-- the eye the way a fast spinner would.
local SPIN_RATE = 70

-- The gold piggy-and-arrows emblem. `layered` builds it as two images so the
-- ring turns while the piggy stays upright; otherwise it is the single
-- combined emblem. With no uploaded art it falls back to a drawn coin, never
-- to an empty square.
local function emblem(parent: Instance, size: number, layered: boolean,
	disc: boolean?): (Frame, ImageLabel?)
	local root = frame(parent, "Emblem")
	root.Size = UDim2.fromOffset(size, size)
	-- A round card behind the art, so an emblem hanging off a button's edge
	-- reads as a medal set on it rather than as art floating over the seam.
	if disc then
		local back = frame(root, "Disc", PLUM:Lerp(Theme.INK, 0.25))
		back.AnchorPoint = Vector2.new(0.5, 0.5)
		back.Position = UDim2.fromScale(0.5, 0.5)
		back.Size = UDim2.fromScale(0.84, 0.84)
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = back
		Theme.outline(back)
		Theme.gloss(back, PLUM_LIGHT, PLUM:Lerp(Theme.INK, 0.35))
	end
	local arrows: ImageLabel? = nil
	if layered and ICONS.rebirthArrows and ICONS.rebirthArrows ~= "" then
		arrows = image(root, "Arrows", ICONS.rebirthArrows, 1)
		image(root, "Piggy", ICONS.piggy, 0.62)
		table.insert(spinners, arrows :: ImageLabel)
	elseif not image(root, "Art", ICONS.rebirthEmblem, 1) then
		local coin = Theme.coin(root, math.floor(size * 0.8))
		coin.AnchorPoint = Vector2.new(0.5, 0.5)
		coin.Position = UDim2.fromScale(0.5, 0.5)
	end
	return root, arrows
end

local function button(parent: Instance, name: string, fill: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = ""
	b.AutoButtonColor = true
	b.BackgroundColor3 = fill
	b.BorderSizePixel = 0
	b.Parent = parent
	Theme.corner(b, 12)
	Theme.outline(b)
	Theme.shade(b, 0.88)
	return b
end

local function format(value: number): string
	return Config.formatCoins(value)
end

-- ============================================================
-- THE HUD BUTTON
-- ============================================================

-- THE PAGE'S OWN TITLE PLATE, on the HUD: the same dark plum gloss, the
-- spinning emblem on a disc hanging off its left edge, and "REBIRTH N" on one
-- line with the number in gold. Tapping it opens a page whose header is the
-- very thing you tapped, which is what makes the two read as one object.
local function buildButton(gui: ScreenGui)
	local b = button(gui, "RebirthButton", PLUM)
	Theme.corner(b, 16)
	Theme.gloss(b, PLUM_LIGHT, PLUM)
	b.AnchorPoint = Vector2.new(0.5, 0)
	b.Visible = false
	b.ZIndex = 2
	ui.button = b

	-- The press moves the face down, emblem and text together.
	local press = Instance.new("UIPadding")
	press.Parent = b
	-- One brief pop when rebirth first becomes available. The only standing
	-- motion is the emblem's arrow ring turning (designer's call, over the
	-- guide's "keep it still"); the plate itself does not pulse or bounce.
	local pop = Instance.new("UIScale")
	pop.Parent = b
	ui.pop = pop

	local mark, arrows = emblem(b, 72, true, true)
	mark.AnchorPoint = Vector2.new(0, 0.5)
	ui.buttonEmblem = mark
	ui.buttonArrows = arrows

	local label = text(b, "Label", "REBIRTH", 22, Theme.PAPER)
	inked(label, 2)
	label.TextXAlignment = Enum.TextXAlignment.Center
	ui.buttonLabel = label

	local function fit()
		local m = require(script.Parent.HUDLayout).metrics(gui.AbsoluteSize)
		local w, h = if m.compact then 190 else 250, if m.compact then 44 else 54
		local e = h + 22
		local over = math.floor(e * 0.3)
		b.Size = UDim2.fromOffset(w, h)
		-- The same slots the old button used, which HUDLayout's neighbours are
		-- already clear of; shifted right by the emblem's overhang so the whole
		-- footprint, overhang included, stays centred on them.
		-- NEVER UNDER THE PIGGY PANEL. Centred on the screen, a 1180-wide
		-- tablet put this button straight across the panel's coin balance
		-- (the panel is scaled 1.3 there). So the centre is pulled left until
		-- the button's right edge clears the panel's drawn left edge by 12.
		local view = gui.AbsoluteSize
		local centre = view.X / 2 + (if m.compact then -56 + over else over)
		local panelLeft = view.X - 14 - m.bankWidth * m.bankScale
		if not m.portrait then
			centre = math.min(centre, panelLeft - 12 - w / 2)
		end
		b.Position = UDim2.fromOffset(centre, if m.compact
			then (if m.portrait then 150 else 12)
			else 96)
		mark.Size = UDim2.fromOffset(e, e)
		mark.Position = UDim2.new(0, -over, 0.5, 0)
		local left = math.floor(e * 0.72)
		label.TextSize = if m.compact then 19 else 24
		label.Position = UDim2.fromOffset(left, 0)
		label.Size = UDim2.new(1, -left - 8, 1, 0)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()

	b.MouseButton1Down:Connect(function() press.PaddingTop = UDim.new(0, 2) end)
	b.MouseButton1Up:Connect(function() press.PaddingTop = UDim.new(0, 0) end)
	b.MouseLeave:Connect(function() press.PaddingTop = UDim.new(0, 0) end)

	b.Activated:Connect(function()
		press.PaddingTop = UDim.new(0, 0)
		Rebirth.open()
	end)
end

local function emphasise()
	if not ui.pop then
		return
	end
	ui.pop.Scale = 1
	TweenService:Create(ui.pop, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out,
		0, true), { Scale = 1.1 }):Play()
end

-- ============================================================
-- THE PAGE
-- ============================================================

-- A benefit card: an art well, a title, a current -> next line and a helper.
local function benefitCard(parent: Instance, order: number, name: string, wellTint: Color3)
	local card = frame(parent, name)
	card.LayoutOrder = order
	Theme.card(card, 16)
	Theme.outline(card, Theme.OUTLINE_THIN)

	local well = frame(card, "Well", wellTint)
	well.AnchorPoint = Vector2.new(0, 0.5)
	Theme.corner(well, 14)
	Theme.gloss(well, wellTint, wellTint:Lerp(Theme.INK, 0.12))

	local title = text(card, "Title", "", 16)
	local value = text(card, "Value", "", 24)
	local helper = text(card, "Helper", "", 14, Theme.MUTED, Enum.Font.GothamMedium)
	helper.TextWrapped = true
	helper.TextYAlignment = Enum.TextYAlignment.Top
	return { card = card, well = well, title = title, value = value, helper = helper }
end

-- A summary card: a coloured head band with a title and a one-line promise,
-- then rows. Built as the concept's RESETS / YOU KEEP pair: the band says
-- which side of the trade you are reading before a word of it is read.
local function sectionCard(parent: Instance, name: string, fill: Color3, edge: Color3,
	heading: string, sub: string?, band: Color3)
	local card = frame(parent, name, fill)
	card.AutomaticSize = Enum.AutomaticSize.Y
	Theme.corner(card, 14)
	Theme.outline(card, Theme.OUTLINE_THIN, edge)
	local pad = Instance.new("UIPadding")
	pad.PaddingBottom = UDim.new(0, 12)
	pad.Parent = card
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = card

	local head = frame(card, "Heading", band)
	head.LayoutOrder = 0
	head.Size = UDim2.new(1, 0, 0, if sub then 50 else 36)
	Theme.corner(head, 14)
	-- Squares off the band's lower corners so it reads as the card's top
	-- rather than as a pill sitting inside it.
	local foot = frame(head, "Square", band)
	foot.AnchorPoint = Vector2.new(0, 1)
	foot.Position = UDim2.fromScale(0, 1)
	foot.Size = UDim2.new(1, 0, 0, 14)
	local title = text(head, "Title", heading, 20, Theme.PAPER)
	inked(title, 1.5)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.Position = UDim2.fromOffset(0, 4)
	title.Size = UDim2.new(1, 0, 0, 24)
	if sub then
		local line = text(head, "Sub", sub, 13, Theme.PAPER, Enum.Font.GothamBold)
		line.TextXAlignment = Enum.TextXAlignment.Center
		line.Position = UDim2.fromOffset(0, 27)
		line.Size = UDim2.new(1, 0, 0, 18)
	end
	return card
end

-- A small rounded chip holding a drawn icon.
local function iconChip(parent: Instance, tint: Color3, size: number, draw: (Frame) -> ()): Frame
	local chip = frame(parent, "Icon", tint)
	chip.Size = UDim2.fromOffset(size, size)
	Theme.corner(chip, 10)
	Theme.outline(chip, 1.5)
	draw(chip)
	return chip
end

local function centred(inst: GuiObject, x: number?, y: number?)
	inst.AnchorPoint = Vector2.new(0.5, 0.5)
	inst.Position = UDim2.fromScale(x or 0.5, y or 0.5)
end

-- One line of a summary card: an icon chip, a name with an optional note under
-- it, and an optional value pill on the right.
local function summaryRow(parent: Instance, order: number, tint: Color3?, draw: ((Frame) -> ())?,
	name: string, note: string?, value: string?, pillTint: Color3?): (Frame, TextLabel?)
	local row = frame(parent, "Row" .. order)
	row.LayoutOrder = order
	local h = if note then 44 else 36
	row.Size = UDim2.new(1, -24, 0, h)
	if draw and tint then
		local chip = iconChip(row, tint, 36, draw)
		chip.AnchorPoint = Vector2.new(0, 0.5)
		chip.Position = UDim2.new(0, 0, 0.5, 0)
	end
	local x = 46
	local valueW = if value then 124 else 0
	local label = text(row, "Name", name, 16, Theme.INK, Theme.FONT)
	label.Position = UDim2.fromOffset(x, if note then 3 else 0)
	label.Size = UDim2.new(1, -(x + valueW + 6), 0, if note then 20 else h)
	label.TextTruncate = Enum.TextTruncate.AtEnd
	if note then
		local n = text(row, "Note", note, 13, Theme.MUTED, Enum.Font.GothamMedium)
		n.Position = UDim2.fromOffset(x, 23)
		n.Size = UDim2.new(1, -(x + valueW + 6), 0, 18)
		n.TextTruncate = Enum.TextTruncate.AtEnd
	end
	local v: TextLabel? = nil
	if value then
		v = text(row, "Value", value, 15, Theme.INK, Theme.FONT)
		v.AnchorPoint = Vector2.new(1, 0.5)
		v.Position = UDim2.new(1, 0, 0.5, 0)
		v.Size = UDim2.fromOffset(valueW, 28)
		v.TextXAlignment = Enum.TextXAlignment.Center
		v.BackgroundTransparency = 0
		v.BackgroundColor3 = pillTint or Theme.PAPER
		Theme.corner(v, 14)
		Theme.outline(v, 1.5, Theme.MUTED_LIGHT)
	end
	return row, v
end

local function linkButton(parent: Instance, name: string, order: number, label: string,
	onPress: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.LayoutOrder = order
	b.BackgroundColor3 = Theme.PAPER_DEEP
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Font = Theme.FONT_BODY
	b.TextSize = 14
	b.TextColor3 = PLUM
	b.Text = label
	b.Size = UDim2.new(0, 190, 0, 30)
	b.Parent = parent
	Theme.corner(b, 10)
	b.Activated:Connect(onPress)
	return b
end

local function buildPage(gui: ScreenGui)
	local page = frame(gui, "RebirthPage")
	page.Size = UDim2.fromScale(1, 1)
	page.Visible = false
	page.ZIndex = Theme.MENU_Z
	ui.page = page

	-- Blocks the HUD underneath and dims the world, so the decision is the
	-- only thing on screen. Tapping it does NOT close the page: a stray tap
	-- beside a card should not throw the reader out mid-sentence.
	local scrim = Instance.new("TextButton")
	scrim.Name = "Scrim"
	scrim.Text = ""
	scrim.AutoButtonColor = false
	scrim.Size = UDim2.fromScale(1, 1)
	scrim.BackgroundColor3 = Theme.SLAB_DEEP
	scrim.BackgroundTransparency = 0.45
	scrim.BorderSizePixel = 0
	scrim.Parent = page

	local shell = frame(page, "Shell", Theme.SAND)
	shell.AnchorPoint = Vector2.new(0.5, 0.5)
	shell.ClipsDescendants = false
	Theme.corner(shell, 20)
	Theme.outline(shell)
	ui.shell = shell
	local settle = Instance.new("UIScale")
	settle.Parent = shell
	ui.settle = settle

	-- ---------- fixed header ----------
	local subtitle = text(shell, "Subtitle", "A stronger fresh start", 16, Theme.MUTED, Theme.FONT)
	subtitle.TextXAlignment = Enum.TextXAlignment.Center
	ui.subtitle = subtitle

	-- The floating plum tab. Lifted over everything built after it.
	local tab = frame(shell, "TitleTab", PLUM)
	tab:SetAttribute("ZBoost", 6)
	tab.AnchorPoint = Vector2.new(0.5, 0)
	Theme.corner(tab, 16)
	Theme.outline(tab)
	Theme.gloss(tab, PLUM_LIGHT, PLUM)
	ui.tab = tab
	local tabMark = emblem(tab, 58, true, true)
	tabMark.AnchorPoint = Vector2.new(0, 0.5)
	ui.tabMark = tabMark
	local title = text(tab, "Title", "REBIRTH", 30, Theme.PAPER)
	inked(title, 2.5)
	title.TextXAlignment = Enum.TextXAlignment.Center
	ui.title = title

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close:SetAttribute("ZBoost", 8)
	close.Text = CROSS
	close.Font = Theme.FONT
	close.TextSize = 30
	close.TextColor3 = Theme.PAPER
	close.BackgroundColor3 = Theme.STOP
	close.BorderSizePixel = 0
	close.Parent = shell
	Theme.corner(close, 12)
	Theme.outline(close)
	Theme.shade(close, 0.85)
	Theme.floatClose(close, 44, 10)
	close.Activated:Connect(function() Rebirth.close() end)

	-- ---------- scrolling body ----------
	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 6
	body.ScrollBarImageColor3 = PLUM
	body.CanvasSize = UDim2.new()
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.ScrollingDirection = Enum.ScrollingDirection.Y
	body.Parent = shell
	ui.body = body
	local bodyPad = Instance.new("UIPadding")
	bodyPad.PaddingTop = UDim.new(0, 4)
	bodyPad.PaddingBottom = UDim.new(0, 8)
	bodyPad.PaddingLeft = UDim.new(0, 4)
	bodyPad.PaddingRight = UDim.new(0, 12)
	bodyPad.Parent = body
	local bodyList = Instance.new("UIListLayout")
	bodyList.Padding = UDim.new(0, 12)
	bodyList.SortOrder = Enum.SortOrder.LayoutOrder
	bodyList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	bodyList.Parent = body

	-- A. the four benefit cards
	local grid = frame(body, "Benefits")
	grid.LayoutOrder = 1
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.CellPadding = UDim2.fromOffset(12, 12)
	gridLayout.Parent = grid
	ui.grid = grid
	ui.gridLayout = gridLayout

	ui.coinCard = benefitCard(grid, 1, "CoinBonus", Theme.GOLD:Lerp(Theme.PAPER, 0.35))
	ui.limitCard = benefitCard(grid, 2, "UpgradeLimit", Theme.COOL:Lerp(Theme.GOOD, 0.5):Lerp(Theme.PAPER, 0.55))
	ui.crateCard = benefitCard(grid, 3, "FreeCrate", PLUM:Lerp(Theme.PAPER, 0.55))
	ui.acornCard = benefitCard(grid, 4, "AcornGrowth", Theme.GOOD:Lerp(Theme.PAPER, 0.25))

	-- B. crate details, expanded in place -- never the shop over this page.
	local crateDetails = sectionCard(body, "CrateDetails", Theme.PAPER, Theme.MUTED_LIGHT,
		"POSSIBLE REWARDS", nil, PLUM)
	crateDetails.LayoutOrder = 2
	crateDetails.Visible = false
	ui.crateDetails = crateDetails

	-- C. what changes
	local changes = frame(body, "Changes")
	changes.LayoutOrder = 3
	changes.AutomaticSize = Enum.AutomaticSize.Y
	local changesLayout = Instance.new("UIListLayout")
	changesLayout.Padding = UDim.new(0, 12)
	changesLayout.SortOrder = Enum.SortOrder.LayoutOrder
	changesLayout.Parent = changes
	ui.changes = changes
	ui.changesLayout = changesLayout
	ui.resets = sectionCard(changes, "Resets", Theme.STOP:Lerp(Theme.PAPER, 0.86),
		Theme.STOP:Lerp(Theme.PAPER, 0.4), "RESETS", "Goes back to the start", Theme.STOP_INK)
	ui.resets.LayoutOrder = 1
	ui.keep = sectionCard(changes, "YouKeep", Theme.GOOD:Lerp(Theme.PAPER, 0.84),
		Theme.GOOD:Lerp(Theme.PAPER, 0.35), "YOU KEEP", "Stays with you forever", Theme.GOOD_INK)
	ui.keep.LayoutOrder = 2

	-- D. the requirement
	local req = frame(body, "Requirement", Theme.PAPER)
	req.LayoutOrder = 4
	req.Size = UDim2.new(1, 0, 0, 58)
	Theme.corner(req, 14)
	Theme.outline(req, Theme.OUTLINE_THIN, Theme.MUTED_LIGHT)
	local reqName = text(req, "Name", "Piggy coins", 15, Theme.INK, Theme.FONT)
	reqName.Position = UDim2.fromOffset(14, 6)
	reqName.Size = UDim2.new(0.5, -14, 0, 22)
	local reqAmount = text(req, "Amount", "", 15, Theme.INK, Theme.FONT_BODY)
	reqAmount.AnchorPoint = Vector2.new(1, 0)
	reqAmount.Position = UDim2.new(1, -118, 0, 6)
	reqAmount.Size = UDim2.new(0.5, -118, 0, 22)
	reqAmount.TextXAlignment = Enum.TextXAlignment.Right
	local track = frame(req, "Track", Theme.PAPER_DEEP)
	track.Position = UDim2.fromOffset(14, 34)
	track.Size = UDim2.new(1, -146, 0, 12)
	Theme.corner(track, 6)
	Theme.outline(track, 1.5)
	local fill = frame(track, "Fill", Theme.GOLD)
	fill.Size = UDim2.fromScale(0, 1)
	Theme.corner(fill, 6)
	local status = text(req, "Status", "", 14, Theme.PAPER, Theme.FONT)
	status.AnchorPoint = Vector2.new(1, 0.5)
	status.Position = UDim2.new(1, -12, 0.5, 0)
	status.Size = UDim2.fromOffset(98, 32)
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.TextWrapped = true
	status.BackgroundTransparency = 0
	Theme.corner(status, 16)
	ui.reqAmount, ui.reqFill, ui.reqStatus = reqAmount, fill, status

	-- ---------- fixed footer ----------
	local footer = frame(shell, "Footer")
	footer.AnchorPoint = Vector2.new(0, 1)
	ui.footer = footer
	local rule = frame(footer, "Rule", Theme.MUTED_LIGHT)
	rule.Size = UDim2.new(1, 0, 0, 2)
	local reminder = text(footer, "Reminder",
		"Your piggy coins and bought upgrades reset. Your collection stays.", 14,
		Theme.MUTED, Enum.Font.GothamMedium)
	reminder.TextXAlignment = Enum.TextXAlignment.Center
	reminder.TextWrapped = true
	ui.reminder = reminder

	local back = button(footer, "NotYet", Theme.PAPER)
	local backLabel = text(back, "Label", "NOT YET", 18)
	backLabel.Size = UDim2.fromScale(1, 1)
	backLabel.TextXAlignment = Enum.TextXAlignment.Center
	back.Activated:Connect(function() Rebirth.close() end)
	ui.back = back

	local confirm = button(footer, "Confirm", PLUM)
	local confirmMark = emblem(confirm, 38, true, true)
	confirmMark.AnchorPoint = Vector2.new(0, 0.5)
	confirmMark.Position = UDim2.new(0, 10, 0.5, 0)
	local confirmLabel = text(confirm, "Label", "REBIRTH", 18, Theme.PAPER)
	inked(confirmLabel, 1.5)
	confirmLabel.Position = UDim2.fromOffset(52, 0)
	confirmLabel.Size = UDim2.new(1, -60, 1, 0)
	confirmLabel.TextXAlignment = Enum.TextXAlignment.Center
	confirmLabel.TextWrapped = true
	ui.confirm, ui.confirmLabel = confirm, confirmLabel
	confirm.Activated:Connect(function()
		-- One deliberate press, sent once. Refused client-side when the
		-- server's own `rebirthReady` says no, or when one is already out.
		if pending.active or not seen.ready or not onConfirm then
			return
		end
		pending.active = true
		pending.from = seen.rebirths
		pending.token += 1
		local token = pending.token
		Rebirth.paintLive()
		onConfirm()
		-- No answer (the server refused, and its toast says why) -> give the
		-- page back with fresh values. Success closes it from `onEconomy`.
		task.delay(5, function()
			if pending.active and pending.token == token then
				pending.active = false
				Rebirth.paintLive()
			end
		end)
	end)

	-- ---------- responsive layout ----------
	local function fit()
		local view = gui.AbsoluteSize
		local narrow = view.X < 560
		local short = view.Y < 520
		local tabOver = if short then 22 else 30
		local w = math.min(780, view.X - 24)
		local h = math.min(640, view.Y - 24 - tabOver)
		shell.Size = UDim2.fromOffset(w, h)
		shell.Position = UDim2.new(0.5, 0, 0.5, math.floor(tabOver / 2))

		local tabH = if short then 50 else 62
		local tabW = math.min(w - 110, if short then 300 else 380)
		tab.Size = UDim2.fromOffset(tabW, tabH)
		tab.Position = UDim2.new(0.5, 0, 0, -tabOver)
		local markSize = tabH + (if short then 32 else 46)
		tabMark.Size = UDim2.fromOffset(markSize, markSize)
		tabMark.Position = UDim2.new(0, -math.floor(markSize * 0.42), 0.5, 0)
		title.TextSize = if short then 24 else 32
		local titleX = math.floor(markSize * 0.6)
		title.Position = UDim2.fromOffset(titleX, 0)
		title.Size = UDim2.new(1, -titleX - 8, 1, 0)

		local subH = if short then 0 else 24
		subtitle.Visible = not short
		subtitle.Position = UDim2.fromOffset(0, tabH - tabOver + 4)
		subtitle.Size = UDim2.new(1, 0, 0, subH)
		local top = tabH - tabOver + 8 + subH

		local buttonsH = if short then 44 else 50
		local reminderH = if narrow then 36 else 20
		local footH = 10 + reminderH + 8 + buttonsH + 12
		footer.Size = UDim2.new(1, -28, 0, footH)
		footer.Position = UDim2.new(0, 14, 1, 0)
		reminder.Position = UDim2.fromOffset(0, 10)
		reminder.Size = UDim2.new(1, 0, 0, reminderH)
		local by = 10 + reminderH + 8
		local backW = if narrow then 110 else 170
		local confirmW = math.min(if narrow then 200 else 300, w - 28 - backW - 34)
		local gap = 12 + math.floor((buttonsH + 22) * 0.3)
		local rowW = backW + gap + confirmW
		local x0 = math.floor((w - 28 - rowW) / 2)
		back.Size = UDim2.fromOffset(backW, buttonsH)
		back.Position = UDim2.fromOffset(x0, by)
		confirm.Size = UDim2.fromOffset(confirmW, buttonsH)
		confirm.Position = UDim2.fromOffset(x0 + backW + gap, by)
		-- Bigger than the button and hanging off its left edge.
		local cm = buttonsH + 22
		confirmMark.Size = UDim2.fromOffset(cm, cm)
		confirmMark.Position = UDim2.new(0, -math.floor(cm * 0.3), 0.5, 0)
		local labelX = math.floor(cm * 0.72)
		confirmLabel.Position = UDim2.fromOffset(labelX, 0)
		confirmLabel.Size = UDim2.new(1, -labelX - 8, 1, 0)
		confirmLabel.TextSize = if narrow then 16 else 19

		body.Position = UDim2.fromOffset(12, top)
		body.Size = UDim2.new(1, -24, 0, h - top - footH)

		-- One column on a narrow screen, two otherwise; cards are sized from
		-- the width actually available, so they never force a sideways scroll.
		local inner = w - 24 - 16
		local cols = if narrow then 1 else 2
		local cellH = if short then 96 else 112
		local cellW = math.floor((inner - (cols - 1) * 12) / cols)
		gridLayout.CellSize = UDim2.fromOffset(cellW, cellH)
		local rows = math.ceil(4 / cols)
		grid.Size = UDim2.new(1, 0, 0, rows * cellH + (rows - 1) * 12)
		for _, c in ipairs({ ui.coinCard, ui.limitCard, ui.crateCard, ui.acornCard }) do
			local wellSize = if short then 62 else 74
			c.well.Size = UDim2.fromOffset(wellSize, wellSize)
			c.well.Position = UDim2.new(0, 12, 0.5, 0)
			local tx = 12 + wellSize + 12
			c.title.Position = UDim2.fromOffset(tx, if short then 8 else 12)
			c.title.Size = UDim2.new(1, -tx - 10, 0, 22)
			c.title.TextSize = if short then 15 else 17
			c.value.Position = UDim2.fromOffset(tx, if short then 30 else 36)
			c.value.Size = UDim2.new(1, -tx - 10, 0, if short then 26 else 30)
			c.value.TextSize = if short then 22 else 26
			c.helper.Position = UDim2.fromOffset(tx, if short then 58 else 68)
			c.helper.Size = UDim2.new(1, -tx - 10, 0, cellH - (if short then 60 else 72))
		end

		-- Resets above You keep when narrow; side by side otherwise.
		changesLayout.FillDirection = if narrow then Enum.FillDirection.Vertical
			else Enum.FillDirection.Horizontal
		changes.Size = UDim2.new(1, 0, 0, 0)
		local half = if narrow then UDim2.new(1, 0, 0, 0) else UDim2.new(0.5, -6, 0, 0)
		ui.resets.Size = half
		ui.keep.Size = half
		ui.crateDetails.Size = UDim2.new(1, 0, 0, 0)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()

	-- Escape or a gamepad B closes the page before a request; nothing on the
	-- keyboard confirms it.
	UserInputService.InputBegan:Connect(function(input)
		if not page.Visible then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			Rebirth.close()
		end
	end)

	layer(page, page.ZIndex + 1)
end

-- ============================================================
-- FILLING IT IN
-- ============================================================

local function clear(parent: Instance, keep: { [string]: boolean })
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("GuiObject") and not keep[child.Name] then
			child:Destroy()
		end
	end
end

local function resetWell(card: any)
	for _, child in ipairs(card.well:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- "+128% -> +136%": the current value muted, the next in plum.
local function compare(now: string, after: string): string
	return ("%s <font color=\"%s\">%s</font> <font color=\"%s\">%s</font>"):format(
		now, MUTED_HEX, ARROW, PLUM_HEX, after)
end

local function ownedSkins(): { [string]: boolean }
	local owned = {}
	for key, skin in pairs((seen.cosmetics and seen.cosmetics.skins) or {}) do
		owned[key] = skin.unlocked == true
	end
	return owned
end

-- The odds line for a crate, from ChestState. nil until that push arrives.
local function oddsLine(chestKey: string): string?
	local state = seen.chests and seen.chests[chestKey]
	local odds = state and state.odds
	if not odds then
		return nil
	end
	local parts = {}
	for _, tier in ipairs(Config.RARITY_ORDER) do
		local pct = odds[tier]
		if pct and pct > 0 then
			local rarity = Config.RARITIES[tier]
			table.insert(parts, ("<font color=\"%s\">%s %d%%</font>"):format(
				hex(Theme.readable(rarity.colour, Theme.PAPER)), rarity.label, math.floor(pct + 0.5)))
		end
	end
	return table.concat(parts, (" %s "):format(DOT))
end

local function drawCoinIcon(chip: Frame)
	centred(Theme.coin(chip, 24))
end

local function drawBarsIcon(chip: Frame)
	for i, hgt in ipairs({ 0.32, 0.5, 0.7 }) do
		local bar = frame(chip, "Bar" .. i, Theme.GOOD)
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.fromScale(0.16 + (i - 1) * 0.24, 0.84)
		bar.Size = UDim2.fromScale(0.18, hgt)
		Theme.corner(bar, 2)
		Theme.outline(bar, 1)
	end
end

local function drawPigIcon(chip: Frame)
	if not image(chip, "Piggy", ICONS.piggy, 0.95) then
		centred(Theme.snout(chip, 22))
	end
end

local function drawGearIcon(chip: Frame)
	centred(Theme.gear(chip, 24))
end

local function drawAcornIcon(chip: Frame)
	centred(Theme.acorn(chip, 24))
end

local function drawBagIcon(chip: Frame)
	centred(Theme.satchel(chip, 24))
end

local function drawEmblemIcon(chip: Frame)
	if not image(chip, "Art", ICONS.rebirthEmblem, 1) then
		drawCoinIcon(chip)
	end
end

-- A little house: a roof square turned 45 degrees behind a body, so only its
-- top half shows as a gable.
local function drawHouseIcon(chip: Frame)
	local roof = frame(chip, "Roof", Theme.STOP)
	centred(roof, 0.5, 0.44)
	roof.Size = UDim2.fromScale(0.46, 0.46)
	roof.Rotation = 45
	Theme.outline(roof, 1.5)
	local body = frame(chip, "Body", Theme.PAPER)
	body.AnchorPoint = Vector2.new(0.5, 1)
	body.Position = UDim2.fromScale(0.5, 0.84)
	body.Size = UDim2.fromScale(0.5, 0.36)
	Theme.outline(body, 1.5)
	local door = frame(body, "Door", Theme.ACORN)
	door.AnchorPoint = Vector2.new(0.5, 1)
	door.Position = UDim2.fromScale(0.5, 1)
	door.Size = UDim2.fromScale(0.3, 0.62)
end

-- The default Classic Pink piggy with its reward around it: a gold coin
-- stack at its feet and a green "+%" badge, which is the permanent bonus.
local function drawCoinBonus(well: Frame)
	local piggy = image(well, "Piggy", ICONS.piggy, 0.74)
	if piggy then
		piggy.Position = UDim2.fromScale(0.42, 0.5)
	else
		centred(Theme.snout(well, 34), 0.42, 0.5)
	end
	for i, spot in ipairs({ { 0.7, 0.84 }, { 0.86, 0.84 }, { 0.78, 0.7 } }) do
		centred(Theme.coin(well, 20, "Coin" .. i), spot[1], spot[2])
	end
	local badge = text(well, "Plus", "+%", 13, Theme.PAPER, Theme.FONT)
	badge.TextXAlignment = Enum.TextXAlignment.Center
	badge.BackgroundTransparency = 0
	badge.BackgroundColor3 = Theme.GOOD_INK
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, 6, 0, -6)
	badge.Size = UDim2.fromOffset(32, 22)
	Theme.corner(badge, 11)
	Theme.outline(badge, 2)
end

-- Acorns an hour, trimmed: "1.36", "2", "2.5".
local function perHour(value: number): string
	local out = ("%.2f"):format(value)
	out = out:gsub("0+$", "")
	out = out:gsub("%.$", "")
	return out
end

local function drawCrate(well: Frame, colour: Color3)
	local box = frame(well, "Crate", Theme.SAND_DEEP)
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.55)
	box.Size = UDim2.fromScale(0.72, 0.58)
	Theme.corner(box, 6)
	Theme.outline(box, Theme.OUTLINE_THIN)
	local lid = frame(well, "Lid", Theme.PAPER_DEEP)
	lid.AnchorPoint = Vector2.new(0.5, 1)
	lid.Position = UDim2.fromScale(0.5, 0.3)
	lid.Size = UDim2.fromScale(0.8, 0.16)
	Theme.corner(lid, 5)
	Theme.outline(lid, Theme.OUTLINE_THIN)
	for _, x in ipairs({ 0.18, 0.7 }) do
		local band = frame(box, "Band", colour)
		band.Position = UDim2.fromScale(x, 0)
		band.Size = UDim2.fromScale(0.12, 1)
	end
	local star = text(box, "Mark", "?", 22, Theme.INK, Theme.FONT)
	star.TextXAlignment = Enum.TextXAlignment.Center
	star.Size = UDim2.fromScale(1, 1)
end

-- A rising staircase of bars BEHIND a piggy: "your ladder goes higher". The
-- bars are built first so the piggy stands in front of them rather than
-- having them pasted over its side; each is outlined in ink so it reads
-- against the teal well rather than merging with it.
local function drawLimit(well: Frame)
	for i, hgt in ipairs({ 0.3, 0.48, 0.66 }) do
		local bar = frame(well, "Bar" .. i, Theme.GOOD)
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.fromScale(0.5 + (i - 1) * 0.155, 0.84)
		bar.Size = UDim2.fromScale(0.12, hgt)
		Theme.corner(bar, 4)
		Theme.outline(bar, 2)
		Theme.gloss(bar, Theme.GOOD:Lerp(Theme.PAPER, 0.25), Theme.GOOD:Lerp(Theme.INK, 0.15))
	end
	local piggy = image(well, "Piggy", ICONS.piggy, 0.6)
	if piggy then
		piggy.Position = UDim2.fromScale(0.3, 0.64)
	else
		local s = Theme.snout(well, 36)
		s.AnchorPoint = Vector2.new(0.5, 0.5)
		s.Position = UDim2.fromScale(0.36, 0.6)
	end
end

local function fill()
	if not ui.page then
		return
	end
	local r = seen.rebirths
	local nextR = r + 1
	ui.title.Text = ("REBIRTH <font color=\"%s\">%d</font>"):format(GOLD_HEX, nextR)

	-- ---------- A. benefits ----------
	local c = ui.coinCard
	c.title.Text = "Permanent coin bonus"
	c.value.Text = compare(("+%d%%"):format(Config.rebirthBonusPercent(r)),
		("+%d%%"):format(Config.rebirthBonusPercent(nextR)))
	c.helper.Text = "Applies at every income level"
	resetWell(c)
	drawCoinBonus(c.well)

	local l = ui.limitCard
	local capNow, capNext = Config.maxLevel(r), Config.maxLevel(nextR)
	l.title.Text = "Higher upgrade limit"
	if capNext > capNow then
		l.value.Text = compare(("Lv %d"):format(capNow), ("Lv %d"):format(capNext))
		l.helper.Text = "Earn Faster + Bigger Piggy Bank"
	else
		l.value.Text = ("Lv %d"):format(capNow)
		l.helper.Text = "All upgrade levels unlocked"
	end
	resetWell(l)
	drawLimit(l.well)

	local owned = ownedSkins()
	local open = Config.rebirthCratesOpen(owned)
	local k = ui.crateCard
	resetWell(k)
	clear(k.card, { Well = true, Title = true, Value = true, Helper = true })
	if #open == 0 then
		-- Nothing left to open: the page says the Acorns, never a crate.
		local bonus = Config.rebirthCrateBonus()
		k.title.Text = "Collections complete"
		k.value.Text = ("%d %s"):format(bonus, Config.lootWord(bonus))
		k.helper.Text = "Every Legendary collected, so you get Acorns instead"
		local acorn = Theme.acorn(k.well, 48)
		acorn.AnchorPoint = Vector2.new(0.5, 0.5)
		acorn.Position = UDim2.fromScale(0.5, 0.5)
		expanded.crate = false
	else
		local first = Config.CHESTS[open[1]]
		k.title.Text = "Free crate opening"
		k.value.Text = if #open == 1 then first.name else "Legendary crate"
		k.value.TextTruncate = Enum.TextTruncate.AtEnd
		-- Identical odds across the eligible crates print once; different
		-- ones defer to the detail list rather than picking one to show.
		local line = oddsLine(open[1])
		for i = 2, #open do
			if oddsLine(open[i]) ~= line then
				line = "Odds vary by crate"
			end
		end
		k.helper.Text = line or ("Random pick %s not a set skin"):format(DOT)
		drawCrate(k.well, first.colour)
		local link = Instance.new("TextButton")
		link.Name = "ViewRewards"
		link.BackgroundTransparency = 1
		link.Font = Theme.FONT_BODY
		link.TextSize = 14
		link.TextColor3 = PLUM
		link.TextXAlignment = Enum.TextXAlignment.Right
		link.Text = (if expanded.crate then "Hide rewards %s" else "View rewards %s"):format(CHEVRON)
		link.AnchorPoint = Vector2.new(1, 0)
		link.Position = UDim2.new(1, -10, 0, 12)
		link.Size = UDim2.fromOffset(130, 22)
		link.Parent = k.card
		link.Activated:Connect(function()
			expanded.crate = not expanded.crate
			fill()
		end)
		k.title.Size = UDim2.new(1, -(k.title.Position.X.Offset + 146), 0, 22)
	end

	local a = ui.acornCard
	local treeNow = math.floor((Config.treeRebirthFactor(r, true) - 1) * 100 + 0.5)
	local treeNext = math.floor((Config.treeRebirthFactor(nextR, true) - 1) * 100 + 0.5)
	a.title.Text = "Online Acorn growth"
	-- Acorns an hour from `treeGrowthPerHour` -- the one function the
	-- server's live tick grows the tree with -- at this tree's level.
	local rateLine = "While you're playing"
	if seen.treeLevel then
		local now = Config.treeGrowthPerHour(seen.treeLevel, r, true)
		local after = Config.treeGrowthPerHour(seen.treeLevel, nextR, true)
		rateLine = if after > now
			then ("%s %s <font color=\"%s\"><b>%s</b></font> acorns an hour"):format(
				perHour(now), ARROW, PLUM_HEX, perHour(after))
			else ("%s acorns an hour"):format(perHour(now))
	end
	if treeNext > treeNow then
		a.value.Text = compare(("+%d%%"):format(treeNow), ("+%d%%"):format(treeNext))
		a.helper.Text = rateLine
	else
		a.value.Text = ("+%d%%"):format(treeNow)
		a.helper.Text = rateLine .. " (max bonus)"
	end
	resetWell(a)
	if not image(a.well, "Art", ICONS.acornTree, 0.95) then
		local acorn = Theme.acorn(a.well, 48)
		acorn.AnchorPoint = Vector2.new(0.5, 0.5)
		acorn.Position = UDim2.fromScale(0.5, 0.5)
	end

	-- ---------- B. crate details ----------
	local details = ui.crateDetails
	clear(details, { Heading = true })
	details.Visible = expanded.crate and #open > 0
	if details.Visible then
		local order = 0
		local function line(value: string, colour: Color3?, size: number?)
			order += 1
			local t = text(details, "Line" .. order, value, size or 14, colour or Theme.INK,
				Enum.Font.GothamMedium)
			t.LayoutOrder = order
			t.TextWrapped = true
			t.AutomaticSize = Enum.AutomaticSize.Y
			t.Size = UDim2.new(1, -24, 0, 20)
		end
		-- The pick among eligible crates is uniform on the server
		-- (`open[math.random(#open)]`), so the share is derived from the count.
		local share = math.floor(100 / #open + 0.5)
		for _, key in ipairs(open) do
			local chest = Config.CHESTS[key]
			local pool = Config.chestPool(key)
			local legendaries = pool.legendary or {}
			local have = 0
			for _, skin in ipairs(legendaries) do
				if owned[skin] then have += 1 end
			end
			local head = if #open > 1
				then ("<b>%s</b>  %s %d%% chance of this crate"):format(chest.name, DOT, share)
				else ("<b>%s</b>"):format(chest.name)
			line(head, Theme.INK, 16)
			local odds = oddsLine(key)
			if odds then
				line(odds)
			end
			line(("Legendaries owned: %d / %d"):format(have, #legendaries), Theme.MUTED)
		end
		line("One free opening. A new skin isn't guaranteed: a copy you already own "
			.. "becomes a spare you can sell or combine.", Theme.MUTED)
	end

	-- ---------- C. what changes ----------
	local resets = ui.resets
	clear(resets, { Heading = true })
	local pill = Theme.STOP:Lerp(Theme.PAPER, 0.92)
	local _, coinsValue = summaryRow(resets, 1, Theme.GOLD:Lerp(Theme.PAPER, 0.35), drawCoinIcon,
		"Piggy coins", "Even past the goal",
		("%s %s 0"):format(format(seen.coins), ARROW), pill)
	ui.coinsValue = coinsValue
	local order = 1
	if seen.incomeLevel > 1 then
		order += 1
		summaryRow(resets, order, Theme.GOOD:Lerp(Theme.PAPER, 0.45), drawBarsIcon,
			"Earn Faster", nil, ("Lv %d %s 1"):format(seen.incomeLevel, ARROW), pill)
	end
	if seen.capacityLevel > 1 then
		order += 1
		summaryRow(resets, order, Theme.PIG:Lerp(Theme.PAPER, 0.35), drawPigIcon,
			"Bigger Piggy Bank", nil, ("Lv %d %s 1"):format(seen.capacityLevel, ARROW), pill)
	end
	local trees = {}
	for _, info in pairs(seen.upgrades or {}) do
		if (info.level or 0) > 0 then
			table.insert(trees, info)
		end
	end
	-- Defence then offence, each in the shop's own order.
	table.sort(trees, function(x, y)
		if x.tree ~= y.tree then
			return x.tree == "defense"
		end
		return (x.order or 99) < (y.order or 99)
	end)
	if #trees > 0 then
		order += 1
		summaryRow(resets, order, Theme.SAND_DEEP, drawGearIcon,
			"Bought upgrades", "Your Defend and Rob trees",
			("%d %s 0"):format(#trees, ARROW), pill)
		if expanded.upgrades then
			for _, t in ipairs(trees) do
				order += 1
				local row = summaryRow(resets, order, nil, nil, t.name, nil,
					("Lv %d %s 0"):format(t.level, ARROW), pill)
				row.Size = UDim2.new(1, -24, 0, 30)
			end
		end
		order += 1
		linkButton(resets, "ViewUpgrades", order,
			(if expanded.upgrades then "Hide upgrades %s" else "View upgrades %s"):format(CHEVRON),
			function()
				expanded.upgrades = not expanded.upgrades
				fill()
			end)
	end

	-- A rule, not an inventory: "nothing you collected goes" is total, where a
	-- count read off a stale push could disagree with the server.
	local keep = ui.keep
	clear(keep, { Heading = true })
	for i, row in ipairs({
		{ Theme.PIG:Lerp(Theme.PAPER, 0.35), drawPigIcon, "Skins and collection", "Every skin, trophy and set item" },
		{ Theme.STOP:Lerp(Theme.PAPER, 0.65), drawHouseIcon, "Home and lawn", "Houses, garden and decorations" },
		{ Theme.COOL:Lerp(Theme.PAPER, 0.5), drawBagIcon, "Rides and items", "Wearables, bones and gadgets" },
		{ Theme.ACORN_CAP:Lerp(Theme.PAPER, 0.45), drawAcornIcon, "Acorns and guard dog", "Your acorns, tree and dog" },
		{ PLUM:Lerp(Theme.PAPER, 0.5), drawEmblemIcon, "Rebirths and records",
			("All %d rebirths and your stats"):format(nextR) },
	}) do
		summaryRow(keep, i, row[1], row[2], row[3], row[4])
	end

	Rebirth.paintLive()
	layer(ui.page, ui.page.ZIndex + 1)
end

-- The parts that move with every coin: the requirement, the coin reset row
-- and the confirm. Cheap, so it runs on every economy push.
function Rebirth.paintLive()
	if not ui.page then
		return
	end
	local threshold = Config.getRebirthThreshold(seen.rebirths)
	local ratio = if threshold > 0 then math.clamp(seen.coins / threshold, 0, 1) else 1
	ui.reqAmount.Text = ("%s / %s"):format(format(seen.coins), format(threshold))
	ui.reqFill.Size = UDim2.fromScale(ratio, 1)
	ui.reqFill.BackgroundColor3 = if seen.ready then Theme.GOOD else Theme.GOLD
	if seen.ready then
		ui.reqStatus.Text = "READY"
		ui.reqStatus.TextSize = 15
		ui.reqStatus.BackgroundColor3 = Theme.GOOD_INK
		ui.reqStatus.TextColor3 = Theme.PAPER
	else
		ui.reqStatus.Text = ("%s more"):format(format(math.max(0, threshold - seen.coins)))
		ui.reqStatus.TextSize = 13
		ui.reqStatus.BackgroundColor3 = Theme.WARN:Lerp(Theme.PAPER, 0.7)
		ui.reqStatus.TextColor3 = Theme.INK
	end
	if ui.coinsValue then
		ui.coinsValue.Text = ("%s %s 0"):format(format(seen.coins), ARROW)
	end

	local usable = seen.ready and not pending.active
	ui.confirm.AutoButtonColor = usable
	ui.confirm.BackgroundColor3 = if usable then PLUM else PLUM:Lerp(Theme.MUTED_LIGHT, 0.55)
	ui.confirmLabel.Text = if pending.active
		then "Rebirthing" .. ELLIPSIS
		elseif seen.ready then ("REBIRTH TO <font color=\"%s\">%d</font>"):format(GOLD_HEX, seen.rebirths + 1)
		else "NOT READY YET"
end

-- ============================================================
-- API
-- ============================================================

function Rebirth.open()
	if not ui.page then
		return
	end
	expanded.crate = false
	expanded.upgrades = false
	fill()
	ui.body.CanvasPosition = Vector2.zero
	ui.page.Visible = true
	ui.settle.Scale = 0.96
	TweenService:Create(ui.settle, TweenInfo.new(0.16, Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out), { Scale = 1 }):Play()
	Rebirth.sync()
end

function Rebirth.close()
	if ui.page then
		ui.page.Visible = false
	end
	Rebirth.sync()
end

function Rebirth.isOpen(): boolean
	return ui.page ~= nil and ui.page.Visible
end

function Rebirth.sync()
	if not ui.button then
		return
	end
	local allowed = if Rebirth.canShow then Rebirth.canShow() else true
	local show = seen.ready and allowed and not Rebirth.isOpen()
	local was = ui.button.Visible
	ui.button.Visible = show
	if show and not was and ui.emphasiseNext then
		ui.emphasiseNext = false
		emphasise()
	end
end

function Rebirth.onEconomy(state: any)
	local before = seen.rebirths
	local wasReady = seen.ready
	seen.coins = state.coins or 0
	seen.incomeLevel = state.incomeLevel or 1
	seen.capacityLevel = state.capacityLevel or 1
	seen.rebirths = state.rebirths or 0
	seen.ready = state.rebirthReady == true
	local treeBefore = seen.treeLevel
	seen.treeLevel = state.treeLevel
	if ui.buttonLabel then
		ui.buttonLabel.Text = ("REBIRTH <font color=\"%s\">%d</font>"):format(GOLD_HEX, seen.rebirths + 1)
	end
	-- One pop the first time readiness turns on, whenever the button is next
	-- actually on screen to be seen doing it.
	if seen.ready and not wasReady then
		ui.emphasiseNext = true
	end

	if seen.rebirths > before then
		-- The rebirth happened. A page left open would describe a trade that
		-- is already made -- the receipt this file exists to avoid.
		pending.active = false
		if Rebirth.isOpen() then
			Rebirth.close()
		end
	elseif Rebirth.isOpen() then
		if seen.treeLevel ~= treeBefore
			or seen.incomeLevel ~= (ui.lastIncome or seen.incomeLevel)
			or seen.capacityLevel ~= (ui.lastCapacity or seen.capacityLevel) then
			fill()
		else
			Rebirth.paintLive()
		end
	end
	ui.lastIncome, ui.lastCapacity = seen.incomeLevel, seen.capacityLevel
	Rebirth.sync()
end

function Rebirth.onUpgrades(list: any)
	seen.upgrades = list
	if Rebirth.isOpen() then fill() end
end

function Rebirth.onCosmetics(c: any)
	seen.cosmetics = c
	if Rebirth.isOpen() then fill() end
end

function Rebirth.onRides(list: any)
	seen.rides = list
end

function Rebirth.onChest(payload: any)
	seen.chests = payload and payload.chests
	if Rebirth.isOpen() then fill() end
end

-- Keeps the existing injection signature; the page draws its own art now.
function Rebirth.init(gui: ScreenGui, confirm: () -> (),
	_icon: ((GuiObject, Model, UDim2, UDim2, boolean) -> Instance)?)
	onConfirm = confirm
	buildButton(gui)
	buildPage(gui)
	RunService.Heartbeat:Connect(function()
		if not (ui.button.Visible or ui.page.Visible) then
			return
		end
		local angle = (os.clock() * SPIN_RATE) % 360
		for _, ring in ipairs(spinners) do
			ring.Rotation = angle
		end
	end)
end

return Rebirth
