-- Real AcornTree builder + Config + save reconciliation. No mesh network or saves.
local Config,sources=...
local checks=0
local function check(ok,message) assert(ok,message);checks+=1 end
local function near(a,b) return math.abs(a-b)<0.00001 end
local function copy(v)
 if type(v)~="table" then return v end
 local out={};for k,x in v do out[k]=copy(x) end;return out
end
-- Minimal vector/frame math for actual placement at 0 and 180 degree plot yaw.
local vectorMeta={}
local function vector(x,y,z) return setmetatable({X=x,Y=y,Z=z},vectorMeta) end
vectorMeta.__mul=function(v,n) return vector(v.X*n,v.Y*n,v.Z*n) end
vectorMeta.__add=function(a,b) return vector(a.X+b.X,a.Y+b.Y,a.Z+b.Z) end
local frameMeta={}
local function frame(v,yaw) return setmetatable({Position=v,yaw=yaw or 0},frameMeta) end
frameMeta.__mul=function(a,b)
 local p=b.Position;local c,s=math.cos(a.yaw),math.sin(a.yaw)
 return frame(a.Position+vector(c*p.X+s*p.Z,p.Y,-s*p.X+c*p.Z),a.yaw+b.yaw)
end
for _,entry in Config.ACORN_OAK_MESH.parts do
 for _,key in {"size","offset"} do local v=entry[key];entry[key]=vector(v.X,v.Y,v.Z) end
end
local off=Config.ACORNS.treeOffset;Config.ACORNS.treeOffset=vector(off.X,off.Y,off.Z)
for _,key in {"treeCollisionSize","treeCollisionOffset"} do
 local v=Config.ACORNS[key];Config.ACORNS[key]=vector(v.X,v.Y,v.Z)
end
local calls,warnings,destroyed=0,0,0
local failAt
local function part()
 return {Destroy=function(self) self.destroyed=true;destroyed+=1 end,
 Clone=function(self) local out=table.clone(self);return out end}
end
local insert={CreateMeshPartAsync=function(_,id)
 calls+=1
 if calls==failAt then error("isolated mesh load failure") end
 local p=part();p.MeshId=id;return p
end}
local env={script={Parent={Config="Config"}},require=function() return Config end,
 game={GetService=function(_,name) assert(name=="InsertService");return insert end},
 Instance={new=function(kind) assert(kind=="Model" or kind=="Part");return {} end},
 CFrame={new=function(v) return frame(v) end},Color3={new=function(r,g,b) return {r,g,b} end},
 Enum={CollisionFidelity={Box="Box"},RenderFidelity={Precise="Precise"},Material={Plastic="Plastic"}},
 warn=function() warnings+=1 end}
local function module()
 local run=assert(loadstring(sources.AcornTree,"AcornTree"));setfenv(run,setmetatable(env,{__index=getfenv()}));return run()
