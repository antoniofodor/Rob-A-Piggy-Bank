-- THE STREET LEADERBOARD, which is Roblox's own player list now: the save
-- field, the one place it is incremented, and the service that fills a
-- `leaderstats` folder from it. There is no panel left to test -- the
-- platform draws the columns -- so what this suite holds instead is the
-- CONTRACT WITH THAT COMPONENT: the folder's name, the column order (which
-- is the sort), the classes, and that a value is written only when it has
-- moved. The real Config and the real service against a datamodel small
-- enough to read; nothing here touches a live save or a screen.
local Config, sources = ...
local checks = 0
local function check(ok, msg) assert(ok, msg); checks += 1 end
local function copy(value)
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in value do out[k] = copy(v) end
	return out
end
local names = setmetatable({}, { __index = function(_, k) return k end })

-- ------------------------------------------------------------
-- 1. THE SAVE FIELD: a zero on every save, normalised, idempotent
-- ------------------------------------------------------------
do
	local transformed, n = sources.DataService:gsub("return DataService%s*$", [[
DataService.defaults=defaultData
DataService.reconcile=reconcile
return DataService
]])
	assert(n == 1)
	local env = setmetatable({
		game = { JobId = "board-tests", GetService = function(_, name)
			if name == "ReplicatedStorage" then return { Shared = { Config = "Config" } } end
			if name == "DataStoreService" then return { GetDataStore = function() return nil end } end
			return {}
		end },
		require = function(key) assert(key == "Config"); return Config end,
		task = { wait = function() end }, warn = function() end,
	}, { __index = getfenv() })
	local run = assert(loadstring(transformed, "DataService")); setfenv(run, env)
	local D = run()
	check(D.defaults().piggiesStolen == 0, "a new save starts with no piggies robbed")
	local old = D.defaults(); old.piggiesStolen = nil; old.schema = 25
	local loaded = D.reconcile(old)
	check(loaded.piggiesStolen == 0, "a save written before the counter existed gains a zero")
	check(D.reconcile(copy(loaded)).piggiesStolen == 0, "and gains it once: the fill is idempotent")
	local kept = D.defaults(); kept.piggiesStolen = 17
	check(D.reconcile(kept).piggiesStolen == 17, "a real count survives reconcile")
	for _, case in { { 4.9, 4 }, { -3, 0 }, { "7", 0 }, { {}, 0 }, { 0 / 0, 0 }, { math.huge, 0 } } do
		local saved = D.defaults(); saved.piggiesStolen = case[1]
		local out = D.reconcile(saved)
		check(out.piggiesStolen == case[2], "the counter reconciles to a finite non-negative integer")
		check(D.reconcile(copy(out)).piggiesStolen == case[2], "and is stable on rejoin")
	end
	check(sources.DataService:find("piggiesStolen = 0", 1, true) ~= nil,
		"the default is a field add, filled by the generic pass -- no schema branch")
end

