--!strict
--[[
	HotBar

	The throwables bar along the bottom of the screen, and the drag that lets a
	player arrange it.

	WHY THIS IS A MODULE. `ClientMain` is one chunk against Luau's 200-local
	ceiling and was sitting at 199. A function body gets its own register file,
	so the whole feature costs that chunk ONE local instead of a dozen -- the
	same call `HouseFX`, `SpinWheel` and `AdminPanel` already made. Moving the
	bar's own state in here (the frame, the layout, the key map, the refresh)
	actually hands three registers BACK.

	----------------------------------------------------------------------

	ORDER AND KEYS ARE TWO DIFFERENT THINGS, AND THAT IS WHAT MAKES A
	PLAYER-ARRANGED BAR LEGAL AT ALL.

	The existing rule is that keys are FIXED per item and never renumbered to
	fill gaps, so the key that threw a 1,500-coin plunger a moment ago cannot
	throw a 22,000-coin zapper once a stock runs out. That rule is about the
	GAME silently changing a binding underneath somebody. It is untouched here:
	`KEYS` is still hardcoded, a number still belongs to an item for the life of
	the game, and dragging a tile does not move it.

	What dragging moves is the tile's POSITION, which is the only handle a touch
	player has -- and most of this audience is on a tablet, where the number
	chips are decoration for a keyboard they do not own. So a keyboard player
	arranges nothing and keeps their numbers; a tablet player arranges the bar
	and keeps their thumb. Both are stable, and neither changes unless the
	player changes it themselves.

	----------------------------------------------------------------------

	SHELVING HIDES A SLOT. IT NEVER DESTROYS THE STOCK.

	There is no stock cap anywhere in this game -- not on bones, gadgets, home
	items or the thief kit -- so there is nothing for a destroy button to make
	room for. All it could do is delete something the player has already paid
	coins for, which for a nine-year-old holding a 30,000-coin Golden Bone is a
	trap with no upside on the other side of it. Every other rule in this
	codebase points the same way: a robbery never costs progress, bail is capped
	so being caught is survivable, and bones deliberately survive rebirth.

	So dragging a tile onto the bin takes it OFF THE BAR and leaves the stock
	exactly where it was. It is reversible in one tap, the item is still in the
	shop and still throwable by its own number key, and nothing a child can do
	in here loses them anything.
]]

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local HotBar = {}

local SLOT = 58
local GAP = 6
-- How far the pointer travels before a press becomes a drag rather than a
-- throw. Too tight and a tap from a moving finger throws nothing; too loose
-- and a deliberate drag feels stuck. Ten pixels is about a fingertip's own
-- wobble on a tablet.
local DRAG_SLOP = 10

-- THE KEY BELONGS TO THE SLOT, AND DRAGGING MOVES THE ITEM BETWEEN SLOTS.
--
-- This was a fixed item -> key map, and the reasoning behind that was half
-- right. The thing it was protecting against is AUTOMATIC renumbering: number
-- the tiles you can currently SEE, 1..n, and the bar reshuffles every time a
-- stock runs out, so the key that threw a plunger a moment ago now throws a
-- zapper worth twenty-two thousand coins. That is still forbidden.
--
-- But a DELIBERATE drag is the opposite case. The player picked the position,
-- so the position is the thing they remember -- and a tile that visibly moves
-- to slot 3 while its key stays 7 is the bar lying about itself. Keys follow
-- the arrangement, which the player owns and which is saved.
--
-- What makes both true at once: the key is the index into the ARRANGEMENT,
-- which holds every item whether it is held, empty or shelved. An empty tile
-- is hidden and its number is simply unused, so nothing renumbers when stock
-- changes -- only a drag reorders.
local KEY_SLOTS: { { key: Enum.KeyCode, label: string } } = {
	{ key = Enum.KeyCode.One, label = "1" },
	{ key = Enum.KeyCode.Two, label = "2" },
	{ key = Enum.KeyCode.Three, label = "3" },
	{ key = Enum.KeyCode.Four, label = "4" },
	{ key = Enum.KeyCode.Five, label = "5" },
	{ key = Enum.KeyCode.Six, label = "6" },
	{ key = Enum.KeyCode.Seven, label = "7" },
	{ key = Enum.KeyCode.Eight, label = "8" },
	{ key = Enum.KeyCode.Nine, label = "9" },
	{ key = Enum.KeyCode.Zero, label = "0" },
	-- A LETTER, because the number row runs out at ten. Checked against the
	-- rest of the map: Q dodge/trick, B shop, V garage, F2 admin. G is free.
	{ key = Enum.KeyCode.R, label = "R" },
}

