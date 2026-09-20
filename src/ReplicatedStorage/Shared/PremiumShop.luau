--!strict
--[[
	PremiumShop -- the Robux tab.

	WHAT IS SOLD HERE IS THE RULE, SO IT IS SAID FIRST. Coins are never sold
	for Robux (CLAUDE.md, MASTER-PLAN 19.1): every product is a NAMED thing --
	a pass that grants specific skins, a catch effect, a sign word, a riding
	pose -- and nothing here grants currency, a rate or a random outcome. The
	tab's subtitle says so in words a parent can read, because it is the
	question a parent asks.

	ONE LARGE CARD PER PASS, AND THE CARD SHOWS WHAT ARRIVES. The contents
	come from `Config.passItems`, the same sweep `PassService` grants from, so
	a card can never advertise something the grant does not hand over. The
	Starter and Style packs also give the entry ride to a player with none,
	which the card shows because it is part of the purchase.

	A PASS WITH NO ID READS COMING SOON. `PassService.idOf` is nil until the
	pass exists on the Creator Dashboard, and prompting a purchase for id 0
	throws -- so the button declines to ask rather than failing silently.

	A MODULE for the reason Crates, HotBar and SpinWheel are: `ClientMain` is
	at Luau's 200-local ceiling, and a function body has its own registers.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local ShopStyle = require(ReplicatedStorage.Shared.ShopStyle)
local Theme = require(ReplicatedStorage.Shared.Theme)

local PremiumShop = {}

-- Roblox's own Robux mark, shipped with every client, so there is no upload
-- to be moderated and no second drawing of a trademark to get wrong.
PremiumShop.ROBUX_ICON = "rbxasset://textures/ui/common/robux.png"

-- Each pass wears its own colour so three cards read as three things.
-- A pass added to Config with no row here falls back to the tab's colour.
local HUES = {
	vip = Color3.fromRGB(255, 190, 38),
	starterPack = Color3.fromRGB(101, 207, 53),
	stylePack = Color3.fromRGB(250, 98, 140),
}

local CARD_H, CARD_H_COMPACT = 236, 196
-- The Style Pack card: its words take STYLE_TOP, then the style strip.
local STYLE_TOP, STYLE_STRIP, STYLE_STRIP_COMPACT = 128, 210, 170

local function text(parent: Instance, name: string, value: string, size: number, font: Enum.Font?): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Font = font or Enum.Font.FredokaOne
	t.TextSize = size
	t.TextColor3 = ShopStyle.TEXT
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextYAlignment = Enum.TextYAlignment.Top
	t.TextWrapped = true
	t.Text = value
	t.Parent = parent
	return t
end

local function frame(parent: Instance, name: string, colour: Color3?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour or Theme.PAPER
	f.BackgroundTransparency = if colour then 0 else 1
	f.Parent = parent
	return f
end

-- What a pass hands over, as preview entries: its catalogue items, plus the
-- entry ride it grants to somebody who owns none.
local function contents(passKey: string): { { kind: string, key: string, name: string } }
	local out = {}
	for _, entry in ipairs(Config.passItems(passKey)) do
		local catalogue = Config.catalogueFor(entry.kind)
		local spec = catalogue and catalogue[entry.key]
		local name = (spec and spec.name) or entry.key
		-- A nab effect is named as one, or "Paparazzi" on a pass card reads as
		-- a person rather than as the thing that happens to a thief you catch.
		if entry.kind == "catch" then
			name ..= " nab effect"
		end
		table.insert(out, { kind = entry.kind, key = entry.key, name = name })
	end
	local pass = Config.PASSES[passKey]
	if pass and pass.entryRide and Config.RIDES[pass.entryRide] then
		table.insert(out, { kind = "ride", key = pass.entryRide,
			name = Config.RIDES[pass.entryRide].name .. " (if you have no ride)" })
	end
	-- Things with a picture first: the skin leads the card, a catch effect
	-- (which has no model) comes last.
	local rank = { skin = 1, accessory = 2, decor = 3, ride = 4, catch = 9 }
	table.sort(out, function(a, b)
		return (rank[a.kind] or 5) < (rank[b.kind] or 5)
	end)
	return out
end

-- The extra lines a pass carries that are not catalogue items.
local function perks(passKey: string): { string }
	local pass = Config.PASSES[passKey]
	local out = {}
	if pass and pass.signStyle == "vip" then
		table.insert(out, "A golden signpost with your name in lights")
	end
	if passKey == "stylePack" then
		table.insert(out, "A second riding pose for every ride")
	end
	return out
end

function PremiumShop.new(view: Frame, deps: any): any
	local self = { view = view, deps = deps, cards = {}, latest = nil, onFeatured = nil } :: any

	local head = text(view, "Heading", "Robux Shop", 24)
	head.Size = UDim2.new(1, -8, 0, 30)
	head.Position = UDim2.fromOffset(4, 0)
	-- Robux, and what Robux does NOT buy here. Full ink: this is the one
	-- sentence on the tab that matters to the adult paying.
	local rule = text(view, "Rule",
		"Bought with Robux, not coins. Named things only: no coins, no boosts, "
			.. "and nothing that makes anybody faster or richer.", 13, Enum.Font.GothamMedium)
	rule.Size = UDim2.new(1, -8, 0, 34)
	rule.Position = UDim2.fromOffset(4, 30)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Offers"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Position = UDim2.fromOffset(0, 70)
	scroll.Size = UDim2.new(1, 0, 1, -70)
	scroll.Parent = view
	-- An outside stroke draws into the region a ScrollingFrame clips.
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 5)
	pad.PaddingRight = UDim.new(0, 8)
	pad.PaddingTop = UDim.new(0, 5)
	pad.PaddingBottom = UDim.new(0, 8)
	pad.Parent = scroll
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 14)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll
	self.scroll = scroll

	scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		PremiumShop.layout(self)
	end)
	return setmetatable(self, { __index = PremiumShop })
