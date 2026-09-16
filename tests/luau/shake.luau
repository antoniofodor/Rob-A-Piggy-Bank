-- Real ShakeService and Config with isolated wallets and deterministic time.
local Config,source=...
local checks,now=0,1000
local function check(ok,msg) assert(ok,msg);checks+=1 end
local function noop() end
local nextId=0
local function actor()
 nextId+=1;return {player=true,UserId=nextId,Parent=true,DisplayName="P"..nextId,pos=0,health=100,data={loot=0,treeAcorns=0,groundAcorns=0,acornsGrownAt=now,coins=987}}
end
local function vector(x)
 return setmetatable({x=x},{__sub=function(a,b) return {Magnitude=math.abs(a.x-b.x)} end})
end
local packets,notices,handlers,escrow={},{},{},{}
local callbacks={}
local names=setmetatable({}, {__index=function(_,k) return k end})
local modules={Config=Config,DataService={get=function(p) return p.data end},
 PlotService={updateAcorns=function(plot,amount) plot.shown=amount end,updateTreeAcorns=function(plot,ripe,ground) plot.ripe=ripe;plot.ground=ground end,getAll=function() return {} end},
 ResidentService={get=function(plot) return plot.resident end},
 Remotes={get=function(name) return {FireClient=function(_,p,payload) packets[p]=packets[p] or {};packets[p][name]=payload end,
 OnServerEvent={Connect=function(_,fn) handlers[name]=fn end}} end}}
local env={script={Parent=names},require=function(name) return assert(modules[name],name) end,
 game={GetService=function(_,name) assert(name=="ReplicatedStorage");return {Shared=names} end},
 workspace={GetServerTimeNow=function() return now end},os={time=function() return math.floor(now) end},task={spawn=function(fn) table.insert(callbacks,fn) end}}
local run=assert(loadstring(source,"ShakeService"));setfenv(run,setmetatable(env,{__index=getfenv()}));local S=run()
local alerts,pushes=0,0
local failCarry=false
S.configure({player=function(v) return v.player end,id=function(v) return v.UserId end,name=function(v) return v.DisplayName end,
 plot=function(v) return v.plot end,root=function(p) return if p.noRoot then nil else {Position=vector(p.pos)} end,
 humanoid=function(p) return {Health=p.health} end,disabled=function(p) return p.disabled end,
 reason=function(p,v) if p.blocked then return "busy" end end,
 notify=function(p,msg) notices[p]=msg end,pushBalance=function() pushes+=1 end,
 opened=function() alerts+=1 end,caught=function(p,v,receipt)
  if failCarry then return false end
  local carry=escrow[p] or {amount=0,receipts={},victim=v};escrow[p]=carry
  carry.amount+=1;table.insert(carry.receipts,receipt);return true
 end})
local function victim(amount,player)
 local v=actor();v.player=player;v.pos=100
 if player then v.data.loot=amount else v.acornStock={acorns=amount,treeAcorns=0,groundAcorns=0,acornsGrownAt=now,raidReadyAt=0};v.loot=765 end
 v.plot={owner=if player then v else nil,resident=if not player then v else nil,
 acornTree={collider={Position=vector(0),Parent=true}},acornStorage={body={Position=vector(0),Parent=true}},model={SetAttribute=noop}}
 return v
end
local function open(p,v,source)
 S.open(p,v,source or "storage");return packets[p] and packets[p].ShakeState
