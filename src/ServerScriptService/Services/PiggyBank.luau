--!strict
--[[
	PiggyBank

	Builds the piggy bank that sits on each plot, out of parts, and owns all
	of its feedback -- the coin pile, the glow, the particles and the sounds.

	Part-built rather than a mesh on purpose: it costs nothing, runs on a
	school Chromebook, and I can change the shape in one edit instead of
	round-tripping through Blender.

	The coins are individual discs, not one blob. They're positioned by
	sphere-cap volume so each new coin lands on the current surface of the
	pile, which is what makes it read as filling up rather than inflating.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local PiggyBank = {}

export type Refs = {
	model: Model,
	body: Part,
	pile: Folder,
	coins: { Part },
	shown: number,
	glow: PointLight,
	drip: ParticleEmitter,
	burst: ParticleEmitter,
	aura: ParticleEmitter,
	snout: Part,
	tail: Part,
	ears: { BasePart },
	legs: { Part },
	lock: Model,
	prompt: ProximityPrompt,
	stealPrompt: ProximityPrompt,
	sounds: { [string]: Sound },
}

-- All measurements are relative to the top face of the plot base (y = +0.5).
local BODY_R = 6
local BODY_Y = 8.5

-- Legs are placed by their corner offset and thickness; the length that makes
-- them meet the body is solved for at build time, not written down here.
local LEG_X = 3.1 -- offset from the centre line on both X and Z
local LEG_D = 1.6 -- cylinder diameter

-- The plot base is a slab centred on `origin`, so its walkable top -- and the
-- pig's ground line -- is half a slab above it.
local GROUND_Y = Config.PLOT_SIZE.Y / 2
local COIN_R = 4.3 -- radius of the volume coins may occupy
local COIN_SIZE = 1.6
local COIN_THICK = 0.28

-- The coin volume sits above the body's centre rather than filling it from
-- the very bottom. Players approach from the front, and the snout hides the
-- lower third of the body from exactly that angle -- so a pile that started
-- at the true bottom was invisible until it was already a third full.
-- Raising it costs nothing visually: nobody can see the space it vacated.
local COIN_CENTRE_OFFSET = 1.5

-- Snout sits low, like a real pig's, so it stops covering the pile.
local SNOUT_Y = -2.5
local SNOUT_D = 3.6

local PINK_DARK = Color3.fromRGB(214, 122, 148)
local NEAR_BLACK = Color3.fromRGB(38, 30, 34)
local COIN_GOLD = Color3.fromRGB(238, 194, 72)
local COIN_GOLD_2 = Color3.fromRGB(250, 218, 118)

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local GOLDEN_ANGLE = 2.39996323

local function part(name: string, parent: Instance, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Roblox cylinders have their flat faces on the X axis, so any cylinder that
-- should point some other way needs rotating into place.
local function cylinderUp(pos: Vector3): CFrame
	return CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
end

local function cylinderForward(pos: Vector3): CFrame
	return CFrame.new(pos) * CFrame.Angles(0, math.rad(90), 0)
end

-- ============================================================
-- COIN PILE GEOMETRY
-- ============================================================

-- Height of the spherical cap holding `fraction` of the sphere's volume.
--
-- This is what makes the pile look real. Spacing coins evenly by height would
-- put as many coins in the narrow bottom of the sphere as in the wide middle,
-- so the level would crawl at first and then leap. Spacing them by volume
-- means each coin represents the same amount of money, and the surface rises
-- at the rate a player expects.
local function capHeightForVolume(fraction: number, radius: number): number
	local lo, hi = 0, radius * 2
	for _ = 1, 24 do
		local mid = (lo + hi) / 2
		-- Normalised cap volume: h^2 * (3R - h) / (4R^3)
		local volume = (mid * mid * (3 * radius - mid)) / (4 * radius * radius * radius)
		if volume < fraction then
			lo = mid
		else
			hi = mid
		end
	end
	return (lo + hi) / 2
end

local function buildCoinPile(centre: Vector3, parent: Instance): ({ Part }, Folder)
	local folder = Instance.new("Folder")
	folder.Name = "CoinPile"
	folder.Parent = parent

	-- Seeded so every piggy on every server has the identical pile. A random
	-- scatter per server would mean two players describing the same vault
	-- differently, and would break screenshot comparisons while tuning.
	local rng = Random.new(20260830)
	local coins: { Part } = {}

	for i = 1, Config.COIN_COUNT do
		local fraction = (i - 0.5) / Config.COIN_COUNT
		local height = capHeightForVolume(fraction, COIN_R)
		local y = -COIN_R + height

		-- Radius of the sphere's cross-section at this height, pulled in so
		-- coins never poke through the shell.
		local ring = math.sqrt(math.max(0, COIN_R * COIN_R - y * y)) * 0.74
		local theta = i * GOLDEN_ANGLE
		local dist = ring * math.sqrt(rng:NextNumber(0.05, 1))

		local pos = centre + Vector3.new(math.cos(theta) * dist, y, math.sin(theta) * dist)

		local coin = part("Coin", folder, Vector3.new(COIN_THICK, COIN_SIZE, COIN_SIZE),
			CFrame.new(pos)
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
				* CFrame.Angles(0, 0, math.rad(90))
				* CFrame.Angles(math.rad(rng:NextNumber(-22, 22)), 0, math.rad(rng:NextNumber(-22, 22))))
		coin.Shape = Enum.PartType.Cylinder
		coin.Material = Enum.Material.Metal
		coin.Color = if i % 3 == 0 then COIN_GOLD_2 else COIN_GOLD
		coin.Transparency = 1 -- hidden until the vault reaches it
		coin.CastShadow = false

		table.insert(coins, coin)
	end

	return coins, folder
end

-- ============================================================
-- BUILD
-- ============================================================

function PiggyBank.build(origin: Vector3, parent: Instance): Refs
	local model = Instance.new("Model")
	model.Name = "PiggyBank"

	local function at(x: number, y: number, z: number): Vector3
		return origin + Vector3.new(x, y, z)
	end

	local centre = at(0, BODY_Y, 0)

	-- Body ------------------------------------------------------------
	local body = part("Body", model, Vector3.new(BODY_R * 2, BODY_R * 2, BODY_R * 2), CFrame.new(centre))
	body.Shape = Enum.PartType.Ball
	body.CanCollide = true
	body.CanQuery = true

	local coins, pile = buildCoinPile(centre + Vector3.new(0, COIN_CENTRE_OFFSET, 0), model)

	-- Lights the pile from inside so it reads through a body that's only
	-- slightly transparent. Brightness tracks the fill, so a rich piggy
	-- visibly glows from across the map.
	local glow = Instance.new("PointLight")
	glow.Name = "Glow"
	glow.Color = COIN_GOLD
	glow.Brightness = 0
	glow.Range = 8
	glow.Shadows = false
	glow.Parent = body

	-- Particles -------------------------------------------------------
	-- Ambient trickle at the coin slot: the visual for "you are earning".
	local drip = Instance.new("ParticleEmitter")
	drip.Name = "Drip"
	drip.Texture = SPARKLE
	drip.Color = ColorSequence.new(COIN_GOLD_2, COIN_GOLD)
	drip.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	drip.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	drip.Lifetime = NumberRange.new(0.5, 0.9)
	drip.Rate = 3
	drip.Speed = NumberRange.new(1.5, 3)
	drip.SpreadAngle = Vector2.new(18, 18)
	drip.Acceleration = Vector3.new(0, -6, 0)
	drip.LightEmission = 0.6
	drip.Parent = body

	-- Cosmetic aura, driven entirely by the equipped effect. Off by default.
	--
	-- Emitted from the SURFACE of the body sphere, outward, so every cosmetic
	-- reads as a halo wrapping the piggy. The coin drip and milestone burst
	-- both emit from inside the same part -- with only three built-in particle
	-- textures to go around, emission shape is what keeps a paid effect from
	-- looking like the free coin feedback.
	local aura = Instance.new("ParticleEmitter")
	aura.Name = "Aura"
	aura.Enabled = false
	aura.Shape = Enum.ParticleEmitterShape.Sphere
	aura.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	aura.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	aura.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	aura.LightEmission = 0.55
	aura.Parent = body

	-- Fired in bursts on milestones and banking.
	local burst = Instance.new("ParticleEmitter")
	burst.Name = "Burst"
	burst.Texture = SPARKLE
	burst.Color = ColorSequence.new(COIN_GOLD_2, COIN_GOLD)
	burst.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	burst.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	burst.Lifetime = NumberRange.new(0.6, 1.2)
	burst.Rate = 0
	burst.Speed = NumberRange.new(9, 18)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Acceleration = Vector3.new(0, -22, 0)
	burst.LightEmission = 0.8
	burst.Enabled = false
	burst.Parent = body

	-- Sounds ----------------------------------------------------------
	-- Parented to the body so they're positional. Neighbours hearing your
	-- piggy chime is deliberate: in phase 3 it tells a thief where the
	-- money is, which turns feedback into information.
	local sounds: { [string]: Sound } = {}
	local function addSound(key: string, id: string, volume: number, distance: number)
		local sound = Instance.new("Sound")
		sound.Name = key
		sound.SoundId = id
		sound.Volume = volume
		sound.RollOffMaxDistance = distance
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.Parent = body
		sounds[key] = sound
	end
	addSound("drop", Config.SOUNDS.COIN_DROP, 0.35, 45)
	addSound("milestone", Config.SOUNDS.MILESTONE, 0.5, 80)
	addSound("bank", Config.SOUNDS.BANK, 0.6, 70)
	addSound("alarm", Config.SOUNDS.ALARM, 0.7, 140)

	-- Snout -----------------------------------------------------------
	local snout = part("Snout", model, Vector3.new(2, SNOUT_D, SNOUT_D), cylinderForward(at(0, BODY_Y + SNOUT_Y, BODY_R - 0.4)))
	snout.Shape = Enum.PartType.Cylinder
	snout.Color = PINK_DARK

	for _, offset in ipairs({ -1, 1 }) do
		local nostril = part("Nostril", model, Vector3.new(0.5, 0.95, 0.4), CFrame.new(at(offset * 0.8, BODY_Y + SNOUT_Y, BODY_R + 0.7)))
		nostril.Color = NEAR_BLACK
		nostril.Material = Enum.Material.SmoothPlastic
	end

	-- Face ------------------------------------------------------------
	for _, offset in ipairs({ -1, 1 }) do
		local eye = part("Eye", model, Vector3.new(1.25, 1.25, 1.25), CFrame.new(at(offset * 2.35, BODY_Y + 2.1, BODY_R - 1.1)))
		eye.Shape = Enum.PartType.Ball
		eye.Color = NEAR_BLACK
		eye.Material = Enum.Material.SmoothPlastic
	end

	-- Ears are wedges, not blocks. A wedge's triangular faces sit on its X
	-- sides, so rotating 90 degrees about Y turns them to face the camera and
	-- gives the pointed silhouette that reads as "pig" at a distance.
	local ears: { BasePart } = {}
	for _, offset in ipairs({ -1, 1 }) do
		local ear = Instance.new("WedgePart")
		ear.Name = "Ear"
		ear.Size = Vector3.new(0.9, 2.9, 2.5)
		ear.CFrame = CFrame.new(at(offset * 3.2, BODY_Y + 5.1, 1.9))
			* CFrame.Angles(0, math.rad(90), math.rad(offset * 14))
		ear.Anchored = true
		ear.CanCollide = false
		ear.CanQuery = false
		ear.Color = PINK_DARK
		ear.Parent = model
		table.insert(ears, ear)
	end

	-- Legs ------------------------------------------------------------
	--
	-- Length is derived from the body sphere, never hard-coded. The body is a
	-- ball, so its underside climbs steeply away from the centre line: at the
	-- legs' corner offset it sits about 1.9 studs higher than at the middle.
	-- A fixed 2.5-stud leg therefore stopped 1.4 studs short of the body and
	-- every foot hung in mid-air.
	--
	-- `legReach` measures to the leg's OUTER edge rather than its axis, so the
	-- whole top face is buried in the body and no seam opens up when you walk
	-- around the plot. Any future change to BODY_R, BODY_Y or LEG_X now
	-- re-solves this instead of silently detaching the legs again.
	local legs: { Part } = {}
	local legReach = math.sqrt(LEG_X * LEG_X * 2) + LEG_D / 2
	-- The +0.25 buries the top slightly rather than leaving it exactly tangent
	-- to the sphere, so rounding can't open a hairline gap at the outer edge.
	local legTop = BODY_Y - math.sqrt(math.max(BODY_R * BODY_R - legReach * legReach, 0)) + 0.25
	local legHeight = legTop - GROUND_Y

	for _, x in ipairs({ -LEG_X, LEG_X }) do
		for _, z in ipairs({ -LEG_X, LEG_X }) do
			-- Narrow, or a cylinder this short just reads as a cube.
			local leg = part("Leg", model, Vector3.new(legHeight, LEG_D, LEG_D),
				cylinderUp(at(x, GROUND_Y + legHeight / 2, z)))
			leg.Shape = Enum.PartType.Cylinder
			leg.Color = PINK_DARK
			table.insert(legs, leg)
		end
	end

	-- Tail ------------------------------------------------------------
	local tail = part("Tail", model, Vector3.new(1.7, 1.7, 1.7), CFrame.new(at(0, BODY_Y + 1.2, -BODY_R - 0.4)))
	tail.Shape = Enum.PartType.Ball
	tail.Color = PINK_DARK

	-- Coin slot -------------------------------------------------------
	local slot = part("Slot", model, Vector3.new(0.7, 0.45, 4.2), CFrame.new(at(0, BODY_Y + BODY_R - 0.3, 0)))
	slot.Color = NEAR_BLACK
	slot.Material = Enum.Material.SmoothPlastic

	-- Padlock, sitting on the coin slot -------------------------------
	--
	-- The lock upgrade already worked -- it triples the crack time -- but a
	-- ProximityPrompt draws the same filling circle whether it takes three
	-- seconds or nine, so nothing about it was visible. A defender could not
	-- see what they had bought and a thief could not see what they were up
	-- against. This is that mechanic given a body.
	local lock = Instance.new("Model")
	lock.Name = "Padlock"

	local lockBody = part("LockBody", lock, Vector3.new(2.2, 2.4, 1.1),
		CFrame.new(at(0, BODY_Y + BODY_R + 0.7, 0)))
	lockBody.Material = Enum.Material.Metal

	local shackle = part("Shackle", lock, Vector3.new(1.5, 1.5, 0.55),
		CFrame.new(at(0, BODY_Y + BODY_R + 2.2, 0)))
	shackle.Shape = Enum.PartType.Cylinder
	shackle.CFrame = CFrame.new(shackle.Position) * CFrame.Angles(0, math.rad(90), 0)
	shackle.Material = Enum.Material.Metal

	local keyhole = part("Keyhole", lock, Vector3.new(0.5, 0.5, 0.2),
		CFrame.new(at(0, BODY_Y + BODY_R + 0.5, 0.6)))
	keyhole.Color = NEAR_BLACK

	lock.PrimaryPart = lockBody
	lock.Parent = model

	-- Interaction -----------------------------------------------------
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CollectPrompt"
	prompt.ActionText = "Bank Coins"
	prompt.ObjectText = "Your Piggy Bank"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	-- Both prompts exist on every piggy; the client enables whichever one
	-- applies to the viewer. The server never trusts that choice -- it
	-- re-checks ownership on every trigger.
	local stealPrompt = Instance.new("ProximityPrompt")
	stealPrompt.Name = "StealPrompt"
	stealPrompt.ActionText = "Steal Coins"
	stealPrompt.ObjectText = "Piggy Bank"
	stealPrompt.HoldDuration = Config.STEAL_HOLD
	stealPrompt.MaxActivationDistance = Config.STEAL_RANGE
	stealPrompt.RequiresLineOfSight = false
	stealPrompt.Enabled = false
	stealPrompt.Parent = body

	model.PrimaryPart = body
	model.Parent = parent

	local refs: Refs = {
		model = model,
		body = body,
		pile = pile,
		coins = coins,
		shown = 0,
		glow = glow,
		drip = drip,
		burst = burst,
		aura = aura,
		snout = snout,
		tail = tail,
		ears = ears,
		legs = legs,
		lock = lock,
		prompt = prompt,
		stealPrompt = stealPrompt,
		sounds = sounds,
	}

	PiggyBank.applySkin(refs, Config.DEFAULT_SKIN)
	PiggyBank.applyEffect(refs, Config.DEFAULT_EFFECT)
	return refs
end

-- ============================================================
-- APPEARANCE
-- ============================================================

-- The equipped skin owns the piggy's whole appearance. Rebirth-earned looks
-- are just skins with an unlockRebirths instead of a price, so there's one
-- system here rather than a tier system fighting a cosmetic one.
function PiggyBank.applySkin(refs: Refs, skinKey: string)
	local tier = Config.getSkin(skinKey)

	refs.body.Color = tier.body
	refs.body.Material = tier.material
	refs.body.Transparency = tier.transparency

	local trimParts: { BasePart } = { refs.snout, refs.tail }
	for _, ear in ipairs(refs.ears) do
		table.insert(trimParts, ear)
	end
	for _, leg in ipairs(refs.legs) do
		table.insert(trimParts, leg)
	end

	for _, p in ipairs(trimParts) do
		p.Color = tier.trim
		p.Material = tier.material
	end
end

-- Cosmetic particle aura around the piggy. Reuses one emitter rather than
-- creating and destroying instances every time someone changes their mind
-- in the shop.
function PiggyBank.applyEffect(refs: Refs, effectKey: string)
	local effect = Config.getEffect(effectKey)
	local aura = refs.aura

	if not effect.texture then
		aura.Enabled = false
		return
	end

	aura.Texture = effect.texture
	aura.Color = effect.color
	aura.Rate = effect.rate
	aura.Speed = effect.speed
	aura.Lifetime = effect.lifetime
	aura.Drag = effect.drag
	aura.Acceleration = effect.accel
	aura.SpreadAngle = Vector2.new(effect.spread, effect.spread)
	aura.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, effect.size),
		NumberSequenceKeypoint.new(1, 0),
	})

	-- Tumble. The coin particles never rotate, so any spin at all reads as
	-- "this is the other thing" before you've registered the colour.
	local spin = effect.rotSpeed or 0
	aura.Rotation = NumberRange.new(0, 360)
	aura.RotSpeed = NumberRange.new(-spin, spin)

	aura.Enabled = true
