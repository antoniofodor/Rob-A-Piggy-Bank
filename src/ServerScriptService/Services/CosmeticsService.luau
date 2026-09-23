--!strict
--[[
	CosmeticsService

	Skins and effects for the piggy bank: buying them, equipping them, and
	putting them on the plot.

	This is the game's answer to "what am I grinding for?".

	Every other purchase in the game is temporary -- rebirth wipes income,
	and both upgrade trees back to zero. Cosmetics are the one
	thing rebirth never touches, so they accumulate for the life of the
	account. That gives a player something ahead of them that a reset can't
	take away, and because the piggy is visible from across the map, every
	coin spent here is something other people can see.

	None of it affects balance. That's what makes it safe to price steeply.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- NO `TextService`. The dog's name was the only player-authored text this
-- game showed to anybody, and it is picked from `Config.DOG_NAMES` now, so
-- there is nothing left here to filter. Anything that brings free text back
-- brings the filter call back with it -- see `CosmeticsService.nameDog`.

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerGear = require(ReplicatedStorage.Shared.PlayerGear)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
-- BOTH SAFE RATHER THAN CYCLES: SetService requires DataService and
-- nothing else, and PassService requires Config, Players and
-- MarketplaceService. Neither reaches back here.
local SetService = require(script.Parent.SetService)
local PassService = require(script.Parent.PassService)
-- THE TROPHY SHELF. One direction only: this file needs the progress
-- figures for a locked card and the plinth ladder for a priced one, and
-- TrophyService requires DataService and PlotService alone -- so it
-- reaches its own push back through a registry `Main` fills in rather
-- than by requiring this file. Same shape as SetService, same reason.
local TrophyService = require(script.Parent.TrophyService)

local CosmeticsService = {}
local collectionPushers: { (Player) -> () } = {}
function CosmeticsService.registerCollectionPusher(fn: (Player) -> ())
	table.insert(collectionPushers, fn)
end

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
-- Tapping a house card either buys that house or moves into one already
-- owned. EVERY HOUSE IS ITS OWN PURCHASE (schema 26): there is no "next
-- rung", so the only gates are the price fitting the pig and the coins
-- being there. "Buy the X first" is not a sentence this function knows.
--
-- Moving between owned houses matters because a house is pure taste, and a
-- player who liked the Villa's look should not be punished for having
-- bought a Tower -- nothing about the game changes with which one is
-- standing. It costs nothing, both ways, so there is no sell-and-rebuy loop
-- to farm.
-- "the Stone Manor", but "The Void" as named -- several revision-2 names
-- carry their own article, and "Moved into the The Void" is the result of
-- prefixing one blindly.
local function theHouse(tier): string
	return if tier.name:sub(1, 4) == "The " then tier.name else "the " .. tier.name
end
local function capitalise(text: string): string
	return text:sub(1, 1):upper() .. text:sub(2)
end

-- Anything that has to hear about a house landing -- the tree ladder, whose
-- gate reads the best owned house. Registered from Main, which requires both
-- services, so neither has to require the other.
local houseListeners: { (Player) -> () } = {}
function CosmeticsService.onHouseBought(fn: (Player) -> ())
	table.insert(houseListeners, fn)
end

function CosmeticsService.buyHouse(player: Player, requested: string)
	local data = DataService.get(player)
	if not data then
		return
	end

	-- The client sends the house's stable id. Validated against the
	-- catalogue here, so a forged or retired id buys nothing and says so.
	local tier = Config.getHouseById(requested)
	if not tier then
		notify(player, "That house is not on the street.", "warn")
		return
	end
	local houses = data.houses

	if houses.owned[tier.id] then
		if Config.getShownHouse(data).id == tier.id then
			notify(player, "You already live there.", "warn")
		else
			houses.shown = tier.id
			CosmeticsService.applyToPlot(player)
			notify(player, ("Moved into %s."):format(theHouse(tier)), "good")
			DataService.save(player)
			CosmeticsService.push(player)
		end
		return
	end

	-- ASKED BEFORE THE PRICE, because an earned house has no price and
	-- `tier.cost or 0` would sell the Golden Piggy for nothing.
	if tier.earned ~= nil then
		local have, need = Config.earnedHouseProgress(houses.owned)
		notify(player, ("%s is earned, not bought. Own every other house (%d of %d)."):format(
			capitalise(theHouse(tier)), have, need), "warn")
		return
	end

	local cost = tier.cost or 0
	-- ONE refusal. There used to be a second -- "your piggy bank can't hold
	-- that yet" -- for a price above the pig's capacity, because a bounded
	-- wallet made such a price impossible rather than dear. The pig has no
	-- ceiling now, so every price is a wait and the only refusal is coins.
	if data.coins < cost then
		notify(player, ("You need %s coins for that."):format(Config.formatCoins(cost)), "warn")
		return
	end

	data.coins -= cost
	houses.owned[tier.id] = true
	-- You move into what you just bought. Anything else would make the most
	-- expensive purchase in the game produce no visible change at all.
	houses.shown = tier.id

	-- applyToPlot, not setHouseLevel alone.
	--
	-- The plot sign carries the house name now, and setHouseLevel only builds
	-- the building -- so buying a house rebuilt it while the sign kept
	-- announcing the old one until the player next rejoined. applyToPlot is
	-- the function whose whole job is making the plot match the data, so
	-- anything that changes what the plot should look like goes through it.
	CosmeticsService.applyToPlot(player)

	notify(player, ("Moved into %s!"):format(theHouse(tier)), "good")
	CosmeticsService.grantEarnedHouses(player, data)
	for _, fn in ipairs(houseListeners) do
		fn(player)
	end
	DataService.save(player)
	CosmeticsService.push(player)
end

-- THE COMPLETION HOUSE, handed over the moment the last priced house lands.
-- Owned, not moved into: the player just paid for the house they are
-- standing in, and taking that view away from them to show a trophy would
-- make the purchase produce no visible change. The card and the toast say
-- where it is. Never revokes, so a house added to the catalogue later
-- raises the bar only for players who have not earned it yet.
function CosmeticsService.grantEarnedHouses(player: Player?, data: any): boolean
	local owned = data.houses.owned
	local have, need = Config.earnedHouseProgress(owned)
	if need == 0 or have < need then
		return false
	end
	local granted = false
	for _, tier in ipairs(Config.HOUSE_TIERS) do
		if tier.earned == "houses" and not owned[tier.id] then
			owned[tier.id] = true
			granted = true
			if player then
				notify(player, ("You own every house on the street. %s is yours. Move in from the shop!")
					:format(capitalise(theHouse(tier))), "good")
			end
		end
	end
	return granted
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

	-- A TROPHY IS NOT FOR SALE, AND THE REFUSAL NAMES WHAT WOULD EARN IT.
	--
	-- It has to come before the toggle below AND before the price check.
	-- Before the toggle, because an unearned trophy is not owned and would
	-- fall past it; before the price, because a trophy carries no `cost`
	-- at all and `data.coins < nil` throws -- which is the same shape as
	-- the ten drop-pool skins that once rendered "0" in the price row, one
	-- step louder.
	--
	-- A rejection nobody can see is indistinguishable from a broken
	-- feature, so it says the sentence rather than going quiet.
	if item.trophy then
		if decor.owned[key] then
			-- OWNED, AND NOT A LAWN ORNAMENT ANY MORE. Trophies belong to the
			-- house (the in-house room is retired and the real base takes them
			-- over later), so the toggle below would put one back on the grass
			-- and hold a slot a bought ornament could use. Said out loud rather than ignored: a card that does nothing
			-- when pressed is the silent failure this project refuses.
			notify(player, ("%s is on show in your house."):format(item.name), "good")
		else
			notify(player, ("%s is earned, not bought. %s."):format(
				item.name, Config.trophyRequirement(item.trophy)), "warn")
		end
		return
	end

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

-- THE ACCESSORY ROLL IS RETIRED WITH THE CATALOGUE IT DREW FROM.
--
-- `ownedCount`, `rollFrom` and `rollAccessory` went as one: with
-- `Config.ACCESSORIES` empty the pool is empty, so the roll could only ever
-- refuse -- and it refused by reporting the collection FINISHED, which is a
-- button that spends loot wearing a completed state, for a collection that
-- does not exist. `Config.getRollCost` and its two constants went with it.
--
-- `Config.ROLL_CURRENCY` WENT WITH IT IN THE END, and so did this file's
-- `getLoot`: the roll was one SPENDER of that currency, and then the currency
-- itself retired with the acorn track. There is one balance in this game.

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

	-- THE SIREN POST READS THIS SAME NUMBER, so an escape has to be given
	-- the chance to light a lamp. A second counter would be a second
	-- opinion about how many patrols somebody has outrun; there is one,
	-- and it is `worn.escapes` directly above.
	TrophyService.check(player)
	TrophyService.refresh(player)

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
	-- The pet is a fact about the PLAYER, not the plot, so it is published
	-- before the plot check: every client builds and walks it from this one
	-- attribute (Shared/Pets).
	if Config.PETS_ENABLED and data and type(data.pets) == "table" then
		local out = data.pets.equipped
		player:SetAttribute(Config.PET_ATTRIBUTE,
			if type(out) == "string" and Config.PETS[out] then out else "")
	else
		player:SetAttribute(Config.PET_ATTRIBUTE, "")
	end
	local plot = PlotService.getPlot(player)
	if not data or not plot then
		return
	end

	-- THE SIX LAWN PEDESTALS GO THROUGH THE SAME DOOR AS EVERY OTHER "make the
	-- plot match the data" repaint, which is what this function is for. Put
	-- here rather than at each site that can move a piggy -- a crate grant, a
	-- placement, a snatch, a rebirth -- because that would be five chances to
	-- leave it out and a missed one is a piggy that is earning and invisible.
	PlotService.setPiggySlots(plot, data)
	-- Both halves at a repaint, for the reason `EconomyService.refreshPlot`
	-- gives at length: the accrual tick publishes the figures only when a
	-- buffer MOVED, so a join onto a lawn already at its cap would show six
	-- cards with no number on them.
	PlotService.setPiggyBuffers(plot, data)

	local cosmetics = data.cosmetics

	-- THE BANK WEARS THE TILL PIGGY (designer decision 2026-09-22). The
	-- centre pig IS `data.piggies.till`: that key already decides what the
	-- bank earns (`EconomyService.slotRate` at slot 0), and a bank that
	-- earned as one piggy while dressed as another was the world and the
	-- server disagreeing, with the server being right. `Config.piggyKeyAt`
	-- is the one reader -- it falls back to Classic for a retired key, so a
	-- till never stands bare -- and the swap prompt is the one writer.
	--
	-- NO `isSkinUnlocked` GATE ANY MORE. That gate guarded a WARDROBE choice
	-- against a rebirth-locked skin; the till piggy is owned as an OBJECT in
	-- `piggies.owned`, counted the way every pedestal copy is, so there is no
	-- such thing as an unearned one standing here.
	local skinKey = Config.piggyKeyAt(data, 0)

	-- MIRRORED INTO THE WARDROBE FIELD, because that field still has readers
	-- that ask "what is this player wearing" -- the bag's `equipped` flag,
	-- `SetService.inUse`, the rebirth sign, the skin-theft `wasWorn` -- and
	-- every one of them must read the piggy that is actually on the bank.
	-- One source of truth (`piggies.till`) and one mirror written beside the
	-- thing it mirrors, rather than two fields two services can move apart.
	cosmetics.skin = skinKey

	-- The house that is STANDING, not the highest one owned -- and the sign
	-- names the same one. A sign announcing a Sky Castle over a Beach Villa
	-- would be boasting about a building that is not there.
	local shown = Config.getShownHouse(data)

	PlotService.applySkin(plot, skinKey)
	PlotService.applyEffect(plot, Config.DEFAULT_EFFECT)
	-- The finish goes on last: the two calls above reset what it adds.
	local finish = cosmetics.finish
	PlotService.applyFinish(plot, if type(finish) == "string" and finish ~= "" then finish else nil)
	-- The plot builds by POSITION (residents pick a house that way and
	-- House.build has always taken a level); a player's house is an id and
	-- this is the one seam where the two meet.
	PlotService.setHouseLevel(plot, Config.houseLevelOf(shown.id) or 0)
	-- BEFORE `setDecor`, AND THAT ORDERING IS THE WHOLE COST OF IT.
	--
	-- Four of the lawn ornaments are trophies whose SHAPE is a function of
	-- what their owner has done, so the plot has to be holding this
	-- session's numbers before anything builds one. Run after `setDecor`
	-- it would be correct and would rebuild the whole lawn a second time;
	-- run before, the state lands on a plot whose ornaments have not been
	-- built yet and the line below is the only rebuild.
	TrophyService.refresh(player)
	PlotService.setDecor(plot, data.decor.placed)
	-- AFTER the house and the fence, both of which this function has already
	-- put up: a window box hangs off sills that `setHouseLevel` has just
	-- created, and a border is clamped to a fence tier. Run earlier it would
	-- build against the previous plot and be silently one upgrade behind.
	PlotService.setGarden(plot, data.garden)
	PlotService.applyAccessories(plot, gear(data).worn)

	-- The dog's coat, on the same pass as everything else the plot wears.
	--
	-- A coat that has been retired from the catalogue falls back to the
	-- breed's own colours rather than rendering untinted -- `GuardDog` treats
	-- an unknown key as "no coat" -- and `DataService.reconcile` prunes the
	-- save on load, so this is the second of two guards rather than the only
	-- one. Same shape as the skin fallback above.
	local coat = (data.dogs and data.dogs.equipped) or ""
	if coat ~= "" and not Config.DOG_COATS[coat] then
		coat = ""
		if data.dogs then
			data.dogs.equipped = ""
		end
	end
	PlotService.setDogCoat(plot, coat)

	-- The guardian coat also paints its kennel; saved kennel skins remain dormant.

	-- Always one of `Config.DOG_NAMES` or "": the save cannot hold a name
	-- nobody approved, and reconcile drops any that predate the list.
	PlotService.setDogName(plot, (data.dogs and data.dogs.name) or "")

	-- THE PAID MARK ON THE SIGN, set before the sign is written.
	--
	-- `unlocked` rather than `owns`, which is the opposite call from the
	-- one `grantPassItems` makes and is right for the opposite reason: this
	-- writes nothing into the save, so an unset pass id showing the mark to
	-- everybody during development is a thing a developer can SEE and
	-- correct, where writing items into every save would be permanent.
	--
	-- FIRST MATCH WINS AND THE ORDER IS `pairs`, which is fine only while
	-- exactly one pass carries a `signStyle` -- and today only VIP does. A
	-- second one needs a rule about which outranks which rather than a
	-- hash deciding it, and this is where that rule would go.
	local style: string? = nil
	for passKey, pass in pairs(Config.PASSES or {}) do
		if pass.signStyle and PassService.unlocked(player, passKey) then
			style = pass.signStyle
			break
		end
	end
	PlotService.setSignStyle(plot, style)

	PlotService.updateRank(plot, data.robberies)
	PlotService.updateSign(plot, player.DisplayName, data.rebirths,
		Config.getSkin(skinKey).name, shown.name)
end

-- ============================================================
-- PURCHASE AND EQUIP
-- ============================================================

-- Wear a finish already earned, or take it off by asking twice. Finishes are
-- never bought: a season hands them over (SeasonService).
function CosmeticsService.equipFinish(player: Player, key: string)
	local data = DataService.get(player)
	local spec = Config.FINISHES[key]
	if not data or not spec then
		return
	end
	local c = data.cosmetics
	if not (c.ownedFinishes and c.ownedFinishes[key]) then
		-- THE SEASON LADDER THAT GRANTED THESE IS RETIRED, so there is no
		-- tier left to reach and no honest instruction to give. Said plainly
		-- rather than pointing at a thing that no longer exists.
		notify(player, ("%s is a season reward you have not earned."):format(spec.name), "warn")
		return
	end
	c.finish = if c.finish == key then "" else key
	CosmeticsService.applyToPlot(player)
	DataService.save(player)
	CosmeticsService.push(player)
end

function CosmeticsService.buySkin(player: Player, key: string)
	local skin = Config.SKINS[key]
	local data = DataService.get(player)
	if not skin or not data then
		return
	end

	local cosmetics = data.cosmetics
	if cosmetics.owned[key] or (not skin.chest and (skin.cost or 0) <= 0) then
		CosmeticsService.equipSkin(player, key)
		return
	end

	-- SKINS ARE CRATE-ONLY, AND THIS IS THE LINE THAT MAKES IT TRUE.
	--
	-- The direction was recorded a while ago and the shop was never changed,
	-- so for several sessions the game contradicted its own documentation:
	-- the Inventory panel's empty-skins message told players skins come from
	-- crates while this function happily sold them for coins. A decision half
	-- applied is worse than either answer, because neither half can be relied
	-- on.
	--
	-- IT DELIBERATELY REVERSES "NOTHING IS EVER LOCKED BEHIND LUCK", which is
	-- written twice elsewhere and was the right rule for a spinner sitting
	-- beside a shop. What it is traded for is the crate economy having a top
	-- end at all: a chest whose best prize can also be bought outright is a
	-- slower way to buy something, and the moment a player works that out the
	-- crate stops being worth opening.
	--
	-- WHAT KEEPS IT FAIR IS THAT BAD LUCK STILL ONLY COSTS TIME. A duplicate
	-- is a spare, three spares of a tier combine upward, and the combine's
	-- own arithmetic makes gathering a legendary cost about the same as
	-- rolling for one. There is no outcome here that is unreachable, only
	-- outcomes that are slower.
	--
	-- Crate skins have explicit rarities. Historical resale limits live in
	-- sellBasis, not cost; a missing coin price never makes a crate skin free.
	--
	-- REFUSED OUT LOUD RATHER THAN SILENTLY, because the client no longer
	-- draws a buy button and so nothing should ever reach this -- which means
	-- anything that DOES reach it is a stale client or a poked remote, and
	-- both want the same visible answer rather than a quiet return.
	notify(player, ("%s comes from crates now, not coins."):format(skin.name), "warn")
end

function CosmeticsService.buyEffect(player: Player, _key: string)
	-- Retired: stale clients cannot spend coins on a standalone piggy aura.
	notify(player, "Standalone piggy effects are no longer available.", "warn")
end

-- BUY-OR-EQUIP, THE ONE CONTROL A SKIN AND A DOG COAT ALREADY USE. The
-- card never has to decide which verb it is showing, and a second tap on
-- something owned is simply an equip.
--
-- IT DOES NOT TOGGLE, WHICH IS THE ONE PLACE IT DIFFERS FROM THE COAT.
-- A coat has no default row, so the toggle is the only route back to the
-- breed's own colours; `none` is a real member of this catalogue and is
-- how you turn a catch effect off, so a toggle here would only be a way
-- to un-equip by accident.
function CosmeticsService.buyCatch(player: Player, key: string)
	local spec = Config.CATCH_EFFECTS[key]
	local data = DataService.get(player)
	if not spec or not data or type(data.catch) ~= "table" then
		return
	end

	if data.catch.owned[key] or (spec.cost or 0) <= 0 then
		CosmeticsService.equipCatch(player, key)
		return
	end

	if data.coins < spec.cost then
		notify(player, ("Need %s more coins for %s.")
			:format(Config.formatCoins(spec.cost - data.coins), spec.name), "warn")
		return
	end

	data.coins -= spec.cost
	data.catch.owned[key] = true
	notify(player, ("Unlocked %s! It fires on the next thief you nab.")
		:format(spec.name), "good")

	CosmeticsService.equipCatch(player, key)
end

function CosmeticsService.equipCatch(player: Player, key: string)
	local data = DataService.get(player)
	local spec = Config.CATCH_EFFECTS[key]
	if not data or not spec or type(data.catch) ~= "table" then
		return
	end
	-- The free-if-costless fallback, exactly as `equipEffect` writes it and
	-- for the same reason: `none` costs nothing and everybody has it, so it
	-- must be equippable without ever having been bought. Nothing in this
	-- catalogue is priced in loot today, but the test is written the way the
	-- effects one is so that a set entry landing here later cannot be
	-- unlocked for the whole server by `(nil or 0) <= 0`.
	if (not Config.isEarnedElsewhere(spec) and (spec.cost or 0) <= 0) or data.catch.owned[key] then
		data.catch.equipped = key
		CosmeticsService.push(player)
	end
end

-- WHAT FIRES ON THE THIEF, asked by HeistService at the moment a nab lands.
-- Never `data.catch.equipped` read directly at the call site: an equipped
-- key can name something a player no longer owns (a revoke, a retired row,
-- a save from before this catalogue existed), and a burst nobody paid for
-- is the same silent wrongness as a shop card advertising a retired item.
function CosmeticsService.catchEffectOf(player: Player): string
	local data = DataService.get(player)
	local key = data and type(data.catch) == "table" and data.catch.equipped
	if type(key) ~= "string" or not Config.CATCH_EFFECTS[key] then
		return Config.DEFAULT_CATCH
	end
	if key ~= Config.DEFAULT_CATCH and not data.catch.owned[key] then
		return Config.DEFAULT_CATCH
	end
	return key
end

-- SETS OFF `nabber`'s NAB EFFECT ON `target`, which is the body of whoever
-- was nabbed: a player's character, or a neighbour's figure. ONE WRITER for
-- both, because they are one event -- the neighbour case lived nowhere for
-- the life of the catalogue, so every nab a solo player could ever make went
-- off with nothing on it. The key first and the counter last; `CatchFX`
-- watches the counter and reads the key, so a repeat still fires.
function CosmeticsService.fireCatchEffect(target: Model?, nabber: Player)
	if not target or not target.Parent then
		return
	end
	local key = CosmeticsService.catchEffectOf(nabber)
	if key == Config.DEFAULT_CATCH then
		return
	end
	target:SetAttribute(Config.CATCH_ATTRIBUTE, key)
	target:SetAttribute(Config.CATCH_BY_ATTRIBUTE, nabber.UserId)
	target:SetAttribute(Config.CATCH_COUNT_ATTRIBUTE,
		(target:GetAttribute(Config.CATCH_COUNT_ATTRIBUTE) or 0) + 1)
end
-- THE BANK IS NOT A WARDROBE ANY MORE, AND THIS SAYS SO OUT LOUD.
--
-- This used to write `cosmetics.skin` and repaint, which dressed the bank in
-- whatever the bag tapped. The bank wears the TILL piggy now (see
-- `applyToPlot`), and the only way onto the till is to carry a piggy up to
-- it and hold SWAP -- a rule with an accounting behind it that a tap here
-- has no way to keep (which copy comes off, and where does it go?). Left as
-- it was, a bag tap would have written a field `applyToPlot` immediately
-- overwrites: a control that does nothing when pressed, which is the one
-- failure this project refuses above all others. So it refuses, and names
-- the verb that does the job.
function CosmeticsService.equipSkin(player: Player, key: string)
	local data = DataService.get(player)
	if not data then
		return
	end
	local name = Config.getSkin(key).name
	if Config.piggyKeyAt(data, 0) == key then
		notify(player, ("%s is already on your piggy bank."):format(name), "warn")
		return
	end
	notify(player, ("Carry %s up to your piggy bank and hold SWAP to put it on the till.")
		:format(name), "warn")
end

function CosmeticsService.equipEffect(player: Player, key: string)
	-- Permit clearing legacy saves, never reactivating a retired cosmetic.
	local data = DataService.get(player)
	if not data or key ~= "none" then return end
	data.cosmetics.effect = Config.DEFAULT_EFFECT
	CosmeticsService.applyToPlot(player)
	CosmeticsService.push(player)
end

-- WEAR A COAT, OR TAKE IT OFF BY ASKING FOR IT TWICE.
--
-- A TOGGLE, the same call accessories, decorations and rides already make --
-- and here it is the ONLY route back to the breed's own colours, because
-- `Config.DOG_COATS` deliberately has no "default" row to keep in step with
-- `DOG_TIERS`. Without the toggle, a player who bought one coat could never
-- see their own Mastiff again.
--
-- That also means a test script which "equips" something already worn takes
-- it OFF instead -- a trap this project has now recorded twice. Drive it from
-- the pushed state, never from an assumed starting point.
function CosmeticsService.equipDogCoat(player: Player, key: string)
	local data = DataService.get(player)
	local coat = Config.DOG_COATS[key]
	if not data or not coat or type(data.dogs) ~= "table" then
		return
	end

	if not data.dogs.owned[key] then
		notify(player, ("%s isn't unlocked yet."):format(coat.name), "warn")
		return
	end

	data.dogs.equipped = if data.dogs.equipped == key then "" else key
	CosmeticsService.applyToPlot(player)
	CosmeticsService.push(player)
end

-- Buy a coat, or equip one already owned.
--
-- Same shape as `buySkin`: owning it makes this an equip rather than a second
-- purchase, so one control does both and the card never has to decide which
-- verb it is. The refusal names the SHORTFALL rather than the price, because
-- "need 4.2M more" is a thing a player can act on and "costs 12M" is not.
--
-- A COAT IS PURE TASTE AND CONFERS NOTHING, which is the line every cosmetic
-- in this game holds and the reason this may be bought with coins at all. It
-- changes `fur`, `furDark` and `collar`; the Guard Dog UPGRADE still decides
-- the tier, still lives in `upgrades`, and is still what rebirth takes.
function CosmeticsService.buyDogCoat(player: Player, key: string)
	local coat = Config.DOG_COATS[key]
	local data = DataService.get(player)
	if not coat or not data or type(data.dogs) ~= "table" then
		return
	end

	if data.dogs.owned[key] then
		CosmeticsService.equipDogCoat(player, key)
		return
	end

	local cost = coat.cost or 0
	if data.coins < cost then
		notify(player, ("Need %s more coins for %s."):format(
			Config.formatCoins(cost - data.coins), coat.name), "warn")
		return
	end

	data.coins -= cost
	data.dogs.owned[key] = true
	notify(player, ("Unlocked %s!"):format(coat.name), "good")

	CosmeticsService.equipDogCoat(player, key)
end

-- WEAR A KENNEL, OR PUT THE PLAIN WOODEN ONE BACK BY ASKING TWICE.
--
-- Compatibility endpoint for old clients; kennel colors now follow the guardian.
function CosmeticsService.equipDogKennel(_player: Player, _key: string)
	-- Legacy requests cannot change the guardian's automatically matched kennel.
end

-- THE GARDEN'S THREE CATALOGUES, DESCRIBED ONCE.
--
-- A border, a path and a window box are the same transaction three times --
-- buy it if you do not own it, wear it if you do, take it off if you are
-- already wearing it -- over three tables that differ only in their names.
-- Three near-identical `buyGardenBorder`/`buyGardenPath`/`buyGardenBox`
-- functions is the copy this project keeps recording as the thing that
-- drifts: `RideSound` kept a second copy of the ride-key grammar and broke
-- within the hour, and the mini piggy, `Decor.buildOne` and the coin
-- formatter are three more.
--
-- The place this is NOT done is the dog's coat and kennel, one function up:
-- they have unrelated shapes in the save (`owned`/`equipped` against
-- `kennels`/`kennel`). These three were designed as one shape on the same
-- afternoon.
local GARDEN_KINDS: { [string]: any } = {
	border = { catalogue = Config.BORDER_PLANTS, owned = "borders", worn = "border" },
	path = { catalogue = Config.GARDEN_PATHS, owned = "paths", worn = "path" },
	window = { catalogue = Config.WINDOW_BOXES, owned = "boxes", worn = "window" },
}

-- BUY IT, WEAR IT, OR PUT IT AWAY -- one control, so the card never has to
-- decide which verb it is showing. The same call the dog coats make.
--
-- THE PUT-AWAY IS THE HALF THAT NEEDS SAYING. Equipping the row you are
-- already wearing takes it off, because there is no second control for
-- "none" and a garden you cannot un-plant is a purchase that can only ever
-- be added to. That is the toggle `accessories` and `decor` already use, and
-- this file's parent records it as deliberate rather than incidental.
function CosmeticsService.buyGarden(player: Player, kind: string, key: string)
	local slot = GARDEN_KINDS[kind]
	local data = DataService.get(player)
	if not slot or not data then
		return
	end
	local spec = slot.catalogue[key]
	if not spec or type(data.garden) ~= "table" then
		return
	end

	local held = data.garden[slot.owned]
	if type(held) ~= "table" then
		return
	end

	if not held[key] then
		local cost = spec.cost or 0
		if data.coins < cost then
			notify(player, ("Need %s more coins for %s."):format(
				Config.formatCoins(cost - data.coins), spec.name), "warn")
			return
		end
		data.coins -= cost
		held[key] = true
		notify(player, ("Unlocked %s!"):format(spec.name), "good")
	end

	data.garden[slot.worn] = if data.garden[slot.worn] == key then "" else key

	-- The whole repaint rather than `setGarden` alone, which is the call every
	-- other cosmetic purchase in this file makes. A garden change is rare and
	-- a full `applyToPlot` cannot be out of step with itself; reaching for the
	-- one function that happens to be enough today is how a second path comes
	-- to disagree with the first. The coin balance follows on the economy
	-- tick, as it does for every other purchase here.
	CosmeticsService.applyToPlot(player)
	CosmeticsService.push(player)
end

function CosmeticsService.buyDogKennel(_player: Player, _key: string)
	-- Retired: reject old clients without charging or changing saved purchases.
end

-- BUY A PET, OR PUT ONE OUT. One pet at a time; asking for the one already
-- out puts it away, which is the only way to walk alone without a second
-- control. Same buy-or-equip shape as the kennel.
local function petsSave(data: any): any
	if type(data.pets) ~= "table" then
		data.pets = { owned = {}, equipped = "" }
	end
	if type(data.pets.owned) ~= "table" then data.pets.owned = {} end
	if type(data.pets.equipped) ~= "string" then data.pets.equipped = "" end
	return data.pets
end

function CosmeticsService.buyPet(player: Player, key: string)
	if not Config.PETS_ENABLED then return end
	local pet = Config.PETS[key]
	local data = DataService.get(player)
	if not pet or not data then
		return
	end
	local pets = petsSave(data)

	if not pets.owned[key] then
		local cost = pet.cost or 0
		if data.coins < cost then
			notify(player, ("Need %s more coins for %s."):format(
				Config.formatCoins(cost - data.coins), pet.name), "warn")
			return
		end
		data.coins -= cost
		pets.owned[key] = true
		pets.equipped = key
		notify(player, ("%s is following you!"):format(pet.name), "good")
	elseif pets.equipped == key then
		pets.equipped = ""
		notify(player, ("%s went home."):format(pet.name), "good")
	else
		pets.equipped = key
		notify(player, ("%s is following you."):format(pet.name), "good")
	end

	CosmeticsService.applyToPlot(player)
	CosmeticsService.push(player)
end

-- NAME THE DOG, FROM THE LIST IN `Config.DOG_NAMES`.
--
-- **NOTHING A PLAYER TYPES IS SHOWN TO ANYBODY ANY MORE.** This used to take
-- free text and filter it -- correctly, and it is gone anyway; see the header
-- on `Config.DOG_NAMES` for why a classifier that mostly works is not good
-- enough for a name standing over a kennel in a game for nine-year-olds.
--
-- THE WIRE STILL CARRIES THE NAME RATHER THAN AN INDEX, and the allowlist is
-- checked HERE. An index would have to be resolved against the same table
-- anyway, and it would make a stale client silently name somebody's dog the
-- wrong thing instead of being refused. So the client sends a string, this
-- refuses anything that is not in the catalogue, and what is stored is the
-- catalogue's OWN string rather than the one that arrived -- which is what
-- keeps a lookalike (trailing spaces, a homoglyph) from reaching a kennel
-- board.
--
-- No filter call, so no rate limit and no `namedAt`: the cooldown existed to
-- bound calls to somebody else's moderation service and there are none left to
-- bound. Clearing is still free and still means "go by the breed".
function CosmeticsService.nameDog(player: Player, wanted: string)
	local data = DataService.get(player)
	if not data or type(data.dogs) ~= "table" then
		return
	end

	local name = wanted:match("^%s*(.-)%s*$") or ""
	if name == "" then
		data.dogs.name = ""
		CosmeticsService.applyToPlot(player)
		CosmeticsService.push(player)
		notify(player, "Your dog goes by its breed again.", "good")
		return
	end

	-- The catalogue's own string, found by exact match. Not `table.find` on a
	-- lowered copy: two entries that differ only in case would then both
	-- resolve to whichever came first, and the list has no such pair today
	-- precisely because nothing here tries to be clever about near-misses.
	local approved: string? = nil
	for _, candidate in ipairs(Config.DOG_NAMES) do
		if candidate == name then
			approved = candidate
			break
		end
	end
	if not approved then
		-- A client that sends something off the list is either stale or
		-- forged, and neither is the player's doing -- so this says what the
		-- rule is rather than accusing anybody.
		notify(player, "Pick one of the names on the list.", "warn")
		return
	end

	data.dogs.name = approved
	CosmeticsService.applyToPlot(player)
	CosmeticsService.push(player)
	notify(player, ("Your dog is called %s now."):format(approved), "good")
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
			unlocked = Config.isSkinUnlocked(key, data.cosmetics.owned, data.rebirths),
			equipped = data.cosmetics.skin == key,
			body = skin.body,
			trim = skin.trim,
			rarity = Config.rarityOf(skin),
			loot = skin.loot,
			set = skin.set,
			-- WHICH PASS SELLS IT, and it travels as a NAME rather than as a
			-- key: the card prints it, and a client that had to look the name
			-- up would need `Config.PASSES` reachable from a render loop for
			-- one string. nil for everything else, which is what the render
			-- branch tests.
			passName = skin.pass and Config.PASSES[skin.pass]
				and Config.PASSES[skin.pass].name,
		}
	end

	local effects: { [string]: any } = {}
	-- Standalone auras are retired; preserve ownership in saves, omit UI offers.

	-- FINISHES (Phase 5.4): season rewards, so only OWNED ones are sent --
	-- the inventory never advertises a thing it cannot sell or explain.
	local finishes: { [string]: any } = {}
	local ownedFinishes = data.cosmetics.ownedFinishes or {}
	for key, spec in pairs(Config.FINISHES) do
		if ownedFinishes[key] then
			finishes[key] = {
				name = spec.name,
				order = spec.order,
				owned = true,
				equipped = data.cosmetics.finish == key,
				rarity = Config.rarityOf(spec),
				season = if type(spec.season) == "number" then spec.season else nil,
			}
		end
	end

	-- Houses are a shelf, not a ladder (schema 26): every house is for sale
	-- until it is owned, and every owned house can be moved into. So a card
	-- carries both states -- `owned` says it can be lived in, `current` says
	-- it is the one standing right now -- and is KEYED BY ID: the client
	-- sends `id` back, never a position. The array is in catalogue (price)
	-- order because the shop lists it that way.
	local shown = Config.getShownHouse(data)
	local houses = {}
	-- An EARNED house is never for sale; its card carries the progress
	-- instead, so a locked tile is a count rather than a price nobody can pay.
	local earnedHave, earnedNeed = Config.earnedHouseProgress(data.houses.owned)
	for i, tier in ipairs(Config.HOUSE_TIERS) do
		local owned = data.houses.owned[tier.id] == true
		houses[i] = {
			id = tier.id,
			name = tier.name,
			order = i,
			cost = tier.cost or 0,
			blurb = tier.blurb,
			owned = owned,
			current = tier.id == shown.id,
			forSale = not owned and tier.earned == nil,
			earned = tier.earned ~= nil or nil,
			earnedHave = if tier.earned ~= nil then earnedHave else nil,
			earnedNeed = if tier.earned ~= nil then earnedNeed else nil,
			placeholder = tier.placeholder == true or nil,
			rarity = Config.rarityOf(tier),
			walls = tier.walls,
		}
	end

	-- Computed ONCE for the whole catalogue rather than per card. Two of
	-- the four figures live outside `data.trophies` -- `totalStolen` at the
	-- top level and `escapes` inside `data.gear` -- so this is also the one
	-- place the shop asks how much anybody has stolen.
	local trophyCounts = TrophyService.counts(data)

	local decorItems = {}
	for key, item in pairs(Config.DECOR_ITEMS) do
		decorItems[key] = {
			name = item.name,
			order = item.order,
			cost = item.cost,
			loot = item.loot,
			set = item.set,
			passName = item.pass and Config.PASSES[item.pass]
				and Config.PASSES[item.pass].name,
			zone = item.zone,
			swatch = item.swatch,
			blurb = item.blurb,
			rarity = Config.rarityOf(item),
			-- THE TROPHY'S PROGRESS, so a locked card is a bar rather than a
			-- closed door -- the same call the Most Wanted gear already makes
			-- with its own `have`/`need` pair. Nil on the other eighteen,
			-- which is what the card renderer branches on.
			trophy = (function(): any?
				if not item.trophy then
					return nil
				end
				local spec = Config.TROPHIES[item.trophy]
				if not spec then
					return nil
				end
				return {
					have = trophyCounts[spec.count] or 0,
					need = spec.need,
					coins = spec.coins,
					requirement = spec.requirement,
				}
			end)(),
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

	-- THE DOG'S WARDROBE. Two colours cross the wire rather than three,
	-- because a card is a swatch and a swatch shows a body and a trim -- the
	-- same pair a piggy skin sends. `furDark` is muzzle-and-brow shading and
	-- reads as noise at card size.
	local dogsOwned = (data.dogs and data.dogs.owned) or {}
	local dogsWorn = (data.dogs and data.dogs.equipped) or ""
	local dogCoats: { [string]: any } = {}
	for key, coat in pairs(Config.DOG_COATS) do
		dogCoats[key] = {
			name = coat.name,
			order = coat.order,
			cost = coat.cost or 0,
			owned = dogsOwned[key] == true,
			equipped = dogsWorn == key,
			body = coat.fur,
			trim = coat.collar,
			-- Derived from the price, exactly as a skin's is. Every coat is
			-- bought with coins today, so there is no explicit rarity to send
			-- -- and the first one that ISN'T priced needs one in Config or it
			-- silently borders itself common.
			rarity = Config.rarityOf(coat),
		}
	end

	-- Empty legacy catalogue keeps older clients from selling retired skins.
	local dogKennels: { [string]: any } = {}

	-- THE TROPHY FRAMES. The bought half of the shelf, and the only half:
	-- what stands ON a plinth is earned, and nothing in this payload can
	-- buy it.
	--
	-- Two colours cross the wire rather than four, for the reason a kennel
	-- sends two: a card is a swatch, and a swatch shows a body and a trim.
	-- The plaque and the uplight are what the top two rungs BUY, and both
	-- are things you read on a lawn rather than on a 156-pixel tile.
	local standsOwned = (data.trophies and data.trophies.plinths) or {}
	local standing = (data.trophies and data.trophies.plinth) or ""
	local trophyPlinths: { [string]: any } = {}
	for key, spec in pairs(Config.TROPHY_PLINTHS) do
		trophyPlinths[key] = {
			name = spec.name,
			order = spec.order,
			cost = spec.cost or 0,
			owned = standsOwned[key] == true,
			equipped = standing == key,
			body = spec.base,
			trim = spec.trim,
			rarity = Config.rarityOf(spec),
		}
	end

	local petsData = (type(data.pets) == "table" and data.pets) or {}
	local petsOwned = petsData.owned or {}
	local pets: { [string]: any } = {}
	for key, pet in pairs(if Config.PETS_ENABLED then Config.PETS else {}) do
		pets[key] = {
			name = pet.name,
			order = pet.order,
			cost = pet.cost or 0,
			owned = petsOwned[key] == true,
			equipped = petsData.equipped == key,
			body = pet.body,
			trim = pet.trim,
			rarity = Config.rarityOf(pet),
		}
	end

	-- The catch-effect catalogue, built in the same shape as `effects`
	-- above so the client renders both through one card and one particle
	-- simulation. `swatch`/`swatch2` are the two ends of the burst's own
	-- gradient, which is the only honest still image a particle has.
	local catchOwned = (data.catch and data.catch.owned) or {}
	local catchEquipped = (data.catch and data.catch.equipped) or Config.DEFAULT_CATCH
	local catches: { [string]: any } = {}
	for key, spec in pairs(Config.CATCH_EFFECTS) do
		catches[key] = {
			name = spec.name,
			order = spec.order,
			cost = spec.cost or 0,
			unlocked = (not Config.isEarnedElsewhere(spec) and (spec.cost or 0) <= 0)
				or catchOwned[key] == true,
			set = spec.set,
			passName = spec.pass and Config.PASSES[spec.pass]
				and Config.PASSES[spec.pass].name,
			equipped = catchEquipped == key,
			swatch = spec.color and spec.color.Keypoints[1].Value,
			swatch2 = spec.color and spec.color.Keypoints[#spec.color.Keypoints].Value,
			rarity = Config.rarityOf(spec),
		}
	end

	-- THE ROBUX OFFERS.
	--
	-- Sent whether or not they are owned and whether or not they exist yet,
	-- because the shop is where something you do not own is supposed to be
	-- advertised -- filtering an unowned pass out of the payload would leave
	-- the offer with nothing on screen to explain what it buys, which is the
	-- same call the locked ride stances already make.
	--
	-- `id` IS NIL WHILE THE PASS DOES NOT EXIST, which is what the card
	-- reads to draw COMING SOON rather than a price. Prompting a purchase
	-- for id 0 throws, so the nil is doing real work rather than being tidy.
	local passes: { any } = {}
	for key, pass in pairs(Config.PASSES or {}) do
		table.insert(passes, {
			key = key,
			name = pass.name,
			blurb = pass.blurb,
			robux = pass.robux,
			id = PassService.idOf(key),
			-- `owns` rather than `unlocked`. A card saying OWNED to every
			-- player because the id is unset would hide the one state a
			-- developer most needs to see, and the COMING SOON branch already
			-- says what is true.
			owned = PassService.owns(player, key),
			soldWith = pass.soldWith,
			-- What it hands over, named. Derived from the catalogues rather
			-- than written out here, so a card can never advertise an item the
			-- grant does not give -- they read the same table.
			items = (function()
				local names: { string } = {}
				for _, entry in ipairs(Config.passItems(key)) do
					local spec = Config.getSetItem(entry.kind, entry.key)
					if spec and spec.name then
						table.insert(names, spec.name)
					end
				end
				return names
			end)(),
		})
	end
	table.sort(passes, function(a, b)
		-- Cheapest first. An offers shelf that leads with the dearest thing
		-- is a shelf a nine-year-old bounces off.
		return (a.robux or 0) < (b.robux or 0)
	end)

	-- THE GARDEN, THREE LISTS OFF ONE DESCRIPTION. Sorted here rather than on
	-- the client for the reason every other catalogue in this payload is: the
	-- order is a property of the shelf, and two ends sorting independently is
	-- two answers to one question.
	local garden: { [string]: any } = {}
	for kind, slot in pairs(GARDEN_KINDS) do
		local held = (data.garden and data.garden[slot.owned]) or {}
		local worn = (data.garden and data.garden[slot.worn]) or ""
		local list = {}
		for key, spec in pairs(slot.catalogue) do
			table.insert(list, {
				key = key,
				name = spec.name,
				order = spec.order,
				cost = spec.cost or 0,
				swatch = spec.swatch,
				blurb = spec.blurb,
				owned = held[key] == true,
				equipped = worn == key,
				-- Derived from the price like every other priced catalogue, so a
				-- row added at a new cost borders itself. See Config.rarityOf.
				rarity = Config.rarityOf(spec),
			})
		end
		table.sort(list, function(a, b)
			return (a.order or 0) < (b.order or 0)
		end)
		garden[kind] = list
	end

	Remotes.get("CosmeticState"):FireClient(player, {
		skins = skins,
		garden = garden,
		passes = passes,
		effects = effects,
		finishes = finishes,
		catches = catches,
		dogCoats = dogCoats,
		dogKennels = dogKennels,
		pets = pets,
		trophyPlinths = trophyPlinths,
		-- The dog's name as it is actually shown -- the FILTERED string, so
		-- the shop's text box reads back what the street sees rather than what
		-- was typed. "" means it goes by its breed.
		dogName = (data.dogs and data.dogs.name) or "",
		dogNames = Config.DOG_NAMES,
		houses = houses,
		houseShown = shown.id,
		decor = decorItems,
		accessories = accessories,
		gear = gearList,
		-- `collection` is gone with the accessory roll. `accessories` stays
		-- and is simply empty: it is built by walking the catalogue, so it
		-- costs nothing today and repopulates on its own if the catalogue
		-- ever does.
	})
	for _, push in ipairs(collectionPushers) do push(player) end
end

-- ============================================================
-- PASS-EXCLUSIVE ITEMS
-- ============================================================
--
-- GRANTED INTO THE SAVE RATHER THAN GATED AT RENDER TIME, and that is a
-- decision rather than the lazy option.
--
-- Gating means every card, every equip and every push asks PassService
-- whether this player may have this thing -- which is a question with a
-- WEB CALL behind it, cached per session, that can fail. Granting asks it
-- once, at the two moments the answer can change, and from then on a pass
-- item is an ordinary owned cosmetic that every existing path already
-- knows how to render, wear and save.
--
-- WHAT THAT COSTS, STATED PLAINLY: a refund does not take the items back.
-- That is the right way round for this audience and it is also what
-- `PassService`'s own header argues for -- an entitlement that survives a
-- lost save survives a lost session too, and a cosmetic clawed back off a
-- nine-year-old's piggy is a worse failure than one they kept.
--
-- THROUGH `SetService.grant`, NEVER A SECOND GRANT PATH. That function
-- already resolves all six catalogues through `Config.catalogueFor` and
-- pushes whichever service renders the thing -- so a pass granting a skin,
-- an aura and a catch effect costs nothing beyond the loop, and it cannot
-- drift from how a chest or an event grants the same item.
local function grantPassItems(player: Player, passKey: string)
	if not PassService.owns(player, passKey) then
		-- `owns` rather than `unlocked`. An unset pass id makes `unlocked`
		-- true for EVERYBODY, deliberately, so that content nobody can buy
		-- yet is not also content nobody can reach -- but writing those items
		-- into every save during development would be permanent, and would
		-- hand the whole server a paid exclusive the day the id was filled
		-- in. Locked content is SHOWN through `unlocked`; it is only ever
		-- WRITTEN through `owns`. Same split the entry-ride grant makes.
		return
	end
	local pass = Config.PASSES[passKey]
	local items = Config.passItems(passKey)
	local names: { string } = {}
	for _, entry in ipairs(items) do
		-- `grant` returns false when they already had it, so this is
		-- idempotent by construction and the announcement names only what
		-- actually arrived -- which matters because this runs at every join.
		if SetService.grant(player, entry.kind, entry.key) then
			local spec = Config.getSetItem(entry.kind, entry.key)
			if spec and spec.name then
				table.insert(names, spec.name)
			end
		end
	end
	if #names > 0 and pass then
		-- ONE CARD NAMING ALL OF THEM, not one per item. Three toasts for one
		-- purchase is where a reward turns into noise -- the same call
		-- EventService makes when it folds a loot count into the medal line.
		notify(player, ("%s unlocked: %s."):format(pass.name, table.concat(names, ", ")), "good")
	end
end

-- THERE IS NO `onPlayerReady` HERE, AND WRITING ONE WOULD HAVE BEEN A
-- FUNCTION THAT LOOKED LIKE IT DID THE WORK AND DID NOTHING.
--
-- `PassService.onPlayerReady` SPAWNS the ownership checks -- they are web
-- calls that yield, and Main's own comment says so in as many words: the
-- answer lands a moment later and pushes by itself. So at join time the
-- cache is cold, `owns` is false for everybody, and a grant called from
-- the join sequence would return early every single time.
--
-- `Granted` fires exactly when the answer arrives, which is the join case,
-- AND the instant a purchase completes, which is the other one. Those are
-- the only two moments a pass answer can change, so the event is the whole
-- hook -- the same call RideService's entry-ride grant makes.
function CosmeticsService.start()
	-- Most Wanted gear is a CSG solid and CSG is server-only, so the shells are
	-- built here and replicate to every client from ReplicatedStorage.
	PlayerGear.prewarm()

	PassService.Granted:Connect(function(player: Player, passKey: string)
		grantPassItems(player, passKey)
	end)

	Remotes.get("CosmeticRequest").OnServerEvent:Connect(function(player, kind, key)
		if type(kind) ~= "string" or type(key) ~= "string" then
			return
		end
		if kind == "skin" then
			CosmeticsService.buySkin(player, key)
		elseif kind == "effect" then
			CosmeticsService.buyEffect(player, key)
		elseif kind == "catch" then
			CosmeticsService.buyCatch(player, key)
		elseif kind == "finish" then
			CosmeticsService.equipFinish(player, key)
		elseif kind == "house" then
			CosmeticsService.buyHouse(player, key)
		elseif kind == "decor" then
			CosmeticsService.buyDecor(player, key)
		elseif kind == "accessory" then
			CosmeticsService.equipAccessory(player, key)
		elseif kind == "gear" then
			CosmeticsService.equipGear(player, key)
		elseif kind == "border" or kind == "path" or kind == "window" then
			-- The three garden catalogues, routed through one function with the
			-- kind carried rather than three branches into three near-identical
			-- ones. `buyGarden` refuses an unknown kind on its own, so the list
			-- here is the only place the set is written down.
			CosmeticsService.buyGarden(player, kind, key)
		elseif kind == "dogcoat" then
			-- Buy-or-equip, like a skin: one control, and the card never has
			-- to decide which verb it is showing.
			CosmeticsService.buyDogCoat(player, key)
		elseif kind == "dogkennel" then
			CosmeticsService.buyDogKennel(player, key)
		elseif kind == "pet" then
			CosmeticsService.buyPet(player, key)
		elseif kind == "plinth" then
			-- Buy-or-equip, routed to the service that owns the shelf rather
			-- than duplicated here. This file only knows which remote a card
			-- pressed; what a plinth costs and what it repaints is
			-- TrophyService's business.
			TrophyService.buyPlinth(player, key)
		elseif kind == "dogname" then
			-- `key` is a name from `Config.DOG_NAMES`, or "" to go back to the
			-- breed. Checked against that list in `nameDog`: this is no longer
			-- free text, and nothing a client sends here reaches a kennel
			-- board unless the catalogue already contained it.
			CosmeticsService.nameDog(player, key)
		end
	end)
end

return CosmeticsService
