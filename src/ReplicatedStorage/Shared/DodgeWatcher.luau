--!strict
--[[
	DodgeWatcher -- plays the dodge somersault for every player who rolls.

	The server publishes a DodgeRoll counter on the character and every client
	plays the somersault itself. That is not tidiness: the animation is
	registered at runtime and its id is a content hash local to this machine,
	so it cannot replicate. A track played on one client would be an id nobody
	else can resolve.

	Everyone has to see it. The dodge's real payload is half a second of
	immunity, and a defender who loses a tag hold to an invisible dodge has
	been beaten by something that never appeared to happen.

	EXTRACTED FROM `ClientMain` RATHER THAN REWRITTEN. That chunk is one
	Luau chunk against the 200-local register ceiling, and reaching it
	does not cost the feature being added -- it costs the WHOLE HUD, with
	an error naming a variable thousands of lines from the cause. This
	section borrowed nothing from the rest of the file and lent nothing
	to it, measured in both directions before it moved, so every line
	below is the original and only its home changed.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local player = Players.LocalPlayer

local DodgeWatcher = {}

--
-- The server publishes a DodgeRoll counter on the character and every client
-- plays the somersault itself. Same shape as animated skins, and for a harder
-- reason than tidiness: the animation is registered at runtime and its id is a
-- content hash local to this machine, so it cannot replicate. A track played
-- on one client would be an id nobody else can resolve.
--
-- Everyone has to see it. The dodge's real payload is half a second of
-- immunity, and a defender who loses a tag hold to an invisible dodge has been
-- beaten by something that never appeared to happen.
--
-- THE DASH IS A DIRECTION, NOT AN IMPULSE.
--
-- Config.DODGE is a multiplier on currentSpeed, which means a player standing
-- still dodges at 2.5x of nothing and goes nowhere -- the control did not work
-- unless you were already running. This drives the humanoid's own move
-- direction for the length of the window instead of adding a force, so the
-- dash still goes through the one movement system that the carry penalty, the
-- fence snags, the stun and the dog speeds are all expressed in. A fence still
-- stops you. A stun still means no dodge at all, because the server refuses it
-- before this is ever reached.
--
-- Direction is whatever is being held, and the character's own facing when
-- nothing is. It is captured once and held for the window rather than tracked,
-- because a dodge you can steer mid-roll is a sprint.
function DodgeWatcher.start()
	local DASH_BINDING = "PiggyDodgeDash"
	-- Above the control module, which binds at Input priority. Anything at
	-- or below that loses the frame.
	local DASH_PRIORITY = Enum.RenderPriority.Character.Value + 1
	local DodgeRoll = require(ReplicatedStorage.Shared.DodgeRoll)

	local function dash(character: Model, humanoid: Humanoid)
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end

		local held = humanoid.MoveDirection
		local heading = if held.Magnitude > 0.1 then held else root.CFrame.LookVector
		heading = Vector3.new(heading.X, 0, heading.Z)
		if heading.Magnitude < 0.01 then
			return
		end
		heading = heading.Unit

		-- Bound AFTER the control module rather than run on Heartbeat.
		--
		-- The default controls write a move direction every RenderStepped, and
		-- whoever writes last before the physics step wins. Heartbeat is after
		-- physics, so a dash driven there was overwritten by an empty input
		-- every single frame -- measured at 0.51 studs from a standing start,
		-- which is indistinguishable from the bug this was meant to fix.
		RunService:UnbindFromRenderStep(DASH_BINDING)
		local until_ = os.clock() + Config.DODGE.duration
		RunService:BindToRenderStep(DASH_BINDING, DASH_PRIORITY, function()
			if os.clock() >= until_ or humanoid.Parent == nil or humanoid.Health <= 0 then
				RunService:UnbindFromRenderStep(DASH_BINDING)
				return
			end
			humanoid:Move(heading, false)
		end)
	end

	local function roll(character: Model)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		-- Looked up when it fires rather than at spawn. At CharacterAdded the
		-- Animator often has not replicated yet, and a nil captured then would
		-- mean that character never rolled again.
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			DodgeRoll.play(animator)
		end
		return humanoid
	end

	local function watch(character: Model, isLocal: boolean)
		character:GetAttributeChangedSignal("DodgeRoll"):Connect(function()
			local humanoid = roll(character)
			-- Only your own character moves on your say-so. Everyone else's
			-- position is the server's business and arrives by replication.
			if humanoid and isLocal then
				dash(character, humanoid)
			end
		end)

		-- CLIMBING OUT OF A WHEELIE BIN PLAYS THE SAME ROLL AND NO DASH.
		--
		-- Its own attribute rather than a second bump of DodgeRoll, which
		-- would have been one line fewer and wrong: that handler dashes the
		-- local player as well, and the exit has already placed them 4.5
		-- studs out and handed them a speed burst. A third way to move on top
		-- of those two is exactly what Config.DODGE's "a multiplier, never an
		-- impulse" note rules out.
		--
		-- The animation is shared on purpose. Tumbling out of a bin is the
		-- same gesture as rolling out of the way, and a second sequence built
		-- to look almost the same is the copy that drifts the first time
		-- either one is touched.
		character:GetAttributeChangedSignal("BinExit"):Connect(function()
			roll(character)
		end)
	end

	local function follow(player: Player)
		local isLocal = player == Players.LocalPlayer
		if player.Character then
			watch(player.Character, isLocal)
		end
		player.CharacterAdded:Connect(function(character)
			watch(character, isLocal)
		end)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		follow(player)
	end
	Players.PlayerAdded:Connect(follow)
end

return DodgeWatcher
