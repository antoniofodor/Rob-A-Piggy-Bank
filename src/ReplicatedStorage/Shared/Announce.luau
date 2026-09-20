--!strict
-- ONE SHAPE FOR EVERY ANNOUNCEMENT BANNER IN THE GAME.
--
-- There were three, built five hundred lines apart, and they had drifted into
-- three different objects: the carry banner 52 tall with gold type on its own
-- deep red, the patrol banner 38 tall with INK type on a saturated ground, and
-- the event banner 44 tall with ink type, a badge and a progress groove. Same
-- column, same job -- tell somebody something is happening right now -- three
-- looks. This file is that object, once, and the three call sites hand it a
-- spec.
--
-- ============================================================
-- WHY THE GROUND WENT DARK, WHICH IS THE ONE DECISION EVERYTHING ELSE RESTS ON
-- ============================================================
--
-- The ask was big WHITE text. On the old grounds that is unreadable and it is
-- not close: measured, PAPER against the six banner tones runs
--
--     GOLD 1.41   COOL 2.17   GOOD 2.26   WARN 2.45   STOP 3.47   PRESTIGE 7.70
--
-- so four of the six fail even the 3.0 large-text floor, which is exactly why
-- the patrol and event banners were printing INK. Deepening the tone 62% of
-- the way to ink fixes it outright -- the same pairs become
--
--     GOLD 5.63   COOL 7.22   GOOD 7.40   WARN 7.60   STOP 9.11   PRESTIGE 12.28
--
-- every one clearing the 4.5 BODY floor, never mind large. So the hue still
-- says which announcement this is, and the type is white because the ground
-- can finally carry white.
--
-- AND THE TONE AT FULL STRENGTH BECAME THE SHAPE. This is the notify toast's
-- own rule arriving on the banners: *colour still means something; it stopped
-- being the ground*. The end diamonds, the icon discs and the underline are
-- the tone; the ground is the tone with the lights off. Measured at 2.63 to
-- 4.01 against their own ground, which is plenty for a SHAPE and would not be
-- for type -- nothing here prints on one.
--
-- THE INK STROKE ON THE TYPE IS THEREFORE A FLOURISH AND NOT THE MECHANISM,
-- which is deliberate. A stroked white label would read on any ground at all,
-- and it would also be invisible to the contrast audit -- that probe compares
-- `TextColor3` against the background and cannot see a stroke, the same blind
-- spot it already had for gradients. Solving it in the GROUND keeps the audit
-- honest about this row.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Theme = require(ReplicatedStorage.Shared.Theme)

local Announce = {}

-- ============================================================
-- THE SHAPE
-- ============================================================
--
-- A HEXAGONAL RIBBON: a rounded body with a 45-degree square behind each end,
-- so the banner comes to a point left and right instead of being one more
-- rounded rectangle. Roblox UI has no polygon and no mask, so a compound
-- silhouette cannot have one continuous outline -- the body's own stroke draws
-- a vertical line where each tail meets it.
--
-- THAT LINE IS KEPT AND IS THE POINT. A ribbon banner has a fold at each end;
-- reading the seam as a fold is what turns an engine limitation into the
-- design, and it is the only version of this shape that does not need an
-- uploaded image. Nothing here is an asset that can be moderated away, which
-- is the rule the ground, the houses and the piggies are all built to.
local BODY_W, BODY_H = 400, 52
-- A 45-degree square of side 34 has a 48-stud diagonal, so it fits inside a
-- 52-tall body with two pixels to spare at top and bottom and pokes 24 out to
-- each side. Bigger and the points stand taller than the banner they belong
-- to; smaller and they read as chamfers rather than as a ribbon.
local TAIL = 34
local ROOT_W = BODY_W + TAIL * 1.414

local ICON = 40
local PAD = 6
-- The text column is what is left between the two icons: 400 - 2 * (6 + 40) --
-- and the longest headline in the game today measures 273 there at 26px
-- ("DRONES ON THE STREET"), so it fits with 23 to spare. MEASURED, because
-- `TextScaled` fails by SHRINKING and reports success either way.
local TEXT_X = PAD + ICON + PAD
local TEXT_W = BODY_W - TEXT_X * 2

