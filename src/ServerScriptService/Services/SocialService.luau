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

-- THE RAP SHEET: coins each player has successfully DELIVERED out of somebody
-- else's piggy bank this session, since their last most-wanted arrest.
--
-- A SESSION NUMBER, AND NOT `data.totalStolen`. Most Wanted used to read the
-- persisted lifetime total, which made it unwinnable: whoever had played the
-- longest wore the label permanently and nothing a new player did could ever
-- take it off them, so the one status in the game that cannot be bought was
-- also the one nobody could earn. Per session it is a live contest that resets
-- with the server, which is the only shape that lets a child who joined ten
-- minutes ago be in it.
--
-- Counted on DELIVERY rather than on the grab, because loot tagged out of your
-- hands or confiscated by the patrol was never stolen -- you were caught. Same
-- line `data.totalStolen` already draws, one statement above the call.
--
-- Strong-keyed on Player and cleared in PlayerRemoving. NOT a weak table: the
-- note at the top of RidePose is about exactly this -- the collector cannot
-- see the DataModel's own reference to an Instance, so a weak key here would
-- be collected out from under a player who is still standing on the street.
local heat: { [Player]: number } = {}

-- One table rather than six loose upvalues, and nil until the board is built.
-- ONE ENTRY PER BOARD, because there is a pair at each end of the street now.
--
-- These were single values, which is what a second board actually costs: the
-- refresh has to drive every copy or one of them quietly stops updating and
-- becomes a board showing last hour's standings. A list means the refresh
-- cannot forget one -- it loops over whatever was built.
type WantedUI = {
	card: Frame, photo: ImageLabel, name: TextLabel,
	stolen: TextLabel, bounty: TextLabel, empty: TextLabel,
}
type BoardUI = {
	empty: TextLabel,
	rows: { { row: Frame, who: TextLabel, amount: TextLabel } },
}
local wantedBoards: { WantedUI } = {}
local boards: { BoardUI } = {}

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
-- WHERE THE TWO BOARDS STAND, and the one number that keeps them out of the
-- tunnel.
--
-- The bore is 11 studs either side of the centreline and 14 high. A board on
-- the centreline is a board across the portal, which is exactly what the
-- leaderboard was: 30 wide at z = 0, twenty-eight studs in front of the mouth.
--
-- At 26 out and yawed 45 degrees, the widest board's own footprint reaches
-- HOW FAR OUT ON THE VERGE A BOARD STANDS, and it is DERIVED now.
--
-- It was 26, measured against a tunnel bore these boards no longer stand at,
-- and it only kept working by luck through two moves. The verge is the thing
-- that actually bounds it, so `streetMetrics` computes the mid-verge line and
-- both boards and shops read it -- widen the street and they follow instead
-- of quietly ending up in the road or through a fence.
--
-- Mid-verge rather than hard against the fence: a board reads from the
-- carriageway AND from the pavement, and the shops take the back of the band.
local function boardZ(): number
	return Config.streetMetrics().boardZ
end

-- ONE PAIR, IN THE TOWN SQUARE, and that is a SIMPLIFICATION rather than a cut.
--
-- There were two pairs, one at each end of the street, and the note below
-- says why: a SurfaceGui culls on distance from the CHARACTER rather than the
-- camera, so a single pair at the west end was never RENDERED for the plots at
-- the east -- not merely far away, absent. Two pairs was the fix available
-- while the only wide ground was at the ends.
--
-- The square moving to the middle removes the problem instead of working
-- around it. Every plot is now within 128 studs of one pair, which is inside
-- the cull radius by construction -- and one pair cannot disagree with itself
-- about who is winning, which was the other thing two pairs had to be careful
-- about.
local function boardX(): number
	return 0
end

-- FACING ACROSS THE STREET, at each other over the square.
--
-- The 45-degree splay is gone with the end pairs, and it should be: it existed
-- because a board at the mouth of a tunnel had to serve somebody approaching
-- ALONG the street and somebody standing on the plaza, and halfway was the
-- only angle that served both. In the middle of the row there is no such
-- compromise -- the readers are standing in the square between the two boards,
-- so each simply faces it. Roblox Front is -Z, so the board on the +Z shoulder
-- takes no rotation at all and the one opposite takes a half turn.
local function boardYaw(z: number): number
	return if z > 0 then 0 else math.pi
end

