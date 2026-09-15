--!strict
--[[
	CarryPose

	How a thief holds the piggy bank they are running off with, built entirely
	in code -- the same mechanism as DodgeRoll, SneakWalk and RidePose, for the
	same reasons.

	Everything the DodgeRoll header says about WHY this is an animation rather
	than a joint write applies here unchanged: this rig joins parts with
	AnimationConstraint rather than Motor6D, its `C0` is READ ONLY, and the
	animation system is the one thing allowed to drive these joints.

	WHAT THIS REPLACED, AND IT IS THE SAME FAULT THE TIPTOE HAD.

	`HeistService.attachLoot` has always welded a miniature of the victim's own
	piggy to the thief's root, two studs out in front of their chest -- which
	is the right idea, and it is what makes a chase legible from across the
	street. What was missing is the THIEF: the character went on playing the
	ordinary run cycle with their arms swinging at their sides, so the pig
	FLOATED in front of somebody who was visibly not holding it. Nobody carries
	anything by walking along behind it.

	That is the shape this file keeps recording -- a mechanism built, tuned and
	argued about at length, with nothing ever DRAWING it -- and the fix is the
	one SneakWalk already made for the tiptoe: a pose, so that the body agrees
	with what the game says is happening.

	IT IS AN UPPER-BODY POSE, AND THAT IS THE WHOLE DESIGN CONSTRAINT.

	A thief carrying loot is RUNNING HOME -- the getaway is the risk half of
	the entire trade -- so the legs must keep their run cycle. An animation
	only drives the joints it actually contains, so this one contains the
	torso, the head and both arms and NOT the legs: the run keeps them,
	underneath, with nothing switched off and nothing to fight.

	Which is why it is MOVEMENT priority rather than Action. Measured on a live
	character, the tracks Roblox's own Animate script has running are at Core
	and Idle -- both below Movement -- so this sits on top of the lot without
	that script having to be disabled or fought, which matters rather than
	being tidy: RideService already switches Animate off for its own reasons,
	and two systems switching one script off is how it ends up off for somebody
	who is doing neither. It still LOSES to Action, so a dodge roll mid-getaway
	plays in full rather than as half a hug. Both directions are deliberate.
	(A tiptoe is Movement too and would collide; it cannot, because a tiptoe is
	refused outright while carrying -- see `Config.TIPTOE`.)

	AND THE TWO JOINTS IT ONLY NEEDS AS A PATH CARRY `Weight = 0`.

	A Pose is found by walking the hierarchy, so reaching an arm means naming
	HumanoidRootPart and LowerTorso on the way -- and a named pose at full
	weight OVERRIDES whatever the run was doing with that joint. Measured, with
	them at the default weight of 1 the pelvis froze solid: LowerTorso read
	(0.0, 0.0, 0.0) at y -0.79 on every sample of a run, so the legs swung
	underneath a body with no bob and no sway in it at all.

	At `Weight = 0` the same samples read -4.1 to -11.0 degrees of pitch over y
	-0.699 to -0.993, which is the run's own pelvis coming back, while the arms
	stayed pinned to this pose. So the two questions are genuinely separable,
	and the answer is a property rather than a compromise.

	WHAT IT WAS EXPECTED TO COST is that the arms then ride the pelvis and the
	pig does not -- the pig is welded to the ROOT, which never animates, and
	that weld is not worth moving (see HOLD). So the hands should slide against
	a load that is holding perfectly still, and the write-up of this said "about
	a third of a stud", reasoned from how far the shoulder's own orientation
	swings over a stride.

	MEASURED, IT IS A TWENTIETH OF THAT, and the guess is recorded because it
	is the shape this project keeps having to correct: a number inferred from a
	real measurement of something ELSE, written up as though it had been taken.
	Sampled every frame of a run, the left palm's position IN THE PIG'S OWN
	FRAME travels 0.037 studs across, 0.033 up and 0.014 forward -- so the grip
	is effectively rigid and the whole worry was misplaced. (In the pig's frame
	rather than as a distance from its centre, deliberately: a radial reading
	would report a hand sweeping round the sphere as perfectly still.)

	EVERY CLIENT PLAYS ITS OWN COPY, because a `hash://` id is local to the
	peer that registered it and cannot replicate. Nothing is published to say
	who is carrying: the loot MODEL is already parented to the character, so
	its presence is the question -- see `ClientMain`. That is the call
	`RideSound` already makes about asking the mounted model rather than a
	label describing it, and here it buys the property that matters for free:
	the pig and the pose cannot disagree about whether somebody is carrying,
	because they are the same fact.
]]

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local CarryPose = {}

