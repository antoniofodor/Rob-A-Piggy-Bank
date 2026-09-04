--!strict
--[[
	RidePose

	How a rider sits or stands on the thing they are riding, built entirely in
	code -- the same mechanism as DodgeRoll, for the same reasons.

	WHY AN ANIMATION AND NOT A WELD OR A JOINT WRITE.

	This is settled ground; see the note at the top of DodgeRoll. This rig
	joins parts with AnimationConstraint rather than Motor6D, its `C0` is READ
	ONLY, and `Transform` is a read-back of the animation result rather than an
	input to it -- a client write moves nothing on screen. The animation system
	is the one thing allowed to drive these joints. So a rider's pose is a
	KeyframeSequence, registered at runtime, exactly like the roll.

	WHAT THIS REPLACED.

	Mounting used to disable the Animate script and stop every running track,
	which drops the rig into its default rest pose: arms straight down, legs
	together, feet flat. That is a plausible shape on a hoverboard and wrong on
	everything else -- on the BMX the rider stood bolt upright with their arms
	at their sides, a foot behind the handlebars, and on the skateboard they
	stood to attention with their feet together in the middle of the deck.
	Stopping the walk cycle was right; leaving nothing in its place was not.

	EVERY POSE IS MEASURED AGAINST A REAL CHARACTER, NEVER EYEBALLED.

	Each number here was tuned by applying the pose to a live R15 rig and
	reading the hand and foot positions back in ROOT SPACE, then placing the
	ride's contact points -- grips, saddle, pedals, deck -- at the positions
	that came back. That direction matters: posing a rider to reach a fixed
	handlebar is an inverse-kinematics problem with no solution when the bar is
	out of reach, and the BMX's was. Moving the bar to the hand always works.

	The measured contacts, in root space, for the record:

	    bmx          hands (+-1.74, -0.58, -1.12)   feet (+-0.35, -2.56, -0.52)
	                 pelvis bottom y -1.00 at z +0.43
	    skateboard   feet   R (+0.91, -2.78)  L (-1.36, -2.72)

	THE POSE NEVER MOVES THE ROOT.

	Same rule as the roll, and load-bearing for the same reason: BASE_WALK_SPEED
	is what the carry penalty, the dog speeds, the fence snags and the getaway
	are calibrated against, and a pose that shifted the character would be a
	second way to move that none of those numbers know about. Translating the
	LowerTorso is fine -- that is the body moving relative to the root, and the
	ride is welded to the ROOT, so the bike stays put while the rider settles
	onto it.

	EVERY CLIENT REGISTERS ITS OWN COPY, because a hash:// id is local to the
	peer that registered it and cannot replicate. The server publishes a
	`RideStyle` attribute on the character and every client plays the pose
	itself -- the same shape as the roll and the animated skins. It matters
	that other people see it: a ride is the most visible thing anyone owns, and
	the whole purchase is being seen on it.
]]

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

local Config = require(script.Parent.Config)

local RidePose = {}

