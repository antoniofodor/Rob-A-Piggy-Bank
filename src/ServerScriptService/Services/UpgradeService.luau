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

-- `getStealHold` and `getStealFraction` stood here and are gone with the flat
-- steal. Both asked this service to look up ONE level and hand it to ONE
-- Config function, which was worth a wrapper while the caller was a single
-- line in `attemptSteal`; the crack reads `locks`, `lockpicks` and `sack`
-- together and calls Config directly, and a wrapper per level would have been
-- three indirections hiding one table lookup each.
--
-- Note the lock level in particular is NOT read from here any more even for a
-- player: a crack asks the PLOT, because a resident has no upgrade record and
-- the whole point of the Target abstraction is that the two are one path.

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
	-- EVERY PLOT GETS THE SAME DOG. The Guard rung is retired and a skin is
	-- what varies -- see `Config.DOG_LEVEL`. Still set from here, because
	-- this is the one function whose job is making a plot match its owner,
	-- and a plot rebuilt without it would stand an empty kennel.
	PlotService.setDogLevel(plot, Config.DOG_LEVEL)
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

		-- THE CASING BLURB IS GONE FROM THIS CARD, BY DESIGNER DECISION, and
		-- what it cost is recorded rather than quietly lost.
		--
		-- It used to overwrite the blurb with "You can read any lock from the
		-- pavement" at max and "Next: read any lock from the pavement" one
		-- rung below, on the argument that LOCKPICKS IS THE ONE RUNG THAT
		-- HANDS OVER A VERB and an ability nobody was told about is an ability
		-- nobody uses. That argument is intact and is now unanswered: asked
		-- what this rung is worth, the card talked about reading locks from a
		-- pavement instead of about cracking, which is what a player reads it
		-- for. It says "Spare picks forgive a missed pin" and the stat rows
		-- underneath it count the spares (`Config.LOCKPICK_PERKS`).
		--
		-- SO `Config.CASING` IS ADVERTISED NOWHERE NOW. The pip ladder still
		-- appears on the rob badge at max (`RobBadge` asks `Config.canCase`),
		-- so the verb still arrives -- it simply arrives unannounced, and a
		-- player who never reaches the top of this tree will not learn it
		-- exists. If it should be sold again, the honest home is a line of its
		-- own at max rather than the blurb this card needs for its own job.

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
		elseif key == "locks" then
			PlotService.setLockLevel(plot, level)
		end
	end)
end

return UpgradeService
