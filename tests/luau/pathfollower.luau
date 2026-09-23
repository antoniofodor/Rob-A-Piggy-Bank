-- The waypoint follower: `Shared/PathFollower`, driven against a CANNED
-- PathfindingService whose `ComputeAsync` returns scripted waypoints (and a
-- NoPath / ClosestNoPath / throwing variant), with `task.spawn` turned into a
-- queue the test drains by hand so "keeps following the last good path until
-- the new one lands" is a thing that can be asserted rather than hoped.
-- THE STUB IS THE INSTRUMENT AND NOT THE THING: it proves what the follower
-- does with a path, and says nothing about what the navmesh will hand it on
-- the real street. That is the coordinator's live chase.
local Config, SOURCES = ...
local checks = 0
local function check(ok, message) assert(ok, message); checks += 1 end
local function near(a, b, tol) return math.abs(a - b) <= (tol or 1e-6) end

-- ---- THE STUB --------------------------------------------------------------
local V = {}
local function vec(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, V) end
V.__index = function(self, key)
	if key == "Magnitude" then return math.sqrt(self.X ^ 2 + self.Y ^ 2 + self.Z ^ 2) end
	if key == "Unit" then local m = self.Magnitude; return vec(self.X / m, self.Y / m, self.Z / m) end
	return rawget(V, key)
end
V.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V.__mul = function(a, b)
	if type(a) == "number" then return vec(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V.__div = function(a, b) return vec(a.X / b, a.Y / b, a.Z / b) end
local Enum = setmetatable({}, { __index = function(_, group)
	return setmetatable({}, { __index = function(_, name) return group .. "." .. name end })
end })

-- The canned service. One scripted answer at a time, a log of every compute,
-- a queue standing in for task.spawn, and every Blocked handler kept so the
-- test can fire it.
local scripted = { status = "PathStatus.Success", points = {}, throw = false }
local computeLog = {}
local pending = {}
local blockedHandlers = {}
local disconnected, destroyedPaths, requests = 0, 0, 0
local createParams = nil
local now = 100
local warnings = {}
local PathfindingService = {}
function PathfindingService:CreatePath(params)
	createParams = params
	local path = { Status = nil, _points = {} }
	path.Blocked = { Connect = function(_, fn)
		table.insert(blockedHandlers, fn)
		return { Disconnect = function() disconnected += 1 end }
	end }
	function path:ComputeAsync(from, to)
		table.insert(computeLog, { from = from, to = to })
		if scripted.throw then error("navmesh exploded") end
		self.Status = scripted.status
		self._points = scripted.points
	end
	function path:GetWaypoints()
		local out = {}
		for _, p in ipairs(self._points) do table.insert(out, { Position = p, Action = "PathWaypointAction.Walk" }) end
		return out
	end
	function path:Destroy() destroyedPaths += 1 end
	return path
end
local function drain() while #pending > 0 do local fn = table.remove(pending, 1); fn() end end

local env = setmetatable({
	Vector3 = { new = vec }, Enum = Enum,
	task = { spawn = function(fn) requests += 1; table.insert(pending, fn) end },
	os = { clock = function() return now end },
	warn = function(message) table.insert(warnings, tostring(message)) end,
	game = { GetService = function(_, name)
		assert(name == "PathfindingService", "the follower asks for nothing but PathfindingService: " .. name)
		return PathfindingService
	end },
	require = function() error("the follower requires nothing") end,
}, { __index = getfenv() })
local run = assert(loadstring(SOURCES.PathFollower, "PathFollower"))
setfenv(run, env)
local PathFollower = run()

local SPEC = {
	agentRadius = 2, agentHeight = 6, agentCanJump = false,
	replanDistance = 4, replanSeconds = 0.4, maxWaypoints = 64, waypointReach = 1.0,
	-- A cost row here proves the pass-through and nothing else: the shipped
	-- police spec carries none, because the pond modifier it was written for
	-- measured as doing nothing (see Grassland.buildPond).
	costs = { Mud = 5 },
}
local function reset()
	scripted = { status = "PathStatus.Success", points = {}, throw = false }
	computeLog, pending, blockedHandlers, warnings = {}, {}, {}, {}
	disconnected, destroyedPaths, requests = 0, 0, 0
	now = 100
end
local function flatDist(a, b) return math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2) end

-- ---- CONSTRUCTION -----------------------------------------------------------
reset()
local f = PathFollower.new(SPEC)
check(createParams.AgentRadius == 2 and createParams.AgentHeight == 6 and createParams.AgentCanJump == false,
	"the agent's radius, height and jump go straight through to CreatePath")
