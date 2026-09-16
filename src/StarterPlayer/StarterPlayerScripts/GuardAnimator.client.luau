local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Animation = require(game:GetService("ReplicatedStorage").Shared.GuardAnimation)
local active = {}
local function add(model)
	if active[model] then return end
	local record = { joints = {}, faces = {}, connection = nil }
	active[model] = record
	local function discover(d)
		if d:IsA("Motor6D") then record.joints[d] = true
		elseif d:IsA("MeshPart") and (d:GetAttribute("GuardTone") == "eye" or d:GetAttribute("GuardTone") == "brow") then record.faces[d] = true end
	end
	for _, d in model:GetDescendants() do discover(d) end
	record.connection = model.DescendantAdded:Connect(discover)
end
local function remove(model)
	local record = active[model]
	if record then record.connection:Disconnect(); active[model] = nil end
end
CollectionService:GetInstanceAddedSignal("AnimatedGuard"):Connect(add)
CollectionService:GetInstanceRemovedSignal("AnimatedGuard"):Connect(remove)
for _, model in CollectionService:GetTagged("AnimatedGuard") do add(model) end
RunService.PreSimulation:Connect(function(dt)
	local t = workspace:GetServerTimeNow()
	for model, record in pairs(active) do
		if not model:IsDescendantOf(workspace) then continue end
		local state = model.Parent:GetAttribute("GuardState") or "Idle"
		local height = model:GetAttribute("GuardHeight") or 2.5
		for joint in pairs(record.joints) do
			if joint.Parent then
				joint.Transform = joint.Transform:Lerp(Animation.pose(joint.Name, state, t, height), math.min(1, dt * 16))
			else record.joints[joint] = nil end
		end
		local hostile = state == "Chase" or state == "Attack"
		for mesh in pairs(record.faces) do
			if not mesh.Parent then record.faces[mesh] = nil; continue end
			local eye = mesh:GetAttribute("GuardTone") == "eye"
			mesh.Color = if hostile then (if eye then Color3.fromRGB(245,23,32) else mesh:GetAttribute("AngryBrowColor")) else mesh:GetAttribute("CalmColor")
			mesh.Material = if hostile and eye then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end
end)
