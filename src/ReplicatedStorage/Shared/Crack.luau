--!strict
--
-- THE CRACK PANEL -- THE GREED DIAL, DRAWN.
--
-- The one moment in this game where standing still is the point, so it is the
-- one moment that has to be worth looking at. Two readouts, and they answer
-- two different questions:
--
--   * THE PIG, DRAINING. A gauge that starts full of the victim's coins and
--     empties as slices come out of it, with what you are holding printed on
--     one side and what is left in it on the other. This is the GREED half:
--     it is the thing you are deciding about, and the fact that it visibly
--     goes down is what makes taking one more feel like taking one more.
--   * THE DIAL. A marker sweeping a track with a target zone on it. This is
--     the SKILL half, and the two trees pull on it from either end -- the
--     victim's Vault Lock narrows the zone, the thief's Lockpicks widen it.
--
-- THE BAR IS THE PIG AND NOT THE ALLOWANCE, which was the first version and
-- was wrong. Drawing `Config.LOSS_CAP`'s remaining allowance as the whole bar
-- makes the gauge mean "how much of what I am permitted", which is a rule a
-- nine-year-old has never been told and cannot see. Drawing the PIG means the
-- gauge is a picture of the object in front of them, and the cap is a RED
-- LINE across it: you can dig this far and no further. A resident has no cap,
-- so its line sits at the bottom and the bar can empty completely -- which is
-- the difference between an empty house and a real child, drawn rather than
-- explained.
--
-- NOTHING HERE DECIDES ANYTHING. The server owns the clock, the zone, the
-- slice and whether a tap landed; `CrackTap` carries no arguments at all. All
-- this module does is render the schedule it is handed and send the moment a
-- finger goes down. The marker is drawn from `workspace:GetServerTimeNow`
-- against the `startedAt` in that schedule, so both ends are reading one
-- clock rather than two that have to be kept in step.
--
-- A MODULE, NOT A SECTION OF ClientMain, for the reason HouseFX, HotBar,
-- RobBadge and AdminPanel are: that chunk is at Luau's 200-local ceiling and
-- has twice died naming an innocent variable two thousand lines from the
-- change that caused it. A module body gets its own register file, so this
-- costs ClientMain one statement holding no local at all.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local SoundKit = require(ReplicatedStorage.Shared.SoundKit)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)

local Crack = {}

-- Measured against the shortest thing that has to work, a phone held
-- sideways at 546 tall. The panel is centred horizontally and sits 96 above
-- the bottom edge: the hot bar occupies 20..74 there and grows upward with
-- however many throwables are held, so this clears its tallest state by 22.
-- Bottom-LEFT is four rows deep to 250 and bottom-RIGHT holds the shop, and
-- neither reaches the middle of the screen at any viewport this supports.
local WIDTH = 430
local LIFT = 96

-- The dial's own height, and the marker's width. The marker is deliberately
-- FAT: a one-pixel needle is a thing you chase, and at 8 it is a thing you
-- catch. It also has to be visible against the zone it is standing in, which
-- is why it is ink on colour rather than colour on colour.
local DIAL_H = 34
local MARKER_W = 8

local ui: {
	root: Frame,
	title: TextLabel,
	step: TextLabel,
	held: TextLabel,
	left: TextLabel,
	fill: Frame,
	line: Frame,
	zone: Frame,
	marker: Frame,
	nextSlice: Frame,
	slice: TextLabel,
	tap: TextButton,
	stop: TextButton,
}? = nil

local state: any = nil
local heartbeat: RBXScriptConnection? = nil

local function tap()
	if state then
		Remotes.get("CrackTap"):FireServer()
	end
end

local function stop()
	if state then
		Remotes.get("CrackStop"):FireServer()
	end
end

