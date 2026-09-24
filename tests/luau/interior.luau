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
	local function vec(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, V) end
	-- `Unit` and `Magnitude` are PROPERTIES on a real Vector3, so `__index` has
	-- to be a function rather than the table itself: the frames the second
	-- builder derives are built out of both.
	function V.__index(self, key)
		local x, y, z = rawget(self, "X"), rawget(self, "Y"), rawget(self, "Z")
		if key == "Magnitude" then return math.sqrt(x * x + y * y + z * z) end
		if key == "Unit" then
			local m = math.sqrt(x * x + y * y + z * z)
			return vec(x / m, y / m, z / m)
		end
		return rawget(V, key)
	end
	function V.Cross(a, b)
		return vec(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
	end
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
		if key == "XVector" or key == "RightVector" then return vec(r[1], r[4], r[7]) end
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
	-- A DIRECTION into this frame's own space: the same transpose with no
	-- translation. The second builder asserts its own turns with it.
	function CF.VectorToObjectSpace(self, v)
		local r = self.r
		return vec(r[1] * v.X + r[4] * v.Y + r[7] * v.Z, r[2] * v.X + r[5] * v.Y + r[8] * v.Z,
			r[3] * v.X + r[6] * v.Y + r[9] * v.Z)
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
	-- Columns are Right, Up, Z, which is the convention `InteriorService.facing`
	-- and the wrapper's `originFrame` both STATE rather than take from
	-- `CFrame.lookAt`.
	CFrame.fromMatrix = function(pos, vx, vy, vz)
		return cframe(pos.X, pos.Y, pos.Z, { vx.X, vy.X, vz.X, vx.Y, vy.Y, vz.Y, vx.Z, vy.Z, vz.Z })
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
	local notices = {}
	-- A FRESH LOADER PER SOURCE, so a deliberately broken copy of the builder
	-- can be built beside the real one and the checks below proved to fire.
	local function loadInterior(interiorSource)
		local modules = {
			LowPoly = SOURCES.LowPoly,
			ThemedInterior = SOURCES.ThemedInterior,
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
			Color3 = Color3, Vector3 = { new = vec, yAxis = vec(0, 1, 0) }, Vector2 = { new = vec },
			CFrame = CFrame, Enum = Enum,
			Instance = Instance, UDim2 = UDim2, require = req,
			-- CAPTURED RATHER THAN SWALLOWED: a fallback nobody can see is the
			-- failure this project refuses above all others, so the notices a
			-- missing kit produces are something the checks below read.
			warn = function(message) table.insert(notices, tostring(message)) end,
			-- AN EMPTY `ServerStorage`, WHICH IS THE SHAPE OF A SERVER WITH NO
			-- KITS SYNCED -- an older `rojo serve`, or a `rojo build` from a
			-- project file without the rows -- and therefore the fallback path
			-- under test. It is a real stub rather than `anyService` because
			-- `GetChildren` has to hand back a table: the wrapper resolves a
			-- kit by sweeping for its NAME so a duplicate can be counted.
			game = { GetService = function(_, name)
				if name == "ReplicatedStorage" then return { Shared = shared } end
				if name == "ServerStorage" then return { GetChildren = function() return {} end } end
				return anyService
			end },
		}, { __index = getfenv() })
		return req({ __module = "HouseInterior" }), req
	end

	local HouseInterior, load = loadInterior(SOURCES.HouseInterior)
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


	-- ---- THE AUTHORED INTERIORS, BEHIND THE SAME CONTRACT ---------------------
	-- Interiors are PER HOUSE THEME -- the concept's own direction -- and three
	-- of the eighteen are built (`assets/houses/interiors/`). Checked rather
	-- than assumed: their three `Builder.luau` copies are byte-identical apart
	-- from the kit folder named in a comment and the `model.Name` they stamp, so
	-- ONE wrapper serves all three and what varies is a registry row.
	--
	-- The wrapper has to hand `InteriorService` the shape the generic hall hands
	-- it, or the door crossing, the exit gate, `homeOf` and the indoor plots all
	-- grow a branch. None of the kits' ART is reachable from here; what is, is
	-- every derivation the wrapper makes on top of it and the wiring that
	-- chooses between the two builders.
	local Themed = load({ __module = "ThemedInterior" })

	-- ONE INTERFACE, TWO IMPLEMENTATIONS. `InteriorService` holds one of these
	-- in a field and calls through it, so a name on one and not the other is a
	-- hallway that half works.
	for _, name in ipairs({ "build", "setCapacity", "setDoor", "dress", "plotGround", "footprint" }) do
		check(type(HouseInterior[name]) == "function" and type(Themed[name]) == "function",
			"both builders export " .. name)
	end

	-- ---- THE PRIMARYPART REPAIR ---------------------------------------------
	-- `rojo serve` 7.7 drops every `PrimaryPart` Ref inside an `.rbxmx`
	-- (measured 2026-09-23: 18 refs per kit file, 0 on the synced Models), and
	-- a kit cannot stand without them -- the anchors are looked up through the
	-- primary part and the Builder pivots clones by it. The wrapper gives each
	-- template Model its `Root` back once, at resolve time, and says how many.
	-- Proved on a mock tree rather than read off the source: one Model with a
	-- Root and no PrimaryPart (repaired), one that already has one (untouched),
	-- one with no Root (left alone, like the gate's panels), and a non-Model.
	do
		local function part(name) return { Name = name, ClassName = "Part",
			IsA = function(self, c) return c == "BasePart" or c == "Part" end } end
		local function model(name, root, primary)
			local m = { Name = name, ClassName = "Model", PrimaryPart = primary,
				IsA = function(_, c) return c == "Model" end }
			m.FindFirstChild = function(_, n) return if root and root.Name == n then root else nil end
			return m
		end
		local rootA, rootB = part("Root"), part("Root")
		local bare, kept, panel = model("Pedestal", rootA, nil), model("RoomShell", rootB, rootB), model("Panel_1_L", nil, nil)
		local folder = { Name = "Base", ClassName = "Folder", IsA = function(_, c) return c == "Folder" end }
		local tree = { GetDescendants = function() return { bare, kept, panel, folder, rootA } end }
		local n = Themed.repairTemplates(tree)
		check(n == 1, "exactly the Model with a Root and no PrimaryPart is repaired: " .. tostring(n))
		check(bare.PrimaryPart == rootA, "and it is given its own Root part")
		check(kept.PrimaryPart == rootB, "a Model that already carries a PrimaryPart is not touched")
		check(panel.PrimaryPart == nil, "a sub-model with no Root is left alone rather than given a stranger's part")
		check(Themed.repairTemplates(tree) == 0, "running it again repairs nothing, so it is safe on every resolve")
	end
	check(SOURCES.ThemedInterior:find("ThemedInterior.repairTemplates(templates)", 1, true) ~= nil
			and SOURCES.ThemedInterior:find("function ThemedInterior.repairTemplates(", 1, true)
				< SOURCES.ThemedInterior:find("local function resolve(", 1, true),
		"resolve() runs the repair on the kit's template tree, and the repair is declared above it")

	-- ---- THE REGISTRY, AND IT IS KEYED BY HOUSE TIER --------------------------
	local ids = Themed.houseIds()
	check(#ids == #Config.HOUSE_TIERS, "every permanent house has an authored interior: " .. #ids)
	for _, id in ipairs(ids) do
		check(Config.getHouseById(id) ~= nil, id .. " is a real house tier id")
		local kit = Themed.kitName(Config.getHouseById(id))
		check(type(kit) == "string" and kit:sub(-11) == "InteriorKit",
			id .. " points at a kit named for ServerStorage: " .. tostring(kit))
	end
	-- THE FREE STARTER TIER IS ONE OF THEM, which is what makes the part budget
	-- a budget rather than a note: every new save's interior is the Cardboard
	-- Fort's rather than the 37-part generic hall.
	check(Themed.kitName(Config.getHouseById("shack")) == "CardboardFortInteriorKit",
		"the free Cardboard Fort has an authored interior")
	check(Themed.kitName(Config.getHouseById("skycastle")) == "SkyCastleInteriorKit",
		"Sky Castle uses its own authored interior")
	check(Themed.kitName({id="unregistered-test-house"}) == nil,
		"an unregistered house still falls back rather than resolving a wrong kit")
	check(Themed.kitName(nil) == nil and Themed.kitName({}) == nil and Themed.kitName("shack") == nil,
		"a missing or malformed tier reads as no kit rather than throwing")

	-- READ THROUGH A FALLBACK, so this boots whether or not Config carries the
	-- rows -- the same call `Config.HOUSE_MESH` takes for a row that has not
	-- landed. The rows LANDED on 2026-09-23, so the live table is checked
	-- against the module's own copy (the two must agree or a kit is wired to
	-- one house in Config and another in the fallback), then provoked from
	-- both sides: a Config table WINS, and taking it away restores the copy.
	local live = rawget(Config, "HOUSE_INTERIOR_KITS")
	check(type(live) == "table" and live.shack == "CardboardFortInteriorKit"
			and live.cottage == "BeehiveCottageInteriorKit" and live.treehouse == "TreehouseInteriorKit",
		"Config carries the registry, and it names the three kits the fallback names")
	Config.HOUSE_INTERIOR_KITS = { manor = "HauntedManorInteriorKit" }
	check(Themed.kitName(Config.getHouseById("manor")) == "HauntedManorInteriorKit"
			and Themed.kitName(Config.getHouseById("shack")) == nil,
		"a registry in Config is read in preference to the fallback")
	Config.HOUSE_INTERIOR_KITS = nil
	check(Themed.kitName(Config.getHouseById("shack")) == "CardboardFortInteriorKit",
		"and the fallback is back when it is taken away again")
	Config.HOUSE_INTERIOR_KITS = live

	-- ---- THE FALLBACK, WHICH IS THE STATE THIS HARNESS IS IN ------------------
	-- No kits in ServerStorage: an older `rojo serve`, or a `rojo build` from a
	-- project file without the rows. A server in that state has to BOOT and
	-- still have interiors.
	for _, id in ipairs(ids) do
		check(Themed.available(Config.getHouseById(id)) == false,
			"with no kits in ServerStorage " .. id .. " reports unavailable")
	end
	check(Themed.available(Config.getHouseById("skycastle")) == false,
		"and so does a house that has no kit at all")
	local said = 0
	for _, notice in ipairs(notices) do
		if notice:find("InteriorKit", 1, true) then said += 1 end
	end
	check(said == #ids, "each missing kit says itself ONCE: " .. said)
	for _, id in ipairs(ids) do
		Themed.available(Config.getHouseById(id))
	end
	local again = 0
	for _, notice in ipairs(notices) do
		if notice:find("InteriorKit", 1, true) then again += 1 end
	end
	check(again == said, "and asking again says nothing, which a lazy resolve behind a poll must not")

	local fallback = Themed.footprint()
	check(fallback.X == HouseInterior.footprint().X and fallback.Z == HouseInterior.footprint().Z,
		"the footprint falls back to the generic hall's, so the estate still spaces itself")
	check(pcall(Themed.build, { _kids = {} }, CFrame.new(0, 0, 0), Config.getHouseById("shack"), 1) == false,
		"and building one refuses out loud rather than half-building a hall nobody can leave")

	-- ---- THE PLOT LADDER IS ONE LADDER ----------------------------------------
	check(Themed.SLOTS_PER_ROOM == Config.INDOOR_ROOM_PLOTS,
		"every RoomShell's six slot anchors and the configured room size agree")
	local ceilingRooms = Config.indoorRoomCeiling()
	local counted = 0
	for room = 1, ceilingRooms do
		for slot = 1, Config.indoorPlotsInRoom(room) do
			counted += 1
			check(Themed.plotIndexOf(room, slot) == (room - 1) * Config.INDOOR_ROOM_PLOTS + slot,
				("room %d slot %d indexes into the hall's own dense order"):format(room, slot))
			check(Themed.plotIndexOf(room, slot) == counted, "and the order runs front to back with no gaps")
		end
	end
	check(counted == Config.indoorPlotCeiling(), "the slots add up to the ceiling: " .. counted)
	check(#refs.plots == counted, "which is exactly what the generic hall builds")
	check(#refs.doors == ceilingRooms - 1,
		"the generic hall has a door BETWEEN rooms and none at the far end: " .. #refs.doors)
	check(Themed.doorCount(refs.rooms) == #refs.doors,
		"and an authored interior's door count is the same number, its terminal gate excluded")
	check(Themed.doorCount(1) == 0, "a one-room hall has no door in it")

	-- ---- THE GATE SCHEDULE IS THE SAME SCHEDULE -------------------------------
	-- The generic hall opens a door when `indoorRooms(plots)` reaches its room.
	-- A kit opens a gate when the owner's REBIRTHS reach its requirement
	-- callback. Those are one statement, and this is the sweep that says so
	-- rather than the comment that claims it.
	for rebirths = 0, Config.rebirthsToMax() do
		local plots = Config.indoorPlots(rebirths)
		local rooms = Config.indoorRooms(plots)
		local told = Themed.gateRebirths(plots)
		for room = 2, ceilingRooms do
			local need = Config.indoorDoorRebirths(room)
			local kitOpen = room <= rooms and need ~= nil and told >= need
			check(kitOpen == (rooms >= room),
				("at rebirth %d the two builders agree about room %d"):format(rebirths, room))
		end
		-- THE SHARP ONE: the first room BEYOND the built prefix must need more
		-- rebirths than a kit is told it has, so a gate could not open onto
		-- unbuilt floor even if the kit forgot its own room-count guard.
		if rooms < ceilingRooms then
			local beyond = Config.indoorDoorRebirths(rooms + 1)
			check(beyond ~= nil and told < beyond,
				("at rebirth %d nothing could open room %d"):format(rebirths, rooms + 1))
		end
	end

	-- ---- THE FRAMES THE WRAPPER DERIVES ---------------------------------------
	-- The kits are authored -Z forward and the generic hall +X, so the turn IS
	-- the contract. Driven on the same stub the builder above is.
	local entry = CFrame.new(4000, 0, -2000) * CFrame.Angles(0, -math.pi / 2, 0)
	-- Every vestibule's `Door_Exit` mount stands half a stud inside its
	-- `Entry`, measured on the assembled treehouse and identical in all three
	-- kits' geometry.
	local origin = Themed.originFrame(entry, (entry * CFrame.new(0, 0, -0.5)).Position)
	local down = entry.LookVector
	check(math.abs(origin.XVector.X - down.X) < 1e-6 and math.abs(origin.XVector.Z - down.Z) < 1e-6,
		"the origin's +X runs down the hall, which is the generic hall's own convention")
	check(math.abs(origin.UpVector.Y - 1) < 1e-6, "its +Y is up")
	local handed = origin.XVector:Cross(origin.UpVector)
	check(math.abs(handed.X - origin.ZVector.X) < 1e-6 and math.abs(handed.Z - origin.ZVector.Z) < 1e-6,
		"and X x Y = Z, so it is a rotation rather than the mirror CFrame.fromMatrix takes without saying")
	check(math.abs(origin.Position.X - 4000.5) < 1e-6,
		"the threshold stands at the Door_Exit mount rather than at the outer entrance")

	-- THE ARRIVAL IS CLAMPED OFF THE EXIT GATE'S OWN REACH. Every kit's
	-- authored `Arrival` is 3.5 studs in, INSIDE the gate plane's reach --
	-- arriving there and stepping backwards walks straight out through the door
	-- you came in.
	local reach = Config.HOUSE_DOOR.exitReach
	local arrival = Themed.entranceFrame(origin, 3.5)
	local at = origin:PointToObjectSpace(arrival.Position)
	check(math.abs(at.X - (reach + 3)) < 1e-6, "an arrival inside the exit gate's reach is pushed clear of it")
	check(math.abs(at.Y) < 1e-6 and math.abs(at.Z) < 1e-6, "and stays on the floor down the middle of the hall")
	check(math.abs(origin:PointToObjectSpace(Themed.entranceFrame(origin, 12).Position).X - 12) < 1e-6,
		"an arrival the art puts FURTHER in is honoured rather than dragged back")
	check(math.abs(origin:VectorToObjectSpace(arrival.LookVector).X - 1) < 1e-6,
		"arriving faces down the hall with a CHARACTER'S convention, its front its LookVector")

	-- And it clears the gate `InteriorService.exitGate` builds -- the boot
	-- assert that file makes against a real room, reproduced here so a reach
	-- that stops clearing it fails offline rather than at somebody's front door.
	local gateFrame = origin * CFrame.new(reach, 0, 0) * CFrame.Angles(0, math.pi / 2, 0)
	check(gateFrame:PointToObjectSpace(arrival.Position).Z > 1.0,
		"the way out is not on top of the spot somebody arrives on")
	check(gateFrame:VectorToObjectSpace(origin.XVector).Z > 0.99,
		"and the exit gate's quarter turn puts the corridor on its +Z")

	-- BOTH BUILDERS ARRIVE THE SAME DISTANCE IN, which is what keeps one mask,
	-- one cooldown and one boot assert honest across two different rooms.
	check(math.abs(at.X - refs.origin:PointToObjectSpace(refs.entrance.Position).X) < 1e-6,
		"the two builders put their arrival the same distance down the hall")

	-- ---- THE HALF TURN, WHICH IS THE ONE THING THE MOUNTS GET WRONG -----------
	-- A kit slot faces the aisle with its LookVector; a plot's `ground` is a
	-- MODEL frame whose +Z is the front. Seated straight onto the mount, every
	-- piggy in the building faces the wall.
	local slot = CFrame.new(0, 0.03, -13.5) * CFrame.Angles(0, math.pi, 0)
	local lift = CFrame.new(0, 1.69, 0)
	local ground = Themed.groundFrame(slot, lift)
	check(math.abs(ground.Position.Y - 1.72) < 1e-6,
		"a piggy stands on the pedestal template's own authored mount height")
	check(math.abs(ground.Position.Z + 13.5) < 1e-6, "over the slot it belongs to")
	check(ground.ZVector.Z > 0.999, "and its +Z faces the aisle")
	check((slot * lift).ZVector.Z < -0.999,
		"which the raw mount does NOT: without the turn it would face the wall")
	check(Themed.groundFrame(CFrame.new(0, 0.03, 13.5), lift).ZVector.Z < -0.999,
		"and the same turn serves the other row")

	-- ---- THE WIRING, WHICH IS WHAT A WRAPPER NOBODY CALLS LOOKS LIKE ----------
	local service = SOURCES.InteriorService
	check(service:find("require(script.Parent.ThemedInterior)", 1, true) ~= nil,
		"InteriorService requires the second builder")
	check(service:find("builder: any,", 1, true) ~= nil, "the interior record carries which builder made it")
	check(service:find("home.builder == builder", 1, true) ~= nil,
		"and the builder is part of the cache key, so showing another house rebuilds")
	check(service:find("ThemedInterior.available(tier)", 1, true) ~= nil,
		"which interior a house has is asked of the registry rather than named in the service")
	check(service:find("math.max(HouseInterior.footprint().Z, ThemedInterior.footprint().Z)", 1, true) ~= nil,
		"the estate's pitch clears the WIDEST hall of any builder")
	check(select(2, service:gsub("HouseInterior%.setCapacity", "")) == 0,
		"nothing calls the generic builder's setCapacity by name any more")
	check(select(2, service:gsub("HouseInterior%.build%(", "")) == 1,
		"and the generic builder is built by name in exactly one place: the boot probe")
	check(service:find("builder.build(ensureFolder()", 1, true) ~= nil,
		"a player's hallway is built through whichever builder was chosen")
	check(service:find("builder.setCapacity(refs, capacity)", 1, true) ~= nil,
		"and its capacity set through the same one")
	check(service:find("for _, id in ipairs(ThemedInterior.houseIds()) do", 1, true) ~= nil,
		"the boot probe walks EVERY registered kit rather than the first")
	check(service:find("if not ok and builder ~= HouseInterior then", 1, true) ~= nil,
		"a themed kit that will not assemble falls back to the generic hall rather than to no door")

	-- ---- THE TWO COUNTERS IN THE HALL ---------------------------------------
	--
	-- They stopped being decoration on 2026-09-23. The HUD basket sells Robux
	-- and nothing else, so these two are the ONLY way to the supplies and the
	-- guardians shelves -- a counter that does not build is a shelf no player
	-- in the game can reach, and the room around it still looks perfect.
	local stand = SOURCES.BaseShopStand
	check(stand:find("for i = 1, #Config.BASE_COUNTERS do", 1, true) ~= nil,
		"there is one spot per counter rather than a hardcoded pair")
	check(stand:find("kind == \"gadgets\" or kind == \"guardians\"", 1, true) == nil,
		"which counters exist is Config's answer rather than an assert here")
	check(stand:find("label.Text = counter.sign", 1, true) ~= nil,
		"a counter's fascia is its own Config row")
	check(stand:find("prompt.ObjectText = counter.sign", 1, true) ~= nil,
		"and so is the prompt over it, so the two cannot name different shops")

	check(service:find("for i, counter in ipairs(Config.BASE_COUNTERS) do", 1, true) ~= nil,
		"the hall stands one counter per Config row")
	check(service:find("if i == 1 then", 1, true) == nil,
		"rather than naming the first two and silently repeating the second")
	check(service:find("BaseShopStand.build(counter.tab, standAt, refs.model)", 1, true) ~= nil,
		"each counter is built from its own row")
	check(service:find("FireClient(player, counter.tab)", 1, true) ~= nil,
		"and its prompt opens the shelf that row names")
	-- PCALLED PER COUNTER. A dead asset in one counter's display may cost that
	-- shelf its door; it may not cost the room, the plinths or the piggies
	-- standing on them. Same call `Decor.prewarm` makes.
	check(service:find("local ok, stand, prompt = pcall(function()", 1, true) ~= nil
			and service:find("that shelf has no door until the room is rebuilt", 1, true) ~= nil,
		"a counter that throws costs its own shelf and warns, rather than taking the hallway with it")
	-- THE PROMPT ONLY WORKS ON A ROOM THAT IS STANDING. A hall is parked in
	-- ServerStorage while nobody is in it, and a prompt held across that would
	-- open a shop from outside the building.
	check(service:find("if not refs.model:IsDescendantOf(workspace) then return end", 1, true) ~= nil,
		"a parked hallway's counters refuse")

	local wrapper = SOURCES.ThemedInterior
	check(wrapper:find("Config.indoorDoorRebirths(room)", 1, true) ~= nil,
		"a kit's gates are driven by the game's own ladder rather than a second schedule")
	check(wrapper:find("Config.indoorPlotsInRoom(roomIndex)", 1, true) ~= nil,
		"and its last room is built short off the same function the generic hall uses")
	check(select(2, wrapper:gsub("HouseInterior%.buildPortal", "")) == 1,
		"the portal in the way out is the generic hall's own function rather than a second copy")
	check(wrapper:find("for _, child in ipairs(ServerStorage:GetChildren()) do", 1, true) ~= nil,
		"a kit is resolved by NAME over every child, so a duplicate can be counted and said")
	check(wrapper:find("hall.model:Destroy()", 1, true) ~= nil
			and wrapper:find("local ok, refsOrError = pcall(finish,", 1, true) ~= nil,
		"a throw after the art is cloned takes the half-built hall with it, since a kit parents first")
	check(wrapper:find("local function finish(", 1, true) < wrapper:find("function ThemedInterior.build(", 1, true),
		"and `finish` is declared ABOVE its reader, which Luau needs and this project has paid for a dozen times")


	-- ---- NO SAME-FACING COPLANAR PAIR ----------------------------------------
	-- The file's own header has claimed zero of these since it was written and
	-- nothing checked it, so the claim went stale the moment a plot grew a
	-- drum under its face. SAME-FACING IS THE TEST -- lo==lo or hi==hi with
	-- real overlap on the other two axes -- because any honest BUTT JOINT
	-- shares a face plane with the two faces pointing AT each other, and this
	-- project's own audit had to be corrected for exactly that once already.
	--
	-- AXIS-ALIGNED ONLY, which is the same exclusion the house rebuild's sweep
	-- makes: the vault facets and the ribs are authored on an angle and are
	-- kept apart by construction (each rib's outer face sits a hair inside the
	-- vault's inner face; each facet overlaps its neighbour at the crease on
	-- purpose).
	do
		local boxes = {}
		for _, p in ipairs(parts) do
			local cf = p.CFrame
			local axisAligned = true
			for _, v in ipairs({ cf.RightVector, cf.UpVector, cf.ZVector }) do
				for _, c in ipairs({ v.X, v.Y, v.Z }) do
					local a = math.abs(c)
					if a > 1e-6 and math.abs(a - 1) > 1e-6 then axisAligned = false end
				end
			end
			if axisAligned then
				local h = {
					math.abs(cf.RightVector.X) * p.Size.X / 2 + math.abs(cf.UpVector.X) * p.Size.Y / 2
						+ math.abs(cf.ZVector.X) * p.Size.Z / 2,
					math.abs(cf.RightVector.Y) * p.Size.X / 2 + math.abs(cf.UpVector.Y) * p.Size.Y / 2
						+ math.abs(cf.ZVector.Y) * p.Size.Z / 2,
					math.abs(cf.RightVector.Z) * p.Size.X / 2 + math.abs(cf.UpVector.Z) * p.Size.Y / 2
						+ math.abs(cf.ZVector.Z) * p.Size.Z / 2,
				}
				local c = { cf.Position.X, cf.Position.Y, cf.Position.Z }
				table.insert(boxes, { name = p.Name,
					lo = { c[1] - h[1], c[2] - h[2], c[3] - h[3] },
					hi = { c[1] + h[1], c[2] + h[2], c[3] + h[3] } })
			end
		end
		local found, worst = 0, ""
		for i = 1, #boxes do
			for j = i + 1, #boxes do
				local a, b = boxes[i], boxes[j]
				for ax = 1, 3 do
					local shares = math.abs(a.lo[ax] - b.lo[ax]) < 0.02
						or math.abs(a.hi[ax] - b.hi[ax]) < 0.02
					if shares then
						local over = true
						for other = 1, 3 do
							if other ~= ax then
								local lap = math.min(a.hi[other], b.hi[other])
									- math.max(a.lo[other], b.lo[other])
								if lap <= 0.02 then over = false end
							end
						end
						if over then
							found += 1
							worst = a.name .. " / " .. b.name .. " on axis " .. ax
						end
					end
				end
			end
		end
		check(found == 0, ("%d same-facing coplanar pairs across %d axis-aligned parts (worst %s)")
			:format(found, #boxes, worst))
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

	-- ==========================================================
	-- INDOOR PLACEMENTS: THE SLOT LADDER, THE TWO FRAMES, THE SAVE
	-- ==========================================================
	--
	-- A pedestal, a collect pad and a cash sign stand on every UNLOCKED indoor
	-- plot, and they are the lawn's own placement on different geometry -- one
	-- array of slots in the save, one `EconomyService.collectPiggy`, one set of
	-- state functions. What is testable with no engine is the arithmetic all of
	-- that rests on: which slot a plot is, where the pad and the sign stand in
	-- each builder, and whether a save can hold an indoor piggy at all.

	-- ---- THE LAWN'S NUMBERING, CONTINUED --------------------------------------
	local base = HouseInterior.slotBase()
	local total = HouseInterior.slotCount()
	check(base == Config.PIGGY_LAWN_SLOT_COUNT,
		"the hall starts where the lawn stops: " .. base)
	check(total == base + Config.indoorPlotCeiling(),
		("the collection is the lawn plus the hallway's ceiling: %d against %d + %d")
			:format(total, base, Config.indoorPlotCeiling()))
	check(HouseInterior.slotOfPlot(1) == base + 1,
		"the first indoor plot is the slot after the last lawn one")
	check(HouseInterior.slotOfPlot(Config.indoorPlotCeiling()) == total,
		"and the last one is the last slot in the collection")
	-- THE INVERSE REFUSES EVERYTHING THAT IS NOT AN INDOOR SLOT, which is what
	-- stops a bank collect or a lawn press being read as a hallway press.
	check(HouseInterior.plotOfSlot(0) == nil, "slot 0 is the bank and not a plot")
	check(HouseInterior.plotOfSlot(base) == nil, "the last lawn slot is not a plot")
	check(HouseInterior.plotOfSlot(total + 1) == nil, "nor is a slot past the ceiling")
	check(HouseInterior.plotOfSlot(nil) == nil and HouseInterior.plotOfSlot(-3) == nil,
		"and nonsense reads as no plot rather than throwing")
	for plot = 1, Config.indoorPlotCeiling() do
		check(HouseInterior.plotOfSlot(HouseInterior.slotOfPlot(plot)) == plot,
			"plot " .. plot .. " round-trips through its own slot")
	end

	-- ---- THE PAD AND THE READOUT MOUNT IN THE GENERIC HALL --------------------
	-- Measured off the hall that was actually built, against the platform parts
	-- it stands on -- never against the constants, which is the whole of this
	-- project's rule about measuring a thing rather than a model of it.
	--
	-- THE MOUNT IS A FRAME NOBODY STANDS ON NOW. The cash figure moved onto
	-- the collect button (designer, 2026-09-23: the plaque that used to hang
	-- here covered the coin emblem on the pedestal), so what is still worth
	-- asserting is that the room publishes the mount WHERE THE ART PUT IT --
	-- lane-facing, at reading height, square with the plot -- and not that a
	-- sign clears a stump, which is arithmetic about a part that is gone.
	local PAD = HouseInterior.INDOOR_PAD
	check(PAD.Z > 0 and PAD.X > 0,
		"the pad has a size for both builders to read")
	check(HouseInterior.INDOOR_SIGN == nil
			and HouseInterior.INDOOR_SIGN_STANDOFF == nil,
		"and the sign that used to stand in front of a pedestal is gone outright")

	local platforms = {}
	for _, p in ipairs(parts) do
		if p.Name == "Collide_Platform" then table.insert(platforms, p) end
	end
	check(#platforms > 0, "the hall has platforms for a plot to stand on")

	HouseInterior.setCapacity(refs, Config.indoorPlotCeiling())
	local padChecks = 0
	for _, plot in ipairs(refs.plots) do
		local g, c, s = plot.ground, plot.collect, plot.cash
		check(c ~= nil and s ~= nil, "plot " .. plot.index .. " publishes a collect and a cash frame")
		-- ONE TURN FOR THE PIGGY, ITS BUTTON AND ITS SIGN. A display at one
		-- angle over a pad at another is the reported bug the lawn already
		-- paid for, so all three come off the plot's own quarter turn.
		check(math.abs(c.ZVector.Z - g.ZVector.Z) < 1e-6
				and math.abs(s.ZVector.Z - g.ZVector.Z) < 1e-6,
			"plot " .. plot.index .. "'s pad and mount face the way the piggy does")
		-- +Z IS THE LANE, which for a plot on the +Z platform is -Z in world.
		check(g.Position.Z * c.ZVector.Z < 0,
			"plot " .. plot.index .. " faces the lane rather than the wall")
		-- IN FRONT OF THE PLOT AND ON THE SAME SIDE OF THE LANE.
		check(g.Position.Z * c.Position.Z > 0 and math.abs(c.Position.Z) < math.abs(g.Position.Z),
			"plot " .. plot.index .. "'s pad is between it and the lane")
		check(math.abs(c.Position.X - g.Position.X) < 1e-6,
			"and square in front of it rather than beside it")
		-- THE PAD CLEARS THE PLOT IT SERVES, measured against the surround's
		-- own footprint: two flat things sharing a plane is the coplanar
		-- flicker this project has recorded three times.
		local surroundEdge = math.abs(plot.surround.CFrame.Position.Z) - plot.surround.Size.Z / 2
		local padOuter = math.abs(c.Position.Z) + PAD.Z / 2
		check(padOuter <= surroundEdge + 1e-6,
			("plot %d's pad stops short of its own surround (%0.3f against %0.3f)")
				:format(plot.index, padOuter, surroundEdge))
		-- AND IT STANDS ON THE PLATFORM RATHER THAN IN THE AIR OR IN THE LANE.
		local stood = nil
		for _, p in ipairs(platforms) do
			local dz = math.abs(p.CFrame.Position.Z - c.Position.Z)
			local dx = math.abs(p.CFrame.Position.X - c.Position.X)
			if dz <= p.Size.Z / 2 and dx <= p.Size.X / 2 then stood = p end
		end
		check(stood ~= nil, "plot " .. plot.index .. "'s pad centre is over a platform")
		if stood then
			local top = stood.CFrame.Position.Y + stood.Size.Y / 2
			check(math.abs(c.Position.Y - top) < 1e-6,
				("plot %d's pad sits on the platform top (%0.3f against %0.3f)")
					:format(plot.index, c.Position.Y, top))
			local inner = math.abs(stood.CFrame.Position.Z) - stood.Size.Z / 2
			check(math.abs(c.Position.Z) - PAD.Z / 2 >= inner - 1e-6,
				("plot %d's pad stays on the platform rather than over the lane edge"):format(plot.index))
		end
		-- THE MOUNT IS ON THE PEDESTAL AT READING HEIGHT, under the piggy's own
		-- feet and above the platform it stands on.
		check(s.Position.Y < g.Position.Y and s.Position.Y > c.Position.Y,
			"plot " .. plot.index .. "'s readout mount is between the pad and the piggy")
		-- AND IT IS ON THE DRUM RATHER THAN OUT OVER THE PAD: a surface on the
		-- object, which is what makes it a mount rather than a position.
		check(math.abs(s.Position.Z) > math.abs(c.Position.Z),
			"plot " .. plot.index .. "'s mount is on the pedestal, behind its own button")
		padChecks += 1
	end
	check(padChecks == #refs.plots, "every plot in the hall was measured: " .. padChecks)

	-- ---- AND IN AN AUTHORED KIT, OFF THE REAL MOUNTS --------------------------
	-- The numbers below were read off the three kits in `ServerStorage` on
	-- 2026-09-23 rather than taken from a comment: every one of them has its
	-- six `Slot_0N` at |x| 13.50 facing the aisle with its LookVector, a
	-- `Pedestal` reaching 3.82 (3.57 on the Beehive Cottage) toward the lane,
	-- and a 38-stud clear room whose 16-stud lane boundary is therefore |x| 8.
	do
		local lane = 8.0
		local cases = {
			{ name = "treehouse", reach = 3.82, cash = 2.98, radius = 3.05 },
			{ name = "cardboard fort", reach = 3.82, cash = 3.04, radius = 3.00 },
			{ name = "beehive cottage", reach = 3.57, cash = 2.65, radius = 3.05 },
		}
		for _, side in ipairs({ -1, 1 }) do
			-- A slot on the -x wall faces +x and one on the +x wall faces -x,
			-- which is a half turn between the two rows and is exactly what
			-- `groundFrame` has always had to undo.
			local yaw = if side < 0 then -math.pi / 2 else math.pi / 2
			for _, case in ipairs(cases) do
				local at = CFrame.new(side * 13.5, 0.03, -16) * CFrame.Angles(0, yaw, 0)
				local out = case.reach + PAD.Z / 2
				local collect = Themed.collectFrame(at, out)
				-- The `CashLabel` mount is authored at (0, height, -depth) off
				-- the Root, with its depth measured toward the lane -- which is
				-- the template's own -Z. The kits' two numbers differ by a few
				-- studs and by nothing else.
				local cash = Themed.cashFrame(at, CFrame.new(0, case.cash, -case.cash))
				-- +Z TOWARD THE LANE ON BOTH ROWS.
				check(collect.ZVector.X * side < -0.999,
					case.name .. ": the pad faces the lane on the " .. tostring(side) .. " wall")
				check(cash.ZVector.X * side < -0.999,
					case.name .. ": and so does the readout mount")
				-- THE PAD ABUTS THE PEDESTAL'S OWN FOOTPRINT AND REACHES INTO
				-- THE LANE RATHER THAN THROUGH THE STUMP, which is the rule
				-- `INDOOR_PAD` states for both builders.
				local padOuter = math.abs(collect.Position.X) + PAD.Z / 2
				check(math.abs(padOuter - (13.5 - case.reach)) < 1e-6,
					("%s: the pad's outer edge is the pedestal's own footprint (%0.3f)")
						:format(case.name, padOuter))
				-- AND IT REACHES ONTO THE LANE RATHER THAN STOPPING AT IT,
				-- which is a change of intent rather than a drift: `INDOOR_PAD`
				-- went 2.0 deep to 3.6 on 2026-09-23 (the lawn's own button),
				-- and `HouseInterior.INDOOR_PAD`'s own note states what that
				-- buys here -- "a kit's plot stands on FLAT floor with its
				-- lane beyond it, so the pad simply reaches further onto
				-- ground a player already walks on -- 1.92 studs in against
				-- 0.32 before". Only the generic hall had an edge to fall off.
				--
				-- SO WHAT IS ASSERTED IS THAT IT STRADDLES THE LINE: the near
				-- edge is over the lane and the far edge is still on the
				-- pedestal's own ground. Written against the pad's own depth
				-- rather than against 1.92, so the next resize moves the
				-- measurement rather than breaking the rule.
				local padInner = math.abs(collect.Position.X) - PAD.Z / 2
				check(padInner < lane,
					("%s: its inner edge reaches over the lane (%0.3f, %0.3f in)")
						:format(case.name, padInner, lane - padInner))
				check(padOuter > lane,
					("%s: and its outer edge is still on the plot's own floor (%0.3f)")
						:format(case.name, padOuter))
				check(math.abs(collect.Position.Y - 0.03) < 1e-6,
					case.name .. ": the pad is on the kit's own floor")
				-- THE MOUNT IS ON THE STUMP'S OWN SURFACE TO WITHIN HALF A
				-- STUD, AND NOT EXACTLY ON IT -- which is the measurement that
				-- used to decide a sign's standoff and is kept because it is a
				-- fact about the ART rather than about any part. Measured:
				-- the treehouse's `CashLabel` stands 0.07 proud of its own
				-- radius, the cardboard fort's 0.04, and the Beehive Cottage
				-- authors its 0.40 INSIDE. So anything ever hung here again
				-- has to stand off the frame rather than be seated on it, or
				-- it is buried on one kit of the three.
				local surface = 13.5 - case.radius
				local off = math.abs(cash.Position.X) - surface
				check(math.abs(off) < 0.5,
					("%s: the mount is on the stump's own surface (%0.3f off %0.3f)")
						:format(case.name, off, surface))
				check(math.abs(cash.Position.X) > lane,
					case.name .. ": and stays out of the lane")
				check(math.abs(cash.Position.Y - (0.03 + case.cash)) < 1e-6,
					case.name .. ": at the mount's own height")
			end
		end
	end

	-- ---- CAN A SAVE HOLD ONE? THE BOOT AUDIT, DRIVEN BOTH WAYS ---------------
	-- `HouseInterior.auditCollection` is the loud half of this feature: it
	-- fired for as long as the save layer and the economy stopped at the lawn,
	-- and the three Config bounds were widened on 2026-09-23
	-- (`Config.PIGGY_SLOT_COUNT`, `piggySlots`, `placePiggy`,
	-- `collectionRateOf`). So it has to be SILENT on the shipped Config, and
	-- the probe is proved to be the real thing by NARROWING the three back to
	-- the lawn on the loaded table -- which is exactly the regression a stray
	-- edit to any of them would be -- and watching it fire and name each site.
	do
		local shipped = HouseInterior.auditCollection()
		check(#shipped == 0,
			("the audit is silent on the shipped Config: the save layer reads the whole collection (%d: %s)")
				:format(#shipped, table.concat(shipped, " | ")))
		check(Config.PIGGY_SLOT_COUNT == Config.PIGGY_LAWN_SLOT_COUNT + Config.indoorPlotCeiling(),
			"and `PIGGY_SLOT_COUNT` is the lawn plus the hallway's ceiling, derived rather than typed")
		check(HouseInterior.slotCount() == Config.PIGGY_SLOT_COUNT,
			"which is the number `slotCount` reads rather than its fallback derivation")

		local slots, place, rate = Config.piggySlots, Config.placePiggy, Config.collectionRateOf
		local lawn = Config.PIGGY_LAWN_SLOT_COUNT
		Config.piggySlots = function(data)
			local piggies = data.piggies
			if not piggies then
				piggies = { owned = {}, till = Config.DEFAULT_SKIN }
				data.piggies = piggies
			end
			local held = piggies.slots
			if type(held) ~= "table" then
				held = {}
				piggies.slots = held
			end
			for i = 1, lawn do
				if type(held[i]) ~= "table" then held[i] = {} end
			end
			for i = #held, lawn + 1, -1 do held[i] = nil end
			return held
		end
		Config.placePiggy = function(data, key, slot)
			if slot < 1 or slot > lawn then return false end
			local held = Config.piggySlots(data)
			local entry = held[slot]
			if not entry or entry.key ~= nil then return false end
			local piggies = data.piggies
			piggies.owned = piggies.owned or {}
			piggies.owned[key] = (piggies.owned[key] or 0) + 1
			entry.key = key
			entry.buffer = 0
			return true
		end
		Config.collectionRateOf = function(data, friendBonus)
			local placed = {}
			for slot = 0, lawn do
				if Config.piggyKeyAt(data, slot) ~= nil then
					table.insert(placed, Config.piggyRarityAt(data, slot) or "common")
				end
			end
			return Config.collectionRate(placed, data.incomeLevel, data.rebirths, friendBonus)
		end
		local firing = HouseInterior.auditCollection()
		Config.piggySlots, Config.placePiggy, Config.collectionRateOf = slots, place, rate
		local saw = {}
		for _, p in ipairs(firing) do
			saw[p:match("%[([%w%.]+)%]") or "?"] = true
		end
		check(#firing > 0, "narrowed back to the lawn, the audit fires")
		check(saw["indoor.save"], "and names `Config.piggySlots` trimming the array")
		check(saw["indoor.place"], "and `Config.placePiggy` refusing an indoor slot")
		check(saw["indoor.economy"], "and the economy bounds it cannot reach from there")
		check(#HouseInterior.auditCollection() == 0,
			"and is silent again once the shipped functions are back, so the probe is the real thing")
	end

	-- ---- THE WIRING, WHICH IS WHAT A PEDESTAL NOBODY CALLS LOOKS LIKE --------
	local indoor = SOURCES.IndoorPedestal
	check(indoor:find("PiggyPedestal.buildPadSound(pad)", 1, true) ~= nil,
		"an indoor pad makes the lawn's own noise rather than a second cue")
	check(indoor:find("PiggyPedestal.buildPadFigure(padFace)", 1, true) ~= nil,
		"and its figure is the lawn's own, painted on its own button")
	-- THE PLACARD IS GONE AND IT MAY NOT COME BACK BY ACCIDENT. It stood in
	-- front of the pedestal and covered the coin emblem on it (designer,
	-- 2026-09-23), and what would put it back is one more Part seated on
	-- `plot.cash` -- a frame the room still publishes, on purpose. COUNTED
	-- RATHER THAN GREPPED FOR A NAME: this file is allowed to TALK about that
	-- mount, and does, so the honest assertion is how many parts it stands.
	check(indoor:find("CashSign", 1, true) == nil,
		"nothing stands a sign in front of a pedestal any more")
	check(select(2, indoor:gsub('Instance%.new%("Part"%)', "")) == 2,
		"and a placement is two parts: the pad's own courses and the prompt stand")
	check(indoor:find("local padSpec = Config.PIGGY_PEDESTAL.pad", 1, true) ~= nil
			and indoor:find("local RIM", 1, true) == nil,
		"the pad's rim and relief are the lawn's own rather than a second set")
	check(indoor:find("PiggyPedestal.buildPrompts(stand)", 1, true) ~= nil,
		"and its four prompts are the lawn's own four")
	check(indoor:find("pad.CanTouch = true", 1, true) ~= nil,
		"the pad is a button you walk over, which is what `Touched` needs")
	check(select(2, indoor:gsub("CanTouch = false", "")) >= 2,
		"and it is the ONLY part here that is touchable, so one crossing is one collect")
	check(indoor:find("plinth = stand", 1, true) ~= nil,
		"the prompts hang on a part inside the placement, so one Destroy takes them")
	check(indoor:find("seat = plot.ground", 1, true) ~= nil,
		"and the display stands on the plot's own frame")

	check(service:find("require(script.Parent.EconomyService)", 1, true) ~= nil
			and service:find("require(script.Parent.PiggyHaulService)", 1, true) ~= nil,
		"InteriorService asks for the collect and the haul rather than reimplementing them")
	check(service:find("EconomyService.collectPiggy(player, which, true)", 1, true) ~= nil,
		"an indoor pad banks through the SAME server path the lawn's six pads use")
	check(service:find("PiggyHaulService.take(who, plot, slot)", 1, true) ~= nil
			and service:find("PiggyHaulService.place(who, plot, slot)", 1, true) ~= nil,
		"and its plinth takes and places through the same two functions")
	check(service:find("HouseInterior.slotOfPlot(plot.index)", 1, true) ~= nil,
		"a plot's save slot is the shared mapping rather than an offset written here")
	check(service:find("IndoorPedestal.build", 1, true) ~= nil,
		"the placement itself is the shared builder")
	check(service:find("syncPlacements(home)", 1, true) ~= nil
			and select(2, service:gsub("syncPlacements%(home%)", "")) == 2,
		"placements are synced on BOTH paths -- a fresh hall and a cached one whose capacity grew")
	check(service:find("local function syncPlacements", 1, true) < service:find("local function ensureHome", 1, true),
		"and it is declared above its reader, which Luau needs")
	check(service:find("if plot.unlocked then", 1, true) ~= nil,
		"driven off the plot's own unlocked flag rather than a second rebirth test")
	check(select(2, service:gsub("PlotService%.setIndoorPedestals%(home%.plot, nil%)", "")) == 2,
		"the plot lets go of the placements in BOTH teardowns: a destroy and an evict")
	check(service:find("home.kit == kit", 1, true) ~= nil,
		"the KIT is part of the hallway cache key, not just the builder table")
	check(service:find("kit = ThemedInterior.kitName(tier)", 1, true) ~= nil,
		"and it is the registry's own answer rather than a second lookup")
	check(service:find("HouseInterior.auditCollection()", 1, true) ~= nil,
		"and the save-layer gap is said out loud at boot rather than discovered by a player")

	local plotService = SOURCES.PlotService
	check(plotService:find("function PlotService.pedestalAt", 1, true) ~= nil,
		"there is ONE question for `the placement at this slot`")
	check(plotService:find("return if indoor then indoor[index] else nil", 1, true) ~= nil,
		"and it answers for the hall as well as the lawn")
	check(plotService:find("local pedestal = PlotService.pedestalAt(plot, slot)", 1, true) ~= nil,
		"a collect's sound and its pad stamp go through it, so an indoor collect lights its own button")
	check(select(2, plotService:gsub("for slot, pedestal in pairs%(indoor%) do", "")) == 2,
		"both repaint loops walk the hall's placements, and with `pairs` because the map is sparse")
	check(plotService:find("PlotService.setIndoorPedestals(plot, nil)", 1, true) ~= nil,
		"and a released plot drops them before the repaint that follows")

	local haul = SOURCES.PiggyHaulService
	check(haul:find("local pedestal = PlotService.pedestalAt(plot, slot)", 1, true) ~= nil,
		"take, place and snatch reach through the one question rather than the lawn array")
	check(select(2, haul:gsub("plot%.pedestals and plot%.pedestals%[slot%]", "")) == 0,
		"and nothing in the haul reads the lawn array by hand any more")
end

print(("interior: %d checks passed (%d sightlines)"):format(checks, sightChecks))
