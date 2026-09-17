-- Schema 26: houses by stable id. The migration matrix from
-- docs/LATE-GAME-ECONOMY-PLAN.md section 8.2, run against the real
-- DataService.reconcile and the real Config helpers -- no Studio, no saves.
local Config, sources = ...
local source = sources.DataService
local checks = 0
local function check(ok, message) assert(ok, message);checks += 1 end
local function copy(value)
 if type(value)~="table" then return value end
 local out={};for k,v in value do out[k]=copy(v) end;return out
end
local transformed,n=source:gsub("return DataService%s*$",[[
DataService.defaults=defaultData
DataService.reconcile=reconcile
return DataService
]])
assert(n==1)
local env={game={JobId="houses",GetService=function(_,name)
 if name=="ReplicatedStorage" then return {Shared={Config="Config"}} end
 return {}
end},require=function(key) assert(key=="Config");return Config end,
 task={wait=function() end},warn=function() end}
local run=assert(loadstring(transformed,"DataService"));setfenv(run,setmetatable(env,{__index=getfenv()}))
local D=run()
local ORDER=Config.HOUSE_LEGACY_ORDER

-- ---- CATALOGUE ------------------------------------------------------------
check(#ORDER==9,"nine legacy rungs")
local seen={}
for i,tier in ipairs(Config.HOUSE_TIERS) do
 check(type(tier.id)=="string" and not seen[tier.id],"every house carries a unique id")
 seen[tier.id]=true
 check(Config.getHouseById(tier.id)==tier,"id resolves to its own row")
 check(Config.houseLevelOf(tier.id)==i-1,"id resolves to its catalogue position")
end
for rung,id in ipairs(ORDER) do
 check(Config.getHouseById(id)~=nil,"legacy rung "..rung.." names a real house")
 check(Config.getHouseById(id)==Config.getHouseTier(rung-1),"legacy order still matches catalogue order for the nine")
end
check(Config.getHouseById("nothing")==nil and Config.getHouseById(3)==nil and Config.houseLevelOf(nil)==nil,"unknown ids resolve to nothing")
check(#Config.auditEconomy()==0,"auditEconomy clean with ids")
table.insert(Config.HOUSE_TIERS,{id="shack",name="Twin",style="shack",cost=1})
local dup=false
for _,p in Config.auditEconomy() do if p:find("repeats the id",1,true) then dup=true end end
table.remove(Config.HOUSE_TIERS)
check(dup,"audit refuses a duplicated id")
table.insert(Config.HOUSE_TIERS,{name="Nameless",style="shack",cost=1})
local missing=false
for _,p in Config.auditEconomy() do if p:find("has no id",1,true) then missing=true end end
table.remove(Config.HOUSE_TIERS)
check(missing,"audit refuses a house without an id")
check(#Config.auditEconomy()==0,"audit clean again")

-- ---- DEFAULTS -------------------------------------------------------------
local fresh=D.defaults()
check(fresh.schema==26,"schema is 26")
check(fresh.houseLevel==nil and fresh.houseShown==nil,"new saves carry no numeric house fields")
check(fresh.houses.owned.shack==true and fresh.houses.shown=="shack","new saves own and show the shack")
check(Config.getShownHouse(fresh).id=="shack","shown resolves on a fresh save")

-- ---- THE MATRIX -----------------------------------------------------------
local function legacy(level,shown,schema)
 local old=D.defaults();old.houses=nil;old.schema=schema or 25
 old.houseLevel=level;old.houseShown=shown;old.coins=4242;old.rebirths=3
 return old
end
local function ownedSet(data)
 local n=0;for _ in pairs(data.houses.owned) do n+=1 end;return n
end
local function matrix(level,shown)
 local loaded=D.reconcile(legacy(level,shown))
 check(loaded.houseLevel==nil and loaded.houseShown==nil,"legacy fields deleted")
 check(ownedSet(loaded)==level+1,("level %d owns %d houses"):format(level,level+1))
 for rung=0,8 do
  check((loaded.houses.owned[ORDER[rung+1]]==true)==(rung<=level),"owned set is exactly the rungs below the top")
 end
 local expect=Config.legacyShownHouseLevel(level,shown)
 check(loaded.houses.shown==ORDER[expect+1],("shown clamps: level %d shown %s -> %s"):format(level,tostring(shown),ORDER[expect+1]))
 check(Config.getShownHouse(loaded).id==loaded.houses.shown,"reader agrees with the save")
 check(loaded.coins==4242 and loaded.rebirths==3,"balances and rebirths untouched")
 local again=D.reconcile(copy(loaded))
 check(ownedSet(again)==level+1 and again.houses.shown==loaded.houses.shown,"second run adds no house and moves nobody")
end
for level=0,8 do
 for shown=0,level do matrix(level,shown) end
 matrix(level,nil)      -- pre-schema-9: never split, shows the newest
 matrix(level,level+3)  -- above the owned rung: clamped to the top
end
-- The plan's own acceptance case: a Sky Castle shown over a Marble Palace ladder.
local castle=D.reconcile(legacy(8,8))
check(ownedSet(castle)==9 and castle.houses.shown=="skycastle","level 8 shown 8 owns nine, shows the castle")
local villa=D.reconcile(legacy(8,3))
check(villa.houses.shown=="villa" and villa.houses.owned.skycastle,"living in the villa keeps the castle owned")
check(D.reconcile(D.reconcile(copy(villa))).houses.shown=="villa","twice is the same")

-- ---- NEVER GRANTS ---------------------------------------------------------
local nothing=D.defaults();nothing.houses=nil;nothing.houseLevel=nil;nothing.houseShown=7
local filled=D.reconcile(nothing)
check(ownedSet(filled)==1 and filled.houses.shown=="shack","a save with no level owns only the shack")
local junk=D.defaults();junk.houses=nil;junk.houseLevel="8";junk.houseShown=8
check(ownedSet(D.reconcile(junk))==1,"a string level is not a level")

-- ---- PRUNE AND FALLBACK ---------------------------------------------------
local stale=D.defaults();stale.houses={owned={shack=true,manor=true,ghost=true,palace="yes"},shown="ghost"}
local pruned=D.reconcile(stale)
check(pruned.houses.owned.ghost==nil and pruned.houses.owned.palace==nil,"unknown and non-true entries pruned")
check(pruned.houses.shown=="manor","unknown shown falls back to the dearest owned, never the shack")
local unowned=D.defaults();unowned.houses={owned={cottage=true},shown="skycastle"}
local fixed=D.reconcile(unowned)
check(fixed.houses.owned.shack==true and fixed.houses.shown=="cottage","unowned shown falls back; shack restored")
local broken=D.defaults();broken.houses={owned="nope",shown=42}
local mended=D.reconcile(broken)
check(mended.houses.owned.shack==true and mended.houses.shown=="shack","garbage houses table mends to the shack")
-- A save that already carries `houses` must not be re-derived from a stray level.
local both=D.defaults();both.houses={owned={shack=true,cottage=true},shown="cottage"};both.houseLevel=8;both.houseShown=8
local kept=D.reconcile(both)
check(ownedSet(kept)==2 and kept.houses.shown=="cottage" and kept.houseLevel==nil,"an id save beats a stray numeric level and the level is deleted")

-- ---- READER FALLBACK ------------------------------------------------------
check(Config.getShownHouse({}).id=="shack","no data reads as the shack")
check(Config.getShownHouse({houses={owned={villa=true,manor=true},shown="townhouse"}}).id=="manor","dearest owned wins over a shown house that is not owned")
check(Config.legacyShownHouseLevel(5,nil)==5 and Config.legacyShownHouseLevel(5,9)==5 and Config.legacyShownHouseLevel(5,2.7)==2 and Config.legacyShownHouseLevel(50,3)==3,"legacy clamp")


-- ---- BUYING AND MOVING IN, THROUGH THE REAL SERVICE ------------------------
local function loadModule(name, env, src)
 local run = assert(loadstring(src or sources[name], name))
 setfenv(run, setmetatable(env, {__index=getfenv()}));return run()
end
local replicated = {Shared={Config="Config", Remotes="Remotes", PlayerGear="PlayerGear"}}
local data, messages, saves, applied, pushes
local modules={Config=Config, PlayerGear={}, PassService={}, TrophyService={}}
modules.Remotes={get=function(name) return {FireClient=function(_,_,payload,kind) table.insert(messages,{name=name,text=payload,kind=kind}) end} end}
modules.DataService={get=function() return data end, save=function() saves+=1;return true end}
modules.PlotService={getPlot=function() return nil end}
modules.SetService={inUse=function() return false end, owns=function() return false end, grant=function() return false end}
local env={game={GetService=function(_,name) return if name=="ReplicatedStorage" then replicated else {} end},
 script={Parent=setmetatable({}, {__index=function(_,key) return key end})},
 require=function(key) return assert(modules[key],key) end, os={clock=function() return 0 end}}
modules.ChestService=loadModule("ChestService",env)
local Cos=loadModule("CosmeticsService",env)
Cos.applyToPlot=function() applied+=1 end
Cos.push=function() pushes+=1 end
local player={DisplayName="Test",Name="Test",UserId=1}
local function reset(level)
 data=D.reconcile(legacy(level,level));messages={};saves=0;applied=0;pushes=0
end
local function lastWarn() local m=messages[#messages];return m and m.kind=="warn" end

reset(0);data.coins=1e9;data.capacityLevel=60
Cos.buyHouse(player,"palace")
check(data.houses.owned.palace and data.houses.shown=="palace" and data.coins==1e9-40000000,"any house may be bought outright when it fits; no ladder")
check(not data.houses.owned.cottage,"buying the palace grants nothing below it")
check(applied==1 and saves==1 and pushes==1 and messages[#messages].kind=="good","purchase applies, saves, pushes and says so")
Cos.buyHouse(player,"palace")
check(lastWarn() and data.coins==1e9-40000000,"buying an owned, shown house is refused without a charge")
Cos.buyHouse(player,"shack")
check(data.houses.shown=="shack" and data.coins==1e9-40000000 and applied==2,"moving into an owned house is free")
Cos.buyHouse(player,"palace")
check(data.houses.shown=="palace" and applied==3,"and back again, still free")
Cos.buyHouse(player,"ghost")
check(lastWarn() and applied==3,"an unknown id is refused by name")
Cos.buyHouse(player,3)
check(lastWarn() and applied==3,"a numeric position is not an id any more")

reset(0);data.coins=100;data.capacityLevel=20
Cos.buyHouse(player,"cottage")
check(lastWarn() and messages[#messages].text:find("need",1,true) and not data.houses.owned.cottage,"too dear: coins line")
reset(0);data.coins=Config.getCapacity(1);data.capacityLevel=1
Cos.buyHouse(player,"skycastle")
check(lastWarn() and messages[#messages].text:find("hold",1,true) and not data.houses.owned.skycastle,"won't fit: grow-your-pig line, not a red number")
check(data.coins==Config.getCapacity(1),"a refusal never charges")

-- A rebirth leaves the shelf alone.
modules.CosmeticsService=Cos
local progEnv={game=env.game,script=env.script,require=env.require,os=env.os,math=math}
local Progression=loadModule("ProgressionService",progEnv)
reset(8);data.coins=1e12;data.capacityLevel=60;data.incomeLevel=60
if Progression.rebirth then
 pcall(Progression.rebirth, player)
 check(data.houses.owned.skycastle and data.houses.shown=="skycastle","rebirth keeps every house and the one standing")
end

print(("houses: %d checks passed"):format(checks))
