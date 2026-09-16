-- Actual audit functions, boot warnings and event reward paths, isolated
-- from Roblox rendering and saved player data. Every audit rule is provoked.
local Config,sources=...
local checks=0
local function check(ok,message) assert(ok,message);checks+=1 end
local function contains(problems,code)
 for _,p in problems do if p:find("["..code.."]",1,true) then return true end end;return false
end
local function provoke(tbl,key,value,audit,code)
 local old=tbl[key];tbl[key]=value
 local ok,problems=pcall(audit)
 tbl[key]=old
 check(ok and contains(problems,code),"audit catches "..code.." at "..key)
end
local A,R=Config.auditAcorns,Config.auditRandomOutcomes
check(#A()==0 and #R()==0,"new boot audits clean")
check(#Config.auditEconomy()==0 and #Config.auditSkinSteal()==0,"existing audits remain clean")
local solo,full=Config.acornRates(1),Config.acornRates(Config.MAX_PLAYERS)
check(solo.mintedPerHour==10 and solo.perThiefPerHour==10,"solo faucet derived from ten trees")
check(full.residents==2 and full.serverPerHour==42 and full.perThiefPerHour==5.25,"full-server population model")
check(Config.acornRates(4).serverPerHour==26,"intermediate population matches street circuit")
check(solo.passiveDaily==6 and solo.activeDaily==28 and full.activeDaily==18.5,"daily assumptions explicit: one passive raid and two active hours")
check(math.abs(full.commonMinutes-57.1428571)<.001 and math.abs(full.legendaryHours-7.6190476)<.001,"crate times derived from prices and faucet")
check(solo.initialResidentSupply==36 and full.initialResidentSupply==8,"seed is separate from steady hourly production")
check(full.ownHarvestPerHour==1.25,"own harvest model does not apply theft multipliers")
for n=1,Config.MAX_PLAYERS do
 local rate=Config.acornRates(n)
 check(rate.serverPerHour==(if n==1 then 10 else n*5+(10-n)),"every raw Acorn counted once at its delivery multiplier")
end
provoke(Config.ACORNS,"resident",nil,A,"acorn.config")
for _,v in {-1,1.5,math.huge,0/0} do provoke(Config.ACORNS.resident,"seedRipe",v,A,"acorn.resident") end
provoke(Config.ACORNS.resident,"seedStored",9,A,"acorn.resident")
provoke(Config.ACORNS.resident,"harvestSeconds",0,A,"acorn.resident")
provoke(Config.ACORNS.resident,"raidSeconds",7200,A,"acorn.resident")
provoke(Config,"ACORNS",nil,A,"acorn.config")
for _,v in {0,-1,math.huge,0/0} do provoke(Config.ACORNS,"growSeconds",v,A,"acorn.number") end
provoke(Config.ACORNS,"growCap",nil,A,"acorn.number")
provoke(Config.ACORNS,"share",0,A,"acorn.share")
provoke(Config.ACORNS,"share",1.1,A,"acorn.share")
provoke(Config.ACORN_AUDIT,"minActiveRatio",nil,A,"acorn.model")
provoke(Config.ACORNS.payout,"revenge",0,A,"acorn.multiplier")
provoke(Config.ACORNS.payout,"perRebirthAbove",-1,A,"acorn.multiplier")
provoke(Config,"MAX_PLAYERS",Config.PLOT_COUNT+1,A,"acorn.population")
provoke(Config,"PLOT_COUNT",10.5,A,"acorn.population")
provoke(Config.ACORNS,"lossCap",3.5,A,"acorn.whole")
provoke(Config.ACORNS,"growSeconds",7200,A,"acorn.growth")
provoke(Config.ACORNS,"lossCap",5,A,"acorn.lossCap")
provoke(Config.ACORNS,"lossWindow",1800,A,"acorn.lossCap")
provoke(Config.CHESTS.og,"cost",0,A,"acorn.price")
provoke(Config.ACORNS.payout,"player",1,A,"acorn.populationFloor")
provoke(Config.ACORN_AUDIT,"activeHours",.1,A,"acorn.activeFloor")
provoke(Config.ACORN_AUDIT,"passiveRaids",4,A,"acorn.passive")
provoke(Config,"LOOT",{event={attend=3}},A,"acorn.legacyFaucet")
for _,key in {"spree","boost","income"} do provoke(Config.ACORNS.payout,key,2,A,"acorn.coinMultiplier") end
for _,v in {"coins","unknown",false} do provoke(Config.CHESTS.og,"currency",if v==false then nil else v,R,"random.currency") end
for _,v in {0,1.5,math.huge,0/0} do provoke(Config.CHESTS.og,"cost",v,R,"random.price") end
provoke(Config,"chestPool",function() error("broken pool") end,R,"random.pool")
provoke(Config.SKINS.bronze,"cost",0,R,"random.coinTag")
provoke(Config.SKINS.martian,"cost",100,R,"random.coinPool")
provoke(Config.SKINS.martian,"pass","test",R,"random.passPool")
provoke(Config,"_auditFixture",{nested={unlockRebirths=1}},R,"random.rebirthGate")
local protected
for key,spec in Config.SKINS do if spec.pass then protected=key;break end end
check(protected~=nil,"catalogue has real protected pass skin")
local originalStealable=Config.isStealableSkin
provoke(Config,"isStealableSkin",function(key) return key==protected or originalStealable(key) end,R,"random.passTheft")
provoke(Config.SKIN_STEAL,"chance",.5,R,"random.theft")
provoke(Config,"REBIRTH_CRATE","missing",R,"random.rebirthCrate")
provoke(Config.COIN_PACK,"productId",-1,R,"random.coinPackId")
provoke(Config.COIN_PACK,"productId",123456,R,"random.paidRebirth")
-- Cycles/shared references cannot trap the recursive tag/gate sweep.
local cycle={};cycle.self=cycle;Config._auditFixture=cycle
check(#R()==0,"recursive sweep handles cycles");Config._auditFixture=nil
-- Removing historical coin prices must preserve every resale amount and tier.
local sales={galaxy=40000,vaporwave=95238,stormwolf=125000,hotwire=18750,
 bubblegum=2000,ultraviolet=95238,plasma=95238,bee=40000,giraffe=40000,ladybird=6250,
 pearl=40000,mint=5000,sunset=11250,hyperdrive=1000000,midnight=22500,lava=40000,
 synthwave=95238,cow=8750,neonmint=10000,zebra=40000,cyberlime=3000,laserdream=55000,
 leopard=40000,gridrunner=95238}
for key,value in sales do
 check(Config.sellValue("skin",key)==value and Config.isSellable("skin",key),key.." resale unchanged")
 check(Config.SKINS[key].cost==nil and Config.SKINS[key].sellBasis>0 and Config.SKINS[key].rarity~=nil,key.." resale metadata separate from coin price")
 check(not Config.isSkinUnlocked(key,{},100),key.." not made free by removing price")
end
check(Config.COIN_PACK.productId==0 and Config.CHESTS[Config.REBIRTH_CRATE].odds.rare==65,"standard random rebirth crate retained; pack disabled")

local function load(name,env,source)
 local run=assert(loadstring(source or sources[name],name));setfenv(run,setmetatable(env,{__index=getfenv()}));return run()
end
local names=setmetatable({},{__index=function(_,k) return k end})
local replicated={Shared=names}
local dataSource,n=sources.DataService:gsub("return DataService%s*$","return {defaults=defaultData}");assert(n==1)
local Data=load("DataService",{game={JobId="audit-tests",GetService=function(_,name) return if name=="ReplicatedStorage" then replicated else {} end},require=function() return Config end},dataSource)
local player={DisplayName="Test"};local data,events,saves,rolls,now
local modules={Config=Config,AlienModel={},PlotService={},CosmeticsService={},PlayerGear={},PassService={},TrophyService={}}
modules.Remotes={get=function(name) return {FireClient=function(_,p,payload) events[name]=payload end,
 FireAllClients=function(_,payload) events[name]=payload end} end}
modules.DataService={get=function() return data end,save=function() saves+=1;return true end}
local env={game={GetService=function(_,name)
 if name=="Players" then return {GetPlayers=function() return {player} end} end
 return if name=="ReplicatedStorage" then replicated else {}
end},script={Parent=names},require=function(name) return assert(modules[name],name) end,
 os={clock=function() return now end},task={wait=function(seconds) now+=seconds end}}
modules.SetService=load("SetService",env)
modules.SetService.award=function() error("event path tried to mint Acorns") end
local eventSource,n=sources.EventService:gsub("return EventService%s*$","return {raid=rewardRaid,rush=runRush,multiplier=EventService.getStealMultiplier}");assert(n==1)
local Event=load("EventService",env,eventSource)
local function reset(complete)
 data=Data.defaults();data.loot=23;data.coins=17;events={};saves=0;now=0
 if complete then
  for _,entry in Config.SETS.alien.items do modules.SetService.grant(player,entry.kind,entry.key) end
  events={};saves=0
 end
end
for _,cleared in {false,true} do
 for _,complete in {false,true} do
  reset(complete);Event.raid(cleared)
  local bounty=math.floor(Config.getIncomeRate(data.incomeLevel,data.rebirths)*Config.RAID.bountySeconds*(if cleared then 1.5 else 1))
  check(data.loot==23 and data.coins==17+bounty,"raid preserves coin bounty without Acorns")
  check((events.EventDrop~=nil)==not complete,"raid keeps free unowned drop; full set has no duplicate payout")
  check(next(data.spares)==nil,"completed raid never mints spares")
 end
end
reset(false);Event.rush()
check(data.loot==23 and data.coins==17 and saves==0,"Rush Hour settlement has no currency faucet")
check(events.EventState.stealMultiplier==Config.RUSH.stealMultiplier and Event.multiplier()==1,"Rush coin-steal multiplier still starts and resets")
reset(true);modules.SetService.rollDrop(player,"alien")
check(data.loot==23 and saves==0 and events.Notify:find("already own",1,true),"full set provides feedback without bonus currency")
-- Stale/malicious coin purchase requests still cannot grant unowned crate
-- skins after their historical cost fields have been removed.
local Cosmetics=load("CosmeticsService",env)
for key in sales do
 reset(false);Cosmetics.buySkin(player,key)
 check(data.coins==17 and data.loot==23 and not data.cosmetics.owned[key] and saves==0,
  key.." direct coin request cannot grant a now-unpriced crate skin")
end
-- Execute the actual new boot block; warnings never throw or stop startup.
local boot=assert(sources.Main:match("(%-%- Phase 1%.9 audits.-)ChestService%.start%(%)"))
local warnings,prints={},{ }
local bootEnv={Config=Config,warn=function(message) table.insert(warnings,message) end,print=function(message) table.insert(prints,message) end}
load("Main audits",bootEnv,boot)
check(#warnings==0 and #prints==1 and prints[1]:find("full capture, parity; seed/re-raids excluded",1,true),"clean boot reports model honestly")
local old=Config.COIN_PACK.productId;Config.COIN_PACK.productId=1
load("Main audits",bootEnv,boot);Config.COIN_PACK.productId=old
check(contains(warnings,"random.paidRebirth"),"boot surfaces paid-random conflict without throwing")
local originalAudit=Config.auditAcorns;Config.auditAcorns=function() error("test failure") end
load("Main audits",bootEnv,boot);Config.auditAcorns=originalAudit
check(warnings[#warnings]:find("could not run",1,true)~=nil,"failing audit warns and permits startup")
check(#A()==0 and #R()==0,"all deliberate faults restored")
print(("PASS: %d audit checks; all rules provoked, resale preserved, actual event rewards, boot warnings and model rates. No player saves."):format(checks))
