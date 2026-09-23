local Config,source=...
local Delivery=assert(loadstring(source,"CarryDelivery"))()
local checks=0
local function check(ok,msg) assert(ok,msg);checks+=1 end
-- ONE CARRY KIND. The acorn basket was the second and retired with it.
for _,kind in {"pig"} do
 local view=Delivery.describe(17,{{kind="skin",key="bronze"}},kind,{canKeep=true,canReturn=true,victim="Alex",keepWorth=8,bounty=4})
 check(view.visible and not view.canPress,"in-transit card names choices without enabling a request")
 check(view.home:find("8",1,true) and view.home:find("all items",1,true),"keep preview includes half share and entire item haul")
 check(view.returning:find("Alex's",1,true) and view.returning:find("4",1,true),"return preview names owner and bounty")
 for _,action in {"keep","return"} do
  local at=Delivery.describe(0,{{kind="skin",key="bronze"}},kind,{action=action,canKeep=true,canReturn=true})
  check(at.visible and at.canPress and at.button==string.upper(action),"haul-only carry exposes the correct drop-off action")
 end
end
local own=Delivery.describe(8,{},"pig",{canKeep=true,canReturn=false,keepWorth=8})
check(own.showHome and not own.showReturn and own.home:find("piggy",1,true),"a carry with nowhere to return offers only the home drop-off")
local defender=Delivery.describe(10,{},"pig",{canKeep=false,canReturn=true,ownReturn=true,bounty=2,action="return"})
check(not defender.showHome and defender.returning:find("Your piggy",1,true) and defender.button=="RETURN","defender sees return without a duplicate keep choice")
check(not Delivery.describe(0,{},"pig",{action="keep"}).canPress,"empty carry cannot expose a button")
check(not Delivery.describe(0,nil,nil,nil).visible,"clear update hides the complete card")
check(Delivery.describe(1,{},"pig",{canKeep=true,keepWorth=0}).home:find("0 coins",1,true),"a zero keep share is quoted honestly")
print(("PASS: %d delivery UI checks; two named destinations, haul-only actions, own harvest, defender and empty state."):format(checks))
