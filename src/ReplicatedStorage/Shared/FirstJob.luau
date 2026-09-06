--!strict
--
-- THE WHOLE OF THIS GAME'S ONBOARDING, AND IT IS ONE SENTENCE.
--
-- The game is called Rob a Piggy Bank, so the instruction is *go and rob a
-- piggy bank*. Anything more is a tutorial for a premise that fits in six
-- words, and a nine-year-old closes a tutorial. There is no panel, no OK
-- button, no step two and nothing to dismiss.
--
-- WHAT IT SOLVES. Measured before any of this existed: a new player spawned
-- on their own plot with an empty pig, no affordable purchase for forty
-- seconds, nothing that could happen to them for ten minutes, and not one
-- word anywhere in the first minute mentioning robbing. They learned this
-- was an idle game, because for their first session it was one.
--
-- IT POINTS AS WELL AS TELLS, because "go and rob a piggy bank" is useless
-- to somebody who does not yet know that the houses down the street have
-- piggy banks in them. The nearest worthwhile pig is highlighted, so the
-- sentence has somewhere to send them.
--
-- IT RETIRES ON THE FIRST DELIVERY AND NEVER COMES BACK. The server derives
-- `Config.PLAYER_FIRST_JOB_ATTRIBUTE` from `data.totalStolen`, so a player
-- who has ever got a robbery home has never seen this and never will --
-- including on a later session, and including after a rebirth.
--
-- A MODULE, NOT A SECTION OF ClientMain, for the reason RobBadge, HouseFX,
-- HotBar and AdminPanel are: that chunk sits at Luau's 200-local ceiling and
-- has taken the ENTIRE HUD down twice for four locals. A module body gets
-- its own register file, so this costs the chunk one require and no local at
-- all.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)

local FirstJob = {}

-- Top centre, in the band the coin badge vacated when it merged into the
-- piggy bank panel: 16..90 is free and the rebirth button starts at 96.
--
-- SQUEEZED BETWEEN THE TOPBAR AND THE REBIRTH BUTTON, and both edges are
-- measured rather than chosen. `IgnoreGuiInset` is on, so offset 0 is the
-- PHYSICAL top of the screen and the Roblox topbar covers the first 58
-- pixels of it. The first version sat at 16 with a height of 60 and measured
-- **42 of its 60 pixels inside that band** -- which the old coin counter got
-- away with, because the middle of the topbar is empty and a number is
-- readable half-dimmed. The one sentence a new player has to read is not the
-- element to spend that on.
--
-- 50..94 puts all but 8 pixels clear of the topbar and stops 2 short of the
-- rebirth button. There is no arrangement that clears both completely: 58
-- would be fully clear and a 44-tall card would then run to 102, straight
-- through a control that is pinned at 96.
local TOP = 50
local HEIGHT = 44
local WIDTH = 470

local started = false

local function build(parent: ScreenGui): Frame
	local card = Instance.new("Frame")
	card.Name = "FirstJob"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, TOP)
	card.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	card.BackgroundColor3 = Theme.PAPER
	card.BorderSizePixel = 0
	card.Visible = false
	card.Parent = parent
	Theme.corner(card, 12)
	Theme.outline(card)

	-- A DRAWN COIN, never the emoji. An emoji renders from the colour font,
	-- ignores TextColor3 entirely and is a smudge at chip size -- this
	-- project has the measurement and the rule already.
	local coin = Theme.coin(card, 28)
	coin.AnchorPoint = Vector2.new(0, 0.5)
	coin.Position = UDim2.new(0, 14, 0.5, 0)
	coin.Parent = card

	local label = Instance.new("TextLabel")
	label.Name = "Line"
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.new(0, 52, 0.5, 0)
	label.Size = UDim2.new(1, -66, 1, -14)
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextScaled = true
	label.Text = "Your piggy bank is empty. Go and rob a neighbour!"
	label.Parent = card
	Theme.title(label, 22, Theme.INK)

	return card
end

