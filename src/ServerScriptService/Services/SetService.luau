--!strict
--[[
	SetService

	Medals, and the themed sets they buy.

	A SET IS A VIEW OVER THE EXISTING CATALOGUES, NEVER A NEW CATALOGUE.
	`Config.SETS` lists `{kind, key}` pairs pointing at items that live in
	Config.SKINS, EFFECTS, ACCESSORIES, DECOR_ITEMS and RIDES as ordinary
	members. So there is no new ownership storage, no new save field per item
	and no new equip path -- each item stays in the system that already knows
	how to build, price, render and wear it, and this file only knows which
	table to tick and which service to tell.

	WHY MEDALS ARE FLAT. Every other reward in this game is denominated in
	seconds of the player's own income, precisely so it keeps meaning the same
	thing as they grow. Medals do the opposite ON PURPOSE: a set costs the
	same number of events for a brand-new player as for a maxed one, so the
	ladder measures ATTENDANCE and nothing else. Coins scale with the player;
	medals scale with turning up, and a rich player cannot buy their way up
	this one.

	NOTHING IS EVER LOCKED BEHIND LUCK. Every set item carries a medal price,
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
	end
	return nil
end

function SetService.owns(data: any, kind: string, key: string): boolean
	local owned = ownedTable(data, kind)
	return owned ~= nil and owned[key] == true
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
-- MEDALS
-- ============================================================

function SetService.getMedals(player: Player): number
	local data = DataService.get(player)
	return if data then math.floor(data.medals or 0) else 0
end

function SetService.award(player: Player, amount: number, why: string): number
	local data = DataService.get(player)
	if not data or amount <= 0 then
		return 0
	end
	data.medals = (data.medals or 0) + amount
	Remotes.get("Notify"):FireClient(player,
		("%s +%d medals."):format(why, amount), "money")
	SetService.push(player)
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
	-- price: medals must never be an alternative currency for the ordinary
	-- catalogue, or every coin price in the game has a second, cheaper route.
	local price = spec.medals
	if type(price) ~= "number" or price <= 0 then
		refuse("That isn't bought with medals.")
		return
	end

	if SetService.owns(data, kind, key) then
		refuse(("You already have the %s."):format(spec.name))
		return
	end

	local have = math.floor(data.medals or 0)
	if have < price then
		refuse(("Need %d more medals for the %s."):format(price - have, spec.name))
		return
	end

	data.medals = have - price
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
-- every set into a wall -- and the medal price is already the ladder that
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
		SetService.award(player, Config.MEDALS.setComplete,
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
				medals = spec and spec.medals or 0,
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
		medals = math.floor(data.medals or 0),
		sets = sets,
	})
end

function SetService.start()
	Remotes.get("MedalBuy").OnServerEvent:Connect(function(player, kind, key)
		if type(kind) ~= "string" or type(key) ~= "string" then
			return
		end
		SetService.buy(player, kind, key)
	end)
end

return SetService
