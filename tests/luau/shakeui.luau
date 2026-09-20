-- Real Shake panel/input handlers with deterministic GUI geometry and signals.
local Config,source=...
local checks,now=0,100
local function check(ok,msg) assert(ok,msg);checks+=1 end
local function signal()
 local callbacks={}
 return {Connect=function(_,fn) local c={on=true};function c:Disconnect() self.on=false end;table.insert(callbacks,{fn=fn,c=c});return c end,
 Fire=function(_,...) for _,item in table.clone(callbacks) do if item.c.on then item.fn(...) end end end}
end
local vectorMeta={}
local function vector(x,y) return setmetatable({X=x or 0,Y=y or 0},vectorMeta) end
vectorMeta.__sub=function(a,b) return vector(a.X-b.X,a.Y-b.Y) end
local function dim2(xs,xo,ys,yo) return {X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}} end
local UDim2={new=dim2,fromOffset=function(x,y) return dim2(0,x,0,y) end,fromScale=function(x,y) return dim2(x,0,y,0) end}
local methods={};local mt={}
mt.__index=function(i,k)
 if k=="AbsoluteSize" then
  if not i.Parent then return vector(750,361) end
  local size=i.Size or UDim2.fromOffset(0,0);local parent=i.Parent.AbsoluteSize
  return vector(parent.X*size.X.Scale+size.X.Offset,parent.Y*size.Y.Scale+size.Y.Offset)
 elseif k=="AbsolutePosition" then
  if not i.Parent then return vector(0,0) end
  local parent,size=i.Parent.AbsolutePosition,i.Parent.AbsoluteSize
  local pos=i.Position or UDim2.fromOffset(0,0);local own=i.AbsoluteSize;local anchor=i.AnchorPoint or vector()
  return vector(parent.X+size.X*pos.X.Scale+pos.X.Offset-own.X*anchor.X,parent.Y+size.Y*pos.Y.Scale+pos.Y.Offset-own.Y*anchor.Y)
 end
 return methods[k] or i.props[k]
end
mt.__newindex=function(i,k,value)
 if k=="Parent" then
  local old=i.props.Parent
  if old then local n=table.find(old.children,i);if n then table.remove(old.children,n) end end
  i.props.Parent=value
  if value then table.insert(value.children,i) end
 else i.props[k]=value end
 if i.property[k] then i.property[k]:Fire() end
end
local function instance(kind)
 local i=setmetatable({props={Name=kind,ClassName=kind,ZIndex=1},children={},property={}},mt)
 for _,key in {"InputBegan","Activated","ChildAdded","ChildRemoved","DescendantAdded"} do i[key]=signal() end
 return i
end
function methods:GetAttribute(key) return self.attrs and self.attrs[key] end
function methods:GetAttributeChangedSignal(key)
 self.attrSignals=self.attrSignals or {};self.attrSignals[key]=self.attrSignals[key] or signal();return self.attrSignals[key]
end
function methods:SetAttribute(key,value)
 self.attrs=self.attrs or {};self.attrs[key]=value;self:GetAttributeChangedSignal(key):Fire()
end
function methods:GetPropertyChangedSignal(k) self.property[k]=self.property[k] or signal();return self.property[k] end
function methods:FindFirstChild(name) for _,c in self.children do if c.Name==name then return c end end end
function methods:GetChildren() return table.clone(self.children) end
function methods:GetDescendants() local out={};for _,c in self.children do table.insert(out,c);for _,d in c:GetDescendants() do table.insert(out,d) end end;return out end
function methods:IsA(kind) return kind==self.ClassName or (kind=="GuiObject" and (self.ClassName=="Frame" or self.ClassName=="TextLabel" or self.ClassName=="TextButton")) end
function methods:Destroy() self.Parent=nil;self.destroyed=true;for _,c in self:GetChildren() do c:Destroy() end end
local gui=instance("ScreenGui")
local workspace=instance("Workspace");workspace.GetServerTimeNow=function() return now end
local input={InputChanged=signal(),InputEnded=signal(),InputBegan=signal(),GetLastInputType=function() return "Touch" end}
local render=signal();local events,requests={},{ }
local Remotes={get=function(name)
 if not events[name] then events[name]={OnClientEvent=signal(),FireServer=function(_,...) table.insert(requests,{name=name,args={...}}) end} end
 return events[name]
end}
local theme={card=function() end,corner=function() end,outline=function() end,acorn=function(parent)
 local f=instance("Frame");f.Parent=parent;return f
end}
local services={Players={LocalPlayer={UserId=123}},RunService={RenderStepped=render},UserInputService=input,GuiService={}}
local names=setmetatable({}, {__index=function(_,k) return k end})
local enum=setmetatable({}, {__index=function(_,k) return setmetatable({}, {__index=function(_,v) return v end}) end})
local environment={script={Parent=names},require=function(name) return if name=="Config" then Config elseif name=="Theme" then theme elseif name=="TouchOrigin" then {beganElsewhere=function() return false end} else Remotes end,
 game={GetService=function(_,name) return services[name] end},workspace=workspace,Instance={new=instance},UDim2=UDim2,
 Vector2={new=vector},Enum=enum,Color3={fromRGB=function(...) return {...} end}}
