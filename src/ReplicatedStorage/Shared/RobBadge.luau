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
-- What it shows is what is IN the pig, never what you would take. The take
-- needs the thief's own Bigger Sack level and the live event multiplier, and
-- re-deriving those here would be a second implementation of a number the
-- steal prompt already computes -- and the two would disagree the first time
-- either moved. What is in the pig is also the honest thing to COMPARE across
-- eight plots, which is the job.
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
local cards: { [Instance]: { gui: BillboardGui, label: TextLabel, locks: Frame } } = {}
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
local CARD_H = 40
local LOCK_ROW = 12

local function build(body: BasePart): { gui: BillboardGui, label: TextLabel, locks: Frame }
	local gui = Instance.new("BillboardGui")
	gui.Name = "RobState"
	gui.Size = UDim2.fromOffset(150, CARD_H)
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

	return { gui = gui, label = label, locks = locks }
end

local function attach(plotModel: Instance)
	if cards[plotModel] then
		return
	end
	local piggy = plotModel:WaitForChild("PiggyBank", 20)
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
				text = Config.formatCoins(vault)
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
		badge.gui.Size = UDim2.fromOffset(150, if showLocks then CARD_H + LOCK_ROW else CARD_H)
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
