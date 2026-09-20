--!strict
--[[
	CatchIcons

	A PICTURE OF WHAT A CATCH EFFECT DOES, for the effects whose burst does not
	survive being shrunk into a card. Every catch effect has a live preview
	(`makeEffectIcon` in ClientMain simulates its Config numbers round a little
	pig), and for most of them that is the honest picture. For the Party Popper
	it was a pink pig with a white speck: a burst of paper is a MOMENT, and a
	simulation sampled at a random instant is usually between moments.

	So an effect listed here is drawn as an object instead -- built from parts,
	because a ViewportFrame draws BaseParts and nothing else, and so nothing is
	uploaded. `build` returns nil for any effect not listed, and the caller
	keeps the simulation.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CatchIcons = {}

local function add(model: Model, name: string, size: Vector3, cf: CFrame, colour: Color3,
	shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = model
	return p
end

local CONFETTI = {
	Color3.fromRGB(255, 214, 64),
	Color3.fromRGB(246, 96, 150),
	Color3.fromRGB(80, 190, 246),
	Color3.fromRGB(120, 220, 110),
	Color3.fromRGB(255, 150, 60),
}

local builders: { [string]: () -> Model } = {}

-- A CAUGHT THIEF, which is who a catch effect happens to: the burst goes off at
-- the feet of whoever was nabbed mid-robbery (`CatchFX`), so the icon is that
-- figure rather than the pig. It is the street's own NPC -- `ResidentModel`,
-- the neighbour who robs and gets robbed -- rather than a made-up burglar, so
-- the card shows the person a player has actually seen on the lawn. Standing
-- at the origin facing +Z, 5.6 studs tall. Nil if the figure could not build.
local function caughtThief(model: Model): boolean
	local ok, ResidentModel = pcall(require, ReplicatedStorage.Shared.ResidentModel)
	if not ok then
		return false
	end
	local staging = Instance.new("Folder")
	local built = select(1, (ResidentModel :: any).build(1, "", CFrame.new(), 0, staging))
	if not built then
		staging:Destroy()
		return false
	end
	-- A card has no use for the nametag or the speech bubble.
	for _, d in ipairs(built:GetDescendants()) do
		if d:IsA("BillboardGui") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	built.Parent = model
	staging:Destroy()
	return true
end

-- THE PARTY POPPER going off on a caught thief: the popper on the ground at
-- their feet, and a column of paper and three curling streamers thrown up
-- round them -- the effect's own tight upward cone. Seeded, so every card
-- draws the same burst rather than a new one each time the shop opens.
builders.partypopper = function()
	local model = Instance.new("Model")
	model.Name = "CatchIcon_partypopper"
	local rng = Random.new(20260919)
	caughtThief(model)

	-- The popper, lying at the thief's feet and aimed up at them. A striped
	-- cone: a cylinder's axis is X, so each ring is turned onto the aim.
	local base = Vector3.new(-2.2, 0.35, 0.8)
	local aim = Vector3.new(0.5, 1, 0).Unit
	local frameAt = CFrame.lookAt(base, base + aim) * CFrame.Angles(0, math.rad(90), 0)
	local stripes = { Color3.fromRGB(246, 96, 150), Color3.fromRGB(255, 214, 64) }
	local length, rings = 1.8, 5
	for i = 1, rings do
		local t = (i - 0.5) / rings
		local r = 0.15 + 0.45 * t
		add(model, "Popper" .. i, Vector3.new(length / rings + 0.02, r * 2, r * 2),
			frameAt * CFrame.new(length * t, 0, 0), stripes[(i - 1) % 2 + 1], Enum.PartType.Cylinder)
	end

	-- The paper: flat squares and strips thrown up round the thief in a
	-- widening column, spun at random.
	for i = 1, 46 do
		local y = 0.8 + rng:NextNumber() * 5.6
		local r = 1.1 + y * 0.18 + rng:NextNumber() * 0.6
		local a = rng:NextNumber() * math.pi * 2
		local at = Vector3.new(math.cos(a) * r, y, math.sin(a) * r * 0.7)
		local strip = rng:NextNumber() < 0.4
		local size = if strip then Vector3.new(0.2, 0.05, 0.65) else Vector3.new(0.4, 0.05, 0.4)
		add(model, "Paper" .. i, size,
			CFrame.new(at) * CFrame.Angles(rng:NextNumber(0, 6.3), rng:NextNumber(0, 6.3), rng:NextNumber(0, 6.3)),
			CONFETTI[(i - 1) % #CONFETTI + 1])
	end

	-- Three streamers curling up out of the popper and over the thief.
	local mouth = (frameAt * CFrame.new(length, 0, 0)).Position
	for s = 1, 3 do
		local colour = CONFETTI[s + 1]
		local pos = mouth
		local dir = (aim + Vector3.new((s - 2) * 0.35, 0, (s - 2) * 0.25)).Unit
		for k = 1, 10 do
			local step = 0.45
			local nextPos = pos + dir * step
			add(model, ("Streamer%d_%d"):format(s, k), Vector3.new(0.16, 0.05, step + 0.05),
				CFrame.lookAt((pos + nextPos) / 2, nextPos), colour)
			pos = nextPos
			dir = (CFrame.fromAxisAngle(Vector3.yAxis, 0.5 * (if s % 2 == 0 then 1 else -1)) * dir
				+ Vector3.new(0.05, 0.02, 0)).Unit
		end
	end
	return model
end

-- THE PAPARAZZI going off on a caught thief: a storm of camera flashes round
-- the figure and the press camera that took them. A flash is a white starburst
-- -- four thin neon bars crossed over a bright core -- because a flash is the
-- one thing that reads as a flash when it cannot move. Neon rather than a
-- light: a ViewportFrame draws no lights, and white neon holds its shape.
builders.paparazzi = function()
	local model = Instance.new("Model")
	model.Name = "CatchIcon_paparazzi"
	caughtThief(model)
	local flash = Color3.fromRGB(255, 255, 255)
	local tint = Color3.fromRGB(214, 226, 255)
	local bursts = {
		-- where, size
		{ Vector3.new(-2.3, 5.9, 1.2), 1.6 },
		{ Vector3.new(2.4, 5.2, 0.8), 1.3 },
		{ Vector3.new(-2.0, 3.3, 1.6), 1.0 },
		{ Vector3.new(2.6, 2.6, 1.4), 1.1 },
		{ Vector3.new(0.6, 7.1, 0.4), 0.9 },
	}
	for i, b in ipairs(bursts) do
		local at, r = b[1], b[2]
		local face = CFrame.new(at)
		add(model, "FlashCore" .. i, Vector3.new(r * 0.55, r * 0.55, r * 0.55), face, flash, Enum.PartType.Ball)
			.Material = Enum.Material.Neon
		for k = 0, 3 do
			local ray = add(model, ("FlashRay%d_%d"):format(i, k), Vector3.new(r * (if k % 2 == 0 then 2.2 else 1.4), 0.12, 0.05),
				face * CFrame.Angles(0, 0, math.rad(k * 45)), if k % 2 == 0 then flash else tint)
			ray.Material = Enum.Material.Neon
		end
	end
	-- The press camera, held up in front of the thief and aimed at them.
	local black = Color3.fromRGB(34, 30, 38)
	local metal = Color3.fromRGB(180, 184, 192)
	local cam = CFrame.new(-1.2, 2.2, 3.0) * CFrame.Angles(0, math.rad(200), math.rad(-8))
	add(model, "CameraBody", Vector3.new(1.8, 1.1, 0.8), cam, black)
	add(model, "CameraTop", Vector3.new(0.7, 0.35, 0.6), cam * CFrame.new(-0.4, 0.7, 0), black)
	add(model, "Lens", Vector3.new(0.5, 0.75, 0.75), cam * CFrame.new(0, 0, 0.6) * CFrame.Angles(0, math.rad(90), 0),
		metal, Enum.PartType.Cylinder)
	add(model, "Bulb", Vector3.new(0.12, 1.0, 1.0), cam * CFrame.new(0.55, 1.1, 0.1) * CFrame.Angles(0, math.rad(90), 0),
		flash, Enum.PartType.Cylinder).Material = Enum.Material.Neon
	return model
end

-- The caught thief on their own, for the effects that keep the simulation:
-- ClientMain's `makeEffectIcon` runs their burst round this figure rather
-- than round a pig, so a nab effect's card shows the person it goes off on.
-- A pig with particles on it is what the retired piggy auras looked like, and
-- a nab effect drawn that way read as one of them. Nil if the figure could
-- not build, and the caller falls back to the pig.
function CatchIcons.thief(): Model?
	local model = Instance.new("Model")
	model.Name = "CatchIcon_thief"
	if not caughtThief(model) then
		model:Destroy()
		return nil
	end
	return model
end

-- The drawn icon for a catch effect, or nil when it keeps the simulation.
function CatchIcons.build(key: string): Model?
	local build = builders[key]
	return if build then build() else nil
end

return CatchIcons
