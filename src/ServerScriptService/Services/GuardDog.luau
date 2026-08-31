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

	Each level is a different breed rather than the same dog with a bigger
	number. Parts are resized and recoloured in place on upgrade, so the Dog
	record stays valid and nothing holding a reference has to care.

	Parts are anchored and moved with Model:PivotTo, which moves every
	descendant -- so there are deliberately no welds here. Welds would only
	have to be torn down and rebuilt every time a tier change resized things.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local GuardDog = {}

-- Which tier colour a part takes. Kept as a tag rather than a stored colour
-- so applyTier can repaint everything without knowing the geometry.
type Tone = "fur" | "dark" | "eye" | "collar" | "wood" | "roof"

type Piece = {
	part: Part,
	size: Vector3,   -- at scale 1
	offset: Vector3, -- from the kennel origin, at scale 1
	tone: Tone,
	rot: CFrame?,    -- extra local rotation, never scaled
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
	home: Vector3,           -- the torso's on-duty rest position
	level: number,
	busyUntil: number,
	chasing: boolean,
	sleeping: boolean,
	plate: BillboardGui,
	nameLabel: TextLabel,
	breedLabel: TextLabel,
	zzz: ParticleEmitter,
}

-- The dog rests this far out from the kennel, so the doorway stays visible
-- and it is not standing inside its own house while on duty.
local REST_OFFSET = Vector3.new(0, 0, 5.5)

-- Dog geometry, all at scale 1, relative to the dog's own feet. The torso
-- must come first: it becomes the model's PrimaryPart, and therefore its
-- pivot. The snout sits at +Z, which is what `facing` below depends on.
local SKELETON: { { name: string, size: Vector3, offset: Vector3, tone: Tone, shape: Enum.PartType? } } = {
	{ name = "Torso", size = Vector3.new(2.2, 1.8, 3.6), offset = Vector3.new(0, 1.9, 0), tone = "fur" },
	{ name = "Head", size = Vector3.new(1.7, 1.6, 1.7), offset = Vector3.new(0, 2.6, 2.3), tone = "fur" },
	{ name = "Snout", size = Vector3.new(0.9, 0.7, 0.9), offset = Vector3.new(0, 2.35, 3.1), tone = "dark" },
	{ name = "Tail", size = Vector3.new(0.5, 0.5, 1.4), offset = Vector3.new(0, 2.5, -2.1), tone = "dark" },
	{ name = "Collar", size = Vector3.new(1.9, 0.6, 0.75), offset = Vector3.new(0, 2.4, 1.85), tone = "collar" },
	{ name = "Tag", size = Vector3.new(0.35, 0.35, 0.16), offset = Vector3.new(0, 2.05, 2.2), tone = "collar" },
}

for _, side in ipairs({ -1, 1 }) do
	table.insert(SKELETON, { name = "Ear", size = Vector3.new(0.5, 1, 0.7), offset = Vector3.new(side * 0.7, 3.5, 2.2), tone = "dark" })
	-- Z is 3.13, NOT 3.05.
	--
	-- The head's front face is at 2.3 + 1.7/2 = 3.15, and a 0.2-deep eye
	-- centred on 3.05 put its own front face at exactly 3.15 too. Two surfaces
	-- at identical depth give the renderer nothing to sort by, so the eyes
	-- flickered through the face per pixel and per camera angle. Centred on
	-- 3.13 they sit 0.08 proud, which also reads better: eyes on a blocky dog
	-- want to bulge slightly rather than be painted on.
	table.insert(SKELETON, {
		name = "Eye", size = Vector3.new(0.3, 0.3, 0.3),
		offset = Vector3.new(side * 0.5, 2.9, 3.13), tone = "eye",
		shape = Enum.PartType.Ball,
	})
	for _, front in ipairs({ 1.2, -1.2 }) do
		table.insert(SKELETON, { name = "Leg", size = Vector3.new(0.7, 1.9, 0.7), offset = Vector3.new(side * 0.7, 0.95, front), tone = "dark" })
	end
end

-- Kennel geometry, relative to the kennel origin. Open at +Z.
local KENNEL: { { name: string, size: Vector3, offset: Vector3, tone: Tone, rot: CFrame? } } = {
	{ name = "Floor", size = Vector3.new(5.4, 0.3, 5.6), offset = Vector3.new(0, 0.15, 0), tone = "wood" },
	{ name = "BackWall", size = Vector3.new(5.4, 4.0, 0.4), offset = Vector3.new(0, 2.0, -2.6), tone = "wood" },
	{ name = "SideWall", size = Vector3.new(0.4, 4.0, 5.6), offset = Vector3.new(-2.5, 2.0, 0), tone = "wood" },
	{ name = "SideWall", size = Vector3.new(0.4, 4.0, 5.6), offset = Vector3.new(2.5, 2.0, 0), tone = "wood" },
	{ name = "Lintel", size = Vector3.new(5.4, 1.0, 0.4), offset = Vector3.new(0, 3.5, 2.6), tone = "wood" },
	{
		name = "Roof", size = Vector3.new(3.3, 0.35, 6.2), offset = Vector3.new(-1.35, 4.45, 0),
		tone = "roof", rot = CFrame.Angles(0, 0, math.rad(28)),
	},
	{
		name = "Roof", size = Vector3.new(3.3, 0.35, 6.2), offset = Vector3.new(1.35, 4.45, 0),
		tone = "roof", rot = CFrame.Angles(0, 0, math.rad(-28)),
	},
}

