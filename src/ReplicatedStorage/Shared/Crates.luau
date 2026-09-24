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

	THE TAB IS TWO SHELVES OF LARGE CRATES. The piggy shelf offers Common /
	Rare / Legendary over ONE pool of every piggy skin -- OG Piggy, Animal
	Kingdom and Arcade were three shelves until they merged on 2026-09-23 --
	and the Guardian Crate offers one (`Config.CRATE_SECTIONS`). The same
	tiles are mounted on the Robux page too (`Crates.mount`), so a crate is
	bought there in one tap. The card used to preview the three
	best items and draw an odds bar; the design asked for the crates alone, so
	those moved one tap deeper -- tapping a crate opens `CrateContents`, which
	shows the whole pool and prints the odds.

	THE ODDS ARE STILL THE SERVER'S OWN NUMBERS. `ChestState` carries the odds
	`ChestService.liveOdds` actually rolled with, renormalised over the tiers
	that have stock, and the contents page and the reveal both read those.
	Computing them from `Config.CHESTS[key].odds` would print a player numbers
	the server did not use, which is worse than printing none.

	AND THE ODDS BAR CAME BACK ONTO THE TILE, BECAUSE THE TILE SELLS SOMETHING
	NOW (designer, 2026-09-23). A crate is bought with Robux, which makes it a
	PAID RANDOM ITEM under Roblox's rule -- and that rule asks for real odds,
	summing to 100%, disclosed BEFORE the purchase. The card that carries the
	price is therefore the card that has to carry the odds, so the bar is drawn
	to scale on the tile and the exact percentage of the best tier is printed
	beside the crate's name. The `?` still opens the full per-tier breakdown.

	THE COMBINE ROW HAS LEFT THIS TAB. A physical combine station on the street
	took it over; `ChestService.combine` is untouched and the station calls it
	(or `ChestService.rollUp`, which takes no inputs). What was here was a row
	of chips that could only light while somebody held spares -- and no crate
	mints a spare any more, so on this tab the row was permanently 0/5, which
	is the control that does nothing when pressed and reads as broken rather
	than as locked.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local ShopStyle = require(ReplicatedStorage.Shared.ShopStyle)
local SpinWheel = require(ReplicatedStorage.Shared.SpinWheel)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Icons = require(ReplicatedStorage.Shared.ShopIcons)
-- ROBLOX'S OWN ROBUX MARK, through the module that already names it. It ships
-- with every client, so there is no upload to be moderated and no second
-- drawing of a trademark to get wrong -- and taking it from `PremiumShop`
-- rather than pasting the string is what stops two tabs printing two
-- different marks the day that asset path changes.
local PremiumShop = require(ReplicatedStorage.Shared.PremiumShop)

-- The crate art is per TIER (`Config.CHESTS[key].tier`). A crate with no tier
-- -- the Guardian Crate, and the Alien Cache until it was deleted on
-- 2026-09-23 -- has no art of its own yet, so it wears the legendary crate
-- washed toward its own colour: distinct from OG Legendary at a glance, and
-- one row in `ShopIcons` away from real art.
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
-- THE SAME CRATES, PAINTED A SECOND TIME, ON THE ROBUX PAGE (designer,
-- 2026-09-23: "from the main robux shop menu it should show the common,
-- rare, legendary crates there to be able to purchase in fewer clicks").
-- They are tiles built by `buildTile` and repainted by the same `paint`, so
-- the odds bar, the price, the policy refusal and every inert state are ONE
-- implementation shown in two places -- a second renderer of a paid random
-- item is the one duplicate where two copies disagreeing would be a
-- compliance fault rather than a cosmetic one. Keyed by chest, a list each.
local extras: { [string]: { any } } = {}
local cosmetics: any = nil
local rides: any = nil
-- WHETHER THE BUY-BACK OFFERS SHOW, AND THEY SHOW ONLY THROUGH THE DOOR
-- (designer, 2026-09-23). This shelf is reached two ways now: from the Robux
-- shop, because a crate is a Robux purchase, and through PIGGY OUTFITTERS on
-- the street -- "double exposure, no harm there". A buy-back is priced in
-- COINS (`Config.buybackCost`), and every coin price is bought at a counter,
-- so the Robux route draws the crates and nothing else. Off by default: the
-- HUD is the route that must never leak a coin price, and the door is the one
-- that opts in.
local showBuybacks = false

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
					-- `fur` IS THE GUARDIAN COAT'S, AND IT WAS THE ONE MISSING WHEN
					-- THE GUARDIAN CRATE LANDED. A coat keeps its colour in `fur`
					-- rather than `body`, so ten coats would all have fallen back to
					-- the rarity default and the pool would have read as one colour.
					tint = spec.body or spec.walls or spec.fur or spec.swatch })
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
-- strip, an odds bar, a blurb and a combine row. It is two sections now --
-- the piggy crates and the Guardian Crate (`Config.CRATE_SECTIONS`) -- and a
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
-- The odds bar and the gap under it. Sixteen is the smallest a stacked bar
-- reads at from shop distance; the crate art gives up exactly this much.
local ODDS_H, ODDS_GAP = 16, 4
-- A SEGMENT PRINTS ITS OWN PERCENTAGE ONLY WHEN IT IS THIS MUCH OF THE BAR.
--
-- Tested as a FRACTION rather than against `AbsoluteSize`, which is zero until
-- the frame has laid out and would therefore read differently on the first
-- paint than on every one after it. At a tile's ~290 inner pixels 0.18 is
-- about 52, which holds "18%" at 11px with room; below it the digits are
-- squeezed into a sliver and make the bar harder to read rather than easier.
--
-- THE THIN SLIVER IS NEVER THE ONLY PLACE A NUMBER APPEARS: the best tier's
-- exact percentage is printed beside the crate's name, and that is the one a
-- buyer is actually deciding on.
local ODDS_LABEL_AT = 0.18

