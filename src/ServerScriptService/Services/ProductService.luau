--!strict
--[[
	ProductService

	The one place a DEVELOPER PRODUCT is bought, and the one place Roblox's
	paid-random-item policy is asked.

	WHY THIS FILE EXISTS AT ALL, WHICH IS A RULE REVERSAL AND IS SAID FIRST.

	Every crate in this game was EARNED and none carried a price, and the
	header on `Config.CHESTS` spends a paragraph on what a price field would
	cost: a direct Robux-to-crate purchase puts the whole catalogue INSIDE
	Roblox's paid random item rule. The designer shipped that purchase
	(2026-09-23), so the machinery that rule demands has to exist, and this is
	it. Nothing else about the coins position moved: COINS ARE STILL NOT
	PURCHASABLE WITH ROBUX AT ANY PRICE, which is what keeps the daily ladder,
	the rebirth grant and everything else outside the rule.

	WHAT THE RULE ACTUALLY DEMANDS, AND WHERE EACH HALF LIVES.

	  * REAL ODDS, DISCLOSED BEFORE PURCHASE, SUMMING TO 100%. That is the
	    `Shared/Crates` tile: it draws the server's own `liveOdds` -- already
	    renormalised over the tiers that have stock -- to scale, prints the
	    top tier's exact percentage, and the `?` opens the full per-tier
	    breakdown. Disclosure is a UI obligation and is not this file's job;
	    what IS this file's job is refusing to fulfil a receipt for a crate
	    that could not honestly have been sold.

	  * A `PolicyService` GATE. `ArePaidRandomItemsRestricted` is true for a
	    growing list of players -- UK under-18, Australia, Belgium -- and for
	    an under-12 audience that is a large share of them. A restricted
	    player must never be PROMPTED and must never meet a button that does
	    nothing: `ChestState.restricted` carries the answer to the client, the
	    card says why, and this file refuses a receipt from one as a backstop.

	A FAILED POLICY LOOKUP IS **RESTRICTED**, WHICH INVERTS `PassService`.

	That file's rule is that a failed `UserOwnsGamePassAsync` is NOT a "no",
	because writing false on a network blip takes a paid feature away from
	somebody who owns it. This is the opposite question. Here the answer
	decides whether a REGULATED purchase may be offered, so the failure that
	matters is offering one to somebody the rule protects -- and the cost of
	being wrong the other way is a card that reads "not available here" for a
	session. Fail closed, and retry on the next ask rather than caching the
	failure.

	A RECEIPT IS IDEMPOTENT, AND IT IS RECORDED **BEFORE** THE CRATE OPENS.

	`ProcessReceipt` is re-delivered until it returns `PurchaseGranted`, so
	the same `PurchaseId` can arrive twice -- on a retry, or on the next join.
	`data.receipts` remembers the ids this player has been paid out for. The
	order is the one `DailyService.openCrate` already chose and for the same
	reason: record, SAVE, then roll. A disconnect inside that window hands out
	NOTHING rather than handing out two crates, which is the side this project
	has picked once already.

	`data.receipts` IS CREATED LAZILY AND NEEDS NO SCHEMA BUMP, the same free
	ride `data.claims` takes in `ChestService.buyback`: `DataService.save`
	writes the whole table and `reconcile`'s generic fill only ADDS missing
	keys, so a field this file invents survives a rejoin. It is a LIST capped
	at `RECEIPT_MEMORY`, because a map keyed by purchase id grows for the life
	of an account and nothing would ever prune it.

	NO CYCLE, AND DELIBERATELY NO REQUIRE OF `ChestService`. This file
	requires Config and DataService and nothing else; `ChestService` requires
	IT, registers what to do with a receipt, and calls `start`. The opposite
	direction would be a cycle the day anything here wanted to push a balance.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local ProductService = {}

-- How many purchase ids a save remembers. Roblox re-delivers only receipts
-- that have never returned `PurchaseGranted`, so the window this guards is
-- short -- a lost return, or a disconnect mid-fulfilment. Fifty is several
-- weeks of a heavy buyer and costs a save nothing.
local RECEIPT_MEMORY = 50

-- [Player] = MAY BE OFFERED A PAID RANDOM ITEM. Absent means "not asked yet,
-- or the ask failed", and `restricted` reads anything that is not an explicit
-- TRUE as restricted. See the header for why that is the opposite default
-- from `PassService`.
--
-- STORED AS PERMISSION RATHER THAN AS THE POLICY FIELD'S OWN SENSE, because
-- three-valued logic over a negative reads backwards at every site: `not
-- allowed` is obvious and `restricted ~= false` is a puzzle. The one place the
-- sense is flipped is where the field is read.
local allowed: { [Player]: boolean } = {}

-- Filled in by `ChestService`: what to do with a paid crate, and who to tell
-- when the policy answer lands. A registry rather than a require, for the
-- reason `SetService.registerPusher` is one -- it keeps this file's dependency
-- list at two and makes a cycle impossible rather than merely absent today.
local onCrate: ((Player, string) -> boolean)? = nil
local policyPushers: { (Player) -> () } = {}
-- Filled in by `LassoService`: what to do with a paid lasso pack. The same
-- registry shape as the crate one, for the same reason.
local onLasso: ((Player, string) -> boolean)? = nil

function ProductService.onCrateReceipt(fn: (Player, string) -> boolean)
	onCrate = fn
end

function ProductService.onLassoReceipt(fn: (Player, string) -> boolean)
	onLasso = fn
end

function ProductService.onPolicy(fn: (Player) -> ())
	table.insert(policyPushers, fn)
end

-- ============================================================
-- THE POLICY GATE
-- ============================================================

-- Whether this player may be offered a paid random item at all.
--
-- Fails closed. An absent entry is a player who has not been asked yet or
-- whose ask threw, and both of those are "do not offer" -- see the header.
function ProductService.restricted(player: Player): boolean
	return allowed[player] ~= true
end

-- Asked ONCE per session. Memoised rather than re-asked, for the reason
-- `PassService` caches ownership: this is read by every `ChestState` push and
-- by every receipt, and a web round trip inside a HUD push is not a thing to
-- ship. A failure leaves the entry absent, so the next ask retries.
function ProductService.askPolicy(player: Player)
	if allowed[player] ~= nil then
		return
	end
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	if not ok or type(info) ~= "table" then
		warn(("[ProductService] could not read the paid-random-item policy for %s: %s")
			:format(player.Name, tostring(info)))
		return
	end
	-- READ AS A STRICT `== false`, so a field Roblox ever renames or stops
	-- sending reads as RESTRICTED rather than as permission. A nil here would
	-- otherwise be the quietest possible way to start selling a regulated
	-- product to the players the rule exists to protect.
	allowed[player] = info.ArePaidRandomItemsRestricted == false
	for _, fn in ipairs(policyPushers) do
		local pushed, err = pcall(fn, player)
		if not pushed then
			warn("[ProductService] policy push: " .. tostring(err))
		end
	end
end

function ProductService.onPlayerReady(player: Player)
	task.spawn(ProductService.askPolicy, player)
end

-- ============================================================
-- WHICH PRODUCT IS WHICH CRATE
-- ============================================================

-- ON THE CRATE'S OWN ROW, WHICH IS THE SHAPE `Config.PASSES` ALREADY USES.
--
-- `robux` is what the card prints -- display only, exactly as a pass's is:
-- Roblox owns the real price and there is no API that makes this
-- authoritative, so the two are kept in step BY HAND. `productId` is the
-- developer product that opens it, and 0 means one does not exist yet.
--
-- A TIER LADDER WAS THE OTHER SHAPE AND THE ROW WON. Pricing off
-- `chest.tier` is one table instead of eight numbers and it cannot answer a
-- crate whose pool is a different depth -- the Guardian Crate is common-tier
-- over ten coats and is priced 49 rather than the skin shelves' 20. What the
-- ladder was FOR survives as a property the suite asserts on the rows
-- themselves: 1 : 3 : 12 across a shelf's three rungs.
--
-- NIL-SAFE, AND THE `or 0` DOES REAL WORK. Until the rows carry a price every
-- crate reads as unpriced, so the card says EARN THIS CRATE, nothing prompts,
-- and the game degrades to the earned-only catalogue it was rather than
-- throwing -- which is what lets the Config edit and this one land in either
-- order.
function ProductService.crateRobux(chestKey: string): number
	local chest = Config.CHESTS[chestKey]
	local price = chest and (chest :: any).robux
	return if type(price) == "number" and price > 0 then price else 0
end

function ProductService.crateProduct(chestKey: string): number
	local chest = Config.CHESTS[chestKey]
	local id = chest and (chest :: any).productId
	return if type(id) == "number" and id > 0 then id else 0
end

-- Walked rather than cached, because a receipt arrives about once a minute at
-- the very most and a cache is one more thing that can be stale.
function ProductService.crateOfProduct(productId: number): string?
	if type(productId) ~= "number" or productId <= 0 then
		return nil
	end
	for key in pairs(Config.CHESTS) do
		if ProductService.crateProduct(key) == productId then
			return key
		end
	end
	return nil
end

-- WHICH PRODUCT IS WHICH LASSO. The Elite tier is a paid random item for the
-- same reason a crate is -- Robux buys a CHANCE at a catch -- so it rides the
-- same ledger and the same policy gate. `productId` 0 is "not created yet"
-- and never matches a receipt.
function ProductService.lassoProduct(key: string): number
	local spec = (Config :: any).LASSOS and (Config :: any).LASSOS[key]
	local id = spec and spec.robux and spec.productId
	return if type(id) == "number" and id > 0 then id else 0
end

function ProductService.lassoOfProduct(productId: number): string?
	if type(productId) ~= "number" or productId <= 0 then
		return nil
	end
	for key in pairs((Config :: any).LASSOS or {}) do
		if ProductService.lassoProduct(key) == productId then
			return key
		end
	end
	return nil
end

-- ============================================================
-- RECEIPTS
-- ============================================================

local function receiptsOf(data: any): { string }
	if type(data.receipts) ~= "table" then
		data.receipts = {}
	end
	return data.receipts
end

-- The fulfilment, split out so the shape is readable: returns the decision.
local function fulfil(info: any): Enum.ProductPurchaseDecision
	local granted = Enum.ProductPurchaseDecision.PurchaseGranted
	local pending = Enum.ProductPurchaseDecision.NotProcessedYet

	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not player then
		-- They have left. Roblox re-delivers on their next join, which is the
		-- whole reason this decision exists.
		return pending
	end
	local data = DataService.get(player)
	if not data then
		return pending
	end

	local id = tostring(info.PurchaseId)
	local receipts = receiptsOf(data)
	if table.find(receipts, id) then
		-- ALREADY PAID OUT. Granted rather than pending, or Roblox re-delivers
		-- this receipt forever.
		return granted
	end

	local chestKey = ProductService.crateOfProduct(info.ProductId)
	local lassoKey = if chestKey then nil else ProductService.lassoOfProduct(info.ProductId)
	local handler = if chestKey then onCrate elseif lassoKey then onLasso else nil
	if not handler then
		-- A product this build does not know about. Left PENDING rather than
		-- granted: a newer server may know it, and swallowing the receipt is
		-- the one outcome here that loses somebody's money.
		warn(("[ProductService] no crate for product %s"):format(tostring(info.ProductId)))
		return pending
	end
	-- A RESTRICTED PLAYER'S RECEIPT IS NEVER GRANTED, CRATE OR LASSO. They are
	-- never prompted (the card refuses first), so a receipt from one is a policy
	-- that changed under them, a purchase from outside the game, or a client
	-- that called `PromptProductPurchase` itself -- and a crate is exactly the
	-- paid random item the rule forbids selling them. This was the header's
	-- "backstop" and for a while it guarded only lassos: `ChestService.openPaid`
	-- is a bare roll with no policy check of its own, so the crates -- the
	-- product the rule is actually about -- had no backstop at all. Pending,
	-- and said, because a product that takes the money and says nothing is the
	-- worst outcome here.
	if (chestKey or lassoKey) and ProductService.restricted(player) then
		warn(("[ProductService] refused a %s receipt from %s: paid random items are restricted for them")
			:format(tostring(chestKey or lassoKey), player.Name))
		return pending
	end

	-- RECORDED AND SAVED BEFORE THE CRATE OPENS. See the header: a disconnect
	-- inside this window hands out nothing rather than twice.
	table.insert(receipts, id)
	while #receipts > RECEIPT_MEMORY do
		table.remove(receipts, 1)
	end
	if not DataService.save(player) then
		-- The write did not land, so nothing may be handed over: the receipt
		-- comes back and is fulfilled then.
		table.remove(receipts, table.find(receipts, id) :: number)
		return pending
	end

	local ok, opened = pcall(handler :: any, player, chestKey or lassoKey)
	if not ok then
		warn("[ProductService] receipt: " .. tostring(opened))
		return granted
	end
	if opened == false then
		-- THE CRATE REFUSED, WHICH IS A REAL STATE AND MUST NOT EAT THE
		-- PURCHASE. A full lawn is the commonest one and the player can fix it
		-- in ten seconds. The receipt is un-recorded and left PENDING, so
		-- Roblox brings it back -- the crate arrives once there is room for it
		-- rather than being spent on a warning.
		table.remove(receipts, table.find(receipts, id) :: number)
		DataService.save(player)
		return pending
	end
	return granted
end

function ProductService.start()
	-- ONE CALLBACK PER SERVER, WHICH IS WHY THIS LIVES HERE AND NOT IN
	-- WHICHEVER SERVICE HAPPENS TO SELL SOMETHING. `ProcessReceipt` is a
	-- single assignable property: a second file setting it silently replaces
	-- the first, and the symptom is a purchase that takes the money and never
	-- arrives. Anything else this game ever sells as a developer product
	-- routes through the registry above.
	MarketplaceService.ProcessReceipt = function(info)
		local ok, decision = pcall(fulfil, info)
		if not ok then
			warn("[ProductService] receipt threw: " .. tostring(decision))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return decision
	end

	-- SELF-WIRED, AND THE `GetPlayers` LOOP IS NOT BELT AND BRACES.
	-- `PlayerAdded` never fires for a player who is already in the server --
	-- which is every player in Play Solo and the first player into any live
	-- one -- and this project has shipped that bug twice (the wheelie bin's
	-- release hook, the jump's `refreshSpeed`). Both halves, every time.
	for _, player in ipairs(Players:GetPlayers()) do
		ProductService.onPlayerReady(player)
	end
	Players.PlayerAdded:Connect(ProductService.onPlayerReady)
	Players.PlayerRemoving:Connect(function(player)
		allowed[player] = nil
	end)

	-- SAYS OUT LOUD WHEN A CRATE CANNOT BE SOLD, which is the same warning
	-- `PassService` prints for an unset pass id and for the same reason: an id
	-- of 0 is invisible from inside the game. The card reads COMING SOON and
	-- declines to prompt, which is indistinguishable from the feature being
	-- broken unless something says so here.
	local missing = {}
	for key, chest in pairs(Config.CHESTS) do
		if ProductService.crateRobux(key) > 0 and ProductService.crateProduct(key) == 0 then
			table.insert(missing, key .. " (" .. tostring(chest.name) .. ")")
		end
	end
	if #missing > 0 then
		table.sort(missing)
		warn(("[ProductService] %d crate(s) have a Robux price and no developer "
			.. "product id, so they read COMING SOON and cannot be bought: %s. "
			.. "Create each product in the Creator Dashboard and put its id in "
			.. "that crate's `productId` in Config.CHESTS."):format(#missing, table.concat(missing, ", ")))
	end
	-- And the Robux lassos, for the same reason and in the same words.
	for key, spec in pairs((Config :: any).LASSOS or {}) do
		if spec.robux and ProductService.lassoProduct(key) == 0 then
			warn(("[ProductService] the %s has a Robux price and no developer product id, "
				.. "so it reads COMING SOON and cannot be bought. Put its id in "
				.. "`productId` in Config.LASSOS.%s."):format(tostring(spec.name), key))
		end
	end
end

return ProductService
