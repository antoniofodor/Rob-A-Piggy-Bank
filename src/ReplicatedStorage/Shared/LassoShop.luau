--!strict
--[[
	LassoShop -- the lassos on the client's shop and hot bar (docs/LASSO-PLAN.md).

	THREE SURFACES, ONE PUSH. `LassoStock` arrives on join and on change and
	carries the stock, THIS player's coin prices, their rebirths and the Elite
	product's state. From it this module paints the hot bar tiles, the Supplies
	tab's LASSOS shelf, and hands the Elite state to `PremiumShop`'s product
	card. Nothing here throws a lasso: the held-lasso click, the lock-on and
	the TAP bar belong to the world script, and `ClientMain`'s own click path
	declines a held lasso.

	EVERY ODDS FIGURE ON SCREEN IS `Config.lassoDescription` OR
	`Config.lassoChance`, never typed. For the Elite tier that is the paid
	random item rule rather than tidiness: its odds have to be real and shown
	before the purchase button.

	A MODULE because `ClientMain` is at Luau's 200-local ceiling: it pays one
	statement for `init` and borrows nothing but what it hands over.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)
local ShopStyle = require(ReplicatedStorage.Shared.ShopStyle)
local HotBar = require(ReplicatedStorage.Shared.HotBar)
local SupplyCards = require(ReplicatedStorage.Shared.SupplyCards)
local Widgets = require(ReplicatedStorage.Shared.ShopWidgets)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local LassoShop = {}

type Deps = {
	-- Draws a Model into a ViewportFrame (ClientMain's `makeModelIcon`).
	modelIcon: (GuiObject, Model, UDim2, UDim2, boolean) -> ViewportFrame,
	-- Asks the server to draw an item into the hand (`heldUI.equip`).
	equip: (string) -> (),
	-- The Supplies tab's own section header and card grid builders.
	header: (string, number) -> TextLabel,
	grid: (number) -> Frame,
	-- Where the Supplies cards register their UIScale (ClientMain's `cardFit`).
	cardFit: any?,
	coins: () -> number,
	format: (number) -> string,
	-- Opens the Robux tab, where the Elite card lives.
	openRobux: (() -> ())?,
	-- So a sign or a hint can scroll straight to this shelf.
	sections: any?,
	scroll: ScrollingFrame?,
	tab: number?,
}

local deps: Deps? = nil
local latest: any = nil
local slots: { [string]: { button: TextButton, label: TextLabel, hotkey: TextLabel } } = {}
local tiles: { [string]: any } = {}
local grid: Frame? = nil
local listeners: { (any) -> () } = {}
local pendingIcons: { { parent: GuiObject, key: string } } = {}

-- ============================================================
-- THE CATALOGUE AS THIS CLIENT READS IT
-- ============================================================

-- A lasso key that another consumable already owns is skipped with one
-- warning: slots, stock and the held item are all keyed by item, so a second
-- `golden` would take over the Golden Bone's tile and draw. `auditLassos`
-- refuses the collision at boot; this only stops the client compounding it.
local warned: { [string]: boolean } = {}
local function collides(key: string): boolean
	for _, other in ipairs({ Config.BONES, Config.GADGETS, Config.HOME_ITEMS, Config.THIEF_KIT }) do
		if other and other[key] then
			if not warned[key] then
				warned[key] = true
				warn(("[LassoShop] lasso key '%s' collides with another consumable; its tile and card are skipped"):format(key))
			end
			return true
		end
	end
	return false
end

-- Every lasso this client shows, in tier order.
function LassoShop.keys(): { string }
	local out = {}
	for key in pairs(Config.LASSOS or {}) do
		if not collides(key) then
			table.insert(out, key)
		end
	end
	table.sort(out, function(a, b)
		local oa, ob = Config.LASSOS[a].order or 99, Config.LASSOS[b].order or 99
		if oa ~= ob then return oa < ob end
		return a < b
	end)
	return out
end

-- The Robux tier. Derived from the one field that makes a tier a product,
-- so the card follows a rename rather than a typed key.
function LassoShop.eliteKey(): string?
	for _, key in ipairs(LassoShop.keys()) do
		if Config.LASSOS[key].robux then
			return key
		end
	end
	return nil
end

function LassoShop.stock(key: string): number
	local stock = latest and latest.stock
	return (stock and tonumber(stock[key])) or 0
end

-- Any lasso in stock, which is all `HotBar.shouldShow` needs to know.
function LassoShop.anyHeld(): boolean
	for _, key in ipairs(LassoShop.keys()) do
		if LassoShop.stock(key) > 0 then
			return true
		end
	end
	return false
end

-- The last push, for the Elite card. nil until the server has spoken.
function LassoShop.latest(): any
	return latest
end

-- Called with the push every time one lands, and at once if one has.
function LassoShop.listen(fn: (any) -> ())
	table.insert(listeners, fn)
	if latest then
		task.spawn(fn, latest)
	end
end

-- Rounded exactly as `Config.lassoDescription` rounds, so the card's one
-- figure and the description beside it cannot disagree by a point.
local function pct(x: number): number
	return math.floor(math.min(1, x) * 100 + 0.5)
end

-- The card's one big stat: the first-throw chance on a legendary, no taps to
-- full taps. The hardest catch is the number that separates the tiers.
local function legendaryLine(key: string): string
	local lo = pct(Config.lassoChance(key, "legendary", 0, 0))
	local hi = pct(Config.lassoChance(key, "legendary", math.huge, 0))
	return if lo == hi then ("Legendary %d%%"):format(lo) else ("Legendary %d-%d%%"):format(lo, hi)
end

-- ============================================================
-- THE ICON
-- ============================================================

-- The coil is the world agent's `Shared/LassoModel`, required inside a pcall
-- because it lands in parallel with this file; without it the card gets a
-- ring in the tier's own colours, which says "rope" and costs nothing.
local function coilModel(key: string): Model?
	local module = ReplicatedStorage.Shared:FindFirstChild("LassoModel")
	if not module then
		return nil
	end
	local ok, model = pcall(function()
		return (require(module :: ModuleScript) :: any).buildCoil(key)
	end)
	if ok and typeof(model) == "Instance" and model:IsA("Model") then
		return model
	end
	return nil
end

local function fallbackIcon(parent: GuiObject, key: string)
	local spec = Config.LASSOS[key] or {}
	local ring = Instance.new("Frame")
	ring.Name = "LassoRing"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(0.62, 0.62)
	ring.BackgroundTransparency = 1
	ring.Parent = parent
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = ring
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = ring
	local rope = Instance.new("UIStroke")
	rope.Thickness = 7
	rope.Color = spec.colour or Theme.GOLD
	rope.Parent = ring
	local grip = Instance.new("Frame")
	grip.Name = "Grip"
	grip.AnchorPoint = Vector2.new(0.5, 0.5)
	grip.Position = UDim2.fromScale(0.5, 0)
	grip.Size = UDim2.fromScale(0.34, 0.2)
	grip.BackgroundColor3 = spec.trim or Theme.INK
	grip.BorderSizePixel = 0
	grip.Parent = ring
	local gripCorner = Instance.new("UICorner")
	gripCorner.CornerRadius = UDim.new(0, 4)
	gripCorner.Parent = grip
end

local function drawIcon(parent: GuiObject, key: string, size: UDim2, position: UDim2)
	local d = deps
	local model = coilModel(key)
	if d and model then
		d.modelIcon(parent, SupplyCards.sideOn(model), size, position, false)
	else
		if model then
			model:Destroy()
		end
		fallbackIcon(parent, key)
	end
end

-- For `PremiumShop`, which has no `makeModelIcon` of its own. Queued if it is
-- asked before `init` hands one over, so the order two modules start in can
-- never leave an empty well.
function LassoShop.icon(parent: GuiObject, key: string)
	if deps then
		drawIcon(parent, key, UDim2.fromScale(1, 1), UDim2.new())
	else
		table.insert(pendingIcons, { parent = parent, key = key })
	end
end

-- ============================================================
-- THE HOT BAR TILE
-- ============================================================
--
-- The same tile the bones, gadgets and home items build in ClientMain, and
-- the same rule: a tap SELECTS, never spends. The throw is the world
-- script's click on a held lasso.
local function ensureSlot(key: string): any
	local existing = slots[key]
	if existing then
		return existing
	end
	local d = deps :: Deps
	local spec = Config.LASSOS[key]

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 58, 1, 0)
	button.BackgroundColor3 = Theme.PAPER
	button.BackgroundTransparency = 0.15
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.FredokaOne
	button.Text = ""
	-- After the throwables (bones 1.., gadgets 10+, home 20+, kit 30+).
	HotBar.register(button, key, 40 + (spec.order or 9), spec.name)
	Theme.corner(button, 10)
	drawIcon(button, key, UDim2.new(1, -6, 1, -6), UDim2.new(0, 3, 0, 3))

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -6, 0, 18)
	label.Position = UDim2.new(0, 3, 1, -20)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.TextColor3 = Theme.INK
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Theme.INK
	label.Text = ""
	label.Parent = button

	local hotkey = Instance.new("TextLabel")
	hotkey.Size = UDim2.new(0, 22, 0, 14)
	hotkey.Position = UDim2.new(0, 3, 0, 2)
	hotkey.BackgroundTransparency = 1
	hotkey.Font = Enum.Font.GothamBold
	hotkey.TextScaled = true
	hotkey.TextXAlignment = Enum.TextXAlignment.Left
	hotkey.TextColor3 = Theme.COOL_INK
	hotkey.TextStrokeTransparency = 0.3
	hotkey.TextStrokeColor3 = Theme.INK
	hotkey.Text = ""
	hotkey.Parent = button

	button.Activated:Connect(function()
		if HotBar.suppress() then
			return
		end
		d.equip(key)
	end)

	HotBar.styleSlot(button, label, hotkey)
	local entry = { button = button, label = label, hotkey = hotkey }
	slots[key] = entry
	return entry
end

-- ============================================================
-- THE SUPPLIES SHELF
-- ============================================================

-- A supply's tier is its rung, the Supplies tab's own rule (see
-- `SupplyCards.tierOf`); a lasso states its rung as `tier`, so it is read
-- rather than re-derived from a price that is a function of the buyer.
local function tierOf(key: string): string
	local rung = (Config.LASSOS[key] and Config.LASSOS[key].tier) or 1
	return Config.RARITY_ORDER[math.clamp(rung, 1, #Config.RARITY_ORDER)] or "common"
end

local function ensureTile(key: string): any
	local existing = tiles[key]
	if existing then
		return existing
	end
	local d = deps :: Deps
	local spec = Config.LASSOS[key]
	local entry: any = SupplyCards.card(grid :: Frame, spec.order or 99, spec.name, tierOf(key))
	if d.cardFit and d.cardFit.cards then
		local cardScale = Instance.new("UIScale")
		cardScale.Scale = d.cardFit.scale or 1
		cardScale.Parent = entry.button
		table.insert(d.cardFit.cards, cardScale)
	end
	drawIcon(entry.well, key, UDim2.new(1, 0, 1, 0), UDim2.new())
	-- THE ELITE CARD IS A SIGNPOST TO THE ROBUX TAB, NOT A SECOND PURCHASE.
	-- The summary's BUY is a coin purchase and cannot be relabelled, and a
	-- second Robux prompt here would be a second renderer of a paid random
	-- item's disclosure; the Robux card shows the odds before its button.
	-- `entry.spec` stays nil, so SupplyCards' own tap does nothing and this
	-- one opens the tab.
	if spec.robux then
		entry.button.Activated:Connect(function()
			if d.openRobux then
				d.openRobux()
			end
		end)
	end
	tiles[key] = entry
	return entry
end

local function paintTile(key: string)
	local d = deps :: Deps
	local spec = Config.LASSOS[key]
	local tile = ensureTile(key)
	tile.title.Text = spec.name
	tile.stat.Text = legendaryLine(key)
	if spec.robux then
		tile.price.Text = "ROBUX SHOP"
		tile.button.BackgroundColor3 = ShopStyle.BUY
		tile.button.LayoutOrder = Widgets.gateRank({ order = spec.order })
		return
	end

	local gate = spec.rebirths or 0
	local rebirths = (latest and tonumber(latest.rebirths)) or 0
	local locked = gate > rebirths
	-- THE LOCK IS THE SHOP'S ONE TREATMENT (`ShopWidgets.gate`): shown, not
	-- hidden, with the price raised above the wash and the card ordered by
	-- its gate. A tap still opens the summary and BUY still asks, and the
	-- server names the rebirth -- the same call a locked house card makes.
	Widgets.gate({ button = tile.button, sub = tile.price },
		{ unlockRebirths = gate, order = spec.order, locked = locked })

	local price = latest and latest.prices and tonumber(latest.prices[key])
	tile.price.Text = if price then d.format(price) else "..."
	tile.button.BackgroundColor3 = if price and not locked and d.coins() >= price
		then ShopStyle.BUY
		else ShopStyle.CARD

	local stats = { { label = "You have", value = tostring(LassoShop.stock(key)) } }
	if gate > 0 then
		table.insert(stats, { label = "Unlocks at", value = ("Rebirth %d"):format(gate) })
	end
	tile.spec = if price
		then {
			name = spec.name,
			-- VERBATIM. The odds are generated, never typed (docs/LASSO-PLAN.md 2).
			about = Config.lassoDescription(key),
			stats = stats,
			cost = price,
			price = d.format(price),
			onBuy = function()
				Remotes.get("LassoBuy"):FireServer(key, 1)
			end,
		}
		else nil
end

-- ============================================================
-- PAINT
-- ============================================================

-- Safe to call before `init` and before the first push: both are no-ops, so
-- ClientMain can call it from its coin render without knowing either.
function LassoShop.render()
	if not deps then
		return
	end
	for _, key in ipairs(LassoShop.keys()) do
		if grid then
			paintTile(key)
		end
		local slot = ensureSlot(key)
		local held = LassoShop.stock(key)
		HotBar.setHeld(key, held > 0)
		slot.label.Text = tostring(held)
		local hot = HotBar.keyFor(key)
		slot.hotkey.Text = if hot then hot.label else ""
	end
	SupplyCards.refresh()
	HotBar.refresh()
end

-- THE ELITE PURCHASE, declining to ask for a known no exactly as the crate
-- tile does: a product id of 0 throws, and a player the paid random item
-- rule restricts must never meet the prompt. Returns what it did, so the
-- card can say it.
function LassoShop.promptElite(): string
	local elite = latest and latest.elite
	if not elite then
		return "waiting"
	end
	if elite.allowed ~= true then
		return "restricted"
	end
	local id = tonumber(elite.productId) or 0
	if id <= 0 then
		return "soon"
	end
	MarketplaceService:PromptProductPurchase(Players.LocalPlayer, id)
	return "prompted"
end

function LassoShop.init(d: Deps)
	deps = d
	-- The shelf: after AT HOME (200s), before CALL THE PATROL (400s), in the
	-- Supplies tab's blocks of a hundred.
	local head = d.header("CATCH WILD PIGGIES", 300)
	grid = d.grid(301)
	if d.sections then
		d.sections.lassos = { at = head, scroll = d.scroll, tab = d.tab }
	end
	for _, pending in ipairs(pendingIcons) do
		if pending.parent.Parent then
			drawIcon(pending.parent, pending.key, UDim2.fromScale(1, 1), UDim2.new())
		end
	end
	table.clear(pendingIcons)

	-- Spawned, because `Remotes.get` waits for the instance and ClientMain
	-- must never stall on a feature landing a beat late.
	task.spawn(function()
		Remotes.get("LassoStock").OnClientEvent:Connect(function(payload)
			if type(payload) ~= "table" then
				return
			end
			latest = payload
			LassoShop.render()
			for _, fn in ipairs(listeners) do
				task.spawn(fn, payload)
			end
		end)
	end)
	LassoShop.render()
end

return LassoShop
