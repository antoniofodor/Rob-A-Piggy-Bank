--!strict
--[[
	ThrowPose

	How a player THROWS a gadget: a wind-up, a release and a follow-through,
	built in code exactly the way DodgeRoll, SneakWalk and CarryPose are, and
	for the reasons DodgeRoll's header gives at length -- this rig's joints
	are AnimationConstraints whose `C0` is read only, and the animation system
	is the only thing allowed to drive them.

	WHAT THIS REPLACED. `GadgetService.throw` has always launched the
	projectile from a point two and a half studs above the root, and the
	character went on running with its arms swinging at its sides while a
	plunger appeared out of the air beside its head. Same fault as the tiptoe
	and the carry: a mechanism built, tuned and argued about at length --
	ballistic flight, an arc preview, a miss that costs -- with nothing ever
	DRAWING it. A throw nobody can see being thrown is a throw nobody can
	read from the pavement, and reading things from the pavement is what this
	game is made of.

	IT IS AN UPPER-BODY POSE, LIKE THE CARRY, AND ACTION PRIORITY, LIKE THE
	DODGE. A defender throwing at a running thief is usually running too, so
	the legs keep their cycle: root and LowerTorso are on the path at
	`Weight = 0` (see CarryPose for the measurement that decided that). It sits
	at Action so it plays IN FULL over the carry hug and the run -- a thief who
	throws a smoke bomb mid-getaway should visibly throw it -- and a dodge
	roll, also Action, simply restarts on top if somebody rolls mid-throw,
	which is fine: the projectile has already left.

	IT IS HELD. Pressing plays the wind-up and the clip PARKS at `WINDUP_AT`
	with the arm drawn back for as long as the button stays down; letting go
	runs the rest of it. One clip, one upload: the hold is the track's speed
	going to zero at a time, not a second animation. A quick click is just a
	cock released before it has parked, so it plays straight through.

	THE RELEASE INSTANT IS EXPORTED, AND THE SERVER WAITS FOR IT. The
	projectile is real and server-owned, so the server launches it when this
	clip would be letting go -- `RELEASE_AT - WINDUP_AT` after the release if
	the arm was already back, the whole `RELEASE_AT` after a click that never
	parked. That is what makes the object leave the hand rather than the air
	beside the head.

	NO POWER METER, AND THAT IS A DECISION. `Config.THROW.speed` is fixed
	because the lead a player learns -- how far somebody moves while it is in
	the air -- is only learnable if it never changes per throw. Holding buys
	time to AIM, never distance.

	EVERY CLIENT PLAYS ITS OWN COPY off the state the server publishes on the
	character (`Config.THROW_ANIMATION_ATTRIBUTE`), the same way the dodge
	roll does -- a registered `hash://` id cannot replicate, and a cocked arm
	is a tell everybody on the street is meant to see. The LOCAL player is
	driven straight from input instead, so their own arm never waits a ping.
]]

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ThrowPose = {}

-- Seconds from the start of the clip to the instant the hand lets go. The
-- server launches the projectile at exactly this offset; move one and move
-- the other, because they are one moment.
ThrowPose.WINDUP_AT = 0.14
ThrowPose.RELEASE_AT = 0.26
ThrowPose.DURATION = 0.55

-- How long after the RELEASE the projectile leaves, given how long the arm
-- was held back. The server times the launch with this and the local client
-- times its predicted flight with it, so the two agree by construction.
function ThrowPose.launchDelay(heldFor: number): number
	return math.max(ThrowPose.RELEASE_AT - ThrowPose.WINDUP_AT,
		ThrowPose.RELEASE_AT - math.max(0, heldFor))
end

-- ============================================================
-- THE POSE
-- ============================================================
--
-- The conventions, MEASURED ON THIS POSE by sweeping one axis at a time on a
-- live rig and reading the right hand back in root space (-Z is forward; see
-- CarryPose for why they are stated per pose and never assumed):
--
--   pitch   positive swings the arm FORWARD and up, negative swings it BACK
--           (Rx(-100) alone puts the right hand at root-space z +2.15)
--   roll    positive abducts the RIGHT arm out to the side (+X); it is
--           mirrored below so "out" means out on the left as well
--   yaw     rotates the arm about its own length; barely moves the hand
--   elbow   positive folds the forearm
--   torso   positive leans BACK
--   twist   positive brings the RIGHT shoulder FORWARD (z -0.74 at +30), so
--           a right-handed wind-up is a NEGATIVE twist and the release is a
--           positive one
--
-- The arm is composed as Rx(pitch) * Rz(roll), which is what `CFrame.Angles`
-- produces with a zero yaw: measured, Rx(-100) * Rz(35) lands the hand at
-- (1.68, 1.04, 1.99) -- behind, out, shoulder height, which is a javelin
-- wind-up -- where the other order buries it beside the ribs.
--
-- The right arm throws. A javelin wind-up is the arm drawn back and UP at
-- shoulder height with the body turned side-on and the other arm pointing
-- at the target; the release whips the arm over the top and the body turns
-- through; the follow-through lets it fall. Four keyframes, and the first and
-- last are identity so the clip blends in from and out to whatever the legs
-- and the carry hug are already doing.
type Frame = {
	at: number,
	torso: number, twist: number, head: number,
	right: { pitch: number, roll: number, yaw: number, elbow: number },
	left: { pitch: number, roll: number, yaw: number, elbow: number },
}

