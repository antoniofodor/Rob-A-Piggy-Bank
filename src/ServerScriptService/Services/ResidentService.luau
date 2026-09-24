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

	A RESIDENT IS A PEER, NOT A SECOND ECONOMY. Its income comes from
	`Config.getIncomeRate` at a level derived from the humans in the server,
	and its pig is `RESIDENTS.pigSeconds` of that income (a player's pig has
	no ceiling at all now; a resident's still does, because it is the supply
	the robbery audit is measured against), so an NPC pig is worth robbing at minute one
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
	Treat -- protects against other players, so in a solo
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
local PiggyModel = require(ReplicatedStorage.Shared.PiggyModel)
local ResidentModel = require(ReplicatedStorage.Shared.ResidentModel)
-- For the name over a carried piggy, in the same paper-on-ink the haul
-- service hangs over a player thief's: one label, two carriers.
local Theme = require(ReplicatedStorage.Shared.Theme)

export type Resident = {
	plot: PlotService.Plot,
	-- WHO THIS SHOPKEEPER IS AFTER, and until when. Only ever set on a
	-- resident seated on a shop plot -- see `Config.SHOPKEEPER`. A house
	-- resident is never given these because a house has a dog, and two
	-- things that can both hard-stop one thief on one lawn is how a plot
	-- becomes a wall.
	chasing: Player?,
	chaseUntil: number?,
	chaseFrom: number?,
	-- When this resident may next lob something. A house resident throws on an
	-- interval while chasing; a shopkeeper never throws and leaves it nil,
	-- which is `chaseSpec`'s decision rather than a flag kept here.
	nextThrow: number?,
	-- WHERE THEY STAND WHEN THEY ARE MINDING THE SHOP. Captured once at
	-- `seat` and never recomputed, so a shopkeeper who has chased somebody
	-- into the street has somewhere exact to walk back to. Without it
	-- `goHome` marks them home wherever they happen to be standing -- which
	-- is a shopkeeper permanently in the middle of their own shop floor,
	-- measured at 4.11 studs off the counter and staying there.
	seat: Vector3?,
	name: string,
	coins: number,
	-- Its own copy of the two economy levels: `Config.getIncomeRate` is
	-- asked exactly as it is for a player, and `capacityLevel` feeds
	-- `pigSize` (seconds of income) -- it is a resident's own field and not
	-- the retired player save field of the same name.
	incomeLevel: number,
	capacityLevel: number,
	-- HOW FAR BELOW THE STREET THIS ONE SITS, rolled once when it is seated
	-- and kept for as long as it stands. Re-rolling on the tick would
	-- reshuffle the whole street every time anybody levelled up, and a house
	-- that changes its fence, dog and building for no reason a player can see
	-- is worse than a street with no variety at all.
	offset: number,
	-- WHAT THIS HOUSE LOOKS LIKE, WHICH IS A DIFFERENT NUMBER FROM WHAT ITS
	-- PIG IS WORTH. The fence, the lock, the building and the garden all come
	-- off this; `incomeLevel` above drives the pig and nothing else. They
	-- were one number until 2026-09-23, so a street was a mirror of whoever
	-- stood on it -- see `Config.RESIDENTS.style` for the whole argument and
	-- for why only the INCOME half was ever the faucet risk.
	--
	-- ROLLED ONCE AND NEVER RE-DERIVED, which the income offset's own note
	-- already argues for: a house that changes its fence and its building
	-- for no reason a player can see is worse than a street with no variety
	-- at all. The difference is that `offset` still tracks the street from
	-- its own rung, and this does not track it at all.
	styleLevel: number,
	-- THE STYLE LEVEL THE GEOMETRY IS CURRENTLY STANDING, so the four
	-- ladders are rebuilt when they actually move and not when the pig
	-- moves. `buildFence` and `setHouseLevel` tear down and rebuild real
	-- parts, and since the split an income tick would do that to every
	-- empty plot on the street to arrive at identical geometry.
	styleShown: number?,
	-- WHICH PIGGY SKIN THIS NEIGHBOUR WEARS, drawn once when they are
	-- seated and kept for as long as they stand. See `drawSkin` for why a
	-- resident wears one at all -- the short version is that the Victim
	-- Shelf collects skins ROBBED, and a street of identical default pigs
	-- would make it a two-player feature on a game whose whole resident
	-- system exists to stop those.
	skin: string,
	-- WHAT IS STANDING ON THEIR SIX PLINTHS, in exactly the shape a player's
	-- save carries it: `{ owned = {...}, slots = {...} }`.
	--
	-- DUCK-TYPED ON PURPOSE. `Config.piggySlots`, `addPiggy`, `removePiggy`
	-- and `placePiggy` take a table with a `piggies` field and nothing else,
	-- so a Resident answers all four exactly as a save does -- which is what
	-- lets ONE snatch path serve both kinds of lawn instead of two that can
	-- drift. Same call this file already makes when it reads
	-- `Config.getIncomeRate` for a neighbour rather than inventing a parallel
	-- curve.
	--
	-- `any` rather than a written-out type, because the shape belongs to
	-- `Config` and a second declaration of it here is a second thing to keep
	-- in step with the save format.
	piggies: any,
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
	--   "roam"     pottering about that same lawn, waiting to stand again
	--   "out"      walking to somebody else's piggy bank
	--   "cracking" standing at it, taking their time
	--   "carrying" walking home with the loot
	--   "collecting" walking to one of their OWN pads to bank its buffer
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
	-- THE POSE CACHE (2026-09-23). What the last `poseWalk` was given, so a
	-- neighbour standing still in ANY state -- cracking for six seconds,
	-- waiting at a door -- is not re-posed forty-six parts a frame to say
	-- nothing moved. The model is part of the key: a rebuilt figure has to
	-- be posed once whatever the numbers say.
	posedModel: Model?,
	posedAt: Vector3?,
	posedFacing: Vector3?,
	posedStride: number?,
	posedCarry: boolean?,
	-- The state last written to `Config.RESIDENT_STATE_ATTRIBUTE`.
	publishedState: string?,
	route: { Vector3 },
	-- The plot index they are working, so a victim who moves house or logs
	-- off cannot leave a dangling reference to a plot table.
	markIndex: number?,
	loot: number,
	lootModel: Model?,
	-- A SNATCHED PIGGY IN THEIR ARMS, which is the OTHER thing a neighbour can
	-- be carrying home. `key` is the piggy and `slot` is the plinth it came
	-- off -- so a nab puts it back WHERE IT WAS, the rule the haul service's
	-- own record keeps -- and whose it was is `markIndex`. Nil with empty
	-- arms. `loot` and this are never both set, because a trip is one job;
	-- `carrying` is the one question that covers both.
	haul: { key: string, slot: number }?,
	-- WHICH JOB THIS TRIP IS, "crack" or "snatch", and for a snatch the
	-- victim's plinth. Chosen in `beginTrip`, read in `finishCrack`, cleared
	-- in `goHome`.
	job: string?,
	markSlot: number?,
	-- THE PLINTH OF THEIR OWN they are walking to bank. See `beginCollect`.
	collectSlot: number?,
	-- os.clock() stamps.
	nextTrip: number,
	-- When they may next stroll. A SECOND CLOCK AND NOT A SHORTER `nextTrip`:
	-- going out and pottering about are different events with different
	-- cadences, and one field carrying both is the `busyUntil`/`napUntil` bug
	-- this project already records -- two readers disagreeing about one
	-- number in opposite directions.
	nextRoam: number,
	waitUntil: number,
	-- When this neighbour may next say something, and when the line they are
	-- saying now comes down. `quietAt` is 0 when nothing is up, which is what
	-- makes taking a line down a single comparison in every state rather than
	-- a flag that has to be cleared on four different exits.
	nextLine: number,
	quietAt: number,

	-- WHAT A GADGET IS DOING TO THEM, and it is the SAME set of effects a
	-- player takes (see `ResidentService.applyGadget`). All os.clock() stamps,
	-- all optional so a freshly seated neighbour carries none.
	--   fxSlow / fxSlowUntil   a speed multiplier and when it wears off
	--   fxStunUntil            frozen in place -- no walk, no crack, no catch
	--   fxKnockUntil/fxKnockAxis  lying flat, tipped about this axis
	--   fxRestUntil            when an empty-handed neighbour may be hit again
	fxSlow: number?,
	fxSlowUntil: number?,
	fxStunUntil: number?,
	fxKnockUntil: number?,
	fxKnockAxis: Vector3?,
	fxRestUntil: number?,
}

local ResidentService = {}

-- Keyed by plot INDEX rather than by the plot table, so a resident survives
-- anything that rebuilds the plot model underneath it.
local residents: { [number]: Resident } = {}

-- ANYTHING IN THEIR ARMS: a bag of somebody's coins OR somebody's piggy.
--
-- Asked in one place because it is asked in seven -- the pose, the two gadget
-- target searches, the gadget rest, the eviction refund and the nab -- and
-- every one of them used to read `loot > 0`, which was the whole truth while
-- coins were the only thing a neighbour ever carried home. A snatched piggy
-- is loot of 0 in the arms of somebody who is plainly carrying, and a reader
-- left on the old test is a thief a gadget cannot find, walking with its
-- arms at its sides.
local function carrying(resident: Resident): boolean
	return resident.loot > 0 or resident.haul ~= nil