local function sectionFor(collection: string?): any
	for _, def in ipairs(Config.CRATE_SECTIONS) do
		if def.key == collection then
			return sections[def.key]
		end
	end
	return nil
end

local function buildTile(parent: Instance, chestKey: string, index: number, onPeek: ((string) -> ())?): any
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
		if onPeek then onPeek(chestKey) elseif explorer then explorer:show(chestKey) end
	end)

	local peek = require(ReplicatedStorage.Shared.ShopWidgets).button(tile, "Peek", "?", Theme.PAPER, function()
		if onPeek then onPeek(chestKey) elseif explorer then explorer:show(chestKey) end
	end)
	peek.Size = UDim2.fromOffset(28, 28)
	peek.Position = UDim2.new(1, -36, 0, 8)
	peek.TextSize = 16
	ShopStyle.outline(peek, 2)

	-- THE ODDS, DRAWN TO SCALE, AND THIS IS THE DISCLOSURE THE PAID RANDOM
	-- ITEM RULE ASKS FOR RATHER THAN decoration.
	--
	-- A stacked bar is the version a nine-year-old reads without reading --
	-- THE GOLD SLIVER BEING THIN IS THE INFORMATION -- and the segments are
	-- the SERVER'S renormalised odds, so they sum to 100 by construction. The
	-- track is one step under the tile's ground, which is the same groove an
	-- unbought upgrade pip sits in.
	local oddsTrack = Instance.new("Frame")
	oddsTrack.Name = "Odds"
	oddsTrack.Size = UDim2.new(1, -16, 0, ODDS_H)
	oddsTrack.Position = UDim2.new(0, 8, 1, -(BUTTON_H + 8 + TIER_H + 2 + ODDS_H + ODDS_GAP))
	oddsTrack.BackgroundColor3 = ShopStyle.SUNK
	oddsTrack.BorderSizePixel = 0
	oddsTrack.ClipsDescendants = true
	oddsTrack.Parent = tile
	ShopStyle.round(oddsTrack, 6)
	local segments: { [string]: TextLabel } = {}
	for _, name in ipairs(TIERS) do
		local seg = Instance.new("TextLabel")
		seg.Name = "Odds_" .. name
		seg.BackgroundColor3 = tierColour(name)
		seg.BorderSizePixel = 0
		seg.Font = Enum.Font.GothamBold
		seg.TextSize = 11
		seg.TextColor3 = Theme.INK
		seg.Text = ""
		seg.Visible = false
		seg.Parent = oddsTrack
		segments[name] = seg
	end

	local word = TIER_WORD[chest.tier or ""] or string.upper(chest.name or chestKey)
	local tier = label(tile, word, UDim2.new(1, -16, 0, TIER_H),
		UDim2.new(0, 8, 1, -(BUTTON_H + 8 + TIER_H + 2)), Enum.Font.FredokaOne, 20, ShopStyle.TEXT)
	tier.Name = "Tier"
	tier.TextXAlignment = Enum.TextXAlignment.Center

	-- WHAT IT COSTS, IN THE CORNER, SO THE OFFER READS BEFORE THE BUTTON IS
	-- LOOKED AT. Hidden entirely on a crate that is earned rather than sold --
	-- a price of nothing is not a price, it is a lie about where the crate
	-- comes from.
	local priceChip = ShopStyle.chip(tile, ShopStyle.SUNK, Theme.PAPER)
	priceChip.Name = "Price"
	priceChip.Size = UDim2.new(0, 78, 0, 26)
	priceChip.Position = UDim2.new(0, 8, 0, 8)
	priceChip.Font = Enum.Font.FredokaOne
	priceChip.TextSize = 15
	priceChip.Text = ""
	priceChip.Visible = false
	local chipMark = Instance.new("ImageLabel")
	chipMark.Name = "Robux"
	chipMark.BackgroundTransparency = 1
	chipMark.Image = PremiumShop.ROBUX_ICON
	chipMark.ImageColor3 = Theme.PAPER
	chipMark.ScaleType = Enum.ScaleType.Fit
	chipMark.Size = UDim2.new(0, 16, 0, 16)
	chipMark.Position = UDim2.new(0, 7, 0, 5)
	chipMark.Parent = priceChip

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
	-- THE MARK AND THE PRICE ARE CHILDREN RATHER THAN THE BUTTON'S OWN TEXT,
	-- for the reason `PremiumShop` does the same: a Robux price is an ICON and
	-- a number, and a button whose `Text` carried both would have to draw the
	-- mark as a character nobody has measured.
	local mark = Instance.new("ImageLabel")
	mark.Name = "Robux"
	mark.BackgroundTransparency = 1
	mark.Image = PremiumShop.ROBUX_ICON
	mark.ImageColor3 = Theme.INK
	mark.ScaleType = Enum.ScaleType.Fit
	mark.Size = UDim2.new(0, 20, 0, 20)
	mark.Position = UDim2.new(0, 12, 0.5, -10)
	mark.Visible = false
	mark.Parent = open
	local price = label(open, "", UDim2.new(1, -8, 1, 0), UDim2.new(0, 4, 0, 0),
		Enum.Font.FredokaOne, 16, ShopStyle.TEXT)
	price.Name = "Label"
	price.TextXAlignment = Enum.TextXAlignment.Center
	price.TextTruncate = Enum.TextTruncate.AtEnd

	local ui = { card = tile, icon = icon, open = open, tier = tier, mark = mark,
		price = price, priceChip = priceChip, segments = segments,
		productId = nil :: number? }

	-- THE CLIENT DECLINES TO ASK FOR A KNOWN NO, which is the rule every other
	-- control in this game follows and matters more here than anywhere: a
	-- prompt for a product id of 0 THROWS, and a prompt for a player the paid
	-- random item rule restricts is the one thing that rule forbids outright.
	-- `productId` is nil in every state but the buyable one, so this button
	-- can only ever reach the prompt when the server said it could.
	open.Activated:Connect(function()
		if ui.productId then
			MarketplaceService:PromptProductPurchase(Players.LocalPlayer, ui.productId)
		end
	end)

	return ui
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

	-- THERE IS NO COMBINE ROW. It moved to a physical station on the street
	-- (2026-09-23) -- see the header. `LayoutOrder` 3 is free and the list
	-- does not mind a gap, which is the same call `Config.CHESTS` made when
	-- the dress-up crate left a hole at order 2.

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

	return { def = def, frame = frame, row = row, progress = progress, buybacks = buybacks }