-- EVERY item the bar can ever hold, in its designed order. The arrangement is
-- seeded from this and anything missing from a saved arrangement is appended
-- from it, so a newly shipped item lands in its designed place rather than
-- nowhere. It is also the allowlist a saved arrangement is filtered against.
HotBar.ITEMS = {
	"bone", "steak", "golden",
	"plunger", "gum", "zapper",
	"treat", "sprinkler", "radio",
	"raincoat",
}

-- Set by ClientMain. The bar knows how to lay itself out and nothing about
-- whether the player is holding anything or standing inside a wheelie bin.
HotBar.shouldShow = nil :: (() -> boolean)?

-- Fired whenever the ARRANGEMENT changes, which is the only thing that can
-- move a key.
--
-- The key label on each tile is painted by ClientMain's render functions,
-- because that label is dual-purpose -- it shows the key normally and a state
-- word like "ON" while a buff is running -- so the bar cannot simply own it.
-- That left the labels STALE in the two cases that matter: a saved
-- arrangement arriving after the first render, and a drag. Measured: golden
-- sitting in position 1 still showing key 3, which is the bar lying about
-- itself in exactly the way this change was meant to stop.
HotBar.onArranged = nil :: (() -> ())?

local function announceArranged()
	local fn = HotBar.onArranged
	if fn then
		fn()
	end
end

type Slot = {
	button: TextButton,
	-- The ring that says this is the one in your hand. Built for every slot
	-- and left invisible, rather than created on equip and destroyed on put
	-- away: a stroke that appears has to be parented, sized and layered at
	-- exactly the moment the player is looking at the tile, and one that was
	-- always there only has to change its transparency.
	edge: UIStroke,
	key: string,
	base: number,
	held: boolean,
	-- The item's display name, for the hint above the bar. Passed in rather
	-- than looked up: the bar has no business knowing which of four
	-- catalogues a key came from.
	name: string,
}

local slots: { [string]: Slot } = {}
local frame: Frame
local scale: UIScale
local binZone: Frame
local restoreTile: TextButton
local restoreCount: TextLabel
-- The name that appears above the bar, and which item put it there. Held so
-- MouseLeave only clears the hint it actually set: moving the pointer from
-- one tile straight onto the next fires Leave on the first AFTER Enter on
-- the second, so clearing unconditionally would blank the new name.
local hintLabel: TextLabel
local hintKey: string? = nil
local hintUntil = 0

-- What the SERVER says is in this player's hand. Held so `refresh` can repaint
-- after a tile is shown or hidden, and so nothing here has to ask the
-- character for an attribute it would then have to keep watching.
local equippedKey: string? = nil

-- THE PLAYER'S ARRANGEMENT, AND IT IS ALWAYS THE FULL LIST.
--
-- It used to be sparse -- only items the player had actually dragged -- with
-- everything else falling back to a catalogue block. That worked for layout
-- and cannot work for keys: a key is an INDEX into this list, so a list that
-- omits most items has no index for them. Seeded from ITEMS and kept complete
-- by `applySettings`, which appends anything a saved arrangement is missing.
local arrangement: { string } = table.clone(HotBar.ITEMS)
local shelved: { [string]: boolean } = {}

