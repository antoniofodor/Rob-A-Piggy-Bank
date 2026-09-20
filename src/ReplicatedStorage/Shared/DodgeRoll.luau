--!strict
--[[
	DodgeRoll

	The dive roll a dodge plays, built entirely in code.

	No uploaded asset and no third-party animation. `KeyframeSequenceProvider:
	RegisterKeyframeSequence` takes a KeyframeSequence assembled at runtime and
	hands back a hash:// id an Animator will play, which means the roll is
	generated the same way the ground, the houses and the piggies are -- a fresh
	place plus this repo still gives you the identical game. It also sidesteps
	the licensing problem the audio has: there is nothing here to be moderated
	away.

	WHY AN ANIMATION AND NOT A ROTATION.

	Two cheaper-looking approaches were tried against a real character first,
	and both are dead ends on this rig:

	  * Rotating the root joint's C0, the usual trick for spinning a body
	    without touching physics, is impossible -- this rig joins parts with
	    AnimationConstraint rather than Motor6D, and its C0 is READ ONLY.

	  * Rotating HumanoidRootPart directly puts the Humanoid into FallingDown
	    within a frame and it does not get back up: measured, the character was
	    still on its side a second and a half later, ten studs from where it
	    started. During a chase. The state machine owns that part's orientation
	    and will not share it.

	The animation system is the one thing allowed to drive these joints, which
	is what makes it the only mechanism that works rather than merely the
	tidiest.

	THE ROLL NEVER MOVES THE CHARACTER, AND THAT IS LOAD-BEARING.

	Every pose here is relative to HumanoidRootPart and the root's own pose is
	left at identity, so there is no root motion in it. Config.DODGE is explicit
	that a dodge must be a multiplier on currentSpeed and never an impulse or a
	nudge, because BASE_WALK_SPEED is what the carry penalty, the dog speeds,
	the fence snags and the getaway distance are all measured against. A roll
	that shifted the character even slightly would be exactly the second,
	parallel way to move that rule exists to prevent. Animate the body, never
	the root.

	EVERY CLIENT REGISTERS ITS OWN COPY.

	A hash:// id is local to the peer that registered it, so it cannot be
	replicated by playing the track on one machine and letting Roblox forward
	it. Instead the server publishes the fact of a dodge and each client plays
	the roll itself -- the same shape as animated skins, where the server
	publishes a SkinKey and every client computes the colours. It matters that
	other people see it: the dodge's real payload is the half second of
	immunity, and a defender who loses their tag hold to an invisible dodge has
	been beaten by something they never saw happen.
]]

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local DodgeRoll = {}

-- A DIVE ROLL, NOT A SOMERSAULT. It used to be one rigid body spun end over
-- end in the air with the limbs folded at a fixed ratio, which read as stiff:
-- nothing about it touched the ground. Now the body crouches, pushes off,
-- dives forward reaching for the ground, plants its hands with the hips high,
-- tucks its head and rolls across ONE SHOULDER and the back, and comes up
-- onto its feet in a crouch before standing. `Config.DODGE` owns the timing,
-- because the server hands out the get-up burst at the moment the feet land.
DodgeRoll.DURATION = Config.DODGE.rollSeconds

-- `lift` WAS SOLVED, NOT PICKED. Every key's lift is chosen so the lowest
-- part of the body sits at a set clearance -- hands on the ground at the
-- plant, the shoulder and back a few tenths off it through the roll, feet at
-- zero in the crouches -- by forward kinematics on the R15 proportions, with
-- the in-between poses swept at 400 points so nothing passes through the
-- floor between two keys (worst: a foot dipping 0.1 stud mid-crouch). The
-- pelvis traces a real arc: down into the crouch, up and over the planted
-- hands, down across the back, and up out of the landing crouch.
--
-- Signs follow RidePose's measured conventions: negative pitch is forward,
-- positive `hip` lifts the knee, negative `knee` folds the shin back,
-- positive `armP` raises the arm forward, negative `head` tucks the chin,
-- and negative `lean` rolls toward the character's right, so the roll goes
-- over the RIGHT shoulder.
--
-- NO WIND-UP, AND THE BODY IS THROWN AHEAD OF THE ROOT. The first version
-- opened with a crouch, which read as the player braking to a stop before
-- the roll -- while the dodge's speed window was already spent crouching. It
-- goes straight into the push-off now and leaves the ground by 0.08, and
-- `fwd` carries the body up to 1.6 studs AHEAD of the root in the dive, then
-- lets it settle back as the fast-moving root catches up. That is still the
-- body moving relative to the root: the character's own position is only
-- ever moved by `Config.DODGE`'s multiplier on currentSpeed, and that window
-- now spans the dive and the roll rather than the first quarter second.
--
-- The intermediate frames are still load-bearing: rotation interpolates the
-- short way round, so every step has to be under half a turn.
local FRAMES = {
	-- t,    pitch, lean, lift,  fwd,  curl, head, armP, elbow, hip,  knee
	{ 0.00,     0,    0,  0.00,  0.0,    0,    0,    0,     0,    0,     0 }, -- standing
	{ 0.07,   -35,   -2, -0.33, -0.4,   -5,   10,   80,   -15,   20,   -35 }, -- push off
	{ 0.19,   -68,   -8,  0.35, -1.6,    0,   20,  150,    -5,  -15,    -8 }, -- airborne dive
	{ 0.31,  -115,  -25,  0.74, -1.3,  -30,  -35,  125,   -85,   45,   -60 }, -- hands plant, hips high
	{ 0.38,  -150,  -45,  0.55, -1.0,  -40,  -45,  100,   -90,   90,  -110 }, -- onto the shoulder
	{ 0.46,  -195,  -50, -0.29, -0.7,  -45,  -45,   70,  -100,  120,  -135 }, -- across the back
	{ 0.54,  -240,  -40, -1.27, -0.5,  -45,  -40,   60,  -100,  125,  -140 },
	{ 0.62,  -285,  -25, -1.21, -0.3,  -35,  -25,   50,   -80,  120,  -135 }, -- hips over
	{ 0.72,  -325,  -10, -1.63, -0.1,  -20,  -10,   40,   -60,  105,  -120 }, -- feet down, crouched
	{ 0.86,  -350,   -3, -0.45,  0.0,   -8,    0,   15,   -25,   50,   -75 }, -- rising
	{ 1.00,  -360,    0,  0.00,  0.0,    0,    0,    0,     0,    0,     0 }, -- standing
}

