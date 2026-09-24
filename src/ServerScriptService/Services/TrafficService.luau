--!strict
--[[
	TrafficService

	The delivery van that drives the street, and nothing else.

	WHY IT IS ITS OWN SERVICE. The pathing belongs to `PoliceService` and the
	street furniture belongs to `NeighborhoodService`, and it is neither: a
	patrol is a hazard with a schedule, an alarm, a pursuit and a bail charge,
	and the road, the kerbs and the bins are built once and never move. This
	is a thing that drives and means nothing. Filing it under the police would
	put a bakery van inside a service named for arresting people, which is
	exactly the naming rot this project avoids; filing it under scenery would
	put a per-frame loop inside a file whose own header says "pure scenery".

	IT CONFERS NOTHING, AND THAT IS ENFORCED RATHER THAN PROMISED. Every part
	`VanModel` builds is `CanCollide`, `CanQuery` and `CanTouch` false, so
	there is nothing here a player can stand on, hide behind, be pushed by or
	raycast against. No prompt, no remote, no attribute anybody reads. The
	rule it has to clear is the one the lawn ornaments already clear -- a
	cosmetic may never change an OUTCOME -- and the way it clears it is by
	having no body at all.

	IT STANDS DOWN FOR A PATROL, which is the same call `PoliceService`
	already makes for an event and for the same two reasons. The road has two
	lanes and both vehicles use them, so a van meeting a car in the same lane
	would pass THROUGH it -- neither collides -- which reads as broken rather
	than as traffic. And a siren is the loudest thing this street does; a
	delivery van sharing that moment is the two-banners-in-one-row problem on
	wheels.

	IT IS ON THE SERVER RATHER THAN CLIENT-SIDE, which is the opposite call
	from the fireworks and the moat, and the reason is the paragraph above.
	A client cannot ask whether a patrol is out without being told, so a
	client-side van would need a push to stand down -- at which point the
	server is driving it anyway, one indirection worse. The cost is one
	`PivotTo` per frame while a van is on the road, which is what the patrol
	car already costs and is bounded by there only ever being one.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local VanModel = require(ReplicatedStorage.Shared.VanModel)
local PoliceService = require(script.Parent.PoliceService)

local TrafficService = {}

local ROAD_Y = Config.ROAD_SURFACE_Y

local van: VanModel.Van? = nil
local rng = Random.new()

-- Authored facing +Z like every other model here, so a lookAt needs the half
-- turn. Four bugs in this project have come from leaving it off -- the guard
-- dog ran tail-first through every patrol for months, and the residents
-- moonwalked up the street.
local function facing(at: Vector3, direction: Vector3): CFrame
	return CFrame.lookAt(at, at + direction) * CFrame.Angles(0, math.pi, 0)
end

-- One run: in at one tunnel, out at the other.
--
-- DELIBERATELY NOT `PoliceService.driveTo`. That function eases a LANE
-- CHANGE, polls an abort predicate and stops short of a target, because a
-- patrol turns round in the middle of the street and has to notice an alarm
-- on the next frame. A van does none of those: it enters, it crosses, it
-- leaves. Reaching for the shared version would have meant widening it to
-- serve a caller that wants none of what it does, which is how a function
-- that was clear about one job stops being clear about either.
--
-- What IS shared is everything that could drift: the road surface, the lane
-- and the pivot offset all come out of Config or off the model's own table.
local function run(): boolean
	local m = Config.streetMetrics()
	local lane = Config.DELIVERY.lane
	-- THE PIVOT'S HEIGHT, NOT THE ROAD'S. `PivotTo` aims the PRIMARY PART and
	-- `VanModel.buildVan` takes a GROUND origin; those read as if they take
	-- the same thing and do not. The patrol car spent a whole release 1.6
	-- studs into the tarmac with its wheels half buried for exactly this, and
	-- nothing errored and nothing looked wrong in a still.
	local pivotY = ROAD_Y + VanModel.VAN_PIVOT_Y

	-- Started INSIDE the west bore rather than at its mouth, the same call the
	-- patrol makes: a vehicle that blinks into existence at the end of the
	-- road reads as a spawn, and one that drives out of a tunnel reads as
	-- traffic. Far enough in that the whole body is behind the lintel.
	local startX = m.tunnelWestX - VanModel.HALF_LENGTH - 4
	local endX = m.tunnelEastX + VanModel.HALF_LENGTH + 4

	local built = VanModel.buildVan(
		CFrame.new(Vector3.new(startX, ROAD_Y, lane)), workspace)
	van = built
	built.model:PivotTo(facing(
		Vector3.new(startX, pivotY, lane), Vector3.new(1, 0, 0)))

	-- THE LOOP DRIVES `built`, NEVER THE MODULE-LEVEL `van`, AND THE FIRST
	-- BUILD OF IT GOT THAT WRONG.
	--
	-- It re-read the shared field every frame, on the reasoning that a van
	-- destroyed out from under the loop should stop it. What that actually
	-- buys is that a SECOND run silently steals the first one's loop: `van`
	-- becomes the new model, both loops start driving it, and the first
	-- van is orphaned in the middle of the road with nothing left holding a
	-- reference to destroy it. Measured -- two vans parked nose to tail at
	-- the far tunnel mouth, neither moving, neither cleaned up, and nothing
	-- in any log.
	--
	-- Same family as `busyUntil` carrying two clocks and as `SUNK` being
	-- read by two halves of the shop: one piece of shared state with two
	-- writers, disagreeing in a direction nobody checked. A loop owns the
	-- thing it was handed.
	--
	-- AND IT OVERSHOOTS RATHER THAN LANDING ON THE MARK, WHICH IS NOT
	-- TIDINESS -- THE VERSION THAT LANDED ON IT NEVER TERMINATED.
	--
	-- The obvious last step is `math.min(speed * dt, endX - x)`, so the van
	-- stops exactly at the end instead of sailing past it. A CFrame stores
	-- its position as FLOAT32: write 263.3 and read back 263.29998779, which
	-- is LESS than the double 263.3 this loop compares against. So `x >=
	-- endX` is false, the clamped step is a hundred-thousandth of a stud,
	-- the write rounds to the same float32 again, and the loop runs forever.
	-- Measured: a van parked motionless at the far tunnel mouth, never
	-- destroyed, with nothing in any log -- and a scheduled loop behind it
	-- blocked for the rest of the server's life because its guard reads the
	-- same field.
	--
	-- `driveTo` is immune only because it stops within a stud of its target
	-- rather than on it, which is worth knowing before anybody tightens it.
	-- ANYTHING THAT CONVERGES ON A CFRAME COORDINATE BY EXACT COMPARISON HAS
	-- THIS BUG: leave a tolerance, or -- as here -- do not aim at the point
	-- at all. The overshoot is at most one frame of travel, a third of a
	-- stud, and it happens inside a tunnel bore where nobody can see it.
	local speed = Config.DELIVERY.speed
	while built.model.Parent do
		local dt = RunService.Heartbeat:Wait()
		local x = built.body.Position.X
		if x >= endX then
			break
		end
		built.model:PivotTo(facing(
			Vector3.new(x + speed * dt, pivotY, lane), Vector3.new(1, 0, 0)))
	end

	-- AND IT CLEANS UP ITS OWN, in the same function that built it, which is
	-- what makes the two impossible to get out of step. `van` is only
	-- cleared if it still names THIS model: releasing it unconditionally
	-- would hand a later run's guard a false answer.
	if built.model.Parent then
		built.model:Destroy()
	end
	if van == built then
		van = nil
	end
	return true
end

function TrafficService.isOut(): boolean
	return van ~= nil
end

-- Sends it home early. Used by the admin console and by nothing else --
-- there is no gameplay reason to remove a van, which is the whole point of it.
function TrafficService.clear(): string
	local current = van
	van = nil
	if not current then
		return "No van on the street."
	end
	-- Destroying the model is also how the drive loop is stopped: its own
	-- condition is `built.model.Parent`, so it falls out on the next frame
	-- rather than needing a flag anybody has to remember to set.
	if current.model.Parent then
		current.model:Destroy()
	end
	return "Van removed."
end

-- Puts one on the road now, or says why not. The dev trigger: at a gap of 70
-- to 150 seconds the only other way to see one is to stand on the pavement
-- and wait.
function TrafficService.send(): string
	if van then
		return "A van is already out."
	end
	if PoliceService.isOut() then
		return "Not while a patrol is out -- the van waits for it."
	end
	task.spawn(function()
		local ok, err = pcall(run)
		if not ok then
			warn("[TrafficService] van run failed: " .. tostring(err))
			-- `run` cleans up its own on the way out, so the only case left
			-- here is a THROW partway through -- which leaves a van on the road
			-- and the field still naming it.
			TrafficService.clear()
		end
	end)
	-- `%.1f`, never `%d`: the speed is a RATIO of `BASE_WALK_SPEED` and a base
	-- that lands it on a fraction would make `%d` throw on every van.
	return ("Van away, west to east at %.1f studs/s."):format(Config.DELIVERY.speed)
end

function TrafficService.start()
	-- OFF FOR THE MVP (designer, 2026-09-23). A `return` is the right shape
	-- HERE and the wrong one in `EventService`, and the difference is worth
	-- a line: the admin panel reaches a van through `TrafficService.send`,
	-- which is a direct call and is untouched, where it reaches an event by
	-- setting a field only that scheduler reads. So the dev button still
	-- works in both places and only one of them needed the loop kept alive.
	if not Config.DELIVERY.enabled then
		return
	end
	task.spawn(function()
		task.wait(Config.DELIVERY.firstDelay)
		while true do
			-- WAITS OUT A PATROL RATHER THAN SKIPPING A RUN. The gap is
			-- already the pacing; losing a whole one to a patrol that
			-- happened to be running would make vans rarest exactly when the
			-- street is busiest, which is backwards.
			-- AND WAITS OUT A VAN THAT IS STILL OUT, which `send` guards and
			-- this loop did not. A dev trigger firing a few seconds before a
			-- scheduled run is enough to put two on the road, and two vans in
			-- one lane pass through each other -- neither collides.
			while van ~= nil or PoliceService.isOut() do
				task.wait(2)
			end

			-- PCALLED AS A WHOLE, the same argument as the guard dog's watch
			-- loop and the pcall around `Decor.prewarm`: a van is scenery,
			-- and scenery may never stop the game being played. A throw in
			-- here would otherwise end the loop for the rest of the server's
			-- life, silently, and the failure would look exactly like a
			-- street that has no traffic on it.
			local ok, err = pcall(run)
			if not ok then
				warn("[TrafficService] van run failed: " .. tostring(err))
				TrafficService.clear()
			end

			task.wait(rng:NextNumber(Config.DELIVERY.gapMin, Config.DELIVERY.gapMax))
		end
	end)
end

return TrafficService