-- ============================================================
-- THE POSE
-- ============================================================
--
-- MEASURED ON A LIVE RIG, ONE AXIS AT A TIME. The numbers below are where a
-- sweep landed rather than where anything was typed, and the way to change one
-- is to reproduce that: apply the pose, read the hand back in ROOT space (-Z
-- is forward), then move the PIG to whatever comes back.
--
-- The conventions, as they behave IN THIS POSE -- which is not the same thing
-- as how they behave in any other, and SneakWalk's header explains at length
-- why that distinction has already cost this project two confident tables:
--
--   armPitch  positive raises the arm forward and up
--   armRoll   NEGATIVE abducts: it swings the elbow OUT, away from the ribs
--   armYaw    NEGATIVE rotates the shoulder in, bringing the hand back toward
--             the centre line while the elbow stays roughly where it was put
--   elbow     positive folds the forearm back toward the shoulder
--   torso     positive leans BACK, which is what a load held in front does
--   head      positive drops the chin
--
-- THE ELBOWS ARE OUT BECAUSE OTHERWISE NOTHING READS, and that is the whole
-- reason for the roll/yaw pair. It was arrived at by photographing the obvious
-- version first: the mini piggy is 2.2 studs across against a torso 1.30 wide,
-- so from the front it OCCLUDES THE ENTIRE UPPER BODY. The first pose brought
-- the arms in around it -- correct anatomy, hands measured onto its flanks --
-- and rendered as a pig stuck to somebody's chest with no arms visible
-- anywhere on the character. A hug only reads if part of the arm is outside
-- the silhouette of the thing being hugged.
--
-- So the shoulder abducts to put the forearm at x +-1.29, clear of the pig's
-- 1.10 radius, and then rotates in to bring the hand back to +-1.22 -- onto
-- the flank, with the palm about 0.12 studs inside the surface, which reads as
-- a grip rather than as a touch. Elbows outside it, hands on it.
--
-- WHY THE HANDS ARE NOT WRAPPED FURTHER ROUND, since that is the obvious
-- question: they cannot be. A hand on the FAR side of a pig this size held
-- against the chest sits about 2.15 studs from its own shoulder, against a
-- fully extended reach of about 2.08 -- so there is no pose that gets there,
-- and the pig cannot come closer because it is already touching the chest.
-- Gripping the flanks is not a compromise on a hug; it is what carrying
-- something this size actually looks like.
local SPEC = {
	torso = 6,
	head = 4, -- cancels the lean, so a thief still looks where they are running
	left = { armPitch = 10, armYaw = -30, armRoll = -45, elbow = 50 },
	right = { armPitch = 10, armYaw = 30, armRoll = 45, elbow = 50 },
}

-- TWO KEYFRAMES, NOT ONE. A looping track with a single keyframe has zero
-- length, which the animation system handles badly, and a second frame is
-- free. Having one, making the two slightly different costs nothing: the run
-- drives the pelvis underneath (see the header), but a thief STANDING STILL is
-- on the idle, and this is what keeps the load shifting in their arms rather
-- than sitting there like a shop mannequin.
local DURATION = 1.9
local SETTLE = 3 -- degrees the arms give across the cycle, as if it were heavy

-- WHERE THE PIG SITS, IN ROOT SPACE, DERIVED FROM THE HANDS RATHER THAN
-- CHOSEN.
--
-- This is the rule `RidePose` learned the hard way and states in its own
-- header: MOVE THE MACHINE TO THE HAND, NEVER THE HAND TO THE MACHINE. Posing
-- a thief to reach a pig at a position somebody typed is an inverse-kinematics
-- problem with no solution the moment that position is out of reach; placing
-- the pig where the hands measured always has one.
--
-- Measured on the shipped pose: hands land at (+-1.22, 0.60, -1.22) and
-- forearms at (+-1.29, 0.32, -0.58). So the body sphere centres a little above
-- the hands and slightly ahead of them, which puts the palms on its flanks and
-- just behind its equator -- arms coming round from behind, which is the only
-- direction they can come round from.
--
-- THE z IS SET BY THE CHEST RATHER THAN BY THE HANDS. At -1.50 the sphere's
-- back face sits at -0.40 against a chest front at -0.51, so the pig is
-- pressed into the thief by about a tenth of a stud: hugged, rather than held
-- out at arm's length. Further forward and it floats; further back and it is
-- inside them.
--
-- IT USED TO BE (0, 0.3, -2.1) -- two studs off the chest at hip height, which
-- is correct for a pig nobody is holding and comfortably out of reach of the
-- pose that now holds it. Anything moving this has to re-measure the hands,
-- because the two are one decision.
--
-- The half turn is the one that was always here: the mini is authored with its
-- snout at +Z and a character's front is its LookVector, which is -Z, so
-- without it the pig rides home facing its own thief. The 14 degrees of tilt
-- on top is new, and is the difference between a pig being CARRIED and a pig
-- being transported -- a perfectly level one reads as cargo on a shelf.
CarryPose.HOLD = CFrame.new(0, 0.69, -1.50) * CFrame.Angles(math.rad(-14), math.pi, 0)