local drag = {
	key = nil :: string?,
	ghost = nil :: TextButton?,
	origin = Vector2.zero,
	live = false,
}
-- A drag ends with the same InputEnded a tap does, and Activated fires after
-- it. Without this flag every rearrangement would also throw the thing being
-- rearranged.
local justDragged = false

-- ============================================================
-- ARRANGEMENT
-- ============================================================

local function indexOf(key: string): number?
	return table.find(arrangement, key)
end

-- Insert BEFORE a named slot, or append when there is nothing to the right.
-- A NAME rather than an index, because a drop point is read off the SCREEN --
-- from the visible tiles -- and the arrangement contains hidden and empty
-- ones too. The first version computed an index among visible tiles and
-- applied it to a different, shorter list, which pinned every drop to
-- position 1 until every item had been dragged once. A name means the same
-- thing in both lists.
local function arrange(key: string, before: string?)
	if before == key then
		return
	end
	local out = {}
	for _, k in ipairs(arrangement) do
		if k ~= key then
			if k == before then
				table.insert(out, key)
			end
			table.insert(out, k)
		end
	end
	if not table.find(out, key) then
		table.insert(out, key)
	end
	arrangement = out
end

-- ONE LIST DRIVES BOTH THE LAYOUT AND THE KEYS, which is the only reason a
-- tile's number can be trusted to match where it is sitting.
local function applyOrder()
	for _, slot in pairs(slots) do
		slot.button.LayoutOrder = indexOf(slot.key) or (1000 + slot.base)
		slot.button.Visible = slot.held and not shelved[slot.key]
	end
end

-- THE KEY ROW SKIPS SHELVED ITEMS, AND ONLY SHELVED ITEMS.
--
-- Two things can take a tile off the bar and they are not the same thing. A
-- stock running out is NOT the player's doing, so its slot keeps its number
-- and the number is simply unused -- that is the whole rule protecting muscle
-- memory, and it stays. SHELVING is the player deliberately removing a tile,
-- so the row closes up behind it; leaving a hole would show a bar numbered
-- 1..8 then 0, which reads as a bug rather than as a gap somebody made.
--
-- Restoring a shelved item puts it back at its arranged position and the row
-- opens up again, so nothing is lost by closing it.
local function keyOrder(): { string }
	local out = {}
	for _, key in ipairs(arrangement) do
		if not shelved[key] then
			table.insert(out, key)
		end
	end
	return out
end

-- The key currently bound to an item, or nil past the end of the key row.
function HotBar.keyFor(item: string): { key: Enum.KeyCode, label: string }?
	if shelved[item] then
		return nil
	end
	local i = table.find(keyOrder(), item)
	return if i then KEY_SLOTS[i] else nil
end

-- The item a keypress means right now. The inverse of keyFor, and the only
-- thing ClientMain's input handler needs to know.
function HotBar.itemForKey(code: Enum.KeyCode): string?
	local order = keyOrder()
	for i, slot in ipairs(KEY_SLOTS) do
		if slot.key == code then
			return order[i]
		end
	end
	return nil
end

local function save()
	local hidden = {}
	for key in pairs(shelved) do
		table.insert(hidden, key)
	end
	table.sort(hidden)
	Remotes.get("SettingRequest"):FireServer("hotbar", {
		order = arrangement,
		hidden = hidden,
	})
end

-- ============================================================
-- LAYOUT
-- ============================================================