end
local function current(p) return packets[p].ShakeState end
local function catch(p,s,i) S.catch(p,s.id,i) end
local a=actor();local r=victim(8,false)
local initial=open(a,r)
check(initial.count==2 and alerts==1,"resident with eight offers two and alarms at open")
check(r.acornStock.acorns==8 and escrow[a]==nil,"open reserves without debiting or granting")
catch(a,initial,1)
check(r.acornStock.acorns==8,"early catch refused")
now=initial.startedAt+.2
for _,bad in {false,{},"1",0,-1,3,1.5,math.huge,0/0} do S.catch(a,initial.id,bad) end
S.catch(a,initial.id+1,1)
check(r.acornStock.acorns==8,"malformed/out-of-range indices and stale attempt IDs refused")
catch(a,initial,1);catch(a,initial,1)
check(r.acornStock.acorns==7 and escrow[a].amount==1 and r.loot==765,"unique catch moves one Acorn, not resident carried coins")
now=initial.startedAt+1.7;catch(a,initial,2)
check(r.acornStock.acorns==6 and escrow[a].amount==2 and not S.isShaking(a),"second catch completes bounded attempt")
check(a.data.loot==0,"catch never applies payout or banks stolen Acorns")
open(a,r)
check(not S.isShaking(a) and notices[a]:find("resting"),"second shake inside sixty seconds refused")
S.refund(r,2,escrow[a].receipts)
check(r.acornStock.acorns==8,"failed getaway refunds raw caught amount")
S.refund(r,2,escrow[a].receipts)
check(r.acornStock.acorns==8,"same receipts cannot refund twice")
now+=Config.ACORNS.resident.raidSeconds+1;escrow[a]=nil
local s=open(a,r);now=s.startedAt+.2;failCarry=true;catch(a,s,1);failCarry=false
check(r.acornStock.acorns==8 and not S.isShaking(a),"failed carry attachment refunds debit and ends attempt")

-- All thieves share one rolling victim budget, including reservations.
local rich=victim(135,true);local b,c,d=actor(),actor(),actor()
local sb=open(b,rich)
check(sb.count==4,"rich target offers at most four")
open(c,rich)
check(not S.isShaking(c) and notices[c]:find("loss limit"),"concurrent attempt cannot over-reserve the cap")
S.finish(b,"stop")
local sc=open(c,rich)
check(sc.count==4,"stopping releases uncaught reservations")
now=sc.startedAt+1.8
for i=1,4 do catch(c,sc,i) end
check(rich.data.loot==131 and escrow[c].amount==4 and rich.data.coins==987,"four accepted catches debit only Acorns")
open(d,rich)
check(not S.isShaking(d) and notices[d]:find("loss limit"),"four lost this hour refuses with named reason, no empty minigame")
S.refund(rich,2,escrow[c].receipts)
check(rich.data.loot==133,"partial recovery returns two whole Acorns")
local sd=open(d,rich)
check(sd.count==2,"only refunded allowance reopens")
now=sd.startedAt+1.8;catch(d,sd,1);catch(d,sd,2)
check(rich.data.loot==131,"another thief cannot exceed net loss cap")
local e=actor();open(e,rich)
check(not S.isShaking(e),"shared cap still holds after mixed recoveries")

-- Exactly rolling: old receipts expire independently; refunding one must not
-- erase losses recorded later in the same victim's window.
now=sc.startedAt+1.8+Config.ACORNS.lossWindow
local se=open(e,rich)
check(se.count==2,"only older two losses expire at rolling boundary")
S.finish(e,"stop")
S.refund(rich,2,escrow[c].receipts)
local f=actor();local sf=open(f,rich)
check(sf.count==2,"refund of aged receipt does not erase newer losses")
S.finish(f,"stop")

-- Revalidate scene/character facts on the catch as well as the poll.
for _,reason in {"range","dead","owner","replacement","disabled","gone"} do
 local p=actor();local v=victim(8,true);local schedule=open(p,v);assert(schedule and schedule.count==2)
 now=schedule.startedAt+.2
 if reason=="range" then p.pos=100
 elseif reason=="dead" then p.health=0
 elseif reason=="owner" then v.pos=0
 elseif reason=="replacement" then v.plot.owner=actor()
 elseif reason=="disabled" then p.disabled=true
 else p.noRoot=true end
 catch(p,schedule,1)
 check(v.data.loot==8 and not S.isShaking(p),reason.." cancels before debit")
