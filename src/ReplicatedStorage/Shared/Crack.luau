--!strict
--
-- THE CRACK PANEL -- THE GREED DIAL, DRAWN AS A LOCK ("POP THE PINS").
--
-- The one moment in this game where standing still is the point, so it is the
-- one moment that has to be worth looking at. Two readouts, and they answer
-- two different questions:
--
--   * THE PIG, DRAINING. A slim gauge that starts full of the victim's coins
--     and empties as slices come out of it. This is the GREED half: it is the
--     thing you are deciding about, and the fact that it visibly goes down is
--     what makes taking one more feel like taking one more.
--   * THE LOCK. Five pins, one per slice. The active pin rides the server's
--     sweeping marker and has to be caught with its gold collar in the
--     turquoise notch. This is the SKILL half. The victim's Vault Lock makes
--     it harder (`Config.CRACK_LOCKS`: narrower notch, faster pin, a notch
--     that drifts) and the thief's Lockpicks forgive it -- a spare pick turns
--     a miss into a pin that snaps back and tries again.
--
-- WHY PINS RATHER THAN THE OLD BAR. The bar showed one step at a time, so a
-- run had no shape: slice three looked exactly like slice one. Five channels
-- make the run physical -- how far in you are and how much is still at risk
-- are both things you can SEE -- which is the push-your-luck decision drawn
-- as an object. Art: assets/ui/pop-the-pins-v1, cropped and packed into three
-- atlases by blender/ui/pack_pop_the_pins.py.
--
-- THE BAR IS THE PIG AND NOT THE ALLOWANCE. Drawing `Config.LOSS_CAP`'s
-- remaining allowance as the whole bar makes the gauge mean "how much of what
-- I am permitted", which is a rule a nine-year-old has never been told and
-- cannot see. Drawing the PIG means the gauge is a picture of the object in
-- front of them, and the cap is a RED LINE across it. A resident has no cap,
-- so its line is not drawn and the bar can empty completely.
--
-- NOTHING HERE DECIDES ANYTHING. The server owns the clock, the zone, the
-- slice and whether a tap landed; `CrackTap` carries no arguments at all. All
-- this module does is render the schedule it is handed and send the moment a
-- finger goes down. The pin is drawn from `workspace:GetServerTimeNow` against
-- the `startedAt` in that schedule, so both ends are reading one clock rather
-- than two that have to be kept in step. The notch is the server's zone over
-- the COLLAR's travel, padded by half a collar at each end, so "the collar is
-- in the notch" and "the server will call it a hit" are the same picture.
--
-- A MODULE, NOT A SECTION OF ClientMain, for the reason HouseFX, HotBar,
-- RobBadge and AdminPanel are: that chunk is at Luau's 200-local ceiling and
-- has twice died naming an innocent variable two thousand lines from the
-- change that caused it. A module body gets its own register file, so this
-- costs ClientMain one statement holding no local at all.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Config = require(ReplicatedStorage.Shared.Config)
local SoundKit = require(ReplicatedStorage.Shared.SoundKit)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local RobberyLoot = require(ReplicatedStorage.Shared.RobberyLoot)

local Crack = {}

-- The three sheets and every sprite's rect in them (atlas.json beside the
-- PNGs). Packed so no sheet is over 1024 on a side, because Roblox downscales
-- anything larger and would silently invalidate these pixel rects.
local ART = {
	housing = "rbxassetid://125952317701443",
	parts = "rbxassetid://82492071315088",
	buttons = "rbxassetid://86556901635342",
}
local RECT = {
	housing = { 0, 0, 1024, 557 },
	pinIdle = { 0, 0, 295, 843 },
	pinActive = { 299, 0, 295, 843 },
	pinSet = { 598, 0, 295, 843 },
	spring = { 897, 0, 124, 317 },
	cap = { 0, 847, 250, 161 },
	notch = { 254, 847, 582, 143 },
	check = { 840, 847, 162, 157 },
	tap = { 0, 0, 501, 166 },
	tapDown = { 505, 0, 501, 166 },
	stop = { 0, 170, 495, 155 },
	stopDown = { 499, 170, 495, 155 },
}
local HOUSING_ASPECT = 557 / 1024

