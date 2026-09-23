--!strict
--[[
	Crates

	The shop tab that finally reaches `ChestService`.

	FOUR HUNDRED AND TWENTY LINES OF SERVER WERE UNREACHABLE. `ChestService`
	has been complete and wired since it was written -- open, roll, grant,
	combine, sell, four remotes, five chests -- and `ClientMain` had not one
	reference to any of it. Nothing was broken; there was simply no button.
	This is the button.

	A MODULE, AND THE 200-LOCAL CEILING IS NOT A STYLE NOTE. `ClientMain` is
	one chunk at Luau's register limit, and this feature wants a dozen
	top-level names of its own. Written inline it would not have cost the
	crates tab -- it would have cost the ENTIRE HUD, because the chunk never
	compiles and nothing gets built. A function body gets its own register
	file, so the whole thing costs that chunk one local. Same reason HotBar,
	AdminPanel, Rebirth, HouseFX and SpinWheel are modules.

	THE TAB IS COLLECTIONS, AND A COLLECTION IS A ROW OF LARGE CRATES. OG Piggy
	and Animal Kingdom each offer Common / Rare / Legendary; the Alien Cache
	offers one (`Config.CRATE_SECTIONS`). The card used to preview the three
	best items and draw an odds bar; the design asked for the crates alone, so
	those moved one tap deeper -- tapping a crate opens `CrateContents`, which
	shows the whole pool and prints the odds.

	THE ODDS ARE STILL THE SERVER'S OWN NUMBERS. `ChestState` carries the odds
	`ChestService.liveOdds` actually rolled with, renormalised over the tiers
	that have stock, and the contents page and the reveal both read those.
	Computing them from `Config.CHESTS[key].odds` would print a player numbers
	the server did not use, which is worse than printing none.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local ShopStyle = require(ReplicatedStorage.Shared.ShopStyle)
local SpinWheel = require(ReplicatedStorage.Shared.SpinWheel)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Icons = require(ReplicatedStorage.Shared.ShopIcons)

-- The crate art is per TIER (`Config.CHESTS[key].tier`). A crate with no tier
-- -- the Alien Cache -- has no art of its own yet, so it wears the legendary
-- crate washed toward its own colour: distinct from OG Legendary at a glance,
-- and one row in `ShopIcons` away from real art.
local function crateIcon(holder: GuiObject, chestKey: string)
	local chest = Config.CHESTS[chestKey]
	local tier = chest and chest.tier
	local image = Icons.mount(holder, "crate-" .. (tier or "legendary"))
	if image and chest and not tier and chest.colour then
		image.ImageColor3 = Color3.new(1, 1, 1):Lerp(chest.colour, 0.55)
	end
	return image
end

local Crates = {}

-- THE LADDER, FROM CONFIG RATHER THAN A SECOND COPY OF IT. This was a
-- literal `{ "common", "rare", "epic", "legendary" }` here, which is exactly
-- what `Config.RARITY_ORDER` was extracted to stop -- and it went stale the
-- moment skins dropped to three tiers, because a chip is built per entry and
-- every crate grew an EPIC row that could never fill.
local TIERS = Config.RARITY_ORDER
local DOT = utf8.char(0x00B7)

-- A buy-back card's height; the crate tiles size themselves (see ROW_H).
local CARD_H = 300

-- SHARED STATE ABOVE ITS READERS. A `local` declared after a function that
-- reads it silently becomes a nil GLOBAL in Luau -- it does not error, it dies
-- at the call naming nothing useful. This project has hit that seven times.
local deps: any = nil
local grid: ScrollingFrame? = nil
local cards: { [string]: any } = {}
local buybackCards: { [string]: any } = {}
local latest: any = nil
local coins = 0
local explorer: any = nil
local cosmetics: any = nil
local rides: any = nil

local function tierColour(tier: string): Color3
	local r = Config.RARITIES[tier]
	return if r then r.colour else Theme.MUTED
end

-- Every item a chest can give, best tier first.
--
-- BEST FIRST IS THE ADVERTISING AND IT IS ALSO HONEST. A crate is opened for
-- the thing at the top of it, so leading with three commons describes the
-- likely outcome and sells nothing; leading with the legendaries says what
-- the chest is FOR. Nothing here claims they are likely -- the odds bar
-- directly underneath is drawn to scale and says the opposite.
local function stockOf(chestKey: string): { { kind: string, key: string, name: string, tier: string, tint: Color3? } }
	local pool = Config.chestPool(chestKey)
	local out = {}
	for i = #TIERS, 1, -1 do
		local tier = TIERS[i]
		for _, entry in ipairs(pool[tier] or {}) do
			local kind, key = Config.chestEntry(chestKey, entry)
			local catalogue = Config.catalogueFor(kind)
			local spec = catalogue and catalogue[key]
			if spec then
				-- THE ITEM'S OWN COLOUR, carried out of the catalogue by the one
				-- function that already reads it. The contents grid used to tint
				-- every tile by RARITY, which over a pool of thirty says the same
				-- thing thirty times -- and it was saying it twice, since the
				-- tier is also printed on the tile. Tinted by the skin it is
				-- showing, the grid reads as a shelf of pigs, and the rarity
				-- moves to the tile's EDGE, which is the vocabulary the shop
				-- card and the bag card already use for exactly this.
				--
				-- `body` is a skin, `walls` a house, `swatch` the rest: the same
				-- fallback chain the shop card's own icon well picks from, rather
				-- than a second opinion about where an item keeps its colour.
				table.insert(out, { kind = kind, key = key, name = spec.name or key, tier = tier,
					tint = spec.body or spec.walls or spec.swatch })
			end
		end
	end
	return out
end

local function label(parent: Instance, text: string, size: UDim2, pos: UDim2,
	font: Enum.Font, textSize: number, colour: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = size
	l.Position = pos
	l.Font = font
	l.TextSize = textSize
	l.TextColor3 = colour
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Text = text
	l.Parent = parent
	return l
end

-- ONE CARD PER COLLECTION, AND INSIDE IT ONE LARGE CRATE PER TIER.
--
-- The tab used to be a grid of per-crate cards, each carrying a preview
-- strip, an odds bar, a blurb and a combine row. It is three sections now --
-- OG Piggy, Animal Kingdom, Alien Cache (`Config.CRATE_SECTIONS`) -- and a
-- crate is shown as what it is: a big crate, its tier, and the button that
-- opens it. The odds and the full pool did not go anywhere: tapping a crate
-- (or its ?) opens the contents page, which prints the server's own odds.
--
-- BUILT ONCE FROM CONFIG, REPAINTED FROM STATE. The shape of the tab is a
-- function of `CRATE_SECTIONS` alone, so nothing rebuilds when a balance
-- arrives -- every update is a property write on something that exists.
local sections: { [string]: any } = {}
local TIER_WORD = { common = "COMMON", rare = "RARE", epic = "EPIC", legendary = "LEGENDARY" }
local ROW_H, ROW_H_COMPACT = 250, 186
local TIER_H, BUTTON_H = 26, 40

local function sectionFor(collection: string?): any
	for _, def in ipairs(Config.CRATE_SECTIONS) do
		if def.key == collection then
			return sections[def.key]
		end
	end
	return nil
end

local function buildTile(parent: Instance, chestKey: string, index: number): any
	local chest = Config.CHESTS[chestKey]
	local hue = if chest.tier then tierColour(chest.tier) else (chest.colour or Theme.HUE.crates)

	local tile = Instance.new("Frame")
	tile.Name = "Crate_" .. chestKey
	tile.LayoutOrder = index
	-- A third of the row less its share of the two 12px gaps, so three tiles
	-- fill the row exactly and a section with one (the Alien Cache) keeps the
	-- same size rather than stretching into a banner.
	tile.Size = UDim2.new(1 / 3, -8, 1, 0)
	tile.BackgroundColor3 = hue:Lerp(Theme.PAPER, 0.78)
	tile.BorderSizePixel = 0
	tile.Parent = parent
	ShopStyle.round(tile, 14)
	ShopStyle.outline(tile, if chest.tier == "legendary" then 5 else 3, hue)
	ShopStyle.gloss(tile)

	-- THE CRATE IS THE BUTTON THAT SHOWS WHAT IS INSIDE. Big enough to be the
	-- whole card, which is what "a crate" means to somebody choosing one.
	local icon = Instance.new("ImageButton")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Image = ""
	icon.Size = UDim2.new(1, -16, 1, -(TIER_H + BUTTON_H + 24))
	icon.Position = UDim2.new(0, 8, 0, 8)
	icon.Parent = tile
	crateIcon(icon, chestKey)
	icon.Activated:Connect(function()
		if explorer then explorer:show(chestKey) end
	end)

	local peek = require(ReplicatedStorage.Shared.ShopWidgets).button(tile, "Peek", "?", Theme.PAPER, function()
		if explorer then explorer:show(chestKey) end
	end)
	peek.Size = UDim2.fromOffset(28, 28)
	peek.Position = UDim2.new(1, -36, 0, 8)
	peek.TextSize = 16
	ShopStyle.outline(peek, 2)

	local word = TIER_WORD[chest.tier or ""] or string.upper(chest.name or chestKey)
	local tier = label(tile, word, UDim2.new(1, -16, 0, TIER_H),
		UDim2.new(0, 8, 1, -(BUTTON_H + 8 + TIER_H + 2)), Enum.Font.FredokaOne, 20, ShopStyle.TEXT)
	tier.Name = "Tier"
	tier.TextXAlignment = Enum.TextXAlignment.Center

	local open = Instance.new("TextButton")
	open.Name = "Open"
	open.Size = UDim2.new(1, -16, 0, BUTTON_H)
	open.Position = UDim2.new(0, 8, 1, -(BUTTON_H + 8))
	open.BackgroundColor3 = ShopStyle.BUY
	open.BorderSizePixel = 0
	open.AutoButtonColor = true
	open.Font = Enum.Font.FredokaOne
	open.TextSize = 16
	open.TextColor3 = ShopStyle.TEXT
	open.Text = ""
	open.Parent = tile
	ShopStyle.round(open, 12)
	ShopStyle.outline(open, 3)
	ShopStyle.gloss(open)
	-- NO HANDLER. This label used to be the BUY BUTTON; a crate is earned
	-- rather than bought, so it names where the crate comes from and does
	-- nothing when pressed -- deliberately inert rather than removed, because
	-- the tile's layout is measured around it and "how do I get one" is the
	-- question a player opening this tab actually has.
	open.Active = false
	open.AutoButtonColor = false

	return { card = tile, icon = icon, open = open, tier = tier }
end

local function buildSection(def: any, order: number): any
	local base = Config.CHESTS[def.chests[1]]
	local hue = (base and base.colour) or Theme.HUE.crates

	local frame = Instance.new("Frame")
	frame.Name = "Section_" .. def.key
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, 0, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = ShopStyle.CARD
	frame.BorderSizePixel = 0
	frame.Parent = grid
	ShopStyle.round(frame, 16)
	-- The collection's own colour is the edge; the tiers inside wear theirs.
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

	local head = Instance.new("Frame")
	head.Name = "Header"
	head.LayoutOrder = 1
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(1, 0, 0, 30)
	head.Parent = frame
	local title = label(head, def.name, UDim2.new(1, -100, 1, 0), UDim2.new(), Enum.Font.FredokaOne, 24, ShopStyle.TEXT)
	title.Name = "Title"
	-- Owned of total across the collection, the one number that says "keep going".
	local progress = ShopStyle.chip(head, ShopStyle.deepen(hue, 0.5), Theme.PAPER)
	progress.Name = "Progress"
	progress.Size = UDim2.new(0, 84, 0, 26)
	progress.Position = UDim2.new(1, -84, 0, 2)

	local row = Instance.new("Frame")
	row.Name = "Crates"
	row.LayoutOrder = 2
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, ROW_H)
	row.Parent = frame
	local rowList = Instance.new("UIListLayout")
	rowList.FillDirection = Enum.FillDirection.Horizontal
	rowList.Padding = UDim.new(0, 12)
	rowList.SortOrder = Enum.SortOrder.LayoutOrder
	rowList.Parent = row
	for i, chestKey in ipairs(def.chests) do
		if Config.CHESTS[chestKey] then
			cards[chestKey] = buildTile(row, chestKey, i)
		end
	end

	-- ---- combining spares ------------------------------------------------
	--
	-- One slim row per collection, landing in its COMMON crate's pool: five
	-- commons buy a rare roll from this shelf, and so on up. The counts are
	-- the server's and global per tier, so the same fuel shows on every
	-- section -- the section is where the roll lands. A chip only exists for
	-- a tier this shelf can climb OUT of; the top stocked tier is what the
	-- rest combine up to, and a chip that can never light is worse than none.
	local combineRow = Instance.new("Frame")
	combineRow.Name = "Combine"
	combineRow.LayoutOrder = 3
	combineRow.BackgroundTransparency = 1
	combineRow.Size = UDim2.new(1, 0, 0, 30)
	combineRow.Visible = Config.canCombineChest(def.chests[1])
	combineRow.Parent = frame
	local combineList = Instance.new("UIListLayout")
	combineList.FillDirection = Enum.FillDirection.Horizontal
	combineList.Padding = UDim.new(0, 8)
	combineList.VerticalAlignment = Enum.VerticalAlignment.Center
	combineList.SortOrder = Enum.SortOrder.LayoutOrder
	combineList.Parent = combineRow
	local cap = label(combineRow, "COMBINE SPARES", UDim2.new(0, 124, 1, 0), UDim2.new(),
		Enum.Font.GothamBold, 12, ShopStyle.MUTED)
	cap.LayoutOrder = 0

	local pool = Config.chestPool(def.chests[1])
	local climbable = {}
	for _, tier in ipairs(TIERS) do
		if pool[tier] and #pool[tier] > 0 then
			table.insert(climbable, tier)
		end
	end
	if #climbable > 0 then
		table.remove(climbable)
	end
	local combines: { [string]: TextButton } = {}
	local ready: { [string]: boolean } = {}
	for i, tier in ipairs(climbable) do
		local chip = Instance.new("TextButton")
		chip.Name = "Combine_" .. tier
		chip.LayoutOrder = i
		chip.Size = UDim2.new(0, 110, 1, -2)
		chip.BackgroundColor3 = ShopStyle.SUNK
		chip.BorderSizePixel = 0
		chip.AutoButtonColor = false
		chip.Font = Enum.Font.GothamBold
		chip.TextSize = 12
		chip.TextColor3 = ShopStyle.MUTED
		chip.Text = ""
		chip.Parent = combineRow
		ShopStyle.round(chip, 8)
		ShopStyle.outline(chip, 2, tierColour(tier))
		-- The client declines to ask for a known no; the server re-counts,
		-- re-picks and refuses out loud regardless.
		chip.Activated:Connect(function()
			if ready[tier] and deps.combine then
				deps.combine(tier, def.chests[1])
			end
		end)
		combines[tier] = chip
	end

	-- Buy-back offers for this collection's skins sit inside it.
	local buybacks = Instance.new("Frame")
	buybacks.Name = "BuyBacks"
	buybacks.LayoutOrder = 4
	buybacks.BackgroundTransparency = 1
	buybacks.Size = UDim2.new(1, 0, 0, 0)
	buybacks.AutomaticSize = Enum.AutomaticSize.Y
	buybacks.Visible = false
	buybacks.Parent = frame
	local cells = Instance.new("UIGridLayout")
	cells.CellSize = UDim2.new(1 / 3, -8, 0, CARD_H)
	cells.CellPadding = UDim2.new(0, 12, 0, 12)
	cells.SortOrder = Enum.SortOrder.LayoutOrder
	cells.Parent = buybacks

	return { def = def, frame = frame, row = row, progress = progress,
		combines = combines, combineRow = combineRow, ready = ready, buybacks = buybacks }
end

-- Repaint one crate tile from the server's own numbers.
local function paint(chestKey: string, info: any)
	local ui = cards[chestKey]
	if not ui then
		return
	end
	-- WHERE A CRATE COMES FROM, not what it costs. Nothing here is priced.
	ui.open.Text = "EARN THIS CRATE"
	ui.open.BackgroundColor3 = ShopStyle.DEAR
	ui.open.TextColor3 = ShopStyle.MUTED
end

-- Repaint a collection's progress and combine chips.
local function paintSection(ui: any)
	local chests = (latest and latest.chests) or {}
	local base = chests[ui.def.chests[1]]
	if base then
		ui.progress.Text = ("%d/%d"):format(base.owned or 0, base.total or 0)
	end
	local perTier = (latest and latest.perTier) or {}
	local need = (latest and latest.need) or Config.COMBINE.need
	local canCombine = base ~= nil and base.canCombine == true
	-- HIDDEN UNTIL THE PLAYER ACTUALLY HOLDS A SPARE, which is new and is a
	-- consequence of piggies no longer making them (2026-09-21; see
	-- `ChestService.handOver`).
	--
	-- It used to be enough that the CHEST could be combined into and had
	-- stocked tiers to draw chips for. That was fine while every crate in the
	-- game rained spares: the row was always live for somebody. Now a repeat
	-- skin is placed on a pedestal instead, and six of the seven crates are
	-- skins only -- so on those the row would be permanently visible and
	-- permanently 0/5, which is the control that does nothing when pressed
	-- and reads as broken rather than as locked.
	--
	-- NOT the same as hiding it on skins-only crates, which was the tempting
	-- version and throws away a real path: `sparesAt` pools by TIER across
	-- kinds, so a spare ride out of the Alien Cache can still be combined into
	-- an OG crate. Asking whether there is anything to combine keeps that and
	-- costs nothing.
	local holdsAny = false
	for tier in pairs(ui.combines) do
		if (perTier[tier] or 0) > 0 then
			holdsAny = true
			break
		end
	end
	ui.combineRow.Visible = canCombine and next(ui.combines) ~= nil and holdsAny
	for tier, chip in pairs(ui.combines) do
		local have = perTier[tier] or 0
		local ready = canCombine and have >= need
		ui.ready[tier] = ready
		chip.Text = ("%s %d/%d"):format(tier:sub(1, 4):upper(), math.min(have, need), need)
		chip.BackgroundColor3 = if ready then tierColour(tier) else ShopStyle.SUNK
		chip.TextColor3 = if ready then Theme.INK else ShopStyle.MUTED
	end
end

-- ---- the reveal ---------------------------------------------------------
--
-- The reel is SpinWheel's, not a second one. See the header there: an event
-- drop and a chest differ underneath and are the same object on screen, and
-- the three fields that let one serve both are `title`, `subtitle` and `note`.
function Crates.reveal(payload: any)
	if not deps or not deps.gui or type(payload) ~= "table" then
		return
	end
	local chestKey = payload.chest
	local chest = Config.CHESTS[chestKey]
	if not chest then
		return
	end

	local stock = stockOf(chestKey)
	if #stock == 0 then
		return
	end

	local catalogue = Config.catalogueFor(payload.kind)
	local spec = catalogue and catalogue[payload.key]

	-- The winner is looked up in the pool rather than built separately, so the
	-- tile under the pointer is the same shape as every tile beside it.
	local won = nil
	for _, entry in ipairs(stock) do
		if entry.kind == payload.kind and entry.key == payload.key then
			won = entry
			break
		end
	end
	won = won or { kind = payload.kind, key = payload.key,
		name = (spec and spec.name) or payload.key }

	-- The odds line, from the odds the SERVER rolled with. A combine sends no
	-- odds table -- it is not a chest roll -- so it says what it actually was.
	local subtitle
	if payload.combined then
		subtitle = ("Combined %s climbed %d tier%s"):format(
			DOT, payload.climb or 1, if (payload.climb or 1) == 1 then "" else "s")
	else
		local parts = {}
		for _, tier in ipairs(TIERS) do
			local pct = (payload.odds or {})[tier]
			if pct and pct > 0 then
				table.insert(parts, ("%d%% %s"):format(math.floor(pct + 0.5), tier))
			end
		end
		subtitle = table.concat(parts, "  " .. DOT .. "  ")
	end

	local note = nil
	if payload.duplicate then
		note = ("Spare %s sells for %s"):format(DOT, deps.format(payload.value or 0))
	end

	-- THE TIER GOES THROUGH RATHER THAN ONLY ITS COLOUR, and that is what
	-- buys the whole celebration. `SpinWheel` scales its rays, its confetti,
	-- its flash, its sting's pitch and how long it holds off the tier, and
	-- prints the tier's own name on a chip -- so a legendary and a common are
	-- visibly different events rather than the same animation in a different
	-- accent. Sent as the KEY: the colour is one thing derived from a tier and
	-- there are now six.
	--
	-- It is the SERVER'S tier and deliberately not the winner's own catalogue
	-- rarity, which is the same number today and is not the same question. A
	-- combine climbs tiers, so what a player should be congratulated on is
	-- what the roll landed on.
	SpinWheel.play(deps.gui, {
		pool = stock,
		won = won,
		title = string.upper(chest.name or "CRATE"),
		subtitle = subtitle,
		note = note,
		tier = payload.tier,
		tone = tierColour(payload.tier or "common"),
	}, deps.iconFor)
end

-- Claimed skins sit beside their source crate, with an exact-item preview.
-- They use separate cards so several claims never squeeze the crate controls.
local function buildBuybackCard(key: string, info: any): any
	local card = Instance.new("Frame")
	card.Name = "Buyback_" .. key
	card.BackgroundColor3 = ShopStyle.CARD
	card.BorderSizePixel = 0
	local home = sectionFor(info.chest) or sections[Config.CRATE_SECTIONS[1].key]
	card.Parent = home.buybacks
	ShopStyle.round(card, 14)
	ShopStyle.outline(card, 3, tierColour(info.tier))
	local name = label(card, info.name, UDim2.new(1, -24, 0, 26),
		UDim2.fromOffset(12, 10), Enum.Font.FredokaOne, 19, ShopStyle.TEXT)
	name.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 12
	limit.MaxTextSize = 19
	limit.Parent = name
	local well = Instance.new("Frame")
	well.Name = "SkinPreview"
	well.Size = UDim2.new(1, -24, 0, 110)
	well.Position = UDim2.fromOffset(12, 42)
	well.BackgroundColor3 = ShopStyle.SUNK
	well.BorderSizePixel = 0
	well.ClipsDescendants = true
	well.Parent = card
	ShopStyle.round(well, 10)
	if deps.iconFor then deps.iconFor("skin", key, well) end
	local source = Config.CHESTS[info.chest]
	label(card, source.name, UDim2.new(1, -24, 0, 20),
		UDim2.fromOffset(12, 160), Enum.Font.GothamBold, 12, ShopStyle.TEXT)
	local hint = label(card, "", UDim2.new(1, -24, 0, 46),
		UDim2.fromOffset(12, 184), Enum.Font.Gotham, 12, ShopStyle.MUTED)
	hint.TextWrapped = true
	local buy = Instance.new("TextButton")
	buy.Name = "BuyBack"
	buy.Size = UDim2.new(1, -24, 0, 44)
	buy.Position = UDim2.new(0, 12, 1, -56)
	buy.BorderSizePixel = 0
	buy.Font = Enum.Font.FredokaOne
	buy.TextSize = 15
	buy.TextWrapped = true
	buy.AutoButtonColor = true
	buy.Parent = card
	ShopStyle.round(buy, 12)
	ShopStyle.outline(buy, 3)
	buy.Activated:Connect(function()
		-- A stale card cannot request past its advertised season boundary.
		if latest and (latest.buybacksExpireAt or 0) > workspace:GetServerTimeNow()
			and latest.buybacks and latest.buybacks[key] and deps.buyback then
			deps.buyback(key)
		end
	end)
	require(ReplicatedStorage.Shared.ShopCatalogueLayout).bindCard(card,CARD_H)
	return { card = card, buy = buy, hint = hint }
end

local function paintBuybacks()
	local offered = if latest and (latest.buybacksExpireAt or 0) > workspace:GetServerTimeNow()
		then (latest.buybacks or {}) else {}
	for key, ui in pairs(buybackCards) do
		if not offered[key] then ui.card:Destroy();buybackCards[key] = nil end
	end
	for key, info in pairs(offered) do
		if Config.SKINS[key] and Config.CHESTS[info.chest] then
			local ui = buybackCards[key]
			if not ui then
				ui = buildBuybackCard(key, info)
				buybackCards[key] = ui
			end
			ui.card.LayoutOrder = (info.order or 0) + 1
			-- IN COINS. The buy-back is one NAMED skin, so a price on it is an
			-- ordinary purchase rather than anything random.
			local held = math.floor(coins)
			local affordable = held >= info.cost
			ui.buy.Text = ("BUY BACK  %s"):format(deps.format(info.cost))
			ui.buy.BackgroundColor3 = if affordable then ShopStyle.BUY else ShopStyle.DEAR
			ui.buy.TextColor3 = if affordable then ShopStyle.TEXT else ShopStyle.MUTED
			ui.hint.Text = if affordable then "This season only. Get this exact skin back."
				else ("Need %s more coins."):format(deps.format(info.cost - held))
		end
	end
	-- A collection's buy-back row shows only while it holds a card, counted
	-- from our own table rather than by asking the instance tree.
	for _, section in pairs(sections) do
		local any = false
		for _, ui in pairs(buybackCards) do
			if ui.card.Parent == section.buybacks then any = true break end
		end
		section.buybacks.Visible = any
	end
end

-- ---- state ---------------------------------------------------------------

function Crates.render(state: any?)
	if state then
		latest = state
	end
	if not latest or not grid then
		return
	end
	for chestKey, info in pairs(latest.chests or {}) do
		if Config.CHESTS[chestKey] then
			paint(chestKey, info)
		end
	end
	for _, section in pairs(sections) do
		paintSection(section)
	end
	paintBuybacks()
	if explorer then explorer:update(latest, 0, cosmetics, rides) end
end

-- Opened from the recovery objective. Wait for the newly visible grid to
-- lay out before scrolling, and re-read positions while it settles.
function Crates.focusBuyback(key: string)
	if explorer then explorer:close() end
	task.spawn(function()
		for _ = 1, 8 do
			RunService.RenderStepped:Wait()
			local ui = buybackCards[key]
			if not grid or not ui or not latest or not latest.buybacks or not latest.buybacks[key]
				or latest.buybacksExpireAt <= workspace:GetServerTimeNow() then return end
			local top = ui.card.AbsolutePosition.Y - grid.AbsolutePosition.Y + grid.CanvasPosition.Y - 4
			local limit = math.max(0, grid.AbsoluteCanvasSize.Y - grid.AbsoluteWindowSize.Y)
			grid.CanvasPosition = Vector2.new(0, math.clamp(top, 0, limit))
		end
	end)
end

-- THE BALANCE ARRIVES SEPARATELY, because it always did.
--
-- NO CRATE HAS A PRICE, so the only thing on this tab a balance still decides
-- is whether a BUY-BACK is affordable -- and that is coins now, where it used
-- to be the earned acorn balance this function was written for. The second
-- parameter is kept so existing callers do not have to change.
function Crates.setBalance(newCoins: number?, _newLoot: number?)
	local changed = false
	if type(newCoins) == "number" and newCoins ~= coins then
		coins = newCoins
		changed = true
	end
	if changed then
		Crates.render()
	end
end

function Crates.init(view: Frame, injected: any)
	deps = injected

	-- A HEADER, BECAUSE THIS TAB IS THE ONE THAT NEEDS A SENTENCE. Every other
	-- tab sells a thing you can see; this one sells a chance, and the two
	-- facts that make that fair -- the odds are real, and a repeat is not a
	-- loss -- are exactly what a nine-year-old cannot infer from a grid.
	-- ONE LINE, AT A SIZE THAT READS. There used to be a second, 12px grey
	-- line under this one, which at shop distance was a smudge; the fact it
	-- carried (a repeat comes back as a spare) is said again inside a crate.
	label(view, "Tap a crate to see what is inside and your real chances.",
		UDim2.new(1, -8, 0, 28), UDim2.new(0, 4, 0, 0), Enum.Font.FredokaOne, 20,
		ShopStyle.TEXT)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "CrateGrid"
	scroll.Size = UDim2.new(1, 0, 1, -34)
	scroll.Position = UDim2.new(0, 0, 0, 34)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = view
	grid = scroll

	-- A `Border` stroke draws OUTSIDE its frame, into the region a
	-- ScrollingFrame clips -- which is what once cut the left edge off the
	-- first column of every cosmetic card. The cards cannot be moved, because
	-- the layout owns their position, so the clearance goes on the scroll.
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 4)
	pad.PaddingTop = UDim.new(0, 4)
	pad.Parent = scroll

	local stack = Instance.new("UIListLayout")
	stack.Padding = UDim.new(0, 14)
	stack.SortOrder = Enum.SortOrder.LayoutOrder
	stack.Parent = scroll
	for i, def in ipairs(Config.CRATE_SECTIONS) do
		sections[def.key] = buildSection(def, i)
	end
	-- A phone held sideways gets shorter rows rather than a second layout:
	-- the crate shrinks, the tier word and the button stay full size.
	local function fit()
		local compact = scroll.AbsoluteSize.X < 740 or scroll.AbsoluteSize.Y < 430
		for _, section in pairs(sections) do
			section.row.Size = UDim2.new(1, 0, 0, if compact then ROW_H_COMPACT else ROW_H)
		end
	end
	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	explorer = require(ReplicatedStorage.Shared.CrateContents).new(view, {
		stockOf = stockOf, iconFor = deps.iconFor,
		-- Tier artwork is shared by the card and its collection summary.
		crateIcon = crateIcon,
		showList = function(visible: boolean)
			for _, child in ipairs(view:GetChildren()) do
				if child:IsA("GuiObject") and child.Name ~= "CrateContents" then child.Visible = visible end
			end
		end,
	})
	view:GetPropertyChangedSignal("Visible"):Connect(function()
		if view.Visible then explorer:loadVisible() end
	end)

	-- Expire visible offers locally at the boundary; the server independently
	-- rechecks every request and clears saved claims during its rollover pass.
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 then return end
		elapsed = 0
		if latest and next(buybackCards) and (latest.buybacksExpireAt or 0) <= workspace:GetServerTimeNow() then
			paintBuybacks()
		end
	end)
	Crates.render()
end

function Crates.setCosmetics(snapshot: any)
	cosmetics = snapshot
	if explorer then explorer:update(latest, 0, cosmetics, rides) end
end

function Crates.setRides(snapshot: any)
	rides = snapshot
	if explorer then explorer:update(latest, 0, cosmetics, rides) end
end

function Crates.rebuildIcons()
	if explorer then explorer:rebuildIcons() end
	for key, ui in pairs(cards) do
		crateIcon(ui.icon, key)
	end
end

return Crates
