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
local ShopStyle = require(ReplicatedStorage.Shared.ShopStyle)
local SkinCards = require(ReplicatedStorage.Shared.ShopSkinCards)
local FlyToBag = require(ReplicatedStorage.Shared.FlyToBag)

local TILE_W, TILE_H = 132, 132
local GAP = 8
local STRIDE = TILE_W + GAP

local PAD = 22
local CARD_W = 604
-- THE WINDOW'S WIDTH IS A CONSTANT rather than read off `AbsoluteSize`, so the
-- landing offset cannot depend on layout timing at all.
local WINDOW_W = CARD_W - PAD * 2
local WINDOW_H = TILE_H + 8

-- ---- the spin ------------------------------------------------------------
--
-- THE PLAYER SPINS IT, AND MAY HOLD FOR MORE. The reel opens at
-- rest with a SPIN button; a tap spins it, and the longer it is held (up to `HOLD_MAX`)
-- the faster the reel runs out of the gate and the longer it takes to coast
-- to a stop. Letting go -- or reaching the cap -- starts the coast.
--
-- NONE OF THAT CHANGES WHAT IS WON. The server rolled before this opened; the
-- hold only decides how long the road to the answer is. The coast is solved
-- backwards from the winner, so the tile under the pointer at the end is the
-- server's by construction, whatever the player did with the button.
--
-- THE COAST IS A POWER CURVE FROM THE REEL'S OWN SPEED, NOT A FIXED TWEEN.
-- x(t) = D * (1 - (1 - t/T)^p) starts at exactly speed p*D/T, so the reel
-- leaves the hold at the speed it was doing -- no jump -- and eases down
-- through a long, readable crawl past the last few tiles. The old quint tween
-- started from a standstill and was nearly stopped within a second, which
-- read as rolling straight onto the answer.
local HOLD_MAX = 5
local SPEED_MIN = 1500
local SPEED_MAX = 5200
local COAST_MIN = 3.6
local COAST_MAX = 6.5
-- A press shorter than this is held for this long anyway, so a tap gets a
-- real spin rather than a nudge.
local TAP_EQUIV = 0.6
-- An untouched reel spins itself. An event drop can arrive mid-raid, and a
-- reward nobody claims is a modal sitting over the game.
local AUTO_AFTER = 8
local IDLE_SPEED = 45

-- WHAT EACH TIER'S CELEBRATION IS MADE OF. `rays` and `coins` are counts,
-- `flash` is how opaque the single sheet over the reel goes, `pitch` plays
-- the sting higher for a better tier, `hold` is how long the reveal stays.
-- COMMON GETS NO RAYS AND NO COINS ON PURPOSE: the variance is the mechanic,
-- so the bottom of the ladder has to be quieter than the top.
local DRAMA: { [string]: { rays: number, coins: number, flash: number, pitch: number, hold: number } } = {
	common    = { rays = 0,  coins = 0,  flash = 0.10, pitch = 0.94, hold = 2.2 },
	rare      = { rays = 8,  coins = 6,  flash = 0.20, pitch = 1.06, hold = 2.6 },
	epic      = { rays = 12, coins = 12, flash = 0.28, pitch = 1.16, hold = 3.0 },
	legendary = { rays = 16, coins = 20, flash = 0.36, pitch = 1.30, hold = 3.6 },
}
-- An event drop carries no tier and is not a common: a set item is the
-- rarest thing in the game, so it takes the epic treatment.
local NO_TIER_DRAMA = "epic"

local RAY_LEN = 640
local RAY_W = 26
local DOT = utf8.char(0x00B7)

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

-- The chest's odds line as chips. Crates hands over "65% rare . 35%
-- legendary"; read back into parts it can be drawn at a size a nine-year-old
-- reads from across the room, each in its own tier colour. Anything that is
-- not that shape (an event drop, a combine) comes back nil and is printed as
-- the plain line it is.
local function oddsParts(text: any): { { pct: string, tier: string } }?
	if type(text) ~= "string" then
		return nil
	end
	local parts = {}
	for pct, tier in text:gmatch("(%d+%%)%s+(%a+)") do
		if not Config.RARITIES[tier] then
			return nil
		end
		table.insert(parts, { pct = pct, tier = tier })
	end
	return if #parts > 0 then parts else nil