-- ============================================================
-- BUILDING IT
-- ============================================================

local function pose(name: string, cf: CFrame, parent: Instance, weight: number): Pose
	local p = Instance.new("Pose")
	p.Name = name
	p.CFrame = cf
	p.Weight = weight
	p.EasingStyle = Enum.PoseEasingStyle.Linear
	p.EasingDirection = Enum.PoseEasingDirection.InOut
	p.Parent = parent
	return p
end

local function angles(x: number?, y: number?, z: number?): CFrame
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end

local function buildSequence(): KeyframeSequence
	local seq = Instance.new("KeyframeSequence")
	seq.Name = "CarryPose"
	seq.Loop = true
	-- See the header: over the walk, under a dodge.
	seq.Priority = Enum.AnimationPriority.Movement

	for i, at in ipairs({ 0, DURATION }) do
		local drift = i - 1

		local keyframe = Instance.new("Keyframe")
		keyframe.Time = at

		-- WEIGHT 0. These two exist only as the path to the arms, and at any
		-- weight above zero they hold the pelvis still for the whole getaway.
		-- Measured both ways; see the header.
		local root = pose("HumanoidRootPart", CFrame.new(), keyframe, 0)
		local lower = pose("LowerTorso", CFrame.new(), root, 0)

		local upper = pose("UpperTorso", angles(SPEC.torso, 0, 0), lower, 1)
		pose("Head", angles(SPEC.head, 0, 0), upper, 1)

		for _, side in ipairs({ "Left", "Right" }) do
			local s = SPEC[string.lower(side)]
			local arm = pose(side .. "UpperArm",
				angles(s.armPitch - SETTLE * drift, s.armYaw, s.armRoll), upper, 1)
			local lowerArm = pose(side .. "LowerArm",
				angles(s.elbow + SETTLE * drift, 0, 0), arm, 1)
			pose(side .. "Hand", CFrame.new(), lowerArm, 1)
		end

		keyframe.Parent = seq
	end

	return seq
end

-- Exposed so the `animdump` admin command can build the sequence for
-- uploading. It is the same function the runtime registers, so what gets
-- published is exactly what Studio has been playing.
CarryPose.buildSequence = buildSequence

local animationId: string? = nil

