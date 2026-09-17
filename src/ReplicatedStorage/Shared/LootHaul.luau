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
	  3. THE DELIVERY. A summary of what the run was worth, with the items
	     flying into the satchel and the coins rushing into the ACTUAL PIG on
	     the lawn -- see `rushCoins`, and `Config.BANK_RUSH` for why that is
	     in the world rather than on the HUD.

	NONE OF IT INTERRUPTS, and that is the constraint the whole file is built
	against rather than a nicety. Every one of these lands while the player is
	RUNNING, usually with a dog behind them: the grab card arrives mid-sprint
	and the summary arrives at the moment they are deciding where to go next.
	So nothing here is modal, nothing captures input, nothing pauses anything,
	and the only clickable thing in the file is one button on the summary that
	the player never has to press.

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
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SoundKit = require(ReplicatedStorage.Shared.SoundKit)
local Theme = require(ReplicatedStorage.Shared.Theme)

local CarryDelivery = require(ReplicatedStorage.Shared.CarryDelivery)

local LootHaul = {}

-- HOW LONG EACH BEAT LASTS, read against what is happening on screen while it
-- runs: the grab card is on during a getaway, so it is short, and the summary
-- is on while the player is standing safely on their own plot, so it can
-- afford to be seen.
local POP_IN = 0.28
local POP_HOLD = 1.9
local POP_AWAY = 0.42
local SUMMARY_IN = 0.3
local SUMMARY_HOLD = 5.0
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
local function rushCoins(bank: any)
	local spec = Config.BANK_RUSH
	if typeof(bank) ~= "Instance" or not bank:IsA("BasePart") then
		-- No pig to rush into. The summary card still names the figure, so
		-- the payout is reported either way -- but this is worth a word,
		-- because a delivery with no bank on it means `PlotService.getPlot`
		-- returned nothing for a player who just delivered to their own plot.
		warn("[LootHaul] delivery carried no bank part; no coin rush")
		return
	end

	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local folder = camera:FindFirstChild("LootFX")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "LootFX"
		folder.Parent = camera
	end

	local target = bank.Position
	for i = 1, spec.count do
		task.delay((i - 1) * spec.stagger, function()
			if not bank.Parent then
				-- The pig went away mid-burst -- a rebirth, a plot release.
				-- Nothing to rush into, and `target` is a stale position.
				return
			end

			local coin = Instance.new("Part")
			coin.Name = "RushCoin"
			coin.Size = Vector3.new(0.2, 0.2, 0.2)
			coin.Transparency = 1
			coin.Anchored = true
			coin.CanCollide = false
			coin.CanQuery = false
			coin.CanTouch = false
			coin.CastShadow = false
			-- SCATTERED ACROSS AND ABOVE, so the burst arrives as a shower
			-- rather than as a column. The height is measured from the pig's
			-- own centre, so a vault and a piggy bank both get it right
			-- without either being special-cased.
			local angle = math.random() * math.pi * 2
			local radius = spec.spread * math.sqrt(math.random())
			coin.Position = target + Vector3.new(
				math.cos(angle) * radius,
				spec.height + math.random() * 2,
				math.sin(angle) * radius)
			coin.Parent = folder

			local face = Instance.new("BillboardGui")
			face.Name = "Face"
			-- SIZED IN PIXELS, WHICH IS THE OPPOSITE OF WHAT IT LOOKS LIKE IT
			-- SHOULD BE AND IS FORCED BY WHAT IS DRAWN INSIDE IT.
			--
			-- A BillboardGui takes both: the SCALE half is studs and holds a
			-- constant WORLD size, the OFFSET half is pixels and holds a
			-- constant SCREEN size. Studs is the instinct for a coin beside a
			-- twelve-stud pig -- and it makes the billboard AbsoluteSize
			-- change with distance, and everything `Theme.coin` builds is
			-- laid out in PIXELS. The rim is `size - 8` and the corner radius
			-- is `size // 2`, so at studs the disc is the right size at
			-- exactly one distance and overflows its own container at every
			-- other one.
			--
			-- Offset is also what every other billboard in this game already
			-- does, for the reason the prompt cards record: a card sized in
			-- studs projects to fewer pixels the further off you stand, and
			-- these are read from a stride away.
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
				-- The HUD's own drawn coin, which needs no asset at all. See
				-- `Config.BANK_RUSH.image`.
				-- AT THE BILLBOARD'S OWN SIZE, so the drawn disc fills it
				-- exactly. One number, passed through, rather than two that
				-- have to be kept in step.
				Theme.coin(face, spec.size, "Coin")
			end

			-- EASED IN RATHER THAN OUT, WHICH IS THE WORD "RUSH". It starts
			-- slow, gathers, and vanishes into the pig fastest at the moment
			-- it arrives; eased the other way the coins drift down and settle,
			-- which is money being put away rather than money being poured.
			tween(coin, spec.fall, { Position = target },
				Enum.EasingStyle.Quart, Enum.EasingDirection.In)
			task.delay(spec.fall, function()
				coin:Destroy()
			end)
		end)
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

	-- ---------- the deliver button ----------
	--
	-- THE FOURTH MOMENT, AND THE ONLY ONE IN THIS FILE THE PLAYER HAS TO
	-- PRESS. The header's own rule is that nothing here interrupts and that
	-- "the only clickable thing in the file is one button on the summary that
	-- the player never has to press" -- this is the deliberate exception, and
	-- it is worth saying why rather than quietly breaking it. Arriving home
	-- used to bank the loot on its own: a thief crossed an invisible circle
	-- and the coins appeared, so the pig the whole game is named after was a
	-- thing a robbery never had to touch. The press is the loop closing, and
	-- a press has to have something to press.
	--
	-- `Active` IS THEREFORE TRUE HERE AND FALSE ON EVERYTHING ELSE. That flag
	-- is what stops a frame swallowing the tap underneath it, which on a
	-- touchscreen is the difference between a card you can ignore and one
	-- that eats the tap meant for the hot bar. A button is the one thing in
	-- here that IS the tap, and it is only on screen when the server has just
	-- said it should be.
	--
	-- BOTTOM CENTRE, AND THE BAND WAS MEASURED ON A LIVE HUD RATHER THAN
	-- ARGUED FROM THE LAYOUT NOTES. Swept at 1399x793, everything visible in
	-- the bottom third:
	--
	--     DeliverLoot      y 579..643   x  587..811
	--     HotBar           y 661..715   x  350..1048
	--     BoostPill        y 605..649   x   22..190
	--     GarageSlot/Dodge y 527..595   x   22..242
	--     GaragePicker     y 527..595   x  174..588
	--     CarryingLoot     y 521..585   x 1311..1375
	--     shop / satchel   y 649..713   x 1171..1381
	--
	-- So it clears the hot bar by 18 pixels, and every other row in the band
	-- is either far left or far right of a 224-wide centred button. The
	-- closest thing to it is the garage picker's last tile, which ENDS at
	-- x 588 against this starting at 587 -- one pixel, on a fan that is only
	-- open while a finger is on it.
	--
	-- IT SHARES A BAND WITH THE CRACK PANEL ON PURPOSE, and that is the same
	-- exclusivity the F key below leans on rather than a second risk. The
	-- dial sits at y 553..587 and its three buttons at y 593..627, straight
	-- through this -- and they can never both be up, because `attemptSteal`
	-- refuses while you are carrying and there is nothing to deliver while
	-- you are cracking. This is the band this game already uses for the
	-- moment-to-moment of a robbery, which is what this is.
	--
	-- It is also where a primary action belongs on a touchscreen: reachable
	-- by either thumb, which the top-centre banner saying the same word is
	-- not.
	local deliverBtn = Instance.new("TextButton")
	deliverBtn.Name = "DeliverLoot"
	deliverBtn.Size = UDim2.fromOffset(224, 64)
	deliverBtn.Position = UDim2.new(0.5, 0, 1, -92)
	deliverBtn.AnchorPoint = Vector2.new(0.5, 1)
	deliverBtn.AutoButtonColor = false
	deliverBtn.Text = ""
	deliverBtn.Visible = false
	deliverBtn.ZIndex = 12
	deliverBtn.Parent = gui
	-- GREEN GROUND, GOLD OBJECT, which is the palette rule rather than a
	-- choice. `Theme`'s own line is that gold means money and pink means the
	-- pig, and that both go on OBJECTS and never under them -- so the coin is
	-- drawn on the button and the button is the "good thing happening" green
	-- every other positive action in this game already uses.
	Theme.tinted(deliverBtn, Theme.GOOD, Theme.GOOD:Lerp(Color3.new(), 0.35), 14)

	local deliverCoin = Theme.coin(deliverBtn, 28)
	deliverCoin.Position = UDim2.new(0, 16, 0.5, 0)
	deliverCoin.AnchorPoint = Vector2.new(0, 0.5)
	deliverCoin.ZIndex = 13

	local deliverLabel = Instance.new("TextLabel")
	deliverLabel.Name = "Label"
	deliverLabel.Size = UDim2.new(1, -64, 1, 0)
	deliverLabel.Position = UDim2.fromOffset(56, 0)
	deliverLabel.BackgroundTransparency = 1
	deliverLabel.Text = "DELIVER"
	deliverLabel.ZIndex = 13
	deliverLabel.Parent = deliverBtn
	Theme.title(deliverLabel, 24, Theme.INK)

	local deliverAcorn = Theme.acorn(deliverBtn, 28)
	deliverAcorn.Position, deliverAcorn.AnchorPoint = deliverCoin.Position, deliverCoin.AnchorPoint
	deliverAcorn.ZIndex, deliverAcorn.Visible = 13, false

	-- Both destinations remain legible while running. The existing action
	-- button chooses the destination underfoot, as confirmed by the server.
	local destinations = Instance.new("Frame")
	destinations.Name = "CarryDestinations"
	destinations.Size = UDim2.new(0, 304, 0, 92)
	destinations.Position = UDim2.new(0.5, 0, 1, -164)
	destinations.AnchorPoint = Vector2.new(0.5, 1)
	destinations.Visible, destinations.Active, destinations.ZIndex = false, false, 10
	destinations.Parent = gui
	Theme.card(destinations, 12)
	local function destinationRow(name: string, y: number): TextLabel
		local label = Instance.new("TextLabel")
		label.Name, label.BackgroundTransparency = name, 1
		label.Position, label.Size = UDim2.fromOffset(10, y), UDim2.new(1, -20, 0, 40)
		label.TextWrapped, label.TextScaled, label.ZIndex = true, true, 11
		label.Parent = destinations
		Theme.title(label, 16, Theme.PAPER)
		local limit = Instance.new("UITextSizeConstraint")
		limit.MinTextSize, limit.MaxTextSize, limit.Parent = 11, 16, label
		return label
	end
	local homeRow, returnRow = destinationRow("Keep", 4), destinationRow("Return", 48)
	local carryShown, deliveryReady, crackOpen, shakeOpen = false, false, false, false
	local function updateCarryVisibility()
		local busy = crackOpen or shakeOpen
		destinations.Visible = carryShown and not busy
		deliverBtn.Visible = deliveryReady and not busy
	end
	Remotes.get("CrackState").OnClientEvent:Connect(function(payload)
		crackOpen = payload ~= nil
		updateCarryVisibility()
	end)
	Remotes.get("ShakeState").OnClientEvent:Connect(function(payload)
		shakeOpen = payload ~= nil and payload.ended ~= true
		updateCarryVisibility()
	end)


	-- ONE PATH FOR THE TAP AND THE KEY, so a desktop player and a tablet
	-- player reach the same guard rather than two copies of it.
	--
	-- THE REQUEST CARRIES NOTHING and the server re-derives the plot, the
	-- distance and the haul -- see `deliverRequest` in `HeistService`. The
	-- `Visible` test here is the client declining to ask for a known no,
	-- which is the same split the number keys and the dodge-while-riding
	-- suppression already make; it is not the check that matters.
	local function requestDeliver()
		if not deliverBtn.Visible then
			return
		end
		Remotes.get("DeliverRequest"):FireServer()
	end
	deliverBtn.Activated:Connect(requestDeliver)

	-- F, AND IT IS SAFE FOR THE REASON Q IS SAFE FOR THE DODGE AND THE TRICK:
	-- the two things that share it can never both be live. F is the crack's
	-- dial tap, and `attemptSteal` refuses outright while you are carrying --
	-- so a player with loot in their hands has no crack to tap, and a player
	-- mid-crack is holding nothing to deliver. The button is the primary
	-- route regardless, because most of this audience never presses a key.
	UserInputService.InputBegan:Connect(function(input, typed)
		if typed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F then
			requestDeliver()
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
		deliveryReady, deliverLabel.Text = view.canPress, view.button
		deliverCoin.Visible, deliverAcorn.Visible = kind ~= "basket", kind == "basket"
		carryShown = view.visible
		updateCarryVisibility()
		homeRow.Visible = view.showHome
		returnRow.Visible = view.showReturn or not view.showHome
		homeRow.Text, returnRow.Text = view.home, view.returning
		local both = homeRow.Visible and returnRow.Visible
		destinations.Size = UDim2.fromOffset(304, if both then 92 else 48)
		returnRow.Position = UDim2.fromOffset(10, if both then 48 else 4)
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
	local card = Instance.new("Frame")
	card.Name = "HeistSummary"
	card.Size = UDim2.fromOffset(360, 250)
	card.Position = UDim2.new(0.5, 0, 0.4, 0)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Visible = false
	card.Active = false
	card.ZIndex = 22
	card.Parent = gui
	Theme.card(card, 20)

	local cardScale = Instance.new("UIScale")
	cardScale.Parent = card

	local cardTitle = Instance.new("TextLabel")
	cardTitle.Name = "Title"
	cardTitle.Size = UDim2.new(1, -24, 0, 30)
	cardTitle.Position = UDim2.fromOffset(12, 12)
	cardTitle.BackgroundTransparency = 1
	cardTitle.Text = "DELIVERED"
	cardTitle.ZIndex = 23
	cardTitle.Parent = card
	Theme.title(cardTitle, 24, Theme.INK)

	local cardCoins = Instance.new("TextLabel")
	cardCoins.Name = "Coins"
	cardCoins.Size = UDim2.new(1, -24, 0, 34)
	cardCoins.Position = UDim2.fromOffset(12, 44)
	cardCoins.BackgroundTransparency = 1
	cardCoins.Text = ""
	cardCoins.ZIndex = 23
	cardCoins.Parent = card
	Theme.title(cardCoins, 28, Theme.GOLD_INK)

	local cardNote = Instance.new("TextLabel")
	cardNote.Name = "Note"
	cardNote.Size = UDim2.new(1, -24, 0, 20)
	cardNote.Position = UDim2.fromOffset(12, 78)
	cardNote.BackgroundTransparency = 1
	cardNote.Text = ""
	cardNote.ZIndex = 23
	cardNote.Parent = card
	Theme.body(cardNote, 13, Theme.MUTED)

	local cardItems = Instance.new("Frame")
	cardItems.Name = "Items"
	cardItems.Size = UDim2.new(1, -24, 0, TILE)
	cardItems.Position = UDim2.fromOffset(12, 104)
	cardItems.BackgroundTransparency = 1
	cardItems.Active = false
	cardItems.ZIndex = 23
	cardItems.Parent = card

	local bagButton = Instance.new("TextButton")
	bagButton.Name = "OpenBag"
	bagButton.Size = UDim2.new(1, -24, 0, 36)
	bagButton.Position = UDim2.new(0, 12, 1, -48)
	bagButton.BackgroundColor3 = Theme.HUE.crates
	bagButton.AutoButtonColor = false
	bagButton.Text = "OPEN BAG"
	bagButton.Visible = false
	bagButton.ZIndex = 24
	bagButton.Parent = card
	Theme.title(bagButton, 17, Theme.INK)
	Theme.corner(bagButton, 10)
	Theme.outline(bagButton, 3)

	local summaryToken = 0
	local function hideSummary()
		card.Visible = false
		bagButton.Visible = false
	end

	-- FLIES A COPY, NEVER THE TILE ITSELF. The real tile lives inside a
	-- UIListLayout, so moving it collapses the row it is in -- the same
	-- reason the hot bar's drag ghost is a clone rather than a reparent.
	local function flyTo(from: GuiObject, target: GuiObject?, spin: boolean)
		if not target then
			return
		end
		local ghost = from:Clone()
		ghost.Name = "Flying"
		ghost.AnchorPoint = Vector2.new(0.5, 0.5)
		ghost.Size = UDim2.fromOffset(from.AbsoluteSize.X, from.AbsoluteSize.Y)
		ghost.Position = UDim2.fromOffset(
			from.AbsolutePosition.X + from.AbsoluteSize.X / 2,
			from.AbsolutePosition.Y + from.AbsoluteSize.Y / 2)
		ghost.ZIndex = 40
		ghost.Active = false
		ghost.Parent = gui

		local to = Vector2.new(
			target.AbsolutePosition.X + target.AbsoluteSize.X / 2,
			target.AbsolutePosition.Y + target.AbsoluteSize.Y / 2)
		tween(ghost, FLY, {
			Position = UDim2.fromOffset(to.X, to.Y),
			Size = UDim2.fromOffset(18, 18),
		}, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
		if spin then
			tween(ghost, FLY, { Rotation = 220 })
		end
		task.delay(FLY + 0.05, function()
			ghost:Destroy()
			-- THE LANDING BUMP, ON THE THING IT LANDED IN. Without it the
			-- ghost simply vanishes at the corner and the whole trip reads as
			-- decoration rather than as something ARRIVING somewhere.
			local bump = target:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
			bump.Parent = target
			bump.Scale = 1.22
			tween(bump, 0.24, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
	end

	Remotes.get("HeistDelivered").OnClientEvent:Connect(function(payload: any)
		if type(payload) ~= "table" then
			return
		end
		summaryToken += 1
		local mine = summaryToken

		local items = if type(payload.items) == "table" then payload.items else {}
		cardTitle.Text = if payload.revenge then "REVENGE!" else "DELIVERED"
		cardCoins.Text = ("+%s"):format(Config.formatCoins(payload.banked or 0))

		local bits = {}
		if (payload.run or 0) > 1 then
			table.insert(bits, ("%dx IN A ROW"):format(payload.run))
		end
		-- The pig-crack acorn, on the card as well as in the toast: the one
		-- thing a robbery pays that is not coins, and the reason to rob a
		-- person rather than an empty house.
		if (payload.acorns or 0) > 0 then
			table.insert(bits, ("+%d ACORN%s"):format(payload.acorns, if payload.acorns == 1 then "" else "S"))
		end
		cardNote.Text = table.concat(bits, "   ")

		cardItems:ClearAllChildren()
		-- Rebuilt per delivery rather than kept, because the layout is
		-- cleared with the tiles it owns. One row, centred.
		local itemLayout = Instance.new("UIListLayout")
		itemLayout.FillDirection = Enum.FillDirection.Horizontal
		itemLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		itemLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		itemLayout.Padding = UDim.new(0, 10)
		itemLayout.Parent = cardItems

		local tiles: { Frame } = {}
		for _, item in ipairs(items) do
			if item and item.kind and item.key then
				table.insert(tiles, buildTile(cardItems, item.kind, item.key, TILE, iconFor))
			end
		end
		cardItems.Visible = #tiles > 0
		-- SHORTER WITH NOTHING IN THE MIDDLE OF IT, rather than carrying a
		-- gap where a row of items would have been. Most deliveries are coins
		-- only, and a card sized for the rare case is a card that looks
		-- half-empty almost every time it appears.
		card.Size = UDim2.fromOffset(360, if #tiles > 0 then 250 else 154)
		bagButton.Visible = #tiles > 0 and openBag ~= nil

		-- NO SOUND HERE, AND THAT IS A DUPLICATE REMOVED RATHER THAN AN
		-- OVERSIGHT. `PlotService.playBank` already plays the bank cue in 3D
		-- at the pig on the server, and the player is standing inside
		-- `DROPOFF_RADIUS` of it -- so a 2D copy fired from the client was the
		-- same sound twice in the same instant, which reads as a stutter
		-- rather than as emphasis. The 3D one is also the better of the two
		-- here: it is where the coins are going.

		card.Visible = true
		cardScale.Scale = 0.7
		tween(cardScale, SUMMARY_IN, { Scale = 1 }, Enum.EasingStyle.Back)

		-- THE COINS GO TO THE PIG AND THE ITEMS GO TO THE BAG, which is the
		-- whole reason this is a panel rather than a bigger toast: a number
		-- appearing on screen is a fact, and a number ARRIVING SOMEWHERE is
		-- where it went. The two ends are deliberately different KINDS of
		-- place -- the bag is a HUD button because that is where an item
		-- lives, and the pig is twelve studs of geometry on the lawn the
		-- player is standing on, because that is where the money lives.
		task.delay(SUMMARY_IN + 0.35, function()
			if summaryToken ~= mine then
				return
			end
			rushCoins(payload.bank)

			local satchel = anchor("BagToggle")
			if #tiles > 0 and not satchel then
				warn("[LootHaul] no BagToggle to fly the items into")
			end
			for i, tile in ipairs(tiles) do
				task.delay(0.18 * (i - 1) + 0.25, function()
					if summaryToken == mine then
						flyTo(tile, satchel, true)
					end
				end)
			end
		end)

		task.delay(SUMMARY_IN + SUMMARY_HOLD, function()
			if summaryToken == mine then
				tween(cardScale, 0.2, { Scale = 0.8 })
				task.delay(0.2, function()
					if summaryToken == mine then
						hideSummary()
					end
				end)
			end
		end)
	end)

	bagButton.Activated:Connect(function()
		-- Bumping the token cancels this summary's own pending fade, so the
		-- card cannot reappear behind the bag it just opened.
		summaryToken += 1
		hideSummary()
		if openBag then
			openBag()
		end
	end)
end

return LootHaul
