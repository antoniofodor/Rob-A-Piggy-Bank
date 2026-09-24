--!strict
--[[
	Lasso -- the world half of catching a wild piggy (docs/LASSO-PLAN.md
	section 1). Lock-on, the throw, the rope, the TAP bar, the snap, the daze
	stars and every character's lasso pose.

	ITS OWN LOCALSCRIPT, NOT A SECTION OF `ClientMain`, because that chunk is
	against Luau's 200-local ceiling and a failure there costs the whole HUD.
	This needs nothing from it and lends it nothing: ClientMain's held-item
	click path ignores a lasso, and this file owns that click instead.

	EVERYBODY SEES EVERY ROPE; ONLY THE THROWER GETS CONTROLS. The server
	broadcasts `LassoState` and every client draws the rope from it, the same
	shape as the crack and the dodge: a catch is the one moment on the street
	somebody is guaranteed to be watching.

	THE CLICK NAMES A PIGGY AND NOTHING ELSE. The lock-on picks it, the
	server re-checks everything about whether it may be thrown at, and a
	refusal is the server's to say out loud.

	NOTHING HERE WRITES TO A PIGGY. Wild piggies are anchored and posed by
	the server every frame, so a client-side wriggle would fight it; the
	loop jiggles instead. Every part this file makes lives in one local
	folder or in the TAP gui, and every path out -- a caught, a snap, a
	thrower leaving, a lost final message -- ends in `destroyRope`.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local HeldItem = require(Shared:WaitForChild("HeldItem"))
local LassoModel = require(Shared:WaitForChild("LassoModel"))
local Theme = require(Shared:WaitForChild("Theme"))

local player = Players.LocalPlayer
local LASSO = Config.LASSO

-- A touch is a throw only if it lands near where it went down; every camera
-- swing on a tablet begins exactly like a tap. Same twelve pixels
-- `ClientMain` uses for every other held item.
local TAP_SLOP = 12
-- How long a snapped end tumbles, and how long a caught loop takes to cinch.
-- The staged break (see `snapEnds`): the rope strains this long before it
-- parts, matching the strain beat at the top of `lassoSnap`'s pose; the pieces
-- then lie about this long, fading only over the last `SNAP_FADE`.
local SNAP_BREAK_AT = 0.4
local SNAP_SECONDS = 2.4
local SNAP_FADE = 0.8
-- How long `lassoSnap` runs. Until then the twirl and the spinning loop are
-- held back for that thrower, or the twirl (one lasso track at a time) would
-- replace the stumble the moment the rope was torn down.
local SNAP_POSE_SECONDS = 1.4
local snapUntil: { [number]: number } = {}
-- How much of the whip-crack recording plays: the first crack, not the run.
local LASSO_SNAP_SECONDS = 0.55
local CINCH_SECONDS = 0.3
-- A rope whose final message never arrived is cleared this long after the
-- phase it was in should have ended, so a lost packet cannot leak parts.
local STALE_GRACE = 4
local TAP_ACTION = "LassoTapKey"

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

-- ============================================================
-- LASSOPOSE, LOADED LAZILY AND NEVER TRUSTED
-- ============================================================
--
-- Pcalled on every call: a missing module or a pose that throws costs the
-- animation and never the rope. Retried every few seconds in case it lands
-- after this script starts.

local Pose: any = nil
local poseTriedAt = -math.huge

local function pose(): any
	if Pose then
		return Pose
	end
	if os.clock() - poseTriedAt < 5 then
		return nil
	end
	poseTriedAt = os.clock()
	local module = Shared:FindFirstChild("LassoPose")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok and type(result) == "table" then
			Pose = result
		else
			warn("[Lasso] LassoPose failed to load: " .. tostring(result))
		end
	end
	return Pose
end

local function animatorOf(character: Model?): Animator?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid:FindFirstChildOfClass("Animator") or nil
end

local function posePlay(character: Model?, key: string, opts: any?): AnimationTrack?
	local P = pose()
	local animator = animatorOf(character)
	if not (P and animator and P.play) then
		return nil
	end
	local ok, track = pcall(P.play, animator, key, opts)
	return if ok then track else nil
end

local function poseStop(character: Model?, key: string, fade: number?)
	local P = pose()
	local animator = animatorOf(character)
	if P and animator and P.stop then
		pcall(P.stop, animator, key, fade)
	end
end

local function poseSpeed(character: Model?, key: string, speed: number)
	local P = pose()
	local animator = animatorOf(character)
	if P and animator and P.setSpeed then
		pcall(P.setSpeed, animator, key, speed)
	end
end

local function releaseTime(): number
	local P = pose()
	if P and P.releaseTime then
		local ok, t = pcall(P.releaseTime)
		if ok and type(t) == "number" then
			return t
		end
	end
	return 0.15
end

-- ============================================================
-- WHERE THINGS ARE
-- ============================================================

local fxFolder = Instance.new("Folder")
fxFolder.Name = "LassoFX"
fxFolder.Parent = Workspace

local function characterOf(userId: number): Model?
	local p = Players:GetPlayerByUserId(userId)
	return p and p.Character or nil
end

local function rootOf(character: Model?): BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function bodyOf(model: Model): BasePart?
	local p = model.PrimaryPart or model:FindFirstChild("Body")
	return if p and p:IsA("BasePart") then p else nil
end

-- Wild piggies live in `workspace.Herds`, one Model each (HerdService).
local function herdModels(): { Instance }
	local folder = Workspace:FindFirstChild("Herds")
	return if folder then folder:GetChildren() else {}
end

local function targetIdOf(model: Instance): string?
	local id = model:GetAttribute(Config.LASSO_TARGET_ATTRIBUTE)
	if id == nil or id == "" then
		return nil
	end
	return tostring(id)
end

local function findTarget(id: string): Model?
	for _, child in ipairs(herdModels()) do
		if child:IsA("Model") and targetIdOf(child) == id then
			return child
		end
	end
	return nil
end

local function truthy(v: any): boolean
	return v ~= nil and v ~= false and v ~= 0 and v ~= ""
end

local function heldLasso(character: Model?): string?
	local key = character and character:GetAttribute(HeldItem.ATTRIBUTE)
	if type(key) == "string" and HeldItem.kindOf(key) == "lasso" then
		return key
	end
	return nil
end

-- A model's parts at scale 1 relative to its pivot, so it can be scaled and
-- moved every frame without reading anything back.
type PartRec = { part: BasePart, rel: CFrame, size: Vector3, alpha: number }

local function recordParts(model: Model): { PartRec }
	local pivot = model:GetPivot()
	local out = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(out, { part = d, rel = pivot:ToObjectSpace(d.CFrame), size = d.Size, alpha = d.Transparency })
		end
	end
	return out
end

local function placeParts(recs: { PartRec }, origin: CFrame, s: number, resize: boolean)
	for _, r in ipairs(recs) do
		if resize then
			r.part.Size = r.size * s
		end
		r.part.CFrame = origin * CFrame.new(r.rel.Position * s) * r.rel.Rotation
	end
end

local function fadeParts(recs: { PartRec }, f: number)
	for _, r in ipairs(recs) do
		r.part.Transparency = r.alpha + (1 - r.alpha) * math.clamp(f, 0, 1)
	end
end

-- ============================================================
-- THE ROPES
-- ============================================================

type Rope = {
	id: string,
	thrower: number,
	key: string,
	phase: string,
	startedAt: number,
	endsAt: number,
	target: Model?,
	loop: Model?,
	loopRecs: { PartRec },
	loopScale: number,
	endPart: BasePart?,
	endAtt: Attachment?,
	handAtt: Attachment?,
	beam: Beam?,
	lastCentre: Vector3?,
	lastFacing: Vector3?,
	lastExit: Vector3?,
	fit: number,
	ending: string?,
	endingAt: number,
	taps: number,
	tapTimes: { number },
	speedAt: number,
	lookupAt: number,
	bornAt: number,
}

local ropes: { [string]: Rope } = {}

-- Short-lived effects outliving their rope: the tumbling snapped ends.
type Effect = (dt: number) -> boolean
local effects: { Effect } = {}

local function busyThrower(userId: number): boolean
	for _, rope in pairs(ropes) do
		if rope.thrower == userId and not rope.ending
			and (rope.phase == "flight" or rope.phase == "struggle") then
			return true
		end
	end
	return false
end

local function ownRope(): Rope?
	for _, rope in pairs(ropes) do
		if rope.thrower == player.UserId and not rope.ending
			and (rope.phase == "flight" or rope.phase == "struggle") then
			return rope
		end
	end
	return nil
end

local function handOf(character: Model?): BasePart?
	local hand = character and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm"))
	return if hand and hand:IsA("BasePart") then hand else nil
end

local function ensureHand(rope: Rope): Attachment?
	if rope.handAtt and rope.handAtt.Parent then
		return rope.handAtt
	end
	local hand = handOf(characterOf(rope.thrower)) or rootOf(characterOf(rope.thrower))
	if not hand then
		return nil
	end
	local att = Instance.new("Attachment")
	att.Name = "LassoRopeHand"
	att.Position = Vector3.new(0, -0.25, 0)
	att.Parent = hand
	rope.handAtt = att
	if rope.beam then
		rope.beam.Attachment0 = att
	end
	return att
end

local function buildVisuals(rope: Rope)
	if rope.loop then
		return
	end
	local colour = LassoModel.ropeColour(rope.key)

	local loop = LassoModel.buildLoop(rope.key)
	rope.loop = loop
	rope.loopRecs = recordParts(loop)
	rope.loopScale = 1
	-- Parked out of sight until the first frame seats it, or a thrower this
	-- client cannot see yet would leave a loop lying at the world origin.
	placeParts(rope.loopRecs, CFrame.new(0, -1000, 0), 1, false)
	loop.Parent = fxFolder

	local endPart = Instance.new("Part")
	endPart.Name = "LassoRopeEnd"
	endPart.Size = Vector3.new(0.1, 0.1, 0.1)
	endPart.Transparency = 1
	endPart.Anchored = true
	endPart.CanCollide = false
	endPart.CanQuery = false
	endPart.CanTouch = false
	endPart.CastShadow = false
	endPart.Parent = fxFolder
	local endAtt = Instance.new("Attachment")
	endAtt.Name = "RopeExit"
	endAtt.Parent = endPart
	rope.endPart = endPart
	rope.endAtt = endAtt

	-- A straight rope: a Beam's curve handles are in its attachments' own
	-- frames, and a hand's frame swings with every pose, so any curve here
	-- would whip about. Taut is also what a rope under a struggle is.
	local beam = Instance.new("Beam")
	beam.Name = "LassoRope"
	beam.Color = ColorSequence.new(colour)
	beam.Width0 = LassoModel.ROPE_WIDTH
	beam.Width1 = LassoModel.ROPE_WIDTH
	beam.FaceCamera = true
	beam.Segments = 2
	beam.LightInfluence = 1
	beam.Transparency = NumberSequence.new(0)
	beam.Attachment1 = endAtt
	beam.Parent = endPart
	rope.beam = beam
	ensureHand(rope)
end

local function destroyRope(rope: Rope)
	if rope.loop then
		rope.loop:Destroy()
	end
	if rope.endPart then
		rope.endPart:Destroy()
	end
	if rope.handAtt then
		rope.handAtt:Destroy()
	end
	rope.loop, rope.endPart, rope.endAtt, rope.beam, rope.handAtt = nil, nil, nil, nil, nil
	rope.loopRecs = {}
	ropes[rope.id] = nil
	-- The coil comes back into view once nothing is flying.
	local character = characterOf(rope.thrower)
	local prop = character and character:FindFirstChild(HeldItem.MODEL_NAME)
	if prop and not busyThrower(rope.thrower) then
		for _, d in ipairs(prop:GetDescendants()) do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 0
			end
		end
	end
end

-- How big the loop is once it has closed: the piggy's widest horizontal
-- extent plus clearance, over the loop's clear opening (assets/lassos loop
-- manifest). A piggy's body is roughly a sphere, so its middle is its girth.
local function fitFor(model: Model?): number
	local body = model and bodyOf(model)
	if not body then
		return 2
	end
	local girth = math.max(body.Size.X, body.Size.Z)
	local clearance = girth * 0.1 + 0.1
	return (girth + clearance * 2) / LassoModel.LOOP_INNER_DIAMETER
end

local function targetOf(rope: Rope): Model?
	local model = rope.target
	if model and model.Parent then
		return model
	end
	local now = os.clock()
	if now < rope.lookupAt then
		return nil
	end
	rope.lookupAt = now + 0.2
	rope.target = findTarget(rope.id)
	if rope.target then
		rope.fit = fitFor(rope.target)
	end
	return rope.target
end

local function seatLoop(rope: Rope, centre: Vector3, facing: Vector3, s: number, spin: number)
	local flat = Vector3.new(facing.X, 0, facing.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.xAxis
	end
	-- A quarter turn puts the loop's local +X -- the knot and RopeExit --
	-- along the flat direction to the thrower.
	local origin = CFrame.lookAt(centre, centre + flat) * CFrame.Angles(0, math.pi / 2 + spin, 0)
	placeParts(rope.loopRecs, origin, s, s ~= rope.loopScale)
	rope.loopScale = s
	local exit = origin * (LassoModel.LOOP_ROPE_EXIT * s)
	if rope.endPart then
		rope.endPart.CFrame = CFrame.new(exit)
	end
	rope.lastCentre, rope.lastFacing, rope.lastExit = centre, flat, exit
end

-- THE BREAK, STAGED (designer, 2026-09-23: "more dramatic and last longer so
-- the player can actually see it break"). It used to be two pieces fading out
-- in a second, started the instant the message arrived, which read as the
-- rope simply vanishing. Now it has three beats, timed to `lassoSnap`'s pose:
--
--   STRAIN, 0 to `SNAP_BREAK_AT`: the rope stays, pulled taut and SHUDDERING
--   harder and harder, flickering pale where it is about to part, while the
--   thrower leans back hardest.
--   SNAP: a "SNAP!" pops at the break, a burst of rope fibres flies out, the
--   two ends WHIP apart (the hand's end recoiling at the thrower) and the loop
--   jumps off the piggy.
--   FALL: the pieces tumble and lie there, and only fade over the last
--   `SNAP_FADE` of `SNAP_SECONDS`.
--
-- It TAKES OWNERSHIP of the rope's loop, knot and beam, so the rope itself can
-- be torn down at once and everything here lives in `effects`.
local function snapEnds(rope: Rope)
	local exit = rope.lastExit
	local centre = rope.lastCentre
	local att = rope.handAtt
	if not exit then
		return
	end
	local loop, loopRecs, loopScale = rope.loop, rope.loopRecs, rope.loopScale
	local endPart, beam = rope.endPart, rope.beam
	-- Take them so `destroyRope` leaves them alone; the hand attachment is
	-- borrowed for the strain and destroyed with the beam at the break.
	rope.loop, rope.endPart, rope.endAtt, rope.beam, rope.handAtt = nil, nil, nil, nil, nil
	rope.loopRecs = {}
	local colour = LassoModel.ropeColour(rope.key)
	local width = LassoModel.ROPE_WIDTH
	snapUntil[rope.thrower] = os.clock() + SNAP_POSE_SECONDS

	local age = 0
	local broken = false
	local loopPos: Vector3 = centre or exit
	local loopVel = Vector3.zero
	local loopSpin = 0
	local loopFacing = rope.lastFacing or Vector3.xAxis

	local function handPoint(): Vector3
		return if att and att.Parent then att.WorldPosition else exit + Vector3.new(0, 2, 0)
	end

	local function anchorAt(name: string, at: Vector3): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = Vector3.new(0.2, 0.2, 0.2)
		p.Transparency = 1
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.CFrame = CFrame.new(at)
		p.Parent = fxFolder
		return p
	end

	local function burst(at: Vector3, dir: Vector3)
		-- Fibres: a one-shot emit from a throwaway anchor, cleaned up once the
		-- last particle has had time to land.
		local anchor = anchorAt("LassoSnapBurst", at)
		local fibres = Instance.new("ParticleEmitter")
		fibres.Color = ColorSequence.new(colour)
		fibres.LightEmission = 0
		fibres.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0.08) })
		fibres.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		fibres.Lifetime = NumberRange.new(0.6, 1.1)
		fibres.Speed = NumberRange.new(9, 18)
		fibres.SpreadAngle = Vector2.new(180, 180)
		fibres.Acceleration = Vector3.new(0, -30, 0)
		fibres.Rotation = NumberRange.new(0, 360)
		fibres.RotSpeed = NumberRange.new(-400, 400)
		fibres.Rate = 0
		fibres.Parent = anchor
		fibres:Emit(28)

		-- The crack, from the break itself so it pans and falls off with
		-- distance like every other sound on the street. Stopped after the
		-- first crack; see `Config.SOUNDS.LASSO_SNAP`.
		local snapId = Config.SOUNDS and Config.SOUNDS.LASSO_SNAP
		if type(snapId) == "string" and snapId ~= "" then
			local sound = Instance.new("Sound")
			sound.SoundId = snapId
			sound.Volume = 0.7
			sound.RollOffMinDistance = 12
			sound.RollOffMaxDistance = 120
			sound.Parent = anchor
			sound:Play()
			task.delay(LASSO_SNAP_SECONDS, function()
				if sound.Parent then
					sound:Stop()
				end
			end)
		end
		task.delay(1.5, function()
			anchor:Destroy()
		end)

		-- The word, for a nine-year-old: a comic "SNAP!" that pops, tilts,
		-- floats up and fades.
		local holder = anchorAt("LassoSnapWordAnchor", at)
		local pop = Instance.new("BillboardGui")
		pop.Name = "LassoSnapWord"
		pop.Size = UDim2.fromOffset(170, 70)
		pop.StudsOffsetWorldSpace = Vector3.new(0, 1.2, 0)
		pop.AlwaysOnTop = true
		pop.LightInfluence = 0
		pop.MaxDistance = 140
		pop.Adornee = holder
		pop.Parent = holder
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.Size = UDim2.fromScale(0.2, 0.2)
		label.Font = Enum.Font.FredokaOne
		label.Text = "SNAP!"
		label.TextScaled = true
		label.TextColor3 = Theme.GOLD
		label.Rotation = -10
		label.Parent = pop
		local stroke = Instance.new("UIStroke")
		stroke.Color = Theme.INK
		stroke.Thickness = 3
		stroke.Parent = label
		TweenService:Create(label, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = UDim2.fromScale(1, 1), Rotation = 6 }):Play()
		TweenService:Create(pop, TweenInfo.new(1.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0) }):Play()
		task.delay(0.8, function()
			TweenService:Create(label, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
			TweenService:Create(stroke, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		end)
		task.delay(1.4, function()
			holder:Destroy()
		end)

		-- The two ends WHIP apart. The hand's piece (side 1, pointing along
		-- `dir`, which runs from the knot to the hand) recoils back at the
		-- thrower; the loop's piece is flung the other way. Both spin hard,
		-- fall, and lie there before they fade.
		for _, side in ipairs({ 1, -1 }) do
			local model = LassoModel.buildSnappedEnd(rope.key)
			local recs = recordParts(model)
			model.Parent = fxFolder
			local axis = dir * side
			local up = if math.abs(axis.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
			local pos = at - axis * 0.55
			local rot = CFrame.lookAt(Vector3.zero, axis, up) * CFrame.Angles(0, math.pi / 2, 0)
			local vel = axis * (if side == 1 then 13 else 8) + Vector3.new(0, 10, 0)
			local spinAxis = axis:Cross(Vector3.yAxis)
			if spinAxis.Magnitude < 1e-3 then
				spinAxis = Vector3.xAxis
			end
			spinAxis = spinAxis.Unit
			local t = 0
			local scale = 1.3
			local floorY = at.Y - 6
			placeParts(recs, CFrame.new(pos) * rot, scale, true)
			table.insert(effects, function(dt: number): boolean
				t += dt
				if t >= SNAP_SECONDS or model.Parent == nil then
					model:Destroy()
					return false
				end
				if pos.Y > floorY then
					vel += Vector3.new(0, -Workspace.Gravity * 0.22 * dt, 0)
					pos += vel * dt
				end
				local spinning = math.max(0, 1 - t / 1.2)
				local turn = CFrame.fromAxisAngle(spinAxis, t * 14 * side * spinning)
				placeParts(recs, CFrame.new(pos) * turn * rot, scale, false)
				fadeParts(recs, (t - (SNAP_SECONDS - SNAP_FADE)) / SNAP_FADE)
				return true
			end)
		end
	end

	table.insert(effects, function(dt: number): boolean
		age += dt
		if not broken then
			local strain = math.clamp(age / SNAP_BREAK_AT, 0, 1)
			local hand = handPoint()
			-- The shudder grows to a quarter of a stud at the knot, and the loop
			-- on the piggy jitters with it.
			local jitter = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * (0.5 * strain)
			if endPart and endPart.Parent then
				endPart.CFrame = CFrame.new(exit + jitter)
			end
			if beam and beam.Parent then
				local w = width * (1 + 0.8 * strain * math.abs(math.sin(age * 55)))
				beam.Width0, beam.Width1 = w, w
				local pale = colour:Lerp(Color3.new(1, 1, 1), strain * 0.6 * (0.5 + 0.5 * math.sin(age * 40)))
				beam.Color = ColorSequence.new(pale)
			end
			if loop and loop.Parent and centre then
				local flat = Vector3.new(loopFacing.X, 0, loopFacing.Z)
				if flat.Magnitude < 1e-3 then
					flat = Vector3.xAxis
				end
				local at = centre + jitter * 0.5
				local origin = CFrame.lookAt(at, at + flat) * CFrame.Angles(0, math.pi / 2, 0)
				placeParts(loopRecs, origin, loopScale, false)
			end
			if age >= SNAP_BREAK_AT then
				broken = true
				local run = hand - exit
				local dir = if run.Magnitude > 1e-3 then run.Unit else Vector3.xAxis
				if endPart then
					endPart:Destroy()
				end
				if att then
					att:Destroy()
				end
				burst(exit + run * 0.3, dir)
				-- The loop jumps off the piggy, away from the thrower.
				loopVel = -dir * 6 + Vector3.new(0, 12, 0)
			end
			return true
		end

		-- After the break: the loop tumbles and falls, then fades with the rest.
		local since = age - SNAP_BREAK_AT
		if not loop or loop.Parent == nil or since >= SNAP_SECONDS then
			if loop then
				loop:Destroy()
			end
			return false
		end
		if since < 1.2 then
			loopVel += Vector3.new(0, -Workspace.Gravity * 0.22 * dt, 0)
			loopPos += loopVel * dt
			loopSpin += dt * 8
		end
		local origin = CFrame.new(loopPos) * CFrame.Angles(loopSpin, loopSpin * 0.6, 0)
		placeParts(loopRecs, origin, loopScale, false)
		fadeParts(loopRecs, (since - (SNAP_SECONDS - SNAP_FADE)) / SNAP_FADE)
		return true
	end)
end

-- ============================================================
-- THE TAP BAR (the thrower only)
-- ============================================================

local tapUI: {
	gui: ScreenGui?,
	fill: Frame?,
	scale: UIScale?,
	bound: boolean,
	lastSent: number,
} = { gui = nil, fill = nil, scale = nil, bound = false, lastSent = -math.huge }

local function sendTap()
	local rope = ownRope()
	if not (rope and rope.phase == "struggle") then
		return
	end
	-- Rate-limited to what the server will count anyway, so the remote is
	-- never flooded and the bar never shows taps the roll will not.
	local now = os.clock()
	if now - tapUI.lastSent < 1 / LASSO.tapRate then
		return
	end
	tapUI.lastSent = now
	rope.taps += 1
	table.insert(rope.tapTimes, now)
	Remotes.get("LassoTap"):FireServer()
	local s = tapUI.scale
	if s then
		s.Scale = 1.08
		TweenService:Create(s, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Scale = 1 }):Play()
	end
end

local function buildTapUI(): ScreenGui
	if tapUI.gui then
		return tapUI.gui
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "LassoHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 20
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false

	-- Bottom centre, above the hot bar, and big enough for a thumb that is
	-- hammering it rather than aiming.
	local button = Instance.new("TextButton")
	button.Name = "TapButton"
	button.AnchorPoint = Vector2.new(0.5, 1)
	button.Position = UDim2.new(0.5, 0, 1, -92)
	button.Size = UDim2.fromOffset(210, 108)
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = gui
	Theme.card(button, 18)
	local scale = Instance.new("UIScale")
	scale.Parent = button
	tapUI.scale = scale

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 54)
	title.Position = UDim2.fromOffset(0, 6)
	title.Text = "TAP!"
	Theme.title(title, 46)
	title.Parent = button

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.Size = UDim2.new(1, -16, 0, 16)
	hint.Position = UDim2.fromOffset(8, 58)
	hint.Text = if UserInputService.KeyboardEnabled then "Tap, click or press Space" else "Tap fast!"
	Theme.body(hint, 13)
	hint.Parent = button

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0.5, 0)
	track.Position = UDim2.new(0.5, 0, 0, 80)
	track.Size = UDim2.new(1, -28, 0, 16)
	track.BackgroundColor3 = Theme.SAND_DEEP
	track.BorderSizePixel = 0
	Theme.corner(track, 8)
	Theme.outline(track, Theme.OUTLINE_THIN)
	track.Parent = button

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Theme.GOLD
	fill.BorderSizePixel = 0
	Theme.corner(fill, 8)
	fill.Parent = track
	tapUI.fill = fill

	-- A touch on the card is a tap. A mouse click anywhere already is one
	-- (see the input handler), so only touch is counted here -- counting
	-- both would put two taps on one press.
	button.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			sendTap()
		end
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
	tapUI.gui = gui
	return gui
