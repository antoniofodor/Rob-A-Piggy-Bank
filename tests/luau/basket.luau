-- Real HeistService basket settlement/tug/range paths; geometry is isolated.
local Config,source=...
local checks,now=0,100
local function check(ok,msg) assert(ok,msg);checks+=1 end
local function noop() end
local vm={}
local function v(x,y,z) return setmetatable({X=x,Y=y,Z=z},vm) end
vm.__sub=function(a,b) return {Magnitude=math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)} end
local env={}
local events={}
local modules={Config=Config,AcornBasket={},AcornModel={fillCarry=function() end}}
for _,name in {"SoundKit","CarryPose","PiggyBank","UpgradeService","GuardDog","EventService","ResidentService"} do modules[name]={} end
modules.ResidentService.get=function(plot) return plot.resident end
modules.ShakeService={finish=noop,isShaking=function() return false end,refund=function(victim,amount,receipts)
 local remaining=amount
 for _,receipt in receipts do local back=math.min(receipt.amount,remaining);receipt.amount-=back;remaining-=back end
 local d=if victim.player then victim.data else victim
 if victim.player then d.loot+=amount-remaining else d.acorns+=amount-remaining end
end}
modules.DataService={get=function(p) return p.data end}
modules.PlotService={getPlot=function(p) return p.plot end,updateAcorns=function(plot,amount) plot.acorns=amount end,
 updateRank=function(plot,count) plot.rank=Config.getRapSheetRank(count) end}
modules.SetService={push=noop}
local heat,weekly=0,0
modules.SocialService={recordSteal=function(_,amount) heat+=amount end,recordWeekly=function(_,amount) weekly+=amount end,
 getSpreeMultiplier=function() return 99 end,markRevenge=noop}
modules.CosmeticsService={};modules.TrophyService={}
modules.Remotes={get=function(name) return {FireClient=function(_,p,...)
 events[p]=events[p] or {};events[p][name]={...}
end} end}
local names=setmetatable({}, {__index=function(_,k) return k end})
local environment={game={GetService=function(_,name) return if name=="ReplicatedStorage" then {Shared=names} else {} end},
 require=function(name) return assert(modules[name],name) end,script={Parent=names},Color3={fromRGB=noop},
 Vector3={new=v},os={clock=function() return now end},workspace={GetServerTimeNow=function() return now end},
 typeof=function(x) return if type(x)=="table" and x.player then "Instance" else typeof(x) end}
local tail=[[
getRoot=function(p) return p.root end
getHumanoid=function(p) return {Health=p.health or 100} end
clearCarry=function(p) local c=carrying[p];carrying[p]=nil;return c end
HeistService.isDodgeImmune=function(p) return p.dodge==true end
return {newCarry=newCarry,deliver=deliver,request=deliverRequest,carrying=carrying,grudge=grudge,near=carryNearHome,
 refund=returnCarryAmount,confiscate=HeistService.confiscate,tugs=tugs,tick=tugTick}
]]
local modified,n=source:gsub("return HeistService%s*$",tail);assert(n==1)
local run=assert(loadstring(modified,"HeistService basket"));setfenv(run,setmetatable(environment,{__index=getfenv()}));local H=run()
local serial=0
local function actor(rebirths)
 serial+=1
 return {player=true,UserId=serial,DisplayName="P"..serial,Parent=true,SetAttribute=noop,root={Position=v(0,1,0)},
 data={coins=500,loot=1,robberies=0,rebirths=rebirths or 0,totalStolen=12,totalLost=3},
 plot={base={Position=v(100,0,0)},acornStorage={body={Position=v(0,0,0)}}}}
end
local function carry(thief,victim,amount)
 local c=H.newCarry(thief,victim,amount,{}, {Triggered={Connect=noop}},"basket",{amount=amount})
 H.carrying[thief]=c;return c
end
for _,case in {{0,0,false,15},{0,2,false,21},{3,0,false,15},{0,0,true,30}} do
 local thief,victim=actor(case[1]),actor(case[2]);carry(thief,victim,3)
 if case[3] then H.grudge[thief]={[victim]={expires=now+60,skins={}}} end
 H.deliver(thief)
 check(thief.data.loot==1+case[4],"player delivery computes level/revenge multiplier once at delivery")
 check(thief.data.coins==500 and thief.data.totalStolen==12 and victim.data.totalLost==3,"Acorns never become coins or coin stats")
 check(thief.data.robberies==1 and H.carrying[thief]==nil,"delivery consumes carry and counts one robbery")
 check(H.grudge[victim][thief].expires>now,"player basket delivery opens grudge")
 H.deliver(thief)
 check(thief.data.loot==1+case[4] and thief.data.robberies==1,"duplicate delivery cannot pay/count twice")
 if case[3] then check(H.grudge[thief][victim].expires==0,"revenge bonus is consumed") end
