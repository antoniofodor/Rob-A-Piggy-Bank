-- Phase 5: the season, the nemesis ledger, the new trophies, finishes and the
-- season board window. The real SeasonService, TrophyService, SetService and
-- DataService.reconcile over in-memory saves; Roblox services stubbed and the
-- clock driven by hand. No Studio, no DataStore.
local Config, sources = ...
local checks = 0
local function check(ok, message) assert(ok, message); checks += 1 end
local function load(name, env, src)
	local run = assert(loadstring(src or sources[name], name))
	setfenv(run, setmetatable(env, { __index = getfenv() }))
	return run()
end

local WEEK = 7 * 86400
local SPAN = Config.SEASON.weeks + Config.SEASON.rest
local function weekStart(week) return week * WEEK + 3600 end

-- ---- THE CLOCK ------------------------------------------------------------------
-- Launch day, 2026-09-17, is the rest week of index 591: Season 1 is index 592.
local launch = 1789603200
check(Config.seasonIndex(launch) == 591 and Config.weekIndex(launch) % SPAN == 4, "launch day is 591's rest week")
check(Config.seasonNumber(591) == nil and not Config.seasonActive(launch), "nothing counts before Season 1")
local S1 = weekStart(592 * SPAN)
local S1_REST = weekStart(592 * SPAN + 4)
local S2 = weekStart(593 * SPAN)
check(S1 == 1790208000 + 3600, "Season 1 opens 2026-09-24 UTC")
check(Config.seasonNumber(Config.seasonIndex(S1)) == 1 and Config.seasonActive(S1), "Season 1's first week counts")
check(Config.seasonActive(weekStart(592 * SPAN + 3)), "Season 1's fourth week counts")
check(not Config.seasonActive(S1_REST), "Season 1's fifth week is rest")
check(Config.seasonNumber(Config.seasonIndex(S2)) == 2 and Config.seasonActive(S2), "Season 2 follows")
check(Config.seasonTier(0) == 0 and Config.seasonTier(9) == 0 and Config.seasonTier(10) == 1
	and Config.seasonTier(619) == 9 and Config.seasonTier(10 ^ 6) == 10, "tier thresholds")
check(Config.seasonChipText(nil, 5) == nil and Config.seasonChipText(1, 0) == nil, "no chip before a tier or a season")
check(Config.seasonChipText(1, 3) == "S1 TIER 3" and Config.seasonChipText(2, 9) == "S2 STAR"
	and Config.seasonChipText(1, 10) == "S1 CHAMPION", "chip words")
-- The SIGN tier grants no item: a sign word is shown on the plot sign, not
-- given through SetService. Tier 6 was `trophy:seasoncup` and granted nothing
-- for the same reason; it is a finish now, since the plinth, kennel and trophy
-- catalogues were retired, so it DOES grant.
check(Config.seasonReward(9, 1) == nil, "a sign tier grants no item")
check(Config.seasonReward(6, 1).kind == "finish", "a retargeted tier grants its finish")
-- KNOWN DEFECT, ASSERTED AS IT STANDS RATHER THAN AS IT SHOULD BE: tier 6
-- grants `midnightstar`, which is also `SEASON.finishes[1]` -- so a Season 1
-- player reaches tier 10 already owning its prize, the grant is said and
-- skipped, and the top of the ladder pays nothing. There is no spare finish to
-- move tier 6 onto (all five are spoken for), so fixing it is a design choice:
-- author a sixth finish, or pay tier 6 in an unused catch effect. Flip this to
-- `~=` the moment the ladder changes.
check(Config.seasonReward(6, 1).key == Config.SEASON.finishes[1],
	"tier 6 still collides with the season exclusive")
check(Config.seasonReward(10, 1).key == "midnightstar" and Config.seasonReward(10, 2) == nil,
	"the season finish resolves per season and never falls back")

