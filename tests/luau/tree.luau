-- Step 2.7: the tree ladder, the house gate and the online rebirth bonus.
-- Real Config arithmetic, the real DataService.reconcile and the real
-- TreeService purchase path, with Roblox services stubbed. No Studio, no saves.
local Config, sources = ...
local checks = 0
local function check(ok, message) assert(ok, message); checks += 1 end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-6) end
local LEVELS, GATE = Config.TREE_LEVELS, Config.TREE_HOUSE_GATE

-- ---- THE TABLES -----------------------------------------------------------
check(#LEVELS == 5, "five tree levels, 0 to 4")
local rates = { 1.0, 1.25, 1.5, 2.0, 2.5 }
for i, rate in ipairs(rates) do
	check(LEVELS[i].rate == rate, ("level %d grows %g an hour, as 19.4 says"):format(i - 1, rate))
end
check(LEVELS[1].cost == nil, "level 0 is free: everybody has it")
local expectGate = { common = { 1, 8 }, rare = { 2, 12 }, epic = { 3, 16 }, legendary = { 4, 24 } }
for rarity, row in pairs(expectGate) do
	check(GATE[rarity].maxLevel == row[1] and GATE[rarity].cap == row[2], rarity .. " gate matches 19.4a")
end
-- Every priced rung is affordable once its gate opens: never dearer than the
-- cheapest house of the rarity that unlocks it.
for level = 1, #LEVELS - 1 do
	local rarity = Config.treeGateRarityFor(level)
	local cheapest = math.huge
	for _, tier in ipairs(Config.HOUSE_TIERS) do
		if tier.cost and tier.cost > 0 and Config.rarityOf(tier) == rarity then
			cheapest = math.min(cheapest, tier.cost)
		end
	end
	if rarity == "common" then cheapest = math.huge end
	check(LEVELS[level + 1].cost < cheapest, ("level %d (%s gate) costs less than the house that opens it"):format(level, rarity))
end
check(#Config.auditAcorns() == 0, "auditAcorns clean with the ladder: " .. table.concat(Config.auditAcorns(), "; "))
check(#Config.auditEconomy() == 0, "auditEconomy clean with the ladder")

-- ---- THE GATE READS THE BEST HOUSE OWNED ---------------------------------
local function save(level, owned, rebirths)
	return { tree = { level = level }, houses = { owned = owned, shown = "shack" },
		rebirths = rebirths or 0, treeAcorns = 0, acornsGrownAt = 0 }
end
check(Config.bestHouseRarity(save(0, { shack = true })) == "common", "the shack is Common")
check(Config.bestHouseRarity(save(0, { shack = true, mushroom = true })) == "rare", "a Rare house opens the Rare gate")
check(Config.bestHouseRarity(save(0, { shack = true, void = true, cottage = true })) == "legendary", "the best owned house wins")
check(Config.bestHouseRarity({}) == "common" and Config.bestHouseRarity(nil) == "common", "no houses reads as Common")
local shownCheap = save(0, { shack = true, skycastle = true })
shownCheap.houses.shown = "shack"
check(Config.treeCap(shownCheap) == 24, "the gate reads houses OWNED, never the one shown")
check(Config.treeLevelOf(save(9, {})) == 4 and Config.treeLevelOf(save(-2, {})) == 0
	and Config.treeLevelOf({ tree = { level = 0 / 0 } }) == 0 and Config.treeLevelOf({}) == 0,
	"a saved level is clamped to the ladder and junk reads as 0")
check(Config.treeLevelOf(save(4, { shack = true })) == 4, "a bought level is never clamped by the gate")

-- ---- GROWTH OVER A SIMULATED DAY ------------------------------------------
-- Harvested every minute so the cap never bites: what is left is the rate.
local function day(data, online)
	local harvested, t = 0, 0
	data.acornsGrownAt = 0
	data.treeAcorns = 0
	for _ = 1, 24 * 60 do
		t += 60
		Config.growAcorns(data, t, online)
		harvested += data.treeAcorns
		data.treeAcorns = 0
	end
	return harvested
end
-- The growth cursor clamps to the offline window, so the harness starts it
-- inside that window by calling with a small `now` each minute from zero.
for level = 0, #LEVELS - 1 do
	local data = save(level, { shack = true, void = true })
	local got = day(data, false)
	check(got == math.floor(24 * rates[level + 1]), ("level %d grows %d a day offline (got %d)"):format(level, math.floor(24 * rates[level + 1]), got))
end
for _, rebirths in ipairs({ 0, 5, 10, 20, 50 }) do
	local online = day(save(4, { shack = true, void = true }, rebirths), true)
	local offline = day(save(4, { shack = true, void = true }, rebirths), false)
	local factor = 1 + math.min(Config.TREE_REBIRTH_BONUS.max, rebirths * Config.TREE_REBIRTH_BONUS.perRebirth)
	check(online == math.floor(24 * 2.5 * factor + 1e-9), ("rebirth %d: online grows %d (got %d)"):format(rebirths, math.floor(24 * 2.5 * factor + 1e-9), online))
	check(offline == 60, ("rebirth %d: offline ignores the bonus"):format(rebirths))
end
check(Config.treeRebirthFactor(20, true) == 1.6 and Config.treeRebirthFactor(1000, true) == 1.6
	and Config.treeRebirthFactor(20, false) == 1, "the bonus is 3% a rebirth, capped at +60%, online only")

-- ---- THE CAP IS THE HOUSE'S -----------------------------------------------
for rarity, id in pairs({ common = "cottage", rare = "mushroom", epic = "slime", legendary = "void" }) do
	local data = save(0, { shack = true, [id] = true })
	data.acornsGrownAt = 0
	Config.growAcorns(data, Config.OFFLINE_CAP_SECONDS, false)
	check(data.treeAcorns == math.min(8, GATE[rarity].cap), rarity .. ": eight hours at level 0 grows 8, under the cap")
	data.acornsGrownAt = 0
	data.treeAcorns = 0
	for t = 3600, 48 * 3600, 3600 do Config.growAcorns(data, t, false) end
	check(data.treeAcorns == GATE[rarity].cap, rarity .. " tree stops at " .. GATE[rarity].cap)
end
-- 19.4a's own example: a Legendary owner at level 4 comes back from the
-- eight-hour offline window to 20.
local away = save(4, { shack = true, void = true })
away.acornsGrownAt = 0
Config.growAcorns(away, Config.OFFLINE_CAP_SECONDS, false)
check(away.treeAcorns == 20, "Legendary level 4 returns from eight hours offline to 20")
-- A resident's stock carries no level and no houses: 1 an hour to 8, as before.
local stock = { treeAcorns = 0, acornsGrownAt = 0 }
for t = 3600, 20 * 3600, 3600 do Config.growAcorns(stock, t) end
check(stock.treeAcorns == 8, "a resident tree still caps at 8")
local slow = { treeAcorns = 0, acornsGrownAt = 0 }
Config.growAcorns(slow, 3 * 3600)
check(slow.treeAcorns == 3, "a resident tree still grows one an hour")
-- A purchase mid-hour keeps the partial hour.
local partial = save(0, { shack = true })
partial.acornsGrownAt = 0
Config.growAcorns(partial, 5400, true)
check(partial.treeAcorns == 1 and partial.acornsGrownAt == 3600, "half an hour at level 0 carries forward")
partial.tree.level = 1
Config.growAcorns(partial, 3600 + 2880, true)
check(partial.treeAcorns == 2, "the carried half hour pays at the new rate after a purchase")

-- ---- NEXT RUNG ------------------------------------------------------------
local n, row, allowed = Config.nextTreeLevel(save(0, { shack = true }))
check(n == 1 and row == LEVELS[2] and allowed, "a Common owner may buy level 1")
n, row, allowed = Config.nextTreeLevel(save(1, { shack = true }))
check(n == 2 and not allowed, "level 2 is gated for a Common owner")
check(Config.treeGateRarityFor(2) == "rare" and Config.treeGateRarityFor(4) == "legendary", "the refusal names the rarity that opens a rung")
n = Config.nextTreeLevel(save(4, { shack = true, void = true }))
check(n == nil, "a level-4 tree has no next rung")

-- ---- AUDIT PROVOCATIONS -----------------------------------------------------
local function says(list, text)
	for _, p in list do if p:find(text, 1, true) then return true end end
	return false
end
local top = LEVELS[5]
local saved = top.cost
top.cost = Config.getCapacity(Config.ABSOLUTE_MAX_LEVEL) + 1
check(says(Config.auditEconomy(), "TREE_LEVELS"), "a rung above the largest pig is refused by auditEconomy")
top.cost = saved
top.rate = 1.5
check(says(Config.auditAcorns(), "tree.rate"), "a rung that does not grow faster is refused")
top.rate = 2.5
GATE.rare.cap = 6
check(says(Config.auditAcorns(), "tree.gate"), "a gate holding less than a commoner one is refused")
GATE.rare.cap = 12
GATE.legendary.maxLevel = 9
check(says(Config.auditAcorns(), "tree.gate"), "a gate unlocking a level that does not exist is refused")
GATE.legendary.maxLevel = 4
Config.TREE_REBIRTH_BONUS.perRebirth = -1
check(says(Config.auditAcorns(), "tree.rebirth"), "a negative rebirth bonus is refused")
Config.TREE_REBIRTH_BONUS.perRebirth = 0.03
check(#Config.auditAcorns() == 0 and #Config.auditEconomy() == 0, "audits clean after the provocations")

-- ---- THE OAK AT ITS BIGGEST STILL CLEARS EVERYTHING -------------------------
local off = Config.ACORNS.treeOffset
local crown, wood = Config.ACORN_OAK_MESH.parts[2], Config.ACORN_OAK_MESH.parts[1]
local s = top.scaleXZ * Config.ACORNS.treeScale
local left = off.X + (crown.offset.X - crown.size.X / 2) * s
local right = off.X + (crown.offset.X + crown.size.X / 2) * s
local front = off.Z + (crown.offset.Z + crown.size.Z / 2) * s
check(Config.PLOT_HALF_WIDTH + left > 4.0, ("level-4 canopy clears the side fence (%.2f)"):format(Config.PLOT_HALF_WIDTH + left))
check(Config.PLOT_FRONT_LINE - front > 6.0, ("level-4 canopy clears the front fence (%.2f)"):format(Config.PLOT_FRONT_LINE - front))
check(right < -19, ("level-4 canopy stays outside the piggy sightline (%.2f)"):format(right))
-- The placeholder grows HEIGHT only, so no horizontal clearance the oak and
-- basket suites measured at level 0 can move.
for level = 0, #LEVELS - 1 do
	check(LEVELS[level + 1].scaleXZ == 1, ("level %d keeps the oak's measured footprint"):format(level))
end
check(top.scaleY > 1 and top.scaleY <= 1.25, "level 4 is visibly taller, and no more than a quarter")
local topY = (crown.offset.Y + crown.size.Y / 2) * top.scaleY * Config.ACORNS.treeScale
check(topY < 12, ("level-4 canopy top at %.2f studs, under the pig's 12"):format(topY))
-- The ripe-acorn display is measured off the collider, which does not move,
-- so it scales its heights by Config.PLOT_TREE_GROWTH_ATTRIBUTE. Scaled, the
-- crop keeps exactly the relation to the canopy bottom it has at level 0.
check(type(Config.PLOT_TREE_GROWTH_ATTRIBUTE) == "string", "the growth factor is published for the client")
local gap0 = (crown.offset.Y - crown.size.Y / 2) - 4.2
local gap4 = (crown.offset.Y - crown.size.Y / 2) * top.scaleY - 4.2 * top.scaleY
check(near(gap4, gap0 * top.scaleY) and math.abs(gap4) < 0.05, ("the scaled crop keeps its place under the canopy (%.3f at level 0, %.3f at level 4)"):format(gap0, gap4))
local _ = wood

-- ---- SAVES ------------------------------------------------------------------
local src = sources.DataService
local transformed, count = src:gsub("return DataService%s*$", "DataService.defaults=defaultData\nDataService.reconcile=reconcile\nreturn DataService\n")
assert(count == 1)
local dsEnv = { game = { JobId = "tree", GetService = function(_, name)
	if name == "ReplicatedStorage" then return { Shared = { Config = "Config" } } end
	return {}
end }, require = function(key) assert(key == "Config"); return Config end,
	task = { wait = function() end }, warn = function() end }
local runDS = assert(loadstring(transformed, "DataService")); setfenv(runDS, setmetatable(dsEnv, { __index = getfenv() }))
local D = runDS()
local fresh = D.defaults()
check(fresh.tree.level == 0, "a new save starts at tree level 0")
local old = D.defaults(); old.tree = nil
check(D.reconcile(old).tree.level == 0, "a save from before the ladder joins at level 0")
local junk = D.defaults(); junk.tree = { level = "big" }
check(D.reconcile(junk).tree.level == 0, "a junk level reconciles to 0")
local high = D.defaults(); high.tree = { level = 7 }
check(D.reconcile(high).tree.level == 4, "an out-of-range level clamps to the top")
local full = D.defaults(); full.treeAcorns = 30
check(D.reconcile(full).treeAcorns == 8, "a Common save's ripe stock clamps to 8")
local rich = D.defaults(); rich.treeAcorns = 30; rich.houses = { owned = { shack = true, void = true }, shown = "void" }
check(D.reconcile(rich).treeAcorns == 24, "a Legendary save keeps up to 24 ripe acorns")

-- ---- BUYING, THROUGH THE REAL SERVICE ------------------------------------------
local data, messages, saves = nil, {}, 0
local plotState = { level = nil, owner = nil }
local prompt = { Enabled = false, ActionText = "", ObjectText = "", attrs = {} }
function prompt:SetAttribute(key, value) self.attrs[key] = value end
local plot = { growPrompt = prompt, owner = nil }
local modules = {
	Config = Config,
	Remotes = { get = function(name)
		return { FireClient = function(_, _, text, kind) table.insert(messages, { name = name, text = text, kind = kind }) end,
			OnServerEvent = { Connect = function() end } }
	end },
	DataService = { get = function() return data end, save = function() saves += 1 end },
	PlotService = {
		getPlot = function() return plot end,
		getAll = function() return { plot } end,
		setTreeLevel = function(_, level) plotState.level = level end,
		setTreeOwner = function(_, owner) plotState.owner = owner end,
		updatePile = function() end,
		publishTree = function(_, d) plotState.published = d end,
	},
}
local tsEnv = { game = { GetService = function(_, name) return if name == "ReplicatedStorage" then { Shared = setmetatable({}, { __index = function(_, k) return k end }) } else {} end },
	script = { Parent = setmetatable({}, { __index = function(_, k) return k end }) },
	require = function(key) return assert(modules[key], key) end }
local runTS = assert(loadstring(sources.TreeService, "TreeService")); setfenv(runTS, setmetatable(tsEnv, { __index = getfenv() }))
local T = runTS()
local player = { UserId = 7 }
local function fresh2(coins, capacityLevel, owned)
	data = D.defaults()
	data.coins = coins
	data.capacityLevel = capacityLevel
	data.houses.owned = owned
	data.acornsGrownAt = os.time()
	messages, saves = {}, 0
end
local function last() return messages[#messages] end

fresh2(1e9, 60, { shack = true })
T.apply(player)
check(plotState.level == 0 and plotState.owner == player, "join draws level 0 and names the owner")
check(prompt.Enabled and prompt.ActionText == "Grow to Lv1" and prompt.attrs[Config.PROMPT_AMOUNT_ATTRIBUTE] == Config.formatCoins(LEVELS[2].cost),
	"the offer names level 1 and its price")
T.buy(player)
check(data.tree.level == 1 and data.coins == 1e9 - LEVELS[2].cost and plotState.level == 1 and saves == 1
	and last().kind == "good", "level 1 bought, charged, drawn, saved and announced")
check(prompt.attrs[Config.PROMPT_AMOUNT_ATTRIBUTE] == "LOCKED" and prompt.ObjectText:find("Rare", 1, true),
	"the next offer says a Rare house is needed")
local before = data.coins
T.buy(player)
check(data.tree.level == 1 and data.coins == before and last().kind == "warn" and last().text:find("Rare", 1, true),
	"level 2 without a Rare house is refused by name, free of charge")
data.houses.owned.mushroom = true
T.refresh(player)
check(prompt.attrs[Config.PROMPT_AMOUNT_ATTRIBUTE] == Config.formatCoins(LEVELS[3].cost), "buying a Rare house reopens the offer")
T.buy(player)
check(data.tree.level == 2, "level 2 bought with a Rare house")
data.houses.owned.slime = true
T.buy(player)
data.houses.owned.void = true
T.buy(player)
check(data.tree.level == 4 and not prompt.Enabled, "level 4 reached and the offer turns off")
T.buy(player)
check(last().text:find("fully grown", 1, true) and data.tree.level == 4, "no rung past 4")

fresh2(10, 60, { shack = true })
T.buy(player)
check(data.tree.level == 0 and data.coins == 10 and last().text:find("need", 1, true), "too few coins: refused, not charged")
fresh2(1e9, 1, { shack = true, void = true })
data.tree.level = 3
T.buy(player)
check(data.tree.level == 3 and data.coins == 1e9 and last().text:find("hold", 1, true), "a price the pig cannot hold: grow-your-pig refusal")

-- The purchase settles growth at the OLD rate before the level changes.
fresh2(1e9, 60, { shack = true })
data.acornsGrownAt = os.time() - 5400
T.buy(player)
check(data.treeAcorns == 1 and data.tree.level == 1, "an hour and a half at level 0 settles one acorn before the purchase")

-- ---- THE NEXT-ACORN CLOCK ------------------------------------------------------
local clockSave = save(0, { shack = true })
clockSave.acornsGrownAt = 1000
check(Config.nextAcornIn(clockSave, 1000 + 600, true) == 3000, "level 0: 50 minutes left after 10")
clockSave.tree.level = 4
check(Config.nextAcornIn(clockSave, 1000 + 600, false) == 3600 / 2.5 - 600, "level 4 offline: the level's own rate")
clockSave.rebirths = 20
check(near(Config.nextAcornIn(clockSave, 1000, true), 3600 / (2.5 * 1.6)), "online rebirth bonus shortens the wait")
clockSave.treeAcorns = 8
check(Config.nextAcornIn(clockSave, 1000, true) == nil, "a full Common tree has no next acorn")
clockSave.houses.owned.void = true
check(Config.nextAcornIn(clockSave, 1000, true) ~= nil, "a Legendary house makes room, so the clock runs again")
check(Config.nextAcornIn({ treeAcorns = 0, acornsGrownAt = 1000 }, 900 + 3600 * 20, false) == 0,
	"a stale cursor never reports a negative wait")
T.refresh(player)
check(plotState.published == data, "a refresh republishes the tree, so a purchase moves the clock")

local tcEnv = { game = { GetService = function(_, name) return if name == "ReplicatedStorage" then { Shared = setmetatable({}, { __index = function(_, k) return k end }) } else {} end },
	require = function(key) return assert(({ Config = Config, Theme = {} })[key], key) end }
local runTC = assert(loadstring(sources.TreeClock, "TreeClock")); setfenv(runTC, setmetatable(tcEnv, { __index = getfenv() }))
local C = runTC()
local spec = C.describe(3, 12, 1000 + 2520, 1000)
check(spec.count == "3/12" and spec.timer == "next 42m" and not spec.full, "3 of 12, next in 42 minutes")
spec = C.describe(3, 12, 1000 + 42, 1000)
check(spec.timer == "next 0:42", "under a minute reads as seconds")
spec = C.describe(12, 12, nil, 1000)
check(spec.full and spec.timer == "FULL" and spec.count == "12/12", "a full tree says FULL")
check(C.describe(0, nil, nil, 1000) == nil, "no cap published: no card")
check(C.describe(nil, 8, 900, 1000).timer == "next 0:00" and C.describe(nil, 8, 900, 1000).count == "0/8",
	"an overdue deadline reads 0:00 until the server's tick lands")
check(C.clockText(3600) == "60m" and C.clockText(61) == "2m" and C.clockText(0.2) == "0:01", "clock rounds up")

print(("PASS: %d tree checks; ladder, house gate and caps, online-only rebirth bonus, audits, saves, purchase path and level-4 clearances."):format(checks))
