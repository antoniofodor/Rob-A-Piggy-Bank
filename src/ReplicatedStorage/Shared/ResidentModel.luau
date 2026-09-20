--!strict
--
-- THE NEIGHBOUR STANDING ON THE LAWN.
--
-- A plot with a resident on it had a name on the sign, a pig that fills and
-- a dog, and nobody at all to look at. Eight houses on a street and seven of
-- them visibly empty is the "abandoned game" half of the problem residents
-- were built to fix -- the coins half was fixed and the picture was not.
--
-- IT IS THE DRIP STATUE'S OWN GEOMETRY, NOT A SECOND HUMAN BUILT BESIDE IT.
-- That figure is the most characterful thing in this repo -- a face set INTO
-- the head rather than stuck on it, a nose that tapers over four balls, a
-- smirk that is one rotated bar rather than a staircase, hair cut with CSG
-- and a notch razored into it -- and every one of those decisions is written
-- up and measured. Building a second humanoid from scratch would be the
-- near-identical copy this project keeps recording as the thing that drifts,
-- and it would be worse.
--
-- WHAT CHANGES IS THREE THINGS: the plinth comes off (a resident is a person,
-- not a monument), it is scaled to human height, and it is recoloured per
-- plot so the street is seven different neighbours rather than seven of the
-- same one.
--
-- IT CANNOT BLOCK ANYBODY, and that is inherited rather than added. Every
-- part `Decor` builds is `CanCollide` and `CanQuery` off, because the lawn is
-- ground a defender defends and a thief runs across. A resident is scenery
-- that happens to have a face.
--
-- IT WALKS, AND IT CARRIES ITS NAME. `buildRig` captures the limbs once and
-- `poseWalk` swings them about their own joints, which is `PoliceModel`'s
-- officer with two changes: the swing is a stroll rather than a run, and the
-- pieces are DISCOVERED rather than authored, because this figure was built
-- as a lawn ornament and has no piece table to read.
--
-- WHAT IT STILL DOES NOT DO IS DEFEND. It does not see, and it raises no
-- alarm of its own -- the dog is what defends a plot, and giving the figure a
-- second way to notice an intruder would be two things that can both
-- hard-stop one thief on one lawn, which is exactly what `Config.DOG_WATCH`
-- refuses for the owner being home.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Decor = require(ReplicatedStorage.Shared.Decor)
local Theme = require(ReplicatedStorage.Shared.Theme)

local ResidentModel = {}

-- The statue stands about 14.6 studs from sole to crown once its plinth is
-- gone; a Roblox character is roughly five. Scaled to 5.6 the neighbour is
-- the same size as the player robbing them, which is the only height that
-- reads correctly next to a twelve-stud piggy bank.
local TARGET_HEIGHT = 5.6

-- HOW FAR A LIMB SWINGS, and how much stride a stud buys.
--
-- Both are the officer's numbers scaled to this figure rather than chosen
-- again. `PoliceModel` swings 40 degrees at a run; a neighbour strolling to a
-- neighbour's house is not running, so the legs take 26 and the arms 18 --
-- an arm that swings as far as a leg reads as a march.
--
-- STRIDE_PER_STUD is what makes the walk a function of DISTANCE TRAVELLED
-- rather than of a clock, which is the whole reason the officer's stride
-- cannot desync from the officer. A resident that is slowed, blocked or
-- standing still has its legs together by construction, with no "am I
-- moving" test anywhere.
local LEG_SWING = math.rad(26)
local ARM_SWING = math.rad(18)

