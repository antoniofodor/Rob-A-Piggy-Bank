local storage=game:GetService("ServerStorage")
local isolated=Instance.new("Folder") isolated.Name="WideInteriorIntegrationCheck" isolated.Parent=storage
local checks={}
local active
local function check(value,message) assert(value,message) table.insert(checks,message) end
local function frame(part) return CFrame.new(part.position[1],part.position[2],part.position[3],table.unpack(part.rotation)) end
local ok,err=xpcall(function()
for theme, data in DATA do
local SPEC, BUILDER_SOURCE=data.spec,data.builder
local testKit=Instance.new("Folder") testKit.Name=data.name testKit.Parent=isolated
	local templates = Instance.new("Folder")
	templates.Name = "Templates"
	templates.Parent = testKit
	for name, spec in SPEC.templates do
		local model = Instance.new("Model")
		model.Name = name
		model.Parent = templates
		local root = Instance.new("Part")
		root.Name = "Root"
		root.Size = Vector3.new(.15, .15, .15)
		root.Transparency = 1
		root.Anchored = true
		root.CanCollide = false
		root.CanQuery = false
		root.Parent = model
		model.PrimaryPart = root
		for mountName, at in spec.mounts do
			local attachment = Instance.new("Attachment")
			attachment.Name = mountName
			attachment.CFrame = frame(at)
			attachment.Parent = root
		end
		for _, data in spec.parts do
			local folder = model:FindFirstChild(data.group)
			if not folder then
				folder = Instance.new(if string.match(data.group, "^Panel_") or data.group == "Lock" then "Model" else "Folder")
				folder.Name = data.group
				folder.Parent = model
			end
			local part = Instance.new(if data.shape == "Wedge" then "WedgePart" else "Part")
			if part:IsA("Part") and data.shape == "Cylinder" then part.Shape = Enum.PartType.Cylinder end
			part.Name = data.name
			part.Size = Vector3.new(table.unpack(data.size))
			part.CFrame = frame(data)
			part.Anchored = true
			part.CanCollide = data.collide
			part.CanQuery = data.collide
			part.CanTouch = false
			part.CastShadow = false
			part.Transparency = data.transparency
			local rgb = SPEC.palette[data.material]
			part.Color = Color3.fromRGB(table.unpack(rgb))
			part.Material = Enum.Material.SmoothPlastic
			part.Parent = folder
			if data.name == "RequirementSign" then
				local gui = Instance.new("SurfaceGui")
				gui.Name = "RequirementGui"
				gui.Face = Enum.NormalId.Back
				gui.Parent = part
				local label = Instance.new("TextLabel")
				label.Name = "Requirement"
				label.Parent = gui
			end
		end
	end
	local module = Instance.new("ModuleScript")
	module.Name = "Builder"
	module.Source = BUILDER_SOURCE
	module.Parent = testKit

end
local registry={}
for _, data in DATA do registry[data.id]=data.name end
local module=Instance.new("ModuleScript") module.Name="ThemedInteriorCheck"
module.Source=WRAPPER_SOURCE:gsub('local ServerStorage = game:GetService%("ServerStorage"%)','local ServerStorage = script.Parent')
module.Source=module.Source:gsub('local Config = require%(ReplicatedStorage.Shared.Config%)','local Config = table.clone(require(ReplicatedStorage.Shared.Config)) Config.HOUSE_INTERIOR_KITS = game:GetService("HttpService"):JSONDecode([====['..game:GetService("HttpService"):JSONEncode(registry)..']====])')
module.Parent=isolated
local Themed=require(module)
local maxWidth,maxHeight=0,0
for _,data in DATA do maxWidth=math.max(maxWidth,data.spec.clearWidth) maxHeight=math.max(maxHeight,data.spec.ceilingHeight) end
local extent=Themed.footprint()
check(extent.Z>maxWidth and extent.Z<maxWidth+10,"Estate footprint includes the wider shell")
check(extent.Y>maxHeight,"Estate footprint includes the raised roof")
check(extent.X < require(game.ReplicatedStorage.Shared.Config).INDOOR_CAMERA.estateReach - 20, "Longest hall stays inside indoor camera region")
for _, data in DATA do
local id=data.id
local refs=Themed.build(isolated,CFrame.new(500,-10000,500)*CFrame.Angles(0,.6,0),{id=id},2)
active=refs.model
active:SetAttribute("CatalogueVerification",true)
Themed.setCapacity(refs,7)
check(refs.rooms==2 and #refs.plots==12,id..": two indexed rooms")
check(refs.capacity==7,id..": capacity retained")
check(#refs.doors==1,id..": one inter-room gate")
check(Themed.plotGround(refs,7)~=nil,id..": second room piggy ground")
check(refs.exit.Size.Y>10,id..": raised exit marker")
check(refs.exit.Size.Z>8,id..": widened exit marker")
local spacing=(Themed.plotGround(refs,1).Position-Themed.plotGround(refs,7).Position).Magnitude
check(math.abs(spacing-data.spec.roomLength)<.01,id..": template repeat length is respected")
refs.model.Parent=workspace
task.wait()
local rays=RaycastParams.new() rays.FilterType=Enum.RaycastFilterType.Include rays.FilterDescendantsInstances={refs.model}
for i=1,7 do
local ground=Themed.plotGround(refs,i)
for _,offset in {-.4,.4} do
local support=workspace:Raycast(ground.Position+ground.RightVector*offset+Vector3.new(0,2,0),Vector3.new(0,-4,0),rays)
check(support~=nil and math.abs(support.Position.Y-ground.Position.Y)<.06,id..": piggy feet rest on solid top "..i..":"..offset)
end
end
refs.model.Parent=isolated
Themed.setDoor(refs.doors[1],false)
Themed.setDoor(refs.doors[1],true)
refs.model:Destroy()
active=nil
end
end,debug.traceback)
if active then active:Destroy() end
isolated:Destroy()
return game:GetService("HttpService"):JSONEncode({passed=ok,count=#checks,checks=checks,error=if ok then nil else err})
