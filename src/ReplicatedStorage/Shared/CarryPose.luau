--!strict
--[[
	CarryPose

	How a thief carries the load they are running off with -- a sack of coins
	or somebody's piggy -- built entirely in code, the same mechanism as
	DodgeRoll, SneakWalk and RidePose, for the same reasons.

	Everything the DodgeRoll header says about WHY this is an animation rather
	than a joint write applies here unchanged: this rig joins parts with
	AnimationConstraint rather than Motor6D, its `C0` is READ ONLY, and the
	animation system is the one thing allowed to drive these joints.

	TWO CARRIES, ONE PER KIND OF LOAD (designer, 2026-09-23: "the carry
	animation of the pig to be one and the other when robbing coins to be the
	animation of the bag over the shoulder").

	A HAULED PIGGY IS HUGGED and A SACK OF COINS IS SLUNG. The hug is the
	two-armed front carry this file has always been -- solved on the 2.2-stud
	mini piggy, which is exactly what `PiggyHaulService` hauls -- and the sling
	is the one-armed shoulder carry it wore for part of a day before the hug
	came back: the sack over the right shoulder, the right hand up on its
	neck, the LEFT ARM ABSENT from the sequence so the run goes on swinging
	it. The day the hug came back it replaced the sling for BOTH loads; the
	designer's answer was that each load wants its own, and this file carries
	both as `KINDS`.

	WHICH ONE PLAYS IS A FACT ON THE LOAD, NOT A FLAG BESIDE IT. The loot
	model carries `Config.CARRY_KIND_ATTRIBUTE` ("hug" or "sling"), written by
	the service that built it in the same breath as the weld, so the picture
	on every client and the seat the server pivoted into are one answer. A
	model with no attribute is hugged, which is what the pig always was.

	WHAT THE SLING SPENDS, stated as it was when it lost the whole carry: it
	moves the sack round BEHIND the thief, where being seen carrying it -- the
	risk half of a robbery -- is worth least. It is accepted here for the
	sack only, on the designer's call, and the piggy stays out in front in
	both arms where it can be read from the pavement.

	AND BOTH LOADS ARE WELDED TO THE RIGHT HAND, through one `anchor` that
	takes the kind. See `KINDS[kind].handHold`.

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
	plays in full rather than as half a carry. Both directions are deliberate.
	(A tiptoe is Movement too and would collide; it cannot, because a tiptoe is
	refused outright while carrying -- see `Config.TIPTOE`.)

	AND THE TWO JOINTS IT ONLY NEEDS AS A PATH CARRY `Weight = 0`.

	A Pose is found by walking the hierarchy, so reaching an arm means naming
	HumanoidRootPart and LowerTorso on the way -- and a named pose at full
	weight OVERRIDES whatever the run was doing with that joint. Measured, with
	them at the default weight of 1 the pelvis froze solid: LowerTorso read
	(0.0, 0.0, 0.0) at y -0.79 on every sample of a run, so the legs swung
	underneath a body with no bob and no sway in it at all.

	At `Weight = 0` the same samples read the run's own pelvis back -- measured
	again for this pose at carry speed, LowerTorso travelling 0.37 studs
	vertically over a stride -- while both arms stay pinned to this pose. So
	the two questions are genuinely separable, and the answer is a property
	rather than a compromise.

	AND WHAT THAT USED TO COST IS PAID FOR BY THE HAND WELD RATHER THAN LIVED
	WITH. While the load was welded to the ROOT it stood perfectly still while
	both arms rode the pelvis, so the palms slid against it -- measured at carry
	speed (`WalkSpeed` 12, which is `CARRY_SPEED_MULTIPLIER` on the base walk)
	the right palm travels 0.16 studs across, 0.34 up and 0.37 forward IN ROOT
	SPACE, and at a sprint (24) it is 0.22 / 0.56 / 0.73. (An earlier write-up
	of this said 0.037, which was an idle figure dressed up as a running one.)

	Welded to the HAND there is no slide in that direction at all: the load and
	the right palm are one rigid body. WHAT IS LEFT IS THE POSE'S OWN SETTLE --
	the arms give `SETTLE` degrees across the cycle, so the seat measured in
	hand space wanders 0.037 studs against the root-space `HOLD` it is solved to
	reproduce, which is a twentieth of the load's own width. The LEFT palm is
	posed to that same drift, so it tracks the flank it is on rather than
	sliding off it.

	EVERY CLIENT PLAYS ITS OWN COPY, because a `hash://` id is local to the
	peer that registered it and cannot replicate. Nothing is published to say
	who is carrying: the loot MODEL is already parented to the character, so
	its presence is the question -- see `ClientMain`. That is the call
	`RideSound` already makes about asking the mounted model rather than a
	label describing it, and here it buys the property that matters for free:
	the load and the pose cannot disagree about whether somebody is carrying,
	because they are the same fact.
]]
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local CarryPose = {}

-- ============================================================
-- THE POSES
-- ============================================================
--
-- MEASURED ON A LIVE RIG, ONE AXIS AT A TIME -- and re-measured on that rig
-- the day the hug came back, rather than taken on trust from the old write-up.
-- The numbers below are where a sweep landed rather than where anything was
-- typed, and the way to change one is to reproduce it: apply the pose, read the
-- hands back in ROOT space (-Z is forward, +X is the thief's own right), then
-- move the LOAD to whatever comes back.
--
-- The conventions, as they behave IN THIS POSE -- which is not the same thing
-- as how they behave in any other, and SneakWalk's header explains at length
-- why that distinction has already cost this project two confident tables:
--
--   armPitch  positive raises the arm forward and up
--   armRoll   abducts -- it swings the elbow OUT, away from the ribs -- and is
--             MIRRORED, so it is negative on the left and positive on the
--             right. That mirroring is why the two rows carry opposite signs
--             and why neither sign means the same thing on both arms
--   armYaw    mirrored the same way; it rotates the shoulder in, bringing the
--             hand back toward the centre line while the elbow stays roughly
--             where it was put
--   elbow     positive folds the forearm back toward the shoulder
--   torso     positive leans BACK, which is what a load held in front does
--   head      positive drops the chin
--
-- THE ELBOWS ARE OUT BECAUSE OTHERWISE NOTHING READS, and that is the whole
-- reason for the roll/yaw pair. It was arrived at by photographing the obvious
-- version first: the load is wider than a torso 1.30 studs across, so from the
-- front it OCCLUDES THE ENTIRE UPPER BODY. The first pose brought the arms in
-- around it -- correct anatomy, hands measured onto its flanks -- and rendered
-- as a load stuck to somebody's chest with no arms visible anywhere on the
-- character. A hug only reads if part of the arm is outside the silhouette of
-- the thing being hugged.
--
-- So the shoulder abducts to put the forearm outboard of the load's flank and
-- then rotates in to bring the hand back onto it. Elbows outside it, hands on
-- it. Re-measured on the live rig at exactly these numbers: hands land at
-- (+-1.216, 0.688, -1.219) and forearms at (+-1.285, 0.403, -0.582), which
-- reproduces the figures this pose first shipped with (+-1.22, 0.60, -1.22 and
-- +-1.29, 0.32, -0.58) to a thousandth of a stud across and forward. The y
-- reads 0.08 higher than the old note, which is the pelvis at a different
-- phase rather than a different pose; it is the axis `HOLD` is least sensitive
-- to and the one the chest already pins.
--
-- WHY THE HANDS ARE NOT WRAPPED FURTHER ROUND, since that is the obvious
-- question: they cannot be. A hand on the FAR side of a load this size held
-- against the chest sits about 2.15 studs from its own shoulder, against a
-- fully extended reach of about 2.08 -- so there is no pose that gets there,
-- and the load cannot come closer because it is already touching the chest.
-- Gripping the flanks is not a compromise on a hug; it is what carrying
-- something this size actually looks like.
local HUG_SPEC = {
	torso = 6,
	head = 4, -- cancels the lean, so a thief still looks where they are running
	left = { armPitch = 10, armYaw = -30, armRoll = -45, elbow = 50 },
	right = { armPitch = 10, armYaw = 30, armRoll = 45, elbow = 50 },
}

-- THE SLING: the right upper arm raised forward and out, the forearm folded
-- back over the shoulder so the hand lands just behind and above it, on the
-- sack's neck; the torso and head a few degrees of counter-lean; and NO LEFT
-- ARM -- it is not in the sequence, so the run swings it, by the same
-- mechanism that leaves the legs to the run.
--
-- SWEPT ON A LIVE RIG AND THEN PHOTOGRAPHED, because the numbers the sling
-- first shipped on (armPitch 115, armYaw -25, elbow 88) were re-measured on
-- the day the two carries split and put the hand at (1.77, 0.81, -0.12) in
-- root space -- a hand held out beside the ribs at chest height, with the
-- shoulder at (0.61, 0.34, 0). That is a bag carried at the hip, not over a
-- shoulder. Eight candidates were posed on a clone of the real character and
-- their hands read back; this one lands the hand at (0.89, 1.05, 0.55) --
-- 0.7 above the shoulder and half a stud behind it -- with the elbow forward
-- of it at (1.02, 0.83, -0.10), and two of the candidates were stood on the
-- lawn wearing the real sack and shot from the front, the side and behind.
local SLING_SPEC = {
	torso = -4,
	head = 3,
	left = nil,
	right = { armPitch = 80, armYaw = 40, armRoll = 30, elbow = 140 },
}

-- TWO KEYFRAMES, NOT ONE. A looping track with a single keyframe has zero
-- length, which the animation system handles badly, and a second frame is
-- free. Having one, making the two slightly different costs nothing: the run
-- drives the pelvis underneath (see the header), but a thief STANDING STILL is
-- on the idle, and this is what keeps the load shifting in their arms rather
-- than sitting there like a shop mannequin.
local DURATION = 1.9
local SETTLE = 3 -- degrees the arms give across the cycle, as if it were heavy

-- WHERE THE LOAD SITS, IN ROOT SPACE, DERIVED FROM THE HANDS RATHER THAN
-- CHOSEN.
--
-- This is the rule `RidePose` learned the hard way and states in its own
-- header: MOVE THE MACHINE TO THE HAND, NEVER THE HAND TO THE MACHINE. Posing
-- a thief to reach a load at a position somebody typed is an
-- inverse-kinematics problem with no solution the moment that position is out
-- of reach; placing the load where the hands measured always has one.
--
-- Measured on the shipped pose: hands land at (+-1.216, 0.688, -1.219) and
-- forearms at (+-1.285, 0.403, -0.582). So the load centres a little above the
-- hands and slightly ahead of them, which puts the palms on its flanks and just
-- behind its equator -- arms coming round from behind, which is the only
-- direction they can come round from.
--
-- THE z IS SET BY THE CHEST RATHER THAN BY THE HANDS. Measured with the real
-- seven-part sack seated here, the load's back face lands 0.12 studs INSIDE the
-- upper torso: hugged, rather than held out at arm's length. Further forward
-- and it floats; further back and it is inside them.
--
-- THIS IS THE HUG'S OWN SEAT RESTORED UNCHANGED, AND IT WAS SOLVED ON THE MINI
-- PIGGY -- which is still exactly what `PiggyHaulService` hauls, so that carry
-- is back on the geometry it was measured for. WHAT IS NEW UNDER IT IS THE COIN
-- SACK, so its fit here is measured rather than assumed:
--
--   * At Bigger Sack level 0 the sack spans root x [-1.03 1.03], y
--     [-0.96 2.33], z [-2.60 -0.39]. Its coin face lands at z -2.16 and the
--     snout mark at -2.26, so the decorated side reads to whoever the thief is
--     running AT -- which is exactly the half the shoulder sling gave away.
--   * THE PALMS SIT 0.20 STUDS OFF ITS FLANKS rather than 0.12 inside them.
--     The sack is 2.05 studs across against the mini piggy's 2.2, so a grip
--     solved on the pig lands just outside a sack. Stated rather than tuned
--     out: `HOLD` and the pose are one measurement, and moving either to close
--     a fifth of a stud re-opens both.
--   * The top of it rises past the chin -- y 2.33 against a head reaching 2.00
--     -- and clips the head's own box by 0.05 in z. That is what carrying
--     something this tall in both arms looks like, and it is the price of the
--     front carry.
--   * At level 4 the sack is 3.9 by 5.7 by 2.9, overruns the head by 1.05 in z
--     and reaches y 3.81, well above it: worse than the sling's 0.55 there, and
--     better at the other end, since it stays 0.78 studs off the ground where
--     the sling overran it by 0.17. A fixed `HOLD` and a load that doubles in
--     size cannot both be right; the one-line cap (`math.min(sackLevel, 1)` at
--     `buildLootBag`) is the designer's call.
--
-- WHAT HAS NOT BEEN LOOKED AT IS A PICTURE OF ANY OF IT. Every figure above is
-- a probe on a posed rig, and this file's own rule is that a probe answers "is
-- it there" while only a photograph answers "can it be seen".
--
-- The half turn is the one that was always here: a load is authored with its
-- front on +Z and a character's front is its LookVector, which is -Z, so
-- without it the load rides home facing its own thief. The 14 degrees of tilt
-- is the difference between a load being CARRIED and one being transported --
-- a perfectly level one reads as cargo on a shelf. Measured, it lays the sack's
-- long axis on (0, 0.97, -0.24), tipping its mouth toward the viewer.
--
-- THE SLING'S SEAT IS (1.31, 0.45, 0.04) WITH A -45/+90 TURN, which is a sack
-- over the right shoulder; see `KINDS.sling` below. Anything moving either
-- seat has to re-measure the hands, because a seat and its pose are one
-- decision.
CarryPose.HOLD = CFrame.new(0, 0.69, -1.50) * CFrame.Angles(math.rad(-14), math.pi, 0)

-- THE LOAD RIDES THE HAND, NOT THE ROOT (designer, 2026-09-23: "the carry
-- animation keeps the bag in place when it should be attached to the hand,
-- therefore moving with it"). `HOLD` is the seat in ROOT space -- the one frame
-- a server can pivot into before the pose has replicated, since the root never
-- animates -- but a weld to the root holds the load still while both arms bob
-- with the run, and the palms slide against it. `HAND_HOLD` is the SAME seat
-- expressed in the RIGHT HAND'S frame, so a weld to the hand lands the load
-- where `HOLD` did once the pose settles and then carries it with every swing.
-- The two are one measurement and move together: anything that re-measures
-- `HOLD` re-measures this in the same session, and this one was re-measured
-- the day the hug came back.
--
-- THE RIGHT HAND RATHER THAN THE LEFT, ON A POSE THAT USES BOTH, and the reason
-- is the mechanism rather than the picture: `anchor` has to hand ONE part back,
-- both carry services ask it, and a load welded to two hands is not something a
-- WeldConstraint can express. The choice is free BECAUSE the pose is mirrored
-- -- both palms are on the same load at the same drift, so welding to either
-- leaves the other on its far flank rather than drifting off it.
--
-- HOW IT WAS MEASURED, because the rig is the half that can be got wrong. A
-- clone of a real R15 character, parked nine thousand studs up and destroyed
-- afterwards, with this sequence registered and played on it: the rig's own
-- limb sizes are what these angles were solved against, and the default block
-- rig sitting in `ServerStorage.ANIMATION_UPLOAD_RIG` is NOT them: its upper
-- arm is 1.00 by 1.20 against a real character's 0.75 by 0.89, and the
-- IDENTICAL pose puts its palm 0.88 studs higher and 0.70 further forward --
-- a measurement of a different animal. Then 96 samples over one full
-- 1.9-second cycle of `hand.CFrame:ToObjectSpace(root.CFrame * HOLD)`, and the
-- mean of those is what ships.
--
-- THE SPREAD IS 0.037 STUDS AND 1.33 DEGREES, AND IT IS NOT NOISE: it is the
-- `SETTLE` drift, so it is the same number either way round -- a load welded
-- here reproduces `HOLD` to within 0.037 studs at every phase of the cycle,
-- which was measured end to end rather than inferred. Reproduced across two
-- runs to 0.0003 studs.
CarryPose.HAND_HOLD = CFrame.new(-0.696, -0.286, -0.995)
	* CFrame.fromOrientation(math.rad(87.6), math.rad(-39.0), math.rad(-166.8))

-- THE SLING'S SEAT, IN ROOT SPACE, DERIVED FROM THE HAND: the sack's neck
-- (its rope sits 0.76 above the cloth's centre along the sack's own up axis)
-- is put at the posed hand, so the cloth hangs from the fist down the back.
-- -35 about X tips the sack's up axis forward over the shoulder, which is
-- what lays the body down the BACK rather than down the front; +90 about Y
-- turns the coin OUTWARD to the thief's right, because the mesh authors it on
-- +Z and a half turn would put it into the back. The extra 0.5 on x moves the
-- cloth clear of the torso: measured against the upper torso's own box
-- (half-width 0.65) the inner face of a 1.53-deep sack seated straight under
-- the hand overlapped the shoulder by 0.4 studs; at +0.5 the overlap volume
-- reads 0.05 against the upper torso and 0.00 against the head, which is the
-- cloth pressed on the shoulder blade rather than through it. Anything
-- moving `SLING_SPEC` re-derives this, and `SLING_HAND_HOLD` with it.
CarryPose.SLING_HOLD = CFrame.new(1.38, 0.43, 0.99)
	* CFrame.Angles(math.rad(-35), math.rad(90), 0)

-- THE SAME SEAT IN THE RIGHT HAND'S FRAME, measured the way `HAND_HOLD` was:
-- a clone of the live character (never the block upload rig -- see
-- `HAND_HOLD`) parked nine thousand studs up with the sling playing, sampled
-- over one full cycle as `hand.CFrame:ToObjectSpace(root.CFrame *
-- SLING_HOLD)`. 122 samples over one 1.9-second cycle, spread 0.029 studs
-- (the `SETTLE` drift, as on the hug), the mean of which is what ships; the
-- posed hand itself reads (0.89, 1.05, 0.55) in root space standing still.
-- Re-measure this whenever `SLING_SPEC` or `SLING_HOLD` moves, because the
-- three are one decision.
CarryPose.SLING_HAND_HOLD = CFrame.new(0.053, 0.322, -0.847)
	* CFrame.fromOrientation(math.rad(-44.4), math.rad(111.7), math.rad(88.9))

-- THE TWO CARRIES, KEYED BY THE WORD THE LOOT MODEL CARRIES. `hug` is the
-- default and the piggy's; `sling` is the coin sack's. Each is a pose, a
-- root-space seat, a hand-space seat and the track name its animation plays
-- under, so the two can never be confused on one animator.
CarryPose.KINDS = {
	hug = { spec = HUG_SPEC, hold = CarryPose.HOLD, handHold = CarryPose.HAND_HOLD, track = "CarryPose" },
	sling = { spec = SLING_SPEC, hold = CarryPose.SLING_HOLD, handHold = CarryPose.SLING_HAND_HOLD, track = "CarryPoseSling" },
}
CarryPose.DEFAULT_KIND = "hug"

local function kindOf(kind: string?)
	return CarryPose.KINDS[kind or CarryPose.DEFAULT_KIND] or CarryPose.KINDS[CarryPose.DEFAULT_KIND]
end

-- WHERE A CARRIED THING IS WELDED AND SEATED: the right hand with that kind's
-- hand-space seat on an R15 rig, the root with its root-space seat on
-- anything without one. Both carry services (the coin sack in HeistService,
-- the hauled piggy in PiggyHaulService) ask this rather than each choosing a
-- limb, so the two loads can never ride different parts of the same
-- character. `kind` is the word the service will write on the model, and an
-- unknown one is the hug.
function CarryPose.anchor(character: Instance?, kind: string?): (BasePart?, CFrame)
	local k = kindOf(kind)
	if character then
		local hand = character:FindFirstChild("RightHand")
		if hand and hand:IsA("BasePart") then
			return hand, k.handHold
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			return root, k.hold
		end
	end
	return nil, k.hold
end

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

local function buildSequence(kind: string?): KeyframeSequence
	local k = kindOf(kind)
	local SPEC = k.spec
	local seq = Instance.new("KeyframeSequence")
	seq.Name = k.track
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

		-- BOTH ARMS on the hug, mirrored by the spec rather than by a sign flip
		-- here; the RIGHT ARM ONLY on the sling, whose spec carries no left row,
		-- so the run keeps that arm. The hands ARE named, at identity, so each
		-- posed wrist is pinned to its own forearm rather than inheriting
		-- whatever the run was doing with it. The legs are left out of both --
		-- see the header.
		for _, side in ipairs({ "Left", "Right" }) do
			local s = SPEC[string.lower(side)]
			if not s then
				continue
			end
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

-- Exposed so the `animdump` admin command can build the sequences for
-- uploading -- `buildSequence()` is the hug and `buildSequence("sling")` the
-- sling. It is the same function the runtime registers, so what gets
-- published is exactly what Studio has been playing.
CarryPose.buildSequence = buildSequence

-- One id per kind. The `Config.ANIMATIONS` row is `carry` for the hug and
-- `carrySling` for the sling.
local animationIds: { [string]: string } = {}
local ANIMATION_ROW = { hug = "carry", sling = "carrySling" }

local function getAnimationId(kind: string): string?
	if animationIds[kind] then
		return animationIds[kind]
	end

	-- AN UPLOADED ASSET FIRST, because registering one only works in Studio.
	-- `RegisterKeyframeSequence` hands back a Studio-local id and is refused
	-- live, so a published server with an empty row plays no carry pose at all
	-- -- and the load goes straight back to floating beside somebody with
	-- their arms at their sides, which is the exact fault this file exists to
	-- fix. `Main` names an empty row at startup for precisely that reason.
	local row = ANIMATION_ROW[kind] or "carry"
	local uploaded = Config.animationId(row)
	if uploaded then
		animationIds[kind] = uploaded
		return uploaded
	end

	local ok, id = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(buildSequence(kind))
	end)
	if not ok or type(id) ~= "string" then
		warn("[CarryPose] could not register the " .. kind .. " carry pose, and "
			.. "Config.ANIMATIONS." .. row .. " is empty. In a published game this is "
			.. "expected -- upload the sequence and put its id there. ("
			.. tostring(id) .. ")")
		return nil
	end
	animationIds[kind] = id
	return id
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
-- Both kinds' tracks are found by name; `findTrack` is asked per kind, so
-- the sling can be stopped while the hug is being started and neither can
-- stack on itself.
local function findTrack(animator: Animator, trackName: string): AnimationTrack?
	local found: AnimationTrack? = nil
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.Name == trackName then
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

-- Start the carry pose of one KIND on a character's animator, or stop every
-- carry pose on it (`on` false). Whichever kind is wanted, the other kind's
-- track is stopped: a thief who drops a hauled piggy and grabs a sack in the
-- same second changes carries rather than stacking them.
--
-- Idempotent in both directions, because the caller polls: a getaway lasts
-- several seconds and this is asked on every frame of it.
function CarryPose.apply(animator: Animator, on: boolean, kind: string?)
	local wanted = if on then (kindOf(kind).track) else nil
	local existing: AnimationTrack? = nil
	for _, k in pairs(CarryPose.KINDS) do
		local track = findTrack(animator, k.track)
		if track then
			if k.track == wanted then
				existing = track
			else
				-- Slower than the fade in, and that asymmetry is the point: a
				-- grab is a moment and wants to land, while a delivery hands
				-- the load over and the arms should come down AFTER it rather
				-- than with it.
				track:Stop(0.25)
			end
		end
	end

	if not on or existing then
		return
	end

	local want = kindOf(kind)
	local kindName = if CarryPose.KINDS[kind or ""] then (kind :: string) else CarryPose.DEFAULT_KIND
	local id = getAnimationId(kindName)
	if not id then
		return
	end

	local animation = Instance.new("Animation")
	animation.Name = want.track
	animation.AnimationId = id

	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok or not track then
		warn("[CarryPose] could not load the carry pose: " .. tostring(track))
		return
	end

	track.Name = want.track
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
-- shouldering a sack on their own screen and like they are jogging past one on
-- everybody else's would be advertising nothing at all.
--
-- Nothing here runs on the server. `HeistService` requires this module for
-- `HOLD` and never calls `start`.

-- Characters believed to be carrying, and WHICH carry: the value is the kind
-- read off the loot model's `Config.CARRY_KIND_ATTRIBUTE`. Keyed by the
-- Model, so a respawn needs no cleanup at all: the new character is a
-- different Model, and the old entry simply stops matching anything.
local carriers: { [Model]: string } = {}

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
	local loot = character:FindFirstChild(Config.LOOT_MODEL_NAME)
	if loot then
		-- THE KIND IS ON THE MODEL, written by the service that welded it. A
		-- model with no word is hugged, which is what the pig always was.
		local kind = loot:GetAttribute(Config.CARRY_KIND_ATTRIBUTE)
		carriers[character] = if type(kind) == "string" and CarryPose.KINDS[kind] then kind else CarryPose.DEFAULT_KIND
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
	-- empty-handed on this screen while shouldering a sack on every other one.
	-- Same trap the tiptoe records for a player who was already sneaking.
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
		for character, kind in pairs(carriers) do
			local animator = animatorOf(character)
			if character.Parent == nil or not animator then
				carriers[character] = nil
			else
				CarryPose.apply(animator, true, kind)
			end
		end
	end)
end

return CarryPose
