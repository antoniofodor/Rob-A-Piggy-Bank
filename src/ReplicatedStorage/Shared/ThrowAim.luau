--!strict
--[[
	ThrowAim

	The client half of aiming a gadget: it squares the character to the
	camera while one is in hand, traces where the throw will actually go, and
	hands that aim to whoever fires the remote.

	WHAT A GADGET THROW IS NOW

	A ballistic projectile. It leaves the hand along the direction you are
	LOOKING -- pitch and all -- at `Config.THROW.speed`, and `THROW.gravity`
	pulls it down for as long as it is in the air. Near targets are
	point-and-shoot; anything toward the end of a gadget's range has to be
	lobbed, because it drops about ten studs over a plunger's 34. See
	Config.THROW for the table those two constants are solved against.

	THE PREVIEW IS THE FEATURE, NOT DECORATION.

	A throw that can miss and cannot be seen before it leaves the hand is a
	mechanic a nine-year-old cannot learn: they would know only that gadgets
	sometimes do not work. Worse for this version than for the last one --
	"aim above them for distance" is not a thing anybody works out from a
	toast that says MISSED. The dotted line is how the drop is taught, and it
	is the whole reason this can be aimed with no crosshair, no charge meter
	and no control a tablet cannot perform.

	It traces through `Config.throwPointAt`, which is the same curve the
	server flies the real gadget along, so the line somebody is looking at
	and the throw they are about to make cannot disagree.

	THE AIM IS SENT, AND THIS MODULE IS WHERE IT COMES FROM.

	`ThrowAim.aimDirection` is what `ClientMain` puts on the remote, so what
	was previewed is what gets thrown -- one source, not two that drift. The
	server clamps and re-simulates it and owns everything else about the
	flight; see Config.THROW for why a direction is a different kind of thing
	from a coordinate, and why the character's own facing stopped being
	enough the moment pitch mattered.

	SQUARING THE CHARACTER IS STILL WORTH DOING even though the server no
	longer reads the body's facing. It is a TELL -- somebody lining up a
	throw is visibly turned toward whoever they mean to hit, on a street that
	already prefers a tell to a fight -- and it keeps the yaw of the throw and
	the yaw of the thrower the same thing to look at.

	BONES ARE NOT AIMED AND ARE NOT TOUCHED BY ANY OF THIS. See Config.THROW.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local HeldItem = require(ReplicatedStorage.Shared.HeldItem)
local Theme = require(ReplicatedStorage.Shared.Theme)

local ThrowAim = {}

-- How many beads the path is drawn with. Built ONCE and moved, never created
-- per frame. They are spread over the flight's own duration rather than over
-- a fixed distance, so a short throw is a short dense line and a lobbed one
-- stretches -- which is itself the readout for how long it will be in the
-- air, and therefore how much to lead.
local DOTS = 16
local DOT_SIZE = 0.42
local RING_THICKNESS = 0.18
local RING_LIFT = 0.06

-- The bead nearest the hand is nearly invisible and the far end is solid, so
-- the line reads as going AWAY from you rather than as a static string of
-- dots, and the crowded near end does not cover the thrower's own feet.
local DOT_NEAR_ALPHA = 0.85
local DOT_FAR_ALPHA = 0.25

-- The preview's own step. Coarser than the server's per-frame flight on
-- purpose: this runs a raycast per step on every frame, and a fifth of a
-- stud of accuracy in a dotted line is worth nothing. Capped as well as
-- stepped, because a throw lobbed at the sky would otherwise run the whole
-- of `THROW.maxSeconds` in raycasts on every frame.
local TRACE_STEP = 1 / 30
local TRACE_MAX_STEPS = 70

local state = {
	folder = nil :: Folder?,
	dots = {} :: { BasePart },
	ring = nil :: BasePart?,
	-- The humanoid we turned AutoRotate off on, so it can be put back on
	-- exactly the one we touched. A respawn hands out a new humanoid, and
	-- restoring "the current character" would write to the wrong one.
	held = nil :: Humanoid?,
	connection = nil :: RBXScriptConnection?,
	-- So a throw in the step loop is reported once rather than every frame.
	warned = false,
}

local function ensureParts()
	if state.folder and state.folder.Parent then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "ThrowAimPreview"
	folder.Parent = workspace
	state.folder = folder
	state.dots = {}

	for i = 1, DOTS do
		local dot = Instance.new("Part")
		dot.Name = "AimDot"
		dot.Shape = Enum.PartType.Ball
		dot.Size = Vector3.new(DOT_SIZE, DOT_SIZE, DOT_SIZE)
		dot.Anchored = true
		dot.CanCollide = false
		dot.CanQuery = false
		dot.CanTouch = false
		dot.CastShadow = false
		dot.Material = Enum.Material.Neon
		dot.Color = Theme.GOLD
		local alpha = DOT_NEAR_ALPHA
			+ (DOT_FAR_ALPHA - DOT_NEAR_ALPHA) * ((i - 1) / math.max(1, DOTS - 1))
		dot:SetAttribute("Base", alpha)
		dot.Transparency = alpha
		dot.Parent = folder
		state.dots[i] = dot
	end

	-- A ROBLOX CYLINDER'S AXIS IS ITS X AXIS, which is why this is sized
	-- (thickness, diameter, diameter) rather than the way it reads. Written
	-- the other way round it makes a disc as wide as the thickness and lays
	-- it on its side -- the mistake this project has made five times in
	-- other files.
	local ring = Instance.new("Part")
	ring.Name = "AimRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(RING_THICKNESS, Config.THROW.hitRadius * 2, Config.THROW.hitRadius * 2)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = Theme.GOLD
	ring.Transparency = 0.62
	ring.Parent = folder
	state.ring = ring
end

local function setVisible(on: boolean)
	if not state.folder then
		return
	end
	for _, dot in ipairs(state.dots) do
		dot.Transparency = if on then (dot:GetAttribute("Base") :: number) else 1
	end
	if state.ring then
		state.ring.Transparency = if on then 0.62 else 1
	end
end

local function hide()
	if state.folder then
		setVisible(false)
	end
	if state.held then
		state.held.AutoRotate = true
		state.held = nil
	end
end

-- WHERE THE THROW IS POINTED, and the one thing on this module anybody else
-- calls. Returns nil when there is nothing in hand to aim, which is also the
-- answer `ClientMain` wants: a client that cannot say where it is aiming
-- should let the server fall back to the body's own facing rather than
-- inventing a direction.
--
-- FULL 3D, PITCH INCLUDED. That is the difference from the first aimed
-- version, which flattened this and could therefore never ask anybody to
-- lob anything.
function ThrowAim.aimDirection(): Vector3?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	return Config.throwClampDirection(camera.CFrame.LookVector)
end

-- Steps the same curve the server flies and reports where it stops, why, and
-- how long it took. The three endings are the world, the gadget's own range
-- measured HORIZONTALLY, and the time cap -- exactly the three the flight
-- itself uses, because a preview that ends somewhere the throw does not is
-- worse than no preview.
local function trace(origin: Vector3, velocity: Vector3, range: number, ignore: { Instance }): (Vector3, Vector3, number)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore

	local prev = origin
	local t = 0
	local flatOrigin = Vector3.new(origin.X, 0, origin.Z)

	for _ = 1, TRACE_MAX_STEPS do
		t += TRACE_STEP
		local pos = Config.throwPointAt(origin, velocity, t)
		local step = pos - prev
		if step.Magnitude > 1e-3 then
			local hit = workspace:Raycast(prev, step, params)
			if hit then
				return hit.Position, hit.Normal, t
			end
		end
		-- THE RANGE CAP IS INTERPOLATED BACK, NOT REPORTED WHERE IT WAS
		-- NOTICED. Stepping coarsely means the first sample past the cap can
		-- be a couple of studs beyond it, and measured against a real throw
		-- that showed as the ring sitting 3.6 studs further out than the
		-- gadget actually reached -- a preview lying in the one place it is
		-- most read, the far end of the range.
		--
		-- Horizontal speed is CONSTANT, so horizontal distance is linear in
		-- t and this lerp is exact rather than an approximation.
		local here = (Vector3.new(pos.X, 0, pos.Z) - flatOrigin).Magnitude
		if here >= range then
			local back = (Vector3.new(prev.X, 0, prev.Z) - flatOrigin).Magnitude
			local span = here - back
			local f = if span > 1e-4 then math.clamp((range - back) / span, 0, 1) else 1
			return prev:Lerp(pos, f), Vector3.yAxis, t
		end
		if t >= Config.THROW.maxSeconds then
			return pos, Vector3.yAxis, t
		end
		prev = pos
	end
	return prev, Vector3.yAxis, t
end

local function step()
	local player = Players.LocalPlayer
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?

	local key = if character then character:GetAttribute(HeldItem.ATTRIBUTE) else nil
	local spec = if typeof(key) == "string" then Config.GADGETS[key] else nil

	if not spec or not humanoid or not root or humanoid.Health <= 0 then
		hide()
		return
	end

	local aim = ThrowAim.aimDirection()
	if not aim then
		hide()
		return
	end

	-- SQUARED TO THE CAMERA'S HEADING, and only its heading: a character
	-- cannot pitch, which is the entire reason the aim has to be sent rather
	-- than read off the body.
	--
	-- `CFrame.lookAt` aims LOOKVECTOR, and this deliberately does NOT add the
	-- half turn every other builder in this project needs after it. Those
	-- place MODELS, authored facing +Z. A character is the one thing here
	-- whose front really is its LookVector -- measured, `FaceFrontAttachment`
	-- sits at head-local z -0.594 -- so adding the correction would aim the
	-- body out of the back of its own head.
	local flat = Vector3.new(aim.X, 0, aim.Z)
	if flat.Magnitude > 1e-3 then
		if state.held ~= humanoid then
			if state.held then
				state.held.AutoRotate = true
			end
			state.held = humanoid
		end
		humanoid.AutoRotate = false
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
	end

	ensureParts()
	setVisible(true)

	local origin = root.Position + Vector3.new(0, Config.THROW.launchHeight, 0)
	local velocity = Config.throwVelocity(aim)

	local ignore: { Instance } = { character :: Instance }
	if state.folder then
		table.insert(ignore, state.folder)
	end
	local impact, normal, seconds = trace(origin, velocity, spec.range, ignore)

	-- Beads over the flight's own duration, so the line always spans the
	-- whole path however long it turned out to be.
	for i, dot in ipairs(state.dots) do
		dot.Position = Config.throwPointAt(origin, velocity, seconds * (i / DOTS))
	end

	local ring = state.ring
	if ring then
		-- LAID ON WHATEVER IT HIT rather than always flat, so a throw that
		-- stops against a fence reads as stopping against a fence. The
		-- cylinder's axis is its local X, so the surface normal goes in as
		-- the X vector and any perpendicular serves as Y.
		local axis = if normal.Magnitude > 1e-3 then normal.Unit else Vector3.yAxis
		local other = if math.abs(axis.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
		local yv = axis:Cross(other)
		if yv.Magnitude < 1e-3 then
			yv = Vector3.zAxis
		end
		ring.CFrame = CFrame.fromMatrix(impact + axis * RING_LIFT, axis, yv.Unit)
	end
end

-- Started in ONE STATEMENT holding no local at all, because `ClientMain` is
-- against Luau's 200-register ceiling and has died twice naming an innocent
-- variable two thousand lines from the change. A module body gets its own
-- register file; this costs that chunk nothing.
function ThrowAim.start()
	if state.connection then
		return
	end
	-- HEARTBEAT, AND IT WAS RENDERSTEPPED FOR ONE BUILD, WHICH IS WORTH
	-- WRITING DOWN BECAUSE THE FAILURE LOOKED EXACTLY LIKE A BROKEN FEATURE.
	--
	-- RenderStepped is the obvious choice -- it fires just before the frame
	-- is drawn, so a CFrame written there lands in the same frame the camera
	-- moved, where Heartbeat costs one frame of lag. It also DOES NOT FIRE
	-- AT ALL WHEN NOTHING IS BEING RENDERED. Measured in a Studio session
	-- whose viewport was not drawing: Heartbeat ticked normally and a probe
	-- connected to RenderStepped never fired once, so the aim preview simply
	-- did not exist -- no error, no warning, an empty workspace, and a
	-- feature that had worked an hour earlier.
	--
	-- That is the `RegisterKeyframeSequence` family from a new direction: an
	-- API whose behaviour depends on the environment rather than on the code,
	-- which means the thing that proves it works is not the thing that runs
	-- it. Heartbeat has no such dependency.
	--
	-- The frame of lag it costs is worth nothing here. This is not the dodge
	-- dash racing the control module for a move direction -- `AutoRotate` is
	-- off, so nothing else is writing this rotation, and a dotted line 16ms
	-- behind the camera is not a line anybody can see is behind the camera.
	-- BUILT HERE RATHER THAN ON THE FIRST STEP, which is seventeen invisible
	-- parts for a player who never holds a gadget and is worth it twice
	-- over. It takes the one allocation out of the hot loop, and it makes
	-- this module OBSERVABLE: the folder existing means `start` ran, so a
	-- feature that is not drawing can be told apart from a feature that was
	-- never switched on -- which is a distinction that cost most of an
	-- afternoon when the only evidence either way was an empty workspace.
	ensureParts()
	setVisible(false)

	state.connection = RunService.Heartbeat:Connect(function()
		local ok, err = pcall(step)
		if not ok and not state.warned then
			-- ONCE, NOT SIXTY TIMES A SECOND. A per-frame warn buries the
			-- log it is trying to write to, and this project has already
			-- recorded that a warning nobody can read is not a report.
			state.warned = true
			warn("[ThrowAim] " .. tostring(err))
		end
	end)

	-- A respawn hands out a new humanoid, and the old one's AutoRotate goes
	-- with it. Clearing the reference is what stops the next frame restoring
	-- a property on a corpse.
	local player = Players.LocalPlayer
	if player then
		player.CharacterAdded:Connect(function()
			state.held = nil
			hide()
		end)
	end
end

return ThrowAim
