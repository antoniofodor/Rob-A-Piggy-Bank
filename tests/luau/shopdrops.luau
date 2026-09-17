-- Execute the real shop-drop function against isolated reward/save doubles.
local Config, source = ...
local checks = 0
local function check(ok, message) assert(ok, message); checks += 1 end
local thief = {}
local data, carrying = nil, {}
local grants, notices, saves, pushes, rngCalls = 0, 0, 0, 0, 0
local allOwned = false
local discovery = nil
local draw = function() return 0 end
local fakeMath = table.clone(math)
fakeMath.random = function() rngCalls += 1; return draw() end
local env = setmetatable({Config=Config, math=fakeMath, carrying=carrying,
 DataService={get=function() return data end,save=function() saves+=1 end},
 PlotService={getPlot=function() return nil end},
 SetService={owns=function() return allOwned end,grant=function() grants+=1;return true end},
 stockPushers={function() pushes+=1 end},pushCarryState=function() pushes+=1 end,
 notify=function() notices+=1 end,
 Remotes={get=function(name)
  assert(name=="RobberyLoot")
  return {FireClient=function(_,player,payload) assert(player==thief);discovery=payload end}
 end},
}, {__index=getfenv()})
local body = assert(source:match("local function rollShopDrop%((.-)\nend\n"))
local load = assert(loadstring("return function(" .. body .. "\nend", "rollShopDrop"))
setfenv(load,env)
local roll = load()
local function reset(count)
 data={robberies=count,coins=100,loot=7,consumables={}}
 grants,notices,saves,pushes,rngCalls=0,0,0,0,0
 carrying[thief]=nil;allOwned=false;discovery=nil;draw=function() return 0 end
end
for _,count in {0,24,25,99} do
 reset(count)
 for _=1,200 do roll(thief,"gear") end
 check(grants==0 and notices==0 and saves==0 and rngCalls==0,"ride gate is silent before 100: "..count)
 check(data.coins==100 and data.loot==7 and next(data.consumables)==nil,"refusal changes no balances or stock")
end
reset(nil);roll(thief,"gear")
check(grants==0 and rngCalls==0,"legacy missing count cannot unlock rides")
reset(100);data=nil;roll(thief,"gear")
check(grants==0 and rngCalls==0,"missing save cannot roll")
reset(1600);roll(thief,"unknown")
check(grants==0 and saves==0 and notices==0 and rngCalls==0,"unknown shop cannot award consumables")
-- Evenly spaced draws cover the entire probability interval without flaky
-- random assertions. Each successful attempt also runs the real item pool.
for tab,expected in {piggy=20,home=16,gear=6,defend=40} do
 reset(if tab=="gear" then 100 else 0)
 for i=1,200 do
  local first=true
  draw=function() if first then first=false;return (i-.5)/200 end;return .5 end
  roll(thief,tab)
 end
 local received=grants
 if tab=="defend" then for _,count in data.consumables do received+=count end end
 check(received==expected,"200 probability samples: "..tab)
 check(notices==expected,"one reward notification per success: "..tab)
 check(data.robberies==(if tab=="gear" then 100 else 0) and data.loot==7,"shop drop never changes rank or Acorns")
end
-- Independent reproducible pseudorandom run of the actual gear roll.
reset(100)
local seed=421
draw=function() seed=(seed*16807)%2147483647;return (seed-1)/2147483646 end
for _=1,10000 do roll(thief,"gear") end
local rate=grants/10000
check(math.abs(rate-.03)<.006,"seeded eligible ride frequency stays near three percent")
print(("Eligible rides: %d/10000 (%.2f%%); rank 1: 0/200."):format(grants,rate*100))
for tab,chance in Config.SHOP_VAULT_DROP.chance do
 reset(100);draw=function() return chance end;roll(thief,tab)
 check(notices==0 and rngCalls==1,"upper probability boundary excluded: "..tab)
 reset(100);local first=true
 draw=function() if first then first=false;return chance-.000001 end;return .5 end
 roll(thief,tab)
 check(notices==1,"just below probability boundary succeeds: "..tab)
