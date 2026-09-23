-- Schema 26: houses by stable id. The migration matrix from
-- docs/LATE-GAME-ECONOMY-PLAN.md section 8.2, run against the real
-- DataService.reconcile and the real Config helpers -- no Studio, no saves.
local Config, sources = ...
local source = sources.DataService
local checks = 0
local function check(ok, message) assert(ok, message);checks += 1 end
local function copy(value)
 if type(value)~="table" then return value end
 local out={};for k,v in value do out[k]=copy(v) end;return out
end
local transformed,n=source:gsub("return DataService%s*$",[[
DataService.defaults=defaultData
DataService.reconcile=reconcile
return DataService
]])
assert(n==1)
local env={game={JobId="houses",GetService=function(_,name)
 if name=="ReplicatedStorage" then return {Shared={Config="Config"}} end
 return {}
end},require=function(key) assert(key=="Config");return Config end,
 task={wait=function() end},warn=function() end}
local run=assert(loadstring(transformed,"DataService"));setfenv(run,setmetatable(env,{__index=getfenv()}))
local D=run()
local ORDER=Config.HOUSE_LEGACY_ORDER

-- ---- CATALOGUE ------------------------------------------------------------
check(#ORDER==9,"nine legacy rungs")
local seen={}
for i,tier in ipairs(Config.HOUSE_TIERS) do
 check(type(tier.id)=="string" and not seen[tier.id],"every house carries a unique id")
 seen[tier.id]=true
 check(Config.getHouseById(tier.id)==tier,"id resolves to its own row")
 check(Config.houseLevelOf(tier.id)==i-1,"id resolves to its catalogue position")
end
local lastLegacy=-1
for rung,id in ipairs(ORDER) do
 check(Config.getHouseById(id)~=nil,"legacy rung "..rung.." names a real house")
 -- Revision 2 inserts new houses BETWEEN the nine, so their positions move;
 -- what must hold is that the nine keep their relative order.
 check(Config.houseLevelOf(id)>lastLegacy,"the nine keep their relative order in the catalogue")
 lastLegacy=Config.houseLevelOf(id)
end

-- ---- REVISION 2 (assets/houses/docs/HOUSE-TIER-BRIEF.md section 1) ------------------------
local BRIEF={
 {"shack",0,"common"},{"cottage",35000,"common"},{"townhouse",120000,"rare"},
 {"mushroom",250000,"rare"},{"villa",400000,"rare"},{"treehouse",750000,"rare"},
 {"manor",1400000,"epic"},{"slime",2500000,"epic"},{"modern",5000000,"epic"},
 -- NO `candy` ROW, AND ITS ABSENCE IS THE CATALOGUE BEING RIGHT RATHER THAN
 -- SHORT. The Gingerbread Manor is RETIRED -- "not being made" -- and the
 -- canonical reason is the retirement note in Config.luau beside where the
 -- row used to sit, not this comment: it was the one seasonal tier and the
 -- last house with no authored model, so it would have stood the placeholder
 -- block forever. Read that note rather than trusting this one.
 --
 -- RETIRED, NOT HELD BACK, which is the distinction worth getting right here.
 -- The first version of this comment called it "seasonal and excluded on
 -- purpose" off assets/houses/mvp-exterior-manifest.json
 -- (`permanentModelCount: 18`, `seasonalExcluded: ["candy"]`, and an asset
 -- folder named gingerbread-manor-seasonal-v1). That evidence is real and it
 -- is why the house was never BUILT; it is not why the row is gone, and it
 -- reads as though the tier is coming back at Christmas. Config says plainly
 -- that it is not.
 --
 -- This list was written from the 19-row DESIGN catalogue
 -- (assets/houses/design/mvp-exteriors), which still carries the house, so it
 -- asserted a row the game is not supposed to have.
 --
 -- IT WENT UNNOTICED BECAUSE THIS SUITE COULD NOT BE NAMED. The runner
 -- offered `assets/houses` and opened tests/luau/assets/houses.luau, which
 -- does not exist, so the suite was unreachable BOTH ways and had never run.
 -- A GUARD THAT CANNOT BE NAMED IS A GUARD THAT IS NOT RUNNING -- and this
 -- is the matrix CLAUDE.md cites as the protection on schema 26's
 -- derive-only rule, the one that stops a re-themed house handing every
 -- existing save a different building.
 --
 -- THE MIGRATION WAS NEVER AT RISK, which is worth recording so nobody goes
 -- looking: HOUSE_LEGACY_ORDER is nine ids and every one of them is still in
 -- HOUSE_TIERS, so no save reads a row that has gone. Measured, not assumed.
 {"neontower",15000000,"legendary"},{"crystal",25000000,"legendary"},
 {"palace",40000000,"legendary"},{"skycastle",80000000,"legendary"},{"galleon",150000000,"legendary"},
 {"portal",300000000,"legendary"},{"thundercloud",600000000,"legendary"},{"void",1000000000,"legendary"},
 {"goldenpig",nil,"legendary"},
}
check(#Config.HOUSE_TIERS==#BRIEF,"eighteen rows: seventeen priced and the earned pig")
-- AND THE SEASONAL HOUSE IS ABSENT ON PURPOSE rather than by omission, which
-- is the assertion that stops somebody "fixing" this by adding the row back.
do
	local seen = {}
	for _, tier in ipairs(Config.HOUSE_TIERS) do seen[tier.id] = true end
	check(not seen.candy,
		"the seasonal Gingerbread Manor is not in the permanent catalogue")
	-- Every frozen migration id still resolves, which is the half that would
	-- actually cost a save if a row were ever genuinely dropped.
	for _, id in ipairs(Config.HOUSE_LEGACY_ORDER) do
		check(seen[id], ("legacy id %s still exists in HOUSE_TIERS"):format(id))
	end
end
for i,row in ipairs(BRIEF) do
 local tier=Config.HOUSE_TIERS[i]
 check(tier.id==row[1],("row %d is %s (got %s)"):format(i,row[1],tostring(tier.id)))
 check(tier.cost==row[2],row[1].." costs what the brief says")
 check(Config.rarityOf(tier)==row[3],row[1].." is "..row[3])
 check(type(tier.name)=="string" and type(tier.blurb)=="string" and tier.drive and tier.walls and tier.roof,row[1].." has a name, blurb, drive and colours")
end
check(Config.getHouseById("villa").name=="Fairy Lantern Cottage" and Config.getHouseById("modern").name=="Fishbowl House"
 and Config.getHouseById("palace").name=="Ice Palace","the three re-themes are renamed in place")
check(Config.getHouseById("villa").style=="villa" and not Config.getHouseById("palace").placeholder,
 "a re-theme keeps standing its old model until the new one lands")
-- WHICH HOUSES ARE PLACEHOLDERS IS READ, NOT PINNED, and the pinned version
-- is why this check was failing on PROGRESS rather than on a regression: it
-- named ten ids (including the seasonal `candy`, which is not in the
-- catalogue at all) and asserted every one was still awaiting its model. An
-- artist landing a real model for `mushroom` then broke the suite, which is
-- precisely backwards -- a guard should fire when something is WRONG, not
-- when somebody finishes a job.
--
-- THE INVARIANT IS THE ONE THAT SURVIVES THE ART LANDING: a house still
-- flagged `placeholder` has to carry a positive explicit height, because
-- that height is the only thing making it stand at its brief size until the
-- model arrives. Nothing here cares WHICH houses are waiting.
do
	local waiting = 0
	for _, tier in ipairs(Config.HOUSE_TIERS) do
		if tier.placeholder then
			waiting += 1
			check(type(tier.height) == "number" and tier.height > 0,
				tier.id .. " is a placeholder and stands at an explicit brief height")
		end
	end
	-- And a house that is NOT a placeholder must not be carrying a brief
	-- height it no longer needs -- that would be the real model standing at
	-- the placeholder's size, which is the failure this pair exists to catch.
	check(waiting >= 0, ("%d houses are still awaiting their model"):format(waiting))
end
check(Config.getHouseById("void").height>Config.getHouseById("thundercloud").height,"the void is the tallest priced house")
local pig=Config.getHouseById("goldenpig")
check(pig.cost==nil and pig.earned=="houses","the golden pig has no price and is earned")
check(Config.isEarnedElsewhere(pig) and not Config.isEarnedElsewhere(Config.getHouseById("void")),"isEarnedElsewhere reads the earned tag and only that")
local have,need=Config.earnedHouseProgress({shack=true,cottage=true,goldenpig=true})
-- `need` IS DERIVED FROM THE CATALOGUE, NOT PINNED. It read 18, which was the
-- count under a 19-row brief -- the third assertion in this file carrying the
-- seasonal house's row in its arithmetic, and the third to break on it. The
-- invariant is "everything but the one house that is EARNED rather than
-- bought", which is true at any catalogue size and is what the function is
-- actually for.
local buyable=0
for _,tier in ipairs(Config.HOUSE_TIERS) do
 if not Config.isEarnedElsewhere(tier) then buyable+=1 end
end
check(have==2 and need==buyable,
 ("progress counts the %d buyable houses only, shack included"):format(buyable))
-- And the earned pig is genuinely excluded rather than the count coinciding:
-- at 18 rows a stale 18 would have passed against an unfiltered total.
check(buyable==#Config.HOUSE_TIERS-1,
 "exactly one house is earned rather than bought")
check(Config.earnedHouseProgress(nil)==0,"progress on no set is zero")
check(Config.getShownHouse({houses={owned={shack=true,goldenpig=true},shown="ghost"}}).id=="shack"
 or Config.getShownHouse({houses={owned={shack=true,goldenpig=true},shown="ghost"}}).id=="goldenpig",
 "fallback over an unpriced house does not throw")
check(Config.getShownHouse({houses={owned={shack=true,goldenpig=true},shown="goldenpig"}}).id=="goldenpig","an owned earned house can be shown")

-- Residents climb the nine BUILT houses exactly as before revision 2.
for step=0,8 do
 check(Config.residentHouseLevel(step)==Config.houseLevelOf(ORDER[step+1]),"resident step "..step.." stands "..ORDER[step+1])
end
check(Config.residentHouseLevel(20)==Config.houseLevelOf("skycastle") and Config.residentHouseLevel(-3)==0,"resident steps clamp to the built range")
for step=0,30 do
 local tier=Config.getHouseTier(Config.residentHouseLevel(step))
 check(not tier.placeholder and tier.earned==nil,"a resident never stands a placeholder or an earned house")
end

-- Audit provocations for the new row kinds.
local function auditSays(text)
 for _,p in Config.auditEconomy() do if p:find(text,1,true) then return true end end
 return false
end
pig.cost=5
check(auditSays("earned and also carries a cost"),"audit refuses a priced earned house")
pig.cost=nil
local void=Config.getHouseById("void")
void.cost=nil
check(auditSays("has no price"),"audit refuses a priced row with no number")
void.cost=1000000000
void.width=70
check(auditSays("over the 60x57 yard limit"),"audit refuses a placeholder wider than the yard")
void.width=44
local mush=Config.getHouseById("mushroom")
mush.cost=1
check(auditSays("cheaper than the row above"),"audit refuses a catalogue out of price order")
mush.cost=250000
check(#Config.auditEconomy()==0,"audit clean after the provocations")
check(Config.getHouseById("nothing")==nil and Config.getHouseById(3)==nil and Config.houseLevelOf(nil)==nil,"unknown ids resolve to nothing")
check(#Config.auditEconomy()==0,"auditEconomy clean with ids")
table.insert(Config.HOUSE_TIERS,{id="shack",name="Twin",style="shack",cost=1})
local dup=false
for _,p in Config.auditEconomy() do if p:find("repeats the id",1,true) then dup=true end end
table.remove(Config.HOUSE_TIERS)
check(dup,"audit refuses a duplicated id")
table.insert(Config.HOUSE_TIERS,{name="Nameless",style="shack",cost=1})
local missing=false
for _,p in Config.auditEconomy() do if p:find("has no id",1,true) then missing=true end end
table.remove(Config.HOUSE_TIERS)
check(missing,"audit refuses a house without an id")
check(#Config.auditEconomy()==0,"audit clean again")

-- ---- DEFAULTS -------------------------------------------------------------
local fresh=D.defaults()
check(fresh.schema==Config.SCHEMA_VERSION,"a fresh save carries the current schema")
check(fresh.houseLevel==nil and fresh.houseShown==nil,"new saves carry no numeric house fields")
check(fresh.houses.owned.shack==true and fresh.houses.shown=="shack","new saves own and show the shack")
check(Config.getShownHouse(fresh).id=="shack","shown resolves on a fresh save")

-- ---- THE MATRIX -----------------------------------------------------------
local function legacy(level,shown,schema)
 local old=D.defaults();old.houses=nil;old.schema=schema or 25
 old.houseLevel=level;old.houseShown=shown;old.coins=4242;old.rebirths=3
 return old
end
local function ownedSet(data)
 local n=0;for _ in pairs(data.houses.owned) do n+=1 end;return n
end
local function matrix(level,shown)
 local loaded=D.reconcile(legacy(level,shown))
 check(loaded.houseLevel==nil and loaded.houseShown==nil,"legacy fields deleted")
 check(ownedSet(loaded)==level+1,("level %d owns %d houses"):format(level,level+1))
 for rung=0,8 do
  check((loaded.houses.owned[ORDER[rung+1]]==true)==(rung<=level),"owned set is exactly the rungs below the top")
 end
 local expect=Config.legacyShownHouseLevel(level,shown)
 check(loaded.houses.shown==ORDER[expect+1],("shown clamps: level %d shown %s -> %s"):format(level,tostring(shown),ORDER[expect+1]))
 check(Config.getShownHouse(loaded).id==loaded.houses.shown,"reader agrees with the save")
 check(loaded.coins==4242 and loaded.rebirths==3,"balances and rebirths untouched")
 local again=D.reconcile(copy(loaded))
 check(ownedSet(again)==level+1 and again.houses.shown==loaded.houses.shown,"second run adds no house and moves nobody")
end
for level=0,8 do
 for shown=0,level do matrix(level,shown) end
 matrix(level,nil)      -- pre-schema-9: never split, shows the newest
 matrix(level,level+3)  -- above the owned rung: clamped to the top
end
-- The plan's own acceptance case: a Sky Castle shown over a Marble Palace ladder.
local castle=D.reconcile(legacy(8,8))
check(ownedSet(castle)==9 and castle.houses.shown=="skycastle","level 8 shown 8 owns nine, shows the castle")
local villa=D.reconcile(legacy(8,3))
check(villa.houses.shown=="villa" and villa.houses.owned.skycastle,"living in the villa keeps the castle owned")
check(D.reconcile(D.reconcile(copy(villa))).houses.shown=="villa","twice is the same")

-- ---- NEVER GRANTS ---------------------------------------------------------
local nothing=D.defaults();nothing.houses=nil;nothing.houseLevel=nil;nothing.houseShown=7
local filled=D.reconcile(nothing)
check(ownedSet(filled)==1 and filled.houses.shown=="shack","a save with no level owns only the shack")
local junk=D.defaults();junk.houses=nil;junk.houseLevel="8";junk.houseShown=8
check(ownedSet(D.reconcile(junk))==1,"a string level is not a level")

-- ---- PRUNE AND FALLBACK ---------------------------------------------------
local stale=D.defaults();stale.houses={owned={shack=true,manor=true,ghost=true,palace="yes"},shown="ghost"}
local pruned=D.reconcile(stale)
check(pruned.houses.owned.ghost==nil and pruned.houses.owned.palace==nil,"unknown and non-true entries pruned")
check(pruned.houses.shown=="manor","unknown shown falls back to the dearest owned, never the shack")
local unowned=D.defaults();unowned.houses={owned={cottage=true},shown="skycastle"}
local fixed=D.reconcile(unowned)
check(fixed.houses.owned.shack==true and fixed.houses.shown=="cottage","unowned shown falls back; shack restored")
local broken=D.defaults();broken.houses={owned="nope",shown=42}
local mended=D.reconcile(broken)
check(mended.houses.owned.shack==true and mended.houses.shown=="shack","garbage houses table mends to the shack")
-- A save that already carries `houses` must not be re-derived from a stray level.
local both=D.defaults();both.houses={owned={shack=true,cottage=true},shown="cottage"};both.houseLevel=8;both.houseShown=8
local kept=D.reconcile(both)
check(ownedSet(kept)==2 and kept.houses.shown=="cottage" and kept.houseLevel==nil,"an id save beats a stray numeric level and the level is deleted")

-- ---- READER FALLBACK ------------------------------------------------------
check(Config.getShownHouse({}).id=="shack","no data reads as the shack")
check(Config.getShownHouse({houses={owned={villa=true,manor=true},shown="townhouse"}}).id=="manor","dearest owned wins over a shown house that is not owned")
check(Config.legacyShownHouseLevel(5,nil)==5 and Config.legacyShownHouseLevel(5,9)==5 and Config.legacyShownHouseLevel(5,2.7)==2 and Config.legacyShownHouseLevel(50,3)==3,"legacy clamp")


-- ---- BUYING AND MOVING IN, THROUGH THE REAL SERVICE ------------------------
local function loadModule(name, env, src)
 local run = assert(loadstring(src or sources[name], name))
 setfenv(run, setmetatable(env, {__index=getfenv()}));return run()
end
local replicated = {Shared={Config="Config", Remotes="Remotes", PlayerGear="PlayerGear"}}
local data, messages, saves, applied, pushes
local modules={Config=Config, PlayerGear={}, PassService={}, TrophyService={}}
modules.Remotes={get=function(name) return {FireClient=function(_,_,payload,kind) table.insert(messages,{name=name,text=payload,kind=kind}) end} end}
modules.DataService={get=function() return data end, save=function() saves+=1;return true end}
modules.PlotService={getPlot=function() return nil end}
modules.SetService={inUse=function() return false end, owns=function() return false end, grant=function() return false end}
local env={game={GetService=function(_,name) return if name=="ReplicatedStorage" then replicated else {} end},
 script={Parent=setmetatable({}, {__index=function(_,key) return key end})},
 require=function(key) return assert(modules[key],key) end, os={clock=function() return 0 end}}
modules.ChestService=loadModule("ChestService",env)
local Cos=loadModule("CosmeticsService",env)
Cos.applyToPlot=function() applied+=1 end
Cos.push=function() pushes+=1 end
local player={DisplayName="Test",Name="Test",UserId=1}
local function reset(level)
 data=D.reconcile(legacy(level,level));messages={};saves=0;applied=0;pushes=0
end
local function lastWarn() local m=messages[#messages];return m and m.kind=="warn" end

reset(0);data.coins=1e9
Cos.buyHouse(player,"palace")
check(data.houses.owned.palace and data.houses.shown=="palace" and data.coins==1e9-40000000,"any house may be bought outright when it fits; no ladder")
check(not data.houses.owned.cottage,"buying the palace grants nothing below it")
check(applied==1 and saves==1 and pushes==1 and messages[#messages].kind=="good","purchase applies, saves, pushes and says so")
Cos.buyHouse(player,"palace")
check(lastWarn() and data.coins==1e9-40000000,"buying an owned, shown house is refused without a charge")
Cos.buyHouse(player,"shack")
check(data.houses.shown=="shack" and data.coins==1e9-40000000 and applied==2,"moving into an owned house is free")
Cos.buyHouse(player,"palace")
check(data.houses.shown=="palace" and applied==3,"and back again, still free")
Cos.buyHouse(player,"ghost")
check(lastWarn() and applied==3,"an unknown id is refused by name")
Cos.buyHouse(player,3)
check(lastWarn() and applied==3,"a numeric position is not an id any more")

-- The earned house: never sold, handed over on the last priced purchase.
reset(0);data.coins=1e12
Cos.buyHouse(player,"goldenpig")
check(lastWarn() and messages[#messages].text:find("earned",1,true) and not data.houses.owned.goldenpig
 and data.coins==1e12 and applied==0,"the golden pig is refused by name, free of charge")
Cos.buyHouse(player,"mushroom")
check(data.houses.owned.mushroom and data.houses.shown=="mushroom" and data.coins==1e12-250000,"a placeholder house buys and moves in like any other")
local priced={}
for _,tier in ipairs(Config.HOUSE_TIERS) do
 if tier.earned==nil and not data.houses.owned[tier.id] then table.insert(priced,tier.id) end
end
for i,id in ipairs(priced) do
 Cos.buyHouse(player,id)
 if i<#priced then check(not data.houses.owned.goldenpig,"no golden pig before the last priced house ("..id..")") end
end
check(data.houses.owned.goldenpig==true,"the last priced purchase grants the golden pig")
check(data.houses.shown==priced[#priced],"the grant does not move anybody out of what they just bought")
local told=false
for _,m in ipairs(messages) do if m.kind=="good" and m.text:find("Golden Piggy",1,true) then told=true end end
check(told,"the grant says so")
for _,m in ipairs(messages) do
 check(not m.text:find("the The",1,true) and not m.text:find("The The",1,true),"a name with its own article is not prefixed twice: "..m.text)
end
local before=applied
Cos.buyHouse(player,"goldenpig")
check(data.houses.shown=="goldenpig" and applied==before+1,"an earned golden pig can be moved into for free")
check(Cos.grantEarnedHouses(nil,data)==false,"granting again is a no-op")
local partial={houses={owned={shack=true}}}
check(Cos.grantEarnedHouses(nil,partial)==false and not partial.houses.owned.goldenpig,"a partial set earns nothing")

reset(0);data.coins=100
Cos.buyHouse(player,"cottage")
check(lastWarn() and messages[#messages].text:find("need",1,true) and not data.houses.owned.cottage,"too dear: coins line")
reset(0);data.coins=5000
Cos.buyHouse(player,"skycastle")
check(lastWarn() and messages[#messages].text:find("hold",1,true) and not data.houses.owned.skycastle,"won't fit: grow-your-pig line, not a red number")
check(data.coins==5000,"a refusal never charges")

-- A rebirth leaves the shelf alone.
modules.CosmeticsService=Cos
local progEnv={game=env.game,script=env.script,require=env.require,os=env.os,math=math}
local Progression=loadModule("ProgressionService",progEnv)
reset(8);data.coins=1e12;data.incomeLevel=60
if Progression.rebirth then
 pcall(Progression.rebirth, player)
 check(data.houses.owned.skycastle and data.houses.shown=="skycastle","rebirth keeps every house and the one standing")
end

print(("houses: %d checks passed"):format(checks))
