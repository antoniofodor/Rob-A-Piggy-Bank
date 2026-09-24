-- Six-second poses sampled from the approved Blender files. Meshes are baked
-- into the body's import frame; these poses preserve pivots and parent motion.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Data = require(script.Parent.ArcadeMotionData)
local Config = require(script.Parent.Config)
local ArcadeAnimator = {}
local TAG = "ArcadeMotion"
local keys = { respawn = true, powerup = true, synthwave = true,
	jackpot = true, finalboss = true, mechaplayer = true, aurora = true, neonmint = true }
local sets = {}
local started = false

-- A SET MAY ASK FOR A PLAIN SPIN INSTEAD OF BAKED POSES, and that is the
-- whole of what `spin` on a `Config.SKIN_ACCESSORIES` row means: turns a
-- second about the body's own up axis, through the part's own centre.
--
-- HERE RATHER THAN IN `SkinFX`, WHICH ALREADY HAS A `spin`, because that
-- loop drives parts SkinFX itself built and keys off an anchor part it owns.
-- These are `SkinAccessories`, and this file is already the one animator
-- that reads that folder -- so it already answers the two questions a second
-- one would have had to answer again: a welded pig keeps its pose (a part
-- the client moves would fight its weld) and anything past the cull is left
-- alone. The name says Arcade and has not been true since `aurora` and
-- `neonmint` joined it.
local function spinsOf(key: string?): { any }
	local out = {}
	for _, entry in ipairs(key and Config.SKIN_ACCESSORIES[key] or {}) do
		if type(entry.spin) == "number" and entry.spin ~= 0 then
			table.insert(out, entry)
		end
	end
	return out
end

function ArcadeAnimator.attach(model: Instance, body: BasePart, key: string?)
	local old = model:FindFirstChild("ArcadeMotion")
	if old then old:Destroy() end
	if not key or not (keys[key] or #spinsOf(key) > 0) then return end
	local marker = Instance.new("ObjectValue")
	marker.Name = "ArcadeMotion"
	marker.Value = body
	marker:SetAttribute("Skin", key)
	marker.Parent = model
	CollectionService:AddTag(marker, TAG)
end

local function frame(row)
	return CFrame.new(table.unpack(row, 1, 12))
end

local function track(marker)
	if not marker:IsA("ObjectValue") then return end
	local body = marker.Value
	if not body or not body:IsA("BasePart") or not marker.Parent then return end
	local key = marker:GetAttribute("Skin")
	local folder = marker.Parent:FindFirstChild("SkinAccessories")
	local parts = {}
	for name, samples in pairs(Data[key] or {}) do
		local part = folder and folder:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local poses = {}
			for _, row in ipairs(samples) do
				table.insert(poses, { cf = frame(row), scale = Vector3.new(row[13], row[14], row[15]) })
			end
			-- Read authored size, since a shop may already have scaled the pig.
			local size = part:GetAttribute("ArcadeBaseSize")
			if typeof(size) == "Vector3" then
				table.insert(parts, { part = part, poses = poses, size = size })
			end
		end
	end
	local surfaces = {}
	for _, p in ipairs(marker.Parent:GetChildren()) do
		if p:IsA("MeshPart") then
			local sa = p:FindFirstChildOfClass("SurfaceAppearance")
			if sa and sa.EmissiveStrength > 0 then
				table.insert(surfaces, { surface = sa, strength = sa.EmissiveStrength })
			end
		end
	end
	-- REST IS READ OFF THE PART RATHER THAN RECOMPUTED FROM THE ROW. `dress`
	-- has just seated it through `offset`, `rot` and the body's own scale, so
	-- the part already holds the answer -- and a second derivation here is a
	-- second chance to disagree with where the thing actually is.
	local spins = {}
	for _, entry in ipairs(spinsOf(key)) do
		local part = folder and folder:FindFirstChild(entry.part)
		if part and part:IsA("BasePart") then
			table.insert(spins, { part = part, rate = entry.spin,
				rest = body.CFrame:ToObjectSpace(part.CFrame) })
		end
	end
	sets[marker] = { body = body, parts = parts, surfaces = surfaces,
		spins = spins, key = key }
end

function ArcadeAnimator.start()
	if started or not RunService:IsClient() then return end
	started = true
	for _, marker in ipairs(CollectionService:GetTagged(TAG)) do track(marker) end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(marker)
		-- The marker is the last child added when a skin is dressed.
		task.defer(track, marker)
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(marker) sets[marker] = nil end)
	RunService.Heartbeat:Connect(function()
		local camera = workspace.CurrentCamera
		local t = workspace:GetServerTimeNow() % 6
		local now = workspace:GetServerTimeNow()
		local index = math.floor(t * 12) + 1
		local alpha = t * 12 - math.floor(t * 12)
		for marker, set in pairs(sets) do
			local body = set.body
			if not marker.Parent or not body.Parent then sets[marker] = nil; continue end
			-- Carried pigs retain their welded pose. Anchored lawn and display
			-- pigs animate locally without physics or per-frame replication.
			if not body.Anchored then continue end
			if camera and body:IsDescendantOf(workspace)
				and (camera.CFrame.Position - body.Position).Magnitude > 260 then continue end
			local scale = body.Size.X / 12
			for _, entry in ipairs(set.parts) do
				local p = entry.part
				if not p.Parent then continue end
				local a, b = entry.poses[index], entry.poses[index + 1]
				local pose = a.cf:Lerp(b.cf, alpha)
				local size = entry.size * a.scale:Lerp(b.scale, alpha) * scale
				p.Size = Vector3.new(math.max(0.001, size.X), math.max(0.001, size.Y), math.max(0.001, size.Z))
				p.CFrame = body.CFrame * CFrame.new(pose.Position * scale) * pose.Rotation
			end
			-- A CONTINUOUS CLOCK, NEVER THE SIX-SECOND ONE ABOVE: the pose
			-- index wraps at 6s, and a spin read off that jumps every wrap
			-- unless its rate divides into it. Taking the fraction of a turn
			-- keeps the angle bounded without ever discarding one.
			for _, e in ipairs(set.spins) do
				local p = e.part
				if p.Parent then
					p.CFrame = body.CFrame * CFrame.new(e.rest.Position)
						* CFrame.Angles(0, (now * e.rate % 1) * math.pi * 2, 0)
						* e.rest.Rotation
				end
			end

			local pulse = if set.key == "aurora" or set.key == "neonmint"
				then 1.015 - .155 * math.cos(t * math.pi * 2 / 3)
				else 0.88 + 0.12 * math.cos(t * math.pi / 3)
			for _, entry in ipairs(set.surfaces) do
				if entry.surface.Parent then entry.surface.EmissiveStrength = entry.strength * pulse end
			end
		end
	end)
end

return ArcadeAnimator
