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
local DataService = require(script.Parent.DataService)
local HeldItemService = require(script.Parent.HeldItemService)
local SoundKit = require(ReplicatedStorage.Shared.SoundKit)
local HeistService = require(script.Parent.HeistService)
local ResidentService = require(script.Parent.ResidentService)
local GadgetFX = require(ReplicatedStorage.Shared.GadgetFX)
-- Only for `RELEASE_AT`: the clip itself plays on every client off the
-- counter this file bumps. See Shared/ThrowPose.
local ThrowPose = require(ReplicatedStorage.Shared.ThrowPose)
local EventService = require(script.Parent.EventService)
local StealthService = require(script.Parent.StealthService)

local GadgetService = {}

-- THE ZAPPER KNOCKS A LASSOED CATCH LOOSE (docs/LASSO-PLAN.md section 3).
-- `PiggyHaulService` owns the knock; `Main` registers it here, because a
-- require of that file from this one would put the whole haul chain behind
-- every gadget. Nil is simply no knock.
local zapKnock: ((Player, Player) -> boolean)? = nil

function GadgetService.registerZapKnock(fn: (Player, Player) -> boolean)
	zapKnock = fn
end

local lastThrow: { [Player]: number } = {}

-- Declared up here because `throw` is written above them and reads them: a
-- `local function` declared after its reader is a nil global to it, which is
-- the forward-reference trap this project has hit ten times.
local showHit: (any, any, Vector3, Vector3?) -> ()
local land: (Player, any, string, any, any?, BasePart?, Vector3, Vector3?) -> ()
local playHit: (any, Vector3?) -> ()

-- Who has an arm drawn back, with what, and since when. Server clock.
local cocked: { [Player]: { key: string, at: number } } = {}

-- Each flight's id, so every client can stop its own copy on the one the
-- server ended.
local nextFlight = 0

-- The published throw state (see Config.THROW_ANIMATION_ATTRIBUTE): one
-- letter and a counter on one attribute, so a cock, a throw and a cancel can
-- never replicate out of order with each other.
local stateCount: { [Player]: number } = {}
local function publishState(player: Player, kind: string)
	local character = player.Character
	if not character then
		return
	end
	local n = (stateCount[player] or 0) + 1
	stateCount[player] = n
	character:SetAttribute(Config.THROW_ANIMATION_ATTRIBUTE, kind .. tostring(n))
end

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
-- NOTHING IS DRAWN HERE ANY MORE. The server used to fly a real model and
-- `PivotTo` it every frame, and that replicates in lurches -- measured, a
-- plunger that was genuinely cup-first along its arc on the server read on
-- the thrower's screen as not moving through the air at all. Every client now
-- flies its own copy (Shared/GadgetFlight) along the same curve from the
-- `GadgetFlight` broadcast, and this loop only decides what it hit and where
-- it stopped, which it reports as the third return.
-- The fourth return is the NORMAL of the surface it stopped on, when it
-- stopped on one, so a gum bomb can splat flat on a wall instead of lying
-- on it like a floor puddle.
local function flyBallistic(origin: Vector3, velocity: Vector3, spec: any, thrower: Player): (any?, BasePart?, Vector3, Vector3?)
	local started = os.clock()
	local radius = Config.THROW.hitRadius
	local prev = origin

	-- THE THROWER'S OWN CHARACTER IS EXCLUDED OR THE FIRST CAST HITS IT.
	-- The projectile is born a couple of studs above their head and the
	-- segment from there to the next step passes straight down their own
	-- body when they are aiming low.
	local ignore: { Instance } = {}
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
		local normal: Vector3? = nil
		local step = pos - prev
		if step.Magnitude > 1e-3 then
			local hit = workspace:Raycast(prev, step, params)
			if hit then
				pos = hit.Position
				normal = hit.Normal
				stopped = true
			end
		end

		local victim = HeistService.nearestCarrier(pos, radius, thrower)
		if victim then
			return victim, nil, pos
		end

		local drone = EventService.nearestDrone(pos, Config.THROW.droneRadius)
		if drone then
			return nil, drone, pos
		end

		local bystander = HeistService.nearestBystander(pos, radius, thrower)
		if bystander then
			return bystander, nil, pos
		end

		if stopped then
			return nil, nil, pos, normal
		end

		-- NO DISTANCE CUTOFF. A gadget flies until it meets a person, a wall
		-- or the ground; how far it CAN go is its speed (`Config.throwSpeed`).
		-- The time cap is only a backstop for a throw off the edge of the
		-- world, and `auditThrow` keeps it longer than any real flight.
		if t >= Config.THROW.maxSeconds then
			local down = workspace:Raycast(pos, Vector3.new(0, -60, 0), params)
			return nil, nil, if down then down.Position else pos, if down then down.Normal else nil
		end

		prev = pos
		RunService.Heartbeat:Wait()
	end
