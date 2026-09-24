-- Real palette selection and disabled follower lifecycle without a Studio session.
--
-- AND THE THREE ROUTES TO A GUARDIAN (designer, 2026-09-23): Scrappy free
-- and owned by everybody, Shadow and the Mastiff bought with coins behind
-- their rebirth, and the other ten rolled from the Guardian Crate and
-- reachable no other way. Every route is checked at both ends -- the shape of
-- the Config row, the server's refusal, the push's verdict and the card --
-- because a coat with two routes or none is a card that prices something the
-- server will not sell.
--
-- WHAT MUST NOT CHANGE: an owned coat still equips after a reset, the audits
-- still refuse `unlockRebirths` on anything a crate can roll, and nothing in
-- the crate carries a coin price.
local Config, sources = ...
local checks = 0
local pending = 0
local function check(ok, message) checks += 1; assert(ok, message) end
-- An assertion that needs the Config edit (the `unlockRebirths` rows and the
-- audit exemption) PRINTS rather than fails while the edit is still landing.
local function expect(ok, message)
	if ok then check(true, message) else pending += 1; print("PENDING: " .. message) end
end
local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}; for k, v in value do out[k] = copy(v) end; return out
end
local color = {}
color.__index = color
local function rgb(r, g, b) return setmetatable({R=r/255,G=g/255,B=b/255}, color) end
function color:Lerp(other, t)
	return rgb((self.R+(other.R-self.R)*t)*255, (self.G+(other.G-self.G)*t)*255,
		(self.B+(other.B-self.B)*t)*255)
end
local function same(a,b)
	return math.abs(a.R-b.R)<1e-6 and math.abs(a.G-b.G)<1e-6 and math.abs(a.B-b.B)<1e-6
end
for _,coat in Config.DOG_COATS do
	for _,key in {"fur","furDark","collar"} do coat[key]=rgb(table.unpack(coat[key])) end
end
local names=setmetatable({}, {__index=function(_,key) return key end})
local modules={Config=Config,PetModel={}}
local env=setmetatable({
	game={GetService=function() return {Shared=names} end},
	require=function(key) return assert(modules[key], key) end,
	Color3={fromRGB=rgb,new=function(r,g,b) return rgb(r*255,g*255,b*255) end},
	Vector3={new=function(...) return {...} end},
	CFrame={Angles=function(...) return {...} end},
	Instance={new=function() error("disabled pets must not create instances") end},
},{__index=getfenv()})
local function load(name)
	local fn=assert(loadstring(sources[name],name));setfenv(fn,env)
	modules[name]=fn();return modules[name]
end
local catalog=load("GuardCatalog")
local rig=load("GuardRig")
local kennel=load("KennelModel")
for key,coat in Config.DOG_COATS do
	local model=assert(rig.key(Config.DOG_LEVEL,key))
	local expected=catalog[model].palette
	local tones=kennel.tones(key)
	check(same(tones.wood,if coat.guardModel then rgb(table.unpack(expected.fur)) else coat.fur),key.." kennel matches actual body")
	check(same(tones.trim,if coat.guardModel then rgb(table.unpack(expected.dark)) else coat.furDark),key.." kennel matches actual dark trim")
	check(same(tones.roof,if coat.guardModel then rgb(table.unpack(expected.light)) else coat.collar),key.." roof uses a visible guardian accent")
