--!strict
--[[
	DodgeRoll

	The somersault a dodge plays, built entirely in code.

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

-- Slow enough to read as a somersault rather than a twitch.
--
-- Longer than the 0.25s speed burst and the 0.5s of immunity on purpose.
-- A roll is a push off, a travel, and a landing, and only the first two
-- cover ground -- so the tail of the animation is the recovery, during
-- which you are moving normally and can be nabbed again. That is the
-- honest reading of it: the part of the roll that is still going when the
-- immunity ends is exactly the part that was never immune.
DodgeRoll.DURATION = 0.6

-- A full turn, in steps.
--
-- The intermediate frames are not decoration. Rotation between two poses is
-- interpolated the short way round, so a single keyframe at -360 is identical
-- to one at 0 and the character does nothing at all. Each step has to be under
-- half a turn for the roll to go the way it is meant to.
--
-- `lean` is what makes it a shoulder roll rather than a straight forward flip:
-- it peaks a quarter of the way in and unwinds by the end, so the body goes
-- over one shoulder and lands square.
--
-- `lift` raises the body through the flip. Without it the whole rotation
-- happens about the hip and the head swings down THROUGH the grass at the
-- apex -- measured at 3.66 studs below the root, which is below the floor.
-- It also just looks right: you leave the ground to somersault.
--
-- Lifting is safe where translating the root would not be. This is the
-- body moving relative to the root, so the character itself still does not
-- move an inch -- measured at 0.0 studs travelled across a whole roll.
local FRAMES = {
	-- time (fraction), pitch (deg), lean (deg), tuck (0-1), lift (studs)
	{ 0.00, 0, 0, 0.0, 0.0 },
	{ 0.09, -70, -14, 0.9, 0.9 },
	{ 0.19, -165, -22, 1.0, 1.7 },
	{ 0.29, -260, -16, 0.8, 1.2 },
	{ 0.36, -320, -6, 0.4, 0.5 },
	{ 1.00, -360, 0, 0.0, 0.0 },
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
	-- unaffected either way -- the character keeps its 2.5x burst throughout.
	seq.Priority = Enum.AnimationPriority.Action

	for _, frame in ipairs(FRAMES) do
		local at, pitch, lean, tuck, lift = frame[1], frame[2], frame[3], frame[4], frame[5]

		local keyframe = Instance.new("Keyframe")
		keyframe.Time = at * DodgeRoll.DURATION

		-- Identity, always. See the note above about root motion.
		local root = pose("HumanoidRootPart", CFrame.new(), keyframe)

		local lower = pose("LowerTorso",
			CFrame.new(0, lift, 0) * CFrame.Angles(math.rad(pitch), 0, math.rad(lean)), root)

		-- Curls up as it goes over and opens out to land, which is the
		-- difference between a somersault and a plank being spun end over end.
		local upper = pose("UpperTorso", CFrame.Angles(math.rad(-18 * tuck), 0, 0), lower)
		passthrough("Head", upper)

		for _, side in ipairs({ "Left", "Right" }) do
			local arm = pose(side .. "UpperArm",
				CFrame.Angles(math.rad(-52 * tuck), 0, 0), upper)
			local lowerArm = pose(side .. "LowerArm",
				CFrame.Angles(math.rad(-64 * tuck), 0, 0), arm)
			passthrough(side .. "Hand", lowerArm)

			local leg = pose(side .. "UpperLeg",
				CFrame.Angles(math.rad(-64 * tuck), 0, 0), lower)
			local lowerLeg = pose(side .. "LowerLeg",
				CFrame.Angles(math.rad(72 * tuck), 0, 0), leg)
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
