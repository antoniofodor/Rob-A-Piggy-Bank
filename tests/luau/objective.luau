-- Real FirstJob selection/render/subscription with inert Roblox instances.
-- Tests state, timing, navigation and layout bounds, not engine rendering.
local Config,sources=...
local checks=0
local function check(ok,message) assert(ok,message);checks+=1 end
local function noop() end
local function event()
 local callbacks={}
 return {Connect=function(_,fn) table.insert(callbacks,fn);return {Disconnect=noop} end,
 fire=function(_,...) for _,fn in callbacks do fn(...) end end}
end
local objects={}
local function instance(class)
 local o={ClassName=class,Activated=event(),signals={},attrs={}}
 function o:GetPropertyChangedSignal(name) self.signals[name]=self.signals[name] or event();return self.signals[name] end
 function o:GetAttributeChangedSignal(name) return self:GetPropertyChangedSignal(name) end
 function o:GetAttribute(name) return self.attrs[name] end
 function o:GetChildren()
  local children={};for _,x in objects do if x.Parent==self then table.insert(children,x) end end;return children
 end
 function o:FindFirstChild(name)
  for _,x in self:GetChildren() do if x.Name==name then return x end end
 end
 function o:Destroy() self.Parent=nil;self.destroyed=true end
 function o:IsA(name) return self.ClassName==name end
 table.insert(objects,o);return o
end
local function node(class,name,parent)
 local o=instance(class);o.Name=name;o.Parent=parent;return o
end
local function vector(x,y,z)
 return setmetatable({X=x,Y=y,Z=z},{__sub=function(a,b)
  return {Magnitude=math.sqrt((a.X-b.X)^2+(a.Y-b.Y)^2+(a.Z-b.Z)^2)}
 end})
end
local function udim(s,o) return {Scale=s,Offset=o} end
local function udim2(x,a,y,b) return {X=udim(x,a),Y=udim(y,b)} end
local names=setmetatable({},{__index=function(_,key) return key end})
local signals={Heartbeat=event(),OnClientEvent=event()}
local now,requests,opened,allowed=100,0,{},true
local me=instance("Player");me.UserId=1
local robber=instance("Player");robber.UserId=2;robber.Character=instance("Model")
local world=instance("Workspace");world.GetServerTimeNow=function() return now end
local gui=instance("ScreenGui");gui.AbsoluteSize=vector(1920,1080)
local plots=node("Folder","Plots",world)
local ownPlot=node("Model","Home",plots);ownPlot.attrs.OwnerUserId=1
local ownPig=node("Model","PiggyBank",ownPlot);local ownBody=node("BasePart","Body",ownPig)
local plot=node("Model","RobberHome",plots);plot.attrs.OwnerUserId=2;plot.attrs[Config.PLOT_VAULT_ATTRIBUTE]=100
local pig=node("Model","PiggyBank",plot);local body=node("BasePart","Body",pig);body.Position=vector(10,0,0)
local theme={corner=noop,outline=noop,title=noop,body=noop,
 coin=function(parent) return node("Frame","Coin",parent) end}
local remote={OnClientEvent=signals.OnClientEvent,FireServer=function() requests+=1 end}
local modules={Config=Config,Theme=theme,Remotes={get=function(name)
 assert(name=="RecoveryObjective");return remote
end}}
local env={game={GetService=function(_,name)
 if name=="Players" then return {GetPlayerByUserId=function(_,id) return if id==2 then robber else nil end} end
 if name=="RunService" then return {Heartbeat=signals.Heartbeat} end
 return {Shared=names}
end},require=function(name) return assert(modules[name],name) end,
 Instance={new=instance},Vector2={new=vector},UDim2={new=udim2,fromOffset=function(x,y) return udim2(0,x,0,y) end},
 Enum=setmetatable({},{__index=function() return names end}),workspace=world}
local function load(name)
 local run=assert(loadstring(sources[name],name));setfenv(run,setmetatable(env,{__index=getfenv()}));return run()