end
local guard=actor();local guarded=victim(8,true);guarded.pos=0
open(guard,guarded)
check(not S.isShaking(guard) and notices[guard]:find("guarding"),"owner at trunk prevents opening")
local empty=victim(3,false);local g=actor();open(g,empty)
check(S.isShaking(g) and current(g).count==1,"three stored Acorns offer one without four-Acorn minimum")
S.finish(g,"stop")
local shop=victim(8,false);shop.plot.shop="shop";open(g,shop)
check(not S.isShaking(g) and notices[g]:find("no Acorn tree"),"shop cannot be shaken")
local timed=victim(8,false);local h=actor();local sh=open(h,timed)
now=sh.endsAt+Config.ACORNS.catchGrace+.01;S.poll()
check(not S.isShaking(h) and timed.acornStock.acorns==8,"timeout releases reservation without loss")
local gone=victim(8,true);local j=actor();local sj=open(j,gone)
S.leaving(gone)
check(not S.isShaking(j) and gone.data.loot==8,"victim departure closes attempts")
local k=actor();local v=victim(8,false);local sk=open(k,v)
S.start();handlers.ShakeStop(k,sk.id+1)
check(S.isShaking(k),"stale stop cannot close newer attempt")
handlers.ShakeStop(k,sk.id)
check(not S.isShaking(k),"matching stop releases attempt")
check(pushes>0,"player balances are pushed on debit/refund")
-- Tree stock, loose ground stock and banked storage are three independent balances.
local farmer=victim(8,true);farmer.pos=0;farmer.data.treeAcorns=8
local tree=open(farmer,farmer,"tree")
check(tree.count==8 and tree.source=="tree" and tree.own,"owner can harvest all eight in a five-second round")
check(tree.endsAt-tree.startedAt==5,"collection timer is exactly five seconds")
check(farmer.data.loot==8 and farmer.data.treeAcorns==0 and farmer.data.groundAcorns==8,"shaking moves ripe stock to ground without changing stored eight")
now=tree.startedAt+.2;catch(farmer,tree,1);catch(farmer,tree,1)
check(farmer.data.groundAcorns==7 and escrow[farmer].amount==1 and farmer.data.loot==8,"unique owner drag moves one into carry without banking")
S.finish(farmer,"stop")
local again=open(farmer,farmer,"tree")
check(again.count==7,"owner immediately retries remaining ground Acorns")
S.finish(farmer,"stop")
S.refund(farmer,1,escrow[farmer].receipts)
check(farmer.data.groundAcorns==8 and farmer.data.loot==8,"failed own harvest returns to ground, never shortcuts deposit")
S.refund(farmer,1,escrow[farmer].receipts)
check(farmer.data.groundAcorns==8,"ground refund receipts are idempotent")
now+=Config.ACORNS.groundSeconds+1
open(farmer,farmer,"tree")
check(not S.isShaking(farmer) and farmer.data.groundAcorns==0,"uncollected loose Acorns expire after a minute")
farmer.data.treeAcorns=1
local single=open(farmer,farmer,"tree")
check(single.count==1,"one ripe Acorn is enough to shake")
now=single.startedAt+.2;catch(farmer,single,1)
check(not S.isShaking(farmer) and farmer.data.loot==8,"one ripe catch completes without stored balance movement")

