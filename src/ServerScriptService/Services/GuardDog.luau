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
	-- The toys standing on the lawn: every one in `Config.DOG_TOYS` is BUILT
	-- at boot and hidden, and putting one out is a Transparency write rather
	-- than a construction. Same call the duty vest makes, for the same reason:
	-- a plot's toys change whenever an owner taps a card, and rebuilding parts
	-- on a tap is work done in front of somebody.
	toys: { [string]: { Part } },
	-- Which of them are OUT. Read by the patrol, so it has to be a fact this
	-- module holds rather than one it asks `DataService` for -- `GuardDog`
	-- requires nothing and must go on requiring nothing.
	toysOut: { [string]: boolean },
	-- The owner's name for it, or "" for the breed's own label. ALREADY
	-- FILTERED by the time it reaches here: this module never sees what a
	-- player typed, only what `TextService` handed back -- see
	-- `CosmeticsService.nameDog`, which is the one place that call is made.
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

-- Kennel geometry remains separate from the imported guard rig.
local KENNEL: { any } = {
	{ name = "Base", size = Vector3.new(6.20, 0.50, 6.60), offset = Vector3.new(0, 0.25, 0), tone = "trim" },
	{ name = "Floor", size = Vector3.new(5.30, 0.40, 5.44), offset = Vector3.new(0, 0.66, 0), tone = "wood" },
	-- NO TWO OF THESE SHARE A FACE PLANE, and every one of the differences is
	-- deliberate rather than spare. Sized to match -- which is the obvious way
	-- to build a box -- the floor, the back wall and both side walls agree on
	-- their side planes and their tops, which is four coplanar pairs on an
	-- object twelve plots carry.
	{ name = "BackWall", size = Vector3.new(5.50, 3.90, 0.46), offset = Vector3.new(0, 2.72, -2.58), tone = "wood" },
	{ name = "SideWall", size = Vector3.new(0.44, 3.80, 5.74), offset = Vector3.new(-2.60, 2.72, 0), tone = "wood" },
	{ name = "SideWall", size = Vector3.new(0.44, 3.80, 5.74), offset = Vector3.new(2.60, 2.72, 0), tone = "wood" },
	{ name = "DoorPost", size = Vector3.new(0.70, 3.30, 0.70), offset = Vector3.new(-2.40, 2.52, 2.60), tone = "trim" },
	{ name = "DoorPost", size = Vector3.new(0.70, 3.30, 0.70), offset = Vector3.new(2.40, 2.52, 2.60), tone = "trim" },
	{ name = "Lintel", size = Vector3.new(6.00, 1.00, 0.50), offset = Vector3.new(0, 4.15, 2.76), tone = "trim" },
	-- THE NAME BOARD, over the door. A dog with its name painted on its own
	-- house is a dog somebody OWNS, and that is the cheapest way to say so
	-- from the pavement -- the nameplate is a `MaxDistance` 90 billboard and
	-- small at that range, so the board is the half that carries.
	--
	-- SET INTO THE LINTEL RATHER THAN LAID ON IT. The board's back face sits
	-- at z 2.97 against a lintel front at 3.01, so it is embedded by four
	-- hundredths and shares no plane with anything. A board sized to sit
	-- exactly on that face is the coplanar flicker the comment at the top of
	-- this table already lists four instances of.
	--
	-- `wood` rather than `trim`, so it reads as a separate plaque against the
	-- darker lintel behind it -- and NOT `roof`, which follows the coat: a
	-- board that took the coat colour would put white text on the Shadow
	-- coat's near-black and lose the one thing it exists to show.
	{ name = "NameBoard", size = Vector3.new(4.20, 0.90, 0.18), offset = Vector3.new(0, 4.15, 3.06), tone = "wood" },
	{
		name = "RoofPanel", size = Vector3.new(3.70, 0.40, 7.10), offset = Vector3.new(-1.50, 5.30, 0),
		tone = "roof", rot = CFrame.Angles(0, 0, math.rad(28)),
	},
	{
		name = "RoofPanel", size = Vector3.new(3.70, 0.40, 7.10), offset = Vector3.new(1.50, 5.30, 0),
		tone = "roof", rot = CFrame.Angles(0, 0, math.rad(-28)),
	},
	-- ONE part called Ridge, and the sleep puff hangs off it. The old emitter
	-- was parented to `FindFirstChild("Roof")` against TWO parts named Roof,
	-- so it hung off the left panel -- the castle-finial bug, in miniature,
	-- sitting in this file the whole time.
	{ name = "Ridge", size = Vector3.new(0.95, 0.55, 7.30), offset = Vector3.new(0, 6.02, 0), tone = "trim" },
	{ name = "Eave", size = Vector3.new(0.45, 0.55, 7.20), offset = Vector3.new(-3.36, 4.42, 0), tone = "trim" },
	{ name = "Eave", size = Vector3.new(0.45, 0.55, 7.20), offset = Vector3.new(3.36, 4.42, 0), tone = "trim" },
	-- A bowl. Two parts, and it is what turns a box on the grass into somewhere
	-- an animal lives.
	-- Size is (LENGTH, diameter, diameter): a Roblox cylinder's axis is its X
	-- axis, and the quarter turn about Z is what stands it up. Written the
	-- other way round this is a wide disc laid flat, which is the mistake this
	-- project has now made five times.
	{ name = "Bowl", size = Vector3.new(0.55, 1.70, 1.70), offset = Vector3.new(3.90, 0.30, 2.20), tone = "trim", rot = CFrame.Angles(0, 0, math.rad(90)), shape = Enum.PartType.Cylinder },
	{ name = "BowlRim", size = Vector3.new(0.28, 2.00, 2.00), offset = Vector3.new(3.90, 0.60, 2.20), tone = "roof", rot = CFrame.Angles(0, 0, math.rad(90)), shape = Enum.PartType.Cylinder },
}