-- One entry per ride STYLE, keyed the same as RideModel's builders.
--
-- All five rides are posed. A style with no entry still gets no pose and
-- keeps the rest pose with the walk cycle stopped, which is deliberately a
-- working state rather than an error -- so a sixth ride added tomorrow looks
-- plain rather than broken until somebody measures it.
--
-- Adding one is a measuring pass, never a guess: apply the pose to a live
-- rig, read the hands and feet back in root space, then move that ride's
-- grips, seat, pads or pegs to what came back. A guessed pose puts hands
-- through handlebars.
--
-- Angles are degrees. Sign conventions, all verified on a live rig rather
-- than reasoned about, because half of them are the opposite of the obvious:
--
--   torso / hipPitch   negative leans FORWARD
--   armPitch           positive raises the arm forward
--   elbow              negative bends the arm in
--   hipFlex            positive lifts the knee forward
--   knee               negative folds the shin back
--   legRoll            positive swings the foot toward +X, BOTH SIDES
--   headYaw / torsoYaw negative turns toward +X
--
-- `legRoll` catching both legs the same way is the one that cost the most
-- time: it reads like a mirrored "outward" and it is not, so a skateboard
-- stance needs one side negative and the other positive rather than a single
-- spread value.
local POSES: { [string]: any } = {
	-- SEATED, HANDS ON THE BARS.
	--
	-- `hipBack` slides the pelvis 0.45 studs back so it sits over the saddle
	-- rather than in front of it, and the torso leans 28 degrees forward to
	-- put the hands out at the grips. Head up 22: a rider looks at the road,
	-- not at the stem, and without it the lean buries the face in the bars.
	--
	-- The legs are the part that fought back. At the first setting the knees
	-- came up so far that the feet sat 0.79 studs AHEAD of the hips, which is
	-- a mobility scooter rather than a bike, and it forced the pedals so far
	-- forward that the cranks would have been out past the front of the frame.
	-- 46/-48 drops the feet to 0.37 ahead, which is where a bottom bracket
	-- actually goes.
	bmx = {
		hipBack = 0.45, torso = -28, head = 22,
		left = { armPitch = 76, armRoll = -10, elbow = -12, hipFlex = 46, knee = -48, ankle = 12 },
		right = { armPitch = 76, armRoll = 10, elbow = -12, hipFlex = 46, knee = -48, ankle = 12 },
		-- The wheelie. `lean` is the share of the bike's 30 degrees the body
		-- takes: 0.80, so the rider turns 24 and the machine turns 30, and
		-- the six degrees of difference is taken up by the ARMS -- which is
		-- what a pull looks like. The solver ran the elbow to its stop
		-- (-12 to 0, dead straight) and could go no further; that limit is
		-- what sets 0.80, not taste. Measured residual 0.070 at the grip.
		trick = {
			lean = 0.80,
			left = { armPitch = -7, armYaw = 2, armRoll = -3, elbow = 12, wrist = 2, hipFlex = 3, knee = 4, ankle = -2 },
			right = { armPitch = -7, armYaw = -2, armRoll = 2, elbow = 12, wrist = 2, hipFlex = 3, knee = 4, ankle = -2 },
		},
	},

	-- STANDING ACROSS THE DECK: back foot on the tail, front foot past the
	-- middle, knees soft.
	--
	-- The board lies along the root's X axis, because the stance turn is a
	-- yaw on the ROOT (see RideService) -- so the nose is at root +X, which
	-- makes the RIGHT foot the front foot and the LEFT foot the back one.
	-- That is not a choice, it falls out of `bodyYaw = 90`; flipping the
	-- stance to goofy would flip which leg is which here too.
	--
	-- `hipRoll` is the trick that makes it work. Swinging a leg out to reach
	-- the tail also LIFTS that foot -- abduction shortens the leg's vertical
	-- reach -- so the back foot floated 0.20 studs above the deck however the
	-- knee was bent, and knee bend barely touches it (measured 0.05). Tilting
	-- the pelvis 8 degrees drops the reaching side and lifts the other, which
	-- levels the feet to 0.06 and is what a skater's hips actually do. The
	-- torso counter-rolls by the same 8 so the shoulders stay level.
	--
	-- Measured result: front foot at x +0.91, back foot at x -1.36. The back
	-- truck is at -1.22, so the back foot is genuinely past it and onto the
	-- tail rather than merely near it.
	skateboard = {
		hipRoll = 8, torsoRoll = -8, torso = -6, torsoYaw = -14, headYaw = -34,
		left = { armPitch = 14, armRoll = -34, elbow = -16, hipFlex = 6, knee = -10, legRoll = -38, ankle = 6 },
		right = { armPitch = 8, armRoll = 28, elbow = -12, hipFlex = 10, knee = -28, legRoll = 10, ankle = 4 },
		-- The manual, and it leans FAR less than the bikes do -- 16 degrees
		-- against the deck's 26 -- because nothing is being held. A rider
		-- with their hands on bars runs out of arm; a skater has only their
		-- knees to answer to, so the difference can be large enough to read.
		-- The front knee folds 17 degrees further and the back leg swings
		-- out 10: the board goes up and the skater stays where they were.
		--
		-- The arms are the one AUTHORED part of any trick pose. There is
		-- nothing to reach, so there is nothing to solve for, and a manual
		-- with the arms still by the sides reads as a person standing on a
		-- tipped plank. Up and out, and small enough not to be a semaphore.
		trick = {
			lean = 0.60,
			left = { armPitch = 16, armRoll = -8, hipFlex = -4, legYaw = 2, legRoll = 10, knee = 8, ankle = -7 },
			right = { armPitch = 14, armRoll = 8, hipFlex = 5, legYaw = 4, legRoll = 9, knee = -17, ankle = 10 },
		},
	},

	-- STANDING ALONG THE DECK, one foot ahead of the other, hands on the bars.
	--
	-- A scooter faces forward, so unlike the board the feet are offset in Z
	-- rather than X: left foot forward at z -0.63, right foot back at +0.66,
	-- both flat on the deck and level to 0.04. The asymmetry is the whole
	-- point -- feet side by side reads as standing on a plank, one foot
	-- forward reads as riding.
	scooter = {
		torso = -14, head = 10,
		left = { armPitch = 68, armRoll = -8, elbow = -22, hipFlex = 22, knee = -18, ankle = 6 },
		right = { armPitch = 68, armRoll = 8, elbow = -22, hipFlex = -14, knee = -26, ankle = 10 },
	},

	-- FEET SIDE BY SIDE ON THE PADS, knees soft, arms out to balance.
	--
	-- There is nothing to hold, so the arms ARE the pose: out at +-2.26 they
	-- read as balancing, which is the entire idea of the machine. legRoll is
	-- mirrored here -- one negative, one positive -- which puts the feet at
	-- +-1.08, and the pads are pinned to that number rather than the pose
	-- being bent to reach them.
	hoverboard = {
		torso = -4, head = 4,
		left = { armPitch = 10, armRoll = -40, elbow = -10, hipFlex = 8, knee = -16, legRoll = -22, ankle = 4 },
		right = { armPitch = 10, armRoll = 40, elbow = -10, hipFlex = 8, knee = -16, legRoll = 22, ankle = 4 },
	},

	-- SEATED, like the BMX but more upright. A dirt bike carries its bars
	-- higher and further back, so the rider is not folded over them: 16
	-- degrees of lean against the BMX's 28, and the knees stay higher because
	-- the pegs sit further forward than a bottom bracket does.
	scrambler = {
		hipBack = 0.4, torso = -16, head = 12,
		left = { armPitch = 64, armRoll = -14, elbow = -16, hipFlex = 52, knee = -54, ankle = 12 },
		right = { armPitch = 64, armRoll = 14, elbow = -16, hipFlex = 52, knee = -54, ankle = 12 },
		-- Same wheelie, same 0.80, same reason: the elbow reaches its stop
		-- (-16 to 0) and stops the lean there. Residual 0.048 at the grip.
		trick = {
			lean = 0.80,
			left = { armPitch = -10, armYaw = 4, armRoll = -2, elbow = 16, hipFlex = 3, knee = 3 },
			right = { armPitch = -10, armYaw = -4, armRoll = 2, elbow = 16, hipFlex = 3, knee = 3 },
		},
	},
}

