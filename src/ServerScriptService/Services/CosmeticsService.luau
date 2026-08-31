--!strict
--[[
	CosmeticsService

	Skins and effects for the piggy bank: buying them, equipping them, and
	putting them on the plot.

	This is the game's answer to "what am I grinding for?".

	Every other purchase in the game is temporary -- rebirth wipes income,
	capacity, and both upgrade trees back to zero. Cosmetics are the one
	thing rebirth never touches, so they accumulate for the life of the
	account. That gives a player something ahead of them that a reset can't
	take away, and because the piggy is visible from across the map, every
	coin spent here is something other people can see.

	None of it affects balance. That's what makes it safe to price steeply.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local CosmeticsService = {}

local function notify(player: Player, message: string, kind: string)
	Remotes.get("Notify"):FireClient(player, message, kind)
end

local function getCosmetics(player: Player)
	local data = DataService.get(player)
	return data and data.cosmetics
end

-- ============================================================
-- APPLY
-- ============================================================

-- Houses go through the cosmetics service rather than the upgrade trees on
-- purpose: they survive rebirth, they confer nothing, and they belong to the
-- same "permanent collection" idea as skins. Reusing this channel also keeps
-- the whole collection in a single snapshot push.
function CosmeticsService.buyHouse(player: Player, requested: string)
	local data = DataService.get(player)
	if not data then
		return
	end

	local level = data.houseLevel or 0

	-- The client sends which tile was tapped. Only the next rung is for sale,
	-- so tapping the Mansion at Starter level must say so rather than quietly
	-- selling the Cottage instead.
	local wanted = tonumber(requested)
	if wanted and (wanted - 1) ~= level + 1 then
		if (wanted - 1) <= level then
			notify(player, "You already own that one.", "warn")
		else
			notify(player, ("Buy the %s first."):format(Config.getHouseTier(level + 1).name), "warn")
		end
		return
	end
	if level >= Config.MAX_HOUSE_LEVEL then
		notify(player, "You already own the best house on the street.", "warn")
		return
	end

	local cost = Config.getHouseUpgradeCost(level)
	if not cost then
		return
	end
	if data.coins < cost then
		notify(player, ("You need %d coins for that."):format(cost), "warn")
		return
	end

	data.coins -= cost
	data.houseLevel = level + 1

	local plot = PlotService.getPlot(player)
	if plot then
		PlotService.setHouseLevel(plot, data.houseLevel)
	end

	notify(player, ("Moved into the %s!"):format(Config.getHouseTier(data.houseLevel).name), "good")
	DataService.save(player)
	CosmeticsService.push(player)
end

function CosmeticsService.applyToPlot(player: Player)
	local data = DataService.get(player)
	local plot = PlotService.getPlot(player)
	if not data or not plot then
		return
	end

	local cosmetics = data.cosmetics
	local skinKey = cosmetics.skin

	-- An equipped skin can become unavailable: a rebirth-locked one only
	-- unlocks at N rebirths, and this same save could in principle load
	-- with fewer. Fall back rather than showing something unearned.
	if not Config.isSkinUnlocked(skinKey, cosmetics.owned, data.rebirths) then
		skinKey = Config.DEFAULT_SKIN
		cosmetics.skin = skinKey
	end

	PlotService.applySkin(plot, skinKey)
	PlotService.applyEffect(plot, cosmetics.effect)
	PlotService.setHouseLevel(plot, data.houseLevel or 0)
	PlotService.updateSign(plot, player.DisplayName, data.rebirths, Config.getSkin(skinKey).name)
end

-- ============================================================
-- PURCHASE AND EQUIP
-- ============================================================

function CosmeticsService.buySkin(player: Player, key: string)
	local skin = Config.SKINS[key]
	local data = DataService.get(player)
	if not skin or not data then
		return
	end

	if skin.unlockRebirths then
		notify(player, ("%s is earned at %d rebirths, not bought."):format(skin.name, skin.unlockRebirths), "warn")
		return
	end

	local cosmetics = data.cosmetics
	if cosmetics.owned[key] or (skin.cost or 0) <= 0 then
		CosmeticsService.equipSkin(player, key)
		return
	end

	if data.coins < skin.cost then
		notify(player, ("Need %d more coins for %s."):format(skin.cost - data.coins, skin.name), "warn")
		return
	end

	data.coins -= skin.cost
	cosmetics.owned[key] = true
	notify(player, ("Unlocked %s!"):format(skin.name), "good")

	CosmeticsService.equipSkin(player, key)
end

function CosmeticsService.buyEffect(player: Player, key: string)
	local effect = Config.EFFECTS[key]
	local data = DataService.get(player)
	if not effect or not data then
		return
	end

	local cosmetics = data.cosmetics
	if cosmetics.ownedEffects[key] or (effect.cost or 0) <= 0 then
		CosmeticsService.equipEffect(player, key)
		return
	end

	if data.coins < effect.cost then
		notify(player, ("Need %d more coins for %s."):format(effect.cost - data.coins, effect.name), "warn")
		return
	end

	data.coins -= effect.cost
	cosmetics.ownedEffects[key] = true
	notify(player, ("Unlocked %s!"):format(effect.name), "good")

	CosmeticsService.equipEffect(player, key)
end

function CosmeticsService.equipSkin(player: Player, key: string)
	local data = DataService.get(player)
	if not data then
		return
	end
	if not Config.isSkinUnlocked(key, data.cosmetics.owned, data.rebirths) then
		return
	end
	data.cosmetics.skin = key
	CosmeticsService.applyToPlot(player)
	CosmeticsService.push(player)
end

function CosmeticsService.equipEffect(player: Player, key: string)
	local data = DataService.get(player)
	local effect = Config.EFFECTS[key]
	if not data or not effect then
		return
	end
	if (effect.cost or 0) > 0 and not data.cosmetics.ownedEffects[key] then
		return
	end
	data.cosmetics.effect = key
	CosmeticsService.applyToPlot(player)
	CosmeticsService.push(player)
end

-- Called after a rebirth: the newly reached tier may have unlocked a skin,
-- and that's the visible reward for resetting everything else.
function CosmeticsService.announceRebirthUnlocks(player: Player, rebirths: number)
	for _, skin in pairs(Config.SKINS) do
		if skin.unlockRebirths == rebirths then
			notify(player, ("Rebirth reward: the %s skin is yours forever."):format(skin.name), "good")
		end
	end
end

-- ============================================================
-- STATE
-- ============================================================

function CosmeticsService.push(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end

	local skins: { [string]: any } = {}
	for key, skin in pairs(Config.SKINS) do
		skins[key] = {
			name = skin.name,
			order = skin.order,
			cost = skin.cost or 0,
			unlockRebirths = skin.unlockRebirths,
			unlocked = Config.isSkinUnlocked(key, data.cosmetics.owned, data.rebirths),
			equipped = data.cosmetics.skin == key,
			body = skin.body,
		}
	end

	local effects: { [string]: any } = {}
	for key, effect in pairs(Config.EFFECTS) do
		effects[key] = {
			name = effect.name,
			order = effect.order,
			cost = effect.cost or 0,
			unlocked = (effect.cost or 0) <= 0 or data.cosmetics.ownedEffects[key] == true,
			equipped = data.cosmetics.effect == key,
		}
	end

	-- Houses are a linear ladder rather than a set to choose from, so the
	-- client gets every tier with its state stamped on it: owned, the one
	-- currently for sale, or still locked behind the ones before it.
	local level = data.houseLevel or 0
	local houses = {}
	for i, tier in ipairs(Config.HOUSE_TIERS) do
		houses[i] = {
			name = tier.name,
			order = i,
			cost = tier.cost or 0,
			blurb = tier.blurb,
			owned = (i - 1) <= level,
			current = (i - 1) == level,
			forSale = (i - 1) == level + 1,
			walls = tier.walls,
		}
	end

	Remotes.get("CosmeticState"):FireClient(player, {
		skins = skins,
		effects = effects,
		houses = houses,
		houseLevel = level,
	})
end

function CosmeticsService.start()
	Remotes.get("CosmeticRequest").OnServerEvent:Connect(function(player, kind, key)
		if type(kind) ~= "string" or type(key) ~= "string" then
			return
		end
		if kind == "skin" then
			CosmeticsService.buySkin(player, key)
		elseif kind == "effect" then
			CosmeticsService.buyEffect(player, key)
		elseif kind == "house" then
			CosmeticsService.buyHouse(player, key)
		end
	end)
end

return CosmeticsService