end

local function showTapUI(rope: Rope?)
	local on = rope ~= nil and rope.phase == "struggle"
	if on then
		local gui = buildTapUI()
		gui.Enabled = true
		if tapUI.fill and rope then
			tapUI.fill.BackgroundColor3 = LassoModel.ropeColour(rope.key)
		end
		if not tapUI.bound then
			tapUI.bound = true
			-- Space (and a pad's A) are taps while you struggle, and SUNK so
			-- they do not also jump you off the spot you are pulling from.
			ContextActionService:BindActionAtPriority(TAP_ACTION, function(_, state)
				if state == Enum.UserInputState.Begin then
					sendTap()
				end
				return Enum.ContextActionResult.Sink
			end, false, 3000, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
		end
	else
		if tapUI.gui then
			tapUI.gui.Enabled = false
		end
		if tapUI.bound then
			tapUI.bound = false
			ContextActionService:UnbindAction(TAP_ACTION)
		end
	end
end

-- ============================================================
-- STATE FROM THE SERVER
-- ============================================================

local function setPhase(rope: Rope, phase: string, fresh: boolean)
	local character = characterOf(rope.thrower)
	local changed = fresh or rope.phase ~= phase
	rope.phase = phase
	if not changed then
		return
	end
	if phase == "flight" then
		poseStop(character, "lassoTwirl", 0.05)
		posePlay(character, "lassoThrow")
		buildVisuals(rope)
	elseif phase == "struggle" then
		poseStop(character, "lassoTwirl", 0.1)
		posePlay(character, "lassoPull")
		buildVisuals(rope)
	elseif phase == "caught" then
		-- STRAIGHT INTO THE CARRY, no fist pump (designer, 2026-09-23: a catch
		-- "should then look like a regular carry and the lasso is put away").
		-- Every lasso track stops so the hug underneath is what shows; the
		-- server has already put the coil away.
		poseStop(character, nil :: any, 0.15)
		rope.ending = "caught"
		rope.endingAt = os.clock()
	elseif phase == "snapped" then
		poseStop(character, "lassoPull", 0.1)
		posePlay(character, "lassoSnap")
		snapEnds(rope)
		destroyRope(rope)
	end
	if rope.thrower == player.UserId then
		showTapUI(ownRope())
	end
end

Remotes.get("LassoState").OnClientEvent:Connect(function(payload: any)
	if type(payload) ~= "table" or payload.id == nil then
		return
	end
	local id = tostring(payload.id)
	local phase = payload.phase
	if type(phase) ~= "string" then
		return
	end
	local rope = ropes[id]
	local fresh = false
	if not rope then
		-- A rope ending that this client never saw start has nothing to
		-- draw; the pose still plays.
		local thrower = tonumber(payload.thrower) or 0
		local key = if type(payload.key) == "string" then payload.key else "rope"
		rope = {
			id = id, thrower = thrower, key = key, phase = "", startedAt = 0, endsAt = 0,
			target = nil, loop = nil, loopRecs = {}, loopScale = 1, endPart = nil, endAtt = nil,
			handAtt = nil, beam = nil, lastCentre = nil, lastFacing = nil, lastExit = nil,
			fit = 2, ending = nil, endingAt = 0, taps = 0, tapTimes = {}, speedAt = 0, lookupAt = 0,
			bornAt = os.clock(),
		}
		ropes[id] = rope
		fresh = true
	end
	local r = rope :: Rope
	if type(payload.startedAt) == "number" then
		r.startedAt = payload.startedAt
	end
	if type(payload.endsAt) == "number" then
		r.endsAt = payload.endsAt
	end
	if fresh then
		r.target = findTarget(id)
		r.fit = fitFor(r.target)
	end
	setPhase(r, phase, fresh)
end)

Players.PlayerRemoving:Connect(function(leaving: Player)
	for _, rope in pairs(ropes) do
		if rope.thrower == leaving.UserId then
			destroyRope(rope)
		end
	end
	if leaving == player then
		showTapUI(nil)
	end
end)

-- ============================================================
-- LOCK-ON
-- ============================================================

local lock: { model: Model?, id: string?, highlight: Highlight? } = { model = nil, id = nil, highlight = nil }

local function setLock(model: Model?, id: string?, key: string?)
	lock.model, lock.id = model, id
	if not model then
		if lock.highlight then
			lock.highlight.Enabled = false
			lock.highlight.Adornee = nil
		end
		return
	end
	local h = lock.highlight
	if not h then
		local made = Instance.new("Highlight")
		made.Name = "LassoLock"
		made.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		made.FillTransparency = 0.72
		made.OutlineTransparency = 0
		made.Parent = fxFolder
		lock.highlight = made
		h = made
	end
	local hl = h :: Highlight
	local colour = LassoModel.ropeColour(key)
	hl.FillColor = colour
	hl.OutlineColor = colour
	hl.Adornee = model
	hl.Enabled = true
end

-- The landed piggy nearest the centre of the screen, in reach and inside
-- the cone. Only what the server will also accept: landed (it carries an
-- id), nobody's rope on it, and a dazed one only once it is open or when it
-- is yours. Nothing else about the throw is judged here.
local function pickLock(character: Model): (Model?, string?)
	local root = rootOf(character)
	local camera = Workspace.CurrentCamera
	if not (root and camera) then
		return nil, nil
	end
	local eye = camera.CFrame.Position
	local look = camera.CFrame.LookVector
	local minDot = math.cos(math.rad(LASSO.lockCone))
	local now = serverNow()
	local best: Model?, bestId: string?, bestDot = nil, nil, -2
	for _, child in ipairs(herdModels()) do
		if not child:IsA("Model") then
			continue
		end
		local id = targetIdOf(child)
		if not id or truthy(child:GetAttribute(Config.LASSO_BUSY_ATTRIBUTE)) then
			continue
		end
		local dazed = child:GetAttribute(Config.LASSO_DAZED_ATTRIBUTE)
		if truthy(dazed) and dazed ~= player.UserId then
			local openAt = child:GetAttribute(Config.LASSO_OPEN_AT_ATTRIBUTE)
			if type(openAt) ~= "number" or now < openAt then
				continue
			end
		end
		local body = bodyOf(child)
		if not body then
			continue
		end
		local at = body.Position
		if (at - root.Position).Magnitude > LASSO.range then
			continue
		end
		local toward = at - eye
		if toward.Magnitude < 1e-3 then
			continue
		end
		local dot = toward.Unit:Dot(look)
		if dot >= minDot and dot > bestDot then
			best, bestId, bestDot = child, id, dot
		end
	end
	return best, bestId
end

-- ============================================================
-- THROWING
-- ============================================================

local throwBlockedUntil = 0
local tapFrom: Vector2? = nil

local function hudBlocked(): boolean
	local hud = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("PiggyHUD")
	return hud ~= nil and hud:GetAttribute("BagOpen") == true
end

local function throw()
	if not (lock.id and heldLasso(player.Character)) or ownRope() or hudBlocked() then
		return
	end
	if os.clock() < throwBlockedUntil then
		return
	end
	-- A double click is one throw: the server refuses a second anyway, and
	-- saying so twice in a row reads as the lasso being broken.
	throwBlockedUntil = os.clock() + 0.5
	Remotes.get("LassoThrow"):FireServer(lock.id)
end

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	local mouse = input.UserInputType == Enum.UserInputType.MouseButton1
	if ownRope() then
		-- During your own struggle every click anywhere is a tap, over the HUD
		-- or not. Touches count on the card only.
		if mouse then
			sendTap()
		end
		return
	end
	if processed then
		return
	end
	if mouse then
		throw()
	elseif input.UserInputType == Enum.UserInputType.Touch then
		tapFrom = Vector2.new(input.Position.X, input.Position.Y)
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject, processed: boolean)
	if input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local from = tapFrom
	tapFrom = nil
	if processed or not from then
		return
	end
	if (Vector2.new(input.Position.X, input.Position.Y) - from).Magnitude <= TAP_SLOP then
		throw()
	end
end)

