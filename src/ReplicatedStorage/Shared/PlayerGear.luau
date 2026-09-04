--!strict
--[[
	PlayerGear

	Gear worn by the PLAYER'S OWN CHARACTER, which is a different thing from
	everything else in this project's wardrobe: skins, effects and the twelve
	accessories are all worn by the PIGGY BANK on the lawn, and every pivot rule
	in CLAUDE.md is cut against the pig's eyeballs, tail and lawn line. None of
	those numbers apply here. This is the first thing that goes on a person.

	IN ReplicatedStorage BECAUSE THE SHOP RENDERS IT, the same reason House,
	Decor and PiggyModel live here: a shop tile shows the REAL item built by the
	same function that puts it on a head, and a second nearly-identical copy
	drifts from this one the first time either is touched.

	THREE THINGS ABOUT A CHARACTER THAT ARE NOT TRUE OF ANYTHING ELSE HERE, all
	measured on a live R15 rig rather than assumed:

	  * A CHARACTER FACES -Z. Measured: `FaceFrontAttachment` sits at head-local
	    z = -0.594. Every other model in this repo -- the dog, the piggy, the
	    ornaments, all five rides -- is authored facing +Z, so gear authored to
	    house convention comes out with its face hole at the BACK of the head.
	    It does not error and it does not look like a bug; it looks deliberate.

	  * THE HEAD IS ABOUT 1.20 STUDS, not the 2-stud block of old Roblox. Every
	    offset below is a fraction of that and the whole model is scaled by the
	    head it is actually going onto, so a rig with body scaling applied gets
	    gear that still fits.

	  * THE PLAYER IS ALREADY WEARING HAIR, AND IT IS THEIRS, NOT OURS. This is
	    the same problem CLAUDE.md records for the raised-arm riding stance --
	    "a limb that has to pass near the head is a limb whose final position
	    somebody else chooses" -- except here it cannot be designed around,
	    because the gear IS on the head. A hood with pigtails erupting through
	    it is the bug, so wearing this hides the wearer's hair and hats and puts
	    them back on removal.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local PlayerGear = {}

-- What the attach puts on a character, so it can be found again without
-- keeping a table keyed on a character -- which would be the weak-table trap
-- at the top of RidePose from the other end.
PlayerGear.MODEL_NAME = "PlayerGear"

-- Where a hidden accessory's own transparency is stashed while gear covers it.
-- An ATTRIBUTE rather than a table, for the reason RideSound records about the
-- footstep volume: weak-keyed the collector drops it while the engine still
-- holds the object, strong-keyed it leaks every character that ever wore
-- anything, and an attribute lives and dies with the thing it describes.
local HID_ATTR = "GearHidTransparency"

-- The head this file is solved against.
local NOMINAL_HEAD = 1.2

-- ============================================================
-- THE SHELL
-- ============================================================
--
-- ONE SOLID WITH THE EYE SLOT CUT OUT OF IT, built with runtime CSG.
--
-- This file spent a long while insisting that "a part cannot cut a hole in
-- another part", which is true of plain Parts and false of the engine:
-- `UnionAsync` and `SubtractAsync` both work at runtime, measured here at 15
-- and 17 milliseconds, and the result can be resized. Everything that was
-- painful before came from not using them.
--
-- WHAT THE OLD WAY COST. Without a subtract, an opening can only be the gap
-- between solids, so the mask became eight overlapping spheres and a cylinder
-- band, each one bounding some edge of the slot. Every one of them was solved
-- against the head and correct on its own, and the assembly still read as
-- lumps -- because a union of spheres of different radii has a visible crease
-- wherever two of them meet, and the ears were the worst of it. There is no
-- arrangement of primitives that fixes that; it is what an assembly of
-- primitives looks like. It also cost four rounds of whack-a-mole: tightening
-- the crown opened the ears, adding a side piece opened the nape, and the last
-- gap was two degrees wide and only turned up on a 2-degree sweep.
--
-- The shell is now a single sphere that contains the whole head, unioned with
-- a neck tube so it reads as a garment rather than a helmet, with an oval
-- plug subtracted from the front. One surface, no seams, no gaps to sweep for.
--
-- THE SHELL IS A SQUASHED CAPSULE, NOT A SPHERE, and that is the difference
-- between a fitted sock and an egg.
--
-- A sphere has to contain the head's furthest point to cover it, and the
-- furthest point of a rounded cylinder is its RIM -- 0.715 out, at the top and
-- bottom edges. So the smallest sphere that covers this head is 0.72, which
-- leaves it standing 0.127 proud at the face where the head is only 0.593.
-- That is the bulge you can see on the first CSG version: correct, smooth, and
-- a size too big everywhere except two rings.
--
-- A capsule follows the shape instead. Built as a cylinder with a sphere on
-- each end it comes out far too TALL -- 2.22 against a 1.22 head -- but a
-- UnionOperation can be resized non-uniformly, which a Ball cannot, so the
-- whole thing is squashed to height afterwards. The ends become oblate domes
-- and the result is a rounded cylinder: 0.06 proud at the face, 0.07 at the
-- rim, 0.14 over the crown.
local BODY_R = 0.66
local BODY_HALF = 0.45         -- half-height of the straight section, before squashing
local SHELL_HEIGHT = 1.50      -- what the capsule is squashed down to

-- The neck. Short, because the shell is welded to the HEAD and turns with it,
-- and a long tube would visibly twist against the shoulders. Unioned AFTER the
-- squash so it keeps its own proportions.
local NECK_R = 0.60
local NECK_TOP = -0.40
local NECK_BOTTOM = -0.95

-- THE EYE SLOT, cut as a ROW OF SPHERES rather than one elongated cutter.
--
-- The obvious cutter is a single cylinder with an elliptical cross-section,
-- and it is not worth the risk: a Ball part silently ignores non-uniform Size
-- (measured -- three at (6,6,6), (12,6,6) and (6,12,6) rendered identical), so
-- a Cylinder's cross-section is not something to bet the shape of the mask on
-- without checking. Overlapping spheres cannot be ambiguous. They also give
-- the rounded ends a balaclava actually has.
--
-- Each one is centred ON the shell's surface and is deep enough to break
-- through to the head: 0.66 - 0.125 = 0.535, against a head at 0.593.
-- SPACED FAR CLOSER THAN THEY ARE WIDE, or the slot comes out scalloped. Each
-- cutter subtends 10.5 degrees on the shell, so at 10-degree spacing they meet
-- almost exactly at their rims and leave a visibly wavy edge along the bottom
-- of the opening. At 2.5 they overlap four deep and the edge reads as one
-- smooth stadium.
local SLOT_R = 0.125
local SLOT_Y = 0.06
local SLOT_HALF_YAW = 20
local SLOT_YAW_STEP = 2.5

local function tempPart(shape: Enum.PartType, size: Vector3, cf: CFrame, parent: Instance): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Size = size
	part.CFrame = cf
	part.Anchored = true
	part.Parent = parent
	return part
end

-- CSG IS SERVER-ONLY, so the shell is built once on the server, parked in
-- ReplicatedStorage, and CLONED everywhere -- including by the shop, which
-- renders the real item and runs on the client.
--
-- Measured, not guessed: `UnionAsync` from a LocalScript throws "CSG API can
-- only be called from the Server", and the first version of this failed
-- exactly there -- the mask was correct on every character in the world and
-- the shop tile was empty, with the reason only in the client log.
--
-- Replicating one union is also strictly cheaper than every peer computing the
-- same one, and it guarantees the tile and the head cannot disagree.
local TEMPLATE_FOLDER = "PlayerGearTemplates"

local templates: { [string]: UnionOperation } = {}

local function templateFolder(): Instance?
	local existing = ReplicatedStorage:FindFirstChild(TEMPLATE_FOLDER)
	if existing then
		return existing
	end
	if not RunService:IsServer() then
		-- A client that asks before the server has finished waits briefly
		-- rather than building nothing: the shop is drawn at join, which is
		-- the one moment this can be a race.
		return ReplicatedStorage:WaitForChild(TEMPLATE_FOLDER, 10)
	end
	local folder = Instance.new("Folder")
	folder.Name = TEMPLATE_FOLDER
	folder.Parent = ReplicatedStorage
	return folder
end

local function templateFor(key: string): UnionOperation?
	local cached = templates[key]
	if cached then
		return cached
	end

	local spec = Config.GEAR[key]
	if not spec then
		return nil
	end

	local folder = templateFolder()
	if folder then
		local ready = folder:FindFirstChild(key)
			or (if RunService:IsServer() then nil else folder:WaitForChild(key, 10))
		if ready and ready:IsA("UnionOperation") then
			templates[key] = ready
			return ready
		end
	end
	if not RunService:IsServer() then
		return nil
	end

	local scratch = Instance.new("Folder")
	scratch.Parent = workspace

	local function fail(what: string, err: any): nil
		scratch:Destroy()
		warn(("[PlayerGear] %s failed for %s: %s"):format(what, key, tostring(err)))
		return nil
	end

	-- A ROBLOX CYLINDER'S AXIS IS ITS X AXIS. Standing one up is
	-- Vector3.new(height, d, d) plus a quarter turn about Z -- the gotcha this
	-- project has now hit six times.
	local body = tempPart(Enum.PartType.Cylinder,
		Vector3.new(BODY_HALF * 2, BODY_R * 2, BODY_R * 2),
		CFrame.new() * CFrame.Angles(0, 0, math.rad(90)), scratch)
	local capTop = tempPart(Enum.PartType.Ball,
		Vector3.new(BODY_R * 2, BODY_R * 2, BODY_R * 2), CFrame.new(0, BODY_HALF, 0), scratch)
	local capBottom = tempPart(Enum.PartType.Ball,
		Vector3.new(BODY_R * 2, BODY_R * 2, BODY_R * 2), CFrame.new(0, -BODY_HALF, 0), scratch)

	local ok, capsule = pcall(function()
		return body:UnionAsync({ capTop, capBottom })
	end)
	if not ok or not capsule then
		return fail("UnionAsync (capsule)", capsule)
	end
	capsule.Parent = scratch

	-- Squashed to height. This is the step a Ball cannot do and the whole
	-- reason the shell is a union at all.
	--
	-- WHICH AXIS IS "UP" HAS TO BE DERIVED, NOT ASSUMED. A UnionOperation
	-- inherits the orientation of the part it was built from, and this one was
	-- built from a cylinder stood on end -- so its local X is the vertical, and
	-- squashing Size.Y flattened the mask front-to-back instead. Nor can the
	-- CFrame simply be reset to identity to tidy that up: a union stores its
	-- mesh relative to its own frame, so straightening the frame tips the
	-- geometry on its side.
	local up = capsule.CFrame:VectorToObjectSpace(Vector3.new(0, 1, 0))
	local axis = Vector3.new(math.abs(up.X), math.abs(up.Y), math.abs(up.Z))
	local k = SHELL_HEIGHT / axis:Dot(capsule.Size)
	capsule.Size = capsule.Size * Vector3.new(
		if axis.X > 0.5 then k else 1,
		if axis.Y > 0.5 then k else 1,
		if axis.Z > 0.5 then k else 1)

	local neckHeight = NECK_TOP - NECK_BOTTOM
	local neck = tempPart(Enum.PartType.Cylinder,
		Vector3.new(neckHeight, NECK_R * 2, NECK_R * 2),
		CFrame.new(0, (NECK_TOP + NECK_BOTTOM) / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		scratch)

	local okNeck, shell = pcall(function()
		return capsule:UnionAsync({ neck })
	end)
	if not okNeck or not shell then
		return fail("UnionAsync (neck)", shell)
	end
	shell.Parent = scratch

	local cutters = {}
	for yaw = -SLOT_HALF_YAW, SLOT_HALF_YAW, SLOT_YAW_STEP do
		local a = math.rad(yaw)
		table.insert(cutters, tempPart(Enum.PartType.Ball,
			Vector3.new(SLOT_R * 2, SLOT_R * 2, SLOT_R * 2),
			CFrame.new(BODY_R * math.sin(a), SLOT_Y, -BODY_R * math.cos(a)), scratch))
	end

	local okCut, holed = pcall(function()
		return shell:SubtractAsync(cutters)
	end)
	if not okCut or not holed then
		return fail("SubtractAsync (eye slot)", holed)
	end

	-- One colour for the whole solid. Without UsePartColor a union keeps
	-- whatever its source parts were, which here is five different greys.
	holed.UsePartColor = true
	holed.Color = spec.shell
	holed.Material = Enum.Material.SmoothPlastic
	holed.Name = "Shell"
	holed.Anchored = false
	holed.CanCollide = false
	holed.CanQuery = false
	holed.CanTouch = false
	holed.Massless = true
	holed.Name = key
	holed.Parent = folder

	scratch:Destroy()
	templates[key] = holed
	return holed
end

-- THE LOGO, WHERE THE BRAND'S WOULD BE: a pig snout on the left temple. Same
-- substitution the patrol car makes with its roundel and the lawn statue makes
-- with PIGGY over a snout -- the layout carries the reference, and a layout is
-- a genre rather than somebody's property.
--
-- Left OUT of the union deliberately. Subtracting and unioning it in would
-- flatten it into the shell's single colour, and the whole point of it is that
-- it is pink against the dark.
local LOGO = {
	{ name = "Snout", size = Vector3.new(0.07, 0.19, 0.19), yaw = -62, pitch = 6, lift = 0.035, tone = "snout" },
	{ name = "NostrilA", size = Vector3.new(0.05, 0.045, 0.07), yaw = -65.7, pitch = 6, lift = 0.085, tone = "shell" },
	{ name = "NostrilB", size = Vector3.new(0.05, 0.045, 0.07), yaw = -58.3, pitch = 6, lift = 0.085, tone = "shell" },
}

local function seat(yaw: number, pitch: number, lift: number): CFrame
	local py, pz = math.rad(pitch), math.rad(yaw)
	local dir = Vector3.new(
		math.cos(py) * math.sin(pz),
		math.sin(py),
		-math.cos(py) * math.cos(pz))
	-- Against BODY_R, the shell's straight-section radius, which is where the
	-- temple is. Measuring against the capsule's overall extent would float it.
	local at = dir * (BODY_R + lift)
	return CFrame.lookAt(at, at + dir)
end

-- The gear, at `scale` times the authored size, with its own origin at what
-- would be the CENTRE OF THE HEAD.
function PlayerGear.build(key: string, scale: number?): Model?
	local spec = Config.GEAR[key]
	local template = templateFor(key)
	if not spec or not template then
		return nil
	end

	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = "Gear_" .. key

	local shell = template:Clone()
	-- The template is named for its key so it can be found in the folder; a
	-- clone on a head wants the role, not the key.
	shell.Name = "Shell"
	shell.Size = template.Size * s
	shell.CFrame = CFrame.new(template.CFrame.Position * s) * (template.CFrame - template.CFrame.Position)
	shell.Parent = model
	model.PrimaryPart = shell

	for _, piece in ipairs(LOGO) do
		local part = Instance.new("Part")
		part.Name = piece.name
		part.Shape = Enum.PartType.Cylinder
		part.Size = piece.size * s
		part.Color = spec[piece.tone] or spec.shell
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		local placed = seat(piece.yaw, piece.pitch, piece.lift)
		part.CFrame = CFrame.new(placed.Position * s)
			* (placed - placed.Position)
			* CFrame.Angles(0, math.rad(90), 0)
		part.Parent = model
	end

	return model
end

-- Called once by the server at startup. Without it the first template is built
-- inside whichever request happens to need it first -- which is a CSG call
-- inside a CharacterAdded handler, and CSG yields.
function PlayerGear.prewarm()
	if not RunService:IsServer() then
		return
	end
	for key in pairs(Config.GEAR) do
		templateFor(key)
	end
end

-- ============================================================
-- WEARING IT
-- ============================================================

-- IS THIS ACCESSORY ON THE HEAD? Three tests, because no single one holds.
--
-- Dumped from a live character, the two things sitting on this rig's head are
-- attached in two entirely different ways and NEITHER is a weld:
--
--   Purple Flowy Pigtails (Hair)     Handle + HairAttachment + AccessoryRigidConstraint
--   Accessory (Eyebrow)              Handle + WrapLayer + FaceFront    -- no joint at all
--
-- So the first version, which looked for a `HairAttachment` or `HatAttachment`
-- by name, caught the hair and sailed past the eyebrows -- whose attachment is
-- called `FaceFront` against the head's own `FaceFrontAttachment`, so not even
-- an exact name match would have found it. It sat at radius 0.645 against a
-- brow band at 0.640 and showed as a sliver through the top of the mask. The
-- second version followed the WELD and found nothing whatsoever, because a
-- RigidConstraint joins ATTACHMENTS rather than parts, and a WrapLayer joins
-- nothing -- it is deformed onto the body instead.
--
-- Hence: what the asset SAYS it is, then what it is JOINED to, then where it is
-- ATTACHED. Each covers a gap in the others, and any one of them is enough.
local HEAD_ACCESSORY_TYPES = {
	[Enum.AccessoryType.Hat] = true,
	[Enum.AccessoryType.Hair] = true,
	[Enum.AccessoryType.Face] = true,
	[Enum.AccessoryType.Eyebrow] = true,
	[Enum.AccessoryType.Eyelash] = true,
}

local function onTheHead(item: Accessory, head: BasePart): BasePart?
	local handle = item:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return nil
	end

	-- 1. What it says it is. Absent (Unknown) on older assets, which is why it
	--    is not the only test.
	if HEAD_ACCESSORY_TYPES[item.AccessoryType] then
		return handle
	end

	-- 2. What it is joined to. A RigidConstraint joins ATTACHMENTS, so its ends
	--    have to be followed to their parents rather than read as parts.
	for _, d in ipairs(item:GetDescendants()) do
		if d:IsA("WeldConstraint") then
			if d.Part0 == head or d.Part1 == head then
				return handle
			end
		elseif d:IsA("JointInstance") then
			if d.Part0 == head or d.Part1 == head then
				return handle
			end
		elseif d:IsA("RigidConstraint") then
			local a0, a1 = d.Attachment0, d.Attachment1
			if (a0 and a0.Parent == head) or (a1 and a1.Parent == head) then
				return handle
			end
		end
	end

	-- 3. Where it is attached. Prefix-matched in both directions, since a
	--    handle's `FaceFront` pairs with a head's `FaceFrontAttachment`.
	for _, d in ipairs(item:GetDescendants()) do
		if d:IsA("Attachment") then
			for _, ha in ipairs(head:GetChildren()) do
				if ha:IsA("Attachment") then
					local a, b = ha.Name, d.Name
					if a:sub(1, #b) == b or b:sub(1, #a) == a then
						return handle
					end
				end
			end
		end
	end

	return nil
end

-- Hair, hats and faces belong to the player and this covers the head they are
-- on, so they go away while it is worn and come back when it comes off.
local function setHeadwearHidden(character: Model, hidden: boolean)
	local head = character:FindFirstChild("Head")
	for _, item in ipairs(character:GetChildren()) do
		if item:IsA("Accessory") then
			local handle = if head and head:IsA("BasePart")
				then onTheHead(item, head)
				else nil
			if handle then
				if hidden then
					if handle:GetAttribute(HID_ATTR) == nil then
						handle:SetAttribute(HID_ATTR, handle.Transparency)
					end
					handle.Transparency = 1
				else
					local was = handle:GetAttribute(HID_ATTR)
					if was ~= nil then
						handle.Transparency = was :: number
						handle:SetAttribute(HID_ATTR, nil)
					end
				end
			end
		end
	end
end

function PlayerGear.detach(character: Model)
	local existing = character:FindFirstChild(PlayerGear.MODEL_NAME)
	if existing then
		existing:Destroy()
	end
	setHeadwearHidden(character, false)
end

-- Puts `key` on this character, replacing whatever was there. Passing nil takes
-- gear off, which is why this is one function rather than two: every caller
-- already holds "what should they be wearing" and none of them wants to branch.
function PlayerGear.attach(character: Model, key: string?)
	PlayerGear.detach(character)
	if not key or not Config.GEAR[key] then
		return
	end

	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end

	-- Scaled by the head it is ACTUALLY going on, not by the one it was drawn
	-- against, so body scaling does not leave a mask floating off a small head
	-- or swallowing a large one. The LARGEST dimension of the bounding box
	-- rather than the height: a head that is wider than it is tall would
	-- otherwise get gear sized for the wrong axis and come through the sides.
	local model = PlayerGear.build(key,
		math.max(head.Size.X, head.Size.Y, head.Size.Z) / NOMINAL_HEAD)
	if not model then
		return
	end
	model.Name = PlayerGear.MODEL_NAME

	-- Seated on the head's centre and welded there, so it follows the head
	-- through every animation. A WeldConstraint rather than a Motor6D: nothing
	-- here articulates, and this rig's joints are AnimationConstraints whose
	-- C0 is read only anyway.
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") then
			part.CFrame = head.CFrame * part.CFrame
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = head
			weld.Part1 = part
			weld.Parent = part
		end
	end

	model.Parent = character
	setHeadwearHidden(character, true)
end

return PlayerGear
