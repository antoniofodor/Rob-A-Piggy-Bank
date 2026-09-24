--!strict
--[[
	FxCull

	DISTANCE CULLING OF PARTICLE EMITTERS AND LIGHTS, ON THIS MACHINE ONLY.

	Every piggy bank carries four emitters and two lights, every shop vault
	three and one, every guard dog a sleep puff: measured on the live street
	that is 96 emitters and 42 lights, all of them simulated whether or not
	the camera is anywhere near. Disabling the 26 that were active took the
	mean client frame from about 70 ms to 43 on a machine that could not draw
	ten frames a second -- the single largest lever in the whole pass.

	THE SERVER NEVER KNOWS. `Enabled` is written here, on the client, and a
	client write to a replicated property holds until the server next writes
	that same property -- so what this has to get right is WHAT THE SERVER
	MEANT. An emitter the server switched OFF (a sleeping dog's puff, an aura
	nobody has equipped) must stay off when the camera walks up to it, and one
	the server switched ON while it was out of range must come on when the
	camera arrives. So every entry remembers the AUTHORED value: the property
	as last written by anybody but this module, read off the changed signal
	with this module's own writes masked by a flag. A server write that lands
	on a culled emitter is recorded and re-hidden in the same breath.

	WHAT IS NOT CULLED. Anything carrying the `FxCullExempt` attribute; and
	nothing that fires through `Emit()` is affected at all, because a burst
	does not read `Enabled` -- the landing dust, the catch sparkle and the
	rebirth fireworks all still play at any range.

	One statement in `ClientMain` holding no local, for the 200-register
	ceiling that file records at length.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local FxCull = {}

local EXEMPT_ATTRIBUTE = "FxCullExempt"

type Entry = {
	inst: ParticleEmitter | Light,
	light: boolean,
	authored: boolean,
	-- True while this module is the one writing `Enabled`, so the changed
	-- signal can tell its own writes from everybody else's.
	ours: boolean,
	-- True while the entry is switched off BY DISTANCE, so a server write
	-- that turns it on out of range is recorded and re-hidden.
	culled: boolean,
}

local entries: { [Instance]: Entry } = {}
local started = false

local function spec(): any
	return (Config :: any).FX_CULL or { interval = 0.5, emitterRange = 150, lightRange = 120 }
end

local function register(inst: Instance)
	if entries[inst] then
		return
	end
	if not (inst:IsA("ParticleEmitter") or inst:IsA("Light")) then
		return
	end
	if inst:GetAttribute(EXEMPT_ATTRIBUTE) then
		return
	end
	local fx = inst :: ParticleEmitter | Light
	local entry: Entry = {
		inst = fx,
		light = inst:IsA("Light"),
		authored = fx.Enabled,
		ours = false,
		culled = false,
	}
	entries[inst] = entry
	fx:GetPropertyChangedSignal("Enabled"):Connect(function()
		if entry.ours then
			return
		end
		entry.authored = fx.Enabled
		if entry.culled and fx.Enabled then
			entry.ours = true
			fx.Enabled = false
			entry.ours = false
		end
	end)
	inst.Destroying:Connect(function()
		entries[inst] = nil
	end)
end

local function forget(inst: Instance)
	entries[inst] = nil
end

-- Where the effect IS, in the world: its parent part, or the part its
-- attachment hangs off. Anything else has no position and is left alone.
local function positionOf(inst: Instance): Vector3?
	local parent = inst.Parent
	if not parent then
		return nil
	end
	if parent:IsA("BasePart") then
		return parent.Position
	end
	if parent:IsA("Attachment") then
		return parent.WorldPosition
	end
	return nil
end

local function write(entry: Entry, value: boolean)
	if entry.inst.Enabled == value then
		return
	end
	entry.ours = true
	entry.inst.Enabled = value
	entry.ours = false
end

local function pass()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local s = spec()
	local emitterRange = s.emitterRange or 150
	local lightRange = s.lightRange or 120
	for inst, entry in pairs(entries) do
		if not inst.Parent then
			entries[inst] = nil
			continue
		end
		local at = positionOf(inst)
		if not at then
			continue
		end
		local range = if entry.light then lightRange else emitterRange
		local far = (at - eye).Magnitude > range
		if far then
			entry.culled = entry.authored
			write(entry, false)
		else
			entry.culled = false
			write(entry, entry.authored)
		end
	end
end

function FxCull.start()
	if started or not RunService:IsClient() then
		return
	end
	started = true

	-- `DescendantAdded` is a HIERARCHY signal and does fire for an instance
	-- that replicates in, unlike a tag's added signal -- so one sweep of what
	-- is already here plus the signal covers everything, with no bounded
	-- rescan needed.
	for _, inst in ipairs(Workspace:GetDescendants()) do
		register(inst)
	end
	Workspace.DescendantAdded:Connect(register)
	Workspace.DescendantRemoving:Connect(forget)

	local due = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now < due then
			return
		end
		due = now + (spec().interval or 0.5)
		local ok, err = pcall(pass)
		if not ok then
			warn("[FxCull] " .. tostring(err))
			-- A broken pass is not a broken game: back off rather than spam.
			due = now + 5
		end
	end)
end

-- For a probe: how many effects this client is holding off by distance.
function FxCull.count(): (number, number)
	local total, culled = 0, 0
	for _, entry in pairs(entries) do
		total += 1
		if entry.culled then
			culled += 1
		end
	end
	return total, culled
end

return FxCull