end

-- ============================================================
-- LANDING
-- ============================================================

-- WHAT A HIT LOOKS LIKE ON THE PERSON IT HIT. Only called when the effect
-- actually landed -- a dodge or a raincoat uses the throw and shows nothing.
--
-- The plunger's knockdown is played on the victim's OWN client, for the
-- reason the fence knockback is: a server write to a player's velocity is
-- discarded. The server has already stunned them for `spec.stun`; the
-- client only makes it look like a fall. The direction is from the thrower,
-- so you are knocked AWAY from whoever hit you.
function showHit(victim: any, spec: any, from: Vector3, dir: Vector3?)
	-- A neighbour's figure is its model; its knockdown is already posed by
	-- its own walker (ResidentService), so only the stuck-on bits go here.
	local isPlayer = typeof(victim) == "Instance"
	local character: Model? = if isPlayer then (victim :: Player).Character else victim.model
	if not character then
		return
	end
	-- THE SLIP (designer, 2026-09-23): "cartoon-slip-no-fall" on anybody a
	-- plunger knocks flat, player or neighbour, played in the WORLD so the
	-- thrower and everybody nearby hear the pratfall -- it is the one gadget
	-- hit that is a joke on purpose. `knock` is the plunger's alone.
	if spec.knock then
		SoundKit.at(character:GetPivot().Position, Config.SOUNDS.PLUNGER_SLIP,
			{ name = "PlungerSlip", volume = 0.7, distance = 70 })
	end
	if spec.knock and isPlayer then
		local root = getRoot(victim :: Player)
		local away = if root then root.Position - from else Vector3.zAxis
		Remotes.get("GadgetKnock"):FireClient(victim, Vector3.new(away.X, 0, away.Z), spec.stun, spec.knock)
	end
	-- THE PLUNGER STAYS ON THEM for as long as it is doing something to
	-- them, stuck cup-first on the side it came from.
	if spec.flight == "javelin" then
		local towards = dir
		if not towards then
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local at = if root then root.Position else character:GetPivot().Position
			towards = at - from
		end
		-- Mostly level: a lobbed plunger comes down steeply, and one stuck
		-- into a chest pointing at the sky reads as a hat.
		towards = Vector3.new(towards.X, towards.Y * 0.3, towards.Z)
		GadgetFX.stickPlunger(character:GetPivot().Position, towards,
			math.max(spec.duration, spec.stun or 0), character)
	end
	if spec.puddle then
		GadgetFX.gumOnPerson(character, spec.duration)
	elseif spec.gumFeet then
		-- Stepped in a puddle: the goo is on their shoes.
		GadgetFX.gumOnPerson(character, spec.duration, true)
	end
	if spec.beam then
		GadgetFX.zapOnPerson(character, spec.stun)
	end
end

-- The gadget's OWN hit sound (`spec.hitSound`, a key in Config.SOUNDS), with
-- the old shared one as the fallback for a row that names none.
function playHit(spec: any, at: Vector3?)
	if not at then
		return
	end
	SoundKit.at(at, Config.SOUNDS[spec.hitSound or "GADGET_HIT"] or Config.SOUNDS.GADGET_HIT,
		{ name = "GadgetHit", volume = spec.hitVolume or 0.5, distance = 80 })
end

