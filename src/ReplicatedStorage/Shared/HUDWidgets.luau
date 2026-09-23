--!strict
-- Small static illustrations for the boost pocket and the event countdown,
-- both of which sit in the left menu rail under the three menu buttons.
local TweenService = game:GetService("TweenService")
local Config = require(script.Parent.Config)
local Theme = require(script.Parent.Theme)
local HUDLayout = require(script.Parent.HUDLayout)
local HUDWidgets = {}

-- THE COUNTDOWN IS ONE WIDGET IN TWO SHAPES, AND THE SECOND ONE IS A BANNER.
--
-- Far out it is a small icon at the top of the screen with the clock laid on
-- it: furniture, saying only that something is coming and what. Inside
-- `Config.EVENT_SOON` it UNFOLDS into a banner -- a card fades up under it,
-- the name slides in beside the icon and the clock moves out to the right.
-- Because the whole thing is centre-anchored, growing from 86 wide to 340
-- sweeps the icon LEFT on its own; nothing animates a position that the size
-- change is not already implying.
--
-- THE TOP OF THE SCREEN MEANS THE TOP BAND, NOT THE TOP COLUMN, and getting
-- that wrong once is worth writing down. This first went in at y 200, on the
-- argument that it should take the street banner's own slot and hand over to
-- it seamlessly at `EVENTS.warning`. That argument is sound and the PLACE is
-- not "the top": measured down the top-centre column, y 200 is the FOURTH
-- band -- under the first-job card, the rebirth button and the carry banner
-- -- so it reads as the middle of the screen, which is exactly what it was
-- reported as.
--
-- WHAT IT COSTS is the seamless hand-over: the warning banner still appears
-- at y 200, so the countdown no longer becomes it. The unfold has to carry
-- the escalation on its own, which it does -- it is just no longer the same
-- object continuing.
local EVENT_TOP = 6

-- THE ICON IS THE SIZE OF A MENU BUTTON, AND IT TOOK MOVING SOMETHING ELSE TO
-- GET THERE. It was sized to fit the band under the first-job card at y 50,
-- which capped it at fifty pixels and then at forty, and at that size the
-- clock laid over it covered most of the picture -- so the one element this
-- widget exists for was the smallest thing on it and was also obscured.
--
-- Fifty pixels was never going to be enough: a shop button is 64 and the
-- clock sits ON this, so it has to be BIGGER than a shop button to read as
-- the same size. `FirstJob` moved down to 88 to make the room, which is free
-- because that card and the rebirth button below it are mutually exclusive in
-- practice -- a player in their first session cannot afford a rebirth.
local ICON_H = 76
local ICON_SCALE = ICON_H / 64
-- The art is authored in a 66 x 64 box, so the width follows the height.
local ICON_W = 66 * ICON_SCALE

-- THE CARD IS A CHILD NOW, NOT THE ROOT, which is what lets the picture be
-- taller than the banner it unfolds into. The root is a transparent container
-- the height of the ICON; the card is a 52-tall band centred inside it that
-- fades up, so the icon overhangs it top and bottom exactly as a badge
-- breaking out of a banner does. Sizing the root to the card instead is what
-- pinned the icon to 40 for two sessions.
local CARD_H = 52
-- Wide enough for the NAME rather than for the icon. "ALIEN INVASION" at 16px
-- is about 100 across against a 78-wide picture, so a tile sized to the
-- picture would crop the words laid over it. The name overhanging the icon
-- sideways is fine and reads as deliberate; the stroke is what holds it.
local IDLE_W = 160

