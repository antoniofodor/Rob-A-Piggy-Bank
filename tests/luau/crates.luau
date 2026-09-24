-- Executes the real Config, the full ChestService and the real ProductService
-- (the ProcessReceipt callback, the receipt ledger and the PolicyService gate)
-- with isolated service doubles. No Studio, no DataStore, no Marketplace.
local Config, sources = ...
local source = sources.ChestService
local checks = 0
local function check(ok, message)
 assert(ok, message);checks += 1
end

-- ============================================================
-- THE PENDING CONFIG BLOCK
-- ============================================================
--
-- The Robux route needs four new things in `Config` and this agent may not
-- write that file: they are reported as OLD/NEW for the lead to apply. This
-- installs them ONLY IF THEY ARE ABSENT, so the suite exercises the code
-- against the Config it will have -- and the day the block lands, every line
-- here is dead and the suite is asserting the SHIPPED values instead.
--
-- It refuses to overwrite anything, which is what keeps it from being the
-- harness-sets-up-the-state-it-measures trap: it cannot mask a real table
-- that disagrees with it, and the last line of this suite prints which mode
-- it ran in.
local pending = {}
-- A crate's Robux price and its developer product live on the crate's OWN ROW,
-- the shape `Config.PASSES` already uses and the shape the Guardian Crate
-- landed in. The ladder below is what a SKIN SHELF's three rungs cost; a crate
-- with a price already is left exactly as it is, so this cannot argue with the
-- Guardian Crate's own 49.
local ROBUX_LADDER = {common=20, rare=60, legendary=240}
for key, chest in Config.CHESTS do
 if chest.kind ~= "set" and chest.robux == nil and ROBUX_LADDER[chest.tier or ""] then
  pending.CHESTS = true
  chest.robux = ROBUX_LADDER[chest.tier]
  chest.productId = chest.productId or 0
  local _ = key
 end
end
if Config.REBIRTH_CRATES_RARE == nil then
 pending.REBIRTH_CRATES_RARE = true
 Config.REBIRTH_CRATES_RARE = {"ograre"}
end
if Config.REBIRTH_LEGENDARY_EVERY == nil then
 pending.REBIRTH_LEGENDARY_EVERY = true
 Config.REBIRTH_LEGENDARY_EVERY = 5
end
-- Day one pays a COMMON crate and day seven a RARE one. Rung one used to pay
-- five minutes of income, which is a thing a new player earns by standing
-- still for five minutes -- and a crate open lands on the permanent cosmetic
-- track, which is the one thing an hour of idling cannot buy.
if Config.DAILY_CYCLE[1].kind ~= "crate" then
 pending.DAILY_CYCLE = true
 Config.DAILY_CYCLE[1] = {kind="crate", crate="og",
  short="CRATE", label="A free OG Piggy crate"}
 Config.DAILY_CYCLE[7] = {kind="crate", crate="ograre",
  short="RARE CRATE", label="A free OG Piggy Rare crate"}
end

-- ============================================================
-- THE PRICE LADDER, WHICH IS SOLVED RATHER THAN PICKED
-- ============================================================
--
-- The coin ladder these crates used to carry was solved on COINS PER
-- LEGENDARY, with a deliberate premium at the top for a route that is nine
-- times faster: 500K / 1.5M / 6.0M, which is 1 : 3 : 12. The Robux ladder
-- holds the same ratio, so the same premium survives -- 1.00 / 1.20 / 1.37 of
-- the entry crate's cost per legendary -- and a tier crate stays worth buying
-- without being strictly better value than the cheap one.
--
-- WITHOUT THIS THE TOP CRATE IS THE CHEAPEST PER LEGENDARY, which is the
-- trap: at a flat-looking 79 / 199 / 449 the legendary crate comes out at
-- 1,283 Robux per legendary against the common crate's 1,975, so nobody would
-- ever buy anything else and the ladder would be decoration.
--
-- ASSERTED ON THE ROWS, NOT ON A LADDER TABLE, because the price lives on the
-- crate. What the ladder was for is this property, and this is the property.
for _, shelf in {{"og","ograre","oglegendary"}} do
 local common, rare, legendary = Config.CHESTS[shelf[1]], Config.CHESTS[shelf[2]], Config.CHESTS[shelf[3]]
 check(rare.robux == common.robux * 3 and legendary.robux == common.robux * 12,
  shelf[1] .. " shelf keeps the coin ladder's 1 : 3 : 12")
 local function perLegendary(chest) return chest.robux / (chest.odds.legendary / 100) end
 check(perLegendary(rare) > perLegendary(common) and perLegendary(legendary) > perLegendary(rare),
  shelf[1] .. " shelf costs MORE per legendary at every rung up, so no crate is strictly better value")
 -- Nothing in this game may cost more in one press than VIP, which is a
 -- permanent entitlement at 249. A single random roll above it is
 -- indefensible for this audience whatever the odds are.
 check(legendary.robux < Config.PASSES.vip.robux,
  shelf[1] .. " shelf's dearest crate stays under the permanent VIP pass")
