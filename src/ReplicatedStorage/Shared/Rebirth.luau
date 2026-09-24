--!strict
--[[
	Rebirth

	The rebirth button, and the decision page it opens. The art is in
	assets/ui/rebirth-icons-v1. (The September 2026 redesign's own document is
	deleted: it had shipped, and the header below documents the decisions it
	got wrong better than the doc did.)

	----------------------------------------------------------------------

	THE PAGE IS ONE LIST: YOU GAIN, YOU KEEP, STARTS OVER (designer,
	2026-09-23). Three bands of plain rows in one column, read top to bottom in
	the order the trade happens in a child's head -- what do I get, what is
	safe, what goes.

	WHAT IT REPLACED IS THE POINT. The page carried three illustrated benefit
	cards in a two-column grid, an "Unlocks:" strip with a shape of its own, a
	collapsible POSSIBLE REWARDS list printing real crate odds, and then RESETS
	and YOU KEEP SIDE BY SIDE with a second collapsible inside one of them.
	Five shapes and two expanders, on the one screen in this game that exists
	so a nine-year-old understands an irreversible decision BEFORE making it --
	and on a desktop the cost half of the trade was in a column they had to
	notice. Reported, correctly, as far too confusing. The fault was never any
	one element: the page had grown a SURFACE per fact where a ROW per fact was
	the whole requirement.

	SO THE RULE IS: A FACT ON THIS PAGE IS A ROW. An icon, a name a child can
	read, one short note under it, and a value where there is one. Anything
	that wants a surface of its own, an expander, or a second column has to
	answer this paragraph first.

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
	also reads (`rebirthIncomeFactor`, `getRebirthThreshold` -- the CASH gate,
	`Config.REBIRTH_CASH_GATE`, a placeholder table the designer has yet to
	set -- `rebirthCrateLadder` and `rebirthCratesOpen`) or from a push
	(`StateUpdate`, `UpgradeState`, `CosmeticState`, `RideState`).

	THE PERMANENT COIN MULTIPLIER IS WHAT THE TOP ROW IS CALLED, it is printed
	as a MULTIPLE ("1x -> 1.12x") rather than as the "+12%" it used to be, and
	it is the only thing in the game that raises what a piggy earns. The coin-priced EARN
	FASTER rung is off the shop shelf (designer, 2026-09-23), which also
	retired two things this page used to print: a HIGHER UPGRADE LIMIT benefit
	card -- `Config.rebirthOpensMore` is true of the income ladder and of
	nothing else, so that ceiling now gates nothing anybody can buy -- and an
	"Earn Faster / Lv N -> 1" reset row, which could only ever have read
	"Lv 1 -> 1".

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
--
-- THREE MORE STOOD HERE AND NONE HAD A READER. `CHEVRON` labelled the two
-- expanders and `DOT` separated the crate odds, both of which went with the
-- single list; `TICK` had no use at all and predates that -- swept in the same
-- pass rather than left to be re-checked by whoever wonders next.
local ARROW = utf8.char(0x2192)
local CROSS = utf8.char(0x00D7)
local ELLIPSIS = utf8.char(0x2026)

local function hex(c: Color3): string
	return ("#%02X%02X%02X"):format(
		math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local GOLD_HEX = hex(Theme.GOLD)

-- RETIRED WITH THE MOVE TO THE MENU RAIL. `Rebirth.canShow` and
-- `Rebirth.yieldsBand` were both set by ClientMain and both existed for one
-- reason: the button used to stand in the top-centre column, where a shop
-- panel could cover it and the first-job card wanted the same row. A rail
-- tile is covered by nothing and shares its row with nothing, so the hooks,
-- the watcher that drove them and the arbitration between them are gone
-- rather than left switched off. ClientMain still owns the same predicate for
-- the FIRST-JOB card, which does still sit in that column -- it is declared
-- at that card's own call site now, where its one reader can see it.
local onConfirm: (() -> ())? = nil

local seen = {
	coins = 0,
	rebirths = 0,
	ready = false,
	upgrades = nil :: any,
	cosmetics = nil :: any,
	rides = nil :: any,
}

-- The confirm is in flight. `from` is the rebirth count it was sent at, so
-- success is "the count rose" rather than a guess at a timer.
local pending = { active = false, from = 0, token = 0 }

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
-- THE MENU TILE
-- ============================================================

-- THE REBIRTH TILE, IN THE LEFT MENU RAIL (designer, 2026-09-23): the
-- spinning emblem and the word under it, and nothing else.
--
-- IT WAS A 250 x 54 PLATE IN THE TOP-CENTRE COLUMN, and moving it here is
-- what let a whole arbitration layer be DELETED rather than switched off.
-- That column is the one this project's notes call full and measured, and a
-- PERMANENT element in it overlapped the first-job card by 36 pixels -- so it
-- had grown a yield rule, a second visibility hook and a watcher to decide
-- which of the two owned the row. The rail is drawn at x 4 and the shop panel
-- starts at 83, so nothing covers a tile and none of that is needed: this is
-- a sibling of Shop, Bag and Board and behaves like one.
--
-- IT CARRIES A CAPTION WHERE THE OTHER TWO DO NOT, deliberately rather than
-- inconsistently. Those are a cog, a bag and a shopfront -- objects a
-- nine-year-old already has a word for, which is why `makeButton` keeps its
-- label in an attribute and draws only the picture. A piggy inside a ring of
-- arrows is not one of those: REBIRTH is the idea this game most has to
-- teach, so the one tile whose meaning is not in its drawing is the one tile
-- that says it out loud.
local TILE_W, TILE_H = 66, 64

-- HOW BIG THE DRAWING IS, AND IT IS THE NEIGHBOURS' SIZE RATHER THAN WHAT WAS
-- LEFT OVER (designer, 2026-09-23: "lets make the rebirth icon bigger").
-- `MenuIcons` scales a 96-unit drawing by `min(w, h) / 96`, so a cog, a bag
-- and a shopfront each fill the whole of their 66 x 64 tile. This emblem was
-- 46, chosen to leave a clear 16-pixel caption row under it -- so the one
-- tile carrying a word was also the one drawing at 72% of everything beside
-- it, which is what was reported.
--
-- THE CAPTION LIES ACROSS THE BOTTOM OF IT NOW, WHICH IS WHAT PAID FOR THE
-- EXTRA TWELVE PIXELS. A row of its own can only be bought out of the
-- drawing's height, and the rail's arithmetic (`tiles * 64` in
-- `HUDLayout.bindMenu`) means the TILE cannot grow to make room without
-- every tile growing. Stroked paper type over art is this project's own
-- answer to that trade -- the standing countdown chip records a pill covering
-- its icon as the bug, and bare stroked type over a bigger icon as the fix --
-- and what it overlaps here is the bottom arc of the arrow ring rather than
-- the piggy, which sits at 0.62 of the emblem in the middle of it.
local TILE_ART = 58

local function buildButton(rail: Instance)
	local b = Instance.new("TextButton")
	b.Name = "RebirthButton"
	b.Size = UDim2.fromOffset(TILE_W, TILE_H)
	b.Text = ""
	b.BackgroundTransparency = 1
	b.BorderSizePixel = 0
	b.AutoButtonColor = false
	b:SetAttribute("AccessibleLabel", "REBIRTH")
	-- LAST IN THE RAIL, AND THE RAIL IS THREE TILES PLUS THIS ONE. It took
	-- this slot from the board's own toggle, which was then pushed to 5 and
	-- has since been retired outright (designer, 2026-09-23) -- the board
	-- carries a collapsed tile in its own corner, so the rail was offering a
	-- second way to do one thing. Nothing moved when it went: the rail is
	-- top-anchored and the cup was below this.
	b.LayoutOrder = 4
	-- VISIBLE FROM THE MOMENT IT IS PARENTED. `HUDLayout.bindMenu` sizes the
	-- rail by counting its VISIBLE children on ChildAdded, so a tile that
	-- arrives hidden is a tile the rail is not tall enough to hold.
	b.Visible = true
	b.Parent = rail
	ui.button = b

	-- One brief pop when rebirth first becomes available. The only standing
	-- motion is the emblem's arrow ring turning (designer's call, over the
	-- guide's "keep it still"); the tile itself does not pulse or bounce.
	local pop = Instance.new("UIScale")
	pop.Parent = b
	ui.pop = pop

	-- No disc behind it: on a plum plate the disc was what stopped the emblem
	-- reading as art floating over a seam, and on the rail there is no plate
	-- and no seam -- the other three tiles are bare drawings on the world.
	local mark, arrows = emblem(b, TILE_W, true, false)
	mark.AnchorPoint = Vector2.new(0.5, 0)
	mark.Position = UDim2.new(0.5, 0, 0, -1)
	mark.Size = UDim2.fromOffset(TILE_ART, TILE_ART)
	ui.buttonEmblem = mark
	ui.buttonArrows = arrows

	-- Paper with an ink line round each glyph, which is what holds a caption
	-- legible over grass, a road or a house -- the rail sits on the world, and
	-- since the drawing grew this now sits over the bottom of the ring as
	-- well. The stroke is the only thing between the two, which is exactly
	-- what it is for; `Theme.outline` would have been the wrong helper, since
	-- it strokes a label's invisible RECTANGLE rather than its glyphs.
	local label = text(b, "Label", "REBIRTH", 11, Theme.PAPER)
	inked(label, 2)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Position = UDim2.fromOffset(0, 47)
	label.Size = UDim2.new(1, 0, 0, 16)
	ui.buttonLabel = label

	b.Activated:Connect(function()
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

-- A summary card: a coloured head band with a title and a one-line promise,
-- then rows. THE ONLY SHAPE ON THE PAGE now that the illustrated benefit
-- cards have gone: the band says which side of the trade you are reading
-- before a word of it is read, and all three sections are one of these.
local function sectionCard(parent: Instance, name: string, fill: Color3, edge: Color3,
	heading: string, sub: string?, band: Color3)
	local card = frame(parent, name, fill)
	card.AutomaticSize = Enum.AutomaticSize.Y
	Theme.corner(card, 14)
	Theme.outline(card, Theme.OUTLINE_THIN, edge)
	local pad = Instance.new("UIPadding")
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = card
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Parent = card

	local head = frame(card, "Heading", band)
	head.LayoutOrder = 0
	head.Size = UDim2.new(1, 0, 0, if sub then 44 else 36)
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
	title.Position = UDim2.fromOffset(0, if sub then 2 else 4)
	title.Size = UDim2.new(1, 0, 0, 24)
	if sub then
		local line = text(head, "Sub", sub, 13, Theme.PAPER, Enum.Font.GothamBold)
		line.TextXAlignment = Enum.TextXAlignment.Center
		line.Position = UDim2.fromOffset(0, 24)
		line.Size = UDim2.new(1, 0, 0, 17)
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
--
-- `loud` MAKES THE NOTE THE HEADLINE, and it exists for exactly one row: the
-- coin multiplier, whose note is a before-and-after rather than a caption.
-- IT IS NOT A PILL, AND THAT IS A MEASUREMENT. A value pill is 124 pixels and
-- right-aligned, which leaves a narrow phone's row about 72 for the name -- the
-- reset rows already truncate there -- and "1.24x -> 1.36x" wants nearer 120 at
-- 15px, so pilling it would either clip the number or eat the label. Printed
-- under the name it has the whole row and no neighbour to fight, at any width.
local function summaryRow(parent: Instance, order: number, tint: Color3?, draw: ((Frame) -> ())?,
	name: string, note: string?, value: string?, pillTint: Color3?,
	loud: boolean?): (Frame, TextLabel?)
	local row = frame(parent, "Row" .. order)
	row.LayoutOrder = order
	local h = if loud then 52 elseif note then 40 else 34
	row.Size = UDim2.new(1, -24, 0, h)
	if draw and tint then
		local chip = iconChip(row, tint, 36, draw)
		chip.AnchorPoint = Vector2.new(0, 0.5)
		chip.Position = UDim2.new(0, 0, 0.5, 0)
	end
	local x = 46
	local valueW = if value then 124 else 0
	local label = text(row, "Name", name, 16, Theme.INK, Theme.FONT)
	label.Position = UDim2.fromOffset(x, if note then 2 else 0)
	label.Size = UDim2.new(1, -(x + valueW + 6), 0, if note then 20 else h)
	label.TextTruncate = Enum.TextTruncate.AtEnd
	if note then
		local n = text(row, "Note", note,
			if loud then 20 else 13,
			if loud then Theme.INK else Theme.MUTED,
			if loud then Theme.FONT else Enum.Font.GothamMedium)
		n.Position = UDim2.fromOffset(x, if loud then 24 else 21)
		n.Size = UDim2.new(1, -(x + valueW + 6), 0, if loud then 26 else 18)
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
	bodyPad.PaddingTop = UDim.new(0, 2)
	bodyPad.PaddingBottom = UDim.new(0, 4)
	bodyPad.PaddingLeft = UDim.new(0, 4)
	bodyPad.PaddingRight = UDim.new(0, 12)
	bodyPad.Parent = body
	local bodyList = Instance.new("UIListLayout")
	bodyList.Padding = UDim.new(0, 8)
	bodyList.SortOrder = Enum.SortOrder.LayoutOrder
	bodyList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	bodyList.Parent = body

	-- ONE LIST, TOP TO BOTTOM: what you GAIN, then what you KEEP, then what
	-- STARTS OVER.
	--
	-- WHAT STOOD HERE WAS FIVE SHAPES AND TWO EXPANDERS. Three illustrated
	-- benefit cards in a two-column grid, an "Unlocks:" strip, a collapsible
	-- POSSIBLE REWARDS list, and then RESETS and YOU KEEP SIDE BY SIDE with a
	-- second collapsible inside one of them -- on the one page in this game a
	-- nine-year-old has to understand before pressing anything irreversible.
	-- Reported as far too busy, and it was: the page had grown a SURFACE per
	-- fact where a ROW per fact was the whole requirement.
	--
	-- Three bands of plain rows in ONE COLUMN, in the order the trade is read
	-- (designer, 2026-09-23): what the button buys, then what is safe, then
	-- what goes. Nothing expands, nothing sits beside anything, and the widest
	-- thing on the page is a sentence.
	--
	-- THE SUB-LINE UNDER EACH BAND IS THE UNDERSTANDING HALF and is not
	-- decoration: "YOU KEEP" is a heading a child can read and "Nothing is
	-- taken away" is what it MEANS, which is the whole reason this page exists
	-- rather than a toast after the fact.
	ui.gain = sectionCard(body, "Gain", PLUM:Lerp(Theme.PAPER, 0.86),
		PLUM:Lerp(Theme.PAPER, 0.4), "YOU GAIN", "Yours forever", PLUM)
	ui.gain.LayoutOrder = 1
	ui.keep = sectionCard(body, "YouKeep", Theme.GOOD:Lerp(Theme.PAPER, 0.84),
		Theme.GOOD:Lerp(Theme.PAPER, 0.35), "YOU KEEP", "Nothing is taken away",
		Theme.GOOD_INK)
	ui.keep.LayoutOrder = 2
	ui.resets = sectionCard(body, "Resets", Theme.STOP:Lerp(Theme.PAPER, 0.86),
		Theme.STOP:Lerp(Theme.PAPER, 0.4), "STARTS OVER", "Back to the beginning",
		Theme.STOP_INK)
	ui.resets.LayoutOrder = 3

	-- D. the requirement
	local req = frame(body, "Requirement", Theme.PAPER)
	req.LayoutOrder = 4
	req.Size = UDim2.new(1, 0, 0, 54)
	Theme.corner(req, 14)
	Theme.outline(req, Theme.OUTLINE_THIN, Theme.MUTED_LIGHT)
	-- THE CASH GATE, named as one. It used to read "fill your piggy bank"
	-- in spirit -- the gate WAS one full pig -- and the pig has no ceiling
	-- now, so the row names the amount the server actually checks.
	local reqName = text(req, "Name", "Coins needed", 15, Theme.INK, Theme.FONT)
	reqName.Position = UDim2.fromOffset(14, 6)
	reqName.Size = UDim2.new(0.5, -14, 0, 22)
	local reqAmount = text(req, "Amount", "", 15, Theme.INK, Theme.FONT_BODY)
	reqAmount.AnchorPoint = Vector2.new(1, 0)
	reqAmount.Position = UDim2.new(1, -118, 0, 6)
	reqAmount.Size = UDim2.new(0.5, -118, 0, 22)
	reqAmount.TextXAlignment = Enum.TextXAlignment.Right
	local track = frame(req, "Track", Theme.PAPER_DEEP)
	track.Position = UDim2.fromOffset(14, 32)
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
	-- A REMINDER LINE STOOD HERE and said "Your piggy coins and bought
	-- upgrades reset. Your collection stays." -- which is the three bands
	-- above it, restated in eight words, on the page they are printed on. It
	-- was belt and braces while the trade was spread across a grid and two
	-- columns; against one list it is the same sentence twice.

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
		-- 640 UNTIL THE PAGE BECAME A LIST. Measured on a 1366x768 screen, the
		-- three bands and the requirement came to 650 against a 498 body, so
		-- STARTS OVER -- the half of the trade that is a COST, on the one
		-- decision in this game that cannot be undone -- was sliced across the
		-- fold. The cap is what the screen can give now; everything below
		-- trims the list to meet it.
		local h = math.min(704, view.Y - 24 - tabOver)
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
		-- The reminder line that used to sit above these went with the single
		-- list, and the height it was taking went to the list.
		local footH = 14 + buttonsH + 14
		footer.Size = UDim2.new(1, -28, 0, footH)
		footer.Position = UDim2.new(0, 14, 1, 0)
		local by = 14
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

		-- ONE COLUMN AT EVERY SIZE. RESETS and YOU KEEP were `0.5, -6` beside
		-- each other on anything not narrow, which is half of what this page
		-- was reported for: a reader on a desktop had to find the SECOND
		-- COLUMN to learn what a rebirth takes off them, and the order the
		-- three bands are meant to be read in only existed on a phone.
		for _, card in ipairs({ ui.gain, ui.keep, ui.resets }) do
			card.Size = UDim2.new(1, 0, 0, 0)
		end
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

-- WHAT THE NEXT REBIRTH PUTS ON SALE, NAMED.
--
-- Three shelves carry a rebirth ladder (designer, 2026-09-23) -- houses,
-- rides and guardians -- and this page had nothing that said so: it listed
-- the coin bonus, the upgrade ceiling and the free crate, and the shop items
-- a rebirth actually opens were invisible until somebody went and looked.
-- "Unlocks: Fishbowl House, Husky" is the one line that turns a number into
-- a reason.
--
-- DERIVED FROM THE PUSHED CATALOGUES AND NEVER FROM `Config`. The server
-- already sends `unlockRebirths` on every gated row precisely so that a card
-- and a refusal cannot disagree, and a client that read Config here would be
-- a THIRD opinion -- and the wrong one, because it would name a row the
-- server had not published yet.
--
-- OWNED ROWS ARE SKIPPED. A player who somehow holds a gated item already
-- (an older save, a re-themed row, a pass grant) is not being offered it.
--
-- EXPORTED so the offline suite can drive the derivation without building a
-- page: everything below it is geometry, and the sentence is the part with a
-- rule in it.
--
-- `CAP` BOUNDS THE LINE RATHER THAN THE LIST. A rebirth that opens six
-- things would otherwise wrap a strip into four rows; naming three and
-- counting the rest keeps it one line and still says how much is behind it.
Rebirth.UNLOCK_CAP = 3

function Rebirth.unlocksAt(rebirth: number, cosmetics: any, rides: any): { string }
	local names: { string } = {}
	local function take(info: any)
		-- A row's gate has to MATCH: this line is about the rebirth being
		-- pressed, not about everything still shut. `>=` would name the whole
		-- remaining catalogue on the first rebirth.
		if type(info) ~= "table" or info.owned == true then
			return
		end
		-- A GATE OF ZERO IS NOT A GATE, and the push is why this has to be
		-- said: every row crosses the wire with `unlockRebirths = coat.unlockRebirths or 0`,
		-- so an ungated house and a house gated at rebirth 0 are the same
		-- payload. Requiring 1 or more is what stops the free Cardboard Fort
		-- being named as something a rebirth unlocks.
		local gate = info.unlockRebirths or 0
		if gate >= 1 and gate == rebirth and type(info.name) == "string" then
			table.insert(names, info.name)
		end
	end
	-- Houses are an ARRAY keyed by position and the other two are MAPS keyed
	-- by item, which is why this walks values rather than indices: `pairs`
	-- over an array is still every row, and `ipairs` over a map is nothing.
	for _, info in pairs((cosmetics and cosmetics.houses) or {}) do take(info) end
	for _, info in pairs((rides and rides.rides) or {}) do take(info) end
	for _, info in pairs((cosmetics and cosmetics.dogCoats) or {}) do take(info) end
	-- SORTED, so the line is stable between two pushes that carry the same
	-- rung -- `pairs` over a map has no order, and a line that reshuffled
	-- itself on every coin tick reads as a fault.
	table.sort(names)
	return names
end

local function ownedSkins(): { [string]: boolean }
	local owned = {}
	for key, skin in pairs((seen.cosmetics and seen.cosmetics.skins) or {}) do
		owned[key] = skin.unlocked == true
	end
	return owned
end

local function drawCoinIcon(chip: Frame)
	centred(Theme.coin(chip, 24))
end

local function drawPigIcon(chip: Frame)
	if not image(chip, "Piggy", ICONS.piggy, 0.95) then
		centred(Theme.snout(chip, 22))
	end
end

local function drawGearIcon(chip: Frame)
	centred(Theme.gear(chip, 24))
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
	local door = frame(body, "Door", Theme.SAND_DEEP)
	door.AnchorPoint = Vector2.new(0.5, 1)
	door.Position = UDim2.fromScale(0.5, 1)
	door.Size = UDim2.fromScale(0.3, 0.62)
end

-- A crate. Authored in SCALE throughout, which is what lets the same builder
-- serve a 36-pixel row chip -- there is no well on this page any more.
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

local function drawCrateIcon(chip: Frame)
	drawCrate(chip, PLUM)
end

local function fill()
	if not ui.page then
		return
	end
	local r = seen.rebirths
	local nextR = r + 1
	ui.title.Text = ("REBIRTH <font color=\"%s\">%d</font>"):format(GOLD_HEX, nextR)

	-- ---------- A. YOU GAIN ----------
	local gain = ui.gain
	clear(gain, { Heading = true })
	local order = 1
	-- THE ONE NUMBER THIS BUTTON IS PRESSED FOR, AND IT CARRIES THE DESIGNER'S
	-- NAME FOR IT (2026-09-23): the PERMANENT COIN MULTIPLIER. It read
	-- "Permanent coin bonus" here while a separate coin-priced EARN FASTER rung
	-- sat in the shop raising the same rate; that rung is retired, so this is
	-- the only thing in the game that makes a piggy earn more and there is no
	-- longer a second name for the idea to be confused with.
	summaryRow(gain, order, Theme.GOLD:Lerp(Theme.PAPER, 0.35), drawCoinIcon,
		"Permanent coin multiplier",
		("%s %s %s"):format(Config.rebirthMultipleText(r), ARROW,
			Config.rebirthMultipleText(nextR)),
		nil, nil, true)

	-- THE "HIGHER UPGRADE LIMIT" CARD STOOD HERE and is retired with the rung
	-- it described. `Config.rebirthOpensMore` is true of exactly one ladder --
	-- income -- because the six tree rows carry a fixed `max` no rebirth
	-- lifts; with Earn Faster off the shelf that ceiling gates nothing anybody
	-- can buy, so the card was a benefit a player could not spend. Copy
	-- outliving the thing it describes, caught in the same pass that retired it.

	local owned = ownedSkins()
	-- THE RUNG THE NEXT REBIRTH WILL ACTUALLY DRAW FROM, and the fallback in
	-- the same order the server takes it: `ProgressionService` asks its ladder
	-- first and drops to the legendary shelves when that one has nothing left,
	-- so a page that read only the legendary list named the wrong crate on
	-- four rebirths in five. `+ 1` because the count on screen is the one
	-- being left rather than the one being reached.
	local ladder, legendaryRung = Config.rebirthCrateLadder(r + 1)
	local open = Config.rebirthCratesOpen(owned, ladder)
	if #open == 0 then
		open = Config.rebirthCratesOpen(owned)
		legendaryRung = true
	end
	-- NOTHING LEFT TO OPEN MEANS NO ROW RATHER THAN A ROW SAYING SO. This used
	-- to be a whole card reading "Collections complete / Nothing left to open",
	-- which is a GAIN that is not one, printed in the band a child reads to
	-- find out what they are getting.
	if #open > 0 then
		order += 1
		-- NAMES THE RUNG WHEN THE SHELF IS A CHOICE, because which crate of a
		-- rung a player gets is the server's own `pickOpenable` and depends on
		-- pools this page cannot see. One crate open means one honest name.
		local crate = if #open == 1 then Config.CHESTS[open[1]].name
			elseif legendaryRung then "Legendary crate"
			else "Rare crate"
		summaryRow(gain, order, PLUM:Lerp(Theme.PAPER, 0.5), drawCrateIcon,
			"A free crate", crate)
	end

	-- WHAT THE NEXT REBIRTH PUTS ON SALE, as a row like everything else rather
	-- than the wrapped strip that used to sit under the grid with a shape of
	-- its own. `UNLOCK_CAP` is what keeps it to one line; the note truncates.
	local opens = Rebirth.unlocksAt(nextR, seen.cosmetics, seen.rides)
	if #opens > 0 then
		local shown = {}
		for i = 1, math.min(#opens, Rebirth.UNLOCK_CAP) do
			table.insert(shown, opens[i])
		end
		local line = table.concat(shown, ", ")
		local rest = #opens - #shown
		if rest > 0 then
			line = ("%s and %d more"):format(line, rest)
		end
		order += 1
		summaryRow(gain, order, Theme.STOP:Lerp(Theme.PAPER, 0.65), drawHouseIcon,
			"New things in the shop", line)
	end

	-- ---------- B. YOU KEEP ----------
	--
	-- A RULE, NOT AN INVENTORY: "nothing you collected goes" is total, where a
	-- count read off a stale push could disagree with the server. Four rows
	-- rather than five -- the guard dog is a pet and rides beside the rest of
	-- what a player wears and carries.
	local keep = ui.keep
	clear(keep, { Heading = true })
	for i, row in ipairs({
		{ Theme.PIG:Lerp(Theme.PAPER, 0.35), drawPigIcon, "Everything you collected",
			"Piggies, skins, trophies and sets" },
		{ Theme.STOP:Lerp(Theme.PAPER, 0.65), drawHouseIcon, "Your house and garden",
			"Every house and decoration you own" },
		{ Theme.COOL:Lerp(Theme.PAPER, 0.5), drawBagIcon, "Your pets, rides and items",
			"Your guard dog, bones and gadgets" },
		{ PLUM:Lerp(Theme.PAPER, 0.5), drawEmblemIcon, "Your rebirths",
			("You will have %d"):format(nextR) },
	}) do
		summaryRow(keep, i, row[1], row[2], row[3], row[4])
	end

	-- ---------- C. STARTS OVER ----------
	local resets = ui.resets
	clear(resets, { Heading = true })
	local pill = Theme.STOP:Lerp(Theme.PAPER, 0.92)
	local _, coinsValue = summaryRow(resets, 1, Theme.GOLD:Lerp(Theme.PAPER, 0.35), drawCoinIcon,
		"Your coins", "Every coin in your piggy",
		("%s %s 0"):format(format(seen.coins), ARROW), pill)
	ui.coinsValue = coinsValue

	-- THE EARN FASTER ROW STOOD HERE, gated on `seen.incomeLevel > 1`. Nothing
	-- can raise that level any more, so the row could only ever have read
	-- "Lv 1 -> 1" -- and a reset of something nobody bought is not a cost.
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
		-- THE NAMES ON THE ROW RATHER THAN BEHIND A "VIEW UPGRADES" BUTTON, and
		-- that keeps the rule this file already sets for this column: the cost
		-- has to be somebody's ACTUAL AFTERNOON -- "Vault Lock, Fence" -- and
		-- not a definition. The expander that carried them was collapsed by
		-- default, so the row a player actually saw read only "Bought upgrades
		-- 5 -> 0"; naming three of them in the note is strictly more specific
		-- than the default view was and costs no second control.
		local names = {}
		for i = 1, math.min(#trees, 3) do
			table.insert(names, trees[i].name)
		end
		local note = table.concat(names, ", ")
		if #trees > #names then
			note = ("%s and %d more"):format(note, #trees - #names)
		end
		summaryRow(resets, 2, Theme.SAND_DEEP, drawGearIcon,
			"Your upgrade levels", note, ("%d %s 0"):format(#trees, ARROW), pill)
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
	-- NOTHING HIDES IT ANY MORE. It is a rail tile, and the rail is never
	-- hidden: the three tiles beside it stay up through the shop panel, the
	-- bag and the rebirth page, so a fourth that came and went would be the
	-- odd one out and would leave a hole in a rail whose height is counted
	-- from its visible children. What is left for `sync` is the pop.
	if ui.emphasiseNext then
		ui.emphasiseNext = false
		emphasise()
	end
end

function Rebirth.onEconomy(state: any)
	local before = seen.rebirths
	local wasReady = seen.ready
	seen.coins = state.coins or 0
	seen.rebirths = state.rebirths or 0
	seen.ready = state.rebirthReady == true
	-- The tile's caption is the WORD and never the count: 66 pixels wide is
	-- not the place for a number, and the page it opens leads with which
	-- rebirth this is.
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
		-- A COIN TICK REPAINTS, IT NEVER REBUILDS. This used to rebuild the
		-- whole page whenever `incomeLevel` moved, because a benefit card and a
		-- reset row both printed it; nothing on the page reads it now, and the
		-- three things that DO change under a reader -- the balance, the
		-- requirement bar and the confirm -- are exactly what `paintLive` owns.
		Rebirth.paintLive()
	end
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

-- REFILLS NOW, WHICH IT DID NOT BEFORE, because something on the page finally
-- reads this. Nothing here used the ride catalogue until the "Unlocks:" strip
-- named the rides a rebirth puts on sale, so a push arriving while the page
-- was open would have left that line describing the catalogue as it was at the
-- last cosmetics push. Guarded on the page being open, exactly as the other
-- three handlers are -- a fill on a closed page is work nobody can see.
function Rebirth.onRides(list: any)
	seen.rides = list
	if Rebirth.isOpen() then fill() end
end

-- Keeps the existing injection signature; the page draws its own art now.
function Rebirth.init(gui: ScreenGui, confirm: () -> (),
	_icon: ((GuiObject, Model, UDim2, UDim2, boolean) -> Instance)?, rail: Instance?)
	onConfirm = confirm
	-- The tile goes in the menu rail and the page stays on the ScreenGui. With
	-- no rail it falls back to the gui, which is a tile in the top-left corner
	-- rather than no rebirth button at all.
	buildButton(rail or gui)
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