-- THE TOYS. Three small objects that stand beside the kennel and give the dog
-- somewhere to go -- see `Config.DOG_TOYS` for what they are for and why none
-- of them may change an outcome.
--
-- EVERY OFFSET IS FROM THE TOY'S OWN `spot`, NOT FROM THE KENNEL, so a toy is
-- one shape that can be seated anywhere: the kennel-local placement lives in
-- Config where it can be measured against the decor grid, and the geometry
-- here does not know where it stands. That also means these ride along for
-- free if the kennel is ever moved or turned.
--
-- BUILT AT SCALE 1 AND NEVER SCALED. A toy belongs to the PLOT rather than to
-- the animal, so a Mastiff does not get a bigger ball -- the tier is carried
-- by the dog's own size and a toy that grew with it would be one more channel
-- saying which tier was bought. The bed is sized for the LARGEST breed, since
-- a Titan lying in a Scruffy-sized bed is the failure that would show.
--
-- EVERYTHING SINKS ABOUT 0.05 INTO THE LAWN. A part whose bottom face lands
-- exactly on the grass is coplanar with it, which is the flicker this project
-- has now recorded five times -- and the fix is a convention rather than a
-- list of numbers: anything standing on something sinks slightly into it.
local TOYS: { [string]: { any } } = {
	ball = {
		{ name = "Ball", size = Vector3.new(1.60, 1.60, 1.60), offset = Vector3.new(0, 0.74, 0),
			tone = "body", shape = Enum.PartType.Ball },
		-- A band round the equator, 0.03 proud of the sphere. Sunk flush it
		-- would flicker; that is the coplanar rule this project has recorded
		-- five times, and on a curved surface the only way to be seen at all
		-- is to stand proud of it.
		--
		-- Cylinders take their length on X, so a disc lying flat is sized
		-- (thickness, diameter, diameter) and turned a quarter about Z. The
		-- other way round it is a wide disc standing on edge, which is the
		-- mistake this project has made five times and which the kennel's own
		-- food bowl already carries a note about.
		{ name = "BallStripe", size = Vector3.new(0.50, 1.66, 1.66), offset = Vector3.new(0, 0.74, 0),
			tone = "trim", shape = Enum.PartType.Cylinder,
			rot = CFrame.Angles(0, 0, math.rad(90)) },
	},
	bowl = {
		-- **THE LIP GOES UNDER THE WATER, NOT OVER IT**, and the first build
		-- had it the other way round -- copied from the kennel's own food
		-- bowl, where a wider disc sitting ON TOP is exactly right because
		-- that bowl is empty scenery.
		--
		-- A Roblox cylinder is SOLID. There is no annulus primitive, so a rim
		-- placed above the body is not a ring you look through, it is a
		-- 2.60-wide plate laid over the whole bowl -- and measured, it spanned
		-- y 0.500 to 0.820 against water at 0.690 to 0.790, so it contained
		-- the water completely. A 25,000-coin Water Bowl with no water in it,
		-- and nothing would have errored.
		--
		-- So the lip is a wide, shallow disc LOW on the body, which is what a
		-- moulded plastic bowl actually has, and the water is the highest
		-- thing here. Same rule as the moat's kerbs from the other end: the
		-- eye takes the highest line as the surface, so the surface has to be
		-- the water.
		{ name = "BowlRim", size = Vector3.new(0.25, 2.60, 2.60), offset = Vector3.new(0, 0.42, 0),
			tone = "trim", shape = Enum.PartType.Cylinder,
			rot = CFrame.Angles(0, 0, math.rad(90)) },
		{ name = "BowlBody", size = Vector3.new(0.68, 2.30, 2.30), offset = Vector3.new(0, 0.30, 0),
			tone = "body", shape = Enum.PartType.Cylinder,
			rot = CFrame.Angles(0, 0, math.rad(90)) },
		-- Seated INTO the body and standing 0.08 proud of it. Flush with the
		-- body's top face would be the coplanar flicker this project has
		-- recorded five times; below it, the opaque body hides it.
		{ name = "Water", size = Vector3.new(0.12, 2.06, 2.06), offset = Vector3.new(0, 0.66, 0),
			tone = "accent", shape = Enum.PartType.Cylinder,
			rot = CFrame.Angles(0, 0, math.rad(90)), transparency = 0.35 },
	},
	bed = {
		-- OPEN AT THE FRONT (+Z), so a dog lying in it is seen rather than
		-- walled in. The whole point of the bed is that the sleeping posture
		-- still reads from the pavement -- that posture is half of the "this
		-- plot is unguarded" tell, and a bed with four sides would hide it.
		--
		-- Sized for a Titan: torso 3.00 x 1.3 scale is 3.9 long and about 3.4
		-- across at girth 1.2, against an interior of 5.0 by 3.9.
		{ name = "BedBase", size = Vector3.new(5.40, 0.45, 4.20), offset = Vector3.new(0, 0.17, 0),
			tone = "body" },
		-- No two of these four share a face plane, which is checked rather
		-- than assumed: the rims are narrower and shallower than the base, and
		-- the SIDE rims differ from the BACK rim in height (0.10-0.70 against
		-- 0.145-0.695) precisely because they overlap it at the corners, where
		-- matching heights would have been a coplanar pair on both faces.
		{ name = "BedRim", size = Vector3.new(5.20, 0.55, 0.45), offset = Vector3.new(0, 0.42, -2.12),
			tone = "trim" },
		{ name = "BedRim", size = Vector3.new(0.45, 0.60, 4.00), offset = Vector3.new(-2.72, 0.40, 0),
			tone = "trim" },
		{ name = "BedRim", size = Vector3.new(0.45, 0.60, 4.00), offset = Vector3.new(2.72, 0.40, 0),
			tone = "trim" },
	},
}

