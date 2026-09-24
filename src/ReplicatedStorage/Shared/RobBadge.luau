--!strict
-- Per-viewer street decisions. Acorn quantities/cooldowns belong at the props.
-- This is presentation only; HeistService checks every action on the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local RobBadge = {}
local me: Player? = nil
local cards: { [Instance]: any } = {}
local cooldown: { [number]: number } = {}
local recovery: any = nil
local myPicks, mySack = 0, 0
-- HOW FAR AWAY THE BADGE READS. It was the far row's next-door neighbour
-- from your own lawn; it is a pavement's reach now. See `Config.ROB_BADGE`.
local REACH = Config.ROB_BADGE.reach
-- A ROB FIGURE IS A COIN AND A NUMBER FLOATING OVER THE PIG, AND NO CARD
-- (designer, 2026-09-23). It was a paper card with an ink outline -- first
-- 224 x 42, then 150 x 30 -- and eight of them across a street read as eight
-- shop signs whatever the size. The `Card` frame survives as the LAYOUT
-- (everything is positioned inside it) and is transparent; what holds the
-- type off the grass is an ink stroke on the glyphs, which is `RobberMark`'s
-- own trick and the reason the figure is `Theme.GOLD` rather than the
-- paper-solved `GOLD_INK`: a stroke carries a bright colour over any ground,
-- where a darkened gold was solved for cream. The same four states, the
-- same vocabulary; what went is the ground under them.
local CARD_W, CARD_H, LOCK_ROW, TAG_H = 150, 30, 8, 16
-- The ink line round every floating glyph. Thinner than the bang's 3: this
-- is a price tag, not an alarm.
local STROKE = 2
-- The figure's ceiling.
local TEXT_MAX = 20

local function clockText(seconds: number): string
	local left = math.max(0, math.ceil(seconds))
	return if left >= 60 then ("%dm"):format(math.ceil(left / 60)) else ("0:%02d"):format(left)
end

-- Same order as whyCannotSteal: shield, reader cooldown, empty, loss cap.
function RobBadge.describe(facts: any, now: number): any
	if (facts.shield or 0) > now then
		return { text = if facts.firstJob then "NEW HERE" else "SHIELD",
			timer = if facts.firstJob then "" else clockText(facts.shield - now), tone = "COOL_INK", glyph = "◇" }
	elseif (facts.cooldown or 0) > now then
		return { text = "ROBBED", timer = clockText(facts.cooldown - now), tone = "WARN_INK", glyph = "⌛" }
	elseif (facts.vault or 0) < 1 then
		return { text = "EMPTY", timer = "", tone = "MUTED", glyph = "–" }
	elseif (facts.capped or 0) > now then
		return { text = "CAPPED", timer = clockText(facts.capped - now), tone = "WARN_INK", glyph = "⌛" }
	end
	-- WHAT A CLEAN CRACK CARRIES HOME. Not capped at the reader's own room any
	-- more, and there is therefore no PIG FULL state on this card -- the cap
	-- made a badge about THEIR pig report a fact about YOURS, on all eight at
	-- once. See `Config.homeWorth` for the whole argument; the piggy panel
	-- carries "you have no room" now.
	if facts.home ~= nil then
		return { text = Config.formatCoins(facts.home), timer = "", tone = "GOLD_INK", available = true }
	end
	return { text = Config.formatCoins(facts.vault), timer = "", tone = "GOLD_INK", available = true }
end

-- The figure `describe` prints for an available pig: a clean five-slice crack
-- at this reader's sack, times HEIST_PAYOUT.
--
-- It needs nothing about the reader's own balance, which is the point: the
-- badge is a price tag on somebody else's pig and can be drawn before the
-- first StateUpdate has ever arrived.
function RobBadge.homeFigure(vault: number?, sack: number): number
	return Config.homeWorth(vault, Config.getCrackFraction(Config.CRACK.maxSteps, sack))
end

function RobBadge.recoverable(state: any, victimId: number, now: number): boolean
	for _, row in ipairs(if state then state.claims or {} else {}) do
		if row.stage == "recover" and row.robberId == victimId and (row.expiresAt or 0) > now then return true end
	end
	return false