-- THE HOVERDISC WEARS THE HOVERBOARD'S POSE.
--
-- Both are a board you stand square on with the arms out to balance, and the
-- hoverboard's stance is the measured one -- every contact read back off a
-- live rig and the deck then moved to where the feet actually landed. An
-- alias inherits all of that for a line, where a second authored pose would
-- be the whole measure-and-move exercise again for a ride that stands
-- identically.
--
-- It stays honest only while the Hoverdisc's deck keeps the same standing
-- height and the same +-1.08 pad positions. Change either and this stops
-- being an alias and starts being a lie.
POSES.hoverdisc = POSES.hoverboard


-- ============================================================
-- STANCES
-- ============================================================
--
-- A stance is an ALTERNATE pose for a style: the same rider on the same ride,
-- sitting differently. The style string carries it as a suffix --
-- "bmx@onehand" -- exactly the way the trick is carried as "bmx#trick", so a
-- stance is one more lookup rather than a parallel table that could disagree
-- with this one about which styles exist.
--
-- A STANCE IS AN OVERRIDE, NEVER A WHOLE POSE, AND THAT IS THE WHOLE TRICK.
--
-- Every base pose above was measured by posing a live rig, reading the hands
-- and feet back in ROOT SPACE, and then moving that ride's grips, pads and
-- pedals to what came back. That direction is one-way, and it runs out: once
-- a handlebar has been built at the hand's measured position, a second pose
-- cannot move it. An alternate pose that re-authored the whole body would
-- therefore be exactly the inverse-kinematics problem the note at the top of
-- this file says has no solution when the bar is out of reach -- and this
-- time moving the bar is not available, because the first pose is using it.
--
-- Overriding field by field sidesteps it completely. A stance that names only
-- the left arm CANNOT move the feet, because the leg fields it does not
-- mention are still the measured ones. So the cheap stances -- and the only
-- ones in here -- are the ones that LET GO of something: a hand off the bar,
-- both hands off, arms folded, an arm in the air. A free limb has no contact
-- to miss. Anything that keeps a contact and changes how it is held is a
-- re-measure and has to be treated as one rather than nudged.
--
-- The `trick` block passes through from the base pose untouched, which is
-- right for the limbs still holding on and harmless for the ones that let go:
-- a freed arm picks up the small swing the pull would have given it, and a
-- body leaning into a wheelie swings a loose arm anyway.
--
-- `name` and `order` are label and running order; neither reaches the pose.
local STANCES: { [string]: { [string]: any } } = {
	-- ONE HAND ON THE BAR, the other hanging.
	--
	-- The right hand keeps its grip and the torso keeps its 28-degree lean,
	-- which is what makes this legal: the contact still being made is made by
	-- the same limb at the same angle as the pose the bar was built for. Only
	-- the left arm is told anything at all.
	bmx = {
		onehand = {
			name = "One Hand", order = 1,
			left = { armPitch = -8, armRoll = -13, elbow = -9 },
		},
	},

	-- HANDS DOWN, cruising: RELAXED, SLIGHTLY BEHIND, CLOSE TO THE BODY.
	--
	-- The first version reasoned about this instead of measuring it, on the
	-- theory that landing back on dead-straight arms would look like the pose
	-- had failed to load. It reasoned wrong -- with the whole body's own
	-- cruise lean in play (torsoYaw -14, torsoRoll -8, hipRoll 8), the rig's
	-- OWN rest orientation (every arm field at zero) already sits nowhere
	-- near vertical: measured shoulder-to-hand at (dx -0.53, dy -1.18,
	-- dz -0.37) for the left arm, meaning it hangs 0.53 studs out from the
	-- body and 0.37 forward before a single degree of pose is added. So there
	-- was never a real risk of this reading as unanimated, and the old
	-- values (left -12/-14/-6, right -16/12/-5) did not reach the target
	-- anyway: measured, the left hand still sat 0.87 studs OUT from the
	-- shoulder and 0.15 studs FORWARD of it -- swung away from the body and
	-- not yet behind it at all, which is what "only brings the arms down
	-- slightly" was actually describing.
	--
	-- Retuned by sweeping each arm axis in isolation on a live rig (pitch,
	-- roll, elbow each alone, at a wide angle, to read the sign and rate of
	-- every field before combining them) and then converging on a combined
	-- value. Left and right are NOT mirrors of each other: the skateboard's
	-- own asymmetric lean (torsoYaw, hipRoll) puts each shoulder at a
	-- different starting orientation, so the same "close and slightly
	-- behind" target needs a different roll on each side to reach it.
	--
	-- Measured result, shoulder to hand: left (dx -0.16, dy -1.34, dz +0.20),
	-- right (dx +0.20, dy -1.32, dz +0.29) -- both arms within 0.2 studs of
	-- hanging straight down from their own shoulder, and both a few tenths of
	-- a stud BEHIND it rather than in front, against the old -0.87/+0.82 out
	-- and -0.15/+0.28 (still forward on the left) this replaced.
	--
	-- THE FRONT FOOT COMES IN TOO, for the same "chilling" read the arms are
	-- going for. `legRoll` is the only field that moves it: at the base
	-- pose's +10 it is the small extra abduction that sends the front foot
	-- out toward the nose. Zeroing it -- not flipping its sign, just letting
	-- go of that outward roll -- pulls the front foot in.
	--
	-- MEASURED ON THE LIVE MOUNTED RIDER, not on a throwaway rig off to the
	-- side. A first pass built a standalone KeyframeSequence with the same
	-- numbers to search for the right value without needing a Play restart
	-- per guess, the same shape as the arm sweep above -- and its predictions
	-- did not hold up against the real thing: it forecast legRoll=-15 landing
	-- the gap at 1.86, and the ACTUAL mounted rider at that value measured
	-- 1.44, a stance closing in on the back foot rather than a slight step
	-- toward it. Something about a standalone sequence played over a fresh
	-- LoadAnimation does not compose identically to the two blended tracks
	-- (base pose plus the near-zero-weight trick) the real mount always has
	-- running -- worth another look some time, not chased down here. The
	-- number that shipped is the one read off the actual rider: legRoll=0
	-- puts the front foot at 1.94 studs from the back one, against 2.26
	-- before -- a slight step in, not a stance collapsed to nothing.
	--
	-- The back foot is left alone: it is already the one riding the tail,
	-- and closing on it FROM THE FRONT is what was asked for. hipFlex, knee
	-- and ankle are also untouched -- only the roll was ever the outward
	-- push, so it is the only field this stance needs to name.
	skateboard = {
		cruise = {
			name = "Cruise", order = 1,
			torso = -2,
			left = { armPitch = -18, armRoll = 23, elbow = -7 },
			right = { armPitch = -18, armRoll = -17, elbow = -7, legRoll = 0 },
		},
	},

	-- BOTH HANDS OFF, arms out.
	--
	-- The scooter is the one bar-holding ride where letting go of both reads,
	-- because the rider stands square along the deck and the whole silhouette
	-- opens up. Standing up out of the 14-degree lean is part of it: nobody
	-- stays folded over bars they are not holding.
	scooter = {
		nohands = {
			name = "No Hands", order = 1,
			torso = -2, head = 4,
			left = { armPitch = 8, armRoll = -36, elbow = -12 },
			right = { armPitch = 8, armRoll = 36, elbow = -12 },
		},
	},

	-- ARMS FOLDED.
	--
	-- The hoverboard has nothing to hold, so this is the one stance here with
	-- no contact to respect at all -- and the biggest silhouette change
	-- available anywhere in the file, since the base pose's whole idea is arms
	-- out at +-2.26 reading as balance.
	--
	-- Deliberately not symmetric: two arms folded at identical angles put the
	-- forearms through each other. The right sits higher and crosses further,
	-- which is what a folded pair actually does.
	hoverboard = {
		crossed = {
			name = "Arms Crossed", order = 1,
			torso = -2,
			left = { armPitch = 24, armRoll = 30, elbow = -98 },
			right = { armPitch = 31, armRoll = -34, elbow = -104 },
		},
	},

	-- ONE ARM UP.
	--
	-- The scrambler is the loudest ride in the game and the only one whose
	-- rider sits high enough to clear a fence, so its stance is the one that
	-- reads from furthest away: an arm straight up has a silhouette nothing
	-- else on the street has.
	-- ONE HAND ON THE THROTTLE, AND A LEG OFF WHEN IT GOES UP.
	--
	-- The only stance that is two poses, and the only one that changes what
	-- the TRICK looks like -- which is the whole reason it is the best one in
	-- the set. A raised arm is a flourish nobody is looking at, because a
	-- rider cruising the street is scenery. A wheelie is the one moment on
	-- this ride that people actually watch, so the flourish belongs there.
	--
	-- Riding: the LEFT hand comes off and hangs. The right is the throttle on
	-- every motorcycle ever built, so the hand that stays is the right one --
	-- which is also the hand the base pose measured against the grip, so the
	-- contact that survives is the one that was authored.
	--
	-- Wheelie: the left leg comes off the peg as well and drops toward the
	-- road. It arrives on its own: the trick pose is blended by how far the
	-- bike has actually rotated, so the leg swings off as the front wheel
	-- comes up and tucks back as it lands, with nothing here to time.
	scrambler = {
		onehand = {
			name = "One Hand", order = 1,
			left = { armPitch = -8, armRoll = -13, elbow = -9 },
			trick = {
				-- Only the left LEG. `lean`, the right arm and the right leg
				-- all fall through from the base trick, which is what keeps
				-- the hand that is still holding on exactly where it was
				-- measured against the grip.
				--
				-- A TRICK BLOCK IS A DELTA, NOT A POSE -- see `v()` in
				-- addKeyframe, which ADDS it to the base angle. Written as if
				-- these were absolutes the leg barely moved: hipFlex -18 on
				-- top of the seated 52 is 34, still a knee up by the tank, and
				-- the measured foot came out HIGHER than the classic wheelie
				-- (world y 1.31 against 1.06) rather than dropping at all.
				--
				-- So these are worked backwards from where the limb has to
				-- END UP. The seated leg is hipFlex 52 / knee -54; a leg
				-- dangling off wants about -20 and -8, and -20 rather than 0
				-- because the body is already leaning 24 degrees back into the
				-- wheelie, so a leg square to the torso would point down and
				-- FORWARD in the world. `legRoll` swings it clear of the
				-- engine on the way past.
				left = { hipFlex = -72, knee = 46, legRoll = -16, ankle = -10 },
			},
		},
	},
}

