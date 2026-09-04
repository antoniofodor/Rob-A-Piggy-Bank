--!strict
--[[
	Theme

	What every surface in this game's UI is made of.

	----------------------------------------------------------------------

	THE OLD PALETTE WAS A DASHBOARD, AND THIS IS A CARTOON.

	Everything was cold navy -- ink (28, 33, 44) on panel (38, 45, 60) -- with
	a thin accent stroke and a grey body font. That is the default look of
	every admin console and analytics page ever built, and it is the wrong one
	for a game about robbing a piggy bank, aimed at nine-year-olds, rendered in
	full sun on green grass.

	Three things carry the change, and the first is doing almost all the work.

	**THE INK OUTLINE IS THE WHOLE TRICK.** A hard dark line round every
	surface is the single difference between a flat rectangle and something
	that reads as drawn -- it is what a sticker, a comic panel and every
	cartoon UI ever shipped have in common. It also solves a real problem
	rather than only a stylistic one: a pale card on bright grass has no edge
	of its own, and a thin coloured stroke at 2px does not give it one.

	**THE GROUND IS WARM PAPER, NOT COLD SLATE.** Cream reads as a label stuck
	on the world; navy reads as a window cut into it. Everything here is on the
	warm side of neutral, the near-black included -- a cold outline on a warm
	surface is the tell that a palette was assembled rather than chosen.

	**AND THAT IS NOW A MEASURED PROPERTY RATHER THAN AN INTENTION.** Every
	neutral in this file sits between hue 21 and hue 39, outline to paper. It
	did not, for a long time: this file's own near-black was a plum at 322
	while ClientMain's, the shop's icon well and every survivor of the old
	dashboard were a navy at 221 -- a hundred degrees apart, in one interface.
	Anything added here gets its hue checked against that band.

	**GLOSS IS A GRADIENT, BECAUSE THERE ARE NO IMAGE ASSETS.** Real texture
	means an upload, an upload is a third-party asset that can be moderated
	away, and this project builds the ground, the houses and the piggies in
	code for exactly that reason. A two-stop vertical gradient is the asset-free
	way to make a surface look moulded rather than printed, and it costs one
	instance.

	----------------------------------------------------------------------

	COLOUR STILL MEANS SOMETHING; IT JUST STOPPED BEING THE GROUND.

	`Config.NOTIFY` and `Config.PROMPTS` both key their whole design off a
	TONE, and none of that changes. What changes is where the tone goes: it was
	the panel and the stroke, and it is now the chip, the stripe and the
	heading, on a surface that stays the same colour whatever happened. That
	keeps a robbery red and a purchase gold while stopping every card in the
	game from being a different-coloured dark rectangle.

	The tones themselves were left alone on purpose. They are already tuned
	against each other and against the accessibility note about colour never
	being the only signal.
]]

local Theme = {}

-- ============================================================
-- THE PALETTE
-- ============================================================
--
-- ONE LADDER, ONE AXIS, AND THE DRIFT WAS MEASURABLE RATHER THAN A MATTER OF
-- TASTE. Before this there were two near-blacks a hundred degrees apart on
-- the colour wheel -- this file's INK at hue 322 (a plum) and ClientMain's
-- own INK, the shop's well and every leftover of the old dashboard at hue
-- 221 (a navy) -- plus two golds differing by two degrees and nothing else.
-- ClientMain alone carried 163 colour literals in 101 distinct values.
--
-- Every neutral here now sits on ONE warm axis, hue 21 to 39, from the
-- outline to the paper. That is what makes a palette read as chosen rather
-- than as assembled, and it is the only property of this table that must not
-- be broken by anything added later: a cold grey dropped into this set will
-- look like a mistake even to somebody who cannot say why.
--
-- ----------------------------------------------------------------------
--
-- AND THE GROUND IS A NEUTRAL, BECAUSE PINK AND GOLD BOTH MEAN SOMETHING.
--
-- `GOLD MEANS MONEY AND PINK MEANS THE PIG` is the whole colour system of
-- this game, and the shop broke it by painting its panel pink -- so the
-- pig's own colour became sixty percent of the screen, and the one readout
-- that IS the pig (the piggy bank panel) stopped having a colour of its own.
-- An accent spent on a ground is an accent spent.
--
-- The same trap sits under gold. Making the whole shop gold would cost the
-- coin counter exactly what pink cost the piggy bank.
--
-- So the ground is SAND: the warm neutral one step down from PAPER, on the
-- same axis, carrying no meaning at all. Pink and gold go back to being
-- accents that say something, and the shop and the HUD are finally the same
-- material -- a PAPER card is a PAPER card in both.