-- Everything that happens once a gadget has reached something -- or
-- nothing. Shared by the thrown flight and the zapper's arc, so a hit is one
-- set of rules however it arrived.
function land(player: Player, data: any, key: string, spec: any, target: any?, drone: BasePart?, from: Vector3, stoppedAt: Vector3?, stoppedNormal: Vector3?, stoppedDir: Vector3?)
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
		-- A BUBBLEGUM BOMB THAT MISSES IS NOT WASTED: it leaves a puddle
		-- where it came down, which is its second use -- lob one at a
		-- gate and whoever runs through it is slowed.
		-- A PLUNGER THAT MISSES STICKS WHERE IT HIT, with a boing -- cup
		-- first into the wall, or into the ground. Straight into the surface
		-- rather than along the flight, because a plunger that meets a wall
		-- at a glancing angle does not stick at that angle.
		if spec.flight == "javelin" and stoppedAt and stoppedNormal then
			GadgetFX.stickPlunger(stoppedAt, -stoppedNormal, spec.duration)
			playHit(spec, stoppedAt)
			notify(player, ("Your %s missed."):format(spec.name), "warn")
			return
		end
		if spec.puddle and stoppedAt then
			GadgetService.dropPuddle(player, spec, stoppedAt, stoppedNormal)
			playHit(spec, stoppedAt)
			notify(player, ("Your %s splatted on the ground."):format(spec.name), "warn")
			return
		end
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
	local ok, landed = HeistService.applyGadget(target, player, spec)
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
	if landed then
		showHit(target, spec, from, stoppedDir)
		-- THE ZAPPER'S TUNED HIT, and only that: a stun from the beam on a
		-- player carrying a lassoed catch drops it dazed. Asked by the spec's
		-- own shape (a beam that stops you) rather than by key, and NOT by a
		-- `knock` field -- that would play the plunger's slip on the zapper.
		if zapKnock and spec.beam ~= nil and (spec.stun or 0) > 0 and typeof(target) == "Instance" then
			zapKnock(target :: Player, player)
		end
	end

	-- The zapper's sound is its FIRE, played when the arc goes out.
	if not spec.beam then
		playHit(spec, HeistService.targetPosition(target))
	end

	-- Named through the accessor rather than off `DisplayName`, which a
	-- resident does not have. Same reason `confiscate` reaches for it:
	-- exposing the one accessor is the alternative to teaching this file
	-- the same branch a second time.
	notify(player, ("%s hit %s!"):format(spec.name, HeistService.targetDisplayName(target)), "good")
end

-- ============================================================
-- THROWING
-- ============================================================

-- DRAWING THE ARM BACK. Costs nothing and spends nothing: it is a pose
-- everybody can see and a timestamp the release is measured from. Refused
-- quietly for anything that is not a gadget in hand, because the client
-- only sends it for one and the throw itself names every real refusal.
function GadgetService.cock(player: Player, on: boolean)
	if not on then
		if cocked[player] then
			cocked[player] = nil
			publishState(player, "x")
		end
		return
	end
	local key = HeldItemService.get(player)
	if not key or not Config.GADGETS[key] or Config.GADGETS[key].beam
		or StealthService.isHidden(player) then
		return
	end
	if cocked[player] and cocked[player].key == key then
		return
	end
	cocked[player] = { key = key, at = os.clock() }
	publishState(player, "c")