-- The style half of a key and the stance half.
--
-- "@" rather than "#", which the trick already owns, and rather than "_",
-- which a style could legitimately contain -- a key that can be ambiguously
-- parsed is a key that will be.
local STANCE_MARK = "@"

local function splitStance(style: string): (string, string?)
	local at = string.find(style, STANCE_MARK, 1, true)
	if not at then
		return style, nil
	end
	return string.sub(style, 1, at - 1), string.sub(style, at + 1)
end

-- Field by field, and one level into `left` and `right`.
--
-- One level is the entire point: an arm and a leg share a side table, so a
-- stance that replaced that table outright to change an arm would silently
-- throw away the measured `hipFlex`, `knee` and `ankle` sitting beside it and
-- put the rider's feet through the deck.
local SIDES = { left = true, right = true }

local function merged(base: any, over: any): any
	local out = {}
	for key, value in pairs(base) do
		out[key] = value
	end
	for key, value in pairs(over) do
		if key == "name" or key == "order" then
			-- Label, not geometry.
		elseif key == "trick" then
			-- A stance may change what the TRICK looks like too, and the block
			-- it changes has the same shape as a pose -- `lean`, `left`,
			-- `right` -- so it merges by the same rule, one level in, applied
			-- to itself. Replacing it wholesale would have made a stance that
			-- wanted to drop one leg re-state the lean and both arm
			-- corrections, which is three chances to silently undo work that
			-- was measured against a grip.
			out[key] = merged(base[key] or {}, value)
		elseif SIDES[key] then
			local side = {}
			for field, at in pairs(base[key] or {}) do
				side[field] = at
			end
			for field, at in pairs(value) do
				side[field] = at
			end
			out[key] = side
		else
			out[key] = value
		end
	end
	return out