local function build(parent: Instance)
	local root = Instance.new("Frame")
	root.Name = "CrackPanel"
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.new(0.5, 0, 1, -LIFT)
	root.Size = UDim2.new(0, WIDTH, 0, 176)
	root.Visible = false
	root.ZIndex = 6
	root.Parent = parent
	Theme.card(root)

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = root

	-- ---- header ------------------------------------------------------
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -70, 0, 20)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = ""
	title.Parent = root
	Theme.title(title, 16)

	local step = Instance.new("TextLabel")
	step.Name = "Step"
	step.Size = UDim2.new(0, 70, 0, 20)
	step.Position = UDim2.new(1, -70, 0, 0)
	step.TextXAlignment = Enum.TextXAlignment.Right
	step.Text = ""
	step.Parent = root
	Theme.body(step, 13, Theme.MUTED)

	-- ---- the pig, draining -------------------------------------------
	--
	-- A groove one step under the ground with the remaining coins drawn in
	-- gold on it. The same vocabulary as an unbought upgrade pip and the
	-- event countdown bar: ink on a groove, never paper on paper.
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.new(1, -34, 0, 26)
	track.Position = UDim2.new(0, 34, 0, 28)
	track.BackgroundColor3 = Theme.PIG_DEEP
	track.BorderSizePixel = 0
	track.ZIndex = 6
	track.Parent = root
	Theme.corner(track, 8)
	Theme.outline(track, Theme.OUTLINE_THIN)

	-- The snout stands OUTSIDE the track rather than on it, because the
	-- track is pink and a pink snout on a pink bar is the "an accent spent
	-- on a ground is an accent spent" failure the piggy bank panel already
	-- recorded. Here the pink IS the empty bar, so the pig object goes
	-- beside it.
	local snout = Theme.snout(root, 26, "Snout")
	snout.Position = UDim2.new(0, 0, 0, 30)
	snout.ZIndex = 6

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Theme.GOLD
	fill.BorderSizePixel = 0
	fill.ZIndex = 7
	fill.Parent = track
	Theme.corner(fill, 8)
	Theme.gloss(fill, Theme.GOLD, Theme.GOLD_DEEP)

	-- WHAT THE NEXT TAP WOULD TAKE, drawn on the gauge rather than only
	-- printed under it. A slice is a fixed share of the pig as it was when
	-- the attempt opened, so it is a fixed WIDTH here -- and each one is 1.4x
	-- the last, so the segment visibly grows every time somebody decides to
	-- stay. That growth IS the greed dial: the step you are deciding about is
	-- always the biggest one you have been offered, and this is the only
	-- place that fact is a picture rather than a number.
	local nextSlice = Instance.new("Frame")
	nextSlice.Name = "NextSlice"
	nextSlice.Size = UDim2.fromScale(0, 1)
	nextSlice.BackgroundColor3 = Theme.GOLD_DEEP
	nextSlice.BorderSizePixel = 0
	nextSlice.ZIndex = 8
	nextSlice.Visible = false
	nextSlice.Parent = track
	Theme.corner(nextSlice, 8)

	-- WHERE THE LOSS CAP STOPS YOU. Drawn on TOP of the fill, because it is
	-- a mark on the pig rather than a section of it -- and in alarm red,
	-- which is the one colour on this panel that means "no further".
	local line = Instance.new("Frame")
	line.Name = "CapLine"
	line.Size = UDim2.new(0, 3, 1, 0)
	line.BackgroundColor3 = Theme.STOP
	line.BorderSizePixel = 0
	line.ZIndex = 8
	line.Visible = false
	line.Parent = track

	local held = Instance.new("TextLabel")
	held.Name = "Held"
	held.Size = UDim2.new(0.5, 0, 0, 16)
	held.Position = UDim2.new(0, 34, 0, 56)
	held.TextXAlignment = Enum.TextXAlignment.Left
	held.Text = ""
	held.Parent = root
	Theme.body(held, 12, Theme.GOLD_INK)

	local left = Instance.new("TextLabel")
	left.Name = "Left"
	left.Size = UDim2.new(0.5, -34, 0, 16)
	left.Position = UDim2.new(0.5, 0, 0, 56)
	left.TextXAlignment = Enum.TextXAlignment.Right
	left.Text = ""
	left.Parent = root
	Theme.body(left, 12, Theme.MUTED)

	-- ---- the dial ----------------------------------------------------
	--
	-- THE WHOLE DIAL IS THE TAP TARGET, and that is not laziness. Most of
	-- this audience is on a tablet, the marker is eight pixels wide, and a
	-- control you have to hit a moving eight-pixel target to press is a
	-- second reaction test stacked on the one the game is asking for. You
	-- press anywhere on the track; WHEN is the whole question.
	local dial = Instance.new("TextButton")
	dial.Name = "Dial"
	dial.Size = UDim2.new(1, 0, 0, DIAL_H)
	dial.Position = UDim2.new(0, 0, 0, 78)
	dial.BackgroundColor3 = Theme.SAND_DEEP
	dial.BorderSizePixel = 0
	dial.Text = ""
	dial.AutoButtonColor = false
	dial.ZIndex = 6
	dial.Parent = root
	Theme.corner(dial, 8)
	Theme.outline(dial, Theme.OUTLINE_THIN)

	local zone = Instance.new("Frame")
	zone.Name = "Zone"
	zone.Size = UDim2.fromScale(0, 1)
	zone.BackgroundColor3 = Theme.GOOD
	zone.BorderSizePixel = 0
	zone.ZIndex = 7
	zone.Parent = dial
	Theme.corner(zone, 8)

	local marker = Instance.new("Frame")
	marker.Name = "Marker"
	marker.Size = UDim2.new(0, MARKER_W, 1, 6)
	marker.Position = UDim2.new(0, 0, 0, -3)
	marker.AnchorPoint = Vector2.new(0.5, 0)
	marker.BackgroundColor3 = Theme.INK
	marker.BorderSizePixel = 0
	marker.ZIndex = 8
	marker.Parent = dial
	Theme.corner(marker, 3)

	-- ---- action row --------------------------------------------------
	local slice = Instance.new("TextLabel")
	slice.Name = "Slice"
	slice.Size = UDim2.new(1, -230, 0, 34)
	slice.Position = UDim2.new(0, 0, 0, 118)
	slice.TextXAlignment = Enum.TextXAlignment.Left
	slice.Text = ""
	slice.Parent = root
	Theme.body(slice, 12, Theme.MUTED)

	local function actionButton(name: string, text: string, top: Color3,
		ink: Color3, width: number, x: number): TextButton
		local b = Instance.new("TextButton")
		b.Name = name
		b.Size = UDim2.new(0, width, 0, 34)
		b.Position = UDim2.new(1, x, 0, 118)
		b.Text = text
		b.AutoButtonColor = false
		b.ZIndex = 7
		b.Parent = root
		Theme.title(b :: any, 15, ink)
		b.BackgroundTransparency = 0
		b.BackgroundColor3 = top
		b.BorderSizePixel = 0
		Theme.corner(b, 10)
		Theme.outline(b)
		-- `shade` and never `gloss` on a saturated fill carrying dark type:
		-- gloss runs to a COLOUR and can take ink under the floor, shade
		-- multiplies and cannot. The rebirth button already records this.
		Theme.shade(b, 0.16)
		return b
	end

	-- TAKE IT sits to the LEFT of CRACK, because the loud one belongs under
	-- the thumb that is already there and a bail button next to the screen
	-- edge is the one a panicking nine-year-old reaches for by mistake.
	local stopBtn = actionButton("Stop", "TAKE IT", Theme.PAPER_DEEP, Theme.INK, 100, -222)
	local tapBtn = actionButton("Tap", "CRACK!", Theme.GOLD, Theme.INK, 116, -116)

	ui = {
		root = root,
		title = title,
		step = step,
		held = held,
		left = left,
		fill = fill,
		line = line,
		nextSlice = nextSlice,
		zone = zone,
		marker = marker,
		slice = slice,
		tap = tapBtn,
		stop = stopBtn,
	}

	dial.Activated:Connect(tap)
	tapBtn.Activated:Connect(tap)
	stopBtn.Activated:Connect(stop)