end
-- ONE PIGGY SHELF (designer, 2026-09-23: "put all common, rare, epic,
-- legendary into one pool"). The themed crates are gone, the crates screen
-- has the piggy shelf and the guardian shelf and nothing else, and every
-- piggy skin a crate can give is tagged to the one family -- so a skin that
-- slipped back onto a retired tag would be unreachable, which this catches.
for _, key in { "animal", "animalrare", "animallegendary", "arcade", "arcadelegendary" } do
 check(Config.CHESTS[key] == nil, key .. " is retired into the piggy crates")
end
do
 local keys = {}
 for _, section in Config.CRATE_SECTIONS do table.insert(keys, section.key) end
 check(#keys == 2 and keys[1] == "og" and keys[2] == "guardian", "the crates screen is the piggy shelf and the guardian shelf")
 local themes = {}
 for _, spec in Config.SKINS do
  if spec.chest ~= nil then
   check(spec.chest == "og", (spec.name or "?") .. " is tagged to the piggy crates")
   themes[spec.collection or spec.chest] = (themes[spec.collection or spec.chest] or 0) + 1
  end
 end
 check((themes.animal or 0) > 0 and (themes.arcade or 0) > 0 and (themes.og or 0) > 0,
  "the three themes survive as collections on the skins")
end

-- EVERY CRATE THAT IS NOT AN EVENT SET CARRIES A PRICE AND A PRODUCT FIELD,
-- which is the rule `auditRandomOutcomes` is asked to keep: a crate with no
-- price is unobtainable except by the free routes, and one with a price and no
-- `productId` field cannot even read COMING SOON.
for key, chest in Config.CHESTS do
 if chest.kind == "set" then
  check(chest.robux == nil, key .. " is an event crate and is never sold")
 else
  check(type(chest.robux) == "number" and chest.robux > 0, key .. " carries a Robux price")
  check(type(chest.productId) == "number", key .. " carries a developer product field")
  check(chest.cost == nil and chest.currency == nil, key .. " carries no in-game price")
 end
end
-- The merged pool: the Piggy Crate reaches every tagged skin, and the rare
-- and legendary crates reach every one of them rare or better -- Arcade's
-- 4/3/3 included, which used to have crates of its own.
do
 local pool, total = Config.chestPool("og")
 local tagged = 0
 for _, spec in Config.SKINS do
  if spec.chest ~= nil and not Config.isEarnedElsewhere(spec) then tagged += 1 end
 end
 check(total == tagged and total > 0, "the Piggy Crate draws on every tagged piggy skin")
 for _, key in { "ograre", "oglegendary" } do
  local tierPool, tierTotal = Config.chestPool(key)
  check(tierTotal == total - #(pool.common or {}), key .. " draws on every piggy skin rare or better")
 end
 for _, key in { "respawn", "jackpot" } do
  check(table.find(Config.chestPool("oglegendary")[Config.rarityOf(Config.SKINS[key])] or {}, key) ~= nil,
   key .. " (Arcade) is in the Legendary Piggy Crate")
 end
end
for _, key in { "respawn", "powerup", "jackpot", "finalboss", "mechaplayer" } do
 check(Config.SKIN_ACCESSORY_MODELS[key] ~= nil and #Config.skinAccessories(key) > 0,
  key .. " has an uploaded model and its accessory parts")
end

local player = {UserId=7, Name="Buyer"}
local data, messages, granted, pushes, randomCalls, repaints, saves
-- The first parameter used to be an Acorn balance. Crates carry no price in
-- any in-game currency, so it is kept and ignored rather than deleted from
-- thirty call sites.
local function reset(_unused, owned)
 data = {coins=1000000000, spares={}, owned=owned or {},
  -- The guardian wardrobe, which is `data.dogs` and not a catalogue
  -- `Config.catalogueFor` answers for -- see `ChestService.ownsEntry`.
  dogs={owned={}, equipped=""}}
 messages, granted, pushes, randomCalls, repaints, saves = {}, {}, 0, 0, 0, 0
end
local Remotes = {get=function(name)
 return {FireClient=function(_, who, payload)
  assert(who == player);messages[name] = payload
 end}
end}
-- THE DOUBLE MIRRORS THE REAL `SetService.ownedTable`, INCLUDING THE ONE KIND
-- THAT DOES NOT LIVE WITH THE OTHERS. A guardian coat is `data.dogs.owned`
-- keyed BARE, where the other six are one flat `kind:key` table this suite has
-- always used -- and a double that lags the thing it doubles reports a live bug
-- that is not there.
local SetService = {
 owns=function(save, kind, key)
  if kind == "coat" then
   return type(save.dogs) == "table" and save.dogs.owned[key] == true
  end
  return save.owned[kind .. ":" .. key] == true
 end,
 grant=function(who, kind, key)
  assert(who == player);table.insert(granted, kind .. ":" .. key)
  if kind == "coat" then data.dogs.owned[key] = true
  else data.owned[kind .. ":" .. key] = true end
  return true
 end,
 inUse=function() return false end,
 -- Fires the registered pusher without granting. Counted rather than ignored,
 -- because the bug it exists for was a repeat piggy written into a slot with
 -- nothing told to repaint it -- so "was anybody told" is the assertion.
 repaint=function(who, kind) assert(who == player);repaints += 1 end,
}
-- NO `CosmeticsService` DOUBLE, AND ITS ABSENCE IS AN ASSERTION. `ChestService`
-- briefly reached that service to grant a coat, on the reasoning that a coat is
-- not in `Config.catalogueFor` and not in a table `SetService` reads. Both
-- stopped being true, so the file requires DataService, SetService and (lazily)
-- ProductService and nothing else -- and a stub here would let a fourth
-- dependency creep back without this suite noticing.
local modules = {Config=Config, Remotes=Remotes,
 DataService={get=function(who) assert(who == player);return data end,
  save=function(who) assert(who == player);saves += 1;return true end},
 SetService=SetService}
local randomValue = 0
local testMath = table.clone(math)
testMath.random = function(low, high)
 randomCalls += 1
 return if low then low else randomValue
end
local run = assert(loadstring(source, "ChestService"))
setfenv(run, setmetatable({
 game={GetService=function(_, name)
  if name == "Players" then return {} end
  assert(name == "ReplicatedStorage")
  return {Shared={Config="Config", Remotes="Remotes"}}
 end},
 script={Parent={DataService="DataService", SetService="SetService",
  ProductService="ProductService"}},
 require=function(key) return assert(modules[key], key) end,
 math=testMath,
}, {__index=getfenv()}))

-- ============================================================
-- THE REAL ProductService, ON STUBBED ENGINE SERVICES
-- ============================================================
--
-- Loaded rather than doubled because the two things worth asserting live in
-- it: a receipt may never pay out twice, and a player the paid random item
-- rule restricts may never be sold anything. A double would assert the
-- double.
local policyAnswer, policyThrows = false, false
local marketplace = {}
local polled = 0
-- The engine's enums as `group.name` STRINGS, so a decision compares equal
-- across two chunks. The bundle's own prelude builds one of these for Config
-- and does not share it, and a per-access table would make every `==` false.
local Enum = setmetatable({}, {__index=function(_, group)
 return setmetatable({}, {__index=function(_, name) return group .. "." .. name end})
end})
local productEnv = {
 Enum=Enum,
 game={GetService=function(_, name)
  if name == "MarketplaceService" then return marketplace end
  if name == "Players" then return {
   GetPlayers=function() return {player} end,
   GetPlayerByUserId=function(_, id) return if id == player.UserId then player else nil end,
   PlayerAdded={Connect=function() end},
   PlayerRemoving={Connect=function() end},
  } end
  if name == "PolicyService" then return {
   GetPolicyInfoForPlayerAsync=function()
    polled += 1
    if policyThrows then error("network") end
    return {ArePaidRandomItemsRestricted=policyAnswer}
   end,
  } end
  assert(name == "ReplicatedStorage")
  return {Shared={Config="Config"}}
 end},
 script={Parent={DataService="DataService"}},
 require=function(key) return assert(modules[key], key) end,
 -- Runs the policy ask inline, so a test can read the answer on the next line
 -- rather than waiting on a scheduler this harness does not have.
 task={spawn=function(fn, ...) fn(...) end},
 warn=function() end,
}
local productRun = assert(loadstring(sources.ProductService, "ProductService"))
setfenv(productRun, setmetatable(productEnv, {__index=getfenv()}))
local ProductService = productRun()
modules.ProductService = ProductService

local ChestService = run()
ChestService.registerBalancePusher(function() pushes += 1 end)

-- FAIL CLOSED IN THE WINDOW BEFORE THE ANSWER LANDS, which is the first thing
-- a card sees on a join: `restricted` reads an unanswered player as restricted,
-- so nothing is offered until the policy call has returned -- and the CARD is
-- told, because "refused rather than meeting a button that does nothing" is
-- the half of that rule people forget.
reset()
ChestService.push(player)
check(messages.ChestState.restricted == true, "a card is restricted until the policy answer lands")
ProductService.askPolicy(player)
check(ProductService.restricted(player) == false, "and permitted once it does")

-- EVERY CRATE, AND NOT ONE OF THEM PRICED. They used to cost 15/45/120
-- acorns; a crate is earned now, so what this list is for is the sweep below.
local prices = {og=0, ograre=0, oglegendary=0}
-- The retired mixed crates stay retired, and every section names real crates.
check(Config.CHESTS.rarecrate==nil and Config.CHESTS.legendarycrate==nil, "mixed tier crates retired")
-- THE ALIEN CACHE WENT WITH THE ALIEN EVENT (designer, 2026-09-23). The chest
-- and its section had to go together: `Shared/Crates` builds the tab from
-- `CRATE_SECTIONS` alone, so a section naming a dead chest is a header over an
-- empty grid. Both halves are asserted, because deleting either one on its own
-- is the failure.
check(Config.CHESTS.alien==nil, "the Alien Cache chest is deleted")
for _, section in Config.CRATE_SECTIONS do
 check(section.key~="alien", "and no section still offers it")
end
-- THE SET IS NOT THE CRATE, which is what made that deletion cheap.
-- `SetService.rollDrop` reads `Config.SETS` and never `Config.CHESTS`, so the
-- raid drop is untouched and turning the event back on restores both items.
check(Config.SETS.alien~=nil and #Config.SETS.alien.items==2, "the alien set survives its crate")
for _, section in Config.CRATE_SECTIONS do
 for _, key in section.chests do check(Config.CHESTS[key] ~= nil, section.name .. " lists " .. key) end
end
-- A tier crate draws only from its own collection, never a common.
for key, shelf in {ograre="og", oglegendary="og"} do
 local pool, total = Config.chestPool(key)
 check(total > 0 and pool.common == nil and #(pool.rare or {}) > 0 and #(pool.legendary or {}) > 0, key .. " stocks rare and legendary only")
 for _, list in pool do for _, skin in list do
  check(Config.SKINS[skin].chest == shelf, key .. " draws only " .. shelf .. " skins")
 end end
end
for key in prices do
 check(Config.CHESTS[key].currency == nil and Config.CHESTS[key].cost == nil, key .. " carries no in-game price")
 reset()
 ChestService.grantFree(player, key)
 check(data.coins == 1000000000, key .. " costs no coins to open")
 check(#granted == 1 and messages.ChestResult ~= nil and pushes == 1, key .. " grants and pushes")
 local info = messages.ChestState.chests[key]
 check(info.cost == nil, key .. " publishes no coin price")
 -- EVERY CRATE LEFT CAN COMBINE. The one exception was the event cache, which
 -- `canCombineChest` refuses by its `kind = "set"`; that crate is deleted and
 -- the refusal is kept for the next one, so this reads true rather than
 -- comparing against the predicate it is meant to be checking.
 check(info.canCombine == true, key .. " combine visibility")
 -- THE ROBUX PRICE AND THE PRODUCT, WHICH ARE WHAT THE CARD DISCLOSES BESIDE
 -- THE ODDS.
 check(info.robux == Config.CHESTS[key].robux, key .. " publishes its own row's Robux price")
 check(info.productId == Config.CHESTS[key].productId, key .. " publishes its own developer product")
 -- THE DISCLOSED ODDS SUM TO 100, which is the paid random item rule's own
 -- wording and is a property of the RENORMALISATION rather than of the table.
 local total = 0
 for _, pct in info.odds do total += pct end
 check(math.abs(total - 100) < 0.001, key .. " discloses odds summing to 100%")
 check(info.complete == false, key .. " is not complete on a fresh save")
 check(info.refusal == nil, key .. " would open")
 check(messages.ChestState.restricted == false, "the policy gate rides the same push")
end
check(ChestService.open == nil, "there is no charged open path")
check(ChestService.openPaid ~= nil and ChestService.rollUp ~= nil, "the paid open and the station's roll are exported")
check(not Config.canCombineChest("missing"), "unknown combine target")

-- ============================================================
-- NO CRATE EVER PAYS A DUPLICATE (designer, 2026-09-23)
-- ============================================================
--
-- AND IT IS A POOL RULE RATHER THAN A PAYOUT RULE, which is what this block
-- asserts: the pool a crate rolls from is filtered to what the player does not
-- own, so the reveal CANNOT land on something already held. This check used to
-- assert the two rules before it -- a repeat skin paid a spare, then a repeat
-- skin landed on a pedestal -- and both were about what to do with an outcome
-- that can no longer happen.
local pool = Config.chestPool("og")
local common = pool.common[1]
check(#pool.common > 1, "the OG shelf stocks more than one common, so a filtered roll has somewhere to land")
reset(nil, {["skin:" .. common]=true})
ChestService.grantFree(player, "og")
check(messages.ChestResult.key ~= common, "the roll skipped the common already owned")
check(messages.ChestResult.tier == "common", "and stayed in the tier the odds rolled")
check(#granted == 1 and not messages.ChestResult.duplicate, "so the open is always something new")
check(next(data.spares) == nil, "and no crate outcome ever writes a spare")
check(repaints == 0, "the repeat-pedestal path is not reached at all")

-- THE UNOWNED POOL IS THE ONE THE CARD DISCLOSES, so the odds a buyer reads
-- are the odds the purchase would really be made at. Owning every common
-- takes that tier OUT of the bar rather than leaving a segment that can never
-- pay.
do
 local owned = {}
 for _, key in pool.common do owned["skin:" .. key] = true end
 reset(nil, owned)
 ChestService.push(player)
 local info = messages.ChestState.chests.og
 check(info.odds.common == nil, "a finished tier is not disclosed")
 check(info.odds.rare ~= nil and math.abs(info.odds.rare + (info.odds.epic or 0) + (info.odds.legendary or 0) - 100) < 0.001,
  "and what is left is renormalised to 100%")
 check(info.owned == #pool.common and info.total > info.owned, "the shelf still counts the whole collection")
 check(info.complete == false, "a part-finished crate is not complete")
end

-- AN EXHAUSTED POOL IS REFUSED BEFORE ANYTHING IS SPENT, WHICH IS THE ONE
-- FAILURE MODE HERE THAT WOULD LOOK LIKE THEFT. Robux may never be taken for
-- a crate with nothing left to hand over, so the refusal has to come before
-- the roll, before the prompt and before the receipt.
do
 local owned = {}
 for _, keys in Config.chestPool("og") do
  for _, key in keys do owned["skin:" .. key] = true end
 end
 reset(nil, owned)
 randomCalls = 0
 local refusal = ChestService.whyCannotOpen(player, "og")
 check(refusal ~= nil and refusal:find("everything", 1, true) ~= nil,
  "a finished collection says so rather than reading as unstocked")
 ChestService.grantFree(player, "og")
 check(randomCalls == 0 and messages.ChestResult == nil and #granted == 0,
  "and nothing is rolled")
 ChestService.push(player)
 check(messages.ChestState.chests.og.complete == true,
  "the card is told COLLECTION COMPLETE as a flag rather than a string to parse")
 check(messages.ChestState.chests.og.refusal == refusal,
  "and the card prints the server's own sentence")
 check(ChestService.openPaid(player, "og") == false,
  "a paid open of a finished crate hands back false so the receipt is not spent")
end

-- A FULL LAWN REFUSES THE WHOLE CRATE, ahead of the roll AND the charge --
-- which is what makes placing the outcome above unconditional rather than a
-- thing that can fail. Without this gate a roll onto a full lawn would have
-- nowhere to put what it rolled.
reset()
for i = 1, Config.PIGGY_LAWN_SLOT_COUNT do
 Config.addPiggy(data, pool.common[math.min(i, #pool.common)], true)
end
check(Config.firstFreePiggySlot(data) == nil, "lawn filled for the test")
randomCalls = 0
ChestService.grantFree(player, "og")
check(randomCalls == 0 and messages.ChestResult == nil, "a full lawn refuses before rolling")
check(messages.Notify == "Your lawn is full. Make room for a piggy before you open a crate.",
 "naming the fix rather than failing silently")
reset()
ChestService.grantFree(player, "og")
check(data.coins == 1000000000 and #granted == 1, "the daily crate opens for nothing")

-- A PRICE PUT BACK ON A CRATE FAILS CLOSED AND IS AUDITED. It would be a paid
-- random item with none of the disclosure that rule demands, so the crate
-- refuses to open rather than quietly charging.
check(#Config.auditRandomOutcomes() == 0, "baseline random-outcome audit")
for _, field in {"currency", "cost"} do
 local chest = Config.CHESTS.og
 chest[field] = if field == "cost" then 15 else "loot"
 reset()
 ChestService.grantFree(player, "og")
 check(#granted == 0 and randomCalls == 0, "a priced crate fails closed: " .. field)
 local problems = Config.auditRandomOutcomes()
 check(#problems == 1 and problems[1]:find("og", 1, true) ~= nil, "audit detects the price: " .. field)
 chest[field] = nil
end

-- ============================================================
-- A ROBUX PURCHASE MAY GRANT AN ITEM, NEVER ITS COIN VALUE
-- ============================================================
--
-- A crate carries a Robux price now, and its drop can be SOLD for coins -- a
-- legendary skin pays 1.0M, and measured across `oglegendary`'s odds an open is
-- worth 450.6K if the drop is sold, which is 1,878 coins per Robux. Read as
-- "Robux buys coins" that breaks CLAUDE.md's rule with one extra step.
--
-- IT DOES NOT, AND THE REASON IS THAT NOTHING IN A CRATE IS ROBUX-EXCLUSIVE.
-- Every item a priced crate can pay is also reachable for nothing -- the day-one
-- and day-seven daily crates, the crate every rebirth opens, a robbery, and the
-- combine station -- so what it sells for is a property of the ITEM and the same
-- by every route. The rule is "grant the ride, never grant what the ride costs",
-- and a crate grants the ride.
--
-- WHAT WOULD BREAK IT IS AN EXCLUSIVE IN A POOL, and that is already
-- impossible rather than merely absent: `robux = true` and `pass` both make
-- `Config.isEarnedElsewhere` true, `Config.chestPool` and
-- `Config.inAnyChestPool` both exclude it, so a Robux-exclusive item can
-- neither be rolled nor sold. That is the guard, it predates this work, and
-- these are the assertions that keep it standing.
do
 for key, chest in Config.CHESTS do
  local pool = Config.chestPool(key)
  for _, keys in pool do
   for _, entry in keys do
    local kind, itemKey = Config.chestEntry(key, entry)
    local spec = Config.getSetItem(kind, itemKey)
    check(spec ~= nil, key .. " pool entry " .. entry .. " resolves to a catalogue row")
    check(spec.robux ~= true, entry .. " is Robux-exclusive and may not be in " .. key)
    check(spec.pass == nil, entry .. " is pass-exclusive and may not be in " .. key)
   end
  end
 end
 -- AND EVERY SKIN A PRICED CRATE CAN PAY IS REACHABLE WITHOUT PAYING, which
 -- is what makes the sentence above true rather than merely plausible. The
 -- route is ROBBERY and it needs nobody to have bought one first: residents
 -- and wild piggies wear skins drawn from the catalogue, `isStealableSkin` is
 -- exactly the set that can be taken off one, and the combine station climbs
 -- into the same pools. The daily and rebirth crates are a second route on
 -- the shelves they name.
 for key, chest in Config.CHESTS do
  if (chest.robux or 0) > 0 and chest.kind == "skin" then
   for _, keys in Config.chestPool(key) do
    for _, skin in keys do
     check(Config.isStealableSkin(skin),
      skin .. " is sold in " .. key .. " for Robux, so it has to be stealable too")
    end
   end
  end
 end

 -- THE GUARDIAN CRATE'S COATS HAVE NO COIN VALUE, AND THAT IS ASSERTED NOW.
 -- This was a printed measurement while it was a designer call: a Robux
 -- crate whose drop sold for coins was a route from Robux to coins, and the
 -- only thing that ever defended it was a free rebirth route to the crate,
 -- which came off on 2026-09-23. The call has been made -- "guardians are not
 -- sellable. they are collection items" -- so every coat the crate can give
 -- must be refused by the sell guard AND worth nothing to every reader of
 -- `sellValue`, several of which never ask `isSellable` first.
 local coatCount = 0
 for _, keys in Config.chestPool("guardian") do
  for _, coat in keys do
   coatCount += 1
   check(Config.sellValue("coat", coat) == 0, coat .. " (a Guardian Crate coat) has no coin value")
   check(not Config.isSellable("coat", coat), coat .. " (a Guardian Crate coat) cannot be sold")
  end
 end
 check(coatCount > 0, "the Guardian Crate stocks coats to check")
 for key in Config.DOG_COATS do
  check(Config.sellValue("coat", key) == 0 and not Config.isSellable("coat", key),
   key .. " is a collection item: no guardian is ever sold, crated or not")
 end
end

-- ============================================================
-- THE GUARDIAN CRATE: `kind = "coat"`
-- ============================================================
--
-- AND IT NEEDED NOTHING IN `ChestService`, WHICH IS WHAT THIS BLOCK ASSERTS.
-- The support briefly lived here -- a coat pool, a coat ownership test, a coat
-- spec lookup and a coat grant path -- and all four went the day
-- `Config.catalogueFor` answered `coat`, `Config.chestPool` grew a coat branch
-- and `SetService.ownedTable` learned `data.dogs.owned`. So what is asserted is
-- that a coat crate travels every path a skin crate does with no branch of its
-- own.
do
 local guardian = Config.CHESTS.guardian
 check(guardian ~= nil and guardian.kind == "coat", "the Guardian Crate is a coat crate")
 check(guardian.cost == nil and guardian.robux ~= nil, "bought with Robux and never with coins")

 local pool, total = Config.chestPool("guardian")
 check(total > 0, "and it is stocked")
 local inPool = {}
 for _, keys in pool do for _, key in keys do inPool[key] = true end end
 -- EVERY EXCLUSION IS THE DESIGN. A coat carrying `unlockRebirths` is ON SALE
 -- at that rebirth, so a crate that could roll one would put a shop item
 -- behind luck; `free` is the breed's own colours and is not a prize.
 for key, spec in Config.DOG_COATS do
  if spec.unlockRebirths ~= nil then
   check(not inPool[key], key .. " is on sale at a rebirth and is never rolled")
  end
  if spec.free == true then
   check(not inPool[key], key .. " is the breed's own colours, not a prize")
  end
 end

 reset()
 local tier, kind, key = ChestService.grantFree(player, "guardian")
 check(kind == "coat" and inPool[key] == true, "a rolled coat comes out of the guardian pool")
 check(data.dogs.owned[key] == true, "and lands in the guardian wardrobe rather than a cosmetics table")
 check(#granted == 1 and granted[1] == "coat:" .. key, "through the one grant path every kind uses")
 check(messages.ChestResult.kind == "coat" and messages.ChestResult.tier == tier,
  "and the reveal names it as a coat")
 check(next(data.spares) == nil, "a coat never becomes a spare")

 -- Own the lot, and the crate refuses rather than repeating.
 reset()
 for pooled in inPool do data.dogs.owned[pooled] = true end
 randomCalls = 0
 ChestService.grantFree(player, "guardian")
 check(randomCalls == 0 and messages.Notify:find("everything", 1, true) ~= nil,
  "a finished guardian crate refuses out loud")

 -- ---- rollUp: the combine station's route in -------------------------
 --
 -- IT CONSUMES NOTHING AND CHARGES NOTHING, which is its whole contract: the
 -- caller takes the player's inputs only on a non-nil answer.
 reset()
 randomValue = 0.999 -- three tiers of climb
 local upKind, upKey, upTier = ChestService.rollUp(player, "common", "coat")
 check(upKind == "coat" and inPool[upKey] == true, "rollUp draws from the coat pool")
 check(Config.rarityRank(upTier) > Config.rarityRank("common"), "and lands above the tier it climbed from")
 check(data.dogs.owned[upKey] == true, "granting what it rolled")
 check(data.coins == 1000000000 and next(data.spares) == nil,
  "rollUp spends nothing: the station consumes its own inputs")

 reset()
 for pooled in inPool do data.dogs.owned[pooled] = true end
 check(ChestService.rollUp(player, "common", "coat") == nil,
  "with every coat owned it hands back nil rather than a repeat")
 check(messages.Notify:find("above common", 1, true) ~= nil, "and says what ran out")
end

-- ROLLING UP A SKIN NEVER RETURNS SOMETHING ALREADY OWNED, which is the same
-- unowned-pool rule the crates keep -- and it pools across EVERY collection,
-- because a spare is pooled by tier regardless of the shelf it came from.
do
 reset()
 randomValue = 0.999
 local seen = {}
 for _ = 1, 4 do
  local kind, key, tier = ChestService.rollUp(player, "common", "skin")
  if key then
   check(kind == "skin" and seen[key] == nil, "rollUp never returns a key it has already handed over")
   check(Config.rarityRank(tier) > Config.rarityRank("common"), "and always lands above the tier it climbed from")
   seen[key] = true
  end
 end
 check(next(seen) ~= nil, "at least one skin was rolled up")
 check(ChestService.rollUp(player, "common", "effect") == nil, "rollUp answers for skins and coats only")
 check(ChestService.rollUp(player, "nonsense", "skin") == nil, "an unknown tier is harmless")
end

-- ============================================================
-- THE RECEIPT: PAID ONCE, AND NEVER FOR NOTHING
-- ============================================================
do
 policyAnswer, policyThrows = false, false
 ProductService.onCrateReceipt(ChestService.openPaid)
 ProductService.start()
 check(type(marketplace.ProcessReceipt) == "function", "the one ProcessReceipt callback is set")

 -- The product id is 0 until the Creator Dashboard has one, so the card
 -- declines to prompt. A receipt naming a product nothing knows about is left
 -- PENDING rather than swallowed: a newer server may know it, and swallowing
 -- is the one outcome that loses somebody's money.
 reset()
 local unknown = marketplace.ProcessReceipt({PlayerId=player.UserId, ProductId=4242, PurchaseId="p0"})
 check(unknown == Enum.ProductPurchaseDecision.NotProcessedYet, "an unknown product is left pending")
 check(#granted == 0, "and opens nothing")

 -- With a real id the receipt opens the crate exactly once.
 Config.CHESTS.og.productId = 999001
 reset()
 local first = marketplace.ProcessReceipt({PlayerId=player.UserId, ProductId=999001, PurchaseId="p1"})
 check(first == Enum.ProductPurchaseDecision.PurchaseGranted, "a paid crate is granted")
 check(#granted == 1 and messages.ChestResult ~= nil, "and opens one crate")
 check(table.find(data.receipts, "p1") ~= nil, "the purchase id is recorded in the save")
 local repeated = marketplace.ProcessReceipt({PlayerId=player.UserId, ProductId=999001, PurchaseId="p1"})
 check(repeated == Enum.ProductPurchaseDecision.PurchaseGranted, "a re-delivered receipt is granted rather than retried forever")
 check(#granted == 1, "and never pays out twice")

 -- A REFUSED CRATE MUST NOT EAT THE PURCHASE. A full lawn is the one a player
 -- meets, and it is fixable in ten seconds -- so the receipt is un-recorded
 -- and left pending, and the crate arrives once there is room.
 reset()
 for i = 1, Config.PIGGY_LAWN_SLOT_COUNT do
  Config.addPiggy(data, pool.common[math.min(i, #pool.common)], true)
 end
 local refused = marketplace.ProcessReceipt({PlayerId=player.UserId, ProductId=999001, PurchaseId="p2"})
 check(refused == Enum.ProductPurchaseDecision.NotProcessedYet, "a refused crate leaves the receipt pending")
 check(table.find(data.receipts, "p2") == nil, "and forgets the purchase id, so it can be fulfilled later")
 check(#granted == 0, "and hands over nothing")

 -- A RESTRICTED PLAYER'S CRATE RECEIPT IS NEVER GRANTED. The card refuses to
 -- prompt them, so this is the backstop for the prompt they reach anyway --
 -- a client calling `PromptProductPurchase` itself. The harness resolves one
 -- player, so a second is swapped in: never asked about, which fails closed,
 -- and then asked and answered RESTRICTED, which is the case the rule names.
 do
  local buyer = player
  player = {UserId=77, Name="Restricted"}
  reset()
  local unasked = marketplace.ProcessReceipt({PlayerId=77, ProductId=999001, PurchaseId="r1"})
  check(unasked == Enum.ProductPurchaseDecision.NotProcessedYet and #granted == 0,
   "a crate receipt from a player whose policy is unknown opens nothing")
  policyAnswer = true
  ProductService.askPolicy(player)
  check(ProductService.restricted(player), "the second player is answered restricted")
  local refusedR = marketplace.ProcessReceipt({PlayerId=77, ProductId=999001, PurchaseId="r2"})
  check(refusedR == Enum.ProductPurchaseDecision.NotProcessedYet, "a restricted player's crate receipt is left pending")
  check(#granted == 0 and messages.ChestResult == nil, "and no paid random item is handed over")
  check(table.find(data.receipts or {}, "r2") == nil, "and the purchase is not recorded as paid out")
  policyAnswer = false
  player = buyer
 end

 -- A player who has left is pending too, which is what makes a receipt
 -- survive a disconnect.
 check(marketplace.ProcessReceipt({PlayerId=999, ProductId=999001, PurchaseId="p3"})
  == Enum.ProductPurchaseDecision.NotProcessedYet, "a receipt for an absent player waits")
 Config.CHESTS.og.productId = 0
end

-- ============================================================
-- THE POLICY GATE
-- ============================================================
--
-- FAIL CLOSED, WHICH INVERTS `PassService`. That file's rule is that a failed
-- ownership check is not a "no", because writing false takes a paid feature
-- away from somebody who owns it. This is the other question: the answer
-- decides whether a REGULATED purchase may be offered at all, so an
-- unanswered ask must never read as permission.
do
 ProductService.onPolicy(function() end)
 local other = {UserId=8, Name="Unasked"}
 check(ProductService.restricted(other) == true, "a player nobody has asked about is restricted")

 policyAnswer, policyThrows = true, false
 local strict = {UserId=9, Name="Strict"}
 ProductService.askPolicy(strict)
 check(ProductService.restricted(strict) == true, "a restricted player stays restricted")

 policyAnswer, policyThrows = false, true
 local blipped = {UserId=10, Name="Blipped"}
 ProductService.askPolicy(blipped)
 check(ProductService.restricted(blipped) == true, "a failed lookup is NOT permission")
 policyThrows = false
 local before = polled
 ProductService.askPolicy(blipped)
 check(polled == before + 1 and ProductService.restricted(blipped) == false,
  "and the next ask retries rather than caching the failure")
 local cached = polled
 ProductService.askPolicy(blipped)
 check(polled == cached, "an answered ask is memoised, so a HUD push is not a web call")

 -- THE CARD IS TOLD, and that is asserted up at the top of this suite where
 -- `player` had not been asked about yet -- an answered ask is memoised, so
 -- there is no way to make this one restricted again without a second player,
 -- and `push` is wired to exactly one.
 check(ProductService.restricted(player) == false, "the asked player stays permitted")
 policyAnswer = false
end

-- Exercise the existing legendary jump: every regular crate has this stock.
-- This checks eligibility/atomic spending, not the unchanged combine odds.
randomValue = 0.999
for key in prices do
 reset(0)
 local entry = "skin:" .. common
 data.spares[entry] = Config.COMBINE.need
 ChestService.combine(player, "common", key)
 check(data.spares[entry] == nil and #granted == 1, key .. " regular combine still works")
 check(messages.ChestResult.combined == true, key .. " combine reveal")
 check(messages.ChestResult.duplicate == false, key .. " combine never pays a duplicate either")
 check(data.coins == 1000000000, key .. " combine only spends spares")
end
-- THE SERVER SIDE OF COMBINING IS UNTOUCHED, which is what the physical
-- station on the street calls. The UI left the crates tab; these three did
-- not.
check(ChestService.combine ~= nil and Config.COMBINE.need == 3, "the combine path and its cost survive the UI move")
reset()
ChestService.grantFree(player, "unknown")
check(#granted == 0 and next(messages) == nil, "unknown key is harmless")
check(#Config.auditEconomy() == 0 and #Config.auditRandomOutcomes() == 0, "audits restored after mutation tests")

-- ============================================================
-- THE DAILY LADDER'S TWO CRATE RUNGS
-- ============================================================
--
-- Day one a COMMON and day seven a RARE (designer, 2026-09-23), which are the
-- one thing on that ladder an hour of play cannot buy. Asserted against the
-- shipped `Config.DAILY_CYCLE` rather than against the service, because the
-- rungs are the decision and `DailyService`'s `crate` branch already paid out
-- one of them.
do
 local rungs = {}
 for i, rung in Config.DAILY_CYCLE do
  if rung.kind == "crate" then rungs[i] = rung.crate end
 end
 check(rungs[1] ~= nil and Config.CHESTS[rungs[1]] ~= nil, "day one pays a real crate")
 check(rungs[7] ~= nil and Config.CHESTS[rungs[7]] ~= nil, "day seven pays a real crate")
 check(Config.CHESTS[rungs[1]].tier == "common", "day one is the common rung")
 check(Config.CHESTS[rungs[7]].tier == "rare", "day seven is the rare rung")
 -- EARNED RATHER THAN SOLD IS THE POINT OF THEM, so neither rung may name a
 -- crate that has stopped being openable for nothing.
 for _, key in rungs do
  check(Config.CHESTS[key].cost == nil and Config.CHESTS[key].currency == nil,
   key .. " on the ladder carries no in-game price")
 end
end

local shimmed = {}
for key in pending do table.insert(shimmed, key) end
table.sort(shimmed)
print(("PASS: %d crate checks; the Robux ladder, disclosed odds, unowned-only pools, "
 .. "refusal before charge, receipt idempotency, the policy gate, guardian coats, "
 .. "rollUp and the daily rungs. No player saves.%s"):format(checks,
 if #shimmed > 0 then "\n      NOTE: pending Config applied by the harness: " .. table.concat(shimmed, ", ")
 else ""))
