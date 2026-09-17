--!strict
-- THE SEASON PAGE OF THE STREET BOARD, DRAWN AROUND THE READER (Phase 5.5).
--
-- The server turns the one street board through three pages and publishes
-- which one is up (`Config.BOARD_PAGE_ATTRIBUTE`). On the season page it
-- paints the global top; this module hides that copy ON THIS CLIENT ONLY and
-- draws a local one from the reader's own `SeasonState` -- the rows around
-- them, highlighted, and a footer with their tier and what the next one needs
-- -- because a global top eight produces one euphoric winner and seven
-- demoralised children. Presentation only: every number is the server's.
--
-- A LOCAL SURFACEGUI, NEVER EDITS TO THE REPLICATED ONE. A client write to a
-- replicated label survives only until the server next changes that property,
-- so two writers on one label drift. A separate gui toggled by page cannot.
-- UNVERIFIED IN STUDIO: layout mirrors the server board's measured one.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)

local SeasonBoard = {}

local ROW_H, ROWS = 36, Config.SEASON_BOARD.above + Config.SEASON_BOARD.below + 1

-- The footer line for a state. Pure, so the test can read it.
function SeasonBoard.footer(state: any): string
	if type(state) ~= "table" or not state.number then
		return "Season 1 starts soon. Grow acorns to be ready!"
	end
	if not state.active then
		return ("Season %d is over: you reached tier %d."):format(state.number, state.tier or 0)
	end
	if state.nextNeed then
		return ("You: tier %d  ·  %d / %d acorns to tier %d"):format(
			state.tier or 0, state.earned or 0, state.nextNeed, (state.tier or 0) + 1)
	end
	return ("You: tier %d  ·  %d acorns  ·  TOP TIER"):format(state.tier or 0, state.earned or 0)
end

-- A row's two labels. `rank` nil means "outside the cached pages".
function SeasonBoard.rowText(row: any): (string, string)
	local rank = if row.rank then ("%d."):format(row.rank) else "..."
	return ("%s  %s"):format(rank, row.name or "?"), ("%d acorns"):format(row.amount or 0)
end

local function build(panel: BasePart): any
	local surface = Instance.new("SurfaceGui")
	surface.Name = "SeasonLocal"
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(600, 400)
	surface.LightInfluence = 0
	surface.Enabled = false

	local sheet = Instance.new("Frame")
	sheet.Size, sheet.Position = UDim2.new(1, -32, 1, -32), UDim2.fromOffset(16, 16)
	sheet.Parent = surface
	Theme.card(sheet, 10)
	Theme.outline(sheet, 4)

	local title = Instance.new("TextLabel")
	title.Size, title.Position = UDim2.new(1, -40, 0, 56), UDim2.fromOffset(20, 10)
	title.BackgroundTransparency, title.TextScaled = 1, true
	Theme.title(title, 56, Theme.GOLD_INK)
	title.Parent = sheet

	local rows = {}
	for i = 1, ROWS do
		local row = Instance.new("Frame")
		row.Size, row.Position = UDim2.new(1, -40, 0, ROW_H - 4), UDim2.fromOffset(20, 70 + (i - 1) * ROW_H)
		row.BackgroundColor3 = Theme.SAND_DEEP
		row.BackgroundTransparency = if i % 2 == 0 then 0.78 else 0.5
		row.BorderSizePixel, row.Visible = 0, false
		row.Parent = sheet
		local who = Instance.new("TextLabel")
		who.Size, who.Position = UDim2.new(0.66, 0, 1, 0), UDim2.fromOffset(10, 0)
		who.BackgroundTransparency, who.TextScaled = 1, true
		who.TextXAlignment = Enum.TextXAlignment.Left
		Theme.title(who, 32, Theme.INK)
		who.Parent = row
		local amount = Instance.new("TextLabel")
		amount.Size, amount.Position = UDim2.new(0.32, -10, 1, 0), UDim2.new(0.68, 0, 0, 0)
		amount.BackgroundTransparency, amount.TextScaled = 1, true
		amount.TextXAlignment = Enum.TextXAlignment.Right
		Theme.title(amount, 32, Theme.GOLD_INK)
		amount.Parent = row
		table.insert(rows, { row = row, who = who, amount = amount })
	end

	local foot = Instance.new("TextLabel")
	foot.Size, foot.Position = UDim2.new(1, -40, 0, 26), UDim2.new(0, 20, 1, -34)
	foot.BackgroundTransparency, foot.TextScaled = 1, true
	Theme.body(foot, 24, Theme.MUTED)
	foot.Parent = sheet

	surface.Parent = panel
	return { surface = surface, title = title, rows = rows, foot = foot }
end

local state: any = nil
local boards: { [BasePart]: any } = {}

local function paint()
	local world = workspace:FindFirstChild("World")
	if not world then
		return
	end
	for _, panel in ipairs(world:GetChildren()) do
		if panel.Name == "Leaderboard" and panel:IsA("BasePart") then
			local server = panel:FindFirstChild("BoardGui") :: SurfaceGui?
			local season = panel:GetAttribute(Config.BOARD_PAGE_ATTRIBUTE) == "season"
			local ui = boards[panel]
			if season and not ui then
				ui = build(panel)
				boards[panel] = ui
			end
			if server then
				server.Enabled = not season
			end
			if ui then
				ui.surface.Enabled = season
				if season then
					local serverTitle = server and server:FindFirstChild("Title", true) :: TextLabel?
					ui.title.Text = if serverTitle then serverTitle.Text else "SEASON"
					local list = (state and state.rows) or {}
					for i, entry in ipairs(ui.rows) do
						local row = list[i]
						entry.row.Visible = row ~= nil
						if row then
							entry.who.Text, entry.amount.Text = SeasonBoard.rowText(row)
							entry.row.BackgroundColor3 = if row.me then Theme.GOLD else Theme.SAND_DEEP
							entry.row.BackgroundTransparency = if row.me then 0.35
								elseif i % 2 == 0 then 0.78 else 0.5
						end
					end
					ui.foot.Text = SeasonBoard.footer(state)
				end
			end
		end
	end
end

function SeasonBoard.start()
	Remotes.get("SeasonState").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			state = payload
		end
	end)
	task.spawn(function()
		while true do
			local ok, err = pcall(paint)
			if not ok then
				warn("[SeasonBoard] " .. tostring(err))
				task.wait(5)
			end
			task.wait(0.5)
		end
	end)
end

return SeasonBoard
