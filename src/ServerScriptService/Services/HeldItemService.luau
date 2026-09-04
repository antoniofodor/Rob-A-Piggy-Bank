--!strict
--[[
	HeldItemService

	What each player is holding out, and the one place that decides it.

	----------------------------------------------------------------------

	SELECTING IS FREE; USING SPENDS. That split is the whole feature.

	A number key or a tile tap now EQUIPS, which costs nothing and can be
	undone by pressing the same key again. Only a deliberate click in the
	world spends the item. The reasoning is written up in `Shared/HeldItem`,
	but the short version is that the old one-press path had a
	30,000-coin Golden Bone one stray thumb away from gone, and hid the
	entire consumable layer from everybody else on the street until the
	instant it went off.

	----------------------------------------------------------------------

	THE SERVER OWNS IT, AND THE STOCK CHECK IS WHY.

	The obvious cheap version is a client-side selection with a local model,
	and it is wrong on this game's own terms: what somebody is holding is now
	a TELL that other players act on, so a client that could show itself
	holding a Golden Bone it does not own would be lying to the street about
	the street. Every equip is therefore validated against `data.consumables`
	-- the same table all four services already spend from -- before a single
	part is built.

	----------------------------------------------------------------------

	AND THE USE IS GUARDED, WHICH IS WHAT KEEPS THE TELL HONEST.

	`holding` is asked by BoneService, GadgetService, HomeService and
	StealthService at the top of their use paths. Without it the prop would
	be decoration over an unchanged remote: a client could throw a bone it
	never visibly drew, and a defender reading an empty pair of hands would
	be reading a lie. The refusal is LOUD and names the fix, because a
	rejection nobody can see is indistinguishable from a broken feature.

	It is a LEAF. This file requires DataService and nothing else, so the
	four services above can require it with no cycle to think about. What it
	cannot do from here -- ask whether somebody is riding, or standing inside
	a wheelie bin -- arrives as a VETO that `Main` registers, the same shape
	`SetService.registerPusher` already uses and for the same reason: keeping
	the dependency list at one line makes the cycle impossible rather than
	merely absent today.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HeldItem = require(ReplicatedStorage.Shared.HeldItem)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local HeldItemService = {}

local equipped: { [Player]: string } = {}

-- Reasons a player may not draw something right now, registered by `Main`.
-- Each returns a refusal string, or nil to allow.
local vetoes: { (Player) -> string? } = {}

function HeldItemService.addVeto(fn: (Player) -> string?)
	table.insert(vetoes, fn)
end

local function notify(player: Player, message: string, kind: string)
	Remotes.get("Notify"):FireClient(player, message, kind)
end

local function stockOf(player: Player, key: string): number
	local data = DataService.get(player)
	if not data or type(data.consumables) ~= "table" then
		return 0
	end
	return data.consumables[key] or 0
end

-- ============================================================
-- READING
-- ============================================================

function HeldItemService.get(player: Player): string?
	return equipped[player]
end

function HeldItemService.holding(player: Player, key: string): boolean
	return equipped[player] == key
end

-- ============================================================
-- PUTTING AWAY
-- ============================================================
--
-- `why` is optional and only ever a courtesy. Something the player did
-- themselves -- pressing the key again -- says nothing; something the game
-- did to them, like mounting a ride, says so, because a prop vanishing out
-- of your own hand with no explanation reads as a bug.

function HeldItemService.putAway(player: Player, why: string?)
	if not equipped[player] then
		return
	end
	equipped[player] = nil

	local character = player.Character
	if character then
		HeldItem.detach(character)
		character:SetAttribute(HeldItem.ATTRIBUTE, nil)
	end
	if why then
		notify(player, why, "warn")
	end
end

-- Called after anything that can change a stock. An item spent down to
-- nothing has to leave the hand, or the player is left holding a prop that
-- refuses every click -- which is the exact "rejection nobody can see"
-- failure this codebase keeps writing rules about, wearing a picture.
function HeldItemService.revalidate(player: Player)
	local key = equipped[player]
	if key and stockOf(player, key) <= 0 then
		HeldItemService.putAway(player)
	end
end

-- ============================================================
-- DRAWING
-- ============================================================

function HeldItemService.equip(player: Player, key: string): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return false
	end

	local spec = HeldItem.specFor(key)
	if not spec then
		-- Not a real consumable. Silent, because the only way to reach this
		-- is a forged request: a refusal toast here would be a message the
		-- honest client can never see and the dishonest one does not read.
		return false
	end

	if stockOf(player, key) <= 0 then
		notify(player, ("You have no %s left."):format(spec.name), "warn")
		return false
	end

	for _, veto in ipairs(vetoes) do
		local refusal = veto(player)
		if refusal then
			notify(player, refusal, "warn")
			return false
		end
	end

	equipped[player] = key
	HeldItem.attach(character, key)
	-- Published even if the model failed to build. The HUD reads this to know
	-- which tile is lit and what a click means, and a player who can see the
	-- selection but not the prop has a cosmetic fault; one who can see
	-- neither has an item that appears not to work.
	character:SetAttribute(HeldItem.ATTRIBUTE, key)
	return true
end

-- The client's whole vocabulary: a key to draw, or nothing to put away.
-- Asking for what is already in hand puts it away, because a toggle is what
-- a single button means everywhere else in this game -- accessories,
-- decorations and rides all work this way.
function HeldItemService.request(player: Player, key: string?)
	if key == nil or equipped[player] == key then
		HeldItemService.putAway(player)
		return
	end
	HeldItemService.equip(player, key)
end

-- ============================================================
-- LIFECYCLE
-- ============================================================

function HeldItemService.clear(player: Player)
	equipped[player] = nil
end

function HeldItemService.start()
	Remotes.get("EquipRequest").OnServerEvent:Connect(function(player, key)
		if key ~= nil and type(key) ~= "string" then
			return
		end
		HeldItemService.request(player, key)
	end)

	-- A NEW CHARACTER COMES OUT EMPTY-HANDED, and the table has to agree.
	--
	-- The prop is welded to the OLD character's hand, so a respawn destroys
	-- it along with everything else -- but `equipped` would go on naming it,
	-- and `holding` would then wave through a use for an item nobody can see
	-- anybody carrying. That is precisely the lie the guard exists to stop,
	-- arriving through the one door that does not go past `putAway`.
	--
	-- Connected for players ALREADY here as well as for new ones. A
	-- CharacterAdded hook connected only inside PlayerAdded never fires for
	-- the first player into a server or for anybody in Play Solo, which is
	-- how the wheelie bins shipped a dead handler that went unnoticed for
	-- the whole life of the disguise.
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			equipped[player] = nil
		end)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		equipped[player] = nil
	end)
end

return HeldItemService
