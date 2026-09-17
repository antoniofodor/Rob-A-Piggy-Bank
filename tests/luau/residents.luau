-- Real resident stock model plus ResidentService seat/tick/evict integration.
-- All clocks, figures and coin worlds are isolated; no live saved data.
local Config,sources=...
local checks=0
local function check(ok,msg) assert(ok,msg);checks+=1 end
local names=setmetatable({}, {__index=function(_,k) return k end})
local function model()
 local fn=assert(loadstring(sources.ResidentAcorns,"ResidentAcorns"))
 setfenv(fn,setmetatable({game={GetService=function() return {Shared=names} end},require=function() return Config end},{__index=getfenv()}))
 return fn()
end
local M=model()
local stock=M.attach(1,false,0)
check(stock.acorns==2 and stock.treeAcorns==2 and stock.groundAcorns==0,"seed is four total, split across playable sources")
check(M.attach(1,false,10)==stock and stock.acorns==2,"duplicate seat cannot reseed")
check(M.attach(99,true,0)==nil,"shop never receives Acorn stock")
M.tick(stock,899,true)
check(stock.treeAcorns==2 and stock.acorns==2,"initial crop stays ripe for fifteen minutes")
M.tick(stock,900,false)
check(stock.treeAcorns==2 and stock.acorns==2,"resident away from home cannot harvest")
M.tick(stock,901,true)
check(stock.treeAcorns==0 and stock.acorns==4,"home resident moves ripe stock into storage without minting")
M.tick(stock,3599,true)
check(stock.acorns==4 and stock.treeAcorns==0,"harvesting preserves original hourly growth cursor")
M.tick(stock,3600,true)
check(stock.treeAcorns==1 and stock.acorns==4 and stock.harvestReadyAt==4500,"new crop gets its own fifteen-minute collection opportunity")
M.tick(stock,4499,true)
check(stock.treeAcorns==1,"crop cannot be harvested early")
M.tick(stock,4500,true)
check(stock.treeAcorns==0 and stock.acorns==5,"one grown Acorn becomes one stored Acorn")
stock.treeAcorns=0;stock.acorns=200
M.tick(stock,7200,false)
check(stock.treeAcorns==1 and stock.acorns==200,"large resident storage never blocks tree growth")

local protected=M.attach(2,false,0)
protected.collectingUntil=910
M.tick(protected,901,true)
check(protected.treeAcorns==2 and protected.acorns==2,"active collection prevents automatic stock movement")
M.tick(protected,910,true)
check(protected.acorns==4,"collection lease expiry releases harvest")
local loose=M.attach(3,false,0)
loose.groundAcorns=1;loose.acornsDroppedAt=899
M.tick(loose,900,true)
check(loose.treeAcorns==2 and loose.acorns==2,"resident does not harvest while loose Acorns remain")
M.tick(loose,959,true)
check(loose.groundAcorns==0 and loose.acorns==4,"missed ground expires and ripe stock can then be banked")

local paused=M.attach(4,false,0)
M.tick(paused,100,false);M.suspend(4,100);M.suspend(4,500)
check(paused.pausedAt==100,"repeated eviction does not reset pause start")
paused.acorns+=1 -- old in-flight receipt returns during occupancy
M.tick(paused,10000,true)
check(paused.treeAcorns==2 and paused.acorns==3,"player occupancy cannot grow a hidden resident tree")
check(M.attach(4,false,10100)==paused and paused.acorns==3,"reseat retains old stock and delayed refund")
M.tick(paused,13599,false)
check(paused.treeAcorns==2,"pause retains partial growth hour without premature catch-up")
M.tick(paused,13600,false)
check(paused.treeAcorns==3,"growth resumes exactly after the remaining hour")
M.suspend(4,13600);M.attach(4,false,20000)
check(paused.acorns+paused.treeAcorns==6,"repeated handovers never add seed")
local full=M.attach(5,false,0);full.treeAcorns=8
M.tick(full,10*3600,false)
check(full.treeAcorns==8 and full.acornsGrownAt==36000,"full tree cannot bank excess growth time")
full.treeAcorns=0;M.tick(full,36001,false)
check(full.treeAcorns==0,"emptying capped tree never unlocks a burst of stored time")