check(createParams.Costs.Mud == 5, "a costs table is passed through to CreatePath as given")
check(#blockedHandlers == 1, "Path.Blocked is connected at construction")
check(f:fallbacks() == 0 and not f:onPath(), "born with no fallbacks and no path")

-- No goal: nothing moves, nothing is computed.
local moved, direction, walked = f:step(vec(0, 0, 0), 0.1, 10)
check(walked == 0 and moved.X == 0 and moved.Z == 0, "no goal, no step")
check(requests == 0 and #pending == 0, "and no compute asked for")

-- ---- THE FIRST STEP IS A STRAIGHT ONE, AND A COMPUTE IS ASKED FOR -----------
f:setGoal(vec(10, 0, 10))
moved, direction, walked = f:step(vec(0, 7.5, 0), 0.1, 10)
check(requests == 1 and #pending == 1, "the first step with a goal requests one compute in a spawned task")
check(#computeLog == 0, "and the compute has not run yet -- it yields, so it lives in the task")
check(near(walked, 1.0), "speed x dt is the step: " .. walked)
check(near(direction.X, math.sqrt(0.5)) and near(direction.Z, math.sqrt(0.5)) and direction.Y == 0,
	"before a path lands it walks the straight line, flat")
check(moved.Y == 7.5, "the mover's own Y is untouched: " .. moved.Y)
check(not f:onPath(), "still on the straight line while the compute is pending")

-- ---- A PATH LANDS AND IS FOLLOWED ------------------------------------------
-- Two right angles, so the direction visibly changes at a waypoint.
scripted.points = { vec(0, 0, 0), vec(4, 0, 0), vec(8, 0, 0), vec(8, 0, 6), vec(10, 0, 10) }
drain()
check(#computeLog == 1 and computeLog[1].from.X == 0 and computeLog[1].from.Z == 0, "the compute ran FROM where the mover was")
check(computeLog[1].to.X == 10 and computeLog[1].to.Z == 10, "TO the goal")
check(f:onPath(), "the scripted path is adopted")
check(#pending == 0, "the task queue is drained")

-- Advance within the tolerance, never on an exact compare.
moved, direction, walked = f:step(vec(2.5, 0, 0), 0.1, 10)
check(near(direction.X, 1) and near(direction.Z, 0), "1.5 studs short of (4,0,0) the target is still (4,0,0)")
-- A mover that finds itself PAST a waypoint it never came within reach of
-- (a lag spike, a shove, a path adopted late) does not turn round for it.
moved, direction, walked = f:step(vec(6.5, 0, 0.5), 0.1, 10)
check(near(direction.X, 0.9487, 1e-3) and direction.Z < 0, "2.5 studs past (4,0,0) it is behind the mover and the target is (8,0,0), not a walk back")
check(f.index == 3, "and the corner at (8,0,0) is NOT skipped for being half a stud off sideways")
-- A path adopted late: the mover kept walking while the compute ran and is
-- well past the start waypoint when the path lands.
reset()
f = PathFollower.new(SPEC)
f:setGoal(vec(10, 0, 10))
f:step(vec(0, 0, 0), 0.001, 10)
scripted.points = { vec(0, 0, 0), vec(4, 0, 0), vec(8, 0, 0), vec(8, 0, 6), vec(10, 0, 10) }
moved, direction, walked = f:step(vec(5.8, 0, 0), 0.1, 10)
check(near(direction.X, 4.2 / math.sqrt(4.2 ^ 2 + 100)) and direction.Z > 0.9, "before it lands the mover is still on its straight line to the goal")
drain()
moved, direction, walked = f:step(vec(5.8, 0, 0), 0.1, 10)
check(f.index == 3 and near(direction.X, 1), "a path adopted 5.8 studs along skips its start and the waypoint already passed, and walks on")
moved, direction, walked = f:step(vec(7.3, 0, 0), 0.1, 10)
check(direction.Z > 0.99, "0.7 studs short of (8,0,0) it is reached and the next leg (up +Z) is the target")
f.index = 3
moved, direction, walked = f:step(vec(7.0, 0, 0), 0.1, 10)
check(f.index == 4 and direction.Z > 0.98, "exactly 1.0 away counts as reached: the tolerance is inclusive, not an equality")
check(direction.Y == 0, "the direction is flat")

-- Walk it end to end in real-sized steps and hold the stride to the ground
-- actually covered. Fresh follower so the index starts at the top.
reset()
f = PathFollower.new(SPEC)
f:setGoal(vec(10, 0, 10))
scripted.points = { vec(0, 0, 0), vec(4, 0, 0), vec(8, 0, 0), vec(8, 0, 6), vec(10, 0, 10) }
local at = vec(0, 0.5, 0)
f:step(at, 0.001, 14.5)
drain()
local strideSum, travelled = 0, 0
for _ = 1, 400 do
	local next_, _, w = f:step(at, 0.05, 14.5)
	strideSum += w
	travelled += flatDist(at, next_)
	check(next_.Y == 0.5, "Y untouched on every frame")
	at = next_
end
check(near(strideSum, travelled, 1e-6), ("the stride is the flat distance actually walked: %.4f vs %.4f"):format(strideSum, travelled))
check(flatDist(at, vec(10, 0, 10)) < 1e-3, ("it arrives at the goal, clamped rather than overshooting: %.4f off"):format(flatDist(at, vec(10, 0, 10))))
local legs = 4 + 4 + 6 + math.sqrt(4 + 16)
check(strideSum <= legs + 1e-6 and strideSum >= math.sqrt(200), ("the walk is between the straight line and the polyline: %.3f"):format(strideSum))
check(requests == 1 and #computeLog == 1, "one compute served the whole walk: the goal never moved")

-- ---- THE LAST LEG TARGETS THE LIVE GOAL, INSIDE replanDistance -------------
f:setGoal(vec(12, 0, 10))
now += 1
moved, direction, walked = f:step(vec(10, 0.5, 10), 0.1, 10)
check(direction.X > 0.99 and near(direction.Z, 0), "on the last leg a goal that drifted 2 studs is walked to exactly")
check(requests == 1, "and no recompute for a drift under replanDistance, even after the cadence")

-- ---- REPLAN ON DRIFT, ON THE CADENCE ---------------------------------------
reset()
f = PathFollower.new(SPEC)
f:setGoal(vec(10, 0, 10))
f:step(vec(0, 0, 0), 0.001, 10)
scripted.points = { vec(0, 0, 0), vec(4, 0, 0), vec(8, 0, 0), vec(8, 0, 6), vec(10, 0, 10) }
drain()
-- Mid-path, on the (8,0,0) waypoint.
at = vec(5, 0, 0)
f:step(at, 0.001, 10)
f:setGoal(vec(20, 0, 10)) -- 10 studs off the computed goal
now += 0.2
moved, direction, walked = f:step(at, 0.1, 10)
check(requests == 1, "a drift past replanDistance inside replanSeconds is NOT recomputed yet")
check(near(direction.X, 1), "and the old path is still being followed")
now += 0.25
moved, direction, walked = f:step(at, 0.1, 10)
check(requests == 2, "past replanSeconds the drift is recomputed")
check(#pending == 1 and near(direction.X, 1), "while the compute is pending the mover keeps following the old path")
-- The new path lands; waypoints already within reach are skipped.
scripted.points = { vec(5, 0, 0), vec(5.5, 0, 0), vec(9, 0, -3), vec(20, 0, 10) }
drain()
check(computeLog[2].from.X == 5 and computeLog[2].to.X == 20, "from the mover's current spot to the new goal")
moved, direction, walked = f:step(vec(5.2, 0, 0), 0.1, 10)
check(direction.Z < -0.5, "the new path is followed from the first waypoint NOT already within reach")
check(requests == 2, "adopting it asked for nothing more")

-- ---- NO PATH: THE STRAIGHT LINE, COUNTED, RETRIED --------------------------
reset()
f = PathFollower.new(SPEC)
f:setGoal(vec(10, 0, 0))
f:step(vec(0, 0, 0), 0.001, 10)
scripted.status = "PathStatus.NoPath"
drain()
check(f:fallbacks() == 1, "NoPath is one fallback")
check(not f:onPath(), "and the follower is on the straight line")
moved, direction, walked = f:step(vec(0, 0, 3), 0.1, 10)
check(direction.X > 0.9 and direction.Z < 0, "which points straight at the goal")
check(near(walked, 1.0), "at full speed -- a failed compute never freezes the mover")
check(requests == 1, "no retry inside the cadence")
now += 0.5
f:step(vec(1, 0, 3), 0.1, 10)
check(requests == 2, "the retry comes on the replan cadence with the goal unmoved")
scripted.status = "PathStatus.Success"
scripted.points = { vec(1, 0, 3), vec(5, 0, 3), vec(10, 0, 0) }
drain()
check(f:onPath() and f:fallbacks() == 1, "a later success puts it back on a path and the count stays honest")

-- ClosestNoPath is a fallback too: a partial path ends somewhere else.
now += 0.5
f:setGoal(vec(30, 0, 0))
f:step(vec(1, 0, 3), 0.1, 10)
scripted.status = "PathStatus.ClosestNoPath"
drain()
check(f:fallbacks() == 2 and not f:onPath(), "ClosestNoPath is counted and walked straight")

-- A throw is a fallback, warned, and never propagates into the frame loop.
now += 0.5
scripted.throw = true
local ok = pcall(function() f:step(vec(2, 0, 3), 0.1, 10) end)
check(ok, "a compute is requested without throwing")
ok = pcall(drain)
check(ok, "and the throw inside ComputeAsync never escapes the task")
check(f:fallbacks() == 3, "a thrown compute is a fallback")
check(#warnings == 1 and warnings[1]:find("ComputeAsync threw", 1, true) ~= nil, "and is warned once, naming the cause")
moved, direction, walked = f:step(vec(2, 0, 3), 0.1, 10)
check(near(walked, 1.0), "the mover is still moving after a throw")

-- ---- BLOCKED FORCES A REPLAN ------------------------------------------------
reset()
f = PathFollower.new(SPEC)
f:setGoal(vec(10, 0, 10))
f:step(vec(0, 0, 0), 0.001, 10)
scripted.points = { vec(0, 0, 0), vec(4, 0, 0), vec(8, 0, 0), vec(8, 0, 6), vec(10, 0, 10) }
drain()
f:step(vec(5, 0, 0), 0.001, 10) -- on waypoint 3
now += 1
blockedHandlers[1](1)
f:step(vec(5, 0, 0), 0.001, 10)
check(requests == 1, "a block BEHIND the mover is ignored")
blockedHandlers[1](4)
f:step(vec(5, 0, 0), 0.001, 10)
check(requests == 2, "a block AHEAD of the mover forces a replan")
check(#pending == 1, "in a task of its own")
scripted.points = { vec(5, 0, 0), vec(5, 0, 5), vec(10, 0, 10) }
drain()
moved, direction, walked = f:step(vec(5, 0, 0), 0.1, 10)
check(direction.Z > 0.99, "and the path round the block is followed")
now += 1
f:step(vec(5, 0, 1), 0.1, 10)
check(requests == 2, "a block that has been replanned is not replanned again")

-- ---- A TRUNCATED PATH RUNS OUT AND ASKS AGAIN RATHER THAN BEELINING ---------
reset()
local SHORT = table.clone(SPEC)
SHORT.maxWaypoints = 3
f = PathFollower.new(SHORT)
f:setGoal(vec(40, 0, 0))
f:step(vec(0, 0, 0), 0.001, 10)
scripted.points = { vec(0, 0, 0), vec(4, 0, 4), vec(8, 0, 8), vec(12, 0, 8), vec(20, 0, 0), vec(40, 0, 0) }
drain()
check(#f.waypoints == 3, "only maxWaypoints are kept")
moved, direction, walked = f:step(vec(4.5, 0, 4.5), 0.1, 10)
check(direction.Z > 0.5, "the kept waypoints are followed")
now += 1
moved, direction, walked = f:step(vec(7.9, 0, 7.9), 0.1, 10)
check(walked < 0.2, "at the end of a truncated path the mover does not beeline for the goal")
check(requests == 2, "it asks for the rest of the way")
scripted.points = { vec(8, 0, 8), vec(12, 0, 8), vec(20, 0, 0), vec(40, 0, 0) }
drain()
check(computeLog[2].from.X == 7.9, "from where it stands")
moved, direction, walked = f:step(vec(7.9, 0, 7.9), 0.1, 10)
check(near(walked, 1.0) and direction.X > 0.99, "and carries on along it")

-- ---- DESTROY ---------------------------------------------------------------
f:destroy()
check(disconnected == 1 and destroyedPaths == 1, "destroy disconnects Blocked and destroys the Path")
moved, direction, walked = f:step(vec(7.9, 0, 7.9), 0.1, 10)
check(walked == 0, "a destroyed follower moves nothing")
f:destroy()
check(disconnected == 1 and destroyedPaths == 1, "and destroying twice is one destroy")
-- A compute that lands after destroy changes nothing.
reset()
f = PathFollower.new(SPEC)
f:setGoal(vec(10, 0, 0))
f:step(vec(0, 0, 0), 0.001, 10)
f:destroy()
scripted.points = { vec(0, 0, 0), vec(10, 0, 0) }
drain()
check(not f:onPath() and f:fallbacks() == 0, "a path landing after destroy is dropped on the floor")

print(("pathfollower: %d checks passed"):format(checks))
