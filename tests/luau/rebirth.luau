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
 old.loot=17;old.coins=123;old.spares={};local migrated=Data.reconcile(old)
 local count=0;for _, key in keys do if migrated.cosmetics.owned[key] then count+=1 end end
 check(count==case[2] and migrated.schema==26, "threshold migration " .. case[1])
 check(migrated.loot==17 and migrated.coins==123 and next(migrated.spares)==nil, "migration never pays currency/spares")
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
check(Data.defaults().schema==26 and not Data.defaults().cosmetics.owned.bronze, "new saves earn no legacy grants")
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

local data, player, messages, saves, grants, randomCalls
local now=10
local modules={Config=Config, PlayerGear={}, PassService={}, TrophyService={}}
modules.Remotes={get=function(name) return {FireClient=function(_,_,payload) messages[name]=payload end} end}
modules.DataService={get=function() return data end, save=function() saves+=1;return true end}
modules.PlotService={getPlot=function() return nil end}
modules.SetService={
 inUse=function() return false end,
 owns=function(save,kind,key) return kind=="skin" and save.cosmetics.owned[key]==true end,
 grant=function(_,kind,key)
  assert(kind=="skin")
  if data.cosmetics.owned[key] then return false end
  data.cosmetics.owned[key]=true;grants+=1;return true
 end,
}
local mathFake=table.clone(math)
local randomValue = 0
mathFake.random=function(lo) randomCalls+=1;return lo or randomValue end
local env={game={GetService=function(_,name) return if name=="ReplicatedStorage" then replicated else {} end},
 script={Parent=setmetatable({}, {__index=function(_,key) return key end})},
 require=function(key) return assert(modules[key],key) end,
 math=mathFake, os={clock=function() return now end},
}
modules.ChestService=loadModule("ChestService",env)
modules.CosmeticsService=loadModule("CosmeticsService",env)
check(modules.CosmeticsService.rollRebirthDrop==nil and modules.CosmeticsService.announceRebirthUnlocks==nil, "service drop API retired")
-- Plot rendering/equipping is outside this harness; record the actual request.
modules.CosmeticsService.equipSkin=function(_,key) data.cosmetics.skin=key end
modules.CosmeticsService.applyToPlot=function() end
modules.CosmeticsService.push=function() end
local Progression=loadModule("ProgressionService",env)
local function reset()
 data=Data.defaults();player={DisplayName="Test"};messages={};saves=0;grants=0;randomCalls=0;now+=3
end
-- Rebirth picks among the collections' Legendary crates; `pool.legendary` is
-- every legendary across them, `pool.rare` the OG crate's rares.
local pool={legendary={},rare=Config.chestPool("oglegendary").rare}
for _,crate in Config.REBIRTH_CRATES do
 for _,key in Config.chestPool(crate).legendary do table.insert(pool.legendary,key) end
end
check(#Config.REBIRTH_CRATES==2 and table.find(Config.REBIRTH_CRATES,"oglegendary") and table.find(Config.REBIRTH_CRATES,"animallegendary"), "rebirth draws from both collections")
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
 reset();data.loot=7;data.coins=19;randomValue=case[1]
 local tier,kind,key=modules.ChestService.grantFree(player,"oglegendary")
 check(tier==case[2] and kind=="skin" and key~=nil, "standard free crate can roll " .. case[2])
 check(data.loot==7 and data.coins==19 and grants==1 and randomCalls>0, "free crate rolls without charging")
 check(messages.ChestResult.chest=="oglegendary" and messages.ChestResult.odds.rare==65 and messages.ChestResult.odds.legendary==35, "normal crate reveal reports actual odds")
end
reset();randomValue=0;data.cosmetics.owned[pool.rare[1]]=true
modules.ChestService.grantFree(player,"oglegendary")
check(grants==0 and data.spares["skin:"..pool.rare[1]]==1 and messages.ChestResult.duplicate, "rebirth crate duplicate pays a normal spare")
reset();modules.ChestService.grantFree(player,"og")
check(randomCalls>0 and grants==1 and data.loot==0, "ordinary daily crate remains random and free")

-- Full rebirth flow: threshold, reset, standard crate and immediate save.
reset();data.coins=Config.getRebirthThreshold(0)-1
Progression.rebirth(player)
check(data.rebirths==0 and grants==0 and saves==0, "short gate refuses without reset/reward/save")
now+=3;data.coins=Config.getRebirthThreshold(0);data.incomeLevel=9;data.capacityLevel=8;data.loot=11
data.robberies=99;data.claims.bronze=Config.seasonIndex()
for key in Config.UPGRADES do data.upgrades[key]=2 end
Progression.rebirth(player)
check(data.rebirths==1 and data.coins==0 and data.incomeLevel==1 and data.capacityLevel==1, "rebirth reset preserved")
check(data.robberies==99 and data.claims.bronze==Config.seasonIndex(), "rebirth preserves lifetime robberies and seasonal claims")
for _,value in data.upgrades do check(value==0,"upgrade reset preserved") end
check(grants==1 and data.loot==11 and randomCalls>0 and data.cosmetics.skin=="classic", "fresh rebirth opens crate without charging or changing worn skin")
check(saves==1 and table.find(Config.REBIRTH_CRATES,messages.ChestResult.chest)~=nil and messages.ChestResult.tier=="rare", "rebirth persists and uses standard crate reveal")
Progression.rebirth(player)
check(grants==1 and saves==1 and data.rebirths==1, "repeat request cannot duplicate reward")
reset();data.coins=Config.getRebirthThreshold(0);data.loot=3
for _,key in pool.legendary do data.cosmetics.owned[key]=true end
Progression.rebirth(player)
check(data.coins==0 and data.loot==3+Config.rebirthCrateBonus() and data.rebirths==1 and grants==0 and saves==1, "complete collection rebirth pays Acorns only and saves")
check(randomCalls==0 and messages.Notify:find(("%d acorns"):format(Config.rebirthCrateBonus()),1,true)~=nil and messages.ChestResult==nil, "completed collection fallback does not roll a spare")
check(#Config.auditEconomy()==0, "audit restored after mutation tests")
print(("PASS: %d rebirth checks; migration thresholds, rejoin/idempotence, ownership, audit, standard crate rewards, fallback and progression. No player saves."):format(checks))
