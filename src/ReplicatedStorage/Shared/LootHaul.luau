--!strict
--[[
	LootHaul

	THE THREE MOMENTS A ROBBERY HAS THAT THE HUD NEVER DREW.

	  1. THE GRAB. A cosmetic came out of a pig. This pops a card in the
	     middle of the screen with the real item rendered in it, plays a
	     sting, and gets out of the way.
	  2. THE CARRY. It is not yours yet. A chip sits above the satchel for as
	     long as you are holding it, which is what the carry banner already
	     does for the coins and is the half that makes the getaway mean
	     something.
	  3. THE DELIVERY. The coins stream into the ACTUAL PIG on the lawn one by
	     one -- more of them the bigger the haul -- then each stolen item gets
	     a reveal and flies to the bag, and a summary screen names the lot.
	     See `rushCoins`, `revealItem` and `Config.BANK_RUSH`.

	NONE OF IT INTERRUPTS, and that is the constraint the whole file is built
	against rather than a nicety. Every one of these lands while the player is
	RUNNING, usually with a dog behind them: the grab card arrives mid-sprint
	and the summary arrives at the moment they are deciding where to go next.
	So nothing DURING the robbery is modal. The two exceptions are both at the
	END of one, on the player's own lawn: the item reveal (a tap skips it)
	and the summary screen (a tap closes it, and it closes itself).

	`Active = false` on every frame is what enforces that. A Frame with
	`Active` true swallows clicks under it, which on a touchscreen is the
	difference between a card you can ignore and a card that eats the tap you
	meant for the hot bar.

	A MODULE, AND THAT IS THE 200-LOCAL CEILING RATHER THAN TASTE. ClientMain
	is one chunk against Luau's per-function register limit and this feature
	wants a dozen locals; written inline it would not cost the feature, it
	would cost the ENTIRE HUD, which is the failure that file has now recorded
	nine times. `require(...).start(...)` is one statement holding no local.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SoundKit = require(ReplicatedStorage.Shared.SoundKit)
local Theme = require(ReplicatedStorage.Shared.Theme)

local CarryDelivery = require(ReplicatedStorage.Shared.CarryDelivery)
local CoinModel = require(ReplicatedStorage.Shared.CoinModel)

local LootHaul = {}

-- HOW LONG EACH BEAT LASTS, read against what is happening on screen while it
-- runs: the grab card is on during a getaway, so it is short, and the summary
-- is on while the player is standing safely on their own plot, so it can
-- afford to be seen.
local POP_IN = 0.28
local POP_HOLD = 1.9
local POP_AWAY = 0.42
local FLY = 0.55

-- One tile size, so a grab card and a summary tile are the same object at two
-- scales rather than two designs that drift.
local TILE = 96

local function tween(inst: Instance, time: number, props: { [string]: any },
	style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(inst,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props)
	t:Play()
	return t
end

-- WHAT AN ITEM IS CALLED AND HOW RARE IT IS, resolved on the client from
-- `{kind, key}` alone.
--
-- The server sends the pair and nothing else, which is the split every other
-- push in this game makes: it owns WHAT happened and the client owns how it
-- looks. It also means a stolen skin needs no new field anywhere to be drawn
-- as the actual pig, because `Config.catalogueFor` already resolves all five
-- catalogues and `iconFor` already builds any of them.
local function describe(kind: string, key: string): (string, Color3)
	local catalogue = Config.catalogueFor(kind)
	local spec = catalogue and catalogue[key]
	if not spec then
		-- A kind or key this client does not know. NAMED RATHER THAN SKIPPED:
		-- an item the player earned and cannot see is the silent failure this
		-- project refuses above all others, and a tile carrying the raw key
		-- at least says something arrived.
		return key, Config.RARITIES.common.colour
	end
	local band = Config.RARITIES[Config.rarityOf(spec)] or Config.RARITIES.common
	return spec.name or key, band.colour
end

-- One item, drawn. The well is SUNK and the edge is the RARITY, which is the
-- vocabulary every shop card, crate card and inventory tile already speaks --
-- so a legendary skin looks the same here as everywhere else the player has
-- already met one.
local function buildTile(parent: Instance, kind: string, key: string,
	size: number, iconFor: ((string, string, Frame) -> ())?): Frame
	local name, tone = describe(kind, key)

	local tile = Instance.new("Frame")
	tile.Name = "LootTile"
	tile.Size = UDim2.fromOffset(size, size)
	tile.BackgroundColor3 = Theme.SLAB_DEEP
	tile.BorderSizePixel = 0
	tile.Active = false
	tile.Parent = parent
	Theme.corner(tile, 12)
	Theme.outline(tile, 3, tone)

	local well = Instance.new("Frame")
	well.Name = "Well"
	well.Size = UDim2.new(1, -8, 1, -8)
	well.Position = UDim2.fromOffset(4, 4)
	well.BackgroundTransparency = 1
	well.Active = false
	well.Parent = tile
	if iconFor then
		-- pcall'd for the reason `ShopFront` pcalls its window display: this
		-- is somebody else's builder, and a reward losing its PICTURE is a
		-- cosmetic fault while a reward losing the whole card is not.
		pcall(iconFor, kind, key, well)
	end

	tile:SetAttribute("ItemName", name)
	return tile
end

-- How many coins a haul pours, and how far apart they start. Returned as a
-- pair because the stagger tightens when a long stream would outrun
-- `maxDuration`, and the caller needs the total to time what comes after.
-- `fullAt` is what the pig reads as full on the lawn (the rebirth cash gate,
-- `Config.pigFullAt`) -- a readout the stream is sized against, never a
-- limit: the pig has no ceiling and nothing spills.
local function streamShape(banked: number?, fullAt: number?): (number, number)
	local spec = Config.BANK_RUSH
	local count = spec.count
	if type(banked) == "number" and type(fullAt) == "number" and fullAt > 0 then
		if banked <= 0 then
			return 0, spec.stagger
		end
		local share = math.clamp(banked / fullAt, 0, 1)
		count = math.floor(spec.minCount + (spec.maxCount - spec.minCount) * math.sqrt(share) + 0.5)
	end
	local stagger = spec.stagger
	if count > 1 and (count - 1) * stagger + spec.fall > spec.maxDuration then
		stagger = (spec.maxDuration - spec.fall) / (count - 1)
	end
	return count, stagger
end

-- COINS RUSHING INTO THE ACTUAL PIG ON THE LAWN.
--
-- `Config.BANK_RUSH` carries the argument for this being in the world rather
-- than on the HUD, and the numbers. What lives here is the three decisions
-- that are about instances rather than about tuning.
--
-- ONE: THEY ARE PARTS, NOT PARTICLES. A ParticleEmitter emits OUTWARD from a
-- source and there is no honest way to make one converge on a point -- and
-- converging is the entire effect. Parts also mean each coin is a thing that
-- can be tweened to an exact destination, which is what lets them all arrive
-- INSIDE the pig rather than near it.
--
-- TWO: THEY LIVE UNDER THE CAMERA. A client-built part in `workspace` does
-- not replicate, so it is invisible to everybody else either way -- but the
-- camera is the idiomatic home for purely visual client geometry and it
-- cannot be mistaken for world state by anything walking `workspace.Plots`.
-- The folder is named for the same reason everything else here is: so a
-- probe, a test or the next person can find it.
--
-- THREE: THE FACE IS A BILLBOARD. A coin is a flat disc and a flat disc seen
-- edge-on is nothing, so it would need to be turned to face the camera every
-- frame -- which is a per-frame write per coin to solve a problem a
-- BillboardGui solves for free. It also makes the face a piece of UI, which
-- is what lets an empty `image` fall back to `Theme.coin`: the same drawn
-- disc the HUD uses, out of frames, with no upload anywhere.
-- THE 3D COINS IN FLIGHT, driven by one shared Heartbeat rather than one
-- tween per coin: each frame a coin eases down (Quart In, the "rush") while it
-- tumbles, and is turned so its face stays roughly toward the camera -- the
-- snout is what makes it read as THIS game's coin rather than a gold disc.
local flying: { any } = {}
local driver: RBXScriptConnection? = nil

local function faceCamera(pos: Vector3, yaw: number, roll: number): CFrame
	local camera = Workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else pos + Vector3.new(0, 0, 10)
	-- `lookAt` points -Z at the camera, and the coin's decorated face is +Z
	-- (models/coin/manifest.json), so a half turn shows the face.
	return CFrame.lookAt(pos, eye) * CFrame.Angles(0, math.pi + yaw, roll)
end

local function driveCoins()
	local now = os.clock()
	for i = #flying, 1, -1 do
		local c = flying[i]
		if not c.part.Parent then
			table.remove(flying, i)
			continue
		end
		local a = math.clamp((now - c.t0) / c.fall, 0, 1)
		local pos = c.from:Lerp(c.to, a * a * a * a)
		c.part.CFrame = faceCamera(pos, math.sin(now * 5 + c.phase) * 0.7, c.roll + (now - c.t0) * c.spin)
	end
	if #flying == 0 and driver then
		driver:Disconnect()
		driver = nil
	end
end

local function rushCoins(bank: any, banked: number?, fullAt: number?): number
	local spec = Config.BANK_RUSH
	local count, stagger = streamShape(banked, fullAt)
	if typeof(bank) ~= "Instance" or not bank:IsA("BasePart") then
		-- No pig to rush into. The summary still names the figure, so the
		-- payout is reported either way -- but a delivery with no bank on it
		-- means `PlotService.getPlot` returned nothing for a player who just
		-- delivered to their own plot, which is worth a word.
		warn("[LootHaul] delivery carried no bank part; no coin rush")
		return 0
	end

	local camera = Workspace.CurrentCamera
	if not camera then
		return 0
	end
	local folder = camera:FindFirstChild("LootFX")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "LootFX"
		folder.Parent = camera
	end

	local target = bank.Position
	local total = if count > 0 then (count - 1) * stagger + spec.fall else 0

	-- SILENT, DELIBERATELY. A delivery used to stack a slot-machine pour, a
	-- clink as the last coin landed, a sting and a sparkle per stolen item, a
	-- clink per mint and the summary's stamp on top of the cha-ching --
	-- reported as far too many sounds for one event. The cha-ching (the
	-- `money` toast) is the whole soundtrack now; everything here is picture.

	for i = 1, count do
		task.delay((i - 1) * stagger, function()
			if not bank.Parent then
				-- The pig went away mid-burst -- a rebirth, a plot release.
				return
			end
			-- SCATTERED ACROSS AND ABOVE, so the burst arrives as a shower
			-- rather than as a column. Measured from the pig's own centre, so
			-- a vault and a piggy bank both get it right.
			local angle = math.random() * math.pi * 2
			local radius = spec.spread * math.sqrt(math.random())
			local start = target + Vector3.new(math.cos(angle) * radius,
				spec.height + math.random() * 2, math.sin(angle) * radius)

			local body: Instance
			local mesh = CoinModel.clone(spec.meshStuds)
			if mesh then
				-- THE REAL COIN: the double-sided snout mesh, tumbling in.
				mesh.Name = "RushCoin"
				mesh.CFrame = faceCamera(start, 0, 0)
				mesh.Parent = folder
				table.insert(flying, {
					part = mesh, from = start, to = target, t0 = os.clock(), fall = spec.fall,
					roll = math.random() * math.pi * 2, spin = (math.random() * 2 - 1) * 9,
					phase = math.random() * math.pi * 2,
				})
				if not driver then
					driver = RunService.Heartbeat:Connect(driveCoins)
				end
				body = mesh
			else
				-- THE FALLBACK while `Config.COIN_MESH` has no id: the HUD's own
				-- drawn coin on a billboard. SIZED IN PIXELS because everything
				-- `Theme.coin` draws is laid out in pixels, so a stud-sized
				-- billboard would fit its contents at exactly one distance.
				local coin = Instance.new("Part")
				coin.Name = "RushCoin"
				coin.Size = Vector3.new(0.2, 0.2, 0.2)
				coin.Transparency = 1
				coin.Anchored = true
				coin.CanCollide = false
				coin.CanQuery = false
				coin.CanTouch = false
				coin.CastShadow = false
				coin.Position = start
				coin.Parent = folder
				local face = Instance.new("BillboardGui")
				face.Name = "Face"
				face.Size = UDim2.fromOffset(spec.size, spec.size)
				face.AlwaysOnTop = false
				face.LightInfluence = 0
				face.Adornee = coin
				face.Parent = coin
				if spec.image ~= "" then
					local img = Instance.new("ImageLabel")
					img.Name = "Coin"
					img.Size = UDim2.fromScale(1, 1)
					img.BackgroundTransparency = 1
					img.Image = spec.image
					img.Parent = face
				else
					Theme.coin(face, spec.size, "Coin")
				end
				-- EASED IN RATHER THAN OUT, WHICH IS THE WORD "RUSH": slow, then
				-- gathering, then gone into the pig fastest as it arrives.
				tween(coin, spec.fall, { Position = target },
					Enum.EasingStyle.Quart, Enum.EasingDirection.In)
				body = coin
			end

			task.delay(spec.fall, function()
				body:Destroy()
			end)
		end)
	end
	return total
end

-- FLIES A SCREEN-SPACE FRAME INTO A HUD SLOT and bumps the slot as it lands.
-- The ghost must already be parented to the ScreenGui, centre-anchored, at the
-- pixel it starts from. SHRUNK BY A UISCALE, NOT BY `Size`, so whatever is
-- drawn inside it -- pixel-laid or not -- shrinks with the frame.
-- (The SPILL picture -- coins that did not fit bursting out of the pig and
-- landing in the yard -- stood here and is retired with the pig's ceiling:
-- every delivery banks in full, so there is nothing to spill.)

local function flyGhost(ghost: GuiObject, px: number, target: GuiObject?, spin: boolean,
	onLand: (() -> ())?)
	if not target or not target.Parent then
		ghost:Destroy()
		if onLand then onLand() end
		return
	end
	local shrink = ghost:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	shrink.Parent = ghost
	local to = target.AbsolutePosition + target.AbsoluteSize / 2
	tween(ghost, FLY, { Position = UDim2.fromOffset(to.X, to.Y) },
		Enum.EasingStyle.Quart, Enum.EasingDirection.In)
	tween(shrink, FLY, { Scale = 18 / px }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
	if spin then
		tween(ghost, FLY, { Rotation = ghost.Rotation + 220 })
	end
	task.delay(FLY + 0.05, function()
		ghost:Destroy()
		-- THE LANDING BUMP, ON THE THING IT LANDED IN. Without it the ghost
		-- simply vanishes at the corner and reads as decoration rather than
		-- as something ARRIVING somewhere.
		local bump = target:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		bump.Parent = target
		bump.Scale = 1.22
		tween(bump, 0.24, { Scale = 1 }, Enum.EasingStyle.Back)
		if onLand then onLand() end
	end)
end

-- Where a point in the world is on this ScreenGui, or nil when it is behind
-- the camera. `IgnoreGuiInset` is on for the HUD, so the viewport point IS
-- the GUI point; the inset is only subtracted for a gui that respects it.
local function screenPoint(gui: Instance, world: Vector3): Vector2?
	local camera = Workspace.CurrentCamera
	if not camera then return nil end
	local point, onScreen = camera:WorldToViewportPoint(world)
	if not onScreen then return nil end
	local at = Vector2.new(point.X, point.Y)
	if gui:IsA("ScreenGui") and not gui.IgnoreGuiInset then
		at -= game:GetService("GuiService"):GetGuiInset()
	end
	return at
end

-- `riseAndFly` STOOD HERE: an icon rose out of the pig on a BillboardGui
-- and then flew, in screen space, to a chip on the HUD. Its only caller was
-- the acorn beat of a delivery, and it went with the currency. The stolen
-- item's reveal below is a different sequence and never used it.

-- A STOLEN ITEM'S REVEAL, which is the loudest moment of a delivery on
-- purpose: coins are the everyday payout and a skin is the thing somebody
-- will tell a friend about.
--
-- It LEAVES THE PIG -- starting at the pig's own place on the screen, small,
-- so it visibly comes out of the thing it was delivered into -- and swells to
-- the middle of the screen on a burst of rays in its TIER's colour, over a
-- dim, with its tier and name spelled out. It holds for `revealHold` (a tap
-- skips the rest once `revealGate` has passed), then flies into the bag.
--
-- `onDone` is ALWAYS called, even if something fails to build, because the
-- delivery sequence waits on it before showing the next thing.
local function revealItem(gui: Instance, bank: BasePart?, kind: string, key: string,
	iconFor: ((string, string, Frame) -> ())?, target: GuiObject?, onDone: () -> ())
	local spec = Config.BANK_RUSH
	local size = spec.revealSize
	local finished = false
	local function finish()
		if finished then return end
		finished = true
		onDone()
	end

	local ok, err = pcall(function()
		local name, tone = describe(kind, key)
		local catalogue = Config.catalogueFor(kind)
		local entry = catalogue and catalogue[key]
		local band = (entry and Config.RARITIES[Config.rarityOf(entry)]) or Config.RARITIES.common
		local view = (gui :: any).AbsoluteSize :: Vector2
		local centre = Vector2.new(view.X / 2, view.Y * 0.46)
		local from = (bank and screenPoint(gui, bank.Position + Vector3.new(0, 3, 0)))
			or Vector2.new(view.X / 2, view.Y * 0.62)

		local root = Instance.new("Frame")
		root.Name = "LootReveal"
		root.Size = UDim2.fromScale(1, 1)
		root.BackgroundTransparency = 1
		root.Active = false
		root.ZIndex = 60
		root.Parent = gui

		local dim = Instance.new("Frame")
		dim.Name = "Dim"
		dim.Size = UDim2.fromScale(1, 1)
		dim.BackgroundColor3 = Theme.INK
		dim.BackgroundTransparency = 1
		dim.BorderSizePixel = 0
		dim.ZIndex = 1
		dim.Parent = root

		-- THE RAYS: eight bars through one point, turning slowly, each fading
		-- out along its length so the burst has no hard ends.
		local rays = Instance.new("Frame")
		rays.Name = "Rays"
		rays.BackgroundTransparency = 1
		rays.Position = UDim2.fromOffset(centre.X, centre.Y)
		rays.Size = UDim2.fromOffset(0, 0)
		rays.ZIndex = 2
		rays.Parent = root
		local bars = {}
		for i = 1, 8 do
			local bar = Instance.new("Frame")
			bar.Name = "Ray" .. i
			bar.AnchorPoint = Vector2.new(0.5, 0.5)
			bar.Size = UDim2.fromOffset(math.max(view.X, view.Y) * 1.1, 40)
			bar.BackgroundColor3 = tone
			bar.BorderSizePixel = 0
			bar.BackgroundTransparency = 1
			bar.ZIndex = 2
			bar.Parent = rays
			local fade = Instance.new("UIGradient")
			fade.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.32, 0.7),
				NumberSequenceKeypoint.new(0.5, 0.25),
				NumberSequenceKeypoint.new(0.68, 0.7),
				NumberSequenceKeypoint.new(1, 1),
			})
			fade.Parent = bar
			bars[i] = bar
			tween(bar, 0.5, { BackgroundTransparency = 0 })
		end

		local glow = Instance.new("Frame")
		glow.Name = "Glow"
		glow.AnchorPoint = Vector2.new(0.5, 0.5)
		glow.Position = UDim2.fromOffset(centre.X, centre.Y)
		glow.Size = UDim2.fromOffset(size * 1.5, size * 1.5)
		glow.BackgroundColor3 = tone
		glow.BackgroundTransparency = 1
		glow.BorderSizePixel = 0
		glow.ZIndex = 3
		glow.Parent = root
		Theme.corner(glow, math.floor(size * 0.75))
		local glowFade = Instance.new("UIGradient")
		glowFade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.7, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		})
		glowFade.Parent = glow
		tween(glow, 0.5, { BackgroundTransparency = 0.25 })

		-- THE CARD ITSELF, the same tile the bag and the shop draw, at reveal
		-- size and with a heavy edge in its tier's colour.
		local card = buildTile(root, kind, key, size, iconFor)
		card.Name = "RevealCard"
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Position = UDim2.fromOffset(from.X, from.Y)
		card.Rotation = -18
		card.ZIndex = 4
		Theme.outline(card, 6, tone)
		local grow = Instance.new("UIScale")
		grow.Scale = 0.18
		grow.Parent = card

		local function word(labelName: string, text: string, y: number, height: number,
			textSize: number, colour: Color3): TextLabel
			local label = Instance.new("TextLabel")
			label.Name = labelName
			label.AnchorPoint = Vector2.new(0.5, 0.5)
			label.Position = UDim2.fromOffset(centre.X, y)
			label.Size = UDim2.fromOffset(math.min(view.X - 32, 560), height)
			label.BackgroundTransparency = 1
			label.Text = text
			label.TextTransparency = 1
			label.ZIndex = 5
			label.Parent = root
			Theme.title(label, textSize, colour)
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 3
			stroke.Color = Theme.INK
			stroke.Transparency = 1
			stroke.Parent = label
			return label
		end
		local heading = word("Heading", if kind == "skin" then "NEW SKIN!" else "NEW ITEM!",
			centre.Y - size / 2 - 44, 48, 40, Theme.PAPER)
		local tierWord = word("Tier", string.upper(band.label), centre.Y + size / 2 + 26, 30, 24, tone)
		local nameWord = word("ItemName", string.upper(name), centre.Y + size / 2 + 60, 36, 30, Theme.PAPER)
		local labels = { heading, tierWord, nameWord }

		local flash = Instance.new("Frame")
		flash.Name = "Flash"
		flash.Size = UDim2.fromScale(1, 1)
		flash.BackgroundColor3 = Color3.new(1, 1, 1)
		flash.BackgroundTransparency = 1
		flash.BorderSizePixel = 0
		flash.ZIndex = 6
		flash.Parent = root

		-- A tap anywhere skips the rest of the hold, once the gate has passed.
		local catcher = Instance.new("TextButton")
		catcher.Name = "Skip"
		catcher.Size = UDim2.fromScale(1, 1)
		catcher.BackgroundTransparency = 1
		catcher.Text = ""
		catcher.ZIndex = 7
		catcher.Parent = root

		-- IN: out of the pig to the middle of the screen, growing and
		-- straightening, landing on a flash and the reward sting.
		tween(dim, 0.4, { BackgroundTransparency = 0.4 })
		tween(card, 0.6, { Position = UDim2.fromOffset(centre.X, centre.Y), Rotation = 0 },
			Enum.EasingStyle.Back)
		tween(grow, 0.6, { Scale = 1 }, Enum.EasingStyle.Back)
		task.delay(0.55, function()
			if not root.Parent then return end
			flash.BackgroundTransparency = 0.35
			tween(flash, 0.45, { BackgroundTransparency = 1 })
			for _, label in ipairs(labels) do
				tween(label, 0.3, { TextTransparency = 0 })
				tween(label:FindFirstChildOfClass("UIStroke") :: UIStroke, 0.3, { Transparency = 0 })
			end
		end)

		-- The rays turn and the glow and card breathe for as long as it holds.
		local t0 = os.clock()
		local spinner = RunService.Heartbeat:Connect(function()
			local t = os.clock() - t0
			for i, bar in ipairs(bars) do
				bar.Rotation = (i - 1) * 22.5 + t * 18
			end
			local breath = 1 + 0.04 * math.sin(t * 3.2)
			glow.Size = UDim2.fromOffset(size * 1.5 * breath, size * 1.5 * breath)
		end)

		local skipped = false
		local openedAt = os.clock()
		catcher.Activated:Connect(function()
			if os.clock() - openedAt >= spec.revealGate then skipped = true end
		end)

		task.spawn(function()
			local holdEnd = os.clock() + 0.6 + spec.revealHold
			while os.clock() < holdEnd and not skipped and root.Parent do
				task.wait()
			end
			-- OUT: the burst fades, and the card leaves for the bag.
			for _, label in ipairs(labels) do
				tween(label, 0.2, { TextTransparency = 1 })
				tween(label:FindFirstChildOfClass("UIStroke") :: UIStroke, 0.2, { Transparency = 1 })
			end
			for _, bar in ipairs(bars) do tween(bar, 0.3, { BackgroundTransparency = 1 }) end
			tween(glow, 0.3, { BackgroundTransparency = 1 })
			tween(dim, 0.35, { BackgroundTransparency = 1 })
			catcher:Destroy()
			card.Parent = gui
			card.ZIndex = 60
			flyGhost(card, size, target, true, function()
				finish()
			end)
			task.delay(0.4, function()
				spinner:Disconnect()
				root:Destroy()
			end)
		end)
	end)
	if not ok then
		warn("[LootHaul] item reveal failed: " .. tostring(err))
		finish()
	end
