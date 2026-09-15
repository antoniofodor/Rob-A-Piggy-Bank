--!strict
--
-- CAN I ROB THAT ONE? -- answered from the pavement, not at the prompt.
--
-- Every reason a piggy is off limits used to live in the REFUSAL. You walked
-- up somebody's drive, past their fence and their dog, held a lock for up to
-- twelve seconds, and were then told the owner had been robbed a minute ago.
-- The prompt learned to say some of it up front -- the take, the hold, EMPTY --
-- but a prompt only exists once you are already standing on the lawn, which is
-- well past the point the decision was worth making.
--
-- IT USED TO ONLY EVER SAY NO, AND THAT RULE HAS BEEN DELIBERATELY REVERSED.
-- It read: *there is no "ROB ME" state, because eight piggies all advertising
-- themselves is not information, it is wallpaper -- the useful signal is the
-- exception, so a badge means stay away and no badge means go.*
--
-- That is right for somebody who already knows this street, and wrong for the
-- game as a whole, for a reason that survives the objection: A STEAL TAKES A
-- FRACTION OF A PIG, SO WHICH PIG IS THE ENTIRE DECISION. "No badge" tells a
-- thief a plot is available; it tells them nothing about whether it is WORTH
-- crossing the road for, and that was the one question this whole feature
-- exists to answer from the pavement. A new player cannot read an absence at
-- all -- they have not learned what a missing badge means.
--
-- So a robbable pig now carries its own figure in gold, and the street reads
-- as a shopping list. The refusals are unchanged and still win: a reason to
-- stay away always beats a number.
--
-- What it shows is what a robbery here is WORTH, which is what is in the pig
-- times whatever the street's event multiplier currently is. That is a
-- correction to what this paragraph used to claim -- *"what is IN the pig,
-- never what you would take"* -- and the half that survives is the reason
-- rather than the rule: it is not a TAKE, because a take needs the thief's own
-- Bigger Sack level and would be a second implementation of a figure the crack
-- panel already computes. A Rush Hour is the one thing that moves this, it
-- moves every pig on the street by the same factor, and it is pushed rather
-- than re-derived. See the value line in `paint` for what that costs.
--
-- CLIENT-SIDE AND PER VIEWER, WHICH IS THE ONLY CORRECT SHAPE HERE RATHER THAN
-- A SHORTCUT. The per-victim cooldown is per THIEF, so two players standing at
-- the same piggy genuinely disagree about whether it can be robbed and there
-- is no shared answer a server could paint on a sign. Each client is told its
-- own cooldowns by `StealCooldown` and derives the rest from attributes it
-- already has -- the same shape as the animated skins and the moat, where the
-- server publishes a fact and every machine works out the picture for itself.
--
-- NOTHING HERE DECIDES ANYTHING. `HeistService.whyCannotSteal` re-checks all of
-- it on the trigger; this is a picture of what that function would say, and it
-- is kept in the same ORDER as that function so the two can never contradict
-- each other. Reorder one and reorder both.
--
-- A MODULE, NOT A SECTION OF ClientMain, for the reason HouseFX, HotBar and
-- AdminPanel are: that chunk is at Luau's 200-local ceiling, and the three
-- top-level locals this wanted took the ENTIRE HUD down when it lived there --
-- the chunk fails to compile, nothing is built, and the error names some
-- innocent variable thousands of lines away. A module body gets its own
-- register file, so the whole feature costs ClientMain nothing at all: it is
-- required and started in one statement holding no local.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)

local RobBadge = {}

-- Whole seconds are all this counts, so a Heartbeat would repaint eight labels
-- sixty times a second to redraw the same string fifty-six of those times.
local TICK = 0.25

-- The body's centre sits at plot-local y 8.5 with a radius of 6, and the hat
-- accessory anchor is 14.15 -- so a badge hung off the body has to clear the
-- tallest hat in the shop rather than growing out of somebody's top hat. At
-- +11 it stands about five studs above the crown of the skull.
local LIFT = 11

