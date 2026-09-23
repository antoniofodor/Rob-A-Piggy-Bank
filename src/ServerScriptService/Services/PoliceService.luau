--!strict
--[[
	PoliceService

	A patrol car drives the street every few minutes. Rob somebody while it is
	out and an officer gets out and chases you for thirty seconds; outlast them
	and they give up and drive off, get caught and your piggy bank pays bail.

	WHY THIS EXISTS. Every other risk in the game belongs to the victim -- the
	dog they bought, the fence they upgraded, the lock they are holding, the tag
	they have to be present to make. That leaves one hole no purchase can close:
	robbing somebody who is offline, or who is stood at the far end of the
	street, is completely free, because the person who paid for the defence is
	not there to use it. The patrol is the house's own risk. It cannot be
	upgraded, bribed or aimed, and it does not care whose plot you were
	standing on.

	THE THREE RULES IT IS BUILT ON, all of which come from elsewhere in this
	project and none of which it is allowed to bend:

	  1. SPEED IS THE CURRENCY. The officer runs at 14.5 -- between a carrying
	     thief's 12 and a free player's 16 -- so holding the loot means losing
	     ground and DELIVERING is the answer. Nothing in this file exceeds
	     BASE_WALK_SPEED. The car is faster, but the car cannot catch anybody:
	     only the officer's catchRadius ends a chase.

	  2. BANKED COINS ARE PERMANENTLY SAFE. Bail comes out of `vault`, the
	     uncollected pile that was already stealable, and never out of `coins`.
	     A patrol can cost you an afternoon's idle income. It can never cost
	     you progress, and it can never touch a house, a skin or an accessory.

	  3. NO PLAYER CAN EVER POINT IT AT ANOTHER PLAYER. Same shipping
	     requirement the gadgets carry, and the one rule in this file that is
	     not allowed to bend for anything.

	     It is worth being precise, because two softer-sounding versions of it
	     have already stopped being true. "Only chases you while you are
	     robbing" went when Most Wanted shipped, and "cannot be summoned" went
	     when the Patrol Radio did. Neither was the point. What protects a
	     child from being harassed is that NOTHING ANOTHER PLAYER DOES CAN AIM
	     AN OFFICER AT THEM: you get on the list by robbing people, you are
	     the only person who can put yourself on it, and being caught takes
	     you off it.

	     A radio call is bought TIMING, never a target. It brings a car onto
	     the street and says nothing about who for; the pursuit is then chosen
	     by the two rules below, from the same two sources it always was. The
	     caller cannot name anybody and cannot exclude themselves -- if they
	     are top of the board, the officer gets out for them. There is still
	     no message anywhere in this feature that carries a player.

	AND MOST WANTED, WHICH IS THE ONE REASON AN OFFICER CHASES SOMEBODY WHO IS NOT
	holding loot. If the drive up and down the street ends with nobody having
	robbed anybody, the patrol goes after the name on the plaza board instead:
	the player with the biggest rap sheet this session. Three things keep that
	from being a tax on playing well, and removing any of them breaks it:

	  * A LIVE ROBBERY ALWAYS WINS. The cruise runs first and a completed steal
	    during it takes the pursuit, exactly as before. Most Wanted is what
	    happens in the gap, not a replacement for the alarm.

	  * THE TARGET IS NOT CARRYING ANYTHING, so they run at 16 against an
	    officer at 14.5 and simply outrun them. Being wanted is dangerous
	    precisely when you are greedy enough to be holding loot as well -- which
	    is the decision this whole feature is built around, handed to the one
	    player who has taken the most.

	  * THE ARREST CLEARS THE SHEET, so the title passes to somebody else and
	    the same child is not hunted for the rest of the evening. Bail is three
	    times the RECORD rather than three times a carry, because the record is
	    what they were brought in for -- and it is still capped by the piggy
	    bank, so it can cost an afternoon's idle income and never a house, a
	    skin or an upgrade.

	AND ONE OF ITS OWN: IT COMMITS TO A SINGLE PURSUIT. Once the officer is out
	of the car they chase that thief and nobody else, and the patrol ends when
	the chase does. Otherwise forty-five seconds of car would be a curfew rather
	than a hazard -- and this way a second thief robbing during a chase gets a
	completely free run, which is a decoy worth discovering.

	Nothing here is a weapon and the catch is a tag. See PoliceModel for why
	that is a shipping requirement rather than a stylistic one.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PoliceModel = require(ReplicatedStorage.Shared.PoliceModel)
-- The officer's two walks go through this and never straight at the goal.
-- It knows nothing about officers: `Config.POLICE.path` is the spec it is
-- handed, and the officer's Y, pose and catch test all stay in this file.
local PathFollower = require(ReplicatedStorage.Shared.PathFollower)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local HeistService = require(script.Parent.HeistService)
local SocialService = require(script.Parent.SocialService)
local EventService = require(script.Parent.EventService)
local CosmeticsService = require(script.Parent.CosmeticsService)

local PoliceService = {}

-- The road surface, which is where the car's wheels belong.
--
-- MOVED INTO CONFIG WHEN A SECOND VEHICLE ARRIVED. It was derived here,
-- which was right while exactly one thing drove on this road; the delivery
-- van would have been a second copy of the same arithmetic, and the two
-- agreeing today is not the same as their staying in step the next time
-- somebody re-lays the tarmac. See `Config.ROAD_SURFACE_Y`.
local ROAD_Y = Config.ROAD_SURFACE_Y

-- ============================================================
-- STATE
-- ============================================================
--
-- Every one of these is read by a function declared below it. In Luau a
-- `local` declared AFTER its reader silently becomes a nil global instead of
-- erroring, and this project has lost three bugs to that -- so all shared
-- state lives at the top, without exception.

local phase = "quiet"
local phaseEnds = 0

local car: PoliceModel.Car? = nil
local officer: PoliceModel.Officer? = nil

-- Set by the steal hook, read by the patrol drive loop on its next frame.
--
-- A queue of one, deliberately: the patrol commits to a single pursuit, so a
-- second robbery during a chase must not be remembered and served afterwards.
-- `amount` is captured at the steal because bail is charged on what was TAKEN,
-- and by the time anybody is caught the loot may already be banked or may
-- already have been nabbed out of their hands.
-- `wanted` marks a pursuit raised by the board rather than by a steal. It
-- changes two things and nothing else: what bail is charged against, and
-- whether the rap sheet is cleared afterwards.
-- `victim` may be a RESIDENT rather than a Player since unclaimed plots
-- became robbable, so it is only ever named and notified through
-- HeistService's own accessors. Never index it as a Player here.
-- `inSight` marks a pursuit the CAR raised by spotting somebody on its own
-- cruise, which is the one case that must not pull level afterwards: it has
-- already stopped exactly where it saw them.
type Alarm = { thief: Player, victim: any, amount: number, wanted: boolean?, inSight: boolean? }
local pending: Alarm? = nil
local engaged = false

-- SENT HOME EARLY, for the dev console only. Nothing in the game sets this:
-- the patrol commits to one pursuit and leaves on its own clock, and a way to
-- call it off would be a way to protect somebody from it.
--
-- A flag rather than destroying the car, because the patrol has to LEAVE
-- rather than blink out -- it drives away into the far tunnel like any other
-- ending, which is the one part of this that reads as traffic.
local aborting = false

-- THE SCHEDULE'S OWN CLOCK, kept apart from `phaseEnds` on purpose.
--
-- `phaseEnds` is how long the thing currently happening has left, and a radio
-- call has to be able to cut a quiet stretch short without touching when the
-- next SCHEDULED patrol is due. Folding the two together is what the admin
-- trigger used to do -- it set `phaseEnds = 0`, the loop ran a patrol, and
-- then started a fresh eight minutes, so every dev command silently pushed
-- the next real patrol back by however long the fake one took.
--
-- A CALL BORROWS THE STREET, NEVER THE CLOCK. `dueAt` moves only when the
-- patrol about to run is the scheduled one.
local dueAt = 0

-- A patrol somebody has called in and the earliest another call may be taken.
-- No player on either: a call carries a target nowhere in this file, and the
-- broadcast that announces one deliberately does not name who paid for it.
local callPending = false
local callReadyAt = 0

local function notify(player: Player, message: string, kind: string)
	Remotes.get("Notify"):FireClient(player, message, kind)
end

local function format(value: number): string
	local text = tostring(math.floor(value))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- ============================================================
-- BROADCAST
-- ============================================================

-- Seconds left rather than a deadline, because os.clock() is not the same
-- number on the server and on any client -- the same reason the dodge cooldown
-- is pushed as a duration.
local function pushPhase(to: Player?)
	local payload = { phase = phase, secondsLeft = math.max(0, phaseEnds - os.clock()) }
	local remote = Remotes.get("PoliceState")
	if to then
		remote:FireClient(to, payload)
	else
		remote:FireAllClients(payload)
	end
end

local function setPhase(name: string, seconds: number)
	phase = name
	phaseEnds = os.clock() + seconds
	pushPhase()
end

-- ============================================================
-- MOVEMENT
-- ============================================================

-- A CFrame at `pos` whose LOCAL +Z points along `heading`.
--
-- Not CFrame.lookAt on its own: lookAt aims the LookVector, which is NEGATIVE
-- Z, and everything in PoliceModel is authored facing +Z. Without the half
-- turn the car reverses down the street at 34 studs a second, which is exactly
-- how the guard dog spent its first weeks running tail-first.
local function facing(pos: Vector3, heading: Vector3): CFrame
	return CFrame.lookAt(pos, pos + heading) * CFrame.Angles(0, math.pi, 0)
end

-- Where a character's feet actually are.
--
-- Measured rather than raycast, and measured rather than assumed: the world is
-- three different floor heights (lawn +0.5, driveway -0.28, verge -0.5) and an
-- officer pinned to any one of them is either shin-deep in a lawn or hovering
-- over the verge. Following the thief's own feet is correct on all three and
-- costs nothing, where a downward raycast every frame would cost a raycast
-- every frame to learn something the character already knows.
local function feetOf(root: BasePart, humanoid: Humanoid): number
	return root.Position.Y - (humanoid.HipHeight + root.Size.Y / 2)
end

-- WHAT THE OFFICER IS STANDING ON, which is not the same question as where
-- the thief's feet are -- and confusing the two is what made an officer fly.
--
-- The chase used to ease the officer's own Y toward `feetOf(thief)`. On the
-- same ground those agree to a stud; with the thief upstairs in a house they
-- differ by a storey, so the officer rose through the air and made the arrest
-- through the floor. It walks on the ground beneath ITSELF now and waits at
-- the bottom, and `Config.POLICE.catchRise` is what refuses the catch while
-- the thief is above it.
--
-- Raycast rather than a constant, because the ground under a patrol is the
-- road, a kerb, a driveway or a plot slab and those are four heights. The
-- characters are excluded -- an officer must not stand on the thief it is
-- chasing -- and anything non-collidable is invisible to a raycast anyway,
-- which is most of this game's scenery by design.
local function groundUnder(at: Vector3, fallback: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { workspace:FindFirstChild("Characters") or workspace }
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(params.FilterDescendantsInstances, player.Character)
		end
	end
	local hit = workspace:Raycast(at + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), params)
	return if hit then hit.Position.Y else fallback
end

local function rootOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	return root, humanoid
end

-- Drives the car along the road to `targetX`, in its lane. Polled every frame
-- rather than waited out in one lump, so an alarm raised halfway down the
-- street is noticed on the next frame instead of when the drive finishes --
-- the guard dog's patrol pause was a single long task.wait for exactly this
-- reason and it made the dog late for everything.
local function driveTo(targetX: number, lane: number, abort: (() -> boolean)?): boolean
	local vehicle = car
	if not vehicle then
		return false
	end
	local speed = Config.POLICE.carSpeed

	while true do
		local dt = RunService.Heartbeat:Wait()
		if not vehicle.model.Parent then
			return false
		end
		if abort and abort() then
			return false
		end

		local from = vehicle.body.Position
		local dx = targetX - from.X
		-- The BODY's height, not the road's. PivotTo aims the primary part.
		local pivotY = ROAD_Y + PoliceModel.CAR_PIVOT_Y
		if math.abs(dx) < 1.0 then
			return true
		end

		-- Travel is along X only. The lane change is eased separately and
		-- converges in about a second, so the U-turn at the end of the street
		-- crosses to the other side promptly.
		--
		-- Folding the lane into the travel vector instead looks correct and is
		-- not: the road is over four hundred studs long and the lanes are 8.4
		-- apart, so a single heading built from both is 99.8% X, and the car
		-- creeps across the centre line over the entire length of the street.
		-- Measured at z=0.14 -- straddling the white line -- halfway back.
		local step = math.min(speed * dt, math.abs(dx))
		local moved = Vector3.new(
			from.X + (if dx > 0 then step else -step),
			pivotY,
			from.Z + (lane - from.Z) * math.min(1, dt * 3))

		-- Faced along what it ACTUALLY moved rather than down the road, so the
		-- car visibly angles into its lane during the change.
		local travelled = moved - Vector3.new(from.X, pivotY, from.Z)
		if travelled.Magnitude > 1e-4 then
			vehicle.model:PivotTo(facing(moved, travelled.Unit))
		end
	end
end

-- ============================================================
-- THE CHASE
-- ============================================================

-- Charges bail and says so.
--
-- A SHARE OF THE THIEF'S OWN TILL rather than a multiple of the haul -- see
-- `Config.POLICE.bailFraction` for why the haul stopped being a number when
-- the core moved to stealing piggies.
--
-- STILL CHARGED WHEN THE LOOT IS ALREADY GONE, which is the half that does
-- not change: bail answers for the ROBBERY, and getting home before they
-- caught you is the good outcome rather than an acquittal. It no longer
-- needs to know what was taken in order to say so.
--
-- IT TAKES NO AMOUNT AT ALL NOW, deliberately. Leaving a `stolen` argument
-- in place and ignoring it is how a function comes to be called with a
-- figure somebody believes is doing something.
local function chargeBail(thief: Player): number
	local data = DataService.get(thief)
	if not data then
		return 0
	end

	local bail = math.floor(data.coins * Config.POLICE.bailFraction)
	if bail <= 0 then
		return 0
	end

	data.coins -= bail
	local plot = PlotService.getPlot(thief)
	if plot then
		PlotService.updatePile(plot, data.coins, Config.pigFullAt(data.rebirths))
	end
	return bail
end

-- Let out at your own gate when the detention ends.
--
-- A TELEPORT, AND NEVER `LoadCharacter`. A respawn looks like the obvious way
-- to do this and is free -- `Main.onCharacterAdded` already seats every new
-- character on its owner's plot, so the placement would need no code at all.
-- It is wrong twice. The stun is a WalkSpeed written on the humanoid the
-- player currently has, so a respawn hands them a brand new one and ENDS THE
-- DETENTION the instant it begins, four seconds early, with the arrest card
-- still on screen saying otherwise. And it reads as a death, in a game where
-- nothing kills anybody and where the bail cap exists precisely so that being
-- caught is survivable.
--
-- Timed off the end of the detention rather than off the catch, so the
-- officer's GOT YOU still lands on somebody: the scene plays out where the
-- arrest happened, and the release is what comes after it. That is also what
-- hides the move -- the card is opaque for the whole detention and only starts
-- fading at this moment, so the reveal is the player's own lawn. The 0.3 puts
-- the teleport just INSIDE the stun rather than racing it, or a player holding
-- W gets a step in first and is yanked back mid-stride.
local function releaseHome(thief: Player)
	task.delay(math.max(0, Config.STUN_SECONDS - 0.3), function()
		-- Everything re-fetched, nothing captured. Four seconds is long enough
		-- for the player to have left or died, and a captured plot could by
		-- then belong to somebody else entirely.
		if thief.Parent == nil then
			return
		end
		local plot = PlotService.getPlot(thief)
		local character = thief.Character
		if not plot or not character then
			return
		end
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.CFrame = PlotService.getSpawnCFrame(plot)
		end

		-- Said out loud, because a player who is simply moved has been moved
		-- BY something they cannot see -- which is the same problem a silent
		-- rejection has. `warn` is the one loud-looking kind with no sound on
		-- it, so this arrives after the bail toasts have gone without adding a
		-- fourth chime to an event that already has two.
		notify(thief, "Released at your own gate.", "warn")
	end)
end

local function arrest(alarm: Alarm)
	local recovered, victim = HeistService.confiscate(alarm.thief)
	local currency = "coins"
	-- THE CHARGE NO LONGER ASKS WHAT THIS ARREST WAS FOR. It used to: an
	-- ordinary bust charged three times the loot in their hands and a
	-- most-wanted one three times the whole rap sheet, and `alarm.amount`
	-- carried whichever it was so this needed no branch. It still needs no
	-- branch, for a better reason -- the fraction is of the THIEF'S till, so
	-- both kinds of arrest cost the same share and there is nothing to pass.
	local bail = chargeBail(alarm.thief)
	if alarm.wanted then
		-- Answered for. This is the ONLY thing that clears a record, and it is
		-- what stops the patrol hunting the same player every eight minutes
		-- for the rest of the session.
		SocialService.clearHeat(alarm.thief)
	end
	-- BUT ANY ARREST ENDS THE RUN, wanted or not, and that is a different
	-- question from the record above. A rap sheet is what you have done and an
	-- ordinary bust does not undo it; STARS are momentum, and being put in a
	-- car plainly ends momentum. It is also the whole reason the run's risk
	-- half points at the patrol: what the stars buy is worth losing.
	SocialService.clearStars(alarm.thief)
	HeistService.detain(alarm.thief, Config.STUN_SECONDS)
	releaseHome(alarm.thief)

	if officer then
		officer.plate.Text = "GOT YOU!"
	end

	-- The mugshot. Sent before the toasts so the scene is what lands first;
	-- the toasts below stay anyway, because a rejection or a charge the
	-- player cannot see is indistinguishable from a broken feature and the
	-- scene is the one part of this that could fail to build.
	Remotes.get("PoliceBust"):FireClient(alarm.thief, {
		bail = bail,
		recovered = recovered,
		currency = currency,
		-- A victim may be a RESIDENT now rather than a player, so the name
		-- comes from HeistService's own accessor. Re-deriving it here would
		-- be a second copy of that branch in a file that has no business
		-- knowing there are two kinds.
		victim = if victim and (victim :: any) ~= alarm.thief
			then HeistService.targetDisplayName(victim)
			else nil,
	})

	-- Both halves named, because a punishment the player cannot account for
	-- reads as the game taking coins at random. They should be able to check
	-- the arithmetic: `Config.bailPercent()` of what was in their bank, the
	-- same share the poster prints.
	if bail > 0 then
		notify(alarm.thief, ("BUSTED! Bail: %s coins out of your piggy bank."):format(format(bail)), "bad")
	else
		notify(alarm.thief, "BUSTED! Your piggy bank was empty, lucky you.", "bad")
	end

	if recovered > 0 and victim then
		notify(alarm.thief, ("The police took back %s %s."):format(format(recovered), currency), "bad")
		-- Silent when the victim is a resident: nothing is reading it.
		HeistService.notifyTarget(victim, ("The patrol caught %s. Your %s %s are back!"):format(
			alarm.thief.DisplayName, format(recovered), currency), "money")
	-- Never sent for a self-bust from the admin console, where victim and
	-- thief are the same player: being told you robbed yourself is noise.
	-- `alarm.victim` may be a RESIDENT, which has no `.Parent` -- that read
	-- happens to return nil rather than throwing, so this branch was already
	-- safe by accident. Asking HeistService whether it is a player says so on
	-- purpose, and `notifyTarget` is silent for anything that is not one.
	elseif victim == nil and (alarm.victim :: any) ~= alarm.thief
		and HeistService.isPlayerTarget(alarm.victim) then
		HeistService.notifyTarget(alarm.victim,
			("The patrol caught %s, but your coins were already gone."):format(
				alarm.thief.DisplayName), "warn")
	end
end

-- Runs one pursuit to its end. Returns when the officer has finished, caught
-- or not.
local function pursue(alarm: Alarm)
	local vehicle = car
	if not vehicle then
		return
	end

	local root = rootOf(alarm.thief)
	if not root then
		return
	end

	-- Pull in level with the thief, clamped to the road. The car parks; it is
	-- the officer who leaves the tarmac.
	--
	-- SKIPPED WHEN THE CAR STOPPED BECAUSE IT SAW THEM. A sight-raised pursuit
	-- has already braked at the spot it spotted them from, and driving on to
	-- draw level would be up to a sight radius of extra travel AFTER the moment
	-- the thief watched the car stop -- which reads as the patrol noticing and
	-- then thinking about it. An alarm-raised pursuit still pulls in, because
	-- there the car has no idea where the robbery was until the alarm went.
	local m = Config.streetMetrics()
	if not alarm.inSight then
		local parkX = math.clamp(root.Position.X, m.roadStartX + 12, m.roadEndX - 12)
		local lane = if root.Position.Z >= 0 then Config.POLICE.lane else -Config.POLICE.lane
		driveTo(parkX, lane)
	end

	-- Published, like the rest of the patrol. Thirty seconds is the whole
	-- escape, and an escape whose clock nobody can see is indistinguishable
	-- from no escape -- the thief would have no way to know whether to keep
	-- running or give up.
	setPhase("pursuit", Config.POLICE.chase + Config.POLICE.startDelay)

	notify(alarm.thief, if alarm.wanted
		then ("MOST WANTED! Lose them for %ds or pay the bounty."):format(Config.POLICE.chase)
		else ("PULL OVER! Lose them for %ds or pay %d%% of your piggy bank."):format(Config.POLICE.chase, Config.bailPercent()),
		"police")
	-- THIS ONE WAS A REAL BUG WAITING, not a harmless one: `notify` calls
	-- FireClient, and a resident is a plain table rather than a Player, so
	-- the first robbery of an empty house during a patrol would have thrown
	-- here. `notifyTarget` is the accessor that knows the difference.
	if (alarm.victim :: any) ~= alarm.thief then
		HeistService.notifyTarget(alarm.victim,
			("The patrol spotted %s robbing you!"):format(alarm.thief.DisplayName), "good")
	end

	local doorCF = vehicle.body.CFrame * CFrame.new(0, 0, -8)
	local doorAt = Vector3.new(doorCF.Position.X, ROAD_Y, doorCF.Position.Z)
	local hand = PoliceModel.buildOfficer(CFrame.new(doorAt), Workspace)
	officer = hand
	hand.plate.Text = "PURSUING"

	-- The officer's own GROUND position, its heading, and how far it has run.
	-- Tracked here rather than read back off the model, because the model no
	-- longer holds a single readable position: its parts are posed
	-- individually so the limbs can swing, and the torso is bobbing.
	local at = doorAt
	local look = vehicle.body.CFrame.RightVector
	local stride = 0

	-- WHERE THE NEXT STEP GOES. The officer used to step straight at the
	-- thief every frame and walked through every trunk, fence and pond on
	-- the street (designer decision, 2026-09-21: it goes round). The
	-- follower computes a PathfindingService path in a task of its own and
	-- hands back one frame of travel at a time; it never yields, never
	-- touches Y, and falls back to the old straight line -- counted, and
	-- said out loud below -- if the navmesh has no answer. Everything that
	-- was here before is still here: `groundUnder` for the height, the
	-- stride from distance actually walked, `facing` along the travel and
	-- the same-level catch test against the thief's real position.
	local follower = PathFollower.new(Config.POLICE.path)

	-- The head start. Without it the officer is simply standing on the thief
	-- the instant the car stops, and the chase never reads as one.
	task.wait(Config.POLICE.startDelay)

	local deadline = os.clock() + Config.POLICE.chase
	local caught = false
	-- WHERE THE THIEF WAS LAST SEEN, which is what the officer chases. The
	-- same point as the thief's own position for as long as they are visible;
	-- it stops updating while they are hidden, which is what makes a bin work.
	local lastSeen = at
	local seenFeet = at.Y
	local searchUntil: number? = nil

	while os.clock() < deadline and not aborting do
		local dt = RunService.Heartbeat:Wait()

		-- Fetched fresh every frame rather than captured, so a thief who dies
		-- or leaves ends the chase cleanly instead of being followed by an
		-- officer running at a stale position.
		local targetRoot, humanoid = rootOf(alarm.thief)
		if not targetRoot or not humanoid then
			break
		end

		-- OUT OF SIGHT IS OUT OF MIND. A thief inside a wheelie bin is not
		-- somewhere the officer knows about: it keeps the LAST SEEN spot,
		-- heads there, and gives up `searchSeconds` after arriving. Asked
		-- through HeistService, which is where StealthService pushes this
		-- (see its own note) -- so this file needs no new dependency and
		-- cannot disagree with the dog about who is hidden.
		if HeistService.isHidden(alarm.thief) then
			if not searchUntil then
				searchUntil = os.clock() + Config.POLICE.searchSeconds
				hand.plate.Text = "SEARCHING"
			end
			if os.clock() >= searchUntil then
				break
			end
		else
			searchUntil = nil
			lastSeen = targetRoot.Position
			seenFeet = feetOf(targetRoot, humanoid)
			hand.plate.Text = "PURSUING"
		end

		local flatDelta = Vector3.new(lastSeen.X - at.X, 0, lastSeen.Z - at.Z)

		-- ONLY WHAT IS ON ROUGHLY THE SAME LEVEL. `catchRadius` is a FLAT
		-- distance, so without this an officer on the lawn catches a thief
		-- standing directly above it on an upper floor. See
		-- `Config.POLICE.catchRise`.
		local sameLevel = math.abs(seenFeet - at.Y) <= Config.POLICE.catchRise
		if sameLevel and not searchUntil and flatDelta.Magnitude <= Config.POLICE.catchRadius then
			-- A dodge beats the catch. NAB.hold is 0.4s and the immunity is
			-- 0.5s, so a well-timed roll costs the officer their moment and
			-- they have to close again -- exactly what it costs a player who
			-- eats one mid-tag. The chase is not cancelled, only this frame.
			if not HeistService.isDodgeImmune(alarm.thief) then
				caught = true
				break
			end
		end

		-- The goal is the thief's FEET on the flat: the navmesh is the ground,
		-- and a root three studs up is a point the path would have to snap.
		follower:setGoal(Vector3.new(lastSeen.X, seenFeet, lastSeen.Z))
		local moved, direction, walked = follower:step(at, dt, Config.POLICE.officerSpeed)
		if walked > 0.001 then
			look = direction
			-- THE GROUND UNDER THE OFFICER, not the thief's feet -- see
			-- `groundUnder`. Eased rather than snapped, so it steps up onto a
			-- lawn and down onto the verge over a few frames instead of
			-- teleporting a stud each time it crosses a kerb. The follower
			-- hands back X and Z and leaves Y to this line.
			local groundY = groundUnder(at, at.Y)
			local y = at.Y + (groundY - at.Y) * math.min(1, dt * 8)
			at = Vector3.new(moved.X, y, moved.Z)

			-- The stride is fed the distance actually covered, so the legs
			-- cannot run faster than the officer does.
			stride += walked
			PoliceModel.poseOfficer(hand, facing(at, look), stride)
		end
	end

	if caught then
		arrest(alarm)
	else
		hand.plate.Text = "LOST THEM"
		notify(alarm.thief, "You lost the patrol! They're driving off.", "good")
		-- Only a MOST-WANTED escape counts toward the gear. Outrunning an
		-- officer who came for a robbery you just committed is a different
		-- achievement and it already paid: you still have the loot.
		if alarm.wanted then
			CosmeticsService.recordWantedEscape(alarm.thief)
		end
	end

	-- Standing, not frozen mid-stride. `stride = 0` is legs together and arms
	-- down, which is the pose to be caught reading a nameplate in.
	PoliceModel.poseOfficer(hand, facing(at, look), 0)
	task.wait(1.4)

	-- Then jog back to the car, which is the one moment anybody gets to watch
	-- the run from the side rather than from in front of it. The comment here
	-- used to promise this walk while the code simply deleted the officer.
	local backBy = os.clock() + 5
	while os.clock() < backBy do
		local dt = RunService.Heartbeat:Wait()
		if not vehicle.model.Parent then
			break
		end
		local target = (vehicle.body.CFrame * CFrame.new(0, 0, -8)).Position
		local delta = Vector3.new(target.X - at.X, 0, target.Z - at.Z)
		if delta.Magnitude < 1.2 then
			break
		end
		-- The same follower, the same gate: an officer that caught somebody
		-- on a lawn walks back out the way it came in rather than through
		-- the fence beside it.
		follower:setGoal(Vector3.new(target.X, ROAD_Y, target.Z))
		local moved, direction, walked = follower:step(at, dt, Config.POLICE.officerSpeed)
		if walked > 0.001 then
			look = direction
		end
		local y = at.Y + (ROAD_Y - at.Y) * math.min(1, dt * 8)
		at = Vector3.new(moved.X, y, moved.Z)
		stride += walked
		PoliceModel.poseOfficer(hand, facing(at, look), stride)
	end

	-- ONE LINE PER PURSUIT IF THE NAVMESH EVER HAD NO ANSWER. The follower
	-- walks the straight line rather than freezing when a compute fails,
	-- which is right for the chase and wrong to keep quiet about: a chase
	-- that silently ran the old way is the officer walking through a fence
	-- with nothing in any log to say so.
	local fallbacks = follower:fallbacks()
	follower:destroy()
	if fallbacks > 0 then
		warn(("[PoliceService] pathing fell back to the straight line %d time(s) this pursuit; the officer may have walked through something"):format(fallbacks))
	end

	hand.model:Destroy()
	officer = nil
end

-- ============================================================
-- THE PATROL
-- ============================================================

local function endPatrol()
	if officer then
		officer.model:Destroy()
		officer = nil
	end
	if car then
		car.siren:Stop()
		car.model:Destroy()
		car = nil
	end
	pending = nil
	engaged = false
	aborting = false
end

local function runPatrol()
	local m = Config.streetMetrics()

	-- Out of the hillside at the open end, not out of clear air.
	--
	-- Spawned INSIDE the recess, which is 22 studs deep and unlit, so the
	-- car is already moving by the time any of it is visible. That is the
	-- whole point of the tunnel: a patrol that blinks into existence at the
	-- end of the road reads as a spawn, and one that drives out of a hill
	-- reads as traffic.
	car = PoliceModel.buildCar(
		CFrame.new(Vector3.new(m.tunnelEastX + 12, ROAD_Y, Config.POLICE.lane))
			* CFrame.Angles(0, math.pi, 0),
		Workspace)
	-- THE ID IS ASSIGNED HERE RATHER THAN IN `PoliceModel`, and the split is
	-- a dependency one. `PoliceModel` is pure geometry and requires nothing --
	-- not Config, not a service -- which is what lets the shop render a
	-- patrol car and what keeps it buildable from anywhere. Teaching it to
	-- read `Config.SOUNDS` to fill one property would spend that for a
	-- string, so the model builds the Sound and the service decides what
	-- comes out of it.
	--
	-- THE EMPTY-ID GUARD SURVIVES INTACT, WHICH IS THE POINT. `SIREN` was
	-- deliberately "" for the life of the project so the patrol would ship
	-- silent rather than ship a placeholder; it has a real Pro Sound Effects
	-- id now, and blanking that one line still produces exactly the old
	-- behaviour rather than an error.
	car.siren.SoundId = Config.SOUNDS.SIREN
	if car.siren.SoundId ~= "" then
		car.siren:Play()
	end

	-- THE CAR'S OWN CLOCK, NOT A SECOND OPINION ABOUT IT. The window is the
	-- time a whole number of legs actually takes, so the banner's countdown
	-- and the cruise end together -- see `Config.policeCruise`.
	local cruise = Config.policeCruise()
	setPhase("patrol", cruise.seconds)

	-- Anybody already holding loot when the siren arrives gets told, because
	-- the decision this feature is built around -- keep running or deliver --
	-- is only a decision if you know the clock started.
	for _, player in ipairs(Players:GetPlayers()) do
		if HeistService.isCarrying(player) then
			notify(player, "Sirens on the street. Bank that haul!", "police")
		end
	end

	-- And the name on the board hears it too, at the same moment.
	--
	-- Published for the same reason everything else about this patrol is: the
	-- siren runs fifteen seconds ahead of the car so that robbing during one
	-- is a choice rather than bad luck, and an officer who arrives at a player
	-- standing empty-handed on their own lawn with no warning at all would be
	-- the one part of the feature that was pure bad luck. Forty-five seconds
	-- of cruise is the head start.
	-- getPursuitTarget, NOT getMostWanted. The board names whoever has stolen
	-- the most; this line promises a visit, so it has to be asked of the one
	-- that also clears the income floor. Told to the wrong player it is a
	-- threat that never arrives, which is the same fault as a patrol arriving
	-- with no warning, from the other end.
	local suspect = SocialService.getPursuitTarget()
	if suspect and not HeistService.isCarrying(suspect) then
		notify(suspect, "They're out looking for YOU. Stay clear of the street.", "police")
	end

	-- NOBODY IS ROBBING, SO GO STRAIGHT FOR THE NAME ON THE BOARD.
	--
	-- This used to run AFTER the cruise, on the reasoning that a live robbery
	-- should stay in front of a cold case. It does -- but the cost was absurd:
	-- the officer only set off once the forty-five second patrol had expired
	-- and the car was already leaving, so the most wanted watched the police
	-- drive up and down for the whole window and then get out at the last
	-- second. The pursuit read as an afterthought because it literally was one.
	--
	-- Checked at the top instead, where the question is asked at the only
	-- moment it can be answered honestly: nothing is pending at the start of a
	-- patrol, so "is anybody mid-robbery" is exactly "did a steal beat the
	-- siren". A steal DURING the patrol still takes the pursuit whenever there
	-- is no most wanted to go after, which is the common case early on.
	--
	-- `victim` is the suspect themselves. There is no victim of a records
	-- check, and the notify sites downstream already skip every line that would
	-- be sent when the two are the same player -- the admin console's self-bust
	-- has taken that path since the day it was written.
	-- WATCHED FOR, NOT DRIVEN AT. This is the half that was missing.
	--
	-- Setting `pending` here committed the pursuit before the car had moved --
	-- and the cruise loop below opens `if pending or ... then break end`, so a
	-- patrol with a name on the board BROKE ON ITS FIRST ITERATION and never
	-- drove a single leg. The car did not patrol at all: it went straight to
	-- `pursue`, which drove to wherever the suspect happened to be standing and
	-- unloaded an officer at them. Through a back garden, if that is where they
	-- were.
	--
	-- Two things were wrong with that and only one of them was visible. It made
	-- the patrol's own warning a lie -- "Stay clear of the street" was advice
	-- that bought nothing, because the street was not where the danger was. And
	-- it is why a records check so often ended in no arrest: the officer was
	-- deployed from the road at a suspect who could be most of a plot's depth
	-- away, on foot at 14.5 against a thief who runs at 16, so the whole
	-- thirty-second chase went on closing a gap it could never close. The
	-- pursuit was lost before the officer's door opened.
	--
	-- So the suspect is only WATCHED here, and `sighted` below is what commits.
	local watching: Player? = nil
	if not pending and not aborting then
		-- getPursuitTarget rather than getMostWanted: the floor's whole job is
		-- deciding whether this records check is worth making at all, and this
		-- is the line it guards.
		local suspect, record = SocialService.getPursuitTarget()
		if suspect and suspect.Parent and record > 0 then
			watching = suspect
		end
	end

	-- IS THE SUSPECT WITHIN SIGHT OF THE CAR RIGHT NOW? Commits the pursuit and
	-- returns true, which stops the car exactly where it is standing.
	--
	-- A FLAT DISTANCE FROM THE CAR, AND DELIBERATELY NOT A RAYCAST. "Line of
	-- sight" is the right idea and a ray is the wrong instrument for it here:
	-- every fence in this game carries an invisible colliding Barrier, so a ray
	-- from the road to a thief on their own front lawn is stopped by the fence
	-- in front of them and the officer would never get out at anybody standing
	-- on a plot. A distance says what is actually meant -- close enough to the
	-- street to be seen from it -- and `Config.policeSightRadius` carries the
	-- derivation.
	--
	-- HIDING STILL WORKS, through the one accessor that already answers it, so
	-- this cannot disagree with the dog or with the officer's own search about
	-- who is out of sight. A wheelie bin is a way past a records check.
	--
	-- THE BOARD IS RE-ASKED AT THE MOMENT OF SIGHT rather than trusted from the
	-- top of the patrol, for two reasons. The rap sheet drives the BAIL, at
	-- three times the record, so a figure captured a cruise earlier would
	-- charge for a robbery count that has since moved. And a suspect can be
	-- arrested, cleared or overtaken while the car is still driving -- in which
	-- case there is no longer anybody to get out for, and `watching` is dropped
	-- rather than pursued out of date.
	local function sighted(): boolean
		local suspect = watching
		if pending or not suspect then
			return false
		end
		if not suspect.Parent then
			watching = nil
			return false
		end
		if HeistService.isHidden(suspect) then
			return false
		end
		local vehicle, root = car, rootOf(suspect)
		if not vehicle or not root then
			return false
		end
		local from, at = vehicle.body.Position, root.Position
		if Vector3.new(at.X - from.X, 0, at.Z - from.Z).Magnitude > Config.policeSightRadius() then
			return false
		end
		local current, record = SocialService.getPursuitTarget()
		if current ~= suspect or record <= 0 then
			watching = nil
			return false
		end
		pending = { thief = suspect, victim = suspect, amount = record, wanted = true, inSight = true }
		return true
	end

	local lane = Config.POLICE.lane
	local target = m.roadStartX + 16

	-- A WHOLE NUMBER OF LEGS, COUNTED, RATHER THAN WHATEVER FITS THE CLOCK.
	--
	-- This used to run `while os.clock() < phaseEnds`, which stopped the car
	-- wherever the last leg happened to have got to: at 3.24 legs it drove
	-- three, began a fourth and was cut off a quarter of the way along, so the
	-- patrol ended in the middle of the street and drove off from there. The
	-- count is derived and odd, so the cruise always finishes at the end the
	-- car leaves by -- see `Config.policeCruise`.
	--
	-- THE CLOCK IS STILL AN ABORT AND DELIBERATELY NOT THE CONDITION. A leg
	-- can outrun its own estimate if the car is blocked or the server stalls,
	-- and a cruise that ignored the phase would leave the banner counting down
	-- past zero with the car still driving. It is a backstop with slack rather
	-- than the thing that decides, which is why it is `phaseEnds + legSeconds`
	-- rather than `phaseEnds`.
	local deadline = phaseEnds + cruise.legSeconds
	for _ = 1, cruise.legs do
		if pending or os.clock() >= deadline then
			break
		end
		local arrived = driveTo(target, lane, function()
			-- `sighted` first, so the frame the suspect comes into range is the
			-- frame the car stops -- it commits `pending` as a side effect and
			-- the alarm below picks it up. Checked every Heartbeat, which costs
			-- one distance: the expensive question (is this still the name on
			-- the board) is only asked once the cheap one has already passed.
			return sighted() or pending ~= nil or os.clock() >= deadline
		end)
		if not arrived then
			break
		end
		-- Turn round: the far end, and the other lane, so the return leg
		-- passes on the correct side of the road.
		lane = -lane
		target = if target > (m.roadStartX + m.roadEndX) / 2
			then m.roadStartX + 16
			else m.roadEndX - 16
	end

	local alarm = pending
	pending = nil
	if alarm then
		engaged = true
		-- Held for the whole pursuit: the patrol commits to one thief, so a
		-- robbery raised while this runs must be dropped rather than queued.
		local ok, err = pcall(pursue, alarm)
		if not ok then
			warn(("[PoliceService] pursuit failed: %s"):format(tostring(err)))
		end
	end

	-- Back to quiet BEFORE the drive-off, or the banner counts a pursuit that
	-- has already ended down past zero while the car is still leaving.
	setPhase("quiet", 2)

	-- Off the far end and gone.
	if car then
		-- Away into the FAR tunnel rather than reversing back out of the one
		-- it arrived through. The patrol crosses the plaza to get there,
		-- which is paved the whole way and is the last thing anybody sees of
		-- it. Driven a little past the void so it is out of sight before the
		-- model is destroyed.
		driveTo(m.tunnelWestX - 14, -Config.POLICE.lane)
	end
	endPatrol()
end

-- ============================================================
-- WIRING
-- ============================================================

local function waitText(seconds: number): string
	local whole = math.ceil(seconds)
	if whole < 60 then
		return ("%ds"):format(whole)
	end
	return ("%dm %02ds"):format(math.floor(whole / 60), whole % 60)
end

-- Brings a patrol out early. This is what the Patrol Radio buys, and it is
-- the ONLY thing it buys: no argument, no target, no caller.
--
-- Returns whether it took and the line to show the player either way. The
-- message is the value rather than a notify from in here, because HomeService
-- only spends the item on a true and an item consumed for nothing is
-- indistinguishable from an item that is broken -- the same rule the bone and
-- guard-duty refusals follow.
function PoliceService.call(): (boolean, string)
	if phase ~= "quiet" then
		return false, "The patrol is already out. Listen for the sirens."
	end
	if callPending then
		return false, "Somebody has already called them. They're on their way."
	end
	local left = callReadyAt - os.clock()
	if left > 0 then
		-- Named rather than a flat refusal. The lockout is the whole balance
		-- of this item, so a player who cannot use one has to be able to see
		-- that it is a wait and not a broken button.
		return false, ("The patrol is off shift for another %s."):format(waitText(left))
	end
	callPending = true
	return true, "Called it in. Sirens in a moment."
end

-- Starts a patrol early. Used by the admin console: waiting eight minutes to
-- test a thirty-second chase is how a feature ends up shipped unverified.
--
-- Goes through the same path a radio call does, so what the console proves is
-- the code that actually runs -- and it clears the lockout first, because a
-- dev command that answers "try again in two minutes" is a dev command nobody
-- uses. It no longer touches `phaseEnds`, so testing a patrol no longer
-- silently shifts the scheduled one.
function PoliceService.trigger(): string
	callReadyAt = 0
	local _, message = PoliceService.call()
	return message
end

-- Summons an officer onto the caller, as if they had just robbed somebody.
--
-- A pursuit otherwise needs TWO players and a real robbery inside a
-- forty-five second window, which puts the chase, the catch, the bail
-- arithmetic and the cleanup in the same bucket as everything else in this
-- project that shipped unverified. `dognap` exists for the same reason.
--
-- It fakes only the ALARM. Everything downstream -- the park, the officer,
-- the catch radius, the dodge check, the confiscation, the bail -- is the
-- real path, so what this proves is the thing that actually runs.
function PoliceService.bust(player: Player, amount: number): string
	if phase ~= "patrol" then
		return "No patrol out. Run 'police' first and wait for the car."
	end
	if engaged or pending then
		return "Already committed to a pursuit"
	end
	pending = { thief = player, victim = player, amount = amount }
	return ("Officer dispatched. Bail will be %d%% of their piggy bank.")
		:format(Config.bailPercent())
end

-- Is there a patrol on the street right now? Anything but `quiet` counts,
-- including the fifteen seconds of siren before the car is visible.
function PoliceService.isOut(): boolean
	return phase ~= "quiet"
end

-- Send them home. Cuts the phase short and lets every loop that watches
-- `phaseEnds` or `aborting` fall out on its own, so the car still drives off
-- through the tunnel and cleans itself up the ordinary way rather than being
-- deleted out from under a pursuit.
function PoliceService.standDown(): string
	if not PoliceService.isOut() then
		return "No patrol out to send home."
	end
	local was = phase
	aborting = true
	phaseEnds = 0
	return ("Standing down from '%s'. They'll drive off."):format(was)
end

function PoliceService.status(): string
	return ("phase=%s left=%.1fs car=%s officer=%s engaged=%s pending=%s due=%.0fs call=%s lock=%.0fs"):format(
		phase, math.max(0, phaseEnds - os.clock()),
		tostring(car ~= nil), tostring(officer ~= nil),
		tostring(engaged), tostring(pending ~= nil),
		math.max(0, dueAt - os.clock()), tostring(callPending),
		math.max(0, callReadyAt - os.clock()))
end

function PoliceService.start()
	-- The only way an officer is ever summoned.
	HeistService.onSteal(function(thief: Player, victim: any, amount: number)
		if phase ~= "patrol" or engaged or pending then
			return
		end
		pending = { thief = thief, victim = victim, amount = amount }
	end)

	Players.PlayerAdded:Connect(function(player)
		-- A player who joins mid-patrol has to see the same clock as everybody
		-- else, or the street is full of sirens their HUD says nothing about.
		task.defer(pushPhase, player)
	end)

	task.spawn(function()
		local p = Config.POLICE
		dueAt = os.clock() + p.period - p.warning - p.patrol

		while true do
			-- The quiet stretch, polled a few times a second so a radio call
			-- can cut it short. A flat task.wait here would make a 75,000-coin
			-- purchase take up to eight minutes to be noticed, which is the
			-- same bug the guard dog's patrol pause turned out to be.
			setPhase("quiet", math.max(1, dueAt - os.clock()))
			while os.clock() < phaseEnds and not callPending do
				task.wait(0.25)
			end

			-- AN EVENT SUPPRESSES THE PATROL, and that is two rules at once.
			--
			-- It is right on its own terms: both are "the street is busy", and
			-- two sirens over each other is noise rather than drama. But it is
			-- also what makes the two banners MUTUALLY EXCLUSIVE, which is the
			-- only reason they can share a slot -- the top-centre HUD column
			-- is full at coins 16, rebirth 96, carry 140..192, patrol
			-- 200..238, and anything below that is the middle of the screen on
			-- a phone held sideways. Same argument as the dodge and the trick
			-- button sharing a LayoutOrder.
			--
			-- Waited out rather than skipped: the patrol is not cancelled, it
			-- just does not drive into the middle of an invasion.
			while EventService.isEventLive() do
				task.wait(0.5)
			end

			local called = callPending
			callPending = false

			-- THE SCHEDULE IS NOT MOVED BY A CALL. Set at the start of the
			-- warning rather than at the end of the patrol, so the interval
			-- is siren to siren and a long chase cannot make the next one
			-- late -- which the old arithmetic did, quietly, every time.
			if not called then
				dueAt = os.clock() + p.period
			end

			-- The warning. Fifteen seconds of siren before the car appears,
			-- because this patrol is PUBLISHED: robbing during one has to be
			-- a choice somebody made, not a coincidence they walked into. A
			-- called patrol gets exactly the same head start as a scheduled
			-- one -- paying for it buys the timing and never a surprise.
			setPhase("warning", p.warning)

			if called then
				-- Said out loud, and DELIBERATELY ANONYMOUS. That this patrol
				-- was paid for is a fact about the street and everyone should
				-- have it; who paid is an accusation, and naming a child as
				-- the one who called the police on the server is exactly the
				-- shape of thing this feature is built to avoid. The patrol
				-- belongs to nobody, including the person who called it.
				for _, player in ipairs(Players:GetPlayers()) do
					notify(player, "RADIO CALL! Somebody paid to bring the patrol out early.", "police")
				end
			end

			while os.clock() < phaseEnds do
				task.wait(0.25)
			end

			local ok, err = pcall(runPatrol)
			if not ok then
				warn(("[PoliceService] patrol failed: %s"):format(tostring(err)))
				endPatrol()
			end

			-- From the END of the patrol, never from the call. Measured from
			-- the call it would overlap the patrol it started and guarantee
			-- no gap at all -- the same trap `guardLockUntil` had to be moved
			-- out of. This is what stops a rich player chaining calls into a
			-- curfew, and it is the real cap on the item: at 3,000 coins a
			-- second the price is twenty-five seconds of income and gates
			-- nobody who has finished the game.
			callReadyAt = os.clock() + p.callLockout
		end
	end)
end

return PoliceService
