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
local PiggyModel = require(ReplicatedStorage.Shared.PiggyModel)
local PigGear = require(ReplicatedStorage.Shared.PigGear)

local PiggyBank = {}

export type Refs = {
	model: Model,
	-- The pig's own origin, kept because accessories are attached long after
	-- build() has returned and every anchor in Config is relative to it.
	origin: Vector3,
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

-- Where the vault dial sits on the body, and how big it can get.
--
-- A quarter turn round from the face, and a stud below the equator. Every
-- other candidate is already taken or already blocked: the top of the body is
-- the hat anchor, the front is the snout and the eyes, the back is the cape
-- and jetpack anchor plus the tail, and the underside is the four legs. This
-- patch of flank is the only surface on the pig that is both empty and turned
-- towards someone walking in from the street.
--
-- DIAL_MAX_R is the largest tier's plate. It is the number the clearances
-- were measured against: at 1.95 the plate's top edge reaches y 9.42 against
-- an eyeball that starts at 9.98, its bottom reaches 5.58 against legs that
-- top out at 4.65, and its inner edge comes no closer than x 2.81 to a snout
-- that ends at 1.8. Growing it past 1.95 breaks the first of those.
-- ON THE BACK, BELOW THE TAIL, and it is a vault DOOR rather than a dial on a
-- flank. The flank versions -- 45 degrees, then 72 -- both read as something
-- bolted to the side of an animal. A hatch in the back of a piggy bank is a
-- thing that already exists in the world, which is why it looks right.
--
-- MEASURED AGAINST WHAT IS ALREADY BACK THERE. The tail is a ball spanning
-- local y 0.35 to 2.05 and the legs top out at local y -4.59, so the window
-- below the tail and above the legs is about five studs tall. At local y
-- -1.9 the largest plate spans -3.85 to 0.05: clear of the tail by 0.30 and
-- of the legs by 0.74.
--
-- IT IS BEHIND THE CAPE, AND THAT IS ACCEPTED RATHER THAN MISSED. The back
-- accessory anchor is right above this and a Hero Cape hangs down to local
-- y -1.77, so a caped piggy hides roughly the top half of its own vault.
-- That is the reverse of the padlock bug this file already records: there,
-- the GAME's part swallowed the PLAYER's hat and ruined something they had
-- rolled for. Here the player's own cape covers the game's tell, on a piggy
-- they chose to put a cape on -- their purchase is intact, and what they lose
-- is advertising their own lock to thieves.
--
-- The cost is real and worth stating: a thief walking up from the street sees
-- the face, not the back, so the metal tier no longer carries from out there.
-- What it buys is that an UNLOCKED vault is now a visible hole, which is the
-- signal that actually changes a thief's mind at the gate.
local DIAL_YAW = math.rad(180)
local DIAL_Y = 6.6
local DIAL_MAX_R = 1.95
-- Thick enough that the rim, which sinks 0.32 into the curve of the body at
-- full size, still has its back face buried rather than floating clear.
local DIAL_THICK = 0.9
-- Segments in the vault's rim. Twelve is enough for a four-stud opening to
-- read as round; the cost is twelve parts per piggy, and there are twelve.
local RIM_SEGMENTS = 12

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

-- The frame the whole vault dial is built in, given a piggy's origin.
--
-- Its X axis points straight out of the body, which is what both a Roblox
-- cylinder and the spin in rattleLock want: the plate, face and hub are
-- cylinders along that axis, and turning the wheel is a rotation about it.
-- Y stays as upright as the tilt allows, so the spokes read level.
--
-- CFrame.lookAt aims LookVector, which is -Z, so the extra quarter turn about
-- Y is what swings that onto +X. Without it the dial lies flat against the
-- flank like a sticker.
local function dialCFrame(origin: Vector3): CFrame
	local centre = origin + Vector3.new(0, BODY_Y, 0)
	local drop = DIAL_Y - BODY_Y
	local ring = math.sqrt(math.max(BODY_R * BODY_R - drop * drop, 0))
	local normal = Vector3.new(math.sin(DIAL_YAW) * ring, drop, math.cos(DIAL_YAW) * ring).Unit
	local seat = centre + normal * BODY_R
	return CFrame.lookAt(seat, seat + normal) * CFrame.Angles(0, math.rad(90), 0)
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

	-- Separate from `Glow`, which EconomyService drives to show vault fill.
	-- Sharing one light would make a full vault and a lit effect fight over
	-- the same property every frame.
	local auraLight = Instance.new("PointLight")
	auraLight.Name = "AuraLight"
	auraLight.Enabled = false
	auraLight.Shadows = false
	auraLight.Parent = body

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

	-- Vault dial ------------------------------------------------------
	--
	-- The lock upgrade already worked -- it triples the crack time -- but a
	-- ProximityPrompt draws the same filling circle whether it takes three
	-- seconds or nine, so nothing about it was visible. A defender could not
	-- see what they had bought and a thief could not see what they were up
	-- against. This is that mechanic given a body.
	--
	-- It used to be a padlock on top of the coin slot, and that was wrong
	-- twice over. It sat at (0, 15.2, 0) -- which is the HAT ANCHOR, so every
	-- hat in the game spawned inside it -- and its shackle was a cylinder
	-- written Vector3.new(1.5, 1.5, 0.55), a 1.5-long rod turned to point at
	-- the camera rather than a U over the body, so the one cue that says
	-- "padlock" was never actually built. It read as a grey lump.
	--
	-- A safe dial says the same thing without needing to be identified, and
	-- the body has room for it where the head does not.
	local lock = Instance.new("Model")
	lock.Name = "VaultLock"

	-- The plate is the mount, and it never moves: every other piece of the
	-- dial is positioned from its CFrame, and the spin in rattleLock turns
	-- about its X axis. Size and colour change with the tier; the CFrame does
	-- not, which is what lets the wheel be rebuilt without recomputing where
	-- the dial lives.
	-- THE HOLE IS ALWAYS THERE; THE LOCK IS WHAT COVERS IT.
	--
	-- Nothing in this world can be DUG -- a Part cannot cut a hole in another
	-- Part -- so the opening is the same illusion the moat uses: a near-black
	-- disc with a rim standing proud of it, because the eye takes the highest
	-- line as the surface and reads everything inside it as depth. Set flush
	-- instead, it is a black sticker.
	--
	-- Built once at full size and never resized, so an unlocked piggy and a
	-- gold-locked one have the same opening and only the door changes.
	local seat = dialCFrame(origin)

	local hole = part("VaultHole", lock, Vector3.new(0.30, DIAL_MAX_R * 2, DIAL_MAX_R * 2),
		seat * CFrame.new(0.02, 0, 0))
	hole.Shape = Enum.PartType.Cylinder
	hole.Color = Color3.fromRGB(18, 14, 16)
	hole.Material = Enum.Material.SmoothPlastic

	-- THE RIM IS A RING OF SEGMENTS, because one cylinder cannot be an annulus
	-- and a solid disc in front of the hole simply covers it -- which is what
	-- the first build did, hiding the whole opening behind a pale lid.
	--
	-- It stands PROUD of the dark disc, which is the entire illusion: nothing
	-- in this world can be dug, so a recess is made by putting a lip AROUND
	-- the dark rather than sinking the dark, and the eye takes the highest
	-- line as the surface. Exactly the moat's kerbs, at a twentieth of the
	-- scale.
	for i = 0, RIM_SEGMENTS - 1 do
		local a = (i / RIM_SEGMENTS) * math.pi * 2
		local r = DIAL_MAX_R + 0.16
		-- ROTATED TO LIE TANGENT, not radial. A segment sits at
		-- (sin a, cos a) * r in the seat's YZ plane, so its radius direction
		-- is that vector and its TANGENT is (cos a, -sin a). Turning by -a
		-- maps the segment's long axis onto the radius instead, which builds
		-- a sunburst of spikes rather than a ring -- measured by looking at
		-- twelve of them sticking straight out of the pig.
		local seg = part("VaultRim", lock,
			Vector3.new(0.42, 0.30, (2 * math.pi * r) / RIM_SEGMENTS + 0.10),
			seat * CFrame.new(0.16, math.sin(a) * r, math.cos(a) * r)
				* CFrame.Angles(-a - math.pi / 2, 0, 0))
		seg.Color = PINK_DARK
		seg.Material = Enum.Material.SmoothPlastic
	end

	local plate = part("DialPlate", lock, Vector3.new(DIAL_THICK, DIAL_MAX_R * 2, DIAL_MAX_R * 2),
		seat)
	plate.Shape = Enum.PartType.Cylinder
	plate.Material = Enum.Material.Metal
	plate.Transparency = 1 -- setLockLevel owns whether it shows

	lock.PrimaryPart = plate
	lock.Parent = model

	-- Interaction -----------------------------------------------------
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CollectPrompt"
	prompt.ActionText = "Bank Coins"
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt:SetAttribute(Config.PROMPT_KIND_ATTRIBUTE, "collect")
	prompt.ObjectText = "Your Piggy Bank"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.COLLECT_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Parent = body

	-- Both prompts exist on every piggy; the client enables whichever one
	-- applies to the viewer. The server never trusts that choice -- it
	-- re-checks ownership on every trigger.
	local stealPrompt = Instance.new("ProximityPrompt")
	stealPrompt.Name = "StealPrompt"
	stealPrompt.ActionText = "Steal Coins"
	stealPrompt.Style = Enum.ProximityPromptStyle.Custom
	stealPrompt:SetAttribute(Config.PROMPT_KIND_ATTRIBUTE, "steal")
	stealPrompt.ObjectText = "Piggy Bank"
	stealPrompt.HoldDuration = Config.STEAL_HOLD
	stealPrompt.MaxActivationDistance = Config.STEAL_RANGE
	stealPrompt.RequiresLineOfSight = false
	stealPrompt.Enabled = false
	stealPrompt.Parent = body

	model.PrimaryPart = body
	model.Parent = parent

	local refs: Refs = {
		origin = origin,
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

	-- MARKINGS, and they are the third channel of a skin rather than a fourth
	-- system. Built by PiggyModel because the shop tile and the carried loot
	-- render the same piggy from the same builder -- see the block at the top
	-- of that file. Torn down and rebuilt on every call, so switching skins
	-- cannot accumulate stripes.
	--
	-- SEATED ON THE BODY PART'S OWN CFRAME, never on `refs.origin`. The far
	-- row of plots is turned half round by one PivotTo after everything on it
	-- is built, so the origin captured at build time points the wrong way for
	-- six of the twelve piggies; the body's frame carries the turn with it and
	-- a stripe stays across the spine on both rows.
	PiggyModel.applyPattern(refs.model, tier, {
		frame = refs.body.CFrame,
		radius = BODY_R,
		anchored = true,
		weldTo = nil,
		material = tier.material,
		transparency = tier.transparency,
	})

	-- The colours above are the STATIC baseline, which is what a client sees
	-- before its animator starts and what it falls back to if the skin has no
	-- animation. The key is published as an attribute so every client can drive
	-- the animation locally: animating server-side would replicate a colour
	-- write per piggy per frame for something each machine can compute alone.
	--
	-- The client animator drives the Body and the four trim names and nothing
	-- else, so a pattern on an animated skin holds its own colour while the
	-- body cycles underneath it. That is the intended read -- a marking on a
	-- glowing pig -- which is why every neon pattern in Config is authored
	-- either near-black or near-white: a mid-tone trace would vanish for the
	-- part of the cycle the body happened to pass through it.
	refs.model:SetAttribute("SkinKey", skinKey)
end

-- Puts the worn accessories on the pig.
--
-- Torn down and rebuilt on every change rather than diffed. A player changes
-- hats a handful of times in a session, each item is a dozen anchored parts,
-- and a diff would have to track which model came from which slot in order to
-- save work nobody can measure -- while being the kind of bookkeeping that
-- quietly leaks a hat when two changes land in the same frame.
function PiggyBank.applyAccessories(refs: Refs, worn: { [string]: string })
	local existing = refs.model:FindFirstChild("Gear")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "Gear"
	folder.Parent = refs.model

	for slotKey, slot in pairs(Config.ACCESSORY_SLOTS) do
		local key = worn[slotKey]
		local spec = key and Config.ACCESSORIES[key]
		-- An item is only worn if it still belongs to the slot claiming it.
		-- Moving an accessory between slots in Config would otherwise leave
		-- saved players wearing a hat on their feet.
		if spec and spec.slot == slotKey then
			-- The slot anchor is the shared attachment point; `offset` is each
			-- item's own nudge off it. One anchor cannot suit a cape that hugs
			-- the back and a jetpack that stands off it.
			local offset = spec.offset or Vector3.zero
			for _, anchor in ipairs(slot.anchors) do
				local model = PigGear.build(key)
				model.Parent = folder
				model:PivotTo(CFrame.new(refs.origin + anchor + offset))
			end
		end
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
		local off = refs.body:FindFirstChild("AuraLight") :: PointLight?
		if off then
			off.Enabled = false
		end
		refs.model:SetAttribute("LightKind", nil)
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

	-- The top two effects throw light. Base brightness is set here; the
	-- flicker is a client concern, driven off the LightKind attribute below.
	local auraLight = refs.body:FindFirstChild("AuraLight") :: PointLight?
	if auraLight then
		if effect.light then
			auraLight.Color = effect.light.colour
			auraLight.Brightness = effect.light.brightness
			auraLight.Range = effect.light.range
			auraLight.Enabled = true
			refs.model:SetAttribute("LightKind", effect.light.kind)
		else
			auraLight.Enabled = false
			refs.model:SetAttribute("LightKind", nil)
		end
	end
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
-- Delegated to Shared/PiggyModel, which the shop also renders. See the note
-- at the top of that file: the carried loot and the shop tile must be the
-- same piggy, or a skin can look like one thing in the catalogue and another
-- on somebody's back.
function PiggyBank.buildMini(skinKey: string): Model
	return PiggyModel.build(skinKey)
end

-- Vault dial appearance per lock level. Level 0 hides it entirely: an
-- unlocked piggy should look unlocked.
--
-- Two things ramp, and they are readable at different distances. The metal
-- carries from outside the fence, where a thief decides whether to come in at
-- all; the spoke count only resolves up close, where they are already
-- deciding whether to commit to the hold. A 2-spoke wheel is a bar handle and
-- a 5-spoke one is a bank vault, so nobody has to actually count them to see
-- which is the bigger job.
local LOCK_TIERS = {
	{ metal = Color3.fromRGB(122, 128, 138), radius = 1.55, spokes = 2 }, -- iron
	{ metal = Color3.fromRGB(176, 122, 66), radius = 1.68, spokes = 3 },  -- bronze
	{ metal = Color3.fromRGB(198, 204, 214), radius = 1.82, spokes = 4 }, -- steel
	{ metal = Color3.fromRGB(240, 198, 76), radius = 1.95, spokes = 5 },  -- gold
}

-- The wheel is everything that turns: the dark face it is set into stays put.
-- Named so rattleLock can tell the two apart without keeping a list.
local WHEEL_PARTS = { DialSpoke = true, DialHub = true }

-- Distances out from the plate's seat on the body. Each layer clears the one
-- under it -- the face stands off the plate, the spokes off the face, the hub
-- off the spokes -- because two metal discs at the same depth z-fight exactly
-- the way the road did against the grass.
local FACE_OUT = 0.65
local SPOKE_OUT = 0.95
local HUB_OUT = 1.10

local function buildWheel(lock: Model, seat: CFrame, tier: any)
	local face = part("DialFace", lock, Vector3.new(0.5, tier.radius * 1.32, tier.radius * 1.32),
		seat * CFrame.new(FACE_OUT, 0, 0))
	face.Shape = Enum.PartType.Cylinder
	face.Color = NEAR_BLACK
	face.Material = Enum.Material.Metal

	-- Spokes radiate in the plate's own YZ plane, so a rotation about its X
	-- axis spins them in place. Each is authored pointing along +Y and then
	-- turned into position, which is why the offset is applied AFTER the
	-- angle -- swap those and every spoke lands in the same spot.
	local reach = tier.radius * 0.66
	for i = 1, tier.spokes do
		local angle = (i - 1) * (2 * math.pi / tier.spokes)
		local spoke = part("DialSpoke", lock, Vector3.new(0.4, reach, 0.3),
			seat * CFrame.Angles(angle, 0, 0) * CFrame.new(SPOKE_OUT, reach / 2 + 0.24, 0))
		spoke.Color = tier.metal
		spoke.Material = Enum.Material.Metal
	end

	local hub = part("DialHub", lock, Vector3.new(0.5, 0.8, 0.8), seat * CFrame.new(HUB_OUT, 0, 0))
	hub.Shape = Enum.PartType.Cylinder
	hub.Color = tier.metal
	hub.Material = Enum.Material.Metal
end

function PiggyBank.setLockLevel(refs: Refs, level: number)
	local plate = refs.lock.PrimaryPart
	if not plate then
		return
	end

	-- The wheel is rebuilt rather than restyled, because the spoke count is
	-- part of the tier. The plate survives: it is the one piece whose CFrame
	-- everything else is measured from.
	-- The plate, the rim and the hole all survive: the plate is the piece
	-- every other CFrame is measured from, and the other two are the OPENING,
	-- which is there at every level including none. Only the wheel is rebuilt,
	-- because the spoke count is part of the tier.
	for _, piece in ipairs(refs.lock:GetChildren()) do
		if piece ~= plate and piece.Name ~= "VaultRim" and piece.Name ~= "VaultHole" then
			piece:Destroy()
		end
	end

	-- LEVEL 0 IS AN OPEN HOLE, not an absent one. An unlocked piggy used to
	-- show nothing at all, which reads as "this piggy has no vault" rather
	-- than "this piggy is not locked" -- and the second is the thing a thief
	-- at the gate is actually deciding on. Hiding the door leaves the hole.
	if level <= 0 then
		plate.Transparency = 1
		return
	end

	local tier = LOCK_TIERS[math.clamp(level, 1, #LOCK_TIERS)]
	plate.Transparency = 0
	plate.Size = Vector3.new(DIAL_THICK, tier.radius * 2, tier.radius * 2)
	plate.Color = tier.metal:Lerp(Color3.fromRGB(24, 24, 28), 0.45)
	buildWheel(refs.lock, plate.CFrame, tier)
end

-- One spin per hold, so both sides can see the lock being worked rather than
-- watching a silent progress ring.
--
-- It does not spin back. A dial that snapped to its start every time would
-- read as a failed attempt, and leaving it where it lands means a piggy that
-- has been robbed all evening looks like it.
local spinning: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local SPIN_TIME = 1.1
local SPIN_TURN = math.pi * 1.5

function PiggyBank.rattleLock(refs: Refs)
	local plate = refs.lock.PrimaryPart
	if not plate or plate.Transparency >= 1 or spinning[refs.lock] then
		return
	end

	-- Offsets are read off the parts themselves rather than remembered, so a
	-- spin always continues from wherever the last one stopped.
	local seat = plate.CFrame
	local wheel = {}
	for _, piece in ipairs(refs.lock:GetChildren()) do
		if piece:IsA("BasePart") and WHEEL_PARTS[piece.Name] then
			table.insert(wheel, { piece = piece, offset = seat:Inverse() * piece.CFrame })
		end
	end
	if #wheel == 0 then
		return
	end

	spinning[refs.lock] = true
	task.spawn(function()
		local started = os.clock()
		while true do
			local t = (os.clock() - started) / SPIN_TIME
			if t >= 1 then
				break
			end
			-- Eased out: a hand spinning a dial lets go and it coasts.
			local angle = (1 - (1 - t) ^ 3) * SPIN_TURN
			for _, w in ipairs(wheel) do
				w.piece.CFrame = seat * CFrame.Angles(angle, 0, 0) * w.offset
			end
			task.wait()
		end
		for _, w in ipairs(wheel) do
			w.piece.CFrame = seat * CFrame.Angles(SPIN_TURN, 0, 0) * w.offset
		end
		spinning[refs.lock] = nil
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
