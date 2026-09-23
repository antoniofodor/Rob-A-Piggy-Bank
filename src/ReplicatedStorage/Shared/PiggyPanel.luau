--!strict
-- The balance card in the top-right corner. It draws ONE number, straight
-- off `StateUpdate`, and derives nothing -- see the note above `DESIGN_W`
-- for what this panel used to carry and why each piece went. Keeping the
-- widget here also frees ClientMain registers.
local Config = require(script.Parent.Config)
local Theme = require(script.Parent.Theme)

local PiggyPanel = {}
-- The width of every chip stacked under this panel. Shared with `Wanted`,
-- which is the neighbour it has to line up with.
PiggyPanel.CHIP_W = 176

local function shape(parent: Instance, name: string, x: number, y: number,
	w: number, h: number, colour: Color3, radius: number, z: number?): Frame

	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = UDim2.fromOffset(x, y)
	frame.Size = UDim2.fromOffset(w, h)
	frame.BackgroundColor3 = colour
	frame.BorderSizePixel = 0
	frame.ZIndex = z or 1
	Theme.corner(frame, radius)
	frame.Parent = parent
	return frame
end

local function label(parent: Instance, name: string, text: string, x: number,
	y: number, w: number, h: number, size: number, colour: Color3): TextLabel

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = name
	textLabel.Position = UDim2.fromOffset(x, y)
	textLabel.Size = UDim2.fromOffset(w, h)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Theme.FONT
	textLabel.TextSize = size
	textLabel.TextColor3 = colour
	textLabel.TextXAlignment = Enum.TextXAlignment.Left
	textLabel.Text = text
	textLabel.Parent = parent
	return textLabel
end

-- THE PANEL IS ONE PLATE AND ONE NUMBER (designer call 2026-09-21).
--
-- IT WAS A MEDALLION, A RATE PILL, A CAPACITY BAR AND AN ETA. Every one of
-- those was built for a reason recorded at the time, and the reasons are
-- kept here rather than deleted with the geometry, because what a retired
-- readout was FOR is exactly what somebody needs when they propose putting
-- it back.
--
--   * THE MEDALLION showed the skin you are wearing, in its tier's colour,
--     painted by the shop's own icon builder so the HUD and the shop could
--     never disagree about one skin. What it cost was the largest object on
--     the HUD, permanently, to say something the player already knows.
--   * THE RATE PILL printed income per second, and was the one place a
--     daily boost was visible -- `CLAUDE.md` calls a buff nobody can see a
--     trap. THAT ENTRY PREDATES THE BOOST PILL AND IS WHY THIS WAS
--     AFFORDABLE: `HUDWidgets.renderBoost` puts a running boost on its own
--     pill in the bottom-left stack, carrying the multiplier and the time
--     left. Checked before removing this rather than assumed.
--   * THE BAR AND THE ETA were the standing FULL warning, and a full pig
--     stops earning -- the clock the whole spend-it-or-lose-it loop runs
--     on. WHAT IS LEFT SAYING SO is the refusal on a collect, which
--     notifies that the pig only had room for part of a buffer and the
--     rest is still waiting. So the state is still SAID, at the moment it
--     costs the player something, rather than shown standing. That is a
--     real trade and it is the first thing to revisit if full ever starts
--     reading as a surprise.
--
-- WHAT SURVIVES IS THE RULE THIS PANEL HAS ALWAYS KEPT: the HUD may only
-- ever show a balance once. There is one number up here and nothing else
-- making a claim about what a player has.
--
-- 176 IS `CHIP_W`, AND THAT IS A MEASUREMENT RATHER THAN A TIDY NUMBER.
-- The widest balance this game can print is `999.9M`, measured on a live
-- client at 90px in FredokaOne at 32 -- so a plate carrying the coin, the
-- gap and that figure with real slack comes to 176, which is exactly the
-- width `Wanted` already uses. The plate and the chip under it now share a
-- width AND a right edge, which is the rule this corner is held together
-- by: three stacked things, one edge.
local DESIGN_W = PiggyPanel.CHIP_W
local PLATE_X, PLATE_Y, PLATE_W, PLATE_H = 0, 8, PiggyPanel.CHIP_W, 56
PiggyPanel.COMPACT_SCALE = 0.64

-- A dark copy of a shape, drawn under it. Siblings rather than children: under
-- ZIndexBehavior.Sibling a child always draws ABOVE its parent.
local function dropShadow(parent: Instance, of: Frame, radius: number): Frame
	local s = shape(parent, of.Name .. "Shadow", 0, 0, 0, 0, Theme.INK, radius, 0)
	s.BackgroundTransparency = 0.72
	local function sync()
		s.Position = of.Position + UDim2.fromOffset(0, 4)
		s.Size = of.Size
		s.Visible = of.Visible
	end
	of:GetPropertyChangedSignal("Position"):Connect(sync)
	of:GetPropertyChangedSignal("Size"):Connect(sync)
	of:GetPropertyChangedSignal("Visible"):Connect(sync)
	sync()
	return s
end