-- ---- the neutral ladder, darkest first --------------------------------
-- The outline, and text on any light surface.
Theme.INK = Color3.fromRGB(41, 32, 27)

-- A dark surface: the ground of every icon chip and every icon well. It
-- exists to be a HOLE for something to sit in, never a colour of its own,
-- which is why it is a warm near-black and not a tone.
Theme.SLAB = Color3.fromRGB(54, 44, 37)
Theme.SLAB_DEEP = Color3.fromRGB(28, 22, 19)

-- Secondary text. TWO of them, because one colour cannot be secondary on
-- both grounds: faded ink on paper, and faded paper on a slab. Same warm
-- axis, same relationship to the surface they sit on, opposite ends of it.
Theme.MUTED = Color3.fromRGB(107, 84, 69)
Theme.MUTED_LIGHT = Color3.fromRGB(196, 178, 156)

-- THE GROUND. Any large panel -- the shop, an overlay, a board. One step
-- deeper than PAPER, so a card laid on it separates (measured at 1.20)
-- without needing a colour of its own.
Theme.SAND = Color3.fromRGB(245, 225, 198)
Theme.SAND_DEEP = Color3.fromRGB(224, 198, 166)

-- THE CARD. The ground of nearly everything small and readable.
Theme.PAPER = Color3.fromRGB(255, 247, 232)
Theme.PAPER_DEEP = Color3.fromRGB(237, 220, 194)

-- ---- the accents, each of which means one thing -----------------------
--
-- Built as a FAMILY rather than picked one at a time: saturation 0.72
-- throughout, and value 0.90 except in the green band (hue 80 to 200) where
-- it is 0.82, because green and lime read considerably brighter than red and
-- blue at the same value. Equalising the number rather than the appearance
-- is what makes a set of accents look like nine unrelated colours.
--
-- GOLD is the one deliberate exception: it is a MATERIAL rather than a
-- category -- it is what a coin is made of -- so it is carried at full value.

-- Money. Coins, prices, the piggy bank's fill.
Theme.GOLD = Color3.fromRGB(255, 203, 61)
Theme.GOLD_DEEP = Color3.fromRGB(227, 138, 30)

-- The pig. The snout on the piggy bank panel, and the piggy tab. Lighter
-- than the rest of the accents on purpose: it is used as a SURFACE that
-- carries dark text, where every other accent is a small mark.
Theme.PIG = Color3.fromRGB(255, 163, 191)

-- THE EMPTY HALF OF THE PIGGY BANK BAR, AND IT HAS ONE JOB IT WAS FAILING:
-- to show the gold FILL sitting in it. At (232, 116, 155) it measured 1.87
-- against gold and 1.41 against the orange the bar turns when it is full --
-- so the one readout in this game that is a picture of a NUMBER could not
-- show you the number. It is a deep rose now: 2.98 against gold and 4.24
-- against the card behind it, so the bar reads as a bar from across a room.
--
-- Anything that changes this gets measured against BOTH fills, not one.
Theme.PIG_DEEP = Color3.fromRGB(196, 76, 120)

