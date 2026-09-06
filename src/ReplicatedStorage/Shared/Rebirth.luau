--!strict
--[[
	Rebirth

	The rebirth button, and the page that explains the trade before a player
	makes it for the first time.

	A module for the reason `HouseFX`, `SpinWheel`, `AdminPanel` and `HotBar`
	are: `ClientMain` is one chunk against Luau's 200-local ceiling. Moving the
	button in here with the page hands two registers back rather than costing
	one.

	----------------------------------------------------------------------

	THE PAGE COMES BEFORE THE REBIRTH, NOT AFTER IT.

	"Here is what you kept and what you lost" shown after the button is a
	RECEIPT. Everything on it is already true and there is nothing the player
	can do about any of it, which for a nine-year-old who did not understand
	what they were pressing is the worst possible moment to explain. Shown
	first it is a DECISION: the same words, the same two columns, and a way
	out at the bottom.

	It is also why the confirm is worded NOT YET rather than CANCEL. Nothing
	here is a mistake to be undone; they are deciding whether they are ready.

	----------------------------------------------------------------------

	IT SHOWS ON THE FIRST REBIRTH ONLY, and that is `rebirths == 0` rather
	than a saved flag.

	The question the page answers is "what does this button do", and that is
	asked once. A veteran on their ninth reset who has to clear a confirmation
	every time learns to tap through it without reading, which is worse than
	no page at all -- the dialogue everyone dismisses reflexively is the one
	that fails when it finally matters.

	`rebirths` is already pushed, already authoritative and already persisted,
	so there is no new save field and no way for the flag to disagree with
	reality. `FIRST_TIME_ONLY` below is the one line to change if it should
	ever ask every time.

	----------------------------------------------------------------------

	THE NUMBERS ARE REAL, WHICH IS THE ENTIRE POINT.

	A page reading "you will lose your upgrades" is a definition. One reading
	"Fence Lv 4, Guard Dog Lv 2, Speed Boots Lv 3" is somebody's actual
	afternoon, and the difference decides whether they understand the trade or
	merely read about it. Everything here comes from the same pushes the HUD
	is already drawing, so nothing is computed twice and nothing can drift.

	Only levels ABOVE ZERO are listed on the LOSE side. An upgrade never
	bought is not a loss, and padding the scary column with things the player
	does not own would overstate the cost of the one decision this game most
	wants them to make.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local PiggyModel = require(ReplicatedStorage.Shared.PiggyModel)

local Rebirth = {}

-- Change to false and the page asks every time. See the note above for why it
-- does not: a confirmation nobody reads is worse than none.
local FIRST_TIME_ONLY = true

-- A FOURTH PALETTE, AND IT WAS THE OLD ONE. Six locals here, eight in
-- AdminPanel, five in ClientMain and a whole table in ShopStyle: four files
-- each deciding what a near-black is. They are names for `Theme` now.
local GOLD = Theme.GOLD
local INK = Theme.INK
local PANEL = Theme.PAPER
-- Printed as TEXT on paper rather than used as a fill, so these are the
-- darkened forms. Measured before: the KEEP green read 1.86 against the
-- card and the LOSE red 3.51, on the two columns the whole page is.
local KEEP = Theme.GOOD_INK
local LOSE = Theme.STOP_INK
-- REBIRTH HAS ITS OWN COLOUR NOW. This was `Theme.HUE.effects` -- the
-- shop's particle-effects tab -- so the loudest button on the HUD wore a
-- colour whose only job was to say 'this tab'. See `Theme.PRESTIGE`.
local PLUM = Theme.PRESTIGE

local STAR = utf8.char(0x2605)
local SPARK = utf8.char(0x2728)
-- MEASURED, NOT CHOSEN. Half the obvious dingbats are simply absent from
-- Roblox's Gotham and render as a tofu box -- U+2718, U+2715 and U+2717 all
-- do, and all three measured an identical 20.0 wide, which is the fallback
-- width rather than a glyph. Worse, the one that IS present in the heavy
-- weight, U+2714, is an EMOJI-presentation glyph: it draws in its own grey
-- and ignores TextColor3 entirely, the same trap the notification chips hit.
-- These two are text-presentation, present, and take the colour they are
-- given. Anything added here gets rendered and looked at before it is used.
local TICK = utf8.char(0x2713)
local CROSS = utf8.char(0x00D7)

local button: TextButton
local starChip: TextLabel
local page: Frame
local keepList: ScrollingFrame
local loseList: ScrollingFrame
local unlockList: Frame
-- HANDED IN BY `init` RATHER THAN WRITTEN AGAIN. `makeModelIcon` lives in
-- ClientMain and knows things this module has no business knowing -- how to
-- frame a model from its own bounding box, which way to tilt it, that the
-- icon copy re-centres on its VISUAL centre while the world copy keeps its
-- authored pivot. A second nearly-identical viewport helper is the copy that
-- drifts the first time either is touched.
local makeIcon: ((GuiObject, Model, UDim2, UDim2, boolean) -> Instance)?
local pageTitle: TextLabel
local confirmButton: TextButton

-- Set by ClientMain: the button is a HUD overlay pinned near the top of the
-- screen, which is exactly where the shop panel's header sits.
Rebirth.canShow = nil :: (() -> boolean)?
local onConfirm: (() -> ())? = nil

-- Whatever the HUD last knew. The page is built from these when it opens
-- rather than kept in step every frame -- it is a page somebody reads once,
-- not a readout.
local seen = {
	coins = 0,
	incomeLevel = 1,
	capacityLevel = 1,
	rebirths = 0,
	ready = false,
	upgrades = nil :: any,
	cosmetics = nil :: any,
	rides = nil :: any,
}

-- ZINDEX IS NOT INHERITED UNDER `ZIndexBehavior.Global`, where it orders every
-- GuiObject in the ScreenGui against every other one -- so a page lifted above
-- the HUD by ZIndex draws over its OWN CHILDREN and renders as an empty
-- rectangle. The game's HUD is `Sibling`, where a child always draws above its
-- parent and none of this matters, which is exactly what makes it dangerous:
-- it works until somebody parents this page somewhere else, and then it fails
-- silently and completely. Caught on a probe ScreenGui that defaulted to
-- Global. Depth decides the layering here, explicitly, so it renders the same
-- under either behaviour.
local function layer(root: Instance, z: number)
	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("GuiObject") then
			child.ZIndex = z
			layer(child, z + 1)
		end
	end
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function format(value: number): string
	local suffixes = { "", "K", "M", "B", "T" }
	local n = math.floor(value)
	local i = 1
	while n >= 1000 and i < #suffixes do
		n //= 1000
		i += 1
	end
	if i == 1 then
		return tostring(math.floor(value))
	end
	return ("%.1f%s"):format(math.floor(value) / (1000 ^ (i - 1)), suffixes[i])
end

-- ============================================================
-- THE BUTTON
-- ============================================================

local function buildButton(gui: ScreenGui)
	button = Instance.new("TextButton")
	button.Name = "RebirthButton"
	button.Size = UDim2.new(0, 232, 0, 54)
	button.Position = UDim2.new(0.5, 0, 0, 96)
	button.AnchorPoint = Vector2.new(0.5, 0)
	button.BackgroundColor3 = PLUM
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Text = ""
	button.Visible = false
	button.Parent = gui
	corner(button, 12)

	-- THE ONE SURFACE IN THIS GAME THAT NEVER GOT THE INK OUTLINE, and it is
	-- the loudest control on the HUD. `Theme` calls that line "the whole
	-- trick" -- it is what makes a card read as drawn rather than as a
	-- rectangle, and it is what gives a pale surface an edge against bright
	-- grass. This button had a 2px violet stroke at 0.55 transparency
	-- instead: a glow, which worked on the old dark HUD and against cream
	-- cards in full sun is not an edge at all.
	Theme.outline(button)
	Theme.shade(button, 0.88)

	-- SO THE PULSE MOVED BEHIND IT, because a GuiObject takes exactly ONE
	-- UIStroke and the ink line is not negotiable. A halo is a separate frame
	-- sitting a few pixels proud of the button on every side, which is the
	-- only way to have a drawn edge AND something that breathes.
	--
	-- BREATHING, NOT BLINKING. The standard treats more than three flashes a
	-- second as unsafe and this audience is nine, so the same ceiling
	-- `HouseFX` works to applies here: one continuous curve at about 0.45
	-- cycles a second. It draws the eye to a control that only exists when it
	-- is worth pressing.
	-- A SIBLING, NOT A CHILD, AND THAT IS THE WHOLE OF WHY. Under
	-- `ZIndexBehavior.Sibling` -- which this HUD uses -- a child always draws
	-- ABOVE its parent whatever its ZIndex, so a halo parented to the button
	-- covers the button, its gloss and, worst of all, the 3px ink line it was
	-- added to sit behind. Measured as a 0.62-transparent violet wash over
	-- the one thing on this control that must stay hard and dark.
	--
	-- As a sibling with a lower ZIndex it draws underneath, which is what a
	-- halo is. The cost is that it no longer inherits the button's `Visible`,
	-- so that is mirrored below rather than set in the two places that toggle
	-- the button -- a watcher cannot drift out of step with what it watches.
	button.ZIndex = 2
	local halo = Instance.new("Frame")
	halo.Name = "RebirthHalo"
	halo.AnchorPoint = button.AnchorPoint
	-- The button anchors at its TOP (0.5, 0), so a halo 14 studs taller has
	-- to come up by half of that or it hangs off the bottom instead of
	-- ringing the button. Derived from the same 14 rather than written twice.
	halo.Position = button.Position - UDim2.fromOffset(0, 7)
	halo.Size = UDim2.new(0, button.Size.X.Offset + 14, 0, button.Size.Y.Offset + 14)
	-- LIGHTER THAN THE BUTTON, or it is a shadow rather than a glow. The fill
	-- went deep, and a deep halo washed over grass reads as something spilt
	-- behind the button; lifted toward paper it reads as light coming off it.
	halo.BackgroundColor3 = PLUM:Lerp(Theme.PAPER, 0.45)
	halo.BackgroundTransparency = 0.62
	halo.BorderSizePixel = 0
	halo.ZIndex = 1
	halo.Visible = false
	halo.Parent = gui
	corner(halo, 17)
	button:GetPropertyChangedSignal("Visible"):Connect(function()
		halo.Visible = button.Visible
	end)
	TweenService:Create(halo,
		TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ BackgroundTransparency = 0.9 }):Play()

	local glyph = Instance.new("TextLabel")
	glyph.Name = "Icon"
	glyph.Size = UDim2.new(0, 30, 1, 0)
	glyph.Position = UDim2.new(0, 10, 0, 0)
	glyph.BackgroundTransparency = 1
	glyph.Font = Enum.Font.GothamBold
	glyph.TextSize = 24
	-- Never set before, so it sat on Roblox's default (27, 42, 53) -- a cold
	-- navy, and the last one in the project. The glyph is an emoji and
	-- ignores this, which is exactly why it survived: an uninitialised
	-- colour is invisible until the day something stops being an emoji.
	glyph.TextColor3 = Theme.PAPER
	glyph.Text = SPARK
	glyph.ZIndex = 3
	glyph.Parent = button

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, -96, 1, 0)
	label.Position = UDim2.new(0, 44, 0, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 22
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Theme.PAPER
	label.Text = "REBIRTH"
	label.ZIndex = 3
	label.Parent = button

	-- The star you would BECOME, not the one you are. It is the reward the
	-- whole button is selling, so it is the one number on it.
	--
	-- NOT the keyboard-gated chip the action buttons carry: that one is a
	-- keybind and hides itself on a tablet, and a tablet player still needs
	-- to see what they are about to earn.
	starChip = Instance.new("TextLabel")
	starChip.Name = "Star"
	starChip.Size = UDim2.new(0, 44, 0, 26)
	starChip.Position = UDim2.new(1, -10, 0.5, 0)
	starChip.AnchorPoint = Vector2.new(1, 0.5)
	-- GOLD GROUND, INK NUMERAL -- the inverse of what it was. An ink chip on
	-- the old light violet worked; on a deep plum it is 2.08 and vanishes.
	-- Gold on plum is 5.48 and ink on gold 10.53, so both halves of the one
	-- thing naming the reward finally read.
	starChip.BackgroundColor3 = Theme.GOLD
	starChip.BackgroundTransparency = 0
	starChip.BorderSizePixel = 0
	starChip.Font = Enum.Font.GothamBold
	starChip.TextSize = 14
	starChip.TextColor3 = Theme.INK
	starChip.Text = "1" .. STAR
	starChip.ZIndex = 3
	starChip.Parent = button
	corner(starChip, 6)

	button.Activated:Connect(function()
		if FIRST_TIME_ONLY and seen.rebirths > 0 then
			if onConfirm then
				onConfirm()
			end
			return
		end
		Rebirth.open()
	end)
end

-- ============================================================
-- THE PAGE
-- ============================================================

local function makeRow(parent: Instance, order: number, mark: string,
	tint: Color3, text: string, note: string?)

	local row = Instance.new("Frame")
	row.Name = "Row"
	row.Size = UDim2.new(1, -6, 0, 24)
	row.LayoutOrder = order
	row.BackgroundTransparency = 1
	row.Parent = parent

	local glyph = Instance.new("TextLabel")
	glyph.Size = UDim2.new(0, 18, 1, 0)
	glyph.BackgroundTransparency = 1
	glyph.Font = Enum.Font.GothamBold
	glyph.TextSize = 13
	glyph.TextColor3 = tint
	glyph.Text = mark
	glyph.Parent = row

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -22, 1, 0)
	label.Position = UDim2.new(0, 22, 0, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	-- INK, NOT MUTED. `makeRow` serves three lists and one of them -- YOU
	-- UNLOCK -- sits on a SAND_DEEP band rather than on a PAPER card, where
	-- faded ink measured 4.30 against a floor of 4.5. These are the three
	-- most consequential sentences on the page; none of them is secondary
	-- text, and the tick, cross or star beside each already carries the tone.
	label.TextColor3 = Theme.INK
	label.Text = text
	label.Parent = row

	return row
end

-- A TILE, NOT A SENTENCE.
--
-- "The Bronze skin, yours to wear" is a thing you READ; a Bronze piggy is a
-- thing you WANT, and this page exists to make somebody want to press the
-- button. It is the same argument the shop already settled -- nineteen lawn
-- ornaments were identical grey squares until the cards rendered the real
-- item -- arriving on the one screen where the decision is largest.
--
-- The well is PAPER rather than the shop's dark SUNK: this band is already a
-- warm tan, and a near-black hole punched into it reads as damage. A small
-- light card on a tan band reads as something laid on top.
local function unlockTile(order: number, caption: string,
	fillWell: (Frame) -> (), badge: string?)

	local tile = Instance.new("Frame")
	tile.Name = "Gain" .. order
	tile.Size = UDim2.new(0, 128, 0, 120)
	tile.LayoutOrder = order
	tile.BackgroundTransparency = 1
	tile.Parent = unlockList

	local well = Instance.new("Frame")
	well.Name = "Well"
	well.Size = UDim2.new(0, 76, 0, 76)
	well.Position = UDim2.new(0.5, 0, 0, 0)
	well.AnchorPoint = Vector2.new(0.5, 0)
	well.BackgroundColor3 = Theme.PAPER
	well.BorderSizePixel = 0
	well.Parent = tile
	corner(well, 14)
	Theme.outline(well, Theme.OUTLINE_THIN)

	fillWell(well)

	-- AFTER the well is filled, never before. `layer` re-stamps every ZIndex
	-- by DEPTH once the page is built, so a badge and a viewport that are
	-- siblings end up on the same level and child ORDER is what decides which
	-- is on top. Built second, the badge wins; built first it would be behind
	-- the picture it is labelling.
	if badge then
		local chip = Instance.new("TextLabel")
		chip.Name = "Badge"
		chip.Size = UDim2.new(0, 26, 0, 26)
		chip.Position = UDim2.new(1, 3, 0, -3)
		chip.AnchorPoint = Vector2.new(1, 0)
		chip.BackgroundColor3 = Theme.GOLD
		chip.BorderSizePixel = 0
		chip.Font = Theme.FONT
		chip.TextSize = 16
		chip.TextColor3 = Theme.INK
		chip.Text = badge
		chip.Parent = well
		corner(chip, 13)
		Theme.outline(chip, Theme.OUTLINE_THIN)
	end

	local cap = Instance.new("TextLabel")
	cap.Name = "Caption"
	cap.Size = UDim2.new(1, -2, 0, 40)
	cap.Position = UDim2.new(0, 1, 0, 80)
	cap.BackgroundTransparency = 1
	cap.Font = Theme.FONT
	cap.TextSize = 13
	cap.TextColor3 = Theme.INK
	cap.TextWrapped = true
	cap.TextYAlignment = Enum.TextYAlignment.Top
	cap.Text = caption
	cap.Parent = tile
end

local function makeColumn(parent: Instance, order: number, title: string, tint: Color3): ScrollingFrame
	local holder = Instance.new("Frame")
	holder.Name = title
	holder.Size = UDim2.new(0.5, -5, 1, 0)
	holder.LayoutOrder = order
	holder.BackgroundColor3 = PANEL
	holder.BackgroundTransparency = 0.25
	holder.BorderSizePixel = 0
	holder.Parent = parent
	corner(holder, 10)

	local head = Instance.new("TextLabel")
	head.Size = UDim2.new(1, -20, 0, 26)
	head.Position = UDim2.new(0, 12, 0, 8)
	head.BackgroundTransparency = 1
	head.Font = Enum.Font.FredokaOne
	head.TextSize = 16
	head.TextXAlignment = Enum.TextXAlignment.Left
	head.TextColor3 = tint
	head.Text = title
	head.Parent = holder

	-- A SCROLLING FRAME RATHER THAN A PLAIN ONE, because a UIListLayout does
	-- not clip and does not error -- it just keeps drawing past the edge. The
	-- LOSE column is as long as the player's afternoon was, so its length is
	-- not something this file gets to know in advance. Same trap the shop's
	-- tab rail already shipped once.
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Size = UDim2.new(1, -16, 1, -44)
	list.Position = UDim2.new(0, 8, 0, 36)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 3
	list.ScrollBarImageColor3 = tint
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = holder

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 2)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	return list
end