end

-- ============================================================
-- THE STYLE PACK CAROUSEL
-- ============================================================
--
-- The pack sells a POSE, and a pose is the one thing a still picture of a ride
-- cannot show. So its card plays the real thing: a strip of style cards, one
-- per Style Pack stance, each a copy of the player's own avatar on that ride
-- easing into its trick and back, three on screen and sliding left on a loop. Built from the same pieces the street uses -- `RideModel`
-- for the machine, `RidePose.apply`/`setPhase` for the rider, and the mount
-- and trick transforms `RideService` welds and tweens -- so the preview cannot
-- promise a pose the ride does not do.
local RideModel = require(ReplicatedStorage.Shared.RideModel)
local RidePose = require(ReplicatedStorage.Shared.RidePose)

-- R15 root half-height; the hip is read off the rig itself.
local ROOT_HALF = 1.0

-- Every Style Pack style: one per (ride, stance), in ride order.
local function styleList(): { any }
	local rides = {}
	for key, ride in pairs(Config.RIDES) do
		if ride.style then table.insert(rides, { key = key, ride = ride }) end
	end
	table.sort(rides, function(a, b) return (a.ride.order or 0) < (b.ride.order or 0) end)
	local out = {}
	for _, r in ipairs(rides) do
		for _, stance in ipairs(RidePose.stances(r.ride.style)) do
			if stance.key ~= "" then
				table.insert(out, { rideKey = r.key, ride = r.ride, stance = stance.key,
					name = stance.name, rideName = r.ride.name })
			end
		end
	end
	return out
end

-- A posable copy of the local player: their own look, nothing that runs.
local function riderRig(): Model?
	local character = Players.LocalPlayer.Character
	if not character or not character:FindFirstChildOfClass("Humanoid") then
		return nil
	end
	local was = character.Archivable
	character.Archivable = true
	local ok, copy = pcall(function() return character:Clone() end)
	character.Archivable = was
	if not ok or not copy then
		return nil
	end
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("BillboardGui") or d:IsA("Sound")
			or d:IsA("ForceField") or d:IsA("Tool") or d:IsA("Highlight")
			or (d:IsA("Model") and string.sub(d.Name, 1, 5) == "Ride_") then
			d:Destroy()
		end
	end
	local humanoid = copy:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	for _, track in ipairs((animator :: Animator):GetPlayingAnimationTracks()) do
		track:Stop(0)
	end
	local root = copy:FindFirstChild("HumanoidRootPart") :: BasePart
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = d == root end
	end
	return copy
