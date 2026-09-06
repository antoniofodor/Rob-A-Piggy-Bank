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
local PlayerGear = require(ReplicatedStorage.Shared.PlayerGear)
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

-- Tapping a house tile either buys the next rung or moves back into one
-- already owned.
--
-- Moving back matters because a house is pure taste. The ladder is priced so
-- the last tiers take a very long time, and a player who liked the Beach
-- Villa's look should not be punished for having outgrown it -- nothing about
-- the game changes with which one is standing. It costs nothing, both ways,
-- so there is no sell-and-rebuy loop to farm.
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
		local target = wanted - 1
		if target <= level then
			if target == Config.getShownHouseLevel(data) then
				notify(player, "You already live there.", "warn")
			else
				data.houseShown = target
				CosmeticsService.applyToPlot(player)
				notify(player, ("Moved back into the %s."):format(Config.getHouseTier(target).name), "good")
				DataService.save(player)
				CosmeticsService.push(player)
			end
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
	-- You move into what you just bought. Anything else would make the most
	-- expensive purchase in the game produce no visible change at all.
	data.houseShown = data.houseLevel

	-- applyToPlot, not setHouseLevel alone.
	--
	-- The plot sign carries the house name now, and setHouseLevel only builds
	-- the building -- so buying a house rebuilt it while the sign kept
	-- announcing the old one until the player next rejoined. applyToPlot is
	-- the function whose whole job is making the plot match the data, so
	-- anything that changes what the plot should look like goes through it.
	CosmeticsService.applyToPlot(player)

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

