--!strict
--[[
	ArrestScene -- the mugshot card a caught thief is shown.

	Getting caught used to be a toast with a number in it: the same
	information and none of the event. This is a camera flash, a mugshot card,
	a BUSTED stamp and the bail counting up, and every beat is DERIVED from
	`Config.STUN_SECONDS` so the card clears at about the moment the player
	gets their legs back. A cutscene that outlasts the thing it narrates is
	taking away time somebody could have been playing.

	It HOLDS for `arrestHold` and becomes skippable at `arrestSkipAfter`, with
	the prompt fading in exactly when that becomes true rather than sitting
	there through a window in which pressing does nothing -- the movement key
	a fleeing player is already holding used to kill the scene instantly.

	The layout is an ORIGINAL: a height chart, a headshot, a name board and a
	stamp, in the game's own navy and gold. The obvious reference is somebody
	else's registered property, and moderation lands on the EXPERIENCE.

	EXTRACTED FROM `ClientMain` RATHER THAN REWRITTEN. That chunk is one
	Luau chunk against the 200-local register ceiling, and reaching it
	does not cost the feature being added -- it costs the WHOLE HUD, with
	an error naming a variable thousands of lines from the cause. This
	section borrowed nothing from the rest of the file and lent nothing
	to it, measured in both directions before it moved, so every line
	below is the original and only its home changed.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage.Shared.Config)
local Music = require(ReplicatedStorage.Shared.Music)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local GOLD = Theme.GOLD

local ArrestScene = {}

--
-- Getting caught used to be a toast that said BUSTED and a number, which is
-- the same information and none of the event. This is the scene: the flash,
-- the mugshot, the stamp, the bail.
--
-- IT IS AN ORIGINAL, and that is a shipping rule rather than a preference.
-- The obvious reference here is somebody else's property -- a specific
-- wordmark in a specific typeface over a specific desaturated screen, plus
-- its audio -- and Roblox moderation strips branded assets with the penalty
-- landing on the EXPERIENCE, not the one screen. So this borrows the LAYOUT,
-- which is a genre: a height chart, a headshot, a name board and a stamp.
-- The palette is the game's own navy and gold, and the sting is a cell door
-- rather than a drone -- which is funnier, is nobody's, and says "sentenced"
-- instead of "you died", in a game where nothing kills anybody.
--
-- IT IS EXACTLY AS LONG AS THE DETENTION. Every beat is derived from
-- Config.STUN_SECONDS, so the card clears at about the moment the player gets
-- their legs back. A cutscene that outlasts the thing it is narrating is
-- taking away time somebody could have been playing; this one only fills time
-- they had already lost. Change STUN_SECONDS and the scene follows.
--
-- It can also be dismissed early with any input after the stamp has landed.
-- The drama is the point, but it is still their game.
--
-- Wrapped in a function because the chunk is near Luau's 200-register ceiling
-- and this section alone declares about thirty locals. A function body gets
-- its own register file, so it costs the chunk one.
function ArrestScene.start(gui: Instance)
	local SoundService = game:GetService("SoundService")

	-- Exact, with separators. `format` abbreviates -- 3,000 coins shown as
	-- "3.0K" reads as a statistic, where "3,000" reads as a fine, and this
	-- card is the one place in the HUD that wants the second thing.
	local function exact(value: number): string
		local text = tostring(math.floor(value))
		local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		return (out:gsub("^,", ""))
	end

	local function sfx(id: string, volume: number): Sound
		local sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Volume = volume
		sound.Parent = SoundService
		return sound
	end

	local shutter = sfx(Config.SOUNDS.SHUTTER, 0.65)
	local cellDoor = sfx(Config.SOUNDS.CELL_DOOR, 0.8)

	-- Tolerates an empty SoundId, like every other sound player in this
	-- project: the ids are third-party and can be moderated away, and a
	-- scene that errors is worse than a scene that is quiet.
	local function blast(sound: Sound)
		if sound.SoundId ~= "" then
			sound.TimePosition = 0
			sound:Play()
		end
	end

	-- ---------------------------------------------------------- the scrim
	local scene = Instance.new("Frame")
	scene.Name = "BustScene"
	scene.Size = UDim2.fromScale(1, 1)
	scene.BackgroundColor3 = Color3.fromRGB(11, 7, 5)
	scene.BackgroundTransparency = 1
	scene.BorderSizePixel = 0
	scene.Visible = false
	scene.ZIndex = 50
	scene.Parent = gui

	-- --------------------------------------------------------- the card
	local card = Instance.new("Frame")
	card.Size = UDim2.new(0, 480, 0, 302)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.BackgroundColor3 = Color3.fromRGB(57, 38, 23)
	card.BorderSizePixel = 0
	card.ZIndex = 51
	card.Parent = scene
	Theme.corner(card, 16)

	local cardScale = Instance.new("UIScale")
	cardScale.Scale = 0.86
	cardScale.Parent = card

	local strip = Instance.new("Frame")
	strip.Size = UDim2.new(1, -28, 0, 30)
	strip.Position = UDim2.new(0, 14, 0, 12)
	strip.BackgroundTransparency = 1
	strip.ZIndex = 52
	strip.Parent = card

	local force = Instance.new("TextLabel")
	force.Size = UDim2.new(0.6, 0, 1, 0)
	force.BackgroundTransparency = 1
	force.Font = Enum.Font.FredokaOne
	force.TextSize = 20
	force.TextColor3 = GOLD
	force.TextXAlignment = Enum.TextXAlignment.Left
	force.Text = "PIGGY PATROL"
	force.ZIndex = 52
	force.Parent = strip

	local caseNo = Instance.new("TextLabel")
	caseNo.Size = UDim2.new(0.4, 0, 1, 0)
	caseNo.Position = UDim2.new(0.6, 0, 0, 0)
	caseNo.BackgroundTransparency = 1
	caseNo.Font = Enum.Font.Code
	caseNo.TextSize = 16
	caseNo.TextColor3 = Theme.MUTED_LIGHT
	caseNo.TextXAlignment = Enum.TextXAlignment.Right
	caseNo.Text = "CASE #0000"
	caseNo.ZIndex = 52
	caseNo.Parent = strip

	-- ------------------------------------------------- the photo, with chart
	local photo = Instance.new("Frame")
	photo.Size = UDim2.new(0, 170, 0, 200)
	photo.Position = UDim2.new(0, 14, 0, 48)
	photo.BackgroundColor3 = Color3.fromRGB(220, 210, 203)
	photo.BorderSizePixel = 0
	photo.ClipsDescendants = true
	photo.ZIndex = 52
	photo.Parent = card
	Theme.corner(photo, 8)

	-- The height chart. It is the single element that makes a headshot read
	-- as a mugshot rather than as a profile picture, and it is drawn rather
	-- than built for the same reason the car's door roundel is.
	for i = 1, 6 do
		local rule = Instance.new("Frame")
		rule.Size = UDim2.new(1, 0, 0, 2)
		rule.Position = UDim2.new(0, 0, 0, 14 + (i - 1) * 31)
		rule.BackgroundColor3 = Theme.MUTED
		rule.BorderSizePixel = 0
		rule.ZIndex = 52
		rule.Parent = photo

		local tick = Instance.new("TextLabel")
		tick.Size = UDim2.new(0, 26, 0, 14)
		tick.Position = UDim2.new(0, 4, 0, 16 + (i - 1) * 31)
		tick.BackgroundTransparency = 1
		tick.Font = Enum.Font.Code
		tick.TextSize = 11
		tick.TextColor3 = Theme.MUTED
		tick.TextXAlignment = Enum.TextXAlignment.Left
		tick.Text = ("%d'"):format(7 - i)
		tick.ZIndex = 52
		tick.Parent = photo
	end

	-- rbxthumb rather than GetUserThumbnailAsync: the content URL resolves
	-- itself and never yields, so the scene cannot be held up waiting on a
	-- web call at the exact moment it is supposed to slam onto the screen.
	local mug = Instance.new("ImageLabel")
	mug.Size = UDim2.new(0, 168, 0, 168)
	mug.Position = UDim2.new(0.5, 0, 0, 28)
	mug.AnchorPoint = Vector2.new(0.5, 0)
	mug.BackgroundTransparency = 1
	mug.ScaleType = Enum.ScaleType.Fit
	mug.ZIndex = 53
	mug.Parent = photo

	-- --------------------------------------------------- the name board
	local board = Instance.new("Frame")
	board.Size = UDim2.new(0, 268, 0, 200)
	board.Position = UDim2.new(0, 198, 0, 48)
	board.BackgroundColor3 = Color3.fromRGB(43, 29, 17)
	board.BorderSizePixel = 0
	board.ZIndex = 52
	board.Parent = card
	Theme.corner(board, 8)

	local plate = Instance.new("Frame")
	plate.Size = UDim2.new(1, -24, 0, 54)
	plate.Position = UDim2.new(0, 12, 0, 14)
	plate.BackgroundColor3 = Color3.fromRGB(247, 240, 235)
	plate.BorderSizePixel = 0
	plate.ZIndex = 53
	plate.Parent = board
	Theme.corner(plate, 6)

	local who = Instance.new("TextLabel")
	who.Size = UDim2.new(1, -16, 1, -10)
	who.Position = UDim2.new(0, 8, 0, 5)
	who.BackgroundTransparency = 1
	who.Font = Enum.Font.FredokaOne
	who.TextColor3 = Color3.fromRGB(47, 32, 20)
	-- TextScaled implies wrapping, and writing TextWrapped next to it turns
	-- scaling back off. The plate is given the height a wrapped name needs
	-- instead.
	who.TextScaled = true
	who.Text = "?"
	who.ZIndex = 53
	who.Parent = plate

	local rows = Instance.new("Frame")
	rows.Size = UDim2.new(1, -24, 0, 112)
	rows.Position = UDim2.new(0, 12, 0, 78)
	rows.BackgroundTransparency = 1
	rows.ZIndex = 53
	rows.Parent = board

	local rowList = Instance.new("UIListLayout")
	rowList.Padding = UDim.new(0, 6)
	rowList.Parent = rows

	local function chargeRow(order: number, key: string): TextLabel
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0, 24)
		row.LayoutOrder = order
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.Code
		row.TextSize = 15
		row.TextColor3 = Theme.MUTED_LIGHT
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = key
		row.ZIndex = 53
		row.Parent = rows
		return row
	end

	chargeRow(1, "CHARGE   ROBBERY")
	local victimRow = chargeRow(2, "VICTIM   --")
	local recoveredRow = chargeRow(3, "SEIZED   --")

	-- --------------------------------------------------- the bail strip
	local bailStrip = Instance.new("Frame")
	bailStrip.Size = UDim2.new(1, -28, 0, 34)
	bailStrip.Position = UDim2.new(0, 14, 0, 256)
	bailStrip.BackgroundColor3 = Color3.fromRGB(32, 21, 12)
	bailStrip.BorderSizePixel = 0
	bailStrip.ZIndex = 52
	bailStrip.Parent = card
	Theme.corner(bailStrip, 8)

	local bailKey = Instance.new("TextLabel")
	bailKey.Size = UDim2.new(0.5, 0, 1, 0)
	bailKey.Position = UDim2.new(0, 12, 0, 0)
	bailKey.BackgroundTransparency = 1
	bailKey.Font = Enum.Font.Code
	bailKey.TextSize = 15
	bailKey.TextColor3 = Theme.MUTED_LIGHT
	bailKey.TextXAlignment = Enum.TextXAlignment.Left
	bailKey.Text = "BAIL PAID FROM YOUR PIGGY BANK"
	bailKey.ZIndex = 52
	bailKey.Parent = bailStrip

	local bailValue = Instance.new("TextLabel")
	bailValue.Size = UDim2.new(0.5, -24, 1, 0)
	bailValue.Position = UDim2.new(0.5, 12, 0, 0)
	bailValue.BackgroundTransparency = 1
	bailValue.Font = Enum.Font.FredokaOne
	bailValue.TextSize = 22
	bailValue.TextColor3 = GOLD
	bailValue.TextXAlignment = Enum.TextXAlignment.Right
	bailValue.Text = "0"
	bailValue.ZIndex = 52
	bailValue.Parent = bailStrip

	-- ------------------------------------------------------- the stamp
	local stamp = Instance.new("TextLabel")
	-- ON THE PHOTOGRAPH, not across the card. Centred on the card it looked
	-- better and sat straight over the CHARGE row, which is the one line that
	-- says what you actually did. The mugshot panel spans x 14..184, so a
	-- 184-wide stamp centred on it clears the board text at x=210 even with
	-- the rotation bleed (a 58-tall box turned 8 degrees reaches about four
	-- pixels further each side than its width suggests). It is also where a
	-- stamp belongs: on the picture.
	stamp.Size = UDim2.new(0, 184, 0, 58)
	stamp.Position = UDim2.new(0, 99, 0, 148)
	stamp.AnchorPoint = Vector2.new(0.5, 0.5)
	stamp.Rotation = -8
	stamp.BackgroundTransparency = 1
	stamp.Font = Enum.Font.FredokaOne
	stamp.TextScaled = true
	stamp.TextColor3 = Theme.STOP
	stamp.TextStrokeColor3 = Color3.fromRGB(255, 236, 232)
	stamp.TextStrokeTransparency = 0.15
	stamp.Text = "BUSTED"
	stamp.ZIndex = 60
	stamp.Parent = card

	local stampScale = Instance.new("UIScale")
	stampScale.Scale = 2.4
	stampScale.Parent = stamp

	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(0, 300, 0, 22)
	hint.Position = UDim2.new(0.5, 0, 0.5, 172)
	hint.AnchorPoint = Vector2.new(0.5, 0.5)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Code
	hint.TextSize = 14
	hint.TextColor3 = Theme.MUTED
	hint.TextTransparency = 1
	hint.Text = "tap to continue"
	hint.ZIndex = 51
	hint.Parent = scene

	-- ------------------------------------------------------- the flash
	-- Last child and highest ZIndex: it has to cover the card it is
	-- revealing, or the photo is visible a frame before it is taken.
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 70
	flash.Parent = scene

	-- ---------------------------------------------------------- playback
	--
	-- One table, not a dozen locals -- the register budget is spent by more
	-- than one feature at a time. `token` is what makes a second arrest
	-- during the first one safe: every delayed beat checks it still owns the
	-- scene before touching anything.
	local bust = { token = 0, running = false, tick = nil :: RBXScriptConnection?,
		from = 0, skipAt = 0, pulse = nil :: Tween? }

	local function finish(token: number)
		if bust.token ~= token then
			return
		end
		bust.running = false
		if bust.tick then
			bust.tick:Disconnect()
			bust.tick = nil
		end
		-- Cancelled before the fade, or a looping tween keeps writing
		-- TextTransparency and the prompt never goes out.
		if bust.pulse then
			bust.pulse:Cancel()
			bust.pulse = nil
		end
		local out = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(scene, out, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(cardScale, out, { Scale = 0.9 }):Play()
		TweenService:Create(hint, out, { TextTransparency = 1 }):Play()
		task.delay(0.5, function()
			if bust.token == token then
				scene.Visible = false
			end
		end)
	end

	local function play(payload: any)
		if type(payload) ~= "table" then
			return
		end
		bust.token += 1
		local token = bust.token
		bust.running = true
		if bust.tick then
			bust.tick:Disconnect()
			bust.tick = nil
		end

		local bail = math.max(0, tonumber(payload.bail) or 0)
		local recovered = math.max(0, tonumber(payload.recovered) or 0)

		mug.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=420&h=420"):format(
			Players.LocalPlayer.UserId)
		who.Text = Players.LocalPlayer.DisplayName
		-- Stable per arrest and meaningless on purpose: a case number is set
		-- dressing, and deriving one from anything real would invite a player
		-- to read it as a score.
		caseNo.Text = ("CASE #%04d"):format(math.random(1, 9999))
		victimRow.Text = ("VICTIM   %s"):format(payload.victim or "--")
		recoveredRow.Text = if recovered > 0
			then ("SEIZED   %s coins"):format(exact(recovered))
			else "SEIZED   nothing -- already delivered"
		bailValue.Text = "0"

		-- Beat one: the photograph. Everything else is revealed under it.
		scene.Visible = true
		scene.BackgroundTransparency = 1
		flash.BackgroundTransparency = 0
		cardScale.Scale = 0.86
		stampScale.Scale = 2.4
		stamp.TextTransparency = 1
		hint.TextTransparency = 1
		blast(shutter)

		TweenService:Create(scene, TweenInfo.new(0.3), { BackgroundTransparency = 0.35 }):Play()
		TweenService:Create(flash, TweenInfo.new(0.4, Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(cardScale, TweenInfo.new(0.45, Enum.EasingStyle.Back,
			Enum.EasingDirection.Out), { Scale = 1 }):Play()

		-- Beat two: the stamp lands, and the cell door goes with it.
		task.delay(0.85, function()
			if bust.token ~= token then
				return
			end
			blast(cellDoor)
			stamp.TextTransparency = 0
			TweenService:Create(stampScale, TweenInfo.new(0.22, Enum.EasingStyle.Quint,
				Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end)

		-- Beat three: the bail counts up. A number that arrives already
		-- totalled is a fact; one that climbs is a bill being added up, and
		-- this is the moment the scene exists to sell.
		task.delay(1.35, function()
			if bust.token ~= token then
				return
			end
			local started = os.clock()
			local COUNT = 1.1
			bust.tick = RunService.Heartbeat:Connect(function()
				if bust.token ~= token then
					return
				end
				local through = math.min(1, (os.clock() - started) / COUNT)
				-- Eased out, so it decelerates onto the final figure rather
				-- than stopping dead on it.
				bailValue.Text = exact(bail * (1 - (1 - through) ^ 3))
				if through >= 1 and bust.tick then
					bust.tick:Disconnect()
					bust.tick = nil
				end
			end)
		end)

		-- The prompt appears exactly WHEN it becomes true, rather than sitting
		-- there through a window in which pressing something does nothing. A
		-- hint that lies for two seconds is worse than no hint.
		--
		-- And it PULSES, because the card is now genuinely waiting rather than
		-- counting down. A static line reads as decoration; a breathing one is
		-- the difference between "this will go away" and "this is waiting for
		-- you". Held on `bust` with everything else -- this file is one chunk
		-- against Luau's 200-local ceiling.
		bust.skipAt = os.clock() + Config.POLICE.arrestSkipAfter
		task.delay(Config.POLICE.arrestSkipAfter, function()
			if bust.token ~= token or not bust.running then
				return
			end
			hint.TextTransparency = 0.25
			bust.pulse = TweenService:Create(hint,
				TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut,
					-1, true),
				{ TextTransparency = 0.65 })
			;(bust.pulse :: Tween):Play()
		end)

		-- A BACKSTOP, NOT A BEAT. See Config.POLICE.arrestTimeout: the tap is
		-- what closes this, and thirty seconds only exists so a card cannot
		-- strand somebody whose input never arrives.
		task.delay(Config.POLICE.arrestTimeout, function()
			finish(token)
		end)
	end

	Remotes.get("PoliceBust").OnClientEvent:Connect(function(...)
		-- The shutter and the cell door are the whole beat of the scene, and
		-- it is derived from STUN_SECONDS -- so the duck is too, rather than
		-- being a number that drifts away from the thing it is covering.
		-- Covers the shutter and the cell door and a comfortable read, rather
		-- than the whole backstop -- ducking the score for thirty seconds
		-- because somebody left the card up would be a bug of its own.
		Music.duck(Config.POLICE.arrestSkipAfter + 4.5)
		play(...)
	end)

	-- Dismissable, but NOT INSTANTLY, and the gate is the whole fix. This
	-- handler used to fire from the frame the scene appeared: the comment said
	-- "once the stamp has landed" and nothing enforced it, so the movement key
	-- the player was already holding -- they were running from the police --
	-- dismissed the scene before it had drawn a single beat.
	UserInputService.InputBegan:Connect(function(_, processed)
		if bust.running and not processed and scene.Visible
			and os.clock() >= bust.skipAt then
			finish(bust.token)
		end
	end)
end

return ArrestScene
