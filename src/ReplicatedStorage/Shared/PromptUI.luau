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

	TWO CARDS ON ONE PART, AND UNTIL NOW THERE WAS NEVER MORE THAN ONE.

	This file was built on a guarantee the game kept for it: prompts share a
	part in two places -- collect/steal on a piggy, hide/dig on a bin -- and in
	both the game makes them EXCLUSIVE, so every card could take the same
	`StudsOffset` and no offsetting logic was needed anywhere.

	The smash spends that guarantee on purpose. Steal and smash are the two
	ways into one pig and a choice you cannot see is not a choice, so both are
	live at once for the same player, on the same Body.

	`Config.PROMPT_SLOT_ATTRIBUTE` is what pays for it, and it is a SLOT rather
	than an offset for a measured reason. This card is sized in OFFSET pixels,
	so it is a fixed size on screen at every distance, while `StudsOffset` is a
	world displacement that projects to fewer pixels the further off you stand:
	the shipped 1.6 studs is about 152px at 5 studs and about 69px at
	`STEAL_RANGE`, against a card 82px tall. A stud offset would therefore
	separate the cards when you are on top of the pig and overlap them at
	exactly the range a thief decides from. Growing the BILLBOARD by the slot
	and pinning the card to its bottom edge is a constant pixel gap at every
	range, and slot 0 lands on the identical pixel the card has always used.

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
	watch: RBXScriptConnection?,
	watchText: { RBXScriptConnection },
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

