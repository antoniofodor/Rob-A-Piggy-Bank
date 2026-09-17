-- Step 6.4, revised: Midnight Heist. The real EventService picker and run loop, the
-- real WorldService day/dusk switch, and the real audit -- Roblox services
-- stubbed, clocks driven by hand. No Studio, no saves.
local Config, sources = ...
local checks = 0
local function check(ok, message) assert(ok, message); checks += 1 end
local function load(name, env, src)
	local run = assert(loadstring(src or sources[name], name))
	setfenv(run, setmetatable(env, { __index = getfenv() }))
	return run()
end

-- ---- THE ROSTER ROW -----------------------------------------------------------
local night = Config.EVENTS.roster.midnight
check(night and night.name == "MIDNIGHT HEIST" and night.seconds == 180 and night.weight == 2,
	"Midnight Heist takes Rush Hour's slot: 180 seconds, weight 2")
check(Config.EVENTS.roster.rush == nil and Config.EVENTS.roster.moon == nil, "Rush Hour and the Harvest Moon are gone")
check(Config.EVENT_UI.midnight and Config.EVENT_UI.midnight.live and Config.EVENT_UI.midnight.glyph, "the night has a banner row")
check(Config.EVENT_UI.rush == nil and Config.EVENT_UI.moon == nil, "no orphan banner rows")
for key, spec in pairs(Config.EVENTS.roster) do
	check(not spec.acornTheft, key .. " never opens acorn theft: it is disabled")
end
check(Config.MIDNIGHT.stealMultiplier == 2 and Config.MIDNIGHT.acornMultiplier == 2, "steals and pig-crack acorns pay double")
check(Config.MIDNIGHT_LIGHT.lighting.ClockTime ~= 14.5 and Config.MIDNIGHT_LIGHT.lighting.Brightness > 1,
	"midnight is a dusk, never a blackout")