-- How many ROLLABLE accessories are owned -- set items excluded, because they
-- are not in the pool a roll draws from. This number does two jobs and both
-- want the same pool: it indexes the price ladder, and it is compared against
-- Config.rollableAccessoryCount to decide whether the collection is finished.
--
-- Counting set items here charged a player more for a roll because they had
-- bought an alien hat with medals, which is two currencies leaking into each
-- other. See the note on Config.rollableAccessoryCount.
local function ownedCount(owned: { [string]: boolean }): number
	local n = 0
	for key in pairs(owned) do
		local spec = Config.ACCESSORIES[key]
		if spec and not spec.set then
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
		-- `spec.set` is the second of the two exclusions. An accessory in a
		-- set is earned by turning up to events and bought with medals, so it
		-- must never fall out of the COIN roll -- otherwise the set stops
		-- meaning attendance and starts meaning patience.
		if not owned[key] and not spec.set then
			local rarity = Config.RARITIES[spec.rarity]
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
		ticket -= Config.RARITIES[Config.ACCESSORIES[key].rarity].weight
		if ticket <= 0 then
			return key
		end
	end
	return pool[#pool]
end

-- Loot is granted by SetService.award and nowhere else; this file only
-- spends it (the roll) and reports it (the push).
function CosmeticsService.getLoot(player: Player): number
	local data = DataService.get(player)
	return if data then math.floor(data.loot or 0) else 0
end

function CosmeticsService.rollAccessory(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end

	local acc = gear(data)
	local have = ownedCount(acc.owned)

	if have >= Config.rollableAccessoryCount() then
		notify(player, "You already own every accessory you can roll for!", "good")
		return
	end

	-- PAID IN LOOT, NEVER IN COINS. Loot comes only from robbing, so the
	-- collection is paced by how often somebody goes out rather than by
	-- whoever has the deepest pig -- and no amount of money can reach it.
	-- Nothing about the pool, the odds or the no-duplicates guarantee changed
	-- with it; only what it is bought with.
	local cost = Config.getRollCost(have)
	local held = math.floor(data.loot or 0)
	if held < cost then
		-- Names the shortfall AND where loot comes from. A currency a player
		-- has never seen, on a button they cannot press, is indistinguishable
		-- from a broken feature -- and this one cannot be fixed by going and
		-- earning more coins, which is what every other refusal in this game
		-- has trained them to try.
		notify(player, ("Need %d more %s. Rob a neighbour and get the coins home."):format(
			cost - held, Config.lootWord(cost - held)), "warn")
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

	data.loot = held - cost
	acc.owned[key] = true

	local spec = Config.ACCESSORIES[key]
	local rarity = Config.RARITIES[spec.rarity]

	-- Worn immediately if the slot is empty. The reward for a roll should be
	-- visible on the pig before the player looks away -- but a slot they have
	-- deliberately dressed is left alone.
	if not acc.worn[spec.slot] then
		acc.worn[spec.slot] = key
	end

	notify(player, ("%s: %s!"):format(string.upper(rarity.label), spec.name), "good")

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

-- ============================================================
-- MOST WANTED GEAR
-- ============================================================
--
-- The player's own character rather than their piggy, which is why this sits
-- beside `applyToPlot` rather than inside it: same job -- make what you see
-- match the data -- against a different body.

local function gearOf(player: Player)
	local data = DataService.get(player)
	if not data then
		return nil
	end
	-- Belt and braces against a save written before schema 13 that somehow
	-- missed reconcile. A nil here would otherwise throw inside a
	-- CharacterAdded handler, which takes the whole spawn with it.
	if not data.gear then
		data.gear = { unlocked = {}, worn = "", escapes = 0 }
	end
	return data.gear
end

-- Puts whatever they should be wearing onto whatever character they have.
-- Safe to call on a character that is half-built or already gone.
function CosmeticsService.applyToCharacter(player: Player)
	local worn = gearOf(player)
	local character = player.Character
	if not worn or not character then
		return
	end
	PlayerGear.attach(character, if worn.worn ~= "" then worn.worn else nil)
end

-- One most-wanted pursuit survived. Called by PoliceService and by nothing
-- else, because escaping any OTHER pursuit is a different achievement that
-- already pays in coins.
--
-- Returns the key of anything newly unlocked, so the caller can say so at the
-- moment it happened rather than leaving the player to find it in a menu.
function CosmeticsService.recordWantedEscape(player: Player): string?
	local worn = gearOf(player)
	if not worn then
		return nil
	end
	worn.escapes += 1

	-- Walked in display order so a run of escapes that crosses two rungs at
	-- once announces the lower one first. Only ONE is announced per escape:
	-- two unlock toasts in the same second would bury each other.
	local earned: string? = nil
	for _, key in ipairs(Config.GEAR_ORDER) do
		local spec = Config.GEAR[key]
		if spec and not worn.unlocked[key] and worn.escapes >= (spec.escapes or 1) then
			worn.unlocked[key] = true
			if not earned then
				earned = key
			end
		end
	end

	if earned then
		local spec = Config.GEAR[earned]
		-- Worn immediately. A reward that lands in a menu the player has to go
		-- and find is a reward they earned and did not receive -- and this one
		-- arrives at the exact moment they are looking at the screen, having
		-- just outrun a police officer.
		worn.worn = earned
		CosmeticsService.applyToCharacter(player)
		notify(player, ("UNLOCKED: %s. It's on you now."):format(spec.name), "loot")
	end

	DataService.save(player)
	CosmeticsService.push(player)
	return earned
end

-- Wear it or take it off. A toggle, like the accessories and the decorations,
-- because it is the only way to empty the slot without a second control.
function CosmeticsService.equipGear(player: Player, key: string)
	local worn = gearOf(player)
	local spec = Config.GEAR[key]
	if not worn or not spec then
		return
	end

	if not worn.unlocked[key] then
		-- Names the real requirement rather than refusing blankly, and reads it
		-- from the one place that knows it, so this line and the shop tile can
		-- never describe the same rung differently.
		notify(player, ("%s is locked. %s."):format(spec.name, Config.gearRequirement(key)), "warn")
		return
	end

	if worn.worn == key then
		worn.worn = ""
		notify(player, ("%s off."):format(spec.name), "good")
	else
		worn.worn = key
		notify(player, ("%s on!"):format(spec.name), "good")
	end

	CosmeticsService.applyToCharacter(player)
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

	-- The house that is STANDING, not the highest one owned -- and the sign
	-- names the same one. A sign announcing a Sky Castle over a Beach Villa
	-- would be boasting about a building that is not there.
	local shown = Config.getShownHouseLevel(data)

	PlotService.applySkin(plot, skinKey)
	PlotService.applyEffect(plot, cosmetics.effect)
	PlotService.setHouseLevel(plot, shown)
	PlotService.setDecor(plot, data.decor.placed)
	PlotService.applyAccessories(plot, gear(data).worn)
	PlotService.updateSign(plot, player.DisplayName, data.rebirths,
		Config.getSkin(skinKey).name, Config.getHouseTier(shown).name)
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
			notify(player, ("%s unlocks at %d rebirths. You have %d."):format(
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
			trim = skin.trim,
			-- Explicit for the ten drop-pool skins, from unlockRebirths for the
			-- three reset-locked ones, and from the price for the rest. See
			-- Config.rarityOf. Only the KEY crosses the wire; the client resolves
			-- the label and the colour, which it already has in Config.
			rarity = Config.rarityOf(skin),
			-- Only the ten drop-pool skins carry an explicit rarity, and they are
			-- the ONLY skins that are neither bought nor reset-gated. Without
			-- this flag the shop tile had nothing left to say about them and fell
			-- through to the price branch -- where a missing cost reads as zero,
			-- so the ten rarest skins in the game each advertised themselves as
			-- free, in gold, on the you-can-afford-this green.
			-- NOT a drop if it belongs to a set. Set skins carry a rarity like
			-- everything else so the shop can border the card, but `drop` is
			-- what makes the tile say REBIRTH DROP -- and a medal item that
			-- advertised itself as a rebirth reward would send players to
			-- the wrong feature entirely.
			drop = skin.rarity ~= nil and skin.set == nil,
			loot = skin.loot,
			set = skin.set,
		}
	end

	local effects: { [string]: any } = {}
	for key, effect in pairs(Config.EFFECTS) do
		effects[key] = {
			name = effect.name,
			order = effect.order,
			cost = effect.cost or 0,
			-- `effect.set` before the free-if-costless fallback, exactly as
			-- Config.isSkinUnlocked does. A set effect is priced in loot and
			-- therefore has no `cost`, and (nil or 0) <= 0 is TRUE -- so
			-- without this the Tractor Beam is unlocked for every player in
			-- the game from the first second.
			unlocked = (effect.set == nil and (effect.cost or 0) <= 0)
				or data.cosmetics.ownedEffects[key] == true,
			loot = effect.loot,
			set = effect.set,
			equipped = data.cosmetics.effect == key,
			-- The two ends of the particle gradient, so the shop card can be
			-- painted in the colours the effect actually throws off. An effect is
			-- the one cosmetic with nothing to show in a still image, and a row
			-- of identical grey tiles is what it looked like before. "None" has
			-- no ColorSequence and gets no swatch, which is correct.
			swatch = effect.color and effect.color.Keypoints[1].Value,
			swatch2 = effect.color and effect.color.Keypoints[#effect.color.Keypoints].Value,
			rarity = Config.rarityOf(effect),
		}
	end

	-- Houses are bought as a ladder and worn as a shelf: only the next rung is
	-- for sale, but every rung already bought can be moved back into. So a
	-- tile carries both states -- `owned` says it can be lived in, `current`
	-- says it is the one standing right now, and they are no longer the same
	-- question.
	local level = data.houseLevel or 0
	local shown = Config.getShownHouseLevel(data)
	local houses = {}
	for i, tier in ipairs(Config.HOUSE_TIERS) do
		houses[i] = {
			name = tier.name,
			order = i,
			cost = tier.cost or 0,
			blurb = tier.blurb,
			owned = (i - 1) <= level,
			current = (i - 1) == shown,
			forSale = (i - 1) == level + 1,
			rarity = Config.rarityOf(tier),
			walls = tier.walls,
		}
	end

	local decorItems = {}
	for key, item in pairs(Config.DECOR_ITEMS) do
		decorItems[key] = {
			name = item.name,
			order = item.order,
			cost = item.cost,
			loot = item.loot,
			set = item.set,
			zone = item.zone,
			swatch = item.swatch,
			blurb = item.blurb,
			rarity = Config.rarityOf(item),
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
		local rarity = Config.RARITIES[spec.rarity]
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

	-- MOST WANTED GEAR. Locked entries are SENT rather than filtered out, the
	-- same call the ride stances make: the shop is where something you do not
	-- own is supposed to be advertised, and a list that quietly omitted the
	-- locked ones would leave the whole reward track invisible to everybody who
	-- has not already earned it.
	local worn = data.gear or { unlocked = {}, worn = "", escapes = 0 }
	local gearList = {}
	for _, key in ipairs(Config.GEAR_ORDER) do
		local spec = Config.GEAR[key]
		if spec then
			table.insert(gearList, {
				key = key,
				name = spec.name,
				blurb = spec.blurb,
				rarity = spec.rarity,
				unlocked = worn.unlocked[key] == true,
				equipped = worn.worn == key,
				requirement = Config.gearRequirement(key),
				-- How far along they are, so a locked tile is a progress bar
				-- rather than a closed door.
				have = worn.escapes,
				need = spec.escapes or 1,
			})
		end
	end

	Remotes.get("CosmeticState"):FireClient(player, {
		skins = skins,
		effects = effects,
		houses = houses,
		houseLevel = level,
		houseShown = shown,
		decor = decorItems,
		accessories = accessories,
		gear = gearList,
		collection = {
			owned = have,
			total = Config.rollableAccessoryCount(),
			-- nil once the set is complete, which is how the client knows to
			-- swap the roll button for the finished state rather than showing
			-- a price for something that can no longer be bought.
			cost = if have < Config.rollableAccessoryCount() then Config.getRollCost(have) else nil,
			-- The balance travels with the price, so the client can colour the
			-- roll button without knowing what the currency is called or
			-- needing a second remote to ask for it.
			loot = math.floor(data.loot or 0),
			currency = Config.ROLL_CURRENCY.plural,
		},
	})
end

function CosmeticsService.start()
	-- Most Wanted gear is a CSG solid and CSG is server-only, so the shells are
	-- built here and replicate to every client from ReplicatedStorage.
	PlayerGear.prewarm()

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
		elseif kind == "gear" then
			CosmeticsService.equipGear(player, key)
		elseif kind == "roll" then
			-- The key is ignored: a roll's outcome is picked by the server from
			-- the pool it maintains. Letting a client name what it wanted would
			-- be the entire exploit.
			CosmeticsService.rollAccessory(player)
		end
	end)
end

return CosmeticsService