-- ------------------------------------------------------------
-- 2. THE INCREMENT: at the secure, never at the grab, never on your own
-- ------------------------------------------------------------
do
	local src = sources.PiggyHaulService
	local function inst(class)
		local o = { ClassName = class, Name = class, attributes = {} }
		function o:SetAttribute(k, v) self.attributes[k] = v end
		function o:GetAttribute(k) return self.attributes[k] end
		function o:Destroy() self.Parent = nil; self.destroyed = true end
		o.Triggered = { Connect = function() return {} end }
		return o
	end
	local vm = {}
	local function vec(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, vm) end
	vm.__sub = function(a, b)
		return { Magnitude = math.sqrt((a.X - b.X) ^ 2 + (a.Y - b.Y) ^ 2 + (a.Z - b.Z) ^ 2) }
	end
	local frame = setmetatable({}, { __mul = function(a) return a end })
	local home = {}   -- player -> the plot roomFor should find them on
	local steals = 0
	local modules = {
		Config = Config,
		Remotes = { get = function(name)
			return { FireClient = function(_, p, msg, kind)
				p.notes = p.notes or {}
				table.insert(p.notes, { name = name, msg = msg, kind = kind })
			end }
		end },
		PiggyModel = {
			build = function(key)
				local body = inst("Part"); body.Position = vec(0, 0, 0)
				local m = inst("Model"); m.PrimaryPart = body; m.key = key
				function m:PivotTo() end
				return m
			end,
			bodyOf = function(m) return m.PrimaryPart end,
		},
		CarryPose = { HOLD = frame, anchor = function() return nil, frame end },
		Theme = { FONT = "F", PAPER = "p", INK = "i", GOLD = "g" },
		DataService = { get = function(p) return p.data end, save = function() end },
		PlotService = {
			setSwapOffer = function() end,
			setPlaceOffer = function() end,
			getAll = function() return {} end,
			getPlot = function(p) return home[p] end,
			yardContaining = function() return nil end,
			setPiggySlots = function() end, setPiggyBuffers = function() end,
			-- THE ONE QUESTION `reach` ASKS: the placement at a slot, wherever
			-- it stands. A save's collection is one array -- the lawn at
			-- slots 1..N and the hall behind the front door at the slots
			-- after it -- and this is the real function's own shape, lawn
			-- array first and then the sparse indoor map, so a press on an
			-- indoor plinth is exercised here rather than only live.
			pedestalAt = function(plot, slot)
				local lawn = plot.pedestals and plot.pedestals[slot]
				if lawn then return lawn end
				return plot.indoor and plot.indoor[slot] or nil
			end,
			setIndoorPedestals = function(plot, map) plot.indoor = map end,
		},
		ResidentService = { get = function(plot) return plot.resident end },
		CosmeticsService = { applyToPlot = function() end },
		EconomyService = { push = function() end },
		HeistService = {
			isCarrying = function() return false end, haulChanged = function() end,
			whyCannotSnatch = function() return nil end,
			dropShield = function() end, isDodgeImmune = function() return false end,
		},
		SocialService = { recordSteal = function() steals += 1 end },
	}
	-- The room test: a player is "home" when the plot they are standing in is
	-- their own. The double answers with whatever `home` says for them.
	local standing = nil
	modules.PlotService.yardContaining = function() return standing end
	local env = setmetatable({
		game = { GetService = function(_, name)
			return if name == "ReplicatedStorage" then { Shared = names } else {}
		end },
		require = function(n) return assert(modules[n], tostring(n)) end,
		script = { Parent = names },
		Instance = { new = inst },
		UDim2 = { new = function() return {} end, fromScale = function() return {} end },
		Vector3 = { new = vec },
		os = { clock = function() return 100 end },
		warn = function() end,
	}, { __index = getfenv() })
	local tail = [[
PiggyHaulService.testSecureStep = secureStep
PiggyHaulService.testHauling = hauling
return PiggyHaulService
]]
	local code, n = src:gsub("return PiggyHaulService%s*$", tail); assert(n == 1)
	local run = assert(loadstring(code, "PiggyHaulService")); setfenv(run, env)
	local H = run()

	local D = Config.DEFAULT_SKIN
	local X = "bronze"
	local N = Config.PIGGY_LAWN_SLOT_COUNT
	local serial = 0
	local function actor()
		serial += 1
		local root = { Position = vec(0, 0, 0), CFrame = frame }
		local humanoid = { Health = 100 }
		local char = { attributes = {} }
		function char:SetAttribute(k, v) self.attributes[k] = v end
		function char:GetAttribute(k) return self.attributes[k] end
		function char:FindFirstChild(nm) return if nm == "HumanoidRootPart" then root else nil end
		function char:FindFirstChildOfClass() return humanoid end
		local p = { UserId = serial, DisplayName = "P" .. serial, Parent = true, Character = char }
		p.data = { incomeLevel = 0, rebirths = 0, piggiesStolen = 0,
			cosmetics = { owned = {}, skin = D },
			piggies = { owned = { [D] = 1, [X] = 1 }, till = D,
				slots = { { key = X }, {}, {}, {}, {}, {} } } }
		return p
	end
	local function plotFor(p, resident)
		local plot = { owner = p, index = serial, pedestals = {}, resident = resident,
			piggy = { body = { Position = vec(0, 0, 0) }, swapPrompt = inst("ProximityPrompt") } }
		for i = 1, N do plot.pedestals[i] = { plinth = { Position = vec(0, 0, 0) } } end
		return plot
	end

	-- A THIEF SECURES A NEIGHBOUR'S PIGGY: the counter moves at the landing
	-- and at nothing before it.
	local t = actor()
	local plotT = plotFor(t)
	home[t] = plotT
	local resident = { piggies = { owned = { [X] = 1 }, till = D, slots = { { key = X }, {}, {}, {}, {}, {} } } }
	local plotR = plotFor(nil, resident)
	-- The thief has an empty plinth to land on: clear their own slot 1.
	t.data.piggies.slots[1] = {}; t.data.piggies.owned[X] = nil
	H.snatch(t, plotR, 1)
	local haul = H.testHauling[t]
	check(haul ~= nil and haul.own == false, "the neighbour's piggy is in the thief's arms as a stolen haul")
	check(t.data.piggiesStolen == 0, "the grab counts nothing")
	standing = plotT
	H.testSecureStep(t, haul, 100)
	check(haul.secureFrom == 100 and t.data.piggiesStolen == 0, "the dwell starting counts nothing")
	H.testSecureStep(t, haul, 100 + Config.PIGGY_HAUL.secureSeconds - 0.5)
	check(H.isHauling(t) and t.data.piggiesStolen == 0, "half a second short, still nothing")
	H.testSecureStep(t, haul, 100 + Config.PIGGY_HAUL.secureSeconds)
	check(not H.isHauling(t) and t.data.piggies.slots[1].key == X, "the piggy landed on the thief's own plinth")
	check(t.data.piggiesStolen == 1, "and that is the one moment the lifetime count moves")
	check(steals == 1, "beside the rap sheet, which counts the same moment")

	-- YOUR OWN PIGGY, TAKEN AND PLACED, IS NOT A ROBBERY.
	local o = actor()
	local plotO = plotFor(o)
	home[o] = plotO
	H.take(o, plotO, 1)
	check(H.isHauling(o) and H.testHauling[o].own == true, "an owner carrying their own piggy")
	standing = plotO
	H.testSecureStep(o, H.testHauling[o], 100)
	H.testSecureStep(o, H.testHauling[o], 100 + Config.PIGGY_HAUL.secureSeconds)
	check(H.isHauling(o), "the dwell ignores an own haul")
	H.place(o, plotO, 2)
	check(not H.isHauling(o) and o.data.piggies.slots[2].key == X, "placed on their own lawn")
	check(o.data.piggiesStolen == 0, "and it is not counted as a robbery")

	-- A NABBED HAUL NEVER COUNTS: the second thief is caught before the dwell.
	local u = actor()
	local plotU = plotFor(u)
	home[u] = plotU
	u.data.piggies.slots[1] = {}; u.data.piggies.owned[X] = nil
	resident.piggies.slots[1] = { key = X }; resident.piggies.owned[X] = 1
	H.snatch(u, plotR, 1)
	check(H.isHauling(u), "the second thief took it")
	local nabber = actor()
	H.nab(nabber, u)
	check(not H.isHauling(u) and u.data.piggiesStolen == 0, "caught on the way home: nothing counted")

	-- THE SOURCE SAYS THE SAME: one increment, inside the secure, and the
	-- resident core never touches a save's counter.
	-- Counted by LINE: the one increment reads the field on both sides of
	-- its own `=`, so a string count would report two places for one.
	local first, lines = nil, 0
	local NLC = string.char(10)
	for at in src:gmatch("()[^" .. NLC .. "]*piggiesStolen[^" .. NLC .. "]*") do
		lines += 1
		first = first or at
	end
	check(lines == 1, "PiggyHaulService increments the counter in exactly one place")
	local secureAt = src:find("local function secureStep", 1, true)
	local losingAt = src:find("function PiggyHaulService.nab(", 1, true) -- the LOSING IT section opens with it
	check(secureAt and losingAt and first > secureAt and first < losingAt,
		"and that place is inside secureStep, the landing")
	local residentAt = src:find("function PiggyHaulService.residentSnatch", 1, true)
	local residentEnd = src:find("function PiggyHaulService.residentReturn", 1, true)
	check(residentAt and residentEnd and not (first > residentAt and first < residentEnd),
		"a neighbour's snatch counts nothing: it is a player counter")
