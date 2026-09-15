--!strict
--[[
	ChestService

	Opening a chest, and combining the duplicates it produces.

	WHY THIS IS LEGAL, WHICH IS THE FIRST THING TO KNOW ABOUT IT.

	A coin-bought chest is a paid random item ONLY if those coins can be bought
	with real money. They cannot, and never will -- see the note above
	Config.CHESTS and the long entry in CLAUDE.md. That single rule is what puts
	this whole file outside Roblox's paid-random-item regulation rather than
	compliant with it: no odds disclosure obligation, no PolicyService gate, no
	player in a restricted region meeting a button that refuses to open.

	It can only ever be broken once. The day somebody sells coins, every chest
	here becomes a regulated loot box retroactively, with nothing in this file
	having changed.

	TWO CURRENCIES, AND THE ARROW ONLY POINTS ONE WAY.

	Coins buy the standing catalogue. Tokens buy EVENT chests, and no amount of
	coins reaches them -- you were on the street when the saucer came or you
	were not. Spares, which duplicates produce, can only be COMBINED into coin
	chests, so a rich player cannot grind their way into event loot without
	attending.

	A DUPLICATE IS A SPARE COPY, AND A SPARE HAS TWO EXITS.

	It can be COMBINED -- three of any one tier for a roll at the next -- or
	SOLD for coins. Selling is what makes the per-item shape work at all: a
	spare that can never be combined is still worth something, so the rule that
	a duplicate is never a dead outcome survives the move off per-tier shards.

	SELLING IS ALWAYS A LOSS, AND THAT IS LOAD-BEARING RATHER THAN MEAN.
	Measured across all four coin chests, an open that lands a duplicate sells
	back for 21% to 35% of what the chest cost -- see Config.SELL, which caps a
	tier's value against the item's own price precisely so that buying an item
	in the shop and selling it straight back cannot turn a profit.

	NOTHING IS EVER LOCKED BEHIND LUCK. Every set item still carries its medal
	price, so the guaranteed route survives alongside this one. Bad luck here
	only ever costs time.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
-- skin lands on screen by itself. What it cannot cover is the CURRENCY: coins
-- live behind EconomyService's own push and tokens ride on the cosmetic state,
-- and a DUPLICATE grants nothing at all, so nothing pushed anything. Measured:
-- six opens charged three million coins and the HUD sat unchanged, which reads
-- as the chest being free.
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

local function spend(data: any, currency: string, cost: number): boolean
	if currency == "loot" then
		local held = math.floor(data.loot or 0)
		if held < cost then
			return false
		end
		data.loot = held - cost
		return true
	end
	if data.coins < cost then
		return false
	end
	data.coins -= cost
	return true
end

local function shortfallMessage(chest: any, held: number, cost: number): string
	if (chest.currency or "coins") == "loot" then
		local short = cost - held
		return ("Need %d more %s. Rob a neighbour and get the coins home."):format(
			short, Config.lootWord(short))
	end
	return ("Need %d more coins for the %s."):format(cost - held, chest.name)
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
-- THE ONE ROLL, WITH `charge` DECIDING WHETHER ANYBODY PAYS FOR IT.
--
-- A free open and a bought one differ by exactly one `if`: the tier roll, the
-- pick, the duplicate test, the grant, the two pushes and the reveal are all
-- the same, and a second copy of that is the near-identical duplicate this
-- project keeps recording as the thing that drifts.
--
-- IT IS A LOCAL AND THE FREE PATH IS NOT ON THE SERVICE'S REMOTE HANDLER,
-- which is the half that matters. `ChestOpen` forwards a chest key and
-- nothing else, so a client cannot reach `charge = false` however many extra
-- arguments it fires -- the same shape as every other "the click sends no
-- position" decision here.
local function roll(player: Player, chestKey: string, charge: boolean)
	local data = DataService.get(player)
	local chest = Config.CHESTS[chestKey]
	if not data or not chest then
		return
	end

	local odds, pool, total = liveOdds(chestKey)
	if total == 0 or next(odds) == nil then
		-- Never fail silently. A chest with nothing in it is a button that
		-- takes coins and returns nothing, which is the worst thing this
		-- codebase can ship -- so it refuses and says why instead.
		notify(player, ("The %s is not stocked yet."):format(chest.name), "warn")
		return
	end

	local currency = chest.currency or "coins"
	if charge then
		local held = if currency == "loot" then math.floor(data.loot or 0) else data.coins
		if held < chest.cost then
			notify(player, shortfallMessage(chest, held, chest.cost), "warn")
			return
		end
	end

	local tier = pickTier(odds)
	if not tier then
		return
	end
	local entries = pool[tier]
	local entry = entries[math.random(1, #entries)]
	local kind, key = Config.chestEntry(chestKey, entry)

	-- Charged only once the outcome exists. A chest that took the money and
	-- then found nothing to hand over would be the one failure mode here that
	-- looks like theft.
	if charge and not spend(data, currency, chest.cost) then
		return
	end

	local duplicate = SetService.owns(data, kind, key)
	if duplicate then
		addSpare(data, kind, key)
	else
		SetService.grant(player, kind, key)
	end

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

function ChestService.open(player: Player, chestKey: string)
	return roll(player, chestKey, true)
end

-- A CHEST OPENED WITHOUT PAYING FOR ONE. The daily ladder's day seven, and
-- nothing else today.
--
-- It is a real open rather than a coin payout, which is the entire point of
-- it: every other rung on that ladder pays something a player would have got
-- anyway by playing -- coins denominated in their own income, a boost, a
-- couple of bones -- so the ladder gave nobody a reason to come back that
-- playing did not already give them. A crate open is the one reward in this
-- game that cannot be reached any other way in that moment, and it lands on
-- the permanent cosmetic track rather than in the pig.
function ChestService.grantFree(player: Player, chestKey: string)
	return roll(player, chestKey, false)
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

-- Three spares of a tier for one roll at a higher one.
--
-- THE TARGET CHEST IS THE PLAYER'S CHOICE AND MUST BE A COIN CHEST. Shards are
-- global, so they would otherwise be a route into event loot for somebody who
-- never attended an event -- and attendance being the only route is the entire
-- point of that currency.
function ChestService.combine(player: Player, tier: string, chestKey: string,
	chosen: { string }?)
	local data = DataService.get(player)
	local chest = Config.CHESTS[chestKey]
	if not data or not chest then
		return
	end
	if (chest.currency or "coins") ~= "coins" then
		notify(player, ("The %s only takes %s."):format(
			chest.name, Config.ROLL_CURRENCY.plural:lower()), "warn")
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
	local duplicate = SetService.owns(data, kind, key)
	if duplicate then
		addSpare(data, kind, key)
	else
		SetService.grant(player, kind, key)
	end

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

	-- A SALE THAT WOULD OVERFLOW THE PIG IS REFUSED, NEVER CLAMPED.
	--
	-- The pig is the wallet and it is BOUNDED, so a payout that does not fit has
	-- two possible endings and only one of them is honest. Clamping quietly
	-- destroys coins the player has just earned, and from their side that is
	-- indistinguishable from theft: they pressed sell, the item went, and the
	-- money did not arrive. It is the silent-failure rule wearing a button.
	--
	-- Refusing costs them nothing and names the fix. It is also the "spend it or
	-- lose it" loop this economy already runs on, arriving from a new direction:
	-- a full pig stops earning until you spend some, and now it stops selling
	-- too.
	--
	-- WHOLE ORDER, NEVER PARTIAL. Selling four spares and being handed two is
	-- the same silent clamp one level up.
	local capacity = Config.getCapacity(data.capacityLevel)
	local room = capacity - data.coins
	if room <= 0 then
		notify(player, "Your piggy bank is full. Spend some coins before you sell.", "warn")
		return
	end
	if payout > room then
		notify(player, ("That is worth %s and your piggy bank only has room for %s. Spend some coins first."):format(
			Config.formatCoins(payout), Config.formatCoins(room)), "warn")
		return
	end

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
	notify(player, ("Sold %d %s for %s."):format(
		wanted, (spec and spec.name) or key, Config.formatCoins(payout)), "money")
	return payout
end

function ChestService.push(player: Player)
	local data = DataService.get(player)
	if not data then
		return
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
				cost = chest.cost,
				currency = chest.currency or "coins",
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
	Remotes.get("ChestOpen").OnServerEvent:Connect(function(player, chestKey)
		if type(chestKey) ~= "string" then
			return
		end
		ChestService.open(player, chestKey)
	end)

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