-- A plot is PLOT_SPACING apart and the street is STREET_SPACING across, so
-- this reaches your neighbours and the row opposite without labelling the
-- whole map. Derived rather than picked, so widening the street moves it.
local REACH = Config.STREET_SPACING + Config.PLOT_SPACING

local cooldown: { [number]: number } = {}

-- OUR OWN LOCKPICKS LEVEL, which is the only thing casing is gated on.
--
-- Read off `UpgradeState`, which this client is already sent -- the same
-- push the shop's own tree rows are drawn from, so the badge and the card
-- selling the rung cannot disagree about whether it is owned. It is a fact
-- about the VIEWER rather than about a plot, which is why it lives here
-- beside the per-thief cooldowns rather than on an attribute in the world.
local myPicks = 0

-- WHAT A ROBBERY IS WORTH RIGHT NOW, WHICH IS NOT ALWAYS ONE PIG'S WORTH.
--
-- Rush Hour doubles every take on the street -- `sliceWorth` and `smash` both
-- multiply by `EventService.getStealMultiplier` -- and until now the only
-- place that showed up was the crack panel's slice figures, which nobody can
-- see until they are already standing on the lawn holding somebody's lock.
-- That is the exact fault this file exists to fix, arriving on the one state
-- of the street where the answer changes for every pig at once.
--
-- THE SERVER'S OWN NUMBER, off `EventState`, and deliberately not
-- `Config.RUSH.stealMultiplier` read from here. A constant would be a second
-- description of what a rush is worth, and it would go on saying 2 through
-- the fourteen minutes of every quarter hour when nothing is running at all.
local stealMultiplier = 1

type Badge = { gui: BillboardGui, label: TextLabel, locks: Frame, big: boolean }
local cards: { [Instance]: Badge } = {}
local me: Player? = nil

-- CASING DRAWS THE LOCK AS A LADDER, NOT AS A NUMBER.
--
-- "LOCK 3" is a thing you read; three pips filled of four is a thing you SEE,
-- and half this audience is not reading the numbers. It is also the
-- vocabulary this game already speaks -- the upgrade rungs and the spree row
-- are both pip ladders -- so it needs no teaching and no second convention.
--
-- IT ALSO NEEDS NO NAMES. The tiers have colours in `PiggyBank` and no names
-- anywhere, and inventing "Iron / Bronze / Steel / Gold" here would be a
-- second table describing one ladder, sitting in a different file from the
-- first. That is the near-identical copy that drifts, which this project has
-- recorded for the mini piggy, `Decor.buildOne` and `RideSound`.
local CARD_W = 150
local CARD_H = 40
local LOCK_ROW = 12

-- A BIGGER CARD DURING A RUSH, BECAUSE THE FONT CANNOT GROW ON ITS OWN.
--
-- The label is `TextScaled`, so its size is whatever fits the box rather than
-- a number anybody sets -- measured, it renders at 31.68 of a 32-tall box, so
-- it is already filling the height it has. The only lever on how big that
-- figure reads is therefore the BOX, which is why the card grows rather than
-- a TextSize being written: with `TextScaled` on, writing one changes nothing
-- at all and reads back exactly what you set, which is the `UseJumpPower`
-- family of bug this project has already paid for once.
--
-- WIDTH GROWS WITH HEIGHT, and it has to. A doubled figure gains a digit --
-- 96.9M is the largest pig this game can produce and doubles to 193.8M -- and
-- at the taller height six characters want about 152px, which a 138px label
-- would answer by shrinking the type back down. Growing only the height would
-- have been a bigger box containing the same size number, which is the whole
-- thing this is for.
local RUSH_W = 200
local RUSH_H = 58