end

-- Memoised: this runs on every registration and on every apply, and the merge
-- allocates three tables. Only hits are kept -- a miss is one lookup anyway.
local specs: { [string]: any } = {}

local function specFor(style: string): any
	local cached = specs[style]
	if cached then
		return cached
	end

	local base, stance = splitStance(style)
	local spec = POSES[base]
	if not spec then
		return nil
	end

	-- An unknown stance falls back to the base pose rather than to nothing.
	-- Exactly the call the trick makes when a ride has no manual: the rider
	-- ends up sitting normally, which is a working state, rather than bolt
	-- upright on a moving bike, which reads as broken.
	if stance then
		local over = STANCES[base] and STANCES[base][stance]
		if over then
			spec = merged(spec, over)
		end
	end

	specs[style] = spec
	return spec
end

-- What the HUD offers for a style, default first. Keys and labels only:
-- nothing outside this file should be reading angles.
function RidePose.stances(style: string?): { any }
	local list = { { key = "", name = "Classic", order = 0 } }
	local available = if style then STANCES[(splitStance(style))] else nil
	if available then
		for key, spec in pairs(available) do
			table.insert(list, { key = key, name = spec.name or key, order = spec.order or 99 })
		end
		table.sort(list, function(a, b)
			return a.order < b.order
		end)
	end
	return list
end

-- Whether a style really has this stance, so the server can refuse a forged
-- one rather than publishing it and leaving every client to fall back.
function RidePose.hasStance(style: string?, stance: string?): boolean
	if not stance or stance == "" then
		return true
	end
	local available = if style then STANCES[(splitStance(style))] else nil
	return available ~= nil and available[stance] ~= nil
end

-- The style string a stance is published as. One place, so the "@" convention
-- cannot drift between the file that writes it and the file that reads it.
function RidePose.key(style: string, stance: string?): string
	if not stance or stance == "" then
		return style
	end
	return style .. STANCE_MARK .. stance
end

-- ============================================================
-- THE TRICK POSE
-- ============================================================
--
-- A manual and a wheelie tip the RIDE about its rear contact patch, and the
-- rider has to go with it. Without this the mechanism worked perfectly and
-- looked broken: the bike rotated its 30 degrees, the rider stayed bolt
-- upright, and their hands ended up 2.01 studs off the grips -- measured.
-- Putting the hands exactly on the bars is what made it obvious; before the
-- poses existed, the rider's arms hung at their sides anyway.
--
-- THIS IS COMPUTED, NOT TUNED, and that is the point.
--
-- Every other pose in this file was measured by hand because there was no
-- closed form -- reaching a handlebar is inverse kinematics. This one has an
-- exact answer, because the rider is not reaching for anything new: they are
-- holding the same grips and standing on the same deck, and the whole
-- assembly has simply rotated. So the trick pose is the base pose with ONE
-- extra transform applied to the LowerTorso -- the ride's own rotation,
-- re-expressed about the root -- and every limb below it follows for free,
-- keeping the contacts it already had.
--
-- Rotating the LowerTorso rather than the root, for the reason the whole file
-- exists: root pitch does not hold. The Humanoid rights it within a frame or
-- two, measured at -28 asked for and under -10 ever reached.
--
-- These two are the R15 defaults the rest of the file's measurements are
-- against: HipHeight 2.225 and a 2-stud root, so the ground sits 3.225 below
-- the root when `stand` is zero. Read off a live rig, not looked up.
local BASE_HIP = 2.225
local ROOT_HALF = 1.0

-- WHERE A LowerTorso POSE ACTUALLY ROTATES, and it is not the root origin.
--
-- A `Pose` CFrame is a JOINT transform, not a placement in root space: the
-- body swings about the root joint's attachment, which measures 1.252 studs
-- below the root centre. Measured, by posing the LowerTorso 40 degrees about
-- X and solving for the centre of the arc its part traced -- (0, -0.792,
-- -0.024) to (0, -0.884, +0.277).
--
-- Miss this and the trick delta is right in root space and applied in joint
-- space, which is a rotation about a point 1.25 studs out. It cost 0.64 studs
-- of hand-to-grip error -- a third of the way back to no fix at all, and the
-- kind of wrong that looks like a tuning problem and is not.
local ROOT_JOINT = CFrame.new(0, -1.252, 0)

-- Stance stripped first. A stance changes how the rider sits, never what they
-- are sitting on, so "bmx@onehand" has to find the same bike "bmx" does -- and
-- this hands back the ride KEY that phaseOf uses to find the model inside the
-- character, so missing it would leave every stanced rider stuck at phase 0.
local function rideForStyle(style: string): (any, string?)
	local bare = (splitStance(style))
	for key, ride in pairs(Config.RIDES) do
		if ride.style == bare then
			return ride, key
		end
	end
	return nil, nil
end