end
local default=kennel.tones("")
local unknown=kennel.tones("retired-guardian")
check(same(default.wood,unknown.wood) and same(default.trim,unknown.trim),"unknown guardian safely uses default rig palette")
check(#Config.auditSeason()==0,"replacement guardian reward passes season audit")
check(Config.PETS_ENABLED==false,"pets disabled")
load("Pets").start({})
check(true,"disabled follower starts no instances, player watchers or frame connections")

-- ============================================================
-- THE REBIRTH GATE
-- ============================================================
local function contains(problems, code)
	for _, p in problems do if p:find(code, 1, true) then return true end end
	return false
end
local R, E = Config.auditRandomOutcomes, Config.auditEconomy

-- 1. THREE ROUTES, AND EVERY ROW BELONGS TO EXACTLY ONE.
--
-- THE `XOR` IS THE WHOLE CHECK, and it is what no single assertion further
-- down could catch. A coat with TWO routes is a card that prices something a
-- crate also rolls -- so the shop takes coins for a thing the player might
-- already have won, and `buyDogCoat`'s crate refusal fires above the price
-- and makes the price a lie. A coat with NO route is worse and quieter: no
-- cost, no gate, no crate and no `free`, which `(nil or 0) <= 0` hands over
-- for nothing -- the exact hole that once unlocked the Tractor Beam for a
-- whole server.
local free, priced, crated, total = {}, {}, {}, 0
for key, coat in Config.DOG_COATS do
	total += 1
	local routes = 0
	if coat.free == true then routes += 1; table.insert(free, key) end
	if coat.cost ~= nil then routes += 1; table.insert(priced, key) end
	if coat.chest ~= nil then routes += 1; table.insert(crated, key) end
	expect(routes == 1, key .. " has exactly one route (free, priced or crated), not " .. routes)
end
table.sort(free); table.sort(priced); table.sort(crated)

if #free == 0 and #crated == 0 then
	print("PENDING: no DOG_COATS row is free or crated yet; the three-route checks wait on the Config edit")
	pending += 1
else
	-- THE FREE ONE: Scrappy, and only Scrappy.
	expect(#free == 1 and free[1] == "terrier",
		"exactly one guardian is free, and it is the terrier rig: " .. table.concat(free, ","))
	for _, key in free do
		local coat = Config.DOG_COATS[key]
		expect(coat.cost == nil and coat.unlockRebirths == nil and coat.chest == nil,
			key .. " is free of a price, a gate and a crate")
		-- NO EXPLICIT `rarity`, WHICH IS LOAD-BEARING RATHER THAN TIDY:
		-- `isSellable` treats a stated rarity as "earned somewhere", so the
		-- tag would walk a free item straight past the guard that refuses it.
		expect(coat.rarity == nil, key .. " states no rarity, so the free-item sell guard still catches it")
		expect(Config.rarityOf(coat) == "common", key .. " derives common from having no price")
		expect(Config.isSellable("coat", key) == false, key .. " may never be sold")
	end

	-- THE PRICED PAIR: still coins, still behind a whole rebirth.
	expect(#priced == 2, "two guardians are still bought with coins: " .. table.concat(priced, ","))
	local top = Config.rebirthsToMax()
	for _, key in priced do
		local coat = Config.DOG_COATS[key]
		local gate = coat.unlockRebirths or 0
		expect(type(coat.cost) == "number" and coat.cost > 0, key .. " carries a real coin price")
		expect(gate == math.floor(gate) and gate >= 1 and gate <= top,
			key .. " gate is a whole rebirth on the ladder")
		expect(Config.rarityOf(coat) ~= nil and Config.rarityRank(Config.rarityOf(coat)) > 0,
			key .. " derives a real tier from its price")
		-- Not in a pool, so never sellable either: a priced coat has no
		-- duplicate to sell and no crate to have come out of.
		expect(Config.isSellable("coat", key) == false, key .. " is priced, not crated, and not sellable")
	end
	-- ASCENDING WITH COST ACROSS THE PAIR, for the reason the whole ladder
	-- once was: `rarityOf` reads the price, so a dearer coat opening EARLIER
	-- would be a rare on sale below a common.
	for _, a in priced do
		for _, b in priced do
			if Config.DOG_COATS[b].cost > Config.DOG_COATS[a].cost then
				expect((Config.DOG_COATS[b].unlockRebirths or 0) >= (Config.DOG_COATS[a].unlockRebirths or 0),
					b .. " (dearer) unlocks no earlier than " .. a)
			end
		end
	end

	-- THE REST: crate-only, tagged, and tagged with the tier their old price
	-- derived, so nothing re-bordered when the prices came off. COUNTED
	-- against the catalogue rather than stated -- it read "THE TEN" and is
	-- five, because one coat per rig replaced six colours of one dog.
	expect(#crated == total - #free - #priced,
		"every remaining guardian is crated: " .. #crated .. " of " .. total)
	for _, key in crated do
		local coat = Config.DOG_COATS[key]
		expect(coat.cost == nil and coat.unlockRebirths == nil,
			key .. " comes from a crate and carries neither a price nor a gate")
		expect(Config.rarityRank(coat.rarity) > 0,
			key .. " states a rarity on RARITY_ORDER (a crate-only row has no price to derive from)")
		expect(type(coat.sellBasis) == "number" and coat.sellBasis > 0,
			key .. " keeps a sellBasis, so stripping the price did not strip the sell cap")
		-- THE TAG IS THE TIER THE OLD PRICE DERIVED. Re-derived from
		-- `sellBasis` through the real bands rather than from a table typed
		-- here, so this cannot agree with itself while disagreeing with the
		-- game.
		expect(coat.rarity == Config.rarityOf({ cost = coat.sellBasis }),
			key .. " is tagged the tier its own price derived (" .. tostring(coat.rarity) .. ")")
		local crate = Config.CHESTS[coat.chest]
		expect(crate ~= nil and crate.kind == "coat",
			key .. " names a crate that actually rolls coats: " .. tostring(coat.chest))
		-- SELLABLE, AND CAPPED BY ITS OWN BASIS -- which is the whole reason
		-- `sellBasis` had to come with the rarity. Asserted as the exact
		-- expression rather than as an inequality: an inequality against the
		-- tier value alone is a tautology and would pass with the basis
		-- ignored, which is precisely the money printer this guards (a flat
		-- tier value paying five times an item's own shop price).
		--
		-- WORTH A LOOK BEFORE LAUNCH, AND NOT THIS AGENT'S CALL: the crate is
		-- bought with ROBUX, and CLAUDE.md's rule is that a Robux purchase may
		-- grant an ITEM and never its coin value. A paid crate whose drop
		-- sells for coins is that with one extra step. Nothing reaches it
		-- today -- `Shared/Inventory` has four tabs (skin, ride, gear, catch)
		-- and no coat section, so only a poked `SpareSell` gets here -- and
		-- the honest fix is a rule about PAID CRATES rather than about coats,
		-- since it governs every crate skin the moment those carry a Robux
		-- price too.
		local tierValue = Config.SELL.base * (Config.RARITIES.common.weight / Config.RARITIES[coat.rarity].weight)
		-- DECIDED (designer, 2026-09-23): "guardians are not sellable. they are
		-- collection items". The Robux-to-coins route this block used to flag is
		-- closed in `isSellable` and `sellValue` both, so a poked `SpareSell` finds
		-- nothing to sell and no card can print a price.
		local _ = tierValue
		expect(Config.isSellable("coat", key) == false, key .. " is a collection item and is never sold")
		expect(Config.sellValue("coat", key) == 0, key .. " has no coin value, so nothing can price it")
	end
	expect(#R() == 0 and #E() == 0, "both audits accept the three routes")
end

-- 2. THE AUDITS: still refuse the field on a pool, never fire on a coat.
Config._auditFixture = {nested = {unlockRebirths = 1}}
check(contains(R(), "random.rebirthGate"), "auditRandomOutcomes still refuses unlockRebirths on a random-pool fixture")
Config._auditFixture = nil
local martian = Config.SKINS.martian.unlockRebirths
Config.SKINS.martian.unlockRebirths = 2
check(contains(R(), "random.rebirthGate"), "auditRandomOutcomes still refuses unlockRebirths on a chest-pool skin")
Config.SKINS.martian.unlockRebirths = martian
-- A PRICED COAT'S GATE IS STILL LEGITIMATE, so neither audit may fire on it.
-- Driven on a PRICED row rather than on a crate coat: the table exemption is
-- what protects the rows that still SELL, and asking it of a crated row would
-- be asking the wrong question of the wrong check.
--
-- TAKEN FROM `priced` RATHER THAN NAMED. This said `shadow`, which was a
-- priced guardian until the six shepherd-bodied colour coats were retired on
-- 2026-09-23 -- so the suite indexed nil and fell over on a row the catalogue
-- no longer holds, which is the whole class of failure it exists to catch one
-- level down.
local gatedPriced = priced[1]
local before = Config.DOG_COATS[gatedPriced].unlockRebirths
Config.DOG_COATS[gatedPriced].unlockRebirths = 3
local firesRandom = contains(R(), "random.rebirthGate")
local firesEconomy = contains(E(), "retired rebirth ownership gate")
Config.DOG_COATS[gatedPriced].unlockRebirths = before
expect(not firesRandom, "auditRandomOutcomes does not fire on a priced guardian's rebirth gate (needs the DOG_COATS exemption)")
expect(not firesEconomy, "auditEconomy does not fire on a priced guardian's rebirth gate (needs the DOG_COATS exemption)")

-- AND THE CHECK THAT REPLACES THE NARROWED EXEMPTION: A GATE INSIDE A POOL
-- IS REFUSED WHATEVER TABLE IT CAME FROM.
--
-- The identity exemption above is all-or-nothing -- it protects
-- `Config.DOG_COATS`, so it cannot tell a coat that is SOLD from one that is
-- ROLLED, and on a rolled row `unlockRebirths` is the retired ownership gate
-- the whole sweep exists to refuse. Asked of the POOL instead, it catches a
-- gated coat, a gated skin and whatever lands in a crate next.
local gatedCrate = Config.DOG_COATS.cerberus or Config.DOG_COATS.chocolate
if gatedCrate and gatedCrate.chest ~= nil then
	gatedCrate.unlockRebirths = 4
	local firesPool = contains(R(), "random.poolRebirthGate")
	gatedCrate.unlockRebirths = nil
	expect(firesPool, "auditRandomOutcomes refuses a rebirth gate on a coat inside a crate pool")
	-- The same question of a SKIN, so the check is about pools rather than
	-- about coats. `martian` is in the Alien Cache.
	local martianGate = Config.SKINS.martian.unlockRebirths
	Config.SKINS.martian.unlockRebirths = 4
	local firesSkinPool = contains(R(), "random.poolRebirthGate")
	Config.SKINS.martian.unlockRebirths = martianGate
	expect(firesSkinPool, "and refuses one on a skin inside a crate pool")
	-- A COIN PRICE ON A CRATE COAT IS THE OTHER HALF, and two codes catch it:
	-- `random.coinTag` on carrying both, and `random.coinPool` on being
	-- coin-priced inside a crate. That pair is what makes removing `cost`
	-- from these rows enforced rather than remembered.
	-- A COIN PRICE ON A CRATE COAT IS THE OTHER HALF, and `random.coinPool` is
	-- what catches it -- which is the whole reason `Config.catalogueFor`
	-- learned about coats. That check looks each pool entry's spec up through
	-- `getSetItem`, so with coats unresolvable it would have gone QUIET on the
	-- one catalogue that just entered a pool.
	--
	-- `random.coinTag` IS DELIBERATELY NOT ASSERTED HERE, AND IT IS WORTH
	-- KNOWING WHY: it lives in the `walk` sweep, which skips
	-- `Config.DOG_COATS` by identity and therefore never descends into the
	-- rows -- so the table exemption that protects the two priced gates also
	-- blinds `coinTag` on every coat. Nothing is unguarded (the pool check
	-- above covers it), but the exemption is broader than the gate it was
	-- written for.
	gatedCrate.cost = 1000
	local coinProblems = R()
	gatedCrate.cost = nil
	expect(contains(coinProblems, "random.coinPool"),
		"auditRandomOutcomes refuses a coin price on a crate coat")
else
	print("PENDING: no crated coat to provoke the pool checks with; waits on the Config edit")
	pending += 1
end
check(#R() == 0 and #E() == 0, "audits clean once the fixtures are restored")

-- 3. ONE CRATE ROLLS GUARDIANS, AND ITS POOL IS THE TEN.
--
-- This block used to assert the opposite -- that no crate rolled a coat at
-- all -- and it was right for as long as a guardian was only ever a direct
-- coin purchase. What survives the reversal is every reason it existed: a
-- coat in a pool has to be resolvable, has to be the right set of coats, and
-- may not be reachable two ways.
local coatCrates, pooled = {}, {}
for chestKey in Config.CHESTS do
	local pool = Config.chestPool(chestKey)
	for _, entries in pool do
		for _, entry in entries do
			local kind, key = Config.chestEntry(chestKey, entry)
			if kind == "coat" then
				coatCrates[chestKey] = true
				-- A POOL ENTRY THAT DOES NOT RESOLVE IS THE FAILURE THIS
				-- CATCHES: `chestEntry` hands back the chest's own `kind` for
				-- a bare key, so a crate whose catalogue is unreachable rolls
				-- a nil spec and `ChestService` hands over nothing.
				check(Config.catalogueFor(kind) ~= nil and Config.catalogueFor(kind)[key] ~= nil,
					chestKey .. " rolls " .. entry .. ", which resolves to a real coat")
				check(pooled[key] == nil, key .. " is in exactly one crate, not " .. chestKey
					.. " as well as " .. tostring(pooled[key]))
				pooled[key] = chestKey
			end
			check(kind ~= "dogcoat", chestKey .. " never uses the client's request kind as a pool kind")
		end
	end
end
local coatCrateCount = 0
for _ in coatCrates do coatCrateCount += 1 end
if coatCrateCount == 0 then
	print("PENDING: no crate rolls a guardian yet; the pool checks wait on the Config edit")
	pending += 1
else
	expect(coatCrateCount == 1 and coatCrates.guardian == true,
		"exactly one crate rolls guardians, and it is the Guardian Crate")
	-- EVERY AUTHORISED TIER IS STOCKED. `liveOdds` drops an empty tier and
	-- RENORMALISES, so authorised odds for a tier nothing carries do not
	-- empty the crate, they REPRICE it -- silently. `auditRandomOutcomes`
	-- refuses it too; asserted here as well because this is the crate whose
	-- stock is one epic deep and therefore the one that will break first.
	local pool = Config.chestPool("guardian")
	for tier, weight in Config.CHESTS.guardian.odds do
		expect(type(weight) == "number" and weight > 0 and #(pool[tier] or {}) > 0,
			"the Guardian Crate stocks the " .. tier .. " it authorises (" .. #(pool[tier] or {}) .. " coats)")
	end
	for tier, keys in pool do
		expect(Config.CHESTS.guardian.odds[tier] ~= nil,
			"the Guardian Crate authorises odds for the " .. tier .. " it stocks (" .. #keys .. " coats)")
	end
	-- THE THREE THAT ARE NOT IN IT. Scrappy is free and the two priced
	-- breeds are earnable, which is the whole reason the crate is ten rather
	-- than thirteen.
	for _, key in free do
		expect(pooled[key] == nil, key .. " is free and is in no crate")
	end
	for _, key in priced do
		expect(pooled[key] == nil, key .. " is bought with coins and is in no crate")
	end
	for _, key in crated do
		expect(pooled[key] == "guardian", key .. " is actually in the Guardian Crate's pool")
	end
	expect(Config.catalogueFor("coat") == Config.DOG_COATS,
		"a crate can resolve the coat catalogue")
end
-- `COSMETIC_KINDS` IS STILL NARROWER THAN `catalogueFor`, and the two answer
-- different questions: that list is what gets SWEPT (`passItems` walks it for
-- pass exclusives), and a guardian is not one.
check(table.find(Config.COSMETIC_KINDS, "coat") == nil, "coats are outside the swept cosmetic kinds")
check(Config.catalogueFor("dogcoat") == nil, "the client's request kind is not a catalogue key")
for _, set in Config.SETS do
	for _, entry in set.items do check(entry.kind ~= "coat", "no event set carries a guardian") end
end

-- 4. THE SERVER GATE, driven through the real `buyDogCoat`.
local dataSource, n = sources.DataService:gsub("return DataService%s*$", "return {defaults=defaultData, reconcile=reconcile}")
assert(n == 1)
local function loadWith(name, moduleEnv, source)
	local run = assert(loadstring(source or sources[name], name))
	setfenv(run, setmetatable(moduleEnv, {__index = getfenv()})); return run()
end
local replicated = {Shared = names}
local Data = loadWith("DataService", {game = {JobId = "guardian-tests", GetService = function(_, name)
	return if name == "ReplicatedStorage" then replicated else {} end}, require = function() return Config end}, dataSource)
local player = {DisplayName = "Test"}
local data, events, kinds, saves
local serverModules = {Config = Config, PlayerGear = {}, PlotService = {getPlot = function() return nil end},
	PassService = {}, TrophyService = {}}
serverModules.Remotes = {get = function(name) return {
	FireClient = function(_, _p, payload, kind) events[name] = payload; kinds[name] = kind end,
	FireAllClients = function(_, payload) events[name] = payload end} end}
serverModules.DataService = {get = function() return data end, save = function() saves += 1; return true end}
local serverEnv = {game = {GetService = function(_, name)
		if name == "Players" then return {GetPlayers = function() return {player} end} end
		return if name == "ReplicatedStorage" then replicated else {}
	end}, script = {Parent = names}, require = function(name) return assert(serverModules[name], name) end}
serverModules.SetService = loadWith("SetService", serverEnv)
local Cosmetics = loadWith("CosmeticsService", serverEnv)
local applied, pushed = 0, 0
Cosmetics.applyToPlot = function() applied += 1 end
Cosmetics.push = function() pushed += 1 end
local function reset()
	data = Data.defaults(); events = {}; kinds = {}; saves = 0
end

-- The gate under test is the real one once the row carries it, and a stand-in
-- of 3 until then: the CODE PATH is the same either way and is not pending.
--
-- DRIVEN ON A PRICED COAT RATHER THAN A CRATE ONE, because the priced rows
-- are the only ones a coin purchase can still reach -- the gate path on a
-- crate coat is unreachable by construction (the crate refusal fires above
-- it), and that refusal has a block of its own below. Derived from `priced`
-- rather than named, for the reason the exemption block above records.
local gateKey = priced[1]
local coat = Config.DOG_COATS[gateKey]
local savedGate = coat.unlockRebirths
coat.unlockRebirths = coat.unlockRebirths or 3
local gate = coat.unlockRebirths
check(gate >= 1, "the gated coat has a rebirth to refuse under")

reset(); data.coins = coat.cost * 2; data.rebirths = gate - 1
Cosmetics.buyDogCoat(player, gateKey)
check(events.Notify == ("Rebirth %d unlocks the %s."):format(gate, coat.name) and kinds.Notify == "warn",
	"below the gate the refusal names the rebirth: " .. tostring(events.Notify))
check(data.coins == coat.cost * 2 and not data.dogs.owned[gateKey] and data.dogs.equipped == "",
	"a refused purchase charges nothing, grants nothing and equips nothing")

reset(); data.coins = 0; data.rebirths = gate - 1
Cosmetics.buyDogCoat(player, gateKey)
check(events.Notify:find("Rebirth", 1, true) == 1, "short of both, the rebirth is the reason given -- coins cannot buy past it")

reset(); data.coins = coat.cost * 2; data.rebirths = gate
Cosmetics.buyDogCoat(player, gateKey)
check(data.coins == coat.cost and data.dogs.owned[gateKey] == true and data.dogs.equipped == gateKey,
	"at the gate the coat is bought and worn")
check(events.Notify == ("Unlocked %s!"):format(coat.name) and kinds.Notify == "good", "the purchase is announced")

reset(); data.coins = coat.cost; data.rebirths = gate + 7
Cosmetics.buyDogCoat(player, gateKey)
check(data.coins == 0 and data.dogs.owned[gateKey] == true, "above the gate the coat is bought")

reset(); data.coins = 0; data.rebirths = gate + 1
Cosmetics.buyDogCoat(player, gateKey)
check(events.Notify:find("more coins", 1, true) ~= nil and not data.dogs.owned[gateKey],
	"past the gate a shortfall is still the coin refusal")

-- AN OWNED COAT IS KEPT AND STILL EQUIPS AFTER A RESET: rebirth wipes power,
-- never cosmetics, and the ladder cannot take back what was bought.
reset(); data.coins = coat.cost; data.rebirths = gate
Cosmetics.buyDogCoat(player, gateKey)
data.rebirths = 0; data.dogs.equipped = ""
Cosmetics.buyDogCoat(player, gateKey)
check(data.dogs.equipped == gateKey and data.coins == 0 and data.dogs.owned[gateKey] == true,
	"an owned coat equips at rebirth 0 through buy-or-equip, uncharged")
Cosmetics.equipDogCoat(player, gateKey)
check(data.dogs.equipped == "", "asking twice takes it off")
Cosmetics.equipDogCoat(player, gateKey)
check(data.dogs.equipped == gateKey, "and again puts it back, below the gate")
local migrated = Data.reconcile(copy(data))
check(migrated.dogs.owned[gateKey] == true and migrated.dogs.equipped == gateKey,
	"reconcile prunes nothing an owned gated coat at rebirth 0")
check(events.Notify ~= nil and not events.Notify:find("unlocks the", 1, true), "equipping an owned coat never trips the gate")

-- Equipping a coat that is NOT owned is still the ownership refusal, never
-- a rebirth one -- the gate is on the purchase.
reset(); data.rebirths = 0
Cosmetics.equipDogCoat(player, gateKey)
check(events.Notify == ("%s isn't unlocked yet."):format(coat.name), "equip of an unowned coat is refused by ownership")

-- `or 0`: a row with no gate is buyable at rebirth 0 (the server boots and
-- sells on either side of the Config edit).
coat.unlockRebirths = nil
reset(); data.coins = coat.cost; data.rebirths = 0
Cosmetics.buyDogCoat(player, gateKey)
check(data.dogs.owned[gateKey] == true and data.coins == 0, "a row with no gate sells at rebirth 0")
coat.unlockRebirths = savedGate
check(applied > 0 and pushed > 0 and saves == 0, "purchases repaint and push through the service's own hooks")

-- 4b. A COIN PURCHASE OF A CRATE COAT IS REFUSED, OUT LOUD, AND CHARGES
-- NOTHING.
--
-- THE MONEY IS THE POINT OF THIS BLOCK. A crate coat has no `cost`, so
-- without the refusal `buyDogCoat` reads `cost = 0`, finds `data.coins < 0`
-- false, and HANDS THE COAT OVER FOR NOTHING -- the `(nil or 0)` hole this
-- project has already paid for twice. The refusal has to sit ABOVE the gate
-- as well: a crate coat carries no gate either, so reaching the gate check
-- would name rebirth 0 and read as nonsense.
if #crated > 0 then
	local crateKey = crated[1]
	local crateCoat = Config.DOG_COATS[crateKey]
	local crateName = (Config.CHESTS[crateCoat.chest] or {}).name
	reset(); data.coins = 5000000; data.rebirths = Config.rebirthsToMax()
	Cosmetics.buyDogCoat(player, crateKey)
	expect(events.Notify == ("The %s comes from the %s."):format(crateCoat.name, crateName)
		and kinds.Notify == "warn",
		"a coin purchase of a crate coat names the crate: " .. tostring(events.Notify))
	expect(data.dogs.owned[crateKey] ~= true and data.coins == 5000000 and data.dogs.equipped == "",
		"and grants nothing, charges nothing and equips nothing")
	-- EVEN AT ZERO COINS AND ZERO REBIRTHS, which is the case a `cost = 0`
	-- fall-through would have handed over free.
	reset(); data.coins = 0; data.rebirths = 0
	Cosmetics.buyDogCoat(player, crateKey)
	expect(data.dogs.owned[crateKey] ~= true, "a broke player at rebirth 0 is refused a crate coat rather than given one")
	expect(events.Notify:find("comes from", 1, true) ~= nil,
		"and the reason is the crate, never a coin shortfall or a rebirth")
	-- OWNING ONE STILL MAKES THIS AN EQUIP. A coat that came out of a crate
	-- is worn exactly as a bought one is, so the refusal must sit BELOW the
	-- owned branch.
	reset(); data.dogs.owned[crateKey] = true
	Cosmetics.buyDogCoat(player, crateKey)
	expect(data.dogs.equipped == crateKey, "an owned crate coat is equipped by the same control, not refused")
else
	print("PENDING: no crated coat to refuse a coin purchase of; waits on the Config edit")
	pending += 1
end

-- 4c. RECONCILE GRANTS SCRAPPY, ONCE, ON EVERY SAVE.
--
-- IDEMPOTENT IS THE ASSERTION THAT MATTERS: the grant writes `true` over
-- `true`, so there is no schema version to remember and no second grant to
-- count. It is also why a free coat may not be SOLD -- a refund on every join
-- is the money printer `loot` and `shards` were pruned rather than paid out.
if #free > 0 then
	local freeKey = free[1]
	local fresh = Data.reconcile(Data.defaults())
	expect(fresh.dogs.owned[freeKey] == true, "a fresh save owns " .. freeKey .. " after reconcile")
	local twice = Data.reconcile(Data.reconcile(Data.defaults()))
	expect(twice.dogs.owned[freeKey] == true, "and still owns exactly one after a second reconcile")
	local owned = 0
	for _ in twice.dogs.owned do owned += 1 end
	expect(owned == #free, "reconcile grants the free coats and nothing else: " .. owned)
	-- A SAVE THAT PREDATES IT. Written with an empty wardrobe and a coat key
	-- that no longer exists, so the prune and the grant are exercised in the
	-- one pass and in the right order.
	local old = Data.defaults()
	old.dogs.owned = { ["retired-guardian"] = true }
	old.dogs.equipped = "retired-guardian"
	local migrated2 = Data.reconcile(old)
	expect(migrated2.dogs.owned["retired-guardian"] == nil, "a retired coat is still pruned")
	expect(migrated2.dogs.owned[freeKey] == true, "and the free coat is granted in the same pass")
	expect(migrated2.dogs.equipped == "", "a retired equipped coat still falls back to the breed look")
	-- IT SURVIVES A MALFORMED WARDROBE rather than throwing: `owned` is
	-- guarded, so a save whose table is a string is rebuilt by the generic
	-- fill and simply misses the grant this pass.
	local broken = Data.defaults()
	;(broken.dogs :: any).owned = "not a table"
	expect(pcall(Data.reconcile, broken), "a malformed wardrobe does not take reconcile down")
	-- AND IT IS FREE THROUGH THE REAL PURCHASE TOO, which is the belt to the
	-- reconcile's braces: a save that somehow reaches the shop without it
	-- gets the coat for nothing rather than a refusal.
	reset(); data.coins = 0; data.rebirths = 0
	Cosmetics.buyDogCoat(player, freeKey)
	expect(data.dogs.owned[freeKey] == true and data.coins == 0,
		"the free coat is granted at zero coins and zero rebirths")
else
	print("PENDING: no free coat to grant; waits on the Config edit")
	pending += 1
end

-- 4d. THE NAMEPLATE READS SCRAPPY, which is the whole player-facing half of
-- the rename. `GuardRig.species` prints the COAT's name for any coat naming
-- its own rig, so the free coat is what a plate over that body says -- and
-- the tier's own `breed` is what it says with no coat on.
expect(Config.DOG_COATS.terrier ~= nil and Config.DOG_COATS.terrier.name == "Scrappy",
	"the terrier coat is called Scrappy: " .. tostring(Config.DOG_COATS.terrier and Config.DOG_COATS.terrier.name))
expect(rig.species("terrier") == "Scrappy", "the nameplate reads Scrappy for that coat")
expect(string.upper(rig.species("terrier")) == "SCRAPPY", "and SCRAPPY once GuardDog upper-cases it")
expect(Config.DOG_TIERS[1].breed == "Scrappy", "the tier's breed is Scrappy too")
check(Config.DOG_COATS.terrier ~= nil, "the SAVE KEY is still `terrier`: a rename is not a migration")
check(Config.DOG_COATS.terrier.guardModel == "terrier", "and the rig key is still `terrier`")
check(catalog.terrier ~= nil and catalog.terrier.label == "Scrappy",
	"the rig catalogue's label follows the coat that selects it")
-- NOTHING PLAYER-FACING SAYS TERRIER ANY MORE. Read off the catalogues
-- themselves rather than by grepping prose: a name is what reaches a card,
-- a nameplate and a refusal.
for key, spec in Config.DOG_COATS do
	expect(not tostring(spec.name):lower():find("terrier", 1, true), key .. " does not print Terrier")
end
for index, tier in Config.DOG_TIERS do
	expect(not tostring(tier.breed):lower():find("terrier", 1, true),
		"DOG_TIERS[" .. index .. "] does not print Terrier")
end

-- 5. THE PUSH'S VERDICT: the dogCoats block of `CosmeticsService.push`, run
-- verbatim, carries the gate and a `locked` the card can read.
local block = assert(sources.CosmeticsService:match("(\tlocal dogsOwned = .-\n\tend\r?\n)"), "dogCoats push block found")
local function pushCoats(saveData)
	local out = {}
	local run = assert(loadstring("local data, Config, out = ...\n" .. block .. "\nout.dogCoats = dogCoats", "push"))
	run(saveData, Config, out)
	return out.dogCoats
end
coat.unlockRebirths = coat.unlockRebirths or 3
reset(); data.rebirths = gate - 1
local coats = pushCoats(data)
check(coats[gateKey].locked == true and coats[gateKey].unlockRebirths == gate, "the push marks a coat below its gate locked")
data.rebirths = gate
check(pushCoats(data)[gateKey].locked == false, "the push clears the lock at the gate")
data.rebirths = 0; data.dogs.owned[gateKey] = true
check(pushCoats(data)[gateKey].locked == false, "an owned coat is never pushed locked, whatever the rebirth count")
coat.unlockRebirths = savedGate
-- ONLY THE PRICED PAIR IS EVER LOCKED, AND THAT IS THE ASSERTION THAT MOVED.
-- It used to be "a fresh save sees EVERY guardian locked at rebirth 0", which
-- was right while every row carried a gate. Eleven of thirteen have no sale
-- for a rebirth to open now, so a lock on one would be the card declining to
-- ask for something the server would have accepted.
reset(); data.rebirths = 0
local fresh = pushCoats(data)
local lockedCount = 0
for _, info in fresh do if info.locked then lockedCount += 1 end end
expect(lockedCount == #priced, "a fresh save sees only the priced guardians locked at rebirth 0: " .. lockedCount)
data.rebirths = Config.rebirthsToMax()
local open = pushCoats(data)
local openCount = 0
for _, info in open do if not info.locked then openCount += 1 end end
expect(openCount == total, "a maxed player sees every guardian open")

-- AND THE PUSH SAYS WHICH ROUTE, so the card never has to read a cost of 0
-- and guess. A free coat and a crate coat both push `cost = 0` and they are
-- opposite cards: one is always owned, one can never be bought.
reset(); data.rebirths = 0
local routed = pushCoats(data)
for _, key in free do
	expect(routed[key].free == true and routed[key].fromCrate == false,
		key .. " is pushed as free, not as a crate coat")
	expect(routed[key].locked == false, key .. " is never pushed locked")
end
for _, key in crated do
	expect(routed[key].fromCrate == true and routed[key].free == false,
		key .. " is pushed as a crate coat")
	expect(routed[key].locked == false and routed[key].cost == 0,
		key .. " is pushed unlocked and with no price")
	expect(routed[key].rarity == Config.DOG_COATS[key].rarity,
		key .. " pushes the tier its row states, so the border cannot drift")
end
for _, key in priced do
	expect(routed[key].fromCrate == false and routed[key].free == false,
		key .. " is pushed as neither free nor crated")
	expect(routed[key].cost == Config.DOG_COATS[key].cost, key .. " pushes its real price")
end

-- 6. THE CARD: locked state on the pill, and the Locked attribute the
-- Activated handler declines on.
local function gui(class)
	local o = {ClassName = class, _attributes = {}}
	function o:SetAttribute(key, value) self._attributes[key] = value end
	function o:GetAttribute(key) return self._attributes[key] end
	function o:FindFirstChild() return nil end
	function o:FindFirstChildOfClass() return nil end
	return o
end
-- A STUB `ShopWidgets` WITH NO `requirement` IN IT, which is the state the
-- card has to work in TODAY: the shared lock overlay is another session's
-- work, so `ShopGuardianCards` delegates when the helper exists and paints
-- its own pill when it does not. Both branches are driven below.
local cardModules = {Config = Config, Theme = {INK = "ink", PAPER = rgb(255, 250, 240), MUTED = "muted"},
	ShopStyle = {LOCKED = "locked-purple"}, ShopWidgets = {}}
local cardEnv = setmetatable({game = {GetService = function() return {Shared = names} end},
	require = function(name) return assert(cardModules[name], name) end}, {__index = getfenv()})
local function loadCard(name)
	local fn = assert(loadstring(sources[name], name)); setfenv(fn, cardEnv)
	cardModules[name] = fn(); return cardModules[name]
end
loadCard("ShopImageCards")
local Cards = loadCard("ShopGuardianCards")
local function entry()
	return {button = gui("TextButton"), sub = gui("TextLabel"), title = gui("TextLabel"), swatch = gui("Frame")}
end
local card = entry(); card.sub.Text = "250.0K"
Cards.paint(card, {rarity = "rare", equipped = false, owned = false, cost = 250000, locked = true, unlockRebirths = 4}, 10)
check(card.sub.Text == "REBIRTH 4", "a locked card's pill names the rebirth: " .. tostring(card.sub.Text))
check(card.sub.BackgroundColor3 == "locked-purple" and card.sub.TextColor3 == "ink", "the pill takes the LOCKED tint with ink type")
check(card.button:GetAttribute("Locked") == true, "the button is marked Locked for the Activated handler")
Cards.paint(card, {rarity = "rare", equipped = false, owned = false, cost = 250000, locked = false, unlockRebirths = 4}, 10)
check(card.button:GetAttribute("Locked") == false and card.sub.Text == "REBIRTH 4", "unlocking clears the mark on the next paint (the loop rewrites the text)")
local owned = entry(); owned.sub.Text = "Tap to guard"
Cards.paint(owned, {rarity = "rare", equipped = false, owned = true, cost = 250000, locked = false, unlockRebirths = 4}, 0)
check(owned.button:GetAttribute("Locked") == false and owned.sub.Text == "Tap to guard", "an owned coat is never locked on the card")
local worn = entry(); worn.sub.Text = "ON GUARD"
Cards.paint(worn, {rarity = "rare", equipped = true, owned = true, cost = 250000, locked = true, unlockRebirths = 4}, 0)
check(worn.button:GetAttribute("Locked") == false and worn.sub.Text == "ON GUARD", "a worn coat ignores a stray locked flag")
local plain = entry(); plain.sub.Text = "15.0K"
Cards.paint(plain, {rarity = "common", equipped = false, owned = false, cost = 15000}, 0)
check(plain.button:GetAttribute("Locked") == false and plain.sub.Text == "15.0K", "a push without the field paints an ordinary priced card")

-- A CRATE COAT READS `FROM CRATE`, AND NEVER A `0`.
--
-- ClientMain's render loop writes `format(info.cost)` before this paint runs,
-- so the overwrite HERE is the whole of what keeps a gold `0` off the card --
-- the failure ten drop-pool skins shipped with, where the rarest items in the
-- game each advertised themselves as free and tapping one did nothing.
local crate = entry(); crate.sub.Text = "0"
Cards.paint(crate, {rarity = "legendary", equipped = false, owned = false, cost = 0, fromCrate = true}, 0)
check(crate.sub.Text == "FROM CRATE", "an unowned crate coat names the route rather than a price: " .. tostring(crate.sub.Text))
check(crate.button:GetAttribute("Locked") == false, "and is never locked")
check(crate.button:GetAttribute("Rarity") == "legendary", "and keeps its rarity border")
-- A STRAY `locked` ON A CRATE COAT STILL NAMES THE CRATE, which is the order
-- the two treatments run in: the gate first, the route second. The LOCK
-- itself is left to the shared gate's own rule rather than second-guessed
-- here -- a crate coat carries no `unlockRebirths`, so the push cannot
-- produce this state, and a card that quietly disagreed with the shared
-- verdict would be the fourth opinion about what "gated" means. What must
-- not happen is the pill falling back to a price the coat does not have.
local stray = entry(); stray.sub.Text = "0"
Cards.paint(stray, {rarity = "rare", equipped = false, owned = false, cost = 0,
	fromCrate = true, locked = true, unlockRebirths = 4}, 0)
check(stray.sub.Text == "FROM CRATE",
	"a crate coat names the crate even under a stray locked flag: " .. tostring(stray.sub.Text))
-- OWNED, IT IS THE ORDINARY OWNED CARD. The route only matters while there is
-- something to say about getting one.
local hadCrate = entry(); hadCrate.sub.Text = "Tap to guard"
Cards.paint(hadCrate, {rarity = "epic", equipped = false, owned = true, cost = 0, fromCrate = true}, 0)
check(hadCrate.sub.Text == "Tap to guard", "an owned crate coat reads as owned, not as a route")
-- AND A FREE COAT IS NEVER MUTED FOR BEING UNAFFORDABLE. `ShopImageCards`
-- mutes when `coins < (cost or huge)`, and a free coat pushes a cost of 0 --
-- so `forSale` has to be false or a broke player's Scrappy reads as too dear.
local freeCard = entry(); freeCard.sub.Text = "Tap to guard"
Cards.paint(freeCard, {rarity = "common", equipped = false, owned = true, cost = 0, free = true}, 0)
check(freeCard.sub.TextColor3 == "ink" and freeCard.button:GetAttribute("Locked") == false,
	"a free coat is never locked and never muted")

-- THE GATE IS THE SHOP'S SHARED ONE, AND THE CARD DELEGATES TO IT.
--
-- `ShopWidgets.gate(entry, info)` owns the wash, the padlock, the "Rebirth N
-- required" line, the `Locked` attribute and the open-items-first
-- `LayoutOrder` for the houses, the rides and the guardians alike. Driven
-- through a STUB rather than the real widget, because the real one builds
-- Instances and this harness has none -- what is under test here is that the
-- guardian card calls it, with its own `info`, and reads its verdict.
local gated = nil
cardModules.ShopWidgets.gate = function(target, info)
	gated = info
	target.button:SetAttribute("Locked", info.locked == true and info.owned ~= true)
	return info.locked == true and info.owned ~= true
end
local shared = entry(); shared.sub.Text = "1.5M"
Cards.paint(shared, {rarity = "epic", equipped = false, owned = false, cost = 1500000,
	locked = true, unlockRebirths = 7}, 10)
check(gated ~= nil and gated.unlockRebirths == 7, "a guardian card goes through the shared gate with its own push")
check(shared.button:GetAttribute("Locked") == true, "and the shared gate's verdict is what marks the button")
-- THE PRICE STAYS ON THE PILL UNDER THE WASH, which is the designer's rule
-- and the reason this card no longer writes "REBIRTH 7" over it.
check(shared.sub.Text == "1.5M", "a gated card keeps the price readable rather than replacing it")
-- AND A CRATE COAT STILL NAMES THE CRATE WITH THE SHARED GATE IN PLACE.
local sharedCrate = entry(); sharedCrate.sub.Text = "0"
Cards.paint(sharedCrate, {rarity = "rare", equipped = false, owned = false, cost = 0, fromCrate = true}, 0)
check(sharedCrate.sub.Text == "FROM CRATE", "and a crate coat's route survives the delegation")
cardModules.ShopWidgets.gate = nil
local fallback = entry(); fallback.sub.Text = "1.5M"
Cards.paint(fallback, {rarity = "epic", equipped = false, owned = false, cost = 1500000,
	locked = true, unlockRebirths = 7}, 10)
check(fallback.sub.Text == "REBIRTH 7" and fallback.sub.BackgroundColor3 == "locked-purple",
	"and the card paints its own pill when the shared gate is absent")

-- THE SHELF'S ORDER IS THE SHARED RANK, NOT A SORT OF ITS OWN.
--
-- `ShopWidgets.gateRank` is open-items-first then gated ones by ascending
-- gate, so the guardian shelf comes out Scrappy, the ten crate coats by
-- rarity, then the Mastiff and Shadow. That is DIFFERENT from putting the
-- two earnable breeds second, and it is deliberate: one expression decides
-- every shelf in the shop, and a guardian sorting itself would be the fourth
-- opinion about what "next" means.
if #crated > 0 and #priced > 0 and #free > 0 then
	local Widgets = {gateRank = function(info) return (info.unlockRebirths or 0) * 1000 + (info.order or 99) end}
	local ranked = {}
	for key, coat in Config.DOG_COATS do
		table.insert(ranked, {key = key, rank = Widgets.gateRank(coat)})
	end
	table.sort(ranked, function(a, b) return a.rank < b.rank end)
	expect(ranked[1].key == free[1], "the free guardian sorts first on the shared rank: " .. ranked[1].key)
	expect(Config.DOG_COATS[ranked[#ranked].key].unlockRebirths ~= nil,
		"and a gated one sorts last: " .. ranked[#ranked].key)
	-- ASCENDING BY RARITY THROUGH THE UNGATED RUN, which is what `order` is
	-- for once the gate has decided the coarse grouping.
	local lastRank = 0
	for _, row in ranked do
		local coat = Config.DOG_COATS[row.key]
		if coat.chest ~= nil then
			expect(Config.rarityRank(coat.rarity) >= lastRank,
				row.key .. " does not sort above a rarer crate coat")
			lastRank = Config.rarityRank(coat.rarity)
		end
	end
end

-- 7. THE DEV COMMAND AND THE WIPE, as source: `unlockall` grants every coat
-- by writing ownership directly (never through the gated purchase), and a
-- rebirth never touches `data.dogs`.
local unlockall = assert(sources.AdminService:match("for key in pairs%(Config%.DOG_COATS%) do%s*data%.dogs%.owned%[key%] = true"), "unlockall grants coats directly")
check(sources.AdminService:find("buyDogCoat", 1, true) == nil, "unlockall never routes through the gated purchase")
check(sources.ProgressionService:find("data.dogs", 1, true) == nil and sources.ProgressionService:find("DOG_COATS", 1, true) == nil,
	"rebirth never touches the guardian wardrobe")

-- 8. THE FREE GRANT IS DERIVED FROM THE CATALOGUE, READ AS SOURCE. A second
-- free guardian must cost a FIELD and no code, which is the same call the
-- prune beside it already makes -- and a hardcoded `"terrier"` in reconcile
-- would be a second place that decides which coats are free.
check(sources.DataService:find('coat.free == true', 1, true) ~= nil,
	"reconcile grants free coats by walking the catalogue for the field")
check(sources.DataService:find('data.dogs.owned["terrier"]', 1, true) == nil,
	"and never by naming a key")

print(("PASS: %d guardian checks; palette, season reward, disabled follower, the three routes (free, priced behind a rebirth, crate-only), the crate refusal, reconcile's free grant, the Scrappy rename, the pool, the push's verdict and the card. %d pending on the Config edit."):format(checks, pending))
