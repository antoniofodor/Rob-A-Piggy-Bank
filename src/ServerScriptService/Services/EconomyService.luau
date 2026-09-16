--!strict
--[[
	EconomyService

	Coin accrual, offline catch-up, and the two economy upgrades.

	THE PIG IS THE WALLET. There is one balance, `data.coins`, and it lives in
	the piggy bank on the lawn: every coin a player has is in there, every
	coin in there can be taken, and there is no bank to move it into. Income
	drips in until the pig is full and stops until something is spent. That
	is the "spend it or lose it" loop the robbing pivot rests on -- see
	CLAUDE.md under THE ROBBING PIVOT for why the old vault/coins split was
	the reason nobody robbed anybody.

	Everything here is server-authoritative on purpose. The client renders
	coins; it never counts them. In a game where players take currency from
	each other, a trusted client is an open till -- so every request from a
	client is treated as a suggestion and re-derived from stored state.

	Rate limits sit on every entry point for the same reason.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local SocialService = require(script.Parent.SocialService)
local DailyService = require(script.Parent.DailyService)

local EconomyService = {}

local TICK_RATE = 1
local MIN_REQUEST_GAP = 0.25

local lastRequest: { [Player]: { [string]: number } } = {}

-- Highest milestone index each player has crossed on their current fill.
-- Resets once the pig drops back under the first threshold, so the
-- celebration replays every time it fills rather than firing once per
-- lifetime.
local milestoneReached: { [Player]: number } = {}

-- The whole-coin balance the tick last drew on the lawn and pushed to the
-- HUD. Every service that moves coins -- a purchase, a chest, bail, a daily,
-- a delivery -- used to have to remember to repaint the pile and push the
-- state itself, and the ones that forgot read as the thing being free. The
-- tick compares against this and catches up within a second whatever moved
-- the number.
local lastShown: { [Player]: number } = {}
local lastAcornsShown: { [Player]: number } = {}

-- ============================================================
-- HELPERS
-- ============================================================

local function throttled(player: Player, action: string): boolean
	local now = os.clock()
	local perPlayer = lastRequest[player]
	if not perPlayer then
		perPlayer = {}
		lastRequest[player] = perPlayer
	end
	if perPlayer[action] and (now - perPlayer[action]) < MIN_REQUEST_GAP then
		return true
	end
	perPlayer[action] = now
	return false
end

local function pushState(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end

	local acorns = math.floor(data.loot)
	local plot = PlotService.getPlot(player)
	if plot then
		PlotService.updateAcorns(plot, acorns)
		PlotService.updateTreeAcorns(plot, data.treeAcorns or 0, data.groundAcorns or 0)
	end
	lastAcornsShown[player] = acorns
	local capacity = Config.getCapacity(data.capacityLevel)
	Remotes.get("StateUpdate"):FireClient(player, {
		coins = math.floor(data.coins),
		acorns = acorns,
		capacity = capacity,
		-- Income has stopped. The HUD turns the bar red on this rather than
		-- on the ratio, because a pig can sit ABOVE capacity after a robbery
		-- and is just as full then.
		full = data.coins >= capacity,
		rate = Config.getIncomeRate(data.incomeLevel, data.rebirths, SocialService.getFriendBonus(player)),
		friendBonus = SocialService.getFriendBonus(player),
		incomeLevel = data.incomeLevel,
		capacityLevel = data.capacityLevel,
		incomeCost = Config.getIncomeCost(data.incomeLevel),
		capacityCost = Config.getCapacityCost(data.capacityLevel),
		-- The reachable ceiling, not the absolute one: it rises two levels per
		-- rebirth, and the client draws the ladder from these two numbers, so
		-- pushing the function's answer is what keeps both ends agreeing.
		maxIncome = Config.maxLevel(data.rebirths),
		maxCapacity = Config.maxLevel(data.rebirths),
		rebirths = data.rebirths,
		-- Carried on the per-tick state rather than its own push, so the
		-- rebirth button lights up the instant the threshold is crossed.
		rebirthThreshold = Config.getRebirthThreshold(data.rebirths),
		rebirthReady = data.coins >= Config.getRebirthThreshold(data.rebirths),
	})
	lastShown[player] = math.floor(data.coins)
end

-- Exposed so anything that moves `coins` from outside this file can say so
-- immediately rather than waiting up to a second for the tick to notice.
EconomyService.push = pushState

local function notify(player: Player, message: string, kind: string?)
	Remotes.get("Notify"):FireClient(player, message, kind or "info")
end

local function refreshPlot(player: Player)
	local data = DataService.get(player)
	local plot = PlotService.getPlot(player)
	if not data or not plot then
		return
	end
	PlotService.updatePile(plot, data.coins, Config.getCapacity(data.capacityLevel))
	PlotService.updateSign(plot, player.DisplayName, data.rebirths,
		Config.getSkin(data.cosmetics.skin).name, Config.getHouseTier(Config.getShownHouseLevel(data)).name)
end

-- Fires the celebration for every milestone the pig has newly crossed.
-- Only the highest is played, so a big offline catch-up that jumps straight
-- past three thresholds gets one satisfying chime, not three overlapping ones.
local function checkMilestones(player: Player, plot: any, ratio: number)
	local reached = milestoneReached[player] or 0

	-- Spending (or being robbed) below the first rung re-arms the ladder, so
	-- the next fill celebrates again. Without this the milestones fired once
	-- per session, since nothing else ever reset them now that banking is
	-- gone.
	if ratio < Config.MILESTONES[1] then
		milestoneReached[player] = 0
		return
	end

	local highest = reached
	for index, threshold in ipairs(Config.MILESTONES) do
		if ratio >= threshold and index > highest then
			highest = index
		end
	end

	if highest > reached then
		milestoneReached[player] = highest
		PlotService.playMilestone(plot, highest, #Config.MILESTONES)

		if highest == #Config.MILESTONES then
			notify(player, "Your piggy is FULL. It stops earning until you spend some!", "warn")
		end
	end
end

-- ============================================================
-- OFFLINE ACCRUAL
-- ============================================================

-- Computed from the stored lastSave timestamp, never from anything the
-- client reports, and clamped so a long absence can't mint a fortune.
--
-- Fills up to capacity and never past it: a pig that came home from a
-- robbery overfull earns nothing offline, exactly as it earns nothing live.
function EconomyService.applyOfflineIncome(player: Player): number
	local data = DataService.get(player)
	if not data then
		return 0
	end

	Config.growAcorns(data, os.time())
	Config.expireGroundAcorns(data, os.time())
	local elapsed = math.max(0, os.time() - data.lastSave)
	local counted = math.min(elapsed, Config.OFFLINE_CAP_SECONDS)
	if counted <= 0 then
		return 0
	end

	local rate = Config.getIncomeRate(data.incomeLevel, data.rebirths)
	local capacity = Config.getCapacity(data.capacityLevel)
	local before = data.coins

	data.coins = math.max(before, math.min(capacity, before + rate * counted))

	return math.floor(data.coins - before)
end

-- ============================================================
-- ACTIONS
-- ============================================================

function EconomyService.purchase(player: Player, track: string)
	if throttled(player, "purchase") then
		return
	end

	local data = DataService.get(player)
	if not data then
		return
	end

	local cost: number, level: number, maxLevel: number
	if track == "income" then
		level, maxLevel = data.incomeLevel, Config.maxLevel(data.rebirths)
		cost = Config.getIncomeCost(level)
	elseif track == "capacity" then
		level, maxLevel = data.capacityLevel, Config.maxLevel(data.rebirths)
		cost = Config.getCapacityCost(level)
	else
		return -- unknown track; ignore rather than error on client input
	end

	if level >= maxLevel then
		notify(player, "Already at max level.", "warn")
		return
	end

	if data.coins < cost then
		notify(player, ("Need %s more coins"):format(EconomyService.format(cost - data.coins)), "warn")
		return
	end

	data.coins -= cost
	if track == "income" then
		data.incomeLevel += 1
		notify(player, ("Income upgraded to level %d"):format(data.incomeLevel), "good")
	else
		data.capacityLevel += 1
		notify(player, ("Piggy bank size upgraded to level %d"):format(data.capacityLevel), "good")
	end

	refreshPlot(player)
	pushState(player)
end

-- ============================================================
-- FORMATTING
-- ============================================================

-- ONE LADDER, IN CONFIG, because there were two of these and a third was
-- about to be written. ClientMain kept a byte-identical copy and ChestService
-- needs one on a service that can require neither -- and Config requires
-- nothing while both ends already read it, which makes it the only home where
-- another copy is not the cheaper option. Kept as a name here because 40-odd
-- call sites read it.
EconomyService.format = Config.formatCoins

-- ============================================================
-- LIFECYCLE
-- ============================================================

function EconomyService.onPlayerReady(player: Player)
	local gained = EconomyService.applyOfflineIncome(player)

	-- Set the milestone baseline silently. A player rejoining to a full pig
	-- should not get a fanfare fired at them before the HUD has even drawn --
	-- the offline-income toast below already tells them what happened.
	local data = DataService.get(player)
	if data then
		local ratio = data.coins / Config.getCapacity(data.capacityLevel)
		local reached = 0
		for index, threshold in ipairs(Config.MILESTONES) do
			if ratio >= threshold then
				reached = index
			end
		end
		milestoneReached[player] = reached
	end

	refreshPlot(player)
	pushState(player)

	if gained > 0 then
		notify(player, ("Your piggy bank earned %s coins while you were away"):format(EconomyService.format(gained)), "money")
	end
end

function EconomyService.start()
	Remotes.get("PurchaseRequest").OnServerEvent:Connect(function(player, track)
		if type(track) ~= "string" then
			return
		end
		EconomyService.purchase(player, track)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		milestoneReached[player] = nil
		lastShown[player] = nil
		lastAcornsShown[player] = nil
	end)

	-- Accrual loop. Uses elapsed wall time rather than assuming the tick
	-- landed exactly on schedule, so a laggy server doesn't lose income.
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(TICK_RATE)
			local now = os.clock()
			local delta = now - last
			last = now

			for _, player in ipairs(Players:GetPlayers()) do
				local data = DataService.get(player)
				if data then
					local grown = Config.growAcorns(data, os.time())
					local expired = Config.expireGroundAcorns(data, os.time())
					local capacity = Config.getCapacity(data.capacityLevel)
					if data.coins < capacity then
						-- A daily boost multiplies the live drip only. It deliberately
						-- does not touch offline accrual: a boost is for playing, and
						-- one that ticks while you are logged off is just a worse coin
						-- reward with extra steps.
						local rate = Config.getIncomeRate(
							data.incomeLevel, data.rebirths, SocialService.getFriendBonus(player))
						rate *= DailyService.getMultiplier(player)
						data.coins = math.min(capacity, data.coins + rate * delta)
					end

					-- Repaint and push whenever the whole-coin balance moved, whoever
					-- moved it. See `lastShown`.
					local whole = math.floor(data.coins)
					if whole ~= lastShown[player] then
						local plot = PlotService.getPlot(player)
						if plot then
							local newCoins = PlotService.updatePile(plot, data.coins, capacity)
							if newCoins > 0 then
								PlotService.playCoinDrop(plot)
							end
							checkMilestones(player, plot, data.coins / capacity)
						end
						pushState(player)
					elseif grown > 0 or expired or math.floor(data.loot) ~= lastAcornsShown[player] then
						-- A full pig still grows Acorns, and any other wallet change
						-- must repaint storage/tree even when coins did not move.
						pushState(player)
					end
					if grown > 0 then
						local plot = PlotService.getPlot(player)
						if plot then Remotes.get("AcornGrown"):FireAllClients(plot.model, grown) end
					end
				end
			end
		end
	end)
end

return EconomyService
