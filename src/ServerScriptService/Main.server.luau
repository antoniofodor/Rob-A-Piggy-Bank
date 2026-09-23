--!strict
--[[
	Main

	Server entry point. Starts services in dependency order and owns the
	player lifecycle.

	Load order matters: data before plots before economy, because the economy
	loop reads both.
]]

-- Build stamp, printed FIRST so it lands even if a service later errors.
--
-- Publishing does not restart running servers, and it is easy to publish to
-- the wrong place. When a change looks missing in the live game, this line in
-- the F9 console tells you which of the two it is: a stamp you do not
-- recognise means an old build, no stamp at all means the scripts never ran.
--
-- Bump BUILD before each publish.
local BUILD = "2026-08-30 suburb-street"
print(("[Main] BUILD %s"):format(BUILD))

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
-- Only for the animation warning below. RidePose owns the pose key
-- grammar, so it is the only thing that can say which keys exist.
local RidePose = require(ReplicatedStorage.Shared.RidePose)
local Services = script.Parent:WaitForChild("Services")
local DataService = require(Services.DataService)
local WorldService = require(Services.WorldService)
local NeighborhoodService = require(Services.NeighborhoodService)
local PlotService = require(Services.PlotService)
local ResidentService = require(Services.ResidentService)
local SocialService = require(Services.SocialService)
local EconomyService = require(Services.EconomyService)
local UpgradeService = require(Services.UpgradeService)
local ProgressionService = require(Services.ProgressionService)
local CosmeticsService = require(Services.CosmeticsService)
local HeistService = require(Services.HeistService)
local PiggyHaulService = require(Services.PiggyHaulService)
local BoneService = require(Services.BoneService)
local RideService = require(Services.RideService)
local SettingsService = require(Services.SettingsService)
local GadgetService = require(Services.GadgetService)
local HomeService = require(Services.HomeService)
local StealthService = require(Services.StealthService)
local HeldItemService = require(Services.HeldItemService)
local PoliceService = require(Services.PoliceService)
local TrafficService = require(Services.TrafficService)
local EventService = require(Services.EventService)
local SetService = require(Services.SetService)
local ChestService = require(Services.ChestService)
local DailyService = require(Services.DailyService)
local PassService = require(Services.PassService)
local TrophyService = require(Services.TrophyService)
local AdminService = require(Services.AdminService)
local SeasonService = require(Services.SeasonService)
local InteriorService = require(Services.InteriorService)

-- The legendary skins' meshes start loading now, in the background, so a
-- player wearing one on join is dressed at once rather than a beat later.
require(ReplicatedStorage.Shared.LegendaryModel).prewarm()
DataService.start()
WorldService.start()

-- THE PREVIEW PIG'S MESH, BEFORE ANY SERVICE CAN BUILD ONE.
--
-- `CreateMeshPartAsync` yields, so `PiggyModel` warms a template once and
-- clones it -- and anything that asks before the warm-up finishes gets the
-- old primitives pig instead. That is the right fallback and the wrong thing
-- to leave to luck: it sat in `PlotService.start` for one build, one line
-- BELOW `NeighborhoodService.start`, and the boutique's window display was
-- measured standing there as eleven primitives while every other piggy in
-- the game was the mesh. Nothing errored; the shop window just quietly had
-- the wrong animal in it.
--
-- So it goes above every service that can build a mini: the shop displays
-- (Neighborhood), the victim shelf and the carried loot (Plot, Piggy),
-- and the residents.
require(game:GetService("ReplicatedStorage").Shared.PiggyModel).prewarm()

-- The 3D coin that pours into a pig on a delivery. Built once here so the
-- first delivery clones it rather than waiting on a mesh load; an empty id in
-- Config.COIN_MESH leaves the drawn coin in its place.
require(game:GetService("ReplicatedStorage").Shared.CoinModel).prewarm()