end
-- ------------------------------------------------------------
-- 3. THE SERVICE: a `leaderstats` folder per player, in column order,
--    written only when a figure has moved
-- ------------------------------------------------------------
do
	-- A DATAMODEL SMALL ENOUGH TO READ. `Parent` registers a child and every
	-- `Value` write is counted, which is what makes "only on change" a
	-- measurement rather than a claim about the source text.
	local writes = 0
	local function instance(class)
		local o = { ClassName = class, Name = class, Kids = {} }
		function o.IsA(_, want) return want == class end
		function o.GetChildren() return o.Kids end
		function o.FindFirstChild(_, name)
			for _, c in o.Kids do if c.Name == name then return c end end
			return nil
		end
		-- ONE MECHANISM FOR PARENTING, NOT TWO: `__newindex` stores and
		-- registers, and nothing else touches Parent -- a helper that also
		-- assigned it would re-enter this and blow the C stack.
		--
		-- AND `Value` IS HELD OFF THE TABLE RATHER THAN RAWSET ONTO IT, which
		-- is the half the first version of this stub got wrong and is worth
		-- the comment: `__newindex` fires only while a key is ABSENT, so a
		-- counter that rawsets `Value` counts the first write to a column and
		-- silently ignores every one after it. Every "writes nothing" check
		-- below then passed for the wrong reason -- a harness agreeing with
		-- itself, which is the failure this project records as the worst
		-- shape a test can have. Kept out of the table, so every write is
		-- seen.
		return setmetatable(o, {
			__index = function(t, k)
				if k == "Value" then return rawget(t, "_value") end
				return nil
			end,
			__newindex = function(t, k, v)
				if k == "Parent" and v ~= nil and rawget(v, "Kids") then
					table.insert(v.Kids, t)
				end
				if k == "Value" then
					writes += 1
					rawset(t, "_value", v)
					return
				end
				rawset(t, k, v)
			end,
		})
	end

	local saves = {}
	local players = {}
	local modules = {
		Config = Config,
		DataService = { get = function(p) return saves[p] end },
	}
	local env = setmetatable({
		game = { GetService = function(_, name)
			if name == "ReplicatedStorage" then return { Shared = names } end
			if name == "Players" then
				return { GetPlayers = function() return players end,
					PlayerAdded = { Connect = function() end } }
			end
			return {}
		end },
		require = function(n) return assert(modules[n], tostring(n)) end,
		script = { Parent = names },
		Instance = { new = instance },
		task = { spawn = function() end, wait = function() end },
	}, { __index = getfenv() })
	local run = assert(loadstring(sources.LobbyBoardService, "LobbyBoardService")); setfenv(run, env)
	local Service = run()

	local function player(name, data)
		local p = instance("Player")
		p.Name = name
		p.DisplayName = name
		saves[p] = data
		return p
	end

	-- ---- the contract with the component
	check(Service.FOLDER == "leaderstats",
		"the folder is called leaderstats: the engine looks for exactly that name")
	check(#Service.COLUMNS == 3, "three columns")
	check(Service.COLUMNS[1].key == "Steals",
		"and STEALS LEADS, because the list ranks by the first stat -- the order is the sort")
	local byKey = {}
	for index, column in ipairs(Service.COLUMNS) do byKey[column.key] = { index = index, class = column.class } end
	check(byKey.Money ~= nil and byKey.Money.class == "StringValue",
		"money is a StringValue, so it carries a formatted figure")
	check(byKey.Money.index ~= 1,
		"which is exactly why it cannot lead: a formatted string sorts as nothing")
	check(byKey.Steals.class == "IntValue" and byKey.Rebirths.class == "IntValue",
		"and the two ranking columns are integers, which sort honestly")

	-- ---- the pure half
	local stats = Service.statsFor({ coins = 2860000, piggiesStolen = 7, rebirths = 2 })
	check(stats.Steals == 7 and stats.Rebirths == 2, "the counters are the save's own")
	check(stats.Money == Config.formatCoins(2860000),
		"and the money column is Config's own formatter, not a second copy of it")
	check(type(stats.Money) == "string" and stats.Money ~= "2860000",
		"so a nine-year-old reads 2.86m rather than a row of digits")
	local junk = Service.statsFor({ coins = 0 / 0, piggiesStolen = -4, rebirths = 1.7 })
	check(junk.Steals == 0 and junk.Rebirths == 1 and junk.Money == Config.formatCoins(0),
		"junk normalises to zero or a whole number rather than reaching a column")

	-- ---- publishing one player
	local rich = player("Rich", { coins = 5000000, piggiesStolen = 3, rebirths = 2 })
	Service.publish(rich)
	local folder = rich:FindFirstChild("leaderstats")
	check(folder ~= nil, "publishing builds the folder on the player")
	check(folder.ClassName == "Folder", "as a Folder, which is what the list looks for")
	check(#folder.Kids == 3, "holding one value per column")
	for index, column in ipairs(Service.COLUMNS) do
		check(folder.Kids[index].Name == column.key,
			"parented in COLUMNS order, because column order is child order")
		check(folder.Kids[index].ClassName == column.class, column.key .. " has its declared class")
	end
	check(folder:FindFirstChild("Steals").Value == 3
		and folder:FindFirstChild("Rebirths").Value == 2
		and folder:FindFirstChild("Money").Value == Config.formatCoins(5000000),
		"and every column reads the save")

	-- ---- WRITTEN ONLY ON CHANGE, which is the whole reason this stub counts
	local settled = writes
	Service.publish(rich)
	check(writes == settled, "a second publish with nothing moved writes nothing at all")
	check(#folder.Kids == 3, "and builds no second set of columns")
	-- AND THE FORMATTED COLUMN IS QUIETER STILL, WHICH FELL OUT OF THE
	-- FORMATTER RATHER THAN BEING DESIGNED: a balance that moves inside its
	-- own rounding reads the same string, so it is not a change. An idle pig
	-- ticks constantly and most of those ticks now cost nothing at all.
	saves[rich].coins = 5000001
	Service.publish(rich)
	check(writes == settled, "a balance that moves inside its own rounding still writes nothing")
	saves[rich].coins = 6000000
	Service.publish(rich)
	check(writes == settled + 1, "and a balance that moves the FIGURE writes exactly that column")
	check(folder:FindFirstChild("Money").Value == Config.formatCoins(6000000), "with the new figure")

	-- ---- A PLAYER MID-LOAD GETS NO ROW RATHER THAN A ROW OF ZEROES
	local loading = player("Loading", nil)
	Service.publish(loading)
	check(loading:FindFirstChild("leaderstats") == nil,
		"a player whose save has not landed gets no folder, not three zeros")
	saves[loading] = { coins = 10, piggiesStolen = 0, rebirths = 0 }
	Service.publish(loading)
	check(loading:FindFirstChild("leaderstats") ~= nil, "and gets one the moment the save lands")

	-- ---- the cadence covers everybody
	players = { rich, loading, player("Third", { coins = 1, piggiesStolen = 1, rebirths = 1 }) }
	Service.push()
	for _, p in players do
		check(p:FindFirstChild("leaderstats") ~= nil, "push covers every player in the server")
	end

	-- ---- and the wiring, read off the sources
	local s = sources.LobbyBoardService
	check(s:find("Config.LEADERBOARD_REFRESH", 1, true) ~= nil, "written on the leaderboard's own cadence")
	check(s:find("Players.PlayerAdded:Connect", 1, true) ~= nil, "and once as a player lands")
	check(s:find("DataService.get", 1, true) ~= nil, "read from the live session data, never a copy")
	-- NO PUSH ON LEAVE: the list drops a player who has gone without being
	-- told, which is one of the duties this move deleted.
	check(s:find("PlayerRemoving", 1, true) == nil,
		"and nothing on leave: the component drops a row that has gone")
	check(s:find("FireAllClients", 1, true) == nil and s:find("Remotes", 1, true) == nil,
		"nothing is broadcast: leaderstats replicates itself")
	check(sources.Main:find("require(Services.LobbyBoardService).start()", 1, true) ~= nil,
		"Main starts the service")
end

-- ------------------------------------------------------------
-- 4. THE PANEL IS GONE, AND SO IS EVERYTHING THAT REASONED ABOUT ITS CORNER
-- ------------------------------------------------------------
do
	local cm = sources.ClientMain
	check(cm:find("CoreGuiType.PlayerList", 1, true) == nil,
		"the player list is not switched off any more: it IS the leaderboard")
	check(cm:find("Shared.LobbyBoard", 1, true) == nil,
		"and ClientMain starts no board of our own")
	check(cm:find("BoardOpen", 1, true) == nil,
		"there is no collapse state left to remember")
	check(sources.Remotes:find("LobbyBoard = ", 1, true) == nil,
		"the remote is retired with the panel that read it")

	-- THE ONE NEIGHBOUR THAT OUTLIVED THE BOARD is the card that has to stay
	-- clear of that corner. A CoreGui cannot be measured, so what used to be
	-- a published width has to be a BOUND -- and a bound that is a pure
	-- fraction of the screen is the wrong shape for a thing of fixed size.
	local hl = sources.HUDLayout
	check(hl:find("BoardWidth", 1, true) == nil, "nothing publishes a board width any more")
	check(hl:find("HUDLayout.PLAYER_LIST_W", 1, true) ~= nil, "the reserve is a named bound")
	check(hl:find("math.min(HUDLayout.PLAYER_LIST_W", 1, true) ~= nil,
		"capped in pixels as well as in fraction, because the list does not grow with the screen")
	check(sources.FirstJob:find("HUDLayout.rightClear", 1, true) ~= nil,
		"and the first-job card still asks for it rather than keeping its own copy")
end

print(("PASS: %d lobby board checks; the save field, the secure-time increment, the leaderstats contract -- folder name, column order as the sort, classes, formatting, write-on-change -- and the retirement of the custom panel, its remote and its reserved corner. No live saves, no screen."):format(checks))
