-- Execute the real client renderer with a synchronous Instance/signal double.
-- Checks replication ordering, display bounds, animation lifetime and cleanup.
local Config,source=...
local checks=0
local function check(ok,message) assert(ok,message);checks+=1 end
local function signal()
 local listeners={}
 return {Connect=function(_,fn)
  local c={Connected=true};function c:Disconnect() self.Connected=false end
  table.insert(listeners,{fn=fn,c=c});return c
 end,Fire=function(_,...) for _,l in table.clone(listeners) do if l.c.Connected then l.fn(...) end end end,
 Count=function() local n=0;for _,l in listeners do if l.c.Connected then n+=1 end end;return n end}
end
local vm={};vm.__index=vm
local function vector(x,y,z) return setmetatable({X=x or 0,Y=y or 0,Z=z or 0},vm) end
vm.__mul=function(v,n) return vector(v.X*n,v.Y*n,v.Z*n) end
vm.__add=function(a,b) return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
function vm:Lerp(b,t) return vector(self.X+(b.X-self.X)*t,self.Y+(b.Y-self.Y)*t,self.Z+(b.Z-self.Z)*t) end
local fm={}
local function frame(v,yaw) return setmetatable({Position=v,yaw=yaw or 0},fm) end
fm.__index=function(f,k) if k=="Rotation" then return frame(vector(),f.yaw) end end
fm.__mul=function(a,b)
 local c,s=math.cos(a.yaw),math.sin(a.yaw);local p=b.Position
 return frame(a.Position+vector(c*p.X+s*p.Z,p.Y,-s*p.X+c*p.Z),a.yaw+b.yaw)
end
local cf={new=function(x,y,z) return frame(if type(x)=="table" then x else vector(x,y,z)) end,
 Angles=function(_,y) return frame(vector(),y) end}
for _,entry in Config.ACORN_BASKET_MESH.parts do local o=entry.offset;entry.offset=vector(o.X,o.Y,o.Z) end
local methods={};local im={}
local function propagate(parent,event,item)
 while parent do parent[event]:Fire(item);parent=parent.Parent end
end
im.__index=function(i,k) return methods[k] or i.props[k] end
im.__newindex=function(i,k,v)
 if k~="Parent" then i.props[k]=v;return end
 local old=i.props.Parent;if old==v then return end
 if old then
  propagate(old,"DescendantRemoving",i)
  local at=table.find(old.children,i);if at then table.remove(old.children,at) end
  i.props.Parent=nil;old.ChildRemoved:Fire(i)
 end
 i.props.Parent=v
 if v then table.insert(v.children,i);v.ChildAdded:Fire(i);propagate(v,"DescendantAdded",i) end
end
local created={}
local function instance(kind)
 local i=setmetatable({props={ClassName=kind,Name=kind},children={},attrs={},signals={}},im)
 for _,key in {"ChildAdded","ChildRemoved","DescendantAdded","DescendantRemoving"} do i[key]=signal() end
 table.insert(created,i);return i
end
function methods:IsA(kind) return self.ClassName==kind or (kind=="BasePart" and self.ClassName=="Part") end
function methods:GetChildren() return table.clone(self.children) end
function methods:FindFirstChild(name) for _,c in self.children do if c.Name==name then return c end end end
function methods:GetAttribute(key) return self.attrs[key] end
function methods:GetAttributeChangedSignal(key) self.signals[key]=self.signals[key] or signal();return self.signals[key] end
function methods:SetAttribute(key,v) if self.attrs[key]~=v then self.attrs[key]=v;self:GetAttributeChangedSignal(key):Fire() end end
function methods:Destroy()
 if self.destroyed then return end
 self.destroyed=true
 self.Parent=nil
 for _,c in self:GetChildren() do c:Destroy() end
end
function methods:PivotTo(cf) self.WorldPivot=cf end
local workspace=instance("Workspace")
local stepped,grown=signal(),signal()
local now=0
workspace.GetServerTimeNow=function() return now end
local o=Config.ACORNS.treeCollisionOffset;Config.ACORNS.treeCollisionOffset=vector(o.X,o.Y,o.Z)
local enum=setmetatable({}, {__index=function(_,key) return setmetatable({}, {__index=function(_,v) return v end}) end})
local env={workspace=workspace,game={GetService=function(_,key)
 if key=="ReplicatedStorage" then return {DescendantAdded=signal()} end
 assert(key=="RunService");return {IsClient=function() return true end,RenderStepped=stepped}
end},script={Parent={Config="Config",Remotes="Remotes",AcornModel="AcornModel"}},require=function(key)
 if key=="Config" then return Config end
 if key=="AcornModel" then return {build=function() return nil end,templateName="AcornMeshTemplate"} end
 return {get=function(name) assert(name=="AcornGrown");return {OnClientEvent=grown} end}
end,Instance={new=instance},Vector3={new=vector},CFrame=cf,Enum=enum,
 Color3={fromRGB=function(...) return {...} end},UDim2={fromOffset=function(...) return {...} end,fromScale=function(...) return {...} end},
 UDim={new=function(...) return {...} end},os={clock=function() return now end}}
