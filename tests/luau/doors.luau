-- The front door: walking into a house, and walking back out of the hallway.
-- docs/PIGGY-COLLECTION-BUILD-ORDER.md Stage 4.
--
-- WHAT IS HERE AND WHAT IS NOT. The DECISION -- did this step cross a doorway
-- -- is plain arithmetic on three numbers and is driven here against the real
-- `Config.crossedDoorway`. The CFrame work that produces those numbers needs
-- an engine, so it is driven against a stubbed one outside this runner and the
-- figures are in the change's own report; what this suite can still do about
-- it is read the source and refuse the things that would make it silently
-- wrong -- a client-side teleport, a second copy of the mask's timings, a
-- module nobody starts.
local Config, SOURCES = ...
local checks = 0
local function check(ok, message) assert(ok, message); checks += 1 end

local function at(x, y, z)
	return { X = x, Y = y, Z = z }
end

-- ---- THE DECISION -----------------------------------------------------------
local SPEC = { halfWidth = 3.0, underfoot = 2.0, headroom = 8.0 }

check(Config.crossedDoorway(at(0, 3, 2), at(0, 3, -2), SPEC),
	"a step straight through the middle of a doorway crosses it")
check(not Config.crossedDoorway(at(0, 3, 2), at(0, 3, 0.5), SPEC),
	"stopping short of the plane does not cross it")
check(not Config.crossedDoorway(at(0, 3, -0.5), at(0, 3, -2), SPEC),
	"a step that starts inside does not cross again")

-- ONE-WAY BY CONSTRUCTION, which is what stops the two gates of one crossing
-- fighting over a single step.
check(not Config.crossedDoorway(at(0, 3, -2), at(0, 3, 2), SPEC),
	"walking back out through the same gate does not count as coming in")

-- ---- A SEGMENT, NOT A POINT -------------------------------------------------
-- The tick rate is latency rather than correctness, and this is the property
-- that makes that true: a step that leaps clean over the doorway still counts.
check(Config.crossedDoorway(at(0, 3, 40), at(0, 3, -40), SPEC),
	"a step that jumps the whole plane in one tick still crosses it")

-- ---- THE OPENING ------------------------------------------------------------
-- WHERE IT PIERCES, not where either end of the step happened to be. Somebody
-- running diagonally is inside the opening at one end of a tick and past it at
-- the other, and only the pierce point answers which.
check(not Config.crossedDoorway(at(8, 3, 2), at(8, 3, -2), SPEC),
	"a step eight studs off the centre line walks past the wall instead")
check(Config.crossedDoorway(at(6, 3, 2), at(-6, 3, -2), SPEC),
	"a diagonal that is outside the opening at BOTH ends still crosses if it pierces inside it")
check(not Config.crossedDoorway(at(-2.9, 3, 0.1), at(20, 3, -0.1), SPEC),
	"a diagonal that is inside the opening at one end and pierces outside it does not")
check(Config.crossedDoorway(at(2.99, 3, 2), at(2.99, 3, -2), SPEC),
	"hugging the jamb still crosses")
check(not Config.crossedDoorway(at(3.01, 3, 2), at(3.01, 3, -2), SPEC),
	"a hair outside the jamb does not")

-- ---- THE HEIGHT BAND --------------------------------------------------------
-- MEASURED AGAINST A ROOT AND NOT A PAIR OF FEET. A character's
-- HumanoidRootPart stands about three studs above whatever it is on, which is
-- why the band reaches well above the threshold rather than sitting on it.
check(Config.crossedDoorway(at(0, 0, 2), at(0, 0, -2), SPEC),
	"a crossing at the threshold itself counts")
check(not Config.crossedDoorway(at(0, 13.5, 2), at(0, 13.5, -2), SPEC),
	"a door thirteen studs overhead is not walked through from the ground")
check(not Config.crossedDoorway(at(0, -6, 2), at(0, -6, -2), SPEC),
	"and neither is one thirteen studs below")