-- HOLDING THE STOLEN PIG, and the second number is the one that matters.
--
-- A NEIGHBOUR CARRIED A FLOATING PIG FOR THE WHOLE LIFE OF THE FEATURE. The
-- miniature has always been pivoted to the chest and the arms have always
-- gone on swinging beside it, which is exactly the fault `CarryPose` was
-- written to fix on the player -- recorded there as "the pig FLOATED in front
-- of somebody who was visibly not holding it". Same mechanism built, same
-- thing never drawn.
--
-- BOTH SIGNS WERE MEASURED ON A LIVE FIGURE AND BOTH CAME BACK THE OPPOSITE
-- WAY ROUND FROM THE ONE THIS COMMENT FIRST ASSERTED. Swept rather than
-- reasoned, which is the same method the ride stances record for `legRoll`:
-- drive one axis at a time on a real rig and read the hand back, because a
-- sign convention inferred from a field name is a coin flip.
--
-- PITCH IS NEGATIVE TO GO FORWARD. The walk's own `swing` is applied as a
-- positive X rotation and swings an arm BACKWARD -- measured, a hand at
-- z -0.36 on a positive angle -- so a carry built on a positive pitch put
-- both arms behind the figure, holding a pig that was in front of it.
--
-- AND THE SHOULDERS ABDUCT, WHICH IS `CarryPose`'S FINDING ARRIVING INTACT
-- ON A SECOND FIGURE: THE ELBOWS HAVE TO BE OUTSIDE THE SILHOUETTE OF WHAT
-- IS BEING HUGGED. Measured on the built figure:
--
--     mini piggy      local x -1.41 .. 0.79   (2.20 across, centred -0.31)
--     arms hang at    local x -1.31 and 0.68  (+-0.995 off the centreline)
--
-- so both arms hang INSIDE the pig's outline and are hidden by it before the
-- pose does anything at all. Swung straight forward they stay hidden, and
-- the figure reads as a pig stuck to a chest with no arms anywhere -- which
-- is worse than the floating pig it replaces, because that at least had arms
-- beside it. At 14 degrees the hands reach 1.309 off the centreline and the
-- upper arms 1.148, against pig flanks at 1.095 -- so both show, and the arm
-- is 0.405 thick so what actually reads is about a quarter of a stud of limb
-- either side of the animal.
--
-- WHAT IT COSTS IS THE GRIP, AND A ONE-PIECE ARM CANNOT HAVE BOTH. `CarryPose`
-- abducts the shoulder AND rotates the elbow back in, landing the hand on the
-- flank; this rig's arm is a single rigid piece with no elbow, so pushing the
-- elbow clear pushes the hand out with it and leaves it a fifth of a stud off
-- the pig. Clearance wins: a thief is read from the pavement, where the
-- silhouette is the whole message and a fifth of a stud is nothing.
--
-- AND THE PITCH WAS CHOSEN BY LOOKING, WHICH THE NUMBERS COULD NOT DO. Four
-- pairs were built side by side and photographed -- 80/20, 62/16, 50/14 and
-- 40/12 -- and every one of them satisfies the clearance arithmetic above.
-- They do not read alike at all. At 80 the arm is almost horizontal, so from
-- the front the two limbs stick straight out either side and the figure reads
-- as a pig with WINGS. Dropping the pitch swings them down and forward, and
-- by 50 they come up under the pig's lower flanks and read as arms around
-- something heavy. That difference is invisible in every measurement on this
-- page, which is the whole reason the pose was shot rather than solved.
--
-- AND THE FIRST VERSION OF THIS COMMENT HAD IT EXACTLY BACKWARDS, off a
-- measurement that looked fine. Summing `part.Position` over the mini's parts
-- reported it 1.00 wide, which made the arms look like they already hung
-- clear and sent the pose INWARD -- and the render was the pig swallowing the
-- entire upper body. A position is a centre and says nothing about extent:
-- the honest figure comes from projecting each part's own size through its
-- own CFrame, which is what `CLAUDE.md` means by MEASURE A MODEL PER PART,
-- and it is 2.20. The picture is what caught it, on a number that had already
-- been "measured".
local CARRY_PITCH = math.rad(50)
local CARRY_SPREAD = math.rad(14)
local STRIDE_PER_STUD = 1.9

-- One limb, and everything needed to swing it about a joint it does not own.
--
-- `offset` and `hinge` are captured in the MODEL'S OWN FRAME after scaling,
-- because that is the only frame in which they are stable: the figure is
-- scaled by ScaleTo and then pivoted onto a plot, so an authored constant
-- from Decor's builder describes a statue that is 14.6 studs tall and no
-- longer exists.
export type Piece = {
	part: BasePart,
	-- The limb's authored place in the model's own frame, ROTATION INCLUDED.
	-- The officer gets away with storing a bare position because every piece
	-- of it is an axis-aligned box; half of this figure is not -- the arms are
	-- `cylinderY`, which rolls a cylinder ninety degrees about Z -- so a pose
	-- rebuilt from a position alone would stand both arms up like posts.
	cf: CFrame,
	hinge: number,
	swing: number,
	foot: boolean,
	-- WHETHER THIS IS AN ARM, which the walk does not care about and the
	-- CARRY does. A neighbour holding a stolen piggy has to stop swinging the
	-- two limbs that are supposed to be around it, and `swing` cannot say so
	-- on its own: a leg and an arm differ there only by magnitude and sign,
	-- both of which a carry overrides anyway.
	arm: boolean,
	-- THE PIECE THIS ONE IS BOLTED TO, for anything that must move as part of
	-- a rigid assembly rather than on its own arc. A foot is a shoe AND a
	-- sole, and neither tilts -- so if each took its own swung position they
	-- would separate, because they sit at different heights and a rotation
	-- about the hip moves a lower part FURTHER. Measured on this figure at a
	-- 26-degree swing: the shoe travels 2.08 studs and the sole 2.26, so the
	-- sole would slide 0.18 studs out from under the shoe at every stride.
	--
	-- Same family as the officer's ankle pulling apart by 0.119 studs, which
	-- this file's `swung` comment already records -- there the fix was to
	-- share a hinge, here it is to share a REFERENCE.
	rigidTo: Piece?,
}

