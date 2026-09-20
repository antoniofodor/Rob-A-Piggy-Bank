--!strict
-- Capacity HUD. All balances come from StateUpdate; only the fill and ETA
-- are derived here. Keeping the widget here also frees ClientMain registers.
local TweenService = game:GetService("TweenService")
local Config = require(script.Parent.Config)
local Theme = require(script.Parent.Theme)

local PiggyPanel = {}
-- assets/piggy-hud/piggy-balance-v2.png, imported under the experience's owner.
-- Emptying this falls back to the drawn pig below, which is why that code stays:
-- a moderated or deleted image would otherwise leave an empty hole in the card.
PiggyPanel.ICON_IMAGE = "rbxassetid://115881888441059"
-- The width of every chip stacked under this panel. Shared with `Wanted`,
-- which is the neighbour it has to line up with.
PiggyPanel.CHIP_W = 176

local function shape(parent: Instance, name: string, x: number, y: number,
	w: number, h: number, colour: Color3, radius: number, z: number?): Frame

	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = UDim2.fromOffset(x, y)
	frame.Size = UDim2.fromOffset(w, h)
	frame.BackgroundColor3 = colour
	frame.BorderSizePixel = 0
	frame.ZIndex = z or 1
	Theme.corner(frame, radius)
	frame.Parent = parent
	return frame
end

local function label(parent: Instance, name: string, text: string, x: number,
	y: number, w: number, h: number, size: number, colour: Color3): TextLabel

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = name
	textLabel.Position = UDim2.fromOffset(x, y)
	textLabel.Size = UDim2.fromOffset(w, h)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Theme.FONT
	textLabel.TextSize = size
	textLabel.TextColor3 = colour
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.Text = text
	textLabel.Parent = parent
	return textLabel
end

-- A front-facing pig, drawn at its final HUD size. Its face never changes
-- colour with the balance: gold belongs to the adjacent capacity gauge.
local function buildPig(parent: Instance)
	if PiggyPanel.ICON_IMAGE ~= "" then
		local image = Instance.new("ImageLabel")
		image.Name = "Pig"
		image.Position = UDim2.fromOffset(13, 17)
		image.Size = UDim2.fromOffset(94, 94)
		image.BackgroundTransparency = 1
		image.ScaleType = Enum.ScaleType.Fit
		image.Image = PiggyPanel.ICON_IMAGE
		image.Parent = parent
		return
	end
	local medallion = shape(parent, "Pig", 13, 17, 94, 94, Theme.SAND_DEEP, 47)
	Theme.outline(medallion, 2, Theme.MUTED)
	Theme.shade(medallion, 0.9)
	local ring = shape(medallion, "InnerRing", 5, 5, 84, 84, Theme.PAPER, 42)
	Theme.outline(ring, 1, Theme.PAPER_DEEP)
	for _, x in { 23, 55 } do
		local foot = shape(medallion, "Foot", x, 76, 15, 14, Theme.PIG_DEEP, 6, 2)
		Theme.outline(foot, 1.5, Theme.MUTED)
	end
	for _, x in { 12, 62 } do
		local ear = shape(medallion, "Ear", x, 13, 22, 29, Theme.PIG, 8, 3)
		ear.Rotation = if x == 12 then -24 else 24
		Theme.outline(ear, 1.5, Theme.PIG_DEEP)
		shape(ear, "InnerEar", 5, 5, 12, 18, Theme.PIG_DEEP, 5)
	end
	local head = shape(medallion, "Head", 12, 24, 71, 60, Theme.PIG, 29, 4)
	Theme.outline(head, 1.5, Theme.PIG_DEEP)
	Theme.shade(head, 0.9)
	local sheen = shape(head, "ForeheadShine", 15, 5, 27, 7, Theme.PAPER, 5)
	sheen.BackgroundTransparency = 0.65
	for _, x in { 17, 49 } do
		local eye = shape(head, "Eye", x, 20, 7, 11, Theme.INK, 4)
		shape(eye, "Catchlight", 1, 1, 3, 4, Theme.PAPER, 2)
	end
	for _, x in { 7, 56 } do
		local cheek = shape(head, "Cheek", x, 35, 10, 5, Theme.PIG_DEEP, 4)
		cheek.BackgroundTransparency = 0.55
	end
	local snout = shape(head, "Snout", 22, 32, 29, 21, Theme.PIG, 11, 2)
	Theme.outline(snout, 1.5, Theme.PIG_DEEP)
	Theme.shade(snout, 0.85)
	for _, x in { 7, 18 } do
		shape(snout, "Nostril", x, 7, 4, 8, Theme.PIG_DEEP, 3)
	end
	-- Small smile beneath the snout, with its upper half hidden by the snout.
	local smile = shape(head, "Smile", 31, 48, 12, 8, Theme.PIG_DEEP, 6)
	shape(smile, "SmileInset", 0, -3, 12, 8, Theme.PIG, 6)
	shape(medallion, "CoinSlot", 36, 20, 26, 5, Theme.INK, 3, 5)
	local coin = Theme.coin(medallion, 27, "Coin")
	coin.Position = UDim2.fromOffset(37, -5)
	coin.Rotation = 14
	coin.ZIndex = 6
	-- Use a neutral shading pass: gradients multiply their base colour.
	Theme.shade(coin, 0.83)
