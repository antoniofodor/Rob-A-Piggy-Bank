--!strict
--[[
	UpgradeService

	Buying and querying the defence and offence trees.

	Purchases are validated here and nowhere else, so there's a single place
	to audit what a client is allowed to spend. Levels live in the player's
	saved data; every effect is derived from them on demand rather than
	cached, so there's no stale copy to go out of sync with the save.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local UpgradeService = {}

local onPurchased: { (Player, string, number) -> () } = {}

function UpgradeService.getLevel(player: Player, key: string): number
	local data = DataService.get(player)
	if not data or not data.upgrades then
		return 0
	end
	return data.upgrades[key] or 0
end

-- Effects, all derived from levels at the moment they're needed.

function UpgradeService.getStealHold(thief: Player, victim: Player): number
	return Config.getStealHold(
		UpgradeService.getLevel(victim, "locks"),
		UpgradeService.getLevel(thief, "lockpicks")
	)
end

function UpgradeService.getStealFraction(thief: Player): number
	return Config.getStealFraction(UpgradeService.getLevel(thief, "sack"))
end

function UpgradeService.getCarryMultiplier(thief: Player): number
	return Config.getCarryMultiplier(UpgradeService.getLevel(thief, "boots"))
end

-- Fires listeners so services that build things (fences, dogs) can react to
-- a level change without UpgradeService needing to know they exist.
function UpgradeService.onUpgradePurchased(callback: (Player, string, number) -> ())
	table.insert(onPurchased, callback)
end

function UpgradeService.purchase(player: Player, key: string)
	local def = Config.UPGRADES[key]
	if not def then
		return -- unknown key from a client; ignore rather than error
	end

	local data = DataService.get(player)
	if not data then
		return
	end

	local level = data.upgrades[key] or 0
	if level >= def.max then
		Remotes.get("Notify"):FireClient(player, ("%s is maxed out."):format(def.name), "warn")
		return
	end

	local cost = Config.getUpgradeCost(key, level)
	if data.coins < cost then
		Remotes.get("Notify"):FireClient(player, ("Need %d more coins for %s."):format(cost - data.coins, def.name), "warn")
		return
	end

	data.coins -= cost
	data.upgrades[key] = level + 1

	Remotes.get("Notify"):FireClient(player, ("%s upgraded to level %d!"):format(def.name, level + 1), "good")
	UpgradeService.push(player)

	for _, callback in ipairs(onPurchased) do
		task.spawn(callback, player, key, level + 1)
	end
end

function UpgradeService.push(player: Player)
	Remotes.get("UpgradeState"):FireClient(player, UpgradeService.buildSnapshot(player))
end

-- Rebuilds everything a player's saved levels imply on their plot. Called on
-- join, so someone who bought a fence yesterday still has it today.
function UpgradeService.applyToPlot(player: Player)
	local plot = PlotService.getPlot(player)
	if not plot then
		return
	end
	PlotService.buildFence(plot, UpgradeService.getLevel(player, "fences"))
	PlotService.setDogLevel(plot, UpgradeService.getLevel(player, "dog"))
	PlotService.setLockLevel(plot, UpgradeService.getLevel(player, "locks"))
end

-- Snapshot for the shop UI: level, cost, and whether it's affordable.
function UpgradeService.buildSnapshot(player: Player): { [string]: any }
	local data = DataService.get(player)
	if not data then
		return {}
	end

	local snapshot: { [string]: any } = {}
	for key, def in pairs(Config.UPGRADES) do
		local level = data.upgrades[key] or 0
		snapshot[key] = {
			level = level,
			max = def.max,
			cost = if level >= def.max then 0 else Config.getUpgradeCost(key, level),
			tree = def.tree,
			order = def.order,
			name = def.name,
			blurb = def.blurb,
		}

		-- The dog is the one upgrade where each level is a different thing
		-- rather than a bigger number, so its row names the breed instead of
		-- repeating a description that never changes.
		if key == "dog" then
			local current = Config.getDogTier(level)
			local upcoming = Config.getDogTier(level + 1)
			if level >= def.max and current then
				snapshot[key].blurb = ("%s the %s is on duty"):format(current.name, current.breed)
			elseif upcoming then
				snapshot[key].blurb = ("Next: %s the %s"):format(upcoming.name, upcoming.breed)
			end
		end
	end
	return snapshot
end

function UpgradeService.start()
	Remotes.get("UpgradeRequest").OnServerEvent:Connect(function(player, key)
		if type(key) ~= "string" then
			return
		end
		UpgradeService.purchase(player, key)
	end)

	-- Anything that changes the plot itself gets rebuilt on purchase.
	UpgradeService.onUpgradePurchased(function(player, key, level)
		local plot = PlotService.getPlot(player)
		if not plot then
			return
		end
		if key == "fences" then
			PlotService.buildFence(plot, level)
		elseif key == "dog" then
			PlotService.setDogLevel(plot, level)
		elseif key == "locks" then
			PlotService.setLockLevel(plot, level)
		end
	end)
end

return UpgradeService
