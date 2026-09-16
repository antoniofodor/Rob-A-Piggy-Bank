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

	THE CARD SHOWS WHAT IS INSIDE, WHICH IS THE ONLY THING A PLAYER WANTS TO
	KNOW. The first instinct is a crate icon per chest, and this project has
	already learned exactly where that ends: the four shops on the street were
	"four identical boxes" with a different accent colour, and the shop's own
	cards were "nineteen identical grey squares" until they rendered the real
	item. A crate is a container, so its card is the three best things in it,
	built by the same builders the rest of the shop uses.

	THE ODDS ARE ON THE CARD, DRAWN RATHER THAN WRITTEN. Crates cost earned
	Acorns. The stacked bar shows the server's actual odds before opening;
	the gold sliver being thin is information a child can read at a glance.

	AND THEY ARE THE SERVER'S OWN NUMBERS. `ChestState` carries the odds
	`ChestService.liveOdds` actually rolled with, renormalised over the tiers
	that have stock. Computing them here from `Config.CHESTS[key].odds` would
	print a player numbers the server did not use, which is the one way a
	drawn probability can be worse than no probability at all.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local ShopStyle = require(ReplicatedStorage.Shared.ShopStyle)
local SpinWheel = require(ReplicatedStorage.Shared.SpinWheel)
local Theme = require(ReplicatedStorage.Shared.Theme)

local Crates = {}

-- THE LADDER, FROM CONFIG RATHER THAN A SECOND COPY OF IT. This was a
-- literal `{ "common", "rare", "epic", "legendary" }` here, which is exactly
-- what `Config.RARITY_ORDER` was extracted to stop -- and it went stale the
-- moment skins dropped to three tiers, because a chip is built per entry and
-- every crate grew an EPIC row that could never fill.
local TIERS = Config.RARITY_ORDER
local DOT = utf8.char(0x00B7)

-- Card geometry. Three across the 1020-wide content area at the panel's cap,
-- which is what the scale cell below works out to.
-- 246 UNTIL THE COMBINE ROW, AND THE OLD NUMBER IS WHY IT HAD TO GROW.
-- The card was packed: name at 10, the stock strip at 42, the odds bar
-- under it, the blurb under that, and OPEN pinned 50 from the bottom --
-- which left exactly TWELVE pixels of free band between the blurb and the
-- button. A 34-pixel row does not fit in 12, so the card grew rather than
-- the row being squeezed into a space that would have clipped it.
-- Two blurb lines fit the Acorn shortfall and earning hint above combining.
local CARD_H = 298
local COMBINE_H = 26
local WELL_H = 86
local BAR_H = 20

-- SHARED STATE ABOVE ITS READERS. A `local` declared after a function that
-- reads it silently becomes a nil GLOBAL in Luau -- it does not error, it dies
-- at the call naming nothing useful. This project has hit that seven times.
local deps: any = nil
local grid: ScrollingFrame? = nil
local cards: { [string]: any } = {}
local buybackCards: { [string]: any } = {}
local latest: any = nil
local loot = 0

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
local function stockOf(chestKey: string): { { kind: string, key: string, name: string, tier: string } }
	local pool = Config.chestPool(chestKey)
	local out = {}
	for i = #TIERS, 1, -1 do
		local tier = TIERS[i]
		for _, entry in ipairs(pool[tier] or {}) do
			local kind, key = Config.chestEntry(chestKey, entry)
			local catalogue = Config.catalogueFor(kind)
			local spec = catalogue and catalogue[key]
			if spec then
				table.insert(out, { kind = kind, key = key, name = spec.name or key, tier = tier })
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

