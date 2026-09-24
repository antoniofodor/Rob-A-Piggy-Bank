local storage=game:GetService("ServerStorage")
local isolated=Instance.new("Folder") isolated.Name="WideInteriorIntegrationCheck" isolated.Parent=storage
local checks={}
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
local module=Instance.new("ModuleScript") module.Name="ThemedInteriorCheck"
module.Source=WRAPPER_SOURCE:gsub('local ServerStorage = game:GetService%("ServerStorage"%)','local ServerStorage = script.Parent')
module.Parent=isolated
local Themed=require(module)
local extent=Themed.footprint()
check(extent.Z>60 and extent.Z<65,"Estate footprint includes the wider shell")
check(extent.Y>32,"Estate footprint includes the raised roof")
for _, id in {"shack","cottage","treehouse"} do
local refs=Themed.build(isolated,CFrame.new(500,-10000,500)*CFrame.Angles(0,.6,0),{id=id},2)
Themed.setCapacity(refs,7)
check(refs.rooms==2 and #refs.plots==12,id..": two indexed rooms")
check(refs.capacity==7,id..": capacity retained")
check(#refs.doors==1,id..": one inter-room gate")
check(Themed.plotGround(refs,7)~=nil,id..": second room piggy ground")
check(refs.exit.Size.Y>14,id..": raised exit marker")
check(refs.exit.Size.Z>12,id..": widened exit marker")
Themed.setDoor(refs.doors[1],false)
Themed.setDoor(refs.doors[1],true)
refs.model:Destroy()
end
end,debug.traceback)
isolated:Destroy()
return game:GetService("HttpService"):JSONEncode({passed=ok,count=#checks,checks=checks,error=if ok then nil else err})
