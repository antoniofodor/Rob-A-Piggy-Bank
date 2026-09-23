#!/usr/bin/env python3
"""Load the LIVE Config.luau through the Luau CLI (same inert prelude as
tests/run-crates.py) and dump the economy curves as CSV. Nothing is
re-implemented here: every number comes out of Config's own functions."""
import os, subprocess, tempfile
from pathlib import Path

ROOT = Path(r"C:\Users\anton\robloxGame")
LUAU = Path(os.environ["TEMP"]) / "codex-luau-0.738" / "luau.exe"

def literal(text):
    eq = "="
    while "]" + eq + "]" in text:
        eq += "="
    return "[" + eq + "[" + text + "]" + eq + "]"

PRELUDE = r'''
local valueMeta = {__mul = function(a, b) return a end}
local function value(...) return setmetatable({...}, valueMeta) end
local function vector(x, y, z) return {X=x, Y=y, Z=z} end
local env = setmetatable({
 Color3 = {fromRGB = value}, Vector3 = {new = vector},
 CFrame = {new = value, Angles = value},
 ColorSequence = {new = value}, ColorSequenceKeypoint = {new = value},
 NumberRange = {new = value},
 Enum = setmetatable({}, {__index = function(_, group)
  return setmetatable({}, {__index = function(_, name) return group .. "." .. name end})
 end}),
}, {__index = getfenv()})
local function loadConfig(source)
 local run = assert(loadstring(source, "Config"));setfenv(run, env);return run()
end
'''

DUMP = r'''
local C = Config
print("#scalars")
for _, k in ipairs({"BASE_INCOME","BASE_CAPACITY","INCOME_GROWTH","CAPACITY_GROWTH",
  "INCOME_GROWTH_B","CAPACITY_GROWTH_B","INCOME_COST_GROWTH","CAPACITY_COST_GROWTH",
  "INCOME_COST_GROWTH_B","CAPACITY_COST_GROWTH_B","BAND_TOP","ABSOLUTE_MAX_LEVEL",
  "LEVELS_PER_REBIRTH","INCOME_BASE_COST","CAPACITY_BASE_COST","REBIRTH_MULTIPLIER",
  "REBIRTH_CAPACITY_MULTIPLE","OFFLINE_CAP_SECONDS","HEIST_PAYOUT","STEAL_COOLDOWN",
  "PLOT_COUNT","MAX_PLAYERS","SHOP_COUNT","SHOP_VAULT_DISCOUNT","MAX_HOUSE_LEVEL"}) do
  print(k, C[k])
end
print("ceiling.income", C.UPGRADE_COST_CEILING.income)
print("ceiling.capacity", C.UPGRADE_COST_CEILING.capacity)
print("LOSS_CAP", C.LOSS_CAP.fraction, C.LOSS_CAP.window)
print("REVENGE", C.revengePayout(), C.REVENGE.window)
print("RESIDENTS.pigSeconds", C.RESIDENTS.pigSeconds, C.RESIDENTS.stealCooldown)
print("STARS", C.WANTED_STARS.max, C.WANTED_STARS.payoutPerStar, C.getStarPayout(C.WANTED_STARS.max))
print("crackTotal", C.getCrackTotal(0), C.getCrackTotal(4))
print("smashFrac", C.getSmashFraction(0), C.getSmashFraction(4))
print("cycle.house", C.robberyCycleSeconds(C.CRACK.maxSteps))
print("cycle.shop", C.robberyCycleSeconds(C.CRACK.maxSteps, C.shopVaultRunStuds()))
print("shopVaultPigSeconds", C.shopVaultPigSeconds())
print("#houses")
for i, t in ipairs(C.HOUSE_TIERS) do print(i - 1, t.name, t.cost) end
print("#levels level,capacity,income_rb0,incomeCost,capacityCost,incomeCurve,capCurve")
for L = 1, C.ABSOLUTE_MAX_LEVEL do
  print(L, C.getCapacity(L), C.getIncomeRate(L, 0), C.getIncomeCost(L), C.getCapacityCost(L))
end
print("#rebirths rb,maxLevel,threshold,mult")
for rb = 0, C.rebirthsToMax() + 2 do
  print(rb, C.maxLevel(rb), C.getRebirthThreshold(rb), C.rebirthIncomeFactor(rb))
end
print("#robbery level,rb,coldPerHour,hotPerHour,idlePerHour")
for _, p in ipairs({{1,0},{20,0},{22,1},{30,5},{40,10}}) do
  local cold, idle = C.robberyRates(p[1], p[2], 0)
  local hot = C.robberyRates(p[1], p[2], C.WANTED_STARS.max)
  print(p[1], p[2], cold, hot, idle)
end
print("#trees key,max,total")
for key, def in pairs(C.UPGRADES) do
  local total = 0
  for lvl = 0, def.max - 1 do total += C.getUpgradeCost(key, lvl) end
  print(key, def.max, total)
end
print("#audit", #C.auditEconomy(), #C.auditRobbery())
'''

def main():
    config = (ROOT / "src/ReplicatedStorage/Shared/Config.luau").read_text(encoding="utf-8")
    bundle = PRELUDE + "\nlocal Config = loadConfig(" + literal(config) + ")\n" + DUMP
    with tempfile.TemporaryDirectory(prefix="piggy-dump-") as folder:
        script = Path(folder) / "dump.luau"
        script.write_text(bundle, encoding="utf-8")
        out = subprocess.run([str(LUAU), str(script)], capture_output=True, text=True)
        print(out.stdout)
        if out.returncode:
            print("STDERR:", out.stderr)
        return out.returncode

if __name__ == "__main__":
    raise SystemExit(main())
