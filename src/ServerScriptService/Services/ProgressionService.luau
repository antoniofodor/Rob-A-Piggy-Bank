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
local ChestService = require(script.Parent.ChestService)

local ProgressionService = {}

local lastRequest: { [Player]: number } = {}

local function notify(player: Player, message: string, kind: string)
	Remotes.get("Notify"):FireClient(player, message, kind)
end

-- The rebirth gate is a multiple of capacity now, so it runs to eight and nine
-- figures -- and "You need 137438953 coins" is not a number a nine-year-old can
-- read, let alone compare against the one on their own HUD. The HUD already
-- abbreviates; this is the server saying the same thing the same way.
local function short(n: number): string
	if n >= 1e9 then
		return ("%.1fB"):format(n / 1e9)
	elseif n >= 1e6 then
		return ("%.1fM"):format(n / 1e6)
	elseif n >= 1e3 then
		return ("%.1fK"):format(n / 1e3)
	end
	return tostring(math.floor(n))
end

function ProgressionService.canRebirth(player: Player): boolean
	local data = DataService.get(player)
	return data ~= nil and data.coins >= Config.getRebirthThreshold(data.rebirths)
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

	-- The gate scales with the ceiling you can currently reach, so the message
	-- has to name THIS player's number rather than a constant -- see
	-- Config.REBIRTH_CAPACITY_MULTIPLE for why it is not a flat million.
	local threshold = Config.getRebirthThreshold(data.rebirths)
	if data.coins < threshold then
		notify(player, ("You need %s coins in your piggy bank to rebirth."):format(short(threshold)), "warn")
		return
	end

	data.rebirths += 1
	data.coins = 0
	data.incomeLevel = 1
	data.capacityLevel = 1
	for key in pairs(Config.UPGRADES) do
		data.upgrades[key] = 0
	end

	-- Lifetime stats survive: robberies, totalStolen and totalLost are who you've been,
	-- not what you currently own.

	local plot = PlotService.getPlot(player)
	if plot then
		PlotService.updateSign(plot, player.DisplayName, data.rebirths,
			Config.getSkin(data.cosmetics.skin).name, Config.getShownHouse(data).name)
		PlotService.updatePile(plot, 0, Config.getCapacity(1))
		PlotService.buildFence(plot, 0)
		PlotService.setDogLevel(plot, 0)
		PlotService.setLockLevel(plot, 0)
		PlotService.playBank(plot)
		-- AND THE STREET FINDS OUT. Everything above this line puts the plot
		-- back to level 0, which is the whole cost of a rebirth rendered as
		-- a bare slab -- and until now that was the only thing anybody else
		-- could see. Fired AFTER the teardown so the show goes up over the
		-- plot in the state the player has just paid for.
		PlotService.fireFireworks(plot, data.rebirths)
	end

	notify(player, ("REBIRTH %d! Your piggy earns +%d%% forever."):format(
		data.rebirths, Config.rebirthBonusPercent(data.rebirths)), "good")

	-- The standard Legendary Crate, with its normal odds and duplicate spares.
	-- Once every eligible legendary is owned, pay its price in Acorns instead.
	if Config.rebirthCrateComplete(data.cosmetics.owned) then
		local bonus = Config.CHESTS[Config.REBIRTH_CRATE].cost
		data.loot = (data.loot or 0) + bonus
		notify(player, ("Legendary collection complete! %d %s instead."):format(
			bonus, Config.lootWord(bonus)), "good")
	else
		ChestService.grantFree(player, Config.REBIRTH_CRATE)
	end

	-- Persist immediately. Losing a rebirth to a crash would be the single
	-- worst thing that could happen to a player's evening.
	-- Reapply the collection: rebirth wiped the upgrades, never the skins,
	-- and this rebirth may just have unlocked a new one.
	CosmeticsService.applyToPlot(player)
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
		threshold = Config.getRebirthThreshold(data.rebirths),
		ready = data.coins >= Config.getRebirthThreshold(data.rebirths),
	})
end

function ProgressionService.start()
	Remotes.get("RebirthRequest").OnServerEvent:Connect(function(player)
		ProgressionService.rebirth(player)
	end)
end

return ProgressionService
