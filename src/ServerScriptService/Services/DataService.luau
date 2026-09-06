--!strict
--[[
	DataService

	Session-locked player persistence.

	The lock is the whole point. Without it, the same player joining two
	servers at once ends up with two live copies of their piggy bank, and whichever
	server saves last wins -- which is the classic Roblox duplication exploit.
	Every load claims a lock; every release clears it; a lock left behind by a
	crashed server goes stale and gets stolen after LOCK_STALE_SECONDS.

	If DataStores are unavailable (Studio with API access turned off), this
	falls back to in-memory storage so development still works. It says so
	loudly, because shipping in that state would silently lose every player.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = {}

export type PlayerData = {
	schema: number,
	-- THE PIGGY BANK. One balance, all of it in the pig, all of it stealable.
	-- `vault` used to be the stealable half and `coins` the banked half;
	-- schema 17 merged them (see reconcile), because the split was the reason
	-- nobody robbed anybody -- CLAUDE.md, THE ROBBING PIVOT.
	coins: number,
	-- How many times this account has joined a server. The first session gets
	-- the long new-player shield; every later one gets the short join shield.
	sessions: number,
	incomeLevel: number,
	capacityLevel: number,
	rebirths: number,
	-- Daily claim. `lastDay` is a UTC day index, not a timestamp: the only
	-- question ever asked of it is which day it was, and storing the day
	-- directly means no timezone can get between the save and the answer.
	daily: { lastDay: number, streak: number, lifetime: number },
	-- Boosts held, by key, and the wall-clock second the active one ends.
	-- Held rather than applied on claim -- see Config.BOOSTS for why.
	boosts: { [string]: number },
	boostUntil: number,
	boostMult: number,
	lastSave: number,
	totalStolen: number,
	totalLost: number,
	-- MOST WANTED GEAR: worn by the player's own character, never bought.
	--
	-- `escapes` is the lifetime count of most-wanted pursuits survived and is
	-- what unlocks the tiers; `unlocked` is what they have earned; `worn` is the
	-- one piece actually on, or "" for none. Three fields rather than two
	-- because the counter has to survive the unlock -- later tiers are further
	-- up the same ladder, so throwing the count away at tier 1 would restart
	-- everyone at zero for tier 2.
	--
	-- NEVER RESET BY REBIRTH, like every other cosmetic. Rebirth already costs
	-- a player every upgrade they own; the collection is the reason to press
	-- the button.
	gear: {
		unlocked: { [string]: boolean },
		worn: string,
		escapes: number,
	},
	upgrades: { [string]: number },
	-- Prestige, not power. Never reset by rebirth.
	--
	-- Two numbers: `houseLevel` is the highest tier bought and decides what is
	-- for sale next; `houseShown` is the one actually standing on the plot,
	-- because an owner can move back into any tier they own. Read them through
	-- Config.getShownHouseLevel rather than separately.
	houseLevel: number,
	-- SPARE COPIES, one count per item, keyed "kind:key" -- the grammar
	-- `Config.chestEntry` already owns, because a bare key does not say
	-- which of the five catalogues it came from. There are no collisions across
	-- the 92 keys today, and that is exactly the sort of fact that stops being
	-- true quietly.
	--
	-- A SPARE IS AN EXTRA COPY. Ownership lives in the five owned tables and
	-- this counts what is held BEYOND the one that grants it, so a non-zero
	-- entry always implies ownership and selling the last spare leaves the
	-- player still owning one. Spares are sold for coins or combined by tier --
	-- see Config.COMBINE and Config.sellValue.
	spares: { [string]: number },
	-- LOOT. The second currency and the only one besides coins: earned by
	-- delivering a robbery (and at events when they return), never
	-- purchasable, and what the accessory roll and the set items cost. Schema
	-- 17 merged the old `medals` and `tokens` fields into it one-for-one.
	--
	-- Never wiped by rebirth, like every other cosmetic track.
	loot: number,
	houseShown: number,
	decor: {
		owned: { [string]: boolean },
		-- slot id -> item key. Auto-assigned on purchase.
		placed: { [string]: string },
	},
	-- Rebirths since the last legendary drop, for the pity floor.
	sinceLegendary: number,
	cosmetics: {
		owned: { [string]: boolean },
		ownedEffects: { [string]: boolean },
		skin: string,
		effect: string,
	},
	-- Client-side preferences. Nothing in here may ever affect what a player
	-- can do -- these are read by the HUD and by nothing that decides an
	-- outcome, which is what keeps them safe to let a client write.
	settings: { music: boolean, hotbar: { order: { string }, hidden: { string } } },
}

local store: DataStore? = nil
local usingFallback = false
local fallbackStore: { [string]: any } = {}

local cache: { [Player]: PlayerData } = {}
local loading: { [Player]: boolean } = {}

local JOB_ID = if game.JobId ~= "" then game.JobId else "studio-" .. tostring(os.time())

local function defaultData(): PlayerData
	local upgrades: { [string]: number } = {}
	for key in pairs(Config.UPGRADES) do
		upgrades[key] = 0
	end

	return {
		schema = Config.SCHEMA_VERSION,
		coins = 0,
		sessions = 0,
		incomeLevel = 1,
		capacityLevel = 1,
		rebirths = 0,
		lastSave = os.time(),
		totalStolen = 0,
		totalLost = 0,
		upgrades = upgrades,
		houseLevel = 0,
		houseShown = 0,
		-- LOOT. Flat, never scaled by income, never wiped by rebirth -- it buys
		-- cosmetics, which are the permanent track. See the type above.
		loot = 0,
		-- Spare copies by "kind:key". Missing keys read as zero, so an item
		-- added later needs no migration -- the shape `consumables` uses.
		spares = {},
		decor = { owned = {}, placed = {} },
		-- Bone stock, by key. Counts only; missing keys read as zero, so a
		-- bone added later needs no migration.
		--
		-- NOT wiped by rebirth, unlike every other offensive purchase. A bone
		-- is spent the moment it is thrown, so a stockpile is not standing
		-- power the way a maxed tree is -- and wiping it would only teach
		-- players to burn their stock the hour before rebirthing, which is a
		-- chore, not a decision.
		consumables = {},
		sinceLegendary = 0,
		-- Never reset by rebirth. This is the account's permanent collection.
		-- Rolled, never bought, and never wiped by rebirth -- accessories are
		-- the flex that survives a reset, same bracket as skins and houses.
		-- `worn` is one key per slot; `owned` is the collection.
		accessories = { owned = {}, worn = {} },
		-- What the player gets around on. `equipped` is "" for on foot, and is
		-- a string rather than nil so reconcile's one-level fill can see it --
		-- a nil default is indistinguishable from a field that was never added.
		--
		-- Survives rebirth, like every other purely cosmetic track. A ride
		-- confers nothing in a fight; taking it away at a reset would just be a
		-- reason not to press the button.
		rides = { owned = {}, equipped = "" },
		daily = { lastDay = 0, streak = 0, lifetime = 0 },
		boosts = {},
		boostUntil = 0,
		boostMult = 1,
		-- Schema 13. reconcile descends one level, so an existing save picks up
		-- all three of these rather than just the parent table.
		gear = { unlocked = {}, worn = "", escapes = 0 },
		cosmetics = {
			owned = {},
			ownedEffects = {},
			skin = Config.DEFAULT_SKIN,
			effect = Config.DEFAULT_EFFECT,
		},
		-- Music defaults ON. A player who wants it off finds the toggle once
		-- and it is remembered; defaulting to off would mean nobody ever
		-- hears it and the whole thing may as well not ship.
		-- The hot bar's arrangement, filled by reconcile's one-level descent
		-- for every save written before it existed. Two empty arrays is the
		-- default bar: catalogue order, nothing shelved.
		settings = { music = true, hotbar = { order = {}, hidden = {} } },
	}
end

local function keyFor(player: Player): string
	return "Player_" .. tostring(player.UserId)
end

-- Fills in fields added by later schema versions without touching existing
-- values. Real migrations (renames, rescaling) branch on envelope.schema here.
--
-- Descends one level into table fields, which matters for `upgrades`: adding
-- a seventh upgrade later must fill in just that key on every existing save,
-- not leave it nil because the parent table already existed.
local function reconcile(data: any): PlayerData
	local base = defaultData()
	if type(data) ~= "table" then
		return base
	end

	-- Schema 17: THE PIG IS THE WALLET. `vault` (the stealable pile) and
	-- `coins` (the banked balance) became one field, and `medals` and
	-- `tokens` became `loot`. Both merges are one-for-one and additive, and
	-- both run before the generic fill so the old fields are consumed rather
	-- than left beside a zeroed new one. Idempotent: a save that has already
	-- been through this has no `vault`, `medals` or `tokens` to add.
	if type(data.vault) == "number" then
		data.coins = (tonumber(data.coins) or 0) + data.vault
		data.vault = nil
	end
	if type(data.medals) == "number" or type(data.tokens) == "number" then
		data.loot = (tonumber(data.loot) or 0)
			+ (tonumber(data.medals) or 0) + (tonumber(data.tokens) or 0)
		data.medals = nil
		data.tokens = nil
	end

	-- Schema 18: `shards` (a counter per rarity tier) became `spares` (a count
	-- per item), and the old field is DROPPED rather than converted.
	--
	-- There is nothing to convert -- a tier counter cannot say which item it
	-- came from -- and nothing to lose, because there was no chest UI anywhere
	-- when this shipped: the only shards that have ever existed came out of the
	-- admin console. Doing it now is what makes that true, and it is the whole
	-- reason this landed before the tab rather than after it.
	--
	-- Nothing is refunded, exactly as the retired ornaments below are not. A
	-- version that DID pay out would have to be measured idempotent first, and
	-- one that pays on every join is a money printer -- a far worse bug than
	-- the one being fixed.
	data.shards = nil

	-- Schema 9 split the house into "highest owned" and "currently shown".
	--
	-- This has to run BEFORE the generic fill below, which would otherwise
	-- give every existing save the default houseShown of 0 and evict a player
	-- with a Sky Castle into a Starter Shack. A save from before the split was
	-- always living in its newest house, so that is what it migrates to.
	if data.houseShown == nil and type(data.houseLevel) == "number" then
		data.houseShown = data.houseLevel
	end

	-- DECOR IS PRUNED AGAINST THE CATALOGUE, not against a list of names.
	--
	-- Retiring the Wheelie Bins and the two parked cars left dead keys in
	-- every save that owned one, and a `placed` entry pointing at an item or a
	-- slot that no longer exists -- the driveway slot went with the cars.
	-- Neither errors: `Decor.buildOne` simply returns nil and the ornament
	-- quietly never appears, which is the failure mode this project spends the
	-- most words on.
	--
	-- Written against the catalogue rather than as a one-off migration on
	-- purpose. Anything retired later is handled with no new code and no
	-- version to remember, and there is no table sitting in Config that
	-- somebody has to notice is safe to delete. It is also cheap: a handful of
	-- keys, once, on load.
	--
	-- Nothing is refunded. The game is in beta; a retired ornament is simply
	-- gone.
	if type(data.decor) == "table" then
		if type(data.decor.owned) == "table" then
			for key in pairs(data.decor.owned) do
				if not Config.DECOR_ITEMS[key] then
					data.decor.owned[key] = nil
				end
			end
		end
		if type(data.decor.placed) == "table" then
			local realSlot = {}
			for _, slot in ipairs(Config.DECOR_SLOTS) do
				realSlot[slot.id] = true
			end
			for slot, key in pairs(data.decor.placed) do
				if not realSlot[slot] or not Config.DECOR_ITEMS[key] then
					data.decor.placed[slot] = nil
				end
			end
		end
	end

	for key, value in pairs(base) do
		if data[key] == nil then
			data[key] = value
		elseif type(value) == "table" and type(data[key]) == "table" then
			for innerKey, innerValue in pairs(value) do
				if data[key][innerKey] == nil then
					data[key][innerKey] = innerValue
				end
			end
		end
	end

	data.schema = Config.SCHEMA_VERSION
	return data
end

local function lockIsStale(lock: any): boolean
	if type(lock) ~= "table" or type(lock.timestamp) ~= "number" then
		return true
	end
	return (os.time() - lock.timestamp) > Config.LOCK_STALE_SECONDS
end

-- ============================================================
-- BACKEND
-- ============================================================

local function initStore()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DATASTORE_NAME)
	end)

	if ok and result then
		-- GetDataStore succeeds even with API access off; the failure only
		-- shows up on a real request. Probe with a cheap read.
		local probeOk = pcall(function()
			return result:GetAsync("__probe__")
		end)
		if probeOk then
			store = result
			return
		end
	end

	usingFallback = true
	warn(string.rep("=", 70))
	warn("[DataService] DataStores unavailable -- using IN-MEMORY fallback.")
	warn("  Progress will NOT persist across sessions or servers.")
	warn("  Fix: Studio > File > Game Settings > Security >")
	warn("       'Enable Studio Access to API Services'.")
	warn(string.rep("=", 70))