-- Where the ride is welded, in root space. RideService.mount builds exactly
-- this, and the two have to stay in step: everything below reads the machine's
-- rotation by comparing against it.
local function mountOf(ride: any): CFrame
	return CFrame.new(0, -(BASE_HIP + (ride.stand or 0) + ROOT_HALF), 0)
		* CFrame.Angles(0, math.pi - math.rad(ride.bodyYaw or 0), 0)
end

-- The ride's trick rotation, expressed about the ROOT instead of the model.
--
-- RideService tips the ride by tweening its mount's C0 by `inModel` -- a
-- rotation about the rear contact patch, in the ride's own space. The rider
-- needs the SAME rotation about the SAME world point, but their poses are in
-- root space, so it has to be conjugated through the mount transform. That
-- mount is `CFrame.new(0, -(hip + stand + rootHalf), 0)` turned by
-- `pi - bodyYaw`, which is exactly what RideService.mount welds the model on.
--
-- Conjugating rather than copying is what makes the skateboard work without a
-- special case: `bodyYaw = 90` turns the board's pitch into a ROLL from the
-- rider's point of view, which is correct -- you stand across a deck, so a
-- nose-up manual leans you toward the tail -- and it falls out of the maths
-- rather than needing to be noticed.
local function trickDelta(style: string): CFrame?
	local ride = rideForStyle(style)
	local trick = ride and ride.trick
	if not trick then
		return nil
	end

	local mount = mountOf(ride)
	local pivot = trick.pivot or 0
	local inModel = CFrame.new(0, 0, pivot)
		* CFrame.Angles(-math.rad(trick.pitch), 0, 0)
		* CFrame.new(0, 0, -pivot)

	-- Conjugated twice, and the two are different questions. `mount` moves the
	-- rotation from the RIDE's space into the root's; `ROOT_JOINT` moves it
	-- from the root's space into the one a Pose is actually written in.
	local inRoot = mount * inModel * mount:Inverse()
	local rigid = ROOT_JOINT:Inverse() * inRoot * ROOT_JOINT

	-- THE RIDER IS NOT BOLTED TO THE MACHINE, and that is the whole trick.
	--
	-- `rigid` alone rotates the whole body by the ride's exact pitch, which
	-- keeps every contact perfect and looks like the bike lifting the rider
	-- rather than the rider lifting the bike. A real wheelie is the other way
	-- round: the machine rotates further than the body does, and the ARMS take
	-- up the difference -- which is what a pull is.
	--
	-- So the body is turned back by the share of the pitch it does not take,
	-- and the limbs make up the rest (see the `trick` block on each pose).
	-- Rotating back about the ROOT JOINT is what makes this cost no new
	-- constant: that point is already where the body swings from, it is the
	-- rider's own hips, and post-multiplying puts the pivot exactly there.
	local spec = specFor(style)
	local lean = (spec and spec.trick and spec.trick.lean) or 1
	if lean >= 1 then
		return rigid
	end
	local upright = mount.Rotation
		* CFrame.Angles(math.rad((1 - lean) * trick.pitch), 0, 0)
		* mount.Rotation:Inverse()
	return rigid * upright
end
-- How far the pose drifts between its two keyframes, and how long that takes.
--
-- TWO keyframes, not one. A looping track with a single keyframe has zero
-- length, which is a shape the animation system handles badly; giving it a
-- second frame is free and sidesteps the question. Having done that, making
-- the two frames slightly different costs nothing and stops the rider being a
-- shop mannequin bolted to a moving board.
local BREATHE = 1.6
local SWAY = 2.2

local function pose(name: string, cf: CFrame, parent: Instance): Pose
	local p = Instance.new("Pose")
	p.Name = name
	p.CFrame = cf
	p.EasingStyle = Enum.PoseEasingStyle.Linear
	p.EasingDirection = Enum.PoseEasingDirection.InOut
	p.Parent = parent
	return p
end

local function angles(x: number?, y: number?, z: number?): CFrame
	return CFrame.Angles(math.rad(x or 0), math.rad(y or 0), math.rad(z or 0))
end

local NO_ADJUST: { [string]: number } = {}

-- `drift` is 0 on the first keyframe and 1 on the second. `adjust` is the
-- per-side offset a trick adds on top of the base pose -- the limb work that
-- takes up whatever rotation the body did not.
local function addKeyframe(seq: KeyframeSequence, spec: any, at: number, drift: number, delta: CFrame?, adjust: any?)
	local keyframe = Instance.new("Keyframe")
	keyframe.Time = at

	-- Identity, always. See the note above about root motion.
	local root = pose("HumanoidRootPart", CFrame.new(), keyframe)

	-- The trick delta pre-multiplies the base pose, so the whole body rotates
	-- about the ride's pivot and every limb keeps the contact it already had.
	local hips = CFrame.new(0, 0, spec.hipBack or 0)
		* angles(spec.hipPitch, spec.hipYaw, spec.hipRoll)
	local lower = pose("LowerTorso", if delta then delta * hips else hips, root)

	local upper = pose("UpperTorso",
		angles((spec.torso or 0) - SWAY * drift, spec.torsoYaw, spec.torsoRoll), lower)
	pose("Head", angles(spec.head, spec.headYaw, 0), upper)

	for _, side in ipairs({ "Left", "Right" }) do
		local s = spec[string.lower(side)] or {}
		local a = (adjust and adjust[string.lower(side)]) or NO_ADJUST
		local function v(key: string): number
			return (s[key] or 0) + (a[key] or 0)
		end

		local arm = pose(side .. "UpperArm", angles(v("armPitch"), v("armYaw"), v("armRoll")), upper)
		local lowerArm = pose(side .. "LowerArm", angles(v("elbow"), 0, 0), arm)
		pose(side .. "Hand", angles(v("wrist"), 0, 0), lowerArm)

		local leg = pose(side .. "UpperLeg", angles(v("hipFlex"), v("legYaw"), v("legRoll")), lower)
		local lowerLeg = pose(side .. "LowerLeg", angles(v("knee"), 0, 0), leg)
		pose(side .. "Foot", angles(v("ankle"), 0, 0), lowerLeg)
	end

	keyframe.Parent = seq