end

local function build(body: BasePart): any
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.Adornee = "RobState", body
	gui.Size = UDim2.fromOffset(CARD_W, CARD_H)
	gui.StudsOffset = Vector3.new(0, 11, 0)
	gui.MaxDistance, gui.AlwaysOnTop, gui.Enabled = REACH, false, false
	gui.Parent = body
	local card = Instance.new("Frame")
	card.Name, card.Size = "Card", UDim2.fromScale(1, 1)
	-- NO GROUND. The frame is the layout and nothing else.
	card.BackgroundTransparency, card.BorderSizePixel = 1, 0
	card.Parent = gui
	local function label(name: string, parent: Instance): TextLabel
		local text = Instance.new("TextLabel")
		text.Name, text.BackgroundTransparency, text.Text = name, 1, ""
		text.Font, text.TextColor3 = Theme.FONT, Theme.INK
		-- ON THE GLYPH, NOT ROUND A BOX: a UIStroke on a TextLabel defaults to
		-- `Contextual`, which strokes the characters. `Theme.outline` would set
		-- `Border` and draw a rectangle round an invisible label.
		local stroke = Instance.new("UIStroke")
		stroke.Thickness, stroke.Color = STROKE, Theme.INK
		stroke.Parent = text
		text.Parent = parent
		return text
	end
	local glyph = label("Glyph", card)
	glyph.Size, glyph.Position, glyph.TextSize = UDim2.fromOffset(17, 22), UDim2.fromOffset(7, 4), 15
	local coin = Theme.coin(card, 16)
	coin.Position = UDim2.fromOffset(8, 7)
	local text = label("Label", card)
	text.Position, text.Size = UDim2.fromOffset(28, 3), UDim2.new(1, -36, 0, 24)
	text.TextXAlignment, text.TextScaled = Enum.TextXAlignment.Left, true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize, limit.MaxTextSize, limit.Parent = 10, TEXT_MAX, text
	local timer = label("Timer", card)
	timer.Position, timer.Size = UDim2.new(1, -38, 0, 3), UDim2.fromOffset(32, 24)
	timer.Font, timer.TextSize, timer.TextXAlignment = Enum.Font.GothamBold, 12, Enum.TextXAlignment.Right
	local locks = Instance.new("Frame")
	locks.Name, locks.BackgroundTransparency = "Locks", 1
	locks.Position, locks.Size = UDim2.fromOffset(9, CARD_H - 3), UDim2.fromOffset(46, 3)
	locks.Parent = card
	local def = Config.UPGRADES[Config.CASING.upgrade]
	for i = 1, if def then def.max else 0 do
		local pip = Instance.new("Frame")
		pip.Name, pip.BorderSizePixel = "Pip" .. i, 0
		pip.Size, pip.Position = UDim2.new(1 / def.max, -3, 1, 0), UDim2.new((i - 1) / def.max, 0, 0, 0)
		pip.Parent = locks
		Theme.corner(pip, 2)
	end
	local tag = label("RecoveryTag", gui)
	tag.AnchorPoint, tag.Position = Vector2.new(1, 0), UDim2.new(1, -5, 0, 0)
	tag.Size, tag.BackgroundTransparency = UDim2.fromOffset(104, TAG_H), 0
	tag.BackgroundColor3, tag.TextColor3, tag.TextSize = Theme.STOP_INK, Theme.PAPER, 11
	Theme.corner(tag, 5)
	return { gui = gui, card = card, label = text, timer = timer, glyph = glyph, coin = coin, locks = locks, tag = tag }
end

local function attach(plot: Instance)
	if cards[plot] then return end
	local bank = Config.waitForPlotBank(plot, 20)
	local body = bank and bank:WaitForChild("Body", 20)
	if body and body:IsA("BasePart") and plot.Parent and not cards[plot] then cards[plot] = build(body) end
end