local FRAMES: { Frame } = {
	{ at = 0.00, torso = 0, twist = 0, head = 0,
		right = { pitch = 0, roll = 0, yaw = 0, elbow = 0 },
		left = { pitch = 0, roll = 0, yaw = 0, elbow = 0 } },
	-- WIND-UP: arm straight back at shoulder height, elbow out so the prop
	-- clears the ribs, body turned toward the throwing side and leaning
	-- back, the off hand up and forward as a sight.
	{ at = 0.14, torso = 10, twist = -28, head = -6,
		right = { pitch = -100, roll = 35, yaw = 0, elbow = 12 },
		left = { pitch = 62, roll = 18, yaw = 0, elbow = 8 } },
	-- RELEASE: arm whipped over the top and out in front, body turned
	-- through and leaning into it, off arm swept down and back.
	{ at = ThrowPose.RELEASE_AT, torso = -14, twist = 22, head = 4,
		right = { pitch = 125, roll = 12, yaw = 0, elbow = 4 },
		left = { pitch = -28, roll = 14, yaw = 0, elbow = 20 } },
	-- FOLLOW-THROUGH: the arm falling, the body coming back up.
	{ at = 0.40, torso = -6, twist = 8, head = 0,
		right = { pitch = 46, roll = 10, yaw = 0, elbow = 34 },
		left = { pitch = -10, roll = 8, yaw = 0, elbow = 12 } },
	{ at = ThrowPose.DURATION, torso = 0, twist = 0, head = 0,
		right = { pitch = 0, roll = 0, yaw = 0, elbow = 0 },
		left = { pitch = 0, roll = 0, yaw = 0, elbow = 0 } },
}

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

local function angles(x: number?, y: number?, z: number?): CFrame
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end

local function buildSequence(): KeyframeSequence
	local seq = Instance.new("KeyframeSequence")
	seq.Name = "ThrowPose"
	seq.Loop = false
	seq.Priority = Enum.AnimationPriority.Action

	for _, frame in ipairs(FRAMES) do
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = frame.at

		-- WEIGHT 0 on the two path joints, or the pelvis freezes for the
		-- length of the throw. Measured in CarryPose; same rig, same answer.
		local root = pose("HumanoidRootPart", CFrame.new(), keyframe, 0)
		local lower = pose("LowerTorso", CFrame.new(), root, 0)

		local upper = pose("UpperTorso", angles(frame.torso, frame.twist, 0), lower, 1)
		-- The head counter-turns so the thrower keeps looking at the target
		-- while the shoulders wind up behind them.
		pose("Head", angles(frame.head, -frame.twist * 0.7, 0), upper, 1)

		for _, side in ipairs({ "Left", "Right" }) do
			local s = if side == "Left" then frame.left else frame.right
			-- Roll is mirrored so "out" means out on both sides: positive
			-- abducts the RIGHT arm (measured), so the left takes the negative.
			local rollSign = if side == "Left" then -1 else 1
			local arm = pose(side .. "UpperArm",
				angles(s.pitch, s.yaw * rollSign, s.roll * rollSign), upper, 1)
			local lowerArm = pose(side .. "LowerArm", angles(s.elbow, 0, 0), arm, 1)
			pose(side .. "Hand", CFrame.new(), lowerArm, 1)
		end

		keyframe.Parent = seq
	end

	return seq
end

-- Exposed for the `animdump` admin command: what gets uploaded is exactly
-- what Studio has been playing.
ThrowPose.buildSequence = buildSequence

local animationId: string? = nil

local function getAnimationId(): string?
	if animationId then
		return animationId
	end

	-- AN UPLOADED ASSET FIRST. `RegisterKeyframeSequence` is Studio-only, so
	-- a live server with an empty row plays no throw at all and the
	-- projectile goes back to appearing out of the air -- silently. `Main`
	-- names an empty row at startup for exactly that reason.
	local uploaded = Config.animationId("throw")
	if uploaded then
		animationId = uploaded
		return animationId
	end

	local ok, id = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(buildSequence())
	end)
	if not ok or type(id) ~= "string" then
		warn("[ThrowPose] could not register the throw animation, and "
			.. "Config.ANIMATIONS.throw is empty. In a published game this is "
			.. "expected -- upload the sequence and put its id there. ("
			.. tostring(id) .. ")")
		return nil
	end
	animationId = id
	return animationId
