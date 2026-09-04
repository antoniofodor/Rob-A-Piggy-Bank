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
	were not. Shards, which duplicates produce, spend only on COIN chests, so a
	rich player cannot grind their way into event loot without attending.

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

local TIERS = { "common", "rare", "epic", "legendary" }

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

-- A pool entry is "kind:key" for a set chest and a bare key otherwise, because
-- a set spans five catalogues and a bare key does not say which one to grant
-- from. One place that knows the grammar.
local function splitEntry(chest: any, entry: string): (string, string)
	local kind, key = entry:match("^(%a+):(.+)$")
	if kind and key then
		return kind, key
	end
	return chest.kind, entry
end

local function spend(data: any, currency: string, cost: number): boolean
	if currency == "tokens" then
		local held = math.floor(data.tokens or 0)
		if held < cost then
			return false
		end
		data.tokens = held - cost
		return true
	end
	if data.coins < cost then
		return false
	end
	data.coins -= cost
	return true
end

local function shortfallMessage(chest: any, held: number, cost: number): string
	if (chest.currency or "coins") == "tokens" then
		local short = cost - held
		return ("Need %d more %s. Turn up to a street event to earn them."):format(
			short, Config.tokenWord(short))
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
function ChestService.open(player: Player, chestKey: string)
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
	local held = if currency == "tokens" then math.floor(data.tokens or 0) else data.coins
	if held < chest.cost then
		notify(player, shortfallMessage(chest, held, chest.cost), "warn")
		return
	end

	local tier = pickTier(odds)
	if not tier then
		return
	end
	local entries = pool[tier]
	local entry = entries[math.random(1, #entries)]
	local kind, key = splitEntry(chest, entry)

	-- Charged only once the outcome exists. A chest that took the money and
	-- then found nothing to hand over would be the one failure mode here that
	-- looks like theft.
	if not spend(data, currency, chest.cost) then
		return
	end

	local duplicate = SetService.owns(data, kind, key)
	if duplicate then
		data.shards[tier] = (data.shards[tier] or 0) + 1
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
		-- The odds the server ACTUALLY used, so the reel can print real
		-- percentages. Printing the number is what makes this honest rather
		-- than merely true, and it costs nothing now that nothing requires it.
		odds = odds,
	})
	return tier, kind, key, duplicate
end

-- Three shards of a tier for one roll at a higher one.
--
-- THE TARGET CHEST IS THE PLAYER'S CHOICE AND MUST BE A COIN CHEST. Shards are
-- global, so they would otherwise be a route into event loot for somebody who
-- never attended an event -- and attendance being the only route is the entire
-- point of that currency.
function ChestService.combine(player: Player, tier: string, chestKey: string)
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
	local have = data.shards[tier] or 0
	if have < need then
		notify(player, ("Need %d more %s shards."):format(need - have, tier), "warn")
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

	data.shards[tier] = have - need

	local entry = entries[math.random(1, #entries)]
	local kind, key = splitEntry(chest, entry)
	local duplicate = SetService.owns(data, kind, key)
	if duplicate then
		data.shards[target] = (data.shards[target] or 0) + 1
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
		combined = true,
		climb = climb,
	})
	return target, kind, key, duplicate
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
					local kind, itemKey = splitEntry(chest, entry)
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

	Remotes.get("ChestState"):FireClient(player, {
		chests = chests,
		shards = data.shards,
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

	Remotes.get("ChestCombine").OnServerEvent:Connect(function(player, tier, chestKey)
		if type(tier) ~= "string" or type(chestKey) ~= "string" then
			return
		end
		-- The tier is checked against the real list rather than trusted: a
		-- client naming a field is how a save gets arbitrary keys in it, which
		-- is the same reason SettingsService is an allowlist.
		if not table.find(TIERS, tier) then
			return
		end
		ChestService.combine(player, tier, chestKey)
	end)

end

return ChestService