-- THE SHOP'S DOG CARDS NEED A RIG ON THE CLIENT, and only the handful a
-- card can actually ask for. Before the plots, because the first thing a
-- joining player's shop does is render these -- and a copy that arrives
-- after the cards are built is a card that already fell back to its swatch.
require(Services.GuardVisual).publishPreviews()

-- After the ground exists, before the plots: pure scenery, no dependencies.
NeighborhoodService.start()
PlotService.start()
-- Immediately after the plots exist and BEFORE anything can seat a player on
-- one. `assign` runs the moment a player joins, and in Play Solo that is
-- essentially at once -- so if this had not registered its claim handler
-- yet, the first player into any server would move into a house with a
-- resident still living in it.
ResidentService.start()
SocialService.start()
-- The street leaderboard: lifetime cash, piggies robbed and rebirths for
-- everybody in the server, pushed on the leaderboard's cadence. Required and
-- started in one statement; it needs nothing from here.
require(Services.LobbyBoardService).start()
EconomyService.start()
UpgradeService.start()
ProgressionService.start()
CosmeticsService.start()
HeistService.start()
-- AFTER `HeistService` AND AFTER `PlotService`, AND BOTH HALVES MATTER. It
-- connects a trigger to every pedestal on every plot, so the plots have to
-- exist; and the three questions it answers for `HeistService` are registered
-- below, so that file has to have loaded.
PiggyHaulService.start()
HeldItemService.start()
BoneService.start()
-- Both reach into HeistService, so they start after it.
GadgetService.start()
HomeService.start()
StealthService.start()
-- Subscribes to HeistService's steal hook, so it starts after it.
PoliceService.start()
-- After PoliceService, which it asks whether a patrol is out before it
-- puts a van on the road. Scenery, and the last thing that should be able
-- to hold up anything above it.
TrafficService.start()
EventService.start()
DailyService.start()
-- Before RideService, which subscribes to its Granted event.
PassService.start()
RideService.start()
SettingsService.start()
SetService.start()
SeasonService.start()
-- The front door. Last of the plot chain, because it requires PlotService
-- and wants the plots standing before it probes a hallway at boot -- and
-- deliberately NOT before `PlotService.start`, which is what builds the
-- houses it reads a door anchor off.
InteriorService.start()

