--!strict
--[[
	HouseFX

	The light show on the top house tiers: colour cycles, chases, pulses and
	the few things that actually move.

	WHY NEON AND NOT LIGHTS. This game has no night. `WorldService` sets
	`ClockTime` to 14.5 exactly once and nothing ever changes it, so the note
	in Config claiming the endgame tiers "light up at night so they read in
	the dark too" describes a state the game never enters. At Brightness 2.4
	in full sun a PointLight at brightness 0.9 over an 18-stud range is
	invisible from the street, which is why four lanterns were the entire
	lighting budget of the endgame ladder and why it read as vanilla.

	Neon is the one material that ignores the scene entirely: it renders at
	full saturation in daylight, and `WorldService` already runs a BloomEffect
	at threshold 1.1 that makes it bloom for free. So every effect in here is
	a COLOUR WRITE ON AN EMISSIVE PART, and the handful of real lights that
	remain are garnish rather than the mechanism.

	It is also the only choice that survives the shop. A ViewportFrame renders
	BaseParts and nothing else -- no particles, no beams, no lights, measured
	rather than assumed -- so a light show built out of emitters would be
	invisible on the card selling a hundred-million-coin house. Built out of
	neon geometry it renders on the tile exactly as it does on the lawn, and
	the shop tiles join this animator by tag with no second implementation.

	CLIENT-SIDE, for the reason the animated skins and the moat are.

	This is a colour write per emissive part per frame. Driven from the server
	that is a REPLICATED write per part per frame -- twelve plots of forty
	parts is around twenty-nine thousand property updates a second to say
	something every machine can work out from a clock and an attribute. The
	server builds the geometry and tags it; each client animates what it can
	see.

	THREE FLASHES A SECOND IS THE CEILING, AND EVERYTHING HERE IS FAR UNDER IT.
	The accessibility standard treats a flash as a 10% luminance change over
	20% of the screen, and more than three a second as unsafe. This audience is
	nine. So there is no strobe anywhere in this file: every effect is a
	continuous curve, `MAX_RATE` clamps how fast any of them can be asked to
	run, and the one effect that genuinely blinks (`beacon`) sweeps like a
	lighthouse rather than switching.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HouseFX = {}

-- The tag every animated part carries. One tag, and the part's own attributes
-- say what it should do -- rather than a tag per effect, which would mean a
-- listener per effect and a part that can only ever have one.
HouseFX.TAG = "HouseFX"

-- Cycles per second, hard ceiling. See the photosensitivity note above: this
-- is the number that makes "no strobe" a property of the file rather than a
-- promise about how carefully each tier was authored.
local MAX_RATE = 0.9

-- Past this the effects are switched off entirely. The houses stand 70 studs
-- behind their own piggies and the street is about 420 long, so 520 keeps
-- every house anybody can actually see while dropping the eleven behind the
-- camera. Cheap, and it is the only thing here that scales with plot count.
local CULL = 520

type Entry = {
	part: BasePart,
	fx: string,
	phase: number,
	rate: number,
	hue: number,
	sat: number,
	span: number,
	dim: number,
	-- Motion effects only. `rest` is the part's pose RELATIVE TO ITS MODEL,
	-- never its world CFrame: a shop tile's house is pivoted into place by
	-- `makeModelIcon` and spun on the spot afterwards, so a remembered world
	-- pose would be stale the moment the tile was framed and the halo would
	-- orbit a point out in the panel somewhere.
	model: Model?,
	rest: CFrame?,
	-- `scale` and `sway` need the part's authored SIZE as well as its pose:
	-- one animates the size itself and the other hinges at the top face,
	-- which is half a height above the centre. Read once, like the pose --
	-- re-reading a size this frame that was written last frame accumulates.
	restSize: Vector3?,
	amount: number,
	axis: Vector3,
	-- `swim` only: the point its whole fish turns about, in the PART'S OWN
	-- space. See the `swim` branch.
	centre: Vector3?,
}

local entries: { Entry } = {}
local byPart: { [BasePart]: Entry } = {}
local started = false

local function num(part: BasePart, key: string, fallback: number): number
	local v = part:GetAttribute(key)
	return if type(v) == "number" then v else fallback
end

local function register(inst: Instance)
	if not inst:IsA("BasePart") or byPart[inst] then
		return
	end

	local fx = inst:GetAttribute("FX")
	if type(fx) ~= "string" then
		return
	end

	-- Read once, at registration. These never change for the life of a part --
	-- a house is rebuilt rather than retuned -- and reading six attributes per
	-- part per frame is the kind of cost that only shows up at twelve plots.
	local entry: Entry = {
		part = inst,
		fx = fx,
		phase = num(inst, "Phase", 0),
		rate = math.min(num(inst, "Rate", 0.35), MAX_RATE),
		hue = num(inst, "Hue", 0),
		sat = num(inst, "Sat", 0.85),
		span = num(inst, "Span", 0.35),
		dim = num(inst, "Dim", 0.25),
		model = inst:FindFirstAncestorOfClass("Model"),
		rest = nil,
		amount = num(inst, "Amount", 1),
		axis = Vector3.new(num(inst, "AxisX", 0), num(inst, "AxisY", 1), num(inst, "AxisZ", 0)),
	}

	if fx == "swim" then
		entry.centre = Vector3.new(num(inst, "CentreX", 0), num(inst, "CentreY", 0), num(inst, "CentreZ", 0))
	end

	if fx == "spin" or fx == "orbit" or fx == "bob" or fx == "sway" or fx == "scale" or fx == "swim" then
		local model = entry.model
		if model then
			entry.rest = model:GetPivot():ToObjectSpace(inst.CFrame)
		end
		entry.restSize = inst.Size
	end

	table.insert(entries, entry)
	byPart[inst] = entry
end

local function forget(inst: Instance)
	local entry = byPart[inst :: BasePart]
	if not entry then
		return
	end
	byPart[inst :: BasePart] = nil
	for i, e in ipairs(entries) do
		if e == entry then
			table.remove(entries, i)
			break
		end
	end
end

-- A triangle wave over 0..1 that peaks at `at` and falls to zero `span`
-- either side of it, wrapping at both ends.
--
-- This is what makes a chase read as one travelling band rather than as a row
-- of parts taking turns: the wrap is why a light running up a six-storey
-- tower leaves the top and reappears at the bottom instead of stopping dead.
local function band(t: number, at: number, span: number): number
	local d = math.abs(((t - at + 0.5) % 1) - 0.5)
	if d >= span then
		return 0
	end
	return 1 - d / span
end

local function apply(entry: Entry, clock: number, pivots: { [Model]: CFrame })
	local p = entry.part
	local fx = entry.fx
	local t = clock * entry.rate + entry.phase

	if fx == "cycle" then
		-- Straight through the spectrum. The loudest thing available at a
		-- hundred studs, because it changes even when nothing is moving.
		p.Color = Color3.fromHSV((entry.hue + t) % 1, entry.sat, 1)

	elseif fx == "chase" then
		-- One bright band travelling along a run of parts, each carrying its
		-- own `Phase` for where it sits in the run. Value rather than hue, so
		-- a gold palace chases in gold instead of turning into a rainbow.
		local lit = band(t, entry.phase, entry.span)
		p.Color = Color3.fromHSV(entry.hue, entry.sat, entry.dim + (1 - entry.dim) * lit)

	elseif fx == "pulse" then
		-- Breathing. A cosine rather than a sine so a phase of zero starts at
		-- full brightness, which is what a tier looks like in a screenshot.
		local v = (math.cos(t * math.pi * 2) + 1) / 2
		p.Color = Color3.fromHSV(entry.hue, entry.sat, entry.dim + (1 - entry.dim) * v)

	elseif fx == "sweep" then
		-- A narrow hue sweep rather than the whole wheel: a shimmer across
		-- gold or marble that stays the tier's own colour. `Amount` is how far
		-- around the wheel it is allowed to travel.
		local wobble = math.sin(t * math.pi * 2) * entry.amount
		p.Color = Color3.fromHSV((entry.hue + wobble) % 1, entry.sat, 1)

	elseif fx == "beacon" then
		-- A lighthouse, not a strobe. The brightness follows a raised cosine
		-- so it swells and fades rather than switching, which is both what a
		-- rotating lamp actually looks like and what keeps it off the wrong
		-- side of the flash guidance.
		local v = ((math.cos(t * math.pi * 2) + 1) / 2) ^ 3
		p.Color = Color3.fromHSV(entry.hue, entry.sat, entry.dim + (1 - entry.dim) * v)

	elseif fx == "sway" then
		-- A PENDULUM, HINGED AT THE TOP. The galleon's sail is authored with a
		-- hinge point, an axis and an amplitude of two degrees -- it hangs from
		-- a yard arm, so it swings about its top edge rather than its centre.
		--
		-- HINGED AT THE PART'S OWN TOP RATHER THAN THE AUTHORED POINT, which is
		-- a deliberate approximation and worth the measurement: converting the
		-- Blender hinge would mean carrying the import's own frame into this
		-- file, and at two degrees an error of `d` studs in the hinge moves the
		-- part by `d * sin(2deg)` -- about 0.035 studs per stud of error. On a
		-- sail a few studs tall that is under a tenth of a stud.
		local model, rest, size = entry.model, entry.rest, entry.restSize
		if not model or not rest or not size then
			return
		end
		local pivot = pivots[model]
		if not pivot then
			pivot = model:GetPivot()
			pivots[model] = pivot
		end
		local swing = math.sin(t * math.pi * 2) * math.rad(entry.amount)
		local top = CFrame.new(0, size.Y / 2, 0)
		p.CFrame = pivot * rest * top * CFrame.fromAxisAngle(entry.axis, swing) * top:Inverse()

	elseif fx == "scale" then
		-- STRETCHED DOWNWARD FROM ITS TOP, which is the whole of what the Gloop
		-- House asks for: "only scale hanging goo, anchored at its top". A drip
		-- that grew about its centre would lift off the roof it hangs from by
		-- half of whatever it gained.
		--
		-- `Amount` is the far end of the authored range (1.045), so the part
		-- breathes between its own size and that.
		local model, rest, size = entry.model, entry.rest, entry.restSize
		if not model or not rest or not size then
			return
		end
		local pivot = pivots[model]
		if not pivot then
			pivot = model:GetPivot()
			pivots[model] = pivot
		end
		local v = (math.cos(t * math.pi * 2) + 1) / 2
		local k = 1 + (entry.amount - 1) * v
		local grown = Vector3.new(size.X, size.Y * k, size.Z)
		p.Size = grown
		-- The top face is where it hangs from, so that point is held and the
		-- centre drops by half the new height.
		p.CFrame = pivot * rest * CFrame.new(0, size.Y / 2 - grown.Y / 2, 0)

	elseif fx == "swim" then
		-- A RIGID ORBIT, which `orbit` is not. `orbit` turns each part about a
		-- point along its OWN -Z, so two parts of one fish turn about two
		-- different centres and the fish comes apart as it goes round. Here
		-- every part of a fish carries the SAME point (stored in its own space,
		-- so it survives the house being seated or a shop tile re-pivoting it)
		-- and the same phase and rate, so the whole fish turns as one body
		-- about the model's up axis through that point, bobbing as it goes.
		-- A negative `Rate` swims the other way round.
		local model, rest, centre = entry.model, entry.rest, entry.centre
		if not model or not rest or not centre then
			return
		end
		local pivot = pivots[model]
		if not pivot then
			pivot = model:GetPivot()
			pivots[model] = pivot
		end
		local home = pivot * rest
		local about = home:PointToWorldSpace(centre)
		local up = pivot.UpVector
		local turn = CFrame.new(about) * CFrame.fromAxisAngle(up, t * math.pi * 2) * CFrame.new(-about)
		-- Four bobs a lap, all parts in step because they share `t`.
		p.CFrame = (turn * home) + up * (math.sin(t * math.pi * 8) * entry.amount)

	elseif fx == "spin" or fx == "orbit" or fx == "bob" then
		local model = entry.model
		local rest = entry.rest
		if not model or not rest then
			return
		end
		-- Cached per model per frame. `GetPivot` walks a model's parts, so
		-- calling it once per animated part would make a sixteen-rock ring
		-- sixteen traversals of the same castle.
		local pivot = pivots[model]
		if not pivot then
			pivot = model:GetPivot()
			pivots[model] = pivot
		end

		local turns = t * math.pi * 2
		if fx == "spin" then
			p.CFrame = pivot * rest * CFrame.fromAxisAngle(entry.axis, turns)

		elseif fx == "orbit" then
			-- ROTATED ABOUT A POINT `Amount` STUDS ALONG ITS OWN -Z, never
			-- about the model's pivot.
			--
			-- Orbiting the pivot is the obvious version and it is not
			-- reliable: a Model with no PrimaryPart takes its pivot from
			-- wherever `WorldPivot` happens to be, `House.build` moves the
			-- model twice while seating it, and `makeModelIcon` resets the
			-- pivot to identity at the visual centre for a shop tile. So the
			-- same ring would turn about three different points in three
			-- places, none of them chosen. Each part carrying its own radius
			-- makes the centre a fact about how the ring was AUTHORED, which
			-- is the only place it is actually known.
			local r = entry.amount
			p.CFrame = pivot * rest * CFrame.new(0, 0, -r)
				* CFrame.Angles(0, turns, 0) * CFrame.new(0, 0, r)

		else
			p.CFrame = pivot * rest * CFrame.new(0, math.sin(turns) * entry.amount, 0)
		end
	end
end

function HouseFX.start()
	if started then
		return
	end
	started = true

	-- A BOUNDED RESCAN, because a tag that arrives ALREADY SET does not fire
	-- GetInstanceAddedSignal on the peer it replicates to.
	--
	-- This file got away without one for as long as everything it animated
	-- was built LATE: a house light show only exists once somebody owns a top
	-- tier, which is always after the client is running, exactly as the moat
	-- is built when somebody buys a fifth fence. The shops broke that -- they
	-- are built during server startup, so `GetTagged` below returns nothing
	-- and the signal never fires for them either. Measured on the shop doors,
	-- which failed the identical way: "wired 0 doors at startup".
	--
	-- So the collect runs again for a few seconds. `register` already returns
	-- early for anything it has seen, so a rescan is idempotent and costs one
	-- table walk; after the window it stops entirely and the signal carries
	-- everything built from then on, which is the common case.
	task.spawn(function()
		for _ = 1, 20 do
			task.wait(0.5)
			for _, inst in ipairs(CollectionService:GetTagged(HouseFX.TAG)) do
				register(inst)
			end
		end
	end)

	for _, inst in ipairs(CollectionService:GetTagged(HouseFX.TAG)) do
		register(inst)
	end
	-- By signal rather than a single sweep at startup, because a house is
	-- rebuilt whenever somebody buys a tier or moves back into one, and a shop
	-- tile is built when the catalogue replicates -- both long after this runs.
	CollectionService:GetInstanceAddedSignal(HouseFX.TAG):Connect(register)
	CollectionService:GetInstanceRemovedSignal(HouseFX.TAG):Connect(forget)

	local pivots: { [Model]: CFrame } = {}

	RunService.Heartbeat:Connect(function()
		local clock = os.clock()
		local camera = Workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else Vector3.zero

		table.clear(pivots)

		for i = #entries, 1, -1 do
			local entry = entries[i]
			local p = entry.part
			-- A destroyed part still answers property reads, so a stale entry
			-- would animate a corpse forever rather than erroring. The tag's
			-- removed signal covers Destroy, but a house torn down by a
			-- rebirth is a whole model going at once and this is the cheap
			-- belt to that braces.
			if not p.Parent then
				table.remove(entries, i)
				byPart[p] = nil
			elseif (p.Position - eye).Magnitude < CULL then
				apply(entry, clock, pivots)
			end
		end
	end)
end

return HouseFX