end

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

	-- The arm comes down on every refusal below, or a refused throw would
	-- leave it cocked on every screen until the next press.
	local cock = cocked[player]
	cocked[player] = nil
	local function refuse(message: string?)
		if cock then
			publishState(player, "x")
		end
		if message then
			notify(player, message, "warn")
		end
	end

	-- YOU HAVE TO BE HOLDING IT. The prop in the hand is a tell other players
	-- read off the pavement, so a use that never drew anything would be a lie
	-- about the street. Named rather than silent: the fix is one keypress and
	-- a refusal nobody can read is indistinguishable from a broken item.
	if not HeldItemService.holding(player, key) then
		refuse(("Hold the %s out first."):format(spec.name))
		return
	end

	local held = stock(data)[key] or 0
	if held <= 0 then
		refuse(("You have no %s left."):format(spec.name))
		return
	end

	local now = os.clock()
	if now - (lastThrow[player] or 0) < Config.GADGET_THROW_COOLDOWN then
		refuse(nil)
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

	-- THE ZAPPER IS NOT THROWN. It fires the moment it is pressed, along the
	-- aim, out to its own short range, and hits the first person the line
	-- passes within `beam.width` of -- in the same order a flight tests: a
	-- carrier, then a drone, then anybody.
	if spec.beam then
		GadgetService.zap(player, data, key, spec, root, direction)
		return
	end

	-- THE THROW IS DRAWN BEFORE IT IS LAUNCHED. Every client finishes
	-- `ThrowPose` off this state, and the projectile leaves when the clip's
	-- hand does: `launchDelay` of however long the arm was held back, timed
	-- from the COCK this server saw rather than from anything the client
	-- claims. The aim was sampled at the release and is not re-read.
	--
	-- The prop stays in the hand until the launch for the same reason:
	-- `revalidate` runs AFTER it, so a player throwing their last plunger
	-- winds up holding one rather than an empty fist.

	local heldFor = if cock and cock.key == key then now - cock.at else 0
	local delay = ThrowPose.launchDelay(heldFor)
	publishState(player, "t")

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
	local velocity = Config.throwVelocity(aim, spec)

	task.spawn(function()
		task.wait(delay)

		-- FROM WHERE THE HAND IS AT THE RELEASE -- derived off the root
		-- through `Config.throwOrigin`, which is also what the preview
		-- traces from, rather than read off the hand part: the server does
		-- not play the clip, so its copy of the hand is a frame or more
		-- behind. If the thrower has died or left during the wind-up there
		-- is nothing to throw from, and the gadget comes back: the throw did
		-- not happen, which is a different thing from a miss.
		local liveRoot = getRoot(player)
		if not liveRoot then
			stock(data)[key] = (stock(data)[key] or 0) + 1
			GadgetService.push(player)
			HeldItemService.revalidate(player)
			return
		end
		local from = Config.throwOrigin(liveRoot)

		nextFlight += 1
		local flightId = nextFlight
		Remotes.get("GadgetFlight"):FireAllClients(player, key, from, velocity,
			workspace:GetServerTimeNow(), flightId)
		HeldItemService.revalidate(player)

		local target, drone, stoppedAt, stoppedNormal = flyBallistic(from, velocity, spec, player)
		Remotes.get("GadgetFlightEnd"):FireAllClients(flightId, stoppedAt)

		-- WHICH WAY IT WAS TRAVELLING WHEN IT STOPPED: the tangent of the arc
		-- at the moment it got there, found from how far it went on the flat
		-- (horizontal speed is constant). A stuck plunger points this way.
		local flatSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local flatGone = Vector3.new(stoppedAt.X - from.X, 0, stoppedAt.Z - from.Z).Magnitude
		local tStop = if flatSpeed > 1e-3 then flatGone / flatSpeed else 0
		local stoppedDir = velocity - Vector3.new(0, Config.THROW.gravity * tStop, 0)

		land(player, data, key, spec, target, drone, from, stoppedAt, stoppedNormal, stoppedDir)
	end)

	DataService.save(player)
end

-- ============================================================
-- THE ZAPPER'S ARC
-- ============================================================

