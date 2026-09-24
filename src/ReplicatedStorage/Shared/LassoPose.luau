--!strict
--[[
	LassoPose

	The seven character animations the lasso needs (docs/LASSO-PLAN.md,
	"Character animations"), built in code the way DodgeRoll, CarryPose and
	ThrowPose are and for their reasons: this rig's joints are
	AnimationConstraints whose `C0` is read only, so the animation system is
	the one thing allowed to drive them, and a sequence written here is a
	sequence nobody can moderate away.

	TWO SHAPES. `lassoTwirl` and `lassoThrow` are UPPER BODY ONLY, exactly the
	carry's shape: the legs are absent so the run keeps them, and the root and
	LowerTorso are on the path at `Weight = 0` (see CarryPose for the
	measurement -- at full weight the pelvis freezes for the whole run). The
	other five are FULL BODY, because each one IS a stance: planted and
	leaning back on a rope, a yank and a fist pump, a stumble, a shove, a
	crouch.

	NO ROOT MOTION, EVER. The root pose is identity in every keyframe. A crouch
	or a stumble moves the LOWERTORSO, which is the body leaving where it
	stood, never the character -- the line DodgeRoll and RidePose's `hipLift`
	already draw.

	FEET ARE SOLVED, NOT TYPED. A full-body frame names where each ANKLE
	should be (planted at rest, a step back, lifted) and `legs` works out the
	hip, knee and ankle angles by two-link IK against the pelvis the frame
	asks for. So a crouch keeps its feet on the grass by construction, and a
	pelvis moved in one frame cannot leave a foot floating in another. The
	leg lengths are ESTIMATES (below) and are the thing to re-measure on a
	live rig -- the carry's hand seat was once wrong by most of a stud because
	it was solved on the block upload rig rather than a real character.

	SIGN CONVENTIONS, as CarryPose and ThrowPose measured them and as the
	rotation matrices agree (CFrame.Angles is Rx * Ry * Rz):

	  torso/pelvis pitch  positive leans BACK
	  twist (torso yaw)   positive brings the RIGHT shoulder forward
	  torso/pelvis roll   positive tips the top toward the character's LEFT
	  head pitch          positive lifts the chin
	  arm pitch           positive swings the arm forward and up
	  arm roll / yaw      written as "out" and mirrored here: positive abducts
	                      either arm, and positive yaw brings an abducted arm
	                      round to the front
	  elbow               positive folds the forearm (0..150, never negative)
	  cone                spins the forearm about the upper arm's own axis at
	                      the elbow; the twirl is this going round
	  hipFlex / knee      solved: positive lifts the knee, negative folds the
	                      shin back (0..-150, never positive)

	ONE LASSO TRACK PER ANIMATOR, found BY NAME on the animator rather than
	remembered -- RidePose's header records a weak table dropping an entry
	and stacking five copies of one pose. Playing any lasso key stops every
	other one.

	AN UPLOADED ID FIRST, REGISTRATION SECOND. `RegisterKeyframeSequence` is
	Studio-only (CLAUDE.md: it took every animation in the game down live), so
	a key with an empty `Config.ANIMATIONS` row plays nothing on a published
	server: one warning per key, then quiet nils. `Main` names empty rows at
	startup.
]]
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local Config = require(script.Parent.Config)
local CarryPose = require(script.Parent.CarryPose)

local LassoPose = {}

LassoPose.KEYS = { "lassoTwirl", "lassoThrow", "lassoPull", "lassoWin", "lassoSnap", "knockedLoose", "scoopUp" }

-- ============================================================
-- THE RIG, AS FAR AS THE LEG SOLVER NEEDS IT
-- ============================================================
--
-- ROOT_JOINT_Y is MEASURED (RidePose: the body swings about the root joint's
-- attachment at root-space y -1.252). The rest are ESTIMATES scaled from the
-- default R15 proportions to this character's, chosen so the rest sole lands
-- at y -3.222 against the -3.225 that `HipHeight` 2.225 on a two-stud root
-- implies. An error here costs a crouched foot a few hundredths of a stud of
-- float or sink, never a pose; re-measure them before tuning a crouch deeper.
local ROOT_JOINT_Y = -1.252
local HIP_X = 0.45 -- hip joint, out from the centre line
local HIP_DOWN = 0.20 -- hip joint, below the root joint
local THIGH = 0.80 -- hip to knee
local SHIN = 0.82 -- knee to ankle

