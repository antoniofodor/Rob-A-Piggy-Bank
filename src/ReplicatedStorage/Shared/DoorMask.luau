--!strict
--[[
	DoorMask

	The black wipe that hides a front-door crossing.

	An interior is a DETACHED room standing four thousand studs off the map
	(`InteriorService`), so walking through a door is a teleport. This is the
	half that makes it read as a doorway rather than as a jump cut: the screen
	goes black, the server moves you under the cover, and the reveal is the
	room you walked into.

	IT IS THE ARREST SCENE'S OWN SHAPE, one beat shorter. That scene is a
	scrim tweened over the whole screen with the card under it, and the
	release teleport happens while it is still opaque -- `CLAUDE.md` records
	that as the thing that "hides the move, so the reveal is the player's own
	lawn". Same trick, no card.

	THE TIMING IS `Config.HOUSE_DOOR` AND NOT A SECOND COPY OF IT. The server
	waits `maskLead` before it writes the CFrame; this holds for `maskHold`
	and fades over `maskFade`. Two tables of tenths would drift the first time
	either was touched, and what drifts here is a player seeing the room they
	just left going transparent.

	IT IS A MODULE RATHER THAN A BLOCK IN ClientMain, AND THAT IS THE
	200-LOCAL CEILING RATHER THAN A STYLE NOTE. That chunk has hit it eight
	times and every time it cost the ENTIRE HUD -- the chunk never compiles,
	so nothing gets built and the error names an innocent variable two
	thousand lines away. Required and started in one statement holding no
	local at all.

	AND IT IS ITS OWN `ScreenGui` RATHER THAN A FRAME IN THE HUD'S. The HUD's
	gui is built in ClientMain and this file has no reference to it; more to
	the point, this has to cover the HUD as well. A wipe that left the piggy
	bank panel, the hot bar and a toast floating over a black screen would be
	the one arrangement that makes it obvious nothing physical happened.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local DoorMask = {}

local started = false

function DoorMask.start()
	if started then
		return
	end
	started = true

	local gui = Instance.new("ScreenGui")
	gui.Name = "DoorMask"
	gui.ResetOnSpawn = false
	-- OVER EVERYTHING, INCLUDING THE HUD. See the note at the top: a wipe
	-- with the hot bar drawn on top of it is a wipe that says nothing moved.
	gui.DisplayOrder = 100
	gui.IgnoreGuiInset = true
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local sheet = Instance.new("Frame")
	sheet.Name = "Sheet"
	-- BIGGER THAN THE SCREEN AND CENTRED ON IT. `IgnoreGuiInset` puts y = 0
	-- at the very top of the display, and a frame sized exactly to the
	-- viewport still leaves a hairline at an odd aspect ratio -- which on a
	-- full-screen black cover is the one pixel that gives the whole thing
	-- away.
	sheet.Size = UDim2.fromScale(1.2, 1.2)
	sheet.Position = UDim2.fromScale(0.5, 0.5)
	sheet.AnchorPoint = Vector2.new(0.5, 0.5)
	-- NOT PURE BLACK. A doorway is a dark room rather than a hole in the
	-- world, and the near-black this game already uses for the tunnel lining
	-- reads as one; pure black reads as the game having crashed.
	sheet.BackgroundColor3 = Color3.fromRGB(9, 7, 8)
	sheet.BackgroundTransparency = 1
	sheet.BorderSizePixel = 0
	sheet.Visible = false
	sheet.Parent = gui

	-- ONE TOKEN, SO A SECOND CROSSING DURING THE FIRST IS SAFE. Every delayed
	-- beat checks it still owns the sheet before touching anything -- the
	-- same guard `buildBustScene` keeps for a second arrest landing inside the
	-- first one's card.
	local token = 0

	local function wipe()
		token += 1
		local mine = token
		local door = Config.HOUSE_DOOR

		sheet.Visible = true
		sheet.BackgroundTransparency = 0

		task.delay(door.maskLead + door.maskHold, function()
			if token ~= mine then
				return
			end
			TweenService:Create(sheet,
				TweenInfo.new(door.maskFade, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ BackgroundTransparency = 1 }):Play()
			task.delay(door.maskFade + 0.05, function()
				if token == mine then
					sheet.Visible = false
				end
			end)
		end)
	end

	-- THE PAYLOAD IS IGNORED, DELIBERATELY. `InteriorService` sends a way in
	-- or out because a later version may want to wipe differently in each
	-- direction; today it does not, and branching on a string to produce two
	-- identical animations would be a difference a reader has to check.
	Remotes.get("DoorCross").OnClientEvent:Connect(function()
		wipe()
	end)
end

return DoorMask
