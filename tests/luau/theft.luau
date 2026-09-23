-- Executes the full HeistService with isolated players/services. Physical
-- carry rendering is stubbed; theft, claim, return and delivery logic is real.
local Config, source = ...
local checks, now, nextId = 0, 100, 0
local function check(ok, message) assert(ok, message);checks += 1 end
local function noop() end
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
players.GetPlayers=function() local list={};for p in pairs(data) do if p.Parent then table.insert(list,p) end end;return list end
local modules={Config=Config}
for _, name in {"SoundKit","CarryPose","UpgradePreview","PiggyBank","UpgradeService","GuardDog","EventService","ResidentService"} do modules[name]={} end
modules.Remotes={get=function(name) return {FireClient=function(_,p,payload)
 events[p]=events[p] or {};events[p][name]=payload
 if name=="RecoveryObjective" then sent+=1 end
end,OnServerEvent={Connect=function(_,fn) handlers[name]=fn end}} end}
modules.DataService={get=function(p) return data[p] end,save=function(p) if saveHook then saveHook(p) end;return true end}
modules.PlotService={getPlot=function() return nil end}
modules.SocialService={getStarMultiplier=function() return 1 end,getStars=function() return 1 end,getRun=function() return 1 end,
 recordSteal=noop,recordWeekly=noop,markRevenge=noop}
modules.TrophyService={recordVictim=noop,recordSpree=noop}
modules.SeasonService={earn=function() end,recordNemesis=function() end}
for _,k in {"recordClean","recordWanted","recheck","recordVictim","recordSpree","recordCatch"} do modules.TrophyService[k]=modules.TrophyService[k] or function() end end
modules.SetService={owns=function(d,kind,key) return d.cosmetics.owned[key]==true end,push=noop,
 grant=function(p,kind,key)
  assert(kind=="skin")
  if data[p].cosmetics.owned[key] then return false end
  data[p].cosmetics.owned[key]=true;return true
 end}
modules.CosmeticsService={applyToPlot=noop,push=noop,equipSkin=function(p,key)
 assert(data[p].cosmetics.owned[key]);data[p].cosmetics.skin=key
end}
local names=setmetatable({}, {__index=function(_,key) return key end})
-- The 50/50 between the worn skin and another owned one is the only draw.
-- Controlled rather than banned: `roll` is what math.random() returns (below
-- 0.5 takes the worn skin), `pickIndex` what math.random(a, b) returns.
local rng={roll=0,pickIndex=nil::number?}
local fakeMath=table.clone(math);fakeMath.random=function(a,b)
 if a then return rng.pickIndex or a end
 return rng.roll
end
local env={game={GetService=function(_,name)
 return if name=="ReplicatedStorage" then {Shared=names} elseif name=="Players" then players else {}
end}, script={Parent=names},require=function(name) return assert(modules[name],name) end,
 Color3={fromRGB=function() return {} end},math=fakeMath,os={clock=function() return now end},
 typeof=function(value) return if type(value)=="table" and value._player then "Instance" else typeof(value) end,
 workspace={GetServerTimeNow=function() return now end},task={spawn=function(fn,...) return fn(...) end}}
