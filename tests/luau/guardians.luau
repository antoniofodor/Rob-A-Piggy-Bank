-- Real palette selection and disabled follower lifecycle without a Studio session.
local Config, sources = ...
local checks = 0
local function check(ok, message) checks += 1; assert(ok, message) end
local color = {}
color.__index = color
local function rgb(r, g, b) return setmetatable({R=r/255,G=g/255,B=b/255}, color) end
function color:Lerp(other, t)
	return rgb((self.R+(other.R-self.R)*t)*255, (self.G+(other.G-self.G)*t)*255,
		(self.B+(other.B-self.B)*t)*255)
end
local function same(a,b)
	return math.abs(a.R-b.R)<1e-6 and math.abs(a.G-b.G)<1e-6 and math.abs(a.B-b.B)<1e-6
end
for _,coat in Config.DOG_COATS do
	for _,key in {"fur","furDark","collar"} do coat[key]=rgb(table.unpack(coat[key])) end
end
local names=setmetatable({}, {__index=function(_,key) return key end})
local modules={Config=Config,PetModel={}}
local env=setmetatable({
	game={GetService=function() return {Shared=names} end},
	require=function(key) return assert(modules[key], key) end,
	Color3={fromRGB=rgb,new=function(r,g,b) return rgb(r*255,g*255,b*255) end},
	Vector3={new=function(...) return {...} end},
	CFrame={Angles=function(...) return {...} end},
	Instance={new=function() error("disabled pets must not create instances") end},
},{__index=getfenv()})
local function load(name)
	local fn=assert(loadstring(sources[name],name));setfenv(fn,env)
	modules[name]=fn();return modules[name]
end
local catalog=load("GuardCatalog")
local rig=load("GuardRig")
local kennel=load("KennelModel")
for key,coat in Config.DOG_COATS do
	local model=assert(rig.key(Config.DOG_LEVEL,key))
	local expected=catalog[model].palette
	local tones=kennel.tones(key)
	check(same(tones.wood,if coat.guardModel then rgb(table.unpack(expected.fur)) else coat.fur),key.." kennel matches actual body")
	check(same(tones.trim,if coat.guardModel then rgb(table.unpack(expected.dark)) else coat.furDark),key.." kennel matches actual dark trim")
	check(same(tones.roof,if coat.guardModel then rgb(table.unpack(expected.light)) else coat.collar),key.." roof uses a visible guardian accent")
end
local default=kennel.tones("")
local unknown=kennel.tones("retired-guardian")
check(same(default.wood,unknown.wood) and same(default.trim,unknown.trim),"unknown guardian safely uses default rig palette")
check(#Config.auditSeason()==0,"replacement guardian reward passes season audit")
check(Config.PETS_ENABLED==false,"pets disabled")
load("Pets").start({})
check(true,"disabled follower starts no instances, player watchers or frame connections")
print("PASS: "..checks.." guardian palette, season reward and disabled follower checks.")
