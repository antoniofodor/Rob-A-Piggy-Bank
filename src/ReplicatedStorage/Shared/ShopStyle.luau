--!strict
-- ============================================================
-- THE SHOP'S VISUAL KIT
-- ============================================================
--
-- THE SHOP WAS BORING, AND BORING WAS A CHOICE NOBODY MADE ON PURPOSE. It
-- grew a tab at a time, and every tab was drawn in the HUD's own vocabulary:
-- flat dark rectangles, 2-pixel edges, 13-pixel Gotham. That vocabulary is
-- correct for the HUD, which sits over the game and must never compete with
-- it -- and it is exactly wrong for the one screen a player OPENS on purpose
-- and then reads for a minute. The HUD's job is to disappear; the shop's job
-- is to be worth opening.
--
-- So this is a second vocabulary, and the whole of it is four moves that
-- cost nothing and are applied everywhere:
--
--   OUTLINE   every surface carries a thick near-black edge. This is what
--             separates a toy from a form. It is the single biggest
--             difference between this and what was here before.
--   ROUND     large radii. A 6-pixel corner reads as a dialog; a 16-pixel
--             one reads as moulded plastic.
--   GLOSS     a light vertical gradient on the fill, brightest at the top.
--             One gradient turns a flat colour into a lit object.
--   POP       type carries its own dark outline, so a bright label stays
--             readable on a bright card and reads as a sticker rather than
--             as a caption.
--
-- It is a MODULE and not a block in ClientMain for the reason HotBar,
-- Rebirth, SpinWheel and AdminPanel are: that chunk is at Luau's 200-local
-- ceiling, and a function body gets its own register file. This costs the
-- caller ONE local for the whole vocabulary.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)

local ShopStyle = {}

-- NOT A PALETTE. A VIEW ONTO ONE.
--
-- Everything below is a name for something in `Theme`, and that is the whole
-- point of the file having been rewritten: it used to carry its own colours,
-- which made it a SECOND palette however carefully each one was chosen, and
-- opening the shop changed which game you were in.
--
-- Three of them moved a long way in the process and each is worth naming:
--
--   THE PANEL WAS PINK, AND PINK MEANS THE PIG. Painting the shop with it
--   spent the pig's own colour on the largest surface in the game, so the
--   piggy bank panel on the HUD -- the one readout that IS the pig -- had
--   nothing left to be. The panel is SAND now, a neutral, and pink went back
--   to meaning something.
--
--   THE WELL WAS A COLD SLATE at hue 221 while every other dark in the game
--   was warm. It measured fine and looked assembled, which is the failure
--   this whole pass is about: contrast chose nothing here -- every candidate
--   dark landed between 8.7 and 10.5 against gold -- so hue was the only
--   thing left to decide it, and one axis beats nine degrees of contrast.
--
--   THE CARD IS PAPER, the same PAPER a toast is. A shop card and a HUD card
--   being literally the same colour is most of what "consistent" means here.
--
-- Keeping the names is deliberate: 167 call sites read `ShopStyle.CARD`, and
-- pointing them at `Theme` one alias at a time would have been a rename with
-- no behaviour in it. What matters is that there is now exactly one place a
-- colour is DECIDED.
ShopStyle.INK = Theme.INK
ShopStyle.BASE = Theme.SAND      -- the panel itself
ShopStyle.CARD = Theme.PAPER     -- an ordinary card on it
ShopStyle.SUNK = Theme.SLAB      -- a well an icon sits in
ShopStyle.TEXT = Theme.INK
ShopStyle.LIGHT = Theme.PAPER
ShopStyle.MUTED = Theme.MUTED
ShopStyle.GOLD = Theme.GOLD
ShopStyle.GOOD = Theme.GOOD
ShopStyle.STOP = Theme.STOP

