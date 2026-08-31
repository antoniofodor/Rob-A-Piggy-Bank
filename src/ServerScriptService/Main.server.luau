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
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Services = script.Parent:WaitForChild("Services")
local DataService = require(Services.DataService)
local WorldService = require(Services.WorldService)
local NeighborhoodService = require(Services.NeighborhoodService)
local PlotService = require(Services.PlotService)
local SocialService = require(Services.SocialService)
local EconomyService = require(Services.EconomyService)
local UpgradeService = require(Services.UpgradeService)
local ProgressionService = require(Services.ProgressionService)
local CosmeticsService = require(Services.CosmeticsService)
local HeistService = require(Services.HeistService)
local BoneService = require(Services.BoneService)
local RideService = require(Services.RideService)
local GadgetService = require(Services.GadgetService)
local AdminService = require(Services.AdminService)

DataService.start()
WorldService.start()
-- After the ground exists, before the plots: pure scenery, no dependencies.
NeighborhoodService.start()
PlotService.start()
SocialService.start()
EconomyService.start()
UpgradeService.start()
ProgressionService.start()
CosmeticsService.start()
HeistService.start()
BoneService.start()
-- Both reach into HeistService, so they start after it.
GadgetService.start()
RideService.start()
-- Last: it reaches into every service above.
AdminService.start()

-- Only the plot's owner can bank from it. The steal prompt on the same piggy
-- is wired by HeistService, and both re-check ownership server-side -- the
-- client only decides which of the two to draw.
for _, plot in ipairs(PlotService.getAll()) do
	plot.prompt.Triggered:Connect(function(player)
		if plot.owner == player then
			EconomyService.collect(player)
		end
	end)
end

local function onCharacterAdded(player: Player, character: Model)
	local plot = PlotService.getPlot(player)
	if not plot then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if root then
		root.CFrame = PlotService.getSpawnCFrame(plot)
	end
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

	-- Only show the prompt to the owner; nobody else has a reason to see it.
	plot.prompt:SetAttribute("OwnerUserId", player.UserId)

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
	RideService.push(player)
	AdminService.push(player)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end

	print(("[Main] %s joined -> Plot%d (%s coins banked, %s in vault)"):format(
		player.Name,
		plot.index,
		EconomyService.format(data.coins),
		EconomyService.format(data.vault)
	))
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

print(("[Main] Ready -- %d plots, %s base income/sec"):format(Config.PLOT_COUNT, Config.BASE_INCOME))
