-- ResidentService seat/tick/evict integration, with scene construction
-- stubbed. All clocks and coin worlds are isolated; no live saved data.
--
-- THE ACORN STOCK MODEL STOOD ABOVE THIS and was most of the file: a seed
-- split across a tree and a storage crate, an hourly crop, a fifteen-minute
-- harvest window, ground acorns expiring, and a suspend/resume handover
-- across an eviction. `ResidentAcorns` retired with the currency; what a
-- resident still has is a pig, defences and a place on the street.
--
-- AND NOW A LAWN THEY PLAY THE SAME GAME ON. The second half of this file
-- drives the real walker through a collect (their own pads fill and they
-- bank them), a snatch trip (they take a pedestal piggy off another lawn
-- through `PiggyHaulService`'s own resident core, carry it home and stand it
-- on a plinth of their own), the per-victim cooldown, the shield, the nab
-- give-back, the full-lawn swap and the eviction refund. The figure, the
-- route geometry and the prompts are mocks; the accounting is the real
-- Config and the real two services.
local Config,sources=...
local checks=0
local function check(ok,msg) assert(ok,msg);checks+=1 end
local names=setmetatable({}, {__index=function(_,k) return k end})

-- ------------------------------------------------------------
-- A VECTOR AND A FRAME THAT CAN BE WALKED
-- ------------------------------------------------------------
local VM={}
local function v(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},VM) end
VM.__add=function(a,b) return v(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
VM.__sub=function(a,b) return v(a.X-b.X,a.Y-b.Y,a.Z-b.Z) end
VM.__unm=function(a) return v(-a.X,-a.Y,-a.Z) end
VM.__mul=function(a,b)
	if type(a)=="number" then return v(a*b.X,a*b.Y,a*b.Z) end
	return v(a.X*b,a.Y*b,a.Z*b)
end
VM.__index=function(t,k)
	if k=="Magnitude" then return math.sqrt(t.X*t.X+t.Y*t.Y+t.Z*t.Z) end
	if k=="Unit" then local m=t.Magnitude; return v(t.X/m,t.Y/m,t.Z/m) end
	if k=="Cross" then return function(a,b) return v(a.Y*b.Z-a.Z*b.Y,a.Z*b.X-a.X*b.Z,a.X*b.Y-a.Y*b.X) end end
	return nil
end
local function dist(a,b) return (a-b).Magnitude end

local CF={}
local function cf(x,y,z)
	local p=if type(x)=="table" then x else v(x or 0,y or 0,z or 0)
	return setmetatable({Position=p,LookVector=v(0,0,-1)},CF)
end
CF.__index=CF
CF.__mul=function(a,b) return cf(a.Position+(b.Position or v())) end
local CFrame={new=cf,lookAt=function() return cf() end,Angles=function() return cf() end,
	fromAxisAngle=function() return cf() end}

-- ------------------------------------------------------------
-- THE WORLD
-- ------------------------------------------------------------
local now=10000
local rng=0          -- what `math.random()` answers
local rngPick=1      -- what `math.random(n)` answers (clamped to n)
local fakeMath=setmetatable({random=function(n)
	if n==nil then return rng end
	return math.clamp(rngPick,1,n)
end},{__index=math})

local plots={}
local players={}
local prompts={}     -- every ProximityPrompt handler connected, in order
local labels={}      -- every TextLabel built, in order
local buildFails=false

local function inst(class)
	local o={ClassName=class,Name=class,attributes={}}
	function o:SetAttribute(k,val) self.attributes[k]=val end
	function o:GetAttribute(k) return self.attributes[k] end
	function o:Destroy() self.Parent=nil;self.destroyed=true end
	if class=="ProximityPrompt" then
		o.Triggered={Connect=function(_,fn) table.insert(prompts,fn) return {} end}
	elseif class=="TextLabel" then
		table.insert(labels,o)
	end
	return o
end

local notes={}
local Remotes={get=function(name) return {FireClient=function(_,who,msg,kind)
	table.insert(notes,{to=who,name=name,msg=msg,kind=kind}) end} end}

local callbacks={}
local paints={slots=0,buffers=0,collects={}}
local modules={Config=Config,Remotes=Remotes,Theme={FONT="F",PAPER="p",INK="i",GOLD="g"},
	CarryPose={HOLD=cf(),anchor=function() return nil, cf() end},
	DataService={get=function(p) return p.data end,save=function() end},
	PiggyModel={
		build=function(key)
			if buildFails then error("no figure") end
			local body=inst("Part");body.Position=v()
			local m=inst("Model");m.body=body;m.key=key;m.Parent=nil
			function m:PivotTo() end
			function m:GetDescendants() return {body} end
			function body:IsA(c) return c=="BasePart" end
			return m
		end,
		bodyOf=function(m) return m.body end,
	},
	ResidentModel={
		build=function(plotIndex,name,at,groundY,parent)
			local torso={CFrame=cf(),IsA=function() return true end}
			local m=inst("Model");m.Parent=parent;m.torso=torso
			function m:FindFirstChild(n) return if n=="Tee" then torso else nil end
			function m:GetPivot() return cf(at.Position) end
			return m,{}
		end,
		poseWalk=function() end,
		say=function() end,
	},
	CosmeticsService={applyToPlot=function(p) p.repaints=(p.repaints or 0)+1 end},
	EconomyService={push=function() end},
	HeistService={isCarrying=function() return false end,haulChanged=function() end,
		whyCannotSnatch=function() return nil end,dropShield=function() end,
		isDodgeImmune=function() return false end},
	SocialService={recordSteal=function() end},
}
modules.PlotService={updatePile=function(plot,coins) plot.coins=coins end,
	onClaim=function(fn) callbacks.claim=fn end,onRelease=function(fn) callbacks.release=fn end,
	getAll=function() return plots end,getPlot=function() return nil end,
	yardContaining=function() return nil end,setSwapOffer=function() end,setPlaceOffer=function() end,
	setPiggySlots=function(plot) paints.slots+=1;plot.slotPaints=(plot.slotPaints or 0)+1 end,
	setPiggyBuffers=function(plot) paints.buffers+=1;plot.bufferPaints=(plot.bufferPaints or 0)+1 end,
	playCollect=function(plot,slot,fullness) table.insert(paints.collects,{plot=plot,slot=slot,fullness=fullness}) end}
local Players={GetPlayers=function() return players end,
	PlayerAdded={Connect=function() end},PlayerRemoving={Connect=function() end}}
local Workspace={GetServerTimeNow=function() return now end}
local function service(name)
	if name=="ReplicatedStorage" then return {Shared=names} end
	if name=="ServerScriptService" then return {WaitForChild=function() return names end} end
	if name=="Players" then return Players end
	if name=="RunService" then return {Heartbeat={Connect=function() end}} end
	if name=="Workspace" then return Workspace end
	return {}
end
local environment={require=function(name) return assert(modules[name],name) end,
	game={GetService=function(_,name) return service(name) end},
	Vector3={new=v,zero=v(),yAxis=v(0,1,0)},CFrame=CFrame,
	Instance={new=inst},UDim2={new=function() return {} end,fromScale=function() return {} end},
	os={time=function() return now end,clock=function() return now end},warn=function() end,
	task={spawn=function() end},math=fakeMath,workspace=Workspace,
	script={Parent=names}}
setmetatable(environment,{__index=getfenv()})

local tail=[[
currentLevel=function() return Config.RESIDENTS.minLevel end
pickOffset=function() return 0 end
rollGarden=function() return {} end
pigSize=function() return 500 end
applyLevel=function() end
drawSkin=function() return "classic" end
ResidentService.testTick=tick
ResidentService.testStep=stepResident
ResidentService.testChooseJob=chooseJob
ResidentService.testRipest=ripestPad
ResidentService.testOutCount=outCount
ResidentService.testPlaceHaul=placeHaul
ResidentService.testPadAt=padAt
ResidentService.testCarrying=carrying
return ResidentService
]]
local code,n=sources.ResidentService:gsub("return ResidentService%s*$",tail);assert(n==1)
local run=assert(loadstring(code,"ResidentService"));setfenv(run,environment);local R=run()

-- THE HAUL SERVICE, AGAINST THE SAME RESIDENT SERVICE, so a neighbour's
-- snatch below runs the real resident core rather than a spy.
modules.ResidentService=R
local runH=assert(loadstring(sources.PiggyHaulService,"PiggyHaulService"));setfenv(runH,environment);local H=runH()

local function plot(index,shop,x)
	local attrs={}
	local p={index=index,shop=shop,base={Position=v(0,0,0),Size=v(64,1,64)},cframe=cf(x or 0,0,0),
	model={SetAttribute=function(_,key,value) attrs[key]=value end,GetAttribute=function(_,key) return attrs[key] end}}
	p.attrs=attrs
	if not shop then
		p.pedestals={}
		for i,slot in ipairs(Config.PIGGY_LAWN_SLOTS) do
			p.pedestals[i]={index=i,pad={Position=v((x or 0)+slot.offset.X,0,slot.offset.Z)},
				plinth={Position=v((x or 0)+slot.offset.X,0,slot.offset.Z)}}
		end
	end
	return p
end
local home=plot(1,nil,0);table.insert(plots,home)
local shop=plot(11,"test",200);table.insert(plots,shop)
R.start()
local resident=R.get(home)
check(resident and resident.loot==0,"a real seat starts with an empty haul")
check(R.get(shop)~=nil,"a shop is seated too: it is the plot nobody can move into")
R.seat(home)
check(R.get(home)==resident,"a real seat is idempotent")
now+=3600;resident.state="out";R.testTick()
check(resident.coins==500,"a real tick fills the resident's pig to its own size")
callbacks.claim(home);home.owner={}
check(R.get(home)==nil,"claim evicts the resident")
now+=120
home.owner=nil;callbacks.release(home)
check(R.get(home)~=nil,"release seats a new one")

-- ------------------------------------------------------------
-- THE STREET FOR THE WALK TESTS
-- ------------------------------------------------------------
local N=Config.PIGGY_LAWN_SLOT_COUNT
local D=Config.DEFAULT_SKIN
local function standing(data)
	local keys={}
	for i=1,N do keys[i]=Config.piggySlots(data)[i].key end
	return keys
end
local function standingCount(data)
	local c=0
	for i=1,N do if Config.piggySlots(data)[i].key~=nil then c+=1 end end
	return c
end
local function ownedTotal(data)
	local t=0
	for _,c in pairs(data.piggies.owned or {}) do t+=c end
	return t
end
-- A real common and a real rare that are not earned elsewhere, for the swap.
local commonKey,rareKey
for key,spec in pairs(Config.SKINS) do
	if not Config.isEarnedElsewhere(spec) and spec.aura==nil then
		if spec.rarity=="common" and (commonKey==nil or key<commonKey) then commonKey=key end
		if spec.rarity=="rare" and (rareKey==nil or key<rareKey) then rareKey=key end
	end
end
check(commonKey and rareKey,"the catalogue holds a plain common and a plain rare to test the swap with")

local victim=plot(2,nil,80);table.insert(plots,victim)
local kid={UserId=5,DisplayName="Kid",Parent=true,Character=nil,attributes={}}
function kid:GetAttribute(k) return self.attributes[k] end
kid.data={incomeLevel=0,rebirths=0,cosmetics={owned={},skin=D},
	piggies={owned={[rareKey]=1},till=D,slots={{key=rareKey},{},{},{},{},{}}}}
local kidPlot=plot(3,nil,-80);kidPlot.owner=kid;table.insert(plots,kidPlot)
table.insert(players,kid)
callbacks.release(victim)
local res=R.get(home)
local other=R.get(victim)
check(res and other and R.get(kidPlot)==nil,"two neighbours and one player's lawn, and nobody is seated on the player's")
check(standingCount(res)==Config.RESIDENTS.piggyCount and standingCount(other)==Config.RESIDENTS.piggyCount,
	"each neighbour seeded piggyCount piggies through Config.addPiggy")

-- The registries `Main` fills in.
local takes,givebacks={},{}
R.registerTake(function(plot,want,who) table.insert(takes,{plot=plot,want=want,who=who});return 0 end)
R.registerGiveBack(function(plot,amount) table.insert(givebacks,{plot=plot,amount=amount}) end)
R.registerSnatch(H.residentSnatch)
R.registerPiggyReturn(H.residentReturn)

local function walk(r,done,limit)
	for i=1,limit or 600 do
		R.testStep(r,0.5)
		if done(r) then return i end
	end
	return nil
end
local function lastRoute(r) return r.route[#r.route] end

-- ------------------------------------------------------------
-- 1. THE PLINTHS FILL, ON THE PLAYER'S OWN ARITHMETIC
-- ------------------------------------------------------------
res.state="home"
local before=paints.buffers
R.testTick()
local slots=Config.piggySlots(res)
local filled,empty=0,0
for i=1,N do
	local key=slots[i].key
	if key then
		local rate=Config.getPiggyIncomeRate(Config.SKINS[key].rarity,res.incomeLevel,0)
		check(math.abs((slots[i].buffer or 0)-rate*Config.RESIDENTS.tickRate)<1e-6,
			("a standing plinth accrues one tick of getPiggyIncomeRate at the neighbour's level: slot %d"):format(i))
		filled+=1
	else
		check((slots[i].buffer or 0)==0,("an empty plinth holds nothing: slot %d"):format(i))
		empty+=1
	end
end
check(filled==Config.RESIDENTS.piggyCount and empty==N-filled,"and the count of each matches the seed")
check(paints.buffers>before,"a moved buffer repaints the pads")
for _=1,1000 do R.testTick() end
for i=1,N do
	local key=slots[i].key
	if key then
		local rarity=Config.SKINS[key].rarity
		local rate=Config.getPiggyIncomeRate(rarity,res.incomeLevel,0)
		check(math.abs(slots[i].buffer-rate*Config.piggyBufferSeconds(rarity))<1e-6,
			("the cap is the slot's own ceiling, rate times piggyBufferSeconds of the tier: slot %d"):format(i))
	end
end
before=paints.buffers
R.testTick()
check(paints.buffers==before,"a full lawn repaints nothing")
check(R.get(shop).piggies.slots[1]==nil or R.get(shop).piggies.slots[1].key==nil,"a shop accrues nothing: it has no plinths")

-- ------------------------------------------------------------
-- 2. THE COLLECT WALK
-- ------------------------------------------------------------
res.coins=100;res.state="home";res.nextRoam=now;res.nextTrip=now+1e9
local ripe=R.testRipest(res)
check(ripe~=nil and slots[ripe].key~=nil,"a full plinth is ripe")
-- Make one plinth clearly the fullest and another under the line.
local firstStanding,secondStanding
for i=1,N do if slots[i].key then if not firstStanding then firstStanding=i elseif not secondStanding then secondStanding=i end end end
local function ceilingOf(i)
	local rarity=Config.SKINS[slots[i].key].rarity
	return Config.getPiggyIncomeRate(rarity,res.incomeLevel,0)*Config.piggyBufferSeconds(rarity)
end
for i=1,N do if slots[i].key then slots[i].buffer=ceilingOf(i)*0.5 end end
check(R.testRipest(res)==nil,"half-full plinths are under the collect line, so nothing is ripe")
slots[secondStanding].buffer=ceilingOf(secondStanding)*(Config.RESIDENTS.collect and Config.RESIDENTS.collect.fullness or 0.75)
slots[firstStanding].buffer=ceilingOf(firstStanding)
check(R.testRipest(res)==firstStanding,"the ripest plinth is the fullest one at or over the line")
R.testStep(res,0.1)
check(res.state=="collecting" and res.collectSlot==firstStanding,"on the roam clock a neighbour walks to their ripest pad instead of pottering")
check(dist(lastRoute(res),R.testPadAt(home,firstStanding))<1e-6,"the route ends on that plinth's pad")
check(R.testOutCount()==0,"collecting on your own lawn is not being out")
local held=slots[firstStanding].buffer
local steps=walk(res,function(r) return r.state~="collecting" end)
check(steps~=nil,"the walk to the pad ends")
check(res.state=="roam","and a collect ends as a potter back into the garden")
check(slots[firstStanding].buffer==0,"the buffer is banked")
check(res.coins==math.min(500,100+held),"into the neighbour's own pig, clamped to its size")
local last=paints.collects[#paints.collects]
check(last and last.plot==home and last.slot==firstStanding and math.abs(last.fullness-1)<1e-6,
	"and the pad fires as it does for a player, with the fullness it banked")
check(res.nextTrip>now+1e8,"a collect does not touch the trip clock")
-- Alertable mid-collect.
res.state="collecting";res.route={R.testPadAt(home,secondStanding)}
check(R.alertNeighbour(home,kid)==true,"a neighbour walking to their own pad is home enough to answer a robbery")
res.state="home";res.chasing=nil;res.chaseUntil=nil;res.route={}

-- ------------------------------------------------------------
-- 3. WHICH JOB A TRIP IS
-- ------------------------------------------------------------
local savedSnatch=Config.RESIDENTS.snatch
Config.RESIDENTS.snatch=nil
rng=0
local job,slot=R.testChooseJob(res,victim)
check(job=="snatch" and slot~=nil and Config.piggySlots(other)[slot].key~=nil,
	"under the weight a trip to a lawn with piggies standing is a snatch of a standing plinth")
rng=0.99
job=R.testChooseJob(res,victim)
check(job=="crack","over the weight it is the crack")
rng=0.2
check(R.testChooseJob(res,kidPlot)=="snatch","0.2 is under the default player weight (0.35)")
check(R.testChooseJob(res,victim)=="crack","and over the default resident weight (0.08)")
rng=0.05
check(R.testChooseJob(res,victim)=="snatch","0.05 is under the resident weight")
rng=0
check(R.testChooseJob(res,shop)=="crack","a shop is always a crack: it has no plinths")
local savedSlots=other.piggies.slots
other.piggies.slots={{},{},{},{},{},{}}
check(R.testChooseJob(res,victim)=="crack","a lawn with nothing standing falls back to the crack")
other.piggies.slots=savedSlots
Config.RESIDENTS.snatch={playerWeight=0,residentWeight=1}
rng=0.5
check(R.testChooseJob(res,kidPlot)=="crack" and R.testChooseJob(res,victim)=="snatch",
	"the Config row, when it lands, is read in place of the fallback")
Config.RESIDENTS.snatch=savedSnatch

-- ------------------------------------------------------------
-- 4. A WHOLE SNATCH TRIP, AGAINST A NEIGHBOUR
-- ------------------------------------------------------------
Config.RESIDENTS.snatch=nil
rng=0;rngPick=2      -- pickVictim: options are the plots minus home, {shop, victim, kidPlot}; 2 is the neighbour
res.state="home";res.nextTrip=now;res.nextRoam=now+1e9
local victimBefore=standing(other)
local victimOwnedBefore=ownedTotal(other)
R.testStep(res,0.1)
check(res.state=="out" and res.job=="snatch" and res.markIndex==victim.index,"a due trip goes out as a snatch")
local vslot=res.markSlot
check(vslot~=nil and victimBefore[vslot]~=nil,"aimed at a standing plinth")
check(dist(lastRoute(res),R.testPadAt(victim,vslot))<1e-6,"and the route ends on the victim's pad rather than at the pig")
check(R.testOutCount()==1,"one neighbour is out")
check(walk(res,function(r) return r.state=="cracking" end)~=nil,"they arrive and stand at the plinth")
check(#takes==0,"a snatch never asks the coin take")
now+=Config.RESIDENTS.walk.crackSeconds
local promptsBefore=#prompts
R.testStep(res,0.1)
local taken=victimBefore[vslot]
check(res.state=="carrying" and res.haul~=nil and res.haul.key==taken and res.haul.slot==vslot,
	"after crackSeconds the piggy is in their arms, remembering the slot it came off")
check(R.testCarrying(res) and res.loot==0,"carrying, with no coins")
check(standing(other)[vslot]==nil and ownedTotal(other)==victimOwnedBefore-1,
	"the victim's plinth is empty and their count came down: the real Config.removePiggy")
check(res.lootModel~=nil and res.lootModel.key==taken,"the miniature is the piggy itself")
check(labels[#labels] and labels[#labels].Text==Config.getSkin(taken).name,"with the piggy's name over it")
check(#prompts==promptsBefore+1,"and a nab prompt on it")
check(victim.slotPaints and victim.slotPaints>0,"the victim's lawn was repainted")
check(#notes==0,"nobody is told when the victim is a neighbour")
local homeSlot=Config.firstFreePiggySlot(res)
check(homeSlot~=nil and dist(lastRoute(res),R.testPadAt(home,homeSlot))<1e-6,
	"the way home ends on the plinth it will stand on")
local resOwnedBefore=ownedTotal(res)
check(walk(res,function(r) return r.state~="carrying" end)~=nil,"they carry it home")
check(res.state=="returning" and res.haul==nil and res.lootModel==nil,"and put it down")
check(Config.piggySlots(res)[homeSlot].key==taken and ownedTotal(res)==resOwnedBefore+1,
	"on the first free plinth, through Config.addPiggy, with the count up by one")
check(walk(res,function(r) return r.state=="home" end)~=nil,"then walk back to their spot")
check(res.job==nil and res.markSlot==nil,"and the job is cleared")

-- ------------------------------------------------------------
-- 5. THE PER-VICTIM COOLDOWN
-- ------------------------------------------------------------
res.nextTrip=now;rng=0;rngPick=2
R.testStep(res,0.1)
check(res.state=="out" and res.job=="snatch","a second trip to the same lawn inside the cooldown still sets off")
walk(res,function(r) return r.state=="cracking" end)
now+=Config.RESIDENTS.walk.crackSeconds
local standingBefore=standingCount(other)
R.testStep(res,0.1)
check(res.state=="carrying" and res.haul==nil and standingCount(other)==standingBefore,
	"and comes away with nothing: PIGGY_HAUL.victimCooldown refused it")
walk(res,function(r) return r.state=="home" end)
now+=Config.PIGGY_HAUL.victimCooldown+1

-- ------------------------------------------------------------
-- 6. AGAINST A PLAYER: THE ALARM, THE SHIELD, THE NAB
-- ------------------------------------------------------------
kid.attributes[Config.PLAYER_SHIELD_ATTRIBUTE]=now+100
check(H.residentSnatch(res,kidPlot,1)==nil and kid.data.piggies.slots[1].key==rareKey,
	"a shielded player's plinth is refused at the grab")
kid.attributes[Config.PLAYER_SHIELD_ATTRIBUTE]=nil
res.nextTrip=now;rng=0;rngPick=3   -- {shop, victim, kidPlot}: 3 is the player
R.testStep(res,0.1)
check(res.state=="out" and res.job=="snatch" and res.markIndex==kidPlot.index,"a trip to the player's lawn")
walk(res,function(r) return r.state=="cracking" end)
now+=Config.RESIDENTS.walk.crackSeconds
local notesBefore=#notes
R.testStep(res,0.1)
check(res.haul~=nil and res.haul.key==rareKey and res.haul.slot==1,"the player's piggy is in their arms")
check(kid.data.piggies.slots[1].key==nil and ownedTotal(kid.data)==0,"and off the player's plinth and out of their count")
local alarm=notes[#notes]
check(#notes==notesBefore+1 and alarm.to==kid and alarm.kind=="alarm"
	and alarm.msg:find(res.name,1,true) and alarm.msg:find(Config.getSkin(rareKey).name,1,true),
	"the player is told WHO is running off with WHAT, on the alarm tone")
check(kid.repaints and kid.repaints>0,"and their lawn was repainted through applyToPlot")
check(res.model.attributes[Config.CARRY_VICTIM_ATTRIBUTE]==kid.UserId,"the carry names the player it came from")
-- Somebody nabs them.
local taker={UserId=9,DisplayName="Bystander",Parent=true}
local nab=prompts[#prompts]
walk(res,function() return true end,3)
notesBefore=#notes
nab(taker)
check(res.haul==nil and res.lootModel==nil and not R.testCarrying(res),"the nab empties their arms")
check(kid.data.piggies.slots[1].key==rareKey and ownedTotal(kid.data)==1,
	"and the piggy is back on the plinth it came off, through PiggyHaulService.residentReturn")
local thanks,told=nil,nil
for i=notesBefore+1,#notes do
	if notes[i].to==taker then thanks=notes[i] end
	if notes[i].to==kid then told=notes[i] end
end
check(thanks and thanks.kind=="good" and thanks.msg:find("Nice nab",1,true),"the nabber is thanked")
check(told and told.kind=="good" and told.msg:find("back on your lawn",1,true),"and the victim is told it is back")
check(res.state=="carrying","the neighbour walks the rest of the way home empty-handed")
check(walk(res,function(r) return r.state=="home" end)~=nil,"and gets there")
check(#givebacks==0,"a piggy nab never touches the coin give-back")

-- ------------------------------------------------------------
-- 7. A FULL LAWN SWAPS OUT ITS LOWEST-RARITY PIGGY
-- ------------------------------------------------------------
while Config.firstFreePiggySlot(res) do
	check(Config.addPiggy(res,commonKey,true)~=nil,"filling the lawn with commons")
end
check(standingCount(res)==N,"the lawn is full")
local lowest=nil
for i=1,N do
	local rank=Config.rarityRank(Config.piggyRarityAt(res,i))
	if lowest==nil or rank<Config.rarityRank(Config.piggyRarityAt(res,lowest)) then lowest=i end
end
local ownedFull=ownedTotal(res)
res.haul={key=rareKey,slot=1};res.markIndex=kidPlot.index
R.testPlaceHaul(res)
check(res.haul==nil,"placing empties the arms")
check(Config.piggySlots(res)[lowest].key==rareKey,"on a full lawn the incoming piggy takes the lowest-rarity plinth")
check(standingCount(res)==N and ownedTotal(res)==ownedFull,"six still standing and the count balanced: one out, one in")

-- ------------------------------------------------------------
-- 8. A PIGGY THAT CANNOT BE PICKED UP GOES STRAIGHT BACK
-- ------------------------------------------------------------
now+=Config.PIGGY_HAUL.victimCooldown+1
res.nextTrip=now;rng=0;rngPick=3
R.testStep(res,0.1)
walk(res,function(r) return r.state=="cracking" end)
now+=Config.RESIDENTS.walk.crackSeconds
buildFails=true
R.testStep(res,0.1)
buildFails=false
check(res.state=="carrying" and res.haul==nil,"no figure to carry it, so nothing in the arms")
check(kid.data.piggies.slots[1].key==rareKey and ownedTotal(kid.data)==1,"and the piggy is back where it was rather than gone")
walk(res,function(r) return r.state=="home" end)

-- ------------------------------------------------------------
-- 9. EVICTED WHILE CARRYING
-- ------------------------------------------------------------
now+=Config.PIGGY_HAUL.victimCooldown+1
res.nextTrip=now;rng=0;rngPick=3
R.testStep(res,0.1)
walk(res,function(r) return r.state=="cracking" end)
now+=Config.RESIDENTS.walk.crackSeconds
R.testStep(res,0.1)
check(res.haul~=nil and kid.data.piggies.slots[1].key==nil,"carrying the player's piggy again")
callbacks.claim(home);home.owner={}
check(R.get(home)==nil,"a player moving in evicts them mid-carry")
check(kid.data.piggies.slots[1].key==rareKey and ownedTotal(kid.data)==1,"and the piggy goes home rather than with them")
home.owner=nil;callbacks.release(home)

-- ------------------------------------------------------------
-- 10. THE COIN CRACK IS UNTOUCHED
-- ------------------------------------------------------------
local fresh=R.get(home)
rng=0.99;rngPick=2;fresh.state="home";fresh.nextTrip=now;fresh.nextRoam=now+1e9
victim.attrs[Config.PLOT_VAULT_ATTRIBUTE]=1000
R.testStep(fresh,0.1)
check(fresh.state=="out" and fresh.job=="crack" and fresh.markSlot==nil,"over the weight the trip is the crack")
walk(fresh,function(r) return r.state=="cracking" end)
now+=Config.RESIDENTS.walk.crackSeconds
R.testStep(fresh,0.1)
check(#takes==1 and takes[1].plot==victim and takes[1].want==math.floor(Config.RESIDENTS.walk.takeFraction*1000)
	and takes[1].who==fresh.name,"and asks the registered take for takeFraction of the published pile, by name")

print(("PASS: %d resident checks; seating, ticking, eviction and release, plinth accrual, the collect walk, the snatch branch through the haul service's resident core, the cooldown, the shield, the nab give-back, the full-lawn swap and the eviction refund."):format(checks))
