--!strict
--[[
	CombinePanel -- THE PIGGY PRESS, ON SCREEN.

	Opened by holding the prompt on the machine out on the verge, and by
	nothing else: it is not a tab, not a rail tile and not a key, because it
	is about a PLACE. Walking away does not close it -- the crack panel polls
	its own range and this deliberately does not, because the only thing at
	stake here is a list the server re-checks anyway.

	----------------------------------------------------------------------
	IT DRAWS THE SERVER'S OWN NUMBERS AND KEEPS NONE OF ITS OWN.

	Every spare, its tier, its sell value and whether it is in use arrive in
	`ChestState` -- the push the crates tab and the bag already read -- so
	this connects a third handler to that remote rather than asking for a
	channel of its own. Two implementations of a spare count are two things
	that can disagree, and one of them would be a save.

	The odds come from `Config.COMBINE.odds`, printed, for the reason the
	crate odds are drawn: nothing in a combine is a paid random outcome -- no
	crate here carries a price in any currency and the inputs ARE the price --
	so there is nothing to disclose, and being outside the regulation is the
	reason it costs nothing to comply with the spirit of it.

	----------------------------------------------------------------------
	THE REVEAL IS `Crates`', NOT A SECOND ONE.

	`ChestService.combine` fires `ChestResult`, and `ClientMain` already
	connects that to `Crates.reveal` unconditionally -- so a combine made at
	the machine plays the same reel, on the same SpinWheel, as one made in
	the shop. A second reveal drawn here would be two of them on one result.
	What this does with `ChestResult` is clear the pick, because the spares it
	named are gone.

	----------------------------------------------------------------------
	A MODULE ON ITS OWN ScreenGui, STARTED IN ONE STATEMENT.

	`ClientMain` is at Luau's 200-local ceiling and has been for a year; the
	failure is not this panel, it is the WHOLE HUD, because the chunk never
	compiles and nothing gets built. `require(...).start(player)` holds no
	local at all, which is the call `RobBadge`, `Wanted` and `CarryPose`
	already make.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Theme = require(ReplicatedStorage.Shared.Theme)
local CombineStation = require(ReplicatedStorage.Shared.CombineStation)

local CombinePanel = {}

-- The attribute the HUD publishes while this is up.
--
-- PUBLISHED RATHER THAN KEPT, so the pair can be made mutually exclusive
-- from `ClientMain` with one line and no handle on this frame -- exactly
-- what `BagOpen` is for. This panel already closes ITSELF when a menu opens,
-- so the flag only buys the other direction.
CombinePanel.ATTRIBUTE = "CombineOpen"

-- ============================================================
-- GEOMETRY (design pixels; one UIScale fits the card to short screens)
-- ============================================================
CombinePanel.WIDTH = 660
-- 470 + the hopper strip. The pickers, the grid, the odds line and the foot
-- are all positioned off `KIND_Y`, so the strip's height is the only number
-- that had to change -- which is what that derivation was already for.
CombinePanel.HEIGHT = 470 + 92
CombinePanel.PAD = 16
CombinePanel.ROW_H = 36
CombinePanel.TILE_W = 152
CombinePanel.TILE_H = 58
CombinePanel.FOOT_H = 82
-- THE HOPPER STRIP: a caption and one bay per `Config.PRESS.tiers`.
CombinePanel.HOPPER_H = 92

-- THE GROUNDS THIS PANEL PRINTS ON, NAMED SO THEY CAN BE MEASURED.
--
-- Every label here is `Theme.INK` or `Theme.MUTED`, and which of the two is
-- decided per GROUND rather than per element -- measured, `MUTED` reads 5.24
-- on the unpicked tile and 2.49 on the picked one, so a count label left
-- grey would disappear the moment somebody tapped it. The suite walks this
-- table and asserts ink clears 4.5 on all four.
--
-- MAGENTA IS THE SELECTION, and it is `Theme.HUE.crates` rather than a
-- colour of its own: this machine IS the crate economy's workbench, the
-- prompt card out on the verge wears the same hue, and a player who has
-- learned that magenta means crates should not have to learn it twice. It
-- also measures better on ink than `piggy` does (5.63 against 4.96).
CombinePanel.GROUNDS = {
	card = "PAPER",
	tile = "PAPER_DEEP",
	picked = "HUE.crates",
	chip = "SAND_DEEP",
	ready = "GOOD",
}

-- ============================================================
-- THE PURE HALF
-- ============================================================

-- What a tile prints. `count` is TOTAL SPARE COPIES, not total owned: the
-- bag's chip says `x2` for one spare because "I have two of these" is what a
-- nine-year-old reads off it, and this is the opposite case -- what is on
-- offer to the machine is the spares, so a tile saying 2 when one of them is
-- the copy on the pig would be an off-by-one nobody reports.
function CombinePanel.tileText(record: any, picked: number): (string, string)
	local right = if picked > 0 then ("%d / %d"):format(picked, record.count)
		else ("x%d"):format(record.count)
	return record.name or record.key, right
end

-- THE BUTTON'S OWN WORDS, and it never says COMBINE when it cannot.
--
-- A control that does nothing when pressed reads as broken rather than as
-- locked, which is the rule the garage slot, the stance pill and the combine
-- chips all keep. So the reason replaces the verb rather than sitting beside
-- it greyed out.
function CombinePanel.buttonText(refusal: string?, picked: number, need: number): (string, boolean)
	if refusal then
		return refusal:upper(), false
	end
	if picked < need then
		return ("PICK %d MORE"):format(need - picked), false
	end
	return "COMBINE", true
end

-- ============================================================
-- THE PANEL
-- ============================================================

local function label(parent: Instance, name: string, text: string, size: number,
	font: Enum.Font, colour: Color3, align: string?): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.Text = text
	t.Font = font
	t.TextSize = size
	t.TextColor3 = colour
	t.BackgroundTransparency = 1
	t.TextXAlignment = (Enum.TextXAlignment :: any)[align or "Left"]
	t.TextTruncate = Enum.TextTruncate.AtEnd
	t.Parent = parent
	return t
end

local function chipButton(parent: Instance, name: string, text: string, width: number): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = text
	b.Font = Theme.FONT
	b.TextSize = 15
	b.TextColor3 = Theme.INK
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.BackgroundColor3 = Theme.SAND_DEEP
	b.Size = UDim2.fromOffset(width, CombinePanel.ROW_H - 4)
	b.Parent = parent
	Theme.corner(b, 10)
	Theme.outline(b, Theme.OUTLINE_THIN)
	return b
end

function CombinePanel.start(player: Player, hud: ScreenGui?)
	local playerGui = player:WaitForChild("PlayerGui")
	-- `hud` is optional so the hook in `ClientMain` can stay one statement
	-- holding no local. The HUD's own ScreenGui is what carries every menu
	-- flag, so it is found by name when it is not handed over -- and a
	-- `WaitForChild` rather than a `FindFirstChild`, because this module is
	-- started from the same chunk that builds it and the order is not ours.
	local gui = hud or playerGui:WaitForChild("PiggyHUD", 20) :: ScreenGui
	if not gui then
		warn("[CombinePanel] no PiggyHUD to read the menu flags off; not starting.")
		return
	end

	-- ITS OWN ScreenGui, ABOVE THE MENU LAYER.
	--
	-- The shop raises the HUD's `DisplayOrder` to 10 while it is open, so a
	-- frame parented into the HUD would be ordered against it by ZIndex and
	-- child order -- which is how `LobbyBoard` ends up one step UNDER the
	-- menus. This one is opened by a prompt out in the world rather than by
	-- a rail tile, so being covered by a shop nobody asked for is the wrong
	-- failure: it draws on top, and it closes itself the moment a menu is
	-- raised.
	local screen = Instance.new("ScreenGui")
	screen.Name = "CombinePanel"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = true
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.DisplayOrder = 20
	screen.Enabled = false
	screen.Parent = playerGui

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = UDim2.fromOffset(CombinePanel.WIDTH, CombinePanel.HEIGHT)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Active = true
	Theme.card(card, 18)
	card.Parent = screen

	local scale = Instance.new("UIScale")
	scale.Parent = card

	-- ---- the header -----------------------------------------------------
	local title = label(card, "Title", "PIGGY PRESS", 26, Theme.FONT, Theme.INK)
	title.Position = UDim2.fromOffset(CombinePanel.PAD, CombinePanel.PAD)
	title.Size = UDim2.new(1, -CombinePanel.PAD * 2 - 56, 0, 30)

	local sub = label(card, "Subtitle", "", 13, Theme.FONT_BODY, Theme.MUTED)
	sub.Position = UDim2.fromOffset(CombinePanel.PAD, CombinePanel.PAD + 30)
	sub.Size = UDim2.new(1, -CombinePanel.PAD * 2 - 56, 0, 18)

	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Text = utf8.char(0x00D7)
	close.Font = Theme.FONT
	close.TextSize = 30
	close.TextColor3 = Theme.PAPER
	close.BackgroundColor3 = Theme.STOP
	close.BorderSizePixel = 0
	close.AutoButtonColor = true
	close.ZIndex = 6
	close.Parent = card
	Theme.corner(close, 22)
	Theme.outline(close)
	Theme.floatClose(close, 44)

	-- ---- the hopper -----------------------------------------------------
	--
	-- WHAT IS IN THE MACHINE, AND HOW TO PUT SOMETHING IN IT (designer,
	-- 2026-09-23: "have it open a menu showing a description of how to
	-- operate it ... if they forget what they put in they should be able to
	-- open the menu and see whats in there").
	--
	-- A BAY PER TIER, WHICH IS WHY THERE IS NO MIXED-DEPOSIT STATE TO DRAW.
	-- Two commons and a rare is a full common bay and a rare waiting, not an
	-- error -- so this is a readout rather than a validator, and it never has
	-- to say no.
	--
	-- IT NAMES THE PIGGIES rather than counting them alone. A count answers
	-- "how far along am I" and the question asked was "what did I put in",
	-- which only a name answers.
	local hopperRow = Instance.new("Frame")
	hopperRow.Name = "Hopper"
	hopperRow.BackgroundTransparency = 1
	hopperRow.Position = UDim2.fromOffset(CombinePanel.PAD, CombinePanel.PAD + 52)
	hopperRow.Size = UDim2.new(1, -CombinePanel.PAD * 2, 0, CombinePanel.HOPPER_H)
	hopperRow.Parent = card

	local howTo = label(hopperRow, "HowTo",
		"CARRY A PIGGY HERE AND HOLD THE PRESS TO FEED IT. "
		.. "A FULL BAY CRUSHES ITSELF. NOTHING COMES BACK OUT.",
		12, Theme.FONT_BODY, Theme.MUTED)
	howTo.Position = UDim2.fromOffset(0, 0)
	howTo.Size = UDim2.new(1, 0, 0, 16)

	local bays: { [string]: { count: TextLabel, names: TextLabel } } = {}
	do
		local tiers = Config.PRESS.tiers
		local gap = 8
		local wide = (CombinePanel.WIDTH - CombinePanel.PAD * 2 - gap * (#tiers - 1)) / #tiers
		for index, tier in ipairs(tiers) do
			local bay = Instance.new("Frame")
			bay.Name = "Bay_" .. tier
			bay.Position = UDim2.fromOffset((wide + gap) * (index - 1), 20)
			bay.Size = UDim2.fromOffset(wide, CombinePanel.HOPPER_H - 24)
			bay.BackgroundColor3 = Theme.SLAB
			bay.BorderSizePixel = 0
			bay.Parent = hopperRow
			Theme.corner(bay, 10)
			-- THE TIER'S OWN COLOUR ON THE EDGE, never as the ground: a bay
			-- holds NAMES, and this project has four separate entries about a
			-- saturated ground eating the type printed on it.
			local stroke = Instance.new("UIStroke")
			stroke.Thickness = 2
			stroke.Color = (Config.RARITIES[tier] or Config.RARITIES.common).colour
			stroke.Parent = bay

			local head = label(bay, "Tier", tier:upper(), 11, Theme.FONT, Theme.MUTED_LIGHT)
			head.Position = UDim2.fromOffset(8, 4)
			head.Size = UDim2.new(1, -16, 0, 12)

			local count = label(bay, "Count", "0 / 0", 18, Theme.FONT, Theme.PAPER)
			count.Position = UDim2.fromOffset(8, 16)
			count.Size = UDim2.new(1, -16, 0, 20)

			local names = label(bay, "Names", "empty", 10, Theme.FONT_BODY, Theme.MUTED_LIGHT)
			names.Position = UDim2.fromOffset(8, 38)
			names.Size = UDim2.new(1, -16, 0, 24)
			names.TextWrapped = true
			-- TRUNCATED RATHER THAN SCALED. `TextScaled` here would shrink four
			-- piggy names to unreadable and report that it fits, which is the
			-- silent-shrinkage failure this project already records twice.
			names.TextTruncate = Enum.TextTruncate.AtEnd

			bays[tier] = { count = count, names = names }
		end
	end

	-- Painted from the server's own push and from nothing else, so the panel
	-- cannot disagree with the save about what is in the machine.
	local function paintHopper(payload: any)
		for tier, parts in pairs(bays) do
			local bay = payload and payload[tier]
			local keys = (bay and bay.keys) or {}
			local need = (bay and bay.need) or Config.pressNeed(tier) or 0
			parts.count.Text = ("%d / %d"):format(#keys, need)
			if #keys == 0 then
				parts.names.Text = "empty"
			else
				local named = {}
				for _, key in ipairs(keys) do
					local skin = Config.getSkin(key)
					table.insert(named, (skin and skin.name) or key)
				end
				parts.names.Text = table.concat(named, ", ")
			end
		end
	end
	paintHopper(nil)

	-- ---- the three pickers ----------------------------------------------
	local function pickerRow(name: string, y: number): Frame
		local row = Instance.new("Frame")
		row.Name = name
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromOffset(CombinePanel.PAD, y)
		row.Size = UDim2.new(1, -CombinePanel.PAD * 2, 0, CombinePanel.ROW_H)
		row.Parent = card
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.Padding = UDim.new(0, 8)
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = row
		return row
	end

	local KIND_Y = CombinePanel.PAD + 56 + CombinePanel.HOPPER_H
	local kindRow = pickerRow("Kinds", KIND_Y)
	local shelfRow = pickerRow("Shelves", KIND_Y + CombinePanel.ROW_H + 6)
	local tierRow = pickerRow("Tiers", KIND_Y + (CombinePanel.ROW_H + 6) * 2)

	-- ---- the spares -----------------------------------------------------
	local GRID_Y = KIND_Y + (CombinePanel.ROW_H + 6) * 3 + 4
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Spares"
	grid.Position = UDim2.fromOffset(CombinePanel.PAD, GRID_Y)
	grid.Size = UDim2.new(1, -CombinePanel.PAD * 2,
		0, CombinePanel.HEIGHT - GRID_Y - CombinePanel.FOOT_H - CombinePanel.PAD)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 6
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.Parent = card
	-- A `Border` stroke draws OUTSIDE its frame, into the region a
	-- ScrollingFrame clips -- which is what once cut the left edge off the
	-- first column of every cosmetic card and three pixels off the bag's own
	-- tab rail. Every tile here carries one, so the clearance goes on the
	-- scroll, and it goes on all four sides because the top row's stroke is
	-- clipped by the same edge.
	local gridPad = Instance.new("UIPadding")
	gridPad.PaddingLeft = UDim.new(0, 4)
	gridPad.PaddingRight = UDim.new(0, 4)
	gridPad.PaddingTop = UDim.new(0, 4)
	gridPad.PaddingBottom = UDim.new(0, 4)
	gridPad.Parent = grid

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.fromOffset(CombinePanel.TILE_W, CombinePanel.TILE_H)
	gridLayout.CellPadding = UDim2.fromOffset(8, 8)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = grid

	local empty = label(card, "Empty", "", 14, Theme.FONT_BODY, Theme.MUTED, "Center")
	empty.Position = grid.Position
	empty.Size = grid.Size
	empty.TextWrapped = true
	empty.Visible = false

	-- ---- the footer -----------------------------------------------------
	local odds = label(card, "Odds", "", 13, Theme.FONT_BODY, Theme.MUTED)
	odds.Position = UDim2.fromOffset(CombinePanel.PAD,
		CombinePanel.HEIGHT - CombinePanel.FOOT_H)
	odds.Size = UDim2.new(1, -CombinePanel.PAD * 2, 0, 18)

	local auto = chipButton(card, "Auto", "AUTO PICK", 120)
	auto.Position = UDim2.fromOffset(CombinePanel.PAD,
		CombinePanel.HEIGHT - CombinePanel.FOOT_H + 22)

	local go = Instance.new("TextButton")
	go.Name = "Combine"
	go.Font = Theme.FONT
	go.TextSize = 20
	go.Text = "COMBINE"
	go.TextColor3 = Theme.INK
	go.AutoButtonColor = false
	go.BorderSizePixel = 0
	go.AnchorPoint = Vector2.new(1, 0)
	go.Position = UDim2.new(1, -CombinePanel.PAD, 0,
		CombinePanel.HEIGHT - CombinePanel.FOOT_H + 22)
	go.Size = UDim2.fromOffset(CombinePanel.WIDTH - CombinePanel.PAD * 3 - 120, 40)
	go.Parent = card
	Theme.corner(go, 12)
	Theme.outline(go)
	-- `shade` AND NOT `gloss`, which is the rule for anything printing DARK
	-- type on a saturated fill: gloss runs TO a second colour and its deep
	-- stop can kill ink outright (the rebirth button measured 2.47 that way),
	-- where shade is a shallow MULTIPLY that leaves the hue to the caller.
	-- This button's fill changes between GOOD and SAND_DEEP every repaint, so
	-- a baked two-colour ramp would be wrong half the time. Measured, ink
	-- holds 4.97 at the bottom of the shade on the green.
	Theme.shade(go)

	-- ============================================================
	-- STATE
	-- ============================================================
	--
	-- ONE TABLE, not five top-level locals. `ClientMain` learned that lesson
	-- for the HUD and it is worth keeping here: a feature whose state is
	-- five loose names is five things a later edit can forget to reset.
	local state = {
		chest = nil :: any,          -- the last `ChestState` payload
		kind = CombineStation.KINDS[1].key,
		shelf = nil :: string?,
		tier = nil :: string?,
		picked = {} :: { string },   -- one entry per copy, `kind:key`
	}

	local kindButtons: { [string]: TextButton } = {}
	local shelfButtons: { [string]: TextButton } = {}
	local tierButtons: { [string]: TextButton } = {}
	local tiles: { [string]: TextButton } = {}

	local function pickedCount(entry: string): number
		local n = 0
		for _, e in ipairs(state.picked) do
			if e == entry then
				n += 1
			end
		end
		return n
	end

	local function paintChip(button: TextButton, on: boolean, tone: Color3?)
		button.BackgroundColor3 = if on then (tone or Theme.HUE.crates) else Theme.SAND_DEEP
		-- INK ON BOTH, which is what the four grounds in `GROUNDS` were
		-- measured for. A tier chip's `on` tone is the RARITY colour, and
		-- `Theme.readable` is what keeps ink legible on the pale common grey
		-- as well as on the gold legendary.
		button.TextColor3 = Theme.INK
	end

	local paint: () -> ()

	-- A pick is dropped when it stops being legal, which is every time the
	-- kind, the shelf or the tier changes and every time the server pushes.
	-- Keeping it would send entries the panel is no longer showing, and the
	-- server would refuse the whole combine rather than drop one -- which is
	-- correct and reads as the button being broken.
	local function clearPick()
		state.picked = {}
	end

	local function selectKind(key: string)
		state.kind = key
		local shelves = CombineStation.shelvesFor(key)
		state.shelf = shelves[1] and shelves[1].chest or nil
		state.tier = nil
		clearPick()
		paint()
	end

	local function selectShelf(chest: string)
		state.shelf = chest
		state.tier = nil
		clearPick()
		paint()
	end

	local function selectTier(tier: string)
		state.tier = tier
		clearPick()
		paint()
	end

	-- ---- painting -------------------------------------------------------
	paint = function()
		local need = Config.COMBINE.need
		local kind = CombineStation.kind(state.kind) or CombineStation.KINDS[1]
		sub.Text = kind.blurb
		odds.Text = ("Climb chances: %s   (%d in, 1 out)"):format(
			CombineStation.oddsText(), need)

		-- the kind row
		for key, button in pairs(kindButtons) do
			paintChip(button, key == state.kind)
		end

		-- the shelf row. HIDDEN WHEN THERE IS ONE, because a picker with a
		-- single option is a control that cannot be used -- and the row's
		-- own height goes with it, since a UIListLayout skips an invisible
		-- child and this panel is measured to the pixel.
		local shelves = CombineStation.shelvesFor(state.kind)
		for _, button in pairs(shelfButtons) do
			button.Visible = false
		end
		for _, shelf in ipairs(shelves) do
			local button = shelfButtons[shelf.chest]
			if button then
				button.Visible = #shelves > 1
				paintChip(button, shelf.chest == state.shelf)
			end
		end
		shelfRow.Visible = #shelves > 1

		-- the tier row
		local climbable = if state.shelf then CombineStation.tiersFor(state.shelf) else {}
		for _, button in pairs(tierButtons) do
			button.Visible = false
		end
		for _, tier in ipairs(climbable) do
			local button = tierButtons[tier]
			if button then
				local have = CombineStation.countAt(state.chest, state.kind, tier)
				button.Visible = true
				button.Text = ("%s %d/%d"):format(
					(Config.RARITIES[tier] :: any).label:upper(), math.min(have, need), need)
				paintChip(button, tier == state.tier, (Config.RARITIES[tier] :: any).colour)
			end
		end

		-- the spares
		local records = CombineStation.sparesOf(state.chest, state.kind, state.tier)
		local seen: { [string]: boolean } = {}
		for index, record in ipairs(records) do
			seen[record.entry] = true
			local tile = tiles[record.entry]
			if not tile then
				tile = Instance.new("TextButton")
				tile.Name = "Tile_" .. record.entry
				tile.Text = ""
				tile.AutoButtonColor = false
				tile.BorderSizePixel = 0
				tile.Parent = grid
				Theme.corner(tile, 10)
				Theme.outline(tile, Theme.OUTLINE_THIN)
				local name = label(tile, "Name", "", 14, Theme.FONT, Theme.INK)
				name.Position = UDim2.fromOffset(8, 6)
				name.Size = UDim2.new(1, -16, 0, 20)
				local count = label(tile, "Count", "", 13, Theme.FONT_BODY, Theme.MUTED)
				count.Position = UDim2.fromOffset(8, 30)
				count.Size = UDim2.new(1, -16, 0, 18)
				local entry = record.entry
				tile.Activated:Connect(function()
					local held = 0
					for _, r in ipairs(CombineStation.sparesOf(state.chest, state.kind, state.tier)) do
						if r.entry == entry then
							held = r.count
						end
					end
					local have = pickedCount(entry)
					if have > 0 then
						-- A second tap takes one back off, which is the only
						-- way out of a mistap on a touchscreen.
						for i = #state.picked, 1, -1 do
							if state.picked[i] == entry then
								table.remove(state.picked, i)
								break
							end
						end
					elseif #state.picked < Config.COMBINE.need and held > 0 then
						table.insert(state.picked, entry)
					end
					paint()
				end)
				tiles[record.entry] = tile
			end
			tile.Visible = true
			tile.LayoutOrder = index
			local picked = pickedCount(record.entry)
			local name, right = CombinePanel.tileText(record, picked)
			local nameLabel = tile:FindFirstChild("Name") :: TextLabel
			local countLabel = tile:FindFirstChild("Count") :: TextLabel
			nameLabel.Text = name
			countLabel.Text = right
			local tone = (Config.RARITIES[record.tier] :: any)
			tile.BackgroundColor3 = if picked > 0 then Theme.HUE.crates else Theme.PAPER_DEEP
			-- MEASURED: `MUTED` reads 5.24 on the unpicked tile and 2.49 on
			-- the magenta one, so the count goes to INK the moment a tile is
			-- picked rather than quietly vanishing on the one state that is
			-- about it.
			countLabel.TextColor3 = if picked > 0 then Theme.INK else Theme.MUTED
			local stroke = tile:FindFirstChildOfClass("UIStroke")
			if stroke and tone then
				stroke.Color = tone.colour
				stroke.Thickness = if picked > 0 then Theme.OUTLINE else Theme.OUTLINE_THIN
			end
		end
		for entry, tile in pairs(tiles) do
			if not seen[entry] then
				tile.Visible = false
			end
		end

		-- ONLY WHAT YOU HAVE, AND A NAMED WAY TO GET SOME. An empty grid with
		-- nothing in it is a screen that failed to load; this is the rule the
		-- bag's own empty sections keep.
		local refusal = CombineStation.refusal(state.chest, state.kind, state.shelf, state.tier)
		empty.Visible = #records == 0
		if empty.Visible then
			empty.Text = refusal or "Nothing spare of that rarity yet. Open crates to find some."
		end

		local text, ready = CombinePanel.buttonText(refusal, #state.picked, need)
		go.Text = text
		go.BackgroundColor3 = if ready then Theme.GOOD else Theme.SAND_DEEP
		go.TextColor3 = Theme.INK
		auto.Visible = refusal == nil
	end

	-- ---- the pickers, built once ----------------------------------------
	for index, kind in ipairs(CombineStation.KINDS) do
		local button = chipButton(kindRow, "Kind_" .. kind.key, kind.name, 150)
		button.LayoutOrder = index
		button.Activated:Connect(function()
			selectKind(kind.key)
		end)
		kindButtons[kind.key] = button
	end

	-- Every shelf either kind could ever offer gets a button, built once and
	-- shown when its kind is selected -- so a coat crate landing later needs
	-- no new build path. `shelvesFor` is derived from the live pools, so the
	-- set can only grow.
	do
		local order = 0
		local made: { [string]: boolean } = {}
		for _, kind in ipairs(CombineStation.KINDS) do
			for _, shelf in ipairs(CombineStation.shelvesFor(kind.key)) do
				if not made[shelf.chest] then
					made[shelf.chest] = true
					order += 1
					local button = chipButton(shelfRow, "Shelf_" .. shelf.chest,
						shelf.name:upper(), 140)
					button.LayoutOrder = order
					button.Visible = false
					button.Activated:Connect(function()
						selectShelf(shelf.chest)
					end)
					shelfButtons[shelf.chest] = button
				end
			end
		end
	end

	for index, tier in ipairs(Config.RARITY_ORDER) do
		local button = chipButton(tierRow, "Tier_" .. tier, tier:upper(), 116)
		button.LayoutOrder = index
		button.Visible = false
		button.Activated:Connect(function()
			selectTier(tier)
		end)
		tierButtons[tier] = button
	end

	auto.Activated:Connect(function()
		if state.tier then
			state.picked = CombineStation.autoPick(state.chest, state.kind, state.tier)
		end
		paint()
	end)

	go.Activated:Connect(function()
		local refusal = CombineStation.refusal(state.chest, state.kind, state.shelf, state.tier)
		-- THE CLIENT DECLINES TO ASK FOR A KNOWN NO, which is the split the
		-- number row and the dodge-while-riding suppression both make. The
		-- server re-checks everything and refuses out loud regardless.
		if refusal or #state.picked ~= Config.COMBINE.need then
			return
		end
		Remotes.get("CombineRequest"):FireServer(state.kind, state.shelf, state.tier, state.picked)
		-- Cleared on the way out rather than on the way back: the spares are
		-- committed, and a pick left standing over a `ChestState` that no
		-- longer holds them would show counts nobody owns for a frame.
		clearPick()
		paint()
	end)

	-- ---- fit ------------------------------------------------------------
	local function fit()
		local view = gui.AbsoluteSize
		if view.X <= 0 or view.Y <= 0 then
			return
		end
		scale.Scale = math.min(1,
			(view.X - 24) / CombinePanel.WIDTH,
			(view.Y - 24) / CombinePanel.HEIGHT)
		-- Reapplied after the scale, because `floatClose` seats the button
		-- against its parent and a UIScale moves the parent under it.
		Theme.floatClose(close, 44)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()

	-- ---- open and close -------------------------------------------------
	--
	-- The shop raises the HUD ScreenGui's `DisplayOrder` while it is open and
	-- puts it back on close; the bag and the settings publish attributes.
	-- Those three are every menu there is, and none of them can be named
	-- from here.
	local baseOrder = gui.DisplayOrder
	local function setOpen(open: boolean)
		gui:SetAttribute(CombinePanel.ATTRIBUTE, open)
	end

	gui:GetAttributeChangedSignal(CombinePanel.ATTRIBUTE):Connect(function()
		local open = gui:GetAttribute(CombinePanel.ATTRIBUTE) == true
		if open then
			-- SETTINGS IS THE ONE MENU THIS CAN CLOSE FROM OUTSIDE, because
			-- there the attribute IS the state and `ClientMain` watches it.
			-- `BagOpen` is NOT written here on purpose: `setBag` sets the
			-- flag AND the frame separately, so an outside write to the flag
			-- would leave the bag on screen with the HUD believing it shut.
			-- The shop and the bag are closed by the one-line hook in
			-- `ClientMain` that watches this attribute.
			gui:SetAttribute("SettingsOpen", false)
			paint()
		end
		screen.Enabled = open
	end)

	for _, name in { "BagOpen", "SettingsOpen" } do
		gui:GetAttributeChangedSignal(name):Connect(function()
			if gui:GetAttribute(name) then
				setOpen(false)
			end
		end)
	end
	-- Fires only when the order is RAISED, which is the shop opening. A
	-- restore back to `baseOrder` is the shop closing and must not close
	-- this with it.
	gui:GetPropertyChangedSignal("DisplayOrder"):Connect(function()
		if gui.DisplayOrder ~= baseOrder then
			setOpen(false)
		end
	end)

	close.Activated:Connect(function()
		setOpen(false)
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape
			and gui:GetAttribute(CombinePanel.ATTRIBUTE) == true
		then
			setOpen(false)
		end
	end)

	-- ---- the wires ------------------------------------------------------
	--
	-- A THIRD CONNECTION TO `ChestState` RATHER THAN A CALL BOLTED INTO THE
	-- EXISTING TWO. `ClientMain` already hands it to `Crates.render` and the
	-- bag; those handlers are in a chunk that cannot see this module, and
	-- connecting again is free.
	Remotes.get("ChestState").OnClientEvent:Connect(function(payload)
		state.chest = payload
		-- The pick is dropped on every push, because a spare that was picked
		-- may have been sold, worn or spent in between -- and a stale entry
		-- makes the server refuse the WHOLE combine rather than drop one.
		clearPick()
		if state.shelf == nil then
			selectKind(state.kind)
		else
			paint()
		end
	end)

	Remotes.get("ChestResult").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and payload.combined then
			clearPick()
			paint()
		end
	end)

	Remotes.get("PressState").OnClientEvent:Connect(paintHopper)

	Remotes.get("CombineOpen").OnClientEvent:Connect(function()
		setOpen(true)
	end)

	selectKind(state.kind)
end

return CombinePanel
