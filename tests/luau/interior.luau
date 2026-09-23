-- The indoor capacity ladder (PIGGY-COLLECTION-PLAN section 6, rewritten
-- 2026-09-20; designer 2026-09-21: a rebirth unlocks 2-3 PLOTS, not a room).
-- Real Config, no engine, no saves. The GEOMETRY that stands on this ladder is
-- `Shared/HouseInterior` and is not testable here -- it needs Instance.new --
-- so what this pins is the arithmetic every part of that builder is sized off.
local Config, SOURCES = ...
local checks = 0
local function check(ok, message) assert(ok, message); checks += 1 end

-- ---- ONE DIAL, AND BOTH NUMBERS COME OUT OF IT -----------------------------
-- The whole reason `plotsPerRebirth` is a fraction: it produces the designer's
-- "two to three" without a per-rebirth table beside it that could disagree.
check(Config.INDOOR_ROOM_PLOTS == Config.INDOOR.plotsPerSide * 2,
	"a room is two rows of plotsPerSide")
check(Config.indoorPlots(0) == Config.INDOOR.startPlots,
	"a save with no rebirths has exactly the starting room")

local grants = {}
local last = Config.indoorPlots(0)
for rebirths = 1, Config.rebirthsToMax() do
	local here = Config.indoorPlots(rebirths)
	check(here > last, "rebirth " .. rebirths .. " opens at least one plot")
	local grant = here - last
	check(grant >= Config.INDOOR.grantBand.min and grant <= Config.INDOOR.grantBand.max,
		("rebirth %d opens %d plots, inside the band"):format(rebirths, grant))
	grants[grant] = (grants[grant] or 0) + 1
	last = here
end
check(grants[2] ~= nil and grants[3] ~= nil,
	"the ladder produces BOTH of the designer's numbers, not one of them twenty times")

-- ---- WHERE IT LANDS ---------------------------------------------------------
local ceiling = Config.indoorPlotCeiling()
check(ceiling >= Config.INDOOR.totalBand.min and ceiling <= Config.INDOOR.totalBand.max,
	"the hallway ends up holding " .. ceiling .. " plots, inside the designed band")
check(ceiling == 56 and Config.indoorRoomCeiling() == 10,
	"56 plots across 10 rooms at the shipped dial, got "
		.. ceiling .. " across " .. Config.indoorRoomCeiling())

-- IT STOPS AT THE REBIRTH CEILING. Rebirths past 20 still pay an income
-- multiplier, so an uncapped ladder would keep asking for corridor nobody has
-- built.
check(Config.indoorPlots(Config.rebirthsToMax() + 1) == ceiling
	and Config.indoorPlots(999) == ceiling,
	"capacity stops at the rebirth ceiling rather than running on")
check(Config.indoorPlots(-4) == Config.INDOOR.startPlots and Config.indoorPlots(nil) == Config.INDOOR.startPlots,
	"nonsense rebirth counts read as none rather than throwing")

-- ---- THE ROOM CADENCE IS THE SAME EXPRESSION, NOT A SECOND ONE -------------
-- A door opens when there is somewhere to STAND past it. At a capacity of
-- exactly one room, the next door stays shut: an open door onto locked plots
-- promises something that is not there.
check(Config.indoorRooms(0) == 1 and Config.indoorRooms(Config.INDOOR_ROOM_PLOTS) == 1,
	"an exactly-full room does not open the door beyond it")
check(Config.indoorRooms(Config.INDOOR_ROOM_PLOTS + 1) == 2,
	"one plot past a full room is what opens the door")
check(Config.indoorRooms(Config.indoorPlots(1)) == 2,
	"the FIRST rebirth opens the first door")
for rebirths = 0, Config.rebirthsToMax() do
	local rooms = Config.indoorRooms(Config.indoorPlots(rebirths))
	check(rooms >= 1 and rooms <= Config.indoorRoomCeiling(),
		"rooms reachable at rebirth " .. rebirths .. " stay inside the hallway that gets built")
end

-- ---- THE ROOMS ADD UP TO THE CEILING ----------------------------------------
-- The last room is built SHORT rather than built full and half locked, so the
-- per-room counts have to sum to the ceiling exactly.
local summed = 0
for room = 1, Config.indoorRoomCeiling() do
	local n = Config.indoorPlotsInRoom(room)
	check(n >= 1 and n <= Config.INDOOR_ROOM_PLOTS, "room " .. room .. " holds a sane number of plots")
	summed += n
end
check(summed == ceiling, "the rooms add up to the ceiling: " .. summed .. " against " .. ceiling)
check(Config.indoorPlotsInRoom(Config.indoorRoomCeiling() + 5) == 0,
	"a room past the end of the hallway holds nothing")

