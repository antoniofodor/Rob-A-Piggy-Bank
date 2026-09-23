-- Executes the full HeistService with isolated players/services. Physical
-- carry rendering is stubbed; theft, claim, return and delivery logic is real.
local Config, source = ...
local checks, now, nextId = 0, 100, 0
local function check(ok, message) assert(ok, message);checks += 1 end
local function noop() end
local vm={}
local function vector(x,y,z) return setmetatable({X=x,Y=y,Z=z},vm) end
vm.__sub=function(a,b) return {Magnitude=math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)} end
local data, events, saveHook = {}, {}, nil
local handlers, leaving, sent = {}, nil, 0
local players = {PlayerRemoving={Connect=function(_,fn) leaving=fn end}}
local function player(name, skin)
 nextId += 1
 local p = {_player=true,DisplayName=name,UserId=nextId,Parent=true,SetAttribute=noop}
 data[p]={coins=100,loot=13,robberies=0,totalStolen=0,totalLost=0,
  cosmetics={skin=skin or "classic",owned={}},spares={}}
 if skin then data[p].cosmetics.owned[skin]=true end
 return p
end
local modules={Config=Config}
for _, name in {"SoundKit","CarryPose","UpgradePreview","PiggyBank","UpgradeService","GuardDog","EventService","ResidentService"} do modules[name]={} end
modules.Remotes={get=function(name) return {FireClient=function(_,p,payload)
 events[p]=events[p] or {};events[p][name]=payload
 if name=="RecoveryObjective" then sent+=1 end
end,OnServerEvent={Connect=function(_,fn) handlers[name]=fn end}} end}
modules.DataService={get=function(p) return data[p] end,save=function(p) if saveHook then saveHook(p) end;return true end}
modules.PlotService={getPlot=function(p) return p.plot end,
	updateRank=function(plot,count) plot.rank=Config.getRapSheetRank(count) end,
 updatePile=function(plot,amount) plot.coins=amount end,playBank=noop}
modules.ResidentService={get=function(plot) return plot.resident end,refund=function(r,amount) r.coins+=amount end}
modules.SocialService={getStarMultiplier=function(p) return p.stars or 1 end,getStars=function() return 1 end,getRun=function() return 1 end,
 recordSteal=noop,recordWeekly=noop,markRevenge=function(v,t) events[v]=events[v] or {};events[v].revengeTarget=t end}
modules.TrophyService={recordVictim=noop,recordSpree=noop}
modules.SeasonService={earn=function() end,recordNemesis=function() end}
for _,k in {"recordClean","recordWanted","recheck","recordVictim","recordSpree","recordCatch"} do modules.TrophyService[k]=modules.TrophyService[k] or function() end end
modules.SetService={owns=function(d,kind,key) return d.cosmetics.owned[key]==true end,push=noop,
 grant=function(p,kind,key)
  assert(kind=="skin")
  if data[p].cosmetics.owned[key] then return false end
  data[p].cosmetics.owned[key]=true;if saveHook then saveHook(p) end;return true
 end}
modules.CosmeticsService={applyToPlot=noop,push=noop,equipSkin=function(p,key)
 assert(data[p].cosmetics.owned[key]);data[p].cosmetics.skin=key
end}
local names=setmetatable({}, {__index=function(_,key) return key end})
local fakeMath=table.clone(math);fakeMath.random=function() error("skin theft must not roll RNG") end
local env={game={GetService=function(_,name)
 return if name=="ReplicatedStorage" then {Shared=names} elseif name=="Players" then players else {}
end}, script={Parent=names},require=function(name) return assert(modules[name],name) end,
 Vector3={new=vector},Color3={fromRGB=function() return {} end},math=fakeMath,os={clock=function() return now end},
 typeof=function(value) return if type(value)=="table" and value._player then "Instance" else typeof(value) end,
 workspace={GetServerTimeNow=function() return now end},task={spawn=function(fn,...) return fn(...) end}}
