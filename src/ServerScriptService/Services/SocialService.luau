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
-- THE BOARDS WERE A FIFTH PALETTE, AND THIS IS WHAT ENDS THAT.
--
-- `Theme` was written to be the one place a colour is decided, and the sweep
-- that produced it went through ClientMain, ShopStyle, Rebirth and
-- AdminPanel -- every UI file in the CLIENT. These two boards are built on
-- the SERVER, so they were never in that pass and never in the contrast audit
-- either: eighteen hardcoded colours, including two near-blacks at hue 264
-- and 272, which are VIOLETS against a palette whose every neutral sits
-- between hue 21 and 39. Nothing looked broken; they simply were not from
-- this game.
--
-- Theme requires nothing, so a server service may take it. What it must NOT
-- do is start reaching for the client-only helpers -- these are SurfaceGuis
-- built once and replicated, so anything animated or per-viewer belongs on
-- the client, exactly as the moat and the skins do.
local Theme = require(ReplicatedStorage.Shared.Theme)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local TrophyService = require(script.Parent.TrophyService)

local SocialService = {}

local friendBonus: { [Player]: number } = {}

-- IsFriendsWith is a web call. Cached per unordered pair for the life of the
-- server so a twelve-player room costs at most sixty-six lookups total
-- instead of re-asking every time somebody joins.
local friendCache: { [string]: boolean } = {}

local mostWanted: Player? = nil

-- DOES THE NAME ON THE BOARD ALSO CLEAR THEIR OWN INCOME FLOOR?
--
-- Two different questions, and they used to be one. See refreshMostWanted.
local wantedHunted = false

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
-- Counted on DELIVERY rather than on the grab, because loot nabbed out of your
-- hands or confiscated by the patrol was never stolen -- you were caught. Same
-- line `data.totalStolen` already draws, one statement above the call.
--
-- Strong-keyed on Player and cleared in PlayerRemoving. NOT a weak table: the
-- note at the top of RidePose is about exactly this -- the collector cannot
-- see the DataModel's own reference to an Instance, so a weak key here would
-- be collected out from under a player who is still standing on the street.
local heat: { [Player]: number } = {}

-- THE STARS, AND THEY ARE NOT THE TABLE ABOVE. `heat` is the RAP SHEET: every
-- coin taken this session, only ever rising, and what the Most Wanted board
-- ranks on. Stars count deliveries in a run, FADE while you lay low (one per
-- `WANTED_STARS.fade` seconds of quiet), and are wiped by being caught. They
-- were the spree; see Config.WANTED_STARS for why the two ladders became
-- one drawn on the wanted chip.
--
-- Two tables rather than two meanings in one, which is the `busyUntil` /
-- `napUntil` lesson: one field carrying two clocks had two readers
-- disagreeing about it in opposite directions, and the item that depended on
-- it silently bought nothing for six minutes at a time.
--
-- `at` is the moment the CURRENT count became true: a fade advances it by
-- whole fade windows rather than resetting it, so a star lost at 120s of
-- quiet is not followed by another one at 121s.
--
-- STAMPED IN `workspace:GetServerTimeNow()`, NOT `os.clock` (designer
-- decision 2026-09-22: the fill DRAINS on the chip rather than blinking
-- off). The client draws a star emptying across the fade window from this
-- stamp alone -- the same "server publishes a stamp, client derives the
-- picture" shape the crack's marker and the herd's dig take -- and
-- `os.clock` is a process uptime that means nothing across the wire. Both
-- ends subtract the same stamp from the same clock against the same
-- `WANTED_STARS.fade`, so the gold reaches empty on screen in the instant
-- `starsOf` drops the star here; the picture and the rule cannot disagree.
--
-- THE MOST WANTED PLAYER IS PINNED AT `max` AND DOES NOT FADE, until the
-- board changes hands -- a rule of `starsOf`, below, and not of the chip.
local stars: { [Player]: { count: number, at: number } } = {}

-- One clock for every star stamp, so a later reader cannot mix the two.
local function serverNow(): number
	return workspace:GetServerTimeNow()
end

-- What five stars summons. Filled by Main with `PoliceService.call`, because
-- PoliceService requires this service and asking back would be a cycle --
-- the same registry shape `SetService.registerPusher` uses.
local starAlarm: (() -> ())? = nil

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
-- around it. One pair cannot disagree with itself about who is winning, which
-- was the other thing two pairs had to be careful about.
--
-- AND "THE MIDDLE" WAS A DRIVEWAY, WHICH IS WHAT THIS FUNCTION IS NOW FOR.
--
-- It returned a flat `0`, and that was free ground for exactly as long as
-- `Config.PLOTS_PER_ROW` was EVEN: at four a side the columns sit at +-120 and
-- +-40 and nothing stands on the centreline at all. It went to FIVE, which
-- `Config.plotColumnX` handles by construction -- five columns simply put one
-- at x 0 -- and that put the middle plot's DRIVEWAY precisely where both
-- boards were standing.
--
-- Measured on the built street before they moved: the wanted poster spanned
-- x -8.0..8.0 against a driveway of x -8.5..8.5, so it stood ENTIRELY on the
-- tarmac, and seventeen of the leaderboard's thirty studs were over it with
-- its legs a stud either side. Nothing errored, nothing warned, and a board on
-- a drive reads as a board beside a drive from most of the angles anybody
-- looks from.
--
-- IT IS THE SAME CLASS AS THE KERBSIDE MAILBOX FOUND THE SAME AFTERNOON, and
-- worth stating as a class rather than as two bugs: a placement solved
-- correctly against a constant, left standing when the constant moved. The
-- five-a-side entry in `CLAUDE.md` even records the even-count constraint
-- being DROPPED -- "a stale constraint had been doubling the price of a fix
-- nobody had priced" -- and nothing went looking for what else had been
-- relying on it. **DELETING A CONSTRAINT MEANS GREPPING FOR WHAT ASSUMED IT.**
--
-- SO IT IS DERIVED FROM THE ROW. Everything on this verge stands in a GAP
-- between two driveways -- the lamp posts, the wheelie bins and all four shops
-- do -- and `Config.SHOPS` takes gaps 0 and 2, so the boards take the nearest
-- FREE gap to the middle of the row. A column added, or a shop moved to
-- another gap, carries them with it rather than quietly standing them on
-- somebody's tarmac again.
--
-- AND THE TREE VETO ALREADY RESERVED THAT BAND, which is what makes a gap
-- centre the honest answer rather than merely a clear one.
-- `buildStreetTrees` holds every canopy `SHOP_HALF + reach` -- about 17 studs
-- -- clear of every gap centre, and its own comment says why in as many
-- words: *"the gap centres, which is where the shops and the boards stand"*.
-- The leaderboard is 30 wide, so it reaches 15 from the centre, and the two
-- studs left over belong to that veto rather than to luck.
--
-- WHAT IT COSTS IS THE CULL DISTANCE THE NOTE ABOVE IS ABOUT, and that is
-- recorded rather than waved at. Off-centre by one gap, the far end of the
-- row is further from the nearer board than it was: measured after the move,
-- the worst plot-to-board distance went 168 studs to 205. Both boards carry
-- `MaxDistance = 0`, and the absence this whole entry was written about was
-- measured at roughly 380 studs, so there is still better than a factor of
-- one and a half in hand -- but this is now the number to re-derive before
-- anybody lengthens the street, rather than a comfortable one.
local function boardX(): number
	-- WHICH GAPS ARE ALREADY BUILT ON. `Config.SHOPS` is the one place that
	-- says, and reading it rather than restating it means a shop moved to
	-- another gap moves the boards instead of landing on top of them.
	local taken: { [number]: boolean } = {}
	for _, placement in ipairs(Config.SHOPS) do
		taken[placement.gap] = true
	end

	-- The midpoint of two frontages, which is `NeighborhoodService`'s own
	-- `gapX` written out. One line, and it is duplicated deliberately rather
	-- than lifted into `Config`: that file is the single source three
	-- workstreams want at once, and a third reader is the point at which this
	-- earns a `Config.gapX` and this comment goes away.
	local best: number? = nil
	for gap = 0, Config.PLOTS_PER_ROW - 2 do
		if not taken[gap] then
			local x = (Config.plotColumnX(gap) + Config.plotColumnX(gap + 1)) / 2
			if best == nil or math.abs(x) < math.abs(best) then
				best = x
			end
		end
	end

	-- EVERY GAP HOLDING A SHOP IS A REAL CONFIGURATION -- four shops on a
	-- three-gap row -- and it must not silently put a board back on a
	-- driveway. The centre of the row is the one answer that is certainly
	-- wrong, so this says so out loud and stands them past the last column,
	-- where the verge runs to the hillside with nothing on it. A board nobody
	-- walks past is a smaller failure than a board in a drive, and a warning
	-- is what stops it being a silent one.
	if best == nil then
		warn("[SocialService] every gap on the row holds a shop, so the boards have no gap"
			.. " to stand in and are past the end of the row instead."
			.. " Free a gap in Config.SHOPS.")
		return Config.plotColumnX(Config.PLOTS_PER_ROW - 1) + Config.PLOT_SPACING / 2
	end
	return best
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
		-- THE TIMBER STAYS A LITERAL, AND IT WAS CHECKED RATHER THAN MISSED.
		-- Everything on the FACE of these boards now comes from `Theme`, but
		-- the legs and the panel are a Part with a wood material on it -- a
		-- physical object in the world, not a surface carrying an interface.
		-- Putting a plank colour in the UI palette would be the first entry
		-- there that no GuiObject ever reads. Both hues were measured against
		-- the palette's own band anyway (21 to 39, outline to paper) and both
		-- land inside it at 27 and 25, so the wood and the paper on it are
		-- already the same family.
		leg.Material = Enum.Material.Wood
		leg.Color = Color3.fromRGB(104, 74, 50)
		leg.Parent = workspace.World
	end
