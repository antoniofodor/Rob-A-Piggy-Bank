--!strict
--[[
	InteriorService

	The front door: walking into a house puts you in its hallway, and walking
	out of the hallway puts you back on your own lawn.

	docs/PIGGY-COLLECTION-BUILD-ORDER.md Stage 4, and plan section 6.

	================================================================
	AN INTERIOR IS A DETACHED ROOM, SO A DOOR IS A TELEPORT
	================================================================

	`Shared/HouseInterior` builds one fixed hallway per owner, off the map
	entirely (`Config.INDOOR_ESTATE`), and nothing about it is inside the
	house model standing on the lawn. So the crossing cannot be a hole in a
	wall: it is a server-authoritative CFrame write with a mask over it, which
	is the same trick `PoliceService.releaseHome` already does when it puts a
	thief back at their own gate under an opaque arrest card.

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
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local HouseInterior = require(ReplicatedStorage.Shared.HouseInterior)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

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
	plot: any,
	owner: Player?,
	rooms: number,
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
	local pitch = HouseInterior.footprint().Z + estate.gap
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

local function destroyHome(index: number)
	local home = homes[index]
	if not home then
		return
	end
	home.refs.model:Destroy()
	homes[index] = nil
end

-- Build, or rebuild, the hallway behind one plot's door.
--
-- A REBUILD IS A DESTROY AND NOT A RESIZE, which is safe today and will not
-- be forever: nothing stands on an indoor plot yet, so there is nothing to
-- lose. The moment a piggy is seated in here, growing a hallway has to become
-- an extension rather than a replacement -- `HouseInterior.dress` already
-- makes that argument about a re-theme, in as many words.
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
	local home = homes[plot.index]

	if home and home.owner == owner and home.rooms >= rooms then
		HouseInterior.setCapacity(home.refs, capacity)
		return home
	end
	destroyHome(plot.index)

	local ok, built = pcall(function()
		return HouseInterior.build(ensureFolder(), estateCFrame(plot.index),
			Config.getShownHouse(data), rooms)
	end)
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

	HouseInterior.setCapacity(refs, capacity)
	local fp = HouseInterior.footprint()
	home = {
		refs = refs,
		plot = plot,
		owner = owner,
		rooms = rooms,
		gate = InteriorService.exitGate(refs),
		-- Generous on every axis: this box is only ever asked "has somebody
		-- left by some other route", so it wants to answer NO for anybody who
		-- is genuinely still in the building and never to be a second opinion
		-- about the exit.
		half = Vector3.new(fp.X + 20, fp.Y + 20, fp.Z + 20),
	}
	homes[plot.index] = home
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
		inside[player] = nil
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
	-- THE BOOT ASSERTS, AND THEY ARE HERE RATHER THAN IN CONFIG BECAUSE THIS
	-- IS WHERE BOTH HALVES EXIST. `Config.auditHouseDoor` can check the door's
	-- own numbers against each other; only a built room can say whether the
	-- way out stands clear of the spot somebody arrives on, or whether the
	-- quarter turn that makes the exit gate points the way this file claims.
	for _, problem in ipairs(Config.auditHouseDoor()) do
		warn("[Interior] " .. problem)
	end

	local probe = HouseInterior.build(ensureFolder(), estateCFrame(0), nil, 1)
	local gate = InteriorService.exitGate(probe)
	local entrance = gate.frame:PointToObjectSpace(probe.entrance.Position)
	if entrance.Z <= 1.0 then
		warn(("[Interior] the way out at %.1f studs is on top of the spot somebody arrives on "
			.. "(%.2f clear), so walking in would walk straight back out")
			:format(Config.HOUSE_DOOR.exitReach, entrance.Z))
	end
	-- The quarter turn, provoked rather than trusted: a mover walking back
	-- toward the hallway's threshold is moving along the gate's -Z, so the
	-- corridor's own direction has to read +1 on the gate's Z.
	local along = gate.frame:VectorToObjectSpace(probe.origin.XVector)
	if along.Z < 0.99 then
		warn(("[Interior] the exit gate is turned the wrong way: the corridor reads (%.2f, %.2f, %.2f) in it")
			:format(along.X, along.Y, along.Z))
	end
	-- And that arriving faces DOWN the corridor rather than at the door you
	-- came through. `entrance` is aimed with a character's own convention, so
	-- it is the LookVector that has to agree.
	local look = probe.origin:VectorToObjectSpace(probe.entrance.LookVector)
	if look.X < 0.99 then
		warn(("[Interior] arriving faces (%.2f, %.2f, %.2f) rather than down the hallway")
			:format(look.X, look.Y, look.Z))
	end
	probe.model:Destroy()

	PlotService.onRelease(function(plot)
		evict(plot.index)
		gates[plot.index] = nil
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastAt[player] = nil
		inside[player] = nil
		latched[player] = nil
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
