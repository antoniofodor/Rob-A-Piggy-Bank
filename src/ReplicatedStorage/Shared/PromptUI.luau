--!strict
--[[
	PromptUI

	What every interaction in this game looks like when you walk up to it.

	----------------------------------------------------------------------

	SEVEN ACTIONS SHARED ONE PICTURE.

	Roblox's default prompt is a grey pill with a letter in it, and it is drawn
	identically whether a player is banking their own coins, robbing somebody
	else's piggy, climbing into a wheelie bin or tipping somebody out of one.
	So the loudest thing anybody can do on this street looked exactly like the
	quietest, and the only way to tell them apart was to stop and read.

	`Config.PROMPTS` is the vocabulary -- a tone, a glyph and a word per kind,
	the same shape `Config.NOTIFY` already uses for the toast stack -- and this
	file is the one place that draws it.

	----------------------------------------------------------------------

	COLOUR IS NEVER THE ONLY SIGNAL.

	The rarity borders had to learn this the hard way: colour alone separates
	things only for players who can see the difference, and blue-against-purple
	is exactly the pair that fails. So a prompt says STEAL in words, carries a
	money bag, AND is red. Any one of the three is enough.

	THE CHIP IS A DARK DISC WITH A TONE RING, not a disc of the tone -- an
	emoji carries its own colours and ignores `TextColor3` entirely, so a red
	siren on a red disc is a red smudge. The notification cards learned that
	one first and this follows them.

	----------------------------------------------------------------------

	THE HOLD SHOWS HOW LONG IT IS.

	A default prompt draws the same filling circle whether the hold is three
	seconds or nine, which is the reason the whole Vault Lock tree was once
	invisible to the thief standing in front of it -- the vault dial fixes that
	from the street, and this fixes the other half at arm's length. Over
	`Config.PROMPT_COUNTDOWN_OVER` seconds the bar is joined by a countdown, so
	a thief knows whether they are committing to one second or to twelve BEFORE
	they commit to it.

	`PromptButtonHoldEnded` FIRES AT COMPLETION, NOT ONLY ON RELEASE -- this
	project has that measured at 0.584s on a 0.6s prompt, and it fires BEFORE
	`Triggered`. So nothing here treats it as "cancelled"; it just stops the
	fill, and a completed hold is hidden a frame later anyway.

	----------------------------------------------------------------------

	NOTHING HERE IS ON A REPLICATION RACE, which is worth saying because two
	other features on this street were. `PromptShown` fires when a player walks
	up to a prompt, which is always long after everything has replicated -- so
	unlike the shop doors and the house neon there is nothing to rescan and no
	tag to miss.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)

local PromptUI = {}


local live: { [ProximityPrompt]: {
	gui: BillboardGui,
	fill: Frame,
	count: TextLabel,
	holdFrom: number?,
} } = {}

local started = false

-- What to press. A keyboard player gets the letter; everyone else gets a word,
-- because most of this audience is on a tablet where there is no key to name
-- and a floating "E" is a control they do not have.
local function keyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Touch then
		return if prompt.HoldDuration > 0 then "HOLD" else "TAP"
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		return "A"
	end
	local key = prompt.KeyboardKeyCode
	local name = if key ~= Enum.KeyCode.Unknown then key.Name else "E"
	return if prompt.HoldDuration > 0 then ("HOLD " .. name) else name
end

local function build(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	local adornee = prompt.Parent
	if not adornee or not adornee:IsA("BasePart") then
		return
	end
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end

	local style = Config.promptStyle(prompt:GetAttribute(Config.PROMPT_KIND_ATTRIBUTE) :: string?)

	local gui = Instance.new("BillboardGui")
	gui.Name = "PromptUI"
	gui.Adornee = adornee
	gui.Size = UDim2.new(0, 250, 0, 82)
	-- NOT offset by the prompt own UIOffset. That is a Vector2 in SCREEN
	-- PIXELS meant for the default prompt UI, and adding it to a Vector3 of
	-- studs THROWS -- which it did, loudly, on the first frame anybody walked
	-- up to a piggy. A custom card positions itself in studs and owes the
	-- default one nothing.
	gui.StudsOffset = Vector3.new(0, 1.6, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = prompt.MaxActivationDistance + 24
	gui.Parent = playerGui

	-- PAPER WITH AN INK OUTLINE, not a dark panel with a coloured edge.
	--
	-- The tone has not gone anywhere -- it is the chip ring, the verb and the
	-- hold bar -- but it stopped being the GROUND. Every card being a
	-- different-coloured dark rectangle is what made this look like a
	-- dashboard, and a pale card on bright grass needs a hard edge of its own
	-- rather than a 2px accent stroke.
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.new(1, 0, 1, 0)
	card.Parent = gui
	Theme.card(card, 16)

	-- THE CHIP: a dark disc with a tone RING. See the note at the top -- an
	-- emoji ignores TextColor3, so a disc in the tone would put a coloured
	-- picture on a matching ground and lose both.
	local chip = Instance.new("TextLabel")
	chip.Name = "Chip"
	chip.Size = UDim2.new(0, 44, 0, 44)
	chip.Position = UDim2.new(0, 11, 0.5, 0)
	chip.AnchorPoint = Vector2.new(0, 0.5)
	chip.TextSize = 24
	chip.Text = style.glyph
	chip.Parent = card
	Theme.chip(chip, 44, style.tone)

	-- The verb comes from the KIND, not from ActionText. A prompt's own text
	-- is what a service happened to type; the kind is what the action IS, and
	-- keeping the word here means the vocabulary stays in one table.
	local verb = Instance.new("TextLabel")
	verb.Name = "Verb"
	verb.Size = UDim2.new(1, -74, 0, 26)
	verb.Position = UDim2.new(0, 66, 0, 10)
	verb.TextXAlignment = Enum.TextXAlignment.Left
	verb.Text = style.verb
	-- Darkened against the paper it sits on. The tone is tuned to be seen on
	-- a dark panel, and `collect` is gold: measured at a contrast ratio of
	-- 1.4 against cream before this, which is a label you can see is there
	-- and cannot read.
	Theme.title(verb, 21, Theme.readable(style.tone))
	verb.Parent = card

	-- Whatever the site wanted to say underneath: whose piggy, which shop.
	-- ActionText is used as the SUBTITLE when it says something the verb does
	-- not, which is how "Crack Lock 3.5s" and a shop's own name still show.
	local detail = prompt.ObjectText
	if detail == "" or detail == nil then
		detail = prompt.ActionText
	end
	local sub = Instance.new("TextLabel")
	sub.Name = "Detail"
	sub.Size = UDim2.new(1, -78, 0, 18)
	sub.Position = UDim2.new(0, 66, 0, 34)
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextTruncate = Enum.TextTruncate.AtEnd
	sub.Text = detail
	Theme.body(sub, 13)
	sub.Parent = card

	local key = Instance.new("TextLabel")
	key.Name = "Key"
	key.AutomaticSize = Enum.AutomaticSize.X
	key.Size = UDim2.new(0, 0, 0, 20)
	key.Position = UDim2.new(1, -10, 0, 10)
	key.AnchorPoint = Vector2.new(1, 0)
	key.Text = " " .. keyText(prompt, inputType) .. " "
	key.Parent = card
	Theme.tinted(key, Theme.GOLD, Theme.GOLD_DEEP, 7)
	Theme.title(key, 12, Theme.INK)
	key.BackgroundTransparency = 0

	-- The hold track, along the bottom edge of the card.
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.new(1, -22, 0, 6)
	track.Position = UDim2.new(0, 11, 1, -12)
	track.BackgroundColor3 = Theme.PAPER_DEEP
	track.BorderSizePixel = 0
	track.Visible = prompt.HoldDuration > 0
	track.Parent = card
	Theme.corner(track, 4)
	Theme.outline(track, Theme.OUTLINE_THIN)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = style.tone
	fill.BorderSizePixel = 0
	fill.Parent = track
	Theme.corner(fill, 4)

	-- The countdown, for the holds long enough that a bar alone does not say
	-- how much of your evening this is going to take.
	local count = Instance.new("TextLabel")
	count.Name = "Countdown"
	count.Size = UDim2.new(0, 54, 0, 18)
	count.Position = UDim2.new(1, -10, 1, -34)
	count.AnchorPoint = Vector2.new(1, 0)
	count.TextXAlignment = Enum.TextXAlignment.Right
	count.Text = ""
	Theme.title(count, 14, Theme.readable(style.tone))
	count.Visible = prompt.HoldDuration > Config.PROMPT_COUNTDOWN_OVER
	count.Parent = card

	if count.Visible then
		count.Text = ("%.1fs"):format(prompt.HoldDuration)
	end

	-- A small pop on arrival. One tween, not a loop: this appears whenever
	-- anybody walks near anything, so it has to be cheap and it must never
	-- become something moving in the corner of the eye.
	card.Size = UDim2.new(0.86, 0, 0.86, 0)
	TweenService:Create(card, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.new(1, 0, 1, 0) }):Play()

	live[prompt] = { gui = gui, fill = fill, count = count, holdFrom = nil }
end

local function clear(prompt: ProximityPrompt)
	local entry = live[prompt]
	if not entry then
		return
	end
	live[prompt] = nil
	entry.gui:Destroy()
end

function PromptUI.start()
	if started then
		return
	end
	started = true

	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		-- Only ours. A prompt left on the default style is one somebody has
		-- not given a kind yet, and drawing a second card over Roblox's own
		-- would be worse than either alone.
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		clear(prompt)
		build(prompt, inputType)
	end)

	ProximityPromptService.PromptHidden:Connect(clear)

	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
		local entry = live[prompt]
		if entry then
			entry.holdFrom = os.clock()
		end
	end)

	-- NOT TREATED AS "CANCELLED". This fires at hold COMPLETION as well as on
	-- release -- measured elsewhere in this project at 0.584s on a 0.6s prompt,
	-- and before `Triggered`. All it does here is stop the fill.
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
		local entry = live[prompt]
		if entry then
			entry.holdFrom = nil
			entry.fill.Size = UDim2.new(0, 0, 1, 0)
		end
	end)

	-- One loop for every live prompt rather than one per card. In practice
	-- this is nought or one entry: a player stands in range of one thing at a
	-- time almost always, and the loop does nothing at all when the table is
	-- empty.
	RunService.RenderStepped:Connect(function()
		for prompt, entry in pairs(live) do
			local from = entry.holdFrom
			if from then
				local total = math.max(prompt.HoldDuration, 0.01)
				local t = math.clamp((os.clock() - from) / total, 0, 1)
				entry.fill.Size = UDim2.new(t, 0, 1, 0)
				if entry.count.Visible then
					entry.count.Text = ("%.1fs"):format(total * (1 - t))
				end
			end
		end
	end)

	-- A prompt destroyed while its card is up -- a bin torn down, a thief who
	-- got away -- would otherwise leave the card on screen for the rest of the
	-- session, adorned to nothing.
	Players.LocalPlayer.CharacterRemoving:Connect(function()
		for prompt in pairs(live) do
			clear(prompt)
		end
	end)
end

return PromptUI