end

-- `payload` is the EventDrop or ChestResult-derived table. `iconFor(kind, key,
-- holder)` is optional and fills a frame with a preview of that item.
function SpinWheel.play(gui: ScreenGui, payload: any, iconFor: ((string, string, Frame) -> ())?)
	local pool = payload.pool or {}
	if #pool == 0 then
		return
	end

	local wonEntry = payload.won or pool[1]
	local tier: string? = payload.tier or wonEntry.tier
	local tone = tierColour(tier) or payload.tone or Theme.GOOD
	local drama = DRAMA[tier or ""] or DRAMA[NO_TIER_DRAMA]
	local flatOdds = if type(payload.odds) == "number" then payload.odds else 1 / #pool
	local pct = math.floor(flatOdds * 100 + 0.5)

	-- THE LOOP IS THE POOL, WITH THE WINNER IN IT. The reel repeats the pool
	-- end to end and wraps, so landing is "stop on any copy of the winner's
	-- slot". A winner that is not in the pool (a fallback entry) joins it.
	-- MIXED, NOT BEST-FIRST. The pool arrives sorted best tier first, which
	-- is right for a crate card and wrong for a reel: every legendary sat in
	-- one gold block, so the strip read as two bands rather than a river of
	-- chances. Dealt at random, preferring a different tier from the tile
	-- before, so the gold ones are scattered through the loop.
	local loop = {}
	do
		local left = table.clone(pool)
		while #left > 0 do
			local prev = loop[#loop]
			local choices = {}
			for i, e in ipairs(left) do
				if not prev or e.tier ~= prev.tier or e.tier == nil then
					table.insert(choices, i)
				end
			end
			if #choices == 0 then
				for i = 1, #left do
					table.insert(choices, i)
				end
			end
			table.insert(loop, table.remove(left, choices[math.random(#choices)]))
		end
	end
	local winSlot = 0
	for i, e in ipairs(loop) do
		if e == wonEntry or (e.kind == wonEntry.kind and e.key == wonEntry.key) then
			winSlot = i
			break
		end
	end
	if winSlot == 0 then
		table.insert(loop, wonEntry)
		winSlot = #loop
	end
	local n = #loop
	local LOOP_W = n * STRIDE
	-- Enough copies that the window never sees the end of the track at any
	-- wrap offset.
	local copies = math.ceil((WINDOW_W + STRIDE) / LOOP_W) + 1
	-- The strip offset that puts slot 0's centre under the pointer.
	local K = 4 + TILE_W / 2 - WINDOW_W / 2

	local hasNote = type(payload.note) == "string" and payload.note ~= ""
	local cardH = if hasNote then 372 else 344

	local shade = Instance.new("Frame")
	shade.Name = "DropWheel"
	shade.Size = UDim2.new(1, 0, 1, 0)
	shade.BackgroundColor3 = Theme.INK
	shade.BackgroundTransparency = 1
	shade.BorderSizePixel = 0
	shade.ZIndex = 60
	shade.Active = true
	shade.Parent = gui
	TweenService:Create(shade, TweenInfo.new(0.35), { BackgroundTransparency = 0.3 }):Play()

	-- ---- the burst, behind the card -------------------------------------
	--
	-- Siblings of the card at a lower ZIndex, never children: under
	-- `ZIndexBehavior.Sibling` a child always draws above its parent. Each bar
	-- is a PAIR of opposite rays centred on the middle, because Rotation turns
	-- a frame about its own centre and not about its AnchorPoint.
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

	local rayList: { Frame } = {}
	local bars = math.floor(drama.rays / 2)
	for i = 1, bars do
		local ray = Instance.new("Frame")
		ray.Name = "Ray" .. i
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.fromOffset(RAY_W, RAY_LEN * 2)
		ray.Rotation = (i - 1) * (180 / bars)
		ray.BackgroundColor3 = tone
		ray.BackgroundTransparency = 1
		ray.BorderSizePixel = 0
		ray.ZIndex = 60
		ray.Parent = rays
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
	--
	-- THE SHOP'S OWN VOCABULARY: a cream panel with a heavy ink outline, a
	-- gold header band with white popped type, and tiles dressed exactly like
	-- the crate and bag cards (tier ground, spotlight, deep edge). The pink
	-- band with the drawn snout is gone -- it was the one surface here that
	-- looked like no other part of the shop.
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromOffset(CARD_W, cardH)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.BackgroundColor3 = Theme.PAPER
	card.BorderSizePixel = 0
	card.ZIndex = 61
	card.Parent = shade
	Theme.corner(card, 20)
	-- The edge starts INK and takes the tier colour only when the reel lands:
	-- painted up front it would be a spoiler.
	local stroke = Theme.outline(card, 4, Theme.INK)

	local pop = Instance.new("UIScale")
	pop.Scale = 0.82
	pop.Parent = card
	TweenService:Create(pop, TweenInfo.new(0.34, Enum.EasingStyle.Back,
		Enum.EasingDirection.Out), { Scale = 1 }):Play()

	local head = Instance.new("Frame")
	head.Name = "Head"
	head.Size = UDim2.new(1, -PAD * 2, 0, 50)
	head.Position = UDim2.fromOffset(PAD, 14)
	head.BackgroundColor3 = Theme.GOLD
	head.BorderSizePixel = 0
	head.ZIndex = 62
	head.Parent = card
	Theme.corner(head, 14)
	Theme.outline(head, 3, Theme.INK)
	Theme.shade(head, 0.86)

	local title = label(head,
		payload.title or ("%s DROP"):format(string.upper(payload.setName or "SET")),
		UDim2.new(1, -170, 1, -8), UDim2.fromOffset(16, 4),
		Theme.FONT, 26, Theme.PAPER)
	title.Name = "Title"
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextScaled = true
	title.ZIndex = 63
	local titleCap = Instance.new("UITextSizeConstraint")
	titleCap.MaxTextSize = 26
	titleCap.MinTextSize = 14
	titleCap.Parent = title
	ShopStyle.popText(title)

	-- The tier chip lives at the header's right end and appears with the
	-- prize: before the landing it would be the answer.
	local tierChip: TextLabel? = nil
	if tier and Config.RARITIES[tier] then
		local chip = label(head, string.upper(Config.RARITIES[tier].label or tier),
			UDim2.fromOffset(140, 32), UDim2.new(1, -9, 0.5, 0), Theme.FONT, 18, Theme.PAPER)
		chip.Name = "TierChip"
		chip.AnchorPoint = Vector2.new(1, 0.5)
		chip.BackgroundColor3 = tone
		chip.BackgroundTransparency = 0
		chip.ZIndex = 64
		chip.Visible = false
		Theme.corner(chip, 999)
		Theme.outline(chip, 2, Theme.INK)
		ShopStyle.popText(chip)
		tierChip = chip
	end

	-- THE ODDS, BIG. Chips in each tier's own colour for a chest; a plain
	-- line for anything else. On screen before the spin, because this is the
	-- sentence that makes the reel honest.
	local oddsRow = Instance.new("Frame")
	oddsRow.Name = "Odds"
	oddsRow.BackgroundTransparency = 1
	oddsRow.Size = UDim2.new(1, -PAD * 2, 0, 34)
	oddsRow.Position = UDim2.fromOffset(PAD, 74)
	oddsRow.ZIndex = 62
	oddsRow.Parent = card
	local parts = oddsParts(payload.subtitle)
	if parts then
		local row = Instance.new("UIListLayout")
		row.FillDirection = Enum.FillDirection.Horizontal
		row.HorizontalAlignment = Enum.HorizontalAlignment.Center
		row.VerticalAlignment = Enum.VerticalAlignment.Center
		row.SortOrder = Enum.SortOrder.LayoutOrder
		row.Padding = UDim.new(0, 10)
		row.Parent = oddsRow
		for i, part in ipairs(parts) do
			local r = Config.RARITIES[part.tier]
			local chip = label(oddsRow, ("%s  %s"):format(part.pct, string.upper(r.label or part.tier)),
				UDim2.fromOffset(0, 32), UDim2.new(), Theme.FONT, 20, Theme.PAPER)
			chip.Name = "Odds_" .. part.tier
			chip.LayoutOrder = i
			chip.AutomaticSize = Enum.AutomaticSize.X
			chip.BackgroundColor3 = r.colour
			chip.BackgroundTransparency = 0
			chip.ZIndex = 63
			Theme.corner(chip, 999)
			Theme.outline(chip, 2, Theme.INK)
			local padding = Instance.new("UIPadding")
			padding.PaddingLeft = UDim.new(0, 14)
			padding.PaddingRight = UDim.new(0, 14)
			padding.Parent = chip
			ShopStyle.popText(chip)
		end
	else
		local line = label(oddsRow, payload.subtitle
				or ("%d items left %s %d%% each"):format(#pool, DOT, pct),
			UDim2.fromScale(1, 1), UDim2.new(), Theme.FONT, 20, Theme.INK)
		line.ZIndex = 63
	end

	-- ---- the reel window -------------------------------------------------
	local window = Instance.new("Frame")
	window.Name = "Window"
	window.Size = UDim2.fromOffset(WINDOW_W, WINDOW_H)
	window.Position = UDim2.fromOffset(PAD, 118)
	window.BackgroundColor3 = Theme.SLAB_DEEP
	window.BorderSizePixel = 0
	window.ClipsDescendants = true
	window.ZIndex = 62
	window.Parent = card
	Theme.corner(window, 14)
	Theme.outline(window, 3, Theme.INK)

	local strip = Instance.new("Frame")
	strip.Name = "Strip"
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.new(0, n * copies * STRIDE + 8, 1, 0)
	strip.ZIndex = 62
	strip.Parent = window

	-- EVERY TILE IS DRESSED LIKE A SHOP CARD, so the river of colour going
	-- past the pointer is the same ladder the crate page showed a moment ago.
	local tiles: { [number]: Frame } = {}
	local function addTile(entry: any, index: number)
		local t = Instance.new("Frame")
		t.Name = "Tile"
		t.Size = UDim2.fromOffset(TILE_W, TILE_H)
		-- Centred on its own anchor, so the winner's pop grows out of the
		-- middle rather than walking off the pointer.
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = UDim2.fromOffset(index * STRIDE + 4 + TILE_W / 2, 4 + TILE_H / 2)
		t.BackgroundColor3 = (tierColour(entry.tier) or tone):Lerp(Theme.PAPER, 0.35)
		t.BorderSizePixel = 0
		t.ZIndex = 62
		t.Parent = strip
		Theme.corner(t, 12)
		Theme.outline(t, 3, Theme.INK)

		local holder = Instance.new("Frame")
		holder.Name = "Icon"
		holder.Size = UDim2.new(1, -10, 1, -34)
		holder.Position = UDim2.fromOffset(5, 5)
		holder.BackgroundTransparency = 1
		holder.ZIndex = 63
		holder.Parent = t
		if entry.tier and Config.RARITIES[entry.tier] then
			SkinCards.dressCard(t, entry.tier, { holder })
		end
		if iconFor then
			iconFor(entry.kind, entry.key, holder)
		end

		local name = label(t, entry.name or entry.key, UDim2.new(1, -10, 0, 24),
			UDim2.new(0, 5, 1, -28), Theme.FONT, 15, Theme.PAPER)
		name.TextScaled = true
		name.ZIndex = 63
		local cap = Instance.new("UITextSizeConstraint")
		cap.MaxTextSize = 15
		cap.Parent = name
		ShopStyle.popText(name)
		tiles[index] = t
	end
	for index = 0, n * copies - 1 do
		addTile(loop[(index % n) + 1], index)
	end

	-- The edges go dark, so tiles arrive out of shadow rather than slide.
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

	-- The smear tracks the reel's own speed, so it is motion blur by
	-- construction and clears itself as the reel slows.
	local smear = Instance.new("Frame")
	smear.Name = "Smear"
	smear.Size = UDim2.fromScale(1, 1)
	smear.BackgroundColor3 = Theme.PAPER
	smear.BackgroundTransparency = 1
	smear.BorderSizePixel = 0
	smear.ZIndex = 64
	smear.Parent = window

	-- ---- the pointer -----------------------------------------------------
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
		chev.Size = UDim2.fromOffset(16, 16)
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

	-- ---- the spin button, which becomes the nameplate --------------------
	--
	-- ONE OBJECT, THREE STATES: a green SPIN button with a gold power
	-- bar filling as it is held; a dark plate reading SPINNING while the reel
	-- coasts; the same plate carrying the prize in the tier's colour when it
	-- lands. The reveal then CHANGES something the player was already looking
	-- at rather than appearing from nothing.
	local plate = Instance.new("TextButton")
	plate.Name = "SpinButton"
	plate.Text = ""
	plate.AutoButtonColor = false
	plate.Size = UDim2.new(1, -PAD * 2, 0, 58)
	plate.AnchorPoint = Vector2.new(0.5, 0.5)
	plate.Position = UDim2.fromOffset(CARD_W / 2, 272 + 29)
	plate.BackgroundColor3 = Theme.GOOD
	plate.BorderSizePixel = 0
	plate.ZIndex = 62
	plate.Parent = card
	Theme.corner(plate, 14)
	Theme.outline(plate, 3, Theme.INK)

	local power = Instance.new("Frame")
	power.Name = "Power"
	power.Size = UDim2.new(0, 0, 1, 0)
	power.BackgroundColor3 = Theme.GOLD
	power.BorderSizePixel = 0
	power.ZIndex = 62
	power.Parent = plate
	Theme.corner(power, 14)

	-- JUST "SPIN". Holding is there for anybody who finds it -- the power bar
	-- fills under their thumb -- and a plain tap is an equally good spin, so
	-- the button does not tell anybody how to press it.
	local prize = label(plate, "SPIN", UDim2.fromScale(1, 1), UDim2.new(),
		Theme.FONT, 28, Theme.PAPER)
	prize.Name = "Prize"
	prize.ZIndex = 63
	-- ITS OWN OUTLINE, NOT `ShopStyle.popText`: that helper pins a label to
	-- white for good, and this one has to turn the tier's colour on landing.
	local prizeEdge = Instance.new("UIStroke")
	prizeEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	prizeEdge.Color = Theme.INK
	prizeEdge.Thickness = 3
	prizeEdge.Parent = prize

	local prizePop = Instance.new("UIScale")
	prizePop.Parent = plate

	-- A duplicate is never a dead outcome; the note says what the spare is
	-- worth, and appears with the prize rather than before it.
	local note: TextLabel? = nil
	if hasNote then
		local line = label(card, payload.note, UDim2.new(1, -PAD * 2, 0, 22),
			UDim2.new(0, PAD, 1, -38), Theme.FONT_BODY, 16,
			Theme.readable(Theme.MUTED, Theme.PAPER))
		line.ZIndex = 62
		line.TextTransparency = 1
		note = line
	end

	-- ---- the motion ------------------------------------------------------
	local phase = "ready" -- ready | holding | coast | landed
	local startSlot = math.random(0, n - 1)
	if n > 1 and startSlot == winSlot - 1 then
		startSlot = (startSlot + 1) % n
	end
	local x = (startSlot * STRIDE + K) % LOOP_W
	local v = IDLE_SPEED
	local born = os.clock()
	local pressStart = 0
	local releaseAt: number? = nil
	local heldFor = 0
	local coastFrom, coastD, coastT, coastP, coastT0 = 0, 0, 1, 3, 0
	local winTile: Frame? = nil

	local function beginCoast()
		if phase == "coast" or phase == "landed" then
			return
		end
		phase = "coast"
		local h = math.clamp(heldFor / HOLD_MAX, 0, 1)
		local T = COAST_MIN + (COAST_MAX - COAST_MIN) * h
		local v0 = math.max(v, SPEED_MIN * 0.5)
		-- The landing residue: any x congruent to this puts a copy of the
		-- winner's slot under the pointer.
		local r = ((winSlot - 1) * STRIDE + K) % LOOP_W
		local ideal = v0 * T / 3
		-- The first winner copy at least most of the ideal distance away, never
		-- a nearer one: a short road forces a sharp curve and a one-second
		-- stop, which is the rolled-straight-onto-it read this exists to fix.
		-- Measured over 20,000 random pools and holds, the coast runs 3.6s to
		-- about 9s (a forty-item pool on a full hold) and always lands.
		local k = math.ceil((x + ideal * 0.85 - r) / LOOP_W)
		local best = r + k * LOOP_W - x
		-- Solve the curve so it starts at exactly v0; if that makes it too
		-- sharp or too flat, clamp the shape and let the duration give.
		local p = math.clamp(v0 * T / best, 2, 5)
		coastFrom, coastD, coastP, coastT0 = x, best, p, os.clock()
		coastT = p * best / v0
		plate.BackgroundColor3 = Theme.SLAB_DEEP
		power.Visible = false
		prize.Text = "SPINNING" .. utf8.char(0x2026)
		prize.TextColor3 = Theme.MUTED_LIGHT
	end

	local function press()
		if phase ~= "ready" then
			return
		end
		phase = "holding"
		pressStart = os.clock()
		releaseAt = nil
		SoundKit.ui(Config.SOUNDS.CLICK, { name = "ReelStart", volume = 0.25, pitch = 0.9 })
	end
	local function release()
		if phase ~= "holding" or releaseAt then
			return
		end
		releaseAt = math.max(os.clock(), pressStart + TAP_EQUIV)
	end

	local connections: { RBXScriptConnection } = {}
	local function isPointer(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
	end
	local function isKey(input: InputObject): boolean
		return input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return
			or input.KeyCode == Enum.KeyCode.ButtonA
	end
	table.insert(connections, plate.InputBegan:Connect(function(input)
		if isPointer(input) then
			press()
		end
	end))
	-- The button's own down/up as well: some input paths (and Studio's
	-- synthetic mouse) raise these without a GuiObject.InputBegan. Both
	-- routes are idempotent, so a press seen twice is still one press.
	table.insert(connections, plate.MouseButton1Down:Connect(press))
	table.insert(connections, plate.MouseButton1Up:Connect(release))
	table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and isKey(input) then
			press()
		end
	end))
	-- Released ANYWHERE, not only over the button: a thumb that slides off
	-- the button while holding must still let go.
	table.insert(connections, UserInputService.InputEnded:Connect(function(input)
		if isPointer(input) or isKey(input) then
			release()
		end
	end))

	local done = false
	local closing = false
	local lastTile: number? = nil
	local lastTick = 0

	local function close()
		if closing then
			return
		end
		closing = true
		for _, c in ipairs(connections) do
			c:Disconnect()
		end
		-- THE PRIZE GOES INTO THE BAG, exactly as a robbed skin does at the end
		-- of its reveal (`LootHaul`). A crate that faded out instead left the
		-- one question a new player has -- where did it go? -- unanswered.
		local wt = winTile
		if done and wt and wt.Parent and wonEntry.kind then
			FlyToBag.fly(gui, wt)
			wt.Visible = false
		end
		TweenService:Create(shade, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(card, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(pop, TweenInfo.new(0.3), { Scale = 0.9 }):Play()
		task.delay(0.32, function()
			shade:Destroy()
		end)
	end

	-- ---- the landing -----------------------------------------------------
	local function finish()
		if done then
			return
		end
		done = true

		-- THE ONE FLASH IN THE FILE, fading rather than blinking, which keeps
		-- this inside the three-flashes-a-second rule with nothing to count.
		local flash = Instance.new("Frame")
		flash.Name = "Flash"
		flash.Size = UDim2.fromScale(1, 1)
		flash.BackgroundColor3 = Theme.PAPER
		flash.BackgroundTransparency = drama.flash
		flash.BorderSizePixel = 0
		flash.ZIndex = 67
		flash.Parent = window
		TweenService:Create(flash, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()

		local wt = winTile
		if wt then
			local winEdge = wt:FindFirstChildOfClass("UIStroke")
			if winEdge then
				winEdge.Color = tone
				winEdge.Thickness = 5
			end
			local tilePop = Instance.new("UIScale")
			tilePop.Parent = wt
			TweenService:Create(tilePop, TweenInfo.new(0.18, Enum.EasingStyle.Back,
				Enum.EasingDirection.Out), { Scale = 1.12 }):Play()
			task.delay(0.2, function()
				if tilePop.Parent then
					TweenService:Create(tilePop, TweenInfo.new(0.22), { Scale = 1 }):Play()
				end
			end)
		end

		if drama.rays > 0 then
			TweenService:Create(bloom, TweenInfo.new(0.5), { BackgroundTransparency = 0.82 }):Play()
			for _, ray in ipairs(rayList) do
				TweenService:Create(ray, TweenInfo.new(0.4), { BackgroundTransparency = 0 }):Play()
			end
			TweenService:Create(rays, TweenInfo.new(drama.hold + 1.2,
				Enum.EasingStyle.Linear), { Rotation = 70 }):Play()
		end

		-- The colour arrives here, all at once: edge, pointer, glow, chevrons.
		TweenService:Create(stroke, TweenInfo.new(0.3), { Color = tone }):Play()
		TweenService:Create(glow, TweenInfo.new(0.3),
			{ BackgroundColor3 = tone, BackgroundTransparency = 0.5 }):Play()
		for _, chev in ipairs(chevrons) do
			TweenService:Create(chev, TweenInfo.new(0.3), { BackgroundColor3 = tone }):Play()
		end

		prize.Text = ("%s!"):format(wonEntry.name or wonEntry.key)
		prize.TextColor3 = tone
		TweenService:Create(prizePop, TweenInfo.new(0.16, Enum.EasingStyle.Back,
			Enum.EasingDirection.Out), { Scale = 1.1 }):Play()
		task.delay(0.18, function()
			if prizePop.Parent then
				TweenService:Create(prizePop, TweenInfo.new(0.22), { Scale = 1 }):Play()
			end
		end)
		local chip = tierChip
		if chip then
			chip.Visible = true
			local chipPop = Instance.new("UIScale")
			chipPop.Scale = 0.6
			chipPop.Parent = chip
			TweenService:Create(chipPop, TweenInfo.new(0.25, Enum.EasingStyle.Back,
				Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		if note then
			TweenService:Create(note, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
		end

		-- Coin confetti: the drawn gold disc the balance badge wears, flying
		-- from the nameplate and shrinking away rather than fading.
		for i = 1, drama.coins do
			local size = math.random(14, 24)
			local coin = Theme.coin(shade, size, "Confetti")
			coin.Position = UDim2.new(0.5, math.random(-120, 120), 0.5, 110)
			coin.AnchorPoint = Vector2.new(0.5, 0.5)
			coin.ZIndex = 66
			coin.Rotation = math.random(0, 359)
			local outX = math.random(-330, 330)
			local upY = -math.random(90, 250)
			TweenService:Create(coin, TweenInfo.new(0.42, Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out), {
				Position = UDim2.new(0.5, outX, 0.5, 110 + upY),
				Rotation = coin.Rotation + math.random(-220, 220),
			}):Play()
			task.delay(0.42, function()
				if not coin.Parent then
					return
				end
				TweenService:Create(coin, TweenInfo.new(0.75, Enum.EasingStyle.Quad,
					Enum.EasingDirection.In), {
					Position = UDim2.new(0.5, outX * 1.25, 0.5, 440),
					Size = UDim2.fromOffset(0, 0),
					Rotation = coin.Rotation + 200,
				}):Play()
			end)
			task.delay(1.3, function()
				if coin.Parent then
					coin:Destroy()
				end
			end)
			if i == 1 then
				SoundKit.ui(Config.SOUNDS.COIN_DROP,
					{ name = "CrateCoins", volume = 0.3, pitch = 1.15 })
			end
		end

		SoundKit.ui(Config.SOUNDS.MILESTONE,
			{ name = "CrateWin", volume = 0.36, pitch = drama.pitch })

		-- It closes itself, and any input after the landing skips the wait --
		-- armed a beat late so the release that ended the spin cannot count.
		task.delay(drama.hold, close)
		task.delay(0.4, function()
			if closing then
				return
			end
			table.insert(connections, UserInputService.InputBegan:Connect(function(_, processed)
				if not processed then
					close()
				end
			end))
			table.insert(connections, plate.Activated:Connect(close))
		end)
	end

	table.insert(connections, RunService.Heartbeat:Connect(function(dt)
		if not strip.Parent then
			return
		end
		local now = os.clock()

		if phase == "ready" then
			v = IDLE_SPEED
			x += v * dt
			-- The button breathes so it reads as the thing to press.
			prizePop.Scale = 1 + 0.03 * math.sin((now - born) * 5)
			if now - born > AUTO_AFTER then
				press()
				release()
			end
		elseif phase == "holding" then
			heldFor = math.min(now - pressStart, HOLD_MAX)
			local h = heldFor / HOLD_MAX
			local target = SPEED_MIN + (SPEED_MAX - SPEED_MIN) * h
			v += (target - v) * math.min(1, dt * 5)
			x += v * dt
			power.Size = UDim2.new(h, 0, 1, 0)
			prizePop.Scale = 1 + 0.04 * h
			if heldFor >= HOLD_MAX and not releaseAt then
				releaseAt = now
			end
			if releaseAt and now >= releaseAt then
				prizePop.Scale = 1
				beginCoast()
			end
		elseif phase == "coast" then
			local u = math.clamp((now - coastT0) / coastT, 0, 1)
			local left = 1 - u
			x = coastFrom + coastD * (1 - left ^ coastP)
			v = coastP * coastD / coastT * left ^ (coastP - 1)
			if u >= 1 then
				x = coastFrom + coastD
				v = 0
				phase = "landed"
			end
		end

		strip.Position = UDim2.fromOffset(-(x % LOOP_W), 0)

		-- Motion blur off the reel's own speed.
		smear.BackgroundTransparency = 1 - math.clamp(v / (SPEED_MAX * 0.6), 0, 1) * 0.22
		if not done then
			glow.BackgroundTransparency = 0.72 - 0.16 * (0.5 + 0.5 * math.sin((now - born) * 8.8))
		end

		-- A tick per tile past the pointer, counted from position: a rattle at
		-- speed that slows to single clicks as it lands. Throttled so a full
		-- hold is a buzz rather than forty overlapping sounds a second.
		local tile = math.floor((x - K) / STRIDE)
		if tile ~= lastTile then
			if lastTile ~= nil and phase ~= "ready" and now - lastTick > 0.045 then
				lastTick = now
				SoundKit.ui(Config.SOUNDS.CLICK,
					{ name = "ReelTick", volume = 0.16, pitch = 1.25 + math.min(v / SPEED_MAX, 1) * 0.3 })
			end
			lastTile = tile
		end

		if phase == "landed" and not done then
			smear.BackgroundTransparency = 1
			-- The tile under the pointer is a copy of the winner's slot by
			-- construction; find which copy to light up.
			local s = x % LOOP_W
			winTile = tiles[math.floor((s - K) / STRIDE + 0.5)]
			finish()
		end
	end))
end

return SpinWheel