export type Rig = {
	pieces: { Piece },
	-- How far the soles sit below the model pivot at rest. The caller drives
	-- this figure by where its FEET go -- the same ground-origin convention
	-- `PoliceModel.buildOfficer` and `poseOfficer` share -- because a pivot
	-- is an accident of which part the builder made first and the ground is
	-- a fact about the world.
	feetBelowPivot: number,
}

-- Seven neighbours, seven looks. Indexed by plot so a house keeps the same
-- resident across an owner arriving and leaving, exactly as the NAME does.
local PALETTES = {
	{ shirt = Color3.fromRGB(206, 78, 92),  trousers = Color3.fromRGB(64, 76, 112), hair = Color3.fromRGB(58, 42, 32) },
	{ shirt = Color3.fromRGB(72, 132, 196), trousers = Color3.fromRGB(96, 84, 70),  hair = Color3.fromRGB(158, 116, 62) },
	{ shirt = Color3.fromRGB(238, 186, 74), trousers = Color3.fromRGB(70, 70, 78),  hair = Color3.fromRGB(38, 32, 30) },
	{ shirt = Color3.fromRGB(112, 168, 96), trousers = Color3.fromRGB(102, 82, 60), hair = Color3.fromRGB(190, 158, 96) },
	{ shirt = Color3.fromRGB(176, 118, 196), trousers = Color3.fromRGB(58, 62, 82), hair = Color3.fromRGB(112, 74, 48) },
	{ shirt = Color3.fromRGB(240, 140, 80), trousers = Color3.fromRGB(88, 92, 100), hair = Color3.fromRGB(72, 56, 44) },
	{ shirt = Color3.fromRGB(96, 186, 176), trousers = Color3.fromRGB(74, 66, 58),  hair = Color3.fromRGB(206, 186, 150) },
	{ shirt = Color3.fromRGB(226, 154, 178), trousers = Color3.fromRGB(66, 74, 66), hair = Color3.fromRGB(48, 44, 56) },
}

-- Which parts wear which colour. By NAME, because that is what the statue's
-- own builder names them, and a resident that silently stopped being
-- recoloured when a part was renamed would just look like every other one.
--
-- THE MATERIAL GOES TO `SmoothPlastic` WITH THE COLOUR, AND ONLY LOOKING AT
-- IT CAUGHT THAT. The statue authors its tee and jeans in `Fabric`, which is
-- correct there -- it is one figure and the weave reads. But this project
-- already has the rule written down from the tube man and the duffel bag:
-- *Fabric is a dark, noisy texture, not a colour.* Recoloured and left in
-- Fabric, a shirt set to (206, 78, 92) rendered as dark navy and one set to
-- blue rendered olive -- so seven neighbours who exist to be TOLD APART all
-- came out the same muddy brown, and every measurement said the colours had
-- been applied correctly, because they had.
--
-- Where colour carries identity, the material has to let the colour through.
local SHIRT = { Tee = true, Sleeve = true }
local TROUSERS = { Leg = true }
local HAIR = { Hair = true }

-- The vertical extent of a model, measured PER PART IN WORLD SPACE.
--
-- Never `Model:GetBoundingBox`. That is oriented by the model's pivot, and a
-- model with no PrimaryPart takes its pivot from whichever part the builder
-- happened to create first -- which for this figure is a rolled cylinder, so
-- the box comes back with its axes swapped. This project has lost two
-- separate decisions to exactly that: a house measured by its bounding box
-- reported its FX at altitude, and the "widest lawn ornament" turned out to
-- be a height.
local function verticalExtent(model: Model): (number, number)
	local low, high = math.huge, -math.huge
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local cf, s = d.CFrame, d.Size
			local halfY = math.abs(cf.RightVector.Y) * s.X / 2
				+ math.abs(cf.UpVector.Y) * s.Y / 2
				+ math.abs(cf.LookVector.Y) * s.Z / 2
			low = math.min(low, cf.Position.Y - halfY)
			high = math.max(high, cf.Position.Y + halfY)
		end
	end
	return low, high
end