end
local Tree=module()
Tree.prewarm();Tree.prewarm()
check(calls==2 and warnings==0,"load each generated mesh once")
local parent={}
for _,yaw in {0,math.pi} do
 local plot=frame(vector(80,0,100),yaw)
 local base=plot*frame(Config.ACORNS.treeOffset+vector(0,Config.PLOT_SIZE.Y/2,0))
 local tree=assert(Tree.build(parent,base))
 check(tree.model.Parent==parent and tree.model.Name=="AcornOak","tree belongs to residential plot")
 check(tree.trunk.Parent==tree.model and tree.canopy.Parent==tree.model,"whole two-part tree is reconstructed")
 check(tree.trunk.MeshId=="rbxassetid://86596500351307" and tree.canopy.MeshId=="rbxassetid://126109660219617","uses imported compact Blender oak")
 check(tree.trunk.TextureID=="rbxassetid://122626758016508" and tree.canopy.TextureID=="rbxassetid://122626758016508","both baked textures retained")
 check(near(tree.canopy.Size.X,8.5),"finished asset is not shrunk a second time")
 check(near(tree.trunk.CFrame.Position.Y-tree.trunk.Size.Y/2,Config.PLOT_SIZE.Y/2),"trunk sits on lawn surface")
 local direction=if yaw==0 then 1 else -1
 check(near(tree.collider.CFrame.Position.X,80-25*direction) and near(tree.collider.CFrame.Position.Z,100+16*direction),"far-row tree follows plot facing")
 check(not tree.trunk.CanCollide and not tree.trunk.CanQuery and not tree.canopy.CanCollide and not tree.canopy.CanQuery,"visual branches cannot create invisible obstacles")
 check(tree.collider.CanCollide and tree.collider.CanQuery and tree.collider.Parent==tree.model,"lower trunk owns physical/query collision")
 check(near(tree.collider.CFrame.Position.Y-tree.collider.Size.Y/2,Config.PLOT_SIZE.Y/2) and tree.collider.Size.X<=1.3 and tree.collider.Size.Z<=1.3,"trunk collider sits on the lawn and leaves branch space open")
 check(tree.collider.Anchored and not tree.collider.CanTouch and tree.collider.Transparency==1 and not tree.collider.CastShadow,"collider has no visual or touch side effects")
 check(tree.trunk.Color[1]==1 and tree.canopy.Color[1]==1,"importer grey tint does not darken the palette")
 check(near(tree.canopy.CFrame.Position.X-tree.trunk.CFrame.Position.X,.01711273*direction) and near(tree.canopy.CFrame.Position.Z-tree.trunk.CFrame.Position.Z,.55610656*direction),"imported mesh offsets retain assembly on both rows")
 check(tree.trunk.Anchored and tree.canopy.Anchored and not tree.trunk.CanTouch and not tree.canopy.CanTouch,"tree is anchored without touch events")
 check(tree.model.WorldPivot==base,"tree pivot is its ground contact for future shaking")
end
check(calls==2,"plot clones never reload meshes")
local crown=Config.ACORN_OAK_MESH.parts[2]
local left=off.X+(crown.offset.X-crown.size.X/2)*Config.ACORNS.treeScale
local front=off.Z+(crown.offset.Z+crown.size.Z/2)*Config.ACORNS.treeScale
check(Config.PLOT_HALF_WIDTH+left>4.3,"compact canopy clears side fence line by over 4.3 studs")
check(Config.PLOT_FRONT_LINE-front>6.5,"imported canopy clears front fence line by over 6.5 studs")
check(off.X+(crown.offset.X+crown.size.X/2)*Config.ACORNS.treeScale < -19,"canopy stays outside central piggy sightline")
local oldTexture=crown.texture;crown.texture=""
check(Config.acornOakMesh()==nil,"missing texture refuses untextured substitute")
local Missing=module();check(Missing.build(parent,frame(vector(0,0,0)))==nil and calls==2 and warnings==1,"missing asset warns without requesting meshes")
crown.texture=oldTexture
failAt=calls+2
local Broken=module();Broken.prewarm();Broken.prewarm()
check(destroyed==1 and warnings==2,"partial mesh failure cleans up loaded part and warns once")
check(Broken.build(parent,frame(vector(0,0,0)))==nil and calls==4,"failed mesh pair cannot produce a half tree or repeated requests")
-- The existing reconciliation rule shelves retired slots, preserving ownership.
local dataSource,n=sources.DataService:gsub("return DataService%s*$","return {defaults=defaultData,reconcile=reconcile}");assert(n==1)
local run=assert(loadstring(dataSource,"DataService"))
setfenv(run,setmetatable({game={JobId="oak-tests",GetService=function(_,name)
 return if name=="ReplicatedStorage" then {Shared={Config="Config"}} else {}
end},require=function() return Config end},{__index=getfenv()}))
local Data=run();local data=Data.defaults()
local item
for key,spec in Config.DECOR_ITEMS do if spec.zone=="lawn" then item=key;break end end
assert(item,"fixture requires existing lawn ornament")
data.decor.owned[item]=true;data.decor.placed.lawnI=item;data.decor.placed.lawnA=item;data.coins=321;data.loot=19
local reconciled=Data.reconcile(copy(data))
check(reconciled.decor.placed.lawnI==nil and reconciled.decor.owned[item]==true,"retired slot shelves ornament without taking ownership")
check(reconciled.decor.placed.lawnA==item and reconciled.coins==321 and reconciled.loot==19,"other placements and balances preserved")
check(Data.reconcile(copy(reconciled)).decor.owned[item]==true,"rejoin never deletes shelved ornament")
local lawns=0
for _,slot in Config.DECOR_SLOTS do
 check(slot.id~=Config.ACORNS.slot,"reserved tree slot cannot accept decor")
 if slot.zone=="lawn" then lawns+=1 end