local function pose(name: string, cf: CFrame, parent: Instance): Pose
	local p = Instance.new("Pose")
	p.Name = name
	p.CFrame = cf
	p.EasingStyle = Enum.PoseEasingStyle.Linear
	p.EasingDirection = Enum.PoseEasingDirection.InOut
	p.Parent = parent
	return p
end

-- An empty pose still has to exist for every joint between the root and
-- anything being animated, because a Pose is found by walking the hierarchy.
local function passthrough(name: string, parent: Instance): Pose
	return pose(name, CFrame.new(), parent)
end

local function buildSequence(): KeyframeSequence
	local seq = Instance.new("KeyframeSequence")
	seq.Name = "DodgeRoll"
	seq.Loop = false
	-- Action beats the running animation underneath it. Movement itself is
	-- unaffected either way -- the character keeps its dodge speed throughout.
	seq.Priority = Enum.AnimationPriority.Action

	for _, frame in ipairs(FRAMES) do
		local at, pitch, lean, lift, fwd = frame[1], frame[2], frame[3], frame[4], frame[5]
		local curl, head, armPitch, elbow, hip, knee =
			frame[6], frame[7], frame[8], frame[9], frame[10], frame[11]

		local keyframe = Instance.new("Keyframe")
		keyframe.Time = at * DodgeRoll.DURATION

		-- Identity, always. See the note above about root motion.
		local root = pose("HumanoidRootPart", CFrame.new(), keyframe)

		local lower = pose("LowerTorso",
			CFrame.new(0, lift, fwd) * CFrame.Angles(math.rad(pitch), 0, math.rad(lean)), root)
		local upper = pose("UpperTorso", CFrame.Angles(math.rad(curl), 0, 0), lower)
		pose("Head", CFrame.Angles(math.rad(head), 0, 0), upper)

		for _, side in ipairs({ "Left", "Right" }) do
			local arm = pose(side .. "UpperArm", CFrame.Angles(math.rad(armPitch), 0, 0), upper)
			local lowerArm = pose(side .. "LowerArm", CFrame.Angles(math.rad(elbow), 0, 0), arm)
			passthrough(side .. "Hand", lowerArm)

			local leg = pose(side .. "UpperLeg", CFrame.Angles(math.rad(hip), 0, 0), lower)
			local lowerLeg = pose(side .. "LowerLeg", CFrame.Angles(math.rad(knee), 0, 0), leg)
			passthrough(side .. "Foot", lowerLeg)
		end

		keyframe.Parent = seq
	end

	return seq
end

-- Exposed so the `animdump` admin command can build the sequence for
-- uploading. It is the same function the runtime registration uses, so what
-- gets published is exactly what Studio has been playing.
DodgeRoll.buildSequence = buildSequence

-- Registered once per client, not once per dodge. The id is a content hash, so
-- registering the identical sequence twice is wasted work rather than a bug.
local animationId: string? = nil

local function getAnimationId(): string?
	if animationId then
		return animationId
	end

	-- AN UPLOADED ASSET FIRST, because registering one only works in Studio.
	-- `RegisterKeyframeSequence` returns a temporary Studio-local id and is
	-- refused in a live game, so a published server plays no roll at all --
	-- the dodge still moves you at the right speed and the character simply
	-- never tumbles. See Config.ANIMATIONS.
	local uploaded = Config.animationId("dodgeRoll")
	if uploaded then
		animationId = uploaded
		return animationId
	end

	local ok, id = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(buildSequence())
	end)
	if not ok or type(id) ~= "string" then
		-- Never fail silently: without this the dodge still works and only the
		-- animation is missing, which is exactly the kind of half-broken that
		-- gets mistaken for a design decision.
		warn("[DodgeRoll] could not register the roll animation, and "
			.. "Config.ANIMATIONS.dodgeRoll is empty. In a published game this "
			.. "is expected -- upload the sequence and put its id there. ("
			.. tostring(id) .. ")")
		return nil
	end
	animationId = id
	return animationId
end

-- One track per Animator, kept so a player rolling every five seconds for an
-- hour does not leak a track a second. Weak-keyed, so a character leaving
-- takes its track with it.
local tracks: { [Animator]: AnimationTrack } = setmetatable({}, { __mode = "k" }) :: any

function DodgeRoll.play(animator: Animator)
	local existing = tracks[animator]
	if not existing then
		local id = getAnimationId()
		if not id then
			return
		end
		local animation = Instance.new("Animation")
		animation.Name = "DodgeRoll"
		animation.AnimationId = id

		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		if not ok or not track then
			warn("[DodgeRoll] could not load the roll: " .. tostring(track))
			return
		end
		existing = track
		tracks[animator] = existing
	end

	-- Restarted rather than layered. The cooldown is five seconds so this
	-- should never happen, but a track played on top of itself blends with
	-- itself and the roll comes out half-height.
	existing:Stop(0)
	existing:Play(0.05)
end

return DodgeRoll
