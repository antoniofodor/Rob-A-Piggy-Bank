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
check(Config.getCapacity(1) == 5000 and Config.getCapacity(20) == 2988151 and Config.getCapacity(40) == 96904045,
	"capacity at 1 / 20 / 40 unchanged")
check(near(Config.getIncomeRate(20, 0), 2994.6191770211863) and near(Config.getIncomeRate(40, 10), 128210.63960711213),
	"income at L20 RB0 and L40 RB10 unchanged")
check(Config.getIncomeCost(20) == 1643483 and Config.getCapacityCost(20) == 2390520
	and Config.getIncomeCost(40) == 53297224 and Config.getCapacityCost(40) == 77523236,
	"upgrade costs at 20 and 40 unchanged")
for rb = 0, 10 do
	check(Config.maxLevel(rb) == 20 + 2 * rb, "maxLevel unchanged at rebirth " .. rb)
	check(near(Config.rebirthIncomeFactor(rb), 1 + rb * 0.12), "rebirth factor unchanged at rebirth " .. rb)
end
check(Config.getRebirthThreshold(0) == 2988151 and Config.getRebirthThreshold(10) == 96904045,
	"rebirth gates at 0 and 10 unchanged")

-- ---- THE THIRD BAND ---------------------------------------------------------
check(Config.ABSOLUTE_MAX_LEVEL == 60 and Config.BAND_TOP_2 == 40, "ceiling 60, band C from 40")
check(Config.rebirthsToMax() == 20 and Config.maxLevel(20) == 60 and Config.maxLevel(25) == 60,
	"twenty rebirths open the ladder and the cap holds after")
local top = Config.getCapacity(60)
check(top >= 1.2e9 and top <= 1.3e9, "top pig is about 1.24B, got " .. top)
check(1e9 <= 0.85 * top, "a 1B house keeps the Sky Castle's headroom under the top pig")
check(near(Config.getCapacity(41) / Config.getCapacity(40), 1.136, 1e-4), "band C seam is exactly one band-C multiplier")
check(near(Config.getIncomeRate(41, 0) / Config.getIncomeRate(40, 0), 1.10, 1e-6), "income seam is one band-C multiplier")

-- The taper: 0.12 to rebirth 10, 0.08 beyond. Designer's choice (A2).
check(near(Config.rebirthIncomeFactor(11), 2.28) and near(Config.rebirthIncomeFactor(20), 3.0),
	"rebirth factor tapers to 3.0x at rebirth 20")
check(Config.rebirthBonusPercent(10) == 120 and Config.rebirthBonusPercent(20) == 200, "bonus percent reads the taper")

-- Fill time at every reachable ceiling stays in the band the whole game is
-- tuned to. 8 minutes at level 0; 12.6 at rebirth 10; 17.6 at rebirth 20.
for rb = 0, 20 do
	local L = Config.maxLevel(rb)
	local fill = Config.getCapacity(L) / Config.getIncomeRate(L, rb) / 60
	check(fill >= 10 and fill <= 18, ("fill time at rebirth %d ceiling is %.1f min"):format(rb, fill))
end

-- The affordability clamp binds on every band-C rung, which is what makes
-- time-per-rung constant there and is the no-deadlock guarantee.
for L = 40, 59 do
	local pig = Config.getCapacity(L)
	check(Config.getCapacityCost(L) == math.floor(0.80 * pig), "capacity clamp binds at level " .. L)
	check(Config.getIncomeCost(L) == math.floor(0.55 * pig), "income clamp binds at level " .. L)
	check(Config.getCapacityCost(L) <= pig and Config.getIncomeCost(L) <= pig, "no rung costs more than its pig at " .. L)
end

-- Robbing versus idling is a flat ratio by construction (pigSeconds cancels
-- the rate); band C lives inside getIncomeRate so it must stay flat.
local r0, i0 = Config.robberyRates(1, 0, 0)
local r1, i1 = Config.robberyRates(60, 20, 0)
check(near(r0 / i0, r1 / i1, 1e-6), "robbery advantage flat from L1 RB0 to L60 RB20")

-- ---- AUDITS ---------------------------------------------------------------
check(#Config.auditEconomy() == 0, "auditEconomy clean with the longer ladder")
check(#Config.auditRobbery() == 0, "auditRobbery clean across twenty rebirths")

-- Provoked: a 1B house against a 40-level ceiling must fire, and a 1B house
-- against the real ceiling must not.
local fake = { id = "testcitadel", name = "Test Citadel", style = "shack", cost = 1e9 }
table.insert(Config.HOUSE_TIERS, fake)
check(#Config.auditEconomy() == 0, "a 1B house fits the 60-level pig")
local saved = Config.ABSOLUTE_MAX_LEVEL
Config.ABSOLUTE_MAX_LEVEL = 40
local problems = Config.auditEconomy()
Config.ABSOLUTE_MAX_LEVEL = saved
table.remove(Config.HOUSE_TIERS)
-- The message names the catalogue and the key, not the house: "HOUSE_TIERS.10
-- costs 1000000000 against a largest possible pig of 96904045".
local fired = false
for _, p in problems do
	if p:find("HOUSE_TIERS", 1, true) and p:find("1000000000", 1, true) then fired = true end
end
check(fired, "audit refuses a 1B house against a 40-level pig")
check(#Config.auditEconomy() == 0, "audit clean again after the provocation")

print(("ladder: %d checks passed"):format(checks))