end

-- THE COLLECTION STANDING ON A PLOT, whoever lives there: a player's save or
-- a neighbour's record, both of which answer `Config.piggySlots` identically
-- (see the note on `Resident.piggies`). Nil for a plot mid-handover.
local function collectionOf(plot: PlotService.Plot): any?
	if plot.owner then
		return DataService.get(plot.owner :: Player)
	end
	return residents[plot.index]
end

-- The plot a trip was aimed at, looked up by INDEX at the moment it is needed
-- rather than held: a victim who moves house or logs off must not leave a
-- dangling reference to a plot table.
local function plotByIndex(index: number?): PlotService.Plot?
	if index == nil then
		return nil
	end
	for _, plot in ipairs(PlotService.getAll()) do
		if plot.index == index then
			return plot
		end
	end
	return nil
end

-- ------------------------------------------------------------
-- THE TWO DIALS THIS FILE READS THROUGH A FALLBACK
-- ------------------------------------------------------------
--
-- `Config.RESIDENTS.snatch` and `Config.RESIDENTS.collect` are read through
-- these so the server boots identically before and after the Config rows
-- land: a missing table answers the defaults below, and the defaults ARE the
-- proposed rows. Nothing else in this file may carry a number of its own for
-- either -- see `chooseJob` and `ripestPad` for what each means.
local SNATCH_DEFAULTS = { playerWeight = 0.35, residentWeight = 0.08 }
local COLLECT_DEFAULTS = { fullness = 0.75 }

local function snatchSpec(): any
	return Config.RESIDENTS.snatch or SNATCH_DEFAULTS
end

local function collectSpec(): any
	return Config.RESIDENTS.collect or COLLECT_DEFAULTS
end

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

-- HOW WELL DEFENDED THIS HOUSE IS, AND IT DOES NOT ASK WHAT THE PLAYER HAS.
--
-- This is the whole of the lockstep fix. `pickOffset` above is a rung
-- BELOW the street and is re-read on every tick, so the row rises together
-- whenever anybody buys an income level -- correct for a pig, and what made
-- a player with no fence meet a row of neighbours with no fence. A look is
-- drawn from a fixed band instead, so the street has moats and bare plots
-- on it at minute one and still does at rebirth ten.
--
-- THE BAND SPANS EVERY DEFENCE LADDER EXACTLY ONCE (`residentStyleMax`), so
-- there is nothing above it to reach: a uniform draw across it is a uniform
-- draw across fence tiers and lock tiers, which is what reads as a street
-- of different houses rather than a ladder somebody typed.
--
-- THE TWO GUARANTEES ARE COUNTED AGAINST WHAT IS ACTUALLY STANDING rather
-- than dealt from a bag, for the reason `pickOffset` gives: residents are
-- seated ONE AT A TIME as plots free up, so there is no moment at which
-- "how many are there" has an answer.
local function pickStyle(): number
	local top = math.max(0, math.floor(Config.residentStyleMax()))
	if top == 0 then
		return 0
	end
	local style = Config.RESIDENTS.style

	local easy, hard = 0, 0
	for _, other in pairs(residents) do
		if other.styleLevel <= 0 then
			easy += 1
		end
		if other.styleLevel >= top then
			hard += 1
		end
	end

	-- THE BOTTOM FIRST, because that is the guarantee a player with base
	-- stats depends on: no Lockpicks, no bones, no Sneak, and somewhere to
	-- go anyway. Without it a random street can seat every house near the
	-- top, which is "defence buys time, never immunity" broken by a dice
	-- roll instead of by a purchase.
	if easy < style.easyCount then
		return 0
	end

	-- THEN THE TOP, because a ladder with no top is not a ladder -- and
	-- because the best-defended house is what the risk half of the decision
	-- is measured against. The income ladder pins its own for the same
	-- reason and records what its absence cost.
	if hard < style.topCount then
		return top
	end

	return math.random(0, top)
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

-- HOW BIG A RESIDENT'S PIG IS: a fixed number of SECONDS of its own income.
--
-- THIS USED TO READ "never a share of `Config.getCapacity`" AND THAT
-- FUNCTION NO LONGER EXISTS. The pig is UNBOUNDED (designer, 2026-09-21):
-- `getCapacity`, `getCapacityCost`, `pigRoom`, `fitInPig`, `BASE_CAPACITY`,
-- `UPGRADE_COST_CEILING` and `REBIRTH_CAPACITY_MULTIPLE` are all gone, and
-- the Bigger Piggy Bank tree went with them. So the thing this rule was
-- written to refuse cannot be reached any more.
--
-- THE RULE OUTLIVED ITS OWN REASON AND IS KEPT, which is worth a line
-- because the tempting reading is that it is now moot. It is not: a
-- resident's pig still has to be sized by SOMETHING, `pigSeconds` is
-- still what makes the robbing-versus-idling ratio constant across every
-- level and rebirth (`auditRobbery`'s `spread` check measures exactly
-- that), and the failure it records below is what happens whenever a
-- resident's worth is hung on a curve chosen for a different job. The
-- next curve somebody reaches for will not be called `getCapacity`.
--
-- The paragraphs below are the original post-mortem and are left in the
-- past tense they were written in.
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

-- THE PATCH OF LAWN A NEIGHBOUR LIVES ON, in plot-local studs: where they
-- stand, and the box they may potter about inside.
--
-- Behind the piggy and in front of the house. The piggy holds the centre at
-- 0, the walk from the gate takes the whole middle of the plot in FRONT of
-- it -- plot-local +Z is the street on both rows -- and the front door and
-- its doorstep crate hold the x 0 column, so this is off to one side and out
-- of everybody's way.
--
-- IT WAS z -20 AGAINST A HOUSE WALL AT -18, SO EVERY NEIGHBOUR ON THE STREET
-- HAD BEEN STANDING TWO STUDS INSIDE THEIR OWN FRONT ROOM. The comment this
-- replaces said "the house front line is at -28", which is what it was until
-- the map came in and `HOUSE_FRONT_LINE` went 28 -> 18 in separate work. A
-- number solved against a measurement that then moved, with nothing erroring
-- because a house does not collide and a figure standing in one throws
-- nothing -- the same failure as the grove that planted full-grown trees on
-- people's lawns the day `YARD_DEPTH` stopped being what it had been, and
-- the reason `HOUSE_FRONT_LINE`'s own note ends by saying anything solved
-- against it has to be re-derived with it.
--
-- THE BACK EDGE IS DERIVED FROM THE WALL RATHER THAN TYPED, so it follows
-- the house: the doorstep crate sinks 0.27 into the wall and its front face
-- reaches `HOUSE_FRONT_LINE - 3.37`, and five studs clears that by 1.63 --
-- enough that a neighbour stands in front of their own crate rather than in
-- it. The front edge stops well short of the piggy, because a neighbour
-- planted beside it is standing in the one spot a thief has to reach, which
-- is a defence nobody bought -- the same argument that gave a returning
-- neighbour a second leg away from their own pig after banking.
--
-- THE SIDES ARE THE ORNAMENT COLUMN. Every lawn slot's x offset is -25 or
-- 25 and the widest ornament in the catalogue measures 13.70, so one
-- standing in the near column reaches x 18.15. 18 is under that, and 9 keeps
-- clear of a piggy bank 12 studs across. (`Config.DECOR_ITEMS` is empty
-- today, so nothing can actually stand there -- deriving against an empty
-- catalogue is the stale-measurement trap running backwards, and this file
-- already refuses it once over `YARD_DEPTH`.)
local ROAM_MIN = Vector3.new(9, 0, -Config.HOUSE_FRONT_LINE + 5)
local ROAM_MAX = Vector3.new(18, 0, -3)

-- The middle of that box, so a stroll is symmetric about where they stand
-- rather than always heading the same way out of a corner.
local STAND_AT = Vector3.new(
	(ROAM_MIN.X + ROAM_MAX.X) / 2, 0, (ROAM_MIN.Z + ROAM_MAX.Z) / 2)

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
-- THE FOUR LADDERS A NEIGHBOUR WEARS, off the STYLE level and never the
-- income one. Split out of `applyLevel` so it can be skipped: since the
-- split a style level never changes after `seat`, and running this on an
-- income tick would tear down and rebuild a fence and a house on every
-- empty plot on the street to arrive at exactly the geometry already
-- standing. `tick`'s own comment calls that a rebuild storm nobody asked
-- for, and before the split it was at least doing real work.
local function applyStyle(resident: Resident)
	local plot = resident.plot
	local level = resident.styleLevel
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

	-- The same dog every real plot has: the Guard rung is retired, so a
	-- neighbour's dog no longer laddered with the street either. See
	-- `Config.DOG_LEVEL`.
	PlotService.setDogLevel(plot, Config.DOG_LEVEL)
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
end

