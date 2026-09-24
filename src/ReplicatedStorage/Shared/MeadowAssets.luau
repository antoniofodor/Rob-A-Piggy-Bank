--!strict
-- Server-authored scenery clones checked-in MeshParts; no runtime upload/loading calls.
local Assets = {}
local ServerStorage = game:GetService("ServerStorage")
function Assets.ready(): boolean
	local folder = ServerStorage:FindFirstChild("MeadowTemplates")
	return folder ~= nil and #folder:GetChildren() >= 31
end
function Assets.place(parent: Instance, name: string, at: CFrame, scale: number?, collides: boolean?): MeshPart
	local folder = assert(ServerStorage:FindFirstChild("MeadowTemplates"), "MeadowTemplates missing")
	local template = assert(folder:FindFirstChild(name), name .. " template missing") :: MeshPart
	local p = template:Clone()
	local s = scale or 1
	p.Size = template.Size * s
	p.CFrame = at * CFrame.new(template.Position * s) * template.CFrame.Rotation
	p.CanCollide = collides == true
	p.CanQuery = collides == true
	p.CanTouch = false
	p:SetAttribute("MeadowAsset", name)
	p.Parent = parent
	return p
end
return Assets
