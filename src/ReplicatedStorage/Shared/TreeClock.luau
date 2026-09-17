--!strict
-- THE NEXT-ACORN CLOCK over your own tree (MASTER-PLAN 19.4's anticipation
-- layer): how many ripe acorns it holds against its cap, and how long until
-- the next one -- or FULL, which is the cue to go and shake it.
--
-- OWNER ONLY. A thief reads a tree from its visible acorns and, under the
-- Harvest Moon, from the shake prompt; a countdown over every neighbour's
-- oak would be eight more cards on a street that already carries a rob badge
-- over every pig. Presentation only: the server owns the growth cursor and
-- publishes the deadline (`Config.PLOT_TREE_NEXT_ATTRIBUTE`); this counts down
-- to it and never decides anything.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)

local TreeClock = {}

local CARD_W, CARD_H = 196, 40
-- U+1F330 CHESTNUT: the nearest thing Unicode has to an acorn. Four-byte, so
-- it has no monochrome text form. NOT YET render-measured on a card.
local GLYPH = utf8.char(0x1F330)

-- "42m" above a minute, "0:42" under one -- the rob badge's clock, so the two
-- cards on a lawn count down in the same voice.
function TreeClock.clockText(seconds: number): string
	local left = math.max(0, math.ceil(seconds))
	return if left >= 60 then ("%dm"):format(math.ceil(left / 60)) else ("0:%02d"):format(left)
end

-- What the card says. `nextAt` nil with a cap means the tree is full; a nil
-- cap means there is nothing to show.
function TreeClock.describe(ripe: number?, cap: number?, nextAt: number?, now: number): any
	if type(cap) ~= "number" then
		return nil
	end
	local count = ("%d/%d"):format(math.max(0, math.floor(ripe or 0)), cap)
	if type(nextAt) ~= "number" then
		return { count = count, timer = "FULL", tone = "GOOD_INK", full = true }
	end
	return { count = count, timer = "next " .. TreeClock.clockText(nextAt - now), tone = "INK", full = false }
end

local function build(canopy: BasePart): any
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.Adornee = "TreeClock", canopy
	gui.Size = UDim2.fromOffset(CARD_W, CARD_H)
	gui.MaxDistance, gui.AlwaysOnTop = 120, false
	gui.Parent = canopy
	local card = Instance.new("Frame")
	card.Name, card.Size = "Card", UDim2.fromScale(1, 1)
	card.BackgroundColor3, card.BorderSizePixel = Theme.PAPER, 0
	card.Parent = gui
	Theme.corner(card, 10)
	Theme.outline(card)
	local function label(name: string): TextLabel
		local text = Instance.new("TextLabel")
		text.Name, text.BackgroundTransparency, text.Text = name, 1, ""
		text.Font, text.TextColor3 = Theme.FONT, Theme.INK
		text.Parent = card
		return text
	end
	local glyph = label("Glyph")
	glyph.Size, glyph.Position, glyph.TextSize, glyph.Text = UDim2.fromOffset(26, 32), UDim2.fromOffset(8, 4), 20, GLYPH
	local count = label("Count")
	count.Position, count.Size, count.TextSize = UDim2.fromOffset(38, 4), UDim2.fromOffset(62, 32), 22
	count.TextXAlignment = Enum.TextXAlignment.Left
	local timer = label("Timer")
	timer.Position, timer.Size = UDim2.new(1, -96, 0, 4), UDim2.fromOffset(86, 32)
	timer.Font, timer.TextSize, timer.TextXAlignment = Enum.Font.GothamBold, 16, Enum.TextXAlignment.Right
	return { gui = gui, count = count, timer = timer, canopy = canopy }
end

local card: any = nil

local function ownPlot(me: Player): Instance?
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, plot in ipairs(plots:GetChildren()) do
		if plot:GetAttribute("OwnerUserId") == me.UserId then
			return plot
		end
	end
	return nil
end

local function paint(me: Player)
	local plot = ownPlot(me)
	local tree = plot and plot:FindFirstChild("AcornOak")
	local canopy = tree and tree:FindFirstChild("Canopy")
	if not plot or not canopy or not canopy:IsA("BasePart") then
		if card then card.gui.Enabled = false end
		return
	end
	if not card or card.canopy ~= canopy or not card.gui.Parent then
		if card then card.gui:Destroy() end
		card = build(canopy)
	end
	local spec = TreeClock.describe(plot:GetAttribute(Config.PLOT_TREE_ACORNS_ATTRIBUTE),
		plot:GetAttribute(Config.PLOT_TREE_CAP_ATTRIBUTE),
		plot:GetAttribute(Config.PLOT_TREE_NEXT_ATTRIBUTE), workspace:GetServerTimeNow())
	card.gui.Enabled = spec ~= nil
	if not spec then
		return
	end
	-- Just above the canopy, whatever size the tree level has made it.
	card.gui.StudsOffsetWorldSpace = Vector3.new(0, canopy.Size.Y / 2 + 1.6, 0)
	card.count.Text = spec.count
	card.timer.Text = spec.timer
	card.timer.TextColor3 = Theme[spec.tone]
end

function TreeClock.start(player: Player)
	task.spawn(function()
		while player.Parent do
			local ok, err = pcall(paint, player)
			if not ok then
				warn("[TreeClock] " .. tostring(err))
				task.wait(5)
			end
			task.wait(0.5)
		end
	end)
end

return TreeClock