-- ---- NONSENSE IS REFUSED RATHER THAN THROWN ---------------------------------
check(not Config.crossedDoorway(nil, at(0, 0, -1), SPEC), "a missing end refuses")
check(not Config.crossedDoorway(at(0, 0, 1), at(0, 0, -1), nil), "a missing spec refuses")
check(not Config.crossedDoorway(at(0, 0, 1), at(0, 0, -1), {}),
	"a spec with no width is a doorway nobody fits through")

-- ---- THE DIALS --------------------------------------------------------------
local door = Config.HOUSE_DOOR
check(door.inset > 0, "the plane stands inside the anchor somebody lands on")
check(door.mountStandoff > 0, "a code-built door is pushed out onto the mount's convention")
check(door.ownerOnly == true, "only the plot's owner crosses, for now")
check(door.maskLead > 0, "the teleport happens under the cover and never before it")
check(door.cooldown >= door.maskLead + door.maskHold + door.maskFade,
	"the cooldown outlasts the whole mask")
-- The one that is invisible if it breaks: a headroom under a character's own
-- root height is a front door nobody can walk through, with nothing erroring.
check(door.headroom >= 4.0, "the band clears a character's own root height")
-- And a step guard tight enough to swallow a real walk would leave the door
-- working only for people standing still.
check(door.maxStep > 2 * Config.BASE_WALK_SPEED,
	"a running player's step is well inside the teleport guard")

local estate = Config.INDOOR_ESTATE
check(math.abs(estate.x) > Config.GROUND_SIZE.X,
	"the hallways stand off the map rather than inside it")
check(estate.gap > 0, "two hallways have clear air between them")

