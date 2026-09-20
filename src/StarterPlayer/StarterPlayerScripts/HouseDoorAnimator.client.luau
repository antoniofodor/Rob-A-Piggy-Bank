-- Cosmetic proximity doors. Static collision leaves every doorway open, so a
-- delayed client, streaming boundary or departing player cannot trap anyone.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local active = {}
local clock = 0
local function discover(part)
	if not part:IsA("BasePart") or not part.Name:match("^HouseDoorHinge_[LR]$") then return end
	if active[part] then return end
	active[part] = { parts = {}, alpha = 0, lastNear = -math.huge }
end
for _, part in workspace:GetDescendants() do discover(part) end
workspace.DescendantAdded:Connect(discover)
RunService.Heartbeat:Connect(function(dt)
	clock += dt
	local now = os.clock()
	local refresh = clock >= 0.1
	if refresh then clock = 0 end
	for hinge, state in active do
		if not hinge:IsDescendantOf(workspace) then active[hinge] = nil; continue end
		if refresh then
			local prefix = "HouseDoorLeaf_" .. hinge.Name:sub(-1)
			for _, part in hinge.Parent:GetDescendants() do
				if part:IsA("BasePart") and part.Name:sub(1, #prefix) == prefix and not state.parts[part] then
					state.parts[part] = hinge.CFrame:ToObjectSpace(part.CFrame)
				end
			end
			for _, player in Players:GetPlayers() do
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				if root then
					local delta = root.Position - hinge.Position
					if math.abs(delta.Y) < 7 and Vector2.new(delta.X, delta.Z).Magnitude < 10 then
						state.lastNear = now
						break
					end
				end
			end
		end
		local target = if now - state.lastNear < 1.5 then 1 else 0
		state.alpha += math.clamp(target - state.alpha, -dt / 0.35, dt / 0.35)
		local smooth = state.alpha * state.alpha * (3 - 2 * state.alpha)
		local angle = hinge:FindFirstChild("OpenDegrees")
		local degrees = if angle and angle:IsA("NumberValue") then angle.Value else 0
		local pose = hinge.CFrame * CFrame.Angles(0, math.rad(degrees) * smooth, 0)
		for part, closed in state.parts do
			if part:IsDescendantOf(hinge.Parent) then part.CFrame = pose * closed else state.parts[part] = nil end
		end
	end
end)