-- WHAT A REPAINT OF THIS HOUSE MEANS, which is now two questions rather
-- than one: what it LOOKS like (rolled once, above) and what its pig is
-- worth (tracks the street, every tick).
local function applyLevel(resident: Resident)
	local plot = resident.plot

	-- ONLY WHEN IT ACTUALLY MOVES, which since the split is exactly once per
	-- house. See `styleShown`.
	if resident.styleShown ~= resident.styleLevel then
		resident.styleShown = resident.styleLevel
		applyStyle(resident)
	end

	-- A shop has no skin, no sign row and no plinths -- see `applyStyle` for
	-- the three calls it must not make and why.
	if plot.shop then
		return
	end

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

	-- AND THE SIX PLINTHS, THROUGH THE SAME DOOR A PLAYER'S GO THROUGH.
	--
	-- Here rather than at `seat` for the reason the skin is: this is what runs
	-- whenever anything about this house is repainted, and a lawn dressed once
	-- at seat would be silently undone by anything that rebuilt the plot
	-- afterwards. It is idempotent on the key, so a repaint that changes
	-- nothing writes nothing.
	--
	-- `setHaul` inside it is what actually lights the snatch prompts: a
	-- resident's plot publishes owner 0, which refuses the TAKE and PLACE
	-- prompts on every screen in the game and refuses the SNATCH on none.
	PlotService.setPiggySlots(plot, resident)
	PlotService.setPiggyBuffers(plot, resident)
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

-- ============================================================
-- WHAT A NEIGHBOUR KEEPS ON THEIR PLINTHS
-- ============================================================
--
-- SIXTY EMPTY PEDESTALS WAS AN ACQUISITION ROUTE WITH NOTHING ON IT.
-- `docs/PIGGY-PACKS-PLAN.md` §10e promoted this from a solo-pacing dial to
-- THE supply question the day stealing became a primary way to collect: on a
-- quiet server the only lawns to steal from are residents'.
--
-- THE TWO PROPERTIES §10e REQUIRES ARE BOTH HERE AND NEITHER IS OPTIONAL.
--
-- It is drawn against the SAME catalogue and the same exclusions every other
-- roll in this game uses, so a neighbour's lawn can never become a second
-- economy that drifts from the real one. And it is CAPPED rather than scaled:
-- `RESIDENTS.piggyTopRarity` does not move with the street, because the
-- residents' own level offset is downward-only on the rule that "residents
-- richer than the thief are a faucet, full stop" -- and a lawn that seeded
-- legendaries because the street happened to be rich is that faucet one level
-- up, with no audit in existence that would catch it.
--
-- A BAG RATHER THAN A ROLL PER PLINTH, the same pattern `drawSkin` and the
-- music cues take: it spreads the catalogue across the street instead of
-- letting one key come up three times on one lawn, which is what makes the
-- row read as ten different collectors rather than as one generator.
--
-- IT REFILLS, unlike `skinBag`, and that difference is deliberate. A skin is
-- one per neighbour and sharing one would make two houses read as the same
-- house; a piggy is one of six on each of ten lawns, and duplicates across
-- the street are honest -- duplicates STACK in this collection, so seeing the
-- same one twice is a real thing a player can act on.
local lawnBag: { string } = {}

local function drawLawnPiggy(): string?
	if #lawnBag == 0 then
		local cap = Config.rarityRank(Config.RESIDENTS.piggyTopRarity)
		for key, spec in pairs(Config.SKINS) do
			-- THE SAME TWO EXCLUSIONS THE PIG ITSELF TAKES, and for the same
			-- reasons: an earned-elsewhere skin on scenery advertises a paid
			-- exclusive or an event reward nobody attended anything for, and
			-- an aura is not colour on a body -- it is particles thrown off
			-- one, which is the "variety that LIES" failure this project
			-- records for gardens advertising wealth that is not there.
			--
			-- AND ONE MORE THAT IS THIS FUNCTION'S OWN: the rarity cap. See
			-- the header.
			if not Config.isEarnedElsewhere(spec) and spec.aura == nil
				and Config.rarityRank(Config.rarityOf(spec)) <= cap then
				table.insert(lawnBag, key)
			end
		end
		-- Sorted before the shuffle for `drawSkin`'s own reason: a bag built
		-- from whatever order `pairs` happened to walk makes a bad draw a
		-- ghost rather than something anybody can reproduce.
		table.sort(lawnBag)
		for i = #lawnBag, 2, -1 do
			local j = math.random(i)
			lawnBag[i], lawnBag[j] = lawnBag[j], lawnBag[i]
		end
	end
	if #lawnBag == 0 then
		return nil
	end
	return table.remove(lawnBag) :: string
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
	-- Drawn here, before the record exists, so the two guarantees inside it
	-- count the houses already standing and not this one.
	local style = pickStyle()
	local garden = rollGarden()
	local level = math.max(Config.RESIDENTS.minLevel, currentLevel() + offset)
	local capacity = pigSize(level, plot)

	local resident: Resident = {
		plot = plot,
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
		-- What the house LOOKS like, which no longer follows the street. See
		-- `Config.RESIDENTS.style`.
		styleLevel = style,
		-- DRAWN FOR EVERY PLOT INCLUDING A SHOP, so the field is never nil
		-- and a reader never has to ask which kind of plot it is holding. What
		-- a shop does with it is nothing -- `applyLevel` returns before the
		-- skin is applied, because a shop counter is a shop counter.
		skin = drawSkin(),
		-- SEEDED HERE AND NEVER REFILLED, which is the half of the supply
		-- decision that keeps it from being a faucet. A snatched piggy leaves
		-- this lawn for good, so a server's neighbour stock is FINITE and
		-- visibly runs down as the street is picked over -- which is also the
		-- honest reading: `seat` runs whenever a plot frees up, so a
		-- neighbour genuinely is a new occupant with a new collection, and
		-- one who has been robbed is one who has less.
		piggies = { owned = {}, till = Config.DEFAULT_SKIN, slots = {} },
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
		-- Staggered for the same reason and against its own, much shorter
		-- ceiling: ten neighbours seeded on one clock all shuffle in the same
		-- frame, which reads as a mechanism rather than as ten people.
		nextRoam = os.clock() + math.random() * Config.RESIDENTS.walk.roam.restMax,
		waitUntil = 0,
		-- Staggered for the same reason `nextTrip` is: eight neighbours seeded
		-- on one clock speak in chorus, which reads as a mechanism rather than
		-- as people.
		nextLine = os.clock() + math.random() * Config.RESIDENT_CHATTER.maxGap,
		quietAt = 0,
	}

	-- FRONT TO BACK THROUGH `Config.addPiggy`, which is the one door every
	-- source of a piggy in this game goes through -- a crate reveal, an admin
	-- grant, a delivered snatch and now a neighbour moving in. It bumps the
	-- count and takes the slot in one breath, which is what stops `owned` and
	-- what is STANDING from ever disagreeing.
	--
	-- A SHOP GETS NONE, because a shop has no pedestals: `PlotService` builds
	-- the six on residential plots only, and seeding a collection onto a
	-- counter would be ownership with nowhere to stand.
	if not plot.shop then
		for _ = 1, Config.RESIDENTS.piggyCount do
			local key = drawLawnPiggy()
			if key == nil then
				break
			end
			Config.addPiggy(resident, key :: string, true)
		end
	end

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
	if carrying(resident) then
		ResidentService.nabbed(resident)
	end
	if resident.model then
		resident.model:Destroy()
	end
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
-- Treat -- protects against other players, so in a solo
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
-- WHICH DEFENCE THIS RESIDENT IS, and the two are not the same object.
--
-- A SHOP has one defence and a twelve-stud room, so its keeper runs the
-- officer's 14.5 and CATCHES. A HOUSE already has a tier-2 Shepherd that
-- chases, catches, nabs and knocks a thief out of the yard -- so its neighbour
-- is a RELAY rather than a second defence: it picks the thief up where the
-- dog's own leash makes it stop, runs slower than a carrying thief so the gap
-- opens as they run, and throws instead of catching.
-- `Config.NEIGHBOUR_CHASE` carries the whole argument.
--
-- Declared above `baseSpeed` because that is its first reader -- the forward
-- reference this project has been bitten by eleven times.
local function chaseSpec(resident: Resident): any
	return if resident.plot.shop then Config.SHOPKEEPER else Config.NEIGHBOUR_CHASE
end

local function baseSpeed(resident: Resident): number
	-- A CHASING RESIDENT IS THE ONE THAT IS NOT STROLLING. A shopkeeper takes
	-- the officer's own 14.5, which sits between a carrying thief's 12 and a
	-- free player's 16, so the loot is what makes you catchable. A neighbour
	-- takes 11 and is meant to fall behind.
	if resident.state == "chasing" then
		return chaseSpec(resident).speed
	end
	local walk = Config.RESIDENTS.walk
	if resident.state == "carrying" then
		return walk.carrySpeed
	elseif resident.state == "roam" then
		return walk.roam.speed
	end
	return walk.speed
end

-- The speed they actually walk at: the base, under whatever a gadget is
-- doing to them. A multiplier on the one number, exactly as `currentSpeed`
-- is for a player, so a slowed shopkeeper chases slower and a slowed thief
-- carries slower with nothing else to know.
local function walkSpeed(resident: Resident): number
	local now = os.clock()
	if now < (resident.fxStunUntil or 0) then
		return 0
	end
	local slow = if now < (resident.fxSlowUntil or 0) then (resident.fxSlow or 1) else 1
	return baseSpeed(resident) * slow
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

