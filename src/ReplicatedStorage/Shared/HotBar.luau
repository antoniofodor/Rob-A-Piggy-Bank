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

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Shared.Theme)
local DragRules = require(ReplicatedStorage.Shared.HotBarDrag)
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local HotBar = {}

local SLOT = 58
local GAP = 8
local SHELF_MARGIN = 16
local page = 1
local pageSize = 10
local previousPage: TextButton
local nextPage: TextButton
local pageLabel: TextLabel
local keyLabels: { TextLabel } = {}
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
	-- This list is also the ALLOWLIST a saved arrangement is filtered against,
	-- so a retired item drops out of a bar somebody had already arranged and
	-- the rest of their order survives.
	"treat", "radio",
	-- "raincoat" and "ladder" were here; both are retired with the thief kit,
	-- and dropping them is what strips them out of a saved arrangement.
}

-- Set by ClientMain. The bar knows how to lay itself out and nothing about
-- whether the player is holding anything or standing inside a wheelie bin.
HotBar.shouldShow = nil :: (() -> boolean)?

-- WHAT THE SERVER SAYS IS IN THE PLAYER'S HAND, asked rather than kept, for
-- the same reason `shouldShow` is a function: this file must not hold a second
-- copy of a state the server owns and ClientMain already watches.
--
-- It exists so a press can tell a DRAW from a PUT-AWAY before the server has
-- answered. Without it the bar names the item at the exact moment it leaves
-- your hand, which is the opposite of what the hint is for.
HotBar.heldKey = nil :: (() -> string?)?

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
	marker: Frame,
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
local slotRow: Frame
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
-- A FEW SECONDS AND THEN A FADE, rather than a blink off. The name is read by
-- somebody who has just pressed a tile and is already looking at the world
-- again, so it has to survive being glanced back at -- and a label that simply
-- vanishes reads as a flicker rather than as something that was said.
local HINT_HOLD = 2.6
local HINT_FADE = 0.45
local hintFadeUntil = 0
-- The label's resting stroke, so the fade has somewhere to return to. Written
-- once here rather than repeated at the three places that reset it.
local HINT_STROKE = 0.25

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
	input = nil :: InputObject?,
	ghost = nil :: TextButton?,
	origin = Vector2.zero,
	live = false,
}
-- A drag ends with the same InputEnded a tap does, and Activated fires after
-- it. Without this flag every rearrangement would also throw the thing being
-- rearranged.
local suppressUntil = 0
local dropMarker: Frame

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
--
-- NIL FOR A SLOT YOU HOLD NOTHING IN, WHICH IS NOT THE SAME AS NIL PAST THE
-- END OF THE ROW, and conflating the two is what this used to do. Pressing 5
-- with no bubblegum named the item over the bar and asked the server to draw
-- one, which refused by name -- so the one control this file says does
-- nothing for an item you do not hold was in fact the loudest way in the game
-- to find out you had run out. Two messages about an item that is not there,
-- from a tile that is not on screen.
--
-- THE FIX IS HERE AND EXPLICITLY NOT IN `keyOrder`, which is the tempting
-- place and is wrong. Filtering unheld items out of the ORDER would close the
-- row up behind an empty slot, and the rule is that only SHELVING does that:
-- a stock running out is not the player's doing, so that slot keeps its
-- number and the number goes unused. Renumber on stock and the key that threw
-- a 1,500-coin plunger a moment ago throws a 22,000-coin zapper. So the
-- arrangement still contains the item, `keyFor` still hands its key to the
-- shop card advertising it, and only the PRESS declines.
--
-- `held` rather than `button.Visible`: they agree today (`refresh` sets
-- visibility from exactly this and the shelf), but visibility is a fact about
-- the screen and this is a question about the player's stock -- and a bar
-- hidden entirely, which `shouldShow` does while the shop is open, must not
-- silently change what a key means.
function HotBar.itemForKey(code: Enum.KeyCode): string?
	local order = keyOrder()
	for i, slot in ipairs(KEY_SLOTS) do
		if slot.key == code then
			local key = order[i]
			local held = key ~= nil and slots[key] ~= nil and slots[key].held
			return if held then key else nil
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
	require(ReplicatedStorage.Shared.Remotes).get("SettingRequest"):FireServer("hotbar", {
		order = arrangement,
		hidden = hidden,
	})
end

-- ============================================================
-- LAYOUT
-- ============================================================