-- A pair of legs under a board, angled with it.
--
-- One centre post reads as a village notice board. Two read as a billboard,
-- which is what these became the moment they moved to the roadside -- and the
-- legs have to carry the same yaw as the panel or they splay out from under
-- it at every angle except head-on.
--
-- ACROSS THE PANEL, NOT THROUGH IT. This carried an extra `-90` on the
-- offset direction, which is a quarter turn off the panel's width axis and
-- therefore lands exactly on its NORMAL -- so the two legs stood one in
-- front of the board and one behind it, on the board's centreline, holding
-- up nothing. Every board in the game floated with a free-standing post to
-- either side of it, which is what got reported: random posts by the signs.
--
-- The panel is built as `CFrame.new(...) * CFrame.Angles(0, yaw, 0)` with
-- its width on local X, so the direction the legs have to spread along is
-- that same frame's RightVector and nothing else. Measured after: all eight
-- legs at alongWidth +-9.60 (leaderboard) and +-5.12 (poster), alongDepth
-- 0.00 -- against alongWidth 0.00 and alongDepth +-9.60 before.
--
-- The leg's own rotation gets the panel's yaw too. On a square 1.6 x 1.6
-- post that is invisible either way, but a leg that disagrees with the sign
-- it holds up is the next person's bug.
local function billboardLegs(name: string, at: Vector3, width: number, yaw: number)
	for _, side in ipairs({ -1, 1 }) do
		local across = CFrame.Angles(0, yaw, 0).RightVector * (side * width * 0.32)
		local leg = Instance.new("Part")
		leg.Name = name .. "Leg"
		leg.Size = Vector3.new(1.6, 14, 1.6)
		leg.CFrame = CFrame.new(at + across + Vector3.new(0, 7, 0))
			* CFrame.Angles(0, yaw, 0)
		leg.Anchored = true
		leg.Material = Enum.Material.Wood
		leg.Color = Color3.fromRGB(104, 74, 50)
		leg.Parent = workspace.World
	end
end

-- THE LEADERBOARD, on the +Z shoulder of the square.
local function buildBoard()
	-- FLANKING THE TUNNEL, NOT STANDING IN IT.
	--
	-- This once sat dead on the road centreline, thirty studs wide, directly
	-- in front of a tunnel bore only 22 wide -- so from anywhere on the street
	-- the west portal was a board on legs. It went to one shoulder and the
	-- wanted poster took the other.
	--
	-- Both are mid-verge now, facing each other across the road at x 0, and
	-- the rule is the same one: the CARRIAGEWAY STAYS CLEAR. `boardZ` is
	-- halfway between the kerb and the fence line, so there is a pavement's
	-- width between the board and the tarmac and nothing to drive around.
	local anchor = Vector3.new(boardX(), 0, boardZ())
	local yaw = boardYaw(boardZ())

	-- TWO LEGS, NOT ONE POST. A single centre post reads as a village notice
	-- board; a pair reads as a billboard, which is what these are now that
	-- they stand at the roadside rather than at the head of the street.
	billboardLegs("Leaderboard", anchor, 30, yaw)

	local panel = Instance.new("Part")
	panel.Name = "Leaderboard"
	panel.Size = Vector3.new(30, 20, 1)
	panel.CFrame = CFrame.new(anchor + Vector3.new(0, 22, 0)) * CFrame.Angles(0, yaw, 0)
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

	local rows: { { row: Frame, who: TextLabel, amount: TextLabel } } = {}

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

		table.insert(rows, { row = row, who = who, amount = amount })
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
	table.insert(boards, { empty = empty, rows = rows })
end

