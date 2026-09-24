-- Real Config, ChestService, ProgressionService and reconciliation; all saves
-- and engine dependencies isolated. No live player or DataStore is touched.
local Config, sources = ...
local checks = 0
local function check(ok, message) assert(ok, message);checks += 1 end
local function copy(value)
 if type(value) ~= "table" then return value end
 local out = {};for k, v in value do out[k] = copy(v) end;return out
end
local function loadModule(name, env, source)
 local run = assert(loadstring(source or sources[name], name))
 setfenv(run, setmetatable(env, {__index=getfenv()}));return run()
end
local replicated = {Shared={Config="Config", Remotes="Remotes", PlayerGear="PlayerGear"}}
local dataEnv = {
 game={JobId="rebirth-tests", GetService=function(_, name)
  return if name=="ReplicatedStorage" then replicated else {}
 end},
 require=function(key) assert(key=="Config");return Config end,
}
-- Expose the real local functions only in the test chunk; production API stays
-- private. All preceding module code is compiled and executed unmodified.
local dataSource, replacements = sources.DataService:gsub("return DataService%s*$", "return {reconcile=reconcile, defaults=defaultData}")
assert(replacements==1)
local Data = loadModule("DataService", dataEnv, dataSource)
local keys = {"bronze", "goldleaf", "diamond"}
for _, case in {{0,0},{1,1},{2,1},{3,2},{4,2},{5,2},{6,3},{20,3}} do
 local old = Data.defaults();old.schema=24;old.rebirths=case[1]
 old.sinceLegendary=11;old.cosmetics.skin=if case[1]>=6 then "diamond" else "classic"
 old.coins=123;old.spares={};local migrated=Data.reconcile(old)
 local count=0;for _, key in keys do if migrated.cosmetics.owned[key] then count+=1 end end
 check(count==case[2] and migrated.schema==Config.SCHEMA_VERSION, "threshold migration " .. case[1])
 -- A MIGRATION MAY RESCALE AND MAY NEVER INVENT, which is the same invariant
 -- this line always asserted, stated in the one form that survives schema 30.
 -- These saves are schema 24, so they cross the coin re-denomination and their
 -- balance is expected to come out a thousand times larger -- and EXACTLY a
 -- thousand, which is what separates a rescale from a payout. Spares are still
 -- untouched: nothing about re-denominating coins hands over an item.
 check(migrated.coins==123*Config.COIN_REDENOMINATION and next(migrated.spares)==nil,
  "migration rescales currency and never invents it")
 check(migrated.sinceLegendary==nil, "pity field retired")
 local again=Data.reconcile(copy(migrated));local countAgain=0
 for _, key in keys do if again.cosmetics.owned[key] then countAgain+=1 end end
 check(countAgain==count, "rejoin is idempotent")
 if case[1]>=6 then
  check(again.cosmetics.skin=="diamond" and Config.isSkinUnlocked("diamond",again.cosmetics.owned,0), "equipped legacy skin preserved")
  again.cosmetics.owned.diamond=nil
  check(not Data.reconcile(copy(again)).cosmetics.owned.diamond, "schema 25 never restores a lost skin")
 end
end
local legacy = {rebirths=6, cosmetics={skin="goldleaf"}}
local migrated=Data.reconcile(legacy)
check(migrated.cosmetics.owned.bronze and migrated.cosmetics.owned.goldleaf and migrated.cosmetics.owned.diamond, "missing schema and owned table migrate")
check(Data.defaults().schema==Config.SCHEMA_VERSION and not Data.defaults().cosmetics.owned.bronze, "new saves earn no legacy grants")
local og = Config.chestPool("og")
for _, key in keys do
 local skin=Config.SKINS[key]
 check(skin.chest=="og" and skin.unlockRebirths==nil and table.find(og[skin.rarity],key)~=nil, key .. " in originals")
 check(Config.isStealableSkin(key), key .. " stealable")
 check(not Config.isSkinUnlocked(key,{},100) and Config.isSkinUnlocked(key,{[key]=true},0), key .. " ownership independent of rebirths")
 local _, chest=Config.skinSource(key);check(chest=="og", key .. " inventory source")
