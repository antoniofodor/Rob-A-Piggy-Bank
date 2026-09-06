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

	THERE IS SOMEBODY STANDING ON THE LAWN, AND THEY DO NOTHING. Each resident
	gets a figure built from the drip statue's own geometry (see
	Shared/ResidentModel), scaled to human height, recoloured per plot and
	stripped of its plinth. Eight houses with seven of them visibly empty was
	the other half of the problem residents were built for -- the coins half
	was fixed and the picture was not.

	IT HAS NO BEHAVIOUR AT ALL. It does not see, walk, or raise an alarm, and
	nothing about the heist reads it. It is scenery with a face, and every
	part it is made of is CanCollide and CanQuery off, so it can never body
	block a thief, a defender or the dog.

	AND THAT LEAVES A REAL QUESTION OPEN RATHER THAN ANSWERED BY ACCIDENT.
	The guard dog model in docs/core-loop-plan.md 4.1/4.8 keys off whether the
	owner is HOME: home means the dog stays awake and defers to them, away
	means it sleeps in the kennel until a noise. A resident's owner is treated
	as permanently away -- which is what makes these plots robbable -- and
	there is now visibly a person standing in the garden while that is true.

	Three ways out, none chosen yet: the figure reads as a STATUE of the
	resident rather than the resident (honest, and the geometry is literally a
	statue already); or the figure is the resident and DOES raise an alarm,
	with a facing cone so sneaking up behind them is the counter, which is the
	natural partner to tiptoe and much the most interesting option; or the
	figure moves indoors and out on a cycle so "home" is a thing you can watch
	for. Decide it when the dog is wired, not before.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Services = ServerScriptService:WaitForChild("Services")
local DataService = require(Services.DataService)
local PlotService = require(Services.PlotService)
local ResidentModel = require(ReplicatedStorage.Shared.ResidentModel)

export type Resident = {
	plot: PlotService.Plot,
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
	-- The ordered list of ornaments this garden would hold if it were full.
	-- Taken as a PREFIX, so a resident that climbs with the street ADDS to its
	-- garden rather than being handed a different one.
	garden: { string },
	-- The neighbour standing on the lawn. Optional because the figure is
	-- decoration: if it fails to build the plot still works exactly as it
	-- did, which is the right way round for something with no behaviour.
	model: Model?,
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
local function pigSize(level: number): number
	return Config.RESIDENTS.pigSeconds * Config.getIncomeRate(level, 0)
end

-- WHERE A NEIGHBOUR STANDS, in plot-local studs.
--
-- Behind the piggy and in front of the house. The piggy holds the centre at
-- 0, the house front line is at -28, and the walk from the gate takes the
-- whole middle of the plot in FRONT of the piggy -- plot-local +Z is the
-- street on both rows -- so -20 is out of everybody's way. Offset sideways
-- so they are not standing dead in front of their own front door.
local STAND_AT = Vector3.new(12, 0, -20)

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

	PlotService.setDogLevel(plot, math.clamp(math.floor(level / R.dogPerLevels), 0, #Config.DOG_TIERS))
	PlotService.buildFence(plot, math.clamp(math.floor(level / R.fencePerLevels), 0, #Config.FENCE_TIERS))
	PlotService.setLockLevel(plot, math.clamp(math.floor(level / R.lockPerLevels), 0,
		Config.UPGRADES.locks.max))
	PlotService.setHouseLevel(plot, math.clamp(math.floor(level / R.housePerLevels), 0,
		#Config.HOUSE_TIERS - 1))

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

	PlotService.updateSign(plot, resident.name, 0)
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
	local capacity = pigSize(level)

	local resident: Resident = {
		plot = plot,
		-- Indexed by plot rather than picked at random, so a house keeps its
		-- identity across an owner arriving and leaving.
		name = Config.getResidentName(plot.index),
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
		garden = garden,
	}

	residents[plot.index] = resident
	applyLevel(resident)

	-- The lawn is the TOP OF THE PLOT SLAB, derived rather than the +0.5 it
	-- happens to be today: a plot is three different floor heights and using
	-- one number for all of them is what left every ornament hovering a full
	-- stud when Decor was written.
	local lawnY = plot.base.Position.Y + plot.base.Size.Y / 2
	local ok, built = pcall(ResidentModel.build, plot.index,
		plot.cframe * CFrame.new(STAND_AT), lawnY, plot.model)
	if ok then
		resident.model = built
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
	if resident.model then
		resident.model:Destroy()
	end
	residents[plot.index] = nil
	plot.model:SetAttribute(Config.PLOT_RESIDENT_ATTRIBUTE, nil)
	plot.model:SetAttribute(Config.PLOT_RESIDENT_ID_ATTRIBUTE, nil)
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
	return pigSize(resident.capacityLevel)
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
function ResidentService.refund(resident: Resident, amount: number)
	resident.coins += math.max(0, amount)
	PlotService.updatePile(resident.plot, resident.coins, ResidentService.getCapacity(resident))
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
				resident.coins = math.max(resident.coins, pigSize(level))
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
			PlotService.updatePile(resident.plot, resident.coins, pigSize(level))
		end

		local capacity = pigSize(resident.capacityLevel)
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
end

return ResidentService