-- The highest and lowest points of one part, in the frame `pivot` describes.
--
-- Projected through the part's own CFrame rather than read off `Size.Y`,
-- because half this figure is rotated: the arms are `cylinderY`, which rolls
-- a cylinder ninety degrees about Z, so its `Size.Y` is a DIAMETER and its
-- length lives on X. Reading the property would put the shoulder joint
-- inside the elbow.
local function localSpan(pivot: CFrame, part: BasePart): (number, number)
	local cf = pivot:ToObjectSpace(part.CFrame)
	local s = part.Size
	local half = math.abs(cf.RightVector.Y) * s.X / 2
		+ math.abs(cf.UpVector.Y) * s.Y / 2
		+ math.abs(cf.LookVector.Y) * s.Z / 2
	return cf.Position.Y - half, cf.Position.Y + half
end

-- WHICH PARTS ARE LIMBS, AND WHICH SIDE EACH ONE IS ON.
--
-- COLLECTED BY WALKING THE MODEL AND SPLIT BY X-SIGN, NEVER BY NAME. The
-- statue is built in a mirrored `for sx = -1, 1, 2` loop, so there are two
-- parts called `Leg`, two called `Shoe`, two `Arm` and two `Sleeve` -- and
-- `FindFirstChild("Leg")` returns the same one twice, which would swing one
-- leg and leave the other planted. This project has already paid for that
-- exact trap twice, on the castle's four `Finial`s and the wheelie bin's two
-- `Lid`s, and both entries say the same thing: walk the model.
--
-- THE ARMS SWING OPPOSITE THE LEG ON THEIR OWN SIDE. That is what a gait is
-- -- right arm forward with left leg -- and getting the sign wrong produces
-- a figure that paces like a toy soldier, which reads as broken rather than
-- as a different walk.
-- EVERY PART OF A LIMB, AND THIS LIST WAS MISSING HALF OF THEM.
--
-- The figure is built with four parts per leg -- `Shoe`, `Sole`, `Leg` and
-- `Ankle` -- and this collected two. So on every walking neighbour in the
-- game the DENIM and the CANVAS swung while the near-white SOLE and the
-- skin-coloured ANKLE stood still: reported as a white part displaced,
-- lagging behind the foot, which is exactly what it is. The hands did the
-- same thing on the arms.
--
-- It is the `Finial` trap in its quietest form. Nothing errors, the figure
-- still walks, and the only symptom is a shoe leaving its own sole behind --
-- which reads as a rendering glitch rather than as a list with two names
-- missing from it. Collected by NAME, so a part added to `builders.dripstatue`
-- and not added here is silent again: the check is to build the figure and
-- count the pieces, which `build` now does.
local LEG_PARTS = { Leg = true, Shoe = true, Sole = true, Ankle = true }
local ARM_PARTS = { Arm = true, Sleeve = true, Hand = true }

-- WHAT MAY NOT TILT, AND WHY IT IS A SET RATHER THAN THE ONE NAME IT WAS.
--
-- A shoe turned with its leg dips its toe through the grass -- 0.45 studs at
-- a 40-degree swing on the officer -- and no body drop fixes it, because the
-- sink scales with the SHOE'S length rather than with the leg's. The sole is
-- under the shoe and has to do whatever the shoe does or it shears out of it.
--
-- The ANKLE is deliberately NOT here: it is the shin rather than the foot, it
-- is narrower than both the jean above it and the shoe below it, so it hides
-- inside both, and tilting is what keeps it attached to the cuff it comes out
-- of.
local FLAT_PARTS = { Shoe = true, Sole = true }

