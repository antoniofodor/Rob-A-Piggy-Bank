--!strict
--[[
	InteriorService

	The front door: walking into a house puts you in its hallway, and walking
	out of the hallway puts you back on your own lawn.

	docs/PIGGY-COLLECTION-BUILD-ORDER.md Stage 4, and plan section 6.

	================================================================
	AN INTERIOR IS A DETACHED ROOM, SO A DOOR IS A TELEPORT
	================================================================

	A builder makes one interior per owner, off the map entirely
	(`Config.INDOOR_ESTATE`), and nothing about it is inside the house model
	standing on the lawn. So the crossing cannot be a hole in a wall: it is a
	server-authoritative CFrame write with a mask over it, which is the same
	trick `PoliceService.releaseHome` already does when it puts a thief back at
	their own gate under an opaque arrest card.

	================================================================
	TWO BUILDERS, ONE CONTRACT, ONE DISPATCH
	================================================================

	AN INTERIOR IS PER HOUSE THEME
	(`assets/houses/design/modular-interiors-v1/CONCEPT.md`).
	`Shared/HouseInterior` is the generic hall, and every house with no
	authored kit gets it. `Services/ThemedInterior` wraps the authored art
	packages under `assets/houses/interiors/` -- three of the eighteen today,
	keyed to a house tier by a registry it reads out of Config through a
	fallback.

	BOTH HAND BACK `HouseInterior.Refs`, field for field, so the dispatch is
	ONE FIELD on the record below (`Interior.builder`) and nothing else in this
	file, in `PoliceService`'s door routing, or in the indoor piggy placement
	still to come ever asks which it got. `ensureHome` picks it from the house
	that is STANDING, and the picking is the only place the two names appear
	together.

	A SERVER WITH NO KITS STILL HAS INTERIORS. `ThemedInterior.available(tier)`
	is lazy and false both for a house with no kit registered and for a kit
	that is not in `ServerStorage` -- an older `rojo serve`, or a `rojo build`
	from a project file without the rows -- and it says so once per kit. Those
	houses then get the generic hall, which is a themed interior absent rather
	than a front door that does nothing.

	THE SERVER OWNS THE MOVE. A client-side `Anchored` or CFrame write on a
	character is discarded -- this project has that measured three ways on a
	live rig -- so the teleport is `root.CFrame` written here and the CLIENT
	is only told to draw the cover. Same split as the trampoline and the dodge:
	the server decides, the client renders.

	================================================================
	THE CROSSING IS A SWEPT SEGMENT, NOT A TOUCH AND NOT A PROMPT
	================================================================

	A `ProximityPrompt` would read as OPENING a door rather than walking
	through one, which is the one thing the plan asks for by name.

	`Touched` is the obvious alternative and it is the wrong instrument twice.
	It re-fires per character PART -- measured at fourteen parts on the first
	contact frame when the electric fence shipped as a freeze -- so it needs a
	debounce that is easy to get wrong; and it is unreliable for a model the
	server moves with `PivotTo` every frame, which is exactly what the
	pursuing officer is going to be.

	So the sweep is polled on the server and tested as a SEGMENT: where the
	mover's root was at the last tick against where it is now, pierced against
	the doorway's plane. A segment cannot be stepped over at any speed, which
	makes `Config.HOUSE_DOOR.tickRate` a LATENCY dial rather than a
	correctness one -- the thing a `Touched` debounce is not.

	`Config.crossedDoorway` is the decision and it lives in Config on purpose:
	it is plain arithmetic on three numbers, so it is testable with no engine
	at all, and the CFrame work that produces those numbers is the half that
	needs one.

	================================================================
	THE ANCHOR IS AUTHORED, AND IT WAS MEASURED RATHER THAN ASSUMED
	================================================================

	All eighteen house templates ship a `Mount_Door_Exit` marker. Measured
	across every one of them, off the .rbxmx rather than off a comment: it
	carries IDENTITY rotation, it sits on the doorway's own centre line to
	the millistud, and it stands exactly 0.92 studs outside the line the two
	`HouseDoorLeaf` parts hang on -- so it is the spot a character stands on
	to walk in, and its +Z is OUTWARD. `House.build` only ever TRANSLATES a
	template, so that +Z arrives as plot-local +Z, which is the street on both
	rows.

	A code-built house (the Gingerbread Manor, and the placeholder block)
	carries no mount, so its own `Door` part is put back onto the same
	convention. One anchor shape, two sources, and nothing downstream knows
	which it got.

	================================================================
	LAZY AND PREFIX, WHICH IS A PART BUDGET RATHER THAN A STYLE
	================================================================

	Measured on the real builder offline: a hallway built to the rebirth-20
	ceiling is 416 BaseParts, and ten of those is 4,160 against a world of a
	few thousand -- interiors would be the largest class of object in the
	game, for rooms nobody is standing in.

	Two things stop that, and both are needed:

	  * NOTHING IS BUILT UNTIL SOMEBODY WALKS THROUGH A DOOR. A server that
	    nobody enters a house on carries no interior parts at all.
	  * ONLY THE ROOMS THAT OWNER HAS UNLOCKED ARE BUILT, which is what
	    `HouseInterior.build`'s `rooms` argument is for. At rebirth 0 that is
	    ONE room and 37 parts against 416 -- so ten players all indoors at
	    rebirth 0 is 370 parts, and the 4,160 case needs ten players who have
	    each rebirthed twenty times.

	The full measured ladder is in the report for this change; the shape is
	37 parts at rebirth 0 rising 43 per room to 416 at rebirth 20.

	AND AN AUTHORED INTERIOR IS ABOUT FOURTEEN TIMES THAT, measured on the
	assembled treehouse kit: 521 parts at rebirth 0 and 4,301 at the ceiling.
	So both halves above stop being an optimisation and become the budget --
	ten players indoors at rebirth 0 is 5,210 parts against a world of a few
	thousand, and the kit's README asks for its merged mesh exports and
	measured profiling before this reaches every player's full-length hall.
	That work is not started.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local HouseInterior = require(ReplicatedStorage.Shared.HouseInterior)
local BaseShopStand = require(ReplicatedStorage.Shared.BaseShopStand)
local IndoorPedestal = require(ReplicatedStorage.Shared.IndoorPedestal)
local PiggyPedestal = require(ReplicatedStorage.Shared.PiggyPedestal)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
-- THE COLLECT AND THE THREE HAUL VERBS, WHICH ARE ASKED FOR RATHER THAN
-- REIMPLEMENTED. A hall's pads and prompts are the lawn's own -- one array of
-- placements, one economy -- so walking over an indoor pad calls the same
-- `EconomyService.collectPiggy` the six lawn pads call and a press on an
-- indoor plinth calls the same `PiggyHaulService.take`/`.place`.
--
-- REQUIRED DIRECTLY RATHER THAN THROUGH A REGISTRY, which is safe only
-- because this file is a LEAF: nothing in the game requires
-- `InteriorService` except `Main`, so neither of these can reach back. That
-- was checked rather than assumed -- the registry shape
-- (`SetService.registerPusher`, `PlotService.registerPiggyRates`) exists for
-- the cases where it is not true, and a registry that is not needed is a
-- dependency hidden from the reader.
local EconomyService = require(script.Parent.EconomyService)
local PiggyHaulService = require(script.Parent.PiggyHaulService)
local PlotService = require(script.Parent.PlotService)
local ThemedInterior = require(script.Parent.ThemedInterior)

local InteriorService = {}

type Gate = {
	-- The frame the crossing is tested in: +Z is the side you come FROM, X
	-- runs across the opening, Y is up with the threshold at 0.
	frame: CFrame,
	-- Where a mover LANDS coming the other way, as a ground CFrame aimed with
	-- a CHARACTER's own convention -- LookVector, which is -Z, and the
	-- opposite of every model in this game. `CLAUDE.md` records that
	-- exception in as many words.
	land: CFrame,
	spec: { halfWidth: number, underfoot: number, headroom: number },
}

type Interior = {
	refs: HouseInterior.Refs,
	-- WHICH BUILDER MADE IT, chosen once when the hallway is built and read
	-- everywhere a hallway is changed afterwards. THE DISPATCH IS HERE AND
	-- NOWHERE ELSE: a themed interior and the generic hall hand back the same
	-- `Refs`, so the only thing that can ever need to know which is which is
	-- the code that calls back into the builder -- and keeping that to one
	-- field means the door crossing, the exit gate, `homeOf` and the indoor
	-- plots stay one code path. Branching per call site is the failure this
	-- project records as nine accessors with a plot-shaped hole under each.
	builder: any,
	-- WHICH AUTHORED KIT MADE IT, or nil for the generic hall -- and it is
	-- part of the cache key below.
	--
	-- `builder` ALONE IS NOT ENOUGH AND THAT SHIPPED AS A REAL BUG. All three
	-- authored kits resolve to the SAME `ThemedInterior` table, so a player
	-- who moves from one kit house to another -- the Treehouse to the Beehive
	-- Cottage -- matched on the builder, kept the hall they already had, and
	-- walked into the old kit's interior for the rest of the session.
	-- Measured live on 2026-09-23: a TreehouseInterior standing behind a
	-- Beehive Cottage. The kit NAME is what actually differs, so it is what
	-- the test compares.
	kit: string?,
	plot: any,
	owner: Player?,
	rooms: number,
	-- THE PLACEMENTS STANDING IN IT, KEYED BY SAVE SLOT (7 upward). Built for
	-- the plots the owner has unlocked and for no others, which is what makes
	-- a locked plot unreachable by construction rather than by a rebirth check
	-- at every verb. See `syncPlacements`.
	placements: { [number]: PiggyPedestal.Refs },
	-- The folder they stand in, INSIDE the hall model. Never the model
	-- itself: `tests/luau/interior.luau` sweeps the model's own children for
	-- the entrance-to-plot sightline, and a pad or a sign is not the room.
	placementFolder: Folder?,
	-- The way out, in the same shape the way in has.
	gate: Gate,
	-- The box a root has to be inside to still count as being in here. Held
	-- as a half-extent in the hallway's own frame, because a world-space box
	-- is only meaningful on the half of the street pointing the way you
	-- assumed -- this project has paid for that three times.
	half: Vector3,
}

-- Keyed by PLOT INDEX rather than by player: a plot outlives whoever is
-- standing on it, and `PlotService.onRelease` hands back the plot.
local homes: { [number]: Interior } = {}
-- The outside gate, cached against the HOUSE MODEL it was resolved from. A
-- house is destroyed and rebuilt whenever a tier is bought, so comparing the
-- model is what makes this self-heal with no hook in `PlotService.setHouseLevel`.
local gates: { [number]: { house: Model, gate: Gate } } = {}

local lastAt: { [Player]: Vector3 } = {}
local inside: { [Player]: number } = {}
local latched: { [Player]: number } = {}

local folder: Folder? = nil

-- ============================================================
-- THE CROSSING PRIMITIVE
-- ============================================================

--[[
	Stand `model` on `ground`, wherever `ground` is.

	ANY MODEL WITH A ROOT, which is the shape Stage 4 asks for: a player's
	character today and the pursuing officer's rig later, and DOGS NEVER --
	that exclusion is a decision in the plan rather than a limitation here,
	and it is kept by nothing in this file ever being handed one.

	`ground` is a GROUND CFrame -- the floor, not the middle of a torso --
	because that is the convention `HouseInterior.entrance` and
	`PiggyPedestal.build` already take, and a second convention for the same
	question is how two callers come to disagree about where a floor is.

	THE LIFT IS ASKED OF THE RIG RATHER THAN PINNED. A character is raised by
	its own `HipHeight` plus half its root, so a scaled avatar stands on the
	floor rather than in it. Anything without a Humanoid is raised by the gap
	between its PIVOT and the bottom of its own bounding box, which is what
	makes `PivotTo` land it on the ground: that call aims the PRIMARY PART,
	not the model's origin, and this project has already sunk a patrol car
	1.6 studs into the tarmac and walked an officer through the grass to the
	chest by forgetting it.
]]
function InteriorService.cross(model: Model?, ground: CFrame): boolean
	if not model or not model.Parent or typeof(ground) ~= "CFrame" then
		return false
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if humanoid and root and root:IsA("BasePart") then
		root.CFrame = ground * CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
		-- AND THE VELOCITY IS DELIBERATELY NOT TOUCHED. Zeroing it is the
		-- obvious tidy-up and it is a write this game has MEASURED as
		-- discarded: a character's physics are owned by its own client, so a
		-- server write to `AssemblyLinearVelocity` does nothing -- three ways
		-- on a live rig, which is why the trampoline and the fence knockback
		-- are both fired to the client instead. A line that reads as a fix and
		-- provably is not is worse than no line.
		return true
	end

	local box, size = model:GetBoundingBox()
	local lift = model:GetPivot().Position.Y - (box.Position.Y - size.Y / 2)
	model:PivotTo(ground * CFrame.new(0, lift, 0))
	return true
end

-- ============================================================
-- WHERE THE DOORS ARE
-- ============================================================

-- A ground CFrame at `at`, facing along `forward`, aimed with a CHARACTER'S
-- convention: its LookVector is the way it faces.
--
-- STATED RATHER THAN TAKEN FROM `CFrame.lookAt`, because that aims LookVector
-- and this project's four recorded bugs from it are all the correction being
-- forgotten in one direction or the other. Built from the matrix, the sign is
-- written down once and asserted at boot.
local function facing(at: Vector3, forward: Vector3): CFrame
	local look = Vector3.new(forward.X, 0, forward.Z)
	if look.Magnitude < 1e-4 then
		look = Vector3.new(0, 0, 1)
	end
	look = look.Unit
	local right = look:Cross(Vector3.yAxis).Unit
	-- Columns are Right, Up, Z -- and Z is the BACK of a character, so the
	-- third column is the negated forward. Negating only the third would make
	-- a left-handed frame, which `CFrame.fromMatrix` accepts without saying so.
	return CFrame.fromMatrix(at, right, Vector3.yAxis, -look)
end

-- The authored anchor, or the same thing rebuilt from a code-built door.
--
-- Returns a CFrame whose POSITION is the spot outside the doorway somebody
-- stands on, and whose +Z points OUT -- plus half the opening.
local function doorAnchor(house: Model): (CFrame?, number?)
	local door = Config.HOUSE_DOOR

	local mount = house:FindFirstChild("Mount_Door_Exit", true)
	if mount and mount:IsA("BasePart") then
		local half = door.halfWidth
		local left = house:FindFirstChild("HouseDoorHinge_L", true)
		local right = house:FindFirstChild("HouseDoorHinge_R", true)
		if left and right and left:IsA("BasePart") and right:IsA("BasePart") then
			-- MEASURED FROM THE ART, so a wider doorway is a wider gate with
			-- nothing to remember. The eighteen run 5.70 to 8.99 hinge to
			-- hinge, which is a spread no single constant describes.
			half = (left.Position - right.Position).Magnitude / 2
		end
		return mount.CFrame, half
	end

	-- NO MOUNT: a code-built house. Put its door back onto the mount's own
	-- convention -- pushed out by the measured standoff, dropped to the sill,
	-- keeping the part's own axes, whose +Z is outward for exactly the reason
	-- the template's is.
	for _, name in ipairs({ "Door", "DoorFrame", "Gate" }) do
		local part = house:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			local out = part.Size.Z / 2 + door.mountStandoff
			local at = part.CFrame * CFrame.new(0, -part.Size.Y / 2, out)
			return CFrame.fromMatrix(at.Position,
				part.CFrame.XVector, part.CFrame.YVector, part.CFrame.ZVector),
				part.Size.X / 2
		end
	end

	return nil, nil
end

--[[
	The gate on the LAWN side of one plot's front door, or nil if there is no
	door to find.

	EXPORTED RATHER THAN LOCAL, because it has a second caller coming and one
	here already. `PoliceService` routing a pursuing officer through a door
	(build order Stage 4) needs to know where the doorway is and which way it
	faces, and re-deriving that over there would be a second description of
	one anchor -- the failure this project has recorded for `busyUntil`, for
	the rarity ladder and for the ride-key grammar. It is also what lets the
	whole derivation be driven offline without an engine.
]]
function InteriorService.doorGate(plot: any): Gate?
	local house = plot.house
	if not house or not house.Parent then
		gates[plot.index] = nil
		return nil
	end
	local cached = gates[plot.index]
	if cached and cached.house == house then
		return cached.gate
	end

	local anchor, half = doorAnchor(house)
	if not anchor or not half then
		return nil
	end

	local door = Config.HOUSE_DOOR
	-- THE PORTAL ON THE HOUSE SIDE, built once per house instance beside the
	-- gate it belongs to (this branch is the cache miss, so a rebuilt house
	-- gets a fresh one and the old one died with the old model). Seated on
	-- the LEAF LINE rather than on the anchor: the anchor stands
	-- `mountStandoff` outside the leaves and the crossing plane `inset`
	-- inside them, and a block `PORTAL_DEPTH` deep centred on the leaf line
	-- has the plane INSIDE it -- so a character is in the glow as they
	-- cross, which is what the hallway's own exit does. Height comes off
	-- the art's door leaf where there is one, so a tall doorway fills; a
	-- code-built house falls back to the headroom.
	local leafHeight = door.headroom
	for _, part in ipairs(house:GetDescendants()) do
		if part:IsA("BasePart") and part.Name:sub(1, 13) == "HouseDoorLeaf" then
			leafHeight = math.max(leafHeight, part.Size.Y)
			break
		end
	end
	HouseInterior.buildPortal(house, anchor * CFrame.new(0, 0, -door.mountStandoff), half, leafHeight)

	local gate: Gate = {
		-- The plane stands INSIDE the anchor, so the crossing fires with the
		-- doorway around you. +Z of the anchor is outward already, which is
		-- exactly what `crossedDoorway` wants its frame to be.
		frame = anchor * CFrame.new(0, 0, -door.inset),
		-- AND YOU LAND ON THE ANCHOR ITSELF COMING OUT, rather than a stride
		-- further out. It is the spot the art authored for standing outside
		-- this door -- on the top approach step of a cottage, on the DECK of
		-- the Treehouse fourteen studs up a trunk -- and a fixed nudge outward
		-- would walk that one off its own platform into the air.
		land = facing(anchor.Position, anchor.ZVector),
		spec = {
			halfWidth = half,
			underfoot = door.underfoot,
			headroom = door.headroom,
		},
	}
	gates[plot.index] = { house = house, gate = gate }
	return gate
end

-- The gate on the HALLWAY side, built from the room rather than from a
-- constant: the exit slab's own size is the aperture, so a builder that
-- widens the way out widens the gate with it. Exported for the same reason
-- `doorGate` is.
function InteriorService.exitGate(refs: HouseInterior.Refs): Gate
	local door = Config.HOUSE_DOOR
	local exit = refs.exit
	-- A QUARTER TURN, because the corridor runs along the hallway's X and
	-- `crossedDoorway` wants the side you come from on +Z. `CFrame.Angles(0,
	-- pi/2, 0)` maps the gate's +Z onto the origin's +X, which is the way back
	-- down the corridor, and its X onto the origin's -Z, which is across the
	-- opening. Asserted at boot rather than reasoned about.
	local frame = refs.origin
		* CFrame.new(door.exitReach, 0, 0)
		* CFrame.Angles(0, math.pi / 2, 0)
	return {
		frame = frame,
		land = refs.entrance,
		spec = {
			halfWidth = exit.Size.Z / 2,
			underfoot = door.underfoot,
			headroom = math.max(exit.Size.Y, door.headroom),
		},
	}
end

-- ============================================================
-- THE HALLWAYS
-- ============================================================

-- Laid out in a row along Z, off the map. The PITCH is solved here rather
-- than in Config because it is the builder's own footprint plus the gap, and
-- Config may not require a builder -- a pinned pitch would put two hallways
-- through each other the first time the rebirth ladder grew, with nothing in
-- any log.
local function estateCFrame(index: number): CFrame
	local estate = Config.INDOOR_ESTATE
	-- THE WIDER OF EVERY BUILDER, because one estate holds halls of every kind
	-- and the pitch has to clear whichever a plot's house happens to want.
	-- Measured, the three authored kits are 39.25, 39.25 and 39.45 studs
	-- across against the generic hall's 40, so this is 40 today and
	-- `Config.INDOOR_ESTATE` did not have to move -- and it is a `max` rather
	-- than the generic one so that the NEXT themed kit cannot quietly stand
	-- through its neighbour with nothing in any log.
	local pitch = math.max(HouseInterior.footprint().Z, ThemedInterior.footprint().Z) + estate.gap
	return CFrame.new(estate.x, 0, estate.z + (index - 1) * pitch)
end

local function ensureFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local made = Instance.new("Folder")
	made.Name = "Interiors"
	made.Parent = workspace
	folder = made
	return made
end

-- ============================================================
-- THE PLACEMENTS: A PEDESTAL, A PAD AND A SIGN PER UNLOCKED PLOT
-- ============================================================
--
-- docs/PIGGY-COLLECTION-PLAN.md section 3 and section 6: an indoor plot holds
-- one piggy out of its owner's collection, it earns exactly what a lawn
-- pedestal earns, and what placement buys is EXPOSURE rather than income.
--
-- SO THERE IS NO SECOND ECONOMY IN HERE AND NOTHING IN THIS FILE COUNTS
-- COINS. The lawn is save slots 1..`PIGGY_LAWN_SLOT_COUNT` and the hall is the
-- slots after it (`HouseInterior.slotOfPlot`), so:
--
--   * `Shared/IndoorPedestal` builds a `PiggyPedestal.Refs` -- the same record
--     the six plinths are -- on different geometry, exactly as `PiggyBank`
--     builds the till's pad.
--   * `PlotService.setIndoorPedestals` publishes them onto the plot, so
--     `setPiggySlots` and `setPiggyBuffers` dress them and light their pads on
--     the economy tick that already repaints the lawn.
--   * a pad's `Touched` calls `EconomyService.collectPiggy` with its slot, and
--     a prompt calls `PiggyHaulService.take`/`.place`/`.snatch`, which find
--     the pedestal through `PlotService.pedestalAt`.
--
-- WHAT THIS FILE OWNS IS THE LIFETIME AND NOTHING ELSE: which plots have a
-- placement standing on them, and taking them down when the hall goes.

-- ONE CONNECTION PER PROMPT INSTANCE, made at build and never re-made.
--
-- A lawn plinth is wired once at server startup because it outlives every
-- owner a plot ever has; an indoor placement does not -- it is destroyed when
-- its plot re-locks or when the hallway grows -- so the connections are made
-- here and die with the instances they are on. The SLOT is closed over rather
-- than sent, which is the "the click means now, never now and here" decision
-- `BoneThrow`, `placeLadder`, `CrackTap` and the lawn's own pads all make.
local function wirePlacement(home: Interior, slot: number, refs: PiggyPedestal.Refs)
	local plot = home.plot
	-- THE REPAINT IS IMMEDIATE RATHER THAN LEFT TO THE TICK. Every one of
	-- these four changes what is standing on a plinth or what is waiting on a
	-- pad, and the economy tick is a second away -- which for the player
	-- standing at the pedestal they have just used is a second of the room
	-- disagreeing with the server. Idempotent, so the tick that follows
	-- writes nothing.
	local function after()
		local owner = plot.owner
		local data = owner and DataService.get(owner)
		if data then
			PlotService.setPiggySlots(plot, data)
			PlotService.setPiggyBuffers(plot, data)
		end
	end
	PiggyPedestal.wirePad(refs.pad, slot, function(player: Player, which: number)
		-- QUIET, because walking is not asking. A pad crossed with an empty
		-- buffer must say nothing at all -- the "never fail silently" rule is
		-- about a player PRESSING something and getting no answer, and
		-- crossing a patch of floor is not a press.
		EconomyService.collectPiggy(player, which, true)
	end)
	refs.sellPrompt.Triggered:Connect(function(who: Player)
		EconomyService.sellPiggy(who, slot)
		after()
	end)
	refs.takePrompt.Triggered:Connect(function(who: Player)
		PiggyHaulService.take(who, plot, slot)
		after()
	end)
	refs.placePrompt.Triggered:Connect(function(who: Player)
		PiggyHaulService.place(who, plot, slot)
		after()
	end)
	refs.snatchPrompt.Triggered:Connect(function(who: Player)
		PiggyHaulService.snatch(who, plot, slot)
		after()
	end)
end

-- Stand a placement on every unlocked plot, take down any that are not, and
-- publish the lot onto the plot.
--
-- DRIVEN OFF `plot.unlocked` RATHER THAN OFF A REBIRTH COUNT, because that
-- field is what both builders' own `setCapacity` has just written -- so the
-- placements and the doors cannot disagree about how far the hall reaches.
-- Called immediately after every `setCapacity`, which is the only thing that
-- moves it.
--
-- IDEMPOTENT, which is what lets it run on the cached path as well as after a
-- build: a plot that already has a placement keeps the one it has, so nothing
-- a player is standing at is destroyed and rebuilt under them.
local function syncPlacements(home: Interior)
	local refs = home.refs
	local folder = home.placementFolder
	if not folder or folder.Parent == nil then
		local made = Instance.new("Folder")
		made.Name = "Placements"
		made.Parent = refs.model
		folder = made
		home.placementFolder = made
	end

	local held = home.placements
	local wanted: { [number]: boolean } = {}
	for _, plot in ipairs(refs.plots) do
		if plot.unlocked then
			local slot = HouseInterior.slotOfPlot(plot.index)
			wanted[slot] = true
			if held[slot] == nil then
				-- PCALLED PER PLACEMENT, the same call `Decor.prewarm` makes:
				-- a pedestal that will not build is a plot a player cannot
				-- use, and a pedestal that takes the door crossing down with
				-- it is a house nobody can get out of.
				local ok, built = pcall(IndoorPedestal.build, folder :: Instance, plot, slot)
				if ok and built then
					held[slot] = built
					wirePlacement(home, slot, built)
				else
					warn(("[Interior] plot %d's placement would not build: %s")
						:format(plot.index, tostring(built)))
				end
			end
		end
	end

	-- AND ANYTHING THAT IS NO LONGER WANTED COMES DOWN WITH ITS PROMPTS. The
	-- capacity ladder only ever grows, so this is reachable today only by a
	-- hall rebuilt at a different size -- and it is written anyway, because
	-- four live prompts at a plot with nothing standing on it is the exact
	-- failure this project refuses above all others. The prompts are on a part
	-- INSIDE the placement model (see `IndoorPedestal`), so one Destroy takes
	-- the lot.
	for slot, placement in pairs(held) do
		if not wanted[slot] then
			placement.model:Destroy()
			held[slot] = nil
		end
	end

	PlotService.setIndoorPedestals(home.plot, held)

	-- DRESSED FROM THE SAVE THE MOMENT THEY STAND. The two painters cover
	-- the hallway's plinths as well as the lawn's, and until now nothing
	-- called them here: a plinth built on a door crossing stood EMPTY over a
	-- saved piggy until its own prompt was next pressed -- measured
	-- (2026-09-23), thirty-one take prompts and no piggy on any of them in
	-- a room whose save held twenty-five.
	local owner = home.plot.owner
	local data = owner and DataService.get(owner)
	if data then
		PlotService.setPiggySlots(home.plot, data)
		PlotService.setPiggyBuffers(home.plot, data)
	end
end

-- ============================================================
-- PARKING: A ROOM NOBODY IS IN LIVES IN ServerStorage
-- ============================================================
--
-- Measured on the live street (2026-09-23): ONE owner's Beehive Cottage
-- hallway is 3,312 parts, seven rooms and their gates, standing four
-- thousand studs off the map and replicated to every client whether or not
-- anybody is inside it. Eight owners is 26,000 parts of rooms nobody is in.
-- `ServerStorage` does not replicate, so a hallway waits there and is moved
-- into `workspace` the moment somebody crosses its door -- BEFORE the mask
-- lead, so the client has that head start to receive it -- and back the
-- moment the last person leaves. Everything this file asks of a room (its
-- frames, its gate, its capacity, its placements) is a CFrame, a property
-- or a table and answers the same wherever the model is parented; only a
-- character has to stand in it, and a character is only ever put in it by
-- `goInside`, which unparks first.
local parkedFolder: Folder? = nil

local function ensureParked(): Folder
	if parkedFolder and parkedFolder.Parent then
		return parkedFolder
	end
	local made = Instance.new("Folder")
	made.Name = "ParkedInteriors"
	made.Parent = game:GetService("ServerStorage")
	parkedFolder = made
	return made
end

local function occupied(index: number): boolean
	for _, at in pairs(inside) do
		if at == index then
			return true
		end
	end
	return false
end

local function parkIfEmpty(home: Interior)
	local model = home.refs.model
	if model.Parent and not occupied(home.plot.index) and model.Parent ~= ensureParked() then
		model.Parent = ensureParked()
	end
end

local function unpark(home: Interior)
	local model = home.refs.model
	if model.Parent ~= ensureFolder() then
		model.Parent = ensureFolder()
	end
end

local function destroyHome(index: number)
	local home = homes[index]
	if not home then
		return
	end
	-- THE PLOT LETS GO OF THE PLACEMENTS BEFORE THE MODEL GOES, and the order
	-- is the point: `setPiggySlots` and `setPiggyBuffers` run on the economy
	-- tick against whatever the plot is holding, so a map left behind here is
	-- a repaint dressing pedestals that no longer exist. Cleared first,
	-- destroyed second.
	PlotService.setIndoorPedestals(home.plot, nil)
	home.placements = {}
	home.placementFolder = nil
	home.refs.model:Destroy()
	homes[index] = nil
end

-- Build, or rebuild, the hallway behind one plot's door.
--
-- A REBUILD IS A DESTROY AND NOT A RESIZE, AND PIGGIES STAND IN HERE NOW,
-- which this note used to say was the moment it would stop being safe. It is
-- still safe, for a reason worth stating rather than assuming: THE SAVE IS
-- THE SOURCE OF TRUTH AND THE ROOM IS A DRAWING OF IT. A placement holds no
-- state of its own -- what is standing on it, what is waiting in its buffer
-- and what it earns are all `data.piggies.slots`, repainted through
-- `PlotService.setPiggySlots`/`setPiggyBuffers` -- so a hallway destroyed and
-- rebuilt comes back wearing exactly the collection it had.
--
-- WHAT IT COSTS IS CHURN AND NOT A PIGGY: up to 56 pedestals, pads and signs
-- built again. It happens only when the ROOM COUNT grows, which is a rebirth,
-- and `ensureHome` is reached from a door crossing -- so the rebuild lands
-- while its owner is walking in rather than under their feet.
--
-- What is NOT safe, and is why `destroyHome` clears the plot first, is a
-- placement map outliving the model it describes: the economy tick would go
-- on dressing pedestals that no longer exist.
local function ensureHome(plot: any): Interior?
	-- THE HALLWAY BELONGS TO THE PLOT'S OWNER AND NEVER TO WHOEVER WALKED IN.
	-- It is the same answer today, because only an owner crosses; it stops
	-- being the same answer the moment `HOUSE_DOOR.ownerOnly` is turned off,
	-- and a visitor's rebirth count deciding how many rooms their neighbour's
	-- house has is exactly the bug that would not be noticed.
	--
	-- A RESIDENT HAS NO SAVE, so an unclaimed plot has no hallway. That is the
	-- honest refusal rather than a missing case: there is nothing behind an
	-- NPC's front door and nothing that could be.
	local owner = plot.owner
	local data = owner and DataService.get(owner)
	if not owner or not data then
		return nil
	end

	local capacity = Config.indoorPlots(data.rebirths)
	local rooms = Config.indoorRooms(capacity)
	local tier = Config.getShownHouse(data)

	-- WHICH INTERIOR THIS HOUSE HAS, AND THE REGISTRY OWNS THAT RATHER THAN
	-- THIS FILE. `assets/houses/design/modular-interiors-v1/CONCEPT.md` is
	-- per-house -- a shell, a ceiling, a pedestal dressing and a door for each
	-- of the eighteen -- so a tier with an authored kit gets it and the other
	-- fifteen keep the generic hall. One question, asked in one place.
	--
	-- IT IS ASKED OF THE HOUSE THAT IS STANDING, not of the best one owned:
	-- `getShownHouse` is what the sign, the card and the lawn all already
	-- read, and a player who moves back into a tier they liked should walk
	-- into that tier's interior.
	local builder: any = HouseInterior
	local kit: string? = nil
	if ThemedInterior.available(tier) then
		builder = ThemedInterior
		-- THE KIT NAME, WHICH IS THE PART OF THE ANSWER `builder` THROWS AWAY.
		-- `ThemedInterior` is ONE wrapper over three art packages, so all
		-- three kit houses resolve to the same table -- see `Interior.kit`.
		kit = ThemedInterior.kitName(tier)
	end

	local home = homes[plot.index]

	-- THE BUILDER AND THE KIT ARE BOTH PART OF THE CACHE KEY. Showing a
	-- different house can change which interior a door opens onto, and a
	-- hallway kept because the owner and the room count still match would be
	-- the old house's -- which is the stale-model failure `doorGate` already
	-- self-heals by comparing the house model it was resolved from.
	--
	-- THE KIT HALF OF THAT SHIPPED BROKEN AND WAS MEASURED LIVE: moving from
	-- the Treehouse to the Beehive Cottage matched on `builder` alone, kept
	-- the Treehouse's hall, and put a TreehouseInterior behind a Beehive
	-- Cottage for the rest of the session. Nothing errored -- the frames, the
	-- gates and the plots were all a valid hall's -- so the only symptom was
	-- the wrong art.
	if home and home.owner == owner and home.builder == builder
		and home.kit == kit and home.rooms >= rooms then
		home.builder.setCapacity(home.refs, capacity)
		-- AND THE PLACEMENTS FOLLOW THE CAPACITY, on the cached path as well
		-- as after a build: a rebirth claimed this session opens plots in a
		-- hall that already exists, and a plot standing unlocked with nothing
		-- on it is a slot a save can hold a piggy in and a player cannot see.
		syncPlacements(home)
		return home
	end
	destroyHome(plot.index)

	local ok, built = pcall(function()
		return builder.build(ensureFolder(), estateCFrame(plot.index), tier, rooms)
	end)

	-- AND A THEMED KIT THAT WILL NOT ASSEMBLE FALLS BACK TO THE GENERIC HALL
	-- RATHER THAN TO NOTHING. The boot probe builds every registered kit, but
	-- only at ONE room -- so this is the case it cannot see: a kit that
	-- assembles at one room and throws at ten would leave a themed house with
	-- a front door that does nothing for the rest of the session. The fallback
	-- is the same answer `available` already gives for a kit that is not synced
	-- at all, and the wrapper destroys its own half-built hall before it
	-- rethrows, so there is nothing left standing to trip over.
	if not ok and builder ~= HouseInterior then
		warn(("[Interior] plot %d's authored interior would not assemble (%s); using the generic hall")
			:format(plot.index, tostring(built)))
		builder = HouseInterior
		ok, built = pcall(function()
			return builder.build(ensureFolder(), estateCFrame(plot.index), tier, rooms)
		end)
	end

	local refs = built :: HouseInterior.Refs
	if not ok or not refs then
		-- LOUD, AND NOT FATAL. A hallway that fails to build is a door that
		-- does nothing, which is bad; a hallway that fails to build and takes
		-- the heist loop down with it is worse. Same call `Decor.prewarm`
		-- makes: a room may not stop the game being played.
		warn(("[Interior] could not build the hallway for plot %d: %s")
			:format(plot.index, tostring(built)))
		return nil
	end

	builder.setCapacity(refs, capacity)
	-- Lobby counters share the house lifetime: parking/rebuilding the hall also
	-- parks/destroys its NPCs and prompt connections. Purchases stay in the shop.
	--
	-- THE COUNTERS ARE `Config.BASE_COUNTERS` AND THE SPOTS ARE DERIVED FROM
	-- IT, so the two cannot disagree about how many there are. It was `if i ==
	-- 1 then "gadgets" else "guardians"` against a `placements` that returned
	-- exactly two -- correct, and the shape where a third counter silently
	-- becomes a second Guardians desk standing in the hall.
	--
	-- THESE TWO ARE THE ONLY WAY IN TO THEIR SHELVES NOW. The HUD basket sells
	-- Robux and nothing else since 2026-09-23, so a hallway that fails to build
	-- its counters is a player who cannot buy a bone or a guardian at all --
	-- which is why the build is pcalled PER COUNTER and warned rather than left
	-- to take the room down with it. One dead counter costs its own shelf; the
	-- room, the plinths and the piggies behind it are what a throw here would
	-- otherwise cost. Same call `Decor.prewarm` makes.
	local spots = BaseShopStand.placements(refs.origin, refs.exit.Size.Z)
	for i, counter in ipairs(Config.BASE_COUNTERS) do
		local standAt = spots[i]
		local ok, stand, prompt = pcall(function()
			return BaseShopStand.build(counter.tab, standAt, refs.model)
		end)
		if not ok or not prompt then
			warn(("[Interior] the %s counter would not build in plot %d's hallway (%s); "):format(
				tostring(counter.sign), plot.index, tostring(stand))
				.. "that shelf has no door until the room is rebuilt")
		else
			prompt.Triggered:Connect(function(player: Player)
				local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
				local mount = prompt.Parent
				if not root or not root:IsA("BasePart") or not mount or not mount:IsA("Attachment") then return end
				if not refs.model:IsDescendantOf(workspace) then return end
				if (root.Position - mount.WorldPosition).Magnitude > prompt.MaxActivationDistance + 2 then return end
				Remotes.get("ShopDoor"):FireClient(player, counter.tab)
			end)
		end
	end
	local fp = builder.footprint()
	home = {
		refs = refs,
		builder = builder,
		kit = kit,
		plot = plot,
		owner = owner,
		rooms = rooms,
		placements = {},
		placementFolder = nil,
		gate = InteriorService.exitGate(refs),
		-- Generous on every axis: this box is only ever asked "has somebody
		-- left by some other route", so it wants to answer NO for anybody who
		-- is genuinely still in the building and never to be a second opinion
		-- about the exit.
		half = Vector3.new(fp.X + 20, fp.Y + 20, fp.Z + 20),
	}
	homes[plot.index] = home
	-- AFTER THE RECORD IS IN THE TABLE, because `wirePlacement`'s handlers
	-- close over it and a prompt pressed inside the same frame would
	-- otherwise be answering for a hallway nothing has admitted to owning.
	syncPlacements(home)
	-- And off the wire until somebody walks in.
	parkIfEmpty(home)
	return home
end

-- ============================================================
-- THE TWO CROSSINGS
-- ============================================================

local function maskThen(player: Player, way: string, move: () -> ())
	Remotes.get("DoorCross"):FireClient(player, way)
	-- COVER FIRST, MOVE UNDER THE COVER. The crossing is already latched when
	-- this starts, so nothing the player does during the lead changes the
	-- outcome -- all the wait buys is that the screen is black before the
	-- world changes, which is the whole of what makes a teleport read as a
	-- doorway.
	task.delay(Config.HOUSE_DOOR.maskLead, move)
end

local function goInside(player: Player, plot: any, home: Interior)
	inside[player] = plot.index
	latched[player] = os.clock() + Config.HOUSE_DOOR.cooldown
	-- Into the world NOW, so the mask lead is the room's replication lead.
	unpark(home)
	maskThen(player, "in", function()
		-- Everything re-fetched, nothing captured across the wait: a tenth of
		-- a second is long enough for a player to have died or left, and a
		-- captured character could by then be a stale one.
		if player.Parent == nil or homes[plot.index] ~= home then
			return
		end
		InteriorService.cross(player.Character, home.refs.entrance)
		-- The tracked position is reset rather than left to the next tick,
		-- because the segment from a lawn to a hallway spans four thousand
		-- studs and would pierce anything in between.
		lastAt[player] = nil
	end)
end

local function goOutside(player: Player, home: Interior, gate: Gate?)
	inside[player] = nil
	latched[player] = os.clock() + Config.HOUSE_DOOR.cooldown
	-- WHERE THEY LAND IS RESOLVED NOW AND NOT AFTER THE WAIT, so a house
	-- destroyed mid-crossing cannot leave somebody standing in a hallway with
	-- nowhere to go. The fallback is the plot's own spawn -- the same spot
	-- `PoliceService` releases an arrested thief at, which is the one place on
	-- a plot this game already guarantees is stood on.
	local land = gate and gate.land or PlotService.getSpawnCFrame(home.plot)
	local lift = gate == nil
	maskThen(player, "out", function()
		if player.Parent == nil then
			return
		end
		if lift then
			-- `getSpawnCFrame` is already a ROOT frame rather than a ground
			-- one, so it is written straight through rather than raised again.
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				root.CFrame = land
			end
		else
			InteriorService.cross(player.Character, land)
		end
		lastAt[player] = nil
		-- The last one out parks the room. After the move rather than before
		-- it, so nobody is ever standing in a model that is not in workspace.
		if homes[home.plot.index] == home then
			parkIfEmpty(home)
		end
	end)
end

-- ============================================================
-- THE SWEEP
-- ============================================================

local function stillInside(home: Interior, at: Vector3): boolean
	local localAt = home.refs.origin:PointToObjectSpace(at)
	-- IN THE HALLWAY'S OWN FRAME, never in world space. Half the plots on this
	-- street carry a half turn, and a world-space box is only meaningful on
	-- the half that happens to point the way you assumed.
	return math.abs(localAt.X) <= home.half.X
		and math.abs(localAt.Y) <= home.half.Y
		and math.abs(localAt.Z) <= home.half.Z
end

local function stepPlayer(player: Player, now: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		lastAt[player] = nil
		return
	end

	local at = root.Position
	local from = lastAt[player]
	lastAt[player] = at

	local index = inside[player]
	local home = index and homes[index]
	if index and not home then
		inside[player] = nil
	-- NOT WHILE A CROSSING IS IN FLIGHT. `goInside` sets the flag at once but
	-- moves the character `maskLead` later, under the mask -- and this check
	-- runs BEFORE the latch test below, so for those two or three ticks the
	-- character is provably not in the hallway's box and the flag was being
	-- cleared before they ever arrived. Measured live: walk in landed exactly,
	-- walk out never fired, because every tick after arrival was testing the
	-- LAWN door four thousand studs away. The latch already names the window.
	elseif home and now >= (latched[player] or 0) and not stillInside(home, at) then
		-- SELF-HEALING, AND IT IS THE ONLY THING THAT MAKES THE CACHE SAFE.
		-- A respawn seats a character on its owner's lawn and an arrest
		-- release puts a thief at their own gate, and neither of those knows
		-- this file exists. Without this the flag would say "indoors" for the
		-- rest of the session and the door would never work again.
		--
		-- AND THE ROOM IS PARKED, because nobody is in it now. Measured live
		-- (2026-09-23): a respawn out of a hallway cleared the flag here and
		-- left 3,312 parts in workspace for the rest of the session.
		inside[player] = nil
		parkIfEmpty(home)
		home = nil
	end

	if not from then
		return
	end
	if now < (latched[player] or 0) then
		return
	end
	-- A step nobody can take on foot was a teleport, not a walk.
	if (at - from).Magnitude > Config.HOUSE_DOOR.maxStep then
		return
	end

	if home then
		local gate = home.gate
		if Config.crossedDoorway(gate.frame:PointToObjectSpace(from),
			gate.frame:PointToObjectSpace(at), gate.spec) then
			goOutside(player, home, InteriorService.doorGate(home.plot))
		end
		return
	end

	-- WHOSE DOOR. `ownerOnly` is what decides, and it decides it HERE rather
	-- than as a check further down, so the flag genuinely does something --
	-- `PlotService.getPlot` already hands back the caller's OWN plot, so a
	-- guard testing `plot.owner ~= player` against it could never fire, and a
	-- Config flag that does nothing is the failure this project refuses above
	-- all others.
	--
	-- Opened up, the question becomes "whose ground am I standing on", which
	-- `PlotService.yardContaining` is the one function in this game that
	-- answers -- so asking it is cheaper than sweeping every gate AND keeps
	-- one answer to that question rather than a second one over here.
	local plot = PlotService.getPlot(player)
	if not Config.HOUSE_DOOR.ownerOnly then
		plot = PlotService.yardContaining(at) or plot
	end
	if not plot then
		return
	end
	local gate = InteriorService.doorGate(plot)
	if not gate then
		return
	end
	if not Config.crossedDoorway(gate.frame:PointToObjectSpace(from),
		gate.frame:PointToObjectSpace(at), gate.spec) then
		return
	end
	local built = ensureHome(plot)
	if built then
		goInside(player, plot, built)
	end
end

-- ============================================================
-- LIFECYCLE
-- ============================================================

-- Anybody standing in a hallway that is about to stop existing goes home
-- first. Without it the model is destroyed out from under them and they are
-- left standing in empty air four thousand studs from the map.
local function evict(index: number)
	local home = homes[index]
	if not home then
		return
	end
	for player, at in pairs(inside) do
		if at == index then
			goOutside(player, home, InteriorService.doorGate(home.plot))
		end
	end
	-- THE PLOT LETS GO AT ONCE RATHER THAN AFTER THE MASK. The model is
	-- destroyed a beat later, under the cover, and for that beat the economy
	-- tick would otherwise go on dressing placements in a hallway that is
	-- about to stop existing -- on a plot whose owner has already left, which
	-- is when `release` is repainting it to nobody.
	PlotService.setIndoorPedestals(home.plot, nil)
	-- After the mask's own lead, so the destroy lands under the cover rather
	-- than in front of it.
	task.delay(Config.HOUSE_DOOR.maskLead + 0.1, function()
		if homes[index] == home then
			destroyHome(index)
		end
	end)
end

function InteriorService.isInside(player: Player): boolean
	return inside[player] ~= nil
end

-- The hallway one player is standing in, for whoever needs to reach into it
-- later -- the indoor pedestals, and the officer who follows somebody
-- through a door.
function InteriorService.homeOf(player: Player): HouseInterior.Refs?
	local index = inside[player]
	local home = index and homes[index]
	return home and home.refs or nil
end

function InteriorService.start()
	-- THE FIVE SECONDS WORK INDOORS. `PiggyHaulService`'s dwell asks where a
	-- stolen piggy could land, and this is the hallway's half of the answer:
	-- the plot whose hall a player is standing in, or nil on the street.
	-- Registered rather than required, because this file requires that one.
	-- Without it a thief who sold a hall piggy to make room stood in their
	-- own hallway with a countdown that never started (2026-09-23).
	PiggyHaulService.registerHall(function(player: Player)
		local index = inside[player]
		local home = index and homes[index]
		return home and home.plot or nil
	end)

	-- THE BOOT ASSERTS, AND THEY ARE HERE RATHER THAN IN CONFIG BECAUSE THIS
	-- IS WHERE BOTH HALVES EXIST. `Config.auditHouseDoor` can check the door's
	-- own numbers against each other; only a built room can say whether the
	-- way out stands clear of the spot somebody arrives on, or whether the
	-- quarter turn that makes the exit gate points the way this file claims.
	for _, problem in ipairs(Config.auditHouseDoor()) do
		warn("[Interior] " .. problem)
	end

	-- AND WHETHER A SAVE CAN HOLD WHAT THE HALL NOW STANDS ON. See
	-- `auditCollection`: the failure this catches is a room that looks
	-- finished and a collection that silently cannot grow into it.
	local gaps = HouseInterior.auditCollection()
	if #gaps > 0 then
		warn(("[Interior] %d PROBLEMS: the hallway's placements are built and the save cannot hold them yet."):format(#gaps))
		for _, problem in ipairs(gaps) do
			warn("[Interior]   " .. problem)
		end
	end

	-- AND IT RUNS ON EVERY BUILDER RATHER THAN ON THE FIRST ONE. All three of
	-- these are about frames this file DERIVES from a built room, and the two
	-- builders derive them out of completely different geometry -- the generic
	-- hall authors its threshold and the kit turns a -Z-forward art package
	-- round -- so a clean check on one says nothing at all about the other.
	-- Five hundred parts built and destroyed at boot is the price of hearing
	-- about a turn that is the wrong way round before a player walks into it.
	local function probe(what: string, refs: HouseInterior.Refs)
		local gate = InteriorService.exitGate(refs)
		local entrance = gate.frame:PointToObjectSpace(refs.entrance.Position)
		if entrance.Z <= 1.0 then
			warn(("[Interior] %s: the way out at %.1f studs is on top of the spot somebody arrives on "
				.. "(%.2f clear), so walking in would walk straight back out")
				:format(what, Config.HOUSE_DOOR.exitReach, entrance.Z))
		end
		-- The quarter turn, provoked rather than trusted: a mover walking back
		-- toward the hallway's threshold is moving along the gate's -Z, so the
		-- corridor's own direction has to read +1 on the gate's Z.
		local along = gate.frame:VectorToObjectSpace(refs.origin.XVector)
		if along.Z < 0.99 then
			warn(("[Interior] %s: the exit gate is turned the wrong way, the corridor reads (%.2f, %.2f, %.2f) in it")
				:format(what, along.X, along.Y, along.Z))
		end
		-- And that arriving faces DOWN the corridor rather than at the door you
		-- came through. `entrance` is aimed with a character's own convention, so
		-- it is the LookVector that has to agree.
		local look = refs.origin:VectorToObjectSpace(refs.entrance.LookVector)
		if look.X < 0.99 then
			warn(("[Interior] %s: arriving faces (%.2f, %.2f, %.2f) rather than down the hallway")
				:format(what, look.X, look.Y, look.Z))
		end
		refs.model:Destroy()
	end

	probe("the hallway", HouseInterior.build(ensureFolder(), estateCFrame(0), nil, 1))
	-- EVERY REGISTERED KIT, ON ITS OWN ESTATE SLOT. Three kits are three
	-- different art packages turned round by the same wrapper, so a clean
	-- probe on one says nothing about the next -- and the Cardboard Fort's is
	-- the one that matters most, because `shack` is the free starter tier and
	-- therefore the interior EVERY new save walks into.
	--
	-- PCALLED PER KIT, AND THE FALLBACK IS THE POINT. A kit that will not
	-- assemble is a themed interior nobody gets; a kit that takes `start` down
	-- with it is no front door at all, for any house. Same call
	-- `Decor.prewarm` makes: a room may not stop the game being played.
	local slot = 0
	for _, id in ipairs(ThemedInterior.houseIds()) do
		local tier = Config.getHouseById(id)
		if tier and ThemedInterior.available(tier) then
			slot += 1
			local where = estateCFrame(-slot)
			local ok, err = pcall(function()
				probe(id, ThemedInterior.build(ensureFolder(), where, tier, 1))
			end)
			if not ok then
				warn(("[Interior] %s's authored interior would not assemble: %s"):format(id, tostring(err)))
			end
		end
	end

	PlotService.onRelease(function(plot)
		evict(plot.index)
		gates[plot.index] = nil
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastAt[player] = nil
		local was = inside[player]
		inside[player] = nil
		latched[player] = nil
		-- Somebody who quits from inside leaves nobody in the room.
		local home = was and homes[was]
		if home then
			parkIfEmpty(home)
		end
	end)

	-- ON HEARTBEAT AND NOT `RenderStepped`, which is not a style note: this is
	-- the server, and `RenderStepped` does not exist here at all. The rate is
	-- its own because a door does not want a frame-rate-shaped poll.
	local period = 1 / Config.HOUSE_DOOR.tickRate
	local due = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now < due then
			return
		end
		due = now + period
		-- PCALLED AS A WHOLE, the same call `HeistService.watchLawns` makes:
		-- this touches every player ten to twenty times a second, and a front
		-- door is a cosmetic-grade feature next to the loop running underneath
		-- it. A door that stops working is a bug; a door that stops the game
		-- is not a trade this project makes.
		local ok, err = pcall(function()
			for _, player in ipairs(Players:GetPlayers()) do
				stepPlayer(player, now)
			end
		end)
		if not ok then
			warn("[Interior] " .. tostring(err))
		end
	end)
end

return InteriorService
