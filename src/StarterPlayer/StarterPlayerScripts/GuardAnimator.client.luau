local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Animation = require(game:GetService("ReplicatedStorage").Shared.GuardAnimation)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local active = {}
-- Each eye's authored size, remembered locally so a squashed (sleeping) eye
-- can be opened again.
local eyeSize = setmetatable({}, { __mode = "k" })
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
	-- BY DISTANCE (2026-09-23): fourteen dogs lerping every joint every frame
	-- for a camera that can see two of them. `Config.FX_CULL.guardRange` is
	-- the rule; a dog walking back into range catches its pose up over the
	-- same lerp it always used, so nothing snaps.
	local camera = workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else nil
	local range = (Config.FX_CULL and Config.FX_CULL.guardRange) or 120
	for model, record in pairs(active) do
		if not model:IsDescendantOf(workspace) then continue end
		if eye then
			local primary = model.PrimaryPart
			local at = if primary then primary.Position else model:GetPivot().Position
			if (at - eye).Magnitude > range then continue end
		end
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
			-- WRITTEN ONLY ON CHANGE: a property set to the value it already
			-- holds is still a property set, on every face of every dog,
			-- every frame.
			local wantColor = if hostile then (if eye then Color3.fromRGB(245,23,32) else mesh:GetAttribute("AngryBrowColor")) else mesh:GetAttribute("CalmColor")
			if wantColor and mesh.Color ~= wantColor then mesh.Color = wantColor end
			local wantMaterial = if hostile and eye then Enum.Material.Neon else Enum.Material.SmoothPlastic
			if mesh.Material ~= wantMaterial then mesh.Material = wantMaterial end
			if eye then
				-- Eyes shut while asleep: the eyeball squashed flat reads as a
				-- closed lid line.
				local open = eyeSize[mesh]
				if not open then
					open = mesh.Size
					eyeSize[mesh] = open
				end
				local want = if state == "Sleep" then Vector3.new(open.X, open.Y * 0.15, open.Z) else open
				if mesh.Size ~= want then
					mesh.Size = want
				end
			end
		end
	end
end)
