--!strict
--[[
	GadgetService

	Plungers, bubblegum and the zapper: the defender's answer to a thief who
	has bought their way out of being caught.

	WHY THIS EXISTS

	Config.getCarryMultiplier caps at 1.0, so a thief with Speed Boots maxed
	carries at 16 -- exactly the speed of the person chasing them. Tagging
	becomes impossible unless you were already standing on top of them. That is
	the same shape of hole the guard dog had before bones: a top-of-tree
	purchase with no counter, which quietly ends the argument the whole game is
	built on.

	A GADGET BUYS A TAG, NEVER THE CATCH.

	Four things hold that line and removing any one of them breaks it:

	  * They only work on somebody CARRYING LOOT. Nothing else is a valid
	    target, ever. This is what keeps a game for under-twelves from
	    shipping with a harassment toy in it -- there is no way to point one
	    of these at a player who is not, at that moment, running off with
	    somebody's coins.
	  * They cost coins every throw.
	  * Tagging still recovers the loot. These slow or stop; the defender
	    must still close and tag, which keeps the terminal action the one that
	    was already there and already worked.
	  * Range FALLS as power rises, so the decisive one cannot reach a thief
	    who already got clear.

	A THROW SENDS NO POSITION. The client fires a key and nothing else; the
	server picks the target from its own view of who is carrying what. There is
	no coordinate to forge and no range check to defeat. It also auto-targets
	rather than aiming, for the reason bones do: most of this audience is on a
	touchscreen, where lobbing something at a sprinting player is a fight with
	the camera, and "get it near them" was never the interesting decision.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GadgetModel = require(ReplicatedStorage.Shared.GadgetModel)
local DataService = require(script.Parent.DataService)
local HeistService = require(script.Parent.HeistService)

local GadgetService = {}

local lastThrow: { [Player]: number } = {}

local function notify(player: Player, message: string, kind: string)
	Remotes.get("Notify"):FireClient(player, message, kind)
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Shared with bones. Both are things you hold a stock of and throw, the keys
-- cannot collide, and sharing means gadgets inherit the bone rules for free --
-- including surviving rebirth, which is right for the same reason: a gadget is
-- spent the moment it is thrown, so a stockpile is not standing power, and
-- wiping it would only teach players to burn their stock before rebirthing.
local function stock(data: any): { [string]: number }
	if type(data.consumables) ~= "table" then
		data.consumables = {}
	end
	return data.consumables
end

-- ============================================================
-- FLIGHT
-- ============================================================

-- Lerps the gadget along a parabola from the thrower to wherever the target
-- is when it lands.
--
-- Not physics, for the reason nothing thrown in this game is: an unanchored
-- part rolls down a kerb, catches a fence post, or drops through the seam
-- between two slabs. It also TRACKS -- the target is a sprinting player, not a
-- patch of grass, so the endpoint is re-read every frame. A fixed endpoint
-- made every throw land where the thief used to be.
local function arc(model: Model, from: Vector3, target: Player)
	local peak = 5
	local spin = math.random() * math.pi * 2
	local started = os.clock()

	while model.Parent do
		local t = (os.clock() - started) / Config.GADGET_FLIGHT
		if t >= 1 then
			break
		end
		local root = getRoot(target)
		if not root then
			break
		end
		local to = root.Position
		local pos = from:Lerp(to, t) + Vector3.new(0, math.sin(t * math.pi) * peak, 0)
		model:PivotTo(CFrame.new(pos) * CFrame.Angles(t * 7, spin, t * 4))
		RunService.Heartbeat:Wait()
	end
end

-- ============================================================
-- THROWING
-- ============================================================

function GadgetService.throw(player: Player, key: string)
	local spec = Config.GADGETS[key]
	local data = DataService.get(player)
	if not spec or not data then
		return
	end

	local root = getRoot(player)
	if not root then
		return
	end

	local held = stock(data)[key] or 0
	if held <= 0 then
		notify(player, ("You have no %s left."):format(spec.name), "warn")
		return
	end

	local now = os.clock()
	if now - (lastThrow[player] or 0) < Config.GADGET_THROW_COOLDOWN then
		return
	end

	-- Everything that can refuse is checked BEFORE the gadget leaves the
	-- pocket. One spent on a target that was never valid is indistinguishable
	-- from the item not working.
	local target, reason = HeistService.nearestCarrier(root.Position, spec.range, player)
	if not target then
		notify(player, reason or "Nothing to throw that at.", "warn")
		return
	end

	lastThrow[player] = now
	stock(data)[key] = held - 1
	GadgetService.push(player)

	local model = GadgetModel.build(key, true)
	model.Name = "ThrownGadget"
	model.Parent = workspace

	local from = root.Position + Vector3.new(0, 2.5, 0)

	task.spawn(function()
		arc(model, from, target)
		if model.Parent then
			model:Destroy()
		end

		-- Re-checked on LANDING, not on release. Half a second of flight is
		-- long enough for the thief to be tagged, to deliver, or to leave --
		-- and a gadget that slowed somebody who was no longer carrying
		-- anything would be the griefing tool this whole design is built to
		-- avoid.
		local ok = HeistService.applyGadget(target, player, spec)
		if not ok then
			stock(data)[key] = (stock(data)[key] or 0) + 1
			GadgetService.push(player)
			notify(player, ("Too late -- %s returned."):format(spec.name), "warn")
			return
		end

		notify(player, ("%s hit %s!"):format(spec.name, target.DisplayName), "good")
	end)

	DataService.save(player)
end

-- ============================================================
-- BUYING
-- ============================================================

function GadgetService.buy(player: Player, key: string)
	local spec = Config.GADGETS[key]
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
	GadgetService.push(player)
end

function GadgetService.push(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end

	local held = stock(data)
	local list = {}
	for key, spec in pairs(Config.GADGETS) do
		list[key] = {
			name = spec.name,
			order = spec.order,
			cost = spec.cost,
			blurb = spec.blurb,
			range = spec.range,
			held = held[key] or 0,
			-- Shown as a percentage cut rather than a multiplier, and as a
			-- separate "stops them" flag, because those are two different
			-- promises and a single number cannot make both.
			slowPercent = math.floor((1 - spec.slow) * 100 + 0.5),
			duration = spec.duration,
			stops = (spec.stun or 0) > 0,
		}
	end

	Remotes.get("GadgetState"):FireClient(player, list)
end

function GadgetService.start()
	Remotes.get("GadgetThrow").OnServerEvent:Connect(function(player, key)
		if type(key) ~= "string" then
			return
		end
		GadgetService.throw(player, key)
	end)

	Remotes.get("GadgetRequest").OnServerEvent:Connect(function(player, key)
		if type(key) ~= "string" then
			return
		end
		GadgetService.buy(player, key)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastThrow[player] = nil
	end)
end

return GadgetService