-- ============================================================
-- DAZED PIGGIES: STARS, AND THE PICK-UP IS THE CATCHER'S
-- ============================================================

type Dazed = {
	stars: { Model },
	catcher: number,
	prompts: { [ProximityPrompt]: boolean },
	conns: { RBXScriptConnection },
	age: number,
}

local dazed: { [Model]: Dazed } = {}

local function scaleModel(model: Model, s: number)
	local recs = recordParts(model)
	placeParts(recs, model:GetPivot(), s, true)
end

-- A client `Enabled` write only changes this machine's view, which is the
-- only per-player prompt Roblox offers; the server refuses anybody but the
-- catcher regardless. What the server last wanted is remembered so the
-- prompt is handed back in that state when the daze ends.
local function muzzle(state: Dazed, prompt: ProximityPrompt)
	if state.prompts[prompt] ~= nil then
		return
	end
	state.prompts[prompt] = prompt.Enabled
	prompt.Enabled = false
	table.insert(state.conns, prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
		if prompt.Enabled then
			state.prompts[prompt] = true
			prompt.Enabled = false
		end
	end))
end

local function undaze(model: Model)
	local state = dazed[model]
	if not state then
		return
	end
	dazed[model] = nil
	for _, c in ipairs(state.conns) do
		c:Disconnect()
	end
	for prompt, wanted in pairs(state.prompts) do
		if prompt.Parent then
			prompt.Enabled = wanted
		end
	end
	for _, star in ipairs(state.stars) do
		star:Destroy()
	end
