--!strict
--[[
	BoltFX -- the Storm Wolf's lightning, flickering on the CLIENT.

	`BoltFX.start()` and nothing else. Every part tagged `StormBolt` is driven
	from one shared Heartbeat; a part carries its group in a `BoltPhase`
	attribute and nothing else has to be told anything.

	DRIVEN CLIENT-SIDE, WHICH IS THE CALL THE ANIMATED SKINS AND THE MOAT
	ALREADY MADE. The alternative is a Transparency write per bolt group per
	frame, replicated: six groups on twelve pigs is 4,320 property updates a
	second to say something every machine can derive from one clock and one
	integer. The server publishes the geometry and the phase, and never touches
	it again.

	A MODULE RATHER THAN A BLOCK IN `ClientMain`, and that is not a filing
	preference. That chunk sits on Luau's 200-local-register ceiling and has hit
	it repeatedly -- the failure is not this feature, it is the ENTIRE HUD,
	because the chunk never compiles and nothing gets built. A function body
	gets its own register file, so `require(...).start()` costs the caller ONE
	statement holding no local at all. Same call `RobBadge` and `HouseFX` make.

	--------------------------------------------------------------------------
	WHY THE BOLTS ARE SIX MESHES AND NOT ONE, AND NOT THIRTY-SIX

	`make_stormwolf_bolts.py` deals every bolt round-robin into `PHASES` groups,
	each holding bolts from the crest, the face, the tail and the hocks. So
	lighting one group puts lightning in four scattered places at once, and
	lighting the next puts it somewhere else entirely.

	One mesh could only flash as a unit -- the whole animal on, the whole animal
	off -- and "not all of it showing at the same time" would be unreachable
	however this file drove it. One mesh PER BOLT would give perfect control and
	cost 36 uploads and 36 MeshParts on every pig on the street. Six is the
	trade, and the resolution lives in the exporter rather than here.

	--------------------------------------------------------------------------
	THE RATE IS DERIVED FROM THE GROUP COUNT, WHICH IS THE ONE NUMBER HERE THAT
	IS NOT A TASTE DECISION

	`HouseFX` holds this whole game to three flashes a second, and its own entry
	is emphatic about which three: the standard counts a flash as a 10%
	luminance change over 20% of the screen, more than three a second is unsafe,
	THIS AUDIENCE IS NINE, and the number that matters is the AGGREGATE rather
	than the per-element one. Its castle phases four finials a quarter turn
	apart for exactly this reason -- four corners pulsing in lockstep read as a
	single full-screen flash.

	So `RATE` is not typed. Each group completes `MAX_AGGREGATE / groups` cycles
	a second, capped at `MAX_PER_ELEMENT`, and the groups are offset evenly
	around the cycle so two can never peak together. Add a seventh group and
	every group slows down on its own; the ceiling cannot be broken by editing
	the exporter.

	AND IT IS A CURVE, NEVER A SWITCH. `HouseFX` has no strobe anywhere in it:
	every effect is continuous, and the one thing that genuinely blinks SWEEPS
	like a lighthouse instead of switching. A bolt gets a fast attack and a
	slower decay, which is what a strike looks like, and it reaches full dark
	between strikes -- so a group is genuinely absent rather than dimmed.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local BoltFX = {}

-- The tag a bolt group carries, and the attribute naming its group. Both are
-- interfaces with no compiler behind them, which is the lesson `"LockLevel"`
-- cost this project four call sites to learn -- so they are named ONCE here and
-- whatever builds the pig reads them from this module rather than retyping the
-- literal.
BoltFX.TAG = "StormBolt"
BoltFX.PHASE_ATTRIBUTE = "BoltPhase"

-- **THE FLOOR IS WHAT LETS THE EYES JOIN IN WITHOUT BLINKING OUT.** A bolt goes
-- fully dark between strikes, which is the whole point of it -- a group that
-- merely dimmed would never be ABSENT and "not all of it at once" would be a
-- lie. An eye cannot do that: a piggy whose eyes vanish six times a minute
-- reads as a rendering fault, not as weather.
--
-- So a part may carry a floor, and it is driven by the SAME clock and the same
-- phase as everything else -- the eyes pulse with the storm and simply never
-- reach zero. One curve, one cap, two behaviours.
BoltFX.FLOOR_ATTRIBUTE = "BoltFloor"

-- **THESE BELONG IN `Config.STORM_BOLTS` THE DAY THE SKIN IS WIRED.** Every
-- tunable in this game lives in Config and these are no exception; they are
-- here because Config is one of the three files this project requires a claim
-- on before editing, and nothing reads them yet. Moving them is one table and
-- five reads.
-- **THIS SKIN DELIBERATELY EXCEEDS `HouseFX.MAX_RATE`, AND THAT IS A DECISION
-- RATHER THAN A DRIFT.** Everything else in this game is held to three flashes
-- a second, and the reasoning there is quoted at length: the standard treats a
-- flash as a 10% luminance change over 20% OF THE SCREEN, more than three a
-- second is unsafe, and this audience is nine.
--
-- The half of that rule which does not transfer is the AREA. `HouseFX` governs
-- whole buildings -- a Neon Tower pulsing is a large share of the frame. A bolt
-- group here is a few scattered ribbons on a twelve-stud animal, nowhere near
-- the 20% the standard is written about, so the flash COUNT is being measured
-- against a threshold whose other term is not met.
--
-- It is still a real trade and it is recorded as one: at 8/s this is the
-- fastest-flickering thing in the game by a factor of nearly three. If it ever
-- has to come back, these two numbers are the whole of it -- 3.0 and 0.9 put it
-- back exactly where the houses are, with no other edit.
local MAX_AGGREGATE = 8.0        -- flashes a second across the WHOLE animal
local MAX_PER_ELEMENT = 2.5      -- ...and no single group may beat this

-- **A STRIKE, NOT A PULSE, AND THIS IS WHAT "FASTER" ACTUALLY MEANT.**
--
-- The obvious way to make lightning read quicker is to raise the rate, and it
-- is the one move that is not available: the aggregate is already pinned at
-- `MAX_AGGREGATE`, and going past three flashes a second is the accessibility
-- ceiling `HouseFX` holds the whole game to, on an audience of nine-year-olds.
--
-- It is also the wrong diagnosis. What made the old curve read as SLOW was its
-- SHAPE rather than its frequency: a 0.10 rise and a 0.26 fall is 36% of the
-- cycle spent visibly ramping, which is a throb. Lightning is the opposite --
-- a near-instant strike, a fast fall, and then nothing for a long time.
--
-- AND THE SIGNATURE IS THE RETURN STROKE. Real lightning flickers two or three
-- times in quick succession down the same channel, and that stutter is what the
-- eye recognises. So a cycle now fires `STRIKES` spikes `STRIKE_GAP` apart, the
-- second dimmer than the first, and then goes dark -- which reads as far faster
-- than the throb it replaces while firing NO more flashes per second, because
-- the strikes are counted in the rate below.
-- **IN SECONDS, NOT IN SHARES OF A CYCLE, AND THE FIRST VERSION WAS THE
-- LATTER.** Written as fractions, a sharper strike bought nothing: counting the
-- return stroke in the rate lengthens the CYCLE to 4s, and 0.12 of 4s is 0.48s
-- -- barely quicker than the 0.72s throb it replaced. The shape had improved
-- and the clock had swallowed it.
--
-- A real strike is about a fifth of a second WHATEVER the storm is doing. So
-- these are absolute, and the cycle length now only decides how OFTEN a group
-- fires, never how long it takes.
local STRIKES = 2                -- return strokes per cycle
local STRIKE_GAP = 0.055         -- SECONDS between them
local ECHO = 0.62                -- how bright the second stroke is
local ATTACK = 0.020             -- SECONDS spent rising
local DECAY = 0.180              -- ...and falling. The rest of the cycle is dark.
-- **THE ATTACK IS WHAT READS AS FAST; THE DECAY IS WHAT KEEPS THE ANIMAL
-- ALIVE, AND THEY ARE NOT THE SAME DIAL.** At a 0.15 decay this measured 0.22
-- groups lit on average with NO BOLT AT ALL ON SCREEN 78% OF THE TIME -- a dark
-- pig with the eyes on and an occasional snap, which is not a storm.
--
-- The instinct is to raise the rate, and the rate is the one thing that is
-- capped. What is NOT capped is how long a flash lasts: the accessibility
-- ceiling counts ONSETS per second, so a strike may linger as long as it likes
-- without costing anything. A 17:1 attack-to-decay ratio is also just what
-- lightning does -- the eye takes its speed from the near-instant rise and its
-- presence from the afterglow.
local MIN_WRITE = 0.01           -- do not touch a property for less than this

-- **A BEAM'S TRANSPARENCY IS A `NumberSequence`, WHICH IS AN ALLOCATION.**
-- Building one per beam per frame is 31 objects a frame per animal for a value
-- the eye cannot resolve to better than a few per cent -- so the ramp is
-- pre-built once into buckets and a beam is only written when it crosses into a
-- new one. Same argument as `MIN_WRITE` for a part, one level up: the cost here
-- is the garbage rather than the property write.
--
-- The shape stays constant and only the LEVEL moves: opaque ends fading to
-- nothing, so an arc grows out of its crystal rather than starting square.
local BEAM_STEPS = 12
local BEAM_SEQ: { NumberSequence } = {}
for i = 0, BEAM_STEPS do
	local t = i / BEAM_STEPS
	BEAM_SEQ[i + 1] = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, t),
		NumberSequenceKeypoint.new(0.85, t),
		NumberSequenceKeypoint.new(1, 1),
	})
