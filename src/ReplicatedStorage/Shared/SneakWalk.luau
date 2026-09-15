--!strict
--[[
	SneakWalk

	The exaggerated tiptoe, built entirely in code.

	Everything the DodgeRoll header says about WHY this is an animation rather
	than a rotation applies here unchanged: this rig joins parts with
	AnimationConstraint rather than Motor6D, its C0 is READ ONLY, and rotating
	HumanoidRootPart directly drops the Humanoid into FallingDown within a
	frame. The animation system is the one thing allowed to drive these joints.

	WHY THERE WAS NO ANIMATION AT ALL, WHICH IS THE FAULT THIS FIXES.

	Sneakers is the fourth rung of the offence tree and Config.TIPTOE has been
	live for a long time, but a tiptoe was ONLY EVER A NUMBER: currentSpeed
	multiplied the walk down and the character went on playing the ordinary
	walk cycle, slower. So the one mechanic in this game whose whole point is
	that it looks different -- creeping onto somebody's lawn past a sleeping
	dog -- looked exactly like walking, and the only way to know it was on was
	to read the button.

	That is the same shape as the standing event countdown and the rap sheet:
	the mechanism was built, tuned and argued about at length, and nothing
	ever DREW it. It is the cheapest kind of thing to fix and the easiest to
	leave undone, because nothing errors.

	IT IS A LOOPING POSE, NOT A ONE-SHOT, AND THAT CHANGES TWO THINGS.

	The dodge plays once and stops itself, so DodgeRoll can keep its tracks in
	a weak-keyed table and the worst a dropped entry costs is a leaked track.
	A looping pose cannot afford that: if the collector drops the entry, the
	next call loads a SECOND copy and plays it on top of the first, and two
	copies of one pose blend into a pose that is subtly wrong and drifts.
	This project already has that measured -- five copies stacked on one rider
	inside a second -- which is why RidePose asks the Animator what it is
	playing instead of remembering.

	So tracks are found by asking the Animator. That is authoritative, immune
	to the collector and to a respawn, and it UNWINDS a stack that somehow
	appears rather than merely trying to avoid one.

	AND THE CYCLE IS DRIVEN BY MOVEMENT, NEVER BY A CLOCK.

	The officer's stride is a function of distance travelled and cannot
	desync from the movement it depicts, because it IS the movement. A tiptoe
	wants the same treatment for a sharper reason: the sneak speed is not one
	number. Config.TIPTOE runs from base to max across the Sneakers rung, and
	every other slow in the game multiplies underneath it. A fixed playback
	rate would have a maxed sneaker skating and a snagged one marching on the
	spot.

	Rate comes off the character's ACTUAL horizontal speed, so the upgrade
	rung, a fence snag and a stun are all inherited with no balance code in
	here at all -- and a sneaker standing still keeps a slow shift on their
	toes rather than freezing mid-step. See RATE_FLOOR.
]]

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local SneakWalk = {}

-- One full cycle is TWO steps, left and right.
--
-- Slow on purpose. A tiptoe is the one gait in this game meant to read as
-- deliberate, and much of the exaggeration is in how long a knee stays up --
-- which is a function of this number as much as of the angles below.
SneakWalk.DURATION = 1.15

-- WHAT A REAL SNEAK SPEED IS, used only to normalise the playback rate.
--
-- The cycle is authored to look right at roughly the BASE tiptoe, so a fully
-- upgraded sneaker plays it faster rather than covering more ground per step
-- -- which is what that rung actually buys. Sneakers is written up as
-- "crossing the same lawn in less time", never as a longer stride.
local REFERENCE_SPEED = Config.TIPTOE.base * Config.BASE_WALK_SPEED

-- A STATIONARY SNEAKER STILL MOVES, and that is why the rate is floored
-- rather than allowed to reach zero.
--
-- At zero the track holds whatever pose it stopped on, and for a cycle with
-- a 68-degree knee lift in it that is one leg in the air, indefinitely -- a
-- character frozen mid-step reads as a hitch rather than as a hold. A slow
-- shift on the toes is what somebody poised in the middle of a lawn actually
-- does, and it keeps the tell alive for anybody watching them do it.
local RATE_FLOOR = 0.12