-- How high a dog lies when it sleeps on the bed rather than on the grass: the
-- cushion's own top face. Derived from the geometry above rather than typed,
-- so a thicker cushion carries the dog up with it.
local BED_TOP = 0.17 + 0.45 / 2

local EYE_DULL = Color3.fromRGB(24, 20, 18)
local KENNEL_WOOD = Color3.fromRGB(146, 106, 70)
local KENNEL_TRIM = Color3.fromRGB(94, 66, 42)

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
		local to = Vector3.new(target.X, from.Y, target.Z)
		local delta = to - from
		if delta.Magnitude < 0.6 then
			finished()
			return true
		end

		-- Face along the travel direction rather than at the target: a step
		-- that landed exactly on the target would make CFrame.lookAt degenerate.
		local heading = delta.Unit
		local moved = from + heading * math.min(speed * dt, delta.Magnitude)
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

-- WHERE A TOY STANDS, IN THE WORLD. Kennel-local in Config, so this is the
-- one place the two frames meet.
local function toySpot(dog: Dog, key: string): Vector3?
	local toy = Config.DOG_TOYS[key]
	if not toy or not dog.toysOut[key] then
		return nil
	end
	return (dog.originCF * CFrame.new(toy.spot)).Position
end

-- HOW FAR A DOG REACHES PAST THE POINT IT IS WALKING TO, at scale 1.
--
-- `walkTo` drives the TORSO, and the Mastiff is 9.9 studs nose to tail at its
-- own 1.3 scale -- so a dog whose torso is standing on the fence line has
-- half its body through the fence. Measuring the destination and forgetting
-- the animal standing on it is the same mistake as a prompt that measures to
-- a part's centre and forgets where a thief can put their feet.
local BODY_HALF = 3.81