end

-- Runs `transform` against the stored envelope, retrying on transient failure.
local function updateEnvelope(key: string, transform: (any) -> any?): (boolean, any)
	if usingFallback then
		local updated = transform(fallbackStore[key])
		if updated == nil then
			return false, nil
		end
		fallbackStore[key] = updated
		return true, updated
	end

	local activeStore = store
	if not activeStore then
		return false, nil
	end

	local result: any = nil
	for attempt = 1, 4 do
		local ok, err = pcall(function()
			activeStore:UpdateAsync(key, function(existing)
				local updated = transform(existing)
				result = updated
				return updated
			end)
		end)

		if ok then
			return result ~= nil, result
		end

		warn(("[DataService] UpdateAsync failed for %s (attempt %d): %s"):format(key, attempt, tostring(err)))
		task.wait(attempt * 2)
	end

	return false, nil
end

-- ============================================================
-- PUBLIC API
-- ============================================================

-- Claims the session lock and loads the player's data. Returns nil if the
-- lock could not be claimed, in which case the caller should kick the player
-- rather than let them play against unsaved state.
function DataService.load(player: Player): PlayerData?
	if cache[player] then
		return cache[player]
	end
	if loading[player] then
		return nil
	end
	loading[player] = true

	local key = keyFor(player)
	local claimed: PlayerData? = nil

	-- A live lock usually means the player's previous server hasn't finished
	-- releasing yet. Give it a few seconds before treating it as contested.
	for attempt = 1, 5 do
		local ok, envelope = updateEnvelope(key, function(existing)
			local lock = existing and existing.lock

			if lock and not lockIsStale(lock) and lock.jobId ~= JOB_ID then
				return nil -- someone else holds it; abort this write
			end

			return {
				lock = { jobId = JOB_ID, timestamp = os.time() },
				data = existing and existing.data or defaultData(),
			}
		end)

		if ok and envelope then
			claimed = reconcile(envelope.data)
			break
		end

		if attempt < 5 then
			task.wait(2)
		end
	end

	loading[player] = nil

	if not claimed then
		warn(("[DataService] Could not claim lock for %s"):format(player.Name))
		return nil
	end

	-- Counted on load rather than by a caller, so nothing can forget to. The
	-- shield reads this on the same join.
	claimed.sessions = (claimed.sessions or 0) + 1

	cache[player] = claimed
	return claimed
