--!strict
--[[
	PathFollower

	Walks a point toward a goal along a PathfindingService path, one step a
	frame, and knows nothing about what is being walked. The caller owns its
	own Y (the ground under it), its own pose call and its own catch test;
	this module owns WHERE THE NEXT STEP GOES and nothing else.

	WHY IT EXISTS. The police officer is a posed model with no Humanoid and no
	physics -- `PoliceService` steps it straight at the thief every frame --
	so it walked through every trunk collider, every fence barrier and every
	pond on the street. The designer's call (2026-09-21) is that it respects
	impassable objects and goes round them, and that the same system then
	serves NPCs and guard pets. So this is its own module with PoliceService
	as the first caller, and the interface is shaped for the callers that are
	NOT wired yet:

	  * ResidentService's walking neighbours -- posed, the same step-and-pose
	    loop, one follower per walking figure.
	  * GuardDog's chase and patrol -- posed, inside a fenced yard, the same
	    follower with the yard's own spec.
	  * HerdService's pack LEADER -- one path per pack rather than one per
	    member; the followers stay on their formation slots.

	None of those is wired here and nothing in this file names any of them.

	THE CONTRACT.

	  local follower = PathFollower.new(spec)     -- spec: see `Spec` below
	  follower:setGoal(position)                  -- where to walk to, any frame
	  local moved, direction, walked =
	      follower:step(from, dt, speed)          -- one frame of travel
	  follower:fallbacks()                        -- straight-line frames, for a warn
	  follower:destroy()

	`step` returns where the mover should be this frame (same Y as `from` --
	the caller sets its own height), the flat unit direction of travel (for a
	`facing` call), and the flat distance walked (for a stride accumulator).
	It never yields.

	HOW IT FOLLOWS.

	  * The path is computed in a `task.spawn`, because `Path:ComputeAsync`
	    yields and a frame loop must not. The mover keeps following the LAST
	    GOOD PATH until the new one lands -- a chase must never stand still
	    waiting on the navmesh.
	  * A waypoint is advanced when the mover is within `waypointReach` of it
	    on the flat -- never an exact compare, because a CFrame stores its
	    position as float32 and a loop that converges on a coordinate by
	    equality never terminates (CLAUDE.md, the delivery van).
	  * The LAST leg targets the live goal rather than the last waypoint, so a
	    goal that has drifted less than `replanDistance` is still walked to
	    exactly, and the caller's own catch test agrees with the picture.
	  * A replan is asked for when the goal has moved more than
	    `replanDistance` from the goal the current path was computed to, when
	    `Path.Blocked` fires ahead of the mover, when a truncated path runs
	    out, or when the last compute FAILED -- and never more often than
	    `replanSeconds`.

	THE FALLBACK, LOUDLY DERIVED. If `ComputeAsync` throws or comes back with
	anything but `Success`, the mover follows the straight line exactly as the
	old officer did, and keeps retrying on the replan cadence. A chase must
	never freeze with the officer standing still. Every such frame's compute
	is counted, and `fallbacks()` is what the caller prints -- a warning
	nobody reads is not a report, but a chase that silently ran the old way
	is worse.

	It requires nothing but PathfindingService. Deliberately not Config: the
	spec IS the contract, so a future caller passes its own table and this
	file never learns which one it is serving.
]]

local PathfindingService = game:GetService("PathfindingService")

local PathFollower = {}
PathFollower.__index = PathFollower

export type Spec = {
	agentRadius: number,
	agentHeight: number,
	agentCanJump: boolean,
	-- Recompute when the goal is further than this from the goal the current
	-- path was computed to.
	replanDistance: number,
	-- A floor between two computes, however hard the goal moves.
	replanSeconds: number,
	-- The most waypoints kept from one compute; a path longer than this is
	-- followed as far as it goes and then recomputed from there.
	maxWaypoints: number,
	-- A waypoint counts as reached inside this flat distance.
	waypointReach: number,
	-- Passed through to `CreatePath` as `Costs`, per PathfindingModifier
	-- label. Optional, and worth knowing before relying on: measured live,
	-- a modifier on a script-built NON-COLLIDING part was ignored by the
	-- navmesh entirely (the pond case, see `Grassland.buildPond`), so a cost
	-- row only ever does anything on a label that also has collision under
	-- it. The police spec carries none.
	costs: { [string]: number }?,
	waypointSpacing: number?,
}