-- Hold a patrol destination inside the fence.
--
-- THE RECTANGLE IS THE FENCE'S, not the plot slab's, and it is the same one
-- `PlotService.yardContaining` tests -- so "where a dog may walk" and "whose
-- yard is this" can never disagree about where a yard ends. Inset by the
-- dog's own reach, because the thing that has to stay inside is the animal
-- rather than the point it is aiming at.
--
-- A CLAMP AND NOT A SHORTER RADIUS, because a toy is a fixed destination
-- rather than a distance along a ray -- shortening only works for the random
-- branch, and this has to cover every branch or it covers none.
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

local function sleepCFrame(dog: Dog, tier: any): CFrame
	local scale = tier.scale

	-- ON THE BED IF THERE IS ONE, and this is the only thing in `Config.DOG_TOYS`
	-- that changes where the dog ENDS UP rather than where it walks.
	--
	-- It survives the rule that a cosmetic may never move a tell because the
	-- tell was never the kennel: what a thief reads is the sleeping POSTURE,
	-- the puff and OFF DUTY on the nameplate, and all three follow the dog. It
	-- has never been hidden inside the kennel either -- it settles at the
	-- DOORWAY, in plain sight -- so a bed a few studs away is the same picture
	-- somewhere else on the same lawn.
	local bed = Config.DOG_TOYS.bed
	if bed and bed.kind == "sleep" and dog.toysOut.bed then
		-- Lying ON the cushion rather than through it. `BED_TOP` is derived
		-- from the bed's own geometry, so a thicker cushion carries the dog up
		-- with it instead of leaving a Mastiff sunk into its own bed.
		--
		-- Facing out of the kennel, not into the bed: the orientation comes
		-- from `originCF` exactly as the doorway version does, which keeps a
		-- sleeping dog pointed the way a passer-by is looking.
		local at = dog.originCF
			* CFrame.new(bed.spot + Vector3.new(0, torsoY(tier) - 0.55 * scale + BED_TOP, 0))

		-- CLAMPED HERE RATHER THAN IN `settle`, which is the whole reason
		-- this returns a CFrame rather than being inlined at the call site.
		-- Settling down never goes through `patrolTarget`, so the guarantee
		-- that no toy offset can put a dog through a fence would otherwise
		-- have covered every destination except the one it walks to most
		-- deliberately -- and clamping in `settle` instead would be worse than
		-- not clamping at all: the dog would walk to the clamped point and
		-- then lie down at the unclamped one, which is the two-copies-of-one-
		-- position bug this function exists to avoid.
		--
		-- The bed's own spot is measured well inside the yard, so this changes
		-- nothing today. It is the invariant rather than a fix.
		return CFrame.new(clampToYard(dog, at.Position, tier)) * dog.originCF.Rotation
	end

	-- Just inside the doorway, settled onto the floor, still facing out so a
	-- passer-by can see it is asleep rather than missing.
	return dog.originCF * CFrame.new(0, torsoY(tier) - 0.55 * scale, 0.4 * scale)
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

