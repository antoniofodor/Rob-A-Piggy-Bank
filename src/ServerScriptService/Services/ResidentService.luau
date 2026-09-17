--!strict
--[[
	ResidentService -- the neighbours who are always in.

	Every plot with no player on it gets a RESIDENT: a name on the sign, a
	piggy bank that fills, and defences that grow with the street. They exist
	for one reason, and it is the supply side of the core game loop.

	WHY THIS EXISTS. `HeistService.attemptSteal` requires a `victim: Player`,
	and `PlotService.release` strips an abandoned plot back to a bare slab
	with an empty pig. So on a three-player server five of the eight houses
	are dead frontages -- the street reads as abandoned AND there is nothing
	to rob. In a game called Rob a Piggy Bank, whether the core action is
	available at all depended on how many other children happened to be
	online.

	WHAT A RESIDENT IS NOT. It is a resource, never a rival: no revenge
	marker, no rap sheet, no place on the Richest Piggies or Most Wanted
	boards, and no `Config.LOSS_CAP`. That cap exists so a real child cannot
	be emptied by seven people taking turns; there is nobody behind a
	resident, so there is nothing to protect -- which is precisely what lets
	robbing become the primary income in this game WITHOUT being robbed
	getting any worse for a real player. The uncapped supply is the whole
	point.

	A RESIDENT IS A PEER, NOT A SECOND ECONOMY. Its income and capacity come
	from `Config.getIncome` and `Config.getCapacity` at a level derived from
	the humans in the server, so an NPC pig is worth robbing at minute one
	and still worth robbing at rebirth ten, with no parallel ladder to tune
	and nothing that can quietly drift away from the real one.

	THERE IS SOMEBODY STANDING ON THE LAWN, AND THEY PLAY THE GAME. Each
	resident gets a figure built from the drip statue's own geometry (see
	Shared/ResidentModel), scaled to human height, recoloured per plot and
	stripped of its plinth. Eight houses with seven of them visibly empty was
	the other half of the problem residents were built for -- the coins half
	was fixed and the picture was not.

	THEY WALK, THEY CARRY A NAME OVER THEIR HEAD, AND THEY GO OUT ROBBING.
	The walk is posed exactly as the patrol officer's is -- a stride driven by
	DISTANCE TRAVELLED rather than by a clock, so a neighbour standing still
	has their legs together by construction and the animation cannot desync
	from the movement, because it IS the movement.

	AND THAT ANSWERS THE QUESTION THIS HEADER USED TO LEAVE OPEN. It listed
	three ways to resolve "the dog treats this plot as empty while somebody is
	visibly standing in the garden", and said to decide it when the dog was
	wired. The dog is wired, and this is the third of them: the figure moves,
	so HOME IS A THING YOU CAN WATCH FOR. A neighbour on their own lawn is in;
	a neighbour walking up somebody else's drive is out, with their own pig
	behind them and nobody on it. Nothing has to be explained, and it is the
	same kind of tell the dog's own posture already carries.

	WHY THEY ROB PLAYERS AND NOT ONLY EACH OTHER. Residents exist because a
	quiet server had NOTHING TO ROB. The mirror of that is a quiet server with
	NOBODY TO DEFEND AGAINST, and it is just as real: every rung of the
	defence tree -- the Vault Lock, the Fence, the Guard Dog, the Guard Duty
	Treat, the Sprinkler -- protects against other players, so in a solo
	session half the shop is inert and a child who spends an afternoon buying
	a Mastiff has bought something that will never once be used.

	WHAT KEEPS THAT SAFE, and it is three things that already existed rather
	than three new ones. `Config.LOSS_CAP` still applies, because it is keyed
	to the VICTIM and does not care who the thief is. A plot is RELEASED the
	moment its owner leaves, so this can only happen while the player is there
	to answer it. And the loot is TAGGABLE, on the same prompt a player thief
	carries -- which is why a neighbour walks at 9 and carries at 7 against a
	player's 16, so they can ALWAYS be run down. The coins are recoverable by
	doing the thing, every time, with no purchase involved.

	IT IS STILL A RESOURCE RATHER THAN A RIVAL where that matters: no revenge
	marker, no rap sheet, no place on either board, and it still has no
	`LOSS_CAP` of its own as a victim. What changed is that it now takes part
	in the loop rather than only supplying it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Services = ServerScriptService:WaitForChild("Services")
local DataService = require(Services.DataService)
local PlotService = require(Services.PlotService)
local ResidentAcorns = require(Services.ResidentAcorns)
local PiggyModel = require(ReplicatedStorage.Shared.PiggyModel)
local ResidentModel = require(ReplicatedStorage.Shared.ResidentModel)

export type Resident = {
	plot: PlotService.Plot,
	acornStock: ResidentAcorns.Stock?,
	-- WHO THIS SHOPKEEPER IS AFTER, and until when. Only ever set on a
	-- resident seated on a shop plot -- see `Config.SHOPKEEPER`. A house
	-- resident is never given these because a house has a dog, and two
	-- things that can both hard-stop one thief on one lawn is how a plot
	-- becomes a wall.
	chasing: Player?,
	chaseUntil: number?,
	chaseFrom: number?,
	-- WHERE THEY STAND WHEN THEY ARE MINDING THE SHOP. Captured once at
	-- `seat` and never recomputed, so a shopkeeper who has chased somebody
	-- into the street has somewhere exact to walk back to. Without it
	-- `goHome` marks them home wherever they happen to be standing -- which
	-- is a shopkeeper permanently in the middle of their own shop floor,
	-- measured at 4.11 studs off the counter and staying there.
	seat: Vector3?,
	name: string,
	coins: number,
	-- Its own copy of the two economy levels, so `Config.getIncome` and
	-- `Config.getCapacity` can be asked exactly as they are for a player.
	incomeLevel: number,
	capacityLevel: number,
	-- HOW FAR BELOW THE STREET THIS ONE SITS, rolled once when it is seated
	-- and kept for as long as it stands. Re-rolling on the tick would
	-- reshuffle the whole street every time anybody levelled up, and a house
	-- that changes its fence, dog and building for no reason a player can see
	-- is worse than a street with no variety at all.
	offset: number,
	-- WHICH PIGGY SKIN THIS NEIGHBOUR WEARS, drawn once when they are
	-- seated and kept for as long as they stand. See `drawSkin` for why a
	-- resident wears one at all -- the short version is that the Victim
	-- Shelf collects skins ROBBED, and a street of identical default pigs
	-- would make it a two-player feature on a game whose whole resident
	-- system exists to stop those.
	skin: string,
	-- The ordered list of ornaments this garden would hold if it were full.
	-- Taken as a PREFIX, so a resident that climbs with the street ADDS to its
	-- garden rather than being handed a different one.
	garden: { string },
	-- The neighbour standing on the lawn. Optional because the figure is
	-- decoration: if it fails to build the plot still works exactly as it
	-- did, which is the right way round for something with no behaviour.
	model: Model?,
	-- The limbs, captured once at build. Nil for a resident whose figure did
	-- not build, which is exactly the resident that must not be walked.
	rig: ResidentModel.Rig?,

	-- WHERE THEY ARE AND WHAT THEY ARE DOING.
	--
	-- `state` is one of:
	--   "home"     standing on their own lawn, waiting for `nextTrip`
	--   "out"      walking to somebody else's piggy bank
	--   "cracking" standing at it, taking their time
	--   "carrying" walking home with the loot
	--
	-- There is deliberately no "returning empty" state: a trip that comes
	-- back with nothing walks the identical route carrying zero, so the one
	-- thing a player can read off a neighbour in the street -- are they
	-- holding anything -- is the loot model and never the walk.
	state: string,
	-- The feet, in world space. The figure is driven from the ground rather
	-- than from its pivot, the same convention `PoliceModel` uses, because a
	-- pivot is an accident of which part was built first.
	at: Vector3,
	facing: Vector3,
	-- HOW FAR THEY HAVE WALKED, which is what drives the legs. Never a clock.
	stride: number,
	route: { Vector3 },
	-- The plot index they are working, so a victim who moves house or logs
	-- off cannot leave a dangling reference to a plot table.
	markIndex: number?,
	loot: number,
	lootModel: Model?,
	-- os.clock() stamps.
	nextTrip: number,
	waitUntil: number,
	-- When this neighbour may next say something, and when the line they are
	-- saying now comes down. `quietAt` is 0 when nothing is up, which is what
	-- makes taking a line down a single comparison in every state rather than
	-- a flag that has to be cleared on four different exits.
	nextLine: number,
	quietAt: number,
}

local ResidentService = {}

-- Keyed by plot INDEX rather than by the plot table, so a resident survives
-- anything that rebuilds the plot model underneath it.
local residents: { [number]: Resident } = {}

-- ============================================================
-- LEVEL
-- ============================================================

-- What level a resident should be right now.
--
-- THE AVERAGE OF THE HUMANS IN THE SERVER, and the choice of average over
-- maximum is deliberate. Pinning residents to the best player would make
-- every empty house as rich as the richest human on the street -- which
-- hands a beginner a target they cannot fail to profit from, and hands the
-- best player a row of piggy banks worth more than any real person's. The
-- average keeps a resident a PEER: worth crossing the road for, never the
-- obviously correct target.
--
-- An empty server (everybody still loading) answers 0, which is the level a
-- brand new player meets, and is the case the thirty-second storyboard is
-- written against.
local function currentLevel(): number
	local total, count = 0, 0
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService.get(player)
		if data then
			total += data.incomeLevel
			count += 1
		end
	end
	if count == 0 then
		return Config.RESIDENTS.minLevel
	end
	return math.max(Config.RESIDENTS.minLevel,
		math.floor(total / count) + Config.RESIDENTS.levelOffset)
end

-- WHERE THIS RESIDENT SITS RELATIVE TO THE STREET, as a NEGATIVE offset.
--
-- Downward only, and `RESIDENTS.levelSpread` carries the measurement that
-- forced it: a resident one level ABOVE the thief is worth `INCOME_GROWTH`
-- times more, which takes a maxed spree from 8.25x idling to 11.14x and
-- straight through `auditRobbery`'s ceiling. The peer-level house is the top
-- of the street, never a rung in the middle of it.
--
-- THE EASY FLOOR IS CHECKED AGAINST WHAT IS ACTUALLY STANDING, not dealt from
-- a shuffled bag, because residents are seated ONE AT A TIME as plots free up
-- rather than all at once -- so there is no single moment at which "how many
-- are there" has an answer. Counting the ones already out is the version that
-- cannot drift out of step with the street it is describing.
local function pickOffset(): number
	local spread = math.max(0, math.floor(Config.RESIDENTS.levelSpread))
	if spread == 0 then
		return 0
	end

	local easy, top = 0, 0
	for _, other in pairs(residents) do
		if other.offset <= -spread then
			easy += 1
		end
		if other.offset >= 0 then
			top += 1
		end
	end

	-- The bottom of the ladder first, because that is the guarantee a player
	-- with base stats depends on.
	if easy < Config.RESIDENTS.easyCount then
		return -spread
	end

	-- THEN THE TOP, because a ladder with no top is not a ladder. Measured on
	-- the first build, which drew the rest purely at random: a third of
	-- streets had NO house at the street's own level, since the odds of never
	-- rolling zero across five draws are (spread/(spread+1))^5. The
	-- best-paying, best-defended plot -- the one the whole risk/reward
	-- decision is measured against -- was simply absent, and nothing on
	-- screen could have said so.
	--
	-- It is also the case `auditRobbery` measures, so guaranteeing it means
	-- the street the audit describes is the street that exists.
	if top < 1 then
		return 0
	end

	return -math.random(0, spread)
end

-- The ornaments this garden would hold if it were full, in a fixed order.
--
-- Every lawn item is a candidate: a resident is not shopping, so there is no
-- price to respect and no catalogue order to honour -- and drawing from the
-- same table players buy from is what stops a second list of "ornaments an
-- NPC may have" existing to drift from the first.
local function rollGarden(): { string }
	local keys = {}
	for key, item in pairs(Config.DECOR_ITEMS) do
		if type(item) == "table" and item.zone == "lawn" then
			table.insert(keys, key)
		end
	end
	-- Sorted before shuffling, because `pairs` over a hash is not ordered and
	-- an unsorted seed makes a shuffle unreproducible between runs for no
	-- reason. Fisher-Yates after that.
	table.sort(keys)
	for i = #keys, 2, -1 do
		local j = math.random(i)
		keys[i], keys[j] = keys[j], keys[i]
	end
	return keys
end

-- HOW BIG A RESIDENT'S PIG IS: a fixed number of SECONDS of its own income,
-- never a share of `Config.getCapacity`.
--
-- Capacity is a storage limit that exists because a full pig stops earning
-- and that is what makes a player spend. A resident never spends, so
-- capacity is a concept that does not apply to one -- and borrowing it made
-- a resident's worth ride the capacity curve (1.40 a level) while a player's
-- income rode the income curve (1.35), so robbing drifted from 3.7x the
-- return of idling at level 1 to 12.3x at level 40. See
-- `Config.RESIDENTS.pigSeconds`.
--
-- ONE function, because the fill visual, the accrual ceiling, the seed and
-- the top-up all have to agree about this number, and four copies of it is
-- four chances to disagree.
-- A RESIDENT'S PIG IS MEASURED IN SECONDS OF ITS OWN INCOME, never in
-- capacity -- see `RESIDENTS.pigSeconds` for why borrowing capacity was a
-- category error rather than a tuning miss.
--
-- A SHOP VAULT HOLDS FEWER OF THOSE SECONDS THAN A HOUSE, and that is what
-- pays for where it stands. The vault is on the back wall of a unit whose
-- back faces the houses, so it is about 23 studs from the nearest drop-off
-- against 53 between two houses -- and a haul is a share of the pig against
-- a cycle dominated by that trip.
--
-- Scaling the pig by the cycle ratio would keep coins-per-second LEVEL
-- between the two targets; `SHOP_VAULT_DISCOUNT` then takes it deliberately
-- below, because a shop has no dog to get past either. So a thief chooses a
-- shop for the SHAPE of the robbery -- quick, nothing in the way, loud --
-- and pays for that in coins. `auditRobbery` measures the result at the
-- floor and refuses a discount that makes the supply floor fictional.
local function pigSize(level: number, plot: PlotService.Plot?): number
	local seconds = if plot and plot.shop
		then Config.shopVaultPigSeconds()
		else Config.RESIDENTS.pigSeconds
	return seconds * Config.getIncomeRate(level, 0)
end

-- WHERE A NEIGHBOUR STANDS, in plot-local studs.
--
-- Behind the piggy and in front of the house. The piggy holds the centre at
-- 0, the house front line is at -28, and the walk from the gate takes the
-- whole middle of the plot in FRONT of the piggy -- plot-local +Z is the
-- street on both rows -- so -20 is out of everybody's way. Offset sideways
-- so they are not standing dead in front of their own front door.
local STAND_AT = Vector3.new(12, 0, -20)

-- WHERE A SHOPKEEPER STANDS: BEHIND THE COUNTER, which is the whole reason
-- there is a counter.
--
-- `STAND_AT` is written for a 64-stud lawn and would put them 20 studs back
-- through the shop's own rear wall. This is the far side of the counter
-- `ShopFront` builds, which is the opposite side of the room from the vault
-- -- so a thief walking in has a person to walk PAST rather than a person in
-- the way, and the shopkeeper is the thing that makes the unit read as
-- occupied.
--
-- IT IS `Config.SHOP_ROOM` NOW RATHER THAN A PAIR OF NUMBERS HERE, AND THE
-- COMMENT IT REPLACES IS WHY. That one said this "can be read off the
-- counter's own placement rather than converted" -- true, and a description
-- of a thing somebody has to do again by hand every time the counter moves.
-- It moved: the pocket behind it was 2.68 studs and is 3.00, and a shipped
-- (-4.5, 0, -3.2) would now be standing 0.1 studs inside the counter it is
-- documented as being behind. The z is DERIVED over there from the pocket's
-- own two edges, so it is the middle of the pocket by construction rather
-- than by anybody remembering.
local SHOP_STAND_AT = Vector3.new(
	Config.SHOP_ROOM.keeperX, 0, Config.SHOP_ROOM.keeperZ)

-- WHICH OF THE TWO A PLOT WANTS, asked in one place because it is asked in
-- two, and the second one did not ask.
--
-- `seat` chose per plot and `homeStand` took `STAND_AT` unconditionally --
-- which on a shop plot is twenty studs behind a plot origin that is the
-- middle of a fourteen-stud room, so out through the back wall and onto the
-- grass.
--
-- IT IS UNREACHABLE TODAY AND THAT IS THE POINT OF FIXING IT. `homeStand`
-- only ever builds the last leg of a ROBBERY TRIP, and the tick refuses one
-- outright for a shop -- a shopkeeper minds the shop, see the `plot.shop`
-- guard in `beginTrip`'s caller. So this was never wrong on screen; it was
-- one lifted guard away from being wrong on screen, silently, because
-- nothing in that building collides and a figure standing in a field throws
-- nothing. Two answers to one question, one of which nobody was asking.
local function standOffset(plot: PlotService.Plot): Vector3
	return if plot.shop then SHOP_STAND_AT else STAND_AT
end

-- The name over a shop's vault, which is the shop's own rather than a
-- neighbour's.
--
-- Read out of `Config.SHOPS` by the tab the plot carries, so the plaque,
-- the steal prompt, the delivery toast and the rap sheet all name the same
-- shop the door behind it opens -- and adding a fifth shop needs nothing
-- here. Falls back rather than erroring: a shop with no matching row is a
-- misconfiguration, and losing its NAME is a far smaller fault than losing
-- the resident, which is a robbable pig the economy is counting on.
local function shopName(plot: PlotService.Plot): string
	for _, spec in ipairs(Config.SHOPS) do
		if spec.tab == plot.shop then
			return spec.name
		end
	end
	warn("[ResidentService] no SHOPS row for tab " .. tostring(plot.shop))
	return "THE SHOP"
end

-- ============================================================
-- SEATING
-- ============================================================

-- Paints the defences, the sign and the house for a resident's current
-- level.
--
-- All four ladders land at ZERO while the street is new, which is what makes
-- the first robbery a player ever performs a clean run at a bare plot -- and
-- they climb on their own as the humans do, so a resident never settles into
-- being the free money a maxed player farms instead of playing the game.
local function applyLevel(resident: Resident)
	local plot = resident.plot
	local level = resident.incomeLevel
	local R = Config.RESIDENTS

	-- A SHOP LADDERS ITS LOCK AND NOTHING ELSE, AND THE FOUR IT SKIPS ARE
	-- WHAT MAKE IT A DIFFERENT ROBBERY RATHER THAN A CLOSER HOUSE.
	--
	-- No dog, no fence, no house and no garden: there is nothing to get past
	-- and the whole cost of the job is the run home -- which is about 23
	-- studs against a house's 53. That is the trade `SHOP_VAULT_DISCOUNT` is
	-- priced against, and it is what gives the loop two shapes of robbery
	-- instead of one: the quick loud one with the patrol for a response, and
	-- the slow rich one with a Mastiff on the lawn.
	--
	-- The LOCK is kept because it is the one defence that is honest on a
	-- strongroom, and because it is what casing reads: a maxed Lockpicks
	-- reads any lock from the pavement, and a row of shops that all read zero
	-- would make the rung worth less than it is. It is the same dial ladder a
	-- piggy bank carries, on a vault door instead of a flank -- see
	-- `PiggyBank.buildVault`.
	--
	-- The three it must not call are not merely pointless here, they are
	-- wrong: `buildFence` would ring the room with a plot-sized fence,
	-- `setHouseLevel` would stand a building inside the shop, and `setDecor`
	-- places against `Config.DECOR_SLOTS`, which are authored in plot-local
	-- studs on a 64-wide lawn.
	if plot.shop then
		PlotService.setLockLevel(plot, math.clamp(math.floor(level / R.lockPerLevels), 0,
			Config.UPGRADES.locks.max))
		-- AND DELIBERATELY NO `updateSign`. That function writes both rows and
		-- builds the boast row out of rebirths, a house tier and a skin --
		-- three things a shop has none of -- so calling it would put the shop
		-- name back exactly as it already is and blank the "VAULT" line under
		-- it. The board over the strongroom is built with its final text and
		-- never changes, because nothing about a shop's name does.
		return
	end

	PlotService.setDogLevel(plot, math.clamp(math.floor(level / R.dogPerLevels), 0, #Config.DOG_TIERS))
	PlotService.buildFence(plot, math.clamp(math.floor(level / R.fencePerLevels), 0, #Config.FENCE_TIERS))
	PlotService.setLockLevel(plot, math.clamp(math.floor(level / R.lockPerLevels), 0,
		Config.UPGRADES.locks.max))
	-- Up the BUILT houses only: a neighbour never stands a placeholder block
	-- or an earned trophy (see Config.residentHouseLevel).
	PlotService.setHouseLevel(plot, Config.residentHouseLevel(level / R.housePerLevels))

	-- A RICHER NEIGHBOUR HAS A FULLER GARDEN, which is free information read
	-- from the pavement: a bare lawn is a house at the bottom of the street
	-- and a crowded one is the best-paying and best-defended plot on it.
	--
	-- SCALED OFF THE LEVEL, LIKE EVERY OTHER LADDER IN THIS FUNCTION, and the
	-- first version got that wrong in a way worth recording. It derived the
	-- count from the raw OFFSET, so gardens varied while the street was still
	-- at level 0 and every house was identical -- measured live at 0, 12, 14
	-- and 57 ornaments standing on four houses with the same bare fence, the
	-- same absent dog and the same 1,481 coins. A full garden on a level-0
	-- plot advertises wealth that is not there, which is worse than no
	-- variety: it is variety that LIES.
	--
	-- Off the level it lands at zero on a new street with the other four
	-- ladders, which is the clean bare plot the thirty-second storyboard is
	-- written against, and it fills in as the street climbs.
	local want = math.clamp(math.floor(level / R.decorPerLevels), 0,
		Config.RESIDENTS.decorMax)

	local placed: { [string]: string } = {}
	local slot = 0
	for _, def in ipairs(Config.DECOR_SLOTS) do
		if def.zone == "lawn" and slot < want then
			slot += 1
			local key = resident.garden[slot]
			if key then
				placed[def.id] = key
			end
		end
	end
	PlotService.setDecor(plot, placed)

	-- THE PIG WEARS IT, AND THE SIGN NAMES IT, IN THE SAME BREATH.
	--
	-- Two calls beside each other rather than one at `seat`, so the two can
	-- never disagree: `applyLevel` is what runs whenever anything about
	-- this house is repainted, and a skin applied once at seat would be
	-- silently undone by anything that rebuilt the pig afterwards.
	--
	-- `updateSign` skips a skin that is the default's own name, so a
	-- neighbour who happened to draw Classic gets a plain sign rather than
	-- one boasting about the free tier -- which is the same rule that keeps
	-- the Starter Shack off it.
	PlotService.applySkin(plot, resident.skin)
	PlotService.updateSign(plot, resident.name, 0,
		Config.getSkin(resident.skin).name)
end

-- ============================================================
-- WHAT A NEIGHBOUR'S PIG LOOKS LIKE
-- ============================================================
--
-- A RESIDENT WEARS A SKIN, AND THE REASON IS THE VICTIM SHELF.
--
-- Every unclaimed pig on this street was `Config.DEFAULT_SKIN` -- the
-- one `PlotService` builds with and the one `release` puts back. That
-- was invisible while nothing read a victim's skin, and it stopped being
-- invisible the moment a trophy collected them: a shelf filled by
-- robbing would have had exactly ONE entry available to a solo player,
-- which makes it a two-player feature on a game whose entire resident
-- system was built to stop those. Roughly ten entries under "Not yet
-- verified" in CLAUDE.md read *needs a second player*, and residents are
-- why most of them no longer do.
--
-- IT ALSO PAYS FOR ITSELF ON THE STREET. A row of identical pink pigs
-- was the last place a neighbourhood read as a showroom rather than as
-- houses with people in them -- the same complaint that put every
-- resident on its own rung of the level ladder rather than all at the
-- street's own.
--
-- A SKIN CONFERS NOTHING, which is what makes this safe. It is colour and
-- material on a body; the lock tier, the dog, the fence, the pile and the
-- rob badge are every single thing a thief reads to price a job, and not
-- one of them lives here. The rule it has to clear is the third one in
-- `docs/MASTER-PLAN.md` -- a cosmetic may never imply a tier that has not been
-- bought -- and a skin cannot reach `scale`, `shape` or any ladder.
--
-- A SHUFFLED BAG, NOT A HASH OF THE PLOT INDEX, and the difference is
-- what the shelf can actually reach.
--
-- Indexing the catalogue by plot would pin one skin per house forever, so
-- an account could only ever collect the ten or so this street happens to
-- carry, in every session, for the life of the save -- a collection of
-- forty-six with a hard ceiling of ten. A bag drawn per SERVER gives a
-- different ten every session, and guarantees no two neighbours share one
-- inside a session, which is the same property the music cues take from
-- the same pattern.
--
-- WHAT IT COSTS is that a house's pig changes colour between sessions
-- while its NAME does not. That is the honest reading anyway: `seat` is
-- called whenever a plot frees up, so a neighbour genuinely is a new
-- occupant, and the one thing a plot keeps across owners is its address.
--
-- EARNED-ELSEWHERE SKINS ARE EXCLUDED, through the one predicate that
-- answers this in ten places. A pass skin on a neighbour's lawn would
-- advertise a paid exclusive on scenery, and a set skin would put an
-- event reward on a pig nobody attended anything to get.
local skinBag: { string } = {}

local function drawSkin(): string
	if #skinBag == 0 then
		for key, spec in pairs(Config.SKINS) do
			-- AND A SKIN THAT CARRIES AN AURA IS KEPT OFF SCENERY TOO, which
			-- is a NEW exclusion and a different question from the one above.
			--
			-- The rule that makes a skin safe on a neighbour's lawn is stated
			-- in CLAUDE.md as "A SKIN CONFERS NOTHING... it is colour and
			-- material on a body". An aura is not colour on a body -- it is
			-- particles thrown off it, and a row of resident houses emitting
			-- legendary auras nobody earned is precisely the "variety that
			-- LIES" failure this file already records for gardens advertising
			-- wealth that is not there.
			--
			-- IT IS NOT FOLDED INTO `isEarnedElsewhere`, deliberately. That
			-- predicate means "earned outside the coin economy" and is read in
			-- ten places, including `isSkinUnlocked` and every chest pool --
			-- so an aura'd legendary added to it would become unreachable from
			-- the very crate it is stocked in. This is a question about
			-- SCENERY, and it belongs where scenery is chosen.
			if not Config.isEarnedElsewhere(spec) and spec.aura == nil then
				table.insert(skinBag, key)
			end
		end
		-- Sorted before the shuffle so the bag is built from a stable list
		-- rather than from whatever order `pairs` happened to walk -- which
		-- makes a bad draw reproducible instead of a ghost.
		table.sort(skinBag)
		for i = #skinBag, 2, -1 do
			local j = math.random(i)
			skinBag[i], skinBag[j] = skinBag[j], skinBag[i]
		end
	end
	if #skinBag == 0 then
		return Config.DEFAULT_SKIN
	end
	return table.remove(skinBag) :: string
end

-- Publish only for the current occupant. Refunds may hold an evicted resident.
local function publishAcorns(resident: Resident)
	local plot, stock = resident.plot, resident.acornStock
	if not stock or plot.owner or residents[plot.index] ~= resident then return end
	PlotService.updateAcorns(plot, stock.acorns)
	PlotService.updateTreeAcorns(plot, stock.treeAcorns, stock.groundAcorns)
end

-- Seats a resident on a plot that has just become free (or is free at
-- startup). Safe to call twice: the second call is ignored rather than
-- replacing a resident and losing its pile.
function ResidentService.seat(plot: PlotService.Plot)
	if plot.owner ~= nil or residents[plot.index] then
		return
	end

	-- Rolled BEFORE the level is worked out, because the level IS the street
	-- plus this resident's own offset. `minLevel` is the floor, so a spread
	-- can never push a house below the level a brand new player meets.
	local offset = pickOffset()
	local garden = rollGarden()
	local level = math.max(Config.RESIDENTS.minLevel, currentLevel() + offset)
	local capacity = pigSize(level, plot)

	local resident: Resident = {
		plot = plot,
		acornStock = ResidentAcorns.attach(plot.index, plot.shop ~= nil, os.time()),
		-- Indexed by plot rather than picked at random, so a house keeps its
		-- identity across an owner arriving and leaving.
		--
		-- A SHOPKEEPER IS NAMED AFTER THE SHOP RATHER THAN AS A NEIGHBOUR. The
		-- name reaches the plaque, the steal prompt, the delivery toast and
		-- the rap sheet, so "Old Man Hamm" over a shop counter would be four
		-- places telling a player something that is not true about the thing
		-- in front of them.
		name = if plot.shop then shopName(plot) else Config.getResidentName(plot.index),
		-- SEEDED FULL, NOT EMPTY. A player arriving seven seconds into their
		-- first session meets whatever is in the nearest pig, and if that is
		-- zero because the server booted a minute ago then the first robbery
		-- of their life pays nothing. Full rather than a fraction because a
		-- resident never spends: a pig that holds `pigSeconds` of income and
		-- refills at exactly that income sits at the top of its range
		-- basically always, so seeding anywhere else is a lie that corrects
		-- itself in a few minutes.
		coins = math.floor(capacity),
		incomeLevel = level,
		capacityLevel = level,
		offset = offset,
		-- DRAWN FOR EVERY PLOT INCLUDING A SHOP, so the field is never nil
		-- and a reader never has to ask which kind of plot it is holding. What
		-- a shop does with it is nothing -- `applyLevel` returns before the
		-- skin is applied, because a shop counter is a shop counter.
		skin = drawSkin(),
		garden = garden,
		state = "home",
		at = Vector3.zero,
		facing = Vector3.new(0, 0, 1),
		stride = 0,
		route = {},
		loot = 0,
		-- Staggered rather than all due at once, or every neighbour sets off
		-- in the second the server boots and the whole row is empty at the
		-- same time. `outCount` caps how many are OUT; this is what stops
		-- them queueing behind that cap in lockstep.
		nextTrip = os.clock() + math.random() * Config.RESIDENTS.walk.restMax,
		waitUntil = 0,
		-- Staggered for the same reason `nextTrip` is: eight neighbours seeded
		-- on one clock speak in chorus, which reads as a mechanism rather than
		-- as people.
		nextLine = os.clock() + math.random() * Config.RESIDENT_CHATTER.maxGap,
		quietAt = 0,
	}

	residents[plot.index] = resident
	applyLevel(resident)

	-- The lawn is the TOP OF THE PLOT SLAB, derived rather than the +0.5 it
	-- happens to be today: a plot is three different floor heights and using
	-- one number for all of them is what left every ornament hovering a full
	-- stud when Decor was written.
	local lawnY = plot.base.Position.Y + plot.base.Size.Y / 2
	-- `name` is the second argument and was being dropped, which slid the
	-- CFrame into it and the ground height into `at` -- so every resident on
	-- the street threw "attempt to index number with 'Position'" and the whole
	-- neighbourhood stood empty. The pcall around it did its job perfectly and
	-- that is exactly why nobody noticed: eight warnings a boot, in a log
	-- nobody was reading, for a feature whose failure looks identical to the
	-- plot simply being vacant. The comment below already says the figure
	-- carries no behaviour, so nothing else broke.
	local standAt = standOffset(plot)
	local ok, built, rig = pcall(ResidentModel.build, plot.index, resident.name,
		plot.cframe * CFrame.new(standAt), lawnY, plot.model)
	if ok then
		resident.model = built
		resident.rig = rig
		-- Where they are standing right now, so the first frame of the first
		-- walk starts from the lawn rather than from the world origin.
		local stand = (plot.cframe * CFrame.new(standAt)).Position
		resident.at = Vector3.new(stand.X, lawnY, stand.Z)
		resident.seat = resident.at
		-- PLOT-LOCAL +Z IS THE STREET, AND `LookVector` IS -Z, so this read
		-- the plot's own LookVector and pointed the neighbour at their own
		-- HOUSE. It cancelled against the flipped `lookAt` below and the
		-- standing pose came out correct, which is the entire reason both
		-- bugs survived: they were only ever wrong TOGETHER, and a resident
		-- standing on their lawn is what anybody looks at.
		resident.facing = -plot.cframe.LookVector
	else
		-- A neighbour who fails to build is a plot with nobody standing on
		-- it, which is exactly what this plot looked like yesterday. It must
		-- never be a plot that cannot be robbed -- the figure carries no
		-- behaviour, so losing it costs the picture and nothing else.
		warn("[ResidentService] could not build a resident figure: " .. tostring(built))
	end
	PlotService.updatePile(plot, resident.coins, capacity)
	plot.model:SetAttribute(Config.PLOT_RESIDENT_ATTRIBUTE, resident.name)
	-- The id the steal cooldown travels under. Must match `targetId` in
	-- HeistService exactly, or a client would key its cooldown badge to an
	-- id the server never sends and the badge would never count down.
	plot.model:SetAttribute(Config.PLOT_RESIDENT_ID_ATTRIBUTE, -plot.index)
	publishAcorns(resident)
end

-- Takes the resident off a plot a player is moving into.
--
-- The coins simply GO. They were never anybody's, and handing an arriving
-- player whatever the previous resident had saved up would be a coin faucet
-- that pays out for joining -- the same money printer this project already
-- refused for a migration that ran on every join.
function ResidentService.evict(plot: PlotService.Plot)
	local resident = residents[plot.index]
	if not resident then
		return
	end
	-- COINS IN TRANSIT GO BACK, NEVER WITH THEM. A player moving into this
	-- plot evicts whoever was standing on it, and if that neighbour happened
	-- to be halfway home with somebody else's coins then destroying them
	-- would DELETE those coins -- a silent leak out of a real player's pig,
	-- keyed to somebody else joining the server.
	if resident.loot > 0 then
		ResidentService.nabbed(resident)
	end
	if resident.model then
		resident.model:Destroy()
	end
	ResidentAcorns.suspend(plot.index, os.time())
	residents[plot.index] = nil
	plot.model:SetAttribute(Config.PLOT_RESIDENT_ATTRIBUTE, nil)
	plot.model:SetAttribute(Config.PLOT_RESIDENT_ID_ATTRIBUTE, nil)
end

-- ============================================================
-- GOING OUT
-- ============================================================
--
-- A RESIDENT PLAYS THE GAME NOW, AND THAT ANSWERS THE QUESTION THIS FILE
-- LEFT OPEN AT THE TOP RATHER THAN ADDING A FEATURE BESIDE IT.
--
-- The header lists three ways to resolve "there is visibly somebody standing
-- in the garden while the dog treats this plot as empty", and this is the
-- third: the figure moves, so HOME IS A THING YOU CAN WATCH FOR. A neighbour
-- on their own lawn is in; a neighbour walking up somebody else's driveway is
-- out, and their own pig is behind them with nobody on it. Nothing has to be
-- explained, and the tell is the same one the dog's posture already carries.
--
-- WHY THEY ROB PLAYERS AND NOT ONLY EACH OTHER. Residents were built because
-- a quiet server had NOTHING TO ROB; the mirror of that is a quiet server
-- with NOBODY TO DEFEND AGAINST, and it is just as real. Every rung of the
-- defence tree -- the Vault Lock, the Fence, the Guard Dog, the Guard Duty
-- Treat, the Sprinkler -- protects against other players, so in a solo
-- session half the shop is inert and a child who spends their afternoon
-- buying a Mastiff has bought a thing that will never once be used.
--
-- WHAT KEEPS THAT SAFE FOR A NINE-YEAR-OLD, and it is three things that
-- already exist rather than three new ones:
--   * `Config.LOSS_CAP` still applies, because it is keyed to the VICTIM and
--     does not care who the thief is. A resident cannot take more than the
--     quarter-of-a-pig-an-hour any thief is held to.
--   * A plot is RELEASED the moment its owner leaves, so this can only ever
--     happen while the player is present to do something about it.
--   * The loot is TAGGABLE. A resident carrying a player's coins wears the
--     same prompt a player thief does, so the answer is the verb the game
--     already taught -- and it is the reason the carry speed below is set
--     where it is.

-- HOW FAST A NEIGHBOUR WALKS, and the ordering is the whole balance.
--
-- `Config.BASE_WALK_SPEED` is 16 and a carrying player does 12. A resident
-- strolls well under both and carries slower still, so A PLAYER CAN ALWAYS
-- RUN ONE DOWN -- on their own lawn, on the pavement, or at the neighbour's
-- gate. That is what stops this being a tax: the coins are recoverable by
-- doing the thing, every time, with no purchase involved.
--
-- It is also why a resident is never given a ride, a dodge or a burst. Those
-- exist to make a PLAYER's getaway a contest; a neighbour's getaway is meant
-- to be losable.
local function walkSpeed(resident: Resident): number
	-- A CHASING SHOPKEEPER IS THE ONE RESIDENT THAT IS NOT STROLLING, and
	-- 14.5 is the officer's own number rather than a new one -- see
	-- `Config.SHOPKEEPER`. It sits between a carrying thief's 12 and a free
	-- player's 16, so the loot is what makes you catchable and delivering is
	-- the answer.
	if resident.state == "chasing" then
		return Config.SHOPKEEPER.speed
	end
	local walk = Config.RESIDENTS.walk
	return if resident.state == "carrying" then walk.carrySpeed else walk.speed
end

-- The lawn, and the ground outside the fence. A plot is three different floor
-- heights and using one number for all of them is what left every ornament
-- hovering a full stud when Decor was written.
local function lawnY(plot: PlotService.Plot): number
	return plot.base.Position.Y + plot.base.Size.Y / 2
end

local function groundY(plot: PlotService.Plot): number
	-- The slab sits ON the world ground, so its underside IS the ground.
	-- Derived rather than the -0.5 it happens to be, for the same reason the
	-- lawn is.
	return plot.base.Position.Y - plot.base.Size.Y / 2
end

-- WHICH WAY THEY ARE POINTING, AND IT IS A FUNCTION RATHER THAN TWO CALLS TO
-- `CFrame.lookAt` BECAUSE THIS EXACT LINE HAS COST THIS PROJECT A BUG BEFORE.
--
-- `CFrame.lookAt` aims LOOKVECTOR, and LookVector is -Z. Every builder in
-- this repo authors facing +Z. So `lookAt(at, at + dir)` puts the figure's
-- FRONT at -dir and walks them backwards -- which is precisely what the guard
-- dog did, tail-first, through every patrol and chase from the day it was
-- built until somebody happened to notice.
local function facingCF(at: Vector3, facing: Vector3): CFrame
	return CFrame.lookAt(at, at + facing) * CFrame.Angles(0, math.pi, 0)
end

-- THE ROUTE IS THE ONE A PLAYER WOULD WALK, and that matters more than it
-- sounds. A resident is CanCollide off and could cut through the fence, the
-- house and the hedge in a straight line -- and would immediately stop
-- reading as a neighbour and start reading as a ghost. So it leaves by its
-- own front gate, walks the verge, and comes up the victim's drive.
--
-- Plot-local +Z is the street on BOTH rows -- the far row's half turn is
-- already in its plot CFrame -- so every offset here is written once and is
-- correct on all eight plots with nothing to remember.
local GATE_Z = 24      -- the front fence line, in plot-local studs
local VERGE_Z = 56     -- out past the driveway, on the grass beside the road
local PIG_Z = 9        -- beside the piggy bank, inside `Config.STEAL_RANGE`

local function routeTo(from: Resident, victim: PlotService.Plot): { Vector3 }
	local home = from.plot
	local hg, hv = groundY(home), lawnY(home)
	local vg, vv = groundY(victim), lawnY(victim)
	local function at(plot: PlotService.Plot, z: number, y: number): Vector3
		local p = (plot.cframe * CFrame.new(0, 0, z)).Position
		return Vector3.new(p.X, y, p.Z)
	end
	return {
		at(home, GATE_Z, hv),
		at(home, VERGE_Z, hg),
		at(victim, VERGE_Z, vg),
		at(victim, GATE_Z, vv),
		at(victim, PIG_Z, vv),
	}
end

local function homeStand(resident: Resident): Vector3
	local p = (resident.plot.cframe * CFrame.new(standOffset(resident.plot))).Position
	return Vector3.new(p.X, lawnY(resident.plot), p.Z)
end

-- WHO IS WORTH GOING OUT FOR.
--
-- Every plot but their own is a candidate, players included. A resident does
-- not case the street for the richest pig and never will: picking the best
-- target would make the same house the victim every time, and the one thing
-- eight neighbours must not do is converge.
local function pickVictim(resident: Resident): PlotService.Plot?
	local options = {}
	for _, plot in ipairs(PlotService.getAll()) do
		if plot.index ~= resident.plot.index then
			-- A shielded player is not a target, which is the same refusal a
			-- player thief meets and is asked of the one service that owns
			-- the answer rather than re-derived here.
			local shielded = false
			if plot.owner then
				local until_ = plot.owner:GetAttribute(Config.PLAYER_SHIELD_ATTRIBUTE)
				shielded = typeof(until_) == "number"
					and until_ > workspace:GetServerTimeNow()
			end
			if not shielded then
				table.insert(options, plot)
			end
		end
	end
	if #options == 0 then
		return nil
	end
	return options[math.random(#options)]
end

-- How many are out at once, counted rather than tracked.
--
-- A counter kept alongside would be a second piece of state that can
-- disagree with the residents themselves -- the `busyUntil`/`napUntil` bug
-- this project already records at length. Eight is a small enough table that
-- asking is free.
local function outCount(): number
	local n = 0
	for _, r in pairs(residents) do
		if r.state ~= "home" then
			n += 1
		end
	end
	return n
end

-- The one hook out to the heist, filled in by `Main`.
--
-- `HeistService` requires `ResidentService`, so asking it directly is a
-- cycle. This is the shape `SetService.registerPusher` and
-- `PlotService.registerBounceVeto` already use, and it makes the cycle
-- IMPOSSIBLE rather than merely absent today.
--
-- It returns how much was actually taken, because the answer is not the
-- amount asked for: `Config.LOSS_CAP` may allow less, and an empty pig
-- allows nothing.
local takeFrom: ((PlotService.Plot, number, string) -> number)? = nil

function ResidentService.registerTake(fn: (PlotService.Plot, number, string) -> number)
	takeFrom = fn
end

-- The other half: coins that never made it home go back where they came
-- from. Nabbing a resident thief has to be worth exactly what nabbing a
-- player thief is worth, and the only way to guarantee that is for both to
-- run through the same accounting.
local giveBackTo: ((PlotService.Plot, number) -> ())? = nil

function ResidentService.registerGiveBack(fn: (PlotService.Plot, number) -> ())
	giveBackTo = fn
end

-- AND THE CATCH, FILLED IN BY `Main` FOR THE REASON THE TWO ABOVE ARE.
--
-- A shopkeeper who runs a thief down has to cost them exactly what a guard
-- dog costs them -- the loot recovered, the stun, the toast -- and the only
-- way to guarantee that is for both to run through the same accounting.
-- `HeistService.nab` already takes a non-Player tagger, because the dog
-- passes a Resident table, so this is that path with a different animal on
-- the end of it.
--
-- A REGISTRY RATHER THAN A REQUIRE, because `HeistService` requires THIS
-- file: asking directly would be a cycle. Same shape as
-- `SetService.registerPusher` and the trampoline's bounce veto, and it makes
-- the cycle impossible rather than merely absent today.
local catchThief: ((Resident, Player) -> ())? = nil

function ResidentService.registerCatch(fn: (Resident, Player) -> ())
	catchThief = fn
end

-- A SHOPKEEPER COMES OUT FROM BEHIND THE COUNTER.
--
-- Called from `releaseDog` when the plot has no dog to let off, which on a
-- shop is always -- see `Config.SHOPKEEPER` for what wakes them and why it is
-- only ever the loud paths.
function ResidentService.alertShopkeeper(plot: PlotService.Plot, thief: Player): boolean
	-- Through the accessor rather than the table: `residents` is keyed by
	-- `plot.index` and not by the plot, which is exactly the sort of thing
	-- that reads fine and returns nil forever.
	local resident = ResidentService.get(plot)
	if not resident or not plot.shop or not resident.model then
		return false
	end
	-- ALREADY BUSY IS ALREADY ANSWERED. A shopkeeper mid-chase who is
	-- re-alerted by a second fumble should not have their clock reset by it,
	-- or continuous noise would postpone the give-up indefinitely -- which is
	-- precisely backwards, and is the bug `wakeDelay` was written to avoid on
	-- the dog.
	if resident.state ~= "home" then
		return false
	end
	resident.state = "chasing"
	resident.chasing = thief
	local now = os.clock()
	-- The beat before they come. Stamped once on a fresh alarm and never
	-- re-stamped by a later one -- continuous noise postponing the reaction
	-- indefinitely is precisely backwards, which is the rule the dog's own
	-- wakeDelay already keeps.
	resident.chaseFrom = now + Config.SHOPKEEPER.wakeDelay
	resident.chaseUntil = resident.chaseFrom + Config.SHOPKEEPER.maxChase
	resident.route = {}
	return true
end

-- ============================================================
-- THE LOOT IN THEIR ARMS
-- ============================================================

-- A CARRIED PIG IS THE SAME PICTURE A PLAYER THIEF MAKES, deliberately.
--
-- The whole point of a resident going out is that it reads as somebody
-- playing the game, and the one thing a player thief looks like is a person
-- carrying a labelled miniature piggy bank with a highlight on it. Building
-- a different picture for an NPC would say "this one is scenery" at exactly
-- the moment it stops being scenery.
local function attachLoot(resident: Resident, victim: PlotService.Plot, amount: number)
	local model = resident.model
	if not model then
		return
	end
	local torso = model:FindFirstChild("Tee", true)
	if not (torso and torso:IsA("BasePart")) then
		return
	end

	-- THE MINIATURE MATCHES THE PIG IT CAME OUT OF, the same rule
	-- `HeistService.attachLoot` follows: the label on a thief's arms is a
	-- tell about WHOSE coins those are, and a resident carrying a default
	-- pink pig away from somebody's Bubblegum one is a tell that lies.
	local victimPlayer = victim.owner
	local victimData = if victimPlayer then DataService.get(victimPlayer) else nil
	local skinKey = if victimData then victimData.cosmetics.skin else Config.DEFAULT_SKIN

	local ok, mini = pcall(PiggyModel.build, skinKey)
	if not ok or not mini then
		return
	end
	mini.Name = "ResidentLoot"
	-- Inherits the figure's own rule rather than restating it: a resident is
	-- CanCollide and CanQuery off so it can never body block a thief, a
	-- defender or the dog, and what it is holding must not reintroduce that.
	-- ANCHORED AND UNWELDED, WHICH IS THE OPPOSITE OF WHAT A PLAYER THIEF
	-- NEEDS AND IS RIGHT HERE FOR THE SAME REASON THEIRS IS.
	--
	-- A player's loot is welded because it rides a physics character the
	-- server does not own. A resident is anchored geometry moved by
	-- `PivotTo`, and PivotTo carries EVERY descendant rigidly -- so the
	-- miniature follows the body for free, and a weld would be a second
	-- mechanism fighting the first. This is the same split `HeldItem` records
	-- from the other end, where the builders had to have their anchors taken
	-- OFF to be welded into a hand.
	for _, d in ipairs(mini:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.Anchored = true
		end
	end

	-- Held in front of the chest, facing the way they walk. The torso is not
	-- a rig piece -- only Leg, Arm and Shoe are posed individually -- so it
	-- rides the model's own pivot rigidly and its +Z IS the way they face.
	--
	-- Both halves of this line flipped when the body stopped walking
	-- backwards: -2.1 was "in front" only while the front was -Z, and the
	-- half turn existed to stop the pig staring the other way. A placement
	-- authored against a bug inherits the bug.
	-- AND IT MOVED IN TO MEET THE HANDS, WHICH IS `RidePose`'S RULE ON A
	-- THIRD OBJECT: MOVE THE MACHINE TO THE HAND, NEVER THE HAND TO THE
	-- MACHINE.
	--
	-- 2.1 was solved when nobody was holding this -- it is the offset that
	-- puts a floating pig in a readable place in front of a chest, and
	-- `CarryPose` records the player's own version of that number being
	-- "comfortably out of reach of the pose that now holds it". The same is
	-- true here. `ResidentModel`'s `CARRY_PITCH` lands the hands at about
	-- z 1.54 from the torso centre, and the mini's radius is near 1.1, so at
	-- 1.7 its near face sits about where the chest front is (0.42) and its
	-- flanks are where the hands are. At 2.1 the hands close on empty air
	-- half a stud behind it.
	mini:PivotTo(torso.CFrame * CFrame.new(0, 0.3, 1.7))
	mini.Parent = model

	-- AND IT IS TAGGABLE, WHICH IS THE HALF THAT MAKES ANY OF THIS FAIR.
	--
	-- The alert a victim gets says "nab them before they get home", and a
	-- promise the game does not keep is worse than no alert at all -- so the
	-- prompt is built in the same breath as the loot rather than left to a
	-- later pass. It is the SAME prompt a player thief carries, down to the
	-- kind attribute, the hold and the range: a nine-year-old who has nabbed
	-- one thief has already been taught this one.
	--
	-- It sits on the LOOT rather than on the neighbour, which is what makes
	-- it self-clearing -- no loot, no prompt, and there is no state anywhere
	-- that can disagree about whether somebody is worth tagging.
	local body = mini.PrimaryPart or mini:FindFirstChildWhichIsA("BasePart", true)
	if body then
		-- Re-enabled for the prompt alone: the rest of the figure stays
		-- CanQuery off so it can never eat a raycast meant for a piggy.
		body.CanQuery = true
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "NabPrompt"
		prompt.ActionText = "Nab Thief!"
		Config.setPromptKind(prompt, "nab")
		prompt.ObjectText = resident.name
		prompt.HoldDuration = Config.NAB.hold
		prompt.MaxActivationDistance = Config.NAB.distance
		prompt.RequiresLineOfSight = false
		prompt.Parent = body

		prompt.Triggered:Connect(function(nabber)
			ResidentService.recoverFrom(resident, nabber)
		end)
	end

	-- WHOSE COINS THESE ARE, and this used to be a Highlight on the whole
	-- figure. See `Config.CARRY_VICTIM_ATTRIBUTE`: a glow on a carrying
	-- neighbour is correct once and catastrophic at `walk.maxOut` of them,
	-- which is the state this street is in most of the time -- so the whole
	-- row lit up permanently and the one carrying YOUR coins was
	-- indistinguishable from the four who were not.
	--
	-- Nil unless a real person owns that plot. A neighbour robbing another
	-- neighbour is nobody's business but theirs, and it is by far the common
	-- case: a quiet street is almost all residents.
	model:SetAttribute(Config.CARRY_VICTIM_ATTRIBUTE,
		if victim.owner then victim.owner.UserId else nil)

	resident.lootModel = mini
	resident.loot = amount
	resident.markIndex = victim.index
end

local function clearLoot(resident: Resident)
	if resident.lootModel then
		resident.lootModel:Destroy()
		resident.lootModel = nil
	end
	if resident.model then
		resident.model:SetAttribute(Config.CARRY_VICTIM_ATTRIBUTE, nil)
	end
	resident.loot = 0
	resident.markIndex = nil
end

-- ============================================================
-- THE TRIP
-- ============================================================

local function goHome(resident: Resident)
	resident.state = "home"
	resident.route = {}
	local walk = Config.RESIDENTS.walk
	resident.nextTrip = os.clock() + walk.restMin
		+ math.random() * math.max(0, walk.restMax - walk.restMin)
end

-- BACK TO THE COUNTER, AND IT NEEDS A STATE OF ITS OWN.
--
-- `goHome` above sets `state = "home"` and clears the route -- it is a SETTLE
-- rather than a walk, which is correct for a neighbour who has just arrived
-- on their own lawn and wrong for a shopkeeper standing where they caught
-- somebody. And a shopkeeper cannot simply be given a route in the `home`
-- state, because that branch returns before the route walker is ever reached:
-- the early-out is what makes a resident at home cost nothing, and it is
-- load-bearing, so this walks in its own state and settles on arrival.
local function returnToCounter(resident: Resident)
	local seat = resident.seat
	if not seat then
		goHome(resident)
		return
	end
	resident.state = "returning"
	resident.route = { seat }
end

local function beginTrip(resident: Resident)
	local victim = pickVictim(resident)
	if not victim then
		goHome(resident)
		return
	end
	resident.state = "out"
	resident.route = routeTo(resident, victim)
	resident.markIndex = victim.index
end

-- Standing at the pig. A resident takes its time on purpose: the crack is a
-- DECISION for a player and a resident has no decision to make, so what it
-- spends instead is TIME STANDING IN THE OPEN -- which is the window a
-- victim has to walk over and do something about it.
local function beginCrack(resident: Resident)
	resident.state = "cracking"
	resident.route = {}
	resident.waitUntil = os.clock() + Config.RESIDENTS.walk.crackSeconds
end

local function finishCrack(resident: Resident)
	local index = resident.markIndex
	local victim = nil
	for _, plot in ipairs(PlotService.getAll()) do
		if plot.index == index then
			victim = plot
		end
	end
	-- The plot went away underneath them -- an owner arrived, or a resident
	-- was evicted. Walk home empty rather than reaching into a stale table.
	if not (victim and takeFrom) then
		resident.state = "carrying"
		resident.route = routeTo(resident, resident.plot)
		return
	end

	-- HOW MUCH THEY ASK FOR IS THE SAME SHARE A PLAYER'S CRACK TAKES, so a
	-- neighbour is never worse to be robbed by than a person. What comes back
	-- is what the cap and the pig actually allowed, which is why the answer
	-- is read rather than assumed.
	local want = math.floor(Config.RESIDENTS.walk.takeFraction
		* (victim.model:GetAttribute(Config.PLOT_VAULT_ATTRIBUTE) or 0))
	-- The name goes with it, because the victim's alert has to say WHO --
	-- an unattributed alarm is the thing a player cannot act on.
	local got = if want > 0 then (takeFrom :: any)(victim, want, resident.name) else 0
	if got > 0 then
		attachLoot(resident, victim, got)
	end

	resident.state = "carrying"
	-- Home the way they came: out of the gate, down the verge, up their own
	-- drive. The getaway is the half a player can act on, so it must be the
	-- same length as the approach rather than a shortcut.
	resident.route = routeTo(resident, resident.plot)
	-- routeTo walks FROM this resident's own plot, so going home is that
	-- route read from the victim's end. Rebuilt explicitly rather than
	-- reversed, because the two ends are different plots.
	local home = resident.plot
	local victimPlot = victim
	local function at(plot: PlotService.Plot, z: number, y: number): Vector3
		local pos = (plot.cframe * CFrame.new(0, 0, z)).Position
		return Vector3.new(pos.X, y, pos.Z)
	end
	-- AND IT ENDS AT THEIR OWN PIG, NOT AT THEIR STANDING SPOT.
	--
	-- `homeStand` is (12, 0, -20) in plot-local studs and the piggy holds the
	-- centre at 0, so a route that ended there put a neighbour 23.3 studs
	-- BEHIND their own pig, near the front door, and banked the loot on
	-- arrival -- coins teleporting into a pig they never went near. `PIG_Z`
	-- is the same waypoint the outbound trip uses to reach a VICTIM's pig, so
	-- a neighbour now walks up to a piggy bank at both ends of the job.
	--
	-- IT IS THE SAME RULE A PLAYER OBEYS SINCE DELIVERY BECAME A PRESS, which
	-- is the point rather than a side effect: everybody carrying loot walks
	-- to a pig and puts it in, and the street reads one way for both. `PIG_Z`
	-- is 9 and so is `Config.DROPOFF_RADIUS` -- not coupled in code, because
	-- one is a plot-local waypoint and the other is a radius, but they are
	-- two statements of the same distance and moving one wants a look at the
	-- other.
	--
	-- The walk from the pig to `homeStand` is a SECOND leg in the `returning`
	-- state. Banking is what happens when a route ENDS, so putting the pig
	-- mid-route would have meant detecting an intermediate waypoint -- and
	-- `returning` already exists, already walks one leg and already puts the
	-- facing back at the end of it.
	resident.route = {
		at(victimPlot, GATE_Z, lawnY(victimPlot)),
		at(victimPlot, VERGE_Z, groundY(victimPlot)),
		at(home, VERGE_Z, groundY(home)),
		at(home, GATE_Z, lawnY(home)),
		at(home, PIG_Z, lawnY(home)),
	}
end

-- Banking it. A resident's own pig is where the coins go, which keeps the
-- loop honest: what they took is now sitting in a pig somebody can come and
-- take back off them.
local function bankLoot(resident: Resident)
	if resident.loot > 0 then
		resident.coins = math.min(pigSize(resident.capacityLevel, resident.plot),
			resident.coins + resident.loot)
		PlotService.updatePile(resident.plot, resident.coins,
			pigSize(resident.capacityLevel, resident.plot))
	end
	clearLoot(resident)
end

-- TAGGED. The coins go back to whoever they came from and the neighbour
-- walks home with nothing, which is exactly what happens to a player thief.
function ResidentService.nabbed(resident: Resident)
	local index = resident.markIndex
	if resident.loot > 0 and index and giveBackTo then
		for _, plot in ipairs(PlotService.getAll()) do
			if plot.index == index then
				(giveBackTo :: any)(plot, resident.loot)
			end
		end
	end
	clearLoot(resident)
	resident.state = "carrying"
end

-- TAKES A NEIGHBOUR'S LOOT OFF THEM AND SAYS SO. Returns what was recovered,
-- which is 0 when there was nothing to take.
--
-- ONE PATH FOR TWO WAYS OF STOPPING THEM, and that is the whole reason it is
-- a function rather than a closure on the prompt. Walking up and holding the
-- tag was the only way to stop a carrying neighbour for as long as this
-- existed; a thrown gadget can do it from range now, and a second copy of
-- "give it back, then tell them" is the near-identical duplicate this project
-- keeps recording as the thing that drifts the first time either is touched.
--
-- Read at CALL time rather than captured when the prompt was built, because a
-- neighbour banks and sets off again: a closure holding the old amount would
-- refund coins that are no longer in their arms.
function ResidentService.recoverFrom(resident: Resident, taker: Player): number
	local amount = resident.loot
	if amount <= 0 then
		return 0
	end
	ResidentService.nabbed(resident)
	Remotes.get("Notify"):FireClient(taker,
		("Nice nab! You took %s back off %s."):format(
			Config.formatCoins(amount), resident.name), "good")
	return amount
end

-- Whichever resident is carrying and closest, for the tag to find.
function ResidentService.nearestCarrier(from: Vector3, range: number): (Resident?, number)
	local best, bestDist = nil, range
	for _, r in pairs(residents) do
		if r.loot > 0 then
			local d = (r.at - from).Magnitude
			if d <= bestDist then
				best, bestDist = r, d
			end
		end
	end
	return best, bestDist
end

-- ============================================================
-- THE WALK
-- ============================================================

-- Is there anybody close enough to be talked to?
--
-- THE CHARACTER, NEVER THE PLAYER. A Player is in the server from the moment
-- they connect and their character arrives later, so asking the Player list
-- alone has a window where somebody is present and nowhere -- and a neighbour
-- talking to a character that does not exist yet is a line spent on nobody.
local function someoneNear(at: Vector3, range: number): boolean
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart")
			and (root.Position - at).Magnitude <= range then
			return true
		end
	end
	return false
end


-- One neighbour's idle chatter, run only while they are standing about.
--
-- THE LINE IS PICKED HERE AND SEEN BY EVERYBODY, which is the leaderboards'
-- rule arriving on a speech bubble: two players standing at the same gate must
-- not be told the neighbour said two different things. What stays per viewer
-- is WHO SEES IT -- the bubble carries `MaxDistance`, so the culling costs the
-- server nothing and needs no remote.
--
-- THE GAP IS REDRAWN AFTER EVERY LINE, INCLUDING ONE NOBODY WAS THERE TO
-- HEAR. Holding the slot open until somebody walks past would make the first
-- line of every approach instant, which reads as the neighbour waiting for
-- you rather than as one you happened to catch.
local function stepChatter(resident: Resident, now: number)
	local chat = Config.RESIDENT_CHATTER
	if now < resident.nextLine then
		return
	end
	resident.nextLine = now + chat.minGap
		+ math.random() * math.max(0, chat.maxGap - chat.minGap)

	local model = resident.model
	if not (model and model.Parent) or #chat.lines == 0 then
		return
	end
	if not someoneNear(model:GetPivot().Position, chat.range) then
		return
	end
	ResidentModel.say(model, chat.lines[math.random(#chat.lines)])
	resident.quietAt = now + chat.hold
end


local function stepResident(resident: Resident, dt: number)
	local rig = resident.rig
	local model = resident.model
	if not (rig and model and model.Parent) then
		return
	end

	local now = os.clock()

	-- TAKEN DOWN IN EVERY STATE, NOT ONLY AT HOME. A neighbour who sets off
	-- mid-sentence would otherwise walk the length of the street with a speech
	-- bubble welded to them -- and `beginTrip` is one of four ways out of the
	-- home state, so clearing it at each of them is four chances to miss one.
	-- One comparison here covers all of them.
	if resident.quietAt > 0 and now >= resident.quietAt then
		ResidentModel.say(model, nil)
		resident.quietAt = 0
	end

	if resident.state == "home" then
		-- BEFORE THE TRIP CHECK, because the idle branch below RETURNS -- the
		-- early-out that makes a neighbour at home cost nothing is the same
		-- one that would skip this entirely. The shopkeeper is deliberately
		-- included: they are the most reliably standing figure on the street
		-- and the one a player walks right up to.
		stepChatter(resident, now)
		-- A SHOPKEEPER MINDS THE SHOP. Residents go out and rob each other so
		-- that a quiet server has something to DEFEND against as well as
		-- something to rob -- see `RESIDENTS.walk`. A shop has no legs: the
		-- figure behind the counter is the shopkeeper, and one wandering off
		-- down the street to crack a neighbour's pig would leave an unattended
		-- shop that is meant to be the one target always standing there.
		if not resident.plot.shop
			and now >= resident.nextTrip
			and outCount() < Config.RESIDENTS.walk.maxOut then
			beginTrip(resident)
		else
			-- STILL IN, AND THEREFORE FREE. Posing a figure that has not
			-- moved writes the same CFrame to every limb again -- identical
			-- pixels, and a full replication round for each one. The whole
			-- reason this walk can afford to be server-side is that a
			-- neighbour at home costs NOTHING, so the idle path has to return
			-- before the pose rather than after it.
			return
		end
	elseif resident.state == "cracking" then
		if now >= resident.waitUntil then
			finishCrack(resident)
		end
	elseif resident.state == "chasing" then
		-- RE-ROUTED EVERY TICK RATHER THAN GIVEN A DESTINATION, because a
		-- thief is running away and a route laid at the moment of the alarm
		-- would send a shopkeeper confidently to where somebody used to be.
		-- That is what separates a chase from an errand, and it is the same
		-- shape the officer's own pursuit uses.
		local thief = resident.chasing
		local character = thief and thief.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local spec = Config.SHOPKEEPER

		-- STILL GETTING UP. Nothing moves and nothing catches until the beat
		-- has passed -- see `Config.SHOPKEEPER.wakeDelay` for why gating only
		-- the walk is not enough in a room this size.
		if now < (resident.chaseFrom or 0) then
			return
		end

		if not (thief and hrp and hrp:IsA("BasePart")) or now >= (resident.chaseUntil or 0) then
			-- Out of time, or there is nobody left to chase -- they died,
			-- left, or got into a wheelie bin. Walking back is the honest
			-- ending and it is the same one the dog's cooldown produces.
			resident.chasing = nil
			resident.chaseUntil = nil
			returnToCounter(resident)
		else
			local to = (hrp :: BasePart).Position
			-- Measured FLAT. A shopkeeper on the forecourt and a thief up on
			-- a plot slab are a stud apart vertically, and counting that
			-- would make the catch radius mean something different on every
			-- piece of ground -- the trap the prompt ranges already record,
			-- where a reach measured to a centre is really a question about
			-- the floor.
			local flat = Vector3.new(to.X - resident.at.X, 0, to.Z - resident.at.Z)
			local gap = flat.Magnitude
			if gap <= spec.catchRadius then
				resident.chasing = nil
				resident.chaseUntil = nil
				if catchThief then
					catchThief(resident, thief :: Player)
				end
				returnToCounter(resident)
			elseif gap > spec.giveUp then
				-- A LEASH IN STUDS AS WELL AS A CLOCK. The street is 350
				-- studs long and a chase with only a timer on it ends with a
				-- shopkeeper stranded outside somebody's house at the far
				-- end of it, which is a shop standing unattended -- the exact
				-- thing that pins a shopkeeper behind the counter in the
				-- first place.
				resident.chasing = nil
				resident.chaseUntil = nil
				returnToCounter(resident)
			else
				-- One waypoint, replaced every tick. Y comes from where the
				-- shopkeeper already is rather than from the thief, so
				-- chasing somebody who has climbed a fence does not drag a
				-- shopkeeper into the air.
				resident.route = { Vector3.new(to.X, resident.at.Y, to.Z) }
			end
		end
	end

	local target = resident.route[1]
	if not target then
		-- Nothing left to walk to. Standing still is a stride that does not
		-- advance, so the legs close by construction with no test for it.
		ResidentModel.poseWalk(model, rig,
			facingCF(resident.at, resident.facing), resident.stride,
			resident.loot > 0)
		return
	end

	local delta = target - resident.at
	local flat = Vector3.new(delta.X, 0, delta.Z)
	local step = walkSpeed(resident) * dt

	if flat.Magnitude <= step then
		resident.at = target
		table.remove(resident.route, 1)
		if #resident.route == 0 then
			if resident.state == "out" then
				beginCrack(resident)
			elseif resident.state == "carrying" then
				-- AT THEIR OWN PIG, which is where the route now ends. The
				-- coins go in here rather than over by the front door, so the
				-- delivery happens AT the thing the coins live in -- the same
				-- move a player's DELIVER press makes.
				bankLoot(resident)
				-- Then the second leg, to wherever they stand when idle. A
				-- neighbour who banked and then stayed planted beside their
				-- own piggy would be permanently in the one spot a thief has
				-- to reach, which is a defence nobody bought.
				resident.state = "returning"
				resident.route = { homeStand(resident) }
			elseif resident.state == "returning" then
				-- Facing put back explicitly. The walker points a resident
				-- along their direction of travel, so a shopkeeper who has
				-- walked back would otherwise stand behind the counter facing
				-- the wall they came from -- and plot-local +Z is the street,
				-- which is the one angle this figure is ever looked at from.
				resident.facing = -resident.plot.cframe.LookVector
				goHome(resident)
			end
		end
	else
		local dir = flat.Unit
		resident.at += dir * step
		-- Y is taken from the waypoint being walked to rather than
		-- interpolated from where they started, so stepping up onto a lawn
		-- happens at the kerb instead of over the whole approach.
		resident.at = Vector3.new(resident.at.X,
			resident.at.Y + (target.Y - resident.at.Y) * math.min(1, dt * 6),
			resident.at.Z)
		resident.facing = dir
		resident.stride += step
	end

	-- THE HOLD IS `resident.loot > 0` AND DELIBERATELY NOT `state ==
	-- "carrying"`. Those two disagree in both directions and the loot is the
	-- honest one: a neighbour who was nabbed on the way home keeps the
	-- carrying STATE with nothing in their arms, and `finishCrack` sets the
	-- state before `attachLoot` decides whether anything came out of the pig
	-- at all. The file's own note one screen up makes the same call about the
	-- walk -- "the one thing that says a neighbour is holding anything is the
	-- loot model and never the walk".
	ResidentModel.poseWalk(model, rig,
		facingCF(resident.at, resident.facing), resident.stride,
		resident.loot > 0)
end


-- ============================================================
-- QUERIES  (the interface HeistService will steal through)
-- ============================================================

function ResidentService.get(plot: PlotService.Plot): Resident?
	return residents[plot.index]
end

function ResidentService.getAll(): { Resident }
	local out: { Resident } = {}
	for _, resident in pairs(residents) do
		table.insert(out, resident)
	end
	return out
end

function ResidentService.getCapacity(resident: Resident): number
	return pigSize(resident.capacityLevel, resident.plot)
end

-- Takes coins out of a resident's pig and republishes the pile. Returns what
-- was actually removed, which is never more than is in there.
function ResidentService.take(resident: Resident, amount: number): number
	local taken = math.min(math.floor(amount), math.floor(resident.coins))
	if taken <= 0 then
		return 0
	end
	resident.coins -= taken
	PlotService.updatePile(resident.plot, resident.coins, ResidentService.getCapacity(resident))
	return taken
end

-- Puts coins back, for the one path that needs it: a grab that was charged
-- and then failed to attach its loot model.
-- Returned coins fill only the room the pig has now (MASTER-PLAN 4c.6); the
-- rest spills, exactly as it would for a player. Returns what was banked.
function ResidentService.refund(resident: Resident, amount: number): number
	local capacity = ResidentService.getCapacity(resident)
	local banked = Config.fitInPig(resident.coins, capacity, amount)
	resident.coins += banked
	PlotService.updatePile(resident.plot, resident.coins, capacity)
	return banked
end

-- ============================================================
-- TICK
-- ============================================================

local function tick()
	local street = currentLevel()

	for _, resident in pairs(residents) do
		-- EACH RESIDENT TRACKS THE STREET FROM ITS OWN RUNG. The offset is
		-- fixed for the life of the house, so the whole row rises together and
		-- keeps its shape rather than converging on one level the moment
		-- anybody upgrades.
		local level = math.max(Config.RESIDENTS.minLevel, street + resident.offset)
		-- A resident's level tracks the street. Repainting the defences only
		-- when the level actually MOVES matters: `buildFence` and
		-- `setHouseLevel` tear down and rebuild real geometry, and doing that
		-- every second on every empty plot would be a rebuild storm nobody
		-- asked for.
		if level ~= resident.incomeLevel then
			local rising = level > resident.incomeLevel
			resident.incomeLevel = level
			resident.capacityLevel = level
			applyLevel(resident)

			-- TOPPED UP WHEN THE STREET LEVELS UP, and this was measured
			-- rather than anticipated. Residents are seated at BOOT, when the
			-- server is empty and `currentLevel` therefore answers 0 -- so
			-- they seed against a level-0 capacity. The first player then
			-- arrives, the level jumps to theirs, and capacity grows while
			-- the coins do not: measured live at 2,872 coins sitting in a pig
			-- that now holds 19,208, which is 15% full.
			--
			-- A thief crossing the road to that finds two per cent of almost
			-- nothing. A resident whose entire job is to always be worth
			-- robbing has to be topped up to the same share of its NEW
			-- capacity, or it is worth robbing only on the servers that
			-- happened to boot with everybody already in.
			--
			-- ONLY EVER UPWARDS. Following the level DOWN would refill a pig
			-- that a player has just emptied the moment somebody with a lower
			-- level joins -- which is a thief watching their own robbery be
			-- undone, and a coin faucet keyed to the door.
			if rising then
				resident.coins = math.max(resident.coins, pigSize(level, resident.plot))
			end

			-- PUBLISHED HERE AS WELL AS IN THE ACCRUAL BRANCH BELOW, AND
			-- LEAVING IT OUT WAS A REAL BUG RATHER THAN AN OVERSIGHT.
			--
			-- The accrual branch is guarded by `coins < capacity`, and a
			-- top-up leaves the pig EXACTLY full -- so on the one tick that
			-- matters the guard is false, `updatePile` never runs, and the
			-- plot attribute keeps whatever it was seeded with at boot.
			-- Measured: residents sitting at a published 2,962 while the
			-- street was level 9 and their real pigs held 44,130.
			--
			-- Everything a thief can see reads that attribute -- the coin
			-- pile on the lawn, the value on the rob badge, the take quoted
			-- by the steal prompt -- so the internal state and the whole
			-- world disagreed by fifteen times, silently, with the server
			-- being the one that was right. The published number IS the
			-- interface; anything that changes the pig has to republish it.
			PlotService.updatePile(resident.plot, resident.coins, pigSize(level, resident.plot))
		end

		local stock = resident.acornStock
		if stock and ResidentAcorns.tick(stock, os.time(), resident.state == "home") then
			publishAcorns(resident)
		end

		local capacity = pigSize(resident.capacityLevel, resident.plot)
		if resident.coins < capacity then
			-- Rebirths 0 and no friend bonus: a resident earns the plain rate
			-- for its level. Prestige and friends are things a PLAYER has,
			-- and handing either to a house nobody lives in would make an
			-- empty plot out-earn the street it stands on.
			resident.coins = math.min(capacity,
				resident.coins
					+ Config.getIncomeRate(resident.incomeLevel, 0) * Config.RESIDENTS.tickRate)
			PlotService.updatePile(resident.plot, resident.coins, capacity)
		end
	end
end

function ResidentService.start()
	-- Seat whatever is free at boot. Registered BEFORE this loop runs so a
	-- plot released a moment later gets a resident too.
	PlotService.onClaim(function(plot)
		ResidentService.evict(plot)
	end)
	PlotService.onRelease(function(plot)
		ResidentService.seat(plot)
	end)

	for _, plot in ipairs(PlotService.getAll()) do
		ResidentService.seat(plot)
	end

	task.spawn(function()
		while true do
			task.wait(Config.RESIDENTS.tickRate)
			local ok, err = pcall(tick)
			if not ok then
				warn("[ResidentService] tick failed: " .. tostring(err))
			end
		end
	end)

	-- THE WALK RUNS ON ITS OWN CLOCK, because the economy tick is one second
	-- and a figure that moves once a second is a slideshow.
	--
	-- SERVER-SIDE, AND THAT IS THE OFFICER'S ARGUMENT RATHER THAN A BREACH OF
	-- THE ANIMATED-SKINS RULE. The skins, the moat and HouseFX are all
	-- client-side because they are work multiplied by twelve plots and running
	-- forever. This is neither: `walk.maxOut` caps how many are moving at
	-- once, a resident standing at home writes NOTHING at all, and the
	-- position has to be the server's because a TAG depends on it -- a
	-- client-side walk would be overwritten by the server's next write every
	-- frame, exactly as PoliceService records.
	--
	-- PCALLED AS A WHOLE, the same call the dog's watcher makes: a neighbour
	-- out for a stroll is cosmetic-grade next to the heist loop running
	-- underneath it, and a walk may never stop the game being played.
	RunService.Heartbeat:Connect(function(dt)
		local ok, err = pcall(function()
			-- EVERY resident, every frame, and the cheapness lives INSIDE
			-- `stepResident` rather than in a guard here. Filtering on
			-- `state ~= "home"` reads like an optimisation and is a deadlock:
			-- the thing that decides a neighbour should GO OUT is the same
			-- function the guard was skipping, so nobody ever left.
			for _, resident in pairs(residents) do
				stepResident(resident, dt)
			end
		end)
		if not ok then
			warn("[ResidentService] walk failed: " .. tostring(err))
		end
	end)
end

return ResidentService
