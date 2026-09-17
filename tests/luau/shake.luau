-- Real ShakeService and Config with isolated wallets and deterministic time.
-- Step 2.6: storage is a bank, and another occupant's tree can only be shaken
-- while an acorn-theft event (Harvest Moon) is live -- simulated by `moon`.
local Config,source=...
local checks,now=0,1000
local function check(ok,msg) assert(ok,msg);checks+=1 end
local function noop() end
local nextId=0
local moon=false
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
 theftOpen=function() return moon end,
 notify=function(p,msg) notices[p]=msg end,pushBalance=function() pushes+=1 end,
 opened=function() alerts+=1 end,caught=function(p,v,receipt)
  if failCarry then return false end
  local carry=escrow[p] or {amount=0,receipts={},victim=v};escrow[p]=carry
  carry.amount+=1;table.insert(carry.receipts,receipt);return true
 end})
-- `ripe` on the tree, `stored` in the crate.
local function victim(ripe,player,stored)
 local v=actor();v.player=player;v.pos=100
 if player then v.data.loot=stored or 0;v.data.treeAcorns=ripe
 else v.acornStock={acorns=stored or 0,treeAcorns=ripe,groundAcorns=0,acornsGrownAt=now};v.loot=765 end
 v.plot={owner=if player then v else nil,resident=if not player then v else nil,
 acornTree={collider={Position=vector(0),Parent=true}},acornStorage={body={Position=vector(0),Parent=true}},model={SetAttribute=noop}}
 return v
end
local function stock(v) return if v.player then v.data else v.acornStock end
local function open(p,v,src)
 if packets[p] then packets[p].ShakeState=nil end
 S.open(p,v,src or "tree");return packets[p] and packets[p].ShakeState
end
local function current(p) return packets[p].ShakeState end
local function catch(p,s,i) S.catch(p,s.id,i) end

-- ---- STORAGE IS A BANK ------------------------------------------------------
local a=actor()
for _,isPlayer in {false,true} do
 for _,moonOn in {false,true} do
  moon=moonOn
  local banked=victim(0,isPlayer,40)
  local before=alerts
  open(a,banked,"storage")
  check(not S.isShaking(a) and notices[a]:find("banked",1,true),"storage refused by name (player="..tostring(isPlayer)..", moon="..tostring(moonOn)..")")
  check(stock(banked)[if isPlayer then "loot" else "acorns"]==40 and alerts==before,"a refused raid moves nothing and raises no alarm")
 end
end
moon=false
local owner=victim(0,true,9);owner.pos=0
open(owner,owner,"storage")
check(not S.isShaking(owner) and notices[owner]:find("already available",1,true),"owner opening their own crate is told it is already spendable")

-- ---- ANOTHER TREE ONLY UNDER THE MOON -----------------------------------------
local r=victim(2,false)
open(a,r)
check(not S.isShaking(a) and notices[a]:find("Harvest Moon",1,true),"a resident's tree is refused outside the moon")
check(r.acornStock.treeAcorns==2 and r.acornStock.groundAcorns==0 and alerts==0,"a refused shake knocks nothing loose and raises no alarm")
local p=victim(8,true)
open(a,p)
check(not S.isShaking(a) and notices[a]:find("Harvest Moon",1,true) and p.data.treeAcorns==8,"a player's tree is refused outside the moon")