-- Test-only access to private functions. Geometry/physics cleanup is the only
-- replaced behavior; returnHaul still runs on the same carry for failed runs.
local tail=[[
pushCarryState = function() end
pushCrack = function() end
clearCarry = function(p)
 local carry=carrying[p];carrying[p]=nil
 if carry then returnHaul(carry) end
 return carry
end
return {newCarry=newCarry,steal=rollSkinSteal,deliver=deliver,returnHaul=returnHaul,clear=clearCarry,giveBack=giveBack,
 carrying=carrying,grudge=grudge,losses=skinLosses,record=recordGrudge,
 cracking=cracking,endCrack=endCrack,isRevenge=isRevenge,
 objectives=HeistService.recoveryState,startObjectives=startObjectives,
 street=HeistService.streetState,coinLosses=losses,allowance=lossAllowance,lootOdds=robberyOdds,skinChoice=skinLootChoice}
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
local grabber,wrong,sourceOwner=player("Grabber"),player("Wrong"),player("Source")
local staged=carry(grabber,sourceOwner)
check(staged.claimant==grabber and staged.holder==grabber,"pig grab records claimant separately from holder")
for _,field in {"holder"} do
 staged[field]=wrong
 H.deliver(grabber)
 check(data[grabber].coins==100 and data[grabber].robberies==0,"mismatched identity cannot settle coins or count a robbery")
 check(H.carrying[grabber]==staged,"identity refusal leaves coin escrow intact")
 staged[field]=grabber
end
H.deliver(grabber)
check(data[grabber].coins==100+10*Config.HEIST_PAYOUT and H.carrying[grabber]==nil,"original holder still delivers coins once")

check(Config.SKIN_STEAL.chance==1 and Config.SKIN_STEAL.revengeChance==nil,"single guaranteed chance")
check(#Config.auditSkinSteal()==0,"skin boot audit clean")
Config.SKIN_STEAL.chance=.5;check(#Config.auditSkinSteal()==1,"audit detects chance regression");Config.SKIN_STEAL.chance=1

-- Multiple victims keep independent claims against the same robber, even as
-- that robber continues robbing and changes their outfit.
local a,b,r=player("A","bronze"),player("B","goldleaf"),player("Robber")
stealAndDeliver(r,a);local aClaim=claim(a,r,"bronze")
check(aClaim~=nil and owned(r,"bronze") and not owned(a,"bronze"),"delivered skin establishes hot claim")
check(data[a].claims.bronze==Config.seasonIndex(),"owned skin loss records seasonal buy-back claim")
now+=20;stealAndDeliver(r,b);local bClaim=claim(b,r,"goldleaf")
check(claim(a,r,"bronze")==aClaim and bClaim~=nil,"robbing someone else preserves previous victim's claim")
data[r].cosmetics.skin="classic";H.losses[r]={since=now,lost=Config.SKIN_STEAL.cap}
data[r].spares["skin:bronze"]=2
local c=take(a,r)
check(#c.haul==1 and c.haul[1].key=="bronze" and not owned(r,"bronze"),"revenge takes hot owned skin regardless of outfit/cap")
check(data[r].spares["skin:bronze"]==2 and data[r].cosmetics.skin=="classic","recovery bypasses insurance and preserves other outfit")
H.steal(a,r);check(#c.haul==1,"repeated call cannot add a second skin")
H.deliver(a)
check(owned(a,"bronze") and not owned(r,"bronze") and claim(a,r,"bronze")==nil,"recovered skin lands and claim clears")
check(claim(b,r,"goldleaf")==bClaim,"one recovery leaves another victim's claim intact")
check(events[a].HeistDelivered.revenge and events[a].HeistDelivered.banked==10*Config.revengePayout(),"coin revenge payout is the payout times the bonus")
check(data[a].coins==data[a].coins,"skin recovery mints no second currency: there is none")
stealAndDeliver(b,r)
check(owned(b,"goldleaf") and not owned(r,"goldleaf"),"second victim can recover from same robber")
check(not claim(r,a,"bronze") and not claim(r,b,"goldleaf"),"recovery creates no counter-claim on returned skin")

-- Latest thief is tracked per owner/skin, not globally per robber or victim.
local owner,x,y=player("Owner"),player("X","bronze"),player("Y","bronze")
H.record(owner,x,{kind="skin",key="bronze"});H.record(owner,x,{kind="skin",key="goldleaf"})
now+=1;H.record(owner,y,{kind="skin",key="bronze"})
check(claim(owner,x,"bronze")==nil and claim(owner,y,"bronze")~=nil,"latest taker replaces previous claim for that owner/skin")
check(claim(owner,x,"goldleaf")~=nil,"different stolen skin remains recoverable")
-- Stack multiple skins for one pair; earliest expiry is recovered first.
data[x].cosmetics.owned.goldleaf=true;data[x].cosmetics.owned.diamond=true
H.record(owner,x,{kind="skin",key="diamond"});local stacked=take(owner,x)
check(stacked.haul[1].key=="goldleaf","oldest valid stacked claim selected")
H.deliver(owner);check(claim(owner,x,"diamond")~=nil,"remaining stacked claim survives delivery")
stealAndDeliver(owner,x);check(owned(owner,"diamond"),"remaining stack recovered on next crack")

-- The timer is per skin and cannot be refreshed by a coin-only robbery.
local t,v=player("Timer thief"),player("Timer victim","bronze")
stealAndDeliver(t,v);local timed=claim(v,t,"bronze");local expiry=timed.expires
now+=5;H.record(v,t,nil);check(timed.expires==expiry,"coin theft does not extend skin deadline")
now=expiry;data[t].cosmetics.skin="classic"
-- The loss cap holds the random half shut, so only the claim is under test.
H.losses[t]={since=now,lost=Config.SKIN_STEAL.cap}
local expired=take(v,t)
check(#expired.haul==0 and owned(t,"bronze") and claim(v,t,"bronze")==nil,"claim expires at exact boundary")

-- Other victims' later deadlines remain valid when the first one expires.
local multi=player("Timed robber","bronze")
data[multi].cosmetics.owned.goldleaf=true;data[multi].cosmetics.skin="classic"
local first,last=player("Earlier victim"),player("Later victim")
H.record(first,multi,{kind="skin",key="bronze"});local firstUntil=claim(first,multi,"bronze").expires
now+=30;H.record(last,multi,{kind="skin",key="goldleaf"})
now=firstUntil
H.losses[multi]={since=now,lost=Config.SKIN_STEAL.cap}
check(#take(first,multi).haul==0,"earlier victim deadline expires independently")
stealAndDeliver(last,multi)
check(owned(last,"goldleaf") and owned(multi,"bronze"),"later victim still recovers inside own deadline")

-- Spending the coin revenge bonus (e.g. a smash) leaves the skin window live.
local ct,cv=player("Coin thief"),player("Coin victim","diamond")
stealAndDeliver(ct,cv);carry(cv,ct);H.deliver(cv)
check(not H.isRevenge(cv,ct) and claim(cv,ct,"diamond")~=nil,"coin revenge consumption preserves hot claim")
data[ct].cosmetics.skin="classic";stealAndDeliver(cv,ct)
check(owned(cv,"diamond") and not owned(ct,"diamond"),"skin recovery works after coin bonus spent")

-- A failed recovery returns the exact copy and preserves a live claim.
local ft,fv=player("Failed thief"),player("Failed victim","bronze")
stealAndDeliver(ft,fv);data[ft].cosmetics.skin="classic"
H.losses[ft]={since=now,lost=1};local failed=take(fv,ft);local receipt=claim(fv,ft,"bronze")
check(receipt.reserved==true,"claim reserved while carried")
H.clear(fv);H.returnHaul(failed)
check(owned(ft,"bronze") and data[ft].cosmetics.skin=="classic" and not owned(fv,"bronze"),"caught recovery returns skin without changing unrelated outfit")
check(not receipt.reserved and H.losses[ft].lost==1,"retry released without refunding unrelated loss cap")
stealAndDeliver(fv,ft);check(owned(fv,"bronze"),"retry succeeds inside original deadline")

-- Returning an old carry cannot overwrite a newer claim or newer loss window.
local rt,rv,other=player("Receipt thief"),player("Receipt victim","bronze"),player("New thief","bronze")
stealAndDeliver(rt,rv);local oldCarry=take(rv,rt);local oldReceipt=claim(rv,rt,"bronze")
H.record(rv,other,{kind="skin",key="bronze"});H.clear(rv)
check(claim(rv,rt,"bronze")==nil and claim(rv,other,"bronze")~=nil,"failed old recovery cannot resurrect superseded claim")
local newer,grabber=player("New window","goldleaf"),player("Window thief")
local windowCarry=take(grabber,newer);H.losses[newer]={since=now+1,lost=1};H.clear(grabber)
check(H.losses[newer].lost==1,"old carry return cannot refund a newer loss window")

-- Normal theft still obeys duplicate, class, spare and hourly-loss rails.
for _,key in {"classic","bullion","martian"} do
 local safe,attacker=player("Safe",key),player("Attacker")
 check(#take(attacker,safe).haul==0,"protected skin "..key)
end
-- DUPLICATES ARE ALLOWED, and the thief's extra copy is a SPARE. The victim
-- still loses the copy they lost, so nothing is minted.
local dup,dv=player("Duplicate","bronze"),player("Duplicate victim","bronze")
local dupCarry=take(dup,dv)
check(#dupCarry.haul==1 and dupCarry.haul[1].key=="bronze" and not owned(dv,"bronze"),
 "a skin the thief already owns is still taken")
H.deliver(dup)
check(owned(dup,"bronze") and data[dup].spares["skin:bronze"]==1,
 "the duplicate lands as a spare rather than silently paying nothing")
local capped,attacker=player("Capped","bronze"),player("Cap attacker")
H.losses[capped]={since=now,lost=Config.SKIN_STEAL.cap}
check(#take(attacker,capped).haul==0,"ordinary cap applies")
now+=Config.SKIN_STEAL.window+1;local capCarry=take(attacker,capped)
check(#capCarry.haul==1,"cap reopens after window")
H.clear(attacker);check(owned(capped,"bronze") and H.losses[capped].lost==0,"failed normal theft refunds its loss allowance")
local insured,insurer=player("Insured","goldleaf"),player("Insurance thief")
data[insured].spares["skin:goldleaf"]=1
local insuredCarry=take(insurer,insured)
check(owned(insured,"goldleaf") and data[insured].spares["skin:goldleaf"]==nil,"spare absorbs ordinary theft")
check(not data[insured].claims or not data[insured].claims.goldleaf,"spare-only loss creates no owned-skin buy-back claim")
H.clear(insurer);H.returnHaul(insuredCarry)
check(data[insured].spares["skin:goldleaf"]==1,"repeat cleanup returns spare exactly once")
stealAndDeliver(insurer,insured);stealAndDeliver(insured,insurer)
check(owned(insured,"goldleaf") and data[insured].spares["skin:goldleaf"]==1 and not owned(insurer,"goldleaf"),"recovery restores stolen insured spare without minting extras")

-- Already reacquired skins still come off the robber; no spare faucet.
local at,av=player("Again thief"),player("Again victim","bronze")
stealAndDeliver(at,av);data[av].cosmetics.owned.bronze=true
local again=take(av,at);check(#again.haul==1 and not owned(at,"bronze"),"recovery revokes even when original owner reacquired skin")
H.deliver(av);check(data[av].spares["skin:bronze"]==nil,"reacquired owned copy mints no spare")
-- No item substitution if the robber sold the hot skin.
local st,sv=player("Seller"),player("Sold victim","bronze")
stealAndDeliver(st,sv);data[st].cosmetics.owned.bronze=nil;data[st].cosmetics.owned.goldleaf=true;data[st].cosmetics.skin="goldleaf"
check(#take(sv,st).haul==0 and owned(st,"goldleaf"),"missing hot copy does not take unrelated outfit")
-- No carry means no transfer, and staging precedes a yielding save.
local nv,nt=player("No carry victim","bronze"),player("No carry thief")
H.steal(nt,nv);check(owned(nv,"bronze") and not owned(nt,"bronze"),"no carry cannot instantly grant")
local yieldVictim,yieldThief=player("Yield victim","bronze"),player("Yield thief")
saveHook=function(p)
 if p==yieldVictim then
  saveHook=nil;check(#H.carrying[yieldThief].haul==1,"haul staged before save can yield")
  H.clear(yieldThief)
 end
end
take(yieldThief,yieldVictim)
check(owned(yieldVictim,"bronze") and not owned(yieldThief,"bronze"),"nab during save cannot destroy or grant stolen skin")

-- Exercise the actual endCrack gate: only completed player cracks take skins.
for _,why in {"done","miss","lost"} do
 local p,q=player("Clean victim","bronze"),player("Clean thief")
 local c=carry(q,p);H.cracking[q]={victim=p,plot=nil,banked=10,steps=5}
 H.endCrack(q,why)
 check(#c.haul==(if why=="done" then 1 else 0),"endCrack eligibility "..why)
end
local npc={name="Resident",skin="bronze",plot={index=1}}
local nr=player("Resident thief");local nc=carry(nr,npc)
H.cracking[nr]={victim=npc,plot=nil,banked=10,steps=5};H.endCrack(nr,"done")
check(#nc.haul==0,"resident cannot mint a stolen skin")
H.deliver(nr)
check(events[nr].HeistDelivered.banked==10*Config.HEIST_PAYOUT and H.grudge[npc]==nil,"resident delivery remains coin-only without a grudge")
-- The private objective snapshot follows the real theft/return/delivery paths.
local ov,ot=player("Objective victim","bronze"),player("Jamie")
local function row(p,key)
 for _,r in H.objectives(p).claims do if r.key==key then return r end end
end
check(#H.objectives(ov).claims==0 and H.objectives({})==nil,"no invented claim or unloaded objective")
take(ot,ov)
check(row(ov,"bronze").stage=="chase" and row(ov,"bronze").robberName=="Jamie","theft immediately shows named chase before delivery")
check(row(ov,"bronze").expiresAt==nil and row(ov,"bronze").cost==Config.buybackCost("bronze"),"chase invents no recovery deadline")
H.clear(ot)
check(#H.objectives(ov).claims==0,"caught thief restores skin and clears objective")
stealAndDeliver(ot,ov)
local live=row(ov,"bronze")
check(live.stage=="recover" and live.expiresAt==now+Config.REVENGE.window,"delivery starts actual recovery countdown")
local wallDeadline=live.expiresAt
now+=1;H.record(ov,ot,nil)
check(row(ov,"bronze").expiresAt==wallDeadline,"coin revenge does not reset objective deadline")
local ov2=player("Second objective victim","goldleaf")
stealAndDeliver(ot,ov2);data[ot].cosmetics.skin="classic"
check(row(ov,"bronze").robberId==ot.UserId and row(ov2,"goldleaf").robberId==ot.UserId,"same robber appears privately for multiple victims")
check(row(ov,"bronze").expiresAt==wallDeadline,"later victim and changed outfit preserve earlier timer")
local returning=take(ov,ot)
check(row(ov,"bronze").stage=="home","recovered carry asks to get home")
now=wallDeadline
check(row(ov,"bronze").stage=="home","carry can still be delivered after recovery deadline")
H.clear(ov)
check(row(ov,"bronze").stage=="buyback" and row(ov,"bronze").cost==Config.buybackCost("bronze"),"failed late getaway falls back to buy-back")
check(row(ov2,"goldleaf").stage=="recover","another victim keeps their later deadline")
-- A disconnected robber or a sold copy is not a target a client can recover.
ot.Parent=nil
check(row(ov2,"goldleaf").stage=="buyback","disconnected robber falls back to valid buy-back")
ot.Parent=true;data[ot].cosmetics.owned.goldleaf=nil
check(row(ov2,"goldleaf").stage=="buyback","missing robber copy is not advertised as recoverable")
data[ot].cosmetics.owned.goldleaf=true
check(row(ov2,"goldleaf").stage=="recover","available copy resumes still-valid recovery")
data[ov2].cosmetics.owned.goldleaf=true
check(#H.objectives(ov2).claims==0,"buy-back or other reacquisition clears normal objective")
local latestOwner,olderRobber,newerRobber=player("Latest objective"),player("Older","bronze"),player("Newer","bronze")
H.record(latestOwner,olderRobber,{kind="skin",key="bronze"})
H.record(latestOwner,newerRobber,{kind="skin",key="bronze"})
check(row(latestOwner,"bronze").robberId==newerRobber.UserId,"objective points only at latest taker of this owner's skin")
local doneOwner,doneRobber=player("Finished objective","diamond"),player("Finished robber")
stealAndDeliver(doneRobber,doneOwner);stealAndDeliver(doneOwner,doneRobber)
check(#H.objectives(doneOwner).claims==0,"successful free recovery clears objective")
-- Insured spares are genuinely missing even though the owned skin remains.
local os,oss=player("Spare objective","goldleaf"),player("Spare robber")
data[os].spares["skin:goldleaf"]=1;take(oss,os)
check(row(os,"goldleaf").stage=="chase" and row(os,"goldleaf").cost==nil,"spare has chase but no paid replacement")
H.deliver(oss)
check(row(os,"goldleaf").stage=="recover" and row(os,"goldleaf").name:find("Spare",1,true)==1,"spare recovery is labelled while skin remains worn")
now+=Config.REVENGE.window
check(#H.objectives(os).claims==0,"expired insured spare never invents a buy-back")
-- Rejoin has only persisted seasonal eligibility; free claims are session-local.
local rejoin=player("Rejoin")
data[rejoin].claims={bronze=Config.seasonIndex(),goldleaf=Config.seasonIndex()-1}
check(#H.objectives(rejoin).claims==1 and row(rejoin,"bronze").stage=="buyback","rejoin shows only current persisted claims")
-- Actual subscription/poll wiring: initial state, dedup, no foreign claims,
-- no trusted client payload, throttle, load race and lifecycle cleanup.
local polling
local priorTask=env.task
env.task={spawn=function(fn) polling=coroutine.create(fn);assert(coroutine.resume(polling)) end,
 wait=function(seconds) check(seconds==0.25,"objective poll within one second");return coroutine.yield() end}
H.startObjectives()
handlers.RecoveryObjective(rejoin,{claims={{key="diamond",cost=0}}})
check(events[rejoin].RecoveryObjective.claims[1].key=="bronze","subscribe ignores forged client claims")
local last=sent
handlers.RecoveryObjective(rejoin);assert(coroutine.resume(polling,0.25))
check(sent==last,"duplicate subscription and unchanged poll send nothing")
local late=player("Loading");local loaded=data[late];data[late]=nil
handlers.RecoveryObjective(late);check(events[late]==nil,"unloaded subscription does not fabricate data")
data[late]=loaded;assert(coroutine.resume(polling,0.25))
check(events[late].RecoveryObjective and #events[late].RecoveryObjective.claims==0,"load after subscription receives first snapshot")
data[rejoin].cosmetics.owned.bronze=true;assert(coroutine.resume(polling,0.25))
check(#events[rejoin].RecoveryObjective.claims==0,"ownership mutation pushes cleared card")
leaving(rejoin);local afterLeaving=sent
data[rejoin].cosmetics.owned.bronze=nil;assert(coroutine.resume(polling,0.25))
check(sent==afterLeaving,"departed subscriber no longer receives objectives")
env.task=priorTask
-- Lifetime progress counts deliveries, not coins, items, attempts or requests.
local counter=player("Counter")
local target=player("Counter target")
check(data[counter].robberies==0,"new thief has no completed robberies")
carry(counter,target);H.clear(counter);H.deliver(counter)
check(data[counter].robberies==0,"lost getaway gives no delivery credit")
carry(counter,target);H.deliver(counter);H.deliver(counter)
check(data[counter].robberies==1 and data[target].robberies==0,"player robbery credits thief once despite repeated delivery")
for _,victim in {{name="Resident",skin="bronze",plot={index=1}},
 {name="Shop",skin="goldleaf",plot={index=99,shop={}}}} do
 local before=data[counter].robberies
 carry(counter,victim);H.deliver(counter)
 check(data[counter].robberies==before+1,"resident and shop robberies count equally")
end
local prior=data[counter].robberies
local empty=carry(counter,target);empty.amount=0;H.deliver(counter)
check(data[counter].robberies==prior,"empty carry grants no lifetime credit")
local items=carry(counter,target);items.amount=0
items.haul={{kind="skin",key="bronze"},{kind="skin",key="goldleaf"}}
local originalGrant=modules.SetService.grant
modules.SetService.grant=function(...)
 check(data[counter].robberies==prior+1,"counter updates before item reward/save callbacks")
 H.deliver(counter)
 return originalGrant(...)
end
H.deliver(counter);modules.SetService.grant=originalGrant
check(data[counter].robberies==prior+1 and owned(counter,"bronze") and owned(counter,"goldleaf"),"multi-item skin-only delivery counts once even with reentrant requests")
local incomplete=carry(counter,target);incomplete.amount=1;H.deliver(counter)
check(data[counter].robberies==prior+2,"successfully delivered partial crack counts once")
local unavailable=player("Unloaded counter");carry(unavailable,target)
local pending=data[unavailable];data[unavailable]=nil;H.deliver(unavailable)
check(pending.robberies==0 and H.carrying[unavailable]~=nil,"unloaded save cannot receive delivery credit")
data[unavailable]=pending;H.deliver(unavailable)
check(pending.robberies==1,"delivery credits once when data is available")
-- Street publication follows actual server allowance and recovery claims.
local capped=player("Capped")
data[capped].coins=1000
local capLoss=1000*Config.LOSS_CAP.fraction
check(H.allowance(capped,1000)==capLoss,"coin cap fixture begins with server allowance")
data[capped].coins=1000-capLoss;H.coinLosses[capped].lost=capLoss
local capEnds=now+Config.LOSS_CAP.window
check(H.street()[capped.UserId].cappedUntil==capEnds,"spent allowance publishes window deadline")
data[capped].coins+=4
check(H.street()[capped.UserId].cappedUntil==0,"new income reopens allowance and clears capped state")
data[capped].coins-=4
check(H.street()[capped.UserId].cappedUntil==capEnds,"same window retains deadline after income changes")
H.coinLosses[capped].lost-=10;data[capped].coins+=10
check(H.street()[capped.UserId].cappedUntil==0,"returned coins clear cap")
H.coinLosses[capped].lost=capLoss;data[capped].coins=1000-capLoss
now=capEnds+.01
check(H.street()[capped.UserId].cappedUntil==0,"expired cap clears from same authoritative calculation")
local ownerA,ownerB,hotRobber=player("Badge A"),player("Badge B"),player("Hot robber")
data[hotRobber].cosmetics.owned.bronze=true;data[hotRobber].cosmetics.owned.goldleaf=true
H.record(ownerA,hotRobber,{key="bronze"});now+=10;H.record(ownerB,hotRobber,{key="goldleaf"})
local public=H.street()[hotRobber.UserId]
check(public.hotUntil==now+Config.REVENGE.window,"public hot deadline includes multiple independent victims")
check(public.claims==nil and public.key==nil and public.robberId==nil,"public state exposes no private claim details")
data[hotRobber].cosmetics.skin="classic"
check(H.street()[hotRobber.UserId].hotUntil==public.hotUntil,"outfit change leaves hot status intact")
data[ownerB].cosmetics.owned.goldleaf=true
check(H.street()[hotRobber.UserId].hotUntil==public.hotUntil-10,"reacquiring one skin leaves other owner's claim")
data[ownerA].cosmetics.owned.bronze=true
check(H.street()[hotRobber.UserId].hotUntil==0,"resolved last claim clears public mark")
-- Displayed player odds use the same eligibility function as the actual theft.
local viewer,target=player("Odds reader"),player("Odds target","bronze")
check(H.lootOdds(viewer,target).chance==1,"eligible skin shows guaranteed clean-crack odds")
data[viewer].cosmetics.owned.bronze=true
check(H.lootOdds(viewer,target).chance==1,"a skin the thief already owns is still advertised (it lands as a spare)")
data[viewer].cosmetics.owned.bronze=nil
H.losses[target]={since=now,lost=Config.SKIN_STEAL.cap}
check(H.lootOdds(viewer,target).chance==0,"capped skin advertises no drop")
H.losses[target].since=now-Config.SKIN_STEAL.window-1
check(H.lootOdds(viewer,target).chance==1,"expired limit restores displayed skin odds")
data[target].cosmetics.skin="classic"
local unworn=H.lootOdds(viewer,target)
check(unworn.chance==1 and not unworn.worn and unworn.others==1,"an owned skin not being worn is still on offer")
H.record(viewer,target,{key="bronze"})
check(H.lootOdds(viewer,target).chance==1 and H.lootOdds(viewer,target).name==Config.SKINS.bronze.name,"recovery odds name actual skin despite changed outfit")
claim(viewer,target,"bronze").reserved=true
check(H.lootOdds(viewer,target).chance==0,"in-transit recovery cannot promise another skin")
local resident={plot={}}
check(H.lootOdds(viewer,resident).chance==0 and H.lootOdds(viewer,resident).reason=="Coins only","resident pig shows honest zero item odds")
resident.plot.shop="gear";data[viewer].robberies=99
check(H.lootOdds(viewer,resident).locked and H.lootOdds(viewer,resident).chance==0,"shop preview uses viewer rank")
data[viewer].robberies=100
local preview=H.lootOdds(viewer,resident)
check(preview.chance==.03 and preview.tiers.legendary>0 and preview.pool==nil,"shop preview publishes actual rarity odds without per-tick model pool")
-- THE PIG-CRACK ACORN WAS MINTED HERE and retired with the currency. What a
-- clean crack still does is stamp `clean` on the carry, which the delivery
-- reads for the Clean Sheet trophy -- so the flag is exercised below rather
-- than the payout that used to hang off it.
local at,av=player("CleanThief"),player("CleanVictim")
local cc=carry(at,av);cc.clean=true;H.deliver(at)
check(events[at].HeistDelivered.acorns==nil,"a delivery summary carries no second currency")
H.record(at,av);local rv=carry(at,av);rv.clean=true
check(H.isRevenge(at,av),"grudge set up");H.deliver(at)
check(events[at].HeistDelivered.revenge==true,"a clean revenge crack still reads as revenge")
-- endCrack is what stamps the flag, on "done" only.
local et,ev=player("EndThief"),player("EndVictim")
local function crackFor(p,v,steps) H.cracking[p]={victim=v,plot=nil,sack=0,locks=0,picks=0,steps=steps,banked=5,pig0=100,allowance0=100,stepStart=now,zone=0,width=1,lastTap=now,ending=false} end
local done=carry(et,ev);crackFor(et,ev,5);H.endCrack(et,"done")
check(done.clean==true,"endCrack stamps a clean run on the carry")
H.clear(et)
local missed=carry(et,ev);crackFor(et,ev,3);H.endCrack(et,"range")
check(missed.clean==nil,"a crack ended early leaves the carry unstamped")
H.clear(et)
check(Config.crackAcorns==nil,"the pig-crack acorn gate is retired")
check(Config.MIDNIGHT==nil,"no event multiplies a steal any more")

-- THE PIG HAS NO CEILING (designer decision 2026-09-21, reversing 4c.6): a
-- delivery banks the whole payout whatever the thief already holds, no
-- `spilled` travels, and nothing on any toast says spilled or full.
local PAY=10*Config.HEIST_PAYOUT
local capT,capV=player("CapThief"),player("CapVictim")
check(Config.getCapacity==nil and Config.fitInPig==nil,"the cap and its clamp are retired")
data[capT].coins=1e12
local lostBefore=data[capV].totalLost
local full=carry(capT,capV);full.clean=true;H.deliver(capT)
local sum=events[capT].HeistDelivered
check(data[capT].coins==1e12+PAY and sum.banked==PAY and sum.spilled==nil,"a delivery onto a huge balance banks the whole payout")
check(not events[capT].Notify:find("spill",1,true) and not events[capT].Notify:lower():find("full",1,true),"and nothing says spilled or full")
check(data[capV].totalLost==lostBefore+10,"the victim is charged the full amount")
check(data[capT].robberies==1 and data[capT].totalStolen==10,"the robbery and the stolen total count")
check(sum.fullAt==Config.pigFullAt(0) and sum.fullAt==Config.getRebirthThreshold(0),
 "the summary carries what the pile reads as full -- the rebirth cash gate -- for the coin stream, never a cap")
data[capT].coins=0
carry(capT,capV);H.deliver(capT)
sum=events[capT].HeistDelivered
check(data[capT].coins==PAY and sum.banked==PAY,"an empty pig banks the full payout")
-- The toast that ends a crack promises exactly what the delivery then banks.
local function previewThenDeliver(coins)
 data[capT].coins=coins
 local c=carry(capT,capV);crackFor(capT,capV,5);H.cracking[capT].banked=10;H.endCrack(capT,"done")
 local said=events[capT].Notify
 H.carrying[capT]=c;H.deliver(capT)
 return said,events[capT].HeistDelivered
end
local said,got=previewThenDeliver(0)
check(said:find(("worth %s at home"):format(Config.formatCoins(got.banked)),1,true),"empty pig: preview names the banked figure ("..said..")")
said,got=previewThenDeliver(1e12)
check(got.banked==PAY and said:find(("worth %s at home"):format(Config.formatCoins(PAY)),1,true) and not said:find("room",1,true),
 "huge balance: preview still names the whole payout ("..said..")")
-- Coins coming BACK are whole too, and silent.
local rv2=player("RefundVictim")
data[rv2].coins=1e12
check(H.giveBack(rv2,30)==30 and data[rv2].coins==1e12+30 and (events[rv2] or {}).Notify==nil,"a refund onto any balance banks in full and says nothing")
data[rv2].coins=0
check(H.giveBack(rv2,30)==30 and data[rv2].coins==30 and (events[rv2] or {}).Notify==nil,"an empty pig takes the whole refund silently")
-- Every coin return (nab, dog, patrol, voluntary return) goes through giveBack.

-- THE 50/50: the worn skin or a random other owned one.
local function coinFlip(roll,wear,extra)
 local thief,victim=player("Flip thief"),player("Flip victim",wear)
 for _,key in extra do data[victim].cosmetics.owned[key]=true end
 rng.roll=roll
 local c=take(thief,victim);rng.roll=0
 return c.haul[1] and c.haul[1].key
end
check(coinFlip(0.3,"bronze",{"goldleaf"})=="bronze","low roll takes the worn skin")
check(coinFlip(0.7,"bronze",{"goldleaf"})=="goldleaf","high roll takes another owned skin")
check(coinFlip(0.7,"bronze",{})=="bronze","nothing else owned: the worn skin takes the whole chance")
check(coinFlip(0.3,"classic",{"goldleaf"})=="goldleaf","unstealable outfit: a random owned skin takes the whole chance")
check(coinFlip(0.3,"velvet",{"velvet"})==nil,"a Robux skin is never taken")
check(coinFlip(0.7,"bronze",{"velvet","firstday"})=="bronze","Robux skins never enter the random half")
check(not Config.isStealableSkin("velvet") and not Config.isStealableSkin("firstday"),"pass skins are not stealable")
for key,skin in Config.SKINS do
 if skin.pass~=nil then check(skin.robux==true,key.." carries the robux tag") end
end
print(("PASS: %d theft checks; guaranteed clean cracks, worn/random 50/50, Robux skins never taken, per-owner timed stacks, latest taker, outfit independence, recovery/returns, insurance and unchanged payouts. No player saves."):format(checks))
