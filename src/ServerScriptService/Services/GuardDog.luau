--!strict
--[[
	GuardDog

	The defence tree's payoff: a dog that patrols your plot, chases a thief
	off it, and tags them for you -- then sleeps off its cooldown in a kennel.

	The kennel is not decoration. A dog's cooldown is the main thing that
	scales with its tier (34s for Scruffy down to 24s for Titan), and until it
	was visible it was an invisible timer that made the dog look broken to
	both sides. Asleep in the kennel means "this plot is unguarded right now",
	which a thief can read from the street and time a run against.

	It does not pathfind. A Humanoid with PathfindingService on twelve plots
	would cost far more CPU than this is worth, and a dog that occasionally
	trots through a fence post reads as charming rather than broken -- it's a
	small dog going under things. It just lerps along the ground toward its
	target and gives up after the tier's maxChase.

	The imported mesh rig is swapped per tier; this record and its movement
	anchor survive upgrades. GuardVisual owns the meshes and repaired joints,
	while GuardAnimator drives local motion from replicated gameplay states.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local GuardVisual = require(script.Parent.GuardVisual)
-- ABOVE `KENNEL`, which reads it at MODULE SCOPE. A local declared after
-- its reader is a nil global to that reader and Luau says nothing until the
-- index throws -- this project has paid for that eleven times, twice by
-- taking the whole server down at load.
local KennelModel = require(ReplicatedStorage.Shared.KennelModel)
-- WHAT TO CALL THE THING ON THE LAWN. `tier.breed` is the TIER's breed and
-- knows nothing about the coat, so a creature coat wore its own rig under the
-- wrong species -- a raptor labelled SHEPHERD. See `GuardRig.species`.
local GuardRig = require(ReplicatedStorage.Shared.GuardRig)

local GuardDog = {}

-- Which tier colour a part takes. Kept as a tag rather than a stored colour
-- so applyTier can repaint everything without knowing the geometry.
type Tone = "fur" | "dark" | "eye" | "collar" | "wood" | "roof" | "trim" | "vest"

-- WHICH PART OF THE ANIMAL A PIECE BELONGS TO, which is the whole mechanism
-- behind three breeds coming out of one part list. `layout` reads it and
-- nothing else does. See BREED SHAPE in Config.DOG_TIERS.
type Group = "body" | "head" | "ear" | "leg" | "paw" | "tail"

type Piece = {
	part: Part,
	size: Vector3,   -- at scale 1
	offset: Vector3, -- from the kennel origin, at scale 1
	tone: Tone,
	rot: CFrame?,    -- extra local rotation, never scaled
	group: Group?,   -- dog pieces only; the kennel does not deform
}

export type Dog = {
	model: Model,
	-- The kennel is a SEPARATE model, never pivoted.
	--
	-- Model:PivotTo moves every descendant, so while the kennel lived inside
	-- the dog's own model it was dragged along on every patrol step -- the dog
	-- could never actually reach it, because it fled at exactly the dog's
	-- speed. Anything the dog walks TO has to sit outside the thing that moves.
	kennelModel: Model,
	body: Part,
	pieces: { Piece },       -- the dog itself
	kennelPieces: { Piece }, -- its house
	originCF: CFrame,        -- kennel sits here; +Z points out of the doorway
	-- THE PLOT'S OWN FRAME, so a patrol can be held inside the fence. Nil
	-- where there is no yard to be held inside -- a shop has no fence,
	-- and its dog is level 0 and never patrols anyway.
	--
	-- Passed in rather than derived from `originCF`, which now carries the
	-- kennel's own quarter turn: working the plot frame back out of it would
	-- mean this file knowing where PlotService chose to stand the kennel,
	-- which is exactly the derived-constant-that-stopped-being-derived trap
	-- this project keeps recording.
	yard: CFrame?,
	home: Vector3,           -- the torso's on-duty rest position
	level: number,
	-- WHICH COAT IS WORN, or "" for the breed's own colours. A key into
	-- `Config.DOG_COATS` and nothing else -- see the header there for why a
	-- coat may reach `fur`, `furDark` and `collar` and may NEVER reach `scale`
	-- or `shape`, which are what carry the tier a thief reads.
	--
	-- An unknown key falls back to the breed rather than erroring, so a coat
	-- retired from the catalogue leaves every save that owned one still
	-- rendering a dog. Same shape as `Decor.buildOne` returning nil for a
	-- retired ornament and the prune that follows it.
	coat: string,
	-- WHICH KENNEL SKIN IS STANDING, or "" for the plain wooden one. A key
	-- into `Config.DOG_KENNELS`, and it reaches `wood` and `trim` ONLY -- the
	-- roof is painted from the coat's collar and a kennel may never touch it,
	-- because the roof is the surface that says whose dog lives here. Same
	-- retired-key fallback as `coat` above.
	kennel: string,
	-- HOW WIDE THE FRONT FENCE'S GATE IS, or math.huge while there is no
	-- fence. A dog is not a player and its walk is CFrame writes rather than
	-- physics, so nothing stops it walking through its owner's fence -- which
	-- it did, chasing thieves straight through the pickets. Written by
	-- `PlotService.buildFence`, which is the one place a tier's `gate` is
	-- known, and read only by the chase.
	gate: number,
	-- The owner's name for it, or "" for the breed's own label. Always one of
	-- `Config.DOG_NAMES`: naming is a picker rather than a text box, so this
	-- module never sees a player's own words at all -- see
	-- `CosmeticsService.nameDog`, which is where the list is checked.
	name: string,
	-- The dog's OWN cooldown, earned by finishing a chase. Guard duty
	-- suppresses this one: it is exactly what the owner paid to buy off.
	busyUntil: number,
	-- A nap BOUGHT by a thief with a bone. Guard duty must never suppress
	-- this one, and that is the whole reason it is a separate field.
	--
	-- Both used to live in busyUntil, and a Golden Bone landing on a
	-- guarded dog therefore bought nothing: lure let it past the guard-duty
	-- gate, stamped busyUntil, and onCooldown then threw the stamp away for
	-- the next six minutes because guard duty was still running. The dog
	-- kept patrolling on a 30,000-coin bone. Meanwhile BoneService read the
	-- raw field and refused every later throw with "already off duty" --
	-- the two readers disagreed about the same number in opposite
	-- directions, which is what one field carrying two meanings buys you.
	napUntil: number,
	-- Guard duty, bought by the OWNER with a treat. Until this passes the dog
	-- ignores its cooldown entirely and refuses every bone but a Golden one.
	-- Kept as a deadline rather than a boolean so it needs no timer to expire
	-- and survives the dog being rebuilt by a tier change.
	guardUntil: number,
	-- Earliest a NEW treat may be applied, set to guardUntil plus the
	-- lockout. Guard duty stacked without it, and ten treats bought an
	-- hour of a dog that never slept -- see Config.GUARD_DUTY_LOCKOUT.
	guardLockUntil: number,
	-- IS SOMEBODY IN? Written by the watcher in HeistService, which is the
	-- only thing that knows where players are; a resident's owner is always
	-- away, so a resident plot's dog is always the enforcer.
	--
	-- A dog with its owner home PATROLS. A dog with the house empty SLEEPS in
	-- its kennel until something wakes it -- so the dog's own posture is the
	-- tell for the single most important fact about a target, free, with no
	-- UI, readable from the pavement. A dog trotting about means expect a
	-- fight; a dog curled up means the house is empty.
	ownerHome: boolean,
	-- Roused by NOISE, and up until this passes. Extended by every further
	-- disturbance, so a thief who keeps making noise keeps the dog up.
	alertUntil: number,
	-- The dog does not POUNCE. This is the moment it will actually get up,
	-- stamped `wakeDelay` after the first disturbance of an alert and NOT
	-- pushed back by later ones -- otherwise continuous noise would postpone
	-- the dog forever, which is the opposite of what noise should do.
	--
	-- The beat between being disturbed and being come for is what makes a
	-- crack a DECISION: you hear the dog stir and choose whether to finish or
	-- bail. Same shape as DOG_START_DELAY and the same reason.
	stirAt: number,
	chasing: boolean,
	sleeping: boolean,
	-- Walking over to a thrown bone. Distinct from `chasing` because the dog
	-- is unavailable but not hunting anyone, and distinct from `busyUntil`
	-- because the nap has not started yet -- it starts when the bone is eaten.
	lured: boolean,
	-- The current nap was BOUGHT by a thief rather than earned by a chase.
	-- Purely so the nameplate can say so: a defender who cannot tell a baited
	-- dog from a resting one just sees their expensive purchase not working.
	distracted: boolean,
	plate: BillboardGui,
	nameLabel: TextLabel,
	breedLabel: TextLabel,
	-- The name painted on the kennel, over the door. A second channel for the
	-- same fact as `nameLabel`, and the one that reads from the pavement: the
	-- nameplate is a MaxDistance 90 billboard and small at that range.
	boardLabel: TextLabel,
	zzz: ParticleEmitter,
}

-- The dog rests this far out from the kennel, so the doorway stays visible
-- and it is not standing inside its own house while on duty.
local REST_OFFSET = Vector3.new(0, 0, 5.5)

-- WHERE THE TORSO RIDES AT SCALE 1, and where a leg stops.
--
-- `TORSO_Y` was the literal 1.9 in THREE places -- `home` at build, `home`
-- again in `layout`, and the PivotTo in `rouse` -- which is the
-- derived-constant trap this project keeps recording. It cost nothing while
-- every breed was the same dog scaled; the moment one breed got longer legs,
-- two of those three copies would have been wrong and the dog would have
-- walked with its belly through the grass.
local TORSO_Y = 1.9
local LEG_TOP = 1.725

-- THE KENNEL'S GEOMETRY LIVES IN `Shared/KennelModel` SO THE SHOP CAN DRAW
-- ONE. Only the bone table moved; everything this file does with it -- the
-- scale to fit whatever rig is standing in it, the seating on the plot, the
-- weld into the dog's model and the repaint on every coat change -- stayed,
-- because none of that belongs on a client. See that module's header.
local KENNEL: { any } = KennelModel.BONES

local EYE_DULL = Color3.fromRGB(24, 20, 18)

-- ============================================================
-- MOVEMENT
-- ============================================================

-- Plays one of the dog's voices. Tolerates a missing sound so a half-built
-- dog never throws mid-chase.
local function play(dog: Dog, name: string)
	local sound = dog.body:FindFirstChild(name) :: Sound?
	if sound and sound.SoundId ~= "" then
		sound:Play()
	end
end

-- A CFrame at `pos` whose LOCAL +Z points along `heading`.
--
-- Not CFrame.lookAt on its own. lookAt aims the CFrame's LookVector, and
-- LookVector is the NEGATIVE Z axis -- but every part of this dog is authored
-- with the snout at +Z. Using lookAt directly pointed the tail down the
-- travel direction, so the dog sprinted backwards through every patrol and
-- every chase from the day it was built.
local function facing(pos: Vector3, heading: Vector3): CFrame
	return CFrame.lookAt(pos, pos + heading) * CFrame.Angles(0, math.pi, 0)
end

-- HOW FAR A DOG REACHES PAST THE POINT IT IS WALKING TO, at scale 1.
--
-- `walkTo` drives the TORSO, and the Mastiff is 9.9 studs nose to tail at its
-- own 1.3 scale -- so a dog whose torso is standing on the fence line has
-- half its body through the fence. Measuring the destination and forgetting
-- the animal standing on it is the same mistake as a prompt that measures to
-- a part's centre and forgets where a thief can put their feet.
local BODY_HALF = 3.81

-- And ACROSS, which is a different number and is what has to fit through a
-- gate. The widest rig that ships is the Cerberus coat at 5.40 across, so 2.7
-- at its own scale -- comfortably inside the narrowest gate in the game
-- (8 studs at the Moat).
local BODY_HALF_WIDTH = 1.35

-- THE FENCE, FOR THE ONE THING IN THIS GAME THAT DOES NOT COLLIDE WITH IT.
--
-- Everything below works in the yard's own frame, where +Z is the street and
-- the front fence stands on `PLOT_FRONT_LINE` with an opening `dog.gate` wide
-- on the centre line. A dog may cross that line only through the opening and
-- may never cross the sides or the back at all (`clampToLeash` holds those),
-- so the only way out of a yard is the way a player has: the gate.

-- Is this point on the street side of the front fence?
local function pastFence(dog: Dog, position: Vector3): boolean
	local yard = dog.yard
	if not yard then
		return false
	end
	return yard:PointToObjectSpace(position).Z > Config.PLOT_FRONT_LINE
end

-- WHERE THE CHASE IS ACTUALLY HEADED. The thief, unless they are on the other
-- side of the fence, in which case the mouth of the gate on the dog's own
-- side -- so the dog runs for the opening rather than at the wire. Once it is
-- IN the opening the target takes over again, or it would stall on the
-- waypoint and never step through.
local function chaseGoal(dog: Dog, from: Vector3, target: Vector3): Vector3
	local yard = dog.yard
	if not yard or dog.gate == math.huge then
		return target
	end
	if pastFence(dog, from) == pastFence(dog, target) then
		return target
	end
	local here = yard:PointToObjectSpace(from)
	local line = Config.PLOT_FRONT_LINE
	if math.abs(here.X) <= dog.gate * 0.25 and math.abs(here.Z - line) <= 4 then
		return target
	end
	local side = if here.Z > line then 1.5 else -1.5
	return yard * Vector3.new(0, here.Y, line + side)
end

-- The fence as a wall the walker cannot pass except at the gate. `reach` is
-- how far the animal's body stands out sideways, so it cannot wear a gate
-- post while nominally inside the opening.
local function blockAtFence(dog: Dog, from: Vector3, to: Vector3, reach: number): Vector3
	local yard = dog.yard
	if not yard or dog.gate == math.huge then
		return to
	end
	local a, b = yard:PointToObjectSpace(from), yard:PointToObjectSpace(to)
	local line = Config.PLOT_FRONT_LINE
	if (a.Z <= line) == (b.Z <= line) then
		return to
	end
	if math.abs(b.X) <= math.max(dog.gate / 2 - reach, 0) then
		return to
	end
	-- Into the fence: it keeps its sideways movement and stops at the line,
	-- which reads as a dog working along the wire toward the gate rather than
	-- as one frozen in mid-stride.
	local stop = if a.Z <= line then line - 0.1 else line + 0.1
	local blocked = yard * Vector3.new(b.X, b.Y, stop)
	return Vector3.new(blocked.X, to.Y, blocked.Z)
end

-- Lerps the model toward `target` across the ground plane, facing where it's
-- going. Returns true if it arrived. `abort` is polled every frame so a
-- patrol can drop everything the moment an alarm fires.
local function walkTo(dog: Dog, target: Vector3, speed: number, timeout: number, abort: (() -> boolean)?): boolean
	if not dog.model.Parent or (abort and abort()) then return false end
	GuardVisual.state(dog, "Walk")
	local function finished()
		if dog.model:GetAttribute("GuardState") == "Walk" then GuardVisual.state(dog, "Idle") end
	end
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		local dt = RunService.Heartbeat:Wait()
		if not dog.model.Parent or (abort and abort()) then
			finished()
			return false
		end

		local from = dog.body.Position
		-- ARRIVAL IS JUDGED AGAINST THE TARGET and travel against the GOAL,
		-- which are the same point unless the fence is in the way: a dog on
		-- the driveway walking home routes through its own gate rather than
		-- back through the pickets.
		if Vector3.new(target.X - from.X, 0, target.Z - from.Z).Magnitude < 0.6 then
			finished()
			return true
		end
		local goal = chaseGoal(dog, from, target)
		local to = Vector3.new(goal.X, from.Y, goal.Z)
		local delta = to - from
		if delta.Magnitude < 0.05 then
			finished()
			return true
		end

		-- Face along the travel direction rather than at the target: a step
		-- that landed exactly on the target would make CFrame.lookAt degenerate.
		local heading = delta.Unit
		local moved = from + heading * math.min(speed * dt, delta.Magnitude)
		moved = blockAtFence(dog, from, moved, BODY_HALF_WIDTH)
		dog.model:PivotTo(facing(moved, heading))
	end
	finished()
	return false
end

-- ============================================================
-- OFF DUTY
-- ============================================================

-- HOW HIGH THE TORSO RIDES FOR THIS BREED, which is the dog's pivot and
-- therefore the one number the whole movement system is expressed in.
--
-- Longer legs do not just make longer legs: everything above them has to ride
-- higher by the same amount, or the dog stands with its belly in the grass.
-- Derived from where a leg actually ends rather than tuned, so a breed's
-- `leg` factor moves the stance and the pivot together and cannot desync.
local function torsoY(tier: any): number
	local shape = tier and tier.shape
	local legF = (shape and shape.leg) or 1
	return (TORSO_Y + (legF - 1) * LEG_TOP) * ((tier and tier.scale) or 1)
end

-- Where the dog stands when it is on duty. `layout`, `rouse` and `build` all
-- go through this, because they used to carry three copies of the same
-- literal and any breed change would have moved two of them and not the third.
local function restCFrame(dog: Dog, tier: any): CFrame
	return dog.originCF
		* CFrame.new(REST_OFFSET * ((tier and tier.scale) or 1) + Vector3.new(0, torsoY(tier), 0))
end

-- Hold a patrol destination inside the fence.
--
-- THE RECTANGLE IS THE FENCE'S, not the plot slab's, and it is the same one
-- `PlotService.yardContaining` tests -- so "where a dog may walk" and "whose
-- yard is this" can never disagree about where a yard ends. Inset by the
-- dog's own reach, because the thing that has to stay inside is the animal
-- rather than the point it is aiming at.
--
-- A CLAMP AND NOT A SHORTER RADIUS, so it covers every destination this
-- file hands the walker rather than only the random wander.
local function clampToYard(dog: Dog, target: Vector3, tier: any): Vector3
	local yard = dog.yard
	if not yard then
		return target
	end
	local reach = BODY_HALF * ((tier and tier.scale) or 1)
	local halfX = math.max(Config.PLOT_HALF_WIDTH - reach, 0)
	local front = Config.PLOT_FRONT_LINE - reach
	local back = -Config.YARD_DEPTH + reach
	local p = yard:PointToObjectSpace(target)
	return yard * CFrame.new(
		math.clamp(p.X, -halfX, halfX),
		p.Y,
		math.clamp(p.Z, math.min(back, front), front)).Position
end

-- THE CHASE LEASH: the fence rectangle, extended forward to the end of the
-- driveway. See `Config.DOG_CHASE`. `pad` grows (positive) or shrinks
-- (negative) the box; a dog with no yard (a shop's) has no leash.
local function leashBox(pad: number): (number, number, number)
	local front = Config.streetMetrics().driveFar
	return Config.PLOT_HALF_WIDTH + pad, -Config.YARD_DEPTH - pad, front + pad
end

local function inLeash(dog: Dog, position: Vector3, pad: number): boolean
	local yard = dog.yard
	if not yard then
		return true
	end
	local halfX, back, front = leashBox(pad)
	local p = yard:PointToObjectSpace(position)
	return math.abs(p.X) <= halfX and p.Z >= back and p.Z <= front
end

local function clampToLeash(dog: Dog, position: Vector3, reach: number): Vector3
	local yard = dog.yard
	if not yard then
		return position
	end
	local halfX, back, front = leashBox(-reach)
	local p = yard:PointToObjectSpace(position)
	local clamped = yard * Vector3.new(
		math.clamp(p.X, -math.max(halfX, 0), math.max(halfX, 0)),
		p.Y,
		math.clamp(p.Z, math.min(back, front), front))
	return Vector3.new(clamped.X, position.Y, clamped.Z)
end

-- THE KENNEL'S INSIDE, at scale 1, taken off the KENNEL table above: the
-- walls' inner faces, the floor's top, the gap between the door posts and the
-- height of the opening under the lintel.
local KENNEL_IN_HALF_W = 2.38
local KENNEL_IN_BACK = -2.35
local KENNEL_IN_FRONT = 2.60
local KENNEL_DOOR_HALF_W = 2.05
local KENNEL_DOOR_HEIGHT = 3.65
local KENNEL_FLOOR_TOP = 0.66 + 0.40 / 2

-- HOW BIG THIS DOG IS, from what GuardVisual measured off the real mesh.
-- Falls back to proportions of the breed's height before a visual exists.
local function guardDims(dog: Dog): (number, number, number, number)
	local visual = dog.model:FindFirstChild("Visual")
	local height = dog.model:GetAttribute("GuardHeight") or 2.5
	local function read(name: string, fallback: number): number
		local v = visual and visual:GetAttribute(name)
		return if typeof(v) == "number" then v else fallback
	end
	return read("GuardHalfWidth", 0.35 * height), read("GuardBack", 0.7 * height),
		read("GuardFront", 0.7 * height), height
end

-- HOW BIG THE KENNEL HAS TO BE FOR THIS DOG TO LIVE IN IT, which is the
-- breed's own scale unless the animal does not fit.
--
-- A dog sleeps INSIDE its kennel, so the house has to hold it: wide enough,
-- deep enough, and with a doorway it can walk through without wearing the
-- lintel. Every breed that ships today fits at its own `tier.scale` --
-- measured on the real rigs, the tightest being the Triceratops coat at 6.98
-- long against a 7.43 interior -- so this changes nothing now. It is here
-- because the alternative is a number that is right until somebody
-- regenerates a rig, and the failure that produces is a dog clipping through
-- its own roof, which is exactly what was reported once already.
local function kennelScale(dog: Dog, tier: any): number
	local halfW, back, front, height = guardDims(dog)
	local scale = (tier and tier.scale) or 1
	return math.min(2.4, math.max(
		scale,
		-- Half a stud of air either side, front and back.
		(2 * halfW + 1.0) / (2 * KENNEL_IN_HALF_W),
		(back + front + 1.0) / (KENNEL_IN_FRONT - KENNEL_IN_BACK),
		(2 * halfW + 0.6) / (2 * KENNEL_DOOR_HALF_W),
		-- Walking in, so the STANDING height has to clear the opening.
		(height + 0.25) / KENNEL_DOOR_HEIGHT))
end

local function sleepCFrame(dog: Dog, tier: any): CFrame
	local scale = kennelScale(dog, tier)

	-- INSIDE THE KENNEL, on its floor, facing out, with its NOSE AT THE
	-- DOORWAY.
	--
	-- For one session it slept on the lawn in front of the door, on the claim
	-- that the rigs were too big for the house. That claim was never
	-- measured and is false: every breed fits its own kennel at its own scale,
	-- and what had actually been wrong was the kennel origin sitting half a
	-- stud into the lawn. `kennelScale` now derives the fit from the mesh, so
	-- this is a guarantee rather than a hope.
	--
	-- Seated by its FRONT rather than centred, so the head and shoulders sit
	-- in the opening: a dog buried at the back of its kennel cannot be read
	-- from the pavement, and the sleeping posture is half of the "this plot is
	-- unguarded" tell. Clamped so a long rig cannot be pushed through the back
	-- wall by it.
	--
	-- STANDING HEIGHT PLUS THE FLOOR. The lying-down drop is the animation's
	-- job (GuardAnimation's Sleep pose lowers the Body joint), so the pivot
	-- stays at standing height with the feet on the kennel floor.
	local _, back, front = guardDims(dog)
	local nose = KENNEL_IN_FRONT * scale - 0.3 - front
	local heel = KENNEL_IN_BACK * scale + 0.3 + back
	local z = math.max(nose, heel)
	local at = dog.originCF * CFrame.new(0, torsoY(tier) + KENNEL_FLOOR_TOP * scale, z)
	return CFrame.new(clampToYard(dog, at.Position, tier)) * dog.originCF.Rotation
end

-- On guard duty right now?
local function onGuardDuty(dog: Dog): boolean
	return os.clock() < dog.guardUntil
end

-- Off duty and unavailable.
--
-- Everything below used to compare os.clock() against dog.busyUntil directly,
-- in six places. Guard duty has to suppress the cooldown in ALL of them --
-- miss one and the dog naps through the thing its owner just paid to prevent
-- -- so the comparison lives here once instead.
local function onCooldown(dog: Dog): boolean
	-- Two clocks, and only one of them answers to guard duty.
	--
	-- The dog's own cooldown is what the treat was bought to suppress. A
	-- bone nap is not: the only bone that can set one has already paid to
	-- get past the guard-duty gate, so suppressing it here would refund
	-- the defender a purchase the thief already beat.
	return os.clock() < dog.napUntil
		or (os.clock() < dog.busyUntil and not onGuardDuty(dog))
end

-- SHOULD THIS DOG BE ON ITS FEET?
--
-- Three ways, and the order they are written in is the order they matter:
--
--   * GUARD DUTY. The treat exists to get people OUT of the house -- this
--     file's own argument for it is that a player sitting on their own pig is
--     the worst outcome this design has -- so a paid-for dog has to keep
--     working after its owner leaves. Anything else would make the item sell
--     the opposite of what it does.
--   * THE OWNER IS IN. A guarded house is a busy one; the dog wanders.
--   * IT HEARD SOMETHING, and has had `wakeDelay` to get up.
--
-- Everything else -- an empty house, a quiet lawn, a thief on tiptoe -- is a
-- dog asleep in its kennel, which is the DEFAULT rather than the exception.
-- Three reasons to be up, and they are not the same reason -- which is what
-- the split below exists to keep straight.
local function shouldBeUp(dog: Dog): boolean
	local now = os.clock()
	return onGuardDuty(dog)
		or dog.ownerHome
		or (now < dog.alertUntil and now >= dog.stirAt)
end

-- READINESS: has this dog actually heard somebody, and has the beat passed.
--
-- THIS USED TO BE `shouldBeUp`, AND THEY ARE DIFFERENT QUESTIONS. Being up is
-- about what a dog LOOKS like from the pavement; being alerted is about
-- whether it is coming for you. Conflated, the `or` short-circuited: a dog
-- whose owner was home, or one on guard duty, was `shouldBeUp` before any
-- noise at all, so `isWatching` never reached the third clause -- which IS the
-- `wakeDelay` grace. The beat between being disturbed and being come for is
-- what makes a crack a DECISION rather than a coin flip, and it was being
-- skipped on exactly the two plots with the most reason to be dangerous.
--
-- So a dog may be UP for any of three reasons and may only be LET OFF for one:
-- it heard you, and `wakeDelay` has passed since.
local function isAlerted(dog: Dog): boolean
	local now = os.clock()
	return now < dog.alertUntil and now >= dog.stirAt
end

-- Told by the watcher whether anybody lives here and is standing on the
-- premises. Cheap and idempotent: `behaviour` polls the answer rather than
-- being driven by it, so this is one field write.
function GuardDog.setOwnerHome(dog: Dog, home: boolean)
	dog.ownerHome = home
end

-- NOISE. A footstep above this breed's threshold, or a fumbled slice of a
-- crack.
--
-- The stir is stamped only on a FRESH disturbance -- one that arrives with no
-- alert already running. Re-stamping it on every further noise would let a
-- thief who keeps moving hold the dog down indefinitely, which is exactly
-- backwards: noise should bring the dog sooner, never later. What continued
-- noise DOES buy is a longer alert, so a busy lawn keeps the dog up.
function GuardDog.alert(dog: Dog)
	if dog.level <= 0 then
		return
	end
	local now = os.clock()
	if now >= dog.alertUntil then
		dog.stirAt = now + Config.DOG_WATCH.wakeDelay
	end
	dog.alertUntil = now + Config.DOG_WATCH.alertSeconds
end

-- IS THIS DOG AWAKE, as far as noticing a sneak goes. A sleeping dog is only
-- woken by NOISE -- a walk, a fumbled slice, a smash -- and a tiptoe is never
-- noise. An awake one sees anybody who moves, sneaking or not, so the whole
-- rule for a thief is "don't wake it".
--
-- This replaced a per-tier `notice` speed. There are no dog tiers any more
-- (`Config.DOG_LEVEL`), and a speed threshold measured off position deltas
-- sat 0.6 studs/sec above a maxed carry-sneak, which network jitter could
-- cross on its own.
--
-- Awake is the owner being home, guard duty, or an alert running -- counted
-- from the disturbance rather than from `stirAt`, because a dog that has just
-- heard something is looking round even before it gets up. False where there
-- is no dog at all.
function GuardDog.isAwake(dog: Dog): boolean
	if dog.level <= 0 or dog.lured then
		return false
	end
	return onGuardDuty(dog) or dog.ownerHome or os.clock() < dog.alertUntil
end

-- Is the dog up and able to come for somebody? Public because the watcher
-- decides whether to set a chase going and must not re-derive any of this.
function GuardDog.isWatching(dog: Dog): boolean
	return dog.level > 0
		and not dog.chasing
		and not dog.lured
		and not onCooldown(dog)
		and isAlerted(dog)
end

-- Is anybody in? Written by the watcher every tick and read back by it a few
-- lines later, which looks like a round trip and is not: the WATCHER knows
-- where players are and the DOG is what the answer is about, so this is the
-- one field both halves of that question can agree on. It is also what keeps
-- the alarm-only branch out of the watcher's own bookkeeping -- `releaseDog`
-- asks the dog rather than recomputing a yard test its caller already did.
function GuardDog.isOwnerHome(dog: Dog): boolean
	return dog.ownerHome
end

local function settle(dog: Dog, tier: any)
	-- Walk to the doorstep spot it is about to lie on. Taken from
	-- `sleepCFrame` rather than computed a second time, so the walk and the
	-- lie-down can never disagree and the dog does not snap sideways as it
	-- falls asleep.
	local mouth = sleepCFrame(dog, tier).Position
	walkTo(dog, mouth, tier.speed * Config.DOG_PATROL_SPEED * 2.2, 6, function()
		return dog.chasing or dog.lured or dog.level <= 0
	end)
	if dog.chasing or dog.lured or dog.level <= 0 then
		return
	end

	dog.sleeping = true
	GuardVisual.state(dog, "Sleep")
	dog.model:PivotTo(sleepCFrame(dog, tier))
	dog.zzz.Enabled = true
	dog.breedLabel.Text = if dog.distracted then "DISTRACTED" else "OFF DUTY"
end

local function rouse(dog: Dog, tier: any)
	dog.sleeping = false
	GuardVisual.state(dog, "Idle")
	dog.distracted = false
	dog.zzz.Enabled = false
	-- Keeps the guard-duty tell if that is still running. Waking up from an
	-- interrupted chase must not quietly relabel a dog its owner has paid to
	-- advertise as unbribeable.
	dog.breedLabel.Text = if onGuardDuty(dog) then "ON GUARD"
		else string.upper(GuardRig.species(dog.coat, dog.level))

	-- Stand back up at the rest spot. Orientation comes from originCF, so the
	-- dog ends up facing out of its own doorway.
	dog.model:PivotTo(restCFrame(dog, tier))

	play(dog, "Bark")
end

-- Bark without chasing.
--
-- The bark normally lives inside `chase`, which is right for as long as
-- noticing somebody and going after them are the same event. They stopped
-- being the same event when an owner being home made the dog an ALARM rather
-- than an enforcer, so the noise had to come out from under the chase.
--
-- SAME SOUND DELIBERATELY. What a thief hears is "a dog has seen me"; whether
-- it is also coming for them is the next thing they find out, and giving the
-- alarm-only case its own noise would teach the street to tell the two apart
-- by ear and stop crossing lawns where somebody is home. The tell for that is
-- meant to be the dog's POSTURE, read from the pavement before you commit.
--
-- IT LIVES BELOW `rouse` FOR THE REASON THIS FILE KEEPS RECORDING: a local
-- read by a function written earlier is a nil GLOBAL in Luau, which dies at
-- the call naming nothing useful.
function GuardDog.bark(dog: Dog)
	if dog.level <= 0 then
		return
	end
	local tier = Config.getDogTier(dog.level)
	if tier and dog.sleeping then
		-- Standing up barks on its own, and doing both is two barks.
		rouse(dog, tier)
	else
		play(dog, "Bark")
	end
end

-- THE ONE PLACE A PATROL DESTINATION IS DECIDED, and that is the point of it
-- being a function rather than four lines inside the loop.
--
-- **ANY CLAMP ON WHERE A GUARD DOG MAY WALK BELONGS HERE**, because every
-- branch returns through this one point. That matters more than it looks:
-- the wander is a radius around `home`, `home` is offset out of the kennel
-- doorway, and the kennel stands in a corner of the plot -- so the radius and
-- the fence are two numbers nothing currently multiplies together.
--
-- `clampToYard` is what fills that in, and note `settle` has to call it too:
-- lying down is a destination this function never sees.
local function patrolTarget(dog: Dog): Vector3
	local tier = Config.getDogTier(dog.level)
	local angle = math.random() * math.pi * 2
	local dist = math.random() * Config.DOG_PATROL_RADIUS
	return clampToYard(dog,
		dog.home + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist),
		tier)
end

-- The dog's whole life outside a chase: asleep while on cooldown, wandering
-- while on duty.
local function behaviour(dog: Dog)
	while dog.model.Parent do
		local tier = Config.getDogTier(dog.level)

		-- `lured` hands the dog to GuardDog.lure entirely. Two loops steering
		-- the same model with PivotTo would fight frame by frame.
		if not tier or dog.chasing or dog.lured then
			task.wait(0.4)
		elseif onCooldown(dog) or not shouldBeUp(dog) then
			-- TWO REASONS TO BE IN THE KENNEL AND ONE PICTURE FOR BOTH, which
			-- is deliberate. A dog sleeping off a chase and a dog sleeping
			-- because nobody is home look identical from the pavement, and
			-- they should: what a thief needs to read is "this plot is
			-- unguarded right now", not why.
			if dog.sleeping then
				task.wait(0.4)
			else
				settle(dog, tier)
			end
		else
			if dog.sleeping then
				rouse(dog, tier)
			end

			-- Polled, not one long task.wait.
			--
			-- A flat wait of up to six seconds ignores everything that happens
			-- during it. A dog baited a moment after settling into a pause
			-- stood in the open for the whole nap and only then ambled to its
			-- kennel -- and against a short nap it never arrived at all, so
			-- the one thing that tells a thief the plot is unguarded never
			-- happened. Chases and the dognap admin command were both late
			-- for the same reason.
			local low, high = Config.DOG_PATROL_PAUSE[1], Config.DOG_PATROL_PAUSE[2]
			local pauseUntil = os.clock() + low + math.random() * (high - low)
			while os.clock() < pauseUntil do
				if dog.chasing or dog.lured or dog.level <= 0 or onCooldown(dog) then
					break
				end
				task.wait(0.15)
			end

			tier = Config.getDogTier(dog.level)
			if tier and not dog.chasing and not onCooldown(dog) then
				walkTo(dog, patrolTarget(dog), tier.speed * Config.DOG_PATROL_SPEED, 8, function()
					return dog.chasing or dog.lured or dog.level <= 0 or onCooldown(dog)
				end)
			end
		end
	end
end

-- "4m 10s", or "38s" under a minute. Refusals name a real wait rather
-- than a bare number of seconds, because the player is deciding whether to
-- stand there and wait for it.
local function formatWait(seconds: number): string
	local left = math.max(0, math.ceil(seconds))
	if left < 60 then
		return ("%ds"):format(left)
	end
	return ("%dm %02ds"):format(left // 60, left % 60)
end

-- The visible half of guard duty.
--
-- A buff a thief cannot see is a trap: they burn a Golden Bone finding out, or
-- worse, get caught by a dog they had every reason to think was bribeable. So
-- the dog puts a vest on and the nameplate says so, and the correct response
-- -- go and rob one of the other plots -- is readable from the pavement.
--
-- IT WAS THE COLLAR GOING NEON UNTIL COLLARS BECAME BUYABLE, and that is the
-- whole reason this moved. A player wearing a bright cosmetic collar would
-- have made the tell unreadable, which is worse than no tell at all -- the
-- signal would still be there and would no longer mean anything. Deleting it
-- and leaning on the nameplate alone was the other option and it takes duty
-- from two channels to one, on a `MaxDistance` 90 billboard that is small at
-- pavement range. See `Config.DOG_DUTY_VEST`.
--
-- The vest is found BY TONE rather than by name, unlike the collar it
-- replaced. There is exactly one piece carrying it, a name is a second thing
-- to keep in step, and this file has already been caught once by four kennel
-- `Finial`s answering to the same `FindFirstChild`.
local function showGuardDuty(dog: Dog, on: boolean)
	GuardVisual.duty(dog, on)
	local tier = Config.getDogTier(dog.level)
	if not tier then
		return
	end

	for _, piece in ipairs(dog.pieces) do
		if piece.tone == "vest" then
			piece.part.Transparency = if on then 0 else 1
		end
	end

	if on then
		dog.breedLabel.Text = "ON GUARD"
	elseif not dog.sleeping then
		dog.breedLabel.Text = string.upper(GuardRig.species(dog.coat, dog.level))
	end
end

-- Puts the dog on guard duty, or says why it will not go.
--
-- Returns a reason so HomeService can surface it and NOT spend the treat. An
-- item consumed for nothing is indistinguishable from an item that is broken,
-- which is the same rule the bone refusals follow.
--
-- Two refusals, and they are different: one says the treat would be wasted
-- because the dog is already guarding, the other says the dog is not allowed
-- another one yet. Collapsing them into "can't right now" hides which.
function GuardDog.setGuardDuty(dog: Dog, seconds: number): (boolean, string?)
	local tier = Config.getDogTier(dog.level)
	if not tier then
		return false, "there is no dog there"
	end

	-- NOT a top-up. Adding to what was left is exactly the stacking bug: ten
	-- treats bought an hour of a dog that never napped.
	if onGuardDuty(dog) then
		return false, ("%s is already on guard duty. %s left"):format(
			tier.name, formatWait(dog.guardUntil - os.clock()))
	end

	if os.clock() < dog.guardLockUntil then
		return false, ("%s needs a rest between treats. Ready in %s"):format(
			tier.name, formatWait(dog.guardLockUntil - os.clock()))
	end

	dog.guardUntil = os.clock() + seconds
	-- From EXPIRY, not from now. Measured from now, a six-minute duty and a
	-- four-minute lockout would overlap entirely and guarantee no gap at all.
	dog.guardLockUntil = dog.guardUntil + Config.GUARD_DUTY_LOCKOUT

	-- Straight back on its feet. A dog that stayed asleep for the rest of its
	-- cooldown would look exactly like the treat having done nothing, and the
	-- cooldown is precisely what was just bought off.
	--
	-- A bone nap is NOT woken from: the thief paid to get past the gate and
	-- the treat does not refund that. Guard duty simply resumes when it ends.
	if dog.sleeping and os.clock() >= dog.napUntil then
		rouse(dog, tier)
	end
	showGuardDuty(dog, true)

	local endsAt = dog.guardUntil
	task.delay(seconds + 0.1, function()
		-- Only clear if nothing extended it while we were waiting.
		if dog.model.Parent and dog.guardUntil <= endsAt then
			showGuardDuty(dog, false)
		end
	end)
	return true
end

-- How long until another treat may be used. Zero means it is ready now.
function GuardDog.guardLockSecondsLeft(dog: Dog): number
	return math.max(0, dog.guardLockUntil - os.clock())
end

function GuardDog.guardSecondsLeft(dog: Dog): number
	return math.max(0, dog.guardUntil - os.clock())
end

-- Public because BoneService has to refuse a throw BEFORE the bone leaves the
-- pocket, and it cannot see the local one.
function GuardDog.onGuardDuty(dog: Dog): boolean
	return onGuardDuty(dog)
end

-- Also public, and for the same reason: BoneService has to decide whether
-- a dog is available BEFORE the throw, and it used to answer that by
-- comparing os.clock() against dog.busyUntil itself. That is the exact
-- duplication the note above onCooldown warns about, and it drifted the
-- moment busyUntil stopped being the only clock -- BoneService called a
-- guarded dog "already off duty" while behaviour had it out on patrol.
-- Ask, do not re-derive.
function GuardDog.isOffDuty(dog: Dog): boolean
	return onCooldown(dog)
end

-- ============================================================
-- BUILD AND TIERS
-- ============================================================

-- Scale the kennel and place the authored guard at ground level.
local function layout(dog: Dog, tier: any)
	-- THE VISUAL FIRST, because it is what MEASURES the dog: `kennelScale`
	-- reads the attributes `GuardVisual.apply` writes, so sizing the house
	-- before the animal exists would fall back to a guess and leave the
	-- kennel one tier-change behind the rig inside it.
	dog.model:PivotTo(restCFrame(dog, tier))
	dog.home = dog.body.Position
	GuardVisual.apply(dog, tier, torsoY(tier))

	-- The KENNEL's scale, which is the breed's unless the animal needs a
	-- bigger house to sleep in -- see `kennelScale`. The dog's own size is
	-- authored into its mesh and is not scaled here.
	local scale = kennelScale(dog, tier)
	for _, piece in ipairs(dog.kennelPieces) do
		piece.part.Size = piece.size * scale
		piece.part.CFrame = dog.originCF * CFrame.new(piece.offset * scale) * (piece.rot or CFrame.identity)
	end
	local height = dog.model:GetAttribute("GuardHeight") or 2.5
	local head = dog.plate.Parent :: BasePart
	head.CFrame = dog.body.CFrame * CFrame.new(0, height - torsoY(tier), 0)
	dog.plate.StudsOffsetWorldSpace = Vector3.new(0, 0.65, 0)
end

-- Put a coat on, or take one off by passing nil or "".
--
-- REPAINTS THROUGH `applyTier` RATHER THAN TOUCHING PARTS HERE, because that
-- is the ONE place a dog's colours are decided -- and it also re-seats a
-- sleeping dog, restores the duty vest and rewrites the nameplate, every one
-- of which a second painting path would silently drop. Same argument
-- `CosmeticsService.applyToPlot` makes for being the only thing that makes a
-- plot match its data: buying a house once called `setHouseLevel` alone and
-- the sign went on announcing the old one until the player rejoined.
--
-- A LEVEL-0 DOG STORES THE COAT AND SHOWS NOTHING, which is the ordering that
-- matters: `applyTier` hides every piece and returns early when there is no
-- tier, so a coat restored from a save before the dog level is restored is
-- kept rather than lost, and appears the moment a dog is actually bought.
function GuardDog.setCoat(dog: Dog, key: string?)
	dog.coat = key or ""
	GuardDog.applyTier(dog, dog.level)
end

-- Re-skin the kennel, or go back to plain wood with nil or "".
--
-- A SEPARATE SETTER RATHER THAN A SECOND ARGUMENT TO `setCoat`, because the
-- two are bought separately and arrive separately: `CosmeticsService` pushes
-- whichever one changed, and folding them into one call would mean every coat
-- change had to also know the kennel and vice versa. Two fields, two setters,
-- one repaint path underneath them.
function GuardDog.setKennel(dog: Dog, key: string?)
	dog.kennel = key or ""
	GuardDog.applyTier(dog, dog.level)
end

-- HOW WIDE THE GATE IN THE FRONT FENCE IS, or nil for no fence at all.
--
-- A dog moves by `PivotTo` and therefore collides with nothing, so its own
-- owner's fence is invisible to it: chases went straight through the pickets,
-- which makes the one defence a thief is meant to be able to plan around
-- irrelevant to the thing doing the chasing. The chase now leaves the yard
-- through the gate like a player. Not `applyTier`'s business -- a fence tier
-- and a dog tier are bought separately -- so it is its own setter, the same
-- call `setKennel` makes for the same reason.
function GuardDog.setGate(dog: Dog, width: number?)
	dog.gate = width or math.huge
end

-- Name the dog, or clear the name with nil or "".
--
-- **WHAT ARRIVES HERE IS ALREADY OFF THE APPROVED LIST AND THIS FUNCTION
-- DOES NOT CHECK.** `CosmeticsService.nameDog` matches the name against
-- `Config.DOG_NAMES` and is the only caller, so there is no player-authored
-- text in this game to inspect. A second check here would look like defence
-- and be the opposite -- two places that both "handle" this is how one of
-- them ends up trusted and skipped. If naming ever takes free text again,
-- the filter belongs where the list check is, not here as well.
--
-- Repaints through `applyTier` for the same reason `setCoat` does: that is the
-- one function that decides what a dog looks like, and it also restores the
-- duty vest and the breed line, both of which a second painting path drops.
function GuardDog.setName(dog: Dog, name: string?)
	dog.name = name or ""
	GuardDog.applyTier(dog, dog.level)
end

-- Repaints and resizes the dog and its kennel into the breed for `level`.
-- Level 0 hides the animal; the KENNEL stays standing,
-- because an empty kennel is what the Guard Dog upgrade is sold against.
function GuardDog.applyTier(dog: Dog, level: number)
	dog.level = math.clamp(level, 0, #Config.DOG_TIERS)
	local tier = Config.getDogTier(dog.level)

	if not tier then
		GuardVisual.apply(dog, nil, 0)
		GuardVisual.state(dog, "Hidden")
		for _, piece in ipairs(dog.pieces) do
			piece.part.Transparency = 1
		end
		for _, piece in ipairs(dog.kennelPieces) do
			piece.part.Transparency = 1
		end
		dog.plate.Enabled = false
		dog.zzz.Enabled = false
		-- A SurfaceGui draws on its face whatever the part's Transparency is,
		-- so hiding the board is not enough to hide the writing on it: an
		-- un-cleared label would leave a name floating over a plot with no dog
		-- on it. The name itself is KEPT in `dog.name` and comes back with the
		-- first tier that is bought.
		dog.boardLabel.Text = ""
		return
	end

	layout(dog, tier)

	local all = {}
	for _, p in ipairs(dog.pieces) do table.insert(all, p) end
	for _, p in ipairs(dog.kennelPieces) do table.insert(all, p) end

	-- THE COAT DECIDES COLOUR AND THE TIER DECIDES EVERYTHING ELSE.
	--
	-- An unknown or empty key resolves to nil and every lookup below falls
	-- back to the breed, so a retired coat degrades to the dog this player
	-- would have had anyway rather than erroring or rendering untinted.
	--
	-- Note what is deliberately NOT taken from the coat: `tier.glow`. Whether
	-- the eyes light at all is the top breed's own tell and the coat only ever
	-- says what colour they light IN. A coat that could switch the glow on
	-- would be a Scruffy wearing a Titan's signal, which is the one thing
	-- `Config.DOG_COATS` forbids.
	local coat = Config.DOG_COATS[dog.coat or ""]
	local kennelTones = KennelModel.tones(dog.coat, dog.level)
	local fur = if coat then coat.fur else tier.fur
	local furDark = if coat then coat.furDark else tier.furDark
	local collar = if coat then coat.collar else tier.collar

	for _, piece in ipairs(all) do
		local p = piece.part

		-- THE VEST IS THE ONE PIECE THAT IS NOT ALWAYS THERE, so it is handled
		-- before the blanket `Transparency = 0` below rather than after it.
		-- This function repaints EVERY piece on any tier change, so a vest
		-- taking that line would appear on every dog in the game the moment
		-- somebody upgraded one -- a state readout showing a state that is not
		-- running, which is worse than no readout at all.
		if piece.tone == "vest" then
			p.Color, p.Material = Config.DOG_DUTY_VEST, Enum.Material.SmoothPlastic
			p.Transparency = if onGuardDuty(dog) then 0 else 1
			continue
		end

		p.Transparency = 0
		if piece.tone == "fur" then
			p.Color, p.Material = fur, Enum.Material.SmoothPlastic
		elseif piece.tone == "dark" then
			p.Color, p.Material = furDark, Enum.Material.SmoothPlastic
		elseif piece.tone == "collar" then
			p.Color, p.Material = collar, Enum.Material.Metal
		elseif piece.tone == "wood" then
			-- SmoothPlastic, not WoodPlanks. A textured material is the single
			-- biggest thing that makes something in this game read as old Roblox,
			-- and the kennel and its roof were the last two carrying one.
			p.Color, p.Material = kennelTones.wood, Enum.Material.SmoothPlastic
		elseif piece.tone == "trim" then
			p.Color, p.Material = kennelTones.trim, Enum.Material.SmoothPlastic
		elseif piece.tone == "roof" then
			p.Color, p.Material = kennelTones.roof, Enum.Material.SmoothPlastic
		else
			-- Only the top breed's eyes light up. The cheapest possible
			-- "this one is different" read from across the plot. The coat says
			-- what colour they light IN; `tier.glow` still says WHETHER.
			p.Color = if tier.glow then collar else EYE_DULL
			p.Material = if tier.glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end

	-- Voice.
	--
	-- Bark and snarl are the DOG, so they track the breed. The bite on the
	-- bone is the BONE, and a bone sounds the same whichever dog bites it --
	-- so it stays fixed. Scaling it by breed had it backwards anyway, handing
	-- the terrier a lower note than the mastiff. It was a squeaky toy until
	-- 2026-09-23 and is "Cartoon Bite" now (designer); the Sound is still
	-- named "Squeak" because `play(dog, "Squeak")` is the one call that fires
	-- it, and renaming an instance to match a sound is churn nobody hears.
	local function voice(name: string, id: string, pitch: number, volume: number)
		local sound = dog.body:FindFirstChild(name) :: Sound?
		if sound then
			sound.SoundId = id
			sound.PlaybackSpeed = pitch
			sound.Volume = volume
		end
	end
	voice("Bark", tier.bark, tier.pitch, tier.volume)
	voice("Snarl", Config.SOUNDS.DOG_SNARL, tier.pitch * 0.95, tier.volume)
	voice("Squeak", Config.SOUNDS.BONE_BITE, 1.0, 0.7)

	dog.plate.Enabled = true

	-- THE OWNER'S NAME IF THERE IS ONE, THE TIER'S OWN LABEL OTHERWISE.
	--
	-- It replaces "Scruffy / Rex / Titan" and deliberately NOT the breed line
	-- below it. A named dog must never be a dog whose TIER got quieter: the
	-- breed word is what a thief reads to price the risk at the fence, and the
	-- shape ladder in `Config.DOG_COATS` is what carries it at distance. Take
	-- the breed line for a custom name too and a cosmetic would be hiding a
	-- defence level, which is the one thing this whole feature may not do.
	local shown = if dog.name ~= "" then dog.name else tier.name
	dog.nameLabel.Text = shown
	dog.nameLabel.TextColor3 = collar
	-- The same fact on the kennel, which is the half that reads from the
	-- pavement -- the plate is a MaxDistance 90 billboard and small out there.
	dog.boardLabel.Text = shown
	dog.boardLabel.TextColor3 = if kennelTones.wood.R * 0.299 + kennelTones.wood.G * 0.587 + kennelTones.wood.B * 0.114 > 0.55
		then Color3.fromRGB(39, 35, 31) else Color3.fromRGB(240, 236, 226)
	dog.breedLabel.Text = if onGuardDuty(dog) then "ON GUARD"
		elseif dog.sleeping then "OFF DUTY"
		else string.upper(GuardRig.species(dog.coat, dog.level))

	dog.zzz.Enabled = dog.sleeping
	GuardVisual.state(dog, if dog.sleeping then "Sleep" elseif dog.chasing then "Chase" else "Idle")

	-- A tier change mid-nap has to re-seat the dog, or it snaps to the rest
	-- spot at the new scale while still flagged asleep.
	if dog.sleeping then
		dog.model:PivotTo(sleepCFrame(dog, tier))
	end

	-- This function repaints every piece from the tier, collar included, so a
	-- dog upgraded mid-guard-duty would come back in plain metal with the buff
	-- still running -- the exact invisible-buff trap the tell exists to avoid.
	if onGuardDuty(dog) then
		showGuardDuty(dog, true)
	end
end

-- `originCF` places the kennel and decides which way it faces: local +Z is
-- out of the doorway, and the dog rests in front of it.
function GuardDog.build(originCF: CFrame, parent: Instance, yardCF: CFrame?): Dog
	local model = Instance.new("Model")
	model.Name = "GuardDog"

	local kennelModel = Instance.new("Model")
	kennelModel.Name = "Kennel"

	local function makePart(bone: any, into: Instance): Part
		local p = Instance.new("Part")
		p.Name = bone.name
		p.Size = bone.size
		p.CFrame = originCF * CFrame.new(bone.offset)
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if bone.shape then
			p.Shape = bone.shape
		end
		p.Parent = into
		return p
	end

	-- HELD BY REFERENCE, NEVER LOOKED BACK UP BY NAME. A dog and its kennel
	-- are each one flat folder, so `FindFirstChild` returns whichever matching
	-- part was created first -- which is how the sleep puff came to hang off
	-- the LEFT roof panel of a kennel with two parts called Roof, the same bug
	-- this project already records for the castle's four finials.
	-- The Ridge used to be held here too, for the sleep puff. The puff moved
	-- onto the DOG (see below) and the reference went with it rather than
	-- being left behind as something that looks load-bearing and is not.
	local kennelPieces: { Piece } = {}
	local board: Part? = nil
	for _, bone in ipairs(KENNEL) do
		local p = makePart(bone, kennelModel)
		p.CastShadow = false
		if bone.name == "NameBoard" then
			-- Held from the loop that made it, never looked back up by name.
			-- This folder is flat and `FindFirstChild` returns whichever part
			-- was created first, which is exactly how the sleep puff came to
			-- hang off the left roof panel.
			board = p
		end
		table.insert(kennelPieces, {
			part = p, size = bone.size, offset = bone.offset, tone = bone.tone, rot = bone.rot,
		})
	end

	local pieces: { Piece } = {}
	local torso = makePart({name = "GuardAnchor", size = Vector3.new(0.1,0.1,0.1), offset = REST_OFFSET + Vector3.new(0,TORSO_Y,0)}, model)
	torso.Transparency = 1
	torso.CanTouch = false
	local skull = makePart({name = "NameplateAnchor", size = Vector3.new(0.1,0.1,0.1), offset = REST_OFFSET + Vector3.new(0,2.5,0)}, model)
	skull.Transparency = 1
	skull.CanTouch = false

	-- Three voices, not one. The dog previously "barked" with the coin-collect
	-- chime played at 1.6x, which was a placeholder that outlived its welcome.
	--
	-- SoundId and pitch are set per breed in applyTier; only the routing and
	-- falloff live here.
	for _, spec in ipairs({
		{ name = "Bark", roll = 110 },
		{ name = "Snarl", roll = 90 },
		{ name = "Squeak", roll = 70 },
	}) do
		local sound = Instance.new("Sound")
		sound.Name = spec.name
		sound.RollOffMaxDistance = spec.roll
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.Parent = torso
	end

	local head = skull

	local plate = Instance.new("BillboardGui")
	plate.Name = "Nameplate"
	plate.Size = UDim2.new(0, 110, 0, 34)
	plate.MaxDistance = 90
	plate.Parent = head

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.6, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.Parent = plate

	local breedLabel = Instance.new("TextLabel")
	breedLabel.Size = UDim2.new(1, 0, 0.4, 0)
	breedLabel.Position = UDim2.new(0, 0, 0.6, 0)
	breedLabel.BackgroundTransparency = 1
	breedLabel.Font = Enum.Font.GothamBold
	breedLabel.TextScaled = true
	breedLabel.TextColor3 = Color3.fromRGB(226, 232, 240)
	breedLabel.TextStrokeTransparency = 0.5
	breedLabel.Parent = plate

	-- THE NAME PAINTED ON THE KENNEL.
	--
	-- `Back` and not `Front`: Roblox's `NormalId.Front` is -Z, the kennel's
	-- doorway faces local +Z, and this board sits over that doorway. The plot
	-- signs record the same trap in the same words.
	--
	-- The text is a literal near-white rather than `Theme.PAPER` because this
	-- file requires no theme module and should not start -- the nameplate two
	-- blocks down already paints its breed label from a literal for the same
	-- reason.
	local boardPart = assert(board, "KENNEL must define a NameBoard for the dog's name")
	local nameSign = Instance.new("SurfaceGui")
	nameSign.Name = "NameSign"
	nameSign.Face = Enum.NormalId.Back
	nameSign.CanvasSize = Vector2.new(420, 90)
	nameSign.LightInfluence = 0
	nameSign.MaxDistance = 90
	nameSign.Parent = boardPart

	local boardLabel = Instance.new("TextLabel")
	boardLabel.Name = "DogName"
	boardLabel.Size = UDim2.fromScale(1, 1)
	boardLabel.BackgroundTransparency = 1
	boardLabel.Font = Enum.Font.FredokaOne
	boardLabel.TextScaled = true
	boardLabel.TextColor3 = Color3.fromRGB(240, 236, 226)
	boardLabel.TextStrokeTransparency = 0.35
	boardLabel.Text = ""
	boardLabel.Parent = nameSign

	-- SLEEP PUFF, OVER THE DOG'S HEAD RATHER THAN OVER THE KENNEL ROOF.
	--
	-- It emitted from the ridge, on the reasoning that it "stays put and stays
	-- visible even though the dog is tucked inside". The dog is not tucked
	-- inside: `sleepCFrame` settles it at the DOORWAY in plain sight, so the
	-- puff was already labelling the roof rather than the animal. The Dog Bed
	-- made that a real fault instead of a quiet one -- a dog asleep on a bed
	-- eight studs away would have left the puff hanging over an empty house,
	-- which is the one reading a thief must never get: it says the kennel is
	-- occupied when it is not.
	--
	-- ON AN ATTACHMENT, NOT ON THE PART. The head is repainted, resized and
	-- re-seated per breed by `layout`; an attachment rides all of that and
	-- keeps the puff above the skull rather than inside it, which is where a
	-- part-parented emitter would put it on a Mastiff at head 1.24.
	local puffAt = Instance.new("Attachment")
	puffAt.Name = "SleepPuff"
	puffAt.Position = Vector3.new(0, 1.25, 0)
	puffAt.Parent = head

	local zzz = Instance.new("ParticleEmitter")
	zzz.Name = "Zzz"
	zzz.Enabled = false
	zzz.Texture = "rbxasset://textures/particles/smoke_main.dds"
	zzz.Color = ColorSequence.new(Color3.fromRGB(226, 232, 244))
	zzz.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1.6),
	})
	zzz.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	zzz.Lifetime = NumberRange.new(1.6, 2.4)
	zzz.Rate = 3
	zzz.Speed = NumberRange.new(1.2, 2)
	zzz.SpreadAngle = Vector2.new(12, 12)
	zzz.Acceleration = Vector3.new(0, 2.5, 0)
	zzz.Parent = puffAt

	model.PrimaryPart = torso
	model.Parent = parent
	kennelModel.Parent = parent

	local dog: Dog = {
		model = model,
		kennelModel = kennelModel,
		body = torso,
		pieces = pieces,
		kennelPieces = kennelPieces,
		originCF = originCF,
		yard = yardCF,
		-- Level 0 has no tier, so this is the un-deformed rest height. `layout`
		-- recomputes it through `restCFrame` the moment a real breed is applied.
		home = (originCF * CFrame.new(REST_OFFSET + Vector3.new(0, TORSO_Y, 0))).Position,
		level = 0,
		-- The breed's own colours until an owner says otherwise. Never nil:
		-- `applyTier` indexes `Config.DOG_COATS` with it directly.
		coat = "",
		-- The plain wooden kennel until an owner buys another. Never nil, for
		-- the same reason as `coat`.
		kennel = "",
		-- No fence until one is built, so nothing to walk round.
		gate = math.huge,
		-- The breed's own label until an owner names it. Never nil: `applyTier`
		-- tests it directly.
		name = "",
		busyUntil = 0,
		napUntil = 0,
		guardUntil = 0,
		guardLockUntil = 0,
		-- Asleep until told otherwise. A plot is unowned at build time, and
		-- an unowned plot is exactly the case whose owner is never coming.
		ownerHome = false,
		alertUntil = 0,
		stirAt = 0,
		chasing = false,
		sleeping = false,
		lured = false,
		distracted = false,
		plate = plate,
		nameLabel = nameLabel,
		breedLabel = breedLabel,
		boardLabel = boardLabel,
		zzz = zzz,
	}

	GuardDog.applyTier(dog, 0)
	task.spawn(behaviour, dog)

	return dog
end

-- ============================================================
-- CHASE
-- ============================================================

-- `lured` counts as unavailable even though busyUntil is still in the past:
-- between taking the bait and reaching the bone the dog is walking away from
-- its post, and a chase started in that gap would teleport it back mid-stride.
function GuardDog.isReady(dog: Dog): boolean
	return dog.level > 0
		and not dog.chasing
		and not dog.lured
		and not onCooldown(dog)
end

-- Chases `getTargetRoot()` until it catches them, the target vanishes, or the
-- chase times out. Calls `onCatch` at most once.
--
-- The target is fetched fresh each frame rather than captured, so a thief who
-- dies or drops the loot mid-chase cleanly ends it.
-- `onCatch` RETURNS FALSE WHEN THE CATCH DID NOT LAND -- today, a thief who
-- was dodging at the moment the dog arrived. The chase then CARRIES ON rather
-- than ending, and the dog lunges again shortly after. Anything else makes a
-- half-second immunity worth the entire chase plus the dog's cooldown.
function GuardDog.chase(dog: Dog, getTargetRoot: () -> BasePart?, onCatch: () -> boolean?)
	local tier = Config.getDogTier(dog.level)
	if not tier or not GuardDog.isReady(dog) then
		return
	end
	dog.chasing = true

	-- Straight out of the kennel if it was napping when the alarm went.
	if dog.sleeping then
		rouse(dog, tier)
	end

	GuardVisual.state(dog, "Chase")

	-- The alarm bark. This is the sound a thief hears the instant they are
	-- noticed, and the one the owner hears from anywhere on their plot.
	play(dog, "Bark")

	task.spawn(function()
		task.wait(Config.DOG_START_DELAY)

		local deadline = os.clock() + tier.maxChase
		local caught = false
		-- When the dog may lunge again after one that missed.
		local pounceAt = 0
		local chaseCfg = Config.DOG_CHASE
		local reach = BODY_HALF * (tier.scale or 1)
		-- Heading as an angle on the ground plane, turned at a limited rate
		-- so a sharp cut makes the dog overshoot. Seeded from where it is
		-- facing now; the model's +Z is its nose (see `facing`).
		local look = -dog.body.CFrame.LookVector
		local angle = math.atan2(look.X, look.Z)

		-- `dog.lured` ends the chase early: that is a Golden Bone landing
		-- mid-run, the one bone a dog will break off for.
		while os.clock() < deadline and not dog.lured and dog.level > 0 and dog.model.Parent do
			local dt = RunService.Heartbeat:Wait()
			local root = getTargetRoot()
			if not root then
				break
			end
			-- Off the leash: out the back, over a side fence, or past the end
			-- of the driveway. The dog gives up and goes home.
			if not inLeash(dog, root.Position, 0) then
				break
			end

			local from = dog.body.Position
			-- Steered at the GATE when the thief is the other side of the
			-- fence, and at the thief otherwise.
			local goal = chaseGoal(dog, from, root.Position)
			local to = Vector3.new(goal.X, from.Y, goal.Z)
			local delta = to - from
			local distance = delta.Magnitude
			-- The catch is judged against the THIEF, never the waypoint.
			local reachDelta = Vector3.new(root.Position.X - from.X, 0, root.Position.Z - from.Z)

			local want = math.atan2(delta.X, delta.Z)
			local diff = (want - angle + math.pi) % (2 * math.pi) - math.pi
			local turn = chaseCfg.turnRate * dt
			angle += math.clamp(diff, -turn, turn)
			local heading = Vector3.new(math.sin(angle), 0, math.cos(angle))

			-- Only what is in front of the nose can be caught, and only
			-- across the same side of the fence: a thief standing on the
			-- pavement is not caught through the pickets.
			local sameSide = pastFence(dog, from) == pastFence(dog, root.Position)
			if sameSide and reachDelta.Magnitude <= tier.catchRadius
				and math.abs(diff) <= chaseCfg.catchCone
				and os.clock() >= pounceAt then
				-- A snarl rather than a bark, so being caught sounds different
				-- from being chased: the chase already had its own noise. It
				-- plays on a lunge whether or not the lunge lands, because a
				-- dog that went for somebody and missed has still gone for
				-- them -- and a silent miss would read as the dog ignoring a
				-- thief it was standing on top of.
				play(dog, "Snarl")
				GuardVisual.state(dog, "Attack")
				-- A DODGE BEATS THE POUNCE AND MAY NOT BEAT THE CHASE.
				--
				-- This used to set `caught` and break before anything had
				-- asked whether the catch landed, so a thief who rolled as
				-- the dog arrived kept the piggy, was still knocked out of
				-- the yard by the caller, and left the dog walking home on
				-- its full cooldown. One dodge, one whole robbery -- against
				-- `Config.DODGE`'s own rule that a dodge buys a moment and
				-- never an escape, and against the line that says a defender
				-- who eats one starts their hold again. A dog had no way to
				-- start again, because the chase was already over.
				if onCatch() ~= false then
					caught = true
					break
				end
				GuardVisual.state(dog, "Chase")
				-- DERIVED FROM THE DODGE RATHER THAN PINNED, and that is what
				-- makes one dodge worth exactly one missed lunge: the immunity
				-- is `DODGE.immunity` and a second dodge cannot arrive for
				-- `DODGE.cooldown`, which is an order of magnitude longer, so
				-- the next lunge is guaranteed to land on anybody who simply
				-- keeps running. A delay is also what stops the miss becoming
				-- its own bug -- with none, the pounce re-fires every frame
				-- for the whole immunity window and says "Dodged!" to the
				-- thief thirty times.
				pounceAt = os.clock() + Config.DODGE.immunity
			end

			local speed = tier.speed * (1 - chaseCfg.turnSlow * math.abs(diff) / math.pi)
			local moved = from + heading * math.min(speed * dt, distance)
			-- The dog never leaves its own leash box, whatever it is chasing,
			-- and leaves its own yard only through the gate.
			moved = clampToLeash(dog, moved, reach)
			moved = blockAtFence(dog, from, moved, BODY_HALF_WIDTH * (tier.scale or 1))
			dog.model:PivotTo(facing(moved, heading))
		end

		-- The snarl, the Attack pose and the catch itself all happen at the
		-- lunge, inside the loop, because a lunge that MISSES has to be able
		-- to leave the chase running. What is left here is the beat the dog
		-- stands over somebody before it trots off.
		if caught then
			task.wait(0.45)
		end

		-- Broken off by a bone. The lure owns the dog from here -- it is
		-- already waiting to walk it to the bait -- so this must not also
		-- send it home or stamp a chase cooldown over the nap it is about
		-- to be given.
		if dog.lured then
			dog.chasing = false
			return
		end

		-- Trot home, then go off duty. `behaviour` sees busyUntil and puts it
		-- to bed; the walk to the kennel is its job, not this one's.
		walkTo(dog, dog.home, tier.speed, 8)
		dog.chasing = false
		dog.busyUntil = os.clock() + tier.cooldown
	end)
end

-- ============================================================
-- BAIT
-- ============================================================

-- Takes a thrown bone: the dog drops what it is doing, trots over, eats it,
-- and is then handed back to `behaviour`, which walks it to the kennel and
-- keeps it there until the nap runs out.
--
-- Returns false plus a reason whenever the dog will not take it. The caller
-- MUST surface that and must not charge for the bone -- a thief who watches a
-- purchase vanish with no visible effect cannot tell a rule from a bug, which
-- is exactly how the steal bug survived as long as it did.
--
-- Runs on the caller's thread and blocks until the bone is eaten.
function GuardDog.lure(dog: Dog, bone: Model, nap: number, breaksChase: boolean): (boolean, string?)
	local tier = Config.getDogTier(dog.level)
	if not tier then
		return false, "there is no dog there"
	end
	if dog.lured then
		return false, "that dog already has a bone"
	end
	if dog.chasing and not breaksChase then
		return false, "it has already spotted you. Only a Golden Bone stops a chase"
	end
	if not dog.chasing and onCooldown(dog) then
		return false, "it is already off duty"
	end

	-- Guard duty: the cheap bones bounce off, the master key does not.
	--
	-- Same line the chase-break draws, and drawn here for the same reason: a
	-- defender who has paid to be left alone should raise the price of robbing
	-- them, not close the door. Refused BEFORE the stock is spent, so a thief
	-- who throws into a guarded plot keeps the bone -- see BoneService, which
	-- returns it on any refusal.
	if onGuardDuty(dog) and not breaksChase then
		return false, "that dog is on guard duty. Only a Golden Bone gets past it"
	end

	dog.lured = true

	-- Let a chase we just interrupted unwind before steering. Both loops move
	-- the same model with PivotTo, and for the frame they overlap they would
	-- fight each other.
	local settleBy = os.clock() + 1.5
	while dog.chasing and os.clock() < settleBy do
		RunService.Heartbeat:Wait()
	end

	if dog.sleeping then
		rouse(dog, tier)
	end

	-- Excited, not alarmed: same bark, pitched up, because the dog is pleased
	-- rather than angry. It is the audible half of the bone working.
	local barkSound = dog.body:FindFirstChild("Bark") :: Sound?
	if barkSound then
		local normal = barkSound.PlaybackSpeed
		barkSound.PlaybackSpeed = normal * 1.25
		barkSound:Play()
		task.delay(1, function()
			barkSound.PlaybackSpeed = normal
		end)
	end

	-- Trots rather than sprints. The walk over is the whole tell that a bone
	-- landed, for the thief and for the owner watching their dog wander off,
	-- and at full chase speed it is over before either of them sees it.
	if bone.Parent then
		walkTo(dog, bone:GetPivot().Position, tier.speed * 0.75, 6, function()
			return dog.level <= 0 or not bone.Parent
		end)
	end

	if bone.Parent then
		bone:Destroy()
	end
	-- The bite. This is the payoff moment of the whole bone mechanic --
	-- an expensive guard dog reduced to a delighted puppy -- and it wants to be
	-- funny rather than impressive.
	play(dog, "Squeak")

	-- Nap starts at the bite, not at the kennel, so the walk home is time the
	-- thief gets for free. That is deliberate: the dog is visibly out of
	-- position for those seconds, so it should count as bought.
	dog.distracted = true
	dog.napUntil = os.clock() + nap
	dog.lured = false

	return true
end

return GuardDog