function GadgetService.zap(player: Player, data: any, key: string, spec: any, root: BasePart, direction: any)
	local aim = Config.throwClampDirection(direction)
		or Config.throwClampDirection(root.CFrame.LookVector)
	if not aim then
		stock(data)[key] = (stock(data)[key] or 0) + 1
		GadgetService.push(player)
		return
	end

	SoundKit.on(root, Config.SOUNDS[spec.hitSound] or Config.SOUNDS.GADGET_HIT,
		{ name = "ZapperFire", volume = spec.hitVolume or 0.5, distance = 70 })

	local from = Config.throwOrigin(root)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if player.Character then { player.Character } else {}

	-- THE WORLD STOPS IT. A zap does not go through a fence.
	local reach = spec.range
	local wall = workspace:Raycast(from, aim * reach, params)
	if wall then
		reach = (wall.Position - from).Magnitude
	end

	-- WALKED IN SMALL STEPS with the same three searches a flight uses, so
	-- a thief on the line is picked over a bystander beside it.
	local width = spec.beam.width
	local target, drone = nil, nil
	local hitAt = from + aim * reach
	local d = 0
	while d <= reach do
		local at = from + aim * d
		local victim = HeistService.nearestCarrier(at, width, player)
		if victim then
			target, hitAt = victim, at
			break
		end
		local dr = EventService.nearestDrone(at, Config.THROW.droneRadius)
		if dr then
			drone, hitAt = dr, at
			break
		end
		local by = HeistService.nearestBystander(at, width, player)
		if by then
			target, hitAt = by, at
			break
		end
		d += 1
	end

	-- The arc is drawn on every client from the hand to what it hit, or to
	-- where it ran out -- the thrower included, since there is no flight to
	-- predict and a quarter-second of lightning a ping late is not a lie.
	local tip = hitAt
	if target then
		local pos = HeistService.targetPosition(target)
		if pos then
			tip = pos
		end
	end
	Remotes.get("GadgetZap"):FireAllClients(player, from, tip)

	-- The stock was already spent by `throw`; an empty hand empties itself.
	HeldItemService.revalidate(player)
	land(player, data, key, spec, target, drone, from, nil)
end

-- ============================================================
-- BUBBLEGUM PUDDLES
-- ============================================================
--
-- A puddle slows whoever walks into it ONCE each, through the same
-- `applyGadget` a direct hit uses -- so it respects the dodge, the raincoat
-- and the rest a hit earns, and a puddle cannot hold somebody down for
-- longer than a thrown gadget could. Distance is polled, never `Touched`:
-- `Touched` re-fires per character part on every contact, which is the loop
-- that once froze players on an electric fence.
-- `thrower` IS OPTIONAL BECAUSE SCENERY CAN DROP ONE. A neighbour's gum leaves
-- the same puddle a player's does, and there is no Player behind it -- so the
-- field is nilable and `owner` carries the name for the wording instead.
type Puddle = { at: Vector3, radius: number, untilAt: number, thrower: Player?, owner: string?,
	spec: any, caught: { [any]: true } }
local puddles: { Puddle } = {}

function GadgetService.dropPuddle(thrower: Player?, spec: any, at: Vector3, normal: Vector3?, owner: string?)
	local pd = spec.puddle
	local _, floorY = GadgetFX.splat(at, normal, pd.radius, pd.lifetime)
	-- A splat on a WALL is only a picture: nobody walks through a wall, and a
	-- slow zone centred on a fence would catch people on the far side of it.
	if normal and normal.Unit.Y < 0.6 then
		return
	end
	table.insert(puddles, {
		-- Measured from the surface the splat settled on (a driveway, a
		-- kerb), which is where people's feet actually are.
		at = Vector3.new(at.X, floorY, at.Z),
		radius = pd.radius,
		untilAt = os.clock() + pd.lifetime,
		thrower = thrower,
		owner = owner,
		-- What stepping in it does: a gentler, shorter hit than the bomb
		-- itself, named so the toast says what happened.
		spec = {
			name = spec.name,
			slow = pd.slow,
			duration = pd.duration,
			stun = 0,
			gumFeet = true,
			hit = "You stepped in bubblegum!",
			prank = "You stepped in %s's bubblegum!",
		},
		caught = {},
	})
end