local function refreshBoard()
	if #boards == 0 then
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

	-- EVERY board, not the last one built. Ranking once and painting many is
	-- also why the sort is out here: two boards must never disagree about who
	-- is winning, and they cannot if they are reading one list.
	for _, ui in ipairs(boards) do
		ui.empty.Visible = #ranked == 0
		for index, entry in ipairs(ui.rows) do
			local ranking = ranked[index]
			entry.row.Visible = ranking ~= nil
			if ranking then
				entry.who.Text = ("%d.  %s"):format(index, ranking.player.DisplayName)
				entry.amount.Text = format(ranking.coins)
			end
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

	-- Lives on the Head, not the character: a BillboardGui adorns its parent.
	local existing = head:FindFirstChild("MostWantedHat")
	if not wanted then
		if existing then
			existing:Destroy()
		end
		return
	end
	if existing then
		return
	end

	-- A floating label and nothing else.
	--
	-- This used to weld a neon cylinder over the head as a hat. A Roblox
	-- cylinder's axis is its X axis, so Vector3.new(2.2, 0.5, 2.2) is not a
	-- 2.2-wide disc half a stud thick -- it is a rod 2.2 studs LONG, and the
	-- 90-degree turn meant to lay a brim flat stood that rod upright instead.
	-- Every most-wanted player wore an orange spike out of the top of their
	-- skull. The label was always the part that did the work, so it is now
	-- the whole thing: nothing is welded to the character and nothing can
	-- clip through a hair accessory.
	local label = Instance.new("BillboardGui")
	label.Name = "MostWantedHat"
	label.Size = UDim2.new(0, 180, 0, 34)
	label.StudsOffset = Vector3.new(0, 2.6, 0)
	label.AlwaysOnTop = true
	label.Parent = head

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

-- What this player's rap sheet has to reach before the patrol will come
-- looking for them unprovoked. Seconds of their OWN income; see Config.POLICE.
local function wantedFloor(player: Player): number
	local data = DataService.get(player)
	if not data then
		return math.huge
	end
	local rate = Config.getIncomeRate(
		data.incomeLevel, data.rebirths, SocialService.getFriendBonus(player))
	return rate * Config.POLICE.wantedFloorSeconds
end

-- The server's biggest thief wears something nobody can buy. It's the only
-- status in the game that can't be purchased, which is exactly why it works.
local function refreshMostWanted()
	local best: Player? = nil
	local bestAmount = 0

	for _, player in ipairs(Players:GetPlayers()) do
		local record = heat[player] or 0
		-- The floor is tested per PLAYER rather than once against the winner,
		-- so a rich player's petty theft cannot hold the title against a
		-- poorer player's serious one.
		if record > bestAmount and record >= wantedFloor(player) then
			best = player
			bestAmount = record
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
		-- Names the consequence, not just the status. Being told you are Most
		-- Wanted and then chased by an officer nobody warned you about is the
		-- patrol arriving as bad luck, which is the one thing this feature is
		-- not allowed to be -- bad luck is not something a nine year old can
		-- get better at.
		Remotes.get("Notify"):FireClient(best,
			"You are MOST WANTED. The next patrol comes for you.", "warn")
	end
end

