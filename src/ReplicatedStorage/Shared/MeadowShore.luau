--!strict
-- Flat-shaded banks bridge the ground's rectangular cutouts to irregular water edges.
local Shore = {}
local Assets = require(script.Parent.MeadowAssets)
local Layout = require(script.Parent.MeadowShoreLayout)
local Water = require(script.Parent.MeadowWater)
local GRASS=Color3.fromRGB(82,114,60)
local BANK=Color3.fromRGB(96,111,64)
-- Thin open mesh banks can be convexified across the pond by Roblox. Keep the
-- visual meshes noncolliding and merge dry 2-stud cells into low supports.
local function supports(parent: Instance,ponds: { any },stream: any?)
	for _,p in ponds do
		local r=p.radius*1.15+4
		local x0,x1=math.floor((p.x-r)/4)*4,math.ceil((p.x+r)/4)*4
		local z0,z1=math.floor((p.z-r)/4)*4,math.ceil((p.z+r)/4)*4
		local rectangles={};local active={}
		for z=z0,z1-2,2 do
			local runs={};local start: number?=nil
			for x=x0,x1,2 do
				local wet=Water.shape(p,x+1,z+1)<1.07
				if stream and z+1>=stream.z0 and z+1<=stream.z1 and math.abs(x+1-stream.x)<stream.halfWidth+2 then wet=true end
				local dry=x<x1 and not wet
				if dry and start==nil then start=x end
				if not dry and start~=nil then table.insert(runs,{x0=start,x1=x});start=nil end
			end
			local nextActive={}
			for _,run in runs do
				local key=tostring(run.x0)..":"..tostring(run.x1)
				local prior=active[key]
				if prior then prior.z1=z+2;nextActive[key]=prior else
					local rect={x0=run.x0,x1=run.x1,z0=z,z1=z+2};table.insert(rectangles,rect);nextActive[key]=rect
				end
			end
			active=nextActive
		end
		for _,rect in rectangles do
			local part=Instance.new("Part");part.Name="BankSupport";part.Anchored=true;part.Transparency=1
			part.Size=Vector3.new(rect.x1-rect.x0,1,rect.z1-rect.z0)
			part.CFrame=CFrame.new((rect.x0+rect.x1)/2,-1.03,(rect.z0+rect.z1)/2)
			part.CanCollide=true;part.CanQuery=true;part.CanTouch=false;part.Parent=parent
		end
	end
end
local function triangle(parent: Instance,a: Vector3,b: Vector3,c: Vector3,color: Color3)
	local ab,ac,bc=b-a,c-a,c-b
	if ab:Dot(ab)>ac:Dot(ac) and ab:Dot(ab)>bc:Dot(bc) then c,a=a,c
	elseif ac:Dot(ac)>bc:Dot(bc) then a,b=b,a end
	ab,ac,bc=b-a,c-a,c-b
	if ac:Cross(ab).Magnitude<.001 then return end
	local right=ac:Cross(ab).Unit;local back=bc.Unit;local up=bc:Cross(right).Unit
	local height=math.abs(ab:Dot(up))
	for _,s in {{(a+b)/2,right,back,math.abs(ab:Dot(back))},{(a+c)/2,-right,-back,math.abs(ac:Dot(back))}} do
		if height>.001 and s[4]>.001 then
			local p=Instance.new("WedgePart");p.Name="ShoreFace";p.Size=Vector3.new(.04,height,s[4])
			p.CFrame=CFrame.fromMatrix(s[1],s[2],up,s[3]);p.Anchored=true;p.Material=Enum.Material.SmoothPlastic
			p.Color=color;p.CanCollide=true;p.CanTouch=false;p.CanQuery=true;p.CastShadow=false;p.Parent=parent
		end
	end
end
local function quad(parent: Instance,a: Vector3,b: Vector3,c: Vector3,d: Vector3,color: Color3)
	triangle(parent,a,b,c,color);triangle(parent,a,c,d,color)
