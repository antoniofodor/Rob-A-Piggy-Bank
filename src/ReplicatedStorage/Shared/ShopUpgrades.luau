--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Theme = require(Shared.Theme)
local W = require(Shared.ShopWidgets)
local Facts = require(Shared.ShopUpgradeFacts)
local Preview = require(Shared.UpgradePreview)
local ShopUpgrades = {}
ShopUpgrades.__index = ShopUpgrades
-- TWO GROUPS: DEFEND AND ROB. THERE IS NO EARN GROUP (designer, 2026-09-23).
--
-- It held one row, "Earn Faster" (`income`), which raised what every piggy
-- pays per second for coins. What raises that rate now is the PERMANENT COIN
-- MULTIPLIER, which is bought with a REBIRTH -- so a coin-priced rung doing
-- the same job was a second answer to one question, on the shelf a player
-- reads first. "capacity" (Bigger Piggy Bank) was the group's other row and
-- had already gone with the pig's ceiling.
--
-- WHAT THIS TAB IS FOR IS NOW ONE SENTENCE: the two sides of a robbery. Every
-- row in it has a fixed `max` that no rebirth lifts, which is why nothing here
-- carries a `gated` flag any more.
--
-- THE SERVER PATH IS UNTOUCHED AND IS NOW UNREACHABLE FROM THE CLIENT.
-- `PurchaseRequest("income")`, `Config.getIncomeCost` and `data.incomeLevel`
-- all still exist and `incomeLevel` is still a real multiplier inside
-- `Config.collectionRate`; nothing can raise it, so it sits at 1. Retiring the
-- FIELD is a save migration and the designer's call, not this file's.
local GROUPS = { { key = "defense", label = "Defend", colour = Theme.HUE.gear, keys = { "locks", "fences" } },
	{ key = "offense", label = "Rob", colour = Theme.HUE.kit, keys = { "lockpicks", "sack", "boots", "tiptoe" } } }

