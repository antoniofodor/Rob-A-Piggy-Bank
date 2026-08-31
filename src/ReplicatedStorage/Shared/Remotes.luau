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

	-- Client buys a bone; server pushes how many of each the player holds.
	GearRequest = "RemoteEvent",
	GearState = "RemoteEvent",

	-- Client asks to throw a bone. It sends the BONE KEY AND NOTHING ELSE --
	-- no position, no target. The server picks the dog from its own
	-- authoritative positions, so there is no coordinate here to forge.
	BoneThrow = "RemoteEvent",

	-- Client buys, or uses, an item on their OWN plot. HomeUse carries a key
	-- and NO target: the server acts on the caller's own plot or on nothing,
	-- so there is no player here that could be named.
	HomeRequest = "RemoteEvent",
	HomeUse = "RemoteEvent",
	HomeState = "RemoteEvent",

	-- Client buys a gadget; server pushes how many of each they hold.
	GadgetRequest = "RemoteEvent",
	GadgetState = "RemoteEvent",

	-- Client asks to throw a gadget. Like BoneThrow it sends the KEY AND
	-- NOTHING ELSE. The server picks the target from its own list of who is
	-- carrying loot, so there is no position to forge, no range check to
	-- defeat, and no way to name a victim who is not currently robbing anyone.
	GadgetThrow = "RemoteEvent",

	-- Client buys or puts away a ride; server pushes what they own and
	-- whether they are on one right now. There is no "mount" request: getting
	-- on is decided by the server from where the player is standing, so there
	-- is no message here that could ask to be riding somewhere they may not.
	RideRequest = "RemoteEvent",
	RideState = "RemoteEvent",

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