function HotBar.refresh()
	applyOrder()

	local shelvedHeld = 0
	for _, slot in pairs(slots) do
		if slot.held and shelved[slot.key] then
			shelvedHeld += 1
		end
	end
	restoreTile.Visible = shelvedHeld > 0
	restoreCount.Text = tostring(shelvedHeld)

	local show = if HotBar.shouldShow then HotBar.shouldShow() else true
	frame.Visible = show
	if not show then
		return
	end

	-- The scale is computed from the slot COUNT and never from AbsoluteSize:
	-- scaling changes AbsoluteSize, so reading it back to decide the scale is
	-- a feedback loop that oscillates instead of settling.
	local shown = 0
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("GuiButton") and child.Visible then
			shown += 1
		end
	end

	local natural = shown * SLOT + math.max(0, shown - 1) * GAP
	local room = workspace.CurrentCamera.ViewportSize.X - 40
	scale.Scale = if natural > room and natural > 0 then room / natural else 1
end

-- WHICH TILE IS IN YOUR HAND.
--
-- Pushed in from the character attribute rather than tracked from the press,
-- for the reason the whole feature exists: the server decides whether a draw
-- is allowed -- stock, riding, hiding -- so a bar that lit the tile on the
-- press would show an item in a hand that was refused one.
--
-- Colour AND thickness, not colour alone. This bar is eleven small tiles of
-- rendered 3D models in every colour the game owns, so a ring that only
-- changed hue would be lost against the gold bone and the pink gum; the ring
-- that is twice as thick as its neighbours reads at a glance, which is the
-- same argument the Legendary card border already makes.
function HotBar.setEquipped(key: string?)
	equippedKey = key
	for slotKey, slot in pairs(slots) do
		local on = slotKey == key
		slot.edge.Transparency = if on then 0 else 1
		slot.edge.Thickness = if on then 3 else 1.5
		slot.button.BackgroundTransparency = if on then 0 else 0.15
	end
end

function HotBar.equipped(): string?
	return equippedKey
end

-- Held is pushed in rather than read out, so visibility is decided in ONE
-- place and the shelf gets a veto. The four render functions each used to set
-- `Visible` directly, which left no room for a second opinion.
function HotBar.setHeld(key: string, held: boolean)
	local slot = slots[key]
	if slot then
		slot.held = held
	end
end

-- ============================================================
-- THE DRAG
-- ============================================================

-- Gui space, which is NOT input space: this ScreenGui has IgnoreGuiInset on,
-- so its y=0 is the physical top of the screen while an input's y=0 is below
-- the Roblox topbar. Everything here is compared against AbsolutePosition, so
-- the inset has to be added back or every vertical test is off by its height.
local function pointer(input: InputObject): Vector2
	local inset = GuiService:GetGuiInset()
	return Vector2.new(input.Position.X + inset.X, input.Position.Y + inset.Y)
end

-- Which slot the pointer is to the left of, or nil for past the right-hand
-- end. X only -- the bar is horizontal, and X is also the one axis the inset
-- cannot touch.
local function dropBefore(x: number): string?
	local visible = {}
	for _, slot in pairs(slots) do
		if slot.button.Visible then
			table.insert(visible, slot)
		end
	end
	table.sort(visible, function(a, b)
		return a.button.LayoutOrder < b.button.LayoutOrder
	end)

	for _, slot in ipairs(visible) do
		local b = slot.button
		if x < b.AbsolutePosition.X + b.AbsoluteSize.X / 2 then
			return slot.key
		end
	end
	return nil
end

-- SHELVING IS "ABOVE THE BAR", NOT "INSIDE A BOX".
--
-- This tested the pointer against the bin rectangle exactly: 210 by 48 pixels
-- sitting at y H-134 to H-86, while the bar's own top edge is at H-74. That
-- leaves a TWELVE PIXEL DEAD BAND between the two and open dead space above,
-- so a player pulling a tile off the bar had to stop the cursor inside a thin
-- horizontal stripe -- and dragging further, which is the natural way to mean
-- "get this off my bar", took them straight back out of it.
--
-- The gesture is pulling a tile OFF the bar, so the test is the bar's own top
-- edge and nothing else. Everything above it counts, all the way up and the
-- full width of the screen, which is a target nobody can miss. The drawn zone
-- is now only an affordance saying what will happen; it is not the hit area.
--
-- The margin is what keeps a sideways REORDER from being read as a shelve.
-- Reordering happens LIVE during the drag and freezes while over the bin, so
-- this threshold decides two things at once: where the ghost turns red, and
-- what a release means. Sixteen pixels is about a quarter of a tile -- past
-- any drift in a sideways drag, well short of a deliberate upward pull.
--
-- The drawn zone's bottom edge is placed at exactly this line, so what the
-- player sees is where the behaviour actually changes.
local SHELF_MARGIN = 16