-- WHERE A NEIGHBOUR STANDS TO COLLECT FROM, OR SNATCH OFF, A PLINTH: on its
-- pad, at lawn height. The pad is the part a player crosses to bank the same
-- buffer, so a neighbour walking to it reads as doing the thing a player does
-- -- and it is read off the BUILT PART rather than off `PIGGY_LAWN_SLOTS`,
-- for the reason the route is walked from real plot frames: the part knows
-- its own position on both rows, with nothing to flip. Nil on a plot with no
-- pedestals, which is a shop.
local function padAt(plot: PlotService.Plot, slot: number): Vector3?
	local pedestal = plot.pedestals and plot.pedestals[slot]
	if not pedestal then
		return nil
	end
	local p = pedestal.pad.Position
	return Vector3.new(p.X, lawnY(plot), p.Z)
end

-- WHAT ONE OF A NEIGHBOUR'S PLINTHS EARNS AND HOLDS, WHICH IS THE PLAYER'S
-- OWN ARITHMETIC AND NOT A SECOND COPY OF IT.
--
-- `EconomyService.slotRate` is `Config.getPiggyIncomeRate` at the owner's
-- level, times a friend bonus and a daily boost; `slotCeiling` is that rate
-- times `Config.piggyBufferSeconds` of the tier. A neighbour has neither
-- multiplier -- prestige and friends are things a PLAYER has, the same line
-- the coin accrual in `tick` already draws -- so its rate is the plain one
-- and its cap is the same product. Two numbers, both derived from the two
-- Config functions the player's loop reads, so a tier that gets a longer
-- buffer gets it on every lawn on the street.
--
-- AND THE RATE HALF IS `Config`'S NOW (2026-09-23). The literal 0 that used
-- to be passed for rebirths lives inside `Config.piggySlotRate` as
-- `rebirths or 0`, which is the same statement -- a neighbour has no
-- prestige -- made once for all three readers instead of here, in
-- `EconomyService` and nowhere at all in `PlotService`. That third gap is
-- what printed a name with no figure under it on every resident plinth in
-- the game until somebody looked at one.
--
-- THE KEY TEST STAYS EXPLICIT rather than reading an empty plinth off a
-- zero rate. They agree today and they agree for a reason that is not
-- load-bearing -- no tier multiplier is 0 and no income level pays nothing
-- -- so a rate of 0 meaning "empty" is an inference this function does not
-- need to make and should not start depending on.
--
-- Returns rate then ceiling; both 0 on an empty plinth.
local function slotEconomy(resident: Resident, slot: number): (number, number)
	if Config.piggyKeyAt(resident, slot) == nil then
		return 0, 0
	end
	local rate = Config.piggySlotRate(resident, slot)
	return rate, rate * Config.piggyBufferSeconds(Config.piggyRarityAt(resident, slot))
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

-- WHERE A NEIGHBOUR POTTERS TO, in world space.
--
-- A point drawn in the disc of `walk.roam.radius` around the stand spot and
-- then CLAMPED into `ROAM_MIN`..`ROAM_MAX`, rather than drawn inside the box
-- directly. The disc is what keeps a short move short; the box is the hard
-- guarantee that no radius anybody types later can put a neighbour inside
-- their own house, their own piggy bank or the walk up from their own gate.
-- Two jobs, and a single rectangle would do the second one and not the
-- first.
--
-- The distance is `sqrt` of a uniform draw, which is what spreads points
-- evenly over a disc -- a raw uniform distance bunches them near the middle,
-- and a neighbour shuffling back to almost the same spot every time reads as
-- a twitch rather than as somebody moving about.
local function roamTarget(resident: Resident): Vector3
	local roam = Config.RESIDENTS.walk.roam
	local angle = math.random() * math.pi * 2
	local dist = roam.radius * math.sqrt(math.random())
	local x = math.clamp(STAND_AT.X + math.cos(angle) * dist, ROAM_MIN.X, ROAM_MAX.X)
	local z = math.clamp(STAND_AT.Z + math.sin(angle) * dist, ROAM_MIN.Z, ROAM_MAX.Z)
	local p = (resident.plot.cframe * CFrame.new(x, 0, z)).Position
	return Vector3.new(p.X, lawnY(resident.plot), p.Z)
end

-- ============================================================
-- COLLECTING THEIR OWN PADS
-- ============================================================
--
-- A NEIGHBOUR'S PLINTHS FILLED NOTHING AND NOBODY EMPTIED THEM. The economy
-- loop accrues buffers for PLAYERS (`EconomyService.start`) and residents are
-- not in that list, so `resident.piggies.slots[i].buffer` sat at zero from
-- the day the plinths were seeded, and `setPiggyBuffers` dutifully painted
-- six empty pads on every neighbour's lawn. The street had six piggies a
-- house and none of them were playing the game. `tick` fills them now
-- (through `slotEconomy`) and this is the half that empties them.

-- THE PLINTH WORTH WALKING TO: the fullest one at or over
-- `collect.fullness` of its OWN cap, or nil when none is.
--
-- FULLNESS IS A SHARE OF THE SLOT'S CEILING, never a coin figure and never a
-- share of the pig -- the denominator `Config.piggyCollectPitch` settled on
-- for the same object, and for the same measured reason: a share of the cap
-- spans 0..1 on every tier, where a coin figure saturates on the best piggy
-- and reads as nothing on the worst. The threshold is the one new number
-- (`COLLECT_DEFAULTS.fullness`): a player laps on the commons' hundred
-- seconds and collects everything before anything is full, so a neighbour
-- who waited for FULL would be the one collector on the street who is always
-- late, and one who went at every coin would never stand still.
local function ripestPad(resident: Resident): number?
	local best, bestShare = nil, collectSpec().fullness
	local slots = Config.piggySlots(resident)
	for i = 1, Config.PIGGY_LAWN_SLOT_COUNT do
		local _, ceiling = slotEconomy(resident, i)
		if ceiling > 0 then
			local share = (slots[i].buffer or 0) / ceiling
			if share >= bestShare and padAt(resident.plot, i) then
				best, bestShare = i, share
			end
		end
	end
	return best
end

-- WALKING TO ONE OF THEIR OWN PADS: A STATE OF ITS OWN, "collecting", for the
-- reason `returning` is one. `roam` is a potter with a random target that
-- ends by standing; this is an errand with a destination that ends by
-- BANKING, and sharing the state would mean a flag beside it saying which
-- kind of stroll just ended -- a second piece of state that can disagree
-- with the first.
--
-- IT IS IN (`isIn`): a neighbour collecting on their own lawn is home for
-- every question anybody asks -- alertable by a robbery behind them, not
-- away, and not counted against `walk.maxOut`.
local function beginCollect(resident: Resident, slot: number): boolean
	local at = padAt(resident.plot, slot)
	if not at then
		return false
	end
	resident.state = "collecting"
	resident.collectSlot = slot
	resident.route = { at }
	return true
end

-- AT THE PAD. The buffer goes into the neighbour's own pig, which is the one
-- place a resident's coins live and the pig a thief can come and take them
-- back out of -- so a neighbour's lawn income is robbable exactly as a
-- player's is once collected, and sits on the pad where nobody can take it
-- until then, which is the shape a player's has.
--
-- CLAMPED TO THE PIG, AS `bankLoot` IS. A resident's pig is bounded
-- (`pigSeconds` of its own income is the supply the robbery audit prices),
-- so a collect fills the room there is and the rest is gone: "spend it or
-- lose it", on a neighbour who never spends.
--
-- THE PAD FIRES AS IT DOES FOR A PLAYER -- `PlotService.playCollect` is the
-- sound at the pad and the reaction window on its face -- so from the
-- pavement a neighbour collecting looks and sounds like anybody collecting.
local function finishCollect(resident: Resident)
	local slot = resident.collectSlot
	resident.collectSlot = nil
	if slot then
		local entry = Config.piggySlots(resident)[slot]
		local held = (entry and entry.buffer) or 0
		if held > 0 then
			local _, ceiling = slotEconomy(resident, slot)
			entry.buffer = 0
			local capacity = pigSize(resident.capacityLevel, resident.plot)
			resident.coins = math.min(capacity, resident.coins + held)
			PlotService.updatePile(resident.plot, resident.coins, capacity)
			PlotService.playCollect(resident.plot, slot,
				if ceiling > 0 then held / ceiling else 0)
			PlotService.setPiggyBuffers(resident.plot, resident)
		end
	end
	-- THEN BACK INTO THE GARDEN, AS A STROLL. The pads stand in the ornament
	-- column outside the roam box, and a neighbour planted on one until the
	-- next potter would be standing where they never otherwise stand. `roam`
	-- ends by standing and touches no trip clock, which is what a collect
	-- must not do -- an errand on the lawn is not a rest between trips.
	resident.state = "roam"
	resident.route = { roamTarget(resident) }
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

