--!strict
--[[
	ProgressionService

	Rebirth: the reset that makes week three interesting.

	Everything purchased goes back to zero -- income and both upgrade trees
	-- in exchange for a permanent income multiplier and a visible change of
	material on your piggy. (The capacity tree is retired with the pig's
	ceiling; the rebirth gate is `Config.REBIRTH_CASH_GATE` plus the
	placeholder `Config.rebirthPiggyGate`.)

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

-- The rebirth gate runs to eight and nine figures -- and "You need 137438953
-- coins" is not a number a nine-year-old can read, let alone compare against
-- the one on their own HUD. The HUD already abbreviates; this is the server
-- saying the same thing the same way.
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

-- TWO GATES, ONE PREDICATE: the cash amount (`REBIRTH_CASH_GATE`) and the
-- piggy hook (`rebirthPiggyGate`, a placeholder that returns true). Both the
-- refusal below and the `rebirthReady` push read this shape, so the button
-- and the refusal move together the day the piggy half is written.
function ProgressionService.canRebirth(player: Player): boolean
	local data = DataService.get(player)
	return data ~= nil and data.coins >= Config.getRebirthThreshold(data.rebirths)
		and Config.rebirthPiggyGate(data)
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

	-- The gate climbs with the rebirth count, so the message has to name THIS
	-- player's number rather than a constant -- see Config.REBIRTH_CASH_GATE.
	local threshold = Config.getRebirthThreshold(data.rebirths)
	if data.coins < threshold then
		notify(player, ("You need %s coins in your piggy bank to rebirth."):format(short(threshold)), "warn")
		return
	end
	-- PLACEHOLDER HOOK: true today. When "own specific piggies" is written
	-- this is where it refuses, and it will need its own wording.
	if not Config.rebirthPiggyGate(data) then
		notify(player, "You need the right piggies to rebirth.", "warn")
		return
	end

	data.rebirths += 1
	data.coins = 0
	data.incomeLevel = 1
	for key in pairs(Config.UPGRADES) do
		data.upgrades[key] = 0
	end

	-- Lifetime stats survive: robberies, totalStolen and totalLost are who you've been,
	-- not what you currently own.

	local plot = PlotService.getPlot(player)
	if plot then
		PlotService.updateSign(plot, player.DisplayName, data.rebirths,
			Config.getSkin(data.cosmetics.skin).name, Config.getShownHouse(data).name)
		PlotService.updatePile(plot, 0, Config.pigFullAt(data.rebirths))
		PlotService.buildFence(plot, 0)
		-- THE DOG STAYS. A rebirth takes away what was bought, and the Guard
		-- rung is retired -- every plot has the same dog (`Config.DOG_LEVEL`)
		-- and its skin is a cosmetic, which rebirth has never touched. Set
		-- rather than skipped, so the teardown leaves the plot in a state
		-- `UpgradeService.applyToPlot` agrees with.
		PlotService.setDogLevel(plot, Config.DOG_LEVEL)
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

	-- A shop Legendary crate for free, with its normal odds and duplicate
	-- spares, picked at random from the collections not yet finished -- so the
	-- free open never rolls at a shelf whose legendaries are all owned.
	--
	-- WITH EVERY ONE COMPLETE THERE IS NOTHING TO PAY INSTEAD. It used to hand
	-- over the crate's price in acorns; a crate has no price any more, so the
	-- rebirth is SAID to be complete rather than silently paying zero -- a
	-- grant with nothing on screen is one nobody believes.
	local open = Config.rebirthCratesOpen(data.cosmetics.owned)
	if #open == 0 then
		notify(player, "Every Legendary collected -- no crate left to open!", "good")
	else
		ChestService.grantFree(player, open[math.random(#open)])
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
		ready = ProgressionService.canRebirth(player),
	})
end

function ProgressionService.start()
	Remotes.get("RebirthRequest").OnServerEvent:Connect(function(player)
		ProgressionService.rebirth(player)
	end)
end

return ProgressionService
