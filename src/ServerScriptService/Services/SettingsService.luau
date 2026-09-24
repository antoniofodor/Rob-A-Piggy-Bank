--!strict
--[[
	SettingsService

	The player's own preferences: what they have chosen about how the game
	presents itself, as opposed to anything they have earned or bought.

	THE ALLOWLIST IS THE WHOLE SERVICE.

	A settings channel is a client saying "write this key into my save", which
	is the one shape of request that has to be treated as hostile by default.
	Without the check below, `SettingRequest` is an API for stuffing arbitrary
	keys and arbitrary values into persisted player data -- a slow way to
	bloat every save in the game until they stop fitting, and a fast way to
	collide with a field a later feature wants to use. So the key is matched
	against a table here, the value is type-checked, and anything else is
	dropped without comment.

	It is also why this is a service of its own rather than a field bolted on
	to an existing push: settings are the one thing a client is allowed to
	write, and that deserves one file to audit rather than being spread across
	whichever service happened to be nearby.

	NOTHING IN HERE MAY AFFECT AN OUTCOME. These are read by the HUD and by
	nothing that decides anything -- no speed, no income, no odds. That is
	what makes them safe to let a client set at all, and any future setting
	has to clear the same bar before it goes in the table below.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local SettingsService = {}

-- Every key a hot bar slot can belong to, built from the catalogues that put
-- slots on it -- the four throwables and the lassos. Derived rather than
-- listed, so an item added to any of them is arrangeable with no line to
-- remember here -- and, more to the point, so nothing that is NOT one of them
-- can ever be written into a save.
local THROWABLE: { [string]: boolean } = {}
for _, catalogue in ipairs({ Config.BONES, Config.GADGETS, Config.HOME_ITEMS, Config.THIEF_KIT, Config.LASSOS or {} }) do
	for key in pairs(catalogue) do
		THROWABLE[key] = true
	end
end

-- An array of distinct known item keys, and nothing else. This is the whole
-- reason the allowlist below became functions instead of type names: a table
-- value cannot be checked by asking `type(value) == "table"`, because that
-- accepts a table of any shape and any SIZE -- which is precisely the "bloat
-- every save in the game until they stop fitting" attack this file exists to
-- refuse. A sanitiser that rebuilds the value from known-good parts cannot be
-- talked into storing anything unbounded.
local function itemKeys(value: any): { string }
	local out = {}
	local seen: { [string]: boolean } = {}
	if type(value) ~= "table" then
		return out
	end
	for _, key in ipairs(value) do
		if type(key) == "string" and THROWABLE[key] and not seen[key] then
			seen[key] = true
			table.insert(out, key)
		end
	end
	return out
end

-- key -> a function returning the value to STORE, or nil to refuse the write.
--
-- Sanitising rather than type-checking. The old table mapped a key to a type
-- name, which is enough while every setting is a boolean and not nearly enough
-- for anything with a shape. Adding a setting means adding a line here and a
-- default in DataService's template, and nothing else.
local ALLOWED: { [string]: (any) -> any } = {
	music = function(value)
		return if type(value) == "boolean" then value else nil
	end,

	-- The music volume slider's POSITION, 0..1. A number from a client is
	-- checked for NaN and infinity before it is clamped, because `math.clamp`
	-- passes a NaN straight through and a NaN in a save is a value nothing can
	-- compare against. Rounded to a hundredth so a drag cannot store noise.
	musicVolume = function(value)
		if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
			return nil
		end
		return math.floor(math.clamp(value, 0, 1) * 100 + 0.5) / 100
	end,

	-- The hot bar's arrangement: which order the player dragged their
	-- throwables into, and which ones they took off the bar.
	--
	-- This clears the "may never affect an outcome" bar below with room to
	-- spare. It moves tiles. A shelved slot is still held, still throwable by
	-- its own number key, and still bought and spent by the same services --
	-- nothing in here can reach a stock, a coin or a cooldown.
	hotbar = function(value)
		if type(value) ~= "table" then
			return nil
		end
		return { order = itemKeys(value.order), hidden = itemKeys(value.hidden) }
	end,
}

function SettingsService.push(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	Remotes.get("SettingState"):FireClient(player, data.settings)
end

function SettingsService.start()
	Remotes.get("SettingRequest").OnServerEvent:Connect(function(player, key, value)
		local check = if type(key) == "string" then ALLOWED[key] else nil
		if not check then
			return
		end
		local clean = check(value)
		if clean == nil then
			return
		end

		local data = DataService.get(player)
		if not data then
			return
		end
		(data.settings :: any)[key] = clean

		-- NOT SAVED HERE, deliberately. A preference is worth a field in the
		-- save and not a DataStore write per press: the autosave loop and the
		-- write on leaving both already carry it, and a player flicking a
		-- toggle would otherwise be hammering a budgeted API. The only thing
		-- lost is a preference changed in the seconds before a server crash.
		--
		-- Echoed back regardless, so a client that asked for something the
		-- allowlist refused sees the real value rather than keeping its guess.
		SettingsService.push(player)
	end)
end

return SettingsService
