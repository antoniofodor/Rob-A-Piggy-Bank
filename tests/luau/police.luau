-- The officer's walks, wired: PoliceService drives both of them through
-- `Shared/PathFollower` with `Config.POLICE.path` as the spec, and nothing
-- about the balance -- `officerSpeed`, `catchRadius`, the pose call, the
-- ground raycast, the same-level catch test -- moved. The pond modifier is
-- built on every PondWater, the spec's agent is measured against the real
-- officer, every fence tier's gate admits that agent, and the worst detour
-- the gate costs an officer is measured on the built street and PRINTED.
-- THE STUB IS THE INSTRUMENT AND NOT THE THING: none of this says whether
-- the navmesh will route the officer through the gate on the live street.
-- That is the coordinator's chase.
local Config, SOURCES = ...
local checks = 0
local function check(ok, message) assert(ok, message); checks += 1 end
local function count(text, needle)
	local n, at = 0, 1
	while true do
		local s, e = text:find(needle, at, true)
		if not s then return n end
		n += 1
		at = e + 1
	end
end

-- ---- THE STUB (Grassland's, plus UDim2 and a modifier class) ---------------
local V = {}
V.__index = V
local function vec(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, V) end
function V.__add(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
function V.__sub(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
function V.__mul(a, b)
	if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
	return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
local CF = {}
local function cframe(px, py, pz, r)
	return setmetatable({ p = vec(px, py, pz), r = r or { 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, CF)
end
function CF.__index(self, key)
	if key == "Position" then return rawget(self, "p") end
	if key == "X" then return rawget(self, "p").X end
	if key == "Y" then return rawget(self, "p").Y end
	if key == "Z" then return rawget(self, "p").Z end
	local r = rawget(self, "r")
	if key == "LookVector" then return vec(-r[3], -r[6], -r[9]) end
	if key == "RightVector" then return vec(r[1], r[4], r[7]) end
	if key == "UpVector" then return vec(r[2], r[5], r[8]) end
	return rawget(CF, key)
end
local function mul3(a, b)
	local o = {}
	for i = 0, 2 do for j = 0, 2 do
		local acc = 0
		for k = 0, 2 do acc += a[i * 3 + k + 1] * b[k * 3 + j + 1] end
		o[i * 3 + j + 1] = acc
	end end
	return o
end
local function apply(r, v)
	return vec(r[1] * v.X + r[2] * v.Y + r[3] * v.Z, r[4] * v.X + r[5] * v.Y + r[6] * v.Z,
		r[7] * v.X + r[8] * v.Y + r[9] * v.Z)
end
function CF.__mul(a, b)
	if getmetatable(b) == V then local w = apply(a.r, b); return vec(a.p.X + w.X, a.p.Y + w.Y, a.p.Z + w.Z) end
	local w = apply(a.r, b.p)
	return cframe(a.p.X + w.X, a.p.Y + w.Y, a.p.Z + w.Z, mul3(a.r, b.r))
end
local CFrame = {}
CFrame.new = function(x, y, z) if type(x) == "table" then return cframe(x.X, x.Y, x.Z) end return cframe(x or 0, y or 0, z or 0) end
CFrame.Angles = function(rx, ry, rz)
	rx, ry, rz = rx or 0, ry or 0, rz or 0
	local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
	return cframe(0, 0, 0, mul3(mul3({ 1, 0, 0, 0, cx, -sx, 0, sx, cx }, { cy, 0, sy, 0, 1, 0, -sy, 0, cy }), { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }))
end
CFrame.identity = cframe(0, 0, 0)
local CM = { __index = { Lerp = function(self) return self end } }
local Color3 = {
	fromRGB = function(r, g, b) return setmetatable({ r, g, b }, CM) end,
	new = function(r, g, b) return setmetatable({ r, g, b }, CM) end,
}
local Enum = setmetatable({}, { __index = function(_, group)
	return setmetatable({}, { __index = function(_, name) return group .. "." .. name end })
end })
local value = function(...) return { ... } end
local INST = {}
INST.__index = function(self, key) return rawget(INST, key) end
INST.__newindex = function(self, key, v)
	if key == "Parent" then
		rawset(self, "Parent", v)
		if type(v) == "table" and rawget(v, "_kids") then table.insert(rawget(v, "_kids"), self) end
		return
	end
	rawset(self, key, v)
end
function INST:IsA(c)
	local cls = rawget(self, "ClassName")
	return cls == c or (c == "BasePart" and (cls == "Part" or cls == "WedgePart"))
end
function INST:GetChildren() return rawget(self, "_kids") end
function INST:FindFirstChild(name)
	for _, kid in ipairs(rawget(self, "_kids")) do if rawget(kid, "Name") == name then return kid end end
	return nil
end
local Instance = { new = function(class)
	return setmetatable({ ClassName = class, Name = class, _kids = {}, Size = vec(1, 1, 1),
		CFrame = CFrame.identity, Shape = "PartType.Block" }, INST)
end }
local warnings = {}
local anyService = setmetatable({}, { __index = function() return function() end end })
local shared = setmetatable({}, { __index = function(_, mod) return { __module = mod } end })
local function load(name)
	local loaded = { Config = Config }
	local env
	local function req(token)
		local mod = type(token) == "table" and token.__module or tostring(token)
		if loaded[mod] then return loaded[mod] end
		assert(SOURCES[mod], name .. " requires something this suite does not carry: " .. mod)
		local run = assert(loadstring(SOURCES[mod], mod))
		setfenv(run, env)
		loaded[mod] = run()
		return loaded[mod]
	end
	env = setmetatable({
		Color3 = Color3, Vector3 = { new = vec }, Vector2 = { new = vec }, CFrame = CFrame, Enum = Enum,
		UDim2 = { new = value }, UDim = { new = value },
		Instance = Instance, require = req,
		warn = function(message) table.insert(warnings, tostring(message)) end,
		game = { GetService = function(_, svc) if svc == "ReplicatedStorage" then return { Shared = shared } end return anyService end },
	}, { __index = getfenv() })
	return req({ __module = name })
end

local P = Config.POLICE
local spec = P.path
local police = SOURCES.PoliceService
local follower = SOURCES.PathFollower

-- ---- THE SPEC EXISTS AND IS THE POLICE'S ------------------------------------
check(type(spec) == "table", "Config.POLICE.path is the follower's spec")
check(spec.agentCanJump == false, "the officer does not jump: a fence is a wall to it, as it is to a player on a moat plot")
check(spec.replanDistance == 4 and spec.replanSeconds == 0.4, "recompute at four studs of drift, never more than every 0.4s")
check(spec.maxWaypoints >= 40, "enough waypoints for a chase the length of a plot at the default spacing: " .. spec.maxWaypoints)
check(spec.waypointReach > 0 and spec.waypointReach <= 1.5, "a waypoint is reached inside a tolerance, never on an exact compare")
check(spec.costs == nil, "no costs row: the pond modifier it was written for measured as doing nothing, and the rim stones collide instead")

-- ---- THE AGENT IS MEASURED AGAINST THE REAL OFFICER ------------------------
local PoliceModel = load("PoliceModel")
local officer = PoliceModel.buildOfficer(CFrame.new(0, 0, 0), Instance.new("Folder"))
local reach, crown = 0, 0
for _, piece in ipairs(officer.pieces) do
	local p = piece.part
	local pos = p.CFrame.Position
	-- Every officer part is authored unrotated, so the far corner on the flat
	-- is the offset plus the half size on each axis.
	local corner = math.sqrt((math.abs(pos.X) + p.Size.X / 2) ^ 2 + (math.abs(pos.Z) + p.Size.Z / 2) ^ 2)
	reach = math.max(reach, corner)
	crown = math.max(crown, pos.Y + p.Size.Y / 2)
end
check(reach > 1.5, "the officer is a real width: " .. reach)
check(spec.agentRadius >= reach, ("agentRadius %.2f covers the officer's widest reach %.3f"):format(spec.agentRadius, reach))
check(spec.agentRadius <= reach + 0.5, "and is not padded past the body by more than half a stud")
check(spec.agentHeight >= crown, ("agentHeight %.2f covers the cap's crown at %.3f"):format(spec.agentHeight, crown))
check(spec.agentHeight <= crown + 0.5, "and not more")

-- ---- THE GATE, NOT THE FENCE ------------------------------------------------
-- The path routes through the plot's open gate; every tier's gate has to be
-- wider than the agent's diameter or the officer can never enter that plot.
local narrowest = math.huge
for _, tier in ipairs(Config.FENCE_TIERS) do
	check(tier.gate > 2 * spec.agentRadius,
		("%s: gate %d admits a %.1f-wide agent"):format(tier.label, tier.gate, 2 * spec.agentRadius))
	narrowest = math.min(narrowest, tier.gate)
end
print(("police: narrowest gate %d against an agent %.1f wide -- %.1f studs of navmesh through it"):format(
	narrowest, 2 * spec.agentRadius, narrowest - 2 * spec.agentRadius))

-- ---- THE POND RIM IS THE OBSTACLE ------------------------------------------
-- Measured live, twice: a PathfindingModifier on the non-colliding water did
-- nothing, and colliding rim stones 1.6 proud were STEPPED -- every pond
-- still crossed dead centre -- while 7.5-tall colliding columns on the rim
-- pushed the path 19 studs out. So every rim stone carries an invisible
-- colliding column over `Config.jumpReach()` plus `GRASSLAND.rimJumpMargin`,
-- and the ring of columns has no gap an officer's agent could fit through:
-- adjacent columns' edge-to-edge gap under 2 x agentRadius all the way
-- round every pond, measured on the built ring at column level. The stones
-- collide too (the rock is what a player bumps); water, bed, reeds and pads
-- stay decoration, unreachable now that the ring is a wall to everyone.
local Grassland = load("Grassland")
local world = Instance.new("Folder")
local folder, ponds, partCount = Grassland.build(world, {})
local pondGround = Config.herdGround().groundY
local function flatDist(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end
local wallsOf, stones = {}, 0
local wallFloor = pondGround + Config.jumpReach() + Config.GRASSLAND.rimJumpMargin
for _, p in ipairs(folder:GetChildren()) do
	if p.Name == "PondStone" then
		stones += 1
		check(p.CanCollide == true and p.CanQuery == false and p.CanTouch == false, "a rim stone collides, answers no query and fires no Touched")
	elseif p.Name == "RimWall" then
		check(p.CanCollide == true and p.CanQuery == false and p.CanTouch == false and p.Anchored == true and p.Transparency == 1,
			"a rim wall collides, answers no query, fires no Touched and is invisible")
		check(p.Shape == "PartType.Cylinder" and math.abs(p.CFrame.RightVector.Y) > 0.999, "and is an upright column")
		local top = p.CFrame.Position.Y + p.Size.X / 2
		check(top >= wallFloor - 1e-6, ("its top %.2f over the ground beats jumpReach + margin %.2f: a wall, not a step"):format(top - pondGround, wallFloor - pondGround))
		local best, bestD = nil, math.huge
		for i, pond in ipairs(ponds) do
			local d = flatDist(p.CFrame.Position.X, p.CFrame.Position.Z, pond.x, pond.z)
			if d < bestD then best, bestD = i, d end
		end
		wallsOf[best] = wallsOf[best] or {}
		table.insert(wallsOf[best], p)
	elseif p.Name == "PondWater" or p.Name == "PondBed" or p.Name == "Reed" or p.Name == "LilyPad" then
		check(p.CanCollide == false, p.Name .. " stays non-colliding decoration")
	end
end
local worstGap, ringGaps, wallCount = 0, 0, 0
local diameter = 2 * spec.agentRadius
for i, pond in ipairs(ponds) do
	local walls = wallsOf[i]
	check(walls ~= nil and #walls >= 6, ("pond %d has a ring of walls: %d"):format(i, walls and #walls or 0))
	wallCount += #walls
	table.sort(walls, function(a, b)
		return math.atan2(a.CFrame.Position.Z - pond.z, a.CFrame.Position.X - pond.x)
			< math.atan2(b.CFrame.Position.Z - pond.z, b.CFrame.Position.X - pond.x)
	end)
	for k, a in ipairs(walls) do
		local b = walls[k % #walls + 1]
		local ra, rb = a.Size.Y / 2, b.Size.Y / 2 -- a cylinder's cross-section is Y and Z
		local centres = flatDist(a.CFrame.Position.X, a.CFrame.Position.Z, b.CFrame.Position.X, b.CFrame.Position.Z)
		local gap = centres - ra - rb
		ringGaps += 1
		check(gap < diameter, ("pond %d: wall gap %.2f is under an agent %.1f wide"):format(i, gap, diameter))
		worstGap = math.max(worstGap, gap)
	end
end
check(wallCount == stones, ("one wall per stone: %d walls, %d stones"):format(wallCount, stones))
check(ringGaps > 6 * #ponds, "every adjacent pair round every pond was measured: " .. ringGaps)
check(partCount <= Config.GRASSLAND.budget, ("the grassland with its walls is under budget: %d of %d"):format(partCount, Config.GRASSLAND.budget))
check(SOURCES.Grassland:find("function Grassland.blocks(position: Vector3): boolean", 1, true) ~= nil
	and SOURCES.Grassland:find("RimWall", 1, true) > SOURCES.Grassland:find("function Grassland.blocks(position: Vector3): boolean", 1, true),
	"Grassland.blocks reads the layout; the walls are built below it and it never names them")
print(("police: pond rims -- %d walls over %d stones, tops %.2f over the ground (jumpReach %.2f + margin %.1f), widest gap at column level %.2f studs against an agent %.1f wide; %d pairs over %d ponds; %d of %d parts"):format(
	wallCount, stones, wallFloor - pondGround, Config.jumpReach(), Config.GRASSLAND.rimJumpMargin, worstGap, diameter, ringGaps, #ponds, partCount, Config.GRASSLAND.budget))

-- ---- THE WIRING -------------------------------------------------------------
check(police:find("local PathFollower = require(ReplicatedStorage.Shared.PathFollower)", 1, true) ~= nil,
	"PoliceService requires the follower from Shared")
check(count(police, "PathFollower.new(Config.POLICE.path)") == 1, "one follower per pursuit, built on the POLICE spec")
check(count(police, "follower:step(at, dt, Config.POLICE.officerSpeed)") == 2,
	"both walks -- the chase and the jog back to the car -- step through the follower at officerSpeed")
check(police:find("follower:setGoal(Vector3.new(lastSeen.X, seenFeet, lastSeen.Z))", 1, true) ~= nil,
	"the chase's goal is where the thief was last seen, at their feet")
check(police:find("follower:setGoal(Vector3.new(target.X, ROAD_Y, target.Z))", 1, true) ~= nil,
	"the return walk's goal is the car door on the road")
check(police:find("+ look * step", 1, true) == nil, "no walk steps straight at its goal any more")
check(count(police, "follower:destroy()") == 1 and police:find("follower:fallbacks()", 1, true) ~= nil,
	"the follower is read for fallbacks and destroyed once, after the return walk")
check(police:find("[PoliceService] pathing fell back", 1, true) ~= nil,
	"a pursuit that fell back to the straight line says so in one warn line")
-- What did not move.
check(police:find("flatDelta.Magnitude <= Config.POLICE.catchRadius", 1, true) ~= nil,
	"the catch is still the flat distance to the thief's real position against catchRadius")
check(police:find("math.abs(seenFeet - at.Y) <= Config.POLICE.catchRise", 1, true) ~= nil, "on the same level")
check(police:find("local groundY = groundUnder(at, at.Y)", 1, true) ~= nil, "the officer's Y is still the ground under it")
check(count(police, "PoliceModel.poseOfficer(hand, facing(at, look), stride)") >= 2, "and it is still posed from the stride")
check(police:find("stride += walked", 1, true) ~= nil, "which accumulates what was actually walked")
check(police:find("at = Vector3.new(moved.X, y, moved.Z)", 1, true) ~= nil,
	"the follower hands back X and Z and PoliceService keeps its own Y")
-- THE RATIO, NEVER THE ABSOLUTE: every speed is `BASE_WALK_SPEED * ratio`
-- (designer, 2026-09-21), so 14.5 is only what 0.90625 comes to at a base of
-- 16 and pinning it would fail for the wrong reason the day the base moves.
check(math.abs(P.officerSpeed / Config.BASE_WALK_SPEED - 0.90625) < 1e-12,
	"officerSpeed is untouched at 0.90625 of the base walk (14.5 at 16)")
check(P.catchRadius == 6.5 and P.chase == 30, "catchRadius and the chase clock are untouched")
check(count(follower, "require(") == 0, "the follower requires nothing -- a resident, a pet or a herd can take it")
check(follower:find('game:GetService("PathfindingService")', 1, true) ~= nil, "and asks only for PathfindingService")
check(follower:find("task.spawn", 1, true) ~= nil and follower:find("ComputeAsync", 1, true) ~= nil,
	"the compute yields in a task of its own, never in the frame loop")
check(follower:find("waypointReach", 1, true) ~= nil and count(follower, "Magnitude ==") == 0 and count(follower, "Magnitude <= reach") >= 1,
	"a waypoint is reached by tolerance and nothing in the follower compares a distance by equality")

-- ---- THE DETOUR THE GATE COSTS, MEASURED ON THE BUILT STREET -----------------
-- An officer deployed from the road to a thief inside a fence has to come in
-- through the gate. Route = door -> gate -> thief, straight = door -> thief,
-- for every tier's gate, every reachable spot inside the yard on a 2-stud
-- grid, and every place the car can have stopped: level with the thief (an
-- alarm pursuit, door eight studs either side of the park) or anywhere it
-- could have SEEN them from (`Config.policeSightRadius`). The shortest route
-- through a gap is the straight line's crossing clamped into the gap, so the
-- gate point is solved rather than searched.
local m = Config.streetMetrics()
local plotX = Config.plotColumnX(0)
local frontZ = m.fenceLine
local backZ = Config.STREET_SPACING / 2 + Config.YARD_DEPTH
local halfW = Config.PLOT_HALF_WIDTH
local r = spec.agentRadius + 0.3 -- the barrier is 0.6 thick on the line
local lane = P.lane
local sight = Config.policeSightRadius()
local function dist(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end
local worst = { detour = 0 }
local worstLevel = { detour = 0 } -- the car parked level with the thief: an alarm pursuit
local evaluated = 0
for _, tier in ipairs(Config.FENCE_TIERS) do
	local gateLo, gateHi = plotX - tier.gate / 2 + r, plotX + tier.gate / 2 - r
	for tx = plotX - halfW + r, plotX + halfW - r, 2 do
		for tz = frontZ + r, backZ - r, 2 do
			local starts = { tx - 8, tx + 8 }
			local levelStarts = 2
			for cx = tx - sight, tx + sight, 2 do
				if dist(cx, lane, tx, tz) <= sight then table.insert(starts, cx) end
			end
			for si, sx in ipairs(starts) do
				local straight = dist(sx, lane, tx, tz)
				-- Where the straight line crosses the fence line, clamped into the gate.
				local t = (frontZ - lane) / (tz - lane)
				local gx = math.clamp(sx + (tx - sx) * t, gateLo, gateHi)
				local route = dist(sx, lane, gx, frontZ) + dist(gx, frontZ, tx, tz)
				local detour = route - straight
				evaluated += 1
				check(detour >= -1e-9, "a route through the gate is never shorter than the straight line")
				local record = { detour = detour, tier = tier.label, thief = { tx - plotX, tz }, car = sx - tx, straight = straight, route = route }
				if detour > worst.detour then worst = record end
				if si <= levelStarts and detour > worstLevel.detour then worstLevel = record end
			end
		end
	end
end
check(evaluated > 100000, "the sweep covered the yard: " .. evaluated)
check(worst.detour > 0, "the gate costs something somewhere")
local seconds = worst.detour / P.officerSpeed
print(("police: worst detour with the car parked LEVEL (an alarm pursuit) %.1f studs = %.2fs (%s; thief %.0f across, z %.0f; door %+.0f along; straight %.1f, route %.1f)"):format(
	worstLevel.detour, worstLevel.detour / P.officerSpeed, worstLevel.tier, worstLevel.thief[1], worstLevel.thief[2], worstLevel.car, worstLevel.straight, worstLevel.route))
print(("police: worst gate detour %.1f studs = %.2fs at %.1f studs/s (%s; thief %.0f across, z %.0f; car %+.0f along; straight %.1f, route %.1f)"):format(
	worst.detour, seconds, P.officerSpeed, worst.tier, worst.thief[1], worst.thief[2], worst.car, worst.straight, worst.route))
check(seconds < P.chase, "the worst detour is a fraction of the chase clock, not the chase")

print(("police: %d checks passed"):format(checks))