end

-- ============================================================
-- FILL
-- ============================================================

-- Reveals coins up to the current fill and returns how many newly appeared,
-- so the caller can decide whether that's worth a sound.
--
-- Only the coins that actually changed state get touched. Rewriting all 32
-- transparencies every tick would push pointless replication traffic for
-- twelve piggies, every second, forever.
function PiggyBank.setFill(refs: Refs, vault: number, capacity: number): number
	local ratio = 0
	if vault > 0 and capacity > 0 then
		ratio = math.clamp(vault / capacity, 0, 1)
	end

	local target = math.floor(ratio * Config.COIN_COUNT + 0.0001)
	local previous = refs.shown

	if target > previous then
		for i = previous + 1, target do
			refs.coins[i].Transparency = 0
		end
	elseif target < previous then
		for i = target + 1, previous do
			refs.coins[i].Transparency = 1
		end
	end
	refs.shown = target

	refs.glow.Brightness = 0.4 + ratio * 2.6
	refs.glow.Range = 7 + ratio * 11
	refs.drip.Rate = if ratio >= 1 then 0 else 2 + ratio * 5

	return math.max(0, target - previous)
end

-- ============================================================
-- FEEDBACK
-- ============================================================

-- A coin just landed on the pile. Quiet on purpose -- at roughly one every
-- fifteen seconds this is a heartbeat, and anything louder becomes nagging.
function PiggyBank.playCoinDrop(refs: Refs)
	local sound = refs.sounds.drop
	if sound then
		sound.PlaybackSpeed = 0.94 + math.random() * 0.12
		sound:Play()
	end
	refs.burst:Emit(6)