end
function Shore.build(parent: Instance,ponds: { any },stream: any?)
	local folder=Instance.new("Folder");folder.Name="Shorelines";folder.Parent=parent
	local templates=game:GetService("ServerStorage"):FindFirstChild("MeadowTemplates")
	local cached=templates and templates:FindFirstChild(string.format("Shore_%02d",#ponds+1)) and #ponds==#Layout.ponds and stream~=nil
	if cached then
		for i,p in ponds do
			local saved=Layout.ponds[i]
			if math.abs(p.x-saved.x)>.01 or math.abs(p.z-saved.z)>.01 or p.radius~=saved.radius or p.side~=saved.side then cached=false end
		end
		if math.abs(stream.x-Layout.stream.x)>.01 or math.abs(stream.z0-Layout.stream.z0)>.01 or math.abs(stream.z1-Layout.stream.z1)>.01 or stream.halfWidth~=Layout.stream.halfWidth then cached=false end
	end
	if cached then
		for i=1,#ponds+1 do Assets.place(folder,string.format("Shore_%02d",i),CFrame.identity,1,false) end
		supports(folder,ponds,stream)
		return folder
	end
	for _,p in ponds do
		local r=p.radius*1.15+4
		local x0,x1=math.floor((p.x-r)/4)*4,math.ceil((p.x+r)/4)*4
		local z0,z1=math.floor((p.z-r)/4)*4,math.ceil((p.z+r)/4)*4
		local rings={{},{},{}}
		-- Include all four corner bearings so the outer bank exactly covers its rectangular opening.
		local angles={}
		for i=0,23 do table.insert(angles,i*math.pi*2/24) end
		for _,x in {x0,x1} do for _,z in {z0,z1} do table.insert(angles,math.atan2(z-p.z,x-p.x)%(2*math.pi)) end end
		table.sort(angles)
		for _,a in angles do
			local dx,dz=math.cos(a),math.sin(a)
			local tx=if math.abs(dx)<1e-7 then math.huge elseif dx>0 then (x1-p.x)/dx else (x0-p.x)/dx
			local tz=if math.abs(dz)<1e-7 then math.huge elseif dz>0 then (z1-p.z)/dz else (z0-p.z)/dz
			local t=math.min(tx,tz)
			table.insert(rings[1],Vector3.new(p.x+dx*t,-.47,p.z+dz*t))
			local rr=p.radius*(1+.1*math.sin(a*3+p.side))
			table.insert(rings[2],Vector3.new(p.x+dx*rr*1.10,-.52,p.z+dz*rr*.86*1.10))
			table.insert(rings[3],Vector3.new(p.x+dx*rr*.87,-2.5,p.z+dz*rr*.86*.87))
		end
		for i=1,#angles do
			local j=i%#angles+1;local midpoint=(rings[3][i]+rings[3][j])/2
			local outlet=stream and midpoint.Z>p.z and math.abs(midpoint.X-stream.x)<stream.halfWidth+2 and p.side==1
			if not outlet then
				quad(folder,rings[1][i],rings[1][j],rings[2][j],rings[2][i],GRASS)
				quad(folder,rings[2][i],rings[2][j],rings[3][j],rings[3][i],BANK)
			end
		end
	end
	if stream then
		local z0=stream.bankStart;local z1=stream.z1
		for _,side in {-1,1} do
			local outer=if side<0 then math.floor((stream.x-stream.halfWidth-4)/4)*4 else math.ceil((stream.x+stream.halfWidth+4)/4)*4
			local inner=stream.x+side*stream.halfWidth
			quad(folder,Vector3.new(outer,-.47,z0),Vector3.new(outer,-.47,z1),Vector3.new(inner,-2.5,z1),Vector3.new(inner,-2.5,z0),BANK)
		end
	end
	return folder
end
return Shore
