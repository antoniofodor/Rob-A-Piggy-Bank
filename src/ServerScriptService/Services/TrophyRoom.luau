--!strict
--[[
	TrophyRoom -- what a player has done, displayed INSIDE the house.

	A house in this game is a trophy room: `assets/houses/docs/HOUSE-TROPHY-ROOMS.md` and
	brief B2 in `docs/BRIEFS-FOR-GPT.md` approved that direction, and the briefs
	fix the one thing code depends on -- THE MOUNT NAMES. An authored house
	template carries `Featured`, `Shelf_1..N`, `Wall`, `Record`, `Plaque_Legacy`
	and `Door_Exit`; where they are is art's choice and the names are the
	contract. This is the first reader of them: before this, five Blender
	builders and two shipped assets authored mounts nothing had ever looked at.

	THE MVP USES ONE OF THEM: `Wall`. Three stat panels stand on it -- piggies
	robbed, coins stolen, patrols outrun -- plus a wanted poster once a player
	has been top of the Most Wanted board. The shelves, the hero pedestal and
	the record desk draw nothing; see `PANELS` below for what was there and the
	three measured reasons it went. Their mounts are kept because a template
	that carries them costs nothing and the room can grow back into them.

	NO ROOM SERVICE, NO DOOR, NO RESERVED REGION -- and that is the whole
	reason this is small. The plan describes rooms instanced somewhere off-map
	and entered through a door, because the code-built houses are solid masses
	with no inside. An AUTHORED house has a real interior standing on the lawn
	with collision boxes you can walk through (see
	assets/houses/tools/build_house_runtime.py), so the displays go in the house that
	is already there and a visitor sees them by walking in. The instanced-room
	machinery is what the OTHER houses will need.

	================================================================
	IT READS THE PUBLISHED STATE AND OWNS NONE OF ITS OWN
	================================================================

	`TrophyService.state(data)` is already published to the plot on every
	change (`PlotService.setTrophyState`), and it carries both halves of what
	a display needs: the earned flags, and the counters `Config.trophyGrade`
	turns into a grade. So there is no save field here, no remote and no push.

	OWNED DECIDES WHETHER IT IS DISPLAYED; THE GRADE DECIDES HOW IT LOOKS.
	Deriving "earned" from the grade alone is right for a normal save and
	wrong for two real ones -- an admin grant moves no counter, and the Victim
	Shelf's counter is a set of skins a prune can shrink -- which measured on
	the dev save as a progress plaque for a trophy the shop called owned.

	Two things fall out of reading rather than owning:

	  * THE LAWN IS A DELETION, NOT A MIGRATION. Trophies no longer take a
	    lawn slot (`TrophyService.check`), and `decor.owned` was not touched
	    to do it -- which is the order `assets/houses/docs/HOUSE-TROPHY-ROOMS.md` insists
	    on: retire the lawn writes only once the interior ships, and never
	    disturb what somebody earned.
	  * the unearned ones can be drawn too, as the progress plaques the
	    achievement wall is specified to show, from the same numbers.

	A BIGGER HOUSE SHOWS MORE BECAUSE ITS TEMPLATE CARRIES MORE SHELVES, which
	is the rule the brief is firmest about: display capacity may grow with the
	house and ACHIEVEMENT capacity may never. Nothing here reads the house
	tier -- it counts `Shelf_N` mounts -- so a grander template is an art
	change and cannot become a gameplay advantage.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)

local TrophyRoom = {}

local function part(name: string, size: Vector3, cf: CFrame, colour: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	-- A display is scenery INSIDE scenery: the house's own collision boxes are
	-- what a player walks on, and a plaque they could stand on or raycast is a
	-- cosmetic changing an outcome.
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A readable label on the face of a part.
--
-- `Back` is +Z, which is the face every mount here points at the doorway, and
-- Roblox's `Front` is -Z -- the NormalId trap this project has recorded for
-- the plot sign.
--
-- A SURFACEGUI REPLACES THE FACE IT IS ON, which is why this paints its own
-- background. The first build put a transparent gui on a sand-coloured plaque
-- and the plaques rendered as BLACK PANELS: where the canvas draws nothing,
-- the face is no longer the part's colour, it is the gui's own empty surface.
-- So the fill is drawn here and the part's colour is only what the edges show.
--
-- AND THE TYPE IS SIZED IN CANVAS PIXELS AGAINST A 100-PIXEL STUD, which is
-- the other half of the same bug: a `MaxTextSize` of 15 on this canvas is 0.15
-- studs tall -- legible with your nose against the wall and invisible from the
-- doorway. About half a stud of cap height is what reads across a twelve-stud
-- room, so a cap is around 50.
local PIXELS_PER_STUD = 100

local function surface(on: BasePart, fill: Color3): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Text"
	gui.Face = Enum.NormalId.Back
	gui.CanvasSize = Vector2.new(
		math.floor(on.Size.X * PIXELS_PER_STUD), math.floor(on.Size.Y * PIXELS_PER_STUD))
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.Parent = on

	local back = Instance.new("Frame")
	back.Name = "Fill"
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = fill
	back.BorderSizePixel = 0
	back.Parent = gui
	return gui
end


-- ---------------------------------------------------------------------------
-- THREE NUMBERS AND A POSTER. THAT IS THE WHOLE ROOM.
-- ---------------------------------------------------------------------------
--
-- WHAT WAS HERE AND WHY IT WENT. A hero trophy on a pedestal, four shelves
-- carrying graded trophy models, and a wall of ten framed cells -- an earned
-- trophy hung in each, a socket where one was not, and the whole of
-- `Config.TROPHIES` laid across it. Every piece of that was built and measured
-- and it was still the wrong shape, for reasons that only showed up once it
-- was standing in a room:
--
--   * A CELL IS NOT A PLINTH. A trophy model is a 3D object with depth, and
--     hanging one flat in a framed cell puts its own edges through the frame
--     and through its neighbour's. The skin case is the worst of them: 1.37
--     studs deep and the widest trophy in the game.
--   * THE THINGS DID NOT FIT THE FRAMES THEY WERE IN. A board trophy scaled to
--     a cell is smaller than the cell, so the frame reads as a border round a
--     gap; the case scaled to that same cell is bigger than the cell is. ONE
--     CELL SIZE CANNOT HOLD TEN DIFFERENTLY SHAPED OBJECTS.
--   * TEN ACHIEVEMENTS IS NOT AN MVP. What a player wants off a wall at a
--     glance is how much they have done, and ten graded counters answer that
--     more slowly than three plain ones.
--
-- So a display is a PANEL: a drawn icon, a number, and a word. A panel has no
-- depth, so it cannot clip its frame or its neighbour; it is sized TO the wall
-- rather than the wall to it; and it says the one thing it is for.
--
-- NOTHING IS DELETED, ONLY UNDISPLAYED. `Config.TROPHIES`, every trophy
-- builder in `Decor`, the earned flags and the grades are all untouched and
-- all still published -- the bag's Trophies tab still shows the whole
-- collection log with its progress, which is where a list of ten belongs.
-- This file stopped being the thing that renders them. Bringing one back is a
-- row in `PANELS`.
local PANELS = {
	{
		key = "skins",
		caption = "SKINS ROBBED",
		icon = "snout",
		-- OUT OF THE TOTAL, because a count with no denominator is a score and
		-- a count with one is a collection. `skinTotal` is published beside it
		-- for exactly this.
		value = function(state: any): string
			local held = #((state and state.victims) or {})
			local total = tonumber(state and state.skinTotal) or 0
			if total > 0 then
				return ("%d / %d"):format(held, total)
			end
			return tostring(held)
		end,
	},
	{
		key = "stolen",
		caption = "COINS STOLEN",
		icon = "coin",
		-- `Config.formatCoins` rather than a second formatter: this is the same
		-- figure the HUD, the delivery toast and the rap sheet print, and two
		-- ladders over one set of suffixes is the near-identical copy this
		-- project keeps recording.
		value = function(state: any): string
			return Config.formatCoins(tonumber(state and state.stolen) or 0)
		end,
	},
	{
		key = "escapes",
		caption = "PATROLS OUTRUN",
		icon = "siren",
		value = function(state: any): string
			return tostring(tonumber(state and state.escapes) or 0)
		end,
	},
}

-- A PANEL IS AS WIDE AS THE WALL LETS IT BE, which is the other half of "too
-- small for the things we were putting in them": the old cell was a constant
-- and the wall was whatever it happened to be. Clamped at both ends -- wider
-- than `max` reads as a banner rather than a frame, and under `min` is the
-- problem this started from.
local PANEL = {
	height = 3.4,
	gap = 0.42,
	inset = 0.3,
	min = 2.6,
	max = 5.0,
}

-- The siren has no drawn icon in `Theme`, so here is one: a dark housing with
-- a lit dome and one off-centre highlight. DRAWN rather than an emoji for the
-- reason `Theme.coin` is drawn -- an emoji renders from the colour font and
-- ignores `TextColor3`, so it is a smudge at any size a panel would use.
local function siren(parent: Instance, size: number): Frame
	local outer = Instance.new("Frame")
	outer.Name = "Siren"
	outer.Size = UDim2.new(0, size, 0, size)
	outer.BackgroundTransparency = 1
	outer.Parent = parent

	local base = Instance.new("Frame")
	base.Name = "Base"
	base.Size = UDim2.new(1, 0, 0.3, 0)
	base.Position = UDim2.new(0, 0, 0.62, 0)
	base.BackgroundColor3 = Theme.INK
	base.BorderSizePixel = 0
	base.Parent = outer
	local baseCorner = Instance.new("UICorner")
	baseCorner.CornerRadius = UDim.new(0, math.max(2, math.floor(size * 0.08)))
	baseCorner.Parent = base

	local dome = Instance.new("Frame")
	dome.Name = "Dome"
	dome.Size = UDim2.new(0.74, 0, 0.66, 0)
	dome.Position = UDim2.new(0.13, 0, 0.04, 0)
	dome.BackgroundColor3 = Theme.STOP
	dome.BorderSizePixel = 0
	dome.Parent = outer
	local domeCorner = Instance.new("UICorner")
	domeCorner.CornerRadius = UDim.new(0.5, 0)
	domeCorner.Parent = dome

	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Size = UDim2.new(0.22, 0, 0.22, 0)
	shine.Position = UDim2.new(0.28, 0, 0.18, 0)
	shine.BackgroundColor3 = Theme.PAPER
	shine.BackgroundTransparency = 0.35
	shine.BorderSizePixel = 0
	shine.Parent = outer
	local shineCorner = Instance.new("UICorner")
	shineCorner.CornerRadius = UDim.new(0.5, 0)
	shineCorner.Parent = shine
	return outer
end

local function drawIcon(kind: string, parent: Instance, size: number): Frame
	if kind == "snout" then
		return Theme.snout(parent, size)
	elseif kind == "coin" then
		return Theme.coin(parent, size)
	end
	return siren(parent, size)
end

-- One panel: the rim, the board, and a canvas to print on.
local function panel(at: CFrame, width: number, name: string, parent: Instance): BasePart
	-- THE RIM IS BEHIND A LIGHTER BOARD AND SHOWS ONLY AT ITS EDGE. Drawn the
	-- other way round -- one dark plate at full size with the content on top --
	-- it is a black panel with a small thing on it, which is what the first
	-- build of this wall photographed as.
	part("Frame_" .. name, Vector3.new(width + 0.18, PANEL.height + 0.18, 0.1),
		at * CFrame.new(0, 0, -0.06), Theme.INK, parent)
	local board = part("Board_" .. name, Vector3.new(width, PANEL.height, 0.08),
		at * CFrame.new(0, 0, 0.03), Theme.PAPER, parent)
	surface(board, Theme.PAPER)
	return board
end

local function printed(fill: Frame, name: string, size: UDim2, pos: UDim2,
	text: string, colour: Color3, cap: number): TextLabel

	local t = Instance.new("TextLabel")
	t.Name = name
	t.Size = size
	t.Position = pos
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.TextColor3 = colour
	t.Text = text
	t.Parent = fill
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = cap
	limit.Parent = t
	return t
end

local function statPanel(spec: any, state: any, at: CFrame, width: number, parent: Instance)
	local board = panel(at, width, spec.key, parent)
	local gui = board:FindFirstChildOfClass("SurfaceGui") :: SurfaceGui
	local fill = gui:FindFirstChild("Fill") :: Frame
	local tall = gui.CanvasSize.Y

	local icon = drawIcon(spec.icon, fill, math.floor(tall * 0.30))
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0.07, 0)

	printed(fill, "Value", UDim2.new(1, -20, 0.30, 0), UDim2.new(0, 10, 0.44, 0),
		spec.value(state), Theme.INK, math.floor(tall * 0.26))
	printed(fill, "Caption", UDim2.new(1, -20, 0.16, 0), UDim2.new(0, 10, 0.77, 0),
		spec.caption, Theme.MUTED, math.floor(tall * 0.11))
end

-- THE WANTED POSTER, AND IT IS EARNED RATHER THAN SHOWN. It appears the first
-- time a player has been top of the Most Wanted board and never goes away:
-- `state.wanted` is the count of appearances and is already published, so this
-- needs no new save field, no new remote and no new counter.
--
-- IT IS THE ONE THING ON THIS WALL ABOUT A PLAYER RATHER THAN A NUMBER, which
-- is why it gets their own face on it. `rbxthumb` and never
-- `GetUserThumbnailAsync`: the content URL resolves itself and never yields,
-- so a room cannot be held up on a web call -- the same call the arrest scene
-- and the street's own Most Wanted board already make.
local function wantedPanel(state: any, userId: number?, at: CFrame, width: number,
	parent: Instance)

	local board = panel(at, width, "wanted", parent)
	local gui = board:FindFirstChildOfClass("SurfaceGui") :: SurfaceGui
	local fill = gui:FindFirstChild("Fill") :: Frame
	local tall = gui.CanvasSize.Y

	-- The alarm red in its DARKENED form: raw `STOP` on paper is thin, and
	-- this is the one heading in the room that should read as bad news.
	printed(fill, "Heading", UDim2.new(1, -16, 0.17, 0), UDim2.new(0, 8, 0.04, 0),
		"WANTED", Theme.STOP_INK, math.floor(tall * 0.16))

	-- A photo well is a hole, so it is dark with the board standing proud of
	-- it -- the eye takes the highest line as the surface. A printed photograph
	-- has a dark border anyway.
	local well = Instance.new("Frame")
	well.Name = "PhotoWell"
	well.AnchorPoint = Vector2.new(0.5, 0)
	well.Position = UDim2.new(0.5, 0, 0.23, 0)
	well.Size = UDim2.new(0, math.floor(tall * 0.48), 0, math.floor(tall * 0.48))
	well.BackgroundColor3 = Theme.SLAB_DEEP
	well.BorderSizePixel = 0
	well.Parent = fill

	if userId then
		local photo = Instance.new("ImageLabel")
		photo.Name = "Photo"
		photo.Size = UDim2.new(1, -8, 1, -8)
		photo.Position = UDim2.new(0, 4, 0, 4)
		photo.BackgroundTransparency = 1
		photo.Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=420&h=420"):format(userId)
		photo.Parent = well
	end

	-- THE BOUNTY, IN THE WORDS THE BOARD OUTSIDE USES. A count of appearances
	-- is a statistic; a price on your head is the thing a wanted poster is
	-- for, and the street's own board prints exactly this line. `bestBounty`
	-- is the highest it ever reached, kept on the save because the live figure
	-- is session heat and dies with the session -- see
	-- `TrophyService.recordWanted`.
	local bounty = tonumber(state and state.bestBounty) or 0
	printed(fill, "Bounty", UDim2.new(1, -16, 0.16, 0), UDim2.new(0, 8, 0.77, 0),
		("BOUNTY  %s"):format(Config.formatCoins(bounty)),
		Theme.STOP_INK, math.floor(tall * 0.12))
end

-- How wide the wall is, off the room's own collision boxes -- the only thing
-- here that knows how big the room is, since a mount is a point.
--
-- MATCHED ON "side", NOT ON ONE HOUSE'S OWN NAMES: the treehouse calls its
-- walls `Collide_Cabin side -1` and the slime calls its `Collide_SideWall-1`.
-- A template whose walls did not match found none and fell back to a centred
-- rack of whatever width the code happened to want.
local function wallSpan(at: CFrame, house: Model): (number, number)
	local left, right = -math.huge, math.huge
	for _, d in ipairs(house:GetChildren()) do
		if d:IsA("BasePart") and d.Name:sub(1, 8) == "Collide_"
			and d.Name:lower():find("side") ~= nil then
			local x = at:PointToObjectSpace(d.Position).X
			if x < 0 then
				left = math.max(left, x + d.Size.X / 2)
			else
				right = math.min(right, x - d.Size.X / 2)
			end
		end
	end
	-- AND THEN CLAMPED TO THE WALL THE MOUNT IS ACTUALLY STANDING ON, because
	-- the side walls describe how wide the ROOM is and a row of panels is drawn
	-- on ONE WALL.
	--
	-- Those are the same number in a rectangular room, which is why this held
	-- for sixteen of the eighteen houses. The Toadstool Cottage is an OCTAGON:
	-- its `SideWall_02` and `SideWall_06` sit at x +-12.75 while the wall behind
	-- the mount, `Wall_04`, is 10.74 wide -- so the row came out 14.16 wide and
	-- ran a stud and a half past each end of its own wall, into the two angled
	-- segments either side. That is the reported "posters clipping into the
	-- wall", and it is measured rather than eyeballed.
	--
	-- MINIMUM OF THE TWO, NEVER A SWAP. The treehouse is the case that refuses
	-- the obvious fix: its rear wall is 17.00 wide across the OUTSIDE while the
	-- side walls leave 15.60 between their inner faces, so the wall alone would
	-- be too generous there exactly as the sides are too generous in the
	-- mushroom. The row has to fit inside BOTH.
	local nearest, wallLeft, wallRight = math.huge, nil, nil
	for _, d in ipairs(house:GetChildren()) do
		if d:IsA("BasePart") and d.Name:sub(1, 8) == "Collide_" then
			local here = at:PointToObjectSpace(d.Position)
			-- Behind the mount, tall enough to be a wall rather than a floor or
			-- a lintel, and wide enough to be the one the mount is on.
			if math.abs(here.Z) < 4.0 and math.abs(here.X) < d.Size.X / 2 + 0.5
				and d.Size.Y > 3 and math.abs(here.Z) < nearest then
				nearest = math.abs(here.Z)
				wallLeft, wallRight = here.X - d.Size.X / 2, here.X + d.Size.X / 2
			end
		end
	end
	if wallLeft then
		left = if left == -math.huge then wallLeft else math.max(left, wallLeft)
		right = if right == math.huge then wallRight else math.min(right, wallRight)
	end

	if left == -math.huge or right == math.huge then
		local half = (PANEL.max * 2 + PANEL.gap) / 2
		return -half, half
	end
	return left + PANEL.inset, right - PANEL.inset
end

--[[
	Fill (or refill) a house's trophy room from a published trophy state.

	Safe to call on any plot: a house with no `Wall` mount -- which is every
	code-built tier -- is left exactly alone, and that is what makes this
	per-template rather than a change to all eighteen.

	`userId` is the owner's, for the wanted poster's photograph. A resident has
	no Player behind it, so the poster is drawn without one rather than not at
	all: it is still true that somebody was wanted.
]]
function TrophyRoom.fill(house: Model?, state: any?, userId: number?)
	if not house then
		return
	end
	local old = house:FindFirstChild("TrophyDisplay")
	if old then
		old:Destroy()
	end
	if not state then
		return
	end

	local mount = nil
	for _, d in ipairs(house:GetChildren()) do
		if d:IsA("BasePart") and d.Name == "Mount_Wall" then
			mount = d
		end
	end
	if not mount then
		return
	end

	local display = Instance.new("Model")
	display.Name = "TrophyDisplay"
	display.Parent = house

	-- THE MOUNT'S OWN FACING, which the art authors per mount. Deriving one by
	-- aiming at the doorway is right on the back wall and about 43 degrees
	-- wrong on a side wall.
	local at = mount.CFrame

	local panels: { any } = {}
	for _, spec in ipairs(PANELS) do
		table.insert(panels, spec)
	end
	-- GATED ON THE BOUNTY, NOT ON THE COUNT, and the difference showed up on
	-- the first boot: this save has topped the board (`wanted` is 1) and
	-- `bestBounty` is a field that did not exist when it did, so the poster
	-- printed BOUNTY 0 -- a wanted poster with no price on it, which reads as
	-- broken rather than as early. Gating on the figure it PRINTS means it can
	-- never show a zero, and a save from before the field simply earns it back
	-- the next time they top the board.
	if (tonumber(state.bestBounty) or 0) > 0 then
		table.insert(panels, { key = "wanted" })
	end

	local left, right = wallSpan(at, house)
	local count = #panels
	local fits = (right - left - PANEL.gap * (count - 1)) / count
	local width = math.clamp(fits, PANEL.min, PANEL.max)
	-- `PANEL.min` IS A PREFERENCE AND THE WALL IS NOT. On a wall too narrow to
	-- hold the row at its minimum, the clamp does not make the panels readable,
	-- it hangs them off the end -- measured on the Toadstool Cottage, whose
	-- 10.14 of usable wall takes four 2.6-wide panels to 11.66 and pushes the
	-- outer two into the angled segments either side. Below the floor the row is
	-- divided instead: 2.22 there, 15% under the preference and still legible,
	-- against panels that visibly do not fit the wall they are on. The MAX is a
	-- real ceiling and stays clamped.
	if width * count + PANEL.gap * (count - 1) > right - left then
		width = math.max(fits, 0.1)
	end
	local span = width * count + PANEL.gap * (count - 1)
	local centre = (left + right) / 2

	for i, spec in ipairs(panels) do
		local x = centre - span / 2 + width / 2 + (i - 1) * (width + PANEL.gap)
		local cell = at * CFrame.new(x, 0, 0)
		if spec.key == "wanted" then
			wantedPanel(state, userId, cell, width, display)
		else
			statPanel(spec, state, cell, width, display)
		end
	end
end

return TrophyRoom