-- HOW FAR THE BODY RISES ONTO ITS TOES, and this is a fix rather than a
-- flourish -- without it the gait puts a foot through the floor.
--
-- MEASURED: at phase 0.750 the PLANTED foot (ankle 30, leg nearly straight)
-- reached 0.318 studs BELOW the ground, against a standing baseline of
-- +0.006. That is not a tuning slip, it is arithmetic: the humanoid holds
-- the root a fixed HipHeight above the floor and knows nothing about the
-- animation, so rotating a toe downward can only drive it into the ground.
-- Every pointed-toe gait has to answer this.
--
-- THE ANSWER IS THE ONE THE REAL GAIT USES: you are TALLER on your toes. A
-- translation on LowerTorso carries the legs with it, because they are its
-- children in the pose hierarchy -- so the whole body rises, the ankle takes
-- the toe back down to the ground, and what is left is a raised heel, which
-- is exactly the picture wanted.
--
-- IT IS NOT ROOT MOTION AND THE RULE STILL HOLDS. The root's own pose stays
-- at identity; this moves the BODY relative to the root, which is the same
-- thing DodgeRoll's `lift` does to keep a somersaulting head out of the
-- grass. The character does not travel an inch.
--
-- 0.33 is the measured 0.318 plus a little, checked against the WORST phase
-- rather than an average -- the bob below is zero at phase 0.750, so that
-- reading was already the deepest the cycle gets.
local TOE_RISE = 0.33

