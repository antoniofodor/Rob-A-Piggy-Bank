-- Real HeistService tug, handOff, prompt binding and confiscation. Instance,
-- movement and clock doubles isolate geometry/network/saves from accounting.
local Config, source = ...
local checks, now, serial = 0, 100, 0
local function check(ok,msg) assert(ok,msg); checks+=1 end
local function noop() end
local vm={}
local function v(x,y,z) return setmetatable({X=x,Y=y,Z=z},vm) end
vm.__sub=function(a,b) return {Magnitude=math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)} end
local frame=setmetatable({}, {__mul=function(a,b) return a end})
local jobs,delays={},{}
local function resume(co) local ok,err=coroutine.resume(co);assert(ok,err) end
local function step()
 now+=Config.NAB.tickRate
 for _,co in table.clone(jobs) do if coroutine.status(co)~="dead" then resume(co) end end
end
local function finish() for _=1,5 do step() end end
local modules={Config=Config,AcornBasket={},AcornModel={},CarryPose={HOLD=frame},SoundKit={on=noop}}
for _,name in {"PiggyBank","UpgradeService","GuardDog","EventService","ResidentService","SocialService","SetService","CosmeticsService"} do modules[name]={} end
modules.DataService={get=function(p) return p.data end}
modules.PlotService={getPlot=function() return nil end}
modules.TrophyService={recordCatch=function(p) p.catches=(p.catches or 0)+1 end}
modules.SeasonService={earn=function() end,recordNemesis=function() end}
for _,k in {"recordClean","recordWanted","recordHarvest","recheck","recordVictim","recordSpree","recordCatch"} do modules.TrophyService[k]=modules.TrophyService[k] or function() end end
modules.ShakeService={finish=function(p) p.shaking=false end,isShaking=function(p) return p.shaking==true end,
 refund=function(victim,amount,receipts)
  local left=amount
  for _,r in receipts do local n=math.min(r.amount,left);r.amount-=n;left-=n end
  victim.data.loot+=amount-left
 end}
modules.Remotes={get=function(name) return {FireClient=function(_,p,...)
 p.events=p.events or {};p.events[name]={...}
end} end}
local names=setmetatable({}, {__index=function(_,k) return k end})
local env={game={GetService=function(_,name) return if name=="ReplicatedStorage" then {Shared=names} else {} end},
 require=function(n) return assert(modules[n],n) end,script={Parent=names},Color3={fromRGB=noop},Vector3={new=v},
 os={clock=function() return now end},workspace={GetServerTimeNow=function() return now end},
 typeof=function(x) return if type(x)=="table" and x.player then "Instance" else typeof(x) end,
 task={spawn=function(fn) local co=coroutine.create(fn);table.insert(jobs,co);resume(co) end,
 wait=function() coroutine.yield() end,delay=function(_,fn) table.insert(delays,fn) end}}
local tail=[[
getRoot=function(p) return p.root end
getHumanoid=function(p) return p.humanoid end
endCrack=function(p) cracking[p]=nil end
setCarrySpeed=function(p,slow) p.slow=slow;p.humanoid.WalkSpeed=if slow then 12 else 16 end
dropShield=function(p) p.shield=false end
HeistService.setTiptoe=function(p,on) p.tiptoe=on end
HeistService.isDodgeImmune=function(p) return p.dodge==true end
pushCarryState=function(p) p.pushed=carrying[p] or false end
returnHaul=function(c) c.returnedHaul=true;c.haul={} end
fireCatchEffect=function(p,winner) p.effectWinner=winner end
return {newCarry=newCarry,carrying=carrying,tugs=tugs,rest=nabRest,cracking=cracking,
 nab=HeistService.nab,tick=tugTick,finish=endTug,handOff=handOff,winner=catchWinner,
 confiscate=HeistService.confiscate,clear=clearCarry,deliver=deliver,canDeliver=canDeliverCarry,inBin=inBin,rides=rideMultiplier}
]]
local modified,n=source:gsub("return HeistService%s*$",tail);assert(n==1)
if modules.SocialService then modules.SocialService.recordDefend=modules.SocialService.recordDefend or function() end end
local run=assert(loadstring(modified,"handoff"));setfenv(run,setmetatable(env,{__index=getfenv()}));local H=run()
local function actor()
 serial+=1
 local char={attributes={}}
 function char:SetAttribute(k,val) self.attributes[k]=val end
 local p={player=true,UserId=serial,DisplayName="P"..serial,Parent=true,Character=char,
  data={coins=100,loot=8,robberies=0,capacityLevel=1},humanoid={Health=100,WalkSpeed=16,Parent=char},shield=true,tiptoe=true}
 p.root={Position=v(0,0,0),CFrame=frame,Parent=char};return p
