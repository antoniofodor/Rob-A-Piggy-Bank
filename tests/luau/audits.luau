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
local R=Config.auditRandomOutcomes
check(#R()==0,"random-outcome sweep clean")
check(#Config.auditEconomy()==0 and #Config.auditSkinSteal()==0,"existing audits remain clean")
-- THE ACORN FAUCET AUDIT STOOD HERE and went with the currency: it modelled
-- how fast a tree filled and what a crate therefore cost. What replaces it is
-- the stricter rule below -- a crate must carry NO price at all.
for _,key in {"currency","cost"} do
 provoke(Config.CHESTS.og,key,if key=="cost" then 15 else "loot",R,"random.price")
end
for _,chest in Config.CHESTS do
 check(chest.cost==nil and chest.currency==nil,"no crate carries a price")
end
for _,v in {"coins","unknown"} do provoke(Config.CHESTS.og,"currency",v,R,"random.price") end
for _,v in {0,1.5,math.huge,0/0} do provoke(Config.CHESTS.og,"cost",v,R,"random.price") end
provoke(Config,"chestPool",function() error("broken pool") end,R,"random.pool")
provoke(Config.SKINS.bronze,"cost",0,R,"random.coinTag")
-- A POOL ITEM, DERIVED RATHER THAN NAMED. Both rules fire on anything sitting
-- inside a crate pool, and both were provoked through `Config.SKINS.martian`
-- -- which was in a pool only because the Alien Cache put it there. That
-- crate was deleted on 2026-09-23, the Martian is in NO pool now, and neither
-- provoke fired: the suite reported the AUDIT as broken when the audit was
-- right, which is the harness-lags-the-game failure CLAUDE.md records for the
-- SetService double. Asking the pools which item to use cannot go stale when
-- a crate is added or retired.
local pooled
for chestKey in Config.CHESTS do
 for _,entries in Config.chestPool(chestKey) do
  for _,entry in entries do
   local kind,itemKey=Config.chestEntry(chestKey,entry)
   if pooled==nil and kind=="skin" and Config.SKINS[itemKey] then pooled=itemKey end
  end
 end
end
check(pooled~=nil,"a skin sits in some crate pool to provoke the pool rules with")
provoke(Config.SKINS[pooled],"cost",100,R,"random.coinPool")
-- `random.passPool` IS ONLY REACHABLE THROUGH A SET CHEST, so it needs a
-- fixture rather than a real row. For an ordinary chest `chestPool` drops
-- anything `isEarnedElsewhere` claims -- a pass skin included -- so the item
-- leaves the pool BEFORE the audit looks at it and the rule cannot fire. The
-- set branch walks `set.items` verbatim and excludes nothing, which made a set
-- the only pool that could ever hold a pass-exclusive item. The Alien Cache
-- was the only set chest and was deleted on 2026-09-23, so this rule kept its
-- reason to exist and lost the row that exercised it.
--
-- IT IS WORTH THE FIXTURE BECAUSE OF WHAT IT GUARDS: a paid exclusive sitting
-- inside a random pool is the one thing `set = true` and the pass catalogue
-- exist to prevent, and the next event crate will reach this branch for real.
-- Same shape as `Config._auditFixture` two lines down -- a table installed to
-- provoke a sweep and removed again -- and the tier is read BEFORE `pass` is
-- set, because `rarityOf` reads the spec being altered.
local fixtureTier=Config.rarityOf(Config.SKINS[pooled])
Config.SETS._auditSet={name="Audit Set",order=99,items={{kind="skin",key=pooled}}}
Config.CHESTS._auditSetChest={name="Audit Cache",order=99,kind="set",set="_auditSet",odds={[fixtureTier]=100}}
check(#R()==0,"the fixture set chest is clean before the rule is provoked")
local restorePass=Config.SKINS[pooled].pass
Config.SKINS[pooled].pass="test"
local passOk,passProblems=pcall(R)
Config.SKINS[pooled].pass=restorePass
Config.SETS._auditSet=nil
Config.CHESTS._auditSetChest=nil
check(passOk and contains(passProblems,"random.passPool"),"audit catches random.passPool in a set pool")
check(#R()==0,"and the fixture leaves nothing behind")
provoke(Config,"_auditFixture",{nested={unlockRebirths=1}},R,"random.rebirthGate")
local protected
for key,spec in Config.SKINS do if spec.pass then protected=key;break end end
check(protected~=nil,"catalogue has real protected pass skin")
local originalStealable=Config.isStealableSkin
provoke(Config,"isStealableSkin",function(key) return key==protected or originalStealable(key) end,R,"random.passTheft")
provoke(Config.SKIN_STEAL,"chance",.5,R,"random.theft")
provoke(Config,"REBIRTH_CRATES",{"missing"},R,"random.rebirthCrate")
provoke(Config,"CRATE_SECTIONS",{{key="x",name="X",chests={"missing"}}},R,"random.crateSection")
-- Cycles/shared references cannot trap the recursive tag/gate sweep.
local cycle={};cycle.self=cycle;Config._auditFixture=cycle
check(#R()==0,"recursive sweep handles cycles");Config._auditFixture=nil
-- Removing historical coin prices must preserve every resale amount and tier.
-- RE-PINNED x1000 with the economy's re-denomination. Every figure here is
-- the old one times a thousand, so what this still asserts is that the sell
-- LADDER -- the tier value, the `sellBasis` cap and which of the two binds on
-- each skin -- is untouched. Bubblegum at 2.0M against a common's flat 40.0M
-- is the cap biting exactly where it did before.
local sales={galaxy=40000000,stormwolf=125000000,
 bubblegum=2000000,bee=40000000,giraffe=40000000,ladybird=6250000,
 pearl=40000000,mint=5000000,sunset=11250000,midnight=22500000,lava=40000000,
 cow=8750000,neonmint=10000000,zebra=40000000,cyberlime=3000000,
 leopard=40000000}
-- SKINS SELL FOR COINS AGAIN. They paid acorns for one pass; with no crate
-- priced in any in-game currency there is no printer to close, so the coin
-- ladder and its `sellBasis` cap are back and these are the figures it pays.
for key,coins in sales do
 check(Config.sellValue("skin",key)==coins and Config.isSellable("skin",key),key.." sells for its coin value")
 check(Config.SKINS[key].cost==nil and Config.SKINS[key].sellBasis>0 and Config.SKINS[key].rarity~=nil,key.." resale metadata separate from coin price")
 check(not Config.isSkinUnlocked(key,{},100),key.." not made free by removing price")
end
-- A CRATE CANNOT PAY FOR ITSELF IN SPARES because a crate costs nothing to
-- open. What is checked instead is that the sell cap still binds: no skin may
-- return more than `SELL.priceFraction` of its own basis.
for key in sales do
 local spec=Config.SKINS[key]
 check(Config.sellValue("skin",key)<=math.max(1,math.floor(spec.sellBasis*Config.SELL.priceFraction)),
  key.." resale stays under the price cap")
end
check(Config.CHESTS[Config.REBIRTH_CRATES[1]].odds.rare==40 and Config.CHESTS[Config.REBIRTH_CRATES[1]].odds.epic==25
 and Config.CHESTS[Config.REBIRTH_CRATES[1]].odds.legendary==35,"standard random rebirth crate retained, epic rung stocked")

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
local eventSource,n=sources.EventService:gsub("return EventService%s*$","return {raid=rewardRaid}");assert(n==1)
local Event=load("EventService",env,eventSource)
local function reset(complete)
 data=Data.defaults();data.coins=17;events={};saves=0;now=0
 if complete then
  for _,entry in Config.SETS.alien.items do modules.SetService.grant(player,entry.kind,entry.key) end
  events={};saves=0
 end
end
for _,cleared in {false,true} do
 for _,complete in {false,true} do
  reset(complete);Event.raid(cleared)
  local bounty=math.floor(Config.getIncomeRate(data.incomeLevel,data.rebirths)*Config.RAID.bountySeconds*(if cleared then 1.5 else 1))
  check(data.coins==17+bounty,"raid pays its coin bounty")
  check((events.EventDrop~=nil)==not complete,"raid keeps free unowned drop; full set has no duplicate payout")
  check(next(data.spares)==nil,"completed raid never mints spares")
 end
end
check(Config.EVENTS.roster.midnight==nil and Config.EVENT_UI.midnight==nil and Config.MIDNIGHT==nil,"Midnight Heist is retired: no roster row, no banner row, no multiplier")
reset(true);modules.SetService.rollDrop(player,"alien")
check(saves==0 and events.Notify:find("already own",1,true),"full set provides feedback without bonus currency")
-- Stale/malicious coin purchase requests still cannot grant unowned crate
-- skins after their historical cost fields have been removed.
local Cosmetics=load("CosmeticsService",env)
for key in sales do
 reset(false);Cosmetics.buySkin(player,key)
 check(data.coins==17 and not data.cosmetics.owned[key] and saves==0,
  key.." direct coin request cannot grant a now-unpriced crate skin")
end
-- Paused pets and retired kennel skins cannot be bought or reactivated by old clients.
check(Config.PETS_ENABLED == false, "pets are disabled")
for key in Config.PETS do
 reset(false);data.coins=96000000
 local before=data.pets.equipped
 Cosmetics.buyPet(player,key)
 check(data.coins==96000000 and not data.pets.owned[key] and data.pets.equipped==before,
  key.." paused pet purchase cannot charge or equip")
 data.pets.owned[key]=true;data.pets.equipped=key
 Cosmetics.buyPet(player,key)
 check(data.pets.owned[key] and data.pets.equipped==key and saves==0,
  key.." paused pet request preserves dormant purchases")
end
for key in Config.DOG_KENNELS do
 reset(false);data.coins=96000000
 Cosmetics.buyDogKennel(player,key)
 check(data.coins==96000000 and not data.dogs.kennels[key],key.." retired kennel purchase cannot charge")
 data.dogs.kennels[key]=true;data.dogs.kennel=key
 Cosmetics.equipDogKennel(player,key)
 check(data.dogs.kennels[key] and data.dogs.kennel==key and saves==0,
  key.." old equip request leaves dormant ownership intact")
 check(not modules.SetService.inUse(data,"kennel",key),key.." legacy kennel skin is never active")
end
reset(false)
local attributes={PetKey="piglet"}
player.SetAttribute=function(_,key,value) attributes[key]=value end
modules.PlotService.getPlot=function() return nil end
data.pets.owned.piglet=true;data.pets.equipped="piglet"
Cosmetics.applyToPlot(player)
check(attributes.PetKey=="" and data.pets.equipped=="piglet", "pet publication is cleared while saved selection survives")
reset(false)
-- THE SEASON TIER LADDER GRANTED THIS and retired with the acorn rank that
-- fed it. What is checked is that the guardian it named is still grantable,
-- so whatever earns it next has something to hand over.
check(modules.SetService.grant(player,"coat","goldenboy") and data.dogs.owned.goldenboy,
 "the Golden Boy guardian is still grantable")
check(Config.SEASON.tiers==nil,"the acorn-ranked tier ladder is retired")
-- Retired piggy effects cannot charge, equip or grant through stale clients.
local applied,pushed=0,0
Cosmetics.applyToPlot=function() applied+=1 end
Cosmetics.push=function() pushed+=1 end
for key in Config.EFFECTS do
 reset(false);data.coins=96000000
 local before=data.cosmetics.effect
 Cosmetics.buyEffect(player,key)
 check(data.coins==96000000 and data.cosmetics.effect==before,
  key.." retired purchase leaves coins/equipment unchanged")
 if key~="none" then
  data.cosmetics.ownedEffects[key]=true;Cosmetics.equipEffect(player,key)
  check(data.cosmetics.effect==before,key.." legacy ownership cannot equip standalone aura")
  data.cosmetics.ownedEffects[key]=nil
  check(not modules.SetService.grant(player,"effect",key) and not data.cosmetics.ownedEffects[key],
   key.." retired effect cannot be granted")
 end
end
reset(false);data.cosmetics.effect="inferno";Cosmetics.equipEffect(player,"none")
check(data.cosmetics.effect=="none" and applied==1 and pushed==1,"legacy aura can be cleared")
check(Config.EFFECTS.starfall==nil,"unwanted new Starfall removed")
check(Config.EFFECTS.aurora==nil,"unwanted new Aurora removed")
reset(false)
check(modules.SetService.buy==nil,"the loot-priced set purchase is retired")
check(not data.cosmetics.ownedEffects.tractor,"no path grants the retired effect")
check(Config.skinAura({rarity="legendary",aura="sparkle"})==Config.EFFECTS.sparkle,
 "Legendary skin particle definitions remain available")
check(Config.skinAura({rarity="epic",aura="sparkle"})==Config.EFFECTS.sparkle,
 "an epic skin carries its aura: the effect is what makes the tier")
check(Config.skinAura({rarity="rare",aura="sparkle"})==nil,"a rare skin cannot gain a particle aura")
check(Config.skinAura({rarity="common",aura="sparkle"})==nil,"a common skin cannot gain a particle aura")
for passKey in Config.PASSES do
 for _,entry in Config.passItems(passKey) do check(entry.kind~="effect","pass grants exclude standalone auras") end
end
for _,set in Config.SETS do
 for _,entry in set.items do check(entry.kind~="effect","event set excludes standalone auras") end
end
local effectBody=assert(sources.PiggyBank:match("(function PiggyBank%.applyEffect.-)\nend")).."\nend"
local render={}
load("retired aura renderer",{PiggyBank=render},effectBody)
local light={Enabled=true}
local refs={aura={Enabled=true},skinAura={Enabled=true},drip={Enabled=true},
 body={FindFirstChild=function() return light end},model={SetAttribute=function() end}}
render.applyEffect(refs,"inferno")
check(not refs.aura.Enabled and not light.Enabled,"legacy renderer disables separate aura and light")
check(refs.skinAura.Enabled and refs.drip.Enabled,"renderer preserves skin and coin emitters")
-- Execute the actual new boot block; warnings never throw or stop startup.
local boot=assert(sources.Main:match("(%-%- THE RANDOM%-OUTCOME SWEEP.-)ChestService%.start%(%)"))
local warnings,prints={},{ }
local bootEnv={Config=Config,warn=function(message) table.insert(warnings,message) end,print=function(message) table.insert(prints,message) end}
load("Main audits",bootEnv,boot)
check(#warnings==0,"clean boot warns about nothing")
local price=Config.CHESTS.og.cost;Config.CHESTS.og.cost=15
load("Main audits",bootEnv,boot);Config.CHESTS.og.cost=price
check(contains(warnings,"random.price"),"boot surfaces a priced crate without throwing")
local originalAudit=Config.auditRandomOutcomes;Config.auditRandomOutcomes=function() error("test failure") end
load("Main audits",bootEnv,boot);Config.auditRandomOutcomes=originalAudit
check(warnings[#warnings]:find("could not run",1,true)~=nil,"failing audit warns and permits startup")
check(#R()==0,"all deliberate faults restored")
print(("PASS: %d audit checks; crates unpriced, resale on coins, actual event rewards and boot warnings. No player saves."):format(checks))
