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
-- AGAINST `Config` RATHER THAN A PINNED 26, which is what this line was and
-- what made it a chore: it asserted the number the houses-by-id migration
-- happened to land on, so every later bump broke a test that was never about
-- the value. What it should have been checking all along is that the DEFAULTS
-- and Config agree -- a save written with one and reconciled against the
-- other is the actual failure, and it is invisible to a literal.
check(fresh.schema==Config.SCHEMA_VERSION,"a new save is stamped with the current schema")
-- Schema 27/28, the piggy collection (docs/PIGGY-COLLECTION-PLAN.md §3/§4a):
-- the till's own buffer, the collection, and the six dense lawn slots.
check(fresh.tillBuffer==nil,"the bank has no buffer: its income drips straight into coins")
check(fresh.piggies.till==Config.DEFAULT_SKIN,"the starter Classic is on the till")
check(fresh.piggies.owned[Config.DEFAULT_SKIN]==1,"and it is owned exactly once")
check(#fresh.piggies.slots==Config.PIGGY_LAWN_SLOT_COUNT,"one dense entry per lawn slot")
for i,entry in fresh.piggies.slots do
 check(type(entry)=="table" and entry.key==nil,"lawn slot "..i.." starts empty")
end
-- THE TILL NAMES A PIGGY THE CATALOGUE STILL HOLDS, OR IT NAMES CLASSIC -- and
-- the count moves with it, so `piggystate` goes on reading owned == standing.
local stale=D.defaults();stale.piggies.till="retired_zzz";stale.piggies.owned={retired_zzz=1}
local fixed=D.reconcile(stale)
check(fixed.piggies.till==Config.DEFAULT_SKIN,"a retired till falls back to Classic")
check(fixed.piggies.owned[Config.DEFAULT_SKIN]==1 and fixed.piggies.owned.retired_zzz==nil,"and the retired copy leaves the count as the Classic enters it")
check(D.reconcile(copy(fixed)).piggies.owned[Config.DEFAULT_SKIN]==1,"the till prune is idempotent")
local swapped=D.defaults();swapped.piggies.till="bronze";swapped.piggies.owned={bronze=1}
check(D.reconcile(swapped).piggies.till=="bronze","a valid swapped-on till is left alone")
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
-- SCHEMA 29: THE ACORN TRACK IS DELETED, NOT CONVERTED. A save carrying the
-- balance, the tree or the acorn-ranked season table loses all of them, and a
-- second pass finds nothing left to drop.
check(fresh.loot==nil and fresh.tree==nil and fresh.season==nil,"a new save carries no acorn track")
local acorny=D.defaults()
acorny.loot=24;acorny.tree={level=3};acorny.treeAcorns=8;acorny.groundAcorns=2
acorny.acornsGrownAt=at-1800;acorny.acornsDroppedAt=at
acorny.season={index=1,earned=500,tier=9,best=9,granted={}}
acorny.medals=5;acorny.tokens=7
local pruned=D.reconcile(acorny)
for _,field in {"loot","tree","treeAcorns","groundAcorns","acornsGrownAt","acornsDroppedAt","season","medals","tokens"} do
 check(pruned[field]==nil,"schema 29 drops "..field)
end
check(D.reconcile(pruned).loot==nil,"the prune is idempotent")
-- THE CAPACITY TREE IS RETIRED (the pig has no ceiling): `capacityLevel` is
-- pruned from every save, nothing is paid back for the rungs, and a fresh
-- save never carries it.
local capped=D.defaults();capped.capacityLevel=14;capped.coins=555
local uncapped=D.reconcile(capped)
check(uncapped.capacityLevel==nil and uncapped.coins==555,"capacityLevel is pruned and nothing is refunded for it")
check(D.reconcile(copy(uncapped)).capacityLevel==nil,"and that prune is idempotent")
check(D.defaults().capacityLevel==nil,"a fresh save never carries a capacity rung")
-- The two ROBBERY ledgers beside it are untouched: neither counted a currency.
check(type(pruned.nemesis)=="table" and type(pruned.defend)=="table","nemesis and defend survive the prune")
-- PIGGIES ROBBED (the street leaderboard): a field add filled by the generic
-- pass, so an older save gains a zero once and a real count survives.
check(fresh.piggiesStolen==0,"a new save starts with no piggies robbed")
local unrobbed=D.defaults();unrobbed.piggiesStolen=nil;unrobbed.schema=25
local robbed=D.reconcile(unrobbed)
check(robbed.piggiesStolen==0,"an older save gains a zero piggies-robbed count")
check(D.reconcile(copy(robbed)).piggiesStolen==0,"and that fill is idempotent")
local counted=D.defaults();counted.piggiesStolen=6
check(D.reconcile(counted).piggiesStolen==6,"a real piggies-robbed count is preserved")
for _,case in {{2.5,2},{-1,0},{"3",0},{0/0,0}} do
 local saved=D.defaults();saved.piggiesStolen=case[1]
 check(D.reconcile(saved).piggiesStolen==case[2],"piggies robbed reconciles to a finite nonnegative integer")
end
local p={UserId=123,Name="Isolated",Parent=true}
local key="Player_123"
local legacy=D.defaults();legacy.robberies=nil;legacy.claims={bronze=Config.seasonIndex(),goldleaf=Config.seasonIndex()-1};legacy.coins=987
stored[key]={data=legacy}
local loaded=assert(D.load(p))
check(loaded.robberies==0 and loaded.claims.bronze==Config.seasonIndex() and loaded.claims.goldleaf==nil,"load fills counter and prunes only expired claims")
check(loaded.coins==987,"load preserves the balance")
check(D.load(p)==loaded and loaded.sessions==1,"repeated load reuses cached session")
loaded.robberies=8
check(stored[key].data.robberies==nil,"cache mutation is not mistaken for a persisted write")
check(D.save(p) and stored[key].data.robberies==8,"normal save serializes counter")
local B=server("save-tests-b")
check(B.load(p)==nil and stored[key].data.robberies==8,"other live session cannot overwrite progress")
local releases=0
D.onBeforeRelease(function(who)
 check(who==p and D.get(who)==loaded,"before-release hook sees live cached wallet")
 releases+=1
 loaded.coins+=2
end)
loaded.robberies=9
check(stored[key].data.robberies==8,"later cache changes await another save")
D.release(p)
check(D.get(p)==nil and stored[key].lock==nil and stored[key].data.robberies==9,"release flushes latest count and releases lock")
local rejoined=assert(B.load(p))
check(rejoined.robberies==9 and rejoined.sessions==2,"new server reloads lifetime count")
check(rejoined.claims.bronze==Config.seasonIndex() and rejoined.coins==989,"rejoin preserves valid claims and the balance")
D.release(p)
check(releases==1,"before-release hook runs once, not after cache removal")
B.release(p)
check(not B.save(p),"departed session cannot save stale data")
print(("PASS: %d save checks; defaults, normalization, save/release/rejoin and session ownership using an isolated DataStore double. No live player saves."):format(checks))
