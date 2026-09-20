--!strict
--[[
	SupplyCards -- the Supplies tab's card and the summary that comes up before
	anything is bought.

	ONE CARD FOR BONES, GADGETS AND HOME ITEMS. They were four near-identical
	builders in ClientMain, each with its own idea of where the count went and
	how big the price was, which is how the tab came to read as muddled. A
	card here is a picture, a name, ONE big stat and ONE big price. There is no
	held count on it: the hot bar already shows how many you carry, and the
	number on the card never meant the same thing twice.

	A TAP OPENS A SUMMARY, IT NEVER SPENDS. The explainers used to live behind
	one "?" per section, so a player had to know to press a chip beside a
	header to learn that a throw can miss or that a treat does not stop a
	Golden Bone. Each item now carries its own card with what it does and its
	numbers, and the BUY on that card is the only thing here that fires a
	purchase -- which is also the mistap guard a stray thumb on a tablet needs.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local ShopStyle = require(ReplicatedStorage.Shared.ShopStyle)

local SupplyCards = {}

export type Stat = { label: string, value: string }
export type Spec = {
	name: string,
	about: string,
	stats: { Stat },
	cost: number,
	price: string,
	onBuy: () -> (),
}
export type Entry = {
	button: TextButton,
	well: Frame,
	title: TextLabel,
	stat: TextLabel,
	price: TextLabel,
	spec: Spec?,
}

local function label(parent: Instance, name: string, size: number, font: Enum.Font?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = font or Enum.Font.FredokaOne
	l.TextSize = size
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Text = ""
	l.Parent = parent
	ShopStyle.popText(l)
	return l
end

-- ============================================================
-- THE POPUP
-- ============================================================

local popup: {
	root: Frame,
	icon: Frame,
	name: TextLabel,
	about: TextLabel,
	stats: Frame,
	price: TextLabel,
	buy: TextButton,
}? = nil
local current: Spec? = nil
local coins: () -> number = function() return 0 end
local format: (number) -> string = tostring

local function close()
	if popup then
		popup.root.Visible = false
	end
	current = nil
end
SupplyCards.close = close

local function paintBuy()
	if not popup or not current then
		return
	end
	local short = current.cost - coins()
	if short > 0 then
		popup.buy.Text = "NEED " .. format(short) .. " MORE"
		popup.buy.BackgroundColor3 = ShopStyle.DEAR
		popup.buy.AutoButtonColor = false
	else
		popup.buy.Text = "BUY"
		popup.buy.BackgroundColor3 = Theme.GOOD
		popup.buy.AutoButtonColor = true
	end
end
SupplyCards.refresh = paintBuy

-- `host` is the shop panel; the popup covers it and nothing else, so the HUD
-- around the shop is untouched and closing the shop closes this with it.
function SupplyCards.setup(host: GuiObject, getCoins: () -> number, fmt: (number) -> string)
	coins, format = getCoins, fmt

	local root = Instance.new("Frame")
	root.Name = "SupplySummary"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.ZIndex = 60
	root.Visible = false
	root.Parent = host

	-- The dimmer is a button so a tap anywhere off the card is "not now".
	local dim = Instance.new("TextButton")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = Theme.INK
	dim.BackgroundTransparency = 0.45
	dim.AutoButtonColor = false
	dim.Text = ""
	dim.Parent = root
	ShopStyle.round(dim, 22)
	dim.Activated:Connect(close)

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(560, 330)
	card.BackgroundColor3 = Theme.PAPER
	card.BorderSizePixel = 0
	card.Parent = root
	ShopStyle.round(card, 20)
	ShopStyle.outline(card, 4)
	ShopStyle.gloss(card, 0.1)
	-- Shrinks on a short screen rather than running off it.
	local scale = Instance.new("UIScale")
	scale.Parent = card
	local function fit()
		local s = host.AbsoluteSize
		scale.Scale = math.min(1, (s.X - 24) / 560, (s.Y - 24) / 330)
	end
	host:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()

	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.Position = UDim2.fromOffset(18, 18)
	icon.Size = UDim2.fromOffset(190, 190)
	icon.BackgroundColor3 = ShopStyle.SUNK
	icon.BorderSizePixel = 0
	icon.ClipsDescendants = true
	icon.Parent = card
	ShopStyle.round(icon, 16)
	ShopStyle.outline(icon, 3)

	local name = label(card, "Name", 30)
	name.Position = UDim2.fromOffset(224, 16)
	name.Size = UDim2.new(1, -290, 0, 38)

	local about = label(card, "About", 17, Enum.Font.GothamBold)
	about.Position = UDim2.fromOffset(224, 58)
	about.Size = UDim2.new(1, -242, 0, 150)
	about.TextWrapped = true
	about.TextTruncate = Enum.TextTruncate.None
	about.TextYAlignment = Enum.TextYAlignment.Top

	local stats = Instance.new("Frame")
	stats.Name = "Stats"
	stats.Position = UDim2.fromOffset(18, 222)
	stats.Size = UDim2.new(1, -36, 0, 40)
	stats.BackgroundTransparency = 1
	stats.Parent = card
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.Padding = UDim.new(0, 10)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = stats

	local price = Instance.new("TextLabel")
	price.Name = "Price"
	price.Position = UDim2.fromOffset(18, 274)
	price.Size = UDim2.fromOffset(250, 42)
	price.BackgroundColor3 = ShopStyle.SUNK
	price.BorderSizePixel = 0
	price.Font = Enum.Font.FredokaOne
	price.TextSize = 26
	price.Text = ""
	price.Parent = card
	ShopStyle.round(price, 999)
	ShopStyle.outline(price, 3)
	ShopStyle.popText(price)

	local buy = Instance.new("TextButton")
	buy.Name = "Buy"
	buy.AnchorPoint = Vector2.new(1, 0)
	buy.Position = UDim2.new(1, -18, 0, 274)
	buy.Size = UDim2.fromOffset(260, 42)
	buy.BackgroundColor3 = Theme.GOOD
	buy.BorderSizePixel = 0
	buy.Font = Enum.Font.FredokaOne
	buy.TextSize = 24
	buy.Text = "BUY"
	buy.Parent = card
	ShopStyle.round(buy, 999)
	ShopStyle.outline(buy, 3)
	ShopStyle.gloss(buy)
	ShopStyle.popText(buy)
	buy.Activated:Connect(function()
		local spec = current
		if not spec or spec.cost > coins() then
			return
		end
		spec.onBuy()
		close()
	end)

	local x = Instance.new("TextButton")
	x.Name = "Close"
	x.AnchorPoint = Vector2.new(1, 0)
	x.Position = UDim2.new(1, -14, 0, 14)
	x.Size = UDim2.fromOffset(44, 44)
	x.BackgroundColor3 = Theme.STOP
	x.BorderSizePixel = 0
	x.Font = Enum.Font.FredokaOne
	x.TextSize = 26
	x.Text = utf8.char(0x00D7)
	x.Parent = card
	ShopStyle.round(x, 12)
	ShopStyle.outline(x, 3)
	ShopStyle.popText(x)
	x.Activated:Connect(close)

	popup = { root = root, icon = icon, name = name, about = about, stats = stats, price = price, buy = buy }
	host:GetPropertyChangedSignal("Visible"):Connect(function()
		if not host.Visible then
			close()
		end
	end)
end

local function statChip(parent: Instance, order: number, stat: Stat)
	local chip = Instance.new("Frame")
	chip.Name = "Stat"
	chip.LayoutOrder = order
	chip.Size = UDim2.fromOffset(0, 40)
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.BackgroundColor3 = Theme.SAND
	chip.BorderSizePixel = 0
	chip.Parent = parent
	ShopStyle.round(chip, 12)
	ShopStyle.outline(chip, 2)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = chip
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = chip
	local k = label(chip, "Label", 15, Enum.Font.GothamBold)
	k.AutomaticSize = Enum.AutomaticSize.X
	k.Size = UDim2.fromOffset(0, 40)
	k.TextTruncate = Enum.TextTruncate.None
	k.Text = stat.label
	local v = label(chip, "Value", 22)
	v.LayoutOrder = 1
	v.AutomaticSize = Enum.AutomaticSize.X
	v.Size = UDim2.fromOffset(0, 40)
	v.TextTruncate = Enum.TextTruncate.None
	v.Text = stat.value
end

-- `well` is the card's own picture, cloned rather than rebuilt: a ViewportFrame
-- clone keeps its camera, so the summary shows exactly the icon the card does.
function SupplyCards.open(spec: Spec, well: GuiObject?)
	local p = popup
	if not p then
		return
	end
	current = spec
	for _, c in ipairs(p.icon:GetChildren()) do
		if not c:IsA("UICorner") and not c:IsA("UIStroke") then
			c:Destroy()
		end
	end
	if well then
		for _, c in ipairs(well:GetChildren()) do
			if c:IsA("GuiObject") then
				local copy = c:Clone()
				copy.Size = UDim2.fromScale(1, 1)
				copy.Position = UDim2.new()
				copy.Parent = p.icon
			end
		end
	end
	p.name.Text = spec.name
	p.about.Text = spec.about
	for _, c in ipairs(p.stats:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	for i, stat in ipairs(spec.stats) do
		statChip(p.stats, i, stat)
	end
	p.price.Text = spec.price
	paintBuy()
	p.root.Visible = true
end

-- ============================================================
-- THE CARD
-- ============================================================

-- Built to the grid's default 156x182 cell; `ShopCatalogueLayout.bindCard`
-- moves the rows for a compact screen.
-- A SUPPLY HAS NO RARITY, SO ITS TIER IS ITS RUNG IN ITS OWN LADDER. Every
-- group here is a cheap / middling / expensive set -- a Dog Bone, a Steak, a
-- Golden Bone -- and the rule the whole kit is built on is that cheap counters
-- bounce and the expensive one gets through. Colouring by that rung says so at
-- a glance. The global price bands would call all eight of them common, which
-- is true about the economy and useless on a shelf. Derived from `cost`, so a
-- repriced or added item re-ranks itself.
function SupplyCards.tierOf(catalogue: { [string]: any }?, key: string): string
	if not catalogue or not catalogue[key] then return "common" end
	local keys = {}
	for k, spec in pairs(catalogue) do
		if type(spec) == "table" and type(spec.cost) == "number" then table.insert(keys, k) end
	end
	table.sort(keys, function(a, b)
		local ca, cb = catalogue[a].cost, catalogue[b].cost
		if ca ~= cb then return ca < cb end
		return a < b
	end)
	local n, rank = #keys, table.find(keys, key) or 1
	if n <= 1 then return "rare" end
	if n == 2 then return if rank == 1 then "rare" else "epic" end
	if rank == 1 then return "common" end
	if rank == n then return "legendary" end
	return if rank * 2 <= n then "rare" else "epic"
end

function SupplyCards.card(parent: Instance, order: number, name: string, tier: string?): Entry
	local button = Instance.new("TextButton")
	button.Name = "Supply_" .. name:gsub("[^%w]", "")
	button.LayoutOrder = order
	button.BackgroundColor3 = ShopStyle.CARD
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Text = ""
	button.Parent = parent
	ShopStyle.round(button, 16)
	ShopStyle.outline(button, 3)
	ShopStyle.gloss(button)

	local well = ShopStyle.well(button)
	well.Size = UDim2.new(1, -16, 0, 92)

	local title = label(button, "Title", 20)
	title.Position = UDim2.fromOffset(8, 102)
	title.Size = UDim2.new(1, -16, 0, 24)
	title.Text = name

	local stat = label(button, "Stat", 18)
	stat.Position = UDim2.fromOffset(8, 126)
	stat.Size = UDim2.new(1, -16, 0, 22)

	local price = Instance.new("TextLabel")
	price.Name = "Price"
	price.Position = UDim2.fromOffset(8, 149)
	price.Size = UDim2.new(1, -16, 0, 28)
	price.Text = ""
	price.Parent = button
	ShopStyle.priceRow(price)
	price.TextSize = 22
	ShopStyle.popText(price)

	-- THE WHOLE CARD WEARS ITS TIER, the same dressing the crate and bag
	-- cards use. That covers the background tint the tab used to say "you can
	-- afford this" with, so the renders' BUY/CARD write is read here instead
	-- and moved onto the price: full strength when affordable, faded when not.
	if tier then
		require(ReplicatedStorage.Shared.ShopSkinCards).dressCard(button, tier, { well })
		local function affordable()
			price.TextTransparency = if button.BackgroundColor3 == ShopStyle.BUY then 0 else 0.45
		end
		button:GetPropertyChangedSignal("BackgroundColor3"):Connect(affordable)
		affordable()
	end

	local entry: Entry = { button = button, well = well, title = title, stat = stat, price = price, spec = nil }
	button.Activated:Connect(function()
		if entry.spec then
			SupplyCards.open(entry.spec, well)
		end
	end)
	return entry
end

-- ============================================================
-- WHAT EACH ONE DOES
-- ============================================================
--
-- The words that used to sit behind each section's "?", split per item. Kept
-- here rather than in Config because they are shop copy about how to USE the
-- thing, and Config's `blurb` is the one line both ends already share.
local HOW = {
	bone = "Hold it from the bar and click near a dog: it naps in its kennel. Bigger dogs resist.",
	gadget = "Aim it. The throw drops as it flies, so lead anyone running and aim high for anyone far away. "
		.. "The same person cannot be hit twice in a row.",
	-- THE ZAPPER IS NOT THROWN (`GadgetService.zap`): it fires the instant it
	-- is used, straight along your aim, and hits the first person on the line
	-- inside its short range. The throwing advice above would be wrong for it.
	zapper = "Point it and use it: the arc fires straight along your aim the instant you press, and hits "
		.. "the first person on the line. No lob, no lead. The same person cannot be hit twice in a row.",
	treat = "Use it before you go out. Its collar glows so robbers can see your guard is on duty.",
	radio = "You do not choose who they chase: whoever robs somebody, or the name on the MOST WANTED board. "
		.. "The next patrol still comes as normal.",
}

function SupplyCards.about(kind: string, blurb: string?, detail: string?): string
	local parts = {}
	if blurb and blurb ~= "" then
		table.insert(parts, (blurb:gsub("[%.%s]+$", "")) .. ".")
	end
	if detail and detail ~= "" then
		table.insert(parts, detail)
	end
	if HOW[kind] then
		table.insert(parts, HOW[kind])
	end
	return table.concat(parts, " ")
end

-- TURNS A MODEL SO ITS LONG SIDE FACES THE CAMERA. The icon camera looks
-- mostly down Z, and a bone is authored lying along Z -- so the Dog Bone and
-- the Juicy Steak were drawn END-ON, a white stub nobody could name. Measured
-- per part in world space rather than off `GetBoundingBox`, which follows the
-- model's pivot and transposes extents (see CLAUDE.md).
function SupplyCards.sideOn(model: Model): Model
	local lo, hi = Vector3.one * math.huge, Vector3.one * -math.huge
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			local cf, h = p.CFrame, p.Size / 2
			local e = Vector3.new(
				math.abs(cf.RightVector.X) * h.X + math.abs(cf.UpVector.X) * h.Y + math.abs(cf.LookVector.X) * h.Z,
				0,
				math.abs(cf.RightVector.Z) * h.X + math.abs(cf.UpVector.Z) * h.Y + math.abs(cf.LookVector.Z) * h.Z)
			lo = lo:Min(p.Position - e)
			hi = hi:Max(p.Position + e)
		end
	end
	local span = hi - lo
	if span.Z > span.X * 1.2 then
		-- About WORLD up, so a pivot that carries its own turn cannot tip it.
		local pivot = model:GetPivot()
		model:PivotTo(CFrame.new(pivot.Position) * CFrame.Angles(0, math.pi / 2, 0)
			* CFrame.new(-pivot.Position) * pivot)
	end
	return model
end

-- "1.5s" rather than "1.50s", and "6 min" once it is a whole number of them.
function SupplyCards.seconds(s: number): string
	if s >= 60 and s % 60 == 0 then
		return ("%d min"):format(s / 60)
	end
	if s == math.floor(s) then
		return ("%ds"):format(s)
	end
	return ("%.1fs"):format(s)
end

return SupplyCards