-- Test-only access to private functions. Geometry/physics cleanup is the only
-- replaced behavior; returnHaul still runs on the same carry for failed runs.
local tail=[[
getRoot=function(p) return p.root end
getHumanoid=function(p) return {Health=p.health or 100} end
pushCarryState = function() end
pushCrack = function() end
clearCarry = function(p)
 local carry=carrying[p];carrying[p]=nil
 if carry then returnHaul(carry) end
 return carry
end
return {request=settleOnArrival,returnCarry=returnCarry,options=carryOptions,action=dropAction,newCarry=newCarry,steal=rollSkinSteal,deliver=deliver,returnHaul=returnHaul,clear=clearCarry,
 carrying=carrying,grudge=grudge,losses=skinLosses,record=recordGrudge,
 cracking=cracking,endCrack=endCrack,isRevenge=isRevenge,
 objectives=HeistService.recoveryState,startObjectives=startObjectives}
]]
local transformed,n=source:gsub("return HeistService%s*$",tail);assert(n==1)
if modules.SocialService then modules.SocialService.recordDefend=modules.SocialService.recordDefend or function() end end
local run=assert(loadstring(transformed,"HeistService"));setfenv(run,setmetatable(env,{__index=getfenv()}))
local H=run()
local function carry(p,v)
 local c=H.newCarry(p,v,10,{}, {Triggered={Connect=noop}});H.carrying[p]=c;return c
end
local function take(p,v)
 local c=carry(p,v);H.steal(p,v);return c
end
local function owned(p,key) return data[p].cosmetics.owned[key]==true end
local function claim(owner,robber,key)
 local g=H.grudge[owner] and H.grudge[owner][robber];return g and g.skins[key]