-- CARD STATE: what you can do with this item, as a tint of the card rather
-- than as a replacement for it.
--
-- Each is its accent lifted 58% of the way to PAPER, so the four are
-- siblings by construction instead of by four separate judgements -- which
-- is how the last set ended up with a green nobody could find in the table.
-- Measured against INK at 9.4 to 12.9, so a card name is readable on every
-- one of them, and against each other by HUE rather than by lightness.
--
-- 58 AND NOT 74, AND THE FIRST NUMBER WAS MEASURABLY TOO WEAK. At 74% every
-- state landed within 1.006 to 1.209 of the ground -- so on the skins tab,
-- with twenty-seven affordable cards, seven owned and thirteen locked all on
-- screen at once, the three read as one cream. State is the only thing a
-- card's BACKGROUND says (its edge is the rarity and its pill is the price),
-- so a state you cannot see is the background saying nothing.
ShopStyle.OWNED = Color3.fromRGB(173, 231, 189)   -- good, lifted
ShopStyle.BUY = Color3.fromRGB(255, 229, 160)     -- gold, lifted
-- The one that goes the other way: too dear reads as RECESSED, a step BELOW
-- the ground rather than a tint above it.
ShopStyle.DEAR = Color3.fromRGB(219, 202, 180)
ShopStyle.LOCKED = Color3.fromRGB(224, 184, 242)  -- purple, lifted

-- The category hues live in `Theme` now, for the same reason the rest of
-- this moved: a second table of nine colours is a second palette however
-- carefully it is written, and the shop is no longer the only thing drawing
-- them. Aliased rather than re-exported so no call site had to change.
ShopStyle.HUE = Theme.HUE

function ShopStyle.round(inst: Instance, radius: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = inst
	return c
end

-- `Border` mode rather than the default: a Contextual stroke on a Frame is
-- drawn INSIDE the shape, so a 3-pixel edge eats 3 pixels of a 62-pixel icon
-- well and the artwork inside starts to look cropped.
function ShopStyle.outline(inst: Instance, thickness: number?, colour: Color3?): UIStroke
	local s = Instance.new("UIStroke")
	s.Name = "Outline"
	s.Color = colour or ShopStyle.INK
	s.Thickness = thickness or 3
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

-- The sheen, and the one thing about it that is not obvious: A UIGRADIENT CAN
-- ONLY DARKEN. `Color` MULTIPLIES the fill, and channels are capped at 1, so
-- there is no way to add a highlight with it. The first version tried to fake
-- one through `Transparency` instead and did not produce a lit top edge -- it
-- produced a SEE-THROUGH one, because Transparency fades the object out
-- rather than lightening it. Measured on the live panel: the gold coin pill
-- rendered as a dark olive smear with the panel showing through it.
--
-- So a sheen is built the other way round. The fill is authored at the LIT
-- value, and the gradient darkens toward the bottom. Same result, and it is
-- the only version the engine can actually draw.
function ShopStyle.gloss(inst: Instance, strength: number?): UIGradient
	local k = 1 - (strength or 0.16)
	local g = Instance.new("UIGradient")
	g.Name = "Gloss"
	g.Rotation = 90
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.55, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.new(k, k, k)),
	})
	g.Parent = inst
	return g
end

-- Type that survives being put on a bright colour. Without this, white
-- FredokaOne on the amber category is barely legible and the same label on
-- the green one is fine -- so the shop would look inconsistent for a reason
-- nobody could name.
function ShopStyle.pop(label: TextLabel | TextButton, thickness: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Name = "Pop"
	s.Color = ShopStyle.INK
	s.Thickness = thickness or 2
	s.Parent = label
	return s
end

-- A DARKER, DESATURATED RELATIVE OF A HUE, for the well an icon sits in. It
-- is derived rather than listed so a new category needs one colour and not
-- three, and so the two can never drift apart.
function ShopStyle.deepen(hue: Color3, amount: number?): Color3
	return hue:Lerp(ShopStyle.SUNK, amount or 0.72)
end

-- The recurring shape: a filled, outlined, rounded, glossed surface. Nearly
-- everything in the shop is one of these, which is what makes the screen look
-- like it was designed rather than assembled.
function ShopStyle.surface(parent: Instance, fill: Color3, radius: number?, thickness: number?): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = fill
	f.BorderSizePixel = 0
	f.Parent = parent
	ShopStyle.round(f, radius or 14)
	ShopStyle.outline(f, thickness)
	ShopStyle.gloss(f)
	return f
end

-- A pill: the price, the count, OWNED, EQUIPPED. Returns the label so the
-- caller can drive its text and colour without looking children up by name.
function ShopStyle.chip(parent: Instance, fill: Color3, textColour: Color3?): TextLabel
	local chip = Instance.new("TextLabel")
	chip.BackgroundColor3 = fill
	chip.BorderSizePixel = 0
	chip.Font = Enum.Font.FredokaOne
	chip.TextScaled = true
	chip.TextColor3 = textColour or ShopStyle.TEXT
	chip.Text = ""
	chip.Parent = parent
	ShopStyle.round(chip, 999)
	ShopStyle.outline(chip, 2)
	ShopStyle.gloss(chip, 0.14)

	-- POP ONLY WHEN THE TYPE IS LIGHT. A dark outline exists to hold pale text
	-- off a bright fill; put it around text that is ALREADY dark and it just
	-- thickens the glyphs into a smear. Measured on the gold coin pill, whose
	-- ink text and ink outline turned "3.1M coins" into a muddy blob -- and
	-- dark-on-light needs no help anyway, which is why it was chosen.
	local lum = textColour and (textColour.R * 0.299 + textColour.G * 0.587
		+ textColour.B * 0.114) or 1
	if lum >= 0.5 then
		ShopStyle.pop(chip, 1.5)
	end

	-- Padding so a pill is never tight against its own outline. TextScaled
	-- fills the box exactly, and without this the glyphs touch the edge.
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 3)
	pad.PaddingBottom = UDim.new(0, 3)
	pad.Parent = chip
	return chip