-- The speed above which this breed hears a footstep, or nil where there is no
-- dog at all -- which is how every caller checks "is there one".
--
-- Exported so the watcher never has to reach into `dog.level` and look a tier
-- up for itself. Which tier a dog is, and what that tier can hear, is this
-- file's business; WHO is making the noise is the caller's.
function GuardDog.noticeSpeed(dog: Dog): number?
	local tier = Config.getDogTier(dog.level)
	return if tier then tier.notice else nil
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
	-- Walk to whatever it is about to lie on. Taken from `sleepCFrame` rather
	-- than computed a second time, so the bed can never be somewhere the dog
	-- walks to and not somewhere it lies down -- two copies of one position is
	-- how a dog comes to snap five studs sideways as it falls asleep.
	-- `sleepCFrame` is already clamped to the yard, so the walk and the
	-- lie-down cannot disagree about where the bed is.
	local mouth = if dog.toysOut.bed
		then sleepCFrame(dog, tier).Position
		else (dog.originCF * CFrame.new(0, 0, 2.4 * tier.scale)).Position
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
	dog.breedLabel.Text = if onGuardDuty(dog) then "ON GUARD" else string.upper(tier.breed)

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
-- A toy does not add a behaviour: the dog already walked to a random point
-- inside `DOG_PATROL_RADIUS` every few seconds, and a toy REPLACES where that
-- step goes. Under half the time, so a dog with three toys still spends most
-- of its patrol pacing the lawn rather than commuting between objects -- see
-- `Config.DOG_TOY_VISIT_CHANCE`.
--
-- **ANY CLAMP ON WHERE A GUARD DOG MAY WALK BELONGS HERE**, because every
-- branch returns through this one point. That matters more than it looks:
-- the wander is a radius around `home`, `home` is offset out of the kennel
-- doorway, and the kennel stands in a corner of the plot -- so the radius and
-- the fence are two numbers nothing currently multiplies together. A clamp
-- added here covers the toys for free; one added at the call site would not.
--
-- `clampToYard` is what fills that in, and note `settle` has to call it too:
-- lying down is a destination this function never sees.
--
-- Returns the point and, when it is a toy, which one -- because arriving at a
-- BALL is the one destination that does something on arrival.
local function patrolTarget(dog: Dog): (Vector3, string?)
	local tier = Config.getDogTier(dog.level)
	local out: { string } = {}
	for key, toy in pairs(Config.DOG_TOYS) do
		-- `visit` only. The bed is a place the dog SLEEPS, and walking over to
		-- stand next to a bed it is not lying in is the uncanny version of
		-- this feature.
		if toy.kind == "visit" and dog.toysOut[key] then
			table.insert(out, key)
		end
	end

	if #out > 0 and math.random() < Config.DOG_TOY_VISIT_CHANCE then
		local key = out[math.random(#out)]
		local spot = toySpot(dog, key)
		if spot then
			-- STAND BESIDE IT, NEVER ON IT. `walkTo` drives the torso to the
			-- point it is given, so aiming at the toy itself puts a 3.9-stud
			-- Mastiff through a water bowl. Approached from wherever the dog
			-- happens to be, so the dog ends up on the near side and the toy
			-- stays visible between it and whoever is watching.
			local from = dog.body.Position
			local away = Vector3.new(from.X - spot.X, 0, from.Z - spot.Z)
			local dir = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, 1)
			return clampToYard(dog, spot + dir * 1.9, tier), key
		end
	end

	local angle = math.random() * math.pi * 2
	local dist = math.random() * Config.DOG_PATROL_RADIUS
	return clampToYard(dog,
		dog.home + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist),
		tier), nil
