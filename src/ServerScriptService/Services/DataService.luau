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
	-- `capacityLevel` sat here until the pig's ceiling was removed; reconcile
	-- prunes it from every existing save, unrefunded (the game is in beta).
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
	-- THE PIGGY PRESS'S HOPPER: the piggy keys waiting in each tier's bay.
	-- Nothing comes back out of it, so this is the ONLY record of a piggy
	-- between being fed in and the bay filling -- `take` has already taken
	-- it out of `owned`, and `CombineService.feed` saves in the same breath
	-- as the insert for exactly that reason.
	press: { [string]: { string } },
	-- PIGGIES ROBBED, LIFETIME. Counted at the moment a snatched piggy is
	-- SECURED on the thief's own plinth (`PiggyHaulService`), never at the
	-- grab -- the same line `totalStolen` draws for coins: caught, nabbed or
	-- returned never counts. A PLAYER counter: a neighbour's snatch runs the
	-- resident core, which touches no save. Read by the street leaderboard.
	-- Survives rebirth, like every other record of things done.
	piggiesStolen: number,
	-- HAS THIS SAVE BEEN HANDED ITS STARTER LASSOS (`Config.LASSO.starter`)?
	-- A flag rather than a check on the stock, because a player who spends
	-- every lasso must not get the starter back on the next join.
	lassoStarter: boolean,
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
		-- Phase 5.2: clean cracks delivered and times topping Most Wanted,
		-- lifetime. `harvested` counted acorns off the player's own tree. It is
		-- kept as an inert counter nothing writes and nothing reads, because
		-- `TrophyService` still carries it across its own pushes and dropping a
		-- field from a payload shape is a bigger edit than the currency was.
		clean: number,
		wanted: number,
		harvested: number,
		-- The highest bounty ever on this player's head; the wanted poster in
		-- their house prints it, and session heat cannot supply it.
		bestBounty: number,
		plinths: { [string]: boolean },
		plinth: string,
	},
	-- PHASE 5.1: who robbed this player most this season window. Keyed by the
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
	-- THERE IS ONE CURRENCY. `loot` -- the acorn balance, and before that the
	-- merged medals and tokens -- is gone with the tree that filled it and the
	-- crates it bought. Schema 29 deletes it and the five tree fields beside
	-- it; see `Config.SCHEMA_VERSION`.
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
	-- every cosmetic in this game sits in. It cannot imply a tier that has
	-- not been bought either, which used to be a rule about what a coat may
	-- reach and is now true by construction: the Guard rung is retired, every
	-- plot has the same dog, and a coat picks what that dog LOOKS like. See
	-- `Config.DOG_LEVEL`.
	dogs: {
		owned: { [string]: boolean },
		equipped: string,
		-- The name the owner picked, which is always one of
		-- `Config.DOG_NAMES`, or "" for the breed's own label. Naming used to
		-- be free text put through the moderation filter; it is a fixed list
		-- now, so a save cannot carry player-authored text at all. Reconcile
		-- drops anything that is not on the list, which is what clears the
		-- typed names written while the text box existed.
		name: string,
		-- Which kennel skins are owned, and which one is standing. A SECOND
		-- pair rather than a shared one: a coat and a kennel are bought
		-- separately, worn together, and neither may reach the other's
		-- colours -- see `Config.DOG_KENNELS`. Both are new keys INSIDE an
		-- existing table, which `reconcile` fills in one level down, so they
		-- cost no schema bump.
		kennels: { [string]: boolean },
		kennel: string,
	},
	-- The pets: owned, and the one out ("" for none). A new top-level table,
	-- which `reconcile` fills in on every existing save with no schema bump.
	pets: { owned: { [string]: boolean }, equipped: string },
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
	settings: { music: boolean, musicVolume: number, hotbar: { order: { string }, hidden: { string } } },
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

	-- THE PIGGY PRESS'S HOPPER, ONE BAY PER TIER, DERIVED FROM `Config.PRESS`
	-- RATHER THAN LISTED. A second copy of that tier list here is the
	-- near-identical duplicate this project keeps recording, and it would go
	-- stale in the direction that is hardest to notice: a tier the save has
	-- no table for is one `CombineService` creates lazily anyway, so nothing
	-- would error and nothing would be lost -- it would simply drift.
	local press: { [string]: { string } } = {}
	for _, tier in ipairs(Config.PRESS.tiers) do
		press[tier] = {}
	end

	return {
		schema = Config.SCHEMA_VERSION,
		coins = 0,
		sessions = 0,
		incomeLevel = 1,
		rebirths = 0,
		lastSave = os.time(),
		robberies = 0,
		-- A brand new top-level table, which is the free case: `reconcile`'s
		-- generic pass fills it in on every existing save with no migration
		-- branch, nothing to pay out and nothing that can run twice.
		press = press,
		-- A field add rather than a schema bump: the generic fill in
		-- `reconcile` hands every existing save a zero, idempotently.
		piggiesStolen = 0,
		-- A field add rather than a schema bump: the generic fill hands every
		-- existing save a false, so each save is granted the starter once, by
		-- `LassoService` on join, which then sets it true.
		lassoStarter = false,
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
		nemesis = { index = 0, rows = {} },
		defend = { index = 0, count = 0 },
		trophies = { victims = {}, caught = 0, bestSpree = 0, clean = 0, wanted = 0, harvested = 0,
			-- The highest bounty ever on this player's head, for the wanted
			-- poster in their own house. A FIELD ADD rather than a schema bump:
			-- `reconcile` descends one level into `trophies`, so a save written
			-- before this simply gains a zero.
			bestBounty = 0,
			plinths = {}, plinth = "" },
		upgrades = upgrades,
		houses = { owned = { shack = true }, shown = "shack" },
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
		dogs = { owned = {}, equipped = "", name = "",
			kennels = {}, kennel = "" },
		pets = { owned = {}, equipped = "" },
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
		-- Schema 28: the piggy collection. `owned` is duplicate-counted
		-- (three Pearls in three slots pay three times, plan §4), keyed by
		-- `Config.SKINS`. `till` is which owned key is standing on the till
		-- and earning -- ITS OWN FIELD, deliberately not read off
		-- `cosmetics.skin`: the old wardrobe can already hold a rare or
		-- legendary from before this system existed, and this field must
		-- never inherit that. Every save, old or new, gets exactly one
		-- Classic Pink here -- the same free ride `catch`/`dogs` took as a
		-- brand new top-level table, no migration branch needed, because an
		-- old save has no `piggies` key at all for reconcile's generic pass
		-- to leave alone.
		--
		-- `slots` is the SIX LAWN PEDESTALS (`Config.PIGGY_LAWN_SLOTS`) -- a
		-- DENSE array of six tables, one per slot, where an empty table is an
		-- empty slot. Dense and never sparse because a mixed array/dictionary
		-- is exactly what `SetAsync` starts refusing, and grown through
		-- `Config.piggySlots` rather than trusted, so a save written before a
		-- slot existed picks one up without a schema branch. It starts EMPTY on
		-- purpose -- EXCEPT FOR SLOT ONE, and that exception is what keeps this
		-- game from opening with no income at all.
		--
		-- THE TILL STOPPED EARNING ON 2026-09-23 AND A NEW SAVE HAD EXACTLY ONE
		-- PIGGY, ON IT. So a brand-new player earned nothing per second, forever:
		-- the only way a piggy leaves the till is `PiggyHaulService.swap`, which
		-- needs a piggy in your arms to swap IN, and the only piggy they own is
		-- the one standing on the till. A dead end, and `Config.piggyKeyAt`'s own
		-- rule says it is the one state this economy may not have -- it is the
		-- first minute of the game.
		--
		-- SO THE STARTER IS SEATED TWICE AND OWNED TWICE: a Classic on the till to
		-- look at, and a Classic on the first pedestal to earn. `owned` counts
		-- placements rather than a bag (`Config.addPiggy`: placement IS ownership,
		-- there is no bag), so two standing is two owned and `piggystate` reads
		-- clean. What a new player earns per second is UNCHANGED by the till
		-- change -- one common's rate, exactly as before -- and all that moved is
		-- that it ripens on a pedestal instead of dripping into the balance.
		--
		-- AN EXISTING SAVE IS NOT MIGRATED, deliberately. A reconcile that seated
		-- a free Classic whenever the lawn read empty would fire again every time
		-- somebody sold their last piggy, which is a piggy faucet keyed to an
		-- empty lawn -- the "pays out on every join is a money printer" failure
		-- this file already records for `shards`. The admin console's
		-- `fillpiggies` is the way to seat one.
		piggies = {
			owned = { [Config.DEFAULT_SKIN] = 2 },
			till = Config.DEFAULT_SKIN,
			slots = { { key = Config.DEFAULT_SKIN, buffer = 0 }, {}, {}, {}, {}, {} },
		},
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
		settings = { music = true, musicVolume = Config.MUSIC.SLIDER_DEFAULT, hotbar = { order = {}, hidden = {} } },
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

	-- SCHEMA 29: THE ACORN TRACK IS DELETED, NOT CONVERTED.
	--
	-- `loot` was the acorn balance and the only thing a crate ever cost; the
	-- five fields beside it were the tree that filled it. With no crate price
	-- there is nothing to convert a balance INTO, and this file already
	-- records what a payout on join is worth: `shards` took the same call, and
	-- "one that pays on every join is a money printer -- a far worse bug than
	-- the one being fixed". Nothing is refunded; the game is in beta.
	--
	-- BEFORE the generic fill, so the dead fields are consumed rather than
	-- left beside a defaulted new one, and idempotent by construction: a
	-- second run finds nothing to nil out.
	data.loot = nil
	data.tree = nil
	data.treeAcorns = nil
	data.groundAcorns = nil
	data.acornsGrownAt = nil
	data.acornsDroppedAt = nil
	-- The season table ranked acorns earned and nothing else fed it, so it
	-- goes with them. `nemesis` and `defend` are untouched: both count
	-- ROBBERIES and neither has anything to do with the currency.
	data.season = nil
	-- THE CAPACITY TREE IS RETIRED, AND THE RUNGS ARE PRUNED, NOT REFUNDED.
	-- `capacityLevel` was the Bigger Piggy Bank ladder; the pig has no
	-- ceiling now (designer decision 2026-09-21) so the field describes an
	-- upgrade that does not exist -- the Tiptoe rung on disk, in reverse.
	-- Nothing is paid back for the same reason `loot` and `shards` paid
	-- nothing: a payout on every join is a money printer, a far worse bug
	-- than the one being fixed, and the game is in beta. Idempotent: a save
	-- that has been through this has no field to nil out. No schema bump,
	-- because a prune that is idempotent needs no version branch.
	data.capacityLevel = nil
	local previousSchema = tonumber(data.schema) or 0

	-- SCHEMA 30: THE COIN RE-DENOMINATION. Every price in the game was
	-- multiplied by `Config.COIN_REDENOMINATION`, so every coin a save is
	-- holding has to move with them or the save is worth a thousandth of what
	-- it was. See the note over `Config.SCHEMA_VERSION`.
	--
	-- WHAT COUNTS AS A COIN IS THE WHOLE OF THE DECISION, and the list is
	-- short because most of a save is not money: an ownership table, a count,
	-- a key, a timestamp and a level are all unaffected by what a coin is
	-- worth. What IS money is the balance, the two lifetime ledgers, the
	-- week's running total (which the board ranks on), the best bounty a
	-- poster prints, and each pedestal's uncollected buffer.
	--
	-- GUARDED, NEVER IDEMPOTENT BY CONSTRUCTION -- which is the opposite of
	-- every other branch in this function and has to be said out loud. A
	-- prune can run a hundred times and find nothing the second time; a
	-- MULTIPLY cannot tell its own output from its input, so the version
	-- check is the only thing standing between this and a save that gains a
	-- thousandfold on every join. `previousSchema` is read above, before
	-- anything writes to it, and `data.schema` is stamped once at the end.
	if previousSchema > 0 and previousSchema < 30 then
		local factor = Config.COIN_REDENOMINATION
		local function scale(n: any): number
			return (tonumber(n) or 0) * factor
		end
		data.coins = scale(data.coins)
		data.totalStolen = scale(data.totalStolen)
		data.totalLost = scale(data.totalLost)
		if type(data.week) == "table" then
			data.week.stolen = scale(data.week.stolen)
		end
		if type(data.trophies) == "table" then
			data.trophies.bestBounty = scale(data.trophies.bestBounty)
		end
		-- The uncollected pile on each plinth, including slot 0's till. A
		-- buffer left unscaled would collect for a thousandth of what the
		-- pedestal now says it is worth, which reads as the collect prompt
		-- being broken rather than as a stale number.
		if type(data.piggies) == "table" and type(data.piggies.slots) == "table" then
			for _, entry in pairs(data.piggies.slots) do
				if type(entry) == "table" and entry.buffer ~= nil then
					entry.buffer = scale(entry.buffer)
				end
			end
		end
	end

	-- Schema 17: THE PIG IS THE WALLET. `vault` (the stealable pile) and
	-- `coins` (the banked balance) became one field. Idempotent: a save that
	-- has already been through this has no `vault` to add.
	--
	-- The other half of 17 merged `medals` and `tokens` into `loot`, and all
	-- three are dropped above by schema 29 -- so a save old enough to carry
	-- them loses them here rather than being carried into a currency that no
	-- longer exists.
	if type(data.vault) == "number" then
		data.coins = (tonumber(data.coins) or 0) + data.vault
		data.vault = nil
	end
	-- The till's buffer (schema 27) is retired: it drip-fed the balance from
	-- 2026-09-22 and earns nothing at all since 2026-09-23 (the till is a
	-- display). Whatever a save was holding in it is banked once, here, and the
	-- field goes -- ONCE, because a migration that pays out on every join is a
	-- money printer, which is why this is keyed to the field still existing.
	if type(data.tillBuffer) == "number" then
		data.coins = (tonumber(data.coins) or 0) + math.max(0, data.tillBuffer)
		data.tillBuffer = nil
	end
	data.medals = nil
	data.tokens = nil

	-- THE TILL NAMES A PIGGY THE CATALOGUE STILL HOLDS, OR IT NAMES CLASSIC.
	--
	-- `Config.piggyKeyAt` already answers Classic for a retired till at every
	-- READ, so the bank never earned nothing and never stood bare. What that
	-- read-time fallback could not do is keep the BOOKS: `piggies.owned` went
	-- on counting a copy of a key nobody can draw, and the Classic the bank
	-- was actually wearing was counted nowhere -- so `piggystate` reported a
	-- mismatch and a swap would have decremented a Classic that was never
	-- owned. Settled here once, as the swap it effectively is: the retired
	-- copy leaves the count and the Classic that replaces it enters it.
	-- Idempotent -- a second pass finds a valid till and does nothing -- and
	-- a save with no `piggies` table at all is left to the generic fill,
	-- which seats the starter Classic with its count.
	if type(data.piggies) == "table" then
		local piggies = data.piggies
		local till = piggies.till
		if till ~= nil and (type(till) ~= "string" or not Config.SKINS[till]) then
			if type(piggies.owned) == "table" then
				if type(till) == "string" and type(piggies.owned[till]) == "number" then
					local left = piggies.owned[till] - 1
					piggies.owned[till] = if left > 0 then left else nil
				end
				piggies.owned[Config.DEFAULT_SKIN] = (piggies.owned[Config.DEFAULT_SKIN] or 0) + 1
			end
			piggies.till = Config.DEFAULT_SKIN
		end
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
				local item = Config.DECOR_ITEMS[key]
				-- A TROPHY IS CLEARED OFF THE LAWN, AND ITS OWNERSHIP IS NOT
				-- TOUCHED. Trophies moved off the lawn into the house (the
				-- in-house room is retired since; the real base takes them over
				-- later), so a save written before that still has one
				-- standing on the grass and holding a slot a bought ornament
				-- could use. Pruned here rather than migrated, the same call
				-- the retired bins and cars take -- and `decor.owned` above
				-- keeps every earned trophy, which is the one thing
				-- `assets/houses/docs/HOUSE-TROPHY-ROOMS.md` says never to disturb.
				if not realSlot[slot] or not item or item.trophy ~= nil then
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

			-- EVERY PLAYER HAS SCRAPPY, AND THIS IS WHERE THEY GET HIM
			-- (designer, 2026-09-23).
			--
			-- A coat carrying `free = true` is owned by everybody from their
			-- first second: there is no price, no rebirth and no crate in
			-- front of it, so the only honest place for it is the save. The
			-- ALTERNATIVE was a special case in `SetService.owns` -- "owned,
			-- or free" -- and that is the wrong shape by a distance: nine
			-- readers ask that question (the shop push, the equip, the
			-- buy-or-equip, the sell guard, the spare pool, the set panel,
			-- the admin console, `applyToPlot` and the reconcile below), and
			-- every one of them would have had to learn it. Writing it once
			-- here means every reader already answers correctly.
			--
			-- IDEMPOTENT BY CONSTRUCTION, which is the rule this project
			-- holds for every migration: it writes `true` over `true`, so a
			-- save that has been through it has nothing to do and there is no
			-- schema version to remember. Nothing is granted twice because
			-- ownership is a SET rather than a count -- and note that is the
			-- reason a free coat may not be sold: a refund on every join is
			-- exactly the money printer `loot` and `shards` were pruned to
			-- avoid, and a free item selling for a tier value is that with
			-- extra steps. `Config.isSellable` refuses one already (no cost,
			-- no rarity, no earned tag), so the two halves agree.
			--
			-- DERIVED FROM THE CATALOGUE rather than naming a key, the same
			-- call the prune above makes: a second free guardian needs a
			-- field and no code here.
			for key, coat in pairs(Config.DOG_COATS) do
				if coat.free == true then
					data.dogs.owned[key] = true
				end
			end
		end
		-- "" is the breed look and is always legal; anything else has to be a
		-- coat that still exists AND is still owned, or it falls back.
		local worn = data.dogs.equipped
		if type(worn) ~= "string" or (worn ~= "" and not Config.DOG_COATS[worn]) then
			data.dogs.equipped = ""
		end

		-- THE NAME, AGAINST THE LIST -- and this one is a SAFETY prune rather
		-- than a tidy-up like the rest of them.
		--
		-- Naming was free text put through the platform filter until the list
		-- replaced it, so saves written before that carry whatever a player
		-- typed. The filter does not run in Studio at all (measured), so a
		-- dev-built save can hold anything, and a live one holds whatever the
		-- classifier let through. Either way it is text nobody approved
		-- standing over a kennel, so it goes: an unknown name falls back to
		-- the breed, exactly as an unknown coat does.
		local named = data.dogs.name
		if type(named) ~= "string" or named ~= "" then
			local ok = false
			for _, candidate in ipairs(Config.DOG_NAMES) do
				if candidate == named then
					ok = true
					break
				end
			end
			if not ok then
				data.dogs.name = ""
			end
		end
		-- The rate limit went with the filter call it bounded.
		data.dogs.namedAt = nil

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

		-- Dog toys (ball, water bowl, bed) were removed from the game during
		-- the beta; whatever a save still holds of them is dropped, with no
		-- refund.
		(data.dogs :: any).toys = nil
	end

	-- Pets against their catalogue: a retired pet left `equipped` would be
	-- published as an attribute every client then fails to build.
	if type(data.pets) == "table" then
		if type(data.pets.owned) == "table" then
			for key in pairs(data.pets.owned) do
				if not Config.PETS[key] then
					data.pets.owned[key] = nil
				end
			end
		end
		local out = data.pets.equipped
		if type(out) ~= "string" or (out ~= "" and not Config.PETS[out]) then
			data.pets.equipped = ""
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
	-- real: those tables have unrelated names in the save (`owned`,
	-- `kennels`) and unrelated shapes, where these are three
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
		-- The nemesis and defend tables need their one-deeper shape. The
		-- season table went with the acorn ladder that ranked it.
		for _, key in ipairs({ "nemesis", "defend" }) do
			if type(data[key]) ~= "table" then
				data[key] = base[key]
			end
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
	-- Same normalisation as `robberies`, for the same reason: a counter the
	-- leaderboard sorts on may not be a NaN, a fraction or a negative.
	local piggiesStolen = data.piggiesStolen
	if type(piggiesStolen) ~= "number" or piggiesStolen ~= piggiesStolen or math.abs(piggiesStolen) == math.huge then
		data.piggiesStolen = 0
	else
		data.piggiesStolen = math.max(0, math.floor(piggiesStolen))
	end
	if type(data.claims) ~= "table" then data.claims = {} end
	-- The receipt ledger and the doorstep queue are created lazily by
	-- `ProductService` and `DailyService`; normalised here for the reason
	-- `claims` is, so a hand-edited or truncated save cannot crash a receipt.
	if type(data.receipts) ~= "table" then data.receipts = {} end
	if type(data.daily) == "table" and type(data.daily.crates) ~= "table" then
		data.daily.crates = {}
	end
	Config.pruneBuybackClaims(data.claims)
	data.sinceLegendary = nil
	data.schema = Config.SCHEMA_VERSION
	return data
end

local function lockIsStale(lock: any): boolean
	if type(lock) ~= "table" or type(lock.timestamp) ~= "number" then
		return true
	end
	-- A LOCK LEFT BY ANOTHER STUDIO SESSION IS STALE AT ONCE. `JOB_ID` is
	-- minted per Play session here ("studio-" plus the clock), and Studio
	-- gives `BindToClose` too little time to release, so the lock from the
	-- session you just stopped is usually still on the key when you press
	-- Play again -- held by a job that no longer exists, and honoured for
	-- up to `LOCK_STALE_SECONDS`. `load` then retried behind it, two seconds
	-- a go, which was most of the "spawns mid-map, then teleports home a few
	-- seconds later" the designer reported (2026-09-23). One Studio session
	-- runs on one machine at a time; a second one on the same account is a
	-- deliberate act, and the live rule still holds for every real server.
	if RunService:IsStudio() and type(lock.jobId) == "string" and lock.jobId:sub(1, 7) == "studio-" then
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
