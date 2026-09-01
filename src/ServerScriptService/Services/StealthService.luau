--!strict
--[[
	StealthService

	The thief's two consumables: the Disguise Kit and the Raincoat.

	These exist because the offence tree was left behind. Gadgets closed the
	maxed-boots hole and the Guard Duty Treat closed the cheap-bone hole, and
	both landed with nothing given back to the people they were aimed at.

	THE DISGUISE HIDES THE WAIT, NEVER THE GETAWAY.

	Worth being honest about what it is for. The guard dog does not watch an
	approach: GuardDog.chase only fires from HeistService.attemptSteal, after a
	completed steal. Walking up to somebody's piggy was never dangerous, so a
	sneaking tool would have been solving a problem this game does not have.

	It is a WAITING tool. You stand on a lawn as a wheelie bin while a vault
	fills, or while a sixty-second steal cooldown runs out, or through six
	minutes of guard duty until the collar stops glowing. That last one is the
	good one: it puts the treat and the disguise in an argument with each other
	rather than adding a number to either side.

	Two rules hold it in place, and the first is why it needs no timer worth
	tuning:

	  * STANDING STILL IS THE DISGUISE. Drift more than a few studs and it
	    drops. That is self-limiting by construction -- it cannot help you run
	    anywhere, because running is what ends it.
	  * IT BREAKS THE INSTANT LOOT IS PICKED UP. No exception, no grace. The
	    run home is the risk half of the entire trade and has to stay visible,
	    and a thief who could carry a piggy while looking like a bin would end
	    the chase before it started.

	It survives the LOCK HOLD on purpose, which is the joke: a wheelie bin
	quietly cracking somebody's piggy is worth four thousand coins on its own.
	The hold does not move you, so nothing special is needed to allow it.

	THE RAINCOAT MIRRORS THE GUARD DUTY TREAT.

	The two cheap gadgets slide off; the Zapper still lands. Same shape as the
	treat on the other side of the fight -- cheap counters bounce, the
	expensive one gets through -- and it does the same job, raising the price
	of stopping somebody from 1,500 to 22,000 rather than making them
	unstoppable.

	Neither of these touches SPEED, which stays capped at 16.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local HeistService = require(script.Parent.HeistService)
local Decor = require(script.Parent.Decor)

local StealthService = {}

type Hidden = {
	prop: Model,
	anchor: Vector3,
	until_: number,
	hiddenParts: { { part: BasePart, transparency: number } },
	nameMode: Enum.HumanoidDisplayDistanceType?,
}

local hidden: { [Player]: Hidden } = {}

local function notify(player: Player, message: string, kind: string)
	Remotes.get("Notify"):FireClient(player, message, kind)
end

-- Shared with bones, gadgets and home items. Same reasoning every time: these
-- are things you hold a stock of and spend, the keys cannot collide, and
-- sharing means they inherit the rebirth rule for free.
local function stock(data: any): { [string]: number }
	if type(data.consumables) ~= "table" then
		data.consumables = {}
	end
	return data.consumables
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- ============================================================
-- THE DISGUISE
-- ============================================================

local function reveal(player: Player, why: string?)
	local state = hidden[player]
	if not state then
		return
	end
	hidden[player] = nil

	if state.prop.Parent then
		state.prop:Destroy()
	end

	-- Restore the recorded value rather than setting 0. Some of what gets
	-- hidden was already partly transparent -- a jetpack's exhaust, a cape's
	-- cloth -- and forcing everything opaque would repaint accessories the
	-- player bought.
	for _, entry in ipairs(state.hiddenParts) do
		if entry.part.Parent then
			entry.part.Transparency = entry.transparency
		end
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and state.nameMode then
		humanoid.DisplayDistanceType = state.nameMode
	end

	if why then
		notify(player, why, "warn")
	end
	StealthService.push(player)
end

local function conceal(player: Player, spec: any): boolean
	local character = player.Character
	local root = getRoot(player)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not root or not humanoid then
		return false
	end

	if hidden[player] then
		notify(player, "You're already hidden.", "warn")
		return false
	end

	-- Refused before the kit is spent: a disguise that drops instantly is
	-- indistinguishable from one that never worked.
	if HeistService.isCarrying(player) then
		notify(player, "You can't hide while you're carrying loot.", "warn")
		return false
	end

	-- The floor under the character, so the prop stands on the ground rather
	-- than at hip height. Same formula RideService uses, and measured against
	-- a raycast there at 0.002 studs out.
	local at = root.CFrame * CFrame.new(0, -(humanoid.HipHeight + root.Size.Y / 2), 0)
	-- Square to the world, never to the player. Ornaments do not stand at a
	-- jaunty angle, and a bin rotated fifteen degrees off true is the one
	-- detail that gives the whole thing away.
	local flat = CFrame.new(at.Position)

	local prop = Decor.buildOne(spec.prop, flat, workspace)
	if not prop then
		return false
	end
	prop.Name = "Disguise"

	local hiddenParts = {}
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(hiddenParts, { part = d, transparency = d.Transparency })
			d.Transparency = 1
		elseif d:IsA("Decal") then
			table.insert(hiddenParts, { part = d :: any, transparency = d.Transparency })
			d.Transparency = 1
		end
	end

	-- The nameplate has to go too. A wheelie bin with somebody's username
	-- floating over it is not a disguise, it is a label.
	local nameMode = humanoid.DisplayDistanceType
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	hidden[player] = {
		prop = prop,
		anchor = root.Position,
		until_ = os.clock() + spec.maxSeconds,
		hiddenParts = hiddenParts,
		nameMode = nameMode,
	}

	notify(player, "Hidden. Stand still -- moving gives you away.", "good")
	return true
end

-- Polled, for the reason the dog's patrol is: the four things that end a
-- disguise -- moving, grabbing loot, dying, running out the clock -- change
-- independently of each other and of anything this module could listen to.
local function step()
	for player, state in pairs(hidden) do
		local root = getRoot(player)

		if not root then
			reveal(player, nil)
		elseif HeistService.isCarrying(player) then
			-- Non-negotiable. The run home stays visible.
			reveal(player, "You grabbed the loot -- disguise blown!")
		elseif (root.Position - state.anchor).Magnitude > (Config.THIEF_KIT.disguise.drift or 4) then
			reveal(player, "You moved -- disguise dropped.")
		elseif os.clock() > state.until_ then
			reveal(player, "Your disguise wore off.")
		end
	end
end

-- ============================================================
-- BUYING AND USING
-- ============================================================

function StealthService.buy(player: Player, key: string)
	local spec = Config.THIEF_KIT[key]
	local data = DataService.get(player)
	if not spec or not data then
		return
	end

	if data.coins < spec.cost then
		notify(player, ("Need %d more coins for a %s."):format(spec.cost - data.coins, spec.name), "warn")
		return
	end

	data.coins -= spec.cost
	stock(data)[key] = (stock(data)[key] or 0) + 1

	notify(player, ("%s bought -- you have %d."):format(spec.name, stock(data)[key]), "good")
	DataService.save(player)
	StealthService.push(player)
end

function StealthService.use(player: Player, key: string)
	local spec = Config.THIEF_KIT[key]
	local data = DataService.get(player)
	if not spec or not data then
		return
	end

	local held = stock(data)[key] or 0
	if held <= 0 then
		notify(player, ("You have no %s left."):format(spec.name), "warn")
		return
	end

	local used = false
	if spec.style == "disguise" then
		used = conceal(player, spec)
	elseif spec.style == "raincoat" then
		if HeistService.isWarded(player) then
			notify(player, "You're already wearing one.", "warn")
		else
			HeistService.setWard(player, true)
			notify(player, "Raincoat on -- the next plunger or gum slides off.", "good")
			used = true
		end
	end

	if not used then
		return
	end

	stock(data)[key] = held - 1
	DataService.save(player)
	StealthService.push(player)
end

-- Public so RideService can refuse to mount over a disguise. Without it a
-- board mounted AFTER concealing is not in the hidden-parts list, and the
-- result is a wheelie bin with a floating motorbike parked in it.
function StealthService.isDisguised(player: Player): boolean
	return hidden[player] ~= nil
end

function StealthService.push(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end

	local held = stock(data)
	local list = {}
	for key, spec in pairs(Config.THIEF_KIT) do
		list[key] = {
			name = spec.name,
			order = spec.order,
			cost = spec.cost,
			blurb = spec.blurb,
			detail = spec.detail,
			held = held[key] or 0,
		}
	end

	Remotes.get("StealthState"):FireClient(player, {
		items = list,
		disguised = hidden[player] ~= nil,
		warded = HeistService.isWarded(player),
	})
end

function StealthService.clear(player: Player)
	reveal(player, nil)
	HeistService.setWard(player, false)
	StealthService.push(player)
end

function StealthService.start()
	Remotes.get("StealthRequest").OnServerEvent:Connect(function(player, key)
		if type(key) ~= "string" then
			return
		end
		StealthService.buy(player, key)
	end)

	-- No target argument. Both of these act on the caller and nobody else.
	Remotes.get("StealthUse").OnServerEvent:Connect(function(player, key)
		if type(key) ~= "string" then
			return
		end
		StealthService.use(player, key)
	end)

	-- The ward is consumed inside HeistService, which owns the effect; this is
	-- how the HUD finds out it is gone.
	HeistService.onWardUsed(function(player, _spec)
		StealthService.push(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			-- Dying drops both, the way it drops loot and a ride. Neither may
			-- survive onto a fresh character: the disguise's hidden-parts list
			-- points at a destroyed model, and a ward that outlived a respawn
			-- would be a free one every time you reset.
			reveal(player, nil)
			HeistService.setWard(player, false)
			task.defer(StealthService.push, player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		hidden[player] = nil
	end)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.15 then
			return
		end
		accumulator = 0
		step()
	end)
end

return StealthService