end

-- A BOUNCE, AND DELIBERATELY NOT A SOUND.
--
-- The bark is the "a dog has seen me" signal a thief reads from the pavement,
-- and this game has exactly one of those on purpose -- giving the alarm-only
-- case its own noise is already recorded here as something that would teach
-- the street to tell "somebody is home" from "nobody is" by ear. A ball that
-- squeaked would be a bought object making that same noise for no reason at
-- all, which is worse: it would train players to ignore it.
--
-- So the ball moves and says nothing. Driven with plain CFrame writes rather
-- than a TweenService require, because it is nine lines and this module
-- currently requires exactly one thing.
local function nudgeBall(dog: Dog)
	local parts = dog.toys.ball
	if not parts or not parts[1] then
		return
	end
	local ball = parts[1]
	local rest = ball.CFrame
	task.spawn(function()
		-- Two hops, the second smaller, over about a second. Anything longer
		-- and the dog has walked away from its own ball before it stops
		-- moving.
		for _, height in ipairs({ 1.5, 0.7 }) do
			local started = os.clock()
			while true do
				local t = (os.clock() - started) / 0.42
				if t >= 1 or ball.Parent == nil then
					break
				end
				-- A parabola, so it leaves and lands at the grass rather than
				-- easing to a halt in mid-air.
				ball.CFrame = rest + Vector3.new(0, height * 4 * t * (1 - t), 0)
				RunService.Heartbeat:Wait()
			end
		end
		if ball.Parent then
			ball.CFrame = rest
		end
	end)
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
				local target, visiting = patrolTarget(dog)
				local arrived = walkTo(dog, target, tier.speed * Config.DOG_PATROL_SPEED, 8, function()
					return dog.chasing or dog.lured or dog.level <= 0 or onCooldown(dog)
				end)
				if arrived and visiting == "ball" then
					nudgeBall(dog)
				end
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
		dog.breedLabel.Text = string.upper(tier.breed)
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
	local scale = tier.scale
	for _, piece in ipairs(dog.kennelPieces) do
		piece.part.Size = piece.size * scale
		piece.part.CFrame = dog.originCF * CFrame.new(piece.offset * scale) * (piece.rot or CFrame.identity)
	end
	dog.model:PivotTo(restCFrame(dog, tier))
	dog.home = dog.body.Position
	GuardVisual.apply(dog, tier, torsoY(tier))
	local height = dog.model:GetAttribute("GuardHeight") or 2.5
	local head = dog.plate.Parent :: BasePart
	head.CFrame = dog.body.CFrame * CFrame.new(0, height - torsoY(tier), 0)
	dog.plate.StudsOffsetWorldSpace = Vector3.new(0, 0.65, 0)
end