check(#Config.auditAcorns() == 0, "auditAcorns clean: " .. table.concat(Config.auditAcorns(), "; "))

local function says(text)
	for _, p in Config.auditAcorns() do if p:find(text, 1, true) then return true end end
	return false
end
night.acornTheft = true
check(says("theft.disabled"), "an event that re-opens acorn theft is refused")
night.acornTheft = nil
Config.MIDNIGHT.acornMultiplier = 5
check(says("midnight.acorns"), "a night paying more than double acorns is refused")
Config.MIDNIGHT.acornMultiplier = 2
check(#Config.auditAcorns() == 0, "audit clean after the provocations")

-- ---- THE EVENT, THROUGH THE REAL SERVICE ------------------------------------------
local now = 0
local pushes, notes, world = {}, {}, {}
local names = setmetatable({}, { __index = function(_, k) return k end })
local player = { DisplayName = "Moonwatcher" }
local modules = {
	Config = Config, AlienModel = {}, PlotService = {}, CosmeticsService = {},
	DataService = { get = function() return nil end, save = function() end },
	SetService = {},
	WorldService = {
		setNight = function(on) table.insert(world, if on then "dusk" else "day") end,
		restoreDay = function() table.insert(world, "restore") end,
	},
	Remotes = { get = function(name)
		return {
			FireClient = function(_, _, payload, kind)
				if name == "Notify" then table.insert(notes, { text = payload, kind = kind }) end
			end,
			FireAllClients = function(_, payload)
				if name == "EventState" then table.insert(pushes, payload) end
			end,
		}
	end },
}
local ES
local sawOpen, sawSteals, sawAcorns = false, 0, 0
local env = {
	game = { GetService = function(_, name)
		if name == "Players" then return { GetPlayers = function() return { player } end } end
		return if name == "ReplicatedStorage" then { Shared = names } else {}
	end },
	script = { Parent = names },
	require = function(name) return assert(modules[name], name) end,
	os = { clock = function() return now end },
	task = { wait = function(s)
		now += s or 0
		if ES and ES.open() then sawOpen = true end
		if ES then sawSteals = math.max(sawSteals, ES.steals()); sawAcorns = math.max(sawAcorns, ES.acorns()) end
	end },
}
local src, n = sources.EventService:gsub("return EventService%s*$", [[
return {
	open = EventService.isAcornTheftOpen,
	live = EventService.isEventLive,
	runAs = function(name, fn) running = name; lastPicked = name; local ok = pcall(fn); running = nil; setPhase("quiet", "", 2); return ok end,
	night = runMidnight,
	steals = EventService.getStealMultiplier,
	acorns = EventService.getAcornMultiplier,
	draw = function() local c = pick(); lastPicked = c; return c end,
}
]])
assert(n == 1)
ES = load("EventService", env, src)

check(not ES.open(), "no theft while nothing runs")
ES.runAs("midnight", ES.night)
check(not sawOpen, "acorn theft stays closed through the whole night")
check(sawSteals == 2 and sawAcorns == 2, "steals and acorns pay double while it runs")
check(ES.steals() == 1 and ES.acorns() == 1 and not ES.live(), "and both reset at dawn")
check(world[1] == "dusk" and world[2] == "day", "the street dims on entry and returns to day on exit")
local runningPush, quietPush
for _, p in ipairs(pushes) do
	if p.phase == "running" and p.event == "midnight" then runningPush = p end
	if p.phase == "quiet" then quietPush = p end
end
check(runningPush and runningPush.stealMultiplier == 2 and runningPush.acornTheft == false
	and runningPush.secondsTotal == night.seconds,
	"the running push carries the doubled steal (set BEFORE the push) and no theft")
check(quietPush and quietPush.stealMultiplier == 1, "the push after it quotes plain steals again")
check(notes[1] and notes[1].text:find("MIDNIGHT HEIST", 1, true) and notes[1].text:find("2x", 1, true),
	"the street is told what doubles")
check(notes[#notes].text:find("Dawn", 1, true), "and told when it is over")
check(now >= night.seconds and now < night.seconds + 1, "the night lasts its roster length")

-- A night that errors mid-run: the scheduler restores the day (EventService
-- calls restoreDay on a failed moon; mirrored here through the real loop's
-- rule by checking the service source says so).
check(sources.EventService:find('chosen == "midnight" and not ok', 1, true)
	and sources.EventService:find("WorldService.restoreDay()", 1, true),
	"a night that fails halfway still hands the street back to day")

-- ---- HOW OFTEN, WITH THE REAL PICKER ------------------------------------------------
math.randomseed(6_4)
local counts, draws, repeats, last = {}, 40000, 0, nil
for _ = 1, draws do
	local c = ES.draw()
	counts[c] = (counts[c] or 0) + 1
	if c == last then repeats += 1 end
	last = c
end
local raidShare = counts.raid / draws
print(("Measured roster shares over %d slots: raid %.1f%%, midnight %.1f%%; repeats %.1f%%; raid every %.0f min, night every %.0f min")
	:format(draws, raidShare * 100, counts.midnight / draws * 100, repeats / draws * 100,
		Config.EVENTS.period / 60 / raidShare, Config.EVENTS.period / 60 / (counts.midnight / draws)))
check(raidShare > 0.38 and raidShare < 0.44, ("the raid is back to ~41%% of slots (%.1f%%)"):format(raidShare * 100))
check(counts.midnight + counts.raid == draws, "only the two events run")

-- ---- THE DAY COMES BACK EXACTLY ---------------------------------------------------------
local lighting = {}
local tweens = {}
local delayed = {}
local wsEnv = {
	game = { GetService = function(_, name)
		if name == "Lighting" then return lighting end
		if name == "TweenService" then
			return { Create = function(_, target, _, goal)
				local tw = { goal = goal, target = target }
				function tw:Play() for k, v in pairs(self.goal) do self.target[k] = (type(v) == "number") and v + 0.00037 or v end end
				function tw:Cancel() self.cancelled = true end
				table.insert(tweens, tw)
				return tw
			end }
		end
		return if name == "ReplicatedStorage" then { Shared = names } else {}
	end },
	require = function() return Config end,
	TweenInfo = { new = function() return {} end },
	Color3 = { fromRGB = function(r, g, b) return { r, g, b } end },
	Enum = setmetatable({}, { __index = function(_, g) return setmetatable({}, { __index = function(_, k) return g .. "." .. k end }) end }),
	Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end },
	task = { delay = function(_, fn) table.insert(delayed, fn) end },
	workspace = {},
}
local WS = load("WorldService", wsEnv)
for k, v in pairs(WS.DAY) do lighting[k] = v end
check(WS.DAY.ClockTime == 14.5 and WS.DAY.Brightness == 2.4, "the day table is the game's one sun")
WS.setNight(true)
check(math.abs(lighting.ClockTime - Config.MIDNIGHT_LIGHT.lighting.ClockTime) < 0.01, "dusk tweens in")
WS.setNight(false)
check(lighting.ClockTime ~= 14.5, "the fade back lands a float off, which is why the restore exists")
for _, fn in ipairs(delayed) do fn() end
check(lighting.ClockTime == 14.5 and lighting.Brightness == 2.4
	and lighting.Ambient == WS.DAY.Ambient and lighting.OutdoorAmbient == WS.DAY.OutdoorAmbient
	and lighting.ColorShift_Top == WS.DAY.ColorShift_Top, "after the fade the day is set exactly: ClockTime 14.5")
delayed = {}
WS.setNight(true)
WS.setNight(false)
WS.setNight(true)
for _, fn in ipairs(delayed) do fn() end
check(math.abs(lighting.ClockTime - Config.MIDNIGHT_LIGHT.lighting.ClockTime) < 0.01,
	"a stale restore never cuts a night that has fallen again")
WS.restoreDay()
check(lighting.ClockTime == 14.5, "restoreDay sets the day outright")

print(("PASS: %d midnight checks; roster, theft disabled, doubled steals and acorns only while live, pushes, dusk and exact day restore, measured frequency."):format(checks))