function ShopUpgrades.new(view: Frame, purchase: (string) -> ())
	local self = setmetatable({ view = view, purchase = purchase, group = 1, selected = GROUPS[1].keys[1],
		economy = nil, snapshot = {}, tiles = {}, busy = false, mobileDetail = false, facts = {} }, ShopUpgrades) :: any
	self.root = W.frame(view, "UpgradeBrowser")
	self.root.Size = UDim2.fromScale(1, 1)
	self.root.BackgroundTransparency = 1
	self.groupButtons = {}
	for i, g in ipairs(GROUPS) do
		local b = W.button(self.root, g.key, g.label, g.colour, function()
			self.group = i; self.selected = g.keys[1]; self.mobileDetail = false; self:render()
		end)
		-- SIZED FROM `#GROUPS` RATHER THAN A PINNED THIRD. The row was hardcoded
		-- to three and there are two; a pinned fraction would have left a third
		-- of the rail empty and read as a tab that failed to render.
		b.Position = UDim2.new((i - 1) / #GROUPS, 4, 0, 2)
		b.Size = UDim2.new(1 / #GROUPS, -10, 0, 44)
		self.groupButtons[i] = b
	end
	self.list = W.scroll(self.root, "UpgradeChoices")
	self.grid = W.grid(self.list)
	self.detail = W.frame(self.root, "UpgradeDetails", Theme.PAPER)
	W.round(self.detail)
	local detailEdge = self.detail:FindFirstChildOfClass("UIStroke") :: UIStroke
	detailEdge.Thickness = 3
	self.back = W.button(self.detail, "BackToUpgrades", "< UPGRADES", Theme.GOLD, function()
		self.mobileDetail = false; self:layout()
	end)
	self.back.Size = UDim2.fromOffset(88, 42)
	self.back.Text = "< ALL"
	self.back.Position = UDim2.fromOffset(8, 8)
	self.title = W.text(self.detail, "Title", "", 22)
	self.title.Position = UDim2.fromOffset(12, 12); self.title.Size = UDim2.new(1, -24, 0, 30)
	self.level = W.text(self.detail, "Level", "", 15)
	self.level.Position = UDim2.fromOffset(12, 44); self.level.Size = UDim2.new(1, -24, 0, 22)
	self.model = W.frame(self.detail, "Preview", Theme.GOLD:Lerp(Theme.PAPER, .6))
	self.model.Position = UDim2.fromOffset(12, 74); self.model.Size = UDim2.new(1, -24, .3, 0)
	W.round(self.model, 10, false)
	W.hero(self.model, Theme.GOLD)
	self.stats = W.scroll(self.detail, "StatComparison")
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Parent = self.stats
	self.note = W.text(self.detail, "Explanation", "", 13)
	self.note.TextWrapped = true; self.note.TextTruncate = Enum.TextTruncate.None
	self.note.Position = UDim2.new(0, 12, 1, -98); self.note.Size = UDim2.new(1, -24, 0, 34)
	self.buy = W.button(self.detail, "PurchaseUpgrade", "Loading...", Theme.GOOD, function()
		local info = self:info(self.selected)
		if self.busy or not info or info.level >= info.max or (self.economy and self.economy.coins or 0) < info.cost then return end
		self.busy = true; self.buy.Text = "REQUESTING..."; self.buy.Active = false
		self.purchase(self.selected)
		task.delay(1.2, function() self.busy = false; if self.root.Parent then self:render() end end)
	end)
	self.buy.Size = UDim2.new(1, -24, 0, 48); self.buy.Position = UDim2.new(0, 12, 1, -58)
	view:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() self:layout() end)
	self:render()
	return self
end

-- THE `income` BRANCH STOOD HERE and was the only row this ever answered for
-- out of the ECONOMY push rather than the upgrade snapshot -- a level, a
-- rebirth-lifted ceiling and a `gated` flag that no other row has. It went
-- with the Earn group. `self.economy` is still kept, because affordability is
-- read off its `coins`.
function ShopUpgrades:info(key: string): any
	return self.snapshot[key]
end

-- Every upgrade uses rendered icon art. The model builder is a fallback for
-- future upgrade families that do not yet have a registered image.
function ShopUpgrades:modelFor(key: string, level: number): Model?
	return Preview.build(key, math.max(1, level))
end

function ShopUpgrades:showArt(holder: GuiObject, key: string, level: number)
	if not W.icon(holder, key, true) then W.preview(holder, self:modelFor(key, level)) end
end

function ShopUpgrades:layout()
	local width, height = self.view.AbsoluteSize.X, self.view.AbsoluteSize.Y
	local compact = width < 740
	local showDetail = not compact or self.mobileDetail
	self.list.Visible = not compact or not self.mobileDetail
	self.detail.Visible = showDetail
	self.back.Visible = compact
	self.list.Position = UDim2.fromOffset(0, 56)
	self.list.Size = if compact then UDim2.new(1, 0, 1, -56) else UDim2.new(.53, -8, 1, -56)
	self.detail.Position = if compact then UDim2.fromOffset(4, 56) else UDim2.new(.53, 6, 0, 56)
	self.detail.Size = if compact then UDim2.new(1, -8, 1, -60) else UDim2.new(.47, -10, 1, -60)
	-- On the shortest phones, Back returns to the group choices. Give the
	-- selected upgrade that row's space so its comparison remains readable.
	local focusedDetail = compact and self.mobileDetail and height < 230
	for _,button in ipairs(self.groupButtons) do button.Visible = not focusedDetail end
	if focusedDetail then
		self.detail.Position=UDim2.fromOffset(4,4)
		self.detail.Size=UDim2.new(1,-8,1,-8)
	end
	local smallCards = compact or height < 430
	local gap = if smallCards then 8 else 12
	local columns = math.max(1, math.floor((self.list.AbsoluteSize.X-14+gap)/(if smallCards then 148 else 180)))
	if not smallCards then columns = math.min(2, columns) end
	self.grid.CellPadding = UDim2.fromOffset(gap,gap)
	self.grid.CellSize = UDim2.new(1 / columns, -(14 + (columns - 1) * gap) / columns, 0, if smallCards then 170 else 360)
	for _,tile in pairs(self.tiles) do
		tile.title.TextSize=if smallCards then 16 else 22
		tile.title.Position=UDim2.fromOffset(10,8);tile.title.Size=UDim2.new(1,-48,0,if smallCards then 38 else 54)
		tile.model.Position=UDim2.fromOffset(4,if smallCards then 44 else 62)
		tile.model.Size=UDim2.new(1,-8,1,if smallCards then -98 else -128)
		tile.level.Position=UDim2.new(0,8,1,if smallCards then -49 else -59)
		tile.level.Size=UDim2.new(1,-16,0,if smallCards then 22 else 26)
		tile.level.TextSize=if smallCards then 11 else 13
		tile.price.Position=UDim2.new(0,8,1,if smallCards then -25 else -32)
		tile.price.TextSize=if smallCards then 14 else 17
	end
	local short = height < 460
	local tiny = height < 350
	local head = 8
	self.title.Position = UDim2.fromOffset(if compact then 108 else 12, head)
	self.title.Size = UDim2.new(1, -(if compact then 120 else 24), 0, 30)
	self.title.TextSize = if compact then 20 else 26
	self.level.Position = UDim2.fromOffset(12, head + 30)
	self.level.Size=UDim2.new(1,-24,0,22)
	self.note.Visible = not tiny
	if short then
		self.model.Position = UDim2.fromOffset(12, head + 57)
		self.model.Size = UDim2.new(.38, -16, 1, -head - (if tiny then 121 else 160))
		self.stats.Position = UDim2.new(.38, 0, 0, head + 57)
		self.stats.Size = UDim2.new(.62, -12, 1, -head - (if tiny then 123 else 163))
		if tiny then
			self.title.Position=UDim2.fromOffset(if compact then 108 else 12,6)
			self.title.Size=UDim2.new(1,-(if compact then 120 else 24),0,26)
			self.level.Position=UDim2.fromOffset(if compact then 108 else 12,34)
			self.level.Size=UDim2.new(1,-(if compact then 120 else 24),0,18)
			self.model.Position=UDim2.fromOffset(12,55);self.model.Size=UDim2.new(.29,-16,1,-113)
			self.stats.Position=UDim2.new(.29,0,0,55);self.stats.Size=UDim2.new(.71,-12,1,-113)
		end
	else
		self.model.Position = UDim2.fromOffset(12, head + 57)
		if not compact then
			-- Give the artwork the space above one readable, scrollable stat row.
			local artHeight = math.max(120, self.detail.AbsoluteSize.Y - head - 267)
			self.model.Size = UDim2.new(1, -24, 0, artHeight)
			self.stats.Position = UDim2.fromOffset(8, head + 65 + artHeight)
			self.stats.Size = UDim2.new(1, -16, 0, 98)
		else
			self.model.Size = UDim2.new(1, -24, .35, 0)
			self.stats.Position = UDim2.new(0, 8, .35, head + 65)
			self.stats.Size = UDim2.new(1, -16, .65, -head - 172)
		end
	end
end

function ShopUpgrades:render()
	local g = GROUPS[self.group]
	for i, b in ipairs(self.groupButtons) do
		b.BackgroundColor3 = if i == self.group then GROUPS[i].colour else Theme.PAPER
	end
	for _, tile in pairs(self.tiles) do tile.button.Visible = false end
	for order, key in ipairs(g.keys) do
		local info = self:info(key)
		if info then
			local tile = self.tiles[key]
			if not tile then
				local button = W.button(self.list, key, "", g.colour:Lerp(Theme.PAPER, .25), function()
					self.selected = key; self.mobileDetail = true; self:render()
				end)
				local title = W.text(button, "Name", info.name, 18)
				title.TextWrapped = true; title.TextTruncate = Enum.TextTruncate.None
				title.Position = UDim2.fromOffset(10, 8); title.Size = UDim2.new(1, -20, 0, 25)
				local model = W.frame(button, "Model"); model.BackgroundTransparency = 1
				model.Position = UDim2.fromOffset(6, 35); model.Size = UDim2.new(1, -12, 1, -94)
				local level = W.text(button, "Level", "", 13)
				level.BackgroundTransparency = 0; level.TextXAlignment = Enum.TextXAlignment.Center
				W.round(level, 11, false)
				local lock = W.lock(level)
				level.Position = UDim2.new(0, 10, 1, -55); level.Size = UDim2.new(1, -20, 0, 20)
				local price = W.text(button, "Price", "", 17)
				price.Position = UDim2.new(0, 10, 1, -32); price.Size = UDim2.new(1, -20, 0, 24)
				local check = W.selection(button)
				local halo = Instance.new("UIStroke"); halo.Name = "SelectionGlow"
				halo.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; halo.Thickness = 7
				halo.Transparency = .65; halo.Color = Theme.GOLD; halo.Parent = button
				tile = { button = button, title = title, model = model, level = level, price = price, check = check, halo = halo, lock = lock }
				self.tiles[key] = tile
			end
			tile.button.Visible = true; tile.button.LayoutOrder = order
			local selected = key == self.selected
			W.gradient(tile.button, if selected then g.colour else g.colour:Lerp(Theme.PAPER, .55))
			tile.check.Visible = selected; tile.halo.Enabled = selected
			local edge = tile.button:FindFirstChild("ShopOutline") :: UIStroke
			edge.Thickness = if selected then 3 else 2
			local gated = info.level >= info.max and info.gated
			tile.level.BackgroundColor3 = if gated then Theme.PRESTIGE else Theme.PAPER
			tile.level.TextColor3 = if gated then Theme.PAPER else Theme.INK
			tile.lock.Visible = gated == true
			tile.level.Text = ("LEVEL %d / %d"):format(info.level, info.max)
			-- Measured rather than guessed, because these labels truncate
			-- SILENTLY: at the small-card TextSize of 14 the box is about 128
			-- and "NEEDS REBIRTH" is 95, where "REBIRTH TO UNLOCK" is 127 and
			-- would have sat exactly on the edge.
			tile.price.Text = if info.level < info.max then Config.formatCoins(info.cost) .. " coins"
				elseif info.gated then "NEEDS REBIRTH" else "MAX LEVEL"
			if tile.shownLevel ~= info.level then
				tile.shownLevel = info.level; self:showArt(tile.model, key, info.level)
			end
		end
	end
	local info = self:info(self.selected)
	if info then
		-- A GATED ROW PREVIEWS THE LEVEL A REBIRTH OPENS, which is the whole
		-- point of showing it: clamped to `max`, both columns of every stat
		-- row printed the SAME number, so the one surface that could have said
		-- what the next rebirth is worth said nothing at all.
		local maxed = info.level >= info.max
		local nextLevel = if maxed and not info.gated then info.level else info.level + 1
		self.title.Text = info.name
		-- No arrow when there is nowhere to point: "LEVEL 42 -> LEVEL 42"
		-- reads as a broken readout rather than as a ceiling.
		self.level.Text = if maxed then ("LEVEL %d"):format(info.level)
			else ("LEVEL %d  %s  LEVEL %d"):format(info.level, utf8.char(0x2192), nextLevel)
		self.note.Text = info.blurb or ""
		W.gradient(self.model, g.colour)
		local signature = self.selected .. ":" .. nextLevel
		if self.shownModel ~= signature then
			self.shownModel = signature; self:showArt(self.model, self.selected, nextLevel)
		end
		local values = Facts.rows(self.selected, info.level, nextLevel, self.economy)
		for _, row in ipairs(self.facts) do row.frame.Visible = false end
		for i, value in ipairs(values) do
			local row = self.facts[i]
			if not row then
				local f = W.frame(self.stats, "Stat" .. i, Theme.SAND)
				f.Size = UDim2.new(1, -14, 0, 86); f.LayoutOrder = i; W.round(f, 8, false)
				local label = W.text(f, "Stat", "", 14); label.Position = UDim2.fromOffset(8, 5); label.Size = UDim2.new(1, -16, 0, 22)
				local now = W.text(f, "Now", "", 17); now.Position = UDim2.fromOffset(8, 32); now.Size = UDim2.new(.46, -12, 0, 49); now.TextWrapped = true; now.TextTruncate = Enum.TextTruncate.None
				local arrow = W.text(f, "ImprovementArrow", utf8.char(0x2192), 23); arrow.Position = UDim2.new(.46, -8, 0, 34); arrow.Size = UDim2.new(.10, 0, 0, 38); arrow.TextColor3 = Theme.GOOD_INK
				local after = W.text(f, "Next", "", 17); after.Position = UDim2.new(.55, 4, 0, 32); after.Size = UDim2.new(.45, -12, 0, 49); after.TextWrapped = true; after.TextTruncate = Enum.TextTruncate.None; after.TextColor3 = Theme.GOOD_INK
				row = { frame = f, label = label, now = now, after = after }; self.facts[i] = row
			end
			row.frame.Visible = true; row.label.Text = value.label
			row.now.Text = "NOW" .. string.char(10) .. value.now
			-- "REBIRTH" and not "AFTER REBIRTH": this column is half the panel
			-- less 12, which is 149 on a phone, and the label has to stay on
			-- one line above a value that already wraps to two.
			row.after.Text = (if maxed and info.gated then "REBIRTH" else "NEXT")
				.. string.char(10) .. value.after
		end
		local affordable = (self.economy and self.economy.coins or 0) >= info.cost
		-- Through `coinPrice`, which hangs a drawn coin off the text and hides it
		-- on the two states that are not a price. The separator is the middot
		-- this game already uses on the plot sign and the ride tiles, rather
		-- than the two spaces that were here -- which render as two spaces.
		-- DELIBERATELY CARRIES NO DIGIT. `coinPrice` hangs a drawn coin off any
		-- text containing one, so "REBIRTH FOR LEVEL 43" would have put a coin
		-- beside a requirement that coins cannot meet.
		Theme.coinPrice(self.buy, if self.busy then "REQUESTING..."
			elseif maxed and info.gated then "REBIRTH TO UNLOCK MORE"
			elseif maxed then "MAX LEVEL"
			elseif not affordable then "NEED " .. Config.formatCoins(info.cost - (self.economy and self.economy.coins or 0)) .. " MORE COINS"
			else "UPGRADE " .. utf8.char(0x2022) .. " " .. Config.formatCoins(info.cost))
		self.buy.Active = not self.busy and not maxed and affordable
		-- Prestige rather than the dead sand a true MAX LEVEL gets, so the
		-- strip points at the thing that lifts it. INK on that plum measures
		-- 1.99 and PAPER measures 7.70, so the text colour moves with it --
		-- W.button seats INK, which is the readable answer on the other three.
		local gate = maxed and info.gated
		self.buy.BackgroundColor3 = if gate then Theme.PRESTIGE
			elseif affordable and not maxed then Theme.GOOD else Theme.SAND_DEEP
		self.buy.TextColor3 = if gate then Theme.PAPER else Theme.INK
	end
	self:layout()
end

function ShopUpgrades:setEconomy(state: any) self.economy = state; self:render() end
function ShopUpgrades:setUpgrades(state: any) self.snapshot = state; self:render() end
function ShopUpgrades:rebuildIcons()
	self.shownModel = nil
	for _, tile in pairs(self.tiles) do tile.shownLevel = nil end
	self:render()
end
return ShopUpgrades