-- WHAT IS ACTUALLY VISIBLE ON THE LAWN, which is not the same question as
-- what the owner asked for.
--
-- `toysOut` is the OWNER'S choice and is kept whatever happens to the dog;
-- what shows is that choice AND a dog existing to use it. A level-0 plot has
-- no animal, and a ball on a lawn with nothing to fetch it is an object with
-- no explanation -- so toys hide with the DOG rather than with the kennel,
-- which deliberately stays standing at level 0 because an empty kennel is what
-- the upgrade is sold against.
--
-- Keeping the choice rather than clearing it is what makes a rebirth
-- survivable: the dog level goes to zero, the toys go away, and every one of
-- them comes back with the first tier bought -- exactly as the name does.
local function refreshToys(dog: Dog)
	local live = Config.getDogTier(dog.level) ~= nil
	for key, parts in pairs(dog.toys) do
		local show = live and dog.toysOut[key] == true
		for _, part in ipairs(parts) do
			-- The AUTHORED transparency, never zero: the water in the bowl is
			-- translucent, and reading it back off the part would hand back
			-- whatever hiding it last wrote.
			part.Transparency = if show then (part:GetAttribute("ToyTransparency") or 0) else 1
		end
	end
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

-- PUT TOYS OUT, OR TAKE THEM IN. Takes the whole set rather than one key,
-- because that is the shape the save has and the shape the push sends -- and
-- a per-key setter would need the caller to remember which ones it had NOT
-- mentioned, which is how a toy comes to be left out on a plot somebody
-- moved out of.
--
-- Does NOT go through `applyTier`, which is the one setter here that does
-- not. `applyTier` repaints the ANIMAL and its house from the tier and the
-- coat; a toy belongs to the plot, is painted once at build and never takes a
-- tier colour. Routing it through there would mean every coat change also
-- rewrote every toy's transparency for nothing.
function GuardDog.setToys(dog: Dog, out: { [string]: boolean }?)
	table.clear(dog.toysOut)
	for key in pairs(dog.toys) do
		dog.toysOut[key] = (out and out[key]) == true
	end
	refreshToys(dog)
end

-- Name the dog, or clear the name with nil or "".
--
-- **WHAT ARRIVES HERE IS ALREADY FILTERED AND THIS FUNCTION DOES NOT CHECK.**
-- That is deliberate and it is the whole reason the filtering lives in exactly
-- one place: `CosmeticsService.nameDog` makes the `TextService` call and is
-- the only caller. A second filter here would look like defence and would
-- actually be the opposite -- two places that both "handle" moderation is how
-- one of them ends up trusted and skipped. If this ever grows a second caller,
-- the filter moves down here rather than being duplicated up there.
--
-- Repaints through `applyTier` for the same reason `setCoat` does: that is the
-- one function that decides what a dog looks like, and it also restores the
-- duty vest and the breed line, both of which a second painting path drops.
function GuardDog.setName(dog: Dog, name: string?)
	dog.name = name or ""
	GuardDog.applyTier(dog, dog.level)
end