end

-- Repaints everything that only changes when the server says so.
local function render()
	local u = ui
	if not u then
		return
	end
	if not state then
		u.root.Visible = false
		return
	end

	local pig = math.max(1, state.pig)
	local remaining = math.max(0, pig - state.banked)

	u.root.Visible = true
	-- A NAME THAT ALREADY ENDS IN S TAKES A BARE APOSTROPHE, which is the
	-- ordinary English rule and was not being followed. It went unnoticed
	-- while every victim was a player or a family -- "THE SNUFFLES'S PIGGY"
	-- is clumsy and readable -- and the shops made it loud, because a shop's
	-- money is named after the shop: "PIGGY OUTFITTERS'S PIGGY". Fixed here
	-- rather than in the names, since the names are correct and it is the
	-- possessive that was wrong.
	local name = state.victim
	local tail = if name:sub(-1):lower() == "s" then "'" else "'s"
	u.title.Text = string.upper(("%s%s piggy"):format(name, tail))
	u.step.Text = ("SLICE %d / %d"):format(state.step, state.maxSteps)
	u.fill.Size = UDim2.fromScale(math.clamp(remaining / pig, 0, 1), 1)
	u.held.Text = ("You hold %s"):format(Config.formatCoins(state.banked))
	u.left.Text = ("%s left"):format(Config.formatCoins(remaining))

	-- The cap line only exists when there IS a cap. A resident's floor is
	-- zero and drawing a line hard against the left edge would say "you can
	-- empty this" in the one visual language that means "you cannot".
	local floor = state.floor or 0
	u.line.Visible = floor > 0
	u.line.Position = UDim2.new(math.clamp(floor / pig, 0, 1), -1, 0, 0)

	-- The next slice sits at the RIGHT-HAND end of what is left, because that
	-- is the coins it would come out of -- the fill shrinks from the right,
	-- so this is the piece about to go.
	local width = math.clamp(state.slice / pig, 0, 1)
	local from = math.clamp(remaining / pig - width, 0, 1)
	u.nextSlice.Visible = state.slice > 0 and remaining > 0
	u.nextSlice.Position = UDim2.fromScale(from, 0)
	u.nextSlice.Size = UDim2.new(math.min(width, 1 - from), 0, 1, 0)

	u.zone.Position = UDim2.fromScale(state.zone, 0)
	u.zone.Size = UDim2.new(state.width, 0, 1, 0)
	u.slice.Text = ("Next slice %s"):format(Config.formatCoins(state.slice))
