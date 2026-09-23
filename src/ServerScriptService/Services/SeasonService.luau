--!strict
--[[
	SeasonService

	THE NEMESIS LEDGER, AND THE SEASON CLOCK IT IS KEYED TO.

	This file used to carry two things: the SEASON LADDER (rank, ten tiers,
	rewards, an OrderedDataStore board and a chip on the plot sign) and the
	nemesis ledger. The ladder ranked ACORNS EARNED and nothing else ever fed
	it, so it retired with the acorn currency -- a board that counted zero for
	everybody forever is the broken-feature shape this project refuses
	everywhere else, and `docs/PIGGY-COLLECTION-PLAN.md` section 7 calls for
	the same retirement.

	WHAT SURVIVED, AND WHY EACH PIECE IS STILL HERE:

	  * THE NEMESIS LEDGER (5.1): who has robbed this player most this season
	    window, twenty rows, the smallest dropped first, shown on the plot
	    sign. It is fed by ROBBERIES and has never had anything to do with
	    acorns.
	  * THE SEASON CLOCK. `Config.seasonIndex` still keys the buy-back claims
	    and the hot-skin window, so the index, its dev-only shift and the lazy
	    rollover all stay. What is gone is what used to be RANKED inside it.

	THE ROLLOVER IS STILL LAZY -- a save carrying an older index is rolled the
	first time anything reads it, the `WEEKLY_HEIST` shape: no job at the
	boundary and nothing to schedule.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)

local SeasonService = {}

local WEEK = 7 * 86400

-- A dev-only clock shift (admin `seasonshift`), so a window can be tested
-- from the far side of a rollover. Server-local and never saved.
local shiftSeconds = 0

local function now(): number
	return os.time() + shiftSeconds
end

function SeasonService.now(): number
	return now()
end

function SeasonService.shiftWeeks(weeks: number)
	shiftSeconds = math.floor(weeks) * WEEK
end

local function currentIndex(): number
	return Config.seasonIndex(now())
end

-- ============================================================
-- STATE
-- ============================================================

local function nemesisState(data: any): any
	local nem = data.nemesis
	if type(nem) ~= "table" then
		nem = { index = 0, rows = {} }
		data.nemesis = nem
	end
	if type(nem.rows) ~= "table" then
		nem.rows = {}
	end
	local index = currentIndex()
	if nem.index ~= index then
		nem.index = index
		nem.rows = {}
	end
	return nem
end

-- The top counterparty, or nil.
function SeasonService.nemesisOf(data: any): (string?, number)
	local nem = nemesisState(data)
	local bestName, bestCount = nil, 0
	for _, row in pairs(nem.rows) do
		if row.count > bestCount then
			bestName, bestCount = row.name, row.count
		end
	end
	return bestName, bestCount
end

-- ============================================================
-- THE SIGN
-- ============================================================

-- ONE LINE NOW RATHER THAN TWO. The season chip that used to sit beside the
-- nemesis line named a tier on the retired ladder; `PlotService.setSeasonChip`
-- went with it.
function SeasonService.refreshSign(player: Player)
	local data = DataService.get(player)
	local plot = PlotService.getPlot(player)
	if not data or not plot then
		return
	end
	local name, count = SeasonService.nemesisOf(data)
	PlotService.setNemesis(plot, name, count)
end

-- A robbery of `victim` by `thief` got home. The victim's ledger remembers.
function SeasonService.recordNemesis(victim: Player, thief: Player)
	if victim == thief then
		return
	end
	local data = DataService.get(victim)
	if not data then
		return
	end
	local nem = nemesisState(data)
	local key = tostring(thief.UserId)
	local row = nem.rows[key]
	if row then
		row.count += 1
		row.name = thief.DisplayName
	else
		local size = 0
		local smallestKey, smallest = nil, math.huge
		for k, r in pairs(nem.rows) do
			size += 1
			if r.count < smallest then
				smallestKey, smallest = k, r.count
			end
		end
		if size >= Config.NEMESIS_ROWS and smallestKey then
			nem.rows[smallestKey] = nil
		end
		nem.rows[key] = { name = thief.DisplayName, count = 1 }
	end
	SeasonService.refreshSign(victim)
end

function SeasonService.onPlayerAdded(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	nemesisState(data)
	SeasonService.refreshSign(player)
end

function SeasonService.status(): string
	local index = currentIndex()
	return ("season index %d, shift %d weeks"):format(index, shiftSeconds // WEEK)
end

-- NOTHING TO START. The board loop that used to live here published season
-- totals to an OrderedDataStore and fetched the ranked pages back; both went
-- with the ladder. The nemesis ledger rides the player's own save and needs
-- no job of its own. Kept as a no-op so `Main` keeps one shape for every
-- service it starts.
function SeasonService.start() end

return SeasonService
