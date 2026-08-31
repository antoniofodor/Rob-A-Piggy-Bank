--!strict
--[[
	EconomyService

	Coin accrual, offline catch-up, banking, and upgrades.

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

local EconomyService = {}

local TICK_RATE = 1
local MIN_REQUEST_GAP = 0.25

local lastRequest: { [Player]: { [string]: number } } = {}

-- Highest milestone index each player has crossed on their current fill.
-- Resets when they bank, so the celebration replays every cycle rather than
-- firing once per lifetime.
local milestoneReached: { [Player]: number } = {}

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

	Remotes.get("StateUpdate"):FireClient(player, {
		coins = math.floor(data.coins),
		vault = math.floor(data.vault),
		capacity = Config.getCapacity(data.capacityLevel),
		rate = Config.getIncomeRate(data.incomeLevel, data.rebirths, SocialService.getFriendBonus(player)),
		friendBonus = SocialService.getFriendBonus(player),
		incomeLevel = data.incomeLevel,
		capacityLevel = data.capacityLevel,
		incomeCost = Config.getIncomeCost(data.incomeLevel),
		capacityCost = Config.getCapacityCost(data.capacityLevel),
		maxIncome = Config.MAX_INCOME_LEVEL,
		maxCapacity = Config.MAX_CAPACITY_LEVEL,
		rebirths = data.rebirths,
		-- Carried on the per-tick state rather than its own push, so the
		-- rebirth button lights up the instant the threshold is crossed.
		rebirthThreshold = Config.REBIRTH_THRESHOLD,
		rebirthReady = data.coins >= Config.REBIRTH_THRESHOLD,
	})
end

local function notify(player: Player, message: string, kind: string?)
	Remotes.get("Notify"):FireClient(player, message, kind or "info")
end

local function refreshPlot(player: Player)
	local data = DataService.get(player)
	local plot = PlotService.getPlot(player)
	if not data or not plot then
		return
	end
	PlotService.updatePile(plot, data.vault, Config.getCapacity(data.capacityLevel))
	PlotService.updateSign(plot, player.DisplayName, data.rebirths,
		Config.getSkin(data.cosmetics.skin).name, Config.getHouseTier(Config.getShownHouseLevel(data)).name)
end

-- Fires the celebration for every milestone the vault has newly crossed.
-- Only the highest is played, so a big offline catch-up that jumps straight
-- past three thresholds gets one satisfying chime, not three overlapping ones.
local function checkMilestones(player: Player, plot: any, ratio: number)
	local reached = milestoneReached[player] or 0
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
			notify(player, "Your piggy is FULL -- go bank it!", "warn")
		end
	end
end

-- ============================================================
-- OFFLINE ACCRUAL
-- ============================================================

-- Computed from the stored lastSave timestamp, never from anything the
-- client reports, and clamped so a long absence can't mint a fortune.
function EconomyService.applyOfflineIncome(player: Player): number
	local data = DataService.get(player)
	if not data then
		return 0
	end

	local elapsed = math.max(0, os.time() - data.lastSave)
	local counted = math.min(elapsed, Config.OFFLINE_CAP_SECONDS)
	if counted <= 0 then
		return 0
	end

	local rate = Config.getIncomeRate(data.incomeLevel, data.rebirths)
	local capacity = Config.getCapacity(data.capacityLevel)
	local before = data.vault

	data.vault = math.min(capacity, data.vault + rate * counted)

	return math.floor(data.vault - before)
end

-- ============================================================
-- ACTIONS
-- ============================================================

function EconomyService.collect(player: Player)
	if throttled(player, "collect") then
		return
	end

	local data = DataService.get(player)
	if not data then
		return
	end

	local amount = math.floor(data.vault)
	if amount <= 0 then
		notify(player, "Your vault is empty.", "warn")
		return
	end

	data.vault -= amount
	data.coins += amount
	milestoneReached[player] = 0

	local plot = PlotService.getPlot(player)
	if plot then
		PlotService.playBank(plot)
	end

	refreshPlot(player)
	pushState(player)
	notify(player, ("Banked %s coins"):format(EconomyService.format(amount)), "good")
end

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
		level, maxLevel = data.incomeLevel, Config.MAX_INCOME_LEVEL
		cost = Config.getIncomeCost(level)
	elseif track == "capacity" then
		level, maxLevel = data.capacityLevel, Config.MAX_CAPACITY_LEVEL
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
		notify(player, ("Vault size upgraded to level %d"):format(data.capacityLevel), "good")
	end

	refreshPlot(player)
	pushState(player)
end

-- ============================================================
-- FORMATTING
-- ============================================================

local SUFFIXES = { "", "K", "M", "B", "T" }

function EconomyService.format(value: number): string
	local n = math.floor(value)
	local tier = 1
	while n >= 1000 and tier < #SUFFIXES do
		n /= 1000
		tier += 1
	end
	if tier == 1 then
		return tostring(math.floor(n))
	end
	return ("%.1f%s"):format(n, SUFFIXES[tier])
end

-- ============================================================
-- LIFECYCLE
-- ============================================================

function EconomyService.onPlayerReady(player: Player)
	local gained = EconomyService.applyOfflineIncome(player)

	-- Set the milestone baseline silently. A player rejoining to a full vault
	-- should not get a fanfare fired at them before the HUD has even drawn --
	-- the offline-income toast below already tells them what happened.
	local data = DataService.get(player)
	if data then
		local ratio = data.vault / Config.getCapacity(data.capacityLevel)
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
		notify(player, ("Your vault earned %s coins while you were away"):format(EconomyService.format(gained)), "good")
	end
end

function EconomyService.start()
	Remotes.get("CollectRequest").OnServerEvent:Connect(function(player)
		EconomyService.collect(player)
	end)

	Remotes.get("PurchaseRequest").OnServerEvent:Connect(function(player, track)
		if type(track) ~= "string" then
			return
		end
		EconomyService.purchase(player, track)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		milestoneReached[player] = nil
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
					local capacity = Config.getCapacity(data.capacityLevel)
					if data.vault < capacity then
						local rate = Config.getIncomeRate(
							data.incomeLevel, data.rebirths, SocialService.getFriendBonus(player))
						data.vault = math.min(capacity, data.vault + rate * delta)

						local plot = PlotService.getPlot(player)
						if plot then
							local newCoins = PlotService.updatePile(plot, data.vault, capacity)
							if newCoins > 0 then
								PlotService.playCoinDrop(plot)
							end
							checkMilestones(player, plot, data.vault / capacity)
						end
						pushState(player)
					end
				end
			end
		end
	end)
end

return EconomyService
