--!strict
--[[
	BinExitHint -- the way out of a wheelie bin, and the card that says so.

	A player inside a bin sees NO prompts: ClientMain switches
	ProximityPromptService off for a hider, so the bin's own OPEN, the bin next
	door and every plot prompt go dark. That rule is right and it is also what
	killed the CLIMB OUT prompt this replaced -- the only way out of a bin was
	the two-minute ceiling. So the exit is not a prompt. Three routes, all
	arriving at the server as one `BinClimbOut` remote carrying at most a
	direction (never a position; the server flattens it, validates it and
	falls back to the way the player went in):

	  * JUMP. `UserInputService.JumpRequest` fires for Space, the on-screen
	    touch jump button and gamepad A alike. Hiding does not touch
	    JumpHeight, so the touch jump button stays on screen. The direction is
	    the move input if one is held, else the CAMERA's look flattened --
	    the hider's own facing was flattened to world +Z on entry and means
	    nothing, and "out the way I am looking" is what a player aims with.
	  * A TAP ON THIS CARD. Belt and braces for touch: if the jump button is
	    ever hidden (a stun as they dived in sets JumpHeight 0), the card is
	    still a button.
	  * A FRESH PUSH of the move input. "Fresh" is the whole rule: a player
	    reaches a bin running, so the key under their thumb would throw them
	    straight back out (the bug that retired the direction exit once
	    already). A push only counts once the input has been seen NEUTRAL
	    since the lid shut.

	All three wait out `Config.BINS.settleSeconds` (the commitment); a jump or
	a tap during the settle is QUEUED rather than dropped, so a press is never
	silently eaten. A held jump key is filtered the same way a held move key
	is: JumpRequest repeats every frame while held, so only a request after a
	gap counts.

	Every one of these is a player choosing to leave, so the server pays the
	exit burst for all of them (`vaulted` in StealthService.exitBin).

	THE CARD sits bottom-centre, in the hot bar's own band: the hot bar is
	hidden for exactly as long as a player is in a bin (HotBar.shouldShow), so
	the band is guaranteed free while this is up and this is never up
	otherwise.

	A MODULE, FOR THE 200-LOCAL CEILING: required and started in one statement
	from ClientMain, holding no local there.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)

local BinExitHint = {}

-- A JumpRequest counts as a NEW press only after this long with none; a held
-- key repeats every frame and never clears it.
local JUMP_GAP = 0.2
-- The StealthState push arrives after the server stamped `canExitAt`, so the
-- client's clock is already late by the latency; this is only rounding slop.
local SETTLE_SLOP = 0.05
-- If a sent exit has not landed in this long (a dropped packet, a refused
-- early press), the next press may try again rather than being eaten.
local RESEND_AFTER = 1.0

local started = false

function BinExitHint.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local remote = Remotes.get("BinClimbOut")

	local gui = Instance.new("ScreenGui")
	gui.Name = "BinExitHint"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 12
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local card = Instance.new("TextButton")
	card.Name = "Card"
	card.AutoButtonColor = false
	card.Text = ""
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Size = UDim2.fromOffset(300, 62)
	card.Parent = gui
	Theme.card(card, 16)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 7)
	title.Size = UDim2.new(1, -24, 0, 28)
	title.Font = Theme.FONT
	title.TextSize = 26
	title.TextColor3 = Theme.INK
	title.Text = "JUMP TO CLIMB OUT"
	title.Parent = card

	local sub = Instance.new("TextLabel")
	sub.Name = "Sub"
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromOffset(12, 36)
	sub.Size = UDim2.new(1, -24, 0, 18)
	sub.Font = Theme.FONT_BODY
	sub.TextSize = 14
	sub.TextColor3 = Theme.MUTED
	sub.Text = "or push any way"
	sub.Parent = card

	-- Same band the hot bar uses (HotBar's `fit.bottom`): 22 in landscape,
	-- 270 in portrait where the bottom-left stack takes the lower band.
	local function place()
		local camera = workspace.CurrentCamera
		local size = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local bottom = if size.Y > size.X then 270 else 22
		card.Position = UDim2.new(0.5, 0, 1, -bottom)
	end
	place()

	local inside = false
	local enteredAt = 0
	local sawNeutral = false
	local pending = false
	local sentAt: number? = nil
	local lastJump = -math.huge

	local function ready(): boolean
		return os.clock() >= enteredAt + Config.BINS.settleSeconds + SETTLE_SLOP
	end

	local function moveDir(): Vector3
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		return if humanoid then humanoid.MoveDirection else Vector3.zero
	end

	-- A held move input wins; otherwise out the way the camera looks.
	local function jumpDir(): Vector3
		local held = moveDir()
		if held.Magnitude > 0.1 then
			return held
		end
		local camera = workspace.CurrentCamera
		local look = if camera then camera.CFrame.LookVector else Vector3.zero
		return Vector3.new(look.X, 0, look.Z)
	end

	local function send(direction: Vector3)
		if sentAt and os.clock() - sentAt < RESEND_AFTER then
			return
		end
		sentAt = os.clock()
		pending = false
		remote:FireServer(direction)
	end

	local function press()
		if not inside then
			return
		end
		if ready() then
			send(jumpDir())
		else
			pending = true
		end
	end

	local function paint()
		local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
		sub.Text = if isTouch then "or tap here, or push any way" else "or push any way"
		local live = ready()
		title.TextTransparency = if live then 0 else 0.45
		sub.TextTransparency = if live then 0 else 0.45
	end

	UserInputService.JumpRequest:Connect(function()
		local now = os.clock()
		local fresh = now - lastJump > JUMP_GAP
		lastJump = now
		if fresh then
			press()
		end
	end)

	card.Activated:Connect(press)

	Remotes.get("StealthState").OnClientEvent:Connect(function(snapshot)
		local now = type(snapshot) == "table" and snapshot.disguised == true
		if now and not inside then
			inside = true
			enteredAt = os.clock()
			sawNeutral = false
			pending = false
			sentAt = nil
			place()
		elseif not now and inside then
			inside = false
			pending = false
		end
		gui.Enabled = inside
	end)

	RunService.Heartbeat:Connect(function()
		if not inside then
			return
		end
		paint()
		local dir = moveDir()
		if dir.Magnitude < 0.1 then
			sawNeutral = true
		end
		if not ready() then
			return
		end
		if pending then
			send(jumpDir())
		elseif sawNeutral and dir.Magnitude > 0.5 then
			send(dir)
		end
	end)
end

return BinExitHint
