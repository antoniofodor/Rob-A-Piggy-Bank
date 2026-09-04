--!strict
--[[
	SpinWheel

	The reward reel that plays when an event drops a set item.

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
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(ReplicatedStorage.Shared.Theme)

local SpinWheel = {}

local TILE_W, TILE_H = 132, 132
local GAP = 8
local STRIDE = TILE_W + GAP
-- How many copies of the pool scroll past before it settles. Enough that the
-- reel is moving fast at the start and clearly slowing at the end; fewer and
-- it reads as a jump cut rather than a spin.
local LOOPS = 7
local SPIN_SECONDS = 3.4

local function corner(inst: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = inst
	return c
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

-- `payload` is the EventDrop table. `iconFor(kind, key, holder)` is optional
-- and fills a frame with a preview of that item.
function SpinWheel.play(gui: ScreenGui, payload: any, iconFor: ((string, string, Frame) -> ())?)
	local pool = payload.pool or {}
	if #pool == 0 then
		return
	end

	local tone = payload.tone or Theme.GOOD
	local pct = math.floor((payload.odds or (1 / #pool)) * 100 + 0.5)

	local shade = Instance.new("Frame")
	shade.Name = "DropWheel"
	shade.Size = UDim2.new(1, 0, 1, 0)
	shade.BackgroundColor3 = Theme.INK
	shade.BackgroundTransparency = 1
	shade.BorderSizePixel = 0
	shade.ZIndex = 60
	shade.Parent = gui
	TweenService:Create(shade, TweenInfo.new(0.35), { BackgroundTransparency = 0.35 }):Play()

	local card = Instance.new("Frame")
	card.Size = UDim2.new(0, 560, 0, 300)
	card.Position = UDim2.new(0.5, 0, 0.5, 0)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.BackgroundColor3 = Theme.SAND
	card.BorderSizePixel = 0
	card.ZIndex = 61
	card.Parent = shade
	corner(card, 16)

	local stroke = Instance.new("UIStroke")
	stroke.Color = tone
	stroke.Thickness = 2
	stroke.Transparency = 0.3
	stroke.Parent = card

	label(card, ("%s DROP"):format(string.upper(payload.setName or "SET")),
		UDim2.new(1, -24, 0, 30), UDim2.new(0, 12, 0, 14),
		Enum.Font.FredokaOne, 22, tone).ZIndex = 62

	-- The odds, stated plainly. This is the sentence that makes the reel
	-- honest, so it is on screen before the spin rather than after it.
	label(card, ("%d items left %s %d%% each"):format(#pool, utf8.char(0x00B7), pct),
		UDim2.new(1, -24, 0, 18), UDim2.new(0, 12, 0, 44),
		Enum.Font.Gotham, 13, Theme.MUTED).ZIndex = 62

	-- The window the reel scrolls through.
	local window = Instance.new("Frame")
	window.Size = UDim2.new(1, -40, 0, TILE_H + 8)
	window.Position = UDim2.new(0, 20, 0, 74)
	window.BackgroundColor3 = Theme.SLAB
	window.BorderSizePixel = 0
	window.ClipsDescendants = true
	window.ZIndex = 61
	window.Parent = card
	corner(window, 10)

	local strip = Instance.new("Frame")
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.new(0, 10000, 1, 0)
	strip.Position = UDim2.new(0, 0, 0, 0)
	strip.ZIndex = 61
	strip.Parent = window

	-- Build the reel: LOOPS copies of the pool, then the winner placed once
	-- more at the end. Landing is therefore a fixed offset rather than a
	-- search, and the tile under the pointer is the server's answer by
	-- construction rather than by coincidence.
	local tiles: { Frame } = {}
	local function addTile(entry: any, index: number): Frame
		local t = Instance.new("Frame")
		t.Size = UDim2.new(0, TILE_W, 0, TILE_H)
		t.Position = UDim2.new(0, index * STRIDE + 4, 0, 4)
		t.BackgroundColor3 = Theme.PAPER
		t.BorderSizePixel = 0
		t.ZIndex = 61
		t.Parent = strip
		corner(t, 8)

		local holder = Instance.new("Frame")
		holder.Size = UDim2.new(1, -10, 1, -34)
		holder.Position = UDim2.new(0, 5, 0, 5)
		holder.BackgroundTransparency = 1
		holder.ZIndex = 62
		holder.Parent = t
		if iconFor then
			iconFor(entry.kind, entry.key, holder)
		end

		local name = label(t, entry.name or entry.key, UDim2.new(1, -8, 0, 26),
			UDim2.new(0, 4, 1, -28), Enum.Font.GothamBold, 12,
			Theme.INK)
		name.TextScaled = true
		name.ZIndex = 62
		table.insert(tiles, t)
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
	local wonEntry = payload.won or pool[1]
	-- The winner's own name, looked up from the pool so the tile matches the
	-- others exactly rather than being a differently-shaped special case.
	local winTile = addTile(wonEntry, winIndex)
	-- A few more after it, so the reel does not visibly run out of track.
	for i = 1, #pool do
		addTile(pool[((i - 1) % #pool) + 1], winIndex + i)
	end

	-- The pointer, over the centre of the window.
	local pointer = Instance.new("Frame")
	pointer.Size = UDim2.new(0, 3, 1, 0)
	pointer.Position = UDim2.new(0.5, -1, 0, 0)
	pointer.BackgroundColor3 = tone
	pointer.BorderSizePixel = 0
	pointer.ZIndex = 63
	pointer.Parent = window

	local prize = label(card, "", UDim2.new(1, -24, 0, 40), UDim2.new(0, 12, 1, -56),
		Enum.Font.FredokaOne, 24, tone)
	prize.ZIndex = 62
	prize.TextTransparency = 1

	-- Land so the winning tile's CENTRE sits under the pointer.
	local target = -(winIndex * STRIDE + 4 + TILE_W / 2) + window.AbsoluteSize.X / 2
	local tween = TweenService:Create(strip,
		TweenInfo.new(SPIN_SECONDS, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Position = UDim2.new(0, target, 0, 0) })
	tween:Play()

	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		winTile.BackgroundColor3 = Color3.fromRGB(204, 237, 205)
		local win = Instance.new("UIStroke")
		win.Color = tone
		win.Thickness = 3
		win.Parent = winTile
		prize.Text = ("%s!"):format(wonEntry.name or wonEntry.key)
		TweenService:Create(prize, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
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
		task.delay(0.32, function()
			shade:Destroy()
		end)
	end

	task.delay(SPIN_SECONDS + 2.6, close)

	-- Any input after the reel has landed skips the wait, the same courtesy
	-- the arrest scene gives somebody who has seen it forty times.
	local conn
	conn = UserInputService.InputBegan:Connect(function(_, processed)
		if not processed and done then
			conn:Disconnect()
			close()
		end
	end)
	task.delay(SPIN_SECONDS + 3.2, function()
		if conn.Connected then
			conn:Disconnect()
		end
	end)
end

return SpinWheel