local function stepPuddles()
	local now = os.clock()
	for i = #puddles, 1, -1 do
		local pd = puddles[i]
		if now >= pd.untilAt then
			table.remove(puddles, i)
		else
			for _, other in ipairs(Players:GetPlayers()) do
				-- `pd.thrower` is nil on a neighbour's puddle, and `other` is
				-- never nil, so nobody is excluded -- which is right: scenery
				-- has no self to spare.
				if other ~= pd.thrower and not pd.caught[other] then
					local root = getRoot(other)
					if root then
						local flat = Vector3.new(root.Position.X - pd.at.X, 0, root.Position.Z - pd.at.Z).Magnitude
						-- Feet, roughly: the root rides about three studs up,
						-- and somebody jumping over it clears it.
						local above = root.Position.Y - pd.at.Y
						if flat <= pd.radius and above < 4.5 then
							-- A NEIGHBOUR'S PUDDLE GOES THROUGH `neighbourHit`,
							-- which is the only route into the slow that does
							-- not need a Player thrower -- and it carries the
							-- thief-keyed rest, so a street of gum cannot hold
							-- one child still.
							local used, landed
							if pd.thrower then
								used, landed = HeistService.applyGadget(other, pd.thrower, pd.spec)
							else
								landed = HeistService.neighbourHit(other, pd.spec, pd.owner or "A neighbour")
								used = landed
							end
							if used then
								pd.caught[other] = true
								if landed then
									showHit(other, pd.spec, pd.at)
									playHit(Config.GADGETS.gum, root.Position)
								end
							end
						end
					end
				end
			end
			-- NEIGHBOURS WALK INTO IT TOO. Their `at` is their feet, so the
			-- height test is tighter than a player's root-based one.
			--
			-- EXCEPT INTO ANOTHER NEIGHBOUR'S, and that is an absence of an
			-- effect rather than one being withheld. What a gadget does to a
			-- resident is take the carried coins back and hand them to the
			-- THROWER -- no slow and no stun, because a resident has no Humanoid
			-- to write a speed to. With no player behind the puddle there is
			-- nobody to hand them to, so there is no outcome to define.
			for _, r in ipairs(if pd.thrower then ResidentService.getAll() else {}) do
				if not pd.caught[r] and r.model then
					local flat = Vector3.new(r.at.X - pd.at.X, 0, r.at.Z - pd.at.Z).Magnitude
					if flat <= pd.radius and math.abs(r.at.Y - pd.at.Y) < 2.5 then
						local used, landed = HeistService.applyGadget(r, pd.thrower, pd.spec)
						if used then
							pd.caught[r] = true
							if landed then
								showHit(r, pd.spec, pd.at)
							end
						end
					end
				end
			end
		end
	end
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