local function buildPage(gui: ScreenGui)
	page = Instance.new("Frame")
	page.Name = "RebirthPage"
	-- Scaled with a maximum, the same way the shop panel is sized: a flat
	-- pixel size runs off the top of a phone held sideways, which is a lot of
	-- this audience.
	page.Size = UDim2.new(0.94, 0, 0.9, 0)
	page.Position = UDim2.fromScale(0.5, 0.5)
	page.AnchorPoint = Vector2.new(0.5, 0.5)
	page.BackgroundColor3 = Theme.SAND
	page.BorderSizePixel = 0
	page.Visible = false
	page.ZIndex = 30
	page.Parent = gui
	corner(page, 16)

	local cap = Instance.new("UISizeConstraint")
	cap.MaxSize = Vector2.new(860, 540)
	cap.Parent = page

	local edge = Instance.new("UIStroke")
	edge.Color = Theme.INK
	edge.Thickness = Theme.OUTLINE
	edge.Transparency = 0
	edge.Parent = page

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 14)
	pad.PaddingBottom = UDim.new(0, 14)
	pad.PaddingLeft = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.Parent = page

	local stack = Instance.new("UIListLayout")
	stack.Padding = UDim.new(0, 10)
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Parent = page

	-- ---------- header ----------
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 56)
	header.LayoutOrder = 1
	header.BackgroundTransparency = 1
	header.Parent = page

	pageTitle = Instance.new("TextLabel")
	pageTitle.Size = UDim2.new(1, 0, 0, 28)
	pageTitle.BackgroundTransparency = 1
	pageTitle.Font = Enum.Font.FredokaOne
	pageTitle.TextSize = 24
	pageTitle.TextXAlignment = Enum.TextXAlignment.Left
	pageTitle.TextColor3 = Theme.INK
	pageTitle.Text = SPARK .. "  REBIRTH"
	pageTitle.Parent = header

	local blurb = Instance.new("TextLabel")
	blurb.Size = UDim2.new(1, 0, 0, 24)
	blurb.Position = UDim2.new(0, 0, 0, 30)
	blurb.BackgroundTransparency = 1
	blurb.Font = Enum.Font.Gotham
	blurb.TextSize = 14
	blurb.TextXAlignment = Enum.TextXAlignment.Left
	blurb.TextColor3 = Theme.MUTED
	blurb.Text = "Start your upgrades again, and your piggy earns more forever."
	blurb.Parent = header

	-- ---------- the two columns ----------
	local columns = Instance.new("Frame")
	columns.Name = "Columns"
	-- Grown by 40 when the unlock band did. The KEEP column got shorter at
	-- the same time, so this costs nothing readable.
	columns.Size = UDim2.new(1, 0, 1, -290)
	columns.LayoutOrder = 2
	columns.BackgroundTransparency = 1
	columns.Parent = page

	local across = Instance.new("UIListLayout")
	across.FillDirection = Enum.FillDirection.Horizontal
	across.Padding = UDim.new(0, 10)
	across.SortOrder = Enum.SortOrder.LayoutOrder
	across.Parent = columns

	keepList = makeColumn(columns, 1, "YOU KEEP", KEEP)
	loseList = makeColumn(columns, 2, "YOU LOSE", LOSE)

	-- ---------- what it buys ----------
	local unlock = Instance.new("Frame")
	unlock.Name = "Unlock"
	-- Tall enough for a row of PICTURES rather than three sentences: a
	-- 64-stud well plus a two-line caption under it.
	unlock.Size = UDim2.new(1, 0, 0, 158)
	unlock.LayoutOrder = 3
	-- A BAND, NOT A BLOCK OF GOLD. At full gold the heading printed on it
	-- was gold on gold -- measured at 1.00, the worst pairing possible.
	unlock.BackgroundColor3 = Theme.SAND_DEEP
	unlock.BackgroundTransparency = 0.15
	unlock.BorderSizePixel = 0
	unlock.Parent = page
	corner(unlock, 10)

	local unlockEdge = Instance.new("UIStroke")
	unlockEdge.Color = GOLD
	unlockEdge.Thickness = 1.5
	unlockEdge.Transparency = 0.55
	unlockEdge.Parent = unlock

	local unlockHead = Instance.new("TextLabel")
	unlockHead.Size = UDim2.new(1, -20, 0, 24)
	unlockHead.Position = UDim2.new(0, 12, 0, 6)
	unlockHead.BackgroundTransparency = 1
	unlockHead.Font = Enum.Font.FredokaOne
	unlockHead.TextSize = 16
	unlockHead.TextXAlignment = Enum.TextXAlignment.Left
	unlockHead.TextColor3 = Theme.readable(Theme.GOLD, Theme.SAND_DEEP)
	unlockHead.Text = "YOU UNLOCK"
	unlockHead.Parent = unlock

	unlockList = Instance.new("Frame")
	unlockList.Name = "List"
	unlockList.Size = UDim2.new(1, -20, 1, -36)
	unlockList.Position = UDim2.new(0, 10, 0, 30)
	unlockList.BackgroundTransparency = 1
	unlockList.Parent = unlock

	-- ACROSS AND LEFT-ALIGNED, under the heading rather than centred in the
	-- band. Centring looked right in the abstract and measured wrong: three
	-- 108-wide tiles in a 1140-wide band leave nearly four hundred pixels
	-- either side, so the row floated in the middle with YOU UNLOCK stranded
	-- in an empty left third. Starting where the heading starts ties the two
	-- together, and reads the same whether there are two tiles or three.
	local unlockLayout = Instance.new("UIListLayout")
	unlockLayout.FillDirection = Enum.FillDirection.Horizontal
	unlockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	unlockLayout.VerticalAlignment = Enum.VerticalAlignment.Top
	unlockLayout.Padding = UDim.new(0, 14)
	unlockLayout.SortOrder = Enum.SortOrder.LayoutOrder
	unlockLayout.Parent = unlockList

	-- ---------- the decision ----------
	local footer = Instance.new("Frame")
	footer.Size = UDim2.new(1, 0, 0, 52)
	footer.LayoutOrder = 4
	footer.BackgroundTransparency = 1
	footer.Parent = page

	local footerRow = Instance.new("UIListLayout")
	footerRow.FillDirection = Enum.FillDirection.Horizontal
	footerRow.HorizontalAlignment = Enum.HorizontalAlignment.Right
	footerRow.VerticalAlignment = Enum.VerticalAlignment.Center
	footerRow.Padding = UDim.new(0, 10)
	footerRow.SortOrder = Enum.SortOrder.LayoutOrder
	footerRow.Parent = footer

	-- NOT YET rather than CANCEL. Nothing here is a mistake being undone --
	-- the player is deciding whether they are ready, and the wording should
	-- not tell them they have done something wrong by looking.
	local back = Instance.new("TextButton")
	back.Name = "NotYet"
	back.Size = UDim2.new(0, 132, 0, 44)
	back.LayoutOrder = 1
	back.BackgroundColor3 = PANEL
	back.BorderSizePixel = 0
	back.AutoButtonColor = true
	back.Font = Enum.Font.FredokaOne
	back.TextSize = 17
	back.TextColor3 = Theme.MUTED
	back.Text = "NOT YET"
	back.Parent = footer
	-- The same radius and the same line as its neighbour. The hierarchy
	-- between the two is carried by the FILL -- paper against plum -- rather
	-- than by one of them being drawn more faintly than the other.
	corner(back, 12)
	Theme.outline(back)
	back.Activated:Connect(function()
		Rebirth.close()
	end)

	confirmButton = Instance.new("TextButton")
	confirmButton.Name = "Confirm"
	confirmButton.Size = UDim2.new(0, 190, 0, 44)
	confirmButton.LayoutOrder = 2
	-- The button players actually press. Same treatment as the HUD one, for
	-- the same reason: it is the single most consequential control in the
	-- game and it was the only one on this page without a drawn edge.
	confirmButton.BackgroundColor3 = PLUM
	Theme.shade(confirmButton, 0.88)
	confirmButton.BorderSizePixel = 0
	confirmButton.AutoButtonColor = true
	confirmButton.Font = Enum.Font.FredokaOne
	confirmButton.TextSize = 18
	confirmButton.TextColor3 = Theme.PAPER
	confirmButton.Text = ""
	confirmButton.Parent = footer
	-- MATCHED TO THE HUD BUTTON PIECE BY PIECE, because they are the same
	-- control in two places and were built five hundred lines apart: same
	-- corner radius (12, not 10), the same full-weight ink outline (3px and
	-- opaque, not 1.5 at 0.4 transparency), and the same sparkle beside the
	-- word. Only the halo is left off -- that one pulses to catch an eye that
	-- is looking at the world, and on this page nothing else is competing.
	corner(confirmButton, 12)
	Theme.outline(confirmButton)

	local confirmGlyph = Instance.new("TextLabel")
	confirmGlyph.Name = "Icon"
	confirmGlyph.Size = UDim2.new(0, 26, 1, 0)
	confirmGlyph.Position = UDim2.new(0, 14, 0, 0)
	confirmGlyph.BackgroundTransparency = 1
	confirmGlyph.Font = Enum.Font.GothamBold
	confirmGlyph.TextSize = 20
	confirmGlyph.TextColor3 = Theme.PAPER
	confirmGlyph.Text = SPARK
	confirmGlyph.Parent = confirmButton

	local confirmLabel = Instance.new("TextLabel")
	confirmLabel.Name = "Label"
	confirmLabel.Size = UDim2.new(1, -48, 1, 0)
	confirmLabel.Position = UDim2.new(0, 42, 0, 0)
	confirmLabel.BackgroundTransparency = 1
	confirmLabel.Font = Enum.Font.FredokaOne
	confirmLabel.TextSize = 18
	confirmLabel.TextXAlignment = Enum.TextXAlignment.Left
	confirmLabel.TextColor3 = Theme.PAPER
	confirmLabel.Text = "REBIRTH!"
	confirmLabel.Parent = confirmButton

	confirmButton.Activated:Connect(function()
		Rebirth.close()
		if onConfirm then
			onConfirm()
		end
	end)

	layer(page, page.ZIndex + 1)