local run=assert(loadstring(source,"AcornFill"));setfenv(run,setmetatable(env,{__index=getfenv()}))
local Fill=run();Fill.start();Fill.start()
check(stepped:Count()==1,"start is idempotent")
local plots=instance("Folder");plots.Name="Plots";plots.Parent=workspace
local plot=instance("Model");plot.Name="Plot1";plot.Parent=plots
plot:SetAttribute(Config.PLOT_ACORNS_ATTRIBUTE,8)
local storage=instance("Model");storage.Name="AcornStorage";storage.Parent=plot
local body=instance("Part");body.Name="Storage"
local base=cf.new(90,.5,40)*cf.Angles(0,math.pi,0)
body.CFrame=base*cf.new(0,.125,0);body.Parent=storage
local function fill() return assert(storage:FindFirstChild("AcornFill")) end
local function count(folder) local n=0;for _,c in folder:GetChildren() do if c.Name=="Acorn" then n+=1 end end;return n end
local function label() return fill():FindFirstChild("StoredCount"):FindFirstChild("TextLabel").Text end
check(count(fill())==8 and label()=="8 Acorns","late storage/body draws eight and exact count")
check(#storage:GetChildren()==2,"joining does not spawn loose acorns")
local first=fill():GetChildren()[1]
check(math.abs(first.WorldPivot.Position.X-(90+.43*2.1))<.00001,"contents use replicated storage orientation on far row")
for _,p in created do if p.Name=="Nut" or p.Name=="Cap" or p.Name=="Stem" then
 check(p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch,"fill cannot affect physics or targeting")
end end
plot:SetAttribute(Config.PLOT_ACORNS_ATTRIBUTE,200)
check(count(fill())==8 and label()=="200 Acorns" and not fill():FindFirstChild("Packed"),"large balance stays exact and never says PACKED")
plot:SetAttribute(Config.PLOT_ACORNS_ATTRIBUTE,0)
check(count(fill())==0 and label()=="0 Acorns","spending clears pile but retains exact count")
plot:SetAttribute(Config.PLOT_ACORNS_ATTRIBUTE,3)
check(count(fill())==3,"partial wallet draws exact contents")
local tree=instance("Model");tree.Name="AcornOak";tree.Parent=plot
local trunk=instance("Part");trunk.Name="TrunkCollider";trunk.CFrame=base*cf.new(Config.ACORNS.treeCollisionOffset);trunk.Parent=tree
plot:SetAttribute(Config.PLOT_TREE_ACORNS_ATTRIBUTE,8)
check(count(tree:FindFirstChild("RipeAcorns"))==8 and count(fill())==3,"ripe tree is independent of storage")
plot:SetAttribute(Config.PLOT_TREE_ACORNS_ATTRIBUTE,0)
plot:SetAttribute(Config.PLOT_GROUND_ACORNS_ATTRIBUTE,8)
plot:SetAttribute(Config.PLOT_SHAKE_ATTRIBUTE,now)
check(count(tree:FindFirstChild("RipeAcorns"))==0 and count(tree:FindFirstChild("GroundAcorns"))==8,"shake visibly moves supply to ground")
local flight=tree:FindFirstChild("GroundAcorns"):GetChildren()[1]
stepped:Fire();local high=flight.WorldPivot.Position.Y
now=.2;stepped:Fire()
check(flight.WorldPivot.Position.Y<high and flight.WorldPivot.Position.Y>.78,"released Acorns fall onto ground")
now=.5;stepped:Fire()
check(math.abs(flight.WorldPivot.Position.Y-.78)<.00001 and not flight.destroyed,"landed Acorns stay visible after falling")
plot:SetAttribute(Config.PLOT_GROUND_ACORNS_ATTRIBUTE,7)
check(count(tree:FindFirstChild("GroundAcorns"))==7 and count(fill())==3,"one catch removes ground item without banking")
plot:SetAttribute(Config.PLOT_GROUND_ACORNS_ATTRIBUTE,0)
check(count(tree:FindFirstChild("GroundAcorns"))==0,"ground expiry clears loose display")
local oldFill=fill();body.Parent=nil
check(oldFill.destroyed and not storage:FindFirstChild("AcornFill"),"body streaming out clears fill")
check(tree:FindFirstChild("RipeAcorns")~=nil,"storage streaming out retains tree display")
body.Parent=storage
check(count(fill())==3,"body streaming back restores fill")
plot.Parent=nil
check(not storage:FindFirstChild("AcornFill") and not tree:FindFirstChild("GroundAcorns"),"plot removal cleans contents")
check(plot:GetAttributeChangedSignal(Config.PLOT_ACORNS_ATTRIBUTE):Count()==0,"plot removal disconnects attribute watcher")
plot.Parent=plots
check(count(fill())==3,"plot re-entry renders once")
plots.Parent=nil
check(not storage:FindFirstChild("AcornFill") and plots.ChildAdded:Count()==0,"folder replacement cleans watchers")
plots.Parent=workspace
check(count(fill())==3,"replacement folder is watched")
local shop=instance("Model");shop.Parent=plots;shop:SetAttribute(Config.PLOT_ACORNS_ATTRIBUTE,20)
check(#shop:GetChildren()==0,"shops without props receive no display")
print(("PASS: %d fill checks; exact storage counts, separate tree/ground, falling, replication and cleanup."):format(checks))