local target=victim(135,true);target.data.treeAcorns=8
local raider,other=actor(),actor()
local raid=open(raider,target,"tree")
check(raid.count==8,"tree theft is independent of quarter-share storage rule")
open(other,target,"tree")
check(not S.isShaking(other),"concurrent collectors cannot reserve the same ground stock")
now=raid.startedAt+.2;catch(raider,raid,1);S.finish(raider,"stop")
local storage=open(other,target,"storage")
check(storage.count==4,"tree theft never consumes the storage loss budget")
S.finish(other,"stop")
S.refund(target,1,escrow[raider].receipts)
check(target.data.loot==135 and target.data.groundAcorns==8,"stolen tree Acorns refund to the tree ground, not victim storage")
local bad=actor();S.open(bad,target,"bogus")
check(not S.isShaking(bad),"unknown source cannot start an attempt")
S.open(target,target,"storage")
check(not S.isShaking(target),"owner cannot raid own banked storage for payout")
local late=actor();local ltarget=victim(8,false);local ls=open(late,ltarget)
now=ls.endsAt+Config.ACORNS.catchGrace+.01;catch(late,ls,1)
check(ltarget.acornStock.acorns==8 and not S.isShaking(late),"late catch cannot collect after the server timer")
-- Resident cadence belongs to the plot stock, not to one thief or source.
local npc=victim(2,false);npc.acornStock.treeAcorns=2
local first,second=actor(),actor()
local started=open(first,npc,"tree")
check(started.count==2 and npc.acornStock.raidReadyAt==math.floor(now)+900,"valid resident opening starts quarter-hour")
S.finish(first,"stop")
open(second,npc,"storage")
check(not S.isShaking(second) and notices[second]:find("resting"),"another thief cannot bypass the shared cooldown through storage")
now=npc.acornStock.raidReadyAt-.1;open(second,npc,"storage")
check(not S.isShaking(second),"resident remains protected just before cooldown boundary")
now=npc.acornStock.raidReadyAt;local reopened=open(second,npc,"storage")
check(reopened and reopened.count==1 and S.isShaking(second),"resident raid reopens at exact boundary")
S.finish(second,"stop")
local poor=victim(0,false);local visitor=actor();open(visitor,poor,"storage")
check(poor.acornStock.raidReadyAt==0 and not S.isShaking(visitor),"empty refusal never consumes resident cooldown")
local far=victim(2,false);local wanderer=actor();wanderer.pos=100;open(wanderer,far,"tree")
check(far.acornStock.raidReadyAt==0 and far.acornStock.treeAcorns==0,"out-of-range refusal never consumes stock or cadence")
local old=victim(2,false);old.acornStock.treeAcorns=1;local robber=actor()
local offer=open(robber,old,"tree");now=offer.startedAt+.2;catch(robber,offer,1)
local replacement=victim(0,false);replacement.acornStock=old.acornStock
old.plot.owner=actor()
S.refund(old,1,escrow[robber].receipts)
check(replacement.acornStock.groundAcorns==1 and old.plot.owner.data.loot==0,"old receipt returns into shared resident stock without crediting the new player")
check(replacement.acornStock.raidReadyAt>now,"replacement retains original resident cooldown")
-- Cooldown snapshots are targeted, authoritative and repair late listeners.
local privateTarget=victim(8,true);privateTarget.data.treeAcorns=2
local viewer,otherViewer=actor(),actor()
local privateOpen=open(viewer,privateTarget,"tree")
local privateEnds=now+Config.ACORNS.shakeCooldown
check(packets[viewer].AcornCooldown[privateTarget.UserId]==privateEnds,"successful opening sends server deadline privately")
check(not packets[otherViewer],"another thief receives no private cooldown broadcast")
S.finish(viewer,"stop");open(viewer,privateTarget,"storage")
check(not S.isShaking(viewer) and packets[viewer].AcornCooldown[privateTarget.UserId]==privateEnds,"switching source cannot reset or bypass private cooldown")
handlers.AcornCooldown(otherViewer,{[privateTarget.UserId]=0})
check(next(packets[otherViewer].AcornCooldown)==nil,"forged client deadline receives only caller's actual cooldowns")
handlers.AcornCooldown(viewer)
check(packets[viewer].AcornCooldown[privateTarget.UserId]==privateEnds,"late subscriber recovers active deadline")
local cached=packets[viewer].AcornCooldown
handlers.AcornCooldown(viewer)
check(packets[viewer].AcornCooldown==cached,"subscribe requests are throttled")
now=privateEnds;handlers.AcornCooldown(viewer)
check(packets[viewer].AcornCooldown[privateTarget.UserId]==nil,"expired deadline omitted from next snapshot")
local own=victim(8,true);own.pos=0;own.data.treeAcorns=1
open(own,own,"tree")
check(packets[own].AcornCooldown==nil,"own harvest starts no theft timer")
print(("PASS: %d shake checks; schedules, replay limits, caps, refunds, concurrent attempts and interruptions."):format(checks))
