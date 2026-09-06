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

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)

local Wanted = {}

-- DIRECTLY UNDER THE EVENT CHIP, AND EVERY NUMBER HERE IS ITS NEIGHBOUR'S.
-- The event chip is 176 x 34 at y 154, so it ends at 188 and this starts at
-- 196 -- the same 8px gap that chip leaves under the piggy bank panel. Sharing
-- the width is what makes the two read as a column rather than as two things
-- that happen to be near each other.
local WIDTH = 176
local ROW = 34
local TOP = 196

-- THE RUN GETS ITS OWN ROW, BECAUSE THE ONE ABOVE IT IS FULL.
--
-- A badge, a caption and a coin figure already spend all 176 pixels of the
-- first row -- measured, the gap between the caption and the amount is 20px,
-- which holds nothing. So the chip is 12 taller than its neighbour rather
-- than trying to fit a fifth thing into a row that has no room. It keeps the
-- same x and the same width, which is what actually makes the column read as
-- a column; matching heights was never the thing doing that work.
local PIP_ROW = 12
local HEIGHT = ROW + PIP_ROW
local PIP_PAD = 12
local PIP_GAP = 4

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

	-- PIPS AND NOT A BAR, WHICH IS THIS PROJECT'S OWN RULE ABOUT LADDERS. Four
	-- steps with three filled is a thing you SEE; "3/4" is a thing you read,
	-- and half this audience is not reading the numbers. The upgrade trees
	-- make exactly this argument, and they also record where it stops holding
	-- -- at forty rungs a pip is 4.4 pixels and becomes noise, so those get a
	-- bar instead. Four is comfortably the pip end of that.
	--
	-- THE RING SAYS WHAT THE STREET THINKS OF YOU AND THE PIPS SAY HOW FAST
	-- YOU ARE WORKING, which are genuinely two facts. Same split as an upgrade
	-- card, where the outline says which tree and the pill says whether you
	-- can afford it: two signals, two places, neither having to carry the
	-- other's meaning.
	local pips = Instance.new("Frame")
	pips.Name = "Run"
	pips.BackgroundTransparency = 1
	pips.Position = UDim2.new(0, PIP_PAD, 1, -PIP_ROW + 2)
	pips.Size = UDim2.new(1, -PIP_PAD * 2, 0, 4)
	pips.Parent = chip

	return chip
end

-- Built on the first push rather than at construction, because how many there
-- are is the SERVER'S to say -- `Config.SPREE.maxSteps` arrives in the payload
-- so the chip cannot disagree with the ladder it is drawing. Rebuilt only when
-- the count changes, which is the same rule the upgrade rows follow: repainting
-- is one property per pip, and tearing the row down on every push would rebuild
-- it every five seconds forever.
local function ensurePips(pips: Frame, count: number)
	if #pips:GetChildren() == count then
		return
	end
	pips:ClearAllChildren()
	if count <= 0 then
		return
	end
	local each = (1 / count)
	for i = 1, count do
		local pip = Instance.new("Frame")
		pip.Name = ("Pip%d"):format(i)
		pip.BorderSizePixel = 0
		-- Scale so any ladder length fills the same row, exactly as the
		-- upgrade pips size themselves 1/max of their own row.
		pip.Size = UDim2.new(each, -PIP_GAP, 1, 0)
		pip.Position = UDim2.new(each * (i - 1), 0, 0, 0)
		pip.Parent = pips
		Theme.corner(pip, 2)
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
	local pips = chip:FindFirstChild("Run") :: Frame
	local ring = badge:FindFirstChildOfClass("UIStroke")

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

		local hunted = state.isLeader and state.hunted
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

		-- GOLD FOR A STEP TAKEN AND A GROOVE FOR ONE NOT, which is the
		-- unbought-rung colour the upgrade pips already settled: a well holds
		-- a rendered model and wants to be a hole, but an empty pip is a
		-- groove and belongs one step under the ground rather than reading as
		-- disabled.
		local run = tonumber(state.spree) or 0
		ensurePips(pips, tonumber(state.spreeMax) or 0)
		for i, pip in ipairs(pips:GetChildren()) do
			local index = tonumber(pip.Name:match("%d+")) or i
			;(pip :: Frame).BackgroundColor3 = if index <= run then Theme.GOLD else Theme.SAND_DEEP
		end

		chip.Visible = true
	end)
end

return Wanted