local function build(body: BasePart): Badge
	local gui = Instance.new("BillboardGui")
	gui.Name = "RobState"
	gui.Size = UDim2.fromOffset(CARD_W, CARD_H)
	gui.StudsOffset = Vector3.new(0, LIFT, 0)
	gui.MaxDistance = REACH
	-- Not AlwaysOnTop: this is scenery-scale information, and a label that
	-- punches through the house it is behind reads as a HUD element pinned to
	-- the world rather than as something standing on the lawn.
	gui.AlwaysOnTop = false
	gui.Enabled = false
	gui.Adornee = body
	gui.Parent = body

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Theme.PAPER
	card.BorderSizePixel = 0
	card.Parent = gui
	Theme.corner(card, 10)
	Theme.outline(card)

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.new(1, -12, 0, CARD_H - 8)
	label.Position = UDim2.new(0, 6, 0, 4)
	label.BackgroundTransparency = 1
	label.Font = Theme.FONT
	label.TextScaled = true
	label.Text = ""
	label.Parent = card

	-- Built once and hidden, rather than created when casing is unlocked. A
	-- badge is attached when a plot appears and this row is four frames; the
	-- alternative is building geometry inside a render loop that runs on every
	-- plot every frame.
	local locks = Instance.new("Frame")
	locks.Name = "Locks"
	locks.BackgroundTransparency = 1
	locks.Position = UDim2.new(0, 10, 0, CARD_H - 4)
	locks.Size = UDim2.new(1, -20, 0, 5)
	locks.Visible = false
	locks.Parent = card

	local def = Config.UPGRADES[Config.CASING.upgrade]
	local rungs = if def then def.max else 0
	for i = 1, rungs do
		local pip = Instance.new("Frame")
		pip.Name = ("Pip%d"):format(i)
		pip.BorderSizePixel = 0
		pip.Size = UDim2.new(1 / rungs, -3, 1, 0)
		pip.Position = UDim2.new((i - 1) / rungs, 0, 0, 0)
		pip.Parent = locks
		Theme.corner(pip, 2)
	end

	return { gui = gui, label = label, locks = locks, big = false }
end

local function attach(plotModel: Instance)
	if cards[plotModel] then
		return
	end
	-- Either kind of money -- see `Config.waitForPlotBank`. A shop vault gets
	-- a badge for the same reason a piggy does: what is in it is the whole
	-- decision, and a shop's is readable from the pavement over the roof.
	local piggy = Config.waitForPlotBank(plotModel, 20)
	local body = piggy and piggy:WaitForChild("Body", 20)
	if not body or not body:IsA("BasePart") then
		return
	end
	cards[plotModel] = build(body)
end

