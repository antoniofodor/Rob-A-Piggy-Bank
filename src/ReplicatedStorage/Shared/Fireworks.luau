--!strict
--[[
	Fireworks

	The show that goes up over a plot when its owner rebirths.

	THE FIFTH CLIENT-SIDE ANIMATOR, and it is here for the reason the
	animated skins, the moat, `HouseFX` and `CatchFX` are: the server
	decides, publishes two attributes and never touches it again, and every
	client renders what it can see for itself. Driving this one server-side
	would be a hundred-odd parts of CFrame and Transparency writes per frame,
	replicated to eight people, to say something two numbers already say.

	WHAT IT IS FOR. Rebirth is the one purchase in this game that costs a
	player EVERYTHING they own -- every coin, both upgrade trees, forty rungs
	of ladder -- and the whole of it used to happen on one screen: a toast, a
	skin drop, and a plot quietly rebuilt at level 0. The street had no way of
	knowing anybody had done it. For the mechanic this economy most needs
	players to press, that is exactly the wrong way round.

	NEON AND NOT LIGHTS. There is no night in this game -- `WorldService`
	sets `ClockTime` to 14.5 once and nothing ever moves it -- so a light is
	the wrong instrument, and this project has already paid for that lesson on
	the endgame house tiers, which read as vanilla for months because their
	whole celebration was four `lantern()` calls invisible at midday. Neon
	renders flat out whatever the sun is doing and the shipped BloomEffect
	does the rest.

	WHAT IT MAY NOT DO:

	  * NOTHING IT BUILDS COLLIDES, ANSWERS A QUERY OR CASTS A SHADOW. A
	    celebration may never change an outcome, and the guarantee is that
	    there is nothing here with a body. The same rule every lawn ornament
	    and every tuft of grass already follows.

	  * NOTHING IT BUILDS IS ON THE SCREEN. No ScreenGui, no camera write, no
	    tint. The show is ninety studs up in the WORLD, so it is loudest to
	    whoever chooses to look at it and costs nothing to whoever does not.

	  * IT STAYS UNDER THREE FLASHES A SECOND, the ceiling `HouseFX` holds
	    the whole game to. Shells rise on a fixed clock, so bursts arrive
	    exactly as often as launches and `Config.FIREWORKS.gap` IS the flash
	    rate. The number that has to clear the ceiling is the gap LESS its
	    jitter rather than the gap -- see the note beside those two fields,
	    where the first pass measured the mean and shipped a worst case over
	    the line.

	  * IT CLEANS UP AFTER ITSELF. Every part goes through `Debris`, with a
	    ceiling derived from the burst's own longest lifetime rather than
	    pinned -- so retuning the sparks cannot leave litter at altitude.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Fireworks = {}

local started = false

-- Roblox ships three particle textures and this is the one that reads as a
-- spark. Named here rather than reached for inline for the same reason
-- `Config.EFFECTS` names its three: it is a fact about what is available,
-- not a per-shell decision.
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

-- Where the show is parented. One folder rather than loose parts in the
-- workspace, so a probe can ask how much of this is currently in the air and
-- so nothing else has to step over half a firework.
local FOLDER_NAME = "FireworksFX"

local function stage(): Folder
	local existing = workspace:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = workspace
	return folder
end

-- Everything built here is dead weight to the physics engine, the query
-- system and the shadow pass, and saying so in one place is what stops a
-- later shell being the one that body-blocks a chase.
local function inert(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Material = Enum.Material.Neon
end

-- THE BURST, and it is two things rather than one on purpose.
--
-- A particle cloud alone has no centre: it reads as a puff arriving rather
-- than as something going off. The flash is a hard bright core that expands
-- and fades in under a third of a second, which is what the eye actually
-- reads as the bang. The particles are what it leaves behind.
local function burst(at: Vector3, colour: Color3, folder: Folder)
	local fw = Config.FIREWORKS

	local core = Instance.new("Part")
	core.Name = "Flash"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.new(1, 1, 1)
	core.Color = colour
	core.Position = at
	inert(core)
	core.Parent = folder

	-- Size only, never position: a Ball grows about its own centre, so the
	-- flash cannot walk off the point the shell reached.
	TweenService:Create(core, TweenInfo.new(fw.flashSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(fw.flashSize, fw.flashSize, fw.flashSize),
		Transparency = 1,
	}):Play()
	Debris:AddItem(core, fw.flashSeconds + 0.2)

	-- The sparks hang off their own anchor rather than off the flash, or
	-- they would be destroyed with it a second before they have finished
	-- falling.
	local anchor = Instance.new("Part")
	anchor.Name = "Burst"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = at
	anchor.Transparency = 1
	inert(anchor)
	anchor.Parent = folder

	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARK
	emitter.Color = ColorSequence.new(colour)
	emitter.LightEmission = fw.sparkGlow
	emitter.Speed = fw.burstSpeed
	emitter.Lifetime = fw.burstLife
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, fw.fall, 0)
	emitter.Drag = 1.2
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-90, 90)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, fw.burstSize),
		NumberSequenceKeypoint.new(1, 0),
	})
	-- RATE ZERO AND `Emit`, which is the whole difference between a firework
	-- and an aura. Left above zero this would be a permanent green cloud at
	-- ninety studs that nobody could reach to switch off.
	emitter.Rate = 0
	emitter.Enabled = false
	emitter.Parent = attachment
	emitter:Emit(fw.burst)

	-- DERIVED FROM THE SPARKS' OWN LONGEST LIFE rather than pinned, so
	-- retuning `burstLife` cannot start leaving anchors in the sky.
	Debris:AddItem(anchor, fw.burstLife.Max + 0.5)