end
modules.HUDLayout=load("HUDLayout")
local UI=load("FirstJob")
local function state(rows,deadline) return {claims=rows,buybacksExpireAt=deadline or 2000} end
local function claim(key,stage,expires,cost)
 return {key=key,name=key,stage=stage,expiresAt=expires,cost=cost,robberId=2,robberName="Jamie"}
end
local row,mode,count=UI.selectObjective(nil,now)
check(row==nil and mode==nil and count==0,"no state invents no objective")
local live=claim("bronze","recover",700,45)
row,mode,count=UI.selectObjective(state({live}),100)
check(row==live and mode=="recover" and count==1,"live recovery selected")
row,mode=UI.selectObjective(state({live}),700)
check(mode=="buyback" and row.cost==45,"exact deadline flips to buy-back locally")
check(UI.selectObjective(state({live},700),700)==nil,"expired recovery plus season never offers purchase")
check(select(2,UI.selectObjective(state({live},99),100))=="recover","free recovery can outlast a season")
check(UI.selectObjective(state({claim("spare","recover",700,nil)}),700)==nil,"expired spare with no buy-back disappears")
local home=claim("home","home",nil,15)
check(select(2,UI.selectObjective(state({home},99),900))=="home","carried recovery survives both deadlines")
row,mode,count=UI.selectObjective(state({claim("later","recover",900,15),claim("earlier","recover",650,135),claim("paid","buyback",nil,45)}),100)
check(row.key=="earlier" and mode=="recover" and count==3,"earliest recovery prioritised with stack count")
row=UI.selectObjective(state({claim("z","recover",650,15),claim("a","recover",650,15)}),100)
check(row.key=="a","equal deadlines have stable key tie-break")
row=UI.selectObjective(state({live,home}),100)
check(row==home,"getting a recovered carry home is first priority")
row=UI.selectObjective(state({live,claim("chase","chase",nil,15)}),100)
check(row.key=="chase","active getaway ahead of a delivered robbery")

