--!strict
--[[
	AdminPanel

	The F2 dev console, built from a declarative menu.

	DRIVEN BY A TABLE, NOT BY EIGHTEEN CALLS. The old panel was a flat list of
	hardcoded `button(...)` lines, which is fine at eight and unreadable at
	eighteen -- and every new feature added one more to the bottom regardless
	of what it related to. `MENU` below is the whole panel: adding a command is
	one row, adding a category is one table, and neither touches a line of the
	building code.

	A MODULE, NOT A SECTION OF ClientMain. That chunk is at Luau's 200-local
	ceiling and a panel with a dropdown, collapsible categories and per-row
	state is exactly the kind of thing that overflows it -- the last section to
	do that took down the ENTIRE HUD, because the chunk never compiles and
	nothing gets built. A function body gets its own register file.

	IT SCROLLS, AND THAT IS NOT COSMETIC. This project has already shipped a
	tab rail that silently ate two tabs: a UIListLayout does not clip and does
	not error, it just keeps drawing past the edge, so the panel looked like a
	deliberate six-tab shop. A fixed-height panel with a growing menu has the
	identical failure mode, and a ScrollingFrame cannot have the bug at any
	panel size or command count.

	THE PANEL IS CONVENIENCE ONLY. `AdminRequest` exists for every player
	whether or not their panel was built, so nothing here is a security
	control -- the allowlist check at the top of AdminService's one handler is.
	In particular the player dropdown does not grant anything: it sends a
	userId, and the server resolves and re-authorises before acting.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)

local AdminPanel = {}

local BG = Theme.SLAB_DEEP
local ROW = Theme.SLAB
local ROW_HOT = Color3.fromRGB(78, 64, 54)
local HEAD = Color3.fromRGB(40, 33, 28)
local GOLD = Theme.GOLD
local TEXT = Theme.PAPER
local MUTED = Color3.fromRGB(160, 142, 126)
local DANGER = Theme.STOP_INK

-- ============================================================
-- THE MENU
-- ============================================================
--
-- `cmd` is the AdminService command; `a` and `b` are its arguments. `danger`
-- paints a row red. That is the entire vocabulary -- anything a row needs to
-- say that is not in this list is a sign the panel is growing a second job.
--
-- Grouped by WHAT YOU ARE TESTING rather than by which service owns it, which
-- is the same split the shop's four tabs already use: somebody reaching for
-- this panel knows what they want to happen, not which file it lives in.
type Row = { label: string, cmd: string, a: any?, b: any?, danger: boolean? }
type Group = { name: string, note: string?, rows: { Row } }

local MENU: { Group } = {
	{
		name = "Events",
		note = "Each borrows the street without touching the schedule.",
		rows = {
			{ label = "ALIEN INVASION now", cmd = "event", a = "raid" },
			{ label = "RUSH HOUR now", cmd = "event", a = "rush" },
			{ label = "What is running?", cmd = "eventstate" },
		},
	},
	{
		name = "Police",
		note = "Both toggles. The server answers with what it actually did.",
		rows = {
			{ label = "Toggle patrol", cmd = "police" },
			{ label = "Toggle MOST WANTED", cmd = "mostwanted" },
			{ label = "Arrest (bail on 2K)", cmd = "bust", a = 2000 },
			{ label = "Patrol status", cmd = "policestate" },
		},
	},
	{
		name = "Guard dog",
		rows = {
			{ label = "Titan (Lv3)", cmd = "upgrade", a = "dog", b = 3 },
			{ label = "No dog (Lv0)", cmd = "upgrade", a = "dog", b = 0 },
			{ label = "Send to bed (20s)", cmd = "dognap", a = 20 },
			{ label = "Dog status", cmd = "dogstate" },
		},
	},
	{
		name = "Money",
		rows = {
			{ label = "+100K coins", cmd = "coins", a = 100000 },
			{ label = "+10M coins", cmd = "coins", a = 10000000 },
			{ label = "Fill piggy bank", cmd = "fill" },
			{ label = "Max all upgrades", cmd = "maxupgrades" },
			{ label = "Set 5 rebirths", cmd = "rebirths", a = 5 },
		},
	},
	{
		name = "Collection",
		rows = {
			{ label = "Unlock skins / effects / houses / gear", cmd = "unlockall" },
			{ label = "+50 loot", cmd = "loot", a = 50 },
			{ label = "Open Piggy Classics x5", cmd = "chest", a = "classics", b = 5 },
			{ label = "Open Dress-Up Crate x5", cmd = "chest", a = "gear", b = 5 },
			{ label = "Open Alien Cache x3", cmd = "chest", a = "alien", b = 3 },
			{ label = "+3 spares of each tier", cmd = "spares", a = 3 },
			{ label = "Dump animations for upload", cmd = "animdump" },
			{ label = "Combine 3 common -> Classics", cmd = "combine", a = "common", b = "classics" },
			{ label = "Empty accessory collection", cmd = "cleargear" },
		},
	},
	{
		name = "Heist",
		rows = {
			{ label = "Open season (shield + cooldowns)", cmd = "shield" },
		},
	},
	{
		name = "Danger",
		note = "Wipe always applies to YOU, whatever the dropdown says.",
		rows = {
			{ label = "WIPE MY SAVE", cmd = "reset", danger = true },
		},
	},
}

-- ============================================================
-- BUILD
-- ============================================================

local function corner(inst: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = inst
end

local function label(parent: Instance, text: string, size: UDim2, font: Enum.Font,
	textSize: number, colour: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = size
	l.BackgroundTransparency = 1
	l.Font = font
	l.TextSize = textSize
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextColor3 = colour
	l.Text = text
	l.Parent = parent
	return l
end

-- Builds the panel and returns it. `fire(command, targetUserId, a, b)` is
-- handed in rather than the remote itself, so this module knows nothing about
-- Remotes and can be driven by a test harness.
function AdminPanel.build(parent: Instance, fire: (string, number?, any, any) -> ()): Frame
	local panel = Instance.new("Frame")
	panel.Name = "AdminPanel"
	panel.Size = UDim2.new(0, 330, 0, 560)
	panel.Position = UDim2.new(0, 16, 0.5, -280)
	panel.BackgroundColor3 = BG
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.ZIndex = 40
	panel.Parent = parent
	corner(panel, 12)

	label(panel, "ADMIN  [F2]", UDim2.new(1, -24, 0, 22), Enum.Font.FredokaOne, 18, GOLD)
		.Position = UDim2.new(0, 12, 0, 10)

	-- ---------- the target dropdown ----------
	--
	-- WHO THE NEXT BUTTON APPLIES TO. It sends a USERID and never a name or a
	-- player object: the server looks the id up in the live player list, so a
	-- selection that has since left resolves to nobody and is refused rather
	-- than silently landing on whoever now matches.
	local selected: Player = Players.LocalPlayer

	label(panel, "ACTING ON", UDim2.new(1, -24, 0, 14), Enum.Font.GothamBold, 10, MUTED)
		.Position = UDim2.new(0, 12, 0, 38)

	local pick = Instance.new("TextButton")
	pick.Name = "TargetPick"
	pick.Size = UDim2.new(1, -24, 0, 30)
	pick.Position = UDim2.new(0, 12, 0, 54)
	pick.BackgroundColor3 = HEAD
	pick.BorderSizePixel = 0
	pick.Font = Enum.Font.GothamBold
	pick.TextSize = 13
	pick.TextColor3 = TEXT
	pick.ZIndex = 41
	pick.Parent = panel
	corner(pick, 8)

	-- SIZED TO ITS CONTENTS, capped. A fixed height is 132 pixels of empty
	-- box in a solo test session and it floats over whichever category sits
	-- under it, hiding the thing you just expanded. Capped as well as sized,
	-- because a twelve-player server would otherwise open a dropdown taller
	-- than the panel.
	local ROW_H, MENU_MAX = 28, 132
	local menu = Instance.new("ScrollingFrame")
	menu.Name = "TargetMenu"
	menu.Size = UDim2.new(1, -24, 0, ROW_H)
	menu.Position = UDim2.new(0, 12, 0, 86)
	menu.BackgroundColor3 = Theme.SLAB_DEEP
	menu.BorderSizePixel = 0
	menu.Visible = false
	menu.ZIndex = 45
	menu.ScrollBarThickness = 4
	menu.AutomaticCanvasSize = Enum.AutomaticSize.Y
	menu.CanvasSize = UDim2.new()
	menu.Parent = panel
	corner(menu, 8)
	local menuList = Instance.new("UIListLayout")
	menuList.Padding = UDim.new(0, 2)
	menuList.SortOrder = Enum.SortOrder.LayoutOrder
	menuList.Parent = menu

	local function setSelected(p: Player)
		selected = p
		pick.Text = ("%s  %s"):format(
			if p == Players.LocalPlayer then "(you)" else p.DisplayName,
			utf8.char(0x25BC))
	end

	-- REBUILT ON EVERY OPEN, never cached. Players join and leave constantly
	-- in a test session, and a dropdown listing somebody who left is a button
	-- that fails with "that player has left" for no visible reason.
	local function refreshMenu()
		for _, child in ipairs(menu:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local roster = Players:GetPlayers()
		menu.Size = UDim2.new(1, -24, 0, math.min(#roster * (ROW_H + 2) + 4, MENU_MAX))

		local order = 0
		for _, p in ipairs(roster) do
			order += 1
			local row = Instance.new("TextButton")
			row.Size = UDim2.new(1, -4, 0, ROW_H)
			row.LayoutOrder = order
			row.BackgroundColor3 = if p == selected then ROW_HOT else ROW
			row.BorderSizePixel = 0
			row.Font = Enum.Font.Gotham
			row.TextSize = 12
			row.TextColor3 = TEXT
			row.Text = if p == Players.LocalPlayer
				then ("%s  (you)"):format(p.DisplayName) else p.DisplayName
			row.ZIndex = 46
			row.Parent = menu
			corner(row, 6)
			row.Activated:Connect(function()
				setSelected(p)
				menu.Visible = false
			end)
		end
	end

	pick.Activated:Connect(function()
		menu.Visible = not menu.Visible
		if menu.Visible then
			refreshMenu()
		end
	end)

	-- A player who leaves must not stay selected: the next press would be
	-- refused by the server for a reason nothing on screen explains.
	Players.PlayerRemoving:Connect(function(p)
		if p == selected then
			setSelected(Players.LocalPlayer)
		end
		if menu.Visible then
			refreshMenu()
		end
	end)
	setSelected(Players.LocalPlayer)

	-- ---------- the scrolling body ----------
	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.Size = UDim2.new(1, -24, 1, -104)
	body.Position = UDim2.new(0, 12, 0, 94)
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 5
	body.ScrollBarImageColor3 = Theme.MUTED
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.ZIndex = 40
	body.Parent = panel

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 5)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = body

	local order = 0
	for _, group in ipairs(MENU) do
		order += 1

		local head = Instance.new("TextButton")
		head.Size = UDim2.new(1, -6, 0, 28)
		head.LayoutOrder = order
		head.BackgroundColor3 = HEAD
		head.BorderSizePixel = 0
		head.Font = Enum.Font.GothamBold
		head.TextSize = 13
		head.TextColor3 = GOLD
		head.TextXAlignment = Enum.TextXAlignment.Left
		head.Text = ""
		head.Name = "Head_" .. group.name
		head.ZIndex = 41
		head.Parent = body
		corner(head, 8)
		local headPad = Instance.new("UIPadding")
		headPad.PaddingLeft = UDim.new(0, 10)
		headPad.Parent = head

		-- COLLAPSED BY DEFAULT, all of them. Seven groups expanded is a longer
		-- list than the flat panel this replaced, which would make the
		-- reorganisation a net loss.
		local open = false
		local holder = Instance.new("Frame")
		holder.Size = UDim2.new(1, -6, 0, 0)
		holder.AutomaticSize = Enum.AutomaticSize.Y
		holder.BackgroundTransparency = 1
		holder.LayoutOrder = order
		holder.Visible = false
		holder.Name = "Group_" .. group.name
		holder.ZIndex = 40
		holder.Parent = body

		local inner = Instance.new("UIListLayout")
		inner.Padding = UDim.new(0, 4)
		inner.SortOrder = Enum.SortOrder.LayoutOrder
		inner.Parent = holder

		local function paint()
			head.Text = ("%s  %s"):format(
				if open then utf8.char(0x25BC) else utf8.char(0x25B6), group.name)
		end
		head.Activated:Connect(function()
			open = not open
			holder.Visible = open
			paint()
		end)
		paint()

		local sub = 0
		if group.note then
			sub += 1
			local n = label(holder, group.note, UDim2.new(1, -8, 0, 26),
				Enum.Font.Gotham, 10, MUTED)
			n.LayoutOrder = sub
			n.TextWrapped = true
			n.ZIndex = 40
		end

		for _, row in ipairs(group.rows) do
			sub += 1
			local b = Instance.new("TextButton")
			b.Size = UDim2.new(1, -8, 0, 28)
			b.LayoutOrder = sub
			b.BackgroundColor3 = if row.danger then DANGER else ROW
			b.BorderSizePixel = 0
			b.Font = Enum.Font.GothamBold
			b.TextSize = 12
			b.TextColor3 = TEXT
			b.Text = row.label
			b.Name = "Row_" .. row.cmd
			b.ZIndex = 41
			b.Parent = holder
			corner(b, 7)
			b.Activated:Connect(function()
				-- The selection is read AT PRESS TIME, not captured when the
				-- row was built: the dropdown changes constantly and a
				-- captured target would silently act on whoever was selected
				-- when the panel was first opened.
				fire(row.cmd, selected.UserId, row.a, row.b)
			end)
		end

		order += 1
	end

	local hint = label(body, "Every action is re-checked and logged server-side.",
		UDim2.new(1, -6, 0, 30), Enum.Font.Gotham, 10, Color3.fromRGB(160, 142, 126))
	hint.LayoutOrder = 999
	hint.TextWrapped = true

	return panel
end

return AdminPanel