-- ---- THE BOOT AUDIT, PROVOKED RATHER THAN TRUSTED ---------------------------
check(#Config.auditHouseDoor() == 0, "the shipped door audits clean")

local function provoke(mutate, restore, wanted, why)
	mutate()
	local problems = Config.auditHouseDoor()
	local fired = false
	for _, p in problems do
		if p:find(wanted, 1, true) then fired = true end
	end
	restore()
	check(fired, why)
	check(#Config.auditHouseDoor() == 0, "audit clean again after: " .. why)
end

provoke(function() door.headroom = 2.0 end, function() door.headroom = 8.0 end,
	"[door.headroom]", "audit refuses a band no root could ever be inside")
provoke(function() door.inset = 0 end, function() door.inset = 1.6 end,
	"[door.inset]", "audit refuses a plane sitting on the spot somebody lands on")
provoke(function() door.cooldown = 0.2 end, function() door.cooldown = 1.5 end,
	"[door.mask]", "audit refuses a mask that outlasts the cooldown behind it")
provoke(function() door.maskLead = 0 end, function() door.maskLead = 0.12 end,
	"[door.mask]", "audit refuses a teleport that happens before the cover")
provoke(function() door.maxStep = 4 end, function() door.maxStep = 40 end,
	"[door.step]", "audit refuses a teleport guard a running player trips")
provoke(function() Config.INDOOR_ESTATE.x = 400 end, function() Config.INDOOR_ESTATE.x = 4000 end,
	"[door.estate]", "audit refuses hallways built inside the horizon")
provoke(function() door.halfWidth = 0 end, function() door.halfWidth = 2.85 end,
	"[door.width]", "audit refuses a doorway with no width")
provoke(function() door.exitReach = 0 end, function() door.exitReach = 3.0 end,
	"[door.exit]", "audit refuses a way out flush with a solid end wall")

-- ---- WHAT THE SOURCE HAS TO KEEP --------------------------------------------
local service = SOURCES.InteriorService
local mask = SOURCES.DoorMask
local remotes = SOURCES.Remotes
local main = SOURCES.Main
local client = SOURCES.ClientMain

-- THE SERVER OWNS THE MOVE. A client-side CFrame or `Anchored` write on a
-- character is discarded, which this project has measured three ways -- so the
-- teleport is written here and the client is only told to draw the cover.
check(service:find("root.CFrame = ground", 1, true) ~= nil,
	"the crossing writes the root's CFrame on the server")
-- MATCHED ON CODE AND NOT ON PROSE. Both of these files explain at length
-- WHY the client does not move anybody, so a search for the word finds the
-- comment saying it never happens. An assignment is the thing to refuse.
check(mask:find("%.CFrame%s*=") == nil and mask:find("%.Anchored%s*=") == nil,
	"the mask moves nothing -- it only draws")

-- NOT `Touched`. It re-fires per character part and is unreliable for a model
-- the server drives with `PivotTo`, which is what the pursuing officer will be.
check(service:find("%.Touched") == nil,
	"the crossing is a swept segment rather than a Touched handler")
check(service:find("Config.crossedDoorway", 1, true) ~= nil,
	"and the decision goes through the one function that owns it")

-- ONE COPY OF THE TIMINGS. A mask timed from a second table drifts off either
-- side of the move it exists to hide.
check(mask:find("Config.HOUSE_DOOR", 1, true) ~= nil,
	"the mask reads its timings from Config")
for _, key in ipairs({ "maskLead", "maskHold", "maskFade" }) do
	check(mask:find("door." .. key, 1, true) ~= nil,
		"the mask reads " .. key .. " rather than inventing one")
end

-- THE CHANNEL EXISTS AND CARRIES NOTHING WORTH FORGING.
check(remotes:find("DoorCross = \"RemoteEvent\"", 1, true) ~= nil,
	"DoorCross is declared in the one place remotes are declared")
check(service:find("FireClient(player, way)", 1, true) ~= nil,
	"and it carries a way in or out and no position at all")

-- A MODULE NOBODY STARTS IS A FEATURE THAT SILENTLY DOES NOTHING, which is the
-- failure shape this project records more than any other.
check(main:find("InteriorService.start()", 1, true) ~= nil,
	"Main starts the service")
check(main:find("PlotService.start()", 1, true) < main:find("InteriorService.start()", 1, true),
	"and starts it after the plots it reads a door anchor off")
check(client:find("require(ReplicatedStorage.Shared.DoorMask).start()", 1, true) ~= nil,
	"ClientMain starts the mask, in one statement holding no local")

-- THE ANCHOR IS THE AUTHORED ONE. All eighteen templates ship
-- `Mount_Door_Exit`; a code-built house falls back to its own `Door` part.
check(service:find("Mount_Door_Exit", 1, true) ~= nil,
	"the anchor is read off the art")
check(service:find("HouseDoorHinge_L", 1, true) ~= nil,
	"and the opening's width with it")

-- LAZY AND PREFIX, which is the part budget. A hallway is built on a crossing
-- and only to the rooms that owner has unlocked.
check(service:find("Config.indoorRooms", 1, true) ~= nil,
	"only the rooms a save has unlocked are built")
check(service:find("local built = ensureHome(plot)", 1, true) ~= nil,
	"and nothing is built until somebody walks through a door")

-- THE FLAG DOES SOMETHING. `PlotService.getPlot` already hands back the
-- caller's own plot, so a guard comparing that plot's owner against the caller
-- could never fire -- a Config flag that reads as a gate and is not one is the
-- failure this project refuses above all others.
check(service:find("if not Config.HOUSE_DOOR.ownerOnly then", 1, true) ~= nil
	and service:find("PlotService.yardContaining(at)", 1, true) ~= nil,
	"ownerOnly chooses WHOSE door counts rather than being a check that cannot fire")
-- And a hallway belongs to the plot's owner rather than to whoever walked in,
-- which is the same answer today and stops being one the moment it is opened.
check(service:find("local owner = plot.owner", 1, true) ~= nil,
	"the hallway is built against the plot's owner and not the visitor")

print(("doors: %d checks passed"):format(checks))