end

-- Where a ride sits under a rider at the origin, tipped `phase` of the way
-- through its trick: RideService's own mount (the floor under the root with
-- the stand height added, turned half round because a character faces -Z,
-- back by the stance angle) and its own trick tween (about the rear contact
-- patch).
local function rideCFrame(root: CFrame, hip: number, ride: any, phase: number): CFrame
	local at = root * CFrame.new(0, -(hip + (ride.stand or 0) + ROOT_HALF), 0)
		* CFrame.Angles(0, math.pi - math.rad(ride.bodyYaw or 0), 0)
	if ride.trick and phase > 0 then
		local pivot = ride.trick.pivot or 0
		at = at * CFrame.new(0, 0, pivot) * CFrame.Angles(-math.rad(ride.trick.pitch) * phase, 0, 0)
			* CFrame.new(0, 0, -pivot)
	end
	return at
end

-- One style card: the rider on the ride in that stance, easing into the
-- trick and back if the ride has one. Built lazily, because the rig is a copy
-- of the player's character and there may not be one yet.
local function styleCard(parent: Instance, hue: Color3, style: any): any
	local card = frame(parent, "Style_" .. style.rideKey .. "_" .. style.stance, hue:Lerp(Theme.PAPER, 0.55))
	ShopStyle.round(card, 14)
	ShopStyle.outline(card, 3)

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Pose"
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.new(1, 0, 1, -30)
	viewport.Ambient = Color3.fromRGB(190, 180, 170)
	viewport.LightColor = Color3.fromRGB(255, 250, 240)
	viewport.LightDirection = Vector3.new(-0.5, -1, -0.6)
	viewport.Parent = card
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 34
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local caption = text(card, "Caption", ("%s %s %s"):format(style.rideName, utf8.char(0x00B7), style.name), 14)
	caption.AnchorPoint = Vector2.new(0.5, 1)
	caption.Position = UDim2.new(0.5, 0, 1, -6)
	caption.Size = UDim2.new(1, -12, 0, 20)
	caption.TextXAlignment = Enum.TextXAlignment.Center
	caption.TextWrapped = false
	caption.TextTruncate = Enum.TextTruncate.AtEnd

	local state = { card = card, rig = nil :: Model?, ride = nil :: Model?, phase = 0,
		rootBase = nil :: CFrame?, camBase = nil :: CFrame? }
	local key = RidePose.key(style.ride.style, style.stance)

	function state.build(): boolean
		if state.rig then return true end
		local rig = riderRig()
		if not rig then return false end
		local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart
		-- Turned by the stance angle, the way the client turns a real root
		-- for the rides ridden sideways.
		root.CFrame = CFrame.Angles(0, math.rad(style.ride.bodyYaw or 0), 0)
		state.rootBase = root.CFrame
		rig.Parent = world
		local ok, model = pcall(RideModel.build, style.rideKey)
		if ok and model then
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then d.Anchored = true end
				if d:IsA("Trail") then d:Destroy() end
			end
			model.Parent = world
			state.ride = model
		end
		state.rig = rig
		local humanoid = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
		RidePose.apply(humanoid:FindFirstChildOfClass("Animator") :: Animator, key)
		-- FRAMED ON WHAT IS ACTUALLY THERE, not on a fixed point: a handstand
		-- on the hoverboard is two studs taller than a seated bike, and a fixed
		-- camera cut its legs off. The pose settles over a frame or two, so it
		-- is measured after a beat, at both ends of the trick, and the camera
		-- is fitted to a sphere round all of it -- from three-quarter on the
		-- rider's left, more side than front, which is where a wheelie reads.
		state.setPhase(0)
		task.delay(0.25, function()
			if not state.rig then return end
			local lo, hi = Vector3.new(math.huge, math.huge, math.huge), -Vector3.new(math.huge, math.huge, math.huge)
			-- Points come back in the phase-0 frame: at any other phase the
			-- rider has been moved by the inverse of the trick (see setPhase),
			-- so the trick is put back on to measure where it really reaches.
			local function take()
				local undo = state.delta(state.phase)
				for _, holder in ipairs({ state.rig, state.ride }) do
					for _, d in ipairs(holder and holder:GetDescendants() or {}) do
						if d:IsA("BasePart") and d.Transparency < 1 and d.Name ~= "HumanoidRootPart" then
							local half = d.Size / 2
							for _, sx in ipairs({ -1, 1 }) do for _, sy in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do
								local p = undo * d.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
								lo, hi = lo:Min(p), hi:Max(p)
							end end end
						end
					end
				end
			end
			take()
			if style.ride.trick then
				state.setPhase(1)
				task.wait(0.15)
				take()
				state.setPhase(0)
			end
			local centre = (lo + hi) / 2
			local radius = (hi - lo).Magnitude / 2
			local distance = radius / math.sin(math.rad(camera.FieldOfView / 2)) * 0.9
			state.camBase = CFrame.lookAt(centre + Vector3.new(-8.6, 2.6, -6.4).Unit * distance, centre)
			state.setPhase(state.phase)
		end)
		return true
	end

	-- How far the trick has turned the ride away from where it rests.
	function state.delta(phase: number): CFrame
		local rig = state.rig
		if not rig or not state.rootBase or not style.ride.trick or phase <= 0 then
			return CFrame.identity
		end
		local hip = (rig:FindFirstChildOfClass("Humanoid") :: Humanoid).HipHeight
		local base = state.rootBase :: CFrame
		return rideCFrame(base, hip, style.ride, phase) * rideCFrame(base, hip, style.ride, 0):Inverse()
	end

	-- THE RIDE NEVER MOVES; THE RIDER AND THE CAMERA DO. Pivoting a
	-- 70-part ride every tick in a ViewportFrame made it drop out of the
	-- picture for a frame -- the whole machine vanishing under a rider who
	-- stayed put. Tipping the ride by D is the same picture as leaving it
	-- where it is and moving everything else by D's inverse, and a rider's
	-- root moving is something a viewport already redraws every frame.
	function state.setPhase(phase: number)
		local rig = state.rig
		if not rig then return end
		state.phase = phase
		local humanoid = rig:FindFirstChildOfClass("Humanoid") :: Humanoid
		RidePose.setPhase(humanoid:FindFirstChildOfClass("Animator") :: Animator, key, phase)
		local inverse = state.delta(phase):Inverse()
		local root = rig:FindFirstChild("HumanoidRootPart") :: BasePart
		if state.rootBase then
			root.CFrame = inverse * (state.rootBase :: CFrame)
		end
		if state.ride and not state.ride:GetAttribute("Seated") then
			state.ride:PivotTo(rideCFrame(root.CFrame, humanoid.HipHeight, style.ride, 0))
			state.ride:SetAttribute("Seated", true)
		end
		if state.camBase then
			camera.CFrame = inverse * (state.camBase :: CFrame)
		end
	end

	return state
