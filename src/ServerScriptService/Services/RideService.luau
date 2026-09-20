--!strict
--[[
	RideService

	Skateboards, bikes, scooters, hoverboards and the scrambler: what a player
	gets around on between plots.

	WHAT A RIDE IS FOR, AND WHAT IT IS NOT FOR

	"Speed is the currency" is the load-bearing rule this feature runs straight
	into. BASE_WALK_SPEED (16) is what the carry penalty, the three dog speeds,
	every fence snag and the length of a getaway are all calibrated against,
	and anything that makes a player faster than 16 invalidates all of them at
	once. Every ride in Config.RIDES does exactly that -- the scrambler doubles
	it -- so the entire design of this service is the set of conditions under
	which it is switched OFF:

		* You are carrying loot.          (protects the getaway)
		* Someone is carrying yours.      (protects the offence tree)
		* A fence has you snagged.        (protects the fence)
		* You are inside anybody's yard.  (protects the lawn)

	The first three are HeistService.rideBlockReason, because that module owns
	all of them. The fourth is geometry and lives here.

	What is left over is the street, which was the one part of this game that
	was pure walking: twelve plots at 64-stud spacing means a lap on foot is
	the better part of a minute of holding W. A ride buys that back, and it is
	the most VISIBLE thing anyone owns -- a house stands 70 studs back and a
	skin is on a piggy, but a board is under you, moving, in the middle of the
	street where everybody is. That is the whole purchase. Like a house, it
	confers nothing else.

	MOUNTING IS AUTOMATIC. There is no button and no prompt.

	Deliberate, and the same call the decorations made: this audience is mostly
	on a touchscreen, the HUD already carries a collect prompt, a steal prompt
	and a rebirth button, and "press E to get on your skateboard" is a rule to
	learn for something the game can just decide. You walk out of your gate and
	you are on it; you step onto a lawn and you are off it. The dismount is
	also a mechanic in its own right -- it is how a thief finds out, physically
	rather than through a message, that the getaway is run on foot.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RideModel = require(ReplicatedStorage.Shared.RideModel)
local RidePose = require(ReplicatedStorage.Shared.RidePose)
local HeldItemService = require(script.Parent.HeldItemService)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local HeistService = require(script.Parent.HeistService)
local StealthService = require(script.Parent.StealthService)
local PassService = require(script.Parent.PassService)

-- Which pass gates the alternate poses. One pass covers every ride rather than
-- one per ride: a player who buys it and later buys a fourth board already has
-- its pose waiting, which is the difference between a purchase that keeps
-- paying off and five that each stop mattering.
local STANCE_PASS = "stylePack"

local RideService = {}

-- The model currently welded under each rider, and which ride it is.
--
-- `animate` is the one bit of the character mounting borrows: the script is
-- switched off so the legs stop walking, and remembered rather than looked up
-- again, so dismount re-enables the script it actually disabled even if the
-- character changed underneath in between.
local mounted: { [Player]: {
	model: Model,
	key: string,
	baseHip: number,
	animate: BaseScript?,
	motor: Motor6D?,
	motorBase: CFrame?,
	trickTween: Tween?,
} } = {}

-- THE SIDEWAYS STANCE IS PUBLISHED, NOT APPLIED.
--
-- A skateboarder stands across the deck. The tidy way to do that is to turn
-- the root JOINT so only the drawn body moves, and it does not work: `C0` is
-- read only on the `AnimationConstraint` newer rigs use in place of a Motor6D,
-- and `Transform`, which is writable, is a read-back of the animation result
-- rather than an input to it -- a write from the client changes nothing on
-- screen. Both measured on a live character, not guessed.
--
-- What works is turning the HumanoidRootPart itself with `AutoRotate` off. The
-- controls move a humanoid along a world vector that has nothing to do with
-- which way it faces, so travel is unaffected by the turn.
--
-- That has to happen on the CLIENT: a character is network-owned by its own
-- player, so this is the one machine whose root CFrame writes are authoritative
-- -- which is also why nothing has to run on anybody else's, since the root is
-- replicated and every other player sees the turn for free. All the server
-- does is say how far round to stand, and counter-rotate the board when it
-- welds it so the deck still points along travel. ClientMain owns the rest.
local RIDE_YAW_ATTRIBUTE = "RideYaw"

-- Which pose to hold while riding, published the same way and for the same
-- reason: a pose is a KeyframeSequence registered at runtime, and a hash:// id
-- is local to the peer that registered it, so it CANNOT be replicated by
-- playing the track here. The server says what is being ridden and every
-- client builds and plays the pose itself -- the shape the dodge roll and the
-- animated skins already use.
--
-- Carries the STYLE rather than the ride key, because the pose belongs to the
-- shape of the thing: a second bike added tomorrow with style "bmx" is sat on
-- exactly the same way, and RidePose should not need editing to know that.
local RIDE_STYLE_ATTRIBUTE = "RideStyle"

-- Whether the trick is being held right now, published for the same reason as
-- the style: the rider has to LEAN with the ride, and a lean is a pose, and a
-- pose is a hash:// animation every client has to play for itself. Without
-- this the ride tipped 30 degrees and the rider stayed bolt upright with their
-- hands 2.01 studs off the grips -- measured, and the whole of what "the
-- wheelie is broken" turned out to mean.
local RIDE_TRICK_ATTRIBUTE = "RideTricking"

-- Stop the legs. A rider gliding along doing a walk cycle is the single thing
-- that gives away that a ride is a costume rather than a vehicle.
--
-- Disabling the Animate script is what stops NEW animations; the tracks
-- already running have to be stopped separately or the current stride keeps
-- playing to its end. With both done the rig settles into its default pose,
-- which is a plausible standing-on-a-board shape and costs no uploaded asset.
local function setWalkAnimation(character: Model, humanoid: Humanoid, on: boolean): BaseScript?
	local animate = character:FindFirstChild("Animate")
	if animate and animate:IsA("BaseScript") then
		animate.Disabled = not on
	end

	if not on then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
				track:Stop(0.15)
			end
		end
	end

	return if animate and animate:IsA("BaseScript") then animate else nil
end

-- The last reason a player was refused, so the same message is not fired
-- every tick. Walking around your own lawn would otherwise be a toast every
-- tenth of a second.
local lastReason: { [Player]: string } = {}

-- Who has already been told why their ride comes off at a gate.
--
-- Said ONCE per session and then never again. Silence is wrong -- a board
-- that vanishes with no explanation reads as the expensive thing they just
-- bought being broken -- but so is a toast every time somebody steps onto
-- their own lawn, which is a thing they do constantly. Once is the whole
-- budget.
local toldAboutGates: { [Player]: boolean } = {}

local function notify(player: Player, message: string, kind: string)
	Remotes.get("Notify"):FireClient(player, message, kind)
end

local function rides(data: any)
	if type(data.rides) ~= "table" then
		data.rides = { owned = {}, equipped = "", stance = {} }
	end
	if type(data.rides.owned) ~= "table" then
		data.rides.owned = {}
	end
	if type(data.rides.equipped) ~= "string" then
		data.rides.equipped = ""
	end
	-- How the rider sits on each thing, keyed by ride. PER RIDE rather than
	-- one setting for the lot: the poses are per style and the choices are not
	-- comparable -- arms folded on a hoverboard has no meaning on a bike -- so
	-- a single field would have to be reinterpreted at every mount and would
	-- silently mean something different depending on what you were on.
	--
	-- Reconciled here rather than behind a schema bump, the same way `owned`
	-- and `equipped` already are: an absent field is a player who has never
	-- chosen one, which is exactly what an empty table says.
	if type(data.rides.stance) ~= "table" then
		data.rides.stance = {}
	end
	return data.rides
end

-- The stance chosen for a ride, or "" for the pose it ships with.
--
-- Validated on the way OUT as well as on the way in. A stance that was
-- retired, or that belonged to a style before the ride was re-pointed at
-- another one, would otherwise sit in the save forever and publish a key
-- every client has to fall back from.
-- The stance chosen for a ride, or "" for the pose it ships with.
--
-- Validated three ways on the way OUT, not just on the way in. A stance can
-- stop being wearable long after it was chosen: it can be retired from
-- RidePose, it can belong to a style the ride no longer has, or -- the one
-- that matters here -- the player can have been wearing it on a pass that has
-- since lapsed or that they never owned on this server. Reading it back
-- through this function means every one of those ends up as the ride's own
-- pose rather than as a key no client can play.
local function stanceFor(player: Player, key: string): string
	local spec = Config.RIDES[key]
	local data = DataService.get(player)
	if not spec or not data then
		return ""
	end
	local chosen = rides(data).stance[key]
	if type(chosen) ~= "string" or chosen == "" then
		return ""
	end
	if not RidePose.hasStance(spec.style, chosen) then
		return ""
	end
	if not PassService.unlocked(player, STANCE_PASS) then
		return ""
	end
	return chosen
end

-- ============================================================
-- MOUNTING
-- ============================================================

-- The FLOOR under a character, in world space, derived from the root rather
-- than raycast for it.
--
-- HipHeight plus half the root part is the standard formula. Measured against
-- a raycast on a real R15 character standing on a plot it came out 0.002
-- studs off, which is the whole reason it is used instead: a raycast would
-- also have to decide what counts as ground, and a decoration or a coin pile
-- under the player would answer it wrongly.
--
-- Note this returns the same value whatever HipHeight is set to -- raising
-- HipHeight lifts the root by exactly as much as it subtracts. That is what
-- makes the mount work: the rider goes UP onto the deck and the wheels stay
-- on the road.
local function floorCFrame(root: BasePart, humanoid: Humanoid): CFrame
	return root.CFrame * CFrame.new(0, -(humanoid.HipHeight + root.Size.Y / 2), 0)
end

local function dismount(player: Player)
	local current = mounted[player]
	if not current then
		return
	end
	mounted[player] = nil
	-- Cancelled before the model goes: a tween still running against a
	-- destroyed Motor6D is a live reference to a dead instance.
	if current.trickTween then
		current.trickTween:Cancel()
	end
	current.model:Destroy()

	-- Back down off the deck. Restoring the REMEMBERED value rather than
	-- subtracting the ride's stand height, so a respawn in between (which
	-- gives the new humanoid the rig default) cannot leave a player walking
	-- around permanently one stud taller than everybody else.
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.HipHeight = current.baseHip
	end

	-- Square the body back up and give the legs back.
	--
	-- The stance is cleared on whatever character is current rather than on a
	-- remembered one: a respawn hands over a different rig, and the new one
	-- starts at zero anyway, so clearing the live character is both correct
	-- and enough. Animate is restored from the script recorded at mount,
	-- guarded on Parent, because that one DOES belong to the old rig after a
	-- respawn and re-enabling a destroyed script is pointless.
	if character then
		character:SetAttribute(RIDE_YAW_ATTRIBUTE, 0)
		character:SetAttribute(RIDE_STYLE_ATTRIBUTE, "")
		character:SetAttribute(RIDE_TRICK_ATTRIBUTE, false)
	end
	if current.animate and current.animate.Parent then
		current.animate.Disabled = false
	end

	HeistService.setRideMultiplier(player, 1)
	RideService.push(player)
end

-- Is the model we think is mounted still on the character we think it is on?
--
-- Dying destroys the character and every welded model with it, but leaves
-- `mounted` holding a reference and -- far worse -- leaves the multiplier set
-- inside HeistService. A thief who respawned mid-chase would have walked away
-- at scrambler speed with no board visible and nothing on screen to explain
-- it. Respawning is not something this module gets told about, so it checks.
local function mountIsLive(player: Player): boolean
	local current = mounted[player]
	return current ~= nil
		and current.model.Parent ~= nil
		and current.model.Parent == player.Character
end

local function mount(player: Player, key: string)
	local spec = Config.getRide(key)
	local character = player.Character
	if not spec or not character then
		return
	end

	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end

	-- THE RIDER GOES UP; THE RIDE STAYS ON THE ROAD.
	--
	-- Every ride is authored with y = 0 at the ground, so seating one at the
	-- character's feet buries the rider's shins in their own deck -- measured
	-- at 0.98 studs of skateboard through the ankles. HipHeight is what fixes
	-- it: raising it lifts the character clear by exactly the height of the
	-- surface they are standing on, and the model then goes on the floor
	-- underneath to fill the gap.
	--
	-- Order matters. HipHeight is set FIRST and the placement is computed from
	-- the new value, because the weld locks in whatever offset exists at that
	-- moment and the character has not physically risen yet. Reading the
	-- position back after setting it would catch the character mid-rise and
	-- weld the board a stud into the air.

	-- THE RIDE IS BUILT BEFORE THE CHARACTER IS TOUCHED, and that ordering is
	-- the difference between a mount that fails and a player who cannot land.
	--
	-- Everything that can fail in a mount fails HERE -- building the geometry
	-- and reading its chassis -- and none of it needs the character at all.
	-- It used to run after the HipHeight write, which made a throw anywhere
	-- below catastrophic rather than merely broken: HipHeight was already
	-- raised, `mounted[player]` was never set, so dismount had nothing to
	-- restore it from. And the gate polls TEN TIMES A SECOND, re-entering
	-- mount each tick and reading the already-raised HipHeight as the new
	-- base -- so the failure did not settle at one stud of float, it
	-- accumulated. Measured on the hoverdisc, whose missing `accent` threw
	-- inside addTrail: HipHeight climbed 2.22 to 23.81 in three seconds and
	-- went on climbing, with no ride visible and nothing the player could
	-- press to come down.
	--
	-- So: a mount either completes or leaves the character exactly as it
	-- found it. Any future failure between here and the end is a ride that
	-- does not appear, which is a bug somebody reports; the other shape is a
	-- bug that eats the session.
	local model = RideModel.build(key)
	local chassis = model:FindFirstChild("Chassis") :: BasePart?
	if not chassis then
		-- Destroyed rather than left to the collector: it is parented to
		-- nothing yet, and an orphan model holding a Trail is a leak per
		-- failed tick at this poll rate.
		model:Destroy()
		return
	end
	RideModel.addTrail(model, spec.accent)

	local baseHip = humanoid.HipHeight
	humanoid.HipHeight = baseHip + (spec.stand or 0)

	-- TURNED HALF ROUND, because a character's front is its root's -Z.
	--
	-- Every ride is authored facing +Z, and floorCFrame keeps the root's
	-- rotation -- so seating one straight onto it points the handlebars out of
	-- the rider's back. It is exactly the LookVector trap the guard dog and the
	-- mini piggy already hit (LookVector is -Z, so a model authored on +Z needs
	-- a half turn), reached through a weld this time instead of CFrame.lookAt.
	--
	-- It read as fine on the skateboard and the old hoverboard because both
	-- were near enough symmetric to hide it; the bike and the scooter have a
	-- front, and rode backwards from the day they were built.
	-- ...and then turned BACK by the stance angle, for the rides ridden
	-- sideways.
	--
	-- The client points the root along travel plus `bodyYaw` so the rider
	-- stands across the deck, and the ride is welded to that root -- so
	-- without this the board would swing round with the body and travel
	-- sideways. Countering it here means root faces travel plus the yaw and
	-- the board faces travel, which is the arrangement being asked for.
	local at = floorCFrame(root, humanoid)
		* CFrame.Angles(0, math.pi - math.rad(spec.bodyYaw or 0), 0)

	model:PivotTo(at)

	-- ONE JOINT TO THE CHARACTER, and everything else rigid behind it.
	--
	-- Every part used to weld straight to the root, which is simpler and makes
	-- the whole ride immovable: a WeldConstraint has no offset to change, so
	-- there was no way to tip the board for a manual or the bike for a
	-- wheelie. Now the parts weld to a chassis and the CHASSIS takes a Motor6D
	-- to the root -- a Motor6D's C0 is a plain property, so the server can
	-- tween it and every client sees it, unlike the animation-state channels
	-- that turned out to be client-authoritative.
	--
	-- Welded, not anchored. An anchored part welded to a humanoid pins the
	-- humanoid in place; every part is already Massless so this adds nothing
	-- to how the character walks or jumps.
	--
	-- `chassis` is resolved above, before anything about the character was
	-- changed -- see the note there.
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part ~= chassis then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = chassis
			weld.Part1 = part
			weld.Parent = part
		end
	end

	local motor = Instance.new("Motor6D")
	motor.Name = "RideMount"
	motor.Part0 = root
	motor.Part1 = chassis
	motor.C0 = root.CFrame:ToObjectSpace(at)
	motor.Parent = root

	model.Parent = character

	local animate = setWalkAnimation(character, humanoid, false)

	-- Publish the stance for the clients to apply. See RIDE_YAW_ATTRIBUTE.
	--
	-- The chosen stance rides along inside the style string rather than in an
	-- attribute of its own, because it IS part of which pose to play -- see
	-- RidePose.key. One attribute means a client cannot read a new style
	-- against a stale stance, which two would have made possible on exactly
	-- the frame somebody changed one.
	character:SetAttribute(RIDE_YAW_ATTRIBUTE, spec.bodyYaw or 0)
	character:SetAttribute(RIDE_STYLE_ATTRIBUTE,
		RidePose.key(spec.style or "", stanceFor(player, key)))
	character:SetAttribute(RIDE_TRICK_ATTRIBUTE, false)

	-- BOTH HANDS ARE ON THE BARS. Every ride here is posed with measured
	-- contacts -- hand-to-grip lands at 0.01 to 0.06 studs -- so a bone left
	-- in the right fist is a bone through the handlebar the pose put the hand
	-- on. Named rather than silent, because the prop leaving a player's own
	-- hand with nothing said reads as having lost the item.
	HeldItemService.putAway(player, "You put that away to ride.")

	mounted[player] = {
		model = model,
		key = key,
		baseHip = baseHip,
		animate = animate,
		motor = motor,
		motorBase = motor.C0,
	}
	HeistService.setRideMultiplier(player, Config.rideMultiplier(spec))
	RideService.push(player)
end

-- ============================================================
-- TRICKS
-- ============================================================
--
-- A manual on the board, a wheelie on the bike: the ride tips back onto its
-- rear wheels for as long as the button is held.
--
-- It is a LOOK AND NOTHING ELSE. No speed, no jump, no advantage, and nothing
-- that any other system has to be re-balanced against -- the same line houses
-- and rides themselves are held to. That is also what makes it safe to leave
-- entirely unguarded: there is nothing to gain by spamming it.
--
-- Driven by tweening the mount's C0 on the SERVER, which is the one channel
-- established to work here. C0 is a plain property rather than animation
-- state, so the change replicates and everyone on the street sees the trick;
-- a tween means one instruction rather than a CFrame write per frame.
--
-- THE RIDER LEANS WITH IT, and that half is a pose rather than a joint.
--
-- The ride tips here; the body is turned by RidePose on every client. It has
-- to be that way round because the root itself cannot be pitched -- the
-- Humanoid rights it within a frame or two, measured at -28 degrees asked for
-- and under -10 ever reached -- so the lean lives in the LowerTorso, which
-- only the animation system can drive.
--
-- The pose is not tuned to match this rotation, it is DERIVED from it: see
-- RidePose.trickDelta, which conjugates this very transform through the mount.
-- And it is not merely STARTED with it -- every client reads the chassis's
-- own rotation each frame and leans to whatever it finds, so the two cannot
-- drift however this tween is shaped.
function RideService.setTrick(player: Player, on: boolean)
	local current = mounted[player]
	if not current or not current.motor or not current.motorBase then
		return
	end

	local spec = Config.getRide(current.key)
	local trick = spec and spec.trick
	if not trick then
		return
	end

	if current.trickTween then
		current.trickTween:Cancel()
		current.trickTween = nil
	end

	local target = current.motorBase
	if on then
		-- About the rear contact patch, not the model's centre. Negative on X
		-- because rotating about +X drives the model's +Z -- its nose -- down,
		-- and the whole point is to lift it.
		local pivot = trick.pivot or 0
		target = current.motorBase
			* CFrame.new(0, 0, pivot)
			* CFrame.Angles(-math.rad(trick.pitch), 0, 0)
			* CFrame.new(0, 0, -pivot)
	end

	-- UP SLOWLY, DOWN QUICKLY, because a wheelie is a lever and a landing is
	-- gravity. Easing in AND out on the way up is what reads as a heave: the
	-- machine starts from rest, which the old front-loaded curve did not --
	-- it was 73% of the way up within a tenth of a second, which is where
	-- "the bike comes up faster than the rider" came from.
	--
	-- The rider follows this whatever it is. RidePose.phaseOf reads the
	-- chassis rather than a clock, so the curve here is now purely a question
	-- of feel and cannot put anybody's hands off the grips. Before that it
	-- was load-bearing and silently wrong.
	local rising = on
	local tween = TweenService:Create(
		current.motor,
		TweenInfo.new(
			if rising then 0.26 else 0.20,
			Enum.EasingStyle.Quad,
			if rising then Enum.EasingDirection.InOut else Enum.EasingDirection.In),
		{ C0 = target })
	current.trickTween = tween
	tween:Play()

	-- Published AFTER the refusals above, so a ride with no trick never
	-- announces one. Nothing poses off this any more -- the lean is measured
	-- from the machine -- but it stays as the one honest answer to "is this
	-- player holding the button", which nothing else on a remote peer has.
	local character = player.Character
	if character then
		character:SetAttribute(RIDE_TRICK_ATTRIBUTE, on)
	end
end

-- ============================================================
-- THE GATE
-- ============================================================

-- Nil when the player should be riding, otherwise why not.
--
-- `silent` reasons are the normal state of affairs rather than a refusal --
-- standing on your own lawn is not a rejection worth a toast, it is just
-- where you are. Only the heist reasons are worth telling somebody about,
-- and only once each.
local function blockReason(player: Player, data: any): (string?, boolean)
	local equipped = rides(data).equipped
	if equipped == "" or not Config.getRide(equipped) then
		return "none", true
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return "no character", true
	end

	local heist = HeistService.rideBlockReason(player)
	if heist then
		return heist, false
	end

	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return "no character", true
	end

	-- TWO TESTS, AND THE REDUNDANCY IS DELIBERATE.
	--
	-- `isOnStreet` is the positive rule and the one that matches what a player
	-- is told: rides are for the street. It is narrower than "not in a yard" --
	-- it also rules out the woodland behind the plots and the twelve-stud
	-- alleys between neighbouring yards, which are public ground but are not a
	-- street, and which nobody should be crossing at 33 studs a second.
	--
	-- `yardContaining` is a veto on top of it. The two cannot disagree with the
	-- layout as it stands -- the corridor stops at the front fences -- but if
	-- the plots are ever moved, one of these is balance-critical and the other
	-- is tidiness, and this is the order that fails safe. A ride inside a yard
	-- breaks the fence, the dog and the steal; a ride in the woods is only
	-- untidy.
	-- A wheelie bin is not on a skateboard.
	--
	-- Beyond the obvious: StealthService hides the character by walking its
	-- descendants ONCE, at the moment of concealing. A ride mounted after that
	-- is not on the list, so it stays fully visible -- a floating motorbike
	-- parked inside an ornament, which is a worse tell than no disguise at all.
	if StealthService.isDisguised(player) then
		return "hidden", true
	end

	if PlotService.yardContaining(root.Position) then
		return "on a lawn", true
	end
	if not Config.isOnStreet(root.Position) then
		return "off the street", true
	end

	return nil, true
end

local function step()
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService.get(player)
		if data then
			local reason, silent = blockReason(player, data)
			local equipped = rides(data).equipped

			-- A mount that died with its character counts as no mount, and has
			-- to be cleared through dismount rather than forgotten, because the
			-- speed multiplier lives in HeistService and outlives the model.
			if mounted[player] and not mountIsLive(player) then
				dismount(player)
			end

			if reason then
				if mounted[player] then
					dismount(player)
					if not silent and lastReason[player] ~= reason then
						notify(player, reason, "warn")
					elseif silent and not toldAboutGates[player] then
						toldAboutGates[player] = true
						notify(player, "Rides are for the street. You hop off at the gate.", "warn")
					end
				end
				lastReason[player] = reason
			else
				lastReason[player] = nil
				local current = mounted[player]

				if not current then
					mount(player, equipped)
				elseif current.key ~= equipped then
					-- Swapped ride while out on the street.
					dismount(player)
					mount(player, equipped)
				end
			end
		end
	end
end

-- ============================================================
-- BUYING AND EQUIPPING
-- ============================================================

function RideService.buy(player: Player, key: string)
	local spec = Config.RIDES[key]
	local data = DataService.get(player)
	if not spec or not data then
		return
	end

	local owned = rides(data).owned

	-- Already owned? Then this is a toggle, not a purchase -- the same shape
	-- as decorations and accessories, and for the same reason: putting a ride
	-- away has to be possible, and toggling beats a refund because no coins
	-- move and there is nothing to farm by buying and selling.
	if owned[key] then
		if rides(data).equipped == key then
			rides(data).equipped = ""
			notify(player, ("%s put away."):format(spec.name), "good")
		else
			rides(data).equipped = key
			notify(player, ("Riding the %s."):format(spec.name), "good")
		end
		DataService.save(player)
		RideService.push(player)
		return
	end

	if data.coins < spec.cost then
		notify(player, ("Need %d more coins for the %s."):format(spec.cost - data.coins, spec.name), "warn")
		return
	end

	data.coins -= spec.cost
	owned[key] = true
	-- Straight onto it. Buying a ride and then having to tap it again to use
	-- it is a second step for a decision already made.
	rides(data).equipped = key

	notify(player, ("%s unlocked! Head out to the street."):format(spec.name), "good")
	DataService.save(player)
	RideService.push(player)
end

-- Chooses how the rider sits on a ride they own.
--
-- Cosmetic and nothing else -- it writes no speed, no multiplier and no gate
-- -- so the only things worth checking are that the ride is theirs and that
-- the stance is real. A forged one would otherwise be published as a style
-- key every client in the server has to fall back from.
function RideService.setStance(player: Player, key: string, stance: string)
	local spec = Config.RIDES[key]
	local data = DataService.get(player)
	if not spec or not data then
		return
	end

	local store = rides(data)
	if not store.owned[key] then
		return
	end
	if stance ~= "" and not RidePose.hasStance(spec.style, stance) then
		return
	end
	-- Refused OUT LOUD, and without spending anything. A style the player
	-- cannot wear has to say why: a stance that silently snapped back to the
	-- default would be indistinguishable from the button being broken, which
	-- is the one thing the client is never allowed to look like.
	if stance ~= "" and not PassService.unlocked(player, STANCE_PASS) then
		local pass = Config.PASSES[STANCE_PASS]
		notify(player, ("%s unlocks that one."):format(pass and pass.name or "A pass"), "warn")
		return
	end

	store.stance[key] = if stance ~= "" then stance else nil
	DataService.save(player)

	-- Re-publish to a rider who is already on it, so the change lands
	-- immediately instead of at the next gate. Only the attribute moves; the
	-- model, the weld and the multiplier are all untouched, which is why this
	-- does not have to dismount and remount to take effect.
	local current = mounted[player]
	local character = player.Character
	if current and current.key == key and character then
		character:SetAttribute(RIDE_STYLE_ATTRIBUTE,
			RidePose.key(spec.style or "", stanceFor(player, key)))
	end

	RideService.push(player)
end

function RideService.push(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end

	local owned = rides(data).owned
	local equipped = rides(data).equipped

	local list = {}
	for key, spec in pairs(Config.RIDES) do
		list[key] = {
			name = spec.name,
			order = spec.order,
			cost = spec.cost,
			loot = spec.loot,
			blurb = spec.blurb,
			-- Shown as a percentage rather than a multiplier: "+35% on the
			-- street" is a sentence a nine year old reads once, where "x1.35"
			-- is one they have to work out.
			boost = math.floor((Config.rideMultiplier(spec) - 1) * 100 + 0.5),
			-- Rides are collected and kept, so they carry a tier like the skins
			-- and the decorations. Bones and gadgets deliberately do not: a tier
			-- on something you rebuy every time you throw it describes a purchase
			-- you will make a hundred times, which is not a rarity.
			rarity = Config.rarityOf(spec),
			owned = owned[key] == true,
			equipped = equipped == key,
		}
	end

	-- The trick's NAME, not a flag: it is what the button says, and the two
	-- rides that have one call it different things.
	local current = mounted[player]
	local mountedSpec = current and Config.getRide(current.key)
	local trick = mountedSpec and mountedSpec.trick

	-- Stances for whatever is EQUIPPED, not for whatever is being ridden.
	-- The street gate flicks `riding` off at every gate, and a picker that
	-- emptied itself each time somebody stepped onto their own lawn would
	-- look broken rather than gated.
	local equippedSpec = if equipped ~= "" then Config.RIDES[equipped] else nil
	local stances = if equippedSpec then RidePose.stances(equippedSpec.style) else nil

	-- Locked stances are SENT, not filtered out. The shop is where something
	-- you do not own is supposed to be advertised, and a list that quietly
	-- omitted them would leave the pack with nothing on screen to explain what
	-- it buys.
	local unlocked = PassService.unlocked(player, STANCE_PASS)
	if stances then
		for _, entry in ipairs(stances) do
			entry.locked = entry.key ~= "" and not unlocked
		end
	end

	local pass = Config.PASSES[STANCE_PASS]

	Remotes.get("RideState"):FireClient(player, {
		rides = list,
		riding = current ~= nil,
		trick = trick and trick.name or nil,
		stances = stances,
		stance = if equipped ~= "" then stanceFor(player, equipped) else nil,
		pass = pass and {
			name = pass.name,
			blurb = pass.blurb,
			robux = pass.robux,
			owned = unlocked,
			-- nil while no pass exists, which is how the client knows to show
			-- the offer as unavailable rather than opening a prompt for id 0.
			id = PassService.idOf(STANCE_PASS),
		} or nil,
	})
end

-- Everything the admin wipe has to clear, in one place, so a field added here
-- cannot be forgotten there.
-- Whether this player is on something right now. `mounted` is private and
-- should stay so; this exists because the held-item veto has to ask, and a
-- second copy of "is there an entry in that table" is a second thing to keep
-- in step with it.
function RideService.isRiding(player: Player): boolean
	return mounted[player] ~= nil
end

function RideService.clear(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	data.rides = { owned = {}, equipped = "", stance = {} }
	dismount(player)
	RideService.push(player)
end

-- The entry ride, handed over when somebody owns the pass and owns nothing to
-- put a pose on. See Config.PASSES.stylePack.entryRide for why it is the
-- cheapest ride rather than a matching one.
--
-- Costs no coins and takes none: this is a grant, not a purchase, because a
-- Robux purchase may hand over an item but must never mint the coins that
-- would buy it.
local function grantEntryRide(player: Player)
	local pass = Config.PASSES[STANCE_PASS]
	local key = pass and pass.entryRide
	local spec = key and Config.RIDES[key]
	local data = DataService.get(player)
	if not spec or not data or not PassService.owns(player, STANCE_PASS) then
		return
	end

	local store = rides(data)
	for _ in pairs(store.owned) do
		-- Owns something already. Nothing to do, and this is what makes the
		-- grant self-clearing rather than something to record.
		return
	end

	store.owned[key] = true
	store.equipped = key
	notify(player, ("%s unlocked the %s to ride it on."):format(pass.name, spec.name), "good")
	DataService.save(player)
	RideService.push(player)
end

function RideService.onPlayerReady(player: Player)
	grantEntryRide(player)
end

function RideService.start()
	-- Fires at join once the ownership check lands, and again the instant a
	-- purchase completes -- the two moments the answer can change.
	PassService.Granted:Connect(function(player: Player, key: string)
		if key ~= STANCE_PASS then
			return
		end
		grantEntryRide(player)
		-- Re-published either way: the stances the player just bought have to
		-- stop reading as locked without them having to reopen anything.
		RideService.push(player)
	end)

	Remotes.get("RideRequest").OnServerEvent:Connect(function(player, key)
		if type(key) ~= "string" then
			return
		end
		RideService.buy(player, key)
	end)

	Remotes.get("RideStance").OnServerEvent:Connect(function(player, key, stance)
		if type(key) ~= "string" or type(stance) ~= "string" then
			return
		end
		RideService.setStance(player, key, stance)
	end)

	-- Unrate-limited on purpose. A trick moves one joint on a massless model
	-- and confers nothing, so the worst a player can do by hammering it is
	-- make their own board wobble.
	Remotes.get("RideTrick").OnServerEvent:Connect(function(player, on)
		if type(on) ~= "boolean" then
			return
		end
		RideService.setTrick(player, on)
	end)

	Players.PlayerRemoving:Connect(function(player)
		mounted[player] = nil
		lastReason[player] = nil
		toldAboutGates[player] = nil
	end)

	-- Dying drops the ride, the same way it drops loot. The model goes with
	-- the old character on its own; this is here for the multiplier, which
	-- does not.
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			dismount(player)
		end)
	end)

	-- Polled, not event-driven, and for the reason the guard dog's patrol was
	-- rewritten from a long task.wait: a player can cross a fence line by any
	-- route, and the four things that gate a ride change independently of each
	-- other and of anything this module could listen to.
	--
	-- Ten times a second. The work is a rectangle test per plot per player --
	-- 144 comparisons a tick at a full server -- and the cost of being slower
	-- is overshoot: at the scrambler's 33.6 studs/sec, a tenth of a second is
	-- 3.4 studs past the fence line before the board disappears. A quarter of
	-- a second would be eight, which is far enough into a yard to notice.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		accumulator = 0
		step()
	end)
end

return RideService