end

local function refreshDazed(model: Model)
	local catcher = model:GetAttribute(Config.LASSO_DAZED_ATTRIBUTE)
	if not truthy(catcher) or model.Parent == nil then
		undaze(model)
		return
	end
	local existing = dazed[model]
	if existing then
		if existing.catcher == tonumber(catcher) then
			return
		end
		-- A different catcher: the prompt belongs to somebody else now.
		undaze(model)
	end
	local state: Dazed = { stars = {}, catcher = tonumber(catcher) or 0, prompts = {}, conns = {}, age = 0 }
	dazed[model] = state
	local body = bodyOf(model)
	local width = if body then math.max(body.Size.X, body.Size.Z) else 3
	local s = math.clamp(width * 0.22, 0.4, 1.1)
	for _ = 1, 4 do
		local star = LassoModel.buildStar()
		scaleModel(star, s)
		star.Parent = fxFolder
		table.insert(state.stars, star)
	end
	if state.catcher ~= player.UserId then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("ProximityPrompt") then
				muzzle(state, d)
			end
		end
		-- The prompt may replicate a frame after the attribute does.
		table.insert(state.conns, model.DescendantAdded:Connect(function(d: Instance)
			if d:IsA("ProximityPrompt") then
				muzzle(state, d)
			end
		end))
	end