end

-- THE LEADERBOARD, on the +Z shoulder of the square.
-- ============================================================
-- THE WEEKLY LADDER
-- ============================================================
--
-- THE ONE RANKING IN THIS GAME THAT OUTLIVES THE SERVER. Everything else here
-- reads `Players:GetPlayers()`, so it is true for as long as the eight people
-- currently standing on the street stay on it. See `Config.WEEKLY_HEIST` for
-- why rank is the only thing this design is allowed to let decay.

local DataStoreService = game:GetService("DataStoreService")

-- Cached page of the sorted store, plus when it was fetched. A board that
-- asked the datastore on its own five-second tick would burn the sorted-read
-- budget for a number that moves once a robbery.
local weeklyTop: { { name: string, amount: number } } = {}
local weeklyFetchedAt = -math.huge
local weeklyFetching = false
-- Declared here rather than beside the loop that reads it: a `local` written
-- below its reader is a nil global to it, which this project has recorded
-- nine times and once took the whole server down.
local lastWeeklyPublish = -math.huge

-- Names are cached because a sorted page hands back USER IDS and nothing else,
-- and `GetNameFromUserIdAsync` is a web call per row. Keyed by id and never
-- cleared: a name is not going to change under us within a server's life, and
-- eight of them is not a leak worth managing.
local weeklyNames: { [number]: string } = {}

local function weeklyStore(): OrderedDataStore
	-- THE WEEK IS PART OF THE KEY, WHICH IS WHAT MAKES THE RESET FREE. There
	-- is nothing to clear at midnight on Sunday and no job to schedule: the
	-- new week simply reads an empty page, and last week's stays intact behind
	-- it in case it is ever worth showing.
	return DataStoreService:GetOrderedDataStore(
		("%s.%d"):format(Config.WEEKLY_HEIST.store, Config.weekIndex()))
end

-- Rolls a save onto the current week if it is carrying an older one. Lazy,
-- because nothing in the game has to happen at the moment a week turns over --
-- the same argument the spree's expiry makes for having no loop.
local function currentWeekStolen(data): number
	local week = Config.weekIndex()
	if data.week.index ~= week then
		data.week.index = week
		data.week.stolen = 0
	end
	return data.week.stolen
end