-- The nearest pig worth walking to.
--
-- NEAREST RATHER THAN RICHEST, deliberately. The job of this marker is to
-- teach that the houses on this street have money in them, and the shortest
-- possible trip is the one most likely to be completed by somebody who has
-- been playing for nine seconds. Richest is the decision they get to make
-- once the badges above every pig have taught them there is one to make.
local function pickTarget(me: Player): (Model?, BasePart?)
	local character = me.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local plots = workspace:FindFirstChild("Plots")
	if not root or not plots then
		return nil, nil
	end

	local bestModel: Model?, bestBody: BasePart?, bestDistance = nil, nil, math.huge
	for _, model in ipairs(plots:GetChildren()) do
		local ownerId = model:GetAttribute("OwnerUserId")
		local residentId = model:GetAttribute(Config.PLOT_RESIDENT_ID_ATTRIBUTE)
		local vault = model:GetAttribute(Config.PLOT_VAULT_ATTRIBUTE) or 0
		-- Somebody to rob, something in the pig, and not your own house.
		if (ownerId or residentId) and ownerId ~= me.UserId and vault > 0 then
			local piggy = model:FindFirstChild("PiggyBank")
			local body = piggy and piggy:FindFirstChild("Body")
			if body and body:IsA("BasePart") then
				local distance = (body.Position - root.Position).Magnitude
				if distance < bestDistance then
					bestModel, bestBody, bestDistance = model :: Model, body, distance
				end
			end
		end
	end
	return bestModel, bestBody
end

function FirstJob.start(me: Player, parent: ScreenGui)
	if started then
		return
	end
	started = true

	local card = build(parent)

	-- One highlight, re-adorned rather than rebuilt. A Highlight per plot
	-- would be eight instances to keep in step; moving one cannot desync.
	local mark = Instance.new("Highlight")
	mark.Name = "FirstJobTarget"
	mark.FillColor = Theme.GOLD
	mark.FillTransparency = 0.55
	mark.OutlineColor = Theme.GOLD
	mark.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	mark.Enabled = false
	-- Parented to the workspace rather than to the ScreenGui: a Highlight is
	-- not a GuiObject and wants to live where the thing it adorns lives. It
	-- is created on the client, so nothing about it replicates.
	mark.Parent = workspace

	-- THREE STATES, NOT TWO, AND CONFLATING THEM WOULD HAVE MEANT NO NEW
	-- PLAYER EVER SAW THIS.
	--
	-- `nil` is NOT "no". The server writes this attribute from its own
	-- PlayerAdded, and this module starts from the client's own script --
	-- neither waits for the other, so on any join where the client wins the
	-- race the attribute is simply not there yet. Treating that as false tore
	-- the whole feature down a frame before it was told it was needed, which
	-- is exactly the case it exists for and the one that would never have
	-- reproduced in a test that set the attribute first.
	--
	-- So: true shows it, false retires it for good, and nil waits.
	local function state(): boolean?
		return me:GetAttribute(Config.PLAYER_FIRST_JOB_ATTRIBUTE) :: boolean?
	end

	local accumulator = 0
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt)
		local want = state()
		if want == false then
			-- Retired. Torn down rather than hidden: it can never be needed
			-- again, and a hidden widget still polling is a cost nobody sees.
			card:Destroy()
			mark:Destroy()
			connection:Disconnect()
			return
		end
		if want ~= true then
			-- Not told yet. Stay quiet and keep waiting.
			card.Visible = false
			mark.Enabled = false
			return
		end

		-- A quarter second is plenty for something a player walks toward, and
		-- it keeps eight distance checks off every frame.
		accumulator += dt
		if accumulator < 0.25 then
			return
		end
		accumulator = 0

		local model, body = pickTarget(me)
		card.Visible = model ~= nil
		mark.Adornee = body
		mark.Enabled = body ~= nil
	end)

	-- No eager teardown here on purpose: the loop above owns all three
	-- states, and doing it once more at start time is precisely how the nil
	-- race gets reintroduced by somebody tidying up.
end

return FirstJob
