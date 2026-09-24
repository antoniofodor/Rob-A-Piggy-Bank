--!strict
--[[
	CombineService -- THE MACHINE'S SERVER HALF, AND NOT A SECOND ECONOMY.

	Designer, 2026-09-23: "move the combine machine outside of the shop and
	into a dedicated spot on the map where players can combine their piggies
	and pets there for a chance to get better one."

	----------------------------------------------------------------------
	IT OWNS A PLACE, A PROMPT AND A HOPPER. IT OWNS NO ARITHMETIC AT ALL.

	THE HOPPER ARRIVED LATER AND IS THE ONE SAVE FIELD THIS FILE WRITES.
	`data.press` has exactly one writer -- here -- which is why it does not
	break the rule below rather than being an exception to it: what that rule
	refuses is a SECOND writer to a field somebody else owns. The suite
	checks the narrow version, that every field assigned here is `press`.

	`ChestService.combine` has done the whole transaction since spares
	existed: it validates the pick against the save, refuses out loud on
	every failure, consumes `Config.COMBINE.need` spares PAST every refusal,
	rolls the climb on `Config.COMBINE.odds`, grants through `SetService`,
	pushes `ChestState` and fires `ChestResult`. Not one line of that is
	repeated here, and the reason is sharper than tidiness: `data.spares` is
	a SAVE FIELD keyed `kind:key`, and a second writer to it that got the
	decrement wrong would be a save bug rather than a broken feature.

	So this file forwards. What it adds is the two things a station needs and
	a shop row did not: a KIND (piggies or guardians) and a refusal for the
	one failure a shop row could not have -- a kind with no crate stocked to
	roll out of.

	----------------------------------------------------------------------
	WHY `combine` AND NOT `rollUp`.

	The crates workstream is adding `ChestService.rollUp(player, fromTier,
	kind)`, which rolls a tier up WITHOUT consuming the inputs. That is the
	right tool for something that has already taken payment and the wrong one
	here: using it would mean writing the consumption in this file, which is
	exactly the second writer above. `combine` takes a chest KEY instead of a
	kind, and the station answers that question itself -- see
	`CombineStation.shelvesFor`, which derives a kind's shelves from what the
	crate pools actually stock. So this file depends on nothing in flight.

	The require is still guarded and the capability is still checked once,
	because ChestService is being edited by another workstream as this is
	written: a missing function warns LOUDLY at startup and refuses OUT LOUD
	at the prompt, rather than erroring on a nine-year-old's first hold.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CombineStation = require(ReplicatedStorage.Shared.CombineStation)

local DataService = require(script.Parent.DataService)
local PiggyHaulService = require(script.Parent.PiggyHaulService)

local CombineService = {}

-- PCALLED, BECAUSE THIS SERVICE MAY NEVER BE THE THING THAT STOPS THE BOOT.
--
-- `Main` runs every `start` in sequence, so anything that throws in here
-- takes the plots, the economy and the game with it. Same argument as the
-- pcall around `Decor.prewarm`: a lawn ornament may never stop the server
-- starting, and a combine machine is the same class of thing.
--
-- A require rather than a registry, because there is no cycle to avoid:
-- ChestService requires DataService and SetService and neither of those --
-- nor ChestService -- knows this file exists.
local ChestService: any = nil
do
	local ok, loaded = pcall(function()
		return require(script.Parent.ChestService)
	end)
	if ok then
		ChestService = loaded
	else
		warn("[CombineService] ChestService did not load, so the combine machine will"
			.. " stand on the verge and refuse: " .. tostring(loaded))
	end
end

-- The one capability this file uses, checked once by NAME rather than
-- assumed. A nil here is a machine that refuses with a sentence; calling it
-- would be an error inside a ProximityPrompt handler, which is silent on the
-- client and a stack trace on the server.
local function combineReady(): boolean
	return type(ChestService) == "table" and type(ChestService.combine) == "function"
end

local warnedOnce = false
local function warnMissing()
	if warnedOnce then
		return
	end
	warnedOnce = true
	warn("[CombineService] ChestService.combine is missing, so the combine machine"
		.. " cannot run. Every hold will refuse.")
end

local function notify(player: Player, message: string, kind: string)
	Remotes.get("Notify"):FireClient(player, message, kind)
end

-- ============================================================
-- THE REQUEST
-- ============================================================

-- WHAT A CLIENT MAY ASK FOR, AND NOTHING ELSE.
--
-- A kind out of `CombineStation.KINDS`, a chest key out of the shelves that
-- kind actually has, a tier out of `Config.RARITY_ORDER`, and an OPTIONAL
-- list of `kind:key` entries. Every one is checked against the real list
-- rather than trusted -- the same reason `SettingsService` is an allowlist
-- and `ChestCombine`'s own handler checks its tier against `RARITY_ORDER`.
--
-- THE ENTRY LIST IS REBUILT RATHER THAN FORWARDED WHOLESALE, and the bound
-- is one past `need`: `ChestService.validatePick` refuses anything that is
-- not exactly `need`, so a client sending ten thousand is refused without
-- this walking ten thousand of them. That is `ChestCombine`'s own guard,
-- kept because this is a second door into the same function.
function CombineService.request(player: Player, kindKey: unknown, chestKey: unknown,
	tier: unknown, entries: unknown)
	if type(kindKey) ~= "string" or type(chestKey) ~= "string" or type(tier) ~= "string" then
		return
	end
	if not combineReady() then
		warnMissing()
		notify(player, "The Piggy Press is out of order.", "warn")
		return
	end

	local kind = CombineStation.kind(kindKey)
	if not kind then
		return
	end
	if not table.find(Config.RARITY_ORDER, tier) then
		return
	end

	-- The shelf has to be one this kind really offers. A client naming any
	-- other chest would be combining into a pool the machine never showed
	-- it, which is the same class as a client naming a save field.
	local shelf = nil
	for _, candidate in ipairs(CombineStation.shelvesFor(kindKey)) do
		if candidate.chest == chestKey then
			shelf = candidate
			break
		end
	end
	if not shelf then
		-- NOTHING LEFT TO WIN, SAID BEFORE ANY SPARE IS TOUCHED. This is the
		-- one refusal the shop row could not have: a kind whose catalogue or
		-- whose crate does not exist yet. `CombineStation.refusal` words it,
		-- so the panel's greyed button and this say the same thing.
		local reason = CombineStation.refusal(nil, kindKey, nil, nil)
		notify(player, reason or "That shelf is not stocked yet.", "warn")
		return
	end

	local chosen: { string }? = nil
	if type(entries) == "table" then
		local list: { string } = {}
		for _, entry in ipairs(entries :: any) do
			if #list > Config.COMBINE.need then
				break
			end
			if type(entry) == "string" then
				table.insert(list, entry)
			end
		end
		chosen = list
	end

	-- AND THEN IT IS ChestService'S. Every count, every refusal, the
	-- consumption, the roll, both pushes and the reveal.
	ChestService.combine(player, tier, chestKey, chosen)
end

-- ============================================================
-- THE PLACE
-- ============================================================

-- BUILT HERE RATHER THAN IN `NeighborhoodService`, AND THAT IS A DECISION.
--
-- The four shops are built over there and their door prompts wired over
-- there, which is right for a building whose only behaviour is one remote.
-- This carries a panel, a request handler and a capability that may be
-- missing, so it lives with them: a machine that refuses because
-- ChestService did not load should say so from the file that found out.
--
-- `NeighborhoodService` still has to know WHERE it stands, because the verge
-- grass and the verge trees both need vetoing round it -- and it asks
-- `CombineStation`, which is pure and needs no built model, so neither
-- service has to run before the other.
-- ============================================================
-- THE HOPPER
-- ============================================================

-- `rollUp` rather than `combine`, and that is the whole reason the press can
-- eat piggies at all. `combine` consumes `data.spares`, and a piggy never
-- becomes one -- see the note above `Config.PRESS`. `rollUp` rolls a tier up
-- and consumes NOTHING, so the consumption is the hopper's own and there is
-- still exactly one writer to each field.
local function pressReady(): boolean
	return type(ChestService) == "table" and type(ChestService.rollUp) == "function"
end

-- ONE BAY PER TIER, CREATED ON FIRST READ. `data.press` is a brand new
-- top-level save field, which is the free case: `DataService.reconcile`'s
-- generic pass fills it in on every existing save with no migration branch,
-- nothing to pay out and nothing that can run twice.
local function hopper(data: any)
	if type(data.press) ~= "table" then
		data.press = {}
	end
	for _, tier in ipairs(Config.PRESS.tiers) do
		if type(data.press[tier]) ~= "table" then
			data.press[tier] = {}
		end
	end
	return data.press
end

-- WHAT IS IN *THIS PLAYER'S* PRESS. Fired to one client and never broadcast.
function CombineService.pushState(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local held = hopper(data)
	local payload = {}
	for _, tier in ipairs(Config.PRESS.tiers) do
		payload[tier] = {
			keys = table.clone(held[tier]),
			need = Config.pressNeed(tier),
		}
	end
	Remotes.get("PressState"):FireClient(player, payload)
end

-- FEED IT WHAT IS IN THEIR ARMS.
--
-- PEEK, DECIDE, THEN TAKE. Every refusal below happens while the piggy is
-- still being carried, because `take` has already removed it from `owned` --
-- so the haul record is the only copy, and surrendering before a refusal
-- would delete it outright.
-- TAKE THE INPUTS OUT, ROLL, AND PUT THEM BACK IF THE ROLL REFUSES.
--
-- `rollUp` turns down a full lawn and a finished pool, and a press that
-- swallowed the inputs and handed back nothing is the exact failure
-- `ChestService.combine`'s own comment is written against. It names the prize
-- on the way out and names the refusal too, so there is no toast of ours on
-- either branch. Returns whether the bay actually paid.
local function crush(player: Player, data: any, bay: { string }, tier: string, need: number): boolean
	local eaten = {}
	for _ = 1, need do
		table.insert(eaten, table.remove(bay, 1))
	end
	if ChestService.rollUp(player, tier, "skin") ~= nil then
		return true
	end
	for i = #eaten, 1, -1 do
		table.insert(bay, 1, eaten[i])
	end
	return false
end

function CombineService.feed(player: Player)
	if not pressReady() then
		warnMissing()
		notify(player, "The Piggy Press is out of order.", "warn")
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end

	local key, own = PiggyHaulService.peekHaul(player)
	if not key then
		notify(player, "Carry a piggy over and the press will take it.", "warn")
		return
	end
	if not own then
		notify(player, "That one is not yours to crush. Take it home first.", "warn")
		return
	end
	local skin = Config.getSkin(key)
	local tier = if skin then Config.rarityOf(skin) else "common"
	local need = Config.pressNeed(tier)
	if not need then
		notify(player, ("There is nothing above %s to press one into."):format(tier), "warn")
		return
	end

	-- A BAY THAT CANNOT PAY OUT DOES NOT KEEP TAKING.
	--
	-- The crush can refuse -- `rollUp` turns down a full lawn and a player who
	-- already owns everything above this tier -- and the inputs go back in the
	-- bay when it does. Without this the next feed stacks on top of a bay that
	-- is already at its limit and the panel reads 3 of 2, which is a number
	-- that cannot be true. Retried first, because whatever blocked it may have
	-- cleared since; refused second, with the piggy still in their arms rather
	-- than swallowed by a machine that has already said no.
	local bay = hopper(data)[tier]
	if #bay >= need then
		crush(player, data, bay, tier, need)
		if #bay >= need then
			DataService.save(player)
			CombineService.pushState(player)
			notify(player, ("The %s bay is full and the press cannot pay out yet.")
				:format(tier), "warn")
			return
		end
	end

	if PiggyHaulService.surrender(player) == nil then
		return
	end
	table.insert(bay, key)

	if #bay < need then
		-- SAVED IN THE SAME BREATH AS THE INSERT. The piggy is out of `owned`
		-- and out of their arms, so this table is the only record of it and a
		-- disconnect between here and the next autosave would lose it.
		DataService.save(player)
		CombineService.pushState(player)
		notify(player, ("%s press: %d of %d."):format(tier:upper(), #bay, need), "money")
		return
	end

	-- FULL. Take the inputs out, roll, and PUT THEM BACK if the roll refuses.
	-- `rollUp` turns down a full lawn and a finished pool, and a press that
	-- swallowed the inputs and handed back nothing is the exact failure
	-- `ChestService.combine`'s own comment is written against.
	crush(player, data, bay, tier, need)
	-- `rollUp` names the prize itself on the way out, and names the refusal
	-- too, so there is no toast of ours on either branch.
	DataService.save(player)
	CombineService.pushState(player)
end

local function build()
	local parent = workspace:FindFirstChild("World") or workspace
	local existing = parent:FindFirstChild("CombineStation")
	if existing then
		existing:Destroy()
	end

	local at = CombineStation.placement()
	local groundY = -Config.PLOT_SIZE.Y / 2
	local frame = CFrame.new(at.x, 0, at.z) * CFrame.Angles(0, at.yaw, 0)
	local model, prompt = CombineStation.build(frame, groundY, parent)

	-- THE PROMPT IS WIRED HERE, ON THE SERVER, AT THE MOMENT THE PART
	-- EXISTS. The client cannot do it for itself: this is built during
	-- startup, and a tag set before parenting never fires
	-- `GetInstanceAddedSignal` on a peer it replicates to -- the fault that
	-- left all four shop doors wired to nothing. Same fix, same reason.
	prompt.Triggered:Connect(function(player: Player)
		-- EITHER HALF IS ENOUGH TO BE WORTH OPENING. The two paths need
		-- different things off ChestService -- the hopper needs `rollUp` and
		-- the guardian shelf needs `combine` -- so a guard on one would have
		-- refused a carried piggy because the OTHER feature was unavailable.
		-- `feed` re-checks its own capability by name a line later.
		if not (combineReady() or pressReady()) then
			warnMissing()
			notify(player, "The Piggy Press is out of order.", "warn")
			return
		end
		-- THE HOLD CARRIES NOTHING. It means "use it", never "use it with
		-- this in it" -- the same call `BoneThrow`, `placeLadder` and
		-- `CrackTap` all make. What it DOES depends on the player's own hands,
		-- which the server reads for itself:
		--
		-- CARRYING FEEDS IT, EMPTY HANDS OPEN IT. One prompt rather than two,
		-- because two prompts on one part is a collision this project has
		-- already paid for twice and the two states are mutually exclusive by
		-- construction -- you cannot be carrying and not carrying.
		local carried = PiggyHaulService.peekHaul(player)
		if carried ~= nil then
			CombineService.feed(player)
			return
		end
		CombineService.pushState(player)
		Remotes.get("CombineOpen"):FireClient(player)
	end)

	-- THE CLEARANCES, PRINTED AT STARTUP, so a street edit that closes one
	-- says so in the log rather than in a screenshot six weeks later.
	--
	-- Same argument as `auditFences` and `auditEconomy`: the failure is a
	-- NUMBER, nothing errors, nothing looks wrong from a plan view, and the
	-- moment to hear about a number is while you are typing it. This one
	-- warns rather than merely printing, because a negative clearance means
	-- the machine is standing in the carriageway, on a driveway or through
	-- somebody's fence.
	local clearances = CombineStation.clearances()
	local worst, worstName = math.huge, "?"
	for name, gap in pairs(clearances) do
		if gap < worst then
			worst, worstName = gap, name
		end
		if gap < 0 then
			warn(("[CombineService] the combine machine is %.2f studs INTO the %s."):format(-gap, name))
		end
	end
	print(("[CombineService] Piggy Press in gap %s at x %.0f, z %.1f: %d parts,"
		.. " tightest clearance %.2f studs (%s)"):format(
		tostring(at.gap), at.x, at.z, #model:GetDescendants(), worst, worstName))

	return model
end

function CombineService.start()
	if not combineReady() then
		warnMissing()
	end

	-- PCALLED FOR THE REASON THE GRASSLAND IS. A machine that fails to build
	-- is a bare patch of verge; a machine that fails to build and takes
	-- `Main` with it is every plot, every service after it and no "Ready" in
	-- the log at all.
	local ok, err = pcall(build)
	if not ok then
		warn("[CombineService] the combine machine did not build: " .. tostring(err))
	end

	-- A PART-FILLED BAY SURVIVES A SESSION, so it has to arrive with one. A
	-- player who left at 1 of 3 comes back to 1 of 3, and the panel is the
	-- only place that says so.
	game:GetService("Players").PlayerAdded:Connect(function(player)
		task.defer(CombineService.pushState, player)
	end)

	Remotes.get("CombineRequest").OnServerEvent:Connect(function(player, kindKey, chestKey, tier, entries)
		CombineService.request(player, kindKey, chestKey, tier, entries)
	end)
end

return CombineService