end

local function buildSequence(style: string, spec: any, delta: CFrame?, adjust: any?): KeyframeSequence
	local seq = Instance.new("KeyframeSequence")
	seq.Name = "RidePose_" .. style
	seq.Loop = true
	-- Action, matching the roll. Nothing else should be running -- RideService
	-- disables the Animate script on mount -- but a stray emote or a tool
	-- animation must not be able to stand the rider up on a moving bike.
	seq.Priority = Enum.AnimationPriority.Action

	addKeyframe(seq, spec, 0, 0, delta, adjust)
	addKeyframe(seq, spec, BREATHE, 1, delta, adjust)
	return seq
end

-- Registered once per style per client, not once per mount. The id is a
-- content hash, so registering the same sequence twice is wasted work rather
-- than a bug -- but a player hopping on and off at every gate would do it a
-- lot.
local ids: { [string]: string } = {}

-- A pose KEY is either a style ("bmx") or a style doing its trick
-- ("bmx#trick"). Splitting here keeps the two variants one lookup rather than
-- two parallel tables that could disagree about which styles exist.
--
-- "#" rather than "_" because a style could legitimately contain an
-- underscore, and a key that can be ambiguously parsed is a key that will be.
local TRICK_SUFFIX = "#trick"

local function splitKey(key: string): (string, boolean)
	if string.sub(key, -#TRICK_SUFFIX) == TRICK_SUFFIX then
		return string.sub(key, 1, #key - #TRICK_SUFFIX), true
	end
	return key, false
end

-- The sequence for one pose key, for the `animdump` admin command.
--
-- Resolves the key exactly as getAnimationId does -- same split, same spec,
-- same trick delta -- so what gets uploaded is byte-for-byte what Studio has
-- been registering and playing. Building it a second way here would be the
-- near-identical copy that drifts.
function RidePose.buildSequenceFor(key: string): KeyframeSequence?
	local style, tricking = splitKey(key)
	local spec = specFor(style)
	if not spec then
		return nil
	end
	local delta = if tricking then trickDelta(style) else nil
	if tricking and not delta then
		return nil
	end
	return buildSequence(key, spec, delta, if tricking then spec.trick else nil)
end

local function getAnimationId(key: string): string?
	if ids[key] then
		return ids[key]
	end
	local style, tricking = splitKey(key)
	local spec = specFor(style)
	if not spec then
		return nil
	end

	local delta = if tricking then trickDelta(style) else nil
	if tricking and not delta then
		-- The ride has no trick. Nothing to build, and the caller falls back
		-- to the plain pose rather than standing the rider up.
		return nil
	end

	-- AN UPLOADED ASSET FIRST. Registering one is Studio-only, so in a
	-- published game every pose below falls through to the warning and no
	-- rider is ever posed -- the ride carries them at the right speed sitting
	-- in the default rest pose. See Config.ANIMATIONS.
	local uploaded = Config.animationId(key)
	if uploaded then
		ids[key] = uploaded
		return uploaded
	end

	local ok, id = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(
			buildSequence(key, spec, delta, if tricking then spec.trick else nil))
	end)
	if not ok or type(id) ~= "string" then
		-- Never fail silently. Without this the ride still works and only the
		-- pose is missing, which is exactly the kind of half-broken that gets
		-- mistaken for a design decision.
		warn(("[RidePose] could not register the '%s' pose, and Config.ANIMATIONS "):format(key)
			.. "has no id for it. In a published game this is expected -- upload "
			.. "the sequence and put its id there. (" .. tostring(id) .. ")")
		return nil
	end
	ids[key] = id
	return id
end

function RidePose.has(style: string?): boolean
	return style ~= nil and specFor(style) ~= nil
end

-- NO TRACK CACHE. The animator is asked what it is already playing.
--
-- The obvious cache -- a table keyed by Animator, weak-keyed so a character
-- leaving takes its tracks with it -- is a TRAP here, and it was measured
-- being one: five copies of the same pose playing at once on a single rider
-- after about a second.
--
-- Lua's collector cannot see the DataModel's reference to an Instance, because
-- that reference lives in C++. So an Animator sitting in a live character, in
-- a weak-keyed table, is reachable to the engine and garbage to the collector:
-- the entry gets dropped whenever a GC runs, the next call finds no track,
-- loads a second one, and plays it ON TOP of the first -- which nothing ever
-- stopped. At a tenth of a second per poll that stacks fast, and a stack of
-- identical Action tracks blends into a pose that is subtly wrong and drifts.
--
-- Asking the animator is authoritative, needs no bookkeeping, is immune to
-- both the collector and a respawn, and self-heals if a duplicate ever does
-- appear. It costs one array walk per rider per poll, over maybe a dozen
-- tracks. (DodgeRoll keeps the weak-keyed version. It is a one-shot that stops
-- its own track before replaying, so a dropped entry leaks a track rather than
-- stacking a pose -- worth fixing, but it is not this bug.)
local PREFIX = "RidePose_"

-- ZERO IS A TERMINAL WEIGHT, AND NOTHING SAYS SO.
--
-- Measured on a live Animator: a track played at weight 0 never starts
-- (IsPlaying false immediately), and AdjustWeight(0) on a running one STOPS
-- it -- permanently, since AdjustWeight(1) afterwards does not bring it back.
-- Which is reasonable of the engine, because that is exactly what Stop() is:
-- a fade to zero weight.
--
-- It cost a whole afternoon, because it fails in the shape of a tuning
-- problem rather than an error. The trick track was started at 0 and dialled
-- up, so it was dead on arrival and the rider never leaned at all; and once a
-- weight-0 floor had been reached at the END of a trick, apply() rebuilt the
-- track every tenth of a second forever and every one of them was born dead.
-- No warning, no exception, and a rider who leans on their first wheelie and
-- never again.
--
-- 0.001 is alive and verified through repeated up-and-down cycles. What it
-- costs is that the two ends are 1/1.001 rather than exactly 1: a 0.024
-- degree lean at rest against a 24 degree one at the top.
local FLOOR = 0.001

local function startTrack(animator: Animator, name: string, weight: number)
	local id = getAnimationId(string.sub(name, #PREFIX + 1))
	if not id then
		return
	end

	local animation = Instance.new("Animation")
	animation.Name = name
	animation.AnimationId = id

	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok or not track then
		warn(("[RidePose] could not load the '%s' pose: %s"):format(name, tostring(track)))
		return
	end

	track.Priority = Enum.AnimationPriority.Action
	track.Looped = true
	-- The trick variant starts at the floor and is dialled in by setPhase.
	-- Fading it in on a timer is the bug this whole arrangement replaces.
	track:Play(0.2, math.max(weight, FLOOR), 1)
end

-- Puts the right set of pose tracks on this animator and stops everything
-- else this module started. Passing nil for the style is how a dismount
-- clears the pose.
--
-- BOTH variants run at once on a ride that has a trick -- the base pose and
-- the trick pose, blended by weight rather than swapped. That is what lets
-- setPhase put the rider at any point between them, which is what it takes to
-- follow a machine that is part way through rotating.
--
-- A ride with no trick gets the plain pose alone: the scooter and the
-- hoverboard have no manual to do, and holding the button on one of them
-- should leave the rider standing there, not standing up.
function RidePose.apply(animator: Animator, style: string?)
	local wanted: { [string]: boolean } = {}
	if style and specFor(style) then
		wanted[PREFIX .. style] = true
		if getAnimationId(style .. TRICK_SUFFIX) then
			wanted[PREFIX .. style .. TRICK_SUFFIX] = true
		end
	end

	local held: { [string]: boolean } = {}
	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if string.sub(track.Name, 1, #PREFIX) == PREFIX then
			if wanted[track.Name] and not held[track.Name] then
				-- Exactly one of each survives. A second copy of the RIGHT
				-- pose is still a duplicate, and stopping it is how a stack
				-- unwinds itself rather than needing to be prevented.
				held[track.Name] = true
			else
				track:Stop(0.15)
			end
		end
	end

	for name in pairs(wanted) do
		if not held[name] then
			startTrack(animator, name, if string.find(name, TRICK_SUFFIX, 1, true) then FLOOR else 1)
		end
	end
end

-- HOW FAR THROUGH ITS TRICK THE MACHINE ACTUALLY IS, read off the machine.
--
-- Not off a clock, and not off the attribute that says the button is held.
-- The ride is tipped by a C0 tween on the server and the rider is posed by an
-- animation on every client, and those are two different curves over two
-- different durations -- so anything that starts both and hopes has the rider
-- somewhere the ride is not for the whole of the move. Measured on the
-- shipped version: the bike reached its full 30 degrees at 0.22s and the
-- rider did not arrive until 0.30, with the hands 1.33 studs off the grips in
-- between. The endpoints were perfect, which is exactly why it survived.
--
-- Asking the ride removes the coupling instead of tuning it. The C0 write
-- does not replicate as a C0 -- see RideService -- but its RESULT does, so
-- the chassis really is where it looks like it is on every machine, and a
-- rider posed from that number cannot be out of step with it whatever curve,
-- delay or interruption the tween had. Same idea as the officer's stride
-- being a function of distance travelled rather than of a timer.
function RidePose.phaseOf(character: Instance?, style: string?): number
	if not character or not style then
		return 0
	end
	local ride, key = rideForStyle(style)
	local trick = ride and ride.trick
	if not trick or not key then
		return 0
	end

	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local model = character:FindFirstChild("Ride_" .. key) :: Model?
	local chassis = model and model.PrimaryPart
	if not root or not chassis then
		return 0
	end

	-- Back into the ride's own space, where the tip is a rotation about X and
	-- nothing else -- so it reads off the euler directly, with no axis to get
	-- wrong on the rides that are ridden sideways.
	local moved = mountOf(ride):Inverse() * (root.CFrame:Inverse() * chassis.CFrame)
	local x = select(1, moved:ToEulerAnglesXYZ())
	return math.clamp(math.deg(-x) / trick.pitch, 0, 1)
end

-- Leans the rider to match `phase`, 0 at rest and 1 at the top of the trick.
--
-- Creates nothing: it only touches tracks apply() has already started, so it
-- is safe to call every frame. Blending two poses by weight is what makes an
-- in-between position expressible at all -- a Pose is a fixed shape, and
-- there is no other way to ask for two thirds of one.
function RidePose.setPhase(animator: Animator, style: string?, phase: number)
	if not style or not specFor(style) then
		return
	end
	local baseName = PREFIX .. style
	local trickName = baseName .. TRICK_SUFFIX
	local w = math.clamp(phase, 0, 1)

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track.Name == trickName then
			track:AdjustWeight(math.max(w, FLOOR), 0)
		elseif track.Name == baseName then
			track:AdjustWeight(math.max(1 - w, FLOOR), 0)
		end
	end
end

-- Stops every pose this module started on an animator. Separate from
-- apply(animator, nil) only so the intent reads at the call site.
function RidePose.clear(animator: Animator)
	RidePose.apply(animator, nil)
end

return RidePose