end
check(#Config.auditEconomy()==0 and #Config.auditSkinSteal()==0, "boot audits clean")
Config.SKINS.bronze.unlockRebirths=1
check(#Config.auditEconomy()==1, "audit catches restored skin gate")
Config.SKINS.bronze.unlockRebirths=nil
Config._migrationTest={nested={unlockRebirths=6}}
check(#Config.auditEconomy()==1, "audit catches gate anywhere in Config")
Config._migrationTest=nil
check(Config.rollRarity==nil and Config.getDropWeights==nil and Config.DROP_RARITIES==nil and Config.LEGENDARY_PITY==nil, "random rebirth API retired")

-- ============================================================
-- THE PENDING CONFIG BLOCK
-- ============================================================
--
-- The rebirth cadence needs two new things in `Config` and this agent may not
-- write that file: they are reported as OLD/NEW for the lead. Installed ONLY
-- IF ABSENT, so the suite exercises the code against the Config it will have
-- and goes dead the day the block lands. It cannot overwrite a real table, so
-- it cannot mask one that disagrees; the last line prints which mode it ran
-- in.
local pending = {}
if Config.REBIRTH_CRATES_RARE == nil then
 pending.REBIRTH_CRATES_RARE = true
 Config.REBIRTH_CRATES_RARE = {"ograre"}
end
if Config.REBIRTH_LEGENDARY_EVERY == nil then
 pending.REBIRTH_LEGENDARY_EVERY = true
 Config.REBIRTH_LEGENDARY_EVERY = 5
end

local data, player, messages, saves, grants, randomCalls, repaints
local now=10
local modules={Config=Config, PlayerGear={}, PassService={}, TrophyService={}}
modules.Remotes={get=function(name) return {FireClient=function(_,_,payload) messages[name]=payload end} end}
modules.DataService={get=function() return data end, save=function() saves+=1;return true end}
modules.PlotService={getPlot=function() return nil end}
-- THE DOUBLE MIRRORS THE REAL `SetService`, INCLUDING THE TWO THINGS THAT
-- ONLY EXIST FOR THE PIGGY COLLECTION. `grant` places a piggy for a skin
-- (`SetService.grant` does, `place = true`), and `repaint` exists at all --
-- a stub missing it is a nil call from inside `handOver`, which is what this
-- suite died on when a repeat skin stopped paying a spare. A double that
-- lags the thing it doubles reports a live bug that is not there.
local function ownedTable(save,kind)
 if kind=="skin" then return save.cosmetics.owned end
 if kind=="ride" then return save.rides.owned end
 if kind=="decor" then return save.decor.owned end
 -- THE GUARDIAN COATS, BECAUSE A REBIRTH CAN OPEN THEIR CRATE NOW. A coat
 -- travels every path a skin does (`SetService.ownedTable` is where the real
 -- answer lives, and it says `data.dogs.owned`), so a double that knows only
 -- three kinds reports a live bug that is not there -- which is exactly what
 -- it did the hour `guardian` landed on `Config.REBIRTH_CRATES_RARE`.
 if kind=="coat" then return save.dogs and save.dogs.owned end
 return nil
end
modules.SetService={
 inUse=function() return false end,
 owns=function(save,kind,key)
  local owned=ownedTable(save,kind);return owned~=nil and owned[key]==true
 end,
 grant=function(_,kind,key)
  local owned=ownedTable(data,kind)
  assert(owned,kind)
  if owned[key] then return false end
  owned[key]=true
  if kind=="skin" then Config.addPiggy(data,key,true) end
  grants+=1;return true
 end,
 repaint=function(_,kind) assert(kind=="skin" or kind=="coat");repaints+=1 end,
}
local mathFake=table.clone(math)
local randomValue = 0
-- `pickIndex` names WHICH entry of a tier the roll lands on; nil keeps the
-- old behaviour (the two-argument form returns its low bound), so every
-- existing check draws exactly what it always drew.
local pickIndex = nil
mathFake.random=function(lo,hi)
 randomCalls+=1
 if lo==nil then return randomValue end
 if hi==nil then return lo end
 return math.clamp(pickIndex or lo, lo, hi)
end
local env={game={GetService=function(_,name) return if name=="ReplicatedStorage" then replicated else {} end},
 script={Parent=setmetatable({}, {__index=function(_,key) return key end})},
 require=function(key) return assert(modules[key],key) end,
 math=mathFake, os={clock=function() return now end},
}
-- THE ROBUX ROUTE IS DOUBLED HERE AND EXERCISED IN THE `crates` SUITE, which
-- loads the real ProductService. What this suite needs from it is only that
-- `ChestService.push` can ask whether a player may be offered a paid random
-- item -- and the honest default for a double is PERMITTED, so nothing here
-- accidentally passes because a card was hidden.
local productDouble = {
 restricted=function() return false end,
 crateRobux=function() return 0 end,
 crateProduct=function() return 0 end,
 onCrateReceipt=function() end,
 onPolicy=function() end,
 start=function() end,
}
modules.ProductService=productDouble
modules.ChestService=loadModule("ChestService",env)
modules.CosmeticsService=loadModule("CosmeticsService",env)
check(modules.CosmeticsService.rollRebirthDrop==nil and modules.CosmeticsService.announceRebirthUnlocks==nil, "service drop API retired")
-- Plot rendering/equipping is outside this harness; record the actual request.
modules.CosmeticsService.equipSkin=function(_,key) data.cosmetics.skin=key end
modules.CosmeticsService.applyToPlot=function() end
modules.CosmeticsService.push=function() end
local Progression=loadModule("ProgressionService",env)
local function reset()
 data=Data.defaults();player={DisplayName="Test"};messages={};saves=0;grants=0;randomCalls=0;repaints=0;now+=3
end
-- Rebirth picks among the collections' Legendary crates; `pool.legendary` is
-- every legendary across them, `pool.rare` the OG crate's rares.
local pool={legendary={},rare=Config.chestPool("oglegendary").rare}
for _,crate in Config.REBIRTH_CRATES do
 for _,key in Config.chestPool(crate).legendary do table.insert(pool.legendary,key) end
end
check(#Config.REBIRTH_CRATES==1 and Config.REBIRTH_CRATES[1]=="oglegendary", "rebirth draws from the one piggy shelf")
check(#pool.legendary>1 and table.find(pool.legendary,"diamond")~=nil, "legendary stock includes Diamond")
for _, key in pool.legendary do
 local spec=Config.SKINS[key]
 check(spec.rarity=="legendary" and spec.chest~=nil and not Config.isEarnedElsewhere(spec), "completion pool excludes rare and exclusive skins")
end
check(not Config.rebirthCrateComplete({}), "fresh collection incomplete")
local complete={};for _,key in pool.legendary do complete[key]=true end
check(Config.rebirthCrateComplete(complete), "all eligible legendaries completes collection")
complete[pool.legendary[1]]=nil
check(not Config.rebirthCrateComplete(complete), "losing one legendary restores crate reward")
local open=Config.rebirthCratesOpen(complete)
check(#open==1 and Config.chestPool(open[1]).legendary and table.find(Config.chestPool(open[1]).legendary,pool.legendary[1]), "only the unfinished collection stays in the draw")

-- Free Legendary Crates use the exact shop odds, including rare outcomes.
for _,case in {{0,"rare"},{0.999,"legendary"}} do
 reset();data.coins=19;randomValue=case[1]
 local tier,kind,key=modules.ChestService.grantFree(player,"oglegendary")
 check(tier==case[2] and kind=="skin" and key~=nil, "standard free crate can roll " .. case[2])
 check(data.coins==19 and grants==1 and randomCalls>0, "free crate rolls without charging")
 check(messages.ChestResult.chest=="oglegendary" and messages.ChestResult.odds.rare==40 and messages.ChestResult.odds.epic==25 and messages.ChestResult.odds.legendary==35, "normal crate reveal reports actual odds")
end
-- NO CRATE EVER PAYS A DUPLICATE (designer, 2026-09-23), AND THAT IS A POOL
-- RULE. This check has now asserted three different answers to what a repeat
-- is worth -- a spare, then a second pedestal piggy -- and both were about an
-- outcome that can no longer happen: the pool a crate rolls from is filtered
-- to what the player does not own, at every tier, so the reveal cannot land on
-- something already held.
reset();randomValue=0
local repeatKey=pool.rare[1]
data.cosmetics.owned[repeatKey]=true
-- DERIVED RATHER THAN PINNED AT 1. A new save seats its own starter Classic on
-- the front pedestal now (the till earns nothing since 2026-09-23), so an
-- arrival lands on the next free one -- and what this check is actually about
-- is that the copy STANDS somewhere, because the roll below has to have
-- something to skip.
local firstFree=Config.firstFreePiggySlot(data)
check(firstFree~=nil and Config.addPiggy(data,repeatKey,true)==firstFree, "the first copy stands on the first free pedestal")
local tier,kind,key,duplicate=modules.ChestService.grantFree(player,"oglegendary")
check(tier=="rare" and kind=="skin" and key~=repeatKey, "the roll skipped the skin already owned")
check(grants==1 and repaints==0, "so it granted something new rather than repainting a pedestal")
check(data.piggies.owned[repeatKey]==1, "the owned copy is untouched")
check(next(data.spares)==nil, "and no crate outcome ever writes a spare")
check(duplicate==false and not messages.ChestResult.duplicate and messages.ChestResult.value==0, "the reveal never calls anything a duplicate")
-- NOR DOES ANY OTHER KIND, which reverses the split this block used to
-- assert. A ride or a decoration out of the set crate is a wardrobe item with
-- one copy each, so a repeat used to become a sellable spare; spares come from
-- STEALING and WILD PIGGIES now, and a crate is not a source of them.
-- IT WENT THROUGH THE ALIEN CACHE UNTIL 2026-09-23 AND GOES THROUGH THE
-- GUARDIAN CRATE NOW. That crate was deleted with the alien event, and it was
-- the only `kind = "set"` chest -- so it was also the only crate that could
-- hand over a RIDE. What is left that is not a skin is a COAT, which
-- exercises the same three properties this block is about: a non-skin pool,
-- the per-player filter, and no spare on any outcome.
--
-- DERIVED RATHER THAN NAMED, so the day a set chest comes back with the event
-- this picks it up instead of going on testing a coat. A crate that stocks
-- something other than a skin is the property under test; which crate that is
-- is not.
local nonSkin
for chestKey in Config.CHESTS do
 local odds,pool=modules.ChestService.liveOdds(chestKey)
 for poolTier,entries in pool do
  if odds[poolTier] then
   for _,entry in entries do
    local kind=Config.chestEntry(chestKey,entry)
    if nonSkin==nil and kind~="skin" then nonSkin=chestKey end
   end
  end
 end
end
check(nonSkin~=nil, "some crate still stocks a kind that is not a skin")
local setOdds,setPool=modules.ChestService.liveOdds(nonSkin)
local setTier,setIndex,setKind,setKey
for poolTier,entries in setPool do
 if setOdds[poolTier] then
  for i,entry in entries do
   local entryKind,entryKeyName=Config.chestEntry(nonSkin,entry)
   if entryKind~="skin" and setKind==nil then setTier,setIndex,setKind,setKey=poolTier,i,entryKind,entryKeyName end
  end
 end
end
check(setKind~=nil and setTier~=nil, nonSkin .. " stocks a kind that is not a skin")
reset();randomValue=0;pickIndex=setIndex
ownedTable(data,setKind)[setKey]=true
-- THE POOL IS FILTERED PER PLAYER, so the owned item is not even offered --
-- which is what `liveOdds` with a save reports and what the card discloses.
local filteredOdds,filteredPool=modules.ChestService.liveOdds(nonSkin,data)
local stillThere=false
for _,entries in filteredPool do
 for _,entry in entries do
  local entryKind,entryKeyName=Config.chestEntry(nonSkin,entry)
  if entryKind==setKind and entryKeyName==setKey then stillThere=true end
 end
end
check(not stillThere, "an owned non-skin item leaves the pool the roll reads")
local _=filteredOdds
modules.ChestService.grantFree(player,nonSkin)
check(next(data.spares)==nil, "so no kind pays a spare out of a crate")
check(messages.ChestResult==nil or messages.ChestResult.key~=setKey, "and the roll never lands on it")
check(data.piggies.owned[setKey]==nil, "a non-skin outcome touches no pedestal")
pickIndex=nil
reset();modules.ChestService.grantFree(player,"og")
check(randomCalls>0 and grants==1, "ordinary daily crate remains random and free")

-- Full rebirth flow: threshold, reset, standard crate and immediate save.
reset();data.coins=Config.getRebirthThreshold(0)-1
Progression.rebirth(player)
check(data.rebirths==0 and grants==0 and saves==0, "short gate refuses without reset/reward/save")
now+=3;data.coins=Config.getRebirthThreshold(0);data.incomeLevel=9
data.robberies=99;data.claims.bronze=Config.seasonIndex()
for key in Config.UPGRADES do data.upgrades[key]=2 end
Progression.rebirth(player)
check(data.rebirths==1 and data.coins==0 and data.incomeLevel==1 and data.capacityLevel==nil, "rebirth reset preserved, and no capacity rung to reset")
check(data.robberies==99 and data.claims.bronze==Config.seasonIndex(), "rebirth preserves lifetime robberies and seasonal claims")
for _,value in data.upgrades do check(value==0,"upgrade reset preserved") end
check(grants==1 and randomCalls>0 and data.cosmetics.skin=="classic", "fresh rebirth opens crate without charging or changing worn skin")
-- EVERY REBIRTH OPENS A CRATE AND EVERY FIFTH ONE OPENS A LEGENDARY
-- (designer, 2026-09-23). Rebirth one is not a fifth, so it draws from the
-- RARE ladder -- which is what stops the best crate in the game being the
-- reward at rebirth one and again at rebirth twenty.
check(saves==1 and table.find(Config.REBIRTH_CRATES_RARE,messages.ChestResult.chest)~=nil, "rebirth one draws from the rare ladder")
check(messages.ChestResult.tier=="rare", "and uses the standard crate reveal")
Progression.rebirth(player)
check(grants==1 and saves==1 and data.rebirths==1, "repeat request cannot duplicate reward")

-- THE FIFTH REBIRTH IS THE LEGENDARY RUNG, counted on the INCREMENTED count
-- so it lands on the rebirth a player would count on their fingers.
for _,at in {5,10} do
 reset();data.rebirths=at-1;data.coins=Config.getRebirthThreshold(at-1)
 Progression.rebirth(player)
 check(data.rebirths==at and table.find(Config.REBIRTH_CRATES,messages.ChestResult.chest)~=nil,
  ("rebirth %d opens a legendary crate"):format(at))
end
for _,at in {1,2,3,4,6} do
 reset();data.rebirths=at-1;data.coins=Config.getRebirthThreshold(at-1)
 Progression.rebirth(player)
 check(table.find(Config.REBIRTH_CRATES_RARE,messages.ChestResult.chest)~=nil,
  ("rebirth %d opens a rare crate"):format(at))
end

-- A RARE SHELF WITH NOTHING OPENABLE FALLS BACK TO THE LEGENDARY ONE rather
-- than paying nothing: without that, clearing the cheap shelf would silently
-- cost four rebirths out of five their reward.
--
-- DRIVEN BY POINTING THE LADDER AT A CRATE THAT IS NOT THERE, because with
-- today's catalogue the two shelves CANNOT diverge: `ograre` and `oglegendary`
-- both carry `floor = "rare"` over the `og` collection, so they stock exactly
-- the same pool and one runs out only when the other does. The fallback is
-- insurance against a ladder that names different shelves, and this is the one
-- condition that reaches it.
do
 reset();data.coins=Config.getRebirthThreshold(0)
 local real=Config.REBIRTH_CRATES_RARE
 Config.REBIRTH_CRATES_RARE={"nosuchcrate"}
 Progression.rebirth(player)
 Config.REBIRTH_CRATES_RARE=real
 check(grants==1 and table.find(Config.REBIRTH_CRATES,messages.ChestResult.chest)~=nil,
  "a rare ladder with nothing openable falls through to the legendary one")
end

-- NOTHING IS PAID INSTEAD. A crate has no price, so a finished collection is
-- SAID rather than silently paying zero -- and "finished" now means every
-- crate on both ladders has an empty unowned pool, because an exhausted pool
-- is what refuses an open.
reset();data.coins=Config.getRebirthThreshold(0)
for _,ladder in {Config.REBIRTH_CRATES, Config.REBIRTH_CRATES_RARE} do
 for _,crate in ladder do
  for _,keys in Config.chestPool(crate) do
   -- RESOLVED PER ENTRY RATHER THAN POURED INTO THE SKIN WARDROBE, because
   -- the rare ladder reaches the Guardian Crate and a coat is owned in
   -- `data.dogs.owned`. Filling the wrong table left the guardian pool
   -- unowned, so "every collection complete" picked it and the rebirth
   -- opened a crate this check says cannot exist.
   for _,entry in keys do
    local kind,key=Config.chestEntry(crate,entry)
    local owned=ownedTable(data,kind)
    if owned then owned[key]=true end
   end
  end
 end
end
Progression.rebirth(player)
check(data.coins==0 and data.rebirths==1 and grants==0 and saves==1, "complete collection rebirth opens nothing and saves")
check(messages.Notify:find("no crate left",1,true)~=nil and messages.ChestResult==nil, "completed collection is named rather than rolled")
check(Config.rebirthCrateBonus==nil, "the acorn fallback is retired")
check(#Config.auditEconomy()==0, "audit restored after mutation tests")
local shimmed = {}
for key in pending do table.insert(shimmed,key) end
table.sort(shimmed)
print(("PASS: %d rebirth checks; migration thresholds, rejoin/idempotence, ownership, audit, unowned-only crate pools, the rare/legendary cadence, fallback and progression. No player saves.%s"):format(checks,
 if #shimmed>0 then "\n      NOTE: pending Config applied by the harness: " .. table.concat(shimmed,", ") else ""))