-- The card, and the gap between two of them, in pixels. CARD_GAP is the card
-- plus a gutter, so slot 1 clears slot 0 with daylight rather than by a pixel.
local CARD_H = 82
local CARD_GAP = 94

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
	-- SLOT 0 IS BYTE-IDENTICAL TO WHAT THIS ALWAYS DREW, which is the property
	-- that makes this safe to add to ten existing prompts at once. The billboard
	-- is centred on the adornee, so growing it by `2 * slot * CARD_GAP` extends
	-- it `slot * CARD_GAP` DOWNWARD past the anchor; the card is pinned to that
	-- bottom edge, so it sits exactly that many pixels lower. At slot 0 the
	-- growth is zero and a bottom-pinned card in an 82-tall box is the same
	-- rectangle as a card filling it.
	local slot = tonumber(prompt:GetAttribute(Config.PROMPT_SLOT_ATTRIBUTE)) or 0
	gui.Size = UDim2.new(0, 250, 0, CARD_H + 2 * slot * CARD_GAP)
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
	card.Size = UDim2.new(1, 0, 0, CARD_H)
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Position = UDim2.new(0.5, 0, 1, 0)
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
	local sub = Instance.new("TextLabel")
	sub.Name = "Detail"
	sub.Size = UDim2.new(1, -78, 0, 18)
	sub.Position = UDim2.new(0, 66, 0, 34)
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextTruncate = Enum.TextTruncate.AtEnd
	Theme.body(sub, 13)
	sub.Parent = card

	-- READ EVERY TIME IT CHANGES, NOT ONCE AT BUILD.
	--
	-- This card is built on PromptShown and used to never look at the prompt
	-- again, so anything a service wrote to ObjectText while a player was
	-- already standing there simply never appeared. Caught by the steal
	-- prompt, which flips to naming your haul the moment you pick loot up:
	-- the line was being written correctly and the card went on showing the
	-- lock. It was latent for every other site too.
	local function setDetail()
		local text = prompt.ObjectText
		if text == "" or text == nil then
			text = prompt.ActionText
		end
		sub.Text = text
	end
	setDetail()

	-- WHAT THIS IS WORTH, beside the verb.
	--
	-- Gold, because gold means money everywhere else in this game, and
	-- GOLD_INK rather than GOLD because this prints on PAPER: raw gold on the
	-- card measures 1.42:1 and is a label you can see is there and cannot
	-- read. The darkened form measures 4.87:1.
	--
	-- NOT A PILL, deliberately. The key chip on the row above is already a
	-- gold pill, and a second one beside it reads as two of the same control
	-- rather than as a price. Plain gold type says money without competing.
	--
	-- It sits on the DETAIL row rather than the verb row, which is where it
	-- started: the verb row has "STEAL" at 60px and the key pill at 46px in a
	-- 176px budget, so a late-game "~999.9M" at 56px left the verb two pixels
	-- to truncate into. The detail row carries a 94px lock line in the same
	-- 176, so the amount fits with room measured to spare.
	local amount = Instance.new("TextLabel")
	amount.Name = "Amount"
	-- 64 rather than 84: right-aligned text does not draw outside its own box,
	-- but an 84-wide one OVERLAPPED the detail beside it by 20px -- invisible
	-- today and exactly the kind of thing that starts clipping the first time
	-- either string grows. The widest amount this can hold is "~999.9M" at
	-- 56px, so 64 fits it and leaves the detail its own ground.
	amount.Size = UDim2.new(0, 64, 0, 18)
	amount.Position = UDim2.new(1, -10, 0, 34)
	amount.AnchorPoint = Vector2.new(1, 0)
	amount.TextXAlignment = Enum.TextXAlignment.Right
	amount.Text = ""
	amount.Visible = false
	Theme.title(amount, 16, Theme.GOLD_INK)
	amount.Parent = card

	-- The detail gives up the width the amount takes, and takes it back when
	-- there is no amount -- which is what lets the steal prompt's carrying
	-- line use the whole row: measured at 160px of the 172 this box actually
	-- is. Note 172 and not the 176 a first pass assumed from the card width;
	-- the offset is -78 on a 250 card starting at x66.
	local function setAmount(text: string?)
		local shown = type(text) == "string" and text ~= ""
		amount.Visible = shown
		amount.Text = if shown then text :: string else ""
		sub.Size = if shown then UDim2.new(1, -152, 0, 18) else UDim2.new(1, -78, 0, 18)
	end
	setAmount(prompt:GetAttribute(Config.PROMPT_AMOUNT_ATTRIBUTE) :: string?)

	-- WATCHED RATHER THAN READ ONCE, because the number moves while the card
	-- is on screen. A victim's piggy fills every second, and picking loot up
	-- turns the take into a refusal -- and this card is built on PromptShown
	-- and never looks at the prompt again, so without this it would freeze on
	-- whatever was true the moment somebody walked up.
	local watch = prompt:GetAttributeChangedSignal(Config.PROMPT_AMOUNT_ATTRIBUTE):Connect(function()
		setAmount(prompt:GetAttribute(Config.PROMPT_AMOUNT_ATTRIBUTE) :: string?)
	end)
	local watchText = {
		prompt:GetPropertyChangedSignal("ObjectText"):Connect(setDetail),
		prompt:GetPropertyChangedSignal("ActionText"):Connect(setDetail),
	}

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
	-- Four pixels lower than it was, so it clears the amount above it: the
	-- amount occupies y34..52 and this now runs y52..70, ending exactly where
	-- the hold track starts. They shared the right-hand corner before.
	count.Position = UDim2.new(1, -10, 1, -30)
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
	--
	-- IN THE CARD'S OWN UNITS, WHICH IS NOT WHERE THIS STARTED. It popped to a
	-- SCALE height -- `UDim2.new(1, 0, 1, 0)` -- which was right for as long as
	-- a card filled its billboard, and silently undid the slot the moment one
	-- did not: the card grew back to the full 270px box and landed on top of
	-- its neighbour. Measured on a live client, `card.Size` read `{1,0},{1,0}`
	-- while the source three hundred lines up plainly said `{1,0},{0,82}`, and
	-- the AnchorPoint and Position beside it were the new ones -- which is what
	-- said the fault was a LATER WRITE rather than a stale module.
	--
	-- The general shape is one this project already records from the other end:
	-- when a property is set in two places, the second one wins and the first
	-- one reads like the bug. Grep the property, not the line you changed.
	card.Size = UDim2.new(0.86, 0, 0, CARD_H * 0.86)
	TweenService:Create(card, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.new(1, 0, 0, CARD_H) }):Play()

	live[prompt] = { gui = gui, fill = fill, count = count, holdFrom = nil,
		watch = watch, watchText = watchText }
end

