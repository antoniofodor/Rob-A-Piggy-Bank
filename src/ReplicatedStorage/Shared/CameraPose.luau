--!strict
--[[
	CameraPose

	THE PAPARAZZI CATCH: whoever nabs the loot back raises a camera to their
	face, the flash goes off on the thief, and the camera comes down again.
	The VIP catch effect used to be a burst of white sparks on the thief with
	nobody holding anything; this is the half that makes it read as a
	PHOTOGRAPH rather than as a firework.

	Built in code exactly the way ThrowPose, CarryPose and DodgeRoll are, for
	the reasons those headers give: this rig's joints are AnimationConstraints
	whose `C0` is read only, and the animation system is the only thing
	allowed to drive them. Upper body only, with root and LowerTorso on the
	path at `Weight = 0`, so a catcher who is running keeps running.

	THE ANGLES WERE MEASURED, NOT REASONED. Swept on a live R15 rig and read
	back in HEAD space: upper-arm pitch 76, yaw 52 (mirrored), elbow 62 puts
	both hands at x +-0.42, y +0.06, z -0.95 -- either side of a camera held
	a stud in front of the face. The YAW is what brings the hands in; roll in
	either direction only swung them out past the shoulders (x 1.25 to 1.55),
	which is the trap to avoid if anybody retunes this.

	`CatchFX` owns the prop and the flash and times them off `SNAP_AT`; this
	file owns only the arms.
]]

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local CameraPose = {}

-- Seconds into the clip: the camera is up by RAISED_AT, the shutter goes at
-- SNAP_AT, and the arms are back down at DURATION. CatchFX times the flash
-- and the prop off these, so move them together.
CameraPose.RAISED_AT = 0.22
CameraPose.SNAP_AT = 0.45
CameraPose.LOWER_AT = 0.95
CameraPose.DURATION = 1.25

-- Where the camera sits in HEAD space, so the prop and the measured hands
-- agree: centred between them, a hair further out than the palms.
CameraPose.CAMERA_OFFSET = CFrame.new(0, 0.06, -1.05)

type Arm = { pitch: number, yaw: number, elbow: number }
type Frame = { at: number, head: number, arm: Arm }

local REST: Arm = { pitch = 0, yaw = 0, elbow = 0 }
local RAISED: Arm = { pitch = 76, yaw = 52, elbow = 62 }

local FRAMES: { Frame } = {
	{ at = 0, head = 0, arm = REST },
	{ at = CameraPose.RAISED_AT, head = -4, arm = RAISED },
	-- The shutter: a tiny dip of the head into the viewfinder.
	{ at = CameraPose.SNAP_AT, head = -7, arm = RAISED },
	{ at = CameraPose.LOWER_AT, head = -4, arm = RAISED },
	{ at = CameraPose.DURATION, head = 0, arm = REST },
}

local function angles(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

local function pose(name: string, cf: CFrame, parent: Instance, weight: number): Pose
	local p = Instance.new("Pose")
	p.Name = name
	p.CFrame = cf
	p.Weight = weight
	p.EasingStyle = Enum.PoseEasingStyle.Cubic
	p.EasingDirection = Enum.PoseEasingDirection.InOut
	p.Parent = parent
	return p
end

local function buildSequence(): KeyframeSequence
	local seq = Instance.new("KeyframeSequence")
	seq.Name = "CameraPose"
	seq.Loop = false
	seq.Priority = Enum.AnimationPriority.Action

	for _, frame in ipairs(FRAMES) do
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = frame.at
		-- WEIGHT 0 on the path joints, or the pelvis freezes. See CarryPose.
		local root = pose("HumanoidRootPart", CFrame.new(), keyframe, 0)
		local lower = pose("LowerTorso", CFrame.new(), root, 0)
		local upper = pose("UpperTorso", CFrame.new(), lower, 1)
		pose("Head", angles(frame.head, 0, 0), upper, 1)
		for _, side in ipairs({ "Left", "Right" }) do
			-- Yaw is mirrored so both hands turn IN toward the camera.
			local sign = if side == "Left" then -1 else 1
			local a = frame.arm
			local arm = pose(side .. "UpperArm", angles(a.pitch, a.yaw * sign, 0), upper, 1)
			local lowerArm = pose(side .. "LowerArm", angles(a.elbow, 0, 0), arm, 1)
			pose(side .. "Hand", CFrame.new(), lowerArm, 1)
		end
		keyframe.Parent = seq
	end
	return seq
end

-- Exposed for `animdump`: what gets uploaded is exactly what Studio plays.
CameraPose.buildSequence = buildSequence

local animationId: string? = nil

local function getAnimationId(): string?
	if animationId then
		return animationId
	end
	-- An uploaded asset first: `RegisterKeyframeSequence` is Studio-only, so a
	-- live server with an empty row flashes with no camera raised. `Main`
	-- names the empty row at startup.
	local uploaded = Config.animationId("cameraSnap")
	if uploaded then
		animationId = uploaded
		return animationId
	end
	local ok, id = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(buildSequence())
	end)
	if not ok or type(id) ~= "string" then
		warn("[CameraPose] could not register the camera pose, and "
			.. "Config.ANIMATIONS.cameraSnap is empty. In a published game this is "
			.. "expected -- upload the sequence and put its id there. (" .. tostring(id) .. ")")
		return nil
	end
	animationId = id
	return animationId
end

-- Plays the raise-snap-lower on one animator. A second catch while the first
-- is still up restarts it rather than stacking a track.
function CameraPose.play(animator: Animator)
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.Name == "CameraPose" then
			track:Stop(0)
		end
	end
	local id = getAnimationId()
	if not id then
		return
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok or not track then
		return
	end
	track.Name = "CameraPose"
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = false
	track:Play(0.08)
	track.Stopped:Connect(function()
		track:Destroy()
	end)
end

return CameraPose