local function paint()
	local now = workspace:GetServerTimeNow()
	for plot, badge in pairs(cards) do
		local ownerId = plot:GetAttribute("OwnerUserId")
		local victimId = ownerId or plot:GetAttribute(Config.PLOT_RESIDENT_ID_ATTRIBUTE)
		badge.gui.Enabled = victimId ~= nil and victimId ~= (me :: Player).UserId
		if not badge.gui.Enabled then continue end
		local owner = if ownerId then Players:GetPlayerByUserId(ownerId) else nil
		local vault = plot:GetAttribute(Config.PLOT_VAULT_ATTRIBUTE)
		local spec = RobBadge.describe({
			shield = owner and owner:GetAttribute(Config.PLAYER_SHIELD_ATTRIBUTE),
			firstJob = owner and owner:GetAttribute(Config.PLAYER_FIRST_JOB_ATTRIBUTE) == true,
			cooldown = cooldown[victimId], vault = vault,
			capped = plot:GetAttribute(Config.PLOT_CAPPED_ATTRIBUTE),
			home = RobBadge.homeFigure(vault, mySack),
		}, now)
		local recover = RobBadge.recoverable(recovery, victimId, now)
		local hot = (plot:GetAttribute(Config.PLOT_HOT_SKIN_ATTRIBUTE) or 0) > now
		badge.tag.Visible, badge.tag.Text = recover or hot, if recover then "↶ RECOVER SKIN" else "HOT SKIN"
		-- A stroked figure carries the real gold; a paper-solved tone is for
		-- type sitting on cream. The state words keep their own tones.
		badge.label.Text = spec.text
		badge.label.TextColor3 = if spec.available then Theme.GOLD else Theme[spec.tone]
		badge.timer.Text, badge.timer.TextColor3 = spec.timer, Theme.MUTED
		badge.glyph.Text, badge.glyph.TextColor3 = spec.glyph or "", Theme[spec.tone]
		badge.coin.Visible = spec.available == true
		local showLocks = spec.available and Config.canCase(myPicks)
		badge.locks.Visible = showLocks == true
		local width, height = CARD_W, CARD_H
		local tagHeight = if recover or hot then TAG_H else 0
		local lockHeight = if showLocks then LOCK_ROW else 0
		badge.gui.Size = UDim2.fromOffset(width, height + lockHeight + tagHeight)
		badge.card.Position, badge.card.Size = UDim2.fromOffset(0, tagHeight), UDim2.new(1, 0, 0, height + lockHeight)
		badge.label.Size = UDim2.new(1, if spec.timer ~= "" then -68 else -36, 0, height - 6)
		badge.locks.Position = UDim2.fromOffset(9, height - 3)
		if showLocks then
			local level = plot:GetAttribute(Config.PLOT_LOCK_ATTRIBUTE) or 0
			for _, pip in ipairs(badge.locks:GetChildren()) do
				local index = tonumber(pip.Name:match("%d+")) or 0
				(pip :: Frame).BackgroundColor3 = if index <= level then Theme.STOP else Theme.SAND_DEEP
			end
		end
	end
end

function RobBadge.start(player: Player)
	if me then return end
	me = player
	Remotes.get("UpgradeState").OnClientEvent:Connect(function(state)
		local row = state and state[Config.CASING.upgrade]
		myPicks = (row and row.level) or 0
		local sack = state and state.sack
		mySack = (sack and sack.level) or 0
	end)
	Remotes.get("StealCooldown").OnClientEvent:Connect(function(id, deadline) cooldown[id] = deadline end)
	Remotes.get("RecoveryObjective").OnClientEvent:Connect(function(state) recovery = state end)
	task.spawn(function()
		local plots = workspace:WaitForChild("Plots", 30)
		if not plots then return end
		for _, plot in ipairs(plots:GetChildren()) do task.spawn(attach, plot) end
		plots.ChildAdded:Connect(function(plot) task.spawn(attach, plot) end)
		plots.ChildRemoved:Connect(function(plot)
			if cards[plot] then cards[plot].gui:Destroy(); cards[plot] = nil end
		end)
		while true do paint(); task.wait(0.25) end
	end)
end
return RobBadge