-- Writes one player's weekly total. Guarded, because a DataStore call is a
-- yield that can throw, and a leaderboard may never take the server with it --
-- the same rule `Decor.prewarm` and the dog watcher already follow.
local function publishWeekly(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local amount = currentWeekStolen(data)
	if amount <= 0 then
		-- Nothing to publish, and writing a zero would put every player who
		-- has never robbed anybody onto the page ahead of nobody at all.
		return
	end
	local store = weeklyStore()
	local ok, err = pcall(function()
		store:SetAsync(tostring(player.UserId), math.floor(amount))
	end)
    if not ok then
		warn(("[SocialService] could not publish %s's weekly total: %s"):format(
			player.Name, tostring(err)))
	end
end

local function fetchWeekly()
	if weeklyFetching or os.clock() - weeklyFetchedAt < Config.WEEKLY_HEIST.refresh then
		return
	end
	weeklyFetching = true
	task.spawn(function()
		local ok, err = pcall(function()
			local pages = weeklyStore():GetSortedAsync(false, Config.WEEKLY_HEIST.rows)
			local page = pages:GetCurrentPage()
			local fresh = {}
			for _, entry in ipairs(page) do
				local id = tonumber(entry.key)
				local name = id and weeklyNames[id]
				if id and not name then
					-- Tolerated failing: an unresolvable id is a row with a
					-- number on it, which is far better than no board.
					local nameOk, resolved = pcall(function()
						return Players:GetNameFromUserIdAsync(id)
					end)
					name = if nameOk then resolved else ("player %d"):format(id)
					weeklyNames[id] = name
				end
				table.insert(fresh, { name = name or "?", amount = entry.value })
			end
			weeklyTop = fresh
		end)
		if not ok then
			warn("[SocialService] weekly board fetch failed: " .. tostring(err))
		end
		weeklyFetchedAt = os.clock()
		weeklyFetching = false
	end)
end

-- Coins taken from a victim, added to this week's total. Called on DELIVERY
-- and never on the grab, the same line `data.totalStolen` and the rap sheet
-- already draw: loot nabbed out of your hands or confiscated by a patrol was
-- never stolen, you were caught.
function SocialService.recordWeekly(player: Player, amount: number)
	local data = DataService.get(player)
	if not data then
		return
	end
	currentWeekStolen(data)
	data.week.stolen += amount
end

function SocialService.getWeeklyTop(): { { name: string, amount: number } }
	return weeklyTop
end

-- ============================================================
-- TOP DEFENDERS THIS WEEK (Phase 5.5)
-- ============================================================
--
-- The weekly twin of Top Thieves, so defending is a collection rather than
-- a tax: a thief nabbed, a dog's catch, a hot skin brought home. Same store
-- shape, same lazy week roll, same cache.
local defend = { top = {} :: { { name: string, amount: number } }, fetchedAt = -math.huge, fetching = false }

local function defendStore(): OrderedDataStore
	return DataStoreService:GetOrderedDataStore(
		("%s.%d"):format(Config.WEEKLY_DEFEND.store, Config.weekIndex()))
end

local function currentWeekDefends(data): number
	local week = Config.weekIndex()
	if type(data.defend) ~= "table" then
		data.defend = { index = week, count = 0 }
	end
	if data.defend.index ~= week then
		data.defend.index = week
		data.defend.count = 0
	end
	return data.defend.count
end

function SocialService.recordDefend(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	currentWeekDefends(data)
	data.defend.count += 1
end

local function publishDefend(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local count = currentWeekDefends(data)
	if count <= 0 then
		return
	end
	local ok, err = pcall(function()
		defendStore():SetAsync(tostring(player.UserId), math.floor(count))
	end)
	if not ok then
		warn(("[SocialService] could not publish %s's defends: %s"):format(player.Name, tostring(err)))
	end
end

local function fetchDefend()
	if defend.fetching or os.clock() - defend.fetchedAt < Config.WEEKLY_DEFEND.refresh then
		return
	end
	defend.fetching = true
	task.spawn(function()
		local ok, err = pcall(function()
			local page = defendStore():GetSortedAsync(false, Config.WEEKLY_DEFEND.rows):GetCurrentPage()
			local fresh = {}
			for _, entry in ipairs(page) do
				local id = tonumber(entry.key)
				local name = id and weeklyNames[id]
				if id and not name then
					local nameOk, resolved = pcall(function()
						return Players:GetNameFromUserIdAsync(id)
					end)
					name = if nameOk then resolved else ("player %d"):format(id)
					weeklyNames[id] = name
				end
				table.insert(fresh, { name = name or "?", amount = entry.value })
			end
			defend.top = fresh
		end)
		if not ok then
			warn("[SocialService] defenders board fetch failed: " .. tostring(err))
		end
		defend.fetchedAt = os.clock()
		defend.fetching = false
	end)
end

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
	-- Named, because the retired season page used to be drawn by each client
	-- over this one, hiding it locally by name. Kept: a named instance is what
	-- anything inspecting this board addresses it by.
	surface.Name = "BoardGui"
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(600, 400)
	-- Unlit, so the text stays readable whichever way the sun is pointing.
	surface.LightInfluence = 0
	-- Parented at the bottom of this function, once every child exists, so
	-- the whole board replicates as one piece instead of a dozen increments.

	-- A PRINTED SHEET ON A WOODEN BOARD, AND THE INSET IS WHAT SAYS SO.
	--
	-- It used to fill the face edge to edge in a violet dark, which reads as a
	-- SCREEN set into the timber rather than as something pinned to it. Paper
	-- inset far enough to leave the wood showing all round is the picture the
	-- object already is -- and it is the theme's own argument arriving at the
	-- one place that had never heard it: cream reads as a label stuck on the
	-- world, dark reads as a window cut into it. These boards are labels.
	--
	-- 16px HERE AND 20px ON THE POSTER, which is the same 0.8 studs of timber
	-- on both. The two boards do not share a pixel scale -- 20 per stud here
	-- against 25 there -- so a border copied across as a pixel count would
	-- come out visibly narrower on one of them. Choose it in studs, multiply
	-- up. Same rule the type heights already follow.
	local backdrop = Instance.new("Frame")
	backdrop.Name = "Sheet"
	backdrop.Size = UDim2.new(1, -32, 1, -32)
	backdrop.Position = UDim2.new(0, 16, 0, 16)
	backdrop.Parent = surface
	Theme.card(backdrop, 10)
	-- 4px is 0.2 studs, against the HUD's 3px at arm's length. The ink line
	-- has to survive being looked at from the far end of the street.
	Theme.outline(backdrop, 4)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -40, 0, 62)
	title.Position = UDim2.new(0, 20, 0, 12)
	title.BackgroundTransparency = 1
	title.TextScaled = true
	-- GOLD_INK, NOT GOLD. Raw gold on paper measures 1.42:1 -- a heading you
	-- can see is there and cannot read. The darkened form is what every gold
	-- label on a light ground in this game uses.
	Theme.title(title, 62, Theme.GOLD_INK)
	-- TOP THIEVES, NOT RICHEST PIGGIES, AND THE OLD BOARD WAS CELEBRATING THE
	-- WRONG BEHAVIOUR. It ranked live `data.coins` -- so the biggest name on
	-- the street was whoever had sat on their own lawn the longest, in a game
	-- whose whole economy was rewritten to make that the WORST way to play. A
	-- board is an instruction about what is worth doing, and that one was
	-- pointing at idling.
	--
	-- It also could not survive its own server. Every ranking in this project
	-- read `Players:GetPlayers()`, so nothing anybody did on Tuesday existed
	-- on Wednesday. See `Config.WEEKLY_HEIST`.
	--
	-- THE PAIR STILL SPLITS THE SAME WAY, which is what keeps the two boards
	-- from disagreeing: the portrait poster is ONE PERSON and RIGHT NOW (who
	-- the patrol is coming for, this session), and this landscape list is the
	-- LADDER (who is winning, this week). Two questions, two boards, exactly
	-- as before -- only the list's question got better.
	title.Name = "Title"
	title.Text = "TOP THIEVES  THIS WEEK"
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
		-- ZEBRA STRIPING IN THE SAND, which is what a printed table looks
		-- like. The alternation is the same idea it always was; what changed
		-- is that the darker band is now a warm tan out of the palette rather
		-- than a violet-grey that belonged to nothing.
		row.BackgroundColor3 = Theme.SAND_DEEP
		-- LIGHT. Measured, a heavier band took the GOLD amount column -- the
		-- one number this board exists to show -- down to 3.49 against the
		-- paper's 3.98, so the same column read differently on every other
		-- row. The stripe only has to separate rows; it does not have to be
		-- seen on its own.
		row.BackgroundTransparency = if index % 2 == 0 then 0.78 else 0.5
		row.BorderSizePixel = 0
		row.Visible = false
		row.Parent = list

		local who = Instance.new("TextLabel")
		who.Name = "Who"
		who.Size = UDim2.new(0.68, 0, 1, 0)
		who.Position = UDim2.new(0, 10, 0, 0)
		who.BackgroundTransparency = 1
		who.TextScaled = true
		who.TextXAlignment = Enum.TextXAlignment.Left
		Theme.title(who, 34, Theme.INK)
		who.Text = ""
		who.Parent = row

		local amount = Instance.new("TextLabel")
		amount.Name = "Amount"
		amount.Size = UDim2.new(0.3, -10, 1, 0)
		amount.Position = UDim2.new(0.7, 0, 0, 0)
		amount.BackgroundTransparency = 1
		amount.TextScaled = true
		amount.TextXAlignment = Enum.TextXAlignment.Right
		Theme.title(amount, 34, Theme.GOLD_INK)
		amount.Text = ""
		amount.Parent = row

		table.insert(rows, { row = row, who = who, amount = amount })
	end

	local empty = Instance.new("TextLabel")
	empty.Name = "Empty"
	empty.Size = UDim2.new(1, 0, 0, 40)
	empty.BackgroundTransparency = 1
	empty.TextScaled = true
	Theme.body(empty, 28, Theme.MUTED)
	-- Names the mechanic rather than reporting a blank, the same call the
	-- wanted poster makes -- and this board is empty at the start of every
	-- week, not just at the start of every server.
	empty.Text = "nobody yet this week"
	empty.LayoutOrder = 0
	empty.Parent = list

	surface.Parent = panel
	table.insert(boards, { empty = empty, rows = rows, title = title, panel = panel })
end

-- THE BOARD TURNS PAGES (Phase 5.5): Top Thieves and Top Defenders, on the
-- one board the street already has, because its geometry is measured and a
-- second board is not.
--
-- THERE WERE THREE PAGES AND THERE ARE TWO. The third ranked ACORNS EARNED
-- this season and went with the acorn currency -- along with the local
-- `Shared/SeasonBoard` overlay each client used to draw over it, which is the
-- reason the page attribute below is still published: nothing reads it for
-- the season any more, but the two surviving pages still name themselves on
-- it. Both of these are WEEKLY and neither has ever counted a currency.
local PAGES = { "thieves", "defenders" }
local pageClock = { index = 1, turnedAt = os.clock() }

local function refreshBoard()
	if #boards == 0 then
		return
	end

	-- Asks for fresh pages if the cached ones are stale, and paints whatever
	-- they currently hold either way. The fetches yield on a web call, so
	-- waiting for them here would stall the refresh loop that also drives the
	-- poster and the wanted chip.
	fetchWeekly()
	fetchDefend()

	if os.clock() - pageClock.turnedAt >= Config.BOARD_PAGE_SECONDS then
		pageClock.index = pageClock.index % #PAGES + 1
		pageClock.turnedAt = os.clock()
	end
	local page = PAGES[pageClock.index]

	local ranked, title, emptyText, amountOf
	if page == "thieves" then
		ranked, title, emptyText = weeklyTop, "TOP THIEVES  THIS WEEK", "nobody yet this week"
		amountOf = format
	else
		ranked, title, emptyText = defend.top, "TOP DEFENDERS  THIS WEEK", "no thieves stopped yet this week"
		amountOf = function(n: number) return ("%d stopped"):format(n) end
	end

	-- EVERY board, not the last one built. Ranking once and painting many is
	-- also why the list is fetched out here: two boards must never disagree
	-- about who is winning, and they cannot if they are reading one list.
	for _, ui in ipairs(boards) do
		ui.panel:SetAttribute(Config.BOARD_PAGE_ATTRIBUTE, page)
		ui.title.Text = title
		ui.empty.Text = emptyText
		ui.empty.Visible = #ranked == 0
		for index, entry in ipairs(ui.rows) do
			local ranking = ranked[index]
			entry.row.Visible = ranking ~= nil
			if ranking then
				entry.who.Text = ("%d.  %s"):format(index, ranking.name)
				entry.amount.Text = amountOf(ranking.amount)
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

-- How many stars this player is carrying right now.
--
-- FADED LAZILY RATHER THAN ON A TIMER. A run needs no loop of its own:
-- nothing in the game has to happen at the moment a star lapses, so the
-- honest implementation is to check the clock when somebody asks. That also
-- means a player who logs off mid-run leaves no timer behind to fire at a
-- Player that has gone -- the failure the wheelie bin's `CharacterAdded` hook
-- records from the other end. The fade is written back so the next ask sees
-- the same answer, with `at` advanced by the windows spent rather than reset.
local function starsOf(player: Player): number
	-- THE MOST WANTED PLAYER IS PINNED AT FIVE FULL STARS AND DOES NOT FADE
	-- (designer decision 2026-09-22), until `refreshMostWanted` hands the
	-- title to somebody else. The name on the poster is the biggest sheet in
	-- the server, and the street reads that name as the most dangerous thief
	-- on it -- a leader whose stars quietly drained while their poster stayed
	-- up would be two readouts telling two stories about one player.
	--
	-- A SERVER RULE, NOT A DRAWING RULE: it is written into the run here, so
	-- everything that reads stars -- the payout multiplier, the pursuit
	-- target, the alarm, the chip and the poster -- sees five without any of
	-- them knowing about the pin. What that costs, stated plainly: the leader
	-- is always over `huntedFrom` (the patrol comes for them on every pass)
	-- and always at `Config.getStarPayout(max)` (double pay). The stamp is
	-- refreshed on every read so the fade clock is genuinely HELD, and the
	-- hand-over in `refreshMostWanted` re-stamps it once more, so the old
	-- leader starts fading from the five they were reading rather than from
	-- wherever a stale clock would have put them.
	if mostWanted == player then
		-- THE CLOCK IS HELD AND THE COUNT IS KEPT. Only `at` is refreshed:
		-- the run underneath -- how many deliveries in a row this player has
		-- actually made -- goes on counting through `recordSteal`, because
		-- the spree trophy and the "Nx IN A ROW" line read the RUN through
		-- `SocialService.getRun` and a leader's first delivery is one
		-- robbery, not five. The hand-over in `refreshMostWanted` is what
		-- stamps the five the fade then starts from.
		local held = stars[player]
		if held then
			held.at = serverNow()
		end
		return Config.WANTED_STARS.max
	end
	local run = stars[player]
	if not run then
		return 0
	end
	local quiet = serverNow() - run.at
	local left = Config.starsAfterQuiet(run.count, quiet)
	if left <= 0 then
		stars[player] = nil
		return 0
	end
	if left < run.count then
		run.at += (run.count - left) * Config.WANTED_STARS.fade
		run.count = left
	end
	return left
end

-- What this player's rap sheet has to reach before the patrol will come
-- looking for them unprovoked. Seconds of their OWN income; see Config.POLICE.
--
-- SCALED BY THE STARS, WHICH ARE THE RISK HALF OF A RUN. A thief working fast
-- draws a records check on a smaller sheet than the same thief taking their
-- time -- so the reward for consecutive robberies is paid for in the one
-- system that already hunts people, rather than in a new hazard nobody has to
-- learn. See Config.WANTED_STARS.floorDropPerStar.
--
-- DENOMINATED IN THE WHOLE COLLECTION'S INCOME, NOT ONE PIG'S. It read
-- `getIncomeRate` for the life of the feature, which was a player's whole
-- income until a lawn started earning -- and then it was a seventh of it at
-- commons and a hundredth at the top tier, so a full lawn cleared its own
-- floor with a couple of laps' worth and the poster promised a patrol for a
-- pocketful. `collectionRateOf` is the same summation the tick pays.
-- THE PATROL'S FLOOR IS RETIRED (designer decision 2026-09-22). It was
-- seconds of the thief's own income that the sheet had to clear before the
-- leader was worth a car, scaled down by the stars. The stars carry the
-- whole consequence now: from `WANTED_STARS.huntedFrom` the patrol comes on
-- every pass, whoever leads the board, and the board itself is only a
-- ranking. One ladder, one rule, nothing to fold a second time.

local wantedCounted: { [Player]: boolean } = {}

local function refreshMostWanted()
	local best: Player? = nil
	local bestAmount = 0

	for _, player in ipairs(Players:GetPlayers()) do
		local record = heat[player] or 0
		if record > bestAmount then
			best = player
			bestAmount = record
		end
	end

	-- WHETHER THE PATROL COMES FOR THE WINNER is asked AFTER the board has
	-- moved rather than here, because `starsOf` pins whoever `mostWanted`
	-- names -- read before the hand-over it would report the new leader's
	-- real run and the old leader's pin, both of them about to be wrong.
	-- With the pin it is always true of a leader; the expression is kept
	-- rather than replaced by `best ~= nil` so that a pin that is ever
	-- relaxed does not leave a toast promising a patrol nobody sends.
	local function huntedNow(): boolean
		return best ~= nil and starsOf(best) >= Config.WANTED_STARS.huntedFrom
	end

	-- Names the consequence, not just the status. Being told you are Most
	-- Wanted and then chased by an officer nobody warned you about is the
	-- patrol arriving as bad luck, which is the one thing this feature is not
	-- allowed to be -- bad luck is not something a nine year old can get
	-- better at.
	--
	-- AND IT IS TWO LINES NOW, because the board can name somebody the patrol
	-- is not coming for. Promising a visit that will not happen is the same
	-- fault as arriving without warning, from the other end.
	local function announce(player: Player, patrol: boolean)
		Remotes.get("Notify"):FireClient(player,
			if patrol
				then "You are MOST WANTED. The next patrol comes for you."
				else ("You are MOST WANTED. %d stars in a row and the patrol comes for you."):format(
					Config.WANTED_STARS.huntedFrom),
			"warn")
	end

	if best == mostWanted then
		local hunted = huntedNow()
		if mostWanted then
			setHat(mostWanted, true) -- re-apply after a respawn
			-- The board did not change hands, but the sheet grew past the floor
			-- while it sat there. Announce the patrol half NOW or it never gets
			-- announced at all -- and that is the COMMON shape, since a thief
			-- reaches the top of the board well before they reach the floor.
			if hunted and not wantedHunted then
				announce(mostWanted, true)
			end
		end
		wantedHunted = hunted
		return
	end

	if mostWanted then
		setHat(mostWanted, false)
		-- THE OLD LEADER FADES FROM FIVE (designer decision 2026-09-22). Five
		-- is what they were reading while they held the board, so it is the
		-- only honest place to start draining from; a run that snapped back
		-- to whatever it was before the pin would be a row of stars vanishing
		-- for no reason a player can see. Stamped NOW, so the first star
		-- starts full: `starsOf` last refreshed it up to a refresh tick ago.
		--
		-- An arrest is the one hand-over that must NOT leave a fading five,
		-- and it does not: PoliceService calls `clearHeat` (which moves the
		-- board here) BEFORE `clearStars` (which wipes what this stamped).
		-- The wanted suite asserts that order.
		stars[mostWanted] = { count = Config.WANTED_STARS.max, at = serverNow() }
	end
	mostWanted = best
	local hunted = huntedNow()
	wantedHunted = hunted

	if best then
		setHat(best, true)
		announce(best, hunted)
		-- The Wanted Poster trophy (Phase 5.2): one more time on top -- at
		-- most once a session, or two friends trading the lead would farm it.
		if not wantedCounted[best] then
			wantedCounted[best] = true
			-- THE RAP SHEET ITSELF, not a bounty derived from it. Bail is a
			-- share of the thief's own till now, so there is no per-player
			-- bounty left to record -- and the sheet is the better trophy
			-- anyway: what you were wanted FOR rather than what somebody
			-- would have charged you. `heat` lives here and dies with the
			-- session, which is why it is handed over rather than derived
			-- later by a poster hanging in a house.
			--
			-- `bestBounty` KEEPS ITS FIELD NAME. Renaming a persisted field to
			-- fix a wording is a schema migration for a wording problem --
			-- the call `data.vault` already made while the HUD said PIGGY
			-- BANK. It only ever rises, so saves carrying an old 3x figure
			-- keep a generous record rather than a wrong one.
			TrophyService.recordWanted(best, math.floor(heat[best] or 0))
		end
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

	-- The same printed sheet as the leaderboard, at this board's own scale:
	-- 20px of inset at 25 pixels per stud is the 0.8 studs of visible timber
	-- that 16px buys over there at 20. See the note on that one.
	local backdrop = Instance.new("Frame")
	backdrop.Name = "Sheet"
	backdrop.Size = UDim2.new(1, -40, 1, -40)
	backdrop.Position = UDim2.new(0, 20, 0, 20)
	backdrop.Parent = surface
	Theme.card(backdrop, 12)
	Theme.outline(backdrop, 5)

	-- THE WHOLE CARD IS SOLVED AGAINST THE SHEET RATHER THAN STACKED DOWN IT,
	-- because stacking is what walked it off the bottom.
	--
	-- Reported as the sign cutting off the words, and measured on the live
	-- board it is exactly that: the paper runs to canvas y 530 and the bounty
	-- line ran 492 to 546 -- sixteen pixels of it printed on the bare timber
	-- below the sheet, with the canvas itself ending four pixels later. The
	-- card was over-full as well: 430 pixels of content in a frame declared
	-- 400 tall, so the last row was 30 past its own parent before it ever
	-- reached the paper.
	--
	-- Nothing clipped it, which is why it survived: `Theme.card` sets no
	-- `ClipsDescendants`, so the row simply drew outside everything it
	-- belonged to and only the board's own edge stopped it.
	--
	-- So the four blocks are laid out from one budget. Sheet 510 tall, less
	-- the title band and a 12px foot, is 408 for the card; the three text
	-- rows and their gaps take 172 of it and the photograph takes what is
	-- left. Change any row height and change PHOTO to match, or this walks
	-- off the paper again.
	local TITLE_H = 76
	local CARD_TOP = 90
	local CARD_H = 408          -- 510 - CARD_TOP - 12 of foot
	local BAR_H = 34
	-- THE PHOTOGRAPH PAYS FOR THE BAR, which is what the note above demands:
	-- every row here comes out of one budget, so a new row is 40 pixels off
	-- the picture rather than 40 pixels further down the paper. 236 -> 196.
	local PHOTO = 196           -- CARD_H - (10 + 58 + 4 + 40 + 6 + BAR_H + 6 + 54)
	local WHO_Y = PHOTO + 10
	local STOLEN_Y = WHO_Y + 58 + 4
	local FLOOR_Y = STOLEN_Y + 40 + 6
	local BOUNTY_Y = FLOOR_Y + BAR_H + 6

	local title = Instance.new("TextLabel")
	-- 76px / 25 = 3.04 studs, near enough the leaderboard's own heading
	-- height, and the width is what binds this string anyway -- measured,
	-- "MOST WANTED" renders 330 wide by 51 tall in a box 330 across, so the
	-- four pixels of height come off nothing.
	title.Size = UDim2.new(1, -30, 0, TITLE_H)
	title.Position = UDim2.new(0, 15, 0, 8)
	title.BackgroundTransparency = 1
	title.TextScaled = true
	-- RED, WHERE THE LEADERBOARD'S HEADING IS GOLD, AND THAT PAIR IS THE
	-- WHOLE DIFFERENCE BETWEEN THE TWO BOARDS AT FORTY STUDS. Both used to be
	-- the same gold, so the only thing separating them from down the street
	-- was portrait against landscape. Gold means money and this board is not
	-- about money -- it is the one that says somebody is coming for you.
	-- It is the same red the alarm toast and the bounty use.
	Theme.title(title, TITLE_H, Theme.STOP_INK)
	title.Text = "MOST WANTED"
	title.Parent = backdrop

	local card = Instance.new("Frame")
	card.Name = "Suspect"
	card.Size = UDim2.new(1, -30, 0, CARD_H)
	card.Position = UDim2.new(0, 15, 0, CARD_TOP)
	card.BackgroundTransparency = 1
	card.Visible = false
	card.Parent = backdrop

	local photo = Instance.new("ImageLabel")
	photo.Name = "Photo"
	photo.Size = UDim2.new(0, PHOTO, 0, PHOTO)
	photo.Position = UDim2.new(0.5, -PHOTO / 2, 0, 0)
	-- A WELL IS A HOLE, so it stays dark while everything round it went to
	-- paper -- the same call the shop's icon wells and the coin chip make.
	-- What sits in it is a photograph, and a photograph wants something to be
	-- against.
	photo.BackgroundColor3 = Theme.SLAB_DEEP
	photo.BorderSizePixel = 0
	photo.Parent = card

	-- INK, NOT GOLD. A gold frame was right on a dark board and is the wrong
	-- half of the contrast on a light one; a printed photo on a poster has a
	-- dark border round it, and that is also the line that stops a dark well
	-- from bleeding into the cream behind it.
	local frame = Instance.new("UIStroke")
	frame.Thickness = 4
	frame.Color = Theme.INK
	frame.Parent = photo

	local name = Instance.new("TextLabel")
	-- "Who", matching the leaderboard rows, and NOT "Name": a child called Name
	-- is shadowed by the Instance.Name property on every dotted lookup, so
	-- board.Suspect.Name reads back the string "Suspect" rather than the label.
	-- The service itself holds a direct reference and never noticed; anything
	-- inspecting the board from outside would have to know to use FindFirstChild.
	name.Name = "Who"
	-- INSET TEN A SIDE, and that is a real fix rather than tidiness. Measured
	-- with a real suspect on the board, "EATYOURBEANSBOYS" rendered 320 wide
	-- in a 330-wide box -- fitting, and touching both edges, which is the
	-- state this project already records as reporting `TextFits` true while
	-- sitting exactly on the frame edge. `TextScaled` keeps it legible; the
	-- margin is what stops the glyphs meeting the paper's edge.
	name.Size = UDim2.new(1, -20, 0, 58)
	name.Position = UDim2.new(0, 10, 0, WHO_Y)
	name.BackgroundTransparency = 1
	name.TextScaled = true
	Theme.title(name, 58, Theme.INK)
	name.Text = ""
	name.Parent = card

	local stolen = Instance.new("TextLabel")
	stolen.Name = "Stolen"
	stolen.Size = UDim2.new(1, -20, 0, 40)
	stolen.Position = UDim2.new(0, 10, 0, STOLEN_Y)
	stolen.BackgroundTransparency = 1
	stolen.TextScaled = true
	-- Secondary type on a light ground is MUTED, which is faded INK. The old
	-- (190, 180, 196) was faded PAPER, solved against a dark board -- exactly
	-- the mistake the shop made in nine places when its cards went light: a
	-- mid-tone reads as faded on black and as washed out on cream.
	Theme.body(stolen, 40, Theme.MUTED)
	stolen.Text = ""
	stolen.Parent = card

	-- ---- THE MIDDLE OF THE LADDER -------------------------------------
	--
	-- THE RAP SHEET IS AN ARC AND ONLY ITS TWO ENDS WERE EVER DRAWN.
	--
	-- Take more, lead the board, cross your own floor, draw a patrol. A
	-- player could see the first (a figure on the HUD chip) and the last (the
	-- chip's ring going red), and nothing in between -- so the escalation
	-- read as a number and then, abruptly, a consequence. Nothing anywhere
	-- answered *how close am I*.
	--
	-- IT GOES ON THE POSTER RATHER THAN IN THE CHIP, AND THAT RESOLVES THE
	-- OBJECTION THAT KEPT IT OUT OF THE PAYLOAD. `wantedPayload`'s own
	-- comment refuses to send a floor because "a floor is only ever asked
	-- about the leader, so drawing a bar toward one for anybody else would
	-- promise a consequence that cannot happen" -- which is exactly right
	-- for a per-player chip and stops being a problem on a board about ONE
	-- PERSON. `getPursuitTarget` returns nobody unless they are the most
	-- wanted, so the leader's floor is the only floor that decides anything,
	-- and it is a public fact about the street rather than private state.
	--
	-- IT IS ALSO THE HONEST SURFACE FOR IT. A 176x34 chip already carries a
	-- badge, a caption, a figure and four spree pips and has nowhere to put
	-- a second player's name; this board exists to say who is wanted and has
	-- room. And it makes the ladder readable FROM THE STREET, which is where
	-- this project puts a tell whenever it can.
	--
	-- WHAT IT BUYS EVERYONE ELSE IS THE HALF NOBODY ASKED FOR. A thief who
	-- is not leading can now compare: their own figure is on their chip and
	-- the leader's is on the paper. And any bystander can see a patrol
	-- building before it happens, which is the same published-in-advance
	-- rule the fifteen seconds of siren already follow -- bad luck is not
	-- something a nine-year-old can get better at.
	local floorTrack = Instance.new("Frame")
	floorTrack.Name = "Floor"
	floorTrack.Size = UDim2.new(1, -20, 0, BAR_H)
	floorTrack.Position = UDim2.new(0, 10, 0, FLOOR_Y)
	-- A GROOVE ONE STEP UNDER THE PAPER, which is the language the upgrade
	-- pips and the event countdown's own track already speak. A well is a
	-- hole for an object; a groove is a track for a fill.
	floorTrack.BackgroundColor3 = Theme.SAND_DEEP
	floorTrack.BorderSizePixel = 0
	floorTrack.ClipsDescendants = true
	floorTrack.Parent = card
	Theme.corner(floorTrack, BAR_H // 2)
	Theme.outline(floorTrack, 3)

	local floorFill = Instance.new("Frame")
	floorFill.Name = "Fill"
	floorFill.Size = UDim2.new(0, 0, 1, 0)
	floorFill.BackgroundColor3 = Theme.WARN
	floorFill.BorderSizePixel = 0
	floorFill.Parent = floorTrack
	Theme.corner(floorFill, BAR_H // 2)

	-- THE WORDS SIT OVER THE FILL RATHER THAN BESIDE IT, because the bar is
	-- already the full width of the card and a caption next to it would have
	-- to come out of the bar. Ink on both states: `WARN` and `STOP` are both
	-- bright by design -- every category hue in this game has to carry ink at
	-- 4.5 to be a tab at all -- and the track behind the unfilled part is
	-- sand, which carries ink too. So one text colour reads on all three
	-- grounds and none of it needs a stroke.
	local floorLabel = Instance.new("TextLabel")
	floorLabel.Name = "Says"
	floorLabel.Size = UDim2.new(1, -16, 1, -8)
	floorLabel.Position = UDim2.new(0, 8, 0, 4)
	floorLabel.BackgroundTransparency = 1
	floorLabel.TextScaled = true
	Theme.body(floorLabel, BAR_H - 8, Theme.INK)
	floorLabel.Text = ""
	floorLabel.ZIndex = 2
	floorLabel.Parent = floorTrack
	-- What a catch would actually cost them, spelled out. The patrol is
	-- published on principle -- the siren runs fifteen seconds ahead of the car
	-- and the HUD counts both clocks -- and a bounty nobody could read would be
	-- the one part of it that still arrived as a surprise.
	local bounty = Instance.new("TextLabel")
	bounty.Name = "Bounty"
	-- Runs to the foot of the card, and now actually does: this used to end
	-- 30 pixels past it. It keeps the full 54 because it is the loud line --
	-- the photograph gave up the height instead.
	bounty.Size = UDim2.new(1, -20, 0, 54)
	bounty.Position = UDim2.new(0, 10, 0, BOUNTY_Y)
	bounty.BackgroundTransparency = 1
	bounty.TextScaled = true
	Theme.title(bounty, 54, Theme.STOP_INK)
	bounty.Text = ""
	bounty.Parent = card

	-- Teaches the mechanic rather than reporting a blank, which is the state
	-- this board is in for the first minutes of every server.
	local empty = Instance.new("TextLabel")
	empty.Name = "Empty"
	empty.Size = UDim2.new(1, -30, 0, 150)
	empty.Position = UDim2.new(0, 15, 0.38, 0)
	empty.BackgroundTransparency = 1
	empty.TextScaled = true
	Theme.body(empty, 30, Theme.MUTED)
	empty.Text = "no suspects\n\nrob a neighbour\nto get on this board"
	empty.Parent = backdrop

	surface.Parent = panel

	table.insert(wantedBoards, {
		card = card, photo = photo, name = name,
		stolen = stolen, bounty = bounty, empty = empty,
		floorFill = floorFill, floorLabel = floorLabel,
	})
end

local function refreshWantedBoard()
	local suspect = mostWanted

	-- Computed ONCE and painted onto every poster. Two boards must never
	-- disagree about who is wanted, and they cannot if they are reading one
	-- answer rather than each working it out.
	local photo, name, stolen, bounty = "", "", "", ""
	-- The ladder's middle rung, computed once with everything else and painted
	-- onto every poster: two boards must never disagree about how close the
	-- patrol is any more than they may disagree about who is wanted.
	local progress, says, hot = 0, "", false
	if suspect then
		-- rbxthumb, never GetUserThumbnailAsync: the content URL resolves
		-- itself and never yields, so a board refresh cannot be held up by a
		-- web call. Same reason the arrest scene's mugshot uses it.
		photo = ("rbxthumb://type=AvatarHeadShot&id=%d&w=420&h=420"):format(suspect.UserId)
		name = suspect.DisplayName:upper()
		local record = heat[suspect] or 0
		stolen = ("STOLEN  %s"):format(format(record))
		-- THE RULE RATHER THAN A FIGURE, because bail stopped being a
		-- function of the rap sheet: it is a share of the THIEF'S OWN till
		-- now, which this board cannot know and should not read a save to
		-- find out. What the poster owes a reader is what being caught
		-- COSTS -- `CLAUDE.md`'s rule that the patrol is published on
		-- principle -- and a flat share says that better than a number,
		-- because it is true of every reader rather than only this suspect.
		--
		-- MEASURED AT 42px AGAINST THE OLD 54. This row is TextScaled and
		-- is the loud line on the card -- the photograph gave up height for
		-- it -- so a longer string is paid for in size: `BOUNTY  999.9M`
		-- renders at 54 and this at 42. Taken deliberately, because the
		-- version that keeps 54 is `BAIL  20%` and a share of nothing
		-- stated is worse than a smaller clear line.
		bounty = ("BAIL  %d%% OF THE PIG"):format(Config.bailPercent())

		-- THE BAR IS THE STAR LADDER, the same one the HUD chip draws, so the
		-- poster and the officer who turns up cannot disagree: a patrol comes
		-- at `huntedFrom` stars and nothing else decides it.
		local run = starsOf(suspect)
		local need = Config.WANTED_STARS.huntedFrom
		progress = math.clamp(run / need, 0, 1)
		hot = run >= need
		says = if hot
			then "PATROL COMING"
			else ("%d STAR%s TO A PATROL"):format(need - run, if need - run == 1 then "" else "S")
	end

	for _, ui in ipairs(wantedBoards) do
		ui.card.Visible = suspect ~= nil
		ui.empty.Visible = suspect == nil
		if suspect then
			ui.photo.Image = photo
			ui.name.Text = name
			ui.stolen.Text = stolen
			ui.bounty.Text = bounty

			-- AMBER CLIMBING, RED ARRIVED, which is the SAME two-state escalation
			-- the HUD chip's ring already draws -- gold once the poster has your
			-- name on it, red once the sheet clears the floor. One ladder, two
			-- surfaces, and a player who learns it on the chip reads it on the
			-- board without being taught twice.
			ui.floorFill.Size = UDim2.new(progress, 0, 1, 0)
			ui.floorFill.BackgroundColor3 = if hot then Theme.STOP else Theme.WARN
			ui.floorLabel.Text = says
		end
	end
end

-- ============================================================
-- THE RAP SHEET
-- ============================================================

-- THE SESSION ARC, PUSHED. Everything below already existed and none of it
-- had ever reached a screen.
--
-- The rap sheet, Most Wanted and the pursuit floor model an arc across a
-- session -- take more, lead the board, draw a patrol -- and the only places
-- any of it surfaced were a poster somewhere on the street and a handful of
-- toasts that are gone in six seconds. So the one system in this game that
-- gives a session a SHAPE was invisible in the moment it was happening, which
-- is the same fault the standing event countdown was built to fix from the
-- other end: that too was a display nobody had written rather than a mechanism
-- nobody had built.
--
-- IT IS PER PLAYER BECAUSE HALF THE PAYLOAD IS ABOUT THE RECIPIENT. A floor is
-- seconds of the reader's OWN income, so two thieves standing together have
-- different ones and there is no street-wide answer to broadcast.
local function wantedPayload(player: Player)
	local leader = SocialService.getMostWanted()
	-- THREE FIELDS, AND NOTHING THE CHIP CANNOT HONESTLY DRAW.
	--
	-- The obvious payload also carries the pursuit FLOOR, the leader's NAME
	-- and their sheet -- and none of the three has a reader. A floor is only
	-- ever asked about the leader, so drawing a bar toward one for anybody
	-- else would promise a consequence that cannot happen; and a 176x34 chip
	-- that already holds a badge, a caption and a figure has nowhere to put a
	-- second player's name. Pushing them anyway is how a payload rots: a field
	-- nobody reads is a field nobody notices going wrong.
	local run = starsOf(player)
	local stamp = stars[player]
	return {
		sheet = heat[player] or 0,
		isLeader = leader == player,
		-- THE NEXT PATROL COMES FOR THIS PLAYER, which is true two ways now:
		-- they lead the board and their sheet clears the floor, or they are
		-- carrying `WANTED_STARS.huntedFrom` stars whoever leads. One flag,
		-- because the chip has one ring and a player has one question.
		hunted = run >= Config.WANTED_STARS.huntedFrom,
		stars = run,
		starsMax = Config.WANTED_STARS.max,
		-- THE STAMP THE DRAIN IS DRAWN FROM: server time at which `stars`
		-- became true. The chip empties the newest star across
		-- `WANTED_STARS.fade` from it and needs nothing per frame; with no
		-- run there is nothing to drain and now is as good a stamp as any.
		starsAt = if stamp then stamp.at else serverNow(),
		-- Held full, not draining: the Most Wanted pin, decided above in
		-- `starsOf` and reported here so the chip draws no motion.
		pinned = leader == player,
	}
end

-- Pushes one player, or everybody when given nobody.
function SocialService.pushWanted(player: Player?)
	if player then
		if player.Parent then
			Remotes.get("WantedState"):FireClient(player, wantedPayload(player))
		end
		return
	end
	for _, other in ipairs(Players:GetPlayers()) do
		Remotes.get("WantedState"):FireClient(other, wantedPayload(other))
	end
end

-- One successful delivery. Called by HeistService and by nothing else: coins
-- that arrive any other way -- income, banking, a daily, a rebirth -- were not
-- taken off anybody.
-- WHAT A DELIVERY IS WORTH RIGHT NOW, asked BEFORE `recordSteal` bumps it.
--
-- The order is the whole of what makes "consecutive" mean anything: the
-- delivery that STARTS a run pays 1.0 and the one after it pays more, which is
-- what a player would expect from a streak. Bumping first would pay a bonus
-- for the first robbery of a session and there would be no streak to speak of.
function SocialService.getStarMultiplier(player: Player): number
	return Config.getStarPayout(starsOf(player))
end

-- How many stars, for anything that wants to show or record it.
--
-- READS THE PIN. The Most Wanted player answers `max` here on every call,
-- which is right for the payout and the chip and is worth knowing for a
-- caller RECORDING a run: HeistService hands this to `TrophyService.recordSpree`
-- after each delivery, so a leader's first delivery as leader records a
-- five-star spree. `isPinned` is beside it for a caller that wants to know.
function SocialService.getStars(player: Player): number
	return starsOf(player)
end

-- THE RUN UNDERNEATH THE PIN: deliveries in a row, as counted, with the
-- Most Wanted pin NOT applied. `getStars` is what the game pays, hunts and
-- draws by; this is what a run IS, and it is the number a record of the
-- best run ever should be measured on -- a leader pinned at five on their
-- first delivery has made one robbery in a row, not five.
function SocialService.getRun(player: Player): number
	if mostWanted == player then
		local held = stars[player]
		return if held then math.min(held.count, Config.WANTED_STARS.max) else 0
	end
	return starsOf(player)
end

-- Is this player's row held full by the Most Wanted pin right now?
function SocialService.isPinned(player: Player): boolean
	return mostWanted == player
end

-- CAUGHT ENDS THE RUN, and that is the point of a run having an end.
--
-- Separate from `clearHeat`, which wipes the rap SHEET and fires only on a
-- most-wanted arrest -- an ordinary bust deliberately leaves a record intact
-- because that is what the thief was caught for. Stars are momentum rather
-- than a record, and any arrest breaks momentum, so this is called on both.
function SocialService.clearStars(player: Player)
	if stars[player] then
		stars[player] = nil
		-- A LEADER STAYS PINNED THROUGH THIS. `starsOf` re-pins whoever the
		-- board names on the next read, so an ORDINARY bust of the Most
		-- Wanted player -- caught mid-robbery, sheet kept, board kept --
		-- leaves them at five. That is the pin working: they are still the
		-- biggest thief on the street. A MOST-WANTED arrest wipes the sheet
		-- first (`clearHeat`), which hands the board on before this runs.
		SocialService.pushWanted(player)
	end
end

-- What reaching `WANTED_STARS.max` does to the street: Main registers
-- `PoliceService.call`, so a five-star thief brings the patrol out early.
-- A call that cannot be taken -- one already out, or the lockout -- is
-- refused inside the callee, which is the right place for it: the stars
-- name the consequence and the patrol owns its own clock.
function SocialService.registerStarAlarm(fn: () -> ())
	starAlarm = fn
end

-- ONE MORE ON THE SHEET.
--
-- `amount` IS COINS-EQUIVALENT VALUE TAKEN FROM ANOTHER PLAYER, which is a
-- change of DEFINITION rather than of signature (designer call 2026-09-21).
-- It used to mean coins, because coins were the only thing a robbery took.
-- Most Wanted ranks on the value of PIGGIES stolen now, and a piggy's value
-- is `Config.piggyWorth` -- the one coin figure this game already gives an
-- animal, so the board and the sell prompt cannot drift.
--
-- THE COIN PATH STILL FEEDS IT, AND THAT IS THE SEQUENCING RATHER THAN A
-- LEFTOVER. Cash robbery is going; the snatch that replaces it does not
-- exist yet. Switching the source before the new one lands would leave the
-- poster, the weekly board and the patrol's target counting zero for
-- everybody until it did -- which is exactly the shape that killed the
-- season ladder, and the one failure this project refuses above all others.
-- Both sources are the same unit, so the coin caller is deleted later with
-- nothing else here to change.
--
-- IT IS DELIBERATELY UNIT-AGNOSTIC INSIDE. Nothing below reads what the
-- number means, so the transition costs this function no branch at all.
function SocialService.recordSteal(thief: Player, amount: number)
	heat[thief] = (heat[thief] or 0) + amount

	-- ANOTHER STAR. Read the current count through the accessor rather than
	-- the raw table, so stars that faded while the thief was carrying are
	-- dropped here rather than silently kept.
	-- TWO READS, BECAUSE THE PIN SPLITS THEM: `before` is what the game
	-- was showing (five for the Most Wanted leader, so the two announcements
	-- below never repeat for them), and the RUN underneath is what this
	-- delivery extends -- read through `getRun` so a pinned leader's count
	-- keeps counting deliveries rather than being reset to five on each.
	local before = starsOf(thief)
	local run = SocialService.getRun(thief)
	local count = math.min(run + 1, Config.WANTED_STARS.max)
	stars[thief] = { count = count, at = serverNow() }
	if before < Config.WANTED_STARS.huntedFrom and count >= Config.WANTED_STARS.huntedFrom then
		-- THE THRESHOLD IS SAID THE MOMENT IT IS CROSSED. The chip's ring goes
		-- red on the same push, and a consequence a player is not told about
		-- is a patrol arriving without warning.
		Remotes.get("Notify"):FireClient(thief,
			("%d stars. The patrol comes for you on every pass until they fade."):format(count),
			"police")
	end
	if before < Config.WANTED_STARS.max and count >= Config.WANTED_STARS.max and starAlarm then
		-- FIVE STARS CALLS THE PATROL. Once per reaching the top: a thief who
		-- stays at five keeps robbing under a patrol every pass already. The
		-- `before` half is what makes that true of the PINNED leader too --
		-- they read five before every delivery, so neither this nor the
		-- `huntedFrom` toast above fires for them on every haul. Taking the
		-- board does not call the patrol early on its own; being pinned
		-- makes the leader the pursuit target on every scheduled pass.
		task.spawn(starAlarm)
	end

	-- The thief's OWN row, immediately, because a delivery is the moment the
	-- number changes and a readout that waited five seconds for it would read
	-- as broken. The leader fields can be up to one refresh stale here and
	-- that is deliberate: recomputing the board per delivery is a DataService
	-- read per player, which is exactly what `SocialService.refresh` exists to
	-- keep the dev console from doing on a tick.
	SocialService.pushWanted(thief)
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
	-- AND THE BOARD MOVES NOW, NOT ON ITS NEXT TICK. The Most Wanted player
	-- is pinned at five stars for as long as `mostWanted` names them, so a
	-- wiped sheet that left the board standing for up to five more seconds
	-- would re-pin the stars `clearStars` is about to wipe -- and an arrest
	-- that leaves the arrested player at five stars is the one outcome this
	-- rule may never produce. The hand-over inside stamps them at five for
	-- the fade; `clearStars`, called next by PoliceService, takes that away.
	refreshMostWanted()
	SocialService.pushWanted(player)
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
	heat[player] = math.floor(top * 1.25 + 1000)
	-- And the stars that actually bring the patrol, or the command would put
	-- a name on the poster and no officer on the street.
	stars[player] = { count = Config.WANTED_STARS.huntedFrom, at = serverNow() }
	SocialService.refresh()
	return heat[player]
end

-- THE NAME ON THE BOARD: the biggest sheet in the server, and nothing else.
-- Whoever has stolen the most is on the poster, full stop.
--
-- NOT THE PURSUIT TARGET -- use `getPursuitTarget` for that. Two questions,
-- two functions, the same split PassService draws between `unlocked` and
-- `owns` and for the same reason: mixing them up here either empties the
-- poster or sends an officer after a child who lifted one small pile.
function SocialService.getMostWanted(): (Player?, number)
	local suspect = mostWanted
	if not suspect then
		return nil, 0
	end
	return suspect, heat[suspect] or 0
end

-- WHO THE PATROL MAY COME FOR: the name on the board, but only once their
-- sheet clears their own income floor. Nil the rest of the time, and nil is an
-- ordinary answer rather than an error -- a quiet server has a poster with a
-- name on it and nobody worth a records check.
--
-- The floor is evaluated on the refresh tick rather than here, so this can
-- never disagree with the hat the whole street can see.
function SocialService.getPursuitTarget(): (Player?, number)
	-- FROM `WANTED_STARS.huntedFrom` STARS THE PATROL COMES ON EVERY PASS,
	-- AND NOTHING ELSE SENDS IT (designer decision 2026-09-22: the floor is
	-- retired, the stars are the whole rule). A run of three deliveries is a
	-- thief the street can see, and the stars are the reward AND the threat.
	-- The most-starred player is taken, the bigger sheet breaking a tie, and
	-- the bail is still measured against the sheet -- what they actually
	-- took -- never against the stars. Leading the board on its own sends
	-- nobody: the poster is a ranking, not a warrant.
	local best: Player? = nil
	local bestStars, bestSheet = 0, -1
	for _, player in ipairs(Players:GetPlayers()) do
		local stars = starsOf(player)
		if stars >= Config.WANTED_STARS.huntedFrom then
			local sheet = heat[player] or 0
			if stars > bestStars or (stars == bestStars and sheet > bestSheet) then
				best, bestStars, bestSheet = player, stars, sheet
			end
		end
	end
	if best then
		return best, heat[best] or 0
	end
	return nil, 0
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
	Remotes.get("RevengeMarker"):FireClient(victim, plot.model, thief.DisplayName, Config.REVENGE.window)
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
		-- BEFORE the state below is dropped, and before DataService gets to
		-- release the save: a player's last robbery of the session is the one
		-- most worth having on the board, and it is the one a publish that
		-- only ran on a tick would miss.
		publishWeekly(player)
		publishDefend(player)
		wantedCounted[player] = nil
		friendBonus[player] = nil
		-- The rap sheet dies with the session it belongs to. Left behind, it
		-- would also hold a Player reference open for the life of the server.
		heat[player] = nil
		stars[player] = nil
		if mostWanted == player then
			mostWanted = nil
			wantedHunted = false
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

			-- PUBLISHED ON ITS OWN SLOWER CLOCK, not on this five-second one.
			-- A write per player every five seconds is 72 a minute at six
			-- players against a budget of 60 + 10 each, so it would be over it
			-- on its own -- and the number only moves when somebody delivers.
			if os.clock() - lastWeeklyPublish >= Config.WEEKLY_HEIST.refresh then
				lastWeeklyPublish = os.clock()
				for _, player in ipairs(Players:GetPlayers()) do
					task.spawn(publishWeekly, player)
					task.spawn(publishDefend, player)
				end
			end
			-- In this order: the poster reads whatever refreshMostWanted just
			-- decided, so it and the floating label can never disagree about
			-- who is wanted.
			refreshMostWanted()
			refreshWantedBoard()

			-- AFTER the refresh, so the chip on a player's screen and the
			-- poster on the street cannot disagree about who is wanted --
			-- the same ordering argument the two lines above already make.
			--
			-- On the tick rather than on change, because the FLOOR moves with
			-- income and rebirths and nothing about buying an upgrade would
			-- otherwise tell this service to look again. Eight FireClients
			-- every LEADERBOARD_REFRESH is cheaper than a hook on every
			-- income change, and it cannot go stale in a way nobody notices.
			SocialService.pushWanted()
		end
	end)
end

return SocialService
