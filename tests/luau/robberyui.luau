local Config,source=...
local checks=0
local function check(ok,message) assert(ok,message);checks+=1 end
local names=setmetatable({}, {__index=function(_,key) return key end})
local env=setmetatable({game={GetService=function() return {Shared=names} end},
 require=function(name) return if name=="Config" then Config else {} end}, {__index=getfenv()})
local run=assert(loadstring(source,"RobberyLoot"));setfenv(run,env)
local U=run()
check(U.percent(0)=="0%" and U.percent(1)=="100%" and U.percent(.03)=="3%","percentage formatting")
check(U.percent(.0004)=="<0.1%","tiny nonzero chance never rounds to zero")
local odds=Config.shopLootOdds("gear",100,function() return false end)
local title,detail=U.describe(odds)
check(title:find("ITEM 3%%") and title:find("every slice",1,true),"overall chance explicitly requires clean completion")
check(detail:find("If item:",1,true) and detail:find("Legendary 1.5%%"),"conditional rarity chances clearly labelled")
title,detail=U.describe(Config.shopLootOdds("gear",99,function() return false end))
check(title:find("ITEM 0%%") and detail:find("100 completed",1,true),"locked shop shows zero and unlock requirement")
title,detail=U.describe({kind="skin",chance=1,name="Bronze",tier="rare"})
check(title:find("100%%") and detail=="Bronze · Rare","deterministic player skin is not presented as a random tier roll")
title,detail=U.describe({kind="resident",chance=0,reason="Coins only"})
check(title=="COINS ONLY" and detail=="Skins come from robbing players","a neighbour says coins only rather than printing a 0% roll that reads as broken")
title=U.describe(Config.shopLootOdds("gear",100,function() return true end))
check(title:find("Duplicate sells for coins",1,true)~=nil,"completed collection explains resale")
for _,view in {{X=1399,Y=793},{X=750,Y=361},{X=480,Y=320},{X=320,Y=568}} do
 local l=U.layout(view)
 check(l.x-l.width/2>=0 and l.x+l.width/2<=view.X and l.y>=0 and l.y+l.height<=view.Y,"discovery remains on screen")
 if view.X>view.Y then check(l.y+l.height<=view.Y-96,"discovery clears the hotbar lane") end
 if view.X==480 then check(l.x+l.width/2<view.X-186,"small landscape discovery clears action buttons") end
end
print(("PASS: %d robbery UI checks; odds wording, actual tiers, locked/resale states and responsive discovery bounds."):format(checks))