end

-- ONE STATE MACHINE, AND EVERY BRANCH OF IT IS THE SERVER'S ANSWER.
--
-- Nothing here decides anything: the price, the product id, whether the
-- collection is finished, whether this player may be offered a paid random
-- item at all and the SENTENCE for any other refusal all arrive on
-- `ChestState`. A second opinion about any of them would be a card that
-- disagrees with the thing it is a card for -- and on this tab one of those
-- opinions is money.
--
-- THE BUTTON IS INERT IN EVERY STATE BUT ONE, AND SAYS WHY IN ALL OF THEM.
-- A control that does nothing when pressed reads as broken rather than as
-- locked, which is why each refusal is printed ON the button rather than left
-- to a player to infer from a grey rectangle.
local function paintOne(ui: any, chestKey: string, info: any)

	-- ---- the odds bar ----------------------------------------------------
	local odds = (info and info.odds) or {}
	local best, bestPct = nil, 0
	local at = 0
	for _, tier in ipairs(TIERS) do
		local seg = ui.segments[tier]
		local pct = odds[tier] or 0
		local share = pct / 100
		seg.Visible = share > 0
		if share > 0 then
			seg.Position = UDim2.new(at, 0, 0, 0)
			seg.Size = UDim2.new(share, 0, 1, 0)
			seg.Text = if share >= ODDS_LABEL_AT
				then (if pct < 1 then "<1%" else ("%d%%"):format(math.floor(pct + 0.5)))
				else ""
			at += share
			-- LAST WINS, and `TIERS` runs cheapest first, so this lands on the
			-- best tier the crate can actually pay rather than on the best one
			-- its table authorises -- which is the number a buyer is deciding
			-- on and the one a thin sliver would otherwise hide.
			best, bestPct = tier, pct
		end
	end

	-- ---- the name row ----------------------------------------------------
	local chest = Config.CHESTS[chestKey]
	local word = TIER_WORD[(chest and chest.tier) or ""]
		or string.upper((chest and chest.name) or chestKey)
	if latest and latest.restricted then
		-- THE POLICY REFUSAL, IN WORDS, WHICH IS THE HALF OF THAT RULE PEOPLE
		-- FORGET. "Restricted players are refused rather than meeting a button
		-- that does nothing" is the requirement; a greyed button with no
		-- sentence beside it IS a button that does nothing.
		ui.tier.Text = "CRATE BUYING IS OFF FOR THIS ACCOUNT"
		ui.tier.TextSize = 13
	elseif best then
		ui.tier.Text = ("%s  %s  %s%% %s"):format(word, DOT,
			(if bestPct < 1 then "<1" else tostring(math.floor(bestPct + 0.5))),
			string.upper(best))
		ui.tier.TextSize = 16
	else
		ui.tier.Text = word
		ui.tier.TextSize = 20
	end

	-- ---- the price chip --------------------------------------------------
	local robux = (info and info.robux) or 0
	ui.priceChip.Visible = robux > 0
	ui.priceChip.Text = if robux > 0 then ("      %d"):format(robux) else ""

	-- ---- the button ------------------------------------------------------
	local function inert(text: string, ground: Color3, ink: Color3)
		ui.productId = nil
		ui.mark.Visible = false
		ui.price.Text = text
		ui.price.Position = UDim2.new(0, 4, 0, 0)
		ui.price.Size = UDim2.new(1, -8, 1, 0)
		ui.price.TextColor3 = ink
		ui.open.BackgroundColor3 = ground
		ui.open.Active = false
		ui.open.AutoButtonColor = false
	end

	if robux <= 0 then
		-- Earned, never sold: the event cache. Naming where it comes from is
		-- the answer to the question a player opening this tab actually has.
		inert("EARN THIS CRATE", ShopStyle.DEAR, ShopStyle.MUTED)
	elseif info and info.complete then
		inert("COLLECTION COMPLETE", ShopStyle.OWNED, ShopStyle.TEXT)
	elseif latest and latest.restricted then
		inert("NOT AVAILABLE HERE", ShopStyle.DEAR, ShopStyle.MUTED)
	elseif (info and info.productId or 0) <= 0 then
		-- The developer product does not exist yet. The same wording and the
		-- same reason as a pass with no id: prompting for 0 throws, so the
		-- button declines to ask rather than failing silently.
		inert("COMING SOON", ShopStyle.DEAR, ShopStyle.MUTED)
	elseif info and info.refusal then
		-- ANY OTHER SERVER REFUSAL, IN THE SERVER'S OWN WORDS -- a full lawn
		-- is the one a player meets. Printed rather than summarised, so the
		-- card and the toast cannot disagree about why.
		inert(string.upper(info.refusal), ShopStyle.DEAR, ShopStyle.MUTED)
		ui.price.TextSize = 12
	else
		ui.productId = info.productId
		ui.mark.Visible = true
		ui.price.Text = tostring(robux)
		ui.price.Position = UDim2.new(0, 36, 0, 0)
		ui.price.Size = UDim2.new(1, -44, 1, 0)
		ui.price.TextColor3 = ShopStyle.TEXT
		ui.price.TextSize = 16
		ui.open.BackgroundColor3 = ShopStyle.BUY
		ui.open.Active = true
		ui.open.AutoButtonColor = true
	end