end

type Tracked = {
	part: BasePart?,
	beam: Beam?,
	phase: number,
	floor: number,
	bucket: number,
}

local tracked: { Tracked } = {}
local seen: { [Instance]: true } = {}
local phases: { [number]: true } = {}
local phaseCount = 0
local started = false

local function register(inst: Instance)
	-- A BEAM IS A FIRST-CLASS BOLT HERE, NOT A SPECIAL CASE. Point-to-point
	-- lightning arcing between two crystal tips is the same event as a bolt
	-- leaving one, and it has to strike on the same clock or the two read as two
	-- unrelated effects sharing an animal.
	if not (inst:IsA("BasePart") or inst:IsA("Beam")) then
		return
	end
	local part = inst :: any
	if seen[part] then
		return
	end
	-- A GROUP WITH NO PHASE IS A BUG THAT WOULD OTHERWISE LOOK LIKE A STYLE.
	-- Defaulting a missing attribute to 0 puts every unlabelled group in
	-- lockstep, which is precisely the arrangement the aggregate cap exists to
	-- prevent -- and it would read as "the lightning pulses together", which
	-- nobody would file as a fault.
	local phase = part:GetAttribute(BoltFX.PHASE_ATTRIBUTE)
	if typeof(phase) ~= "number" then
		warn(("BoltFX: %s carries no %s attribute -- not animated")
			:format(part:GetFullName(), BoltFX.PHASE_ATTRIBUTE))
		return
	end

	-- A missing floor is 0, which is a bolt. That default is safe in the way
	-- the missing PHASE default was not: it produces the ordinary behaviour
	-- rather than putting everything in lockstep.
	local floor = part:GetAttribute(BoltFX.FLOOR_ATTRIBUTE)
	if typeof(floor) ~= "number" then
		floor = 0
	end

	seen[part] = true
	table.insert(tracked, {
		part = if inst:IsA("BasePart") then inst :: BasePart else nil,
		beam = if inst:IsA("Beam") then inst :: Beam else nil,
		phase = phase :: number,
		floor = math.clamp(floor :: number, 0, 1),
		bucket = -1,
	})
	if not phases[phase :: number] then
		phases[phase :: number] = true
		phaseCount += 1
	end
