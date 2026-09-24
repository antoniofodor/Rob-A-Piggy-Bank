-- Standalone comparison place only: normal follow camera with a repeatable start.
local player = game:GetService("Players").LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart")
local humanoid = character:WaitForChild("Humanoid")
local reference = workspace:FindFirstChild("ScaleAvatar_DeleteMe", true)
if reference then reference:Destroy() end
task.wait(.3)
local camera = workspace.CurrentCamera
camera.FieldOfView = 70
camera.CameraSubject = humanoid
camera.CameraType = Enum.CameraType.Custom
camera.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 5, 13), root.Position + Vector3.new(0, 1, -8))
