-- THE WANTED STARS, BOTH ENDS, ON ONE CLOCK.
--
-- SocialService owns the stars (a count and a server-time stamp), the pin
-- (the Most Wanted player reads five and does not fade), the hand-over (the
-- old leader fades from five) and the arrest (sheet wiped, board moved,
-- stars wiped, in that order). `Shared/Wanted` draws the fill draining out
-- of the newest star from the same stamp. The property worth asserting is
-- that the two ends are ONE SUBTRACTION: the gold reaches empty on the chip
-- in the instant `starsOf` drops the star on the server -- so the suite
-- loads the real service against a clock it can advance, feeds the real
-- payload it fires into the real chip, and holds the drawn fills against
-- `Config.starsAfterQuiet`.
--
-- And it asserts what the designer asked to be asserted: the sheet, the
-- stars and the board are PER SERVER. Tables keyed on Player, cleared when
-- the player leaves, written to no save.
local Config, SOURCES = ...
local checks = 0
local function check(ok, message) assert(ok, message); checks += 1 end

-- ---- THE STUB ---------------------------------------------------------------
local clock = 1000
local value = function(...) return { ... } end
-- The police suite's vector and frame stub, verbatim: the boards are legged
-- with real `RightVector * width` arithmetic at start().
local V = {}
V.__index = V
local function vec(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, V) end
function V.__add(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
function V.__sub(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
function V.__mul(a, b)
	if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
local CF = {}
local function cframe(px, py, pz, r)
	return setmetatable({ p = vec(px, py, pz), r = r or { 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, CF)
end
function CF.__index(self, key)
	if key == "Position" then return rawget(self, "p") end
	if key == "X" then return rawget(self, "p").X end
	if key == "Y" then return rawget(self, "p").Y end
	if key == "Z" then return rawget(self, "p").Z end
	local r = rawget(self, "r")
	if key == "LookVector" then return vec(-r[3], -r[6], -r[9]) end
	if key == "RightVector" then return vec(r[1], r[4], r[7]) end
	if key == "UpVector" then return vec(r[2], r[5], r[8]) end
	return rawget(CF, key)
end
local function mul3(a, b)
	local o = {}
	for i = 0, 2 do for j = 0, 2 do
		local acc = 0
		for k = 0, 2 do acc += a[i * 3 + k + 1] * b[k * 3 + j + 1] end
		o[i * 3 + j + 1] = acc
	end end
	return o
end
local function apply(r, v)
	return vec(r[1] * v.X + r[2] * v.Y + r[3] * v.Z, r[4] * v.X + r[5] * v.Y + r[6] * v.Z,
		r[7] * v.X + r[8] * v.Y + r[9] * v.Z)
end
function CF.__mul(a, b)
	if getmetatable(b) == V then local w = apply(a.r, b); return vec(a.p.X + w.X, a.p.Y + w.Y, a.p.Z + w.Z) end
	local w = apply(a.r, b.p)
	return cframe(a.p.X + w.X, a.p.Y + w.Y, a.p.Z + w.Z, mul3(a.r, b.r))
end
local CFrame = {}
CFrame.new = function(x, y, z) if type(x) == "table" then return cframe(x.X, x.Y, x.Z) end return cframe(x or 0, y or 0, z or 0) end
CFrame.Angles = function(rx, ry, rz)
	rx, ry, rz = rx or 0, ry or 0, rz or 0
	local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
	return cframe(0, 0, 0, mul3(mul3({ 1, 0, 0, 0, cx, -sx, 0, sx, cx }, { cy, 0, sy, 0, 1, 0, -sy, 0, cy }), { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }))
end
CFrame.identity = cframe(0, 0, 0)
local INST = {}
INST.__index = function(self, key) return rawget(INST, key) end
INST.__newindex = function(self, key, v)
	if key == "Parent" then
		local old = rawget(self, "Parent")
		if type(old) == "table" and rawget(old, "_kids") then
			local kids = rawget(old, "_kids")
			for i, kid in ipairs(kids) do if kid == self then table.remove(kids, i) break end end
		end
		rawset(self, "Parent", v)
		if type(v) == "table" and rawget(v, "_kids") then table.insert(rawget(v, "_kids"), self) end
		return
	end
	rawset(self, key, v)
end
function INST:IsA(c) return rawget(self, "ClassName") == c end
function INST:GetChildren() return table.clone(rawget(self, "_kids")) end
function INST:FindFirstChild(name)
	for _, kid in ipairs(rawget(self, "_kids")) do if rawget(kid, "Name") == name then return kid end end
	return nil
end
function INST:FindFirstChildOfClass(c)
	for _, kid in ipairs(rawget(self, "_kids")) do if rawget(kid, "ClassName") == c then return kid end end
	return nil
end
function INST:ClearAllChildren() rawset(self, "_kids", {}) end
function INST:Destroy() self.Parent = nil end
local Instance = { new = function(class)
	return setmetatable({ ClassName = class, Name = class, _kids = {}, Visible = true }, INST)
end }
local Enum = setmetatable({}, { __index = function(_, group)
	return setmetatable({}, { __index = function(_, name) return group .. "." .. name end })
end })
local fired = {}
local clientHandlers = {}
local function firedTo(name, player)
	local last
	for _, hit in ipairs(fired[name] or {}) do if hit.player == player then last = hit end end
	return last
end
local Remotes = { get = function(name)
	fired[name] = fired[name] or {}
	return {
		FireClient = function(_, player, ...) table.insert(fired[name], { player = player, args = { ... } }) end,
		FireAllClients = function(_, ...) table.insert(fired[name], { player = false, args = { ... } }) end,
		OnClientEvent = { Connect = function(_, fn) clientHandlers[name] = fn end },
		OnServerEvent = { Connect = function() end },
	}
end }
local Theme = setmetatable({ OUTLINE = 3, OUTLINE_THIN = 2, MENU_Z = 45 }, {
	__index = function(_, key) return function(first) return first end end,
})
local players = {}
local removing = nil
local Players = {
	GetPlayers = function() return table.clone(players) end,
	PlayerRemoving = { Connect = function(_, fn) removing = fn end },
	PlayerAdded = { Connect = function() end },
	GetNameFromUserIdAsync = function() return "someone" end,
}
local heartbeat = nil
local RunService = { Heartbeat = { Connect = function(_, fn) heartbeat = fn end }, IsStudio = function() return false end }
local spawned = {}
-- Spawns are parked during start() -- its refresh loop would spin on a
-- no-op wait forever -- and run inline afterwards, so the star alarm fires
-- where the service fires it.
local runSpawns = false
local task = { spawn = function(fn) if runSpawns then fn() else table.insert(spawned, fn) end end, defer = function() end, wait = function() end }
local workspace = { World = Instance.new("Folder"), GetServerTimeNow = function() return clock end }
local store = { SetAsync = function() end, GetSortedAsync = function() return { GetCurrentPage = function() return {} end } end }
local DataStoreService = { GetOrderedDataStore = function() return store end }
local anyService = setmetatable({}, { __index = function() return function() end end })
local shared = setmetatable({}, { __index = function(_, mod) return { __module = mod } end })
local modules = {
	Config = Config, Remotes = Remotes, Theme = Theme,
	DataService = { get = function() return nil end },
	PlotService = { getPlot = function() return nil end },
	TrophyService = setmetatable({}, { __index = function() return function() end end }),
}
local warnings = {}
local function load(name)
	local env
	local function req(token)
		local mod = type(token) == "table" and token.__module or tostring(token)
		if modules[mod] then return modules[mod] end
		assert(SOURCES[mod], name .. " requires something this suite does not carry: " .. mod)
		local run = assert(loadstring(SOURCES[mod], mod))
		setfenv(run, env)
		modules[mod] = run()
		return modules[mod]
	end
	env = setmetatable({
		Color3 = { fromRGB = value, new = value }, Vector3 = { new = vec }, Vector2 = { new = value },
		CFrame = CFrame, Enum = Enum,
		UDim2 = { new = value, fromScale = value, fromOffset = value }, UDim = { new = value },
		Instance = Instance, require = req, task = task, workspace = workspace,
		warn = function(message) table.insert(warnings, tostring(message)) end,
		script = { Parent = shared },
		game = { GetService = function(_, svc)
			if svc == "ReplicatedStorage" then return { Shared = shared } end
			if svc == "Players" then return Players end
			if svc == "RunService" then return RunService end
			if svc == "DataStoreService" then return DataStoreService end
			return anyService
		end },
	}, { __index = getfenv() })
	return req({ __module = name })
end

local STARS = Config.WANTED_STARS
local MAX, FADE, HUNTED = STARS.max, STARS.fade, STARS.huntedFrom
check(MAX == 5 and HUNTED <= MAX and FADE > 0, "five stars, hunted inside the ladder, a real fade window")

local Social = load("SocialService")
Social.start()
runSpawns = true
check(type(removing) == "function", "SocialService.start connects PlayerRemoving")
local alarms = 0
Social.registerStarAlarm(function() alarms += 1 end)

local function player(id, name) return { UserId = id, Name = name, DisplayName = name, Parent = true, Character = nil } end
local a, b, c = player(1, "Ada"), player(2, "Bo"), player(3, "Cy")
players = { a, b, c }

local function payload(p)
	Social.pushWanted(p)
	local hit = firedTo("WantedState", p)
	assert(hit, "no WantedState pushed to " .. p.Name)
	return hit.args[1]
end
local function notifies(p, needle)
	local n = 0
	for _, hit in ipairs(fired.Notify or {}) do
		if hit.player == p and type(hit.args[1]) == "string" and hit.args[1]:find(needle, 1, true) then n += 1 end
	end
	return n
end

-- ---- NOTHING STOLEN ---------------------------------------------------------
local fresh = payload(a)
check(fresh.sheet == 0 and fresh.stars == 0 and fresh.pinned == false and fresh.isLeader == false,
	"a fresh player has no sheet, no stars and no pin")
check(fresh.starsAt == clock, "a run-less payload is stamped now, so a chip draws no drain from it")
check(fresh.starsMax == MAX, "the ladder's length arrives in the payload")
local none = Social.getMostWanted()
check(none == nil, "an empty server has nobody on the board")

-- ---- ONE DELIVERY, THEN THE BOARD --------------------------------------------
Social.recordSteal(a, 100)
check(Social.getStars(a) == 1, "one delivery is one star before the board has moved")
local one = payload(a)
check(one.stars == 1 and one.starsAt == clock and one.pinned == false, "the payload carries the count and the server-time stamp")
check(notifies(a, "The patrol comes for you on every pass") == 0, "one star says nothing about a patrol")

Social.refresh()
local leader = Social.getMostWanted()
check(leader == a, "the only thief leads the board")
check(Social.getStars(a) == MAX, "THE MOST WANTED PLAYER READS FIVE STARS, whatever their run was")
check(Social.isPinned(a) == true, "and says so")
local pinned = payload(a)
check(pinned.pinned == true and pinned.stars == MAX and pinned.isLeader == true and pinned.hunted == true,
	"the payload reports the pin, five stars, the lead and the hunt")
check(notifies(a, "The next patrol comes for you") == 1, "taking the board announces the patrol, once")
check(alarms == 0, "taking the board does not call the patrol early on its own")
check(Social.getStarMultiplier(a) == Config.getStarPayout(MAX), "the pinned leader is paid at the top of the ladder")
local target = Social.getPursuitTarget()
check(target == a, "and is the pursuit target on every pass")

-- ---- THE PIN DOES NOT FADE ---------------------------------------------------
clock += FADE * (MAX + 2)
check(Social.getStars(a) == MAX, "seven fade windows of quiet leave the leader at five")
check(payload(a).starsAt == clock, "the held clock is re-stamped on every read, so a hand-over starts from a full star")
Social.recordSteal(a, 50)
Social.recordSteal(a, 50)
check(notifies(a, "stars. The patrol comes for you on every pass") == 0,
	"a pinned leader is not told they crossed three stars on every delivery")
check(alarms == 0, "nor does a pinned leader call the patrol early on every delivery")

-- ---- HAND-OVER: THE OLD LEADER FADES FROM FIVE --------------------------------
Social.recordSteal(b, 1000)
Social.refresh()
check(Social.getMostWanted() == b, "the bigger sheet takes the board")
check(Social.getStars(b) == MAX and Social.isPinned(b), "and is pinned in turn")
check(Social.isPinned(a) == false and Social.getStars(a) == MAX, "the old leader starts fading FROM FIVE")
local handed = payload(a)
check(handed.pinned == false and handed.stars == MAX and handed.starsAt == clock, "stamped at the hand-over, so the first star drains from full")
clock += FADE
check(Social.getStars(a) == MAX - 1, "one fade window later the old leader has four")
clock += FADE * (MAX - 1)
check(Social.getStars(a) == 0, "and none after five")
check(Social.getStars(b) == MAX, "while the new leader still holds five")
check(Social.getHeat(a) == 200, "the sheet is not the stars: fading costs it nothing")

-- ---- THE ALARM FIRES ONCE PER REAL REACH OF FIVE ------------------------------
for _ = 1, MAX do Social.recordSteal(c, 10) end
check(Social.getStars(c) == MAX and not Social.isPinned(c), "five deliveries are five real stars")
check(alarms == 1, "reaching five for real calls the patrol exactly once")
Social.recordSteal(c, 10)
check(alarms == 1, "and staying at five does not call it again")
check(notifies(c, "stars. The patrol comes for you on every pass") == 1, "crossing the hunted line is said once")
target = Social.getPursuitTarget()
check(target == b, "five pinned against five real: the bigger sheet is the target")

-- ---- ARREST: SHEET, BOARD, STARS, IN POLICESERVICE'S ORDER --------------------
Social.clearHeat(b)
check(Social.getMostWanted() ~= b, "a wiped sheet hands the board on immediately, not on the next tick")
check(Social.getMostWanted() == a, "to the biggest remaining sheet")
Social.clearStars(b)
check(Social.getStars(b) == 0 and Social.getHeat(b) == 0, "a most-wanted arrest leaves no sheet and no stars")
clock += FADE * 10
check(Social.getStars(b) == 0, "and nothing re-pins them afterwards")
check(Social.getStars(a) == MAX and Social.isPinned(a), "the new leader is pinned at five from a faded run")
-- An ORDINARY bust of the leader keeps the sheet and therefore the pin.
Social.clearStars(a)
check(Social.getStars(a) == MAX, "an ordinary bust of the Most Wanted player leaves them pinned: the sheet, and so the board, stayed")
local police = SOURCES.PoliceService
local heatAt = police:find("SocialService.clearHeat(alarm.thief)", 1, true)
local starsAt = police:find("SocialService.clearStars(alarm.thief)", 1, true)
check(heatAt and starsAt and heatAt < starsAt, "PoliceService wipes the sheet BEFORE the stars, which is what releases the pin first")

-- ---- PER SERVER --------------------------------------------------------------
removing(a)
check(Social.getHeat(a) == 0 and Social.getStars(a) == 0, "leaving clears the sheet and the stars")
check(Social.getMostWanted() == nil, "and takes the title with it")
players = { b, c }
Social.refresh()
check(Social.getMostWanted() == c, "the board is recomputed from who is still here")
local social = SOURCES.SocialService
for _, field in { "data.heat", "data.stars", "data.mostWanted", "data.wanted", "data.spree", "data.stars" } do
	check(social:find(field, 1, true) == nil, "nothing in SocialService writes " .. field .. " to a save")
end
for line in social:gmatch("[^\n]+") do
	if line:find("heat[", 1, true) or line:find("stars[", 1, true) then
		check(not line:find("DataService", 1, true) and not line:find("SetAsync", 1, true) and not line:find("data.", 1, true),
			"a sheet or star write never touches a save: " .. line)
	end
end
local removingBlock = social:match("PlayerRemoving:Connect%(function%(player%)(.-)end%)")
check(removingBlock ~= nil, "the PlayerRemoving block is findable")
for _, needle in { "heat[player] = nil", "stars[player] = nil", "mostWanted = nil" } do
	check(removingBlock:find(needle, 1, true) ~= nil, "PlayerRemoving clears: " .. needle)
end
check(social:find("local heat: { [Player]: number } = {}", 1, true) ~= nil, "the sheet is keyed on Player")
check(social:find("local stars: { [Player]: { count: number, at: number } } = {}", 1, true) ~= nil, "the stars are keyed on Player")
check(social:find("os.clock() - run.at", 1, true) == nil and social:find("at = serverNow()", 1, true) ~= nil,
	"every star stamp is server time, never os.clock")
check(social:find("WEEKLY_HEIST", 1, true) ~= nil, "the weekly OrderedDataStore board is a different thing and stays")

-- ---- THE CHIP DRAWS FROM THE SAME STAMP -------------------------------------
local Wanted = load("Wanted")
check(type(Wanted.fills) == "function", "the drain is a pure function the suite can hold")
for count = 0, MAX do
	for tenth = 0, FADE * MAX * 10, 7 do
		local quiet = tenth / 10
		local fills = Wanted.fills(MAX, count, quiet, FADE)
		local lit = 0
		for i = 1, MAX do
			assert(fills[i] >= 0 and fills[i] <= 1, "a fill is a unit")
			if fills[i] > 0 then lit += 1 end
			if i > 1 then assert(fills[i] <= fills[i - 1], "the newest star drains first") end
		end
		assert(lit == Config.starsAfterQuiet(count, quiet),
			("the chip's lit count and the server's star count agree: count %d quiet %.1f drew %d against %d")
				:format(count, quiet, lit, Config.starsAfterQuiet(count, quiet)))
	end
end
checks += 1
local half = Wanted.fills(MAX, 3, FADE / 2, FADE)
check(half[1] == 1 and half[2] == 1 and math.abs(half[3] - 0.5) < 1e-9 and half[4] == 0, "half a window in, the third star is half full and the others untouched")
local held = Wanted.fills(MAX, 1, FADE * 3, FADE, true)
check(held[1] == 1 and held[MAX] == 1, "a pinned row is five full stars whatever the clock says")

-- The real payload into the real chip.
local gui = Instance.new("ScreenGui")
Wanted.start(gui)
check(type(clientHandlers.WantedState) == "function" and type(heartbeat) == "function", "the chip listens and animates on Heartbeat")
local chip = gui:FindFirstChild("Wanted")
local run = chip and chip:FindFirstChild("Run")
check(run ~= nil, "the star row exists")
clientHandlers.WantedState(payload(c))
check(chip.Visible == true and #run:GetChildren() == MAX, "a push builds five stars")
local function fillOf(i)
	local star = run:FindFirstChild(("Star%d"):format(i))
	local fill = star and star:FindFirstChild("FillA")
	return fill and (fill.Visible and fill.Size[1] or 0) or nil
end
for i = 1, MAX do check(fillOf(i) == 1, "the pinned leader's star " .. i .. " is drawn full") end
-- Hand c's title to b and watch c's row drain on the chip's own clock.
Social.recordSteal(b, 100000)
Social.refresh()
check(Social.getMostWanted() == b, "b takes the board back")
clientHandlers.WantedState(payload(c))
check(fillOf(MAX) == 1 and fillOf(1) == 1, "at the hand-over every star is still full")
clock += FADE / 4
heartbeat()
check(math.abs(fillOf(MAX) - 0.75) < 1e-9 and fillOf(MAX - 1) == 1, "a quarter window later the newest star is three-quarters full and the rest untouched")
clock += FADE * 3 / 4
heartbeat()
check(fillOf(MAX) == 0 and fillOf(MAX - 1) == 1 and Social.getStars(c) == MAX - 1,
	"at exactly one window the newest star is empty on the chip and gone on the server, in the same instant")
Social.recordSteal(c, 10)
clientHandlers.WantedState(payload(c))
check(fillOf(MAX) == 1, "a delivery refills")

-- ---- IT FITS THE COLUMN -------------------------------------------------------
local wanted = SOURCES.Wanted
local function const(name) return tonumber(wanted:match("local " .. name .. " = (%d+)")) end
local width, star, gap, pad, row = const("WIDTH"), const("STAR"), const("STAR_GAP"), const("STAR_PAD"), const("STAR_ROW")
check(width == 176 and SOURCES.PiggyPanel:find("PiggyPanel.CHIP_W = 176", 1, true) ~= nil, "the chip is the column's width")
check(MAX * star + (MAX - 1) * gap <= width - 2 * pad,
	("five stars fit the row: %d against %d"):format(MAX * star + (MAX - 1) * gap, width - 2 * pad))
local diagonal = tonumber(wanted:match("local DIAGONAL = ([%d%.]+)"))
local overhang = star * (diagonal * math.sqrt(2) - 1) / 2
check(overhang > 0 and gap - 2 * overhang >= 3, ("the turned square's points stand %.2fpx proud and neighbours still clear by %.1fpx"):format(overhang, gap - 2 * overhang))
check(star + 2 <= row, "the star box sits inside its row")
check(wanted:find("os.clock", 1, true) == nil and wanted:find("GetServerTimeNow", 1, true) ~= nil, "the chip reads server time, never a process clock")
check(wanted:find("RunService.Heartbeat:Connect", 1, true) ~= nil and wanted:find("RenderStepped:Connect", 1, true) == nil, "and animates on Heartbeat, never RenderStepped")
check(wanted:find("starsAt", 1, true) ~= nil and wanted:find("pinned", 1, true) ~= nil, "and reads the stamp and the pin off the payload")
check(wanted:find("Config.WANTED_STARS.fade", 1, true) ~= nil, "against the same fade the server drops a star on")
check(#warnings == 0, "no warnings: " .. table.concat(warnings, " | "))

print(("PASS: %d wanted checks; pinned leader, fade-from-five hand-over, one alarm per reach, arrest order, per-server tables, and a chip whose drain reaches empty on the server's own clock."):format(checks))
