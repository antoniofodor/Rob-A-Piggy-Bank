--!strict
--[[
	PlotService

	Owns the pool of plots: builds them, hands one to each arriving player,
	and wipes it when they leave.

	Plots are generated in code rather than built by hand in Studio. That
	keeps the whole layout in source control and means changing the grid is
	a one-line edit instead of an afternoon of dragging parts.

	The piggy bank itself lives in PiggyBank.luau; this file only decides
	where the plots go and who owns which one.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PiggyBank = require(script.Parent.PiggyBank)
local GuardDog = require(script.Parent.GuardDog)
-- Geometry, in Shared because the shop renders these too.
local House = require(ReplicatedStorage.Shared.House)
local Decor = require(ReplicatedStorage.Shared.Decor)

local PlotService = {}

export type Plot = {
	index: number,
	model: Model,
	base: Part,
	-- Position AND facing. Anything rebuilt after construction (the fence,
	-- the spawn point) has to work from this, not from base.Position, or it
	-- comes back unrotated on the far row.
	cframe: CFrame,
	piggy: PiggyBank.Refs,
	dog: GuardDog.Dog,
	fence: Folder,
	house: Model?,
	decor: Model?,
	-- Two rows, not one. A single TextScaled label holding both the name and
	-- the boasts shrank the name to fit whatever the boasts happened to be, so
	-- the most important word on the board was the one that moved.
	signLabel: TextLabel,
	signBoast: TextLabel,
	prompt: ProximityPrompt,
	owner: Player?,
}

local plots: { Plot } = {}
local byPlayer: { [Player]: Plot } = {}
local plotsFolder: Folder

-- Registered by HeistService, which owns walkspeed state. PlotService builds
-- the fence and detects the crossing; it doesn't decide what that costs.
local fencePenaltyHandlers: { (Player, any, any) -> () } = {}

local LAWN = Color3.fromRGB(138, 178, 104)
local TRIM = Color3.fromRGB(196, 178, 148)
local POST = Color3.fromRGB(122, 88, 58)

-- Where the plot sign stands, in plot-local studs, and which way it is turned.
--
-- OUT ON THE VERGE, beyond the fence and beyond the moat, beside the driveway.
-- A sign is a thing to be read from the street, and inside the fence it spent
-- the whole late game behind barbed wire and then behind five studs of water.
--
-- The z is not a taste decision. Measured on a tier-5 plot, the front moat
-- runs z 26.1 to 31.1 with its outer bank to 32.1, broken only by the driveway
-- causeway at x -7.0 to +7.0. So the dry verge starts at 32.1 and the kerb is
-- at streetMetrics().driveFar, 44. Anything between those two is out of the
-- water at every tier; anything short of it is swimming the moment its owner
-- buys the fifth fence.
--
-- The x keeps it clear of two things: the causeway itself, which is the walk
-- from the street to the gate and must stay open, and the vergeL/vergeR decor
-- slots at (+/-9.5, 31). The board hangs left of its post, so a post at 16.2
-- puts the board across x 8.9 to 15.1 -- past the driveway edge at 6.5, and
-- five studs clear of the decor in z.
--
-- The yaw turns it a little toward the road it is addressed to.
local SIGN_SPOT = Vector3.new(12, 0, 36)
local SIGN_YAW = 12

-- ============================================================
-- CONSTRUCTION
-- ============================================================

-- Where a plot sits AND which way it faces.
--
-- Everything on a plot -- sign, gate, snout, spawn point -- is authored with
-- +Z as its front. The far row is yawed 180 degrees so both rows face the
-- road rather than one row showing the street its back fence. That yaw is the
-- only place in the codebase that has to know the layout has two sides.
local function plotCFrame(index: number): CFrame
	local perRow = Config.PLOTS_PER_ROW
	local row = math.floor((index - 1) / perRow) -- 0 = near side, 1 = far side
	local col = (index - 1) % perRow

	-- Asked of Config rather than computed here, so this file and the scenery
	-- that lines up against it cannot drift. The row briefly had a hole in the
	-- middle for the town square and a column was NOT its own position; it is
	-- continuous again, and the one place that knows is Config.
	local x = Config.plotColumnX(col)
	local z = (if row == 0 then -0.5 else 0.5) * Config.STREET_SPACING
	local yaw = if row == 0 then 0 else math.pi

	return CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
end

local function buildPlot(index: number): Plot
	local cf = plotCFrame(index)
	local origin = cf.Position

	local model = Instance.new("Model")
	model.Name = "Plot" .. index

	-- Stone trim sits slightly proud of the lawn so each plot reads as a
	-- separate property rather than a patch of the same field.
	--
	-- IT RINGS THE WHOLE YARD, HOUSE INCLUDED, not just the front lawn. It
	-- used to be PLOT_SIZE + 4, a 52-stud square centred on the piggy, which
	-- stopped dead at the back of the lawn -- so a plot read as a bordered
	-- garden with an unbordered field of grass stuck on the back of it, and
	-- the border was exactly the thing saying where one property ended and the
	-- next began. It now runs from the pavement to two studs behind the back
	-- fence, which is the same rectangle buildFence encloses.
	--
	-- Sized off YARD_DEPTH rather than off the slab. Those were the same
	-- number until the yard was lengthened to hold the house, and this file
	-- already has one bug from measuring the wrong one -- the grove that
	-- planted full-grown trees on people's lawns.
	local TRIM_EDGE = 2
	local trimFront = Config.PLOT_SIZE.Z / 2 + TRIM_EDGE
	local trimBack = Config.YARD_DEPTH + TRIM_EDGE

	local trim = Instance.new("Part")
	trim.Name = "Trim"
	trim.Size = Vector3.new(
		Config.PLOT_SIZE.X + TRIM_EDGE * 2,
		Config.PLOT_SIZE.Y + 0.4,
		trimFront + trimBack)
	-- Authored around `origin` like everything else here; the PivotTo at the
	-- end turns the far row. Safe to resize because the model's PrimaryPart is
	-- the Base, so the pivot does not move when this part's bounds change.
	trim.Position = origin + Vector3.new(0, -0.4, (trimFront - trimBack) / 2)
	trim.Anchored = true
	trim.Material = Enum.Material.Concrete
	trim.Color = TRIM
	trim.TopSurface = Enum.SurfaceType.Smooth
	trim.Parent = model

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Config.PLOT_SIZE
	base.Position = origin
	base.Anchored = true
	base.Material = Enum.Material.Grass
	base.Color = LAWN
	base.TopSurface = Enum.SurfaceType.Smooth
	base.Parent = model

	-- The back of the yard, between the plot slab and the back fence.
	--
	-- The fence now encloses far more ground than the 48x48 slab covers, and
	-- without this the far half of a player's own garden is darker world
	-- ground -- one fenced yard in two obviously different greens. Butts up
	-- against the slab rather than overlapping it: two grass surfaces at the
	-- same height would z-fight along the seam.
	local yardDepth = Config.YARD_DEPTH - Config.PLOT_SIZE.Z / 2
	local yard = Instance.new("Part")
	yard.Name = "Yard"
	-- SAME WIDTH AS THE LAWN, so the stone border either side is a constant
	-- two studs from the pavement to the back fence. At 51.2 -- the full fence
	-- interior -- the grass grew 1.6 studs wider at the seam behind the piggy
	-- and the visible trim shrank from 2 studs to 0.4 at the same line, which
	-- reads as the border running out rather than as a wider garden. The strip
	-- between this grass and the fence is stone now, exactly as it already is
	-- along the front lawn.
	yard.Size = Vector3.new(Config.PLOT_SIZE.X, Config.PLOT_SIZE.Y, yardDepth)
	yard.Position = origin + Vector3.new(0, 0, -(Config.PLOT_SIZE.Z / 2 + yardDepth / 2))
	yard.Anchored = true
	yard.Material = Enum.Material.Grass
	yard.Color = LAWN
	yard.TopSurface = Enum.SurfaceType.Smooth
	yard.Parent = model

	local piggy = PiggyBank.build(origin, model)

	-- The plot sign: a hanging shingle, off to the right of the gate.
	--
	-- It used to be an eleven-stud plank on a stick in the dead centre of the
	-- front edge, which put the least interesting object on the plot directly
	-- between the street and the piggy bank -- the one thing everybody is
	-- actually looking at, and the line everybody walks. Off to one side it
	-- stops blocking that and starts reading as a house sign rather than a
	-- billboard.
	--
	-- OUT ON THE VERGE, past the moat. See SIGN_SPOT for the measured numbers
	-- that decide exactly where "past the moat" is -- it is a narrow band, and
	-- the obvious spots on either side of it are underwater at tier 5.
	--
	-- Authored around `origin` and yawed in place, because the far row of
	-- plots is turned 180 degrees by the PivotTo at the end of this function
	-- and a sign built from raw positions comes back facing its own back
	-- fence.
	local signCF = CFrame.new(origin)
		* CFrame.new(SIGN_SPOT.X, 0, SIGN_SPOT.Z)
		* CFrame.Angles(0, math.rad(SIGN_YAW), 0)
	-- The VERGE, which is a different floor from the lawn.
	--
	-- A plot is three heights: the lawn is the top of the plot slab (+0.5),
	-- the driveway is paving on the world ground (-0.28), and the verge is
	-- bare world ground (-0.5). The sign used to stand on the lawn and read
	-- +0.5; moving it outside the fence without moving this number would have
	-- left the whole thing hovering a full stud, which is exactly how the
	-- decorations got it wrong the first time.
	local baseY = -Config.PLOT_SIZE.Y / 2

	local function signPart(name: string, size: Vector3, at: CFrame, colour: Color3,
		material: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = at
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Material = material
		p.Color = colour
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	-- The board hangs at local x = 0 and the post stands off to its OUTER
	-- side, away from the drive.
	--
	-- Inner side first, and the 20-degree yaw swung the pole toward the
	-- street: from the pavement it stood in front of the board it was holding
	-- up, covering the first third of the name. Out here it sits behind the
	-- board instead, and the board still turns to face the drive.
	--
	-- The anchor positions the BOARD, not the post -- the board is the part
	-- that has to clear the decor slots and stay inside the fence.
	signPart("SignPlinth", Vector3.new(2.4, 0.6, 2.4),
		signCF * CFrame.new(4.2, baseY + 0.3, 0), Color3.fromRGB(196, 190, 176), Enum.Material.Slate)
	signPart("SignPost", Vector3.new(0.7, 9.0, 0.7),
		signCF * CFrame.new(4.2, baseY + 5.1, 0), POST, Enum.Material.Wood)
	signPart("SignCap", Vector3.new(1.1, 0.5, 1.1),
		signCF * CFrame.new(4.2, baseY + 9.85, 0), POST, Enum.Material.Wood)
	signPart("SignArm", Vector3.new(7.3, 0.45, 0.45),
		signCF * CFrame.new(0.55, baseY + 9.35, 0), POST, Enum.Material.Wood)
	-- The brace that stops the arm reading as a plank stuck through a pole.
	signPart("SignBrace", Vector3.new(2.4, 0.3, 0.3),
		signCF * CFrame.new(3.3, baseY + 8.5, 0) * CFrame.Angles(0, 0, math.rad(-40)),
		POST, Enum.Material.Wood)
	for _, x in ipairs({ -2.4, 2.4 }) do
		signPart("SignLink", Vector3.new(0.22, 0.95, 0.22),
			signCF * CFrame.new(x, baseY + 8.9, 0), Color3.fromRGB(126, 130, 136), Enum.Material.Metal)
	end

	-- Frame and panel are separate parts so the panel can stand proud of the
	-- frame. Flush would put two faces at the same depth, which is the
	-- coplanar flicker this codebase has now hit three times.
	signPart("Sign", Vector3.new(6.2, 4.2, 0.35),
		signCF * CFrame.new(0, baseY + 6.35, 0), Color3.fromRGB(96, 64, 42), Enum.Material.WoodPlanks)
	local panel = signPart("SignPanel", Vector3.new(5.5, 3.5, 0.16),
		signCF * CFrame.new(0, baseY + 6.35, 0.2), Color3.fromRGB(244, 236, 218),
		Enum.Material.SmoothPlastic)

	local surface = Instance.new("SurfaceGui")
	-- Roblox's "Front" face is -Z. The board faces out toward the street on
	-- +Z, so that's Back.
	surface.Face = Enum.NormalId.Back
	surface.CanvasSize = Vector2.new(550, 350)
	surface.AlwaysOnTop = false
	-- Unlit, so the board stays readable at dusk. It is the one thing on the
	-- plot whose whole job is being read from the pavement.
	surface.LightInfluence = 0
	surface.Parent = panel

	local label = Instance.new("TextLabel")
	label.Name = "Owner"
	label.Size = UDim2.new(1, -30, 0.4, 0)
	label.Position = UDim2.new(0, 15, 0.05, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	-- NEVER write TextWrapped next to TextScaled. Setting TextWrapped = false
	-- after TextScaled = true silently turns TextScaled back OFF and drops the
	-- label to the default TextSize of 8 -- measured, and on a board this size
	-- it renders as a faint smudge. TextScaled implies wrapping; the way to
	-- stop text overflowing is to give the row enough height for the lines it
	-- will wrap into, which is what the boast row below does.
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(70, 46, 30)
	label.Text = "EMPTY PLOT"
	label.Parent = surface

	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.Size = UDim2.new(0.62, 0, 0, 4)
	rule.Position = UDim2.new(0.19, 0, 0.5, 0)
	rule.BackgroundColor3 = Color3.fromRGB(178, 150, 112)
	rule.BorderSizePixel = 0
	rule.Parent = surface

	local boast = Instance.new("TextLabel")
	boast.Name = "Boasts"
	-- Tall enough for the two lines a full boast list wraps into. At one row's
	-- height the second line fell off the bottom of the board and a maxed-out
	-- player's sign read "12*  ·  Neon Tower  ·" with the skin missing.
	boast.Size = UDim2.new(1, -14, 0.36, 0)
	boast.Position = UDim2.new(0, 7, 0.545, 0)
	boast.BackgroundTransparency = 1
	boast.Font = Enum.Font.GothamBold
	boast.TextScaled = true
	boast.TextColor3 = Color3.fromRGB(150, 104, 44)
	boast.Text = ""
	boast.Parent = surface

	local fence = Instance.new("Folder")
	fence.Name = "Fence"
	fence.Parent = model

	model.PrimaryPart = base
	model.Parent = plotsFolder

	-- Yaw the whole plot into place. Everything above is authored front-to-+Z
	-- around `origin`, so a single pivot turns the far row's sign, gate and
	-- snout to face the street instead of the backdrop.
	model:PivotTo(cf)

	-- One dog per plot, built hidden at tier 0. Cheaper than spawning and
	-- destroying a model every time someone buys or rebirths away the upgrade,
	-- and it means the chase can start the instant an alarm fires.
	--
	-- Built AFTER the pivot on purpose: the dog caches its home as a world
	-- Vector3 and drives itself with PivotTo, so rotating it underneath that
	-- cache would leave it walking back to the wrong corner forever.
	-- Takes a CFrame, not a position: the kennel's +Z is its doorway, and the
	-- dog rests in front of it, so the whole arrangement has to be turned to
	-- face into the plot rather than out through the back fence.
	-- (14, 4) -> (26, 17), OUT TO THE FRONT-RIGHT CORNER.
	--
	-- On a 48-wide lawn that spot was near the edge; on a 64-wide one it is a
	-- third of the way in, standing between the piggy and the decoration ring
	-- with the dog napping in the middle of somebody's garden. The corner is
	-- also what buys the eighth decoration slot: the ring is four rows of three
	-- and the kennel holds exactly one of the twelve positions, so putting it
	-- anywhere in the middle would have cost two.
	local dog = GuardDog.build(cf * CFrame.new(26, 0, 17), model)

	return {
		index = index,
		model = model,
		base = base,
		cframe = cf,
		piggy = piggy,
		dog = dog,
		fence = fence,
		house = nil,
		decor = nil,
		signLabel = label,
		signBoast = boast,
		prompt = piggy.prompt,
		owner = nil,
	}
end
-- ============================================================
-- FENCES
-- ============================================================
--
-- Collision and decoration are deliberately separate systems.
--
-- The old fence WAS its rails: two thin bars with a 2.95-stud hole between
-- them and open air above the top one, so a thief could slip straight
-- through. Now every side gets one invisible slab running ground-to-top --
-- the only colliding geometry on the whole fence -- and the visible fence is
-- pure decoration with CanCollide off. Styles can then look like anything
-- without ever changing the jump maths, which depends only on `tier.top`.

-- Fence sits on the world ground outside the plot slab, not on the slab.
local FENCE_BASE_Y = -Config.PLOT_SIZE.Y / 2

-- How far the driveway paving stands proud of the world ground. Shared with
-- the decor placement so a car sits ON the paving rather than sunk into it or
-- hovering over it.
local DRIVEWAY_LIFT = 0.22

local function alongVec(alongX: boolean, t: number): Vector3
	return if alongX then Vector3.new(t, 0, 0) else Vector3.new(0, 0, t)
end

local function spanSize(alongX: boolean, length: number, height: number, depth: number): Vector3
	return if alongX then Vector3.new(length, height, depth) else Vector3.new(depth, height, length)
end

-- Takes a CFrame, not a position: the far row of plots is yawed 180 degrees,
-- and decoration has to arrive already rotated into the plot's own frame.
local function decorPart(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Evenly spaced positions along a side that always include both ends, so
-- corners and gate mouths get a post instead of trailing off into nothing.
local function stepsAlong(length: number, spacing: number): { number }
	local count = math.max(1, math.round(length / spacing))
	local out = {}
	for i = 0, count do
		table.insert(out, -length / 2 + (length / count) * i)
	end
	return out
end

local function decorRickety(parent: Instance, originCF: CFrame, centre: Vector3, length: number, alongX: boolean, tier: any)
	local WOOD = Color3.fromRGB(124, 100, 76)
	local WOOD_PALE = Color3.fromRGB(152, 128, 98)

	-- Rails in broken segments. A rickety fence is defined by what's missing,
	-- so roughly one plank in four is simply never built.
	for row, height in ipairs({ 1.2, 2.5 }) do
		local segments = math.max(3, math.round(length / 5))
		local segLength = length / segments
		for i = 0, segments - 1 do
			if (i + row) % 4 ~= 2 then
				local t = -length / 2 + segLength * (i + 0.5)
				local rail = decorPart(parent, "Rail",
					spanSize(alongX, segLength * 0.9, 0.4, 0.35),
					originCF * CFrame.new(centre + alongVec(alongX, t) + Vector3.new(0, FENCE_BASE_Y + height, 0)))
				rail.Material = Enum.Material.WoodPlanks
				rail.Color = if i % 2 == 0 then WOOD else WOOD_PALE
			end
		end
	end

	for i, t in ipairs(stepsAlong(length, 5)) do
		local post = decorPart(parent, "Post", Vector3.new(0.55, tier.decorTop, 0.55),
			originCF * CFrame.new(centre + alongVec(alongX, t) + Vector3.new(0, FENCE_BASE_Y + tier.decorTop / 2, 0)))
		post.Material = Enum.Material.WoodPlanks
		post.Color = WOOD
		-- A few degrees of lean, alternating, so the line never looks surveyed.
		local lean = math.rad((i % 3 - 1) * 3.5)
		post.CFrame = post.CFrame
			* (if alongX then CFrame.Angles(lean, 0, 0) else CFrame.Angles(0, 0, lean))
	end
end

local function decorPicket(parent: Instance, originCF: CFrame, centre: Vector3, length: number, alongX: boolean, tier: any)
	local WHITE = Color3.fromRGB(246, 246, 240)

	for _, height in ipairs({ 1.3, 3.4 }) do
		local rail = decorPart(parent, "Rail", spanSize(alongX, length, 0.35, 0.28),
			originCF * CFrame.new(centre + Vector3.new(0, FENCE_BASE_Y + height, 0)))
		rail.Material = Enum.Material.SmoothPlastic
		rail.Color = WHITE
	end

	for _, t in ipairs(stepsAlong(length, 2.6)) do
		local base = centre + alongVec(alongX, t)
		local picket = decorPart(parent, "Picket", spanSize(alongX, 0.5, tier.top, 0.22),
			originCF * CFrame.new(base + Vector3.new(0, FENCE_BASE_Y + tier.top / 2, 0)))
		picket.Material = Enum.Material.SmoothPlastic
		picket.Color = WHITE

		-- Rotated cube reads as a point from the front, which is the entire
		-- silhouette of a picket fence, and costs one part instead of two wedges.
		local tip = decorPart(parent, "Tip", Vector3.new(0.42, 0.42, 0.42),
			originCF * CFrame.new(base + Vector3.new(0, FENCE_BASE_Y + tier.top + 0.2, 0)))
		tip.Material = Enum.Material.SmoothPlastic
		tip.Color = WHITE
		tip.CFrame = tip.CFrame
			* (if alongX then CFrame.Angles(0, 0, math.rad(45)) else CFrame.Angles(math.rad(45), 0, 0))
	end
end

local function decorBarbed(parent: Instance, originCF: CFrame, centre: Vector3, length: number, alongX: boolean, tier: any)
	local STEEL = Color3.fromRGB(104, 110, 120)

	for _, height in ipairs({ 1.4, 3.0, 4.6 }) do
		local wire = decorPart(parent, "Wire", spanSize(alongX, length, 0.16, 0.16),
			originCF * CFrame.new(centre + Vector3.new(0, FENCE_BASE_Y + height, 0)))
		wire.Material = Enum.Material.DiamondPlate
		wire.Color = STEEL
	end

	-- The top strand sits above the barrier, so the thing you have to clear is
	-- visibly the nasty bit rather than an invisible line.
	local top = decorPart(parent, "Wire", spanSize(alongX, length, 0.2, 0.2),
		originCF * CFrame.new(centre + Vector3.new(0, FENCE_BASE_Y + tier.decorTop, 0)))
	top.Material = Enum.Material.DiamondPlate
	top.Color = Color3.fromRGB(152, 158, 168)

	for _, t in ipairs(stepsAlong(length, 6)) do
		local post = decorPart(parent, "Post", Vector3.new(0.45, tier.decorTop, 0.45),
			originCF * CFrame.new(centre + alongVec(alongX, t) + Vector3.new(0, FENCE_BASE_Y + tier.decorTop / 2, 0)))
		post.Material = Enum.Material.Metal
		post.Color = STEEL
	end
end

local function decorElectric(parent: Instance, originCF: CFrame, centre: Vector3, length: number, alongX: boolean, tier: any)
	decorBarbed(parent, originCF, centre, length, alongX, tier)

	local LIVE = Color3.fromRGB(255, 226, 92)
	for _, height in ipairs({ 2.2, 4.6, tier.decorTop }) do
		local live = decorPart(parent, "Live", spanSize(alongX, length, 0.2, 0.2),
			originCF * CFrame.new(centre + Vector3.new(0, FENCE_BASE_Y + height, 0)))
		live.Material = Enum.Material.Neon
		live.Color = LIVE
	end

	-- One emitter per side rather than per strand: the arcing is atmosphere,
	-- and four emitters a plot is already plenty of particles.
	local arc = Instance.new("ParticleEmitter")
	arc.Name = "Arc"
	arc.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	arc.Color = ColorSequence.new(Color3.fromRGB(255, 244, 190), LIVE)
	arc.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	arc.Lifetime = NumberRange.new(0.2, 0.45)
	arc.Rate = 6
	arc.Speed = NumberRange.new(0.5, 2)
	arc.SpreadAngle = Vector2.new(180, 180)
	arc.LightEmission = 1
	arc.Parent = parent:FindFirstChild("Live") or parent
end

local function decorMoat(parent: Instance, originCF: CFrame, centre: Vector3, length: number, alongX: boolean, tier: any)
	-- The wall itself is unchanged from Electric; the water is the upgrade,
	-- and it is built once for the whole ring rather than per side.
	decorElectric(parent, originCF, centre, length, alongX, tier)
end

local FENCE_STYLES: { [string]: (Instance, CFrame, Vector3, number, boolean, any) -> () } = {
	rickety = decorRickety,
	picket = decorPicket,
	barbed = decorBarbed,
	electric = decorElectric,
	moat = decorMoat,
}

function PlotService.buildFence(plot: Plot, level: number)
	plot.fence:ClearAllChildren()
	if level <= 0 then
		return
	end

	local tier = Config.FENCE_TIERS[math.clamp(level, 1, #Config.FENCE_TIERS)]
	local decorate = FENCE_STYLES[tier.style] or decorRickety
	local originCF = plot.cframe
	-- THE SIDES AND THE FRONT ARE DIFFERENT NUMBERS. This was one `half` doing
	-- both jobs, which was right only while the plot was square -- see
	-- Config.PLOT_HALF_WIDTH.
	local half = Config.PLOT_HALF_WIDTH
	local frontZ = Config.PLOT_FRONT_LINE
	local gate = tier.gate

	local climbPenalty = {
		label = tier.label,
		slow = tier.slow,
		duration = tier.duration,
		stun = tier.stun or 0,
	}

	local function firePenalty(hit: BasePart, penalty: any)
		local character = hit.Parent
		if not character or not character:FindFirstChildOfClass("Humanoid") then
			return
		end
		local crosser = Players:GetPlayerFromCharacter(character)
		-- Owners cross their own defences freely; they paid for them.
		if not crosser or crosser == plot.owner then
			return
		end
		for _, callback in ipairs(fencePenaltyHandlers) do
			task.spawn(callback, crosser, plot, penalty)
		end
	end

	local function side(centre: Vector3, length: number, alongX: boolean)
		-- The one and only colliding part of the fence. Solid from the ground
		-- to `top` so there is nothing to slip between.
		local barrier = Instance.new("Part")
		barrier.Name = "Barrier"
		barrier.Size = spanSize(alongX, length, tier.top, 0.6)
		barrier.CFrame = originCF * CFrame.new(centre + Vector3.new(0, FENCE_BASE_Y + tier.top / 2, 0))
		barrier.Anchored = true
		barrier.CanCollide = true
		barrier.CanQuery = false
		barrier.Transparency = 1
		barrier.Parent = plot.fence

		decorate(plot.fence, originCF, centre, length, alongX, tier)

		-- Snag volume, sitting above the barrier so it only catches players
		-- coming over the top, never anyone walking in through the gate.
		local zone = Instance.new("Part")
		zone.Name = "ClimbZone"
		zone.Size = spanSize(alongX, length, 5, 3)
		zone.CFrame = originCF * CFrame.new(centre + Vector3.new(0, FENCE_BASE_Y + tier.top + 2.5, 0))
		zone.Anchored = true
		zone.CanCollide = false
		zone.CanQuery = false
		zone.Transparency = 1
		zone.Parent = plot.fence

		zone.Touched:Connect(function(hit)
			firePenalty(hit, climbPenalty)
		end)
	end

	-- The yard is a long rectangle, not a square: the front fence stays exactly
	-- where every heist number expects it, and the sides run BACK to enclose
	-- the house. A thief approaches from the street, so nothing behind the
	-- piggy affects the steal, the getaway or the drop-off.
	local backZ = Config.YARD_DEPTH
	-- The sides run from the FRONT LINE back to the back fence, so their length
	-- is a Z span and takes frontZ; their POSITION is an X offset and takes
	-- half. Mixing those is what a single `half` used to hide.
	local sideLength = frontZ + backZ
	local sideCentre = (frontZ - backZ) / 2

	side(Vector3.new(0, 0, -backZ), half * 2, true)
	side(Vector3.new(-half, 0, sideCentre), sideLength, false)
	side(Vector3.new(half, 0, sideCentre), sideLength, false)

	local wing = half - gate / 2
	if wing > 0 then
		local offset = gate / 2 + wing / 2
		side(Vector3.new(-offset, 0, frontZ), wing, true)
		side(Vector3.new(offset, 0, frontZ), wing, true)
	end

	-- Moat ------------------------------------------------------------
	--
	-- Sits in the one-stud step between the world ground and the plot slab, so
	-- it reads as dug rather than poured on top. The gate mouth is left dry:
	-- there is always a clean way in for anyone willing to take the long route.
	--
	-- WHY THIS IS NOT TERRAIN WATER. Roblox's real water -- the animated,
	-- refracting, swimmable kind -- only exists on Terrain, and Terrain is
	-- voxelised at four studs. This moat is five studs wide and about one
	-- stud deep, so a terrain fill would round it into a blocky four-stud
	-- gouge; the world ground it would have to cut through is a Part, not
	-- terrain, so there is nothing to carve; and dropping a player into the
	-- Swimming humanoid state would walk straight through the carry-speed
	-- model that every other number here is calibrated against. So it is
	-- parts, and the water-ness is built rather than inherited.
	--
	-- Three things do that, and the first matters most: a channel needs a
	-- VISIBLE EDGE. Flat blue laid on flat green is a carpet no matter what
	-- colour it is -- what says "dug" is the bank standing proud on either
	-- side, casting a line of shadow down onto the surface. Then depth: the
	-- surface is a thick translucent slab rather than a sheet, so you look
	-- down THROUGH a volume of blue into a dark bed. Then motion, which is
	-- client-side for the same reason the animated skins are (see
	-- ClientMain): the server tags the parts and publishes their span, and
	-- every machine works the ripples out for itself.
	if tier.moat then
		local m = tier.moat
		local moatPenalty = { label = "Moat", slow = m.slow, duration = m.duration, stun = 0 }
		-- `mid`/`reach` are the SIDE bands' X offsets and the FRONT band's Z, and
		-- those are no longer the same distance from the centre. The front pair
		-- is measured off the front line; the sides off the half width.
		local mid = half + 0.5 + m.width / 2
		local reach = half + 0.5 + m.width
		local frontMid = frontZ + 0.5 + m.width / 2
		local frontReach = frontZ + 0.5 + m.width

		-- Mirrors the fence rectangle: the back band sits behind the house and
		-- the side bands run the full length of the yard.
		local backMid = backZ + 0.5 + m.width / 2
		local backReach = backZ + 0.5 + m.width
		local sideMoatLength = frontReach + backReach
		local sideMoatCentre = (frontReach - backReach) / 2

		-- THE CHANNEL IS RAISED, NOT DUG, and it has to be.
		--
		-- The world ground is one solid slab and a Part cannot cut a hole in
		-- another Part, so a water surface set below ground level is not a
		-- trench -- it is simply invisible, hidden behind the grass that is
		-- still there above it. (Measured: at 0.16 under the ground the whole
		-- moat disappeared.) So every layer here sits PROUD of the ground, and
		-- the sunkenness is an illusion the banks do all the work for: kerbs
		-- standing 0.5 above the grass with a water surface 0.19 BELOW their
		-- top edge reads as a channel, because the eye takes the highest line
		-- as ground level.
		--
		-- Heights are all relative to FENCE_BASE_Y, the world ground:
		--     bank   -0.10 .. +0.50   (bottom buried, top is the kerb line)
		--     water  -0.19 .. +0.31   (a volume, seen into from above)
		--     bed    -0.47 .. +0.03   (opaque and dark, the thing you see)
		-- Nothing shares a face height with anything else, which is the rule
		-- the road and the old moat both broke.
		local BANK_H, BANK_W = 0.6, 1.0
		local BANK_Y = FENCE_BASE_Y + 0.20
		local DEEP = 0.5
		local WATER_Y = FENCE_BASE_Y + 0.06
		local SURFACE_Y = WATER_Y + DEEP / 2
		local BED_Y = FENCE_BASE_Y - 0.22
		local WATER = Color3.fromRGB(38, 104, 164)
		local BED = Color3.fromRGB(26, 52, 64)
		local STONE = Color3.fromRGB(112, 116, 118)

		local splashed: { [Player]: number } = {}
		local bandIndex = 0

		-- One kerb run. Built along the RING rather than per band -- see the
		-- rim pass below for why.
		local function bank(centre: Vector3, length: number, alongX: boolean)
			local b = Instance.new("Part")
			b.Name = "MoatBank"
			b.Size = spanSize(alongX, length, BANK_H, BANK_W)
			b.CFrame = originCF * CFrame.new(centre + Vector3.new(0, BANK_Y, 0))
			b.Anchored = true
			b.CanCollide = false
			b.CanQuery = false
			-- The one thing here that casts: the kerb's shadow falling across
			-- the water is most of what sells the depth.
			b.CastShadow = true
			b.Color = STONE
			b.Material = Enum.Material.Slate
			b.TopSurface = Enum.SurfaceType.Smooth
			b.BottomSurface = Enum.SurfaceType.Smooth
			b.Parent = plot.fence
		end

		local function channel(centre: Vector3, length: number, alongX: boolean)
			bandIndex += 1

			-- The bed: opaque, dark, and the thing actually seen through the
			-- water. Without it the translucent surface tints the grass
			-- underneath and the moat comes out pond-green.
			local bed = Instance.new("Part")
			bed.Name = "MoatBed"
			bed.Size = spanSize(alongX, length, 0.5, m.width)
			bed.CFrame = originCF * CFrame.new(centre + Vector3.new(0, BED_Y, 0))
			bed.Anchored = true
			bed.CanCollide = false
			bed.CanQuery = false
			bed.CastShadow = false
			bed.Color = BED
			bed.Material = Enum.Material.Slate
			bed.TopSurface = Enum.SurfaceType.Smooth
			bed.BottomSurface = Enum.SurfaceType.Smooth
			bed.Parent = plot.fence

			local w = Instance.new("Part")
			w.Name = "MoatWater"
			-- A VOLUME, not a sheet. A flat plane has nothing to see into;
			-- half a stud of translucent blue over a dark bed does.
			w.Size = spanSize(alongX, length, DEEP, m.width)
			w.CFrame = originCF * CFrame.new(centre + Vector3.new(0, WATER_Y, 0))
			w.Anchored = true
			w.CanCollide = false
			w.CanQuery = false
			w.CastShadow = false
			-- SmoothPlastic, not Glass. Glass plus reflectance washed out to
			-- near-white against the grass and stopped reading as water.
			w.Material = Enum.Material.SmoothPlastic
			w.Color = WATER
			w.Transparency = 0.38
			w.Reflectance = 0.07
			-- Everything the client's animation loop needs, and nothing it
			-- could work out for itself.
			w:SetAttribute("Phase", bandIndex * 0.83)
			w.Parent = plot.fence
			CollectionService:AddTag(w, "MoatWater")

			-- Splash, fired on entry rather than left running. A permanent
			-- emitter per band would be sixty of them across a full street to
			-- say something nobody looks at; a burst when someone goes in is
			-- the moment that actually wants marking.
			local splash = Instance.new("ParticleEmitter")
			splash.Name = "Splash"
			splash.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			splash.Color = ColorSequence.new(Color3.fromRGB(226, 244, 255), WATER)
			splash.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1.1),
				NumberSequenceKeypoint.new(1, 0),
			})
			splash.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.1),
				NumberSequenceKeypoint.new(1, 1),
			})
			splash.Lifetime = NumberRange.new(0.4, 0.8)
			splash.Speed = NumberRange.new(9, 16)
			splash.SpreadAngle = Vector2.new(40, 40)
			splash.Acceleration = Vector3.new(0, -55, 0)
			splash.LightEmission = 0.6
			splash.Rate = 0
			splash.Enabled = false
			splash.Parent = w

			-- Two ripple crests per band, animated along it by the client.
			-- Anchored, non-colliding, and invisible until the client moves
			-- them: a server that never touches them again costs nothing.
			for i = 1, 2 do
				local r = Instance.new("Part")
				r.Name = "MoatRipple"
				r.Size = spanSize(alongX, 1.8, 0.08, m.width * 0.8)
				r.CFrame = originCF * CFrame.new(centre + Vector3.new(0, SURFACE_Y + 0.025, 0))
				r.Anchored = true
				r.CanCollide = false
				r.CanQuery = false
				r.CastShadow = false
				r.Material = Enum.Material.SmoothPlastic
				r.Color = Color3.fromRGB(178, 216, 240)
				r.Transparency = 1
				r:SetAttribute("Span", length)
				r:SetAttribute("AlongX", alongX)
				r:SetAttribute("Phase", (bandIndex * 2 + i) * 0.37)
				r.Parent = plot.fence
				CollectionService:AddTag(r, "MoatRipple")
			end

			w.Touched:Connect(function(hit)
				local character = hit.Parent
				local crosser = character and Players:GetPlayerFromCharacter(character)
				if crosser then
					local now = os.clock()
					if now - (splashed[crosser] or 0) > 1.2 then
						splashed[crosser] = now
						splash:Emit(22)
					end
				end
				firePenalty(hit, moatPenalty)
			end)
		end

		channel(Vector3.new(0, 0, -backMid), reach * 2, true)
		channel(Vector3.new(-mid, 0, sideMoatCentre), sideMoatLength, false)
		channel(Vector3.new(mid, 0, sideMoatCentre), sideMoatLength, false)

		-- The causeway is driveway-width, NOT gate-width. The driveway has to
		-- stay dry at every tier or the top tier drowns its own entrance, and
		-- widening a bridge does not widen the gate behind it, so this costs
		-- the defender nothing.
		local causeway = math.max(gate, Config.DRIVEWAY_WIDTH + 1)
		local moatWing = reach - causeway / 2
		if moatWing > 0 then
			local offset = causeway / 2 + moatWing / 2
			channel(Vector3.new(-offset, 0, frontMid), moatWing, true)
			channel(Vector3.new(offset, 0, frontMid), moatWing, true)
		end

		-- The rim, laid as TWO CLOSED RECTANGLES rather than a pair of kerbs
		-- per band.
		--
		-- Per band was the obvious way and it was wrong: the bands overlap at
		-- the four corners, so each one's kerb ran straight across its
		-- neighbour's water and the moat came out with stone bars lying
		-- across it like cattle grids. The ring does not care how the water
		-- was cut up -- there is an outer edge and an inner edge, and the
		-- kerb belongs on those.
		-- Three pairs, because the ring is a RECTANGLE and its three edges are
		-- now three different distances from the plot centre: the sides off the
		-- half width, the front off the front line, the back off YARD_DEPTH.
		-- The front pair used to be copied from the side pair, which was right
		-- only while the plot was square.
		local outerX, innerX = reach + BANK_W / 2, (half + 0.5) - BANK_W / 2
		local outerFrontZ, innerFrontZ = frontReach + BANK_W / 2, (frontZ + 0.5) - BANK_W / 2
		local outerBackZ, innerBackZ = -(backReach + BANK_W / 2), -((backZ + 0.5) - BANK_W / 2)

		-- Parameters named for the EDGE they are, not `frontZ`/`backZ`: those
		-- are now real values in the enclosing scope and shadowing them here
		-- would make this function read as though it used them.
		local function rim(x: number, frontEdge: number, backEdge: number)
			local span = frontEdge - backEdge
			local midZ = (frontEdge + backEdge) / 2
			-- Sides run the full depth; overlong by a kerb width at each end
			-- so the corners close square instead of showing a notch.
			for _, s in ipairs({ -1, 1 }) do
				bank(Vector3.new(s * x, 0, midZ), span + BANK_W, false)
			end
			bank(Vector3.new(0, 0, backEdge), x * 2, true)

			-- The front run is the only one with a hole in it, and it is the
			-- same hole the water leaves: the causeway.
			local wing = x - causeway / 2
			if wing > 0 then
				local offset = causeway / 2 + wing / 2
				bank(Vector3.new(-offset, 0, frontEdge), wing, true)
				bank(Vector3.new(offset, 0, frontEdge), wing, true)
			else
				bank(Vector3.new(0, 0, frontEdge), x * 2, true)
			end
		end

		rim(outerX, outerFrontZ, outerBackZ)
		rim(innerX, innerFrontZ, innerBackZ)
	end
end

function PlotService.onFencePenalty(callback: (Player, any, any) -> ())
	table.insert(fencePenaltyHandlers, callback)
end

-- Rebuilt from scratch on every change, unlike the dog. House tiers differ in
-- footprint, storey count and which details exist at all, so there is no
-- shared skeleton to resize -- and this runs once per purchase, not per frame.
--
-- Sits well behind the plot: clear of the fence at 25.6 and a top-tier moat at
-- 31.1, facing the street so the front is what the road sees.
-- Rebuilds the whole ornament set. Cheap enough to redo wholesale on each
-- purchase, and wholesale avoids having to diff slots.
-- DECLARED ABOVE `setDecor`, WHICH IS ITS FIRST CALLER, AND THAT PLACEMENT IS
-- LOAD-BEARING. A `local` declared after a function that reads it does not
-- error in Luau -- it compiles as a nil GLOBAL and dies at the call naming
-- nothing useful. This file has lost six bugs to exactly that, and this block
-- was written 300 lines lower down before the line numbers gave it away.

-- ============================================================
-- TRAMPOLINES
-- ============================================================
--
-- The first decoration that does anything, and everything below exists to keep
-- it from being a power item.
--
-- IT MUST NOT CHANGE AN OUTCOME -- not the steal, the chase, the tag or the
-- getaway. A bounce is a toy. That is asserted twice over: once by making it
-- vertical only, and once by the veto below, which is what turns "it should
-- not matter in a chase" from an argument into a fact.
--
-- THE MAT IS A TRIGGER, NOT A SURFACE. Every ornament in this game is
-- CanCollide and CanQuery off, because they sit on the exact ground a defender
-- defends and a thief runs across. `Touched` fires on overlap without needing
-- collision, so that rule is untouched: a trampoline can never body-block
-- anybody and can never be stood behind as cover.
--
-- FOUND BY TAG, NEVER BY A LIST COLLECTED AT STARTUP. A plot's decor is torn
-- down and rebuilt every time an owner buys or puts away an ornament, so there
-- is no single moment at which trampolines could be enumerated -- the same
-- reason the moat's bands are tagged.
local bouncedAt: { [Player]: number } = {}
local bounceVetoes: { (Player) -> boolean } = {}

-- Registered by Main, for the reason SetService.registerPusher is: asking
-- "is this player carrying loot" means asking HeistService, and HeistService
-- already requires this file. A registry keeps the dependency list at one line
-- and makes the cycle impossible rather than merely absent today.
function PlotService.registerBounceVeto(fn: (Player) -> boolean)
	table.insert(bounceVetoes, fn)
end

local function bounce(hit: BasePart)
	local character = hit.Parent
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	-- Anything mid-heist is refused outright. This is the line that keeps a
	-- decoration out of the balance: a thief carrying somebody's coins cannot
	-- be launched, so the trampoline cannot lengthen a getaway, break a tag or
	-- get anyone over anything while it matters.
	for _, veto in ipairs(bounceVetoes) do
		if veto(player) then
			return
		end
	end

	local now = os.clock()
	if bouncedAt[player] and (now - bouncedAt[player]) < Config.TRAMPOLINE_COOLDOWN then
		return
	end
	bouncedAt[player] = now

	-- HANDED TO THE CLIENT, because a character's physics belong to the client
	-- that owns it and a server-side velocity write on somebody's root is
	-- simply discarded. Measured on a live rig: a raw write, a write after
	-- ChangeState(Jumping) and a write after ChangeState(Freefall) all left the
	-- character at exactly its 5.00-stud drop height. The server still owns the
	-- DECISION -- which mat, which player, the cooldown and the veto above are
	-- all decided here and none of it is sent.
	--
	-- The wheelie bin's exit hop gets away with a server write because it
	-- happens in the frame the root is unanchored, which is the one moment the
	-- server has authority over that assembly.
	Remotes.get("TrampolineBounce"):FireClient(player)
end

local function bindTrampoline(mat: Instance)
	if mat:IsA("BasePart") then
		mat.Touched:Connect(bounce)
	end
end

-- BOUND BY WALKING THE MODEL, NOT BY `GetInstanceAddedSignal`, AND THAT IS NOT
-- A PREFERENCE -- the signal version silently never fires.
--
-- `Decor.build` creates its Model DETACHED, runs every builder into it, and
-- parents it to the plot at the very end. So the tag is added while the part
-- is outside the DataModel, and CollectionService's added-signal only fires
-- for instances inside it. Measured: the mat was tagged, `GetTagged` returned
-- it, `Touched` fired fifteen times, and the handler had never been connected.
--
-- Note the moat does NOT have this problem and looked like a precedent for
-- doing it the other way: it parents each band to `plot.fence` as it builds,
-- and that folder is already in the world. Anything tagged inside a detached
-- model has to be bound after it lands.
local function bindTrampolinesIn(model: Instance)
	for _, d in ipairs(model:GetDescendants()) do
		if CollectionService:HasTag(d, Decor.TRAMPOLINE_TAG) then
			bindTrampoline(d)
		end
	end
end

function PlotService.setDecor(plot: Plot, placed: { [string]: string })
	if plot.decor then
		plot.decor:Destroy()
		plot.decor = nil
	end
	-- Three different floors, one per zone: the lawn is the top of the plot
	-- slab, the driveway is paving laid on the world ground, and the verge is
	-- the bare world ground. Passing a single height left everything outside
	-- the fence floating.
	local worldGround = -Config.PLOT_SIZE.Y / 2
	plot.decor = Decor.build(placed, plot.cframe, {
		lawn = Config.PLOT_SIZE.Y / 2,
		driveway = worldGround + DRIVEWAY_LIFT,
		verge = worldGround,
	}, plot.model)

	-- Anything functional in that model gets hooked up now that it is in the
	-- world. This runs on every decor change rather than once at startup,
	-- because a lawn is torn down and rebuilt whenever an owner buys or puts
	-- away an ornament -- there is no single moment at which they could all be
	-- collected. See bindTrampolinesIn for why a tag signal cannot do this.
	bindTrampolinesIn(plot.decor)
end

-- The strip of paving from the gate out to the kerb, surfaced by house tier.
--
-- Lives on the plot rather than in the neighbourhood scenery because it is
-- per-owner: it is the one part of the house upgrade visible from the road,
-- since the house itself stands 70 studs behind the piggy.
local function buildDriveway(plot: Plot, tier: any)
	local existing = plot.model:FindFirstChild("Driveway")
	if existing then
		existing:Destroy()
	end

	local drive = tier.drive
	if not drive then
		return
	end

	local m = Config.streetMetrics()
	local length = m.driveFar - m.driveNear
	if length <= 0 then
		return
	end

	local model = Instance.new("Model")
	model.Name = "Driveway"

	local function slab(name: string, size: Vector3, offset: Vector3, colour: Color3, material: Enum.Material)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = plot.cframe * CFrame.new(offset)
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Color = colour
		p.Material = material
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	-- Same lift discipline as the road: the top face must clear the grass, or
	-- two coplanar surfaces z-fight and the lawn flickers through the paving.
	local groundY = -Config.PLOT_SIZE.Y / 2
	local thickness = 0.8
	local centreZ = (m.driveNear + m.driveFar) / 2

	slab("Surface", Vector3.new(Config.DRIVEWAY_WIDTH, thickness, length),
		Vector3.new(0, groundY + DRIVEWAY_LIFT - thickness / 2, centreZ), drive.colour, drive.material)

	if drive.edge then
		for _, side in ipairs({ -1, 1 }) do
			slab("Edge", Vector3.new(0.7, thickness, length),
				Vector3.new(side * (Config.DRIVEWAY_WIDTH / 2 - 0.35), groundY + DRIVEWAY_LIFT + 0.04 - thickness / 2, centreZ),
				Color3.fromRGB(228, 226, 218), Enum.Material.Concrete)
		end
	end

	if drive.lit then
		for _, side in ipairs({ -1, 1 }) do
			slab("DriveLight", Vector3.new(0.35, thickness, length - 2),
				Vector3.new(side * (Config.DRIVEWAY_WIDTH / 2 - 1.2), groundY + DRIVEWAY_LIFT + 0.08 - thickness / 2, centreZ),
				Color3.fromRGB(240, 202, 110), Enum.Material.Neon)
		end
	end

	model.Parent = plot.model
end

-- Is this world position inside anybody's yard?
--
-- The yard is the fence rectangle, not the plot slab: `half` in front and to
-- the sides, YARD_DEPTH behind, all in plot-local space, which is the same
-- rectangle buildFence runs its barriers around. Measuring from the slab
-- instead would call the whole back garden public ground -- the exact mistake
-- that put the grove inside people's fences.
--
-- Returns the plot, so a caller can tell "my own lawn" from "someone else's".
-- Nothing uses that yet; RideService only cares that it is somebody's.
function PlotService.yardContaining(position: Vector3): Plot?
	-- TWO numbers, not one. `half` served as both the X extent and the front Z
	-- while the plot was square; the rectangle is 64 x 48 now, so a single
	-- value would test a square that is neither the fence nor the slab.
	local halfWidth = Config.PLOT_HALF_WIDTH
	local frontZ = Config.PLOT_FRONT_LINE

	for _, plot in ipairs(plots) do
		-- Into plot-local space, where the rectangle is axis-aligned and the
		-- far row's half-turn has already been taken care of.
		local local_ = plot.cframe:PointToObjectSpace(position)
		if math.abs(local_.X) <= halfWidth
			and local_.Z <= frontZ
			and local_.Z >= -Config.YARD_DEPTH
		then
			return plot
		end
	end
	return nil
end

function PlotService.setHouseLevel(plot: Plot, level: number)
	if plot.house then
		plot.house:Destroy()
		plot.house = nil
	end
	local groundY = -Config.PLOT_SIZE.Y / 2
	-- Passed the PLOT ORIGIN, not a pre-computed spot: House.build measures
	-- what it actually built and seats itself against the back fence, because
	-- the archetypes range from 15 to 47 studs deep.
	plot.house = House.build(level, plot.cframe * CFrame.new(0, groundY, 0), plot.model)
	buildDriveway(plot, Config.getHouseTier(level))
end

function PlotService.setDogLevel(plot: Plot, level: number)
	GuardDog.applyTier(plot.dog, level)
end

-- Publishes the owner's lock level as an attribute rather than only baking it
-- into HoldDuration.
--
-- The client re-times its own prompt for its lockpicks, so if it had to infer
-- the lock level from HoldDuration it would be reading a number it also
-- writes -- and any server change after the first read would get clobbered by
-- the client's stale copy. Replicating the level itself means both sides
-- derive the duration from the same input and neither can drift.
function PlotService.setLockLevel(plot: Plot, level: number)
	plot.model:SetAttribute("LockLevel", level)
	plot.piggy.stealPrompt.HoldDuration = Config.getStealHold(level, 0)
	PiggyBank.setLockLevel(plot.piggy, level)
end

-- Shakes the padlock while a thief is working on it.
function PlotService.rattleLock(plot: Plot)
	PiggyBank.rattleLock(plot.piggy)
end

-- ============================================================
-- VISUALS
-- ============================================================

-- Returns how many coins newly appeared, so callers can decide whether that
-- deserves a sound.
function PlotService.updatePile(plot: Plot, vault: number, capacity: number): number
	return PiggyBank.setFill(plot.piggy, vault, capacity)
end

function PlotService.playCoinDrop(plot: Plot)
	PiggyBank.playCoinDrop(plot.piggy)
end

function PlotService.playMilestone(plot: Plot, index: number, total: number)
	PiggyBank.playMilestone(plot.piggy, index, total)
end

function PlotService.playBank(plot: Plot)
	PiggyBank.playBank(plot.piggy)
end

function PlotService.playAlarm(plot: Plot)
	PiggyBank.playAlarm(plot.piggy)
end

-- The sign advertises the skin as well as the rebirth count -- a cosmetic
-- nobody can identify from a distance isn't worth grinding for.
-- The sign is the only thing on a plot that is READ rather than looked at, and
-- it faces the road. So it carries whichever boasts the owner has actually
-- earned, hardest first: rebirths, then the house, then the skin.
--
-- The house is on here because it is otherwise the least visible expensive
-- thing anybody owns. It stands 70 studs back, and past the first few tiers a
-- passer-by cannot tell a 1.4M manor from a 40M palace at that range. Naming
-- it turns the whole ladder into something other people can see, which is the
-- only kind of reward a house is allowed to give.
--
-- The Starter Shack is never named: a sign announcing the free tier reads as a
-- jeer at players who have not bought anything yet.
function PlotService.updateSign(plot: Plot, ownerName: string?, rebirths: number,
	skinName: string?, houseName: string?)
	if not ownerName then
		plot.signLabel.Text = "EMPTY PLOT"
		plot.signBoast.Text = "for sale"
		return
	end

	local boasts: { string } = {}
	if rebirths > 0 then
		table.insert(boasts, ("%d*"):format(rebirths))
	end
	if houseName and houseName ~= Config.HOUSE_TIERS[1].name then
		table.insert(boasts, houseName)
	end
	if skinName and skinName ~= Config.getSkin(Config.DEFAULT_SKIN).name then
		table.insert(boasts, skinName)
	end

	-- The name owns the top row at a fixed size whatever the boasts say; the
	-- boasts get their own smaller row underneath. Sharing one TextScaled
	-- label meant buying a house shrank your own name.
	plot.signLabel.Text = ownerName
	plot.signBoast.Text = table.concat(boasts, " · ")
end

function PlotService.applySkin(plot: Plot, skinKey: string)
	PiggyBank.applySkin(plot.piggy, skinKey)
end

function PlotService.applyAccessories(plot: Plot, worn: { [string]: string })
	PiggyBank.applyAccessories(plot.piggy, worn)
end

function PlotService.applyEffect(plot: Plot, effectKey: string)
	PiggyBank.applyEffect(plot.piggy, effectKey)
end

-- ============================================================
-- ASSIGNMENT
-- ============================================================

function PlotService.assign(player: Player): Plot?
	if byPlayer[player] then
		return byPlayer[player]
	end

	for _, plot in ipairs(plots) do
		if plot.owner == nil then
			plot.owner = player
			byPlayer[player] = plot
			plot.model:SetAttribute("OwnerUserId", player.UserId)
			PlotService.updateSign(plot, player.DisplayName, 0)
			return plot
		end
	end

	warn(("[PlotService] No free plot for %s"):format(player.Name))
	return nil
end

function PlotService.release(player: Player)
	local plot = byPlayer[player]
	if not plot then
		return
	end

	plot.owner = nil
	byPlayer[player] = nil
	plot.model:SetAttribute("OwnerUserId", nil)
	PlotService.updateSign(plot, nil, 0)
	PlotService.applySkin(plot, Config.DEFAULT_SKIN)
	PlotService.applyEffect(plot, Config.DEFAULT_EFFECT)
	PlotService.updatePile(plot, 0, Config.BASE_CAPACITY)
	-- Wipe the previous owner's defences so the next arrival gets a bare
	-- plot -- and put the house back to the Starter Shack with them. It was
	-- the one thing release never reset, so a player leaving with a Sky
	-- Castle left the Sky Castle standing on an unclaimed plot until
	-- somebody else took it over.
	PlotService.buildFence(plot, 0)
	PlotService.setDogLevel(plot, 0)
	PlotService.setLockLevel(plot, 0)
	PlotService.setHouseLevel(plot, 0)
end

function PlotService.getPlot(player: Player): Plot?
	return byPlayer[player]
end

function PlotService.getAll(): { Plot }
	return plots
end

function PlotService.getSpawnCFrame(plot: Plot): CFrame
	return PiggyBank.getViewCFrame(plot.cframe)
end

function PlotService.getOwnerOf(model: Model): Player?
	for _, plot in ipairs(plots) do
		if plot.model == model then
			return plot.owner
		end
	end
	return nil
end


function PlotService.start()
	Players.PlayerRemoving:Connect(function(player)
		bouncedAt[player] = nil
	end)

	-- The Brace Face turtle's headband is runtime CSG and CSG is
	-- server-only, so its template is built here, once, before any plot can
	-- possibly need it -- a saved lawn reconstructing on join is the one
	-- moment this would otherwise race a purchase.
	Decor.prewarm()

	local existing = workspace:FindFirstChild("Plots")
	if existing then
		existing:Destroy()
	end

	plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = workspace

	-- Every plot gets the Starter Shack standing on it before anyone owns
	-- it. Level 0 is the free tier that every player already has, so an
	-- unclaimed plot showing one is honest rather than generous -- and a
	-- bare slab reads as unfinished map rather than as an empty house.
	--
	-- It also builds the driveway, which only ever happened inside
	-- setHouseLevel, so an unowned plot had no drive either.
	for index = 1, Config.PLOT_COUNT do
		local plot = buildPlot(index)
		table.insert(plots, plot)
		PlotService.setHouseLevel(plot, 0)
	end

	Players.PlayerRemoving:Connect(function(player)
		PlotService.release(player)
	end)
end

return PlotService