local function getAnimationId(): string?
	if animationId then
		return animationId
	end

	-- AN UPLOADED ASSET FIRST, because registering one only works in Studio.
	-- `RegisterKeyframeSequence` hands back a Studio-local id and is refused
	-- live, so a published server with an empty row plays no carry pose at all
	-- -- and the pig goes straight back to floating in front of somebody with
	-- their arms at their sides, which is the exact fault this file exists to
	-- fix. `Main` names an empty row at startup for precisely that reason.
	local uploaded = Config.animationId("carry")
	if uploaded then
		animationId = uploaded
		return animationId
	end

	local ok, id = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(buildSequence())
	end)
	if not ok or type(id) ~= "string" then
		warn("[CarryPose] could not register the carry pose, and "
			.. "Config.ANIMATIONS.carry is empty. In a published game this is "
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

-- The track is found by NAME on the animator rather than remembered in a
-- table. See RidePose's header at length: a weak-keyed table whose entry the
-- collector drops has the next call stack a SECOND copy of a looping pose on
-- top of the first, and two copies blend into a pose that is wrong and drifts
-- -- measured once at five copies on one rider inside a second. Asking the
-- animator is authoritative, immune to the collector and to a respawn, and it
-- UNWINDS a stack that somehow appears rather than merely avoiding one.
local TRACK_NAME = "CarryPose"

local function findTrack(animator: Animator): AnimationTrack?
	local found: AnimationTrack? = nil
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.Name == TRACK_NAME then
			if found then
				-- Exactly one survives. Stopping the extras is how a stack
				-- unwinds itself rather than needing to be prevented.
				track:Stop(0.1)
			else
				found = track
			end
		end
	end
	return found
end

-- Start or stop the carry pose on one character's animator.
--
-- Idempotent in both directions, because the caller polls: a getaway lasts
-- several seconds and this is asked on every frame of it.
function CarryPose.apply(animator: Animator, on: boolean)
	local existing = findTrack(animator)

	if not on then
		if existing then
			-- Slower than the fade in, and that asymmetry is the point: a grab
			-- is a moment and wants to land, while a delivery hands the pig
			-- over and the arms should come down AFTER it rather than with it.
			existing:Stop(0.25)
		end
		return
	end

	if existing then
		return
	end

	local id = getAnimationId()
	if not id then
		return
	end

	local animation = Instance.new("Animation")
	animation.Name = TRACK_NAME
	animation.AnimationId = id

	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok or not track then
		warn("[CarryPose] could not load the carry pose: " .. tostring(track))
		return
	end

	track.Name = TRACK_NAME
	track.Priority = Enum.AnimationPriority.Movement
	track.Looped = true
	track:Play(0.15)
end

-- ============================================================
-- WHO IS CARRYING
-- ============================================================
--
-- THE WATCHER LIVES HERE RATHER THAN IN `ClientMain`, AND THAT WAS MEASURED
-- RATHER THAN PREFERRED. Written inline over there it wanted five top-level
-- locals, and that chunk is at Luau's 200-register ceiling: the HUD refused to
-- compile with "Out of local registers when trying to allocate carriers" --
-- the whole HUD, not the pose. Started from here it is one statement holding
-- no local at all, which is the call `RobBadge` already makes.
--
-- It poses EVERY thief on the street, not just this client's own player. That
-- matters rather than being generous: the run home is the risk half of a
-- robbery and its entire job is being seen, so a thief who looks like they are
-- hugging a pig on their own screen and like they are jogging past one on
-- everybody else's would be advertising nothing at all.
--
-- Nothing here runs on the server. `HeistService` requires this module for
-- `HOLD` and never calls `start`.

-- Characters believed to be carrying. Keyed by the Model, so a respawn needs
-- no cleanup at all: the new character is a different Model, and the old entry
-- simply stops matching anything.
local carriers: { [Model]: true } = {}

local function animatorOf(character: Model): Animator?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end
	return humanoid:FindFirstChildOfClass("Animator")
end

-- THE QUESTION IS ASKED OF THE LOOT MODEL, NOT OF A FLAG.
--
-- `HeistService.attachLoot` parents the miniature to the character and the
-- drop destroys it, so its presence already IS "is this player carrying" --
-- replicated, and true on every client including one that joined halfway
-- through a getaway. A published attribute beside it would be a second answer
-- to a question that already has one, and two answers can disagree; this way
-- the pig and the pose are the same fact. Same call `RideSound` makes about
-- asking the mounted model rather than the label describing it.
local function refresh(character: Model)
	if character:FindFirstChild(Config.LOOT_MODEL_NAME) then
		carriers[character] = true
	else
		carriers[character] = nil
		local animator = animatorOf(character)
		if animator then
			CarryPose.apply(animator, false)
		end
	end
end

local function watch(character: Model)
	local function onChange(child: Instance)
		if child.Name == Config.LOOT_MODEL_NAME then
			refresh(character)
		end
	end
	character.ChildAdded:Connect(onChange)
	character.ChildRemoved:Connect(onChange)
	-- READ NOW as well as watched, because a character can arrive ALREADY
	-- carrying -- somebody who was mid-getaway before this client ever joined.
	-- The added signal would never fire for them, and they would run home
	-- empty-handed on this screen while hugging a pig on every other one. Same
	-- trap the tiptoe records for a player who was already sneaking.
	refresh(character)
end

function CarryPose.start()
	local function follow(player: Player)
		if player.Character then
			watch(player.Character)
		end
		player.CharacterAdded:Connect(watch)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		follow(player)
	end
	Players.PlayerAdded:Connect(follow)

	-- THE TRACK IS STARTED HERE RATHER THAN IN `refresh`, and that is the trap
	-- both the sneak and the dodge already record: at the moment the loot
	-- arrives the Animator may not have replicated yet, and a nil captured
	-- then means that thief is never posed again for the life of the
	-- character. Asking every frame is what makes this self-healing rather
	-- than dependent on winning a race -- and it is cheap, because `apply`
	-- returns early once its track is running and this loop only ever holds
	-- the handful of people actually carrying something.
	RunService.Heartbeat:Connect(function()
		for character in pairs(carriers) do
			local animator = animatorOf(character)
			if character.Parent == nil or not animator then
				carriers[character] = nil
			else
				CarryPose.apply(animator, true)
			end
		end
	end)
end

return CarryPose