local REST_HIP_Y = ROOT_JOINT_Y - HIP_DOWN
local REST_ANKLE_Y = REST_HIP_Y - THIGH - SHIN

-- ============================================================
-- THE FRAMES
-- ============================================================
--
-- Every angle is degrees. A frame leaves out what stays at zero. `feet`
-- offsets are from the rest ankle: `f` forward, `out` away from the centre
-- line, `up` off the ground.

type Arm = { pitch: number?, yaw: number?, roll: number?, elbow: number?, cone: number? }
type Foot = { f: number?, out: number?, up: number? }
type Frame = {
	at: number,
	pelvis: { pitch: number?, yaw: number?, roll: number?, lift: number?, fwd: number?, side: number? }?,
	torso: { pitch: number?, twist: number?, roll: number? }?,
	head: { pitch: number?, yaw: number?, roll: number? }?,
	left: Arm?,
	right: Arm?,
	feet: { left: Foot?, right: Foot? }?,
	marker: string?,
}
type Def = { length: number, loop: boolean, legs: boolean, easing: Enum.PoseEasingStyle, frames: { Frame } }

-- THE HUG'S OWN ARMS, read off CarryPose rather than copied, so a scoop ends
-- on the exact pose the carry track underneath it is holding and the hand-off
-- is invisible. CarryPose writes them RAW (left roll and yaw negative); this
-- file writes them "out", so the left row is un-mirrored here.
local HUG = CarryPose.KINDS.hug.spec
local HUG_RIGHT: Arm = { pitch = HUG.right.armPitch, yaw = HUG.right.armYaw, roll = HUG.right.armRoll, elbow = HUG.right.elbow }
local HUG_LEFT: Arm = { pitch = HUG.left.armPitch, yaw = -HUG.left.armYaw, roll = -HUG.left.armRoll, elbow = HUG.left.elbow }

-- THE OVERHEAD TWIRL, shared by the twirl and the first frame of the throw so
-- one hands over to the other without a jump. It goes with the OPEN LOOP the
-- client spins round the fist while a lasso is out (`Lasso.client`, designer
-- 2026-09-23: "uncoiled and spinning when equipped"). For a few hours it was a
-- still "ready to throw" stance instead, because a forearm circling a coil
-- that stayed coiled read as an arm spinning for no reason; with a real loop
-- going round the hand the circle is the point again. The client plays it at
-- the loop's own rate, so arm and rope go round together.
--
-- THE WHOLE ARM GOES ROUND, NOT JUST THE FOREARM (designer, 2026-09-23: "the
-- arm segment from shoulder to elbow should be moving as well", and the hand
-- was clipping the head). The first version held the upper arm straight up
-- and circled only the forearm, so the fist swept across the top of the skull.
-- Now the arm is raised UP AND OUT to the side -- the circle's axis leans away
-- from the head -- and the UPPER ARM traces its own small cone about that axis
-- while the forearm circles in phase with it, so the shoulder drives the motion
-- the way a real twirl does and the fist stays beside the head, never over it.
-- `TWIRL_*` are that axis and the two radii, picked by sweeping them through
-- the suite's own kinematics: fist and elbow stay 1.13 studs from the head's
-- centre at their nearest, and the upper arm sweeps 0.45 of a unit direction.
local TWIRL_TORSO = { twist = -6, roll = -4 }
local TWIRL_HEAD = { pitch = 4, yaw = 4 }
local TWIRL_LEFT: Arm = { pitch = 10, roll = 14, elbow = 18 }
local TWIRL_PITCH, TWIRL_OUT = 178, 42 -- the axis: raised almost straight up, and out
local TWIRL_SWING = 13 -- how far the upper arm leaves that axis, degrees
local TWIRL_ELBOW = 50
local function twirlRight(cone: number): Arm
	local a = math.rad(cone)
	return {
		pitch = TWIRL_PITCH + TWIRL_SWING * math.cos(a),
		roll = TWIRL_OUT + TWIRL_SWING * math.sin(a),
		elbow = TWIRL_ELBOW,
		cone = cone,
	}
end

