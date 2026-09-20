-- Actual DataService lifecycle with a copying in-memory DataStore double.
-- This checks serialization boundaries and session locks, not Roblox networking.
local Config, source = ...
local checks = 0
local function check(ok, message) assert(ok, message);checks += 1 end
local function copy(value)
 if type(value)~="table" then return value end
 local out={};for k,v in value do out[k]=copy(v) end;return out
end
local stored={}
local store={GetAsync=function(_,key) return copy(stored[key]) end,
 UpdateAsync=function(_,key,transform)
  local updated=transform(copy(stored[key]))
  if updated~=nil then stored[key]=copy(updated) end
  return copy(stored[key])
 end}
local transformed,n=source:gsub("return DataService%s*$",[[
DataService.defaults=defaultData
DataService.reconcile=reconcile
DataService.initStore=initStore
return DataService
]])
assert(n==1)
local function server(id)
 local env={game={JobId=id,GetService=function(_,name)
  if name=="ReplicatedStorage" then return {Shared={Config="Config"}} end
  if name=="DataStoreService" then return {GetDataStore=function() return store end} end
  return {}
 end},require=function(key) assert(key=="Config");return Config end,
 task={wait=function() end},warn=function() end}
 local run=assert(loadstring(transformed,"DataService"));setfenv(run,setmetatable(env,{__index=getfenv()}))
 local service=run();service.initStore();return service
end
local D=server("save-tests-a")
local fresh=D.defaults()
check(fresh.robberies==0 and next(fresh.claims)==nil,"new saves start with zero robberies and empty claims")
check(fresh.schema==26,"houses by id bumped the schema to 26")
for _,schema in {24,25} do
 local old=D.defaults();old.schema=schema;old.robberies=nil;old.claims=nil;old.totalStolen=1234567
 local loaded=D.reconcile(old)
 check(loaded.robberies==0 and next(loaded.claims)==nil,"old save gets both defaults")
 check(loaded.totalStolen==1234567,"coin history preserved without inventing robbery history")
 check(D.reconcile(copy(loaded)).robberies==0,"default reconciliation is idempotent")
end
for _,case in {{37,37},{37.9,37},{-4,0},{"12",0},{false,0},{{},0},{math.huge,0},{-math.huge,0},{0/0,0}} do
 local saved=D.defaults();saved.robberies=case[1]
 local loaded=D.reconcile(saved)
 check(loaded.robberies==case[2],"counter reconciles to a finite nonnegative integer")
 check(D.reconcile(copy(loaded)).robberies==case[2],"normalized counter is stable on rejoin")
end
local dormant=D.defaults()
dormant.pets.owned.piglet=true;dormant.pets.equipped="piglet"
dormant.dogs.kennels.midnight=true;dormant.dogs.kennel="midnight"
local kept=D.reconcile(copy(dormant))
check(kept.pets.owned.piglet and kept.pets.equipped=="piglet", "paused pet purchases survive reconciliation")
check(kept.dogs.kennels.midnight and kept.dogs.kennel=="midnight", "retired kennel purchases survive reconciliation")
local at=os.time()
check(math.abs(fresh.acornsGrownAt-at)<=1,"new saves start the Acorn clock now")
local oldGrowth=D.defaults();oldGrowth.acornsGrownAt=nil;oldGrowth.lastSave=at-Config.OFFLINE_CAP_SECONDS;oldGrowth.loot=0
local migrated=D.reconcile(oldGrowth)
check(math.abs(migrated.acornsGrownAt-oldGrowth.lastSave)<=1,"legacy cursor begins at lastSave within offline allowance")
check(Config.growAcorns(migrated,os.time())==8 and migrated.treeAcorns==8 and migrated.loot==0,"legacy eight-hour absence earns eight exactly")
for _,bad in {false,"yesterday",{},math.huge,-math.huge,0/0,at+10000} do
 local broken=D.defaults();broken.acornsGrownAt=bad
 local fixed=D.reconcile(broken)
 check(math.abs(fixed.acornsGrownAt-os.time())<=1,"bad growth cursor reconciles safely")
end
local p={UserId=123,Name="Isolated",Parent=true}
local key="Player_123"
local stockSave=D.defaults();stockSave.loot=24;stockSave.treeAcorns=nil;stockSave.groundAcorns=nil
local stockMigrated=D.reconcile(stockSave)
check(stockMigrated.loot==24 and stockMigrated.treeAcorns==0 and stockMigrated.groundAcorns==0,"old wallet stays in storage without copying to tree")
local dropped=D.defaults();dropped.treeAcorns=3;dropped.groundAcorns=2;dropped.acornsDroppedAt=at
local preserved=D.reconcile(dropped)
check(preserved.treeAcorns==3 and preserved.groundAcorns==2,"fresh ground and tree stock survive reconciliation")
dropped.acornsDroppedAt=at-Config.ACORNS.groundSeconds-1
check(D.reconcile(dropped).groundAcorns==0,"expired ground cannot reappear after rejoin")
local legacy=D.defaults();legacy.robberies=nil;legacy.claims={bronze=Config.seasonIndex(),goldleaf=Config.seasonIndex()-1};legacy.coins=987;legacy.loot=21
stored[key]={data=legacy}
local loaded=assert(D.load(p))
check(loaded.robberies==0 and loaded.claims.bronze==Config.seasonIndex() and loaded.claims.goldleaf==nil,"load fills counter and prunes only expired claims")
check(loaded.coins==987 and loaded.loot==21,"load preserves balances")
check(D.load(p)==loaded and loaded.sessions==1,"repeated load reuses cached session")
loaded.robberies=8
loaded.acornsGrownAt=at-1800
check(stored[key].data.robberies==nil,"cache mutation is not mistaken for a persisted write")
check(D.save(p) and stored[key].data.robberies==8,"normal save serializes counter")
check(stored[key].data.acornsGrownAt==at-1800,"autosave preserves partial Acorn hour")
local B=server("save-tests-b")
check(B.load(p)==nil and stored[key].data.robberies==8,"other live session cannot overwrite progress")
local releases=0
D.onBeforeRelease(function(who)
 check(who==p and D.get(who)==loaded,"before-release hook sees live cached wallet")
 releases+=1
 loaded.loot+=2
end)
loaded.robberies=9
check(stored[key].data.robberies==8,"later cache changes await another save")
D.release(p)
check(D.get(p)==nil and stored[key].lock==nil and stored[key].data.robberies==9,"release flushes latest count and releases lock")
local rejoined=assert(B.load(p))
check(rejoined.robberies==9 and rejoined.sessions==2,"new server reloads lifetime count")
check(rejoined.claims.bronze==Config.seasonIndex() and rejoined.coins==987 and rejoined.loot==23,"rejoin preserves valid claims and balances")
check(rejoined.acornsGrownAt==at-1800,"release and rejoin preserve partial Acorn hour")
D.release(p)
check(releases==1,"before-release hook runs once, not after cache removal")
B.release(p)
check(not B.save(p),"departed session cannot save stale data")
print(("PASS: %d save checks; defaults, normalization, save/release/rejoin and session ownership using an isolated DataStore double. No live player saves."):format(checks))