local function buildRig(model: Model, feetBelowPivot: number): Rig
	local pivot = model:GetPivot()

	-- The joints are derived from the limbs themselves rather than pinned.
	-- A hip is the top of the leg and a shoulder is the top of the arm, so a
	-- figure rescaled or reproportioned keeps its joints where its geometry
	-- actually is -- the same argument the fence audit makes for asking
	-- `jumpReach` rather than a constant somebody typed.
	local hipY, shoulderY = -math.huge, -math.huge
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local _, top = localSpan(pivot, d)
			if d.Name == "Leg" then
				hipY = math.max(hipY, top)
			elseif d.Name == "Arm" then
				shoulderY = math.max(shoulderY, top)
			end
		end
	end

	-- Collected before any side is decided, because WHERE THE MIDDLE IS has
	-- to be measured before left and right mean anything.
	local found: { { part: BasePart, cf: CFrame, leg: boolean } } = {}
	local sumX = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and (LEG_PARTS[d.Name] or ARM_PARTS[d.Name]) then
			local cf = pivot:ToObjectSpace(d.CFrame)
			table.insert(found, { part = d, cf = cf, leg = LEG_PARTS[d.Name] ~= nil })
			sumX += cf.Position.X
		end
	end

	-- THE CENTRELINE IS THE LIMBS' OWN CENTROID, NEVER THE PIVOT'S X=0, and
	-- the difference is not academic. A Model with no PrimaryPart takes its
	-- pivot from whichever part the builder happened to create FIRST, so the
	-- pivot is an accident: measured on this figure, the limbs sit at
	-- -1.31, -0.72, +0.09 and +0.68 about a centroid of **-0.315**, so the
	-- whole body is offset a third of a stud from the frame it is described
	-- in.
	--
	-- Splitting on x < 0 still happened to give the right answer, because
	-- both pairs straddle zero -- but the nearer leg sits only 0.09 studs
	-- from that boundary. Any change to the statue's geometry, or to which
	-- part Decor builds first, drops BOTH legs on the same side and the
	-- figure scissors them together in lockstep: a silent break that looks
	-- like a stiff walk rather than like a bug. Measuring the middle cannot
	-- have that failure at any offset.
	local centreX = if #found > 0 then sumX / #found else 0

	local pieces: { Piece } = {}
	for _, f in ipairs(found) do
		local hinge = if f.leg then hipY else shoulderY
		if hinge > -math.huge then
			-- Left is the side below the centreline, and the arm there takes
			-- the opposite sign so the diagonal reads as a walk.
			local side = if f.cf.Position.X < centreX then -1 else 1
			table.insert(pieces, {
				part = f.part,
				cf = f.cf,
				hinge = hinge,
				swing = if f.leg then side * LEG_SWING else -side * ARM_SWING,
				foot = FLAT_PARTS[f.part.Name] ~= nil,
				arm = not f.leg,
				rigidTo = nil,
			})
		end
	end

	-- BOLT EACH FOOT PART TO THE SHOE ON ITS OWN SIDE. The shoe is the
	-- reference because it is the piece the no-tilt rule was written for; the
	-- sole then rides it rather than computing an arc of its own. Matched on
	-- the SIGN OF X ABOUT THE CENTROID -- the same test that decides which
	-- side a limb is on a few lines above -- rather than on nearest distance,
	-- which would pair a sole with the far shoe the moment the figure is
	-- reproportioned.
	local shoeBySide: { [number]: Piece } = {}
	for _, p in ipairs(pieces) do
		if p.part.Name == "Shoe" then
			shoeBySide[if p.cf.Position.X < centreX then -1 else 1] = p
		end
	end
	for _, p in ipairs(pieces) do
		if p.foot and p.part.Name ~= "Shoe" then
			p.rigidTo = shoeBySide[if p.cf.Position.X < centreX then -1 else 1]
		end
	end

	return { pieces = pieces, feetBelowPivot = feetBelowPivot }
end

