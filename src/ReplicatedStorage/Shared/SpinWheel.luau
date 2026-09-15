--!strict
--[[
	SpinWheel

	The reward reel that plays when a crate opens or an event drops a set item.

	A REEL, NOT A PIE. Roblox's UI has no arc or conic gradient, so a real
	segmented wheel would be a stack of rotated images faking curvature -- a
	lot of work to end up with something that reads worse than the horizontal
	reel every child already knows from every case-opening in every game they
	play. The reel decelerates under a fixed pointer, which is the same
	promise a wheel makes and is legible at a glance.

	THE SERVER ALREADY DECIDED. This module is handed the winner and animates
	landing on it. Nothing in here picks anything: the reel is built so that
	the winning tile is under the pointer when the tween ends, and if the
	maths were wrong the result would be a visual bug rather than a wrong
	prize. A client that chose its own reward is a client that chose its own
	reward.

	THE PERCENTAGES ARE REAL, and printing them is the point rather than a
	flourish. The pool is only ever what the player does NOT own, so odds
	visibly improve as a set fills -- which is the honest version of what a
	crate pretends to do. Showing the number is what makes it honest instead
	of merely true.

	IT MUST STAY FREE. No Robux spin, no extra spins, no premium reel, no pass
	that re-rolls it. A free spin is fine for an under-13 audience; the moment
	real money can reach it, it is a paid random-chance item and the penalty
	lands on the whole experience rather than on this file.

	ICONS ARE INJECTED. Building a real preview needs PiggyModel, PigGear,
	Decor and RideModel plus the viewport helper, all of which live in
	ClientMain. Taking a callback keeps this module ignorant of every one of
	them, and keeps the icons the REAL items rather than a second set of
	pictures that would drift.

	ONE REEL SERVES THE EVENT DROP AND THE CHEST, and the four fields that
	make that possible are `title`, `subtitle`, `note` and `tier`.

	The two are genuinely different underneath -- an event drop rolls a flat
	pool of things you do not own, so every item is equally likely and
	duplicates are impossible, while a chest rolls a TIER first and can hand
	back something you already have. But everything on screen is the same
	object: a strip of real items decelerating under a fixed pointer. Writing
	a second one of those is exactly the near-identical copy this project
	keeps recording as the thing that drifts, and it would have drifted at the
	first tweak to the easing.

	So the CALLER owns the wording -- the same split `CosmeticsService.award`
	makes with its optional `why` -- and each field falls back to what the
	event drop already printed, so that caller is untouched. `note` is a beat
	only a chest needs: "you already had this, here is what it is worth".

	-------------------------------------------------------------------------
	THE DRAMA IS SCALED BY THE TIER, AND A COMMON DELIBERATELY GETS NONE.

	This was a cream card with a strip of cream tiles, a three-pixel line for
	a pointer, and one line of text at the end. Every number in it was right
	and it was the quietest moment in the game -- on the one screen whose
	entire job is to be worth opening a crate for.

	What it has now is a burst: rays, a bloom, a flash, coin confetti, a
	nameplate and a sting. All of it comes off `Config.RARITIES` through
	`DRAMA` below, so a legendary gets sixteen rays and twenty coins and a
	common gets neither -- and THAT IS THE FEATURE RATHER THAN A SAVING. A
	crate exists for rarity variance; if every open ends in the same
	fireworks then nothing in the set means anything, and the fourth open
	teaches a nine-year-old that the fireworks are wallpaper. The tier has to
	be READABLE FROM THE CELEBRATION, not just from a word.

	NOTHING HERE IS AN IMAGE ASSET. Rays, bloom, coins, snout and chevrons are
	all frames, gradients and corner radii, for the reason `Theme.gloss`
	exists: an upload is a third-party asset that can be moderated away, and
	this project builds the ground, the houses and the piggies in code
	precisely so that a fresh place plus this repo is the whole game.

	AND IT STAYS INSIDE THE FLASH CEILING. The accessibility rule this game
	holds itself to is three flashes a second, and `HouseFX` enforces it for
	the houses. There is exactly ONE flash in here -- a single sheet over the
	reel as it lands -- and everything else is continuous: the rays SPIN, the
	bloom fades in once, the pointer glow breathes at 1.4Hz and the card's
	own edge at 1.2Hz. A strobe would be the easy version of drama and it is
	not available.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Theme = require(ReplicatedStorage.Shared.Theme)
local Config = require(ReplicatedStorage.Shared.Config)
local SoundKit = require(ReplicatedStorage.Shared.SoundKit)

local SpinWheel = {}

local TILE_W, TILE_H = 132, 132
local GAP = 8
local STRIDE = TILE_W + GAP

local PAD = 22
local CARD_W = 604
-- THE WINDOW'S WIDTH IS A CONSTANT, AND IT USED TO BE READ OFF
-- `AbsoluteSize.X` ON THE FRAME THE WINDOW WAS BUILT.
--
-- WHICH WORKED, AND THIS IS RECORDED BECAUSE THE OPPOSITE WAS ASSUMED. The
-- landing offset is solved from half the window's width, and reading geometry
-- off a frame that has not been laid out is a real trap in this project -- the
-- shop's jump-to-section landed at the top of the wrong tab the first time a
-- tab was ever opened, for exactly that reason. So this looked like the same
-- bug and was written up as one.
--
-- Measured instead: a frame sized `UDim2.new(1, -40, 0, 140)` inside a
-- 604-wide parent reads `AbsoluteSize.X` of **564 on the frame it is
-- created**, and 564 a tick later. An offset-and-scale size against a parent
-- whose own size is already known resolves immediately; what the shop hit was
-- a descendant of a frame that was not VISIBLE yet, which is a different
-- state.
--
-- The constant stays, because a landing offset that cannot depend on layout
-- timing at all is worth more than the line it saves -- but it is a
-- ROBUSTNESS change and not a fix, and calling it a fix would have put a bug
-- in this file's history that never happened.
local WINDOW_W = CARD_W - PAD * 2
local WINDOW_H = TILE_H + 8

-- How many copies of the pool scroll past before it settles. Enough that the
-- reel is moving fast at the start and clearly slowing at the end; fewer and
-- it reads as a jump cut rather than a spin.
local LOOPS = 7
local SPIN_SECONDS = 4.0

-- WHAT EACH TIER'S CELEBRATION IS MADE OF.
--
-- `rays` and `coins` are counts, `flash` is how opaque the single sheet over
-- the reel goes, `pitch` plays the same sting higher for a better tier, and
-- `hold` is how long the reveal stays up before closing itself.
--
-- COMMON GETS NO RAYS AND NO COINS ON PURPOSE. See the header: the variance
-- IS the mechanic, so the bottom of the ladder has to be visibly quieter than
-- the top or the top stops meaning anything. It still gets the flash, the
-- nameplate and the sting, so it never reads as a failed open -- which is the
-- line this project draws everywhere else too: a duplicate is never a dead
-- outcome, and neither is a common.
local DRAMA: { [string]: { rays: number, coins: number, flash: number, pitch: number, hold: number } } = {
	common    = { rays = 0,  coins = 0,  flash = 0.10, pitch = 0.94, hold = 1.9 },
	rare      = { rays = 8,  coins = 6,  flash = 0.20, pitch = 1.06, hold = 2.4 },
	epic      = { rays = 12, coins = 12, flash = 0.28, pitch = 1.16, hold = 2.8 },
	legendary = { rays = 16, coins = 20, flash = 0.36, pitch = 1.30, hold = 3.4 },
}
-- AN EVENT DROP CARRIES NO TIER, AND IT IS NOT A COMMON.
--
-- A set item is earned by turning up to an event and is the rarest thing in
-- the game by construction -- `SetService` sends a flat pool with no tier in
-- it, because there is no tier to send. Defaulting to `common` would give the
-- one drop that cannot be bought the quietest celebration in the file, so it
-- takes the epic treatment instead. Named rather than inferred, so the next
-- caller that sends no tier gets a deliberate answer.
local NO_TIER_DRAMA = "epic"

local RAY_LEN = 640
local RAY_W = 26

local function tierColour(tier: string?): Color3?
	local r = if tier then Config.RARITIES[tier] else nil
	return if r then r.colour else nil
end

local function label(parent: Instance, text: string, size: UDim2, pos: UDim2,
	font: Enum.Font, textSize: number, colour: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.Font = font
	l.TextSize = textSize
	l.TextColor3 = colour
	l.Text = text
	l.Parent = parent
	return l
end

-- `payload` is the EventDrop or ChestResult table. `iconFor(kind, key, holder)`
-- is optional and fills a frame with a preview of that item.
function SpinWheel.play(gui: ScreenGui, payload: any, iconFor: ((string, string, Frame) -> ())?)
	local pool = payload.pool or {}
	if #pool == 0 then
		return
	end

	local wonEntry = payload.won or pool[1]
	-- The tier drives every part of the celebration, so it is resolved once
	-- and from the winner's own entry where the caller did not say -- a chest
	-- sends it, an event drop has none, and the pool entries carry it.
	local tier: string? = payload.tier or wonEntry.tier
	local tone = tierColour(tier) or payload.tone or Theme.GOOD
	local drama = DRAMA[tier or ""] or DRAMA[NO_TIER_DRAMA]
	local pct = math.floor((payload.odds or (1 / #pool)) * 100 + 0.5)

	local hasNote = type(payload.note) == "string" and payload.note ~= ""
	local cardH = if hasNote then 356 else 332

	local shade = Instance.new("Frame")
	shade.Name = "DropWheel"
	shade.Size = UDim2.new(1, 0, 1, 0)
	shade.BackgroundColor3 = Theme.INK
	shade.BackgroundTransparency = 1
	shade.BorderSizePixel = 0
	shade.ZIndex = 60
	shade.Parent = gui
	TweenService:Create(shade, TweenInfo.new(0.35), { BackgroundTransparency = 0.3 }):Play()

	-- ---- the burst, behind the card -------------------------------------
	--
	-- SIBLINGS OF THE CARD AT A LOWER ZINDEX, NEVER CHILDREN OF IT. This HUD
	-- runs `ZIndexBehavior.Sibling`, where a CHILD ALWAYS DRAWS ABOVE ITS
	-- PARENT whatever its ZIndex -- the trap the rebirth button's halo had to
	-- be moved out of its own button to solve. Parented to the card these
	-- would wash over the reel and the nameplate instead of standing behind
	-- them. They are also outside the card's bounds by design, which is what
	-- makes a burst read as a burst.
	local bloom = Instance.new("Frame")
	bloom.Name = "Bloom"
	bloom.Size = UDim2.fromOffset(560, 560)
	bloom.Position = UDim2.fromScale(0.5, 0.5)
	bloom.AnchorPoint = Vector2.new(0.5, 0.5)
	bloom.BackgroundColor3 = tone
	bloom.BackgroundTransparency = 1
	bloom.BorderSizePixel = 0
	bloom.ZIndex = 60
	bloom.Parent = shade
	Theme.corner(bloom, 280)

	local rays = Instance.new("Frame")
	rays.Name = "Rays"
	rays.Size = UDim2.fromOffset(RAY_LEN * 2, RAY_LEN * 2)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.BackgroundTransparency = 1
	rays.ZIndex = 60
	rays.Parent = shade

	-- EACH BAR IS A PAIR OF OPPOSITE RAYS, AND IT HAS TO BE, BECAUSE
	-- `GuiObject.Rotation` TURNS A FRAME ABOUT ITS OWN CENTRE AND NOT ABOUT
	-- ITS ANCHORPOINT.
	--
	-- The first build was one-sided rays: each anchored at its BOTTOM centre,
	-- placed on the container's centre, extending upward, and turned to its
	-- own angle -- which reads as obviously correct and is wrong. Rotation
	-- ignores the anchor, so every ray pivoted about its own waist instead,
	-- 320 studs up the frame, and all twelve of them swept about a point HALF
	-- A RAY LENGTH ABOVE THE CARD. The burst hung in the sky over the panel.
	--
	-- IT MEASURED PERFECTLY WHILE LOOKING WRONG, which is why this is written
	-- down. The container, the bloom and the card all reported the same
	-- centre to the pixel -- (700, 338) on all three -- because the CONTAINER
	-- was right and the children inside it were not. What settled it was
	-- putting a bright marker on the container's centre and photographing it
	-- next to the rays: the marker sat in the reel window and the rays
	-- converged three hundred pixels above it. Same lesson as the fence
	-- border clamped against the wrong tier -- every probe agreed with itself
	-- and only a picture disagreed.
	--
	-- A bar centred on the middle cannot have the problem: its own centre IS
	-- the burst centre, so rotating about the centre is rotating about the
	-- right point. It also costs half the instances for the same number of
	-- visible rays -- one bar is two rays -- so `drama.rays` still means what
	-- it says and the loop runs half as many times.
	local rayList: { Frame } = {}
	local bars = math.floor(drama.rays / 2)
	for i = 1, bars do
		local ray = Instance.new("Frame")
		ray.Name = "Ray" .. i
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.fromOffset(RAY_W, RAY_LEN * 2)
		-- 180 degrees rather than 360: a bar already points both ways, so
		-- spreading them over a full turn would build every ray twice and
		-- leave half the wheel empty.
		ray.Rotation = (i - 1) * (180 / bars)
		ray.BackgroundColor3 = tone
		ray.BackgroundTransparency = 1
		ray.BorderSizePixel = 0
		ray.ZIndex = 60
		ray.Parent = rays
		-- Brightest at the middle and gone at both tips, which is what a
		-- starburst is. A UIGradient's transparency MULTIPLIES the frame's
		-- own, so the fade-in below stays one tween per bar rather than a
		-- rewritten NumberSequence every frame.
		local grad = Instance.new("UIGradient")
		grad.Rotation = 90
		grad.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.32, 0.72),
			NumberSequenceKeypoint.new(0.5, 0.1),
			NumberSequenceKeypoint.new(0.68, 0.72),
			NumberSequenceKeypoint.new(1, 1),
		})
		grad.Parent = ray
		table.insert(rayList, ray)
	end

	-- ---- the card --------------------------------------------------------
	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(CARD_W, cardH)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.BackgroundColor3 = Theme.SAND
	card.BorderSizePixel = 0
	card.ZIndex = 61
	card.Parent = shade
	Theme.corner(card, 18)
	-- `shade` RATHER THAN `gloss`, AND SHALLOW, BECAUSE THE GLOSS COST THE
	-- TWO SECONDARY LABELS THEIR CONTRAST.
	--
	-- A UIGradient MULTIPLIES the fill -- `Theme.shade`'s own header says so
	-- -- so `gloss(SAND, SAND_DEEP)` over a SAND card is not a ramp from SAND
	-- to SAND_DEEP, it is SAND*SAND down to SAND_DEEP*SAND, and both ends are
	-- darker than the colours named. Measured on the live reveal, that took
	-- the odds line to 4.41 and the note to 3.55 against a body floor of 4.5
	-- -- neither of which was true of the flat SAND card this replaced.
	--
	-- A neutral multiply at 0.94 leaves the TOP of the card at exactly SAND
	-- and darkens the bottom by six per cent, which still reads as a moulded
	-- surface and costs the labels almost nothing. This is the entry in
	-- `Theme` about which of the two to reach for, arriving as a bill.
	Theme.shade(card, 0.94)

	-- THE TIER COLOUR DOES NOT APPEAR UNTIL THE REEL HAS LANDED, AND THIS IS
	-- THE HALF THAT MATTERS MOST IN THE FILE.
	--
	-- The server sends the tier with the payload, so every tier-coloured thing
	-- here COULD be painted the moment the reveal opens -- and the version
	-- this replaces did exactly that, with the pointer, the title and the
	-- card's edge all in the winning colour from the first frame. That reads
	-- as decoration and is actually a SPOILER: a player who has seen four
	-- opens knows that a gold edge means a legendary before the strip has
	-- moved, and from then on the spin is a formality they sit through.
	--
	-- So the edge, the pointer, its glow and the chevrons all start NEUTRAL --
	-- `Theme.INK`, which is the edge every other card in this game wears --
	-- and take the tier's colour in `finish`. What is tier-coloured from the
	-- start is each TILE, which is honest: a tile's colour is a fact about
	-- that item's own rarity and says nothing about which one the pointer will
	-- stop on.
	local stroke = Theme.outline(card, 3, Theme.INK)

	-- IT ARRIVES RATHER THAN APPEARING. A modal that is simply there on one
	-- frame has no moment in it, and this is the one screen in the game a
	-- player opened a crate to see. Back easing overshoots by 4% and settles,
	-- which is the difference between a card appearing and a card landing.
	local pop = Instance.new("UIScale")
	pop.Scale = 0.82
	pop.Parent = card
	TweenService:Create(pop, TweenInfo.new(0.34, Enum.EasingStyle.Back,
		Enum.EasingDirection.Out), { Scale = 1 }):Play()

	-- THE HEADER IS PINK AND THE PRIZE IS THE TIER, which is this game's own
	-- colour rule doing the work: pink means the pig and gold means money, so
	-- pink says whose crate this is and the tier colour is left free to say
	-- what came out of it. An inset plate rather than a full-width band,
	-- because a `UICorner` rounds all four corners and a square-bottomed band
	-- on a rounded card needs a second frame to hide the join.
	local head = Instance.new("Frame")
	head.Name = "Head"
	head.Size = UDim2.new(1, -PAD * 2, 0, 44)
	head.Position = UDim2.fromOffset(PAD, 14)
	-- DEEPER THAN `PIG_DEEP` AND SHADED RATHER THAN GLOSSED, BOTH FOR THE
	-- SAME REASON: the title is PAPER type and it has to be readable on every
	-- pixel of what is behind it.
	--
	-- `Theme.gloss` runs a gradient FROM the colour it is given, so a gloss
	-- from `PIG` put light pink at the top of the band -- measured, PAPER on
	-- PIG is 1.76:1 and PAPER on the band's own mid-point is 2.70:1, against
	-- a floor of 3.0 for large type. `Theme.shade` only ever MULTIPLIES, so
	-- it can only darken downward from the fill, which is the right direction
	-- for light type; and the fill itself goes a fifth of the way to ink,
	-- which takes the top of the band -- the worst pixel -- to 5.5:1.
	--
	-- This is the note in `Theme` about `gloss` against `shade` arriving on a
	-- new surface, pointed the other way: that one is about DARK type on a
	-- saturated fill, and the rule underneath is the same either way -- a
	-- gradient that moves toward the text colour is a gradient that eats the
	-- contrast somewhere along it.
	head.BackgroundColor3 = Theme.PIG_DEEP:Lerp(Theme.INK, 0.18)
	head.BorderSizePixel = 0
	head.ZIndex = 62
	head.Parent = card
	Theme.corner(head, 12)
	Theme.shade(head, 0.84)

	-- The snout is DRAWN, for the reason the coin badge is: an emoji renders
	-- from the colour font, ignores `TextColor3`, and is a smudge at this
	-- size. It is also the cheapest possible way to say "piggy bank" on a
	-- screen that is otherwise about rarity colours.
	local snout = Theme.snout(head, 30, "Snout")
	snout.Position = UDim2.new(0, 12, 0.5, 0)
	snout.AnchorPoint = Vector2.new(0, 0.5)
	snout.ZIndex = 63

	local title = label(head,
		payload.title or ("%s DROP"):format(string.upper(payload.setName or "SET")),
		UDim2.new(1, -60, 1, 0), UDim2.fromOffset(52, 0),
		Theme.FONT, 24, Theme.PAPER)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = 63

	-- The odds, stated plainly. This is the sentence that makes the reel
	-- honest, so it is on screen before the spin rather than after it.
	--
	-- The event drop's own line is the fallback rather than the only option,
	-- because it is only TRUE of an event drop: a flat pool of unowned things
	-- really is "N items left, X% each", and a chest's tiered odds are not
	-- that shape at all. A caller printing the wrong sentence honestly would
	-- be worse than printing none.
	-- `Theme.readable` AGAINST THE DARKEST PIXEL IT CAN SIT ON, which is the
	-- bottom of the card's own shading rather than the SAND at the top. That
	-- is the instrument this project already has for exactly this -- a tone
	-- darkened until it clears 4.5 against a named ground -- and naming the
	-- WORST ground rather than the nominal one is what stops a label that
	-- passes at the top of a gradient failing halfway down it.
	local quiet = Theme.readable(Theme.MUTED, Theme.SAND_DEEP)
	local odds = label(card, payload.subtitle
			or ("%d items left %s %d%% each"):format(#pool, utf8.char(0x00B7), pct),
		UDim2.new(1, -PAD * 2, 0, 16), UDim2.fromOffset(PAD, 62),
		Enum.Font.Gotham, 13, quiet)
	odds.ZIndex = 62

	-- ---- the reel window -------------------------------------------------
	local window = Instance.new("Frame")
	window.Name = "Window"
	window.Size = UDim2.fromOffset(WINDOW_W, WINDOW_H)
	window.Position = UDim2.fromOffset(PAD, 84)
	window.BackgroundColor3 = Theme.SLAB_DEEP
	window.BorderSizePixel = 0
	window.ClipsDescendants = true
	window.ZIndex = 62
	window.Parent = card
	Theme.corner(window, 12)

	local strip = Instance.new("Frame")
	strip.Name = "Strip"
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.new(0, 20000, 1, 0)
	strip.Position = UDim2.fromOffset(0, 0)
	strip.ZIndex = 62
	strip.Parent = window

	-- Build the reel: LOOPS copies of the pool, then the winner placed once
	-- more at the end. Landing is therefore a fixed offset rather than a
	-- search, and the tile under the pointer is the server's answer by
	-- construction rather than by coincidence.
	local function addTile(entry: any, index: number): Frame
		local hue = tierColour(entry.tier) or tone

		local t = Instance.new("Frame")
		t.Name = "Tile"
		t.Size = UDim2.fromOffset(TILE_W, TILE_H)
		-- CENTRED ON ITS OWN ANCHOR, so the winner's pop grows out of the
		-- middle of the tile instead of down and to the right of it. A
		-- `UIScale` scales about its object's AnchorPoint, and at the default
		-- (0, 0) a 12% pop on a 132-pixel tile walks it sixteen pixels off the
		-- pointer at the exact moment the pointer is what everybody is looking
		-- at. Every tile takes the same anchor rather than only the winner:
		-- the tile under the pointer has to be the same shape as the ones
		-- beside it, which is the rule that put the winner through `addTile`
		-- in the first place.
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = UDim2.fromOffset(index * STRIDE + 4 + TILE_W / 2, 4 + TILE_H / 2)
		-- EVERY TILE WEARS ITS OWN TIER, WHICH IS INFORMATION RATHER THAN
		-- PAINT. Twenty cream squares tell a player nothing while they scroll
		-- past; a river of colour with a gold one in it is the whole reason to
		-- watch the reel at all -- you can SEE the legendary go by. An event
		-- drop's pool carries no tier, so those all take the set's own tone
		-- and the strip still reads as one family.
		t.BackgroundColor3 = hue:Lerp(Theme.PAPER, 0.78)
		t.BorderSizePixel = 0
		t.ZIndex = 62
		t.Parent = strip
		Theme.corner(t, 10)
		local edge = Theme.outline(t, Theme.OUTLINE_THIN, hue)
		edge.Transparency = 0.25

		local holder = Instance.new("Frame")
		holder.Name = "Icon"
		holder.Size = UDim2.new(1, -10, 1, -34)
		holder.Position = UDim2.fromOffset(5, 5)
		holder.BackgroundTransparency = 1
		holder.ZIndex = 63
		holder.Parent = t
		if iconFor then
			iconFor(entry.kind, entry.key, holder)
		end

		local name = label(t, entry.name or entry.key, UDim2.new(1, -8, 0, 26),
			UDim2.new(0, 4, 1, -28), Theme.FONT_BODY, 12, Theme.INK)
		name.TextScaled = true
		name.ZIndex = 63
		return t
	end

	local index = 0
	for _ = 1, LOOPS do
		for _, entry in ipairs(pool) do
			addTile(entry, index)
			index += 1
		end
	end
	local winIndex = index
	local winTile = addTile(wonEntry, winIndex)
	-- A few more after it, so the reel does not visibly run out of track.
	for i = 1, #pool do
		addTile(pool[((i - 1) % #pool) + 1], winIndex + i)
	end

	-- THE EDGES GO DARK, WHICH IS WHAT MAKES TILES ARRIVE RATHER THAN SLIDE.
	-- One frame with a gradient that is opaque at both ends and clear in the
	-- middle, so the strip emerges out of shadow into the light under the
	-- pointer and falls back into it. Cheaper than any other way of saying
	-- "the thing in the middle is the one that matters".
	local vignette = Instance.new("Frame")
	vignette.Name = "Vignette"
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundColor3 = Theme.SLAB_DEEP
	vignette.BorderSizePixel = 0
	vignette.ZIndex = 63
	vignette.Parent = window
	local vg = Instance.new("UIGradient")
	vg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.3, 1),
		NumberSequenceKeypoint.new(0.7, 1),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	vg.Parent = vignette

	-- THE SMEAR IS A FUNCTION OF THE REEL'S OWN SPEED, not of a clock.
	--
	-- A pale sheet over the window whose opacity tracks how fast the strip is
	-- actually moving, so it reads as motion blur and clears itself as the
	-- reel slows -- with nothing to keep in step. That is the officer's
	-- stride rule on a new object: an animation cannot desync from the thing
	-- it depicts when it IS the thing it depicts, and a timed fade would drift
	-- the first time anybody retuned the easing.
	local smear = Instance.new("Frame")
	smear.Name = "Smear"
	smear.Size = UDim2.fromScale(1, 1)
	smear.BackgroundColor3 = Theme.PAPER
	smear.BackgroundTransparency = 1
	smear.BorderSizePixel = 0
	smear.ZIndex = 64
	smear.Parent = window

	-- ---- the pointer -----------------------------------------------------
	--
	-- A three-pixel line was doing this job. It is a marker now: a glow, a
	-- bright blade and a chevron top and bottom, so the thing the whole
	-- animation is aimed at is the loudest object in the window.
	local glow = Instance.new("Frame")
	glow.Name = "PointerGlow"
	glow.Size = UDim2.new(0, 40, 1, 0)
	glow.Position = UDim2.new(0.5, -20, 0, 0)
	glow.BackgroundColor3 = Theme.MUTED_LIGHT
	glow.BackgroundTransparency = 0.72
	glow.BorderSizePixel = 0
	glow.ZIndex = 65
	glow.Parent = window

	local blade = Instance.new("Frame")
	blade.Name = "Pointer"
	blade.Size = UDim2.new(0, 4, 1, 0)
	blade.Position = UDim2.new(0.5, -2, 0, 0)
	blade.BackgroundColor3 = Theme.PAPER
	blade.BorderSizePixel = 0
	blade.ZIndex = 66
	blade.Parent = window

	local chevrons: { Frame } = {}
	for _, at in ipairs({ 0, 1 }) do
		local chev = Instance.new("Frame")
		chev.Name = "Chevron"
		chev.Size = UDim2.fromOffset(14, 14)
		chev.Position = UDim2.new(0.5, 0, at, 0)
		chev.AnchorPoint = Vector2.new(0.5, at)
		chev.Rotation = 45
		chev.BackgroundColor3 = Theme.PAPER_DEEP
		chev.BorderSizePixel = 0
		chev.ZIndex = 66
		chev.Parent = window
		Theme.corner(chev, 3)
		table.insert(chevrons, chev)
	end

	-- ---- the prize block -------------------------------------------------
	--
	-- BOTTOM ANCHORED, so the one layout serves both the chest (which has a
	-- note under the prize) and the event drop (which does not) without a
	-- second set of offsets to keep in step.
	local tierChip: TextLabel? = nil
	local chipRing: UIStroke? = nil
	if tier then
		local r = Config.RARITIES[tier]
		local chip = label(card, string.upper(r and r.label or tier),
			UDim2.fromOffset(150, 24),
			UDim2.new(0.5, -75, 1, if hasNote then -126 else -102),
			Theme.FONT, 15, tone)
		Theme.chip(chip, 24, tone)
		-- `Theme.chip` grounds on `SLAB` and this needs `SLAB_DEEP`, for a
		-- reason worth the line: the chip prints a RARITY COLOUR at body size,
		-- and rare is the darkest of the four -- measured, that blue on SLAB
		-- is 4.20 against a floor of 4.5, so the one tier a player sees most
		-- often after common would have been the one that failed. On
		-- `SLAB_DEEP` it is 5.6, and it also matches the nameplate directly
		-- below, so the tier and the prize read as one object rather than as
		-- two dark pills of slightly different darkness.
		chip.BackgroundColor3 = Theme.SLAB_DEEP
		chip.ZIndex = 62
		chip.TextTransparency = 1
		chip.BackgroundTransparency = 1
		-- AND ITS OUTLINE TOO, WHICH IS THE LAST PLACE THE TIER LEAKED.
		--
		-- `Theme.chip` rings a pill in the tone it is given, and with the text
		-- and the fill both transparent that ring was the only part of the
		-- chip still drawing -- so mid-spin the card carried an empty pale
		-- purple pill where the word EPIC was going to go. Caught in a
		-- photograph after the same fault had already been fixed on the edge,
		-- the pointer and the chevrons: a probe reading text and background
		-- transparency finds a chip that is properly hidden, because a stroke
		-- is neither.
		local ring = chip:FindFirstChildOfClass("UIStroke")
		if ring then
			ring.Transparency = 1
			chipRing = ring
		end
		tierChip = chip
	end

	-- THE NAMEPLATE IS DARK AND THE NAME IS THE TIER'S OWN COLOUR, which is
	-- the only arrangement that works. A rarity colour is a bright saturated
	-- hue and this card is cream: gold on paper measures 1.42:1, which is a
	-- label you can see is there and cannot read. `Theme.readable` would fix
	-- that by darkening the gold until it is brown, and the whole point of a
	-- legendary is that it is GOLD. So the plate goes dark instead and the
	-- colour is kept intact on top of it.
	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.Size = UDim2.new(1, -PAD * 2, 0, 54)
	-- Centre-anchored for the same reason the tiles are: the pop below is a
	-- `UIScale`, which scales about the AnchorPoint, and a plate growing out
	-- of its own top-left corner reads as a panel sliding rather than as a
	-- prize landing.
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.new(0.5, 0, 1, if hasNote then -71 else -47)
	plate.BackgroundColor3 = Theme.SLAB_DEEP
	-- ON SCREEN FROM THE START, READING "OPENING", AND THAT IS A LAYOUT FIX AS
	-- WELL AS A BEAT.
	--
	-- Hidden until the landing, the bottom third of the card was 120 pixels of
	-- empty cream for the whole four-second spin -- which is most of the time
	-- anybody spends looking at this. A plate that is already there and says
	-- what is happening fills it, and it gives the reveal something to CHANGE
	-- rather than something to reveal from nothing: the same plate, the same
	-- pop, and the word swaps for the prize.
	plate.BackgroundTransparency = 0.25
	plate.BorderSizePixel = 0
	plate.ZIndex = 62
	plate.Parent = card
	Theme.corner(plate, 12)

	local prize = label(plate, "OPENING" .. utf8.char(0x2026),
		UDim2.fromScale(1, 1), UDim2.fromScale(0, 0),
		Theme.FONT, 28, Theme.MUTED_LIGHT)
	prize.ZIndex = 63

	-- Starts near its full size rather than at 0.7, because it is already
	-- visible: what lands is a 10% punch on something the player has been
	-- looking at, which reads harder than a panel growing out of nothing.
	local prizePop = Instance.new("UIScale")
	prizePop.Parent = plate

	-- A DUPLICATE IS NEVER A DEAD OUTCOME, and this line is where a chest
	-- says so. It appears with the prize rather than before it: what it has
	-- to report is a fact about the item that just landed, and printing it
	-- while the reel is still moving would be telling the player the answer
	-- before the spin has given it to them.
	local note: TextLabel? = nil
	if hasNote then
		local n = label(card, payload.note, UDim2.new(1, -PAD * 2, 0, 20),
			UDim2.new(0, PAD, 1, -34), Theme.FONT_BODY, 14, quiet)
		n.ZIndex = 62
		n.TextTransparency = 1
		note = n
	end

	-- ---- the spin --------------------------------------------------------
	--
	-- Land so the winning tile's CENTRE sits under the pointer. Derived from
	-- `WINDOW_W` rather than measured -- see the note on that constant.
	local target = -(winIndex * STRIDE + 4 + TILE_W / 2) + WINDOW_W / 2
	local distance = math.abs(target - strip.Position.X.Offset)
	local tween = TweenService:Create(strip,
		TweenInfo.new(SPIN_SECONDS, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(target, 0) })
	tween:Play()

	-- THE REEL TICKS PER TILE, AND THE TWEEN'S OWN EASING IS WHAT MAKES IT
	-- SATISFYING. Quint-out means the strip covers most of its distance
	-- early, so counting whole STRIDEs past the pointer produces a rattle
	-- that slows to single clicks as it lands -- the ratchet a physical reel
	-- makes, for free, because it is a function of the movement rather than
	-- a rhythm anybody typed.
	--
	-- COUNTED FROM POSITION RATHER THAN CLOCKED. A timer would drift out of
	-- step with the tween the moment either was retuned, which is the failure
	-- the officer's stride already avoids by being a function of distance
	-- travelled.
	--
	-- The same loop drives the smear, the pointer's breath and the card's
	-- edge, because all four are functions of where the strip is or of the
	-- wall clock and one connection is cheaper than four.
	--
	-- DECLARED HERE AND WRITTEN IN `finish` BELOW, because the loop READS it
	-- and a local declared after its reader is a nil global to that reader --
	-- the forward-reference trap this project has now recorded eleven times,
	-- and the one that is silent in Luau until the line actually runs.
	local landed = false
	do
		-- Peak speed for a quint-out is 5 * distance / duration, at t=0. The
		-- smear saturates at half of that so it is fully on for the opening
		-- rattle rather than only in the first few frames -- derived, so a
		-- pool of six and a pool of forty both read the same.
		local smearFull = math.max(5 * distance / SPIN_SECONDS * 0.5, 1)
		local lastX = strip.Position.X.Offset
		local lastTile: number? = nil
		local born = os.clock()
		local ticker: RBXScriptConnection? = nil
		ticker = RunService.Heartbeat:Connect(function(dt)
			-- The strip dies with the card when the reveal closes, and a
			-- Heartbeat left running against a destroyed instance is the leak
			-- this check exists to stop.
			if not strip.Parent then
				if ticker then
					ticker:Disconnect()
					ticker = nil
				end
				return
			end

			local x = strip.Position.X.Offset
			local speed = math.abs(x - lastX) / math.max(dt, 1 / 240)
			lastX = x
			smear.BackgroundTransparency = 1 - math.clamp(speed / smearFull, 0, 1) * 0.22

			-- 1.4Hz on the pointer and 1.2Hz on the edge, both continuous
			-- rather than flashing, and both well inside the three-a-second
			-- ceiling this game holds itself to.
			local t = os.clock() - born
			-- Held off once the landing has repainted the glow, or this would
			-- fight the tween that gives it the tier's colour.
			if not landed then
				glow.BackgroundTransparency = 0.72 - 0.16 * (0.5 + 0.5 * math.sin(t * 8.8))
			end
			stroke.Thickness = 3 + 1.2 * (0.5 + 0.5 * math.sin(t * 7.5))

			local tile = math.floor(-x / STRIDE)
			if tile ~= lastTile then
				-- The FIRST sample is skipped rather than clicked: the strip
				-- starts wherever it starts, and a tick for arriving where it
				-- already was is a click for nothing having moved.
				if lastTile ~= nil then
					SoundKit.ui(Config.SOUNDS.CLICK,
						{ name = "ReelTick", volume = 0.16, pitch = 1.35 })
				end
				lastTile = tile
			end
		end)
		tween.Completed:Once(function()
			if ticker then
				ticker:Disconnect()
				ticker = nil
			end
			smear.BackgroundTransparency = 1
			stroke.Thickness = 3
		end)
	end

	-- ---- the landing -----------------------------------------------------
	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		-- Stops the breath loop above fighting the tween that gives the glow
		-- its tier colour.
		landed = true

		-- THE ONE FLASH IN THE FILE. A single sheet over the reel, fading out
		-- rather than blinking, which is what keeps this inside the
		-- three-flashes-a-second rule with nothing to count.
		local flash = Instance.new("Frame")
		flash.Name = "Flash"
		flash.Size = UDim2.fromScale(1, 1)
		flash.BackgroundColor3 = Theme.PAPER
		flash.BackgroundTransparency = drama.flash
		flash.BorderSizePixel = 0
		flash.ZIndex = 67
		flash.Parent = window
		TweenService:Create(flash, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()

		-- The winner: brighter ground, a full-weight edge in its tier, and a
		-- pop. Lerped only half way to paper so the tier colour is unmistakable
		-- while the name printed on it stays ink-readable.
		winTile.BackgroundColor3 = tone:Lerp(Theme.PAPER, 0.5)
		local winEdge = Theme.outline(winTile, 4, tone)
		winEdge.Transparency = 0
		local tilePop = Instance.new("UIScale")
		tilePop.Parent = winTile
		TweenService:Create(tilePop, TweenInfo.new(0.18, Enum.EasingStyle.Back,
			Enum.EasingDirection.Out), { Scale = 1.12 }):Play()
		task.delay(0.2, function()
			if tilePop.Parent then
				TweenService:Create(tilePop, TweenInfo.new(0.22), { Scale = 1 }):Play()
			end
		end)

		-- The burst. The rays fade in and turn; the bloom is a soft ground
		-- under them. Both are no-ops at `rays = 0`, which is what a common
		-- gets.
		if drama.rays > 0 then
			TweenService:Create(bloom, TweenInfo.new(0.5), { BackgroundTransparency = 0.82 }):Play()
			for _, ray in ipairs(rayList) do
				TweenService:Create(ray, TweenInfo.new(0.4), { BackgroundTransparency = 0 }):Play()
			end
			-- Slow and continuous. A fast spin reads as a hazard stripe and a
			-- stepped one reads as a strobe; this is about a fifth of a turn
			-- a second, which the eye follows.
			TweenService:Create(rays, TweenInfo.new(drama.hold + 1.2,
				Enum.EasingStyle.Linear), { Rotation = 70 }):Play()
		end

		-- THE COLOUR ARRIVES HERE, which is the whole point of it having been
		-- withheld. Everything neutral becomes the tier at once -- the card's
		-- edge, the pointer, its glow, both chevrons -- so the moment the reel
		-- stops the entire panel changes colour to tell the player what they
		-- got. That is one event rather than four, because they all take the
		-- same tween length.
		TweenService:Create(stroke, TweenInfo.new(0.3), { Color = tone }):Play()
		TweenService:Create(glow, TweenInfo.new(0.3),
			{ BackgroundColor3 = tone, BackgroundTransparency = 0.5 }):Play()
		for _, chev in ipairs(chevrons) do
			TweenService:Create(chev, TweenInfo.new(0.3), { BackgroundColor3 = tone }):Play()
		end

		-- The nameplate and the tier, together, because they are one sentence.
		TweenService:Create(plate, TweenInfo.new(0.25), { BackgroundTransparency = 0.05 }):Play()
		prize.Text = ("%s!"):format(wonEntry.name or wonEntry.key)
		prize.TextColor3 = tone
		-- A punch rather than a grow: out to 1.1 and back, on a plate that was
		-- already on screen.
		TweenService:Create(prizePop, TweenInfo.new(0.16, Enum.EasingStyle.Back,
			Enum.EasingDirection.Out), { Scale = 1.1 }):Play()
		task.delay(0.18, function()
			if prizePop.Parent then
				TweenService:Create(prizePop, TweenInfo.new(0.22), { Scale = 1 }):Play()
			end
		end)
		if tierChip then
			local chip = tierChip :: TextLabel
			TweenService:Create(chip, TweenInfo.new(0.3),
				{ TextTransparency = 0, BackgroundTransparency = 0 }):Play()
		end
		if chipRing then
			TweenService:Create(chipRing :: UIStroke, TweenInfo.new(0.3),
				{ Transparency = 0 }):Play()
		end
		if note then
			TweenService:Create(note, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
		end

		-- COIN CONFETTI, WHICH IS THE PIGGY-THEMED HALF OF THE BURST.
		--
		-- `Theme.coin` is the same drawn gold disc the balance badge wears, so
		-- what comes out of a crate in this game is money-shaped rather than
		-- generic sparkle. They fly from the nameplate and fall, and they
		-- SHRINK rather than fade: transparency does not inherit in Roblox UI,
		-- so fading one would mean tweening each of its three parts, and a
		-- coin tumbling away to nothing reads the same for a third of the
		-- work.
		for i = 1, drama.coins do
			local size = math.random(14, 24)
			local coin = Theme.coin(shade, size, "Confetti")
			coin.Position = UDim2.new(0.5, math.random(-120, 120), 0.5, 90)
			coin.AnchorPoint = Vector2.new(0.5, 0.5)
			coin.ZIndex = 66
			coin.Rotation = math.random(0, 359)
			local outX = math.random(-330, 330)
			local upY = -math.random(90, 250)
			-- Out and up, then down past the bottom: two tweens, because one
			-- cannot arc.
			TweenService:Create(coin, TweenInfo.new(0.42, Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, outX, 0.5, 90 + upY),
				Rotation = coin.Rotation + math.random(-220, 220),
			}):Play()
			task.delay(0.42, function()
				if not coin.Parent then
					return
				end
				TweenService:Create(coin, TweenInfo.new(0.75, Enum.EasingStyle.Quad,
					Enum.EasingDirection.In), {
					Position = UDim2.new(0.5, outX * 1.25, 0.5, 420),
					Size = UDim2.fromOffset(0, 0),
					Rotation = coin.Rotation + 200,
				}):Play()
			end)
			task.delay(1.3, function()
				if coin.Parent then
					coin:Destroy()
				end
			end)
			-- One chime for the handful rather than one per coin, which would
			-- be twenty overlapping copies of the same sound.
			if i == 1 then
				SoundKit.ui(Config.SOUNDS.COIN_DROP,
					{ name = "CrateCoins", volume = 0.3, pitch = 1.15 })
			end
		end

		-- The sting, pitched by tier. `MILESTONE` is the celebration chime the
		-- pig already uses at a fill milestone, which is the right register --
		-- and it is an id already shipped rather than a new asset to source,
		-- since the Creator Store's free stings are overwhelmingly ripped from
		-- games and a strike would moderate this one away mid-season.
		SoundKit.ui(Config.SOUNDS.MILESTONE,
			{ name = "CrateWin", volume = 0.36, pitch = drama.pitch })
	end

	tween.Completed:Connect(finish)

	-- Dismissable, and it closes itself. A modal a child has to find a button
	-- on is a modal that sits over the game while a raid is still ending.
	local closing = false
	local function close()
		if closing then
			return
		end
		closing = true
		finish()
		TweenService:Create(shade, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(card, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(pop, TweenInfo.new(0.3), { Scale = 0.9 }):Play()
		task.delay(0.32, function()
			shade:Destroy()
		end)
	end

	task.delay(SPIN_SECONDS + drama.hold, close)

	-- Any input after the reel has landed skips the wait, the same courtesy
	-- the arrest scene gives somebody who has seen it forty times.
	local conn: RBXScriptConnection
	conn = UserInputService.InputBegan:Connect(function(_, processed)
		if not processed and done then
			conn:Disconnect()
			close()
		end
	end)
	task.delay(SPIN_SECONDS + drama.hold + 0.6, function()
		if conn.Connected then
			conn:Disconnect()
		end
	end)
end

return SpinWheel