-- ============================================================
-- THE WANTED BOARD
-- ============================================================
--
-- Stands in the arrival plaza beside the leaderboard, at the head of the
-- cul-de-sac: the two boards are the first thing a player sees when they spawn
-- and the last thing they pass on the way out to the street.
--
-- A PORTRAIT POSTER AGAINST THE LEADERBOARD'S LANDSCAPE TABLE, which is the
-- whole reason it reads as a different object from forty studs away instead of
-- as a second, shorter list of names. It carries one face and three lines,
-- because it is about ONE person -- a ranked top eight of thieves would just
-- be the richest-piggies board again with a different column in it.
local function buildWantedBoard()
	-- Offset across the street's width so the two boards stand shoulder to
	-- shoulder and look the same way down the road.
	-- The opposite shoulder, mirrored, so the two frame the tunnel mouth.
	local anchor = Vector3.new(boardX(), 0, -boardZ())
	local yaw = boardYaw(-boardZ())
	billboardLegs("WantedBoard", anchor, 16, yaw)


	local panel = Instance.new("Part")
	panel.Name = "WantedBoard"
	panel.Size = Vector3.new(16, 22, 1)
	-- The same quarter turn the leaderboard takes: Roblox's Front face is -Z,
	-- and after this yaw that looks down the street at the plots.
	panel.CFrame = CFrame.new(anchor + Vector3.new(0, 23, 0)) * CFrame.Angles(0, yaw, 0)
	panel.Anchored = true
	panel.Material = Enum.Material.WoodPlanks
	panel.Color = Color3.fromRGB(78, 56, 40)
	panel.Parent = workspace.World

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	-- 400x550 over a 16x22 panel is 25 pixels per stud, against the
	-- leaderboard's 600x400 over 30x20, which is 20. THE TWO BOARDS THEREFORE
	-- DO NOT SHARE A TYPE SCALE: a 62-pixel row is 3.1 studs tall over there
	-- and 2.5 here, so copying the leaderboard's numbers across rendered this
	-- poster's heading visibly smaller than the list beside it -- on the board
	-- that is meant to be the louder of the two. Every height below is chosen
	-- in studs and multiplied up, not carried over.
	surface.CanvasSize = Vector2.new(400, 550)
	surface.LightInfluence = 0

	local backdrop = Instance.new("Frame")
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.BackgroundColor3 = Color3.fromRGB(46, 38, 58)
	backdrop.BackgroundTransparency = 0.05
	backdrop.BorderSizePixel = 0
	backdrop.Parent = surface

	local title = Instance.new("TextLabel")
	-- 80px / 25 = 3.2 studs, which is the leaderboard's own heading height.
	title.Size = UDim2.new(1, -30, 0, 80)
	title.Position = UDim2.new(0, 15, 0, 10)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(240, 196, 76)
	title.Text = "MOST WANTED"
	title.Parent = backdrop

	local card = Instance.new("Frame")
	card.Name = "Suspect"
	card.Size = UDim2.new(1, -30, 1, -110)
	card.Position = UDim2.new(0, 15, 0, 96)
	card.BackgroundTransparency = 1
	card.Visible = false
	card.Parent = backdrop

	local photo = Instance.new("ImageLabel")
	photo.Name = "Photo"
	photo.Size = UDim2.new(0, 256, 0, 256)
	photo.Position = UDim2.new(0.5, -128, 0, 0)
	photo.BackgroundColor3 = Color3.fromRGB(28, 24, 36)
	photo.BorderSizePixel = 0
	photo.Parent = card

	local frame = Instance.new("UIStroke")
	frame.Thickness = 4
	frame.Color = Color3.fromRGB(240, 196, 76)
	frame.Parent = photo

	local name = Instance.new("TextLabel")
	-- "Who", matching the leaderboard rows, and NOT "Name": a child called Name
	-- is shadowed by the Instance.Name property on every dotted lookup, so
	-- board.Suspect.Name reads back the string "Suspect" rather than the label.
	-- The service itself holds a direct reference and never noticed; anything
	-- inspecting the board from outside would have to know to use FindFirstChild.
	name.Name = "Who"
	name.Size = UDim2.new(1, 0, 0, 60)
	name.Position = UDim2.new(0, 0, 0, 268)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.FredokaOne
	name.TextScaled = true
	name.TextColor3 = Color3.fromRGB(246, 240, 228)
	name.Text = ""
	name.Parent = card

	local stolen = Instance.new("TextLabel")
	stolen.Name = "Stolen"
	stolen.Size = UDim2.new(1, 0, 0, 42)
	stolen.Position = UDim2.new(0, 0, 0, 332)
	stolen.BackgroundTransparency = 1
	stolen.Font = Enum.Font.Gotham
	stolen.TextScaled = true
	stolen.TextColor3 = Color3.fromRGB(190, 180, 196)
	stolen.Text = ""
	stolen.Parent = card

	-- What a catch would actually cost them, spelled out. The patrol is
	-- published on principle -- the siren runs fifteen seconds ahead of the car
	-- and the HUD counts both clocks -- and a bounty nobody could read would be
	-- the one part of it that still arrived as a surprise.
	local bounty = Instance.new("TextLabel")
	bounty.Name = "Bounty"
	-- Runs to the foot of the card. The first pass left 48 pixels of dead
	-- board under the bounty, which on a poster reads as a printing error.
	bounty.Size = UDim2.new(1, 0, 0, 54)
	bounty.Position = UDim2.new(0, 0, 0, 376)
	bounty.BackgroundTransparency = 1
	bounty.Font = Enum.Font.FredokaOne
	bounty.TextScaled = true
	bounty.TextColor3 = Color3.fromRGB(226, 86, 80)
	bounty.Text = ""
	bounty.Parent = card

	-- Teaches the mechanic rather than reporting a blank, which is the state
	-- this board is in for the first minutes of every server.
	local empty = Instance.new("TextLabel")
	empty.Name = "Empty"
	empty.Size = UDim2.new(1, -30, 0, 150)
	empty.Position = UDim2.new(0, 15, 0.38, 0)
	empty.BackgroundTransparency = 1
	empty.Font = Enum.Font.Gotham
	empty.TextScaled = true
	empty.TextColor3 = Color3.fromRGB(150, 140, 150)
	empty.Text = "no suspects\n\nrob a neighbour\nto get on this board"
	empty.Parent = backdrop

	surface.Parent = panel

	table.insert(wantedBoards, {
		card = card, photo = photo, name = name,
		stolen = stolen, bounty = bounty, empty = empty,
	})
