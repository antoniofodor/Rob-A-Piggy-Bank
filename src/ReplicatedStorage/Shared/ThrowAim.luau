--!strict
--[[
	ThrowAim

	The client half of throwing a gadget: the crosshair, the over-the-shoulder
	camera, holding the arm back, and letting go.

	HOW A THROW WORKS NOW

	Draw a gadget and the camera eases over your right shoulder with a
	crosshair in the middle of the screen. PRESS and the arm goes back and
	stays back (`ThrowPose` parks it); on a mouse the pointer locks while you
	hold, so moving it steers the camera and the crosshair with it. LET GO
	and it is thrown toward whatever the crosshair is on. A quick click is a
	cock released before it parked, and plays straight through.

	THE THROW LANDS ON THE CROSSHAIR. The camera sits behind and above the
	hand, so a direction copied off the camera points DOWN at the ground in
	front of you -- measured on the first javelin build, where every throw
	landed within six to eighteen studs. So the aim is the ARC from the hand
	to the point the screen centre is on (`Config.throwAimAt`), and whenever
	that point is within the gadget's reach, that is where it comes down.
	Out of reach, it is lobbed as far as it can go toward it and falls short
	in plain sight. Leading somebody who is running is the skill.

	THE DOTTED ARC AND THE LANDING RING ARE GONE, by designer decision. They
	told the player exactly where a throw would land, which made the aim a
	matter of putting a ring on somebody rather than of throwing at them.
	The crosshair only says where you are POINTING: it tightens while the arm
	is back, turns red over somebody you could hit, and fades when what is
	under it is past the gadget's reach.

	THE AIM IS STILL A DIRECTION ON THE WIRE, NEVER A POSITION. The server
	clamps it (`Config.throwClampDirection`) and owns the origin, the speed,
	the gravity, the range and every step of the flight.

	BONES ARE NOT AIMED AND ARE NOT TOUCHED BY ANY OF THIS. See Config.THROW.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local GadgetFlight = require(ReplicatedStorage.Shared.GadgetFlight)
local HeldItem = require(ReplicatedStorage.Shared.HeldItem)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local ThrowPose = require(ReplicatedStorage.Shared.ThrowPose)

local ThrowAim = {}

-- Over the right shoulder, in the humanoid's own CameraOffset -- the same
-- mechanism shift-lock uses, so the camera module does the rest.
local SHOULDER = Vector3.new(1.75, 0.35, 0)
local SHOULDER_EASE = 12 -- per second

-- How far the screen-centre ray looks for something to aim at.
local AIM_REACH = 400

-- Crosshair geometry, in pixels.
local TICK_LONG = 10
local TICK_SHORT = 3
local GAP_IDLE = 13
local GAP_COCKED = 6

-- A touch that moved further than this and let go sooner than `TOUCH_HOLD`
-- was a camera swipe, not a throw. The same twelve pixels the hot bar's
-- drag and the tap-to-use test already use.
local TOUCH_SLOP = 12
local TOUCH_HOLD = 0.25

local state = {
	gui = nil :: ScreenGui?,
	root = nil :: Frame?,
	ticks = {} :: { Frame },
	dot = nil :: Frame?,
	-- The humanoid whose AutoRotate and CameraOffset we changed, so exactly
	-- that one is put back. A respawn hands out a new humanoid.
	held = nil :: Humanoid?,
	baseOffset = Vector3.zero,
	offsetBlend = 0,
	-- The button is down and wants a cock as soon as one is allowed.
	want = false,
	wantMouse = false,
	-- The arm is back.
	cocking = nil :: { key: string, at: number, mouse: boolean }?,
	lastThrow = -math.huge,
	lockedMouse = false,
	-- When the server last lowered our arm on a throw it refused, so a
	-- flight predicted for that throw is never drawn.
	refusedAt = -math.huge,
	warned = false,
}

-- ============================================================
-- THE CROSSHAIR
-- ============================================================

local function ensureGui()
	if state.gui and state.gui.Parent then
		return
	end
	local player = Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ThrowCrosshair"
	gui.ResetOnSpawn = false
	-- Centred on the CAMERA's viewport, which is the whole screen: the ray
	-- below is cast through the same point.
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = -1
	gui.Enabled = false
	gui.Parent = playerGui

	local root = Instance.new("Frame")
	root.Name = "Crosshair"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(0, 0)
	root.BackgroundTransparency = 1
	root.Parent = gui

	local function bar(name: string, size: Vector2): Frame
		local f = Instance.new("Frame")
		f.Name = name
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = UDim2.fromOffset(size.X, size.Y)
		f.BackgroundColor3 = Theme.PAPER
		f.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = f
		-- The ink line is what keeps a pale mark readable on bright grass
		-- and on a pale sky, which is most of what it will sit over.
		local stroke = Instance.new("UIStroke")
		stroke.Color = Theme.INK
		stroke.Thickness = 1.5
		stroke.Parent = f
		f.Parent = root
		return f
	end

	state.ticks = {
		bar("Up", Vector2.new(TICK_SHORT, TICK_LONG)),
		bar("Down", Vector2.new(TICK_SHORT, TICK_LONG)),
		bar("Left", Vector2.new(TICK_LONG, TICK_SHORT)),
		bar("Right", Vector2.new(TICK_LONG, TICK_SHORT)),
	}
	state.dot = bar("Dot", Vector2.new(4, 4))
	state.gui = gui
	state.root = root
end

local function layoutTicks(gap: number)
	local t = state.ticks
	if #t < 4 then
		return
	end
	local off = gap + TICK_LONG / 2
	t[1].Position = UDim2.fromOffset(0, -off)
	t[2].Position = UDim2.fromOffset(0, off)
	t[3].Position = UDim2.fromOffset(-off, 0)
	t[4].Position = UDim2.fromOffset(off, 0)
end

local currentGap = GAP_IDLE

local function paint(colour: Color3, alpha: number)
	for _, f in ipairs(state.ticks) do
		f.BackgroundColor3 = colour
		f.BackgroundTransparency = alpha
		local stroke = f:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = alpha
		end
	end
	if state.dot then
		state.dot.BackgroundColor3 = colour
		state.dot.BackgroundTransparency = alpha
	end
end

-- ============================================================
-- AIMING
-- ============================================================

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- The gadget in this character's hand, if any. Above everything that reads
-- it, for the forward-reference reason this project keeps recording.
local function heldGadget(character: Model?): string?
	if not character then
		return nil
	end
	local key = character:GetAttribute(HeldItem.ATTRIBUTE)
	if typeof(key) == "string" and Config.GADGETS[key] then
		return key
	end
	return nil
end

-- What the centre of the screen is on: the point, and the character it
-- belongs to if any.
local function crosshairHit(character: Model): (Vector3?, Model?)
	local camera = workspace.CurrentCamera
	if not camera then
		return nil, nil
	end
	local size = camera.ViewportSize
	local ray = camera:ViewportPointToRay(size.X / 2, size.Y / 2)
	local ignore: { Instance } = { character }
	local flights = workspace:FindFirstChild("GadgetFlights")
	if flights then
		table.insert(ignore, flights)
	end
	rayParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(ray.Origin, ray.Direction * AIM_REACH, rayParams)
	if not hit then
		return ray.Origin + ray.Direction * AIM_REACH, nil
	end
	local model = hit.Instance:FindFirstAncestorOfClass("Model")
	while model and not model:FindFirstChildOfClass("Humanoid") do
		model = model:FindFirstAncestorOfClass("Model")
	end
	return hit.Position, model
end

-- WHERE THE THROW IS POINTED: from the hand to what the crosshair is on.
-- Nil when there is nothing in hand to aim, which lets the server fall back
-- to the body's own facing rather than the client inventing a direction.
function ThrowAim.aimDirection(): Vector3?
	local player = Players.LocalPlayer
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local camera = workspace.CurrentCamera
	if not character or not root or not camera then
		return nil
	end
	local origin = Config.throwOrigin(root)
	local point = crosshairHit(character)
	local key = heldGadget(character)
	local spec = if key then Config.GADGETS[key] else nil
	if point then
		local to = point - origin
		-- A point behind or right on top of the hand -- the crosshair on a
		-- wall you are pressed against -- has no useful direction; aim along
		-- the camera instead.
		if to.Magnitude > 3 and to.Unit:Dot(camera.CFrame.LookVector) > 0 then
			if spec and not spec.beam then
				return (Config.throwAimAt(origin, point, Config.throwSpeed(spec)))
			end
			return Config.throwClampDirection(to)
		end
	end
	return Config.throwClampDirection(camera.CFrame.LookVector)
end

-- ============================================================
-- COCK, RELEASE, CANCEL
-- ============================================================

local function setMouseLock(on: boolean)
	if on then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		state.lockedMouse = true
	elseif state.lockedMouse then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		state.lockedMouse = false
	end
end

local function tryCock()
	if not state.want or state.cocking then
		return
	end
	if os.clock() - state.lastThrow < Config.GADGET_THROW_COOLDOWN then
		return
	end
	local player = Players.LocalPlayer
	local key = heldGadget(player and player.Character)
	if not key then
		return
	end
	state.cocking = { key = key, at = os.clock(), mouse = state.wantMouse }
	local animator = ThrowPose.localAnimator()
	if animator then
		ThrowPose.cock(animator)
	end
	Remotes.get("GadgetCock"):FireServer(true)
end

-- The button went down. Returns whether a gadget is in hand, so the caller
-- knows this press was a throw rather than some other item's use.
function ThrowAim.press(fromMouse: boolean): boolean
	local player = Players.LocalPlayer
	local key = heldGadget(player and player.Character)
	if not key then
		return false
	end

	-- THE ZAPPER FIRES ON THE PRESS. It is not thrown, so there is no arm to
	-- draw back and nothing to wait for: point the crosshair, press, and the
	-- arc goes. The same cooldown a throw has keeps it from being a hose.
	if Config.GADGETS[key].beam then
		if os.clock() - state.lastThrow >= Config.GADGET_THROW_COOLDOWN then
			state.lastThrow = os.clock()
			Remotes.get("GadgetThrow"):FireServer(key, ThrowAim.aimDirection())
		end
		return true
	end

	state.want = true
	state.wantMouse = fromMouse
	tryCock()
	return true
end

function ThrowAim.cancel()
	state.want = false
	setMouseLock(false)
	if not state.cocking then
		return
	end
	state.cocking = nil
	local animator = ThrowPose.localAnimator()
	if animator then
		ThrowPose.cancel(animator)
	end
	Remotes.get("GadgetCock"):FireServer(false)
end

-- The button came up. `swipe` is true for a touch that was really a camera
-- drag, which lowers the arm instead of throwing.
function ThrowAim.release(swipe: boolean?)
	local cock = state.cocking
	if not cock then
		-- Held through a cooldown and let go before it ended: nothing was
		-- drawn back, so nothing is thrown.
		state.want = false
		setMouseLock(false)
		return
	end
	local heldFor = os.clock() - cock.at
	if swipe and heldFor < TOUCH_HOLD then
		ThrowAim.cancel()
		return
	end

	state.want = false
	state.cocking = nil
	state.lastThrow = os.clock()
	setMouseLock(false)

	local key = cock.key
	local direction = ThrowAim.aimDirection()
	Remotes.get("GadgetThrow"):FireServer(key, direction)

	local animator = ThrowPose.localAnimator()
	if animator then
		ThrowPose.release(animator)
	end

	-- The thrower's own flight, from their own hand, the moment the server
	-- will launch it. Same `launchDelay` the server uses; the server's own
	-- figure also includes a ping, which is why this is a prediction.
	local aim = direction or Config.throwClampDirection(Vector3.zAxis)
	if aim then
		local delay = ThrowPose.launchDelay(heldFor)
		local thrownAt = state.lastThrow
		task.delay(delay, function()
			if state.refusedAt >= thrownAt then
				return
			end
			local player = Players.LocalPlayer
			local root = player and player.Character
				and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				GadgetFlight.predict(key, Config.throwOrigin(root),
					Config.throwVelocity(aim, Config.GADGETS[key]), 0)
			end
		end)
	end
end

-- The touch rule, computed once so `ClientMain` does not carry it.
function ThrowAim.isSwipe(from: Vector2, to: Vector2): boolean
	return (to - from).Magnitude > TOUCH_SLOP
end

-- ============================================================
-- EVERY FRAME
-- ============================================================

local function restoreHumanoid()
	local humanoid = state.held
	if humanoid then
		humanoid.AutoRotate = true
		humanoid.CameraOffset = state.baseOffset
	end
	state.held = nil
	state.offsetBlend = 0
end

local function step(dt: number)
	local player = Players.LocalPlayer
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local key = heldGadget(character)
	local spec = if key then Config.GADGETS[key] else nil

	-- The item changed under a drawn arm -- put away, spent, swapped.
	if state.cocking and state.cocking.key ~= key then
		ThrowAim.cancel()
	end

	if not spec or not humanoid or not root or humanoid.Health <= 0 or not character then
		if state.gui then
			state.gui.Enabled = false
		end
		if state.held then
			-- Ease the shoulder back rather than snapping it.
			state.offsetBlend = math.max(0, state.offsetBlend - dt * SHOULDER_EASE)
			if state.offsetBlend <= 0 then
				restoreHumanoid()
			else
				state.held.CameraOffset = state.baseOffset:Lerp(SHOULDER, state.offsetBlend)
			end
		end
		return
	end

	if state.held ~= humanoid then
		restoreHumanoid()
		state.held = humanoid
		state.baseOffset = humanoid.CameraOffset
	end
	state.offsetBlend = math.min(1, state.offsetBlend + dt * SHOULDER_EASE)
	humanoid.CameraOffset = state.baseOffset:Lerp(SHOULDER, state.offsetBlend)

	tryCock()
	if state.cocking and state.cocking.mouse then
		-- Re-asserted every frame: the camera module writes this property
		-- whenever its own right-button state changes.
		setMouseLock(true)
	end

	-- SQUARED TO THE CAMERA'S HEADING, which is a tell (somebody lining up a
	-- throw is visibly turned toward whoever they mean to hit) and keeps the
	-- thrower's yaw and the throw's yaw the same thing to look at.
	--
	-- `CFrame.lookAt` aims LOOKVECTOR, and this deliberately does NOT add the
	-- half turn every other builder here needs: a character's front really is
	-- its LookVector (`FaceFrontAttachment` is at head-local z -0.594).
	local camera = workspace.CurrentCamera
	if camera then
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		if flat.Magnitude > 1e-3 then
			humanoid.AutoRotate = false
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
		end
	end

	ensureGui()
	if not state.gui then
		return
	end
	state.gui.Enabled = true

	local targetGap = if state.cocking then GAP_COCKED else GAP_IDLE
	currentGap += (targetGap - currentGap) * math.min(1, dt * 18)
	layoutTicks(currentGap)

	local point, model = crosshairHit(character)
	local origin = Config.throwOrigin(root)
	-- IN REACH is "the arc can land there" for a thrown gadget, and a
	-- straight-line distance for the zapper's beam.
	local inRange = false
	if point then
		if spec.beam then
			inRange = (point - origin).Magnitude <= spec.range
		else
			local _, reachable = Config.throwAimAt(origin, point, Config.throwSpeed(spec))
			inRange = reachable
		end
	end
	if model and model ~= character and inRange then
		paint(Theme.STOP, 0)
	elseif inRange then
		paint(Theme.PAPER, 0)
	else
		paint(Theme.PAPER, 0.55)
	end
end

function ThrowAim.start()
	if state.gui then
		return
	end
	ensureGui()

	-- HEARTBEAT, NOT RENDERSTEPPED: RenderStepped does not fire at all in a
	-- Studio session whose viewport is not drawing, and a feature that
	-- silently does not exist there cost an afternoon once.
	RunService.Heartbeat:Connect(function(dt)
		local ok, err = pcall(step, dt)
		if not ok and not state.warned then
			state.warned = true
			warn("[ThrowAim] " .. tostring(err))
		end
	end)

	local player = Players.LocalPlayer
	if player then
		local function watchRefusal(character: Model)
			-- A throw the server refused publishes a cancel; if a flight was
			-- predicted for it, take it back.
			character:GetAttributeChangedSignal(Config.THROW_ANIMATION_ATTRIBUTE):Connect(function()
				local s = character:GetAttribute(Config.THROW_ANIMATION_ATTRIBUTE)
				if typeof(s) == "string" and string.sub(s, 1, 1) == "x" and not state.cocking
					and os.clock() - state.lastThrow < 1 then
					state.refusedAt = os.clock()
					GadgetFlight.cancelPrediction()
				end
			end)
		end
		if player.Character then
			watchRefusal(player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			state.cocking = nil
			state.want = false
			setMouseLock(false)
			state.held = nil
			state.offsetBlend = 0
			watchRefusal(character)
		end)
	end
end

return ThrowAim