-- A day with no theft: automatic harvesting only redistributes the four seed
-- plus twenty-four hourly Acorns. No periodic refill or storage-based growth.
local sim=model();local day=sim.attach(1,false,0)
for t=1,24*60 do sim.tick(day,t*60,true) end
check(day.acorns+day.treeAcorns+day.groundAcorns==28,"24-hour production conserves four seed plus 24 grown")
check(day.treeAcorns==1 and day.acorns==27,"last fresh crop remains ripe for collection")
local street=model();local seeds=0
for index=1,14 do
 local s=street.attach(index,index>10,0)
 if s then seeds+=s.acorns+s.treeAcorns end
end
check(seeds==40,"ten residential plots seed forty once; four shops seed nothing")

-- Exercise actual ResidentService wiring with only scene construction stubbed.
local now=10000
local attributes={}
local plots={}
local v=function(x,y,z) return {X=x or 0,Y=y or 0,Z=z or 0} end
local frame=setmetatable({}, {__mul=function(a,b) return a end})
local callbacks={}
local modules={Config=Config,ResidentAcorns=model(),Remotes={},DataService={},PiggyModel={},
 ResidentModel={build=function() error("isolated missing figure") end}}
modules.PlotService={updatePile=function(plot,coins) plot.coins=coins end,
 updateAcorns=function(plot,stored) plot.stored=stored end,
 updateTreeAcorns=function(plot,ripe,ground) plot.ripe=ripe;plot.ground=ground end,
 onClaim=function(fn) callbacks.claim=fn end,onRelease=function(fn) callbacks.release=fn end,
 getAll=function() return plots end}
local environment={require=function(name) return assert(modules[name],name) end,
 game={GetService=function(_,name)
  if name=="ReplicatedStorage" then return {Shared=names} end
  if name=="ServerScriptService" then return {WaitForChild=function() return names end} end
  if name=="Players" then return {GetPlayers=function() return {} end} end
  if name=="RunService" then return {Heartbeat={Connect=function() end}} end
 end},Vector3={new=v,zero=v()},CFrame={new=function() return frame end},
 os={time=function() return now end,clock=function() return now end},warn=function() end,
 task={spawn=function() end}}
local tail=[[
currentLevel=function() return Config.RESIDENTS.minLevel end
pickOffset=function() return 0 end
rollGarden=function() return {} end
pigSize=function() return 500 end
applyLevel=function() end
drawSkin=function() return "classic" end
ResidentService.testTick=tick
return ResidentService
]]
local code,n=sources.ResidentService:gsub("return ResidentService%s*$",tail);assert(n==1)
local run=assert(loadstring(code,"ResidentService"));setfenv(run,setmetatable(environment,{__index=getfenv()}));local R=run()
local function plot(index,shop)
 local attrs={}
 local p={index=index,shop=shop,base={Position=v(0,0,0),Size=v(64,1,64)},cframe=frame,
 model={SetAttribute=function(_,key,value) attrs[key]=value end}}
 p.attrs=attrs;return p
end
local home=plot(1);table.insert(plots,home)
local shop=plot(11,"test");table.insert(plots,shop)
R.start()
local resident=R.get(home)
check(resident and resident.acornStock and resident.loot==0,"real seat creates separate stock without using resident coin haul")
check(home.stored==2 and home.ripe==2 and home.ground==0,"real seat publishes both Acorn sources even without a figure")
check(R.get(shop).acornStock==nil and shop.stored==nil,"real shop seat publishes no Acorn balance")
R.seat(home)
check(R.get(home)==resident and home.stored==2,"real seat is idempotent")
now+=3600;resident.state="out";R.testTick()
check(home.ripe==3 and home.stored==2 and resident.coins==500,"real tick grows independently of full coin pig while resident is away")
resident.state="home";R.testTick()
check(home.ripe==0 and home.stored==5,"real home tick banks ripe crop")
callbacks.claim(home);home.owner={}
local oldStock=resident.acornStock
check(R.get(home)==nil and oldStock.pausedAt==now,"claim evicts and suspends resident supply")
now+=120;oldStock.acorns+=1
home.owner=nil;callbacks.release(home)
check(R.get(home).acornStock==oldStock and home.stored==6,"release resumes same stock including delayed receipt refund")
check(oldStock.raidReadyAt==nil,"resident stock carries no raid cadence (storage raids retired)")
print(("PASS: %d resident checks; seed, growth, harvest, leases, shop exclusion, handovers and actual service integration."):format(checks))
