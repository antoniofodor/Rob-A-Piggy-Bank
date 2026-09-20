--!strict
-- Static category illustrations, not previews of a particular purchasable item.
-- Built locally from low-poly shapes so the art needs no image upload.
local Shared = game:GetService("ReplicatedStorage").Shared
local Theme = require(Shared.Theme)
local Scenes = {}
local C = Color3.fromRGB
local function part(m: Model, name: string, size: Vector3, cf: CFrame, colour: Color3, class: string?): BasePart
	local p = Instance.new(class or "Part") :: BasePart
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = colour
	p.Material = Enum.Material.SmoothPlastic; p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.CastShadow = false
	p.Parent = m; return p
end
local function box(m: Model, name: string, x: number, y: number, z: number, w: number, h: number, d: number, colour: Color3): BasePart
	return part(m, name, Vector3.new(w,h,d), CFrame.new(x,y,z), colour)
end
local function model(name: string): Model local m=Instance.new("Model");m.Name=name;return m end
local function place(scene: Model, item: Model, height: number, x: number, z: number, yaw: number?)
	local _, size = item:GetBoundingBox()
	item:ScaleTo(item:GetScale() * height / math.max(.1,size.Y))
	item:PivotTo(CFrame.Angles(0,math.rad(yaw or 0),0) * item:GetPivot())
	local cf, bounds = item:GetBoundingBox()
	item:PivotTo(item:GetPivot() + Vector3.new(x-cf.X, bounds.Y/2-cf.Y, z-cf.Z))
	item.Parent = scene
end

local function lock(): Model
	local m=model("Padlock")
	box(m,"Body",0,1,0,1.9,1.8,.65,C(182,188,204))
	box(m,"Face",0,1,.34,1.58,1.55,.04,C(206,213,226))
	for _,x in {-0.65,.65} do box(m,"Shackle",x,2.25,0,.32,1.25,.35,C(203,209,219)) end
	part(m,"Shoulder",Vector3.new(.32,.65,.35),CFrame.new(-.46,2.86,0)*CFrame.Angles(0,0,-math.pi/4),C(224,229,237))
	part(m,"Shoulder",Vector3.new(.32,.65,.35),CFrame.new(.46,2.86,0)*CFrame.Angles(0,0,math.pi/4),C(224,229,237))
	box(m,"Crown",0,3.03,0,.67,.32,.35,C(224,229,237))
	local key=box(m,"Keyhole",0,1.15,.39,.47,.47,.06,Theme.INK);key.CFrame*=CFrame.Angles(0,0,math.pi/4)
	box(m,"KeyStem",0,.84,.39,.26,.5,.06,Theme.INK)
	return m
end
local function sack(): Model
	local m=model("CoinSack")
	box(m,"Centre",0,1.13,0,1.7,2.05,1.6,C(144,89,41))
	for _,x in {-1,1} do
		part(m,"Fold",Vector3.new(.48,1.8,1.48),CFrame.new(x*.88,1.05,0)*CFrame.Angles(0,0,math.rad(-x*12)),C(159,99,43))
	end
	box(m,"Neck",0,2.4,0,.96,.65,.95,C(107,65,33))
	box(m,"OpenTop",0,2.82,0,1.42,.46,1.2,C(155,97,48))
	box(m,"Inside",0,3.06,0,1.07,.025,.8,C(87,54,32))
	local coin=part(m,"GoldSeal",Vector3.new(.14,1.2,1.2),CFrame.new(0,1.05,.87)*CFrame.Angles(0,math.pi/2,0),Theme.GOLD);
	(coin :: Part).Shape=Enum.PartType.Cylinder
	return m
end
local function house(): Model
	local m=model("GardenHouse")
	box(m,"Walls",0,1.15,0,3.3,2.3,2.4,Theme.PAPER)
	for _,side in {-1,1} do
		part(m,"Roof",Vector3.new(3.05,1.55,1.96),CFrame.new(side*.98,2.99,0)*CFrame.Angles(0,if side==1 then math.pi else 0,0)*CFrame.Angles(0,math.pi/2,0),C(29,139,45),"WedgePart")
	end
	box(m,"Chimney",.9,3.25,-.55,.55,1.6,.62,C(142,87,48))
	box(m,"Door",0,.62,1.22,.65,1.25,.07,C(143,92,53))
	for _,x in {-1.04,1.04} do box(m,"Window",x,1.35,1.23,.66,.72,.06,C(40,151,237)) end
	box(m,"Lawn",0,-.08,0,6,.16,3.4,C(89,188,51))
	for _,x in {-2.45,2.45} do
		box(m,"TreeTrunk",x,.65,-.4,.26,1.3,.28,C(146,91,49))
		box(m,"Canopy",x,1.72,-.4,1.0,1.3,.95,C(46,163,48))
		box(m,"CanopyTop",x,2.48,-.4,.7,.6,.7,C(76,195,59))
		for _,dx in {-.48,.48} do box(m,"FencePost",x+dx,.42,1.4,.15,.84,.15,C(157,103,49)) end
		box(m,"FenceRail",x,.46,1.4,1.12,.22,.16,C(157,103,49))
	end
	return m