moon=true
local initial=open(a,r)
check(initial.count==2 and alerts==1,"under the moon a resident tree opens and alarms")
check(r.acornStock.groundAcorns==2 and r.acornStock.treeAcorns==0 and escrow[a]==nil,"shaking knocks the crop loose without granting it")
check(r.acornStock.raidReadyAt==nil,"no resident raid cadence is stamped")
catch(a,initial,1)
check(r.acornStock.groundAcorns==2,"early catch refused")
now=initial.startedAt+.2
for _,bad in {false,{},"1",0,-1,3,1.5,math.huge,0/0} do S.catch(a,initial.id,bad) end
S.catch(a,initial.id+1,1)
check(r.acornStock.groundAcorns==2,"malformed/out-of-range indices and stale attempt IDs refused")
catch(a,initial,1);catch(a,initial,1)
check(r.acornStock.groundAcorns==1 and escrow[a].amount==1 and r.loot==765,"unique catch moves one Acorn, not resident carried coins")
now=initial.startedAt+1.7;catch(a,initial,2)
check(r.acornStock.groundAcorns==0 and escrow[a].amount==2 and not S.isShaking(a),"second catch completes bounded attempt")
check(a.data.loot==0 and r.acornStock.acorns==0,"catch never applies payout or touches storage")
open(a,r)
check(not S.isShaking(a) and notices[a]:find("Wait",1,true),"the same thief is held by the per-victim cooldown")
local second=actor();open(second,r)
check(not S.isShaking(second) and notices[second]:find("No loose or ripe",1,true),"another thief finds the tree empty rather than a resident resting")
S.refund(r,2,escrow[a].receipts)
check(r.acornStock.groundAcorns==2,"failed getaway refunds raw caught amount to the ground")
S.refund(r,2,escrow[a].receipts)
check(r.acornStock.groundAcorns==2,"same receipts cannot refund twice")
local again=open(second,r)
check(again and again.count==2 and S.isShaking(second),"no resident cadence: a different thief may shake the refunded ground at once")
S.finish(second,"stop")
now+=Config.ACORNS.shakeCooldown+1;escrow[a]=nil
r.acornStock.treeAcorns=2
local s=open(a,r);now=s.startedAt+.2;failCarry=true;catch(a,s,1);failCarry=false
check(r.acornStock.groundAcorns==2 and not S.isShaking(a),"failed carry attachment refunds debit and ends attempt")

-- Concurrent collectors share one ground stock.
local target=victim(8,true,135)
local raider,other=actor(),actor()
local raid=open(raider,target)
check(raid.count==8,"a moonlit player tree offers its whole crop")
open(other,target)
check(not S.isShaking(other),"concurrent collectors cannot reserve the same ground stock")
now=raid.startedAt+.2;catch(raider,raid,1);S.finish(raider,"stop")
check(target.data.loot==135,"tree theft never touches the victim's bank")
S.refund(target,1,escrow[raider].receipts)
check(target.data.loot==135 and target.data.groundAcorns==8,"stolen tree Acorns refund to the tree ground, not victim storage")
local bad=actor();S.open(bad,target,"bogus")
check(not S.isShaking(bad),"unknown source cannot start an attempt")

-- Revalidate scene/character facts on the catch as well as the poll.
for _,reason in {"range","dead","owner","replacement","disabled","gone"} do
 local thief=actor();local v=victim(8,true);local schedule=open(thief,v);assert(schedule and schedule.count==8)
 now=schedule.startedAt+.2
 if reason=="range" then thief.pos=100
 elseif reason=="dead" then thief.health=0
 elseif reason=="owner" then v.pos=0
 elseif reason=="replacement" then v.plot.owner=actor()
 elseif reason=="disabled" then thief.disabled=true
 else thief.noRoot=true end
 catch(thief,schedule,1)
 check(v.data.groundAcorns==8 and not S.isShaking(thief),reason.." cancels before debit")
end
local guard=actor();local guarded=victim(8,true);guarded.pos=0
open(guard,guarded)
check(not S.isShaking(guard) and notices[guard]:find("guarding"),"owner at trunk prevents opening")
check(guarded.data.treeAcorns==8,"a guarded tree stays on the branch")
local g=actor()
local shop=victim(8,false);shop.plot.shop="shop";open(g,shop)
check(not S.isShaking(g) and notices[g]:find("no Acorn tree"),"shop cannot be shaken")
local timed=victim(8,false);local h=actor();local sh=open(h,timed)
now=sh.endsAt+Config.ACORNS.catchGrace+.01;S.poll()
check(not S.isShaking(h) and timed.acornStock.groundAcorns==8,"timeout releases reservation without loss")
local gone=victim(8,true);local j=actor();open(j,gone)
S.leaving(gone)
check(not S.isShaking(j) and gone.data.groundAcorns==8,"victim departure closes attempts")
local k=actor();local v=victim(8,false);local sk=open(k,v)
S.start();handlers.ShakeStop(k,sk.id+1)
check(S.isShaking(k),"stale stop cannot close newer attempt")
handlers.ShakeStop(k,sk.id)
check(not S.isShaking(k),"matching stop releases attempt")
check(pushes>0,"player balances are pushed on debit/refund")
local late=actor();local ltarget=victim(8,false);local ls=open(late,ltarget)
now=ls.endsAt+Config.ACORNS.catchGrace+.01;catch(late,ls,1)
check(ltarget.acornStock.groundAcorns==8 and not S.isShaking(late),"late catch cannot collect after the server timer")
-- An old receipt refunds into the resident stock without crediting the new player.
local old=victim(1,false);local robber=actor()
local offer=open(robber,old);now=offer.startedAt+.2;catch(robber,offer,1)
local replacement=victim(0,false);replacement.acornStock=old.acornStock
old.plot.owner=actor()
S.refund(old,1,escrow[robber].receipts)
check(replacement.acornStock.groundAcorns==1 and old.plot.owner.data.loot==0,"old receipt returns into shared resident stock without crediting the new player")