export type PathFollower = typeof(setmetatable({} :: {
	spec: Spec,
	path: Path,
	goal: Vector3?,
	pathGoal: Vector3?,
	waypoints: { Vector3 },
	index: number,
	truncated: boolean,
	direct: boolean,
	computing: boolean,
	forceReplan: boolean,
	lastCompute: number,
	fallbackCount: number,
	lastDirection: Vector3,
	blockedConnection: RBXScriptConnection?,
	destroyed: boolean,
}, PathFollower))

local function flat(a: Vector3, b: Vector3): Vector3
	return Vector3.new(b.X - a.X, 0, b.Z - a.Z)
end

function PathFollower.new(spec: Spec): PathFollower
	local path = PathfindingService:CreatePath({
		AgentRadius = spec.agentRadius,
		AgentHeight = spec.agentHeight,
		AgentCanJump = spec.agentCanJump,
		WaypointSpacing = spec.waypointSpacing,
		Costs = spec.costs,
	})

	local self = setmetatable({
		spec = spec,
		path = path,
		goal = nil,
		pathGoal = nil,
		waypoints = {},
		index = 1,
		truncated = false,
		-- Straight line until the first path lands: the first frame of a
		-- chase is a chase, not a wait.
		direct = true,
		computing = false,
		forceReplan = false,
		lastCompute = -math.huge,
		fallbackCount = 0,
		lastDirection = Vector3.new(0, 0, 1),
		blockedConnection = nil,
		destroyed = false,
	}, PathFollower) :: PathFollower

	-- Something stood in the way after the path was computed. Only a block
	-- AHEAD of the mover matters; one behind it is ground already crossed.
	self.blockedConnection = path.Blocked:Connect(function(blockedIndex: number)
		if blockedIndex >= self.index then
			self.forceReplan = true
		end
	end)

	return self
end

function PathFollower.setGoal(self: PathFollower, position: Vector3)
	self.goal = position
end

function PathFollower.fallbacks(self: PathFollower): number
	return self.fallbackCount
end

-- True while the mover is on a computed path rather than the straight line.
-- For tests and for a caller that wants to say so; nothing decides on it.
function PathFollower.onPath(self: PathFollower): boolean
	return not self.direct and #self.waypoints > 0
end

-- Whether a compute should be asked for now. Split out so the policy is one
-- expression rather than five sites that each remember most of it.
local function wantsReplan(self: PathFollower, now: number): boolean
	if self.destroyed or self.computing or self.goal == nil then
		return false
	end
	if now - self.lastCompute < self.spec.replanSeconds then
		return false
	end
	if self.pathGoal == nil or self.forceReplan or self.direct then
		return true
	end
	-- A truncated path that has been walked to its end has nowhere left to
	-- point; the straight line from there is exactly what this module exists
	-- to avoid, so it asks again rather than guessing.
	if self.truncated and self.index >= #self.waypoints then
		return true
	end
	local goal = self.goal :: Vector3
	local pathGoal = self.pathGoal :: Vector3
	return flat(pathGoal, goal).Magnitude > self.spec.replanDistance
end

