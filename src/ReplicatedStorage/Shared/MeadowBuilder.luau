--!strict
local Config = require(script.Parent.Config)
local Assets = require(script.Parent.MeadowAssets)
local Water = require(script.Parent.MeadowWater)
local Boundary = require(script.Parent.MeadowBoundary)
local Shore = require(script.Parent.MeadowShore)
local Plan = require(script.Parent.MeadowPlan)
local Meadow = {}
local blocked: { any } = {}
local stream: any = nil
Meadow.ready = Assets.ready
Meadow.layout = Plan.layout
local function solid(parent: Instance, name: string, size: Vector3, at: CFrame, visible: boolean?, color: Color3?): Part
	local p = Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=at;p.Anchored=true
	p.CanCollide=true;p.CanQuery=true;p.CanTouch=false;p.Transparency=if visible then 0 else 1
	p.Color=color or Color3.fromRGB(37,43,43);p.Material=Enum.Material.SmoothPlastic;p.Parent=parent
	return p
end
local function distance(x: number,z: number,t: any): number
	return math.sqrt((x-t.x)^2+(z-t.z)^2)
end
function Meadow.blocks(position: Vector3): boolean
	for _, item in blocked do
		if distance(position.X,position.Z,item)<item.r+Config.GRASSLAND.pondMargin then return true end
	end
	if stream and position.Z>=stream.z0-3 and position.Z<=stream.z1+3 and math.abs(position.X-stream.x)<stream.halfWidth+4 then return true end
	return false
end
local function cliffHeight(x: number): number
	local best, h = math.huge, 35
	for _, p in Boundary.boundary do
		if p.z==270 and math.abs(p.x-x)<best then best=math.abs(p.x-x);h=p.height end
	end
	return h
end
local function waterfall(parent: Instance, x: number, z: number)
	local top=math.ceil((cliffHeight(x)+5)/4)*4
	local width=Plan.settings.waterfallWidth
	Water.cascade(x,z,top,width)
	for _, side in {-1,1} do
		Assets.place(parent,"CascadeLedge",CFrame.new(x+side*(width/2+4),-.8,z-1)*CFrame.Angles(0,side*.35,0),1.7,true)
		Assets.place(parent,"RockSlab",CFrame.new(x+side*(width/2+2),top-1,z+8),1.4,false)
		Assets.place(parent,"RockCluster",CFrame.new(x+side*(width/2+1),top-4,z+3),1.4,false)
	end
	local anchor=Instance.new("Part");anchor.Name="WaterfallFlow";anchor.Size=Vector3.one
	anchor.Transparency=1;anchor.Anchored=true;anchor.CanCollide=false;anchor.CanQuery=false;anchor.CanTouch=false
	anchor.CFrame=CFrame.new(x,0,z-5.2);anchor.Parent=parent
	for i=-3,3 do
		local a=Instance.new("Attachment");a.Position=Vector3.new(i*width/7,top,0);a.Parent=anchor
		local b=Instance.new("Attachment");b.Position=Vector3.new(i*width/7,-1.3,-1);b.Parent=anchor
		local beam=Instance.new("Beam");beam.Name="FallingWater";beam.Attachment0=a;beam.Attachment1=b
		beam.Width0=width/6;beam.Width1=width/5.5;beam.FaceCamera=true
		beam.Color=ColorSequence.new(Color3.fromRGB(177,233,244),Color3.fromRGB(237,255,255))
		beam.Transparency=NumberSequence.new(.38);beam.Texture="rbxasset://textures/particles/smoke_main.dds"
		beam.TextureMode=Enum.TextureMode.Wrap
		beam.TextureLength=top*(.65+.07*(i+3));beam.TextureSpeed=1.5+.13*(i+3);beam.Segments=4;beam.Parent=anchor
	end
	local foam=Instance.new("ParticleEmitter");foam.Name="Splash";foam.Texture="rbxasset://textures/particles/smoke_main.dds"
	foam.Color=ColorSequence.new(Color3.fromRGB(212,243,245));foam.Rate=10;foam.Lifetime=NumberRange.new(.7,1.2)
	foam.Speed=NumberRange.new(2,5);foam.SpreadAngle=Vector2.new(50,50);foam.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,1.3),NumberSequenceKeypoint.new(1,3)})
	foam.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.55),NumberSequenceKeypoint.new(1,1)});foam.Parent=anchor
