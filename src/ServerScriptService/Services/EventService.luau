--!strict
--[[
	EventService

	The things that happen to the whole street, on a clock nobody owns.

	WHY THIS EXISTS. Both upgrade trees max out at 2h11m, the highest rebirth
	gate in the game is 6, and both sources of randomness are finite lists that
	run dry and never refill. But the fault that actually costs retention is
	none of those: it is that NOTHING DIFFERS between a player's third session
	and their thirtieth except the size of their numbers. An event cannot be
	exhausted, because it is not an item -- it has no pool, no catalogue and no
	completion state, which is precisely the property the two collection rolls
	do not have.

	THE ALIEN RAID IS THE FLAGSHIP BECAUSE THE STREET HAS NEVER BEEN ON THE
	SAME SIDE. Stealing, dogs, fences, locks, gadgets and Most Wanted are all
	adversarial; the patrol is neutral and comes for individuals. The only
	cooperative mechanic in the entire codebase is FRIEND_BONUS, and it is a
	passive income multiplier rather than an action -- you are paid for your
	friends being present, you never do anything together. So a full server
	means MORE THIEVES. For the length of a raid it means more defenders, and
	that is the biggest single change available to this design.

	IT REUSES THE HEIST VERBS AND ADDS NONE. You break a beam by THROWING a
	gadget, exactly as you would at somebody carrying your coins, and you
	recover the loot by HOLDING A PROMPT, exactly as you collect or steal. A
	nine year old already knows how to play this the first time it happens,
	and there is no weapon anywhere in it -- the same shipping requirement that
	gives the officer no baton and makes the catch a tag.

	IT OBEYS EVERY RULE THE PATROL OBEYS, because it is the same kind of thing:

	  * PUBLISHED before it lands, so being beamed is a thing you saw coming.
	  * TRIGGERABLE AND AIMABLE BY NOBODY. There is no remote here a client can
	    fire and no argument anywhere that names a player.
	  * IT TAKES FROM THE PIGGY BANK, the only balance there is since the
	    pivot. The cap below is what keeps it survivable, the same line the
	    police draw with bail: what is spent is out of the pig and safe.
	  * CAPPED AT `STEAL_FRACTION`, so a raid can never cost more than one bad
	    neighbour -- and everyone present is paid a bounty regardless of how it
	    goes, so attending is net positive in expectation even on a total
	    failure. An event that can only take is a reason to log off during it.
	  * NOTHING IN IT EXCEEDS `BASE_WALK_SPEED`, and nothing it grants confers
	    power.

	AND IT ONLY EVER TARGETS PLAYERS WHO ARE PRESENT. A steal can take from
	somebody who is offline because a thief had to walk to their plot and hold
	their lock; an event is weather, and weather that empties the piggy of a
	child who was at school is indistinguishable from the game being broken.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AlienModel = require(ReplicatedStorage.Shared.AlienModel)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local SetService = require(script.Parent.SetService)
local CosmeticsService = require(script.Parent.CosmeticsService)
local WorldService = require(script.Parent.WorldService)

local EventService = {}

-- ============================================================
-- STATE
-- ============================================================
--
-- All of it at the top, without exception. In Luau a `local` declared AFTER a
-- function that reads it silently becomes a nil GLOBAL rather than erroring,
-- and this project has now lost six bugs to that -- the most recent one this
-- week, in House.luau.

local phase = "quiet"
local phaseName = ""
local phaseEnds = 0
-- How long the CURRENT phase was when it started, so the HUD can draw a bar
-- rather than only a number. Sent alongside secondsLeft rather than inferred
-- on the client: a player who joins halfway through a raid would otherwise
-- see the bar start full and drain from the wrong place.
local phaseSpan = 0

-- A queue of one, like the patrol's alarm: an event requested early by the
-- admin console, served on the scheduler's next pass.
local pending: string? = nil
local running: string? = nil

local saucer: AlienModel.Saucer? = nil

type Beam = {
	victim: Player,
	beam: Part,
	drone: AlienModel.Drone,
	prompt: ProximityPrompt?,
	-- Coins already lifted out of the vault and still aboard. They are gone
	-- from the piggy the moment they are taken, so the drain is visible on the
	-- pile rather than settled up at the end -- but they are only LOST if the
	-- drone is still holding them when the saucer leaves.
	held: number,
	-- The most this beam may ever take, fixed when it locks on. Derived from
	-- the vault at that instant so a player who banks mid-raid is not punished
	-- for it and one who fills up is not milked for more.
	cap: number,
	-- os.clock() when it was knocked down, or nil while it is flying.
	grounded: number?,
}

local beams: { Beam } = {}

-- Rush Hour's multiplier on the steal fraction, read by HeistService. 1 when
-- nothing is running, which is what makes it safe to consult unconditionally.
local stealMultiplier = 1

local function notify(player: Player, message: string, kind: string)
	Remotes.get("Notify"):FireClient(player, message, kind)
end

local function announce(message: string, kind: string)
	for _, player in ipairs(Players:GetPlayers()) do
		notify(player, message, kind)
	end
end

local function format(value: number): string
	local text = tostring(math.floor(value))
	local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- ============================================================
-- BROADCAST
-- ============================================================

-- Seconds left rather than a deadline, for the reason PoliceState does the
-- same: os.clock() is not the same number on the server and on any client.
-- The event the scheduler has already rolled for the end of this quiet
-- stretch, or nil once it has started. Declared above `pushPhase` because
-- that reads it -- a local declared below its reader is a nil global, which
-- this project has paid for ten times.
local upcoming: string? = nil

local function pushPhase(to: Player?)
	local payload = {
		phase = phase,
		event = phaseName,
		secondsLeft = math.max(0, phaseEnds - os.clock()),
		secondsTotal = phaseSpan,
		-- Sent so the steal prompt can print what a grab is actually worth.
		-- Rush Hour doubles a take, and a prompt quoting the un-doubled figure
		-- would be showing a number the server does not use -- the same fault
		-- the chest reel avoids by printing ChestService's own live odds
		-- rather than recomputing them from Config.
		stealMultiplier = stealMultiplier,
		-- Whether another player's ripe tree can be shaken right now. The
		-- client hides the shake prompt on anybody else's tree unless this is
		-- true; the server refuses it regardless.
		acornTheft = EventService.isAcornTheftOpen(),
		-- WHICH EVENT IS COMING, published through the quiet stretch.
		--
		-- This reverses a rule CLAUDE.md states outright: the standing
		-- countdown drew an hourglass "because which event is not known yet
		-- -- the roster is rolled when the quiet ends". It is rolled at the
		-- START of the quiet now, on the designer's call, so the countdown
		-- can show the thing it is counting down to. What that spends is the
		-- surprise; what it buys is a chip that says why anybody should
		-- care, which the hourglass never did.
		--
		-- It is nil outside the quiet, because during the warning and the
		-- run `event` above already names what is happening.
		nextEvent = upcoming,
	}
	local remote = Remotes.get("EventState")
	if to then
		remote:FireClient(to, payload)
	else
		remote:FireAllClients(payload)
	end
end

local function setPhase(name: string, event: string, seconds: number)
	phase = name
	phaseName = event
	phaseEnds = os.clock() + seconds
	phaseSpan = seconds
	pushPhase()
end

-- ============================================================
-- SHARED HELPERS
-- ============================================================

local function incomeOf(data: any): number
	return Config.getIncomeRate(data.incomeLevel, data.rebirths)
end

-- SECONDS OF THE PLAYER'S OWN INCOME, never a flat number. The daily ladder
-- already writes this rule down and the reason is the same: forty-five
-- thousand coins is a gift on day one and an insult at three thousand a
-- second, and a reward that stops mattering at exactly the point players have
-- the habit is worse than no reward at all.
local function payIncomeSeconds(player: Player, seconds: number, why: string)
	local data = DataService.get(player)
	if not data then
		return 0
	end
	local amount, spilled = Config.fitInPig(data.coins, Config.getCapacity(data.capacityLevel),
		incomeOf(data) * seconds)
	if amount <= 0 and spilled <= 0 then
		return 0
	end
	-- Capped at the pig like every other mint (Config.fitInPig), and the
	-- spill is named rather than silently dropped.
	data.coins += amount
	notify(player, ("%s +%s coins.%s"):format(why, format(amount),
		if spilled > 0 then (" Your piggy was full: %s spilled."):format(format(spilled)) else ""), "money")
	return amount
end

-- Takes from the piggy bank -- the only balance there is -- and repaints the
-- pile so the drain is visible on the lawn. This is `PoliceService.chargeBail`
-- with a different reason attached; the arithmetic and the rule are identical.
local function takeFromVault(player: Player, amount: number): number
	local data = DataService.get(player)
	if not data or amount <= 0 then
		return 0
	end
	local taken = math.min(math.floor(data.coins), math.floor(amount))
	if taken <= 0 then
		return 0
	end
	data.coins -= taken
	local plot = PlotService.getPlot(player)
	if plot then
		PlotService.updatePile(plot, data.coins, Config.getCapacity(data.capacityLevel))
	end
	return taken
end

-- Recovered coins go back into the pig, capped at the room it has now like
-- every other way coins arrive (MASTER-PLAN 4c.6); the rest spills, and the
-- owner is told. Returns what was banked, which is what the toasts name.
local function giveToVault(player: Player, amount: number): number
	local data = DataService.get(player)
	if not data or amount <= 0 then
		return 0
	end
	local capacity = Config.getCapacity(data.capacityLevel)
	local banked, spilled = Config.fitInPig(data.coins, capacity, amount)
	data.coins += banked
	local plot = PlotService.getPlot(player)
	if plot then
		PlotService.updatePile(plot, data.coins, capacity)
	end
	if spilled > 0 and player.Parent then
		notify(player, ("Your piggy was full: %s of your recovered coins spilled."):format(format(spilled)), "warn")
	end
	return banked
end

-- ============================================================
-- THE RAID
-- ============================================================

local function clearBeam(entry: Beam)
	if entry.prompt then
		entry.prompt:Destroy()
	end
	if entry.beam.Parent then
		entry.beam:Destroy()
	end
	if entry.drone.model.Parent then
		entry.drone.model:Destroy()
	end
end

local function endRaid()
	for _, entry in ipairs(beams) do
		clearBeam(entry)
	end
	table.clear(beams)
	if saucer and saucer.model.Parent then
		saucer.model:Destroy()
	end
	saucer = nil
end

-- Everyone who could be beamed: present, alive, on a plot, with something in
-- the piggy worth taking. Sorted fullest first, which is what stops a raid
-- being a tax on a brand new player standing next to somebody with millions.
local function candidates(): { Player }
	local out: { Player } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local data = DataService.get(player)
		local plot = PlotService.getPlot(player)
		if data and plot and data.coins > 0 then
			table.insert(out, player)
		end
	end
	table.sort(out, function(a, b)
		local da, db = DataService.get(a), DataService.get(b)
		return (da and da.coins or 0) > (db and db.coins or 0)
	end)
	return out
end

-- Recovers what a grounded drone is holding. The coins go back to the player
-- they were taken from; the breaker is paid separately, out of nothing, in
-- seconds of their OWN income.
--
-- That split is the entire co-operative engine in one function: defending a
-- neighbour has to pay the defender without costing the neighbour, or the
-- honest move is to let everybody else get robbed.
local function recover(entry: Beam, breaker: Player)
	local returned = giveToVault(entry.victim, entry.held)
	entry.held = 0

	if entry.victim == breaker then
		notify(breaker, ("You got your own %s coins back!"):format(format(returned)), "money")
	else
		notify(breaker, ("Saved %s's %s coins!"):format(entry.victim.DisplayName, format(returned)), "money")
		if entry.victim.Parent then
			notify(entry.victim, ("%s saved %s of your coins!"):format(
				breaker.DisplayName, format(returned)), "good")
		end
	end
	payIncomeSeconds(breaker, Config.RAID.breakerSeconds, "Drone scrapped.")

	-- Destroyed rather than recalled. A drone that has been caught is out of
	-- the raid for good, which is what makes clearing the street a winnable
	-- goal rather than a treadmill.
	for i, other in ipairs(beams) do
		if other == entry then
			table.remove(beams, i)
			break
		end
	end
	clearBeam(entry)
end

local function groundDrone(entry: Beam, by: Player)
	if entry.grounded then
		return
	end
	entry.grounded = os.clock()

	-- The beam goes out and the drone drops to where somebody can reach it.
	entry.beam.Transparency = 1
	local plot = PlotService.getPlot(entry.victim)
	local landing = if plot
		then plot.cframe * CFrame.new(6, Config.PLOT_SIZE.Y / 2 + AlienModel.DRONE_PIVOT_Y, 14)
		else entry.drone.body.CFrame
	entry.drone.model:PivotTo(landing)

	-- A hold prompt, because that is already this game's universal "do a
	-- thing": it collects, it steals, and it cracks a lock. No new input, no
	-- new button on a phone, and nothing to teach.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RecoverPrompt"
	prompt.ActionText = "Recover"
	Config.setPromptKind(prompt, "recover")
	prompt.ObjectText = ("%s coins"):format(format(entry.held))
	prompt.HoldDuration = Config.RAID.promptHold
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = entry.drone.body
	entry.prompt = prompt

	prompt.Triggered:Connect(function(player)
		-- Re-checked at trigger time rather than captured: the drone may have
		-- been recalled between the hold starting and it completing.
		if entry.grounded and entry.drone.model.Parent then
			recover(entry, player)
		end
	end)

	notify(entry.victim, ("%s knocked a drone off your piggy bank!"):format(by.DisplayName), "good")
end

-- Called by GadgetService when a thrown gadget lands on a drone. Public
-- because the throw belongs to that service; the drone belongs to this one.
function EventService.hitDrone(body: BasePart, thrower: Player): boolean
	for _, entry in ipairs(beams) do
		if entry.drone.body == body and not entry.grounded then
			groundDrone(entry, thrower)
			return true
		end
	end
	return false
end

-- The nearest drone still flying, for GadgetService's target selection. Same
-- shape as `HeistService.nearestCarrier` on purpose -- it returns a reason as
-- well as a target, because everything that can refuse a throw is checked
-- BEFORE the gadget leaves the pocket.
function EventService.nearestDrone(from: Vector3, range: number): (BasePart?, string?)
	local best: BasePart? = nil
	local bestDist = range
	for _, entry in ipairs(beams) do
		if not entry.grounded and entry.drone.body.Parent then
			local d = (entry.drone.body.Position - from).Magnitude
			if d <= bestDist then
				best, bestDist = entry.drone.body, d
			end
		end
	end
	if best then
		return best, nil
	end
	if #beams > 0 then
		return nil, "Too far. Get closer to a drone."
	end
	return nil, nil
end

local function rewardRaid(cleared: boolean)
	local set = Config.EVENTS.roster.raid.set
	for _, player in ipairs(Players:GetPlayers()) do
		payIncomeSeconds(player, Config.RAID.bountySeconds
			* (if cleared then 1.5 else 1), "Invasion survived.")

		-- Attendance pays the coin bounty above and one free set drop.
		-- Events never mint Acorns, including on a completed collection.
		if set then
			SetService.rollDrop(player, set)
		end
	end
end

local function runRaid()
	local m = Config.streetMetrics()
	local raid = Config.RAID

	-- Out of the same hillside bore the patrol uses. A thing that blinks into
	-- existence over the street reads as a spawn; a thing that comes out of
	-- the tunnel reads as having arrived from somewhere.
	-- TARGETS CHOSEN BEFORE THE FLIGHT, so the saucer parks over the plots it
	-- is actually going to beam. Parked at the street's midpoint instead, the
	-- first measured beam was 201 studs long -- a tractor beam is supposed to
	-- be overhead, and one stretching the length of the road reads as a girder
	-- rather than as something holding a piggy bank.

	local targets = candidates()
	local count = math.clamp(#targets, 0, raid.maxDrones)
	if count == 0 then
		announce("The saucer passed over and found nothing worth taking.", "warn")
		return
	end

	local sum = Vector3.zero
	for i = 1, count do
		local plot = PlotService.getPlot(targets[i])
		sum += if plot then plot.piggy.body.Position else Vector3.zero
	end
	local centre = sum / count

	local startAt = Vector3.new(m.tunnelEastX + 10, raid.hoverY, 0)
	-- Held to the road corridor on Z so it hangs over the street rather than
	-- over somebody's back garden, but centred on X over its victims.
	local restAt = Vector3.new(
		math.clamp(centre.X, m.roadStartX + 20, m.roadEndX - 20), raid.hoverY, 0)
	saucer = AlienModel.buildSaucer(CFrame.new(startAt), Workspace)

	setPhase("running", "raid", Config.EVENTS.roster.raid.seconds)
	announce("THE SKY OPENS. Something is coming out of the tunnel.", "police")

	-- The flight in, polled rather than tweened, so the raid can be cut short
	-- at any point without a tween still running against a destroyed model.
	local flewFor = 0
	while flewFor < 3.5 and saucer do
		local dt = RunService.Heartbeat:Wait()
		flewFor += dt
		local ship = saucer
		if not ship or not ship.model.Parent then
			return
		end
		-- The saucer's PrimaryPart is its hull and the hull is centred on the
		-- origin, so PivotTo and this position mean the same thing. That is
		-- the whole reason buildSaucer takes a centre and not a ground point:
		-- driving a model per frame by a ground position sinks it by its own
		-- anchor height, which is how the patrol car spent every patrol 1.6
		-- studs into the tarmac.
		ship.model:PivotTo(CFrame.new(startAt:Lerp(restAt, math.min(1, flewFor / 3.5))))
	end

	-- Lock on. One drone per victim, fullest vaults first, capped by how many
	-- players are actually here -- so twelve is a fight and one is winnable.
	for i = 1, count do
		local victim = targets[i]
		local data = DataService.get(victim)
		local plot = PlotService.getPlot(victim)
		if data and plot then
			local anchor = plot.piggy.body
			if not saucer then
				break
			end
			-- THE BEAM COMES FROM THE DRONE, NOT FROM THE SAUCER.
			--
			-- Run from the hull it was 64 studs long and 6.8 wide, and the
			-- drone -- 3.4 across -- hovered INSIDE it and could not be seen
			-- at all. The one object in this whole feature a player has to
			-- aim at was swallowed by the effect advertising it.
			--
			-- Emitting from the drone fixes three things at once: the drone
			-- sits proud at the top of a short beam where it reads as the
			-- source, the beam is a fixed ~15 studs however far away the
			-- saucer parks, and the saucer goes back to being the scenery it
			-- should always have been.
			local dronePos = anchor.Position + Vector3.new(0, raid.droneY, 0)
			local drone = AlienModel.buildDrone(CFrame.new(dronePos), Workspace, true)
			local beam = AlienModel.buildBeam(
				dronePos - Vector3.new(0, 2.6, 0), anchor.Position, raid.beamRadius, Workspace)
			table.insert(beams, {
				victim = victim,
				beam = beam,
				drone = drone,
				prompt = nil,
				held = 0,
				-- FIXED AT LOCK-ON, at STEAL_FRACTION of what is in there now.
				-- A raid can therefore never cost more than one bad neighbour,
				-- which is the number that makes it survivable rather than a
				-- reason to stop playing.
				cap = math.floor(data.coins * Config.STEAL_FRACTION),
				grounded = nil,
			})
			notify(victim, "A drone locked onto your piggy bank! Knock it down.", "alarm")
		end
	end

	announce(("%d drone%s on the street. Throw a gadget to knock one down!"):format(
		#beams, if #beams == 1 then "" else "s"), "police")

	-- The body of the raid. Polled every frame: a flat task.wait next to
	-- shared state is a state machine that ignores the world, which is what
	-- the guard dog's patrol pause turned out to be.
	local baseRate = 1 / math.max(raid.drainSeconds, 1)
	while os.clock() < phaseEnds do
		local dt = RunService.Heartbeat:Wait()
		local ship = saucer
		if not ship or not ship.model.Parent then
			break
		end

		for i = #beams, 1, -1 do
			local entry = beams[i]
			if not entry.victim.Parent then
				-- Left mid-raid. Their coins are already out of the vault and
				-- there is nobody to give them back to, so the drone simply
				-- goes with them rather than hanging over an empty plot.
				table.remove(beams, i)
				clearBeam(entry)
			elseif entry.grounded then
				if os.clock() - entry.grounded > raid.groundedSeconds then
					-- Recalled. It keeps what it has and goes back to work,
					-- which is what makes the grounded window a real decision
					-- rather than a free reset.
					entry.grounded = nil
					if entry.prompt then
						entry.prompt:Destroy()
						entry.prompt = nil
					end
					entry.beam.Transparency = 0.55
					local plot = PlotService.getPlot(entry.victim)
					if plot then
						entry.drone.model:PivotTo(CFrame.new(
							plot.piggy.body.Position + Vector3.new(0, raid.droneY, 0)))
					end
				end
			else
				-- WHICHEVER IS FASTER: the flat pace, or enough to visibly
				-- out-drain the victim's own income. Without the second term
				-- the pile never moves for a maxed player -- measured, the
				-- vault sat at 2,988,151 for a whole raid while coins were
				-- genuinely being taken. A loss nobody can see is
				-- indistinguishable from a broken feature.
				local data = DataService.get(entry.victim)
				local floorRate = if data then incomeOf(data) * raid.drainIncomeMultiple else 0
				local want = math.max(entry.cap * baseRate, floorRate) * dt
				local room = entry.cap - entry.held
				if room > 0 then
					entry.held += takeFromVault(entry.victim, math.min(want, room))
				end
			end
		end
	end

	-- Settling up. Anything still aboard when the saucer leaves is lost, and
	-- everybody present is paid regardless -- including the people who lost
	-- something, which is what keeps a bad night net positive.
	local lostTotal = 0
	for _, entry in ipairs(beams) do
		if entry.held > 0 and entry.victim.Parent then
			lostTotal += entry.held
			notify(entry.victim, ("The saucer got away with %s of your coins."):format(
				format(entry.held)), "bad")
		end
	end

	local cleared = #beams == 0
	announce(if cleared
		then "THE STREET WON. Every drone knocked out of the sky."
		else ("The saucer left with %s coins."):format(format(lostTotal)), if cleared then "good" else "warn")

	rewardRaid(cleared)

	endRaid()
end

-- ============================================================
-- MIDNIGHT HEIST (designer, September 16; replaces Rush Hour and the
-- Harvest Moon)
-- ============================================================
--
-- The street goes dusk and, for its length, every coin steal pays double
-- (Rush Hour's old job) and a clean pig crack's acorn pays double
-- (`Config.MIDNIGHT`). It opens nobody's tree: acorn theft is disabled.
--
-- THE MULTIPLIERS ARE SET BEFORE THE PUSH. `pushPhase` stamps
-- `stealMultiplier` into the payload so the steal prompt and the badge can
-- quote what a grab is worth, and Rush Hour once set it on the line AFTER the
-- push -- so no push in the whole cycle ever carried a 2, and nothing read it
-- to say so. Anything that changes a number publishes it in the same breath.

local acornMultiplier = 1

local function runMidnight()
	local spec = Config.EVENTS.roster.midnight
	stealMultiplier = Config.MIDNIGHT.stealMultiplier
	acornMultiplier = Config.MIDNIGHT.acornMultiplier
	WorldService.setNight(true)
	setPhase("running", "midnight", spec.seconds)
	announce(("MIDNIGHT HEIST! For %d seconds every steal pays %dx, and a clean crack on a player's pig pays %dx acorns.")
		:format(spec.seconds, Config.MIDNIGHT.stealMultiplier, Config.MIDNIGHT.acornMultiplier), "police")

	while os.clock() < phaseEnds do
		task.wait(0.25)
	end

	stealMultiplier = 1
	acornMultiplier = 1
	WorldService.setNight(false)
	announce("Dawn. The Midnight Heist is over.", "warn")
end

-- Read by HeistService when a clean crack ends. 1 whenever nothing is running.
function EventService.getAcornMultiplier(): number
	return acornMultiplier
end

-- Read by HeistService. Safe to consult unconditionally because it is 1
-- whenever nothing is running.
function EventService.getStealMultiplier(): number
	return stealMultiplier
end

-- ANY event suppresses the patrol, not just the raid.
--
-- Right on its own terms -- an event is the street's headline for its
-- duration and two sirens over each other is noise -- but it is also what
-- makes the event banner and the patrol banner MUTUALLY EXCLUSIVE, which is
-- the only reason they can share one frame. The top-centre HUD column is full
-- at coins 16, rebirth 96, carry 140..192, patrol 200..238, and a fourth row
-- below that is 35% of the way down a phone held sideways.
--
-- The patrol is deferred, never cancelled: `dueAt` is its own clock and this
-- does not touch it.
function EventService.isEventLive(): boolean
	return running ~= nil
end

-- THE ONLY WINDOW IN WHICH ANOTHER PLAYER'S ACORNS COULD BE TAKEN (MASTER-PLAN
-- 19.3). True while a roster row carrying `acornTheft = true` is running.
-- ACORN THEFT IS DISABLED (September 16): no row carries the flag and
-- `auditAcorns` refuses one that does, so this is always false.
function EventService.isAcornTheftOpen(): boolean
	local spec = running and Config.EVENTS.roster[running]
	return spec ~= nil and spec.acornTheft == true
end

-- ============================================================
-- WIRING
-- ============================================================

-- Weighted, and never the same one twice running. Not a shuffled bag like the
-- music: with two entries a bag is strict alternation, which is more
-- predictable than random rather than less.
local lastPicked: string? = nil

-- THE LAST EVENT IS WEIGHTED DOWN, NEVER EXCLUDED.
--
-- Excluding it is the obvious version and it degenerates completely at the
-- roster size this actually has: with TWO events, removing the last one
-- leaves exactly one candidate, so the picker strictly ALTERNATES and the
-- weights do nothing whatever. Raid, rush, raid, rush -- an invasion every
-- second slot instead of the intended one in three, and a player who has seen
-- one Rush Hour knows exactly what is coming next.
--
-- That is the same failure this project already wrote down about shuffled
-- bags ("with two entries a bag is strict alternation, which is more
-- predictable than random rather than less"), reimplemented in a different
-- shape. Damping the repeat keeps the weights meaningful at every roster
-- size, and keeps the schedule genuinely unpredictable rather than merely
-- nominally random.
local REPEAT_WEIGHT = 0.35

local function pick(): string
	-- Sorted, so the same random number picks the same event on every server.
	-- `pairs` order is undefined and an unreproducible schedule is one nobody
	-- can investigate when a player reports a strange run of them.
	local keys: { string } = {}
	for key in pairs(Config.EVENTS.roster) do
		table.insert(keys, key)
	end
	table.sort(keys)
	if #keys == 0 then
		return ""
	end

	local function weightOf(key: string): number
		local w = Config.EVENTS.roster[key].weight or 1
		return if key == lastPicked then w * REPEAT_WEIGHT else w
	end

	local total = 0
	for _, key in ipairs(keys) do
		total += weightOf(key)
	end
	if total <= 0 then
		return keys[1]
	end

	local ticket = math.random() * total
	for _, key in ipairs(keys) do
		ticket -= weightOf(key)
		if ticket <= 0 then
			return key
		end
	end
	return keys[#keys]
end

-- Starts an event early. Used by the admin console, because waiting fifteen
-- minutes to test a two-minute raid is how a feature ends up shipped
-- unverified -- the same argument `police` and `dognap` already make.
function EventService.trigger(name: string?): string
	if phase ~= "quiet" then
		return ("An event is already running (%s)"):format(phaseName)
	end
	if pending then
		return "One is already queued"
	end
	if name and not Config.EVENTS.roster[name] then
		local names = {}
		for key in pairs(Config.EVENTS.roster) do
			table.insert(names, key)
		end
		table.sort(names)
		return ("Unknown event. Try: %s"):format(table.concat(names, ", "))
	end
	pending = name or pick()
	phaseEnds = 0
	return ("Event called: %s. Warning in a moment."):format(pending)
end

function EventService.status(): string
	return ("phase=%s event=%s left=%.1fs beams=%d saucer=%s steals=x%d acorns=x%d"):format(
		phase, phaseName, math.max(0, phaseEnds - os.clock()),
		#beams, tostring(saucer ~= nil), stealMultiplier, acornMultiplier)
end

function EventService.start()
	Players.PlayerAdded:Connect(function(player)
		-- A player joining mid-event has to see the same clock as everybody
		-- else, or the street is full of drones their HUD says nothing about.
		task.defer(pushPhase, player)
	end)

	task.spawn(function()
		local events = Config.EVENTS
		while true do
			-- The quiet stretch, polled a few times a second so the admin
			-- trigger is noticed within a frame rather than in fifteen
			-- minutes. Same reason the patrol's quiet is polled.
			-- ROLLED BEFORE THE QUIET IS PUBLISHED, not after it runs out, so
			-- the payload that starts the countdown already names its event.
			-- `pick()` damps whatever `lastPicked` holds, which at this point
			-- is still the event that has only just finished -- the same
			-- input the roll used to get one stretch later.
			upcoming = pick()
			setPhase("quiet", "", math.max(1, events.period - events.warning))
			while os.clock() < phaseEnds and not pending do
				task.wait(0.25)
			end

			-- An admin trigger still overrides it, which is the whole point
			-- of `pending`: the dev panel names the event it wants to test.
			local chosen = pending or upcoming or pick()
			pending = nil
			upcoming = nil
			lastPicked = chosen
			local spec = events.roster[chosen]

			-- Published ahead of arriving, exactly like the patrol's fifteen
			-- seconds of siren, and for the same reason: being caught out by
			-- a raid has to be a thing you saw coming and chose to stay for.
			setPhase("warning", chosen, events.warning)
			announce(("%s INCOMING in %d seconds."):format(spec.name, events.warning), "police")
			while os.clock() < phaseEnds do
				task.wait(0.25)
			end

			running = chosen
			local run = if chosen == "raid" then runRaid else runMidnight
			local ok, err = pcall(run)
			if not ok then
				warn(("[EventService] '%s' failed: %s"):format(chosen, tostring(err)))
			end
			-- Torn down whatever happened above. A raid that errored halfway
			-- must not leave a saucer parked over the street forever.
			running = nil
			stealMultiplier = 1
			acornMultiplier = 1
			endRaid()
			-- The day back, whatever the night did or failed to do. A night
			-- that errored halfway must not leave the street at dusk forever.
			if chosen == "midnight" and not ok then
				WorldService.restoreDay()
			end

			setPhase("quiet", "", 2)
		end
	end)
end

return EventService