-- Success, owned, affordable, a thing that went right.
Theme.GOOD = Color3.fromRGB(59, 209, 129)
-- A refusal, a caution, the dog.
Theme.WARN = Color3.fromRGB(230, 136, 64)
-- An alarm, a loss, danger, the offence tree.
Theme.STOP = Color3.fromRGB(230, 81, 64)
-- Neutral information: the patrol, a hint, anything that is neither good nor
-- bad and must not be mistaken for either.
Theme.COOL = Color3.fromRGB(64, 147, 230)

-- REBIRTH, AND IT NEEDED ITS OWN SLOT RATHER THAN BORROWING ONE. The button
-- wore `HUE.effects` -- the shop's particle-effects tab -- which is a colour
-- that means "this tab" being used to mean "the biggest decision in the
-- game". They never appear on screen together, so nothing was visibly wrong;
-- it was just a colour saying two unrelated things.
--
-- DEEP, AND IT PRINTS CREAM. It was a LIGHT violet solved so that INK type
-- would clear on it, and it only just did -- 4.67, the worst body pair in the
-- game. The number that actually gave it away is the STAR: the gold chip this
-- button carries measured **2.25** on that violet, so the one thing on the
-- control that names the reward was the least readable thing on it. Reported
-- as the button looking muddy, which is exactly what a label and a badge both
-- sitting near the floor look like.
--
-- A mid-tone carries neither polarity well -- the same finding that moved the
-- dodge tile onto paper. Here the answer is the other direction: go DARK and
-- print PAPER. The label goes 4.67 -> 7.80 (9.06 at the gloss bottom) and the
-- gold star 2.25 -> 5.48.
--
-- PLUM RATHER THAN VIOLET, so it sits on the warm side of the wheel with gold,
-- pink and sand instead of being the one cool surface in the game -- which is
-- what read as not matching. It is far enough from PIG (342, and light) and
-- from STOP (6) that it cannot be mistaken for the pig or for danger, and
-- nothing else in the game wears it.
Theme.PRESTIGE = Color3.fromRGB(128, 48, 101)
-- NOTE THERE IS NO `PRESTIGE_DEEP`, and the attempt to add one is worth
-- recording. A `Theme.gloss` ramping to a deep violet took INK type on the
-- rebirth buttons down to 2.47 -- and the contrast audit could not see it,
-- because a probe reads `BackgroundColor3`, which is the TOP of the ramp.
-- The button was plainly unreadable in a screenshot while the whole HUD
-- measured clean. The deep stop that WOULD carry ink is (155, 115, 250),
-- which is the fill itself, so there is no gloss to be had here at all.
-- These two buttons use `Theme.shade` -- a shallow multiply -- instead.
--
-- The general rule: anything printing dark type on a saturated fill gets
-- `shade`, not `gloss`. `gloss` is for surfaces whose text sits on the light
-- end, or which carry no text at all.

-- ---- category hues ----------------------------------------------------
--
-- EVERY CATEGORY OWNS A HUE, AND THAT IS NAVIGATION RATHER THAN DECORATION.
-- A tab, the shelf card that jumps to it and the header it lands on are all
-- one colour, so "the pink one" is a usable instruction for a player who
-- cannot yet reliably read "ACCESSORIES".
--
-- They live HERE rather than in ShopStyle because the shop is no longer the
-- only thing that draws them, and because a second table of nine hues is a
-- second palette however carefully it is written. Same family, same rule.
--
-- WITH ONE PROPERTY THE FAMILY RULE ALONE DID NOT GIVE THEM: every hue here
-- has to carry INK TYPE, because a shelf card is a block of its own colour
-- with its name printed on it. Built at a flat value of 0.90 three of them
-- did not -- red 4.26, pink 4.10 and purple 3.20 against a floor of 4.5, all
-- three on the front page where a nine-year-old picks a category by looking
-- at it. Red and pink only wanted their value taking to 1.0 and kept their
-- saturation; purple is the one hue on the wheel that cannot be bright at
-- full saturation, so it eased to 0.62. Anything added here gets the same
-- check -- it is the only constraint on this table that is not cosmetic.
Theme.HUE = {
	everything = Color3.fromRGB(230, 185, 64),
	upgrades = Color3.fromRGB(255, 90, 71),
	piggy = Color3.fromRGB(255, 71, 139),
	home = Color3.fromRGB(59, 209, 129),
	gear = Color3.fromRGB(64, 147, 230),

	-- ALIASES, and they have to be kept in step by hand: `skins` IS `piggy`
	-- and `kit` IS `upgrades`, which is the point -- a section and the tab it
	-- lives on must be one colour. Both were missed when red and pink were
	-- lightened, and the live audit caught exactly those two and nothing else.
	skins = Color3.fromRGB(255, 71, 139),
	effects = Color3.fromRGB(181, 97, 255),
	accessories = Color3.fromRGB(230, 185, 64),
	houses = Color3.fromRGB(59, 209, 129),
	decor = Color3.fromRGB(59, 204, 209),
	rides = Color3.fromRGB(64, 147, 230),
	kit = Color3.fromRGB(255, 90, 71),
	items = Color3.fromRGB(230, 136, 64),
	worn = Color3.fromRGB(129, 209, 59),
}

