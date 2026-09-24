--!strict
--[[
	THREE WAYS INTO A CRATE, AND ROBUX IS NOW ONE OF THEM (designer,
	2026-09-23). A crate is BOUGHT WITH ROBUX, EARNED ON THE DAILY LADDER, or
	GRANTED ON A REBIRTH, and nothing else opens one. In particular NO CRATE
	CARRIES A PRICE IN ANY IN-GAME CURRENCY: `Config.auditRandomOutcomes`
	still refuses a `cost` or a `currency` here, and `whyCannotOpen` fails
	closed on one, because coins are not purchasable with Robux and a coin
	price on a random outcome is what would make that rule load-bearing.

	WHAT THE ROBUX ROUTE COSTS, BECAUSE IT IS NOT FREE. A direct Robux
	purchase puts every priced crate INSIDE Roblox's paid random item rule:
	real odds disclosed before purchase summing to 100%, and a
	`PolicyService` gate so a restricted player is never prompted. The odds
	are `liveOdds`, already renormalised over the tiers that have stock, and
	`push` sends them to the card that draws them; the gate is
	`ProductService`. See the header there for which half lives where.

	NO CRATE EVER PAYS A DUPLICATE (designer, 2026-09-23), AND THAT IS A POOL
	RULE RATHER THAN A PAYOUT RULE. Every pool this file rolls from is
	filtered to what the player does NOT own -- `poolOf` with a save, at every
	tier -- so the reveal cannot land on something they already have, and
	`handOver` writes no spare for any kind. Spares still exist and are still
	sold and combined; what changed is where they come from, which is STEALING
	and WILD PIGGIES and no longer a crate.

	AND AN EMPTY POOL IS REFUSED BEFORE ANYTHING IS SPENT. A crate whose
	unowned pool is empty cannot be opened, cannot be prompted and reads
	COLLECTION COMPLETE on its card -- because the one failure mode here that
	looks like theft is taking Robux and handing back nothing.

	A SECOND PIGGY IS A SECOND PIGGY (2026-09-21) and survives as the FALLBACK
	it now is: the unowned pool means a crate cannot roll an owned skin, so
	`handOver`'s repeat branch is reachable only if something else ever hands
	it one, and a piggy is placed on a free pedestal rather than shredded into
	a spare. A crate that could yield a piggy is still REFUSED while the lawn
	is full, ahead of the roll and the receipt.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local SetService = require(script.Parent.SetService)

local ChestService = {}

-- SetService is required for `owns` and `grant`, which already resolve all five
-- catalogues through Config.catalogueFor and tell whichever service renders the
-- thing. It requires DataService and nothing else, so there is no cycle -- and
-- writing a second grant path here is exactly the near-identical copy this
-- project keeps recording as the thing that drifts.

-- `ProductService` IS REQUIRED LAZILY, FOR THE REASON `DailyService` REQUIRES
-- THIS FILE LAZILY.
--
-- That file's own note says it: SetService reaches the five catalogues' own
-- services, and pulling that chain in at load time is how a require cycle gets
-- built. The same argument points outward here -- the policy gate and the
-- receipt are needed when a crate is PUSHED or BOUGHT, never when this module
-- loads, so a top-level require would put ProductService inside every harness
-- that merely LOADS this file and one of those has no business knowing about
-- receipts.
--
-- Memoised, and written as a function rather than a `local` filled in later: a
-- `local` below its reader is a nil global, which this project has now hit
-- twelve times.
local cachedProducts: any = nil
local function Products(): any
	if cachedProducts == nil then
		cachedProducts = require(script.Parent.ProductService)
	end
	return cachedProducts
end

-- CHEAPEST FIRST, AND IT IS `Config`'S LIST RATHER THAN A SECOND COPY OF IT.
-- This was a local for as long as nothing else needed the sequence; a chest
-- carrying a rarity `floor` needs the same one to compare against, and two
-- copies of a ladder is the drift `RideSound` already paid for.
local TIERS = Config.RARITY_ORDER

-- WHO TO TELL WHEN A BALANCE MOVES, filled in by Main.
--
-- SetService.grant already pushes whichever service renders the ITEM, so a new
-- skin lands on screen by itself. What it cannot cover is the COIN BALANCE,
-- which lives behind EconomyService's own push -- and a DUPLICATE grants
-- nothing at all, so nothing pushed anything. Measured: six opens charged
-- three million coins and the HUD sat unchanged, which reads as the chest
-- being free.
--
-- A registry rather than a require, for the reason SetService.registerPusher is
-- one: it keeps this file's dependency list at DataService and SetService, and
-- makes a cycle impossible rather than merely absent today.
local balancePushers: { (Player) -> () } = {}

function ChestService.registerBalancePusher(fn: (Player) -> ())
	table.insert(balancePushers, fn)
end

local function pushBalances(player: Player)
	for _, fn in ipairs(balancePushers) do
		fn(player)
	end
end

local function notify(player: Player, message: string, kind: string)
	Remotes.get("Notify"):FireClient(player, message, kind)
end

local function tierIndex(tier: string): number
	for i, t in ipairs(TIERS) do
		if t == tier then
			return i
		end
	end
	return 1
end

-- ============================================================
-- WHAT IS IN A CRATE, AND WHOSE IT IS NOT YET
-- ============================================================

-- THE GUARDIAN CRATE NEEDED NOTHING HERE, WHICH IS WORTH A NOTE BECAUSE IT
-- BRIEFLY HAD THIRTY LINES.
--
-- `kind = "coat"` arrived with a pool of `Config.DOG_COATS` rows, and this
-- file carried its own pool builder, its own ownership test, its own spec
-- lookup and its own grant path for it -- on the reasoning that a coat is not
-- in `Config.catalogueFor` and does not live in a table `SetService` reads.
-- Both halves of that stopped being true the same day: `catalogueFor` answers
-- `coat`, `chestPool` has a coat branch with the exclusions in it, and
-- `SetService`'s own `ownedTable` and its registered pusher reach
-- `data.dogs.owned`. All four went.
--
-- WHAT THAT BUYS IS ONE GRANT PATH AND ONE POOL, which is the thing this
-- project keeps paying for when it has two -- and it is why a new KIND should
-- be added to those three places rather than branched around here.
--
-- THE STOCK OF A CRATE, AND WITH A SAVE THE PART OF IT THIS PLAYER CAN STILL
-- WIN.
--
-- No crate pays a duplicate any more (designer, 2026-09-23), and this is
-- where that is true rather than in the payout: a pool filtered to unowned
-- CANNOT roll something already held, so there is no duplicate to decide what
-- to do with. Called with no save it is the full stock, which is what a
-- collection COUNT and the audits are about.
local function poolOf(chestKey: string, data: any?): ({ [string]: { string } }, number)
	local pool, total = Config.chestPool(chestKey)
	if not data then
		return pool, total
	end

	local left: { [string]: { string } } = {}
	local count = 0
	for tier, entries in pairs(pool) do
		local keep: { string } = {}
		for _, entry in ipairs(entries) do
			local kind, key = Config.chestEntry(chestKey, entry)
			if not SetService.owns(data, kind, key) then
				table.insert(keep, entry)
				count += 1
			end
		end
		if #keep > 0 then
			left[tier] = keep
		end
	end
	return left, count
end

ChestService.poolOf = poolOf

-- What a chest can actually give, as weights over the tiers that HAVE stock.
--
-- RENORMALISED RATHER THAN RE-ROLLED. A tier carrying odds but no items is a
-- real possibility -- an event pool has no commons, and a half-built bucket may
-- have no legendary yet -- and rolling it would mean either handing back
-- nothing or looping until the dice cooperate. Dropping empty tiers and
-- rescaling what is left keeps every open honest and terminating.
--
-- It also means the percentages a player is shown have to be computed the same
-- way, or the reel prints odds the server does not use.
local function liveOdds(chestKey: string, data: any?): ({ [string]: number }, { [string]: { string } }, number)
	local chest = Config.CHESTS[chestKey]
	local pool, total = poolOf(chestKey, data)
	local odds: { [string]: number } = {}
	if not chest or total == 0 then
		return odds, pool, 0
	end

	local sum = 0
	for _, tier in ipairs(TIERS) do
		local weight = chest.odds[tier]
		if weight and weight > 0 and pool[tier] and #pool[tier] > 0 then
			odds[tier] = weight
			sum += weight
		end
	end
	if sum <= 0 then
		return {}, pool, 0
	end
	for tier, weight in pairs(odds) do
		odds[tier] = weight / sum * 100
	end
	return odds, pool, total
end

ChestService.liveOdds = liveOdds

local function pickTier(odds: { [string]: number }): string?
	local ticket = math.random() * 100
	-- Walked in TIERS order rather than with `pairs`, so the same random number
	-- picks the same tier on every machine. `pairs` has no defined order, which
	-- would make a reported bad roll impossible to reproduce -- the same reason
	-- `rollFrom` sorts its pool.
	for _, tier in ipairs(TIERS) do
		local weight = odds[tier]
		if weight then
			ticket -= weight
			if ticket <= 0 then
				return tier
			end
		end
	end
	for _, tier in ipairs(TIERS) do
		if odds[tier] then
			return tier
		end
	end
	return nil
end

-- The pool-entry grammar moved to `Config.chestEntry` when the crates UI
-- became a second reader of it and the admin console a third. Every call site
-- below already had the chest KEY to hand, which is what that function takes.

-- A spare is stored under the same "kind:key" grammar `Config.chestEntry`
-- reads, so the two are inverses and one place knows the shape. A bare key
-- would not say which of the five catalogues it came from -- there are no
-- collisions across the 92 keys today, and that is exactly the kind of fact
-- that stops being true without anything erroring.
local function entryKey(kind: string, key: string): string
	return kind .. ":" .. key
end

local function entrySpec(entry: string): (string?, string?, any)
	local kind, key = entry:match("^(%a+):(.+)$")
	if not kind or not key then
		return nil, nil, nil
	end
	local catalogue = Config.catalogueFor(kind)
	return kind, key, catalogue and catalogue[key]
end

-- Every spare the player holds AT A TIER, and how many copies that is.
--
-- COMBINING STILL POOLS BY TIER even though spares are per item, and that is
-- the whole reason a spare is never stranded: three commons of ANY kind make a
-- rare roll, so a duplicate out of a collection you have finished is still
-- fuel for one you have barely started. Per-item combining would have needed
-- three of one thing and put back the dead outcome this design removed.
local function sparesAt(data: any, tier: string): ({ string }, number)
	local entries: { string } = {}
	local total = 0
	for entry, count in pairs(data.spares) do
		if type(count) == "number" and count > 0 then
			local _kind, _key, spec = entrySpec(entry)
			if spec and Config.rarityOf(spec) == tier then
				table.insert(entries, entry)
				total += count
			end
		end
	end
	table.sort(entries)
	return entries, total
end

local function addSpare(data: any, kind: string, key: string)
	local entry = entryKey(kind, key)
	data.spares[entry] = (data.spares[entry] or 0) + 1
end

local function takeSpare(data: any, entry: string)
	local left = (data.spares[entry] or 0) - 1
	-- Dropped rather than left at zero. A save is a thing that gets walked, and
	-- a table full of zeroes is a table that grows forever and reads as stock
	-- to anything counting keys rather than values.
	data.spares[entry] = if left > 0 then left else nil
end

-- NO `DataService.save` PER OPEN, AND THAT MATCHES THE HOUSE STYLE RATHER THAN
-- DEPARTING FROM IT.
--
-- `save` is an unthrottled UpdateAsync, and a chest is the most repeatable
-- spend in this game -- completing Piggy Classics is about 149 opens. Saving
-- each one is 149 DataStore writes, which Roblox queues and then drops;
-- measured earlier in this session as a real "request was added to queue"
-- warning.
--
-- The precedent is `EconomyService.purchase`: the single most common coin
-- spend in the game does not save either, and leans on the 60-second autosave
-- and the write-on-leave. Buying a HOUSE saves, because that happens nine
-- times in an account's life. A chest is the other kind. The exposure is up to
-- one autosave interval of opens on a crash, which is exactly the exposure
-- every upgrade purchase already accepts.
--
-- SetService.grant still saves when it hands over a NEW item, so the thing a
-- player would actually mind losing is written immediately anyway. What is not
-- written on the spot is a duplicate's shard.
--
-- One open: roll a tier, take an item from it, grant it or shard it.
--
-- DUPLICATES ARE POSSIBLE FROM THE FIRST OPEN, which reverses the rule the
-- accessory roll was built on ("a roll can only return something you do not
-- already own"). That rule was right for one button over a pool of twelve and
-- is the wrong shape for a chest: a chest that cannot repeat is a checklist
-- with an animation on it.
--
-- WHAT REPLACED IT IS NARROWER AND HARDER: A DUPLICATE IS NEVER A DEAD
-- OUTCOME. It becomes a shard in the same breath, in the same reveal, so an
-- open always visibly pays out. What the old rule protected -- that a
-- nine-year-old never opens something and gets nothing -- is still true.
-- ============================================================
-- WHETHER A CRATE MAY BE OPENED AT ALL
-- ============================================================
--
-- A PIGGY OUT OF A CRATE HAS TO HAVE SOMEWHERE TO STAND, and since the
-- designer's 2026-09-21 ruling there is no bag behind the lawn: placement IS
-- ownership (docs/PIGGY-COLLECTION-PLAN.md §3/§4). So a crate that could hand
-- over a skin is REFUSED while every placement is taken, rather than rolling
-- one and having nowhere to put it.
--
-- REFUSED BEFORE THE ROLL, NOT AFTER IT. The entry below `roll` records why
-- the CHARGE happens only once the outcome exists -- "a chest that took the
-- money and then found nothing to hand over would be the one failure mode
-- here that looks like theft". An unplaceable outcome is that same failure
-- wearing different clothes: the reel would land on a legendary and then
-- nothing would arrive. Better never to spin.
--
-- "CAN YIELD A SKIN" RATHER THAN "IS A SKIN CRATE", which is deliberately the
-- stricter of the two. The Alien Cache is mixed, so a pool that MIGHT roll a
-- piggy is held back even though its other outcomes would have fitted -- the
-- looser rule would let a mixed crate roll the one thing it cannot deliver,
-- which is what this gate exists to stop.
--
-- MEASURED, THAT IS EVERY CRATE IN THE GAME TODAY: all seven of
-- `Config.CHESTS` can yield a skin (`og`/`animal` and their rare and
-- legendary tiers are skins only, `alien` is mixed), so right now this gate
-- applies to the whole Crates tab. The test is written as a QUESTION rather
-- than as "always true" because the catalogue has already moved once -- the
-- Dress-Up and effects crates are retired -- and an accessory-only pool
-- coming back must not be blocked by a full lawn it can never fill.
local function poolCanYieldPiggy(chestKey: string, data: any?): boolean
	local _, pool = liveOdds(chestKey, data)
	for _, entries in pairs(pool) do
		for _, entry in ipairs(entries) do
			local kind = Config.chestEntry(chestKey, entry)
			if kind == "skin" then
				return true
			end
		end
	end
	return false
end

-- nil when it may be opened, or the sentence to show the player.
--
-- ONE PREDICATE, TWO CALLERS, WHICH IS THE POINT OF IT BEING A FUNCTION.
-- `roll` asks it before spinning, and `DailyService.openCrate` asks it BEFORE
-- clearing the doorstep -- because that function clears the field and SAVES
-- before it rolls, deliberately, so that a disconnect cannot hand out a crate
-- twice. A refusal is not a disconnect: it is a synchronous, known no, and
-- without this the day-seven reward would be destroyed by a full lawn with a
-- warning as its only trace. Two copies of the reason would be two things
-- that can disagree about whether a crate is openable.
--
-- Deliberately NOT the funds check: what a crate costs only applies to the
-- charged path, and `grantFree` has to be able to open one for nothing.
function ChestService.whyCannotOpen(player: Player, chestKey: string): string?
	local data = DataService.get(player)
	local chest = Config.CHESTS[chestKey]
	if not data or not chest then
		return "That crate does not exist."
	end
	-- FAIL CLOSED IF A FUTURE CATALOGUE EDIT PUTS A PRICE BACK. A crate is
	-- earned; a priced one would be a paid random item with none of the
	-- disclosure that rule demands, so it refuses to open rather than
	-- quietly charging.
	if chest.currency ~= nil or chest.cost ~= nil then
		return ("The %s is unavailable."):format(chest.name)
	end
	local _, stocked = poolOf(chestKey)
	if stocked == 0 then
		-- Never fail silently. A chest with nothing in it is a button that
		-- takes money and returns nothing, which is the worst thing this
		-- codebase can ship -- so it refuses and says why instead.
		return ("The %s is not stocked yet."):format(chest.name)
	end
	-- TWO EMPTY POOLS, TWO SENTENCES, BECAUSE THEY ARE DIFFERENT NEWS. The
	-- one above is a catalogue with nothing in it, which is a bug somebody has
	-- to fix. This one is a collection somebody has FINISHED, which is the
	-- best possible reason to be refused -- and is the state the card draws as
	-- COLLECTION COMPLETE rather than as a price.
	local odds, _, left = liveOdds(chestKey, data)
	if left == 0 or next(odds) == nil then
		return ("You have everything in the %s."):format(chest.name)
	end
	if Config.firstFreePiggySlot(data) == nil and poolCanYieldPiggy(chestKey, data) then
		-- NAMES THE FIX, because a refusal that does not is indistinguishable
		-- from a broken button -- the rule every bone and gadget refusal here
		-- already follows.
		return "Your lawn is full. Make room for a piggy before you open a crate."
	end
	return nil
end

-- HANDING OVER WHAT WAS ROLLED. Returns whether the reveal should call it a
-- DUPLICATE, which for a piggy is now always false.
--
-- ONE FUNCTION BECAUSE THERE WERE TWO COPIES: the roll and the combine both
-- had the same four lines, and the piggy rule below would have had to be
-- written into both -- which is the near-identical duplicate this project
-- keeps recording as the thing that drifts. A combine that still made spares
-- out of skins while a roll did not is exactly the drift that would follow.
--
-- A SECOND PIGGY IS A SECOND PIGGY, NOT A SPARE (designer ruling 2026-09-21;
-- docs/PIGGY-COLLECTION-PLAN.md §3/§4). The duplicate/spare split is the
-- WARDROBE model -- you own a skin or you do not, so a repeat is a
-- consolation that pays its sell value -- and that was right while a skin was
-- a costume. A piggy is income standing on a pedestal, so a repeat is a REAL
-- prize: plan §4's whole argument is that this is "what makes a repeat pull
-- from a crate exciting rather than a consolation".
--
-- EVERY OTHER KIND KEEPS THE OLD BEHAVIOUR, deliberately rather than as
-- unfinished work: a duplicate ride or decoration out of the Alien Cache IS a
-- spare, because those are still wardrobe items with one copy each and
-- nowhere to stand a second.
-- HANDING OVER WHAT WAS ROLLED, AND IT IS NEVER A DUPLICATE.
--
-- Returns whether the reveal should call it one, which is now always false --
-- kept as a return rather than deleted because `roll` and `combine` both
-- publish it and a reveal that stopped saying so would be a silent change to
-- the payload every client reads.
--
-- NO SPARE IS WRITTEN FOR ANY KIND (designer, 2026-09-23). Spares are what
-- STEALING and WILD PIGGIES pay now, and the machinery that sells and
-- combines them is untouched; what went is a crate as a source of them. The
-- guarantee is upstream of this function: `poolOf` filters every pool to the
-- unowned set, so nothing here can land on something already held.
--
-- THE REPEAT BRANCH IS A FALLBACK AND IS DELIBERATELY STILL HERE. The pool
-- rule makes it unreachable from a crate; anything that ever hands this
-- function a key the player owns -- a caller with its own pool, a race
-- against a grant from somewhere else -- lands on it, and a second piggy on a
-- free pedestal is the honest outcome (designer ruling 2026-09-21). For every
-- other kind there is nowhere to stand a second copy and nothing to say, so
-- it is said out loud instead of being turned into currency.
local function handOver(player: Player, data: any, kind: string, key: string): boolean
	if not SetService.owns(data, kind, key) then
		-- ONE GRANT PATH FOR EVERY KIND. `SetService.grant` resolves the
		-- catalogue through `Config.catalogueFor`, writes the ownership table
		-- `ownedTable` names, pushes whichever service renders the thing,
		-- pushes the set panel and saves -- so a guardian coat, a skin and a
		-- ride all arrive the same way.
		SetService.grant(player, kind, key)
		return false
	end

	if kind == "skin" then
		-- `SetService.grant` returns false for a key already owned and writes
		-- nothing, so the collection write cannot be left to it for a repeat.
		-- A PLACEMENT IS GUARANTEED TO HAVE BEEN FREE: `whyCannotOpen` refuses
		-- the whole crate while the lawn is full, ahead of the roll and the
		-- receipt.
		Config.addPiggy(data, key, true)
		-- AND TELL SOMEBODY, because `grant` is what normally does that and
		-- this branch deliberately steps around it. Without it the save is
		-- correct, the pedestal is bare, and the crate reads as having handed
		-- over nothing.
		SetService.repaint(player, kind)
	else
		local spec = Config.getSetItem(kind, key)
		notify(player, ("You already have the %s."):format(
			(spec and spec.name) or key), "warn")
	end
	return false
end

-- THE ONE ROLL, WITH `charge` DECIDING WHETHER ANYBODY PAYS FOR IT.
--
-- A free open and a bought one differ by exactly one `if`: the tier roll, the
-- pick, the duplicate test, the grant, the two pushes and the reveal are all
-- the same, and a second copy of that is the near-identical duplicate this
-- project keeps recording as the thing that drifts.
--
-- THERE IS NO CHARGED PATH LEFT, and that is the whole shape of crates now.
--
-- This used to take a `charge` flag: the shop's buy button passed true and
-- the daily ladder passed false, and the note here explained at length why
-- the free path was a local rather than a remote handler. Crates are EARNED
-- (designer, 2026-09-21) -- the daily ladder, a rebirth, an event -- so every
-- open is what the free path always was, and there is no flag to reach.
--
-- WHAT THAT BUYS IS THE THING THE COMMENT ABOVE `Config.CHESTS` IS ABOUT:
-- nothing random here is purchased with anything, so no crate is a paid
-- random item and none of the disclosure or `PolicyService` machinery that
-- rule demands has to exist.
local function roll(player: Player, chestKey: string)
	local data = DataService.get(player)
	local chest = Config.CHESTS[chestKey]
	if not data or not chest then
		return
	end

	-- THE STOCK AND THE ROOM ON THE LAWN, through the one predicate
	-- `DailyService` also asks -- see `whyCannotOpen`. It used to be two
	-- checks written out here; they moved so that the doorstep crate and the
	-- shop button cannot disagree about whether a crate is openable.
	local refusal = ChestService.whyCannotOpen(player, chestKey)
	if refusal then
		notify(player, refusal, "warn")
		return
	end

	-- THE SAVE GOES IN, so the pool is what this player can still win rather
	-- than the whole shelf. See `poolOf`: that filter is the whole of "no
	-- crate ever pays a duplicate".
	local odds, pool = liveOdds(chestKey, data)

	local tier = pickTier(odds)
	if not tier then
		return
	end
	local entries = pool[tier]
	local entry = entries[math.random(1, #entries)]
	local kind, key = Config.chestEntry(chestKey, entry)

	local duplicate = handOver(player, data, kind, key)

	ChestService.push(player)
	pushBalances(player)

	Remotes.get("ChestResult"):FireClient(player, {
		chest = chestKey,
		tier = tier,
		kind = kind,
		key = key,
		duplicate = duplicate,
		-- What the spare is worth sold, so the reveal can pay out visibly in
		-- the same breath rather than leaving a duplicate reading as nothing.
		-- Zero for a new item, which has no spare to sell.
		value = if duplicate then Config.sellValue(kind, key) else 0,
		-- The odds the server ACTUALLY used, so the reel can print real
		-- percentages. Printing the number is what makes this honest rather
		-- than merely true, and it costs nothing now that nothing requires it.
		odds = odds,
	})
	return tier, kind, key, duplicate
end

-- Daily rewards, rebirths and events open a crate for nothing. There is no
-- CLIENT way in: `ChestService.open` retired with the coin buy button, and the
-- Robux route arrives as a RECEIPT rather than as a remote -- see `openPaid`.
function ChestService.grantFree(player: Player, chestKey: string)
	return roll(player, chestKey)
end

-- A PAID OPEN, REACHED ONLY FROM `MarketplaceService.ProcessReceipt`.
--
-- One roll with a flag would be the shape if a paid open differed from a free
-- one, and it does not: the tier roll, the pick, the grant, both pushes and
-- the reveal are identical, and the CHARGE is Roblox's rather than this
-- file's. So this is `grantFree` with a boolean, and the boolean is the whole
-- contract: FALSE means nothing was handed over, and `ProductService` leaves
-- the receipt un-recorded and pending so the purchase comes back rather than
-- being spent on a warning.
--
-- IT IS A FUNCTION AND NOT A REMOTE, which is what stops a client opening a
-- crate for nothing by firing the channel a paid one arrives on.
function ChestService.openPaid(player: Player, chestKey: string): boolean
	return roll(player, chestKey) ~= nil
end

-- WHICH OF THESE CRATES IS WORTH OPENING FOR THIS PLAYER, or nil.
--
-- `ProgressionService` picks a rebirth crate from a list and used to ask
-- `Config.rebirthCratesOpen`, which tests whether the LEGENDARY keys are all
-- owned -- the right question while a crate could pay a duplicate and the
-- wrong one now that an exhausted pool is refused outright. This asks the
-- predicate that actually decides: whichever crate would open.
--
-- RANDOM AMONG THE OPENABLE ONES rather than the first, so a rebirth does not
-- always roll at the same shelf.
function ChestService.pickOpenable(player: Player, keys: { string }): string?
	local open: { string } = {}
	for _, key in ipairs(keys) do
		if Config.CHESTS[key] and ChestService.whyCannotOpen(player, key) == nil then
			table.insert(open, key)
		end
	end
	if #open == 0 then
		return nil
	end
	return open[math.random(1, #open)]
end

-- Direct recovery of a lost skin, never a random roll. Eligibility, ownership
-- and price are re-read on the server; clients supply only the skin key.
function ChestService.buyback(player: Player, key: string)
	if type(key) ~= "string" then return end
	local data = DataService.get(player)
	if not data then return end
	data.claims = data.claims or {}
	Config.pruneBuybackClaims(data.claims)
	local cost = Config.buybackCost(key)
	if not cost or data.claims[key] ~= Config.seasonIndex() then
		notify(player, "That skin has no buy-back claim this season.", "warn")
		ChestService.push(player)
		return
	end
	if SetService.owns(data, "skin", key) then
		notify(player, "You already own that skin.", "warn")
		ChestService.push(player)
		return
	end
	-- IN COINS NOW. The buy-back used to be priced off the crate that drops
	-- the skin and paid in acorns; `Config.buybackCost` derives it from what
	-- letting the skin go pays instead. This is one NAMED skin and nothing
	-- about it is random, so a coin price here is an ordinary purchase rather
	-- than anything the paid random item rule reaches.
	local held = math.floor(data.coins or 0)
	if held < cost then
		notify(player, ("Need %s more coins to buy that back."):format(
			Config.formatCoins(cost - held)), "warn")
		return
	end
	-- No yield between eligibility, charge and grant's ownership write. Its
	-- normal save includes this balance and the retained seasonal claim.
	data.coins = held - cost
	if not SetService.grant(player, "skin", key) then
		data.coins += cost
		notify(player, "Could not return that skin. Your coins were refunded.", "warn")
	else
		notify(player, ("Bought back %s for %s coins."):format(
			Config.SKINS[key].name, Config.formatCoins(cost)), "good")
	end
	ChestService.push(player)
	pushBalances(player)
end

-- WHICH THREE, WHEN THE PLAYER DOES NOT SAY.
--
-- Every spare at a tier combines identically, so the choice cannot affect the
-- roll -- which means the only thing it CAN affect is what is left behind. The
-- honest default is therefore to leave the valuable ones: spares are consumed
-- cheapest first, so a nine-year-old who just presses the button keeps the ones
-- worth most sold. The client may still name its own three.
--
-- The values are computed once into a map rather than inside the comparator.
-- `table.sort` throws "invalid order function" on a comparator that is not
-- consistent, and one that recomputes a value per comparison is one edit away
-- from not being.
local function autoPick(data: any, entries: { string }): { string }
	local worth: { [string]: number } = {}
	for _, entry in ipairs(entries) do
		local kind, key = entrySpec(entry)
		worth[entry] = if kind and key then Config.sellValue(kind, key) else 0
	end

	local order = table.clone(entries)
	table.sort(order, function(a, b)
		if worth[a] ~= worth[b] then
			return worth[a] < worth[b]
		end
		return a < b
	end)

	local take: { string } = {}
	for _, entry in ipairs(order) do
		for _ = 1, data.spares[entry] or 0 do
			if #take >= Config.COMBINE.need then
				return take
			end
			table.insert(take, entry)
		end
	end
	return take
end

-- HOW FAR UP A COMBINE CLIMBS. Clamped at legendary by its caller, so
-- combining epics is simply a legendary rather than a wasted roll.
--
-- EXTRACTED BECAUSE THERE ARE TWO CALLERS NOW. `combine` had these eleven
-- lines inline, which was right while it was the only thing that climbed a
-- tier; `rollUp` is the physical combine station's route in, and a second copy
-- of a ladder is what `RideSound` already paid for.
local function rollClimb(): number
	local ticket, climb = math.random() * 100, 1
	for steps = 1, 3 do
		local weight = Config.COMBINE.odds[steps]
		if weight then
			ticket -= weight
			if ticket <= 0 then
				climb = steps
				break
			end
		end
	end
	return climb
end

-- EVERY UNOWNED ITEM OF ONE KIND, ACROSS EVERY COLLECTION, BY TIER.
--
-- `poolOf` answers for ONE crate, which is the right scope for opening one and
-- the wrong scope for climbing a tier: a spare is pooled by TIER regardless of
-- which shelf it came from (see `sparesAt`), so what it buys has to be too --
-- otherwise the fuel is global and the prize is parochial, and a player with a
-- finished OG shelf could not spend their commons at all.
--
-- Unioned through the crates rather than by walking a catalogue, so every
-- exclusion those pools already make comes for free: a set item, a pass
-- exclusive, a season finish and a gated coat are all out, in one place, by
-- the predicate that already decides it.
local function unownedByKind(data: any, kind: string): { [string]: { string } }
	local seen: { [string]: boolean } = {}
	local pool: { [string]: { string } } = {}
	for chestKey, chest in pairs(Config.CHESTS) do
		if chest.kind == kind then
			local entries = poolOf(chestKey, data)
			for tier, list in pairs(entries) do
				for _, entry in ipairs(list) do
					local entryKind, entryKey = Config.chestEntry(chestKey, entry)
					if entryKind == kind and not seen[entryKey] then
						seen[entryKey] = true
						pool[tier] = pool[tier] or {}
						table.insert(pool[tier], entryKey)
					end
				end
			end
		end
	end
	for _, list in pairs(pool) do
		table.sort(list)
	end
	return pool
end

-- ONE TIER UP, TAKING NOTHING AND CHARGING NOTHING.
--
-- THE COMBINE UI HAS LEFT THE CRATES TAB and a physical station on the street
-- has taken it over (2026-09-23). `combine` above is untouched and is still
-- the route that consumes spares; this is the shape a station may prefer,
-- because it wants to decide for itself what the inputs are and what the
-- reveal looks like.
--
-- IT CONSUMES NOTHING, WHICH IS THE ENTIRE CONTRACT AND IS THE ONE THING A
-- CALLER MUST GET RIGHT. Call this FIRST and consume the player's inputs only
-- on a non-nil answer. Consuming first and calling second is how five spares
-- are eaten by a pool that had nothing left in it -- which is the failure
-- `combine` orders its own refusals to avoid, and the reason that function
-- takes the spares last.
--
-- Returns (kind, key, tier) or nil. The CALLER owns the reveal: no
-- `ChestResult` is fired, because a station's own animation is not a crate
-- reel and a payload naming no chest is dropped by the one client that draws
-- them. The grant is still said out loud here, so this can never be silent.
function ChestService.rollUp(player: Player, fromTier: string, kind: string): (string?, string?, string?)
	local data = DataService.get(player)
	if not data or type(fromTier) ~= "string" or type(kind) ~= "string" then
		return nil
	end
	if kind ~= "skin" and kind ~= "coat" then
		return nil
	end
	local from = table.find(TIERS, fromTier)
	if not from then
		return nil
	end
	-- THE SAME ROOM-ON-THE-LAWN GATE EVERY OTHER ROUTE TO A PIGGY TAKES, and
	-- ahead of the climb for the reason `combine` asks ahead of consuming:
	-- placement IS ownership, so a piggy with nowhere to stand is a prize that
	-- cannot be handed over.
	if kind == "skin" and Config.firstFreePiggySlot(data) == nil then
		notify(player, "Your lawn is full. Make room for a piggy first.", "warn")
		return nil
	end

	local pool = unownedByKind(data, kind)
	local target = math.min(from + rollClimb(), #TIERS)

	-- THE CLIMB IS WHAT WAS ROLLED; WHERE IT LANDS IS WHAT IS STOCKED. Walked
	-- DOWN from the target first, so a lucky three-tier climb into an
	-- exhausted legendary pool pays the epic it passed through rather than
	-- nothing -- and never below `from + 1`, because this is a roll UP. Only
	-- then upward, so a player who owns every epic can still be handed the
	-- legendary above it.
	local landed = nil
	for step = target, from + 1, -1 do
		local entries = pool[TIERS[step]]
		if entries and #entries > 0 then
			landed = step
			break
		end
	end
	if not landed then
		for step = target + 1, #TIERS do
			local entries = pool[TIERS[step]]
			if entries and #entries > 0 then
				landed = step
				break
			end
		end
	end
	if not landed then
		-- Never fail silently, and name what is actually true: there is
		-- nothing left ABOVE this tier rather than nothing left at all.
		notify(player, ("You already have everything above %s."):format(fromTier), "warn")
		return nil
	end

	local tier = TIERS[landed]
	local entries = pool[tier]
	local key = entries[math.random(1, #entries)]
	handOver(player, data, kind, key)

	ChestService.push(player)
	pushBalances(player)

	local spec = Config.getSetItem(kind, key)
	notify(player, ("%s %s!"):format(tier:upper(), (spec and spec.name) or key), "good")
	return kind, key, tier
end

-- A client-named list, rebuilt from known-good parts rather than trusted. Every
-- entry has to be a real catalogue item AT THIS TIER and a spare this player
-- actually holds, counted as a multiset so three of the same key needs three of
-- them. Anything else refuses the whole combine rather than silently dropping
-- an entry and consuming two.
local function validatePick(data: any, tier: string, chosen: { string }): { string }?
	if #chosen ~= Config.COMBINE.need then
		return nil
	end
	local left: { [string]: number } = {}
	for _, entry in ipairs(chosen) do
		local kind, key, spec = entrySpec(entry)
		if not kind or not key or not spec or Config.rarityOf(spec) ~= tier then
			return nil
		end
		local held = left[entry] or data.spares[entry] or 0
		if held <= 0 then
			return nil
		end
		left[entry] = held - 1
	end
	return chosen
end

-- Config.COMBINE.need spares for a higher-tier roll into a regular crate.
-- Event-set crates remain excluded independently of their currency.
function ChestService.combine(player: Player, tier: string, chestKey: string,
	chosen: { string }?)
	local data = DataService.get(player)
	local chest = Config.CHESTS[chestKey]
	if not data or not chest then
		return
	end
	if not Config.canCombineChest(chestKey) then
		notify(player, ("Spares cannot be combined into the %s."):format(chest.name), "warn")
		return
	end
	-- THE SAME ROOM-ON-THE-LAWN GATE THE ROLL TAKES, and for the sharper
	-- reason: a combine CONSUMES spares. A roll that could not place its
	-- outcome would waste the crate; a combine would eat five spares and hand
	-- back a piggy with nowhere to stand. Asked ahead of every consumption
	-- below, through the same predicate the shop button and the doorstep crate
	-- use, so the three cannot disagree about whether a crate is openable.
	local refusal = ChestService.whyCannotOpen(player, chestKey)
	if refusal then
		notify(player, refusal, "warn")
		return
	end

	local need = Config.COMBINE.need
	local entriesAt, have = sparesAt(data, tier)
	if have < need then
		notify(player, ("Need %d more spare %s to combine."):format(need - have, tier), "warn")
		return
	end

	local take = if chosen then validatePick(data, tier, chosen) else autoPick(data, entriesAt)
	if not take or #take ~= need then
		-- Never fail silently. A client naming spares it does not hold is
		-- either a bug in the picker or somebody poking the remote, and both
		-- want the same visible refusal rather than a quiet return.
		notify(player, ("Those are not %d spare %s you hold."):format(need, tier), "warn")
		return
	end

	local from = tierIndex(tier)
	if from >= #TIERS then
		notify(player, "Legendary is the top tier. Nothing to combine up to.", "warn")
		return
	end

	local climb = rollClimb()
	local target = TIERS[math.min(from + climb, #TIERS)]

	local _, pool = liveOdds(chestKey, data)
	local entries = pool[target]
	if not entries or #entries == 0 then
		notify(player, ("The %s has no %s to give yet."):format(chest.name, target), "warn")
		return
	end

	-- Consumed only now, past every refusal above. A combine that took the
	-- spares and then found the target tier empty is the same failure shape as
	-- a chest that charges and hands back nothing.
	for _, consumed in ipairs(take) do
		takeSpare(data, consumed)
	end

	local entry = entries[math.random(1, #entries)]
	local kind, key = Config.chestEntry(chestKey, entry)
	local duplicate = handOver(player, data, kind, key)

	ChestService.push(player)
	pushBalances(player)

	Remotes.get("ChestResult"):FireClient(player, {
		chest = chestKey,
		tier = target,
		kind = kind,
		key = key,
		duplicate = duplicate,
		value = if duplicate then Config.sellValue(kind, key) else 0,
		combined = true,
		climb = climb,
		-- What it cost, so the reveal can show the three going in. The client
		-- may not have chosen them.
		consumed = take,
	})
	return target, kind, key, duplicate
end

-- SELLING SPARES, AND SELLING THE LAST COPY, WHICH ARE DIFFERENT ACTS.
--
-- A spare sale is safe by construction: another copy stays behind and nothing
-- the player is looking at changes. The LAST copy takes the item away, and that
-- is allowed on purpose -- a collection you can only ever add to is a checklist,
-- and it is the mechanic this audience already knows from every other Roblox
-- game with crates in it.
--
-- THE GUARD IS NOT THE EXPLOIT, IT IS THE ACCIDENT. There is no sell-and-rebuy
-- loop to close, because Config.SELL caps every tier value against the item's
-- own price and selling is therefore always a loss. What there is, is a
-- nine-year-old with a stray thumb and the legendary they spent three weeks
-- getting. So the copy IN USE cannot be sold: taking it off first is one tap,
-- learnable in a second, and it kills exactly the accidental case without a
-- lock flag anybody has to be taught.
function ChestService.sell(player: Player, kind: string, key: string, count: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	if not Config.isSellable(kind, key) then
		return
	end

	local wanted = math.floor(count)
	if wanted < 1 then
		return
	end
	if not SetService.owns(data, kind, key) then
		return
	end

	local entry = entryKey(kind, key)
	local held = data.spares[entry] or 0
	local inUse = SetService.inUse(data, kind, key)
	-- Held spares, plus the owned copy itself when it is not being worn. That
	-- last term is the whole of "you may sell your only one".
	local sellable = held + (if inUse then 0 else 1)

	if wanted > sellable then
		if inUse and held == 0 then
			notify(player, "You are wearing your only one. Take it off first.", "warn")
		else
			notify(player, ("You only have %d of those to sell."):format(sellable), "warn")
		end
		return
	end

	local payout = Config.sellValue(kind, key) * wanted
	if payout <= 0 then
		return
	end
	-- A SALE BANKS IN FULL. It used to be REFUSED when the payout would not
	-- fit the pig -- refused rather than clamped, because a clamp that
	-- destroys coins a player has just earned is indistinguishable from
	-- theft -- and both endings are gone with the pig's ceiling: there is no
	-- room to overflow.

	local fromSpares = math.min(wanted, held)
	for _ = 1, fromSpares do
		takeSpare(data, entry)
	end
	if wanted > fromSpares then
		-- The last copy. `revoke` pushes the item's own service AND the set panel
		-- and saves, exactly as `grant` does -- so the thing a player would
		-- actually mind getting wrong is written immediately.
		SetService.revoke(player, kind, key)
	end
	data.coins += payout

	ChestService.push(player)
	pushBalances(player)

	local catalogue = Config.catalogueFor(kind)
	local spec = catalogue and catalogue[key]
	notify(player, ("Sold %d %s for %s coins."):format(
		wanted, (spec and spec.name) or key, Config.formatCoins(payout)), "money")
	return payout
end

function ChestService.push(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end

	data.claims = data.claims or {}
	Config.pruneBuybackClaims(data.claims)
	local buybacks = {}
	for key in pairs(data.claims) do
		local cost = Config.buybackCost(key)
		if cost and not SetService.owns(data, "skin", key) then
			local skin = Config.SKINS[key]
			buybacks[key] = { name = skin.name, chest = skin.chest,
				cost = cost, tier = Config.rarityOf(skin), order = skin.order }
		end
	end

	-- WHAT A RESTRICTED PLAYER MAY NOT BE OFFERED, asked once per push rather
	-- than once per crate: it is a fact about the PLAYER, and
	-- `ProductService.restricted` is memoised anyway.
	local restricted = Products().restricted(player)

	local chests = {}
	for key, chest in pairs(Config.CHESTS) do
		-- THE FULL STOCK DECIDES WHETHER THE CRATE IS ON THE SHELF AND THE
		-- UNOWNED STOCK DECIDES WHETHER IT CAN BE OPENED, and conflating the
		-- two would delete a finished crate from the tab -- which reads as a
		-- shop that failed to load rather than as a collection somebody has
		-- completed.
		local pool, total = poolOf(key)
		if total > 0 then
			local owned = 0
			for _, entries in pairs(pool) do
				for _, entry in ipairs(entries) do
					local kind, itemKey = Config.chestEntry(key, entry)
					if SetService.owns(data, kind, itemKey) then
						owned += 1
					end
				end
			end
			-- THE ODDS THE SERVER WOULD ACTUALLY ROLL WITH, which is what the
			-- paid random item rule asks to be disclosed. They are the UNOWNED
			-- pool's, renormalised, so the percentages on the card are the
			-- ones the purchase would really be made at rather than the
			-- table's.
			local odds, _, left = liveOdds(key, data)
			local robux = Products().crateRobux(key)
			chests[key] = {
				name = chest.name,
				order = chest.order,
				canCombine = Config.canCombineChest(key),
				blurb = chest.blurb,
				colour = chest.colour,
				odds = odds,
				owned = owned,
				total = total,
				-- WHAT IT COSTS IN ROBUX, AND WHICH PRODUCT OPENS IT. Zero
				-- robux is a crate that is earned and never sold (the event
				-- cache); a price with a zero product is one whose developer
				-- product does not exist yet, which the card reads as COMING
				-- SOON -- the same shape `PassService.idOf` gives a pass.
				robux = robux,
				productId = Products().crateProduct(key),
				-- NOTHING LEFT TO WIN. Sent as a FLAG rather than left to the
				-- client to infer from `owned == total`: the two differ
				-- whenever a tier carries stock and no authorised odds, and
				-- the server is the only end that knows which.
				complete = left == 0 or next(odds) == nil,
				-- THE SERVER'S OWN SENTENCE, so the card and the refusal
				-- cannot disagree about why a crate will not open. nil means
				-- it would.
				refusal = ChestService.whyCannotOpen(player, key),
			}
		end
	end

	-- EVERY SPARE, WITH WHAT IT IS WORTH SOLD AND WHETHER IT CAN BE.
	--
	-- The value is derived here rather than on the client for the same reason
	-- the reel's odds are: two implementations of one number are two things that
	-- can disagree, and this one is money. `inUse` rides along so a card can say
	-- "take it off first" BEFORE the player presses a button that will only
	-- refuse -- the same rule the steal prompt follows.
	local spares = {}
	local perTier: { [string]: number } = {}
	for entry, count in pairs(data.spares) do
		local kind, key, spec = entrySpec(entry)
		if kind and key and spec and type(count) == "number" and count > 0 then
			local tier = Config.rarityOf(spec)
			perTier[tier] = (perTier[tier] or 0) + count
			spares[entry] = {
				kind = kind,
				key = key,
				name = spec.name,
				count = count,
				tier = tier,
				value = Config.sellValue(kind, key),
				inUse = SetService.inUse(data, kind, key),
			}
		end
	end

	Remotes.get("ChestState"):FireClient(player, {
		chests = chests,
		-- ROBLOX'S PAID RANDOM ITEM GATE, AS ONE BOOLEAN. True means this
		-- player may not be prompted for a crate at all -- and the card has to
		-- SAY so rather than silently dropping its button, which is the
		-- "refused rather than meeting a button that does nothing" half of
		-- that rule. Per client, because it is per player.
		restricted = restricted,
		buybacks = buybacks,
		buybacksExpireAt = Config.seasonEndsAt(),
		spares = spares,
		-- Copies per tier, which is what the combine button is gated on. Summed
		-- here rather than on the client, because the client would have to know
		-- the rarity rules to do it and that is a second copy of them.
		perTier = perTier,
		need = Config.COMBINE.need,
		combineOdds = Config.COMBINE.odds,
	})
end

function ChestService.start()
	Remotes.get("SkinBuyback").OnServerEvent:Connect(function(player, key)
		if type(key) == "string" then ChestService.buyback(player, key) end
	end)

	-- Requests always enforce the current season. This also clears idle
	-- players' saved claims/cards when a boundary passes during a session.
	task.spawn(function()
		local season = Config.seasonIndex()
		while task.wait(30) do
			local current = Config.seasonIndex()
			if current ~= season then
				season = current
				for _, player in ipairs(Players:GetPlayers()) do
					local data = DataService.get(player)
					if data and data.claims and Config.pruneBuybackClaims(data.claims) then
						ChestService.push(player)
						DataService.save(player)
					end
				end
			end
		end
	end)

	-- THERE IS NO `ChestOpen` HANDLER, AND THE ROBUX ROUTE DID NOT ADD ONE.
	-- A paid crate arrives as a `ProcessReceipt` callback rather than as a
	-- remote, which is what stops a client opening one for nothing by firing
	-- the channel; the free routes are the daily ladder, a rebirth and an
	-- event, and all three are server calls.
	--
	-- REGISTERED HERE AND STARTED HERE, so no line in `Main` is load-bearing
	-- for a purchase working. ProductService requires Config and DataService
	-- and nothing else precisely so this direction is the only one.
	Products().onCrateReceipt(ChestService.openPaid)
	-- The policy answer arrives on a web call a beat after the join, and the
	-- card has to repaint when it does or it sits on "not available here" for
	-- the session.
	Products().onPolicy(ChestService.push)
	Products().start()

	Remotes.get("ChestCombine").OnServerEvent:Connect(function(player, tier, chestKey, entries)
		if type(tier) ~= "string" or type(chestKey) ~= "string" then
			return
		end
		-- The tier is checked against the real list rather than trusted: a
		-- client naming a field is how a save gets arbitrary keys in it, which
		-- is the same reason SettingsService is an allowlist.
		if not table.find(TIERS, tier) then
			return
		end

		-- The entry list is OPTIONAL and is rebuilt from known-good parts rather
		-- than trusted. Read one past `need` and stop: `validatePick` refuses
		-- anything that is not exactly three, so a client sending ten thousand is
		-- refused without this walking ten thousand of them.
		local chosen: { string }? = nil
		if type(entries) == "table" then
			local list: { string } = {}
			for _, entry in ipairs(entries) do
				if #list > Config.COMBINE.need then
					break
				end
				if type(entry) == "string" then
					table.insert(list, entry)
				end
			end
			chosen = list
		end
		ChestService.combine(player, tier, chestKey, chosen)
	end)

	Remotes.get("SpareSell").OnServerEvent:Connect(function(player, kind, key, count)
		if type(kind) ~= "string" or type(key) ~= "string" then
			return
		end
		-- A count that is not a number is ONE, never everything. The dangerous
		-- default here is the generous one: this is the remote that can empty a
		-- collection. `count == count` rejects NaN, which floors to itself and
		-- compares false against every bound above.
		local wanted = if type(count) == "number" and count == count then math.floor(count) else 1
		ChestService.sell(player, kind, key, wanted)
	end)

end

return ChestService