-- ---- WHAT A DOOR PRINTS IS THE LADDER'S OWN NUMBER --------------------------
-- The reference puts "Need 2 Rebirths" on the locked door. The count on the
-- leaf comes off `indoorPlots` and never off a second table, so this walks
-- every built room and checks the door's number against the door opening.
check(Config.indoorDoorRebirths(1) == 0, "the first room needs no rebirth")
check(Config.indoorDoorRebirths(2) == 1, "the first door says one rebirth, which is when it opens")
local lastGate = -1
for room = 1, Config.indoorRoomCeiling() do
	local gate = Config.indoorDoorRebirths(room)
	check(gate ~= nil, "room " .. room .. " has a rebirth that opens it")
	check(gate >= lastGate, "room " .. room .. " opens no earlier than the room before it")
	check(Config.indoorRooms(Config.indoorPlots(gate)) >= room,
		"at the printed count room " .. room .. " is actually open")
	if gate > 0 then
		check(Config.indoorRooms(Config.indoorPlots(gate - 1)) < room,
			"and one rebirth earlier room " .. room .. " is still shut")
	end
	lastGate = gate
end
check(Config.indoorDoorRebirths(Config.indoorRoomCeiling() + 1) == nil,
	"a room past the hallway has no rebirth that opens it")

-- ---- THE BOOT AUDIT, PROVOKED RATHER THAN TRUSTED ---------------------------
check(#Config.auditIndoor() == 0, "the shipped ladder audits clean")

local function provoke(mutate, restore, wanted, why)
	mutate()
	local problems = Config.auditIndoor()
	local fired = false
	for _, p in problems do
		if p:find(wanted, 1, true) then fired = true end
	end
	restore()
	check(fired, why)
	check(#Config.auditIndoor() == 0, "audit clean again after: " .. why)
end

-- A dial too small to move the ladder: the plan asks for this one by name.
provoke(function() Config.INDOOR.plotsPerRebirth = 0.4 end,
	function() Config.INDOOR.plotsPerRebirth = 2.5 end,
	"[indoor.ladder]", "audit refuses a rebirth that opens no new plot")

-- A dial that blows past the designer's two-to-three.
provoke(function() Config.INDOOR.plotsPerRebirth = 6 end,
	function() Config.INDOOR.plotsPerRebirth = 2.5 end,
	"[indoor.grant]", "audit refuses a rebirth handing over six plots at once")

-- A dial that keeps the band and overshoots the total.
provoke(function() Config.INDOOR.startPlots = 40 end,
	function() Config.INDOOR.startPlots = 6 end,
	"[indoor.total]", "audit refuses a hallway holding more than the plan designed for")

-- The derivation hand-edited apart, which is the failure this whole block is
-- shaped to avoid: one ladder described twice.
provoke(function() Config.INDOOR_ROOM_PLOTS = 7 end,
	function() Config.INDOOR_ROOM_PLOTS = Config.INDOOR.plotsPerSide * 2 end,
	"[indoor.room]", "audit refuses a room size that disagrees with plotsPerSide")

-- ---- THE SIGHTLINE, TRACED THROUGH THE REAL BUILDER --------------------------
-- The designer's rule for the arches: once rooms are unlocked you can see the
-- piggies all the way down the hall from the entrance. That is a claim about
-- geometry this suite cannot make from Config, so the builder is loaded here
-- under a small engine stub -- real 3x3 CFrames and counted Instances, no
-- rendering -- and a line is traced from the entrance's eye to every plot
-- with every door open. Anything in the model that crosses it fails.
--
-- THE STUB IS THE INSTRUMENT AND NOT THE THING: it proves the parts are not
-- in the way, and says nothing about what the picture looks like.
local sightChecks = 0
do
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
		if key == "ZVector" then return vec(r[3], r[6], r[9]) end
		if key == "XVector" then return vec(r[1], r[4], r[7]) end
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
	-- world -> this frame's own space: transpose of the rotation
	function CF.PointToObjectSpace(self, w)
		local d = w - self.p
		local r = self.r
		return vec(r[1] * d.X + r[4] * d.Y + r[7] * d.Z, r[2] * d.X + r[5] * d.Y + r[8] * d.Z,
			r[3] * d.X + r[6] * d.Y + r[9] * d.Z)
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
		fromHSV = function(h, s, v) return setmetatable({ h, s, v }, CM) end,
	}
	local Enum = setmetatable({}, { __index = function(_, group)
		return setmetatable({}, { __index = function(_, name) return group .. "." .. name end })
	end })
	local INST = {}
	INST.__index = function(self, key) return rawget(INST, key) end
	INST.__newindex = function(self, key, value)
		if key == "Parent" then
			rawset(self, "Parent", value)
			if type(value) == "table" and rawget(value, "_kids") then table.insert(rawget(value, "_kids"), self) end
			return
		end
		rawset(self, key, value)
	end
	function INST:SetAttribute(k, v) rawget(self, "_attr")[k] = v end
	function INST:GetAttribute(k) return rawget(self, "_attr")[k] end
	function INST:IsA(c)
		local cls = rawget(self, "ClassName")
		return cls == c or (c == "BasePart" and (cls == "Part" or cls == "WedgePart"))
	end
	function INST:GetChildren() return rawget(self, "_kids") end
	local Instance = { new = function(class)
		return setmetatable({ ClassName = class, Name = class, _kids = {}, _attr = {}, Size = vec(1, 1, 1), CFrame = CFrame.identity }, INST)
	end }
	local UDim2 = { fromScale = function(x, y) return { x, y } end }
	local anyService = setmetatable({}, { __index = function(_, k) return function() end end })
	local shared = setmetatable({}, { __index = function(_, mod) return { __module = mod } end })
	-- A FRESH LOADER PER SOURCE, so a deliberately broken copy of the builder
	-- can be built beside the real one and the checks below proved to fire.
	local function loadInterior(interiorSource)
		local modules = {
			LowPoly = SOURCES.LowPoly,
			HouseInterior = interiorSource,
			Theme = "return { FONT = 'FredokaOne', INK = Color3.fromRGB(41, 32, 27), PAPER = Color3.fromRGB(255, 247, 232) }",
		}
		local loaded = { Config = Config }
		local env
		local function req(token)
			local name = type(token) == "table" and token.__module or tostring(token)
			if loaded[name] then return loaded[name] end
			local run = assert(loadstring(modules[name], name))
			setfenv(run, env)
			loaded[name] = run()
			return loaded[name]
		end
		env = setmetatable({
			Color3 = Color3, Vector3 = { new = vec }, Vector2 = { new = vec }, CFrame = CFrame, Enum = Enum,
			Instance = Instance, UDim2 = UDim2, require = req,
			game = { GetService = function(_, name) if name == "ReplicatedStorage" then return { Shared = shared } end return anyService end },
		}, { __index = getfenv() })
		return req({ __module = "HouseInterior" })
	end

	local HouseInterior = loadInterior(SOURCES.HouseInterior)
	local refs = HouseInterior.build({ _kids = {} }, CFrame.new(0, 0, 0), nil)
	local parts = {}
	for _, p in ipairs(refs.model:GetChildren()) do
		if p:IsA("BasePart") then table.insert(parts, p) end
	end

	-- Segment against an oriented box: both ends into the part's own frame,
	-- then a slab test. Rotated parts (the vault, the ribs) are tested as the
	-- boxes they are rather than as their bounding boxes.
	local function blocked(a, b)
		for _, p in ipairs(parts) do
			local la, lb = p.CFrame:PointToObjectSpace(a), p.CFrame:PointToObjectSpace(b)
			local h = { p.Size.X / 2, p.Size.Y / 2, p.Size.Z / 2 }
			local A, B = { la.X, la.Y, la.Z }, { lb.X, lb.Y, lb.Z }
			local t0, t1, hit = 0, 1, true
			for ax = 1, 3 do
				local d = B[ax] - A[ax]
				if math.abs(d) < 1e-9 then
					if A[ax] < -h[ax] or A[ax] > h[ax] then hit = false break end
				else
					local ta, tb = (-h[ax] - A[ax]) / d, (h[ax] - A[ax]) / d
					if ta > tb then ta, tb = tb, ta end
					t0, t1 = math.max(t0, ta), math.min(t1, tb)
					if t0 > t1 then hit = false break end
				end
			end
			if hit then return p.Name end
		end
		return nil
	end

	-- A character's root stands about 3.2 studs up and its eyes a stud and a
	-- half above that; a piggy on a plot is about three studs above the face.
	local eye = refs.entrance.Position + vec(0, 4.7, 0)
	HouseInterior.setCapacity(refs, Config.indoorPlotCeiling())
	local farthest = 0
	for _, plot in ipairs(refs.plots) do
		local target = plot.ground.Position + vec(0, 3.0, 0)
		local what = blocked(eye, target)
		check(what == nil, ("plot %d in room %d is in sight from the entrance with every door open (blocked by %s)")
			:format(plot.index, plot.room, tostring(what)))
		sightChecks += 1
		farthest = math.max(farthest, target.X - eye.X)
	end
	check(farthest > 250, "the farthest plot is a real distance away: " .. farthest)

	-- AND THE TEST CAN FAIL: with every door shut the second room is behind a
	-- leaf, which is what a locked door is for.
	HouseInterior.setCapacity(refs, 0)
	local second = refs.plots[Config.INDOOR_ROOM_PLOTS + 1]
	check(blocked(eye, second.ground.Position + vec(0, 3.0, 0)) == "DoorLeaf",
		"with every door shut the first locked room is behind a leaf")
	-- And an open leaf is not merely non-colliding but OUT OF THE ROOM, below
	-- the floor, so it cannot stand along a platform hiding a plot.
	HouseInterior.setDoor(refs.doors[1], true)
	local leaf = refs.doors[1].leaves[1]
	check(leaf.CFrame.Position.Y + leaf.Size.Y / 2 < 0, "an open leaf sits wholly below the floor")
	check(leaf.CanCollide == false, "and does not collide")

	-- ---- THE VAULT IS AN ARCH AND NOT A SAWTOOTH ------------------------------
	-- Photographed live: every facet's centre sat on the arc and every facet
	-- SLOPED AGAINST it, with sky showing through the wedge between each pair.
	-- Nothing above could see it -- a vertical ray stops on the first top face
	-- and no plot sightline crosses the roof -- so this asks two things the
	-- picture asked: is each facet's width axis the arc's tangent at its own
	-- angle, and does the ceiling fall monotonically from the ridge outward
	-- with nothing but facet above every point.
	local function vaultShape(module, built)
		local radius, _, centreY = module.vaultArc()
		local facets = {}
		for _, p in ipairs(built.model:GetChildren()) do
			if p:IsA("BasePart") and p.Name == "Collide_Vault" then table.insert(facets, p) end
		end
		local worstTangent = 1
		for _, f in ipairs(facets) do
			local c = f.CFrame.Position
			local ny, nz = c.Y - centreY, c.Z
			local n = math.sqrt(ny * ny + nz * nz)
			-- radial (0, cos phi, sin phi) -> tangent (0, -sin phi, cos phi)
			local ty, tz = -nz / n, ny / n
			local w = f.CFrame.ZVector
			worstTangent = math.min(worstTangent, math.abs(w.Y * ty + w.Z * tz))
		end
		-- The ceiling's height at (x, z): the lowest INNER face of any facet
		-- standing over that point.
		local x = built.plots[1].ground.Position.X
		local function ceilingAt(z)
			local best = nil
			for _, f in ipairs(facets) do
				local r, c = f.CFrame.r, f.CFrame.Position
				local dx, dz = x - c.X, z - c.Z
				-- local y = r[2]*dx + r[5]*dy + r[8]*dz = -thickness/2 on the inner face
				if math.abs(r[5]) > 1e-6 then
					local dy = (-f.Size.Y / 2 - r[2] * dx - r[8] * dz) / r[5]
					local lz = r[3] * dx + r[6] * dy + r[9] * dz
					if math.abs(lz) <= f.Size.Z / 2 then
						local y = c.Y + dy
						if best == nil or y < best then best = y end
					end
				end
			end
			return best
		end
		local monotone, covered, last = true, true, math.huge
		local half = Config.INDOOR_ROOM_PLOTS > 0 and (built.plots[1].ground.Position.Z * -1) or 0
		-- from the ridge out to just inside the wall, both sides
		local reach = math.abs(built.plots[1].ground.Position.Z) + 5
		for i = 0, 40 do
			local z = reach * i / 40
			local h = ceilingAt(z)
			if h == nil then covered = false break end
			if h > last + 1e-6 then monotone = false end
			last = h
		end
		return worstTangent, monotone, covered, #facets
	end

	local tangent, monotone, covered, count = vaultShape(HouseInterior, refs)
	check(count >= 4, "the vault is built from facets: " .. count)
	check(tangent > 0.999, "every facet's width axis lies along the arc's tangent (worst " .. tangent .. ")")
	check(monotone, "the ceiling falls monotonically from the ridge outward")
	check(covered, "there is facet over every point of the hall's width")

	-- PROVED TO FIRE: the sawtooth version, rebuilt from the source with the
	-- one sign flipped back, fails both of the checks that would have caught
	-- it.
	local flipped, n = SOURCES.HouseInterior:gsub("CFrame%.Angles%(phi, 0, 0%)", "CFrame.Angles(-phi, 0, 0)")
	check(n == 2, "the tilt is written in exactly two places, the vault and the ribs: " .. n)
	local broken = loadInterior(flipped)
	local bTangent, bMonotone = vaultShape(broken, broken.build({ _kids = {} }, CFrame.new(0, 0, 0), nil))
	check(bTangent < 0.99, "the sawtooth's facets are off the tangent (worst " .. bTangent .. ")")
	check(not bMonotone, "and its ceiling dips and rises, which an arch cannot do")
end

print(("interior: %d checks passed (%d sightlines)"):format(checks, sightChecks))