local function clear(prompt: ProximityPrompt)
	local entry = live[prompt]
	if not entry then
		return
	end
	live[prompt] = nil
	if entry.watch then
		entry.watch:Disconnect()
	end
	for _, c in ipairs(entry.watchText or {}) do
		c:Disconnect()
	end
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

	-- A PROMPT ON YOUR OWN BODY IS NEVER FOR YOU, and that is an invariant of
	-- this design rather than a special case for one item.
	--
	-- Exactly one prompt in this game lives on a character: the tag prompt,
	-- which `attachLoot` welds to the THIEF -- on purpose, because it is there
	-- so that everybody ELSE can reach it. Nothing here is ever meant to be
	-- acted on by the person wearing it, so the general rule is the honest one
	-- and a future prompt that wants to break it is a design mistake meeting a
	-- documented wall rather than a silent bug.
	--
	-- `Enabled` written from a client affects only THIS machine's view, which
	-- is the only per-player prompt Roblox offers. The server refuses a
	-- self-tag outright regardless; this is the client declining to ask for a
	-- known no, the same split the number keys and the dodge-while-riding
	-- suppression already make. Without it the refusal would be silent and
	-- invisible -- a thief holding a button on their own chest that does
	-- nothing, which is the one failure this project refuses above all others.
	local function disown(inst: Instance)
		if inst:IsA("ProximityPrompt") then
			inst.Enabled = false
		end
	end
	local function disownCharacter(character: Model)
		for _, d in ipairs(character:GetDescendants()) do
			disown(d)
		end
		-- The loot is welded on AFTER the character exists -- a slice at a
		-- time, mid-robbery -- so walking it once is not enough.
		character.DescendantAdded:Connect(disown)
	end
	if Players.LocalPlayer.Character then
		disownCharacter(Players.LocalPlayer.Character)
	end
	Players.LocalPlayer.CharacterAdded:Connect(disownCharacter)

	-- AND THE INVERSE: A PROMPT THAT NAMES AN OWNER IS FOR NOBODY ELSE.
	--
	-- Same instrument as the rule above and the opposite direction. A
	-- mailbox belongs to one plot and one player, so on every other screen
	-- it is a control that looks available and does nothing -- which is the
	-- failure this file refuses above all others, and the reason the number
	-- row declines to ask for an item you do not hold.
	--
	-- `Enabled` written here affects only THIS machine's view, which is the
	-- only per-player prompt Roblox offers. The server re-checks the owner on
	-- the trigger regardless: this is the client declining a known no, never
	-- the guard.
	--
	-- WATCHED RATHER THAN READ ONCE, because a plot changes hands. It is set
	-- on assign and cleared on release, and a prompt that read it at build
	-- time would be answering for whoever lived there when the server
	-- started.
	-- IT MAY ONLY EVER TURN A PROMPT OFF, NEVER ON, and the first version got
	-- that wrong in a way worth recording.
	--
	-- Written as `Enabled = (owner == me)` it reads as the same rule and is a
	-- SECOND WRITER: the server turns a mailbox off when there is nothing in
	-- it, and this switched it straight back on for the owner. Measured -- the
	-- flag lying flat over a box whose prompt was live, which is precisely the
	-- disagreement `setMail` exists to make impossible, reintroduced one layer
	-- further out.
	--
	-- A client-side rule here is a REFUSAL and nothing else. Whether a prompt
	-- should be available at all is the server's answer; this only ever
	-- subtracts from it, which is the same shape as the number row declining
	-- an item you do not hold.
	local function ownerRule(prompt: ProximityPrompt)
		local owner = prompt:GetAttribute(Config.PROMPT_OWNER_ATTRIBUTE)
		if owner ~= nil and owner ~= Players.LocalPlayer.UserId then
			prompt.Enabled = false
		end
	end
	local function watchOwner(inst: Instance)
		if not inst:IsA("ProximityPrompt") then
			return
		end
		local prompt = inst :: ProximityPrompt
		-- EVERY PROMPT, RATHER THAN ONLY THE ONES THAT CARRY AN OWNER TODAY.
		--
		-- This used to skip anything with no owner attribute, with `MailPrompt`
		-- named by hand as the exception -- because an unowned plot's mailbox
		-- has no owner until somebody moves in, and a prompt skipped at build
		-- time would never be watching when one arrived. That worked and it
		-- coupled a renderer to one prompt's NAME, so the doorstep crate would
		-- have been a second hardcoded name and the third would have been
		-- forgotten -- silently, since a missed prompt merely fails to refuse.
		--
		-- Watching all of them costs one changed-signal per prompt in the
		-- world, and `ownerRule` only ever REFUSES, so a prompt that never
		-- gains an owner is untouched by construction.
		ownerRule(prompt)
		prompt:GetAttributeChangedSignal(Config.PROMPT_OWNER_ATTRIBUTE)
			:Connect(function()
				ownerRule(prompt)
			end)
		-- The SERVER also writes Enabled, when the flag goes up and down. Its
		-- write replicates and would otherwise switch somebody else's mailbox
		-- back on over the top of this rule.
		prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
			if prompt.Enabled then
				ownerRule(prompt)
			end
		end)
	end
	-- A PLOT IS BUILT AT SERVER STARTUP, SO ITS PROMPTS ARRIVE ALREADY
	-- ATTRIBUTED -- and `GetAttributeChangedSignal` reports a CHANGE on this
	-- peer, which never happens for a value the server set before parenting.
	-- The shop doors lost every one of their prompts to exactly this, and the
	-- fix there is the fix here: sweep what is already present, then listen
	-- for arrivals.
	for _, inst in ipairs(workspace:GetDescendants()) do
		watchOwner(inst)
	end
	workspace.DescendantAdded:Connect(watchOwner)

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