end

local watchedHerd: { [Instance]: boolean } = {}

local function watchHerdModel(child: Instance)
	if not child:IsA("Model") or watchedHerd[child] then
		return
	end
	watchedHerd[child] = true
	local model = child :: Model
	model:GetAttributeChangedSignal(Config.LASSO_DAZED_ATTRIBUTE):Connect(function()
		refreshDazed(model)
	end)
	model.Destroying:Connect(function()
		watchedHerd[model] = nil
		undaze(model)
	end)
	refreshDazed(model)
end

local function watchHerds(folder: Instance)
	for _, child in ipairs(folder:GetChildren()) do
		watchHerdModel(child)
	end
	folder.ChildAdded:Connect(watchHerdModel)
	folder.ChildRemoved:Connect(function(child: Instance)
		if child:IsA("Model") then
			undaze(child)
		end
	end)
end

do
	local folder = Workspace:FindFirstChild("Herds")
	if folder then
		watchHerds(folder)
	else
		local conn: RBXScriptConnection
		conn = Workspace.ChildAdded:Connect(function(child: Instance)
			if child.Name == "Herds" then
				conn:Disconnect()
				watchHerds(child)
			end
		end)
	end
end

-- ============================================================
-- EVERY CHARACTER: THE TWIRL, AND THE TWO ONE-SHOTS
-- ============================================================