local function overBin(p: Vector2): boolean
	if not frame then
		return false
	end
	return p.Y < frame.AbsolutePosition.Y - SHELF_MARGIN
end

local function endDrag(input: InputObject)
	if drag.ghost then
		drag.ghost:Destroy()
		drag.ghost = nil
	end
	binZone.Visible = false

	local key = drag.key
	if key and slots[key] then
		-- Restored through setEquipped rather than to a literal 0.15: the tile
		-- being dragged may be the one in the player's hand, and putting the
		-- flat value back would quietly un-highlight it.
		slots[key].button.BackgroundTransparency = if key == equippedKey then 0 else 0.15
		if drag.live then
			if overBin(pointer(input)) then
				shelved[key] = true
			end
			save()
		end
	end

	if drag.live then
		justDragged = true
		task.defer(function()
			justDragged = false
		end)
	end
	drag.key, drag.live = nil, false
	HotBar.refresh()
	-- The drop may have moved keys, so the tiles have to be repainted.
	announceArranged()
end

local function beginDrag(key: string)
	local slot = slots[key]
	if not slot then
		return
	end
	drag.live = true

	-- A CLONE rather than a reparent, so the real tile stays in the bar and
	-- slides into place under the finger while the ghost tracks it. A reparent
	-- would take the tile out of the layout, collapsing the bar by one slot at
	-- the exact moment the player is aiming at a gap in it. Connections do not
	-- survive a Clone either, so the copy cannot be tapped or throw anything.
	local ghost = slot.button:Clone()
	ghost.Name = "DragGhost"
	ghost.Visible = true
	ghost.Active = false
	ghost.AutoButtonColor = false
	ghost.BackgroundTransparency = 0
	ghost.Size = UDim2.new(0, SLOT, 0, SLOT)
	ghost.ZIndex = 20
	for _, d in ipairs(ghost:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.ZIndex = 21
		end
	end
	ghost.Parent = frame.Parent
	drag.ghost = ghost

	slot.button.BackgroundTransparency = 0.72
	binZone.Visible = true
end

local function trackDrag(input: InputObject)
	local key = drag.key
	if not key then
		return
	end
	local p = pointer(input)

	if not drag.live then
		if (p - drag.origin).Magnitude < DRAG_SLOP then
			return
		end
		beginDrag(key)
	end

	local ghost = drag.ghost
	if ghost then
		ghost.Position = UDim2.new(0, p.X - SLOT / 2, 0, p.Y - SLOT / 2)
		ghost.BackgroundColor3 = if overBin(p)
			then Theme.STOP
			else Theme.COOL
	end

	-- The bin is a removal, not a position, so the tile stops shuffling while
	-- the finger is over it. Otherwise it slides to whichever end of the bar
	-- the bin happens to sit above, and reads as though the drop had already
	-- landed somewhere else.
	if not overBin(p) then
		arrange(key, dropBefore(p.X))
		applyOrder()
	end
end

-- ============================================================
-- BUILD
-- ============================================================

function HotBar.init(gui: ScreenGui): Frame
	frame = Instance.new("Frame")
	frame.Name = "HotBar"
	-- Bottom centre, and its own element rather than the top row of the
	-- bottom-right column it used to live in. AutomaticSize.X makes it exactly
	-- as wide as the slots that are actually visible, so a centred bar stays
	-- centred as items come and go -- UIListLayout skips hidden children, and
	-- most of these slots are hidden most of the time.
	frame.Size = UDim2.new(0, 0, 0, 54)
	frame.AutomaticSize = Enum.AutomaticSize.X
	frame.Position = UDim2.new(0.5, 0, 1, -20)
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	-- THE NAME, ABOVE THE BAR AND CENTRED ON THE SCREEN RATHER THAN ON THE BAR.
	--
	-- Parented to the gui, not to `frame`: the bar has AutomaticSize.X and
	-- re-centres itself as tiles come and go, so a label inside it would slide
	-- sideways every time a stock ran out. It also sits at y -80, which is
	-- clear of the bottom-left column this file's own notes measure -- stance
	-- pill 216..250, garage 140..208, boost 86..130, bar 20..74 -- because
	-- that column is on the LEFT and this is centred.
	hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "ItemName"
	hintLabel.Size = UDim2.new(0, 260, 0, 22)
	hintLabel.Position = UDim2.new(0.5, 0, 1, -80)
	hintLabel.AnchorPoint = Vector2.new(0.5, 1)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Font = Enum.Font.FredokaOne
	hintLabel.TextSize = 17
	hintLabel.TextColor3 = Theme.PAPER
	hintLabel.TextStrokeTransparency = 0.25
	hintLabel.TextStrokeColor3 = Theme.INK
	hintLabel.Text = ""
	hintLabel.Visible = false
	hintLabel.ZIndex = 6
	hintLabel.Parent = gui

	-- A use-hint lets go after a moment; a hover-hint does not, so only the
	-- timed one is cleared here. Polled rather than task.delay'd so a second
	-- press simply extends it instead of the first press's timer blanking a
	-- name the player has only just been shown.
	RunService.Heartbeat:Connect(function()
		if hintUntil > 0 and os.clock() > hintUntil then
			hintUntil = 0
			HotBar.hint(nil)
		end
	end)

	scale = Instance.new("UIScale")
	scale.Parent = frame

	-- ---------- the bin ----------
	--
	-- On screen only during a drag, and centred directly above the bar rather
	-- than in a corner: a target you have to aim at across the screen is a
	-- target a nine-year-old misses, and this one wants to sit in the path of
	-- the gesture that reaches it.
	--
	-- It says OFF THE BAR, not DELETE, because that is what it does. Nothing
	-- in this file spends a coin or destroys a stock, and a label implying
	-- otherwise would be the scariest thing on the screen for no reason.
	binZone = Instance.new("Frame")
	binZone.Name = "HotBarBin"
	binZone.AnchorPoint = Vector2.new(0.5, 1)
	-- Sits ON the bar's top edge with no gap, and spans most of the width, so
	-- what it shows is roughly what `overBin` accepts. It is an affordance,
	-- not the hit test -- the test is generous well beyond this box, which is
	-- the right way round: a player who aims at the target always hits, and a
	-- player who overshoots still hits.
	binZone.Position = UDim2.new(0.5, 0, 1, -90)   -- bar top (74) + SHELF_MARGIN
	binZone.Size = UDim2.new(0.6, 0, 0, 92)
	-- DEEPER THAN `STOP_INK`, which is solved for TEXT on paper and lands
	-- this the other way round -- paper on it measured 4.51 against a
	-- floor of 4.5. At (168, 50, 36) it is 6.27.
	binZone.BackgroundColor3 = Color3.fromRGB(168, 50, 36)
	binZone.BackgroundTransparency = 0.12
	binZone.BorderSizePixel = 0
	binZone.Visible = false
	binZone.ZIndex = 18
	binZone.Parent = gui

	local binCorner = Instance.new("UICorner")
	binCorner.CornerRadius = UDim.new(0, 12)
	binCorner.Parent = binZone

	local binEdge = Instance.new("UIStroke")
	binEdge.Color = Theme.STOP
	binEdge.Thickness = 2
	binEdge.Transparency = 0.25
	binEdge.Parent = binZone

	local binText = Instance.new("TextLabel")
	binText.Size = UDim2.new(1, -12, 0, 26)
	binText.Position = UDim2.new(0, 6, 0, 6)
	binText.BackgroundTransparency = 1
	binText.Font = Enum.Font.GothamBold
	binText.TextSize = 14
	binText.TextColor3 = Theme.PAPER
	binText.Text = utf8.char(0x1F5D1) .. "  OFF THE BAR"
	binText.ZIndex = 19
	binText.Parent = binZone

	local binSub = Instance.new("TextLabel")
	binSub.AnchorPoint = Vector2.new(0.5, 1)
	binSub.Position = UDim2.new(0.5, 0, 1, -5)
	binSub.Size = UDim2.new(1, -12, 0, 13)
	binSub.BackgroundTransparency = 1
	binSub.Font = Enum.Font.Gotham
	binSub.TextSize = 11
	binSub.TextColor3 = Theme.PAPER
	binSub.Text = "you keep the item"
	binSub.ZIndex = 19
	binSub.Parent = binZone

	-- ---------- the way back ----------
	--
	-- One tile at the end of the bar, present only while something is shelved.
	-- A tray or a second panel would be somewhere to navigate to; this is the
	-- undo sitting next to the thing it undoes, and it costs no screen at all
	-- once the bar is arranged the way the player wants it.
	restoreTile = Instance.new("TextButton")
	restoreTile.Name = "RestoreTile"
	restoreTile.Size = UDim2.new(0, SLOT, 1, 0)
	restoreTile.LayoutOrder = 9999
	restoreTile.BackgroundColor3 = Theme.PAPER
	restoreTile.BackgroundTransparency = 0.15
	restoreTile.BorderSizePixel = 0
	restoreTile.AutoButtonColor = true
	restoreTile.Font = Enum.Font.FredokaOne
	restoreTile.TextSize = 22
	restoreTile.TextColor3 = Theme.MUTED
	restoreTile.Text = utf8.char(0x1F5D1)
	restoreTile.Visible = false
	restoreTile.Parent = frame

	local restoreCorner = Instance.new("UICorner")
	restoreCorner.CornerRadius = UDim.new(0, 10)
	restoreCorner.Parent = restoreTile

	local restoreEdge = Instance.new("UIStroke")
	restoreEdge.Color = Theme.MUTED
	restoreEdge.Thickness = 1.5
	restoreEdge.Parent = restoreTile

	restoreCount = Instance.new("TextLabel")
	restoreCount.Size = UDim2.new(1, -6, 0, 16)
	restoreCount.Position = UDim2.new(0, 3, 1, -18)
	restoreCount.BackgroundTransparency = 1
	restoreCount.Font = Enum.Font.GothamBold
	restoreCount.TextSize = 11
	restoreCount.TextColor3 = Theme.INK
	restoreCount.Text = ""
	restoreCount.Parent = restoreTile

	restoreTile.Activated:Connect(function()
		shelved = {}
		save()
		HotBar.refresh()
		-- Restoring reopens the key row, so the labels have to be repainted.
		announceArranged()
	end)

	-- One connection for the whole bar rather than two per slot. A drag that
	-- leaves the tile it started on still has to be tracked, so movement and
	-- release are watched globally and only the press is per-slot.
	UserInputService.InputChanged:Connect(function(input)
		if drag.key == nil then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			trackDrag(input)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if drag.key == nil then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			endDrag(input)
		end
	end)

	return frame
end

-- Names the item above the bar, or clears it with nil.
--
-- A USE holds it for a moment and then lets go; a HOVER holds it for as long
-- as the pointer is there. One label serves both, because two would be two
-- things fighting over the same strip of screen.
function HotBar.hint(key: string?, sticky: boolean?)
	if not hintLabel then
		return
	end
	hintKey = key
	local slot = if key then slots[key] else nil
	hintLabel.Text = if slot then slot.name else ""
	hintLabel.Visible = slot ~= nil
	hintUntil = if sticky then os.clock() + 1.6 else 0
end

function HotBar.register(button: TextButton, key: string, base: number, name: string?)
	local edge = Instance.new("UIStroke")
	edge.Name = "EquipRing"
	edge.Color = Theme.GOLD
	edge.Thickness = 1.5
	edge.Transparency = 1
	edge.Parent = button

	slots[key] = {
		button = button, edge = edge, key = key, base = base, held = false,
		name = name or key,
	}
	-- Named, because a probe, a test or the next person has no other way to
	-- tell eleven identical TextButtons apart -- and this bar is now something
	-- a player rearranges, so which tile is which is a question that gets
	-- asked. They were all called "TextButton" until this went in.
	button.Name = "Slot_" .. key
	button.Parent = frame

	button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		drag.key = key
		drag.live = false
		drag.origin = pointer(input)
	end)

	-- HOVER NAMES THE ITEM. Eleven tiles of 3D icons and a number is fine
	-- once you know the bar and unreadable the first time you see it -- and
	-- this audience is nine. MouseEnter is desktop-only by nature, which is
	-- why the same hint also fires on USE: a touch player never hovers
	-- anything, so the name has to arrive when they press it instead.
	-- ITS OWN Activated, alongside whatever ClientMain connected. Two
	-- handlers on one button both fire, so the throw and the name stay
	-- separate concerns -- and this way the hint arrives for a TAP as well as
	-- a keypress without four tile builders each remembering to ask for it.
	button.Activated:Connect(function()
		HotBar.hint(key, true)
	end)

	button.MouseEnter:Connect(function()
		HotBar.hint(key)
	end)
	button.MouseLeave:Connect(function()
		if hintKey == key then
			HotBar.hint(nil)
		end
	end)