-- ============================================================
-- WHICH WAY EACH JOINT TURNS
-- ============================================================
--
-- MEASURED ON A LIVE RIG, ONE AXIS AT A TIME. Not inherited, not inferred,
-- and not reasoned from field names -- all three of those were tried here
-- first and two of them were wrong.
--
-- The sweep: pose exactly ONE joint at +40 and -40 with every other joint on
-- the path a passthrough, then read the limb's endpoint back in ROOT space
-- (-Z is forward, since a character's front is its LookVector). Whatever
-- moves is attributable to that joint alone. Reproduce it before changing
-- any number here.
--
--   hipFlex   POSITIVE swings the foot forward   +40 -> fwd +0.65
--   knee      NEGATIVE folds the shin back       -40 -> fwd -0.69
--   armPitch  POSITIVE raises the arm forward    +40 -> fwd +0.81 up +0.72
--   hipPitch  NEGATIVE leans the torso forward   -40 -> head fwd +1.67
--   ankle     NEGATIVE points the TOES DOWN      see below
--
-- TWO OF THESE CAME OUT AGAINST A CONFIDENT GUESS, AND BOTH GUESSES LOOKED
-- WELL SOURCED. The first draft took all five from DodgeRoll's tuck; three
-- were backwards. The second took them from RidePose's header, which is
-- genuinely verified -- and TWO OF THOSE ARE STILL WRONG HERE:
--
--   * ANKLE. RidePose's convention list does not name it, so it was inferred
--     from every ride posing a flat-surface foot at a small POSITIVE value:
--     a rest foot already flat would want zero, so positive "must" be toes
--     down. Measured, positive is toes UP -- +40 puts the toe 0.55 studs
--     ABOVE the heel. The rides dorsiflex slightly because their shins are
--     angled forward over a pedal, which is the opposite of what the
--     inference assumed and reads identically in the numbers.
--
--   * ELBOW. RidePose says negative bends the arm in, and that is true IN
--     ITS CONTEXT -- its arms are already pitched near horizontal reaching
--     for handlebars. From an arm pitched 52 degrees it inverts: measured in
--     UpperTorso space, elbow +78 puts the hand up +0.82 and forward, and
--     elbow -78 puts it DOWN -1.05, which is arms hanging at the sides and
--     indistinguishable from no pose at all.
--
-- THE LESSON IS THE ONE THIS FILE KEEPS RE-LEARNING FROM A NEW DIRECTION: A
-- SIGN CONVENTION IS NOT A PROPERTY OF A JOINT, IT IS A PROPERTY OF A JOINT
-- IN A POSE. An elbow's world direction depends on where the shoulder
-- already put it, so a convention measured in one pose can be exactly
-- backwards in another -- and it will look like a plausible table either
-- way. Measure the COMBINATION you are actually using, not the joint.
local HIP_FORWARD = 1
local KNEE_FOLD = -1
local ANKLE_POINT = -1
local ARM_FORWARD = 1
local ELBOW_BEND = 1
local LEAN_FORWARD = -1

-- ============================================================
-- THE CYCLE
-- ============================================================
--
-- ONE LEG, DESCRIBED ONCE, and the other is the same curve half a cycle
-- later. Writing the two out separately is how a walk ends up subtly
-- asymmetric with nothing to point at, and it doubles every future tuning
-- edit.
--
-- hip:   + lifts the knee FORWARD and up
-- knee:  + folds the shin BACK toward the buttock
-- ankle: + points the TOES DOWN, which is the whole gait
--
-- The exaggeration lives in two places and both are deliberate:
--
--   * THE KNEE COMES UP TO 68 DEGREES at the top of the swing, roughly twice
--     what a walk does. That single pose is what reads as "tiptoe" from the
--     pavement, which is why the swing gets a whole quarter of the cycle
--     rather than being passed through on the way to the next plant.
--
--   * THE HEEL NEVER COMES DOWN. The ankle stays past 20 degrees at every
--     phase INCLUDING the plant, so there is no frame in the loop where the
--     character stands flat. A cycle that touched the heel down would read
--     as a careful walk, which is precisely what this replaces.
local LEG = {
	-- phase, hip, knee, ankle
	{ 0.00, 34, 14, 22 }, -- the toe reaches out and takes the weight
	{ 0.25, 6, 6, 30 }, -- weight rolls over it, leg long, heel at its highest
	{ 0.50, -22, 26, 42 }, -- push off, toe trailing behind
	{ 0.75, 68, 96, 34 }, -- KNEE UP: the pose the whole gait exists for
	{ 1.00, 34, 14, 22 },
}

local function legAt(phase: number): (number, number, number)
	local p = phase % 1
	for i = 1, #LEG - 1 do
		local a, b = LEG[i], LEG[i + 1]
		if p >= a[1] and p <= b[1] then
			local span = b[1] - a[1]
			local f = if span > 0 then (p - a[1]) / span else 0
			return a[2] + (b[2] - a[2]) * f,
				a[3] + (b[3] - a[3]) * f,
				a[4] + (b[4] - a[4]) * f
		end
	end
	return LEG[1][2], LEG[1][3], LEG[1][4]
end

local TAU = math.pi * 2

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

-- Eight samples plus the closing frame. The leg curve has its keys on the
-- quarters and both legs are half a cycle apart, so every one of those keys
-- lands exactly on a sample; the body's sinusoids are what the extra
-- resolution is actually for.
local STEPS = 8

local function buildSequence(): KeyframeSequence
	local seq = Instance.new("KeyframeSequence")
	seq.Name = "SneakWalk"
	seq.Loop = true
	-- MOVEMENT, WHICH IS WHAT OVERRIDES THE DEFAULT WALK.
	--
	-- Roblox's own Animate script plays idle, walk and run at Core, so a
	-- Movement track sits on top of all three and no part of that script has
	-- to be disabled or fought. That matters rather than being tidy:
	-- RideService already disables Animate for its own reasons, and two
	-- systems switching one script off is how it ends up switched off for
	-- somebody who is not riding.
	--
	-- It also loses to Action, deliberately and in both directions -- a dodge
	-- still reads while sneaking, and a rider's pose still wins if the two
	-- ever coexist.
	seq.Priority = Enum.AnimationPriority.Movement

	for i = 0, STEPS do
		local phase = i / STEPS

		local keyframe = Instance.new("Keyframe")
		keyframe.Time = phase * SneakWalk.DURATION

		-- Identity, always. A pose that moved the root would be a second,
		-- parallel way to travel -- the thing Config.DODGE's "a multiplier,
		-- never an impulse" rule exists to prevent -- and here it would also
		-- break the rate control below, which reads the character's real
		-- speed and would end up reading its own animation.
		local root = pose("HumanoidRootPart", CFrame.new(), keyframe)

		-- TWO TERMS, DOING TWO DIFFERENT JOBS. `TOE_RISE` is the standing
		-- height of somebody up on their toes and is what keeps the pointed
		-- foot out of the ground; the sine on top is the BOB, two per cycle
		-- because there are two toes to rise onto. Small -- it is a creep,
		-- not a skip -- and it is deliberately smaller than the rise, so the
		-- body never comes back down off its toes mid-step.
		local lift = TOE_RISE + 0.10 * math.sin(phase * TAU * 2)
		-- ONE SWAY PER CYCLE, as the weight moves onto the standing leg and
		-- back. This is most of what makes the gait read as exaggerated
		-- rather than as a slow walk, and it costs one term.
		local sway = 7 * math.sin(phase * TAU)

		local lower = pose("LowerTorso",
			CFrame.new(0, lift, 0)
				* CFrame.Angles(math.rad(17 * LEAN_FORWARD), 0, math.rad(sway)),
			root)

		-- Shoulders counter-rotate against the hips, which is what a real
		-- gait does and what stops the upper body reading as a plank bolted
		-- onto the legs.
		local upper = pose("UpperTorso",
			CFrame.Angles(math.rad(6 * LEAN_FORWARD), math.rad(-8 * math.sin(phase * TAU)), 0),
			lower)

		-- Head pulled down into the shoulders. A tiptoe is a posture before
		-- it is a gait, and this is the cheapest half of it.
		pose("Head", CFrame.Angles(math.rad(9), 0, 0), upper)

		for _, side in ipairs({ "Left", "Right" }) do
			-- OUTWARD IS LEFT-NEGATIVE, MEASURED: at roll -14 the left hand
			-- sits 1.55 studs off centre against a torso half-width of 0.65,
			-- and at +14 it comes in to 1.36. The first draft had this the
			-- other way round, which rolled both hands INTO the chest they
			-- were meant to be held in front of.
			local sign = if side == "Left" then -1 else 1
			local offset = if side == "Left" then 0 else 0.5

			-- ARMS HELD UP AND BENT -- the cat-burglar pose -- with a small
			-- alternating swing so they are not a frozen prop being carried
			-- about. Rolled outward a little so the hands sit in FRONT of
			-- the chest rather than inside it.
			local swing = 10 * math.sin((phase + offset) * TAU)
			local arm = pose(side .. "UpperArm",
				CFrame.Angles(math.rad((52 + swing) * ARM_FORWARD), 0, math.rad(14 * sign)),
				upper)
			local lowerArm = pose(side .. "LowerArm",
				CFrame.Angles(math.rad(78 * ELBOW_BEND), 0, 0), arm)
			passthrough(side .. "Hand", lowerArm)

			local hip, knee, ankle = legAt(phase + offset)
			local leg = pose(side .. "UpperLeg",
				CFrame.Angles(math.rad(hip * HIP_FORWARD), 0, 0), lower)
			local lowerLeg = pose(side .. "LowerLeg",
				CFrame.Angles(math.rad(knee * KNEE_FOLD), 0, 0), leg)
			pose(side .. "Foot",
				CFrame.Angles(math.rad(ankle * ANKLE_POINT), 0, 0), lowerLeg)
		end

		keyframe.Parent = seq
	end

	return seq
end

-- Exposed so the `animdump` admin command can build the sequence for
-- uploading. It is the same function the runtime registration uses, so what
-- gets published is exactly what Studio has been playing.
SneakWalk.buildSequence = buildSequence

local animationId: string? = nil

local function getAnimationId(): string?
	if animationId then
		return animationId
	end

	-- AN UPLOADED ASSET FIRST, because registering one only works in Studio.
	-- `RegisterKeyframeSequence` hands back a Studio-local id and is refused
	-- in a live game, so a published server would play no sneak at all --
	-- and the tiptoe would go straight back to being a number with nothing on
	-- screen, which is the exact fault this file was written to fix.
	local uploaded = Config.animationId("sneak")
	if uploaded then
		animationId = uploaded
		return animationId
	end

	local ok, id = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(buildSequence())
	end)
	if not ok or type(id) ~= "string" then
		warn("[SneakWalk] could not register the tiptoe animation, and "
			.. "Config.ANIMATIONS.sneak is empty. In a published game this is "
			.. "expected -- upload the sequence and put its id there. ("
			.. tostring(id) .. ")")
		return nil
	end
	animationId = id
	return animationId
