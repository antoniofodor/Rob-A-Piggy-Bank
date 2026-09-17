-- Temporary Studio server fixture. Map/copy into ServerScriptService only
-- for a local play test; remove afterwards. It sends cosmetic packets only:
-- no DataService, award, charge, stock, rank or claim changes.
-- Set workspace._LootReview.Phase to "reveal" to advance from odds to reel.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local marker = Instance.new("Folder")
marker.Name = "_LootReview"
marker:SetAttribute("Phase","odds")
marker.Parent = workspace
local seen = {}
local function review(player: Player)
	if seen[player] then return end
	seen[player] = true
	-- Client-created HUD instances do not replicate to this server fixture.
	if not player.Character then player.CharacterAdded:Wait() end
	task.wait(10)
	local odds=Config.shopLootOdds("gear",100,function() return false end)
	Remotes.get("CrackState"):FireClient(player,{victim="TEST PREVIEW",pig=10000,
		banked=2000,floor=0,step=2,maxSteps=5,slice=1000,zone=.4,width=.2,
		startedAt=workspace:GetServerTimeNow(),sweep=3,loot=odds})
	marker:SetAttribute("Ready",true)
	repeat marker:GetAttributeChangedSignal("Phase"):Wait() until marker:GetAttribute("Phase")=="reveal"
	Remotes.get("CrackState"):FireClient(player,nil)
	local won
	for _,item in ipairs(odds.pool) do if item.key=="scrambler" then won=item end end
	assert(won,"approved Legendary ride missing")
	Remotes.get("RobberyLoot"):FireClient(player,{pool=odds.pool,won=won,
		mode="carried",coins=0,chance=odds.chance,odds=won.odds,shop="gear"})
end
Players.PlayerAdded:Connect(function(player) task.spawn(review,player) end)
for _,player in Players:GetPlayers() do task.spawn(review,player) end