end

-- ============================================================
-- FILLING IT IN
-- ============================================================

local function fill()
	local next_ = seen.rebirths + 1
	pageTitle.Text = ("%s  REBIRTH %d"):format(SPARK, next_)

	for _, list in ipairs({ keepList, loseList, unlockList }) do
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
	end

	-- ---------- keep ----------
	--
	-- A RULE, NOT AN INVENTORY. This used to itemise: "Your 2 skins", "Your 5
	-- lawn decorations", "Your 1 piece of gear" -- nine rows counted off the
	-- pushed catalogues. Every line was true and the column was a stocktake,
	-- which is the wrong shape for the reassuring half of a scary page. A
	-- nine-year-old deciding whether to press this needs to know that NOTHING
	-- THEY COLLECTED GOES, and counting it back at them makes them audit the
	-- list instead.
	--
	-- It is also more honest. `Rebirth wipes power but never cosmetics` is a
	-- rule about the game rather than about today's inventory, so stating the
	-- rule cannot disagree with what the server does -- where a count read
	-- from a stale push can. The LOSE column keeps its real numbers, and that
	-- asymmetry is deliberate: a loss is somebody's actual afternoon and has
	-- to be specific, while a thing you keep is a promise and has to be total.
	local order = 0
	local function keep(text: string)
		order += 1
		makeRow(keepList, order, TICK, KEEP, text)
	end

	keep("All your skins and trail effects")
	keep("Your house, and everything on your lawn")
	keep("Everything you wear, and every ride")
	keep("Every bone and gadget you are holding")
	if seen.rebirths > 0 then
		keep(("Your %d%s so far, plus the new one"):format(seen.rebirths, STAR))
	else
		keep(("Your %s: they only ever go up"):format(STAR))
	end

	-- ---------- lose ----------
	order = 0
	local function lose(text: string)
		order += 1
		makeRow(loseList, order, CROSS, LOSE, text)
	end

	lose(("%s coins in your piggy bank"):format(format(seen.coins)))
	if seen.incomeLevel > 1 then
		lose(("Earn Faster, Lv %d"):format(seen.incomeLevel))
	end
	if seen.capacityLevel > 1 then
		lose(("Bigger Piggy Bank, Lv %d"):format(seen.capacityLevel))
	end

	-- Only what they actually bought. An upgrade at zero is not a loss, and
	-- listing it would make the scary column longer than the truth.
	local trees = {}
	for _, info in pairs(seen.upgrades or {}) do
		if (info.level or 0) > 0 then
			table.insert(trees, info)
		end
	end
	-- Defence then offence, each in its own order: the same arrangement the
	-- shop shows both trees in. A list sorted by table key instead came out
	-- boots, dog, lockpicks, locks, sack -- alphabetical order over the
	-- INTERNAL names, which is an arrangement the player has never seen.
	table.sort(trees, function(a, b)
		if a.tree ~= b.tree then
			return a.tree == "defense"
		end
		return (a.order or 99) < (b.order or 99)
	end)
	for _, t in ipairs(trees) do
		lose(("%s, Lv %d"):format(t.name, t.level))
	end

	-- ---------- unlock ----------
	--
	-- PICTURES. See `unlockTile` for why.
	order = 0
	local step = math.floor(Config.REBIRTH_MULTIPLIER * 100)
	local total = math.floor(next_ * Config.REBIRTH_MULTIPLIER * 100)

	-- The income tile is the one reward that is not an object, so it gets the
	-- drawn coin the HUD already uses rather than a stand-in model. Gold means
	-- money everywhere else in this game; it means it here too.
	order += 1
	unlockTile(order,
		if next_ > 1
			then ("+%d%% income, now +%d%% in all"):format(step, total)
			else ("+%d%% income, forever"):format(step),
		function(well)
			local coin = Theme.coin(well, 54)
			coin.Position = UDim2.new(0.5, 0, 0.5, 0)
			coin.AnchorPoint = Vector2.new(0.5, 0.5)
		end)

	-- The guaranteed skin. WHICH one is a roll, so the picture is a piggy
	-- wearing the starter skin with a "?" on it -- the honest image of "a
	-- skin, and you will find out which". Rendering a specific one here would
	-- promise something the server never said.
	order += 1
	unlockTile(order, "A new piggy skin, guaranteed",
		function(well)
			if makeIcon then
				makeIcon(well, PiggyModel.build("classic"),
					UDim2.new(1, -10, 1, -10), UDim2.new(0, 5, 0, 5), false)
			end
		end, "?")

	-- Anything the COUNT itself unlocks. Read off the pushed catalogue rather
	-- than Config, so the page can never promise a skin the server would not
	-- actually hand over -- and rendered from the same key, so the picture
	-- cannot disagree with the name under it either.
	if seen.cosmetics and seen.cosmetics.skins then
		for key, skin in pairs(seen.cosmetics.skins) do
			if skin.unlockRebirths == next_ then
				order += 1
				unlockTile(order, ("%s, yours to wear"):format(skin.name),
					function(well)
						if makeIcon then
							makeIcon(well, PiggyModel.build(key),
								UDim2.new(1, -10, 1, -10), UDim2.new(0, 5, 0, 5), false)
						end
					end)
			end
		end
	end

	-- Every row above was built after the page was, so it has not been
	-- layered yet. See `layer`.
	layer(page, page.ZIndex + 1)