end
local function dog(): Model
	local m=model("GuardDog")
	local tan=C(225,179,117)
	box(m,"Body",0,1.08,-.15,1.2,1.2,1.8,tan)
	for _,x in {-.42,.42} do for _,z in {-.72,.59} do box(m,"Leg",x,.4,z,.4,.8,.44,tan) end end
	box(m,"Head",0,1.93,.68,1.48,1.25,1.05,C(239,198,141))
	for _,x in {-.5,.5} do
		part(m,"Ear",Vector3.new(.47,.9,.48),CFrame.new(x,2.86,.57)*CFrame.Angles(0,math.pi,0),tan,"WedgePart")
		box(m,"Eye",x*.72,2.05,1.22,.18,.25,.06,Theme.INK)
	end
	box(m,"Muzzle",0,1.61,1.24,.88,.5,.46,C(249,223,179))
	box(m,"Nose",0,1.79,1.51,.28,.19,.08,Theme.INK)
	box(m,"Collar",0,1.39,.51,1.27,.19,1.28,Theme.STOP)
	part(m,"Tail",Vector3.new(.24,.85,.24),CFrame.new(.1,1.63,-1.03)*CFrame.Angles(math.rad(-30),0,0),tan)
	return m
end
local function crate(): Model
	local m=model("WoodenCrate")
	local wood=C(151,91,45)
	box(m,"Box",0,1,0,2,2,1.85,C(117,73,37))
	for _,x in {-.88,.88} do box(m,"Post",x,1,1,.22,2.1,.18,wood) end
	for _,y in {.1,1.9} do box(m,"Rail",0,y,1,2.1,.22,.18,wood) end
	for _,angle in {-45,45} do part(m,"Brace",Vector3.new(.19,2.35,.14),CFrame.new(0,1,1.12)*CFrame.Angles(0,0,math.rad(angle)),wood) end
	for _,z in {-.82,.82} do box(m,"LidRail",0,2.08,z,2.1,.19,.2,wood) end
	return m
end
local function pig(): Model
	local m=model("PiggyIllustration")
	box(m,"Body",0,1.16,0,1.75,1.65,2.22,Theme.PIG)
	box(m,"Face",0,1.23,1.03,1.65,1.45,.5,Theme.PIG)
	box(m,"Snout",0,.93,1.43,.92,.64,.35,Theme.PIG_DEEP)
	for _,x in {-.51,.51} do
		box(m,"Eye",x,1.45,1.31,.16,.21,.08,Theme.INK)
		part(m,"Ear",Vector3.new(.55,.67,.58),CFrame.new(x,2.19,.57)*CFrame.Angles(0,math.pi,0),Theme.PIG_DEEP,"WedgePart")
		for _,z in {-.76,.76} do box(m,"Foot",x,.25,z,.43,.5,.43,Theme.PIG_DEEP) end
	end
	for _,x in {-.24,.24} do box(m,"Nostril",x,.94,1.62,.15,.25,.03,C(111,48,67)) end
	box(m,"CoinSlot",0,2.0,0,.08,.035,.68,Theme.INK)
	return m
end

-- ONE SUBJECT, for the sidebar. `build` composes two objects for four of the
-- six categories, which is right on a 200-stud landing tile and mush in a
-- 38-pixel square -- so this picks the single most recognisable shape instead
-- of shrinking a two-object stage. It deliberately does NOT set the `ShopScene`
-- attribute, so `W.preview` frames it the way it frames a catalogue item rather
-- than with the wide stage crop.
function Scenes.icon(key: string): Model
	if key == "home" then return house()
	elseif key == "companions" then return dog()
	elseif key == "rides" then return require(Shared.RideModel).build("scooter")
	elseif key == "supplies" then return require(Shared.GadgetModel).build("plunger", false)
	elseif key == "style" then return crate()
	end
	-- Upgrades: the sack rather than the padlock. All three trees live behind
	-- that tab and the sack is the one that says COINS, which is what every
	-- rung on it is bought with.
	return sack()
end

-- Exported for the crate contents summary, which shows the crate you are about
-- to open beside its odds. Building a second crate over there would be the
-- near-identical duplicate that drifts the first time either is touched -- and
-- this one is already the crate a player sees on the Style & Crates tile, so
-- sharing it is what makes the two pictures the same object.
Scenes.crate = crate

function Scenes.build(key: string): Model
	local scene=model("Category_"..key)
	scene:SetAttribute("ShopScene",true)
	if key=="upgrades" then place(scene,lock(),3.3,-1.6,0,-8);place(scene,sack(),3.3,1.35,0,8)
	elseif key=="home" then place(scene,house(),3.5,0,0,0)
	elseif key=="companions" then
		place(scene,dog(),3.3,0,0,-8)
	elseif key=="rides" then place(scene,require(Shared.RideModel).build("scooter"),3.25,0,0,55)
	elseif key=="supplies" then
		place(scene,require(Shared.GadgetModel).build("plunger",false),3.7,-1.25,0,0)
		local gum=model("GumPacket");box(gum,"Packet",0,.7,0,1.9,1.4,1.05,Theme.PIG)
		box(gum,"Wrapper",0,.7,.54,1.55,.91,.025,Theme.PIG:Lerp(Theme.PAPER,.3))
		place(scene,gum,1.8,1.35,.1,-12)
	else place(scene,crate(),2.5,-1.65,0,-8);place(scene,pig(),3.15,1.2,0,8) end
	-- Flat contact patches keep the subjects seated without animated effects.
	local colour=Theme.SHOP_COLOURS[key]:Lerp(Theme.INK,.16)
	for _,child in ipairs(scene:GetChildren()) do
		if child:IsA("Model") then
			local cf,size=child:GetBoundingBox()
			local shadow=part(scene,"ContactShadow",Vector3.new(.025,size.X*.95,size.Z*.85),CFrame.new(cf.X,-.035,cf.Z)*CFrame.Angles(0,0,math.pi/2),colour);
			(shadow :: Part).Shape=Enum.PartType.Cylinder
		end
	end
	return scene
end
return Scenes