-- The kit's layout, as fractions of the DISPLAYED housing (see its README).
-- Five channels because `Config.CRACK.maxSteps` is five: a sixth slice would
-- need a sixth channel drawn into the housing, not a sixth pin squeezed in.
local CHANNELS = { 0.145, 0.322, 0.499, 0.676, 0.853 }
local PIN_W, PIN_H = 0.060, 0.316
-- Pin travel. Marker 0 holds the pin up against its spring and marker 1 lets
-- it all the way down. The kit's own range is 0.30..0.48; it is opened to
-- 0.28 so a narrow window is still a readable number of pixels of travel.
local PIN_TOP_HI, PIN_TOP_LO = 0.28, 0.48
local TRAVEL = PIN_TOP_LO - PIN_TOP_HI
local COLLAR = PIN_H * 0.5
local CAP_W, CAP_H, CAP_TOP = 0.068, 0.080, 0.17
local SPRING_W, SPRING_TOP = 0.039, 0.234
local NOTCH_W, NOTCH_H = 0.106, 0.062
local CHECK_W, CHECK_H = 0.049, 0.088
local NUMBER_Y = 0.905

local function pinTop(marker: number): number
	return PIN_TOP_HI + TRAVEL * math.clamp(marker, 0, 1)
end

-- Measured against the shortest thing that has to work, a phone held
-- sideways at 546 tall. The panel is centred horizontally and sits 96 above
-- the bottom edge: the hot bar occupies 20..74 there and grows upward with
-- however many throwables are held, so this clears its tallest state by 22.
-- The lock is taller than the old bar was, so `fit` scales the whole panel
-- down on a short screen rather than letting it climb into the view.
local WIDTH = 430
local LIFT = 96
local PAD = 14
local BUTTON_H = 46

type Pin = {
	pin: ImageLabel,
	spring: ImageLabel,
	check: ImageLabel,
	checkScale: UIScale,
	number: TextLabel,
	ring: UIStroke,
}

local ui: {
	root: Frame,
	title: TextLabel,
	step: TextLabel,
	held: TextLabel,
	nextText: TextLabel,
	left: TextLabel,
	fill: Frame,
	line: Frame,
	nextSlice: Frame,
	spares: TextLabel,
	housing: ImageButton,
	flashText: TextLabel,
	notch: ImageLabel,
	pins: { Pin },
	odds: TextLabel,
	tiers: TextLabel,
	pressTap: (boolean) -> (),
	pressStop: (boolean) -> (),
}? = nil

local state: any = nil
local heartbeat: RBXScriptConnection? = nil
-- Where each seated pin came to rest this attempt, as a marker position: the
-- centre of the notch it was caught in. So a seated pin stays where it was
-- set rather than jumping to one shared height.
local seated: { [number]: number } = {}
-- Where the active pin was last drawn, 0..1. A slice that lands seats its pin
-- exactly here: the server judged the collar in the notch at that moment, so
-- this is where the player saw it caught -- drifting notch or not.
local lastAt = 0

local function tap()
	if state then
		Remotes.get("CrackTap"):FireServer()
	end
end

local function stop()
	if state then
		Remotes.get("CrackStop"):FireServer()
	end
end

local function sprite(image: ImageLabel | ImageButton, sheet: string, rect: { number })
	image.Image = ART[sheet]
	image.ImageRectOffset = Vector2.new(rect[1], rect[2])
	image.ImageRectSize = Vector2.new(rect[3], rect[4])
	image.BackgroundTransparency = 1
end

local function part(name: string, rect: { number }, z: number, parent: Instance): ImageLabel
	local image = Instance.new("ImageLabel")
	image.Name = name
	sprite(image, "parts", rect)
	image.AnchorPoint = Vector2.new(0.5, 0)
	image.ZIndex = z
	image.Parent = parent
	return image
end