end
check(lawns==8,"eight usable lawn ornament slots remain")
-- Actual plot wiring: only the residential builder owns a tree.
local plot=sources.PlotService
local residential=assert(plot:find("local function buildPlot(",1,true))
local shops=assert(plot:find("local function buildShopPlot(",1,true))
check(plot:sub(residential,shops-1):find("AcornTree.build(model, cf * CFrame.new(",1,true)~=nil,"residential builder places tree in final plot frame")
check(not plot:sub(shops):find("AcornTree.build(",1,true),"shop builder has no tree")
-- Imported basket assembly and its footprint beside the oak.
for _,entry in Config.ACORN_BASKET_MESH.parts do
 for _,key in {"size","offset"} do local v=entry[key];entry[key]=vector(v.X,v.Y,v.Z) end
end
local offset=Config.ACORNS.storageOffset
Config.ACORNS.storageOffset=vector(offset.X,offset.Y,offset.Z)
local function basketModule()
 local run=assert(loadstring(sources.AcornBasket,"AcornBasket"));setfenv(run,setmetatable(env,{__index=getfenv()}));return run()
end
local Basket=basketModule();local initialCalls=calls
Basket.prewarm();Basket.prewarm()
check(calls==initialCalls+2,"basket loads each mesh once")
for _,yaw in {0,math.pi} do
 local base=frame(vector(80,0,100),yaw)*frame(Config.ACORNS.storageOffset+vector(0,Config.PLOT_SIZE.Y/2,0))
 local basket=assert(Basket.build(parent,base));local direction=if yaw==0 then 1 else -1
 check(basket.model.Parent==parent and basket.model.Name=="AcornBasket","basket attaches to residential plot")
 check(basket.body.Parent==basket.model and basket.handles.Parent==basket.model,"body and handles remain one assembly")
 check(basket.body.MeshId=="rbxassetid://100678587274495" and basket.handles.MeshId=="rbxassetid://94132455116099","uses imported hollow basket meshes")
 check(basket.body.TextureID=="rbxassetid://138402969079437" and basket.handles.TextureID=="rbxassetid://110241410993564","both basket textures retained")
 check(near(basket.body.CFrame.Position.Y-basket.body.Size.Y/2,Config.PLOT_SIZE.Y/2),"basket bottom sits on lawn")
 check(near(basket.model.WorldPivot.Position.X,80-20*direction) and near(basket.model.WorldPivot.Position.Z,100+16*direction),"basket follows far-row facing")
 check(near(basket.handles.CFrame.Position.Y+ basket.handles.Size.Y/2-Config.PLOT_SIZE.Y/2,1.20034543),"handles retain imported height")
 for _,part in {basket.body,basket.handles} do
  check(part.Anchored and not part.CanCollide and not part.CanQuery and not part.CanTouch,"basket cannot block runners or interact with physics")
  check(part.Color[1]==1 and part.Color[2]==1 and part.Color[3]==1,"basket texture uses white tint")
 end
end
check(calls==initialCalls+2,"additional baskets reuse templates")
local basketSpec=Config.ACORN_BASKET_MESH.parts[2]
local minX=offset.X+basketSpec.offset.X-basketSpec.size.X/2
local wood=Config.ACORN_OAK_MESH.parts[1]
local woodMaxX=Config.ACORNS.treeOffset.X+wood.offset.X+wood.size.X/2
check(minX-woodMaxX>.6,"basket clears even the whole wood mesh bounding box")
local bodySpec=Config.ACORN_BASKET_MESH.parts[1]
check(Config.PLOT_FRONT_LINE-(offset.Z+bodySpec.offset.Z+bodySpec.size.Z/2)>8.3,"basket clears front fence")
check(Config.PLOT_HALF_WIDTH+minX>12.3,"basket clears side fence")
check(offset.X+basketSpec.offset.X+basketSpec.size.X/2 < -18,"basket leaves central gate walk open")
local bodyTexture=bodySpec.texture;bodySpec.texture=""
local oldCalls,oldWarnings=calls,warnings
check(Config.acornBasketMesh()==nil,"basket refuses missing texture")
local MissingBasket=basketModule();check(MissingBasket.build(parent,frame(vector(0,0,0)))==nil and calls==oldCalls and warnings==oldWarnings+1,"invalid basket config warns without a half basket")
bodySpec.texture=bodyTexture
local oldDestroyed=destroyed;failAt=calls+2
local FailedBasket=basketModule();FailedBasket.prewarm();FailedBasket.prewarm()
check(destroyed==oldDestroyed+1 and warnings==oldWarnings+2,"failed handle load cleans up bowl and warns once")
check(FailedBasket.build(parent,frame(vector(0,0,0)))==nil and calls==oldCalls+2,"failed basket load never creates a partial model or reload loop")
check(plot:sub(residential,shops-1):find("AcornStorage.build(model, cf * CFrame.new(",1,true)~=nil,"residential builder places storage after plot rotation")
check(not plot:sub(shops):find("AcornStorage.build(",1,true),"shops get no basket")
-- Imported crate retains the old floor anchor for prompts and Acorn fill.
for _,entry in Config.ACORN_STORAGE_MESH.parts do
 for _,key in {"size","offset"} do local v=entry[key];entry[key]=vector(v.X,v.Y,v.Z) end
