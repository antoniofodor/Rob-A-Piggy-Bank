-- Run in Studio's Edit DataModel using execute_luau. Tests fresh synced
-- modules and the actual delivery function with isolated service doubles.
-- No live players, remotes, DataStores or economy state are modified.
local shared = game.ReplicatedStorage.Shared
local configCopy = shared.Config:Clone()
configCopy.Name = "AcornConfigTest"
configCopy.Parent = shared
local harness = Instance.new("ModuleScript")
harness.Name = "AcornDeliveryTest"
harness.Parent = shared
local ok, result = pcall(function()
	local Config = require(configCopy)
	assert(Config.lootWord(1) == "acorn" and Config.lootWord(0) == "acorns")
	assert(Config.ROLL_CURRENCY.colour == require(shared.Theme).ACORN)
	assert(Config.LOOT == nil and Config.REVENGE.loot == nil)
	for _, case in {
		{0, nil, false, 1}, {8, nil, true, 1}, {0, 0, false, 5},
		{8, 1, false, 5}, {2, 8, false, 11}, {2, 8, true, 22}, {3, 3, true, 10},
	} do
		assert(Config.acornMultiplier(case[1], case[2], case[3]) == case[4])
	end
	local source = game.ServerScriptService.Services.HeistService.Source
	local first = assert(source:find("local function deliver(thief: Player)", 1, true))
	local last = assert(source:find("\n-- ============================================================", first, true))
	local deliver = source:sub(first, last - 1)
	local helperFirst = assert(source:find("local function isRevenge(", 1, true))
	local helperLast = assert(source:find("-- [victim][thief] -> os.clock()", helperFirst, true))
	local helpers = source:sub(helperFirst, helperLast - 1)
	assert(not deliver:find("acornMultiplier", 1, true), "piggy delivery calls shake payout")
	harness.Source = [=[
local Config = require(script.Parent.AcornConfigTest)
local function run(kind, revenge, spree)
 local thief = {DisplayName = "Thief", SetAttribute = function() end}
 local victim = {DisplayName = "Victim"}
 local data = {coins = 100, loot = 37, robberies = 0, totalStolen = 0, capacityLevel = 0}
 local victimData = {totalLost = 0}
 local item = {kind = if kind == "shop" then "effect" else "skin", key = "fixture"}
 local carrying = {[thief] = {amount = 100, victim = victim, haul = {item}}}
 local grudge = {[thief] = {[victim] = {expires = if revenge then os.clock() + 60 else 0, skins = {}}}}
 local granted, equipped, payload, toast = nil, nil, nil, nil
 local function clearCarry(player)
  assert(#carrying[player].haul == 0, "delivered haul was returned to victim")
  carrying[player] = nil
 end
 local DataService = {get = function(player) return if player == thief then data else victimData end}
 local function asPlayer(target) return if kind == "player" then target else nil end
 local function targetSkin() return "fixture" end
 local function targetName() return kind end
 local function noop() end
 local SocialService = {
  getSpreeMultiplier = function() return spree end,
  getSpree = function() return 3 end,
  recordSteal = noop, recordWeekly = noop, markRevenge = noop,
 }
 local TrophyService = {recordVictim = noop, recordSpree = noop}
 local PlotService = {getPlot = function() return nil end}
 local SetService = {
  award = function() error("piggy delivery awarded acorns") end,
  grant = function(_, itemKind, key) granted = {kind = itemKind, key = key}; return true end,
 }
 local CosmeticsService = {equipSkin = function(_, key) equipped = key end}
 local Remotes = {get = function(name)
  assert(name == "HeistDelivered")
  return {FireClient = function(_, player, value) assert(player == thief); payload = value end}
 end}
 local format = Config.formatCoins
 local function notify(_, text) toast = text end
 local notifyTarget = noop
]=] .. helpers .. deliver .. [=[
 deliver(thief)
 local expected = math.floor(100 * (if revenge then Config.REVENGE.payout else Config.HEIST_PAYOUT) * spree)
 assert(data.coins == 100 + expected and data.totalStolen == 100, "coin settlement changed")
 assert(data.robberies == 1, "delivery must count one lifetime robbery")
 assert(data.loot == 37, "saved Acorn balance changed")
 assert(granted and granted.key == item.key and granted.kind == item.kind, "haul not granted")
 assert(payload and payload.banked == expected and payload.loot == nil and #payload.items == 1)
 assert(payload.revenge == revenge and payload.items[1].key == item.key)
 if item.kind == "skin" and Config.SKIN_STEAL.wear then assert(equipped == item.key) end
 assert(toast and not toast:lower():find("acorn") and not toast:lower():find("loot"))
 assert(carrying[thief] == nil)
 if kind == "player" then assert(victimData.totalLost == 100) end
end
local count = 0
for _, kind in {"player", "resident", "shop"} do
 for _, revenge in {false, true} do
  for _, spree in {1, 2} do
   run(kind, revenge, spree)
   count += 1
  end
 end
end
return count
]=]
	local count = require(harness)
	return ("PASS: currency names/palette, seven multiplier cases, %d delivery cases (player/resident/shop, revenge, spree). Saves untouched."):format(count)
end)
harness:Destroy()
configCopy:Destroy()
assert(ok, result)
return result