-- ---- type -------------------------------------------------------------
-- ONE FONT, and it is the display one. The body font was Gotham, which is a
-- fine interface face and exactly the wrong register here -- this audience is
-- nine and the game is a cartoon. FredokaOne everywhere means the HUD reads
-- as one object rather than as a UI kit with a game logo on it.
Theme.FONT = Enum.Font.FredokaOne
-- The one exception, for long sentences where a display face gets tiring.
Theme.FONT_BODY = Enum.Font.GothamBold

-- How thick the outline is. Deliberately chunky: at 2 it reads as a border
-- and at 3 it reads as drawn.
Theme.OUTLINE = 3
Theme.OUTLINE_THIN = 2

-- ============================================================
-- BUILDERS
-- ============================================================

function Theme.corner(inst: Instance, radius: number): UICorner
	local existing = inst:FindFirstChildOfClass("UICorner")
	if existing then
		existing.CornerRadius = UDim.new(0, radius)
		return existing
	end
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = inst
	return c
end

-- The ink line. Reuses an existing stroke rather than adding a second one, so
-- this is safe to apply to something that already had an accent border --
-- which is most of what it is being retrofitted onto.
function Theme.outline(inst: Instance, thickness: number?, colour: Color3?): UIStroke
	local stroke = inst:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Parent = inst
	end
	local s = stroke :: UIStroke
	s.Color = colour or Theme.INK
	s.Thickness = thickness or Theme.OUTLINE
	s.Transparency = 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	return s
end

-- A vertical sheen: lighter at the top, deeper at the bottom. This is the
-- asset-free stand-in for texture, and the reason it works is that a flat
-- fill reads as a rectangle while a graded one reads as a moulded object.
--
-- `strength` is how far down the deep stop goes, not how dark it is -- the
-- two colours are the caller's, because a gold badge and a cream card want
-- different bottoms.
function Theme.gloss(inst: Instance, top: Color3, bottom: Color3): UIGradient
	local existing = inst:FindFirstChildOfClass("UIGradient")
	local g = existing or Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, top),
		-- The highlight is held across the top third rather than fading from
		-- the very first pixel, which is what makes it read as a lit surface
		-- instead of a linear wash.
		ColorSequenceKeypoint.new(0.34, top),
		ColorSequenceKeypoint.new(1, bottom),
	})
	g.Rotation = 90
	g.Parent = inst
	return g
end

-- A NEUTRAL SHADING GRADIENT, for a surface whose colour is written at
-- runtime.
--
-- `Theme.gloss` bakes two colours in, which is right for anything that keeps
-- the same ground for its life and useless for anything that does not -- the
-- street banner rewrites its own BackgroundColor3 every frame while it
-- flashes, and a baked gradient would simply replace whatever it chose.
--
-- A UIGradient MULTIPLIES the background rather than replacing it, so a white
-- to grey ramp is a pure shading pass: it darkens the bottom of the panel and
-- leaves the hue to the caller, whatever the caller decides it is this frame.
function Theme.shade(inst: Instance, depth: number?): UIGradient
	local d = depth or 0.76
	local low = Color3.new(d, d, d)
	local existing = inst:FindFirstChildOfClass("UIGradient")
	local g = existing or Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.34, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, low),
	})
	g.Rotation = 90
	g.Parent = inst
	return g