end
env.Vector3={new=vector}
env.CFrame.new=function(x,y,z) return frame(if type(x)=="table" then x else vector(x,y,z)) end
env.Color3.fromRGB=function(r,g,b) return {r,g,b} end
env.Enum.SurfaceType={Smooth="Smooth"}
env.Enum.Material.SmoothPlastic="SmoothPlastic"
local created={}
env.Instance.new=function(kind) local p={ClassName=kind};table.insert(created,p);return p end
local function storageModule()
 local run=assert(loadstring(sources.AcornStorage,"AcornStorage"));setfenv(run,setmetatable(env,{__index=getfenv()}));return run()
end
-- Capture cloned template parts as well as new anchors.
insert.CreateMeshPartAsync=function(_,id)
 calls+=1;if calls==failAt then error("isolated crate load failure") end
 local p=part();p.MeshId=id
 p.Clone=function(self) local clone=table.clone(self);table.insert(created,clone);return clone end
 return p
end
failAt=nil
local before=calls;local Storage=storageModule();Storage.prewarm();Storage.prewarm()
check(calls==before+4,"crate prewarms four meshes once")
for _,yaw in {0,math.pi} do
 created={}
 local base=frame(vector(80,.5,100),yaw)
 local refs=Storage.build(parent,base)
 check(refs.model.Parent==parent and refs.model.PrimaryPart==refs.body,"crate retains gameplay anchor and parent")
 check(refs.body.Name=="Storage" and refs.body.Transparency==1 and not refs.body.CastShadow,"imported crate hides original floor")
 check(near(refs.body.CFrame.Position.Y,.625),"floor anchor preserves exact Acorn fill ground offset")
 check(#created==6,"crate has exactly a model, an anchor and four visible meshes")
 for _,entry in Config.ACORN_STORAGE_MESH.parts do
  local found
  for _,p in created do if p.Name==entry.part then found=p end end
  check(found and found.MeshId=="rbxassetid://"..entry.id and found.TextureID=="rbxassetid://108648327781313","crate retains imported mesh and atlas")
  check(found.Anchored and not found.CanCollide and not found.CanTouch and not found.CanQuery,"crate art cannot obstruct running or collection")
  local direction=if yaw==0 then 1 else -1
  check(near(found.CFrame.Position.Z,100+entry.offset.Z*direction) and near(found.CFrame.Position.Y,.5+entry.offset.Y),"crate parts follow both plot orientations and ground")
 end
end
check(calls==before+4,"building crates never repeats network loads")
local oldDestroyed,oldWarnings=destroyed,warnings
failAt=calls+3
local BrokenStorage=storageModule();created={}
local fallback=BrokenStorage.build(parent,frame(vector(0,0,0)))
check(destroyed==oldDestroyed+2 and warnings==oldWarnings+1,"partial crate load destroys templates and warns")
check(#created==18 and fallback.body.Transparency~=1,"failed import falls back to complete visible wooden crate")
local failedCalls=calls;BrokenStorage.prewarm();check(calls==failedCalls,"failed crate load cannot retry every plot")
print(("PASS: %d oak/basket checks; generated assets, cached construction, both plot rows, clearances, failed loads and shelved decorations. No live player saves."):format(checks))