end

-- ============================================================
-- API
-- ============================================================

function Rebirth.open()
	if not page then
		return
	end
	fill()
	page.Visible = true
	Rebirth.sync()
end

function Rebirth.close()
	if page then
		page.Visible = false
	end
	Rebirth.sync()
end

function Rebirth.isOpen(): boolean
	return page ~= nil and page.Visible
end

function Rebirth.sync()
	if not button then
		return
	end
	local allowed = if Rebirth.canShow then Rebirth.canShow() else true
	button.Visible = seen.ready and allowed and not Rebirth.isOpen()
end

function Rebirth.onEconomy(state: any)
	seen.coins = state.coins or 0
	seen.incomeLevel = state.incomeLevel or 1
	seen.capacityLevel = state.capacityLevel or 1
	seen.rebirths = state.rebirths or 0
	seen.ready = state.rebirthReady == true
	if starChip then
		starChip.Text = ("%d%s"):format(seen.rebirths + 1, STAR)
	end
	-- A page left open through a rebirth would be describing a trade that has
	-- already happened, which is the receipt this file exists to avoid.
	if Rebirth.isOpen() and not seen.ready then
		Rebirth.close()
	end
	Rebirth.sync()
end

function Rebirth.onUpgrades(list: any)
	seen.upgrades = list
end

function Rebirth.onCosmetics(c: any)
	seen.cosmetics = c
end

function Rebirth.onRides(list: any)
	seen.rides = list
end

-- `icon` is optional and the page degrades to empty wells without it, which
-- is the same trade the drip statue's hair makes: a picture missing is a far
-- smaller fault than a page that does not build.
function Rebirth.init(gui: ScreenGui, confirm: () -> (),
	icon: ((GuiObject, Model, UDim2, UDim2, boolean) -> Instance)?)
	onConfirm = confirm
	makeIcon = icon
	buildButton(gui)
	buildPage(gui)
end

return Rebirth
