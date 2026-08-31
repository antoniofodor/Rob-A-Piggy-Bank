--!strict
--[[
	GuardDog

	The defence tree's payoff: a dog that patrols your plot, chases a thief
	off it, and tags them for you.

	It does not pathfind. A Humanoid with PathfindingService on twelve plots
	would cost far more CPU than this is worth, and a dog that occasionally
	trots through a fence post reads as charming rather than broken -- it's a
	small dog going under things. It just lerps along the ground toward its
	target and gives up after the tier's maxChase.

	Each level is a different breed rather than the same dog with a bigger
	number. The parts are resized and recoloured in place on upgrade, so the
	Dog record stays valid and nothing holding a reference has to care that
	the dog changed underneath it.

	Parts are anchored and moved with Model:PivotTo, which moves every
	descendant -- so there are deliberately no welds here. Welds would only
	have to be torn down and rebuilt every time a tier change resized things.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local GuardDog = {}

-- Which tier colour a part takes. Kept as a tag rather than a stored colour
-- so applyTier can repaint the whole dog without knowing its geometry.
type Tone = "fur" | "dark" | "eye" | "collar"

type Piece = {
	part: Part,
	size: Vector3,   -- at scale 1
	offset: Vector3, -- from the ground point, at scale 1
	tone: Tone,
}

export type Dog = {
	model: Model,
	body: Part,
	pieces: { Piece },
	ground: Vector3, -- where the dog stands, at its feet
	home: Vector3,   -- the torso's resting position; scales with the breed
	level: number,
	busyUntil: number,
	chasing: boolean,
	plate: BillboardGui,
	nameLabel: TextLabel,
	breedLabel: TextLabel,
}

-- Base geometry, all at scale 1. The torso must come first: it becomes the
-- model's PrimaryPart, and therefore its pivot.
local SKELETON: { { name: string, size: Vector3, offset: Vector3, tone: Tone } } = {
	{ name = "Torso", size = Vector3.new(2.2, 1.8, 3.6), offset = Vector3.new(0, 1.9, 0), tone = "fur" },
	{ name = "Head", size = Vector3.new(1.7, 1.6, 1.7), offset = Vector3.new(0, 2.6, 2.3), tone = "fur" },
	{ name = "Snout", size = Vector3.new(0.9, 0.7, 0.9), offset = Vector3.new(0, 2.35, 3.1), tone = "dark" },
	{ name = "Tail", size = Vector3.new(0.5, 0.5, 1.4), offset = Vector3.new(0, 2.5, -2.1), tone = "dark" },
	{ name = "Collar", size = Vector3.new(1.9, 0.6, 0.75), offset = Vector3.new(0, 2.4, 1.85), tone = "collar" },
	{ name = "Tag", size = Vector3.new(0.35, 0.35, 0.16), offset = Vector3.new(0, 2.05, 2.2), tone = "collar" },
}

for _, side in ipairs({ -1, 1 }) do
	table.insert(SKELETON, { name = "Ear", size = Vector3.new(0.5, 1, 0.7), offset = Vector3.new(side * 0.7, 3.5, 2.2), tone = "dark" })
	table.insert(SKELETON, { name = "Eye", size = Vector3.new(0.3, 0.3, 0.2), offset = Vector3.new(side * 0.5, 2.9, 3.05), tone = "eye" })
	for _, front in ipairs({ 1.2, -1.2 }) do
		table.insert(SKELETON, { name = "Leg", size = Vector3.new(0.7, 1.9, 0.7), offset = Vector3.new(side * 0.7, 0.95, front), tone = "dark" })
	end
end

local EYE_DULL = Color3.fromRGB(24, 20, 18)

-- ============================================================
-- MOVEMENT
-- ============================================================

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
		dog.model:PivotTo(CFrame.lookAt(moved, moved + heading))
	end
	return false
end

-- Wanders the plot between chases. A dog frozen at a corner reads as scenery;
-- one that paces reads as on duty, which is most of what the purchase buys.
local function patrol(dog: Dog)
	while dog.model.Parent do
		local tier = Config.getDogTier(dog.level)
		if not tier or dog.chasing then
			task.wait(1)
		else
			local low, high = Config.DOG_PATROL_PAUSE[1], Config.DOG_PATROL_PAUSE[2]
			task.wait(low + math.random() * (high - low))

			tier = Config.getDogTier(dog.level)
			if tier and not dog.chasing then
				local angle = math.random() * math.pi * 2
				local dist = math.random() * Config.DOG_PATROL_RADIUS
				local target = dog.home + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
				walkTo(dog, target, tier.speed * Config.DOG_PATROL_SPEED, 8, function()
					return dog.chasing or dog.level <= 0
				end)
			end
		end
	end
end

-- ============================================================
-- BUILD AND TIERS
-- ============================================================

local function layout(dog: Dog, scale: number)
	for _, piece in ipairs(dog.pieces) do
		piece.part.Size = piece.size * scale
		piece.part.CFrame = CFrame.new(dog.ground + piece.offset * scale)
	end
	dog.home = dog.ground + Vector3.new(0, 1.9 * scale, 0)
	-- Clear of the ears, which are the tallest thing on the dog. The plate is
	-- not AlwaysOnTop, so anything it overlaps will chew holes in the text.
	dog.plate.StudsOffsetWorldSpace = Vector3.new(0, 2.4 * scale, 0)
end

-- Repaints and resizes the dog into the breed for `level`. Level 0 hides it.
function GuardDog.applyTier(dog: Dog, level: number)
	dog.level = math.clamp(level, 0, #Config.DOG_TIERS)
	local tier = Config.getDogTier(dog.level)

	if not tier then
		for _, piece in ipairs(dog.pieces) do
			piece.part.Transparency = 1
		end
		dog.plate.Enabled = false
		return
	end

	layout(dog, tier.scale)

	for _, piece in ipairs(dog.pieces) do
		local p = piece.part
		p.Transparency = 0
		if piece.tone == "fur" then
			p.Color, p.Material = tier.fur, Enum.Material.SmoothPlastic
		elseif piece.tone == "dark" then
			p.Color, p.Material = tier.furDark, Enum.Material.SmoothPlastic
		elseif piece.tone == "collar" then
			p.Color, p.Material = tier.collar, Enum.Material.Metal
		else
			-- Only the top breed's eyes light up. It is the cheapest possible
			-- "this one is different" read from across the plot.
			p.Color = if tier.glow then tier.collar else EYE_DULL
			p.Material = if tier.glow then Enum.Material.Neon else Enum.Material.SmoothPlastic
		end
	end

	dog.plate.Enabled = true
	dog.nameLabel.Text = tier.name
	dog.nameLabel.TextColor3 = tier.collar
	dog.breedLabel.Text = string.upper(tier.breed)
end

function GuardDog.build(ground: Vector3, parent: Instance): Dog
	local model = Instance.new("Model")
	model.Name = "GuardDog"

	local pieces: { Piece } = {}
	local body: Part? = nil

	for _, bone in ipairs(SKELETON) do
		local p = Instance.new("Part")
		p.Name = bone.name
		p.Size = bone.size
		p.CFrame = CFrame.new(ground + bone.offset)
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
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

	model.PrimaryPart = torso
	model.Parent = parent

	local dog: Dog = {
		model = model,
		body = torso,
		pieces = pieces,
		ground = ground,
		home = ground + Vector3.new(0, 1.9, 0),
		level = 0,
		busyUntil = 0,
		chasing = false,
		plate = plate,
		nameLabel = nameLabel,
		breedLabel = breedLabel,
	}

	GuardDog.applyTier(dog, 0)
	task.spawn(patrol, dog)

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
			dog.model:PivotTo(CFrame.lookAt(moved, moved + heading))
		end

		if caught then
			if bark then
				bark:Play()
			end
			onCatch()
		end

		-- Trot home either way, then go back on duty.
		walkTo(dog, dog.home, tier.speed, 8)
		dog.model:PivotTo(CFrame.new(dog.home))
		dog.chasing = false
		dog.busyUntil = os.clock() + tier.cooldown
	end)
end

return GuardDog
