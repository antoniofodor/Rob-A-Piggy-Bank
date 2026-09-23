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

local Config = require(ReplicatedStorage.Shared.Config)
local ShopStyle = require(ReplicatedStorage.Shared.ShopStyle)
local Theme = require(ReplicatedStorage.Shared.Theme)
local SkinCards = require(ReplicatedStorage.Shared.ShopSkinCards)
local W = require(ReplicatedStorage.Shared.ShopWidgets)

local Inventory = {}


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
	-- SKINS ARE A COLLECTION LOG RATHER THAN A LIST, which is the one section
	-- here that shows things you do NOT own.
	--
	-- THAT REVERSES THIS PANEL'S OWN RULE, deliberately, and the rule's own
	-- reasoning is what expired. It read: "a locked tile in an inventory is a
	-- shop card wearing a padlock -- the shop is where something you do not
	-- own is supposed to be advertised". True while skins were bought. They
	-- are CRATE-ONLY now, so the shop has no price to show and no buy button
	-- to press for one: there is nowhere else a player can see what they are
	-- missing. A log with no gaps in it is a list.
	--
	-- The gaps are also the whole point of the format. What makes a set worth
	-- finishing is seeing the holes in it, and a missing card here names the
	-- crate that fills it and opens the shop at it.
	{ kind = "skin", from = "skins", tab = "Skins", icon = utf8.char(0x1F437),
		hue = "style", art = "style", owned = "unlocked", worn = "equipped", wire = "skin",
		collection = true,
		empty = "Open a crate. Skins come from nowhere else." },
	-- THE LAWN TAB WENT WITH THE LAWN. `Config.DECOR_ITEMS` is empty, so this
	-- was a tab that could only ever show its own empty state -- and a rail
	-- slot opening a blank page is what took the Piggy tab and the Trophies
	-- tab before it.
	-- THE TROPHIES TAB IS GONE WITH THE TROPHIES. It was a collection log over
	-- `Config.TROPHIES`, which is empty now -- see the note there for why the
	-- ten went and what replaced them. AN EMPTY TAB IS NOT AN OPTION: a rail
	-- slot that opens a blank page reads as a shop that failed to load, which
	-- is the argument that removed the Piggy tab rather than leaving it holding
	-- one section.
	--
	-- What a player can still see of that progress is the three stat panels on
	-- their own wall, which is where an MVP wants it.
	--
	-- AND THE `log` BRANCHES WENT WITH IT, which the first pass left behind on
	-- the claim that "it is the same branch the Skins tab needs". IT IS NOT:
	-- Skins is `collection = true` and walks `Config.skinCollections()`, and
	-- `log` was only ever this section's. Three unreachable branches behind a
	-- comment asserting they were load-bearing is the shape this project keeps
	-- paying for -- so they are gone, and a trophy ladder coming back brings
	-- its own back with it.
	{ kind = "ride", from = "rides", tab = "Rides", icon = utf8.char(0x1F6F9),
		hue = "rides", art = "rides", owned = "owned", worn = "equipped", wire = "ride",
		empty = "Boards and bikes are bought in the shop." },
	-- MOST WANTED GEAR is earned by escaping a wanted pursuit and never
	-- bought, so it lives here and not in the shop. The push is a LIST, not a
	-- keyed table -- `sourceFor` keys it -- and only unlocked pieces show.
	{ kind = "gear", from = "gear", tab = "Outfit", icon = utf8.char(0x1F3AD),
		hue = "supplies", model = "facemask", owned = "unlocked", worn = "equipped", wire = "gear",
		empty = "Top the Most Wanted board, then outrun the patrol to earn one." },
	-- NAB EFFECTS took the tab FINISHES had. What goes off on a thief you nab
	-- is something a player chooses and changes, which is exactly what this
	-- panel is for -- and until now the only place to switch one was the
	-- Guardians shelf in the shop. `catches` carries every effect with an
	-- `unlocked` flag, so only owned ones show; "None" is free and owned by
	-- everybody, and wearing it is how an effect is switched off. The server
	-- equips on an owned key rather than toggling, so there is no second
	-- press to take one off -- None is that press.
	{ kind = "catch", from = "catches", tab = "Nab Effects", icon = utf8.char(0x1F389),
		hue = "companions", model = "partypopper",
		owned = "unlocked", worn = "equipped", wire = "catch",
		empty = "Nab effects are in the shop, on the Guardians shelf." },
}