end

function DataService.get(player: Player): PlayerData?
	return cache[player]
end

-- Writes current data and refreshes the lock timestamp. Keeps the lock held.
function DataService.save(player: Player): boolean
	local data = cache[player]
	if not data then
		return false
	end

	data.lastSave = os.time()

	local ok = updateEnvelope(keyFor(player), function(existing)
		local lock = existing and existing.lock
		-- Only write if we still hold the lock. If another server stole it
		-- (because we went unresponsive), our data is stale -- drop it rather
		-- than clobber theirs.
		if lock and lock.jobId ~= JOB_ID and not lockIsStale(lock) then
			return nil
		end
		return {
			lock = { jobId = JOB_ID, timestamp = os.time() },
			data = data,
		}
	end)

	return ok
end

-- Final write, then clears the lock so the player can join elsewhere.
function DataService.release(player: Player)
	local data = cache[player]
	if not data then
		return
	end

	data.lastSave = os.time()

	updateEnvelope(keyFor(player), function(existing)
		local lock = existing and existing.lock
		if lock and lock.jobId ~= JOB_ID and not lockIsStale(lock) then
			return nil
		end
		return { lock = nil, data = data }
	end)

	cache[player] = nil
end

function DataService.start()
	initStore()

	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_INTERVAL)
			for player in pairs(cache) do
				if player.Parent then
					DataService.save(player)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		DataService.release(player)
	end)

	-- Studio gives BindToClose very little time; live servers get 30s.
	game:BindToClose(function()
		if RunService:IsStudio() and usingFallback then
			return
		end
		local pending = 0
		for player in pairs(cache) do
			pending += 1
			task.spawn(function()
				DataService.release(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

function DataService.isUsingFallback(): boolean
	return usingFallback
end

return DataService
