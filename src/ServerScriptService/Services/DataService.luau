--!strict
--[[
	DataService

	Session-locked player persistence.

	The lock is the whole point. Without it, the same player joining two
	servers at once ends up with two live copies of their vault, and whichever
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
	coins: number,      -- banked and permanently safe
	vault: number,      -- uncollected and stealable
	incomeLevel: number,
	capacityLevel: number,
	rebirths: number,
	lastSave: number,
	totalStolen: number,
	totalLost: number,
	upgrades: { [string]: number },
	-- Prestige, not power. Never reset by rebirth.
	--
	-- Two numbers: `houseLevel` is the highest tier bought and decides what is
	-- for sale next; `houseShown` is the one actually standing on the plot,
	-- because an owner can move back into any tier they own. Read them through
	-- Config.getShownHouseLevel rather than separately.
	houseLevel: number,
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
		vault = 0,
		incomeLevel = 1,
		capacityLevel = 1,
		rebirths = 0,
		lastSave = os.time(),
		totalStolen = 0,
		totalLost = 0,
		upgrades = upgrades,
		houseLevel = 0,
		houseShown = 0,
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
		cosmetics = {
			owned = {},
			ownedEffects = {},
			skin = Config.DEFAULT_SKIN,
			effect = Config.DEFAULT_EFFECT,
		},
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

	-- Schema 9 split the house into "highest owned" and "currently shown".
	--
	-- This has to run BEFORE the generic fill below, which would otherwise
	-- give every existing save the default houseShown of 0 and evict a player
	-- with a Sky Castle into a Starter Shack. A save from before the split was
	-- always living in its newest house, so that is what it migrates to.
	if data.houseShown == nil and type(data.houseLevel) == "number" then
		data.houseShown = data.houseLevel
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
