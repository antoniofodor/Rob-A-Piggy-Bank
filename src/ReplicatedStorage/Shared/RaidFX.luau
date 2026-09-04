--!strict
--[[
	RaidFX

	The saucer's lights and the tractor beams, animated on every client.

	CLIENT-SIDE, for the reason the animated skins, the moat and HouseFX are.
	A beam that scrolls and a rim that chases are a property write per part per
	frame. Driven from the server that is a REPLICATED write per part per
	frame -- six beams and twelve rim lights is eighteen parts before anybody
	counts a second raid -- to say something every machine can work out from a
	clock and an attribute. The server owns the positions the raid depends on;
	the client owns everything that is only a picture.

	FOUND BY TAG, NEVER COLLECTED ONCE. A saucer is built when a raid starts
	and destroyed when it ends, and a drone can be knocked out of the sky at
	any moment, so a list gathered at startup would be empty forever. Same
	reason the moat is found by tag rather than at boot.

	NO STROBE. Every curve in here is continuous and the rim chases rather than
	blinking, because the accessibility standard treats more than three flashes
	a second as unsafe and this audience is nine. Twelve lamps flashing
	together is the one arrangement that reads as a single full-screen flash,
	which is exactly why each one carries its own phase.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local AlienModel = require(script.Parent.AlienModel)

local RaidFX = {}

local GLOW = Color3.fromRGB(96, 255, 176)
local COOL = Color3.fromRGB(40, 150, 120)

local lamps: { BasePart } = {}
local beamParts: { BasePart } = {}
local started = false

local function track(list: { BasePart })
	return function(inst: Instance)
		if inst:IsA("BasePart") then
			table.insert(list, inst)
		end
	end
end

-- Swept rather than handled per instance, because a raid tears its saucer
-- down as one model and the tag-removed signal does not fire for a Destroy
-- that takes the tag with it. Same workaround the moat uses.
local function sweep(list: { BasePart })
	for i = #list, 1, -1 do
		if not list[i].Parent then
			table.remove(list, i)
		end
	end
end

function RaidFX.start()
	if started then
		return
	end
	started = true

	for _, inst in ipairs(CollectionService:GetTagged(AlienModel.HULL_TAG)) do
		track(lamps)(inst)
	end
	for _, inst in ipairs(CollectionService:GetTagged(AlienModel.BEAM_TAG)) do
		track(beamParts)(inst)
	end
	CollectionService:GetInstanceAddedSignal(AlienModel.HULL_TAG):Connect(track(lamps))
	CollectionService:GetInstanceAddedSignal(AlienModel.BEAM_TAG):Connect(track(beamParts))
	CollectionService:GetInstanceRemovedSignal(AlienModel.HULL_TAG):Connect(function()
		sweep(lamps)
	end)
	CollectionService:GetInstanceRemovedSignal(AlienModel.BEAM_TAG):Connect(function()
		sweep(beamParts)
	end)

	RunService.Heartbeat:Connect(function()
		if #lamps == 0 and #beamParts == 0 then
			return
		end
		local clock = os.clock()

		-- The rim: one bright band travelling round the ring. A phase per lamp
		-- is what makes it read as rotation rather than as twelve bulbs taking
		-- turns, and it is why no two are ever bright at the same instant.
		for i = #lamps, 1, -1 do
			local p = lamps[i]
			if not p.Parent then
				table.remove(lamps, i)
			else
				local phase = p:GetAttribute("Phase")
				local at = if type(phase) == "number" then phase else 0
				local d = math.abs(((clock * 0.45 - at + 0.5) % 1) - 0.5)
				local lit = math.max(0, 1 - d / 0.22)
				p.Color = COOL:Lerp(GLOW, lit)
			end
		end

		-- The beams breathe rather than sit still, so a lock-on looks like it
		-- is doing something. Transparency only: the CFrame and the length are
		-- the server's, because where a beam actually reaches is a fact the
		-- raid depends on rather than a picture.
		for i = #beamParts, 1, -1 do
			local p = beamParts[i]
			if not p.Parent then
				table.remove(beamParts, i)
			elseif p.Transparency < 0.99 then
				-- Left alone once the server has switched it off. A knocked-out
				-- beam is set fully transparent and must stay that way, or this
				-- loop would light it back up every frame and the one signal
				-- that says "you got it" would never appear.
				p.Transparency = 0.42 + math.sin(clock * 3.1) * 0.12
			end
		end
	end)
end

return RaidFX
