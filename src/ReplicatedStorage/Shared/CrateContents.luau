--!strict
-- Inspect the complete pool without rolling. All odds and prices use ChestState.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Theme = require(Shared.Theme)
local W = require(Shared.ShopWidgets)
local SkinCards = require(Shared.ShopSkinCards)
local Contents = {}
Contents.__index = Contents

-- U+2713, not U+2714. The heavy check mark is an EMOJI-presentation glyph and
-- ignores `TextColor3`, so it renders in its own grey whatever the pill does;
-- this one is drawn by the text font and takes the colour it is given.
local TICK = utf8.char(0x2713)
local CHEVRON = utf8.char(0x2039)
local DOT = utf8.char(0x2022)

function Contents.new(view: Frame, deps: any)
	local self = setmetatable({ view = view, deps = deps, filter = "All", tiles = {}, loot = 0,
		state = {}, cosmetics = nil, rides = nil, pending = false, selected = nil,
		oddsRows = {}, crateShown = nil }, Contents) :: any
	self.root = W.frame(view, "CrateContents", Theme.SAND)
	self.root.Size = UDim2.fromScale(1, 1); self.root.Visible = false; self.root.ZIndex = 5
	self.back = W.button(self.root, "Back", CHEVRON .. " CRATES", Theme.PAPER, function() self:close() end)
	self.back.Position = UDim2.fromOffset(4, 2); self.back.Size = UDim2.fromOffset(112, 40)
	self.title = W.text(self.root, "CrateName", "", 20)
	self.title.Position = UDim2.fromOffset(124, 2); self.title.Size = UDim2.new(1, -132, 0, 40)

	-- WHAT'S INSIDE, WITH THE COLLECTION COUNT BESIDE IT. The count used to
	-- live over in the summary panel, which is the wrong side of the screen
	-- from the thing it describes: it is a fact about this grid, and it is the
	-- number that answers "is there anything in here I have not got".
	self.heading = W.text(self.root, "WhatsInside", "WHAT'S INSIDE", 20)
	self.counter = W.text(self.root, "Collected", "", 14)
	self.counter.Font = Enum.Font.GothamMedium
	self.counter.TextColor3 = Theme.MUTED
	self.counter.Size = UDim2.fromOffset(150, 20)
	-- Seated off the heading's OWN measured width and re-seated whenever it
	-- changes. A hardcoded x is wrong the first time the copy or the text size
	-- moves, which is the stale-geometry guard `ShopStyle.hintToggle` already
	-- keeps for its "?" chip.
	local function seatCounter()
		self.counter.Position = UDim2.fromOffset(
			self.heading.Position.X.Offset + math.ceil(self.heading.TextBounds.X) + 10,
			self.heading.Position.Y.Offset + 5)
	end
	self.heading:GetPropertyChangedSignal("TextBounds"):Connect(seatCounter)
	self.seatCounter = seatCounter

	-- CHIPS, NOT THREE FULL-WIDTH BUTTONS. A filter refines the grid; it is not
	-- the primary action on the screen, and at a third of the width each these
	-- were the loudest controls on it -- louder than OPEN, which is the one
	-- thing this page exists to let you press.
	self.filters = {}
	self.filterBar = W.frame(self.root, "Filters"); self.filterBar.BackgroundTransparency = 1
	self.filterBar.AutomaticSize = Enum.AutomaticSize.X
	self.filterBar.Size = UDim2.fromOffset(0, 34)
	self.filterBar.AnchorPoint = Vector2.new(1, 0)
	local strip = Instance.new("UIListLayout")
	strip.FillDirection = Enum.FillDirection.Horizontal
	strip.Padding = UDim.new(0, 6)
	strip.SortOrder = Enum.SortOrder.LayoutOrder
	strip.VerticalAlignment = Enum.VerticalAlignment.Center
	strip.Parent = self.filterBar
	for i, value in ipairs({ "All", "Owned", "Not owned" }) do
		local b = W.button(self.filterBar, "Filter" .. i, value, Theme.PAPER, function()
			self.filter = value; self.list.CanvasPosition = Vector2.zero; self:paint()
		end)
		-- As wide as its own word, which is the rule the tab rail already
		-- keeps: a flat width spends the same room on "All" as on "Not owned".
		b.AutomaticSize = Enum.AutomaticSize.X
		b.Size = UDim2.fromOffset(0, 34)
		b.TextSize = 13
		b.LayoutOrder = i
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 12); pad.PaddingRight = UDim.new(0, 12)
		pad.Parent = b
		self.filters[value] = b
	end

	self.list = W.scroll(self.root, "Collection")
	self.grid = W.grid(self.list, 10)
	self.empty = W.text(self.root, "Empty", "No items match this filter.", 16)
	self.empty.Position = UDim2.fromOffset(14, 150); self.empty.Size = UDim2.new(1, -28, 0, 50)
	self.empty.Visible = false

	-- Shown only when there is genuinely more below the fold. A standing "there
	-- is more" hint on a grid that already fits is the wallpaper this file's
	-- own notify rule refuses: what a player stops seeing.
	self.more = W.text(self.root, "ScrollHint", "", 13)
	self.more.Font = Enum.Font.GothamMedium
	self.more.TextColor3 = Theme.MUTED
	self.more.TextXAlignment = Enum.TextXAlignment.Center
	self.more.Visible = false

	self.summary = W.frame(self.root, "CrateSummary", Theme.PAPER); W.round(self.summary)
	-- THE CRATE YOU ARE ABOUT TO OPEN, from `ShopScenes.crate` -- the same model
	-- the Style & Crates tile shows, rather than a second one built here.
	self.crateWell = W.frame(self.summary, "CratePicture", Theme.PAPER_DEEP)
	W.round(self.crateWell, 12)
	self.oddsTitle = W.text(self.summary, "OddsTitle", "DROP CHANCES", 13)
	self.oddsHolder = W.frame(self.summary, "Odds"); self.oddsHolder.BackgroundTransparency = 1
	self.oddsList = Instance.new("UIListLayout")
	self.oddsList.Padding = UDim.new(0, 6)
	self.oddsList.SortOrder = Enum.SortOrder.LayoutOrder
	self.oddsList.Parent = self.oddsHolder

	-- ONE ROW PER TIER, IN THE TIER'S OWN COLOUR, rather than one wrapped line
	-- of text. The tiers are built once and hidden when a crate does not stock
	-- one, so the order is always `RARITY_ORDER` and a missing tier leaves no
	-- gap. The colours are `Config.RARITIES` and deliberately NOT the mockup's
	-- -- there is one rarity ladder in this game and a second set of colours
	-- wearing the same names is the failure this file already records.
	for i, tier in ipairs(Config.RARITY_ORDER) do
		local colour = Config.RARITIES[tier].colour
		local row = W.frame(self.oddsHolder, "Odds_" .. tier, colour:Lerp(Theme.PAPER, .55))
		row.LayoutOrder = i; row.Size = UDim2.new(1, 0, 0, 30); W.round(row, 10)
		local name = W.text(row, "Tier", (tier:gsub("^%l", string.upper)), 14)
		name.Position = UDim2.fromOffset(10, 0); name.Size = UDim2.new(1, -70, 1, 0)
		local pct = W.text(row, "Chance", "", 14)
		pct.Position = UDim2.new(1, -58, 0, 0); pct.Size = UDim2.new(0, 48, 1, 0)
		pct.TextXAlignment = Enum.TextXAlignment.Right
		self.oddsRows[tier] = { row = row, name = name, pct = pct }
	end

	-- NO CRATE CAN REPEAT, AND THAT IS WORTH A LINE BECAUSE IT IS THE OPPOSITE
	-- OF WHAT THIS AUDIENCE EXPECTS FROM A CRATE. Every pool is filtered to
	-- what the player does not own (designer, 2026-09-23; see
	-- `ChestService.poolOf`), so an open is always something new -- and the
	-- copy that used to sit here sold the old rule, telling players duplicates
	-- become spares and pointing them at a combine row that has since left
	-- this tab. Copy outlives the thing it describes, and nothing errors.
	self.note = W.text(self.summary, "Duplicates", "Every crate gives you something you do not already own.", 13)
	self.note.TextWrapped = true; self.note.TextTruncate = Enum.TextTruncate.None
	-- NOT A BUTTON ANY MORE, and deliberately still a button-shaped label.
	-- This opened the crate for its price; a crate is earned rather than
	-- bought, so it names where one comes from instead. The shape stays
	-- because the summary's layout is measured around it.
	self.open = W.button(self.summary, "OpenCrate", "Loading...", Theme.GOOD, function() end)
	self.open.Active = false
	self.open.AutoButtonColor = false
	view:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:layout() end)
	return self
