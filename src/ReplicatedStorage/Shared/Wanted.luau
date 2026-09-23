--!strict
--
-- THE SESSION ARC, ON SCREEN. It has existed for months and had never been
-- drawn.
--
-- The rap sheet, the Most Wanted board and the pursuit floor already model an
-- arc across a session: take more, lead the board, draw a patrol. Every part
-- of that was built, tuned and argued about -- and the only places any of it
-- ever surfaced were a poster standing somewhere on the street and a handful
-- of toasts that are gone in six seconds. So the one system in this game that
-- gives a session a SHAPE was invisible during the session it was shaping.
--
-- SAME FAULT AS THE STANDING EVENT COUNTDOWN, WHICH IS THE CHIP DIRECTLY
-- ABOVE THIS ONE. That was a display nobody had written rather than a
-- mechanism nobody had built -- `EventService` was already pushing the whole
-- countdown and the client was dropping it on the floor. This is the same
-- shape one step further along: the mechanism was there, the numbers were
-- there, and there was no channel and no chip.
--
-- IT IS THE SECOND CHIP IN THE TOP-RIGHT COLUMN, AND THAT IS A STATEMENT
-- ABOUT WHAT KIND OF THING IT IS. The top-centre column is ALERTS -- things
-- that just happened. This corner is STANDING READOUTS: the piggy bank panel
-- says what you have, the event chip says what the street is about to do, and
-- this says what you have done and whether it has consequences yet. A player
-- glances at one place to read their own situation.
--
-- A MODULE, NOT A SECTION OF ClientMain, for the reason FirstJob, RobBadge,
-- HouseFX, HotBar and AdminPanel are: that chunk sits at Luau's 200-local
-- ceiling and has taken the ENTIRE HUD down twice over four locals. A module
-- body gets its own register file, so this costs the chunk one require and no
-- top-level local at all.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)

local Wanted = {}

