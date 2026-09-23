--!strict
--[[
	CRATES ARE EARNED, NEVER BOUGHT. No crate carries a price in any currency:
	they arrive from the daily ladder, from a rebirth and from events, and
	`grantFree` is the only way one opens. That is what keeps every crate here
	outside Roblox's paid random item rule -- see the note above
	`Config.CHESTS` for what a price field would cost.

	A SECOND PIGGY IS A SECOND PIGGY (2026-09-21): a duplicate SKIN is placed
	on a free lawn pedestal rather than becoming a spare, and a crate that
	could yield one is REFUSED while the lawn is full -- see `handOver` and
	`whyCannotOpen`. Duplicates of every other kind still become per-item
	spares, because those are wardrobe items with nowhere to stand a second
	copy. Config.COMBINE.need spares of one tier can roll into a regular
	crate; event-set crates cannot be combined into. Selling spares pays coins
	through Config.sellValue.
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
local function liveOdds(chestKey: string): ({ [string]: number }, { [string]: { string } }, number)
	local chest = Config.CHESTS[chestKey]
	local pool, total = Config.chestPool(chestKey)
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
local function poolCanYieldPiggy(chestKey: string): boolean
	local _, pool = liveOdds(chestKey)
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
	local odds, _, total = liveOdds(chestKey)
	if total == 0 or next(odds) == nil then
		-- Never fail silently. A chest with nothing in it is a button that
		-- takes coins and returns nothing, which is the worst thing this
		-- codebase can ship -- so it refuses and says why instead.
		return ("The %s is not stocked yet."):format(chest.name)
	end
	if Config.firstFreePiggySlot(data) == nil and poolCanYieldPiggy(chestKey) then
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
local function handOver(player: Player, data: any, kind: string, key: string): boolean
	local duplicate = SetService.owns(data, kind, key)
	if kind ~= "skin" then
		if duplicate then
			addSpare(data, kind, key)
		else
			SetService.grant(player, kind, key)
		end
		return duplicate
	end

	-- `SetService.grant` returns false for a key already owned and writes
	-- nothing, so the collection write cannot be left to it for a repeat --
	-- that early-out IS the wardrobe rule this branch steps around. The first
	-- copy still goes through it, so `cosmetics.owned` and the set panel see
	-- it; later copies go straight onto a pedestal.
	if duplicate then
		Config.addPiggy(data, key, true)
		-- AND TELL SOMEBODY, because `grant` is what normally does that and
		-- this branch deliberately steps around it. Without this the only
		-- write in the game that changes a lawn and pushes nothing -- the save
		-- correct, the pedestal bare, and the crate reading as having handed
		-- over nothing.
		SetService.repaint(player, kind)
	else
		SetService.grant(player, kind, key)
	end
	-- A PLACEMENT IS GUARANTEED TO HAVE BEEN FREE, which is what lets this be
	-- unconditional: `whyCannotOpen` refuses the whole crate while the lawn is
	-- full, ahead of the roll and the charge, so there is no "rolled it and
	-- had nowhere to put it" case left to handle here.
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

	local odds, pool = liveOdds(chestKey)

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

-- Daily rewards, rebirths and events open a crate. There is no other way in:
-- `ChestService.open` retired with the buy button, so nothing a client can
-- fire opens one.
function ChestService.grantFree(player: Player, chestKey: string)
	return roll(player, chestKey)
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

	-- How far up. Clamped at legendary, so combining epics is simply a
	-- legendary rather than a wasted roll.
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
	local target = TIERS[math.min(from + climb, #TIERS)]

	local _, pool = liveOdds(chestKey)
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

	local chests = {}
	for key, chest in pairs(Config.CHESTS) do
		local odds, pool, total = liveOdds(key)
		if total > 0 then
			local owned = 0
			for tier, entries in pairs(pool) do
				local _ = tier
				for _, entry in ipairs(entries) do
					local kind, itemKey = Config.chestEntry(key, entry)
					if SetService.owns(data, kind, itemKey) then
						owned += 1
					end
				end
			end
			chests[key] = {
				name = chest.name,
				order = chest.order,
				canCombine = Config.canCombineChest(key),
				blurb = chest.blurb,
				colour = chest.colour,
				odds = odds,
				owned = owned,
				total = total,
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

	-- THERE IS NO `ChestOpen` HANDLER. A crate is earned rather than bought,
	-- so nothing a client fires may open one -- the buy button and its remote
	-- retired together, and `grantFree` is reached only from the daily ladder,
	-- a rebirth and events.

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
