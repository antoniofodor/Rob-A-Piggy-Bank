--!strict
--[[
	EconomyService

	Coin accrual, offline catch-up, and the two economy upgrades.

	THE PIG IS THE WALLET. There is one balance, `data.coins`, and it lives in
	the piggy bank on the lawn: every coin a player has is in there, every
	coin in there can be taken, and there is no bank to move it into. THE PIG
	HAS NO CEILING (designer decision 2026-09-21): nothing clamps a mint,
	nothing refuses a collect, and the Bigger Piggy Bank tree is retired --
	cash resets at every rebirth and rebirth is required for progress, so the
	reset is what bounds hoarding. See CLAUDE.md under THE ROBBING PIVOT for
	why the old vault/coins split was the reason nobody robbed anybody.

	Everything here is server-authoritative on purpose. The client renders
	coins; it never counts them. In a game where players take currency from
	each other, a trusted client is an open till -- so every request from a
	client is treated as a suggestion and re-derived from stored state.

	Rate limits sit on every entry point for the same reason.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local SocialService = require(script.Parent.SocialService)
local DailyService = require(script.Parent.DailyService)

local EconomyService = {}

local TICK_RATE = 1
local MIN_REQUEST_GAP = 0.25

local lastRequest: { [Player]: { [string]: number } } = {}

-- Highest milestone index each player has crossed on their current fill.
-- Resets once the pig drops back under the first threshold, so the
-- celebration replays every time it fills rather than firing once per
-- lifetime.
local milestoneReached: { [Player]: number } = {}

-- The whole-coin balance the tick last drew on the lawn and pushed to the
-- HUD. Every service that moves coins -- a purchase, a chest, bail, a daily,
-- a delivery -- used to have to remember to repaint the pile and push the
-- state itself, and the ones that forgot read as the thing being free. The
-- tick compares against this and catches up within a second whatever moved
-- the number.
local lastShown: { [Player]: number } = {}

-- ============================================================
-- HELPERS
-- ============================================================

local function throttled(player: Player, action: string): boolean
	local now = os.clock()
	local perPlayer = lastRequest[player]
	if not perPlayer then
		perPlayer = {}
		lastRequest[player] = perPlayer
	end
	if perPlayer[action] and (now - perPlayer[action]) < MIN_REQUEST_GAP then
		return true
	end
	perPlayer[action] = now
	return false
end

local function pushState(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end

	Remotes.get("StateUpdate"):FireClient(player, {
		coins = math.floor(data.coins),
		-- No `capacity` and no `full`: the pig is unbounded, so there is no
		-- denominator to push and no state in which it has stopped earning.
		rate = Config.getIncomeRate(data.incomeLevel, data.rebirths, SocialService.getFriendBonus(player)),
		-- WHAT THE WHOLE LAWN EARNS, BESIDE `rate` AND NEVER INSTEAD OF IT.
		--
		-- `rate` is the BASE ONE-PIG figure and has to stay that way, which the
		-- comment below already argues for the boost and is doubly true here:
		-- `ShopUpgradeFacts` recovers the boost/friend factor as
		-- `state.rate / getIncomeRate(level, ...)` and prints "now" against a
		-- "next" solved from the same function. Swapping `rate` for the
		-- collection would multiply that factor by up to 105 and inflate every
		-- figure on every upgrade card -- the exact shape of the trap the boost
		-- note names, one field along. Measured in the source before touching it.
		--
		-- SO THE TRUE INCOME TRAVELS AS ITS OWN FIELD. Nothing draws it yet: the
		-- top-right card is mid-rebuild in another workstream and `PiggyPanel`
		-- currently renders coins alone, so putting the number on the wire is the
		-- half that belongs here. A rate pill that reads this is a one-line
		-- change in whoever owns that panel.
		collection = EconomyService.collectionRate(player, data),
		-- THE BOOST TRAVELS BESIDE THE RATE AND DOES NOT MULTIPLY IT, and the
		-- split is deliberate rather than lazy.
		--
		-- `rate` is the BASE rate and several things read it that must not see
		-- a boost: the upgrade comparison prints "now" against a "next" solved
		-- from `getIncomeRate`, so a boosted `now` against an unboosted `next`
		-- would report an upgrade as making you SLOWER. Multiplying here would
		-- fix one readout by breaking another.
		--
		-- What was actually wrong is that nothing carried the boost at all, so
		-- the HUD said +3.0K/s while the pig filled at 6.0K/s -- a buff nobody
		-- can see, which is the trap the guard-duty collar already records.
		-- Sending both lets the one readout that is ABOUT the live drip show
		-- the real number, and leaves every other reader correct.
		--
		-- Both on THIS push, never split across two: the multiplier and the
		-- number it multiplies have to come from the same frame or a client can
		-- draw one against the other's.
		boostMultiplier = DailyService.getMultiplier(player),
		boostLeft = math.max(0, data.boostUntil - os.time()),
		friendBonus = SocialService.getFriendBonus(player),
		incomeLevel = data.incomeLevel,
		incomeCost = Config.getIncomeCost(data.incomeLevel),
		-- The reachable ceiling, not the absolute one: it rises two levels per
		-- rebirth, and the client draws the ladder from this number, so
		-- pushing the function's answer is what keeps both ends agreeing.
		maxIncome = Config.maxLevel(data.rebirths),
		rebirths = data.rebirths,
		-- Carried on the per-tick state rather than its own push, so the
		-- rebirth button lights up the instant the threshold is crossed.
		-- The same predicate `ProgressionService.canRebirth` refuses on --
		-- the cash gate AND the (placeholder) piggy gate -- so the button
		-- and the refusal cannot disagree.
		rebirthThreshold = Config.getRebirthThreshold(data.rebirths),
		rebirthReady = data.coins >= Config.getRebirthThreshold(data.rebirths)
			and Config.rebirthPiggyGate(data),
	})
	lastShown[player] = math.floor(data.coins)
end

-- Exposed so anything that moves `coins` from outside this file can say so
-- immediately rather than waiting up to a second for the tick to notice.
EconomyService.push = pushState

local function notify(player: Player, message: string, kind: string?)
	Remotes.get("Notify"):FireClient(player, message, kind or "info")
end

local function refreshPlot(player: Player)
	local data = DataService.get(player)
	local plot = PlotService.getPlot(player)
	if not data or not plot then
		return
	end
	PlotService.updatePile(plot, data.coins, Config.pigFullAt(data.rebirths))
	PlotService.updateSign(plot, player.DisplayName, data.rebirths,
		Config.getSkin(data.cosmetics.skin).name, Config.getShownHouse(data).name)
	-- THE LAWN GOES THROUGH THE SAME DOOR AS THE PILE AND THE SIGN. Every
	-- site that already knew to repaint a plot after changing a save -- a
	-- purchase, a collect, a rebirth, a join -- picks the six pedestals up for
	-- free, which is the whole reason this is here rather than at each of
	-- them. Idempotent on the server side, so the cost of the ones that did
	-- not need it is a table walk.
	PlotService.setPiggySlots(plot, data)
	-- AND THE FIGURES, WHICH THE TICK ALONE CANNOT BE TRUSTED TO PUBLISH.
	--
	-- The accrual loop only calls this when a buffer MOVED. That is the right
	-- optimisation and on its own it was a real bug, measured live: a player
	-- rejoining onto a lawn whose buffers had been SAVED AT THEIR CAP got six
	-- prompt cards carrying a verb and no figure, permanently, because nothing
	-- ever moved again. `updatePile` shipped precisely this once -- called only
	-- inside the accrual branch, guarded by `coins < capacity`, so on the one
	-- tick that mattered the guard was false and the attribute kept whatever
	-- it had been seeded with at boot, and residents advertised 2,962 while
	-- holding 44,130.
	--
	-- The rule that entry left behind is the fix: ANYTHING THAT CHANGES A PIG
	-- HAS TO REPUBLISH IT IN THE SAME BREATH -- and a REPAINT is one of those
	-- moments even when no arithmetic happened, because a repaint is what a
	-- join, a purchase, a rebirth and a collect all arrive through.
	PlotService.setPiggyBuffers(plot, data)
end

-- Fires the celebration for every milestone the pig has newly crossed.
-- Only the highest is played, so a big offline catch-up that jumps straight
-- past three thresholds gets one satisfying chime, not three overlapping ones.
local function checkMilestones(player: Player, plot: any, ratio: number)
	local reached = milestoneReached[player] or 0

	-- Spending (or being robbed) below the first rung re-arms the ladder, so
	-- the next fill celebrates again. Without this the milestones fired once
	-- per session, since nothing else ever reset them now that banking is
	-- gone.
	if ratio < Config.MILESTONES[1] then
		milestoneReached[player] = 0
		return
	end

	local highest = reached
	for index, threshold in ipairs(Config.MILESTONES) do
		if ratio >= threshold and index > highest then
			highest = index
		end
	end

	if highest > reached then
		milestoneReached[player] = highest
		PlotService.playMilestone(plot, highest, #Config.MILESTONES)

		-- The top rung is the rebirth cash gate (`Config.pigFullAt`), so the
		-- one functional milestone says what it means. Nothing stops
		-- earning: the pig has no ceiling.
		if highest == #Config.MILESTONES then
			notify(player, "Your piggy bank has reached the rebirth amount!", "good")
		end
	end
end

-- WHICH PIGGY IS WHERE -- LIFTED ABOVE THE OFFLINE SECTION BECAUSE THAT IS
-- WHAT READS IT. These two used to sit beside the accrual loop, which was
-- their only caller; offline catch-up asks for the collection now, and a
-- `local` declared after its reader is a nil GLOBAL to that reader -- the
-- failure this project has had take the whole server down eleven times, and
-- one that compiles clean and throws at the call.

-- The piggy standing in a placement, or nil for an empty one. `slot` is 0 for
-- the till and 1..Config.PIGGY_LAWN_SLOT_COUNT for the lawn.
-- WHICH PIGGY IS WHERE AND WHAT TIER IT IS -- both now `Config`'s, because
-- `EventService`'s raid drain asks the same question and two services may not
-- ask each other. The till fallback and the retired-key prune live there with
-- them; a second copy of either is silent when wrong.
--
-- KEPT AS LOCAL NAMES rather than every call site being rewritten, because the
-- three readers here (the buffer cap, the per-slot rate and the collection)
-- read better against a short name and this way the move is one edit rather
-- than nine.
local placedKey = Config.piggyKeyAt
local rarityAt = Config.piggyRarityAt

-- THE COIN CAP ON ONE PLACEMENT'S BUFFER: its own rate times how long its
-- TIER holds (`Config.piggyBufferSeconds`). The duration used to be a flat
-- `PIGGY_BUFFER_SECONDS` for every placement, so a legendary stopped earning
-- at the same hundred seconds as the free starter piggy.
--
-- BOTH READERS GO THROUGH THIS, which is the point of it being a function.
-- The accrual loop decides when a buffer is FULL and the collect decides what
-- share of full was just banked (the sound's pitch) -- two answers to one
-- question, and the second one silently SATURATES if they disagree: a ceiling
-- left on the flat hundred seconds would make `take / ceiling` exceed 1 on
-- every tier above common, clamp to 1, and chime at the top of the band
-- forever. A derived dial that always reads the same is the failure this
-- economy keeps recording.
--
-- `rate` IS PASSED IN rather than re-derived, because the accrual loop has
-- already paid for it once per slot per tick.
local function slotCeiling(data: any, slot: number, rate: number): number
	return rate * Config.piggyBufferSeconds(rarityAt(data, slot))
end

-- ============================================================
-- OFFLINE ACCRUAL
-- ============================================================

-- Computed from the stored lastSave timestamp, never from anything the
-- client reports, and clamped so a long absence can't mint a fortune: the
-- ONLY bound is `OFFLINE_CAP_SECONDS` now that the pig has no ceiling.
function EconomyService.applyOfflineIncome(player: Player): number
	local data = DataService.get(player)
	if not data then
		return 0
	end

	local elapsed = math.max(0, os.time() - data.lastSave)
	local counted = math.min(elapsed, Config.OFFLINE_CAP_SECONDS)
	if counted <= 0 then
		return 0
	end

	-- THE WHOLE COLLECTION, NOT ONE PIG. This asked `getIncomeRate`, which was
	-- a player's entire income until a lawn started earning and is now a
	-- seventh of it at best -- so an eight-hour absence paid out against the
	-- till alone and ignored six pedestals.
	--
	-- IT USED TO CHANGE ALMOST NOTHING, AND NOW IT IS THE WHOLE NUMBER. The
	-- line below was clamped to CAPACITY, which at every level the pig hit
	-- long before `OFFLINE_CAP_SECONDS` ran out -- so the rate only decided
	-- how short an absence still paid in full. With no ceiling the full
	-- eight hours pay at this rate, which is a real change to what a night
	-- away is worth and is recorded in the capacity-removal report.
	--
	-- NO FRIEND BONUS AND NO BOOST, which is the pair of rules this already
	-- kept and `collectionRate` would have broken. `getIncomeRate`'s own
	-- comment: friends were not in the server while you were asleep. And the
	-- daily boost multiplies the live drip only -- one that ticked while you
	-- were logged off would be a worse coin reward with extra steps. So this
	-- goes to `Config.collectionRate` directly rather than through
	-- `EconomyService.collectionRate`, which applies both.
	--
	-- STILL PAID AS COINS RATHER THAN INTO THE BUFFERS, and that is left alone
	-- deliberately. Plan §4a says a piggy earns into ITSELF and is collected by
	-- hand, so the honest offline model is buffers filling to their own
	-- `PIGGY_BUFFER_SECONDS` cap -- which would make eight hours away worth a
	-- hundred seconds per placement and is a real nerf to a real reward. That
	-- is a decision rather than a bug, so it is recorded here and not taken.
	local rate = Config.collectionRateOf(data)
	local before = data.coins

	data.coins = before + rate * counted

	return math.floor(data.coins - before)
end

-- ============================================================
-- ACTIONS
-- ============================================================

function EconomyService.purchase(player: Player, track: string)
	if throttled(player, "purchase") then
		return
	end

	local data = DataService.get(player)
	if not data then
		return
	end

	-- ONE TRACK. `capacity` was the other and is retired with the pig's
	-- ceiling; a client still sending it is ignored like any unknown track.
	local cost: number, level: number, maxLevel: number
	if track == "income" then
		level, maxLevel = data.incomeLevel, Config.maxLevel(data.rebirths)
		cost = Config.getIncomeCost(level)
	else
		return -- unknown track; ignore rather than error on client input
	end

	if level >= maxLevel then
		-- "Already at max level" was a lie on these two tracks for anybody
		-- below rebirth 20: the ladder runs to ABSOLUTE_MAX_LEVEL and a
		-- rebirth opens LEVELS_PER_REBIRTH more of it. Same predicate the
		-- shop's own gate reads, so the button and the refusal cannot
		-- disagree about which ceiling this is.
		notify(player, if Config.rebirthOpensMore(maxLevel)
			then "Rebirth to unlock more levels."
			else "Already at max level.", "warn")
		return
	end

	if data.coins < cost then
		notify(player, ("Need %s more coins"):format(EconomyService.format(cost - data.coins)), "warn")
		return
	end

	data.coins -= cost
	data.incomeLevel += 1
	notify(player, ("Income upgraded to level %d"):format(data.incomeLevel), "good")

	refreshPlot(player)
	pushState(player)
end

-- ============================================================
-- THE COLLECTION -- WHAT EACH PLACED PIGGY EARNS
-- ============================================================
--
-- PIGGY COLLECTION PHASE 1 (docs/PIGGY-COLLECTION-PLAN.md §4a). Nothing drips
-- into `data.coins` on its own clock any more. Every PLACED piggy fills a
-- buffer of its own at its own rate, and a collect prompt walks each buffer
-- across into the till.
--
-- THERE ARE SEVEN PLACEMENTS AND THE TILL IS ONE OF THEM. `data.tillBuffer`
-- is slot 0's buffer and the six `data.piggies.slots[i].buffer` are the lawn's
-- -- two storage shapes for one idea, which is a wart and a deliberate one:
-- the till's buffer predates the pedestals, it is a top-level number that
-- every existing save already reconciled, and folding it into the array would
-- be a schema migration to tidy a field name. The two are read through ONE
-- pair of accessors below so nothing downstream has to know there are two.


-- SLOTS 1..N ONLY. The bank (slot 0) has no buffer: its income goes straight
-- into `data.coins` on the tick below (designer decision 2026-09-22 -- the
-- centre pig is where a player's whole wealth sits, and a button to move
-- coins from the bank into the bank was a step for nothing).
local function bufferOf(data: any, slot: number): number
	local entry = Config.piggySlots(data)[slot]
	return (entry and entry.buffer) or 0
end

local function setBuffer(data: any, slot: number, amount: number)
	Config.piggySlots(data)[slot].buffer = amount
end

-- What one placement earns per second, or 0 when it is empty.
--
-- `friendBonus` and the daily boost are the SAME multipliers the retired drip
-- carried, applied here rather than being re-derived per slot: a boost is for
-- playing and a friend bonus is for being in a busy server, and neither is a
-- fact about which piggy is standing where.
local function slotRate(player: Player, data: any, slot: number): number
	local key = placedKey(data, slot)
	if key == nil then
		return 0
	end
	local skin = Config.SKINS[key]
	local rate = Config.getPiggyIncomeRate(skin and skin.rarity,
		data.incomeLevel, data.rebirths, SocialService.getFriendBonus(player))
	return rate * DailyService.getMultiplier(player)
end


-- WHAT THE WHOLE COLLECTION PRODUCES, which is the number every reader that
-- means "what this player earns" used to get from `Config.getIncomeRate` alone
-- and now cannot (plan §8).
--
-- IT DELEGATES TO `Config.collectionRate` RATHER THAN SUMMING HERE, and that is
-- the whole reason it is worth a function. `auditRobbery` measures idling
-- against a canonical lawn through that same summation, so what the audit calls
-- a collection and what a player earns from one cannot drift apart -- and this
-- economy's longest post-mortem is two curves nobody multiplied together.
--
-- THE TWO MULTIPLIERS STAY HERE, because `Config` requires nothing and can
-- reach neither. The friend bonus is a fact about who is in the server and the
-- daily boost is a fact about a claim, so both are the caller's to apply --
-- which is also why the boost is a flat factor on the total rather than
-- something `Config` has to know about.
function EconomyService.collectionRate(player: Player, data: any): number
	return Config.collectionRateOf(data, SocialService.getFriendBonus(player))
		* DailyService.getMultiplier(player)
end

-- WHAT EACH OF THE SIX LAWN PEDESTALS EARNS, for the row under its name.
--
-- THE LIVE FIGURE, WHICH IS THE ONLY REASON THIS IS EXPORTED. `PlotService`
-- builds those labels and can reach `Config.getPiggyIncomeRate` perfectly
-- well -- and that function answers the rate BEFORE the friend bonus and the
-- daily boost, both of which live behind services `PlotService` may not
-- require without a cycle. A label built from what is reachable would
-- under-report for the whole length of every boost while the HUD's rate pill
-- printed the right number, which is two claims about one figure and no way
-- for a player to tell which one is lying. `PlotService.registerPiggyRates`
-- is how this arrives; `Main` connects the two.
--
-- SLOT 0 IS DELIBERATELY NOT IN HERE. The till carries no name label, so
-- there is no row to print under -- and an array indexed 1..N is what the
-- pedestal loop already walks. `collectionRate` above is the one that counts
-- all seven, because that is a different question.
function EconomyService.pedestalRates(player: Player, data: any): { number }
	local rates = table.create(Config.PIGGY_LAWN_SLOT_COUNT)
	for slot = 1, Config.PIGGY_LAWN_SLOT_COUNT do
		rates[slot] = slotRate(player, data, slot)
	end
	return rates
end

-- Bank one placement's buffer into the till. `slot` 0 is the till's own piggy.
--
-- OWNER ONLY, CHECKED HERE. The client hides these prompts for anybody but
-- the owner through `PROMPT_OWNER_ATTRIBUTE`, which is a courtesy to the
-- reader; `Enabled` written on a client is a fact about that client's screen
-- and nothing else, so this is the check that is load-bearing.
--
-- `quiet` IS THE PAD, AND IT ONLY EVER SILENCES ONE REFUSAL. Crossing a pad
-- with nothing waiting must say nothing: the "never fail silently" rule is
-- about a player PRESSING something and getting no answer, and walking over a
-- patch of their own grass is not a press. The only other refusal is
-- "nothing to collect yet", and the pad's own per-player cooldown is what
-- stops even that repeating. (A FULL pig used to refuse here too; the pig
-- has no ceiling now, so a collect always banks the whole buffer.)
function EconomyService.collectPiggy(player: Player, slot: number?, quiet: boolean?)
	if throttled(player, "collect") then
		return
	end
	local data = DataService.get(player)
	local plot = PlotService.getPlot(player)
	if not data or not plot or plot.owner ~= player then
		return
	end
	-- Slot 0 is the bank and has nothing to collect: it drips.
	local index = math.floor(tonumber(slot) or 0)
	if index < 1 or index > Config.PIGGY_LAWN_SLOT_COUNT then
		return
	end

	local buffered = bufferOf(data, index)
	if buffered <= 0 then
		if not quiet then
			notify(player, "Nothing to collect yet.", "info")
		end
		return
	end

	-- THE WHOLE BUFFER, EVERY TIME. This used to clamp to the pig's room and
	-- say so; with no ceiling there is nothing to clamp against, and `take`
	-- is kept as a name because the pitch below is measured off it.
	local take = buffered
	setBuffer(data, index, 0)
	data.coins += take

	-- AND IT MAKES A NOISE, at the pad that banked it (designer call
	-- 2026-09-21). See `PIGGY_PEDESTAL.pad.sound` for the cue and
	-- `PlotService.playCollect` for why it is per pad rather than at the pig.
	--
	-- MEASURED AGAINST WHAT WENT IN. `take` is `buffered` now that nothing
	-- clamps a collect; the two names are kept apart so a future clamp would
	-- have to choose, because a
	-- cue pitched off `buffered` would then ring out a big collect the player
	-- did not get, one line after a toast telling them it did not fit. The
	-- sound reports the banking; the toast reports the refusal.
	--
	-- THE CEILING IS THE SLOT'S OWN, through `slotCeiling` -- literally the
	-- same function the accrual loop caps the buffer with, so what the pitch
	-- calls full is exactly what the loop stops filling. It is a function
	-- rather than a repeated expression precisely because the two disagreeing
	-- makes this dial saturate: a ceiling on the old FLAT duration would make
	-- `take / ceiling` exceed 1 on every tier above common and chime at the top
	-- of the band forever. A slot with no rate
	-- (an empty pedestal, which accrues nothing) would divide by zero, so it
	-- is guarded here and again inside `Config.piggyCollectPitch`: a nan
	-- `PlaybackSpeed` is SILENCE, which is the one failure shape that would
	-- look exactly like this feature not being wired up.
	local ceiling = slotCeiling(data, index, slotRate(player, data, index))
	PlotService.playCollect(plot, index, if ceiling > 0 then take / ceiling else 0)

	refreshPlot(player)
	PlotService.setPiggyBuffers(plot, data)
	pushState(player)

	-- AND ONE MORE REPAINT WHEN THE PAD MAY FIRE AGAIN, so the green arrives
	-- on time rather than up to a tick late.
	--
	-- `setPiggyBuffers` is what paints a pad's face and it runs on the economy
	-- tick, which is one second -- so without this the red window would be the
	-- cooldown PLUS however much of a tick was left, and a pad would sit dark
	-- for up to a second after stepping on it would have worked. That is the
	-- same lie the other way up: the safe direction for a light, and still a
	-- light that is wrong.
	--
	-- IT CANNOT FIGHT THE TICK, which is the reason this is a repaint rather
	-- than a timer that writes a colour. Both callers derive the face from the
	-- same buffer and the same stamp, so the later one agrees with the earlier
	-- by construction -- where a `task.delay` painting `readyColour` directly
	-- would be a second writer of one property and would light a pad whose
	-- buffer had been emptied in between.
	--
	-- RE-READ RATHER THAN CLOSED OVER: a second and a half is long enough for
	-- the player to leave, for the plot to be released and reseated, and for
	-- the save to have gone. Everything is asked for again and the owner is
	-- re-checked, so the worst this can do is nothing.
	local cool = Config.PIGGY_PEDESTAL.pad.cooldown
	task.delay(cool, function()
		local live = DataService.get(player)
		local nowPlot = PlotService.getPlot(player)
		if live and nowPlot and nowPlot.owner == player then
			PlotService.setPiggyBuffers(nowPlot, live)
		end
	end)
end

-- LETTING A PIGGY GO, WHICH IS THE ONLY WAY A SLOT EMPTIES WITHOUT A THIEF.
--
-- WHY THIS HAS TO EXIST AT ALL: with the lawn capped at six pedestals plus
-- the till and no bag behind them, a crate is REFUSED while every placement
-- is taken (`ChestService.whyCannotOpen`). Without a way to free one, a
-- player who fills their lawn can never open another crate -- so the gate
-- would be a dead end rather than a gate. This is the way out.
--
-- IT PAYS COINS, and that is `Config.sellValue`'s own rule rather than a
-- choice made here: there is one currency again. It used to pay acorns, on
-- the reasoning that acorns were what a crate cost, so letting a piggy go
-- bought the roll that replaced it. Nothing buys a crate now, so that trade
-- is gone and the sale lands in the coin economy like every other payout.
--
-- IT BANKS IN FULL: the pig has no ceiling, so there is no room to fit and
-- no spill to say.
function EconomyService.sellPiggy(player: Player, slot: number?)
	if throttled(player, "sellpiggy") then
		return
	end
	local data = DataService.get(player)
	local plot = PlotService.getPlot(player)
	if not data or not plot or plot.owner ~= player then
		return
	end
	-- SLOT 0 IS NOT SELLABLE AND IT IS NOT AN OVERSIGHT. The till always wears
	-- something (§3: it falls back to Classic rather than to nothing), so
	-- selling the piggy off it would either leave the one placement that may
	-- never be empty empty, or silently swap in Classic behind the player's
	-- back. Changing what is on the till is a DISPLAY choice and wants its own
	-- verb; this one only ever takes a piggy off the grass.
	local index = math.floor(tonumber(slot) or 0)
	if index < 1 or index > Config.PIGGY_LAWN_SLOT_COUNT then
		return
	end

	local entry = Config.piggySlots(data)[index]
	local key = entry and entry.key
	if key == nil then
		notify(player, "There is nothing on that pedestal.", "warn")
		return
	end

	local value = Config.sellValue("skin", key)
	local skin = Config.getSkin(key)
	local name = (skin and skin.name) or key
	-- A SALE WORTH NOTHING IS REFUSED RATHER THAN BEING A FREE DELETE. A skin
	-- with no rarity the ladder prices would come back at 0 here, and taking
	-- somebody's piggy away for nothing is the worst outcome on this prompt --
	-- so it refuses, loudly, and the piggy stays where it is.
	if value <= 0 then
		notify(player, ("%s cannot be sold."):format(name), "warn")
		return
	end

	-- THE BUFFER GOES WITH IT AND IS NOT PAID OUT, which is the same rule a
	-- SNATCHED piggy follows (plan §4a: a carried piggy takes its buffer with
	-- it as zero rather than as a bonus). Collect first if you want it -- the
	-- prompt to do that is on the same plinth, which is the whole reason both
	-- cards are visible at once.
	if Config.removePiggy(data, index) == nil then
		return
	end
	local paid = math.max(0, math.floor(value))
	data.coins += paid
	notify(player, ("Sold %s. +%s coins."):format(name, Config.formatCoins(paid)), "money")

	refreshPlot(player)
	PlotService.setPiggyBuffers(plot, data)
	pushState(player)
	DataService.save(player)
end

-- ============================================================
-- FORMATTING
-- ============================================================

-- ONE LADDER, IN CONFIG, because there were two of these and a third was
-- about to be written. ClientMain kept a byte-identical copy and ChestService
-- needs one on a service that can require neither -- and Config requires
-- nothing while both ends already read it, which makes it the only home where
-- another copy is not the cheaper option. Kept as a name here because 40-odd
-- call sites read it.
EconomyService.format = Config.formatCoins

-- ============================================================
-- LIFECYCLE
-- ============================================================

function EconomyService.onPlayerReady(player: Player)
	local gained = EconomyService.applyOfflineIncome(player)

	-- Set the milestone baseline silently. A player rejoining to a full pig
	-- should not get a fanfare fired at them before the HUD has even drawn --
	-- the offline-income toast below already tells them what happened.
	local data = DataService.get(player)
	if data then
		local ratio = data.coins / Config.pigFullAt(data.rebirths)
		local reached = 0
		for index, threshold in ipairs(Config.MILESTONES) do
			if ratio >= threshold then
				reached = index
			end
		end
		milestoneReached[player] = reached
	end

	refreshPlot(player)
	pushState(player)

	if gained > 0 then
		notify(player, ("Your piggy bank earned %s coins while you were away"):format(EconomyService.format(gained)), "money")
	end
end

-- ============================================================
-- THE COLLECT PADS
-- ============================================================
--
-- A flat button on the grass that banks a buffer when somebody walks over it.
-- See `PiggyPedestal.build` for why it is a place rather than a press.
--
-- `Touched` IS NOT AN ENTRY EVENT, AND THIS IS THE ENTIRE DIFFICULTY.
--
-- It fires PER CHARACTER PART and re-fires on every re-contact: measured on an
-- electric fence, fourteen parts reporting on the first contact frame and
-- eighteen fires over four seconds while standing still. That is the bug that
-- made a fence stun renew itself faster than it could expire, and it is the
-- single most expensive lesson in this codebase about this one event.
--
-- What it would cost HERE is not a freeze, because a collect is idempotent --
-- it is one crossing banking seven times, and, worse, a refusal toast fired
-- fourteen times over. So every pad keeps a per-player stamp.
--
-- KEYED PER PLAYER PER PAD, never per player alone. Per player, walking from
-- one pedestal to the next inside the cooldown would silently skip the second
-- pad -- and the whole mechanic is a lap of six of them, so the pads are
-- crossed in quick succession by design.
local padTouchedAt: { [BasePart]: { [Player]: number } } = {}

local function wirePad(pad: BasePart, slot: number)
	local stamps: { [Player]: number } = {}
	padTouchedAt[pad] = stamps
	pad.Touched:Connect(function(hit: BasePart)
		-- The character a part belongs to, and nothing else: a thrown bone or
		-- a rolling ride part touching a pad is not somebody collecting.
		local character = hit.Parent
		if not character then
			return
		end
		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local now = os.clock()
		local last = stamps[player]
		if last and (now - last) < Config.PIGGY_PEDESTAL.pad.cooldown then
			return
		end
		stamps[player] = now
		-- QUIET, because walking is not asking. A pad crossed with an empty
		-- buffer must say nothing at all -- the "never fail silently" rule is
		-- about a player PRESSING something and getting no answer, and
		-- crossing a patch of grass is not a press. The refusals that do
		-- speak are the ones a player can act on, and the cooldown above is
		-- what stops even those repeating.
		EconomyService.collectPiggy(player, slot, true)
	end)
end

function EconomyService.start()
	Remotes.get("PurchaseRequest").OnServerEvent:Connect(function(player, track)
		if type(track) ~= "string" then
			return
		end
		EconomyService.purchase(player, track)
	end)

	-- NO CUSTOM REMOTE -- `ProximityPrompt.Triggered` already replicates
	-- client-to-server on its own, the same native channel `steal` and
	-- `smash` use (see `wireEntry` in HeistService).
	--
	-- WHICH SLOT IS CLOSED OVER HERE, NEVER SENT. A prompt carries its own
	-- slot index in the connection rather than in a payload, so there is no
	-- number on the wire to forge -- the same "the click means now, never now
	-- and here" decision `BoneThrow`, `placeLadder` and `CrackTap` all make.
	-- The only thing a forged trigger could reach is a buffer on the caller's
	-- own plot, which they may empty by walking to it anyway.
	--
	-- CONNECTED HERE, WHERE THE PLOTS EXIST, rather than per claim: a pad and
	-- a prompt both outlive every owner a plot ever has (`PiggyPedestal.dress`
	-- rebuilds the display and never either of them), so one connection per
	-- pedestal for the life of the server is correct and a re-wire on claim
	-- would be a leak.
	for _, plot in ipairs(PlotService.getAll()) do
		for index, pedestal in ipairs(plot.pedestals or {}) do
			wirePad(pedestal.pad, index)
			pedestal.sellPrompt.Triggered:Connect(function(who: Player)
				EconomyService.sellPiggy(who, index)
			end)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		milestoneReached[player] = nil
		lastShown[player] = nil
	end)

	-- Accrual loop. Uses elapsed wall time rather than assuming the tick
	-- landed exactly on schedule, so a laggy server doesn't lose income.
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(TICK_RATE)
			local now = os.clock()
			local delta = now - last
			last = now

			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataService.get(player)
				if data then
					-- What the pile on the lawn reads as full: the rebirth
					-- cash gate, never a limit (`Config.pigFullAt`).
					local fullAt = Config.pigFullAt(data.rebirths)

					-- PIGGY COLLECTION PHASE 1: THE PASSIVE DRIP IS RETIRED.
					-- Nothing fills `data.coins` on its own clock any more -- see
					-- docs/PIGGY-COLLECTION-PLAN.md §1/§4a. Every PLACED piggy
					-- fills a buffer of its OWN instead, at its own rate, and a
					-- collect prompt walks each buffer across. Seven placements:
					-- the till (slot 0) and the six lawn pedestals.
					--
					-- THE CAP IS PER SLOT AND IS NOW PER TIER TOO. It was `rate
					-- * PIGGY_BUFFER_SECONDS`, a flat hundred seconds for every
					-- placement -- so a legendary filled in the same wall-clock
					-- time as the free starter piggy and the best thing on the
					-- lawn was the one punished hardest by a late lap.
					--
					-- `slotCeiling` folds the tier in (designer call 2026-09-21),
					-- and what that SPENDS is stated where the number lives: the
					-- old flat cap made everything ripen together, which is the
					-- property that made one lap the right action instead of six
					-- errands. The lap is now set by the SHORTEST cap -- the
					-- commons -- and lapping on that clock still collects
					-- everything before anything is full, so the tier ladder is
					-- pure slack: being late costs your cheapest piggies first.
					-- See `Config.PIGGY_BUFFER_TIER_POWER`.
					--
					-- A BUFFER OVER ITS OWN CAP IS CLAMPED DOWN RATHER THAN LEFT,
					-- which is the case a rebirth produces: the income tree is
					-- wiped, so every rate falls and every cap with it, and a
					-- buffer filled at the old rate would sit above the new
					-- ceiling forever.
					-- THE BANK DRIPS STRAIGHT INTO THE BALANCE (designer
					-- decision 2026-09-22). The centre pig is where everything
					-- a player owns already sits, so its own piggy's income has
					-- no buffer and no pad: it lands in `coins` on every tick,
					-- at the till skin's own rarity rate, and the pile on the
					-- lawn is the readout. Slots 1..N still fill a buffer each.
					local bankRate = slotRate(player, data, 0)
					if bankRate > 0 then
						data.coins += bankRate * delta
					end
					local buffersMoved = false
					for slot = 1, Config.PIGGY_LAWN_SLOT_COUNT do
						local rate = slotRate(player, data, slot)
						if rate > 0 then
							local held = bufferOf(data, slot)
							local capped = math.min(slotCeiling(data, slot, rate),
								held + rate * delta)
							if capped ~= held then
								setBuffer(data, slot, capped)
								buffersMoved = true
							end
						elseif bufferOf(data, slot) ~= 0 then
							-- AN EMPTY SLOT HOLDS NOTHING. A piggy snatched off a
							-- pedestal takes its buffer with it as ZERO rather
							-- than as a windfall (plan §4a) -- and the coins it
							-- had accrued are not the thief's either. This is the
							-- one line that enforces both halves.
							setBuffer(data, slot, 0)
							buffersMoved = true
						end
					end

					-- WHAT IS WAITING ON EACH PEDESTAL, repainted on the tick
					-- because that is the clock it changes on. Attributes on six
					-- prompts, so this is cheap -- and it is the only thing that
					-- tells a player standing in their own garden which pedestal
					-- is worth walking to next.
					--
					-- NOT PUSHED THROUGH `pushState`: it is one string per
					-- placement on the reader's own plot, which is exactly the
					-- shape an attribute serves and a `StateUpdate` field does
					-- not. Same call the published pile already makes.
					if buffersMoved then
						local plot = PlotService.getPlot(player)
						if plot then
							PlotService.setPiggyBuffers(plot, data)
						end
					end

					-- Repaint and push whenever the whole-coin balance moved, whoever
					-- moved it. See `lastShown`.
					local whole = math.floor(data.coins)
					if whole ~= lastShown[player] then
						local plot = PlotService.getPlot(player)
						if plot then
							local newCoins = PlotService.updatePile(plot, data.coins, fullAt)
							if newCoins > 0 then
								PlotService.playCoinDrop(plot)
							end
							checkMilestones(player, plot, data.coins / fullAt)
						end
						pushState(player)
					end
				end
			end
		end
	end)
end

return EconomyService