end

-- Called at the top of every slot's Activated handler. A press that turned
-- into a drag has already done its job; letting it also throw would mean a
-- player could never rearrange a bone without spending one.
function HotBar.suppress(): boolean
	return justDragged or drag.live
end

-- The saved arrangement, echoed back by SettingsService. Tolerates nil at
-- every level: `settings.hotbar` is absent from every save written before this
-- shipped, and an absent arrangement is exactly the default one.
function HotBar.applySettings(settings: any)
	local saved = if type(settings) == "table" then settings.hotbar else nil
	if type(saved) ~= "table" then
		return
	end

	-- REBUILT COMPLETE, never taken as given. A saved order is filtered
	-- against ITEMS -- so a removed item (the Disguise Kit) drops out rather
	-- than holding a key slot forever -- and then anything ITEMS has that the
	-- save does not is APPENDED, so a newly shipped item gets a key instead
	-- of falling off the end of the list the keys are indexed into.
	local seen: { [string]: boolean } = {}
	arrangement = {}
	if type(saved.order) == "table" then
		for _, key in ipairs(saved.order) do
			if type(key) == "string" and not seen[key] and table.find(HotBar.ITEMS, key) then
				table.insert(arrangement, key)
				seen[key] = true
			end
		end
	end
	for _, key in ipairs(HotBar.ITEMS) do
		if not seen[key] then
			table.insert(arrangement, key)
			seen[key] = true
		end
	end

	shelved = {}
	if type(saved.hidden) == "table" then
		for _, key in ipairs(saved.hidden) do
			if type(key) == "string" and table.find(HotBar.ITEMS, key) then
				shelved[key] = true
			end
		end
	end

	HotBar.refresh()
	-- A saved arrangement almost always arrives AFTER the first render, so
	-- without this every key label stays at its designed position for the
	-- whole session while the tiles sit somewhere else.
	announceArranged()
end

return HotBar