end

function Contents:owned(entry: any): boolean?
	local source = if entry.kind == "ride" then self.rides else self.cosmetics
	if not source then return nil end
	local fields = { skin = "skins", decor = "decor", ride = "rides", finish = "finishes", accessory = "accessories" }
	local field = fields[entry.kind]
	if not field then return nil end
	local info = source[field] and source[field][entry.key]
	return info ~= nil and (info.owned == true or info.unlocked == true)
end

function Contents:show(key: string)
	if self.selected ~= key then
		for _, tile in ipairs(self.tiles) do tile.frame:Destroy() end
		table.clear(self.tiles)
		self.selected = key; self.filter = "All"; self.list.CanvasPosition = Vector2.zero
		for i, entry in ipairs(self.deps.stockOf(key)) do
			local rarity = Config.RARITIES[entry.tier]
			-- THE ITEM'S OWN COLOUR, with the rarity as a fallback for anything
			-- in a catalogue that keeps no colour at all.
			local f = W.frame(self.list, entry.kind .. "_" .. entry.key, rarity.colour)
			f.LayoutOrder = i; W.round(f)
			-- THE WHOLE TILE IS THE TIER: ground, spotlight, edge and the text
			-- area under the picture, so a pool reads as a ladder of colours
			-- rather than as pale tiles with a coloured rim. Legendary is still
			-- drawn heavier, since colour alone separates four tiers only for a
			-- player who can see four.
			local edge = f:FindFirstChild("ShopOutline")
			if edge and edge:IsA("UIStroke") then
				edge.Thickness = if entry.tier == "legendary" then 5 else 3
			end
			local preview = W.frame(f, "Preview"); preview.BackgroundTransparency = 1
			preview.Position = UDim2.fromOffset(4, 4); preview.Size = UDim2.new(1, -8, 1, -62)
			local palette = SkinCards.dressCard(f, entry.tier, { preview })
			local name = W.text(f, "Name", entry.name, 14)
			name.Position = UDim2.new(0, 7, 1, -58); name.Size = UDim2.new(1, -14, 0, 30)
			name.TextWrapped = true; name.TextTruncate = Enum.TextTruncate.None
			SkinCards.onTierText(name)
			-- A PILL, NOT A LINE OF TEXT. Owned is the one fact somebody scans
			-- this grid for, and a filled shape answers it without being read.
			local status = W.text(f, "Ownership", "", 12)
			status.Position = UDim2.new(0, 7, 1, -26); status.Size = UDim2.new(1, -14, 0, 20)
			status.TextXAlignment = Enum.TextXAlignment.Center
			W.round(status, 999)
			table.insert(self.tiles, { frame = f, preview = preview, entry = entry, status = status, built = false,
				deep = if palette then palette.deep else Theme.INK })
		end
	end
	-- The crate picture comes in through `deps`, like the item icons do, rather
	-- than this module requiring the model builder. A view that reaches for
	-- geometry is a view that cannot be exercised without a 3D stub, and
	-- OPTIONAL so a caller with no picture to give loses the picture and
	-- nothing else.
	if self.crateShown ~= key and self.deps.crateIcon then
		self.crateShown = key
		self.deps.crateIcon(self.crateWell, key)
	end
	self.root.Visible = true
	self.deps.showList(false)
	self:layout(); self:paint(); self:loadVisible()
	if not self.scrollConnection then
		self.scrollConnection = self.list:GetPropertyChangedSignal("CanvasPosition"):Connect(function() self:loadVisible() end)
		self.list:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function()
			self:loadVisible(); self:refreshHint()
		end)
	end
