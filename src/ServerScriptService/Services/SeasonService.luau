--!strict
--[[
	SeasonService

	Phase 5 (MASTER-PLAN 11-12): the season, and the two sign lines it feeds.

	  * THE SEASON (5.3). Rank is acorns EARNED this season -- the own-tree
	    harvest deposited and the pig-crack acorn -- counted only in a real
	    season week (the fifth week of every index is rest). Ten tiers
	    (`Config.SEASON.tiers`); each reward is granted the first time its
	    tier is crossed and never again, recorded in `season.granted`.
	  * THE ROLLOVER IS LAZY. A save carrying an older index is rolled the
	    first time anything reads it, the `WEEKLY_HEIST` shape: no job at the
	    boundary, and last season's store page stays behind it.
	  * THE NEMESIS LEDGER (5.1): who has robbed this player most this
	    season, twenty rows, shown on the plot sign.
	  * THE SEASON BOARD (5.5): an OrderedDataStore page per season, cached a
	    minute, and each player is pushed the rows AROUND THEM rather than
	    the top of the list.

	What it does not do: mint acorns. `earn` is told about acorns another
	service already banked; it never adds any.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local SetService = require(script.Parent.SetService)
local TrophyService = require(script.Parent.TrophyService)

local SeasonService = {}

local WEEK = 7 * 86400

-- A dev-only clock shift (admin `seasonshift`), so a season can be tested in
-- a rest week. Server-local and never saved.
local shiftSeconds = 0

local function now(): number
	return os.time() + shiftSeconds
end

function SeasonService.now(): number
	return now()
end

function SeasonService.shiftWeeks(weeks: number)
	shiftSeconds = math.floor(weeks) * WEEK
end

local function notify(player: Player, message: string, kind: string)
	Remotes.get("Notify"):FireClient(player, message, kind)
end

local function currentIndex(): number
	return Config.seasonIndex(now())
end

-- ============================================================
-- STATE
-- ============================================================

-- The save's season table for the CURRENT index, rolling it if it is stale.
-- The best tier is kept live, so a rollover only has to forget.
function SeasonService.state(data: any): any
	local season = data.season
	if type(season) ~= "table" then
		season = { index = 0, earned = 0, tier = 0, best = 0, granted = {} }
		data.season = season
	end
	if type(season.granted) ~= "table" then
		season.granted = {}
	end
	local index = currentIndex()
	if season.index ~= index then
		season.best = math.max(tonumber(season.best) or 0, tonumber(season.tier) or 0)
		season.index = index
		season.earned = 0
		season.tier = 0
		season.granted = {}
	end
	return season
end

local function nemesisState(data: any): any
	local nem = data.nemesis
	if type(nem) ~= "table" then
		nem = { index = 0, rows = {} }
		data.nemesis = nem
	end
	if type(nem.rows) ~= "table" then
		nem.rows = {}
	end
	local index = currentIndex()
	if nem.index ~= index then
		nem.index = index
		nem.rows = {}
	end
	return nem
end

-- The top counterparty, or nil.
function SeasonService.nemesisOf(data: any): (string?, number)
	local nem = nemesisState(data)
	local bestName, bestCount = nil, 0
	for _, row in pairs(nem.rows) do
		if row.count > bestCount then
			bestName, bestCount = row.name, row.count
		end
	end
	return bestName, bestCount
end

-- ============================================================
-- THE SIGN AND THE PUSH
-- ============================================================

function SeasonService.refreshSign(player: Player)
	local data = DataService.get(player)
	local plot = PlotService.getPlot(player)
	if not data or not plot then
		return
	end
	local season = SeasonService.state(data)
	local number = Config.seasonNumber(season.index)
	PlotService.setSeasonChip(plot, Config.seasonChipText(number, season.tier),
		Config.seasonChipColour(season.tier))
	local name, count = SeasonService.nemesisOf(data)
	PlotService.setNemesis(plot, name, count)
end

-- The season board, cached. `ranked` is every entry fetched, in order.
local board = {
	index = -1,
	ranked = {} :: { { id: number, amount: number } },
	fetchedAt = -math.huge,
	fetching = false,
	names = {} :: { [number]: string },
}

local function nameOf(id: number): string
	local cached = board.names[id]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(id)
	local name = player and player.DisplayName
	if not name then
		local ok, resolved = pcall(function()
			return Players:GetNameFromUserIdAsync(id)
		end)
		name = if ok then resolved else ("player %d"):format(id)
	end
	board.names[id] = name
	return name
end

-- The rows drawn for one reader: `above` rows above them and `below` below,
-- or the top of the list plus a "you" row when they are not in the cached
-- pages. Pure over `ranked`, so the test can drive it.
function SeasonService.window(ranked: { any }, userId: number, earned: number): { any }
	local spec = Config.SEASON_BOARD
	local mine = nil
	for i, entry in ipairs(ranked) do
		if entry.id == userId then
			mine = i
			break
		end
	end
	local rows = {}
	if mine then
		local from = math.max(1, mine - spec.above)
		local to = math.min(#ranked, from + spec.above + spec.below)
		from = math.max(1, to - spec.above - spec.below)
		for i = from, to do
			table.insert(rows, { rank = i, id = ranked[i].id, amount = ranked[i].amount, me = i == mine })
		end
	else
		local keep = spec.above + spec.below
		for i = 1, math.min(#ranked, keep) do
			table.insert(rows, { rank = i, id = ranked[i].id, amount = ranked[i].amount, me = false })
		end
		if earned > 0 then
			table.insert(rows, { rank = nil, id = userId, amount = earned, me = true })
		end
	end
	return rows
end

function SeasonService.push(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local season = SeasonService.state(data)
	local nextRow = Config.SEASON.tiers[season.tier + 1]
	local rows = {}
	for _, row in ipairs(SeasonService.window(board.ranked, player.UserId, season.earned)) do
		table.insert(rows, {
			rank = row.rank,
			name = if row.me then player.DisplayName else nameOf(row.id),
			amount = row.amount,
			me = row.me,
		})
	end
	local span = Config.SEASON.weeks + Config.SEASON.rest
	Remotes.get("SeasonState"):FireClient(player, {
		number = Config.seasonNumber(season.index),
		active = Config.seasonActive(now()),
		earned = season.earned,
		tier = season.tier,
		nextNeed = nextRow and nextRow.need,
		-- Server time, so the client counts down without a second clock.
		endsAt = workspace:GetServerTimeNow()
			+ ((season.index + 1) * span * WEEK - now()),
		rows = rows,
	})
end

-- ============================================================
-- EARNING
-- ============================================================

local function rewardName(reward: any): string
	local catalogue = ({
		finish = Config.FINISHES, plinth = Config.TROPHY_PLINTHS,
		coat = Config.DOG_COATS, catch = Config.CATCH_EFFECTS,
	} :: any)[reward.kind]
	local spec = catalogue and catalogue[reward.key]
	return (spec and spec.name) or reward.key
end

-- Grants every tier crossed and not yet granted this season. Idempotent:
-- `season.granted` is written before the grant, so a re-entrant push or a
-- second call cannot hand a reward over twice.
local function grantTiers(player: Player, season: any)
	local number = Config.seasonNumber(season.index)
	for i = 1, season.tier do
		local mark = tostring(i)
		if not season.granted[mark] then
			season.granted[mark] = true
			local row = Config.SEASON.tiers[i]
			local reward = row.reward
			if reward.kind == "sign" then
				notify(player, ("SEASON TIER %d! Your sign now says SEASON %s."):format(i, reward.key), "loot")
			elseif reward.kind == "trophy" then
				notify(player, ("SEASON TIER %d!"):format(i), "loot")
				TrophyService.recheck(player)
			else
				local grant = Config.seasonReward(i, number)
				if not grant then
					warn(("[SeasonService] season %s has no finish authored for tier %d"):format(tostring(number), i))
					notify(player, ("SEASON TIER %d!"):format(i), "loot")
				elseif SetService.grant(player, grant.kind, grant.key) then
					notify(player, ("SEASON TIER %d: %s is yours!"):format(i, rewardName(grant)), "loot")
				else
					notify(player, ("SEASON TIER %d! You already own %s."):format(i, rewardName(grant)), "loot")
				end
			end
		end
	end
end

local dirty: { [Player]: boolean } = {}

-- Acorns another service has just BANKED for this player. Counted only in a
-- real season week.
function SeasonService.earn(player: Player, amount: number)
	amount = math.floor(tonumber(amount) or 0)
	if amount <= 0 or not Config.seasonActive(now()) then
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	local season = SeasonService.state(data)
	season.earned += amount
	local before = season.tier
	season.tier = Config.seasonTier(season.earned)
	dirty[player] = true
	if season.tier > before then
		local best = math.max(tonumber(season.best) or 0, season.tier)
		season.best = best
		grantTiers(player, season)
		SeasonService.refreshSign(player)
		TrophyService.recheck(player)
		DataService.save(player)
	end
	SeasonService.push(player)
end

-- A robbery of `victim` by `thief` got home. The victim's ledger remembers.
function SeasonService.recordNemesis(victim: Player, thief: Player)
	if victim == thief then
		return
	end
	local data = DataService.get(victim)
	if not data then
		return
	end
	local nem = nemesisState(data)
	local key = tostring(thief.UserId)
	local row = nem.rows[key]
	if row then
		row.count += 1
		row.name = thief.DisplayName
	else
		local size = 0
		local smallestKey, smallest = nil, math.huge
		for k, r in pairs(nem.rows) do
			size += 1
			if r.count < smallest then
				smallestKey, smallest = k, r.count
			end
		end
		if size >= Config.NEMESIS_ROWS and smallestKey then
			nem.rows[smallestKey] = nil
		end
		nem.rows[key] = { name = thief.DisplayName, count = 1 }
	end
	SeasonService.refreshSign(victim)
end

-- ============================================================
-- THE STORE
-- ============================================================

local function store(index: number): OrderedDataStore
	return DataStoreService:GetOrderedDataStore(("%s.%d"):format(Config.SEASON_BOARD.store, index))
end

local function publish(player: Player)
	local data = DataService.get(player)
	if not data or not dirty[player] then
		return
	end
	local season = SeasonService.state(data)
	if season.earned <= 0 or not Config.seasonNumber(season.index) then
		return
	end
	dirty[player] = nil
	local ok, err = pcall(function()
		store(season.index):SetAsync(tostring(player.UserId), math.floor(season.earned))
	end)
	if not ok then
		dirty[player] = true
		warn(("[SeasonService] could not publish %s's season total: %s"):format(player.Name, tostring(err)))
	end
end

local function fetch()
	local index = currentIndex()
	if board.fetching or (board.index == index
		and os.clock() - board.fetchedAt < Config.SEASON_BOARD.refresh) then
		return
	end
	board.fetching = true
	local ok, err = pcall(function()
		local spec = Config.SEASON_BOARD
		local pages = store(index):GetSortedAsync(false, spec.pageSize)
		local fresh = {}
		for page = 1, spec.pages do
			for _, entry in ipairs(pages:GetCurrentPage()) do
				local id = tonumber(entry.key)
				if id then
					table.insert(fresh, { id = id, amount = entry.value })
				end
			end
			if page == spec.pages or pages.IsFinished then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
		board.ranked = fresh
		board.index = index
		-- The names the shared board page shows, resolved here so the
		-- street board's five-second refresh never waits on a web call.
		for i = 1, math.min(#fresh, Config.LEADERBOARD_SIZE) do
			nameOf(fresh[i].id)
		end
	end)
	if not ok then
		warn("[SeasonService] season board fetch failed: " .. tostring(err))
	end
	board.fetchedAt = os.clock()
	board.fetching = false
end

-- The global top of the season, for the shared page of the street board.
function SeasonService.getTop(count: number): { { name: string, amount: number } }
	local out = {}
	for i = 1, math.min(count, #board.ranked) do
		local entry = board.ranked[i]
		table.insert(out, { name = board.names[entry.id] or "...", amount = entry.amount })
	end
	return out
end

function SeasonService.onPlayerAdded(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	SeasonService.state(data)
	SeasonService.refreshSign(player)
	SeasonService.push(player)
end

function SeasonService.status(): string
	local index = currentIndex()
	return ("season index %d (Season %s), %s, shift %d weeks, board %d rows"):format(
		index, tostring(Config.seasonNumber(index)),
		if Config.seasonActive(now()) then "active" else "rest/pre-season",
		shiftSeconds // WEEK, #board.ranked)
end

function SeasonService.start()
	Players.PlayerRemoving:Connect(function(player)
		publish(player)
		dirty[player] = nil
	end)
	task.spawn(function()
		while true do
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(publish, player)
			end
			fetch()
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(SeasonService.push, player)
			end
			task.wait(Config.SEASON_BOARD.refresh)
		end
	end)
end

return SeasonService
