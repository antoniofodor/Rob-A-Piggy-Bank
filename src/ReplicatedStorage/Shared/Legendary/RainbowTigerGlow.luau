--!strict
-- Rainbow Tiger's client companion: the rainbow that FLOWS down the stripes,
-- and the eye cycle.
--
-- THE STRIPES ARE PARTS NOW, NOT TEXELS. Each colour band is its own Neon
-- ribbon (`Stripe_<band>_<tone>`, built by
-- blender/pig/make/build_rainbowtiger_stripe_bands.py) laid over the painted
-- stripe it replaces, because a painted texel cannot change hue at run time:
-- EmissiveTint MULTIPLIES, so a red stripe can never be tinted blue. Here
-- band i wears the palette at (i * LAG - time): top to bottom it reads red
-- to violet like the paint, and each colour steps one band DOWN every LAG
-- seconds. (time - i * LAG) also flows down, but upside-down: red over violet.
--
-- The coat's own stripe emission is switched OFF while this runs: those
-- painted stripes sit under the ribbons, and pulsing them would only light
-- the seams. The eyes keep the Blender build's four-second RGB loop, on the
-- same clock as the top band.
local RunService = game:GetService("RunService")
local Glow = {}

local PERIOD = 4
local PALETTE = {
	Color3.fromRGB(231, 65, 91), Color3.fromRGB(247, 134, 29), Color3.fromRGB(244, 209, 42),
	Color3.fromRGB(73, 214, 100), Color3.fromRGB(27, 164, 238), Color3.fromRGB(71, 101, 222),
	Color3.fromRGB(157, 65, 220),
}

-- A colour takes this long to step from one band to the next.
local LAG = PERIOD / #PALETTE

local function eyeColour(t: number): Color3
	local x = ((t % PERIOD) / PERIOD) * #PALETTE
	local i = math.floor(x)
	local a = PALETTE[i + 1]
	local b = PALETTE[(i + 1) % #PALETTE + 1]
	return a:Lerp(b, x - i)
end

function Glow.start(model: Model, phaseOffset: number?)
	local surfaces = {}
	local eyes = {}
	local stripes: { [BasePart]: { any } } = {}
	for _, object in model:GetDescendants() do
		if object:IsA("SurfaceAppearance") and object:GetAttribute("RainbowTigerGlow") == true then
			surfaces[object] = { object.EmissiveStrength, object.EmissiveTint }
		elseif object:IsA("BasePart") and object.Name == "Eyes" then
			eyes[object] = { object.Color, object.Material }
		elseif object:IsA("BasePart") then
			local band = tonumber(string.match(object.Name, "^Stripe_(%d+)_"))
			if band then
				stripes[object] = { object.Color, object.Material, band }
			end
		end
	end
	for surface in surfaces do surface.EmissiveTint = Color3.new(1, 1, 1) end
	for part in eyes do part.Material = Enum.Material.Neon end
	for part in stripes do part.Material = Enum.Material.Neon end
	-- Only once the ribbons are there: an older model without them keeps
	-- its painted stripes pulsing rather than going dark.
	local ribbons = next(stripes) ~= nil
	local started = os.clock()
	local stopped = false
	local heartbeat: RBXScriptConnection?
	local destroying: RBXScriptConnection?
	local function stop()
		if stopped then return end
		stopped = true
		if heartbeat then heartbeat:Disconnect() end
		if destroying then destroying:Disconnect() end
		for surface, state in surfaces do
			if surface.Parent then
				surface.EmissiveStrength = state[1]
				surface.EmissiveTint = state[2]
			end
		end
		for part, state in eyes do
			if part.Parent then part.Color = state[1]; part.Material = state[2] end
		end
		for part, state in stripes do
			if part.Parent then part.Color = state[1]; part.Material = state[2] end
		end
	end
	heartbeat = RunService.Heartbeat:Connect(function()
		local t = os.clock() - started + (phaseOffset or 0)
		local pulse = (0.5 - 0.5 * math.cos(2 * math.pi * t / PERIOD)) ^ 4
		for surface in surfaces do
			surface.EmissiveStrength = if ribbons then 0 else 0.08 + 0.95 * pulse
		end
		local colour = eyeColour(-t)
		for part in eyes do part.Color = colour end
		for part, state in stripes do part.Color = eyeColour(state[3] * LAG - t) end
	end)
	destroying = model.Destroying:Connect(stop)
	return stop
end

return Glow
