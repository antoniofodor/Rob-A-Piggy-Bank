--!strict
--[[
	Inventory -- WHAT YOU OWN, as opposed to what you can get.

	THE SHOP AND THE COLLECTION WERE ONE SCREEN, AND THAT STOPPED WORKING THE
	DAY DUPLICATES EXISTED. A card in the Piggy tab used to answer one
	question -- do you own this, and if not what does it cost -- so owning and
	buying could share a surface. Schema 18 gave every item a SPARE COUNT and
	two exits (sell it, or combine three of a tier), and neither of those is a
	purchase. Hanging them off a shop card would have meant one tile carrying
	a price, an equip toggle, a spare count and a sell button, which is four
	verbs on a 156-pixel card.

	So the split is by VERB, the same rule that gave the shop its tabs in the
	first place:

	  Crates      how you GET a cosmetic -- open, browse the pool, combine
	  Inventory   what you HAVE -- wear it, or turn a spare back into coins

	WHICH MEANS THIS TAB NEVER SHOWS A PRICE, and that is the property to
	preserve. The moment it does, it is the shop again and the reason for two
	tabs has gone.

	ONLY OWNED THINGS ARE HERE. A locked tile in an inventory is a shop card
	wearing a padlock -- the shop is where something you do not own is
	supposed to be advertised, and this file already argues that for ride
	stances and for Most Wanted gear. What an empty section says instead is
	where to go and get one.

	IT IS A MODULE FOR THE REASON `Crates`, `HotBar`, `AdminPanel`, `Rebirth`
	and `SpinWheel` ARE. `ClientMain` is one chunk against Luau's 200-local
	register ceiling and has hit it eight times; a function body gets its own
	register file, so this whole feature costs that chunk ZERO top-level
	locals -- the require sits inside the block that owns `iconFor`, holding
	no local at all, and the panel's open/closed state is an ATTRIBUTE on the
	ScreenGui rather than a flag. Overflowing that ceiling does not cost the
	feature, it costs the ENTIRE HUD, and the error names an innocent variable
	two thousand lines away.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local Config = require(ReplicatedStorage.Shared.Config)
local ShopStyle = require(ReplicatedStorage.Shared.ShopStyle)
local Theme = require(ReplicatedStorage.Shared.Theme)

local Inventory = {}

local DOT = utf8.char(0x00B7)

-- A card is the shop's own size, because the two tabs sit one tap apart and a
-- collection whose tiles were a different shape would read as a different
-- game. Taller than a shop card by the height of one control: a shop card
-- ends in a price row, this one ends in a price row AND an equip row.
local CARD_W = 156
local CARD_H = 196
local WELL_H = 86

-- THE SECTIONS ARE THE FIVE PLACES A COSMETIC GOES, in the order the shop
-- already lists them, so a player who knows the shop knows this. `owned` and
-- `worn` differ per catalogue because each service named its own fields years
-- apart -- resolved here once rather than at every read.
--
-- `wire` is what `CosmeticRequest` expects; rides are the exception and go
-- through `RideRequest`, which is why the field exists at all rather than the
-- kind being reused directly.
-- `tab` IS A SHORT WORD AND `title` IS NOT USED ON A TAB, because a rail is
-- read sideways at a glance. "LAWN AND KERB" is a section heading; "Lawn" is
-- a tab. The icons are the same glyphs the shop's own rail uses for the tab
-- each catalogue is SOLD on, so a player who knows where they bought a thing
-- recognises where it went.
local SECTIONS = {
	{ kind = "skin", from = "skins", tab = "Skins", icon = utf8.char(0x1F437),
		hue = "piggy", owned = "unlocked", worn = "equipped", wire = "skin",
		empty = "Open a crate, or buy one in the shop." },
	{ kind = "effect", from = "effects", tab = "Effects", icon = utf8.char(0x2728),
		hue = "effects", owned = "unlocked", worn = "equipped", wire = "effect",
		empty = "Effects are sold in the shop." },
	{ kind = "accessory", from = "accessories", tab = "Accessories",
		icon = utf8.char(0x1F452),
		hue = "worn", owned = "owned", worn = "worn", wire = "accessory",
		empty = "Roll one, or open a Dress-Up Crate." },
	{ kind = "decor", from = "decor", tab = "Lawn", icon = utf8.char(0x1F3E0),
		hue = "home", owned = "owned", worn = "placed", wire = "decor",
		empty = "Lawn ornaments are bought in the shop." },
	{ kind = "ride", from = "rides", tab = "Rides", icon = utf8.char(0x1F6F9),
		hue = "gear", owned = "owned", worn = "equipped", wire = "ride",
		empty = "Boards and bikes are bought in the shop." },
}

-- ---- state -----------------------------------------------------------------
--
-- ONE TABLE PER CONCERN AND ALL OF THEM ABOVE THE READERS. A `local` declared
-- after a function that reads it is a nil GLOBAL to that function and Luau
-- says nothing until the call dies naming nothing useful -- eight times in
-- this project so far.

local deps: any = nil
local rail: ScrollingFrame? = nil
local content: Frame? = nil
local scroll: ScrollingFrame? = nil
local tabs: { [string]: any } = {}
local active: string = SECTIONS[1].kind
-- Whether the player has picked a tab themselves. Until they have, `render`
-- is free to land them on one that has something in it; afterwards it must
-- not move them.
local chosen = false
local rows: { [string]: any } = {}
local cards: { [string]: any } = {}
local cosmetics: any = nil
local rideList: any = nil
-- KEYED `kind:key`, AND THE VALUE IS A RECORD RATHER THAN A COUNT.
-- `ChestService` sends `{ kind, key, name, count, tier, value, inUse }` per
-- spare, which is more than a number and deliberately so: the coin value and
-- the in-use test are the SERVER'S, computed by the same code that will
-- charge and refuse. Re-deriving either here would be two implementations of
-- one number, and one of them is money.
--
-- An item with no spare has NO ENTRY at all, which is the case the last-copy
-- sale runs in -- so nothing may assume a record exists.
local spares: { [string]: any } = {}

-- ---- helpers ---------------------------------------------------------------

local function entryKey(kind: string, key: string): string
	return kind .. ":" .. key
end

local function tierColour(tier: string): Color3
	local band = Config.RARITIES[tier]
	return (band and band.colour) or ShopStyle.SUNK
end

local function label(parent: Instance, text: string, size: UDim2, pos: UDim2,
	font: Enum.Font, textSize: number, colour: Color3): TextLabel
	local t = Instance.new("TextLabel")
	t.Size = size
	t.Position = pos
	t.BackgroundTransparency = 1
	t.Font = font
	t.TextSize = textSize
	t.TextColor3 = colour
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Text = text
	t.Parent = parent
	return t
end

-- The source table for a section, whichever push it arrived on. Rides come in
-- on `RideState` and everything else on `CosmeticState`; asking here keeps
-- every caller from branching.
local function sourceFor(section: any): any?
	if section.kind == "ride" then
		return rideList
	end
	return cosmetics and cosmetics[section.from]
end

-- WHAT A PLAYER MAY SELL, AND THE LAST-COPY RULE IS THE INTERESTING HALF.
--
-- You may sell your last copy -- that is a deliberate decision, and the sell
-- value is capped below what the item cost so there is no sell-and-rebuy loop
-- to close. What is guarded is the ACCIDENT: the copy IN USE cannot go, so a
-- stray thumb cannot delete the legendary somebody spent three weeks getting.
-- Taking it off first is one tap.
--
-- Mirrored from `ChestService.sell` rather than invented, and it is
-- PRESENTATION ONLY -- the server re-derives all of it and refuses out loud.
-- What this buys is that the button says what will happen before it is
-- pressed, instead of offering an action the server will reject.
local function sellable(kind: string, key: string, worn: boolean): (number, string?)
	if not Config.isSellable(kind, key) then
		return 0, nil
	end
	local record = spares[entryKey(kind, key)]
	if record and record.count > 0 then
		return record.count, nil
	end
	-- The last copy. `inUse` is the server's answer and covers all five equip
	-- sites at once; `worn` is this catalogue's own field and is what there is
	-- to go on when no record exists, which is exactly this branch.
	if worn then
		return 0, "WEARING"
	end
	return 1, nil
end

-- The server's figure when it sent one, and Config's otherwise. They agree by
-- construction -- `ChestService` calls the same function -- so this is about
-- there being no record for a last copy, not about a disagreement.
local function valueOf(kind: string, key: string): number
	local record = spares[entryKey(kind, key)]
	if record and type(record.value) == "number" then
		return record.value
	end
	return Config.sellValue(kind, key)
end

-- ---- one card --------------------------------------------------------------

local function buildCard(section: any, key: string, info: any): any
	local button = Instance.new("TextButton")
	button.Name = "Own_" .. section.kind .. "_" .. key
	button.Size = UDim2.new(0, CARD_W, 0, CARD_H)
	button.BackgroundColor3 = ShopStyle.CARD
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Text = ""
	ShopStyle.round(button, 14)

	-- A GUIOBJECT TAKES ONE UISTROKE, and rarity wins it -- the same call the
	-- shop card makes. It is the one edge carrying information, and on a tab
	-- where everything is owned it is the ONLY thing separating a common from
	-- a legendary.
	local tier = info.rarity or Config.rarityOf({ cost = info.cost })
	ShopStyle.outline(button, if tier == "legendary" then 5 else 3, tierColour(tier))

	local well = Instance.new("Frame")
	well.Name = "Well"
	well.Size = UDim2.new(1, -16, 0, WELL_H)
	well.Position = UDim2.new(0, 8, 0, 8)
	well.BackgroundColor3 = ShopStyle.SUNK
	well.BorderSizePixel = 0
	well.Parent = button
	ShopStyle.round(well, 10)
	if deps.iconFor then
		deps.iconFor(section.kind, key, well)
	end

	-- THE SPARE COUNT SITS ON THE PICTURE, not under it. It is the one fact
	-- this tab exists to show that the shop never had, and a player scanning
	-- for something to sell is looking for the number rather than reading the
	-- names. Hidden at zero -- "x0" on forty tiles is noise, and an absent
	-- chip is the faster read of "just the one".
	local spare = ShopStyle.chip(button, Theme.PRESTIGE, Theme.PAPER)
	spare.Name = "Spare"
	spare.Size = UDim2.new(0, 34, 0, 20)
	spare.Position = UDim2.new(1, -44, 0, 14)
	spare.Visible = false

	local title = label(button, info.name or key, UDim2.new(1, -16, 0, 18),
		UDim2.new(0, 8, 0, WELL_H + 12), Enum.Font.FredokaOne, 13, ShopStyle.TEXT)
	title.Name = "Title"
	title.TextTruncate = Enum.TextTruncate.AtEnd

	local wear = Instance.new("TextButton")
	wear.Name = "Wear"
	wear.Size = UDim2.new(1, -16, 0, 28)
	wear.Position = UDim2.new(0, 8, 0, WELL_H + 34)
	wear.BorderSizePixel = 0
	wear.AutoButtonColor = true
	wear.Font = Enum.Font.FredokaOne
	wear.TextSize = 13
	wear.Text = ""
	wear.Parent = button
	ShopStyle.round(wear, 8)
	ShopStyle.outline(wear, 2)

	local sell = Instance.new("TextButton")
	sell.Name = "Sell"
	sell.Size = UDim2.new(1, -16, 0, 26)
	sell.Position = UDim2.new(0, 8, 0, WELL_H + 66)
	sell.BorderSizePixel = 0
	sell.AutoButtonColor = true
	sell.Font = Enum.Font.FredokaOne
	sell.TextSize = 12
	sell.Text = ""
	sell.Parent = button
	ShopStyle.round(sell, 8)
	ShopStyle.outline(sell, 2)

	-- EQUIPPING IS A TOGGLE and always was: firing the same request again
	-- takes the thing off, which is the only way to empty a slot without a
	-- second control. Nothing here changes that -- this is the shop's own
	-- remote, so the two surfaces cannot disagree about what you are wearing.
	wear.Activated:Connect(function()
		if deps.equip then
			deps.equip(section.wire, key)
		end
	end)

	-- ONE AT A TIME, DELIBERATELY. A "sell all spares" control is one tap
	-- from emptying a collection, and the capacity rule makes a bulk sale the
	-- likeliest thing to be refused anyway -- the server takes the order whole
	-- or not at all, so selling four and being handed two cannot happen.
	sell.Activated:Connect(function()
		if deps.sell then
			deps.sell(section.kind, key, 1)
		end
	end)

	local card = { button = button, title = title, spare = spare,
		wear = wear, sell = sell }
	cards[entryKey(section.kind, key)] = card
	return card
end

-- ---- painting --------------------------------------------------------------

local function paintCard(section: any, key: string, info: any)
	local card = cards[entryKey(section.kind, key)]
	if not card then
		return
	end

	card.title.Text = info.name or key

	local record = spares[entryKey(section.kind, key)]
	local held = (record and record.count) or 0
	-- TOTAL COPIES, NOT SPARES. "x2" is what a nine-year-old reads as "I have
	-- two of these"; a chip saying "x1" beside an item they hold two of is the
	-- kind of off-by-one nobody reports, they just stop trusting the number.
	card.spare.Visible = held > 0
	card.spare.Text = "x" .. tostring(held + 1)

	-- The server's `inUse` when there is a record, since it asks all five
	-- equip sites rather than this one catalogue.
	local worn = info[section.worn] == true
	if record and record.inUse ~= nil then
		worn = record.inUse == true or worn
	end
	card.wear.Text = if worn then "WEARING" else "WEAR"
	card.wear.BackgroundColor3 = if worn then ShopStyle.OWNED else ShopStyle.BUY
	card.wear.TextColor3 = ShopStyle.INK

	local count, why = sellable(section.kind, key, worn)
	if count <= 0 then
		card.sell.Visible = why ~= nil
		-- NAMED RATHER THAN HIDDEN. A control that vanishes teaches nothing;
		-- one that says WEARING teaches the rule in a word, and this file's
		-- standing rule is that a refusal nobody can see is indistinguishable
		-- from a broken feature.
		card.sell.Text = why or ""
		card.sell.BackgroundColor3 = ShopStyle.LOCKED
		card.sell.TextColor3 = ShopStyle.MUTED
		card.sell.AutoButtonColor = false
		return
	end

	card.sell.Visible = true
	card.sell.AutoButtonColor = true
	card.sell.BackgroundColor3 = ShopStyle.DEAR
	card.sell.TextColor3 = Theme.GOLD_INK
	card.sell.Text = "SELL " .. deps.format(valueOf(section.kind, key))
end

-- ---- the rail --------------------------------------------------------------
--
-- FIVE TABS RATHER THAN FIVE SECTIONS DOWN ONE SCROLL. Owning everything is
-- 71 cards, which is about five screens of scrolling to reach the rides --
-- and unlike a shop, where scrolling past things you cannot afford is half
-- the point, nothing in here is being advertised. You came looking for a
-- specific thing you already own.
--
-- THE SELECTED TAB IS THE ONLY ONE WEARING ITS COLOUR, which is the rule the
-- shop's own rail already follows: five saturated buttons in a row have no
-- winner, so nothing answers "where am I" -- the only question a rail exists
-- to answer.

local function selectKind(kind: string, byPlayer: boolean?)
	active = kind
	if byPlayer then
		chosen = true
	end
	for key, tab in pairs(tabs) do
		local on = key == kind
		local hue = Theme.HUE[tab.section.hue] or ShopStyle.CARD
		tab.button.BackgroundColor3 = if on then hue else Theme.PAPER
		tab.label.TextColor3 = ShopStyle.INK
		-- The active tab stands taller as well as brighter. Colour alone
		-- separates a selection only for players who can see the difference
		-- between two hues, which is the same two-channel argument the
		-- rarity borders make.
		tab.button.Size = UDim2.new(0, tab.width, 0, if on then 40 else 34)
	end
	for key, row in pairs(rows) do
		row.holder.Visible = key == kind
	end
end

local function ensureTab(section: any, order: number): any
	local tab = tabs[section.kind]
	if tab then
		return tab
	end

	-- MEASURED PER LABEL, NEVER A FLAT WIDTH. The shop's rail shipped eight
	-- tabs at a flat 102 and overflowed its band; sized to their own words
	-- they fit with room to spare. "Skins" and "Accessories" are 34 and 79
	-- pixels at 13px FredokaOne, so a flat width is wrong for both.
	--
	-- The COUNT is a fixed-width chip rather than part of the measured
	-- string, so a tab does not change width the moment you gain an item.
	local width = 77 + math.ceil(TextService:GetTextSize(
		section.tab, 13, Enum.Font.FredokaOne, Vector2.new(9999, 100)).X)

	local button = Instance.new("TextButton")
	button.Name = "Tab_" .. section.kind
	button.Size = UDim2.new(0, width, 0, 34)
	button.BackgroundColor3 = Theme.PAPER
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.LayoutOrder = order
	button.Text = ""
	button.Parent = rail
	ShopStyle.round(button, 10)
	ShopStyle.outline(button, 3)

	local glyph = label(button, section.icon, UDim2.new(0, 22, 1, 0),
		UDim2.new(0, 8, 0, 0), Enum.Font.FredokaOne, 15, ShopStyle.INK)
	glyph.Name = "Glyph"

	local text = label(button, section.tab, UDim2.new(1, -68, 1, 0),
		UDim2.new(0, 32, 0, 0), Enum.Font.FredokaOne, 13, ShopStyle.INK)
	text.Name = "Label"

	-- A COUNT ON THE TAB IS THE WHOLE REASON A TAB BEATS A SECTION HEADING
	-- HERE: it says how much is behind a door you have not opened, so an
	-- empty category is legible without visiting it.
	local count = ShopStyle.chip(button, ShopStyle.SUNK, Theme.MUTED_LIGHT)
	count.Name = "Count"
	count.Size = UDim2.new(0, 30, 0, 20)
	count.Position = UDim2.new(1, -36, 0.5, -10)
	count.Text = "0"

	button.Activated:Connect(function()
		selectKind(section.kind, true)
	end)

	tab = { button = button, label = text, count = count,
		width = width, section = section }
	tabs[section.kind] = tab
	return tab
end

-- ---- one section -----------------------------------------------------------

local function ensureRow(section: any, order: number): any
	local row = rows[section.kind]
	if row then
		return row
	end

	-- EVERY ROW IS PARENTED TO THE SAME SCROLL AND ALL BUT ONE IS HIDDEN.
	-- A tab does not need its own ScrollingFrame: five of them means five
	-- canvases to keep in step and five scroll positions to remember, for a
	-- panel that shows exactly one at a time.
	local holder = Instance.new("Frame")
	holder.Name = "Row_" .. section.kind
	holder.Size = UDim2.new(1, 0, 0, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	holder.LayoutOrder = order
	holder.Visible = section.kind == active
	holder.Parent = scroll

	-- NO SECTION HEADING, because the selected tab already is one. Two names
	-- for one thing on one screen is the redundancy the shop's own header
	-- lost when the tabs learned to carry words.
	--
	-- AN EMPTY SECTION NAMES THE WAY OUT. "You own no skins" is a report;
	-- "open a crate" is the same fact with somewhere to go, and on a brand
	-- new save every one of these five is empty at once.
	local blank = label(holder, section.empty, UDim2.new(1, -8, 0, 20),
		UDim2.new(0, 4, 0, 4), Enum.Font.Gotham, 13, ShopStyle.MUTED)
	blank.Name = "Empty"

	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.Size = UDim2.new(1, 0, 0, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.BackgroundTransparency = 1
	grid.Parent = holder

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0, CARD_W, 0, CARD_H)
	layout.CellPadding = UDim2.new(0, 10, 0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	row = { holder = holder, grid = grid, blank = blank }
	rows[section.kind] = row
	return row
end

-- ---- render ----------------------------------------------------------------

function Inventory.render()
	if not scroll then
		return
	end

	local total, spareTotal = 0, 0

	for index, section in ipairs(SECTIONS) do
		ensureTab(section, index)
		local row = ensureRow(section, index)
		local source = sourceFor(section)
		local shown = 0

		-- BUILT ONCE, PAINTED EVERY PUSH. This runs off `CosmeticState`,
		-- `RideState` and `ChestState`, so a rebuild per push would tear down
		-- and re-create every ViewportFrame in the tab several times a minute
		-- -- and a ViewportFrame is the single most expensive thing on this
		-- screen.
		if source then
			for key, info in pairs(source) do
				if type(info) == "table" and info[section.owned] == true then
					local card = cards[entryKey(section.kind, key)]
					if not card then
						card = buildCard(section, key, info)
						card.button.Parent = row.grid
					end
					card.button.Visible = true
					card.button.LayoutOrder = info.order or 0
					paintCard(section, key, info)
					shown += 1
					local rec = spares[entryKey(section.kind, key)]
					spareTotal += (rec and rec.count) or 0
				end
			end
		end

		-- A CARD FOR SOMETHING NO LONGER OWNED IS HIDDEN, NEVER DESTROYED.
		-- Selling your last copy is legal, so a tile really can leave this
		-- list -- and rebuilding its viewport if it comes back is dearer than
		-- keeping a hidden frame around.
		for entry, card in pairs(cards) do
			local kind = entry:match("^(%a+):")
			if kind == section.kind then
				local key = entry:sub(#kind + 2)
				local info = source and source[key]
				if not (type(info) == "table" and info[section.owned] == true) then
					card.button.Visible = false
				end
			end
		end

		tabs[section.kind].count.Text = tostring(shown)
		row.blank.Visible = shown == 0
		row.grid.Visible = shown > 0
		total += shown
	end

	-- LAND ON A TAB WITH SOMETHING IN IT, but only before anybody has chosen
	-- one. A player who taps Rides and then sells their last board should be
	-- looking at an empty Rides tab that tells them where to get one -- being
	-- silently moved somewhere else is the panel arguing with them.
	if not chosen then
		for _, section in ipairs(SECTIONS) do
			local row = rows[section.kind]
			if row and row.grid.Visible then
				selectKind(section.kind)
				break
			end
		end
	end

	if deps.onSummary then
		deps.onSummary(total, spareTotal)
	end
end

-- ---- pushes ----------------------------------------------------------------
--
-- THREE SOURCES, AND EACH ONE ONLY EVER ARRIVES ON ITS OWN REMOTE. Rendering
-- from whichever handler happened to be wired first is the bug the shop's
-- front page already shipped and had to fix: the catalogues land at join in no
-- fixed order, so a tab drawn from one of them shows blank sections for
-- everything that had not arrived yet.

function Inventory.setCosmetics(snapshot: any)
	cosmetics = snapshot
	Inventory.render()
end

function Inventory.setRides(snapshot: any)
	rideList = snapshot and snapshot.rides
	Inventory.render()
end

function Inventory.setChest(state: any)
	spares = (state and state.spares) or {}
	Inventory.render()
end

function Inventory.init(view: Frame, injected: any)
	deps = injected

	label(view, "Everything you own.", UDim2.new(1, -8, 0, 22),
		UDim2.new(0, 4, 0, 0), Enum.Font.FredokaOne, 17, ShopStyle.TEXT)
	label(view, "Tap to wear it. A spare is a second copy " .. DOT
		.. " sell one for coins you can spend.",
		UDim2.new(1, -8, 0, 18), UDim2.new(0, 4, 0, 22), Enum.Font.Gotham, 12,
		ShopStyle.MUTED)

	-- A SCROLLING RAIL, for the reason the shop's is one: a UIListLayout does
	-- not clip and does not error, it keeps drawing past the edge -- which is
	-- how two shop tabs were once eaten whole with nothing on screen to say
	-- they existed. Five tabs fit today; a sixth cannot bring that bug back.
	local bar = Instance.new("ScrollingFrame")
	bar.Name = "InventoryRail"
	-- 54 RATHER THAN 44, AND THE EXTRA TEN IS THE STROKE'S. A tab's outline
	-- is `ApplyStrokeMode.Border`, so it draws OUTSIDE the button -- 3 studs
	-- above and 3 below -- and a ScrollingFrame clips exactly that region.
	-- Measured before the fix: the selected tab stood 40 tall flush against
	-- the rail's bottom edge at y 153.5, so its outline wanted 156.5 and the
	-- bottom 3 pixels were cut off, in the one place a player would read it
	-- as the item grid slicing the tabs off.
	--
	-- Sized for the SELECTED tab, which is the tall one at 40: 40 + 6 of
	-- stroke + 10 of padding is 56. Sizing against the 34-tall resting state
	-- is the version that looks right until somebody presses something.
	--
	-- 56 AND NOT 54, because 54 left ONE PIXEL under the bottom stroke.
	-- Measured, it cleared -- and a one-pixel margin is the same class of
	-- number as a label that reports `TextFits` true while touching its own
	-- frame edge. It clears by 3 now, top and bottom, so a stroke that ever
	-- goes to 4 does not put this bug straight back.
	--
	-- Same class as the shop's own first tab losing its left border, and the
	-- first column of cosmetic cards losing theirs. THE RULE IS THE ONE THIS
	-- FILE KEEPS RELEARNING: an outside stroke needs clearance from every
	-- clipping ancestor, and the clip is at the frame's bounds rather than
	-- inside its padding.
	bar.Size = UDim2.new(1, 0, 0, 56)
	bar.Position = UDim2.new(0, 0, 0, 46)
	bar.BackgroundTransparency = 1
	bar.BorderSizePixel = 0
	bar.ScrollBarThickness = 0
	bar.ScrollingDirection = Enum.ScrollingDirection.X
	bar.CanvasSize = UDim2.new()
	bar.AutomaticCanvasSize = Enum.AutomaticSize.X
	bar.Parent = view
	rail = bar

	local railLayout = Instance.new("UIListLayout")
	railLayout.FillDirection = Enum.FillDirection.Horizontal
	railLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	railLayout.Padding = UDim.new(0, 8)
	railLayout.SortOrder = Enum.SortOrder.LayoutOrder
	railLayout.Parent = bar

	-- Four pixels of clearance, because a `Border` stroke draws OUTSIDE its
	-- frame and a ScrollingFrame clips exactly that -- which is what cut the
	-- left edge off the shop's own first tab.
	local railPad = Instance.new("UIPadding")
	railPad.PaddingLeft = UDim.new(0, 4)
	railPad.PaddingRight = UDim.new(0, 4)
	-- Vertical clearance for the same stroke. The tabs are bottom-aligned, so
	-- the bottom pad is what actually lifts the outline back inside the clip;
	-- the top pad keeps a pressed tab's own outline off the ceiling.
	railPad.PaddingTop = UDim.new(0, 4)
	railPad.PaddingBottom = UDim.new(0, 6)
	railPad.Parent = bar

	local list = Instance.new("ScrollingFrame")
	list.Name = "InventoryList"
	-- Follows the rail down by the ten it grew, keeping the same 6-pixel gap.
	list.Size = UDim2.new(1, 0, 1, -108)
	list.Position = UDim2.new(0, 0, 0, 108)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = view

	-- A `Border` STROKE DRAWS OUTSIDE THE PART, and a ScrollingFrame clips
	-- exactly that region -- which is how the shop's first column and its
	-- first tab both lost an edge. Every card in here carries a rarity stroke,
	-- so the leftmost column of every row needs the clearance.
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 4)
	pad.Parent = list

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 18)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	scroll = list
	Inventory.render()
	selectKind(active)
end

return Inventory
