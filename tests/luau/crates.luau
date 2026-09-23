-- Executes the real Config and full ChestService with isolated service doubles.
local Config, source = ...
local checks = 0
local function check(ok, message)
 assert(ok, message);checks += 1
end
local player = {}
local data, messages, granted, pushes, randomCalls, repaints
-- The first parameter used to be an Acorn balance. Crates carry no price, so
-- it is kept and ignored rather than deleted from thirty call sites.
local function reset(_unused, owned)
 data = {coins=1000000000, spares={}, owned=owned or {}}
 messages, granted, pushes, randomCalls, repaints = {}, {}, 0, 0, 0
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
 -- Fires the registered pusher without granting. Counted rather than ignored,
 -- because the bug it exists for was a repeat piggy written into a slot with
 -- nothing told to repaint it -- so "was anybody told" is the assertion.
 repaint=function(who, kind) assert(who == player);repaints += 1 end,
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

-- EVERY CRATE, AND NOT ONE OF THEM PRICED. They used to cost 15/45/120
-- acorns; a crate is earned now, so what this list is for is the sweep below.
local prices = {og=0, ograre=0, oglegendary=0, animal=0, animalrare=0, animallegendary=0, alien=0}
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
for key in prices do
 check(Config.CHESTS[key].currency == nil and Config.CHESTS[key].cost == nil, key .. " carries no price")
 reset()
 ChestService.grantFree(player, key)
 check(data.coins == 1000000000, key .. " costs nothing to open")
 check(#granted == 1 and messages.ChestResult ~= nil and pushes == 1, key .. " grants and pushes")
 check(messages.ChestState.chests[key].cost == nil, key .. " publishes no price")
 check(messages.ChestState.chests[key].canCombine == (key ~= "alien"), key .. " combine visibility")
end
check(ChestService.open == nil, "there is no charged open path")
check(not Config.canCombineChest("missing"), "unknown combine target")

-- A SECOND PIGGY IS A SECOND PIGGY, NOT A SPARE (designer ruling 2026-09-21;
-- docs/PIGGY-COLLECTION-PLAN.md §3/§4). This used to assert the WARDROBE
-- model -- a repeat skin paid one spare and the reveal called it a duplicate
-- so the reel could offer its sell value. A piggy is income standing on a
-- pedestal now, so a repeat is a real prize: it lands on the next free lawn
-- slot, makes no spare, and the reveal must not call it a duplicate.
local pool = Config.chestPool("og")
local common = pool.common[1]
reset(nil, {["skin:" .. common]=true})
ChestService.grantFree(player, "og")
check(next(data.spares) == nil, "a repeat piggy makes no spare")
check(Config.piggyPlacedCount(data, common) == 1, "it is standing on a pedestal instead")
check(data.piggies.owned[common] == 1, "and the collection counted it")
check(not messages.ChestResult.duplicate, "the reveal does not call it a duplicate")
check(messages.ChestResult.value == 0, "so it is not offered as a spare to sell")
check(repaints == 1, "and something was told to repaint the lawn")

-- A FULL LAWN REFUSES THE WHOLE CRATE, ahead of the roll AND the charge --
-- which is what makes placing the outcome above unconditional rather than a
-- thing that can fail. Without this gate a roll onto a full lawn would have
-- nowhere to put what it rolled.
reset()
for i = 1, Config.PIGGY_LAWN_SLOT_COUNT do
 Config.addPiggy(data, pool.common[math.min(i, #pool.common)], true)
end
check(Config.firstFreePiggySlot(data) == nil, "lawn filled for the test")
randomCalls = 0
ChestService.grantFree(player, "og")
check(randomCalls == 0 and messages.ChestResult == nil, "a full lawn refuses before rolling")
check(messages.Notify == "Your lawn is full. Make room for a piggy before you open a crate.",
 "naming the fix rather than failing silently")
reset()
ChestService.grantFree(player, "og")
check(data.coins == 1000000000 and #granted == 1, "the daily crate opens for nothing")

-- A PRICE PUT BACK ON A CRATE FAILS CLOSED AND IS AUDITED. It would be a paid
-- random item with none of the disclosure that rule demands, so the crate
-- refuses to open rather than quietly charging.
check(#Config.auditRandomOutcomes() == 0, "baseline random-outcome audit")
for _, field in {"currency", "cost"} do
 local chest = Config.CHESTS.og
 chest[field] = if field == "cost" then 15 else "loot"
 reset()
 ChestService.grantFree(player, "og")
 check(#granted == 0 and randomCalls == 0, "a priced crate fails closed: " .. field)
 local problems = Config.auditRandomOutcomes()
 check(#problems == 1 and problems[1]:find("og", 1, true) ~= nil, "audit detects the price: " .. field)
 chest[field] = nil
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
 check(data.coins == 1000000000, key .. " combine only spends spares")
end
reset()
ChestService.grantFree(player, "unknown")
check(#granted == 0 and next(messages) == nil, "unknown key is harmless")
check(#Config.auditEconomy() == 0 and #Config.auditRandomOutcomes() == 0, "audits restored after mutation tests")
print(("PASS: %d crate checks; unpriced crates, refusals, grants, duplicates, combines and audits. No player saves."):format(checks))