local run=assert(loadstring(source,"Shake"));setfenv(run,setmetatable(environment,{__index=getfenv()}));local UI=run();UI.start(gui)
local overlay=assert(gui:FindFirstChild("ShakeOverlay"));local panel=assert(overlay:FindFirstChild("ShakePanel"))
local field=assert(panel:FindFirstChild("LooseAcorns"));local basket=assert(panel:FindFirstChild("CatchBasket"))
local function at(node) local p,s=node.AbsolutePosition,node.AbsoluteSize;return vector(p.X+s.X/2,p.Y+s.Y/2) end
local function finger(kind,node,key) return {UserInputType=kind,Position=at(node),KeyCode=key} end
local function message(id,count)
 events.ShakeState.OnClientEvent:Fire({id=id,count=count,caught=0,startedAt=now,endsAt=now+5,victim="Resident"})
end
local function catches() local n=0;for _,r in requests do if r.name=="ShakeCatch" then n+=1 end end;return n end
for _,viewport in {{750,361},{546,320},{320,600},{1438,848}} do
 overlay.Size=UDim2.fromOffset(viewport[1],viewport[2]);overlay:GetPropertyChangedSignal("AbsoluteSize"):Fire()
 local spec=UI.layout(viewport[1],viewport[2])
 check(panel.AbsoluteSize.X==spec.width and panel.AbsoluteSize.Y==spec.height,"responsive panel respects safe viewport")
 check(spec.acornSize>=48 and basket.AbsoluteSize.X>=140 and basket.AbsoluteSize.Y>=48,"phone catch targets remain finger-sized")
 message(viewport[1],8);now+=1.6;render:Fire()
 for i=1,8 do
  local button=field:FindFirstChild("Acorn"..i);local p,s=button.AbsolutePosition,button.AbsoluteSize
  check(p.X>=field.AbsolutePosition.X and p.X+s.X<=field.AbsolutePosition.X+field.AbsoluteSize.X,"eight Acorns stay within panel width")
 end
 events.ShakeState.OnClientEvent:Fire({ended=true})