end

-- `index` is which milestone (1-based), `total` how many there are, so the
-- pitch climbs as the vault fills and the last one lands highest.
function PiggyBank.playMilestone(refs: Refs, index: number, total: number)
	local sound = refs.sounds.milestone
	if sound then
		sound.PlaybackSpeed = 0.88 + (index / math.max(total, 1)) * 0.5
		sound:Play()
	end
	refs.burst:Emit(if index >= total then 70 else 26)

	-- A small squash-and-stretch on the body. Cheap, and it makes the piggy
	-- feel like an object reacting rather than a static prop.
	local base = Vector3.new(BODY_R * 2, BODY_R * 2, BODY_R * 2)
	local squash = base * (if index >= total then 1.16 else 1.08)
	refs.body.Size = squash
	TweenService:Create(
		refs.body,
		TweenInfo.new(0.45, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
		{ Size = base }
	):Play()
end

-- Someone is robbing this piggy. Loud and long-range on purpose: the alarm
-- is how the owner and every bystander find out in time to do something.
function PiggyBank.playAlarm(refs: Refs)
	local sound = refs.sounds.alarm
	if sound then
		sound:Play()
	end
	refs.burst:Emit(30)
end

function PiggyBank.playBank(refs: Refs)
	local sound = refs.sounds.bank
	if sound then
		sound:Play()
	end
	refs.burst:Emit(40)
end

-- Standing just in front of the snout, facing the piggy.
-- A pocket-sized piggy for a thief to run off with.
--
-- Wears the VICTIM's skin, which is the whole point: the loot has to be
-- recognisably somebody's property, not a generic bag of money. Someone
-- across the street should be able to look at a fleeing player and know
-- whose piggy that is.
--
-- Unanchored, massless and non-colliding, because it gets welded to a
-- character: mass would change how the thief moves, and collision would
-- catch on doorways and fences.
function PiggyBank.buildMini(skinKey: string): Model
	local skin = Config.getSkin(skinKey)
	local model = Instance.new("Model")
	model.Name = "StolenPiggy"

	local function piece(name: string, size: Vector3, cf: CFrame, color: Color3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		p.CastShadow = false
		p.Color = color
		-- Solid, unlike the plot piggy. That one is translucent so the coin
		-- pile shows through; this one has no pile and just needs to read.
		p.Material = skin.material
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	local body = piece("Body", Vector3.new(2.2, 2.2, 2.2), CFrame.new(0, 1.15, 0), skin.body)
	body.Shape = Enum.PartType.Ball

	local snout = piece("Snout", Vector3.new(0.5, 0.85, 0.85),
		CFrame.new(0, 0.9, 1.05) * CFrame.Angles(0, math.rad(90), 0), skin.trim)
	snout.Shape = Enum.PartType.Cylinder

	local tail = piece("Tail", Vector3.new(0.45, 0.45, 0.45), CFrame.new(0, 1.4, -1.1), skin.trim)
	tail.Shape = Enum.PartType.Ball

	for _, side in ipairs({ -1, 1 }) do
		piece("Ear", Vector3.new(0.26, 0.5, 0.2), CFrame.new(side * 0.45, 2.0, 0.5), skin.trim)
		piece("Eye", Vector3.new(0.16, 0.16, 0.1), CFrame.new(side * 0.36, 1.45, 1.0), NEAR_BLACK)
		for _, front in ipairs({ 0.55, -0.55 }) do
			local leg = piece("Leg", Vector3.new(0.75, 0.34, 0.34),
				CFrame.new(side * 0.5, 0.375, front) * CFrame.Angles(0, 0, math.rad(90)), skin.trim)
			leg.Shape = Enum.PartType.Cylinder
		end
	end

	-- Welds rather than anchoring: the whole model rides on the thief, so it
	-- has to move as one piece without being pinned to the world.
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") and child ~= body then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = child
			weld.Parent = child
		end
	end

	model.PrimaryPart = body
	return model
end

-- Padlock appearance per lock level. Level 0 hides it entirely: an unlocked
-- piggy should look unlocked.
--
-- The metal is the tell. A thief reads the colour from outside the fence and
-- knows roughly how long they are committing to standing there.
local LOCK_TIERS = {
	{ colour = Color3.fromRGB(122, 128, 138), scale = 1.00 },  -- iron
	{ colour = Color3.fromRGB(176, 122, 66), scale = 1.10 },   -- bronze
	{ colour = Color3.fromRGB(198, 204, 214), scale = 1.20 },  -- steel
	{ colour = Color3.fromRGB(240, 198, 76), scale = 1.32 },   -- gold
}

function PiggyBank.setLockLevel(refs: Refs, level: number)
	local visible = level > 0
	for _, piece in ipairs(refs.lock:GetChildren()) do
		if piece:IsA("BasePart") then
			piece.Transparency = if visible then 0 else 1
		end
	end
	if not visible then
		return
	end

	local tier = LOCK_TIERS[math.clamp(level, 1, #LOCK_TIERS)]
	for _, piece in ipairs(refs.lock:GetChildren()) do
		if piece:IsA("BasePart") and piece.Name ~= "Keyhole" then
			piece.Color = tier.colour
		end
	end
	refs.lock:ScaleTo(tier.scale)
end

-- A shudder and a spark when a thief is working on the lock, so both sides
-- can see it happening rather than watching a silent progress ring.
function PiggyBank.rattleLock(refs: Refs)
	local body = refs.lock.PrimaryPart
	if not body or body.Transparency >= 1 then
		return
	end
	local origin = body.CFrame
	task.spawn(function()
		for _ = 1, 6 do
			body.CFrame = origin * CFrame.Angles(0, 0, math.rad(math.random(-9, 9)))
			task.wait(0.06)
		end
		body.CFrame = origin
	end)
end

-- Takes the plot's CFrame, not its position: a spawn point has to land in
-- front of the piggy on both rows, and the far row's "front" is -Z in world.
function PiggyBank.getViewCFrame(originCF: CFrame): CFrame
	local standing = (originCF * CFrame.new(0, 3.5, BODY_R + 11)).Position
	local looking = (originCF * CFrame.new(0, BODY_Y, 0)).Position
	return CFrame.lookAt(standing, looking)
end

return PiggyBank