end

-- Every copy of one crate: the shelf's tile and any on the Robux page.
local function paint(chestKey: string, info: any)
	local ui = cards[chestKey]
	if ui then
		paintOne(ui, chestKey, info)
	end
	for _, extra in ipairs(extras[chestKey] or {}) do
		paintOne(extra, chestKey, info)
	end
end

-- Repaint a collection's progress and combine chips.
local function paintSection(ui: any)
	local chests = (latest and latest.chests) or {}
	local base = chests[ui.def.chests[1]]
	if base then
		ui.progress.Text = ("%d/%d"):format(base.owned or 0, base.total or 0)
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
		section.buybacks.Visible = any and showBuybacks
	end
end

-- ---- state ---------------------------------------------------------------

-- WHICH ROUTE OPENED THIS SHELF. `ClientMain` sets it true when the PIGGY
-- OUTFITTERS door opens the shelf, false from the Robux shop, and false when
-- the panel closes, so a stale true can never outlive the visit that set it.
-- Repaints in place: the offers are built either way and only their
-- visibility follows the route, so switching costs nothing to rebuild.
function Crates.setBuybacks(shown: boolean)
	showBuybacks = shown
	paintBuybacks()
end

-- BACK TO THE TOP OF THE SHELF, CALLED BY EVERY ROUTE THAT OPENS IT.
--
-- The contents page is a child of this view and only its own "CRATES" arrow
-- closed it, so leaving through the shop's big back arrow left it open
-- underneath -- and SEE CRATES then landed a player straight back inside the
-- crate they had walked away from, filter and scroll intact. A route in is a
-- fresh visit: the list of crates, from the top, with the page's filter back
-- on All. `paint` returns early while the page is hidden, so the filter chips
-- repaint the next time a crate is opened rather than here.
-- EVERY CRATE ON THE SHELF, AS A STRIP OF TILES SOMEWHERE ELSE -- the Robux
-- page. The chests come from `Config.CRATE_SECTIONS` in the shelf's own
-- order, so the page and the shelf cannot list different crates. No buy-back
-- row: those are coin prices and are only ever met at a counter.
--
-- Safe to call before `init`: a tile needs nothing `init` sets, and the
-- first `render` after it paints these along with the shelf.
--
-- Four across on a wide panel, two on a narrow one, one on a phone held
-- upright; the crate shrinks and the tier word and button stay full size, the
-- same trade the shelf's own rows make.
function Crates.mount(parent: Instance, onPeek: ((string) -> ())?): Frame
	local strip = Instance.new("Frame")
	strip.Name = "CrateStrip"
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.new(1, 0, 0, 0)
	strip.AutomaticSize = Enum.AutomaticSize.Y
	strip.Parent = parent
	local cells = Instance.new("UIGridLayout")
	cells.CellPadding = UDim2.fromOffset(12, 12)
	cells.SortOrder = Enum.SortOrder.LayoutOrder
	cells.Parent = strip
	local count = 0
	for _, def in ipairs(Config.CRATE_SECTIONS) do
		for _, chestKey in ipairs(def.chests) do
			if Config.CHESTS[chestKey] then
				count += 1
				local ui = buildTile(strip, chestKey, count, onPeek)
				extras[chestKey] = extras[chestKey] or {}
				table.insert(extras[chestKey], ui)
			end
		end
	end
	local function fit()
		local width = strip.AbsoluteSize.X
		local columns = if width >= 700 then math.min(4, count) elseif width >= 340 then 2 else 1
		local cellW = (width - 12 * (columns - 1)) / columns
		cells.CellSize = UDim2.new(1 / columns, -math.ceil(12 * (columns - 1) / columns), 0,
			if cellW < 200 then ROW_H_COMPACT else ROW_H)
	end
	strip:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	if latest then
		Crates.render()
	end
	return strip
end

-- Open one crate's contents page. The caller has already selected the crates
-- tab (the Robux page does it through `openRobuxCrates`, which also resets the
-- shelf), so this only has to show the page.
function Crates.peek(chestKey: string)
	if explorer and Config.CHESTS[chestKey] then
		explorer:show(chestKey)
	end
end

function Crates.reset()
	if explorer then
		explorer.filter = "All"
		explorer.list.CanvasPosition = Vector2.zero
		explorer:close()
	end
	if grid then
		grid.CanvasPosition = Vector2.zero
	end
end

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
	for key, list in pairs(extras) do
		for _, ui in ipairs(list) do
			crateIcon(ui.icon, key)
		end
	end
end

return Crates