end

function LootHaul.start(gui: Instance, iconFor: ((string, string, Frame) -> ())?,
	openBag: (() -> ())?)
	-- WHERE AN ITEM FLIES TO, FOUND BY NAME RATHER THAN PASSED IN.
	--
	-- `BagToggle` is the satchel, built in ClientMain hundreds of lines from
	-- any call site that could hand it over. Looking it up is safe here for
	-- one reason: it already carries a real name, because this project makes
	-- a rule of naming anything a probe might address.
	--
	-- THE COINS DO NOT COME THROUGH HERE, and that is the whole world-versus-
	-- HUD change: they go to the pig on the lawn, which the SERVER names in
	-- the delivery payload. See `rushCoins`.
	--
	-- A MISS IS WARNED AND NOT GUESSED. A hardcoded screen corner would go on
	-- working and would quietly aim at nothing the day the button moved,
	-- which is exactly the class of silent drift this codebase keeps paying
	-- for; a warn names it once and the tile fades in place instead.
	local function anchor(name: string): GuiObject?
		local found = gui:FindFirstChild(name, true)
		return if found and found:IsA("GuiObject") then found else nil
	end

	-- ---------- the carrying chip ----------
	--
	-- ABOVE THE SATCHEL, WHICH IS WHERE IT IS GOING. The whole point of the
	-- chip is that this is not yours yet, and parking it one hop from the bag
	-- makes the delivery a short readable trip rather than a diagonal across
	-- the screen. It is also the only corner with room: the top-centre column
	-- is five bands deep and the bottom-left is four rows deep.
	local chip = Instance.new("Frame")
	chip.Name = "CarryingLoot"
	chip.Size = UDim2.fromOffset(64, 64)
	chip.Position = UDim2.new(1, -24, 1, -150)
	chip.AnchorPoint = Vector2.new(1, 1)
	chip.Visible = false
	chip.Active = false
	chip.ZIndex = 6
	chip.Parent = gui
	Theme.card(chip, 12)

	local chipWell = Instance.new("Frame")
	chipWell.Name = "Well"
	chipWell.Size = UDim2.new(1, -10, 1, -10)
	chipWell.Position = UDim2.fromOffset(5, 5)
	chipWell.BackgroundTransparency = 1
	chipWell.Active = false
	chipWell.ZIndex = 7
	chipWell.Parent = chip

	local chipCount = Instance.new("TextLabel")
	chipCount.Name = "Count"
	chipCount.Size = UDim2.fromOffset(26, 20)
	chipCount.Position = UDim2.new(1, 2, 0, -6)
	chipCount.AnchorPoint = Vector2.new(1, 0)
	chipCount.BackgroundColor3 = Theme.STOP
	chipCount.Text = ""
	chipCount.Visible = false
	chipCount.ZIndex = 9
	chipCount.Parent = chip
	Theme.title(chipCount, 13, Theme.PAPER)
	Theme.corner(chipCount, 10)

	-- WHAT IS CURRENTLY IN HAND, kept so a NEW entry can be told from a
	-- re-push. `CarryUpdate` fires on the grab, on every landed slice and on
	-- the delivery, so "an item arrived" is not an event the server sends --
	-- it is a list that got longer, and the only way to see one is to
	-- remember the last. Same trick the crack's note ladder uses on `step`.
	local held: { { kind: string, key: string } } = {}

	local function renderChip()
		chipWell:ClearAllChildren()
		chip.Visible = #held > 0
		chipCount.Visible = #held > 1
		if #held == 0 then
			return
		end
		chipCount.Text = ("%d"):format(#held)
		local top = held[#held]
		if iconFor then
			pcall(iconFor, top.kind, top.key, chipWell)
		end
	end

	-- ---------- the drop-off rings ----------
	--
	-- ARRIVING IS THE DELIVERY, AND THE RING IS HOW A PLAYER KNOWS WHERE THAT
	-- IS. There was a DELIVER button bottom-centre; a player running home with
	-- a dog behind them should not have to find a button as well, so the
	-- server banks the haul the tick they step inside `Config.DROPOFF_RADIUS`
	-- of their own pig (or of the owner's pig, for somebody returning loot)
	-- and this draws that circle on the lawn.
	--
	-- THE RING IS THE RULE, NOT A PICTURE OF IT. The server measures a 3D
	-- distance from the pig's centre, so the circle on the grass is the slice
	-- of that sphere at the carrier's own root height -- recomputed each
	-- frame, so standing on the line means standing on the edge of the zone.
	--
	-- CLIENT-SIDE AND FOR THE CARRIER ONLY. Nobody else needs to know where a
	-- thief is heading; the loot on their chest already says they are one.
	-- A `CylinderHandleAdornment` has an inner radius, which a Part does not,
	-- so one instance is one ring and nothing here collides or is queried.
	local localPlayer = game:GetService("Players").LocalPlayer
	local rings: { [string]: any } = {}
	local function makeRing(name: string, colour: Color3)
		local band = Instance.new("CylinderHandleAdornment")
		band.Name = name .. "Ring"
		band.Adornee = Workspace.Terrain
		band.Color3 = colour
		band.Height = 0.35
		band.AlwaysOnTop = false
		band.ZIndex = 1
		band.Visible = false
		band.Parent = gui
		-- A thin wall of the same colour standing on the ring, so the drop-off
		-- reads from down the street and not only from on top of it.
		local wall = Instance.new("CylinderHandleAdornment")
		wall.Name = name .. "Glow"
		wall.Adornee = Workspace.Terrain
		wall.Color3 = colour
		wall.Height = 2.6
		wall.AlwaysOnTop = false
		wall.Visible = false
		wall.Parent = gui
		rings[name] = { band = band, wall = wall, spec = nil }
	end
	makeRing("Home", Theme.GOLD)
	makeRing("Return", Theme.GOOD)

	local crackOpen = false
	local function paintRings()
		local busy = crackOpen
		for _, ring in pairs(rings) do
			local on = ring.spec ~= nil and not busy
			ring.band.Visible, ring.wall.Visible = on, on
		end
	end
	Remotes.get("CrackState").OnClientEvent:Connect(function(payload)
		crackOpen = payload ~= nil
		paintRings()
	end)
	local function setRings(options: any?)
		local info = options or {}
		rings.Home.spec = if type(info.homeRing) == "table" then info.homeRing else nil
		rings.Return.spec = if type(info.returnRing) == "table" then info.returnRing else nil
		paintRings()
	end

	local FLAT = CFrame.Angles(math.pi / 2, 0, 0)
	RunService.Heartbeat:Connect(function()
		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local pulse = 0.5 + 0.5 * math.sin(os.clock() * math.pi * 2 * 0.8)
		for _, ring in pairs(rings) do
			local spec = ring.spec
			if spec and ring.band.Visible and typeof(spec.at) == "Vector3" then
				local reach = Config.DROPOFF_RADIUS
				local dy = if root then root.Position.Y - spec.at.Y else 3
				local r = math.sqrt(math.max(reach * reach - dy * dy, 4))
				local ground = tonumber(spec.ground) or spec.at.Y
				local centre = Vector3.new(spec.at.X, ground, spec.at.Z)
				ring.band.CFrame = CFrame.new(centre + Vector3.new(0, 0.2, 0)) * FLAT
				ring.band.Radius, ring.band.InnerRadius = r, r - 0.7
				ring.band.Transparency = 0.05 + 0.3 * pulse
				ring.wall.CFrame = CFrame.new(centre + Vector3.new(0, 1.3, 0)) * FLAT
				ring.wall.Radius, ring.wall.InnerRadius = r, r - 0.12
				ring.wall.Transparency = 0.6 + 0.25 * pulse
			end
		end
	end)

	-- ---------- the grab pop ----------
	local pop = Instance.new("Frame")
	pop.Name = "LootPop"
	pop.Size = UDim2.fromOffset(230, 200)
	pop.Position = UDim2.new(0.5, 0, 0.42, 0)
	pop.AnchorPoint = Vector2.new(0.5, 0.5)
	pop.Visible = false
	pop.Active = false
	pop.ZIndex = 20
	pop.Parent = gui
	Theme.card(pop, 18)

	local popScale = Instance.new("UIScale")
	popScale.Parent = pop

	local popBanner = Instance.new("TextLabel")
	popBanner.Name = "Banner"
	popBanner.Size = UDim2.new(1, -20, 0, 26)
	popBanner.Position = UDim2.fromOffset(10, 10)
	popBanner.BackgroundColor3 = Theme.STOP
	popBanner.Text = "STOLEN!"
	popBanner.ZIndex = 21
	popBanner.Parent = pop
	Theme.title(popBanner, 17, Theme.PAPER)
	Theme.corner(popBanner, 8)

	local popWell = Instance.new("Frame")
	popWell.Name = "Well"
	popWell.Size = UDim2.fromOffset(TILE, TILE)
	popWell.Position = UDim2.new(0.5, 0, 0, 44)
	popWell.AnchorPoint = Vector2.new(0.5, 0)
	popWell.BackgroundTransparency = 1
	popWell.Active = false
	popWell.ZIndex = 21
	popWell.Parent = pop

	local popName = Instance.new("TextLabel")
	popName.Name = "ItemName"
	popName.Size = UDim2.new(1, -20, 0, 24)
	popName.Position = UDim2.new(0, 10, 1, -46)
	popName.BackgroundTransparency = 1
	popName.Text = ""
	popName.ZIndex = 21
	popName.Parent = pop
	Theme.title(popName, 18, Theme.INK)

	local popHint = Instance.new("TextLabel")
	popHint.Name = "Hint"
	popHint.Size = UDim2.new(1, -20, 0, 18)
	popHint.Position = UDim2.new(0, 10, 1, -24)
	popHint.BackgroundTransparency = 1
	popHint.Text = "RUN IT HOME"
	popHint.ZIndex = 21
	popHint.Parent = pop
	Theme.body(popHint, 12, Theme.MUTED)

	-- ONE TOKEN GUARDS EVERY DELAYED STEP. Two grabs inside one crack are
	-- ordinary -- a shop can drop an item on the same run a skin comes off a
	-- player -- and without this the first card's own fade-out would hide the
	-- second card three frames after it appeared.
	local popToken = 0
	local function playPop(kind: string, key: string)
		popToken += 1
		local mine = popToken

		local name, tone = describe(kind, key)
		popName.Text = string.upper(name)
		popBanner.BackgroundColor3 = tone
		popBanner.TextColor3 = Theme.readable(tone, tone)
		popWell:ClearAllChildren()
		if iconFor then
			pcall(iconFor, kind, key, popWell)
		end

		-- A STING, AND IT IS THE MILESTONE CUE RATHER THAN A NEW UPLOAD.
		-- This game already owns a reward sound, and reusing it is the same
		-- call the dog barks make with one coyote: what a player learns is
		-- "that noise means something good landed", and two of them teach
		-- half a lesson twice. Pitched up a fourth so it is audibly the
		-- bigger sibling of the coin drop rather than the same event.
		SoundKit.ui(Config.SOUNDS.MILESTONE, {
			name = "LootPop",
			volume = 0.5,
			pitch = Config.semitonePitch(5),
		})

		pop.Visible = true
		pop.Position = UDim2.new(0.5, 0, 0.42, 0)
		popScale.Scale = 0.6
		tween(popScale, POP_IN, { Scale = 1 }, Enum.EasingStyle.Back)

		task.delay(POP_IN + POP_HOLD, function()
			if popToken ~= mine then
				return
			end
			-- AWAY TOWARDS THE CHIP, not a fade in place. The card shrinking
			-- into the corner the item then sits in is what makes those two
			-- one object rather than two unrelated pieces of UI -- the same
			-- reason the summary flies its tiles at the satchel.
			local target = chip.AbsolutePosition
			local viewport = gui.AbsoluteSize
			tween(pop, POP_AWAY, {
				Position = UDim2.new(
					(target.X + 32) / math.max(viewport.X, 1), 0,
					(target.Y + 32) / math.max(viewport.Y, 1), 0),
			}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween(popScale, POP_AWAY, { Scale = 0.2 })
			task.delay(POP_AWAY, function()
				if popToken == mine then
					pop.Visible = false
				end
			end)
		end)
	end

	Remotes.get("CarryUpdate").OnClientEvent:Connect(function(amount: number, haul: any,
		_inRange: boolean?, kind: string?, _worth: number?, _ownBasket: boolean?, options: any?)
		local view = CarryDelivery.describe(amount, haul, kind, options)
		setRings(if view.visible then options else nil)
		local list = if type(haul) == "table" then haul else {}
		-- A LIST THAT GOT LONGER IS THE EVENT. Anything else -- a re-push on
		-- a landed slice, the same haul arriving twice -- must not re-pop, or
		-- one card would fire five times over a single five-slice crack.
		if #list > #held then
			for i = #held + 1, #list do
				local item = list[i]
				if item and item.kind and item.key then
					playPop(item.kind, item.key)
				end
			end
		end
		held = {}
		for _, item in ipairs(list) do
			if item and item.kind and item.key then
				table.insert(held, { kind = item.kind, key = item.key })
			end
		end
		renderChip()
	end)

	-- ---------- the delivery summary ----------
	--
	-- THE LAST BEAT, AND THE ONE PLACE THIS FILE STOPS THE PLAYER. It comes
	-- after the coins and any stolen item have all landed, so it
	-- is a receipt for things the player has just watched arrive rather than
	-- a promise. A tap closes it -- after `summaryGate`, so a tap already on
	-- its way does not dismiss it unread -- and `summaryAuto` closes it on its
	-- own, so it can never trap anybody. The arrest scene's shape, in the
	-- HUD's own paper-and-ink vocabulary.
	local overlay = Instance.new("TextButton")
	overlay.Name = "HeistSummary"
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.BackgroundColor3 = Theme.INK
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.AutoButtonColor = false
	overlay.Text = ""
	overlay.Visible = false
	overlay.ZIndex = 70
	overlay.Parent = gui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.52)
	panel.Size = UDim2.fromOffset(440, 300)
	panel.Active = false
	panel.ZIndex = 71
	panel.Parent = overlay
	Theme.card(panel, 22)
	local panelScale = Instance.new("UIScale")
	panelScale.Parent = panel

	-- THE RIBBON across the top edge, half off the card: DELIVERED! on the
	-- good green, REVENGE! on the alarm red. It slams in a beat after the
	-- card, which is the stamp moment the arrest scene has.
	local ribbon = Instance.new("Frame")
	ribbon.Name = "Ribbon"
	ribbon.AnchorPoint = Vector2.new(0.5, 0.5)
	ribbon.Position = UDim2.new(0.5, 0, 0, 0)
	ribbon.Size = UDim2.new(1, -56, 0, 58)
	ribbon.ZIndex = 73
	ribbon.Parent = panel
	Theme.tinted(ribbon, Theme.GOOD, Theme.GOOD:Lerp(Color3.new(), 0.3), 16)
	local ribbonScale = Instance.new("UIScale")
	ribbonScale.Parent = ribbon
	local ribbonTitle = Instance.new("TextLabel")
	ribbonTitle.Name = "Title"
	ribbonTitle.Size = UDim2.fromScale(1, 1)
	ribbonTitle.BackgroundTransparency = 1
	ribbonTitle.Text = "DELIVERED!"
	ribbonTitle.ZIndex = 74
	ribbonTitle.Parent = ribbon
	Theme.title(ribbonTitle, 32, Theme.INK)

	local function line(labelName: string, textSize: number, colour: Color3, heading: boolean): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = labelName
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.BackgroundTransparency = 1
		label.Text = ""
		label.ZIndex = 72
		label.Parent = panel
		if heading then Theme.title(label, textSize, colour) else Theme.body(label, textSize, colour) end
		return label
	end
	local fromLabel = line("From", 15, Theme.MUTED, false)

	local coinRow = Instance.new("Frame")
	coinRow.Name = "Coins"
	coinRow.AnchorPoint = Vector2.new(0.5, 0)
	coinRow.BackgroundTransparency = 1
	coinRow.ZIndex = 72
	coinRow.Parent = panel
	local coinLayout = Instance.new("UIListLayout")
	coinLayout.FillDirection = Enum.FillDirection.Horizontal
	coinLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	coinLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	coinLayout.Padding = UDim.new(0, 10)
	coinLayout.SortOrder = Enum.SortOrder.LayoutOrder
	coinLayout.Parent = coinRow
	local coinIcon = Theme.coin(coinRow, 50, "CoinIcon")
	coinIcon.LayoutOrder = 1
	local coinAmount = Instance.new("TextLabel")
	coinAmount.Name = "Amount"
	coinAmount.AutomaticSize = Enum.AutomaticSize.X
	coinAmount.Size = UDim2.new(0, 0, 1, 0)
	coinAmount.BackgroundTransparency = 1
	coinAmount.Text = ""
	coinAmount.LayoutOrder = 2
	coinAmount.ZIndex = 72
	coinAmount.Parent = coinRow
	Theme.title(coinAmount, 46, Theme.GOLD_INK)

	local bankedLabel = line("Banked", 14, Theme.MUTED, false)

	local function strip(stripName: string): Frame
		local row = Instance.new("Frame")
		row.Name = stripName
		row.AnchorPoint = Vector2.new(0.5, 0)
		row.BackgroundTransparency = 1
		row.ZIndex = 72
		row.Parent = panel
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, 10)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = row
		return row
	end
	local chips = strip("Chips")
	local itemRow = strip("Items")

	local bagButton = Instance.new("TextButton")
	bagButton.Name = "OpenBag"
	bagButton.AnchorPoint = Vector2.new(0.5, 0)
	bagButton.Size = UDim2.fromOffset(180, 40)
	bagButton.AutoButtonColor = false
	bagButton.Text = "OPEN BAG"
	bagButton.ZIndex = 73
	bagButton.Parent = panel
	Theme.tinted(bagButton, Theme.HUE.crates, Theme.HUE.crates:Lerp(Color3.new(), 0.25), 12)
	Theme.title(bagButton, 18, Theme.INK)

	local tapLabel = line("TapToContinue", 16, Theme.MUTED, true)
	tapLabel.Text = "TAP TO CONTINUE"

	-- One pill in the chip strip: a tone-tinted ground and a word. It used to
	-- take an icon as well, for the acorn chip; that was its only caller and
	-- it went with the currency, so the parameter went too.
	local function addChip(order: number, tone: Color3, text: string)
		local pill = Instance.new("Frame")
		pill.Name = "Chip"
		pill.AutomaticSize = Enum.AutomaticSize.X
		pill.Size = UDim2.new(0, 0, 1, 0)
		pill.BackgroundColor3 = tone:Lerp(Theme.PAPER, 0.55)
		pill.LayoutOrder = order
		pill.ZIndex = 72
		pill.Parent = chips
		Theme.corner(pill, 20)
		Theme.outline(pill, 2.5)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
		pad.Parent = pill
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = pill
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.AutomaticSize = Enum.AutomaticSize.X
		label.Size = UDim2.new(0, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Text = text
		label.LayoutOrder = 2
		label.ZIndex = 73
		label.Parent = pill
		Theme.title(label, 17, Theme.INK)
	end

	local function clearRow(row: Frame)
		for _, child in ipairs(row:GetChildren()) do
			if not child:IsA("UIListLayout") then child:Destroy() end
		end
	end

	local summaryToken = 0
	local openedAt = 0
	local counting: Tween? = nil
	local pulsing: Tween? = nil

	local function hideSummary()
		if not overlay.Visible then return end
		summaryToken += 1
		local mine = summaryToken
		if counting then counting:Cancel() end
		if pulsing then pulsing:Cancel() end
		tween(overlay, 0.2, { BackgroundTransparency = 1 })
		tween(panelScale, 0.2, { Scale = panelScale.Scale * 0.8 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.2, function()
			if summaryToken == mine then overlay.Visible = false end
		end)
	end

	local function showSummary(payload: any, stolen: { { kind: string, key: string } })
		summaryToken += 1
		local mine = summaryToken
		local revenge = payload.revenge == true
		local banked = math.floor(tonumber(payload.banked) or 0)
		local run = math.floor(tonumber(payload.run) or 0)

		-- No PIGGY FULL result any more: the pig has no ceiling, so every
		-- delivery banks in full and the card is DELIVERED or REVENGE.
		ribbon.BackgroundColor3 = if revenge then Theme.STOP else Theme.GOOD
		Theme.gloss(ribbon, ribbon.BackgroundColor3, ribbon.BackgroundColor3:Lerp(Color3.new(), 0.3))
		ribbonTitle.Text = if revenge then "REVENGE!" else "DELIVERED!"
		ribbonTitle.TextColor3 = if revenge then Theme.PAPER else Theme.INK
		coinAmount.TextColor3 = Theme.GOLD_INK
		local victim = if type(payload.victim) == "string" and payload.victim ~= "" then payload.victim else nil
		fromLabel.Text = if victim then ("You robbed %s"):format(victim) else "You got the haul home"
		bankedLabel.Text = "banked into your piggy"

		clearRow(chips)
		if run > 1 then addChip(1, Theme.WARN, ("%dx IN A ROW"):format(run)) end
		clearRow(itemRow)
		for i, item in ipairs(stolen) do
			local tile = buildTile(itemRow, item.kind, item.key, 76, iconFor)
			tile.LayoutOrder = i
			tile.ZIndex = 73
		end

		-- LAID OUT TOP DOWN, skipping any row with nothing in it, so the card
		-- is always as tall as what it says.
		local width = 440
		local y = 42
		local function place(obj: GuiObject, height: number, gap: number, show: boolean)
			obj.Visible = show
			if not show then return end
			obj.Position = UDim2.new(0.5, 0, 0, y)
			if obj ~= bagButton then obj.Size = UDim2.new(1, -40, 0, height) end
			y += height + gap
		end
		place(fromLabel, 22, 4, true)
		place(coinRow, 58, 0, true)
		place(bankedLabel, 20, 6, true)
		place(chips, 40, 12, #chips:GetChildren() > 1)
		place(itemRow, 76, 12, #stolen > 0)
		place(bagButton, 40, 12, #stolen > 0 and openBag ~= nil)
		place(tapLabel, 24, 16, true)
		panel.Size = UDim2.fromOffset(width, y)

		-- Fitted to a short screen, so a phone held sideways sees all of it.
		local view = (gui :: any).AbsoluteSize :: Vector2
		local fit = math.min(1, (view.Y - 40) / (y + 40), (view.X - 24) / width)

		overlay.Visible = true
		overlay.BackgroundTransparency = 1
		tween(overlay, 0.3, { BackgroundTransparency = 0.45 })
		panelScale.Scale = fit * 0.6
		tween(panelScale, 0.4, { Scale = fit }, Enum.EasingStyle.Back)
		ribbonScale.Scale = 1.8
		ribbon.Rotation = -6
		tapLabel.TextTransparency = 1
		task.delay(0.25, function()
			if summaryToken ~= mine then return end
			tween(ribbonScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
			tween(ribbon, 0.3, { Rotation = -2 }, Enum.EasingStyle.Back)
		end)

		-- THE FIGURE COUNTS UP, which is the difference between reading a
		-- number and watching it be paid.
		local counter = Instance.new("NumberValue")
		counter.Value = 0
		counter.Changed:Connect(function(v)
			coinAmount.Text = ("+%s"):format(Config.formatCoins(math.floor(v)))
		end)
		coinAmount.Text = "+0"
		counting = TweenService:Create(counter,
			TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = banked })
		;(counting :: Tween):Play()
		task.delay(1, function() counter:Destroy() end)

		openedAt = os.clock()
		task.delay(Config.BANK_RUSH.summaryGate, function()
			if summaryToken ~= mine then return end
			tapLabel.TextTransparency = 0
			pulsing = TweenService:Create(tapLabel,
				TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ TextTransparency = 0.55 })
			;(pulsing :: Tween):Play()
		end)
		task.delay(Config.BANK_RUSH.summaryAuto, function()
			if summaryToken == mine then hideSummary() end
		end)
	end

	local function tryClose()
		if overlay.Visible and os.clock() - openedAt >= Config.BANK_RUSH.summaryGate then
			hideSummary()
		end
	end
	overlay.Activated:Connect(tryClose)
	UserInputService.InputBegan:Connect(function(input, typed)
		if typed then return end
		local k = input.KeyCode
		if k == Enum.KeyCode.Space or k == Enum.KeyCode.Return or k == Enum.KeyCode.Escape
			or k == Enum.KeyCode.ButtonA then
			tryClose()
		end
	end)
	bagButton.Activated:Connect(function()
		hideSummary()
		if openBag then openBag() end
	end)

	-- ---------- the delivery sequence ----------
	--
	-- ONE THING AT A TIME, IN THE ORDER A PLAYER CAN FOLLOW: the coins pour
	-- into the pig, each stolen item gets its reveal and goes to the bag, and
	-- then the summary names it all.
	-- A second delivery arriving mid-sequence takes over from the first.
	local sequence = 0
	Remotes.get("HeistDelivered").OnClientEvent:Connect(function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		sequence += 1
		local mine = sequence
		hideSummary()

		local stolen: { { kind: string, key: string } } = {}
		if type(payload.items) == "table" then
			for _, item in ipairs(payload.items) do
				if type(item) == "table" and item.kind and item.key then
					table.insert(stolen, { kind = item.kind, key = item.key })
				end
			end
		end
		local bank: BasePart? = if typeof(payload.bank) == "Instance" and payload.bank:IsA("BasePart")
			then payload.bank else nil
		local spec = Config.BANK_RUSH

		-- NO BANK SOUND HERE: the delivery toast is the one cha-ching.
		task.spawn(function()
			local pour = rushCoins(payload.bank, payload.banked, payload.fullAt)
			task.wait(pour + 0.25)
			if sequence ~= mine then return end

			local satchel = anchor("BagToggle")
			if #stolen > 0 and not satchel then
				warn("[LootHaul] no BagToggle to fly the items into")
			end
			for _, item in ipairs(stolen) do
				local done = false
				revealItem(gui, bank, item.kind, item.key, iconFor, satchel, function() done = true end)
				local deadline = os.clock() + spec.revealHold + 4
				while not done and os.clock() < deadline do task.wait() end
				if sequence ~= mine then return end
			end

			-- THE ACORN BEAT STOOD HERE: an acorn per mint rose out of the pig
			-- and flew to its chip on the HUD. Both the currency and the chip
			-- retired, so a delivery is the coins and the stolen items and
			-- then the summary.

			showSummary(payload, stolen)
		end)
	end)
end

return LootHaul