-- Puts one neighbour on the ground at `groundCF` mid-stride.
--
-- `stride` is HOW FAR THEY HAVE WALKED, in studs, not a phase and not a
-- clock. Everything follows from that: a resident standing still has its
-- legs together with no test for it, one that is slowed steps in proportion,
-- and the animation cannot desync from the movement because it IS the
-- movement. The officer's own comment makes the same argument and it is the
-- reason this is worth copying rather than tweening.
--
-- Rebuilt from the captured offsets every call rather than nudged from the
-- last pose, so a dropped frame cannot accumulate into drift.
function ResidentModel.poseWalk(model: Model, rig: Rig, groundCF: CFrame, stride: number,
	carry: boolean?)
	local wave = math.sin(stride * STRIDE_PER_STUD)

	-- The limb's authored frame, turned about its own joint.
	local function swung(piece: Piece): CFrame
		-- The joint takes the piece's own X and the BODY's Z, never the
		-- piece's Z. A shoe is authored forward of the ankle because it is a
		-- foot and points somewhere, and hanging it on a hinge that far
		-- forward puts the two limbs on two different arcs -- measured on the
		-- officer as the ankle pulling apart by 0.119 studs mid-stride.
		local joint = Vector3.new(piece.cf.Position.X, piece.hinge, 0)
		-- CARRYING: THE ARMS STOP WALKING AND THE LEGS DO NOT.
		--
		-- This is `CarryPose`'s job on a figure that cannot use it. A player
		-- thief holds the pig through a partial-body ANIMATION -- upper body
		-- posed, run cycle still driving the legs underneath -- and a
		-- resident has no Humanoid and no Animator, so there is nothing to
		-- play. What it has is this function, which is already posing every
		-- limb from a stride, so the carry is one branch: arms leave the wave
		-- and take a fixed hold, legs carry on walking.
		--
		-- THE SIDE IS READ OFF THE PIECE'S OWN SWING rather than stored
		-- again. An arm's `swing` is `-side * ARM_SWING`, so its sign already
		-- says which side of the body it is on, and a second field saying the
		-- same thing is the kind of pair that drifts.
		if carry and piece.arm then
			local side = if piece.swing > 0 then -1 else 1
			-- The pitch is negated and the spread is not, and both signs came
			-- off a sweep rather than off the field names -- see above.
			return CFrame.new(joint)
				* CFrame.Angles(-CARRY_PITCH, 0, side * CARRY_SPREAD)
				* CFrame.new(-joint)
				* piece.cf
		end
		return CFrame.new(joint)
			* CFrame.Angles(wave * piece.swing, 0, 0)
			* CFrame.new(-joint)
			* piece.cf
	end

	-- PASS ONE: plant the feet. Swinging a leg about the hip lifts the foot
	-- on the end of it, so the body drops by however far the LOWER foot rose
	-- or the figure walks on tiptoe above the grass. Measured off the feet
	-- rather than derived from the angle, and seeded at infinity rather than
	-- zero -- BOTH feet rise when the legs split, because cosine does not
	-- care which way a leg went, so a zero seed is always the minimum and the
	-- body never comes down at all.
	-- MEASURED ON THE REFERENCE FOOT, not on every foot part. A sole is bolted
	-- to its shoe and therefore rises with it exactly, so measuring both says
	-- the same thing twice -- and measuring the sole's OWN arc, which it does
	-- not travel, would plant the body against a number nothing on the figure
	-- follows.
	local rise = math.huge
	for _, piece in ipairs(rig.pieces) do
		if piece.foot and piece.rigidTo == nil then
			rise = math.min(rise, swung(piece).Position.Y - piece.cf.Position.Y)
		end
	end
	if rise == math.huge then
		rise = 0
	end

	-- The bob is not tuned: it is whatever planting the lower foot requires,
	-- so raising LEG_SWING raises the bounce for free.
	local pivot = groundCF * CFrame.new(0, rig.feetBelowPivot - rise, 0)
	model:PivotTo(pivot)

	-- PASS TWO: place every limb, in the frame the body has just landed in.
	for _, piece in ipairs(rig.pieces) do
		local at = swung(piece)
		if piece.rigidTo then
			-- RIDES ITS REFERENCE RATHER THAN ITS OWN ARC. The authored offset
			-- from the shoe is preserved exactly, so the foot stays one solid
			-- object however far the leg swings -- which is the whole reason
			-- the sole stopped shearing out from under the shoe.
			local ref = swung(piece.rigidTo)
			local delta = piece.cf.Position - piece.rigidTo.cf.Position
			piece.part.CFrame = pivot * CFrame.new(ref.Position + delta)
				* piece.cf.Rotation
		elseif piece.foot then
			-- THE FEET TRAVEL WITH THE LEG AND DO NOT TILT, which is a
			-- measurement rather than a style choice. A shoe turned with its
			-- leg dips its toe through the grass -- the officer's own entry
			-- has it at 0.45 studs at a 40-degree swing -- and no body drop
			-- fixes it, because the sink scales with the SHOE'S LENGTH rather
			-- than with the leg's. Distance is preserved by the rotation, so
			-- taking the position and keeping the authored rotation cannot
			-- pull the foot off the ankle.
			piece.part.CFrame = pivot * CFrame.new(at.Position) * piece.cf.Rotation
		else
			piece.part.CFrame = pivot * at
		end
	end
end

-- Put a line over a neighbour's head, or take it down with no argument.
--
-- THE MODEL CARRIES THE BUBBLE, SO THIS IS A PROPERTY WRITE AND NOT A BUILD.
-- Everything is already there and already replicated; speaking is two writes
-- and going quiet is one, which is what makes it affordable to do on the
-- server where one line can be true for everybody.
--
-- SILENT ON A FIGURE THAT HAS NO BUBBLE rather than an error. A resident
-- whose head failed to build is already a cosmetic fault behind a pcall --
-- the same call `Decor.prewarm` makes -- and a neighbour who cannot speak
-- must never be a plot that cannot be robbed.
function ResidentModel.say(model: Model?, line: string?)
	if not model then
		return
	end
	local head = model:FindFirstChild("Head", true)
	local bubble = head and head:FindFirstChild("Speech")
	if not (bubble and bubble:IsA("BillboardGui")) then
		return
	end
	local said = bubble:FindFirstChild("Said")
	if line and line ~= "" and said and said:IsA("TextLabel") then
		said.Text = line
		bubble.Enabled = true
	else
		bubble.Enabled = false
	end
end