-- Repaints and resizes the dog and its kennel into the breed for `level`.
-- Level 0 hides both the animal and its toys; the KENNEL stays standing,
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
		-- The toys go with the animal, not with its house. The owner's CHOICE
		-- is kept in `toysOut` and comes back with the first tier bought.
		refreshToys(dog)
		return
	end

	refreshToys(dog)

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
	-- An unknown key is the plain wooden kennel, never an error: a skin
	-- retired from the catalogue leaves every save that owned one still
	-- rendering a house. `DataService.reconcile` prunes the save on load, so
	-- this is the second of two guards rather than the only one.
	local den = Config.DOG_KENNELS[dog.kennel or ""]
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
			p.Color, p.Material = (if den then den.wood else KENNEL_WOOD), Enum.Material.SmoothPlastic
		elseif piece.tone == "trim" then
			p.Color, p.Material = (if den then den.trim else KENNEL_TRIM), Enum.Material.SmoothPlastic
		elseif piece.tone == "roof" then
			-- AND A KENNEL SKIN DELIBERATELY DOES NOT REACH THIS BRANCH.
			-- Kennel roof takes the collar colour, so the kennel reads as
			-- belonging to this DOG from as far away as the dog does -- which
			-- is why it follows the coat rather than the breed now that those
			-- are two different things. A kennel that stayed on the tier
			-- colour while its occupant changed would read as the wrong dog's
			-- house.
			p.Color, p.Material = collar, Enum.Material.SmoothPlastic
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
	-- Bark and snarl are the DOG, so they track the breed. The squeak is the
	-- TOY, and a squeaky toy sounds the same whichever dog bites it -- so it
	-- stays fixed. Scaling it by breed had it backwards anyway, handing the
	-- terrier a lower squeak than the mastiff.
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
	voice("Squeak", Config.SOUNDS.DOG_SQUEAK, 1.0, 0.6)

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
	dog.breedLabel.Text = if onGuardDuty(dog) then "ON GUARD"
		elseif dog.sleeping then "OFF DUTY"
		else string.upper(tier.breed)

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

	-- THE TOYS, BUILT HIDDEN AND PARENTED TO THE KENNEL MODEL.
	--
	-- The kennel is the one model here that is never pivoted -- the dog's own
	-- model is moved every patrol step, and anything the dog WALKS TO has to
	-- sit outside the thing that moves or it flees at exactly the dog's speed.
	-- That is the bug this file already records for the kennel itself, and a
	-- ball parented to the dog would reproduce it exactly.
	--
	-- All of them are built whether or not they are owned, for the reason the
	-- duty vest is: putting a toy out is then a Transparency write on a part
	-- that already exists, and the alternative is constructing geometry inside
	-- a shop tap.
	local toyParts: { [string]: { Part } } = {}
	for key, toy in pairs(Config.DOG_TOYS) do
		local parts: { Part } = {}
		for _, bone in ipairs(TOYS[key] or {}) do
			local p = Instance.new("Part")
			p.Name = "Toy_" .. key
			p.Size = bone.size
			p.CFrame = originCF * CFrame.new(toy.spot + bone.offset) * (bone.rot or CFrame.new())
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CastShadow = false
			-- The colour comes from `Config.DOG_TOYS`, not from the geometry
			-- table: the SHOP has to draw a swatch for these and cannot
			-- require this file, so one table feeds both or the two drift.
			p.Color = toy[bone.tone] or toy.body
			p.Material = Enum.Material.SmoothPlastic
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			if bone.shape then
				p.Shape = bone.shape
			end
			-- Stashed rather than read back off `Transparency`, because
			-- hiding a toy overwrites that: without this the water in the
			-- bowl would come back opaque the first time it was put away and
			-- taken out again.
			p:SetAttribute("ToyTransparency", bone.transparency or 0)
			p.Transparency = 1
			p.Parent = kennelModel
			table.insert(parts, p)
		end
		toyParts[key] = parts
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
		toys = toyParts,
		toysOut = {},
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
function GuardDog.chase(dog: Dog, getTargetRoot: () -> BasePart?, onCatch: () -> ())
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

		-- `dog.lured` ends the chase early: that is a Golden Bone landing
		-- mid-run, the one bone a dog will break off for.
		while os.clock() < deadline and not dog.lured and dog.level > 0 and dog.model.Parent do
			local dt = RunService.Heartbeat:Wait()
			local root = getTargetRoot()
			if not root then
				break
			end

			local from = dog.body.Position
			local to = Vector3.new(root.Position.X, from.Y, root.Position.Z)
			local delta = to - from

			if delta.Magnitude <= tier.catchRadius then
				caught = true
				break
			end

			local heading = delta.Unit
			local moved = from + heading * math.min(tier.speed * dt, delta.Magnitude)
			dog.model:PivotTo(facing(moved, heading))
		end

		if caught then
			-- A snarl rather than a bark, so being caught sounds different from
			-- being chased. The chase already had its own noise.
			play(dog, "Snarl")
			GuardVisual.state(dog, "Attack")
			onCatch()
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
	-- The squeaky toy. This is the payoff moment of the whole bone mechanic --
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