end

-- One shell: up, then off.
local function shell(from: Vector3, colour: Color3, folder: Folder)
	local fw = Config.FIREWORKS
	local rng = Random.new()

	local top = from + Vector3.new(
		rng:NextNumber(-fw.spread, fw.spread),
		fw.apex + rng:NextNumber(-fw.apexJitter, fw.apexJitter),
		rng:NextNumber(-fw.spread, fw.spread))

	local comet = Instance.new("Part")
	comet.Name = "Shell"
	comet.Shape = Enum.PartType.Ball
	comet.Size = Vector3.new(0.9, 0.9, 0.9)
	comet.Color = colour
	comet.Position = from
	inert(comet)
	comet.Parent = folder

	-- A TRAIL AND NOT AN EMITTER, because what a rising shell leaves is a
	-- continuous streak rather than a scatter -- and a Trail is two
	-- attachments against a particle system's worth of tuning.
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.4, 0)
	a0.Parent = comet
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.4, 0)
	a1.Parent = comet

	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(colour)
	trail.LightEmission = 1
	trail.Lifetime = 0.4
	trail.MinLength = 0
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Parent = comet

	-- QUAD-OUT, so the shell DECELERATES as it climbs. Linear reads as a
	-- lift rather than a launch: a real one leaves fast and runs out of
	-- momentum, and the pause at the top is what makes the burst land.
	local rise = TweenService:Create(
		comet,
		TweenInfo.new(fw.riseSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = top })
	rise.Completed:Connect(function()
		-- The trail outlives the comet by its own lifetime, so the streak
		-- fades out of the sky instead of being cut off at the bang.
		comet.Transparency = 1
		Debris:AddItem(comet, trail.Lifetime)
		burst(top, colour, folder)
	end)
	rise:Play()
end

-- The whole show for one plot.
local function show(centre: Vector3, rebirths: number)
	local fw = Config.FIREWORKS
	local folder = stage()
	local rng = Random.new()
	local count = Config.fireworkShells(rebirths)

	-- NO COLOUR TWICE IN A ROW. With six colours and up to ten shells a plain
	-- draw repeats about one launch in six, and two identical bursts back to
	-- back read as the show having stalled rather than as chance. This is the
	-- cheap half of the shuffled-bag argument the music cues make: what has
	-- to be avoided is the REPEAT, not the distribution.
	local last = 0

	task.spawn(function()
		for i = 1, count do
			local pick = rng:NextInteger(1, #fw.palette)
			if pick == last then
				pick = (pick % #fw.palette) + 1
			end
			last = pick

			local from = centre + Vector3.new(
				rng:NextNumber(-fw.spread, fw.spread),
				2,
				rng:NextNumber(-fw.spread, fw.spread))
			shell(from, fw.palette[pick], folder)

			if i < count then
				task.wait(fw.gap + rng:NextNumber(-fw.gapJitter, fw.gapJitter))
			end
		end
	end)
end

local function watch(plotModel: Instance)
	if not plotModel:IsA("Model") then
		return
	end

	-- THE COUNTER IS WATCHED AND THE RANK IS READ, in that order, because the
	-- server writes them in the other one. Watching the RANK instead would
	-- miss nothing today and would miss every repeat the moment two rebirths
	-- ever landed on the same number.
	plotModel:GetAttributeChangedSignal(Config.PLOT_FIREWORK_ATTRIBUTE):Connect(function()
		local count = plotModel:GetAttribute(Config.PLOT_FIREWORK_ATTRIBUTE)
		if type(count) ~= "number" or count <= 0 then
			-- Cleared on release, which is not a rebirth and must not fire a
			-- show over a plot nobody lives on.
			return
		end
		local rank = plotModel:GetAttribute(Config.PLOT_FIREWORK_RANK_ATTRIBUTE)
		-- THE PLOT'S OWN PIVOT AND NOT A CONSTANT. Its PrimaryPart is the
		-- Base, so this is the slab's centre on both rows -- and reading it
		-- from the model is what keeps the far row, which carries a half
		-- turn, from needing a second answer.
		show(plotModel:GetPivot().Position, if type(rank) == "number" then rank else 1)
	end)
end

function Fireworks.start()
	if started then
		return
	end
	started = true

	-- Nothing here belongs on a server, and requiring it there would build a
	-- second copy of the whole show that nobody would ever see.
	if not RunService:IsClient() then
		return
	end

	task.spawn(function()
		local plots = workspace:WaitForChild("Plots", 30)
		if not plots then
			return
		end
		-- A PLOT IS BUILT AT SERVER STARTUP, so the folder's children are
		-- already here by the time a client runs -- swept first, then the
		-- signal for arrivals. The shop doors lost every prompt they had to
		-- exactly this ordering being the other way round.
		for _, child in ipairs(plots:GetChildren()) do
			watch(child)
		end
		plots.ChildAdded:Connect(watch)
	end)
end

return Fireworks