end

local STRIP_STEP = 2.6 -- seconds each position holds before the strip slides
local SLIDE_TIME = 0.55
local TRICK_EVERY = 1.6 -- a card with a trick goes up and back this often
local VISIBLE = 3
-- A card's outline is drawn OUTSIDE it and the track clips, so every card sits
-- this far in from the track's edges or its border is cut off.
local EDGE = 4
local ARROW_W = 34
local DRAG_START = 8 -- pixels a finger moves before it counts as a swipe

-- The Style Pack strip: one card per style, three on screen, sliding one to
-- the left every STRIP_STEP and looping. A card leaving at the left wraps to
-- the back of the queue off the right edge, so five cards are enough for a
-- seamless loop of three.
--
-- THE PLAYER CAN TAKE IT OVER: a swipe drags it and an arrow either side steps
-- it one card. The moment they do, it stops sliding on its own -- a strip that
-- moves under a finger that is trying to read it is fighting the reader --
-- and it only starts again once the shop has been closed and reopened.
local function buildStyleStrip(strip: Frame, hue: Color3)
	strip.ClipsDescendants = false
	local track = frame(strip, "Track")
	track.Position = UDim2.fromOffset(ARROW_W + 6, 0)
	track.Size = UDim2.new(1, -2 * (ARROW_W + 6), 1, 0)
	track.ClipsDescendants = true
	track.Active = true

	local styles = styleList()
	local cards = {}
	for i, style in ipairs(styles) do
		cards[i] = styleCard(track, hue, style)
	end
	local n = #cards
	if n == 0 then return end
	local offset = 0
	local gap = 10
	local manual = false
	local moving = 0 -- bumps each time a slide starts, so an older one stops

	local function place()
		local width = track.AbsoluteSize.X - 2 * EDGE
		local slotW = (width + gap) / VISIBLE
		for i, c in ipairs(cards) do
			-- Slots run from -1 (off the left) to n-1 (queued off the right).
			local slot = if n > VISIBLE then ((i - 1 - offset + 1) % n) - 1 else i - 1
			c.card.Position = UDim2.fromOffset(EDGE + math.floor(slot * slotW), EDGE)
			c.card.Size = UDim2.new(0, math.floor(slotW - gap), 1, -2 * EDGE)
		end
	end
	track:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
	place()

	-- Eases the strip from where it is to `target`, then settles the offset
	-- back into 0..n so it never drifts.
	local function slideTo(target: number)
		moving += 1
		local mine = moving
		local start = offset
		local t0 = os.clock()
		while os.clock() - t0 < SLIDE_TIME do
			if moving ~= mine then return end
			local t = (os.clock() - t0) / SLIDE_TIME
			offset = start + (target - start) * (t * t * (3 - 2 * t))
			place()
			task.wait()
		end
		if moving ~= mine then return end
		offset = target % n
		place()
	end

	-- THE ARROWS: outside the track, so they never sit on top of a card.
	local function arrow(name: string, glyph: string, side: number): TextButton
		local b = Instance.new("TextButton")
		b.Name = name
		b.AutoButtonColor = true
		b.BackgroundColor3 = Theme.PAPER
		b.AnchorPoint = Vector2.new(if side < 0 then 0 else 1, 0.5)
		b.Position = UDim2.new(if side < 0 then 0 else 1, if side < 0 then 3 else -3, 0.5, 0)
		b.Size = UDim2.fromOffset(ARROW_W, ARROW_W + 14)
		b.Font = Enum.Font.FredokaOne
		b.Text = glyph
		b.TextSize = 30
		b.TextColor3 = ShopStyle.TEXT
		b.Parent = strip
		ShopStyle.round(b, 10)
		ShopStyle.outline(b, 3)
		b.Activated:Connect(function()
			if n <= VISIBLE then return end
			manual = true
			task.spawn(slideTo, math.round(offset) + side)
		end)
		return b
	end
	local left = arrow("Prev", utf8.char(0x2039), -1)
	local right = arrow("Next", utf8.char(0x203A), 1)
	left.Visible, right.Visible = n > VISIBLE, n > VISIBLE

	-- THE SWIPE: the strip follows the finger, then snaps to the nearest card.
	-- A mostly-vertical drag is left alone, so the shop page still scrolls; a
	-- horizontal one locks the page while it lasts.
	local page = strip:FindFirstAncestorWhichIsA("ScrollingFrame")
	track.InputBegan:Connect(function(input: InputObject)
		if n <= VISIBLE then return end
		local touch = input.UserInputType == Enum.UserInputType.Touch
		if not touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end
		local from = Vector2.new(input.Position.X, input.Position.Y)
		local startOffset = offset
		local swiping = false
		local done = false
		local slotW = math.max(1, (track.AbsoluteSize.X - 2 * EDGE + gap) / VISIBLE)
		local moved: RBXScriptConnection? = nil
		local ended: RBXScriptConnection? = nil
		local function finish()
			if done then return end
			done = true
			if moved then moved:Disconnect() end
			if ended then ended:Disconnect() end
			if page then page.ScrollingEnabled = true end
			if swiping then
				task.spawn(slideTo, math.round(offset))
			end
		end
		moved = UserInputService.InputChanged:Connect(function(change: InputObject)
			if touch then
				if change ~= input then return end
			elseif change.UserInputType ~= Enum.UserInputType.MouseMovement then
				return
			end
			local d = Vector2.new(change.Position.X, change.Position.Y) - from
			if not swiping then
				if math.abs(d.Y) > DRAG_START and math.abs(d.Y) >= math.abs(d.X) then
					finish() -- a scroll of the page, not of the strip
					return
				end
				if math.abs(d.X) < DRAG_START then return end
				swiping = true
				manual = true
				moving += 1 -- stop any slide in flight
				if page then page.ScrollingEnabled = false end
			end
			offset = startOffset - d.X / slotW
			place()
		end)
		ended = UserInputService.InputEnded:Connect(function(change: InputObject)
			if change == input or change.UserInputType == input.UserInputType then
				finish()
			end
		end)
	end)

	local function onScreen(): boolean
		local node: Instance? = strip
		while node and node:IsA("GuiObject") do
			if not (node :: GuiObject).Visible then return false end
			node = node.Parent
		end
		return node ~= nil and strip.AbsoluteSize.X > 0
	end

	-- Tricks: every card with one eases up and back, in turn.
	task.spawn(function()
		local up = false
		while strip.Parent do
			if onScreen() then
				for _, c in ipairs(cards) do c.build() end
				up = not up
				local from, to = if up then 0 else 1, if up then 1 else 0
				for step = 1, 8 do
					local t = step / 8
					local eased = t * t * (3 - 2 * t)
					for i, c in ipairs(cards) do
						if styles[i].ride.trick then
							c.setPhase(from + (to - from) * eased)
						end
					end
					task.wait(0.03)
				end
			end
			task.wait(TRICK_EVERY)
		end
	end)

	-- The slide: one card left every STRIP_STEP, eased, looping -- until the
	-- player takes over. Hiding the shop hands it back.
	if n > VISIBLE then
		task.spawn(function()
			local idle = 0
			while strip.Parent do
				task.wait(0.2)
				if not onScreen() then
					manual = false
					idle = 0
				elseif manual then
					idle = 0
				else
					idle += 0.2
					if idle >= STRIP_STEP then
						idle = 0
						slideTo(math.round(offset) + 1)
					end
				end
			end
		end)
	end
