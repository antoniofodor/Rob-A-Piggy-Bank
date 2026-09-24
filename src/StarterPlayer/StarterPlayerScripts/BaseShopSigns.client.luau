--!strict
-- SurfaceGui text can arrive blank when a parked hallway first replicates.
-- Refresh after its descendants arrive, also covering subsequent unpark cycles.
local RunService = game:GetService("RunService")
local pending: { [SurfaceGui]: boolean } = {}
local function refresh(instance: Instance)
	local gui = if instance:IsA("SurfaceGui") then instance else instance:FindFirstAncestorWhichIsA("SurfaceGui")
	if not gui or gui.Name ~= "ShopSign" or pending[gui] then return end
	pending[gui] = true
	task.spawn(function()
		RunService.Heartbeat:Wait()
		pending[gui] = nil
		if gui:IsDescendantOf(workspace) and gui.Enabled then
			gui.Enabled = false
			gui.Enabled = true
		end
	end)
end
workspace.DescendantAdded:Connect(refresh)
for _, instance in workspace:GetDescendants() do
	if instance:IsA("SurfaceGui") then refresh(instance) end
end