end
local thief=actor();local resident={acorns=5,name="Resident",plot={index=9}}
carry(thief,resident,3);H.deliver(thief)
check(thief.data.loot==4,"resident delivery pays one for one")
check(heat==0 and weekly==0,"coin heat/weekly totals are not inflated; spree cannot multiply Acorns")
local t,victim=actor(),actor();local held=carry(t,victim,2)
victim.data.loot=6
local amount,target,kind=H.confiscate(t)
check(amount==2 and target==victim and kind=="basket" and victim.data.loot==8,"patrol refunds raw Acorns and reports correct kind")
check(victim.data.coins==500 and t.data.loot==1,"confiscation never banks or changes coins")
H.confiscate(t)
check(victim.data.loot==8,"second confiscation cannot duplicate refund")
local runner,owner,nabber=actor(),actor(),actor();owner.data.loot=6
local c=carry(runner,owner,2)
H.tugs[runner]={carry=c,nabbers={[nabber]=0},joined={[nabber]=1},joinCount=1,progress=0}
for i=1,3 do H.tick(runner) end
check(c.amount==2 and owner.data.loot==6,"partial tug never refunds or removes Acorns")
runner.dodge=true
check(not H.tick(runner) and c.amount==2,"dodge breaks basket tug with whole escrow intact")
runner.dodge=false
H.tick(runner);check(not H.tick(runner),"fifth tick completes timed tug regardless of basket size")
check(c.amount==2 and c.receipts[1].amount==2 and owner.data.loot==6 and nabber.data.coins==500,"completed tug awaiting handoff never refunds receipts or mints bounty")
local walker=actor();local carried=carry(walker,resident,1)
check(H.near(carried,walker.plot,walker.root),"basket delivers at home storage")
walker.root.Position=v(100,0,0)
check(not H.near(carried,walker.plot,walker.root),"home pig is not basket drop-off")
H.request(walker)
check(H.carrying[walker]~=nil and walker.data.loot==1,"out-of-range deliver request does not bank")
walker.root.Position=v(0,100,0)
check(not H.near(carried,walker.plot,walker.root),"basket drop-off checks vertical distance")
walker.root.Position=v(0,1,0);walker.health=0;H.request(walker)
check(H.carrying[walker]~=nil and walker.data.loot==1,"dead carrier cannot deliver")
walker.health=100;H.request(walker)
check(H.carrying[walker]==nil and walker.data.loot==2,"valid request settles at own crate once")
local farmer=actor(5);carry(farmer,farmer,8)
H.request(farmer)
check(farmer.data.loot==9 and farmer.data.robberies==0,"own harvest deposits one for one and never counts a robbery")
check(H.grudge[farmer]==nil,"harvesting cannot create a revenge claim against yourself")
H.request(farmer)
check(farmer.data.loot==9,"own harvest replay cannot duplicate deposit")
-- A stale carry index or future handoff must not receive original-claimant
-- settlement before the alternate settlement branch is implemented.
local original,other=actor(),actor()
local escrow=carry(original,resident,3)
check(escrow.claimant==original and escrow.holder==original,"catch records both identities at attachment")
for _,field in {"holder"} do
 escrow[field]=other
 H.request(original);H.deliver(original)
 check(original.data.loot==1 and original.data.robberies==0,"identity mismatch cannot bank or count an Acorn getaway")
 check(H.carrying[original]==escrow and escrow.receipts[1].amount==3,"refused delivery preserves raw escrow and refund receipts")
 escrow[field]=original
end
escrow.claimant=nil;H.request(original)
check(H.carrying[original]==escrow and original.data.loot==1,"missing claimant cannot use legacy full-payout path")
escrow.claimant=original;H.request(original)
check(original.data.loot==4 and H.carrying[original]==nil,"matching identities still settle preserved Acorns exactly once")
print(("PASS: %d basket checks; delivery multipliers, raw refunds, escrow-preserving tug, replay and drop-off range."):format(checks))