end

local function step()
	if phaseCount == 0 then
		return
	end

	-- DERIVED EVERY FRAME RATHER THAN CACHED, because groups arrive over time:
	-- a pig built after this loop started adds a phase, and a rate cached at
	-- startup would go on running the old, faster cadence against more groups
	-- than it was solved for -- which is the aggregate cap being broken by
	-- something that looks like it has nothing to do with it.
	-- **TWO STROKES ONLY COST TWO FLASHES IF THEY SEPARATE, AND MEASURED, THESE
	-- DO NOT.** The divisor was `phaseCount * STRIKES` on the reasoning that a
	-- return stroke is a second onset -- true only when the first has gone dark
	-- before the second arrives. It has not: the gap is 0.10s against a 0.60s
	-- decay, so the second stroke lands on a bolt that is still bright and the
	-- eye reads ONE flash with a stutter in it.
	--
	-- Measured on a live client: 1.40 onsets a second against a ceiling of 3.0.
	-- The budget was being charged twice and spent once, and what it cost was
	-- the animal -- nothing lit at all on 54% of frames.
	--
	-- So the count is DERIVED from the shape rather than assumed from it. Shorten
	-- the decay below the gap and the strokes genuinely do separate, and this
	-- puts the rate back down on its own.
	local separated = STRIKE_GAP > (ATTACK + DECAY)
	local strokes = if separated then STRIKES else 1
	local rate = math.min(MAX_PER_ELEMENT,
		MAX_AGGREGATE / (phaseCount * strokes))
	local now = workspace:GetServerTimeNow()

	for _, row in tracked do
		local inst: Instance? = row.part or row.beam
		if inst == nil or inst.Parent == nil then
			continue
		end

		-- EVENLY OFFSET AROUND THE CYCLE. Two groups peaking together is the
		-- lockstep case, and it is the whole reason the finials in `HouseFX`
		-- are a quarter turn apart.
		local cycle = (now * rate + row.phase / phaseCount) % 1
		-- ...and where that is in SECONDS, which is what the strike is shaped in.
		local since = cycle / rate

		-- The brightest stroke wins where two overlap, rather than summing --
		-- adding them would push past full brightness and clip, which is the
		-- same blowout that turned the first cyan bolts white.
		local intensity: number = 0
		for i = 0, STRIKES - 1 do
			local t = since - i * STRIKE_GAP
			if t >= 0 and t < ATTACK + DECAY then
				local amp = if i == 0 then 1 else ECHO
				local v = if t < ATTACK
					then t / ATTACK
					else 1 - (t - ATTACK) / DECAY
				local lit = v * amp
				if lit > intensity then
					intensity = lit
				end
			end
		end

		-- The floor is applied to the INTENSITY rather than clamped onto the
		-- transparency afterwards, so a floored part still has the full shape
		-- of the strike in it -- it swings between `floor` and 1 instead of
		-- between 0 and 1, and the attack still reads as an attack.
		intensity = row.floor + (1 - row.floor) * intensity

		local want = 1 - intensity
		if row.part then
			local p = row.part :: BasePart
			if math.abs(p.Transparency - want) >= MIN_WRITE then
				p.Transparency = want
			end
		else
			local b = row.beam :: Beam
			local bucket = math.clamp(math.floor(want * BEAM_STEPS + 0.5),
				0, BEAM_STEPS)
			if bucket ~= row.bucket then
				row.bucket = bucket
				b.Transparency = BEAM_SEQ[bucket + 1]
			end
		end
	end