end

-- The standard surface: paper, outlined, glossed, chunky corners. Returns the
-- frame it was given, so it drops into an existing chain.
function Theme.card(frame: GuiObject, radius: number?): GuiObject
	frame.BackgroundColor3 = Theme.PAPER
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	Theme.corner(frame, radius or 14)
	Theme.outline(frame)
	Theme.gloss(frame, Theme.PAPER, Theme.PAPER_DEEP)
	return frame
end

-- The same, in a colour. For the few surfaces that ARE their colour -- the
-- coin badge, a banner -- rather than carrying one.
function Theme.tinted(frame: GuiObject, top: Color3, bottom: Color3, radius: number?): GuiObject
	frame.BackgroundColor3 = top
	frame.BackgroundTransparency = 0
	frame.BorderSizePixel = 0
	Theme.corner(frame, radius or 14)
	Theme.outline(frame)
	Theme.gloss(frame, top, bottom)
	return frame
end

-- A COIN, DRAWN RATHER THAN TYPESET.
--
-- The coin counter carried a chip with the coin emoji in it at 19px, which is
-- the "unreadable icon" half of the same report -- an emoji renders from the
-- colour font at whatever size the box gives it, ignores `TextColor3`, and at
-- that size is a smudge. Three nested frames are legible at any size, take
-- the palette, and cost no more instances than the chip they replace.
--
-- Returns the outer frame so the caller positions one thing.
function Theme.coin(parent: Instance, size: number, name: string?): Frame
	local outer = Instance.new("Frame")
	outer.Name = name or "Coin"
	outer.Size = UDim2.new(0, size, 0, size)
	outer.BackgroundColor3 = Theme.GOLD
	outer.BorderSizePixel = 0
	outer.Parent = parent
	Theme.corner(outer, size // 2)
	Theme.outline(outer, Theme.OUTLINE_THIN)
	Theme.gloss(outer, Theme.GOLD, Theme.GOLD_DEEP)

	-- The rim: a smaller disc in the deeper gold, so the face reads as struck
	-- rather than as a flat circle.
	local rim = Instance.new("Frame")
	rim.Name = "Rim"
	rim.Size = UDim2.new(0, size - 8, 0, size - 8)
	rim.Position = UDim2.new(0.5, 0, 0.5, 0)
	rim.AnchorPoint = Vector2.new(0.5, 0.5)
	rim.BackgroundColor3 = Theme.GOLD_DEEP
	rim.BackgroundTransparency = 0.45
	rim.BorderSizePixel = 0
	rim.Parent = outer
	Theme.corner(rim, (size - 8) // 2)

	-- A highlight, off centre. One small pale dot is the whole difference
	-- between a disc and something with a surface.
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Size = UDim2.new(0, math.max(size // 5, 3), 0, math.max(size // 6, 2))
	shine.Position = UDim2.new(0.3, 0, 0.26, 0)
	shine.BackgroundColor3 = Color3.fromRGB(255, 246, 214)
	shine.BackgroundTransparency = 0.25
	shine.BorderSizePixel = 0
	shine.Parent = outer
	Theme.corner(shine, math.max(size // 8, 2))

	return outer
end

-- A PIG SNOUT, DRAWN, AND IT IS THE SIBLING OF `Theme.coin`.
--
-- The piggy bank panel used to BE pink -- a solid block of it, 320 by 74 in
-- the corner. That reads as pink; it does not read as a pig. And it spent
-- the accent on square footage, which is the exact fault that took the shop
-- off its pink ground: an accent on a ground is an accent spent.
--
-- The coin badge already had the answer. It is a PAPER card with a drawn
-- gold coin on it, and nobody mistakes it for anything else, because the
-- gold is on an OBJECT rather than under one. This is that move again: the
-- panel is a paper card like its neighbour, and the pig is a thing sitting
-- on it. The bar track underneath carries the rest of the pink.
--
-- Wider than it is tall, because a snout is; and no emoji, for the reason
-- the coin is drawn -- an emoji renders from the colour font, ignores
-- `TextColor3`, and is a smudge at this size.
function Theme.snout(parent: Instance, size: number, name: string?): Frame
	local outer = Instance.new("Frame")
	outer.Name = name or "Snout"
	outer.Size = UDim2.new(0, size, 0, math.floor(size * 0.78))
	outer.BackgroundColor3 = Theme.PIG
	outer.BorderSizePixel = 0
	outer.Parent = parent
	Theme.corner(outer, math.floor(size * 0.34))
	Theme.outline(outer, Theme.OUTLINE_THIN)
	Theme.gloss(outer, Theme.PIG, Theme.PIG_DEEP)

	-- Two nostrils, upright ovals, set in from the edges. They are the whole
	-- of what makes this a snout rather than a pink pill, so they are sized
	-- to be visible at the 30px this is actually drawn at rather than scaled
	-- from something that looked right larger.
	for i, at in ipairs({ 0.32, 0.68 }) do
		local hole = Instance.new("Frame")
		hole.Name = "Nostril" .. i
		hole.Size = UDim2.new(0, math.max(math.floor(size * 0.15), 3),
			0, math.max(math.floor(size * 0.34), 5))
		hole.Position = UDim2.new(at, 0, 0.5, 0)
		hole.AnchorPoint = Vector2.new(0.5, 0.5)
		hole.BackgroundColor3 = Theme.PIG_DEEP
		hole.BorderSizePixel = 0
		hole.Parent = outer
		Theme.corner(hole, math.max(math.floor(size * 0.08), 2))
	end

	return outer
end

-- A round chip for an icon. Dark ground with a tone ring, which is the rule
-- the notification chips already established: an emoji carries its own
-- colours and ignores TextColor3, so a tone-coloured disc loses both the
-- picture and the colour.
function Theme.chip(label: TextLabel, size: number, tone: Color3): TextLabel
	label.BackgroundColor3 = Theme.SLAB
	label.BackgroundTransparency = 0
	label.BorderSizePixel = 0
	label.Font = Theme.FONT
	Theme.corner(label, size // 2)
	Theme.outline(label, Theme.OUTLINE_THIN, tone)
	return label
end

-- A TONE, DARKENED UNTIL IT CAN BE READ ON PAPER.
--
-- This is the bill for moving the ground from navy to cream, and it comes due
-- on exactly the tones that were easiest to read before. `collect` is gold and
-- `recover` is a pale mint: both are bright, both were perfect as light text
-- on a dark panel, and both are nearly invisible AS text on cream. Measured,
-- the gold verb came out at a contrast ratio of 1.4 against the paper it was
-- sitting on.
--
-- So the tone stays the tone -- it is still the chip ring, the stripe and the
-- hold bar, where it sits on dark or is a solid block of itself -- and only
-- its TEXT form is darkened. One value, derived, rather than a second hand
-- authored colour per kind that somebody has to keep in step.
--
-- WCAG relative luminance, and the target is 4.5. That is the ratio for body
-- text; large display type is allowed 3.0, and this is used for both, so it
-- takes the stricter of the two rather than deciding per label.
local function luminance(c: Color3): number
	local function channel(v: number): number
		return if v <= 0.03928 then v / 12.92 else ((v + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * channel(c.R) + 0.7152 * channel(c.G) + 0.0722 * channel(c.B)
end

local function contrast(a: Color3, b: Color3): number
	local la, lb = luminance(a), luminance(b)
	if la < lb then
		la, lb = lb, la
	end
	return (la + 0.05) / (lb + 0.05)
end

-- AND IT HAS TO WORK IN BOTH DIRECTIONS, which it did not.
--
-- It only ever walked DOWN, which is correct on paper and exactly wrong on a
-- chip: asked for a readable green against a near-black well it returned a
-- DARKER green, so the one call that most needed help got the answer that
-- made it worse. Measured on the live tree afterwards, nine of the
-- twenty-seven remaining contrast failures were this: a tone darkened onto
-- something already dark.
--
-- The ground decides the direction now. Below a luminance of 0.18 the tone
-- is lifted instead -- value up, saturation eased off, because a saturated
-- hue cannot get bright enough on its own to clear a dark ground.
function Theme.readable(tone: Color3, against: Color3?): Color3
	local ground = against or Theme.PAPER
	local h, sat, v = tone:ToHSV()
	local out = tone
	local lift = luminance(ground) < 0.18
	-- Hold the HUE throughout, so a red stays red and a gold stays gold.
	-- Going down, saturation is nudged UP or a dimmed pastel turns to mud
	-- rather than into a deeper version of itself; going up it is eased OFF,
	-- for the same reason in reverse.
	-- 4.8 AND NOT 4.5, because stopping the instant it clears means landing
	-- ON the floor: measured, every `_INK` accent came out at 4.51 against a
	-- 4.5 bar. That is not a pass with a margin, it is a pass by a fifth of a
	-- percent, and it moves the moment a ground is nudged. Aiming past costs
	-- a shade of value and buys headroom on every caller at once.
	for _ = 1, 24 do
		if contrast(out, ground) >= 4.8 then
			return out
		end
		if lift then
			v = math.min(v + 0.05, 1)
			sat = math.max(sat - 0.05, 0.06)
		else
			v = math.max(v - 0.045, 0.12)
			sat = math.min(sat + 0.03, 1)
		end
		out = Color3.fromHSV(h, sat, v)
	end
	return out
end

-- Text that sits ON paper. Collected here so no caller has to remember that
-- the ground went light and white text stopped working.
-- Deliberately does NOT darken its colour. `Theme.readable` is applied at the
-- CALL SITE, because this helper has no idea what its label is sitting on and
-- two of its callers are on saturated grounds -- the carry banner's gold on
-- red and the street banner's white on a colour that changes every frame.
-- Folding it in here looked tidier and would have made the loudest two labels
-- in the game unreadable while fixing the quiet ones.
function Theme.title(label: TextLabel, size: number, colour: Color3?): TextLabel
	label.Font = Theme.FONT
	label.TextSize = size
	label.TextColor3 = colour or Theme.INK
	label.BackgroundTransparency = 1
	label.TextStrokeTransparency = 1
	return label
end

function Theme.body(label: TextLabel, size: number, colour: Color3?): TextLabel
	label.Font = Theme.FONT_BODY
	label.TextSize = size
	label.TextColor3 = colour or Theme.MUTED
	label.BackgroundTransparency = 1
	label.TextStrokeTransparency = 1
	return label
end

-- ---- accents, pre-darkened for TEXT on a light ground -----------------
--
-- `Theme.readable` walks a tone down until it clears 4.5:1 on paper, and it
-- is the right tool at a call site that knows what it is sitting on. But
-- nearly every caller sits on PAPER, and a hundred call sites each running
-- a 24-step loop to arrive at the same four colours is a colour decision
-- made a hundred times.
--
-- So the four that are actually used as TEXT are solved once, here. The
-- accent itself stays the accent -- it is still the chip ring, the stripe,
-- the pill and the fill, where it sits on dark or is a solid block of
-- itself. Only its written form is darkened.
Theme.GOOD_INK = Theme.readable(Theme.GOOD)
Theme.WARN_INK = Theme.readable(Theme.WARN)
Theme.STOP_INK = Theme.readable(Theme.STOP)
Theme.GOLD_INK = Theme.readable(Theme.GOLD)
Theme.COOL_INK = Theme.readable(Theme.COOL)

return Theme
