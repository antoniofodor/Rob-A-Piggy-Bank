--!strict
--[[
	TuftCull

	DISTANCE FADING OF THE GRASS TUFTS, ON THIS MACHINE ONLY.

	The 1,569 tufts are the largest single class of part in the world -- about
	half of everything standing in it -- and every one is a MeshPart drawn
	wherever the camera is. Measured on the live client (2026-09-23): hiding
	all of them took the mean frame from 16.7 ms to 15.5, about 7% on a desktop
	and a larger share on the tablets and phones this game is for. Deleting
	them is the wrong lever, because the grass a player is standing on is what
	makes the lawn read as a lawn. So a tuft further than `Config.FX_CULL.
	tuftRange` from the camera is faded out on this machine through
	`LocalTransparencyModifier`, which the server never sees, and fades back in
	over `tuftFade` studs as the camera approaches so nothing pops.

	A tuft never moves, so its position is read once at registration and the
	pass is a distance per tuft every `FX_CULL.interval` -- fifteen hundred
	subtractions twice a second, which is nothing next to what they cost to
	draw. Nothing is written when the value has not changed.

	One statement in `ClientMain` holding no local, for the 200-register
	ceiling that file records at length.
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local TuftCull = {}

local TUFT_NAME = "Tuft"

type Entry = { part: BasePart, at: Vector3, value: number }

local entries: { [Instance]: Entry } = {}
local started = false

local function spec(): any
	return (Config :: any).FX_CULL or {}
end

local function register(inst: Instance)
	if entries[inst] or inst.Name ~= TUFT_NAME or not inst:IsA("BasePart") then
		return
	end
	local part = inst :: BasePart
	entries[inst] = { part = part, at = part.Position, value = 0 }
end

local function forget(inst: Instance)
	entries[inst] = nil
end

local function pass()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local s = spec()
	local range = s.tuftRange or 120
	local fade = math.max(s.tuftFade or 30, 1)
	local near = range - fade
	for inst, entry in pairs(entries) do
		if not inst.Parent then
			entries[inst] = nil
			continue
		end
		local d = (entry.at - eye).Magnitude
		-- 0 inside `near`, 1 beyond `range`, a straight ramp between, so a
		-- tuft the camera walks toward comes up through the grass rather
		-- than appearing.
		local want = math.clamp((d - near) / fade, 0, 1)
		-- Quantised to a twentieth so a slowly drifting camera does not
		-- rewrite fifteen hundred parts every pass for a change nobody sees.
		want = math.floor(want * 20 + 0.5) / 20
		if want ~= entry.value then
			entry.value = want
			entry.part.LocalTransparencyModifier = want
		end
	end
end

function TuftCull.start()
	if started or not RunService:IsClient() then
		return
	end
	started = true
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
			warn("[TuftCull] " .. tostring(err))
			due = now + 5
		end
	end)
end

-- For a probe: how many tufts are registered and how many are fully hidden.
function TuftCull.count(): (number, number)
	local total, hidden = 0, 0
	for _, entry in pairs(entries) do
		total += 1
		if entry.value >= 1 then
			hidden += 1
		end
	end
	return total, hidden
end

return TuftCull
