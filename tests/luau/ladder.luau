-- The late-game ladder (MASTER-PLAN Phase 4b.1, LATE-GAME-ECONOMY-PLAN §3).
-- Real Config, no engine, no saves. Every figure below is either today's
-- shipped value -- which must not move -- or a derivation the plan records.
local Config = ...
local checks = 0
local function check(ok, message) assert(ok, message); checks += 1 end
local function near(a, b, tol) return math.abs(a - b) <= (tol or 1e-6) * math.max(1, math.abs(b)) end

-- ---- NOTHING BELOW LEVEL 40 / REBIRTH 10 MOVED -----------------------------
-- These are the values measured out of the live Config the day before band C
-- landed (tests/sim/late-game/dump.py). A byte-identical early and mid game
-- is the whole reason there is no value migration.
-- THE PIG HAS NO CAPACITY (designer decision 2026-09-21). The ladder below is
-- the INCOME ladder alone, and the retired half has to STAY retired: a
-- `getCapacity` that came back would be a cap with no reader deciding to
-- have one.
check(Config.getCapacity == nil and Config.getCapacityCost == nil and Config.fitInPig == nil
	and Config.pigRoom == nil and Config.UPGRADE_COST_CEILING == nil
	and Config.CAPACITY_GROWTH == nil and Config.BASE_CAPACITY == nil
	and Config.REBIRTH_CAPACITY_MULTIPLE == nil,
	"the capacity ceiling, its tree, its clamp and its gate basis are gone")
check(near(Config.getIncomeRate(20, 0), 2994.6191770211863) and near(Config.getIncomeRate(40, 10), 128210.63960711213),
	"income at L20 RB0 and L40 RB10 unchanged")
-- INCOME COSTS ARE THE PURE CURVE NOW. They were 1,643,483 and 53,297,224 at
-- 20 and 40 -- both CLAMPED by `UPGRADE_COST_CEILING`, which is retired with
-- the wallet it guarded -- so these two moved, on purpose, and are pinned at
-- the unclamped figures so they cannot move again by accident.
check(Config.getIncomeCost(20) == 1653340 and Config.getIncomeCost(40) == 168179539,
	"income costs at 20 and 40 are the unclamped curve")
check(Config.getIncomeCost(1) == 400 and Config.getIncomeCost(19) == 400 * 1.55 ^ 18 // 1,
	"band A income costs untouched")
for rb = 0, 10 do
	check(Config.maxLevel(rb) == 20 + 2 * rb, "maxLevel unchanged at rebirth " .. rb)
	check(near(Config.rebirthIncomeFactor(rb), 1 + rb * 0.12), "rebirth factor unchanged at rebirth " .. rb)
end
check(Config.getRebirthThreshold(0) == 2988151 and Config.getRebirthThreshold(10) == 96904045,
	"rebirth gates at 0 and 10 unchanged")
-- THE GATE IS A FROZEN TABLE (`REBIRTH_CASH_GATE`, PLACEHOLDER: designer to
-- set): every row is today's old derivation as a literal, so nothing got
-- easier or harder, and the piggy half is a hook that says yes.
for rb, gate in pairs({ [1] = 4231522, [5] = 17016580, [15] = 346836842, [20] = 1241390843 }) do
	check(Config.getRebirthThreshold(rb) == gate, "frozen gate at rebirth " .. rb)
end
check(Config.rebirthPiggyGate({}) == true, "the piggy gate is a placeholder that passes")

-- ---- THE THIRD BAND ---------------------------------------------------------
check(Config.ABSOLUTE_MAX_LEVEL == 60 and Config.BAND_TOP_2 == 40, "ceiling 60, band C from 40")
check(Config.rebirthsToMax() == 20 and Config.maxLevel(20) == 60 and Config.maxLevel(25) == 60,
	"twenty rebirths open the ladder and the cap holds after")
-- The gate flattens past the last rebirth that opens a level, as the old
-- derivation did at ABSOLUTE_MAX_LEVEL, and never gets easier on the way up.
check(Config.getRebirthThreshold(25) == Config.getRebirthThreshold(20), "the gate is flat past rebirth 20")
for rb = 1, Config.rebirthsToMax() do
	check(Config.REBIRTH_CASH_GATE[rb] > Config.REBIRTH_CASH_GATE[rb - 1], "the gate climbs at rebirth " .. rb)
end
check(near(Config.getIncomeRate(41, 0) / Config.getIncomeRate(40, 0), 1.10, 1e-6), "income seam is one band-C multiplier")

-- The taper: 0.12 to rebirth 10, 0.08 beyond. Designer's choice (A2).
check(near(Config.rebirthIncomeFactor(11), 2.28) and near(Config.rebirthIncomeFactor(20), 3.0),
	"rebirth factor tapers to 3.0x at rebirth 20")