local icons={}
UI.start(me,gui,{skinIcon=function(parent,key)
 local icon=node("ViewportFrame",key,parent);table.insert(icons,icon);return icon
end,canShow=function() return allowed end,openCrates=function(key) table.insert(opened,key) end})
local card=gui:FindFirstChild("FirstJob")
local title,detail,amount=card:FindFirstChild("Line"),card:FindFirstChild("Detail"),card:FindFirstChild("Amount")
local mark=world:FindFirstChild("FirstJobTarget")
check(requests==1 and card and not card.Visible,"subscribe once after listener; unknown onboarding stays hidden")
UI.start(me,gui);check(requests==1,"duplicate start is ignored")
signals.Heartbeat:fire(1)
check(requests==2,"no initial snapshot retries subscription after transient startup race")
-- First delivery can happen before this module starts, so false never tears
-- down the recovery listener, card or heartbeat.
me.attrs[Config.PLAYER_FIRST_JOB_ATTRIBUTE]=false;signals.Heartbeat:fire(.25)
check(not card.Visible and card.Parent==gui,"veteran keeps dormant objective available")
signals.OnClientEvent:fire(state({claim("bronze","chase",nil,45)}))
check(card.Visible and title.Text=="RECOVER SKIN" and detail.Text:find("Jamie",1,true),"theft snapshot renders synchronously for veteran")
check(amount.Text=="CHASE" and detail.Text:find("Nab them now",1,true) and mark.Adornee==robber.Character,"chase shows actual carrier, no premature timer")
check(card.Size.X.Offset==64 and card.Size.Y.Offset==68 and not title.Visible,"recovery starts as compact task icon")
check(#icons==1 and icons[1].Name=="bronze" and icons[1].Parent.Name=="StolenSkin","task thumbnail uses exact claim key")
card.Activated:fire();check(#opened==0 and title.Visible,"recovery task expands without opening purchase")
check(#icons==1,"expansion reuses the same skin model")
signals.OnClientEvent:fire(state({live}))
check(title.Text=="RECOVER SKIN" and amount.Text=="10:00" and mark.Adornee==body,"delivered theft starts displayed countdown at robber's pig")
now=101;signals.Heartbeat:fire(1)
check(requests==2,"authoritative snapshot stops subscription retries")
check(amount.Text=="9:59" and #icons==1,"countdown uses server wall clock without rebuilding skin")
now=700;signals.Heartbeat:fire(.25)
check(title.Text=="BUY IT BACK" and amount.Text=="45 COINS" and not mark.Enabled,"clock alone flips expired recovery without new server event")
check(icons[1].destroyed,"expired free task releases thumbnail")
check(card:FindFirstChild("Coin").Visible,"the buy-back carries the coin glyph, which is the only one left")
card.Activated:fire()
check(#opened==1 and opened[1]=="bronze","buy-back opens Crates for matching key without buying")
signals.OnClientEvent:fire(state({}))
check(not card.Visible and not mark.Enabled,"returned or repurchased skin clears card and marker")
card.Activated:fire();check(#opened==1,"stale cleared card cannot navigate")
now=100
signals.OnClientEvent:fire(state({live,claim("goldleaf","recover",800,45)}))
check(detail.Text:find("+1 more",1,true)~=nil and amount.Text=="10:00","stack count displayed without replacing oldest timer")
signals.OnClientEvent:fire(state({claim("goldleaf","recover",800,45)}))
check(amount.Text=="11:40" and not detail.Text:find("more",1,true),"resolving first claim reveals remaining one")
signals.OnClientEvent:fire(state({home}))
check(title.Text=="GET IT HOME" and mark.Adornee==ownBody,"recovered skin points home")
allowed=false;signals.Heartbeat:fire(.25)
check(not card.Visible and not mark.Enabled,"shop/bag overlay hides objective and highlight")
allowed=true;signals.Heartbeat:fire(.25)
check(card.Visible and mark.Enabled,"closing overlay restores current objective")
-- Onboarding is the fallback, not a competing card or a permanent teardown.
me.Character=instance("Model");local root=node("BasePart","HumanoidRootPart",me.Character);root.Position=vector(0,0,0)
me.attrs[Config.PLAYER_FIRST_JOB_ATTRIBUTE]=true
signals.OnClientEvent:fire(state({}))
check(card.Visible and title.Text=="GO AND ROB A PIGGY BANK" and mark.Adornee==body,"no claim restores unfinished first job and nearest pig")
signals.OnClientEvent:fire(state({live}))
check(title.Text=="RECOVER SKIN","recovery overrides unfinished onboarding")
me.attrs[Config.PLAYER_FIRST_JOB_ATTRIBUTE]=false
signals.OnClientEvent:fire(state({}))
check(not card.Visible,"completed onboarding stays retired after recovery")
signals.OnClientEvent:fire(state({claim("bronze","buyback",nil,45)},101))
now=101;card.Activated:fire();signals.Heartbeat:fire(.25)
check(#opened==1 and not card.Visible,"season boundary blocks stale click and hides offer locally")
-- Bounds in representative safe-area viewports, including existing phone sizes.
for _,size in {{1920,1080},{1180,800},{750,361},{705,338},{390,844}} do
 gui.AbsoluteSize=vector(size[1],size[2]);gui:GetPropertyChangedSignal("AbsoluteSize"):fire()
 local left=card.Position.X.Offset-card.Size.X.Offset/2
 local right=left+card.Size.X.Offset
 check(left>=0 and right<=size[1] and card.Size.Y.Offset==44,"objective stays inside viewport "..size[1])
 if size[1]>size[2] then
  local m=modules.HUDLayout.metrics(gui.AbsoluteSize)
  check(right<=size[1]-m.bankWidth-22,"objective clears the piggy bank column "..size[1])
 end
end
check(detail.TextTruncate=="AtEnd" and title.TextTruncate=="AtEnd","long player/skin names truncate inside card")
print(("PASS: %d objective checks; selection, stacks, client clock, onboarding lifecycle, markers, navigation and viewport bounds. No player saves or visual-rendering claim."):format(checks))