-- ROAMING HERDS -- the PvE supply of piggies (docs/HERDS-PLAN.md).
--
-- After the plots, whose yards it must stay out of, and after SetService,
-- whose `grant`/`repaint` a catch lands through. THE YARD TEST ARRIVES AS A
-- VETO RATHER THAN A REQUIRE, so HerdService stays a leaf that requires
-- Config, Remotes, PiggyModel, DataService and SetService and nothing else
-- -- the same registry shape as the trampoline's bounce veto and the
-- held-item vetoes above, and for the same reason.
--
-- The boot audit first, because every number in `Config.HERDS` is a
-- placeholder and the failures it catches are numbers: a cap that is not a
-- tier, a roster row weighting a tier the cap forbids, a band with no depth.
-- Nothing errors on any of them; what they produce is a herd that never
-- comes or one walking through a fence.
do
	local problems = Config.auditHerds()
	if #problems > 0 then
		warn(("[Main] %d PROBLEMS IN THE HERD TABLE. See Config.HERDS."):format(#problems))
		for _, problem in ipairs(problems) do
			warn("[Main]   " .. problem)
		end
	end
end
local HerdService = require(Services.HerdService)
HerdService.addGroundVeto(function(position: Vector3): boolean
	return PlotService.yardContaining(position) ~= nil
end)
HerdService.addGroundVeto(require(ReplicatedStorage.Shared.Grassland).blocks) -- a pack steers round the ponds
HerdService.addGroundVeto(NeighborhoodService.treeBlocks) -- and round the trunks, never the canopies
HerdService.start()

-- WHAT MAY NOT BE DRAWN, AND WHY IT IS REGISTERED RATHER THAN REQUIRED.
--
-- HeldItemService requires DataService and nothing else, which is what lets
-- BoneService, GadgetService, HomeService and StealthService all require IT
-- with no cycle to think about. The two questions it cannot answer from down
-- there -- are you riding, are you inside a wheelie bin -- arrive as vetoes
-- filled in here, the same shape as the set pushers below and for the same
-- reason: the dependency list stays at one line and the cycle is impossible
-- rather than merely absent today.
--
-- Both states also PUT AWAY whatever is already in hand at the moment they
-- begin, in RideService.mount and StealthService's enterBin. These stop one
-- being drawn afterwards, which is the half a put-away cannot cover.
HeldItemService.addVeto(function(player)
	return if RideService.isRiding(player) then "Not while you're riding." else nil
end)
HeldItemService.addVeto(function(player)
	return if StealthService.isHidden(player) then "Not while you're hiding." else nil
end)

-- SETS PUSH THROUGH A REGISTRY, and this is the only place that can fill it.
--
-- A set spans five catalogues owned by two services, so granting a ride has
-- to tell RideService and granting a skin has to tell CosmeticsService. But
-- RideService requires HeistService, which requires SetService -- so
-- SetService requiring either of them directly is a cycle.
-- It holds a table of pushers instead, and Main is the one file that already
-- requires everything and can therefore wire them without a loop.
-- A SKIN IS A PIGGY NOW, SO ITS PUSHER HAS TO REPAINT THE PLOT AND NOT ONLY
-- THE HUD -- and until it did, a crate open was correct in the save and
-- invisible on the lawn.
--
-- `CosmeticsService.push` sends STATE to the client; `applyToPlot` is the one
-- whose job is making the plot match the data, and it is what dresses the six
-- pedestals. With only the former registered, `SetService.grant` wrote the
-- new piggy into a slot and nothing stood it up: measured live, a crate
-- rolled `skin:sunset` onto free slot 6 and that pedestal was still bare
-- afterwards, with the save perfectly correct. Nothing errors, and the crate
-- reads as having handed over nothing.
--
-- THIRD TIME THIS EXACT SHAPE HAS BITTEN in this feature alone -- a value
-- written and never republished. The other two were the till's own figure and
-- the buffers being published only when they moved. The rule stands: anything
-- that changes a pig has to republish it in the same breath.
--
-- The heavier call is affordable because a skin grant is a crate open rather
-- than a tick, and `applyToPlot` is idempotent.
SetService.registerPusher("skin", function(player: Player)
	CosmeticsService.applyToPlot(player)
	CosmeticsService.push(player)
end)
SetService.registerPusher("effect", CosmeticsService.push)
SetService.registerPusher("accessory", CosmeticsService.push)
SetService.registerPusher("decor", CosmeticsService.push)
SetService.registerPusher("ride", RideService.push)
-- The sixth kind. Registered the same day the catalogue landed rather
-- than the session after it: a kind with no pusher still GRANTS
-- correctly, so the failure is an item a player owns and cannot see
-- until something else happens to push -- which reads as the grant not
-- working and is the quietest possible way to be wrong.
SetService.registerPusher("catch", CosmeticsService.push)
-- Phase 5.3's season reward kinds. Ownership lives in four more tables, and
-- every one of them is drawn by the cosmetics push.
for _, kind in ipairs({ "finish", "plinth", "kennel", "coat" }) do
	SetService.registerPusher(kind, CosmeticsService.push)
end
-- Loot is spent in two places -- the set panel, which SetService pushes
-- itself, and the accessory roll, whose balance rides on CosmeticsService's
-- push -- so an award has to reach both.

-- THE TROPHY SHELF REACHES THE SHOP THE SAME WAY, AND FOR THE SAME REASON.
--
-- A trophy landing has to repaint the Decorations grid -- a card goes from
-- a locked progress bar to an owned tile -- and `CosmeticsService` requires
-- TrophyService for the progress it puts on that bar. Requiring it back
-- would be a cycle, so the push is registered from here, which requires
-- everything and can therefore wire the two without one.
TrophyService.registerPusher(CosmeticsService.push)

-- A SHOP VAULT CAN HAND OVER A CONSUMABLE, AND THE COUNT HAS TO REACH THE
-- HOT BAR IN THE SAME BREATH.
--
-- `data.consumables` is one flat table shared by four services and each
-- pushes its own slice of it, so a drop that wrote the count and told
-- nobody would land a Golden Bone in a save and leave the bar showing none
-- until the next purchase -- which is the shape the daily ladder's own bone
-- reward already has. HeistService cannot ask either service directly:
-- GadgetService requires IT. Registered from here, which requires
-- everything and can therefore wire the two without a cycle.
HeistService.registerStockPusher(BoneService.push)
HeistService.registerStockPusher(GadgetService.push)

-- Chests. Started after SetService, whose `owns`/`grant` it leans on for all
-- five catalogues rather than writing a second grant path.
-- What a chest has to tell the client when it takes payment. SetService.grant
-- covers the ITEM; these two cover the money, and the duplicate case pushes
-- nothing at all without them.
-- Skin theft, recovery and grants refresh buy-back eligibility immediately.
CosmeticsService.registerCollectionPusher(ChestService.push)
ChestService.registerBalancePusher(EconomyService.push)
ChestService.registerBalancePusher(CosmeticsService.push)
-- EVERY ANIMATION IN THIS GAME NEEDS AN UPLOADED ASSET, AND SAYS SO IF IT HAS
-- NONE. `RegisterKeyframeSequence` is Studio-only, so a published server plays
-- no dodge roll and poses no rider -- silently, because both readers pcall and
-- degrade. This is the one place that turns that into something a developer
-- sees. Same shape and same reason as PassService's unset game-pass warning.
do
	local missing = {}
	for _, key in ipairs(Config.animationKeys(RidePose.animationKeys())) do
		if not Config.animationId(key) then
			table.insert(missing, key)
		end
	end
	if #missing > 0 and not RunService:IsStudio() then
		warn(("[Main] %d animations have no uploaded id, so they will NOT play on "):format(#missing)
			.. "this server: " .. table.concat(missing, ", ")
			.. ". Run the `animdump` admin command in Studio, publish each, and put "
			.. "the ids in Config.ANIMATIONS.")
	end
end

-- THE CATALOGUE AND LADDER AUDIT, AND THIS IS WHERE IT GETS HEARD.
--
-- It used to check every price against the largest pig the game could
-- produce, because a bounded wallet made a price above it IMPOSSIBLE rather
-- than dear. The pig has no ceiling now, so `Config.auditEconomy` is
-- structural instead: retired gates, house ids, priced-or-earned, the
-- rebirth cash gate being complete, the rarity ladder being priced.
--
-- Loud in STUDIO as well as live, unlike the animation warning above -- that
-- one is about an asset that only fails when published, this one is about a
-- number, and the moment to hear about a number is while you are editing it.
do
	local problems = Config.auditEconomy()
	if #problems > 0 then
		-- ONE WARN PER PROBLEM, AND NO ESCAPE SEQUENCES ANYWHERE IN IT. The
		-- first draft of this joined them with a newline escape, and the
		-- escape was rewritten in transit into a REAL newline before it
		-- reached disk -- which ends the string literal mid-sentence and makes
		-- Luau refuse the whole chunk. This file is Main, so the cost of that
		-- is every service in the game rather than one warning. A format
		-- string with no backslash in it has nothing to get wrong.
		warn(("[Main] %d PROBLEMS IN THE ECONOMY AUDIT -- see Config.auditEconomy for "):format(#problems)
			.. "what each check is about.")
		for _, problem in ipairs(problems) do
			warn("[Main]   " .. problem)
		end
	end
end

-- AND SO IS WHETHER ROBBING IS WORTH DOING AT ALL, which is the number this
-- whole game is named after and the last one nothing checked.
--
-- The two audits above ask whether a price can be PAID. This one asks whether
-- the activity that pays for them is worth performing, which is the question
-- the economy was rebuilt around: before residents, robbing returned 7% of
-- idle income at level 0, so standing on your own lawn was the optimal way to
-- play a game about robbing people. Nothing errored then either.
--
-- It is the shape the other two already use because the failure is the same
-- shape: a number somebody retunes for a good local reason, with the damage
-- landing somewhere else entirely and nothing in the log to connect them. See
-- Config.ROBBERY_ADVANTAGE.
do
	local problems = Config.auditRobbery()
	if #problems > 0 then
		warn(("[Main] %d ROBBERY BALANCE PROBLEMS. "):format(#problems)
			.. "See Config.ROBBERY_ADVANTAGE and RESIDENTS.pigSeconds.")
		for _, problem in ipairs(problems) do
			warn("[Main]   " .. problem)
		end
	end
end

-- AND THE SERVER CAP IS A NUMBER THAT DOES NOT LIVE IN THIS REPO, which is
-- the one class the audits above cannot reach.
--
-- `Players.MaxPlayers` is READ ONLY from a script, so `default.project.json`
-- sets it and an already-published place keeps whatever it was configured
-- with -- the same trap as the `GearPreview` folder, state that lives in the
-- place rather than in `src/`, where nothing reconciles it. It used to matter
-- only because Main kicks anybody it cannot seat, which is the loud failure
-- and is what a cap ABOVE the plot count buys. It matters quietly too: a
-- resident is seated on every UNCLAIMED plot, so the number of robbable
-- houses is `PLOT_COUNT` less however many people are online. The four shop
-- shops are what stop that reaching zero -- see Config.SHOPS -- so a
-- misconfigured cap now costs turned-away players rather than the economy,
-- which is exactly the direction that failure should point.
do
	local live = Players.MaxPlayers
	if live ~= Config.MAX_PLAYERS then
		warn(("[Main] this place is configured for %d players and Config expects %d. "):format(
			live, Config.MAX_PLAYERS)
			.. (live > Config.PLOT_COUNT
				and ("There are only %d plots, so %d players would be turned away at the door. "):format(
					Config.PLOT_COUNT, live - Config.PLOT_COUNT)
				or ("A full server would hold %d resident houses plus %d shop vaults, against the %d permanent pigs the economy is audited at. "):format(
					math.max(0, Config.PLOT_COUNT - live), Config.SHOP_COUNT, Config.RESIDENT_FLOOR))
			.. "Fix it in File -> Game Settings -> World -> Max Player Count.")
	end
end

-- A FENCE HEIGHT IS A NUMBER TOO, and it fails the same silent way.
--
-- The fence stands on the world ground and the yard it encloses is a stud
-- higher, so a tier can be hoppable from the lawn and not from the street --
-- which nothing errors on and nothing looks wrong about. All three top tiers
-- shipped in that band: getting in was refused and getting out was free, so
-- the toll landed on the approach instead of the getaway, and the ladder that
-- exists to cross a fence would have been selling a way over a wall anybody
-- could step over. See Config.auditFences.
do
	local problems = Config.auditFences()
	if #problems > 0 then
		warn(("[Main] %d FENCE TIERS ARE HOPPABLE IN ONE DIRECTION ONLY. "):format(#problems)
			.. "See Config.BASE_JUMP_HEIGHT and Config.LAWN_LIFT.")
		for _, problem in ipairs(problems) do
			warn("[Main]   " .. problem)
		end
	end
end

-- IS THERE ROOM ON THE LAWN FOR THE SIX PEDESTALS? Six coordinates on a lawn
-- that already carries a twelve-stud piggy, a kennel, an oak, a basket, a
-- doorstep crate and the walk from the gate -- and every one of those is a
-- constant somebody may move for its own reasons. The failure is a number:
-- nothing errors, the pedestal builds, and what it produces is a display
-- piece standing inside a kennel or half through a house wall. Warned in
-- Studio too, for the reason `auditEconomy` is -- the moment to hear about a
-- number is while you are typing it. See Config.auditPiggySlots.
do
	local problems = Config.auditPiggySlots()
	if #problems > 0 then
		warn(("[Main] %d PIGGY PEDESTALS DO NOT FIT ON THE LAWN. "):format(#problems)
			.. "See Config.PIGGY_LAWN_SLOTS and Config.PIGGY_PEDESTAL.")
		for _, problem in ipairs(problems) do
			warn("[Main]   " .. problem)
		end
	end
end

-- DOES A REBIRTH STILL OPEN A DOOR? Indoor capacity is the one thing rebirth
-- is now the gate on, and the whole ladder hangs off a single fraction in
-- `Config.INDOOR.plotsPerRebirth` -- so a hand edit to it is a rebirth that
-- silently opens nothing, or a hallway three times longer than anybody
-- intended standing off-map once per plot. Nothing errors either way: the
-- corridor builds, the doors work, and the failure is a NUMBER. Warned in
-- Studio too, for the reason `auditEconomy` is -- the moment to hear about a
-- number is while you are typing it. See Config.auditIndoor.
do
	local problems = Config.auditIndoor()
	if #problems > 0 then
		warn(("[Main] %d PROBLEMS IN THE INDOOR CAPACITY LADDER. "):format(#problems)
			.. "See Config.INDOOR and Shared/HouseInterior.")
		for _, problem in ipairs(problems) do
			warn("[Main]   " .. problem)
		end
	end
end

-- CAN A STOLEN SKIN BE WON BACK? Taking a cosmetic off a real player is the
-- one place this game spends its "never lose permanent progress" rule, and
-- the whole thing rests on the loss being TIME rather than the item. That is
-- true only while every stealable skin is still in a crate somebody can open
-- -- a `chest` tag is a string with no compiler behind it, and a skin
-- pointing at a retired crate is one a child loses for good. See
-- Config.auditSkinSteal.
do
	local problems = Config.auditSkinSteal()
	if #problems > 0 then
		warn(("[Main] %d STOLEN SKINS COULD NOT BE WON BACK. "):format(#problems)
			.. "See Config.SKIN_STEAL and Config.isStealableSkin.")
		for _, problem in ipairs(problems) do
			warn("[Main]   " .. problem)
		end
	end
end

-- CAN ANYBODY WALK ABOUT IN A SHOP? A fitting is sized against the thing it
-- IS, and a room is what several of them add up to -- which is how a display
-- case correct on its own came to leave 1.45 studs between itself and the
-- counter, on the one patch of floor a customer stands on. Nothing errors,
-- nothing looks wrong in any number the builder prints, and the only symptom
-- is a figure that cannot get where it is going. Warned in Studio too, for
-- the reason `auditEconomy` is: this is about a number.
do
	local problems = Config.auditShopRoom()
	for _, problem in ipairs(problems) do
		warn("[Main] shop room: " .. problem)
	end
end

-- IS AN AIMED THROW STILL FLAT UP CLOSE AND A LOB FAR OUT? See
-- `Config.auditThrow`: the feel of the whole gadget tree is one relationship
-- between `THROW.speed`, `THROW.gravity` and each gadget's own range, and
-- getting it wrong produces a mechanic that reads as a broken item rather
-- than as anything that errors. Warned in Studio as well as live, for the
-- reason `auditEconomy` is: this is about a NUMBER, and the moment to hear
-- about a number is while you are typing it.
do
	local problems = Config.auditThrow()
	for _, problem in ipairs(problems) do
		warn("[Main] throw balance: " .. problem)
	end
end

-- Phase 5: every season tier must promise something that exists, and every
-- finish must stay season-only and dim.
do
	for _, problem in ipairs(Config.auditSeason()) do
		warn("[Main] season: " .. problem)
	end
end

-- THE RANDOM-OUTCOME SWEEP, which is the one that is left and the one that
-- matters most now.
--
-- It stood beside an Acorn faucet audit that modelled how fast a tree filled
-- and what a crate therefore cost. Both went with the currency. What this one
-- guards is sharper than either: a crate must carry NO price, because the day
-- one does, every crate in the game is a paid random item under Roblox's rule
-- and needs disclosed odds and a `PolicyService` gate before it may be sold.
-- Warned rather than fatal, like the audits around it.
do
	local ok, problems = pcall(Config.auditRandomOutcomes)
	if not ok then
		warn("[Main] random-outcome sweep could not run: " .. tostring(problems))
	else
		for _, problem in ipairs(problems) do warn("[Main] random-outcome sweep: " .. problem) end
	end
end

ChestService.start()

-- A trampoline refuses anybody mid-heist, and this is where that is wired.
--
-- Same shape and same reason as the pushers above: PlotService cannot ask
-- HeistService whether somebody is carrying loot, because HeistService already
-- requires PlotService. Registering the question here keeps both dependency
-- lists at one line -- and it is what makes "a decoration never changes an
-- outcome" true by construction rather than by argument.
PlotService.registerBounceVeto(HeistService.isCarrying)
-- Five wanted stars call the patrol out early. SocialService cannot require
-- PoliceService (which requires it), so the consequence is registered here.
SocialService.registerStarAlarm(function()
	PoliceService.call()
end)

-- AND THE SAME ARROW AGAIN FOR WHAT A PIGGY EARNS. `PlotService` builds the
-- rate row under each pedestal's name and cannot work out what to print on
-- it: the live figure folds in a friend bonus and a daily boost, which means
-- asking EconomyService, which already requires PlotService. Without this
-- one line the labels build and stay blank -- a failure that looks exactly
-- like the feature not existing, which is why it is registered beside the
-- veto above rather than somewhere a reader has to go looking for it.
PlotService.registerPiggyRates(EconomyService.pedestalRates)

-- AND THE OTHER THING A THIEF CAN BE CARRYING.
--
-- `PiggyHaulService` requires `HeistService` -- it needs the shield, the
-- dodge immunity and the one function that owns every speed rule in the game
-- -- so `HeistService` cannot ask back. Registered here, the same shape as
-- the bounce veto above and the set pushers below it, which keeps both
-- dependency lists at one line and makes the cycle impossible rather than
-- merely absent today.
--
-- WHAT THE THREE ARE FOR. `isHauling` is what makes "is this player
-- carrying" ONE question with one answer however many kinds of thing there
-- turn out to be -- the carry speed penalty, the ride refusal, the disguise
-- breaking and the dog hearing a loaded thief all read it. `nab` is the seam
-- every catcher in the game already comes through, so a guard dog, a
-- shopkeeper and a bystander all stop a piggy thief without one of them being
-- the exception somebody forgot. `confiscate` is the patrol's, and without it
-- an arrest would hold a thief still, charge them nothing and leave the piggy
-- under their arm.
HeistService.registerPiggyHaul(
	PiggyHaulService.isHauling,
	PiggyHaulService.nab,
	PiggyHaulService.confiscate)

-- A NEIGHBOUR GOING OUT ROBBING NEEDS THE HEIST'S OWN ACCOUNTING, and cannot
-- ask for it: HeistService already requires ResidentService, so the arrow only
-- runs one way. Registered here for the same reason the bounce veto and the
-- set pushers are, which keeps both dependency lists at one line and makes the
-- cycle impossible rather than merely absent today.
--
-- What this actually buys is that `Config.LOSS_CAP` has exactly ONE
-- implementation. A resident thief and a player thief take coins through the
-- same allowance, so the protection standing between a real child and being
-- emptied cannot drift apart into two versions -- and one of those versions
-- would be the one nobody is testing.
ResidentService.registerTake(HeistService.residentTake)
ResidentService.registerGiveBack(HeistService.residentGiveBack)
-- AND THE PIGGY SNATCH, THROUGH THE SERVICE THAT OWNS IT, for the identical
-- reason: `PiggyHaulService` requires `ResidentService`. A neighbour's grab
-- off a plinth and the put-back on a nab both run the player's own path, so
-- the per-victim cooldown, the shield and the victim's alarm have exactly
-- one implementation.
ResidentService.registerSnatch(PiggyHaulService.residentSnatch)
ResidentService.registerPiggyReturn(PiggyHaulService.residentReturn)
-- The shopkeeper's catch, through the same accounting a guard dog's catch
-- uses. Registered rather than required, because `HeistService` already
-- requires `ResidentService` and asking back would be a cycle.
ResidentService.registerCatch(HeistService.shopkeeperCatch)
-- A player's nab effect going off on a neighbour they nabbed.
ResidentService.registerCatchEffect(CosmeticsService.fireCatchEffect)
-- The neighbour's throw. A registry for the same reason the catch is one:
-- `GadgetService` requires `ResidentService`, so asking the other way round
-- would be a cycle.
ResidentService.registerThrow(GadgetService.neighbourThrow)
-- Last: it reaches into every service above.
AdminService.start()

local function onCharacterAdded(player: Player, character: Model)
	local plot = PlotService.getPlot(player)
	if not plot then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if root then
		root.CFrame = PlotService.getSpawnCFrame(plot)
	end

	-- Most Wanted gear is welded to the Head, so it dies with the character it
	-- was welded to and has to be put back on every new one. This is also the
	-- only place it can be done: the head does not exist until the character
	-- does, and nothing else fires when one is replaced.
	character:WaitForChild("Head", 10)
	CosmeticsService.applyToCharacter(player)
end

local function onPlayerAdded(player: Player)
	local data = DataService.load(player)

	if not data then
		-- Someone else holds the session lock, or the datastore is down.
		-- Kicking is the correct call: letting them play against state we
		-- can't save is how progress gets silently lost.
		player:Kick("Couldn't load your save. Please rejoin in a moment.")
		return
	end

	local plot = PlotService.assign(player)
	if not plot then
		player:Kick("This server is full. Please try another.")
		return
	end

	SocialService.onPlayerAdded(player)
	EconomyService.onPlayerReady(player)
	UpgradeService.applyToPlot(player)
	UpgradeService.push(player)
	ProgressionService.push(player)
	CosmeticsService.applyToPlot(player)
	CosmeticsService.push(player)
	-- The nemesis line (Phase 5).
	SeasonService.onPlayerAdded(player)
	HeistService.onPlayerAdded(player)
	BoneService.push(player)
	GadgetService.push(player)
	HomeService.push(player)
	StealthService.push(player)
	RideService.push(player)
	RideService.onPlayerReady(player)
	-- Before the HUD can want it: the client keeps the music silent until this
	-- arrives, so a player who turned it off never hears a burst on joining.
	SettingsService.push(player)
	SetService.push(player)
	ChestService.push(player)
	DailyService.onPlayerReady(player)
	-- Last of the ride chain, and deliberately after the push: the ownership
	-- check is a web call that yields, so it lands a moment later and pushes
	-- again by itself. Waiting for it here would hold up the whole join.
	PassService.onPlayerReady(player)
	AdminService.push(player)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end

	print(("[Main] %s joined -> Plot%d (%s coins in the pig, session %d)"):format(
		player.Name,
		plot.index,
		EconomyService.format(data.coins),
		data.sessions or 0
	))
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

print(("[Main] Ready -- %d plots, %s base income/sec"):format(Config.PLOT_COUNT, Config.BASE_INCOME))