end
local function carry(p,victim,kind,amount)
 local prompt={Triggered={}}
 function prompt.Triggered:Connect(fn) self.fire=fn end
 local weld={Part0=p.root,IsA=function(_,name) return name=="WeldConstraint" end}
 local body={FindFirstChild=function(_,name) return if name=="CarryWeld" then weld else nil end};weld.Part1=body
 local model={PrimaryPart=body,Parent=p.Character,Destroy=function(self) self.destroyed=true;self.Parent=nil end}
 function model:PivotTo(cf) assert(weld.Part0==nil,"detach before repositioning");self.at=cf end
 local c=H.newCarry(p,victim,amount or 17,model,prompt,kind,if kind=="basket" then {amount=amount or 17,source="tree"} else nil)
 c.haul={{kind="skin",key="bronze",victim=victim}};c.inRange=true
 H.carrying[p]=c;p.slow=true;p.humanoid.WalkSpeed=12
 p.Character:SetAttribute(Config.CARRY_VICTIM_ATTRIBUTE,victim.UserId)
 return c,weld
end
for _,kind in {"pig","basket"} do
 local thief,winner,victim=actor(),actor(),actor()
 local c,weld=carry(thief,victim,kind,17);local haul,receipts,model,prompt=c.haul,c.receipts,c.loot,c.prompt
 H.cracking[thief]={};thief.shaking=true
 H.nab(winner,thief)
 check(H.tugs[thief] and H.tugs[thief].progress==0,"opening waits before counting the first tick")
 check(not thief.shaking and H.cracking[thief]==nil,"tug closes ongoing grab")
 for _=1,4 do step() end
 check(H.carrying[thief]==c and c.amount==17 and victim.data.coins==100 and victim.data.loot==8,"partial tug moves no escrow")
 step()
 check(H.carrying[thief]==nil and H.carrying[winner]==c,"completion changes exactly one carrying index")
 check(c.claimant==thief and c.holder==winner and c.victim==victim,"claimant and victim survive holder change")
 check(c.haul==haul and c.receipts==receipts and c.amount==17 and not c.returnedHaul,"haul and receipts remain the same escrow")
 check(c.loot==model and c.prompt==prompt and model.Parent==winner.Character and weld.Part0==winner.root,"same loot and prompt welded to new character")
 check(prompt.ObjectText==winner.DisplayName and c.inRange==nil,"prompt names current holder and clears old delivery range")
 check(thief.Character.attributes[Config.CARRY_VICTIM_ATTRIBUTE]==nil and winner.Character.attributes[Config.CARRY_VICTIM_ATTRIBUTE]==victim.UserId,"victim marker follows loot")
 check(thief.humanoid.WalkSpeed==16 and winner.humanoid.WalkSpeed==12 and #delays==0,"loser remains unstunned; winner gets carry speed")
 check(winner.shield==false and winner.tiptoe==false and winner.pushed==c and thief.pushed==false,"transfer publishes both players and drops winner protection")
 check(winner.catches==1 and thief.effectWinner==winner,"successful transfer records catch and winner effect")
 check(winner.data.coins==100 and winner.data.loot==8 and victim.data.coins==100 and victim.data.loot==8,"handoff never pays bounty or refunds currency")
 H.finish(thief,"emptied");check(winner.catches==1 and H.carrying[winner]==c,"duplicate completion is inert")
 check(H.canDeliver(winner,c),"new holder is eligible for alternate settlement")
 -- This is the original connection, created at grab, now targeting the new holder.
 prompt.Triggered.fire(thief)
 check(H.tugs[winner]==nil and H.rest[winner]>now,"new holder rest blocks immediate re-nab through transferred prompt")
 now=H.rest[winner]+.01;prompt.Triggered.fire(thief)
 check(H.tugs[winner]~=nil and H.tugs[thief]==nil,"same prompt routes to holder rather than original thief")
 finish()
 check(H.carrying[thief]==c and c.holder==thief and c.claimant==thief and weld.Part0==thief.root,"original claimant can reclaim whole haul")
 local amount,target,currency=H.confiscate(thief)
 check(amount==17 and target==victim and currency==kind and c.returnedHaul,"patrol still confiscates full escrow and returns haul")
 check((if kind=="basket" then victim.data.loot==25 else victim.data.coins==117),"patrol refunds raw currency exactly once after repeated transfer")
 H.confiscate(thief)
 check((if kind=="basket" then victim.data.loot==25 else victim.data.coins==117),"repeat confiscation cannot duplicate transferred escrow")
end
-- Crowd rate, contribution ranking and active-winner filtering.
local t,victim,a,b,c=actor(),actor(),actor(),actor(),actor()
local held=carry(t,victim,"pig",0) -- haul-only transfers must still finish in one second.
H.nab(a,t);step();H.nab(b,t);H.nab(c,t);H.nab(b,t)
local tug=H.tugs[t]
check(tug.joinCount==3 and tug.joined[b]==2,"repeated joins cannot change tie priority")
step();check(math.abs(tug.progress-.4)<.000001,"three nabbers advance at the single-nabber rate")
a.root.Position=v(100,0,0)
for _=1,3 do step() end
check(H.carrying[b]==held and b.catches==1,"out-of-range leader cannot win; earliest remaining tie wins haul-only carry")
check(c.catches==1 and a.catches==1,"contributing helpers keep catch credit without currency payouts")
-- Refusals and cancellation preserve the original carry and award no catch.
for _,reason in {"dodge","range","dead","gone","busy","noRoot","noData","badWeld","staleCarry"} do
 local old,nabber,owner=actor(),actor(),actor();local escrow,weld=carry(old,owner,"basket",3)
 H.nab(nabber,old);step();local started=H.tugs[old]
 if reason=="dodge" then old.dodge=true
 elseif reason=="range" then nabber.root.Position=v(100,0,0)
 elseif reason=="dead" then nabber.humanoid.Health=0
 elseif reason=="gone" then nabber.Parent=nil
 elseif reason=="busy" then carry(nabber,owner,"pig",9)
 elseif reason=="noRoot" then nabber.root=nil
 elseif reason=="noData" then nabber.data=nil
 elseif reason=="badWeld" then weld.Part0=nil
 elseif reason=="staleCarry" then H.carrying[old]=H.newCarry(old,owner,4,{}, {Triggered={Connect=noop}}) end
 finish()
 check(H.tugs[old]==nil and not nabber.catches and not old.effectWinner,"cancelled/failed transfer has no catch: "..reason)
 check(escrow.amount==3 and escrow.receipts[1].amount==3 and owner.data.loot==8 and not escrow.returnedHaul,"refusal conserves escrow: "..reason)
 check(not H.tick(old,started),"old tick token cannot resume: "..reason)
end
-- Early completion cannot be forced, and old loops cannot finish replacement tugs.
local old,nabber,owner=actor(),actor(),actor();local escrow=carry(old,owner,"basket",1)
H.nab(nabber,old);H.finish(old,"emptied")
check(H.carrying[old]==escrow and not nabber.catches,"endTug validates actual completion")
now=H.rest[old]+.01;H.nab(nabber,old);local replacement=H.tugs[old]
step();check(H.tugs[old]==replacement and math.abs(replacement.progress-.2)<.000001,"stale coroutine cannot tick or end replacement tug")
H.confiscate(old);finish()
check(H.tugs[old]==nil and not nabber.catches and owner.data.loot==9,"confiscation during tug cancels it without awarding a catch")
-- Guard-dog route remains binary and retains its existing stun/refund.
local runner,guardOwner=actor(),actor();local dogCarry=carry(runner,guardOwner,"basket",2)
H.nab(guardOwner,runner,true)
check(H.carrying[runner]==nil and dogCarry.returnedHaul and guardOwner.data.loot==10,"dog returns full basket and haul immediately")
check(runner.humanoid.WalkSpeed==0 and #delays==1 and guardOwner.catches==1,"dog still stuns and credits its owner")
print(("PASS: %d handoff checks; real tug loop, full escrow, prompt rebinding, winner/rest, stale tasks, failures and dog/patrol refunds."):format(checks))
