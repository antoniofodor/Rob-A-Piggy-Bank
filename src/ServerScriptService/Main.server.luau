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
local EventService = require(Services.EventService)
local SetService = require(Services.SetService)
local ChestService = require(Services.ChestService)
local DailyService = require(Services.DailyService)
local PassService = require(Services.PassService)
local AdminService = require(Services.AdminService)

DataService.start()
WorldService.start()
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
-- Loot is spent in two places -- the set panel, which SetService pushes
-- itself, and the accessory roll, whose balance rides on CosmeticsService's
-- push -- so an award has to reach both.
SetService.registerLootPusher(CosmeticsService.push)

-- Chests. Started after SetService, whose `owns`/`grant` it leans on for all
-- five catalogues rather than writing a second grant path.
-- What a chest has to tell the client when it takes payment. SetService.grant
-- covers the ITEM; these two cover the money, and the duplicate case pushes
-- nothing at all without them.
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

ChestService.start()

-- A trampoline refuses anybody mid-heist, and this is where that is wired.
--
-- Same shape and same reason as the pushers above: PlotService cannot ask
-- HeistService whether somebody is carrying loot, because HeistService already
-- requires PlotService. Registering the question here keeps both dependency
-- lists at one line -- and it is what makes "a decoration never changes an
-- outcome" true by construction rather than by argument.
PlotService.registerBounceVeto(HeistService.isCarrying)
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
