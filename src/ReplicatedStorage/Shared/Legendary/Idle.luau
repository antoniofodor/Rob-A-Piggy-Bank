--!strict
-- A legendary's idle sway, driven on the client from `Legendary/Rigs`.
--
-- Each moving piece is one rigid part (see the Rigs header), so a sway is a
-- rotation of those parts about their bone's head, written as a local CFrame.
-- The server builds the parts and never moves them again, so there is nothing
-- to fight -- the same split as the glow helpers, and the same shape:
-- start(model, key, phaseOffset) returns a stop function, and the model's own
-- Destroying stops it too.
--
-- The frame comes from the `IdleRig` anchor `LegendaryModel` puts on the
-- armature's origin, turned a half and carrying the scale, so a far-row plot
-- and a near-row plot need nothing different here.
--
-- Beyond `FAR` studs from the camera the parts are put back and left: a
-- 3-degree sway is invisible from across the street.
local RunService = game:GetService("RunService")

local Rigs = require(script.Parent:WaitForChild("Rigs"))

local Idle = {}

local FAR = 160
local RIG_NAME = "IdleRig"

function Idle.start(model: Model, key: string, phaseOffset: number?)
	local rig = Rigs[key]
	local anchor = model:FindFirstChild(RIG_NAME)
	if not rig or not anchor or not anchor:IsA("BasePart") then
		return function() end
	end
	local s = anchor:GetAttribute("Scale")
	s = if type(s) == "number" then s else 1

	-- Everything is captured in the ANCHOR's frame, so the rest pose is exact
	-- and a frame is one CFrame product per part.
	local groups = {}
	for _, spec in ipairs(rig.bones) do
		local pivot = CFrame.new(Vector3.new(-spec.head.X, spec.head.Z, spec.head.Y) * s)
		local members = {}
		for _, name in ipairs(spec.parts) do
			local p = model:FindFirstChild(name)
			if p and p:IsA("BasePart") then
				table.insert(members, { part = p, rest = pivot:Inverse() * anchor.CFrame:ToObjectSpace(p.CFrame) })
			end
		end
		if #members > 0 then
			table.insert(groups, { pivot = pivot, axis = spec.track.axis.Unit,
				a = spec.track.a, b = spec.track.b, members = members })
		end
	end

	local omega = 2 * math.pi / rig.period
	local started = os.clock() - (phaseOffset or 0)
	local resting = false

	local function place(angleOf: (any) -> number)
		local frame = anchor.CFrame
		for _, g in ipairs(groups) do
			local turned = frame * g.pivot * CFrame.fromAxisAngle(g.axis, angleOf(g))
			for _, m in ipairs(g.members) do
				m.part.CFrame = turned * m.rest
			end
		end
	end
	local function atRest() return 0 end

	local heartbeat: RBXScriptConnection?
	local destroying: RBXScriptConnection?
	local stopped = false
	local function stop()
		if stopped then return end
		stopped = true
		if heartbeat then heartbeat:Disconnect() end
		if destroying then destroying:Disconnect() end
		if anchor.Parent then place(atRest) end
	end

	heartbeat = RunService.Heartbeat:Connect(function()
		local cam = workspace.CurrentCamera
		if cam and (cam.CFrame.Position - anchor.Position).Magnitude > FAR then
			if not resting then
				resting = true
				place(atRest)
			end
			return
		end
		resting = false
		local w = omega * (os.clock() - started)
		local sn, cs = math.sin(w), math.cos(w)
		place(function(g) return g.a * sn + g.b * cs end)
	end)
	destroying = model.Destroying:Connect(stop)
	return stop
end

return Idle
