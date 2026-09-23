--!strict
--[[
	HerdService -- roaming herds, the PvE supply of piggies (docs/HERDS-PLAN.md).

	A HERD'S LIFE, START TO FINISH:

	  1. The scheduler wakes every half second. If fewer than
	     `Config.HERDS.maxLoose` herds are loose and the spawn timer is due,
	     it picks a KIND from `Config.HERDS.roster` with the damped-repeat
	     picker (`Config.pickWeighted`, the same function EventService uses)
	     and rolls each member's TIER and SKIN through `Config.herdDraw`,
	     under the absolute `tierCap`.
	  2. THE PACK IS RELEASED FROM THE SKY (designer, 2026-09-22). A landing
	     zone is drawn in the grass band on the emptier side; EVERY MEMBER'S
	     OWN LANDING SLOT is tested against the band and the vetoes before
	     one part is built; a BEACON goes up on the spot and every player is
	     told where it is; and the pack descends from `drop.height` over
	     `drop.seconds`, each member on its own slice of `drop.stagger` so
	     ten do not land in lockstep. A member is CATCHABLE AT THE MOMENT IT
	     LANDS and not a frame before -- the prompt is built disabled and
	     enabled on the thump, because a prompt on a pig 120 studs up is an
	     action the player cannot take.
	  3. It ROAMS: the leader picks wander points inside the band, grazes at
	     each, and moves on; followers keep a formation slot behind the
	     leader with a slow drift of their own. Every wander point AND THE
	     STRAIGHT LINE TO IT is vetoed against `Config.isOnStreet` and against
	     whatever ground vetoes Main registered (the yard test, and the
	     decoration lane's ponds), so the pack never walks the carriageway,
	     through a fence, or through a pond on its way to legal ground.
	     While it roams, members stop to DIG (visual only; see DIGGING).
	  4. Any player may hold the prompt on a member. THE FIRST HOLD TO FINISH
	     WINS: `claim` marks the member taken before anything yields, grants
	     the piggy through the Stage 1 placement path (`Config.addPiggy`,
	     front to back -- the same door a crate roll uses), and the member
	     leaves the herd. A full lawn refuses OUT LOUD and the piggy stays.
	  5. When its roam time is up the pack is RECALLED: the same fall run
	     backwards, prompts off, rising out of the enclosure. The
	     replacement is due `replaceDelay` later, so "when one exits a new
	     one enters". A herd whose last member is caught simply ends.

	WHY IT DROPS RATHER THAN WALKING IN, AND WHAT THAT RETIRED. The street
	is a SIMULATION and the players are the subjects being watched; a pack
	is RELEASED into the enclosure from above rather than let in at the gate.
	That is a fiction decision and it paid for itself in code: the whole
	tunnel walk is gone -- `Config.herdRoute`, the route/leg machinery, the
	alternating bores, and the single-file kerb formation that existed only
	because a bore leaves under a stud of standing room beside the leader.
	A pack now has one shape (three abreast) and three states, and the exit
	is the drop with the sign flipped rather than a second route to keep in
	step with the first.

	FIVE PACKS OF TEN (designer, 2026-09-21). `maxLoose` is 5 and `size` is
	pinned at 10. The scheduler needs no boot-stagger constant of its own:
	`spawnEverySeconds` is the MINIMUM GAP between two packs arriving, so at
	boot the cap fills one pack per gap from `firstSpawnDelay`, and in the
	steady state a replacement is due `replaceDelay` after a recall and no
	sooner than the gap after the last drop. The arithmetic is in the
	comment over `Config.HERDS.spawnEverySeconds`.

	WHERE THE FIVE GO. A side is picked as the one with FEWER packs on it
	(random on a tie), so five packs land three-and-two across the two bands
	-- rolled purely at random, one street in sixteen put every pack on one
	side. Which END of a band a pack lands on is free: a drop needs no
	corridor to arrive through, so there is nothing to queue.

	THE FORMATION IS THREE ABREAST, and that is a measurement rather than
	taste. Two abreast makes a pack of ten five rows deep -- a conga that
	cuts every corner through the fence margin; three abreast is three rows,
	which reads as a herd. It is used at the drop as well as on the walk, so
	the landing slots and the walking slots are the SAME function: a pack
	lands in the shape it is about to keep.

	EVERY STUD IN THE FORMATION IS A MULTIPLE OF THE MEMBER'S OWN SIZE. A
	herd piggy stands at exactly the size the same skin stands at on a
	pedestal (`Config.PIGGY_PEDESTAL.display * Config.piggyScale`) -- the
	designer's rule, and it is why `followSpacing` and `jitter` are that
	same multiple of the numbers they were solved at against a 2.2-stud
	mini. Two piggies of one skin at two sizes is the thing this collection
	must never show.

	DIGGING (designer: "while they're wandering around they should be
	digging in the ground to find coins, just for visual"). Each member owns
	a clock drawn from `Config.HERDS.dig.every`; when it fires on a leg the
	pack may dig on, the member stops for `dig.seconds` and the start is
	published on its model as `Config.HERD_DIG_ATTRIBUTE` in
	`workspace:GetServerTimeNow()` seconds -- a client reads it, and
	`os.clock` is a process uptime that means nothing across the wire. A
	digging member does not move and its `Walked` does not advance; when it
	ends the attribute is cleared to nil (nil means not digging) and the
	existing catch-up brings it back to its slot. The leader digs only while
	the pack is grazing with no target, because the leader IS the anchor:
	a leader that dug mid-walk would freeze while `herd.at` walked on and
	never catch up (a leader has no hurry). No coins move anywhere.

	WHY THE MEMBERS ARE `PiggyModel.build` MINIS AND NOTHING ELSE. A herd
	piggy is pet-sized and SKIN-ONLY -- no accessory anchors, no vault hatch,
	no dial. Every scale-dependent measurement this game has shipped was
	solved against one pig radius (HERDS-PLAN section 2), and a second scale
	would reopen all of it. Measured against the catalogue: a mesh mini is
	FOUR BaseParts (body, trim, two eyes -- no herd-eligible skin carries a
	pattern or shape geometry, and the legendaries sit above the cap), so
	fifty piggies are 200 parts; on the primitives fallback it is eleven
	each, 550.

	WHY THIS FILE IS A LEAF. It requires Config, Remotes, PiggyModel,
	DataService and SetService and nothing else. The one question it cannot
	answer from down here -- is this point inside somebody's yard, or in a
	pond -- arrives as a VETO that Main fills in, the same registry shape the
	trampoline's bounce veto and the held-item vetoes use, so the dependency
	list stays short and a cycle is impossible rather than merely absent
	today.

	WHAT IS SERVER-DRIVEN AND WHY. Every member's CFrame is written here on
	Heartbeat, like the officer and the residents: the CATCH depends on where
	a member is, so the server has to own that position, and a `PivotTo` on
	an anchored mini is a handful of property replications per frame across
	at most fifty animals.

	NOT TUNED. Every number this reads from `Config.HERDS` is a placeholder
	-- see the loud comment over that table.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PiggyModel = require(ReplicatedStorage.Shared.PiggyModel)
-- THE BEACON IS A GuiObject, AND A SERVER FILE THAT BUILDS ONE TAKES `Theme`.
-- That is the scope rule the verge boards got wrong -- "the UI files" is not
-- the same set as "the files that build UI" -- and `Theme` requires nothing,
-- so it costs this leaf nothing to keep one vocabulary on the street.
local Theme = require(ReplicatedStorage.Shared.Theme)
local DataService = require(script.Parent.DataService)
local SetService = require(script.Parent.SetService)

local HerdService = {}

-- WHAT A DROP IS, HELD LOCALLY UNTIL `Config.HERDS.drop` LANDS. Read through
-- `dropSpec` and never off the table directly, so this service boots either
-- side of that Config edit and there is exactly one place the default lives.
-- Every number here is reasoned in the Config block that replaces it.
local DROP_DEFAULT = {
	height = 120,
	seconds = 2.4,
	stagger = 0.6,
	bounce = 0.35,
	bounceSeconds = 0.34,
	beaconSeconds = 40,
	beaconFade = 1.5,
	beaconWidth = 5,
	puffSeconds = 0.5,
	puffRadius = 1.6,
	tries = 24,
}

local function dropSpec()
	local d = (Config.HERDS :: any).drop
	return if type(d) == "table" then d else DROP_DEFAULT
end

-- NOBODY DIGS IN MID-AIR, AND THAT IS HELD HERE AS WELL AS IN `dig.never`.
-- The Config list still names the retired tunnel legs until its own block
-- lands, and a member scratching at the ground on the way down is the one
-- failure a stale list would actually produce.
local NEVER_DIG = { drop = true, recall = true }

-- HOW BIG A HERD MEMBER IS: EXACTLY THE PEDESTAL'S OWN FACTOR (designer,
-- 2026-09-22, "the minis have to look like they were built"). It used to be
-- `Config.piggyScale` alone, which is the SKIN'S share of the size and not
-- the size -- so the same Bengal Tiger stood 7.2 studs across on a plinth
-- and 2.2 in the grass, a third of it, and the collection showed two animals
-- for one skin. One expression, read by the scale, the lift and the
-- formation, so they cannot disagree.
local function memberFactor(key: string): number
	return Config.PIGGY_PEDESTAL.display * Config.piggyScale(key)
end
HerdService.memberFactor = memberFactor

export type Member = {
	key: string,
	tier: string,
	at: Vector3,
	facing: Vector3,
	-- A phase for the drift, so no two members wobble in step.
	phase: number,
	-- Studs walked since the member was built, published on the model as
	-- `Config.HERD_WALK_ATTRIBUTE` so every client can pose the waddle from
	-- DISTANCE rather than from a clock (`Shared/PiggyWalk`). It only ever
	-- grows, and it is the one thing this service publishes for the walk.
	walked: number,
	-- HOW MUCH HIGHER THIS MEMBER'S BODY CENTRE SITS THAN A SCALE-1 MINI'S,
	-- in studs: `PiggyModel.MINI_CENTRE_Y * (memberFactor(key) - 1)`. `at` is
	-- always the scale-1 centre over the ground (`groundPoint`), so a bee at
	-- 0.75 and a tiger at 1.2 both keep their feet on the grass by adding
	-- this at the one place the model is seated.
	lift: number,
	-- HOW FAR ABOVE ITS OWN LANDING SPOT THIS MEMBER IS RIGHT NOW, in studs
	-- and never negative: `drop.height` the frame it is released, 0 once it
	-- is standing, a small hop through the settle, and `drop.height` again at
	-- the top of a recall. `at` stays the GROUND point the whole time -- it
	-- is what the catch is measured against and what the formation is solved
	-- in -- so the air is one number added at the one place the model is
	-- seated, beside `lift`.
	fall: number,
	-- HAS THIS MEMBER TOUCHED DOWN? The dust and the prompt fire ONCE, on the
	-- frame it does, and `fall` cannot be the test for that: the settle hop
	-- takes it back off zero and down again, so a crossing test lands the
	-- pack twice. It is also what lets the LAST member of a pack land on the
	-- same frame the herd starts roaming.
	landed: boolean,
	-- This member's own slice of `drop.stagger`, drawn once and used at both
	-- ends: it lands this many seconds after the pack's first, and it starts
	-- rising this many seconds after the recall begins. Ten members landing
	-- on one frame reads as a machine rather than as animals.
	stagger: number,
	-- THE LANDING PUFF: the dust ring under the member, and when it is due to
	-- be destroyed. Parts rather than a ParticleEmitter, because an emitter
	-- needs a texture and a texture is a third-party asset that can be
	-- moderated away -- the same call every other effect in this repo makes.
	puff: BasePart?,
	puffUntil: number,
	-- DIGGING. `nextDigAt` is this member's own clock for its next dig,
	-- drawn from `Config.HERDS.dig.every` so no two members dig in step;
	-- `digUntil` is when the dig in progress ends, and 0 when it is not
	-- digging. Both are `os.clock` seconds; only the PUBLISHED stamp is
	-- server time.
	nextDigAt: number,
	digUntil: number,
	taken: boolean,
	model: Model?,
	body: BasePart?,
	prompt: ProximityPrompt?,
}

export type Herd = {
	id: number,
	kind: string,
	side: number,
	state: string, -- "drop" | "roam" | "recall"
	members: { Member },
	-- The pack anchor: where the LEADER is and which way the pack points.
	at: Vector3,
	facing: Vector3,
	-- THE AIRBORNE STATES' CLOCK. `phaseStart` is when the drop or the recall
	-- began and `phaseUntil` is when the LAST member finishes it -- the pack
	-- is in the air until then, so one straggler cannot leave the herd half
	-- roaming and half falling.
	phaseStart: number,
	phaseUntil: number,
	-- Roaming: when the pack is recalled, and when the leader may leave its
	-- current graze.
	roamUntil: number,
	grazeUntil: number,
	target: Vector3?,
	-- THE DROP-ZONE MARKER and when it starts fading. Built at the drop, so
	-- it is standing on the spot while the pack is still in the air; gone
	-- with the herd whatever ends it.
	beacon: Instance?,
	beaconUntil: number,
}

local herds: { Herd } = {}
local lastKind: string? = nil
local nextSpawnAt = 0
local serial = 0
local folder: Folder? = nil
local groundVetoes: { (Vector3) -> boolean } = {}
local warnedStep = false

local function notify(player: Player, message: string, kind: string)
	Remotes.get("Notify"):FireClient(player, message, kind)
end

local function nameOf(key: string): string
	local spec = Config.SKINS[key]
	return if spec and spec.name then spec.name else key
end

-- EVERY DROP IS ANNOUNCED TO EVERYBODY, AND IT NAMES THE PLACE (designer,
-- 2026-09-22). A pack that appears in a field nobody was looking at is a
-- supply route only the player who happened to be facing it can use, and on
-- a 443-stud street that is most of the server most of the time. The beacon
-- says where by standing there; this says where in words, to the people who
-- are indoors, in the shop, or looking the other way.
--
-- THE VOICE IS THE OBSERVER'S, which is the fiction the drop is for: the
-- street is an enclosure and the piggies are released into it. It has to
-- read clearly to a nine-year-old all the same, so the only jargon in it is
-- the batch number, and the sentence after it is a plain instruction about
-- where to go.
--
-- ITS OWN NOTIFY KIND, FALLING BACK TO `good`. `Config.NOTIFY.herd` is the
-- row this wants -- an OBSERVER title, the pig glyph, no flash, because the
-- three flashing kinds are the ones a player must react to and this fires
-- about once a minute all session. Until that row lands, `good` is the
-- honest neighbour: it is the kind that already means "something arrived".
local function announceDrop(herd: Herd)
	local kind = if (Config.NOTIFY :: any).herd then "herd" else "good"
	local message = ("OBSERVER: Batch %d released. Landing zone: %s."):format(
		herd.id, HerdService.zoneWords(herd.at))
	for _, player in ipairs(Players:GetPlayers()) do
		notify(player, message, kind)
	end
end

-- ============================================================
-- GROUND
-- ============================================================

-- A wander point is refused if it is on the street or inside any registered
-- veto -- the yard test, filled in by Main. The band is derived to clear
-- both by construction; the vetoes are the guarantee that survives somebody
-- moving a fence.
function HerdService.addGroundVeto(fn: (Vector3) -> boolean)
	table.insert(groundVetoes, fn)
end

function HerdService.groundAllows(position: Vector3): boolean
	if Config.isOnStreet(position) then
		return false
	end
	for _, veto in ipairs(groundVetoes) do
		if veto(position) then
			return false
		end
	end
	return true
end

-- Is the straight walk from `from` to `to` on allowed ground the whole way?
-- Sampled every `Config.HERDS.pathSample` studs (the endpoint included),
-- because a legal endpoint says nothing about the ground between: a pond
-- registered as a veto sits INSIDE the band, and a pack that only tested
-- where it was going would wade straight through one to get there.
--
-- THREE LINES, NOT ONE. The leader's own line and a flank either side at
-- `followSpacing`, because the thing walking is a pack three columns wide
-- and a line that misses a pond by a stud drags the outside column through
-- the water. The flanks are the formation's own width, so a wider
-- formation moves them with no second number.
function HerdService.pathClear(from: Vector3, to: Vector3): boolean
	local dx, dz = to.X - from.X, to.Z - from.Z
	local dist = math.sqrt(dx * dx + dz * dz)
	if dist < 1e-6 then
		return HerdService.groundAllows(to)
	end
	-- Unit right-hand vector of the line, on the flat.
	local rx, rz = dz / dist, -dx / dist
	local flank = Config.HERDS.followSpacing
	local n = math.max(1, math.ceil(dist / Config.HERDS.pathSample))
	for k = 1, n do
		local t = k / n
		local x, z = from.X + dx * t, from.Z + dz * t
		for _, side in ipairs({ 0, -flank, flank }) do
			if not HerdService.groundAllows(Vector3.new(x + rx * side, to.Y, z + rz * side)) then
				return false
			end
		end
	end
	return true
end

local function groundPoint(x: number, z: number): Vector3
	local g = Config.herdGround()
	return Vector3.new(x, g.groundY + PiggyModel.MINI_CENTRE_Y, z)
end

-- IS THIS POINT INSIDE THE WANDER BAND ITSELF? `groundAllows` answers a
-- different and narrower question -- is this the street, is it somebody's
-- yard, is it a pond -- and it says nothing about the band's own edges,
-- because the ground slab runs 45 studs further out than `bandFar` does.
-- That margin is not slack: the valley wall stands its foreground columns in
-- to |z| 258, so a landing slot 25 studs past the band is a piggy in rock.
-- The roaming leader never met this because `wanderTarget` draws inside the
-- band by construction; a DROP has to place ten slots at once, so it asks.
function HerdService.inBand(point: Vector3): boolean
	local g = Config.herdGround()
	local z = math.abs(point.Z)
	return z >= g.bandNear and z <= g.bandFar and math.abs(point.X) <= g.corridorX
end

-- WHICH WAY A MINI POINTS. `CFrame.lookAt` aims LookVector, which is -Z,
-- and every builder in this repo authors facing +Z -- the guard dog ran
-- tail-first through every patrol until this line was written down. One
-- function, so the turn is written once.
local function facingCF(at: Vector3, facing: Vector3): CFrame
	return CFrame.lookAt(at, at + facing) * CFrame.Angles(0, math.pi, 0)
end

-- A random point in the band on the pack's side, tried a few times against
-- the vetoes -- the point AND the line to it. nil when nothing passed, in
-- which case the leader grazes where it stands rather than walking
-- somewhere it should not.
local function wanderTarget(herd: Herd): Vector3?
	local g = Config.herdGround()
	for _ = 1, 8 do
		local x = (math.random() * 2 - 1) * g.corridorX
		local z = herd.side * (g.bandNear + math.random() * (g.bandFar - g.bandNear))
		local point = groundPoint(x, z)
		if HerdService.groundAllows(point) and HerdService.pathClear(herd.at, point) then
			return point
		end
	end
	return nil
end

-- ============================================================
-- FORMATION
-- ============================================================

-- Follower `i` (2 = the first follower) keeps a slot behind the leader.
-- Returns (right, back) in studs.
--
-- THREE ABREAST: rows of three a `spacing` back each, the first two of a
-- row flanking and the third on the centre line, so a pack of four is a
-- loose column and a pack of ten is three rows -- three spacings deep and
-- two wide, a blob rather than a queue. Two abreast was measured and
-- refused: ten is then five rows, and a tail that far back cuts every
-- corner straight through the 8-stud fence margin.
--
-- ONE SHAPE, NOT TWO. There was a `file` variant for the kerb legs, because
-- the bore left under a stud of standing room beside the leader; a pack
-- arrives out of the sky now and never sets foot in a tunnel, so the
-- variant and its measurement went with the route.
function HerdService.formationOffset(i: number, spacing: number?): (number, number)
	local s = spacing or Config.HERDS.followSpacing
	local n = i - 1
	if n <= 0 then
		return 0, 0
	end
	local row = math.ceil(n / 3)
	local col = (n - 1) % 3
	local lateral = if col == 0 then -1 elseif col == 1 then 1 else 0
	return lateral * s, row * s
end

-- Where member `i` wants to stand this frame. Recomputed from the index
-- rather than stored, so when a member is caught everybody behind it
-- closes up a slot.
--
-- `drift` is OPTIONAL and the landing turns it off: a slot drawn with the
-- wobble in it slides while the pack is falling, so the ground a member was
-- cleared to land on is not the ground it lands on.
local function slotOf(herd: Herd, i: number, member: Member, now: number, drifting: boolean?): Vector3
	local slotRight, slotBack = HerdService.formationOffset(i)
	local right = Vector3.yAxis:Cross(herd.facing)
	local base = herd.at + right * slotRight - herd.facing * slotBack
	if drifting == false then
		return base
	end
	local j = Config.HERDS.jitter
	local drift = right * (math.sin(now * 0.7 + member.phase) * j)
		+ herd.facing * (math.cos(now * 0.5 + member.phase * 1.3) * j * 0.5)
	return base + drift
end

-- ============================================================
-- THE LANDING ZONE
-- ============================================================

-- WHICH PLOT A POINT IS BEHIND, so the announcement can say where without
-- this file learning anything about plots. `PlotService.plotCFrame` seats
-- row 0 (indices 1..PLOTS_PER_ROW) at -Z and row 1 at +Z on the same
-- `Config.plotColumnX` columns, so the number is that arithmetic read back.
function HerdService.plotBehind(at: Vector3): number
	local best, bestDx = 0, math.huge
	for col = 0, Config.PLOTS_PER_ROW - 1 do
		local dx = math.abs(at.X - Config.plotColumnX(col))
		if dx < bestDx then
			best, bestDx = col, dx
		end
	end
	local row = if at.Z < 0 then 0 else 1
	return row * Config.PLOTS_PER_ROW + best + 1
end

-- The landing zone in words a nine-year-old can walk to. EAST AND WEST ARE
-- THIS FILE'S OWN CONVENTION ALREADY -- `trigger` has named the tunnels that
-- way since it was written -- and past the last column there is no plot to
-- be "behind", so the end of the field is named instead of a plot that is
-- forty studs to one side of it.
function HerdService.zoneWords(at: Vector3): string
	local lastX = Config.plotColumnX(Config.PLOTS_PER_ROW - 1)
	local plot = HerdService.plotBehind(at)
	if math.abs(at.X) > lastX + Config.PLOT_HALF_WIDTH then
		return ("the %s end of the field, past Plot %d"):format(
			if at.X > 0 then "east" else "west", plot)
	end
	return ("the field behind Plot %d"):format(plot)
end

-- Does a pack of `count` land legally with its leader here, facing this way?
-- EVERY SLOT IS TESTED, not the centre: the formation is three spacings deep
-- and two wide, so a leader a few studs inside `bandFar` puts its back row
-- in the valley wall, and a leader beside a pond drops three members in the
-- water. Drift is off for the same reason it is off at the landing itself.
function HerdService.dropFits(at: Vector3, facing: Vector3, count: number): boolean
	local probe: Herd = {
		id = 0, kind = "", side = if at.Z < 0 then -1 else 1, state = "drop",
		members = {}, at = at, facing = facing,
		phaseStart = 0, phaseUntil = 0, roamUntil = 0, grazeUntil = 0, target = nil,
		beacon = nil, beaconUntil = 0,
	}
	local blank: Member = {
		key = "", tier = "", at = at, facing = facing, phase = 0, walked = 0,
		lift = 0, fall = 0, landed = false, stagger = 0, puff = nil, puffUntil = 0,
		nextDigAt = 0, digUntil = 0, taken = false,
	}
	for i = 1, count do
		local slot = slotOf(probe, i, blank, 0, false)
		if not HerdService.inBand(slot) or not HerdService.groundAllows(slot) then
			return false
		end
	end
	return true
end

-- A landing zone on `side`, or nil when the band is too crowded to take one.
--
-- THE PACK FACES THE HOUSES, which stacks the formation AWAY from the back
-- fences rather than toward them, and is the read the fiction wants: a batch
-- released into the enclosure, looking at the occupants. It also makes the
-- one binding constraint legible -- the leader has to land at least three
-- spacings in from `bandFar` -- rather than leaving it to a random yaw.
local function pickDropPoint(side: number, count: number): (Vector3?, Vector3)
	local g = Config.herdGround()
	local facing = Vector3.new(0, 0, -side)
	for _ = 1, dropSpec().tries do
		local x = (math.random() * 2 - 1) * g.corridorX
		local z = side * (g.bandNear + math.random() * (g.bandFar - g.bandNear))
		local at = groundPoint(x, z)
		if HerdService.dropFits(at, facing, count) then
			return at, facing
		end
	end
	return nil, facing
end

-- ============================================================
-- DIGGING
-- ============================================================

-- The member's next dig, drawn from the band so a pack never digs in step.
local function drawDig(now: number): number
	local every = Config.HERDS.dig.every
	return now + every.min + math.random() * (every.max - every.min)
end

-- May anybody in this herd be digging right now? `dig.never` names the
-- states -- the drop and the recall -- and it is asked every frame so a dig
-- in progress ENDS the moment the pack is called back up.
--
-- `NEVER_DIG` is checked as well as the list, and that is not belt and
-- braces for its own sake: until the Config block lands, `dig.never` still
-- names the retired tunnel legs, and a list that names no state a herd has
-- is a list that forbids nothing.
function HerdService.mayDig(herd: Herd): boolean
	if NEVER_DIG[herd.state] then
		return false
	end
	for _, state in ipairs(Config.HERDS.dig.never) do
		if herd.state == state then
			return false
		end
	end
	return true
end

local function publishDig(member: Member, startedAt: number?)
	if member.model then
		member.model:SetAttribute(Config.HERD_DIG_ATTRIBUTE, startedAt)
	end
end

-- ============================================================
-- ROLLING A HERD
-- ============================================================

-- The kind, through the one damped picker. Pure: reads `lastKind`, sets
-- nothing, so a suite can sweep tickets through it.
function HerdService.pickKind(ticket: number?): string?
	local weights: { [string]: number } = {}
	for key, row in pairs(Config.HERDS.roster) do
		weights[key] = row.weight or 0
	end
	return Config.pickWeighted(weights, lastKind, Config.HERDS.repeatWeight, ticket)
end

-- The members of a herd of `kind`, rolled but not built. A tier the cap
-- forbids is never rolled; a tier with no stock falls DOWN (see
-- `Config.herdDraw`). A row that rolls nothing at all yields an empty list,
-- which the caller treats as "no herd" and says so.
function HerdService.rollMembers(kind: string): { Member }
	local row = Config.HERDS.roster[kind]
	local members: { Member } = {}
	if not row then
		return members
	end
	local size = Config.HERDS.size
	local count = math.random(size.min, size.max)
	local now = os.clock()
	local spec = dropSpec()
	for i = 1, count do
		local key, tier = Config.herdDraw(row.tiers)
		if key and tier then
			table.insert(members, {
				key = key,
				tier = tier,
				at = Vector3.zero,
				facing = Vector3.zAxis,
				phase = math.random() * math.pi * 2,
				walked = 0,
				lift = 0,
				fall = 0,
				landed = false,
				stagger = 0,
				puff = nil,
				puffUntil = 0,
				nextDigAt = drawDig(now),
				digUntil = 0,
				taken = false,
			})
		end
	end
	-- THE STAGGER IS SPREAD ACROSS THE PACK RATHER THAN DRAWN PER MEMBER,
	-- and it is solved against what actually rolled rather than what was
	-- asked for: an even spread covers the whole of `drop.stagger` where ten
	-- uniform draws leave clumps and gaps, and what this is for is that no
	-- two members land on one frame. Front to back, so the pack arrives in
	-- its own rows -- the leader first, the back row last.
	local last = math.max(1, #members - 1)
	for i, member in ipairs(members) do
		member.stagger = spec.stagger * (i - 1) / last
	end
	return members
end

-- Which band gets the next pack: the side with fewer packs on it, random
-- on a tie. Counted against what is STANDING rather than dealt from a bag,
-- for the reason the resident floor is: packs leave one at a time, so
-- there is no moment at which "how many are there" has a bag's answer.
function HerdService.pickSide(): number
	local minus, plus = 0, 0
	for _, h in ipairs(herds) do
		if h.side < 0 then
			minus += 1
		else
			plus += 1
		end
	end
	if minus == plus then
		return if math.random() < 0.5 then -1 else 1
	end
	return if minus < plus then -1 else 1
end

-- ============================================================
-- BUILDING AND TEARING DOWN
-- ============================================================

local function ensureFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "Herds"
	f.Parent = Workspace
	folder = f
	return f
end

-- Forward-declared: `buildMember` connects the prompt to `claim`, which is
-- defined below it. A `local` read before its declaration is a nil global
-- in Luau, which this project has paid for eleven times.
local claim: (Herd, Member, Player) -> boolean

-- One pet-sized piggy, standing on the ground and answering a prompt.
--
-- ANCHORED, WHICH IS THE OPPOSITE OF WHAT `PiggyModel.build` HANDS BACK,
-- and on purpose. The mini is authored unanchored and massless because it
-- is normally welded to a running thief, and an anchored part welded to a
-- humanoid pins the humanoid. Nothing here is welded to anybody, and an
-- unanchored, non-colliding model simply FALLS -- three of the four shop
-- displays vanished on their first build for exactly this reason. So this
-- takes the same call `ShopFront` does: anchor whatever it is handed.
--
-- RENAMED, because the mini is born as `Config.LOOT_MODEL_NAME` and
-- `CarryPose` decides whether to pose a character as carrying by looking
-- for a child of that name. A herd piggy is never inside a character, so
-- that is belt and braces -- but a name is an interface with no compiler
-- behind it, and this one should say what the thing is.
local function buildMember(herd: Herd, member: Member)
	local model = PiggyModel.build(member.key)
	model.Name = "HerdPiggy"
	-- THE PEDESTAL'S OWN SIZE (designer, 2026-09-22), through
	-- `PiggyModel.scale` so anything on the mini measured in studs follows --
	-- the aura's sparks, and `PiggyWalk`'s stride and dig, which are solved
	-- against the body's own radius rather than a constant. Before the model
	-- is parented, so `PiggyWalk`'s rest-offset capture 0.25 s after it
	-- appears sees the finished size.
	--
	-- IT USED TO BE `Config.piggyScale` ALONE, which is the SKIN'S share of
	-- the size rather than the size: a herd member stood 2.2 studs across
	-- where the same skin stands 7.2 on a plinth, so the collection showed
	-- two animals for one skin and fifteen of the nineteen animal skins were
	-- unrecognisable in the grass.
	local factor = memberFactor(member.key)
	if factor ~= 1 then
		PiggyModel.scale(model, factor)
	end
	member.lift = PiggyModel.MINI_CENTRE_Y * (factor - 1)
	local body = PiggyModel.bodyOf(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
		end
	end
	model:SetAttribute("HerdId", herd.id)
	model:SetAttribute("HerdTier", member.tier)

	if body then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "CatchPrompt"
		prompt.ActionText = "Catch Piggy"
		prompt.ObjectText = nameOf(member.key)
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.HoldDuration = Config.HERDS.hold
		prompt.MaxActivationDistance = Config.HERDS.range
		prompt.RequiresLineOfSight = false
		-- The pedestal's own TAKE treatment: same verb, same glyph, same
		-- tone, so a piggy is caught the way one is taken off a plinth.
		-- No owner attribute -- a herd belongs to nobody, so every client
		-- may see this.
		Config.setPromptKind(prompt, "take")
		-- LANDING IS WHAT MAKES A MEMBER CATCHABLE. A prompt live on a pig
		-- 120 studs over the grass offers an action a player cannot reach,
		-- which is the silent-refusal rule wearing a button; `land` turns it
		-- on, and the recall turns it back off.
		prompt.Enabled = herd.state == "roam"
		prompt.Parent = body
		prompt.Triggered:Connect(function(player: Player)
			claim(herd, member, player)
		end)
		member.prompt = prompt
	end

	model:PivotTo(facingCF(member.at + Vector3.new(0, member.lift + member.fall, 0), member.facing))
	model.Parent = ensureFolder()
	member.model = model
	member.body = body
end

-- ============================================================
-- THE DROP ZONE MARKER
-- ============================================================

-- HOW A BEACON PART FADES: its own authored transparency is stashed ON the
-- instance, the way the ride footsteps stash their volume, so a fade reads
-- what the thing was rather than a second copy of it kept somewhere else.
local FADE_ATTRIBUTE = "BeaconBase"

local function beaconBase(inst: Instance, base: number)
	inst:SetAttribute(FADE_ATTRIBUTE, base)
end

local function fadeBeacon(model: Instance, alpha: number)
	local list = model:GetDescendants()
	table.insert(list, model)
	for _, d in ipairs(list) do
		local stash = d:GetAttribute(FADE_ATTRIBUTE)
		local base = if type(stash) == "number" then stash else nil
		if base == nil then
			continue
		end
		local value = base + (1 - base) * math.clamp(alpha, 0, 1)
		if d:IsA("BasePart") then
			d.Transparency = value
		elseif d:IsA("TextLabel") then
			-- THE TEXT ONLY. `Theme.title` and `Theme.body` both set
			-- `TextStrokeTransparency` to 1, so touching it here would turn a
			-- stroke ON as the card faded out.
			d.TextTransparency = value
		elseif d:IsA("UIStroke") then
			d.Transparency = value
		elseif d:IsA("GuiObject") then
			d.BackgroundTransparency = value
		end
	end
end

-- THE MARKER, STOOD ON THE SPOT BEFORE THE PACK REACHES IT. The toast says
-- WHERE in words; this says where by standing there, which is the only half
-- a player running across the street can act on.
--
-- A COLUMN AND A CARD, AND BOTH ARE DELIBERATE. The column is the drop
-- shaft: it runs from the grass to `drop.height`, so it is the line the
-- pack actually comes down, and it is tall enough to clear the grove (26 to
-- 35 studs) and every house (to 64) between the band and the pavement. The
-- card is `AlwaysOnTop` with `MaxDistance` 0 -- unlimited -- because a
-- `SurfaceGui` culls by CHARACTER distance and this has to read from the far
-- end of a 443-stud street. Note what that costs: an always-on-top billboard
-- is drawn in a pass `screen_capture` is taken before, so THIS CARD IS
-- INVISIBLE TO EVERY SCREENSHOT EVER TAKEN OF IT.
local function buildBeacon(herd: Herd): Instance?
	local spec = dropSpec()
	local g = Config.herdGround()
	local model = Instance.new("Model")
	model.Name = "DropZone"

	local column = Instance.new("Part")
	column.Name = "Shaft"
	column.Shape = Enum.PartType.Cylinder
	-- A ROBLOX CYLINDER'S AXIS IS ITS X, so a standing column is
	-- (height, d, d) turned a quarter about Z. Written the other way round it
	-- is a disc as wide as the column was tall, and the turn meant to stand
	-- it up lays that disc flat -- the trap this project has recorded five
	-- times over.
	column.Size = Vector3.new(spec.height, spec.beaconWidth, spec.beaconWidth)
	column.CFrame = CFrame.new(herd.at.X, g.groundY + spec.height / 2, herd.at.Z)
		* CFrame.Angles(0, 0, math.pi / 2)
	column.Material = Enum.Material.Neon
	-- A NEON PART WANTS A DEEP COLOUR: neon renders a colour flat out and the
	-- BloomEffect takes it from there, so a pale tint on something this size
	-- is a white hole rather than a beam. `Theme.COOL` is the one saturated
	-- tone in this palette that is neither money, the pig, nor an alarm.
	column.Color = Theme.COOL
	column.Transparency = 0.55
	beaconBase(column, 0.55)
	column.Anchored = true
	column.CanCollide, column.CanQuery, column.CanTouch, column.CastShadow = false, false, false, false
	column.Parent = model

	local anchor = Instance.new("Part")
	anchor.Name = "Label"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(herd.at.X, g.groundY + spec.beaconWidth * 3, herd.at.Z)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide, anchor.CanQuery, anchor.CanTouch, anchor.CastShadow = false, false, false, false
	anchor.Parent = model

	local gui = Instance.new("BillboardGui")
	gui.Name = "DropLabel"
	gui.Size = UDim2.new(0, 190, 0, 78)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 0
	gui.Adornee = anchor
	gui.Parent = anchor

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.new(1, 0, 1, 0)
	-- ONE `Theme.card` AND NO SECOND OUTLINE: that helper already paints the
	-- paper, rounds it and strokes it, and a GuiObject takes ONE UIStroke --
	-- a second is at best redundant and at worst the one the engine draws.
	Theme.card(card, 10)
	beaconBase(card, 0)
	card.Parent = gui
	for _, d in ipairs(card:GetChildren()) do
		if d:IsA("UIStroke") then
			beaconBase(d, 0)
		end
	end

	local title = Instance.new("TextLabel")
	title.Name = "Zone"
	title.Size = UDim2.new(1, -12, 0.55, 0)
	title.Position = UDim2.new(0, 6, 0, 4)
	title.BackgroundTransparency = 1
	title.Text = "DROP ZONE"
	Theme.title(title, 30, Theme.COOL_INK)
	beaconBase(title, 0)
	title.Parent = card

	local batch = Instance.new("TextLabel")
	batch.Name = "Batch"
	batch.Size = UDim2.new(1, -12, 0.4, 0)
	batch.Position = UDim2.new(0, 6, 0.56, 0)
	batch.BackgroundTransparency = 1
	batch.Text = ("BATCH %d"):format(herd.id)
	Theme.body(batch, 24, Theme.MUTED)
	beaconBase(batch, 0)
	batch.Parent = card

	model.Parent = ensureFolder()
	return model
end

local function destroyBeacon(herd: Herd)
	if herd.beacon then
		herd.beacon:Destroy()
		herd.beacon = nil
	end
end

-- The dust a landing throws up: one flat disc under the member, expanding
-- and fading on the same step loop that moves it. PARTS RATHER THAN A
-- ParticleEmitter, because an emitter needs a texture, and a texture is a
-- third-party asset that can be moderated away -- the call every other
-- effect in this repo already makes.
local function landingPuff(member: Member, now: number)
	local body = member.body
	if not body then
		return
	end
	local spec = dropSpec()
	local puff = Instance.new("Part")
	puff.Name = "LandingPuff"
	puff.Shape = Enum.PartType.Cylinder
	local r = spec.puffRadius * math.max(1, memberFactor(member.key))
	puff.Size = Vector3.new(0.2, r, r)
	puff.CFrame = CFrame.new(member.at.X, member.at.Y - PiggyModel.MINI_CENTRE_Y + 0.1, member.at.Z)
		* CFrame.Angles(0, 0, math.pi / 2)
	puff.Color = Theme.SAND_DEEP
	puff.Material = Enum.Material.SmoothPlastic
	puff.Transparency = 0.35
	puff.Anchored = true
	puff.CanCollide, puff.CanQuery, puff.CanTouch, puff.CastShadow = false, false, false, false
	puff.Parent = ensureFolder()
	member.puff = puff
	member.puffUntil = now + spec.puffSeconds
end

local function destroyMember(member: Member)
	if member.model then
		member.model:Destroy()
		member.model = nil
	end
	if member.puff then
		member.puff:Destroy()
		member.puff = nil
	end
	member.puffUntil = 0
	member.body = nil
	member.prompt = nil
end

local function removeHerd(herd: Herd)
	destroyBeacon(herd)
	for _, member in ipairs(herd.members) do
		destroyMember(member)
	end
	for i, h in ipairs(herds) do
		if h == herd then
			table.remove(herds, i)
			break
		end
	end
	-- "When one exits, a new one enters": the replacement is due after a
	-- short beat rather than a whole spawn period.
	nextSpawnAt = math.min(nextSpawnAt, os.clock() + Config.HERDS.replaceDelay)
end

-- ============================================================
-- THE PICK-UP
-- ============================================================

-- Is the player actually beside the member? The prompt's own range is a
-- CLIENT fact, so it is re-asked here with slack, the way every reach in
-- this game is re-checked on the trigger.
local function reach(player: Player, member: Member): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - member.at).Magnitude <= Config.HERDS.range + 4
end

-- Lands a caught piggy on the player's lawn. Returns (ok, why-not).
--
-- THE SAME DOOR A CRATE ROLL USES, and deliberately no other: `ChestService.
-- handOver` is the shape. The first copy of a skin goes through
-- `SetService.grant`, which owns the wardrobe write, the collection write
-- and every push; a REPEAT is a second piggy rather than a spare (designer
-- ruling 2026-09-21), so it steps around `grant`'s early-out and goes
-- straight onto a pedestal through `Config.addPiggy`, then repaints -- a
-- lawn changed and not republished is the failure this project records
-- more than any other.
--
-- A FULL LAWN REFUSES BEFORE ANYTHING IS WRITTEN. `addPiggy` with
-- `place = true` bumps nothing when it cannot land, so there is no ghost to
-- roll back; the refusal names the fix, because one that does not is
-- indistinguishable from a broken prompt.
function HerdService.grant(player: Player, key: string): (boolean, string?)
	local data = DataService.get(player)
	if not data then
		return false, "Your save is not loaded yet. Try again in a moment."
	end
	if not Config.SKINS[key] then
		return false, "That piggy is not in the catalogue."
	end
	if Config.firstFreePiggySlot(data) == nil then
		return false, "Your lawn is full. Make room for a piggy before you catch one."
	end
	if SetService.owns(data, "skin", key) then
		Config.addPiggy(data, key, true)
		SetService.repaint(player, "skin")
		DataService.save(player)
	else
		SetService.grant(player, "skin", key)
	end
	return true, nil
end

-- FIRST PLAYER TO FINISH THE HOLD GETS IT. `taken` is set before anything
-- below can yield, so two holds finishing in the same frame resolve in
-- arrival order and the second is told so. A grant that fails hands the
-- member back to the herd untouched -- it is still there to be caught by
-- somebody with room. A member claimed MID-DIG goes the same way: the
-- model is destroyed with the stamp still on it, and a destroyed model has
-- no reader.
claim = function(herd: Herd, member: Member, player: Player): boolean
	if member.taken or not member.model then
		notify(player, "Somebody else got that one.", "warn")
		return false
	end
	-- NOTHING IN THE AIR IS CATCHABLE, RE-ASKED ON THE TRIGGER the way every
	-- reach in this game is. The prompt is built disabled and enabled on the
	-- thump, so the engine already refuses a pig in the air -- but `reach` is
	-- measured against the member's GROUND point, which a player can be
	-- standing on while the pack is 120 studs over their head, and the
	-- prompt's own state is the one guard here that lives on the client's
	-- side of the wire. The STATE as well as the member, because a recalled
	-- pack is rising rather than falling and `landed` is true of all of it.
	if herd.state ~= "roam" or not member.landed then
		notify(player, "That one is not on the ground yet.", "warn")
		return false
	end
	if not reach(player, member) then
		notify(player, "Get closer to catch it.", "warn")
		return false
	end
	member.taken = true
	local ok, why = HerdService.grant(player, member.key)
	if not ok then
		member.taken = false
		notify(player, why or "That piggy would not come.", "warn")
		return false
	end
	notify(player, ("You caught a %s! It is standing on your lawn."):format(nameOf(member.key)), "good")

	destroyMember(member)
	for i, m in ipairs(herd.members) do
		if m == member then
			table.remove(herd.members, i)
			break
		end
	end
	if #herd.members == 0 then
		removeHerd(herd)
	end
	return true
end
HerdService.claim = claim

-- ============================================================
-- SPAWNING
-- ============================================================

function HerdService.count(): number
	return #herds
end

function HerdService.canSpawn(now: number): boolean
	return #herds < Config.HERDS.maxLoose and now >= nextSpawnAt
end

-- Builds a herd of `kind` (or a picked one) over a landing zone and releases
-- it. Respects the cap and nothing else -- the TIMER is the scheduler's
-- business, so the admin trigger can call this at will.
-- Returns the herd, or nil and a reason.
function HerdService.spawn(kindKey: string?): (Herd?, string?)
	if #herds >= Config.HERDS.maxLoose then
		return nil, ("%d herds are already loose, which is the cap."):format(#herds)
	end
	local kind = kindKey or HerdService.pickKind()
	if not kind or not Config.HERDS.roster[kind] then
		return nil, ("Unknown herd kind %q."):format(tostring(kind))
	end
	local members = HerdService.rollMembers(kind)
	if #members == 0 then
		warn(("[HerdService] herd kind %q rolled no members: nothing under the tier cap is stocked"):format(kind))
		return nil, "That herd kind has nothing to roll. See Config.auditHerds."
	end

	-- The emptier band, and a landing zone inside it that the WHOLE PACK
	-- fits in. Refused out loud rather than dropped anywhere legal-ish: a
	-- pack landing half in a pond is the silent failure this file refuses,
	-- and the band is 443 by 97 studs against a pack about 23 by 34, so
	-- `drop.tries` misses only if somebody has vetoed most of a side.
	local side = HerdService.pickSide()
	local at, facing = pickDropPoint(side, #members)
	if not at then
		return nil, "No clear landing zone in that band. See HerdService.dropFits."
	end

	serial += 1
	local now = os.clock()
	local spec = dropSpec()
	local herd: Herd = {
		id = serial,
		kind = kind,
		side = side,
		state = "drop",
		members = members,
		at = at,
		facing = facing,
		phaseStart = now,
		-- The pack is in the air until its LAST member is down AND SETTLED:
		-- the hop is part of the landing, and cutting it off at the last
		-- member's touchdown would snap that one piggy flat while its
		-- neighbours were still bouncing.
		phaseUntil = now + spec.seconds + spec.stagger + spec.bounceSeconds,
		roamUntil = 0,
		grazeUntil = 0,
		target = nil,
		beacon = nil,
		beaconUntil = now + spec.beaconSeconds,
	}
	-- Every member is born ON ITS OWN LANDING SLOT, drift off, with the air
	-- carried in `fall` rather than in `at` -- so the ground each one was
	-- cleared for is the ground it lands on, and the formation it lands in
	-- is the formation it is about to walk.
	for i, member in ipairs(members) do
		member.facing = herd.facing
		member.at = slotOf(herd, i, member, now, false)
		member.fall = spec.height
		buildMember(herd, member)
	end
	herd.beacon = buildBeacon(herd)
	announceDrop(herd)

	lastKind = kind
	nextSpawnAt = now + Config.HERDS.spawnEverySeconds
	table.insert(herds, herd)
	return herd, nil
end

-- Sends a herd home now (admin, or a herd whose walk errored).
function HerdService.despawn(herd: Herd)
	removeHerd(herd)
end

-- ============================================================
-- MOVEMENT
-- ============================================================

-- HOW HIGH A MEMBER IS, THIS FRAME, in studs above its own landing spot.
-- Pure: given the pack's phase clock and the member's own stagger it is a
-- function of `now`, so nothing about the fall is stored per frame and a
-- dropped Heartbeat cannot leave a piggy hanging in the air.
--
-- THE FALL ACCELERATES, which is what makes it a fall rather than a lowering,
-- and getting it backwards is easy: `h * (1 - p)^2` is the tempting one and
-- is the WRONG WAY ROUND -- its speed is greatest at the release and zero at
-- the thump, which is a crane setting something down. `h * (1 - p^2)` is the
-- other one: zero speed at the release, greatest at the thump, which is
-- constant acceleration written in one line. A sine would read as zero
-- gravity, the lesson the pedestal idle already paid for.
--
-- AND IT IS SLOWER THAN GRAVITY ON PURPOSE. Real gravity drops 120 studs in
-- 1.11 s; this takes `drop.seconds`, which is 2.2x that. What that buys is
-- the read -- a batch RELEASED into an enclosure rather than dropped out of
-- a hole -- and the time for somebody who heard the toast to turn round and
-- watch it land.
--
-- THE RECALL IS `h * p^2`, which is the same curve pointed the other way:
-- slow off the grass, quickest at the top. A pack being drawn up by
-- something, rather than a fall played backwards.
--
-- The settle after it is one small hop -- `bounce` studs of a scale-1 mini,
-- times the member's own factor, over `bounceSeconds` -- because ten animals
-- arriving and stopping dead reads as ten statues being placed.
function HerdService.fallAt(herd: Herd, member: Member, now: number): number
	local spec = dropSpec()
	if herd.state == "drop" then
		local landAt = herd.phaseStart + spec.seconds + member.stagger
		if now < landAt then
			local p = math.clamp(1 - (landAt - now) / spec.seconds, 0, 1)
			return spec.height * (1 - p * p)
		end
		local b = (now - landAt) / spec.bounceSeconds
		if b < 1 then
			return spec.bounce * memberFactor(member.key) * math.sin(math.pi * b)
		end
		return 0
	elseif herd.state == "recall" then
		local liftAt = herd.phaseStart + member.stagger
		local p = math.clamp((now - liftAt) / spec.seconds, 0, 1)
		return spec.height * p * p
	end
	return 0
end

-- The frame a member touches down: its dust, and the prompt that makes it
-- catchable. Called once, guarded by `member.landed` -- `fall` crossing zero
-- cannot be the test, because the settle hop takes it back off zero and down
-- again and would land the whole pack twice.
local function land(member: Member, now: number)
	landingPuff(member, now)
	if member.prompt then
		member.prompt.Enabled = true
	end
end

-- One frame of one herd. In the air nothing moves horizontally at all: the
-- pack holds the slots it was cleared for and only `fall` changes. On the
-- ground the leader walks its wander target and followers ease toward their
-- formation slots, everything on the flat at the pack's own speed, and a
-- member faces the way it actually went -- a still member keeps the pack's
-- facing rather than snapping.
local function stepHerd(herd: Herd, dt: number, now: number)
	local speed = Config.herdSpeed()
	local step = speed * dt
	local airborne = herd.state == "drop" or herd.state == "recall"

	local function toward(from: Vector3, to: Vector3): (Vector3, boolean)
		local delta = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
		local dist = delta.Magnitude
		if dist <= step then
			return Vector3.new(to.X, from.Y, to.Z), true
		end
		return from + delta.Unit * step, false
	end

	-- THE BEACON IS FADED FROM THIS LOOP rather than by a tween or a timer of
	-- its own, because it is one more thing that already has a frame here and
	-- a second clock is a second thing that can disagree with the herd.
	if herd.beacon then
		local spec = dropSpec()
		local alpha = (now - (herd.beaconUntil - spec.beaconFade)) / spec.beaconFade
		if alpha >= 1 then
			destroyBeacon(herd)
		elseif alpha > 0 then
			fadeBeacon(herd.beacon, alpha)
		end
	end

	if airborne then
		if now >= herd.phaseUntil then
			if herd.state == "drop" then
				herd.state = "roam"
				local roam = Config.HERDS.roam
				herd.roamUntil = now + roam.min + math.random() * (roam.max - roam.min)
				herd.grazeUntil = now
				herd.target = nil
			else
				removeHerd(herd)
				return
			end
		end
	end

	local goal: Vector3? = nil
	if herd.state == "roam" then
		if now >= herd.roamUntil then
			-- RECALLED: the drop with the sign flipped. Prompts off first --
			-- a pack rising out of reach must not still be offering itself --
			-- and any dig in progress ends with the state change below.
			herd.state = "recall"
			herd.phaseStart = now
			local spec = dropSpec()
			herd.phaseUntil = now + spec.seconds + spec.stagger
			herd.target = nil
			for _, member in ipairs(herd.members) do
				if member.prompt then
					member.prompt.Enabled = false
				end
			end
		elseif herd.target then
			goal = herd.target
		elseif now >= herd.grazeUntil then
			herd.target = wanderTarget(herd)
			if not herd.target then
				local graze = Config.HERDS.graze
				herd.grazeUntil = now + graze.min + math.random() * (graze.max - graze.min)
			end
			goal = herd.target
		end
	end

	if goal then
		local moved, arrived = toward(herd.at, goal)
		local delta = Vector3.new(moved.X - herd.at.X, 0, moved.Z - herd.at.Z)
		if delta.Magnitude > 1e-4 then
			herd.facing = delta.Unit
		end
		herd.at = moved
		if arrived then
			herd.target = nil
			local graze = Config.HERDS.graze
			herd.grazeUntil = now + graze.min + math.random() * (graze.max - graze.min)
		end
	end

	local mayDig = HerdService.mayDig(herd)
	-- RE-ASKED AFTER THE TRANSITIONS ABOVE, never reused from the top of the
	-- frame: the frame a pack lands is the frame it starts walking, and the
	-- frame it is recalled is the frame it stops.
	local inAir = herd.state == "drop" or herd.state == "recall"
	for i, member in ipairs(herd.members) do
		-- THE PUFF, on its own short clock. Destroyed here rather than by a
		-- `task.delay` per member so nothing outlives a herd that was cleared
		-- while its dust was still settling.
		if member.puff then
			local spec = dropSpec()
			local t = 1 - math.max(0, member.puffUntil - now) / spec.puffSeconds
			if t >= 1 then
				member.puff:Destroy()
				member.puff = nil
			else
				local r = spec.puffRadius * math.max(1, memberFactor(member.key)) * (1 + t * 1.6)
				member.puff.Size = Vector3.new(0.2, r, r)
				member.puff.Transparency = 0.35 + 0.65 * t
			end
		end

		-- TOUCHDOWN, asked whatever the herd's state is. The LAST member of a
		-- pack lands on the very frame the herd starts roaming -- its
		-- `phaseUntil` is that landing plus the settle -- so a check that
		-- only ran while the state was still "drop" would leave one piggy of
		-- every pack dustless and, far worse, uncatchable.
		if not member.landed and herd.state ~= "recall"
			and now >= herd.phaseStart + dropSpec().seconds + member.stagger then
			member.landed = true
			land(member, now)
		end

		-- IN THE AIR: the slot is held, the fall is the only thing that
		-- moves, and nothing is published -- `Walked` is ground covered, and
		-- a member that has not walked has not covered any.
		if inAir then
			-- A DIG ENDS THE FRAME THE PACK LEAVES THE GROUND, and a clock
			-- that comes due while it is off it is REDRAWN rather than held:
			-- held, every clock that ripened during a fall would fire on the
			-- first roaming frame and the whole pack would dig in step. Both
			-- are the rule the old tunnel legs kept, moved to where the pack
			-- now spends its non-roaming time.
			if member.digUntil > 0 then
				member.digUntil = 0
				member.nextDigAt = drawDig(now)
				publishDig(member, nil)
			elseif now >= member.nextDigAt then
				member.nextDigAt = drawDig(now)
			end
			member.fall = HerdService.fallAt(herd, member, now)
			member.facing = herd.facing
			if member.model then
				member.model:PivotTo(facingCF(
					member.at + Vector3.new(0, member.lift + member.fall, 0), member.facing))
			end
			continue
		end
		member.fall = 0

		-- DIGGING, before any movement. A member mid-dig is frozen: no
		-- step, no facing change, no `Walked` publish. A dig ends on its
		-- clock, or at once when the pack is called back up, and the
		-- attribute goes to nil either way, which is what "not digging"
		-- reads as.
		if member.digUntil > 0 then
			if now < member.digUntil and mayDig then
				continue
			end
			member.digUntil = 0
			member.nextDigAt = drawDig(now)
			publishDig(member, nil)
		elseif now >= member.nextDigAt then
			if not mayDig then
				-- Redrawn rather than held, so a pack arriving in the band
				-- does not have every clock already due and dig in step.
				member.nextDigAt = drawDig(now)
			elseif not member.taken and (i > 1 or (herd.state == "roam" and herd.target == nil)) then
				member.digUntil = now + Config.HERDS.dig.seconds
				if i == 1 then
					-- The leader IS the anchor: hold the graze for the dig,
					-- or `herd.at` walks off and the leader never catches up.
					herd.grazeUntil = math.max(herd.grazeUntil, member.digUntil)
				end
				publishDig(member, Workspace:GetServerTimeNow())
				continue
			end
			-- A leader that is walking holds its clock for the next graze.
		end

		local want = if i == 1 then herd.at else slotOf(herd, i, member, now)
		local moved, _ = toward(member.at, want)
		-- A follower may hurry a little to close on its slot, never so much
		-- that it overtakes the leader for long.
		if i > 1 then
			local delta = Vector3.new(want.X - member.at.X, 0, want.Z - member.at.Z)
			if delta.Magnitude > step * 1.4 then
				moved = member.at + delta.Unit * step * 1.4
			end
		end
		local delta = Vector3.new(moved.X - member.at.X, 0, moved.Z - member.at.Z)
		local walked = delta.Magnitude
		if walked > 1e-3 then
			member.facing = delta.Unit
		elseif i == 1 then
			member.facing = herd.facing
		end
		member.at = moved
		if member.model then
			member.model:PivotTo(facingCF(member.at + Vector3.new(0, member.lift + member.fall, 0), member.facing))
			-- The walk's ONE publish: distance, only on a frame the member
			-- actually moved, so a grazing pack writes nothing to the wire.
			if walked > 1e-3 then
				member.walked += walked
				member.model:SetAttribute(Config.HERD_WALK_ATTRIBUTE, member.walked)
			end
		end
	end
end

local function stepAll(dt: number)
	local now = os.clock()
	-- Iterated over a copy: a herd may remove itself mid-step.
	local snapshot = table.clone(herds)
	for _, herd in ipairs(snapshot) do
		stepHerd(herd, dt, now)
	end
end

-- ============================================================
-- ADMIN
-- ============================================================

function HerdService.trigger(kind: string?): string
	local herd, why = HerdService.spawn(kind)
	if not herd then
		return why or "No herd."
	end
	return ("Batch %d (%s) released: %d piggies dropping into %s (%s side, x %.0f z %.0f)."):format(
		herd.id, herd.kind, #herd.members, HerdService.zoneWords(herd.at),
		if herd.side > 0 then "+Z" else "-Z", herd.at.X, herd.at.Z)
end

function HerdService.clear(): string
	local n = #herds
	for _, herd in ipairs(table.clone(herds)) do
		removeHerd(herd)
	end
	return ("Sent %d herds home."):format(n)
end

function HerdService.status(): string
	local parts = {}
	for _, herd in ipairs(herds) do
		local digging = 0
		for _, m in ipairs(herd.members) do
			if m.digUntil > 0 then
				digging += 1
			end
		end
		local air = 0
		for _, m in ipairs(herd.members) do
			if m.fall > 0 then
				air += 1
			end
		end
		table.insert(parts, ("#%d %s %s x%d dig=%d air=%d %s"):format(
			herd.id, herd.kind, herd.state, #herd.members, digging, air,
			HerdService.zoneWords(herd.at)))
	end
	return ("loose=%d/%d next=%.0fs last=%s [%s]"):format(
		#herds, Config.HERDS.maxLoose, math.max(0, nextSpawnAt - os.clock()),
		tostring(lastKind), table.concat(parts, "; "))
end

-- ============================================================
-- START
-- ============================================================

-- One beat of the scheduler: spawn if the cap has room and the timer is
-- due. Its own function so a suite can drive the REAL scheduler against a
-- stubbed clock rather than a copy of these lines.
function HerdService.tick(now: number)
	if HerdService.canSpawn(now) then
		local ok, err = pcall(HerdService.spawn, nil)
		if not ok then
			warn(("[HerdService] spawn failed: %s"):format(tostring(err)))
			-- Do not spin on a broken spawn: try again next gap.
			nextSpawnAt = now + Config.HERDS.spawnEverySeconds
		end
	end
end

function HerdService.start()
	nextSpawnAt = os.clock() + Config.HERDS.firstSpawnDelay

	-- PCALLED AS A WHOLE, the call the dog watcher already makes: a herd is
	-- scenery next to the loop underneath it, and a bad frame of pack
	-- movement may never stop the game being played. Warned once rather
	-- than sixty times a second, because a warning nobody can read is not a
	-- report.
	RunService.Heartbeat:Connect(function(dt: number)
		local ok, err = pcall(stepAll, dt)
		if not ok and not warnedStep then
			warnedStep = true
			warn(("[HerdService] movement step failed: %s"):format(tostring(err)))
		end
	end)

	-- The scheduler. Polled, not slept out in one lump, so the admin
	-- trigger and a herd leaving early are both noticed within a beat.
	task.spawn(function()
		while true do
			task.wait(0.5)
			HerdService.tick(os.clock())
		end
	end)
end

return HerdService