-- Keep real touch targets and page the overflow instead of shrinking ten
-- items into the joystick and jump areas. This also handles window resizing.
function HotBar.layoutFor(view: Vector2, touch: boolean, count: number)
	local compact = view.X < 1100 or view.Y < 620 or touch
	local portrait = view.Y > view.X
	local slot = if compact then 52 else SLOT
	-- A TABLET SCALES THE WHOLE BAR, the same test HUDLayout uses (touch, short
	-- side over 500). Scaled rather than given bigger slots, so every tile's
	-- inside -- icon, count, key chip -- grows with it instead of being
	-- re-laid-out; `room` is divided by it so paging still fits the screen.
	local barScale = if touch and math.min(view.X, view.Y) > 500 then 1.25 else 1
	local room = math.max(164, view.X - (if compact and not portrait then 240 else 40)) / barScale
	local allWidth = count * slot + math.max(0, count - 1) * GAP
	local limit = if compact then 5 else math.max(1, count)
	local paged = count > limit or allWidth > room
	local capacity = if paged then math.clamp(math.floor((room - 96) / (slot + GAP)), 1, limit) else math.max(1, count)
	return { slot = slot, capacity = capacity, bottom = if portrait then 270 else 22, room = room, scale = barScale }
end

local function visibleItems(): { TextButton }
	local items = {}
	-- Include newly registered catalogue items even before they have a saved
	-- arrangement entry (for example, the ladder).
	for key, slot in pairs(slots) do
		if slot.held and not shelved[key] then table.insert(items, slot.button) end
	end
	table.sort(items, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	return items
end

function HotBar.refresh()
	if not frame then return end
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
		pageLabel.Visible = false
		hintLabel.Visible = false
		-- The bar going away takes its hint's clocks with it. Left running,
		-- the fade would go on counting against a hidden label and put a
		-- half-transparent name back the next time one was shown.
		hintKey = nil
		hintUntil = 0
		hintFadeUntil = 0
		hintLabel.TextTransparency = 0
		hintLabel.TextStrokeTransparency = HINT_STROKE
		return
	end

	local items = visibleItems()
	if shelvedHeld > 0 then table.insert(items, restoreTile) end
	local gui = frame.Parent :: ScreenGui
	local fit = HotBar.layoutFor(gui.AbsoluteSize, UserInputService.TouchEnabled, #items)
	pageSize = fit.capacity
	local pages = math.max(1, math.ceil(#items / pageSize))
	page = math.clamp(page, 1, pages)
	local rowCount = if pages > 1 then pageSize else #items
	local rowWidth = rowCount * fit.slot + math.max(0, rowCount - 1) * GAP
	frame.Size = UDim2.fromOffset(rowWidth + (if pages > 1 then 104 else 0), 60)
	slotRow.Size = UDim2.fromOffset(rowWidth, 60)
	slotRow.Position = UDim2.fromOffset(if pages > 1 then 52 else 0, 0)
	for index, item in ipairs(items) do
		item.Size = UDim2.fromOffset(fit.slot, 60)
		item.Visible = math.ceil(index / pageSize) == page
	end
	previousPage.Visible = pages > 1
	nextPage.Visible = pages > 1
	previousPage:SetAttribute("Available", page > 1)
	nextPage:SetAttribute("Available", page < pages)
	for _, control in { previousPage, nextPage } do
		local enabled = control:GetAttribute("Available") == true
		control.Active = enabled
		for _, d in control:GetChildren() do
			if d:IsA("Frame") then d.BackgroundTransparency = if enabled then 0 else 0.65 end
		end
	end
	frame.Position = UDim2.new(0.5, 0, 1, -fit.bottom)
	scale.Scale = fit.scale
	-- Everything that sits ABOVE the bar is measured from its top, which moves
	-- up with the scale.
	hintLabel.Position = UDim2.new(0.5, 0, 1, -fit.bottom - 60 * fit.scale - 5)
	binZone.Position = UDim2.new(0.5, 0, 1, -fit.bottom - 60 * fit.scale - SHELF_MARGIN)
	pageLabel.Position = UDim2.new(0.5, 0, 1, -fit.bottom + 17)
	pageLabel.Text = string.format("%d / %d", page, pages)
	pageLabel.Visible = show and pages > 1
	for _, label in keyLabels do
		label.Visible = not UserInputService.TouchEnabled or label.Text == "ON"
	end
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
	local changed = key ~= equippedKey
	equippedKey = key
	for slotKey, slot in pairs(slots) do
		local on = slotKey == key
		slot.edge.Transparency = 1
		slot.marker.Visible = on
		slot.button.BackgroundTransparency = 1
	end
	-- Number keys can select an item on another page. Bring it into view.
	if changed and key and slots[key] then
		local index = table.find(visibleItems(), slots[key].button)
		if index then page = math.ceil(index / pageSize) end
		HotBar.refresh()
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

-- InputObject.Position and AbsolutePosition share CoreUISafeInsets space.
-- Convert only when placing a child under the ScreenGui, whose origin can
-- be above the topbar (or shifted by a device cutout).
local TouchOrigin = require(script.Parent.TouchOrigin)
-- Touches that slid onto a tile rather than started on it; see `register`.
local strayTouches: { [InputObject]: boolean } = {}

local function pointer(input: InputObject): Vector2
	return Vector2.new(input.Position.X, input.Position.Y)
end

local function dropBefore(x: number): string?
	local visible = {}
	for _, slot in pairs(slots) do
		if slot.button.Visible then
			table.insert(visible, {key = slot.key,
				x = slot.button.AbsolutePosition.X + slot.button.AbsoluteSize.X / 2})
		end
	end
	return DragRules.before(arrangement, drag.key or "", visible, x)
end

-- Only this explicit target shelves an item. Releasing over the world
-- cancels instead of silently hiding an item during a sideways reorder.
local function overBin(p: Vector2): boolean
	return binZone.Visible and DragRules.contains(p, binZone.AbsolutePosition, binZone.AbsoluteSize)
end

local function overRow(p: Vector2): boolean
	return DragRules.contains(p, slotRow.AbsolutePosition - Vector2.new(12, 12),
		slotRow.AbsoluteSize + Vector2.new(24, 24))
end

local function endDrag(input: InputObject?)
	if drag.ghost then
		drag.ghost:Destroy()
		drag.ghost = nil
	end
	local key = drag.key
	if key and slots[key] and drag.live then
		if input and input.UserInputState ~= Enum.UserInputState.Cancel then
			local p = pointer(input)
			if overBin(p) then
				shelved[key] = true
				save()
			elseif overRow(p) then
				local before = dropBefore(p.X)
				if before ~= key then arrange(key, before); save() end
			end
		end
		-- Activated can arrive after InputEnded's deferred callbacks.
		suppressUntil = os.clock() + 0.25
	end
	binZone.Visible = false
	dropMarker.Visible = false
	drag.key, drag.input, drag.live = nil, nil, false
	HotBar.refresh()
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
	ghost.BackgroundTransparency = 1
	ghost.Size = UDim2.fromOffset(slot.button.AbsoluteSize.X, slot.button.AbsoluteSize.Y)
	ghost.AnchorPoint = Vector2.new(0.5, 0.5)
	ghost.ZIndex = 20
	for _, d in ipairs(ghost:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.ZIndex = 21
		end
	end
	ghost.Parent = frame.Parent
	drag.ghost = ghost

	slot.button.BackgroundTransparency = 1
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
	local gui = frame.Parent :: ScreenGui
	if ghost then
		local localPoint = p - gui.AbsolutePosition
		ghost.Position = UDim2.fromOffset(localPoint.X, localPoint.Y)
	end
	local storing = overBin(p)
	binZone.BackgroundColor3 = if storing then Theme.PIG_DEEP else Theme.PAPER
	dropMarker.Visible = not storing and overRow(p)
	if dropMarker.Visible then
		local closest, distance = nil, math.huge
		for _, slot in pairs(slots) do
			if slot.button.Visible then
				local delta = math.abs(p.X - slot.button.AbsolutePosition.X - slot.button.AbsoluteSize.X / 2)
				if delta < distance then closest, distance = slot.button, delta end
			end
		end
		if closest then
			local at = closest.AbsolutePosition - gui.AbsolutePosition
			dropMarker.Position = UDim2.fromOffset(at.X, at.Y)
			dropMarker.Size = UDim2.fromOffset(closest.AbsoluteSize.X, closest.AbsoluteSize.Y)
		end
	end
	-- Keep the row still while aiming. Commit the reorder once on release.
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
	frame.Size = UDim2.new(0, 0, 0, 60)
	frame.AutomaticSize = Enum.AutomaticSize.None
	frame.Position = UDim2.new(0.5, 0, 1, -20)
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.BackgroundTransparency = 1
	frame.Visible = false
	frame.Parent = gui
	slotRow = Instance.new("Frame")
	slotRow.Name = "Items"
	slotRow.BackgroundTransparency = 1
	slotRow.Size = UDim2.fromScale(1, 1)
	slotRow.Parent = frame

	dropMarker = Instance.new("Frame")
	dropMarker.Name = "HotBarDropTarget"
	dropMarker.BackgroundTransparency = 1
	dropMarker.Visible = false
	dropMarker.ZIndex = 18
	dropMarker.Parent = gui
	Theme.corner(dropMarker, 12)
	Theme.outline(dropMarker, 3, Theme.GOLD)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = slotRow

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
	--
	-- THE FADE IS DRIVEN HERE TOO rather than with a Tween, because this loop
	-- already exists and a tween would need cancelling from the three places
	-- that can interrupt it -- a second press, a hover, and the bar hiding.
	-- An elapsed fraction cannot be left half-applied by any of them.
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if hintUntil > 0 and now > hintUntil then
			hintUntil = 0
			hintFadeUntil = now + HINT_FADE
		end
		if hintFadeUntil > 0 then
			local left = hintFadeUntil - now
			if left <= 0 then
				HotBar.hint(nil)
			else
				local gone = 1 - left / HINT_FADE
				hintLabel.TextTransparency = gone
				hintLabel.TextStrokeTransparency = HINT_STROKE + gone * (1 - HINT_STROKE)
			end
		end
	end)

	scale = Instance.new("UIScale")
	scale.Parent = frame

	local function arrow(name: string, direction: number, order: number): TextButton
		local control = Instance.new("TextButton")
		control.Name = name
		control.Size = UDim2.fromOffset(44, 60)
		control.LayoutOrder = order
		control.BackgroundTransparency = 1
		control.Text = ""
		control.AutoButtonColor = false
		control.Visible = false
		control.Parent = frame
		for _, tilt in { -1, 1 } do
			local line = Instance.new("Frame")
			line.Size = UDim2.fromOffset(17, 7)
			line.AnchorPoint = Vector2.new(0.5, 0.5)
			line.Position = UDim2.fromOffset(22, 29 + tilt * 5)
			line.Rotation = direction * tilt * -40
			line.BackgroundColor3 = Theme.GOLD
			line.BorderSizePixel = 0
			line.Parent = control
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(1, 0)
			corner.Parent = line
			Theme.outline(line, 2)
		end
		control.Activated:Connect(function()
			if control:GetAttribute("Available") ~= true or drag.live then return end
			page += direction
			HotBar.hint(nil)
			HotBar.refresh()
		end)
		return control
	end
	previousPage = arrow("PreviousPage", -1, -1)
	nextPage = arrow("NextPage", 1, 10000)
	nextPage.Position = UDim2.new(1, -44, 0, 0)
	pageLabel = Instance.new("TextLabel")
	pageLabel.Name = "HotBarPage"
	pageLabel.Size = UDim2.fromOffset(80, 16)
	pageLabel.AnchorPoint = Vector2.new(0.5, 1)
	pageLabel.BackgroundTransparency = 1
	pageLabel.Font = Theme.FONT
	pageLabel.TextSize = 12
	pageLabel.TextColor3 = Theme.PAPER
	pageLabel.TextStrokeColor3 = Theme.INK
	pageLabel.TextStrokeTransparency = 0
	pageLabel.Visible = false
	pageLabel.Parent = gui

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
	binZone.Size = UDim2.fromOffset(164, 46)
	-- DEEPER THAN `STOP_INK`, which is solved for TEXT on paper and lands
	-- this the other way round -- paper on it measured 4.51 against a
	-- floor of 4.5. At (168, 50, 36) it is 6.27.
	binZone.BackgroundColor3 = Theme.PAPER
	binZone.BackgroundTransparency = 0
	binZone.BorderSizePixel = 0
	binZone.Visible = false
	binZone.ZIndex = 18
	binZone.Parent = gui

	local binCorner = Instance.new("UICorner")
	binCorner.CornerRadius = UDim.new(0, 12)
	binCorner.Parent = binZone

	local binEdge = Instance.new("UIStroke")
	binEdge.Color = Theme.INK
	binEdge.Thickness = 2
	binEdge.Transparency = 0
	binEdge.Parent = binZone

	local binText = Instance.new("TextLabel")
	binText.Size = UDim2.new(1, -12, 0, 26)
	binText.Position = UDim2.new(0, 6, 0, 6)
	binText.BackgroundTransparency = 1
	binText.Font = Enum.Font.GothamBold
	binText.TextSize = 14
	binText.TextColor3 = Theme.INK
	binText.Text = "STORE IN BAG"
	binText.ZIndex = 19
	binText.Parent = binZone

	local binSub = Instance.new("TextLabel")
	binSub.AnchorPoint = Vector2.new(0.5, 1)
	binSub.Position = UDim2.new(0.5, 0, 1, -5)
	binSub.Size = UDim2.new(1, -12, 0, 13)
	binSub.BackgroundTransparency = 1
	binSub.Font = Enum.Font.Gotham
	binSub.TextSize = 11
	binSub.TextColor3 = Theme.MUTED
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
	restoreTile.BackgroundTransparency = 1
	restoreTile.BorderSizePixel = 0
	restoreTile.AutoButtonColor = false
	restoreTile.Font = Enum.Font.FredokaOne
	restoreTile.TextSize = 40
	restoreTile.TextColor3 = Theme.GOLD
	restoreTile.TextStrokeColor3 = Theme.INK
	restoreTile.TextStrokeTransparency = 0
	restoreTile.Text = utf8.char(0x21B6)
	restoreTile:SetAttribute("AccessibleLabel", "Restore hidden items")
	restoreTile.Visible = false
	restoreTile.Parent = slotRow

	local restoreCorner = Instance.new("UICorner")
	restoreCorner.CornerRadius = UDim.new(0, 10)
	restoreCorner.Parent = restoreTile

	local restoreEdge = Instance.new("UIStroke")
	restoreEdge.Color = Theme.MUTED
	restoreEdge.Thickness = 0
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
	restoreCount.Size = UDim2.fromOffset(24, 18)
	restoreCount.AnchorPoint = Vector2.new(1, 1)
	restoreCount.Position = UDim2.new(1, -1, 1, -1)
	restoreCount.BackgroundColor3 = Theme.PAPER
	restoreCount.BackgroundTransparency = 0
	local restoreBadgeCorner = restoreCorner:Clone()
	restoreBadgeCorner.Parent = restoreCount
	Theme.outline(restoreCount, 2)

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
		if DragRules.owns(drag.input, input, false) then
			trackDrag(input)
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		-- The stray touch's lift: suppress the Activated it would fire on
		-- whatever tile it ended over, exactly as a finished drag does.
		if strayTouches[input] then
			strayTouches[input] = nil
			suppressUntil = os.clock() + 0.25
			return
		end
		if drag.key == nil then
			return
		end
		if DragRules.owns(drag.input, input, true) then
			endDrag(input)
		end
	end)

	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if drag.key then endDrag(nil) else HotBar.refresh() end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		if drag.key then endDrag(nil) end
	end)
	UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(HotBar.refresh)
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
	-- ANY NEW HINT CANCELS A RUNNING FADE AND PUTS THE INK BACK. Without this
	-- the second press of a key shows a half-faded name, because the label
	-- keeps whatever transparency the last fade left on it.
	hintFadeUntil = 0
	hintLabel.TextTransparency = 0
	hintLabel.TextStrokeTransparency = HINT_STROKE
	hintUntil = if sticky then os.clock() + HINT_HOLD else 0
end

function HotBar.register(button: TextButton, key: string, base: number, name: string?)
	button.BackgroundTransparency = 1
	button.AutoButtonColor = false
	local edge = Instance.new("UIStroke")
	edge.Name = "EquipRing"
	edge.Color = Theme.GOLD
	edge.Thickness = 1.5
	edge.Transparency = 1
	edge.Parent = button
	local marker = Instance.new("Frame")
	marker.Name = "Equipped"
	marker.Size = UDim2.new(0.65, 0, 0, 5)
	marker.Position = UDim2.new(0.5, 0, 1, 2)
	marker.AnchorPoint = Vector2.new(0.5, 0)
	marker.BackgroundColor3 = Theme.GOLD
	marker.BorderSizePixel = 0
	marker.Visible = false
	marker.Parent = button
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = marker
	Theme.outline(marker, 2)

	slots[key] = {
		button = button, edge = edge, marker = marker, key = key, base = base, held = false,
		name = name or key,
	}
	-- Named, because a probe, a test or the next person has no other way to
	-- tell eleven identical TextButtons apart -- and this bar is now something
	-- a player rearranges, so which tile is which is a question that gets
	-- asked. They were all called "TextButton" until this went in.
	button.Name = "Slot_" .. key
	button.Parent = slotRow

	button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if drag.key then return end
		-- A THUMB SLIDING OVER FROM THE STICK IS NOT A PRESS. On a phone a
		-- finger already down elsewhere can arrive here and be handed to the
		-- tile, and it used to start a drag and, on lifting, use the item.
		-- Remembered, so its release is swallowed below as well.
		if TouchOrigin.beganElsewhere(input, button) then
			strayTouches[input] = true
			return
		end
		suppressUntil = 0
		drag.key = key
		drag.input = input
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
		if HotBar.suppress() then
			return
		end
		-- PUTTING IT AWAY SAYS NOTHING, and says it immediately. Pressing the
		-- key of the item already in hand is a put-away, so the name goes at
		-- once rather than being shown for two and a half seconds and then
		-- faded -- a label naming something you have just stopped holding.
		if HotBar.heldKey and HotBar.heldKey() == key then
			HotBar.hint(nil)
		else
			HotBar.hint(key, true)
		end
	end)

	button.MouseEnter:Connect(function()
		HotBar.hint(key)
	end)
	button.MouseLeave:Connect(function()
		-- A TIMED HINT OUTLIVES THE POINTER, and not checking that is what made
		-- a tap's name vanish the instant it appeared.
		--
		-- `Activated` and `MouseLeave` both fire on a release: on a touchscreen
		-- every tap ends with the pointer leaving, and on a mouse the click
		-- that fires this often re-renders the bar underneath the cursor. So
		-- the use-hint set a moment earlier was cleared by the same gesture
		-- that asked for it, every time.
		--
		-- Only a HOVER hint is the pointer's to take away; a hint on the clock
		-- belongs to the clock.
		if hintKey == key and hintUntil == 0 and hintFadeUntil == 0 then
			HotBar.hint(nil)
		end
	end)
end

-- The four item catalogues supply the real, static 3D model and live text.
-- Give them one consistent HUD treatment once those children exist.
function HotBar.styleSlot(button: TextButton, count: TextLabel, key: TextLabel)
	local icon = button:FindFirstChildOfClass("ViewportFrame")
	if icon then
		icon.Size = UDim2.new(1, -2, 1, -8)
		icon.Position = UDim2.fromOffset(1, -2)
		icon.BackgroundTransparency = 1
	end
	count.Name = "Quantity"
	count.Size = UDim2.fromOffset(30, 19)
	count.Position = UDim2.new(1, -1, 1, -1)
	count.AnchorPoint = Vector2.new(1, 1)
	count.BackgroundColor3 = Theme.PAPER
	count.BackgroundTransparency = 0
	count.TextColor3 = Theme.INK
	count.TextStrokeTransparency = 1
	count.TextXAlignment = Enum.TextXAlignment.Center
	count.TextSize = 13
	count.TextScaled = true
	count.ZIndex = 4
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = 13
	cap.Parent = count
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 8)
	round.Parent = count
	Theme.outline(count, 2)
	key.Name = "Key"
	key.Size = UDim2.fromOffset(22, 17)
	key.Position = UDim2.fromOffset(1, 0)
	key.BackgroundColor3 = Theme.INK
	key.BackgroundTransparency = 0
	key.TextColor3 = Theme.PAPER
	key.TextStrokeTransparency = 1
	key.TextXAlignment = Enum.TextXAlignment.Center
	key.TextScaled = false
	key.TextSize = 11
	key.ZIndex = 4
	local keyRound = round:Clone()
	keyRound.Parent = key
	table.insert(keyLabels, key)
	local function showKey()
		key.Visible = not UserInputService.TouchEnabled or key.Text == "ON"
	end
	key:GetPropertyChangedSignal("Text"):Connect(showKey)
	showKey()
end

-- Called at the top of every slot's Activated handler. A press that turned
-- into a drag has already done its job; letting it also throw would mean a
-- player could never rearrange a bone without spending one.
function HotBar.suppress(): boolean
	return os.clock() < suppressUntil or drag.live
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
