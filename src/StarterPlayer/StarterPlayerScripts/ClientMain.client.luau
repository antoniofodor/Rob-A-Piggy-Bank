--!strict
--[[
	ClientMain

	The phase-1 HUD: one piggy bank panel carrying the whole balance, and the
	two upgrade buttons.

	Everything here is display only. The client never computes a balance --
	it renders whatever the last StateUpdate said. If this file and the server
	ever disagree, the server is right by construction.

	Deliberately oversized type and chunky buttons: the whole HUD needs to be
	readable at a glance by a nine-year-old on a school laptop.
]]

local CollectionService = game:GetService("CollectionService")
-- MarketplaceService is NOT required here. The Robux tab (`Shared/PremiumShop`)
-- owns every purchase prompt in the game, and this chunk's last caller -- the
-- Rides tab's Style Pack advert -- became a link to that tab. Worth stating
-- rather than silently deleting: this file sits against Luau's 200-local
-- register ceiling, which has taken the whole HUD down nine times, so a service
-- local nothing calls is a register that could cost the next feature.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local BoneModel = require(ReplicatedStorage.Shared.BoneModel)
local PigGear = require(ReplicatedStorage.Shared.PigGear)
local RideModel = require(ReplicatedStorage.Shared.RideModel)
local PlayerGear = require(ReplicatedStorage.Shared.PlayerGear)
-- Geometry that used to live server-side. The shop renders the REAL house,
-- ornament and piggy now, from the same builders that put them on a plot.
local House = require(ReplicatedStorage.Shared.House)
local Decor = require(ReplicatedStorage.Shared.Decor)
local PiggyModel = require(ReplicatedStorage.Shared.PiggyModel)
local RidePose = require(ReplicatedStorage.Shared.RidePose)
local Music = require(ReplicatedStorage.Shared.Music)
local GadgetModel = require(ReplicatedStorage.Shared.GadgetModel)
local HomeModel = require(ReplicatedStorage.Shared.HomeModel)
local ThiefModel = require(ReplicatedStorage.Shared.ThiefModel)
-- The endgame houses' light show. A module rather than another inline
-- animator beside the skins and the moat, because this chunk is near Luau's
-- 200-local ceiling and a function body gets its own register file: the whole
-- feature costs one local here instead of a dozen.
local HouseFX = require(ReplicatedStorage.Shared.HouseFX)
-- The saucer's lights and the tractor beams. A module for the same reason
-- HouseFX is one: this chunk is at Luau's 200-local ceiling and a function
-- body gets its own register file.
local RaidFX = require(ReplicatedStorage.Shared.RaidFX)
-- The event drop reel. A module for the same reason RaidFX and HouseFX are:
-- this chunk is at Luau's 200-local ceiling and a function body gets its own
-- register file.
local SpinWheel = require(ReplicatedStorage.Shared.SpinWheel)
-- The crates tab, which is what finally reaches `ChestService` -- four hundred
-- lines of working server that no player could get to, because there was no
-- button. A module for the reason every one above it is: this chunk is at
-- Luau's 200-local ceiling and the tab wants a dozen names of its own, so
-- inline it would cost the ENTIRE HUD rather than the tab.
local Crates = require(ReplicatedStorage.Shared.Crates)
local AdminPanel = require(ReplicatedStorage.Shared.AdminPanel)
-- The throwables bar: its frame, its layout, its fixed key map, and the drag
-- that lets a player arrange it. A module for the same reason the three above
-- are -- and this one HANDS REGISTERS BACK, because the bar's own state moved
-- in with it: four top-level locals here became one.
local HotBar = require(ReplicatedStorage.Shared.HotBar)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Announce = require(ReplicatedStorage.Shared.Announce)
-- The rebirth button and the page that explains the trade before a player
-- makes it for the first time. A module for the same reason, and this one
-- also hands a register back: the button, its ready flag and its sync
-- function were three top-level locals here and are none.
local Rebirth = require(ReplicatedStorage.Shared.Rebirth)

-- The shop's own visual vocabulary -- outline, round, gloss, pop -- and the
-- hue every category is known by. One local for the whole kit; see the module
-- for why the shop is not drawn in the HUD's language.
local ShopStyle = require(ReplicatedStorage.Shared.ShopStyle)

local player = Players.LocalPlayer

-- Defined down in the prompt-visibility section; needed earlier so an
-- upgrade purchase can re-time the steal prompts immediately.
local refreshStealPrompts: () -> ()
-- Set progress. UP HERE, not beside homeUI, because the cosmetic card
-- renderer four hundred lines below reads it -- and a `local` declared after
-- its reader compiles against a nil GLOBAL and dies at the call, naming
-- neither the variable nor the cause. One table rather than four locals: this
-- chunk is near Luau's 200-register ceiling and the budget is spent by more
-- than one feature at a time. `loot` is kept at zero rather than removed: the
-- set cards still branch on `info.loot` to keep an unpriced set item out of
-- the coin formatter, and a nil there would be a second thing to reason about.
local setUI = { loot = 0, sets = nil :: any, cards = {}, dirty = false }
-- Declared here and assigned four hundred lines down, for the same reason.
-- The cosmetic cards render 3D previews now and are built well above the
-- viewport helper: a `local function` down there is invisible to them, and
-- Luau does not error on that -- it reads a nil GLOBAL and dies at the call
-- with "attempt to call a nil value" naming neither the function nor the
-- cause. Fourth time in this project.
local makeModelIcon: (GuiObject, Model, UDim2, UDim2, boolean) -> ViewportFrame
-- Same reason again: the effect cards are built well above this.
local makeEffectIcon: (GuiObject, string, any?) -> ()
local playerGui = player:WaitForChild("PlayerGui")

-- SEPARATOR AND BANNER ICONS, in one place and built with utf8.char.
--
-- The banners used to join their halves with a double hyphen -- "PURSUIT --
-- LOSE THEM IN 12s" -- which renders as exactly that, two hyphens, and reads
-- as a typo rather than as punctuation. A middot is the separator the rest of
-- this game already uses (the plot sign, the ride tiles), so the banners now
-- match instead of inventing a third convention.
--
-- The icons are the same ones `Config.NOTIFY` puts on the cards, on purpose:
-- a patrol should be the same picture whether it arrives as an alert or as a
-- countdown, and until now the two systems looked like different games.
-- One table rather than four locals: this chunk is at 185 of Luau's 200
-- top-level registers, and four constants is not worth 2% of the budget.
-- ONE ENTRY LEFT, AND THAT IS THE POINT.
--
-- The siren, the car and the money bag lived here AND were about to live in
-- `Config.ANNOUNCE`, which is two copies of one character in two files -- the
-- near-identical duplicate this project keeps recording, and the exact reason
-- the event glyphs were moved out of this table once already. They are rows in
-- Config now, beside the tone and the image id they belong with.
--
-- The middot stays, because it is PUNCTUATION rather than an icon: half the
-- HUD joins two facts with it, and none of those are announcements.
local GLYPH = {
	dot = utf8.char(0x00B7),
}

-- THE HUD'S OWN PALETTE WAS THE SECOND ONE, AND IT WAS THE OLD ONE.
--
-- These five were the survivors of the cold-navy dashboard: an INK at hue
-- 221 living in the same file as `Theme.INK`, a PANEL that was the navy
-- every light surface in this game had already stopped being, and a GOLD two
-- degrees off `Theme.GOLD` for no reason anybody could name. They are aliases
-- now rather than deletions, because 76 call sites read them and a rename
-- with no behaviour in it is the change most likely to break something.
local GOLD = Theme.GOLD
local INK = Theme.INK
local PANEL = Theme.PAPER
local GOOD = Theme.GOOD
local WARN = Theme.WARN

-- The coin ladder lives in Config now. This was a byte-identical second copy
-- of EconomyService's, and a third was about to be written for the sell
-- refusal -- so the number a player reads in a toast and the number they read
-- on the HUD are one function rather than three that agree today. Still one
-- local, so the register budget is unchanged.
local format = Config.formatCoins

-- Shared render state, declared above everything that reads it: a local
-- declared *after* a function that uses it silently becomes a nil global.
local latestCoins = 0
local latestUpgrades: { [string]: any } = {}
-- What the steal prompt needs to say. It used to carry the lockpick level,
-- the sack level and the live event multiplier as well, because the prompt
-- computed the take -- and all three went dead the day the crack made a take
-- a decision rather than a constant. Removed rather than left assigned: this
-- chunk is at Luau's 200-register ceiling and state nothing reads is a
-- register that a real feature cannot have.
--
-- ONE TABLE rather than separate locals, for the same reason.
--
-- The event multiplier came back once, for the SMASH card, and went again
-- with the event that set it: Midnight Heist was the last thing doubling a
-- take, and it was retired with the piggy-collection pivot. No event moves
-- what a grab is worth now, so nothing here carries one.
local stealInfo = { carrying = 0 }
-- Whether the daily board is up. Read by `Rebirth.canShow`, which is wired
-- further down and would otherwise let the rebirth button sit on top of it:
-- the same collision the shop panel already had.
local dailyOpen = false

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

-- ============================================================
-- LAYOUT
-- ============================================================

local gui = Instance.new("ScreenGui")
gui.Name = "PiggyHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- The vault panel sits top right, which is where Roblox puts the default
-- player list. That list is redundant here -- the plaza has a physical
-- leaderboard, and a twelve-plot server tells you who is on it by looking
-- out of the window -- so the HUD gets the corner instead. One line to put
-- back if the list is ever wanted.
game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
-- AND THE BACKPACK, for a sharper reason than tidiness: Roblox binds the
-- number row 1..0 to it permanently, so its tool hotkeys sit directly on top
-- of this game's hot bar keys. There are no Tools here, so nothing visibly
-- broke -- but the conflict is real enough that Studio's own VirtualInput
-- refuses to send those keys while it is on, which is how it was found.
--
-- The hot bar IS this game's backpack. Two of them, one of which is always
-- empty, is one too many.
game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

-- The balance and the responsive readout column share one module.
local bankHUD = require(ReplicatedStorage.Shared.PiggyPanel).new(gui)

-- THE SHOP BUTTON, BOTTOM RIGHT, AND NOTHING ELSE NOW.
--
-- EARN FASTER and BIGGER PIGGY BANK used to sit above it here, which put the
-- two largest coin sinks in the game on the HUD while the six upgrade TREES
-- they compete with lived behind a shop tab. So the choice this economy is
-- built on -- every coin into income is a coin not into a fence -- was split
-- across two screens that were never visible at once, and only one side of it
-- was ever costed in front of you. They are rows in the Upgrades tab now,
-- beside the trees, where the comparison is the whole point of the layout.
--
-- Height is AutomaticSize rather than a literal: this stack was hard-coded to
-- 128px while its children added up to 172, so the bottom button ran off the
-- screen edge -- and the button that got cut was the one that opens the shop.
-- Anchored bottom-right, so it grows upward and the bottom edge stays put.
local shop = Instance.new("Frame")
shop.Size = UDim2.new(0, 210, 0, 0)
shop.AutomaticSize = Enum.AutomaticSize.Y
shop.Position = UDim2.new(1, -18, 1, -22)
shop.AnchorPoint = Vector2.new(1, 1)
shop.BackgroundTransparency = 1
shop.Parent = gui

-- A static column below the piggy HUD keeps the bottom clear for inventory.
-- HUDLayout fits its size and top edge to the safe screen area.
local shopLayout = Instance.new("UIListLayout")
shopLayout.FillDirection = Enum.FillDirection.Vertical
shopLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
shopLayout.VerticalAlignment = Enum.VerticalAlignment.Top
shopLayout.Padding = UDim.new(0, 6)
shopLayout.SortOrder = Enum.SortOrder.LayoutOrder
shopLayout.Parent = shop
require(ReplicatedStorage.Shared.HUDLayout).bindMenu(shop, gui)

-- ============================================================
-- ACTION BUTTONS
-- ============================================================
--
-- The three buttons a player actually presses mid-game -- SHOP, DODGE and the
-- ride TRICK -- built by one function so they read as a set rather than as
-- three things that happen to be rectangles.
--
-- THE KEYBIND IS SHOWN ONLY ON A KEYBOARD, and it is a CHIP rather than part of
-- the label. Two reasons, and the second is the one that was actually breaking
-- something. Most of this audience is on a tablet, where "SHOP  [B]" is a line
-- of noise about a key they do not have. And baking the key into the label made
-- the label's width depend on it -- which is why the dodge and trick buttons
-- had to be sized against "WHEELIE  Q" and re-measured every time either
-- changed. A corner chip is out of the text flow entirely, so the label is
-- sized by the word and nothing else.
--
-- Emoji are built with `utf8.char`, NEVER a decimal escape: the music toggle's
-- speaker glyph went in as "\240\159\148\138", something in the pipeline
-- rewrote the escapes into the bytes they named, and Luau refused the whole
-- file -- which takes down the entire HUD, not the button.
-- WRAPPED IN A do-BLOCK, and that is not tidiness. This chunk sits within a
-- couple of registers of Luau's 200-local ceiling -- adding the three icon
-- constants and this function at top level measured 202, which does not fail
-- at the button, it fails the WHOLE HUD with an error naming some innocent
-- variable. A block's locals are released at its end, so the three constants
-- cost nothing and only the function is spent.
local makeActionButton
do
	-- REQUIRED INSIDE THE BLOCK, HOLDING NO TOP-LEVEL LOCAL, which is the
	-- call `Crates` already makes here. This chunk sits within a couple of
	-- registers of Luau's 200-local ceiling and the comment below records
	-- what going over costs: not the button, the WHOLE HUD, with an error
	-- naming an innocent variable thousands of lines away.
	local Motion = require(ReplicatedStorage.Shared.Motion)

	local ICON_SHOP = utf8.char(0x1F6D2)  -- trolley
	local ICON_DODGE = utf8.char(0x1F4A8) -- dash
	local ICON_TRICK = utf8.char(0x26A1)  -- bolt
	-- A TRAINER FOR THE SNEAK, AND IT HAD NO ICON AT ALL UNTIL A SCREENSHOT
	-- SHOWED IT.
	--
	-- `makeActionButton("TiptoeButton", "SNEAK", "SNEAK", ...)` passed "SNEAK"
	-- as the ICON as well as the label, and the lookup falls back to `icon`
	-- itself when it is not a known key -- so the tile typeset the literal word
	-- SNEAK at `textSize + 12`, which is 30px across a 68px tile, straight over
	-- its own label and out across the two buttons beside it.
	--
	-- IT WAS INVISIBLE TO EVERY PROBE IN THIS PROJECT. The button built, the
	-- label was correct, the geometry was correct, and nothing errored -- the
	-- text simply drew outside the control, which is the same silent overflow
	-- the Most Wanted poster had when it printed off its own paper. Only a
	-- picture says so.
	local ICON_SNEAK = utf8.char(0x1F45F) -- trainer

	-- Icons are resolved HERE rather than by the caller, so the call sites stay
	-- short and the three buttons cannot drift onto different glyph conventions.
	local ICONS = { SHOP = ICON_SHOP, DODGE = ICON_DODGE, TRICK = ICON_TRICK,
		SNEAK = ICON_SNEAK }

	-- THE THREE CORNER BUTTONS DRAW THEIR ICONS RATHER THAN TYPESETTING THEM,
	-- AND THE REASON IS THE ONE THIS PROJECT HAS ALREADY MET TWICE.
	--
	-- An emoji renders from the colour font and IGNORES `TextColor3`. The coin
	-- badge hit that -- a gold coin on a gold ground with no way to recolour
	-- either -- and so did the piggy panel, and both ended up drawing the
	-- object out of frames instead. These are the last three that had not.
	--
	-- A BASKET WITH A COIN IN IT rather than a trolley, because the coin is
	-- what makes it THIS shop: one currency, and the only question at a card
	-- is whether you can afford it. A SATCHEL for the bag, deliberately with
	-- no coin on it, or the two buttons in one corner would read as the same
	-- control. A GEAR for settings, which is the one icon here that needs no
	-- explaining to anybody.
	local DRAWN: { [string]: (Instance, number, string?) -> Frame } = {
		BASKET = Theme.basket,
		SATCHEL = Theme.satchel,
		GEAR = Theme.gear,
	}

	-- `stacked` turns the row into a SQUARE SLOT: icon over a small label, with
	-- the key chip top-left. That is the anatomy the garage slot already has,
	-- and the dodge sits directly beside one -- two controls on the same row at
	-- the same size have to be the same KIND of object or the row reads as a
	-- button that happens to be next to a slot.
	--
	-- One function with a branch rather than two functions, because this chunk
	-- is at Luau's 200-local ceiling: a second top-level name costs a register
	-- and a parameter costs none.
	makeActionButton = function(name: string, icon: string, label: string,
		key: string, tint: Color3, size: UDim2, textSize: number, parent: Instance,
		stacked: boolean?): TextButton

		-- The three menu controls are static silhouettes with transparent hit
		-- areas. Return before the card, labels, key badges and Motion hooks.
		if name == "ShopToggle" or name == "BagToggle" or name == "SettingsToggle" then
			return require(ReplicatedStorage.Shared.MenuIcons).makeButton(name, icon, label, size, parent)
		end

		if name == "DodgeButton" or name == "TiptoeButton" or name == "TrickButton" then
			return require(ReplicatedStorage.Shared.ActionButtons).make(name, icon, label, key, parent)
		end

		local button = Instance.new("TextButton")
		button.Name = name
		button.Size = size
		-- A STACKED SLOT IS PAPER; A ROW BUTTON WEARS ITS COLOUR.
		--
		-- The note above already says a stacked control has to be the same
		-- KIND of object as the garage slot beside it, and once that slot
		-- became a paper card a blue tile next to it stopped being one.
		--
		-- It is also the only thing that MEASURES. `Theme.COOL` is a mid-tone
		-- -- it carries ink at 4.96 flat, which is thin before any shading,
		-- and the stacked label sits at the BOTTOM of the sheen where it fell
		-- to 3.17. Paper text does not rescue it either: at 3.80 it fails the
		-- same floor from the other side. A mid-tone blue cannot carry small
		-- type of EITHER polarity, so the ground had to move rather than the
		-- text. On paper the same label reads at 14.98.
		--
		-- The tint is not lost: on a stacked slot it rings the key chip, the
		-- same way a notification chip carries its tone.
		button.BackgroundColor3 = if stacked then Theme.PAPER else tint
		button.BorderSizePixel = 0
		button.AutoButtonColor = true
		-- The button itself carries no text: everything is a child, so the icon and
		-- the label can be positioned independently and the cooldown fill can sit
		-- behind both.
		button.Text = ""
		button.Parent = parent
		corner(button, 12)

		-- Lit from above, which is the whole difference between a coloured
		-- rectangle and something that looks pressable -- but SHALLOW, and
		-- that is the fix rather than a preference. The old ramp ran to
		-- (188, 188, 188), a 26% darkening, and a contrast probe reading
		-- `BackgroundColor3` cannot see it: it measures the TOP of the ramp
		-- while the label sits at the bottom. `Theme.shade` multiplies, so
		-- one number says how deep it goes and the caller's colour survives.
		Theme.shade(button, 0.9)

		-- THE INK LINE, which these never had. They carried a pale tint of
		-- their own fill at 1.5px instead -- a highlight, not an edge -- so
		-- the three loudest controls on the HUD were the only surfaces in the
		-- game without the one thing that makes everything else read as
		-- drawn.
		Theme.outline(button)

		-- A DRAWN ICON IS A FRAME AND A GLYPH IS A LABEL, so the two cannot
		-- share a variable and the sizing below has to ask which it got. The
		-- drawn one is built at a fixed pixel size rather than scaled with the
		-- button: it is assembled from parts whose own corners and strokes are
		-- in pixels, so scaling the container would leave a 2px outline on a
		-- 60px icon looking like a hairline.
		local builder = DRAWN[icon]
		local drawn: Frame? = nil
		local glyph: TextLabel? = nil

		if builder then
			-- 38 rather than 32 on a row button. The icon is the thing this
			-- control is recognised by -- a basket, a satchel, a gear -- and
			-- once it lifts off the card it is also the only part that
			-- overhangs, so it carries the whole silhouette. 38 on a 66-wide
			-- button still leaves fourteen pixels either side.
			local made = builder(button, if stacked then 34 else 38, "Icon")
			made.ZIndex = 3
			drawn = made
		else
			local g = Instance.new("TextLabel")
			g.Name = "Icon"
			g.BackgroundTransparency = 1
			g.Font = Enum.Font.GothamBold
			g.Text = ICONS[icon] or icon
			g.ZIndex = 3
			g.Parent = button
			glyph = g
		end

		local text = Instance.new("TextLabel")
		text.Name = "Label"
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.FredokaOne
		-- WHITE WITH AN INK STROKE ON A DRAWN BUTTON, AND THAT IS WHAT MAKES
		-- THE GROUND STOP MATTERING.
		--
		-- Ink type is why the stacked slots had to become paper: `Theme.COOL`
		-- is a mid-tone that carries ink at 4.96 flat and 3.17 at the bottom
		-- of its own sheen, and paper text on it fails at 3.80 from the other
		-- side -- a mid-tone cannot carry small type of EITHER polarity. A
		-- stroke sidesteps the whole argument: the label is white and its own
		-- outline supplies the contrast, so the same three words read on the
		-- shop's green, the piggy pink and the settings slate without any of
		-- the three having to be chosen for legibility.
		--
		-- It is the same instrument the plot sign and the carry banner already
		-- use, and it is why these buttons can keep their tint where the dodge
		-- tile had to give its up.
		text.TextColor3 = if builder then Theme.PAPER else Theme.INK
		text.Text = label
		text.ZIndex = 3
		text.Parent = button
		if builder then
			ShopStyle.pop(text, 2)
		end

		if drawn then
			-- ICON OVER LABEL, CENTRED, which is the anatomy the user asked for
			-- and is also the only one that works for a DRAWN icon: a frame has
			-- a real width, where a glyph could be squeezed into a 28px gutter
			-- and left the rest of the row to the text.
			--
			-- The button is 50 tall in this corner, so the icon takes the top 34
			-- and the label the bottom 14 with two to spare. Sized against the
			-- BUTTON rather than against the icon, so a taller tile grows the gap
			-- rather than overlapping the two.
			local icon = drawn :: Frame
			-- SEATED LOW, BECAUSE THE FLOAT LIFTS IT FROM HERE. This is where
			-- the icon RESTS -- what a player sees is fourteen pixels higher,
			-- which puts eight of the icon's thirty-eight above the button's
			-- own top edge. Pressing drops it back to exactly this line, so
			-- the resting seat has to clear the label underneath: 6 + 38 is
			-- 44 against a label starting at 48.
			icon.Position = UDim2.new(0.5, 0, 0, 6)
			icon.AnchorPoint = Vector2.new(0.5, 0)

			text.Size = UDim2.new(1, -6, 0, 14)
			text.Position = UDim2.new(0, 3, 1, -16)
			text.TextSize = 12
			text.TextXAlignment = Enum.TextXAlignment.Center

			-- THE FLOAT, AND IT IS THE WHOLE POINT OF THE CHANGE. The icon
			-- sits proud of its card, breathes, tips a few degrees with the
			-- bob, and DROPS onto the card while the button is held -- which
			-- is the press feedback as well, so there is no scale anywhere
			-- near a control that lives in a UIListLayout. See `Motion`.
			--
			-- A shadow only on the row buttons: they are the ones that
			-- overhang, and a shadow under something that has not left the
			-- surface is just a smudge.
			Motion.lift(button, icon, 14, true)
		elseif stacked then
			-- The icon takes the whole tile and the label sits in the bottom
			-- strip, which is where the garage slot next to it puts its own
			-- state line. Sized in the same 13 pixels for the same reason.
			local g = glyph :: TextLabel
			g.Size = UDim2.new(1, 0, 1, -16)
			g.Position = UDim2.new(0, 0, 0, -1)
			g.TextSize = textSize + 12

			text.Size = UDim2.new(1, -8, 0, 13)
			text.Position = UDim2.new(0, 4, 1, -16)
			text.TextSize = 10
			text.TextXAlignment = Enum.TextXAlignment.Center

			-- A SLOT BOBS IN PLACE AND DOES NOT OVERHANG, and that is a
			-- measurement rather than restraint. The glyph fills the whole
			-- tile here, so lifting it off the card would carry it out of the
			-- tile rather than proud of it -- and there is nowhere to go: the
			-- stance pill sits EIGHT PIXELS above the sneak slot, measured on
			-- the live HUD, against 298 pixels of clear air above the three
			-- corner buttons. Three is a breath; it still drops on a press,
			-- which is what these were missing.
			Motion.lift(button, g, 3, false)
		else
			local g = glyph :: TextLabel
			g.Size = UDim2.new(0, 28, 1, 0)
			g.Position = UDim2.new(0, 9, 0, 0)
			g.TextSize = textSize + 5

			text.Size = UDim2.new(1, -46, 1, 0)
			text.Position = UDim2.new(0, 40, 0, 0)
			text.TextSize = textSize
			text.TextXAlignment = Enum.TextXAlignment.Left
		end

		-- Keyboard only. A tablet gets the button and nothing else.
		if key ~= "" and UserInputService.KeyboardEnabled then
			local chip = Instance.new("TextLabel")
			chip.Name = "Key"
			chip.Size = UDim2.new(0, 18, 0, 16)
			chip.ZIndex = 3
			-- Top LEFT on a slot, matching the garage's V, and top right on a
			-- row, where the label is left-aligned and the corner is empty.
			if stacked then
				chip.Position = UDim2.new(0, 4, 0, 3)
				chip.AnchorPoint = Vector2.new(0, 0)
				chip.BackgroundTransparency = 1
				chip.TextXAlignment = Enum.TextXAlignment.Left
				-- The slot's own colour, darkened until it reads on paper.
				-- This is where the tint went when the ground became a card:
				-- the accent still says which control this is, on the one
				-- element small enough that it costs the card nothing.
				chip.TextColor3 = Theme.readable(tint)
			else
				chip.Position = UDim2.new(1, -6, 0, 5)
				chip.AnchorPoint = Vector2.new(1, 0)
				chip.BackgroundColor3 = Theme.SLAB
				chip.BackgroundTransparency = 0.25
				chip.TextColor3 = Theme.MUTED_LIGHT
				corner(chip, 4)
			end
			chip.BorderSizePixel = 0
			chip.Font = Enum.Font.GothamBold
			chip.TextSize = 11
			chip.Text = key
			chip.Parent = button
		end

		-- THE KEY MAKES THE BUTTON REACT TOO, and without this half the drop
		-- was a touchscreen feature only.
		--
		-- B opens the shop, I opens the bag, Q dodges and C sneaks, and on a
		-- keyboard every one of those did its job with the control sitting
		-- perfectly still -- so the loudest buttons on the HUD acknowledged a
		-- finger and ignored a key. A press and a tap are the same action and
		-- should look the same.
		--
		-- Gated on `Visible`, which is what keeps the dodge and the trick
		-- honest: they share Q and share a slot, and exactly one of them is on
		-- screen at a time. THE ONE CASE IT GETS WRONG is a player hidden in a
		-- wheelie bin, where the main key handler suppresses every binding but
		-- the shop -- the icon will still bounce. It is a control
		-- acknowledging a press rather than a claim that anything happened,
		-- and the alternative is this block knowing about bins.
		local iconObject: GuiObject? = drawn or glyph
		if key ~= "" and iconObject then
			local code = (Enum.KeyCode :: any)[key]
			if code then
				UserInputService.InputBegan:Connect(function(input, processed)
					if processed or not button.Visible then
						return
					end
					if input.KeyCode == code then
						Motion.tap(iconObject :: GuiObject)
					end
				end)
			end
		end

		return button
	end
end

-- Labelled SHOP, not "Defend / Rob". The old label described the two trees
-- accurately but never said it was a shop, and this button is now the only
-- way into skins and effects as well -- players looked for a shop and did
-- not recognise this as one.
-- THE SHOP BUTTON WEARS THE SHOP DOOR'S OWN COLOUR, taken from the prompt
-- rather than copied, so the two can never drift. Both open the same thing:
-- one is the door on the street and one is the button in the corner, and a
-- player who has walked into a shop should recognise the button that does
-- the same job. It also settles a collision -- it had landed on the same
-- purple as REBIRTH, which is the loudest button on the HUD and an entirely
-- unrelated action.
local shopToggle = makeActionButton("ShopToggle", "BASKET", "SHOP", "B",
	Config.PROMPTS.shop.tone, UDim2.new(0, 66, 0, 64), 21, shop)
-- LAST IN THE ROW, WHICH IS THE ACTUAL CORNER. The layout is right-aligned,
-- so the highest LayoutOrder sits furthest right -- and this is the control
-- players already know the position of, so it keeps the pixel it had.
shopToggle.LayoutOrder = 3


-- ============================================================
-- DEFENCE / OFFENCE PANEL
-- ============================================================
--
-- Both trees are shown side by side, always, with the coin balance above
-- them. That layout is the message: every coin you spend on one column is a
-- coin you can't spend on the other, and you should feel that at the moment
-- you choose.

local DEFENCE = Theme.GOOD
local OFFENCE = Theme.STOP

-- Sized in scale with a max, not a flat 620x420. At a fixed size the panel
-- ran off the top of the screen on short viewports -- a wide laptop window or
-- a phone held sideways, which is a lot of this audience. Scale keeps it
-- inside the screen; the constraint stops it ballooning on a big monitor.
local panel = Instance.new("Frame")
-- Reserve space for the raised sign and basket below Roblox's top-left controls.
panel.Size = UDim2.new(0.94, 0, 0.92, -58)
panel.Position = UDim2.new(0.5, 0, 0.5, 29)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = ShopStyle.BASE
panel.BorderSizePixel = 0
panel.Visible = false
panel.Active = true
-- The menu layer: above every HUD element. See `Theme.MENU_Z`.
panel.ZIndex = Theme.MENU_Z
panel.Parent = gui
do
	-- Keep mobile movement buttons behind the open shop. Restore the HUD's
	-- normal layer on close so movement controls remain accessible in play.
	local hudOrder = gui.DisplayOrder
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		gui.DisplayOrder = if panel.Visible then math.max(hudOrder, 10) else hudOrder
	end)
end
corner(panel, 22)
ShopStyle.outline(panel, 5)

local panelSize = Instance.new("UISizeConstraint")
-- Raised from 620x420, which was set when there were two tabs and a dozen
-- items. It is now eight tabs against twenty-one skins, sixteen decorations
-- and twelve accessories: the piggy tab alone came to 1.9 screens of
-- scrolling through a 530x364 window, and the rail needed 440 pixels of tab
-- in 368 -- so Rides and Collection hung off the bottom edge, unreachable.
--
-- AND THEN IT WAS RAISED TO 1480x920 FOR "LARGER DESKTOP CARDS", WHICH IS
-- WHAT MADE THE SHOP UNUSABLE ON A LAPTOP.
--
-- The panel is sized in SCALE (0.94 x 0.92), so the cap is the only thing
-- deciding how much of a desktop screen it takes -- and at 1480x920 it is
-- essentially the whole window, with every measurement inside it derived from
-- a width nothing was authored against. Reported as too big to click anything
-- on a laptop while reading well on a phone, which is exactly the shape of a
-- cap that only bites on big screens.
--
-- 1200x760 IS DERIVED FROM THE TWO LAYOUTS IT HAS TO HOLD, not chosen:
--
--   * the CATALOGUE wants six 156-wide cards across an 8-gap grid, which is
--     976 of content -- plus the 166 sidebar and its 24 of inset, 1166. This
--     file's own note records "six across at the 1040 cap" from before the
--     sidebar existed; 1200 is that same six with a sidebar beside it.
--   * the LANDING wants its six tiles at the size their artwork was drawn
--     for, 333 x 269 (see `ShopRevamp:layout`), which is 1037 of grid.
--
-- Scale sizing still shrinks the panel on phones, so the compact layout is
-- untouched: a phone is nowhere near either cap.
panelSize.MaxSize = Vector2.new(1200, 760)
panelSize.MinSize = Vector2.new(300, 240)
panelSize.Parent = panel

-- ONE BAND, NOT TWO, AND THAT IS WHAT PAID FOR THE TABS.
--
-- The header used to be three stacked bands: a title at 12, a tab rail down
-- the left from 44, and content from 86. The title existed for one reason,
-- written down at the time -- THE RAIL WAS GLYPHS, so the name of the open
-- tab appeared nowhere else and a nine-year-old got five emoji and no words.
--
-- Putting the words ON the tabs makes that label redundant, and dropping it
-- frees the whole top band. So the tabs move INTO it, beside the coins and
-- the close button, and the shop goes from two bands of furniture to one.
--
-- IT ALSO GOT WIDER RATHER THAN SHORTER, which is the part worth measuring.
-- A vertical rail costs WIDTH permanently -- and one wide enough to carry
-- words costs about 96 of it. Measured at the 1040 cap: the old rail left a
-- 950 content area, which takes FIVE 156-wide cards across (six needs 976),
-- and a labelled vertical rail would have left 910 and still five. The
-- horizontal band leaves 1020 and 578 -- SIX across and three down, so 18
-- items are visible where 15 were, with the tabs now readable.
--
-- Note the "six across" in the note further down was true when the card was
-- 148 wide and quietly stopped being true when it went to 156. It is six
-- again, and this time it is measured against the width it actually has.
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, -20, 0, 52)
header.Position = UDim2.new(0, 10, 0, 10)
header.BackgroundTransparency = 1
header.Parent = panel

-- Kept under its old name because `selectTab` still writes to it and a probe
-- may still address it. It is invisible: the tabs say where you are now.
local panelTitle = Instance.new("TextLabel")
panelTitle.Name = "PanelTitle"
panelTitle.Visible = false
panelTitle.Text = ""
panelTitle.Parent = header

-- THE BALANCE IS A GOLD PILL, not a right-aligned string. It is the number
-- every price on this screen is read against, so it is the one piece of
-- status that gets to look like an object rather than like a caption.
local panelCoins = ShopStyle.chip(header, ShopStyle.GOLD, ShopStyle.INK)
panelCoins.Name = "CoinChip"
panelCoins.Size = UDim2.new(0, 138, 0, 34)
panelCoins.Position = UDim2.new(1, -240, 0, 9)
panelCoins.Text = ""

-- ============================================================
-- SETTINGS
-- ============================================================
--
-- THE MUSIC TOGGLE HAS LEFT THE SHOP HEADER, AND THE COMMENT THAT USED TO
-- STAND HERE CALLED THAT MOVE FOR ITSELF.
--
-- It read: "This is a stopgap and is written down as one. A shop is the
-- wrong home for a setting -- it is where you spend coins, not where you
-- configure the game." What kept it there was that every alternative was
-- worse: the HUD corners were full and a ninth shop tab would spend a whole
-- view on one switch.
--
-- WHAT CHANGED IS THAT THE CORNER BECAME A ROW. Three 66-pixel tiles fit the
-- 210 this corner already occupied, so a third button costs no height and no
-- width -- and a setting reached from the HUD is reachable while PLAYING,
-- which is the whole point of a mute: you press it because the music is
-- bothering you now, not because you were shopping.
--
-- A PANEL RATHER THAN A NAKED TOGGLE, because the moment there is one
-- setting there are three, and a lone speaker button in a corner has
-- nowhere for the next one to go. It is deliberately SMALL -- a card in the
-- middle of the screen rather than a full-screen view -- so it does not
-- join the two panels that may never be open at once.
--
-- MUSIC ONLY, never the effects. Muting the lot would hide the siren, and
-- the patrol only works because it is heard coming. A player who wants quiet
-- should be able to get it without going deaf to the one warning in the game.
-- WRAPPED IN A do-BLOCK, AND THAT IS THE 200-REGISTER CEILING FOR THE
-- ELEVENTH TIME.
--
-- The panel, its title, its close button, the row, the row's label, the hint
-- and the corner button are SEVEN new top-level locals, and this chunk had
-- about two spare. It does not fail at the settings panel: it failed at
-- `inst` on line 7361, six thousand lines away, with "Out of local registers
-- when trying to allocate" -- and it takes the ENTIRE HUD rather than the
-- feature, because the chunk never compiles and nothing gets built.
--
-- A block's locals are released at its end, so the whole panel costs the
-- chunk NOTHING. Only `musicButton` is declared outside it, because the
-- behaviour block further down -- the glyph, the optimistic flip, the server
-- echo -- still reads it.
local musicButton: TextButton
do
	local settingsPanel = Instance.new("Frame")
	settingsPanel.Name = "SettingsPanel"
	settingsPanel.Size = UDim2.new(0, 300, 0, 152)
	settingsPanel.Position = UDim2.new(0.5, 0, 0.5, 0)
	settingsPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	settingsPanel.BackgroundColor3 = Theme.SAND
	settingsPanel.BorderSizePixel = 0
	settingsPanel.Visible = false
	settingsPanel.ZIndex = Theme.MENU_Z
	settingsPanel.Parent = gui
	corner(settingsPanel, 16)
	Theme.outline(settingsPanel)
	Theme.gloss(settingsPanel, Theme.SAND, Theme.SAND_DEEP)

	local settingsTitle = Instance.new("TextLabel")
	settingsTitle.Name = "Title"
	settingsTitle.Size = UDim2.new(1, -24, 0, 26)
	settingsTitle.Position = UDim2.new(0, 12, 0, 12)
	settingsTitle.BackgroundTransparency = 1
	settingsTitle.Font = Enum.Font.FredokaOne
	settingsTitle.TextSize = 19
	settingsTitle.TextColor3 = Theme.INK
	settingsTitle.TextXAlignment = Enum.TextXAlignment.Left
	settingsTitle.Text = "SETTINGS"
	settingsTitle.ZIndex = 41
	settingsTitle.Parent = settingsPanel

	local settingsClose = Instance.new("TextButton")
	settingsClose.Name = "CloseSettings"
	settingsClose.Size = UDim2.new(0, 34, 0, 34)
	settingsClose.Position = UDim2.new(1, -12, 0, 8)
	settingsClose.AnchorPoint = Vector2.new(1, 0)
	settingsClose.BackgroundColor3 = Theme.STOP
	settingsClose.BorderSizePixel = 0
	settingsClose.Font = Enum.Font.FredokaOne
	settingsClose.TextSize = 22
	settingsClose.TextColor3 = Theme.PAPER
	settingsClose.AutoButtonColor = true
	settingsClose.Text = utf8.char(0x00D7)
	settingsClose.ZIndex = 41
	settingsClose.Parent = settingsPanel
	corner(settingsClose, 11)
	Theme.outline(settingsClose)
	Theme.floatClose(settingsClose)

	-- The row. A label on the left and the toggle on the right, which is the
	-- shape every settings row in every game already has -- and it leaves room
	-- for the second and third settings to stack under it without a rethink.
	local musicRow = Instance.new("Frame")
	musicRow.Name = "MusicRow"
	musicRow.Size = UDim2.new(1, -24, 0, 52)
	musicRow.Position = UDim2.new(0, 12, 0, 52)
	musicRow.BackgroundColor3 = Theme.PAPER
	musicRow.BorderSizePixel = 0
	musicRow.ZIndex = 41
	musicRow.Parent = settingsPanel
	corner(musicRow, 12)
	Theme.outline(musicRow, Theme.OUTLINE_THIN)

	local musicLabel = Instance.new("TextLabel")
	musicLabel.Name = "What"
	musicLabel.Size = UDim2.new(1, -80, 1, 0)
	musicLabel.Position = UDim2.new(0, 14, 0, 0)
	musicLabel.BackgroundTransparency = 1
	musicLabel.Font = Enum.Font.FredokaOne
	musicLabel.TextSize = 16
	musicLabel.TextColor3 = Theme.INK
	musicLabel.TextXAlignment = Enum.TextXAlignment.Left
	musicLabel.Text = "Music"
	musicLabel.ZIndex = 42
	musicLabel.Parent = musicRow

	-- THE BUTTON KEEPS ITS NAME AND ITS BEHAVIOUR. Everything below this point
	-- -- the glyph it shows, the optimistic flip, the server echo -- is the same
	-- code it had in the header, so this move is a parent and a rectangle and
	-- nothing else. That is deliberate: a re-home that also rewrites the
	-- behaviour is two changes wearing one diff.
	musicButton = Instance.new("TextButton")
	musicButton.Name = "MusicToggle"
	musicButton.Size = UDim2.new(0, 52, 0, 36)
	musicButton.Position = UDim2.new(1, -10, 0.5, 0)
	musicButton.AnchorPoint = Vector2.new(1, 0.5)
	musicButton.BackgroundColor3 = ShopStyle.CARD
	musicButton.BorderSizePixel = 0
	musicButton.Font = Enum.Font.FredokaOne
	musicButton.TextSize = 18
	musicButton.AutoButtonColor = true
	musicButton.Text = ""
	musicButton.ZIndex = 42
	musicButton.Parent = musicRow
	corner(musicButton, 10)
	ShopStyle.outline(musicButton, 3)
	ShopStyle.gloss(musicButton)

	local settingsHint = Instance.new("TextLabel")
	settingsHint.Name = "Hint"
	settingsHint.Size = UDim2.new(1, -24, 0, 30)
	settingsHint.Position = UDim2.new(0, 12, 0, 110)
	settingsHint.BackgroundTransparency = 1
	settingsHint.Font = Enum.Font.Gotham
	settingsHint.TextSize = 12
	settingsHint.TextColor3 = Theme.MUTED
	settingsHint.TextWrapped = true
	settingsHint.TextXAlignment = Enum.TextXAlignment.Left
	-- Says what muting does NOT do, which is the only thing about this switch a
	-- player could get wrong: the siren, the dog and your ride keep their voice.
	settingsHint.Text = "Turns the music off. Sirens, dogs and your ride still make noise."
	settingsHint.ZIndex = 41
	settingsHint.Parent = settingsPanel

	-- THE BUTTON IS BUILT HERE, BELOW THE PANEL, AND THAT IS THE ELEVENTH TIME
	-- THIS PROJECT HAS MET THE SAME TRAP.
	--
	-- It was first written up with the other two corner tiles, 100 lines above
	-- this -- which reads fine and is a nil GLOBAL: a `local` declared after a
	-- closure that reads it is not an error in Luau, it compiles against a global
	-- and dies at the call naming nothing useful. Every previous instance was
	-- found by watching something fail; this one was found by noticing that the
	-- panel is declared further down the file than the handler that shows it.
	--
	-- The other two tiles stay where they are because neither closes over
	-- anything: `shopToggle` and `bagToggle` are wired by code that already sits
	-- below whatever it touches.
	local settingsToggle = makeActionButton("SettingsToggle", "GEAR", "OPTIONS", "",
		Theme.SLAB, UDim2.new(0, 66, 0, 64), 21, shop)
	-- FIRST IN THE ROW AND THEREFORE FURTHEST FROM THE CORNER: the layout is
	-- right-aligned, so the two controls pressed constantly keep the easiest
	-- reach and the one pressed twice a session takes the far end.
	--
	-- SLATE RATHER THAN A CATEGORY HUE. All nine hues mean a shop section, and
	-- this is the one control in the corner that opens nothing to do with the
	-- catalogue -- borrowing a tab's colour would say that it did.
	settingsToggle.LayoutOrder = 1

	-- OPENING A MENU REPLACES WHATEVER MENU WAS OPEN, and settings was the one
	-- panel in the HUD that did neither half of that.
	--
	-- Every menu here sits at `Theme.MENU_Z`, so a tie is broken by CHILD
	-- ORDER -- and this panel is built after the shop, which is why it drew
	-- OVER an open shop rather than behind it. Then closing the shop revealed
	-- a settings panel the player had forgotten was open. Same fault the bag
	-- and the shop already solve, and the same instrument solves it.
	--
	-- THE ATTRIBUTE IS THE STATE AND THE PANEL FOLLOWS IT, which is what makes
	-- this reachable from outside a `do` block holding every local it owns.
	-- The bag is built five thousand lines below here and cannot be named from
	-- inside this block; an attribute on the ScreenGui can be read and written
	-- from anywhere, costs this chunk no register, and cannot go stale the way
	-- a second copy of the state would. Exactly what `BagOpen` already does.
	local function setSettings(open: boolean)
		gui:SetAttribute("SettingsOpen", open)
	end

	gui:GetAttributeChangedSignal("SettingsOpen"):Connect(function()
		settingsPanel.Visible = gui:GetAttribute("SettingsOpen") == true
	end)

	settingsToggle.Activated:Connect(function()
		-- TOGGLED OFF THE ATTRIBUTE RATHER THAN OFF `Visible`, because an
		-- attribute-changed signal is DEFERRED: the panel catches up at the
		-- end of the frame, so reading the panel here would be reading the
		-- state as it was before the last press rather than as it is.
		setSettings(gui:GetAttribute("SettingsOpen") ~= true)
	end)

	settingsClose.Activated:Connect(function()
		setSettings(false)
	end)

	-- WATCHED RATHER THAN POKED FROM THE PLACES THAT TOGGLE, the same call the
	-- bag makes on the shop panel: the shop opens from a button, a close X, the
	-- B key and a shop DOOR on the street, and none of those could call in here.
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then
			setSettings(false)
		end
	end)
	gui:GetAttributeChangedSignal("BagOpen"):Connect(function()
		if gui:GetAttribute("BagOpen") then
			setSettings(false)
		end
	end)

	-- The shop is in scope here, so opening settings closes it directly. The
	-- bag is not, and closes itself by watching this attribute -- see `setBag`.
	gui:GetAttributeChangedSignal("SettingsOpen"):Connect(function()
		if gui:GetAttribute("SettingsOpen") then
			panel.Visible = false
		end
	end)
end

-- BIG AND RED, because closing is the one control every player finds first
-- and a 40-pixel dark square with an X on it is not findable at a glance.
-- Same argument the hot bar's number chips already carry: a control a child
-- has to hunt for reads as a control that is missing.
--
-- U+00D7, not a capital X. This file already measured which glyphs Roblox
-- actually has: the heavy ballot crosses are tofu and U+2714 ignores
-- TextColor3, while the multiplication sign renders and takes its colour.
local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseShop"
closeButton.Size = UDim2.new(0, 44, 0, 44)
closeButton.Position = UDim2.new(1, -46, 0, 4)
closeButton.BackgroundColor3 = ShopStyle.STOP
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.FredokaOne
closeButton.TextSize = 28
closeButton.TextColor3 = ShopStyle.LIGHT
closeButton.AutoButtonColor = true
closeButton.Text = utf8.char(0x00D7)
closeButton.Parent = header
corner(closeButton, 14)
ShopStyle.outline(closeButton, 3)
ShopStyle.gloss(closeButton)
ShopStyle.pop(closeButton, 2)
Theme.floatClose(closeButton)

-- The toggle's behaviour, and the score it drives.
--
-- Optimistic: the button flips and the audio responds on the press, and the
-- server's echo corrects it afterwards if it disagreed. That is not a breach
-- of "the server owns all state" -- that rule is about balances, and this is
-- a preference that decides nothing. A hundred milliseconds of round trip
-- before a mute button does anything reads as a broken mute button.
do
	local musicOn = false

	-- Built with utf8.char rather than typed or escaped. A four-byte emoji
	-- written as a decimal escape is one shell or one editor away from being
	-- silently rewritten into different bytes -- which is how this line first
	-- shipped as a non-breaking space and a carriage return and took the whole
	-- HUD down with "Malformed string" at compile time.
	local SPEAKER = utf8.char(0x1F50A)
	local MUTED = utf8.char(0x1F507)

	local function paint()
		-- A speaker with sound, or one with a cross. The glyph is the whole
		-- label: there is no room for a word here and none needed.
		musicButton.Text = if musicOn then SPEAKER else MUTED
		musicButton.TextColor3 = if musicOn then GOLD else Theme.MUTED
	end

	musicButton.Activated:Connect(function()
		musicOn = not musicOn
		paint()
		Music.setEnabled(musicOn)
		Remotes.get("SettingRequest"):FireServer("music", musicOn)
	end)

	-- The server is what actually decides, and it pushes on join -- which is
	-- why the score starts silent above rather than starting and being cut
	-- off a second later on the machine of somebody who had turned it off.
	Remotes.get("SettingState").OnClientEvent:Connect(function(settings)
		if type(settings) ~= "table" then
			return
		end
		musicOn = settings.music ~= false
		paint()
		Music.setEnabled(musicOn)
		-- The hot bar's saved arrangement rides in on the same push. It is a
		-- preference in exactly the sense this channel is for: it moves tiles
		-- and cannot reach a stock, a coin or a cooldown.
		HotBar.applySettings(settings)
	end)

	paint()
	Music.start()
end

-- THE TABS, ACROSS THE TOP, WITH WORDS ON THEM.
--
-- A SCROLLING bar, for the reason the vertical rail was made to scroll: a
-- fixed one silently ate two whole tabs when the count grew, because a
-- UIListLayout does not clip and does not error -- it just keeps drawing past
-- the end, so the shop looked like a deliberate six-tab shop. Horizontal has
-- the same failure available on a narrow phone, where five 136-wide tabs need
-- 712 pixels and the panel is allowed down to 300. Scrolling cannot have the
-- bug at any size or tab count, and costs nothing when everything fits.
--
-- It stops 300 short of the right edge so it can never run under the coin
-- pill, the music toggle or the close button.
local rail = Instance.new("ScrollingFrame")
rail.Name = "TabRail"
rail.Size = UDim2.new(1, -248, 1, 0)
rail.BackgroundTransparency = 1
rail.BorderSizePixel = 0
rail.ScrollBarThickness = 0
rail.ScrollingDirection = Enum.ScrollingDirection.X
rail.CanvasSize = UDim2.new()
rail.AutomaticCanvasSize = Enum.AutomaticSize.X
rail.Parent = header

local railLayout = Instance.new("UIListLayout")
railLayout.FillDirection = Enum.FillDirection.Horizontal
railLayout.Padding = UDim.new(0, 8)
railLayout.VerticalAlignment = Enum.VerticalAlignment.Center
railLayout.SortOrder = Enum.SortOrder.LayoutOrder
railLayout.Parent = rail

-- THE FIRST TAB LOST ITS LEFT BORDER, and the rail being a SCROLLING frame is
-- what did it. A ScrollingFrame clips, the layout puts the first tab at x=0,
-- and `ApplyStrokeMode.Border` draws 3px OUTSIDE that -- so Everything's left
-- edge was cut while every other tab was clear. Measured: first tab at 246
-- against a rail starting at 246, its stroke reaching 243; the second tab at
-- 356 reaching 353, fine.
--
-- Same shape as the card grid's first column and the same fix, which is worth
-- stating plainly: ANY outside stroke needs clearance from a clipping parent,
-- and in this shop the clipping parents are the scrolls. Four pixels each
-- side; the rail needs 762 of the 772 available at seven tabs, so it fits
-- without scrolling and has one slot in hand.
local railInset = Instance.new("UIPadding")
railInset.PaddingLeft = UDim.new(0, 4)
railInset.PaddingRight = UDim.new(0, 4)
railInset.Parent = rail

-- Every view fills the panel under the one band, so adding a tab never moves
-- anything already on screen. 1020 x 578 at the 1040x660 cap.
local function makeView(name: string): Frame
	local v = Instance.new("Frame")
	v.Name = name
	v.Size = UDim2.new(1, -20, 1, -82)
	v.Position = UDim2.new(0, 10, 0, 70)
	v.BackgroundTransparency = 1
	v.Visible = false
	v.Parent = panel
	return v
end

-- FOUR VIEWS, DOWN FROM EIGHT, and the count was the whole problem.
--
-- Bones, Gadgets and Rides held three, three and five items -- eleven of the
-- catalogue's eighty-one taking three of the eight rail slots, so more than a
-- third of the navigation led to tabs you visit once and never again. The big
-- tabs were never the clutter: Your Piggy carries twenty-seven items in two
-- headed sections and reads fine, which is the shape the merge copies.
--
-- Sub-tabs were the other option and are worse. Every section in here is
-- already a HEADER you can see while scrolling past it; a sub-tab replaces
-- that with a button you have to press, and puts every item one tap deeper.
-- This file already wrote that lesson down for the garage slot, where "four
-- taps deep behind a shop tab" is the bug the slot exists to fix.
--
-- The grouping is by WHAT THE PLAYER WANTS, not by what the thing is:
--   Defend / Rob   the two upgrade trees -- the only tab that changes an outcome
--   Your Piggy     worn: skins, effects, accessories
--   Your Home      your plot and defending it: houses, decor, gadgets, treats
--   Your Gear      what you take out robbing: rides, styles, bones, disguises
--
-- That last line is the same split the upgrade tab already names, so the shop
-- and the trees now describe the game the same way round.
-- The front page gets a view like any other tab, and is the one the panel
-- opens on. It is navigation rather than a category, which is why it earns a
-- rail slot back after the merge gave four away.
local startView = makeView("StartView")
local upgradesView = makeView("UpgradesView")
local homeView = makeView("HomeView")
local gearView = makeView("GearView")
-- See the note above `SHOP` below: these two are held in that table rather
-- than as locals of their own, for the register budget.
local SHOP = { view = {}, at = {} } :: any
SHOP.view.items = makeView("ItemsView")
-- Held in SHOP rather than as a local of its own, for the register budget --
-- the note above this table records the same trick for the two lines above.
SHOP.view.crates = makeView("CratesView")
SHOP.view.companions = makeView("CompanionsView")
SHOP.view.premium = makeView("PremiumView")

-- The hint bubble floats over whichever view is open, so it hangs off the
-- PANEL rather than off any one of them -- a bubble parented to a view would
-- vanish with it the moment the tab changed, which is a bug that only shows
-- up on the one tab you did not test.
ShopStyle.setHintHost(panel)
startView.Visible = true

local tabs: { { button: TextButton, view: Frame, title: string,
	label: TextLabel, hue: Color3 } } = {}

-- THE SELECTED TAB IS THE ONLY ONE WEARING ITS COLOUR, and the rest stay
-- grey. Painting all five their own hue at once looks livelier in a mockup
-- and is unreadable in use: five saturated buttons in a row have no winner,
-- so nothing on screen answers "which one am I looking at". The colour is
-- spent on that answer, which is the question a tab bar exists for.
local function selectTab(index: number)
	-- A bubble describes the section it was opened from, so it goes with it.
	ShopStyle.closeHint()
	for i, tab in ipairs(tabs) do
		local on = i == index
		tab.view.Visible = on
		tab.button.BackgroundColor3 = if on then tab.hue else ShopStyle.CARD
		tab.label.TextColor3 = if on then ShopStyle.INK else ShopStyle.MUTED
		-- It also stands taller. Colour alone separates these only for players
		-- who can see all five, and this is a game for nine year olds where
		-- about one boy in twelve is colour-blind -- the same reasoning that
		-- made Legendary a THICKER border as well as a gold one.
		-- The tab's OWN width, not the old flat 102: this line re-sizes on
		-- every selection, so a constant here would undo the measurement
		-- above the moment anybody pressed anything.
		tab.button.Size = UDim2.new(0, tab.width, 0, if on then 44 else 38)
		if on then
			panelTitle.Text = tab.title
		end
	end
	if SHOP.shell then SHOP.shell:select(index) end
end

-- ICON AND WORD SIDE BY SIDE. The icon is what a returning player re-finds at
-- speed; the word is what a new one needs at all. Stacking them would want a
-- taller band, and the band's height is precisely what this layout was bought
-- with.
-- A TAB IS AS WIDE AS ITS OWN WORD, AND THE EIGHTH ONE IS WHY.
--
-- Every tab was a flat 102 wide. That fits seven in the 772-pixel rail and
-- does not fit eight: measured, the canvas ran to 880 and the Crates tab sat
-- at x 964 against a rail ending at 962 -- off the edge, reachable only by
-- scrolling a rail that gives no sign it scrolls. Not the old bug, which was
-- a rail that did not scroll at all and ATE two tabs silently; this is the
-- gentler version, where the tab exists and a nine-year-old never finds it.
--
-- A flat width was always spending the same 102 on "Worn" as on "Everything",
-- and measured at the shipped 13px FredokaOne those two labels are 30 and 62
-- pixels. Sizing each tab to its own label takes all eight to 692 including
-- padding -- inside the rail with 80 to spare, and room for a ninth.
--
-- Measured rather than estimated, because the failure is silent in the other
-- direction too: a tab one pixel too narrow truncates its own name, and
-- `TextTruncate` does that without erroring or looking obviously wrong.
--
-- THE ARITHMETIC IS INLINE, AND THAT IS THE REGISTER BUDGET RATHER THAN
-- TASTE. It was a constant and a helper at the top level, which with the
-- Crates require put this chunk at 201 locals -- and the whole HUD went, with
-- the error naming `buildNotifications` two thousand lines away. A function
-- body gets its own register file, so anything that can live inside one
-- costs this chunk nothing. Eighth time this file has hit that wall.
local function makeTab(icon: string, title: string, view: Frame, order: number, hue: Color3)
	-- 7 glyph x + 22 glyph + 2 gap, then a right inset, plus the word itself.
	local width = 41 + math.ceil(game:GetService("TextService")
		:GetTextSize(title, 13, Enum.Font.FredokaOne, Vector2.new(9999, 100)).X)
	local button = Instance.new("TextButton")
	-- Named after the view it opens. Five buttons all called "TextButton" are
	-- indistinguishable in the explorer and unaddressable from a test.
	button.Name = "Tab_" .. view.Name
	button.Size = UDim2.new(0, width, 0, 38)
	button.LayoutOrder = order
	button.BackgroundColor3 = ShopStyle.CARD
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Text = ""
	button.Parent = rail
	corner(button, 12)
	ShopStyle.outline(button, 3)
	ShopStyle.gloss(button)

	local glyph = Instance.new("TextLabel")
	glyph.Name = "Icon"
	glyph.Size = UDim2.new(0, 22, 1, 0)
	glyph.Position = UDim2.new(0, 7, 0, 0)
	glyph.BackgroundTransparency = 1
	glyph.Font = Enum.Font.FredokaOne
	glyph.TextSize = 19
	glyph.Text = icon
	glyph.Parent = button

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	-- In OFFSET now rather than scale. It is the same box on a fixed-width
	-- button and the honest one on a measured button, since the width this
	-- label gets is exactly the width it was measured to need.
	label.Size = UDim2.new(0, width - 36, 1, 0)
	label.Position = UDim2.new(0, 31, 0, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	-- Fixed size with truncation rather than TextScaled: scaled type would set
	-- "Everything" larger than "Defend / Rob" on tabs of identical width,
	-- which reads as the two being different kinds of control.
	label.TextSize = 13
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = ShopStyle.MUTED
	label.Text = title
	label.Parent = button

	local index = #tabs + 1
	tabs[index] = { button = button, view = view, title = title,
		label = label, hue = hue, width = width }
	button.Activated:Connect(function()
		selectTab(index)
	end)
end

-- THE SPLIT IS BY WHAT A THING IS FOR.
--
-- Your Home had become two different shops sharing a scroll: houses, lawn
-- ornaments and kerb decorations -- pure taste, bought once, looked at -- and
-- gadgets, the treat and the radio, which are STOCK you spend.
-- Nothing about those two lists belongs on one page, and the tab was 4.13
-- screens because it was carrying both.
--
-- Your Gear had the same fault three ways over: a vehicle you mount, a stock
-- you throw, and a hat you wear are three unrelated verbs.
--
--   Home     houses, lawn, kerb          -- your plot, and only its looks
--   Rides    boards and bikes, plus the poses that go on them
--   Items    everything with a COUNT on it: bones, gadgets, treat,
--            radio, raincoat
--   Worn     the gear you wear YOURSELF, which is a different body from the
--            piggy every other cosmetic goes on
--
-- Standalone piggy effects are retired by design. Keep coin-deposit feedback
-- and skin-authored Legendary visuals; do not restore an effects shelf.
--
-- Short labels, because the rail is one band. "Your Home" earned its
-- possessive when there were four tabs and room for it; the icon carries the
-- same meaning now.
makeTab(utf8.char(0x1F3EA), "Everything", startView, 1, ShopStyle.HUE.everything)
makeTab(utf8.char(0x2694), "Upgrades", upgradesView, 2, ShopStyle.HUE.upgrades)
makeTab(utf8.char(0x1F3E0), "Home", homeView, 3, ShopStyle.HUE.home)
SHOP.at.home = #tabs
makeTab(utf8.char(0x1F6F9), "Rides", gearView, 4, ShopStyle.HUE.gear)
SHOP.at.rides = #tabs
makeTab(utf8.char(0x1F9F0), "Items", SHOP.view.items, 5, ShopStyle.HUE.items)
SHOP.at.items = #tabs
-- THE WORN TAB IS GONE. It held two things: Most Wanted gear, which is earned
-- rather than bought and so lives in the bag, and catch effects, which moved
-- to Guardians -- catching a thief is protecting your home.
-- AN EIGHTH TAB, AND IT IS A VERB RATHER THAN A CATEGORY. The seven above are
-- places a thing GOES -- on the piggy, on the plot, under you, on you. This
-- one is a way of GETTING things, which is why it does not fold into any of
-- them and why it earns its own slot rather than a section inside one.
--
-- The rail is a ScrollingFrame precisely so that this could not repeat the
-- bug it once had: eight tabs at 106 wide is 848 pixels, which fits the band
-- today, and a UIListLayout does not clip and does not error -- it keeps
-- drawing past the edge, which is how Rides and Collection were once eaten
-- whole with nothing on screen to say they existed.
makeTab(utf8.char(0x1F4E6), "Crates", SHOP.view.crates, 7, ShopStyle.HUE.crates)
SHOP.at.crates = #tabs
makeTab(utf8.char(0x1F43E), "Guardians", SHOP.view.companions, 8, ShopStyle.HUE.gear)
SHOP.at.companions = #tabs
-- THE ROBUX TAB, last. Named things bought with Robux, never coins; see
-- `Shared/PremiumShop`. The shell adds it to the sidebar and puts a featured
-- banner for it on the landing page.
makeTab(utf8.char(0x1F48E), "Robux", SHOP.view.premium, 9, Theme.SHOP_COLOURS.premium)
SHOP.at.premium = #tabs
-- THE INVENTORY IS NOT A TAB IN HERE, AND THAT IS THE POINT OF IT.
--
-- It was one for about an hour and it was wrong twice. A shop tab is a
-- place you go to SPEND; the inventory is where you go to look at what you
-- already have, and putting it behind the shop button says the opposite of
-- what the split was for. It also overflowed the rail -- eight tabs measure
-- 692 in a 772 window and "Inventory" wants about 98 more -- so the one tab
-- that is not a shop was also the one a nine-year-old had to scroll to find.
--
-- It is its own HUD button now, beside SHOP in the bottom-right. See the
-- BAG PANEL section further down.

-- EARN, DEFEND, ROB -- three verbs, and the first one is the base of the
-- other two. It gets a full-width band across the top rather than a third
-- column, for two reasons: a 1/3-width card cannot hold "Bigger Piggy Bank"
-- at 18px beside a 122-wide price chip without truncating it, and these two
-- are not a TREE. They are the thing both trees are paid for.
--
-- One table rather than three loose upvalues -- this chunk is at Luau's
-- 200-local ceiling and the note above `SHOP` records the same trick.
local earn = { band = nil :: any, rows = {} :: any }

local earnHeading = Instance.new("TextLabel")
earnHeading.Name = "EarnHeading"
earnHeading.Size = UDim2.new(1, -26, 0, 38)
earnHeading.Position = UDim2.new(0, 18, 0, 0)
earnHeading.BackgroundColor3 = GOLD:Lerp(ShopStyle.LIGHT, 0.42)
earnHeading.BorderSizePixel = 0
earnHeading.Font = Enum.Font.FredokaOne
earnHeading.TextSize = 20
earnHeading.TextColor3 = ShopStyle.INK
earnHeading.Text = "EARN"
earnHeading.Parent = upgradesView
corner(earnHeading, 14)
ShopStyle.outline(earnHeading, 3)
ShopStyle.gloss(earnHeading)

earn.band = Instance.new("Frame")
earn.band.Name = "EarnRow"
earn.band.Size = UDim2.new(1, -26, 0, 96)
earn.band.Position = UDim2.new(0, 18, 0, 48)
earn.band.BackgroundTransparency = 1
earn.band.Parent = upgradesView

local earnLayout = Instance.new("UIListLayout")
earnLayout.FillDirection = Enum.FillDirection.Horizontal
earnLayout.Padding = UDim.new(0, 16)
earnLayout.SortOrder = Enum.SortOrder.LayoutOrder
earnLayout.Parent = earn.band

-- WHAT THE BAND COSTS THE TREES IS 158 PIXELS, AND THAT IS WHY THE LISTS
-- SCROLL NOW. Three rows of 96 plus their gaps is 308, against a column list
-- of 512 on a desktop and 322 on a phone held sideways -- so the trees fitted
-- by 14 pixels before this band existed and would have overflowed by 134
-- after it. A UIListLayout does not clip and does not error; it keeps drawing
-- past the edge, which is exactly how the tab rail once ate two whole tabs.
local columns: { [string]: ScrollingFrame } = {}
for index, spec in ipairs({
	{ tree = "defense", title = "DEFEND", color = DEFENCE },
	{ tree = "offense", title = "ROB", color = OFFENCE },
}) do
	local column = Instance.new("Frame")
	column.Size = UDim2.new(0.5, -26, 1, -176)
	column.Position = UDim2.new(0.5 * (index - 1), if index == 1 then 18 else 8, 0, 158)
	column.BackgroundTransparency = 1
	column.Parent = upgradesView

	local heading = Instance.new("TextLabel")
	heading.Size = UDim2.new(1, 0, 0, 38)
	heading.BackgroundColor3 = spec.color:Lerp(ShopStyle.LIGHT, 0.42)
	heading.BorderSizePixel = 0
	heading.Font = Enum.Font.FredokaOne
	heading.TextSize = 20
	heading.TextColor3 = ShopStyle.INK
	heading.Text = spec.title
	heading.Parent = column
	corner(heading, 14)
	ShopStyle.outline(heading, 3)
	ShopStyle.gloss(heading)

	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Size = UDim2.new(1, 0, 1, -48)
	list.Position = UDim2.new(0, 0, 0, 48)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = column

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	-- A card carries a 3px Border stroke, which draws OUTSIDE the frame and
	-- straight into the region a ScrollingFrame clips. Same clearance the
	-- cosmetics scroll and the tab rail already need.
	local inset = Instance.new("UIPadding")
	inset.PaddingLeft = UDim.new(0, 4)
	inset.PaddingRight = UDim.new(0, 4)
	inset.PaddingTop = UDim.new(0, 4)
	inset.Parent = list

	columns[spec.tree] = list
end

local upgradeRows: { [string]: { button: TextButton, title: TextLabel, cost: TextLabel,
	blurb: TextLabel, pips: Frame, accent: Color3 } } = {}

-- ONE CARD BUILDER FOR ALL EIGHT ROWS. The six trees and the two EARN rows are
-- the same object -- a name, a line of explanation, a level readout and a price
-- you press -- and the only things that differ are where it is parented, what
-- colour it is edged in, how wide it is and what pressing it fires. A second
-- near-identical builder for the two new rows is the copy that drifts the first
-- time either is touched, which this project has already recorded for the mini
-- piggy, `Decor.buildOne` and `RideSound`.
local function makeUpgradeCard(parent: Instance, order: number, accent: Color3,
	size: UDim2, onBuy: () -> ()): any

	-- THE LAST TAB DRAWN IN THE OLD VOCABULARY, and the one that could least
	-- afford to be. This is the only tab in the shop that changes an OUTCOME
	-- rather than how something looks, and it was six flat rows with a
	-- two-pixel stripe floating in a 1020x578 area -- the plainest screen in
	-- the game sitting behind the loudest card on the front page.
	--
	-- THE LEVEL IS DRAWN AS A LADDER, which is the real gain here. "Lv 3/4"
	-- is a thing you read; four pips with three filled is a thing you SEE,
	-- and it answers the only question this tab is asked -- how much of this
	-- have I got, and how much is left -- without reading at all. That
	-- matters for an audience whose younger half is not reading the numbers.
	local button = Instance.new("TextButton")
	button.Size = size
	button.LayoutOrder = order
	button.BackgroundColor3 = ShopStyle.CARD
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.FredokaOne
	button.Text = ""
	button.Parent = parent
	corner(button, 16)
	-- The tree's own colour, so DEFEND and ROB stay told apart at a glance
	-- once a row is no longer wearing a coloured stripe.
	ShopStyle.outline(button, 3, accent)
	ShopStyle.gloss(button)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -152, 0, 24)
	title.Position = UDim2.new(0, 14, 0, 10)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 18
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = ShopStyle.TEXT
	title.Text = ""
	title.Parent = button

	local blurb = Instance.new("TextLabel")
	blurb.Name = "Blurb"
	blurb.Size = UDim2.new(1, -152, 0, 16)
	blurb.Position = UDim2.new(0, 14, 0, 36)
	blurb.BackgroundTransparency = 1
	blurb.Font = Enum.Font.Gotham
	blurb.TextSize = 12
	blurb.TextTruncate = Enum.TextTruncate.AtEnd
	blurb.TextXAlignment = Enum.TextXAlignment.Left
	blurb.TextColor3 = ShopStyle.MUTED
	blurb.Text = ""
	blurb.Parent = button

	-- The pips are filled in at render, because `max` is a fact about the
	-- catalogue and this row is built before the first push arrives.
	local pips = Instance.new("Frame")
	pips.Name = "Pips"
	pips.Size = UDim2.new(1, -152, 0, 14)
	pips.Position = UDim2.new(0, 14, 0, 62)
	pips.BackgroundTransparency = 1
	pips.Parent = button

	local pipLayout = Instance.new("UIListLayout")
	pipLayout.FillDirection = Enum.FillDirection.Horizontal
	pipLayout.Padding = UDim.new(0, 4)
	pipLayout.SortOrder = Enum.SortOrder.LayoutOrder
	pipLayout.Parent = pips

	local cost = ShopStyle.chip(button, ShopStyle.SUNK, GOLD)
	cost.Name = "Cost"
	cost.Size = UDim2.new(0, 122, 0, 40)
	cost.Position = UDim2.new(1, -136, 0.5, -20)
	cost.Text = ""

	button.Activated:Connect(onBuy)

	return { button = button, title = title, cost = cost, blurb = blurb,
		pips = pips, accent = accent }
end

local function ensureRow(key: string, info: any)
	local existing = upgradeRows[key]
	if existing then
		return existing
	end
	local row = makeUpgradeCard(
		columns[info.tree],
		info.order,
		if info.tree == "defense" then DEFENCE else OFFENCE,
		UDim2.new(1, 0, 0, 196),
		function()
			Remotes.get("UpgradeRequest"):FireServer(key)
		end)
	-- A TREE ROW IS A TIER LIST: every level as a picture underneath the name,
	-- so a player sees what the next rungs ARE rather than counting pips. The
	-- price moves up beside the title to give the tiles the full width.
	row.tiered = key
	row.cost.Position = UDim2.new(1, -136, 0, 10)
	row.pips.Position = UDim2.new(0, 10, 0, 62)
	row.pips.Size = UDim2.new(1, -20, 0, 124)
	upgradeRows[key] = row
	return row
end

-- ONE EARN ROW, half of the band -- about the width of a tree card, so the
-- price chip lands in the same place on all seven. The second, Bigger Piggy
-- Bank, is retired with the pig's ceiling: there is nothing for it to buy.
earn.rows.income = makeUpgradeCard(earn.band, 1, GOLD, UDim2.new(0.5, -8, 1, 0),
	function()
		Remotes.get("PurchaseRequest"):FireServer("income")
	end)
earn.rows.income.title.Text = "Earn Faster"
earn.rows.income.blurb.Text = "More coins every second, forever."

-- A LADDER YOU CAN COUNT, OR A BAR YOU READ, AND THE CALLER SAYS WHICH.
--
-- Pips are the right picture for a tree: four rungs with three filled answers
-- "how much have I got, how much is left" with no reading at all, and that is
-- the whole argument for them. They are the WRONG picture for income,
-- because it runs to `Config.maxLevel` -- 20, and 40 once enough
-- rebirths have opened the ceiling. Measured on the card this actually renders
-- on: 40 pips share 337 pixels, so each one is 4.4 wide and carries a 2px
-- outline. That is not a ladder, it is noise.
--
-- THE KIND IS PASSED IN RATHER THAN DERIVED FROM `max`, and that is the point
-- rather than laziness. A threshold would flip these two rows from pips to a
-- bar partway through the game -- at whatever rebirth pushed the ceiling past
-- it -- so a player would watch a control they already knew change shape for
-- no reason they could see.
local function paintLadder(row: any, level: number, max: number, bar: boolean)
	local pips = row.pips
	if bar then
		-- Built once and then only repainted, for the same reason the pips are:
		-- this runs off the state push, which lands on every coin tick.
		local track = pips:FindFirstChild("Track")
		if not track then
			for _, old in ipairs(pips:GetChildren()) do
				if old:IsA("Frame") then
					old:Destroy()
				end
			end
			track = Instance.new("Frame")
			track.Name = "Track"
			track.Size = UDim2.new(1, 0, 1, 0)
			track.BackgroundColor3 = Theme.SAND_DEEP
			track.BorderSizePixel = 0
			track.Parent = pips
			corner(track, 5)
			ShopStyle.outline(track, 2)

			local fill = Instance.new("Frame")
			fill.Name = "Fill"
			fill.Size = UDim2.new(0, 0, 1, 0)
			fill.BackgroundColor3 = row.accent
			fill.BorderSizePixel = 0
			fill.Parent = track
			corner(fill, 5)

			-- PRINTED ON THE BAR, because at forty rungs the bar alone cannot
			-- tell 31 from 33 and the level is what a player is deciding on.
			-- INK reads on both grounds it crosses -- the pale sand track and
			-- the gold fill -- so it needs no halo behind it.
			local text = Instance.new("TextLabel")
			text.Name = "Level"
			text.Size = UDim2.new(1, 0, 1, 0)
			text.BackgroundTransparency = 1
			text.Font = Enum.Font.GothamBold
			text.TextSize = 11
			text.TextColor3 = ShopStyle.INK
			text.ZIndex = 3
			text.Parent = track
		end
		local fraction = if max > 0 then math.clamp(level / max, 0, 1) else 0
		track.Fill.Size = UDim2.new(fraction, 0, 1, 0)
		track.Level.Text = ("Lv %d / %d"):format(level, max)
		return
	end

	-- THE TIER LIST, for the six trees. One tile per level with that level's
	-- picture (Shared/UpgradePreview): bought tiers bright with a tick, the
	-- next one outlined in gold, everything past it faded under a lock. Built
	-- once per rung count and only repainted after -- this runs off the state
	-- push. Written inline because this chunk has no top-level register left.
	if row.tiered then
		local Preview = require(ReplicatedStorage.Shared.UpgradePreview)
		local tiles = pips:GetChildren()
		local count = 0
		for _, t in ipairs(tiles) do
			if t:IsA("Frame") then
				count += 1
			end
		end
		if count ~= max then
			for _, old in ipairs(tiles) do
				if old:IsA("Frame") then
					old:Destroy()
				end
			end
			for i = 1, max do
				local tile = Instance.new("Frame")
				tile.Name = "Tier" .. i
				tile.Size = UDim2.new(1 / max, -6, 1, -4)
				tile.LayoutOrder = i
				tile.BorderSizePixel = 0
				tile.ClipsDescendants = true
				tile.Parent = pips
				corner(tile, 12)
				local edge = ShopStyle.outline(tile, 2)
				edge.Name = "Edge"

				local model = Preview.build(row.tiered, i)
				if model then
					makeModelIcon(tile, model, UDim2.new(1, -8, 1, -30), UDim2.new(0, 4, 0, 4), false)
				end

				local name = Instance.new("TextLabel")
				name.Name = "Label"
				name.Size = UDim2.new(1, -6, 0, 22)
				name.Position = UDim2.new(0, 3, 1, -24)
				name.BackgroundTransparency = 1
				name.Font = Enum.Font.FredokaOne
				name.TextSize = 12
				name.TextTruncate = Enum.TextTruncate.AtEnd
				name.TextColor3 = ShopStyle.INK
				name.Text = Preview.label(row.tiered, i)
				name.Parent = tile

				-- The fade: a sheet of the card colour over the picture, with a
				-- lock on it. Built last so it draws above the viewport.
				local veil = Instance.new("Frame")
				veil.Name = "Veil"
				veil.Size = UDim2.new(1, 0, 1, 0)
				veil.BackgroundColor3 = Theme.SAND
				veil.BackgroundTransparency = 0.35
				veil.BorderSizePixel = 0
				veil.ZIndex = 5
				veil.Parent = tile
				-- A word rather than the padlock emoji, which did not render on
				-- this card -- a chip is also readable without knowing the glyph.
				local lock = Instance.new("TextLabel")
				lock.Name = "Lock"
				lock.Size = UDim2.new(0, 58, 0, 18)
				lock.AnchorPoint = Vector2.new(0.5, 0.5)
				lock.Position = UDim2.new(0.5, 0, 0.42, 0)
				lock.BackgroundColor3 = ShopStyle.INK
				lock.BorderSizePixel = 0
				lock.Font = Enum.Font.GothamBold
				lock.TextSize = 10
				lock.TextColor3 = Theme.PAPER
				lock.Text = "LOCKED"
				lock.ZIndex = 6
				lock.Parent = veil
				corner(lock, 999)

				-- The tick on a bought tier: U+2713, which takes its colour.
				local tick = Instance.new("TextLabel")
				tick.Name = "Tick"
				tick.Size = UDim2.new(0, 20, 0, 20)
				tick.Position = UDim2.new(1, -23, 0, 3)
				tick.BackgroundColor3 = Theme.GOOD
				tick.BorderSizePixel = 0
				tick.Font = Enum.Font.GothamBold
				tick.TextSize = 14
				tick.TextColor3 = Theme.PAPER
				tick.Text = utf8.char(0x2713)
				tick.ZIndex = 7
				tick.Parent = tile
				corner(tick, 999)
			end
		end
		for _, tile in ipairs(pips:GetChildren()) do
			if tile:IsA("Frame") then
				local i = tile.LayoutOrder
				local owned = i <= level
				local nextUp = i == level + 1
				tile.BackgroundColor3 = if owned
					then row.accent:Lerp(ShopStyle.LIGHT, 0.6)
					elseif nextUp then ShopStyle.CARD
					else Theme.SAND_DEEP
				local edge = tile:FindFirstChild("Edge") :: UIStroke?
				if edge then
					edge.Color = if nextUp then GOLD elseif owned then row.accent else ShopStyle.INK
					edge.Thickness = if nextUp then 4 else 2
				end
				local veil = tile:FindFirstChild("Veil") :: Frame?
				if veil then
					veil.Visible = not owned and not nextUp
				end
				local tick = tile:FindFirstChild("Tick") :: TextLabel?
				if tick then
					tick.Visible = owned
				end
			end
		end
		return
	end

	-- THE LADDER. Rebuilt only when the RUNG COUNT changes, which is almost
	-- never -- repainting is one property per pip, where tearing the row down
	-- every push would rebuild six of these on every coin tick. Pips share the
	-- row's width, so a four-rung tree and a five-rung one both fill the same
	-- bar and the two trees stay comparable at a glance.
	if #pips:GetChildren() - 1 ~= max then
		for _, old in ipairs(pips:GetChildren()) do
			if old:IsA("Frame") then
				old:Destroy()
			end
		end
		for i = 1, max do
			local pip = Instance.new("Frame")
			pip.Name = "Pip" .. i
			pip.Size = UDim2.new(1 / max, -4, 1, 0)
			pip.LayoutOrder = i
			pip.BorderSizePixel = 0
			pip.Parent = pips
			corner(pip, 5)
			ShopStyle.outline(pip, 2)
		end
	end
	for _, pip in ipairs(pips:GetChildren()) do
		if pip:IsA("Frame") then
			pip.BackgroundColor3 = if pip.LayoutOrder <= level
				then row.accent else Theme.SAND_DEEP
		end
	end
end

-- One EARN row against the economy push. The same three questions a tree row
-- answers, asked of `StateUpdate` rather than `UpgradeState`: income has
-- always been pushed there, beside the coins it is priced against, and moving
-- the control did not move the data.
local function paintEarn(row: any, level: number, max: number,
	cost: number, coins: number)

	paintLadder(row, level, max, true)
	if level >= max then
		-- Not "MAXED" while a rebirth opens more of this ladder: the same
		-- lie the shop's own tile told, and this row is the fallback that
		-- draws when the revamped browser has not been built.
		local gated = Config.rebirthOpensMore(max)
		row.cost.Text = if gated then "REBIRTH" else "MAXED"
		row.cost.TextColor3 = if gated
			then Theme.readable(Theme.PRESTIGE, ShopStyle.SUNK)
			else ShopStyle.GOOD
	else
		row.cost.Text = format(cost)
		-- Affordability is on the PILL, never the card: the card's outline is
		-- the only thing saying which of the three sections a row belongs to,
		-- and tinting the whole card fought it. The trees follow the same rule.
		row.cost.TextColor3 = if coins >= cost then GOLD else Theme.MUTED_LIGHT
	end
end

-- ============================================================
-- COSMETICS VIEW
-- ============================================================

-- Each tab gets its own scroll, built by the same helper.
--
-- Sections inside a scroll exist because a fixed-height row cannot grow:
-- effects once lived in a pinned row with a horizontal layout, and six of them
-- needed 688px against a 584px panel, so the last one and a half were clipped
-- with no scrollbar to reach them. A scroll with AutomaticCanvasSize grows
-- instead, and a new category costs a header and a grid.
-- THE CARD, and the one size four different catalogues are laid out on.
--
-- Skins, effects, houses and decorations all come through
-- ensureCosmeticButton, so they all get this. The old cell was 130x62 -- a
-- 14-pixel colour stripe with two lines of text beside it, which is a LIST
-- ROW wearing a grid, and at twenty-one skins it read as a wall of
-- near-identical bars. A card gives the thing itself most of the tile: the
-- colour block is what a skin IS, and it is the only part a player is
-- actually choosing between.
--
-- 148x132 is measured against the panel, not picked. At the new 1040 cap the
-- content area is 950, which takes SIX cards across with the padding, and
-- four rows fit down -- 24 items visible where the old row-shaped tile showed
-- 15, so the card is both bigger per item AND less scrolling. It was 158x150
-- first, which looked right and measured wrong: five across, three down, and
-- the piggy tab went from 1.9 screens of scrolling to 3.2. Cards get taller
-- faster than they get more legible.
--
-- It falls to one column on a phone with no code deciding that; a UIGridLayout
-- wraps on its own.
--
-- Catalogue grids reflow on phones. ShopCatalogueLayout reduces preview space
-- and moves text rows directly; whole-card UIScale stays at one for clarity.
local cardFit = {
	full = UDim2.new(0, 156, 0, 182),
	scale = 1,
	grids = {} :: { UIGridLayout },
	cards = {} :: { UIScale },
}

local function makeScroll(parent: Frame): (ScrollingFrame, (string, number) -> TextLabel, (number) -> Frame)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Active = true
	scroll.Size = UDim2.new(1, 0, 1, 0)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	local inset = Instance.new("UIPadding")
	inset.PaddingLeft = UDim.new(0, 5)
	inset.PaddingRight = UDim.new(0, 5)
	inset.PaddingTop = UDim.new(0, 4)
	inset.Parent = scroll

	-- Hands the label back so a section can be ADDRESSED. The front page
	-- scrolls a tab to a section rather than dumping the player at the top of
	-- it, and the header is the thing it scrolls to.
	local function header(text: string, order: number): TextLabel
		-- A SECTION HEADER IS A SIGNPOST, so it is set at the weight of one.
		-- At 13px grey Gotham it was quieter than the item names underneath
		-- it, which inverts the hierarchy: the thing you scan for while
		-- scrolling was the faintest text on the screen.
		local label = Instance.new("TextLabel")
		-- NAMED AFTER THE SECTION. Six unnamed TextLabels in one scroll are
		-- indistinguishable to anything resolving a path -- a test, a tool,
		-- the next person -- and the click harness simply could not address
		-- the "?" chip parented to one of them. Same rule the admin panel's
		-- rows already follow.
		label.Name = "Section_" .. (text:gsub("[^%w]", ""))
		label.Size = UDim2.new(1, -10, 0, 30)
		label.LayoutOrder = order
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextSize = 22
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = ShopStyle.TEXT
		label.Text = text
		label.Parent = scroll
		return label
	end

	-- AutomaticSize on the wrapper is what lets the grid inside push the
	-- canvas taller as rows are added, instead of clipping at a fixed height.
	-- `cell` is optional: the default 130x62 suits a swatch and two lines of
	-- text, but a tile carrying a rendered 3D icon needs room for the icon
	-- AND the text beside it.
	local function grid(order: number, cell: UDim2?): Frame
		local frame = Instance.new("Frame")
		frame.Size = UDim2.new(1, -10, 0, 0)
		frame.AutomaticSize = Enum.AutomaticSize.Y
		frame.BackgroundTransparency = 1
		frame.LayoutOrder = order
		frame.Parent = scroll

		local g = Instance.new("UIGridLayout")
		g.CellSize = cell or cardFit.full
		-- Only the default-cell grids are cards. The bones, gadgets, rides and
		-- accessory grids pass their own size because they carry a rendered 3D
		-- icon, and they are not resized with these.
		if not cell then
			table.insert(cardFit.grids, g)
		end
		g.CellPadding = UDim2.new(0, 8, 0, 8)
		g.SortOrder = Enum.SortOrder.LayoutOrder
		g.Parent = frame
		-- Fill the row while retaining readable text and full-size touch targets.
		local desired = cell or cardFit.full
		local function fitGrid()
			local width = frame.AbsoluteSize.X
			local columns, height = require(ReplicatedStorage.Shared.ShopCatalogueLayout).metrics(
				width, scroll.AbsoluteSize.Y, Vector2.new(desired.X.Offset, desired.Y.Offset))
			g.CellSize = UDim2.new(1 / columns, -8 * (columns - 1) / columns, 0, height)
		end
		frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitGrid)
		scroll:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitGrid)
		if not cell then
			frame.ChildAdded:Connect(function(child)
				if child:IsA("GuiObject") then task.defer(function()
					if child.Parent then require(ReplicatedStorage.Shared.ShopCatalogueLayout).bindCard(child, desired.Y.Offset) end
				end) end
			end)
		end
		fitGrid()
		return frame
	end

	return scroll, header, grid
end

-- One scroll per tab, declared together and ahead of every section.
--
-- LAYOUT ORDERS ARE ALLOCATED IN BLOCKS OF A HUNDRED, one block per group of
-- sections, and that is not tidiness. Three tabs' worth of sections now share
-- a UIListLayout, and they are still WRITTEN in the order the old tabs were
-- built -- so a second group starting at 1 again would interleave itself
-- through the first, silently, with nothing on screen to say why the driveway
-- ornaments were sitting between the houses. A block also means inserting a
-- section never renumbers a neighbouring group.
--
--   Your Piggy     1..99 skins and effects      100+ the roll and accessories
--   Your Home      1..99 houses                 100+ decorations   200+ defending it
--   Your Gear      1..99 rides and styles       100+ what you carry out
local homeScroll, homeHeader, homeGrid = makeScroll(homeView)
require(ReplicatedStorage.Shared.ShopCatalogueLayout).bindSections(homeScroll)
local gearScroll, gearHeader, gearGrid = makeScroll(gearView)
SHOP.itemsScroll, SHOP.itemsHeader, SHOP.itemsGrid = makeScroll(SHOP.view.items)
SHOP.companionScroll, SHOP.companionHeader, SHOP.companionGrid = makeScroll(SHOP.view.companions)

-- EVERY WORD IN THE SHOP IS WHITE WITH A BLACK STROKE -- see `ShopStyle.popText`.
-- One call over the whole panel, now and as cards are built, rather than a
-- colour chosen per label in a hundred places.
ShopStyle.popTree(panel)
-- The Supplies tab's per-item summary, which replaced one "?" per section.
SHOP.supply = require(ReplicatedStorage.Shared.SupplyCards)
SHOP.supply.setup(panel, function() return latestCoins end, format)

-- WHERE EVERY SECTION IS, so the front page can jump to one.
--
-- `at` is whatever the player should be looking at when they arrive, which is
-- USUALLY the header and deliberately is not for the accessories: the roll
-- button sits above that block and is the entire point of it, so landing on
-- HATS would scroll the one control in the section off the top of the screen.
local sections: { [string]: { at: GuiObject, scroll: ScrollingFrame, tab: number } } = {}

-- Hung off one table for the same reason gadgetUI and rideUI are: this file is
-- one chunk against Luau's 200-local ceiling and has already hit it once.
--
-- DIRTY-DRIVEN, NOT CALLED FROM THE SEVEN PLACES THAT CHANGE ITS DATA. Two
-- separate bugs made that necessary and the first one cost an hour:
--
--   * Six catalogues arrive on six different remotes at join, in no fixed
--     order, and the front page summarises all of them. Rendering it from the
--     handler that happened to be edited first drew five shelves and left the
--     rides and the throwables permanently blank -- they had simply not
--     arrived yet.
--   * The obvious second hook, the coin tick, is not a tick. State is pushed
--     on CHANGE, so a player sitting on a full piggy bank generates no updates
--     at all, and the front page had no reason to ever look again.
--
-- So every data site sets `dirty` and one Heartbeat drains it: at most one
-- render a frame, whatever arrives in what order, with no site needing to know
-- what the others hold.
local frontUI = { render = nil :: any, dirty = false }

-- CATCH EFFECTS ARE SOLD ON GUARDIANS. A catch effect goes off when you nab a
-- thief, which is protecting your home -- the same job the guard does. They
-- used to share a Worn tab with Most Wanted gear; the gear is earned rather
-- than bought and lives in the bag now, which left the tab holding one
-- section behind a switch bar of its own.
--
-- Block 300, under the guard's coats (200s), in blocks of a hundred so
-- inserting a section never renumbers a neighbour.
sections.catch = { at = SHOP.companionHeader("NAB EFFECTS", 300),
	scroll = SHOP.companionScroll, tab = SHOP.at.companions }
SHOP.catchGrid = SHOP.companionGrid(302)

do
	local how = Instance.new("TextLabel")
	how.Size = UDim2.new(1, -10, 0, 60)
	how.LayoutOrder = 301
	how.BackgroundTransparency = 1
	how.Font = Enum.Font.Gotham
	how.TextSize = 13
	how.TextWrapped = true
	how.TextXAlignment = Enum.TextXAlignment.Left
	how.TextYAlignment = Enum.TextYAlignment.Top
	how.TextColor3 = Theme.MUTED
	-- ONE SHORT PARAGRAPH CARRYING THE ONE FACT THAT WOULD OTHERWISE READ
	-- AS A BUG: it goes off on THEM, not on you, so a player who buys one
	-- and then nabs somebody is not left wondering why nothing happened.
	how.Text = "A nab effect goes off on the thief when you NAB them and pull the "
		.. "stolen goods back out of their hands. You watch it happen to them, "
		.. "not to you. It changes nothing about the catch."
	ShopStyle.hintToggle(sections.catch.at, how)
end

-- ============================================================
-- SPECIAL OFFERS
-- ============================================================
--
-- The Robux passes have their own tab now (`Shared/PremiumShop`), with a
-- featured banner on the landing page pointing at it. They used to be text
-- cards at the bottom of the Worn tab, which this block's own comment called
-- a compromise: the front page had no room. The shell's landing does.

sections.houses = { at = homeHeader("MOVE UP THE STREET", 1), scroll = homeScroll, tab = SHOP.at.home }
local housesGridFrame = homeGrid(2)

-- MERGED WITH THE BONES, because they are the same verb. A grid holding
-- three items still takes a WHOLE ROW, so six one-to-three-item sections
-- spent six rows on ten items where two would hold them -- which is most of
-- why this tab scrolled. Both are "a stock you throw at something", so they
-- share a row and a header now; the frame is filled in where that header is
-- built, further down.
local gadgetsGridFrame = nil :: any

do
	-- Says what they are FOR, and names the two different things one does,
	-- because they look identical when you throw them and are not.
	--
	-- AutomaticSize rather than a measured height. The old label was pinned at
	-- 112 for the text it had; a fixed height is a number that has to be
	-- re-derived every time a word changes, and a wrapped line in a too-short
	-- row does not error -- it falls off the bottom and is silently clipped,
	-- which is how the plot sign came to read "12* . Neon Tower ." with the
	-- skin missing.
	local how = Instance.new("TextLabel")
	how.Size = UDim2.new(1, -10, 0, 0)
	how.AutomaticSize = Enum.AutomaticSize.Y
	how.LayoutOrder = 202
	how.BackgroundTransparency = 1
	how.Font = Enum.Font.Gotham
	how.TextSize = 13
	how.TextWrapped = true
	how.TextXAlignment = Enum.TextXAlignment.Left
	how.TextYAlignment = Enum.TextYAlignment.Top
	how.TextColor3 = Theme.MUTED
	-- THIS COPY DESCRIBED THE OLD RULE AND HAD TO BE REWRITTEN WITH IT. It
	-- read "throw at anyone for a laugh: a brief wobble, nothing lost. On a
	-- thief carrying coins the slow lasts much longer" -- which was an exact
	-- description of the prank branch that no longer exists, and would have
	-- taught a player that helping a friend rob somebody does not work. The
	-- same failure this file keeps recording as copy outliving the thing it
	-- described, caught here in the same change that made it stale.
	--
	-- It names the two things that now read as bugs if nobody says them: a
	-- throw can MISS, and the same person cannot be hit twice in a row.
	how.Text = "Aim it. The throw goes where you are looking and drops as it "
		.. "flies, so lead anyone running and aim high for anyone far away. "
		.. "It works on anybody at full strength, and the same person cannot "
		.. "be hit twice in a row. You still have to nab a thief to get the "
		.. "coins back."
	-- Held for the bones header, which is built further down and is the one
	-- this section now shares.
	SHOP.gadgetHint = how.Text
	how:Destroy()
end

SHOP.atHomeHead = SHOP.itemsHeader("AT HOME", 200)
local homeGridFrame = SHOP.itemsGrid(201)

-- THE SNEAKING SECTION IS GONE with the Ladder and the Raincoat, which were
-- the whole of it (`Config.THIEF_KIT` is empty). Its grid is kept as a
-- detached frame so the stealth renderer has somewhere to put a card if that
-- catalogue ever grows again, without a header over an empty shelf.
local stealthGridFrame = Instance.new("Frame")

sections.rides = { at = gearHeader("GET AROUND", 1), scroll = gearScroll, tab = SHOP.at.rides }
-- Wide cells: these tiles carry a rendered 3D model AND three lines of text,
-- where the default 130x62 was drawn for a colour swatch and two.
local ridesGridFrame = gearGrid(2)

-- The rule, stated once, where somebody will read it before they spend four
-- and a half million coins on something that turns itself off.
--
-- It has to be here rather than only in a refusal toast, because the first
-- time a board vanishes is the moment a player decides the thing they bought
-- is broken -- and by then they are mid-robbery and not reading.
local rideNote = Instance.new("TextLabel")
rideNote.Size = UDim2.new(1, -10, 0, 62)
rideNote.LayoutOrder = 3
rideNote.BackgroundTransparency = 1
rideNote.Font = Enum.Font.Gotham
rideNote.TextSize = 12
rideNote.TextWrapped = true
rideNote.TextXAlignment = Enum.TextXAlignment.Left
rideNote.TextYAlignment = Enum.TextYAlignment.Top
rideNote.TextColor3 = Theme.MUTED
rideNote.Text = "Street only. You hop off at any garden gate, and never while "
	.. "carrying stolen goods: a getaway is always on foot."
ShopStyle.hintToggle(sections.rides.at, rideNote)

-- Decorations, under the house they stand in front of rather than in a tab
-- of their own. Three sections, one per zone, and the zone is the thing a
-- player is actually choosing between.
sections.decor = { at = homeHeader("FRONT LAWN", 100), scroll = homeScroll, tab = SHOP.at.home }
local lawnGridFrame = homeGrid(101)
-- No DRIVEWAY section: the Hatchback and the Sports Car were the only two
-- items that could stand there, and a header with an empty grid under it reads
-- as a catalogue that failed to load.
homeHeader("BY THE KERB", 104)
local vergeGridFrame = homeGrid(105)

-- THE TROPHY SHELF IS GONE FROM THIS TAB, WITH THE TROPHIES THEMSELVES.
--
-- `Config.TROPHIES` and `Config.TROPHY_PLINTHS` are empty tables now: the ten
-- earned trophies and the six plinth finishes were retired in favour of three
-- stat panels and a wanted poster on the house's own wall -- and that room is
-- retired in turn (2026-09-22); the achievements move into the real base
-- later. Every counter survives in `data.trophies` -- victims, catches,
-- sprees, clean cracks, wanted appearances, harvests -- so what went is the
-- CATALOGUE and never the record of what anybody did.
--
-- The header, the grid and the "?" explainer went with them rather than being
-- hidden behind an empty payload. A header with an empty grid under it reads
-- as a catalogue that failed to load: that is the note three sections above
-- this one, and it is what the retired parked cars left behind when their
-- DRIVEWAY section outlived the only two items that could stand in it.

-- THE DOG'S COAT, ON HOME RATHER THAN ON DEFEND/ROB, AND THE SPLIT IS THE
-- POINT. A coat is TASTE and the Guard Dog rung is POWER: the tier decides
-- how fast the dog is, how far it hears and whether it catches anybody, and
-- it lives on the upgrade tab with the fences and the locks where a thief can
-- price it. What is sold here changes three colours and nothing else.
--
-- The same line the shop already draws between the house you live in and the
-- income that paid for it -- and the reason it is safe to sell a dog's
-- appearance at all. See the header on `Config.DOG_COATS`.
--
-- IN `SHOP` RATHER THAN A LOCAL OF ITS OWN, for the register budget: this
-- chunk sits at Luau's 200-local ceiling and has twice lost the ENTIRE HUD to
-- a handful of new top-level locals, dying on an innocent variable thousands
-- of lines from the change. `sections` is an existing table too, so the pair
-- costs this file nothing.
-- "YOUR GUARD" RATHER THAN "YOUR GUARD DOG", because three of the nine coats
-- in this section are not dogs: a Gorilla, a Raptor and a Triceratops coat
-- swap the rig outright. A header is a signpost read while scrolling past, so
-- it has to be true of everything under it rather than of most of it.
sections.dogCoats = { at = SHOP.companionHeader("CHOOSE YOUR GUARDIAN", 200), scroll = SHOP.companionScroll, tab = SHOP.at.companions }

-- THE NAME PICKER, AND THERE IS NOWHERE IN THIS GAME A PLAYER TYPES ANY MORE.
--
-- This was a text box -- the one place a player's own words were shown to
-- other players -- filtered server-side and every bit of that filtering
-- correct. It is a list of approved names now (`Config.DOG_NAMES`), because a
-- classifier that mostly works is the wrong instrument for a name standing
-- over a kennel in a game played by nine-year-olds. See the header on
-- `Config.DOG_NAMES`.
--
-- WHAT THAT BUYS THE CLIENT: every control in this shop is a button over a
-- fixed catalogue again, so there is nothing to validate here and no way for
-- this end to be the weak one. The server still checks the name against the
-- same list, because a client is never the thing that decides.
--
-- The cell is 104x34 rather than the grid's default card: a name is one short
-- word and a row of full-size cards for forty of them would be most of the
-- tab. Measured on the longest entry -- "Marbles" at 13px FredokaOne is 54px
-- against 94 of usable width, so nothing truncates.
SHOP.dogNameGrid = SHOP.companionGrid(202, UDim2.fromOffset(104, 44))

-- FORTY CHIPS ARE A PAGE, SO THEY LIVE BEHIND A BUTTON NOW.
--
-- The picker was always open, which put forty name chips between the header
-- and the coats -- most of the tab, permanently, for a control a player
-- touches about once. A name is not something you browse; it is something you
-- change, which is a button.
--
-- THE BUTTON READS THE CURRENT NAME rather than saying "Change name", because
-- that makes it a READOUT as well as a control: a player who wants to know
-- what their dog is called no longer has to open the picker to find out. Both
-- states are repainted from the server's answer beside the chips themselves,
-- so a refused name cannot leave this showing something that is not on the
-- plate.
--
-- A UIListLayout SKIPS INVISIBLE CHILDREN, so hiding the grid genuinely
-- closes the gap rather than leaving forty chips' worth of hole -- the same
-- property the hot bar relies on and the same one the "?" bubbles use.
SHOP.dogNameToggle = (function()
	local button = Instance.new("TextButton")
	button.Name = "DogNameToggle"
	-- SIZED TO ITS OWN WORDS, NOT TO THE ROW. Full width made it the widest
	-- element on the tab and the least informative -- a 1148-pixel centred bar
	-- reads as a banner or a section header, which is the one thing it must
	-- not read as. At 240 it is a control sitting where the first card sits,
	-- and still a far larger touch target than the 44 a tablet needs.
	button.Size = UDim2.fromOffset(240, 40)
	-- LayoutOrder IS AN INTEGER, so there is no slotting in at 200.5 between
	-- the header and the grid: the name section is renumbered instead and the
	-- kennel's two orders moved up with it.
	button.LayoutOrder = 201
	button.BackgroundColor3 = ShopStyle.CARD
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.FredokaOne
	button.TextSize = 14
	button.TextColor3 = Theme.INK
	button.Text = "Name your guard"
	button.Parent = SHOP.companionScroll
	corner(button, 12)
	ShopStyle.outline(button, 2)
	button.Activated:Connect(function()
		SHOP.dogNameGrid.Visible = not SHOP.dogNameGrid.Visible
		-- Repainted here as well as on the next push, because a push only
		-- arrives when something CHANGES and opening the picker changes
		-- nothing on the server.
		if SHOP.dogNamePaint then
			SHOP.dogNamePaint()
		end
	end)
	return button
end)()

-- Shut by default: the tab should open on the coats, which is what somebody
-- came here to look at.
SHOP.dogNameGrid.Visible = false

do
	-- "No name" FIRST, and it is the row a child reaches for after picking one
	-- they have gone off. Sends "" -- the same clear the server treats as
	-- free -- and reads as the breed on the plate rather than as blank.
	local options: { string } = { "" }
	for _, name in ipairs(Config.DOG_NAMES) do
		table.insert(options, name)
	end

	for _, name in ipairs(options) do
		local chip = Instance.new("TextButton")
		-- NAMED SO A PROBE CAN ADDRESS IT. Forty unnamed TextButtons in one
		-- grid are indistinguishable to anything resolving a path, which is
		-- the rule the section headers and the admin rows already follow.
		chip.Name = if name == "" then "DogName_None" else "DogName_" .. name
		chip.Size = UDim2.fromScale(1, 1)
		chip.BackgroundColor3 = ShopStyle.CARD
		chip.BorderSizePixel = 0
		chip.AutoButtonColor = false
		chip.Font = Enum.Font.FredokaOne
		chip.TextSize = 13
		chip.TextColor3 = Theme.INK
		chip.Text = if name == "" then "No name" else name
		chip.Parent = SHOP.dogNameGrid
		corner(chip, 10)
		ShopStyle.outline(chip, 2)
		chip.Activated:Connect(function()
			Remotes.get("CosmeticRequest"):FireServer("dogname", name)
		end)
	end
end

SHOP.dogCoatGrid = SHOP.companionGrid(203)

-- THE GARDEN: THREE SHELVES, AND NOT ONE OF THEM SPENDS A LAWN SLOT.
--
-- They sit under FRONT LAWN's own tab and deliberately NOT under its header,
-- because the nine slots up there are a shelf you curate and these are not on
-- it -- see `Config.BORDER_PLANTS`. Folding them in would say the opposite of
-- the thing that makes them worth having: that you can plant a garden without
-- clearing your trophies to do it.
--
-- Three headers rather than one for the reason the kennel and the toys have
-- their own: a card reading "Box Hedge" beside one reading "Red Brick" gives
-- a nine-year-old nothing to tell a hedge from a paving slab.
sections.garden = { at = homeHeader("ALONG THE FENCE", 210), scroll = homeScroll, tab = SHOP.at.home }
SHOP.borderGrid = homeGrid(211)

homeHeader("THE PATH TO YOUR PIGGY", 212)
SHOP.pathGrid = homeGrid(213)

homeHeader("WINDOW BOXES", 214)
SHOP.windowGrid = homeGrid(215)

-- ACCESSORIES ARE RETIRED, so the piggy tab is skins and effects. The roll
-- button, its loot price ladder, the per-slot grids and the collection
-- renderer went with them: with an empty catalogue the button reads
-- COLLECTION COMPLETE forever, which is a control that does nothing wearing
-- a finished state. `PigGear.luau` still builds all fourteen and
-- `Config.ACCESSORIES` is where they come back -- see the retirement note
-- there for what else had to go and why.

-- Bones: the only repeat purchase in the game, so a tile never reads as
-- "owned" -- it shows what you are holding and stays buyable forever.
-- TWO SHELVES, BECAUSE THEY ARE TWO SIDES OF A ROBBERY. The plunger, the gum
-- and the zapper are how you STOP a robber; the bones are how a robber gets
-- past a guard dog. One "THROW AT SOMEBODY" header over both said neither, and
-- stopped being true of the zapper the day it became an arc instead of a throw.
sections.kit = { at = SHOP.itemsHeader("STOP ROBBERS", 1), scroll = SHOP.itemsScroll, tab = SHOP.at.items }
gadgetsGridFrame = SHOP.itemsGrid(2)
SHOP.itemsHeader("GET PAST GUARD DOGS", 100)
local bonesGridFrame = SHOP.itemsGrid(101)

do
	local how = Instance.new("TextLabel")
	how.Size = UDim2.new(1, -10, 0, 96)
	how.LayoutOrder = 102
	how.BackgroundTransparency = 1
	how.Font = Enum.Font.Gotham
	how.TextSize = 13
	how.TextWrapped = true
	how.TextXAlignment = Enum.TextXAlignment.Left
	how.TextYAlignment = Enum.TextYAlignment.Top
	how.TextColor3 = Theme.MUTED
	how.Text = "Hold one from the bar, click near a dog, and it naps in its "
		.. "kennel. Bigger dogs resist. Only a Golden Bone stops one that "
		.. "has already seen you."
	-- Both halves of the merged section in one bubble. string.char rather
	-- than a written escape: this file has twice had a backslash sequence
	-- rewritten in transit into the bytes it named, which ends the literal
	-- and takes the whole HUD down at compile time.
	-- NO "?" ON THIS SECTION ANY MORE: each item carries its own summary
	-- (Shared/SupplyCards), which is where these words went.
	how:Destroy()
end

-- The guard duty treat renders in Your Home. It is bought beside the bones
-- because it is the thing that refuses them, but it is used on your OWN dog
-- before you go out rather than being kit you carry.
-- Merged into AT HOME, which is what a treat already is: something you use
-- on your own plot before you go out. The radio deliberately does NOT join
-- them -- see its own header below.
local treatGridFrame = homeGridFrame

do
	local how = Instance.new("TextLabel")
	how.Size = UDim2.new(1, -10, 0, 74)
	how.LayoutOrder = 222
	how.BackgroundTransparency = 1
	how.Font = Enum.Font.Gotham
	how.TextSize = 13
	how.TextWrapped = true
	how.TextXAlignment = Enum.TextXAlignment.Left
	how.TextYAlignment = Enum.TextYAlignment.Top
	how.TextColor3 = Theme.MUTED
	how.Text = "Use one before you go out. Your guard stays awake, refuses cheap "
		.. "bones, and its collar glows so robbers can see. A Golden Bone "
		.. "still gets past."
	-- AT HOME never had an explainer of its own, so the merged bubble is just
	-- the treat's, hung on the header. `tostring(nil)` would have put the word
	-- "nil" in front of a nine-year-old, which is why this is not a
	-- concatenation.
	how:Destroy()
end

-- THE RADIO GETS ITS OWN HEADER, and not because it needs the room.
--
-- It is the one thing on this tab that does nothing to your own plot: a treat
-- is for your own dog, and this brings a police car onto the whole street.
-- Sold under AT HOME beside it, the radio would read as a second way to
-- defend your piggy, which is precisely what it is not.
local radioHead = SHOP.itemsHeader("CALL THE PATROL", 400)
local radioGridFrame = SHOP.itemsGrid(401)

do
	-- What it does, and the two things about it that would otherwise read as
	-- bugs: that the patrol may drive through and arrest nobody, and that it
	-- can come for the person who paid for it. Same reason the gadgets carry
	-- an explainer -- "nothing happened" is indistinguishable from broken.
	local how = Instance.new("TextLabel")
	how.Size = UDim2.new(1, -10, 0, 130)
	how.LayoutOrder = 232
	how.BackgroundTransparency = 1
	how.Font = Enum.Font.Gotham
	how.TextSize = 13
	how.TextWrapped = true
	how.TextXAlignment = Enum.TextXAlignment.Left
	how.TextYAlignment = Enum.TextYAlignment.Top
	how.TextColor3 = Theme.MUTED
	how.Text = "Calls the patrol out now. You do not choose who they chase: "
		.. "whoever robs somebody, or the name on the MOST WANTED board. "
		.. "That could be you. The next patrol still comes as normal."
	how:Destroy()
end

local cosmeticButtons: { [string]: { button: TextButton, title: TextLabel, sub: TextLabel, swatch: Frame? } } = {}

-- One builder for four catalogues: skins, effects, houses and decorations.
-- Every one of them is a card with the same three rows, so a player learns
-- the layout once and reads all four.
local function ensureCosmeticButton(kind: string, key: string, info: any)
	local existing = cosmeticButtons[kind .. ":" .. key]
	if existing then
		return existing
	end

	local button = Instance.new("TextButton")
	-- No explicit Size: UIGridLayout drives cell dimensions for both kinds.
	button.LayoutOrder = info.order or 99
	button.BackgroundColor3 = ShopStyle.CARD
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.FredokaOne
	button.Text = ""
	button.Parent = if kind == "catch" then SHOP.catchGrid
		elseif kind == "house" then housesGridFrame
		elseif kind == "decorLawn" then lawnGridFrame
		elseif kind == "decorVerge" then vergeGridFrame
		elseif kind == "dogcoat" then SHOP.dogCoatGrid
		elseif kind == "border" then SHOP.borderGrid
		elseif kind == "path" then SHOP.pathGrid
		-- The last branch is a CATCH-ALL and is deliberately a real grid rather
		-- than nil: an unknown kind landing in the wrong section is a card
		-- somebody notices, where a nil parent is a card that is never built and
		-- says nothing at all. It used to be the plinth grid, retired with the
		-- trophies.
		else SHOP.windowGrid
	corner(button, 16)
	ShopStyle.gloss(button)

	-- One scale per card, taken from the current fit, so a card built after a
	-- resize comes out the same size as the ones already on screen.
	local cardScale = Instance.new("UIScale")
	cardScale.Scale = cardFit.scale
	cardScale.Parent = button
	table.insert(cardFit.cards, cardScale)

	-- THE COLOUR BLOCK, which is most of the card.
	--
	-- A skin IS its colour, and a 14-pixel stripe down the side of a text row
	-- was showing about a fiftieth of it. Two-tone where there are two colours
	-- to show -- body into trim for a skin, the two ends of the particle
	-- gradient for an effect -- because a single flat rectangle cannot tell
	-- Bubblegum from Sunset at a glance and the trim is half of what makes a
	-- piggy look like anything.
	--
	-- Effects used to get no swatch at all, on the grounds that a particle
	-- system has nothing to show in a still image. That produced eleven
	-- identical grey tiles for the six-hundred-thousand-coin end of the shop.
	-- Their gradient is the honest answer: Inferno reads as fire and Frost
	-- reads as ice without rendering a single particle.
	local swatch = Instance.new("Frame")
	swatch.Name = "Swatch"
	swatch.Size = UDim2.new(1, -16, 0, 100)
	swatch.Position = UDim2.new(0, 8, 0, 8)
	swatch.BackgroundColor3 = info.body or info.walls or info.swatch
		or Theme.PAPER_DEEP
	swatch.BorderSizePixel = 0
	swatch.ClipsDescendants = true
	swatch.Parent = button
	corner(swatch, 11)
	ShopStyle.outline(swatch, 2)

	-- THE PREVIEW: the actual item, rendered.
	--
	-- Three of the five kinds here can be built now that House, Decor and
	-- PiggyModel live in Shared, and every one of them was a flat rectangle
	-- before: nineteen ornaments as identical grey squares, twelve houses as
	-- a wall colour, and a skin as the one thing a stripe of colour cannot
	-- tell you -- what a piggy wearing it looks like.
	--
	-- EFFECTS ARE THE EXCEPTION AND STAY A GRADIENT. A particle system has
	-- nothing to render in a still frame, and the two ends of its gradient
	-- are the honest picture: Inferno reads as fire and Frost reads as ice
	-- without a single particle. Rendering an unlit emitter would be worse
	-- than the swatch it replaced.
	local preview: Model? = nil
	if kind == "house" then
		-- Static artwork uses the authored house, with consistent framing.
		-- Future houses without an image retain the real-model fallback.
		if not require(ReplicatedStorage.Shared.ShopHouseCards).image(swatch, key) then
			preview = House.build(Config.houseLevelOf(key) or 0, CFrame.new(), nil)
		end
	elseif kind:sub(1, 5) == "decor" then
		preview = Decor.buildOne(key, CFrame.new(), nil)
	elseif kind == "dogcoat" then
		require(ReplicatedStorage.Shared.ShopGuardianCards).image(swatch, key)
	end

	-- BOTH PARTICLE CATALOGUES GO THROUGH ONE SIMULATION, which is the whole
	-- reason a catch effect was authored in `Config.EFFECTS`' own field
	-- shape. A second renderer for a burst would be the near-identical copy
	-- this project keeps recording as the thing that drifts -- and the two
	-- would then disagree about what an effect looks like on the one screen
	-- where a player decides whether to buy it.
	--
	-- THE SUBJECT IS THE CAUGHT THIEF, NOT A PIG. It used to be the pig, on
	-- the argument that the stolen piggy is what a nab knocks loose -- and a
	-- burst round a pig is exactly what the retired piggy auras looked like,
	-- so the shelf read as a shelf of them. `makeEffectIcon` swaps the
	-- subject for `CatchIcons.thief` whenever it is handed a catch row.
	if kind == "catch" then
		-- An effect with a drawn picture shows the picture (CatchIcons);
		-- the rest simulate their burst.
		preview = require(ReplicatedStorage.Shared.CatchIcons).build(key)
		if not preview then
			swatch.BackgroundColor3 = swatch.BackgroundColor3:Lerp(ShopStyle.SUNK, 0.78)
			makeEffectIcon(swatch, key, Config.CATCH_EFFECTS[key])
		end
	end

	if preview then
		-- Behind the model, the item's own colour knocked most of the way
		-- toward the panel: enough that the tile still reads as "the green
		-- one" while scrolling, not so much that a pink piggy is rendered on
		-- a pink field and disappears.
		swatch.BackgroundColor3 = swatch.BackgroundColor3:Lerp(ShopStyle.SUNK, 0.72)
		makeModelIcon(swatch, preview, UDim2.new(1, 0, 1, 0), UDim2.new(), true)
	elseif kind ~= "house" and kind ~= "dogcoat" then
		local second = info.trim or info.swatch2
		if second then
			local gradient = Instance.new("UIGradient")
			gradient.Color = ColorSequence.new(swatch.BackgroundColor3, second)
			gradient.Rotation = 90
			gradient.Parent = swatch
		end
	end

	-- THE RARITY BORDER.
	--
	-- The card already says two things with colour: the swatch is what the
	-- item looks like, and the background is whether you own it or can afford
	-- it. The tier is a third, and it goes on the EDGE because the edge is the
	-- only part of a card not already carrying something -- painting the
	-- background by rarity would have fought the affordability colour that was
	-- there first, and tinting the swatch would have lied about what the skin
	-- looks like.
	--
	-- Legendary is drawn thicker as well as gold. Colour alone separates four
	-- tiers only for players who can see all four, and this is a game for
	-- nine-year-olds where roughly one boy in twelve is colour-blind: red-green
	-- confusion would not touch this palette, but blue-purple (Rare against
	-- Epic) is exactly the pair that goes. Weight is a second channel that
	-- costs nothing.
	--
	-- IT IS ALSO THE CARD'S ONLY OUTLINE, and that is forced rather than
	-- chosen: a GuiObject takes ONE UIStroke, so the shop's dark edge and the
	-- rarity edge cannot both be on the card. Rarity wins, because it is the
	-- one carrying information -- and at the weight the rest of the shop is
	-- drawn at, a 3-pixel coloured border does the separating job the dark
	-- edge would have done anyway. Legendary goes to 5, keeping the two
	-- channels (hue AND weight) the colour-blind case needs.
	local tier = Config.RARITIES[info.rarity] or Config.RARITIES.common

	local edge = Instance.new("UIStroke")
	edge.Name = "RarityEdge"
	edge.Color = tier.colour
	edge.Thickness = if info.rarity == "legendary" then 5 else 3
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = button

	-- The word, because a colour nobody has been taught is just decoration.
	-- Bottom-left of the swatch: it sits over the item's own colour, so it
	-- carries the tier colour as a background and dark ink on top rather than
	-- coloured text, which would be unreadable on the half of the catalogue
	-- whose swatch happens to be the same hue.
	local tag = Instance.new("TextLabel")
	tag.Name = "RarityTag"
	-- 60 wide, measured: "LEGENDARY" at 9px GothamBold renders 55px and the
	-- first attempt at 52 clipped the Y off the longest tier in the game.
	tag.Size = UDim2.new(0, 64, 0, 15)
	tag.Position = UDim2.new(0, 5, 1, -20)
	tag.BackgroundColor3 = tier.colour
	tag.BorderSizePixel = 0
	tag.Font = Enum.Font.GothamBold
	tag.TextSize = 9
	-- BLACK, not near-black. The tag prints on the tier's own colour, and the
	-- darkest of those (Epic) has a luminance of 0.198 -- which put a (20, 24,
	-- 32) ink at 4.16:1, just under the floor for a 9px label. Pure black is
	-- the only lever here, since the background is carrying the meaning and
	-- cannot move, and it takes every tier clear.
	tag.TextColor3 = Color3.new(0, 0, 0)
	tag.Text = string.upper(tier.label)
	tag.Parent = swatch
	corner(tag, 999)
	ShopStyle.outline(tag, 2)
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -16, 0, 20)
	title.Position = UDim2.new(0, 8, 0, 110)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	-- A fixed TextSize with truncation rather than TextScaled, so every card
	-- on the row sets its name at the same size. TextScaled would shrink
	-- "Basketball Hoop" and leave "Frost" huge beside it, which reads as the
	-- two being different kinds of thing.
	title.TextSize = 15
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = ShopStyle.TEXT
	title.Text = info.name
	title.Parent = button

	-- NO BLURB ROW. A 156-wide card carrying a name, a line of description AND
	-- a price is three rows of prose stacked on a picture, and it is most of
	-- what made a shelf of things to want read as a list of settings. The
	-- description is not lost -- it is exactly the thing a card can afford to
	-- put behind a tap, because a player who has stopped to look at one item
	-- is reading, and a player scanning a shelf is not.

	-- THE PRICE ROW IS A PILL, and it stays a plain TextLabel underneath so
	-- that none of the state code changes. Roughly a dozen sites write
	-- `sub.Text` and `sub.TextColor3` -- owned, equipped, affordable, too
	-- dear, REBIRTH DROP, medal-priced -- and every one of them still reads
	-- correctly as coloured type on a dark pill. Rebuilding it as a bespoke
	-- widget would have meant touching all of them.
	local sub = Instance.new("TextLabel")
	sub.Name = "Price"
	sub.Size = UDim2.new(1, -16, 0, 24)
	sub.Position = UDim2.new(0, 8, 0, 150)
	sub.BackgroundColor3 = ShopStyle.SUNK
	sub.BorderSizePixel = 0
	sub.Font = Enum.Font.FredokaOne
	sub.TextSize = 13
	sub.TextTruncate = Enum.TextTruncate.AtEnd
	sub.TextColor3 = GOLD
	sub.Text = ""
	sub.Parent = button
	corner(sub, 999)
	ShopStyle.outline(sub, 2)

	local subPad = Instance.new("UIPadding")
	subPad.PaddingLeft = UDim.new(0, 9)
	subPad.PaddingRight = UDim.new(0, 9)
	subPad.Parent = sub

	button.Activated:Connect(function()
		-- Lawn and driveway are separate GRIDS but one server-side kind; the
		-- item's own zone decides where it lands.
		Remotes.get("CosmeticRequest"):FireServer(
			if kind:sub(1, 5) == "decor" then "decor" else kind, key)
	end)

	local entry = { button = button, title = title, sub = sub, swatch = swatch,
		preview = preview }
	if kind == "house" then
		require(ReplicatedStorage.Shared.ShopHouseCards).decorate(entry, info)
	elseif kind == "dogcoat" then
		require(ReplicatedStorage.Shared.ShopGuardianCards).decorate(entry, key)
	end
	cosmeticButtons[kind .. ":" .. key] = entry
	return entry
end

-- Catalogue grids adapt their column count; touch targets and text retain their size.

local latestCosmetics: { skins: any, effects: any }? = nil

local function renderCosmetics()
	if not latestCosmetics then
		return
	end

	-- Decorations. Bought once and placed automatically, so a tile is simply
	-- owned or for sale -- there is no equip state to show.
	for key, info in pairs(latestCosmetics.decor or {}) do
		local kind = if info.zone == "verge" then "decorVerge" else "decorLawn"
		local entry = ensureCosmeticButton(kind, key, info)
		entry.title.Text = info.name

		if info.owned and info.placed then
			entry.sub.Text = "OUT - tap to store"
			entry.sub.TextColor3 = Theme.GOOD
			entry.button.BackgroundColor3 = ShopStyle.OWNED
		elseif info.owned then
			entry.sub.Text = "Stored - tap to place"
			entry.sub.TextColor3 = Theme.MUTED_LIGHT
			entry.button.BackgroundColor3 = ShopStyle.DEAR
		elseif info.passName then
			-- No decoration is pass-exclusive today. Written anyway, because
			-- `Config.passItems` sweeps all six catalogues -- so the day one is,
			-- the alternative is this loop reaching `format(nil)` and throwing.
			entry.sub.Text = info.passName:upper()
			entry.sub.TextColor3 = Theme.GOLD_INK
			entry.button.BackgroundColor3 = ShopStyle.LOCKED
		elseif info.loot then
			-- A SET ITEM, AND THERE IS NO LONGER A PRICE TO PRINT. These used
			-- to carry a loot price so that "nothing is ever locked behind
			-- luck" held -- a drop only saved you the wait. The currency is
			-- gone, so the guaranteed route went with it and the card says
			-- where the thing actually comes from instead of what it costs.
			-- `info.cost` is nil for a set item and `format` floors its
			-- argument, so the branch below would throw rather than render a
			-- wrong number; this one still has to come first.
			entry.sub.Text = "FROM THE ALIEN CACHE"
			entry.sub.TextColor3 = Theme.MUTED_LIGHT
			entry.button.BackgroundColor3 = ShopStyle.LOCKED
		else
			entry.sub.Text = format(info.cost)
			entry.sub.TextColor3 = GOLD
			entry.button.BackgroundColor3 = if latestCoins >= info.cost
				then ShopStyle.BUY
				else ShopStyle.CARD
		end
	end

	-- THE DOG'S COAT, AND IT RENDERS A REAL DOG NOW.
	--
	-- This used to read "no rendered preview, and that is a limit rather than
	-- a choice: `GuardDog` is a SERVICE, so the client cannot build a dog" --
	-- and then, correctly, that moving `GuardDog` into `Shared` was not worth
	-- it, because it carries patrol, chase, sleep and bark behaviour that has
	-- no business on a client.
	--
	-- BOTH HALVES WERE RIGHT ABOUT `GuardDog` AND WRONG ABOUT THE DOG. What
	-- a card needs is which rig, what colour, and the meshes -- none of which
	-- is behaviour. The first two moved to `Shared/GuardRig` (pure functions
	-- of Config and the catalogue) and the rigs a card can ask for are
	-- published to ReplicatedStorage at boot. Not one line of patrol came
	-- with them.
	-- WHICH NAME IS ON THE DOG, painted from the SERVER's answer rather than
	-- from whichever chip was last pressed: a refused name (a stale client
	-- sending something off the list) has to leave the picker showing what is
	-- actually on the plate.
	if SHOP.dogNameGrid then
		-- HELD SO THE TOGGLE CAN CALL IT. Opening the picker has to repaint
		-- immediately and no push is coming, because nothing on the server
		-- changed -- see the note over `SHOP.dogNameToggle`.
		SHOP.dogNamePaint = function()
			local current = latestCosmetics.dogName or ""
			local wanted = if current == "" then "DogName_None" else "DogName_" .. current
			for _, chip in ipairs(SHOP.dogNameGrid:GetChildren()) do
				if chip:IsA("TextButton") then
					chip.BackgroundColor3 = if chip.Name == wanted
						then ShopStyle.OWNED
						else ShopStyle.CARD
				end
			end
			if SHOP.dogNameToggle then
				local open = SHOP.dogNameGrid.Visible
				-- NAMES WHAT IS ACTUALLY STANDING THERE. With a creature coat
				-- on, "Name your dog" is wrong in the same way the nameplate
				-- was -- so the prompt asks about the raptor, the gorilla or
				-- the triceratops by name, from the same `GuardRig.species`
				-- the plate over its head reads.
				local equipped: string? = nil
				for coatKey, coat in pairs(latestCosmetics.dogCoats or {}) do
					if coat.equipped then
						equipped = coatKey
					end
				end
				SHOP.dogNameToggle.Text = if open
					then "Done"
					elseif current == "" then ("Name your %s"):format(
						require(ReplicatedStorage.Shared.GuardRig).species(equipped):lower())
					else ("Name: %s"):format(current)
				SHOP.dogNameToggle.BackgroundColor3 = if open
					then ShopStyle.OWNED
					else ShopStyle.CARD
			end
		end
		SHOP.dogNamePaint()
	end

	for key, info in pairs(latestCosmetics.dogCoats or {}) do
		local entry = ensureCosmeticButton("dogcoat", key, info)
		entry.title.Text = info.name
		entry.sub.Text = if info.equipped then "ON GUARD"
			elseif info.owned then "Tap to guard"
			else format(info.cost)
		require(ReplicatedStorage.Shared.ShopGuardianCards).paint(entry, info, latestCoins)
	end

	-- THE GARDEN, THREE SHELVES OFF ONE LOOP.
	--
	-- The three catalogues are the same transaction over three tables, so the
	-- only thing that differs per shelf is the WORD on an equipped card -- and
	-- that word is the whole reason they are not one grid. "PLANTED",
	-- "LAID" and "UP" each name what actually happened to the thing, which is
	-- the same call the dog's three shelves make when they refuse to share
	-- "EQUIPPED": what is worn, what is stood in and what is planted are
	-- different relationships, and one sentence for all of them describes the
	-- wrong object two times in three.
	for _, shelf in ipairs({
		{ kind = "border", on = "PLANTED", verb = "Tap to plant" },
		{ kind = "path", on = "LAID", verb = "Tap to lay" },
		{ kind = "window", on = "UP", verb = "Tap to hang" },
	}) do
		for _, info in ipairs((latestCosmetics.garden or {})[shelf.kind] or {}) do
			local entry = ensureCosmeticButton(shelf.kind, info.key, info)
			entry.title.Text = info.name

			if info.equipped then
				entry.sub.Text = shelf.on
				entry.sub.TextColor3 = Theme.GOOD
				entry.button.BackgroundColor3 = ShopStyle.OWNED
			elseif info.owned then
				entry.sub.Text = shelf.verb
				entry.sub.TextColor3 = Theme.MUTED_LIGHT
				entry.button.BackgroundColor3 = ShopStyle.DEAR
			else
				entry.sub.Text = format(info.cost)
				entry.sub.TextColor3 = GOLD
				entry.button.BackgroundColor3 = if latestCoins >= info.cost
					then ShopStyle.BUY
					else ShopStyle.CARD
			end
		end
	end

	-- Houses are a shelf (schema 26): every house is for sale until owned,
	-- and every owned one stays available to move into for free. Which is
	-- why an owned tile reads as an action ("Tap to move in") rather than as
	-- a state -- "Moved out" described the situation accurately and gave no
	-- hint that tapping would undo it. Keyed by the house's ID, which is
	-- what the server validates the tap against; the position is only the
	-- display order. (The individual-purchase card states in
	-- `docs/BRIEFS-FOR-GPT.md` B1 land on this loop.)
	for _, info in ipairs(latestCosmetics.houses or {}) do
		local entry = ensureCosmeticButton("house", info.id, info)
		entry.title.Text = info.name

		if info.current then
			entry.sub.Text = "YOU LIVE HERE"
			entry.sub.TextColor3 = Theme.GOOD
			entry.button.BackgroundColor3 = ShopStyle.OWNED
		elseif info.owned then
			entry.sub.Text = "Tap to move in"
			entry.sub.TextColor3 = Theme.MUTED_LIGHT
			entry.button.BackgroundColor3 = ShopStyle.DEAR
		elseif info.earned then
			-- Earned, not bought: the card is a count toward owning every
			-- priced house, never a price. Tapping it asks the server, which
			-- says the same thing out loud.
			entry.sub.Text = ("EARNED %d/%d"):format(info.earnedHave or 0, info.earnedNeed or 0)
			entry.sub.TextColor3 = ShopStyle.LIGHT
			entry.button.BackgroundColor3 = ShopStyle.LOCKED
		elseif info.forSale then
			entry.sub.Text = format(info.cost)
			entry.sub.TextColor3 = GOLD
			entry.button.BackgroundColor3 = if latestCoins >= info.cost
				then ShopStyle.BUY
				else ShopStyle.CARD
		else
			entry.sub.Text = "Locked"
			entry.sub.TextColor3 = ShopStyle.LIGHT
			entry.button.BackgroundColor3 = ShopStyle.DEAR
		end
		require(ReplicatedStorage.Shared.ShopHouseCards).paint(entry, info, latestCoins)
	end

	-- CATCH EFFECTS, and the word on the card is why they have never shared
	-- a loop with anything else.
	--
	-- "EQUIPPED" is what a skin and an aura said, because the player was
	-- looking at the thing that would be wearing it. A catch effect is worn
	-- by NOBODY -- it fires on whoever you nab -- so the same word would
	-- leave a nine-year-old asking equipped to what, which is the exact
	-- reason the dog's coat says ON YOUR DOG and its kennel says IT LIVES
	-- HERE. What is worn, what is stood in and what is fired at somebody
	-- else are three different relationships, and one sentence for all
	-- three would be describing the wrong object two thirds of the time.
	for key, info in pairs(latestCosmetics.catches or {}) do
		local entry = ensureCosmeticButton("catch", key, info)
		entry.title.Text = info.name

		if info.equipped then
			entry.sub.Text = "YOUR CATCH"
			entry.sub.TextColor3 = Theme.GOOD
			entry.button.BackgroundColor3 = ShopStyle.OWNED
		elseif info.unlocked then
			entry.sub.Text = "Tap to use"
			entry.sub.TextColor3 = Theme.MUTED_LIGHT
			entry.button.BackgroundColor3 = ShopStyle.CARD
		elseif info.passName then
			-- Same branch and the same reason as the skins and effects above:
			-- a pass item has no coin price, and the fallback formats one.
			entry.sub.Text = info.passName:upper()
			entry.sub.TextColor3 = Theme.GOLD_INK
			entry.button.BackgroundColor3 = ShopStyle.LOCKED
		elseif info.loot then
			-- Nothing here is a set item today. Written anyway for the reason
			-- the loop above carries the same branch: a set entry landing in
			-- this catalogue would have no `cost`, and a missing cost arrives
			-- as 0 and renders "0" in gold on the you-can-afford green -- the
			-- drop-pool skins' own bug, which is silent every time.
			entry.sub.Text = "FROM A SET CRATE"
			entry.sub.TextColor3 = Theme.MUTED_LIGHT
			entry.button.BackgroundColor3 = ShopStyle.LOCKED
		else
			-- A BUY BUTTON, AND IT IS THE POINT RATHER THAN A PLACEHOLDER.
			-- Coins are not purchasable with Robux at any price, so this is
			-- what keeps a catch effect an ordinary in-game reward for in-game
			-- money however many of them a pass adds later.
			entry.sub.Text = format(info.cost)
			entry.sub.TextColor3 = GOLD
			entry.button.BackgroundColor3 = if latestCoins >= info.cost
				then ShopStyle.BUY
				else ShopStyle.CARD
		end
	end

	-- The Robux offers. Guarded, because the tab is built later in the chunk
	-- and a nil there would take this whole render down -- and this function
	-- runs on every coin tick.
	if SHOP.premium then
		SHOP.premium:render(latestCosmetics.passes)
	end
end

-- ============================================================
-- BONES
-- ============================================================
--
-- Bones are the one thing here that is CONSUMED, so the usual owned/equipped
-- states do not apply: a tile is buyable forever and shows a running count
-- instead. Which is why they get their own builder rather than a sixth branch
-- inside ensureCosmeticButton.

local latestBones: { [string]: any }? = nil

-- The bar only exists while you are holding something. An empty row of greyed
-- slots is permanent clutter on a phone screen. Two renderers feed it now, so
-- each records whether IT has anything and the bar takes the union -- a single
-- `Visible = anyHeld` in either one would hide the other's slots.
local boneHeld = false

-- One table per feature instead of four locals each.
--
-- Luau caps a function at 200 local registers and the main chunk of this file
-- reached it: gadgets, home items, the thief kit and rides were each keeping a
-- `latest`, a `tiles`, a `slots` and a `held` at top level. Grouping costs one
-- register apiece and reads better besides -- `gadgetUI.tiles` says what it
-- belongs to, where `gadgetUI.tiles` only spells it. Any new HUD feature should
-- follow this shape; the budget is not large.
local gadgetUI = { latest = nil :: any, tiles = {}, slots = {}, held = false }
local homeUI = { latest = nil :: any, tiles = {}, slots = {}, held = false }
local stealthUI = { latest = nil :: any, tiles = {}, slots = {}, held = false }
-- `renderGarage` and `toggleGarage` are filled in by buildGarage() further
-- down, and live here rather than as two more top-level locals: the chunk is
-- against the 200-register ceiling and every HUD feature added since has to
-- group its state this way.
local rideUI = { latest = nil :: any, tiles = {}, renderGarage = nil :: any, toggleGarage = nil :: any }

-- THE STYLE PACK, advertised under the rides rather than beside them.
--
-- One offer for every ride, which is why it is a banner and not a tile per
-- pose: the pack is not a thing you pick, it is the thing that makes the
-- picking possible, and five identical locked tiles would say the opposite.
--
-- Below GET AROUND on purpose. A player with no ride cannot use a pose, so
-- the ride is the thing to sell first and this reads as what you do next.
--
-- Wrapped in a function because ClientMain is ONE chunk against Luau's
-- 200-local ceiling; a function body gets its own register file. See the note
-- by the daily rewards board.
--
-- AND DEFINED DOWN HERE, beside `rideUI`, not up beside the rest of the Rides
-- tab it draws into. It writes its render hook into that table, and a function
-- DEFINED above the local it reads captures a nil global instead of the
-- upvalue -- moving only the call does not help, because the binding is
-- decided where the function is written. Measured as
-- "attempt to index nil with 'renderStyleOffer'", which names the field and
-- not the cause. Fourth time this file has paid for that lesson.
local function buildStyleOffer()
	gearHeader("STYLES", 4)

	local card = Instance.new("TextButton")
	card.Name = "StyleOffer"
	card.Size = UDim2.new(1, -10, 0, 84)
	card.LayoutOrder = 5
	card.BackgroundColor3 = ShopStyle.CARD
	card.BorderSizePixel = 0
	card.AutoButtonColor = true
	card.Font = Enum.Font.FredokaOne
	card.Text = ""
	card.Visible = false
	card.Parent = gearScroll
	corner(card, 10)

	local edge = Instance.new("UIStroke")
	edge.Color = GOLD
	edge.Thickness = 2
	edge.Parent = card

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 22)
	title.Position = UDim2.new(0, 12, 0, 9)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = ShopStyle.TEXT
	title.Text = "Style Pack"
	title.Parent = card

	local blurb = Instance.new("TextLabel")
	blurb.Size = UDim2.new(1, -20, 0, 30)
	blurb.Position = UDim2.new(0, 12, 0, 31)
	blurb.BackgroundTransparency = 1
	blurb.Font = Enum.Font.Gotham
	blurb.TextSize = 12
	blurb.TextWrapped = true
	blurb.TextXAlignment = Enum.TextXAlignment.Left
	blurb.TextYAlignment = Enum.TextYAlignment.Top
	-- Full ink, not muted: this card's ground is the light OWNED mint when the
	-- pass is held, and even a dark muted measured 2.76:1 on it. It is also
	-- the only sales copy in the shop, so it is the last thing to whisper.
	blurb.TextColor3 = ShopStyle.TEXT
	blurb.Text = ""
	blurb.Parent = card

	local price = Instance.new("TextLabel")
	price.Size = UDim2.new(1, -20, 0, 18)
	price.Position = UDim2.new(0, 12, 1, -24)
	price.BackgroundTransparency = 1
	price.Font = Enum.Font.GothamBold
	price.TextSize = 13
	price.TextXAlignment = Enum.TextXAlignment.Left
	price.TextColor3 = GOLD
	price.Text = ""
	-- The call-to-action makes this the longest line on the card, and on a
	-- phone-width scroll it is the one that could reach the edge. Clipped at the
	-- end rather than allowed to draw outside the card: `Theme.card` sets no
	-- `ClipsDescendants`, so an overflow here would print across the tile below
	-- -- the fault the Most Wanted poster already shipped once. NOT MEASURED in
	-- pixels: `TextBounds.X` against `AbsoluteSize.X` is the check and it needs
	-- a running client, so this is the safe failure rather than a verified fit.
	price.TextTruncate = Enum.TextTruncate.AtEnd
	price.Parent = card

	card.Activated:Connect(function()
		local pass = rideUI.latest and rideUI.latest.pass
		if not pass or pass.owned then
			return
		end
		-- THE ADVERT LINKS TO THE SHELF RATHER THAN STRAIGHT TO THE TILL.
		--
		-- This used to fire `PromptGamePassPurchase` from here, which was the
		-- only route to the pass on the day it was written: there was no Robux
		-- tab yet. There is now, it is where every named Robux thing in the game
		-- is sold, and it carries the Style Pack's own carousel -- so an advert
		-- that threw a purchase dialogue straight over the Rides tab was selling
		-- one item out of a shelf the player had never been shown.
		--
		-- It also leaves exactly ONE place in the game that charges for a pass.
		-- Two buy buttons for one product is two things to keep in step, and
		-- this pair was already drifting: this card prompted for a pass whose
		-- price, blurb and artwork the other shelf renders from its own code.
		--
		-- IT NAVIGATES EVEN WHEN THERE IS NO PASS ID, which reverses the note
		-- that used to sit here. "Nothing to open" was true of a purchase
		-- dialogue and is false of a tab: an unreleased pass still has a shelf,
		-- it still reads COMING SOON over there, and a card that does nothing
		-- when pressed is the one outcome this file refuses everywhere else.
		selectTab(SHOP.at.premium)
	end)

	-- Hung off rideUI rather than kept as top-level locals, the shape every
	-- HUD feature added since the register ceiling was hit has to follow.
	rideUI.renderStyleOffer = function()
		local pass = rideUI.latest and rideUI.latest.pass
		card.Visible = pass ~= nil
		if not pass then
			return
		end
		title.Text = pass.name or "Style Pack"
		blurb.Text = pass.blurb or ""
		if pass.owned then
			price.Text = "OWNED  \226\128\162  tap the style button by your garage"
			-- INK, NOT MINT. This card's background moved to a LIGHT owned
			-- tint with the rest of the shop, and a pale green on a pale
			-- green measured 1.15:1 -- the worst contrast anywhere in the
			-- shop and effectively invisible. The state is already carried by
			-- the card colour and the border; the words only have to be
			-- readable. Same for the Robux price, where gold on cream was the
			-- next worst.
			price.TextColor3 = ShopStyle.TEXT
			edge.Color = Theme.GOOD
			card.BackgroundColor3 = ShopStyle.OWNED
		elseif pass.id then
			-- THE PRICE AND WHERE TO PAY IT. An advert that reads as a price tag
			-- invites a tap that opens a tab, and a control whose label does not
			-- describe what pressing it does is the same fault as a card that
			-- does nothing. `utf8.char` rather than a byte escape for the middot,
			-- because this project has twice had a backslash sequence rewritten
			-- in transit into the bytes it named -- which ends the string literal
			-- and takes the whole HUD down at compile time.
			price.Text = ("%d Robux  %s  OPEN ROBUX SHOP"):format(pass.robux or 0, utf8.char(0x00B7))
			price.TextColor3 = ShopStyle.TEXT
			edge.Color = Theme.GOLD_DEEP
			card.BackgroundColor3 = ShopStyle.DEAR
		else
			price.Text = "COMING SOON  " .. utf8.char(0x00B7) .. "  OPEN ROBUX SHOP"
			price.TextColor3 = ShopStyle.MUTED
			edge.Color = Theme.MUTED
			card.BackgroundColor3 = ShopStyle.DEAR
		end
	end
end


buildStyleOffer()

-- ============================================================
-- THE FRONT PAGE
-- ============================================================
--
-- Eight tabs became four, which fixed the rail and made the scrolls longer:
-- Your Home is 3.55 screens on a phone held sideways. So the shop opens on a
-- MAP of itself -- every category at once, three real items showing in each,
-- and a tap that lands you ON the section rather than at the top of the tab
-- it lives in.
--
-- EVERY SHELF, ONE SCREEN, NO SCROLLING. That is the whole design. A front
-- page you have to scroll to read is one more thing to navigate rather than
-- the answer to navigating, so the cards are sized to fit the panel twice
-- over and the previews are small on purpose.
--
-- IT IS SIX CARDS NOW RATHER THAN EIGHT, and the grid is CENTRED down the
-- page rather than resized to fit them. The cell is a third of the width AND
-- a third of the height, so six cards fill two rows of three and leave the
-- last row empty -- and a page with a blank bottom third reads as a row that
-- failed to load. Taller cells were the other option and are worse: the three
-- preview wells inside a card are sized `1, -74`, so a half-height cell
-- stretches them into narrow slots and the picture that is most of the point
-- of this page gets worse to close a gap.
--
-- THE THREE PREVIEWS ARE CHOSEN BY STATE, NEVER "the first three". Affordable
-- and unowned first, then unowned, then owned -- so a shelf always leads with
-- something the player could actually walk away with, and visibly changes as
-- they get richer. Showing items 1-3 of a catalogue somebody finished a week
-- ago is dead space in the most valuable spot in the shop.
--
-- NOTHING HERE RE-IMPLEMENTS A CARD. The shelves show ICONS and a COUNT, and
-- the count is the only stateful thing on them. Building a second, smaller
-- version of the real card -- with its own owned/equipped/price branches --
-- is the copy that drifts from the original the first time either is touched,
-- which this repo has written down about Decor.buildOne and the mini piggy.
-- The model builders are shared; the state logic is not duplicated because
-- there is only one line of it.
--
-- Wrapped in a function for the register budget, and DEFINED HERE rather than
-- up beside the views it draws into: it reads latestCosmetics, latestBones,
-- gadgetUI, stealthUI and rideUI, and a function written above any of those
-- captures a nil global instead of the upvalue. Fifth time in this file.
local function buildFrontPage()
	-- A PLAIN FRAME, NOT A SCROLLING ONE, because "no scrolling" is the design
	-- rather than something that happens to be true at one window size. A
	-- ScrollingFrame here was a standing invitation for the front page to
	-- quietly become scrollable on a short window, which is the one property
	-- it is not allowed to have.
	local scroll = Instance.new("Frame")
	scroll.Name = "Shelves"
	scroll.Size = UDim2.new(1, 0, 1, 0)
	scroll.BackgroundTransparency = 1
	scroll.Parent = startView

	-- THE SAME OUTSIDE-STROKE CLEARANCE THE OTHER TABS GET, and this one was
	-- missed because the front page is a plain Frame rather than one of the
	-- scrolls `makeScroll` builds -- so it never picked up that padding.
	--
	-- It shows differently here, which is why it survived the first fix.
	-- Nothing CLIPS the front page: measured, no ancestor has
	-- ClipsDescendants and the card's 4px border reached 6px inside the panel
	-- quite happily. The fault is that the panel's OWN border is the same ink,
	-- 4px thick, in the same place -- so the left column's outline landed on
	-- it and merged, and a card with no visible left edge reads as clipped
	-- whether or not anything cut it. Two identical lines touching is
	-- indistinguishable from one.
	--
	-- The grid arithmetic survives untouched: the cells are in SCALE, so
	-- 3 * (W/3 - 8) + 2 * 12 = W still holds against whatever width is left
	-- after padding, and every shelf still lands on one screen.
	local inset = Instance.new("UIPadding")
	inset.PaddingLeft = UDim.new(0, 6)
	inset.PaddingRight = UDim.new(0, 6)
	inset.PaddingTop = UDim.new(0, 4)
	inset.PaddingBottom = UDim.new(0, 4)
	inset.Parent = scroll

	local grid = Instance.new("UIGridLayout")
	-- THE CELL IS IN SCALE, NOT PIXELS, and that is what makes the promise
	-- keep itself. Three cells of (1/3 - 8) with 12 of padding come to exactly
	-- the parent's width -- 3 * (W/3 - 8) + 2 * 12 = W -- at EVERY panel size,
	-- so every shelf lands on one screen on a desktop and on a phone held
	-- sideways with no resize handler and nothing to keep in step.
	--
	-- The old cell was a measured 224x158 against a content area that has
	-- since changed twice. At the current 1020x489 this gives a 332x155 card:
	-- half again as wide as the one it replaces, which is what "large card"
	-- actually costs.
	grid.CellSize = UDim2.new(1 / 3, -8, 1 / 3, -8)
	grid.CellPadding = UDim2.new(0, 12, 0, 12)
	-- CENTRED, because there are six cards in a nine-cell grid. Top-aligned,
	-- the empty third sits at the BOTTOM of the page, which is exactly where
	-- a row that failed to render would be. Split between the two edges it
	-- reads as margin.
	grid.VerticalAlignment = Enum.VerticalAlignment.Center
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = scroll

	-- Lands you ON the section, not at the top of the tab that contains it.
	-- Without this the driveway ornaments are still 3.2 screens down and the
	-- front page has only saved you the guess about which tab they are in.
	local function openSection(name: string)
		local at = sections[name]
		if not at then
			return
		end
		selectTab(at.tab)

		-- CONVERGES ON THE TARGET RATHER THAN JUMPING ONCE AND HOPING.
		--
		-- The view was invisible until the line above, and a hidden frame's
		-- descendants carry stale AbsolutePositions -- so a single deferred
		-- read is measurably wrong the FIRST time a tab is opened and right
		-- every time after, which is the worst shape a bug can have: it works
		-- whenever you go looking for it. Measured, the first jump to the
		-- accessories computed an offset of 0 and landed at the top of the
		-- skins, and the identical second click landed at 614.
		--
		-- So each frame it re-reads where the target actually is and moves
		-- there, and stops as soon as it is already there -- usually one or
		-- two frames. A stale read simply corrects itself on the next one.
		task.spawn(function()
			for _ = 1, 8 do
				RunService.RenderStepped:Wait()
				local want = math.max(0, at.at.AbsolutePosition.Y
					- at.scroll.AbsolutePosition.Y
					+ at.scroll.CanvasPosition.Y - 6)
				if math.abs(at.scroll.CanvasPosition.Y - want) < 1 then
					return
				end
				at.scroll.CanvasPosition = Vector2.new(0, want)
			end
		end)
	end

	-- One shelf per section. `items` returns whatever that catalogue has right
	-- now, in the shape the picker below wants: a key, a sort order, whether
	-- it is owned, what it costs (nil for anything that is not bought), and
	-- how to build its icon.
	local shelves = {
		{
			title = "HOUSES", section = "houses",
			items = function()
				local out = {}
				for index, info in ipairs(latestCosmetics and latestCosmetics.houses or {}) do
					table.insert(out, {
						key = info.id, order = index,
						owned = info.owned,
						-- Every unowned house is for sale (schema 26); an
						-- owned one has no price to advertise.
						cost = if info.forSale then info.cost else nil,
						build = function()
							return House.build(index - 1, CFrame.new(), nil)
						end,
					})
				end
				return out
			end,
		},
		{
			title = "DECORATIONS", section = "decor",
			items = function()
				local out = {}
				for key, info in pairs(latestCosmetics and latestCosmetics.decor or {}) do
					table.insert(out, {
						key = key, order = info.order or 0,
						owned = info.owned, cost = info.cost,
						build = function()
							return Decor.buildOne(key, CFrame.new(), nil)
						end,
					})
				end
				return out
			end,
		},
		{
			title = "RIDES", section = "rides",
			items = function()
				local out = {}
				for key, info in pairs(rideUI.latest and rideUI.latest.rides or {}) do
					table.insert(out, {
						key = key, order = info.order or 0,
						owned = info.owned, cost = info.cost,
						build = function()
							return RideModel.build(key)
						end,
						-- The render, where one exists; `build` is the fallback.
						mount = function(holder: Frame)
							return require(ReplicatedStorage.Shared.ShopRideCards).mount(holder, key) ~= nil
						end,
					})
				end
				return out
			end,
		},
		{
			-- Bones, gadgets and the thief kit on one shelf, because they are
			-- the one thing here you rebuy rather than collect: none of them
			-- carries a rarity border and none of them is ever "owned". The
			-- shelf says how many are in stock rather than how many are left
			-- to get, which is the honest count for a consumable.
			title = "THROW & SNEAK", section = "kit",
			items = function()
				local out = {}
				for key, info in pairs(latestBones or {}) do
					table.insert(out, {
						key = key, order = info.order or 0, owned = false, cost = info.cost,
						build = function()
							return BoneModel.build(key, false)
						end,
					})
				end
				for key, info in pairs(gadgetUI.latest or {}) do
					table.insert(out, {
						key = key, order = 100 + (info.order or 0), owned = false, cost = info.cost,
						build = function()
							return GadgetModel.build(key, false)
						end,
					})
				end
				for key, info in pairs(stealthUI.latest and stealthUI.latest.items or {}) do
					table.insert(out, {
						key = key, order = 200 + (info.order or 0), owned = false, cost = info.cost,
						build = function()
							return ThiefModel.build(key)
						end,
					})
				end
				return out
			end,
		},
	}

	-- Only rebuilds when the CHOSEN ITEM changes, which is what keeps a
	-- once-a-second re-render from constructing twenty-one ViewportFrames.
	local function setIcon(holder: Frame, item: any?)
		local want = if item then item.key else nil
		if holder:GetAttribute("ItemKey") == want then
			return
		end
		holder:SetAttribute("ItemKey", want)
		for _, child in ipairs(holder:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		holder.Visible = item ~= nil
		if not item then
			return
		end
		if item.mount and item.mount(holder) then
			return
		end
		if item.build then
			makeModelIcon(holder, item.build(), UDim2.new(1, 0, 1, 0), UDim2.new(), true)
		end
	end

	-- THE SHELF CARD, IN THE CATEGORY'S OWN COLOUR.
	--
	-- The colour is doing navigation rather than decoration: the tab it opens
	-- wears the same hue, so the trip from "the pink one" to the skins is one
	-- recognisable colour instead of two words a nine-year-old has to read
	-- twice. Same argument as the guard-duty collar and the overflowing bin --
	-- prefer information to a fight.
	--
	-- THE PREVIEWS SIT IN A SUNK, DESATURATED WELL of that same hue rather
	-- than directly on it. On the raw colour a pink piggy on a pink card
	-- disappears, which is the exact failure the item card's swatch already
	-- had to solve by lerping its own colour toward the panel.
	for index, shelf in ipairs(shelves) do
		local hue = ShopStyle.HUE[shelf.section] or ShopStyle.CARD
		local card = Instance.new("TextButton")
		card.Name = "Shelf_" .. shelf.section
		card.LayoutOrder = index
		card.BackgroundColor3 = hue
		card.BorderSizePixel = 0
		card.AutoButtonColor = true
		card.Text = ""
		card.Parent = scroll
		corner(card, 18)
		ShopStyle.outline(card, 4)
		ShopStyle.gloss(card)

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, -28, 0, 22)
		title.Position = UDim2.new(0, 14, 0, 9)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.FredokaOne
		title.TextSize = 17
		title.TextTruncate = Enum.TextTruncate.AtEnd
		title.TextXAlignment = Enum.TextXAlignment.Left
		-- INK on the hue, never white. All seven of these are LIGHT colours,
		-- and white FredokaOne on the amber one is the least readable pairing
		-- in the whole shop.
		title.TextColor3 = ShopStyle.INK
		title.Text = shelf.title
		title.Parent = card

		-- THREE WELLS, SIZED IN SCALE so they follow the card that the cell
		-- size already follows. Pixel positions here would need re-deriving
		-- every time the panel cap or the tab band moved, and this file has
		-- already been caught once by a constant that stopped being derived.
		local icons = {}
		for slot = 1, 3 do
			local holder = Instance.new("Frame")
			holder.Name = "Icon" .. slot
			holder.Size = UDim2.new(0.29, 0, 1, -74)
			holder.Position = UDim2.new(0.043 + (slot - 1) * 0.313, 0, 0, 38)
			holder.BackgroundColor3 = ShopStyle.deepen(hue)
			holder.BorderSizePixel = 0
			holder.Visible = false
			holder.Parent = card
			corner(holder, 12)
			ShopStyle.outline(holder, 3)
			icons[slot] = holder
		end

		-- The state line is a PILL now. It is the only part of this card that
		-- changes as the player gets richer, so it is the part that has to
		-- catch the eye when it does.
		local state = ShopStyle.chip(card, ShopStyle.INK, ShopStyle.LIGHT)
		state.Name = "State"
		state.Size = UDim2.new(0, 152, 0, 26)
		state.Position = UDim2.new(0, 14, 1, -34)
		state.Text = ""

		local chevron = Instance.new("TextLabel")
		chevron.Name = "Chevron"
		chevron.Size = UDim2.new(0, 26, 0, 26)
		chevron.Position = UDim2.new(1, -38, 1, -34)
		chevron.BackgroundTransparency = 1
		chevron.Font = Enum.Font.FredokaOne
		chevron.TextSize = 24
		chevron.TextColor3 = ShopStyle.INK
		-- utf8.char, not an escape. This file has twice had a backslash
		-- sequence rewritten in transit into the bytes it named, which ends
		-- the string literal and takes down the whole HUD at compile time.
		chevron.Text = utf8.char(0x203A)
		chevron.Parent = card

		card.Activated:Connect(function()
			openSection(shelf.section)
		end)

		shelf.ui = { icons = icons, state = state }
	end

	-- THE FIFTH CARD, AND THE FIRST OF THE TWO THAT ARE NOT SHELVES.
	--
	-- "Everything" did not contain everything: it mapped the cosmetic
	-- catalogues and silently omitted Defend / Rob, which is the one tab in
	-- this shop that changes an OUTCOME rather than how something looks. A
	-- front page that is a map of the shop cannot leave out the half of it
	-- that matters most, and there were empty cells in the grid where it
	-- belonged.
	--
	-- It is built here rather than as an entry in `shelves` because it has no
	-- catalogue behind it: no items to count, none to preview and no
	-- affordability to report. Forcing it through the shelf loop would have
	-- meant a branch at every one of those four points to render a card that
	-- shares none of their state. A BIG GLYPH stands where the three preview
	-- wells go -- the upgrade trees have no models to show, and three empty
	-- wells beside four full ones would read as a card that failed to load.
	local trees = Instance.new("TextButton")
	trees.Name = "Shelf_upgrades"
	trees.LayoutOrder = 8
	trees.BackgroundColor3 = ShopStyle.HUE.upgrades
	trees.BorderSizePixel = 0
	trees.AutoButtonColor = true
	trees.Text = ""
	trees.Parent = scroll
	corner(trees, 18)
	ShopStyle.outline(trees, 4)
	ShopStyle.gloss(trees)

	local treesTitle = Instance.new("TextLabel")
	treesTitle.Name = "Title"
	treesTitle.Size = UDim2.new(1, -28, 0, 22)
	treesTitle.Position = UDim2.new(0, 14, 0, 9)
	treesTitle.BackgroundTransparency = 1
	treesTitle.Font = Enum.Font.FredokaOne
	treesTitle.TextSize = 17
	treesTitle.TextXAlignment = Enum.TextXAlignment.Left
	treesTitle.TextColor3 = ShopStyle.INK
	treesTitle.Text = "DEFEND / ROB"
	treesTitle.Parent = trees

	local treesGlyph = Instance.new("TextLabel")
	treesGlyph.Name = "Glyph"
	treesGlyph.Size = UDim2.new(1, 0, 1, -74)
	treesGlyph.Position = UDim2.new(0, 0, 0, 34)
	treesGlyph.BackgroundTransparency = 1
	treesGlyph.Font = Enum.Font.FredokaOne
	treesGlyph.TextScaled = true
	treesGlyph.Text = utf8.char(0x2694)
	treesGlyph.Parent = trees

	local treesState = ShopStyle.chip(trees, ShopStyle.INK, ShopStyle.LIGHT)
	treesState.Name = "State"
	treesState.Size = UDim2.new(0, 176, 0, 26)
	treesState.Position = UDim2.new(0, 14, 1, -34)
	treesState.Text = "The only tab with stats"

	local treesChevron = Instance.new("TextLabel")
	treesChevron.Name = "Chevron"
	treesChevron.Size = UDim2.new(0, 26, 0, 26)
	treesChevron.Position = UDim2.new(1, -38, 1, -34)
	treesChevron.BackgroundTransparency = 1
	treesChevron.Font = Enum.Font.FredokaOne
	treesChevron.TextSize = 24
	treesChevron.TextColor3 = ShopStyle.INK
	treesChevron.Text = utf8.char(0x203A)
	treesChevron.Parent = trees

	-- Straight to the tab. There is no section to land ON -- the upgrade view
	-- is not a scroll of headed sections like the other four -- so this is the
	-- one card that opens a tab rather than a place inside one.
	trees.Activated:Connect(function()
		selectTab(2)
	end)

	-- THE NINTH CARD, AND THE GRID HAD BEEN HOLDING A CELL FOR IT.
	--
	-- The cell is `1/3` by `1/3`, which is nine exactly, and eight were used.
	-- So this costs no height, no scroll and no arithmetic -- the front page's
	-- one promise, that it is a whole screen with nothing below the fold,
	-- keeps itself here as it does everywhere else on this page.
	--
	-- It has to be on the map for the same reason Defend / Rob did. That entry
	-- is written directly above: a front page that is a map of the shop cannot
	-- leave out a tab, and the fault is invisible -- the tab exists, it works,
	-- and a nine-year-old simply never learns it is there. Crates are worse in
	-- that respect than the trees were, because a crate is the only thing in
	-- this shop nothing else in the game mentions.
	--
	-- Same shape as the trees card and for the same reason: no catalogue
	-- behind it, so nothing to count, preview or price. A crate's own card in
	-- the tab does all of that, and doing a smaller version of it here is the
	-- copy that drifts.
	local crates = Instance.new("TextButton")
	crates.Name = "Shelf_crates"
	crates.LayoutOrder = 9
	crates.BackgroundColor3 = ShopStyle.HUE.crates
	crates.BorderSizePixel = 0
	crates.AutoButtonColor = true
	crates.Text = ""
	crates.Parent = scroll
	corner(crates, 18)
	ShopStyle.outline(crates, 4)
	ShopStyle.gloss(crates)

	local cratesTitle = Instance.new("TextLabel")
	cratesTitle.Name = "Title"
	cratesTitle.Size = UDim2.new(1, -28, 0, 22)
	cratesTitle.Position = UDim2.new(0, 14, 0, 9)
	cratesTitle.BackgroundTransparency = 1
	cratesTitle.Font = Enum.Font.FredokaOne
	cratesTitle.TextSize = 17
	cratesTitle.TextXAlignment = Enum.TextXAlignment.Left
	cratesTitle.TextColor3 = ShopStyle.INK
	cratesTitle.Text = "CRATES"
	cratesTitle.Parent = crates

	local cratesGlyph = Instance.new("TextLabel")
	cratesGlyph.Name = "Glyph"
	cratesGlyph.Size = UDim2.new(1, 0, 1, -74)
	cratesGlyph.Position = UDim2.new(0, 0, 0, 34)
	cratesGlyph.BackgroundTransparency = 1
	cratesGlyph.Font = Enum.Font.FredokaOne
	cratesGlyph.TextScaled = true
	cratesGlyph.Text = utf8.char(0x1F4E6)
	cratesGlyph.Parent = crates

	-- THE ONE FACT THAT HAS TO ARRIVE BEFORE THE BUTTON DOES. Every other
	-- shelf sells a thing you can see; this one sells a chance, and the reason
	-- that is fair for a nine-year-old is that a repeat is not a loss. Static,
	-- exactly as the trees card's line is -- a count here would be a second,
	-- smaller version of the progress chip the real card already carries.
	local cratesState = ShopStyle.chip(crates, ShopStyle.INK, ShopStyle.LIGHT)
	cratesState.Name = "State"
	cratesState.Size = UDim2.new(0, 176, 0, 26)
	cratesState.Position = UDim2.new(0, 14, 1, -34)
	cratesState.Text = "A repeat pays a spare"

	local cratesChevron = Instance.new("TextLabel")
	cratesChevron.Name = "Chevron"
	cratesChevron.Size = UDim2.new(0, 26, 0, 26)
	cratesChevron.Position = UDim2.new(1, -38, 1, -34)
	cratesChevron.BackgroundTransparency = 1
	cratesChevron.Font = Enum.Font.FredokaOne
	cratesChevron.TextSize = 24
	cratesChevron.TextColor3 = ShopStyle.INK
	cratesChevron.Text = utf8.char(0x203A)
	cratesChevron.Parent = crates

	-- Through `SHOP.at`, never a literal. The trees card can hardcode 2
	-- because Upgrades has been the second tab since there were four; this one
	-- is the newest tab in the rail and the first thing a ninth would move.
	crates.Activated:Connect(function()
		selectTab(SHOP.at.crates)
	end)

	frontUI.render = function()
		for _, shelf in ipairs(shelves) do
			local items = shelf.items()
			table.sort(items, function(a, b)
				return (a.order or 0) < (b.order or 0)
			end)

			-- Affordable and unowned, then unowned, then owned. Three passes
			-- rather than a sort, because within a rank the catalogue's own
			-- order has to survive -- sorting by rank alone would shuffle
			-- twenty-one skins into a different arrangement every coin tick.
			local pick, buyable, unowned = {}, 0, 0
			for _, item in ipairs(items) do
				if not item.owned then
					unowned += 1
					if item.cost and latestCoins >= item.cost then
						buyable += 1
					end
				end
			end
			for rank = 1, 3 do
				for _, item in ipairs(items) do
					if #pick >= 3 then
						break
					end
					local mine = if item.owned then 3
						elseif item.cost and latestCoins >= item.cost then 1
						else 2
					if mine == rank then
						table.insert(pick, item)
					end
				end
			end

			for slot = 1, 3 do
				setIcon(shelf.ui.icons[slot], pick[slot])
			end

			if #items == 0 then
				shelf.ui.state.Text = ""
			elseif buyable > 0 then
				shelf.ui.state.Text = ("%d you can buy now"):format(buyable)
				shelf.ui.state.TextColor3 = Theme.GOOD
			elseif unowned > 0 then
				shelf.ui.state.Text = ("%d still to get"):format(unowned)
				shelf.ui.state.TextColor3 = Theme.MUTED_LIGHT
			else
				shelf.ui.state.Text = "ALL YOURS"
				shelf.ui.state.TextColor3 = Theme.GOOD
			end
		end
	end
end

-- ShopRevamp builds the category landing page after the bag is initialized.

local boneTiles: { [string]: any } = {}
local boneSlots: { [string]: { button: TextButton, label: TextLabel, hotkey: TextLabel } } = {}

-- The quick-throw bar. Everything about how it lays itself out, how a player
-- rearranges it and which key belongs to which item now lives in the module;
-- what stays here is WHAT goes on it and WHETHER it is up.
--
-- It carries BOTH bones and gadgets. They are the same gesture -- hold a
-- stock, pick one, throw it at something -- and two separate bars for one verb
-- would cost twice the screen on a phone to teach a distinction the game does
-- not actually make.
--
-- Rides are deliberately NOT here. Mounting is automatic and, by design, a
-- ride cannot be used during a chase, so a slot for one would be inert at
-- exactly the moment this bar matters. Choosing a board is a taste decision
-- made once, and taste decisions live in the shop -- and, now, in the garage
-- slot in the bottom-left corner.
HotBar.init(gui)

-- BOTTOM LEFT, BESIDE THE GARAGE, because a dodge is a movement control and
-- the column it used to head was a menu: SHOP over Earn Faster over Bigger
-- Piggy Bank, with the one mid-chase action in the game sitting on top of
-- them. It belongs with the vehicle slot, which is the other thing in this HUD
-- that changes how you are moving.
--
-- BESIDE it rather than above it, and that is a reach decision rather than a
-- tidiness one. The left column is measured against a 546-tall viewport -- a
-- phone held sideways, the shortest thing that has to work -- and it is
-- already four deep: item bar 20 to 74, boost pill 86 to 130, garage slot 140
-- to 208, stance pill 216 to 250. A fifth row would put this slot's top edge
-- at 284, which is 52% of the way up the screen and outside a thumb that is
-- also holding the phone. Sharing the garage's row costs the column nothing
-- and keeps the dodge where a thumb already is.
--
-- The dodge takes x=22 and the garage moves right to x=98, because the garage
-- HIDES ITSELF ENTIRELY until a ride is owned: leaving it on the left would
-- have left this slot floating in the middle of an empty row for every player
-- who has not bought a board yet.
local dodgeButton = makeActionButton("DodgeButton", "DODGE", "DODGE", "Q",
	Theme.COOL, UDim2.new(0, 68, 0, 68), 18, gui, true)
dodgeButton.AnchorPoint = Vector2.new(0, 1)
dodgeButton.Position = UDim2.new(0, 22, 1, -140)
require(ReplicatedStorage.Shared.HUDLayout).bindAction(dodgeButton, gui, 1)

-- The cooldown, drawn as the button draining rather than as a number.
--
-- A five-second wait shown as "3.2" is a thing to read; shown as a bar that is
-- two-thirds empty it is a thing to glance at, which is all anybody can spare
-- mid-chase.
local dodgeFill = Instance.new("Frame")
dodgeFill.Name = "Cooldown"
dodgeFill.Size = UDim2.new(0, 0, 1, 0)
dodgeFill.BackgroundColor3 = Theme.INK
dodgeFill.BackgroundTransparency = 0.35
dodgeFill.BorderSizePixel = 0
-- Behind the icon and the label, which are ZIndex 3.
dodgeFill.ZIndex = 2
dodgeFill.Parent = dodgeButton
corner(dodgeFill, 18)

local dodgeReadyAt = 0

local function requestDodge()
	Remotes.get("DodgeRequest"):FireServer()
end

-- Gated so a thumb sliding off the stick and lifting over the button is not
-- a dodge. See Shared/TouchOrigin.
do
	local pressed = require(ReplicatedStorage.Shared.TouchOrigin).guard(dodgeButton)
	dodgeButton.Activated:Connect(function()
		if pressed() then
			requestDodge()
		end
	end)
end

-- ---------- the tiptoe slot ----------
--
-- Third on the dodge and garage row, and it is the ONLY control on this HUD
-- most of the audience will ever use to sneak: most of them are on a tablet
-- and will never press C, so a keyboard-only tiptoe would mean a watching
-- guard dog is unbeatable on a touchscreen -- "defence buys time, never
-- immunity" broken by an input gap rather than by a number.
--
-- IT GOES AWAY WHILE RIDING, AND THE SERVER REFUSES A SNEAK UNDER A RIDE.
-- The two are multipliers on one speed, so they compose into a scrambler
-- creeping at 11.8 studs a second -- see `tiptoeInEffect` -- and a control
-- that does nothing when pressed reads as broken rather than as unavailable.
-- The hide is written in the `RideState` handler, which is the only place
-- that knows, and C is suppressed there too; this block is `do`-scoped and
-- cannot see `ridingNow`, which is declared a thousand lines below it.
--
-- NOTHING ELSE HIDES IT, and this paragraph used to claim the garage picker
-- did -- "hidden while the picker is open regardless, belt and braces". No
-- code ever did that, which is this project's own most-repeated failure: a
-- comment asserting a rule the code does not keep. It cannot collide with
-- the picker anyway, because `HUDLayout` owns every position out here now --
-- the fan-out opens ABOVE the row rather than out of this button's corner,
-- and the x=174 that sentence was measured against is overwritten by
-- `bindAction` on the next line.
--
-- WRAPPED IN A `do` BLOCK SO IT COSTS THIS CHUNK NOTHING. ClientMain is one
-- Luau chunk against a 200-local ceiling, and it has died twice for four
-- top-level locals -- taking the ENTIRE HUD with it, naming some innocent
-- variable two thousand lines away. Three locals live in here; the picker
-- finds this button by name rather than holding a fourth.
do

local tiptoeButton = makeActionButton("TiptoeButton", "SNEAK", "SNEAK", "C",
	Theme.MUTED, UDim2.new(0, 68, 0, 68), 18, gui, true)
tiptoeButton.AnchorPoint = Vector2.new(0, 1)
tiptoeButton.Position = UDim2.new(0, 174, 1, -140)
require(ReplicatedStorage.Shared.HUDLayout).bindAction(tiptoeButton, gui, 3)

local tiptoePressed = require(ReplicatedStorage.Shared.TouchOrigin).guard(tiptoeButton)
tiptoeButton.Activated:Connect(function()
	if not tiptoePressed() then
		return
	end
	-- Asks; never assumes. The server refuses this while carrying and drops
	-- it on a grab, so what comes back on TiptoeState is the only truth.
	Remotes.get("TiptoeRequest"):FireServer(gui:GetAttribute("Tiptoe") ~= true)
end)

-- THE KEY CHIP CARRIES THE STATE, which is the pattern the hot bar already
-- uses: the chip shows the key normally and a state word while something is
-- running. A second widget saying ON would be a light nobody looks at.
gui:GetAttributeChangedSignal("Tiptoe"):Connect(function()
	local on = gui:GetAttribute("Tiptoe") == true
	local chip = tiptoeButton:FindFirstChild("Key") :: TextLabel?
	if chip then
		chip.Text = if on then "ON" else "C"
	end
	local label = tiptoeButton:FindFirstChild("Label") :: TextLabel?
	if label then
		label.Text = if on then "SNEAKING" else "SNEAK"
	end
end)

end

-- WHETHER the bar is up is this file's business; HOW it is arranged is the
-- module's. Nothing to throw from inside a wheelie bin, so the bar goes with
-- the prompts rather than sitting there live for a player who cannot use it --
-- most of this audience never presses a key at all, so a control that looks
-- available and does nothing is the version of that bug they would meet.
HotBar.shouldShow = function(): boolean
	local boxedNow = stealthUI.latest ~= nil and stealthUI.latest.disguised == true
	-- AND NOT WHILE THE SHOP IS OPEN, which is the same rule one step on. The
	-- bar is pinned to the bottom of the screen and the panel is 0.86 of it,
	-- so the two overlap: the tiles were drawing over the bottom shelf of the
	-- front page, and the row of throwables a player cannot use while reading
	-- a shop is exactly the "looks available, does nothing" control this
	-- function already exists to suppress.
	return not boxedNow
		and not panel.Visible
		-- The bag panel is the same size in the same place, so it hides the
		-- bar for the same reason. Read as an attribute because the panel
		-- itself is built a long way below this function.
		and not gui:GetAttribute("BagOpen")
		and (boneHeld or gadgetUI.held or homeUI.held or stealthUI.held)
end

local function throwBone(key: string)
	Remotes.get("BoneThrow"):FireServer(key)
end

local function throwGadget(key: string)
	-- THE AIM COMES OFF THE PREVIEW, WHICH IS THE WHOLE REASON IT IS ASKED
	-- FOR HERE RATHER THAN COMPUTED HERE. `ThrowAim` traces the dotted line
	-- from this exact direction every frame, so sending anything else would
	-- be two implementations of one aim and the player would be throwing
	-- something they had not been shown.
	--
	-- A nil is a legal answer -- no camera, nothing in hand -- and the server
	-- falls back to the body's own facing rather than refusing. The require
	-- is cached, so reaching for the module here costs a table lookup and
	-- this chunk no register.
	Remotes.get("GadgetThrow"):FireServer(key, require(ReplicatedStorage.Shared.ThrowAim).aimDirection())
end

-- AIMING A GADGET IS THE CLIENT'S JOB, AND THE FACT THAT NONE OF IT IS IN
-- THIS FILE IS THE POINT OF THE LINE BELOW RATHER THAN AN OMISSION.
--
-- See Shared/ThrowAim. It squares the character to the camera, draws the
-- crosshair, holds the arm back while the button is down and throws toward
-- the crosshair on release. `throwGadget` above is only the fallback for a
-- use that did not come through a press.
--
-- `GadgetThrow` carries a DIRECTION now and still never a position. That is
-- a reversal, argued in full over Config.THROW: a Roblox character cannot
-- look up or down, so once the throw acquired a drop there was no way to
-- read a pitched aim off anything the server already held. The server still
-- owns the origin, the speed, the gravity, the range cap and the whole
-- simulation.
--
-- BONES ARE NOT AIMED, so nothing about `throwBone` above changed. See
-- Config.THROW for why that is a decision rather than unfinished work.
--
-- STARTED IN ONE STATEMENT HOLDING NO LOCAL AT ALL. This chunk is against
-- Luau's 200-register ceiling and has died twice naming an innocent variable
-- two thousand lines from whatever had actually been added.
require(ReplicatedStorage.Shared.ThrowAim).start()
-- Roblox's phone thumbstick stopped the player whenever ANY on-screen button
-- was pressed mid-run -- see the module. One statement, no local.
require(ReplicatedStorage.Shared.ThumbstickFix).start()

-- ============================================================
-- THE ITEM IN YOUR HAND
-- ============================================================
--
-- SELECTING IS FREE; CLICKING SPENDS. A number key or a tile tap asks the
-- server to DRAW something, which costs nothing and is undone by pressing the
-- same key again; only a click out in the world uses it. See Shared/HeldItem
-- for why, but the two reasons are that a stray thumb used to spend a
-- 30,000-coin Golden Bone with nothing having asked, and that the entire
-- consumable layer was invisible to everybody else on the street until the
-- instant it went off.
--
-- ONE TABLE, WHICH IS ONE LOCAL. This chunk is against Luau's 200-register
-- ceiling and has already died once naming an innocent variable, so a feature
-- that wants a few pieces of state groups them the way `gadgetUI.tiles` and
-- `stealthUI.held` already do rather than declaring four more.
local heldUI = {
	-- Read off the shared module rather than typed out again. The whole
	-- feature hangs off this one string -- the server stamps it, the HUD
	-- watches it -- and a second copy is the copy that drifts. Kept as a
	-- FIELD rather than as its own local because this chunk is against
	-- Luau's register ceiling and a require costs one either way.
	attribute = require(ReplicatedStorage.Shared.HeldItem).ATTRIBUTE,
	-- What the SERVER says is in our hand. Never written by a press: the
	-- server can refuse a draw (no stock, riding, hiding), and a client that
	-- lit its own tile would show an item it was refused.
	key = nil :: string?,
	-- Where a touch went down, so a camera drag is not read as a tap. A mouse
	-- needs none of this -- a click is a click -- but most of this audience is
	-- on a tablet, where every camera swing starts exactly like a tap.
	tapFrom = nil :: Vector2?,
}

-- Wired HERE and not up beside `HotBar.shouldShow`, which is where it belongs
-- by subject. `heldUI` is a local declared on the line above this one, and a
-- closure written earlier in the chunk would capture the nil GLOBAL of that
-- name instead -- the forward reference this project has been bitten by eleven
-- times, and the one shape of it that does not error: it would simply report
-- an empty hand forever, so every press would read as a draw.
HotBar.heldKey = function(): string?
	return heldUI.key
end

-- Toggle, because that is what one button means everywhere else in this game:
-- accessories, decorations and rides all put themselves away when asked for
-- again.
--
-- THE SERVER DOES THE TOGGLING, and this always sends the key. Comparing
-- against our own copy first and sending nil looks equivalent and is not: on
-- the one frame the two ends disagree it inverts, so a press that meant
-- "draw this" puts something away instead. One authority, no inversion.
function heldUI.equip(key: string)
	-- A KEY FOR SOMETHING YOU DO NOT HOLD STILL DOES NOTHING, which is a rule
	-- this file already had and which moving to a draw quietly broke.
	--
	-- Only SHELVED items are skipped when the key row is built, so an item
	-- whose stock ran out keeps its number -- that is the whole rule
	-- protecting muscle memory. Its tile is hidden, though, so without this
	-- the number under an invisible tile would fire a request the server can
	-- only refuse, and the player would get a toast about an item that is not
	-- on their screen. The client declining to ask for a known no is the same
	-- shape as suppressing the dodge while riding.
	--
	-- Tiles are safe either way: one is only visible while its stock is above
	-- zero, so this can never block a tap somebody could actually make.
	if heldUI.stock(key) <= 0 then
		return
	end
	Remotes.get("EquipRequest"):FireServer(key)
end

-- How many of this the player holds, from whichever of the four pushed
-- catalogues the key lives in. One lookup rather than four call sites,
-- because both the draw and the use need the same answer.
function heldUI.stock(key: string): number
	local entry = (latestBones and latestBones[key])
		or (gadgetUI.latest and gadgetUI.latest[key])
		or (homeUI.latest and homeUI.latest.items and homeUI.latest.items[key])
		or (stealthUI.latest and stealthUI.latest.items and stealthUI.latest.items[key])
	return if entry then entry.held or 0 else 0
end


-- A rendered 3D bone in a ViewportFrame, from the same model that gets thrown.
--
-- Not an image asset: a decal would be one more third-party ID to get moderated
-- away (see SOUNDS), and it could not stay in step with the geometry. A viewport
-- renders the real item, and a new bone style needs no art at all.
--
-- A viewport lights its contents from its own Ambient and LightDirection and
-- ignores every light in the scene, so the model is asked for WITHOUT its glow
-- and the framing is done here.
-- NO SPIN. Every shop icon used to turn on a shared Heartbeat, and it read as
-- CHOPPY rather than as lively -- which is what a per-frame `PivotTo` on a
-- Model inside a ViewportFrame looks like once there are a few dozen of them
-- on screen at once. It is not a frame-rate problem to be tuned away: the
-- motion buys nothing a still three-quarter view does not already show, and a
-- catalogue of objects gently juddering is worse than a catalogue of objects.
--
-- The `spin` parameter stays on `makeModelIcon` and is ignored, rather than
-- being removed from seventeen call sites for no behavioural gain.

makeModelIcon = function(parent: GuiObject, model: Model, size: UDim2, position: UDim2, spin: boolean): ViewportFrame
	local vp = Instance.new("ViewportFrame")
	vp.Size = size
	vp.Position = position
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(196, 194, 200)
	vp.LightColor = Color3.fromRGB(255, 250, 238)
	vp.LightDirection = Vector3.new(-0.35, -1, -0.55)
	vp.Parent = parent

	model.Parent = vp

	local camera = Instance.new("Camera")
	camera.Parent = vp
	vp.CurrentCamera = camera

	-- Re-centred on its VISUAL centre, and only here.
	--
	-- A model's pivot is its authored origin, because that is the point world
	-- placement has to be right about -- a hat is authored at its brim so it
	-- can sit on a head. An icon wants the opposite: the middle of the shape,
	-- so it spins in place and the camera has a fixed thing to aim at. The two
	-- are different points, so this copy moves itself and leaves the contract
	-- everyone else depends on alone.
	local box, extent = model:GetBoundingBox()
	model:TranslateBy(-box.Position)
	model.WorldPivot = CFrame.new()

	-- Framed from the model's own bounding box rather than a hardcoded
	-- distance, so an item with a different footprint fills the tile the same
	-- way instead of overflowing it or sitting lost in the middle.
	local dist = extent.Magnitude * 0.95
	camera.CFrame = CFrame.lookAt(
		Vector3.new(dist * 0.42, dist * 0.5, dist * 0.72), Vector3.zero)

	local tilt = CFrame.Angles(math.rad(-12), math.rad(-25), math.rad(8))
	model:PivotTo(tilt)


	return vp
end

-- ============================================================
-- EFFECT PREVIEWS
-- ============================================================
--
-- An effect tile shows a piggy with the effect actually running on it.
--
-- IT CANNOT USE A REAL ParticleEmitter, AND THIS WAS MEASURED RATHER THAN
-- ASSUMED. A ViewportFrame renders BaseParts and nothing else: no particles,
-- no beams, no trails, no lights. Two identical viewports were put on screen
-- side by side, one of them carrying a 200-per-second emitter at LightEmission
-- 1 and size 3, and they came out pixel-identical -- the emitter drew nothing
-- at all. That is why effects were a gradient swatch for so long.
--
-- So the particles are SIMULATED with real parts, from the effect's own numbers
-- in Config: its speed, lifetime, spread, drag, acceleration and colour ramp.
-- Nothing here is invented per effect, which is what makes the previews
-- actually differ -- frost falls because its accel is -4, inferno rockets
-- because its accel is +14 through a 34-degree cone, sparkle drifts because
-- its speed is 1 to 2.5 across a full sphere, and storm boils because it is
-- big and slow. Change a number in Config and the tile changes with it.
--
-- Wrapped in a do-block: the state below would otherwise be three more
-- top-level locals in a chunk that is near Luau's 200 ceiling, and a block's
-- locals are released at its `end`.
do
	type Bit = { part: Part, pos: Vector3, vel: Vector3, age: number, life: number }
	type Sim = { origin: CFrame, spec: any, scale: number, spawn: Vector3, bits: { Bit } }

	local sims: { Sim } = {}

	-- Roblox will not evaluate a ColorSequence for you, and a particle's whole
	-- character is in the ramp -- inferno goes pale gold to deep red across its
	-- life, and a single flat colour would lose exactly that.
	local function sampleColour(seq: ColorSequence, t: number): Color3
		local keys = seq.Keypoints
		if t <= keys[1].Time then
			return keys[1].Value
		end
		for i = 1, #keys - 1 do
			local a, b = keys[i], keys[i + 1]
			if t <= b.Time then
				return a.Value:Lerp(b.Value, (t - a.Time) / math.max(1e-6, b.Time - a.Time))
			end
		end
		return keys[#keys].Value
	end

	local function reseed(bit: Bit, sim: Sim)
		local spec = sim.spec
		bit.age = 0
		bit.life = spec.lifetime.Min + math.random() * (spec.lifetime.Max - spec.lifetime.Min)

		-- A direction inside the effect's own cone. 180 is the whole sphere,
		-- which is how sparkle and frost surround the piggy, while inferno's
		-- 34 keeps it a column.
		local half = math.rad(spec.spread or 45) / 2
		local theta = math.random() * math.pi * 2
		local phi = math.acos(1 - math.random() * (1 - math.cos(half)))
		local dir = Vector3.new(
			math.sin(phi) * math.cos(theta),
			math.cos(phi),
			math.sin(phi) * math.sin(theta))
		-- Downward effects are authored as a NEGATIVE accel rather than a
		-- flipped cone, so frost still emits upward and then falls, which is
		-- what snow does.
		local speed = spec.speed.Min + math.random() * (spec.speed.Max - spec.speed.Min)
		bit.vel = dir * speed * sim.scale
		bit.pos = sim.spawn + dir * 0.35
	end

	-- `spec` IS OPTIONAL AND DEFAULTS TO `Config.EFFECTS`, so the four call
	-- sites that only ever wanted a piggy aura are untouched and the catch
	-- catalogue passes its own row in. Taking the TABLE rather than a
	-- catalogue name keeps this function ignorant of how many particle
	-- catalogues exist, which is what a third one costs nothing.
	makeEffectIcon = function(parent: GuiObject, key: string, spec: any?)
		spec = spec or Config.EFFECTS[key]
		if not spec then
			return
		end

		-- A plain piggy, so the EFFECT is the subject of the tile rather than
		-- competing with a skin the player may not even own.
		--
		-- EXCEPT A NAB EFFECT, WHICH GOES OFF ON THE CAUGHT THIEF. A burst
		-- round a pig is exactly what the retired piggy auras looked like, so
		-- the Nab Effects shelf read as a shelf of them. The thief is the
		-- street's own neighbour (`CatchIcons.thief`), and the burst starts
		-- low on them, as `CatchFX` puts it at their feet. `k` is how much
		-- bigger the figure is than the mini pig the numbers below were
		-- tuned on, so the cloud keeps the same size ON SCREEN.
		local catch = Config.CATCH_EFFECTS[key] == spec
		local subject: Model? = if catch
			then require(ReplicatedStorage.Shared.CatchIcons).thief()
			else nil
		local k = if subject then 2.2 else 1
		local spawn = if subject then Vector3.new(0, -1.2, 0) else Vector3.new(0, 1.1, 0)
		subject = subject or PiggyModel.build(Config.DEFAULT_SKIN)
		local vp = makeModelIcon(parent, subject :: Model, UDim2.new(1, 0, 1, 0), UDim2.new(), false)

		if not spec.color or not spec.speed then
			return -- "None" is the subject and nothing else, which is the truth.
		end

		-- Every effect is normalised to about the same REACH on screen, and
		-- only the reach: an inferno particle covers eleven studs in its life
		-- and a sparkle covers three, so at a shared scale one would be a blur
		-- off the edge of the tile and the other would barely move. Direction,
		-- spread, colour, size and the speed SPREAD within an effect all
		-- survive; only the overall distance is fitted to a 156-pixel square.
		local reach = ((spec.speed.Min + spec.speed.Max) / 2)
			* ((spec.lifetime.Min + spec.lifetime.Max) / 2)
		local sim: Sim = {
			origin = (subject :: Model):GetPivot(),
			spec = spec,
			scale = 1.3 * k / math.max(0.5, reach),
			spawn = spawn,
			bits = {},
		}

		-- Particle count from the effect's own rate, so a 72-per-second
		-- inferno is visibly denser than an 11-per-second sparkle.
		local count = math.clamp(math.round((spec.rate or 12) / 3), 6, 16)
		-- The big soft one. Storm is authored at size 7 against everything
		-- else's 1 to 3.6, and it is smoke: dull and see-through, not neon.
		local smoke = (spec.size or 1) >= 5

		for _ = 1, count do
			local part = Instance.new("Part")
			part.Shape = Enum.PartType.Ball
			part.Size = Vector3.one * math.clamp((spec.size or 1) * 0.16, 0.12, 0.78) * k
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CastShadow = false
			part.Material = if smoke then Enum.Material.SmoothPlastic else Enum.Material.Neon
			part.Parent = vp

			local bit: Bit = { part = part, pos = Vector3.zero, vel = Vector3.zero, age = 0, life = 1 }
			reseed(bit, sim)
			-- Staggered, or every particle in the tile is born on the same
			-- frame and the whole cloud pulses in lockstep forever.
			bit.age = math.random() * bit.life
			table.insert(sim.bits, bit)
		end

		table.insert(sims, sim)
	end

	RunService.Heartbeat:Connect(function(dt)
		-- Only while the shop is open, exactly like the icon spin loop: this
		-- is a few dozen parts of work to animate something nobody is looking
		-- at otherwise.
		-- The bag shows the same cards on its Nab Effects tab, so it counts.
		if not panel.Visible and not gui:GetAttribute("BagOpen") then
			return
		end
		for _, sim in ipairs(sims) do
			local spec = sim.spec
			local accel = (spec.accel or Vector3.zero) * sim.scale
			local drag = spec.drag or 0
			local smoke = (spec.size or 1) >= 5

			for _, bit in ipairs(sim.bits) do
				bit.age += dt
				if bit.age >= bit.life then
					reseed(bit, sim)
				end

				bit.vel += accel * dt
				bit.vel *= math.max(0, 1 - drag * dt)
				bit.pos += bit.vel * dt

				local t = bit.age / bit.life
				bit.part.CFrame = sim.origin * CFrame.new(bit.pos)
				bit.part.Color = sampleColour(spec.color, t)
				-- In fast, out slow, so a particle appears rather than
				-- switching on and fades rather than vanishing.
				local fade = math.min(t / 0.15, (1 - t) / 0.55, 1)
				bit.part.Transparency = (if smoke then 0.55 else 0.1)
					+ (1 - math.clamp(fade, 0, 1)) * 0.9
			end
		end
	end)
end

local function ensureBoneTile(key: string, info: any)
	local existing = boneTiles[key]
	if existing then
		return existing
	end

	-- One card for the whole Supplies tab (Shared/SupplyCards): a picture, a
	-- name, one big stat and one big price. A tap opens the item's summary
	-- and BUY is on that, never here.
	local entry = SHOP.supply.card(bonesGridFrame, info.order or 99, info.name, SHOP.supply.tierOf(Config.BONES, key))
	local cardScale = Instance.new("UIScale")
	cardScale.Scale = cardFit.scale
	cardScale.Parent = entry.button
	table.insert(cardFit.cards, cardScale)
	if not require(ReplicatedStorage.Shared.ShopIcons).supply(entry.well, key) then
		makeModelIcon(entry.well, SHOP.supply.sideOn(BoneModel.build(key, false)), UDim2.new(1, 0, 1, 0), UDim2.new(), false)
	end
	boneTiles[key] = entry
	return entry
end

local function ensureBoneSlot(key: string, info: any)
	local existing = boneSlots[key]
	if existing then
		return existing
	end

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 58, 1, 0)
	-- LayoutOrder belongs to HotBar, not to us: the player may have dragged
	-- this slot somewhere. The number passed to `register` is where it sits
	-- until they do.
	-- Dark tile behind the icon, not the bone's own colour. The colour is in
	-- the rendered model now; painting the tile the same colour as the thing
	-- standing on it flattens the one part that has to read at a glance.
	button.BackgroundColor3 = PANEL
	button.BackgroundTransparency = 0.15
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.FredokaOne
	button.Text = ""
	HotBar.register(button, key, info.order or 99, info.name)
	corner(button, 10)

	-- Static, unlike the shop tiles. These sit on the HUD for the whole
	-- session, and something turning in the corner of the screen forever pulls
	-- the eye away from the plot the player is meant to be watching.
	makeModelIcon(button, BoneModel.build(key, false), UDim2.new(1, -6, 1, -6), UDim2.new(0, 3, 0, 3), false)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -6, 0, 18)
	label.Position = UDim2.new(0, 3, 1, -20)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.TextColor3 = Theme.INK
	-- Stroked, because it is drawn over a rendered model whose brightness
	-- changes with the bone: cream, red and gold all sit behind this number.
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Theme.INK
	label.Text = ""
	label.Parent = button

	local hotkey = Instance.new("TextLabel")
	hotkey.Size = UDim2.new(0, 22, 0, 14)
	hotkey.Position = UDim2.new(0, 3, 0, 2)
	hotkey.BackgroundTransparency = 1
	hotkey.Font = Enum.Font.GothamBold
	hotkey.TextScaled = true
	hotkey.TextXAlignment = Enum.TextXAlignment.Left
	hotkey.TextColor3 = Theme.COOL_INK
	hotkey.TextStrokeTransparency = 0.3
	hotkey.TextStrokeColor3 = Theme.INK
	hotkey.Text = ""
	hotkey.Parent = button

	button.Activated:Connect(function()
		-- A press that turned into a drag has already done its job.
		if HotBar.suppress() then
			return
		end
		-- SELECTS, never spends. A tap on a tile is the cheapest thing to do
		-- by accident on a touchscreen, so it is the one gesture in this
		-- feature that can never cost a coin.
		heldUI.equip(key)
	end)

	HotBar.styleSlot(button, label, hotkey)
	local entry = { button = button, label = label, hotkey = hotkey }
	boneSlots[key] = entry
	return entry
end

local function renderBones()
	if not latestBones then
		return
	end

	local anyHeld = false

	for key, info in pairs(latestBones) do
		local tile = ensureBoneTile(key, info)
		tile.title.Text = info.name
		tile.stat.Text = SHOP.supply.seconds(info.nap) .. " nap"
		tile.price.Text = format(info.cost)
		tile.spec = {
			name = info.name,
			about = SHOP.supply.about("bone", info.blurb or (Config.BONES[key] or {}).blurb),
			stats = {
				{ label = "Dog naps", value = SHOP.supply.seconds(info.nap) },
				{ label = "Breaks a chase", value = if info.breaksChase then "Yes" else "No" },
			},
			cost = info.cost,
			price = format(info.cost),
			onBuy = function()
				Remotes.get("GearRequest"):FireServer(key)
			end,
		}
		tile.button.BackgroundColor3 = if latestCoins >= info.cost
			then ShopStyle.BUY
			else ShopStyle.CARD

		local slot = ensureBoneSlot(key, info)
		HotBar.setHeld(key, info.held > 0)
		slot.label.Text = tostring(info.held)
		-- Every slot shows its NUMBER, bones included.
		--
		-- This used to show "G" on the cheapest bone instead, which left the
		-- bar reading G,2,3,4,5,6 -- so the one key a player could work out by
		-- looking was the one that was not advertised anywhere. G is gone
		-- entirely now and every tile carries its own number, which is the
		-- version of this that needs no explaining.
		local hot = HotBar.keyFor(key)
		slot.hotkey.Text = if hot then hot.label else ""
		if info.held > 0 then
			anyHeld = true
		end
	end

	boneHeld = anyHeld
	SHOP.supply.refresh()
	HotBar.refresh()
end

-- ONE Heartbeat loop for every shop icon, the same way animated skins are
-- driven. A connection per ViewportFrame would be three loops doing one
-- rotation each, and a fourth the moment another bone is added.
--
-- Only turns while the shop is actually open. These icons are offscreen for
-- almost the whole session, and rendering three viewports every frame to
-- animate something nobody is looking at is pure waste.
-- ============================================================
-- GADGETS
-- ============================================================


local function ensureGadgetTile(key: string, info: any)
	local existing = gadgetUI.tiles[key]
	if existing then
		return existing
	end

	-- One card for the whole Supplies tab (Shared/SupplyCards): a picture, a
	-- name, one big stat and one big price. A tap opens the item's summary
	-- and BUY is on that, never here.
	local entry = SHOP.supply.card(gadgetsGridFrame, (info.order or 99) + 100, info.name, SHOP.supply.tierOf(Config.GADGETS, key))
	local cardScale = Instance.new("UIScale")
	cardScale.Scale = cardFit.scale
	cardScale.Parent = entry.button
	table.insert(cardFit.cards, cardScale)
	if not require(ReplicatedStorage.Shared.ShopIcons).supply(entry.well, key) then
		makeModelIcon(entry.well, SHOP.supply.sideOn(GadgetModel.build(key, false)), UDim2.new(1, 0, 1, 0), UDim2.new(), false)
	end
	gadgetUI.tiles[key] = entry
	return entry
end

local function ensureGadgetSlot(key: string, info: any)
	local existing = gadgetUI.slots[key]
	if existing then
		return existing
	end

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 58, 1, 0)
	-- After the bones in the bar, so the two kinds never interleave as stock
	-- comes and goes. Bones are thrown at dogs and gadgets at people; keeping
	-- them grouped means the hand knows which half it is reaching for.
	-- LayoutOrder belongs to HotBar, not to us: the player may have dragged
	-- this slot somewhere. The number passed to `register` is where it sits
	-- until they do.
	button.BackgroundColor3 = PANEL
	button.BackgroundTransparency = 0.15
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.FredokaOne
	button.Text = ""
	HotBar.register(button, key, 10 + (info.order or 99), info.name)
	corner(button, 10)

	-- Static, like the bone slots: something turning in the corner of the
	-- screen forever pulls the eye off the plot the player should be watching.
	makeModelIcon(button, GadgetModel.build(key, false), UDim2.new(1, -6, 1, -6), UDim2.new(0, 3, 0, 3), false)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -6, 0, 18)
	label.Position = UDim2.new(0, 3, 1, -20)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.TextColor3 = Theme.INK
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Theme.INK
	label.Text = ""
	label.Parent = button

	local hotkey = Instance.new("TextLabel")
	hotkey.Size = UDim2.new(0, 22, 0, 14)
	hotkey.Position = UDim2.new(0, 3, 0, 2)
	hotkey.BackgroundTransparency = 1
	hotkey.Font = Enum.Font.GothamBold
	hotkey.TextScaled = true
	hotkey.TextXAlignment = Enum.TextXAlignment.Left
	hotkey.TextColor3 = Theme.STOP_INK
	hotkey.TextStrokeTransparency = 0.3
	hotkey.TextStrokeColor3 = Theme.INK
	hotkey.Text = ""
	hotkey.Parent = button

	button.Activated:Connect(function()
		-- A press that turned into a drag has already done its job.
		if HotBar.suppress() then
			return
		end
		-- SELECTS, never spends. A tap on a tile is the cheapest thing to do
		-- by accident on a touchscreen, so it is the one gesture in this
		-- feature that can never cost a coin.
		heldUI.equip(key)
	end)

	HotBar.styleSlot(button, label, hotkey)
	local entry = { button = button, label = label, hotkey = hotkey }
	gadgetUI.slots[key] = entry
	return entry
end

local function renderGadgets()
	if not gadgetUI.latest then
		return
	end

	local anyHeld = false
	for key, info in pairs(gadgetUI.latest) do
		local tile = ensureGadgetTile(key, info)
		tile.title.Text = info.name
		-- What it does, in the two numbers that matter: how much it takes off
		-- them and for how long. A full stop is called out separately, because
		-- "stops them" is a different promise from "slows them" and one number
		-- cannot make both.
		local spec = Config.GADGETS[key] or {}
		local stun = spec.stun or 0
		tile.stat.Text = if stun > 0
			then "Freezes " .. SHOP.supply.seconds(stun)
			else "Slows " .. SHOP.supply.seconds(info.duration)
		tile.price.Text = format(info.cost)
		tile.spec = {
			name = info.name,
			about = SHOP.supply.about(if spec.beam then "zapper" else "gadget", info.blurb or spec.blurb),
			-- A freezing gadget says how long it freezes and nothing else: its
			-- slow afterwards is a second number that reads as a second effect.
			stats = if stun > 0 then {
					{ label = "Freezes", value = SHOP.supply.seconds(stun) },
					{ label = "Range", value = ("%d studs"):format(info.range) },
				} else {
					{ label = "Slows", value = ("-%d%%"):format(info.slowPercent) },
					{ label = "Lasts", value = SHOP.supply.seconds(info.duration) },
					{ label = "Range", value = ("%d studs"):format(info.range) },
				},
			cost = info.cost,
			price = format(info.cost),
			onBuy = function()
				Remotes.get("GadgetRequest"):FireServer(key)
			end,
		}
		tile.button.BackgroundColor3 = if latestCoins >= info.cost
			then ShopStyle.BUY
			else ShopStyle.CARD

		local slot = ensureGadgetSlot(key, info)
		HotBar.setHeld(key, info.held > 0)
		slot.label.Text = tostring(info.held)
		local hot = HotBar.keyFor(key)
		slot.hotkey.Text = if hot then hot.label else ""
		if info.held > 0 then
			anyHeld = true
		end
	end

	gadgetUI.held = anyHeld
	SHOP.supply.refresh()
	HotBar.refresh()
end

-- ============================================================
-- HOME ITEMS
-- ============================================================


local function ensureHomeTile(key: string, info: any, parent: Frame)
	local existing = homeUI.tiles[key]
	if existing then
		return existing
	end

	-- One card for the whole Supplies tab (Shared/SupplyCards): a picture, a
	-- name, one big stat and one big price. A tap opens the item's summary
	-- and BUY is on that, never here.
	local entry = SHOP.supply.card(parent, info.order or 99, info.name, SHOP.supply.tierOf(Config.HOME_ITEMS, key))
	local cardScale = Instance.new("UIScale")
	cardScale.Scale = cardFit.scale
	cardScale.Parent = entry.button
	table.insert(cardFit.cards, cardScale)
	makeModelIcon(entry.well, SHOP.supply.sideOn(HomeModel.build(key)), UDim2.new(1, 0, 1, 0), UDim2.new(), false)
	homeUI.tiles[key] = entry
	return entry
end

local function ensureHomeSlot(key: string, info: any)
	local existing = homeUI.slots[key]
	if existing then
		return existing
	end

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 58, 1, 0)
	-- Last on the bar, after the bones and the gadgets. These are used at
	-- home rather than thrown at anybody, so they are the least urgent thing
	-- on it and belong furthest from the thumb.
	-- LayoutOrder belongs to HotBar, not to us: the player may have dragged
	-- this slot somewhere. The number passed to `register` is where it sits
	-- until they do.
	button.BackgroundColor3 = PANEL
	button.BackgroundTransparency = 0.15
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.FredokaOne
	button.Text = ""
	HotBar.register(button, key, 20 + (info.order or 99), info.name)
	corner(button, 10)

	makeModelIcon(button, HomeModel.build(key), UDim2.new(1, -6, 1, -6), UDim2.new(0, 3, 0, 3), false)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -6, 0, 18)
	label.Position = UDim2.new(0, 3, 1, -20)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.TextColor3 = Theme.INK
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Theme.INK
	label.Text = ""
	label.Parent = button

	local hotkey = Instance.new("TextLabel")
	hotkey.Size = UDim2.new(0, 22, 0, 14)
	hotkey.Position = UDim2.new(0, 3, 0, 2)
	hotkey.BackgroundTransparency = 1
	hotkey.Font = Enum.Font.GothamBold
	hotkey.TextScaled = true
	hotkey.TextXAlignment = Enum.TextXAlignment.Left
	hotkey.TextColor3 = Theme.GOOD_INK
	hotkey.TextStrokeTransparency = 0.3
	hotkey.TextStrokeColor3 = Theme.INK
	hotkey.Text = ""
	hotkey.Parent = button

	button.Activated:Connect(function()
		-- A press that turned into a drag has already done its job.
		if HotBar.suppress() then
			return
		end
		-- SELECTS, never spends. A tap on a tile is the cheapest thing to do
		-- by accident on a touchscreen, so it is the one gesture in this
		-- feature that can never cost a coin.
		heldUI.equip(key)
	end)

	HotBar.styleSlot(button, label, hotkey)
	local entry = { button = button, label = label, hotkey = hotkey }
	homeUI.slots[key] = entry
	return entry
end

local function renderHome()
	if not homeUI.latest then
		return
	end

	local anyHeld = false
	for key, info in pairs(homeUI.latest.items or {}) do
		local parent = if key == "treat" then treatGridFrame
			elseif key == "radio" then radioGridFrame
			else homeGridFrame
		local tile = ensureHomeTile(key, info, parent)
		-- The treat shares the AT HOME grid with nothing else now, but both
		-- catalogues still number their items from 1, so it is pushed past
		-- them rather than
		-- interleaved. It has to come AFTER the tile exists: `parent` is
		-- chosen up here, but the button is not built until ensureHomeTile.
		if key == "treat" then
			tile.button.LayoutOrder = (info.order or 99) + 100
		end
		tile.title.Text = info.name
		-- A DURATION IS OPTIONAL: the radio is a phone call, so it has none
		-- and its stat says when the patrol comes instead.
		local lasts = info.duration and info.duration > 0
		local spec = Config.HOME_ITEMS[key] or {}
		tile.stat.Text = if lasts then "Lasts " .. SHOP.supply.seconds(info.duration) else "Patrol comes now"
		tile.price.Text = format(info.cost)
		tile.spec = {
			name = info.name,
			about = SHOP.supply.about(key, info.blurb or spec.blurb, spec.detail),
			stats = {
				if lasts then { label = "Lasts", value = SHOP.supply.seconds(info.duration) }
					else { label = "Patrol arrives", value = "Now" },
			},
			cost = info.cost,
			price = format(info.cost),
			onBuy = function()
				Remotes.get("HomeRequest"):FireServer(key)
			end,
		}
		tile.button.BackgroundColor3 = if latestCoins >= info.cost
			then ShopStyle.BUY
			else ShopStyle.CARD

		local slot = ensureHomeSlot(key, info)
		HotBar.setHeld(key, info.held > 0)
		slot.label.Text = tostring(info.held)
		local hot = HotBar.keyFor(key)
		slot.hotkey.Text = if hot then hot.label else ""
		if info.held > 0 then
			anyHeld = true
		end
	end

	-- The countdown, on the treat's own slot. Ten thousand coins with nothing
	-- on screen to show for it reads as a purchase that did not take -- and the
	-- one thing a defender actually wants to know is how long they have left
	-- before they should head home.
	local left = homeUI.latest.guardSeconds or 0
	local treatSlot = homeUI.slots.treat
	if treatSlot then
		if left > 0 then
			treatSlot.button.Visible = true
			treatSlot.label.Text = ("%d:%02d"):format(math.floor(left / 60), left % 60)
			treatSlot.hotkey.Text = "ON"
			anyHeld = true
		else
			local tk = HotBar.keyFor("treat")
			treatSlot.hotkey.Text = if tk then tk.label else ""
		end
	end

	homeUI.held = anyHeld
	SHOP.supply.refresh()
	HotBar.refresh()
end

-- ============================================================
-- THIEF KIT
-- ============================================================


local function ensureStealthTile(key: string, info: any)
	local existing = stealthUI.tiles[key]
	if existing then
		return existing
	end

	-- One card for the whole Supplies tab (Shared/SupplyCards): a picture, a
	-- name, one big stat and one big price. A tap opens the item's summary
	-- and BUY is on that, never here.
	local entry = SHOP.supply.card(stealthGridFrame, info.order or 99, info.name, SHOP.supply.tierOf(Config.THIEF_KIT, key))
	local cardScale = Instance.new("UIScale")
	cardScale.Scale = cardFit.scale
	cardScale.Parent = entry.button
	table.insert(cardFit.cards, cardScale)
	makeModelIcon(entry.well, ThiefModel.build(key), UDim2.new(1, 0, 1, 0), UDim2.new(), false)
	stealthUI.tiles[key] = entry
	return entry
end

local function ensureStealthSlot(key: string, info: any)
	local existing = stealthUI.slots[key]
	if existing then
		return existing
	end

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 58, 1, 0)
	-- Last on the bar. The order across the whole thing is bones, gadgets,
	-- home, thief kit -- grouped by who you use them ON, so the hand knows
	-- which quarter it is reaching for without reading.
	-- LayoutOrder belongs to HotBar, not to us: the player may have dragged
	-- this slot somewhere. The number passed to `register` is where it sits
	-- until they do.
	button.BackgroundColor3 = PANEL
	button.BackgroundTransparency = 0.15
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	button.Font = Enum.Font.FredokaOne
	button.Text = ""
	HotBar.register(button, key, 30 + (info.order or 99), info.name)
	corner(button, 10)

	makeModelIcon(button, ThiefModel.build(key), UDim2.new(1, -6, 1, -6), UDim2.new(0, 3, 0, 3), false)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -6, 0, 18)
	label.Position = UDim2.new(0, 3, 1, -20)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextXAlignment = Enum.TextXAlignment.Right
	label.TextColor3 = Theme.INK
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Theme.INK
	label.Text = ""
	label.Parent = button

	local hotkey = Instance.new("TextLabel")
	hotkey.Size = UDim2.new(0, 22, 0, 14)
	hotkey.Position = UDim2.new(0, 3, 0, 2)
	hotkey.BackgroundTransparency = 1
	hotkey.Font = Enum.Font.GothamBold
	hotkey.TextScaled = true
	hotkey.TextXAlignment = Enum.TextXAlignment.Left
	hotkey.TextColor3 = Theme.readable(Theme.HUE.effects)
	hotkey.TextStrokeTransparency = 0.3
	hotkey.TextStrokeColor3 = Theme.INK
	hotkey.Text = ""
	hotkey.Parent = button

	button.Activated:Connect(function()
		-- A press that turned into a drag has already done its job.
		if HotBar.suppress() then
			return
		end
		-- SELECTS, never spends. A tap on a tile is the cheapest thing to do
		-- by accident on a touchscreen, so it is the one gesture in this
		-- feature that can never cost a coin.
		heldUI.equip(key)
	end)

	HotBar.styleSlot(button, label, hotkey)
	local entry = { button = button, label = label, hotkey = hotkey }
	stealthUI.slots[key] = entry
	return entry
end

local function renderStealth()
	if not stealthUI.latest then
		return
	end

	local anyHeld = false
	for key, info in pairs(stealthUI.latest.items or {}) do
		local tile = ensureStealthTile(key, info)
		tile.title.Text = info.name
		tile.stat.Text = ""
		tile.price.Text = format(info.cost)
		tile.spec = {
			name = info.name,
			about = SHOP.supply.about("stealth", info.blurb, info.detail),
			stats = {},
			cost = info.cost,
			price = format(info.cost),
			onBuy = function()
				Remotes.get("StealthRequest"):FireServer(key)
			end,
		}
		tile.button.BackgroundColor3 = if latestCoins >= info.cost
			then ShopStyle.BUY
			else ShopStyle.CARD

		local slot = ensureStealthSlot(key, info)
		HotBar.setHeld(key, info.held > 0)
		slot.label.Text = tostring(info.held)
		local hot = HotBar.keyFor(key)
		slot.hotkey.Text = if hot then hot.label else ""
		if info.held > 0 then
			anyHeld = true
		end
	end

	-- Both of these are STATES once used, and a state with nothing on screen
	-- reads as a purchase that did not take. The slot says so instead of the
	-- player having to guess whether they are still hidden.
	-- The Disguise Kit's slot used to live here and show "HID" while boxed.
	-- Both are gone: the item was removed, and the indicator was unreachable
	-- anyway -- `HotBar.shouldShow` returns false for the whole time a player
	-- is in a bin, so the bar carrying that tile was never on screen.

	stealthUI.held = anyHeld
	HotBar.refresh()
end

-- ============================================================
-- RIDES
-- ============================================================


local function ensureRideTile(key: string, info: any)
	local existing = rideUI.tiles[key]
	if existing then
		return existing
	end

	local button = Instance.new("TextButton")
	button.LayoutOrder = info.order or 99
	button.BackgroundColor3 = PANEL
	button.BorderSizePixel = 0
	button.Font = Enum.Font.FredokaOne
	button.Text = ""
	button.Parent = ridesGridFrame
	corner(button, 16)

	-- ONE edge, and it is the rarity's: a GuiObject honours a single UIStroke,
	-- and the ink outline that used to be first in line was the one drawn.
	local rideTier = if Config.RARITIES[info.rarity] then info.rarity
		elseif Config.RIDES[key] then Config.rarityOf(Config.RIDES[key]) else "common"
	do
		local edge = Instance.new("UIStroke")
		edge.Name = "RarityEdge"
		edge.Thickness = if rideTier == "legendary" then 5 else 3
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Parent = button
	end

	-- A studio render of the real model (ShopRideCards), matching the guardian
	-- and house cards; the live RideModel preview is the fallback for a ride
	-- with no render. Both come from RideModel's own parts, so neither is a
	-- coloured rectangle kept in sync by hand.
	local cardScale = Instance.new("UIScale")
	cardScale.Scale = cardFit.scale
	cardScale.Parent = button
	table.insert(cardFit.cards, cardScale)

	local well = ShopStyle.well(button)
	-- The whole card wears the tier, as it does in the bag (ShopSkinCards).
	local ridePalette = require(ReplicatedStorage.Shared.ShopSkinCards).dressCard(button, rideTier, { well })
	if not require(ReplicatedStorage.Shared.ShopRideCards).mount(well, key) then
		makeModelIcon(well, RideModel.build(key), UDim2.new(1, 0, 1, 0), UDim2.new(), false)
	end

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -16, 0, 20)
	title.Position = UDim2.new(0, 8, 0, 110)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 15
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = ShopStyle.TEXT
	title.Text = info.name
	title.Parent = button
	require(ReplicatedStorage.Shared.ShopSkinCards).onTierText(title)

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -16, 0, 24)
	sub.Position = UDim2.new(0, 8, 0, 150)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamBold
	sub.TextSize = 13
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.TextColor3 = GOLD
	sub.Text = ""
	sub.Parent = button
	ShopStyle.priceRow(sub)

	button.Activated:Connect(function()
		Remotes.get("RideRequest"):FireServer(key)
	end)

	local entry = { button = button, title = title, sub = sub,
		deep = if ridePalette then ridePalette.deep else ShopStyle.INK }
	rideUI.tiles[key] = entry
	return entry
end

-- REPAINT THE KEY LABELS WHENEVER THE ARRANGEMENT MOVES.
--
-- The bar owns which key an item has; these four own the label that shows it,
-- because the same label doubles as a state word ("ON") while a buff runs.
-- Without this hook the two drift apart the moment a saved arrangement loads.
--
-- Assigned HERE rather than beside `HotBar.shouldShow` because all four are
-- declared further down the file, and a `local function` read from above
-- compiles against a nil global and dies at the call naming neither it nor
-- the cause.
HotBar.onArranged = function()
	renderBones()
	renderGadgets()
	renderHome()
	renderStealth()
end

local function renderRides()
	if not rideUI.latest then
		return
	end

	if rideUI.renderStyleOffer then
		rideUI.renderStyleOffer()
	end

	for key, info in pairs(rideUI.latest.rides or {}) do
		local tile = ensureRideTile(key, info)
		tile.title.Text = info.name

		if info.equipped then
			-- Says whether the board is actually under them right now, not just
			-- that it is selected. Those are different states -- standing on your
			-- own lawn is the second without the first -- and a tile that claimed
			-- "RIDING" while the player was plainly walking would read as a bug.
			-- Owned states in the tier's own colours, like the bag and the
			-- crate pages: equipped is the solid deep pill, owned the light one,
			-- and anything for sale keeps the dark price pill.
			tile.sub.Text = if rideUI.latest.riding then "RIDING" else "READY -- HIT THE STREET"
			tile.sub.BackgroundColor3 = tile.deep
			tile.sub.TextColor3 = Theme.PAPER
			tile.button.BackgroundColor3 = ShopStyle.OWNED
		elseif info.owned then
			tile.sub.Text = ("RIDE  ·  +%d%%"):format(info.boost)
			tile.sub.BackgroundColor3 = Theme.PAPER
			tile.sub.TextColor3 = tile.deep
			tile.button.BackgroundColor3 = ShopStyle.CARD
		elseif info.loot then
			-- A SET RIDE. No price: see the note on the decoration card above.
			tile.sub.BackgroundColor3 = ShopStyle.SUNK
			tile.sub.Text = ("ALIEN CACHE  ·  +%d%%"):format(info.boost)
			tile.sub.TextColor3 = Theme.MUTED_LIGHT
			tile.button.BackgroundColor3 = ShopStyle.LOCKED
		else
			tile.sub.BackgroundColor3 = ShopStyle.SUNK
			tile.sub.Text = ("%s  ·  +%d%%"):format(format(info.cost), info.boost)
			tile.sub.TextColor3 = if latestCoins >= info.cost then GOLD else Theme.MUTED
			tile.button.BackgroundColor3 = ShopStyle.DEAR
		end
	end
end

-- Declared up here, above the Heartbeat that reads it, rather than beside the
-- ride code that assigns it. A `local` declared AFTER a function that reads it
-- silently becomes a nil GLOBAL in Luau, and this file has lost four bugs to
-- exactly that -- the last one an hour ago.
local ridingNow = false

RunService.Heartbeat:Connect(function()
	-- The dodge button goes with the hot bar and the prompts. Set from HERE
	-- rather than from the StealthState handler, which is written two hundred
	-- lines ABOVE this button and above `ridingNow` -- a function that reads a
	-- local declared after it captures a nil global in Luau, and this file has
	-- lost four bugs to exactly that.
	-- ONE RULE, EVERY FRAME. Hiding it from the StealthState handler and
	-- restoring it from the RideState one meant climbing out of a bin left the
	-- button gone until the next ride push -- two handlers owning one property
	-- and neither of them firing at the moment that mattered.
	local want = not ridingNow
		and not (stealthUI.latest ~= nil and stealthUI.latest.disguised == true)
	if dodgeButton.Visible ~= want then
		dodgeButton.Visible = want
	end

	local left = dodgeReadyAt - os.clock()
	if left > 0 then
		dodgeFill.Size = UDim2.new(left / Config.DODGE.cooldown, 0, 1, 0)
		dodgeButton.BackgroundColor3 = Theme.PAPER
	elseif dodgeFill.Size.X.Scale > 0 then
		dodgeFill.Size = UDim2.new(0, 0, 1, 0)
		dodgeButton.BackgroundColor3 = Theme.COOL
	end

	-- Drained ABOVE the closed-panel early-out on purpose: the shelves have to
	-- be right at the instant the panel opens, and a render is a few string
	-- formats plus icons that only rebuild when the chosen item changes.
	if frontUI.dirty and frontUI.render then
		frontUI.dirty = false
		frontUI.render()
	end

end)

Remotes.get("GearState").OnClientEvent:Connect(function(snapshot)
	latestBones = snapshot
	renderBones()
	frontUI.dirty = true
end)

Remotes.get("CosmeticState").OnClientEvent:Connect(function(snapshot)
	Rebirth.onCosmetics(snapshot)
	latestCosmetics = snapshot
	Crates.setCosmetics(snapshot)
	renderCosmetics()
	frontUI.dirty = true
end)

-- ============================================================
-- LOOT, SETS AND THE DROP REEL
-- ============================================================
--
-- Wrapped, because this chunk is at Luau's 200-local ceiling: a `do` block
-- keeps every name in here off the top-level register file. The section that
-- overflowed it last time added about twenty locals and took down the ENTIRE
-- HUD, since the chunk never compiles and nothing gets built.
do
	Remotes.get("SetState").OnClientEvent:Connect(function(state)
		setUI.sets = state.sets
		setUI.dirty = true
		renderCosmetics()
	end)

	-- THE PREVIEW PIG'S MESH, WARMED BEFORE ANYTHING ASKS FOR ONE.
	--
	-- `iconFor` below is called from inside a pcall on a render path, and
	-- `PiggyModel.build` must not yield there -- so the template is built
	-- once, off the critical path, and every card afterwards is a clone.
	-- Spawned rather than awaited because the HUD has no reason to wait for
	-- a picture: until it lands, `build` hands back the primitives pig and
	-- the first repaint after it swaps every card over.
	task.spawn(function()
		if not PiggyModel.prewarm() then
			return
		end
		-- EVERY ICON CACHE HAS TO BE TOLD, and this is the half that is easy
		-- to miss. All three surfaces build a 3D preview ONCE and paint it
		-- afterwards -- a ViewportFrame is far too dear to rebuild per push --
		-- so anything built during the warm-up keeps the primitives pig for
		-- the rest of the session. Nothing errors and nothing looks broken;
		-- the game just quietly shows two different pigs for one skin, which
		-- is the fault this whole change set out to fix.
		--
		-- The crate reel is deliberately absent: it builds its strip fresh on
		-- every spin, so it corrects itself.
		renderCosmetics()
		-- REQUIRED INLINE RATHER THAN THROUGH `Inv`, which is a local declared
		-- in a block eighty lines BELOW this one -- a closure reading it from
		-- up here captures a nil global and dies when the mesh lands, minutes
		-- after anything could point at the cause. Roblox caches a module per
		-- ModuleScript, so this is the same table that block holds rather
		-- than a second copy with its own empty card list.
		require(ReplicatedStorage.Shared.Inventory).rebuildIcons()
		Crates.rebuildIcons()
		if SHOP.upgrades then SHOP.upgrades:rebuildIcons() end
		if SHOP.shell then SHOP.shell:rebuildPiggy() end
		-- The HUD pig too, if it was painted as the primitives stand-in.
		if bankHUD.showWorn and latestCosmetics then
			bankHUD.showWorn(latestCosmetics, true)
		end
		-- The shelf wells rebuild only when their item KEY changes, so the
		-- key has to be cleared rather than the render merely re-run.
		for _, d in ipairs(startView:GetDescendants()) do
			if d:GetAttribute("ItemKey") ~= nil then
				d:SetAttribute("ItemKey", nil)
			end
		end
		frontUI.dirty = true
	end)

	-- THE DROP REEL. The server has already decided; this only animates
	-- landing on the answer. Icons are handed in rather than built inside
	-- SpinWheel, so the reel shows the REAL item from the same builders the
	-- shop uses and there is no second set of pictures to drift.
	local function iconFor(kind: string, key: string, holder: Frame, static: boolean?)
		-- Every tiered item stands on its tier's colour with a spotlight streak
		-- (ShopSkinCards.backdrop). A kind with no tier -- supplies -- passes an
		-- empty tier, which clears a backdrop left by a previous item.
		do
			local catalogue = if kind == "finish" then Config.FINISHES elseif kind == "gear" then Config.GEAR else Config.catalogueFor(kind)
			local spec = catalogue and catalogue[key]
			require(ReplicatedStorage.Shared.ShopSkinCards).backdrop(holder, if spec then Config.rarityOf(spec) else "")
		end
		if kind == "consumable" and require(ReplicatedStorage.Shared.ShopIcons).supply(holder, key) then return end
		-- A skin with a baked render shows the render: a ViewportFrame cannot
		-- draw a textured coat at all. See ShopSkinCards.
		if kind == "skin" and require(ReplicatedStorage.Shared.ShopSkinCards).mount(holder, key) then return end
		if kind == "ride" and require(ReplicatedStorage.Shared.ShopRideCards).mount(holder, key) then return end
		local ok, model = pcall(function(): Model?
			if kind == "skin" then
				local m = PiggyModel.build(key)
				m:SetAttribute("SkinKey", key)
				return m
			elseif kind == "accessory" then
				return PigGear.build(key)
			elseif kind == "gear" then
				-- Most Wanted gear, shown in the bag: the real mask from the
				-- same builder that welds one to a head.
				return PlayerGear.build(key)
			elseif kind == "decor" then
				return Decor.buildOne(key, CFrame.new(), nil)
			elseif kind == "ride" then
				return RideModel.build(key)
			elseif kind == "finish" then
				-- The default piggy wearing the finish: shine and eye colour
				-- are what a finish changes, so that is what the tile shows.
				local spec = Config.FINISHES[key]
				local m = PiggyModel.build(Config.DEFAULT_SKIN)
				for _, d in ipairs(m:GetDescendants()) do
					if spec and d:IsA("BasePart") then
						if d.Name == "Eye" and spec.eyes then
							d.Color, d.Material = spec.eyes, Enum.Material.Neon
						elseif spec.reflectance then
							d.Reflectance = math.min(1, d.Reflectance + spec.reflectance)
						end
					end
				end
				return m
			elseif kind == "consumable" then
				return if Config.BONES[key] then BoneModel.build(key, false) else GadgetModel.build(key, false)
			elseif kind == "catch" then
				-- A drawn picture where the effect has one (CatchIcons);
				-- otherwise nil, and the simulated burst below takes over.
				return require(ReplicatedStorage.Shared.CatchIcons).build(key)
			end
			return nil
		end)
		if ok and model then
			if kind == "skin" or kind == "finish" then
				-- A pig is shot like the animal cards beside it. See ShopSkinCards.
				require(ReplicatedStorage.Shared.ShopSkinCards).pigPreview(holder, model)
			elseif static then
				require(ReplicatedStorage.Shared.ShopWidgets).preview(holder, model)
			else
				makeModelIcon(holder, model, UDim2.new(1, 0, 1, 0), UDim2.new(), true)
			end
		elseif kind == "effect" then
			-- An effect has no geometry, so it borrows the shop's own effect
			-- preview -- the one that simulates its Config numbers with parts,
			-- because a ViewportFrame renders no particles at all.
			makeEffectIcon(holder, key)
		elseif kind == "catch" then
			-- A catch effect is the same: its own burst, simulated off its
			-- Config numbers round the caught thief, as its shop card shows it.
			makeEffectIcon(holder, key, Config.CATCH_EFFECTS[key])
		end
	end

	-- THE HUD PIG WEARS YOUR SKIN. Held as fields on the panel rather than
	-- as locals: this chunk is at the 200-register ceiling, and a `do` block
	-- does not buy registers back. The painter is the shop's own -- the baked
	-- card render where a skin has one, otherwise a still 3D pig wearing it.
	bankHUD.paintSkin = function(key: string, holder: Frame)
		if require(ReplicatedStorage.Shared.ShopSkinCards).mount(holder, key) then
			return
		end
		local m = PiggyModel.build(key)
		m:SetAttribute("SkinKey", key)
		require(ReplicatedStorage.Shared.ShopSkinCards).pigPreview(holder, m)
	end
	bankHUD.showWorn = function(snapshot: any, force: boolean?)
		local worn = nil
		for key, entry in pairs(snapshot and snapshot.skins or {}) do
			if type(entry) == "table" and entry.equipped then
				worn = key
			end
		end
		bankHUD:setSkin(worn, bankHUD.paintSkin, force)
	end
	Remotes.get("CosmeticState").OnClientEvent:Connect(function(snapshot)
		bankHUD.showWorn(snapshot)
	end)
	if latestCosmetics then
		bankHUD.showWorn(latestCosmetics)
	end

	Remotes.get("EventDrop").OnClientEvent:Connect(function(payload)
		SpinWheel.play(gui, payload, iconFor)
	end)
	require(ReplicatedStorage.Shared.RobberyLoot).start(gui, iconFor)

	-- THE CRATES TAB IS WIRED IN HERE RATHER THAN BESIDE ITS TAB, because
	-- `iconFor` is local to this block and a crate card is three real item
	-- previews. Lifting that helper to the top level to reach it from further
	-- up would cost a register on a chunk that has none spare, to solve a
	-- problem that is only about where two lines sit.
	SHOP.premium = require(ReplicatedStorage.Shared.PremiumShop).new(SHOP.view.premium, { iconFor = iconFor })
	if latestCosmetics then
		SHOP.premium:render(latestCosmetics.passes)
	end
	Crates.init(SHOP.view.crates, {
		gui = gui,
		iconFor = function(kind, key, holder) iconFor(kind, key, holder, true) end,
		format = format,
		-- NO `open`. A crate is earned rather than bought, so the tab has no
		-- buy button and there is no channel to fire: `ChestService.grantFree`
		-- is reached from the daily ladder, a rebirth and events.
		buyback = function(key: string)
			Remotes.get("SkinBuyback"):FireServer(key)
		end,
		-- A TIER AND A CHEST, AND DELIBERATELY NO LIST OF SPARES. The remote
		-- takes an optional pick, and omitting it is what makes `autoPick`
		-- run server-side: cheapest first, from the spares the server can see
		-- the player actually holds. Naming three here would be the client
		-- asserting what it owns, which `validatePick` would then have to
		-- rebuild from known-good parts anyway.
		combine = function(tier: string, chestKey: string)
			Remotes.get("ChestCombine"):FireServer(tier, chestKey)
		end,
	})
	Remotes.get("ChestState").OnClientEvent:Connect(Crates.render)
	Remotes.get("ChestState").OnClientEvent:Connect(Rebirth.onChest)
	Remotes.get("ChestResult").OnClientEvent:Connect(Crates.reveal)

	-- THE ADMIN PICKER IS WIRED HERE, NOT BESIDE THE ADMIN PANEL, because it
	-- draws a real piggy per card and `iconFor` lives in this block. Holding
	-- no local: the module keeps its own state and `AdminPanel` opens it by
	-- name, so nothing up here needs a handle on it.
	require(ReplicatedStorage.Shared.AdminPiggyPicker).init(gui, {
		iconFor = function(kind, key, holder) iconFor(kind, key, holder, true) end,
		fire = function(command, targetId, a, b)
			Remotes.get("AdminRequest"):FireServer(command, targetId, a, b)
		end,
	})

	-- THE INVENTORY IS WIRED IN THE SAME BLOCK AND FOR THE SAME REASON: it
	-- renders a real model per owned item, so it needs `iconFor`, and this
	-- chunk has no top-level register to spare for a require.
	--
	-- REQUIRED INLINE, holding no local at all. `Inventory` keeps its own
	-- module state, so nothing up here needs a handle on it -- the three
	-- pushes below are the entire interface.
	local Inv = require(ReplicatedStorage.Shared.Inventory)

	-- ---- THE BAG PANEL -------------------------------------------------
	--
	-- Its own panel rather than a shop tab, because it is its own VERB. The
	-- shop is where you spend; this is where you look at what you already
	-- own, wear it, and turn a spare back into coins. Nothing in here has a
	-- price on it, which is the invariant the whole split exists to protect.
	--
	-- Built to the shop panel's exact geometry and furniture -- same scale,
	-- same cap, same corner, same red close button. Two full-screen panels
	-- one tap apart that were nearly-but-not-quite the same shape would read
	-- as a bug rather than as a pair.
	-- THE SHOP PANEL'S NUMBERS, EXACTLY: the same scale, the same offset
	-- under the topbar, the same 1200x760 cap, the same paper ground and the
	-- same 5px ink edge. The masthead, sign, balances and sidebar inside it
	-- are built by `Inventory` from the shop's own widgets.
	local bag = Instance.new("Frame")
	bag.Name = "BagPanel"
	bag.Size = panel.Size
	bag.Position = panel.Position
	bag.AnchorPoint = Vector2.new(0.5, 0.5)
	bag.BackgroundColor3 = Theme.PAPER
	bag.BorderSizePixel = 0
	bag.Visible = false
	bag.Active = true
	bag.ZIndex = Theme.MENU_Z
	bag.Parent = gui
	corner(bag, 22)
	ShopStyle.outline(bag, 5)

	local bagSize = Instance.new("UISizeConstraint")
	bagSize.MaxSize = panelSize.MaxSize
	bagSize.MinSize = panelSize.MinSize
	bagSize.Parent = bag

	-- U+00D7, not a capital X, and red -- the same close button the shop
	-- carries. This file has already measured which glyphs Roblox actually
	-- has: the heavy ballot crosses render as tofu and U+2714 ignores
	-- TextColor3, while the multiplication sign renders and takes its colour.
	local bagClose = Instance.new("TextButton")
	bagClose.Name = "CloseBag"
	bagClose.Size = UDim2.new(0, 44, 0, 44)
	bagClose.Position = UDim2.new(1, -46, 0, 4)
	bagClose.BackgroundColor3 = ShopStyle.STOP
	bagClose.BorderSizePixel = 0
	bagClose.Font = Enum.Font.FredokaOne
	bagClose.TextSize = 28
	bagClose.TextColor3 = ShopStyle.LIGHT
	bagClose.AutoButtonColor = true
	bagClose.Text = utf8.char(0x00D7)
	bagClose.Parent = bag
	corner(bagClose, 14)
	ShopStyle.outline(bagClose, 3)
	ShopStyle.gloss(bagClose)
	ShopStyle.pop(bagClose, 2)
	Theme.floatClose(bagClose)

	local bagBody = Instance.new("Frame")
	bagBody.Name = "InventoryView"
	bagBody.Size = UDim2.fromScale(1, 1)
	bagBody.BackgroundTransparency = 1
	bagBody.Parent = bag

	-- FORWARD-DECLARED, because `openCrate` below has to close the bag and
	-- `setBag` is written further down beside the toggle it serves. A
	-- `local function` read from ABOVE compiles against a nil global and dies
	-- at the call naming neither it nor the cause -- this file has lost
	-- several bugs to exactly that, and this is the same shape: the closure
	-- is built here and run minutes later when somebody taps a locked skin.
	local setBag: (boolean) -> ()

	Inv.init(bagBody, {
		gui = gui,
		close = bagClose,
		iconFor = iconFor,
		format = format,
		-- The shop's OWN remote, not a second equip path. Two ways to equip
		-- is two things that can disagree about what you are wearing, which
		-- is the rule the garage slot already follows for rides.
		equip = function(wire: string, key: string)
			if wire == "ride" then
				Remotes.get("RideRequest"):FireServer(key)
			else
				Remotes.get("CosmeticRequest"):FireServer(wire, key)
			end
		end,
		-- Kind, key and a count -- never a value. The server re-reads
		-- `Config.sellValue`, exactly as `ChestOpen` re-reads a cost, so
		-- there is no payout on the wire.
		sell = function(kind: string, key: string, count: number)
			Remotes.get("SpareSell"):FireServer(kind, key, count)
		end,
		-- TAPPING A GAP IN THE COLLECTION LOG TAKES YOU TO THE CRATE THAT
		-- FILLS IT. The chest key comes from `Config.skinSource`, which reads
		-- the skin's own `chest` tag -- so there is no map here from skins to
		-- crates to fall out of step with the catalogue.
		--
		-- It closes the bag on the way, because the shop and the bag are the
		-- two full-screen panels this HUD may never show at once: the loser
		-- sits invisible underneath with its close button unreachable, which
		-- is a trap with no way out rather than a tidiness problem. `setBag`
		-- owns both halves of that (the flag and the shop), so this routes
		-- through it rather than writing `panel.Visible` itself.
		openCrate = function(_chestKey: string)
			setBag(false)
			panel.Visible = true
			selectTab(SHOP.at.crates)
		end,
	})

	-- ---- THE BUTTON ----------------------------------------------------
	--
	-- Beside SHOP in the bottom-right, which is the one HUD corner with room:
	-- it went from 210x172 to 210x50 when EARN moved into the Upgrades tab,
	-- and the frame is `AutomaticSize.Y` anchored to the corner, so a second
	-- row grows it UPWARD and the shop button does not move. That matters --
	-- it is the control players already know the position of.
	--
	-- LayoutOrder 0 puts the bag ABOVE the shop rather than below it, so
	-- SHOP keeps the actual corner.
	--
	-- The pink is the piggy's own hue, which it wore as a tab: almost
	-- everything in here is a pig cosmetic. It is safe against the rule that
	-- pink and gold go on OBJECTS rather than under them -- that is about
	-- large GROUNDS, and this is a 50-pixel button whose ink is already
	-- measured against this exact hue, since every category hue has to carry
	-- ink type at 4.5 to be a tab at all.
	local bagToggle = makeActionButton("BagToggle", "SATCHEL", "STUFF",
		"I", Theme.HUE.piggy, UDim2.new(0, 66, 0, 64), 21, shop)
	bagToggle.LayoutOrder = 2

	-- TWO FULL-SCREEN PANELS MAY NEVER BE OPEN AT ONCE. They are the same
	-- size in the same place, so the loser is invisible underneath and its
	-- close button is unreachable -- a player would be looking at the shop
	-- with no way to know the bag was still open behind it.
	--
	-- WATCHED RATHER THAN POKED FROM THE PLACES THAT TOGGLE, the same call
	-- Rebirth and the hot bar already make on this panel: the shop is opened
	-- from a button, a close X, the B key, and a shop DOOR on the street, and
	-- three of those are defined above this block and could not call in here.
	setBag = function(open: boolean)
		bag.Visible = open
		-- An ATTRIBUTE rather than a local, because the three functions that
		-- have to respect this -- the hot bar's `shouldShow`, `heldUI.use`
		-- and `Rebirth.canShow` -- are all defined further down and this
		-- chunk has no top-level register to spare for a flag.
		gui:SetAttribute("BagOpen", open)
		if open then
			panel.Visible = false
		end
	end

	bagToggle.Activated:Connect(function()
		setBag(not bag.Visible)
	end)

	-- WHAT A ROBBERY LOOKS LIKE WHEN IT PAYS OUT: the grab pop, the carrying
	-- chip and the delivery summary. See `LootHaul`.
	--
	-- WIRED FROM INSIDE THIS BLOCK RATHER THAN BESIDE THE OTHER REMOTES,
	-- because it needs two things that live here and nowhere else -- the
	-- `iconFor` this block already hands to Crates and Inventory, and
	-- `setBag`, which is the only route to the bag and is deliberately a
	-- local so nothing outside can open a panel without the shop closing.
	-- The same call the Crates tab makes, and for the same reason.
	--
	-- ONE STATEMENT HOLDING NO LOCAL. This chunk is against Luau's 200-local
	-- ceiling and a feature of this size written inline would not cost the
	-- feature, it would cost the entire HUD.
	require(ReplicatedStorage.Shared.LootHaul).start(gui, iconFor, function()
		setBag(true)
	end)

	bagClose.Activated:Connect(function()
		setBag(false)
	end)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then
			setBag(false)
		end
	end)
	-- Settings is the third menu and is built in a `do` block far above this
	-- one, so it closes the bag the only way it can reach: its own attribute.
	gui:GetAttributeChangedSignal("SettingsOpen"):Connect(function()
		if gui:GetAttribute("SettingsOpen") then
			setBag(false)
		end
	end)

	-- The same two duties the shop panel's own visibility carries: the hot
	-- bar is a row of throwables a player cannot throw while reading a
	-- panel, and the rebirth button is pinned where this panel's header sits.
	bag:GetPropertyChangedSignal("Visible"):Connect(HotBar.refresh)
	bag:GetPropertyChangedSignal("Visible"):Connect(Rebirth.sync)

	-- I opens it, Escape closes it -- the same shape as B for the shop. The
	-- button stays the primary route: most of this audience is on a
	-- touchscreen and will never press a key. Checked against the map in
	-- CLAUDE.md before taking it: Q dodge/trick, B shop, V garage, R radio,
	-- Escape close, F2 admin, 1-0 the hot bar. I was free.
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.I then
			setBag(not bag.Visible)
		elseif input.KeyCode == Enum.KeyCode.Escape and bag.Visible then
			setBag(false)
		end
	end)

	-- THREE PUSHES, THREE SOURCES, AND A SECOND CONNECTION RATHER THAN A CALL
	-- BOLTED INTO THE EXISTING HANDLERS. Those handlers are above this block
	-- and cannot see `Inv`; connecting again is free, keeps this feature in
	-- one place, and means nothing up there has to know the tab exists.
	Remotes.get("CosmeticState").OnClientEvent:Connect(Inv.setCosmetics)
	Remotes.get("RideState").OnClientEvent:Connect(Inv.setRides)
	Remotes.get("RideState").OnClientEvent:Connect(Crates.setRides)
	Remotes.get("ChestState").OnClientEvent:Connect(Inv.setChest)

	for _, child in ipairs(upgradesView:GetChildren()) do
		if child:IsA("GuiObject") then child.Visible = false end
	end
	SHOP.upgrades = require(ReplicatedStorage.Shared.ShopUpgrades).new(upgradesView, function(key: string)
		Remotes.get(if key == "income" then "PurchaseRequest" else "UpgradeRequest"):FireServer(key)
	end)
	SHOP.upgrades:setUpgrades(latestUpgrades)
	SHOP.shell = require(ReplicatedStorage.Shared.ShopRevamp).new({
		panel = panel, header = header, rail = rail, title = panelTitle, coins = panelCoins,
		close = closeButton, tabs = tabs, at = SHOP.at, startView = startView,
		selectTab = selectTab,
	})
	SHOP.shell:setBalances(latestCoins)
	-- The landing banner names the cheapest pass not owned yet; the Robux tab
	-- works that out on every render and hands it over.
	if SHOP.premium then
		SHOP.premium.onFeatured = function(info)
			SHOP.shell:setFeatured(info)
		end
		SHOP.premium:render()
	end
end

Remotes.get("GadgetState").OnClientEvent:Connect(function(snapshot)
	gadgetUI.latest = snapshot
	renderGadgets()
	frontUI.dirty = true
end)

Remotes.get("HomeState").OnClientEvent:Connect(function(snapshot)
	homeUI.latest = snapshot
	renderHome()
	frontUI.dirty = true
end)

Remotes.get("DodgeState").OnClientEvent:Connect(function(secondsLeft)
	dodgeReadyAt = os.clock() + (secondsLeft or 0)
end)

Remotes.get("StealthState").OnClientEvent:Connect(function(snapshot)
	stealthUI.latest = snapshot

	-- IN A BIN YOU MAY DO EXACTLY ONE THING, WHICH IS CLIMB OUT.
	--
	-- Every prompt on this client goes off together: the bin's own OPEN --
	-- which the occupant could see and hold, and which the server then
	-- silently ignored, so it read as a broken control -- and also the bin
	-- next door, the collect prompt and the steal prompt. One service-level
	-- switch rather than a per-prompt filter, because the rule is about the
	-- PLAYER, not about which prompt they happen to be looking at.
	--
	-- Client-side because a ProximityPrompt is triggered client-side: turning
	-- it off here means the server never sees the press at all. The server
	-- refuses anyway -- see StealthService.isHidden -- for the client that was
	-- written to ignore this.
	ProximityPromptService.Enabled = snapshot.disguised ~= true
	frontUI.dirty = true
	renderStealth()
end)

-- ============================================================
-- RIDING: THE WALK CYCLE AND THE SKATE STANCE
-- ============================================================
--
-- Both of these have to happen on the client, and for the same underlying
-- reason: a character is network-owned by its own player, and animation state
-- -- which is what both of these fight -- is client-authoritative. A Stop()
-- or a joint Transform written on the server changes the server's copy of the
-- rig and never reaches anybody's screen.
--
-- So the server publishes and the clients apply, exactly as with the animated
-- skins and the moat. RideService disables the Animate script (which does
-- replicate, and stops any NEW animation starting) and sets a `RideYaw`
-- attribute on the character; the loop below stops the tracks already running
-- and turns the body.
--
-- It walks EVERY player, not just this one. The eleven other people on the
-- street have no RideState of their own to read, and a skateboarder who
-- stands sideways only on their own screen is worse than one who never turns.


-- THE STANCE TURNS THE ROOT, NOT A JOINT.
--
-- Turning the root joint is the tidier idea and it does not work. Two dead
-- ends, both measured on a live character rather than guessed:
--
--   * `C0` is READ ONLY on the `AnimationConstraint` that newer rigs use in
--     place of a `Motor6D` -- assigning it throws outright.
--   * `Transform` is writable and moves the SERVER's copy of the rig, but a
--     write from the client changes nothing on screen, at Heartbeat or bound
--     after RenderPriority.Character. It is a read-back of the animation
--     result, not an input to it.
--
-- What does hold is rotating the HumanoidRootPart with `AutoRotate` off:
-- measured at exactly +90 degrees, kept for as long as the loop ran. The
-- controls move the humanoid along a world vector that has nothing to do with
-- which way it faces, so travel is unaffected -- and because the root is
-- replicated, every other player sees the turn without any of this running on
-- their machine.
--
-- The board would turn with the root, so RideService counter-rotates the model
-- by the same angle when it welds it. Root faces travel plus the yaw; board
-- faces travel.
do
	-- Required in here rather than at the top of the file: ClientMain is one
	-- chunk against Luau's 200-local ceiling, and a `do` block's locals are
	-- released at its end where a top-level one is held for the whole script.
	local RideSound = require(ReplicatedStorage.Shared.RideSound)

	local STANCE = "RideStance"
	local accumulated = 0
	local bound = false
	local autoRotateWas: boolean? = nil
	local heading: Vector3? = nil
	-- The root's own CURRENT facing, eased toward wherever `heading` and the
	-- stance yaw point rather than snapped to it. Nil means "not turning
	-- yet", which is what makes the first frame after a mount instant instead
	-- of easing in from some stale angle nobody was ever actually facing.
	local currentAngle: number? = nil

	-- Wraps to (-pi, pi] so the eased step always takes the SHORT way round.
	-- Without this, turning from just past -170 degrees to just past +170 --
	-- five degrees apart the short way -- would ease the long way, through
	-- zero, taking most of a second to cover 350 degrees of nothing.
	local function wrapAngle(a: number): number
		a %= (2 * math.pi)
		if a > math.pi then
			a -= 2 * math.pi
		end
		return a
	end

	local function release()
		if bound then
			RunService:UnbindFromRenderStep(STANCE)
			bound = false
		end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and autoRotateWas ~= nil then
			humanoid.AutoRotate = autoRotateWas
		end
		autoRotateWas = nil
		heading = nil
		currentAngle = nil
	end

	local function hold(yaw: number)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not (humanoid and root) then
			return
		end

		if autoRotateWas == nil then
			autoRotateWas = humanoid.AutoRotate
		end
		humanoid.AutoRotate = false

		-- Bound after the character update, which is the step that would
		-- otherwise overwrite this within the same frame.
		if not bound then
			bound = true
			RunService:BindToRenderStep(STANCE, Enum.RenderPriority.Character.Value + 1,
				function(dt: number)
				local ch = player.Character
				local hum = ch and ch:FindFirstChildOfClass("Humanoid")
				local hrp = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not (hum and hrp) then
					return
				end
				-- Last non-zero direction, so standing still holds the stance
				-- instead of snapping back to whatever facing it had.
				local move = hum.MoveDirection
				if move.Magnitude > 0.05 then
					heading = move.Unit
				end
				local face = heading
				if not face then
					return
				end

				-- TARGET, NOT DESTINATION. `heading` itself is still a flat
				-- keyboard direction and still changes in a single frame --
				-- that is fine, it is only WHICH WAY the board should end up
				-- facing. What used to be wrong is that the root's actual
				-- CFrame was set straight to that target every frame, so a
				-- rider turned as fast as the keyboard did: instantly.
				--
				-- ToEulerAnglesYXZ returns THREE values and the yaw is the
				-- SECOND, not the first -- a call used as a lone argument
				-- expands every return into its own argument, so passing it
				-- straight into wrapAngle(...) would have silently taken the
				-- pitch instead. X and Z are both zero here (the CFrame being
				-- decomposed is a pure Y rotation), so there is no gimbal
				-- ambiguity to worry about.
				local _, targetY = (CFrame.lookAt(Vector3.zero, face).Rotation
					* CFrame.Angles(0, math.rad(yaw), 0)):ToEulerAnglesYXZ()
				local target = wrapAngle(targetY)

				if not currentAngle then
					-- Mounting (or a fresh bind) has nothing to ease FROM, so
					-- the first frame snaps -- the rider should not spend half
					-- a second turning onto a board they just stepped on.
					currentAngle = target
				else
					local step = math.rad(Config.RIDE_STANCE_TURN_RATE) * dt
					local delta = wrapAngle(target - currentAngle)
					currentAngle = currentAngle + math.clamp(delta, -step, step)
				end

				hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, currentAngle, 0)
			end)
		end
	end

	-- The lean runs EVERY FRAME, and the tracks it leans are only checked ten
	-- times a second. Two different jobs: which pose a rider should be in
	-- changes when they mount or dismount, and how far through a trick they
	-- are changes continuously -- so polling the second at 10Hz put the rider
	-- up to a tenth of a second behind their own bike. Nothing is created
	-- here, so this cannot race with the track bookkeeping below.
	--
	-- ON PreAnimation, AND THE STAGE IS THE WHOLE POINT -- the same trap the
	-- dodge dash hit from the other end. A weight set on Heartbeat lands
	-- AFTER the animation system has already evaluated this frame, so it
	-- shows up on the next one: measured as a one-frame sawtooth, the rider
	-- holding last frame's angle against the bike's current one and the hands
	-- swinging 0.57 studs off the grips and back every other frame. Read the
	-- machine and lean immediately before the poses are evaluated, and the
	-- two are the same frame by construction.
	local function leanEveryone(dt: number)
		for _, other in ipairs(Players:GetPlayers()) do
			local body = other.Character
			local style = body and body:GetAttribute("RideStyle")
			if type(style) == "string" and RidePose.has(style) then
				local humanoid = body:FindFirstChildOfClass("Humanoid")
				local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
				if animator then
					RidePose.setPhase(animator, style, RidePose.phaseOf(body, style))
				end
			end
			-- The rolling loop rides along with it: same walk, same reason
			-- it is per-frame, and it wants a rider's speed rather than a
			-- ride's angle. It takes no style -- it reads the mounted model
			-- itself -- so a ride with no pose still gets its sound.
			if body then
				RideSound.update(body, dt)
			end
		end
	end

	RunService.PreAnimation:Connect(leanEveryone)

	RunService.Heartbeat:Connect(function(dt)
		accumulated += dt
		if accumulated < 0.1 then
			return
		end
		accumulated = 0

		local character = player.Character
		local yaw = character and character:GetAttribute("RideYaw")
		if ridingNow and type(yaw) == "number" and yaw ~= 0 then
			hold(yaw)
		else
			release()
		end

		-- The walk cycle, on the character this client owns. Everyone else.s
		-- Animate script is disabled by the SERVER at mount, which replicates,
		-- so their legs stop without this running on their machine.
		--
		-- The ride pose is deliberately spared. It used to stop every track
		-- there was, which was right when there was nothing to keep -- now it
		-- would cancel the pose 0.1 seconds after it started, every tenth of a
		-- second, forever.
		if ridingNow then
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
			if animator then
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					if not string.match(track.Name, "^RidePose") then
						track:Stop(0.1)
					end
				end
			end
		end

		-- THE POSE, ON EVERY RIDER IN THE SERVER AND NOT JUST THIS ONE.
		--
		-- A pose is a hash:// animation registered on THIS peer, and a hash id
		-- cannot replicate -- so playing it on the rider's own machine would
		-- show nobody else anything. Each client walks the players it can see
		-- and poses them itself, from the `RideStyle` the server published: the
		-- same shape as the animated skins and the dodge roll.
		--
		-- It matters that other people see it. A ride is the most visible thing
		-- anyone owns, and being seen on it is the entire purchase.
		for _, other in ipairs(Players:GetPlayers()) do
			local body = other.Character
			local humanoid = body and body:FindFirstChildOfClass("Humanoid")
			local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
			if animator then
				local style = body:GetAttribute("RideStyle")
				if type(style) == "string" and RidePose.has(style) then
					-- Only WHICH tracks should be on them. How far through a
					-- trick they are is leanEveryone's job, off the ride's own
					-- rotation -- which is read from the character rather than
					-- from this client's button, so somebody else popping a
					-- wheelie down the street leans too.
					RidePose.apply(animator, style)
				else
					RidePose.clear(animator)
				end
				-- Builds the ride's own loop and mutes Roblox's footsteps,
				-- which otherwise has every rider on the street jogging --
				-- a ride is a WalkSpeed multiplier, so as far as the Humanoid
				-- is concerned they ARE running. Polled rather than hooked
				-- because the sounds are built by a Roblox LocalScript that
				-- this one does not get told about.
				RideSound.apply(body)
			end
		end
	end)
end

-- The trick button: hold for a manual on the board, a wheelie on the bike.
--
-- A BUTTON and not only a keybind, because most of this audience is on a
-- touchscreen -- the same reason mounting has no prompt and bones auto-target.
-- Held rather than toggled: a trick you hold is a thing you are doing, and a
-- toggle would leave players rolling around permanently nose-up having
-- forgotten they pressed it.
--
-- Shown only while riding something that HAS a trick, so it never appears
-- next to a scooter and does nothing.
--
-- IN THE DODGE BUTTON'S OWN SLOT, and matching it exactly.
--
-- The two can never both be live -- the dodge is refused outright while a ride
-- multiplier is set, and this button only exists while one is -- and they
-- already share the Q key for that reason. Two controls that are the same key,
-- doing the same job at the same moment, drawn in two different corners is a
-- worse lie than either of them alone: it reads as two buttons where there is
-- only ever one.
--
-- So it goes in the bottom-right list at the same LayoutOrder, at the same
-- size, and a UIListLayout skips invisible children -- which means whichever
-- of the pair is live occupies the identical patch of screen and the other
-- takes up no room at all. Nothing has to position anything.
-- The same pixels as the dodge, deliberately. The two are one control in two
-- states -- Q does whichever is live, and they are mutually exclusive by
-- construction -- so they sit at the identical position and size and only one
-- is ever visible. Drawn anywhere else they would read as two buttons where
-- there is only ever one.
local trickButton = makeActionButton("TrickButton", "TRICK", "MANUAL", "Q",
	Theme.COOL, UDim2.new(0, 68, 0, 68), 18, gui, true)
trickButton.AnchorPoint = Vector2.new(0, 1)
trickButton.Position = UDim2.new(0, 22, 1, -140)
require(ReplicatedStorage.Shared.HUDLayout).bindAction(trickButton, gui, 1)
trickButton.Visible = false

local trickHeld = false

local function setTrick(on: boolean)
	if on == trickHeld then
		return
	end
	trickHeld = on
	trickButton.BackgroundColor3 = if on
		then Theme.COOL
		else Theme.COOL
	Remotes.get("RideTrick"):FireServer(on)
end

-- ON InputBegan, NOT MouseButton1Down, because only this one says WHICH
-- touch: a thumb on the stick that slides over the button must not pop a
-- wheelie. See Shared/TouchOrigin.
trickButton.InputBegan:Connect(function(input)
	if (input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch)
		and not require(ReplicatedStorage.Shared.TouchOrigin).beganElsewhere(input, trickButton) then
		setTrick(true)
	end
end)
-- Released on leave as well as on up: a finger that slides off the button
-- never fires MouseButton1Up, and the board would stay up for good.
trickButton.MouseButton1Up:Connect(function()
	setTrick(false)
end)
trickButton.MouseLeave:Connect(function()
	setTrick(false)
end)

-- Q, THE SAME KEY AS THE DODGE, because the two can never both be live.
--
-- HeistService.dodge refuses outright while a ride multiplier is set -- you
-- do not roll off a moving scrambler -- so a rider pressing Q has exactly
-- one thing it could have meant. One key doing the one available thing is
-- fewer keys to teach, and this audience is nine.
--
-- What that costs, and what is paid for it below: the refusal is LOUD
-- ("Not while you're riding"), which is right for a key press that meant a
-- dodge and wrong for one that meant a manual. So the dodge is suppressed
-- CLIENT-SIDE while riding rather than fired and rejected -- the same shape
-- as the number keys, which do nothing for an item you do not hold instead
-- of firing a remote the server will only refuse. The server keeps the
-- authority; the client just stops asking for something it knows is a no.
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.Q and trickButton.Visible then
		setTrick(true)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Q then
		setTrick(false)
	end
end)

-- ============================================================
-- THE RIDE PICKER
-- ============================================================
-- Keep the visual controller in its own module and the existing remote
-- channels here. This avoids adding top-level locals to ClientMain.
local function buildGarage()
	local picker = require(ReplicatedStorage.Shared.RidePicker).new({
		gui = gui, shop = panel,
		requestRide = function(key: string) Remotes.get("RideRequest"):FireServer(key) end,
		requestStance = function(key: string, stance: string) Remotes.get("RideStance"):FireServer(key, stance) end,
		openStyles = function() panel.Visible = true; selectTab(SHOP.at.rides) end,
	})
	rideUI.renderGarage = function() picker:render(rideUI.latest) end
	rideUI.toggleGarage = function() picker:setOpen(not picker.open) end
end

buildGarage()

Remotes.get("RideState").OnClientEvent:Connect(function(snapshot)
	rideUI.latest = snapshot
	Rebirth.onRides(snapshot)
	frontUI.dirty = true
	ridingNow = snapshot.riding == true

	local trick = snapshot.trick
	trickButton.Visible = ridingNow and type(trick) == "string"

	-- AND THE SNEAK BUTTON GOES WITH IT, because the sneak does. A tiptoe and
	-- a ride are both multipliers on one speed and the server refuses the pair
	-- outright -- see `tiptoeInEffect` -- so a live-looking SNEAK on screen
	-- while a board is under you is a control that does nothing when pressed,
	-- which this project's own rule says reads as broken rather than as
	-- unavailable. Most of this audience never presses a key, so the button IS
	-- the sneak to them; C is suppressed in the same breath below.
	--
	-- FOUND BY NAME, holding no local, which is the call the tiptoe slot's own
	-- header already makes about this button: that block is wrapped in a `do`
	-- precisely because this chunk sits within a couple of registers of Luau's
	-- 200-local ceiling, and going over costs the WHOLE HUD.
	--
	-- ONE OWNER, UNLIKE THE DODGE. That button is driven from the Heartbeat
	-- because TWO states decide it -- riding and being in a bin -- and two
	-- handlers owning one property left it hidden after a player climbed out.
	-- Riding is the only thing that hides this one, so the ride push is the
	-- honest place for it and cannot drift out of step with itself.
	local sneakButton = gui:FindFirstChild("TiptoeButton") :: GuiObject?
	if sneakButton then
		sneakButton.Visible = not ridingNow
	end

	-- The dodge button goes away while riding, because the dodge does. It
	-- shares the key with the trick, and leaving a live-looking DODGE on
	-- screen while Q pops a manual is the touch half of the same confusion --
	-- worse, in fact, since most of this audience never presses a key at all.
	--
	-- The two stand in the SAME list slot, so this is a straight swap rather
	-- than one appearing while the other leaves a hole: the list skips
	-- whichever is hidden, and the survivor lands on the same pixels.
	-- dodgeButton visibility is owned by the Heartbeat above, which is the
	-- only place that sees BOTH the ride state and the bin state.

	if type(trick) == "string" then
		trickButton.Label.Text = string.upper(trick)
	end
	-- Whatever we were holding is void the moment the ride comes off, and the
	-- server has already dropped it -- clear the local flag or the next mount
	-- starts out thinking the button is still down.
	if not trickButton.Visible then
		trickHeld = false
	end

	renderRides()
	rideUI.renderGarage()
end)

shopToggle.Activated:Connect(function()
	panel.Visible = not panel.Visible
end)
closeButton.Activated:Connect(function()
	panel.Visible = false
end)
-- THE SHOP ALWAYS REOPENS ON ITS HOME PAGE. Reset on CLOSE rather than on
-- open, because a shop door, the bag's crate button and the ride styles pill
-- all open the panel and THEN pick a tab -- a reset on open would race them.
-- Watching the property covers every way the panel closes: the X, B, Escape
-- and the bag taking over the screen.
panel:GetPropertyChangedSignal("Visible"):Connect(function()
	if not panel.Visible then
		selectTab(1)
	end
end)

-- B opens the shop, Escape closes it. The button stays the primary route --
-- most of the audience is on a touchscreen and will never press a key.
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	-- Hidden in a bin: no dodge, no garage, no throwing anything, no hotbar.
	-- The shop and its Escape stay, because opening a menu is not acting on
	-- the world and trapping somebody in a panel they cannot close is worse
	-- than letting them browse from inside a bin.
	local boxed = stealthUI.latest ~= nil and stealthUI.latest.disguised == true

	if input.KeyCode == Enum.KeyCode.B then
		panel.Visible = not panel.Visible
	elseif input.KeyCode == Enum.KeyCode.Escape and panel.Visible then
		panel.Visible = false
	elseif input.KeyCode == Enum.KeyCode.Escape and gui:GetAttribute("SettingsOpen") then
		-- Escape closes whichever menu is open, and settings is a menu. The
		-- two can no longer both be open, so the order of these two branches
		-- decides nothing -- it is written this way round because the shop is
		-- the one a player is in far more often.
		gui:SetAttribute("SettingsOpen", false)
	elseif boxed then
		-- Every other binding is suppressed rather than fired and refused:
		-- the server's refusals are the loud kind, and a player who pressed a
		-- key the HUD is not currently offering should hear nothing at all.
		return
	elseif input.KeyCode == Enum.KeyCode.Q then
		-- Shared with the trick. See the note by trickButton: the two states
		-- are mutually exclusive, and the server would refuse this one with a
		-- toast that would fire on every manual.
		if not ridingNow then
			requestDodge()
		end
	elseif input.KeyCode == Enum.KeyCode.C then
		-- TIPTOE. C is the crouch key everywhere else on this platform, and it
		-- was free: the map is Q dodge/trick, B shop, V garage, R radio, I
		-- bag, Escape close, F2 admin, and 1-0 the hot bar.
		--
		-- A TOGGLE RATHER THAN A HOLD. Most of this audience is on a tablet
		-- and a hold is a thumb they cannot spare while also steering; a
		-- toggle is one tap either way and survives a finger slipping.
		--
		-- The client only ASKS. Whether a sneak is allowed is the server's --
		-- it refuses one while you are carrying, and drops it out from under
		-- you the moment you grab a pig -- so the button's state comes back on
		-- `TiptoeState` rather than being assumed here.
		--
		-- The current state rides an ATTRIBUTE ON THE ScreenGui rather than a
		-- local, which is the register budget again -- the same call the bag
		-- panel's `BagOpen` flag makes. This chunk has no top-level register
		-- spare, an attribute costs none, is readable from anywhere, and
		-- cannot go stale the way a second copy of the state would.
		--
		-- NOT WHILE RIDING, which is the dodge's own suppression two branches
		-- up applied to the other shared-with-a-ride control. The server
		-- refuses a sneak under a ride and refuses it LOUDLY, so firing this
		-- would toast "Not while you're riding." at somebody who pressed the
		-- crouch key on a board -- the same noise that argument spared the
		-- dodge. The SNEAK button is hidden for the same reason, up in the
		-- RideState handler.
		if not ridingNow then
			Remotes.get("TiptoeRequest"):FireServer(gui:GetAttribute("Tiptoe") ~= true)
		end
	elseif input.KeyCode == Enum.KeyCode.V then
		-- The garage fan-out. V for vehicle, and free: Q is the dodge and the
		-- trick, B opens the shop, and the number row is the item bar.
		--
		-- G IS FREE AGAIN. It threw the cheapest bone held, which was a second
		-- route to using an item and a special case for exactly one of the four
		-- catalogues -- so bones were the only things on that bar with a
		-- shortcut, and the one purchase message in the game that taught a
		-- control was teaching that. Every item is now reached the same way:
		-- its own number, then a click.
		rideUI.toggleGarage()
	else
		-- One fixed key per item, driven from the PUSHED state and never from
		-- an assumed stock: pressing a number for something you do not hold has
		-- to do nothing, rather than fire a remote the server will only reject.
		-- ASKED, not searched. The bar owns which item a number means, because
		-- the player can drag tiles and the key follows the slot -- so a map
		-- iterated here would have to be kept in step with an arrangement it
		-- does not own.
		--
		-- THE "DO NOTHING" HALF IS ENFORCED IN `itemForKey`, NOT HERE, and it
		-- was missing for a long time: this branch fired for an empty slot, so
		-- pressing its number named the item over the bar AND asked the server
		-- to draw one, which refused by name. Two messages about something you
		-- do not have, from a tile that is not on screen. Nothing below needs
		-- a stock test now, because a nil key already means "not yours to
		-- press" rather than only "past the end of the row".
		local key = HotBar.itemForKey(input.KeyCode)
		if key then
			-- Named on press, because a touch player never hovers anything and
			-- would otherwise never learn which tile is which.
			HotBar.hint(key, true)
			-- DRAWS IT. The four-way dispatch that used to live here moved to
			-- `heldUI.use`, because the number row no longer decides what
			-- happens -- it decides what is in your hand, and the click that
			-- follows is the one that has to know which service owns the key.
			heldUI.equip(key)
		end
	end
end)

-- USING WHAT IS IN YOUR HAND.
--
-- The dispatch that used to sit in the number-key branch, moved here whole.
-- It routes on which pushed catalogue the key appears in, exactly as before;
-- what it no longer tests is whether the stock is above zero, because being
-- ABLE to hold something already means holding one -- the server refuses an
-- empty draw and `HeldItemService.revalidate` puts the last one away as it is
-- spent. The equipped key IS the check the `held > 0` test used to be.
--
-- IT SENDS NO POSITION, and that is the load-bearing half of moving to a
-- click. A click is an obvious place to start sending one, and every remote
-- here would then have a coordinate on it to forge and a range check to
-- defeat. The server still picks the dog from its own positions and the
-- gadget target from its own search; the click means "use it", never "use it
-- there".
function heldUI.use()
	local key = heldUI.key
	if not key or panel.Visible or dailyOpen or gui:GetAttribute("BagOpen") then
		return
	end
	if latestBones and latestBones[key] then
		throwBone(key)
	elseif gadgetUI.latest and gadgetUI.latest[key] then
		throwGadget(key)
	elseif homeUI.latest and homeUI.latest.items and homeUI.latest.items[key] then
		Remotes.get("HomeUse"):FireServer(key)
	elseif stealthUI.latest and stealthUI.latest.items and stealthUI.latest.items[key] then
		Remotes.get("StealthUse"):FireServer(key)
	end
end

-- WHAT THE SERVER SAYS WE ARE HOLDING, which is the only thing the HUD
-- believes. Never set from the press: a draw can be refused -- no stock,
-- riding, hiding -- and a bar that lit its own tile would show an item in a
-- hand that was told no.
--
-- Re-read on every new character as well as watched, because a respawn hands
-- out a fresh Model with no attribute on it and the old one's signal dies
-- with it. Connected for the character we may ALREADY have, which is the
-- shape of bug the wheelie bins shipped: a CharacterAdded hook alone never
-- fires for a player who was here before the handler was.
function heldUI.watch(character: Model)
	local function sync()
		local was = heldUI.key
		heldUI.key = character:GetAttribute(heldUI.attribute) :: string?
		HotBar.setEquipped(heldUI.key)
		-- AN EMPTY HAND TAKES THE NAME WITH IT, whatever emptied it. The press
		-- path already knows a put-away from a draw, but a hand can also be
		-- emptied by things no press can see: the last one spent, mounting a
		-- ride, climbing into a bin, or the server refusing a draw outright.
		-- Clearing here covers all of them with one line.
		if was and not heldUI.key then
			HotBar.hint(nil)
		end
	end
	character:GetAttributeChangedSignal(heldUI.attribute):Connect(sync)
	sync()
end

if player.Character then
	heldUI.watch(player.Character)
end
player.CharacterAdded:Connect(heldUI.watch)

-- A CLICK USES IT, AND A CAMERA SWING DOES NOT.
--
-- `processed` is what keeps a tap on the bar itself from also throwing the
-- thing it just selected -- the same job `HotBar.suppress` does one layer up,
-- from the other side.
--
-- Touch needs the extra half. A mouse click is a click, but every camera
-- swing on a tablet begins exactly like a tap, so a touch is only a use if it
-- LANDS near where it went down. Twelve pixels is about a fingertip's own
-- wobble -- the same slop the hot bar's own drag threshold uses, and for the
-- same reason.
-- A GADGET IS THROWN ON THE WAY UP. Press draws the arm back and holds it
-- (Shared/ThrowAim), release throws. Every other held item still fires on
-- the press. `ThrowAim.press` answers whether a gadget was in hand, so this
-- file never has to know which catalogue a key belongs to. The shop, the
-- daily board and the bag block a press exactly as they block a use.
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local blocked = panel.Visible or dailyOpen or gui:GetAttribute("BagOpen")
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		heldUI.gadgetDown = not blocked and require(ReplicatedStorage.Shared.ThrowAim).press(true)
		if not heldUI.gadgetDown then
			heldUI.use()
		end
	elseif input.UserInputType == Enum.UserInputType.Touch then
		heldUI.tapFrom = Vector2.new(input.Position.X, input.Position.Y)
		heldUI.gadgetDown = not blocked and require(ReplicatedStorage.Shared.ThrowAim).press(false)
	end
end)

UserInputService.InputEnded:Connect(function(input, processed)
	local ThrowAim = require(ReplicatedStorage.Shared.ThrowAim)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		-- Always honoured, even over the HUD: the pointer is locked while the
		-- arm is back, and a release lost to `processed` would leave it back.
		if heldUI.gadgetDown then
			heldUI.gadgetDown = false
			ThrowAim.release(false)
		end
		return
	end
	if input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	-- Cleared whether or not this one counts, so a swipe that started on the
	-- world and ended over the HUD cannot leave a stale origin for the next
	-- touch to be measured against.
	local from = heldUI.tapFrom
	heldUI.tapFrom = nil
	local to = Vector2.new(input.Position.X, input.Position.Y)
	if heldUI.gadgetDown then
		heldUI.gadgetDown = false
		-- A long press may have dragged the camera to aim; a short one that
		-- moved was a swipe. ThrowAim owns that rule.
		ThrowAim.release(from == nil or ThrowAim.isSwipe(from, to))
		return
	end
	if processed or not from then
		return
	end
	if (to - from).Magnitude <= 12 then
		heldUI.use()
	end
end)

-- EVERY INTERACTION PROMPT IN THE GAME, drawn by one module.
--
-- Required inline and never stored: this chunk is against Luau's 200-register
-- ceiling, and a feature that needs nothing back from its module should not
-- spend a local saying so.
require(ReplicatedStorage.Shared.PromptUI).start()

-- THE SHOP DOORS ON THE SQUARE.
--
-- PUSHED, NOT FOUND, and the first version tried to find them. It collected
-- the doors by CollectionService tag and wired nothing: measured at "wired 0
-- doors at startup", because they had not replicated yet and
-- `GetInstanceAddedSignal` does not fire for an instance that arrives already
-- carrying its tag. The full write-up is in `ShopFront`; the short version is
-- that anything built during SERVER STARTUP has to be pushed to a client,
-- and only things built later (the moat) can be found by tag.
--
-- The door sends the tab as a NAME and this maps it to an index, because the
-- ordering of the rail is a fact about this file: a number sent from
-- NeighborhoodService would point at the wrong shop the first time a tab was
-- inserted, silently.
do
	-- FOUND BY VIEW NAME, NOT BY TITLE, AND THIS BROKE ONCE ALREADY.
	--
	-- It matched on the tab's display TITLE -- "Your Piggy", "Your Home",
	-- "Your Gear", "Defend / Rob" -- which was chosen over a bare index
	-- because an index goes wrong the moment anybody inserts a tab. That was
	-- the right instinct aimed at the wrong half: an index survives a rename
	-- and dies on a reorder, a title survives a reorder and dies on a RENAME,
	-- and the shop was then reworked from four tabs to seven with every one of
	-- those four titles rewritten. `BY_TAB` came out EMPTY, every door lookup
	-- returned nil, and the handler's own early return swallowed it -- so all
	-- four shop doors on the street did nothing at all when pressed, with the
	-- prompt still appearing and the remote still arriving.
	--
	-- A view's NAME is neither a display string nor a position: it is a code
	-- identifier that only a code change can move, and a code change to it is
	-- visible in the same file as this table. That is the thing to key on.
	--
	-- Declared inside a `do` block because ClientMain is one chunk against
	-- Luau's 200-register ceiling and a block gives its slots back at the end.
	-- PIGGY OUTFITTERS OPENS THE CRATES TAB, and that is a repoint rather
	-- than a rename. `Config.SHOPS` keys a unit's style, its window display
	-- and its fascia off `tab`, so the boutique is `piggy` over there and has
	-- to stay `piggy` -- what changed is where its door LANDS. It sold skins;
	-- skins come out of crates now, so the shop that is about dressing a pig
	-- opens the one tab that can still hand one over.
	--
	-- Caught by the warning below rather than by pressing the door, which is
	-- the entire reason that warning is loud: the tab this used to name went
	-- with the skins, and a silent nil here is four doors doing nothing.
	local WANTED: { [string]: string } = {
		piggy = "CratesView", home = "HomeView",
		gear = "GearView", defend = "UpgradesView",
	}
	local BY_TAB: { [string]: number } = {}
	for key, viewName in pairs(WANTED) do
		for i, tab in ipairs(tabs) do
			if tab.view.Name == viewName then
				BY_TAB[key] = i
			end
		end
		-- LOUD, because the whole cost of the last failure was its silence.
		-- Four doors stopped working and nothing anywhere said so.
		if not BY_TAB[key] then
			warn(("[ClientMain] shop door '%s' wants view '%s', which no tab has. "):format(key, viewName)
				.. "That door will do nothing when pressed.")
		end
	end

	Remotes.get("ShopDoor").OnClientEvent:Connect(function(tab)
		local index = BY_TAB[tab]
		if not index then
			warn(("[ClientMain] a shop door asked for tab '%s' and nothing maps to it."):format(tostring(tab)))
			return
		end
		panel.Visible = true
		selectTab(index)
	end)
end

-- Rebirth button. Hidden entirely until you can afford it -- a permanently
-- greyed-out button you can't use for three hours is just a nag.
-- The rebirth button is a HUD overlay pinned near the top of the screen,
-- which is exactly where the shop panel's own header and first row sit. It
-- was covering the roll button outright. Whether it is affordable is the
-- module's business; whether anything is covering it is ours.
Rebirth.canShow = function(): boolean
	return not panel.Visible and not dailyOpen and not gui:GetAttribute("BagOpen")
end
-- `makeModelIcon` is handed over rather than reimplemented: the unlock band
-- renders real piggies now, and the framing, tilt and visual-centre rules
-- that make an icon read are already solved in one place.
Rebirth.init(gui, function()
	Remotes.get("RebirthRequest"):FireServer()
end, makeModelIcon)

-- Watched rather than called from the three places that toggle the panel --
-- the button, the close X, and the B/Escape keybind, all of which are defined
-- above this point and could not call it anyway. Watching the property also
-- covers anything that opens the panel later without knowing about this.
panel:GetPropertyChangedSignal("Visible"):Connect(Rebirth.sync)
-- The bar reads panel.Visible through shouldShow, so it has to be asked again
-- when that changes -- otherwise it only notices the next time a stock does.
panel:GetPropertyChangedSignal("Visible"):Connect(HotBar.refresh)

-- Friend bonus chip, only shown when it's actually earning you something.
local friendChip = Instance.new("TextLabel")
friendChip.Size = UDim2.new(0, 150, 0, 30)
friendChip.Position = UDim2.new(0, 18, 0, 18)
friendChip.TextScaled = true
friendChip.Text = ""
friendChip.Visible = false
friendChip.Parent = gui
Theme.tinted(friendChip, Theme.GOOD, Theme.GOOD, 10)
Theme.title(friendChip, 16, Theme.INK)

-- Carry banner. Only visible while holding stolen loot, and deliberately
-- loud -- a thief should feel exposed, because they are.
--
-- IT IS A `Shared/Announce` BANNER NOW, like the patrol's and the event's.
-- All three were built five hundred lines apart and had drifted into three
-- different objects in one column: this one 52 tall with gold type on its own
-- deep red, the patrol's 38 tall with ink on a saturated ground, the event's
-- 44 with a badge and a groove. One widget, one shape, and the tone is what
-- says which announcement it is.
--
-- WHAT THE MOVE SPENDS is the hand-solved red this carried: "THE ONE BANNER
-- THAT STAYS ITS OWN COLOUR", at (162, 36, 32), chosen because gold numerals
-- on a brighter red measured 2.40 and reached 4.77 there. That whole
-- measurement was about GOLD ON RED, and the type is white on a deepened
-- ground now -- `Theme.STOP` at 62% toward ink is (111, 48, 44), a shade off
-- the old gradient's own second stop, carrying PAPER at 9.11. So it is still
-- an alarm going off around the player rather than a label, and the pairing
-- it was solved for no longer exists.
local carryBanner = Announce.new(gui, "CarryBanner", 140)

-- ============================================================
-- BEHAVIOUR
-- ============================================================

local function renderUpgrades()
	if SHOP.upgrades then SHOP.upgrades:setUpgrades(latestUpgrades) end
	for key, info in pairs(if SHOP.upgrades then {} else latestUpgrades) do
		local row = ensureRow(key, info)
		-- The name alone. The level used to be appended here and is now the
		-- ladder underneath, which says the same thing without being read.
		row.title.Text = info.name
		-- Re-set every render: the dog's blurb names its next breed, so it
		-- changes with the level rather than being fixed at row creation.
		row.blurb.Text = info.blurb

		-- Pips, not a bar: a tree is four or five rungs, which is a thing you
		-- can count at a glance. See paintLadder for why the two EARN rows ask
		-- for the other kind.
		paintLadder(row, info.level, info.max, false)

		if info.level >= info.max then
			row.cost.Text = "MAXED"
			row.cost.TextColor3 = ShopStyle.GOOD
			row.button.BackgroundColor3 = ShopStyle.CARD
		else
			row.cost.Text = format(info.cost)
			local affordable = latestCoins >= info.cost
			row.cost.TextColor3 = if affordable then GOLD else Theme.MUTED_LIGHT
			-- Affordability is on the PILL, not the whole card. Tinting the
			-- card green fought the tree colour on its own outline, which is
			-- the one thing telling DEFEND from ROB now the stripe is gone.
			row.button.BackgroundColor3 = ShopStyle.CARD
		end
	end
	panelCoins.Text = format(latestCoins)
	renderCosmetics()
	renderBones()
	renderGadgets()
	renderHome()
	renderStealth()
	renderRides()
	-- latestCoins lands in this function's caller, and it is what decides
	-- whether a shelf says "3 you can buy now".
	frontUI.dirty = true
end

local function render(state: any)
	-- ONE BALANCE, ONE READOUT. The pig is the wallet and it has no ceiling,
	-- so the panel is the figure and nothing else.
	bankHUD:render(state)
	latestCoins = state.coins
	-- The steal and smash cards used to be handed this player's own coins and
	-- capacity, to cap the take they quote. They print `Config.homeWorth`
	-- now, which is about the TARGET and has no reader in it, so the two
	-- fields went with the cap rather than being left to go stale.
	-- Forward-declared; a push can land before the prompt code is defined.
	if refreshStealPrompts then
		refreshStealPrompts()
	end
	renderUpgrades()
	-- NO CRATE HAS A PRICE, so there is no buy state to repaint against a
	-- balance. The cards are built once and the tab is a browse surface.

	-- The EARN row in the Upgrades tab. It is painted from HERE and not from
	-- renderUpgrades, because its level, ceiling and price ride the economy
	-- push rather than the upgrade snapshot -- and the ceiling is the reason
	-- that matters: `maxIncome` grows with every rebirth, so the bar's own
	-- length is state rather than a constant.
	if SHOP.upgrades then
		SHOP.upgrades:setEconomy(state)
		SHOP.shell:setBalances(state.coins)
		require(ReplicatedStorage.Shared.Inventory).setBalances(state.coins)
	else
		paintEarn(earn.rows.income, state.incomeLevel, state.maxIncome, state.incomeCost, state.coins)
	end

	-- Coins, piggy bank, both upgrade levels and the rebirth count all go
	-- across: the page is built out of what the player actually has, and this
	-- is the push that knows it.
	Rebirth.onEconomy(state)

	local bonus = state.friendBonus or 0
	friendChip.Visible = bonus > 0
	if bonus > 0 then
		friendChip.Text = ("Friends  +%d%%"):format(math.floor(bonus * 100))
	end

end

Remotes.get("StateUpdate").OnClientEvent:Connect(render)

Remotes.get("UpgradeState").OnClientEvent:Connect(function(snapshot)
	latestUpgrades = snapshot
	Rebirth.onUpgrades(snapshot)
	renderUpgrades()
end)

-- Revenge marker. Built client-side from a server ping so only the victim
-- sees it -- everyone else watching a red beacon over one plot would turn a
-- private grudge into a public pile-on.
local activeRevenge: BillboardGui? = nil

Remotes.get("RevengeMarker").OnClientEvent:Connect(function(plotModel: Model, thiefName: string, duration: number)
	if activeRevenge then
		activeRevenge:Destroy()
		activeRevenge = nil
	end
	if not plotModel or not plotModel.PrimaryPart then
		return
	end

	local marker = Instance.new("BillboardGui")
	marker.Name = "RevengeMarker"
	marker.Size = UDim2.new(0, 220, 0, 60)
	marker.StudsOffset = Vector3.new(0, 26, 0)
	marker.AlwaysOnTop = true
	marker.Adornee = plotModel.PrimaryPart
	marker.Parent = playerGui

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Theme.STOP_INK
	text.TextStrokeTransparency = 0.15
	text.Text = ("%s ROBBED YOU\nGET THEM BACK"):format(thiefName)
	text.Parent = marker

	activeRevenge = marker

	task.delay(duration, function()
		if activeRevenge == marker then
			marker:Destroy()
			activeRevenge = nil
		end
	end)
end)

Remotes.get("CarryUpdate").OnClientEvent:Connect(function(amount: number, haul: any,
	_inRange: boolean?, kind: string?, _worth: number?, _ownBasket: boolean?, options: any?)
	local view = require(ReplicatedStorage.Shared.CarryDelivery).describe(amount, haul, kind, options)
	-- The destination card replaces this banner, avoiding overlap on phones.
	--
	-- SPLIT ACROSS THE TWO LINES rather than joined with a middot, which is
	-- what let the type get big: "CARRYING 999.9K · TAKE YOUR HAUL HOME!" is
	-- 478px at 26px against a 296px column, so one line would have silently
	-- shrunk to about 16. The haul is the headline and the instruction is the
	-- line under it, and both fit at full size -- 190 and 175.
	if view.visible and options == nil then
		local row = Config.announce("carry")
		carryBanner:set({
			tone = row and row.tone,
			glyph = row and row.glyph,
			image = row and row.icon,
			headline = ("CARRYING %s"):format(format(amount)),
			subline = view.banner,
		})
	else
		carryBanner:set(nil)
	end
	-- The steal prompts change meaning the instant loot is in hand: you cannot
	-- rob anybody while carrying, so every one of them stops quoting a take
	-- and starts naming the haul instead.
	stealInfo.carrying = if view.visible then math.max(1, amount) else 0
	if refreshStealPrompts then
		refreshStealPrompts()
	end
end)

-- ============================================================
-- PROMPT VISIBILITY
-- ============================================================
--
-- Each piggy carries a "Steal Coins" prompt, enabled for everybody but the
-- owner. There is no collect prompt since the pivot: the pig is the wallet
-- and nothing is banked. Doing this on the client is purely presentational --
-- the server re-checks ownership on every trigger, so an exploiter
-- re-enabling the prompt on their own piggy gets nothing.

local boundPlots: { { model: Instance, steal: ProximityPrompt, smash: ProximityPrompt } } = {}

-- Re-times our own steal prompts so the bar we watch matches the time we
-- actually need: the owner's locks against our lockpicks.
--
-- Both values are read fresh -- the lock level from the plot's replicated
-- attribute, our lockpicks from the last UpgradeState -- and the duration is
-- recomputed from scratch. Nothing is cached, so a lock bought mid-session
-- lands immediately instead of being overwritten by a stale local baseline.
--
-- This is presentation only. The server times the real hold and rejects
-- anything faster than we're entitled to, so tampering here only ever costs
-- the client.
function refreshStealPrompts()
	for _, entry in ipairs(boundPlots) do
		local lockLevel = entry.model:GetAttribute(Config.PLOT_LOCK_ATTRIBUTE) or 0
		-- A FLAT HALF SECOND, AND NO LONGER A NUMBER WORTH PRINTING.
		--
		-- What used to be here re-timed the ring against the victim's Vault
		-- Lock and this player's own Lockpicks, and printed the result on the
		-- prompt -- because the hold WAS the mechanic and a prompt animates
		-- its ring over whatever duration it is given, so three seconds and
		-- nine looked identical and the whole axis read as decorative.
		--
		-- Both trees still pull on that axis; they pull on the crack's ZONE
		-- WIDTHS now (Config.getCrackWindow), which is drawn as a target you
		-- can see rather than as a duration you have to be told. So this hold
		-- is a doorknob and the lock level goes on the label instead.
		entry.steal.HoldDuration = Config.CRACK.openHold
		entry.steal.ActionText = "Crack Lock"
		-- THE NOUN IS THE PLOT'S, NOT THIS FUNCTION'S. A shop's money is a
		-- strongroom, and "Unlocked Piggy" over one is the last place in the
		-- game still insisting the noun had not changed. The lock LADDER is
		-- shared -- it is the same four tiers on the same dial -- so only the
		-- unlocked wording differs.
		entry.steal.ObjectText = if lockLevel > 0
			then ("Vault Lock Lv%d"):format(lockLevel)
			else ("Unlocked %s"):format(entry.noun)

		-- WHAT IS IN IT, WHICH USED TO BE WHAT YOU WOULD TAKE.
		--
		-- The old figure was the one flat take, computed here over the same
		-- Config function the server used, and it was worth printing because
		-- a take was a CONSTANT. It is a decision now: five slices running
		-- 2% to 7.7% of the pig, any prefix of which the thief may walk away
		-- with. There is no single number left that is both true and useful
		-- -- the first slice under-sells the pig by a factor of ten, and a
		-- clean-run total is a promise the loss cap may refuse.
		--
		-- So the prompt says what the pile in front of them holds and the
		-- crack panel does the rest, which is where the decision now actually
		-- happens. That deliberately makes this the same figure the rob badge
		-- shows from the pavement: two readouts of one true thing at two
		-- distances, rather than two numbers a player has to reconcile.
		--
		-- Presentation only. The server re-derives every slice as it is
		-- landed and never reads a word of this.
		if stealInfo.carrying > 0 then
			-- You cannot rob anybody while carrying -- attemptSteal refuses
			-- with "take it home first". The prompt used to look completely
			-- available and then spend a hold finding that out, so it says so
			-- up front and names the haul it is protecting.
			entry.steal.ObjectText = ("Holding %s %s run home"):format(format(stealInfo.carrying), GLYPH.dot)
			entry.steal:SetAttribute(Config.PROMPT_AMOUNT_ATTRIBUTE, "")
		else
			local vault = math.floor(entry.model:GetAttribute(Config.PLOT_VAULT_ATTRIBUTE) or 0)
			-- WHAT A CLEAN CRACK CARRIES HOME -- the same figure the rob badge
			-- prints, through the same function, so the card and the badge
			-- cannot disagree. An empty piggy is refused outright, so saying so
			-- saves a hold that was always going to end in a rejection toast.
			--
			-- NO LONGER CAPPED AT THIS PLAYER'S OWN ROOM, and no longer says
			-- FULL. See Config.homeWorth: that cap made a card about somebody
			-- else's pig report a fact about yours, on all eight of them at
			-- once. The piggy panel carries "you have no room" now.
			local sack = (latestUpgrades.sack and latestUpgrades.sack.level) or 0
			local home = Config.homeWorth(vault,
				Config.getCrackFraction(Config.CRACK.maxSteps, sack))
			entry.steal:SetAttribute(Config.PROMPT_AMOUNT_ATTRIBUTE,
				if vault <= 0 then "EMPTY" else ("~%s"):format(format(home)))
		end

		-- THE OTHER CARD, AND IT PRINTS A DIFFERENT KIND OF NUMBER.
		--
		-- The steal card gives up on quoting a take, and the comment above says
		-- why: a crack is five slices any prefix of which the thief may walk
		-- away with, so there is no single figure that is both true and useful.
		-- A SMASH HAS ONE. It is a fixed fraction of the pile, it cannot be
		-- missed, and it is the same expression the server runs -- so the two
		-- cards side by side read as WHAT IS IN THERE against WHAT I WOULD GET,
		-- which is exactly the comparison the choice is made on.
		--
		-- Still a "~", for the reason the pile's own figure carries one: the pig
		-- accrues while the hold runs, so the real take is a beat larger.
		-- Under-stating is the safe direction and the tilde is what stops it
		-- reading as a promise.
		--
		-- Presentation only. `HeistService.smash` recomputes all of it.
		entry.smash.HoldDuration = Config.SMASH.hold
		entry.smash.ActionText = "Smash It"
		if stealInfo.carrying > 0 then
			entry.smash.ObjectText = ("Holding %s %s run home"):format(format(stealInfo.carrying), GLYPH.dot)
			entry.smash:SetAttribute(Config.PROMPT_AMOUNT_ATTRIBUTE, "")
		else
			-- BOTH HALVES OF THE TRADE, AND IT WAS MEASURED RATHER THAN
			-- WRITTEN. The cost is the alarm and the advantage is that no lock
			-- applies, and a thief choosing between two red cards needs both --
			-- the one beside this is naming a Vault Lock tier this one ignores.
			--
			-- IT SHIPPED AS "Loud . sets the alarm off" FOR ONE SESSION AND WAS
			-- TRUNCATED ON SCREEN, which no property read could have caught:
			-- `TextTruncate.AtEnd` HIDES an overflow rather than reporting it, so
			-- the label read back perfectly while the card showed "Loud . sets
			-- the...". Only a photograph said so. Measured after: the detail row
			-- is 172px of a 250 card and the amount box beside it takes 64, so a
			-- line printed WITH an amount has 108 -- against 141 for the original
			-- and 85 for this. "Sets the alarm off" also fits, at 103, and is the
			-- kind of five-pixel margin this project already records as reporting
			-- `TextFits` true while sitting on the frame edge.
			--
			-- 85 puts it alongside the STEAL card's own "Vault Lock Lv4" at 83,
			-- which is the line it is read against.
			entry.smash.ObjectText = ("Alarm %s no lock"):format(GLYPH.dot)
			local vault = math.floor(entry.model:GetAttribute(Config.PLOT_VAULT_ATTRIBUTE) or 0)
			local sack = (latestUpgrades.sack and latestUpgrades.sack.level) or 0
			-- Like the badge, what that take banks AT HOME -- paid out, and
			-- NOT capped at this player's own room. See the steal card above
			-- and RobBadge.describe for why that cap came off.
			local home = Config.homeWorth(vault, Config.getSmashFraction(sack))
			entry.smash:SetAttribute(Config.PROMPT_AMOUNT_ATTRIBUTE,
				if home <= 0 then "EMPTY" else ("~%s"):format(format(home)))
		end
	end
end

local function bindPlot(plotModel: Instance)
	-- A PLOT'S MONEY IS A PIGGY BANK OR A SHOP VAULT, AND THIS MUST NOT CARE
	-- WHICH. It waited on `PiggyBank` by name, so every shop vault waited ten
	-- seconds for a child that was never coming and left its steal prompt off
	-- forever -- four robbable targets nobody could press, with nothing
	-- anywhere to say so. `Config.waitForPlotBank` is the one place that
	-- knows both names.
	local piggy = Config.waitForPlotBank(plotModel, 10)
	if not piggy then
		return
	end
	local body = piggy:WaitForChild("Body", 10) :: BasePart?
	if not body then
		return
	end

	local stealPrompt = body:WaitForChild("StealPrompt", 10) :: ProximityPrompt
	-- THE SECOND WAY IN, ON THE SAME BODY. Both are live at once for a thief:
	-- the pair IS the feature, and a choice you cannot see is not a choice.
	-- They do not collide on screen because the smash carries
	-- `Config.PROMPT_SLOT_ATTRIBUTE`, which is what taught `PromptUI` to draw
	-- a second card at all.
	local smashPrompt = body:WaitForChild("SmashPrompt", 10) :: ProximityPrompt
	-- THERE IS A THIRD PROMPT ON THIS BODY -- the till's owner-only
	-- `CollectPrompt` (piggy collection Phase 1, plan §4a) -- and it is
	-- DELIBERATELY NOT BOUND HERE. It carries `PROMPT_OWNER_ATTRIBUTE`, and
	-- `PromptUI` already watches every prompt in the world for that and
	-- refuses the ones that are not the reader's. See the note in `refresh`
	-- below for what binding it here cost.

	local function refresh()
		local ownerId = plotModel:GetAttribute("OwnerUserId")
		local isMine = ownerId == player.UserId
		local isOwned = ownerId ~= nil
		-- A plot nobody lives on has a RESIDENT on it, and a resident is
		-- robbable. Without this the prompt stayed off for every unclaimed
		-- plot and the whole neighbour system was inert -- the test used to
		-- be `isOwned`, which is a question about PLAYERS rather than about
		-- whether there is anything in that pig.
		local hasResident = plotModel:GetAttribute(Config.PLOT_RESIDENT_ATTRIBUTE) ~= nil

		-- ONE RULE, BOTH PROMPTS. They are two ways into the same pig, so
		-- anything that makes one available makes the other available -- and
		-- deriving them separately would be two answers to one question, with
		-- the wrong one showing on somebody's own lawn.
		local robbable = (isOwned and not isMine) or (not isOwned and hasResident)
		stealPrompt.Enabled = robbable
		smashPrompt.Enabled = robbable
		-- THERE IS NO COLLECT PROMPT TO TOUCH ANY MORE, and the two things
		-- that used to be wrong here are both worth keeping.
		--
		-- This line read `collectPrompt.Enabled = isMine`, which looks like
		-- the exact inverse of the two above and is a SECOND WRITER -- the bug
		-- `PromptUI.ownerRule` records in full: the server turns a prompt off
		-- when there is nothing to do with it, and a client rule written as
		-- `Enabled = (owner == me)` switches it straight back on. Measured
		-- once already on the mailbox, where the flag lay flat over a live
		-- prompt.
		--
		-- Then collecting stopped being a prompt at all: the till and all six
		-- pedestals carry a flat PAD on the grass that the owner walks over,
		-- guarded on the server where the guard belongs. So there is nothing
		-- on this side to enable, refuse or get out of step -- which is the
		-- quiet second win of the conversion.
	end

	plotModel:GetAttributeChangedSignal("OwnerUserId"):Connect(refresh)
	plotModel:GetAttributeChangedSignal(Config.PLOT_RESIDENT_ATTRIBUTE):Connect(refresh)
	refresh()

	table.insert(boundPlots, {
		model = plotModel,
		steal = stealPrompt,
		smash = smashPrompt,
		-- Read off which of the two models was found rather than from a
		-- second attribute: `Config.waitForPlotBank` already had to know, and
		-- a flag published beside it would be a second answer that can go
		-- stale.
		noun = if piggy.Name == "ShopVault" then "Vault" else "Piggy",
	})
	plotModel:GetAttributeChangedSignal(Config.PLOT_LOCK_ATTRIBUTE):Connect(refreshStealPrompts)
	-- The pile fills every second, so the quoted take has to follow it.
	plotModel:GetAttributeChangedSignal(Config.PLOT_VAULT_ATTRIBUTE):Connect(refreshStealPrompts)
	refreshStealPrompts()
end

-- The leaderboard's SurfaceGui is built on the server and frequently never
-- gets drawn -- it stays blank indefinitely, while toggling Enabled with no
-- visual change at all makes it appear immediately. Reordering the build and
-- moving the board closer both failed to fix it on their own; nudging it once
-- from the client, after everything has replicated, is what actually works.
--
-- Purely cosmetic, and it costs one property write per player per session.
task.spawn(function()
	local world = workspace:WaitForChild("World", 30)
	local board = world and world:WaitForChild("Leaderboard", 30)
	local surface = board and board:FindFirstChildOfClass("SurfaceGui")
	if not surface then
		return
	end
	task.wait(1)
	surface.Enabled = false
	task.wait()
	surface.Enabled = true
end)

task.spawn(function()
	local plots = workspace:WaitForChild("Plots", 30)
	if not plots then
		return
	end
	for _, plotModel in ipairs(plots:GetChildren()) do
		task.spawn(bindPlot, plotModel)
	end
	plots.ChildAdded:Connect(function(child)
		task.spawn(bindPlot, child)
	end)
end)

-- CAN I ROB THAT ONE? -- answered from the pavement rather than at the prompt.
--
-- REQUIRED AND STARTED IN ONE STATEMENT, holding no local of its own, because
-- this chunk is at Luau's 200-local ceiling and the three the badge originally
-- wanted went straight through it. That does not cost the badge, it costs the
-- ENTIRE HUD: the chunk never compiles, so nothing gets built, and the error
-- names whatever variable happened to be next in line -- `buildBustScene`,
-- two thousand lines away and nothing to do with it.
--
-- It also wants nothing from here. The badge is a function of plot attributes,
-- the Player list and one remote, so it finds its own plots and needs no hook
-- in `bindPlot`.
require(ReplicatedStorage.Shared.RobBadge).start(player)
-- THE STREET LEADERBOARD: a toggled panel of everybody's lifetime cash,
-- piggies robbed and rebirths, its BOARD tile in the left menu rail (`shop`
-- is that rail) and its keys (Tab, L). One statement holding no local, for
-- the 200-register ceiling. See LobbyBoard.
require(ReplicatedStorage.Shared.LobbyBoard).start(player, gui, shop)
-- Moves the legendary skins' shape geometry on the lawn pigs. No local held.
require(ReplicatedStorage.Shared.SkinFX).start()
-- The legendary skins' glow and lightning, driven here per machine. One
-- statement holding no local, for the 200-local ceiling. See LegendaryFX.
require(ReplicatedStorage.Shared.LegendaryFX).start()
-- The idle breath on every piggy standing on a pedestal. One statement
-- holding no local, for the 200-register ceiling. See PiggyIdle -- and note
-- it finds its displays BY NAME rather than by tag, because a tag the
-- server sets before parenting never fires its added signal here.
require(ReplicatedStorage.Shared.PiggyIdle).start()
-- The WADDLE on every roaming herd piggy: a bob, a sway and a nod about its
-- own feet, laid over the server's placement and driven by the distance the
-- server publishes on the member -- never by a clock. One statement holding
-- no local, for the same ceiling. See PiggyWalk.
require(ReplicatedStorage.Shared.PiggyWalk).start()
-- The DAILY REWARD sign and its sparkles, over the reader's OWN mailbox and
-- nobody else's. One statement, no local -- the 200-register ceiling, and the
-- same call the badge above makes for the same reason. It finds its own plots
-- and reads the two facts `PlotService.setMail`/`setMailOwner` already
-- publish on the prompt, so it needs no hook here and no new remote.
require(ReplicatedStorage.Shared.MailCall).start(player)

-- THE BURST THAT GOES OFF ON A THIEF WHEN SOMEBODY NABS THEM. Required and
-- started in ONE statement holding no local at all, which is the ninth time
-- this chunk's register ceiling has shaped a decision and is now cheaper to
-- design for than to hit. It wants nothing from here either: it watches the
-- Player list and two attributes, and every client renders what it can see.
require(ReplicatedStorage.Shared.CatchFX).start()
-- The gold glint across a VIP owner's name on their plot sign.
require(ReplicatedStorage.Shared.SignShine).start()

-- THE SHOW THAT GOES UP WHEN SOMEBODY REBIRTHS. Required and started in
-- one statement holding no local, the tenth time this chunk's 200-local
-- ceiling has shaped a decision. It wants nothing from here either: it
-- finds the plot folder itself and watches one attribute on each plot.
require(ReplicatedStorage.Shared.Fireworks).start()

-- SOMEBODY IS RUNNING OFF WITH YOUR COINS -- the "!" over a thief's head, and
-- the replacement for a Highlight that used to glow on every carrier in the
-- game at once. Same shape and the same two reasons as the badge above it: a
-- module required and started in one statement holding no local, and it needs
-- nothing from here -- it is a function of one attribute, the Player list and
-- the plots. See `Config.CARRY_VICTIM_ATTRIBUTE`.
require(ReplicatedStorage.Shared.RobberMark).start()

-- THE CRACK PANEL. Same shape and the same two reasons as the badge above it:
-- a module required and started in one statement holding no local, because
-- this chunk is at the 200-register ceiling; and it wants nothing from here,
-- because everything it draws arrives on one remote from the server that
-- decided it.
require(ReplicatedStorage.Shared.Crack).start(gui)

-- One shared onboarding/recovery objective slot. Keep it in its own module:
-- ClientMain is at Luau's top-level local ceiling. Crates remains the purchase
-- surface; the objective only opens the exact claimed skin's card.
require(ReplicatedStorage.Shared.FirstJob).start(player, gui, {
	canShow = Rebirth.canShow,
	skinIcon = function(parent: GuiObject, key: string)
		-- The same picture the crates show: the baked card for an animal, the
		-- card-angle 3D pig for a paint-only skin.
		local cards = require(ReplicatedStorage.Shared.ShopSkinCards)
		return cards.mount(parent, key) or cards.pigPreview(parent, PiggyModel.build(key))
	end,
	openCrates = function(key: string)
		for i, tab in ipairs(tabs) do
			if tab.view.Name == "CratesView" then
				panel.Visible = true
				selectTab(i)
				Crates.focusBuyback(key)
				break
			end
		end
	end,
})

-- THE SESSION ARC, WHICH HAD A MECHANISM AND NO DISPLAY. The rap sheet, Most
-- Wanted and the pursuit floor already model an arc across a session, and the
-- only places any of it surfaced were a poster out on the street and toasts
-- that are gone in six seconds.
--
-- It sits directly under the event chip because it is the same KIND of thing:
-- the top-centre column is alerts, and this corner is standing readouts --
-- what you have, what the street is about to do, and now what you have done.
-- Same one-statement, no-local shape as the two modules above it.
require(ReplicatedStorage.Shared.Wanted).start(gui)

-- THE SERVER OWNS WHETHER YOU ARE SNEAKING, and this is the only thing that
-- writes the flag. It can refuse a request (carrying) and can drop a live
-- sneak without being asked (grabbing a pig), so a client that set the flag
-- optimistically when it pressed C would show ON through an entire getaway.
-- Written as a bare statement holding no local: see the key handler for why
-- this lives on the ScreenGui rather than in a variable.
Remotes.get("TiptoeState").OnClientEvent:Connect(function(on)
	gui:SetAttribute("Tiptoe", on == true)
end)

-- ============================================================
-- ADMIN PANEL
-- ============================================================
--
-- Built only after the SERVER says this player is an admin. That is a
-- convenience, not a security control: the AdminRequest remote exists for
-- everyone, and AdminService re-authorises every request against its
-- allowlist before reading a single argument. Nothing here grants anything --
-- if this whole block were deleted, or if a non-admin recreated it with an
-- exploit, the server would behave identically.

local adminGui: Frame? = nil

-- Built by AdminPanel, which owns the whole menu as a table. It lives in a
-- module rather than here for the reason SpinWheel and RaidFX do: this chunk
-- is at Luau's 200-local ceiling, and a panel with a dropdown, collapsible
-- groups and per-row state is exactly the kind of section that overflows it.
--
-- The remote is handed in rather than required over there, so the panel knows
-- nothing about Remotes and stays drivable from a test harness.
local function buildAdminPanel()
	if adminGui then
		return
	end
	adminGui = AdminPanel.build(gui, function(command, targetId, a, b)
		Remotes.get("AdminRequest"):FireServer(command, targetId, a, b)
	end, {
		-- The "spawn any piggy" screen; see `AdminPiggyPicker`.
		piggies = function(targetId)
			require(ReplicatedStorage.Shared.AdminPiggyPicker).toggle(targetId)
		end,
	})
end

Remotes.get("AdminState").OnClientEvent:Connect(function(isAdmin)
	if not isAdmin then
		return
	end
	buildAdminPanel()
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not adminGui then
		return
	end
	if input.KeyCode == Enum.KeyCode.F2 then
		adminGui.Visible = not adminGui.Visible
	end
end)

-- ============================================================
-- ANIMATED SKINS
-- ============================================================
--
-- Runs entirely on the client. The server publishes a SkinKey attribute on
-- each piggy and nothing else; every machine computes the colours itself.
--
-- Doing this server-side would mean a Color write per animated piggy per
-- frame, replicated to everyone -- roughly 700 property updates a second
-- across twelve plots, to say something each client could have worked out
-- from a single string.
--
-- One Heartbeat loop drives every piggy on the map rather than one loop each.

-- "Trim" IS THE MESH PIGGY'S WHOLE TRIM ON ONE PART, and it has to be in
-- this list or an animated skin drives the body and leaves the ears, muzzle,
-- hooves and tail on their static colour -- forever, on 23 skins, with
-- nothing in the log. The four primitive names stay beside it because an
-- empty mesh id is still a supported state.
local ANIMATED_TRIM = { "Trim", "Snout", "Tail", "Ear", "Leg" }

-- THE `patch` FIELD IS RETIRED WITH THE PART IT PAINTED. It capped a socket
-- the generator left in the old body's back, and was a field of its own
-- rather than a name in ANIMATED_TRIM because it took the BODY colour --
-- left off, it held a static colour while the pig cycled, which on the 23
-- animated skins was a coin-sized spot that did not match the animal. The
-- regenerated body seats every part on its own socket, so there is no cap and
-- nothing to keep in step.
local animatedPiggies: {
	{
		model: Instance, body: BasePart, trim: { BasePart },
		glow: PointLight?, auraLight: PointLight?,
	}
} = {}

local function paletteAt(palette: { Color3 }, t: number): Color3
	-- Wraps, so a palette is a loop rather than a ramp that snaps at the end.
	local span = #palette
	local scaled = (t % 1) * span
	local index = math.floor(scaled)
	local frac = scaled - index
	local a = palette[(index % span) + 1]
	local b = palette[((index + 1) % span) + 1]
	return a:Lerp(b, frac)
end

local function skinColourAt(anim: any, clock: number, seed: number): Color3?
	local kind = anim.kind
	local speed = anim.speed or 1

	if kind == "rainbow" then
		return Color3.fromHSV((clock * speed + seed) % 1, anim.sat or 0.72, anim.value or 1)
	elseif kind == "cycle" then
		return paletteAt(anim.palette, clock * speed * 0.25 + seed)
	elseif kind == "pulse" then
		local t = (math.sin(clock * speed * math.pi * 2 + seed * 6) + 1) / 2
		return anim.palette[1]:Lerp(anim.palette[2], t)
	elseif kind == "flicker" then
		-- Deliberately not smooth: fire and lightning read as unsteady, so this
		-- stacks two out-of-phase waves to avoid an obvious pulse rhythm.
		local a = math.sin(clock * speed + seed * 5)
		local b = math.sin(clock * speed * 2.7 + seed * 11)
		local t = math.clamp((a + b) / 2 * 0.5 + 0.5, 0, 1)
		return anim.palette[1]:Lerp(anim.palette[2], t * t)
	end
	return nil
end

local function collectAnimated(piggy: Instance)
	local body = piggy:FindFirstChild("Body") :: BasePart?
	if not body then
		return
	end
	local trim: { BasePart } = {}
	for _, child in ipairs(piggy:GetChildren()) do
		if child:IsA("BasePart") and table.find(ANIMATED_TRIM, child.Name) then
			table.insert(trim, child)
		end
	end
	table.insert(animatedPiggies, {
		model = piggy,
		body = body,
		trim = trim,
		glow = body:FindFirstChild("Glow") :: PointLight?,
		auraLight = body:FindFirstChild("AuraLight") :: PointLight?,
	})
end

task.spawn(function()
	local plots = workspace:WaitForChild("Plots", 30)
	if not plots then
		return
	end
	for _, plot in ipairs(plots:GetChildren()) do
		local piggy = plot:FindFirstChild("PiggyBank")
		if piggy then
			collectAnimated(piggy)
		end
	end

	-- THE MINIS FEED IT NOW: every pedestal display, every herd member and
	-- every carried piggy, found BY NAME the way `LegendaryFX` finds its
	-- folders -- a model parented whole is seen by a scan and by
	-- DescendantAdded both, where a CollectionService tag's added signal
	-- does not fire for an instance that replicates already tagged. They
	-- carry `SkinKey` from `PiggyModel.build`, so an `anim` skin cycles on a
	-- plinth exactly as it does on the till. Designer, 2026-09-21: "we need
	-- the minis to look exactly like they were built".
	--
	-- PRUNED ON `Destroying`, which is what the shop previews below could not
	-- have and the reason they stay out: a display is destroyed by the next
	-- dress, a herd member by its catch or its exit, a carry by delivery, and
	-- each takes its entry with it. The trim is collected by the `Trim`
	-- attribute as well as by name, because the mesh mini's whole trim is one
	-- part called `Trim` and the primitives fallback still names four.
	local MINI_NAMES = { Display = true, HerdPiggy = true, [Config.LOOT_MODEL_NAME] = true }
	local collected: { [Instance]: boolean } = {}
	local function collectMini(inst: Instance)
		if not inst:IsA("Model") or type(inst:GetAttribute("SkinKey")) ~= "string" then
			return
		end
		if collected[inst] then
			return
		end
		collected[inst] = true
		-- WAITED FOR, NOT LOOKED UP. A replicated model raises DescendantAdded
		-- the moment IT arrives, and its children follow in later packets --
		-- so a `FindFirstChild("Body")` here answered nil for every display
		-- that came in after the first scan, and the plinths sat static while
		-- every property on them read right. Bounded, so a model that never
		-- gets a body (a shop's own "Display" case carries no SkinKey and is
		-- refused above anyway) costs one wait and no entry.
		local body = inst:WaitForChild("Body", 10) :: BasePart?
		if not body or not inst.Parent then
			collected[inst] = nil
			return
		end
		local trim: { BasePart } = {}
		for _, child in ipairs(inst:GetChildren()) do
			if child:IsA("BasePart") and child ~= body
				and (child:GetAttribute("Trim") == true or table.find(ANIMATED_TRIM, child.Name)) then
				table.insert(trim, child)
			end
		end
		local entry = { model = inst, body = body, trim = trim, glow = nil, auraLight = nil }
		table.insert(animatedPiggies, entry)
		inst.Destroying:Once(function()
			local at = table.find(animatedPiggies, entry)
			if at then
				table.remove(animatedPiggies, at)
			end
		end)
	end
	for _, d in ipairs(workspace:GetDescendants()) do
		if MINI_NAMES[d.Name] then
			task.spawn(collectMini, d)
		end
	end
	workspace.DescendantAdded:Connect(function(d)
		if MINI_NAMES[d.Name] then
			task.spawn(collectMini, d)
		end
	end)

	-- THE SHOP NO LONGER FEEDS THIS LIST. `watchShopPiggy` existed so that a
	-- skin tile cycled in the catalogue as well as on the lawn, and the skins
	-- tab has gone -- so the plot piggies above are the whole of it.
	--
	-- The crate reel, the bag and the haul summary all build a real piggy
	-- through `iconFor` and deliberately do NOT register it here: this list is
	-- never pruned, and those models are created and destroyed constantly, so
	-- feeding them in would leak a Heartbeat entry per preview. Animating them
	-- wants a cleanup pass first, and it has never been wired.

	RunService.Heartbeat:Connect(function()
		local clock = os.clock()
		for index, entry in ipairs(animatedPiggies) do
			local key = entry.model:GetAttribute("SkinKey")
			local skin = if type(key) == "string" then Config.SKINS[key] else nil
			local anim = skin and skin.anim

			if anim then
				-- Seeded per plot so twelve animated piggies are not all
				-- pulsing in lockstep, which reads as one effect rather than
				-- twelve separate players.
				local colour = skinColourAt(anim, clock, index * 0.137)
				if colour then
					entry.body.Color = colour
					for _, p in ipairs(entry.trim) do
						p.Color = colour:Lerp(skin.trim, 0.55)
					end
				end
				if anim.glow and entry.glow then
					-- Left alone otherwise: EconomyService drives this light to
					-- show vault fill, and stomping it every frame would erase
					-- that signal.
					entry.glow.Color = entry.body.Color
				end
			end

			-- Effect light. Storm strikes; Inferno breathes.
			local light = entry.auraLight
			if light and light.Enabled then
				local kind = entry.model:GetAttribute("LightKind")
				local seed = index * 0.61
				if kind == "strike" then
					-- Mostly dark with occasional sharp flashes, so it reads as
					-- lightning rather than as a lamp someone left on.
					local wave = math.sin(clock * 1.7 + seed) * math.sin(clock * 0.53 + seed * 3)
					local flash = math.max(0, wave) ^ 8
					light.Brightness = 0.6 + flash * 14
				elseif kind == "flicker" then
					local a = math.sin(clock * 11 + seed * 5)
					local b = math.sin(clock * 27 + seed * 13)
					light.Brightness = 7 + (a + b) * 1.6
				end
			end
		end
	end)
end)

-- ============================================================
-- MOAT WATER
-- ============================================================
--
-- The top fence tier's moat, animated here for exactly the reason the
-- animated skins are: the server builds the channel once and publishes the
-- span, and every machine works the motion out for itself. Driving it
-- server-side would replicate a CFrame and a Transparency write per band per
-- frame -- twenty-five parts per moat, before anyone buys a second one.
--
-- Two motions, and they do different jobs. The SURFACE breathes: a slow bob
-- and a shift in transparency, which is what stops a flat plane reading as
-- painted-on. The RIPPLES travel: pale crests sliding the length of each band
-- and fading out at both ends, so a crest dissolves before it reaches a
-- corner instead of popping through the one beside it.
--
-- Tagged rather than collected once, because a moat comes and goes -- it is
-- built when someone buys the fifth fence and torn down if they rebirth.

local moatWater: { { part: BasePart, base: CFrame, phase: number } } = {}
local moatRipples: { { part: BasePart, base: CFrame, span: number, alongX: boolean, phase: number } } = {}

local function trackMoatWater(inst: Instance)
	if inst:IsA("BasePart") then
		table.insert(moatWater, {
			part = inst,
			base = inst.CFrame,
			phase = (inst:GetAttribute("Phase") :: number?) or 0,
		})
	end
end

local function trackMoatRipple(inst: Instance)
	if inst:IsA("BasePart") then
		table.insert(moatRipples, {
			part = inst,
			base = inst.CFrame,
			span = (inst:GetAttribute("Span") :: number?) or 10,
			alongX = (inst:GetAttribute("AlongX") :: boolean?) == true,
			phase = (inst:GetAttribute("Phase") :: number?) or 0,
		})
	end
end

local function dropDead(list: { any })
	for i = #list, 1, -1 do
		if not list[i].part.Parent then
			table.remove(list, i)
		end
	end
end

-- Same shape as the moat below and the skins above: the server tags emissive
-- parts and publishes what they should do, and every client animates what it
-- can see. Safe to start before any house exists -- it registers by tag
-- signal, and a house is built when somebody buys a tier or a shop tile is
-- rendered, both long after this line runs.
HouseFX.start()
RaidFX.start()

-- The Storm Wolf's lightning, for the same reasons one line up -- except that a
-- piggy IS built at server startup, so this one cannot rely on the tag signal
-- the way HouseFX gets away with. `BoltFX` carries its own bounded rescan.
-- Required inline and holding no local, because this chunk is on the 200-local
-- ceiling and a top-level name here costs the whole HUD rather than the effect.
require(ReplicatedStorage.Shared.BoltFX).start()

do
	local DEEP = Color3.fromRGB(30, 86, 140)
	local SHALLOW = Theme.COOL

	for _, inst in ipairs(CollectionService:GetTagged("MoatWater")) do
		trackMoatWater(inst)
	end
	for _, inst in ipairs(CollectionService:GetTagged("MoatRipple")) do
		trackMoatRipple(inst)
	end
	CollectionService:GetInstanceAddedSignal("MoatWater"):Connect(trackMoatWater)
	CollectionService:GetInstanceAddedSignal("MoatRipple"):Connect(trackMoatRipple)
	-- Removal is swept rather than handled per instance: a torn-down fence
	-- destroys its parts, and the tag-removed signal does not fire for a
	-- Destroy that takes the tag with it.
	CollectionService:GetInstanceRemovedSignal("MoatWater"):Connect(function()
		dropDead(moatWater)
	end)
	CollectionService:GetInstanceRemovedSignal("MoatRipple"):Connect(function()
		dropDead(moatRipples)
	end)

	RunService.Heartbeat:Connect(function()
		if #moatWater == 0 and #moatRipples == 0 then
			return
		end
		local clock = os.clock()

		for _, w in ipairs(moatWater) do
			if w.part.Parent then
				local s = math.sin(clock * 0.85 + w.phase)
				local t = math.sin(clock * 0.41 + w.phase * 1.7)
				w.part.CFrame = w.base * CFrame.new(0, s * 0.035, 0)
				w.part.Transparency = 0.30 + s * 0.05
				w.part.Color = DEEP:Lerp(SHALLOW, (t + 1) / 2 * 0.6)
			end
		end

		for _, r in ipairs(moatRipples) do
			if r.part.Parent then
				local t = (clock * 0.32 + r.phase) % 1
				local d = (t - 0.5) * r.span
				r.part.CFrame = r.base * CFrame.new(
					if r.alongX then Vector3.new(d, 0, 0) else Vector3.new(0, 0, d))
				-- Faded at both ends of its own band, so a crest never
				-- reaches a corner and cuts across the channel next to it.
				local edge = math.min(t, 1 - t) * 2
				r.part.Transparency = 1 - 0.5 * math.clamp(edge * 2.5, 0, 1)
			end
		end
	end)
end


-- ============================================================
-- DAILY REWARDS
-- ============================================================
--
-- Wrapped in a function, and that is not a style choice.
--
-- Luau allows 200 local registers per function, ClientMain is ONE top-level
-- chunk, and this file was already close to the ceiling. Declaring this
-- section's twenty-odd locals at the top level overflowed it -- "Out of local
-- registers when trying to allocate dayLabel: exceeded limit 200" -- and the
-- whole HUD failed to build, not just the part that was added. A function
-- body gets its own register file, so this costs the chunk exactly one local
-- instead of twenty. Any future section of this size wants the same treatment.
local function buildDailyRewards()

	-- ============================================================
	-- DAILY REWARDS
	-- ============================================================
	--
	-- The board is the whole feature: seven cards, today's lit, and every rung
	-- readable from day one. Nothing here is a surprise on purpose -- a random
	-- daily would be a random outcome standing downstream of a coin purchase,
	-- which is the one thing this economy is not allowed to contain.
	--
	-- IT NO LONGER OPENS ITSELF, AND THAT IS THE WHOLE POINT OF THE MAILBOX.
	-- The board used to appear 1.5 seconds after a join whenever there was
	-- something to claim, which handed the reward over before the player had
	-- done anything and left the postbox on their own verge -- flag up, prompt
	-- live, a delivery fiction already built -- with nothing to walk to it
	-- for. It opens from the mailbox now, on `DailyOpen`. `Shared/MailCall` is
	-- what makes the box worth walking to.

	-- THE BOARD IS THE CURRENT HUD'S OWN VOCABULARY: a paper card with the ink
	-- line, a picture on every rung, and the reward's real value printed on it.
	-- It was the last surface still drawn the old way -- seven flat text tiles,
	-- a claimed day that forgot what it had paid, and a sentence about today's
	-- rung that this section's own comment promised and nothing ever drew.
	local TweenService = game:GetService("TweenService")
	local Icons = require(ReplicatedStorage.Shared.ShopIcons)
	local BOARD_W, BOARD_H = 660, 360

	local dailyModal = Instance.new("Frame")
	dailyModal.Name = "DailyBoard"
	dailyModal.AnchorPoint = Vector2.new(0.5, 0.5)
	dailyModal.Position = UDim2.new(0.5, 0, 0.5, 0)
	dailyModal.Size = UDim2.fromOffset(BOARD_W, BOARD_H)
	dailyModal.BackgroundColor3 = PANEL
	dailyModal.BorderSizePixel = 0
	dailyModal.Visible = false
	dailyModal.ZIndex = Theme.MENU_Z
	dailyModal.Parent = gui
	Theme.card(dailyModal, 18)

	-- Scales down on a phone rather than overflowing. Seven cards across is the
	-- widest thing in the HUD, and this is the only element that cannot simply
	-- wrap. The pop-in rides a second scale so it never fights the fit.
	local dailyScale = Instance.new("UIScale")
	dailyScale.Parent = dailyModal
	local dailyFit = 1

	local function fitDaily()
		local camera = workspace.CurrentCamera
		local view = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		dailyFit = math.clamp(math.min((view.X - 40) / BOARD_W, (view.Y - 40) / BOARD_H), 0.5, 1)
		dailyScale.Scale = dailyFit
	end
	fitDaily()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitDaily)
	end

	-- THE HEADER IS A RIBBON, the same tinted band the delivery summary wears,
	-- so the two screens that hand a reward over read as one family.
	local ribbon = Instance.new("Frame")
	ribbon.Name = "Ribbon"
	ribbon.Size = UDim2.new(1, -120, 0, 44)
	ribbon.Position = UDim2.fromOffset(18, 16)
	ribbon.BorderSizePixel = 0
	ribbon.ZIndex = 41
	ribbon.Parent = dailyModal
	Theme.tinted(ribbon, Theme.GOLD, Theme.GOLD_DEEP, 12)

	local dailyTitle = Instance.new("TextLabel")
	dailyTitle.Name = "Title"
	dailyTitle.Size = UDim2.new(1, -24, 1, -8)
	dailyTitle.Position = UDim2.fromOffset(14, 4)
	dailyTitle.BackgroundTransparency = 1
	dailyTitle.TextScaled = true
	dailyTitle.TextXAlignment = Enum.TextXAlignment.Left
	dailyTitle.Text = "DAILY REWARDS"
	dailyTitle.ZIndex = 42
	dailyTitle.Parent = ribbon
	Theme.title(dailyTitle, 30, Theme.INK)

	local dailyStreakLabel = Instance.new("TextLabel")
	dailyStreakLabel.Name = "Streak"
	dailyStreakLabel.Size = UDim2.new(1, -36, 0, 20)
	dailyStreakLabel.Position = UDim2.fromOffset(20, 68)
	dailyStreakLabel.BackgroundTransparency = 1
	dailyStreakLabel.TextScaled = true
	dailyStreakLabel.TextXAlignment = Enum.TextXAlignment.Left
	dailyStreakLabel.Text = ""
	dailyStreakLabel.ZIndex = 41
	dailyStreakLabel.Parent = dailyModal
	Theme.body(dailyStreakLabel, 16, Theme.MUTED)

	local dailyClose = Instance.new("TextButton")
	dailyClose.Size = UDim2.new(0, 30, 0, 30)
	dailyClose.Position = UDim2.new(1, -42, 0, 14)
	dailyClose.Name = "CloseDailyRewards"
	dailyClose.BackgroundColor3 = Theme.STOP
	dailyClose.BorderSizePixel = 0
	dailyClose.Font = Enum.Font.FredokaOne
	dailyClose.TextScaled = false
	dailyClose.TextSize = 28
	dailyClose.TextColor3 = Theme.PAPER
	dailyClose.Text = utf8.char(0x00D7)
	dailyClose.ZIndex = 41
	dailyClose.Parent = dailyModal
	corner(dailyClose, 12)
	Theme.outline(dailyClose)
	Theme.floatClose(dailyClose)

	local dailyRow = Instance.new("Frame")
	dailyRow.Name = "Days"
	dailyRow.Size = UDim2.new(1, -36, 0, 152)
	dailyRow.Position = UDim2.fromOffset(18, 98)
	dailyRow.BackgroundTransparency = 1
	dailyRow.ZIndex = 41
	dailyRow.Parent = dailyModal

	local dailyRowLayout = Instance.new("UIListLayout")
	dailyRowLayout.FillDirection = Enum.FillDirection.Horizontal
	dailyRowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dailyRowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	dailyRowLayout.Padding = UDim.new(0, 8)
	dailyRowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	dailyRowLayout.Parent = dailyRow

	-- READ OFF Config.DAILY_CYCLE, never kept as a second copy of the ladder.
	-- This ladder's whole rule is that it is published, so it has to be
	-- published from the one place that decides it.
	local DAILY_SHORT: { string } = {}
	for i, rung in ipairs(Config.DAILY_CYCLE) do
		DAILY_SHORT[i] = rung.short or string.upper(rung.kind)
	end

	-- A PICTURE PER RUNG, from the art the shop already uses: the coin, the
	-- income arrow for a boost, the golden bone, and the crate for its own
	-- tier. The plain Dog Bone has no painted icon, so it gets the same 3D
	-- model its hot bar tile renders.
	local function rungIcon(well: GuiObject, rung: any)
		if rung.kind == "coins" then
			Icons.mount(well, "coin-front")
		elseif rung.kind == "boost" then
			Icons.mount(well, "income")
		elseif rung.kind == "golden" then
			Icons.mount(well, "golden-bone")
		elseif rung.kind == "crate" then
			local chest = Config.CHESTS[rung.crate]
			Icons.mount(well, "crate-" .. ((chest and chest.tier) or "common"))
		elseif rung.kind == "bone" then
			makeModelIcon(well, BoneModel.build(rung.bone or "bone", false),
				UDim2.fromScale(1, 1), UDim2.new(), false)
		end
	end

	local CARD_W = math.floor((BOARD_W - 36 - 6 * 8) / 7)
	local dailyCards = {}
	for i, rung in ipairs(Config.DAILY_CYCLE) do
		local card = Instance.new("Frame")
		card.Name = "Day" .. i
		card.Size = UDim2.fromOffset(CARD_W, 140)
		card.LayoutOrder = i
		card.BackgroundColor3 = Theme.PAPER_DEEP
		card.BorderSizePixel = 0
		card.ZIndex = 41
		card.Parent = dailyRow
		corner(card, 12)
		Theme.shade(card, 0.88)
		local stroke = Theme.outline(card, Theme.OUTLINE_THIN)
		local pop = Instance.new("UIScale")
		pop.Parent = card

		local dayLabel = Instance.new("TextLabel")
		dayLabel.Name = "Day"
		dayLabel.Size = UDim2.new(1, -8, 0, 20)
		dayLabel.Position = UDim2.fromOffset(4, 7)
		dayLabel.BackgroundTransparency = 1
		dayLabel.TextScaled = true
		dayLabel.Text = if i == #Config.DAILY_CYCLE then "DAY " .. i .. "!" else "DAY " .. i
		dayLabel.ZIndex = 42
		dayLabel.Parent = card
		Theme.title(dayLabel, 18, Theme.INK)
		local dayCap = Instance.new("UITextSizeConstraint")
		dayCap.MaxTextSize = 18
		dayCap.Parent = dayLabel

		local well = Instance.new("Frame")
		well.Name = "Well"
		well.AnchorPoint = Vector2.new(0.5, 0)
		well.Size = UDim2.fromOffset(58, 58)
		well.Position = UDim2.new(0.5, 0, 0, 32)
		well.BackgroundTransparency = 1
		well.ZIndex = 42
		well.Parent = card
		rungIcon(well, rung)

		local what = Instance.new("TextLabel")
		what.Name = "What"
		what.Size = UDim2.new(1, -8, 0, 36)
		what.Position = UDim2.new(0, 4, 1, -42)
		what.BackgroundTransparency = 1
		what.TextScaled = true
		what.Text = DAILY_SHORT[i]
		what.ZIndex = 42
		what.Parent = card
		Theme.body(what, 14, Theme.INK)
		local whatCap = Instance.new("UITextSizeConstraint")
		whatCap.MaxTextSize = 16
		whatCap.Parent = what

		-- A CLAIMED DAY KEEPS ITS PICTURE AND GETS A TICK OVER IT. The old card
		-- replaced the reward with the word CLAIMED, so four days into a streak
		-- the board had forgotten what it paid you.
		local tick = Instance.new("TextLabel")
		tick.Name = "Tick"
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Size = UDim2.fromOffset(30, 30)
		tick.Position = UDim2.new(1, -8, 0, 36)
		tick.BackgroundColor3 = Theme.GOOD
		tick.BorderSizePixel = 0
		tick.Font = Theme.FONT
		tick.TextSize = 22
		tick.TextColor3 = Theme.INK
		tick.Text = utf8.char(0x2713)
		tick.Visible = false
		tick.ZIndex = 44
		tick.Parent = card
		corner(tick, 15)
		Theme.outline(tick, Theme.OUTLINE_THIN)

		dailyCards[i] = { card = card, stroke = stroke, dayLabel = dayLabel,
			what = what, well = well, tick = tick, pop = pop, rung = rung }
	end

	-- THE SENTENCE UNDER THE ROW, for today's rung only. Seven long labels side
	-- by side are unreadable at any size, and six of them are not today.
	local dailyDetail = Instance.new("TextLabel")
	dailyDetail.Name = "Detail"
	dailyDetail.Size = UDim2.new(1, -36, 0, 22)
	dailyDetail.Position = UDim2.fromOffset(18, 258)
	dailyDetail.BackgroundTransparency = 1
	dailyDetail.TextScaled = true
	dailyDetail.Text = ""
	dailyDetail.ZIndex = 41
	dailyDetail.Parent = dailyModal
	Theme.title(dailyDetail, 20, Theme.INK)
	local detailCap = Instance.new("UITextSizeConstraint")
	detailCap.MaxTextSize = 20
	detailCap.Parent = dailyDetail

	local dailyClaim = Instance.new("TextButton")
	dailyClaim.Name = "Claim"
	dailyClaim.Size = UDim2.new(0, 260, 0, 50)
	dailyClaim.AnchorPoint = Vector2.new(0.5, 1)
	dailyClaim.Position = UDim2.new(0.5, 0, 1, -16)
	dailyClaim.BackgroundColor3 = GOOD
	dailyClaim.BorderSizePixel = 0
	dailyClaim.Font = Theme.FONT
	dailyClaim.TextScaled = true
	dailyClaim.TextColor3 = INK
	dailyClaim.Text = "CLAIM"
	dailyClaim.ZIndex = 41
	dailyClaim.Parent = dailyModal
	corner(dailyClaim, 14)
	Theme.outline(dailyClaim)
	Theme.shade(dailyClaim)
	local claimPad = Instance.new("UIPadding")
	claimPad.PaddingTop, claimPad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
	claimPad.Parent = dailyClaim

	-- ---------- the boost pocket ----------
	--
	-- Bottom left, which is the one corner of the HUD nothing else claims: the
	-- Bottom left, on the row ABOVE the item bar. The bar is centred and
	-- grows with however many throwables are held, so on a narrow screen a
	-- pill sitting on the same line would eventually be underneath it.

	local boostPill = require(ReplicatedStorage.Shared.HUDWidgets).boost(gui)

	local heldBoosts: { [string]: number } = {}
	local boostEndsAt = 0

	-- Shortest first, so a five-minute token is spent before a fifteen. The other
	-- order strands the small ones forever.
	local BOOST_ORDER = { "boost5", "boost15" }

	local function firstHeldBoost(): string?
		for _, key in ipairs(BOOST_ORDER) do
			if (heldBoosts[key] or 0) > 0 then
				return key
			end
		end
		return nil
	end

	local function renderBoostPill()
		local left = math.max(0, math.ceil(boostEndsAt - os.clock()))
		local total = 0
		for _, key in ipairs(BOOST_ORDER) do
			total += heldBoosts[key] or 0
		end
		require(ReplicatedStorage.Shared.HUDWidgets).renderBoost(boostPill, total, left)
	end

	boostPill.Activated:Connect(function()
		if boostEndsAt > os.clock() then
			return
		end
		local key = firstHeldBoost()
		if key then
			Remotes.get("BoostUse"):FireServer(key)
		end
	end)

	-- ---------- state ----------

	local function setDailyOpen(open: boolean)
		dailyOpen = open
		dailyModal.Visible = open
		if open then
			-- A small pop, the same arrival every reward card in this HUD makes.
			dailyScale.Scale = dailyFit * 0.85
			TweenService:Create(dailyScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = dailyFit }):Play()
		end
		Rebirth.sync()
	end

	-- What a rung pays, in the words that fit on a card. Coin rungs print the
	-- player's own figure off the push, which is the whole point of pricing
	-- them in seconds of income: "+12.4K" means something and COINS did not.
	local function rungWords(i: number, rung: any, values: any): string
		local value = values and values[tostring(i)]
		if rung.kind == "coins" and value then
			return "+" .. Config.formatCoins(value)
		elseif rung.kind == "golden" then
			return "GOLDEN BONE"
		elseif rung.kind == "crate" then
			return "FREE CRATE"
		end
		return DAILY_SHORT[i]
	end

	local function setWellFaded(well: Instance, faded: boolean)
		for _, d in ipairs(well:GetDescendants()) do
			if d:IsA("ImageLabel") then
				d.ImageTransparency = if faded then 0.45 else 0
			elseif d:IsA("ViewportFrame") then
				d.ImageTransparency = if faded then 0.45 else 0
			end
		end
	end

	local todayPulse: Tween? = nil

	local function renderDaily(snapshot: any)
		local day = snapshot.day or 1
		local claimable = snapshot.claimable == true
		local values = snapshot.values

		if todayPulse then
			todayPulse:Cancel()
			todayPulse = nil
		end

		for i, entry in ipairs(dailyCards) do
			local isToday = claimable and i == day
			-- Rungs already banked in THIS run of the cycle. When there is nothing
			-- to claim, today's has been collected too, so it counts as done.
			local done = if claimable then i < day else i <= day
			entry.card.BackgroundColor3 = if isToday
				then Theme.GOLD
				elseif done then ShopStyle.OWNED
				else Theme.PAPER
			entry.stroke.Thickness = if isToday then Theme.OUTLINE + 1 else Theme.OUTLINE_THIN
			entry.what.Text = rungWords(i, entry.rung, values)
			entry.tick.Visible = done
			setWellFaded(entry.well, done)
			entry.pop.Scale = 1
			if isToday then
				-- TODAY BREATHES, so the eye lands on the one card that can be
				-- pressed for. Well under the three-flashes-a-second ceiling.
				todayPulse = TweenService:Create(entry.pop,
					TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
					{ Scale = 1.06 })
				todayPulse:Play()
			end
		end

		-- The sentence: today's rung while there is one to claim, tomorrow's once
		-- it is banked, so the board always says what turning up next buys.
		local nextIndex = if claimable then day else (day % #Config.DAILY_CYCLE) + 1
		local nextRung = Config.DAILY_CYCLE[nextIndex]
		local nextLabel = if nextRung then nextRung.label else ""
		local nextValue = values and values[tostring(nextIndex)]
		if nextRung and nextRung.kind == "coins" and nextValue then
			nextLabel = Config.formatCoins(nextValue) .. " coins"
		elseif nextRung and nextRung.kind == "golden" and nextValue then
			nextLabel = "A Golden Bone + " .. Config.formatCoins(nextValue) .. " coins"
		end

		if claimable then
			dailyStreakLabel.Text = ("Day %d of your streak. Miss two days and it starts over.")
				:format(snapshot.nextStreak or 1)
			dailyDetail.Text = "Today: " .. nextLabel
			dailyDetail.TextColor3 = Theme.INK
			dailyClaim.Text = "CLAIM"
			dailyClaim.BackgroundColor3 = GOOD
			dailyClaim.AutoButtonColor = true
		else
			dailyStreakLabel.Text = ("Streak %d, %d days in total.")
				:format(snapshot.streak or 0, snapshot.lifetime or 0)
			dailyDetail.Text = "Tomorrow: " .. nextLabel
			dailyDetail.TextColor3 = Theme.MUTED
			dailyClaim.Text = "COME BACK TOMORROW"
			dailyClaim.BackgroundColor3 = Theme.PAPER_DEEP
			dailyClaim.AutoButtonColor = false
		end

		heldBoosts = snapshot.boosts or {}
		boostEndsAt = os.clock() + (snapshot.boostLeft or 0)
		renderBoostPill()
	end

	dailyClose.Activated:Connect(function()
		setDailyOpen(false)
	end)

	-- THE MAILBOX ON YOUR OWN PLOT, AND IT IS THE ONLY WAY TO THIS BOARD.
	--
	-- It was the only way BACK to it, once: the board opened itself 1.5
	-- seconds after a join and nothing else in the game reached it, so closing
	-- it without claiming lost the day silently with the reward still sitting
	-- there. Now it is the only way IN, which is a stronger version of the
	-- same fix -- the claim is a walk and a press rather than a modal that
	-- arrives before the player has done anything. `Shared/MailCall` puts the
	-- sign and the sparkles on the box so there is something to walk to.
	Remotes.get("DailyOpen").OnClientEvent:Connect(function()
		setDailyOpen(true)
	end)

	dailyClaim.Activated:Connect(function()
		Remotes.get("DailyRequest"):FireServer()
	end)

	Remotes.get("DailyState").OnClientEvent:Connect(function(snapshot)
		local wasOpen = dailyModal.Visible
		renderDaily(snapshot)

		-- A PUSH STILL CLOSES THE BOARD AND NEVER OPENS IT. The claimable
		-- branch that used to open it is gone (see the note above the modal);
		-- what is left is the half that was always about feedback rather than
		-- about arrival.
		if not snapshot.claimable and wasOpen then
			-- Just claimed. Hold it open long enough to watch the card tick over
			-- to CLAIMED, which is the only feedback that the button did anything.
			task.delay(1.4, function()
				setDailyOpen(false)
			end)
		end
	end)

	-- One tick a second is enough for a mm:ss countdown, and it costs nothing
	-- while no boost is running.
	task.spawn(function()
		while true do
			task.wait(1)
			if boostEndsAt > os.clock() or boostPill.Visible then
				renderBoostPill()
			end
		end
	end)
end

-- ============================================================
-- TRAMPOLINES
-- ============================================================
--
-- The server decides; this applies it. A character's physics are owned by its
-- own client, so a server-side write to AssemblyLinearVelocity on a player's
-- own root is discarded -- measured three ways on a live rig (raw, and after
-- ChangeState to Jumping and to Freefall), all of which left the character at
-- exactly its 5.00-stud drop height. Same split as the dodge: the server owns
-- the decision, the client owns the physics.
--
-- A FUNCTION RATHER THAN A TOP-LEVEL HANDLER, because this chunk sits near
-- Luau's 200-local ceiling and a function body gets its own register file.
local function bindTrampolineBounce()
	Remotes.get("TrampolineBounce").OnClientEvent:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		-- VERTICAL ONLY. The horizontal components are read back and written
		-- straight through, so a trampoline adds height and never distance --
		-- a second way to move sideways is exactly what Config.DODGE exists to
		-- rule out, and the wheelie bin's exit hop makes the same promise.
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, Config.TRAMPOLINE_BOUNCE, v.Z)
	end)
end
bindTrampolineBounce()

-- SHOCKED OFF A FENCE.
--
-- Same split as the trampoline and for the same measured reason: a server-side
-- write to this character's AssemblyLinearVelocity is discarded, so the server
-- decides -- who, whether, and which way -- and the client applies it.
--
-- `PLATFORMSTAND IS THE WHOLE TRICK, AND WITHOUT IT THIS DOES NOTHING.` A
-- plain velocity write here buys 0.20 studs of ground: the shock has just set
-- WalkSpeed to 0, and the humanoid's own control force spends every frame
-- damping horizontal motion toward MoveDirection * WalkSpeed. Vertical is the
-- one axis it does not fight, which is exactly why the trampoline is
-- vertical-only and works. PlatformStand suspends that steering, and the
-- identical push then lands: measured 5.66 studs against 0.20.
--
-- It also happens to be the right picture. The character goes limp for the
-- flight, which is what being zapped off a fence looks like, and recovers to
-- Running on its own -- verified rather than assumed, since a character left
-- in PlatformStand is a character that can never stand up again.
local function bindFenceKnockback()
	-- A guard dog throwing its catch out of the yard. The server chose the
	-- landing point; this flies a limp, tumbling arc to it over `duration`,
	-- writing the root every frame (a velocity push cannot reliably clear a
	-- fence or cover a yard). The server re-places anybody who never landed.
	Remotes.get("DogKnockout").OnClientEvent:Connect(function(landing, duration)
		if typeof(landing) ~= "Vector3" or type(duration) ~= "number" then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 or root.Anchored then
			return
		end
		local start = root.Position
		local flat = Vector3.new(landing.X - start.X, 0, landing.Z - start.Z)
		local facingCF = if flat.Magnitude > 0.1
			then CFrame.lookAt(Vector3.zero, flat.Unit)
			else root.CFrame.Rotation
		local apex = math.max(start.Y, landing.Y) + Config.DOG_CHASE.knockout.apex
		local control = 2 * apex - (start.Y + landing.Y) / 2
		local began = os.clock()
		humanoid.PlatformStand = true
		local connection
		connection = RunService.PreSimulation:Connect(function()
			local t = math.min((os.clock() - began) / duration, 1)
			if player.Character ~= character or humanoid.Health <= 0 or not root.Parent then
				connection:Disconnect()
				return
			end
			local u = 1 - t
			local y = u * u * start.Y + 2 * u * t * control + t * t * landing.Y
			local x = start.X + (landing.X - start.X) * t
			local z = start.Z + (landing.Z - start.Z) * t
			-- One backwards tumble across the flight, upright on landing.
			root.CFrame = CFrame.new(x, y, z) * facingCF * CFrame.Angles(-t * 2 * math.pi, 0, 0)
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			if t >= 1 then
				connection:Disconnect()
				root.CFrame = CFrame.new(landing) * facingCF
				humanoid.PlatformStand = false
			end
		end)
	end)

	Remotes.get("FenceKnockback").OnClientEvent:Connect(function(direction)
		if typeof(direction) ~= "Vector3" then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or humanoid.Health <= 0 then
			return
		end

		-- Flattened and re-normalised rather than used raw. The server sends a
		-- horizontal axis today, and a direction with any vertical component
		-- in it would trade knockback for launch height without either end
		-- saying so.
		local flat = Vector3.new(direction.X, 0, direction.Z)
		if flat.Magnitude < 1e-3 then
			return
		end
		flat = flat.Unit

		local k = Config.FENCE_KNOCKBACK
		humanoid.PlatformStand = true
		root.AssemblyLinearVelocity = flat * k.back + Vector3.new(0, k.up, 0)

		-- Cleared by CHARACTER, not by a bare flag: a respawn mid-flight hands
		-- the player a brand new humanoid, and clearing PlatformStand on the
		-- old one would leave the new one untouched while this timer went off
		-- against a corpse. Same shape as the wheelie bin remembering which
		-- character it swallowed.
		task.delay(k.limp, function()
			if player.Character == character and humanoid.Health > 0 then
				humanoid.PlatformStand = false
			end
		end)
	end)
end
bindFenceKnockback()

buildDailyRewards()

-- ============================================================
-- DODGE ROLL
-- ============================================================
--
-- The server publishes a DodgeRoll counter on the character and every client
-- plays the somersault itself. Same shape as animated skins, and for a harder
-- reason than tidiness: the animation is registered at runtime and its id is a
-- content hash local to this machine, so it cannot replicate. A track played
-- on one client would be an id nobody else can resolve.
--
-- Everyone has to see it. The dodge's real payload is half a second of
-- immunity, and a defender who loses a tag hold to an invisible dodge has been
-- beaten by something that never appeared to happen.
--
-- THE DASH IS A DIRECTION, NOT AN IMPULSE.
--
-- Config.DODGE is a multiplier on currentSpeed, which means a player standing
-- still dodges at 2.5x of nothing and goes nowhere -- the control did not work
-- unless you were already running. This drives the humanoid's own move
-- direction for the length of the window instead of adding a force, so the
-- dash still goes through the one movement system that the carry penalty, the
-- fence snags, the stun and the dog speeds are all expressed in. A fence still
-- stops you. A stun still means no dodge at all, because the server refuses it
-- before this is ever reached.
--
-- Direction is whatever is being held, and the character's own facing when
-- nothing is. It is captured once and held for the window rather than tracked,
-- because a dodge you can steer mid-roll is a sprint.
local function buildDodgeRolls()
	local DASH_BINDING = "PiggyDodgeDash"
	-- Above the control module, which binds at Input priority. Anything at
	-- or below that loses the frame.
	local DASH_PRIORITY = Enum.RenderPriority.Character.Value + 1
	local DodgeRoll = require(ReplicatedStorage.Shared.DodgeRoll)

	local function dash(character: Model, humanoid: Humanoid)
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			return
		end

		local held = humanoid.MoveDirection
		local heading = if held.Magnitude > 0.1 then held else root.CFrame.LookVector
		heading = Vector3.new(heading.X, 0, heading.Z)
		if heading.Magnitude < 0.01 then
			return
		end
		heading = heading.Unit

		-- Bound AFTER the control module rather than run on Heartbeat.
		--
		-- The default controls write a move direction every RenderStepped, and
		-- whoever writes last before the physics step wins. Heartbeat is after
		-- physics, so a dash driven there was overwritten by an empty input
		-- every single frame -- measured at 0.51 studs from a standing start,
		-- which is indistinguishable from the bug this was meant to fix.
		RunService:UnbindFromRenderStep(DASH_BINDING)
		local until_ = os.clock() + Config.DODGE.duration
		RunService:BindToRenderStep(DASH_BINDING, DASH_PRIORITY, function()
			if os.clock() >= until_ or humanoid.Parent == nil or humanoid.Health <= 0 then
				RunService:UnbindFromRenderStep(DASH_BINDING)
				return
			end
			humanoid:Move(heading, false)
		end)
	end

	local function roll(character: Model)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		-- Looked up when it fires rather than at spawn. At CharacterAdded the
		-- Animator often has not replicated yet, and a nil captured then would
		-- mean that character never rolled again.
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			DodgeRoll.play(animator)
		end
		return humanoid
	end

	local function watch(character: Model, isLocal: boolean)
		character:GetAttributeChangedSignal("DodgeRoll"):Connect(function()
			local humanoid = roll(character)
			-- Only your own character moves on your say-so. Everyone else's
			-- position is the server's business and arrives by replication.
			if humanoid and isLocal then
				dash(character, humanoid)
			end
		end)

		-- CLIMBING OUT OF A WHEELIE BIN PLAYS THE SAME ROLL AND NO DASH.
		--
		-- Its own attribute rather than a second bump of DodgeRoll, which
		-- would have been one line fewer and wrong: that handler dashes the
		-- local player as well, and the exit has already placed them 4.5
		-- studs out and handed them a speed burst. A third way to move on top
		-- of those two is exactly what Config.DODGE's "a multiplier, never an
		-- impulse" note rules out.
		--
		-- The animation is shared on purpose. Tumbling out of a bin is the
		-- same gesture as rolling out of the way, and a second sequence built
		-- to look almost the same is the copy that drifts the first time
		-- either one is touched.
		character:GetAttributeChangedSignal("BinExit"):Connect(function()
			roll(character)
		end)
	end

	local function follow(player: Player)
		local isLocal = player == Players.LocalPlayer
		if player.Character then
			watch(player.Character, isLocal)
		end
		player.CharacterAdded:Connect(function(character)
			watch(character, isLocal)
		end)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		follow(player)
	end
	Players.PlayerAdded:Connect(follow)
end

-- ============================================================
-- THE SNEAK
-- ============================================================
--
-- The server publishes `Config.SNEAK_ATTRIBUTE` on a character and every
-- client plays the tiptoe itself -- the same shape as the dodge, and for the
-- same hard reason rather than for tidiness: the animation is registered at
-- runtime and its id is a content hash local to this machine, so it cannot
-- replicate. A track played on one client would be an id nobody else can
-- resolve.
--
-- EVERYONE HAS TO SEE IT, WHICH IS THE HALF `TiptoeState` CANNOT DO. That
-- remote is a FireClient to the sneaker alone, which is exactly right for the
-- button's own ON/OFF state and useless for the street. Half the value of a
-- tiptoe is what it says to somebody watching a figure come up their drive,
-- and this game prefers a tell to a fight everywhere it can get one.
--
-- THE RATE IS MEASURED, NEVER READ OFF THE HUMANOID. Speed comes from
-- differencing the root's own flat position between frames rather than from
-- `WalkSpeed`. The guard dog's watcher draws exactly this distinction and it
-- matters here for the same reason: WalkSpeed is what a character is ALLOWED
-- to do, so somebody standing perfectly still reads 5.6 and would have their
-- legs cycling on the spot forever. Flat, because a fall is not a footstep.
local function buildSneakWalk()
	local SneakWalk = require(ReplicatedStorage.Shared.SneakWalk)

	-- Characters currently flagged, and where each was last frame.
	local active: { [Model]: { last: Vector3? } } = {}

	local function animatorOf(character: Model): Animator?
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return nil
		end
		return humanoid:FindFirstChildOfClass("Animator")
	end

	local function refresh(character: Model)
		if character:GetAttribute(Config.SNEAK_ATTRIBUTE) == true then
			active[character] = active[character] or {}
		else
			active[character] = nil
			local animator = animatorOf(character)
			if animator then
				SneakWalk.apply(animator, false)
			end
		end
	end

	local function watch(character: Model)
		character:GetAttributeChangedSignal(Config.SNEAK_ATTRIBUTE):Connect(function()
			refresh(character)
		end)
		-- A character can arrive ALREADY sneaking -- a remote player who was
		-- creeping before this client ever joined -- so the current value is
		-- read rather than waited for. The changed signal alone would never
		-- fire for them, and they would walk normally on this screen while
		-- tiptoeing on everybody else's.
		refresh(character)
	end

	local function follow(player: Player)
		if player.Character then
			watch(player.Character)
		end
		player.CharacterAdded:Connect(watch)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		follow(player)
	end
	Players.PlayerAdded:Connect(follow)

	RunService.Heartbeat:Connect(function(dt)
		for character, state in pairs(active) do
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local animator = animatorOf(character)
			if character.Parent == nil or not root or not animator then
				-- A destroyed or half-built character drops out rather than
				-- being carried forever. Nothing has to clean up after a
				-- respawn either: the new rig is a different Model, so the
				-- old entry simply stops matching anything.
				active[character] = nil
			else
				-- STARTED HERE RATHER THAN IN `refresh`, because at the
				-- moment the attribute changes the Animator may not have
				-- replicated yet -- the dodge records that same trap one
				-- section up, where a nil captured at spawn meant that
				-- character never rolled again. Asking every frame is what
				-- makes this self-healing rather than dependent on winning
				-- a race, and it is cheap: `apply` returns early once a
				-- track is running, and this loop only ever holds the
				-- handful of people actually sneaking.
				SneakWalk.apply(animator, true)

				local at = Vector3.new(root.Position.X, 0, root.Position.Z)
				local last = state.last
				state.last = at
				if last and dt > 0 then
					SneakWalk.setRate(animator, (at - last).Magnitude / dt)
				end
			end
		end
	end)
end

-- ============================================================
-- THE PATROL
-- ============================================================
--
-- Two jobs, and both of them are the same job: making the patrol PUBLISHED.
-- The banner counts down the siren and then the patrol itself, and the light
-- bar flashes. A hidden patrol would cause an identical amount of trouble
-- while turning a decision into bad luck, and bad luck is not something a
-- nine year old can get better at.
--
-- Wrapped in a function because this chunk sits near Luau's 200-local-register
-- ceiling and the whole HUD -- not just this section -- fails to build if it
-- is crossed. A function body gets its own register file, so this costs the
-- chunk one local instead of eight.
local function buildPatrol()

	-- UNDER THE WHOLE TOP-CENTRE STACK, and that is measured rather than
	-- chosen. This column is full, and it was already the documented way to
	-- break this HUD -- the rebirth button is what covered the accessory roll
	-- button the last time something was hung up here:
	--
	--     (free)          16 .. 90
	--     rebirth         96 .. 148
	--     carry banner   140 .. 192
	--     PATROL         200 .. 238
	--
	-- The top band opened up when the coin badge merged into the piggy bank
	-- panel, and the rebirth button was deliberately NOT moved up into it:
	-- shuffling a control a player already knows the position of, to close a
	-- gap nothing is drawn in, costs more than the gap does. It is the space
	-- for whatever wants this column next.
	--
	-- The carry banner is the one that settles it. It is on screen exactly
	-- when this one is -- a thief holding loot during a pursuit -- so the two
	-- have to stack rather than share, and this goes below it.
	-- ONE WIDGET FOR BOTH, TWO INSTANCES OF IT.
	--
	-- These were two hand-built frames at one anchor -- 38 tall with ink type
	-- and a hardcoded string for the patrol, 44 with a badge and a progress
	-- groove for the event -- and the note that used to sit here argued they
	-- had to stay separate because "an event is not a patrol" and because "the
	-- patrol's row is measured and verified, and every event feature would have
	-- to keep re-clearing that".
	--
	-- THAT ARGUMENT WAS ABOUT THE GEOMETRY, AND THE GEOMETRY IS SHARED NOW. Its
	-- second half is simply gone: there is one measured row in one file, so
	-- nothing has to re-clear anything. Its first half survives and is carried
	-- by the CONTENT rather than by the frame -- a patrol is blue with a car on
	-- it, an event is its own tone with its own icon -- which is how
	-- `Config.NOTIFY` already tells nine kinds of toast apart without nine
	-- widgets.
	--
	-- STILL TWO INSTANCES RATHER THAN ONE, because that is the rule this row
	-- already keeps: two things that can never both be live share a SLOT. The
	-- exclusivity is untouched -- `EventService.isEventLive` suppresses the
	-- patrol for an event's whole length -- and hiding the loser below is the
	-- same belt and braces it always was.
	local banner = Announce.new(gui, "StreetBanner", 200)
	local eventBanner = Announce.new(gui, "EventBanner", 200)

	-- ============================================================
	-- THE STANDING COUNTDOWN
	-- ============================================================
	--
	-- ALWAYS ON SCREEN WHILE THE STREET IS QUIET, counting down to the next
	-- event. Every other alert in this game reports something that has already
	-- happened or is happening; this is the only thing on the HUD that gives a
	-- player a reason to still be here in ten minutes.
	--
	-- IT NEEDED NO NEW SERVER STATE, which is worth saying because it looks
	-- like it should. `EventService` already sets the quiet stretch as a PHASE
	-- with its own deadline -- `setPhase("quiet", "", period - warning)` -- and
	-- already pushes seconds left and, since the banner wanted it, seconds
	-- total. The client was receiving the whole countdown and dropping it on
	-- the floor, because the render branch opened with `if phase ~= "quiet"`.
	--
	-- IN THE LEFT MENU RAIL, WHICH REVERSES WHERE THIS USED TO LIVE.
	--
	-- It sat under the piggy bank panel on the argument that a standing
	-- readout belongs with the other standing readout. That was right about
	-- what KIND of thing it is and wrong about which family it joins: the
	-- top-right corner is the BALANCE, and a second paper card hanging off
	-- the same right edge saying something unrelated to the balance is what
	-- made that column read as clutter rather than as a column. The rail
	-- below Shop / Stuff / Options is where this game keeps the things that
	-- are always there and are not about money, so the countdown is drawn in
	-- that vocabulary and takes the slot the boost token used to have.
	local nextEventChip = require(ReplicatedStorage.Shared.HUDWidgets).event(gui)

	-- The server sends seconds LEFT, never a deadline: os.clock() is a
	-- different number on every machine, so a timestamp would count down from
	-- somewhere random. Same reason the dodge cooldown is pushed as a duration.
	local patrol = { phase = "quiet", endsAt = 0 }

	-- THE EVENT SHARES THIS FRAME, it does not get a second one.
	--
	-- The top-centre column is full and measured -- coins 16, rebirth 96,
	-- carry 140..192, this 200..238 -- and a fourth row lands 35% of the way
	-- down a phone held sideways. Two controls that can never both be live
	-- share a slot, which is the rule the dodge and the trick button already
	-- follow, and `EventService.isEventLive` is what makes that true here:
	-- the patrol waits out any event, so there is never a frame where both
	-- want to say something.
	--
	-- The priority below is therefore belt and braces rather than a design:
	-- if the invariant ever breaks, the bigger news wins and nothing overlaps.
	local event = { phase = "quiet", name = "", next = "", endsAt = 0, total = 0 }

	Remotes.get("EventState").OnClientEvent:Connect(function(state)
		event.phase = state.phase
		event.name = state.event or ""
		-- The event the server has already rolled for the end of this quiet
		-- stretch, so the countdown can show what it is counting down to.
		-- Empty outside the quiet, and empty on a build whose server has not
		-- been updated -- which the chip renders as the generic bell rather
		-- than as a blank tile.
		event.next = state.nextEvent or ""
		event.endsAt = os.clock() + (state.secondsLeft or 0)
		-- Guarded against zero: this divides the bar, and a phase pushed
		-- without a total would put a nan into a UDim2 rather than erroring.
		event.total = math.max(state.secondsTotal or 0, 0.01)
		-- Ducked like the patrol, and for the same reason: a raid is published
		-- ahead precisely so staying out is a choice, and music over the top
		-- of the warning takes that choice back.
		if state.phase ~= "quiet" then
			Music.duck((state.secondsLeft or 0) + 3)
		end
	end)

	Remotes.get("PoliceState").OnClientEvent:Connect(function(state)
		patrol.phase = state.phase
		patrol.endsAt = os.clock() + (state.secondsLeft or 0)

		-- THE SCORE GETS OUT OF THE WAY OF THE PATROL. The siren is published
		-- fifteen seconds ahead precisely so a robbery during one is a choice,
		-- and music over the top of it takes that choice back. Ducked for the
		-- whole phase plus a moment, so it does not swell back up between the
		-- warning and the car arriving.
		if state.phase ~= "quiet" then
			Music.duck((state.secondsLeft or 0) + 3)
		end
	end)

	-- ONE TABLE RATHER THAN TWO LOCALS, because this chunk is at Luau's
	-- 200-register ceiling and has died there twice: once allocating
	-- `dayLabel` and once allocating `buildBustScene`, both naming a
	-- variable thousands of lines from the change and both taking the
	-- WHOLE HUD rather than the feature.
	-- REQUIRED INSIDE THIS FUNCTION FOR THE SAME REASON. A require at the top
	-- level costs the chunk a register it does not have; a function body gets
	-- its own file, so the whole cue system costs the top level nothing. Same
	-- call `HouseFX`, `AdminPanel` and `Wanted` already make.
	local SoundKit = require(ReplicatedStorage.Shared.SoundKit)

	local eventCue = { phase = "", tick = nil :: number? }
	RunService.Heartbeat:Connect(function()
		-- THE STANDING COUNTDOWN, while nothing is actually happening.
		--
		-- Gated on the quiet stretch being a REAL one rather than on the phase
		-- name alone, and that is not defensive tidiness -- it is two live
		-- cases. A client that has not received its first push yet has total 0
		-- and would render "0:00" as though an event were overdue. And the
		-- scheduler stamps a two-second `setPhase("quiet", "", 2)` on the way
		-- out of an event before the loop sets the real fifteen minutes, so
		-- for up to a frame the honest reading of the pushed state is "next
		-- event in 2s". Testing the SPAN against the warning window rules out
		-- both with one comparison.
		--
		-- THE PATROL TAKES THIS WIDGET WHILE IT RUNS. The sirens, the cruise
		-- and a pursuit used to draw their own ribbon in the middle of the
		-- screen; they draw here now (below), so for those forty-odd seconds
		-- the countdown steps aside and comes back when the car has gone. The
		-- same goes for an event's warning and run.
		local quietSpan = if event.phase == "quiet" then event.total else 0
		if quietSpan > Config.EVENTS.warning then
			local left = math.max(0, event.endsAt - os.clock())
			nextEventChip.Visible = true
			require(ReplicatedStorage.Shared.HUDWidgets).renderEvent(
				nextEventChip, left, event.total, left <= Config.EVENT_SOON, event.next)
		elseif nextEventChip.Visible then
			nextEventChip.Visible = false
		end

		-- The event owns the row whenever it has anything to say. The two are
		-- mutually exclusive by construction -- an event suppresses the patrol
		-- for its whole length -- so hiding the other one here is belt and
		-- braces: if that invariant ever breaks, the bigger news wins and
		-- nothing overlaps.
		--
		-- Drawn only for an event this build has a row for. A new event with
		-- no `Config.EVENT_UI` entry falls through to the patrol rather than
		-- rendering as an unnamed grey bar, which is the louder failure and
		-- the easier one to notice.
		local ui = if event.phase ~= "quiet" then Config.eventUI(event.name) else nil
		if ui then
			local left = math.max(0, event.endsAt - os.clock())

			-- THE ALARM FIRES ON THE TRANSITION, NEVER ON THE PHASE. This
			-- block runs every frame, so testing `phase == "warning"` would
			-- play a klaxon sixty times a second; what has to be detected is
			-- the phase CHANGING, which means remembering the last one. Same
			-- shape as the crack's slice click and for the same reason -- the
			-- server pushes a state, not an event.
			--
			-- IT IS PER VIEWER AND CLIENT-SIDE, like the moat and the animated
			-- skins: the server publishes the phase and its deadline and every
			-- machine decides for itself what to play. Nothing about a cue
			-- needs to replicate.
			if event.phase ~= eventCue.phase then
				if event.phase == "warning" then
					SoundKit.ui(Config.SOUNDS.EVENT_ALARM,
						{ name = "EventCue", volume = 0.45 })
				end
				eventCue.phase = event.phase
				eventCue.tick = nil
			end

			-- THE TICK IS THE LAST FEW SECONDS AND NOT THE WHOLE WARNING.
			-- `Config.EVENT_TICK_FROM` is five against a twenty-second warning,
			-- because a tick running the whole way is a metronome nobody can
			-- switch off -- the same argument the coin drip's own comment makes
			-- about anything louder becoming nagging.
			--
			-- ONE PER WHOLE SECOND, keyed on the ceiling of what is left rather
			-- than on a timer: the countdown the player is reading and the
			-- sound they are hearing then come off the same number and cannot
			-- disagree, which is what a separate clock would eventually do.
			if event.phase == "warning" and left <= Config.EVENT_TICK_FROM then
				local second = math.ceil(left)
				if second > 0 and second ~= eventCue.tick then
					eventCue.tick = second
					SoundKit.ui(Config.SOUNDS.CLICK,
						{ name = "EventTick", volume = 0.3, pitch = 1.15 })
				end
			end
			banner:set(nil)
			-- The roster is where an event's display name lives, so it is read
			-- rather than copied into EVENT_UI beside the glyph. It is read
			-- DEFENSIVELY though: the guard above is on EVENT_UI, so a row
			-- added to one table and not the other would index a nil here and
			-- take the whole HUD loop with it.
			local entry = Config.EVENTS.roster[event.name]
			local warning = event.phase == "warning"
			-- THE TOP WIDGET CARRIES THE EVENT NOW, not a ribbon in the middle
			-- of the screen. The designer's call: every timed announcement
			-- looks like the next-event countdown, which already sits at the
			-- top out of the way. WHAT IT IS in the name, HOW LONG on the clock,
			-- unfolded, and breathing only during the warning -- a live event is
			-- a standing readout and flashing for three minutes is wallpaper.
			eventBanner:set(nil)
			nextEventChip.Visible = true
			require(ReplicatedStorage.Shared.HUDWidgets).renderStatus(nextEventChip, {
				art = event.name,
				image = ui.icon,
				name = if warning then ((entry and entry.name) or event.name) else ui.live,
				seconds = left,
				tone = ui.tone,
				alert = true,
				pulse = warning,
			})
			return
		end
		eventBanner:set(nil)

		if patrol.phase == "quiet" then
			banner:set(nil)
			return
		end

		local left = math.max(0, patrol.endsAt - os.clock())

		-- THE THREE PHASES ARE THREE ROWS IN `Config.ANNOUNCE` NOW, not three
		-- branches each writing its own colour. What that bought beyond the
		-- tidying is a palette fix: the routine cruise used to draw in the same
		-- `Theme.STOP` red as a PURSUIT, so the street's heartbeat and somebody
		-- actually being hunted were one colour. This project's own palette rule
		-- reads "blue the police", so the car going past is blue, the sirens
		-- warning of one are orange, and only a pursuit is red.
		local key = if patrol.phase == "pursuit" then "pursuit"
			elseif patrol.phase == "warning" then "sirens"
			else "patrol"
		local row = Config.announce(key)
		if not row then
			-- A phase this build has no row for draws NOTHING rather than an
			-- unnamed grey bar, which is the louder failure and the easier one
			-- to notice. Same guard the event branch above makes on EVENT_UI.
			banner:set(nil)
			return
		end
		-- THE PATROL IS IN THE TOP WIDGET TOO, for the same reason as the
		-- event above: one place, one look, out of the middle of the screen.
		-- A beacon for the sirens and a pursuit, the car for the cruise; the
		-- two loud phases breathe and the routine cruise does not, because
		-- that one is on screen for forty-five seconds and is the street's own
		-- heartbeat. Written as what DOES pulse, so a renamed third phase
		-- cannot silently turn the cruise into an alarm.
		banner:set(nil)
		nextEventChip.Visible = true
		require(ReplicatedStorage.Shared.HUDWidgets).renderStatus(nextEventChip, {
			art = if key == "patrol" then "car" else "siren",
			image = if row.icon ~= "" then row.icon else nil,
			name = if key == "pursuit" then "LOSE THEM"
				elseif key == "sirens" then "SIRENS"
				else "PATROL",
			seconds = left,
			tone = row.tone,
			alert = true,
			pulse = patrol.phase == "pursuit" or patrol.phase == "warning",
		})
	end)

	-- The light bar, driven HERE rather than on the server.
	--
	-- Same rule as the animated skins and the moat: a flash is a colour and a
	-- transparency write per lamp per frame, and replicating that would be
	-- property updates every frame to say something every machine can work out
	-- from a clock and a phase offset. The server publishes the offset once,
	-- as an attribute, and nothing else.
	--
	-- Found by tag rather than collected at startup, because the car is built
	-- when a patrol begins and destroyed when it ends -- there is nothing to
	-- collect when this runs.
	local lamps: { [BasePart]: boolean } = {}

	local function watchLamp(part: Instance)
		if part:IsA("BasePart") then
			lamps[part] = true
		end
	end

	for _, part in ipairs(CollectionService:GetTagged("PoliceLamp")) do
		watchLamp(part)
	end
	CollectionService:GetInstanceAddedSignal("PoliceLamp"):Connect(watchLamp)
	CollectionService:GetInstanceRemovedSignal("PoliceLamp"):Connect(function(part)
		lamps[part :: BasePart] = nil
	end)

	RunService.Heartbeat:Connect(function()
		for part in pairs(lamps) do
			if not part.Parent then
				lamps[part] = nil
			else
				local offset = part:GetAttribute("Phase") or 0
				local tone = part:GetAttribute("Tone") or Color3.new(1, 1, 1)
				-- A short bright blip and a long dark gap, rather than an even
				-- flash: it is what makes red and blue alternate legibly at
				-- distance instead of blurring into one mauve smear.
				local on = ((os.clock() * 2.4 + offset) % 1) < 0.32
				part.Transparency = if on then 0 else 0.72
				part.Color = if on then tone else (tone :: Color3):Lerp(Color3.new(0, 0, 0), 0.6)
			end
		end
	end)
end

-- ============================================================
-- THE ARREST
-- ============================================================
--
-- Getting caught used to be a toast that said BUSTED and a number, which is
-- the same information and none of the event. This is the scene: the flash,
-- the mugshot, the stamp, the bail.
--
-- IT IS AN ORIGINAL, and that is a shipping rule rather than a preference.
-- The obvious reference here is somebody else's property -- a specific
-- wordmark in a specific typeface over a specific desaturated screen, plus
-- its audio -- and Roblox moderation strips branded assets with the penalty
-- landing on the EXPERIENCE, not the one screen. So this borrows the LAYOUT,
-- which is a genre: a height chart, a headshot, a name board and a stamp.
-- The palette is the game's own navy and gold, and the sting is a cell door
-- rather than a drone -- which is funnier, is nobody's, and says "sentenced"
-- instead of "you died", in a game where nothing kills anybody.
--
-- IT IS EXACTLY AS LONG AS THE DETENTION. Every beat is derived from
-- Config.STUN_SECONDS, so the card clears at about the moment the player gets
-- their legs back. A cutscene that outlasts the thing it is narrating is
-- taking away time somebody could have been playing; this one only fills time
-- they had already lost. Change STUN_SECONDS and the scene follows.
--
-- It can also be dismissed early with any input after the stamp has landed.
-- The drama is the point, but it is still their game.
--
-- Wrapped in a function because the chunk is near Luau's 200-register ceiling
-- and this section alone declares about thirty locals. A function body gets
-- its own register file, so it costs the chunk one.
local function buildBustScene()
	local SoundService = game:GetService("SoundService")

	-- Exact, with separators. `format` abbreviates -- 3,000 coins shown as
	-- "3.0K" reads as a statistic, where "3,000" reads as a fine, and this
	-- card is the one place in the HUD that wants the second thing.
	local function exact(value: number): string
		local text = tostring(math.floor(value))
		local out = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		return (out:gsub("^,", ""))
	end

	local function sfx(id: string, volume: number): Sound
		local sound = Instance.new("Sound")
		sound.SoundId = id
		sound.Volume = volume
		sound.Parent = SoundService
		return sound
	end

	local shutter = sfx(Config.SOUNDS.SHUTTER, 0.65)
	local cellDoor = sfx(Config.SOUNDS.CELL_DOOR, 0.8)

	-- Tolerates an empty SoundId, like every other sound player in this
	-- project: the ids are third-party and can be moderated away, and a
	-- scene that errors is worse than a scene that is quiet.
	local function blast(sound: Sound)
		if sound.SoundId ~= "" then
			sound.TimePosition = 0
			sound:Play()
		end
	end

	-- ---------------------------------------------------------- the scrim
	local scene = Instance.new("Frame")
	scene.Name = "BustScene"
	scene.Size = UDim2.fromScale(1, 1)
	scene.BackgroundColor3 = Color3.fromRGB(11, 7, 5)
	scene.BackgroundTransparency = 1
	scene.BorderSizePixel = 0
	scene.Visible = false
	scene.ZIndex = 50
	scene.Parent = gui

	-- --------------------------------------------------------- the card
	local card = Instance.new("Frame")
	card.Size = UDim2.new(0, 480, 0, 302)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.BackgroundColor3 = Color3.fromRGB(57, 38, 23)
	card.BorderSizePixel = 0
	card.ZIndex = 51
	card.Parent = scene
	corner(card, 16)

	local cardScale = Instance.new("UIScale")
	cardScale.Scale = 0.86
	cardScale.Parent = card

	local strip = Instance.new("Frame")
	strip.Size = UDim2.new(1, -28, 0, 30)
	strip.Position = UDim2.new(0, 14, 0, 12)
	strip.BackgroundTransparency = 1
	strip.ZIndex = 52
	strip.Parent = card

	local force = Instance.new("TextLabel")
	force.Size = UDim2.new(0.6, 0, 1, 0)
	force.BackgroundTransparency = 1
	force.Font = Enum.Font.FredokaOne
	force.TextSize = 20
	force.TextColor3 = GOLD
	force.TextXAlignment = Enum.TextXAlignment.Left
	force.Text = "PIGGY PATROL"
	force.ZIndex = 52
	force.Parent = strip

	local caseNo = Instance.new("TextLabel")
	caseNo.Size = UDim2.new(0.4, 0, 1, 0)
	caseNo.Position = UDim2.new(0.6, 0, 0, 0)
	caseNo.BackgroundTransparency = 1
	caseNo.Font = Enum.Font.Code
	caseNo.TextSize = 16
	caseNo.TextColor3 = Theme.MUTED_LIGHT
	caseNo.TextXAlignment = Enum.TextXAlignment.Right
	caseNo.Text = "CASE #0000"
	caseNo.ZIndex = 52
	caseNo.Parent = strip

	-- ------------------------------------------------- the photo, with chart
	local photo = Instance.new("Frame")
	photo.Size = UDim2.new(0, 170, 0, 200)
	photo.Position = UDim2.new(0, 14, 0, 48)
	photo.BackgroundColor3 = Color3.fromRGB(220, 210, 203)
	photo.BorderSizePixel = 0
	photo.ClipsDescendants = true
	photo.ZIndex = 52
	photo.Parent = card
	corner(photo, 8)

	-- The height chart. It is the single element that makes a headshot read
	-- as a mugshot rather than as a profile picture, and it is drawn rather
	-- than built for the same reason the car's door roundel is.
	for i = 1, 6 do
		local rule = Instance.new("Frame")
		rule.Size = UDim2.new(1, 0, 0, 2)
		rule.Position = UDim2.new(0, 0, 0, 14 + (i - 1) * 31)
		rule.BackgroundColor3 = Theme.MUTED
		rule.BorderSizePixel = 0
		rule.ZIndex = 52
		rule.Parent = photo

		local tick = Instance.new("TextLabel")
		tick.Size = UDim2.new(0, 26, 0, 14)
		tick.Position = UDim2.new(0, 4, 0, 16 + (i - 1) * 31)
		tick.BackgroundTransparency = 1
		tick.Font = Enum.Font.Code
		tick.TextSize = 11
		tick.TextColor3 = Theme.MUTED
		tick.TextXAlignment = Enum.TextXAlignment.Left
		tick.Text = ("%d'"):format(7 - i)
		tick.ZIndex = 52
		tick.Parent = photo
	end

	-- rbxthumb rather than GetUserThumbnailAsync: the content URL resolves
	-- itself and never yields, so the scene cannot be held up waiting on a
	-- web call at the exact moment it is supposed to slam onto the screen.
	local mug = Instance.new("ImageLabel")
	mug.Size = UDim2.new(0, 168, 0, 168)
	mug.Position = UDim2.new(0.5, 0, 0, 28)
	mug.AnchorPoint = Vector2.new(0.5, 0)
	mug.BackgroundTransparency = 1
	mug.ScaleType = Enum.ScaleType.Fit
	mug.ZIndex = 53
	mug.Parent = photo

	-- --------------------------------------------------- the name board
	local board = Instance.new("Frame")
	board.Size = UDim2.new(0, 268, 0, 200)
	board.Position = UDim2.new(0, 198, 0, 48)
	board.BackgroundColor3 = Color3.fromRGB(43, 29, 17)
	board.BorderSizePixel = 0
	board.ZIndex = 52
	board.Parent = card
	corner(board, 8)

	local plate = Instance.new("Frame")
	plate.Size = UDim2.new(1, -24, 0, 54)
	plate.Position = UDim2.new(0, 12, 0, 14)
	plate.BackgroundColor3 = Color3.fromRGB(247, 240, 235)
	plate.BorderSizePixel = 0
	plate.ZIndex = 53
	plate.Parent = board
	corner(plate, 6)

	local who = Instance.new("TextLabel")
	who.Size = UDim2.new(1, -16, 1, -10)
	who.Position = UDim2.new(0, 8, 0, 5)
	who.BackgroundTransparency = 1
	who.Font = Enum.Font.FredokaOne
	who.TextColor3 = Color3.fromRGB(47, 32, 20)
	-- TextScaled implies wrapping, and writing TextWrapped next to it turns
	-- scaling back off. The plate is given the height a wrapped name needs
	-- instead.
	who.TextScaled = true
	who.Text = "?"
	who.ZIndex = 53
	who.Parent = plate

	local rows = Instance.new("Frame")
	rows.Size = UDim2.new(1, -24, 0, 112)
	rows.Position = UDim2.new(0, 12, 0, 78)
	rows.BackgroundTransparency = 1
	rows.ZIndex = 53
	rows.Parent = board

	local rowList = Instance.new("UIListLayout")
	rowList.Padding = UDim.new(0, 6)
	rowList.Parent = rows

	local function chargeRow(order: number, key: string): TextLabel
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0, 24)
		row.LayoutOrder = order
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.Code
		row.TextSize = 15
		row.TextColor3 = Theme.MUTED_LIGHT
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Text = key
		row.ZIndex = 53
		row.Parent = rows
		return row
	end

	chargeRow(1, "CHARGE   ROBBERY")
	local victimRow = chargeRow(2, "VICTIM   --")
	local recoveredRow = chargeRow(3, "SEIZED   --")

	-- --------------------------------------------------- the bail strip
	local bailStrip = Instance.new("Frame")
	bailStrip.Size = UDim2.new(1, -28, 0, 34)
	bailStrip.Position = UDim2.new(0, 14, 0, 256)
	bailStrip.BackgroundColor3 = Color3.fromRGB(32, 21, 12)
	bailStrip.BorderSizePixel = 0
	bailStrip.ZIndex = 52
	bailStrip.Parent = card
	corner(bailStrip, 8)

	local bailKey = Instance.new("TextLabel")
	bailKey.Size = UDim2.new(0.5, 0, 1, 0)
	bailKey.Position = UDim2.new(0, 12, 0, 0)
	bailKey.BackgroundTransparency = 1
	bailKey.Font = Enum.Font.Code
	bailKey.TextSize = 15
	bailKey.TextColor3 = Theme.MUTED_LIGHT
	bailKey.TextXAlignment = Enum.TextXAlignment.Left
	bailKey.Text = "BAIL PAID FROM YOUR PIGGY BANK"
	bailKey.ZIndex = 52
	bailKey.Parent = bailStrip

	local bailValue = Instance.new("TextLabel")
	bailValue.Size = UDim2.new(0.5, -24, 1, 0)
	bailValue.Position = UDim2.new(0.5, 12, 0, 0)
	bailValue.BackgroundTransparency = 1
	bailValue.Font = Enum.Font.FredokaOne
	bailValue.TextSize = 22
	bailValue.TextColor3 = GOLD
	bailValue.TextXAlignment = Enum.TextXAlignment.Right
	bailValue.Text = "0"
	bailValue.ZIndex = 52
	bailValue.Parent = bailStrip

	-- ------------------------------------------------------- the stamp
	local stamp = Instance.new("TextLabel")
	-- ON THE PHOTOGRAPH, not across the card. Centred on the card it looked
	-- better and sat straight over the CHARGE row, which is the one line that
	-- says what you actually did. The mugshot panel spans x 14..184, so a
	-- 184-wide stamp centred on it clears the board text at x=210 even with
	-- the rotation bleed (a 58-tall box turned 8 degrees reaches about four
	-- pixels further each side than its width suggests). It is also where a
	-- stamp belongs: on the picture.
	stamp.Size = UDim2.new(0, 184, 0, 58)
	stamp.Position = UDim2.new(0, 99, 0, 148)
	stamp.AnchorPoint = Vector2.new(0.5, 0.5)
	stamp.Rotation = -8
	stamp.BackgroundTransparency = 1
	stamp.Font = Enum.Font.FredokaOne
	stamp.TextScaled = true
	stamp.TextColor3 = Theme.STOP
	stamp.TextStrokeColor3 = Color3.fromRGB(255, 236, 232)
	stamp.TextStrokeTransparency = 0.15
	stamp.Text = "BUSTED"
	stamp.ZIndex = 60
	stamp.Parent = card

	local stampScale = Instance.new("UIScale")
	stampScale.Scale = 2.4
	stampScale.Parent = stamp

	local hint = Instance.new("TextLabel")
	hint.Size = UDim2.new(0, 300, 0, 22)
	hint.Position = UDim2.new(0.5, 0, 0.5, 172)
	hint.AnchorPoint = Vector2.new(0.5, 0.5)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Code
	hint.TextSize = 14
	hint.TextColor3 = Theme.MUTED
	hint.TextTransparency = 1
	hint.Text = "tap to continue"
	hint.ZIndex = 51
	hint.Parent = scene

	-- ------------------------------------------------------- the flash
	-- Last child and highest ZIndex: it has to cover the card it is
	-- revealing, or the photo is visible a frame before it is taken.
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.ZIndex = 70
	flash.Parent = scene

	-- ---------------------------------------------------------- playback
	--
	-- One table, not a dozen locals -- the register budget is spent by more
	-- than one feature at a time. `token` is what makes a second arrest
	-- during the first one safe: every delayed beat checks it still owns the
	-- scene before touching anything.
	local bust = { token = 0, running = false, tick = nil :: RBXScriptConnection?,
		from = 0, skipAt = 0, pulse = nil :: Tween? }

	local function finish(token: number)
		if bust.token ~= token then
			return
		end
		bust.running = false
		if bust.tick then
			bust.tick:Disconnect()
			bust.tick = nil
		end
		-- Cancelled before the fade, or a looping tween keeps writing
		-- TextTransparency and the prompt never goes out.
		if bust.pulse then
			bust.pulse:Cancel()
			bust.pulse = nil
		end
		local out = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(scene, out, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(cardScale, out, { Scale = 0.9 }):Play()
		TweenService:Create(hint, out, { TextTransparency = 1 }):Play()
		task.delay(0.5, function()
			if bust.token == token then
				scene.Visible = false
			end
		end)
	end

	local function play(payload: any)
		if type(payload) ~= "table" then
			return
		end
		bust.token += 1
		local token = bust.token
		bust.running = true
		if bust.tick then
			bust.tick:Disconnect()
			bust.tick = nil
		end

		local bail = math.max(0, tonumber(payload.bail) or 0)
		local recovered = math.max(0, tonumber(payload.recovered) or 0)

		mug.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=420&h=420"):format(
			Players.LocalPlayer.UserId)
		who.Text = Players.LocalPlayer.DisplayName
		-- Stable per arrest and meaningless on purpose: a case number is set
		-- dressing, and deriving one from anything real would invite a player
		-- to read it as a score.
		caseNo.Text = ("CASE #%04d"):format(math.random(1, 9999))
		victimRow.Text = ("VICTIM   %s"):format(payload.victim or "--")
		recoveredRow.Text = if recovered > 0
			then ("SEIZED   %s coins"):format(exact(recovered))
			else "SEIZED   nothing -- already delivered"
		bailValue.Text = "0"

		-- Beat one: the photograph. Everything else is revealed under it.
		scene.Visible = true
		scene.BackgroundTransparency = 1
		flash.BackgroundTransparency = 0
		cardScale.Scale = 0.86
		stampScale.Scale = 2.4
		stamp.TextTransparency = 1
		hint.TextTransparency = 1
		blast(shutter)

		TweenService:Create(scene, TweenInfo.new(0.3), { BackgroundTransparency = 0.35 }):Play()
		TweenService:Create(flash, TweenInfo.new(0.4, Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(cardScale, TweenInfo.new(0.45, Enum.EasingStyle.Back,
			Enum.EasingDirection.Out), { Scale = 1 }):Play()

		-- Beat two: the stamp lands, and the cell door goes with it.
		task.delay(0.85, function()
			if bust.token ~= token then
				return
			end
			blast(cellDoor)
			stamp.TextTransparency = 0
			TweenService:Create(stampScale, TweenInfo.new(0.22, Enum.EasingStyle.Quint,
				Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end)

		-- Beat three: the bail counts up. A number that arrives already
		-- totalled is a fact; one that climbs is a bill being added up, and
		-- this is the moment the scene exists to sell.
		task.delay(1.35, function()
			if bust.token ~= token then
				return
			end
			local started = os.clock()
			local COUNT = 1.1
			bust.tick = RunService.Heartbeat:Connect(function()
				if bust.token ~= token then
					return
				end
				local through = math.min(1, (os.clock() - started) / COUNT)
				-- Eased out, so it decelerates onto the final figure rather
				-- than stopping dead on it.
				bailValue.Text = exact(bail * (1 - (1 - through) ^ 3))
				if through >= 1 and bust.tick then
					bust.tick:Disconnect()
					bust.tick = nil
				end
			end)
		end)

		-- The prompt appears exactly WHEN it becomes true, rather than sitting
		-- there through a window in which pressing something does nothing. A
		-- hint that lies for two seconds is worse than no hint.
		--
		-- And it PULSES, because the card is now genuinely waiting rather than
		-- counting down. A static line reads as decoration; a breathing one is
		-- the difference between "this will go away" and "this is waiting for
		-- you". Held on `bust` with everything else -- this file is one chunk
		-- against Luau's 200-local ceiling.
		bust.skipAt = os.clock() + Config.POLICE.arrestSkipAfter
		task.delay(Config.POLICE.arrestSkipAfter, function()
			if bust.token ~= token or not bust.running then
				return
			end
			hint.TextTransparency = 0.25
			bust.pulse = TweenService:Create(hint,
				TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut,
					-1, true),
				{ TextTransparency = 0.65 })
			;(bust.pulse :: Tween):Play()
		end)

		-- A BACKSTOP, NOT A BEAT. See Config.POLICE.arrestTimeout: the tap is
		-- what closes this, and thirty seconds only exists so a card cannot
		-- strand somebody whose input never arrives.
		task.delay(Config.POLICE.arrestTimeout, function()
			finish(token)
		end)
	end

	Remotes.get("PoliceBust").OnClientEvent:Connect(function(...)
		-- The shutter and the cell door are the whole beat of the scene, and
		-- it is derived from STUN_SECONDS -- so the duck is too, rather than
		-- being a number that drifts away from the thing it is covering.
		-- Covers the shutter and the cell door and a comfortable read, rather
		-- than the whole backstop -- ducking the score for thirty seconds
		-- because somebody left the card up would be a bug of its own.
		Music.duck(Config.POLICE.arrestSkipAfter + 4.5)
		play(...)
	end)

	-- Dismissable, but NOT INSTANTLY, and the gate is the whole fix. This
	-- handler used to fire from the frame the scene appeared: the comment said
	-- "once the stamp has landed" and nothing enforced it, so the movement key
	-- the player was already holding -- they were running from the police --
	-- dismissed the scene before it had drawn a single beat.
	UserInputService.InputBegan:Connect(function(_, processed)
		if bust.running and not processed and scene.Visible
			and os.clock() >= bust.skipAt then
			finish(bust.token)
		end
	end)
end

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
--
-- Every message the game sends a player, and the sound it makes arriving.
--
-- WHAT THIS REPLACED: one grey bar that faded in, held, and faded out. Two
-- colours for a hundred and thirty different events, no sound at all, and a
-- second message REPLACED the first rather than queueing -- which mattered
-- most exactly when it hurt most, because a robbery fires three notifications
-- in about a second and you would see only the last of them.
--
-- Three things fix that, and the third is the one that matters:
--
--   * They STACK. Up to four, newest at the top, each on its own clock. A
--     UIListLayout does the reflow, so nothing here positions anything.
--   * They are TYPED. `Config.NOTIFY` gives each kind a colour, a glyph, a
--     headline and a sound, so banking coins and being robbed no longer look
--     alike. Adding a kind there upgrades every call site already using it.
--   * The three urgent kinds FLASH THE SCREEN EDGES. A toast in a corner is
--     the wrong instrument for "a dog is on you" -- the player is running and
--     looking at the world, not at the HUD.
--
-- TOP LEFT, and that is not a style choice. The top-centre column was full to
-- the point of collision -- coin badge 16..78, rebirth 96..148, carry
-- 140..192, patrol 200..238 -- and the old toast sat at 88, which put it
-- straight through the rebirth button. The left edge is empty from the topbar
-- down to the garage slot, which is room for four cards and no neighbours to
-- fight. The badge has since merged into the piggy bank panel and freed the
-- top of that column, which does NOT invite the toasts back: a card that
-- appears and disappears under a button somebody is aiming at is the same
-- collision waiting for whatever fills 16..90 next.
--
-- Wrapped in a function because this chunk is near Luau's 200-local ceiling.
local function buildNotifications()
	local SoundService = game:GetService("SoundService")

	-- One Sound per kind, built once. Two toasts of a kind in quick
	-- succession restart it rather than layering, which is what you want:
	-- three overlapping alarms is noise, not urgency.
	local voices: { [string]: Sound } = {}
	for kind, spec in pairs(Config.NOTIFY) do
		local id = spec.sound and Config.SOUNDS[spec.sound]
		if id and id ~= "" then
			local sound = Instance.new("Sound")
			sound.Name = kind
			sound.SoundId = id
			sound.Volume = spec.volume or 0.4
			sound.Parent = SoundService
			voices[kind] = sound
		end
	end

	local function blast(kind: string)
		local sound = voices[kind]
		if sound then
			sound.TimePosition = 0
			sound:Play()
		end
	end

	-- ------------------------------------------------------- the stack
	local stack = Instance.new("Frame")
	stack.Name = "Notifications"
	stack.Size = UDim2.new(0, 330, 0, 0)
	-- y=72 for the same reason the piggy bank panel uses it: IgnoreGuiInset
	-- is on, so y=0 is UNDER the topbar rather than below it, measured at a
	-- 58px inset. The corners are where the topbar's own buttons live.
	stack.Position = UDim2.new(0, 18, 0, 72)
	stack.BackgroundTransparency = 1
	stack.AutomaticSize = Enum.AutomaticSize.Y
	-- ABOVE THE MENU LAYER, the one HUD element that is. A shop refusal ("Need
	-- 2K more coins") lands here while the shop is open over this corner, and
	-- a refusal hidden behind the menu that caused it is a silent failure.
	stack.ZIndex = Theme.MENU_Z + 1
	stack.Parent = gui

	local stackList = Instance.new("UIListLayout")
	stackList.Padding = UDim.new(0, 8)
	stackList.SortOrder = Enum.SortOrder.LayoutOrder
	stackList.Parent = stack

	-- ------------------------------------------------- the edge flash
	--
	-- Four bands, each fading inward, so the colour hugs the frame and leaves
	-- the middle of the screen -- where the player is actually looking --
	-- completely clear. Built once and reused.
	--
	-- EVERY ONE OF THE FOUR WAS INSIDE OUT, and that is the whole of why this
	-- read as a square laid over the screen rather than as a glow round the
	-- edge of it. The keypoints ran (0, transparency 1) to (1, transparency
	-- 0) -- invisible at gradient offset 0, opaque at offset 1 -- while every
	-- `rot` here points offset 0 AT THE SCREEN EDGE. So each band was
	-- invisible where it touched the frame and solid along its INNER lip, and
	-- the four together drew a bright rectangle outline floating 120 pixels
	-- inside the screen. Measured on the live HUD: top band rotation 90 with
	-- keys `0 1 0 / 1 0 0`, and the same 180-degree error on all four.
	--
	-- Fixed by flipping the SEQUENCE rather than the rotations, so `rot` keeps
	-- meaning the one readable thing -- from the screen edge inward.
	--
	-- THE RAMP IS A CURVE, NOT A LINE, AND THAT IS WHAT KILLS THE SEAMS.
	-- A straight ramp reaches zero with its slope still on, which the eye
	-- reads as a crease (a Mach band) exactly where the band stops -- a
	-- straight line right across the screen. It shows up twice over: once at
	-- each band's inner lip, and again down the line where a side band stops
	-- overlapping a top one, because the sum of two linear ramps has a kink
	-- there. The curve below is alpha = (1 - t)^2, whose slope is ZERO at the
	-- inner end, so both creases go: the bands melt out instead of stopping,
	-- and the corners -- where two of them multiply -- come out as a rounded
	-- falloff rather than a denser square.
	--
	-- DEPTH IS A FRACTION OF THE SCREEN, not 120 pixels. A fixed depth is a
	-- different vignette on every device: 120 was 18% of this window's height
	-- and 8% of its width, which is part of why the sides read as stripes
	-- while the top read as a band.
	local edges: { Frame } = {}

	local ramp = {}
	for i = 0, 7 do
		local t = i / 7
		table.insert(ramp, NumberSequenceKeypoint.new(t, 1 - (1 - t) ^ 2))
	end

	for _, side in ipairs({
		{ size = UDim2.new(1, 0, 0.26, 0), pos = UDim2.new(0, 0, 0, 0), rot = 90 },
		{ size = UDim2.new(1, 0, 0.26, 0), pos = UDim2.new(0, 0, 0.74, 0), rot = 270 },
		{ size = UDim2.new(0.17, 0, 1, 0), pos = UDim2.new(0, 0, 0, 0), rot = 0 },
		{ size = UDim2.new(0.17, 0, 1, 0), pos = UDim2.new(0.83, 0, 0, 0), rot = 180 },
	}) do
		local edge = Instance.new("Frame")
		edge.Size = side.size
		edge.Position = side.pos
		edge.BackgroundColor3 = Theme.STOP
		edge.BackgroundTransparency = 1
		edge.BorderSizePixel = 0
		edge.ZIndex = 19
		edge.Parent = gui

		-- Opaque at the screen edge (offset 0, where `rot` points), gone by
		-- the inner lip.
		local fade = Instance.new("UIGradient")
		fade.Rotation = side.rot
		fade.Transparency = NumberSequence.new(ramp)
		fade.Parent = edge
		table.insert(edges, edge)
	end

	local flashToken = 0

	local function flash(tone: Color3)
		flashToken += 1
		local token = flashToken
		for _, edge in ipairs(edges) do
			edge.BackgroundColor3 = tone
		end
		-- Two pulses, not a strobe. This fires on the three loudest events in
		-- the game and the audience is nine.
		for pulse = 0, 1 do
			task.delay(pulse * 0.42, function()
				if flashToken ~= token then
					return
				end
				for _, edge in ipairs(edges) do
					TweenService:Create(edge, TweenInfo.new(0.14), { BackgroundTransparency = 0.35 }):Play()
				end
				task.delay(0.16, function()
					if flashToken ~= token then
						return
					end
					for _, edge in ipairs(edges) do
						TweenService:Create(edge, TweenInfo.new(0.26), { BackgroundTransparency = 1 }):Play()
					end
				end)
			end)
		end
	end

	-- ------------------------------------------------------- one card
	local nextOrder = 0

	-- Counted off the stack itself rather than kept in a variable.
	--
	-- A counter desynced immediately: a card retired early by the cap still
	-- had its own fade-out scheduled, so it decremented twice and the count
	-- drifted below the truth until the cap stopped firing at all. Measured
	-- at five cards on screen against a limit of four. The children ARE the
	-- count and cannot disagree with themselves.
	local function liveCards(): number
		local n = 0
		for _, child in ipairs(stack:GetChildren()) do
			if child:IsA("Frame") then
				n += 1
			end
		end
		return n
	end

	local function show(message: string, kind: string?)
		local spec = Config.NOTIFY[kind or "good"] or Config.NOTIFY.good
		local tone = spec.tone

		-- Newest at the TOP, which is why the order counts down. A stack that
		-- grew downward would make the message you have already read the one
		-- nearest your eye.
		nextOrder -= 1

		-- FROSTED GLASS IN THE KIND'S OWN COLOUR. The card used to be opaque
		-- paper with a five-pixel stripe laid flat against its left edge, and
		-- a square stripe cannot follow a rounded corner: it ran straight past
		-- the curve at both ends. The colour now lives in things that ARE the
		-- card's shape -- a wash across the card's own background (a gradient
		-- on a rounded frame is clipped by its corner), a rim in the tone, and
		-- an accent CAPSULE inset from the edge, fully rounded, so it never
		-- meets a corner at all. Slightly see-through: it is a notice laid
		-- over the world, not a panel cut into it.
		local GLASS = 0.14
		local card = Instance.new("Frame")
		card.Name = "Toast"
		card.Size = UDim2.new(0, 330, 0, 0)
		card.AutomaticSize = Enum.AutomaticSize.Y
		card.LayoutOrder = nextOrder
		card.ZIndex = 20
		card.BackgroundColor3 = Theme.PAPER
		card.BackgroundTransparency = 1
		card.BorderSizePixel = 0
		card.Parent = stack
		Theme.corner(card, 18)
		local wash = Instance.new("UIGradient")
		wash.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Theme.PAPER:Lerp(tone, 0.34)),
			ColorSequenceKeypoint.new(0.32, Theme.PAPER:Lerp(tone, 0.1)),
			ColorSequenceKeypoint.new(1, Theme.PAPER),
		})
		-- Clearer toward the right, where the words already have contrast.
		wash.Transparency = NumberSequence.new(0, 0.1)
		wash.Parent = card
		local cardEdge = Instance.new("UIStroke")
		cardEdge.Color = tone:Lerp(Theme.INK, 0.45)
		cardEdge.Thickness = 2
		cardEdge.Transparency = 1
		cardEdge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		cardEdge.Parent = card
		-- Pops from slightly small, so it arrives rather than appears.
		local cardPop = Instance.new("UIScale")
		cardPop.Scale = 0.94
		cardPop.Parent = card

		-- The accent capsule: inset 6 from the left and 10 from top and
		-- bottom, and as round as it is wide, so it sits INSIDE the curve.
		-- Grows out from its middle on arrival.
		local stripe = Instance.new("Frame")
		stripe.Name = "Accent"
		stripe.AnchorPoint = Vector2.new(0, 0.5)
		stripe.Position = UDim2.new(0, 6, 0.5, 0)
		stripe.Size = UDim2.new(0, 4, 0, 0)
		stripe.BackgroundColor3 = tone
		stripe.BackgroundTransparency = 1
		stripe.BorderSizePixel = 0
		stripe.ZIndex = 21
		stripe.Parent = card
		Theme.corner(stripe, 2)

		-- HOW LONG IT HAS LEFT, drawn: a hairline along the bottom that runs
		-- out as the card's own clock does. Inset past both corners.
		local life = Instance.new("Frame")
		life.Name = "Life"
		life.AnchorPoint = Vector2.new(0, 1)
		life.Position = UDim2.new(0, 18, 1, -5)
		life.Size = UDim2.new(1, -36, 0, 3)
		life.BackgroundColor3 = tone
		life.BackgroundTransparency = 1
		life.BorderSizePixel = 0
		life.ZIndex = 21
		life.Parent = card
		Theme.corner(life, 2)

		-- A DARK DISC WITH A TONE RING, not a tone disc.
		--
		-- The chip used to be a solid block of the kind's colour with the
		-- glyph typeset over it in near-black, which works for "+" and stops
		-- working the moment the glyph is a real icon: an emoji carries its
		-- own colours and ignores TextColor3 entirely, so a red siren sat on a
		-- red disc and a gold money bag on a gold one. Dark behind, colour
		-- around, and every icon reads at any size.
		--
		-- The card loses nothing by it. The stripe down the left edge is what
		-- actually carries the colour, and it is the faster read of the two.
		-- ONE ROW, LAID OUT, RATHER THAN TWO THINGS POSITIONED BY HAND.
		--
		-- The chip used to sit at a fixed (15, 10) and the text column at a
		-- fixed (56, 10), which produced two separate faults that both read as
		-- "the icons are wrong":
		--
		--   * THE CARD WAS SHORTER THAN ITS OWN ICON. AutomaticSize measures
		--     children, and on a one-line message the tallest was the text
		--     column at 10 + 18 + 12 = 40 -- while the chip needed 10 + 32 =
		--     42. Measured at a 38px card holding a chip that wanted to reach
		--     42, so the icon hung out of the bottom of the card it was on.
		--   * NOTHING ALIGNED THEM. On a one-line card the text centre sat 6.4
		--     pixels ABOVE the icon's; on a title-plus-body card it sat 16.6
		--     BELOW, leaving the icon stranded at the top. Two hand-set
		--     offsets cannot both be right when one of the two things changes
		--     height and the other does not.
		--
		-- A horizontal UIListLayout with VerticalAlignment.Center fixes both at
		-- once and cannot drift: the row grows to whichever of the two is
		-- taller, the card grows to the row, and the shorter one is centred
		-- against it. Nothing here positions anything.
		--
		-- The stripe stays a direct child of the card, deliberately: a
		-- UIListLayout owns EVERY child of its parent, so an accent bar that
		-- has to hug the left edge cannot be a sibling of the row.
		local row = Instance.new("Frame")
		row.Name = "Row"
		row.Size = UDim2.new(1, 0, 0, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.BackgroundTransparency = 1
		row.ZIndex = 21
		row.Parent = card

		local rowPad = Instance.new("UIPadding")
		rowPad.PaddingTop = UDim.new(0, 12)
		rowPad.PaddingBottom = UDim.new(0, 14)
		rowPad.PaddingLeft = UDim.new(0, 18)
		rowPad.PaddingRight = UDim.new(0, 16)
		rowPad.Parent = row

		local rowList = Instance.new("UIListLayout")
		rowList.FillDirection = Enum.FillDirection.Horizontal
		rowList.VerticalAlignment = Enum.VerticalAlignment.Center
		rowList.Padding = UDim.new(0, 9)
		rowList.SortOrder = Enum.SortOrder.LayoutOrder
		rowList.Parent = row

		local chip = Instance.new("TextLabel")
		chip.LayoutOrder = 1
		chip.Size = UDim2.new(0, 34, 0, 34)
		chip.TextSize = 18
		chip.Text = spec.glyph or "!"
		chip.ZIndex = 22
		chip.Parent = row
		Theme.chip(chip, 34, tone)
		chip.BackgroundTransparency = 1
		chip.TextTransparency = 1

		local ring = Instance.new("UIStroke")
		ring.Color = tone
		ring.Thickness = 2
		ring.Transparency = 1
		ring.Parent = chip

		local chipPop = Instance.new("UIScale")
		chipPop.Scale = 0.3
		chipPop.Parent = chip

		-- The text column: a list, so a headline and a wrapped body stack
		-- without either being positioned by hand, and the CARD's automatic
		-- height follows whatever they add up to.
		-- 253 is what is left, not a chosen number: the card is 330, the row
		-- pads 18 and 16 off the ends, the chip takes 34 and the gap 9.
		local column = Instance.new("Frame")
		column.LayoutOrder = 2
		column.Size = UDim2.new(0, 253, 0, 0)
		column.AutomaticSize = Enum.AutomaticSize.Y
		column.BackgroundTransparency = 1
		column.ZIndex = 21
		column.Parent = row

		local columnList = Instance.new("UIListLayout")
		columnList.Padding = UDim.new(0, 1)
		columnList.SortOrder = Enum.SortOrder.LayoutOrder
		columnList.Parent = column

		local texts: { TextLabel } = {}

		if spec.title then
			local head = Instance.new("TextLabel")
			head.LayoutOrder = 1
			head.Size = UDim2.new(1, 0, 0, 15)
			Theme.title(head, 12, Theme.readable(tone))
			head.TextTransparency = 1
			head.TextXAlignment = Enum.TextXAlignment.Left
			head.Text = spec.title
			head.ZIndex = 21
			head.Parent = column
			table.insert(texts, head)
		end

		-- A FIXED TextSize with wrapping, never TextScaled. TextScaled would
		-- size every message to its box, so "Banked 12 coins" would arrive in
		-- letters twice the height of a sentence -- and in a box that grows to
		-- fit its text, TextScaled and AutomaticSize chase each other.
		local body = Instance.new("TextLabel")
		body.LayoutOrder = 2
		body.Size = UDim2.new(1, 0, 0, 0)
		body.AutomaticSize = Enum.AutomaticSize.Y
		Theme.body(body, 15, Theme.INK)
		body.TextTransparency = 1
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.TextWrapped = true
		body.Text = message
		body.ZIndex = 21
		body.Parent = column
		table.insert(texts, body)

		blast(kind or "good")
		if spec.flash then
			flash(tone)
		end

		-- In.
		local quick = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(card, quick, { BackgroundTransparency = GLASS }):Play()
		TweenService:Create(cardEdge, quick, { Transparency = 0.1 }):Play()
		TweenService:Create(cardPop, TweenInfo.new(0.3, Enum.EasingStyle.Back,
			Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(chip, quick, { BackgroundTransparency = 0, TextTransparency = 0 }):Play()
		TweenService:Create(ring, quick, { Transparency = 0 }):Play()
		TweenService:Create(chipPop, TweenInfo.new(0.34, Enum.EasingStyle.Back,
			Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(stripe, TweenInfo.new(0.3, Enum.EasingStyle.Quint,
			Enum.EasingDirection.Out), { Size = UDim2.new(0, 4, 1, -20), BackgroundTransparency = 0 }):Play()
		TweenService:Create(life, quick, { BackgroundTransparency = 0.35 }):Play()
		for _, label in ipairs(texts) do
			TweenService:Create(label, quick, { TextTransparency = 0 }):Play()
		end

		-- HOW LONG IT STAYS IS A FUNCTION OF HOW MUCH THERE IS TO READ.
		--
		-- The kind's own `hold` is a FLOOR, not the answer. A flat hold is the
		-- wrong number for every message but one, and the ones it was most
		-- wrong for were the long ones -- exactly the messages that matter,
		-- since nothing important in this game is three words. See
		-- Config.NOTIFY_READ for where the two constants come from.
		--
		-- Counted in WORDS rather than characters, because reading time
		-- tracks words and a coin figure like "1,482,000" is one glance
		-- whatever its length.
		local read = Config.NOTIFY_READ
		local words = 0
		for _ in message:gmatch("%S+") do
			words += 1
		end
		local hold = math.min(read.max,
			math.max(spec.hold or read.base, read.base + words * read.perWord))

		TweenService:Create(life, TweenInfo.new(hold, Enum.EasingStyle.Linear),
			{ Size = UDim2.new(0, 0, 0, 3) }):Play()

		-- Out, on this card's own clock. Every card owns its lifetime, which
		-- is the whole reason a second message no longer erases the first.
		task.delay(hold, function()
			local slow = TweenInfo.new(0.34, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			TweenService:Create(card, slow, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(cardEdge, slow, { Transparency = 1 }):Play()
			TweenService:Create(chip, slow, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
			TweenService:Create(ring, slow, { Transparency = 1 }):Play()
			TweenService:Create(stripe, slow, { BackgroundTransparency = 1 }):Play()
			TweenService:Create(life, slow, { BackgroundTransparency = 1 }):Play()
			for _, label in ipairs(texts) do
				TweenService:Create(label, slow, { TextTransparency = 1 }):Play()
			end
			task.delay(0.4, function()
				card:Destroy()
			end)
		end)

		-- Retire the oldest rather than let the stack grow down the screen. A
		-- robbery fires three of these in a second and a rebirth fires more.
		--
		-- A `while`, not an `if`: a burst can arrive faster than the fades
		-- retire it, and one removal per message would never catch up.
		--
		-- TWO CAPS, AND THE HEIGHT ONE IS THE REAL ONE. Four cards was fine
		-- while a card was 38 pixels tall; the holds are now long enough that
		-- four coexist routinely, and a card that has to fit its own icon is
		-- 56 at its shortest and 80-odd with a headline. Four of those runs
		-- past the garage slot in the bottom-left, which is the one neighbour
		-- this corner has.
		--
		-- So the limit is the STACK'S MEASURED HEIGHT against the band that is
		-- actually free -- from the top of the stack down to the garage slot's
		-- own 216-pixel reserve. That is derived per screen instead of assumed:
		-- a phone held sideways is 546 tall and gives 258 pixels, where this
		-- window gives 377. The count cap stays as a backstop.
		--
		-- Deferred a frame because AutomaticSize has not measured the new card
		-- yet, and trimming against a stale height would retire nothing.
		task.spawn(function()
			RunService.RenderStepped:Wait()
			local free = workspace.CurrentCamera.ViewportSize.Y
				- stack.AbsolutePosition.Y - 216
			while liveCards() > 1
				and (liveCards() > 4 or stack.AbsoluteSize.Y > free) do
				local oldest, oldestOrder = nil, -math.huge
				for _, child in ipairs(stack:GetChildren()) do
					if child:IsA("Frame") and child.LayoutOrder > oldestOrder then
						oldest, oldestOrder = child, child.LayoutOrder
					end
				end
				if not oldest then
					break
				end
				oldest:Destroy()
				RunService.RenderStepped:Wait()
			end
		end)
	end

	Remotes.get("Notify").OnClientEvent:Connect(show)
end

buildDodgeRolls()
buildSneakWalk()

-- EVERY THIEF ON THE STREET IS POSED HOLDING THEIR LOOT, and the watcher that
-- does it lives in `CarryPose` rather than here -- required and started in ONE
-- STATEMENT holding no local at all.
--
-- That is the call `RobBadge` already makes two thousand lines up, and for the
-- same reason: this chunk is at Luau's 200-register ceiling, and it was
-- MEASURED being at it by this very feature. Written inline the watcher wanted
-- five top-level locals and the HUD died with "Out of local registers when
-- trying to allocate carriers" -- not the pose, the entire HUD, because the
-- chunk never compiles and nothing gets built.
--
-- A `do ... end` block does NOT buy the way out here, which is worth knowing
-- because it looks like it should: its locals still come out of the enclosing
-- FUNCTION's register file, so scoping five of them changed nothing. Only a
-- real function body has a file of its own. Tenth-odd time this ceiling has
-- shaped a decision, and it is now cheaper to design for than to discover.
require(ReplicatedStorage.Shared.CarryPose).start()

-- THE GADGET THROW, same shape and same one-statement starts. The server
-- publishes `Config.THROW_ANIMATION_ATTRIBUTE` on every thrower and each
-- client poses them (Shared/ThrowPose) and flies every gadget in the air
-- itself (Shared/GadgetFlight). ThrowAim, which drives the local player's
-- own throw, is started further up beside the old aim preview.
require(ReplicatedStorage.Shared.ThrowPose).start()
require(ReplicatedStorage.Shared.GadgetFlight).start()

-- THE FRONT DOOR'S WIPE. The server decides the crossing and writes the
-- CFrame; this is only the cover that hides it. One statement holding no
-- local, for the 200-register ceiling -- see DoorMask.
require(ReplicatedStorage.Shared.DoorMask).start()

buildPatrol()
buildBustScene()
buildNotifications()

selectTab(1)