function PiggyPanel.new(gui: ScreenGui)
	-- The root carries nothing visible of its own: it is the frame the plate
	-- is laid out in, anchored to the top-right corner.
	local root = Instance.new("Frame")
	root.Name = "PiggyPanel"
	root.AnchorPoint = Vector2.new(1, 0)
	root.Size = UDim2.fromOffset(DESIGN_W, PLATE_Y + PLATE_H)
	root.Position = UDim2.new(1, -14, 0, 72)
	root.BackgroundTransparency = 1
	root.ZIndex = 1
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = root

	-- ---------------------------------------------------------- coin plate
	local plate = shape(root, "CoinPlate", PLATE_X, PLATE_Y, PLATE_W, PLATE_H,
		Theme.PAPER, 18, 2)
	Theme.outline(plate, 2.5, Theme.INK)
	Theme.gloss(plate, Theme.PAPER, Theme.PAPER_DEEP)
	dropShadow(root, plate, 18)

	-- A DRAWN COIN RATHER THAN THE EMOJI, and paper under it rather than
	-- gold: gold means money and a gold coin on a gold ground has nothing to
	-- stand out against. One gold object on a paper card is the whole rule.
	local coinIcon = Theme.coin(plate, 30, "CoinIcon")
	coinIcon.Position = UDim2.fromOffset(14, (PLATE_H - 30) // 2)
	-- 104 against a measured widest of 90, so the figure never reaches its
	-- own frame -- the state this project records as `TextFits` reporting
	-- true while the glyphs sit exactly on the edge. Truncation is the
	-- backstop for a balance nobody has reached yet rather than the plan.
	local coins = label(plate, "Coins", "0", 52, 8, 104, 40, 32, Theme.INK)
	coins.TextTruncate = Enum.TextTruncate.AtEnd

	local function layout()
		local metrics = require(script.Parent.HUDLayout).metrics(gui.AbsoluteSize)
		local compact = metrics.compact
		-- ONE SHAPE AT EVERY SIZE NOW. The plate used to lose 14 pixels on a
		-- phone because the ETA line came off it; there is no second line to
		-- drop, so compact is the same panel drawn smaller and nothing about
		-- it can be laid out twice.
		local designH = PLATE_Y + PLATE_H
		local drawn = (if compact then PiggyPanel.COMPACT_SCALE else 1) * metrics.bankScale
		root.Size = UDim2.fromOffset(DESIGN_W, designH)
		root.Position = UDim2.new(1, -14, 0, metrics.bankTop)
		scale.Scale = drawn
		-- Built later by Wanted. Hung under the panel's DRAWN bottom, so a
		-- resize can never make the column overlap -- and it shares this
		-- plate's width and right edge, which is what makes the corner read
		-- as a column rather than as two objects.
		local chip = gui:FindFirstChild("Wanted")
		if chip and chip:IsA("GuiObject") then
			chip.Position = UDim2.new(1, -14, 0, metrics.bankTop + designH * drawn + 8)
			local chipScale = chip:FindFirstChildOfClass("UIScale")
			if not chipScale then chipScale = Instance.new("UIScale"); chipScale.Parent = chip end
			chipScale.Scale = if compact then 0.75 else 1
		end
	end
	layout()
	local layoutConnection = gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	local childConnection = gui.ChildAdded:Connect(function(child)
		if child.Name == "Wanted" then
			task.defer(layout)
		end
	end)
	root.Destroying:Connect(function()
		layoutConnection:Disconnect()
		childConnection:Disconnect()
	end)

	local controller = {}
	-- THE SKIN ENTRY POINTS SURVIVE AS NO-OPS, WHICH IS A DECISION RATHER
	-- THAN AN OVERSIGHT. `ClientMain` calls `showWorn` from three places --
	-- a cosmetics push, a wardrobe change and a join -- and it fills in
	-- `paintSkin` with the shop's own icon builder. Deleting the medallion
	-- and leaving those calls to index a nil would take the HUD down at a
	-- moment that has nothing to do with this panel; deleting them from
	-- `ClientMain` instead means editing a chunk that is at the 200-local
	-- ceiling, for no behaviour. So the door stays and opens onto nothing,
	-- the same call `SeasonService.start` already makes -- and because
	-- `setSkin` returns before touching `paint`, the shop icon it would have
	-- built is never built either.
	controller.paintSkin = nil :: any
	controller.showWorn = nil :: any
	function controller:setSkin(_key: string?, _paint: ((string, Frame) -> ())?, _force: boolean?)
	end
	function controller:render(state: any)
		-- ONE FIELD READ FROM THE PUSH, and the others are deliberately left
		-- on it rather than removed from `StateUpdate`: `capacity`, `rate`,
		-- `full`, `boostMultiplier` and `boostLeft` all have other readers
		-- (the boost pill, the upgrade cards, the first-job card), so the
		-- payload is unchanged and only this panel stopped drawing them.
		coins.Text = Config.formatCoins(math.max(0, state.coins or 0))
	end
	return controller
end

return PiggyPanel