end
function Meadow.build(parent: Instance, trees: { any }, ponds: { any }): (Folder,{ any },number)
	assert(Assets.ready(),"All meadow templates must be installed before building")
	table.clear(blocked);stream=nil
	local g=Config.herdGround();local G=Config.GRASSLAND
	local folder=Instance.new("Folder");folder.Name="Grassland"
	stream=Plan.stream(g,ponds)
	Water.build(ponds,stream)
	Shore.build(folder,ponds,stream)
	for index, pond in ponds do
		local rng=Random.new(G.seed+index*123)
		-- Broken shore groups; the bank is terrain, not a ring of spheres or invisible walls.
		for i=1,14 do
			local a=i*math.pi*2/17+.2*index;local r=pond.radius*(1.08+.09*math.sin(a*3+pond.side))
			local x,z=pond.x+math.cos(a)*r,pond.z+math.sin(a)*r*.86
			if not (pond.side==1 and math.abs(x-stream.x)<stream.halfWidth+3 and z>pond.z) then
				Assets.place(folder,if i%3==0 then "RockCluster" else "RockSlab",CFrame.new(x,-.9,z)*CFrame.Angles(0,a,0),rng:NextNumber(.65,1.0),true)
			end
		end
		for i=1,7 do
			local a=rng:NextNumber()*math.pi*2
			Assets.place(folder,"Lily",CFrame.new(pond.x+math.cos(a)*pond.radius*.45,-1.35,pond.z+math.sin(a)*pond.radius*.4),rng:NextNumber(.8,1.2),false)
			Assets.place(folder,"Reeds",CFrame.new(pond.x+math.cos(a)*pond.radius*.96,-1.2,pond.z+math.sin(a)*pond.radius*.83)*CFrame.Angles(0,a,0),1,false)
		end
	end
	local function clear(x: number,z: number,r: number): boolean
		if math.abs(x)+r>g.corridorInner-14 or math.abs(z)-r<g.bandNear+6 or math.abs(z)+r>g.bandFar-3 then return false end
		for _, pond in ponds do if distance(x,z,pond)<pond.rim+r+1 then return false end end
		for _, tree in trees do if distance(x,z,tree)<G.trunkKeep+r then return false end end
		if Meadow.blocks(Vector3.new(x,0,z)) then return false end
		for _, rock in blocked do if distance(x,z,rock)<rock.r+r+3 then return false end end
		return true
	end
	local rockNames={"RockRounded","RockSplit","RockWedge","RockSlab","RockCluster","Pebbles"}
	local flowers={"Daisies","Bellflowers","PinkCups","GoldenSpikes"}
	for _, side in {-1,1} do
		local rng=Random.new(G.seed+side*932)
		local rockCount=0
		for i=1,80 do
			local x=rng:NextNumber(-165,165);local z=side*rng:NextNumber(g.bandNear+15,g.bandFar-10)
			local yaw=rng:NextNumber()*math.pi*2
			if rockCount<9 and clear(x,z,6) then
				local name=rockNames[rockCount%#rockNames+1]
				local p=Assets.place(folder,name,CFrame.new(x,-.8,z)*CFrame.Angles(0,yaw,0),1,true)
				table.insert(blocked,{x=p.Position.X,z=p.Position.Z,r=math.sqrt(p.Size.X^2+p.Size.Z^2)/2})
				rockCount+=1
			end
		end
		for i=1,140 do
			-- Fixed per-candidate seed keeps unaffected flowers stable when a tree is moved.
			local draw=Random.new(G.seed+i*149+side*107)
			local x=draw:NextNumber(-170,170);local z=side*draw:NextNumber(g.bandNear+12,g.bandFar-8)
			local yaw=draw:NextNumber()*math.pi*2
			if clear(x,z,2.3) then
				local name=flowers[i%4+1];local scale=draw:NextNumber(1.15,1.65)
				if i%7==0 then name=({"BushLow","BushTall","BushFlowers"})[i%3+1];scale=1.2 end
				if i%11==0 then name="Fern";scale=1.3 end
				if i%23==0 then name="Mushrooms";scale=1.2 end
				local y=if name=="Fern" then -1.35 else -.55
				Assets.place(folder,name,CFrame.new(x,y,z)*CFrame.Angles(0,yaw,0),scale,false)
			end
		end
		for i=1,35 do
			local x=rng:NextNumber(-150,150);local z=side*rng:NextNumber(g.bandNear+15,g.bandFar-12)
			if clear(x,z,6) then
				local p=Assets.place(folder,"Log",CFrame.new(x,-.7,z)*CFrame.Angles(0,rng:NextNumber()*math.pi,0),1.3,true)
				table.insert(blocked,{x=p.Position.X,z=p.Position.Z,r=4.5});break
			end
		end
	end
	waterfall(folder,stream.x,stream.z1)
	folder:SetAttribute("Ponds",game:GetService("HttpService"):JSONEncode(ponds))
	folder:SetAttribute("Obstacles",game:GetService("HttpService"):JSONEncode(blocked))
	folder:SetAttribute("Stream",game:GetService("HttpService"):JSONEncode(stream))
	folder.Parent=parent
	return folder,ponds,#folder:GetChildren()
end
function Meadow.buildBorder(parent: Instance, metrics: any): boolean
	if not Assets.ready() then return false end
	local folder=Instance.new("Folder");folder.Name="WorldBorder"
	local sx,sz=metrics.tunnelEastX/252,(Config.GROUND_SIZE.Y/2-30)/270
	for i=1,12 do
		local p=Assets.place(folder,string.format("Border_%02d",i),CFrame.identity,1,false)
		p.Size*=Vector3.new(sx,1,sz);p.CFrame=CFrame.new(p.Position*Vector3.new(sx,1,sz))*p.CFrame.Rotation
	end
	for i,a in Boundary.boundary do
		local b=Boundary.boundary[i%#Boundary.boundary+1]
		local tunnel=math.abs(a.x)==252 and a.x==b.x and math.max(math.abs(a.z),math.abs(b.z))<=11.001
		if not tunnel then
			local pa=Vector3.new(a.x*sx,0,a.z*sz);local pb=Vector3.new(b.x*sx,0,b.z*sz)
			local length=(pb-pa).Magnitude
			if length>.05 then
				local h=math.min(a.height,b.height)-1
				-- Hidden collider faces follow shared boundary spans; only buried joins overlap.
				local cf=CFrame.lookAt((pa+pb)/2+Vector3.new(0,h/2-1,0),pb+Vector3.new(0,h/2-1,0))
				solid(folder,"CliffCollision",Vector3.new(4,h+2,length+.15),cf)
			end
		end
	end
	for _, sign in {-1,1} do
		local mouth=sign*metrics.tunnelEastX;local depth=metrics.tunnelDepth;local half=metrics.tunnelHalfWidth
		solid(folder,"TunnelVoid",Vector3.new(1,14,half*2),CFrame.new(mouth+sign*(depth-.5),6.5,0),true,Color3.new(0,0,0)).Material=Enum.Material.Neon
		solid(folder,"TunnelRoof",Vector3.new(depth,3,half*2),CFrame.new(mouth+sign*depth/2,15,0),true)
		for _, side in {-1,1} do solid(folder,"TunnelLiner",Vector3.new(depth,15,1),CFrame.new(mouth+sign*depth/2,6.5,side*half),true) end
		solid(folder,"TunnelFloor",Vector3.new(depth,.2,half*2),CFrame.new(mouth+sign*depth/2,-.43,0),true,Color3.fromRGB(25,27,29))
	end
	folder.Parent=parent
	return true
end
return Meadow
