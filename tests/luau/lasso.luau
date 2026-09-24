-- THE LASSO (docs/LASSO-PLAN.md). The odds table, the audit that guards it,
-- and the rules of a catch driven through the REAL LassoService, HerdService,
-- PiggyHaulService and ProductService with the scene stubbed: no Instance
-- worth the name, no models, no engine.
--
-- WHAT THIS CANNOT SEE is everything a player feels: the lock-on, the rope,
-- the TAP bar on a tablet, whether a 14.4-stud flee reads as a chase. Those
-- are live-only. What it pins is the state underneath -- that nothing is
-- spent on a refusal, that pity is the thrower's alone, that one rope holds a
-- piggy, that a knock drops a catch dazed and a window guards the catcher,
-- and that lassoing somebody else's catch is a robbery and your own is not.
local Config, sources = ...
local checks = 0
local function check(ok, msg) assert(ok, msg); checks += 1 end
local names = setmetatable({}, { __index = function(_, k) return k end })

-- ---- THE ODDS TABLE ----------------------------------------------------------
-- Keys are read from `Config.LASSOS` and never typed (the lead's rule): the
-- plan's table is by TIER, so the catalogue is ordered by its own `tier`.
local tiers = {}
for key, spec in pairs(Config.LASSOS) do
	table.insert(tiers, { key = key, spec = spec })
end
table.sort(tiers, function(a, b) return a.spec.tier < b.spec.tier end)
check(#tiers == 4, "four lasso tiers")
local ROPE, BRAIDED, GOLD, ELITE = tiers[1].key, tiers[2].key, tiers[3].key, tiers[4].key
check(Config.LASSOS[ELITE].robux ~= nil, "the top tier is the Robux one")

-- The plan's first-throw table, no taps / fast taps, in whole percent.
local PLAN = {
	{ common = { 80, 96 }, rare = { 35, 42 }, epic = { 12, 14 }, legendary = { 4, 5 } },
	{ common = { 90, 100 }, rare = { 50, 60 }, epic = { 20, 24 }, legendary = { 8, 10 } },
	{ common = { 100, 100 }, rare = { 70, 84 }, epic = { 35, 42 }, legendary = { 15, 18 } },
	{ common = { 100, 100 }, rare = { 90, 100 }, epic = { 60, 72 }, legendary = { 35, 42 } },
}
local RARITIES = { "common", "rare", "epic", "legendary" }
local function pct(x) return math.floor(math.min(1, x) * 100 + 0.5) end
local fullTaps = Config.LASSO.tapRate * Config.LASSO.struggle
for i, row in ipairs(PLAN) do
	local key = tiers[i].key
	for _, r in ipairs(RARITIES) do
		local lo = Config.lassoChance(key, r, 0, 0)
		local hi = Config.lassoChance(key, r, fullTaps, 0)
		check(pct(lo) == row[r][1], ("%s on %s with no taps is %d%%: %d"):format(key, r, row[r][1], pct(lo)))
		check(pct(hi) == row[r][2], ("%s on %s with full taps is %d%%: %d"):format(key, r, row[r][2], pct(hi)))
		check(Config.lassoChance(key, r, 10000, 0) == hi, ("taps past the cap buy nothing more (%s, %s)"):format(key, r))
	end
end

-- THE TIER TAPPING CAN NEVER BEAT: a Rope on a legendary.
for taps = 0, 400, 7 do
	check(Config.lassoChance(ROPE, "legendary", taps, 0) <= 0.05,
		("a Rope on a legendary stays at or under 5%% at %d taps"):format(taps))
end
check(Config.lassoChance(ROPE, "legendary", math.huge, 0) < 0.05, "even infinitely many taps: under 5%")

-- THE GUARANTEE lands on the stated throw and not one before, for every tier.
for _, t in ipairs(tiers) do
	for _, r in ipairs(RARITIES) do
		local g = Config.LASSO.guaranteeBy[r]
		check(Config.lassoChance(t.key, r, 0, g - 1) == 1, ("%s on %s is guaranteed on throw %d"):format(t.key, r, g))
	end
end
for _, r in ipairs(RARITIES) do
	local g = Config.LASSO.guaranteeBy[r]
	if g >= 2 then
		check(Config.lassoChance(ROPE, r, 0, g - 2) < 1, ("but not on throw %d for a Rope on %s"):format(g - 1, r))
	end
	-- Pity only ever raises the odds.
	for m = 1, g - 1 do
		check(Config.lassoChance(ROPE, r, 0, m) >= Config.lassoChance(ROPE, r, 0, m - 1),
			("a miss never lowers the odds (%s, miss %d)"):format(r, m))
	end
end

-- THE DESCRIPTION IS GENERATED FROM THE SAME TABLE. The plan's wording is
-- "Common 80-96%"; until `Config.lassoDescription` prints a range that way
-- this is PENDING on a Config edit rather than red -- recorded and printed,
-- never silently skipped.
local pending = {}
local function whenConfig(ok, msg)
	if ok then check(true, msg) else table.insert(pending, msg) end
end
check(Config.lassoDescription(ROPE):find("80", 1, true) ~= nil and Config.lassoDescription(ROPE):find("96", 1, true) ~= nil,
	"the Rope's description states its common odds from the table")
whenConfig(Config.lassoDescription(ROPE):find("80-96%", 1, true) ~= nil,
	"the Rope's description reads 80-96% on a common: " .. Config.lassoDescription(ROPE))
whenConfig(Config.lassoDescription(ROPE):find("4-5%", 1, true) ~= nil, "and 4-5% on a legendary")

-- ---- THE AUDIT ----------------------------------------------------------------
check(#Config.auditLassos() == 0, "the shipped lasso table audits clean: " .. table.concat(Config.auditLassos(), "; "))
local function provoke(mutate, restore, wanted, why)
	mutate()
	local fired = false
	for _, p in ipairs(Config.auditLassos()) do
		if p:find(wanted, 1, true) then fired = true end
	end
	restore()
	check(fired, why)
	check(#Config.auditLassos() == 0, "clean again after: " .. why)
end
provoke(function() Config.LASSOS[ELITE].priceSeconds = 30 end,
	function() Config.LASSOS[ELITE].priceSeconds = nil end,
	"also carries a coin price", "a Robux tier with a coin price is refused")
do
	local was = Config.LASSOS[BRAIDED].base.rare
	provoke(function() Config.LASSOS[BRAIDED].base.rare = 0.01 end,
		function() Config.LASSOS[BRAIDED].base.rare = was end,
		"is worse than", "a tier worse than the one below it is refused")
end
do
	local was = Config.LASSOS[ELITE].productId
	provoke(function() Config.LASSOS[ELITE].productId = nil end,
		function() Config.LASSOS[ELITE].productId = was end,
		"no productId", "a Robux tier with no productId field is refused")
end

-- ---- A WORLD SMALL ENOUGH TO READ ----------------------------------------------
local V = {}
local function vec(x, y, z) return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V) end
V.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V.__unm = function(a) return vec(-a.X, -a.Y, -a.Z) end
V.__mul = function(a, b)
	if type(a) == "number" then return vec(a * b.X, a * b.Y, a * b.Z) end
	return vec(a.X * b, a.Y * b, a.Z * b)
end
V.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
	if k == "Unit" then local m = t.Magnitude; return if m > 0 then vec(t.X / m, t.Y / m, t.Z / m) else vec() end
	if k == "Cross" then
		return function(a, b) return vec(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
	end
	return nil
end
local Vector3 = { new = vec, zero = vec(), zAxis = vec(0, 0, 1), yAxis = vec(0, 1, 0) }
local frame = setmetatable({}, { __mul = function(a) return a end })
local CFrame = { lookAt = function() return frame end, Angles = function() return frame end, new = function() return frame end }
local Enum = setmetatable({}, { __index = function(_, g)
	return setmetatable({}, { __index = function(_, n) return g .. "." .. n end })
end })

local clock = 1000
local OFFSET = 500000
local function serverNow() return clock + OFFSET end

local function mk(class)
	local o = { ClassName = class, Name = class, attrs = {} }
	function o:SetAttribute(k, v) self.attrs[k] = v end
	function o:GetAttribute(k) return self.attrs[k] end
	function o:Destroy() self.Parent = nil; self.destroyed = true end
	function o:FindFirstChild() return nil end
	function o:IsA(c) return c == class end
	o.Triggered = { Connect = function() return {} end }
	return o
end

-- Players, each with a save, a character and a plot of their own.
local players = {}
local nextUser = 100
local function newPlayer(name)
	nextUser += 1
	local attrs = {}
	local root = { Position = vec(0, 0, 0) }
	function root:IsA(c) return c == "BasePart" end
	local humanoid = { Health = 100 }
	local character = {}
	function character:FindFirstChild(n) if n == "HumanoidRootPart" then return root end return nil end
	function character:FindFirstChildOfClass(n) if n == "Humanoid" then return humanoid end return nil end
	function character:SetAttribute(k, v) attrs[k] = v end
	function character:GetAttribute(k) return attrs[k] end
	local p = {
		Name = name, DisplayName = name, UserId = nextUser, Parent = true,
		Character = character, root = root, humanoid = humanoid,
		data = {
			coins = 0, incomeLevel = 1, rebirths = 0, lassoStarter = false,
			consumables = {}, receipts = {},
			piggies = { owned = {}, till = Config.DEFAULT_SKIN },
			cosmetics = { owned = {} },
			piggiesStolen = 0,
		},
	}
	local pedestals = {}
	for i = 1, Config.PIGGY_LAWN_SLOT_COUNT do
		pedestals[i] = { plinth = { Position = vec(0, 0, 0) } }
	end
	p.plot = { owner = p, pedestals = pedestals, index = #players + 1 }
	table.insert(players, p)
	return p
end
local function charAttr(p, k) return p.Character:GetAttribute(k) end

local notes, states, stocks = {}, {}, {}
local function said(p, needle)
	for _, n in ipairs(notes) do
		if n.player == p and type(n.msg) == "string" and n.msg:find(needle, 1, true) then return true end
	end
	return false
end
local Remotes = { get = function(name)
	return {
		FireClient = function(_, p, a, b)
			if name == "Notify" then table.insert(notes, { player = p, msg = a, kind = b })
			elseif name == "LassoStock" then stocks[p] = a end
		end,
		FireAllClients = function(_, payload)
			if name == "LassoState" then table.insert(states, payload) end
		end,
		OnServerEvent = { Connect = function() return {} end },
	}
end }

local signal = { Connect = function() return {} end }
local PlayersService = {
	GetPlayers = function() return players end,
	GetPlayerByUserId = function(_, id)
		for _, p in ipairs(players) do if p.UserId == id and p.Parent then return p end end
		return nil
	end,
	PlayerAdded = signal, PlayerRemoving = signal,
}
local marketplace = {}
local policy = { GetPolicyInfoForPlayerAsync = function(_, p) return { ArePaidRandomItemsRestricted = p.policyRestricted == true } end }
local services = {
	ReplicatedStorage = { Shared = names },
	RunService = { Heartbeat = signal },
	Workspace = { GetServerTimeNow = function() return serverNow() end },
	Players = PlayersService,
	MarketplaceService = marketplace,
	PolicyService = policy,
}

local saved = 0
local grants, repaints, pushes = 0, 0, 0
local steals, revenges, shields = 0, {}, 0
local warnings = {}
local modules = {
	Config = Config,
	Remotes = Remotes,
	Theme = { FONT = "F", PAPER = "p", INK = "i", GOLD = "g", COOL = "c", SAND_DEEP = "s" },
	PiggyModel = { MINI_CENTRE_Y = 1.15, build = function() error("live only") end, bodyOf = function() return nil end },
	CarryPose = { HOLD = frame, anchor = function() return nil, frame end },
	DataService = { get = function(p) return p.data end, save = function() saved += 1; return true end },
	SetService = {
		owns = function(data, _, key) return data.cosmetics.owned[key] == true end,
		grant = function() grants += 1; return true end,
		repaint = function() repaints += 1 end,
		push = function() pushes += 1 end,
	},
	PlotService = {
		getAll = function() return {} end,
		getPlot = function(p) return p.plot end,
		yardContaining = function(_) return nil end,
		pedestalAt = function(plot, slot) return plot.pedestals[slot] end,
		setSwapOffer = function() end, setPlaceOffer = function() end,
		setPiggySlots = function() end, setPiggyBuffers = function() end,
	},
	ResidentService = { get = function() return nil end },
	CosmeticsService = { applyToPlot = function() end },
	EconomyService = { push = function() end },
	HeistService = {
		isCarrying = function() return false end, haulChanged = function() end,
		whyCannotSnatch = function() return nil end,
		dropShield = function() shields += 1 end,
		isDodgeImmune = function() return false end,
	},
	SocialService = {
		recordSteal = function() steals += 1 end,
		markRevenge = function(victim, thief) table.insert(revenges, { victim = victim, thief = thief }) end,
	},
	HeldItemService = {
		get = function(p) return p.held end,
		revalidate = function() end,
		putAway = function(p) p.held = nil; p.putAways = (p.putAways or 0) + 1 end,
	},
}
local env = setmetatable({
	require = function(n) return assert(modules[n], tostring(n)) end,
	game = { GetService = function(_, n) return services[n] or {} end },
	script = { Parent = names },
	Vector3 = Vector3, CFrame = CFrame, Enum = Enum,
	Instance = { new = mk },
	UDim2 = { new = function() return {} end, fromScale = function() return {} end },
	os = { clock = function() return clock end, time = function() return clock end },
	task = { spawn = function() end, wait = function() end, delay = function() end },
	warn = function(m) table.insert(warnings, m) end,
	typeof = function(x) return type(x) end,
}, { __index = getfenv() })

local function load(name, src, tail, pattern)
	local code = src
	if tail then
		local n
		code, n = src:gsub(pattern, tail)
		assert(n == 1, name .. "'s return line was not found")
	end
	local run = assert(loadstring(code, name))
	setfenv(run, env)
	return run()
end

-- THE HERD, with the scene stubbed the way the herds suite stubs it.
local H = load("HerdService", sources.HerdService, [[
buildMember = function(herd, member)
	local attrs = {}
	member.model = {
		Destroy = function() end, PivotTo = function() end,
		SetAttribute = function(_, k, v) attrs[k] = v end,
		GetAttribute = function(_, k) return attrs[k] end,
	}
end
buildBeacon = function() return { Destroy = function() end } end
fadeBeacon = function() end
landingPuff = function() end
buildPickup = function(member)
	if member.dazed and member.dazed.catcher ~= nil then
		member.pickup = { Enabled = true, Destroy = function() end }
	end
end
HerdService._herds = herds
HerdService._step = stepHerd
HerdService._setNext = function(t) nextSpawnAt = t end
return HerdService
]], "return HerdService%s*$")
modules.HerdService = H

-- THE HAUL, with the carried model reduced to what the rules read.
local P = load("PiggyHaulService", sources.PiggyHaulService, [[
attach = function(player, key)
	local model = Instance.new("Model"); model.Parent = player.Character
	local body = Instance.new("Part")
	local label = Instance.new("TextLabel")
	return model, body, label
end
PiggyHaulService._hauling = hauling
PiggyHaulService._secure = secureStep
PiggyHaulService._lost = lost
return PiggyHaulService
]], "return PiggyHaulService%s*$")
modules.PiggyHaulService = P

local Products = load("ProductService", sources.ProductService)
modules.ProductService = Products

local L = load("LassoService", sources.LassoService)
L.start()
Products.start()
check(type(marketplace.ProcessReceipt) == "function", "one ProcessReceipt callback, still ProductService's")

-- ---- A PIGGY ON THE GROUND ------------------------------------------------------
local function landed()
	H._setNext(clock)
	local herd = assert(H.spawn("stray"))
	local steps = 0
	while herd.state == "drop" and steps < 2000 do
		H._step(herd, 0.1, clock); clock += 0.1; steps += 1
	end
	assert(herd.state == "roam", "the herd landed")
	return herd, herd.members[1]
end
local function standBeside(p, at, dx, dz)
	p.root.Position = vec(at.X + dx, at.Y, at.Z + dz)
end
local function stock(p, key) return p.data.consumables[key] or 0 end
local function fillCollection(p, key)
	local last = Config.PIGGY_LAWN_SLOT_COUNT + Config.indoorPlots(p.data.rebirths)
	for i = 1, last do
		Config.placePiggy(p.data, key, i)
	end
end
local function clearCollection(p)
	for i = 1, Config.PIGGY_SLOT_COUNT do
		Config.removePiggy(p.data, i)
	end
end

local p1, p2, p3 = newPlayer("Ann"), newPlayer("Ben"), newPlayer("Cat")
local herd, member = landed()
local id, at = member.id, member.at
standBeside(p1, at, 4, 0); standBeside(p2, at, 0, 4); standBeside(p3, at, -4, 0)
local anyKey = Config.herdSkinPool("common")[1]

-- ---- THE STARTER, ONCE ------------------------------------------------------------
check(L.grantStarter(p1) == true, "a new save is handed the starter lassos")
for key, n in pairs(Config.LASSO.starter) do
	check(stock(p1, key) == n, ("the starter is %d %s"):format(n, key))
end
check(p1.data.lassoStarter == true, "and the save remembers it")
check(L.grantStarter(p1) == false, "and never twice")
p1.data.consumables = {}

-- ---- A REFUSED THROW SPENDS NOTHING ------------------------------------------------
p1.data.consumables[ROPE] = 5
notes = {}
check(L.throw(p1, id) == false and said(p1, "Hold a lasso"), "no lasso in hand: refused out loud")
p1.held = ROPE
p1.data.consumables[ROPE] = 0
check(L.throw(p1, id) == false and said(p1, "no " .. Config.LASSOS[ROPE].name), "no stock: refused out loud")
p1.data.consumables[ROPE] = 5
check(L.throw(p1, "w-nobody") == false and said(p1, "gone"), "an unknown piggy: refused")
standBeside(p1, at, Config.LASSO.range + Config.LASSO.slack + 5, 0)
check(L.throw(p1, id) == false and said(p1, "Get closer"), "out of range: refused")
standBeside(p1, at, 4, 0)
fillCollection(p1, anyKey)
check(L.throw(p1, id) == false and said(p1, "No room"), "nowhere at home to put it: refused")
clearCollection(p1)
modules.HeistService.isCarrying = function(p) return p == p1 end
check(L.throw(p1, id) == false and said(p1, "hands are full"), "hands full: refused")
modules.HeistService.isCarrying = function() return false end
do
	local h2 = assert(H.spawn("stray"))
	local m2 = h2.members[1]
	check(L.throw(p1, m2.id) == false and said(p1, "not on the ground"), "a piggy still in the air: refused")
	H.take(m2.id)
end
check(stock(p1, ROPE) == 5, "and not one of those refusals spent a lasso")
check(select(2, H.find(id)).busy == nil, "nor put a rope on the piggy")

-- ---- ONE ROPE AT A TIME -----------------------------------------------------------
states = {}
check(L.throw(p1, id) == true, "a good throw is accepted")
check(stock(p1, ROPE) == 4, "and spends exactly one lasso")
check(member.model:GetAttribute(Config.LASSO_BUSY_ATTRIBUTE) == p1.UserId, "the piggy carries the thrower's rope")
local s = states[#states]
check(s and s.phase == "flight" and s.id == id and s.thrower == p1.UserId and s.key == ROPE
	and type(s.startedAt) == "number" and type(s.endsAt) == "number" and s.endsAt > s.startedAt,
	"everybody is told: flight, with a numeric start and end and the lasso key")
p2.held = ROPE; p2.data.consumables[ROPE] = 3
notes = {}
check(L.throw(p2, id) == false and said(p2, "already has a rope"), "a second rope on the same piggy is refused")
check(stock(p2, ROPE) == 3, "and costs the second thrower nothing")
check(L.throw(p1, id) == false and said(p1, "rope out"), "one rope per thrower too")

-- ---- THE STRUGGLE, THE TAP BUDGET, AND A MISS ------------------------------------------
clock += Config.LASSO.flight + 0.01
L.step()
s = states[#states]
check(s.phase == "struggle" and type(s.startedAt) == "number" and type(s.endsAt) == "number", "then the struggle")
local rope = L._ropes[id]
for _ = 1, 50 do L.tap(p1) end
check(rope.taps == 1, "fifty taps in one instant count once: the budget runs on the server clock")
for _ = 1, 50 do L.tap(p2) end
check(rope.taps == 1, "and taps from anybody but the thrower count for nothing")
clock += 1.0
for _ = 1, 50 do L.tap(p1) end
check(rope.taps == math.floor(1.0 * Config.LASSO.tapRate) + 1, "a second in, the budget is tapRate a second: " .. rope.taps)
L._setRandom(function() return 0.99999 end)
clock += Config.LASSO.struggle
L.step()
s = states[#states]
check(s.phase == "snapped", "a miss snaps the rope, and everybody is told")
check(L.missesOf(p1, id) == 1, "the miss is on the thrower's pity")
check(L.missesOf(p2, id) == 0, "and on nobody else's")
check(member.model:GetAttribute(Config.LASSO_BUSY_ATTRIBUTE) == nil, "the rope is off the piggy")
check(herd.state == "flee", "and it runs")
check(member.model:GetAttribute(Config.LASSO_FLEE_ATTRIBUTE) ~= nil, "with the flee published for the client")
do
	local before = herd.at
	H._step(herd, 0.5, clock)
	local d = (herd.at - before).Magnitude
	check(d > 0 and d <= Config.LASSO.flee.speed * 0.5 + 1e-6, ("it runs directly away at the flee speed: %.2f"):format(d))
	local away = (herd.at - p1.root.Position).Magnitude > (before - p1.root.Position).Magnitude
	check(away, "away from the thrower")
end

-- ---- SOMEBODY ELSE MAY THROW AT A RUNNING PIGGY, AT THEIR OWN ODDS ------------------------
at = member.at
standBeside(p2, at, 0, 4)
check(L.throw(p2, id) == true, "a running piggy may be lassoed by anybody")
check(herd.state == "roam", "and a rope stops it running")
check(L.missesOf(p2, id) == 0, "p2 starts with no pity on it")
clock += Config.LASSO.flight + 0.01; L.step()
L._setRandom(function() return 0 end)
clock += Config.LASSO.struggle; L.step()
check(states[#states].phase == "caught", "the roll lands: caught")
check(P.isHauling(p2), "and it is in the catcher's arms")
check(select(2, H.find(id)) == nil, "out of the wild")
check(L.missesOf(p1, id) == 0, "and every pity ladder on it is gone with it")
check(charAttr(p2, Config.PIGGY_HAUL_ATTRIBUTE) == nil and charAttr(p2, Config.PIGGY_HAUL_FROM_ATTRIBUTE) == nil,
	"a catch of your own sets neither haul attribute")
check(shields == 0, "and drops nobody's shield")

-- ---- A NAB KNOCKS IT LOOSE, AFTER THE IMMUNITY, AND IT LANDS DAZED ----------------------------
notes = {}
check(P.nab(p3, p2) == false and P.isHauling(p2), "inside the immunity after a catch, a nab does nothing")
check(said(p3, "only just picked that up"), "and the nabber is told why")
clock += Config.LASSO.dazed.immunity + 0.1
check(P.nab(p3, p2) == true, "after it, a nab knocks it loose")
check(not P.isHauling(p2), "out of their arms")
check(charAttr(p2, Config.LASSO_KNOCK_ATTRIBUTE) == 1, "and the knocked-loose pose is bumped on the carrier")
local function findDazed(exclude)
	for _, h in ipairs(H._herds) do
		if h.state == "dazed" and h.members[1] and h.members[1].id ~= exclude then return h, h.members[1] end
	end
	return nil, nil
end
local dh, dm = findDazed()
check(dm ~= nil, "it lands dazed on the ground")
local did = dm.id
check(dm.model:GetAttribute(Config.LASSO_TARGET_ATTRIBUTE) == did, "as a lasso target")
check(dm.model:GetAttribute(Config.LASSO_DAZED_ATTRIBUTE) == p2.UserId, "with its catcher named")
check(math.abs(dm.model:GetAttribute(Config.LASSO_OPEN_AT_ATTRIBUTE) - (serverNow() + Config.LASSO.dazed.catcherWindow)) < 1e-6,
	"opening to everybody after the catcher window")
check(dm.pickup ~= nil, "and the catcher has a hand pick-up")

-- ---- ONLY THE CATCHER INSIDE THE WINDOW ------------------------------------------------------
standBeside(p3, dm.at, -4, 0); standBeside(p2, dm.at, 0, 4); standBeside(p1, dm.at, 4, 0)
p3.held = ROPE; p3.data.consumables[ROPE] = 2
notes = {}
check(L.throw(p3, did) == false and said(p3, "Only"), "somebody else's lasso inside the window is refused")
check(stock(p3, ROPE) == 2, "and spends nothing")
L.pickup(p3, did)
check(not P.isHauling(p3) and said(p3, "not your catch"), "and nobody else may pick it up by hand")

-- ---- AFTER IT, A LASSO ON SOMEBODY ELSE'S CATCH IS A ROBBERY ----------------------------------
clock += Config.LASSO.dazed.catcherWindow + 0.1
check(L.throw(p3, did) == true, "after the window anybody may lasso it")
clock += Config.LASSO.flight + 0.01; L.step()
clock += Config.LASSO.struggle; L.step()
check(P.isHauling(p3), "and p3 caught it")
check(p3.held == nil and (p3.putAways or 0) >= 1, "a catch puts the lasso away, so the carry reads as the plain hug")
check(charAttr(p3, Config.PIGGY_HAUL_ATTRIBUTE) == "stolen", "a lassoed dropped catch is a STOLEN haul")
check(charAttr(p3, Config.PIGGY_HAUL_FROM_ATTRIBUTE) == p2.UserId, "from its catcher")
check(said(p2, "lassoed your"), "and the catcher is told")
check(shields == 1, "and the thief's shield drops, as for a snatch")

-- The secure: the thief standing on their own lawn by a free plinth.
modules.PlotService.yardContaining = function(pos) return if pos == p3.root.Position then p3.plot else nil end
local haul = P._hauling[p3]
local stolenKey = haul.key
P._secure(p3, haul, clock)
P._secure(p3, haul, clock + Config.PIGGY_HAUL.secureSeconds + 0.1)
check(not P.isHauling(p3), "five seconds on your own lawn and it is yours")
check(Config.piggyPlacedCount(p3.data, stolenKey) >= 1, "standing on a plinth")
check(p3.data.cosmetics.owned[stolenKey] == true, "and in the wardrobe, as a first copy")
check(steals == 1, "a wanted star for the thief")
check(p3.data.piggiesStolen == 1, "and one on the lifetime count")
check(#revenges == 1 and revenges[1].victim == p2 and revenges[1].thief == p3, "a revenge marker for the catcher")
check(charAttr(p3, Config.PIGGY_HAUL_ATTRIBUTE) == nil and charAttr(p3, Config.PIGGY_HAUL_FROM_ATTRIBUTE) == nil,
	"and both haul attributes come off when the haul ends")

-- ---- THE CATCHER'S OWN PICK-UP IS NOT A THEFT --------------------------------------------------
local oid = H.spawnDazed(anyKey, p1.root.Position, p1.UserId)
L.pickup(p1, oid)
check(P.isHauling(p1), "the catcher picks their own dropped catch up by hand")
check(charAttr(p1, Config.LASSO_SCOOP_ATTRIBUTE) == 1, "with the scoop pose bumped")
check(charAttr(p1, Config.PIGGY_HAUL_ATTRIBUTE) == nil, "and it is not a robbery")
modules.PlotService.yardContaining = function(pos) return if pos == p1.root.Position then p1.plot else nil end
local haul1 = P._hauling[p1]
P._secure(p1, haul1, clock)
P._secure(p1, haul1, clock + Config.PIGGY_HAUL.secureSeconds + 0.1)
check(not P.isHauling(p1) and steals == 1 and #revenges == 1, "secured with no star and no marker")

-- ---- A GRANT THAT YIELDS MAY NOT BE GRANTED TWICE -----------------------------------------------
-- The live bug: the grant saved to the DataStore (which yields) before the haul
-- was detached, so every Heartbeat until the save returned granted the same
-- catch again, and one lassoed piggy filled a whole lawn with copies.
local yid = H.spawnDazed(anyKey, p1.root.Position, p1.UserId)
L.pickup(p1, yid)
local yhaul = P._hauling[p1]
local grants = 0
local held: thread? = nil
P.registerWild(H.spawnDazed, function(player, key, slot)
	grants += 1
	local ok = H.grantAt(player, key, slot)
	-- Only the secure frame the test suspends may yield; the harness itself
	-- runs inside a coroutine, so `isyieldable` is true everywhere.
	if coroutine.running() == held then coroutine.yield() end
	return ok
end)
local before = Config.piggyPlacedCount(p1.data, yhaul.key)
local done = clock + Config.PIGGY_HAUL.secureSeconds + 0.1
P._secure(p1, yhaul, clock)
local co = coroutine.create(P._secure)
held = co
coroutine.resume(co, p1, yhaul, done)
P._secure(p1, yhaul, done + 0.02)
P._secure(p1, yhaul, done + 0.04)
coroutine.resume(co)
check(grants == 1, "a secure frame that runs while the grant is still yielding grants nothing")
check(Config.piggyPlacedCount(p1.data, yhaul.key) == before + 1, "exactly one more copy stands on the lawn")
check(not P.isHauling(p1), "and the haul ends once the grant returns")
P.registerWild(H.spawnDazed, H.grantAt)

-- ---- A ZAPPER KNOCKS IT LOOSE; DEATH AND ARREST DROP IT OPEN ------------------------------------
local zid = H.spawnDazed(anyKey, p1.root.Position, p1.UserId)
L.pickup(p1, zid)
check(P.knockWild(p1, p3) == false and P.isHauling(p1), "no zapper knock inside the pick-up immunity")
clock += Config.LASSO.dazed.immunity + 0.1
check(P.knockWild(p1, p3) == true and not P.isHauling(p1), "after it, the zapper knocks it loose")
local _, zm = findDazed()
check(zm ~= nil, "dazed on the ground again")
H.take(zm.id)

local lid = H.spawnDazed(anyKey, p1.root.Position, p1.UserId)
L.pickup(p1, lid)
P._lost(p1)
check(not P.isHauling(p1), "dying drops it")
local _, lm = findDazed()
check(lm and lm.model:GetAttribute(Config.LASSO_DAZED_ATTRIBUTE) == 0, "dazed, with no catcher")
check(lm and lm.model:GetAttribute(Config.LASSO_OPEN_AT_ATTRIBUTE) <= serverNow(), "open to everybody at once")
check(lm and lm.pickup == nil, "and no hand pick-up for anybody")
H.take(lm.id)

local cid = H.spawnDazed(anyKey, p1.root.Position, p1.UserId)
L.pickup(p1, cid)
P.confiscate(p1)
local _, cm = findDazed()
check(not P.isHauling(p1) and cm and cm.model:GetAttribute(Config.LASSO_DAZED_ATTRIBUTE) == 0,
	"an arrest drops it dazed and open too")
H.take(cm.id)

-- ---- A DAZED PIGGY WAKES AFTER THIRTY SECONDS, UNLESS ROPED -------------------------------------
local wid = H.spawnDazed(anyKey, p1.root.Position, p2.UserId)
local wh, wm = H.find(wid)
L._pity[p1] = L._pity[p1] or {}
L._pity[p1][wid] = 3
H.setBusy(wid, 12345)
H._step(wh, 0.1, clock + Config.LASSO.dazed.wake + 1)
check(wh.state == "dazed", "a roped dazed piggy does not get up")
H.setBusy(wid, nil)
H._step(wh, 0.1, clock + Config.LASSO.dazed.wake - 1)
check(wh.state == "dazed", "nor before its wake time")
H._step(wh, 0.1, clock + Config.LASSO.dazed.wake + 1)
check(wh.state ~= "dazed", "after it, untouched, it rejoins the wild")
check(wm.model:GetAttribute(Config.LASSO_DAZED_ATTRIBUTE) == nil and wm.dazed == nil, "no longer anybody's dropped catch")
check(L.missesOf(p1, wid) == 0, "and the pity on it is gone")

-- ---- BUYING -------------------------------------------------------------------------------------
do
	local buyer = newPlayer("Dot")
	local each = Config.lassoPrice(ROPE, 1, 0)
	buyer.data.coins = each * 3
	L.buy(buyer, ROPE, 3)
	check(stock(buyer, ROPE) == 3 and buyer.data.coins == 0, "three coin lassos at the server's own price")
	notes = {}
	L.buy(buyer, ROPE, 1)
	check(stock(buyer, ROPE) == 3 and said(buyer, "more coins"), "too few coins: refused out loud")
	buyer.data.coins = 10 ^ 12
	L.buy(buyer, ROPE, 50)
	check(stock(buyer, ROPE) == 13, "a count is clamped to ten")
	local gate = Config.LASSOS[BRAIDED].rebirths or 0
	if gate > 0 then
		L.buy(buyer, BRAIDED, 1)
		check(stock(buyer, BRAIDED) == 0 and said(buyer, ("Rebirth %d unlocks the %s."):format(gate, Config.LASSOS[BRAIDED].name)),
			"a rebirth-gated lasso says which rebirth")
		buyer.data.rebirths = gate
		L.buy(buyer, BRAIDED, 1)
		check(stock(buyer, BRAIDED) == 1, "and sells once the gate is met")
	end
	L.buy(buyer, ELITE, 1)
	check(stock(buyer, ELITE) == 0 and said(buyer, "Robux"), "the Elite tier is never sold for coins")
	L.push(buyer)
	local card = stocks[buyer]
	check(card and card.stock[ROPE] == stock(buyer, ROPE) and card.prices[ELITE] == nil and type(card.prices[ROPE]) == "number",
		"the stock card carries the stock, the coin prices, and no coin price for the Elite tier")
	check(card and type(card.elite) == "table" and card.elite.allowed == false, "an unasked player may not be offered the Elite tier")
end

-- ---- THE ELITE RECEIPT --------------------------------------------------------------------------
do
	local spec = Config.LASSOS[ELITE]
	local wasId = spec.productId
	spec.productId = 777001
	local rich, strict = newPlayer("Eve"), newPlayer("Fin")
	strict.policyRestricted = true
	Products.askPolicy(rich)
	Products.askPolicy(strict)
	local GRANTED = Enum.ProductPurchaseDecision.PurchaseGranted
	local PENDING = Enum.ProductPurchaseDecision.NotProcessedYet
	check(marketplace.ProcessReceipt({ PlayerId = strict.UserId, ProductId = 777001, PurchaseId = "L1" }) == PENDING,
		"a restricted player's Elite receipt is never granted")
	check(stock(strict, ELITE) == 0, "and hands over nothing")
	check(marketplace.ProcessReceipt({ PlayerId = rich.UserId, ProductId = 777001, PurchaseId = "L2" }) == GRANTED,
		"a permitted player's receipt is granted")
	check(stock(rich, ELITE) == (spec.pack or 1), "a pack of Elite lassos into the stock")
	check(marketplace.ProcessReceipt({ PlayerId = rich.UserId, ProductId = 777001, PurchaseId = "L2" }) == GRANTED
		and stock(rich, ELITE) == (spec.pack or 1), "a redelivered receipt pays once")
	spec.productId = wasId
	check(Products.lassoOfProduct(0) == nil, "product id 0 never matches a receipt")
end

-- ---- THE WIRING, AS SOURCE -------------------------------------------------------------------
local main = sources.Main
check(main:find("LassoService.start()", 1, true) ~= nil, "Main starts the lasso")
check(main:find("Config.auditLassos()", 1, true) ~= nil, "and warns on its audit at boot")
check(main:find("GadgetService.registerZapKnock(PiggyHaulService.knockWild)", 1, true) ~= nil, "and wires the zapper knock")
check(main:find("LassoService.onPlayerReady(player)", 1, true) ~= nil, "and hands the starter on join")
check(main:find("LassoModel", 1, true) ~= nil, "and warms the lasso meshes")
check(sources.SettingsService:find("Config.LASSOS", 1, true) ~= nil, "the hot bar allowlist takes the lasso keys")
check(sources.SettingsService:find("musicVolume", 1, true) ~= nil, "and still carries the volume sanitiser")
check(sources.GadgetService:find("zapKnock(", 1, true) ~= nil, "the zapper's landed hit calls the knock")
check(sources.AdminService:find("commands.lassos", 1, true) ~= nil and sources.AdminService:find("commands.droppiggy", 1, true) ~= nil,
	"and the admin can give lassos and drop a piggy of any rarity")
check(sources.HerdService:find('"CatchPrompt"', 1, true) == nil, "the free catch prompt is gone")

for _, msg in ipairs(pending) do
	print("PENDING: " .. msg)
end
print(("PASS: %d lasso checks, %d pending on the Config edit; the odds table, the guarantee, the audit, refusals before the spend, one rope, the tap budget, pity per thrower, flee, dazed windows, knock-loose, theft, wake, buying and the Elite receipt."):format(checks, #pending))
