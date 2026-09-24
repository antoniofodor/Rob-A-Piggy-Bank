--!strict
--[[
	IndoorZoom

	Caps the local camera's zoom while the character is inside a house
	interior, so the camera cannot be wheeled out through a ceiling the
	popper does not stop at. `Config.INDOOR_CAMERA` says why and holds the
	numbers.

	WHERE, NOT WHEN. An interior is a detached hall on the indoor estate
	(`Config.INDOOR_ESTATE`, x 4000, against a street inside |x| 400), so
	"am I indoors" is a question about the character's position and not
	about which remote fired last. That is what makes it self-healing: a
	death inside, a kick, a respawn on the lawn or a crossing whose remote
	the client never saw all leave the character SOMEWHERE, and the cap
	follows the somewhere. The `DoorCross` remote is deliberately not read.

	THE OLD CAP IS PUT BACK, NOT A LITERAL. Whatever `CameraMaxZoomDistance`
	the place ships with (Roblox's 400 today) is what a player gets outside;
	a number typed here would be a second opinion about a StarterPlayer
	setting.

	A MODULE, FOR THE 200-LOCAL CEILING: required and started in one
	statement from ClientMain, holding no local there, the way DoorMask is.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local IndoorZoom = {}

local started = false

-- Is this position on the indoor estate? Exported so a suite can ask it
-- without a character.
function IndoorZoom.isIndoors(position: Vector3): boolean
	local estate = Config.INDOOR_ESTATE
	local reach = Config.INDOOR_CAMERA.estateReach
	return math.abs(position.X - estate.x) < reach
end

function IndoorZoom.start()
	if started then
		return
	end
	started = true

	local player = Players.LocalPlayer
	local outdoorCap: number? = nil
	local indoors = false
	local acc = 0

	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < Config.INDOOR_CAMERA.pollSeconds then
			return
		end
		acc = 0
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local here = root and root:IsA("BasePart") and IndoorZoom.isIndoors(root.Position) or false
		if here == indoors then
			return
		end
		indoors = here
		if here then
			outdoorCap = player.CameraMaxZoomDistance
			player.CameraMaxZoomDistance = Config.INDOOR_CAMERA.maxZoom
		elseif outdoorCap then
			player.CameraMaxZoomDistance = outdoorCap
			outdoorCap = nil
		end
	end)
end

return IndoorZoom