-- The same three questions `whyCannotSteal` asks, in its order.
local function paint()
	local now = workspace:GetServerTimeNow()
	local myId = me and me.UserId
	for plotModel, badge in pairs(cards) do
		local ownerId = plotModel:GetAttribute("OwnerUserId")
		local text: string? = nil
		local tone: Color3? = nil

		-- A plot nobody lives on has a RESIDENT, and a resident is robbable --
		-- so the question is no longer "is this owned" but "is there anybody
		-- to rob here". Nothing over your own plot either way.
		local residentId = plotModel:GetAttribute(Config.PLOT_RESIDENT_ID_ATTRIBUTE)
		local victimId = ownerId or residentId

		if victimId and victimId ~= myId then
			local owner = if ownerId then Players:GetPlayerByUserId(ownerId) else nil
			local shield = (owner and owner:GetAttribute(Config.PLAYER_SHIELD_ATTRIBUTE)) or 0
			local cool = cooldown[victimId] or 0
			local vault = plotModel:GetAttribute(Config.PLOT_VAULT_ATTRIBUTE) or 0

			if shield - now > 0 then
				-- Seconds under a minute now that the shield is two minutes
				-- rather than fifteen: "NEW HERE 1m" against a wait of
				-- seventy seconds is a worse answer than the number itself.
				local left = shield - now
				text = if left >= 60
					then ("NEW HERE  %dm"):format(math.ceil(left / 60))
					else ("NEW HERE  %ds"):format(math.ceil(left))
				tone = Theme.COOL_INK
			elseif cool - now > 0 then
				text = ("ROBBED  %ds"):format(math.ceil(cool - now))
				tone = Theme.WARN_INK
			elseif vault <= 0 then
				text = "EMPTY"
				tone = Theme.MUTED
			else
				-- AND THIS BADGE NOW SAYS YES, WHICH REVERSES THE RULE ABOVE
				-- IT ON PURPOSE.
				--
				-- It used to only ever refuse, on the argument that eight
				-- pigs advertising themselves is wallpaper and the useful
				-- signal is the exception. That is right for somebody who
				-- already knows this street and wrong for the game as a
				-- whole, for a reason that survives the objection: A STEAL
				-- TAKES A FRACTION OF A PIG, SO WHICH PIG IS THE ENTIRE
				-- DECISION -- and until now that number was only legible from
				-- the steal prompt, which as this file's own header says only
				-- exists once you are already standing on the lawn, past the
				-- fence, past the dog, and well past the point the decision
				-- was worth making.
				--
				-- A figure over each robbable pig turns the street into a
				-- shopping list, which is what the first thirty seconds of
				-- this game needs: a target, visible, with a number on it.
				--
				-- It shows what is IN the pig rather than what you would
				-- take. The take needs the thief's own Bigger Sack level and
				-- the live event multiplier, and re-deriving those here would
				-- be a second implementation of a number the steal prompt
				-- already computes -- and the two would disagree the first
				-- time either moved. What is in the pig is also the honest
				-- thing to COMPARE across eight plots, which is the job.
				-- THE FIGURE IS MULTIPLIED BY THE RUSH, AND THE CARD GROWS
				-- WITH IT. So this badge is a WORTH rather than a pile, and
				-- that is worth being exact about, because it is the one
				-- number on the street that changes meaning during an event.
				--
				-- A pig does not HOLD double during a Rush Hour: what doubles
				-- is the share a thief takes out of it, and `sliceWorth` and
				-- `smash` both multiply by `EventService.getStealMultiplier`
				-- to do it. So the honest reading of "23.3M" over a pig
				-- holding 11.7M is *what robbing this is worth right now*,
				-- which is the question the badge was built to answer from the
				-- pavement -- and the doubling has to be VISIBLE rather than
				-- merely true, because the whole point of the event is that
				-- this is the twenty seconds to go and do it.
				--
				-- IT WAS A "x2" TAG BESIDE THE TRUE PILE FOR ONE SESSION, and
				-- the figure is what changed instead. A tag is a thing you
				-- READ and then multiply; a bigger number is a thing you SEE,
				-- and half this audience is not reading the numbers -- the same
				-- argument that made the upgrade rungs pips rather than "Lv
				-- 3/4" and the crack's next slice a segment on a bar rather
				-- than a figure. Every pig on the street grows at once, so
				-- what the street reads as is a rush rather than as eight
				-- separate pieces of arithmetic.
				--
				-- WHAT IT COSTS, STATED PLAINLY: THE STEAL PROMPT STILL QUOTES
				-- THE PILE. Its own comment calls the two "two readouts of one
				-- true thing at two distances", and during a rush they differ
				-- by the multiplier -- the badge says 23.3M from the pavement
				-- and the card at the lock says ~11.7M. That is deliberate and
				-- it is the pair to revisit first if it ever reads wrong: the
				-- prompt cannot follow without the crack panel's gauge
				-- following too, because that gauge is drawn against the real
				-- pig and a slice is a fixed width on it.
				text = Config.formatCoins(vault * stealMultiplier)
				tone = Theme.GOLD_INK
			end
		end

		badge.gui.Enabled = text ~= nil
		if text and tone then
			badge.label.Text = text
			badge.label.TextColor3 = tone
		end

		-- ONLY ON A PIG YOU COULD ACTUALLY ROB. A lock ladder over a plot that
		-- is shielded, on cooldown or empty is answering a question nobody
		-- asked -- the refusal is the answer there, and this file's own rule
		-- is that a reason to stay away always beats a number. So it rides
		-- the same branch the value does.
		local showLocks = Config.canCase(myPicks) and tone == Theme.GOLD_INK
		badge.locks.Visible = showLocks

		-- THE BIG CARD IS THE ROBBABLE STATE ONLY, which is the same branch
		-- the value and the lock ladder already ride. A refusal is not worth
		-- more of the screen for being refused during a rush -- "ROBBED 12s"
		-- in bigger type says the wrong thing louder -- and this file's rule
		-- is that a reason to stay away always beats a number.
		local big = stealMultiplier > 1 and tone == Theme.GOLD_INK
		local w = if big then RUSH_W else CARD_W
		local h = if big then RUSH_H else CARD_H
		-- The two inner offsets are written only on a CHANGE. `paint` runs
		-- four times a second over every plot in reach, and a rush changes
		-- this twice in three minutes -- so this is a comparison per badge per
		-- tick instead of two property writes, and it is what keeps the label
		-- from being re-laid-out sixty times for every time it moves.
		if badge.big ~= big then
			badge.big = big
			badge.label.Size = UDim2.new(1, -12, 0, h - 8)
			badge.locks.Position = UDim2.new(0, 10, 0, h - 4)
		end
		badge.gui.Size = UDim2.fromOffset(w, if showLocks then h + LOCK_ROW else h)
		if showLocks then
			local level = plotModel:GetAttribute(Config.PLOT_LOCK_ATTRIBUTE) or 0
			for _, pip in ipairs(badge.locks:GetChildren()) do
				local index = tonumber(pip.Name:match("%d+")) or 0
				-- STOP rather than gold for a locked rung: this is the one
				-- thing on the badge that is bad news for the reader, and the
				-- figure above it is already the gold. An unbought rung is a
				-- groove, the same colour the upgrade pips settled on.
				;(pip :: Frame).BackgroundColor3 = if index <= level
					then Theme.STOP
					else Theme.SAND_DEEP
			end
		end
	end