end

local function buildCard(self: any, passKey: string): any
	local hue = HUES[passKey] or Theme.GOLD
	local card = frame(self.scroll, "Pass_" .. passKey, hue:Lerp(Theme.PAPER, 0.84))
	card.Size = UDim2.new(1, 0, 0, CARD_H)
	ShopStyle.round(card, 18)
	ShopStyle.outline(card, 4, hue)
	ShopStyle.gloss(card)

	-- THE ART: what you get, big, on the pass's own colour.
	local art = frame(card, "Contents", hue)
	art.Position = UDim2.fromOffset(12, 12)
	art.Size = UDim2.new(0.44, -12, 1, -24)
	ShopStyle.round(art, 14)
	ShopStyle.outline(art, 3)
	local wells = frame(art, "Wells")
	wells.Position = UDim2.fromOffset(10, 10)
	wells.Size = UDim2.new(1, -20, 1, -20)
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.HorizontalAlignment = Enum.HorizontalAlignment.Center
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 8)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = wells

	local items = contents(passKey)
	-- The Style Pack sells a pose, so its card is a different shape: the words
	-- across the top and a full-width strip of style cards underneath, rather
	-- than a still of the skateboard it also happens to include.
	local carousel = passKey == "stylePack"
	if carousel then
		wells.Visible = false
		art.Position = UDim2.fromOffset(12, STYLE_TOP)
		art.Size = UDim2.new(1, -24, 1, -STYLE_TOP - 12)
		art.BackgroundTransparency = 1
		local artEdge = art:FindFirstChildOfClass("UIStroke")
		if artEdge then artEdge.Enabled = false end
		buildStyleStrip(art, hue)
	end
	local shown = if carousel then 0 else math.max(1, math.min(#items, 3))
	for i = 1, shown do
		local entry = items[i]
		local well = frame(wells, "Well" .. i, hue:Lerp(Theme.PAPER, 0.55))
		well.LayoutOrder = i
		well.Size = UDim2.new(1 / shown, -8 * (shown - 1) / shown, 1, 0)
		well.ClipsDescendants = true
		ShopStyle.round(well, 12)
		ShopStyle.outline(well, 2)
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.AspectRatio = 1
		aspect.Parent = well
		if entry then
			-- A catch effect is something that happens to a thief, not an object,
			-- so it has no model to render and gets its name on a sparkle.
			-- Asked by KIND rather than by counting what `iconFor` left in the
			-- well: it now lays a tier backdrop first, so a well can hold
			-- children and still show nothing.
			-- A catch effect gets its own simulated burst from `iconFor`, the
			-- one its shop card shows; the sparkle below is only a fallback.
			local modelled = self.deps.iconFor ~= nil
			if modelled then
				modelled = pcall(self.deps.iconFor, entry.kind, entry.key, well)
			end
			if not modelled then
				-- A catch effect has no model; its name on the colour says it.
				local glyph = text(well, "Glyph", utf8.char(0x2728), 34)
				glyph.Size = UDim2.fromScale(1, 0.6)
				glyph.TextXAlignment = Enum.TextXAlignment.Center
				glyph.TextYAlignment = Enum.TextYAlignment.Center
				local name = text(well, "Name", entry.name, 12)
				name.Position = UDim2.fromScale(0, 0.58)
				name.Size = UDim2.new(1, 0, 0.4, 0)
				name.TextXAlignment = Enum.TextXAlignment.Center
			end
		end
	end

	-- THE WORDS: name, blurb, and the itemised list of what arrives.
	local side = frame(card, "Details")
	side.Position = if carousel then UDim2.fromOffset(12, 12) else UDim2.new(0.44, 12, 0, 12)
	side.Size = if carousel then UDim2.new(1, -24, 0, STYLE_TOP - 22) else UDim2.new(0.56, -24, 1, -24)
	local title = text(side, "Title", Config.PASSES[passKey].name or passKey, 30)
	title.Size = UDim2.new(1, 0, 0, 34)
	title.TextWrapped = false
	title.TextTruncate = Enum.TextTruncate.AtEnd
	local blurb = text(side, "Blurb", Config.PASSES[passKey].blurb or "", 14, Enum.Font.GothamMedium)
	blurb.Position = UDim2.fromOffset(0, 36)
	blurb.Size = UDim2.new(1, 0, 0, 36)
	local lines = {}
	for _, entry in ipairs(items) do
		table.insert(lines, utf8.char(0x2713) .. " " .. entry.name)
	end
	for _, perk in ipairs(perks(passKey)) do
		table.insert(lines, utf8.char(0x2713) .. " " .. perk)
	end
	local includes = text(side, "Includes", table.concat(lines, utf8.char(10)), 13, Enum.Font.GothamBold)
	includes.Position = UDim2.fromOffset(0, 76)
	includes.Size = if carousel then UDim2.new(0.66, 0, 1, -76) else UDim2.new(1, 0, 1, -76 - 54)
	includes.TextTruncate = Enum.TextTruncate.AtEnd

	-- THE BUTTON: Robux mark and price, or OWNED, or COMING SOON.
	local buy = Instance.new("TextButton")
	buy.Name = "Buy"
	buy.AnchorPoint = Vector2.new(1, 1)
	buy.Position = UDim2.new(1, 0, 1, 0)
	buy.Size = if carousel then UDim2.new(0.3, 0, 0, 46) else UDim2.new(0.62, 0, 0, 46)
	buy.BackgroundColor3 = ShopStyle.BUY
	buy.BorderSizePixel = 0
	buy.AutoButtonColor = true
	buy.Text = ""
	buy.Parent = side
	ShopStyle.round(buy, 14)
	ShopStyle.outline(buy, 3)
	ShopStyle.gloss(buy)
	local mark = Instance.new("ImageLabel")
	mark.Name = "Robux"
	mark.BackgroundTransparency = 1
	mark.Image = PremiumShop.ROBUX_ICON
	mark.ImageColor3 = Theme.INK
	mark.ScaleType = Enum.ScaleType.Fit
	mark.Size = UDim2.fromOffset(24, 24)
	mark.Position = UDim2.new(0, 14, 0.5, -12)
	mark.Parent = buy
	local price = text(buy, "Price", "", 20)
	price.TextXAlignment = Enum.TextXAlignment.Center
	price.TextYAlignment = Enum.TextYAlignment.Center
	price.TextWrapped = false
	price.Size = UDim2.new(1, -44, 1, 0)
	price.Position = UDim2.fromOffset(40, 0)

	local ui = { card = card, buy = buy, mark = mark, price = price, id = nil :: number?, title = title,
		blurb = blurb, includes = includes, art = art, strip = carousel }
	buy.Activated:Connect(function()
		-- The client declines to ask for a known no: an owned pass has
		-- nothing to buy, and prompting for a pass that does not exist throws.
		if ui.id then
			MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, ui.id)
		end
	end)
	return ui
end

function PremiumShop.render(self: any, list: { any }?)
	if list then
		self.latest = list
	end
	list = self.latest
	if not list then
		return
	end
	local featured = nil
	for order, info in ipairs(list) do
		if Config.PASSES[info.key] then
			local ui = self.cards[info.key]
			if not ui then
				ui = buildCard(self, info.key)
				self.cards[info.key] = ui
			end
			ui.card.LayoutOrder = order
			if info.owned then
				ui.id = nil
				ui.price.Text = "OWNED"
				ui.mark.Visible = false
				ui.price.Position = UDim2.new()
				ui.price.Size = UDim2.fromScale(1, 1)
				ui.buy.BackgroundColor3 = ShopStyle.OWNED
				ui.buy.AutoButtonColor = false
			elseif info.id then
				ui.id = info.id
				ui.price.Text = tostring(info.robux or 0)
				ui.mark.Visible = true
				ui.price.Position = UDim2.fromOffset(40, 0)
				ui.price.Size = UDim2.new(1, -44, 1, 0)
				ui.buy.BackgroundColor3 = ShopStyle.BUY
				ui.buy.AutoButtonColor = true
			else
				ui.id = nil
				ui.price.Text = "COMING SOON"
				ui.mark.Visible = false
				ui.price.Position = UDim2.new()
				ui.price.Size = UDim2.fromScale(1, 1)
				ui.buy.BackgroundColor3 = ShopStyle.DEAR
				ui.buy.AutoButtonColor = false
			end
			if not info.owned and not featured then
				featured = info
			end
		end
	end
	PremiumShop.layout(self)
	if self.onFeatured then
		self.onFeatured(featured)
	end
end

-- A phone held sideways gets shorter cards and smaller type, never a second
-- layout.
function PremiumShop.layout(self: any)
	local compact = self.scroll.AbsoluteSize.X < 640 or self.scroll.AbsoluteSize.Y < 330
	for _, ui in pairs(self.cards) do
		ui.card.Size = UDim2.new(1, 0, 0, if ui.strip
			then STYLE_TOP + (if compact then STYLE_STRIP_COMPACT else STYLE_STRIP) + 12
			else (if compact then CARD_H_COMPACT else CARD_H))
		ui.title.TextSize = if compact then 22 else 30
		ui.blurb.TextSize = if compact then 12 else 14
		ui.includes.TextSize = if compact then 11 else 13
	end
end

return PremiumShop