-- Characters holding a lasso, and the twirl track playing on each. Keyed by
-- the Model, so a respawn needs no cleanup: the old entry stops matching.
local holders: { [Model]: AnimationTrack | false } = {}
local twirlRetry: { [Model]: number } = {}

local function watchCharacter(character: Model)
	local function syncHeld()
		if heldLasso(character) then
			if holders[character] == nil then
				holders[character] = false
			end
		elseif holders[character] ~= nil then
			holders[character] = nil
			twirlRetry[character] = nil
			poseStop(character, "lassoTwirl", 0.15)
		end
	end
	character:GetAttributeChangedSignal(HeldItem.ATTRIBUTE):Connect(syncHeld)
	-- Counters rather than flags: a boolean set true twice fires one signal.
	character:GetAttributeChangedSignal(Config.LASSO_KNOCK_ATTRIBUTE):Connect(function()
		posePlay(character, "knockedLoose")
	end)
	character:GetAttributeChangedSignal(Config.LASSO_SCOOP_ATTRIBUTE):Connect(function()
		posePlay(character, "scoopUp")
	end)
	syncHeld()
end

local function follow(p: Player)
	if p.Character then
		watchCharacter(p.Character)
	end
	p.CharacterAdded:Connect(watchCharacter)
end

for _, p in ipairs(Players:GetPlayers()) do
	follow(p)