end

-- THE PANEL IS A MEDALLION WITH TWO TABS, NOT A CARD.
--
-- It was one 420 x 128 paper card with the pig in a 94-pixel box at its left
-- end and a separate acorn chip hung underneath -- every element the same
-- weight, so the worn skin, which is the one thing up there a player actually
-- chose, read as a thumbnail. Now the pig stands in a BIG ROUND MEDALLION at
-- the right edge, and the two balances are tabs running off it: the coin
-- plate (balance, rate, fill, ETA) behind its upper half and the acorn tab
-- behind its lower half. The tabs tuck UNDER the circle, so their right ends
-- are hidden by it and the whole thing reads as one object.
--
-- Drawn at one design size and scaled: `COMPACT_SCALE` on a phone and
-- `bankScale` on a tablet. HUDLayout's bankWidth/bankHeight are these numbers
-- after the compact scale, so FirstJob keeps clearing the panel.
local DESIGN_W = 404
local MEDAL_D, MEDAL_X, MEDAL_Y = 136, 268, 4
local PLATE_X, PLATE_Y, PLATE_W = 0, 8, 320
local TAB_X, TAB_W, TAB_H = 128, 200, 36
PiggyPanel.COMPACT_SCALE = 0.64

-- A dark copy of a shape, drawn under it. Siblings rather than children: under
-- ZIndexBehavior.Sibling a child always draws ABOVE its parent.
local function dropShadow(parent: Instance, of: Frame, radius: number): Frame
	local s = shape(parent, of.Name .. "Shadow", 0, 0, 0, 0, Theme.INK, radius, 0)
	s.BackgroundTransparency = 0.72
	local function sync()
		s.Position = of.Position + UDim2.fromOffset(0, 4)
		s.Size = of.Size
		s.Visible = of.Visible
	end
	of:GetPropertyChangedSignal("Position"):Connect(sync)
	of:GetPropertyChangedSignal("Size"):Connect(sync)
	of:GetPropertyChangedSignal("Visible"):Connect(sync)
	sync()
	return s
end

