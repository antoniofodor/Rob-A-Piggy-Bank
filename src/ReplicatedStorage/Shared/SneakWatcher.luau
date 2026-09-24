--!strict
--[[
	SneakWatcher -- plays the tiptoe for every character that is sneaking.

	The server publishes `Config.SNEAK_ATTRIBUTE` on a character and every
	client plays the tiptoe itself -- the same shape as the dodge, and for the
	same hard reason rather than for tidiness: the animation is registered at
	runtime and its id is a content hash local to this machine, so it cannot
	replicate.

	It has to be seen by everyone. A sneak is the counter to a watching dog,
	and a thief creeping across a lawn invisibly is a mechanic the defender
	cannot read.

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

local SneakWatcher = {}

--
-- The server publishes `Config.SNEAK_ATTRIBUTE` on a character and every
-- client plays the tiptoe itself -- the same shape as the dodge, and for the
-- same hard reason rather than for tidiness: the animation is registered at
-- runtime and its id is a content hash local to this machine, so it cannot
-- replicate. A track played on one client would be an id nobody else can
-- resolve.
--
-- EVERYONE HAS TO SEE IT, WHICH IS THE HALF `TiptoeState` CANNOT DO. That
-- remote is a FireClient to the sneaker alone, which is exactly right for the
-- button's own ON/OFF state and useless for the street. Half the value of a
-- tiptoe is what it says to somebody watching a figure come up their drive,
-- and this game prefers a tell to a fight everywhere it can get one.
--
-- THE RATE IS MEASURED, NEVER READ OFF THE HUMANOID. Speed comes from
-- differencing the root's own flat position between frames rather than from
-- `WalkSpeed`. The guard dog's watcher draws exactly this distinction and it
-- matters here for the same reason: WalkSpeed is what a character is ALLOWED
-- to do, so somebody standing perfectly still reads 5.6 and would have their
-- legs cycling on the spot forever. Flat, because a fall is not a footstep.
function SneakWatcher.start()
	local SneakWalk = require(ReplicatedStorage.Shared.SneakWalk)

	-- Characters currently flagged, and where each was last frame.
	local active: { [Model]: { last: Vector3? } } = {}

	local function animatorOf(character: Model): Animator?
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return nil
		end
		return humanoid:FindFirstChildOfClass("Animator")
	end

	local function refresh(character: Model)
		if character:GetAttribute(Config.SNEAK_ATTRIBUTE) == true then
			active[character] = active[character] or {}
		else
			active[character] = nil
			local animator = animatorOf(character)
			if animator then
				SneakWalk.apply(animator, false)
			end
		end
	end

	local function watch(character: Model)
		character:GetAttributeChangedSignal(Config.SNEAK_ATTRIBUTE):Connect(function()
			refresh(character)
		end)
		-- A character can arrive ALREADY sneaking -- a remote player who was
		-- creeping before this client ever joined -- so the current value is
		-- read rather than waited for. The changed signal alone would never
		-- fire for them, and they would walk normally on this screen while
		-- tiptoeing on everybody else's.
		refresh(character)
	end

	local function follow(player: Player)
		if player.Character then
			watch(player.Character)
		end
		player.CharacterAdded:Connect(watch)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		follow(player)
	end
	Players.PlayerAdded:Connect(follow)

	RunService.Heartbeat:Connect(function(dt)
		for character, state in pairs(active) do
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local animator = animatorOf(character)
			if character.Parent == nil or not root or not animator then
				-- A destroyed or half-built character drops out rather than
				-- being carried forever. Nothing has to clean up after a
				-- respawn either: the new rig is a different Model, so the
				-- old entry simply stops matching anything.
				active[character] = nil
			else
				-- STARTED HERE RATHER THAN IN `refresh`, because at the
				-- moment the attribute changes the Animator may not have
				-- replicated yet -- the dodge records that same trap one
				-- section up, where a nil captured at spawn meant that
				-- character never rolled again. Asking every frame is what
				-- makes this self-healing rather than dependent on winning
				-- a race, and it is cheap: `apply` returns early once a
				-- track is running, and this loop only ever holds the
				-- handful of people actually sneaking.
				SneakWalk.apply(animator, true)

				local at = Vector3.new(root.Position.X, 0, root.Position.Z)
				local last = state.last
				state.last = at
				if last and dt > 0 then
					SneakWalk.setRate(animator, (at - last).Magnitude / dt)
				end
			end
		end
	end)
end

return SneakWatcher