-- ---- THE AUDIT ------------------------------------------------------------------
check(#Config.auditSeason() == 0, "auditSeason clean: " .. table.concat(Config.auditSeason(), "; "))
local function says(text)
	for _, p in Config.auditSeason() do if p:find(text, 1, true) then return true end end
	return false
end
Config.SEASON.tiers[2].need = 5
check(says("tiers[2]"), "falling thresholds are refused")
Config.SEASON.tiers[2].need = 20
Config.FINISHES.polished.cost = 5
check(says("FINISHES.polished"), "a priced finish is refused")
Config.FINISHES.polished.cost = nil
Config.SEASON.finishes[1] = "brighteyes"
check(says("SEASON.finishes[1]"), "a season finish must be flagged for its season")
Config.SEASON.finishes[1] = "midnightstar"
Config.FINISHES.gilded.light.brightness = 0.9
check(says("FINISHES.gilded"), "a bright lamp in the shell is refused")
Config.FINISHES.gilded.light.brightness = 0.45
local was = Config.SEASON.tiers[4].reward.key
Config.SEASON.tiers[4].reward.key = "nope"
check(says("tiers[4]"), "a reward that does not exist is refused")
Config.SEASON.tiers[4].reward.key = was
check(#Config.auditSeason() == 0, "audit clean after the provocations")

-- ---- TROPHY GRADES ------------------------------------------------------------------
check(Config.trophyGrade("hotstreak", 2) == 0 and Config.trophyGrade("hotstreak", 3) == 1
	and Config.trophyGrade("hotstreak", 4) == 2 and Config.trophyGrade("hotstreak", 99) == Config.TROPHIES.hotstreak.max,
	"a ladder-above trophy grades one per step")
check(Config.trophyGrade("seasoncup", 5) == 0 and Config.trophyGrade("seasoncup", 6) == 1
	and Config.trophyGrade("seasoncup", 10) == 5, "the Season Cup grades from tier 6 to 10")
check(Config.trophyGrade("goodharvest", 100) == 1 and Config.trophyGrade("goodharvest", 400) == 3,
	"Good Harvest doubles")
for _, key in { "hotstreak", "oldhand", "cleansheet", "seasoncup", "wantedposter", "goodharvest" } do
	check(Config.TROPHIES[key] and Config.DECOR_ITEMS[key] and Config.isEarnedElsewhere(Config.DECOR_ITEMS[key]),
		key .. " is a trophy ornament nobody can buy")
end

-- ---- SAVES --------------------------------------------------------------------------
local transformed, n = sources.DataService:gsub("return DataService%s*$",
	"DataService.defaults=defaultData\nDataService.reconcile=reconcile\nreturn DataService\n")
assert(n == 1)
local D = load("DataService", {
	game = { JobId = "season", GetService = function(_, name)
		if name == "ReplicatedStorage" then return { Shared = { Config = "Config" } } end
		if name == "DataStoreService" then return { GetDataStore = function() return {} end } end
		return {}
	end },
	require = function() return Config end,
	task = { wait = function() end }, warn = function() end,
}, transformed)
local fresh = D.defaults()
check(fresh.season.earned == 0 and fresh.season.tier == 0 and next(fresh.season.granted) == nil, "new saves start seasonless")
check(fresh.cosmetics.finish == "" and next(fresh.cosmetics.ownedFinishes) == nil, "new saves wear no finish")
check(fresh.defend.count == 0 and next(fresh.nemesis.rows) == nil, "no defends and no nemesis yet")
local old = D.defaults()
old.season, old.nemesis, old.defend = nil, "junk", nil
old.cosmetics.ownedFinishes = { brighteyes = true, retired = true, polished = "yes" }
old.cosmetics.finish = "retired"
local fixed = D.reconcile(old)
check(fixed.cosmetics.ownedFinishes.brighteyes and fixed.cosmetics.ownedFinishes.retired == nil
	and fixed.cosmetics.ownedFinishes.polished == nil, "unknown and malformed finishes are pruned")
check(fixed.cosmetics.finish == "", "a worn finish that is not owned comes off")
check(type(fixed.season) == "table" and type(fixed.season.granted) == "table"
	and type(fixed.nemesis.rows) == "table" and type(fixed.defend) == "table", "season tables are rebuilt")
local kept = D.defaults()
kept.cosmetics.ownedFinishes = { gilded = true }
kept.cosmetics.finish = "gilded"
check(D.reconcile(kept).cosmetics.finish == "gilded", "an owned finish stays on")

-- ---- THE SERVICES ------------------------------------------------------------------
local clock = S1
local notes, chips, nemeses, saves, warns = {}, {}, {}, 0, {}
local saveOf = {}
local plot = {}
local modules
local Remotes = { get = function(name)
	return {
		FireClient = function(_, _, payload, kind)
			if name == "Notify" then table.insert(notes, payload) end
		end,
		FireAllClients = function() end,
	}
end }
local function env()
	return {
		game = { GetService = function(_, name)
			if name == "ReplicatedStorage" then return { Shared = { Config = "Config", Remotes = "Remotes" } } end
			if name == "Players" then
				return {
					GetPlayerByUserId = function() return nil end,
					GetNameFromUserIdAsync = function(_, id) return "user" .. id end,
					GetPlayers = function() return {} end,
					PlayerRemoving = { Connect = function() end },
				}
			end
			return { GetOrderedDataStore = function() return {} end }
		end },
		script = { Parent = {
			DataService = "DataService", PlotService = "PlotService", SetService = "SetService",
			TrophyService = "TrophyService", SeasonService = "SeasonService",
		} },
		require = function(key) return assert(modules[key], tostring(key)) end,
		os = setmetatable({ time = function() return clock end }, { __index = os }),
		workspace = { GetServerTimeNow = function() return clock end },
		warn = function(message) table.insert(warns, message) end,
		task = { spawn = function(f) f() end, wait = function() end },
	}
end
modules = {
	Config = Config, Remotes = Remotes,
	DataService = { get = function(p) return saveOf[p] end, save = function() saves += 1 end },
	PlotService = {
		getPlot = function() return plot end,
		setSeasonChip = function(_, text, colour) table.insert(chips, text or false) end,
		setNemesis = function(_, name, count) table.insert(nemeses, { name = name, count = count }) end,
		setTrophyState = function() end, setDecor = function() end,
	},
}
modules.SetService = load("SetService", env())
modules.TrophyService = load("TrophyService", env())
local S = load("SeasonService", env())

local player = { UserId = 7, DisplayName = "Acorn Ace", Name = "ace" }
local data = D.defaults()
saveOf[player] = data

-- Pre-season: nothing counts.
clock = launch
S.earn(player, 50)
check(data.season.earned == 0 and #notes == 0, "acorns before Season 1 do not count")
clock = S1

local function tierNotes()
	local count = 0
	for _, note in notes do if note:find("SEASON TIER", 1, true) then count += 1 end end
	return count
end

S.earn(player, 9)
check(data.season.earned == 9 and data.season.tier == 0 and tierNotes() == 0, "9 acorns is no tier")
S.earn(player, 1)
check(data.season.tier == 1 and data.cosmetics.ownedFinishes.brighteyes, "tier 1 grants Bright Eyes")
check(chips[#chips] == "S1 TIER 1" and saves > 0, "the sign chip updates and the save is written")
S.earn(player, 10)
check(data.season.tier == 2 and data.trophies.plinths.marble, "tier 2 grants the marble plinth")
S.earn(player, 55)
check(data.season.tier == 4 and data.cosmetics.ownedFinishes.polished and data.dogs.owned.goldenboy,
	"crossing two tiers at once grants both")
data.cosmetics.ownedFinishes.lanternglow = true
local before = #notes
S.earn(player, 75)
check(data.season.tier == 5, "tier 5 at 150")
local sawAlready = false
for i = before + 1, #notes do if notes[i]:find("already own", 1, true) then sawAlready = true end end
check(sawAlready, "a reward already owned is said, not silently skipped")
S.earn(player, 60)
check(data.season.tier == 6 and data.season.best == 6 and data.decor.owned.seasoncup,
	"tier 6 earns the Season Cup trophy")
S.earn(player, 70)
check(data.season.tier == 7 and data.catch.owned.bubbles, "tier 7 grants the bubbles catch")
S.earn(player, 90)
check(data.season.tier == 8 and data.cosmetics.ownedFinishes.gilded, "tier 8 grants Gilded")
S.earn(player, 110)
check(data.season.tier == 9 and chips[#chips] == "S1 STAR", "tier 9 changes the sign's words")
S.earn(player, 140)
check(data.season.tier == 10 and data.cosmetics.ownedFinishes.midnightstar and chips[#chips] == "S1 CHAMPION",
	"tier 10 grants the Season 1 finish")
local granted = tierNotes()
check(granted == 10, "ten tier announcements, one each: " .. granted)
data.cosmetics.ownedFinishes.brighteyes = nil
S.earn(player, 500)
check(tierNotes() == granted and not data.cosmetics.ownedFinishes.brighteyes, "a tier is granted once a season")

-- Rest week: nothing counts, nothing rolls.
clock = S1_REST
local earned = data.season.earned
S.earn(player, 100)
check(data.season.earned == earned, "rest-week acorns do not count")

-- Season 2: lazy rollover keeps the best tier.
clock = S2
local state = S.state(data)
check(state.earned == 0 and state.tier == 0 and next(state.granted) == nil and state.best == 10,
	"the rollover forgets the season and keeps the best tier")
check(data.decor.owned.seasoncup, "the Season Cup stays on the shelf")
warns = {}
S.earn(player, 700)
check(data.season.tier == 10 and #warns == 1 and warns[1]:find("season 2", 1, true),
	"an unauthored season finish is warned and skipped, not repeated")

-- ---- THE BOARD WINDOW ----------------------------------------------------------------
local ranked = {}
for i = 1, 20 do ranked[i] = { id = 100 + i, amount = 1000 - i } end
local function ranks(rows)
	local out = {}
	for _, r in rows do table.insert(out, (r.rank or "-") .. (if r.me then "*" else "")) end
	return table.concat(out, " ")
end
check(ranks(S.window(ranked, 110, 0)) == "7 8 9 10* 11 12 13 14", "three above, four below")
check(ranks(S.window(ranked, 101, 0)) == "1* 2 3 4 5 6 7 8", "the leader sees the top eight")
check(ranks(S.window(ranked, 120, 0)) == "13 14 15 16 17 18 19 20*", "last place sees the bottom eight")
check(ranks(S.window(ranked, 999, 42)) == "1 2 3 4 5 6 7 -*", "off the pages: the top plus a you row")
check(ranks(S.window(ranked, 999, 0)) == "1 2 3 4 5 6 7", "nothing earned: no you row")
check(ranks(S.window({}, 999, 5)) == "-*", "an empty board still shows you")

-- ---- THE NEMESIS LEDGER -----------------------------------------------------------
local victim = { UserId = 1, DisplayName = "Victim" }
saveOf[victim] = D.defaults()
S.recordNemesis(victim, victim)
check(next(saveOf[victim].nemesis.rows) == nil, "robbing yourself is not a nemesis")
local rival = { UserId = 2, DisplayName = "Rival" }
S.recordNemesis(victim, rival)
S.recordNemesis(victim, rival)
for i = 1, 25 do S.recordNemesis(victim, { UserId = 1000 + i, DisplayName = "t" .. i }) end
local size = 0
for _ in saveOf[victim].nemesis.rows do size += 1 end
check(size == Config.NEMESIS_ROWS, "the ledger is capped at " .. Config.NEMESIS_ROWS .. ": " .. size)
check(saveOf[victim].nemesis.rows["2"].count == 2, "the cap drops a one-off, never the rival")
local name, count = S.nemesisOf(saveOf[victim])
check(name == "Rival" and count == 2, "the nemesis is whoever robbed most")
check(nemeses[#nemeses].name == "Rival" and nemeses[#nemeses].count == 2, "the sign shows the nemesis")
clock = weekStart(594 * SPAN)
check(S.nemesisOf(saveOf[victim]) == nil, "the ledger resets with the season")

-- ---- TROPHY COUNTERS ------------------------------------------------------------------
local t = D.defaults()
saveOf[player] = t
modules.TrophyService.recordClean(player)
modules.TrophyService.recordWanted(player)
modules.TrophyService.recordHarvest(player, 99.9)
local counts = modules.TrophyService.counts(t)
check(counts.clean == 1 and counts.wanted == 1 and counts.harvested == 99, "the new counters count")
check(t.decor.owned.wantedposter == true, "one Most Wanted session earns the Wanted Poster")
modules.TrophyService.recordHarvest(player, 1)
check(t.decor.owned.goodharvest, "100 harvested acorns earns Good Harvest")
t.robberies = 10 ^ 6
modules.TrophyService.recheck(player)
check(t.decor.owned.oldhand, "a rap-sheet rank earns Old Hand on recheck")

-- ---- SET KINDS ----------------------------------------------------------------------
local Set = modules.SetService
local s = D.defaults()
s.cosmetics.ownedFinishes.gilded = true
s.cosmetics.finish = "gilded"
s.trophies.plinths.marble = true
s.trophies.plinth = "marble"
s.dogs.kennels.midnight = true
check(Set.owns(s, "finish", "gilded") and Set.inUse(s, "finish", "gilded"), "a worn finish is owned and in use")
check(Set.owns(s, "plinth", "marble") and Set.inUse(s, "plinth", "marble"), "a standing plinth is in use")
check(Set.owns(s, "kennel", "midnight") and not Set.inUse(s, "kennel", "midnight"), "an owned kennel not in use")
check(not Config.isSellable("finish", "gilded"), "a finish cannot be sold")

-- ---- THE DEFEND COUNTER --------------------------------------------------------------
local defendSrc = sources.SocialService:match("(local function currentWeekDefends.-\nend\n)")
local recordSrc = sources.SocialService:match("(function SocialService%.recordDefend.-\nend\n)")
assert(defendSrc and recordSrc, "defend counter source")
local social = load("defends", {
	Config = Config, DataService = modules.DataService, SocialService = {},
}, defendSrc .. "\n" .. recordSrc .. "\nreturn SocialService")
local d = D.defaults()
saveOf[player] = d
social.recordDefend(player)
social.recordDefend(player)
check(d.defend.count == 2 and d.defend.index == Config.weekIndex(), "defends count this week")
d.defend.index -= 1
social.recordDefend(player)
check(d.defend.count == 1, "a new week starts the count again")

-- ---- THE CLIENT BOARD ----------------------------------------------------------------
local Board = load("SeasonBoard", {
	game = { GetService = function() return { Shared = { Config = "Config", Remotes = "Remotes", Theme = "Theme" } } end },
	require = function(key) return ({ Config = Config, Remotes = Remotes, Theme = {} })[key] end,
})
check(Board.footer(nil):find("starts soon", 1, true), "footer before a season")
check(Board.footer({ number = 1, active = false, tier = 4 }) == "Season 1 is over: you reached tier 4.", "footer in rest")
check(Board.footer({ number = 1, active = true, tier = 2, earned = 25, nextNeed = 40 })
	:find("25 / 40 acorns to tier 3", 1, true), "footer mid-season")
check(Board.footer({ number = 1, active = true, tier = 10, earned = 700 }):find("TOP TIER", 1, true), "footer at the top")
local left, right = Board.rowText({ rank = 3, name = "Ace", amount = 12 })
check(left == "3.  Ace" and right == "12 acorns", "a ranked row")
check(Board.rowText({ name = "Me", amount = 1 }) == "...  Me", "an unranked row")

print(("PASS: %d season checks; clock, tiers, grants once, rollover, rest, window, nemesis, trophies, finishes, defends and the board page. No player saves."):format(checks))