end

-- The marker, and only the marker. Everything else is push-driven, so this
-- writes ONE property a frame.
local function step()
	local u, st = ui, state
	if not u or not st then
		return
	end
	local sweep = st.sweep
	local phase = (workspace:GetServerTimeNow() - st.startedAt) % (sweep * 2)
	local at = if phase <= sweep then phase / sweep else 2 - phase / sweep
	u.marker.Position = UDim2.new(math.clamp(at, 0, 1), 0, 0, -3)
end

function Crack.start(gui: Instance)
	build(gui)

	-- WHAT THE LAST PUSH SAID, so a slice landing can be told from any
	-- other reason this payload arrives. `CrackState` is pushed on the
	-- open, on every tap, on a walk-away and on a miss -- so "a slice
	-- landed" is not an event the server sends, it is a STEP THAT WENT UP,
	-- and the only way to see it is to remember the last one.
	local lastStep = 0

	Remotes.get("CrackState").OnClientEvent:Connect(function(payload, why)
		-- THE LADDER. A note per slice, rising, and the reasoning for the
		-- intervals is in `Config.CRACK_NOTES` -- the short version is that
		-- these are equal-tempered pentatonic steps rather than the even
		-- FREQUENCY steps this used to use, which is the difference between
		-- a tune and a slide.
		--
		-- 2D THROUGH `SoundKit.ui`, WHICH IS LOAD-BEARING RATHER THAN
		-- CONVENIENT. It plays into SoundService, so it is audible to the
		-- thief and to nobody else. A 3D note on the pig would be a tell that
		-- a CLEAN crack currently does not give -- `Config.CRACK`'s whole
		-- alarm design is that a fumble is loud and a clean run is silent,
		-- and stealth of the alarm is the thing a good thief is buying. A
		-- rising musical run audible from the pavement would sell that for a
		-- sound effect.
		--
		-- `landed`, NOT `step`, AND THE NAME IS THE WHOLE BUG.
		--
		-- This was `local step`, twelve lines above a
		-- `RenderStepped:Connect(step)` that means the module-level FUNCTION
		-- of that name. Lua resolves the nearest one, so the connect was
		-- handed the slice NUMBER: "Attempt to connect failed: Passed value
		-- is not a function", once per push, on the one loop that moves the
		-- marker.
		--
		-- SO THE DIAL NEVER SWEPT. The panel opened, the gauge drew, the zone
		-- was in the right place and the marker sat at 0 forever -- every
		-- crack in the game, since the day the crack shipped. A tap could
		-- only ever land if the zone happened to touch the left edge, which
		-- `CRACK_MIN_OFFSET` exists specifically to prevent.
		--
		-- It is not the `RenderStepped` trap this project already records --
		-- that one is about a viewport not drawing and would have been
		-- environmental. This fires in every session on every machine, and
		-- the error names a LINE rather than the shadowing, which is why it
		-- read as a Studio quirk for as long as it did.
		local landed = (payload and payload.step) or 0
		if landed > lastStep then
			SoundKit.ui(Config.SOUNDS.CLICK, {
				name = "CrackSlice",
				volume = Config.CRACK_NOTES.volume,
				pitch = Config.crackNotePitch(landed),
			})
		end

		-- THE TOP OF THE RUN NEVER PLAYED, AND THAT IS A BUG RATHER THAN A
		-- CHOICE. `crackTap` lands the final slice and goes straight to
		-- `endCrack("done")`, which RETURNS before the `pushCrack` at the
		-- bottom of that function -- so the client is never told about the
		-- last step, only that the panel closed. The ladder therefore sounded
		-- four notes on a five-slice crack and the biggest, most valuable,
		-- most-decided-upon slice in the game was the silent one.
		--
		-- Played here off the close rather than fixed on the server, because
		-- the server is RIGHT: there is no state left to push once the
		-- attempt is over, and inventing one so a sound could hang off it
		-- would be a payload that exists for the client's benefit only.
		if not payload and why == "done" then
			SoundKit.ui(Config.SOUNDS.CLICK, {
				name = "CrackDone",
				volume = Config.CRACK_NOTES.volume,
				pitch = Config.crackNotePitch(Config.CRACK.maxSteps),
			})
		elseif not payload and why == "miss" then
			-- A FALL, and only on a MISS. Walking away is silent because
			-- nothing went wrong and the player chose it; being nabbed,
			-- chased, scared off or walking out of range are all endings the
			-- WORLD already makes a noise for.
			SoundKit.ui(Config.SOUNDS.CLICK, {
				name = "CrackMiss",
				volume = Config.CRACK_NOTES.missVolume,
				pitch = Config.semitonePitch(Config.CRACK_NOTES.miss),
			})
		end

		lastStep = landed

		state = payload
		render()
		if state and not heartbeat then
			heartbeat = RunService.RenderStepped:Connect(step)
		elseif not state and heartbeat then
			-- Disconnected rather than left running against a nil state: the
			-- panel is closed for most of a session and a per-frame handler
			-- that early-outs is still a per-frame handler.
			heartbeat:Disconnect()
			heartbeat = nil
		end
	end)

	-- F CRACKS AND ESCAPE TAKES WHAT YOU HAVE, and the map was checked before
	-- either was claimed: Q dodge/trick, B shop, V garage, R radio, I bag,
	-- Escape close, F2 admin, 1-0 the hot bar. F was free.
	--
	-- Escape is deliberately reused rather than given a key of its own. It
	-- already means "close this" everywhere else here, and walking away with
	-- what you have banked IS closing this -- there is nothing to lose by
	-- pressing it, which is exactly what the word cancel should mean.
	--
	-- Both are the secondary route. The BUTTONS are primary: most of this
	-- audience never presses a key at all, and this is the one panel in the
	-- game with a timing test on it.
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not state then
			return
		end
		if input.KeyCode == Enum.KeyCode.F then
			tap()
		elseif input.KeyCode == Enum.KeyCode.Escape then
			stop()
		end
	end)
end

return Crack