-- The two shapes, as data. Every field is tweened, so adding one here means
-- adding it to `applyState` and nowhere else. The ROOT HEIGHT never changes:
-- the unfold is purely horizontal, so the widget can never grow down into the
-- band below it, and the picture does not swell as the card arrives.
-- THE NAME IS ON IT IN BOTH SHAPES, and it used to appear only on the
-- unfold. Hiding it meant the idle widget said "something is coming in 12:32"
-- and left WHICH to a picture -- which works for somebody who has met both
-- events before and is exactly no help the first time. The unfold is still a
-- real change without it doing the introducing: the card arrives and the
-- whole thing goes from a badge to a banner.
--
-- STACKED IN THE LOWER HALF so the top of the picture stays clear: the name
-- at 28..52 and the clock under it at 50..76, over a 76-tall icon. Two lines
-- of type do cover a drawing, and putting them low is the only lever there
-- is -- what is left uncovered is the saucer's dome, which is the half of
-- it that identifies it.
local IDLE = {
	root = UDim2.fromOffset(IDLE_W, ICON_H),
	card = 1,
	icon = UDim2.fromOffset((IDLE_W - ICON_W) / 2, 0),
	timePos = UDim2.fromOffset(0, 50),
	timeSize = UDim2.fromOffset(IDLE_W, 26),
	namePos = UDim2.fromOffset(0, 28),
	nameSize = UDim2.fromOffset(IDLE_W, 24),
	nameFade = 0,
}
local ALERT = {
	root = UDim2.fromOffset(340, ICON_H),
	card = 0,
	icon = UDim2.fromOffset(8, 0),
	timePos = UDim2.fromOffset(240, 0),
	timeSize = UDim2.fromOffset(92, ICON_H),
	-- Clear of the icon, which ends at 8 + ICON_W.
	namePos = UDim2.fromOffset(96, 0),
	nameSize = UDim2.fromOffset(140, ICON_H),
	nameFade = 0,
}
local UNFOLD = TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function part(parent: Instance, name: string, x: number, y: number,
	w: number, h: number, colour: Color3, radius: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Position = UDim2.fromOffset(x, y)
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = colour
	f.BorderSizePixel = 0
	f.Parent = parent
	Theme.corner(f, radius)
	return f
end

local function label(parent: Instance, name: string, x: number, y: number,
	w: number, h: number, size: number, text: string): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Position = UDim2.fromOffset(x, y)
	l.Size = UDim2.fromOffset(w, h)
	l.BackgroundTransparency = 1
	l.Font = Theme.FONT
	l.TextColor3 = Theme.INK
	l.TextSize = size
	l.Text = text
	l.Parent = parent
	return l
end

function HUDWidgets.boost(gui: ScreenGui): TextButton
	local root = Instance.new("TextButton")
	root.Name = "BoostPill"
	root.Size = UDim2.fromOffset(60, 48)
	root.BackgroundTransparency = 1
	root.Text = ""
	root.AutoButtonColor = false
	root.Visible = false
	root.Parent = gui
	local disc = part(root, "Token", 0, 2, 44, 44, Theme.PAPER, 22)
	Theme.outline(disc, 2, Theme.INK)
	local face = part(disc, "Face", 4, 4, 36, 36, Theme.GOLD, 18)
	-- Fixed pixel sizes keep this small token legible without scaled text.
	label(face, "Multiplier", 0, -1, 36, 27, 22, "2×")
	local caption = label(face, "Caption", -2, 23, 40, 12, 10, "BOOST")
	caption.Font = Enum.Font.GothamBold
	local badge = part(root, "Stock", 34, 0, 26, 18, Theme.PAPER, 8)
	Theme.outline(badge, 1.5)
	label(badge, "Count", 0, 0, 26, 18, 11, "0")
	local timer = part(root, "Timer", 44, 9, 54, 29, Theme.PAPER, 10)
	Theme.outline(timer, 1.5)
	timer.Visible = false
	label(timer, "Time", 2, 0, 50, 29, 14, "0:00")
	local function fit()
		local m = HUDLayout.metrics(gui.AbsoluteSize)
		-- Fourth entry in the left menu rail, immediately below Shop. It
		-- spent two sessions moving aside for the event countdown; the
		-- countdown lives at the top of the screen now, so this has the slot
		-- back and the rail is what it always was.
		local menuTop = if m.compact then 78 else 144
		root.Position = UDim2.fromOffset(4 + math.floor((m.menuSize - 44) / 2),
			menuTop + 3 * (m.menuSize + m.menuGap))
	end
	local connection = gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	root.Destroying:Connect(function() connection:Disconnect() end)
	fit()
	return root
end

function HUDWidgets.renderBoost(root: TextButton, count: number, seconds: number)
	local active = seconds > 0
	root.Visible = active or count > 0
	root.Size = UDim2.fromOffset(if active then 100 else 60, 48)
	root:SetAttribute("BoostActive", active)
	root:SetAttribute("Stock", count)
	local stock = root:FindFirstChild("Stock") :: Frame
	stock.Visible = not active
	local countLabel = stock:FindFirstChild("Count") :: TextLabel
	countLabel.Text = tostring(count)
	local timer = root:FindFirstChild("Timer") :: Frame
	timer.Visible = active
	local timeLabel = timer:FindFirstChild("Time") :: TextLabel
	timeLabel.Text = ("%d:%02d"):format(seconds // 60, seconds % 60)
end

-- THE COUNTDOWN MOVED INTO THE MENU RAIL AND STOPPED BEING A CARD.
--
-- It was a 176-wide paper chip hanging off the right edge under the piggy
-- bank panel: a second card, in the corner the balance owns, saying something
-- that is not about the balance. What it actually is, is a STANDING CONTROL
-- READOUT -- the same kind of thing as Shop, Stuff and Options -- so it lives
-- where those live, drawn in their vocabulary: one illustration authored on
-- the rail's own 64-unit grid, in the game's own palette.
--
-- AND IT SHOWS WHICH EVENT IS COMING RATHER THAN A CLOCK. The first build
-- drew a bell, which says "something is coming" and leaves the interesting
-- half -- WHAT -- to nothing at all. The scheduler rolls the event at the
-- start of the quiet stretch now, so the icon is a picture of the actual
-- thing: a saucer for the Alien Raid (the Midnight Heist's moon went with
-- the event). The bell survives as the UNKNOWN case, which is what a roster
-- row with no artwork and no drawn fallback has to look like.

-- A SAUCER, DRAWN, BECAUSE AN EMPTY UPLOAD SLOT IS A WORKING STATE.
-- `Config.EVENT_UI[key].icon` wins when it is filled in; this is what the
-- row renders until its picture lands, and what it falls back to if an
-- upload is ever moderated away. It is authored inside the 66 x 64 rail
-- cell and takes its own event's tone from Config, so the icon and the
-- banner that follows it twenty seconds later cannot disagree about colour.
local function saucer(icon: Frame, tone: Color3)
	-- The beam goes down FIRST and stays behind the hull, so the hull's own
	-- stroke is what caps it rather than a second edge across the middle.
	local beam = part(icon, "Beam", 24, 42, 18, 18, tone, 6)
	beam.BackgroundTransparency = 0.55
	beam.ZIndex = 0
	local dome = part(icon, "Dome", 21, 10, 24, 24, tone, 12)
	dome.ZIndex = 0
	Theme.outline(dome, 2.5, Theme.INK)
	Theme.shade(dome, 0.88)
	local hull = part(icon, "Hull", 4, 28, 58, 17, Theme.PAPER, 9)
	hull.ZIndex = 1
	Theme.outline(hull, 2.5, Theme.INK)
	Theme.shade(hull, 0.9)
	for _, x in { 12, 29, 46 } do
		local lamp = part(hull, "Lamp" .. x, x - 4, 5, 8, 8, Theme.GOLD, 4)
		lamp.ZIndex = 2
		Theme.outline(lamp, 1.5, Theme.INK)
	end
end

-- THE PATROL'S TWO PICTURES, drawn in the same toolkit so the widget reads as
-- one family whatever it is counting down to: a rotating beacon for the
-- sirens and a pursuit, a patrol car for the cruise. Tones come from
-- `Config.ANNOUNCE`, so orange sirens and a red pursuit stay the palette
-- rule's colours rather than this file's.
local function siren(icon: Frame, tone: Color3)
	for i, spec in { { 8, 14, -35 }, { 50, 14, 35 }, { 29, 0, 0 } } do
		local ray = part(icon, "Ray" .. i, spec[1], spec[2], 8, 16, Theme.GOLD, 4)
		ray.Rotation = spec[3]
		Theme.outline(ray, 1.5, Theme.INK)
	end
	local dome = part(icon, "Dome", 15, 18, 36, 32, tone, 16)
	Theme.outline(dome, 2.5, Theme.INK)
	Theme.shade(dome, 0.85)
	part(dome, "Glint", 7, 6, 8, 12, Theme.PAPER, 4).BackgroundTransparency = 0.25
	local base = part(icon, "Base", 8, 46, 50, 12, Theme.INK:Lerp(Theme.PAPER, 0.35), 5)
	Theme.outline(base, 2.5, Theme.INK)
end

local function car(icon: Frame, tone: Color3)
	local cabin = part(icon, "Cabin", 16, 16, 34, 20, Theme.PAPER, 8)
	Theme.outline(cabin, 2.5, Theme.INK)
	local glass = part(cabin, "Glass", 5, 4, 24, 10, tone:Lerp(Theme.PAPER, 0.4), 4)
	glass.ZIndex = 2
	local light = part(icon, "LightBar", 24, 9, 18, 8, Color3.fromRGB(230, 81, 64), 4)
	Theme.outline(light, 1.5, Theme.INK)
	local body = part(icon, "Body", 3, 32, 60, 18, tone, 8)
	body.ZIndex = 2
	Theme.outline(body, 2.5, Theme.INK)
	Theme.shade(body, 0.88)
	for _, x in { 10, 42 } do
		local wheel = part(icon, "Wheel" .. x, x, 44, 15, 15, Theme.INK, 8)
		wheel.ZIndex = 3
		part(wheel, "Hub", 5, 5, 5, 5, Theme.MUTED, 3).ZIndex = 4
	end
end

local EVENT_ART: { [string]: (Frame, Color3) -> () } = {
	raid = saucer, siren = siren, car = car,
}
-- The patrol pictures take their own tones rather than an event's.
local ART_TONE: { [string]: () -> Color3 } = {
	siren = function()
		local row = Config.announce("sirens")
		return if row then row.tone else Theme.WARN
	end,
	car = function()
		local row = Config.announce("patrol")
		return if row then row.tone else Theme.COOL
	end,
}

function HUDWidgets.event(gui: ScreenGui): Frame
	local root = Instance.new("Frame")
	root.Name = "NextEvent"
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = UDim2.new(0.5, 0, 0, EVENT_TOP)
	root.Size = IDLE.root
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Visible = false
	root.Parent = gui

	-- Full width, fixed height, centred in the root: it follows the unfold
	-- sideways without the icon ever having to know it is there.
	local card = part(root, "Card", 0, (ICON_H - CARD_H) / 2, 0, CARD_H, Theme.GOLD, 12)
	card.Size = UDim2.new(1, 0, 0, CARD_H)
	card.BackgroundTransparency = IDLE.card
	card.ZIndex = 1
	local cardEdge = Theme.outline(card, 2.5, Theme.INK)
	cardEdge.Transparency = IDLE.card

	-- EVERY VARIANT IS BUILT ONCE AND TOGGLED, never rebuilt on the tick.
	-- This paints every frame of a fifteen-minute countdown; tearing an
	-- illustration down and standing another one up per push would be a few
	-- dozen instances a second to say something that changes twice an hour.
	local slot = part(root, "Icon", 0, 0, 66, 64, Theme.PAPER, 0)
	slot.Position = IDLE.icon
	slot.BackgroundTransparency = 1
	slot.ZIndex = 5
	local iconScale = Instance.new("UIScale")
	iconScale.Name = "IconScale"
	iconScale.Scale = ICON_SCALE
	iconScale.Parent = slot

	-- The upload slot. One ImageLabel serves every event, because only one
	-- event is ever upcoming: `renderEvent` swaps the id.
	local image = Instance.new("ImageLabel")
	image.Name = "Image"
	image.Position = UDim2.fromOffset(3, 2)
	image.Size = UDim2.fromOffset(60, 60)
	image.BackgroundTransparency = 1
	image.ScaleType = Enum.ScaleType.Fit
	image.Image = ""
	image.Visible = false
	image.Parent = slot

	for key, draw in EVENT_ART do
		local art = part(slot, "Art_" .. key, 0, 0, 66, 64, Theme.PAPER, 0)
		art.BackgroundTransparency = 1
		art.Visible = false
		local ui = Config.eventUI(key)
		local tone = if ART_TONE[key] then ART_TONE[key]() elseif ui then ui.tone else Theme.GOLD
		draw(art, tone)
	end

	-- THE UNKNOWN CASE, and it is a real state rather than a leftover: a
	-- roster row added without artwork, and any client whose server has not
	-- started publishing the upcoming key, both land here. A bell says
	-- "something is coming" without naming anything, which is exactly what
	-- is true then.
	--
	-- ONE ROUNDED BODY WITH A BAR ACROSS ITS FOOT, never a dome plus a skirt.
	-- Two stacked solids meet along a line both of their strokes draw on, and
	-- on a rounded corner those two strokes do not coincide, so the seam
	-- shows as an arc through the middle of the bell. The band covers the
	-- body's own bottom edge instead, which is what a bell's rim actually is.
	local bell = part(slot, "Bell", 8, 2, 50, 60, Theme.PAPER, 25)
	bell.BackgroundTransparency = 1
	local knob = part(bell, "Knob", 20, 0, 10, 12, Theme.MUTED, 5)
	knob.ZIndex = 0
	Theme.outline(knob, 2, Theme.INK)
	local dome = part(bell, "Dome", 3, 8, 44, 42, Theme.PAPER, 18)
	Theme.outline(dome, 2.5, Theme.INK)
	Theme.shade(dome, 0.9)
	part(bell, "Shade", 33, 18, 8, 22, Theme.SAND_DEEP, 4).ZIndex = 2
	local band = part(bell, "Band", -1, 40, 52, 12, Theme.GOLD, 5)
	band.ZIndex = 3
	Theme.outline(band, 2.5, Theme.INK)
	part(bell, "Clapper", 19, 50, 12, 10, Theme.INK, 5).ZIndex = 2

	-- BARE TYPE WITH A DARK STROKE, AND NO CARD BEHIND EITHER LABEL.
	--
	-- This went through two worse shapes first. Side by side, a 66-wide
	-- picture and a 100-wide clock card were two things near each other.
	-- Stacking the card ON the icon fixed that and cost the thing it was
	-- stacked on: a 78 x 26 pill covers the top third of a 66-wide
	-- illustration, so the icon that is supposed to say WHICH event was the
	-- part being hidden.
	--
	-- Bare type takes no room at all, and it is the only version that can
	-- survive the unfold: the labels sit on a drawing in one shape and on a
	-- coloured banner in the other, and a stroke reads over both where a
	-- ground would have to be tweened out from under itself.
	local function overlay(name: string, pos: UDim2, size: UDim2, textSize: number,
		thickness: number): TextLabel

		local text = label(root, name, 0, 0, 10, 10, textSize, "")
		text.Position, text.Size = pos, size
		text.TextXAlignment = Enum.TextXAlignment.Center
		text.TextColor3 = Theme.PAPER
		text.ZIndex = 6
		-- ON THE GLYPH, NOT ROUND A BOX. `ApplyStrokeMode` is left at its
		-- default `Contextual`, which on a TextLabel strokes THE CHARACTER;
		-- `Border` -- which is what `Theme.outline` sets, so that helper is
		-- the wrong one here -- would outline the label's invisible rectangle
		-- and put a floating box over the icon. Two words, and they are the
		-- difference between a readout and a rectangle.
		local stroke = Instance.new("UIStroke")
		stroke.Color = Theme.INK
		stroke.Thickness = thickness
		stroke.LineJoinMode = Enum.LineJoinMode.Round
		stroke.Parent = text
		return text
	end

	local time = overlay("Time", IDLE.timePos, IDLE.timeSize, 23, 3)
	time.Text = "--:--"

	-- WHAT IT IS, IN WORDS, IN BOTH SHAPES. It sits over the icon above the
	-- clock while this is idle and slides out beside the icon on the unfold.
	--
	-- TextScaled with a floor rather than a fixed size: both shipped names
	-- are fourteen characters, and a longer one added later shrinks visibly
	-- instead of being clipped by a truncation nobody sees.
	local name = overlay("Name", IDLE.namePos, IDLE.nameSize, 16, 2.5)
	name.Text = "NEXT EVENT"
	name.TextScaled = true
	name.TextTransparency = IDLE.nameFade
	local nameStroke = name:FindFirstChildOfClass("UIStroke") :: UIStroke
	nameStroke.Transparency = IDLE.nameFade
	local nameLimit = Instance.new("UITextSizeConstraint")
	nameLimit.MinTextSize, nameLimit.MaxTextSize, nameLimit.Parent = 8, 16, name

	-- THE PROGRESS BAR WENT WITH THE CARD, AND THAT IS A REAL LOSS RATHER
	-- THAN A TIDY-UP. This file's own rule is that a countdown is a bar AND a
	-- number, because one is read and the other is seen. It was written about
	-- the BANNER, where the window is twenty seconds and a glance has to be
	-- enough; over fifteen minutes a bar moves about a pixel a half-minute,
	-- which is not something anybody sees moving. The unfold is the signal
	-- that replaces it, and it is a far louder one.

	return root
end

-- ONE TWEEN SET PER SHAPE, FIRED ONLY WHEN THE SHAPE CHANGES. `renderEvent`
-- runs on Heartbeat, so building six tweens a frame would be sixty sets a
-- second all racing to the same targets -- which does not error, it just
-- means nothing ever finishes and the unfold never plays.
local function applyState(root: Frame, spec: any, animate: boolean)
	local slot = root:FindFirstChild("Icon") :: Frame
	local time = root:FindFirstChild("Time") :: TextLabel
	local name = root:FindFirstChild("Name") :: TextLabel
	local nameStroke = name:FindFirstChildOfClass("UIStroke") :: UIStroke
	local card = root:FindFirstChild("Card") :: Frame
	local cardEdge = card:FindFirstChildOfClass("UIStroke") :: UIStroke
	local goals = {
		{ root, { Size = spec.root } },
		{ card, { BackgroundTransparency = spec.card } },
		{ cardEdge, { Transparency = spec.card } },
		{ slot, { Position = spec.icon } },
		{ time, { Position = spec.timePos, Size = spec.timeSize } },
		{ name, { Position = spec.namePos, Size = spec.nameSize,
			TextTransparency = spec.nameFade } },
		{ nameStroke, { Transparency = spec.nameFade } },
	}
	for _, goal in ipairs(goals) do
		local target, props = goal[1] :: any, goal[2] :: any
		if animate then
			TweenService:Create(target, UNFOLD, props):Play()
		else
			for key, value in props do
				(target :: any)[key] = value
			end
		end
	end
end

-- ONE WIDGET FOR EVERYTHING WITH A CLOCK ON IT.
--
-- It was the next-event countdown alone, while the patrol's sirens and cruise,
-- a pursuit, and an event's own warning and run each drew a separate ribbon in
-- the middle of the screen. Those ribbons are gone: the designer asked for
-- every timed announcement to look like this one, at the top, out of the way.
-- So the widget takes a SPEC and the caller decides what matters most.
--
--   art      a key of EVENT_ART (drawn), or nil for the bell
--   image    an uploaded picture, which wins over the drawing when set
--   name     what it is, in words
--   seconds  what is left
--   tone     the card's colour
--   alert    unfolded into the card (anything urgent, or an event close)
--   pulse    the card breathes -- sirens, a pursuit, an event's warning
function HUDWidgets.renderStatus(root: Frame, spec: any)
	local left = math.max(0, math.ceil(spec.seconds or 0))
	local timeLabel = root:FindFirstChild("Time") :: TextLabel
	timeLabel.Text = ("%d:%02d"):format(left // 60, left % 60)

	-- THE PICTURE, IN ONE ORDER: an uploaded image, then the drawn art, then
	-- the bell. Resolved every call, so an id filled in later needs no rebuild.
	local key = spec.art or ""
	local id = spec.image or ""
	local slot = root:FindFirstChild("Icon") :: Frame
	local image = slot:FindFirstChild("Image") :: ImageLabel
	if image.Image ~= id then image.Image = id end
	image.Visible = id ~= ""
	local drawn = if id == "" then slot:FindFirstChild("Art_" .. key) else nil
	for _, child in ipairs(slot:GetChildren()) do
		if child:IsA("GuiObject") and child.Name:sub(1, 4) == "Art_" then
			child.Visible = child == drawn
		end
	end
	local bell = slot:FindFirstChild("Bell") :: Frame
	bell.Visible = id == "" and drawn == nil

	local nameLabel = root:FindFirstChild("Name") :: TextLabel
	nameLabel.Text = spec.name or ""

	-- THE PULSE IS A BREATH OF THE CARD'S OWN COLOUR toward paper, at 1.2 a
	-- second -- well inside the three-flashes-a-second ceiling this game holds
	-- everything to, and never a hard on/off.
	local card = root:FindFirstChild("Card") :: Frame
	local tone: Color3 = spec.tone or Theme.GOLD
	if spec.pulse then
		local breath = 0.5 + 0.5 * math.sin(os.clock() * math.pi * 2 * 1.2)
		card.BackgroundColor3 = tone:Lerp(Theme.PAPER, 0.3 * breath)
	else
		card.BackgroundColor3 = tone
	end

	-- THE UNFOLD IS THE ESCALATION. Fired only when the shape changes;
	-- `renderStatus` runs on Heartbeat.
	local alert = spec.alert == true
	if root:GetAttribute("Alert") ~= alert then
		local first = root:GetAttribute("Alert") == nil
		root:SetAttribute("Alert", alert)
		applyState(root, if alert then ALERT else IDLE, not first)
	end
end

-- `upcoming` is the roster key the server has already rolled, or "" when
-- nothing is rolled yet.
--
-- THE ROSTER'S OWN NAME, never a second copy of it: the HUD once hardcoded
-- "INVASION INCOMING" while Config said "ALIEN INVASION". GET READY survives
-- only for the unknown case, where there is no name to keep.
function HUDWidgets.renderEvent(root: Frame, seconds: number, total: number,
	soon: boolean, upcoming: string?)

	local key = upcoming or ""
	local ui = Config.eventUI(key)
	local entry = (Config.EVENTS.roster :: any)[key]
	HUDWidgets.renderStatus(root, {
		art = key,
		image = if ui then ui.icon else nil,
		name = if entry and entry.name then entry.name
			elseif soon then "GET READY"
			else "NEXT EVENT",
		seconds = seconds,
		tone = if ui then ui.tone else Theme.GOLD,
		alert = soon,
	})
end

return HUDWidgets
