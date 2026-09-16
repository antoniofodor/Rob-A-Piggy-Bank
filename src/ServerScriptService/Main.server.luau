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
EconomyService.start()
UpgradeService.start()
ProgressionService.start()
CosmeticsService.start()
HeistService.start()
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
-- RideService requires HeistService, which requires EventService, which needs
-- SetService -- so SetService requiring either of them directly is a cycle.
-- It holds a table of pushers instead, and Main is the one file that already
-- requires everything and can therefore wire them without a loop.
SetService.registerPusher("skin", CosmeticsService.push)
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
-- Loot is spent in two places -- the set panel, which SetService pushes
-- itself, and the accessory roll, whose balance rides on CosmeticsService's
-- push -- so an award has to reach both.
SetService.registerLootPusher(CosmeticsService.push)

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

-- EVERY PRICE HAS TO FIT IN A PIG, AND THIS IS WHERE THAT GETS CHECKED.
--
-- The pig is the wallet now, so a price above capacity is not an expensive
-- thing, it is an IMPOSSIBLE one -- and it fails silently, as a button that
-- never lights. `Config.auditEconomy` walks both upgrade ladders, every
-- catalogue and every rebirth gate against the largest pig the game can
-- produce. See `Config.UPGRADE_COST_CEILING`: the trees hold by construction,
-- so anything this finds is a catalogue price somebody has just typed.
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
		warn(("[Main] %d PRICES CANNOT BE PAID -- the pig cannot hold them, so "):format(#problems)
			.. "nobody can ever buy them by earning. See Config.UPGRADE_COST_CEILING.")
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

-- Phase 1.9 audits warn without blocking startup. Tree figures are a model
-- of full capture at parity, not observed live earning rates. Resident seed
-- is one-off server stock and is excluded from hourly production.
do
	for _, audit in ipairs({ { name = "Acorns", run = Config.auditAcorns }, { name = "random-outcome sweep", run = Config.auditRandomOutcomes } }) do
		local ok, problems = pcall(audit.run)
		if not ok then
			warn("[Main] " .. audit.name .. " audit could not run: " .. tostring(problems))
		else
			for _, problem in ipairs(problems) do warn("[Main] " .. audit.name .. ": " .. problem) end
		end
	end
	local ok, solo, full = pcall(function()
		return Config.acornRates(1), Config.acornRates(Config.MAX_PLAYERS)
	end)
	if ok then
		print(("[Main] Acorn new-growth model (full capture, parity; seed/re-raids excluded): solo %.2f/full %.2f per thief-hour; active/passive %.2fx/%.2fx; full-server common %.1f min, legendary %.2f h")
			:format(solo.perThiefPerHour, full.perThiefPerHour, solo.activeRatio, full.activeRatio, full.commonMinutes, full.legendaryHours))
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
-- The shopkeeper's catch, through the same accounting a guard dog's catch
-- uses. Registered rather than required, because `HeistService` already
-- requires `ResidentService` and asking back would be a cycle.
ResidentService.registerCatch(HeistService.shopkeeperCatch)
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
