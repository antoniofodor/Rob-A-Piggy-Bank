--!strict
--[[
	HeldItem

	The prop in a player's hand: which model, how big it is, and how it sits.

	----------------------------------------------------------------------

	AN ITEM IS HELD BEFORE IT IS USED, AND THAT IS A TELL RATHER THAN A STEP.

	Every consumable in this game used to be spent by a single press: tap a
	tile, the bone is gone. That is one input, and it costs two things worth
	more than the input it saves.

	The first is the MISTAP. There is no confirmation anywhere on that path
	and no stock cap to make a mistake cheap, so a nine-year-old's stray
	thumb spends a 30,000-coin Golden Bone with nothing on screen having
	asked. Selecting is now free, and only a deliberate click in the world
	spends anything -- which puts the irreversible half of the gesture behind
	a second, aimed action.

	The second is the one that matters to the street. A thief walking up
	somebody's driveway holding a Golden Bone is INFORMATION: the defender
	reads the intent off the lawn, the same way ON GUARD on a collar tells a
	thief to walk to one of the other eleven plots. This game prefers
	information to a fight everywhere it can -- the guard-duty tell, the
	overflowing bin, the published patrol -- and the whole consumable layer
	was invisible until the instant it went off.

	SO THE HELD ITEM IS SERVER STATE, not a local flourish. Two clients
	disagreeing about what somebody is carrying would be a bug in what the
	street can read rather than a cosmetic one, which is why
	`HeldItemService` validates the stock and welds the model, and why this
	module is only the geometry it needs to do it.

	----------------------------------------------------------------------

	IT IS WELDED LIKE A RIDE, AND FOR THE SAME MEASURED REASON.

	All four builders here return ANCHORED parts, because all four exist to
	drop something on a lawn or fly it through the air. An anchored part
	welded to a humanoid PINS THE HUMANOID IN PLACE -- RideService already
	writes that down -- so every part is unanchored and made Massless in the
	same pass that welds it, with no physics step in between.

	`RideModel` builds its parts unanchored and Massless already, which is
	exactly why RideService gets to skip this. These four cannot.

	----------------------------------------------------------------------

	THE SIZE IS DERIVED FROM ONE NUMBER, NEVER TUNED PER ITEM.

	These models are authored to be seen on the ground or in flight, and run
	2.68 to 4.53 studs on their longest side against a hand measuring 0.55.
	Rather than ten hand-picked scales that each drift the first time a
	builder is touched, every prop is scaled so its longest side lands on
	`GRIP_SPAN`. A new consumable is then the right size in the hand with
	nothing to remember -- the same call `PlayerGear` makes when it scales
	from the largest bounding-box dimension.

	`span` on a grip entry overrides it, and the two that use it are the two
	BULKY ones, where matching the longest side would have put a beach ball
	in a fist because the thing is nearly as wide as it is long.

	----------------------------------------------------------------------

	THE GRIP IS PER STYLE, AND THE HAND'S FRAME WAS MEASURED RATHER THAN
	ASSUMED.

	On a live R15 rig the hand's own axes are very nearly the root's: hand +X
	reads (0.99, -0.12, 0.05) in root space and hand -Z reads
	(0.05, 0.01, -1.00). So hand-local -Z is the way the character faces, and
	hand-local -Y is down the fingers -- because the wrist attachment sits at
	local +Y 0.167, which is the arm entering from above.

	That makes the default grip readable: drop the prop below the fist and
	push it forward a little. What each entry adds is the turn that puts the
	model's OWN long axis where it belongs, and those differ because the
	builders were authored for different jobs -- a bone lies along Z, a treat
	along X, and a walkie-talkie is 4.53 studs tall on Y and is MEANT to stay
	upright. A rule that aligned every long axis with the fingers would have
	laid the radio flat, which is the one thing a radio never is.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BoneModel = require(ReplicatedStorage.Shared.BoneModel)
local GadgetModel = require(ReplicatedStorage.Shared.GadgetModel)
local HomeModel = require(ReplicatedStorage.Shared.HomeModel)
local ThiefModel = require(ReplicatedStorage.Shared.ThiefModel)

local HeldItem = {}

-- Published on the CHARACTER, so every peer can read what somebody is
-- carrying without a remote of its own -- the channel `SkinKey` and
-- `RideStyle` already use. The model is welded by the server and replicates
-- on its own; this is for the HUD, which wants the key rather than the parts.
HeldItem.ATTRIBUTE = "HeldItem"
HeldItem.MODEL_NAME = "HeldProp"

-- How long the longest side of a held prop is, in studs. The hand is 0.55
-- across and the character five studs tall, so this is about a forearm: big
-- enough to read from the pavement, small enough not to be a plank.
local GRIP_SPAN = 1.9

-- Below the fist and a little forward. Everything else is the turn.
local BASE = CFrame.new(0, -0.34, -0.16)

local function turn(x: number, y: number, z: number): CFrame
	return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
end

type Grip = { cf: CFrame, span: number? }

-- Keyed by STYLE rather than by key, because two bones share one builder and
-- would otherwise need the same entry written twice -- the copy that drifts
-- the first time either is touched.
local GRIP: { [string]: Grip } = {
	-- Authored down Z already, so it only wants tipping, so the knuckle end
	-- leads rather than the whole thing lying dead level.
	bone = { cf = BASE * turn(14, 0, 0) },
	steak = { cf = BASE * turn(14, 0, 0) },

	-- Authored down X: a quarter turn puts the length along the fingers.
	gum = { cf = BASE * turn(0, 90, 0) },
	treat = { cf = BASE * turn(0, 90, 0) },

	-- Authored standing on Y. Tipped BACK rather than levelled: a plunger
	-- carried over the shoulder reads as carried, and one aimed dead forward
	-- reads as a weapon, which is the one thing nothing in this game is.
	plunger = { cf = BASE * turn(-32, 0, 0) },
	zapper = { cf = BASE * turn(-26, 0, 0) },

	-- Over the shoulder, which is the one way anybody has ever carried a
	-- ladder. Authored standing on Y like those two, so it takes the same
	-- tip-back and for the same reason: upright in the fist reads as a staff.
	ladder = { cf = BASE * turn(-38, 0, 0) },

	-- STAYS UPRIGHT. It is a walkie-talkie; laying it along the fingers with
	-- everything else is the one arrangement nobody ever holds one in.
	radio = { cf = CFrame.new(0, -0.30, -0.10) * turn(-12, 0, 0) },

	-- The two bulky ones. Both are nearly as wide as they are long, so
	-- matching the LONGEST side would have made them enormous; the span is
	-- cut rather than the grip nudged, because the fault is size not place.
	sprinkler = { cf = CFrame.new(0, -0.34, -0.14), span = 1.45 },

	-- A WIDE PROP IS TURNED FORE-AFT, NOT PUSHED OUTWARD, and that is the one
	-- clearance on this bar that had to be solved rather than eyeballed.
	--
	-- The hand hangs at x 1.25 from the root and the thigh's outer face is at
	-- about 1.05, so only 0.2 studs separate them. Anything wider than that
	-- across the body reaches the leg by construction: measured, the coat
	-- rolled across the fingers put 0.22 studs into RightUpperLeg. Pushing it
	-- FORWARD cannot fix it either -- the thigh is 0.9 deep, so clearing it
	-- that way needs the coat 0.8 studs out in front, where it reads as
	-- floating rather than carried.
	--
	-- Turned a quarter so the long axis runs front-to-back, its lateral half
	-- is 0.37 and the inboard edge lands at 0.88, clear of the leg. Same trick
	-- the shark ornament uses from the other side: put the long axis where
	-- there is room for it.
	raincoat = { cf = BASE * turn(0, 90, 12), span = 1.35 },
}

local DEFAULT: Grip = { cf = BASE }

-- ============================================================
-- WHICH CATALOGUE A KEY CAME FROM
-- ============================================================
--
-- All four consumables share `data.consumables`, so a key is unique across
-- the whole bar and one lookup answers both "does this exist" and "who owns
-- it". Returned as a KIND rather than as a builder, so a caller that only
-- needs to know which service a key belongs to -- the use path is one -- does
-- not have to build a model to find out.

function HeldItem.kindOf(key: string): string?
	if Config.BONES[key] then
		return "bone"
	elseif Config.GADGETS[key] then
		return "gadget"
	elseif Config.HOME_ITEMS[key] then
		return "home"
	elseif Config.THIEF_KIT[key] then
		return "kit"
	end
	return nil
end

function HeldItem.specFor(key: string): any
	local kind = HeldItem.kindOf(key)
	if kind == "bone" then
		return Config.BONES[key]
	elseif kind == "gadget" then
		return Config.GADGETS[key]
	elseif kind == "home" then
		return Config.HOME_ITEMS[key]
	elseif kind == "kit" then
		return Config.THIEF_KIT[key]
	end
	return nil
end

-- No glow on either of the two that take the flag. A PointLight is for the
-- one lying in the grass at the far end of a lawn; on a prop welded to a hand
-- it is a light source following a player round the street for nothing.
function HeldItem.build(key: string): Model?
	local kind = HeldItem.kindOf(key)
	if kind == "bone" then
		return BoneModel.build(key, false)
	elseif kind == "gadget" then
		return GadgetModel.build(key, false)
	elseif kind == "home" then
		return HomeModel.build(key)
	elseif kind == "kit" then
		return ThiefModel.build(key)
	end
	return nil
end

-- ============================================================
-- ATTACHING
-- ============================================================

-- Scales about the model's own pivot. None of these four builders sets a
-- PrimaryPart -- they all pivot on the visual centre through `WorldPivot`,
-- deliberately, because the obvious primary part in each carries a quarter
-- turn of its own -- so `GetPivot` is stable and every part moves with it.
local function scaleModel(model: Model, s: number)
	if s == 1 then
		return
	end
	local origin = model:GetPivot()
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local rel = origin:ToObjectSpace(part.CFrame)
			part.Size *= s
			part.CFrame = origin * CFrame.new(rel.Position * s) * (rel - rel.Position)
		end
	end
end

function HeldItem.detach(character: Model)
	local existing = character:FindFirstChild(HeldItem.MODEL_NAME)
	if existing then
		existing:Destroy()
	end
end

-- Returns the model, or nil for a key nothing can build. Never throws: this
-- is reached from a player-facing request, and losing a prop is a cosmetic
-- fault while taking the handler down with it is not.
function HeldItem.attach(character: Model, key: string): Model?
	HeldItem.detach(character)

	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand or not hand:IsA("BasePart") then
		return nil
	end

	local ok, model = pcall(HeldItem.build, key)
	if not ok or not model then
		warn(("HeldItem: no model for '%s'"):format(tostring(key)))
		return nil
	end

	local spec = HeldItem.specFor(key)
	local grip = GRIP[spec and spec.style or ""] or DEFAULT

	local _, size = model:GetBoundingBox()
	local longest = math.max(size.X, size.Y, size.Z)
	if longest > 0 then
		scaleModel(model, (grip.span or GRIP_SPAN) / longest)
	end

	-- Placed while still anchored, so nothing can fall between here and the
	-- weld below.
	model:PivotTo(hand.CFrame * grip.cf)

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			-- THE ANCHOR COMES OFF IN THE SAME PASS AS THE WELD. See the note
			-- at the top: an anchored part welded to a humanoid pins the
			-- humanoid where it stands, which on a thief mid-getaway is the
			-- worst thing this file could ship.
			part.Anchored = false
			part.Massless = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = hand
			weld.Part1 = part
			weld.Parent = part
		end
	end

	model.Name = HeldItem.MODEL_NAME
	model.Parent = character
	return model
end

return HeldItem
