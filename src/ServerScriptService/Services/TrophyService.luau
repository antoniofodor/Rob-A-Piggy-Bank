--!strict
--[[
	TrophyService

	The yard's trophy shelf: what has been earned, what it looks like, and
	the one place a trophy is ever handed over.

	MONEY BUYS THE FRAME; ROBBERY BUYS THE PICTURE. `Config.TROPHY_PLINTHS`
	is the only part of a shelf a coin can reach -- it repaints a base and
	adds a plaque and an uplight. Everything standing on one is a record of
	something the player DID: a pig for every skin robbed, a bar for every
	doubling of the lifetime haul, a rosette for every thief stopped on the
	lawn, a lamp for every most-wanted patrol outrun.

	A TROPHY IS A DECOR ITEM, WHICH IS WHY THIS FILE IS SHORT.

	The four live in `Config.DECOR_ITEMS` carrying a `trophy` field and no
	`cost`, so ownership, placement, the auto-slot, the put-away toggle, the
	rebuild on a plot and the shop card are all `data.decor` doing exactly
	what it already did. Earning one is `decor.owned[key] = true` and a call
	to the placement the shop already uses. The alternative was a parallel
	`data.trophies.placed` with a slot grid of its own, which is nine
	accessors with a decor-shaped hole under every one of them -- the same
	trade the shops refused when they became plots rather than a third
	kind of `Target`.

	IT ALSO MAKES THE SLOTS SCARCE FOR FREE. There are nine lawn slots,
	eighteen ornaments and four trophies, so putting up what you have DONE
	costs a slot you were using for what you BOUGHT. `docs/MASTER-PLAN.md` asks
	for exactly that and says why: choosing is the whole of what makes a
	shelf mean anything, and that argument does not survive giving trophies a
	grid of their own.

	THREE OF THE FOUR NUMBERS ALREADY EXISTED AND WERE ON NO SCREEN.
	`data.totalStolen` has been written on every delivery since the heist
	system shipped and `data.gear.escapes` since the most-wanted gear did.
	Neither has ever been displayed anywhere in the game. So two thirds of
	this feature is a readout for arithmetic the game was already doing,
	which is the cheapest content this design has.

	THE ONE THAT HAD TO BE INVENTED IS THE DEFENDER'S. There was no count of
	thieves stopped anywhere: `data.totalLost` tracks the INVERSE -- coins
	somebody took off you -- so a defence trophy built on it would have been
	a prize for being robbed.

	REQUIRES DataService AND PlotService, AND NOTHING ELSE.

	The shop has to repaint when a trophy lands, and `CosmeticsService`
	requires this file for the progress it puts on a locked card -- so
	requiring it back is a cycle. The push is a REGISTRY that `Main` fills
	in, which is the shape `SetService.registerPusher` already uses and for
	the same reason.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local TrophyService = {}

-- Filled by Main with CosmeticsService.push. A missing pusher still awards
-- correctly; the shop just does not repaint until the next push of its own,
-- which is a display lag rather than a lost trophy.
local pushers: { (Player) -> () } = {}

function TrophyService.registerPusher(fn: (Player) -> ())
	table.insert(pushers, fn)
end

local function notify(player: Player, message: string, kind: string)
	Remotes.get("Notify"):FireClient(player, message, kind)
end

local function pushAll(player: Player)
	for _, fn in ipairs(pushers) do
		fn(player)
	end
end

-- Belt and braces against a save that somehow missed reconcile. A nil here
-- would otherwise throw inside a delivery or a nab -- both of which run in
-- the middle of somebody's robbery -- and this is a shelf.
local function shelf(data: any)
	if type(data.trophies) ~= "table" then
		data.trophies = { victims = {}, caught = 0, bestSpree = 0,
			plinths = {}, plinth = "" }
	end
	local t = data.trophies
	if type(t.victims) ~= "table" then
		t.victims = {}
	end
	if type(t.plinths) ~= "table" then
		t.plinths = {}
	end
	t.caught = tonumber(t.caught) or 0
	t.bestSpree = tonumber(t.bestSpree) or 0
	-- Phase 5.2 counters. `reconcile` fills them one level down; this is the
	-- belt to its braces.
	t.clean = tonumber(t.clean) or 0
	t.wanted = tonumber(t.wanted) or 0
	t.harvested = tonumber(t.harvested) or 0
	if type(t.plinth) ~= "string" then
		t.plinth = ""
	end
	return t
end

-- ============================================================
-- WHAT EACH TROPHY IS MEASURED AGAINST
-- ============================================================
--
-- ONE FUNCTION, FOUR NUMBERS, AND EVERY READER GOES THROUGH IT.
--
-- The earn check, the shop card's progress bar and the geometry all ask the
-- same question, and this is the only place that answers it. Two of these
-- live outside `data.trophies` -- `totalStolen` at the top level and
-- `escapes` inside `data.gear` -- so a second reader written against the
-- save directly would be a second opinion about how much somebody has
-- stolen. `Config.TROPHIES` names the key; this produces it.
function TrophyService.counts(data: any): { [string]: number }
	local t = shelf(data)
	local seen = 0
	for _ in pairs(t.victims) do
		seen += 1
	end
	local gear = data.gear
	local season = data.season
	return {
		victims = seen,
		stolen = tonumber(data.totalStolen) or 0,
		caught = t.caught,
		escapes = (gear and tonumber(gear.escapes)) or 0,
		bestSpree = t.bestSpree,
		rank = Config.getRapSheetRank(tonumber(data.robberies) or 0),
		clean = t.clean,
		seasonBest = (type(season) == "table" and tonumber(season.best)) or 0,
		wanted = t.wanted,
		harvested = t.harvested,
	}
end

-- Everything `Decor`'s four trophy builders read, and nothing else.
--
-- The victim list is handed over as an ARRAY of skin keys rather than as the
-- save's own set, because the shelf sorts it -- rarest first -- and a builder
-- that walked a `pairs` table would stand a different nine pigs on every
-- rebuild, in a different order, for no reason a player could name.
function TrophyService.state(data: any): any
	local t = shelf(data)
	local counts = TrophyService.counts(data)

	local victims: { string } = {}
	for key in pairs(t.victims) do
		if Config.SKINS[key] then
			table.insert(victims, key)
		end
	end
	table.sort(victims)

	local total = 0
	for _ in pairs(Config.SKINS) do
		total += 1
	end

	-- WHAT IS OWNED, NOT ONLY WHAT THE COUNTERS SAY.
	--
	-- The trophy room derives "earned" from a grade, which is right for a
	-- normal save and wrong for two real ones: an admin grant hands over a
	-- trophy without moving its counter, and the Victim Shelf's own counter is
	-- a set of skins that a prune can shrink. Measured on the dev save --
	-- `decor.owned.victimshelf` true against `victims` of 0 -- which put a
	-- PROGRESS PLAQUE on the wall for a trophy the shop was calling owned.
	--
	-- So ownership travels with the numbers and the room prefers it. The grade
	-- still comes from the counters, because that is what a trophy's own model
	-- reads to draw itself.
	local owned: { [string]: boolean } = {}
	local held = if type(data.decor) == "table" and type(data.decor.owned) == "table"
		then data.decor.owned
		else {}
	for key in pairs(Config.TROPHIES) do
		if held[key] then
			owned[key] = true
		end
	end

	return {
		victims = victims,
		skinTotal = total,
		owned = owned,
		stolen = counts.stolen,
		caught = counts.caught,
		escapes = counts.escapes,
		bestSpree = counts.bestSpree,
		rank = counts.rank,
		clean = counts.clean,
		seasonBest = counts.seasonBest,
		wanted = counts.wanted,
		-- The figure the house's wanted poster prints. Session heat cannot
		-- supply it -- see `recordWanted`.
		bestBounty = tonumber(shelf(data).bestBounty) or 0,
		harvested = counts.harvested,
		plinth = t.plinth,
	}
end

-- Repaint this player's own lawn.
--
-- Held ON THE PLOT rather than passed to `setDecor`, because that function
-- has five callers across three services and a fifth positional argument
-- would be five chances to leave it out -- and a missing one reads as nil,
-- which is an EMPTY shelf, silently, on a lawn nobody would think to check.
-- That is the `signWord` decision made a second time, for the same reason.
function TrophyService.refresh(player: Player)
	local data = DataService.get(player)
	local plot = PlotService.getPlot(player)
	if not data or not plot then
		return
	end
	PlotService.setTrophyState(plot, TrophyService.state(data))
end

-- ============================================================
-- EARNING
-- ============================================================

-- Hands over anything newly earned, and says so.
--
-- CALLED AFTER EVERY EVENT THAT COULD MOVE A NUMBER rather than at the point
-- each number is written, which is what keeps the four thresholds in one
-- place. `data.gear.escapes` is bumped by CosmeticsService and
-- `data.totalStolen` by HeistService; neither should have to know that a
-- shelf exists.
--
-- A TROPHY IS AUTO-PLACED IF THERE IS ROOM AND OWNED EITHER WAY, and the
-- order matters. Refusing to award one because the lawn is full would mean
-- the game quietly declining to hand over something already earned -- so it
-- is granted, and the toast says where it went or why it did not.
function TrophyService.check(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end

	local counts = TrophyService.counts(data)
	local decor = data.decor
	if type(decor) ~= "table" then
		return
	end

	local earned = false

	-- Walked in catalogue ORDER rather than by `pairs`, so a session that
	-- crosses two thresholds at once announces them in the same order every
	-- time -- the same call `recordWantedEscape` makes over `GEAR_ORDER`.
	local keys: { string } = {}
	for key in pairs(Config.TROPHIES) do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		local ia = Config.DECOR_ITEMS[a]
		local ib = Config.DECOR_ITEMS[b]
		return (ia and ia.order or 0) < (ib and ib.order or 0)
	end)

	for _, key in ipairs(keys) do
		local spec = Config.TROPHIES[key]
		local item = Config.DECOR_ITEMS[key]
		local have = counts[spec.count] or 0
		if item and not decor.owned[key] and have >= spec.need then
			decor.owned[key] = true
			earned = true
			-- A TROPHY GOES IN THE HOUSE NOW, NOT ON THE LAWN.
			--
			-- This used to claim a `Config.DECOR_SLOTS` lawn slot and stand
			-- the trophy on the grass, competing with the bought ornaments --
			-- and it had to say so out loud when the lawn was full. The
			-- trophy room (`TrophyRoom`) displays every earned trophy inside
			-- the house off the same published state, so there is no slot to
			-- claim, nothing to put away to make room, and no full-lawn case
			-- to explain. `assets/houses/docs/HOUSE-TROPHY-ROOMS.md` asks for the lawn
			-- writes to be retired ONLY once the interior ships, and to never
			-- touch earned ownership: `decor.owned` above is untouched.
			notify(player, ("EARNED: %s. It is on show in your house."):format(item.name),
				"loot")
		end
	end

	if not earned then
		return
	end

	-- `refresh` republishes the trophy state, which repaints the lawn's
	-- ornaments AND refills the house's trophy room -- so nothing here needs
	-- to rebuild the lawn itself any more.
	TrophyService.refresh(player)
	DataService.save(player)
	pushAll(player)
end

-- ============================================================
-- THE FOUR EVENTS
-- ============================================================

-- A ROBBERY LANDED, IN THAT VICTIM'S SKIN.
--
-- ON THE DELIVERY, NEVER ON THE GRAB. Everything else this game counts about
-- a robbery -- `totalStolen`, the rap sheet, the weekly board, the spree --
-- is counted when the coins reach home, because loot nabbed out of your
-- hands or confiscated by a patrol was never stolen: you were caught. A
-- shelf that filled on the grab would let a thief collect all 46 skins by
-- cracking pigs and never once getting away with anything.
function TrophyService.recordVictim(thief: Player, skinKey: string?)
	if not skinKey or not Config.SKINS[skinKey] then
		return
	end
	local data = DataService.get(thief)
	if not data then
		return
	end
	local t = shelf(data)
	if t.victims[skinKey] then
		-- Already on the shelf. Nothing to award and nothing to repaint --
		-- which is the common case by a distance once a street has been
		-- worked through, so it returns before touching a plot.
		return
	end
	t.victims[skinKey] = true
	TrophyService.check(thief)
	-- AFTER the check, and it has to be. `check` only repaints when
	-- something was newly EARNED, and the tenth skin on a shelf that already
	-- exists earns nothing -- so without this the case would stop gaining
	-- pigs the moment it was unlocked.
	TrophyService.refresh(thief)
	pushAll(thief)
end

-- A THIEF WAS STOPPED ON THIS PLAYER'S LAWN.
--
-- Counted for a player's NAB and for their DOG'S catch, and deliberately not
-- for an arrest. The patrol belongs to nobody -- that is the whole point of
-- it, and it is why it can never be aimed -- so crediting a plot owner for a
-- car the street sent would be the first time anything in this game claimed
-- the police as a defence upgrade.
function TrophyService.recordCatch(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local t = shelf(data)
	t.caught += 1
	TrophyService.check(player)
	TrophyService.refresh(player)
	pushAll(player)
end

-- The longest run of deliveries this account has ever put together.
--
-- Kept because `Config.SPREE` deliberately does not: a run decays when you
-- stop and is spent by being arrested, which is right for a live multiplier
-- and means the best thing a player ever did evaporates the moment they do
-- anything else. Nothing reads this yet -- it is here because the schema
-- change is free TODAY and costs a real payout the day a trophy is built on
-- it, which is the window `docs/MASTER-PLAN.md` says is the only free one.
function TrophyService.recordSpree(player: Player, run: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	local t = shelf(data)
	if run > t.bestSpree then
		t.bestSpree = run
		-- Hot Streak (5.2) reads this now, so a new best can earn or regrade.
		TrophyService.check(player)
		TrophyService.refresh(player)
	end
end

-- PHASE 5.2 COUNTERS. Each bumps one number and re-asks the shelf, the
-- `recordCatch` shape. All three are counted where the thing is COMPLETE:
-- a clean crack when its haul gets home, a harvest when it is deposited,
-- Most Wanted when the board changes hands to this player.
local function bump(player: Player, field: string, amount: number)
	local data = DataService.get(player)
	if not data or amount <= 0 then
		return
	end
	local t = shelf(data)
	t[field] += amount
	TrophyService.check(player)
	TrophyService.refresh(player)
	pushAll(player)
end

function TrophyService.recordClean(player: Player)
	bump(player, "clean", 1)
end

--[[
	Top of the Most Wanted board, and the BOUNTY that put them there.

	THE POSTER IN THE HOUSE NEEDS A FIGURE THAT OUTLIVES THE SESSION. The
	street's own board prints the LIVE bounty -- `heat` times
	`POLICE.bailMultiple` -- and heat is per session, held in memory and
	dropped when a player leaves. So a poster hung in a house from that number
	would read zero for everybody who was ever wanted, which is the one state
	it must not have.

	`bestBounty` is therefore kept on the save and only ever RISES. It is the
	caller's figure rather than one computed here, for the reason the board's
	own comment gives: two surfaces must not disagree about a bounty any more
	than about who is wanted, so there is one piece of arithmetic and it lives
	where `heat` does.
]]
function TrophyService.recordWanted(player: Player, bounty: number?)
	local data = DataService.get(player)
	if data then
		local t = shelf(data)
		local best = math.max(tonumber(t.bestBounty) or 0, math.floor(tonumber(bounty) or 0))
		t.bestBounty = best
	end
	bump(player, "wanted", 1)
end

function TrophyService.recordHarvest(player: Player, amount: number)
	bump(player, "harvested", math.floor(amount))
end

-- The robbery count and the season's best tier live elsewhere in the save;
-- their writers call this so Old Hand and the Season Cup can land.
function TrophyService.recheck(player: Player)
	TrophyService.check(player)
	TrophyService.refresh(player)
end

-- ============================================================
-- THE FRAME
-- ============================================================

-- Stand a plinth already owned, or put the plain concrete back by asking
-- twice. The kennel's twin, and a separate function for the same reason:
-- two catalogues that happen to share a shape today are not one catalogue.
function TrophyService.equipPlinth(player: Player, key: string)
	local data = DataService.get(player)
	local spec = Config.TROPHY_PLINTHS[key]
	if not data or not spec then
		return
	end
	local t = shelf(data)
	if not t.plinths[key] then
		notify(player, ("%s isn't unlocked yet."):format(spec.name), "warn")
		return
	end

	t.plinth = if t.plinth == key then "" else key
	TrophyService.refresh(player)
	DataService.save(player)
	pushAll(player)
end

-- Buy a plinth, or stand one already owned. Buy-or-equip on one control, the
-- same shape a skin, a coat and a kennel all use, so the card never has to
-- decide which verb it is.
--
-- A PLINTH CONFERS NOTHING, which is the line that lets it be sold for coins
-- at all. It repaints a base and adds a label; the trophy standing on it is
-- the same trophy, and no amount of money spent here changes one thing a
-- thief reads off the lawn.
function TrophyService.buyPlinth(player: Player, key: string)
	local data = DataService.get(player)
	local spec = Config.TROPHY_PLINTHS[key]
	if not data or not spec then
		return
	end
	local t = shelf(data)

	if t.plinths[key] then
		TrophyService.equipPlinth(player, key)
		return
	end

	local cost = spec.cost or 0
	if data.coins < cost then
		notify(player, ("Need %s more coins for %s."):format(
			Config.formatCoins(cost - data.coins), spec.name), "warn")
		return
	end

	data.coins -= cost
	t.plinths[key] = true
	notify(player, ("Unlocked %s!"):format(spec.name), "good")

	TrophyService.equipPlinth(player, key)
end

return TrophyService
