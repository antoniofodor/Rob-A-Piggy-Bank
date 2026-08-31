--!strict
--[[
	Remotes

	Single place where every client/server channel is declared, so there's
	one list to audit when checking what a client is allowed to ask for.

	The server creates the instances; the client waits for them. Any new
	remote goes in DEFINITIONS and nowhere else.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DEFINITIONS = {
	-- Client asks to bank their uncollected coins. Server decides how much.
	CollectRequest = "RemoteEvent",

	-- Client asks to buy an upgrade: ("income" | "capacity").
	PurchaseRequest = "RemoteEvent",

	-- Server pushes the authoritative snapshot of a player's own state.
	StateUpdate = "RemoteEvent",

	-- Server tells a client something worth a toast ("Banked 4,210 coins").
	Notify = "RemoteEvent",

	-- How much loot the player is currently carrying (0 when empty-handed).
	CarryUpdate = "RemoteEvent",

	-- Client asks to buy a defence or offence upgrade, by key.
	UpgradeRequest = "RemoteEvent",

	-- Server pushes the player's upgrade levels, costs and caps.
	UpgradeState = "RemoteEvent",

	-- Client asks to rebirth; server pushes rebirth count and readiness.
	RebirthRequest = "RemoteEvent",
	RebirthState = "RemoteEvent",

	-- Sent only to a robbery's victim: which plot to go and hit back.
	RevengeMarker = "RemoteEvent",

	-- Client buys or equips a skin/effect; server pushes the collection.
	CosmeticRequest = "RemoteEvent",
	CosmeticState = "RemoteEvent",

	-- Admin console. Every request is re-authorised server-side against the
	-- allowlist; the existence of this channel grants nobody anything.
	AdminRequest = "RemoteEvent",
	AdminState = "RemoteEvent",
}

local Remotes = {}

local folder: Folder

if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for name, className in pairs(DEFINITIONS) do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Remotes.get(name: string): RemoteEvent
	assert(DEFINITIONS[name], ("Unknown remote '%s' -- add it to Remotes.DEFINITIONS"):format(name))
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
