-- Executes the real Config and full ChestService with isolated service doubles.
local Config, source = ...
local checks = 0
local function check(ok, message)
 assert(ok, message);checks += 1
end
local player = {}
local data, messages, granted, pushes, randomCalls
local function reset(acorns, owned)
 data = {loot=acorns, coins=1000000000, spares={}, owned=owned or {}}
 messages, granted, pushes, randomCalls = {}, {}, 0, 0
end
local Remotes = {get=function(name)
 return {FireClient=function(_, who, payload)
  assert(who == player);messages[name] = payload
 end}
end}
local SetService = {
 owns=function(save, kind, key) return save.owned[kind .. ":" .. key] == true end,
 grant=function(who, kind, key)
  assert(who == player);table.insert(granted, kind .. ":" .. key)
  data.owned[kind .. ":" .. key] = true;return true
 end,
 inUse=function() return false end,
}
local modules = {Config=Config, Remotes=Remotes,
 DataService={get=function(who) assert(who == player);return data end},
 SetService=SetService}
local randomValue = 0
local testMath = table.clone(math)
testMath.random = function(low, high)
 randomCalls += 1
 return if low then low else randomValue
end
local run = assert(loadstring(source, "ChestService"))
setfenv(run, setmetatable({
 game={GetService=function(_, name)
  if name == "Players" then return {} end
  assert(name == "ReplicatedStorage")
  return {Shared={Config="Config", Remotes="Remotes"}}
 end},
 script={Parent={DataService="DataService", SetService="SetService"}},
 require=function(key) return assert(modules[key], key) end,
 math=testMath,
}, {__index=getfenv()}))
local ChestService = run()
ChestService.registerBalancePusher(function() pushes += 1 end)

-- Tripled September 16 (MASTER-PLAN 19.5).
local prices = {og=15, ograre=45, oglegendary=120, animal=15, animalrare=45, animallegendary=120, alien=18}
-- The retired mixed crates stay retired, and every section names real crates.
check(Config.CHESTS.rarecrate==nil and Config.CHESTS.legendarycrate==nil, "mixed tier crates retired")
for _, section in Config.CRATE_SECTIONS do
 for _, key in section.chests do check(Config.CHESTS[key] ~= nil, section.name .. " lists " .. key) end
end
-- A tier crate draws only from its own collection, never a common.
for key, shelf in {ograre="og", oglegendary="og", animalrare="animal", animallegendary="animal"} do
 local pool, total = Config.chestPool(key)
 check(total > 0 and pool.common == nil and #(pool.rare or {}) > 0 and #(pool.legendary or {}) > 0, key .. " stocks rare and legendary only")
 for _, list in pool do for _, skin in list do
  check(Config.SKINS[skin].chest == shelf, key .. " draws only " .. shelf .. " skins")
 end end
end
for key, price in prices do
 check(Config.CHESTS[key].currency == "loot" and Config.CHESTS[key].cost == price, key .. " price")
 reset(price)
 ChestService.open(player, key)
 check(data.loot == 0 and data.coins == 1000000000, key .. " charges only Acorns")
 check(#granted == 1 and messages.ChestResult ~= nil and pushes == 1, key .. " grants and pushes")
 check(messages.ChestState.chests[key].currency == "loot", key .. " publishes Acorn price")
 check(messages.ChestState.chests[key].canCombine == (key ~= "alien"), key .. " combine visibility")
 reset(price - 1)
 ChestService.open(player, key)
 check(data.loot == price - 1 and data.coins == 1000000000 and #granted == 0, key .. " short balance unchanged")
 check(messages.Notify == "Need 1 more acorn. Shake trees to earn acorns.", key .. " shortfall and earning route")
 check(randomCalls == 0 and messages.ChestResult == nil, key .. " refuses before rolling")
end
check(not Config.canCombineChest("missing"), "unknown combine target")
reset(nil)
ChestService.open(player, "og")
check(messages.Notify == ("Need %d more acorns. Shake trees to earn acorns."):format(Config.CHESTS.og.cost), "missing balance treated as zero")
check(data.loot == nil and data.coins == 1000000000, "missing balance cannot spend coins")
reset(Config.CHESTS.og.cost + 0.9)
ChestService.open(player, "og")
check(data.loot == 0 and data.coins == 1000000000, "whole Acorn charging preserved")

-- An existing item pays one spare, with exactly the same Acorn charge.
local pool = Config.chestPool("og")
local common = pool.common[1]
reset(Config.CHESTS.og.cost, {["skin:" .. common]=true})
ChestService.open(player, "og")
check(data.spares["skin:" .. common] == 1 and #granted == 0, "duplicate yields one spare")
check(messages.ChestResult.duplicate and data.loot == 0, "duplicate is charged once")
reset(0)
ChestService.grantFree(player, "og")
check(data.loot == 0 and data.coins == 1000000000 and #granted == 1, "free daily crate remains free")

-- Provoke catalogue regressions, including an omitted currency. Restore each.
check(#Config.auditEconomy() == 0, "baseline economy audit")
for _, currency in {"coins", "typo", false} do
 local chest = Config.CHESTS.og
 chest.currency = if currency == false then nil else currency
 reset(100)
 ChestService.open(player, "og")
 check(data.loot == 100 and data.coins == 1000000000 and #granted == 0 and randomCalls == 0, "bad currency fails closed")
 check(not Config.canCombineChest("og"), "bad currency cannot combine")
 local problems = Config.auditEconomy()
 check(#problems == 1 and problems[1]:find("CHESTS.og", 1, true) ~= nil, "audit detects bad currency")
 chest.currency = "loot"
end

-- Exercise the existing legendary jump: every regular crate has this stock.
-- This checks eligibility/atomic spending, not the unchanged combine odds.
randomValue = 0.999
for key in prices do
 reset(0)
 local entry = "skin:" .. common
 data.spares[entry] = Config.COMBINE.need
 ChestService.combine(player, "common", key)
 if key == "alien" then
  check(data.spares[entry] == Config.COMBINE.need and #granted == 0, "event combine refused without spending")
 else
  check(data.spares[entry] == nil and #granted == 1, key .. " regular combine still works")
  check(messages.ChestResult.combined == true, key .. " combine reveal")
 end
 check(data.loot == 0 and data.coins == 1000000000, key .. " combine only spends spares")
end
reset(10)
ChestService.open(player, "unknown")
check(data.loot == 10 and #granted == 0 and next(messages) == nil, "unknown key is harmless")
check(#Config.auditEconomy() == 0, "audit restored after mutation tests")
print(("PASS: %d crate checks; prices, charging, refusals, grants, duplicates, free crates, combines and audit. No player saves."):format(checks))