-- A NEIGHBOUR THROWS SOMETHING AT THE THIEF WHO ROBBED THEM.
--
-- It lives here because this file owns every flight in the game -- the curve
-- both ends step, the remote the clients draw one with, the flight ids -- and
-- a second flight loop in `ResidentService` would be the near-identical copy
-- that drifts the first time either is touched. `ResidentService` reaches it
-- through a registry rather than a require, because this file already requires
-- that one.
--
-- WHAT IT DELIBERATELY DOES NOT REUSE is `flyBallistic` and `land`. Both are
-- written around a PLAYER thrower: the first needs a Character for its ignore
-- list and uses the thrower as the self-exclusion in two target searches, and
-- the second refunds stock, pushes a hot bar and notifies an inventory that
-- scenery has not got.
--
-- AND IT TESTS AGAINST ONE PLAYER, WHICH IS A SAFETY DECISION RATHER THAN A
-- SHORTCUT. A player's throw searches every step for a carrier, then a drone,
-- then any bystander, so it cannot pass through somebody standing in the way.
-- Scenery doing that would be a neighbour clipping an uninvolved nine-year-old
-- who happened to walk between them -- the harassment shape this game refuses
-- everywhere else. A miss hits nothing at all.
function GadgetService.neighbourThrow(resident: any, thief: Player)
	local cfg = Config.NEIGHBOUR_CHASE
	local spec = Config.GADGETS[cfg.throw.gadget]
	if not spec then
		return
	end
	local character = thief.Character
	local body = character and character:FindFirstChild("HumanoidRootPart")
	if not (body and body:IsA("BasePart")) then
		return
	end
	local from = ResidentService.bodyAt(resident)
	local to = (body :: BasePart).Position
	-- FLAT, like every other range in the chase: a thief up on a plot slab and
	-- a neighbour on the pavement are a stud apart vertically, and counting it
	-- would make the same throw legal on one piece of ground and not another.
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z).Magnitude
	if flat < cfg.throw.minRange or flat > spec.range then
		return
	end
	local speed = Config.throwSpeed(spec)
	local aim = Config.throwAimAt(from, to, speed)
	if not aim then
		return
	end
	-- THE MISS IS REAL AND IT IS AIM, NOT A DICE ROLL. The cone is solved from
	-- the accuracy at THIS range, so the throw that misses visibly misses, can
	-- be dodged, and reads as a neighbour with a poor arm rather than as a
	-- number the server rolled behind a projectile that always flew true.
	local cone = Config.neighbourAimError(flat)
	local scattered = (CFrame.lookAt(Vector3.zero, aim)
		* CFrame.Angles((math.random() * 2 - 1) * cone, (math.random() * 2 - 1) * cone, 0)).LookVector
	-- Through the same one gate a player's aim passes, so a neighbour cannot
	-- produce a direction the rest of this file would refuse.
	local direction = Config.throwClampDirection(scattered)
	if not direction then
		return
	end
	local velocity = Config.throwVelocity(direction, spec)

	nextFlight += 1
	local flightId = nextFlight
	-- A NIL THROWER DRAWS CORRECTLY. The client handler validates the origin,
	-- the velocity, the id and the gadget key; the thrower is read only to
	-- reconcile a local player's own prediction, and scenery has none.
	Remotes.get("GadgetFlight"):FireAllClients(nil, cfg.throw.gadget, from, velocity,
		workspace:GetServerTimeNow(), flightId)

	-- THE SEGMENT IS CAST, NEVER THE POINT, which is the rule a player's flight
	-- already keeps: stepped point-to-point, a gum crossing a fence between two
	-- frames would pass clean through it. The resident's own figure is excluded
	-- so the first cast does not hit the thrower.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { resident.model :: any }

	task.spawn(function()
		local t = 0
		local hit = false
		local at, prev = from, from
		local normal: Vector3? = nil
		while t < Config.THROW.maxSeconds do
			local dt = RunService.Heartbeat:Wait()
			t += dt
			at = Config.throwPointAt(from, velocity, t)
			local blocked = workspace:Raycast(prev, at - prev, params)
			if blocked then
				at = blocked.Position
				normal = blocked.Normal
			end
			local root = thief.Character and thief.Character:FindFirstChild("HumanoidRootPart")
			if root and ((root :: BasePart).Position - at).Magnitude <= Config.THROW.hitRadius then
				hit = true
				break
			end
			if blocked or not root then
				break
			end
			prev = at
		end
		Remotes.get("GadgetFlightEnd"):FireAllClients(flightId, at)
		if hit then
			HeistService.neighbourHit(thief, spec, resident.name)
		elseif spec.puddle then
			-- A MISS LEAVES THE SAME MESS A PLAYER'S DOES. The gum is the gum:
			-- it splats where it lands and anybody who walks through it gets
			-- stuck, which is the whole reason a thrown miss is not a wasted
			-- throw. `dropPuddle` refuses a wall on its own, so a gum that hits
			-- a fence is a picture and not a slow zone behind it.
			GadgetService.dropPuddle(nil, spec, at, normal, resident.name)
			playHit(spec, at)
		end
	end)
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

	local puddleClock = 0
	RunService.Heartbeat:Connect(function(dt)
		puddleClock += dt
		if puddleClock < 0.1 or #puddles == 0 then
			return
		end
		puddleClock = 0
		local ok, err = pcall(stepPuddles)
		if not ok then
			warn("[GadgetService] puddles: " .. tostring(err))
		end
	end)

	Remotes.get("GadgetCock").OnServerEvent:Connect(function(player, on)
		if type(on) ~= "boolean" then
			return
		end
		GadgetService.cock(player, on)
	end)

	Remotes.get("GadgetRequest").OnServerEvent:Connect(function(player, key)
		if type(key) ~= "string" then
			return
		end
		GadgetService.buy(player, key)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastThrow[player] = nil
		cocked[player] = nil
		stateCount[player] = nil
	end)
end

return GadgetService