-- ---- state -----------------------------------------------------------------
--
-- ONE TABLE PER CONCERN AND ALL OF THEM ABOVE THE READERS. A `local` declared
-- after a function that reads it is a nil GLOBAL to that function and Luau
-- says nothing until the call dies naming nothing useful -- eight times in
-- this project so far.

local deps: any = nil
local rail: ScrollingFrame? = nil
-- The shop's own furniture, built by `buildChrome`: masthead, sign, balances.
local chrome: any = nil
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
-- THE SHORT-SCREEN REFIT, and it is here because the SHOP had one and this
-- panel did not.
--
-- NOTE THE SHOP'S HAS SINCE BEEN LOST, which is why this says "had". HEAD
-- carries a `refitCards` in ClientMain that shrank the shop's cards on a short
-- viewport; the working copy has none, and `cardFit.scale` is left with seven
-- readers and no writer, so it sits at 1 forever. This panel's own refit below
-- is unaffected -- it is self-contained -- but the two are meant to agree, so
-- restoring that one is what makes the threshold below true again. Reported to
-- the session holding the shop files rather than fixed here.
--
-- Measured on a phone
-- held sideways -- the shortest thing that has to work, 546 tall -- the bag
-- showed 1.4 rows of card against a desktop's 2.3, and the collection log's
-- group headings cost another 28 apiece on top.
--
-- Same mechanism as the shop's on purpose: ONE design at two sizes rather
-- than a second set of offsets. A `UIScale` on the card takes the whole thing
-- with it -- well, title, buttons, padding and type -- and the grid cell
-- shrinks by the same factor so more columns fit as well as more rows.
local panelView: Frame? = nil
local cardScale = 1
local cardScales: { UIScale } = {}
local cardGrids: { UIGridLayout } = {}
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
-- The decor/trophy split that used to live here went with the Trophies tab:
-- no row in `Config.DECOR_ITEMS` carries a `trophy` key any more, so there is
-- one catalogue and one tab reading it.
local function sourceFor(section: any): any?
	if section.kind == "ride" then
		return rideList
	end
	if section.kind == "gear" then
		local list = cosmetics and cosmetics.gear
		if type(list) ~= "table" then
			return nil
		end
		local byKey = {}
		for i, info in ipairs(list) do
			if type(info) == "table" and info.key then
				info.order = info.order or i
				byKey[info.key] = info
			end
		end
		return byKey
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

	-- Registered before anything is painted, so a card built while the panel
	-- is already small is born at the right size rather than full size until
	-- the next resize.
	local fit = Instance.new("UIScale")
	fit.Scale = cardScale
	fit.Parent = button
	table.insert(cardScales, fit)

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
	-- THE WHOLE CARD WEARS THE TIER, so the well is cleared before the icon
	-- goes in -- `iconFor` would otherwise lay a second ground inside it.
	local palette = SkinCards.dressCard(button, tier, { well })
	local deep = if palette then palette.deep else ShopStyle.INK
	if deps.iconFor then
		deps.iconFor(section.kind, key, well)
	end

	-- NOT OWNED DIMS THE WHOLE CARD, above the tier ground and below
	-- everything printed on it, so a missing skin still says which tier it is
	-- and reads as the same card with the lights down.
	local dim = Instance.new("Frame")
	dim.Name = "MissingDim"
	dim.Size = UDim2.new(1, 0, 1, 0)
	dim.BackgroundColor3 = Theme.INK
	dim.BackgroundTransparency = 0.5
	dim.BorderSizePixel = 0
	dim.ZIndex = 0
	dim.Visible = false
	dim.Parent = button
	ShopStyle.round(dim, 14)

	-- WHAT A MISSING SKIN LOOKS LIKE, and it is a DIM rather than a
	-- silhouette. The shop greys its locked previews by walking the model and
	-- repainting every part, which needs a paint list per item and knows what
	-- a skin is made of; a sheet laid over the well costs one frame and works
	-- for any model the icon builder returns. It also keeps the skin
	-- RECOGNISABLE, which is what a collection log wants -- you are meant to
	-- see the thing you are missing, not a question mark.
	local shade = Instance.new("Frame")
	shade.Name = "Shade"
	shade.Size = UDim2.new(1, 0, 1, 0)
	shade.BackgroundColor3 = ShopStyle.SUNK
	shade.BackgroundTransparency = 0.45
	shade.BorderSizePixel = 0
	shade.ZIndex = 5
	shade.Visible = false
	shade.Parent = well
	ShopStyle.round(shade, 10)

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
	SkinCards.onTierText(title)
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
		-- THE CARD'S OWN STATE, READ AT PRESS TIME. A locked card reuses this
		-- control as its crate button rather than growing a fourth widget on
		-- a 156-pixel tile, so what the press MEANS depends on what the card
		-- is showing right now -- and `paintCard` is the only thing that
		-- knows. Reading a captured boolean instead would be a second copy of
		-- the state, stale from the first repaint.
		local self = cards[entryKey(section.kind, key)]
		if self and self.crate then
			if deps.openCrate then
				deps.openCrate(self.crate)
			end
			return
		end
		if self and self.locked then
			-- No crate hands this one over. The label already names what does.
			return
		end
		-- A SECTION WITH NO `wire` HAS NOTHING TO EQUIP, and the guard is the
		-- section's own field rather than its kind. Trophies are the first:
		-- which ones are displayed is decided by the house template's mounts,
		-- so a WEAR press has nothing to ask for -- and `deps.equip(nil, key)`
		-- would fire a remote naming no catalogue, which the server can only
		-- refuse silently. The label reads ON SHOW rather than WEAR, so the
		-- card is not offering an action in the first place.
		if deps.equip and section.wire then
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

	for _, control in ipairs({ wear, sell }) do
		local edge = control:FindFirstChildOfClass("UIStroke")
		if edge then edge.Color = deep end
	end
	local card = { button = button, title = title, spare = spare,
		wear = wear, sell = sell, shade = shade, dim = dim, deep = deep,
		-- Set by `paintCard` every repaint. `locked` is "you do not own it";
		-- `crate` is the chest key that would fix that, or nil where no crate
		-- can -- the rebirth drops, the pass skins and the set skin.
		locked = false, crate = nil :: string? }
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

	-- ---- the gap in the log ------------------------------------------------
	--
	-- A skin the player has not got. The card keeps its picture and loses its
	-- two verbs: there is nothing to wear and nothing to sell, and what
	-- replaces them is the one thing worth knowing -- where it comes from.
	local owned = info[section.owned] == true
	if section.collection and not owned then
		local where, crate = Config.skinSource(key)
		card.locked = true
		card.crate = crate
		card.shade.Visible = true
		card.dim.Visible = true
		card.spare.Visible = false
		card.title.TextTransparency = 0.25
		card.sell.Visible = false

		card.wear.Visible = true
		if crate then
			-- "OPEN CRATE" rather than the crate's own name, which the group
			-- heading directly above already carries -- measured, "OPEN PIGGY
			-- CLASSICS" is about 140px at 13px FredokaOne in a 140px button,
			-- which is the silent-shrink trap this project keeps paying for.
			card.wear.Text = "OPEN CRATE"
			card.wear.BackgroundColor3 = Theme.PAPER
			card.wear.TextColor3 = card.deep
			card.wear.AutoButtonColor = true
		else
			-- Nothing to open. Naming the source is the whole content of the
			-- card in this state, and a dead button that says REBIRTH 3 is a
			-- better answer than a live one that goes somewhere useless.
			card.wear.Text = string.upper(where)
			card.wear.BackgroundColor3 = card.deep
			card.wear.TextColor3 = Theme.PAPER
			card.wear.AutoButtonColor = false
		end
		return
	end

	card.locked = false
	card.crate = nil
	card.shade.Visible = false
	card.dim.Visible = false
	card.title.TextTransparency = 0
	card.wear.Visible = true

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
	-- Worn is the solid pill in the tier's deep shade; not worn the hollow one.
	card.wear.BackgroundColor3 = if worn then card.deep else Theme.PAPER
	card.wear.TextColor3 = if worn then Theme.PAPER else card.deep

	local count, why = sellable(section.kind, key, worn)
	if count <= 0 then
		card.sell.Visible = why ~= nil
		-- NAMED RATHER THAN HIDDEN. A control that vanishes teaches nothing;
		-- one that says WEARING teaches the rule in a word, and this file's
		-- standing rule is that a refusal nobody can see is indistinguishable
		-- from a broken feature.
		card.sell.Text = why or ""
		card.sell.BackgroundColor3 = Theme.PAPER
		card.sell.BackgroundTransparency = 0.45
		card.sell.TextColor3 = card.deep
		card.sell.AutoButtonColor = false
		return
	end

	card.sell.Visible = true
	card.sell.AutoButtonColor = true
	card.sell.BackgroundTransparency = 0
	card.sell.BackgroundColor3 = ShopStyle.DEAR
	card.sell.TextColor3 = Theme.GOLD_INK
	-- ONE CURRENCY. A skin used to sell for acorns and everything else for
	-- coins; the acorn half retired with the currency.
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

