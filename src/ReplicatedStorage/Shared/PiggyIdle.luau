--!strict
--[[
	PiggyIdle

	A piggy on a pedestal BREATHES, and when somebody banks its coins it hops,
	shimmies and oinks.

	-------------------------------------------------------------------
	THE FIRST VERSION FLOATED, AND THE FAULT WAS THE CURVE.
	-------------------------------------------------------------------

	It was a sine on the lift and a sine on the roll, and it was reported --
	correctly -- as *"the piggies have 0 gravity rather than being alive"*.
	That is a literal description of what a sine IS: perfectly symmetric, the
	same speed up as down, smooth acceleration everywhere, at rest nowhere.
	Nothing with mass moves like that, and turning the amplitude up makes it a
	BIGGER float -- which is why that was a rewrite rather than a retune.

	What carries weight instead: **asymmetry** (a hop crouches, snaps, hangs,
	and falls faster than it rose), **stillness** (breathing is the only thing
	it does unprompted), and **squash and stretch**, the strongest cue for
	mass in cartoon animation.

	-------------------------------------------------------------------
	THE MOTION IS A REACTION NOW, NOT A HABIT (designer, this session).
	-------------------------------------------------------------------

	The first build hopped on a random timer. That is a mechanism deciding to
	move for no reason a player can see, which is the same complaint as the
	float one level up: it is motion with no cause. A hop that fires WHEN THE
	PAD IS STEPPED ON is the piggy answering something, and the difference
	costs nothing -- the scheduler came out and a signal went in.

	**THE SIGNAL IS A COLLECT COUNTER ON THE PAD, AND IT USED TO BE THE PAD'S
	OWN SOUND -- WHICH WAS WRONG IN A WAY EVERY PROBE PASSED.** The first
	build hopped off `Sound.Played` on `CollectPad.PadCollect`, on the
	argument that a server `Play()` replicates and so needs no remote and no
	attribute. It replicates a PROPERTY, `Playing`, and `Played` on a client
	is the false -> true edge of it. The server plays the clip on every
	collect, the clip is 4.1s, so any collect inside the previous one changed
	nothing that replicates and the client hopped ONCE and then never while
	the player kept crossing. Measured live: server plays at t, t+1, t+6
	arrived as two `Played`s. Reported as the hop "only firing after 30+
	seconds" -- pacing over the pad kept restarting the server's clip.

	`PiggyPedestal.playPadCollect` increments `PiggyPedestal.COLLECT_ATTRIBUTE`
	on the pad, and this module hops AND restarts the sound locally off that
	change -- a counter, never a flag, because a boolean set true twice fires
	one signal. It still cannot drift from the thing it reacts to: the counter
	is written in the one function that plays the sound.

	-------------------------------------------------------------------
	WHY THIS IS NOT A BLENDER SKELETAL ANIMATION, MEASURED TWICE.
	-------------------------------------------------------------------

	Two independent reasons, either one sufficient:

	* **THERE IS NOTHING TO RIG.** Measured on a live pedestal, a dressed
	  display is FOUR parts: `Body`, one merged `Trim`, and two `Eye`s. The
	  ears, snout, tail and legs are a single welded mesh -- so there is no
	  ear to flap and no tail to wag, whatever an armature says.
	* **A RUNTIME MESH DOES NOT DEFORM.** `PiggyModel` builds through
	  `InsertService:CreateMeshPartAsync`, and this project has measured that
	  such a MeshPart does not deform under Bone instances rebuilt at runtime
	  -- a 35-degree bone turn moved nothing, photographed twice. That is why
	  the four legendaries' idle sway is RIGID PARTS rather than skinning.

	**WHAT BLENDER IS STILL GOOD FOR IS THE CURVE.** A clip here is a list of
	sampled frames -- time, lift, scale, roll -- which is exactly what a bake
	out of a graph editor produces. Replacing a hand-authored `frames` table
	with a baked one changes no code.

	-------------------------------------------------------------------
	SQUASH IS ABOUT THE FOOT, NOT THE PIVOT.
	-------------------------------------------------------------------

	`PiggyModel`'s pivot is the mini's BODY CENTRE. Scaling about that sinks
	the feet into the plinth on a squash and lifts them off it on a stretch --
	the animal would breathe through the thing it stands on. Everything here
	scales and rolls about the FOOT PLANE, captured once from the model's own
	bounding box on the frame it is first seen.

	A bounding box is admissible for that ONE number despite this project's
	two recorded bugs with it, for a specific reason: `GetBoundingBox` is
	oriented by the pivot, and `dress` seats a display with NO rotation at all
	now and never anything but a yaw before that -- and a yaw cannot transpose
	the Y extent. Anything that ever TILTS a pedestal breaks that and this has
	to be re-derived.

	**THE EYES KEEP THEIR SHAPE.** They are carried by the scale -- they move
	with the face -- but their own `Size` is never written: a distorted
	eyeball reads as a fault where a squashed body reads as weight.

	-------------------------------------------------------------------
	THE RULES IT KEEPS
	-------------------------------------------------------------------

	* **IT MAY NOT SPIN.** `dress` turns every piggy inward by a QUARTER --
	  `Config.piggyPadYaw`, the same yaw its own collect pad takes, which is
	  +90 on the viewer's right column and 270 on the left. A turntable is
	  that decision thrown away, and the decision has a measurement behind
	  it: seated on the TRUE bearing to the till (`Config.piggyPedestalYaw`,
	  now only the quantiser's input) four of the six stood askew on their own
	  square plinths by up to 26 degrees. Note the STAND under it faces the
	  street instead (`PiggyPedestal`'s `ART_TURN`): two objects on one spot,
	  two facings, and nothing here touches either.
	* **FOUND BY NAME, NEVER BY TAG.** A tag the server sets before parenting
	  never fires `GetInstanceAddedSignal` on the peer it replicates to -- the
	  shop-door failure, where four doors wired zero prompts at startup.
	* **THE NAME LABEL DOES NOT MOVE.** `dress` adorns `PiggyName` to the
	  PLINTH, so the text stays steady while the animal moves under it.
	* **NOTHING ACCUMULATES.** Every pose is authored against the rest pose
	  and rest sizes captured on first sight, so a server running for a week
	  cannot drift a piggy off its own plinth.
	* **CULLED BY CAMERA DISTANCE.** `PivotTo` plus a `Size` write per part is
	  not free across sixty pedestals, and a breath at the far end of the
	  street is not a thing anybody can see. The oink is NOT culled the same
	  way -- it is a positional Sound and the engine's own rolloff owns that.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- FOR ONE NUMBER: how long the collect reaction runs. It lives in `Config`
-- rather than here because the PAD has to know it too -- the button may not
-- fire again while the reaction it caused is still playing, and its face
-- reports that window in colour. See `Config.PIGGY_PEDESTAL.pad.cooldown`.
local Config = require(ReplicatedStorage.Shared.Config)
-- For `COLLECT_ATTRIBUTE` alone: the name is written by the one function that
-- plays the pad sound and read here, and a second literal would be the
-- `"LockLevel"` bug -- an attribute is an interface with no compiler behind
-- it. `PiggyPedestal` requires Config, PiggyModel and Theme and nothing that
-- requires this, so there is no cycle.
local PiggyPedestal = require(ReplicatedStorage.Shared.PiggyPedestal)

local PiggyIdle = {}

-- The names this module is coupled to. Stated as constants so the coupling
-- greps: an instance name is an interface with no compiler behind it, which
-- is the lesson `"LockLevel"` cost four call sites to learn.
local DISPLAY_NAME = "Display"
-- BOTH BUILDERS, BECAUSE THERE ARE TWO AND ONLY ONE WAS EVER MATCHED.
-- `PiggyPedestal.build` names a lawn plinth `PiggyPedestal_<slot>` and
-- `IndoorPedestal.build` names a hall placement `IndoorPedestal_<slot>`, and
-- the two produce the SAME `PiggyPedestal.Refs` on different geometry. This
-- module matched the first prefix only, so every piggy in a player's own
-- hallway stood dead still and its collect made no sound -- not because
-- anything failed, but because the reaction was never wired to it.
local PEDESTAL_PREFIXES = { "PiggyPedestal_", "IndoorPedestal_" }
local PAD_NAME = "CollectPad"
local PAD_SOUND_NAME = "PadCollect"
local EYE_NAME = "Eye"
local BODY_NAME = "Body"

local RANGE = 120

-- THE OINK. Pro Sound Effects, "Pig, Individual Pig Grunts and Squeals",
-- measured at 0.26s in a running game -- short enough to be a punctuation
-- mark on a collect rather than a performance.
--
-- CHOSEN FROM THE LICENSED LIBRARY RATHER THAN FROM A KEYWORD SEARCH. The
-- Creator Store's free audio is largely lifted from other games -- "free"
-- there means costing no Robux, not cleared -- and a strike moderates the
-- asset away and leaves the game silent afterwards. The same search returned
-- Pro Sound Effects' "Beast-Like Screams" pigs, which load and are exactly
-- wrong for an audience of nine-year-olds.
--
-- WHAT IS NOT VERIFIED IS HOW IT SOUNDS. Nothing in this toolchain can hear;
-- it is confirmed to LOAD and to be 0.26s. Somebody has to put headphones on,
-- and the nearby alternates are 9117344730 (2.3s, sparse snorts) and
-- 9117367644 (2.2s, shriller).
local OINK_ID = "rbxassetid://9117363151"
local OINK_VOLUME = 0.42
-- Pitched up a little because a real pig is lower than a cartoon one, and
-- jittered per play so that six pedestals on one lawn are not one pig.
local OINK_PITCH, OINK_JITTER = 1.14, 0.09
-- Heard across a lawn, not across the street. The ride sounds record why this
-- pair matters: everything inside `RollOffMinDistance` hears the raw volume.
local OINK_MIN, OINK_MAX = 8, 70

-- ------------------------------------------------------------
-- CLIPS
-- ------------------------------------------------------------
--
-- A frame is `{ t, y, sx, sy, sz, roll }`: normalised time, lift in studs,
-- the three scale factors about the foot, and roll in degrees.
--
-- INTERPOLATION IS LINEAR BETWEEN FRAMES ON PURPOSE. A spline would round off
-- exactly the corners that carry the weight -- the snap at launch and the
-- stop at landing are DISCONTINUITIES in velocity, and that is what a landing
-- is. Keys sit close together where the motion is fast, which is how a bake
-- behaves anyway.

export type Frame = { t: number, y: number, sx: number, sy: number, sz: number, roll: number }
export type Clip = { name: string, length: number, frames: { Frame } }

local function f(t: number, y: number, sx: number, sy: number, sz: number, roll: number): Frame
	return { t = t, y = y, sx = sx, sy = sy, sz = sz, roll = roll }
end

-- THE BREATH -- the only thing a piggy does unprompted. Scale only: no lift
-- and no roll, because a resting animal does not leave the ground and a prop
-- that drifts is the floating this module was rewritten to stop. Small enough
-- that it does not read as motion so much as it stops the thing reading as a
-- statue.
local BREATHE: Clip = {
	name = "breathe",
	length = 3.6,
	frames = {
		f(0.00, 0.000, 1.000, 1.000, 1.000, 0),
		f(0.30, 0.010, 0.992, 1.013, 0.992, 0),
		f(0.55, 0.006, 0.996, 1.006, 0.996, 0),
		f(1.00, 0.000, 1.000, 1.000, 1.000, 0),
	},
}

-- THE COLLECT REACTION: a hop, then a shimmy it settles out of. One clip
-- rather than two queued, because they are one performance -- and a queue
-- would be a second piece of state that can be interrupted half way.
--
-- Read the `t` column as the story. Frames up to 0.613 are the hop -- crouch,
-- snap, hang, drop, land hard, overshoot -- and the rest is the wobble
-- afterwards. The hang is deliberately longer than either the rise or the
-- fall, because hang time is what makes a jump read as a jump.
local CELEBRATE: Clip = {
	name = "celebrate",
	-- THE PAD'S OWN NUMBER, and the frames below are normalised 0..1 so they
	-- stretch to whatever it is. Three readers of one duration -- this clip,
	-- the pad's touch debounce and the pad's face -- and a second copy here is
	-- the near-identical duplicate that drifts: it WAS 1.55 against a
	-- 1.0-second cooldown, so a re-crossing at 1.2s restarted the performance
	-- 78% of the way through it.
	length = Config.PIGGY_PEDESTAL.pad.reaction,
	frames = {
		f(0.000, 0.00, 1.000, 1.000, 1.000, 0.0),
		-- Anticipation. It gathers; nothing leaves the plinth yet.
		f(0.086, 0.00, 1.070, 0.880, 1.070, 0.0),
		f(0.123, -0.02, 1.090, 0.850, 1.090, 0.0),
		-- The snap, stretched thin and already most of the way up.
		f(0.166, 0.34, 0.920, 1.170, 0.920, 0.0),
		f(0.208, 0.52, 0.960, 1.080, 0.960, 0.0),
		-- The hang, briefly weightless and round again.
		f(0.257, 0.58, 1.000, 1.000, 1.000, 0.0),
		f(0.307, 0.55, 1.000, 1.000, 1.000, 0.0),
		-- The fall, faster than the rise.
		f(0.368, 0.30, 0.960, 1.080, 0.960, 0.0),
		f(0.405, 0.00, 0.930, 1.130, 0.930, 0.0),
		-- Impact.
		f(0.429, 0.00, 1.150, 0.810, 1.150, 0.0),
		-- Recovery, with one overshoot so it settles rather than stopping.
		f(0.490, 0.02, 0.970, 1.060, 0.970, 0.0),
		f(0.546, 0.00, 1.020, 0.975, 1.020, 0.0),
		f(0.613, 0.00, 1.000, 1.000, 1.000, 0.0),
		-- The shimmy, damping out.
		--
		-- IT RISES AS IT TILTS, AND THAT IS GEOMETRY RATHER THAN STYLE. A roll
		-- about the foot swings a bottom corner DOWN by roughly the body's
		-- half-width times sin(roll) -- measured at 0.23 studs for six degrees
		-- on this mini, which cleared the plinth by 0.017 and nothing else.
		-- That margin was borrowed from a seating gap in `dress` that puts a
		-- display 0.25 studs above its own plinth, i.e. from a bug: fix the
		-- seating and this starts cutting through the plinth, with nothing
		-- here having changed.
		--
		-- So each key lifts by about |roll| / 90, which is what a rocking
		-- object actually does -- it stands up on its edge. The clearance is
		-- then the clip's own rather than a loan from somewhere else.
		f(0.659, 0.066, 1.030, 0.965, 1.030, -6.0),
		f(0.729, 0.055, 1.000, 1.000, 1.000, 5.0),
		f(0.799, 0.040, 1.020, 0.980, 1.020, -3.6),
		f(0.868, 0.023, 1.000, 1.000, 1.000, 2.1),
		f(0.938, 0.010, 1.000, 1.000, 1.000, -0.9),
		f(1.000, 0.000, 1.000, 1.000, 1.000, 0.0),
	},
}

local function sample(clip: Clip, u: number): (number, Vector3, number)
	local frames = clip.frames
	if u <= 0 then
		local a = frames[1]
		return a.y, Vector3.new(a.sx, a.sy, a.sz), a.roll
	end
	for i = 1, #frames - 1 do
		local a, b = frames[i], frames[i + 1]
		if u <= b.t then
			local span = b.t - a.t
			local k = if span > 0 then (u - a.t) / span else 0
			return a.y + (b.y - a.y) * k,
				Vector3.new(a.sx + (b.sx - a.sx) * k,
					a.sy + (b.sy - a.sy) * k,
					a.sz + (b.sz - a.sz) * k),
				a.roll + (b.roll - a.roll) * k
		end
	end
	local z = frames[#frames]
	return z.y, Vector3.new(z.sx, z.sy, z.sz), z.roll
end

-- ------------------------------------------------------------
-- REGISTRY
-- ------------------------------------------------------------

type Piece = { part: BasePart, size: Vector3, cf: CFrame, eye: boolean }
type Entry = {
	home: CFrame,
	footY: number,
	pieces: { Piece },
	oink: Sound?,
	clip: Clip,
	-- WHEN THIS CLIP BEGAN, and a piggy's breathing offset is baked into it
	-- at registration rather than carried as a second term. It WAS a separate
	-- `drift` added to every clip for one revision, and that is a bug with a
	-- measurement attached: celebrate reset `started` and not `drift`, so a
	-- piggy holding 2.0s of offset ran a 1.55s hop straight past its own end
	-- and back to the breath -- 0.112 studs of travel against the 1.4 the
	-- clip asks for, with nothing erroring. One field cannot fall out of step
	-- with itself.
	started: number,
}

-- NOT weak tables. Lua's collector cannot see the DataModel's reference to an
-- Instance -- that lives in C++ -- so a live model held weakly is dropped on
-- the next collection and re-registered at a NEW rest pose read off a body
-- that is mid-hop. `RidePose` records that exact failure.
local live: { [Model]: Entry } = {}
-- Pedestals whose pad sound is already listened to. A pedestal outlives every
-- display that stands on it -- `dress` rebuilds the display and never the pad
-- -- so this is connected once per pedestal for the life of the server, which
-- is the same call `EconomyService` makes about wiring the pad itself.
local wired: { [Instance]: boolean } = {}
-- Pedestals with a thread already waiting on their pad. See `wirePedestal`:
-- this is the difference between "somebody is on it" and "it is connected",
-- and the two cannot share a table without either double-connecting the
-- attribute signal or refusing the retry that makes the wait worth having.
local wiring: { [Instance]: boolean } = {}

-- Is this the name of a pedestal, by either builder?
--
-- ONE TEST, TWO READERS, BECAUSE SPLITTING IT COST THE WHOLE ANIMATION ONCE.
-- `PEDESTAL_PREFIX` was a single string read here and in `wirePedestal`;
-- turning it into a list updated the second reader and left this one pointing
-- at a name that no longer existed -- a nil global, so `#PEDESTAL_PREFIX`
-- threw on every sweep, `isDisplay` never returned, and NO piggy anywhere
-- registered: the lawn lost its idle for a change that was only ever about
-- the hall. An interface with no compiler behind it, exactly as `"LockLevel"`
-- cost four call sites, and the fix is the same -- one function both sides
-- call rather than one constant both sides spell.
local function isPedestalName(name: string): boolean
	for _, prefix in ipairs(PEDESTAL_PREFIXES) do
		if name:sub(1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local function isDisplay(inst: Instance): boolean
	if not inst:IsA("Model") or inst.Name ~= DISPLAY_NAME then
		return false
	end
	local parent = inst.Parent
	return parent ~= nil and isPedestalName(parent.Name)
end

local function forget(model: Model)
	local e = live[model]
	if e and e.oink then
		e.oink:Destroy()
	end
	live[model] = nil
end

-- Builds the entry from a display whose parts have ALL arrived. Never called
-- straight off `DescendantAdded`; see `register` below for why.
local function registerNow(model: Model)
	if live[model] or not model.Parent then
		return
	end

	local home = model:GetPivot()
	local box, size = model:GetBoundingBox()
	local footY = home:PointToObjectSpace(box.Position).Y - size.Y / 2

	local pieces: { Piece } = {}
	local body: BasePart? = nil
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(pieces, {
				part = d,
				size = d.Size,
				cf = home:ToObjectSpace(d.CFrame),
				eye = d.Name == EYE_NAME,
			})
			if d.Name == BODY_NAME then
				body = d
			end
		end
	end
	if #pieces == 0 then
		return
	end

	-- THE OINK IS BUILT ON THIS CLIENT, which is what makes it free: every
	-- client runs this module and every client sees the pad sound replicate,
	-- so each one plays its own copy and the whole street hears it without a
	-- remote. It hangs off the BODY so it is positional at the animal rather
	-- than at the plot.
	local oink: Sound? = nil
	if body then
		local s = Instance.new("Sound")
		s.Name = "Oink"
		s.SoundId = OINK_ID
		s.Volume = OINK_VOLUME
		s.RollOffMinDistance = OINK_MIN
		s.RollOffMaxDistance = OINK_MAX
		s.Parent = body
		oink = s
	end

	live[model] = {
		home = home,
		footY = footY,
		pieces = pieces,
		oink = oink,
		clip = BREATHE,
		-- Started somewhere in the middle of a breath, so six on a lawn are
		-- not one lung.
		started = Workspace:GetServerTimeNow() - math.random() * BREATHE.length,
	}
	model.Destroying:Once(function()
		forget(model)
	end)
end

-- A REPLICATED MODEL ARRIVES BEFORE ITS CHILDREN, and this animator registered
-- a display the instant the Model replicated -- so a piggy PLACED after the
-- client's first ten seconds arrived with zero parts, `registerNow` returned
-- on `#pieces == 0`, and nothing ever came back for it: no breathing, no hop
-- when its pad was pressed. The boot-time displays worked only because the
-- twenty half-second re-sweeps caught them once their parts had landed, which
-- is exactly the window a piggy placed at minute five is outside. Same trap
-- CLAUDE.md records for the mini skin animator, and the same fix: wait for the
-- body, then for the part count to stop moving, then register once.
local pending: { [Model]: boolean } = {}

local function register(inst: Instance)
	if not isDisplay(inst) then
		return
	end
	local model = inst :: Model
	if live[model] or pending[model] then
		return
	end
	pending[model] = true
	task.spawn(function()
		local body = model:WaitForChild(BODY_NAME, 10)
		if body then
			-- Settled means three consecutive reads of the same descendant
			-- count: a display's parts land within a frame or two of each
			-- other, and a second's ceiling keeps a stalled replication from
			-- pinning the thread.
			local last, stable = -1, 0
			for _ = 1, 30 do
				local n = #model:GetDescendants()
				if n == last then
					stable += 1
				else
					stable = 0
				end
				if stable >= 3 then
					break
				end
				last = n
				task.wait(0.05)
			end
		end
		pending[model] = nil
		registerNow(model)
	end)
end

-- Fire the collect reaction on whatever is standing on this pedestal.
local function celebrate(pedestal: Instance)
	local display = pedestal:FindFirstChild(DISPLAY_NAME)
	if not display then
		return
	end
	local e = live[display :: Model]
	if not e then
		return
	end
	-- RESTARTED RATHER THAN QUEUED. Banking twice in quick succession is two
	-- reactions to two events, and a queue would make the second one arrive
	-- late -- after the moment it was about.
	--
	-- AND THE PAD CAN NO LONGER PRODUCE THE SECOND EVENT INSIDE THE FIRST
	-- CLIP, so on that path this branch is unreachable rather than wrong:
	-- `pad.cooldown` IS `pad.reaction` now, and the button reads red for the
	-- length of the performance. This stays because it is still the right
	-- answer for any second caller, and because the restart was measured to
	-- cut a shimmy off mid-swing when the two numbers disagreed.
	e.clip = CELEBRATE
	e.started = Workspace:GetServerTimeNow()
	local oink = e.oink
	if oink then
		oink.PlaybackSpeed = OINK_PITCH + (math.random() * 2 - 1) * OINK_JITTER
		oink:Play()
	end
end

local function wirePedestal(inst: Instance)
	if wired[inst] or not inst:IsA("Model") then
		return
	end
	if not isPedestalName(inst.Name) then
		return
	end
	-- WAITED FOR, NOT LOOKED UP, WHICH IS `register`'S OWN SHAPE ONE OBJECT
	-- ALONG. A Model replicates before its children do, so a pedestal that
	-- arrives through `DescendantAdded` can be here with its `CollectPad` and
	-- that pad's Sound still in flight. This read them synchronously and
	-- returned on the miss WITHOUT stamping `wired`, so nothing marked it
	-- attempted and nothing came back: `DescendantAdded` does fire again when
	-- the pad and the sound land, but those are named `CollectPad` and
	-- `PadCollect` rather than a pedestal prefix, so they return at the test
	-- above and the pedestal is never revisited. No collect sound and no
	-- celebrate, for the life of the session.
	--
	-- AND IT POINTS AT THE HALL RATHER THAN THE LAWN, which is why it survived
	-- being invisible. The startup sweep catches anything already standing --
	-- the lawn, built before a client is listening -- and the bounded rescan
	-- covers the first ten seconds. A hallway is built when somebody walks
	-- through their own front door, which is minutes later and through
	-- `DescendantAdded` with its children behind it: exactly the case the two
	-- roots above were added for.
	--
	-- `wiring` RATHER THAN `wired`, because they answer different questions --
	-- one thread is already waiting on this, against this one is connected --
	-- and collapsing them would either double-connect the attribute signal or
	-- refuse the retry.
	if wiring[inst] then
		return
	end
	wiring[inst] = true
	task.spawn(function()
		local pad = inst:WaitForChild(PAD_NAME, 10)
		local sound = pad and pad:WaitForChild(PAD_SOUND_NAME, 10)
		wiring[inst] = nil
		if not pad or not sound or not sound:IsA("Sound") then
			return
		end
		-- Re-checked after the wait: ten seconds is long enough for the
		-- pedestal to have been destroyed (a plot re-locking takes its
		-- placement with it) or for a rescan to have got there first.
		if wired[inst] or not inst.Parent then
			return
		end
		wired[inst] = true
		-- OFF THE PAD'S COLLECT COUNTER, NOT `sound.Played`. `Played` is an
		-- edge on `Playing`, and a server `Play()` on a clip still running has
		-- no edge to replicate -- so every collect inside the previous clip's
		-- 4.1s was invisible here. See `PiggyPedestal.COLLECT_ATTRIBUTE`. The
		-- sound is restarted locally for the same reason: the replicated play
		-- cannot restart a clip this client is already playing.
		pad:GetAttributeChangedSignal(PiggyPedestal.COLLECT_ATTRIBUTE):Connect(function()
			sound:Play()
			celebrate(inst)
		end)
	end)
end

-- ------------------------------------------------------------
-- POSING
-- ------------------------------------------------------------

local function pose(e: Entry, y: number, k: Vector3, rollDeg: number)
	local foot = e.footY
	-- Roll about the foot, then lift. Composed in the model's own rest frame,
	-- so the far row's half turn -- already carried by `home` -- comes along
	-- for free and no `lookAt` correction is needed.
	local motion = CFrame.new(0, foot + y, 0)
		* CFrame.Angles(0, 0, math.rad(rollDeg))
		* CFrame.new(0, -foot, 0)

	for _, piece in ipairs(e.pieces) do
		local p = piece.cf.Position
		local scaled = Vector3.new(p.X * k.X, foot + (p.Y - foot) * k.Y, p.Z * k.Z)
		piece.part.CFrame = e.home * motion * (CFrame.new(scaled) * (piece.cf - p))
		if not piece.eye then
			piece.part.Size = piece.size * k
		end
	end
end

function PiggyIdle.start()
	if not RunService:IsClient() then
		return
	end

	-- TWO ROOTS, BECAUSE THERE ARE TWO PLACES A PIGGY STANDS. The lawn's six
	-- plinths are under `workspace.Plots`; a player's own hallway is a
	-- separate folder, `workspace.Interiors`, built when they walk through
	-- their front door. This scanned `Plots` alone, so nothing in a hallway
	-- ever entered `live` -- which is why an indoor piggy neither breathed nor
	-- reacted to its own collect. The server was already doing its half:
	-- `PlotService.playCollect` is slot-based and `pedestalAt` finds an indoor
	-- placement, so the sound and the `COLLECT_ATTRIBUTE` bump were firing
	-- into a client that was not listening.
	--
	-- FOUND RATHER THAN WAITED FOR, AND BOTH ARE OPTIONAL. `Interiors` exists
	-- from boot but is EMPTY until somebody goes inside, and a client can load
	-- before either folder does -- which is what the bounded rescan below is
	-- for. Falling back to `Workspace` when neither exists keeps this module
	-- working in a test place that has no plots at all.
	local roots: { [Instance]: boolean } = {}

	-- ADOPTED RATHER THAN LISTED ONCE, because a folder can arrive after this
	-- runs. A client that loads early may see neither, and the rescan below is
	-- what picks them up -- so the connection is made when the folder is first
	-- SEEN rather than at `start`, and adopting twice is a no-op.
	local function adopt(root: Instance)
		if roots[root] then
			return
		end
		roots[root] = true
		for _, inst in ipairs(root:GetDescendants()) do
			register(inst)
			wirePedestal(inst)
		end
		root.DescendantAdded:Connect(function(inst)
			register(inst)
			wirePedestal(inst)
		end)
	end

	local function sweep()
		local found = false
		for _, name in ipairs({ "Plots", "Interiors" }) do
			local folder = Workspace:FindFirstChild(name)
			if folder then
				found = true
				adopt(folder)
			end
		end
		-- Only as a last resort, and only while neither folder exists: adopting
		-- the whole Workspace once `Plots` is there would walk the street, the
		-- scenery and every tuft on every rescan.
		if not found then
			adopt(Workspace)
		end
		for root in pairs(roots) do
			for _, inst in ipairs(root:GetDescendants()) do
				register(inst)
				wirePedestal(inst)
			end
		end
	end

	sweep()

	-- A BOUNDED RESCAN, for the reason `HouseFX` and `BoltFX` both carry one.
	-- `DescendantAdded` fires only for what arrives AFTER it connects, and a
	-- client that loads while `PlotService` is still building its plots misses
	-- whatever landed in between -- the shop-door failure exactly: present,
	-- correct and dead, and only reachable at startup. Both `register` and
	-- `wirePedestal` return early for anything already seen, so a rescan is
	-- idempotent and costs one tree walk.
	task.spawn(function()
		for _ = 1, 20 do
			task.wait(0.5)
			sweep()
		end
	end)

	RunService.Heartbeat:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local eye = camera.CFrame.Position
		local now = Workspace:GetServerTimeNow()

		for model, e in pairs(live) do
			-- Dropped here as well as on `Destroying`: a model reparented out
			-- rather than destroyed never fires that signal.
			if not model.Parent then
				forget(model)
				continue
			end
			if (e.home.Position - eye).Magnitude <= RANGE then
				local u = (now - e.started) / e.clip.length
				if u >= 1 then
					-- A reaction plays ONCE and hands back to the breath; the
					-- breath loops. Both land here, which is why there is no
					-- per-clip flag saying which does what.
					e.clip = BREATHE
					e.started = now
					u = 0
				end
				local y, k, roll = sample(e.clip, u)
				pose(e, y, k, roll)
			end
		end
	end)
end

return PiggyIdle