-- 1.67Hz, which is inside the three-flashes-a-second accessibility ceiling
-- this project holds the whole game to (`HouseFX` states it for the houses).
-- IT LIVES HERE RATHER THAN AT THE CALL SITES, which is the difference between
-- a ceiling and a coincidence: all three banners used to compute their own
-- `os.clock() % 0.6 < 0.3`, so three files each had to keep respecting it.
local PULSE = 0.6

-- How far into the ink a tone goes to become a ground. See the header.
local GROUND = 0.62

local function frame(parent: Instance, name: string): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Theme.INK
	f.Parent = parent
	return f
end

-- ONE ICON SLOT. An ImageLabel and a drawn chip, one of which is shown.
--
-- AN EMPTY IMAGE SLOT IS A WORKING STATE, which is the call `Config.ANIMATIONS`
-- and `Config.EVENT_UI.icon` both already make: a row can land before its
-- artwork does, and a picture that is ever moderated away degrades to the
-- drawing rather than to a hole. The drawn fallback is the dark disc with a
-- tone RING the notify chips and the prompt cards already use -- never a disc
-- OF the tone, because an emoji carries its own colours and ignores
-- `TextColor3` entirely, so a siren on a red disc is a red smudge.
local function iconSlot(body: Frame, name: string, rightHand: boolean): any
	local holder = frame(body, name)
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(ICON, ICON)
	holder.AnchorPoint = Vector2.new(if rightHand then 1 else 0, 0.5)
	holder.Position = UDim2.new(if rightHand then 1 else 0,
		if rightHand then -PAD else PAD, 0.5, 0)

	local picture = Instance.new("ImageLabel")
	picture.Name = "Picture"
	picture.BackgroundTransparency = 1
	picture.Size = UDim2.fromScale(1, 1)
	picture.ScaleType = Enum.ScaleType.Fit
	picture.Image = ""
	picture.Visible = false
	picture.Parent = holder

	local chip = Instance.new("TextLabel")
	chip.Name = "Chip"
	chip.Size = UDim2.fromScale(1, 1)
	chip.Text = ""
	chip.TextSize = 21
	chip.Parent = holder
	Theme.chip(chip, ICON, Theme.PAPER)
	local ring = chip:FindFirstChildOfClass("UIStroke")

	return { holder = holder, picture = picture, chip = chip, ring = ring }
end