-- Cooldown snapshots are targeted, authoritative and repair late listeners.
local privateTarget=victim(2,true)
local viewer,otherViewer=actor(),actor()
open(viewer,privateTarget)
local privateEnds=now+Config.ACORNS.shakeCooldown
check(packets[viewer].AcornCooldown[privateTarget.UserId]==privateEnds,"successful opening sends server deadline privately")
check(not packets[otherViewer],"another thief receives no private cooldown broadcast")
S.finish(viewer,"stop");open(viewer,privateTarget)
check(not S.isShaking(viewer) and packets[viewer].AcornCooldown[privateTarget.UserId]==privateEnds,"reopening cannot reset or bypass private cooldown")
handlers.AcornCooldown(otherViewer,{[privateTarget.UserId]=0})
check(next(packets[otherViewer].AcornCooldown)==nil,"forged client deadline receives only caller's actual cooldowns")
handlers.AcornCooldown(viewer)
check(packets[viewer].AcornCooldown[privateTarget.UserId]==privateEnds,"late subscriber recovers active deadline")
local cached=packets[viewer].AcornCooldown
handlers.AcornCooldown(viewer)
check(packets[viewer].AcornCooldown==cached,"subscribe requests are throttled")
now=privateEnds;handlers.AcornCooldown(viewer)
check(packets[viewer].AcornCooldown[privateTarget.UserId]==nil,"expired deadline omitted from next snapshot")

-- ---- OWN HARVEST, WITH THE MOON DOWN ------------------------------------------
moon=false
local farmer=victim(8,true,8);farmer.pos=0
local tree=open(farmer,farmer)
check(tree.count==8 and tree.source=="tree" and tree.own,"owner can harvest all eight in a five-second round without any event")
check(tree.endsAt-tree.startedAt==5,"collection timer is exactly five seconds")
check(farmer.data.loot==8 and farmer.data.treeAcorns==0 and farmer.data.groundAcorns==8,"shaking moves ripe stock to ground without changing stored eight")
now=tree.startedAt+.2;catch(farmer,tree,1);catch(farmer,tree,1)
check(farmer.data.groundAcorns==7 and escrow[farmer].amount==1 and farmer.data.loot==8,"unique owner drag moves one into carry without banking")
S.finish(farmer,"stop")
local retry=open(farmer,farmer)
check(retry.count==7,"owner immediately retries remaining ground Acorns")
S.finish(farmer,"stop")
S.refund(farmer,1,escrow[farmer].receipts)
check(farmer.data.groundAcorns==8 and farmer.data.loot==8,"failed own harvest returns to ground, never shortcuts deposit")
S.refund(farmer,1,escrow[farmer].receipts)
check(farmer.data.groundAcorns==8,"ground refund receipts are idempotent")
now+=Config.ACORNS.groundSeconds+1
open(farmer,farmer)
check(not S.isShaking(farmer) and farmer.data.groundAcorns==0,"uncollected loose Acorns expire after a minute")
farmer.data.treeAcorns=1
local single=open(farmer,farmer)
check(single.count==1,"one ripe Acorn is enough to shake")
now=single.startedAt+.2;catch(farmer,single,1)
check(not S.isShaking(farmer) and farmer.data.loot==8,"one ripe catch completes without stored balance movement")
local own=victim(1,true);own.pos=0
open(own,own)
check(packets[own].AcornCooldown==nil,"own harvest starts no theft timer")
print(("PASS: %d shake checks; storage refused as a bank, moon-gated tree theft, replay limits, refunds, concurrent attempts and interruptions."):format(checks))