end
-- Mouse: wrong drop stays catchable; proper drag sends only ID and index.
message(2000,2);now+=.2;render:Fire()
local one=field:FindFirstChild("Acorn1");local two=field:FindFirstChild("Acorn2")
local mouse=finger("MouseButton1",one)
one.InputBegan:Fire(mouse)
input.InputEnded:Fire({UserInputType="MouseButton1",Position=vector(-100,-100)})
check(catches()==0 and not one.destroyed,"dropping outside basket does not claim a catch")
one.InputBegan:Fire(mouse)
input.InputChanged:Fire({UserInputType="MouseMovement",Position=at(basket)})
input.InputEnded:Fire({UserInputType="MouseButton1",Position=at(basket)})
check(catches()==1 and requests[#requests].args[1]==2000 and requests[#requests].args[2]==1,"mouse drag reports only scheduled attempt/index")
check(not one.Visible,"submitted Acorn hides pending server acknowledgement")
one.InputBegan:Fire(mouse);input.InputEnded:Fire({UserInputType="MouseButton1",Position=at(basket)})
check(catches()==1,"same icon cannot submit twice")
-- Touch: another finger cannot move or complete the active drag.
now+=1.4;render:Fire()
local touch=finger("Touch",two);two.InputBegan:Fire(touch)
local stranger=finger("Touch",basket)
input.InputChanged:Fire(stranger);input.InputEnded:Fire(stranger)
check(catches()==1,"unrelated touch cannot finish another finger's drag")
touch.Position=at(basket);input.InputChanged:Fire(touch);input.InputEnded:Fire(touch)
check(catches()==2 and requests[#requests].args[2]==2,"owning touch drags second Acorn into basket")
-- Expired drops, stop and delayed packets never resurrect a cancelled panel.
message(2001,1);now+=.2;render:Fire()
local expiring=field:FindFirstChild("Acorn1");local t=finger("Touch",expiring);expiring.InputBegan:Fire(t)
now+=5;render:Fire();t.Position=at(basket);input.InputEnded:Fire(t)
check(catches()==2 and not expiring.Visible,"holding a drop cannot extend its lifetime")
panel:FindFirstChild("Run").Activated:Fire()
check(not panel.Visible and requests[#requests].name=="ShakeStop" and requests[#requests].args[1]==2001,"Run closes panel and sends matching stop")
events.ShakeState.OnClientEvent:Fire({id=2001,count=1,caught=0,startedAt=now,endsAt=now+5,victim="late"})
check(not panel.Visible,"late acknowledgement cannot reopen locally stopped attempt")
message(2002,1);now+=.2;render:Fire()
local controller=field:FindFirstChild("Acorn1");controller.Activated:Fire({KeyCode="ButtonA"})
check(catches()==3,"controller can catch selected Acorn")
events.ShakeState.OnClientEvent:Fire({ended=true,id=2001})
check(panel.Visible,"stale end cannot close a newer attempt")
events.ShakeState.OnClientEvent:Fire({ended=true,id=2002})
check(not panel.Visible and #field:GetChildren()==0,"server end cleans all drop targets")
-- Another occupant's tree is offered only while an acorn-theft event is live
-- (step 2.6); the crate carries no raid prompt at all.
local plots=instance("Folder");plots.Name="Plots";plots.Parent=workspace;workspace.ChildAdded:Fire(plots)
local plot=instance("Model");plot.Name="ResidentFixture"
plot:SetAttribute(Config.PLOT_RESIDENT_ATTRIBUTE,"Resident")
plot:SetAttribute(Config.PLOT_TREE_ACORNS_ATTRIBUTE,2);plot:SetAttribute(Config.PLOT_ACORNS_ATTRIBUTE,2)
local tree=instance("Model");tree.Name="AcornOak";tree.Parent=plot
local trunk=instance("Part");trunk.Name="TrunkCollider";trunk.Parent=tree
local shakePrompt=instance("ProximityPrompt");shakePrompt.Name="ShakePrompt";shakePrompt.Parent=trunk
local storage=instance("Model");storage.Name="AcornStorage";storage.Parent=plot
local body=instance("Part");body.Name="Storage";body.Parent=storage
plot.Parent=plots;plots.ChildAdded:Fire(plot)
check(shakePrompt:GetAttribute(Config.PROMPT_AMOUNT_ATTRIBUTE)=="2 RIPE","tree prompt shows the ripe count, never a resting timer")
check(not shakePrompt.Enabled,"a resident's tree is not offered outside the Harvest Moon")
events.EventState.OnClientEvent:Fire({phase="live",acornTheft=true})
check(shakePrompt.Enabled,"an acorn-theft event offers it")
events.EventState.OnClientEvent:Fire({phase="quiet",acornTheft=false})
check(not shakePrompt.Enabled,"and the end of the event withdraws it")
events.EventState.OnClientEvent:Fire("garbage")
check(not shakePrompt.Enabled,"a malformed event payload reads as closed")
plot:SetAttribute("OwnerUserId",123)
check(shakePrompt.Enabled and shakePrompt:GetAttribute(Config.PROMPT_AMOUNT_ATTRIBUTE)=="2 RIPE","own tree is always harvestable")
-- Private player deadlines never leak by plot/owner.
now=math.ceil(now)
events.EventState.OnClientEvent:Fire({acornTheft=true})
plot:SetAttribute("OwnerUserId",456)
events.AcornCooldown.OnClientEvent:Fire({[456]=now+60})
check(shakePrompt:GetAttribute(Config.PROMPT_COOLDOWN_ATTRIBUTE)=="Steal ready in 1:00","tree receives private player cooldown")
now+=6;render:Fire()
check(shakePrompt:GetAttribute(Config.PROMPT_COOLDOWN_ATTRIBUTE)=="Steal ready in 0:54","nearby cue ticks without server packets")
plot:SetAttribute("OwnerUserId",789)
check(shakePrompt:GetAttribute(Config.PROMPT_COOLDOWN_ATTRIBUTE)==nil,"replacement occupant never inherits previous player's deadline")
plot:SetAttribute("OwnerUserId",123)
check(shakePrompt:GetAttribute(Config.PROMPT_COOLDOWN_ATTRIBUTE)==nil and shakePrompt.Enabled,"own tree remains harvestable")
plot:SetAttribute("OwnerUserId",456)
now+=54;render:Fire()
check(shakePrompt:GetAttribute(Config.PROMPT_COOLDOWN_ATTRIBUTE)==nil,"cue retires at exact boundary")
check(shakePrompt:GetAttribute(Config.PROMPT_AMOUNT_ATTRIBUTE)=="2 RIPE","normal nearby prompt recovers after cooldown")
events.AcornCooldown.OnClientEvent:Fire({})
check(shakePrompt:GetAttribute(Config.PROMPT_COOLDOWN_ATTRIBUTE)==nil,"empty private snapshot clears stale deadlines")
print(("PASS: %d shake UI checks; four viewport sizes, mouse/touch ownership, catch lifetime, controller and cancellation."):format(checks))
