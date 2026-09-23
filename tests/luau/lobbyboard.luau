-- THE STREET LEADERBOARD, held together across the six files it spans: the
-- save field, the one place it is incremented, the service that pushes it,
-- the panel that draws it, and the two lines that start both halves. The
-- accounting is the real Config and the real services against doubles for
-- the figure, the network and the DataStore; nothing here touches a live
-- save or a screen.
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
		CarryPose = { HOLD = frame },
		Theme = { FONT = "F", PAPER = "p", INK = "i", GOLD = "g" },
		DataService = { get = function(p) return p.data end, save = function() end },
		PlotService = {
			setSwapOffer = function() end,
			getAll = function() return {} end,
			getPlot = function(p) return home[p] end,
			yardContaining = function() return nil end,
			setPiggySlots = function() end, setPiggyBuffers = function() end,
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
-- 3. THE SERVICE: rows for loaded players, in a stable order, broadcast
-- ------------------------------------------------------------
local Service
do
	local fired = {}
	local players = {}
	local modules = {
		Config = Config,
		Remotes = { get = function(name)
			return { FireAllClients = function(_, payload) table.insert(fired, { name = name, payload = payload }) end }
		end },
		DataService = { get = function(p) return p.data end },
	}
	local env = setmetatable({
		game = { GetService = function(_, name)
			if name == "ReplicatedStorage" then return { Shared = names } end
			if name == "Players" then return { GetPlayers = function() return players end,
				PlayerAdded = { Connect = function() end }, PlayerRemoving = { Connect = function() end } } end
			return {}
		end },
		require = function(n) return assert(modules[n], tostring(n)) end,
		script = { Parent = names },
		task = { spawn = function() end, defer = function() end, wait = function() end },
	}, { __index = getfenv() })
	local run = assert(loadstring(sources.LobbyBoardService, "LobbyBoardService")); setfenv(run, env)
	Service = run()

	local function player(id, name, data)
		return { UserId = id, DisplayName = name, Name = name .. "_acct", data = data }
	end
	players = {
		player(1, "Poor", { coins = 10, piggiesStolen = 0, rebirths = 0 }),
		player(2, "Rich", { coins = 5000000, piggiesStolen = 3, rebirths = 2 }),
		player(3, "Loading", nil),
		player(4, "Tied", { coins = 10, piggiesStolen = 2, rebirths = 9 }),
		player(5, "Junk", { coins = 0 / 0, piggiesStolen = -4, rebirths = 1.7 }),
	}
	local rows = Service.snapshot(players, function(p) return p.data end)
	check(#rows == 4, "a player whose save has not landed has no row")
	check(rows[1].name == "Rich" and rows[1].userId == 2, "sorted by cash, richest first")
	check(rows[2].name == "Tied" and rows[3].name == "Poor", "a cash tie is broken by piggies robbed")
	check(rows[4].name == "Junk" and rows[4].coins == 0 and rows[4].piggiesStolen == 0 and rows[4].rebirths == 1,
		"junk numbers print as zero or a whole number rather than sorting to the top")
	for _, row in rows do
		for _, field in { "name", "userId", "coins", "piggiesStolen", "rebirths" } do
			check(row[field] ~= nil, "every row carries " .. field)
		end
		check(row.name:find("_acct", 1, true) == nil, "rows carry the display name, as every toast does")
	end
	check(rows[1].coins == 5000000 and rows[1].piggiesStolen == 3 and rows[1].rebirths == 2, "the figures are the save's own")
	Service.push()
	check(#fired == 1 and fired[1].name == "LobbyBoard" and #fired[1].payload == 4, "push broadcasts the snapshot on the LobbyBoard remote")
	local s = sources.LobbyBoardService
	check(s:find("Config.LEADERBOARD_REFRESH", 1, true) ~= nil, "pushed on the leaderboard's own cadence")
	check(s:find("Players.PlayerAdded:Connect", 1, true) ~= nil and s:find("Players.PlayerRemoving:Connect", 1, true) ~= nil,
		"and on every join and leave")
	check(s:find("DataService.get", 1, true) ~= nil, "read from the live session data, never a copy")
	check(sources.Remotes:find('LobbyBoard = "RemoteEvent"', 1, true) ~= nil, "the channel is declared in Remotes")
	check(sources.Main:find("require(Services.LobbyBoardService).start()", 1, true) ~= nil, "Main starts the service")
end

-- ------------------------------------------------------------
-- 4. THE PANEL: rows, formatting, columns wide enough for their payload
-- ------------------------------------------------------------
do
	local modules = {
		Config = Config,
		Remotes = { get = function() return { OnClientEvent = { Connect = function() end } } end },
		Theme = setmetatable({ MENU_Z = 45 }, { __index = function() return {} end }),
		MenuIcons = {},
	}
	local env = setmetatable({
		game = { GetService = function(_, name)
			if name == "ReplicatedStorage" then return { Shared = names } end
			if name == "UserInputService" then return { InputBegan = { Connect = function() end }, GetFocusedTextBox = function() return nil end } end
			return {}
		end },
		require = function(n) return assert(modules[n], tostring(n)) end,
		script = { Parent = names },
		utf8 = utf8,
	}, { __index = getfenv() })
	local run = assert(loadstring(sources.LobbyBoard, "LobbyBoard")); setfenv(run, env)
	local Board = run()

	local payload = {
		{ name = "Rich", userId = 2, coins = 999900000, piggiesStolen = 12, rebirths = 3 },
		{ name = "Me", userId = 7, coins = 1234, piggiesStolen = 0, rebirths = 0 },
	}
	local rows = Board.rowsFor(payload, 7)
	check(#rows == 2 and rows[1].rank == "1" and rows[2].rank == "2", "rank is the server's order")
	check(rows[1].coins == Config.formatCoins(999900000) and rows[1].coins == "999.9M", "cash goes through the one coin formatter")
	check(rows[2].me == true and rows[1].me == false, "the reader's own row is marked")
	check(rows[1].piggies == "12" and rows[1].rebirths == "3", "the two counts print as whole numbers")
	check(#Board.rowsFor("nonsense", 7) == 0 and #Board.rowsFor(nil, 7) == 0, "a bad payload draws an empty board")
	local many = {}
	for i = 1, Board.ROWS + 3 do many[i] = { name = "P" .. i, userId = i, coins = 0, piggiesStolen = 0, rebirths = 0 } end
	check(#Board.rowsFor(many, 1) == Board.ROWS, "never more rows than seats in the server")
	check(Board.ROWS == Config.MAX_PLAYERS, "and that is Config.MAX_PLAYERS")

	-- THE COLUMNS AGAINST THEIR LONGEST PAYLOAD. No TextBounds without a
	-- renderer, so these are upper bounds from this project's own measured
	-- glyph widths: FredokaOne runs 0.48-0.58 em per glyph ("Everything" 62
	-- at 13, "Worn" 30 at 13) and GothamBold 0.54-0.67 ("888.8K" 55 at 17,
	-- "MOST WANTED" 88 at 12, all caps). 0.62 and 0.70 are taken as the
	-- ceilings; a real TextBounds read in Studio is what closes this.
	local FREDOKA, GOTHAM = 0.62, 0.70
	local widths = {}
	for _, column in Board.COLUMNS do widths[column.key] = column.width end
	local function fits(text, em, size, width, what)
		local need = #text * em * size
		check(need <= width, ("%s: %d chars at %dpx need %.0f in %d"):format(what, #text, size, need, width))
	end
	fits("Sixteencharname1", FREDOKA, Board.ROW_TEXT, widths.name, "a 16-character display name")
	fits("999.9M", GOTHAM, Board.ROW_TEXT, widths.coins, "the largest cash figure")
	fits("99999", GOTHAM, Board.ROW_TEXT, widths.piggies, "a five-digit robbery count")
	fits("99", GOTHAM, Board.ROW_TEXT, widths.rebirths, "a two-digit rebirth count")
	fits("8", GOTHAM, Board.ROW_TEXT, widths.rank, "the rank")
	fits("REBIRTHS", GOTHAM, Board.HEAD_TEXT, widths.rebirths - 16, "the rebirths head beside its star")
	fits("ROBBED", GOTHAM, Board.HEAD_TEXT, widths.piggies, "the robbed head")
	fits("PLAYER", GOTHAM, Board.HEAD_TEXT, widths.name, "the player head")
	fits("STREET LEADERBOARD", FREDOKA, 24, Board.WIDTH - Board.PAD * 2 - 52, "the title beside its close button")
	fits("Lifetime totals of everybody in this server", GOTHAM, 12, Board.WIDTH - Board.PAD * 2 - 52, "the subtitle")
	check(Board.WIDTH == 570 and Board.HEIGHT == 380, "the card is 570 x 380 design pixels")
	-- A phone held sideways is the shortest thing that has to work: the card
	-- fits 736 x 414 unscaled and scales on anything shorter.
	check(Board.HEIGHT <= 414 - 24 and Board.WIDTH <= 736 - 24, "fits a phone held sideways at scale 1")

	local s = sources.LobbyBoard
	check(s:find("STREET LEADERBOARD", 1, true) ~= nil and s:find("Lifetime", 1, true) ~= nil,
		"the header names the board and the subtitle names the claim: lifetime, not this week")
	check(s:find("Theme.MENU_Z - 1", 1, true) ~= nil, "drawn one step under the menu layer, so a menu always covers it")
	check(s:find('"BagOpen"', 1, true) ~= nil and s:find('"SettingsOpen"', 1, true) ~= nil and s:find('"DisplayOrder"', 1, true) ~= nil,
		"closes itself when the bag, settings or the shop opens")
	check(s:find("Enum.KeyCode.Tab", 1, true) ~= nil and s:find("Enum.KeyCode.L", 1, true) ~= nil,
		"Tab and L toggle it")
	check(s:find('"BoardToggle", "TROPHY"', 1, true) ~= nil and s:find("toggle.LayoutOrder = 4", 1, true) ~= nil,
		"the button is the fourth tile of the menu rail, under SHOP")
	check(s:find("TextScaled = false", 1, true) ~= nil, "no cell is TextScaled")
	check(sources.MenuIcons:find("TROPHY = board", 1, true) ~= nil, "MenuIcons draws the trophy tile")
	check(sources.HUDLayout:find("tiles * 64", 1, true) ~= nil and sources.HUDLayout:find("menu.ChildAdded:Connect", 1, true) ~= nil,
		"the menu rail is sized by its tiles and re-fits when one is added")
	local starts = select(2, sources.ClientMain:gsub("require%(ReplicatedStorage%.Shared%.LobbyBoard%)%.start%(player, gui, shop%)", ""))
	check(starts == 1, "ClientMain starts the panel in exactly one statement holding no local")
end

print(("PASS: %d lobby board checks; the save field, the secure-time increment, the service snapshot and push, the panel's rows and columns, and the wiring in Remotes, Main and ClientMain. No live saves, no screen."):format(checks))