end

local function refreshWantedBoard()
	local suspect = mostWanted

	-- Computed ONCE and painted onto every poster. Two boards must never
	-- disagree about who is wanted, and they cannot if they are reading one
	-- answer rather than each working it out.
	local photo, name, stolen, bounty = "", "", "", ""
	if suspect then
		-- rbxthumb, never GetUserThumbnailAsync: the content URL resolves
		-- itself and never yields, so a board refresh cannot be held up by a
		-- web call. Same reason the arrest scene's mugshot uses it.
		photo = ("rbxthumb://type=AvatarHeadShot&id=%d&w=420&h=420"):format(suspect.UserId)
		name = suspect.DisplayName:upper()
		local record = heat[suspect] or 0
		stolen = ("STOLEN  %s"):format(format(record))
		bounty = ("BOUNTY  %s"):format(
			format(math.floor(record * Config.POLICE.bailMultiple)))
	end

	for _, ui in ipairs(wantedBoards) do
		ui.card.Visible = suspect ~= nil
		ui.empty.Visible = suspect == nil
		if suspect then
			ui.photo.Image = photo
			ui.name.Text = name
			ui.stolen.Text = stolen
			ui.bounty.Text = bounty
		end
	end
end

-- ============================================================
-- THE RAP SHEET
-- ============================================================

-- One successful delivery. Called by HeistService and by nothing else: coins
-- that arrive any other way -- income, banking, a daily, a rebirth -- were not
-- taken off anybody.
function SocialService.recordSteal(thief: Player, amount: number)
	heat[thief] = (heat[thief] or 0) + amount
end

-- Answered for. Called by PoliceService when a most-wanted pursuit ends in an
-- arrest, and by nothing else.
--
-- ONLY THAT ARREST CLEARS IT. A thief caught mid-robbery pays three times the
-- loot in their hands and keeps their record, because that is what they were
-- caught for. Clearing on any arrest would be an exploit with a friendly face:
-- run a hundred thousand up on the board, get deliberately caught carrying
-- fifty coins, pay a hundred and fifty, and walk away clean.
function SocialService.clearHeat(player: Player)
	heat[player] = nil
end

-- What is on one player's sheet right now. Separate from getMostWanted
-- because the board only moves on its refresh tick: a caller that has just
-- written to a sheet and wants to read it back would otherwise get the stale
-- winner and conclude nothing happened.
function SocialService.getHeat(player: Player): number
	return heat[player] or 0
end

-- Recompute the board NOW rather than on its five-second tick. Only the dev
-- console needs this: everything else can wait a tick, and a refresh per steal
-- would be twelve DataService reads on every delivery.
function SocialService.refresh()
	refreshMostWanted()
	refreshWantedBoard()
end

-- Put this player at the top of the board, for the dev console. Enough to clear
-- their OWN income floor and to beat whoever is currently leading -- both,
-- because either alone leaves the board unchanged and the command looking
-- broken.
function SocialService.makeMostWanted(player: Player): number
	local top = 0
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			top = math.max(top, heat[other] or 0)
		end
	end
	heat[player] = math.floor(math.max(wantedFloor(player), top * 1.25) + 1000)
	SocialService.refresh()
	return heat[player]
end

-- The name on the board, and the figure on it. Already floored -- see
-- refreshMostWanted -- so a caller does not repeat that test.
function SocialService.getMostWanted(): (Player?, number)
	local suspect = mostWanted
	if not suspect then
		return nil, 0
	end
	return suspect, heat[suspect] or 0
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
	-- One of each, facing each other across the square. The refresh below
	-- still drives a LIST rather than the last board built, which costs
	-- nothing and is what a second pair would need again if the street ever
	-- gets long enough to want one.
	buildBoard()
	buildWantedBoard()

	Players.PlayerRemoving:Connect(function(player)
		friendBonus[player] = nil
		-- The rap sheet dies with the session it belongs to. Left behind, it
		-- would also hold a Player reference open for the life of the server.
		heat[player] = nil
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
			-- In this order: the poster reads whatever refreshMostWanted just
			-- decided, so it and the floating label can never disagree about
			-- who is wanted.
			refreshMostWanted()
			refreshWantedBoard()
		end
	end)
end

return SocialService