local EYE_DULL = Color3.fromRGB(24, 20, 18)
local KENNEL_WOOD = Color3.fromRGB(132, 96, 64)

-- ============================================================
-- MOVEMENT
-- ============================================================

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
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		local dt = RunService.Heartbeat:Wait()
		if abort and abort() then
			return false
		end

		local from = dog.body.Position
		local to = Vector3.new(target.X, from.Y, target.Z)
		local delta = to - from
		if delta.Magnitude < 0.6 then
			return true
		end

		-- Face along the travel direction rather than at the target: a step
		-- that landed exactly on the target would make CFrame.lookAt degenerate.
		local heading = delta.Unit
		local moved = from + heading * math.min(speed * dt, delta.Magnitude)
		dog.model:PivotTo(facing(moved, heading))
	end
	return false
end

-- ============================================================
-- OFF DUTY
-- ============================================================

local function sleepCFrame(dog: Dog, scale: number): CFrame
	-- Just inside the doorway, settled onto the floor, still facing out so a
	-- passer-by can see it is asleep rather than missing.
	return dog.originCF * CFrame.new(0, (1.9 - 0.55) * scale, 0.4 * scale)
end

local function settle(dog: Dog, tier: any)
	local mouth = (dog.originCF * CFrame.new(0, 0, 2.4 * tier.scale)).Position
	walkTo(dog, mouth, tier.speed * Config.DOG_PATROL_SPEED * 2.2, 6, function()
		return dog.chasing or dog.level <= 0
	end)
	if dog.chasing or dog.level <= 0 then
		return
	end

	dog.sleeping = true
	dog.model:PivotTo(sleepCFrame(dog, tier.scale))
	dog.zzz.Enabled = true
	dog.breedLabel.Text = "OFF DUTY"
end

local function rouse(dog: Dog, tier: any)
	dog.sleeping = false
	dog.zzz.Enabled = false
	dog.breedLabel.Text = string.upper(tier.breed)

	-- Stand back up at the rest spot. Orientation comes from originCF, so the
	-- dog ends up facing out of its own doorway.
	dog.model:PivotTo(dog.originCF * CFrame.new(REST_OFFSET * tier.scale + Vector3.new(0, 1.9 * tier.scale, 0)))

	local bark = dog.body:FindFirstChild("Bark") :: Sound?
	if bark then
		bark:Play()
	end
end

-- The dog's whole life outside a chase: asleep while on cooldown, wandering
-- while on duty.
local function behaviour(dog: Dog)
	while dog.model.Parent do
		local tier = Config.getDogTier(dog.level)

		if not tier or dog.chasing then
			task.wait(0.4)
		elseif os.clock() < dog.busyUntil then
			if dog.sleeping then
				task.wait(0.4)
			else
				settle(dog, tier)
			end
		else
			if dog.sleeping then
				rouse(dog, tier)
			end

			local low, high = Config.DOG_PATROL_PAUSE[1], Config.DOG_PATROL_PAUSE[2]
			task.wait(low + math.random() * (high - low))

			tier = Config.getDogTier(dog.level)
			if tier and not dog.chasing and os.clock() >= dog.busyUntil then
				local angle = math.random() * math.pi * 2
				local dist = math.random() * Config.DOG_PATROL_RADIUS
				local target = dog.home + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
				walkTo(dog, target, tier.speed * Config.DOG_PATROL_SPEED, 8, function()
					return dog.chasing or dog.level <= 0 or os.clock() < dog.busyUntil
				end)
			end
		end
	end
end

-- ============================================================
-- BUILD AND TIERS
-- ============================================================

local function layout(dog: Dog, scale: number)
	for _, piece in ipairs(dog.kennelPieces) do
		piece.part.Size = piece.size * scale
		piece.part.CFrame = dog.originCF
			* CFrame.new(piece.offset * scale)
			* (piece.rot or CFrame.identity)
	end

	for _, piece in ipairs(dog.pieces) do
		piece.part.Size = piece.size * scale
		piece.part.CFrame = dog.originCF * CFrame.new((REST_OFFSET + piece.offset) * scale)
	end

	dog.home = (dog.originCF * CFrame.new((REST_OFFSET + Vector3.new(0, 1.9, 0)) * scale)).Position
	-- Clear of the ears, which are the tallest thing on the dog. The plate is
	-- not AlwaysOnTop, so anything it overlaps will chew holes in the text.
	dog.plate.StudsOffsetWorldSpace = Vector3.new(0, 2.4 * scale, 0)
end