end
local function stealAndDeliver(p,v)
 local c=take(p,v);check(#c.haul==1,"skin staged on carry");H.deliver(p)
end
local function plot(p,x)
 p.root={Position=vector(x,1,0)}
 p.plot={owner=p,base={Position=vector(x,0,0)}}
 return p
end
-- ONE CARRY KIND. `kind` used to pick between a plot's base and its acorn
-- storage crate; the basket retired with the currency, so every destination
-- is the base and the parameter is ignored.
local function home(p,_kind)
 p.root.Position=p.plot.base.Position
end
local function moveTo(p,target,_kind)
 p.root.Position=target.plot.base.Position
end
local function transfer(c,old,holder)
 H.carrying[old]=nil;H.carrying[holder]=c;c.holder=holder
end
local thief=plot(player("Original"),100)
local victim=plot(player("Victim","bronze"),200)
local keeper=plot(player("Keeper"),300)
local c=take(thief,victim);c.amount=17
transfer(c,thief,keeper)
keeper.stars=99;H.grudge[keeper]={[victim]={expires=now+60,skins={}}}
local choices=H.options(keeper,c)
check(choices.canKeep and choices.canReturn and choices.victim=="Victim" and choices.keepWorth==8 and choices.bounty==4,"server quotes both destinations and raw half share")
H.request(keeper)
check(data[keeper].coins==108 and data[keeper].totalStolen==17 and data[keeper].robberies==1,"keeper receives floor(raw/2), not doubled/revenge/spree payout")
check(owned(keeper,"bronze") and not owned(thief,"bronze") and not owned(victim,"bronze"),"whole skin follows final keeper")
check(claim(victim,keeper,"bronze") and not claim(victim,thief,"bronze") and events[victim].revengeTarget==keeper,"latest skin claim and revenge marker name final keeper")
check(H.grudge[keeper][victim].expires>now,"half-share keep does not consume keeper's unrelated revenge bonus")
H.request(keeper);check(data[keeper].coins==108 and data[keeper].robberies==1,"keep request replay cannot settle twice")
check(events[keeper].Notify:find("Half share",1,true) and events[victim].Notify:find("Keeper",1,true),"keeper and victim toasts name the settlement")
-- The actual settlement paths publish each newly earned rank immediately.
for _,kind in {"pig","skin"} do
 local t=plot(player("RankThief"),4100);local v=plot(player("RankVictim"),4200)
 data[t].robberies=99
 local held=carry(t,v)
 if kind=="skin" then held.amount=0;held.haul={{kind="skin",key="bronze"}} end
 home(t,kind)
 H.request(t)
 check(data[t].robberies==100 and t.plot.rank==2,"delivery updates rank at 100: "..kind)
 H.request(t)
 check(data[t].robberies==100 and t.plot.rank==2,"replay leaves rank unchanged: "..kind)
end
-- An original claimant pays normally after reclaiming; whole-item duplicate
-- rules still refuse new spares as compensation.
local r=plot(player("Reclaimer"),400);local owner=plot(player("Owner","goldleaf"),500)
local cc=take(r,owner);transfer(cc,r,keeper);transfer(cc,keeper,r)
H.request(r)
check(data[r].coins==100+10*Config.HEIST_PAYOUT and owned(r,"goldleaf"),"reclaimed haul settles at full original rate")
-- Third-party return, owner recovery and voluntary undo.
for _,who in {"helper","owner"} do
 local t=plot(player("T"),600);local v=plot(player("V","bronze"),700);local h=plot(player("H"),800)
 local carried=take(t,v);carried.amount=17
 local recipient=if who=="owner" then v elseif who=="claimant" then t else h
 if recipient~=t then transfer(carried,t,recipient) end
 moveTo(recipient,v)
 local before=data[recipient].coins
 H.request(recipient)
 local bonus=if recipient==t then 0 else 4
 check(data[recipient].coins==before+bonus+(if recipient==v then 17 else 0),"return pays one raw bounty to deliverer: "..who)
 check(data[v].coins==117+(if recipient==v then 4 else 0) and owned(v,"bronze"),"return restores full coins and skin: "..who)
 check(data[recipient].robberies==0 and data[recipient].totalStolen==0 and not claim(v,recipient,"bronze"),"return does not count theft or create a hot claim: "..who)
 check(H.carrying[recipient]==nil and not owned(h,"bronze"),"return consumes haul without granting helper the skin: "..who)
 H.request(recipient);H.returnCarry(recipient)
 check(data[v].coins==117+(if recipient==v then 4 else 0),"repeated return cannot refund twice: "..who)
end
-- Arriving is the delivery, so a robber still standing at the pig they
-- just robbed must NOT hand the haul back by walking: no voluntary undo.
do
 local t=plot(player("T"),600);local v=plot(player("V","bronze"),700)
 local carried=take(t,v);moveTo(t,v);H.request(t)
 check(H.carrying[t]==carried and H.options(t,carried).returnRing==nil,"robber at the robbed pig keeps the haul and sees no return ring")
end
-- THE ACORN-BASKET SETTLEMENT PATHS STOOD HERE: a raw half share that
-- bypassed the coin multipliers, a two-acorn return bounty, a source-receipt
-- refund that put tree acorns back on the ground, and the own-harvest case.
-- All four went with the carry kind. The coin paths above and below are the
-- whole of what a settlement is now.
-- Returning an insured spare restores the spare; keeping never mints one.
local insured=plot(player("Insured","bronze"),1700);data[insured].spares["skin:bronze"]=1
local raider=plot(player("Raider"),1800);local rescuer=plot(player("Rescuer"),1900)
local spare=take(raider,insured);transfer(spare,raider,rescuer);moveTo(rescuer,insured);H.request(rescuer)
check(data[insured].spares["skin:bronze"]==1 and owned(insured,"bronze"),"return restores exactly the insured copy")
-- A recovered skin is nabbed again: its original recovery owner now gets a
-- claim against the final keeper; the old reserved claim is retired.
local original=plot(player("RecoveryOwner","goldleaf"),2000);local robber=plot(player("Robber"),2100)
stealAndDeliver(robber,original)
local recovery=take(original,robber);local hot=recovery.haul[1].hot
local interceptor=plot(player("Interceptor"),2200);transfer(recovery,original,interceptor);H.request(interceptor)
check(owned(interceptor,"goldleaf") and not owned(original,"goldleaf") and not owned(robber,"goldleaf"),"intercepted recovery grants only final holder")
check(not claim(original,robber,"goldleaf") and claim(original,interceptor,"goldleaf"),"intercepted recovery moves claim away from old robber")
check(events[original].revengeTarget==interceptor,"recovery owner's marker follows intercepted skin")
check(not claim(robber,interceptor,"goldleaf"),"old robber receives no ownership claim on original victim's skin")
-- An intercepted insured recovery must not mint a spare for the interceptor.
local insuredOwner=plot(player("InsuredOwner","bronze"),3500)
data[insuredOwner].spares["skin:bronze"]=1
local first=plot(player("FirstRobber"),3600);stealAndDeliver(first,insuredOwner)
local returning=take(insuredOwner,first)
local second=plot(player("SecondRobber"),3700);transfer(returning,insuredOwner,second);H.request(second)
check(owned(second,"bronze") and not data[second].spares["skin:bronze"],"interceptor gets a skin, not a minted insured spare")
check(claim(insuredOwner,second,"bronze").spare and (data[insuredOwner].spares["skin:bronze"] or 0)==0,"insured recovery claim follows intercepted copy")
local recovered=take(insuredOwner,second);H.request(insuredOwner)
check(data[insuredOwner].spares["skin:bronze"]==1 and owned(insuredOwner,"bronze") and not owned(second,"bronze"),"original insured owner can recover the same spare through the final keeper")
-- Haul-only handoffs can finish at either destination despite zero currency.
for _,exit in {"keep","return"} do
 local t=plot(player("ZeroT"),3800);local v=plot(player("ZeroV","goldleaf"),3900);local h=plot(player("ZeroH"),4000)
 local itemOnly=take(t,v);itemOnly.amount=0;transfer(itemOnly,t,h)
 if exit=="return" then moveTo(h,v) end
 H.request(h)
 check(H.carrying[h]==nil and data[h].coins==100,"zero-currency haul settles without a bounty or coin mint: "..exit)
 check(owned(if exit=="keep" then h else v,"goldleaf"),"haul-only skin reaches selected owner: "..exit)
end
-- Geometric/server authority: no trusting the old in-range flag or payload.
for _,reason in {"far","vertical","dead","wrongHolder","missingClaimant","departedVictim","newOccupant"} do
 local t=plot(player("T"),2300);local v=plot(player("V"),2400);local h=plot(player("H"),2500)
 local held=carry(t,v);transfer(held,t,h);held.inRange=true;moveTo(h,v)
 if reason=="far" then h.root.Position=vector(2600,0,0)
 elseif reason=="vertical" then h.root.Position=vector(2400,100,0)
 elseif reason=="dead" then h.health=0
 elseif reason=="wrongHolder" then held.holder=t
 elseif reason=="missingClaimant" then held.claimant=nil
 elseif reason=="departedVictim" then v.Parent=nil
 elseif reason=="newOccupant" then v.plot.owner=t end
 H.request(h)
 check(H.carrying[h]==held and data[h].coins==100 and data[v].coins==100,"stale/invalid return refuses without consuming escrow: "..reason)
end
-- Active minigames own their controls; a stale delivery key cannot cash out.
local busy=plot(player("Busy"),3300);local source=plot(player("Source"),3400)
local active=carry(busy,source);home(busy)
H.cracking[busy]={};H.request(busy)
check(H.carrying[busy]==active and data[busy].coins==100,"crack in progress blocks delivery")
H.cracking[busy]=nil;H.request(busy)
check(H.carrying[busy]==nil,"delivery becomes available when the crack ends")
-- Resident plots return only while they still belong to that same resident.
local t=plot(player("ResidentThief"),2700);local h=plot(player("ResidentHelper"),2800)
local npc={name="NPC",coins=10,plot={index=9,base={Position=vector(2900,0,0)}}};npc.plot.resident=npc
local held=carry(t,npc);transfer(held,t,h);h.root.Position=npc.plot.base.Position;H.request(h)
check(npc.coins==20 and data[h].coins==102,"resident return refunds raw coins with one floored bounty")
local blocked=carry(t,npc);transfer(blocked,t,h);npc.plot.owner=t;H.request(h)
check(H.carrying[h]==blocked and npc.coins==20,"new property occupant cannot receive old resident refund")
-- Reentrant callbacks during item grant see an already-consumed carry.
local t=plot(player("YieldThief"),3000);local v=plot(player("YieldVictim","bronze"),3100);local h=plot(player("YieldHelper"),3200)
data[v].spares["skin:bronze"]=1
local held=take(t,v);transfer(held,t,h);moveTo(h,v)
saveHook=function() H.request(h) end
H.request(h);saveHook=nil
check(data[v].spares["skin:bronze"]==1 and data[h].coins==102 and H.carrying[h]==nil,"yielding return grant cannot replay bounty or insured refund")
-- A carry holding an ITEM as well as coins must stage the money AND its
-- completed getaway before a grant callback can save.
local t=plot(player("MixedT"),4100);local v=plot(player("MixedV","bronze"),4200);local h=plot(player("MixedH"),4300)
local mixed=take(t,v);mixed.amount=10
transfer(mixed,t,h);home(h)
local saved=false
saveHook=function(p)
 if p==h then
  check(H.carrying[h]==nil and data[h].robberies==1,"a keep stages complete accounting before item grant/save")
  saved=true;H.request(h)
 end
end
H.request(h);saveHook=nil
check(saved and owned(h,"bronze") and data[h].robberies==1,"item grant cannot replay the completed getaway")
print(("PASS: %d settlement checks; drop-offs, payouts, skins/recovery, replay, residents and server range authority."):format(checks))