-- IN, WHICH IS TWO STATES RATHER THAN ONE. A neighbour pottering about their
-- own garden is at home in every sense that anything asks about: they can be
-- alerted by a robbery on their own lawn, their tree still gets harvested,
-- and they are not away from home robbing anybody. Asked in one place because
-- the alternative is `state == "home" or state == "roam"` written at four
-- call sites and the fifth one added later being the bug -- silently, because
-- every one of those failures is a neighbour who simply does nothing.
--
-- COLLECTING IS IN TOO. An errand to one of your own pads is done on your own
-- lawn, and a neighbour who could not be alerted, or who counted as away,
-- for the four seconds it takes to cross to a plinth is the intermittent
-- failure the roam entry above already refuses.
local function isIn(resident: Resident): boolean
	return resident.state == "home" or resident.state == "roam"
		or resident.state == "collecting"
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
		-- A DEFENDER IS NOT AN ERRAND, and counting one as an errand costs the
		-- whole street. `walk.maxOut` is 2 and limits how many neighbours are
		-- away from home ROBBING at once; a resident chasing a thief off their
		-- own lawn, or walking back from one, is not out shopping. Counted,
		-- two simultaneous chases freeze every NPC robbery on the street until
		-- both of them finish.
		if not (isIn(r) or r.state == "chasing" or r.state == "returning") then
			n += 1
		end
	end
	return n
end

-- HOW MANY ARE MOVING AT ALL, for `RESIDENTS.walk.maxMoving`. Every state
-- but home and chasing: a trip, a potter, a collect, a crack, a carry and
-- the walk back are all a figure being posed every frame. A chase is a
-- defence and is exempt, for the reason `outCount` gives -- counting it
-- would let two thieves freeze the whole street's NPC life.
local function movingCount(): number
	local n = 0
	for _, r in pairs(residents) do
		if r.state ~= "home" and r.state ~= "chasing" then
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

-- AND THE PIGGY SNATCH, THROUGH THE SERVICE THAT OWNS IT. `PiggyHaulService`
-- requires this file, so asking it directly is a cycle; `Main` fills these
-- in with `PiggyHaulService.residentSnatch` and `.residentReturn`, the same
-- shape as the four registries above.
--
-- WHAT THAT BUYS IS THAT A NEIGHBOUR'S SNATCH IS A PLAYER'S SNATCH. The
-- per-victim cooldown, the shield, the slot emptying, the repaint, the
-- victim's alarm and the return on a nab all run in the one file that runs
-- them for a person -- a second copy here would be the near-identical
-- duplicate this project keeps recording, and this one drifts into taking a
-- child's piggy past a rule nobody is testing.
--
-- `snatchFrom` answers the piggy's KEY, or nil when the lawn refused (on
-- cooldown, shielded, empty). `giveBackPiggy` is the nab's other half.
local snatchFrom: ((Resident, PlotService.Plot, number) -> string?)? = nil
local giveBackPiggy: ((PlotService.Plot, string, number) -> ())? = nil

function ResidentService.registerSnatch(fn: (Resident, PlotService.Plot, number) -> string?)
	snatchFrom = fn
end

function ResidentService.registerPiggyReturn(fn: (PlotService.Plot, string, number) -> ())
	giveBackPiggy = fn
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

-- AND THE NAB EFFECT, THE OTHER WAY ROUND: a player nabbing a neighbour.
-- Filled in by `Main` with `CosmeticsService.fireCatchEffect`, a registry for
-- the same reason as the rest -- this file sits under half the services.
local catchEffect: ((Model?, Player) -> ())? = nil

function ResidentService.registerCatchEffect(fn: (Model?, Player) -> ())
	catchEffect = fn
end

function ResidentService.registerCatch(fn: (Resident, Player) -> ())
	catchThief = fn
end

-- THE THROW GOES OUT THROUGH A REGISTRY FOR THE SAME REASON THE CATCH DOES,
-- and it lands in `GadgetService` rather than here: that file owns every
-- flight in this game, the curve both ends step, and the remote the clients
-- draw one with. A second flight loop in this file would be the near-identical
-- copy that drifts the first time either is touched.
local throwAt: ((Resident, Player) -> ())? = nil

function ResidentService.registerThrow(fn: (Resident, Player) -> ())
	throwAt = fn
end

-- A SHOPKEEPER COMES OUT FROM BEHIND THE COUNTER.
--
-- Called from `releaseDog` when the plot has no dog to let off, which on a
-- shop is always -- see `Config.SHOPKEEPER` for what wakes them and why it is
-- only ever the loud paths.
-- A NEIGHBOUR COMES OUT AFTER THE DOG HAS HAD TO STOP.
--
-- The house counterpart of `alertShopkeeper`, and deliberately a SECOND named
-- entry rather than a boolean on the first: they read differently at the call
-- site and `releaseDog` reaches them on different branches for different
-- reasons. It refuses a shop, which mirrors the refusal below, so neither path
-- can quietly serve the other's ground.
function ResidentService.alertNeighbour(plot: PlotService.Plot, thief: Player): boolean
	local resident = ResidentService.get(plot)
	if not resident or plot.shop or not resident.model then
		return false
	end
	-- ALREADY BUSY IS ALREADY ANSWERED, the same rule the shopkeeper keeps: a
	-- neighbour out robbing somebody else does not abandon the trip to come
	-- home, and one already chasing is already chasing.
	--
	-- POTTERING IS NOT BUSY. A neighbour standing in their own garden who
	-- ignored somebody cracking the pig behind them would be the worst
	-- possible reading of a stroll -- and it would be intermittent, which is
	-- worse than never: the same alarm on the same lawn would work or not
	-- depending on whether they happened to be mid-step.
	if not isIn(resident) then
		return false
	end
	local spec = Config.NEIGHBOUR_CHASE
	resident.state = "chasing"
	resident.chasing = thief
	local now = os.clock()
	resident.chaseFrom = now + spec.noticeDelay
	resident.chaseUntil = resident.chaseFrom + spec.maxChase
	-- The first throw waits out the notice beat too, so nothing is in the air
	-- before the `!` has had time to be read.
	resident.nextThrow = resident.chaseFrom + spec.throw.interval
	resident.route = {}
	-- THE `!`, AND IT IS THE SPEECH BUBBLE RATHER THAN A SECOND BILLBOARD.
	--
	-- A neighbour already has one on their head, with its own `MaxDistance` so
	-- a street of them is not a wall of text, and its own clock that takes it
	-- down. Building an alert badge beside it would be two billboards saying
	-- two things from one head, and a second thing to keep in step.
	--
	-- WHAT IT BUYS IS THE HALF A CLEAN CRACK COULD NOT HAVE. The alarm fires
	-- on a fumble and never on a clean robbery, and that stays true: nobody is
	-- TOLD, no notification goes out, no mark is put on anybody. What this adds
	-- is that the robbery is visible IN THE WORLD to whoever is looking -- the
	-- difference between stealth of the alarm and stealth of the getaway, which
	-- this game already draws.
	--
	-- It is also the BEAT. It goes up at the notice and the chase starts at
	-- `chaseFrom`, so a thief sees it and chooses whether to finish the crack
	-- or run -- rather than finding out afterwards what a dice roll decided.
	ResidentModel.say(resident.model, "!")
	resident.quietAt = resident.chaseFrom + 0.6
	return true
end

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
	if not isIn(resident) then
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
-- THE BUILDER BOTH KINDS OF CARRY SHARE. `skinKey` is what the miniature
-- wears: the victim's own pig for a bag of coins (`attachLoot`), the piggy
-- itself for a snatch (`attachHaul`). Returns the mini, or nil when nothing
-- could be built -- and sets no `loot` and no `haul`, because which of the
-- two this is belongs to the caller.
local function attachCarry(resident: Resident, victim: PlotService.Plot, skinKey: string): Model?
	local model = resident.model
	if not model then
		return nil
	end
	local torso = model:FindFirstChild("Tee", true)
	if not (torso and torso:IsA("BasePart")) then
		return nil
	end

	local ok, mini = pcall(PiggyModel.build, skinKey)
	if not ok or not mini then
		return nil
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
	-- ASKED FOR BY NAME RATHER THAN TAKEN AS "the first BasePart". A mini has
	-- no PrimaryPart on purpose (see `PiggyModel.bodyOf`), and the fallback
	-- here returned whichever part the builder happened to make first --
	-- which IS the body today, and is a coincidence rather than a contract.
	local body = PiggyModel.bodyOf(mini)
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
	resident.markIndex = victim.index
	return mini
end

local function attachLoot(resident: Resident, victim: PlotService.Plot, amount: number)
	-- THE MINIATURE MATCHES THE PIG IT CAME OUT OF, the same rule
	-- `HeistService.attachLoot` follows: the label on a thief's arms is a
	-- tell about WHOSE coins those are, and a resident carrying a default
	-- pink pig away from somebody's Bubblegum one is a tell that lies.
	local victimPlayer = victim.owner
	local victimData = if victimPlayer then DataService.get(victimPlayer) else nil
	local skinKey = if victimData then victimData.cosmetics.skin else Config.DEFAULT_SKIN
	if attachCarry(resident, victim, skinKey) then
		resident.loot = amount
	end
end

-- A SNATCHED PIGGY IN A NEIGHBOUR'S ARMS: the piggy ITSELF, with its name
-- over it -- the same picture `PiggyHaulService.attach` makes on a player
-- thief, down to the 1.8-stud offset, so a victim chasing either reads the
-- same tell. Returns whether it is in their arms; the caller puts the piggy
-- back if not, because the victim's slot has already emptied by then.
local function attachHaul(resident: Resident, victim: PlotService.Plot,
	key: string, slot: number): boolean
	local mini = attachCarry(resident, victim, key)
	if not mini then
		return false
	end
	local body = PiggyModel.bodyOf(mini)
	if body then
		local label = Instance.new("BillboardGui")
		label.Name = "HaulLabel"
		label.Size = UDim2.new(0, 200, 0, 40)
		label.StudsOffset = Vector3.new(0, 1.8, 0)
		label.AlwaysOnTop = true
		label.LightInfluence = 0
		label.Parent = body
		local text = Instance.new("TextLabel")
		text.Name = "What"
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Theme.FONT
		text.TextScaled = true
		text.TextColor3 = Theme.PAPER
		text.TextStrokeColor3 = Theme.INK
		text.TextStrokeTransparency = 0.1
		text.Text = Config.getSkin(key).name
		text.Parent = label
	end
	resident.haul = { key = key, slot = slot }
	return true
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
	resident.haul = nil
	resident.markIndex = nil
