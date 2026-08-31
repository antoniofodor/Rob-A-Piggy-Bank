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
-- Rolls one animated skin for a rebirth and grants it.
--
-- Returns the key and its rarity, or nil if the player already owns every
-- animated skin in the game -- at which point the caller pays coins instead,
-- because a completed collection should not turn rebirth into a dead end.
--
-- Duplicates never waste a roll. Landing on a rarity you have completed walks
-- UPWARD first, so an unlucky roll on a full "rare" shelf turns into an epic
-- rather than into nothing.
function CosmeticsService.rollRebirthDrop(player: Player): (string?, string?)
	local data = DataService.get(player)
	if not data then
		return nil, nil
	end

	local owned = data.cosmetics.owned
	local rng = Random.new()
	local rolled = Config.rollRarity(data.rebirths, data.sinceLegendary or 0, rng)

	-- Search order: the rolled rarity, then rarer, then commoner.
	local order = { rolled }
	local rolledIndex = table.find(Config.DROP_RARITIES, rolled) or 1
	for i = rolledIndex + 1, #Config.DROP_RARITIES do
		table.insert(order, Config.DROP_RARITIES[i])
	end
	for i = rolledIndex - 1, 1, -1 do
		table.insert(order, Config.DROP_RARITIES[i])
	end

	for _, rarity in ipairs(order) do
		local candidates = {}
		for _, key in ipairs(Config.getSkinsOfRarity(rarity)) do
			if not owned[key] then
				table.insert(candidates, key)
			end
		end
		if #candidates > 0 then
			local key = candidates[rng:NextInteger(1, #candidates)]
			owned[key] = true

			if rarity == "legendary" then
				data.sinceLegendary = 0
			else
				data.sinceLegendary = (data.sinceLegendary or 0) + 1
			end
			return key, rarity
		end
	end

	return nil, nil
end

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

-- Bought and placed in one step: the next free slot for the item's zone.
--
-- No placement mode on purpose. The lawn is the ground an owner defends on,
-- and six more prompts there would compete with the collect and steal prompts
-- that actually matter. Buying is one tap instead of four.
function CosmeticsService.buyDecor(player: Player, key: string)
	local item = Config.DECOR_ITEMS[key]
	local data = DataService.get(player)
	if not item or not data then
		return
	end

	local decor = data.decor

	-- Already owned? Then this is a toggle, not a purchase.
	--
	-- Removal has to exist -- an ornament bought by accident is otherwise
	-- permanent -- and toggling is better than a refund: no coins move, so
	-- there is nothing to farm by buying and selling as prices change, and
	-- the item comes back for free whenever they want it again.
	if decor.owned[key] then
		local placedAt: string? = nil
		for slotId, placedKey in pairs(decor.placed) do
			if placedKey == key then
				placedAt = slotId
				break
			end
		end

		if placedAt then
			decor.placed[placedAt] = nil
			notify(player, ("%s put away."):format(item.name), "good")
		else
			local slot = Config.firstFreeDecorSlot(item.zone, decor.placed)
			if not slot then
				notify(player, ("No room left on your %s for that."):format(item.zone), "warn")
				return
			end
			decor.placed[slot] = key
			notify(player, ("%s back out on display."):format(item.name), "good")
		end

		local plot = PlotService.getPlot(player)
		if plot then
			PlotService.setDecor(plot, decor.placed)
		end
		DataService.save(player)
		CosmeticsService.push(player)
		return
	end

	local slot = Config.firstFreeDecorSlot(item.zone, decor.placed)
	if not slot then
		notify(player, ("No room left on your %s for that."):format(item.zone), "warn")
		return
	end

	if data.coins < item.cost then
		notify(player, ("Need %d more coins for the %s."):format(item.cost - data.coins, item.name), "warn")
		return
	end

	data.coins -= item.cost
	decor.owned[key] = true
	decor.placed[slot] = key

	local plot = PlotService.getPlot(player)
	if plot then
		PlotService.setDecor(plot, decor.placed)
	end

	notify(player, ("%s delivered!"):format(item.name), "good")
	DataService.save(player)
	CosmeticsService.push(player)
end

-- ============================================================
-- ACCESSORIES
-- ============================================================

local function gear(data: any)
	if type(data.accessories) ~= "table" then
		data.accessories = { owned = {}, worn = {} }
	end
	data.accessories.owned = data.accessories.owned or {}
	data.accessories.worn = data.accessories.worn or {}
	return data.accessories
end

local function ownedCount(owned: { [string]: boolean }): number
	local n = 0
	for key in pairs(owned) do
		if Config.ACCESSORIES[key] then
			n += 1
		end
	end
	return n
end

-- One weighted pick from everything the player does NOT already own.
--
-- Building the pool fresh each roll is what makes duplicates impossible: an
-- item leaves the pool the moment it is won, so there is nothing to "protect
-- against" later and no pity timer to tune. It also means the odds visibly
-- improve as the collection fills, which is the honest version of what a
-- crate usually only pretends to do.
local function rollFrom(owned: { [string]: boolean }): string?
	local pool: { string } = {}
	local total = 0
	for key, spec in pairs(Config.ACCESSORIES) do
		if not owned[key] then
			local rarity = Config.ACCESSORY_RARITIES[spec.rarity]
			if rarity then
				table.insert(pool, key)
				total += rarity.weight
			end
		end
	end
	if total <= 0 then
		return nil
	end

	-- Sorted before drawing. `pairs` has no defined order, so an unsorted pool
	-- would make the same random number pick different items on different
	-- servers -- harmless here, but it also makes the roll impossible to
	-- reproduce when someone reports a bad one.
	table.sort(pool)

	local ticket = math.random() * total
	for _, key in ipairs(pool) do
		ticket -= Config.ACCESSORY_RARITIES[Config.ACCESSORIES[key].rarity].weight
		if ticket <= 0 then
			return key
		end
	end
	return pool[#pool]
end

function CosmeticsService.rollAccessory(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end

	local acc = gear(data)
	local have = ownedCount(acc.owned)

	if have >= Config.accessoryCount() then
		notify(player, "You already own every accessory in the game!", "good")
		return
	end

	local cost = Config.getRollCost(have)
	if data.coins < cost then
		notify(player, ("Need %d more coins to roll."):format(cost - data.coins), "warn")
		return
	end

	local key = rollFrom(acc.owned)
	if not key then
		-- Unreachable given the count check above, but a roll that charged and
		-- returned nothing is the one failure mode here that would look like
		-- theft, so it refuses rather than trusting the arithmetic.
		notify(player, "Nothing left to roll.", "warn")
		return
	end

	data.coins -= cost
	acc.owned[key] = true

	local spec = Config.ACCESSORIES[key]
	local rarity = Config.ACCESSORY_RARITIES[spec.rarity]

	-- Worn immediately if the slot is empty. The reward for a roll should be
	-- visible on the pig before the player looks away -- but a slot they have
	-- deliberately dressed is left alone.
	if not acc.worn[spec.slot] then
		acc.worn[spec.slot] = key
	end

	notify(player, ("%s -- %s!"):format(string.upper(rarity.label), spec.name), "good")

	local plot = PlotService.getPlot(player)
	if plot then
		PlotService.applyAccessories(plot, acc.worn)
	end
	DataService.save(player)
	CosmeticsService.push(player)
end

-- Wear it, or take it off if it is already on. Toggling is the only way to
-- empty a slot: a separate "remove" control would double the number of things
-- to tap on a grid built for a touchscreen.
function CosmeticsService.equipAccessory(player: Player, key: string)
	local data = DataService.get(player)
	local spec = Config.ACCESSORIES[key]
	if not data or not spec then
		return
	end

	local acc = gear(data)
	if not acc.owned[key] then
		notify(player, ("You have not rolled the %s yet."):format(spec.name), "warn")
		return
	end

	if acc.worn[spec.slot] == key then
		acc.worn[spec.slot] = nil
		notify(player, ("%s off."):format(spec.name), "good")
	else
		acc.worn[spec.slot] = key
		notify(player, ("%s on!"):format(spec.name), "good")
	end

	local plot = PlotService.getPlot(player)
	if plot then
		PlotService.applyAccessories(plot, acc.worn)
	end
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
	PlotService.setDecor(plot, data.decor.placed)
	PlotService.applyAccessories(plot, gear(data).worn)
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

	-- Rebirth skins are earned, not bought -- but an EARNED one still has to
	-- be wearable. This used to reject them unconditionally, which meant
	-- Bronze, Gold Leaf and Diamond could never be equipped by anyone at any
	-- rebirth count: the reward existed and was permanently unreachable.
	if skin.unlockRebirths then
		if Config.isSkinUnlocked(key, data.cosmetics.owned, data.rebirths) then
			CosmeticsService.equipSkin(player, key)
		else
			notify(player, ("%s unlocks at %d rebirths -- you have %d."):format(
				skin.name, skin.unlockRebirths, data.rebirths), "warn")
		end
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
		notify(player, ("%s isn't unlocked yet."):format(Config.getSkin(key).name), "warn")
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

	local decorItems = {}
	for key, item in pairs(Config.DECOR_ITEMS) do
		decorItems[key] = {
			name = item.name,
			order = item.order,
			cost = item.cost,
			zone = item.zone,
			swatch = item.swatch,
			owned = data.decor.owned[key] == true,
			placed = (function()
				for _, placedKey in pairs(data.decor.placed) do
					if placedKey == key then
						return true
					end
				end
				return false
			end)(),
		}
	end

	local acc = gear(data)
	local have = ownedCount(acc.owned)
	local accessories = {}
	for key, spec in pairs(Config.ACCESSORIES) do
		local rarity = Config.ACCESSORY_RARITIES[spec.rarity]
		accessories[key] = {
			name = spec.name,
			order = spec.order,
			slot = spec.slot,
			rarity = spec.rarity,
			rarityLabel = rarity.label,
			rarityColour = rarity.colour,
			blurb = spec.blurb,
			owned = acc.owned[key] == true,
			worn = acc.worn[spec.slot] == key,
		}
	end

	Remotes.get("CosmeticState"):FireClient(player, {
		skins = skins,
		effects = effects,
		houses = houses,
		houseLevel = level,
		decor = decorItems,
		accessories = accessories,
		collection = {
			owned = have,
			total = Config.accessoryCount(),
			-- nil once the set is complete, which is how the client knows to
			-- swap the roll button for the finished state rather than showing
			-- a price for something that can no longer be bought.
			cost = if have < Config.accessoryCount() then Config.getRollCost(have) else nil,
		},
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
		elseif kind == "decor" then
			CosmeticsService.buyDecor(player, key)
		elseif kind == "accessory" then
			CosmeticsService.equipAccessory(player, key)
		elseif kind == "roll" then
			-- The key is ignored: a roll's outcome is picked by the server from
			-- the pool it maintains. Letting a client name what it wanted would
			-- be the entire exploit.
			CosmeticsService.rollAccessory(player)
		end
	end)
end

return CosmeticsService
