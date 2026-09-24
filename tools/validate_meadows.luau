-- Read-only Studio playtest audit. Run after Main reports Ready.
local Http=game:GetService("HttpService")
local Shared=game.ReplicatedStorage.Shared
local Config=require(Shared.Config)
local boundary=require(Shared.MeadowBoundary).boundary
local grass=assert(workspace.Neighborhood:FindFirstChild("Grassland"))
local border=assert(workspace.Neighborhood:FindFirstChild("WorldBorder"))
local ponds=Http:JSONDecode(grass:GetAttribute("Ponds"))
local stream=Http:JSONDecode(grass:GetAttribute("Stream"))
local obstacles=Http:JSONDecode(grass:GetAttribute("Obstacles"))
local errors={};local checks=0
local function check(test,message) checks+=1;if not test then table.insert(errors,message) end end
check(#game.ServerStorage.MeadowTemplates:GetChildren()==34,"34 checked-in mesh templates")
check(#ponds==2,"two large ponds replace six small ponds")
local meshCount,parts,triangles=0,0,0
local types={}
for _,p in grass:GetDescendants() do
	if p:IsA("BasePart") then
		parts+=1
		check(p.Position.Magnitude<10000 and p.Size.Magnitude<4000,"finite bounded meadow transform: "..p.Name)
		if p:IsA("MeshPart") then meshCount+=1;types[p:GetAttribute("MeadowAsset") or p.Name]=true end
		check(p.Name~="RimWall" and p.Name~="PondWater","retired fake water/rim wall absent")
	end
end
check(parts<=Config.GRASSLAND.budget,"meadow part budget")
local shoreMeshes=0
for _,p in grass.Shorelines:GetChildren() do if p:IsA("MeshPart") then shoreMeshes+=1 end end
check(shoreMeshes==3,"shorelines use three imported meshes")
for _,name in {"RockRounded","RockSplit","RockSlab","RockWedge","RockCluster","Pebbles","Daisies","Bellflowers","PinkCups","GoldenSpikes","BushLow","BushTall","BushFlowers","Fern","Log","Mushrooms","Reeds","Lily","CascadeLedge"} do
	check(types[name],"placed asset family: "..name)
end
local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={workspace.Terrain};params.IgnoreWater=false
local waterResults={}

-- Dry terrain must stay beneath the mesh banks; smoothing can lift voxel surfaces.
for _,p in ponds do
	for _,sign in {-1,1} do
		local x=p.x+sign*(p.radius*1.15+1)
		local hit=workspace:Raycast(Vector3.new(x,5,p.z),Vector3.new(0,-20,0),params)
		check(not hit or hit.Position.Y<-.55,"terrain hidden beneath dry bank")
	end
end
for i,p in ponds do
	local origin=Vector3.new(p.x,20,p.z)
	local water=workspace:Raycast(origin,Vector3.new(0,-50,0),params)
	check(water and water.Material==Enum.Material.Water,"real water in pond "..i)
	local accessible=RaycastParams.new();accessible.FilterType=Enum.RaycastFilterType.Include
	accessible.FilterDescendantsInstances={workspace.Terrain,workspace.World.Ground,grass.Shorelines}
	local first=workspace:Raycast(origin,Vector3.new(0,-50,0),accessible)
	check(first and first.Material==Enum.Material.Water,"shore collision leaves pond open: "..i)
	params.IgnoreWater=true;local bed=workspace:Raycast(origin,Vector3.new(0,-50,0),params);params.IgnoreWater=false
	check(water and bed and water.Position.Y-bed.Position.Y>4,"pond depth above 4 studs: "..i)
	check(p.clear>=3,"large pond clearing stays outside tree canopies: "..i)
	table.insert(waterResults,{x=p.x,z=p.z,waterY=water and water.Position.Y,bedY=bed and bed.Position.Y})
end
local area=Region3.new(Vector3.new(stream.x-4,8,264),Vector3.new(stream.x+4,28,272)):ExpandToGrid(4)
local mats,occ=workspace.Terrain:ReadVoxels(area,4);local waterCells=0
for x=1,#mats do for y=1,#mats[x] do for z=1,#mats[x][y] do if mats[x][y][z]==Enum.Material.Water and occ[x][y][z]>.1 then waterCells+=1 end end end end
check(waterCells>0,"waterfall contains water volume")
check(stream.halfWidth==12,"waterfall outlet is 24 studs wide")
local ground=workspace.World.Ground:GetChildren()
for i,a in ground do for j=i+1,#ground do
	local b=ground[j]
	local ox=(a.Size.X+b.Size.X)/2-math.abs(a.Position.X-b.Position.X)
	local oz=(a.Size.Z+b.Size.Z)/2-math.abs(a.Position.Z-b.Position.Z)
	check(ox<.001 or oz<.001,"ground section tops do not overlap")
end end
params.FilterDescendantsInstances={border}
local metrics=Config.streetMetrics()
for _,sign in {-1,1} do
	local hit=workspace:Raycast(Vector3.new(sign*(metrics.tunnelEastX-8),5,0),Vector3.new(sign*40,0,0),params)
	check(hit and hit.Instance.Name=="TunnelVoid","tunnel aperture is clear on side "..sign)
end
for i,a in boundary do
	local b=boundary[i%#boundary+1]
	local tunnel=math.abs(a.x)==252 and a.x==b.x and math.max(math.abs(a.z),math.abs(b.z))<=11.001
	if not tunnel then
		local center=Vector3.new((a.x+b.x)/2,3,(a.z+b.z)/2)
		local outward=Vector3.new(center.X/252,0,center.Z/270).Unit
		local hit=workspace:Raycast(center-outward*12,outward*30,params)
		check(hit and hit.Instance.Name=="CliffCollision","continuous collision at border span "..i)
	end
end
params.FilterDescendantsInstances={workspace.World.Ground,workspace.Terrain}
local missingGround=0
for _,side in {-1,1} do for x=-190,190,10 do for z=158,255,8 do
	local hit=workspace:Raycast(Vector3.new(x,15,z*side),Vector3.new(0,-50,0),params)
	if not hit then missingGround+=1 end
end end end
check(missingGround==0,"no holes under sampled herd lanes")
return Http:JSONEncode({checks=checks,errors=errors,meadowParts=parts,meadowMeshes=meshCount,
	borderParts=#border:GetChildren(),waterfallWaterCells=waterCells,ponds=waterResults,
	groundSections=#ground,missingGround=missingGround,obstacles=#obstacles})
