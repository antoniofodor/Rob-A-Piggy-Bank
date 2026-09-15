--!strict
--[[
	GadgetService

	Plungers, bubblegum and the zapper: the defender's answer to a thief who
	has bought their way out of being caught.

	WHY THIS EXISTS

	Config.getCarryMultiplier caps at 1.0, so a thief with Speed Boots maxed
	carries at 16 -- exactly the speed of the person chasing them. Nabbing
	becomes impossible unless you were already standing on top of them. That is
	the same shape of hole the guard dog had before bones: a top-of-tree
	purchase with no counter, which quietly ends the argument the whole game is
	built on.

	A GADGET BUYS A TAG, NEVER THE CATCH.

	Three things hold that line:

	  * They cost coins every throw.
	  * Nabbing still recovers the loot. These slow or stop; the defender
	    must still close and tag, which keeps the terminal action the one that
	    was already there and already worked.
	  * Range FALLS as power rises, so the decisive one cannot reach a thief
	    who already got clear.

	THEY MAY BE THROWN AT ANYBODY, AND THEY LAND ON ANYBODY. Two rules used
	to narrow that and both are gone, a session apart, and the order matters
	because the first one on its own read as a finished job.

	The original said the only valid target, ever, was somebody carrying
	loot. What it protected was real -- a gadget pointable at anyone is a
	harassment toy handed to under-twelves -- and what it got wrong is WHERE
	the protection had to live. Harassment is the EFFECT, not the aim. So the
	aim opened, and the effect got held down instead: a hit on somebody who
	was not carrying became a PRANK, about a second long, the zapper's dead
	stop capped to a blink.

	THAT WAS ALSO A DESCRIPTION OF WHY NOBODY COULD HELP ANYBODY. A defender
	standing on their own lawn while a friend cracked their pig could be hit
	and could not be affected, so the one cooperative play this game has --
	you hold them, I take the coins -- was refused by three numbers. The
	effect is the real one now whoever is hit, and a per-target cooldown
	carries the whole protection. See Config.GADGET_GUARD and
	HeistService.applyGadget.

	AND A GADGET IS AIMED NOW. It used to pick the nearest carrier, then the
	nearest drone, then the nearest anybody, all measured from the thrower --
	and then `arc` re-read that target's position every frame and lerped to
	it, so the flight was decorative and the throw could not miss. Both ends
	of that are gone.

	IT IS A BALLISTIC PROJECTILE: it launches along the full aim direction,
	pitch included, and drops for as long as it is in the air. Point at them,
	lead them, and aim HIGH for anything near the end of its range. See
	Config.THROW, which carries the drop table the two constants are solved
	against.

	BONES DID NOT CHANGE, and that is deliberate rather than unfinished work.
	See the note over Config.THROW.

	A THROW SENDS A DIRECTION AND STILL NEVER A POSITION. That is a reversal
	and it is argued in full over Config.THROW: a character cannot look up or
	down, so there was no way to read a pitched aim off data the server
	already held. What the old rule protected survives -- the server owns the
	origin, the speed, the gravity, the range cap and the simulation, and a
	direction is not a coordinate.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GadgetModel = require(ReplicatedStorage.Shared.GadgetModel)
local DataService = require(script.Parent.DataService)
local HeldItemService = require(script.Parent.HeldItemService)
local SoundKit = require(ReplicatedStorage.Shared.SoundKit)
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

-- Flies the gadget as a BALLISTIC PROJECTILE and reports whatever it passed.
--
-- Not Roblox physics, for the reason nothing thrown in this game is: an
-- unanchored part rolls down a kerb, catches a fence post, or drops through
-- the seam between two slabs. It is stepped through `Config.throwPointAt`,
-- which is the same curve the client's preview traces.
--
-- THIS HAS NOW BEEN THREE DIFFERENT FLIGHTS AND THE MIDDLE ONE IS THE
-- INTERESTING FAILURE. First it TRACKED -- the endpoint was re-read every
-- frame, so a gadget could not miss and the flight was an animation played
-- over a decision already made. Then it was a fixed-point LOB: a flat facing,
-- a fixed parabola, and a landing spot exactly `spec.range` away. That fixed
-- everything about tracking and introduced something nobody wanted -- every
-- throw travelled the same distance whatever it was aimed at, so hitting
-- somebody three studs away meant lobbing a plunger over their head, and the
-- whole thing read as tossing a bomb at a marked spot.
--
-- Now it launches along the full aim, pitch included, and gravity does the
-- rest. See Config.THROW.
--
-- FOUR THINGS CAN END IT, and the order they are asked in matters. A target
-- passed within `hitRadius`; the WORLD, so a fence or a wall stops it and
-- lobbing something over one is a real thing to do; the gadget's own `range`
-- measured HORIZONTALLY, which is what keeps "range falls as power rises"
-- meaning what it always did even though aiming up now buys airtime; and a
-- hard time cap so a throw off the edge of the world cannot leave a loop
-- running.
--
-- TESTED EVERY STEP RATHER THAN AT THE END, or a gadget would pass clean
-- through somebody standing halfway along its path. The order inside a step
-- is the one the old target search used -- a carrier, then a drone, then
-- anybody -- so a thief in the path is still picked over a bystander beside
-- them, which is what keeps a real chase behaving as it did.
local function flyBallistic(model: Model, origin: Vector3, velocity: Vector3, range: number, thrower: Player): (any?, BasePart?)
	local spin = math.random() * math.pi * 2
	local started = os.clock()
	local radius = Config.THROW.hitRadius
	local prev = origin

	-- THE THROWER'S OWN CHARACTER IS EXCLUDED OR THE FIRST CAST HITS IT.
	-- The projectile is born a couple of studs above their head and the
	-- segment from there to the next step passes straight down their own
	-- body when they are aiming low.
	local ignore: { Instance } = { model }
	if thrower.Character then
		table.insert(ignore, thrower.Character)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore

	while true do
		local t = os.clock() - started
		local pos = Config.throwPointAt(origin, velocity, t)

		-- CAST THE SEGMENT, NEVER THE POINT. At 60 studs a second a frame is
		-- a stud of travel, which is small -- but a fast frame drop is not,
		-- and a point test tunnels through a fence the moment one arrives.
		local stopped = false
		local step = pos - prev
		if step.Magnitude > 1e-3 then
			local hit = workspace:Raycast(prev, step, params)
			if hit then
				pos = hit.Position
				stopped = true
			end
		end

		if model.Parent then
			model:PivotTo(CFrame.new(pos) * CFrame.Angles(t * 9, spin, t * 5))
		end

		local victim = HeistService.nearestCarrier(pos, radius, thrower)
		if victim then
			return victim, nil
		end

		local drone = EventService.nearestDrone(pos, Config.THROW.droneRadius)
		if drone then
			return nil, drone
		end

		local bystander = HeistService.nearestBystander(pos, radius, thrower)
		if bystander then
			return bystander, nil
		end

		if stopped then
			return nil, nil
		end

		-- HORIZONTAL, so aiming up buys height and hang time and never REACH.
		-- Measured any other way, elevation would quietly be a range upgrade
		-- on the one stat this tree is balanced with.
		local flat = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(origin.X, 0, origin.Z)).Magnitude
		if flat >= range or t >= Config.THROW.maxSeconds then
			return nil, nil
		end

		prev = pos
		RunService.Heartbeat:Wait()
	end
end

-- ============================================================
-- THROWING
-- ============================================================

function GadgetService.throw(player: Player, key: string, direction: any)
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

	-- EVERYTHING THAT CAN REFUSE IS ABOVE THIS LINE, AND THERE IS ONE FEWER
	-- OF THEM THAN THERE USED TO BE.
	--
	-- A throw used to search for a target BEFORE spending anything, and
	-- refuse with "Nobody close enough to throw that at." That was the right
	-- shape while the server chose the target: an item spent on a target that
	-- was never valid is indistinguishable from an item that does not work.
	--
	-- IT IS THE WRONG SHAPE FOR AN AIMED THROW, and deleting it is the whole
	-- of what "a miss must cost" means here. There is no such thing as an
	-- invalid throw any more -- you may lob a plunger down an empty street --
	-- so the only question left is whether it connected, and the player owns
	-- the answer. A miss that refunded would be a mechanic with nothing at
	-- stake in it.
	lastThrow[player] = now
	stock(data)[key] = held - 1
	GadgetService.push(player)
	HeldItemService.revalidate(player)

	local model = GadgetModel.build(key, true)
	model.Name = "ThrownGadget"
	model.Parent = workspace

	-- THE THROW IS HEARD FROM THE THROWER, NOT FROM THE PROJECTILE, and
	-- that is a decision rather than a convenience. A sound welded to a
	-- gadget in flight doppler-shifts across the street and arrives at the
	-- target as a warning -- which would hand a defender a free half-second
	-- of notice on the one action this tree exists to sell. A whoosh at the
	-- hand says somebody near you threw something and says nothing about
	-- where it is going.
	--
	-- It fires AFTER everything that can refuse, so a throw that was refused
	-- is silent -- a sound on a spend that did not happen is the same lie
	-- as a prop in a hand holding nothing.
	SoundKit.on(root, Config.SOUNDS.GADGET_THROW,
		{ name = "GadgetThrow", volume = 0.45, distance = 70 })

	local from = root.Position + Vector3.new(0, Config.THROW.launchHeight, 0)

	-- THE AIM ARRIVES FROM THE CLIENT AND IS TAKEN APART IN EXACTLY ONE
	-- PLACE. `Config.throwClampDirection` normalises it, refuses a nil, a
	-- non-Vector3, a zero, a NaN and a straight-up-or-down, and clamps the
	-- pitch -- so a forged payload meets one gate rather than three call
	-- sites that each forgot a different case.
	--
	-- WHAT IT CANNOT CARRY IS A POSITION, and that is the rule this reverses
	-- carefully rather than abandons. The server still owns the origin, the
	-- speed, the gravity, the range cap, the hit radius and the whole
	-- simulation. See Config.THROW for why a direction is a different kind of
	-- thing from a coordinate, and why a Roblox character -- which cannot look
	-- up or down -- left no way to read a pitched aim off data the server
	-- already had.
	--
	-- A BAD DIRECTION FALLS BACK TO THE BODY'S OWN FACING RATHER THAN
	-- REFUSING. The player did nothing wrong, the fallback is a legal throw,
	-- and it is the same call `RidePose` makes for an unknown stance: degrade
	-- to the thing it is a variant of, never to nothing.
	local aim = Config.throwClampDirection(direction)
		or Config.throwClampDirection(root.CFrame.LookVector)
	if not aim then
		stock(data)[key] = (stock(data)[key] or 0) + 1
		GadgetService.push(player)
		return
	end
	local velocity = Config.throwVelocity(aim)

	task.spawn(function()
		local target, drone = flyBallistic(model, from, velocity, spec.range, player)
		if model.Parent then
			model:Destroy()
		end

		if drone then
			-- Re-checked on LANDING for the same reason a thief is: the
			-- flight is long enough for somebody else to have knocked this
			-- drone down already.
			if not EventService.hitDrone(drone, player) then
				stock(data)[key] = (stock(data)[key] or 0) + 1
				GadgetService.push(player)
				notify(player, ("Somebody beat you to it. %s returned."):format(spec.name), "warn")
				return
			end
			notify(player, ("Direct hit! The drone is down. Grab the coins!"), "good")
			return
		end

		if not target then
			-- THE MISS, AND IT IS NAMED RATHER THAN SILENT. A gadget that
			-- vanished with nothing on screen would read exactly like the
			-- item failing, which is the one failure this project refuses
			-- above all others -- and a player who cannot tell a miss from a
			-- bug never learns to lead.
			notify(player, ("Your %s missed."):format(spec.name), "warn")
			return
		end

		-- A PERSON OR A NEIGHBOUR, and the gadget does not care which.
		-- `applyGadget` decides WHICH hit this is at the moment it lands, so
		-- somebody who picked loot up mid-flight catches the carrier's
		-- version and a thief who got home first catches the ordinary one.
		--
		-- False means there was nothing left to hit at all: they left, died,
		-- got into a bin, or are still resting off somebody else's gadget.
		-- That is refunded, and it is a different thing from a MISS -- the
		-- throw connected and there was nobody home.
		local ok = HeistService.applyGadget(target, player, spec)
		if not ok then
			stock(data)[key] = (stock(data)[key] or 0) + 1
			GadgetService.push(player)
			notify(player, ("Too late. %s returned."):format(spec.name), "warn")
			return
		end

		-- THE LANDING IS HEARD FROM THE TARGET, which is the other half of
		-- the decision above: the throw belongs to the thrower and the hit
		-- belongs to whoever caught it, so the two ends of one gadget are
		-- audible in two different places and a bystander can tell which
		-- happened near them.
		--
		-- Only on a hit that actually LANDED. The miss above returns before
		-- this line and so does the refunded no-target case, so neither makes
		-- a noise -- a splat with nobody under it would read as a hit that
		-- the game then declined to apply.
		local hitAt = HeistService.targetPosition(target)
		SoundKit.at(hitAt, Config.SOUNDS.GADGET_HIT,
			{ name = "GadgetHit", volume = 0.5, distance = 80 })

		-- Named through the accessor rather than off `DisplayName`, which a
		-- resident does not have. Same reason `confiscate` reaches for it:
		-- exposing the one accessor is the alternative to teaching this file
		-- the same branch a second time.
		notify(player, ("%s hit %s!"):format(spec.name, HeistService.targetDisplayName(target)), "good")
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
	Remotes.get("GadgetThrow").OnServerEvent:Connect(function(player, key, direction)
		-- Nothing but climbing out, while you are in a bin. The client hides
		-- the control, so this only ever fires for a client that was written
		-- to ignore it.
		if StealthService.isHidden(player) then
			return
		end
		if type(key) ~= "string" then
			return
		end
		-- `direction` is deliberately NOT type-checked here.
		-- `Config.throwClampDirection` is the one gate, and it refuses every
		-- shape this could arrive in; a second, weaker check up here would be
		-- two places that can disagree about what a legal aim is.
		GadgetService.throw(player, key, direction)
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
