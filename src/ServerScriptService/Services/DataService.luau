--!strict
--[[
	DataService

	Session-locked player persistence.

	The lock is the whole point. Without it, the same player joining two
	servers at once ends up with two live copies of their piggy bank, and whichever
	server saves last wins -- which is the classic Roblox duplication exploit.
	Every load claims a lock; every release clears it; a lock left behind by a
	crashed server goes stale and gets stolen after LOCK_STALE_SECONDS.

	If DataStores are unavailable (Studio with API access turned off), this
	falls back to in-memory storage so development still works. It says so
	loudly, because shipping in that state would silently lose every player.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = {}

export type PlayerData = {
	schema: number,
	-- THE PIGGY BANK. One balance, all of it in the pig, all of it stealable.
	-- `vault` used to be the stealable half and `coins` the banked half;
	-- schema 17 merged them (see reconcile), because the split was the reason
	-- nobody robbed anybody -- CLAUDE.md, THE ROBBING PIVOT.
	coins: number,
	-- How many times this account has joined a server. The first session gets
	-- the long new-player shield; every later one gets the short join shield.
	sessions: number,
	incomeLevel: number,
	capacityLevel: number,
	rebirths: number,
	-- Skin key -> season index of its loss. Filled for existing schema-25 saves.
	claims: { [string]: number },
	-- Daily claim. `lastDay` is a UTC day index, not a timestamp: the only
	-- question ever asked of it is which day it was, and storing the day
	-- directly means no timezone can get between the save and the answer.
	daily: { lastDay: number, streak: number, lifetime: number, crate: string },
	-- Boosts held, by key, and the wall-clock second the active one ends.
	-- Held rather than applied on claim -- see Config.BOOSTS for why.
	boosts: { [string]: number },
	boostUntil: number,
	boostMult: number,
	lastSave: number,
	-- Lifetime delivered robberies, against any target; survives rebirth.
	robberies: number,
	totalStolen: number,
	totalLost: number,
	-- THE WEEKLY LADDER. `index` is a UTC week index, never a timestamp, for
	-- the reason `daily.lastDay` is a day index: the only question asked of it
	-- is which week, so no clock can get between the save and the answer.
	-- `stolen` is coins taken from VICTIMS this week -- the same figure the rap
	-- sheet counts, never the doubled payout, so it measures what was actually
	-- taken rather than what was minted on the way home.
	--
	-- Rolled over lazily, when it is next read or written. Nothing has to
	-- happen at midnight on Sunday, so nothing schedules anything.
	week: { index: number, stolen: number },
	-- MOST WANTED GEAR: worn by the player's own character, never bought.
	--
	-- `escapes` is the lifetime count of most-wanted pursuits survived and is
	-- what unlocks the tiers; `unlocked` is what they have earned; `worn` is the
	-- one piece actually on, or "" for none. Three fields rather than two
	-- because the counter has to survive the unlock -- later tiers are further
	-- up the same ladder, so throwing the count away at tier 1 would restart
	-- everyone at zero for tier 2.
	--
	-- NEVER RESET BY REBIRTH, like every other cosmetic. Rebirth already costs
	-- a player every upgrade they own; the collection is the reason to press
	-- the button.
	gear: {
		unlocked: { [string]: boolean },
		worn: string,
		escapes: number,
	},
	-- THE TROPHY SHELF. Schema 23.
	--
	-- What a yard is allowed to boast about, and it is deliberately a
	-- record of THINGS DONE rather than of things held. Coins held are
	-- already printed over every pig in gold by the rob badge, so a yard
	-- advertising them harder would only paint a bigger target.
	--
	-- `victims` is the collection: one key per PIGGY SKIN successfully
	-- robbed and delivered, which is what the Victim Shelf stands a little
	-- pig of. A SET rather than a count, because the shelf shows WHICH
	-- ones -- and because a number could never tell you whether the next
	-- robbery adds to it.
	--
	-- `caught` and `bestSpree` are the two figures this game was not
	-- keeping anywhere. Everything else a trophy reads already existed:
	-- `totalStolen` since the heist system shipped and `gear.escapes`
	-- since the most-wanted gear did, both written on every event and
	-- displayed on no screen in the game.
	--
	-- `plinths` and `plinth` are the bought half -- the owned set and the
	-- one standing -- which is the same owned/worn pair the kennels, the
	-- coats and the skins all keep, so the shop card and the equip toggle
	-- needed nothing new.
	--
	-- NEVER RESET BY REBIRTH. A trophy is a record of what an account has
	-- done and rebirth already costs every upgrade somebody owns; wiping
	-- the shelf as well would make the one decision this economy most
	-- needs players to take also the one that erases their history.
	trophies: {
		victims: { [string]: boolean },
		caught: number,
		bestSpree: number,
		-- Phase 5.2: clean cracks delivered, times topping Most Wanted, and
		-- acorns harvested from the player's own tree, lifetime.
		clean: number,
		wanted: number,
		harvested: number,
		plinths: { [string]: boolean },
		plinth: string,
	},
	-- PHASE 5.3: THE SEASON. `index` is the `Config.seasonIndex` these
	-- numbers belong to; `earned` is acorns earned in it, `tier` the tier
	-- reached, `granted` which tier rewards already landed (so a crossing
	-- grants once and never twice), `best` the best tier ever (the Season
	-- Cup). Rolled lazily on read by SeasonService.
	season: { index: number, earned: number, tier: number, best: number,
		granted: { [string]: boolean } },
	-- PHASE 5.1: who robbed this player most this season. Keyed by the
	-- thief's UserId as a string, at most `Config.NEMESIS_ROWS` rows.
	nemesis: { index: number, rows: { [string]: { name: string, count: number } } },
	-- PHASE 5.5: thieves stopped this week, for Top Defenders.
	defend: { index: number, count: number },
	upgrades: { [string]: number },
	-- Prestige, not power. Never reset by rebirth.
	--
	-- HOUSES BY STABLE ID (schema 26). `owned` is a set of `Config.HOUSE_TIERS`
	-- ids and `shown` is the one standing on the plot. Any house may be bought
	-- when its price fits the pig, any owned house may be moved into for
	-- free, and the shack is always owned. Read the standing house through
	-- `Config.getShownHouse(data)` rather than trusting `shown`: it falls back
	-- to the dearest owned house if `shown` is stale. The two numeric fields
	-- this replaced (`houseLevel`, `houseShown`) are read ONCE in reconcile
	-- and deleted.
	houses: { owned: { [string]: boolean }, shown: string },
	-- SPARE COPIES, one count per item, keyed "kind:key" -- the grammar
	-- `Config.chestEntry` already owns, because a bare key does not say
	-- which of the five catalogues it came from. There are no collisions across
	-- the 92 keys today, and that is exactly the sort of fact that stops being
	-- true quietly.
	--
	-- A SPARE IS AN EXTRA COPY. Ownership lives in the five owned tables and
	-- this counts what is held BEYOND the one that grants it, so a non-zero
	-- entry always implies ownership and selling the last spare leaves the
	-- player still owning one. Spares are sold for coins or combined by tier --
	-- see Config.COMBINE and Config.sellValue.
	spares: { [string]: number },
	-- LOOT. The second currency and the only one besides coins: earned by
	-- delivering a robbery (and at events when they return), never
	-- purchasable, and what the accessory roll and the set items cost. Schema
	-- 17 merged the old `medals` and `tokens` fields into it one-for-one.
	--
	-- Never wiped by rebirth, like every other cosmetic track.
	loot: number,
	acornsGrownAt: number,
	-- THE TREE LADDER (step 2.7). The bought level, 0..#Config.TREE_LEVELS-1.
	-- Survives rebirth like the houses that gate it; only the deferred Legacy
	-- reset may take it.
	tree: { level: number },
	treeAcorns: number,
	groundAcorns: number,
	acornsDroppedAt: number,
	decor: {
		owned: { [string]: boolean },
		-- slot id -> item key. Auto-assigned on purchase.
		placed: { [string]: string },
	},
	-- THE GARDEN. Schema 24.
	--
	-- A SECOND DECORATION TRACK THAT SPENDS NO SLOT, which is the whole
	-- reason it is not folded into `decor` above. That table is a NINE-SLOT
	-- SHELF and its scarcity is a design decision `docs/MASTER-PLAN.md` states
	-- twice; a border, a path and a window box hang on the fence, the gate
	-- walk and the house instead, so they are equipped rather than placed.
	--
	-- Three owned tables and three equipped strings, the shape `dogs` already
	-- uses for a coat and a kennel -- and for the same reason: one of each at
	-- a time, so there is nothing for a `placed` map to hold. "" is none and
	-- is always legal.
	garden: {
		borders: { [string]: boolean },
		paths: { [string]: boolean },
		boxes: { [string]: boolean },
		border: string,
		path: string,
		window: string,
	},
	-- THE DOG'S WARDROBE. Schema 20.
	--
	-- `owned` is the collection and `equipped` is the one being worn, "" for
	-- the breed's own colours -- the same owned/worn split `accessories` and
	-- `cosmetics` already use, so the equip toggle and the shop card need
	-- nothing new.
	--
	-- A COAT IS PURE TASTE AND IS NEVER WIPED BY REBIRTH, which is the bracket
	-- every cosmetic in this game sits in. What it must never touch is the
	-- Guard Dog UPGRADE level: that is power, it lives in `upgrades`, and
	-- rebirth takes it. A thief reads the dog to price the risk, so a coat
	-- that could imply a tier would be a defence upgrade sold for money --
	-- see the header on `Config.DOG_COATS` for the measurement that says the
	-- tier read survives on shape alone.
	dogs: {
		owned: { [string]: boolean },
		equipped: string,
		-- The name the owner gave it, ALREADY FILTERED, or "" for the breed's
		-- own label. What is stored is what came back from
		-- `TextService:FilterStringAsync`, never what the client typed -- so a
		-- save can never be a delivery mechanism for unfiltered text, and a
		-- name written before a filter rule changed is re-filtered on its next
		-- rename rather than being trusted forever.
		name: string,
		-- `os.time()` of the last rename, for the rate limit on the filter
		-- call. Absolute rather than a countdown so it survives a rejoin.
		namedAt: number,
		-- Which kennel skins are owned, and which one is standing. A SECOND
		-- pair rather than a shared one: a coat and a kennel are bought
		-- separately, worn together, and neither may reach the other's
		-- colours -- see `Config.DOG_KENNELS`. Both are new keys INSIDE an
		-- existing table, which `reconcile` fills in one level down, so they
		-- cost no schema bump.
		kennels: { [string]: boolean },
		kennel: string,
		-- The toys: bought, and out. TWO tables, the same pair `data.decor`
		-- already keeps, and for the same reason -- one table would make
		-- "put it away" mean "sell it", and nothing in this game refunds
		-- anything.
		toys: { owned: { [string]: boolean }, out: { [string]: boolean } },
	},
	cosmetics: {
		owned: { [string]: boolean },
		ownedEffects: { [string]: boolean },
		skin: string,
		effect: string,
		-- Phase 5.4: the finish worn over the skin ("" for none) and the
		-- finishes earned.
		finish: string,
		ownedFinishes: { [string]: boolean },
	},
	-- Schema 21. THE THIRD KIND OF COSMETIC, and it is deliberately its own
	-- top-level table rather than two more fields inside `cosmetics`: that
	-- one is what the PIGGY wears, and a catch effect is not worn by
	-- anything -- it fires on the person you just nabbed. Filing it under
	-- the piggy's wardrobe would be the first time a name in this save
	-- stopped describing what is in it.
	catch: { owned: { [string]: boolean }, equipped: string },
	-- Client-side preferences. Nothing in here may ever affect what a player
	-- can do -- these are read by the HUD and by nothing that decides an
	-- outcome, which is what keeps them safe to let a client write.
	settings: { music: boolean, hotbar: { order: { string }, hidden: { string } } },
}

local store: DataStore? = nil
local usingFallback = false
local fallbackStore: { [string]: any } = {}

local cache: { [Player]: PlayerData } = {}
local loading: { [Player]: boolean } = {}

local JOB_ID = if game.JobId ~= "" then game.JobId else "studio-" .. tostring(os.time())

local function defaultData(): PlayerData
	local upgrades: { [string]: number } = {}
	for key in pairs(Config.UPGRADES) do
		upgrades[key] = 0
	end

	return {
		schema = Config.SCHEMA_VERSION,
		coins = 0,
		sessions = 0,
		incomeLevel = 1,
		capacityLevel = 1,
		rebirths = 0,
		lastSave = os.time(),
		robberies = 0,
		totalStolen = 0,
		totalLost = 0,
		-- Schema 19. reconcile descends one level, so an existing save picks
		-- up both fields rather than only the parent table -- and a brand new
		-- field defaulting to zero needs no migration branch, which is the
		-- same free ride `loot` and `spares` took.
		week = { index = 0, stolen = 0 },
		-- Schema 23, and the same free ride `week`, `dogs` and `catch` each
		-- took: a brand new top-level table that the generic pass in
		-- `reconcile` fills in on every existing save, with no migration
		-- branch and nothing that can run twice. Every field defaults to
		-- empty or zero, so a save written before trophies existed joins
		-- with an empty shelf rather than with a payout.
		season = { index = 0, earned = 0, tier = 0, best = 0, granted = {} },
		nemesis = { index = 0, rows = {} },
		defend = { index = 0, count = 0 },
		trophies = { victims = {}, caught = 0, bestSpree = 0, clean = 0, wanted = 0, harvested = 0,
			plinths = {}, plinth = "" },
		upgrades = upgrades,
		houses = { owned = { shack = true }, shown = "shack" },
		-- LOOT. Flat, never scaled by income, never wiped by rebirth -- it buys
		-- cosmetics, which are the permanent track. See the type above.
		loot = 0,
		acornsGrownAt = os.time(),
		-- A new top-level table: the generic fill in `reconcile` gives every
		-- existing save level 0, which is the tree they already have.
		tree = { level = 0 },
		treeAcorns = 0, groundAcorns = 0, acornsDroppedAt = 0,
		-- Spare copies by "kind:key". Missing keys read as zero, so an item
		-- added later needs no migration -- the shape `consumables` uses.
		spares = {},
		claims = {},
		decor = { owned = {}, placed = {} },
		-- Schema 24. A new top-level table, so the generic fill picks it up on
		-- every existing save with no migration branch -- the same free ride
		-- `week`, `loot`, `spares` and `dogs` each took. Nothing is owned and
		-- nothing is equipped, which is a bare lawn: exactly what every save
		-- already had.
		garden = {
			borders = {}, paths = {}, boxes = {},
			border = "", path = "", window = "",
		},
		-- Schema 20. A new top-level table, so the generic fill below picks it
		-- up on every existing save with no migration branch -- the same free
		-- ride `week`, `loot` and `spares` took. Doing it BEFORE any UI exists
		-- is what keeps it free: the same change after a tab ships needs a
		-- real payout, and a payout that runs on every join is a money printer.
		-- `name` and `namedAt` are NEW KEYS INSIDE AN EXISTING TABLE, which is
		-- the free case: the generic pass in `reconcile` descends one level,
		-- so a save written at schema 20 picks them up without a version bump.
		-- That is the same ride a seventh entry in `upgrades` takes, and the
		-- reason this file's comment there says adding one "must fill in just
		-- that key on every existing save".
		dogs = { owned = {}, equipped = "", name = "", namedAt = 0,
			kennels = {}, kennel = "",
			toys = { owned = {}, out = {} } },
		-- Bone stock, by key. Counts only; missing keys read as zero, so a
		-- bone added later needs no migration.
		--
		-- NOT wiped by rebirth, unlike every other offensive purchase. A bone
		-- is spent the moment it is thrown, so a stockpile is not standing
		-- power the way a maxed tree is -- and wiping it would only teach
		-- players to burn their stock the hour before rebirthing, which is a
		-- chore, not a decision.
		consumables = {},
		-- Never reset by rebirth. This is the account's permanent collection.
		-- Rolled, never bought, and never wiped by rebirth -- accessories are
		-- the flex that survives a reset, same bracket as skins and houses.
		-- `worn` is one key per slot; `owned` is the collection.
		accessories = { owned = {}, worn = {} },
		-- What the player gets around on. `equipped` is "" for on foot, and is
		-- a string rather than nil so reconcile's one-level fill can see it --
		-- a nil default is indistinguishable from a field that was never added.
		--
		-- Survives rebirth, like every other purely cosmetic track. A ride
		-- confers nothing in a fight; taking it away at a reset would just be a
		-- reason not to press the button.
		rides = { owned = {}, equipped = "" },
		-- Schema 22: `crate` is the day-seven chest this save is still OWED.
		-- It is a KEY into `Config.CHESTS` and an empty string means nothing
		-- is waiting, so a save that has one survives a disconnect between the
		-- claim and the walk to the doorstep -- which is the whole reason the
		-- reward moved out of the claim in the first place. reconcile descends
		-- one level, so an existing save picks up just this key.
		daily = { lastDay = 0, streak = 0, lifetime = 0, crate = "" },
		boosts = {},
		boostUntil = 0,
		boostMult = 1,
		-- Schema 13. reconcile descends one level, so an existing save picks up
		-- all three of these rather than just the parent table.
		gear = { unlocked = {}, worn = "", escapes = 0 },
		cosmetics = {
			owned = {},
			ownedEffects = {},
			skin = Config.DEFAULT_SKIN,
			effect = Config.DEFAULT_EFFECT,
			finish = "",
			ownedFinishes = {},
		},
		-- Schema 21, and the same free ride `week` and `dogs` took: a brand
		-- new top-level table filled in by the generic pass in `reconcile`,
		-- so an existing save picks it up on its next join with no migration
		-- branch and nothing that can run twice. Landed in the same change
		-- as the catalogue and BEFORE any UI reads it, which is the window
		-- the `shards`-to-`spares` entry says is the only free one.
		catch = { owned = {}, equipped = Config.DEFAULT_CATCH },
		-- Music defaults ON. A player who wants it off finds the toggle once
		-- and it is remembered; defaulting to off would mean nobody ever
		-- hears it and the whole thing may as well not ship.
		-- The hot bar's arrangement, filled by reconcile's one-level descent
		-- for every save written before it existed. Two empty arrays is the
		-- default bar: catalogue order, nothing shelved.
		settings = { music = true, hotbar = { order = {}, hidden = {} } },
	}
end

local function keyFor(player: Player): string
	return "Player_" .. tostring(player.UserId)
end

-- Fills in fields added by later schema versions without touching existing
-- values. Real migrations (renames, rescaling) branch on envelope.schema here.
--
-- Descends one level into table fields, which matters for `upgrades`: adding
-- a seventh upgrade later must fill in just that key on every existing save,
-- not leave it nil because the parent table already existed.
local function reconcile(data: any): PlayerData
	local base = defaultData()
	if type(data) ~= "table" then
		return base
	end

	-- Before generic defaults: legacy saves catch up from their last save,
	-- capped to the same eight-hour allowance as coins. Existing cursors keep
	-- their partial hour across saves and server changes.
	data.acornsGrownAt = Config.acornGrowthCursor(
		if data.acornsGrownAt == nil then data.lastSave else data.acornsGrownAt, os.time())
	-- Existing loot stays banked. Adding tree stock never copies the wallet.
	local function stock(value: any, cap: number): number
		if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return 0 end
		return math.clamp(math.floor(value), 0, cap)
	end
	-- Clamped to the largest cap any house allows here; the house set is not
	-- resolved yet. Re-clamped to this save's own cap once it is (below).
	local largestCap = Config.ACORNS.growCap
	for _, gate in pairs(Config.TREE_HOUSE_GATE) do
		largestCap = math.max(largestCap, gate.cap)
	end
	data.treeAcorns = stock(data.treeAcorns, largestCap)
	data.groundAcorns = stock(data.groundAcorns, 1000000)
	data.acornsDroppedAt = Config.acornGrowthCursor(data.acornsDroppedAt or 0, os.time())
	Config.expireGroundAcorns(data, os.time())
	local previousSchema = tonumber(data.schema) or 0

	-- Schema 17: THE PIG IS THE WALLET. `vault` (the stealable pile) and
	-- `coins` (the banked balance) became one field, and `medals` and
	-- `tokens` became `loot`. Both merges are one-for-one and additive, and
	-- both run before the generic fill so the old fields are consumed rather
	-- than left beside a zeroed new one. Idempotent: a save that has already
	-- been through this has no `vault`, `medals` or `tokens` to add.
	if type(data.vault) == "number" then
		data.coins = (tonumber(data.coins) or 0) + data.vault
		data.vault = nil
	end
	if type(data.medals) == "number" or type(data.tokens) == "number" then
		data.loot = (tonumber(data.loot) or 0)
			+ (tonumber(data.medals) or 0) + (tonumber(data.tokens) or 0)
		data.medals = nil
		data.tokens = nil
	end

	-- Schema 18: `shards` (a counter per rarity tier) became `spares` (a count
	-- per item), and the old field is DROPPED rather than converted.
	--
	-- There is nothing to convert -- a tier counter cannot say which item it
	-- came from -- and nothing to lose, because there was no chest UI anywhere
	-- when this shipped: the only shards that have ever existed came out of the
	-- admin console. Doing it now is what makes that true, and it is the whole
	-- reason this landed before the tab rather than after it.
	--
	-- Nothing is refunded, exactly as the retired ornaments below are not. A
	-- version that DID pay out would have to be measured idempotent first, and
	-- one that pays on every join is a money printer -- a far worse bug than
	-- the one being fixed.
	data.shards = nil

	-- Schema 26: HOUSES BY STABLE ID. The numeric ladder (`houseLevel`, the
	-- highest rung bought; `houseShown`, the rung standing, which schema 9
	-- split off it) becomes `houses = { owned = { [id] = true }, shown = id }`
	-- read against `Config.HOUSE_LEGACY_ORDER`, the nine ids in the order the
	-- ladder counted them, frozen.
	--
	-- DERIVE-ONLY. `owned` is exactly the rungs the old level said were
	-- bought -- a ladder owned every rung below its top, so a level-8 save
	-- owns nine houses -- and never one more. `shown` keeps today's clamp
	-- through `Config.legacyShownHouseLevel`: a shown rung above the owned
	-- one builds the owned one, and a missing one (pre-schema-9) means the
	-- newest. Both legacy fields are DELETED, because two meanings never
	-- share one save and the only reader of the old shape is this block.
	-- Idempotent by construction: a save carrying `houses` is not touched
	-- here, and a second run finds no `houseLevel` to read.
	--
	-- Runs BEFORE the generic fill for the reason the schema-9 rule it
	-- replaces did: the fill would otherwise hand every existing save the
	-- default of "owns the shack, shows the shack" and evict a player with a
	-- Sky Castle into a Starter Shack.
	if type(data.houses) ~= "table" and type(data.houseLevel) == "number" then
		local order = Config.HOUSE_LEGACY_ORDER
		local level = math.clamp(math.floor(data.houseLevel), 0, #order - 1)
		local owned = {}
		for rung = 0, level do
			owned[order[rung + 1]] = true
		end
		local shown = Config.legacyShownHouseLevel(level, data.houseShown)
		data.houses = { owned = owned, shown = order[shown + 1] }
	end
	data.houseLevel = nil
	data.houseShown = nil

	-- HOUSES ARE PRUNED AGAINST THE CATALOGUE, for the reason decor is, and
	-- the shack is always owned because level 0 always was. `shown` is
	-- resolved through the same fallback every reader uses -- an unowned or
	-- unknown id falls back to the dearest owned house, never the shack --
	-- and written back so the save says what the plot shows.
	if type(data.houses) == "table" then
		if type(data.houses.owned) ~= "table" then
			data.houses.owned = {}
		end
		for id, held in pairs(data.houses.owned) do
			if held ~= true or not Config.getHouseById(id) then
				data.houses.owned[id] = nil
			end
		end
		data.houses.owned.shack = true
		data.houses.shown = Config.getShownHouse(data).id
	end

	-- THE TREE (step 2.7): a whole level on the ladder, and ripe stock no
	-- larger than what this save's best house lets the tree hold. Houses are
	-- never lost in play, so the second clamp only bites a hand-edited save.
	if type(data.tree) ~= "table" then
		data.tree = { level = 0 }
	end
	data.tree.level = Config.treeLevelOf(data)
	data.treeAcorns = math.min(data.treeAcorns, Config.treeCap(data))

	-- DECOR IS PRUNED AGAINST THE CATALOGUE, not against a list of names.
	--
	-- Retiring the Wheelie Bins and the two parked cars left dead keys in
	-- every save that owned one, and a `placed` entry pointing at an item or a
	-- slot that no longer exists -- the driveway slot went with the cars.
	-- Neither errors: `Decor.buildOne` simply returns nil and the ornament
	-- quietly never appears, which is the failure mode this project spends the
	-- most words on.
	--
	-- Written against the catalogue rather than as a one-off migration on
	-- purpose. Anything retired later is handled with no new code and no
	-- version to remember, and there is no table sitting in Config that
	-- somebody has to notice is safe to delete. It is also cheap: a handful of
	-- keys, once, on load.
	--
	-- Nothing is refunded. The game is in beta; a retired ornament is simply
	-- gone.
	if type(data.decor) == "table" then
		if type(data.decor.owned) == "table" then
			for key in pairs(data.decor.owned) do
				if not Config.DECOR_ITEMS[key] then
					data.decor.owned[key] = nil
				end
			end
		end
		if type(data.decor.placed) == "table" then
			local realSlot = {}
			for _, slot in ipairs(Config.DECOR_SLOTS) do
				realSlot[slot.id] = true
			end
			for slot, key in pairs(data.decor.placed) do
				if not realSlot[slot] or not Config.DECOR_ITEMS[key] then
					data.decor.placed[slot] = nil
				end
			end
		end
	end

	-- DOG COATS ARE PRUNED AGAINST THE CATALOGUE, for the reason decor is.
	--
	-- Retiring a coat leaves a dead key in every save that owned one, and an
	-- `equipped` pointing at something `Config.DOG_COATS` no longer holds.
	-- Neither errors -- `GuardDog.applyTier` resolves an unknown key to nil
	-- and falls back to the breed's own colours, which is the right graceful
	-- degradation and is also exactly the silent-failure shape this project
	-- keeps recording: the player sees a plain dog and nothing says why.
	--
	-- Written against the catalogue rather than as a one-off, so a coat
	-- retired later needs no new code and no schema version to remember.
	-- Nothing is refunded, the same call the retired ornaments make.
	if type(data.dogs) == "table" then
		if type(data.dogs.owned) == "table" then
			for key in pairs(data.dogs.owned) do
				if not Config.DOG_COATS[key] then
					data.dogs.owned[key] = nil
				end
			end
		end
		-- "" is the breed look and is always legal; anything else has to be a
		-- coat that still exists AND is still owned, or it falls back.
		local worn = data.dogs.equipped
		if type(worn) ~= "string" or (worn ~= "" and not Config.DOG_COATS[worn]) then
			data.dogs.equipped = ""
		end

		-- The same two guards for the kennel, against its own catalogue.
		-- Written out rather than folded into a loop over the pair: the two
		-- tables have different names in the save and a helper taking four
		-- arguments to save eight lines is the kind of indirection that makes
		-- the next retirement harder to reason about, not easier.
		if type(data.dogs.kennels) == "table" then
			for key in pairs(data.dogs.kennels) do
				if not Config.DOG_KENNELS[key] then
					data.dogs.kennels[key] = nil
				end
			end
		end
		local den = data.dogs.kennel
		if type(den) ~= "string" or (den ~= "" and not Config.DOG_KENNELS[den]) then
			data.dogs.kennel = ""
		end

		-- And the toys, against their own catalogue. BOTH tables, because a
		-- retired toy left in `out` would be asked for by `GuardDog.setToys`
		-- on every join and quietly do nothing -- the silent failure this
		-- prune exists to prevent, one table along from where anybody would
		-- look for it.
		if type(data.dogs.toys) == "table" then
			for _, field in ipairs({ "owned", "out" }) do
				local held = data.dogs.toys[field]
				if type(held) == "table" then
					for key in pairs(held) do
						if not Config.DOG_TOYS[key] then
							held[key] = nil
						end
					end
				end
			end
		end
	end

	-- THE WARDROBE IS PRUNED AGAINST ITS OWN CATALOGUES, AND THE WORN FIELD
	-- IS THE ONE THAT ACTUALLY MATTERED.
	--
	-- Retiring a skin leaves three kinds of dead key behind and only one of
	-- them is visible. `cosmetics.owned` and the `skin:` half of `spares` go
	-- unread, because every surface that draws a wardrobe walks the CATALOGUE
	-- rather than the save -- so an orphan there is dead weight, and a
	-- stranded spare is a few coins the player can no longer sell.
	--
	-- `cosmetics.skin` is different, and it fails in the shape this file
	-- refuses everywhere else. `Config.getSkin` falls back to the default on
	-- an unknown key -- correct, and it is why nothing throws -- so a player
	-- who was wearing a retired skin comes back as Classic Pink while their
	-- save still says otherwise. The pig and the save disagree, the bag shows
	-- nothing equipped, and there is no error anywhere to explain it.
	--
	-- Written against the catalogues rather than as a one-off migration, the
	-- same call the coats, the ornaments and the garden all make: five skins
	-- were retired when the collections became OG and Animal, and the next
	-- retirement needs no new code and no schema version to remember.
	if type(data.cosmetics) == "table" then
		for _, pair in ipairs({
			{ owned = "owned", worn = "skin", catalogue = Config.SKINS,
				fallback = Config.DEFAULT_SKIN },
			{ owned = "ownedEffects", worn = "effect", catalogue = Config.EFFECTS,
				fallback = Config.DEFAULT_EFFECT },
		}) do
			local held = data.cosmetics[pair.owned]
			if type(held) == "table" then
				for key in pairs(held) do
					if not pair.catalogue[key] then
						held[key] = nil
					end
				end
			end
			-- Unlike the garden's "", there is no legal empty here: a piggy is
			-- always wearing SOMETHING, so an unknown key falls back to the
			-- default rather than to nothing.
			local worn = data.cosmetics[pair.worn]
			if type(worn) ~= "string" or not pair.catalogue[worn] then
				data.cosmetics[pair.worn] = pair.fallback
			end
		end
	end

	-- AND THE SPARES THOSE SKINS LEFT BEHIND. Keyed `kind:key`, so the grammar
	-- has to be split before a catalogue can be asked. A spare of a retired
	-- item is unsellable and uncombinable, so it is weight in the save and
	-- nothing else -- and `Config.catalogueFor` answers for all five kinds,
	-- so this covers a retired ride or ornament as well as a skin.
	if type(data.spares) == "table" then
		for entry in pairs(data.spares) do
			local kind, key = tostring(entry):match("^(%w+):(.+)$")
			local catalogue = kind and Config.catalogueFor(kind)
			if not catalogue or not key or not catalogue[key] then
				data.spares[entry] = nil
			end
		end
	end

	-- THE GARDEN IS PRUNED AGAINST ITS THREE CATALOGUES, for the reason the
	-- coats and the ornaments above it are.
	--
	-- Retiring a border leaves a dead key in every save that owned one and an
	-- equipped value naming something `Config.BORDER_PLANTS` no longer holds.
	-- Neither errors: `refreshBorder` resolves an unknown key to nil and
	-- builds nothing at all, which is the correct graceful degradation and is
	-- also exactly the silent failure this function exists to stop -- the
	-- player sees a bare fence and nothing anywhere says why.
	--
	-- Written as a loop over the three PAIRS rather than nine lines, which is
	-- the opposite call the dog coats made one block up. The difference is
	-- real: those three tables have unrelated names in the save (`owned`,
	-- `kennels`, `toys.out`) and unrelated shapes, where these are three
	-- copies of one shape that were designed together. A helper reaching
	-- across genuinely different tables is indirection; a loop over identical
	-- ones is what stops the fourth garden catalogue being pruned in two
	-- places and equipped in one.
	if type(data.garden) == "table" then
		for _, pair in ipairs({
			{ owned = "borders", worn = "border", catalogue = Config.BORDER_PLANTS },
			{ owned = "paths", worn = "path", catalogue = Config.GARDEN_PATHS },
			{ owned = "boxes", worn = "window", catalogue = Config.WINDOW_BOXES },
		}) do
			local held = data.garden[pair.owned]
			if type(held) == "table" then
				for key in pairs(held) do
					if not pair.catalogue[key] then
						held[key] = nil
					end
				end
			end
			-- "" is a bare lawn and is always legal; anything else has to be a
			-- row that still exists, or it falls back.
			local worn = data.garden[pair.worn]
			if type(worn) ~= "string" or (worn ~= "" and not pair.catalogue[worn]) then
				data.garden[pair.worn] = ""
			end
		end
	end

	-- THE TROPHY SHELF IS PRUNED AGAINST THREE CATALOGUES, and the first
	-- of them is the one that would actually throw.
	--
	-- `victims` holds SKIN KEYS, and the Victim Shelf stands a real
	-- `PiggyModel.build` of each one. Every other prune in this function
	-- guards a silent failure -- an ornament that never appears, a coat
	-- that falls back to the breed colours -- and this one guards a build
	-- error on a lawn, inside `Decor.build`, which takes the whole
	-- rebuild with it. Retiring a skin is a thing this catalogue has
	-- already done nine times.
	--
	-- Written against the catalogues rather than as a one-off migration,
	-- for the reason the decor and the coats above are: anything retired
	-- later is handled with no new code and no version to remember.
	if type(data.trophies) == "table" then
		if type(data.trophies.victims) == "table" then
			for key in pairs(data.trophies.victims) do
				if not Config.SKINS[key] then
					data.trophies.victims[key] = nil
				end
			end
		end
		if type(data.trophies.plinths) == "table" then
			for key in pairs(data.trophies.plinths) do
				if not Config.TROPHY_PLINTHS[key] then
					data.trophies.plinths[key] = nil
				end
			end
		end
		-- "" is the plain concrete and is always legal; anything else has
		-- to be a plinth that still exists.
		local stand = data.trophies.plinth
		if type(stand) ~= "string" or (stand ~= "" and not Config.TROPHY_PLINTHS[stand]) then
			data.trophies.plinth = ""
		end
	end

	for key, value in pairs(base) do
		if data[key] == nil then
			data[key] = value
		elseif type(value) == "table" and type(data[key]) == "table" then
			for innerKey, innerValue in pairs(value) do
				if data[key][innerKey] == nil then
					data[key][innerKey] = innerValue
				end
			end
		end
	end

	-- FINISHES (Phase 5.4) are pruned against the catalogue like every other
	-- wardrobe, and the worn one must be owned or it comes off.
	do
		local c = data.cosmetics
		if type(c.ownedFinishes) ~= "table" then
			c.ownedFinishes = {}
		end
		for key, held in pairs(c.ownedFinishes) do
			if held ~= true or not Config.FINISHES[key] then
				c.ownedFinishes[key] = nil
			end
		end
		if type(c.finish) ~= "string" or (c.finish ~= "" and not c.ownedFinishes[c.finish]) then
			c.finish = ""
		end
		-- The season and nemesis tables need their one-deeper shape.
		for _, key in ipairs({ "season", "nemesis", "defend" }) do
			if type(data[key]) ~= "table" then
				data[key] = base[key]
			end
		end
		if type(data.season.granted) ~= "table" then
			data.season.granted = {}
		end
		if type(data.nemesis.rows) ~= "table" then
			data.nemesis.rows = {}
		end
	end

	-- Schema 25 converts arithmetic ownership to saved ownership. Keep these
	-- historical thresholds here: changing catalogue rewards must not change
	-- what an older save already earned. Never restore a later sold/stolen skin.
	if previousSchema < 25 then
		local thresholds = { bronze = 1, goldleaf = 3, diamond = 6 }
		for key, threshold in pairs(thresholds) do
			if (tonumber(data.rebirths) or 0) >= threshold then
				data.cosmetics.owned[key] = true
			end
		end
	end
	-- Older saves start at zero: stolen coin totals cannot recover a count.
	local robberies = data.robberies
	if type(robberies) ~= "number" or robberies ~= robberies or math.abs(robberies) == math.huge then
		data.robberies = 0
	else
		data.robberies = math.max(0, math.floor(robberies))
	end
	if type(data.claims) ~= "table" then data.claims = {} end
	Config.pruneBuybackClaims(data.claims)
	data.sinceLegendary = nil
	data.schema = Config.SCHEMA_VERSION
	return data
end

local function lockIsStale(lock: any): boolean
	if type(lock) ~= "table" or type(lock.timestamp) ~= "number" then
		return true
	end
	return (os.time() - lock.timestamp) > Config.LOCK_STALE_SECONDS
end

-- ============================================================
-- BACKEND
-- ============================================================

local function initStore()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DATASTORE_NAME)
	end)

	if ok and result then
		-- GetDataStore succeeds even with API access off; the failure only
		-- shows up on a real request. Probe with a cheap read.
		local probeOk = pcall(function()
			return result:GetAsync("__probe__")
		end)
		if probeOk then
			store = result
			return
		end
	end

	usingFallback = true
	warn(string.rep("=", 70))
	warn("[DataService] DataStores unavailable -- using IN-MEMORY fallback.")
	warn("  Progress will NOT persist across sessions or servers.")
	warn("  Fix: Studio > File > Game Settings > Security >")
	warn("       'Enable Studio Access to API Services'.")
	warn(string.rep("=", 70))
end

-- Runs `transform` against the stored envelope, retrying on transient failure.
local function updateEnvelope(key: string, transform: (any) -> any?): (boolean, any)
	if usingFallback then
		local updated = transform(fallbackStore[key])
		if updated == nil then
			return false, nil
		end
		fallbackStore[key] = updated
		return true, updated
	end

	local activeStore = store
	if not activeStore then
		return false, nil
	end

	local result: any = nil
	for attempt = 1, 4 do
		local ok, err = pcall(function()
			activeStore:UpdateAsync(key, function(existing)
				local updated = transform(existing)
				result = updated
				return updated
			end)
		end)

		if ok then
			return result ~= nil, result
		end

		warn(("[DataService] UpdateAsync failed for %s (attempt %d): %s"):format(key, attempt, tostring(err)))
		task.wait(attempt * 2)
	end

	return false, nil
end

-- ============================================================
-- PUBLIC API
-- ============================================================

-- Claims the session lock and loads the player's data. Returns nil if the
-- lock could not be claimed, in which case the caller should kick the player
-- rather than let them play against unsaved state.
function DataService.load(player: Player): PlayerData?
	if cache[player] then
		return cache[player]
	end
	if loading[player] then
		return nil
	end
	loading[player] = true

	local key = keyFor(player)
	local claimed: PlayerData? = nil

	-- A live lock usually means the player's previous server hasn't finished
	-- releasing yet. Give it a few seconds before treating it as contested.
	for attempt = 1, 5 do
		local ok, envelope = updateEnvelope(key, function(existing)
			local lock = existing and existing.lock

			if lock and not lockIsStale(lock) and lock.jobId ~= JOB_ID then
				return nil -- someone else holds it; abort this write
			end

			return {
				lock = { jobId = JOB_ID, timestamp = os.time() },
				data = existing and existing.data or defaultData(),
			}
		end)

		if ok and envelope then
			claimed = reconcile(envelope.data)
			break
		end

		if attempt < 5 then
			task.wait(2)
		end
	end

	loading[player] = nil

	if not claimed then
		warn(("[DataService] Could not claim lock for %s"):format(player.Name))
		return nil
	end

	-- Counted on load rather than by a caller, so nothing can forget to. The
	-- shield reads this on the same join.
	claimed.sessions = (claimed.sessions or 0) + 1

	cache[player] = claimed
	return claimed
end

function DataService.get(player: Player): PlayerData?
	return cache[player]
end

-- Writes current data and refreshes the lock timestamp. Keeps the lock held.
function DataService.save(player: Player): boolean
	local data = cache[player]
	if not data then
		return false
	end

	data.lastSave = os.time()

	local ok = updateEnvelope(keyFor(player), function(existing)
		local lock = existing and existing.lock
		-- Only write if we still hold the lock. If another server stole it
		-- (because we went unresponsive), our data is stale -- drop it rather
		-- than clobber theirs.
		if lock and lock.jobId ~= JOB_ID and not lockIsStale(lock) then
			return nil
		end
		return {
			lock = { jobId = JOB_ID, timestamp = os.time() },
			data = data,
		}
	end)

	return ok
end

-- Final write, then clears the lock so the player can join elsewhere.
local beforeRelease: { (Player) -> () } = {}
function DataService.onBeforeRelease(handler: (Player) -> ())
	table.insert(beforeRelease, handler)
end

function DataService.release(player: Player)
	local data = cache[player]
	if not data then return end
	for _, handler in ipairs(beforeRelease) do
		local ok, err = pcall(handler, player)
		if not ok then warn("[DataService] before release: " .. tostring(err)) end
	end

	data.lastSave = os.time()

	updateEnvelope(keyFor(player), function(existing)
		local lock = existing and existing.lock
		if lock and lock.jobId ~= JOB_ID and not lockIsStale(lock) then
			return nil
		end
		return { lock = nil, data = data }
	end)

	cache[player] = nil
end

function DataService.start()
	initStore()

	task.spawn(function()
		while true do
			task.wait(Config.AUTOSAVE_INTERVAL)
			for player in pairs(cache) do
				if player.Parent then
					DataService.save(player)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		DataService.release(player)
	end)

	-- Studio gives BindToClose very little time; live servers get 30s.
	game:BindToClose(function()
		if RunService:IsStudio() and usingFallback then
			return
		end
		local pending = 0
		for player in pairs(cache) do
			pending += 1
			task.spawn(function()
				DataService.release(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

function DataService.isUsingFallback(): boolean
	return usingFallback
end

return DataService
