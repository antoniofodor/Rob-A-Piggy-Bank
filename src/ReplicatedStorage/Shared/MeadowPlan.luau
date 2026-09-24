--!strict
-- Reserve the two large water clearings before planting the grove.
local Config=require(script.Parent.Config)
local Plan={}
Plan.settings={pondRadius=26,basinRadius=32,basinSetback=18,waterfallWidth=24}
function Plan.layout(g: any, trees: { any }?): { any }
	local M=Plan.settings
	local ponds={
		{side=-1,x=-g.corridorInner*.40,z=-(g.bandNear+g.bandFar)/2,radius=M.pondRadius},
		{side=1,x=g.corridorInner*.28,z=g.bandFar-M.basinSetback,radius=M.basinRadius},
	}
	for _,p in ponds do
		p.rim=p.radius+3.6;p.clear=math.huge
		for _,t in trees or {} do p.clear=math.min(p.clear,math.sqrt((p.x-t.x)^2+(p.z-t.z)^2)-t.reach-p.rim) end
	end
	return ponds
end
function Plan.stream(g: any,ponds: { any }): any
	local p=ponds[2]
	return {x=p.x,z0=p.z,z1=Config.GROUND_SIZE.Y/2-32,
		halfWidth=Plan.settings.waterfallWidth/2,
		bankStart=p.z+p.radius*.86*.85}
end
function Plan.treeClear(x: number,z: number,reach: number): boolean
	local g=Config.herdGround();local ponds=Plan.layout(g);local stream=Plan.stream(g,ponds)
	for _,p in ponds do
		if math.sqrt((x-p.x)^2+(z-p.z)^2)<p.rim+reach+3 then return false end
	end
	if z>stream.z0-reach and z<stream.z1+reach and math.abs(x-stream.x)<stream.halfWidth+reach+4 then return false end
	return true
end
return Plan
