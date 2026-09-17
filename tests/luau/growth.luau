-- Real Config arithmetic and EconomyService, fake clock/services. No live saves.
local Config, source = ...
local checks = 0
local function check(ok, message) assert(ok, message); checks += 1 end
local now = 1000000
local hour = Config.ACORNS.growSeconds
check(hour == 3600, "one Acorn per hour")
for _, case in {{0,8},{3,8},{8,8},{20,20},{200,200}} do
 local data = {loot=200, treeAcorns=case[1], acornsGrownAt=now-8*hour}
 local gained = Config.growAcorns(data,now)
 check(data.treeAcorns==case[2] and data.loot==200 and gained==case[2]-case[1], "eight-hour catch-up respects cap and preserves larger balances")
 check(Config.growAcorns(data,now)==0, "same timestamp cannot earn twice")
end
local data={loot=200,treeAcorns=0,acornsGrownAt=now}
check(Config.growAcorns(data,now+hour-1)==0,"never pays early")
check(Config.growAcorns(data,now+hour)==1,"pays exactly on boundary")
check(Config.growAcorns(data,now+hour+1800)==0 and data.acornsGrownAt==now+hour,"partial hour survives tick")
local rejoined=table.clone(data)
check(Config.growAcorns(rejoined,now+2*hour)==1,"saved partial hour survives rejoin")
check(Config.growAcorns({loot=200,treeAcorns=0,acornsGrownAt=now-999*hour},now)==8,"long absence bounded")
data={loot=200,treeAcorns=7,acornsGrownAt=now-10*hour}
check(Config.growAcorns(data,now)==1 and data.acornsGrownAt==now,"cap discards surplus time")
data.treeAcorns=0
check(Config.growAcorns(data,now+hour-1)==0,"harvesting full tree cannot unlock banked hours")
check(Config.growAcorns(data,now+hour)==1,"growth resumes after harvesting")
for _,bad in {false, "123", {}, math.huge, -math.huge, 0/0, now+10*hour} do
 data={loot=200,treeAcorns=2,acornsGrownAt=bad}
 check(Config.growAcorns(data,now)==0 and data.acornsGrownAt==now,"invalid/future clock grants nothing")
end

local player={DisplayName="Tester"}
local plot={model={}}
local wallet
local snapshots,flights,plotCounts={},{},{}
local removed
local function signal() return {Connect=function(_,fn) return {Disconnect=function() end} end} end
local remotes=setmetatable({}, {__index=function(self,key)
 local remote={OnServerEvent=signal(),FireClient=function(_,p,state)
  assert(p==player)
  if key=="StateUpdate" then table.insert(snapshots,state) end
 end,FireAllClients=function(_,p,amount)
  assert(key=="AcornGrown" and p==plot.model);table.insert(flights,amount)
 end};rawset(self,key,remote);return remote
end})
local loop
local services={
 Config=Config,Remotes={get=function(key) return remotes[key] end},
 DataService={get=function() return wallet end},
 PlotService={getPlot=function() return plot end,updateAcorns=function(_,count) table.insert(plotCounts,count) end,
  updateTreeAcorns=function(_,ripe,ground) plot.ripe=ripe;plot.ground=ground end,
  updatePile=function() return 0 end,updateSign=function() end,playMilestone=function() end},
 SocialService={getFriendBonus=function() return 100 end},DailyService={getMultiplier=function() return 100 end},
}
local modules=setmetatable({}, {__index=function(_,key) return key end})
local env={require=function(key) return assert(services[key],key) end,
 script={Parent=modules},game={GetService=function(_,name)
  if name=="ReplicatedStorage" then return {Shared=modules} end
  assert(name=="Players");return {GetPlayers=function() return {player} end,
   PlayerRemoving={Connect=function(_,fn) removed=fn end}}
 end},os={time=function() return now end,clock=function() return now end},
 task={spawn=function(fn) loop=coroutine.create(fn);assert(coroutine.resume(loop)) end,
 wait=function() coroutine.yield() end}}
local run=assert(loadstring(source,"EconomyService"));setfenv(run,setmetatable(env,{__index=getfenv()}))
local E=run()
local function reset(amount,cursor)
 wallet={loot=200,treeAcorns=amount,groundAcorns=0,acornsGrownAt=cursor,lastSave=now-8*hour,coins=Config.getCapacity(1),capacityLevel=1,
  incomeLevel=1,rebirths=0,cosmetics={skin="classic"},houses={owned={shack=true},shown="shack"}}
end
reset(0,now-8*hour)
check(E.applyOfflineIncome(player)==0 and wallet.treeAcorns==8 and wallet.loot==200,"offline Acorns run even when pig is full")
check(#flights==0,"offline catch-up plays no live drops")
reset(20,now-8*hour);E.applyOfflineIncome(player)
check(wallet.treeAcorns==20 and wallet.loot==200,"offline path preserves over-cap wallet")
reset(2,now-hour);wallet.lastSave=now
E.applyOfflineIncome(player)
check(wallet.treeAcorns==3 and wallet.loot==200,"Acorn cursor survives recent coin autosave")
E.push(player)
check(snapshots[#snapshots].acorns==200 and plotCounts[#plotCounts]==200 and plot.ripe==3,"authoritative balance reaches HUD and plot")
E.start()
local function tick(seconds) now+=seconds;local ok,err=coroutine.resume(loop);assert(ok,err) end
tick(hour)
check(wallet.treeAcorns==4 and wallet.loot==200,"full pig still grows on live tick")
check(snapshots[#snapshots].acorns==200 and plotCounts[#plotCounts]==200 and plot.ripe==4,"live growth refreshes HUD and tree")
check(#flights==1 and flights[1]==1,"live growth broadcasts drop cue")
check(wallet.treeAcorns==4 and wallet.loot==200,"friend and daily boosts do not multiply Acorns")
wallet.loot=20;tick(1)
check(snapshots[#snapshots].acorns==20 and plotCounts[#plotCounts]==20,"external bonus is published without coin changes")
check(#flights==1,"external balance change does not pretend to be growth")
wallet.loot=0;tick(1)
check(snapshots[#snapshots].acorns==0 and plotCounts[#plotCounts]==0,"spending repaints empty storage")
check(wallet.loot==0,"full time is not banked")
wallet.groundAcorns=3;wallet.acornsDroppedAt=now-Config.ACORNS.groundSeconds
tick(1)
check(wallet.groundAcorns==0 and plot.ground==0 and wallet.treeAcorns==4,"expired ground clears without crediting storage or removing ripe stock")
removed(player);wallet=nil;tick(hour)
check(#flights==1,"departed player cannot grow")
print(("PASS: %d growth checks; offline/live cap, cursor, full pig, HUD/basket pushes and drop cue."):format(checks))