end
Players.PlayerAdded:Connect(follow)

-- ============================================================
-- THE FRAME
-- ============================================================

local function updateRope(rope: Rope, now: number, clock: number)
	-- A final message that never came: clear it rather than leak it. The
	-- clock cap covers a payload that carried no times at all.
	local stale = (rope.endsAt > 0 and now > rope.endsAt + STALE_GRACE)
		or clock - rope.bornAt > LASSO.flight + LASSO.struggle + STALE_GRACE * 3
	if (not rope.ending and stale) or (rope.ending and not rope.loop) then
		destroyRope(rope)
		if rope.thrower == player.UserId then
			showTapUI(ownRope())
		end
		return
	end
	if not rope.loop then
		return
	end
	local hand = ensureHand(rope)
	local handPos = if hand then hand.WorldPosition else rope.lastExit

	if rope.ending == "caught" then
		-- The loop cinches onto the piggy and is gone.
		local f = (clock - rope.endingAt) / CINCH_SECONDS
		if f >= 1 or not rope.lastCentre then
			destroyRope(rope)
			return
		end
		seatLoop(rope, rope.lastCentre, rope.lastFacing or Vector3.xAxis, rope.fit * (1 - 0.35 * f), 0)
		fadeParts(rope.loopRecs, (f - 0.5) * 2)
		if rope.beam then
			rope.beam.Transparency = NumberSequence.new(math.clamp(f, 0, 1))
		end
		return
	end

	local model = targetOf(rope)
	local body = model and bodyOf(model)
	local centre = if body then body.Position else rope.lastCentre
	if not (centre and handPos) then
		return
	end
	local facing = handPos - centre

	-- The coil leaves the hand at the throw's release: hidden from then until
	-- the rope is done, on every client, so the prop is never in two places.
	local character = characterOf(rope.thrower)
	local sinceStart = now - rope.startedAt
	if rope.phase == "struggle" or sinceStart >= releaseTime() then
		local prop = character and character:FindFirstChild(HeldItem.MODEL_NAME)
		if prop then
			for _, d in ipairs(prop:GetDescendants()) do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = 1
				end
			end
		end
	end

	if rope.phase == "flight" then
		local span = math.max(rope.endsAt - rope.startedAt, 0.05)
		local depart = rope.startedAt + math.min(releaseTime(), span * 0.5)
		local t = math.clamp((now - depart) / math.max(rope.endsAt - depart, 0.05), 0, 1)
		local eased = 1 - (1 - t) * (1 - t)
		local run = centre - handPos
		local lift = math.min(run.Magnitude * 0.15, 3) * math.sin(math.pi * t)
		local at = handPos:Lerp(centre, eased) + Vector3.new(0, lift, 0)
		-- Small in the hand, opening wide in the air, arriving a little wider
		-- than the piggy so the struggle can close it.
		local s = rope.fit * (0.3 + 0.85 * eased)
		seatLoop(rope, at, facing, s, t * math.pi * 4)
	else
		-- Struggle: settle from wide to fitted, then jiggle -- the wriggle
		-- drawn on the rope, since the piggy's own CFrame is the server's.
		local settle = math.clamp((now - rope.startedAt) / 0.2, 0, 1)
		local s = rope.fit * (1.15 - 0.15 * settle)
		local jig = math.sin(clock * 23) * 0.1 + math.sin(clock * 37) * 0.05
		seatLoop(rope, centre + Vector3.new(0, math.sin(clock * 29) * 0.06, 0), facing, s, jig)

		if rope.thrower == player.UserId then
			local fill = tapUI.fill
			if fill then
				local full = math.max(LASSO.tapRate * LASSO.struggle, 1)
				fill.Size = UDim2.fromScale(math.clamp(rope.taps / full, 0, 1), 1)
			end
			-- The pull speeds up with the tap rate over the last second.
			if clock - rope.speedAt > 0.1 then
				rope.speedAt = clock
				local recent = 0
				for i = #rope.tapTimes, 1, -1 do
					if clock - rope.tapTimes[i] <= 1 then
						recent += 1
					else
						break
					end
				end
				local share = math.clamp(recent / LASSO.tapRate, 0, 1)
				poseSpeed(character, "lassoPull", 1 + 0.8 * share)
			end
		end
	end
end

local function updateDazed(model: Model, state: Dazed, dt: number)
	if model.Parent == nil then
		undaze(model)
		return
	end
	local body = bodyOf(model)
	if not body then
		return
	end
	state.age += dt
	local width = math.max(body.Size.X, body.Size.Z)
	local radius = width * 0.45 + 0.3
	local top = body.Position + Vector3.new(0, body.Size.Y * 0.5 + 0.6, 0)
	for i, star in ipairs(state.stars) do
		local a = state.age * 2.6 + (i - 1) * math.pi / 2
		local bob = math.sin(state.age * 4 + i) * 0.12
		star:PivotTo(CFrame.new(top) * CFrame.Angles(0, a, 0) * CFrame.new(radius, bob, 0)
			* CFrame.Angles(0, math.pi / 2 + state.age * 3, 0.25))
	end
end