-- Repaints and resizes the dog and its kennel into the breed for `level`.
-- Level 0 hides both: no dog bought, no kennel on the lawn.
function GuardDog.applyTier(dog: Dog, level: number)
	dog.level = math.clamp(level, 0, #Config.DOG_TIERS)
	local tier = Config.getDogTier(dog.level)

	if not tier then
		for _, piece in ipairs(dog.pieces) do
			piece.part.Transparency = 1
		end
		for _, piece in ipairs(dog.kennelPieces) do
			piece.part.Transparency = 1
		end
		dog.plate.Enabled = false
		dog.zzz.Enabled = false
		return
	end

	layout(dog, tier.scale)

	local all = {}
	for _, p in ipairs(dog.pieces) do table.insert(all, p) end
	for _, p in ipairs(dog.kennelPieces) do table.insert(all, p) end

	for _, piece in ipairs(all) do
		local p = piece.part
		p.Transparency = 0
		if piece.tone == "fur" then
			p.Color, p.Material = tier.fur, Enum.Material.SmoothPlastic
		elseif piece.tone == "dark" then
			p.Color, p.Material = tier.furDark, Enum.Material.SmoothPlastic
		elseif piece.tone == "collar" then
			p.Color, p.Material = tier.collar, Enum.Material.Metal
		elseif piece.tone == "wood" then
			p.Color, p.Material = KENNEL_WOOD, Enum.Material.WoodPlanks
		elseif piece.tone == "roof" then
			-- Kennel roof takes the collar colour, so the kennel reads as
			-- belonging to this breed from as far away as the dog does.
			p.Color, p.Material = tier.collar, Enum.Material.Slate
		else
			-- Only the top breed's eyes light up. The cheapest possible
			-- "this one is different" read from across the plot.
			p.Color = if tier.glow then tier.collar else EYE_DULL
			p.Material = if tier.glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end

	dog.plate.Enabled = true
	dog.nameLabel.Text = tier.name
	dog.nameLabel.TextColor3 = tier.collar
	dog.breedLabel.Text = if dog.sleeping then "OFF DUTY" else string.upper(tier.breed)

	-- A tier change mid-nap has to re-seat the dog, or it snaps to the rest
	-- spot at the new scale while still flagged asleep.
	if dog.sleeping then
		dog.model:PivotTo(sleepCFrame(dog, tier.scale))
	end
end

-- `originCF` places the kennel and decides which way it faces: local +Z is
-- out of the doorway, and the dog rests in front of it.
function GuardDog.build(originCF: CFrame, parent: Instance): Dog
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

	local kennelPieces: { Piece } = {}
	for _, bone in ipairs(KENNEL) do
		local p = makePart(bone, kennelModel)
		p.CastShadow = false
		table.insert(kennelPieces, {
			part = p, size = bone.size, offset = bone.offset, tone = bone.tone, rot = bone.rot,
		})
	end

	local pieces: { Piece } = {}
	local body: Part? = nil
	for _, bone in ipairs(SKELETON) do
		local p = makePart(bone, model)
		table.insert(pieces, { part = p, size = bone.size, offset = bone.offset, tone = bone.tone })
		if not body then
			body = p
		end
	end

	local torso = assert(body, "SKELETON must define at least the torso")

	local bark = Instance.new("Sound")
	bark.Name = "Bark"
	bark.SoundId = Config.SOUNDS.MILESTONE
	bark.Volume = 0.5
	bark.PlaybackSpeed = 1.6
	bark.RollOffMaxDistance = 90
	bark.Parent = torso

	local head = model:FindFirstChild("Head") :: Part

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

	-- Sleep puff over the kennel. Emitted from the roof rather than the dog,
	-- so it stays put and stays visible even though the dog is tucked inside.
	local roof = kennelModel:FindFirstChild("Roof") :: Part
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
	zzz.Parent = roof

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
		home = (originCF * CFrame.new(REST_OFFSET + Vector3.new(0, 1.9, 0))).Position,
		level = 0,
		busyUntil = 0,
		chasing = false,
		sleeping = false,
		plate = plate,
		nameLabel = nameLabel,
		breedLabel = breedLabel,
		zzz = zzz,
	}

	GuardDog.applyTier(dog, 0)
	task.spawn(behaviour, dog)

	return dog
end

-- ============================================================
-- CHASE
-- ============================================================

function GuardDog.isReady(dog: Dog): boolean
	return dog.level > 0 and not dog.chasing and os.clock() >= dog.busyUntil
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

	local bark = dog.body:FindFirstChild("Bark") :: Sound?
	if bark then
		bark:Play()
	end

	task.spawn(function()
		task.wait(Config.DOG_START_DELAY)

		local deadline = os.clock() + tier.maxChase
		local caught = false

		while os.clock() < deadline do
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
			if bark then
				bark:Play()
			end
			onCatch()
		end

		-- Trot home, then go off duty. `behaviour` sees busyUntil and puts it
		-- to bed; the walk to the kennel is its job, not this one's.
		walkTo(dog, dog.home, tier.speed, 8)
		dog.chasing = false
		dog.busyUntil = os.clock() + tier.cooldown
	end)
end

return GuardDog