-- ONE CARD PER CHEST, BUILT ONCE AND REPAINTED FOREVER.
--
-- Balance updates arrive frequently while a player is earning. Rebuilding
-- the card on every update would rebuild three ViewportFrames per chest. Everything below the previews is a property write on an instance that
-- already exists. Same rule the upgrade ladder follows: rebuild only when the
-- SHAPE changes, which for a chest is never.
local function buildCard(chestKey: string, info: any): any
	local chest = Config.CHESTS[chestKey]
	local hue = chest.colour or Theme.HUE.crates

	local card = Instance.new("Frame")
	card.Name = "Crate_" .. chestKey
	card.BackgroundColor3 = ShopStyle.CARD
	card.BorderSizePixel = 0
	card.LayoutOrder = (chest.order or 50) * 1000
	card.Parent = grid
	ShopStyle.round(card, 14)
	-- The chest's OWN colour is the edge, which is what makes five cards read
	-- as five different things rather than as one card five times. The tab's
	-- hue belongs to the tab; a card's belongs to what is in it.
	ShopStyle.outline(card, 3, hue)
	ShopStyle.gloss(card)

	local name = label(card, chest.name or chestKey, UDim2.new(1, -104, 0, 26),
		UDim2.new(0, 12, 0, 10), Enum.Font.FredokaOne, 19, ShopStyle.TEXT)
	name.TextScaled = true
	local nameSize = Instance.new("UITextSizeConstraint")
	nameSize.MinTextSize = 12
	nameSize.MaxTextSize = 19
	nameSize.Parent = name

	-- Owned of total, which is the one number that says "keep going".
	local progress = ShopStyle.chip(card, ShopStyle.deepen(hue, 0.5), Theme.PAPER)
	progress.Name = "Progress"
	progress.Size = UDim2.new(0, 78, 0, 24)
	progress.Position = UDim2.new(1, -90, 0, 11)

	-- ---- what is inside ------------------------------------------------
	local strip = Instance.new("Frame")
	strip.Name = "Stock"
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.new(1, -24, 0, WELL_H)
	strip.Position = UDim2.new(0, 12, 0, 42)
	strip.Parent = card

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = strip

	local stock = stockOf(chestKey)
	for i = 1, 3 do
		local entry = stock[i]
		local well = Instance.new("Frame")
		well.Name = "Well" .. i
		well.LayoutOrder = i
		-- A third of the strip less the two 8px gaps between three of them.
		well.Size = UDim2.new(1 / 3, -16 / 3, 1, 0)
		well.BackgroundColor3 = ShopStyle.SUNK
		well.BorderSizePixel = 0
		well.ClipsDescendants = true
		well.Parent = strip
		ShopStyle.round(well, 10)
		-- The RARITY is the well's edge, so the strip reads as a ladder even
		-- before anybody looks at what is standing in it.
		ShopStyle.outline(well, 2, if entry then tierColour(entry.tier) else ShopStyle.SUNK)
		if entry and deps.iconFor then
			deps.iconFor(entry.kind, entry.key, well)
		end
	end

	-- ---- the odds, to scale ---------------------------------------------
	local bar = Instance.new("Frame")
	bar.Name = "Odds"
	bar.BackgroundColor3 = ShopStyle.SUNK
	bar.BorderSizePixel = 0
	bar.Size = UDim2.new(1, -24, 0, BAR_H)
	bar.Position = UDim2.new(0, 12, 0, 42 + WELL_H + 10)
	bar.ClipsDescendants = true
	bar.Parent = card
	ShopStyle.round(bar, 999)
	ShopStyle.outline(bar, 2)

	local segments: { [string]: TextLabel } = {}
	for _, tier in ipairs(TIERS) do
		local seg = Instance.new("TextLabel")
		seg.Name = "Seg_" .. tier
		seg.BackgroundColor3 = tierColour(tier)
		seg.BorderSizePixel = 0
		seg.Font = Enum.Font.GothamBold
		seg.TextSize = 11
		-- Ink on every tier, because all four rarity colours are bright by
		-- design -- they were chosen to read against a dark card edge.
		seg.TextColor3 = Theme.INK
		seg.Text = ""
		seg.Size = UDim2.new(0, 0, 1, 0)
		seg.Parent = bar
		segments[tier] = seg
	end

	local blurb = label(card, chest.blurb or "", UDim2.new(1, -24, 0, 36),
		UDim2.new(0, 12, 0, 42 + WELL_H + 10 + BAR_H + 8), Enum.Font.Gotham, 12,
		ShopStyle.MUTED)
	blurb.TextWrapped = true

	-- ---- combining spares ------------------------------------------------
	--
	-- THREE CHIPS RATHER THAN ONE BUTTON, and the reason is that the tier is
	-- a real choice rather than a default worth hiding. A single COMBINE
	-- button would have to pick a tier for the player -- the lowest they can
	-- afford, presumably -- and that quietly removes the only decision in
	-- the mechanic: three commons buy a rare roll, three epics buy a
	-- legendary outright, and which of those you spend is the whole
	-- question.
	--
	-- THEY ALSO SHOW PROGRESS TOWARD THE NEXT ONE, which a button cannot.
	-- `2/3` is a reason to open another crate; a greyed button is a reason
	-- to stop looking. Same argument the upgrade pips already make against
	-- printing "Lv 3/4".
	--
	-- LEGENDARY IS ABSENT RATHER THAN GREYED. It is the top tier, so
	-- `ChestService.combine` refuses it outright -- "Legendary is the top
	-- tier. Nothing to combine up to." A fourth chip that can never light
	-- would be a control that does nothing when pressed, which this file
	-- treats as worse than an absent one.
	local combineRow = Instance.new("Frame")
	combineRow.Name = "Combine"
	combineRow.BackgroundTransparency = 1
	combineRow.Size = UDim2.new(1, -24, 0, COMBINE_H)
	combineRow.Position = UDim2.new(0, 12, 0, 42 + WELL_H + 10 + BAR_H + 8 + 38)
	combineRow.Parent = card

	local combineLayout = Instance.new("UIListLayout")
	combineLayout.FillDirection = Enum.FillDirection.Horizontal
	combineLayout.Padding = UDim.new(0, 6)
	combineLayout.SortOrder = Enum.SortOrder.LayoutOrder
	combineLayout.Parent = combineRow

	-- WHICH TIERS THIS CRATE CAN CLIMB OUT OF, ASKED OF ITS OWN POOL.
	--
	-- The rule below has not changed -- a chip that can never light is worse
	-- than an absent one -- only what it is measured against. It used to test
	-- `tier ~= "legendary"`, which is the top of the GLOBAL ladder and was the
	-- right test while every chest carried all four tiers.
	--
	-- A skin is one of three tiers now, so a skin crate has no epic in it at
	-- all and an epic chip on one is a control that does nothing when pressed.
	-- The alien cache is the other way round: it has no COMMON, so a common
	-- chip there is equally dead. Asking the chest's own stock answers both,
	-- and answers the next chest without anybody remembering to come back.
	local pool = Config.chestPool(chestKey)
	local climbable = {}
	for _, tier in ipairs(TIERS) do
		if pool[tier] and #pool[tier] > 0 then
			table.insert(climbable, tier)
		end
	end
	-- The highest stocked tier is what everything else combines UP TO, so it
	-- is never something you combine FROM.
	if #climbable > 0 then
		table.remove(climbable)
	end

	local combines: { [string]: TextButton } = {}
	for i, tier in ipairs(climbable) do
		local chip = Instance.new("TextButton")
		chip.Name = "Combine_" .. tier
		chip.LayoutOrder = i
		-- The chips SHARE the row, however many there are. It was a hardcoded
		-- third back when every crate showed three; a skin crate shows two now
		-- and a fixed third would leave a ragged gap rather than filling it.
		local share = 1 / math.max(#climbable, 1)
		chip.Size = UDim2.new(share, -6 * (#climbable - 1) * share, 1, 0)
		chip.BackgroundColor3 = ShopStyle.SUNK
		chip.BorderSizePixel = 0
		chip.AutoButtonColor = false
		chip.Font = Enum.Font.GothamBold
		chip.TextSize = 11
		chip.TextColor3 = ShopStyle.MUTED
		chip.Text = ""
		chip.Parent = combineRow
		ShopStyle.round(chip, 8)
		ShopStyle.outline(chip, 2, tierColour(tier))

		-- THE CLIENT DECLINES TO ASK FOR A KNOWN NO, which is the same
		-- split the OPEN button above makes and the number row makes for an
		-- item you do not hold. The server re-counts the spares, re-picks
		-- them and refuses out loud if they are not there; this only stops
		-- a chip that is visibly not ready from firing anyway.
		chip.Activated:Connect(function()
			local ui = cards[chestKey]
			if ui and ui.ready[tier] and deps.combine then
				-- NO ENTRY LIST. `ChestCombine` takes an optional pick and
				-- `autoPick` consumes the CHEAPEST spares first when none is
				-- named -- which is the honest default, because every spare at
				-- a tier combines identically, so the only thing the choice
				-- can affect is what is left behind.
				deps.combine(tier, chestKey)
			end
		end)
		combines[tier] = chip
	end
	-- ---- the button ------------------------------------------------------
	local open = Instance.new("TextButton")
	open.Name = "Open"
	open.Size = UDim2.new(1, -24, 0, 38)
	open.Position = UDim2.new(0, 12, 1, -50)
	open.BackgroundColor3 = ShopStyle.BUY
	open.BorderSizePixel = 0
	open.AutoButtonColor = true
	open.Font = Enum.Font.FredokaOne
	open.TextSize = 17
	open.TextColor3 = ShopStyle.TEXT
	open.Text = ""
	open.Parent = card
	ShopStyle.round(open, 12)
	ShopStyle.outline(open, 3)
	ShopStyle.gloss(open)

	-- A short balance still gets the server's refusal and earning hint.
	-- Only a valid Acorn-priced card sends an open request.
	open.Activated:Connect(function()
		if cards[chestKey] and cards[chestKey].canOpen and deps.open then
			deps.open(chestKey)
		end
	end)

	local _ = info
	return { card = card, name = name, progress = progress, segments = segments,
		open = open, blurb = blurb, affordable = false, canOpen = false,
		combines = combines, combineRow = combineRow, ready = {} }
end

-- Repaint one card from the server's own numbers.
local function paint(chestKey: string, info: any)
	local ui = cards[chestKey]
	if not ui then
		return
	end
	local chest = Config.CHESTS[chestKey]
	local currency = info.currency

	ui.progress.Text = ("%d/%d"):format(info.owned or 0, info.total or 0)

	-- THE SEGMENTS ARE LAID OUT BY HAND RATHER THAN BY A UILISTLAYOUT, because
	-- a tier with no stock has to take NO WIDTH and a layout with padding
	-- would still leave its gap. Walked in TIERS order so the bar always runs
	-- common to legendary whatever order `pairs` felt like.
	local at = 0
	for _, tier in ipairs(TIERS) do
		local pct = (info.odds or {})[tier]
		local seg = ui.segments[tier]
		if pct and pct > 0 then
			local w = pct / 100
			seg.Position = UDim2.new(at, 0, 0, 0)
			seg.Size = UDim2.new(w, 0, 1, 0)
			-- The number goes IN the segment, and only where it fits. A 4%
			-- legendary sliver is about twelve pixels wide on this card, and
			-- "4%" typeset across it is a smear that makes the bar harder to
			-- read rather than easier. The sliver being thin is the message.
			seg.Text = if w >= 0.16 then ("%d%%"):format(math.floor(pct + 0.5)) else ""
			seg.Visible = true
			at += w
		else
			seg.Visible = false
		end
	end

	local held = math.floor(loot)
	local cost = info.cost or 0
	ui.canOpen = currency == "loot"
	ui.affordable = ui.canOpen and held >= cost
	local complete = (info.owned or 0) >= (info.total or 0) and (info.total or 0) > 0

	if currency == "loot" then
		Theme.acornPrice(ui.open, ("OPEN %s %d %s"):format(DOT, cost, Config.lootWord(cost)))
	else
		ui.open.Text = "UNAVAILABLE"
	end
	ui.open.BackgroundColor3 = if ui.affordable then ShopStyle.BUY else ShopStyle.DEAR
	ui.open.TextColor3 = if ui.affordable then ShopStyle.TEXT else ShopStyle.MUTED

	-- A FINISHED CHEST STILL OPENS, and saying so is the point of the line.
	-- Every roll from here is a duplicate, which is not a dead outcome -- it
	-- is a spare, and a spare sells or combines. A button that went dead at
	-- 12/12 would be telling a player their collection had stopped paying,
	-- which is the exact thing the spare system exists to make untrue.
	ui.blurb.Text = if ui.canOpen and not ui.affordable
		then Config.acornShortfall(held, cost)
		elseif complete
		then "You have them all. Opens now pay spares."
		else (chest.blurb or "")

	-- ---- the combine chips ----------------------------------------------
	--
	-- THE COUNTS ARE THE SERVER'S AND ARE GLOBAL PER TIER, WHICH IS WHY THE
	-- SAME THREE NUMBERS APPEAR ON EVERY CARD. That reads like a bug and is
	-- the mechanic: `perTier` is how many spares you hold at each rarity
	-- across the WHOLE collection, and the card is where the roll LANDS. So
	-- the chips are your fuel and the card is the target, and the same fuel
	-- can be spent into any of them.
	--
	-- SUMMED ON THE SERVER RATHER THAN HERE, deliberately. Counting spares
	-- per tier needs the rarity rules, and re-deriving those on the client
	-- would be a second copy of `Config.rarityOf` that can disagree with the
	-- one that will actually be charged.
	local perTier = (latest and latest.perTier) or {}
	local need = (latest and latest.need) or Config.COMBINE.need

	-- The server distinguishes regular crates from event sets explicitly;
	-- currency no longer separates them now that every crate costs Acorns.
	local canCombine = info.canCombine == true
	ui.combineRow.Visible = canCombine

	for tier, chip in pairs(ui.combines) do
		local have = perTier[tier] or 0
		local ready = canCombine and have >= need
		ui.ready[tier] = ready

		-- SHORTENED TO FIT RATHER THAN SCALED. A third of a card this wide is
		-- about 96 pixels, and "LEGENDARY 3/3" does not go in it -- but
		-- legendary is not here, and the three that are fit as four letters
		-- plus a count. `TextScaled` would have made it "fit" by shrinking,
		-- which this project already records as a guarantee that means
		-- nothing.
		chip.Text = ("%s %d/%d"):format(tier:sub(1, 4):upper(), math.min(have, need), need)

		-- READY IS THE TIER'S OWN COLOUR AND NOT-READY IS THE WELL, which is
		-- the same two-state language the preview wells above already speak:
		-- a rarity colour means there is something there.
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
	card.Parent = grid
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
			ui.card.LayoutOrder = (Config.CHESTS[info.chest].order or 50) * 1000 + (info.order or 0) + 1
			local held = math.floor(loot)
			local affordable = held >= info.cost
			Theme.acornPrice(ui.buy, ("BUY BACK\n%d %s"):format(info.cost, Config.lootWord(info.cost)))
			ui.buy.BackgroundColor3 = if affordable then ShopStyle.BUY else ShopStyle.DEAR
			ui.buy.TextColor3 = if affordable then ShopStyle.TEXT else ShopStyle.MUTED
			ui.hint.Text = if affordable then "This season only. Get this exact skin back."
				else Config.acornShortfall(held, info.cost)
		end
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
			if not cards[chestKey] then
				cards[chestKey] = buildCard(chestKey, info)
			end
			paint(chestKey, info)
		end
	end
	paintBuybacks()
end

-- Opened from the recovery objective. Wait for the newly visible grid to
-- lay out before scrolling, and re-read positions while it settles.
function Crates.focusBuyback(key: string)
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
-- Coin ticks cannot change crate affordability. Keep the existing caller
-- signature while repainting only when the earned Acorn balance changes.
function Crates.setBalance(_newCoins: number?, newLoot: number?)
	local changed = false
	if type(newLoot) == "number" and newLoot ~= loot then
		loot = newLoot
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
	label(view, "Open a crate and see what is inside.", UDim2.new(1, -8, 0, 22),
		UDim2.new(0, 4, 0, 0), Enum.Font.FredokaOne, 17, ShopStyle.TEXT)
	label(view, "The chances are real, and they are printed on every crate. "
		.. "Something you already own comes back as a SPARE, never as nothing.",
		UDim2.new(1, -8, 0, 18), UDim2.new(0, 4, 0, 22), Enum.Font.Gotham, 12,
		ShopStyle.MUTED)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "CrateGrid"
	scroll.Size = UDim2.new(1, 0, 1, -46)
	scroll.Position = UDim2.new(0, 0, 0, 46)
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

	local cell = Instance.new("UIGridLayout")
	-- IN SCALE, NOT PIXELS, for the reason the front page's shelf is: three
	-- cells of (1/3 - 8) plus two 12-pixel gaps come to exactly the parent
	-- width at EVERY panel size, so this fits a desktop and a phone held
	-- sideways with no resize handler and nothing to keep in step.
	cell.CellSize = UDim2.new(1 / 3, -8, 0, CARD_H)
	cell.CellPadding = UDim2.new(0, 12, 0, 12)
	cell.SortOrder = Enum.SortOrder.LayoutOrder
	cell.Parent = scroll

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

return Crates
