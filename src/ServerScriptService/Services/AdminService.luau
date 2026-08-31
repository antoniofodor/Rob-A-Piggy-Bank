--!strict
--[[
	AdminService

	A developer console for the owner. Grant coins, set upgrade levels, jump to
	late-game state, and clear the new-player shield so a two-player test does
	not start with fifteen minutes of nothing happening.

	SECURITY MODEL

	The only thing that grants access is this file, on the server, checking
	`isAdmin` at the top of the one and only handler. Everything else is
	convenience.

	In particular, the client panel is NOT a security boundary. A RemoteEvent
	exists for every client whether or not their panel was built, and anyone
	can fire it with an exploit -- hiding a button protects nothing. That is
	why authorisation happens here and not in ClientMain, why it happens before
	any argument is even read, and why every rejection is logged with the
	UserId that attempted it.

	Admission on a LIVE server is the Config allowlist OR being the place's own
	creator. The second exists so this keeps working if the experience is
	republished under a different account, which has already happened once.

	In STUDIO everybody is admitted, so local multiplayer tests have a working
	panel on every client. That branch is guarded by RunService:IsStudio() and
	is therefore dead code in production.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local UpgradeService = require(script.Parent.UpgradeService)
local CosmeticsService = require(script.Parent.CosmeticsService)
local ProgressionService = require(script.Parent.ProgressionService)
local HeistService = require(script.Parent.HeistService)
local BoneService = require(script.Parent.BoneService)

local AdminService = {}

local function notify(player: Player, message: string, kind: string)
	Remotes.get("Notify"):FireClient(player, message, kind)
end

-- The whole gate. Called before anything else, every single request.
function AdminService.isAdmin(player: Player): boolean
	-- Everyone is an admin in Studio.
	--
	-- Studio's local multiplayer test hands its extra clients placeholder
	-- UserIds that will never match a real allowlist entry, so a two-player
	-- test would otherwise have no admin on either client -- exactly when the
	-- panel is most useful, since it is what clears the new-player shield.
	--
	-- This cannot widen access in production: RunService:IsStudio() is false
	-- on every live server, and the allowlist below is the only thing that
	-- admits anyone there.
	if RunService:IsStudio() then
		return true
	end

	if Config.isAdminUserId(player.UserId) then
		return true
	end
	-- Place owner, but only for a user-owned place. A group-owned place has a
	-- CreatorId that is a GROUP id, and comparing it against a UserId would
	-- eventually admit whichever unlucky player's UserId happened to match.
	if game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId then
		return true
	end
	return false
end

-- Reapplies everything a data change implies. Coins and vault ride the
-- economy tick already; upgrades and cosmetics have to be pushed by hand.
local function refresh(player: Player)
	UpgradeService.applyToPlot(player)
	UpgradeService.push(player)
	CosmeticsService.applyToPlot(player)
	CosmeticsService.push(player)
	ProgressionService.push(player)
end

-- ============================================================
-- COMMANDS
-- ============================================================
--
-- Each returns a message to show the caller. Arguments arrive from a client
-- and are therefore untrusted even from an admin: every one is type-checked
-- and clamped rather than used raw.

local commands: { [string]: (Player, any, any) -> string? } = {}

commands.coins = function(player, amount)
	local data = DataService.get(player)
	if not data or type(amount) ~= "number" then
		return nil
	end
	local n = math.clamp(math.floor(amount), -1e12, 1e12)
	data.coins = math.max(0, data.coins + n)
	return ("Coins now %d"):format(math.floor(data.coins))
end

commands.vault = function(player, amount)
	local data = DataService.get(player)
	if not data or type(amount) ~= "number" then
		return nil
	end
	data.vault = math.clamp(math.floor(amount), 0, 1e12)
	local plot = PlotService.getPlot(player)
	if plot then
		PlotService.updatePile(plot, data.vault, Config.getCapacity(data.capacityLevel))
	end
	return ("Vault set to %d"):format(math.floor(data.vault))
end

commands.upgrade = function(player, key, level)
	local data = DataService.get(player)
	local def = type(key) == "string" and Config.UPGRADES[key]
	if not data or not def or type(level) ~= "number" then
		return nil
	end
	data.upgrades[key] = math.clamp(math.floor(level), 0, def.max)
	refresh(player)
	return ("%s set to %d"):format(def.name, data.upgrades[key])
end

commands.house = function(player, level)
	local data = DataService.get(player)
	if not data or type(level) ~= "number" then
		return nil
	end
	data.houseLevel = math.clamp(math.floor(level), 0, Config.MAX_HOUSE_LEVEL)
	local plot = PlotService.getPlot(player)
	if plot then
		PlotService.setHouseLevel(plot, data.houseLevel)
	end
	CosmeticsService.push(player)
	return ("Moved into the %s"):format(Config.getHouseTier(data.houseLevel).name)
end

commands.rebirths = function(player, count)
	local data = DataService.get(player)
	if not data or type(count) ~= "number" then
		return nil
	end
	data.rebirths = math.clamp(math.floor(count), 0, 999)
	refresh(player)
	return ("Rebirths set to %d"):format(data.rebirths)
end

commands.skin = function(player, key)
	local data = DataService.get(player)
	if not data or type(key) ~= "string" or not Config.SKINS[key] then
		return nil
	end
	data.cosmetics.owned[key] = true
	data.cosmetics.skin = key
	CosmeticsService.applyToPlot(player)
	CosmeticsService.push(player)
	return ("Wearing %s"):format(Config.getSkin(key).name)
end

commands.unlockall = function(player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	for key in pairs(Config.SKINS) do
		data.cosmetics.owned[key] = true
	end
	for key in pairs(Config.EFFECTS) do
		data.cosmetics.ownedEffects[key] = true
	end
	data.houseLevel = Config.MAX_HOUSE_LEVEL
	local plot = PlotService.getPlot(player)
	if plot then
		PlotService.setHouseLevel(plot, data.houseLevel)
	end
	CosmeticsService.push(player)
	return "Every skin, effect and house unlocked"
end

commands.maxupgrades = function(player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	for key, def in pairs(Config.UPGRADES) do
		data.upgrades[key] = def.max
	end
	data.incomeLevel = Config.MAX_INCOME_LEVEL
	data.capacityLevel = Config.MAX_CAPACITY_LEVEL
	refresh(player)
	return "All upgrades maxed"
end

-- Puts the dog on cooldown without needing a robbery, so the kennel/sleep
-- cycle can be watched on demand rather than only after a real chase.
commands.dognap = function(player, seconds)
	local plot = PlotService.getPlot(player)
	if not plot then
		return nil
	end
	local secs = if type(seconds) == "number" then math.clamp(seconds, 1, 300) else 20
	plot.dog.busyUntil = os.clock() + secs
	return ("Dog off duty for %ds -- it should head for the kennel"):format(secs)
end

-- Ten of every bone. Testing a bone means throwing it at a dog that is on
-- duty, and a dog is only on duty for the first few seconds of each cycle --
-- so a test run burns stock far faster than it can be earned.
commands.bones = function(player, count)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	if type(data.consumables) ~= "table" then
		data.consumables = {}
	end
	local n = if type(count) == "number" then math.clamp(math.floor(count), 0, 99) else 10
	for key in pairs(Config.BONES) do
		data.consumables[key] = n
	end
	BoneService.push(player)
	return ("%d of every bone"):format(n)
end

commands.shield = function(player)
	local shields, cooldowns = HeistService.openSeason()
	return ("Open season: %d shield(s) dropped, %d cooldown/limit pair(s) cleared"):format(
		shields, cooldowns)
end

commands.reset = function(player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	data.coins = 0
	data.vault = 0
	data.incomeLevel = 1
	data.capacityLevel = 1
	data.rebirths = 0
	data.houseLevel = 0
	for key in pairs(Config.UPGRADES) do
		data.upgrades[key] = 0
	end
	data.cosmetics.owned = {}
	data.cosmetics.ownedEffects = {}
	data.cosmetics.skin = Config.DEFAULT_SKIN
	data.cosmetics.effect = Config.DEFAULT_EFFECT

	-- Decorations, bone stock and the pity counter, which this command used to
	-- miss.
	--
	-- It claimed "brand-new player" while leaving every ornament owned AND
	-- placed -- and because refresh re-applies the collection to the plot, they
	-- were immediately rebuilt on a lawn that was supposed to be empty. A dev
	-- command that lies about what it wiped is worse than one that does less,
	-- because the state it leaves behind gets mistaken for a bug in the feature
	-- being tested.
	data.decor = { owned = {}, placed = {} }
	data.consumables = {}
	data.sinceLegendary = 0

	local plot = PlotService.getPlot(player)
	if plot then
		PlotService.buildFence(plot, 0)
		PlotService.setDogLevel(plot, 0)
		PlotService.setLockLevel(plot, 0)
		PlotService.setDecor(plot, data.decor.placed)
		PlotService.setHouseLevel(plot, 0)
		PlotService.updatePile(plot, 0, Config.getCapacity(1))
	end
	refresh(player)
	BoneService.push(player)
	DataService.save(player)
	return "Save wiped back to a brand-new player"
end

-- ============================================================
-- WIRING
-- ============================================================

function AdminService.push(player: Player)
	Remotes.get("AdminState"):FireClient(player, AdminService.isAdmin(player))
end

function AdminService.start()
	Remotes.get("AdminRequest").OnServerEvent:Connect(function(player, command, a, b)
		-- Authorise FIRST, before reading a single argument.
		if not AdminService.isAdmin(player) then
			warn(("[AdminService] DENIED %s (userId %d) tried '%s'"):format(
				player.Name, player.UserId, tostring(command)))
			return
		end

		if type(command) ~= "string" then
			return
		end
		local handler = commands[command]
		if not handler then
			notify(player, ("Unknown command '%s'"):format(command), "warn")
			return
		end

		local ok, result = pcall(handler, player, a, b)
		if not ok then
			warn(("[AdminService] '%s' errored for %s: %s"):format(command, player.Name, tostring(result)))
			notify(player, ("'%s' failed -- check the server log."):format(command), "warn")
			return
		end

		-- Every accepted command is logged. If an account is ever compromised
		-- the server log is the only record of what was done with it.
		print(("[AdminService] %s (%d) ran '%s' -> %s"):format(
			player.Name, player.UserId, command, tostring(result)))
		notify(player, result or ("'%s' did nothing -- bad arguments?"):format(command), "good")
	end)

	Players.PlayerAdded:Connect(function(player)
		task.defer(AdminService.push, player)
	end)
end

return AdminService