check(Config.rebirthBonusPercent(10) == 120 and Config.rebirthBonusPercent(20) == 200, "bonus percent reads the taper")

-- (The fill-time band and the affordability clamp that used to be asserted
-- here were both statements about a bounded pig and went with it.)
--
-- Unclamped, the income cost curve is monotonic across all three bands and
-- its seams are one band multiplier each.
for L = 1, Config.ABSOLUTE_MAX_LEVEL - 1 do
	check(Config.getIncomeCost(L + 1) > Config.getIncomeCost(L), "income cost climbs at level " .. L)
end
check(near(Config.getIncomeCost(21) / Config.getIncomeCost(20), 1.26, 1e-6), "income cost seam A/B is one band-B multiplier")
check(near(Config.getIncomeCost(41) / Config.getIncomeCost(40), 1.26, 1e-6), "income cost seam B/C is one band-C multiplier")

-- Robbing versus idling is a flat ratio by construction (pigSeconds cancels
-- the rate); band C lives inside getIncomeRate so it must stay flat.
local r0, i0 = Config.robberyRates(1, 0, 0)
local r1, i1 = Config.robberyRates(60, 20, 0)
check(near(r0 / i0, r1 / i1, 1e-6), "robbery advantage flat from L1 RB0 to L60 RB20")

-- ---- AUDITS ---------------------------------------------------------------
check(#Config.auditEconomy() == 0, "auditEconomy clean with the longer ladder")
-- AUDITROBBERY IS NOT CLEAN, ON PURPOSE, AND THIS IS THE ONE PROBLEM IT MAY
-- REPORT. The collection sweep added to it measures idling against a whole
-- lawn instead of one pig, and robbing loses to it: 0.459x against a floor of
-- 3.0x. That is a real imbalance awaiting plan §8's re-derivation, so the
-- audit is meant to say so on every boot.
--
-- ASSERTED AS "NOTHING ELSE", NEVER AS A COUNT. A flat `== 1` would pass just
-- as happily if the collection check went quiet and some OTHER check started
-- firing, which is the swap this suite exists to catch. Matching the wording
-- means zero problems passes too, so the day §8 lands this test does not have
-- to be edited to let the fix through.
for _, problem in ipairs(Config.auditRobbery()) do
	check(problem:find("FULL LAWN", 1, true) ~= nil,
		"the only robbery problem is the known collection one: " .. problem)
end
-- And the collection check has to be REACHABLE rather than silently skipped:
-- a `fullLawn` that came back empty would make its ratio infinite and the
-- sweep would never fire, which is the shape of a guard that guards nothing.
check(#Config.fullLawn("common") == Config.PIGGY_LAWN_SLOT_COUNT + 1,
	"a full lawn is every pedestal plus the till")
check(Config.collectionRate(Config.fullLawn("common"), 20, 0)
	> Config.getIncomeRate(20, 0),
	"and a whole collection earns more than the one pig the old audit measured")

-- NO PRICE IS IMPOSSIBLE: a 100B house is a wait, not a wall, and the audit
-- says nothing about it.
local fake = { id = "testcitadel", name = "Test Citadel", style = "shack", cost = 1e11 }
table.insert(Config.HOUSE_TIERS, fake)
check(#Config.auditEconomy() == 0, "a 100B house is not an audit problem with an unbounded pig")
table.remove(Config.HOUSE_TIERS)
-- Provoked: a HOLE in the frozen gate table must fire, because a missing row
-- falls back to the top row and silently gates a mid-game rebirth at 1.24B;
-- and a gate that got EASIER with rebirths must fire too.
local savedGate = Config.REBIRTH_CASH_GATE[5]
Config.REBIRTH_CASH_GATE[5] = nil
local problems = Config.auditEconomy()
Config.REBIRTH_CASH_GATE[5] = savedGate
local fired = false
for _, p in problems do
	if p:find("REBIRTH_CASH_GATE[5]", 1, true) then fired = true end
end
check(fired, "audit refuses a hole in the rebirth cash gate")
Config.REBIRTH_CASH_GATE[5] = 1
problems = Config.auditEconomy()
Config.REBIRTH_CASH_GATE[5] = savedGate
fired = false
for _, p in problems do
	if p:find("REBIRTH_CASH_GATE[5]", 1, true) and p:find("lower", 1, true) then fired = true end
end
check(fired, "audit refuses a gate that gets easier with rebirths")
check(#Config.auditEconomy() == 0, "audit clean again after the provocations")

print(("ladder: %d checks passed"):format(checks))