-- Moves `index` past every waypoint the mover has already dealt with: one
-- within `waypointReach` on the flat, or one the mover has PASSED -- it has
-- crossed the plane through the waypoint perpendicular to the leg that
-- ARRIVES there. The second rule is what stops a mover that jumped past a
-- waypoint -- a lag spike, a shove, a path adopted a few frames late --
-- turning round to walk back to a point it has no reason to visit.
--
-- The arriving leg and not the leaving one, which was the first version and
-- misfires at every corner: a mover a stud and a half short of a right-angle
-- turn but half a stud past it sideways is "behind" the turn's outgoing leg
-- and would skip the corner. The start waypoint has no arriving leg and takes
-- the outgoing one -- it is where the compute began, and the only thing a
-- mover can be relative to it is a little way along. The last waypoint is
-- never advanced past; it is where the path ends.
local function advance(self: PathFollower, from: Vector3)
	local points = self.waypoints
	local n = #points
	local reach = self.spec.waypointReach
	while self.index < n do
		local point = points[self.index]
		if flat(from, point).Magnitude <= reach then
			self.index += 1
		else
			local along = if self.index > 1
				then flat(points[self.index - 1], point)
				else flat(point, points[self.index + 1])
			local past = flat(point, from)
			if past.X * along.X + past.Z * along.Z > 0 then
				self.index += 1
			else
				break
			end
		end
	end
end

-- Adopts a freshly computed path. Waypoints already within reach of the
-- mover are skipped, because the mover kept walking the old path while this
-- one was being computed and may be past its first few points.
local function adopt(self: PathFollower, from: Vector3, points: { PathWaypoint })
	local kept: { Vector3 } = {}
	local limit = math.max(1, self.spec.maxWaypoints)
	for i, waypoint in ipairs(points) do
		if i > limit then
			break
		end
		kept[i] = waypoint.Position
	end
	self.waypoints = kept
	self.truncated = #points > limit
	self.index = 1
	advance(self, from)
	self.direct = #kept == 0
end

local function compute(self: PathFollower, from: Vector3, goal: Vector3, now: number)
	self.computing = true
	self.lastCompute = now
	task.spawn(function()
		local ok, err = pcall(function()
			self.path:ComputeAsync(from, goal)
		end)
		if self.destroyed then
			return
		end
		self.computing = false
		self.forceReplan = false
		self.pathGoal = goal
		if ok and self.path.Status == Enum.PathStatus.Success then
			adopt(self, from, self.path:GetWaypoints())
			return
		end
		-- No path, a partial path, or a throw: the straight line, counted.
		-- `ClosestNoPath` is deliberately in this bucket -- a partial path
		-- ends somewhere that is not the goal, and following it to its end
		-- and then beelining is the same walk-through-things this exists to
		-- stop, arriving later.
		self.fallbackCount += 1
		self.waypoints = {}
		self.truncated = false
		self.index = 1
		self.direct = true
		if not ok then
			warn(("[PathFollower] ComputeAsync threw: %s"):format(tostring(err)))
		end
	end)
end

-- One frame of travel. `from` is where the mover is (its own Y), `speed` in
-- studs a second. Returns where it should be, the flat direction it moved,
-- and how far it moved on the flat. Never yields; never touches Y.
function PathFollower.step(self: PathFollower, from: Vector3, dt: number, speed: number): (Vector3, Vector3, number)
	local goal = self.goal
	if self.destroyed or goal == nil then
		return from, self.lastDirection, 0
	end

	local now = os.clock()
	if wantsReplan(self, now) then
		compute(self, from, goal, now)
	end

	-- Pick the target: the next waypoint, or the goal itself on the last leg
	-- and on the straight line.
	local target: Vector3
	if self.direct or #self.waypoints == 0 then
		target = goal
	else
		advance(self, from)
		local n = #self.waypoints
		if self.index >= n and not self.truncated then
			target = goal
		else
			target = self.waypoints[self.index]
		end
	end

	local delta = flat(from, target)
	local distance = delta.Magnitude
	if distance <= 1e-3 then
		return from, self.lastDirection, 0
	end

	local direction = delta / distance
	local walked = math.min(speed * dt, distance)
	local moved = Vector3.new(from.X + direction.X * walked, from.Y, from.Z + direction.Z * walked)
	self.lastDirection = direction
	return moved, direction, walked
end

function PathFollower.destroy(self: PathFollower)
	if self.destroyed then
		return
	end
	self.destroyed = true
	if self.blockedConnection then
		self.blockedConnection:Disconnect()
		self.blockedConnection = nil
	end
	self.path:Destroy()
	self.waypoints = {}
	self.goal = nil
end

return PathFollower