-- DIRECTLY UNDER THE PIGGY BANK PANEL, AND EVERY NUMBER HERE IS ITS
-- NEIGHBOUR'S. Sharing the width is what makes the two read as a column
-- rather than as two things that happen to be near each other, and moving one
-- without the other breaks the only thing holding the column together.
--
-- THE NEIGHBOUR USED TO BE AN ACORN CHIP hanging off the bottom of that
-- panel, 176 x 34, and this started 8px under IT. The chip went with the
-- currency, so the panel is about four design pixels shorter than it was --
-- under a tenth of that on screen once the panel's own scale is applied.
-- `TOP` is left where it is rather than re-derived by arithmetic nobody has
-- looked at: it wants a photograph of the top-right column before it moves.
-- (The event countdown was the neighbour above until it moved into the left
-- menu rail; PiggyPanel still drives this chip's position.)
local WIDTH = 176
local ROW = 34
-- 224 rather than 196: the piggy panel above grew to a 92-tall card with a
-- pig overhanging it to offset 174, and the event chip moved to 182. This
-- keeps the 8px gap the whole top-right column is spaced on.
local TOP = 224

-- THE RUN IS FIVE STARS ON A ROW OF ITS OWN, BECAUSE THE ONE ABOVE IT IS
-- FULL.
--
-- A badge, a caption and a coin figure already spend all 176 pixels of the
-- first row -- measured, the gap between the caption and the amount is 20px,
-- which holds nothing. So the chip is taller than its neighbour rather than
-- trying to fit a fifth thing into a row that has no room. It keeps the same
-- x and the same width, which is what actually makes the column read as a
-- column; matching heights was never the thing doing that work.
--
-- STARS, NOT PIPS (designer decision 2026-09-22). A pip is a ladder rung
-- and reads as "how far along"; a star is the thing this readout is
-- actually about, because the street's whole vocabulary for a wanted thief
-- is stars. Five of them at chip size, with the fill DRAINING out of the
-- newest one over the fade window rather than blinking off, so a run is
-- visibly running out rather than suddenly one shorter.
--
-- THE GEOMETRY: a star is TWO SQUARES, one square-on and one turned 45
-- degrees, which is an eight-pointed star -- the same trick `Theme.gear`
-- uses for its teeth, since `Rotation` is the only rotation Roblox UI has.
-- Not a text glyph, deliberately: U+2605 has never been rendered and
-- measured in this project's fonts, and CLAUDE.md's record is that half the
-- obvious dingbats draw a tofu box and the emoji forms ignore `TextColor3`.
-- Two frames cannot be a tofu box and take the palette by construction.
--
-- THE ARITHMETIC OF THE ROW: a 14px box on a 22px pitch is 5 x 14 + 4 x 8 =
-- 102px, inside the 152 the chip has between its 12px pads. The turned
-- square is 0.85 of the box, so its corners are the four axis points and
-- stand 14 x (0.85 x sqrt 2 - 1) / 2 = 1.4px proud of the box; the
-- square-on square's own corners are the four diagonal points and stay
-- inside it. So a star is 16.8 across and neighbouring tips clear each
-- other by 5px. The star row is 18 tall so a 14px box sits 2px in from
-- the chip's bottom edge with the axis points into the pad.
local STAR = 14
local STAR_GAP = 8
local STAR_ROW = 18
local STAR_PAD = 12
local DIAGONAL = 0.85
local HEIGHT = ROW + STAR_ROW

-- THE THREE CAPTIONS ARE THE SAME LENGTH ON PURPOSE, AND THEY WERE MEASURED
-- RATHER THAN CHOSEN.
--
-- The obvious wording does not fit: at TextSize 12 in GothamBold "MOST
-- WANTED" measures 88 and "PATROL COMING" measures 96, against a caption box
-- of 82. Both would have been silently shrunk by TextScaled or clipped
-- without it -- the failure this file's own note about `TextBounds` describes,
-- where "it fits" is guaranteed and means nothing.
--
-- Three six-letter words measure 44, 52 and 49, so the chip never jitters as
-- it changes state, and THE RING CARRIES THE ESCALATION instead. That is the
-- event chip's own trick one step further: it keeps a muted ring for fourteen
-- minutes and turns gold in the last one.
local CAPTION = {
	quiet = "STOLEN",
	leading = "WANTED",
	hunted = "HUNTED",
}

local started = false

-- HOW FULL EACH STAR IS, DERIVED FROM THE SERVER'S OWN STAMP.
--
-- `count` stars were true as of `quiet` seconds ago, and one star drains per
-- `fade` seconds of quiet -- the NEWEST first, from full to empty, then the
-- next. Star i (1-based, oldest first) therefore holds
-- `count - i + 1 - quiet / fade`, clamped to a unit: the newest star has one
-- window in hand, the one under it two, and so on. At exactly `quiet = fade`
-- the newest reads 0.00 and `Config.starsAfterQuiet` drops it on the server
-- in the same instant, which is the whole point of deriving both ends from
-- one stamp -- the picture and the rule cannot disagree, because they are
-- the same subtraction. A delivery re-stamps `at`, so the row refills.
--
-- `pinned` is the Most Wanted player, whose five stars are held full by the
-- server (`SocialService.starsOf`) and do not drain until the board changes
-- hands. The client draws that as five full stars and no motion; it does not
-- decide it.
--
-- Pure, so the suite can hold it against `Config.starsAfterQuiet` without an
-- Instance in sight.
function Wanted.fills(max: number, count: number, quiet: number, fade: number, pinned: boolean?): { number }
	local out = table.create(max)
	for i = 1, max do
		if pinned then
			out[i] = 1
		elseif i > count then
			out[i] = 0
		else
			out[i] = math.clamp(count - i + 1 - math.max(quiet, 0) / fade, 0, 1)
		end
	end
	return out
end

-- Two rotated squares, sized as a fraction of the star's box. Used twice
-- per star: once in the groove colour at full size for the empty star, and
-- once in gold, scaled by the fill, on top of it.
local function square(parent: Instance, name: string, rotation: number, colour: Color3, z: number): Frame
	local piece = Instance.new("Frame")
	piece.Name = name
	piece.AnchorPoint = Vector2.new(0.5, 0.5)
	piece.Position = UDim2.fromScale(0.5, 0.5)
	piece.Rotation = rotation
	piece.BackgroundColor3 = colour
	piece.BorderSizePixel = 0
	piece.ZIndex = z
	piece.Parent = parent
	Theme.corner(piece, 2)
	return piece
end

-- One star: an empty GROOVE, which is the unbought-rung colour the upgrade
-- pips already settled (a well holds a rendered model and wants to be a
-- hole; an empty rung is a groove, one step under the ground), with a GOLD
-- fill drawn over it. The fill is a second pair of squares scaled by how
-- full the star is, so draining is the gold shrinking into the centre of the
-- groove -- no clipping, which `ClipsDescendants` does not do to rotated
-- children anyway.
local function buildStar(parent: Instance, index: number): Frame
	local star = Instance.new("Frame")
	star.Name = ("Star%d"):format(index)
	star.BackgroundTransparency = 1
	star.Size = UDim2.fromOffset(STAR, STAR)
	star.Position = UDim2.fromOffset((index - 1) * (STAR + STAR_GAP), 0)
	star.Parent = parent

	local groove = square(star, "GrooveA", 0, Theme.SAND_DEEP, 2)
	groove.Size = UDim2.fromScale(1, 1)
	local grooveB = square(star, "GrooveB", 45, Theme.SAND_DEEP, 2)
	grooveB.Size = UDim2.fromScale(DIAGONAL, DIAGONAL)

	local fill = square(star, "FillA", 0, Theme.GOLD, 3)
	fill.Size = UDim2.fromScale(1, 1)
	local fillB = square(star, "FillB", 45, Theme.GOLD, 3)
	fillB.Size = UDim2.fromScale(DIAGONAL, DIAGONAL)
	return star
end

-- Paints one star's fill. A fill under a pixel is hidden outright rather
-- than drawn as a speck, which is what a zero-sized rotated frame's corner
-- radius would otherwise leave.
local function paintStar(star: Frame, fill: number)
	local a = star:FindFirstChild("FillA") :: Frame?
	local b = star:FindFirstChild("FillB") :: Frame?
	if not a or not b then
		return
	end
	local visible = fill * STAR >= 1
	a.Visible = visible
	b.Visible = visible
	if visible then
		a.Size = UDim2.fromScale(fill, fill)
		b.Size = UDim2.fromScale(fill * DIAGONAL, fill * DIAGONAL)
	end
end

local function build(parent: ScreenGui): Frame
	local chip = Instance.new("Frame")
	chip.Name = "Wanted"
	chip.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	chip.Position = UDim2.new(1, -18, 0, TOP)
	chip.AnchorPoint = Vector2.new(1, 0)
	chip.Visible = false
	chip.Parent = parent
	-- PAPER, like its neighbour. A saturated ground would read as an alarm,
	-- and this is furniture for most of a session; it earns its colour in the
	-- ring when the patrol is actually coming.
	Theme.card(chip, 12)

	-- THE LOOT TOAST'S OWN GLYPH, BORROWED RATHER THAN CHOSEN. It is already
	-- in `Config`'s ICON table and was rendered and measured when the notify
	-- icons were -- the rule being that half the obvious dingbats are simply
	-- not in Roblox's font, and a tofu box measures like a character.
	--
	-- `NOTIFY.loot` and not `NOTIFY.money`: money is the BANK, which is where
	-- coins are put, and a rap sheet counts what was TAKEN. Reading it off the
	-- toast that reports the same event is also what stops the two drifting.
	local badge = Instance.new("TextLabel")
	badge.Name = "Badge"
	badge.Size = UDim2.new(0, 26, 0, 26)
	badge.Position = UDim2.new(0, 7, 0, ROW / 2)
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.TextSize = 15
	badge.Text = Config.NOTIFY.loot.glyph
	badge.Parent = chip
	Theme.chip(badge, 26, Theme.MUTED)

	local caption = Instance.new("TextLabel")
	caption.Name = "Caption"
	caption.Size = UDim2.new(0, 52, 0, ROW)
	caption.Position = UDim2.new(0, 40, 0, 0)
	caption.TextXAlignment = Enum.TextXAlignment.Left
	caption.Text = CAPTION.quiet
	caption.Parent = chip
	Theme.title(caption, 12, Theme.MUTED)

	-- 56 WIDE, WHICH IS WIDER THAN THE EVENT CHIP'S OWN VALUE BOX AND HAD TO
	-- BE. That one holds a clock ("14:29") and 44 is plenty; this holds coins,
	-- and measured at TextSize 17 "888.8K" is 55 and "999.9M" is 54. At 44
	-- every large sheet in the game would have been quietly shrunk.
	local amount = Instance.new("TextLabel")
	amount.Name = "Amount"
	amount.Size = UDim2.new(0, 56, 0, ROW)
	amount.Position = UDim2.new(1, -8, 0, 0)
	amount.AnchorPoint = Vector2.new(1, 0)
	amount.TextXAlignment = Enum.TextXAlignment.Right
	amount.Text = ""
	amount.Parent = chip
	Theme.title(amount, 17, Theme.INK)

	-- THE RING SAYS WHAT THE STREET THINKS OF YOU AND THE STARS SAY HOW HOT
	-- YOU ARE RIGHT NOW, which are genuinely two facts. Same split as an
	-- upgrade card, where the outline says which tree and the pill says
	-- whether you can afford it: two signals, two places, neither having to
	-- carry the other's meaning.
	local run = Instance.new("Frame")
	run.Name = "Run"
	run.BackgroundTransparency = 1
	run.Position = UDim2.new(0, STAR_PAD, 1, -STAR_ROW + 2)
	run.Size = UDim2.new(1, -STAR_PAD * 2, 0, STAR)
	run.Parent = chip

	return chip
end

-- Built on the first push rather than at construction, because how many there
-- are is the SERVER'S to say -- `Config.WANTED_STARS.max` arrives in the payload
-- so the chip cannot disagree with the ladder it is drawing. Rebuilt only when
-- the count changes, which is the same rule the upgrade rows follow: repainting
-- is a size per star, and tearing the row down on every push would rebuild it
-- every five seconds forever.
local function ensureStars(run: Frame, count: number)
	if #run:GetChildren() == count then
		return
	end
	run:ClearAllChildren()
	for i = 1, count do
		buildStar(run, i)
	end
end

function Wanted.start(parent: ScreenGui)
	if started then
		return
	end
	started = true

	local chip = build(parent)
	local badge = chip:FindFirstChild("Badge") :: TextLabel
	local caption = chip:FindFirstChild("Caption") :: TextLabel
	local amount = chip:FindFirstChild("Amount") :: TextLabel
	local run = chip:FindFirstChild("Run") :: Frame
	local ring = badge:FindFirstChildOfClass("UIStroke")

	-- WHAT THE LAST PUSH SAID ABOUT THE STARS, kept so the drain can be drawn
	-- between pushes. The server publishes a COUNT and a STAMP -- the
	-- `workspace:GetServerTimeNow()` at which that count became true -- and
	-- nothing per frame; this end derives the picture, which is the same
	-- shape the crack's marker and the herd's dig take. `fade` is read off
	-- `Config` here and off the same table on the server, so the drain and
	-- the drop share one constant by construction.
	local latest = { max = 0, count = 0, at = 0, pinned = false }
	local painted: { number } = {}

	local function paint()
		local fade = Config.WANTED_STARS.fade
		local quiet = workspace:GetServerTimeNow() - latest.at
		local fills = Wanted.fills(latest.max, latest.count, quiet, fade, latest.pinned)
		for i, star in ipairs(run:GetChildren()) do
			local index = tonumber(star.Name:match("%d+")) or i
			local fill = fills[index] or 0
			-- A size write a frame for five frames is nothing, but a write
			-- that changes nothing is still a replicated-property churn on
			-- the client's own tree; skip it below a hundredth.
			if math.abs((painted[index] or -1) - fill) >= 0.01 then
				painted[index] = fill
				paintStar(star :: Frame, fill)
			end
		end
	end

	Remotes.get("WantedState").OnClientEvent:Connect(function(state)
		local sheet = tonumber(state and state.sheet) or 0

		-- NOTHING STOLEN MEANS NO CHIP AT ALL, and that reverses the argument
		-- the rob badge had to make.
		--
		-- That badge learned it must say YES as well as no, because "no badge"
		-- is an absence a new player cannot read and which pig to rob is the
		-- whole decision. This is the opposite case: there is no decision
		-- riding on it, and a chip reading "STOLEN 0" for a player who has
		-- never robbed anybody is a permanent zero -- wallpaper, which is what
		-- a player stops seeing. It APPEARING is the signal, and it appears at
		-- the exact moment somebody becomes a thief.
		if sheet <= 0 then
			chip.Visible = false
			return
		end

		-- THE SERVER SAYS WHO THE NEXT PATROL COMES FOR. It used to be
		-- "leading and over the floor", combined here; a five-star thief is
		-- hunted whoever leads the board, so the flag arrives decided.
		local hunted = state.hunted == true
		local key = if hunted then "hunted" elseif state.isLeader then "leading" else "quiet"
		caption.Text = CAPTION[key]
		amount.Text = Config.formatCoins(sheet)

		-- THE RING IS THE WHOLE ESCALATION: muted while you are one thief
		-- among several, gold when the poster on the street has your name on
		-- it, red once your sheet clears your own floor and the next patrol is
		-- actually coming for you. Three states, one property, no flashing --
		-- this is a standing readout and not an alarm, and the toast that
		-- announces each transition is already the loud half.
		local tone = if hunted then Theme.STOP
			elseif state.isLeader then Theme.GOLD
			else Theme.MUTED
		if ring then
			ring.Color = tone
		end
		caption.TextColor3 = if hunted then Theme.STOP_INK
			elseif state.isLeader then Theme.GOLD_INK
			else Theme.MUTED

		-- THE STARS. `starsAt` is the server's own stamp; a push without one
		-- (an older server than this client, mid-deploy) is drawn as though
		-- it were stamped now, which is five steady stars rather than five
		-- missing ones. `pinned` is the Most Wanted player's held row.
		latest.max = tonumber(state.starsMax) or 0
		latest.count = tonumber(state.stars) or 0
		latest.at = tonumber(state.starsAt) or workspace:GetServerTimeNow()
		latest.pinned = state.pinned == true
		ensureStars(run, latest.max)
		painted = {}
		paint()

		chip.Visible = true
	end)

	-- THE DRAIN, ON THE CLIENT'S OWN CLOCK. Heartbeat and not RenderStepped,
	-- for the reason the carry watcher records: RenderStepped does not fire
	-- in a session whose viewport is not drawing, and a readout that stops
	-- moving looks exactly like a readout that is broken. Nothing to do while
	-- the chip is hidden, while the row is pinned full, or once every star
	-- has drained -- the next push is what changes any of those.
	RunService.Heartbeat:Connect(function()
		if not chip.Visible or latest.pinned or latest.count <= 0 then
			return
		end
		paint()
	end)
end

return Wanted
