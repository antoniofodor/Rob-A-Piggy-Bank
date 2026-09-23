--!strict
--[[
	LobbyBoard -- THE STREET LEADERBOARD, on screen.

	Everybody in this server, ranked by cash, with the two other numbers an
	account carries across servers: piggies robbed and rebirths. A toggled
	panel, not a standing readout -- it is looked at, not glanced at, which
	is why it sits in the middle of the screen rather than in a column.

	WHAT IT IS NOT. The portrait poster on the street is ONE person, RIGHT
	NOW; the landscape board is TOP THIEVES THIS WEEK. Both physical boards
	make a claim about a window of time, and this one makes a claim about
	LIFETIME -- which is why the header says so in as many words. Three
	boards that read the same would be three answers to one question.

	NOT A FULL-SCREEN MENU, AND IT DOES NOT TAKE THE MUTUAL-EXCLUSION THE
	SHOP AND THE BAG KEEP. That rule exists because two panels of the same
	size in the same place leave the loser invisible underneath with its
	close button unreachable. This is 570 x 380 in the centre and every menu
	is 0.94 of the screen at `Theme.MENU_Z`, so the relation is one-way: a
	menu always covers this. The two duties that follow from that are kept --
	it CLOSES ITSELF when a menu opens (the bag's `BagOpen` attribute, the
	settings' `SettingsOpen`, and the shop through the `DisplayOrder` it
	raises on the ScreenGui), and it REFUSES TO OPEN while one is up, so it
	can never be sitting under a shop with nothing to say it is there. It
	draws one step below `Theme.MENU_Z` so that ordering is by number rather
	than by which frame happened to be built later.

	THE BUTTON IS THE PRIMARY ROUTE and takes the fourth slot in the left menu
	rail, under SHOP -- the rail is top-anchored now, so a tile added at the
	bottom moves nothing a player already knows the position of. Tab is the
	key: the default player list is switched off with `SetCoreGuiEnabled`, so
	the platform's own list key is free and means exactly this. L is the
	spare beside it, because whether Tab arrives unprocessed with the CoreGui
	list disabled is engine behaviour nobody here has measured -- so Tab is
	accepted even when marked processed, unless a TextBox has focus, and L
	is the ordinary binding that needs no such reasoning.

	A MODULE, started from `ClientMain` in one statement holding no local,
	for the reason RobBadge, Wanted and CarryPose are: that chunk is at
	Luau's 200-register ceiling.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local MenuIcons = require(ReplicatedStorage.Shared.MenuIcons)

local LobbyBoard = {}

-- ============================================================
-- GEOMETRY (design pixels; a UIScale fits the whole card to short screens)
-- ============================================================

-- THE COLUMNS, WIDEST PAYLOAD FIRST. Each width was sized against the
-- longest string its cell can hold rather than against how wide it should
-- feel, and the suite re-derives the check: a 16-character display name at
-- 16px FredokaOne, "999.9M" at 16px GothamBold (`Config.formatCoins` never
-- prints more than six characters below a trillion), a five-digit robbery
-- count and a two-digit rebirth count. Numbers are right-aligned so the
-- units line up down the column and a short figure never floats.
LobbyBoard.COLUMNS = {
	{ key = "rank", head = "#", width = 36, align = "Right" },
	{ key = "name", head = "PLAYER", width = 190, align = "Left" },
	{ key = "coins", head = "CASH", width = 104, align = "Right" },
	{ key = "piggies", head = "ROBBED", width = 88, align = "Right" },
	{ key = "rebirths", head = "REBIRTHS", width = 84, align = "Right" },
}
LobbyBoard.PAD = 14
LobbyBoard.GAP = 10
LobbyBoard.TITLE_H = 58
LobbyBoard.HEAD_H = 22
LobbyBoard.ROW_H = 34
LobbyBoard.ROW_TEXT = 16
LobbyBoard.HEAD_TEXT = 11
-- One row per seat in the server: the board never scrolls, because
-- `Config.MAX_PLAYERS` is the most names it can ever hold.
LobbyBoard.ROWS = Config.MAX_PLAYERS

local function totalWidth(): number
	local w = LobbyBoard.PAD * 2 + LobbyBoard.GAP * (#LobbyBoard.COLUMNS - 1)
	for _, column in ipairs(LobbyBoard.COLUMNS) do
		w += column.width
	end
	return w
end
LobbyBoard.WIDTH = totalWidth()
LobbyBoard.HEIGHT = LobbyBoard.PAD * 2 + LobbyBoard.TITLE_H + LobbyBoard.HEAD_H
	+ LobbyBoard.ROWS * LobbyBoard.ROW_H

-- The rebirth mark. There is no star glyph anywhere on the HUD to borrow --
-- the plot sign prints "%d*" and the rebirth button prints the bare count --
-- so this is an emoji, which renders from the colour font at every size
-- and needs no `TextColor3` to carry. It sits in the column head and not in
-- every cell, where eight of them would be a column of stars with numbers
-- beside them.
LobbyBoard.STAR = utf8.char(0x2B50)

-- ============================================================
-- PURE HALF
-- ============================================================

-- What the eight rows print, from the payload the server sent. Pure, so the
-- suite can hold the order, the formatting and the highlight without a
-- ScreenGui. A rank is the index in the server's own order -- the client
-- never re-sorts, because two clients sorting differently is two boards.
function LobbyBoard.rowsFor(payload: any, localUserId: number): { any }
	local rows = {}
	if type(payload) ~= "table" then
		return rows
	end
	for index, entry in ipairs(payload) do
		if index > LobbyBoard.ROWS then
			break
		end
		if type(entry) == "table" then
			table.insert(rows, {
				rank = tostring(index),
				name = tostring(entry.name or ""),
				coins = Config.formatCoins(tonumber(entry.coins) or 0),
				piggies = tostring(math.floor(tonumber(entry.piggiesStolen) or 0)),
				rebirths = tostring(math.floor(tonumber(entry.rebirths) or 0)),
				me = entry.userId == localUserId,
			})
		end
	end
	return rows
end

-- ============================================================
-- THE PANEL
-- ============================================================

local function label(parent: Instance, name: string, text: string, size: number,
	font: Enum.Font, colour: Color3, align: string): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.BorderSizePixel = 0
	t.Font = font
	t.TextSize = size
	t.TextColor3 = colour
	t.Text = text
	-- NEVER `TextScaled` ON A CELL: with it on, "it fits" is guaranteed and
	-- means nothing -- the failure is silent shrinkage. The columns are sized
	-- to their longest payload instead, and the suite checks that.
	t.TextScaled = false
	t.TextTruncate = Enum.TextTruncate.AtEnd
	t.TextXAlignment = (Enum.TextXAlignment :: any)[align]
	t.TextYAlignment = Enum.TextYAlignment.Center
	t.ZIndex = 3
	t.Parent = parent
	return t
end

function LobbyBoard.start(player: Player, gui: ScreenGui, menu: Instance?)
	-- ---- the card -------------------------------------------------------
	local card = Instance.new("Frame")
	card.Name = "LobbyBoard"
	card.Size = UDim2.fromOffset(LobbyBoard.WIDTH, LobbyBoard.HEIGHT)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Visible = false
	card.Active = true
	-- ONE STEP UNDER THE MENU LAYER. Under `ZIndexBehavior.Sibling` two
	-- frames at one ZIndex are ordered by child order, and this is built
	-- thousands of lines after the shop -- so at `MENU_Z` it would draw OVER
	-- an open shop. Below it, a menu covers this by number.
	card.ZIndex = Theme.MENU_Z - 1
	Theme.card(card, 18)
	card.Parent = gui

	local scale = Instance.new("UIScale")
	scale.Parent = card

	-- ---- the header -----------------------------------------------------
	local title = label(card, "Title", "STREET LEADERBOARD", 24, Theme.FONT, Theme.INK, "Left")
	title.Position = UDim2.fromOffset(LobbyBoard.PAD, LobbyBoard.PAD)
	title.Size = UDim2.new(1, -LobbyBoard.PAD * 2 - 52, 0, 30)

	-- THE CLAIM, IN THE SUBTITLE. "Lifetime" is the word that separates this
	-- from the weekly board on the street, and "in this server" is what
	-- separates it from a global top-hundred nobody here is on.
	local sub = label(card, "Subtitle", "Lifetime totals of everybody in this server", 12,
		Theme.FONT_BODY, Theme.MUTED, "Left")
	sub.Position = UDim2.fromOffset(LobbyBoard.PAD, LobbyBoard.PAD + 32)
	sub.Size = UDim2.new(1, -LobbyBoard.PAD * 2 - 52, 0, 18)

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Text = utf8.char(0x00D7)
	close.Font = Theme.FONT
	close.TextSize = 30
	close.TextColor3 = Theme.PAPER
	close.BackgroundColor3 = Theme.STOP
	close.BorderSizePixel = 0
	close.AutoButtonColor = true
	close.ZIndex = 4
	close.Parent = card
	Theme.corner(close, 22)
	Theme.outline(close)
	Theme.floatClose(close, 44)

	-- ---- the column heads -----------------------------------------------
	local headTop = LobbyBoard.PAD + LobbyBoard.TITLE_H
	local x = LobbyBoard.PAD
	for _, column in ipairs(LobbyBoard.COLUMNS) do
		local head = label(card, "Head_" .. column.key, column.head, LobbyBoard.HEAD_TEXT,
			Theme.FONT_BODY, Theme.MUTED, column.align)
		head.Position = UDim2.fromOffset(x, headTop)
		head.Size = UDim2.fromOffset(column.width, LobbyBoard.HEAD_H)
		if column.key == "coins" then
			-- GOLD ON THE OBJECT, NEVER UNDER IT: a drawn coin marks the money
			-- column and the figures print in `GOLD_INK`, the only gold text
			-- that reads on paper (raw gold measures 1.42 there).
			local coin = Theme.coin(head, 14, "CoinMark")
			coin.AnchorPoint = Vector2.new(0, 0.5)
			coin.Position = UDim2.new(0, 0, 0.5, 0)
			coin.ZIndex = 4
		elseif column.key == "rebirths" then
			local star = label(head, "Star", LobbyBoard.STAR, 12, Theme.FONT_BODY, Theme.INK, "Left")
			star.Position = UDim2.fromOffset(0, 0)
			star.Size = UDim2.fromOffset(16, LobbyBoard.HEAD_H)
		end
		x += column.width + LobbyBoard.GAP
	end

	-- ---- the rows -------------------------------------------------------
	local rowTop = headTop + LobbyBoard.HEAD_H
	local rows: { { frame: Frame, cells: { [string]: TextLabel } } } = {}
	for i = 1, LobbyBoard.ROWS do
		local frame = Instance.new("Frame")
		frame.Name = "Row" .. i
		frame.Position = UDim2.fromOffset(LobbyBoard.PAD, rowTop + (i - 1) * LobbyBoard.ROW_H)
		frame.Size = UDim2.fromOffset(LobbyBoard.WIDTH - LobbyBoard.PAD * 2, LobbyBoard.ROW_H)
		frame.BorderSizePixel = 0
		-- Alternate stripes one step under paper, the way the leaderboard on
		-- the street separates its rows.
		frame.BackgroundColor3 = if i % 2 == 0 then Theme.PAPER_DEEP else Theme.PAPER
		frame.BackgroundTransparency = if i % 2 == 0 then 0 else 1
		frame.ZIndex = 2
		frame.Visible = false
		frame.Parent = card
		Theme.corner(frame, 8)

		local cells: { [string]: TextLabel } = {}
		local cx = 0
		for _, column in ipairs(LobbyBoard.COLUMNS) do
			local colour = if column.key == "coins" then Theme.GOLD_INK else Theme.INK
			local font = if column.key == "name" then Theme.FONT else Theme.FONT_BODY
			local cell = label(frame, column.key, "", LobbyBoard.ROW_TEXT, font, colour, column.align)
			cell.Position = UDim2.fromOffset(cx, 0)
			cell.Size = UDim2.fromOffset(column.width, LobbyBoard.ROW_H)
			cells[column.key] = cell
			cx += column.width + LobbyBoard.GAP
		end
		rows[i] = { frame = frame, cells = cells }
	end

	local empty = label(card, "Empty", "Nobody on the street yet.", 14, Theme.FONT_BODY, Theme.MUTED, "Center")
	empty.Position = UDim2.fromOffset(LobbyBoard.PAD, rowTop)
	empty.Size = UDim2.new(1, -LobbyBoard.PAD * 2, 0, LobbyBoard.ROW_H * 2)

	-- ---- painting -------------------------------------------------------
	local latest: any = nil
	local function paint()
		local shown = LobbyBoard.rowsFor(latest, player.UserId)
		empty.Visible = #shown == 0
		for i, row in ipairs(rows) do
			local entry = shown[i]
			row.frame.Visible = entry ~= nil
			if entry then
				for key, cell in pairs(row.cells) do
					cell.Text = entry[key]
				end
				-- THE READER'S OWN ROW IS THE ONE HIGHLIGHT, and it is a
				-- ground rather than a colour on the text: pig pink lifted
				-- most of the way to paper, with a gold edge, so the row is
				-- found at a glance and every cell on it still prints in the
				-- same ink as its neighbours.
				if entry.me then
					row.frame.BackgroundTransparency = 0
					row.frame.BackgroundColor3 = Theme.PIG:Lerp(Theme.PAPER, 0.55)
					Theme.outline(row.frame, Theme.OUTLINE_THIN, Theme.GOLD_DEEP)
				else
					row.frame.BackgroundTransparency = if i % 2 == 0 then 0 else 1
					row.frame.BackgroundColor3 = Theme.PAPER_DEEP
					local stroke = row.frame:FindFirstChildOfClass("UIStroke")
					if stroke then
						stroke:Destroy()
					end
				end
			end
		end
	end

	Remotes.get("LobbyBoard").OnClientEvent:Connect(function(payload: any)
		latest = payload
		if card.Visible then
			paint()
		end
	end)

	-- ---- fitting --------------------------------------------------------
	-- The whole card scales as one thing on a short screen -- a phone held
	-- sideways gives 414 pixels against a 380-tall design -- so there is one
	-- layout and no second set of offsets to drift. 24 pixels of margin on
	-- each axis is what the shop's own scale leaves.
	local function fit()
		local view = gui.AbsoluteSize
		if view.X <= 0 or view.Y <= 0 then
			return
		end
		scale.Scale = math.min(1, (view.X - 24) / LobbyBoard.WIDTH, (view.Y - 24) / LobbyBoard.HEIGHT)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()

	-- ---- open and close -------------------------------------------------
	-- The shop raises the ScreenGui's `DisplayOrder` while it is open and
	-- puts it back on close; the bag and settings publish attributes. Those
	-- three are every menu there is, and none of them can be named from here.
	local baseOrder = gui.DisplayOrder
	local function menuOpen(): boolean
		return gui:GetAttribute("BagOpen") == true
			or gui:GetAttribute("SettingsOpen") == true
			or gui.DisplayOrder ~= baseOrder
	end

	local function setOpen(open: boolean)
		if open and menuOpen() then
			return
		end
		gui:SetAttribute("BoardOpen", open)
	end

	-- THE ATTRIBUTE IS THE STATE AND THE PANEL FOLLOWS IT, the call every
	-- menu here makes, so a probe or a later module can read it without a
	-- handle on this frame.
	gui:GetAttributeChangedSignal("BoardOpen"):Connect(function()
		local open = gui:GetAttribute("BoardOpen") == true
		if open then
			paint()
		end
		card.Visible = open
	end)

	for _, name in { "BagOpen", "SettingsOpen" } do
		gui:GetAttributeChangedSignal(name):Connect(function()
			if gui:GetAttribute(name) then
				setOpen(false)
			end
		end)
	end
	gui:GetPropertyChangedSignal("DisplayOrder"):Connect(function()
		if gui.DisplayOrder ~= baseOrder then
			setOpen(false)
		end
	end)

	close.Activated:Connect(function()
		setOpen(false)
	end)

	-- ---- the button -----------------------------------------------------
	-- The fourth tile in the left menu rail, drawn by the same builder as
	-- the three above it so the four read as a set. `HUDLayout.bindMenu`
	-- sizes the rail by its tiles, so adding one here grows the rail rather
	-- than drawing past its edge.
	if menu then
		-- 66 x 64 like the three above it: the rail's own UIScale sizes all
		-- four together, so the design size is the same on every tile.
		local toggle = MenuIcons.makeButton("BoardToggle", "TROPHY", "BOARD",
			UDim2.fromOffset(66, 64), menu)
		-- UNDER SHOP. The rail is top-anchored, so the bottom is the one slot
		-- that moves nothing a player already knows the position of.
		toggle.LayoutOrder = 4
		toggle.Activated:Connect(function()
			-- Toggled off the attribute rather than off `Visible`: the
			-- attribute-changed signal is deferred, so the frame lags a
			-- press by a frame and reading it here reads the old state.
			setOpen(gui:GetAttribute("BoardOpen") ~= true)
		end)
	end

	-- ---- the keys -------------------------------------------------------
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if input.KeyCode == Enum.KeyCode.Tab then
			-- Accepted even when marked processed, unless somebody is
			-- typing: with the default player list off nothing else on the
			-- platform claims Tab, and whether the CoreGui still stamps it
			-- processed in that state has not been measured here.
			if processed and UserInputService:GetFocusedTextBox() ~= nil then
				return
			end
			setOpen(gui:GetAttribute("BoardOpen") ~= true)
		elseif processed then
			return
		elseif input.KeyCode == Enum.KeyCode.L then
			setOpen(gui:GetAttribute("BoardOpen") ~= true)
		elseif input.KeyCode == Enum.KeyCode.Escape and gui:GetAttribute("BoardOpen") == true then
			setOpen(false)
		end
	end)
end

return LobbyBoard
