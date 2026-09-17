--!strict
--[[
	TreeService

	The tree ladder (MASTER-PLAN 19.4 / 19.4a, step 2.7): buying the next
	level of the oak on your own lawn, and telling the owner what the next
	rung costs and what gates it.

	The growth itself is not here. `Config.growAcorns` reads the level, the
	best owned house and the rebirth bonus straight off the save, so the
	offline path, the live tick and the shake all agree without asking this
	service anything. What lives here is the purchase and the offer.

	THE HOUSE GATES, THE COINS PAY. A rung is bought with coins; the best
	house the player OWNS decides how high the ladder may be bought
	(`Config.TREE_HOUSE_GATE`). Every refusal names its reason and never
	charges -- the house purchase path's rule.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local TreeService = {}

local function notify(player: Player, message: string, kind: string)
	Remotes.get("Notify"):FireClient(player, message, kind)
end

local function rarityWord(rarity: string?): string
	local name = rarity or "better"
	return name:sub(1, 1):upper() .. name:sub(2)
end

-- What the owner's prompt says. Level and rate now, what the next rung does,
-- and on the amount chip either the price or why it cannot be bought yet.
function TreeService.refresh(player: Player)
	local data = DataService.get(player)
	local plot = PlotService.getPlot(player)
	if data and plot then
		-- A new level changes the rate and a new house the cap, so the
		-- next-acorn clock is republished with the offer.
		PlotService.publishTree(plot, data)
	end
	local prompt = plot and plot.growPrompt
	if not data or not prompt then
		return
	end
	local level = Config.treeLevelOf(data)
	local nextLevel, row, allowed = Config.nextTreeLevel(data)
	if not nextLevel or not row then
		prompt.Enabled = false
		return
	end
	prompt.ActionText = ("Grow to Lv%d"):format(nextLevel)
	if allowed then
		prompt.ObjectText = ("%g to %g acorns an hour"):format(
			Config.treeGrowthPerHour(level), row.rate)
		prompt:SetAttribute(Config.PROMPT_AMOUNT_ATTRIBUTE, Config.formatCoins(row.cost))
	else
		prompt.ObjectText = ("Needs a %s house"):format(rarityWord(Config.treeGateRarityFor(nextLevel)))
		prompt:SetAttribute(Config.PROMPT_AMOUNT_ATTRIBUTE, "LOCKED")
	end
	prompt.Enabled = true
end

-- The level is drawn on the plot and the offer is written for its owner.
-- Called on join, after a purchase, and after anything that moves the gate
-- (a house purchase).
function TreeService.apply(player: Player)
	local data = DataService.get(player)
	local plot = PlotService.getPlot(player)
	if not data or not plot then
		return
	end
	PlotService.setTreeLevel(plot, Config.treeLevelOf(data))
	PlotService.setTreeOwner(plot, player)
	TreeService.refresh(player)
end

function TreeService.buy(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local nextLevel, row, allowed = Config.nextTreeLevel(data)
	if not nextLevel or not row then
		notify(player, "Your tree is fully grown.", "warn")
		return
	end
	if not allowed then
		notify(player, ("Level %d needs a %s house. Your tree grows as grand as your home."):format(
			nextLevel, rarityWord(Config.treeGateRarityFor(nextLevel))), "warn")
		return
	end
	local cost = row.cost
	-- The two refusals the house path uses, for the same reason: a price the
	-- pig cannot HOLD wants a bigger pig, not more waiting.
	if cost > Config.getCapacity(data.capacityLevel) then
		notify(player, ("Your piggy bank can't hold %s yet. Grow it first."):format(Config.formatCoins(cost)), "warn")
		return
	end
	if data.coins < cost then
		notify(player, ("You need %s coins to grow your tree."):format(Config.formatCoins(cost)), "warn")
		return
	end

	-- SETTLE AT THE OLD RATE FIRST, so the time already spent growing is paid
	-- at the level it was spent at rather than re-rated by the purchase.
	Config.growAcorns(data, os.time(), true)
	data.coins -= cost
	data.tree.level = nextLevel

	local plot = PlotService.getPlot(player)
	if plot then
		PlotService.setTreeLevel(plot, nextLevel)
		PlotService.updatePile(plot, data.coins, Config.getCapacity(data.capacityLevel))
	end
	notify(player, ("Your tree grew to level %d: %g acorns an hour."):format(nextLevel, row.rate), "good")
	TreeService.refresh(player)
	DataService.save(player)
end

function TreeService.start()
	for _, plot in ipairs(PlotService.getAll()) do
		local prompt = plot.growPrompt
		if prompt then
			-- The prompt is only offered to the owner; the server checks it
			-- anyway, because a client's `Enabled` is its own business.
			prompt.Triggered:Connect(function(player: Player)
				if plot.owner == player then
					TreeService.buy(player)
				end
			end)
		end
	end
	-- The same purchase as a remote, for the shop card brief B5 will draw.
	-- It carries nothing: the rung is always the next one.
	Remotes.get("TreeRequest").OnServerEvent:Connect(function(player: Player)
		TreeService.buy(player)
	end)
end

return TreeService
