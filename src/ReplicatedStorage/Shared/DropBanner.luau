--!strict
--[[
	DropBanner

	PIGGIES INCOMING! -- the splash every client sees when a pack is released
	(designer, 2026-09-23: "a banner saying PIGGIES INCOMING! ... no card, just
	the text as an event on the top of the screen in big funky text").

	IT REPLACED THE OBSERVER TOAST AND THE DROP ZONE CARD. The toast said the
	batch number and the landing zone in the notify stack; the card hung the
	same words on the neon shaft. Both were labels. This is one line of
	display type, popped in over the top of the HUD and gone in four seconds,
	and the shaft standing on the spot is what says WHERE.

	A SPLASH, NOT A BAND OCCUPANT: the top-centre column is measured and full,
	so this draws over it on its own ScreenGui, above the HUD, for
	`Config.HERD_BANNER.hold + fade` seconds about once a minute. Same class as
	the arrest stamp. The numbers are all in `Config.HERD_BANNER`.

	FUNKY IS THE GAME'S OWN FACE, TILTED AND POPPED. FredokaOne at 72 in gold
	with a thick ink stroke, three degrees off level, scaled in from 0.4 with
	a Back ease so it overshoots and settles. No image, no uploaded font,
	nothing that can be moderated away.

	IT SHAKES AND IT SAYS WHERE (designer, 2026-09-23: "it should shake on
	the screen and under it look behind the backyard to find wild piggies").
	The shake is a per-frame random jolt of position and rotation under an
	envelope that decays from the moment the pop lands (`spec.shake`), so
	the type hits and settles; it never touches colour or transparency, so
	it is not a flash. The subtitle is one fixed line: it says the woods
	behind the backyards, never a plot number (designer), and the shaft on
	the spot is what says exactly where.

	ONE TOKEN, SO A SECOND DROP DURING THE FIRST IS SAFE: every delayed beat
	checks it still owns the label before touching it -- the door mask's own
	guard, and the arrest scene's before that.

	A MODULE, FOR THE 200-LOCAL CEILING: required and started in one statement
	from ClientMain, holding no local there.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)

local DropBanner = {}

local started = false

function DropBanner.start()
	if started then
		return
	end
	started = true
	local spec = Config.HERD_BANNER

	local gui = Instance.new("ScreenGui")
	gui.Name = "DropBanner"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	-- Over the HUD (which is the default order) and under the door mask (100):
	-- a splash that fires while somebody is walking through their front door
	-- is covered by the wipe, which is right.
	gui.DisplayOrder = 60
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.Name = "Headline"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, spec.y)
	-- Wide enough for the line at its size with room for the tilt; the text
	-- is not scaled, so a longer line would overflow rather than shrink, and
	-- `TextBounds` is the check if the line ever changes.
	label.Size = UDim2.fromOffset(1000, spec.textSize + 20)
	label.BackgroundTransparency = 1
	label.Font = Theme.FONT
	label.TextSize = spec.textSize
	label.TextColor3 = Theme.GOLD
	label.Text = spec.text
	label.Rotation = spec.tilt
	label.TextTransparency = 1
	label.Visible = false
	label.Parent = gui

	-- ON THE GLYPHS: a UIStroke on a TextLabel is `Contextual` by default and
	-- strokes the characters, which is what holds gold type over the sky and
	-- the grass alike. `Theme.outline` would draw a rectangle round the box.
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 5
	stroke.Color = Theme.INK
	stroke.Transparency = 1
	stroke.Parent = label

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = label

	-- THE CAPTION. Under the headline, the same face at less than half the
	-- size, paper with a thinner ink stroke, the same tilt; it pops, holds
	-- and fades with the headline and shakes with it.
	local caption = Instance.new("TextLabel")
	caption.Name = "Subtitle"
	caption.AnchorPoint = Vector2.new(0.5, 0)
	caption.Position = UDim2.new(0.5, 0, 0, spec.y + spec.textSize + 20 + spec.subtitleGap)
	caption.Size = UDim2.fromOffset(1100, spec.subtitleSize + 12)
	caption.BackgroundTransparency = 1
	caption.Font = Theme.FONT
	caption.TextSize = spec.subtitleSize
	caption.TextColor3 = Theme.PAPER
	caption.Text = spec.subtitle
	caption.Rotation = spec.tilt
	caption.TextTransparency = 1
	caption.Visible = false
	caption.Parent = gui

	local captionStroke = Instance.new("UIStroke")
	captionStroke.Thickness = 3
	captionStroke.Color = Theme.INK
	captionStroke.Transparency = 1
	captionStroke.Parent = caption

	local captionScale = Instance.new("UIScale")
	captionScale.Scale = 1
	captionScale.Parent = caption

	local labelBase = label.Position
	local captionBase = caption.Position

	-- THE SHAKE. One Heartbeat while a splash is live; the envelope is
	-- `1 - t / seconds` from the pop landing, and each frame jolts both
	-- labels by the same random offset so the caption stays under its
	-- headline. Ends by putting both back exactly where they were built.
	local shakeConn: RBXScriptConnection? = nil
	local function stopShake()
		if shakeConn then
			shakeConn:Disconnect()
			shakeConn = nil
		end
		label.Position = labelBase
		label.Rotation = spec.tilt
		caption.Position = captionBase
		caption.Rotation = spec.tilt
	end
	local function startShake()
		stopShake()
		local shake = spec.shake
		if not shake or shake.seconds <= 0 then
			return
		end
		local t0 = os.clock()
		shakeConn = RunService.Heartbeat:Connect(function()
			local k = 1 - (os.clock() - t0) / shake.seconds
			if k <= 0 then
				stopShake()
				return
			end
			local dx = (math.random() * 2 - 1) * shake.pixels * k
			local dy = (math.random() * 2 - 1) * shake.pixels * k
			local dr = (math.random() * 2 - 1) * shake.degrees * k
			label.Position = labelBase + UDim2.fromOffset(dx, dy)
			label.Rotation = spec.tilt + dr
			caption.Position = captionBase + UDim2.fromOffset(dx, dy)
			caption.Rotation = spec.tilt + dr
		end)
	end

	local token = 0

	local function show()
		token += 1
		local mine = token
		stopShake()
		label.Visible = true
		caption.Visible = true
		label.TextTransparency = 0
		caption.TextTransparency = 0
		stroke.Transparency = 0
		captionStroke.Transparency = 0
		scale.Scale = 0.4
		captionScale.Scale = 0.4
		local popInfo = TweenInfo.new(spec.pop, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(scale, popInfo, { Scale = 1 }):Play()
		TweenService:Create(captionScale, popInfo, { Scale = 1 }):Play()
		-- The jolt starts as the pop lands: the type arrives, hits, settles.
		task.delay(spec.pop * 0.6, function()
			if token == mine then
				startShake()
			end
		end)
		task.delay(spec.pop + spec.hold, function()
			if token ~= mine then
				return
			end
			local info = TweenInfo.new(spec.fade, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			TweenService:Create(label, info, { TextTransparency = 1 }):Play()
			TweenService:Create(stroke, info, { Transparency = 1 }):Play()
			TweenService:Create(caption, info, { TextTransparency = 1 }):Play()
			TweenService:Create(captionStroke, info, { Transparency = 1 }):Play()
			task.delay(spec.fade + 0.05, function()
				if token == mine then
					label.Visible = false
					caption.Visible = false
				end
			end)
		end)
	end

	-- THE PAYLOAD IS NOT READ. It carries the batch, the count and the zone
	-- in words; a first build printed the zone under the headline and the
	-- designer refused a plot number on screen, so the caption is fixed and
	-- the shaft says exactly where. The count is what you see landing.
	Remotes.get("HerdDrop").OnClientEvent:Connect(function()
		show()
	end)
end

return DropBanner