end

function RobBadge.start(localPlayer: Player)
	if me then
		return
	end
	me = localPlayer

	-- Casing is unlocked by a rung, so the badge has to know when one is
	-- bought. Nothing else here changes with an upgrade, which is why this is
	-- one field rather than a snapshot kept in step.
	Remotes.get("UpgradeState").OnClientEvent:Connect(function(snapshot)
		local row = snapshot and snapshot[Config.CASING.upgrade]
		myPicks = (row and row.level) or 0
	end)

	Remotes.get("StealCooldown").OnClientEvent:Connect(function(victimUserId, until_)
		cooldown[victimUserId] = until_
	end)

	-- No repaint call: `paint` runs every TICK anyway, so the tag arrives
	-- within a quarter second of the push and there is no second path that
	-- could leave a stale one on screen. It defaults to 1 rather than nil, so
	-- a client that has not had its first push yet reads as "no rush" instead
	-- of erroring inside a loop that runs over every plot -- the same call the
	-- event chip makes when it refuses to divide a bar by a total of 0.
	Remotes.get("EventState").OnClientEvent:Connect(function(state)
		stealMultiplier = (state and state.stealMultiplier) or 1
	end)

	task.spawn(function()
		local plots = workspace:WaitForChild("Plots", 30)
		if not plots then
			return
		end
		for _, plotModel in ipairs(plots:GetChildren()) do
			task.spawn(attach, plotModel)
		end
		plots.ChildAdded:Connect(function(child)
			task.spawn(attach, child)
		end)
		-- A plot is torn down and rebuilt on rebirth, so the table is keyed on
		-- the model and swept rather than being built once at startup.
		plots.ChildRemoved:Connect(function(child)
			cards[child] = nil
		end)

		while true do
			paint()
			task.wait(TICK)
		end
	end)
end

return RobBadge
