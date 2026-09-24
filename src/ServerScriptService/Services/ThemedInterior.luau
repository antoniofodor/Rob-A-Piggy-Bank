--!strict
--[[
	ThemedInterior -- the authored per-house interiors, behind the same door.

	================================================================
	INTERIORS ARE PER HOUSE THEME, AND THAT IS THE APPROVED DIRECTION
	================================================================

	`assets/houses/design/modular-interiors-v1/CONCEPT.md`: *"each illusion
	interior should match its house"*, with a theme table naming a shell, a
	ceiling, a pedestal dressing and a door for every one of the eighteen
	permanent houses -- and a theme-kit rule, *"replace shell surfaces,
	structural ribs, door design, fixture shapes and pedestal dressing
	together while RETAINING room connections and slot anchors"*.

	All eighteen permanent houses now have art under
	`assets/houses/interiors/catalogue-v4/`, mapped by the project file.

	================================================================
	ONE WRAPPER FOR THE WHOLE THEMED CATALOGUE
	================================================================

	The kits share one Builder API and six `Slot_0N` anchors. Each successive
	house tier adds two studs of floor width, two of repeat length and one of
	ceiling height; the generation rule is `catalogue-v4/tier-sizing.json`.
	Pedestals and interaction buttons retain their usable size. The Builder
	copies differ in names and vertical gate travel, and this wrapper derives
	plot frames, entrance apertures and estate bounds from each template.

	There is one wrapper for all themes. What varies is a NAME in
	`ServerStorage` and a `tier.id` that points at it, which is a table rather
	than a module -- and if a future kit ships with a different Builder,
	THIS FILE is where the difference gets absorbed, because everything above
	it is already written against one shape.

	================================================================
	THE SAME `Refs` AS THE GENERIC HALL, FIELD FOR FIELD
	================================================================

	`InteriorService` holds ONE builder handle per hallway and calls through
	it. Every reader downstream -- the door crossing, the exit gate,
	`plotGround`, `homeOf`, the indoor piggy placement still to come -- goes on
	reading one shape. WHEN A NEW THING HAS TO BEHAVE LIKE AN EXISTING THING
	IN N PLACES, MAKE IT ONE.

	`Shared/HouseInterior` is the fallback and stays: a house with no kit
	registered gets it, and so does every house on a server whose
	`ServerStorage` has no kits in it. `available(tier)` is that question and
	it is asked LAZILY, so a place built without the `default.project.json`
	rows boots and still has interiors.

	  kit `AchievementVestibule`    the lobby: the way out and the achievement
	                                alcove, which is what `buildLobby` is
	  kit vestibule `.Door_Exit`    `Refs.origin`, with +X turned down the hall
	  kit vestibule `.Arrival`      `Refs.entrance`, clamped off the exit
	                                gate's own reach -- see `entranceFrame`
	  kit vestibule `.Achievements` `Refs.mount` (`Mount_Wall`), an invisible
	                                marker on the authored alcove wall
	  kit `RoomShell` `.Slot_0N`    one `Refs.plots` entry each
	  kit `Pedestal` `.Piggy`       `Refs.plots[i].ground`, HALF TURNED --
	                                see `groundFrame`
	  kit `RebirthGate` 1..R-1      `Refs.doors`, one per gate BETWEEN built
	                                rooms; gate R is the kit's end cap and is
	                                not a door -- see `indexHall`

	================================================================
	THE TWO LADDERS ARE ONE LADDER, WHICH IS WHY THE GATES AGREE
	================================================================

	`HouseInterior.setCapacity` opens a door when `Config.indoorRooms(plots)`
	reaches that door's room. A kit's own `refreshGates` opens a gate when the
	owner's REBIRTHS reach `requirement(room)`. Those are the same statement,
	because `Config.indoorDoorRebirths` is defined as the smallest rebirth
	count at which `indoorRooms(indoorPlots(r))` reaches the room and both are
	monotone -- so handing a kit `Config.indoorDoorRebirths` as its requirement
	callback (which is what every kit's README asks for by name) and
	`gateRebirths(plots)` as its rebirth count reproduces the hall's schedule
	exactly. `tests/luau/interior.luau` sweeps the whole ladder against it
	rather than taking this paragraph's word for it.

	IT IS NEVER A SECOND SCHEDULE. A table of "which rebirth opens which gate"
	beside `indoorDoorRebirths` is the two-tables failure `Config.INDOOR`'s own
	header spends a paragraph refusing.

	================================================================
	WHAT IT COSTS, AND THE FREE HOUSE IS THE ONE THAT MATTERS
	================================================================

	Historical v1 counts, retained as a baseline; current per-theme counts live
	in `catalogue-v4/*/part-budget.json`. Originally reproduced by measuring the
	assembled treehouse hall in Studio to the part (521 and 4,301 exactly):

	    kit                 room 1   ceiling (10 rooms, 56 plots)
	    Cardboard Fort         409       3,360
	    Treehouse              521       4,301
	    Beehive Cottage        551       4,614
	    generic hall            37         416

	CARDBOARD FORT IS THE `shack`, WHICH IS THE FREE STARTER TIER EVERY SAVE
	OWNS -- so the default interior stops being 37 parts and becomes 409, and
	ten players indoors at rebirth 0 is 4,090 parts against a world of a few
	thousand rather than 370. THE TWO THINGS THAT MAKE THAT AFFORDABLE ARE THE
	ONES `InteriorService` ALREADY DOES, and neither is optional now: nothing
	is built until somebody walks through a door, and only the rooms that owner
	has unlocked are built. Each kit's README asks for its merged mesh exports
	and measured profiling before this reaches every player's full-length hall;
	that work is not started.

	Historical v1 FOOTPRINTS, before the wider gameplay layout:
	336.6 / 335.2 / 335.3 long, 23.6 tall, and 39.25 / 39.25 / 39.45 WIDE --
	all three were under the generic hall's 40. The v3 defaults are wider;
	`footprint()` measures the new templates and estate spacing grows with them.

	================================================================
	THE PART THE MOUNTS GET WRONG IF YOU TRUST THEM
	================================================================

	A kit's `Slot_0N` and `Piggy` anchors face INTO THE AISLE with their
	LookVector -- a character's convention. `HouseInterior.Plot.ground` is a
	MODEL frame, whose +Z is the front, because every model in this game is
	authored facing +Z and a piggy seated on it takes the frame as-is.
	Measured on the assembled treehouse: `Slot_01`'s LookVector points at the
	lane, so its ZVector points at the WALL. Seated straight onto the mount,
	every piggy in the building would face the wall. `groundFrame` is the half
	turn that fixes it, and it is written down once.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HouseInterior = require(ReplicatedStorage.Shared.HouseInterior)

local ThemedInterior = {}

--[[
	WHICH HOUSE HAS WHICH KIT, keyed by `Config.HOUSE_TIERS` id and read
	through a fallback.

	THE TABLE BELONGS IN `Config` and the fallback is what makes this file boot
	either way: `Config.HOUSE_INTERIOR_KITS` is the source when it exists, and
	the copy here is what a repo whose Config has not caught up runs on. The
	same shape `Config.HOUSE_MESH` and `Config.ANIMATIONS` already take for a
	row that has not landed yet -- a missing row is a house with the generic
	hall, never a house with no interior.

	The ids are the tiers' own: the Cardboard Fort is `shack` (the free
	starter), the Beehive Cottage is `cottage`, the Treehouse is `treehouse`.
]]
local KITS_FALLBACK: { [string]: string } = {
	shack = "CardboardFortInteriorKit",
	cottage = "BeehiveCottageInteriorKit",
	townhouse = "WonkyTownhouseInteriorKit",
	mushroom = "ToadstoolCottageInteriorKit",
	villa = "FairyLanternCottageInteriorKit",
	treehouse = "TreehouseInteriorKit",
	manor = "HauntedManorInteriorKit",
	slime = "GloopHouseInteriorKit",
	modern = "FishbowlHouseInteriorKit",
	neontower = "NeonTowerInteriorKit",
	crystal = "CrystalSpireInteriorKit",
	palace = "IcePalaceInteriorKit",
	skycastle = "SkyCastleInteriorKit",
	galleon = "BeachedGalleonInteriorKit",
	portal = "PortalHouseInteriorKit",
	thundercloud = "ThundercloudFortressInteriorKit",
	void = "TheVoidInteriorKit",
	goldenpig = "GoldenPiggyInteriorKit",
}

local function registry(): { [string]: string }
	local rows = (Config :: any).HOUSE_INTERIOR_KITS
	return if type(rows) == "table" then rows else KITS_FALLBACK
end

--[[
	EVERY KIT'S RoomShell CARRIES EXACTLY SIX `Slot_0N` ANCHORS, and that is
	the kits' own sentence: *"Six slots per room match the current
	configuration; changing that layout requires another template revision."*
	So a hand edit to `Config.INDOOR.plotsPerSide` is a room the ART cannot
	follow, and it has to say so at boot rather than quietly seating four
	piggies in a six-slot room or asking for a seventh that does not exist.
]]
ThemedInterior.SLOTS_PER_ROOM = 6

-- Every kit's own documented clear achievement wall, which is what
-- `Mount_Wall` stands on. Nothing draws on it today -- the in-house
-- achievement room was retired on 2026-09-22 and the display moves into this
-- base later -- so this is a marker for that reader, exactly as the generic
-- hall's is.
local WALL_MOUNT = Vector2.new(10, 6)

-- ============================================================
-- FINDING THE KITS
-- ============================================================

type Kit = {
	name: string,
	-- EACH KIT HAS ITS OWN Builder COPY, and it must: that module resolves
	-- `script.Parent.Templates`, so the one inside the cardboard fort's kit is
	-- the only one that can clone the cardboard fort's art.
	builder: any,
	templates: Instance,
}

local kits: { [string]: Kit? } = {}
local looked: { [string]: boolean } = {}
local said: { [string]: boolean } = {}

-- ONCE PER DISTINCT PROBLEM. Three kits missing is three houses that lose
-- their interior, so each says itself -- and none says itself twice a tick,
-- which is what a lazy resolve behind a poll would otherwise do.
local function say(message: string)
	if not said[message] then
		said[message] = true
		warn("[Interior] " .. message)
	end
end

--[[
	Resolve one kit by NAME under `ServerStorage`, or nil.

	BY NAME AND TAKING THE FIRST, because a name can exist twice: the project
	file maps all three and a kit can also be hand-inserted, so until
	`rojo serve` is restarted `ServerStorage` may hold two of one. Two copies
	of one kit are two identical art packages, so either builds the same hall
	-- but it is worth SAYING, because the one Rojo owns is the one that
	follows the repo and a stale hand-inserted twin is exactly the
	`GearPreview` trap this project records: state that lives in the place
	rather than in `src/`, where nothing reconciles it.
]]
-- A KIT ARRIVES WITH EVERY `PrimaryPart` REF DROPPED, AND THE KIT CANNOT
-- STAND WITHOUT THEM. Measured on 2026-09-23 with Rojo 7.7.0: the three
-- `.rbxmx` files each carry eighteen `<Ref name="PrimaryPart">` rows and the
-- Models that `rojo serve` put in ServerStorage read `PrimaryPart == nil` on
-- every one of them -- a Ref inside a model file does not survive the sync.
-- Everything in a kit hangs off that ref: `anchorOf` here and `anchor` in the
-- kit's own Builder read `model.PrimaryPart` to find the `Piggy`, `Entry`,
-- `Slot_0N` and `Door_Exit` attachments, and the Builder's `clone` does a
-- `PivotTo`, which on a Model with no PrimaryPart and no authored pivot (the
-- files carry no `WorldPivotData`) pivots about the bounding-box centre
-- rather than the Root every offset in the art was measured from. So the
-- first Play after the kits landed threw "the Pedestal template has no Piggy
-- anchor" on all three and every house fell back to the generic hall.
--
-- THE REPAIR IS THE AUTHORING CONVENTION READ BACK: every kit template's
-- primary part is the `BasePart` child called `Root` (the concept's own rule,
-- and what the Builder's assert message names), so a Model that has one and
-- no PrimaryPart is given it. Done ONCE, on the template tree in
-- ServerStorage, so every clone the Builder makes inherits it. Sub-models
-- with no `Root` -- the gate's six panels and its lock -- are left alone;
-- nothing reads their pivot, and `setGate` moves their parts off the GATE's
-- root. Said out loud in one line rather than silently, so a Rojo that starts
-- carrying the ref one day is visible as this count going to zero.
function ThemedInterior.repairTemplates(templates: Instance): number
	local repaired = 0
	for _, d in ipairs(templates:GetDescendants()) do
		if d:IsA("Model") and (d :: Model).PrimaryPart == nil then
			local root = d:FindFirstChild("Root")
			if root and root:IsA("BasePart") then
				(d :: Model).PrimaryPart = root :: BasePart
				repaired += 1
			end
		end
	end
	return repaired
end

local function resolve(name: string): Kit?
	if looked[name] then
		return kits[name]
	end
	looked[name] = true

	local holder: Instance? = nil
	local seen = 0
	for _, child in ipairs(ServerStorage:GetChildren()) do
		if child.Name == name then
			seen += 1
			if not holder then
				holder = child
			end
		end
	end

	if not holder then
		say(("no %s in ServerStorage, so that house gets the generic hall. "):format(name)
			.. "`default.project.json` maps it, but the project file is NOT hot reloaded -- "
			.. "restart `rojo serve` and press Play again.")
		return nil
	end
	if seen > 1 then
		say(("%d copies of %s in ServerStorage; taking the first. "):format(seen, name)
			.. "One of them is Rojo's and follows the repo; a hand-inserted twin does not.")
	end

	local module = (holder :: Instance):FindFirstChild("Builder")
	local templates = (holder :: Instance):FindFirstChild("Templates")
	if not module or not module:IsA("ModuleScript") or not templates then
		say(("%s carries no Builder/Templates pair, so that house gets the generic hall"):format(name))
		return nil
	end

	local ok, loaded = pcall(require, module)
	if not ok or type(loaded) ~= "table" or type((loaded :: any).build) ~= "function" then
		say(("%s's Builder would not load (%s), so that house gets the generic hall")
			:format(name, tostring(loaded)))
		return nil
	end

	if Config.INDOOR_ROOM_PLOTS ~= ThemedInterior.SLOTS_PER_ROOM then
		say(("the authored interiors' RoomShell has %d slot anchors and Config.INDOOR_ROOM_PLOTS is %d, ")
			:format(ThemedInterior.SLOTS_PER_ROOM, Config.INDOOR_ROOM_PLOTS)
			.. "so the art cannot follow the room size. Every house gets the generic hall "
			.. "until the templates are revised.")
		return nil
	end

	local repaired = ThemedInterior.repairTemplates(templates)
	if repaired > 0 then
		say(("%s arrived with %d template Models missing their PrimaryPart (Rojo drops the Ref); "):format(name, repaired)
			.. "each was given its Root part.")
	end

	local kit: Kit = { name = name, builder = loaded, templates = templates }
	kits[name] = kit
	return kit
end

-- The kit name registered for a house tier, or nil for a house with no
-- authored interior. All eighteen permanent houses are registered now.
function ThemedInterior.kitName(tier: any?): string?
	local id = type(tier) == "table" and tier.id
	return if type(id) == "string" then registry()[id] else nil
end

-- Does this house have an authored interior ON THIS SERVER? Both halves
-- matter: a house with no kit registered and a kit that is not synced both
-- answer no, and both mean the generic hall.
function ThemedInterior.available(tier: any?): boolean
	local name = ThemedInterior.kitName(tier)
	return name ~= nil and resolve(name) ~= nil
end

-- The PEDESTAL a house's interior kit is authored with, or nil.
--
-- THE LAWN READS THIS, WHICH IS WHY IT IS PUBLIC (designer, 2026-09-23: "no i
-- meant the ones outside to match the interior"). Every one of the eighteen
-- houses carries one `Pedestal` Model in its kit, and the six lawn plinths
-- were generic stone regardless of whether the house behind them was a
-- Starter Shack or a Sky Castle. Handing the same art out of the front door
-- is what makes a lawn read as belonging to its house.
--
-- ALREADY REPAIRED BY THE TIME ANYBODY SEES IT. `resolve` runs
-- `repairTemplates` over the whole templates tree, which is what gives every
-- kit Model back the `PrimaryPart` Rojo drops out of an `.rbxmx` -- so a caller
-- may pivot this clone by its `Root`, which is the frame every offset in the
-- art is measured from. Cloning one BEFORE that repair would turn it about
-- its bounding-box centre instead, silently.
--
-- FOUND RECURSIVELY AND BY NAME, because a kit is free to file its templates
-- under folders and two of them already do.
function ThemedInterior.pedestalTemplate(tier: any?): Model?
	local name = ThemedInterior.kitName(tier)
	local kit = if name then resolve(name) else nil
	if not kit then
		return nil
	end
	local found = kit.templates:FindFirstChild("Pedestal", true)
	return if found and found:IsA("Model") and (found :: Model).PrimaryPart
		then found :: Model
		else nil
end

-- The tier ids with a kit registered, sorted so a boot probe walks them in
-- the same order every time.
function ThemedInterior.houseIds(): { string }
	local ids = {}
	for id in pairs(registry()) do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

-- ============================================================
-- THE FRAMES, WHICH ARE THE WHOLE OF THE CONTRACT
-- ============================================================
--
-- PURE, AND EXPORTED FOR THAT REASON. Every one of these is arithmetic on
-- CFrames with no Instance in it, so the suite drives them with no engine at
-- all -- the same split `Config.crossedDoorway` already makes against the
-- CFrame work that feeds it.

--[[
	`Refs.origin`: the threshold, floor top at y = 0, +X DOWN THE HALL.

	The kits are authored with -Z forward and the generic hall with +X, so the
	one thing this has to do is state that turn ONCE. Built from the matrix
	rather than from `CFrame.lookAt`, for the reason `InteriorService.facing`
	gives: every recorded bug from that call is the correction forgotten in one
	direction or the other. Columns are Right, Up, Z, and X x Y = Z.

	`entry` is the vestibule's own `Entry` anchor -- which IS the CFrame the kit
	was built at, so its LookVector is down the hall -- and `at` is where the
	threshold stands, its `Door_Exit` mount.
]]
function ThemedInterior.originFrame(entry: CFrame, at: Vector3): CFrame
	local down = Vector3.new(entry.LookVector.X, 0, entry.LookVector.Z)
	if down.Magnitude < 1e-4 then
		down = Vector3.new(1, 0, 0)
	end
	down = down.Unit
	return CFrame.fromMatrix(at, down, Vector3.yAxis, down:Cross(Vector3.yAxis))
end

--[[
	`Refs.entrance`: where somebody arrives, on the floor, FACING DOWN THE HALL
	with a CHARACTER'S convention -- its front is its LookVector, which is the
	opposite of every model in this game.

	THE REACH IS CLAMPED OFF THE EXIT GATE'S OWN, AND THAT IS NOT A TASTE CALL.
	`InteriorService.exitGate` puts the crossing plane
	`Config.HOUSE_DOOR.exitReach` down the hall, and the boot assert refuses an
	arrival inside a stud of it -- because arriving there and stepping backwards
	walks straight back out through the door you came in. Every kit's authored
	`Arrival` is 3.5 studs inside its `Door_Exit`, which is INSIDE that reach,
	so it is honoured only where it is far enough and pushed to `exitReach + 3`
	otherwise. That is the generic hall's own 6.0 at the shipped reach of 3.0,
	so the two builders arrive the same distance in.
]]
function ThemedInterior.entranceFrame(origin: CFrame, arrival: number?): CFrame
	local floor = Config.HOUSE_DOOR.exitReach + 3
	local reach = math.max(floor, tonumber(arrival) or 0)
	return origin * CFrame.new(reach, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0)
end

--[[
	`Refs.plots[i].ground`: where a piggy stands, as a MODEL frame.

	`slot` is the room's own `Slot_0N` anchor and `lift` the `Pedestal`
	template's own `Piggy` offset off its Root -- READ FROM THE ART rather than
	pinned, so a revised stump carries the piggy with it. Then the half turn:
	see the header. The kits' anchors face the aisle with their LookVector and
	a model's front is its +Z.
]]
function ThemedInterior.groundFrame(slot: CFrame, lift: CFrame): CFrame
	return slot * lift * CFrame.Angles(0, math.pi, 0)
end

--[[
	`Refs.plots[i].collect`: where the collect pad stands, as a GROUND frame
	with its own +Z toward the lane.

	THE RULE IS `HouseInterior.INDOOR_PAD`'S OWN AND IT IS ONE RULE FOR BOTH
	BUILDERS: the pad's outer edge abuts the pedestal's footprint and it
	reaches `INDOOR_PAD.Z` toward the lane. `out` is that footprint, measured
	off the `Pedestal` TEMPLATE rather than pinned -- so a revised stump, or a
	collection plaque that sticks out further than this one's 3.82, carries its
	own pad with it.

	THE HALF TURN FIRST, WHICH IS THE WHOLE OF THE ARITHMETIC. A kit's
	`Slot_0N` faces the aisle with its LookVector, which is -Z, so the
	pedestal's own footprint reaches into ITS -Z and the turned frame's +Z is
	the way out toward the lane. See the header: seated straight onto the
	mount, every piggy in the building would face the wall.
]]
function ThemedInterior.collectFrame(slot: CFrame, out: number): CFrame
	return slot * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, 0, out)
end

--[[
	`Refs.plots[i].cash`: the pedestal's lane-facing surface at reading height,
	+Z toward the lane, BEFORE the sign's own standoff.

	`cash` is the `Pedestal` template's own `CashLabel` attachment, which is
	what the concept authored the readout mount for -- so the figure lands
	where the art asked for it rather than where this file would have guessed.
	Two of the three kits author theirs a little inside the stump's own radius,
	which is why `IndoorPedestal` stands the sign off it rather than on it.
]]
function ThemedInterior.cashFrame(slot: CFrame, cash: CFrame): CFrame
	return slot * cash * CFrame.Angles(0, math.pi, 0)
end

-- Plot 1..56 from a room and a slot, in the same dense front-to-back order the
-- generic hall and the lawn's own grid use. It is each kit's own `PlotIndex`
-- attribute expression, read off `Config` rather than repeated.
function ThemedInterior.plotIndexOf(room: number, slot: number): number
	return (room - 1) * Config.INDOOR_ROOM_PLOTS + slot
end

--[[
	THE REBIRTH COUNT THAT OPENS EXACTLY THE ROOMS THIS CAPACITY REACHES.

	A kit's gates are driven by rebirths and `HouseInterior.setCapacity` is
	driven by plots, and `InteriorService` only ever has the plot count in
	hand. This is the one conversion, and it is the ladder's own inverse rather
	than a second table -- see the header.
]]
function ThemedInterior.gateRebirths(plots: number?): number
	return Config.indoorDoorRebirths(Config.indoorRooms(plots)) or 0
end

-- How many DOORS a hall of this many rooms has. A kit builds a gate after
-- every room, including a terminal end cap at the far end of the last one;
-- the generic hall builds a cross wall BETWEEN rooms and a solid far wall. So
-- the doors are the gates between built rooms, and the counts match.
function ThemedInterior.doorCount(rooms: number): number
	return math.max(0, math.floor(rooms) - 1)
end

-- ============================================================
-- READING THE ART
-- ============================================================

local function anchorOf(model: Instance, name: string): Attachment?
	local root = (model :: any).PrimaryPart
	local found = root and root:FindFirstChild(name)
	return if found and found:IsA("Attachment") then found else nil
end

-- A part's half-extent along each axis of `local_`, projected through its own
-- CFrame. MEASURED PER PART AND NEVER OFF A MODEL'S BOUNDING BOX, which is
-- oriented by the model's pivot and transposes extents -- this project has
-- paid for that twice, once recording the Sky Castle as 16.6 studs too wide
-- when it was measuring orbiting shards at altitude.
local function halfExtent(local_: CFrame, size: Vector3): Vector3
	local r, u, l = local_.RightVector, local_.UpVector, local_.LookVector
	return Vector3.new(
		math.abs(r.X) * size.X / 2 + math.abs(u.X) * size.Y / 2 + math.abs(l.X) * size.Z / 2,
		math.abs(r.Y) * size.X / 2 + math.abs(u.Y) * size.Y / 2 + math.abs(l.Y) * size.Z / 2,
		math.abs(r.Z) * size.X / 2 + math.abs(u.Z) * size.Y / 2 + math.abs(l.Z) * size.Z / 2)
end

-- One template's own extent, in its Root's frame, which is the frame its mount
-- positions are authored in.
local function extentOf(template: Instance): (Vector3, Vector3)
	local root = (template :: any).PrimaryPart
	local base: CFrame = if root then root.CFrame else (template :: any):GetPivot()
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, d in ipairs(template:GetDescendants()) do
		if d:IsA("BasePart") then
			local at = base:ToObjectSpace(d.CFrame)
			local h = halfExtent(at, d.Size)
			lo = Vector3.new(math.min(lo.X, at.Position.X - h.X),
				math.min(lo.Y, at.Position.Y - h.Y), math.min(lo.Z, at.Position.Z - h.Z))
			hi = Vector3.new(math.max(hi.X, at.Position.X + h.X),
				math.max(hi.Y, at.Position.Y + h.Y), math.max(hi.Z, at.Position.Z + h.Z))
		end
	end
	return lo, hi
end

-- One kit's own footprint at the rebirth ceiling, in the generic hall's
-- convention: X down the hall, Y up, Z across.
local function kitFootprint(kit: Kit): Vector3?
	local lobby = kit.templates:FindFirstChild("AchievementVestibule")
	local room = kit.templates:FindFirstChild("RoomShell")
	local gate = kit.templates:FindFirstChild("RebirthGate")
	if not lobby or not room or not gate then
		return nil
	end
	local entry = anchorOf(lobby, "Entry")
	local roomEntry, roomExit = anchorOf(room, "Entry"), anchorOf(room, "Exit")
	if not entry or not roomEntry or not roomExit then
		return nil
	end
	-- A kit runs along -Z, so a piece's hall-x is its own origin's hall-x less
	-- its root-local z, and the vestibule's `Entry` is the outer entrance.
	local step = math.abs(roomExit.CFrame.Position.Z - roomEntry.CFrame.Position.Z)
	local base = entry.CFrame.Position.Z

	local x0, x1 = math.huge, -math.huge
	local width, top, bottom = 0, -math.huge, math.huge
	local function add(template: Instance, origin: number)
		local lo, hi = extentOf(template)
		x0 = math.min(x0, origin - hi.Z)
		x1 = math.max(x1, origin - lo.Z)
		width = math.max(width, math.abs(lo.X), math.abs(hi.X))
		top = math.max(top, hi.Y)
		bottom = math.min(bottom, lo.Y)
	end
	add(lobby, base)
	for r = 1, Config.indoorRoomCeiling() do
		add(room, base + (r - 1) * step)
		add(gate, base + r * step)
	end
	return Vector3.new(x1 - x0, top - bottom, width * 2)
end

local footprint: Vector3? = nil

--[[
	How much room one hall takes up, in the SAME convention
	`HouseInterior.footprint` uses.

	THE LARGEST OF EVERY REGISTERED KIT, because `InteriorService` spaces ONE
	estate that holds halls of both kinds and the pitch has to clear whichever
	a plot's house happens to want. DERIVED FROM THE TEMPLATES, never pinned: a
	pinned footprint puts two halls through each other the first time the art
	or the rebirth ladder moves, with nothing in any log, which is
	`SHOP_BANK_PIG_SECONDS` wrong by 62% on its first audited boot one system
	along.

	Measured on the original v1 kits at the rebirth-20 ceiling: 336.6 / 335.2 /
	335.3 long and 39.25 / 39.25 / 39.45 wide, against the generic hall's 40 --
	the wider v3 kits now determine the estate width through this same function.
]]
function ThemedInterior.footprint(): Vector3
	if footprint then
		return footprint :: Vector3
	end
	local widest = HouseInterior.footprint()
	for _, id in ipairs(ThemedInterior.houseIds()) do
		local name = registry()[id]
		local kit = name and resolve(name)
		local one = kit and kitFootprint(kit)
		if one then
			widest = Vector3.new(
				math.max(widest.X, one.X), math.max(widest.Y, one.Y), math.max(widest.Z, one.Z))
		end
	end
	footprint = widest
	return widest
end

-- ============================================================
-- THE MARKERS THE GENERIC HALL HAS AND THE ART DOES NOT
-- ============================================================

local function marker(parent: Instance, name: string, size: Vector3, at: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = at
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Parent = parent
	return p
end

--[[
	`Refs.plots[i].face` and `.surround`, one pair per slot, INVISIBLE AND
	PERMANENT.

	The generic hall's plot is a visible tile that goes dark when it is locked.
	A kit's is the PEDESTAL, and the concept is explicit that an unavailable
	slot has *"the entire pedestal and its collection plate"* removed,
	*"leaving a finished floor rather than a hole"* -- so the lock is an ABSENCE
	in here and there is no tile to recolour.

	What the generic hall's face ALSO gives, and the reason these exist, is an
	addressable part per plot: *"a client handed this part by a prompt can say
	which plot it is with no lookup"*. A marker keeps that for a slot whose
	stump is not standing, keeps `face`/`surround` from ever being nil -- which
	is what makes the two builders' `Plot` genuinely one type -- and costs 12
	parts at rebirth 0 against four hundred.
]]
local function ensureMarkers(room: Model, index: number, roomIndex: number, slot: Attachment): (Part, Part)
	local folder = room:FindFirstChild("Plots")
	if not folder then
		local made = Instance.new("Folder")
		made.Name = "Plots"
		made.Parent = room
		folder = made
	end
	local held = folder :: Instance
	local faceName = ("PlotFace_%02d"):format(index)
	local surroundName = ("PlotSurround_%02d"):format(index)
	local existing = held:FindFirstChild(faceName)
	if existing then
		return existing :: Part, held:FindFirstChild(surroundName) :: Part
	end
	local at = slot.WorldCFrame
	local surround = marker(held, surroundName, Vector3.new(6.4, 0.2, 6.4), at)
	local face = marker(held, faceName, Vector3.new(5.6, 0.2, 5.6), at * CFrame.new(0, 0.2, 0))
	face:SetAttribute("Plot", index)
	face:SetAttribute("Room", roomIndex)
	surround:SetAttribute("Plot", index)
	return face, surround
end

--[[
	`Refs.exit`: `InteriorService.exitGate` reads its `Size.Z` as the aperture
	the crossing counts in and its `Size.Y` as the headroom. A kit publishes
	`Door_Exit` as a MOUNT rather than a part, so the marker carries the
	numbers -- and they are MEASURED OFF THE ART, the same call
	`InteriorService.doorAnchor` already makes when it takes a house's real
	doorway from `HouseDoorHinge_L`/`_R` rather than from a constant. All three
	kits name those parts `EntryDoorJamb` and `EntryLintel`; checked.

	The fallback is `Config.HOUSE_DOOR`'s own pair, which is NARROWER than a
	kit's real 8.35-stud opening -- and that is the safe direction for the same
	reason Config gives for its own fallback width: a band wider than the
	doorway fires a crossing on somebody walking along the wall, where a
	narrower one only ever refuses somebody hugging a jamb, and they can step
	across. FAIL TOWARD THE REFUSAL.
]]
local function buildExit(lobby: Model, entry: CFrame, origin: CFrame): (Part, number, number)
	local half = Config.HOUSE_DOOR.halfWidth
	local height = Config.HOUSE_DOOR.headroom

	local inner = math.huge
	local lintel: number? = nil
	for _, d in ipairs(lobby:GetDescendants()) do
		if d:IsA("BasePart") then
			if d.Name == "EntryDoorJamb" then
				local at = entry:ToObjectSpace(d.CFrame)
				inner = math.min(inner, math.abs(at.Position.X) - halfExtent(at, d.Size).X)
			elseif d.Name == "EntryLintel" then
				local at = entry:ToObjectSpace(d.CFrame)
				lintel = math.min(lintel or math.huge, at.Position.Y - halfExtent(at, d.Size).Y)
			end
		end
	end
	if inner < math.huge and inner > 0 then
		half = inner
	end
	if lintel and lintel > height then
		height = lintel
	end

	local exit = marker(lobby, "Door_Exit", Vector3.new(0.5, height, half * 2),
		origin * CFrame.new(0, height / 2, 0))
	return exit, half, height
end

-- ============================================================
-- BUILDING
-- ============================================================

-- THE `Pedestal` TEMPLATE'S THREE MOUNTS AND ITS FOOTPRINT, read off the art
-- ONCE per hall rather than per plot. All four are facts about the template,
-- so re-reading them per slot would be 56 identical lookups -- and it is the
-- template rather than a CLONE deliberately: a locked station has no clone to
-- read, so a pad derived from one could only ever exist where a pad already
-- did.
type Mounts = {
	-- `Piggy`: where a piggy stands, off the Root. See `groundFrame`.
	lift: CFrame,
	-- `CashLabel`: the readout's own surface. See `cashFrame`.
	cash: CFrame,
	-- How far the pedestal's own geometry reaches toward the LANE, plus half
	-- the pad. See `collectFrame`.
	collectOut: number,
}

type Hall = {
	hall: any,
	builder: any,
	kit: string,
	-- The `Pedestal` template's own mounts, read from the art once.
	mounts: Mounts,
	-- FORCED-OPEN GATES, per room. A kit has no per-gate call of its own --
	-- `setGate` is local to its Builder and this file does not fork a kit -- so
	-- `setDoor` writes here and refreshes through the kit's OWN `setRebirths`,
	-- which is the one place the panel poses are computed. A second copy of
	-- that arithmetic over here is the duplicate this project keeps recording.
	forced: { [number]: boolean },
}

-- Keyed by the Model rather than held on the Refs, so `Refs` stays exactly the
-- shape `HouseInterior` publishes and nothing iterating it meets a field the
-- other builder has never heard of. STRONG, with an explicit release on
-- destroy: a weak table keyed on an Instance drops its entry while the engine
-- still holds the object, which this project has measured.
local halls: { [Instance]: Hall } = {}

local function indexHall(refs: HouseInterior.Refs, held: Hall)
	local hall = held.hall
	table.clear(refs.plots)
	table.clear(refs.doors)
	refs.rooms = #hall.rooms

	for roomIndex, room in ipairs(hall.rooms) do
		for slotIndex = 1, Config.indoorPlotsInRoom(roomIndex) do
			local slot = anchorOf(room, ("Slot_%02d"):format(slotIndex))
			if slot then
				local index = ThemedInterior.plotIndexOf(roomIndex, slotIndex)
				local face, surround = ensureMarkers(room, index, roomIndex, slot)
				local at = slot.WorldCFrame
				local mounts = held.mounts
				table.insert(refs.plots, {
					index = index,
					room = roomIndex,
					ground = ThemedInterior.groundFrame(at, mounts.lift),
					collect = ThemedInterior.collectFrame(at, mounts.collectOut),
					cash = ThemedInterior.cashFrame(at, mounts.cash),
					face = face,
					surround = surround,
					unlocked = index <= refs.capacity,
				})
			end
		end
	end

	-- ONLY THE GATES BETWEEN BUILT ROOMS. The last one is the kit's end cap:
	-- the generic hall answers the far end with a solid wall and has no door
	-- there, and a door in this list that nothing can ever open would be the
	-- promise-something-that-is-not-there failure the room cadence is written
	-- to avoid.
	for gateIndex = 1, ThemedInterior.doorCount(#hall.rooms) do
		local gate = hall.gates[gateIndex]
		if gate then
			local leaves: { BasePart } = {}
			local labels: { SurfaceGui } = {}
			for _, d in ipairs(gate:GetDescendants()) do
				if d:IsA("BasePart") and d.Parent and d.Parent.Name:sub(1, 6) == "Panel_" then
					table.insert(leaves, d)
				elseif d:IsA("SurfaceGui") then
					table.insert(labels, d)
				end
			end
			table.insert(refs.doors, {
				room = gateIndex + 1,
				rebirths = Config.indoorDoorRebirths(gateIndex + 1) or 0,
				leaves = leaves,
				labels = labels,
				-- EMPTY, AND THAT IS THE HONEST ANSWER. The generic hall keeps
				-- both poses so `setDoor` can write a leaf's CFrame; a kit
				-- stores its own closed pose as a `ClosedLocal` attribute on
				-- each panel and derives the open one, so there is nothing here
				-- for a caller to write and inventing a pair would be a second
				-- description of the kit's own gate.
				shut = {},
				open = {},
				isOpen = gate:GetAttribute("Open") == true,
			})
		end
	end
end

-- Everything after the art has been cloned: the frames, the markers and
-- the index. Its own function, declared ABOVE its reader, so that `build`
-- below can undo a failure -- see the note there.
local function finish(hall: any, builder: any, kit: Kit, tier: any?, mounts: Mounts,
	forced: { [number]: boolean }, opening: number): HouseInterior.Refs
	local lobby = hall.lobby
	local entryAnchor = assert(anchorOf(lobby, "Entry"), "the vestibule has no Entry anchor")
	local doorExit = assert(anchorOf(lobby, "Door_Exit"), "the vestibule has no Door_Exit anchor")
	local arrival = anchorOf(lobby, "Arrival")
	local wall = anchorOf(lobby, "Achievements")

	local entry = entryAnchor.WorldCFrame
	local origin = ThemedInterior.originFrame(entry, doorExit.WorldCFrame.Position)
	local reach = if arrival then origin:PointToObjectSpace(arrival.WorldCFrame.Position).X else nil

	local exit, half, height = buildExit(lobby, entry, origin)

	-- THE PORTAL IN THE WAY OUT, the generic hall's own function on different
	-- geometry. Seated so its far face stops just short of the exit gate's
	-- plane, which is what puts a character INSIDE the light as they cross --
	-- and its depth is read back off the part rather than copied, because
	-- `PORTAL_DEPTH` is private to that module and a second copy of it would
	-- drift the first time either moved.
	local portal = HouseInterior.buildPortal(lobby,
		origin * CFrame.Angles(0, math.pi / 2, 0), half - 0.2, height - 0.4)
	portal.CFrame = portal.CFrame + origin.XVector * (Config.HOUSE_DOOR.exitReach - portal.Size.Z / 2 - 0.2)

	local mount = marker(lobby, "Mount_Wall", Vector3.new(WALL_MOUNT.X, WALL_MOUNT.Y, 0.3),
		if wall then wall.WorldCFrame else origin)

	local refs: HouseInterior.Refs = {
		model = hall.model,
		origin = origin,
		entrance = ThemedInterior.entranceFrame(origin, reach),
		plots = {},
		doors = {},
		rooms = #hall.rooms,
		capacity = 0,
		mount = mount,
		exit = exit,
		portal = portal,
		-- EMPTY ON PURPOSE. A themed interior's palette IS the house it belongs
		-- to -- that is the whole of what the concept's theme table buys -- so
		-- there is no joinery here for a tier to recolour. The field stays so
		-- the two `Refs` are one shape and `dress` below is the same call on
		-- both.
		painted = { accent = {}, accentDeep = {} },
		theme = HouseInterior.themeOf(tier),
	}

	local held: Hall = {
		hall = hall, builder = builder, kit = kit.name, forced = forced, mounts = mounts,
	}
	halls[refs.model] = held
	refs.model.Destroying:Connect(function()
		halls[refs.model] = nil
	end)

	-- THE KIT HAS ALREADY UNLOCKED THE PREFIX IT WAS BUILT WITH, so the
	-- capacity is RECORDED rather than re-applied. `HouseInterior.build` ends
	-- with `setCapacity(refs, 0)` because its plots are tiles it recolours;
	-- doing the same here would destroy every stump the call above just cloned
	-- and leave the caller's own `setCapacity` to clone them back -- up to
	-- 1,456 parts of churn for no change in outcome. Nothing reads `capacity`
	-- between a build and the `setCapacity` that follows it.
	refs.capacity = opening
	indexHall(refs, held)
	return refs
end

--[[
	Build the hall. Same signature as `HouseInterior.build`.

	WHICH KIT COMES OFF THE `tier` THIS ALREADY TAKES, so the signature does
	not have to grow an argument the generic hall would ignore -- and the
	registry is consulted in exactly one place.

	`rooms` is the PREFIX, exactly as it is there: `InteriorService` builds only
	what a save has unlocked and rebuilds when it grows. A kit's `setCapacity`
	is what builds a prefix (*"builds the required room prefix and updates the
	individual stations"*), so the room count is asked for as the capacity that
	reaches it -- clamped to the ceiling, or the last room would stand six
	stumps where the ladder has two for the frame between this call and
	`setCapacity` below it.
]]
function ThemedInterior.build(parent: Instance, at: CFrame, tier: any?, rooms: number?): HouseInterior.Refs
	local name = ThemedInterior.kitName(tier)
	local kit = name and resolve(name)
	assert(kit, "no authored interior kit for this house on this server")
	local held0 = kit :: Kit
	local builder = held0.builder

	local ceiling = Config.indoorRoomCeiling()
	local count = math.clamp(math.floor(tonumber(rooms) or ceiling), 1, ceiling)
	local per = Config.INDOOR_ROOM_PLOTS
	local opening = math.min(count * per, Config.indoorPlotCeiling())

	local pedestal = assert(held0.templates:FindFirstChild("Pedestal"), "the kit has no Pedestal template")
	local lift = assert(anchorOf(pedestal, "Piggy"), "the Pedestal template has no Piggy anchor")
	-- AND THE OTHER TWO MOUNTS, WHICH ARE WHAT A PLACEMENT NEEDS AND WHAT
	-- NOTHING READ UNTIL NOW. `Pedestal.Collect` is the collection plaque and
	-- `Pedestal.CashLabel` the readout above it -- both authored on all three
	-- kits, and both dead in the art until a pad and a sign stood on them.
	--
	-- ASSERTED RATHER THAN DEFAULTED, the same call the `Piggy` anchor makes:
	-- a kit whose templates have been revised without them is a kit that
	-- cannot carry a collection, and `build`'s own caller falls back to the
	-- generic hall on a throw. A guessed offset would be a pad standing in the
	-- middle of the aisle with nothing in any log.
	local cash = assert(anchorOf(pedestal, "CashLabel"),
		"the Pedestal template has no CashLabel anchor")
	-- HOW FAR THE PEDESTAL REACHES TOWARD THE LANE, measured per part through
	-- each part's own CFrame -- never off a Model's bounding box, which is
	-- oriented by the pivot and transposes extents. The lane is the
	-- template's own -Z (its Root is seated on a `Slot_0N` whose LookVector
	-- faces the aisle), so it is `-lo.Z`: 3.82 on the Treehouse and the
	-- Cardboard Fort and 3.57 on the Beehive Cottage, which is the collection
	-- plaque rather than the stump.
	local lo = extentOf(pedestal)
	local mounts: Mounts = {
		lift = lift.CFrame,
		cash = cash.CFrame,
		collectOut = -lo.Z + HouseInterior.INDOOR_PAD.Z / 2,
	}

	-- THE KIT'S OWN REQUIREMENT CALLBACK IS THE GAME'S LADDER, which is what
	-- every kit's README asks for by name -- so the number a locked gate PRINTS
	-- and the rebirth count it actually opens at are one expression, which is
	-- the whole of why `Config.indoorDoorRebirths` exists. `forced` is what
	-- `setDoor` writes and nothing else consults it; it is closed over here so
	-- the kit holds it from its first gate refresh rather than being handed a
	-- second callback afterwards.
	local forced: { [number]: boolean } = {}
	local hall = builder.build(parent, at, {
		capacity = opening,
		rebirths = 0,
		requirement = function(room: number): number?
			if forced[room] then
				return 0
			end
			return Config.indoorDoorRebirths(room)
		end,
	})

	-- FROM HERE ON A THROW HAS TO TAKE THE HALL WITH IT. A kit's Builder
	-- parents its model BEFORE it clones anything into it -- the generic hall
	-- parents at the very end -- so an assert below would otherwise leave a
	-- half-built interior standing in the estate folder for the life of the
	-- server, with nobody holding a reference to clean it up. That is the
	-- `GearPreview` shape: state nothing reconciles.
	local ok, refsOrError = pcall(finish, hall, builder, held0, tier, mounts, forced, opening)
	if not ok then
		pcall(function()
			hall.model:Destroy()
		end)
		error(refsOrError, 0)
	end
	return refsOrError :: HouseInterior.Refs
end


-- ============================================================
-- STATE
-- ============================================================

--[[
	How many plots are standing, and therefore which gates are open. ONE NUMBER
	IN, BOTH ANSWERS OUT, exactly as `HouseInterior.setCapacity` puts it -- a
	caller passes `Config.indoorPlots(rebirths)` and decides neither half
	itself.

	The kit does the work: `setCapacity` unlocks a contiguous prefix of stations
	and `setRebirths` refreshes every gate off the requirement callback. The
	conversion from plots to rebirths is `gateRebirths`, which is the ladder's
	own inverse -- see the header.
]]
function ThemedInterior.setCapacity(refs: HouseInterior.Refs, plots: number)
	local held = halls[refs.model]
	if not held then
		return
	end
	local cap = math.max(0, math.floor(tonumber(plots) or 0))
	refs.capacity = cap
	local before = #held.hall.rooms
	held.builder.setCapacity(held.hall, cap)
	held.builder.setRebirths(held.hall, ThemedInterior.gateRebirths(cap))
	if #held.hall.rooms ~= before then
		-- `setCapacity` grows a hall rather than shrinking one, so this only
		-- fires if somebody asks for more than was built. `InteriorService`
		-- rebuilds instead, so it should never; re-indexing rather than leaving
		-- a stale list is the cheap half of being wrong about that.
		indexHall(refs, held)
	end
	for _, plot in ipairs(refs.plots) do
		plot.unlocked = plot.index <= cap
	end
	for _, door in ipairs(refs.doors) do
		local gate = held.hall.gates[door.room - 1]
		door.isOpen = gate ~= nil and gate:GetAttribute("Open") == true
	end
end

--[[
	Open one gate, or hand it back to the ladder.

	Separate from `setCapacity` for the reason the generic hall gives: a
	pursuing officer routed through a door will want one open for the length of
	a chase without touching what a player owns.

	`false` RETURNS A GATE TO THE LADDER RATHER THAN FORCING IT SHUT, which is
	the one place this differs from `HouseInterior.setDoor`. A kit's gate state
	is a function of the rebirth ladder, forcing one shut against a player's own
	progress is not a need anybody has stated, and a forced-shut gate would
	print a rebirth count that is not the ladder's -- which is the
	door-says-one-thing-and-does-another failure `indoorDoorRebirths` exists to
	make impossible.
]]
function ThemedInterior.setDoor(door: HouseInterior.Door, open: boolean)
	-- WHOSE GATE. The signature is the generic hall's, which carries no hall
	-- handle, so the owner is found from the one thing the door does hold: a
	-- leaf, which is a descendant of exactly one hall's model.
	local leaf = door.leaves[1]
	if not leaf then
		return
	end
	for model, held in pairs(halls) do
		if leaf:IsDescendantOf(model) then
			held.forced[door.room] = if open then true else nil
			held.builder.setRebirths(held.hall, held.hall.rebirths)
			local gate = held.hall.gates[door.room - 1]
			door.isOpen = gate ~= nil and gate:GetAttribute("Open") == true
			return
		end
	end
end

-- Re-theme for a house tier. NOTHING IS REPAINTED: see `painted` above. The
-- call exists so the two builders are one interface, and it still re-applies
-- capacity for the reason the generic hall's does.
function ThemedInterior.dress(refs: HouseInterior.Refs, tier: any?)
	refs.theme = HouseInterior.themeOf(tier)
	ThemedInterior.setCapacity(refs, refs.capacity)
end

function ThemedInterior.plotGround(refs: HouseInterior.Refs, index: number): CFrame?
	local plot = refs.plots[index]
	return if plot then plot.ground else nil
end

return ThemedInterior