function PiggyPanel.new(gui: ScreenGui)
	-- The root carries nothing visible of its own: it is the frame the three
	-- shapes are laid out in, anchored to the top-right corner.
	local root = Instance.new("Frame")
	root.Name = "PiggyPanel"
	root.AnchorPoint = Vector2.new(1, 0)
	root.Size = UDim2.fromOffset(DESIGN_W, 148)
	root.Position = UDim2.new(1, -14, 0, 72)
	root.BackgroundTransparency = 1
	root.ZIndex = 1
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = root

	-- ---------------------------------------------------------- coin plate
	local plate = shape(root, "CoinPlate", PLATE_X, PLATE_Y, PLATE_W, 94, Theme.PAPER, 22, 2)
	Theme.outline(plate, 2.5, Theme.INK)
	Theme.gloss(plate, Theme.PAPER, Theme.PAPER_DEEP)
	dropShadow(root, plate, 22)

	local coinIcon = Theme.coin(plate, 30, "CoinIcon")
	coinIcon.Position = UDim2.fromOffset(14, 11)
	local coins = label(plate, "Coins", "0", 50, 6, 124, 38, 32, Theme.INK)
	coins.TextTruncate = Enum.TextTruncate.AtEnd
	-- Kept for the one reader that names it; the capacity now rides the bar.
	local capacity = label(plate, "Capacity", "", 0, 0, 0, 0, 1, Theme.MUTED)
	capacity.Visible = false

	local ratePill = shape(plate, "IncomePill", 176, 11, 84, 28,
		Theme.PAPER:Lerp(Theme.GOOD, 0.18), 14, 3)
	Theme.outline(ratePill, 1.5, Theme.GOOD_INK:Lerp(Theme.PAPER, 0.45))
	local rate = label(ratePill, "Rate", "+0/s", 4, 0, 76, 28, 14, Theme.GOOD_INK)
	rate.TextXAlignment = Enum.TextXAlignment.Center
	-- THE SECOND LINE, SHOWN ONLY WHILE A BOOST IS RUNNING. See `paintRate`.
	local boostLine = label(ratePill, "Boost", "", 4, 22, 76, 16, 11, Theme.GOLD_INK)
	boostLine.TextXAlignment = Enum.TextXAlignment.Center
	boostLine.Visible = false

	-- THE RATE READOUT IS THE ONE PLACE A BOOST IS VISIBLE: the server sends
	-- the BASE rate and the multiplier on one push, and a buff nobody can see
	-- is a trap. Multiplying for display is presentation, not state.
	local shownIncome, boostMult, boostLeft, rateCompact = 0, 1, 0, false
	-- A FULL PIG IS THE LOUDEST THING THIS PANEL HAS TO SAY, so it is drawn on
	-- the bar -- which stays visible at every size -- and on the medallion's
	-- ring, never only on the status line a compact panel hides.
	local isFull, shownPercent, shownLimit = false, "0%", "0"
	local function paintRate()
		local boosted = boostMult > 1 and boostLeft > 0
		rate.Text = ("+%s/s"):format(
			Config.formatCoins(shownIncome * (if boosted then boostMult else 1)))
		-- GOLD WHILE IT RUNS, so the change reads without the words being read.
		ratePill.BackgroundColor3 = if boosted
			then Theme.PAPER:Lerp(Theme.GOLD, 0.55)
			else Theme.PAPER:Lerp(Theme.GOOD, 0.18)
		boostLine.Visible = boosted
		if boosted then
			-- Lifted and grown UPWARD into the gap over the pill, so the second
			-- line never reaches the bar under it.
			ratePill.Position = UDim2.fromOffset(176, 3)
			ratePill.Size = UDim2.fromOffset(84, 40)
			rate.Size = UDim2.fromOffset(76, 24)
			boostLine.Text = ("%s%d  %s  %d:%02d"):format(
				utf8.char(0x00D7), boostMult, utf8.char(0x00B7),
				boostLeft // 60, boostLeft % 60)
		else
			ratePill.Position = UDim2.fromOffset(176, 11)
			ratePill.Size = UDim2.fromOffset(84, 28)
			rate.Size = UDim2.fromOffset(76, 28)
		end
	end

	local track = shape(plate, "Track", 14, 50, 248, 24, Theme.PIG_DEEP, 12, 3)
	Theme.outline(track, 2, Theme.INK)
	Theme.shade(track, 0.8)
	-- The rounded leading edge follows the balance, including when spending
	-- moves it backwards. Hidden at zero so an empty pig has no gold sliver.
	local fill = shape(track, "Fill", 0, 0, 0, 24, Theme.GOLD, 12)
	fill.Visible = false
	Theme.shade(fill, 0.84)
	local highlight = shape(fill, "Highlight", 8, 3, 0, 5, Theme.PAPER, 3)
	highlight.Size = UDim2.new(1, -16, 0, 5)
	highlight.BackgroundTransparency = 0.5
	-- Paper type with a stroke, because it sits across two grounds at once:
	-- the gold fill and the pink track.
	local percent = label(track, "Percent", "0%", 0, 0, 248, 24, 15, Theme.PAPER)
	percent.Size = UDim2.fromScale(1, 1)
	percent.ZIndex = 3
	percent.TextXAlignment = Enum.TextXAlignment.Center
	percent.TextStrokeColor3 = Theme.INK
	percent.TextStrokeTransparency = 0.15
	local status = label(plate, "Amount", "Waiting for your piggy...", 14, 76, 248, 15, 12, Theme.MUTED)
	status.Font = Theme.FONT_BODY
	status.TextXAlignment = Enum.TextXAlignment.Center

	-- ------------------------------------------------------------ acorn tab
	-- Named AcornBalance because LootHaul flies acorns into it by that name.
	local acorns = shape(root, "AcornBalance", TAB_X, 108, TAB_W, TAB_H, Theme.PAPER, 18, 2)
	Theme.outline(acorns, 2.5, Theme.INK)
	Theme.gloss(acorns, Theme.PAPER, Theme.PAPER_DEEP)
	dropShadow(root, acorns, 18)
	local acornIcon = Theme.acorn(acorns, 28)
	acornIcon.Position = UDim2.fromOffset(9, 4)
	acornIcon.ZIndex = 3
	-- Ends well before the medallion, which covers the tab's last ~60 pixels
	-- on a compact panel, where the tab rides higher up the circle.
	local acornCount = label(acorns, "Count", "0", 42, 0, 88, TAB_H, 19, Theme.INK)
	acornCount.TextTruncate = Enum.TextTruncate.AtEnd
	acornCount.TextXAlignment = Enum.TextXAlignment.Right

	-- ------------------------------------------------------------ medallion
	local medal = shape(root, "Medallion", MEDAL_X, MEDAL_Y, MEDAL_D, MEDAL_D,
		Theme.PAPER, MEDAL_D // 2, 4)
	Theme.outline(medal, 3, Theme.INK)
	Theme.gloss(medal, Theme.PAPER, Theme.PAPER_DEEP)
	dropShadow(root, medal, MEDAL_D // 2)
	-- The inner disc the pig stands on: a soft pink well framed by a gold
	-- ring. Pink because it is the pig's, gold because the pig is the wallet.
	local inner = shape(medal, "Well", 9, 9, MEDAL_D - 18, MEDAL_D - 18,
		Theme.PAPER:Lerp(Theme.PIG, 0.38), (MEDAL_D - 18) // 2, 1)
	local innerShade = Instance.new("UIGradient")
	innerShade.Rotation = 90
	innerShade.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(0.84, 0.84, 0.84))
	innerShade.Parent = inner
	local ring = Instance.new("UIStroke")
	ring.Thickness = 5
	ring.Color = Color3.new(1, 1, 1)
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Parent = inner
	-- A SHEEN THAT ORBITS THE RING. A gradient on a stroke colours the stroke
	-- only, so turning it sends one bright highlight round the gold, forever,
	-- for one tween -- the cheapest thing on this HUD that moves.
	local ringColours = function(base: Color3, deep: Color3)
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, deep),
			ColorSequenceKeypoint.new(0.42, base),
			ColorSequenceKeypoint.new(0.5, Theme.PAPER),
			ColorSequenceKeypoint.new(0.58, base),
			ColorSequenceKeypoint.new(1, deep),
		})
	end
	-- THE RING WEARS THE SKIN'S TIER: gold for a legendary, and so on down.
	-- It is `Config.RARITIES[tier].colour`, the same colour the shop's card
	-- border, crate well and odds bar use, so the portrait says the tier in
	-- the one vocabulary the rest of the game already teaches. (It used to
	-- take the skin's body colour, which only repeated the picture inside it.)
	-- An unknown skin keeps gold.
	local ringTone, ringDeep = Theme.GOLD, Theme.GOLD_DEEP
	local function toneFor(key: string?)
		local skin = Config.SKINS[key or Config.DEFAULT_SKIN]
		local rarity = skin and Config.RARITIES[Config.rarityOf(skin)]
		local colour = rarity and rarity.colour
		if typeof(colour) ~= "Color3" then
			return Theme.GOLD, Theme.GOLD_DEEP
		end
		return colour, colour:Lerp(Theme.INK, 0.4)
	end
	-- The default pig never reaches `setSkin`'s paint (its key is nil, the
	-- same as the starting state), so it takes its colours here.
	ringTone, ringDeep = toneFor(nil)
	inner.BackgroundColor3 = Theme.PAPER:Lerp(ringTone, 0.38)
	local sheen = Instance.new("UIGradient")
	sheen.Color = ringColours(Theme.GOLD, Theme.GOLD_DEEP)
	sheen.Parent = ring
	local spin = TweenService:Create(sheen,
		TweenInfo.new(6, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
		{ Rotation = 360 })
	spin:Play()

	buildPig(medal)
	local PIG_SIZE = 116
	local pigBox = UDim2.fromOffset((MEDAL_D - PIG_SIZE) / 2, (MEDAL_D - PIG_SIZE) / 2 + 2)
	local defaultPig = medal:FindFirstChild("Pig") :: GuiObject
	defaultPig.ZIndex = 3
	defaultPig.Position = pigBox
	if defaultPig:IsA("ImageLabel") then
		defaultPig.Size = UDim2.fromOffset(PIG_SIZE, PIG_SIZE)
	else
		-- The drawn fallback is authored at 94; scale it rather than redraw it.
		local s = Instance.new("UIScale")
		s.Scale = PIG_SIZE / 94
		s.Parent = defaultPig
	end

	-- THE PIG IN THE MEDALLION IS THE PIG YOU ARE WEARING. The default art
	-- stays for the default skin; any other skin is painted into this well by
	-- `setSkin`, with ClientMain handing in the shop's own icon builder, so the
	-- HUD and the shop can never show two different pictures of one skin.
	local skinWell = Instance.new("Frame")
	skinWell.Name = "SkinWell"
	skinWell.Position = pigBox
	skinWell.Size = UDim2.fromOffset(PIG_SIZE, PIG_SIZE)
	skinWell.BackgroundTransparency = 1
	skinWell.ZIndex = 3
	skinWell.Visible = false
	-- Flagged so the shop's tier ground is never laid inside it.
	skinWell:SetAttribute("OnTierCard", true)
	-- And flagged ROUND, because this well is a circle rather than a card: the
	-- shop's square framing loses its corners to it, which cut the snout off
	-- an OG pig. `ShopSkinCards` centres and pulls in for a well saying this.
	skinWell:SetAttribute("RoundWell", true)
	skinWell.Parent = medal

	-- Paints the bar and the ring for the full state. WARN rather than GOLD:
	-- gold means money and a bar full of it reads as good news, where the news
	-- is that income has stopped.
	local function paintFull()
		percent.Text = if not isFull
				then ("%s  %s  of %s"):format(shownPercent, utf8.char(0x00B7), shownLimit)
			elseif rateCompact then "FULL"
			else "FULL " .. utf8.char(0x00B7) .. " SPEND SOME"
		fill.BackgroundColor3 = if isFull then Theme.WARN else Theme.GOLD
		status.TextColor3 = if isFull then Theme.WARN_INK else Theme.MUTED
		sheen.Color = if isFull
			then ringColours(Theme.WARN, Theme.STOP)
			else ringColours(ringTone, ringDeep)
	end

	local function layout()
		local metrics = require(script.Parent.HUDLayout).metrics(gui.AbsoluteSize)
		local compact = metrics.compact
		-- A phone drops the ETA line, and the plate and tab close up under it.
		local plateH = if compact then 80 else 94
		local tabY = PLATE_Y + plateH + 6
		local designH = math.max(MEDAL_Y + MEDAL_D, tabY + TAB_H)
		local drawn = (if compact then PiggyPanel.COMPACT_SCALE else 1) * metrics.bankScale
		root.Size = UDim2.fromOffset(DESIGN_W, designH)
		root.Position = UDim2.new(1, -14, 0, metrics.bankTop)
		scale.Scale = drawn
		plate.Size = UDim2.fromOffset(PLATE_W, plateH)
		acorns.Position = UDim2.fromOffset(TAB_X, tabY)
		status.Visible = not compact
		-- Bigger type where the whole panel is drawn at 0.64, so nothing
		-- lands under about 10 pixels on the screen.
		rate.TextSize = if compact then 17 else 14
		percent.TextSize = if compact then 18 else 15
		rateCompact = compact
		paintRate()
		paintFull()
		-- Built later by Wanted. Hung under the panel's drawn bottom, so a
		-- resize can never make the column overlap.
		local chip = gui:FindFirstChild("Wanted")
		if chip and chip:IsA("GuiObject") then
			chip.Position = UDim2.new(1, -14, 0, metrics.bankTop + designH * drawn + 8)
			local chipScale = chip:FindFirstChildOfClass("UIScale")
			if not chipScale then chipScale = Instance.new("UIScale"); chipScale.Parent = chip end
			chipScale.Scale = if compact then 0.75 else 1
		end
	end
	layout()
	local layoutConnection = gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	local childConnection = gui.ChildAdded:Connect(function(child)
		if child.Name == "Wanted" then
			task.defer(layout)
		end
	end)
	local tween: Tween? = nil
	local lastRatio: number? = nil
	root.Destroying:Connect(function()
		layoutConnection:Disconnect()
		childConnection:Disconnect()
		spin:Cancel()
		if tween then tween:Cancel() end
	end)

	local shownSkin: string? = nil

	local controller = {}
	-- Filled in by ClientMain, which owns the shop's icon builder. See `setSkin`.
	controller.paintSkin = nil :: any
	controller.showWorn = nil :: any
	function controller:setSkin(key: string?, paint: ((string, Frame) -> ())?, force: boolean?)
		if not key or key == Config.DEFAULT_SKIN or not paint then
			key = nil
		end
		if key == shownSkin and not force then
			return
		end
		shownSkin = key
		skinWell:ClearAllChildren()
		if key and paint then
			local ok = pcall(paint, key, skinWell)
			-- Anything the painter lays under the picture is the shop's card
			-- dressing, not the pig.
			for _, name in ipairs({ "TierBackdrop", "Spotlight" }) do
				local extra = skinWell:FindFirstChild(name)
				if extra then extra:Destroy() end
			end
			if not ok or #skinWell:GetChildren() == 0 then
				key = nil
			end
		end
		skinWell.Visible = key ~= nil
		defaultPig.Visible = key == nil
		ringTone, ringDeep = toneFor(key)
		inner.BackgroundColor3 = Theme.PAPER:Lerp(ringTone, 0.38)
		paintFull()
	end
	function controller:setAcorns(amount: number)
		local balance = math.max(0, math.floor(amount))
		acornCount.Text = Config.formatCoins(balance)
		acorns:SetAttribute("Balance", balance)
	end
	function controller:render(state: any)
		local balance = math.max(0, state.coins or 0)
		local limit = math.max(0, state.capacity or 0)
		local income = math.max(0, state.rate or 0)
		local ratio = if limit > 0 then math.clamp(balance / limit, 0, 1) else 0
		local full = state.full == true or (limit > 0 and balance >= limit)
		coins.Text = Config.formatCoins(balance)
		capacity.Text = "/ " .. Config.formatCoins(limit)
		shownLimit = Config.formatCoins(limit)
		shownIncome = income
		boostMult = math.max(1, state.boostMultiplier or 1)
		boostLeft = math.max(0, math.floor(state.boostLeft or 0))
		paintRate()
		-- A nearly full pig must never claim 100% before accrual stops.
		shownPercent = if full then "100%" else ("%d%%"):format(math.floor(ratio * 100))
		isFull = full
		paintFull()
		if full then
			-- The bar already says FULL, so this line is the instruction.
			status.Text = "Spend some coins to start earning again"
		elseif income > 0 and limit > balance then
			local seconds = math.ceil((limit - balance) / income)
			status.Text = if seconds >= 3600
				then ("Full in %dh %02dm"):format(seconds // 3600, (seconds % 3600) // 60)
				else ("Full in %dm %02ds"):format(seconds // 60, seconds % 60)
		else
			status.Text = "Income paused"
		end
		if lastRatio ~= ratio then
			if tween then tween:Cancel() end
			fill.Visible = ratio > 0
			highlight.Visible = ratio >= 0.08
			-- Initial hydration is immediate; later earning/spending animates.
			if lastRatio == nil then
				fill.Size = UDim2.fromScale(ratio, 1)
			else
				tween = TweenService:Create(fill,
					TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Size = UDim2.fromScale(ratio, 1) })
				tween:Play()
			end
			lastRatio = ratio
		end
	end
	return controller
end

return PiggyPanel
