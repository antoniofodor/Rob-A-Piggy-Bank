--!strict
--[[
	LobbyBoardService -- THE STREET LEADERBOARD, on Roblox's own player list.

	Three LIFETIME numbers that follow the account across servers, in a
	`leaderstats` folder per player: piggies robbed (`data.piggiesStolen`,
	counted at the secure and never at the grab), rebirths, and total cash
	(the one balance, `data.coins` -- the pig is the wallet). The platform
	draws them. Nothing here draws anything.

	IT DREW ITS OWN BOARD UNTIL 2026-09-23, AND THE REBUILD HAD CONVERGED ON
	THE PLATFORM'S OWN ANSWER TWICE. `Shared/LobbyBoard` was a card in the
	middle of the screen, then a translucent collapsible board pinned to the
	exact corner Roblox puts the player list in -- and its own header argued
	for that corner on the grounds that a roster there, always visible and one
	click out of the way, is the affordance players already know. That is a
	description of the thing this game had switched off. The designer's call
	was to stop rebuilding it.

	WHAT THAT DELETED, because it is most of why this service is short: no
	remote, no collapse state, no corner tile, no keys, no hide-under-a-menu
	duty, no reserved width to publish, and no push on leave -- the list drops
	a player who has gone without being told.

	THE COLUMN ORDER IS THE SORT, WHICH IS THE ONE THING THE DEFAULT
	COMPONENT DECIDES FOR YOU. The list ranks players by the FIRST stat in
	the folder, so `COLUMNS` is a design statement rather than a layout one.
	Steals leads. That is the better board anyway, by the rule the landscape
	board on the verge already learned: it stopped ranking `coins` because a
	board is an instruction about what is worth doing and that one was
	pointing at idling -- and the custom board sorted by cash for its whole
	life.

	MONEY IS A `StringValue`, WHICH IS WHY IT CANNOT LEAD. It carries
	`Config.formatCoins`, because "2.86m" is what a nine-year-old reads and a
	raw 2,860,000 in a narrow column is not. A formatted string cannot be
	sorted numerically by anything, so the readable column and the sorting
	column cannot be the same column; the two numeric ones are small integers
	and sort honestly.

	READ FROM DataService'S LIVE SESSION DATA, never from a second copy. The
	balance changes forty times a minute on an idle pig and a snapshot held
	here would be stale before it was written; the cache IS the truth, and
	`DataService.get` is the one door to it.

	WRITTEN ON `Config.LEADERBOARD_REFRESH` AND ONLY ON CHANGE. A value set
	every tick whether or not it moved is three replicated property writes a
	second per player to say nothing, so every column is compared first --
	the same call `GuardVisual` makes for its face colours.

	`statsFor` IS PURE so the suite can hold the three columns, their classes
	and their formatting without a Players service or a DataStore.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local LobbyBoardService = {}

-- THE FOLDER'S NAME IS AN INTERFACE WITH NO COMPILER BEHIND IT: the engine
-- looks for exactly this, and a typo is a list with no columns in it and
-- nothing in any log.
LobbyBoardService.FOLDER = "leaderstats"

-- IN THE ORDER THE LIST DRAWS THEM, WHICH IS ALSO THE ORDER IT SORTS BY.
-- See the header: the first entry IS the ranking, so this table may not be
-- reordered for looks.
LobbyBoardService.COLUMNS = {
	{ key = "Steals", class = "IntValue" },
	{ key = "Rebirths", class = "IntValue" },
	{ key = "Money", class = "StringValue" },
}

-- A finite, non-negative integer or zero. The counters are normalised the
-- same way on load, so this is belt and braces against a save that has not
-- been through reconcile -- and it is what stops a NaN reaching a column.
local function whole(value: any): number
	local n = tonumber(value)
	if n == nil or n ~= n or math.abs(n) == math.huge then
		return 0
	end
	return math.max(0, math.floor(n))
end

-- Pure: a save's fields to the three column values, keyed by column name.
function LobbyBoardService.statsFor(data: any): { [string]: any }
	return {
		Steals = whole(data.piggiesStolen),
		Rebirths = whole(data.rebirths),
		Money = Config.formatCoins(whole(data.coins)),
	}
end

-- BUILT ONCE PER PLAYER, IN COLUMN ORDER, AND FOUND BY NAME AFTERWARDS.
-- Column order is child order, so the values have to be parented in the
-- order `COLUMNS` lists them and may never be sorted later.
local function folderFor(player: Player): Folder
	local existing = player:FindFirstChild(LobbyBoardService.FOLDER)
	if existing and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = LobbyBoardService.FOLDER
	for _, column in ipairs(LobbyBoardService.COLUMNS) do
		local value = Instance.new(column.class) :: any
		value.Name = column.key
		value.Parent = folder
	end
	-- Parented LAST, so the list never meets a folder with no columns in it.
	folder.Parent = player
	return folder
end

-- A PLAYER WITH NO SAVE YET IS LEFT ALONE RATHER THAN PUBLISHED AS ZEROES:
-- three zeros beside a real row is a claim about somebody, and the cadence
-- comes back in five seconds.
function LobbyBoardService.publish(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local folder = folderFor(player)
	for key, wanted in LobbyBoardService.statsFor(data) do
		local holder = folder:FindFirstChild(key) :: any
		if holder and holder.Value ~= wanted then
			holder.Value = wanted
		end
	end
end

function LobbyBoardService.push()
	for _, player in ipairs(Players:GetPlayers()) do
		LobbyBoardService.publish(player)
	end
end

function LobbyBoardService.start()
	-- ON JOIN, ONCE THE SAVE HAS LANDED. `Main` loads the save in its own
	-- PlayerAdded handler and this one may run first, so a folder built on
	-- the signal itself would stand three zeros in the list for as long as
	-- the load takes. Polled rather than hooked, because DataService has no
	-- "loaded" signal and the cadence loop below is the guarantee either way.
	Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(function()
			local deadline = os.clock() + 15
			while player.Parent and not DataService.get(player) and os.clock() < deadline do
				task.wait(0.25)
			end
			LobbyBoardService.publish(player)
		end)
	end)

	task.spawn(function()
		while true do
			task.wait(Config.LEADERBOARD_REFRESH)
			LobbyBoardService.push()
		end
	end)
end

return LobbyBoardService
