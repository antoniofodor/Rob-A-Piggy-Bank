--!strict
--[[
	ProgressionService

	Rebirth: the reset that makes week three interesting.

	Everything purchased goes back to zero -- income, capacity, and both
	upgrade trees -- in exchange for a permanent income multiplier and a
	visible change of material on your piggy.

	Wiping the trees is the point, not a side effect. It's the only way to
	respec, so a player who committed to defence and regrets it has a route
	out, and rebirthing feels like a fresh start rather than a tax. It also
	means a veteran walks back into the low tiers occasionally, which keeps
	the early game populated.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local CosmeticsService = require(script.Parent.CosmeticsService)

local ProgressionService = {}

local lastRequest: { [Player]: number } = {}

local function notify(player: Player, message: string, kind: string)
	Remotes.get("Notify"):FireClient(player, message, kind)
end

function ProgressionService.canRebirth(player: Player): boolean
	local data = DataService.get(player)
	return data ~= nil and data.coins >= Config.REBIRTH_THRESHOLD
end

function ProgressionService.rebirth(player: Player)
	-- Rebirth wipes a lot of state, so it gets its own guard against a client
	-- spamming the remote and racing two resets against each other.
	local now = os.clock()
	if lastRequest[player] and (now - lastRequest[player]) < 2 then
		return
	end
	lastRequest[player] = now

	local data = DataService.get(player)
	if not data then
		return
	end

	if data.coins < Config.REBIRTH_THRESHOLD then
		notify(player, ("You need %d coins to rebirth."):format(Config.REBIRTH_THRESHOLD), "warn")
		return
	end

	data.rebirths += 1
	data.coins = 0
	data.vault = 0
	data.incomeLevel = 1
	data.capacityLevel = 1
	for key in pairs(Config.UPGRADES) do
		data.upgrades[key] = 0
	end

	-- Lifetime stats survive: totalStolen and totalLost are who you've been,
	-- not what you currently own.

	local plot = PlotService.getPlot(player)
	if plot then
		PlotService.updateSign(plot, player.DisplayName, data.rebirths,
			Config.getSkin(data.cosmetics.skin).name, Config.getHouseTier(data.houseLevel or 0).name)
		PlotService.updatePile(plot, 0, Config.getCapacity(1))
		PlotService.buildFence(plot, 0)
		PlotService.setDogLevel(plot, 0)
		PlotService.setLockLevel(plot, 0)
		PlotService.playBank(plot)
	end

	notify(player, ("REBIRTH %d! Your piggy earns +%d%% forever."):format(
		data.rebirths, math.floor(data.rebirths * Config.REBIRTH_MULTIPLIER * 100)), "good")

	-- The drop. Every rebirth grants one animated skin; the odds of a rarer
	-- one climb with the rebirth count, and a legendary is reachable on the
	-- very first rebirth.
	local key, rarity = CosmeticsService.rollRebirthDrop(player)
	if key then
		local skin = Config.getSkin(key)
		notify(player, ("%s DROP -- %s!"):format(string.upper(rarity or "?"), skin.name), "good")
		-- Wear it immediately. The reward for a reset that took everything
		-- should be visible on the plot before the player looks away.
		CosmeticsService.equipSkin(player, key)
	else
		-- Collection complete. Pay out instead of silently doing nothing.
		local bonus = Config.REBIRTH_THRESHOLD // 4
		data.coins += bonus
		notify(player, ("Collection complete -- %d bonus coins instead."):format(bonus), "good")
	end

	-- Persist immediately. Losing a rebirth to a crash would be the single
	-- worst thing that could happen to a player's evening.
	-- Reapply the collection: rebirth wiped the upgrades, never the skins,
	-- and this rebirth may just have unlocked a new one.
	CosmeticsService.applyToPlot(player)
	CosmeticsService.announceRebirthUnlocks(player, data.rebirths)
	CosmeticsService.push(player)

	DataService.save(player)

	ProgressionService.push(player)
end

function ProgressionService.push(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	Remotes.get("RebirthState"):FireClient(player, {
		rebirths = data.rebirths,
		threshold = Config.REBIRTH_THRESHOLD,
		ready = data.coins >= Config.REBIRTH_THRESHOLD,
	})
end

function ProgressionService.start()
	Remotes.get("RebirthRequest").OnServerEvent:Connect(function(player)
		ProgressionService.rebirth(player)
	end)
end

return ProgressionService