end

-- THE ICON WELL: the top two-thirds of a card, which every catalogue in the
-- shop now shares. Before this the throwables, the home items, the thief kit
-- and the rides were all drawn as narrow ROWS -- a 48-pixel icon with three
-- lines of text beside it -- while skins, houses and decorations were cards.
-- Same shop, two shapes, and the row-shaped half looked like a settings list.
-- It also scrolled forever: the gear tab ran several screens because a row
-- wastes the width it is given.
function ShopStyle.well(button: GuiObject, fill: Color3?): Frame
	local well = Instance.new("Frame")
	well.Name = "Swatch"
	well.Size = UDim2.new(1, -16, 0, 98)
	well.Position = UDim2.new(0, 8, 0, 8)
	well.BackgroundColor3 = fill or ShopStyle.SUNK
	well.BorderSizePixel = 0
	well.ClipsDescendants = true
	well.Parent = button
	ShopStyle.round(well, 11)
	ShopStyle.outline(well, 2)
	return well
end

-- The price row, styled in place. It stays a plain TextLabel because roughly
-- a dozen sites write its Text and TextColor3 -- owned, equipped, affordable,
-- too dear, sold out -- and every one of them still reads correctly as
-- coloured type on a dark pill.
function ShopStyle.priceRow(label: TextLabel)
	label.BackgroundColor3 = ShopStyle.SUNK
	label.BackgroundTransparency = 0
	label.BorderSizePixel = 0
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = false
	label.TextSize = 13
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextXAlignment = Enum.TextXAlignment.Center
	ShopStyle.round(label, 999)
	ShopStyle.outline(label, 2)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = label
end

-- A "?" ON A SECTION HEADER, OPENING A BUBBLE.
--
-- The first version expanded the paragraph INLINE, underneath the header. It
-- shortened the tab, which was the point, and it was still wrong in two ways:
-- the text was set at the width of the whole scroll, so it ran to 90-odd
-- characters a line at 13px and read as fine print; and opening one PUSHED
-- every card below it down the page, so the thing you were looking at moved
-- while you read about it.
--
-- A bubble fixes both. It is a fixed, narrow measure over a dark card, laid
-- OVER the tab rather than inside it, so nothing reflows and the text is set
-- at a width somebody can actually read.
--
-- ONE BUBBLE, REUSED. Every "?" in the shop drives the same instance, which
-- is what makes "opening another one closes this one" free rather than
-- bookkeeping across seven of them.
local hintHost: GuiObject? = nil
local bubble: Frame? = nil
local bubbleBody: TextLabel? = nil
local bubbleOwner: GuiObject? = nil

function ShopStyle.setHintHost(host: GuiObject)
	hintHost = host
end