end
reset(100);carrying[thief]={haul={}};roll(thief,"gear")
check(#carrying[thief].haul==1 and carrying[thief].haul[1].kind=="ride" and grants==0,"new ride enters carry before it is owned")
check(pushes==1 and notices==1 and saves==0,"carried ride updates HUD without early grant/save")
check(discovery.mode=="carried" and discovery.won.key==carrying[thief].haul[1].key,"discovery reveals the exact escrowed winner")
check(discovery.pool[1].kind=="ride" and discovery.chance==.03,"discovery only cycles the eligible shop pool")
reset(99);allOwned=true;roll(thief,"gear")
check(data.coins==100 and notices==0,"rank gate also blocks owned-ride coin fallback")
reset(100);allOwned=true;roll(thief,"gear")
check(data.coins>100 and grants==0 and saves==1 and notices==1,"eligible complete ride collection still pays resale coins")
check(discovery.mode=="sold" and discovery.coins==data.coins-100,"resale reveal reports coins rather than a new ride")
-- Actual rarity chances are normalized over the currently eligible items.
local odds=Config.shopLootOdds("gear",100,function() return false end)
local sum=0
for _,value in odds.tiers do sum+=value end
check(math.abs(sum-1)<.000001,"conditional rarity chances sum to 100 percent")
check(odds.tiers.common>odds.tiers.rare and odds.tiers.rare>odds.tiers.legendary and odds.tiers.legendary>0,"ride tiers have distinct nonzero probabilities")
check(Config.rarityOf(Config.RIDES.scrambler)=="legendary","approved top shop ride is Legendary")
for _,entry in odds.pool do check(entry.key~="hoverdisc","event-exclusive ride never appears in shop/reel") end
local last=Config.shopLootOdds("gear",100,function(_,key) return key~="scrambler" end)
check(#last.pool==1 and last.tiers.legendary==1 and last.chance==.03,"last unowned ride has honest conditional odds")
local locked=Config.shopLootOdds("gear",99,function() return false end)
check(locked.chance==0 and locked.baseChance==.03 and locked.minRank==2,"locked odds expose zero now and required rank")
print(("Fresh ride drop tiers: Common %.2f%%, Rare %.2f%%, Epic %.2f%%, Legendary %.2f%% (conditional on a 3%% drop)."):format(
 odds.tiers.common*100,odds.tiers.rare*100,odds.tiers.epic*100,odds.tiers.legendary*100))
check(#Config.auditSkinSteal()==0,"current drop table passes player-prize audit")
local piggy=Config.shopLootOdds("piggy",0,function() return false end)
local mass=0
for _,entry in piggy.pool do
 check(entry.kind=="skin","Piggy Outfitters no longer drops standalone effects")
 mass+=entry.odds
end
check(piggy.chance==.10 and math.abs(mass-1)<.000001,"skin-only piggy pool preserves overall chance and normalized odds")
check(#Config.auditEconomy()==0 and #Config.auditRandomOutcomes()==0,"retired effects keep economy and crate audits clean")
for tab,old in Config.SHOP_VAULT_DROP.chance do
 Config.SHOP_VAULT_DROP.chance[tab]=1
 check(#Config.auditSkinSteal()>0,"audit compares player chance against every shop: "..tab)
 Config.SHOP_VAULT_DROP.chance[tab]=old
end
for _,bad in {-1,1.1,0/0} do
 local old=Config.SHOP_VAULT_DROP.chance.home
 Config.SHOP_VAULT_DROP.chance.home=bad
 check(#Config.auditSkinSteal()>0,"audit rejects invalid probability")
 Config.SHOP_VAULT_DROP.chance.home=old
end
check(#Config.auditSkinSteal()==0,"audit fixtures restored")
print(("PASS: %d shop-drop checks; rank gate, per-shop rates, carry/resale/stock paths and audit."):format(checks))
