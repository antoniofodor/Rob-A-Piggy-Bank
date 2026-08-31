--!strict
--[[
	SocialService

	The things that make a server feel like a place other people are in:
	the friend bonus, the leaderboard, the most-wanted hat, and the revenge
	marker.

	These are the growth and retention systems. The friend bonus is the one
	that actually moves numbers -- it makes inviting someone a mechanical
	advantage rather than a favour, and kids play what their friends play.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local SocialService = {}

local friendBonus: { [Player]: number } = {}

-- IsFriendsWith is a web call. Cached per unordered pair for the life of the
-- server so a twelve-player room costs at most sixty-six lookups total
-- instead of re-asking every time somebody joins.
local friendCache: { [string]: boolean } = {}

local mostWanted: Player? = nil
local board: Part? = nil
local boardEmpty: TextLabel? = nil
local boardRows: { { row: Frame, who: TextLabel, amount: TextLabel } } = {}

local function pairKey(a: Player, b: Player): string
	local lo, hi = a.UserId, b.UserId
	if lo > hi then
		lo, hi = hi, lo
	end
	return ("%d_%d"):format(lo, hi)
end

local function areFriends(a: Player, b: Player): boolean
	local key = pairKey(a, b)
	local cached = friendCache[key]
	if cached ~= nil then
		return cached
	end

	local ok, result = pcall(function()
		return a:IsFriendsWith(b.UserId)
	end)
	local value = ok and result == true
	friendCache[key] = value
	return value
end

local function format(value: number): string
	local suffixes = { "", "K", "M", "B", "T" }
	local n = math.floor(value)
	local tier = 1
	while n >= 1000 and tier < #suffixes do
		n /= 1000
		tier += 1
	end
	if tier == 1 then
		return tostring(math.floor(n))
	end
	return ("%.1f%s"):format(n, suffixes[tier])
end

-- ============================================================
-- FRIEND BONUS
-- ============================================================

function SocialService.getFriendBonus(player: Player): number
	return friendBonus[player] or 0
end

-- Recomputed for everyone whenever the roster changes, because one arrival
-- can change several people's bonus at once.
local function recomputeFriendBonuses()
	local players = Players:GetPlayers()
	for _, player in ipairs(players) do
		local count = 0
		for _, other in ipairs(players) do
			if other ~= player and areFriends(player, other) then
				count += 1
			end
		end

		local bonus = math.min(Config.FRIEND_BONUS_MAX, count * Config.FRIEND_BONUS_PER)
		local previous = friendBonus[player]
		friendBonus[player] = bonus

		if previous and bonus > previous then
			Remotes.get("Notify"):FireClient(player,
				("Friend bonus: +%d%% income!"):format(math.floor(bonus * 100)), "good")
		end
	end
end

-- ============================================================
-- LEADERSTATS
-- ============================================================

-- Roblox's own player list. Nearly free, and it's where kids look first to
-- compare themselves to whoever they just met.
local function setupLeaderstats(player: Player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"

	local coins = Instance.new("StringValue")
	coins.Name = "Coins"
	coins.Value = "0"
	coins.Parent = folder

	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = folder

	folder.Parent = player
end

local function refreshLeaderstats(player: Player)
	local data = DataService.get(player)
	local folder = player:FindFirstChild("leaderstats")
	if not data or not folder then
		return
	end
	local coins = folder:FindFirstChild("Coins") :: StringValue?
	local rebirths = folder:FindFirstChild("Rebirths") :: IntValue?
	if coins then
		coins.Value = format(data.coins)
	end
	if rebirths then
		rebirths.Value = data.rebirths
	end
end

-- ============================================================
-- LEADERBOARD BOARD
-- ============================================================

-- Placed just off the front row rather than out in the field.
--
-- Roblox culls SurfaceGuis by distance from the *character*, so a board far
-- from where anyone stands is one nobody ever sees rendered. Close enough
-- that a player leaving their plot walks into it.
local function buildBoard()
	-- Stands at the head of the cul-de-sac looking straight down the street,
	-- so it faces both rows at once and every player walks past it on the way
	-- out. The old placement sat off the front edge of a solid grid, which no
	-- longer exists.
	local streetEnd = ((Config.PLOTS_PER_ROW - 1) / 2) * Config.PLOT_SPACING
		+ Config.PLOT_SIZE.X / 2
	local anchor = Vector3.new(-(streetEnd + 26), 0, 0)

	local post = Instance.new("Part")
	post.Name = "LeaderboardPost"
	post.Size = Vector3.new(2, 14, 2)
	post.Position = anchor + Vector3.new(0, 7, 0)
	post.Anchored = true
	post.Material = Enum.Material.Wood
	post.Color = Color3.fromRGB(104, 74, 50)
	post.Parent = workspace.World

	local panel = Instance.new("Part")
	panel.Name = "Leaderboard"
	panel.Size = Vector3.new(30, 20, 1)
	-- Turned a quarter turn to look along +X, down the middle of the street.
	panel.CFrame = CFrame.new(anchor + Vector3.new(0, 22, 0)) * CFrame.Angles(0, math.rad(-90), 0)
	panel.Anchored = true
	panel.Material = Enum.Material.WoodPlanks
	panel.Color = Color3.fromRGB(78, 56, 40)
	panel.Parent = workspace.World

	-- Roblox's "Front" face is -Z. After the yaw above that points down the
	-- street toward the plots, which is where the readers are.
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(600, 400)
	-- Unlit, so the text stays readable whichever way the sun is pointing.
	surface.LightInfluence = 0
	-- Parented at the bottom of this function, once every child exists, so
	-- the whole board replicates as one piece instead of a dozen increments.

	-- Light enough to read as a painted panel. A near-black backdrop over
	-- dark wood just looks like the board is blank.
	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(58, 44, 66)
	backdrop.BackgroundTransparency = 0.05
	backdrop.BorderSizePixel = 0
	backdrop.Parent = surface

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -40, 0, 62)
	title.Position = UDim2.new(0, 20, 0, 12)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(240, 196, 76)
	title.Text = "RICHEST PIGGIES"
	title.Parent = backdrop

	local list = Instance.new("Frame")
	list.Name = "Rows"
	list.Size = UDim2.new(1, -40, 1, -92)
	list.Position = UDim2.new(0, 20, 0, 82)
	list.BackgroundTransparency = 1
	list.Parent = backdrop

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	-- Fixed rows, filled in on refresh. Rebuilding instances every five
	-- seconds would churn the datamodel for no reason.
	--
	-- One label per row with TextScaled, rather than a single multi-line
	-- label at a fixed TextSize: a fixed size that reads well on a 30-stud
	-- board at ten studs is invisible at forty, which is where players
	-- actually stand.
	for index = 1, Config.LEADERBOARD_SIZE do
		local row = Instance.new("Frame")
		row.Name = "Row" .. index
		row.Size = UDim2.new(1, 0, 0, 34)
		row.LayoutOrder = index
		row.BackgroundColor3 = Color3.fromRGB(52, 42, 56)
		row.BackgroundTransparency = if index % 2 == 0 then 0.55 else 0.35
		row.BorderSizePixel = 0
		row.Visible = false
		row.Parent = list

		local who = Instance.new("TextLabel")
		who.Name = "Who"
		who.Size = UDim2.new(0.68, 0, 1, 0)
		who.Position = UDim2.new(0, 10, 0, 0)
		who.BackgroundTransparency = 1
		who.Font = Enum.Font.FredokaOne
		who.TextScaled = true
		who.TextXAlignment = Enum.TextXAlignment.Left
		who.TextColor3 = Color3.fromRGB(246, 240, 228)
		who.Text = ""
		who.Parent = row

		local amount = Instance.new("TextLabel")
		amount.Name = "Amount"
		amount.Size = UDim2.new(0.3, -10, 1, 0)
		amount.Position = UDim2.new(0.7, 0, 0, 0)
		amount.BackgroundTransparency = 1
		amount.Font = Enum.Font.FredokaOne
		amount.TextScaled = true
		amount.TextXAlignment = Enum.TextXAlignment.Right
		amount.TextColor3 = Color3.fromRGB(240, 196, 76)
		amount.Text = ""
		amount.Parent = row

		table.insert(boardRows, { row = row, who = who, amount = amount })
	end

	local empty = Instance.new("TextLabel")
	empty.Name = "Empty"
	empty.Size = UDim2.new(1, 0, 0, 40)
	empty.BackgroundTransparency = 1
	empty.Font = Enum.Font.Gotham
	empty.TextScaled = true
	empty.TextColor3 = Color3.fromRGB(150, 140, 150)
	empty.Text = "nobody yet"
	empty.LayoutOrder = 0
	empty.Parent = list

	surface.Parent = panel

	board = panel
	boardEmpty = empty
end

local function refreshBoard()
	if #boardRows == 0 then
		return
	end

	local ranked = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService.get(player)
		if data then
			table.insert(ranked, { player = player, coins = data.coins })
		end
	end
	table.sort(ranked, function(a, b)
		return a.coins > b.coins
	end)

	if boardEmpty then
		boardEmpty.Visible = #ranked == 0
	end

	for index, entry in ipairs(boardRows) do
		local ranking = ranked[index]
		entry.row.Visible = ranking ~= nil
		if ranking then
			entry.who.Text = ("%d.  %s"):format(index, ranking.player.DisplayName)
			entry.amount.Text = format(ranking.coins)
		end
	end
end

-- ============================================================
-- MOST WANTED
-- ============================================================

local function setHat(player: Player, wanted: boolean)
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end

	local existing = character:FindFirstChild("MostWantedHat")
	if not wanted then
		if existing then
			existing:Destroy()
		end
		return
	end
	if existing then
		return
	end

	local hat = Instance.new("Part")
	hat.Name = "MostWantedHat"
	hat.Size = Vector3.new(2.2, 0.5, 2.2)
	hat.Shape = Enum.PartType.Cylinder
	hat.CFrame = head.CFrame * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.rad(90))
	hat.Anchored = false
	hat.CanCollide = false
	hat.Massless = true
	hat.Material = Enum.Material.Neon
	hat.Color = Color3.fromRGB(232, 92, 72)
	hat.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = hat
	weld.Parent = hat

	local label = Instance.new("BillboardGui")
	label.Size = UDim2.new(0, 180, 0, 34)
	label.StudsOffset = Vector3.new(0, 3.2, 0)
	label.AlwaysOnTop = true
	label.Parent = hat

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(255, 138, 112)
	text.TextStrokeTransparency = 0.2
	text.Text = "MOST WANTED"
	text.Parent = label
end

-- The server's biggest thief wears something nobody can buy. It's the only
-- status in the game that can't be purchased, which is exactly why it works.
local function refreshMostWanted()
	local best: Player? = nil
	local bestAmount = 0

	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService.get(player)
		if data and data.totalStolen > bestAmount then
			best = player
			bestAmount = data.totalStolen
		end
	end

	if best == mostWanted then
		if mostWanted then
			setHat(mostWanted, true) -- re-apply after a respawn
		end
		return
	end

	if mostWanted then
		setHat(mostWanted, false)
	end
	mostWanted = best

	if best then
		setHat(best, true)
		Remotes.get("Notify"):FireClient(best, "You are the server's MOST WANTED thief.", "warn")
	end
end

-- ============================================================
-- REVENGE
-- ============================================================

-- Sent only to the victim, and rendered client-side, so the marker hangs
-- over the thief's plot for the person who was robbed and nobody else.
function SocialService.markRevenge(victim: Player, thief: Player)
	local plot = PlotService.getPlot(thief)
	if not plot then
		return
	end
	Remotes.get("RevengeMarker"):FireClient(victim, plot.model, thief.DisplayName, Config.REVENGE_MARKER_SECONDS)
end

-- ============================================================
-- LIFECYCLE
-- ============================================================

function SocialService.onPlayerAdded(player: Player)
	setupLeaderstats(player)
	recomputeFriendBonuses()

	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		if mostWanted == player then
			setHat(player, true)
		end
	end)
end

function SocialService.start()
	buildBoard()

	Players.PlayerRemoving:Connect(function(player)
		friendBonus[player] = nil
		if mostWanted == player then
			mostWanted = nil
		end
		task.defer(recomputeFriendBonuses)
	end)

	task.spawn(function()
		while true do
			task.wait(Config.LEADERBOARD_REFRESH)
			for _, player in ipairs(Players:GetPlayers()) do
				refreshLeaderstats(player)
			end
			refreshBoard()
			refreshMostWanted()
		end
	end)
end

return SocialService