-- Builds one neighbour with their feet on `groundY`, standing at `at` and
-- facing whatever `at` faces. Every builder in this repo authors facing +Z
-- and plot-local +Z is the street on both rows, so an unrotated plot CFrame
-- puts them looking out at the pavement with nothing to remember.
function ResidentModel.build(plotIndex: number, name: string, at: CFrame, groundY: number, parent: Instance): (Model?, Rig?)
	-- Built DETACHED and parented at the end. The statue's hair is a CSG
	-- subtract, and while `Decor.prewarm` caches the template at server start
	-- the very first call can still yield -- so a model assembled straight
	-- into the world could be seen at the origin for a frame.
	local staging = Instance.new("Folder")
	-- `buildFigure` rather than `buildOne("dripstatue")`: the Drip Statue is
	-- retired from the lawn catalogue, and a key lookup would return nil and
	-- empty the whole street behind the guard below.
	local model = Decor.buildFigure(CFrame.new(), staging)
	if not model then
		staging:Destroy()
		return nil, nil
	end
	model.Name = ("Resident_%d"):format(plotIndex)

	local palette = PALETTES[((plotIndex - 1) % #PALETTES) + 1]
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			-- A RESIDENT IS A PERSON, NOT A MONUMENT. The plinth is what
			-- makes the ornament a statue; on a lawn it would read as the
			-- neighbours having erected one of themselves.
			if d.Name == "Plinth" or d.Name == "PlinthCap" then
				d:Destroy()
			elseif SHIRT[d.Name] then
				d.Color = palette.shirt
				d.Material = Enum.Material.SmoothPlastic
			elseif TROUSERS[d.Name] then
				d.Color = palette.trousers
				d.Material = Enum.Material.SmoothPlastic
			elseif HAIR[d.Name] then
				d.Color = palette.hair
			end
		end
	end

	local low, high = verticalExtent(model)
	if high <= low then
		staging:Destroy()
		return nil, nil
	end
	model:ScaleTo(TARGET_HEIGHT / (high - low))

	-- Re-measured AFTER scaling rather than divided through. `ScaleTo` scales
	-- about the model's pivot, and the pivot is not the feet -- so where the
	-- soles end up is a fact to read back, not one to predict.
	local newLow = select(1, verticalExtent(model))
	local pivot = model:GetPivot()
	local feetBelowPivot = pivot.Position.Y - newLow

	-- THE PLOT'S ROTATION HAS TO COME ALONG, and dropping it is the bug this
	-- line exists to avoid. The far row's plot CFrame carries a half turn --
	-- which is exactly what makes plot-local +Z the street on BOTH rows --
	-- so a resident placed with position only would stand on four of the
	-- eight plots with their back to the pavement, facing their own house.
	-- The same trap the wheelie bin prop fell into, where 2 of 6 parts
	-- changed sides between the rows and nobody noticed for a session.
	--
	-- Safe to apply after the vertical measurement because the turn is about
	-- Y, and a Y rotation cannot change how far the soles sit below the pivot.
	model:PivotTo(CFrame.new(at.Position.X, groundY + feetBelowPivot, at.Position.Z)
		* at.Rotation)

	-- THE NAME OVER THEIR HEAD IS THE SAME NAME ON THE SIGN, and it is read
	-- off one argument rather than looked up twice, so the two cannot
	-- disagree about who lives here.
	--
	-- It is a nametag rather than a label: no title, no role, no "NPC". A
	-- resident is a neighbour, and the moment the tag says what it really is
	-- the street stops reading as a street. The dog's plate is the shape this
	-- copies -- BillboardGui on the head, MaxDistance so a street of eight
	-- does not draw from the far end -- and the colour comes from `Theme`
	-- because anything that constructs a GuiObject is in the palette's scope
	-- wherever it runs, which is the rule the physical boards were caught by.
	local head = model:FindFirstChild("Head", true)
	if head and head:IsA("BasePart") then
		local tag = Instance.new("BillboardGui")
		tag.Name = "Nametag"
		tag.Size = UDim2.new(0, 120, 0, 22)
		-- Clear of the crown rather than on it. The figure is scaled to 5.6,
		-- so this is read off the head it is actually standing on instead of
		-- a constant that stops being true the moment TARGET_HEIGHT moves.
		tag.StudsOffsetWorldSpace = Vector3.new(0, head.Size.Y * 0.5 + 0.55, 0)
		tag.MaxDistance = 90
		tag.AlwaysOnTop = false
		tag.Parent = head

		local label = Instance.new("TextLabel")
		label.Name = "Who"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.Text = name
		label.TextColor3 = Theme.PAPER
		-- A stroke rather than a card behind it, because this sits over grass,
		-- fences and houses of every colour and there is no one ground to
		-- solve a contrast against.
		label.TextStrokeTransparency = 0.35
		label.Parent = tag

		-- ------------------------------------------------------- the bubble
		-- BUILT ONCE AND LEFT DISABLED, never created on demand. A GuiObject
		-- made at the moment somebody speaks is a GuiObject made on the
		-- server during gameplay and replicated then, so the first line of
		-- every neighbour would arrive a beat late -- and this is a reaction
		-- to a player walking up, where a beat late is the whole difference
		-- between answering and announcing.
		--
		-- A CARD RATHER THAN A STROKE, WHICH IS THE OPPOSITE CALL TO THE
		-- NAMETAG ABOVE IT. That one is a label stuck on the world and has to
		-- survive being read against grass, fences and nine house tiers, so
		-- it is stroked text on nothing. This is SPEECH: it wants to read as
		-- a thing somebody said, and a bubble is what says that. It can
		-- afford a ground because it is only ever up for a few seconds.
		--
		-- ABOVE THE NAMETAG, so the two never overlap -- the tag sits at the
		-- crown plus 0.55 and is 22 tall, so the bubble clears it rather than
		-- sharing the pixel. `AlwaysOnTop` is FALSE on both, so a neighbour
		-- behind a house does not talk through it.
		local bubble = Instance.new("BillboardGui")
		bubble.Name = "Speech"
		bubble.Size = UDim2.new(0, 210, 0, 46)
		bubble.StudsOffsetWorldSpace = Vector3.new(0, head.Size.Y * 0.5 + 1.55, 0)
		bubble.MaxDistance = Config.RESIDENT_CHATTER.range
		bubble.AlwaysOnTop = false
		bubble.Enabled = false
		bubble.Parent = head

		local card = Instance.new("Frame")
		card.Name = "Card"
		card.Size = UDim2.fromScale(1, 1)
		card.BackgroundColor3 = Theme.PAPER
		card.BorderSizePixel = 0
		card.Parent = bubble

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = card

		-- The ink outline this theme puts round every surface -- what makes a
		-- card read as DRAWN rather than as a rectangle, and what gives it an
		-- edge against grass, which has no one colour to solve against.
		local edge = Instance.new("UIStroke")
		edge.Thickness = 3
		edge.Color = Theme.INK
		edge.Parent = card

		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 8)
		pad.PaddingRight = UDim.new(0, 8)
		pad.PaddingTop = UDim.new(0, 4)
		pad.PaddingBottom = UDim.new(0, 4)
		pad.Parent = card

		local said = Instance.new("TextLabel")
		said.Name = "Said"
		said.Size = UDim2.fromScale(1, 1)
		said.BackgroundTransparency = 1
		said.Font = Enum.Font.FredokaOne
		-- `TextScaled` IMPLIES WRAPPING AND THE PAIR IS ORDER-SENSITIVE.
		-- Writing `TextWrapped = false` after `TextScaled = true` silently
		-- turns the scaling back off and drops the label to TextSize 8 --
		-- measured on the plot sign, where both rows rendered as a smudge.
		-- Wrapping is what this wants anyway: the box is two lines tall so a
		-- long line breaks rather than shrinking to nothing.
		said.TextScaled = true
		said.TextWrapped = true
		said.TextColor3 = Theme.INK
		said.Text = ""
		said.Parent = card
	end

	-- The rig is captured AFTER the scale and the pivot, because those are
	-- what decide where a hip actually is. Feet-below-pivot is handed in
	-- rather than re-measured so the walk and the initial placement can never
	-- disagree about where the soles are.
	local rig = buildRig(model, feetBelowPivot)

	-- THE LIMB LISTS ARE COLLECTED BY NAME, SO A NAME ADDED TO THE BUILDER AND
	-- NOT ADDED HERE IS A PART THAT SILENTLY STOPS MOVING.
	--
	-- That is not hypothetical: `Sole`, `Ankle` and `Hand` were all missing,
	-- and the only symptom was a white sole standing still while the shoe
	-- above it walked away. Nothing errored, the figure walked, and it read as
	-- a rendering glitch rather than as two names left out of a table.
	--
	-- Counted rather than listed, and warned rather than asserted -- the same
	-- call `Decor.prewarm` makes: a neighbour with a stiff leg is a cosmetic
	-- fault and must never be the thing that stops a plot being built.
	local limbs, rigged = 0, #rig.pieces
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and (LEG_PARTS[d.Name] or ARM_PARTS[d.Name]) then
			limbs += 1
		end
	end
	if limbs ~= rigged then
		warn(("[ResidentModel] %d limb parts on the figure but %d in the rig"
			.. " -- a part name is missing from LEG_PARTS or ARM_PARTS and"
			.. " that limb will not move"):format(limbs, rigged))
	end

	model.Parent = parent
	staging:Destroy()
	return model, rig
end

return ResidentModel