local function twirlFrames(): { Frame }
	-- EIGHT STEPS OF 45 DEGREES, because rotation interpolates the short way
	-- round: one key at 360 would be the same pose as 0 and the forearm would
	-- not move at all (DodgeRoll's note). Linear, so the hand goes round at
	-- one speed; the last frame equals the first, so the loop has no seam.
	local frames = {}
	for i = 0, 8 do
		table.insert(frames, {
			at = i / 8,
			torso = TWIRL_TORSO,
			head = TWIRL_HEAD,
			left = TWIRL_LEFT,
			right = twirlRight(45 * i),
		})
	end
	return frames
end

-- THE TUG-OF-WAR STANCE, shared by the pull loop and the first frame of the
-- win and the snap, so both start from exactly where the pull left off.
-- Pelvis tipped back 14 and dropped, feet planted wide and ahead of it (the
-- left one leading), torso back a further 10, both hands forward and low and
-- turned in onto one rope with the left hand in front.
local PULL_PELVIS = { pitch = 14, lift = -0.18 }
local PULL_FEET = { left = { f = 0.40, out = 0.22 }, right = { f = 0.12, out = 0.22 } }
local function pullFrame(at: number, tug: boolean): Frame
	return {
		at = at,
		pelvis = PULL_PELVIS,
		torso = { pitch = if tug then 17 else 10, twist = -8 },
		head = { pitch = if tug then -22 else -16, yaw = 6 },
		left = { pitch = if tug then 30 else 44, roll = -14, elbow = if tug then 44 else 24 },
		right = { pitch = if tug then 22 else 34, roll = -14, elbow = if tug then 54 else 34 },
		feet = PULL_FEET,
	}
end


-- Seconds into the throw at which the rope leaves the hand. The `Release`
-- marker sits on this keyframe; `releaseTime` hands the number out so a
-- caller can time the loop without listening for the marker.
local RELEASE_AT = 0.20

local DEFS: { [string]: Def } = {
	-- The hand circling overhead while held: the right upper arm up and a
	-- little out, the forearm circling the upper arm's axis, the left arm
	-- loose. Upper body only, so it can be twirled at a run.
	lassoTwirl = { length = 1.0, loop = true, legs = false, easing = Enum.PoseEasingStyle.Linear,
		frames = twirlFrames() },

	-- From the twirl, the arm goes up and BACK past vertical with the forearm
	-- cocked behind the head and the body turned away, then whips over the top
	-- to straight out in front -- that is the Release -- and falls through.
	lassoThrow = { length = 0.4, loop = false, legs = false, easing = Enum.PoseEasingStyle.Cubic,
		frames = {
			{ at = 0.00, torso = TWIRL_TORSO, head = TWIRL_HEAD, left = TWIRL_LEFT, right = twirlRight(0) },
			{ at = 0.12, torso = { pitch = 10, twist = -24 }, head = { pitch = -4, yaw = 17 },
				left = { pitch = 55, roll = 16, elbow = 10 }, right = { pitch = 200, roll = 18, elbow = 85 } },
			{ at = RELEASE_AT, marker = "Release", torso = { pitch = -14, twist = 20 }, head = { pitch = 6, yaw = -14 },
				left = { pitch = -24, roll = 14, elbow = 20 }, right = { pitch = 112, roll = 10, elbow = 6 } },
			{ at = 0.30, torso = { pitch = -7, twist = 8 }, head = { pitch = 2, yaw = -6 },
				left = { pitch = -8, roll = 10, elbow = 14 }, right = { pitch = 62, roll = 10, elbow = 24 } },
			{ at = 0.40, left = { roll = 4, elbow = 6 }, right = { pitch = 12, roll = 4, elbow = 12 } },
		} },

	-- Planted and leaning back on the rope, with a small rhythmic heave: the
	-- torso goes further back and both hands come in toward the belly. The
	-- legs and pelvis do not move between frames, so the feet stay exactly
	-- planted. The caller changes the speed with the tap rate.
	lassoPull = { length = 0.6, loop = true, legs = true, easing = Enum.PoseEasingStyle.Cubic,
		frames = { pullFrame(0, false), pullFrame(0.3, true), pullFrame(0.6, false) } },

	-- A hard yank from the pull stance, the feet shuffling back under the
	-- body, then the right fist punched straight up and pumped down.
	lassoWin = { length = 0.8, loop = false, legs = true, easing = Enum.PoseEasingStyle.Cubic,
		frames = {
			pullFrame(0, false),
			{ at = 0.14, pelvis = { pitch = 18, lift = -0.24 }, torso = { pitch = 22, twist = -12 },
				head = { pitch = -20, yaw = 8 },
				left = { pitch = 12, roll = -10, elbow = 95 }, right = { pitch = 6, roll = -8, elbow = 105 },
				feet = PULL_FEET },
			{ at = 0.32, pelvis = { pitch = 2, lift = -0.14 }, torso = { pitch = -2, twist = 4 }, head = { pitch = 6 },
				left = { pitch = 8, roll = 14, elbow = 60 }, right = { pitch = 110, roll = 20, elbow = 70 },
				feet = { left = { f = 0.22, out = 0.12, up = 0.18 }, right = { f = 0.12, out = 0.20 } } },
			{ at = 0.46, pelvis = { lift = -0.04 }, torso = { pitch = 4 }, head = { pitch = 14 },
				left = { pitch = -6, roll = 16, elbow = 70 }, right = { pitch = 172, roll = 14, elbow = 12 },
				feet = { left = { f = 0.06, out = 0.06 }, right = { f = 0.06, out = 0.10 } } },
			{ at = 0.62, pelvis = { lift = -0.16 }, torso = { pitch = -10, twist = 6 }, head = { pitch = -2 },
				left = { roll = 16, elbow = 80 }, right = { pitch = 95, roll = 22, elbow = 120 },
				feet = { left = { f = 0.04, out = 0.04 }, right = { f = 0.04, out = 0.06 } } },
			{ at = 0.80 },
		} },

	-- The rope breaks mid-pull, and it is a PRATFALL rather than a flinch
	-- (designer, 2026-09-23: "more dramatic and last longer so the player can
	-- actually see it break"). It holds the strain for a beat while the rope
	-- shudders (`Lasso.client` breaks it at `SNAP_BREAK_AT`), then the body is
	-- thrown back with both arms flung up, staggers two steps backwards with
	-- the arms windmilling, catches itself and comes back upright -- 1.4 s
	-- against the old 0.6, so the stumble is still going while the pieces fly.
	lassoSnap = { length = 1.4, loop = false, legs = true, easing = Enum.PoseEasingStyle.Cubic,
		frames = {
			pullFrame(0, false),
			-- The strain: leaning back hardest, still holding on.
			pullFrame(0.30, true),
			-- It goes: thrown back, arms flung up, the right foot off the grass.
			{ at = 0.42, pelvis = { pitch = 26, lift = -0.18, fwd = -0.24 }, torso = { pitch = 32 }, head = { pitch = 18 },
				left = { pitch = 150, roll = 45, elbow = 15 }, right = { pitch = 140, roll = 55, elbow = 20 },
				feet = { left = PULL_FEET.left, right = { f = -0.05, out = 0.25, up = 0.32 } } },
			-- First step back, arms starting to wheel.
			{ at = 0.62, pelvis = { pitch = 14, lift = -0.26, fwd = -0.36 }, torso = { pitch = 16, twist = 12 },
				head = { pitch = 6, yaw = -8 },
				left = { pitch = 165, roll = 30, elbow = 25 }, right = { pitch = 70, roll = 70, elbow = 30 },
				feet = { left = PULL_FEET.left, right = { f = -0.48, out = 0.28 } } },
			-- Second step, the other way round: the windmill.
			{ at = 0.84, pelvis = { pitch = 8, lift = -0.20, fwd = -0.30 }, torso = { pitch = 8, twist = -10 },
				head = { pitch = 2, yaw = 8 },
				left = { pitch = 60, roll = 75, elbow = 35 }, right = { pitch = 160, roll = 35, elbow = 20 },
				feet = { left = { f = -0.15, out = 0.20, up = 0.22 }, right = { f = -0.48, out = 0.28 } } },
			-- Caught it.
			{ at = 1.10, pelvis = { pitch = 2, lift = -0.12, fwd = -0.12 }, torso = { pitch = -4, twist = 4 }, head = { pitch = -4 },
				left = { pitch = 40, roll = 25, elbow = 30 }, right = { pitch = 30, roll = 30, elbow = 25 },
				feet = { left = { f = -0.10, out = 0.10 }, right = { f = -0.20, out = 0.12 } } },
			{ at = 1.40 },
		} },

	-- Shoved from the left while hugging a piggy: the hips knocked to the
	-- right with the upper body lagging, the right foot stepping out to catch
	-- it, and both arms flying open so the piggy tumbles out of them.
	knockedLoose = { length = 0.6, loop = false, legs = true, easing = Enum.PoseEasingStyle.Cubic,
		frames = {
			{ at = 0.00, torso = { pitch = HUG.torso }, head = { pitch = HUG.head }, left = HUG_LEFT, right = HUG_RIGHT },
			{ at = 0.10, pelvis = { side = 0.22, roll = -10, lift = -0.10 }, torso = { pitch = -4, roll = 14 },
				head = { pitch = -6, roll = 10 },
				left = { pitch = 40, yaw = 10, roll = 65, elbow = 30 }, right = { pitch = 40, yaw = 10, roll = 65, elbow = 30 },
				feet = { right = { out = 0.28, up = 0.22 } } },
			{ at = 0.24, pelvis = { side = 0.26, roll = -6, lift = -0.16 }, torso = { pitch = 4, roll = 4 },
				head = { pitch = -16, roll = 4 },
				left = { pitch = 72, yaw = -4, roll = 82, elbow = 12 }, right = { pitch = 72, yaw = -4, roll = 82, elbow = 12 },
				feet = { right = { out = 0.34 } } },
			{ at = 0.42, pelvis = { side = 0.10, lift = -0.08 }, head = { pitch = -8 },
				left = { pitch = 28, roll = 36, elbow = 30 }, right = { pitch = 28, roll = 36, elbow = 30 },
				feet = { right = { out = 0.14, up = 0.12 } } },
			{ at = 0.60 },
		} },

	-- Down into a squat with the hips hinged and the head up to watch the
	-- piggy, both arms reaching down and in to cup it, then up -- ending on
	-- the hug's own angles, so the carry underneath takes over seamlessly.
	scoopUp = { length = 0.5, loop = false, legs = true, easing = Enum.PoseEasingStyle.Cubic,
		frames = {
			{ at = 0.00 },
			{ at = 0.16, pelvis = { pitch = -12, lift = -0.55 }, torso = { pitch = -36 }, head = { pitch = 22 },
				left = { pitch = 72, yaw = 20, roll = 16, elbow = 10 }, right = { pitch = 72, yaw = 20, roll = 16, elbow = 10 },
				feet = { left = { f = 0.06, out = 0.10 }, right = { f = 0.06, out = 0.10 } } },
			{ at = 0.32, pelvis = { pitch = -4, lift = -0.22 }, torso = { pitch = -10 }, head = { pitch = 8 },
				left = { pitch = 30, yaw = 30, roll = 40, elbow = 55 }, right = { pitch = 30, yaw = 30, roll = 40, elbow = 55 },
				feet = { left = { f = 0.03, out = 0.05 }, right = { f = 0.03, out = 0.05 } } },
			{ at = 0.50, torso = { pitch = HUG.torso }, head = { pitch = HUG.head }, left = HUG_LEFT, right = HUG_RIGHT },
		} },
}

-- Exposed for tests and review: the frame tables above, and the leg lengths
-- the solver used.
LassoPose.DEFS = DEFS
LassoPose.RIG = { rootJointY = ROOT_JOINT_Y, hipX = HIP_X, hipDown = HIP_DOWN, thigh = THIGH, shin = SHIN }

-- ============================================================
-- THE LEG SOLVER
-- ============================================================

-- Rotate a vector by CFrame.Angles(x, y, z) (degrees), which is Rx * Ry * Rz:
-- roll first, then yaw, then pitch. Plain numbers rather than a CFrame so the
-- solver is the same arithmetic wherever it runs.
local function rotate(x: number, y: number, z: number, pitch: number, yaw: number, roll: number): (number, number, number)
	local c, s = math.cos(math.rad(roll)), math.sin(math.rad(roll))
	x, y = x * c - y * s, x * s + y * c
	c, s = math.cos(math.rad(yaw)), math.sin(math.rad(yaw))
	x, z = x * c + z * s, -x * s + z * c
	c, s = math.cos(math.rad(pitch)), math.sin(math.rad(pitch))
	y, z = y * c - z * s, y * s + z * c
	return x, y, z
end

local function clampUnit(v: number): number
	return math.clamp(v, -1, 1)
end

type Leg = { hipFlex: number, legRoll: number, knee: number, ankle: number, footRoll: number }

-- One pass of two-link IK for an ankle target relative to the hip: the splay
-- is taken as a roll and the rest is solved in the leg's own plane, with the
-- knee always bending forward and the foot levelled against everything above
-- it.
local function solveOnce(dx: number, dy: number, df: number, pitch: number, roll: number): Leg
	local lateral = math.deg(math.atan2(dx, -dy))
	local v = math.sqrt(dx * dx + dy * dy)
	local d = math.clamp(math.sqrt(df * df + v * v), math.abs(THIGH - SHIN) + 0.01, THIGH + SHIN)
	local phi = math.deg(math.atan2(df, v))
	local alpha = math.deg(math.acos(clampUnit((THIGH * THIGH + d * d - SHIN * SHIN) / (2 * THIGH * d))))
	local beta = math.deg(math.acos(clampUnit((SHIN * SHIN + d * d - THIGH * THIGH) / (2 * SHIN * d))))
	local thigh = phi + alpha -- forward of straight down, in the world
	local shin = phi - beta
	return {
		hipFlex = thigh - pitch,
		legRoll = lateral - roll,
		knee = shin - thigh,
		ankle = -shin,
		footRoll = -lateral,
	}
end

-- Where a leg's angles actually put the ankle, relative to the hip, through
-- the same rotation order the poses are built with.
local function ankleOf(leg: Leg, pitch: number, yaw: number, roll: number): (number, number, number)
	local x, y, z = rotate(0, -SHIN, 0, leg.knee, 0, 0)
	x, y, z = rotate(x, y - THIGH, z, leg.hipFlex, 0, leg.legRoll)
	return rotate(x, y, z, pitch, yaw, roll)
end

-- Two-link IK for one leg. `side` is +1 right, -1 left. The ankle target is in
-- root space; the hip is wherever the frame's pelvis puts it. One planar pass
-- is out by up to a tenth of a stud once the pelvis rolls or a foot splays,
-- because the splay and the bend do not commute, so the solve is walked
-- through the real rotation order and the target nudged by the miss a few
-- times -- measured to a thousandth of a stud on every frame here.
local function legs(frame: Frame, side: number): Leg
	local pelvis = frame.pelvis or {}
	local pitch, yaw, roll = pelvis.pitch or 0, pelvis.yaw or 0, pelvis.roll or 0
	local hx, hy, hz = rotate(side * HIP_X, -HIP_DOWN, 0, pitch, yaw, roll)
	hx += pelvis.side or 0
	hy += ROOT_JOINT_Y + (pelvis.lift or 0)
	hz += -(pelvis.fwd or 0)

	local feet = frame.feet or {}
	local foot: Foot = (if side > 0 then feet.right else feet.left) or {}
	local ax = side * (HIP_X + (foot.out or 0)) - hx
	local ay = REST_ANKLE_Y + (foot.up or 0) - hy
	local az = -(foot.f or 0) - hz

	local tx, ty, tz = ax, ay, az
	local leg = solveOnce(tx, ty, -tz, pitch, roll)
	for _ = 1, 6 do
		local lx, ly, lz = ankleOf(leg, pitch, yaw, roll)
		tx, ty, tz = tx + (ax - lx), ty + (ay - ly), tz + (az - lz)
		leg = solveOnce(tx, ty, -tz, pitch, roll)
	end
	return leg
end

LassoPose.solveLeg = legs

-- ============================================================
-- BUILDING
-- ============================================================

local function angles(x: number?, y: number?, z: number?): CFrame
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end

local function pose(name: string, cf: CFrame, parent: Instance, weight: number, easing: Enum.PoseEasingStyle): Pose
	local p = Instance.new("Pose")
	p.Name = name
	p.CFrame = cf
	p.Weight = weight
	p.EasingStyle = easing
	p.EasingDirection = Enum.PoseEasingDirection.InOut
	p.Parent = parent
	return p
end

local function buildSequence(key: string): KeyframeSequence?
	local def = DEFS[key]
	if not def then
		return nil
	end
	local easing = def.easing
	local seq = Instance.new("KeyframeSequence")
	seq.Name = key
	seq.Loop = def.loop
	-- Action, over the run and the carry. An upper-body sequence still leaves
	-- the legs to whatever is running underneath, because it has none. THE
	-- TWIRL IS THE EXCEPTION: it is held for as long as a lasso is out, and at
	-- Action it would blend 50/50 with a dodge roll (also Action), so it sits
	-- at Movement the way CarryPose does and a dodge beats it.
	seq.Priority = if key == "lassoTwirl" then Enum.AnimationPriority.Movement else Enum.AnimationPriority.Action

	for _, frame in ipairs(def.frames) do
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = frame.at

		-- Identity, always: no root motion. The path joints carry no weight
		-- on an upper-body sequence, or the pelvis freezes under the run.
		local pathWeight = if def.legs then 1 else 0
		local root = pose("HumanoidRootPart", CFrame.new(), keyframe, pathWeight, easing)
		local pelvis = frame.pelvis or {}
		local lowerCF = if def.legs
			then CFrame.new(pelvis.side or 0, pelvis.lift or 0, -(pelvis.fwd or 0)) * angles(pelvis.pitch, pelvis.yaw, pelvis.roll)
			else CFrame.new()
		local lower = pose("LowerTorso", lowerCF, root, pathWeight, easing)

		local torso = frame.torso or {}
		local upper = pose("UpperTorso", angles(torso.pitch, torso.twist, torso.roll), lower, 1, easing)
		local head = frame.head or {}
		pose("Head", angles(head.pitch, head.yaw, head.roll), upper, 1, easing)

		for _, side in ipairs({ "Left", "Right" }) do
			local sign = if side == "Left" then -1 else 1
			local arm: Arm = (if side == "Left" then frame.left else frame.right) or {}
			local upperArm = pose(side .. "UpperArm",
				angles(arm.pitch, (arm.yaw or 0) * sign, (arm.roll or 0) * sign), upper, 1, easing)
			-- The cone is applied OUTSIDE the elbow bend, about the upper arm's
			-- own axis, so the bent forearm sweeps round the arm rather than the
			-- whole upper arm spinning on its length.
			local lowerArm = pose(side .. "LowerArm",
				angles(0, arm.cone, 0) * angles(arm.elbow), upperArm, 1, easing)
			pose(side .. "Hand", CFrame.new(), lowerArm, 1, easing)

			if def.legs then
				local leg = legs(frame, sign)
				local upperLeg = pose(side .. "UpperLeg", angles(leg.hipFlex, 0, leg.legRoll), lower, 1, easing)
				local lowerLeg = pose(side .. "LowerLeg", angles(leg.knee), upperLeg, 1, easing)
				pose(side .. "Foot", angles(leg.ankle, 0, leg.footRoll), lowerLeg, 1, easing)
			end
		end

		if frame.marker then
			local marker = Instance.new("KeyframeMarker")
			marker.Name = frame.marker
			keyframe:AddMarker(marker)
		end

		keyframe.Parent = seq
	end

	return seq
end

-- Exposed for the `animdump` uploader: the same function the runtime
-- registers, so what gets published is what Studio has been playing. The
-- sequence is named after its `Config.ANIMATIONS` row.
LassoPose.buildSequence = buildSequence

function LassoPose.releaseTime(): number
	return RELEASE_AT
end

-- ============================================================
-- IDS
-- ============================================================

local ids: { [string]: string } = {}
local failed: { [string]: boolean } = {}

local function getAnimationId(key: string): string?
	if ids[key] then
		return ids[key]
	end
	if failed[key] then
		return nil
	end
	local uploaded = Config.animationId(key)
	if uploaded then
		ids[key] = uploaded
		return uploaded
	end
	local ok, id = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(buildSequence(key) :: KeyframeSequence)
	end)
	if not ok or type(id) ~= "string" then
		failed[key] = true
		warn("[LassoPose] could not register " .. key .. ", and Config.ANIMATIONS." .. key
			.. " is empty. In a published game this is expected -- upload the sequence "
			.. "(animdump) and put its id there. (" .. tostring(id) .. ")")
		return nil
	end
	ids[key] = id
	return id
end

-- ============================================================
-- PLAYING
-- ============================================================

local TRACK_PREFIX = "LassoPose_"
local DEFAULT_FADE = 0.1

local function keyOfTrack(track: AnimationTrack): string?
	local name = track.Name
	if string.sub(name, 1, #TRACK_PREFIX) ~= TRACK_PREFIX then
		return nil
	end
	local key = string.sub(name, #TRACK_PREFIX + 1)
	return if DEFS[key] then key else nil
end

-- Loaded tracks per animator, so a lasso used all session reuses one track
-- per key rather than loading a new one per throw. Strong, and cleared when
-- the animator leaves the game: a weak Instance key is dropped by the
-- collector while the engine still holds the animator (RidePose's header).
-- Every entry point still looks for PLAYING tracks by name first, so a stale
-- cache can never stack a pose.
local loaded: { [Animator]: { [string]: AnimationTrack } } = {}

local function load(animator: Animator, key: string): AnimationTrack?
	local byKey = loaded[animator]
	if byKey and byKey[key] then
		return byKey[key]
	end
	local id = getAnimationId(key)
	if not id then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.Name = TRACK_PREFIX .. key
	animation.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok or not track then
		warn("[LassoPose] could not load " .. key .. ": " .. tostring(track))
		return nil
	end
	track.Name = TRACK_PREFIX .. key
	track.Priority = if key == "lassoTwirl" then Enum.AnimationPriority.Movement else Enum.AnimationPriority.Action
	track.Looped = DEFS[key].loop
	if not byKey then
		byKey = {}
		loaded[animator] = byKey
		animator.AncestryChanged:Connect(function()
			if not animator:IsDescendantOf(game) then
				loaded[animator] = nil
			end
		end)
	end
	byKey[key] = track
	return track
end

-- Every playing lasso track on the animator, optionally one key's only.
local function playingTracks(animator: Animator, key: string?): { AnimationTrack }
	local found = {}
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		local k = keyOfTrack(track)
		if k and (key == nil or k == key) then
			table.insert(found, track)
		end
	end
	return found
end

local warnedUnknown: { [string]: boolean } = {}

function LassoPose.play(animator: Animator, key: string, opts: { speed: number?, fade: number? }?): AnimationTrack?
	local def = DEFS[key]
	if not def then
		if not warnedUnknown[key] then
			warnedUnknown[key] = true
			warn("[LassoPose] no lasso animation called " .. tostring(key))
		end
		return nil
	end
	local fade = (opts and opts.fade) or DEFAULT_FADE
	local speed = math.max((opts and opts.speed) or 1, 0)

	-- One lasso track at a time. A loop already running for this key is kept
	-- (and re-sped) rather than restarted, so a caller polling `play` every
	-- frame does not reset the twirl; anything else is stopped. Exactly one
	-- copy of the kept loop survives, which unwinds a stack if one appeared.
	local keep: AnimationTrack? = nil
	for _, track in ipairs(playingTracks(animator)) do
		if def.loop and keep == nil and keyOfTrack(track) == key then
			keep = track
		else
			track:Stop(fade)
		end
	end
	if keep then
		-- Only an explicit speed re-speeds it, so a poll of `play` does not
		-- undo a tap rate `setSpeed` has just set.
		if opts and opts.speed then
			keep:AdjustSpeed(speed)
		end
		return keep
	end

	local track = load(animator, key)
	if not track then
		return nil
	end
	-- Weight 1, never 0: a track played at weight 0 never starts (CLAUDE.md,
	-- "AN ANIMATION TRACK'S WEIGHT OF ZERO IS TERMINAL"). A one-shot replayed
	-- restarts from the top.
	track:Play(fade, 1, speed)
	return track
end

function LassoPose.stop(animator: Animator, key: string?, fade: number?)
	for _, track in ipairs(playingTracks(animator, key)) do
		track:Stop(fade or DEFAULT_FADE)
	end
end

function LassoPose.setSpeed(animator: Animator, key: string, speed: number)
	for _, track in ipairs(playingTracks(animator, key)) do
		track:AdjustSpeed(math.max(speed, 0))
	end
end

function LassoPose.isPlaying(animator: Animator, key: string): boolean
	return #playingTracks(animator, key) > 0
end

return LassoPose