-- A pill button from the kit. SLICED, so the rounded ends keep their shape
-- however wide the layout makes it: the art is not 9-slice calibrated, but
-- its caps are plain enough that a slice through the straight middle does not
-- show. The whole button is the tap target, and it wears the pressed art
-- while held -- and briefly on the keyboard shortcut -- so a press is felt.
local function pill(name: string, text: string, up: { number }, down: { number },
	key: string, parent: Instance): (ImageButton, (boolean) -> ())
	local b = Instance.new("ImageButton")
	b.Name = name
	sprite(b, "buttons", up)
	b.ScaleType = Enum.ScaleType.Slice
	b.SliceCenter = Rect.new(84, 48, up[3] - 84, up[4] - 48)
	b.AutoButtonColor = false
	b.ZIndex = 7
	b.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, 0, 1, -6)
	label.Text = text
	label.ZIndex = 8
	label.Parent = b
	Theme.title(label, 17)

	-- The key, on a keyboard only. Most of this audience never presses one,
	-- and a chip reading "F" on a tablet names a control that does not exist.
	if UserInputService.KeyboardEnabled then
		local chip = Instance.new("TextLabel")
		chip.Name = "Key"
		chip.AnchorPoint = Vector2.new(0, 0.5)
		chip.Position = UDim2.new(0, 12, 0.5, -3)
		chip.Size = UDim2.fromOffset(if #key > 1 then 30 else 22, 22)
		chip.Text = key
		chip.ZIndex = 8
		chip.Parent = b
		Theme.title(chip, 12, Theme.PAPER)
		chip.BackgroundTransparency = 0
		chip.BackgroundColor3 = Theme.INK
		Theme.corner(chip, 6)
		-- The label steps right of the chip rather than under it, or "Esc"
		-- sits on top of TAKE & RUN.
		local clear = 12 + chip.Size.X.Offset + 4
		label.Position = UDim2.fromOffset(clear, 0)
		label.Size = UDim2.new(1, -clear - 8, 1, -6)
	end
	local rest = label.Position

	local function press(isDown: boolean)
		sprite(b, "buttons", if isDown then down else up)
		label.Position = rest + UDim2.fromOffset(0, if isDown then 2 else 0)
	end
	b.MouseButton1Down:Connect(function() press(true) end)
	b.MouseButton1Up:Connect(function() press(false) end)
	b.MouseLeave:Connect(function() press(false) end)
	return b, press
end

local function build(parent: Instance)
	local root = Instance.new("Frame")
	root.Name = "CrackPanel"
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.new(0.5, 0, 1, -LIFT)
	root.Size = UDim2.fromOffset(WIDTH, 400)
	root.Visible = false
	root.ZIndex = 6
	root.Parent = parent
	Theme.card(root)
	local panelScale = Instance.new("UIScale")
	panelScale.Parent = root

	-- ---- header ------------------------------------------------------
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.Text = ""
	title.Parent = root
	Theme.title(title, 17)

	local step = Instance.new("TextLabel")
	step.Name = "Step"
	step.TextXAlignment = Enum.TextXAlignment.Right
	step.Text = ""
	step.Parent = root
	Theme.body(step, 12, Theme.MUTED)

	-- ---- the pig, draining -------------------------------------------
	--
	-- A slim strip over the lock. The pins say how far into the RUN you are;
	-- this says how much of the PIG is left, where the loss cap stops you,
	-- and -- the segment in deep gold -- what the next pin is worth. That
	-- segment grows 1.4x every pin, which is the greed dial as a picture, and
	-- a lock alone cannot show it.
	--
	-- The snout stands BESIDE the track rather than on it: the track is pink,
	-- and a pink snout on a pink bar is an accent spent on a ground.
	local snout = Theme.snout(root, 18, "Snout")
	snout.ZIndex = 6

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = Theme.PIG_DEEP
	track.BorderSizePixel = 0
	track.ZIndex = 6
	track.Parent = root
	Theme.corner(track, 6)
	Theme.outline(track, Theme.OUTLINE_THIN)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Theme.GOLD
	fill.BorderSizePixel = 0
	fill.ZIndex = 7
	fill.Parent = track
	Theme.corner(fill, 6)
	Theme.gloss(fill, Theme.GOLD, Theme.GOLD_DEEP)

	local nextSlice = Instance.new("Frame")
	nextSlice.Name = "NextSlice"
	nextSlice.Size = UDim2.fromScale(0, 1)
	nextSlice.BackgroundColor3 = Theme.GOLD_DEEP
	nextSlice.BorderSizePixel = 0
	nextSlice.ZIndex = 8
	nextSlice.Visible = false
	nextSlice.Parent = track
	Theme.corner(nextSlice, 6)

	-- WHERE THE LOSS CAP STOPS YOU, drawn on TOP of the fill because it is a
	-- mark on the pig rather than a section of it, and in the one colour on
	-- this panel that means "no further".
	local line = Instance.new("Frame")
	line.Name = "CapLine"
	line.Size = UDim2.new(0, 3, 1, 0)
	line.BackgroundColor3 = Theme.STOP
	line.BorderSizePixel = 0
	line.ZIndex = 8
	line.Visible = false
	line.Parent = track

	-- SPARE PICKS, the Lockpicks tree made visible: how many misses this
	-- crack will still forgive. Hidden when there are none, which is every
	-- crack for a player who has not bought the rung.
	local sparesLabel = Instance.new("TextLabel")
	sparesLabel.Name = "Spares"
	sparesLabel.TextXAlignment = Enum.TextXAlignment.Right
	sparesLabel.Text = ""
	sparesLabel.Visible = false
	sparesLabel.Parent = root
	Theme.body(sparesLabel, 11, Theme.GOOD_INK)

	-- ---- the lock ----------------------------------------------------
	--
	-- THE WHOLE LOCK IS A TAP TARGET as well as SET PIN, and that is not
	-- laziness: most of this audience is on a tablet, and a control you have
	-- to hit a moving pin to press is a second reaction test stacked on the
	-- one the game is asking for. Press anywhere; WHEN is the whole question.
	local housing = Instance.new("ImageButton")
	housing.Name = "Lock"
	sprite(housing, "housing", RECT.housing)
	housing.AutoButtonColor = false
	housing.ZIndex = 6
	housing.Parent = root

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.AnchorPoint = Vector2.new(0.5, 0)
	hint.Position = UDim2.fromScale(0.5, 0.05)
	hint.Size = UDim2.fromScale(0.8, 0.07)
	hint.Text = "LINE UP THE GOLD COLLAR WITH THE NOTCH"
	hint.TextScaled = true
	hint.ZIndex = 12
	hint.Parent = housing
	Theme.title(hint, 12)

	-- A forgiven miss says so over the lock for a moment, or the pin simply
	-- jumping back reads as the game stuttering.
	local flashText = Instance.new("TextLabel")
	flashText.Name = "Forgiven"
	flashText.AnchorPoint = Vector2.new(0.5, 0.5)
	flashText.Position = UDim2.fromScale(0.5, 0.5)
	flashText.Size = UDim2.fromScale(0.7, 0.16)
	flashText.Text = "SPARE PICK USED!"
	flashText.TextScaled = true
	flashText.ZIndex = 14
	flashText.Visible = false
	flashText.Parent = housing
	Theme.title(flashText, 20, Theme.PAPER)
	flashText.TextStrokeTransparency = 0
	flashText.TextStrokeColor3 = Theme.INK

	-- The notch sits BEHIND the pins and is resized every slice to the
	-- server's window. Sliced, so a tall window grows the hollow rather than
	-- thickening its rim.
	local notch = part("Notch", RECT.notch, 7, housing)
	notch.ScaleType = Enum.ScaleType.Slice
	notch.SliceCenter = Rect.new(40, 40, RECT.notch[3] - 40, RECT.notch[4] - 40)
	notch.Visible = false

	local pins: { Pin } = {}
	for i, x in ipairs(CHANNELS) do
		local spring = part("Spring" .. i, RECT.spring, 8, housing)
		spring.Position = UDim2.fromScale(x, SPRING_TOP)

		local cap = part("Cap" .. i, RECT.cap, 10, housing)
		cap.Size = UDim2.fromScale(CAP_W, CAP_H)
		cap.Position = UDim2.fromScale(x, CAP_TOP)

		local pin = part("Pin" .. i, RECT.pinIdle, 9, housing)
		pin.Size = UDim2.fromScale(PIN_W, PIN_H)

		local check = part("Check" .. i, RECT.check, 11, housing)
		check.AnchorPoint = Vector2.new(0.5, 0.5)
		check.Size = UDim2.fromScale(CHECK_W, CHECK_H)
		check.Visible = false
		local checkScale = Instance.new("UIScale")
		checkScale.Parent = check

		-- The number is native UI, as the kit asks: text is never baked in.
		local number = Instance.new("TextLabel")
		number.Name = "Number" .. i
		number.AnchorPoint = Vector2.new(0.5, 0.5)
		number.Position = UDim2.fromScale(x, NUMBER_Y)
		number.Size = UDim2.fromScale(0.052, 0.052 / HOUSING_ASPECT)
		number.Text = tostring(i)
		number.TextScaled = true
		number.ZIndex = 11
		number.Parent = housing
		Theme.title(number, 12, Theme.PAPER)
		number.BackgroundTransparency = 0
		number.BackgroundColor3 = Theme.INK
		Theme.corner(number, 99)
		local ring = Theme.outline(number, Theme.OUTLINE_THIN, Theme.INK)
		local numberPad = Instance.new("UIPadding")
		numberPad.PaddingTop = UDim.new(0.16, 0)
		numberPad.PaddingBottom = UDim.new(0.16, 0)
		numberPad.Parent = number

		pins[i] = { pin = pin, spring = spring, check = check, checkScale = checkScale, number = number, ring = ring }
	end

	-- ---- readouts ----------------------------------------------------
	local function readout(name: string, align: Enum.TextXAlignment, colour: Color3): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.TextXAlignment = align
		label.Text = ""
		label.Parent = root
		Theme.body(label, 12, colour)
		return label
	end
	local held = readout("Held", Enum.TextXAlignment.Left, Theme.GOLD_INK)
	local nextText = readout("Next", Enum.TextXAlignment.Center, Theme.INK)
	local left = readout("Left", Enum.TextXAlignment.Right, Theme.MUTED)

	local odds = Instance.new("TextLabel")
	odds.Name, odds.BackgroundTransparency, odds.Text = "LootOdds", 1, ""
	odds.Font, odds.TextSize, odds.TextColor3 = Theme.FONT, 12, Theme.INK
	odds.TextScaled, odds.Parent = true, root
	local tiers = odds:Clone()
	tiers.Name = "RarityOdds"
	tiers.TextWrapped, tiers.Parent = true, root
	-- Scaled text grows to fill its box, so a short line like "Coins only"
	-- came out twice the size of everything around it. Capped, it still
	-- shrinks to fit a long odds line and never shouts over the pins.
	for _, label in ipairs({ odds, tiers }) do
		local cap = Instance.new("UITextSizeConstraint")
		cap.MaxTextSize = if label == odds then 13 else 12
		cap.Parent = label
	end

	-- ---- actions -----------------------------------------------------
	--
	-- TAKE & RUN sits to the LEFT of SET PIN, because the loud one belongs
	-- under the thumb that is already there, and a bail button by the screen
	-- edge is the one a panicking nine-year-old reaches for by mistake.
	local stopBtn, stopPress = pill("Stop", "TAKE & RUN", RECT.stop, RECT.stopDown, "Esc", root)
	local tapBtn, tapPress = pill("Tap", "SET PIN", RECT.tap, RECT.tapDown, "F", root)

	-- EVERY POSITION IS DERIVED FROM THE WIDTH. The lock keeps its aspect, so
	-- its height -- and everything under it -- follows the panel's width.
	-- Returns the panel's height at that width.
	local function layout(width: number): number
		local w = width - PAD * 2
		local lockH = math.floor(w * HOUSING_ASPECT)
		local y = PAD
		title.Position, title.Size = UDim2.fromOffset(PAD, y), UDim2.fromOffset(w - 136, 20)
		step.Position, step.Size = UDim2.fromOffset(PAD + w - 136, y), UDim2.fromOffset(136, 20)
		y += 26
		snout.Position = UDim2.fromOffset(PAD, y - 3)
		local sparesW = if sparesLabel.Visible then 96 else 0
		track.Position, track.Size = UDim2.fromOffset(PAD + 24, y), UDim2.fromOffset(w - 24 - sparesW, 12)
		sparesLabel.Position, sparesLabel.Size = UDim2.fromOffset(PAD + w - sparesW, y - 3), UDim2.fromOffset(sparesW, 18)
		y += 18
		housing.Position, housing.Size = UDim2.fromOffset(PAD, y), UDim2.fromOffset(w, lockH)
		y += lockH + 6
		local third = math.floor(w / 3)
		held.Position, held.Size = UDim2.fromOffset(PAD, y), UDim2.fromOffset(third, 16)
		nextText.Position, nextText.Size = UDim2.fromOffset(PAD + third, y), UDim2.fromOffset(third, 16)
		left.Position, left.Size = UDim2.fromOffset(PAD + third * 2, y), UDim2.fromOffset(w - third * 2, 16)
		y += 18
		odds.Position, odds.Size = UDim2.fromOffset(PAD, y), UDim2.fromOffset(w, 16)
		y += 17
		tiers.Position, tiers.Size = UDim2.fromOffset(PAD, y), UDim2.fromOffset(w, 24)
		y += 28
		local stopW = math.floor(w * 0.42)
		stopBtn.Position, stopBtn.Size = UDim2.fromOffset(PAD, y), UDim2.fromOffset(stopW, BUTTON_H)
		tapBtn.Position, tapBtn.Size = UDim2.fromOffset(PAD + stopW + 8, y), UDim2.fromOffset(w - stopW - 8, BUTTON_H)
		-- A slice renders its border at SliceScale times its source pixels,
		-- so the pill caps and the notch rim are scaled to what is on screen.
		stopBtn.SliceScale = BUTTON_H / RECT.stop[4]
		tapBtn.SliceScale = BUTTON_H / RECT.tap[4]
		-- The notch rim renders a touch heavier than true scale: at true scale it
		-- is a two-pixel hairline, and it is the target.
		notch.SliceScale = math.max(0.02, 1.6 * NOTCH_W * w / RECT.notch[3])
		return y + BUTTON_H + PAD
	end

	local function fit()
		local view = (parent :: ScreenGui).AbsoluteSize
		local scale = math.min(1, math.max(0.5, (view.Y - LIFT - 8) / layout(WIDTH)))
		panelScale.Scale = scale
		local width = math.min(WIDTH, (view.X - 24) / scale)
		root.Size = UDim2.fromOffset(width, layout(width))
	end
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	sparesLabel:GetPropertyChangedSignal("Visible"):Connect(fit)
	fit()

	ui = {
		root = root,
		title = title,
		step = step,
		held = held,
		nextText = nextText,
		left = left,
		fill = fill,
		line = line,
		nextSlice = nextSlice,
		spares = sparesLabel,
		housing = housing,
		flashText = flashText,
		notch = notch,
		pins = pins,
		odds = odds,
		tiers = tiers,
		pressTap = tapPress,
		pressStop = stopPress,
	}

	housing.Activated:Connect(tap)
	tapBtn.Activated:Connect(tap)
	stopBtn.Activated:Connect(stop)
end

-- Seats a pin's top at `top` and stretches its spring down to meet it, from
-- the same value so the two cannot come apart.
local function placePin(p: Pin, x: number, top: number)
	p.pin.Position = UDim2.fromScale(x, top)
	p.spring.Size = UDim2.fromScale(SPRING_W, math.max(0, top + 0.006 - SPRING_TOP))
	p.check.Position = UDim2.fromScale(x, top + COLLAR)
end

-- The notch's near edge at server time `t` -- the same function the server
-- judges with (`HeistService` zoneAt): it rests at `zone` and, on a drifting
-- lock, swings `drift` either side over `driftPeriod`.
local function zoneAt(st: any, t: number): number
	local drift = st.drift or 0
	if drift <= 0 then
		return st.zone
	end
	return st.zone + drift * math.sin((t - st.startedAt) / st.driftPeriod * math.pi * 2)
end

local function placeNotch(u: any, st: any, t: number)
	local x = CHANNELS[st.step]
	if x then
		local topCollar = PIN_TOP_HI + COLLAR + TRAVEL * zoneAt(st, t)
		u.notch.Position = UDim2.fromScale(x, topCollar - NOTCH_H / 2)
	end
end

-- Repaints everything that only changes when the server says so.
local function render()
	local u = ui
	if not u then
		return
	end
	if not state then
		u.root.Visible = false
		return
	end

	local pig = math.max(1, state.pig)
	local remaining = math.max(0, pig - state.banked)

	u.root.Visible = true
	u.odds.Text, u.tiers.Text = RobberyLoot.describe(state.loot)
	-- A NAME THAT ALREADY ENDS IN S TAKES A BARE APOSTROPHE: "PIGGY
	-- OUTFITTERS' PIGGY", never "OUTFITTERS'S". The names are right; it is
	-- the possessive that has to know the rule, and `Config.possessive` is
	-- the one place it is written.
	u.title.Text = string.upper(("%s piggy"):format(Config.possessive(state.victim)))
	local lock = state.lock
	u.step.Text = if type(lock) == "number" and lock > 0
		then ("LOCK LV.%d · PIN %d / %d"):format(lock, state.step, state.maxSteps)
		else ("PIN %d / %d"):format(state.step, state.maxSteps)
	u.fill.Size = UDim2.fromScale(math.clamp(remaining / pig, 0, 1), 1)
	u.held.Text = ("CARRYING %s"):format(Config.formatCoins(state.banked))
	u.nextText.Text = ("NEXT +%s"):format(Config.formatCoins(state.slice))
	u.left.Text = ("%s LEFT"):format(Config.formatCoins(remaining))
	local spares = state.spares or 0
	u.spares.Visible = spares > 0
	u.spares.Text = if spares == 1 then "1 SPARE PICK" else ("%d SPARE PICKS"):format(spares)

	-- The cap line only exists when there IS a cap. A resident's floor is
	-- zero, and a line against the left edge would say "you can empty this"
	-- in the one visual language that means "you cannot".
	local floor = state.floor or 0
	u.line.Visible = floor > 0
	u.line.Position = UDim2.new(math.clamp(floor / pig, 0, 1), -1, 0, 0)

	-- The next slice sits at the RIGHT-HAND end of what is left, because the
	-- fill shrinks from the right, so this is the piece about to go.
	local width = math.clamp(state.slice / pig, 0, 1)
	local from = math.clamp(remaining / pig - width, 0, 1)
	u.nextSlice.Visible = state.slice > 0 and remaining > 0
	u.nextSlice.Position = UDim2.fromScale(from, 0)
	u.nextSlice.Size = UDim2.new(math.min(width, 1 - from), 0, 1, 0)

	-- THE PINS. Seated ones turquoise with a check where they were caught,
	-- the active one gold, the rest ivory resting low. Never colour alone:
	-- the check, the gold number disc and the notch all say which is which.
	local active = state.step
	for i, p in ipairs(u.pins) do
		local x = CHANNELS[i]
		if i < active then
			sprite(p.pin, "parts", RECT.pinSet)
			p.check.Visible = true
			placePin(p, x, pinTop(seated[i] or 0.5))
		elseif i == active then
			sprite(p.pin, "parts", RECT.pinActive)
			p.check.Visible = false
		else
			sprite(p.pin, "parts", RECT.pinIdle)
			p.check.Visible = false
			placePin(p, x, PIN_TOP_LO)
		end
		p.number.BackgroundColor3 = if i == active then Theme.GOLD else Theme.INK
		p.number.TextColor3 = if i == active then Theme.INK else Theme.PAPER
		p.ring.Thickness = if i == active then 3 else Theme.OUTLINE_THIN
	end

	-- THE NOTCH IS THE SERVER'S ZONE, laid over the COLLAR's travel and
	-- padded by half a collar at each end, so a collar whose centre is
	-- anywhere in the zone reads as sitting in the notch -- which is exactly
	-- the hit the server will judge.
	local x = CHANNELS[active]
	u.notch.Visible = x ~= nil
	if x then
		u.notch.Size = UDim2.fromScale(NOTCH_W, TRAVEL * state.width + NOTCH_H)
		placeNotch(u, state, workspace:GetServerTimeNow())
	end
end

-- The active pin, and only the active pin. Everything else is push-driven,
-- so this moves one pin and one spring a frame.
local function step()
	local u, st = ui, state
	if not u or not st then
		return
	end
	local p = u.pins[st.step]
	if not p then
		return
	end
	local now = workspace:GetServerTimeNow()
	local sweep = st.sweep
	local phase = (now - st.startedAt) % (sweep * 2)
	local at = if phase <= sweep then phase / sweep else 2 - phase / sweep
	lastAt = at
	placePin(p, CHANNELS[st.step], pinTop(at))
	if (st.drift or 0) > 0 then
		placeNotch(u, st, now)
	end
end

-- A forgiven miss: the lock gives a short shake and says what happened. Kept
-- to a third of a second, because the pin is already moving again.
local shakeId = 0
local function forgiven()
	local u = ui
	if not u then
		return
	end
	shakeId += 1
	local id = shakeId
	u.flashText.Visible = true
	local home = u.housing.Position
	task.spawn(function()
		for i = 1, 6 do
			if shakeId ~= id then
				return
			end
			u.housing.Position = home + UDim2.fromOffset(if i % 2 == 0 then 4 else -4, 0)
			task.wait(0.03)
		end
		u.housing.Position = home
		task.wait(0.5)
		if shakeId == id then
			u.flashText.Visible = false
		end
	end)
end

-- The seat: a short pop on the check as the pin lands. Kept to about a tenth
-- of a second, because the next pin starts moving at once and a celebration
-- between slices is time spent not looking at it.
local function popCheck(i: number)
	local u = ui
	local p = u and u.pins[i]
	if not p then
		return
	end
	p.checkScale.Scale = 1.5
	TweenService:Create(p.checkScale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

-- THE STEAL AND SMASH CARDS ARE HIDDEN WHILE A LOCK IS OPEN. They sit on the
-- same pig and would otherwise float over the panel offering G to smash the
-- thing you are halfway through picking. `MaxPromptsVisible` rather than
-- `Enabled`, because ClientMain already owns `Enabled` for the bin disguise
-- and two writers on one property drift.
local savedPrompts: number? = nil
local function hidePrompts(hide: boolean)
	if hide and not savedPrompts then
		savedPrompts = ProximityPromptService.MaxPromptsVisible
		ProximityPromptService.MaxPromptsVisible = 0
	elseif not hide and savedPrompts then
		ProximityPromptService.MaxPromptsVisible = savedPrompts
		savedPrompts = nil
	end
end

function Crack.start(gui: Instance)
	build(gui)

	-- WHAT THE LAST PUSH SAID, so a slice landing can be told from any other
	-- reason this payload arrives. `CrackState` is pushed on the open, on
	-- every tap, on a walk-away and on a miss -- so "a slice landed" is not an
	-- event the server sends, it is a STEP THAT WENT UP, and the only way to
	-- see it is to remember the last one.
	local lastStep = 0

	Remotes.get("CrackState").OnClientEvent:Connect(function(payload, why)
		-- `landed`, NOT `step`: a local named `step` here would shadow the
		-- marker function below and hand `RenderStepped:Connect` a number --
		-- which is exactly how the old dial never swept, on every crack, from
		-- the day it shipped.
		local landed = (payload and payload.step) or 0

		-- A fresh attempt forgets the last one's seated pins.
		if payload and (landed <= 1 or lastStep == 0) then
			table.clear(seated)
		end
		-- THE PIN THAT JUST SEATED rests in the centre of the notch it was
		-- caught in: the previous push's zone, which is the one the server
		-- judged the tap against.
		if state and payload and landed > lastStep then
			seated[state.step] = lastAt
		end

		-- THE LADDER. A note per slice, rising (see `Config.CRACK_NOTES`).
		-- 2D through `SoundKit.ui`, which is load-bearing: it plays for the
		-- thief and nobody else, because a clean crack is SILENT to the street
		-- and a rising run audible from the pavement would sell that stealth
		-- for a sound effect.
		if landed > lastStep then
			SoundKit.ui(Config.SOUNDS.CLICK, {
				name = "CrackSlice",
				volume = Config.CRACK_NOTES.volume,
				pitch = Config.crackNotePitch(landed),
			})
		end

		-- THE TOP OF THE RUN arrives as a close, not a push: `crackTap` lands
		-- the final slice and goes straight to `endCrack("done")`, so the
		-- client is only told that the panel closed. Played here off the close
		-- rather than faked on the server.
		if not payload and why == "done" then
			SoundKit.ui(Config.SOUNDS.CLICK, {
				name = "CrackDone",
				volume = Config.CRACK_NOTES.volume,
				pitch = Config.crackNotePitch(Config.CRACK.maxSteps),
			})
		elseif payload and why == "forgiven" then
			-- The miss sound, softer: something went wrong and a spare pick
			-- caught it, which is a different thing from the crack ending.
			SoundKit.ui(Config.SOUNDS.CLICK, {
				name = "CrackForgiven",
				volume = Config.CRACK_NOTES.missVolume * 0.6,
				pitch = Config.semitonePitch(Config.CRACK_NOTES.miss),
			})
		elseif not payload and why == "miss" then
			-- A FALL, and only on a MISS. Walking away is silent because
			-- nothing went wrong and the player chose it; the other endings
			-- are ones the WORLD already makes a noise for.
			SoundKit.ui(Config.SOUNDS.CLICK, {
				name = "CrackMiss",
				volume = Config.CRACK_NOTES.missVolume,
				pitch = Config.semitonePitch(Config.CRACK_NOTES.miss),
			})
		end

		local seatedNow = if state and payload and landed > lastStep then state.step else nil
		lastStep = if payload then landed else 0

		state = payload
		render()
		if seatedNow then
			popCheck(seatedNow)
		end
		if payload and why == "forgiven" then
			forgiven()
		end
		hidePrompts(state ~= nil)
		if state and not heartbeat then
			heartbeat = RunService.RenderStepped:Connect(step)
		elseif not state and heartbeat then
			-- Disconnected rather than left running against a nil state: the
			-- panel is closed for most of a session and a per-frame handler
			-- that early-outs is still a per-frame handler.
			heartbeat:Disconnect()
			heartbeat = nil
		end
	end)

	-- F SETS THE PIN AND ESCAPE TAKES WHAT YOU HAVE. The map was checked before
	-- either was claimed: Q dodge/trick, B shop, V garage, R radio, I bag,
	-- Escape close, F2 admin, 1-0 the hot bar. Escape already means "close
	-- this" everywhere else, and walking away with what you have banked IS
	-- closing this. Both are the secondary route: the BUTTONS are primary,
	-- because most of this audience never presses a key at all.
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not state then
			return
		end
		local u = ui
		if input.KeyCode == Enum.KeyCode.F then
			if u then
				u.pressTap(true)
				task.delay(0.1, u.pressTap, false)
			end
			tap()
		elseif input.KeyCode == Enum.KeyCode.Escape then
			if u then
				u.pressStop(true)
				task.delay(0.1, u.pressStop, false)
			end
			stop()
		end
	end)
end

return Crack
