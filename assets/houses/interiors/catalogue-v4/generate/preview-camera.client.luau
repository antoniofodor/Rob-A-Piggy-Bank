-- Standalone comparison place only: normal follow camera with a repeatable start.
local player = game:GetService("Players").LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")
for _, reference in workspace:GetDescendants() do
    if reference.Name == "ScaleAvatar_DeleteMe" then reference:Destroy() end
end
task.wait(.3)
local camera = workspace.CurrentCamera
camera.FieldOfView = 70
camera.CameraSubject = humanoid
camera.CameraType = Enum.CameraType.Custom
camera.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 4, 10), root.Position + Vector3.new(0, 1, -8))