end

-- The track is found by NAME on the animator rather than remembered in a
-- table. See the header: a weak-keyed table whose entry the collector drops
-- would have the next call stack a second copy of a LOOPING pose on top of
-- the first, which blends into a pose that is wrong and drifts.
local TRACK_NAME = "SneakWalk"

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

-- Start or stop the tiptoe on one character's animator.
--
-- Idempotent in both directions, because the caller is an attribute watcher
-- and an attribute can be republished with the value it already had.
function SneakWalk.apply(animator: Animator, on: boolean)
	local existing = findTrack(animator)

	if not on then
		if existing then
			existing:Stop(0.2)
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
		warn("[SneakWalk] could not load the tiptoe: " .. tostring(track))
		return
	end

	track.Name = TRACK_NAME
	track.Priority = Enum.AnimationPriority.Movement
	track.Looped = true
	-- Faded in rather than snapped. Going from a walk to a full creep in one
	-- frame reads as a glitch, and 0.2 is comfortably shorter than the walk
	-- to anybody's fence.
	track:Play(0.2)
end

-- How fast the cycle should run, given how fast the character is ACTUALLY
-- moving. See the header: driven by the movement rather than by a clock, so
-- the upgrade rung, a fence snag and a stun are inherited without this file
-- knowing that any of them exist.
function SneakWalk.setRate(animator: Animator, studsPerSecond: number)
	local track = findTrack(animator)
	if not track then
		return
	end
	local rate = math.max(RATE_FLOOR, studsPerSecond / REFERENCE_SPEED)
	-- A track's SPEED is not its WEIGHT. A weight of zero is terminal on this
	-- engine and stops a track for good -- the trap RidePose.FLOOR exists for
	-- -- while a speed of zero merely pauses. It is floored above anyway, but
	-- for the look rather than for the engine, and the two must not be
	-- confused by anything editing this.
	track:AdjustSpeed(rate)
end

return SneakWalk