end

function Contents:close()
	self.root.Visible = false; self.deps.showList(true)
end

function Contents:loadVisible()
	if not self.root.Visible or not self.view.Visible then return end
	local top, bottom = self.list.AbsolutePosition.Y - 180, self.list.AbsolutePosition.Y + self.list.AbsoluteSize.Y + 180
	for _, tile in ipairs(self.tiles) do
		local y = tile.frame.AbsolutePosition.Y
		if tile.frame.Visible and not tile.built and y + tile.frame.AbsoluteSize.Y >= top and y <= bottom then
			tile.built = true
			self.deps.iconFor(tile.entry.kind, tile.entry.key, tile.preview)
		end
	end
end

-- The pool's own noun, so a skin crate says piggies. Derived from what is
-- actually in the crate rather than kept per chest in Config: a second field
-- naming what a pool holds is a second thing to keep in step with the pool.
function Contents:poolNoun(): string
	for _, tile in ipairs(self.tiles) do
		if tile.entry.kind ~= "skin" then return "items" end
	end
	return if #self.tiles > 0 then "piggies" else "items"
end

function Contents:refreshHint()
	local overflowing = self.list.AbsoluteCanvasSize.Y > self.list.AbsoluteSize.Y + 4
	self.more.Visible = self.view.AbsoluteSize.Y >= 180 and overflowing and self.filter == "All" and #self.tiles > 0
	if self.more.Visible then
		self.more.Text = ("Scroll for all %d %s"):format(#self.tiles, self:poolNoun())
	end
end

function Contents:layout()
	local width = self.view.AbsoluteSize.X
	local height = self.view.AbsoluteSize.Y
	local short = height < 430
	local wide = width >= 620 or (short and width >= 460)
	local sideWidth = if short then 210 else 238
	local reserved = sideWidth + 16
	-- A heading, a counter and three chips on one row wants about 520 studs.
	-- This is the case none of the mockups covers, because all three were drawn
	-- at desktop width.
	local roomy = width >= 520
	local summaryH = if height < 410 then 150 else 176
	self.title.Size = UDim2.new(1, -132-(if short and wide then reserved else 0), 0, 40)
	self.title.TextSize = if wide then 18 else 16

	self.heading.Position = UDim2.fromOffset(6, 48)
	self.heading.Size = UDim2.fromOffset(200, 26)
	self.heading.TextSize = if roomy then 20 else 17
	self.heading.Visible=not (short and wide)
	self.counter.Visible=self.heading.Visible
	self.seatCounter()

	self.filterBar.Position = if roomy
		then UDim2.new(1, -10, 0, 46)
		else UDim2.new(1, -10, 0, 80)
	if short and wide then self.filterBar.Position=UDim2.new(1,-reserved-8,0,46) end
	local listTop = if roomy or (short and wide) then 82 else 118
	self.list.Position = UDim2.fromOffset(0, listTop)
	self.list.Size = if wide
		then UDim2.new(1, -reserved, 1, -listTop - (if height < 180 then 4 else 24))
		else UDim2.new(1, 0, 1, -listTop - summaryH - 28)
	local columns = math.max(1,math.floor((self.list.AbsoluteSize.X-4)/142))
	self.grid.CellSize = UDim2.new(1 / columns, -(14 + (columns - 1) * 10) / columns, 0, if short or width<740 then 144 else 182)
	self.empty.Position = UDim2.fromOffset(14, listTop + 40)

	self.more.Position = UDim2.new(0, 0, 1, if wide then -22 else -summaryH - 26)
	self.more.Size = UDim2.new(1, if wide then -reserved else 0, 0, 18)

	self.summary.Position = if wide then UDim2.new(1, -sideWidth-8, 0, listTop) else UDim2.new(0, 4, 1, -summaryH - 4)
	self.summary.Size = if wide then UDim2.new(0, sideWidth, 1, -listTop-6) else UDim2.new(1, -14, 0, summaryH)
	if short and wide then
		self.summary.Position=UDim2.new(1,-sideWidth-8,0,4)
		self.summary.Size=UDim2.new(0,sideWidth,1,-10)
	end

	-- The crate picture is the first thing to go when there is no room for it:
	-- the odds and the button are what the page is for.
	local crateH = if wide and not short then 104 else 0
	self.crateWell.Visible = crateH > 0
	self.crateWell.Position = UDim2.fromOffset(10, 10)
	self.crateWell.Size = UDim2.new(1, -20, 0, math.max(1, crateH))

	local rowH = if height < 180 then 20 elseif wide and not short then 30 else 22
	self.oddsList.Padding = UDim.new(0, if wide and not short then 6 else 2)
	for _, ui in pairs(self.oddsRows) do
		ui.row.Size = UDim2.new(1, 0, 0, rowH)
		ui.name.TextSize = if wide then 14 else 13
		ui.pct.TextSize = if wide then 14 else 13
	end
	self.oddsTitle.Visible = wide and not short
	local oddsY = if wide and not short then 10 + crateH + 12 else 6
	self.oddsTitle.Position = UDim2.fromOffset(10, oddsY)
	self.oddsTitle.Size = UDim2.new(1, -20, 0, 18)
	local rowsY = if self.oddsTitle.Visible then oddsY + 22 else oddsY
	self.oddsHolder.Position = UDim2.fromOffset(10, rowsY)
	self.oddsHolder.Size = UDim2.new(1, -20, 0, #Config.RARITY_ORDER * (rowH + self.oddsList.Padding.Offset))
	self.note.Visible = wide and not short
	-- Seated below the room ALL FOUR tiers would take rather than below the
	-- three today's crates stock. A hidden row collapses out of the list, so
	-- this leaves a gap on a two-tier crate and can never be overlapped by a
	-- fourth -- which is the direction to be wrong in, since the overlap is
	-- what nobody would notice until a crate grew a tier.
	self.note.Position = UDim2.fromOffset(10, rowsY + #Config.RARITY_ORDER * (rowH + self.oddsList.Padding.Offset) + 8)
	self.note.Size = UDim2.new(1, -20, 0, 54)
	self.open.Position = UDim2.new(0, 10, 1, -54); self.open.Size = UDim2.new(1, -20, 0, 44)
	self:loadVisible(); self:refreshHint()
end

function Contents:paint()
	if not self.selected or not self.root.Visible then return end
	local info = self.state.chests and self.state.chests[self.selected]
	local chest = Config.CHESTS[self.selected]
	self.title.Text = chest.name
	self.counter.Text = if info then ("%d / %d collected"):format(info.owned, info.total) else "loading..."
	self.seatCounter()

	-- THE SUMMARY WEARS THE CRATE'S OWN COLOUR, which is what stops five crate
	-- pages reading as one page with a different word on it. Lerped well toward
	-- paper so ink clears the body floor on every chest hue.
	local hue = chest.colour or Theme.HUE.crates
	self.summary.BackgroundColor3 = hue:Lerp(Theme.PAPER, .80)
	self.crateWell.BackgroundColor3 = hue:Lerp(Theme.PAPER, .55)

	for _, tier in ipairs(Config.RARITY_ORDER) do
		local ui = self.oddsRows[tier]
		local value = (info and info.odds and info.odds[tier]) or 0
		ui.row.Visible = value > 0
		if value > 0 then
			-- WHOLE NUMBERS. The two decimals were the server's renormalisation
			-- showing through, and "52.00%" asks a nine-year-old to read four
			-- characters that carry nothing. Anything genuinely under one per
			-- cent says so rather than rounding itself to zero.
			ui.pct.Text = if value < 1 then "<1%" else ("%d%%"):format(math.floor(value + 0.5))
		end
	end

	local visible = 0
	for _, tile in ipairs(self.tiles) do
		local owned = self:owned(tile.entry)
		if owned == nil then
			tile.status.Text = "LOADING"
			tile.status.BackgroundColor3 = Theme.PAPER_DEEP
			tile.status.BackgroundTransparency = 0
			tile.status.TextColor3 = Theme.MUTED
		elseif owned then
			-- IN THE TIER'S OWN COLOURS: owned is the solid, deep pill; not
			-- owned is the hollow one. Filled against empty is the read, so
			-- it survives on all four grounds without a fifth colour.
			tile.status.Text = TICK .. " OWNED"
			tile.status.BackgroundColor3 = tile.deep
			tile.status.BackgroundTransparency = 0
			tile.status.TextColor3 = Theme.PAPER
		else
			tile.status.Text = "NOT OWNED"
			tile.status.BackgroundColor3 = Theme.PAPER
			tile.status.BackgroundTransparency = 0.15
			tile.status.TextColor3 = tile.deep
		end
		local pillEdge = tile.status:FindFirstChild("ShopOutline")
		if pillEdge and pillEdge:IsA("UIStroke") then pillEdge.Color = tile.deep end
		tile.frame.Visible = self.filter == "All"
			or (self.filter == "Owned" and owned == true)
			or (self.filter == "Not owned" and owned == false)
		if tile.frame.Visible then visible += 1 end
	end
	self.empty.Visible = visible == 0
	for name, b in pairs(self.filters) do
		b.BackgroundColor3 = if name == self.filter then W.colours.style else Theme.PAPER
	end

	self.open.BackgroundColor3 = Theme.SAND_DEEP
	self.open.Text = if info ~= nil then "EARN THIS CRATE" else "UNAVAILABLE"
	self:refreshHint()
	task.defer(function() self:loadVisible() end)
end

-- `loot` is kept in the signature and ignored: nothing on this surface is
-- priced in it any more, and the caller has one fewer thing to change.
function Contents:update(state: any, _loot: number, cosmetics: any, rides: any)
	self.state = state or {}; self.cosmetics = cosmetics; self.rides = rides; self:paint()
end

function Contents:rebuildIcons()
	for _, tile in ipairs(self.tiles) do
		tile.built = false
		for _, child in ipairs(tile.preview:GetChildren()) do child:Destroy() end
	end
	self.crateShown = nil
	if self.selected and self.deps.crateIcon then
		self.crateShown = self.selected
		self.deps.crateIcon(self.crateWell, self.selected)
	end
	self:loadVisible()
end
return Contents