end

-- ============================================================
-- PLAYING IT
-- ============================================================

local TRACK_NAME = "ThrowPose"

-- One track per Animator, so a defender throwing every 1.5 seconds does not
-- leak one per throw. Weak-keyed -- safe HERE for the reason the DodgeRoll
-- notes: a dropped entry costs a leaked track, never a stacked pose, because
-- every entry point below looks for a PLAYING track by name first.
local tracks: { [Animator]: AnimationTrack } = setmetatable({}, { __mode = "k" }) :: any

-- Tracks that should park at the wind-up. Cleared on every release and
-- cancel, and swept of stopped tracks each frame.
local parking: { [AnimationTrack]: true } = {}

local function playing(animator: Animator): AnimationTrack?
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.Name == TRACK_NAME then
			return track
		end
	end
	return nil
end

local function load(animator: Animator): AnimationTrack?
	local existing = tracks[animator]
	if existing then
		return existing
	end
	local id = getAnimationId()
	if not id then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.Name = TRACK_NAME
	animation.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok or not track then
		warn("[ThrowPose] could not load the throw: " .. tostring(track))
		return nil
	end
	track.Name = TRACK_NAME
	track.Priority = Enum.AnimationPriority.Action
	track.Looped = false
	tracks[animator] = track
	return track
end

-- Draw the arm back and hold it there. Idempotent: an arm already moving is
-- left alone.
function ThrowPose.cock(animator: Animator)
	if playing(animator) then
		return
	end
	local track = load(animator)
	if not track then
		return
	end
	track:Play(0.05)
	track:AdjustSpeed(1)
	parking[track] = true
end

-- Let go. A parked arm finishes the throw; an arm that was never drawn back
-- plays the whole clip. Idempotent against an arm already throwing.
function ThrowPose.release(animator: Animator)
	local track = playing(animator)
	if track then
		parking[track] = nil
		track:AdjustSpeed(1)
		return
	end
	track = load(animator)
	if not track then
		return
	end
	parking[track] = nil
	track:Play(0.05)
	track:AdjustSpeed(1)
end

-- Lower the arm without throwing: put away, refused, or abandoned. Only a
-- parked or still-winding arm is lowered; one already throwing finishes.
function ThrowPose.cancel(animator: Animator)
	local track = playing(animator)
	if track and parking[track] then
		parking[track] = nil
		track:Stop(0.15)
	end
end

-- The park itself. Polled rather than hung off a keyframe marker: a marker
-- can be stepped past on a long frame, and a poll cannot.
local function park()
	for track in pairs(parking) do
		if not track.IsPlaying then
			parking[track] = nil
		elseif track.TimePosition >= ThrowPose.WINDUP_AT then
			track:AdjustSpeed(0)
			track.TimePosition = ThrowPose.WINDUP_AT
		end
	end
end

-- ============================================================
-- WHO IS THROWING
-- ============================================================
--
-- Watches every OTHER character's state and poses them. In its own module
-- rather than in `ClientMain`, which is at Luau's 200-register ceiling.

local function animatorOf(character: Model): Animator?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end
	return humanoid:FindFirstChildOfClass("Animator")
end

-- The local player's animator, for ThrowAim, which drives it from input.
function ThrowPose.localAnimator(): Animator?
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	return if character then animatorOf(character) else nil
end

local function applyState(character: Model)
	local state = character:GetAttribute(Config.THROW_ANIMATION_ATTRIBUTE)
	-- Looked up when it fires, never at spawn: at CharacterAdded the Animator
	-- has often not replicated, and a nil captured then is permanent.
	local animator = animatorOf(character)
	if typeof(state) ~= "string" or not animator then
		return
	end
	local kind = string.sub(state, 1, 1)
	if kind == "c" then
		ThrowPose.cock(animator)
	elseif kind == "t" then
		ThrowPose.release(animator)
	else
		ThrowPose.cancel(animator)
	end
end

local function watch(character: Model, isLocal: boolean)
	if isLocal then
		-- The local player's arm is driven from input (see ThrowAim). An echo
		-- would be harmless on a fast link and a SECOND throw on a slow one,
		-- where the local clip has already finished by the time it lands.
		return
	end
	character:GetAttributeChangedSignal(Config.THROW_ANIMATION_ATTRIBUTE):Connect(function()
		applyState(character)
	end)
end

function ThrowPose.start()
	local function follow(player: Player)
		local isLocal = player == Players.LocalPlayer
		if player.Character then
			watch(player.Character, isLocal)
		end
		player.CharacterAdded:Connect(function(character)
			watch(character, isLocal)
		end)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		follow(player)
	end
	Players.PlayerAdded:Connect(follow)
	RunService.Heartbeat:Connect(park)
end

return ThrowPose
