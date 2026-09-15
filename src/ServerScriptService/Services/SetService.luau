--!strict
--[[
	SetService

	Loot, and the themed sets it buys.

	A SET IS A VIEW OVER THE EXISTING CATALOGUES, NEVER A NEW CATALOGUE.
	`Config.SETS` lists `{kind, key}` pairs pointing at items that live in
	Config.SKINS, EFFECTS, ACCESSORIES, DECOR_ITEMS and RIDES as ordinary
	members. So there is no new ownership storage, no new save field per item
	and no new equip path -- each item stays in the system that already knows
	how to build, price, render and wear it, and this file only knows which
	table to tick and which service to tell.

	WHY LOOT IS FLAT. Every other reward in this game is denominated in
	seconds of the player's own income, precisely so it keeps meaning the same
	thing as they grow. Loot does the opposite ON PURPOSE: a set costs the
	same number of robberies (or events) for a brand-new player as for a maxed
	one, so the ladder measures DOING IT and nothing else. Coins scale with
	the player; loot scales with going out, and a rich player cannot buy
	their way up this one.

	THIS IS THE ONE PLACE LOOT IS GRANTED. `award` is what a delivery, an
	event and the dev console all call, so a balance can never move without
	both of its readers -- the set panel here and the roll button in
	CosmeticsService, reached through a registered pusher -- being told.

	NOTHING IS EVER LOCKED BEHIND LUCK. Every set item carries a loot price,
	so a drop only ever saves you time. That is the line that makes a wheel
	safe to show a nine-year-old: bad luck costs them a wait, never the item.

	THIS FILE REQUIRES ONLY DataService, AND THAT IS DELIBERATE.

	Granting a ride has to tell RideService, and granting a skin has to tell
	CosmeticsService -- but RideService requires HeistService, which requires
	EventService, which needs this file. Requiring the services directly is
	therefore a cycle. So the pushes are a REGISTRY that `Main` fills in at
	startup, which keeps this module's dependency list to one line and the
	cycle impossible rather than merely absent today.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local SetService = {}

-- kind -> the function that re-pushes that catalogue's state to one player.
-- Filled by Main. A kind with no pusher still GRANTS correctly; the player
-- just does not see it until the next push, which is a display bug rather
-- than a lost item.
local pushers: { [string]: (Player) -> () } = {}

function SetService.registerPusher(kind: string, fn: (Player) -> ())
	pushers[kind] = fn
end

-- Anything else that shows the loot balance. Filled by Main with
-- CosmeticsService.push, which carries the roll button's balance.
local lootPushers: { (Player) -> () } = {}

function SetService.registerLootPusher(fn: (Player) -> ())
	table.insert(lootPushers, fn)
end

-- WHERE EACH KIND KEEPS ITS OWNERSHIP. Five different tables, because five
-- different services got there first and each one is right about its own
-- data. One lookup here beats a five-branch `if` at every call site.
local function ownedTable(data: any, kind: string): { [string]: boolean }?
	if kind == "skin" then
		return data.cosmetics.owned
	elseif kind == "effect" then
		return data.cosmetics.ownedEffects
	elseif kind == "accessory" then
		return data.accessories.owned
	elseif kind == "decor" then
		return data.decor.owned
	elseif kind == "ride" then
		return data.rides.owned
	elseif kind == "catch" then
		-- The sixth kind, and it cost exactly these two lines plus the two
		-- in `inUse` -- which is the argument for `Config.catalogueFor`
		-- existing at all. Guarded, because a save written before schema 21
		-- reaches this before `reconcile` has filled the table in on some
		-- paths, and a nil index here would take a grant down.
		return data.catch and data.catch.owned
	end
	return nil
end

function SetService.owns(data: any, kind: string, key: string): boolean
	local owned = ownedTable(data, kind)
	return owned ~= nil and owned[key] == true
end

-- IS THIS THE COPY THEY ARE ACTUALLY USING?
--
-- The one guard on selling a LAST copy. Selling a spare is safe by definition
-- -- another one stays behind -- but the last copy takes the item away, and
-- the failure that matters for a nine-year-old is not the exploit, it is the
-- accident: a stray thumb selling the legendary they spent three weeks getting.
--
-- Requiring it to be taken off first is one tap, it is learnable in a second,
-- and it kills exactly the accidental case without a lock flag to teach. It is
-- also the honest reading of what a sale is: you cannot hand over the thing
-- you are stood there wearing.
--
-- FIVE KINDS, FIVE PLACES, because five services got there first and each one
-- is right about its own data -- the same reason `ownedTable` exists. Note the
-- two that are maps rather than fields: an accessory is worn per SLOT and a
-- decoration is placed per SLOT, so both want a scan.
function SetService.inUse(data: any, kind: string, key: string): boolean
	if kind == "skin" then
		return data.cosmetics.skin == key
	elseif kind == "effect" then
		return data.cosmetics.effect == key
	elseif kind == "ride" then
		return data.rides.equipped == key
	elseif kind == "catch" then
		return (data.catch and data.catch.equipped) == key
	elseif kind == "accessory" then
		for _, worn in pairs(data.accessories.worn) do
			if worn == key then
				return true
			end
		end
		return false
	elseif kind == "decor" then
		for _, placed in pairs(data.decor.placed) do
			if placed == key then
				return true
			end
		end
		return false
	end
	return false
end

-- The exact inverse of `grant`, and it has to be, or half the game goes on
-- rendering something the save no longer says is owned.
--
-- It refuses anything in use rather than quietly unequipping it: the caller
-- has already been told to take it off, and a revoke that silently strips the
-- player's own skin off their pig is the surprise this whole guard exists to
-- prevent. Pushes and saves on the same two channels `grant` does -- the item's
-- own service AND the set panel, which are two different questions.
function SetService.revoke(player: Player, kind: string, key: string): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	local owned = ownedTable(data, kind)
	if not owned or not owned[key] or SetService.inUse(data, kind, key) then
		return false
	end
	owned[key] = nil

	local push = pushers[kind]
	if push then
		push(player)
	end
	SetService.push(player)
	DataService.save(player)
	return true
end

-- Everything in a set the player does NOT have. This is the roll pool and it
-- is rebuilt every time, which is what makes duplicates impossible: an item
-- leaves the pool the moment it is won, so there is nothing to protect
-- against later and no pity timer to tune. It also means the odds visibly
-- improve as the set fills, which is the honest version of what a crate only
-- pretends to do -- and is why the wheel can print real percentages.
function SetService.unowned(data: any, setKey: string): { { kind: string, key: string } }
	local set = Config.SETS[setKey]
	local out = {}
	if not set then
		return out
	end
	for _, entry in ipairs(set.items) do
		if not SetService.owns(data, entry.kind, entry.key) then
			table.insert(out, { kind = entry.kind, key = entry.key })
		end
	end
	return out
end

function SetService.progress(data: any, setKey: string): (number, number)
	local set = Config.SETS[setKey]
	if not set then
		return 0, 0
	end
	local have = 0
	for _, entry in ipairs(set.items) do
		if SetService.owns(data, entry.kind, entry.key) then
			have += 1
		end
	end
	return have, #set.items
end

-- Marks one item owned and tells whatever service renders it. Returns false
-- if they already had it, so callers never double-count a grant.
function SetService.grant(player: Player, kind: string, key: string): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	local owned = ownedTable(data, kind)
	if not owned or owned[key] then
		return false
	end
	owned[key] = true

	local push = pushers[kind]
	if push then
		push(player)
	end
	-- AND the set state itself, which is a separate push and was the bug:
	-- telling CosmeticsService about a new skin does not tell the SET panel
	-- anything, so a player won an item and watched their progress stay at
	-- 0/6. Measured on the first real drop.
	SetService.push(player)
	DataService.save(player)
	return true
end

-- ============================================================
-- LOOT
-- ============================================================

function SetService.getLoot(player: Player): number
	local data = DataService.get(player)
	return if data then math.floor(data.loot or 0) else 0
end

-- `why` is OPTIONAL and nil means silent: the caller owns the wording, not
-- the choice of whether to speak. A delivery folds the loot into its own
-- card rather than firing a second one at a nine-year-old; nothing is ever
-- granted with nothing on screen.
function SetService.award(player: Player, amount: number, why: string?): number
	local data = DataService.get(player)
	if not data or amount <= 0 then
		return 0
	end
	data.loot = math.floor((data.loot or 0) + amount)
	if why then
		Remotes.get("Notify"):FireClient(player,
			("%s +%d %s."):format(why, amount, Config.lootWord(amount)), "money")
	end
	SetService.push(player)
	for _, fn in ipairs(lootPushers) do
		fn(player)
	end
	return amount
end

-- ============================================================
-- BUYING
-- ============================================================
--
-- The price is READ FROM CONFIG here and never sent by the client. The
-- request carries a kind and a key and nothing else, which is the same shape
-- every other purchase in this game uses and the reason there is no number
-- on the wire to forge.

function SetService.buy(player: Player, kind: string, key: string)
	local data = DataService.get(player)
	local spec = Config.getSetItem(kind, key)
	if not data or not spec then
		return
	end

	local function refuse(message: string)
		Remotes.get("Notify"):FireClient(player, message, "warn")
	end

	-- Not a set item at all. Refused rather than falling through to a coin
	-- price: loot must never be an alternative currency for the ordinary
	-- catalogue, or every coin price in the game has a second, cheaper route.
	local price = spec.loot
	if type(price) ~= "number" or price <= 0 then
		refuse("That isn't bought with loot.")
		return
	end

	if SetService.owns(data, kind, key) then
		refuse(("You already have the %s."):format(spec.name))
		return
	end

	local have = math.floor(data.loot or 0)
	if have < price then
		refuse(("Need %d more loot for the %s. Rob a neighbour."):format(price - have, spec.name))
		return
	end

	data.loot = have - price
	SetService.grant(player, kind, key)
	Remotes.get("Notify"):FireClient(player,
		("%s unlocked!"):format(spec.name), "good")
	SetService.push(player)
end

-- ============================================================
-- THE DROP
-- ============================================================

-- Picks one unowned item from a set. THE SERVER DECIDES; the client is only
-- told what it won and what the odds were, so it can animate a wheel landing
-- on an answer it did not choose.
--
-- Flat odds across the unowned pool rather than rarity-weighted. Rarity here
-- would mean the ride is the one you almost never get, which turns the end of
-- every set into a wall -- and the loot price is already the ladder that
-- makes the ride the last thing you own.
function SetService.rollDrop(player: Player, setKey: string)
	local data = DataService.get(player)
	local set = Config.SETS[setKey]
	if not data or not set then
		return
	end

	local pool = SetService.unowned(data, setKey)

	-- Collection complete. Pay out instead of silently doing nothing, the
	-- same fallback ProgressionService uses when the skin pool is empty: an
	-- event that quietly awards nothing is indistinguishable from a bug.
	if #pool == 0 then
		SetService.award(player, Config.LOOT.event.setComplete,
			("%s set complete!"):format(set.name))
		return
	end

	-- Sorted before drawing, so the same random number picks the same item on
	-- every server. `pairs` order is undefined and an unreproducible roll is
	-- one nobody can investigate when a player reports a bad one.
	table.sort(pool, function(a, b)
		return a.kind .. a.key < b.kind .. b.key
	end)

	local won = pool[math.random(1, #pool)]
	local spec = Config.getSetItem(won.kind, won.key)
	SetService.grant(player, won.kind, won.key)

	-- The pool goes with it so the wheel has slices to draw and honest
	-- percentages to print. It is sent to SHOW, never to choose.
	Remotes.get("EventDrop"):FireClient(player, {
		set = setKey,
		setName = set.name,
		tone = set.tone,
		won = { kind = won.kind, key = won.key, name = spec and spec.name or won.key },
		pool = pool,
		odds = 1 / #pool,
	})
end

function SetService.push(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end

	local sets = {}
	for key, set in pairs(Config.SETS) do
		local items = {}
		for _, entry in ipairs(set.items) do
			local spec = Config.getSetItem(entry.kind, entry.key)
			table.insert(items, {
				kind = entry.kind,
				key = entry.key,
				name = spec and spec.name or entry.key,
				loot = spec and spec.loot or 0,
				owned = SetService.owns(data, entry.kind, entry.key),
			})
		end
		local have, total = SetService.progress(data, key)
		sets[key] = {
			name = set.name, order = set.order, tone = set.tone,
			blurb = set.blurb, items = items, have = have, total = total,
		}
	end

	Remotes.get("SetState"):FireClient(player, {
		loot = math.floor(data.loot or 0),
		sets = sets,
	})
end

function SetService.start()
	Remotes.get("LootBuy").OnServerEvent:Connect(function(player, kind, key)
		if type(kind) ~= "string" or type(key) ~= "string" then
			return
		end
		SetService.buy(player, kind, key)
	end)
end

return SetService