local function hueOf(section: any): Color3
	return W.colours[section.hue] or ShopStyle.CARD
end

local layout: () -> ()

local function selectKind(kind: string, byPlayer: boolean?)
	active = kind
	if byPlayer then
		chosen = true
	end
	for key, tab in pairs(tabs) do
		local on = key == kind
		local hue = hueOf(tab.section)
		-- The shop sidebar's own two channels: the active entry wears its
		-- colour at full strength AND protrudes, the rest sit pale and in line.
		tab.button.BackgroundColor3 = if on then hue else hue:Lerp(Theme.PAPER, 0.65)
		tab.button.Size = if on then UDim2.new(1, -4, 0, 52) else UDim2.new(1, -14, 0, 48)
		if on and chrome then
			-- THE SIGN WEARS THE OPEN TAB'S COLOUR, as the shop's does, so the
			-- sign and the sidebar entry are one colour rather than two.
			chrome.signFill.BackgroundColor3 = hue
			chrome.signTip.BackgroundColor3 = hue
		end
	end
	for key, row in pairs(rows) do
		row.holder.Visible = key == kind
	end
end

-- A SIDEBAR ENTRY IS THE SHOP'S: an icon, a label and a pale tint of its
-- category colour. The count chip is the bag's own addition -- it says how
-- much is behind a door you have not opened.
local function ensureTab(section: any, order: number): any
	local tab = tabs[section.kind]
	if tab then
		return tab
	end

	local hue = hueOf(section)
	local button = W.button(rail, "Tab_" .. section.kind, "", hue:Lerp(Theme.PAPER, 0.65), function()
		selectKind(section.kind, true)
	end)
	button.Size = UDim2.new(1, -14, 0, 48)
	button.LayoutOrder = order

	local icon = W.frame(button, "Icon")
	icon.BackgroundTransparency = 1
	icon.Position = UDim2.fromOffset(7, 5)
	icon.Size = UDim2.fromOffset(38, 38)

	local text = W.text(button, "Label", section.tab, 15)
	text.Position = UDim2.fromOffset(52, 0)
	text.Size = UDim2.new(1, -92, 1, 0)
	text.TextWrapped = true
	text.TextTruncate = Enum.TextTruncate.None
	-- White with an ink line round each letter, as the shop's sidebar labels.
	ShopStyle.popText(text)

	local count = ShopStyle.chip(button, ShopStyle.SUNK, Theme.MUTED_LIGHT)
	count.Name = "Count"
	count.Size = UDim2.new(0, 30, 0, 20)
	count.Position = UDim2.new(1, -36, 0.5, -10)
	count.Text = "0"

	-- THE ICON IS THE SHOP'S ART where the shop has some for this category,
	-- and otherwise the real item, unframed. The glyph is the last resort,
	-- so a failed model costs a picture rather than the tab.
	task.defer(function()
		if section.art and W.icon(icon, section.art) then
			return
		end
		local ok, model = pcall(function(): Model?
			if section.kind == "catch" then
				return require(ReplicatedStorage.Shared.CatchIcons).build(section.model)
			elseif section.kind == "gear" then
				return require(ReplicatedStorage.Shared.PlayerGear).build(section.model)
			end
			return nil
		end)
		if ok and model then
			W.preview(icon, model)
		else
			local glyph = W.text(icon, "Glyph", section.icon, 24)
			glyph.Size = UDim2.fromScale(1, 1)
			glyph.TextXAlignment = Enum.TextXAlignment.Center
		end
	end)

	tab = { button = button, label = text, count = count, icon = icon, section = section }
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
	layout.CellSize = UDim2.new(0, math.floor(CARD_W * cardScale), 0, math.floor(CARD_H * cardScale))
	layout.CellPadding = UDim2.new(0, 10, 0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	table.insert(cardGrids, layout)

	-- A COLLECTION STACKS GROUPS DOWN THE HOLDER, so it needs a layout the
	-- flat sections do not. `blank` and the flat `grid` become invisible
	-- children of it, which a UIListLayout skips -- so the two arrangements
	-- coexist without a branch anywhere else in this file.
	if section.collection then
		grid.Visible = false
		local stack = Instance.new("UIListLayout")
		stack.FillDirection = Enum.FillDirection.Vertical
		stack.Padding = UDim.new(0, 14)
		stack.SortOrder = Enum.SortOrder.LayoutOrder
		stack.Parent = holder
	end

	row = { holder = holder, grid = grid, blank = blank, groups = {} }
	rows[section.kind] = row
	return row
end

-- ---- one group inside a collection ----------------------------------------
--
-- A heading, a progress count and a grid. The heading is the CRATE'S name,
-- because `Config.skinCollections` derives it from the crate that fills the
-- group -- so a player reading "Animal Kingdom" here is reading the name of
-- the thing to go and buy, rather than a category invented for this menu.
local function ensureGroup(section: any, row: any, group: any, order: number): any
	local existing = row.groups[group.key]
	if existing then
		return existing
	end

	local holder = Instance.new("Frame")
	holder.Name = "Group_" .. group.key
	holder.Size = UDim2.new(1, 0, 0, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	holder.LayoutOrder = order
	holder.Parent = row.holder

	-- STACKED BY A LAYOUT RATHER THAN BY OFFSETS, and the first attempt was
	-- the reason. `AutomaticSize` measures a child's SIZE and ignores its
	-- Position, so a grid pushed down 24 pixels to clear the heading left the
	-- holder 24 short and every group overlapped the next. Padding the holder
	-- looks like the fix and is not: padding shifts EVERY child, so the
	-- heading came down with the grid and landed on top of it -- photographed,
	-- the count read "/ 17" beside the first row of cards with no heading
	-- anywhere. A vertical list cannot have either fault.
	local stack = Instance.new("UIListLayout")
	stack.FillDirection = Enum.FillDirection.Vertical
	stack.Padding = UDim.new(0, 6)
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Parent = holder

	-- The heading is a ROW rather than two labels, because a UIListLayout
	-- lays out its children and two siblings would stack vertically.
	local headRow = Instance.new("Frame")
	headRow.Name = "HeadRow"
	headRow.Size = UDim2.new(1, 0, 0, 22)
	headRow.BackgroundTransparency = 1
	headRow.LayoutOrder = 1
	headRow.Parent = holder

	local head = label(headRow, group.name, UDim2.new(1, -110, 1, 0),
		UDim2.new(0, 4, 0, 0), Enum.Font.FredokaOne, 15, ShopStyle.TEXT)
	head.Name = "Head"
	head.TextTruncate = Enum.TextTruncate.AtEnd

	-- RIGHT-ALIGNED AND FIXED WIDTH, so the heading beside it never reflows
	-- as the count changes. "17 / 17" is the widest this gets.
	local count = label(headRow, "", UDim2.new(0, 100, 1, 0),
		UDim2.new(1, -104, 0, 0), Enum.Font.FredokaOne, 13, ShopStyle.MUTED)
	count.Name = "Count"
	count.TextXAlignment = Enum.TextXAlignment.Right

	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.Size = UDim2.new(1, 0, 0, 0)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.BackgroundTransparency = 1
	grid.LayoutOrder = 2
	grid.Parent = holder

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0, math.floor(CARD_W * cardScale), 0, math.floor(CARD_H * cardScale))
	layout.CellPadding = UDim2.new(0, 10, 0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	table.insert(cardGrids, layout)

	local made = { holder = holder, head = head, count = count, grid = grid }
	row.groups[group.key] = made
	return made
end

-- ---- the short-screen refit ------------------------------------------------

--[[
	One design at two sizes, driven by the panel's own height.

	THE THRESHOLD IS THE SHOP'S, DELIBERATELY. The shop's `refitCards` shrank
	as soon as two full rows would not fit -- see the note above, it is in HEAD
	and absent from the working copy -- and a player moving between the shop
	and the bag on one device should not meet two different card
	sizes -- so the rule is copied rather than re-derived, and 0.78 is the same
	floor for the same reason: it takes the 13px name to 10, which is the
	smallest a nine-year-old should be asked to read.

	The group headings are NOT scaled. They are the one thing on this panel
	that has to stay legible at a glance on a phone, they are already the
	smallest type here that carries a word rather than a number, and at four
	of them they cost 112 pixels against a card grid measured in thousands.
]]
local function refit()
	local v = panelView
	if not v then
		return
	end
	-- The list's own height: the masthead is already off it.
	local list = scroll
	local room = if list then list.AbsoluteSize.Y else v.AbsoluteSize.Y - 102
	local want = if room < 2 * (CARD_H + 10) then 0.78 else 1
	if want == cardScale then
		return
	end
	cardScale = want
	local cell = UDim2.new(0, math.floor(CARD_W * want), 0, math.floor(CARD_H * want))
	for _, g in ipairs(cardGrids) do
		g.CellSize = cell
	end
	for _, f in ipairs(cardScales) do
		f.Scale = want
	end
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

		-- ---- a collection log ----------------------------------------------
		--
		-- Walks `Config.skinCollections()` rather than the payload, which is
		-- what makes this a LOG: the groups and their contents are the
		-- catalogue's, so a skin nobody owns still has a card and still leaves
		-- a hole to fill. Every other tab walks what the player HAS.
		--
		-- THE TAB'S COUNT STAYS OWNED-ONLY. It sits beside four other tabs
		-- that all count what you have, and a Skins tab reading 49 while the
		-- player owns three would be the one number on the rail meaning
		-- something different from its neighbours. The per-group "3 / 17" is
		-- where the total belongs, because there it has the denominator
		-- beside it.
		if section.collection then
			local haveAll = 0
			for gi, group in ipairs(Config.skinCollections()) do
				local g = ensureGroup(section, row, group, gi)
				local have = 0
				for _, key in ipairs(group.skins) do
					local info = source and source[key]
					if type(info) == "table" then
						local card = cards[entryKey(section.kind, key)]
						if not card then
							card = buildCard(section, key, info)
						end
						card.button.Parent = g.grid
						card.button.Visible = true
						card.button.LayoutOrder = info.order or 0
						paintCard(section, key, info)
						if info[section.owned] == true then
							have += 1
							local rec = spares[entryKey(section.kind, key)]
							spareTotal += (rec and rec.count) or 0
						end
					end
				end
				g.count.Text = ("%d / %d"):format(have, #group.skins)
				haveAll += have
			end
			tabs[section.kind].count.Text = tostring(haveAll)
			-- Never empty: a log always has its gaps to show, so the "go and
			-- get one" line that the other tabs fall back to has nothing to
			-- say here and would sit above a full grid.
			row.blank.Visible = false
			total += haveAll
			continue
		end

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

	-- AFTER the cards exist, because a card built during this render was born
	-- at whatever `cardScale` already said and a grid created in the same pass
	-- needs the cell size applying. `refit` returns immediately when the scale
	-- has not moved, so this costs one comparison on every push but the first.
	refit()

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

--[[
	Throw away every card so the next render builds them again.

	WHY THIS EXISTS: a card's 3D icon is built ONCE, on the render that first
	shows it, and only PAINTED afterwards -- a ViewportFrame is the most
	expensive thing on this screen and rebuilding forty of them per push is
	not affordable. That is right until the MODEL ITSELF changes underneath
	the cache, which is exactly what happens when the preview pig's mesh
	finishes loading a moment after the HUD came up: every card built in that
	window would keep the primitives pig for the life of the session, and
	nothing would look broken enough for anybody to report it.

	Only the client's prewarm calls this, once.
]]
function Inventory.rebuildIcons()
	for key, card in pairs(cards) do
		card.button:Destroy()
		cards[key] = nil
	end
	-- The scales go with the buttons they were parented to, so the list has
	-- to go too -- otherwise every rebuild leaves a row of destroyed
	-- instances behind that `refit` walks forever. The grids are NOT cleared:
	-- rows and groups survive a rebuild, and it is only their cards that go.
	table.clear(cardScales)
	Inventory.render()
end

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

-- THE SHOP'S MASTHEAD, rebuilt here rather than shared, because the shop's
-- lives inside `ShopRevamp`'s shell with its landing grid and back button,
-- none of which a bag has. Every piece is the same widget with the same
-- numbers -- green band, pointed gold-edged sign, coin badge -- so the two
-- panels one tap apart read as one game. There were TWO badges: the second
-- was the acorn balance and went with the currency.
local function buildChrome(view: Frame)
	local c: any = {}
	c.header = W.frame(view, "Header")
	c.header.BackgroundTransparency = 1
	c.masthead = W.frame(c.header, "Masthead", W.colours.home:Lerp(Theme.INK, 0.18))
	W.round(c.masthead, 16, false)
	c.banner = W.frame(c.masthead, "BagSign")
	c.banner.BackgroundTransparency = 1
	c.signEdge = W.frame(c.banner, "SignOutline", Theme.INK); W.round(c.signEdge, 16, false)
	c.signTipEdge = W.frame(c.banner, "PointOutline", Theme.INK); c.signTipEdge.Rotation = 45
	W.round(c.signTipEdge, 16, false)
	c.signFill = W.frame(c.banner, "SignFace", W.colours.style); W.round(c.signFill, 13, false)
	c.signTip = W.frame(c.banner, "PointFace", W.colours.style); c.signTip.Rotation = 45
	W.round(c.signTip, 13, false)
	c.title = W.text(c.banner, "BagHeading", "YOUR BAG", 42)
	c.title.TextTruncate = Enum.TextTruncate.None
	-- White with an ink line round each letter, as the shop's own sign.
	ShopStyle.popText(c.title)

	c.coinBadge = W.frame(c.masthead, "CoinBadge", Theme.PAPER); W.round(c.coinBadge, 15)
	c.coinBadge:FindFirstChildOfClass("UIStroke").Thickness = 3
	c.coinIcon = W.frame(c.coinBadge, "CoinIcon"); c.coinIcon.BackgroundTransparency = 1
	c.coinScale = Instance.new("UIScale"); c.coinScale.Parent = Theme.coin(c.coinIcon, 34, "Coin")
	c.coins = W.text(c.coinBadge, "Coins", "0", 30)
	return c
end

-- THE SHOP'S LAYOUT, on the numbers `ShopRevamp:layout` uses for a category
-- page: the same masthead height, sign width, badge sizes and sidebar width,
-- so a player moving between the two sees nothing jump. On a compact screen
-- the shop hides its sidebar and navigates from the landing grid; the bag has
-- no landing, so it keeps the sidebar and drops it to icons instead.
layout = function()
	local view = panelView
	local c = chrome
	if not view or not c then
		return
	end
	local width, height = view.AbsoluteSize.X, view.AbsoluteSize.Y
	if width <= 0 then
		return
	end
	local narrow = width < 560
	local compact = width < 950 or height < 500
	local mastH = if narrow then 100 elseif height < 420 then 54 else math.clamp(height * 0.105, 70, 98)
	c.header.Position = UDim2.fromOffset(0, 0)
	c.header.Size = UDim2.new(1, 0, 0, mastH)
	c.masthead.Size = UDim2.fromScale(1, 1)

	local close = deps.close
	local closeSize = if narrow or height < 420 then 44 else math.min(64, mastH - 12)
	if close then
		Theme.floatClose(close, closeSize)
		close.TextSize = math.floor(closeSize * 0.72)
		close.ZIndex = 4
	end

	local signH = if narrow then 54 else mastH + 6
	local signW = if narrow then width - closeSize - 18 else width * 0.43
	c.banner.Size = UDim2.fromOffset(signW, signH)
	c.banner.Position = UDim2.fromOffset(-8, -12)
	local radius, border = 16, 3
	local shoulderX = signW - signH / 2
	local bodyWidth = shoulderX + radius
	c.signEdge.Size = UDim2.fromOffset(bodyWidth, signH)
	c.signFill.Position = UDim2.fromOffset(3, 3)
	c.signFill.Size = UDim2.fromOffset(bodyWidth - 2 * border, signH - 2 * border)
	local tipSide = (signH + 2 * radius * (math.sqrt(2) - 1)) / math.sqrt(2)
	for _, spec in { { c.signTipEdge, tipSide }, { c.signTip, tipSide - 2 * border } } do
		local tip, side = spec[1], spec[2]
		tip.AnchorPoint = Vector2.new(0.5, 0.5)
		tip.Position = UDim2.fromOffset(shoulderX, signH / 2)
		tip.Size = UDim2.fromOffset(side, side)
	end
	local titleX = 24
	c.title.Position = UDim2.fromOffset(titleX, 0)
	c.title.Size = UDim2.new(1, -titleX - signH / 2, 1, 0)
	c.title.TextSize = if narrow then 30 else math.floor(mastH * 0.56)

	-- ONE BADGE, so it takes the whole width the pair used to share.
	if narrow then
		c.coinBadge.Position = UDim2.fromOffset(10, 53)
		c.coinBadge.Size = UDim2.new(1, -20, 0, 40)
	else
		local badgeW = math.floor(width * 0.54 - closeSize - 26)
		c.coinBadge.Size = UDim2.fromOffset(badgeW, mastH - 18)
		c.coinBadge.Position = UDim2.new(1, -closeSize - 20 - badgeW, 0, 9)
	end
	c.coins.TextSize = if width < 900 or height < 420 then 20 else math.floor(mastH * 0.40)
	local badgeH = c.coinBadge.AbsoluteSize.Y
	if badgeH <= 0 then badgeH = if narrow then 40 else mastH - 18 end
	local currencySize = math.min(if compact then 24 else 34, badgeH - 14)
	c.coinScale.Scale = currencySize / 34
	c.coinIcon.Size = UDim2.fromOffset(currencySize, currencySize)
	c.coinIcon.Position = UDim2.new(0, 8, 0.5, -currencySize / 2)
	local balanceX = currencySize + 16
	c.coins.Position = UDim2.fromOffset(balanceX, 0)
	c.coins.Size = UDim2.new(1, -balanceX - 8, 1, 0)

	local top = mastH + 10
	local side = if compact then 70 else 166
	local bar = rail
	if bar then
		bar.Position = UDim2.fromOffset(12, top)
		bar.Size = UDim2.new(0, side, 1, -top - 12)
	end
	for _, tab in pairs(tabs) do
		tab.label.Visible = not compact
		tab.count.Visible = not compact
		tab.icon.Position = if compact then UDim2.new(0.5, -19, 0, 5) else UDim2.fromOffset(7, 5)
	end
	local left = side + 24
	local list = scroll
	if list then
		list.Position = UDim2.fromOffset(left, top)
		list.Size = UDim2.new(1, -left - 16, 1, -top - 12)
	end
end

-- The balance, from the push that already feeds the shop's badge. The second
-- parameter is kept and ignored so existing callers do not have to change.
function Inventory.setBalances(coins: number, _acorns: number?)
	if not chrome then
		return
	end
	chrome.coins.Text = Config.formatCoins(coins)
end

function Inventory.init(view: Frame, injected: any)
	deps = injected
	-- Held for `refit` and `layout`, which run long after this returns.
	panelView = view

	chrome = buildChrome(view)

	-- THE SIDEBAR, the shop's own: a vertical scroll of category buttons down
	-- the left. Still named `InventoryRail` so a probe that knew the old one
	-- finds this. It scrolls for the reason the old rail did -- a list that
	-- does not clip keeps drawing past the edge.
	local bar = W.scroll(view, "InventoryRail")
	local barList = Instance.new("UIListLayout")
	barList.Padding = UDim.new(0, 10)
	barList.SortOrder = Enum.SortOrder.LayoutOrder
	barList.Parent = bar
	rail = bar

	local list = Instance.new("ScrollingFrame")
	list.Name = "InventoryList"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 5
	list.ScrollBarImageColor3 = Theme.MUTED
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = view

	-- A `Border` STROKE DRAWS OUTSIDE THE PART, and a ScrollingFrame clips
	-- exactly that region -- which is how the shop's first column and its
	-- first tab both lost an edge. Every card in here carries a rarity stroke,
	-- so the leftmost column and the top row need the clearance.
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = list

	local stack = Instance.new("UIListLayout")
	stack.Padding = UDim.new(0, 18)
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Parent = list

	scroll = list
	view:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		layout()
		refit()
	end)
	Inventory.render()
	layout()
	selectKind(active)
end

return Inventory