end

-- ============================================================
-- THE TRIP
-- ============================================================

-- When this neighbour may next potter, drawn fresh.
--
-- Called from BOTH ends -- a stroll finishing and a trip finishing -- because
-- somebody who has just walked the length of the street should stand for a
-- moment on arrival rather than setting off round the garden as they land.
local function restRoam(resident: Resident)
	local roam = Config.RESIDENTS.walk.roam
	resident.nextRoam = os.clock() + roam.restMin
		+ math.random() * math.max(0, roam.restMax - roam.restMin)
end

local function goHome(resident: Resident)
	resident.state = "home"
	resident.route = {}
	resident.job = nil
	resident.markSlot = nil
	resident.collectSlot = nil
	local walk = Config.RESIDENTS.walk
	resident.nextTrip = os.clock() + walk.restMin
		+ math.random() * math.max(0, walk.restMax - walk.restMin)
	restRoam(resident)
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

-- WHICH JOB A TRIP IS. Returns "snatch" and the victim's plinth, or "crack"
-- and nil.
--
-- A NEIGHBOUR PLAYS THE SAME GAME A PLAYER DOES, AND A PLAYER HAS TWO THINGS
-- TO TAKE OFF A LAWN: the bank's coins and a pedestal's piggy. A row of
-- neighbours who only ever cracked the pig was a street playing last month's
-- game -- and everything that defends a PIGGY (the fence, the dog, the run
-- home a victim can chase) protected against nothing on a solo server, which
-- is the argument that made residents rob at all.
--
-- WEIGHTED BY WHO THE VICTIM IS, AND THE TWO WEIGHTS ARE NOT ONE NUMBER FOR
-- A REASON. Against a PLAYER a snatch is the threat: their plinth goes bare,
-- they are told who, and the neighbour walks it home at `walk.carrySpeed`
-- past a player who does `BASE_WALK_SPEED` -- recoverable by doing the thing,
-- every time. Against a RESIDENT it is scenery: nobody is told and nobody
-- chases, so two neighbours trading piggies is the street's finite stock
-- going round in a circle and a real player's target list reshuffling for no
-- reason they can see. `residentWeight` is small enough that a collection
-- visibly drifts over a long session and no more; `playerWeight` is a third
-- of trips, because the crack is still the loop this file was built for.
--
-- A SNATCH NEEDS SOMETHING STANDING. A shop has no plinths and an emptied
-- lawn has nothing on them; both fall back to the crack rather than to a trip
-- that walks up a drive and finds nothing to do -- a neighbour standing at a
-- bare plinth for six seconds reads as broken. And with no snatch registered
-- (`Main` has not wired it) every trip is a crack, so the file boots and
-- behaves exactly as it did before this branch existed.
local function chooseJob(resident: Resident, victim: PlotService.Plot): (string, number?)
	if victim.shop or snatchFrom == nil then
		return "crack", nil
	end
	local spec = snatchSpec()
	local weight = if victim.owner then spec.playerWeight else spec.residentWeight
	if math.random() >= weight then
		return "crack", nil
	end
	local data = collectionOf(victim)
	if not data then
		return "crack", nil
	end
	-- A RANDOM STANDING PLINTH, never the best one, for `pickVictim`'s own
	-- reason: a neighbour does not case a lawn for the rarest piggy, because
	-- the one thing eight of them must not do is converge on one object.
	local standing = {}
	local slots = Config.piggySlots(data)
	for i = 1, Config.PIGGY_LAWN_SLOT_COUNT do
		if slots[i].key ~= nil and padAt(victim, i) then
			table.insert(standing, i)
		end
	end
	if #standing == 0 then
		return "crack", nil
	end
	return "snatch", standing[math.random(#standing)]
end

-- THE PLINTH THIS NEIGHBOUR WOULD STAND A NEW PIGGY ON: the first free one,
-- or -- on a full lawn -- the one holding the LOWEST-RARITY piggy, which is
-- the one a snatched piggy swaps out (designer intent: a neighbour's
-- collection changes over time rather than filling once and freezing). Ties
-- go to the front-most plinth. Nil with no pedestals at all.
local function placeSlot(resident: Resident): number?
	local free = Config.firstFreePiggySlot(resident)
	if free then
		return free
	end
	local worst, worstRank = nil, nil
	for i = 1, Config.PIGGY_LAWN_SLOT_COUNT do
		local rank = Config.rarityRank(Config.piggyRarityAt(resident, i))
		if worstRank == nil or rank < worstRank then
			worst, worstRank = i, rank
		end
	end
	return worst
end

-- HOME WITH SOMEBODY'S PIGGY. It goes on a plinth through `Config.addPiggy`,
-- the one door every source of a piggy in this game comes through, so
-- `owned` and what is STANDING cannot disagree. A full lawn swaps its
-- lowest-rarity piggy out first (`placeSlot`); the piggy that came off is
-- simply gone, which is the resident stock being finite scenery -- the same
-- "nothing is refunded" line every retirement here has taken.
local function placeHaul(resident: Resident)
	local haul = resident.haul
	if not haul then
		return
	end
	if Config.addPiggy(resident, haul.key, true) == nil then
		local slot = placeSlot(resident)
		if slot then
			Config.removePiggy(resident, slot)
			Config.placePiggy(resident, haul.key, slot)
		end
	end
	PlotService.setPiggySlots(resident.plot, resident)
	PlotService.setPiggyBuffers(resident.plot, resident)
	clearLoot(resident)
end

local function beginTrip(resident: Resident)
	local victim = pickVictim(resident)
	if not victim then
		goHome(resident)
		return
	end
	local job, slot = chooseJob(resident, victim)
	resident.state = "out"
	resident.job = job
	resident.markSlot = slot
	resident.markIndex = victim.index
	resident.route = routeTo(resident, victim)
	-- A SNATCH ENDS AT THE PLINTH RATHER THAN AT THE PIG: the last waypoint is
	-- swapped for the victim's pad, so the approach is the same walk up the
	-- same drive and only where they stop differs -- which is what a player
	-- doing either job looks like from the pavement.
	if job == "snatch" and slot then
		local at = padAt(victim, slot)
		if at then
			resident.route[#resident.route] = at
		end
	end
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
	if not victim then
		resident.state = "carrying"
		resident.route = routeTo(resident, resident.plot)
		return
	end

	if resident.job == "snatch" then
		-- THE PIGGY, THROUGH THE HAUL SERVICE'S OWN SNATCH (see
		-- `registerSnatch`). It answers nil when the lawn refused -- on
		-- cooldown, shielded, or emptied while they walked -- and a refusal
		-- is a walk home with nothing, the same ending a crack that found an
		-- empty pig gets.
		local slot = resident.markSlot
		local key = if slot and snatchFrom
			then (snatchFrom :: any)(resident, victim, slot) else nil
		if key and slot and not attachHaul(resident, victim, key, slot) then
			-- IT CAME OFF THE PLINTH AND COULD NOT BE PICKED UP. The victim's
			-- slot has already emptied, so it goes straight back rather than
			-- vanishing -- the same put-it-back a player's `snatch` does when
			-- its own attach fails, and the one line here that stops a
			-- missing figure deleting somebody's piggy with nothing in any
			-- log.
			if giveBackPiggy then
				(giveBackPiggy :: any)(victim, key, slot)
			end
		end
	elseif takeFrom then
		-- HOW MUCH THEY ASK FOR IS THE SAME SHARE A PLAYER'S CRACK TAKES, so a
		-- neighbour is never worse to be robbed by than a person. What comes
		-- back is what the cap and the pig actually allowed, which is why the
		-- answer is read rather than assumed.
		local want = math.floor(Config.RESIDENTS.walk.takeFraction
			* (victim.model:GetAttribute(Config.PLOT_VAULT_ATTRIBUTE) or 0))
		-- The name goes with it, because the victim's alert has to say WHO --
		-- an unattributed alarm is the thing a player cannot act on.
		local got = if want > 0 then (takeFrom :: any)(victim, want, resident.name) else 0
		if got > 0 then
			attachLoot(resident, victim, got)
		end
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
	-- A PIGGY GOES ON A PLINTH, NOT INTO THE PIG, so a haul's last leg ends
	-- at the pad of the plinth it will stand on (`placeSlot`, re-asked on
	-- arrival in case the lawn changed while they walked). The bank of coins
	-- keeps the pig for the reason above.
	if resident.haul then
		local slot = placeSlot(resident)
		local pad = if slot then padAt(home, slot) else nil
		if pad then
			resident.route[#resident.route] = pad
		end
	end
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
	local plot = plotByIndex(resident.markIndex)
	if resident.loot > 0 and plot and giveBackTo then
		(giveBackTo :: any)(plot, resident.loot)
	end
	-- THE PIGGY GOES BACK WHERE IT WAS, through the haul service's own
	-- return -- the ending a player thief's nab gives it -- so there is one
	-- place that knows what "you did not get away with it" means for a
	-- piggy, whoever was carrying it.
	local haul = resident.haul
	if haul and plot and giveBackPiggy then
		(giveBackPiggy :: any)(plot, haul.key, haul.slot)
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
	local haul = resident.haul
	if amount <= 0 and not haul then
		return 0
	end
	ResidentService.nabbed(resident)
	-- The nabber's nab effect goes off on the neighbour, as it would on a
	-- player thief. On a solo server this is the only nab there is.
	if catchEffect then
		catchEffect(resident.model, taker)
	end
	if haul then
		-- THE THANKS AND NOTHING ELSE, which is `PiggyHaulService.nab`'s own
		-- rule: a piggy is not fungible, and handing a bystander somebody's
		-- Pearl for pressing a button would make nabbing a better way to
		-- collect than stealing. It went home.
		Remotes.get("Notify"):FireClient(taker,
			("Nice nab! %s dropped %s."):format(
				resident.name, Config.getSkin(haul.key).name), "good")
		return 0
	end
	Remotes.get("Notify"):FireClient(taker,
		("Nice nab! You took %s back off %s."):format(
			Config.formatCoins(amount), resident.name), "good")
	return amount
end

-- WHERE A NEIGHBOUR'S BODY IS, as opposed to their feet. `at` is the ground
-- they stand on, and a thrown gadget flies at chest height, so measuring a
-- hit against the feet put every neighbour about three studs further away
-- than the same throw at a player. Half the figure's height, derived.
function ResidentService.bodyAt(resident: Resident): Vector3
	return resident.at + Vector3.new(0, 2.8, 0)
end

-- Whichever resident is carrying and closest, for the tag to find.
function ResidentService.nearestCarrier(from: Vector3, range: number): (Resident?, number)
	local best, bestDist = nil, range
	for _, r in pairs(residents) do
		if carrying(r) and r.model then
			local d = (ResidentService.bodyAt(r) - from).Magnitude
			if d <= bestDist then
				best, bestDist = r, d
			end
		end
	end
	return best, bestDist
end

-- ============================================================
-- GADGETS ON A NEIGHBOUR
-- ============================================================
--
-- A NEIGHBOUR TAKES A GADGET THE WAY A PLAYER DOES (designer direction,
-- September 17). It used to be that a carrying neighbour hit by a gadget
-- simply handed the coins back -- a tag at range -- and an empty-handed one
-- could not be hit at all, because a resident has no Humanoid and the whole
-- speed system a gadget is written in did not reach it. The effect now lives
-- here, on the resident record, and the walker reads it: slowed, frozen, or
-- knocked flat for exactly the numbers a player gets, and the loot stays in
-- their arms until somebody NABS it, which is also what a player thief has
-- to have done to them.
--
-- The REST is the same too: an empty-handed neighbour is left alone for
-- `Config.gadgetRest` after a hit, so a quiet street cannot be turned into a
-- row of neighbours frozen on a loop. A carrying one can be hit again as
-- fast as anybody can throw, as a carrying player can.

function ResidentService.canHit(resident: Resident): boolean
	return os.clock() >= (resident.fxRestUntil or 0)
end

-- The nearest neighbour holding NOTHING who is open to a gadget. Second
-- choice after a carrier, as a bystander player is.
function ResidentService.nearestIdle(from: Vector3, range: number): (Resident?, number)
	local best, bestDist = nil, range
	for _, r in pairs(residents) do
		if not carrying(r) and r.model and ResidentService.canHit(r) then
			local d = (ResidentService.bodyAt(r) - from).Magnitude
			if d <= bestDist then
				best, bestDist = r, d
			end
		end
	end
	return best, bestDist
end

-- Applies a gadget. Returns whether it landed. `from` is where it came from,
-- so a knockdown tips them away from whoever threw it.
function ResidentService.applyGadget(resident: Resident, spec: any, from: Vector3): boolean
	if not resident.model then
		return false
	end
	local now = os.clock()
	if not carrying(resident) then
		if not ResidentService.canHit(resident) then
			return false
		end
		resident.fxRestUntil = now + Config.gadgetRest(spec.duration)
	end

	-- "TAKE THE WORST", the same three rules `applySlow` keeps: the lower
	-- multiplier, the later stun, and the later end.
	local slowActive = now < (resident.fxSlowUntil or 0)
	resident.fxSlow = if slowActive then math.min(resident.fxSlow or 1, spec.slow) else spec.slow
	resident.fxSlowUntil = math.max(resident.fxSlowUntil or 0, now + spec.duration)
	if (spec.stun or 0) > 0 then
		resident.fxStunUntil = math.max(resident.fxStunUntil or 0, now + spec.stun)
	end

	if spec.knock then
		local away = ResidentService.bodyAt(resident) - from
		local flat = Vector3.new(away.X, 0, away.Z)
		if flat.Magnitude < 1e-3 then
			flat = -resident.facing
		end
		-- Rotating UP about (up x away) swings the head toward `away`: the
		-- neighbour falls AWAY from the thrower, as a player does.
		resident.fxKnockAxis = Vector3.yAxis:Cross(flat.Unit).Unit
		resident.fxKnockUntil = now + (spec.stun or 1)
	end
	return true
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
	-- NOT WHILE THEY ARE CHASING SOMEBODY. The bubble is one surface, and a
	-- neighbour who has just put an `!` over their head does not follow it with
	-- a line about the weather -- the chatter would overwrite the one thing on
	-- that head anybody needs to read.
	if resident.state == "chasing" then
		return
	end
	if not someoneNear(model:GetPivot().Position, chat.range) then
		return
	end
	ResidentModel.say(model, chat.lines[math.random(#chat.lines)])
	resident.quietAt = now + chat.hold
end


-- THE ONE STANDING POSE. `ResidentModel.poseWalk` writes every part of the
-- figure, and a neighbour that has not moved, turned, taken a step or picked
-- anything up is already standing exactly where this would put them -- so
-- the write is skipped, on a key of the five things the pose is a function
-- of plus the model itself. Measured before this existed: thirteen figures
-- being written every frame on a street where two were walking.
local function poseIfChanged(resident: Resident, model: Model, rig: ResidentModel.Rig)
	local carry = carrying(resident)
	if resident.posedModel == model
		and resident.posedAt == resident.at
		and resident.posedFacing == resident.facing
		and resident.posedStride == resident.stride
		and resident.posedCarry == carry then
		return
	end
	resident.posedModel = model
	resident.posedAt = resident.at
	resident.posedFacing = resident.facing
	resident.posedStride = resident.stride
	resident.posedCarry = carry
	ResidentModel.poseWalk(model, rig, facingCF(resident.at, resident.facing), resident.stride, carry)
end

local function stepResident(resident: Resident, dt: number)
	local rig = resident.rig
	local model = resident.model
	if not (rig and model and model.Parent) then
		return
	end

	local now = os.clock()

	-- THE STATE, PUBLISHED ON CHANGE. Read by nothing in the game; it is what
	-- lets a probe on a laggy street say which neighbours are moving and why
	-- without a handle on this service.
	if resident.publishedState ~= resident.state then
		resident.publishedState = resident.state
		model:SetAttribute(Config.RESIDENT_STATE_ATTRIBUTE, resident.state)
	end

	-- TAKEN DOWN IN EVERY STATE, NOT ONLY AT HOME. A neighbour who sets off
	-- mid-sentence would otherwise walk the length of the street with a speech
	-- bubble welded to them -- and `beginTrip` is one of four ways out of the
	-- home state, so clearing it at each of them is four chances to miss one.
	-- One comparison here covers all of them.
	if resident.quietAt > 0 and now >= resident.quietAt then
		ResidentModel.say(model, nil)
		resident.quietAt = 0
	end

	-- A GADGET HAS THEM. Frozen or flat, nothing else happens this tick:
	-- no walk, no crack finishing, no shopkeeper catch. The timers they are
	-- waiting on are pushed back by the same tick, so a freeze costs them
	-- the time it lasted rather than only the walk.
	if now < (resident.fxStunUntil or 0) then
		resident.waitUntil += dt
		if resident.chaseUntil then
			resident.chaseUntil += dt
		end
		if resident.chaseFrom then
			resident.chaseFrom += dt
		end
		local knockUntil = resident.fxKnockUntil
		local axis = resident.fxKnockAxis
		if knockUntil and axis and now < knockUntil then
			-- LYING FLAT. The pose is the walk pose at a standstill, tipped
			-- about the feet, and lifted a little so a body lying on the
			-- lawn is not half inside it.
			local tip = CFrame.fromAxisAngle(axis, math.rad(78))
			local lying = CFrame.new(resident.at + Vector3.new(0, 0.7, 0))
				* tip * facingCF(Vector3.zero, resident.facing)
			ResidentModel.poseWalk(model, rig, lying, resident.stride, carrying(resident))
		end
		return
	end
	if resident.fxKnockUntil then
		-- UP AGAIN, and posed upright once here, because the home branch
		-- below returns before it poses anything.
		resident.fxKnockUntil = nil
		resident.fxKnockAxis = nil
		resident.posedModel = nil
		poseIfChanged(resident, model, rig)
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
		-- THE MOVER BUDGET, ASKED BEFORE EITHER CLOCK. A neighbour whose trip
		-- or potter is due waits, still and unposed, until fewer than
		-- `walk.maxMoving` are away from home -- and goes the moment one
		-- comes back, because the clocks stay due. The shopkeeper never
		-- leaves and is not asked.
		local maxMoving = Config.RESIDENTS.walk.maxMoving
		local mayMove = maxMoving == nil or movingCount() < maxMoving
		if not resident.plot.shop
			and mayMove
			and now >= resident.nextTrip
			and outCount() < Config.RESIDENTS.walk.maxOut then
			beginTrip(resident)
		elseif not resident.plot.shop and mayMove and now >= resident.nextRoam then
			-- A STROLL ROUND THE GARDEN, CHECKED AFTER THE TRIP so that a
			-- neighbour who is due to go out goes out. The two clocks run
			-- independently, so in the tick where both come due the other
			-- ordering would hold the trip back until the stroll finished --
			-- rarely, and therefore rarely enough to be missed.
			--
			-- NOT A SHOPKEEPER, for the reason `SHOP_STAND_AT` exists: the
			-- pocket behind a counter is three studs deep and `ROAM_MIN` is a
			-- front lawn, so one pottering would walk out through their own
			-- back wall. They are also the one figure on this street whose
			-- standing still is the point -- an unattended shop is the target
			-- that is always meant to have somebody in it.
			--
			-- No `maxOut` here and none wanted: that cap is on how many
			-- houses are EMPTY at once, and a neighbour in their own garden
			-- is not one of them. What bounds the cost instead is the rest
			-- clock -- a stroll is about a second of walking in every
			-- fourteen, so the street averages well under one figure moving
			-- at a time on top of the two who are genuinely out.
			--
			-- A PLINTH WORTH COLLECTING FROM COMES BEFORE A POTTER, checked on
			-- the roam clock rather than on a third clock of its own: every
			-- six to twenty seconds a neighbour who is about to move looks at
			-- their own pads first, and walks to the ripest instead of
			-- nowhere in particular. No new cadence, and a neighbour cannot
			-- be both strolling and collecting, so nothing to keep in step.
			local ripe = ripestPad(resident)
			if not (ripe and beginCollect(resident, ripe)) then
				resident.state = "roam"
				resident.route = { roamTarget(resident) }
			end
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
		local spec = chaseSpec(resident)

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
			-- Measured FLAT. A resident on the pavement and a thief up on a plot
			-- slab are a stud apart vertically, and counting that would make every
			-- radius here mean something different on every piece of ground -- the
			-- trap the prompt ranges already record, where a reach measured to a
			-- centre is really a question about the floor.
			local flat = Vector3.new(to.X - resident.at.X, 0, to.Z - resident.at.Z)
			local gap = flat.Magnitude
			if spec.catchRadius and gap <= spec.catchRadius then
				-- SHOPS ONLY, AND THE ABSENCE ON A HOUSE IS THE DESIGN. A neighbour
				-- never takes the haul: the dog, a nab and the patrol stay the only
				-- three ways to lose one, and this costs a thief time and a slowed
				-- getaway instead. Defence buys time, never immunity.
				resident.chasing = nil
				resident.chaseUntil = nil
				resident.nextThrow = nil
				if catchThief then
					catchThief(resident, thief :: Player)
				end
				returnToCounter(resident)
			elseif gap > spec.giveUp then
				-- A LEASH IN STUDS AS WELL AS A CLOCK. The street is 350 studs long,
				-- and a chase with only a timer on it ends with somebody stranded
				-- outside a house at the far end of it.
				resident.chasing = nil
				resident.chaseUntil = nil
				resident.nextThrow = nil
				returnToCounter(resident)
			elseif not spec.catchRadius and PlotService.yardContaining(to) == resident.plot then
				-- THE DOG OWNS THE YARD, AND THIS IS THE WHOLE RELAY.
				--
				-- While the thief is still inside the fence the Shepherd is on them,
				-- and a neighbour walking in as well would be the second independent
				-- hard-stop on one lawn that `releaseDog`'s owner-home branch exists
				-- to refuse: "two things that can both hard-stop one thief on one
				-- lawn is how a plot becomes a wall". So they stand at their own door
				-- and watch, and pick the chase up at the moment the dog's own leash
				-- makes it break off.
				--
				-- Facing them while they wait, because a neighbour staring at their
				-- own front door while somebody robs the pig behind it reads as
				-- scenery rather than as a witness.
				resident.route = {}
				if gap > 0.01 then
					resident.facing = flat.Unit
				end
			else
				-- LEAVE BY THE GATE. A resident is CanCollide off, so a straight line
				-- at a thief on the pavement walks out through their own fence --
				-- which is the ghost the trip routing one function up already refuses
				-- to be. Once they are off their own plot the pursuit is direct.
				local aim = to
				if not spec.catchRadius and PlotService.yardContaining(resident.at) == resident.plot then
					local gate = (resident.plot.cframe * CFrame.new(0, 0, GATE_Z)).Position
					aim = Vector3.new(gate.X, resident.at.Y, gate.Z)
				end
				-- ON AN INTERVAL AND NEVER PER TICK: this branch runs at the resident
				-- tick rate, so an ungated throw would be a stream rather than a lob.
				if spec.throw and throwAt and now >= (resident.nextThrow or 0) then
					resident.nextThrow = now + spec.throw.interval
					throwAt(resident, thief :: Player)
				end
				-- One waypoint, replaced every tick. Y comes from where the resident
				-- already is rather than from the thief, so chasing somebody who has
				-- climbed a fence does not drag them into the air.
				resident.route = { Vector3.new(aim.X, resident.at.Y, aim.Z) }
			end
		end
	end

	local target = resident.route[1]
	if not target then
		-- Nothing left to walk to. Standing still is a stride that does not
		-- advance, so the legs close by construction with no test for it --
		-- and a figure that has not changed since the last write is not
		-- written again.
		poseIfChanged(resident, model, rig)
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
				-- move a player's DELIVER press makes. A PIGGY ends at the
				-- plinth instead and is stood on it; the two never coexist,
				-- because a trip is one job.
				if resident.haul then
					placeHaul(resident)
				else
					bankLoot(resident)
				end
				-- Then the second leg, to wherever they stand when idle. A
				-- neighbour who banked and then stayed planted beside their
				-- own piggy would be permanently in the one spot a thief has
				-- to reach, which is a defence nobody bought.
				resident.state = "returning"
				resident.route = { homeStand(resident) }
			elseif resident.state == "collecting" then
				finishCollect(resident)
			elseif resident.state == "roam" then
				-- Nothing to put back. A stroll ends facing wherever it was
				-- walked, which is what somebody who has just stopped looks
				-- like; `returning` below snaps the facing back to the street
				-- because a shopkeeper has ONE angle they are ever seen from,
				-- and a neighbour standing about on their own lawn has not.
				resident.state = "home"
				restRoam(resident)
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

	-- THE HOLD IS `carrying(resident)` AND DELIBERATELY NOT `state ==
	-- "carrying"`. Those two disagree in both directions and the arms are
	-- the honest one: a neighbour who was nabbed on the way home keeps the
	-- carrying STATE with nothing in their arms, and `finishCrack` sets the
	-- state before `attachLoot` decides whether anything came out of the pig
	-- at all. The file's own note one screen up makes the same call about the
	-- walk -- "the one thing that says a neighbour is holding anything is the
	-- loot model and never the walk".
	poseIfChanged(resident, model, rig)
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
-- A RESIDENT'S PIG IS STILL BOUNDED -- `pigSeconds` of its own income is the
-- supply `auditRobbery` prices, and `bankLoot` and the tick both clamp to it
-- -- so a refund fills only the room it has now, exactly as they do. A
-- PLAYER'S pig has no ceiling and takes everything back (`HeistService.
-- giveBack`); this is the one clamp left in a refund and it is deliberate.
-- Returns what was banked.
function ResidentService.refund(resident: Resident, amount: number): number
	local capacity = ResidentService.getCapacity(resident)
	local banked = math.min(math.max(0, math.floor(amount)),
		math.max(0, math.floor(capacity - resident.coins)))
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

		-- AND THE PLINTHS FILL, on the player's own arithmetic (`slotEconomy`)
		-- and the player's own two rules: a buffer over its cap is clamped
		-- down rather than left (a level falling with the street drops every
		-- cap), and an empty plinth holds nothing. Repainted only when
		-- something moved, which after the lap's worth of ticks is never --
		-- six attribute writes a plot a second while filling, none once full.
		if not resident.plot.shop then
			local slots = Config.piggySlots(resident)
			local moved = false
			for slot = 1, Config.PIGGY_LAWN_SLOT_COUNT do
				local rate, ceiling = slotEconomy(resident, slot)
				local held = slots[slot].buffer or 0
				local next_ = if rate > 0
					then math.min(ceiling, held + rate * Config.RESIDENTS.tickRate)
					else 0
				if next_ ~= held then
					slots[slot].buffer = next_
					moved = true
				end
			end
			if moved then
				PlotService.setPiggyBuffers(resident.plot, resident)
			end
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
