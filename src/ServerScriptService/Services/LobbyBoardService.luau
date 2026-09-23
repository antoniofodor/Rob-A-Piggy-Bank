--!strict
--[[
	LobbyBoardService -- THE STREET LEADERBOARD.

	Every player in this server, with three LIFETIME numbers that follow the
	account across servers: total cash (the one balance, `data.coins` -- the
	pig is the wallet), piggies robbed (`data.piggiesStolen`, counted at the
	secure and never at the grab) and rebirths.

	IT IS A DIFFERENT CLAIM FROM BOTH PHYSICAL BOARDS, and that is why it is
	its own service rather than a fourth thing `SocialService` refreshes. The
	portrait poster is ONE person, RIGHT NOW; the landscape board is TOP
	THIEVES THIS WEEK, a ladder that resets on Sunday. This is neither: it is
	who is standing on the street this minute and what each of them has done
	over their whole account. Three boards, three questions, and the header
	on the client says which one this is.

	READ FROM DataService'S LIVE SESSION DATA, never from a second copy. The
	balance changes forty times a minute on an idle pig and a snapshot held
	here would be stale before it was pushed; the cache IS the truth, and
	`DataService.get` is the one door to it.

	PUSHED TO EVERYBODY ON THE LEADERBOARD'S OWN CADENCE (`Config.LEADERBOARD_REFRESH`)
	plus once as a player lands and once as one leaves, because a board that
	still lists somebody who left a minute ago reads as broken. A broadcast
	rather than a per-client push, because unlike `WantedState` nothing in
	this payload is about the recipient -- every row is the same on every
	screen, and the client highlights its own row itself.

	`snapshot` IS PURE so the suite can hold the shape and the order without a
	Players service: rows for players with a loaded save only (a player mid-load
	has nothing honest to print), sorted by cash, ties broken by piggies robbed,
	then rebirths, then name -- so two fresh joiners never swap places from one
	push to the next.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local DataService = require(script.Parent.DataService)

local LobbyBoardService = {}

export type Row = {
	name: string,
	userId: number,
	coins: number,
	piggiesStolen: number,
	rebirths: number,
}

-- A finite, non-negative integer or zero. The counter is normalised the same
-- way on load, so this is belt and braces against a save that has not been
-- through reconcile -- and it is what stops a NaN sorting a row to the top.
local function whole(value: any): number
	local n = tonumber(value)
	if n == nil or n ~= n or math.abs(n) == math.huge then
		return 0
	end
	return math.max(0, math.floor(n))
end

local function rowFor(player: Player, data: any): Row
	return {
		name = player.DisplayName,
		userId = player.UserId,
		coins = whole(data.coins),
		piggiesStolen = whole(data.piggiesStolen),
		rebirths = whole(data.rebirths),
	}
end

-- Pure: takes the players and a way to read their saves, hands back the rows
-- in board order. `get` is `DataService.get` live and a table lookup in tests.
function LobbyBoardService.snapshot(players: { Player }, get: (Player) -> any?): { Row }
	local rows: { Row } = {}
	for _, player in ipairs(players) do
		local data = get(player)
		if data then
			table.insert(rows, rowFor(player, data))
		end
	end
	table.sort(rows, function(a: Row, b: Row): boolean
		if a.coins ~= b.coins then
			return a.coins > b.coins
		end
		if a.piggiesStolen ~= b.piggiesStolen then
			return a.piggiesStolen > b.piggiesStolen
		end
		if a.rebirths ~= b.rebirths then
			return a.rebirths > b.rebirths
		end
		return a.name < b.name
	end)
	return rows
end

function LobbyBoardService.push()
	local rows = LobbyBoardService.snapshot(Players:GetPlayers(), DataService.get)
	Remotes.get("LobbyBoard"):FireAllClients(rows)
end

function LobbyBoardService.start()
	-- ON JOIN, ONCE THE SAVE HAS LANDED. `Main` loads the save in its own
	-- PlayerAdded handler and this one may run first, so a push fired on the
	-- signal itself would list everybody except the person who just arrived.
	-- Polled rather than hooked, because DataService has no "loaded" signal
	-- and the cadence loop below is the guarantee either way.
	Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(function()
			local deadline = os.clock() + 15
			while player.Parent and not DataService.get(player) and os.clock() < deadline do
				task.wait(0.25)
			end
			LobbyBoardService.push()
		end)
	end)

	-- ON LEAVE, DEFERRED A FRAME so `Players:GetPlayers()` no longer lists
	-- the player who is going.
	Players.PlayerRemoving:Connect(function()
		task.defer(LobbyBoardService.push)
	end)

	task.spawn(function()
		while true do
			task.wait(Config.LEADERBOARD_REFRESH)
			LobbyBoardService.push()
		end
	end)
end

return LobbyBoardService