end

function BoltFX.start()
	if started then
		return
	end
	started = true

	for _, inst in CollectionService:GetTagged(BoltFX.TAG) do
		register(inst)
	end
	CollectionService:GetInstanceAddedSignal(BoltFX.TAG):Connect(register)

	-- **A BOUNDED RESCAN, BECAUSE `GetInstanceAddedSignal` CANNOT SEE A TAG
	-- THAT ARRIVED ALREADY SET.** That signal reports a tag being ADDED on THIS
	-- peer, and a tag the server set before parenting never is -- so anything
	-- built during server startup is invisible to it, and `GetTagged` returns
	-- nothing because the pig has not replicated yet. The shop doors shipped
	-- broken on exactly this ("wired 0 doors at startup"), and `HouseFX` had
	-- the same latent bug and got away with it only because a house light show
	-- is built late.
	--
	-- A piggy is built at server startup, so this one would NOT get away with
	-- it. `register` returns early for anything it has seen, so a rescan is
	-- idempotent and costs one table walk.
	task.spawn(function()
		for _ = 1, 20 do
			task.wait(0.5)
			for _, inst in CollectionService:GetTagged(BoltFX.TAG) do
				register(inst)
			end
		end
	end)

	RunService.Heartbeat:Connect(step)
end

--[[
	How many groups are being driven and how fast each one runs. Exposed so a
	probe can answer "is this animating" with a NUMBER rather than a photograph
	-- a bolt at transparency 1 and a bolt that was never registered look
	identical in any screenshot, which is the failure this project records for
	six always-on-top systems nobody ever looked at.
]]
function BoltFX.debug(): (number, number, number)
	local rate = if phaseCount > 0
		then math.min(MAX_PER_ELEMENT, MAX_AGGREGATE / phaseCount)
		else 0
	return #tracked, phaseCount, rate
end

return BoltFX
