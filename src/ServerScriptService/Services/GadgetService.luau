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

	Three things hold that line:

	  * They cost coins every throw.
	  * Tagging still recovers the loot. These slow or stop; the defender
	    must still close and tag, which keeps the terminal action the one that
	    was already there and already worked.
	  * Range FALLS as power rises, so the decisive one cannot reach a thief
	    who already got clear.

	THEY MAY BE THROWN AT ANYBODY NOW, and a fourth rule used to say they
	could not. It said the only valid target, ever, was somebody carrying
	loot -- and what it was protecting was real: a gadget pointable at anyone
	is a harassment toy handed to under-twelves.

	What that rule got wrong is WHERE the protection had to live. Harassment
	is the EFFECT, not the aim -- taking somebody's movement away, repeatedly,
	at will. So the aim opened and the effect is what got held down instead.
	A hit on somebody who is not carrying anything is a PRANK: about a second,
	the zapper's dead stop capped to a blink, one per TARGET every few seconds
	however many people are throwing, and it never touches a raincoat. It
	cannot start, help or finish a robbery, because the effect that matters in
	a chase still requires the target to be holding somebody's coins.

	See Config.GADGET_FUN, and HeistService.applyGadget for the branch.

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
local HeldItemService = require(script.Parent.HeldItemService)
local HeistService = require(script.Parent.HeistService)
local EventService = require(script.Parent.EventService)
local StealthService = require(script.Parent.StealthService)

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
-- Takes a POSITION PROVIDER rather than a Player, so the identical flight
-- serves a thief and an alien drone. Two arc functions would be two things to
-- keep in step, and the one that drifts is the one nobody is looking at.
local function arc(model: Model, from: Vector3, where: () -> Vector3?)
	local peak = 5
	local spin = math.random() * math.pi * 2
	local started = os.clock()

	while model.Parent do
		local t = (os.clock() - started) / Config.GADGET_FLIGHT
		if t >= 1 then
			break
		end
		local to = where()
		if not to then
			break
		end
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

	-- YOU HAVE TO BE HOLDING IT. The prop in the hand is a tell other players
	-- read off the pavement, so a use that never drew anything would be a lie
	-- about the street. Named rather than silent: the fix is one keypress and
	-- a refusal nobody can read is indistinguishable from a broken item.
	if not HeldItemService.holding(player, key) then
		notify(player, ("Hold the %s out first."):format(spec.name), "warn")
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
	-- A CARRIER, THEN A DRONE, THEN ANYBODY. Ordered rather than
	-- nearest-of-all so that nothing about ordinary play changes: a gadget is
	-- still first and foremost the answer to somebody running off with your
	-- coins. It only looks up at the sky when there is nobody on the ground
	-- to stop, and only looks for somebody to prank when there is neither.
	--
	-- Which means opening the aim cost the serious use nothing. A thief in
	-- range is still picked over a bystander standing next to them, at every
	-- range and in every state.
	local target, reason = HeistService.nearestCarrier(root.Position, spec.range, player)
	local drone: BasePart? = nil
	if not target then
		local found, why = EventService.nearestDrone(root.Position, spec.range)
		drone = found
		-- THE FIRST REASON WINS, not the last. "Too far, get closer to them"
		-- is a better thing to tell somebody than whatever the next search
		-- came back with, and the old code overwrote it with the drone
		-- search's nil every time there was no raid on.
		reason = reason or why
	end
	if not target and not drone then
		local found, why = HeistService.nearestBystander(root.Position, spec.range, player)
		target = found
		reason = reason or why
	end
	if not target and not drone then
		notify(player, reason or "Nobody close enough to throw that at.", "warn")
		return
	end

	lastThrow[player] = now
	stock(data)[key] = held - 1
	GadgetService.push(player)
	HeldItemService.revalidate(player)

	local model = GadgetModel.build(key, true)
	model.Name = "ThrownGadget"
	model.Parent = workspace

	local from = root.Position + Vector3.new(0, 2.5, 0)

	task.spawn(function()
		if drone then
			arc(model, from, function()
				return if drone.Parent then drone.Position else nil
			end)
			if model.Parent then
				model:Destroy()
			end

			-- Re-checked on LANDING for the same reason a thief is: half a
			-- second of flight is long enough for somebody else to have
			-- knocked this drone down already.
			if not EventService.hitDrone(drone, player) then
				stock(data)[key] = (stock(data)[key] or 0) + 1
				GadgetService.push(player)
				notify(player, ("Somebody beat you to it. %s returned."):format(spec.name), "warn")
				return
			end
			notify(player, ("Direct hit! The drone is down. Grab the coins!"), "good")
			return
		end

		local thief = target :: Player
		arc(model, from, function()
			local r = getRoot(thief)
			return if r then r.Position else nil
		end)
		if model.Parent then
			model:Destroy()
		end

		-- Re-checked on LANDING, not on release, and applyGadget decides
		-- WHICH hit this is at that moment. Half a second of flight is long
		-- enough for a thief to be tagged, to deliver or to leave -- so
		-- somebody who picks loot up mid-flight catches the real one, and a
		-- thief who got home first catches the joke instead. Neither end can
		-- time their way around it.
		--
		-- False means there was nothing left to hit at all: they left, died,
		-- or somebody else's gadget landed on them inside the prank cooldown.
		-- The throw is refunded rather than spent on nothing, because an item
		-- consumed for no effect is indistinguishable from a broken one.
		local ok = HeistService.applyGadget(thief, player, spec)
		if not ok then
			stock(data)[key] = (stock(data)[key] or 0) + 1
			GadgetService.push(player)
			notify(player, ("Too late. %s returned."):format(spec.name), "warn")
			return
		end

		notify(player, ("%s hit %s!"):format(spec.name, thief.DisplayName), "good")
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

	notify(player, ("%s bought. You have %d."):format(spec.name, stock(data)[key]), "good")
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
		-- Nothing but climbing out, while you are in a bin. The client hides
		-- the control, so this only ever fires for a client that was written
		-- to ignore it.
		if StealthService.isHidden(player) then
			return
		end
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
