--!strict
--[[
	GadgetFX

	What a gadget LEAVES BEHIND: bubblegum stuck to a person, a bubblegum
	puddle on the floor, the sparks on somebody who has been zapped, and the
	arc the zapper fires.

	The first three are built by the SERVER, because they are facts about the
	street everybody has to see at once and none of them moves on its own --
	a welded part and a static part replicate once and cost nothing after.
	The arc is built by each CLIENT, because it flickers every few frames for
	a quarter of a second, and a server doing that would be a replicated
	write per segment per frame to draw something every machine can derive
	from two points.

	EVERYTHING HERE IS CanCollide, CanQuery AND CanTouch FALSE and casts no
	shadow, for the rule every lawn ornament follows: an effect may never
	body-block a chase or answer a raycast meant for a person. A puddle's
	slow is decided by GadgetService measuring distance, never by `Touched`
	-- this file already records what `Touched` does repeated.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GadgetModel = require(ReplicatedStorage.Shared.GadgetModel)

local GadgetFX = {}

local function part(name: string, parent: Instance, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A player's torso, or a neighbour's shirt: residents are built from the
-- drip statue, whose body is the part called `Tee`.
local function torsoOf(character: Model): BasePart?
	return (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
		or character:FindFirstChild("HumanoidRootPart")
		or character:FindFirstChild("Tee", true)) :: BasePart?
end

local function weld(p: BasePart, to: BasePart)
	p.Anchored = false
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = p
	w.Parent = p
end

-- ============================================================
-- GUM BLOBS
-- ============================================================

-- A GOB IS A FLATTENED ELLIPSOID, and a Ball part cannot be one: a Ball
-- ignores non-uniform Size (measured, see CLAUDE.md). A SpecialMesh sphere
-- on a unit part takes any Scale, so a gob can be wide and paper thin --
-- which is what makes it read as goo stuck ON something rather than a
-- marble resting against it. Local Y is the thin axis, so a caller hands in
-- a frame whose UpVector is the surface normal.
local function gob(name: string, parent: Instance, cf: CFrame, w: number, t: number, d: number, colour: Color3): Part
	local p = part(name, parent, Vector3.one, cf, colour)
	p.Reflectance = 0.08
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(w, t, d)
	mesh.Parent = p
	return p
end

-- A frame at `pos` whose UpVector is `normal`, turned by `yaw` about it.
local function onSurface(pos: Vector3, normal: Vector3, yaw: number): CFrame
	local n = normal.Unit
	local ref = if math.abs(n.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
	local right = ref:Cross(n).Unit
	return CFrame.fromMatrix(pos, right, n) * CFrame.Angles(0, yaw, 0)
end

-- Pops every gob in `model` in from nothing, and fades them all out over the
-- last `FADE` seconds of `seconds`, then removes the model. The goo is there
-- exactly as long as what it is doing to you.
local FADE = 0.6
local function popAndFade(model: Instance, seconds: number)
	local TweenService = game:GetService("TweenService")
	local popInfo = TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("SpecialMesh") then
			local mesh = p :: SpecialMesh
			local full = mesh.Scale
			mesh.Scale = full * 0.2
			TweenService:Create(mesh, popInfo, { Scale = full }):Play()
		end
	end
	task.delay(math.max(0, seconds - FADE), function()
		if not model.Parent then
			return
		end
		local info = TweenInfo.new(FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				TweenService:Create(p, info, { Transparency = 1 }):Play()
			end
		end
		task.wait(FADE)
		if model.Parent then
			model:Destroy()
		end
	end)
end

-- ============================================================
-- BUBBLEGUM ON A PERSON
-- ============================================================

-- The body parts a splatter covers. Accessories are skipped -- their shapes
-- are the player's and a gob on a hat brim floats -- and so is anything
-- invisible (the root, a resident's hidden helper parts).
local function bodyParts(character: Model, feetOnly: boolean): { BasePart }
	local out: { BasePart } = {}
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" and d.Transparency < 0.9
			and not d:FindFirstAncestorOfClass("Accessory")
			and d.Parent and d.Parent.Name ~= "GumSplat" then
			local low = d.Name:find("Foot") or d.Name:find("LowerLeg") or d.Name:find("Leg")
			if not feetOnly or low then
				table.insert(out, d)
			end
		end
	end
	-- Biggest first, so a cap on the count spends it on the torso and the
	-- limbs rather than on a resident's buttons.
	table.sort(out, function(a, b)
		return a.Size.X * a.Size.Y * a.Size.Z > b.Size.X * b.Size.Y * b.Size.Z
	end)
	return out
end

-- GOO ALL OVER THEM: gobs on the faces of every body part, a couple of drips
-- hanging off the sides, welded so they ride along, for `seconds`, then
-- faded. `feetOnly` is the puddle's version -- you stepped in it, so it is on
-- your shoes and shins.
--
-- It works off the character's own parts rather than a shell, because a
-- character's shape is the player's avatar and nothing here can know it:
-- a gob seated on each face of each part is on the avatar whatever it is.
local MAX_GOBS = 80
function GadgetFX.gumOnPerson(character: Model, seconds: number, feetOnly: boolean?)
	local parts = bodyParts(character, feetOnly == true)
	if #parts == 0 then
		return
	end
	local old = character:FindFirstChild("GumSplat")
	if old then
		old:Destroy()
	end
	local spec = Config.GADGETS.gum
	local model = Instance.new("Model")
	model.Name = "GumSplat"
	model.Parent = character

	-- The six faces, as (local axis, sign). The bottom face is left out: goo
	-- under a foot is inside the floor.
	local faces = {
		{ "X", 1 }, { "X", -1 }, { "Z", 1 }, { "Z", -1 }, { "Y", 1 },
	}
	local count = 0
	for _, bp in ipairs(parts) do
		if count >= MAX_GOBS then
			break
		end
		local size = bp.Size
		local area = size.X * size.Y + size.Y * size.Z + size.X * size.Z
		local n = math.clamp(math.floor(area / 0.8), 3, 8)
		for _ = 1, n do
			if count >= MAX_GOBS then
				break
			end
			local face = faces[math.random(#faces)]
			local axis, sign = face[1], face[2]
			local localNormal = Vector3.new(
				if axis == "X" then sign else 0,
				if axis == "Y" then sign else 0,
				if axis == "Z" then sign else 0)
			-- A random spot on that face, kept off its very edge.
			local function along(extent: number): number
				return (math.random() - 0.5) * extent * 0.8
			end
			local offset = Vector3.new(
				if axis == "X" then sign * size.X / 2 else along(size.X),
				if axis == "Y" then sign * size.Y / 2 else along(size.Y),
				if axis == "Z" then sign * size.Z / 2 else along(size.Z))
			local worldNormal = bp.CFrame:VectorToWorldSpace(localNormal)
			local worldPos = bp.CFrame:PointToWorldSpace(offset)
			-- Sized to the part it sits on, so a finger does not wear a pancake.
			local faceSpan = math.min(
				if axis == "X" then size.Z else size.X,
				if axis == "Y" then size.Z else size.Y)
			local w = math.clamp(faceSpan * (0.8 + math.random() * 0.5), 0.45, 1.9)
			local colour = if math.random() < 0.35 then spec.trim else spec.colour
			local g = gob("Gum", model, onSurface(worldPos, worldNormal, math.random() * math.pi),
				w, w * 0.32, w * (0.7 + math.random() * 0.4), colour)
			weld(g, bp)
			count += 1

			-- A DRIP off a side face: a long thin gob hanging down from the
			-- splat, which is what reads as sticky rather than as spots.
			if axis ~= "Y" and math.random() < 0.45 and count < MAX_GOBS then
				local len = w * (0.8 + math.random() * 0.6)
				local dripPos = worldPos + Vector3.new(0, -len * 0.45, 0) + worldNormal * 0.02
				-- RightVector across the face and UpVector the normal leaves
				-- LookVector vertical, so the gob's long Z axis hangs down.
				local across = worldNormal:Cross(Vector3.yAxis)
				across = if across.Magnitude > 1e-3 then across.Unit else Vector3.xAxis
				local drip = gob("Drip", model, CFrame.fromMatrix(dripPos, across, worldNormal),
					w * 0.28, w * 0.2, len, spec.colour)
				weld(drip, bp)
				count += 1
			end
		end
	end
	popAndFade(model, seconds)
end

-- ============================================================
-- A BUBBLEGUM SPLAT ON THE WORLD
-- ============================================================

-- THE TOP OF WHATEVER IS STANDING AT (x, z), near `nearY`.
--
-- WHY NOT A RAYCAST: the driveways, the kerbs and nearly all the street's
-- scenery are `CanQuery` false -- deliberately, so they never eat a query
-- meant for a person -- and EVERY spatial query in the engine skips those.
-- So the landing ray passes through a driveway and hits the ground half a
-- stud below it, and a puddle placed there is drawn UNDER the paving. There
-- is no query that can see them, so this walks candidate parts by hand:
-- flat-topped, visible, wide enough to stand on, and no more than `climb`
-- above the hit (so a splat does not jump onto an ornament).
type Floor = { cf: CFrame, half: Vector2, upAxis: string, top: number }
local function floorsNear(at: Vector3, reach: number, climb: number): { Floor }
	local found: { Floor } = {}
	local characters = {}
	for _, pl in ipairs(game:GetService("Players"):GetPlayers()) do
		if pl.Character then
			characters[pl.Character] = true
		end
	end
	for _, d in ipairs(workspace:GetDescendants()) do
		local owner = d.Parent
		if d:IsA("Part") and d.Transparency < 0.9 and owner
			and owner.Name ~= "GumPuddle" and owner.Name ~= "GumSplat" and owner.Name ~= "ThrownGadget"
			and owner.Name ~= "StuckPlunger" then
			local cf, size = d.CFrame, d.Size
			-- Which local axis points up, if any: a part lying at an angle has
			-- no flat top to lie on.
			local upAxis, half = nil, 0
			if math.abs(cf.UpVector.Y) > 0.98 then
				upAxis, half = "Y", size.Y / 2
			elseif math.abs(cf.RightVector.Y) > 0.98 then
				upAxis, half = "X", size.X / 2
			elseif math.abs(cf.LookVector.Y) > 0.98 then
				upAxis, half = "Z", size.Z / 2
			end
			if upAxis then
				local top = cf.Position.Y + half
				local a = if upAxis == "X" then size.Y else size.X
				local b = if upAxis == "Z" then size.Y else size.Z
				if top >= at.Y - 0.3 and top <= at.Y + climb and math.min(a, b) >= 0.8
					and math.abs(cf.Position.X - at.X) <= reach + math.max(a, b)
					and math.abs(cf.Position.Z - at.Z) <= reach + math.max(a, b) then
					local model = d:FindFirstAncestorOfClass("Model")
					if not (model and characters[model]) then
						table.insert(found, { cf = cf, half = Vector2.new(a / 2, b / 2), upAxis = upAxis, top = top })
					end
				end
			end
		end
	end
	return found
end

local function topAt(floors: { Floor }, x: number, z: number, fallback: number): number
	local best = fallback
	for _, f in ipairs(floors) do
		local l = f.cf:PointToObjectSpace(Vector3.new(x, f.top, z))
		local u, v
		if f.upAxis == "Y" then
			u, v = l.X, l.Z
		elseif f.upAxis == "X" then
			u, v = l.Y, l.Z
		else
			u, v = l.X, l.Y
		end
		if math.abs(u) <= f.half.X and math.abs(v) <= f.half.Y and f.top > best then
			best = f.top
		end
	end
	return best
end

-- A SPLAT WHERE A GUM BOMB STOPPED, lying on the surface it hit.
--
-- On a FLOOR every gob is dropped onto the highest surface under its own
-- spot, so a splat that lands across a kerb or the edge of a driveway drapes
-- over it and is always the top layer. On a WALL (a normal that is mostly
-- sideways) it is spread across the wall with drips running down it.
--
-- Returns the model and the height the floor splat settled at, so the slow
-- zone is measured from the surface people are actually standing on.
function GadgetFX.splat(at: Vector3, normal: Vector3?, radius: number, seconds: number): (Model, number)
	local spec = Config.GADGETS.gum
	local n = if normal and normal.Magnitude > 1e-3 then normal.Unit else Vector3.yAxis
	local model = Instance.new("Model")
	model.Name = "GumPuddle"
	local floorY = at.Y
	local LIFT = 0.07 -- two faces at one depth flicker; always sit proud

	if n.Y >= 0.6 then
		-- FLOOR (or a gentle slope). One wide gob in the middle, a ring of
		-- overlapping ones round it, and a few splashes flung further out.
		local floors = if n.Y > 0.95 then floorsNear(at, radius + 1.5, 1.2) else {}
		local centreTop = topAt(floors, at.X, at.Z, at.Y)
		floorY = centreTop
		local function place(x: number, z: number, w: number, d: number, colour: Color3)
			local pos: Vector3
			local up = n
			if n.Y > 0.95 then
				pos = Vector3.new(x, topAt(floors, x, z, at.Y) + LIFT, z)
				up = Vector3.yAxis
			else
				-- On a slope: slide along the plane of the hit instead.
				local offset = Vector3.new(x - at.X, 0, z - at.Z)
				pos = at + offset - n * offset:Dot(n) + n * LIFT
			end
			-- Each gob a slightly different thickness, so two that overlap never
			-- put their domes at one depth.
			gob("Puddle", model, onSurface(pos, up, math.random() * math.pi), w, 0.13 + math.random() * 0.08, d, colour)
		end
		place(at.X, at.Z, radius * 1.1, radius * 0.95, spec.colour)
		local ring = 9
		for i = 1, ring do
			local a = (i / ring) * math.pi * 2 + math.random() * 0.5
			local r = radius * (0.45 + math.random() * 0.3)
			local s = radius * (0.45 + math.random() * 0.3)
			place(at.X + math.cos(a) * r, at.Z + math.sin(a) * r, s, s * (0.6 + math.random() * 0.4),
				if i % 3 == 0 then spec.trim else spec.colour)
		end
		for _ = 1, 5 do
			local a = math.random() * math.pi * 2
			local r = radius * (0.95 + math.random() * 0.35)
			local s = 0.35 + math.random() * 0.45
			place(at.X + math.cos(a) * r, at.Z + math.sin(a) * r, s, s, spec.colour)
		end
		-- A few raised lumps so it reads as sticky rather than as paint.
		for i = 1, 5 do
			local a = math.random() * math.pi * 2
			local r = radius * math.random() * 0.6
			local x, z = at.X + math.cos(a) * r, at.Z + math.sin(a) * r
			local base = if n.Y > 0.95 then topAt(floors, x, z, at.Y) else at.Y
			local s = 0.5 + math.random() * 0.6
			gob("Lump", model, CFrame.new(x, base + LIFT + 0.08, z), s, s * 0.55, s,
				if i % 2 == 0 then spec.trim else spec.colour)
		end
	else
		-- WALL. Gobs spread across the wall's plane, then drips running down
		-- it. Smaller than a floor splat: a bomb hitting a wall flattens, it
		-- does not pool.
		-- "Down the wall" is gravity with the normal taken out. Under a
		-- ceiling there is no such direction, so any in-plane axis will do.
		local down = Vector3.new(0, -1, 0) + n * n.Y
		if down.Magnitude < 0.2 then
			down = onSurface(at, n, 0).LookVector
		end
		down = down.Unit
		local right = n:Cross(down).Unit
		local wallRadius = radius * 0.6
		local function wallGob(pos: Vector3, w: number, d: number, colour: Color3, name: string)
			gob(name, model, CFrame.fromMatrix(pos, right, n) * CFrame.Angles(0, math.random() * math.pi, 0),
				w, 0.15 + math.random() * 0.08, d, colour)
		end
		wallGob(at + n * LIFT, wallRadius * 1.2, wallRadius, spec.colour, "Gum")
		for i = 1, 8 do
			local a = (i / 8) * math.pi * 2 + math.random() * 0.5
			local r = wallRadius * (0.45 + math.random() * 0.35)
			local s = wallRadius * (0.4 + math.random() * 0.35)
			wallGob(at + n * LIFT + right * math.cos(a) * r + down * math.sin(a) * r,
				s, s * 0.8, if i % 3 == 0 then spec.trim else spec.colour, "Gum")
		end
		for _ = 1, 4 do
			local x = (math.random() - 0.5) * wallRadius * 1.4
			local len = 0.9 + math.random() * 1.6
			local pos = at + n * (LIFT + 0.02) + right * x + down * (wallRadius * 0.5 + len * 0.5)
			-- Long axis (local Z) down the wall.
			gob("Drip", model, CFrame.fromMatrix(pos, right, n), 0.3, 0.16, len, spec.colour)
		end
	end

	model.Parent = workspace
	popAndFade(model, seconds)
	return model, floorY
end

-- ============================================================
-- A PLUNGER STUCK WHERE IT HIT
-- ============================================================

-- How far down the model's -Y the cup's rim is (GadgetModel's `Lip`, centred
-- at -1.15 and 0.4 thick). The flight carries -Y along the direction of
-- travel, so a plunger whose pivot sits this far back from the contact
-- point has its rim ON the contact point.
local PLUNGER_RIM = 1.35

-- THE PLUNGER STAYS WHERE IT LANDED for `seconds` -- the length of what it
-- is doing to whoever it hit -- then fades. `dir` is the way the cup points
-- (into the surface). `attachTo` is a character: the plunger is welded to
-- its torso and rides along through the knockdown.
function GadgetFX.stickPlunger(at: Vector3, dir: Vector3, seconds: number, attachTo: Model?)
	if dir.Magnitude < 1e-3 then
		return
	end
	local d = dir.Unit
	local torso = if attachTo then torsoOf(attachTo) else nil
	local contact = at
	if torso then
		-- On the torso's surface on the side it came from, not wherever the
		-- flight happened to be when it was within reach.
		local reach = math.min(torso.Size.X, torso.Size.Z) / 2
		contact = torso.Position - d * reach
	end
	local model = GadgetModel.build("plunger", false)
	model.Name = "StuckPlunger"
	-- Same frame the flight uses: lookAt puts -Z on `d`, the quarter turn
	-- about X carries -Y (the cup) onto it. A little random roll so two
	-- plungers side by side are not identical.
	local frame = CFrame.lookAt(contact - d * PLUNGER_RIM, contact)
		* CFrame.Angles(math.pi / 2, 0, 0)
		* CFrame.Angles(0, math.random() * math.pi * 2, 0)
	model:PivotTo(frame)
	if torso then
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Massless = true
				weld(p, torso)
			end
		end
		model.Parent = attachTo
	else
		model.Parent = workspace
	end
	-- A little wobble on arrival, the thing a stuck plunger does, then still.
	-- Only on the world: a welded one is moved by its weld, not by us.
	if not torso then
		task.spawn(function()
			local t0 = os.clock()
			while model.Parent and os.clock() - t0 < 0.5 do
				local k = os.clock() - t0
				local wob = math.sin(k * 40) * 0.22 * (1 - k / 0.5)
				-- Rocked about the rim, which stays on the contact point.
				model:PivotTo(frame * CFrame.new(0, -PLUNGER_RIM, 0)
					* CFrame.Angles(wob, 0, 0) * CFrame.new(0, PLUNGER_RIM, 0))
				task.wait()
			end
			if model.Parent then
				model:PivotTo(frame)
			end
		end)
	end
	-- `popAndFade` pops SpecialMeshes and fades parts; the plunger has no
	-- meshes, so it only fades.
	popAndFade(model, seconds)
end

-- ============================================================
-- SPARKS ON A ZAPPED PERSON
-- ============================================================

function GadgetFX.zapOnPerson(character: Model, seconds: number)
	local torso = torsoOf(character)
	if not torso then
		return
	end
	local old = torso:FindFirstChild("ZapFX")
	if old then
		old:Destroy()
	end
	local spec = Config.GADGETS.zapper
	local holder = Instance.new("Attachment")
	holder.Name = "ZapFX"
	holder.Parent = torso

	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(spec.trim, Color3.new(1, 1, 1))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	sparks.Lifetime = NumberRange.new(0.15, 0.35)
	sparks.Rate = 40
	sparks.Speed = NumberRange.new(4, 9)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Parent = holder

	local light = Instance.new("PointLight")
	light.Color = spec.trim
	light.Range = 8
	light.Brightness = 1.2
	light.Parent = holder

	-- A flicker, well under the three-flashes-a-second ceiling this game
	-- holds every light to: a slow pulse, not a strobe.
	task.spawn(function()
		local t0 = os.clock()
		while holder.Parent and os.clock() - t0 < seconds do
			light.Brightness = 0.8 + 0.6 * math.abs(math.sin((os.clock() - t0) * math.pi * 2.4))
			task.wait(0.05)
		end
		if holder.Parent then
			holder:Destroy()
		end
	end)
end

-- ============================================================
-- THE ARC (client)
-- ============================================================

-- A jagged line of neon segments from `from` to `to`, re-jagged a few times
-- over `seconds` so it crackles, then gone. `parent` is a client folder.
function GadgetFX.arc(parent: Instance, from: Vector3, to: Vector3, seconds: number)
	local spec = Config.GADGETS.zapper
	local SEGMENTS = 7
	local parts: { Part } = {}
	for i = 1, SEGMENTS do
		parts[i] = part("Arc", parent, Vector3.new(0.16, 0.16, 1), CFrame.new(from), spec.trim, Enum.Material.Neon)
	end
	local glow = part("ArcCore", parent, Vector3.new(0.06, 0.06, 1), CFrame.new(from), Color3.new(1, 1, 1), Enum.Material.Neon)

	local span = to - from
	local length = span.Magnitude
	if length < 0.1 then
		for _, p in ipairs(parts) do
			p:Destroy()
		end
		glow:Destroy()
		return
	end
	local dir = span.Unit
	local side = dir:Cross(Vector3.yAxis)
	if side.Magnitude < 1e-3 then
		side = Vector3.xAxis
	end
	side = side.Unit
	local up = side:Cross(dir).Unit

	local function jag()
		local points = { from }
		for i = 1, SEGMENTS - 1 do
			local f = i / SEGMENTS
			local wobble = math.min(1.2, length * 0.08)
			table.insert(points, from + span * f
				+ side * (math.random() * 2 - 1) * wobble
				+ up * (math.random() * 2 - 1) * wobble)
		end
		table.insert(points, to)
		for i = 1, SEGMENTS do
			local a, b = points[i], points[i + 1]
			local seg = b - a
			local p = parts[i]
			p.Size = Vector3.new(0.16, 0.16, seg.Magnitude)
			p.CFrame = CFrame.lookAt(a + seg / 2, b)
		end
		glow.Size = Vector3.new(0.06, 0.06, length)
		glow.CFrame = CFrame.lookAt(from + span / 2, to)
	end

	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < seconds do
			jag()
			task.wait(0.05)
		end
		for _, p in ipairs(parts) do
			p:Destroy()
		end
		glow:Destroy()
	end)
end

return GadgetFX