-- ============================================================
-- THE SPINNING LOOP WHILE A LASSO IS OUT
-- ============================================================
--
-- An equipped lasso is UNCOILED and SPINNING (designer, 2026-09-23: "it should
-- be uncoiled and spinning when equipped"). The coil in the fist is hidden and
-- the open loop -- the same Loop mesh that flies out on a throw -- circles
-- round the hand on a short rope from the fist to its knot, while the arm
-- plays the overhead twirl at the same rate. Every client draws it for every
-- holder, like the rope. It is dropped the moment a throw starts: the flight
-- builds its own loop at the hand, so the spinning one becomes the thrown one.

-- Revolutions a second, shared by the loop and the twirl pose so the arm and
-- the rope go round together.
local SPIN_RATE = 1.5
-- The loop's scale: 1.46 of opening at 1, so about 2.2 studs across.
local SPIN_SCALE = 1.5
-- A few degrees off flat, so the far side of the loop dips as it goes round.
local SPIN_TILT = math.rad(10)
-- How far above the fist the knot rides.
local SPIN_LIFT = 0.9

type Spin = {
	key: string,
	loop: Model,
	recs: { PartRec },
	endPart: BasePart,
	handAtt: Attachment?,
	angle: number,
}
local spins: { [Model]: Spin } = {}

local function setCoilHidden(character: Model, hidden: boolean)
	local prop = character:FindFirstChild(HeldItem.MODEL_NAME)
	if not prop then
		return
	end
	local v = if hidden then 1 else 0
	for _, d in ipairs(prop:GetDescendants()) do
		if d:IsA("BasePart") and d.LocalTransparencyModifier ~= v then
			d.LocalTransparencyModifier = v
		end
	end
end

-- Leaves the coil as it is: if a throw is why the spin stopped, the rope's own
-- code decides when the coil shows again.
local function dropSpin(character: Model)
	local s = spins[character]
	if not s then
		return
	end
	spins[character] = nil
	s.loop:Destroy()
	s.endPart:Destroy()
	if s.handAtt then
		s.handAtt:Destroy()
	end
end

local function spinHand(s: Spin, hand: BasePart): Attachment
	if s.handAtt and s.handAtt.Parent == hand then
		return s.handAtt
	end
	if s.handAtt then
		s.handAtt:Destroy()
	end
	local att = Instance.new("Attachment")
	att.Name = "LassoSpinHand"
	att.Position = Vector3.new(0, -0.25, 0)
	att.Parent = hand
	s.handAtt = att
	local beam = s.endPart:FindFirstChildOfClass("Beam")
	if beam then
		beam.Attachment0 = att
	end
	return att
end

local function buildSpin(character: Model, key: string): Spin?
	local hand = handOf(character)
	if not hand then
		return nil
	end
	local loop = LassoModel.buildLoop(key)
	local recs = recordParts(loop)
	-- Parked out of sight and sized once; every later frame only moves it.
	placeParts(recs, CFrame.new(0, -1000, 0), SPIN_SCALE, true)
	loop.Parent = fxFolder

	local endPart = Instance.new("Part")
	endPart.Name = "LassoSpinKnot"
	endPart.Size = Vector3.new(0.1, 0.1, 0.1)
	endPart.Transparency = 1
	endPart.Anchored = true
	endPart.CanCollide = false
	endPart.CanQuery = false
	endPart.CanTouch = false
	endPart.CastShadow = false
	endPart.Parent = fxFolder
	local endAtt = Instance.new("Attachment")
	endAtt.Parent = endPart

	local beam = Instance.new("Beam")
	beam.Name = "LassoSpinRope"
	beam.Color = ColorSequence.new(LassoModel.ropeColour(key))
	beam.Width0 = LassoModel.ROPE_WIDTH
	beam.Width1 = LassoModel.ROPE_WIDTH
	beam.FaceCamera = true
	beam.Segments = 2
	beam.LightInfluence = 1
	beam.Attachment1 = endAtt
	beam.Parent = endPart

	local s: Spin = { key = key, loop = loop, recs = recs, endPart = endPart, handAtt = nil, angle = 0 }
	spinHand(s, hand)
	return s
end

local function updateSpin(character: Model, key: string, dt: number)
	local s = spins[character]
	if s and s.key ~= key then
		dropSpin(character)
		s = nil
	end
	local hand = handOf(character)
	if not hand then
		dropSpin(character)
		return
	end
	if not s then
		s = buildSpin(character, key)
		if not s then
			return
		end
		spins[character] = s
	end
	local spin = s :: Spin
	spinHand(spin, hand)
	spin.angle = (spin.angle + dt * SPIN_RATE * 2 * math.pi) % (2 * math.pi)
	-- The loop turns about its own KNOT, which rides just above the fist, so
	-- the open ring sweeps round the hand the way a cowboy's does.
	local knot = (hand.CFrame * Vector3.new(0, -0.25, 0)) + Vector3.new(0, SPIN_LIFT, 0)
	local origin = CFrame.new(knot) * CFrame.Angles(0, spin.angle, 0) * CFrame.Angles(0, 0, SPIN_TILT)
		* CFrame.new(-LassoModel.LOOP_ROPE_EXIT * SPIN_SCALE)
	placeParts(spin.recs, origin, SPIN_SCALE, false)
	spin.endPart.CFrame = CFrame.new(knot)
	setCoilHidden(character, true)
end

local lastClock = os.clock()

RunService.Heartbeat:Connect(function()
	local clock = os.clock()
	local dt = math.min(clock - lastClock, 0.1)
	lastClock = clock

	local character = player.Character
	local key = heldLasso(character)

	-- Nothing held, nothing roped, nothing dazed, nothing tumbling: nothing
	-- to do, and the cheapest frame is the one that returns here.
	if not key and not lock.model and next(ropes) == nil and #effects == 0
		and next(dazed) == nil and next(holders) == nil and next(spins) == nil then
		return
	end

	-- LOCK-ON, only while a lasso is in hand and none is already out.
	if key and character and not ownRope() then
		local model, id = pickLock(character)
		if model ~= lock.model or id ~= lock.id then
			setLock(model, id, key)
		end
	elseif lock.model then
		setLock(nil, nil, nil)
	end

	local now = serverNow()
	for _, rope in pairs(ropes) do
		updateRope(rope, now, clock)
	end

	for i = #effects, 1, -1 do
		if not effects[i](dt) then
			table.remove(effects, i)
		end
	end

	for model, state in pairs(dazed) do
		updateDazed(model, state, dt)
	end

	-- THE TWIRL, asked every frame rather than started once, because the
	-- Animator may not have replicated when the lasso was drawn and a nil
	-- captured then would never twirl. Cheap: `holders` is the handful of
	-- people actually holding a lasso, and a playing track is left alone.
	for spinner in pairs(spins) do
		if holders[spinner] == nil or spinner.Parent == nil then
			dropSpin(spinner)
		end
	end
	for holder, track in pairs(holders) do
		if holder.Parent == nil then
			holders[holder] = nil
			twirlRetry[holder] = nil
			dropSpin(holder)
			continue
		end
		local owner = Players:GetPlayerFromCharacter(holder)
		if owner and (busyThrower(owner.UserId) or clock < (snapUntil[owner.UserId] or 0)) then
			holders[holder] = false
			dropSpin(holder)
			continue
		end
		local held = heldLasso(holder)
		if held then
			updateSpin(holder, held, dt)
		else
			dropSpin(holder)
		end
		if not (track and track.IsPlaying) and clock >= (twirlRetry[holder] or 0) then
			local played = posePlay(holder, "lassoTwirl", { speed = SPIN_RATE })
			holders[holder] = played or false
			-- A refused twirl (no Animator yet, no pose module) is asked again
			-- in a second rather than every frame.
			twirlRetry[holder] = if played then nil else clock + 1
		end
	end
end)