-- `y` is the top of the row this banner owns in the top-centre column, which
-- is measured and full -- see the notes beside it in ClientMain before moving
-- one.
function Announce.new(parent: Instance, name: string, y: number): any
	local root = frame(parent, name)
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(ROOT_W, BODY_H)
	root.Position = UDim2.new(0.5, 0, 0, y)
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Visible = false

	-- THE POP. A scale tween on arrival, which is the whole of what makes an
	-- announcement land rather than appear. On the ROOT, so the tails, the
	-- icons and the type all come in together as one object.
	local pop = Instance.new("UIScale")
	pop.Scale = 1
	pop.Parent = root

	-- The tails are SIBLINGS of the body and not children of it. Under
	-- `ZIndexBehavior.Sibling` -- which this HUD uses -- A CHILD ALWAYS DRAWS
	-- ABOVE ITS PARENT whatever its ZIndex, so a tail parented to the body
	-- would cover the body it is supposed to sit behind. That is the trap the
	-- rebirth button's halo already paid for.
	local tails = {}
	for i, side in ipairs({ -1, 1 }) do
		local tail = frame(root, if side < 0 then "TailLeft" else "TailRight")
		tail.Size = UDim2.fromOffset(TAIL, TAIL)
		tail.AnchorPoint = Vector2.new(0.5, 0.5)
		tail.Position = UDim2.new(0.5, side * BODY_W / 2, 0.5, 0)
		tail.Rotation = 45
		tail.ZIndex = 1
		Theme.corner(tail, 3)
		Theme.outline(tail)
		tails[i] = tail
	end

	local body = frame(root, "Body")
	body.Size = UDim2.fromOffset(BODY_W, BODY_H)
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.new(0.5, 0, 0.5, 0)
	body.ZIndex = 2
	Theme.corner(body, 14)
	Theme.outline(body)
	-- SHADED AND NOT GLOSSED, for the reason all three of the old banners were:
	-- the ground is rewritten every frame by the pulse, and `Theme.gloss` bakes
	-- two colours in, so the next frame would replace it. `Theme.shade`
	-- MULTIPLIES, which leaves the panel moulded whatever colour it is now.
	Theme.shade(body)

	local left = iconSlot(body, "IconLeft", false)
	local right = iconSlot(body, "IconRight", true)

	-- THE HEADLINE AND THE LINE UNDER IT, which is what let the type get big.
	--
	-- One line could not take it. The carry banner's longest string is
	-- "CARRYING 999.9K <dot> TAKE YOUR HAUL HOME!" -- 478px at 26px against a
	-- 296px column, so it would have shrunk to about 16 and the ask was for
	-- BIG. Split, the headline is 190 and the instruction under it is 175 in
	-- its own smaller font, and both fit at full size. Every other banner in
	-- the game turned out to be two facts joined by a middot as well: what is
	-- happening, and how long you have.
	local headline = Instance.new("TextLabel")
	headline.Name = "Headline"
	headline.Size = UDim2.fromOffset(TEXT_W, 28)
	headline.Position = UDim2.fromOffset(TEXT_X, 3)
	headline.TextScaled = true
	headline.Text = ""
	headline.Parent = body
	Theme.title(headline, 26, Theme.PAPER)
	-- Contextual, which is the default and strokes the GLYPHS. `Theme.outline`
	-- is the wrong helper here and the difference is two words: it sets
	-- `ApplyStrokeMode.Border`, which outlines the label's invisible RECTANGLE
	-- and draws a floating box over the banner. `RobberMark` records the same
	-- distinction for the bang over a thief's head.
	headline.TextStrokeColor3 = Theme.INK
	headline.TextStrokeTransparency = 0.25
	local headLimit = Instance.new("UITextSizeConstraint")
	headLimit.MinTextSize, headLimit.MaxTextSize = 15, 26
	headLimit.Parent = headline

	local subline = Instance.new("TextLabel")
	subline.Name = "Subline"
	subline.Size = UDim2.fromOffset(TEXT_W, 15)
	subline.Position = UDim2.fromOffset(TEXT_X, 31)
	subline.BackgroundTransparency = 1
	subline.Font = Theme.FONT_BODY
	-- SCALED WITH A FLOOR RATHER THAN LEFT AT A FIXED SIZE. At a fixed 15 an
	-- over-long line does not truncate, it DRAWS OUTSIDE the banner -- which is
	-- the failure that once ate two whole tabs off the shop rail, because a
	-- layout that overflows neither clips nor errors. Today's longest subline
	-- measures 175 of the 296px column, so nothing shrinks; the constraint is
	-- there so that the day one does, it gets smaller instead of escaping.
	subline.TextScaled = true
	subline.TextSize = 15
	subline.TextColor3 = Theme.PAPER
	subline.TextTransparency = 0.12
	subline.TextStrokeColor3 = Theme.INK
	subline.TextStrokeTransparency = 0.4
	subline.Text = ""
	subline.Parent = body
	local subLimit = Instance.new("UITextSizeConstraint")
	subLimit.MinTextSize, subLimit.MaxTextSize = 11, 15
	subLimit.Parent = subline

	-- THE COUNTDOWN AS A BAR, kept from the event banner because the argument
	-- is unchanged: "42s" is a thing you READ and a draining bar is a thing you
	-- SEE, and this is read by somebody who is running. It sits along the
	-- bottom edge of the body rather than under the text, so it underlines the
	-- whole banner and needs none of the 52 pixels the type is using.
	local track = frame(body, "Track")
	track.Size = UDim2.new(1, -28, 0, 4)
	track.Position = UDim2.new(0.5, 0, 1, -7)
	track.AnchorPoint = Vector2.new(0.5, 0)
	-- A groove UNDER the ground rather than a second surface on top of it --
	-- the same call the upgrade pips make for an unbought rung.
	track.BackgroundTransparency = 0.72
	Theme.corner(track, 2)

	local fill = frame(track, "Fill")
	fill.Size = UDim2.fromScale(1, 1)
	Theme.corner(fill, 2)

	local self = {
		root = root, body = body, tails = tails, pop = pop,
		headline = headline, subline = subline, track = track, fill = fill,
		left = left, right = right, tween = nil :: Tween?, shown = false,
	}

	-- ONE ICON, BOTH SIDES, and deliberately not mirrored. An ImageLabel has no
	-- horizontal flip -- `Rotation = 180` turns it upside down as well -- and
	-- the thing this was asked for, a siren each end, reads correctly repeated.
	-- Anything that genuinely needs a mirrored pair wants two ids rather than a
	-- transform that does not exist.
	local function paintIcon(slot: any, spec: any, tone: Color3)
		local image = spec.image
		local hasImage = type(image) == "string" and image ~= ""
		slot.picture.Visible = hasImage
		slot.chip.Visible = not hasImage
		if hasImage then
			slot.picture.Image = image
		else
			slot.chip.Text = spec.glyph or ""
			if slot.ring then
				slot.ring.Color = tone
			end
		end
	end

	-- `spec` is nil to hide. Otherwise:
	--   tone     Color3   which announcement this is; the ground is it deepened
	--   headline string   what is happening, in big white type
	--   subline  string?  how long you have, or what to do about it
	--   glyph    string?  the drawn fallback icon
	--   image    string?  an uploaded icon, which wins when it is set
	--   progress number?  0..1, or nil for no underline
	--   pulse    boolean? flash the ground and the tone trim
	function self:set(spec: any)
		if not spec then
			self.root.Visible = false
			self.shown = false
			return
		end
		local tone = spec.tone or Theme.STOP
		local ground = tone:Lerp(Theme.INK, GROUND)
		-- Owned here so the ceiling is one number in one file. A pulsed banner
		-- darkens further rather than brightening past its own ground, because
		-- the type is printed on it and the measured floor above is the DIM
		-- state -- brightening would have put white on the raw tone at the top
		-- of every cycle, which is the 1.41-to-3.47 band this file exists to
		-- get out of.
		local lit = (not spec.pulse) or (os.clock() % PULSE < PULSE / 2)
		self.body.BackgroundColor3 = if lit then ground else ground:Lerp(Theme.INK, 0.45)
		for _, tail in ipairs(self.tails) do
			tail.BackgroundColor3 = if lit then tone else tone:Lerp(Theme.INK, 0.4)
		end
		self.headline.Text = spec.headline or ""
		self.subline.Text = spec.subline or ""
		self.subline.Visible = (spec.subline or "") ~= ""
		self.track.BackgroundColor3 = Theme.INK
		self.fill.BackgroundColor3 = tone
		local progress = spec.progress
		self.track.Visible = type(progress) == "number"
		if type(progress) == "number" then
			self.fill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
		end
		paintIcon(self.left, spec, tone)
		paintIcon(self.right, spec, tone)

		if not self.shown then
			self.shown = true
			self.root.Visible = true
			-- ARRIVAL ONLY, never on every repaint: this runs off a Heartbeat,
			-- so tweening unconditionally would restart the pop sixty times a
			-- second and the banner would sit there quivering.
			if self.tween then
				self.tween:Cancel()
			end
			self.pop.Scale = 0.86
			self.tween = TweenService:Create(self.pop,
				TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 })
			;(self.tween :: Tween):Play()
		end
	end

	return self
end

return Announce