local function ensureBubble(): (Frame?, TextLabel?)
	if bubble then
		return bubble, bubbleBody
	end
	local host = hintHost
	if not host then
		return nil, nil
	end

	local frame = Instance.new("Frame")
	frame.Name = "HintBubble"
	frame.Size = UDim2.new(0, 330, 0, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	-- IT INVERTS WITH THE SHOP. The bubble was cream when the shop was brown,
	-- for contrast -- the one thing on the page that exists to be READ must
	-- not be the lowest-contrast surface on it. The shop is light pink now, so
	-- cream would vanish into it and the bubble goes DARK instead. The rule is
	-- the contrast, not the colour.
	frame.BackgroundColor3 = ShopStyle.SUNK
	frame.BorderSizePixel = 0
	frame.Visible = false
	-- Above every card in the view it floats over. The shop's ScreenGui is
	-- Sibling, so a child always draws above its parent and this only has to
	-- beat its own siblings.
	frame.ZIndex = 50
	frame.Parent = host
	ShopStyle.round(frame, 14)
	ShopStyle.outline(frame, 3)

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Gotham
	-- 14, not 13. This is the one place in the shop somebody actually READS a
	-- paragraph, and it is no longer competing with a card for space.
	body.TextSize = 14
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextColor3 = ShopStyle.LIGHT
	body.ZIndex = 51
	body.Text = ""
	body.Parent = frame

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.Parent = frame

	-- Tapping the bubble puts it away. There is nothing else to do with it,
	-- and a nine-year-old's first instinct with something in the way is to
	-- touch it.
	local dismiss = Instance.new("TextButton")
	dismiss.Name = "Dismiss"
	dismiss.Size = UDim2.new(1, 0, 1, 0)
	dismiss.BackgroundTransparency = 1
	dismiss.Text = ""
	dismiss.ZIndex = 52
	dismiss.Parent = frame
	dismiss.Activated:Connect(function()
		frame.Visible = false
		bubbleOwner = nil
	end)

	bubble, bubbleBody = frame, body
	return frame, body
end

function ShopStyle.hintToggle(header: TextLabel, source: TextLabel | string)
	-- A LABEL OR A STRING. The callers mostly still BUILD their paragraph as a
	-- label, because that is where the words already live and moving seven of
	-- them into call arguments would be a large diff for no gain -- the text
	-- is taken and the label thrown away, so nothing is left in the scroll to
	-- lay out. A string is for the merged sections, where two paragraphs that
	-- used to have a header each now share one and have to be joined first.
	local text = if type(source) == "string" then source else (source :: TextLabel).Text
	if type(source) ~= "string" then
		(source :: TextLabel):Destroy()
	end

	local q = Instance.new("TextButton")
	q.Name = "Hint"
	q.Size = UDim2.new(0, 22, 0, 22)
	q.Position = UDim2.new(0, header.TextBounds.X + 8, 0, 1)
	q.BackgroundColor3 = ShopStyle.CARD
	q.BorderSizePixel = 0
	q.Font = Enum.Font.FredokaOne
	q.TextSize = 14
	q.TextColor3 = ShopStyle.TEXT
	q.AutoButtonColor = true
	q.Text = "?"
	q.Parent = header
	ShopStyle.round(q, 999)
	ShopStyle.outline(q, 2)

	-- TextBounds is 0 until the label has been laid out once, so the chip is
	-- re-seated when it changes rather than placed off a stale measurement --
	-- the same stale-geometry trap the front page's section jump hit.
	header:GetPropertyChangedSignal("TextBounds"):Connect(function()
		q.Position = UDim2.new(0, header.TextBounds.X + 8, 0, 1)
	end)

	q.Activated:Connect(function()
		local frame, body = ensureBubble()
		if not frame or not body then
			return
		end
		if bubbleOwner == q and frame.Visible then
			frame.Visible = false
			bubbleOwner = nil
			return
		end
		body.Text = text
		bubbleOwner = q

		-- SEATED UNDER ITS OWN "?" AND CLAMPED TO THE HOST, so a chip near the
		-- right edge does not open a bubble half off the panel. Measured from
		-- the host's own top-left rather than in screen space, because the
		-- bubble is a child of the host.
		local host = frame.Parent :: GuiObject
		local x = q.AbsolutePosition.X - host.AbsolutePosition.X
		local y = q.AbsolutePosition.Y - host.AbsolutePosition.Y + q.AbsoluteSize.Y + 8
		frame.Visible = true
		x = math.clamp(x, 8, math.max(8, host.AbsoluteSize.X - frame.AbsoluteSize.X - 8))
		y = math.clamp(y, 8, math.max(8, host.AbsoluteSize.Y - frame.AbsoluteSize.Y - 8))
		frame.Position = UDim2.new(0, x, 0, y)
	end)
end

-- Put the bubble away whenever the shop changes underneath it -- a tab
-- switch, or the panel closing. Without this it hangs over whatever you
-- opened next, describing a section you can no longer see.
function ShopStyle.closeHint()
	if bubble then
		bubble.Visible = false
	end
	bubbleOwner = nil
end

return ShopStyle
