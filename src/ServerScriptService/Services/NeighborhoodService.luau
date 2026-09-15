--!strict
--[[
	NeighborhoodService

	The suburb the plots sit in: road, sidewalks, driveways, street furniture
	and the woodland that closes off the view behind the plots.

	None of it is interactive. Every part built here is CanCollide false,
	CanQuery false and CastShadow false -- it exists to make the street read
	as a place rather than twelve lawns in a field, and it must never get in
	the way of a chase or eat a raycast meant for a piggy.

	The one exception is the road surface, which players walk on. It sits a
	few hundredths of a stud proud of the grass rather than flush with it --
	see the LIFT_ constants for why flush is not an option.

	Everything is positioned off Config, so moving the plots moves the suburb
	with them. Nothing here hardcodes a plot coordinate.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollectionService = game:GetService("CollectionService")

local Config = require(ReplicatedStorage.Shared.Config)
local Decor = require(ReplicatedStorage.Shared.Decor)
local ShopFront = require(ReplicatedStorage.Shared.ShopFront)
local PiggyModel = require(ReplicatedStorage.Shared.PiggyModel)
local RideModel = require(ReplicatedStorage.Shared.RideModel)
local BoneModel = require(ReplicatedStorage.Shared.BoneModel)
local GrassTuft = require(ReplicatedStorage.Shared.GrassTuft)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local NeighborhoodService = {}

-- Ground top. The plot slabs are centred on y=0 and one stud thick, so the
-- world outside them sits half a stud lower.
local GROUND_Y = -Config.PLOT_SIZE.Y / 2

local ROAD = Color3.fromRGB(74, 74, 82)
local ROAD_LINE = Color3.fromRGB(226, 206, 120)
local KERB = Color3.fromRGB(198, 196, 188)
local TRUNK = Color3.fromRGB(96, 68, 48)
local LEAF = Color3.fromRGB(84, 132, 66)
local LEAF_2 = Color3.fromRGB(102, 150, 78)

-- The two shades of canopy, as a MULTIPLY rather than as a colour.
--
-- The ball canopy took LEAF and LEAF_2 outright. A MeshPart multiplies its
-- Color against the texture it carries, so the meshed tree gets the same two
-- shades as a near-white tint instead: white is the map as painted, and the
-- second is a gentle darkening. Handed LEAF itself the canopy loses the baked
-- shading between its leaf clumps, which is the only thing making it read as
-- clumps at all. See the note over `Config.TREE_MESH`.
local CANOPY_TINT = Color3.fromRGB(255, 255, 255)
local CANOPY_TINT_2 = Color3.fromRGB(214, 234, 198)

-- The painted lawn surface, built by WorldService before this service runs.
-- Named rather than asked for: a dangling MaterialVariant falls back to the
-- BaseMaterial, so a name that did not build renders as the stock grass that
-- shipped before it existed.
local LAWN_VARIANT = Config.GRASS_MATERIAL.name

-- How much daylight a canopy has to leave between itself and a back fence.
local CANOPY_CLEARANCE = 1.5

-- Flat overlays must sit ABOVE the ground, never flush with it.
--
-- A part whose top face is exactly coplanar with the grass z-fights: two
-- surfaces at the same depth give the renderer nothing to sort by, so it
-- picks per pixel and per camera angle and the grass flickers through the
-- asphalt. Each overlay gets its own lift, which both clears the ground and
-- puts the layers in a defined order -- road, then its markings, then the
-- kerb, then the driveway crossing over the kerb like a real dropped kerb.
--
-- The largest of these is 0.22 studs. A character steps over that without
-- any change to how it walks, so nothing here can catch a fleeing thief.
local LIFT_ROAD = 0.06
local LIFT_LINE = 0.12
local LIFT_KERB = 0.16
local LIFT_DRIVE = 0.22

local folder: Folder

local function scenery(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder
	return p
end

-- Lays a flat surface whose TOP face lands at exactly GROUND_Y + lift,
-- regardless of how thick the slab is. Thickness only exists so the part has
-- volume; it is buried in the ground and never seen.
local function pave(name: string, width: number, depth: number, x: number, z: number,
	lift: number, color: Color3, material: Enum.Material): Part
	local thickness = 0.8
	return scenery(name, Vector3.new(width, thickness, depth),
		CFrame.new(x, GROUND_Y + lift - thickness / 2, z), color, material)
end

-- ============================================================
-- LAYOUT MATHS
-- ============================================================

-- Everything below is derived, so the suburb follows the plots if the grid
-- ever changes shape.
local function metrics()
	-- Every number here comes from Config.streetMetrics, which is the single
	-- source. This file used to keep its own copy of the arithmetic and the two
	-- drifted -- and the plaza and road extents have now moved there too,
	-- because RideService needs to know where the street is in order to keep
	-- vehicles on it, and a third copy would drift the same way.
	local street = Config.streetMetrics()

	return {
		perRow = Config.PLOTS_PER_ROW,
		halfPlot = Config.PLOT_SIZE.X / 2,
		endX = street.endX,
		rowZ = Config.STREET_SPACING / 2,

		-- Fixed carriageway; everything between it and the fence is verge and
		-- driveway, which is where the extra street width goes.
		roadHalfWidth = street.roadHalfWidth,
		vergeOuter = street.fenceLine,

		boardZ = street.boardZ,
		shopZ = street.shopZ,
		roadStartX = street.roadStartX,
		roadEndX = street.roadEndX,

		-- The hillsides at each end, and the bore through them.
		tunnelEastX = street.tunnelEastX,
		tunnelWestX = street.tunnelWestX,
		tunnelDepth = street.tunnelDepth,
		tunnelHalfWidth = street.tunnelHalfWidth,
		tunnelHeight = street.tunnelHeight,
	}
end

local function columnX(m: any, col: number): number
	return Config.plotColumnX(col)
end

-- The gap between two frontages, which is where everything that is not a
-- driveway goes. The row is continuous again, so a plot column IS a slot and
-- this is simply the midpoint of two neighbours -- there is no hole to step
-- over any more.
local function gapX(col: number): number
	return (Config.plotColumnX(col) + Config.plotColumnX(col + 1)) / 2
end

-- ============================================================
-- PIECES
-- ============================================================

local function buildRoad(m: any)
	local length = m.roadEndX - m.roadStartX
	local centreX = (m.roadStartX + m.roadEndX) / 2

	pave("Road", length, m.roadHalfWidth * 2, centreX, 0, LIFT_ROAD, ROAD, Enum.Material.Asphalt)

	for _, side in ipairs({ -1, 1 }) do
		pave("Kerb", length, 1.6, centreX, side * m.roadHalfWidth, LIFT_KERB,
			KERB, Enum.Material.Concrete)
	end

	-- Centre line, dashed, starting clear of the cul-de-sac lip.
	local dash = 7
	local gap = 9
	local x = m.roadStartX + 5
	while x < m.roadEndX - dash do
		pave("RoadLine", dash, 0.7, x + dash / 2, 0, LIFT_LINE, ROAD_LINE, Enum.Material.SmoothPlastic)
		x += dash + gap
	end
end

-- Driveways are NOT built here any more.
--
-- Each plot lays its own, surfaced according to the owner's house tier, so a
-- generic concrete strip per column would sit on top of it. See
-- PlotService.setHouseLevel.

-- ============================================================
-- THE GROVE
-- ============================================================
--
-- Twenty-six trees close the view behind the plots, which makes them the
-- largest thing in anybody's picture of this street after the grass itself.
-- What shipped was a brown box with a green ball balanced on top of it:
-- correct from a plan view, and a lollipop from the pavement.

local treeTemplates: { [string]: BasePart }? = nil
local treeChecked = false

-- Built ONCE and cloned per tree, because `CreateMeshPartAsync` yields and a
-- web call inside a build loop is twenty-six web calls to say one thing. The
-- same shape as `PiggyBank.ensureMeshTemplates` and `PlayerGear.prewarm`.
--
-- AND THE TEXTURE IS APPLIED HERE, BECAUSE THAT CALL DOES NOT CARRY ONE. It
-- takes a mesh id and returns an untextured part however the asset was
-- authored, which is how the first build of this shipped flat canopies with
-- nothing in the log to say so -- the failure was that the trees looked
-- worse, which is the quietest kind this file records. Inside a pcall,
-- because `MeshPart.MeshId` is capability-gated from a real Script and its
-- neighbour is a reasonable thing to expect the same of.
--
-- `RenderFidelity` IS `Automatic` HERE, WHICH IS THE OPPOSITE OF THE PIGGY'S
-- AND IS THE POINT RATHER THAN AN OVERSIGHT. The pig is `Precise` because it
-- is read from the pavement and is the one object a robbery is about, so
-- shedding its triangles with distance would show. A tree is backdrop and
-- there are a hundred of them, and shedding triangles with distance is
-- exactly what you want from a hundred backdrop objects.
local function ensureTreeTemplates(): { [string]: BasePart }?
	if treeChecked then
		return treeTemplates
	end
	treeChecked = true

	local spec = Config.treeMesh()
	if not spec then
		return nil
	end

	local ok, result = pcall(function()
		local insert = game:GetService("InsertService")
		local made: { [string]: BasePart } = {}
		for _, entry in ipairs(spec.parts) do
			local part = insert:CreateMeshPartAsync(entry.id,
				Enum.CollisionFidelity.Box, Enum.RenderFidelity.Automatic)
			if entry.texture then
				part.TextureID = entry.texture
			end
			made[entry.part] = part
		end
		return made
	end)

	if not ok then
		-- NEVER FAIL SILENTLY. A grove that quietly stayed as lollipops after
		-- somebody pasted two ids is indistinguishable from ids that did not
		-- take.
		warn(("[NeighborhoodService] the tree mesh could not be loaded, so the "
			.. "box-and-ball trees are standing instead: %s"):format(tostring(result)))
		return nil
	end

	treeTemplates = result
	return treeTemplates
end

local function treeScale(spec: any, seed: number): number
	return spec.scales[(seed % #spec.scales) + 1]
end

-- The furthest a canopy can reach horizontally from its own trunk, at any yaw.
--
-- THE DIAGONAL, NOT THE DEPTH, because every tree is turned on its own axis
-- for variety: a canopy twelve studs wide by ten and a half deep presents its
-- CORNER at forty-five degrees, which is eight studs rather than five. Taking
-- the depth alone gives a clearance that happens to be right for the trees
-- facing the street and wrong for the ones that are not, which is an
-- asymmetry no screenshot catches. Exactly the tube man that broke the side
-- fence on the four left-hand lawn slots and not the four right-hand ones.
local function canopyReach(spec: any, scale: number): number
	return math.sqrt(spec.width ^ 2 + spec.canopyDepth ^ 2) / 2 * scale
end

-- What shipped before the mesh. Kept, and reached whenever `Config.TREE_MESH`
-- has no ids in it, so a fresh empty place plus this repo still builds the
-- world this repo has always built.
local function buildBoxTree(x: number, z: number, seed: number)
	local height = 9 + (seed % 3) * 2
	scenery("Trunk", Vector3.new(1.6, height, 1.6),
		CFrame.new(x, GROUND_Y + height / 2, z), TRUNK, Enum.Material.Wood)

	local canopy = 8 + (seed % 3)
	local top = scenery("Canopy", Vector3.new(canopy, canopy, canopy),
		CFrame.new(x, GROUND_Y + height + canopy / 3, z),
		if seed % 2 == 0 then LEAF else LEAF_2, Enum.Material.Grass)
	top.Shape = Enum.PartType.Ball
end

local function buildTree(x: number, z: number, seed: number, scaleOverride: number?)
	local spec = Config.treeMesh()
	local templates = spec and ensureTreeTemplates()
	if not (spec and templates) then
		buildBoxTree(x, z, seed)
		return
	end

	-- The grove picks its scale off the seed, which is what gives it a height
	-- spread. A street tree is placed against measured clearances instead, so
	-- it is handed one.
	local scale = scaleOverride or treeScale(spec, seed)
	-- A turn per tree, stepped by the golden angle so consecutive seeds never
	-- land near each other. It costs nothing and it is the whole difference
	-- between a grove and a hundred copies of one tree.
	local base = CFrame.new(x, GROUND_Y, z)
		* CFrame.Angles(0, (seed * 2.39996) % (math.pi * 2), 0)

	for _, entry in ipairs(spec.parts) do
		local template = templates[entry.part]
		if template then
			local part = template:Clone()
			part.Name = entry.part
			-- SIZE BEFORE CFRAME. Resizing a MeshPart scales it about its own
			-- centre, so a part seated first and scaled afterwards moves off
			-- the spot it was seated on.
			part.Size = entry.size * scale
			part.CFrame = base * CFrame.new(entry.offset * scale)
			part.Anchored = true
			-- Everything in this file is scenery a chase has to be able to run
			-- through, and a cloned mesh does not inherit that from `scenery`.
			part.CanCollide = false
			part.CanQuery = false
			part.CastShadow = false
			if entry.part == "Canopy" then
				part.Color = if seed % 2 == 0 then CANOPY_TINT else CANOPY_TINT_2
			end
			part.Parent = folder
		end
	end
end

-- How far a mailbox reaches ACROSS the drive it stands beside. The body is
-- 1.9 wide and 2.7 long and the whole thing is turned twelve degrees, so its
-- X extent is 1.9*cos12 + 2.7*sin12 = 2.42 studs, and 1.3 covers the half of
-- that with a little in hand. Anything that widens the box has to move this
-- with it or the mailbox walks back onto the tarmac.
local MAILBOX_HALF = 1.3

local function buildStreetFurniture(m: any)
	for _, side in ipairs({ -1, 1 }) do
		-- On the verge, just off the kerb. This used to be measured from the
		-- old full-corridor road edge, which put every lamp post and mailbox
		-- 4 studs INSIDE the player's fence.
		local z = side * (m.roadHalfWidth + 1.8)

		-- Lamp posts land in the gaps BETWEEN frontages, never in a driveway.
		-- They sit just off the kerb, in front of whatever else is in the gap:
		-- the verge is 38 studs deep now, so a lamp at 9.8 and a shop at 34
		-- are not competing for the same ground.
		for col = 0, m.perRow - 2 do
			local x = gapX(col)
			scenery("LampPost", Vector3.new(0.6, 14, 0.6),
				CFrame.new(x, GROUND_Y + 7, z), Color3.fromRGB(72, 74, 80), Enum.Material.Metal)
			-- A NEON LAMP HEAD WANTS A DEEP COLOUR, WHICH IS THE FOURTH TIME
			-- THIS PROJECT HAS LEARNED THAT SENTENCE. It was (255, 240, 190)
			-- -- a near-white cream chosen as "warm lamplight" -- and Neon
			-- renders a colour flat out, so what stood on the verge was not a
			-- bulb, it was a white hole with a bloom halo around it.
			-- Photographed down the street, the two nearest lamps were the
			-- brightest objects in frame, brighter than the sky.
			--
			-- The Martian skin, the palace's first lit colonnade and the
			-- townhouse's window rank are the other three, and the fix is the
			-- same every time: a colour a long way from white, so that
			-- rendering it at full brightness still leaves a HUE behind.
			-- Saturation is what survives the bloom, not value.
			local head = scenery("LampHead", Vector3.new(2.2, 0.8, 1.4),
				CFrame.new(x, GROUND_Y + 14, z), Color3.fromRGB(255, 176, 48), Enum.Material.Neon)
			head.CFrame = CFrame.new(head.Position)
		end

		-- PUBLIC WHEELIE BINS, between frontages rather than on them.
		--
		-- Beside the lamp post in the gap between two plots, which is the one
		-- stretch of verge that belongs to nobody: a plot's own verge decor
		-- slots sit at its centre +/- 9.5 and a driveway runs down its middle,
		-- so the midpoint is 27 studs clear of the nearest thing anyone can
		-- buy. That matters -- an owner with Wheelie Bins placed must not end
		-- up with a public one growing out of them.
		--
		-- One per gap -- three a side on a four-plot row, where it was five on
		-- a six-plot one. The COUNT fell with the map and the SPACING did not,
		-- which is the half that matters: cover is still 32 studs from any
		-- driveway, close enough to be a real option on a 37-stud getaway and
		-- far enough that reaching one is a decision.
		--
		-- Yawed to face the road, exactly like a plot: the far side of the
		-- street is turned 180 degrees, which is the correction the old
		-- disguise never made.
		for col = 0, m.perRow - 2 do
			local x = gapX(col) + 5
			local yaw = if side < 0 then 0 else math.pi
			local bin = Decor.buildStreetBin(
				CFrame.new(x, GROUND_Y, z) * CFrame.Angles(0, yaw, 0), workspace)
			if bin then
				bin.Name = "HideBin"

				-- Scenery here is explicitly non-colliding so a chase can run
				-- through it, and a bin is no different -- it must never body
				-- block a thief, a defender or the dog.
				for _, d in ipairs(bin:GetDescendants()) do
					if d:IsA("BasePart") then
						d.CanCollide = false
						d.Anchored = true
					end
				end

				-- One known reference point per bin, rather than whichever
				-- part FindFirstChild happens to return: the prompts hang off
				-- this and the hider is parked at it, so both have to mean the
				-- same place.
				local hatch = Instance.new("Part")
				hatch.Name = "Hatch"
				hatch.Size = Vector3.new(1, 1, 1)
				hatch.CFrame = CFrame.new(x, GROUND_Y + 1.9, z)
				hatch.Transparency = 1
				hatch.Anchored = true
				hatch.CanCollide = false
				hatch.CanQuery = false
				hatch.Parent = bin

				CollectionService:AddTag(bin, "HideBin")
			end
		end

		-- A mailbox on the GRASS beside each driveway.
		--
		-- IT STOOD IN THE DRIVE, AND ONLY MEASURING SAID SO. The offset was a
		-- flat `+ 7` against a `Config.DRIVEWAY_WIDTH` of 17, so the box
		-- spanned x 6.2 to 7.8 on a drive whose edge is at 8.5 -- measured on
		-- the built street, all ten of them standing bodily on their own
		-- owner's tarmac. Nothing errored and nothing looked broken enough to
		-- check, because a mailbox beside a drive and a mailbox in one differ
		-- by a stud and a half.
		--
		-- IT IS DERIVED FROM THE DRIVEWAY NOW rather than typed, which is the
		-- half that stops it coming back: a wider drive carries the mailbox
		-- out with it instead of swallowing it. `MAILBOX_HALF` is the box's
		-- own reach ACROSS the drive at the yaw it is built with -- 1.9 wide
		-- and 2.7 long turned twelve degrees is 2.42 across, so 1.3 covers it
		-- -- and the extra stud is grass anybody can see between the tarmac
		-- and the post.
		--
		-- AND IT IS THE REAL MAILBOX RATHER THAN A RED BOX ON A STICK. What
		-- stood here was two parts in `Material.Metal`, which SHADES a colour
		-- by the environment rather than rendering it -- the trophies already
		-- paid for that one, where the same gold came out olive two studs from
		-- itself. `Decor.buildMailbox` is the same five parts every plot's own
		-- mailbox is built from, in flat `SmoothPlastic`, so the street has
		-- one kind of mailbox on it instead of two.
		for col = 0, m.perRow - 1 do
			local x = columnX(m, col) + Config.DRIVEWAY_WIDTH / 2 + MAILBOX_HALF + 1
			-- Facing the road, and the far row is turned through 180 degrees
			-- exactly as the wheelie bins are -- the correction the old
			-- disguise never made. The extra twelve degrees is the plot's own
			-- mailbox yaw: a box square to the street presents its side to
			-- everybody walking past it.
			local yaw = (if side < 0 then 0 else math.pi) + math.rad(-12)
			Decor.buildMailbox(CFrame.new(x, GROUND_Y, z) * CFrame.Angles(0, yaw, 0), folder)
		end
	end
end

-- Everything beyond the plots is woodland.
--
-- It used to be a row of generic houses standing on the far side of the
-- street, where no plot is. Now that every plot builds its own house at the
-- tier its owner bought, a second set out there read as unclaimed plots and
-- sent players wandering off to look for a piggy that was never going to be
-- built. Trees close the same sightline without promising anything.
--
-- The count is deliberate. This is scenery every client draws behind
-- everything that matters, so the strip is three thinning rows rather than a
-- forest -- roughly a hundred parts, in the same range as the houses it
-- replaced.
local GROVE_ROWS = {
	-- depth: studs beyond the back fence line of a row of plots.
	-- shift:  how far along the street the row slides, in plot spacings, so
	--         no two rows line up into an avenue.
	-- reach:  extra columns past each end of the street.
	-- step:   column stride; the back row is thinned to every other column.

	-- Depths are measured from the BACK FENCE, so the houses -- which all
	-- stand inside it -- are clear by construction. The first row is close
	-- enough to shut the sightline behind a plot without leaning over it.
	-- 14 while the canopy was a ten-stud ball. The meshed tree's canopy is
	-- half as wide again, so the front row moved back by the difference: the
	-- trees are bigger, so the same amount of green stands in front of the
	-- same amount of sky, and the row keeps its full inward jitter rather
	-- than half of it piling up against the clamp below.
	{ depth = 22, shift = -0.5, reach = 0, step = 1 },
	{ depth = 76, shift = 0.1, reach = 1, step = 1 },
	{ depth = 102, shift = -0.4, reach = 2, step = 2 },
}

-- Deterministic scatter, so the grove looks unplanted but every server builds
-- the identical suburb -- a tree that moves between sessions is a landmark
-- that lies.
local function scatter(seed: number, spread: number): number
	local n = math.sin(seed * 12.9898) * 43758.5453
	return (n - math.floor(n) - 0.5) * spread
end

-- Grass along the kerb.
--
-- THE BAND IS DERIVED FROM WHAT IS ALREADY STANDING OUT THERE rather than
-- chosen. It begins outboard of the lamp posts and the wheelie bins, which
-- sit on the 1.8-stud verge line at |z| 9.8, and stops short of the boards at
-- `boardZ` and the four shops set back behind them. So it is exactly the
-- strip of verge that nothing else occupies -- and it is the strip a player
-- walking down the pavement spends the whole walk looking at.
--
-- DRIVEWAYS ARE VETOED, because a driveway crosses this band rather than
-- running beside it: `buildDriveway` lays tarmac from the kerb to the fence
-- line, so every plot column punches a hole straight through the strip.
-- Grass growing out of somebody's driveway is the class of thing nobody files
-- a report about and everybody sees.
local function buildVergeGrass(m: any)
	local nearZ = m.roadHalfWidth + 3
	local farZ = m.boardZ - 3
	if farZ <= nearZ then
		return
	end
	local depth = farZ - nearZ

	-- Half a driveway plus a stud, so a blade never leans over the edging.
	local halfDrive = Config.DRIVEWAY_WIDTH / 2 + 1
	local function offDriveway(pos: Vector3): boolean
		for col = 0, m.perRow - 1 do
			if math.abs(pos.X - columnX(m, col)) < halfDrive then
				return false
			end
		end
		return true
	end

	-- Kept well inboard of the tunnel mouths, which is where the verge stops
	-- being verge and becomes hillside.
	local fromX = m.tunnelWestX + 24
	local toX = m.tunnelEastX - 24

	for i, side in ipairs({ -1, 1 }) do
		GrassTuft.scatterRect(
			CFrame.new((fromX + toX) / 2, GROUND_Y, side * (nearZ + depth / 2)),
			toX - fromX, depth, folder, 4000 + i, offDriveway)
	end
end

-- ============================================================
-- STREET TREES
-- ============================================================
--
-- Trees down the verge as well as behind the plots, so the neighbourhood has
-- them rather than just the backdrop.
--
-- THE SIGHTLINE IS WHAT CONSTRAINS THIS, NOT THE SPACE. A thief decides which
-- piggy is worth crossing the road for from the PAVEMENT -- that is what the
-- rob badge, the coin pile and the vault tell are all for, and this file
-- already measures how much of a pig reads over each fence tier. A tree is
-- taller than any fence, so one planted opposite a gate blanks exactly the
-- thing the decision is made on. Measured before planting: 69% of a pig reads
-- from the kerb, and that number is the one this must not move.
--
-- So they go where the lamp posts and the bins already go: the stretch of
-- verge BETWEEN two driveways, which belongs to no plot. That keeps every
-- trunk a plot-half away from the line a viewer looks down.
--
-- AND THEY ARE SMALLER THAN THE GROVE, WHICH IS A MEASUREMENT RATHER THAN A
-- STYLE CHOICE. `canopyReach` is the DIAGONAL, so a grove tree at its
-- shipped scales reaches 9.2 to 11.6 studs. The free band beside a shop is
-- `(PLOT_SPACING - DRIVEWAY_WIDTH) / 2` less the shop's own half width and
-- forecourt -- about 20.5 studs -- so a grove tree fits it with under two
-- studs to spare on both sides, which is not a fit, it is a coincidence
-- waiting for the next spacing edit. At 0.75 the reach is 5.99 and there are
-- four studs clear either side.
local STREET_TREE = {
	scale = 0.75,
	-- Verge depth. The lamp posts and bins stand on the 1.8 line at |z| 9.8
	-- and the boards are at `boardZ`; this sits between them.
	z = 19,
	-- Out from a gap centre. The free band runs from the shop's edge to the
	-- driveway's, and this is its middle rather than a number that looked
	-- right.
	offset = 21,
}

local function buildStreetTrees(m: any)
	local spec = Config.treeMesh()
	local reach = if spec then canopyReach(spec, STREET_TREE.scale) else 6
	local perRow = Config.PLOTS_PER_ROW

	-- Where a canopy may not reach: a driveway crossing the verge, and the
	-- gap centres, which is where the shops and the boards stand.
	local halfDrive = Config.DRIVEWAY_WIDTH / 2 + 1
	local SHOP_HALF = 11 -- 18 wide plus its two-stud forecourt overhang
	local function clear(x: number): boolean
		for col = 0, perRow - 1 do
			if math.abs(x - Config.plotColumnX(col)) < halfDrive + reach then
				return false
			end
		end
		for col = 0, perRow - 2 do
			if math.abs(x - gapX(col)) < SHOP_HALF + reach then
				return false
			end
		end
		-- THE TREES CAME BACK. A veto stood here for one release: four of
		-- these gaps carried a robbable piggy bank on the verge, 16 studs off
		-- the gap centre, in the only stretch wide enough to hold one -- so
		-- one of each gap's pair of trees gave up its place to a pig.
		--
		-- The pig is inside the shop now, so there is nothing on that band to
		-- clear and both trees stand again. Worth recording as a deletion
		-- rather than quietly dropping it: the veto took a SIDE argument,
		-- which it needed only because a till sat on the same side of its own
		-- SHOP rather than on the same side of the map. `clear` is symmetric
		-- again, and the next thing that stands on a verge will have to bring
		-- that argument back with it.
		return true
	end

	local xs = {}
	-- Two per gap, either side of whatever is standing in it.
	for col = 0, perRow - 2 do
		table.insert(xs, gapX(col) - STREET_TREE.offset)
		table.insert(xs, gapX(col) + STREET_TREE.offset)
	end
	-- And on past the last plot, where the verge runs to the hillside with
	-- nothing on it at all. Stopped short of the tunnel mouth by the canopy's
	-- own reach, or the end trees stand buried in the hill -- the same
	-- mistake the grove's own rows already record.
	local outer = Config.plotColumnX(perRow - 1)
	local limit = m.tunnelEastX - 24 - reach
	local x = outer + 30
	while x <= limit do
		table.insert(xs, x)
		table.insert(xs, -x)
		x += 30
	end

	-- THE SIDE LOOP USED TO BE HERE BECAUSE `clear` NEEDED TO KNOW WHICH ROW
	-- IT WAS ANSWERING FOR, and it no longer does. A till sat on the same
	-- side of its own SHOP rather than on the same side of the map, so the
	-- tree it displaced was a different one on each row; the vault is inside
	-- the building now and both trees stand in every gap. What is left is a
	-- plain loop over the two rows, and `clear` is symmetric again.
	local seed = 5000
	for _, side in ipairs({ -1, 1 }) do
		for _, tx in ipairs(xs) do
			seed += 1
			if clear(tx) then
				buildTree(tx, side * STREET_TREE.z, seed, STREET_TREE.scale)
			end
		end
	end
end

local function buildTrees(m: any)
	-- The back fence line -- YARD_DEPTH behind the plot centre, not half a
	-- plot.
	--
	-- This used to read `m.rowZ + m.halfPlot`, the back edge of the plot
	-- SLAB. That was right when a plot was only its slab, and silently wrong
	-- the moment the fence was lengthened to enclose the house: the first
	-- grove row landed 46 studs inside the yard, which put trees on people's
	-- lawns among their houses. Nothing here may sit inside the fence --
	-- trees are CanCollide false, but a canopy over a plot still hides a
	-- piggy.
	local rear = m.rowZ + Config.YARD_DEPTH
	local seed = 0
	-- Read once rather than per tree: it walks and rebuilds a table, and this
	-- loop runs about a hundred times.
	local treeSpec = Config.treeMesh()

	for _, side in ipairs({ -1, 1 }) do
		for _, row in ipairs(GROVE_ROWS) do
			local col = -row.reach
			while col <= m.perRow + row.reach do
				seed += 1
				-- Jittered FIRST, then tested. The guard used to run on the
				-- column position and the scatter could still push a tree eight
				-- studs into the hillside afterwards -- three of them ended up
				-- buried to the canopy.
				local x = columnX(m, col) + row.shift * Config.PLOT_SPACING + scatter(seed, 16)
				-- Nothing inside a hill. The rows reach two columns past the
				-- last plot, which is now hillside rather than lawn, and a tree
				-- planted there stands buried to its canopy in the mound.
				if x > m.tunnelEastX - 12 or x < m.tunnelWestX + 12 then
					col += row.step
					continue
				end
				-- Jittered, then CLAMPED so no canopy can reach inside a
				-- fence. That is the rule at the top of this function, and it
				-- used to hold because the depths here were chosen against a
				-- ten-stud ball; it holds by construction now.
				--
				-- Same argument as `Config.auditFences`: the failure is a
				-- number, nothing errors, nothing looks wrong from a plan
				-- view, and a canopy standing over somebody's piggy should
				-- not be something the next edit to `scales` can bring back.
				local depth = row.depth + scatter(seed + 97, 8)
				if treeSpec then
					depth = math.max(depth,
						canopyReach(treeSpec, treeScale(treeSpec, seed)) + CANOPY_CLEARANCE)
				end
				buildTree(x, side * (rear + depth), seed)
				col += row.step
			end
		end
	end
end


-- ============================================================
-- THE HILLS
-- ============================================================
--
-- A ridge closing each end of the street, with a tunnel through it.
--
-- It exists for the police car. A patrol used to appear at the end of the road
-- out of clear air and vanish the same way, which reads as a spawn rather than
-- as traffic. Now it drives out of a hillside and away into the far one, so it
-- comes from somewhere and leaves for somewhere.
--
-- THE ONLY BLACK IS INSIDE THE MOUTH, and getting that right meant rebuilding
-- the bore rather than moving the hill. The first version made the tunnel a
-- 2.5-stud skin of near-black concrete and left the domes to bury it, which
-- they did not: measured, the outer walls came out 45% exposed and the roof
-- 98%, so the tunnel read as a black box standing between two hills instead of
-- as a hole in one.
--
-- No arrangement of domes fixes that. A sphere sunk into the ground is at its
-- WIDEST at ground level, so any dome big enough to cover the roof at 16 studs
-- up reaches further forward at the road, and the same sphere that buries the
-- roof fills the bore underneath it. That is a fact about spheres, not a
-- tuning problem.
--
-- So the mass around the bore is EARTH: grass blocks thick enough to be a
-- hillside, with the near-black on thin liners a few inches inside the
-- opening. There is now nothing dark outside the mouth to be buried in the
-- first place, and the domes are shaping a skyline rather than hiding a
-- mistake.
--
-- These are the only parts in this file that COLLIDE. Everything else here is
-- scenery a chase must be able to run through; a hill is the edge of the world
-- and should stop you, and the banks are what stop a player wandering into the
-- void and discovering it is a cupboard.
-- LEFT ALONE WHEN THE LAWN CAME DOWN, AND THAT IS DELIBERATE. The ground and
-- the lawn were darkened about 30% once the texture came off them, which
-- leaves these NUMERICALLY LIGHTER than the ground they sit on -- the reverse
-- of how they started. Looked at rather than reasoned about: a hill is a
-- half-buried SPHERE and a lawn is a flat plane, so the two catch the 14:30
-- sun completely differently, and on screen the hills still read as the
-- deeper, further thing. Matching the numbers would make them read wrong.
-- Compare on a capture before touching these.
local HILL_ROCK = Color3.fromRGB(96, 122, 78)
local HILL_ROCK_2 = Color3.fromRGB(84, 108, 68)
local TUNNEL_STONE = Color3.fromRGB(128, 126, 122)
-- Near black, not merely dark. At (58, 57, 56) the lining still caught the sun
-- and read as two bright wedges either side of the opening, which makes the
-- mouth look like a shallow alcove. Everything in the bore is lit by the same
-- sky as everything outside it, so the only way to sell a tunnel is for the
-- surfaces themselves to be almost black.
local TUNNEL_DARK = Color3.fromRGB(17, 17, 19)

-- The earth around the bore. These are the numbers that stop the tunnel
-- reading as a box: a hillside, not a lining.
local BANK_SIDE = 9 -- earth either side of the bore
local BANK_BACK = 26 -- earth behind the void, so the ridge carries on past it
local BANK_SINK = 1 -- how far the banks are buried, so no face sits ON the grass
local HEAD_RISE = 4 -- masonry above the opening, and earth to the same line
local HEAD_DEPTH = 7 -- how far the headwall reaches back along the bore
local HEAD_PROUD = 1.2 -- and how far it stands out of the hillside
local LINER = 0.8 -- the dark lining, half buried in the earth it lines

-- Like `scenery`, but solid. A hill you can walk through is a hole in the map.
local function solid(name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material): Part
	local p = scenery(name, size, cf, colour, material)
	p.CanCollide = true
	return p
end

-- One dome. Buried to `sink` of its own radius so only the cap shows, which is
-- what makes a sphere read as a hill rather than as a ball on a lawn.
local function mound(x: number, z: number, radius: number, sink: number, seed: number)
	local p = solid("Hill", Vector3.new(radius * 2, radius * 2, radius * 2),
		CFrame.new(x, GROUND_Y - radius * sink, z),
		if seed % 2 == 0 then HILL_ROCK else HILL_ROCK_2, Enum.Material.Grass)
	p.Shape = Enum.PartType.Ball
	-- A hill is ground, so it wears what the ground wears. Without this the
	-- surface stops dead at the foot of the mounds and the ends of the street
	-- read as a different material from the middle of it.
	p.Material = Config.GRASS_MATERIAL.material
	p.MaterialVariant = LAWN_VARIANT
	return p
end

-- The mouth: a bore lined in black, driven through a bank of earth, with a
-- concrete portal standing proud of the face.
--
-- `outward` is the direction the hill lies in, so the same builder does both
-- ends: +1 at the open end, -1 behind the plaza.
local function buildTunnel(m: any, mouthX: number, outward: number)
	local depth = m.tunnelDepth
	local half = m.tunnelHalfWidth
	local height = m.tunnelHeight
	local midX = mouthX + outward * depth / 2
	local wide = half + BANK_SIDE
	local mass = depth + BANK_BACK
	local massX = mouthX + outward * mass / 2

	local function earth(name: string, size: Vector3, cf: CFrame)
		local p = solid(name, size, cf, HILL_ROCK, Enum.Material.Grass)
		-- Same reason as `mound`: this is the hillside the bore is driven
		-- through, not a lining.
		p.Material = Config.GRASS_MATERIAL.material
		p.MaterialVariant = LAWN_VARIANT
		return p
	end

	-- A block on each side of the bore and a plug behind the void, all of it
	-- up to the ceiling. They overlap each other freely: it is all one hill,
	-- and an overlap inside a solid mass is invisible by definition.
	--
	-- Everything that meets the ground starts BANK_SINK below it, so no face
	-- is ever flush with the grass.
	for _, side in ipairs({ -1, 1 }) do
		earth("HillBank", Vector3.new(mass, height + BANK_SINK, BANK_SIDE),
			CFrame.new(massX, GROUND_Y + (height - BANK_SINK) / 2, side * (half + BANK_SIDE / 2)))
	end
	earth("HillBack", Vector3.new(BANK_BACK, height + BANK_SINK, wide * 2),
		CFrame.new(mouthX + outward * (depth + BANK_BACK / 2),
			GROUND_Y + (height - BANK_SINK) / 2, 0))

	-- The earth OVER the bore, and it stops level with the headwall.
	--
	-- No dome can go here, and that is geometry rather than taste. A sphere
	-- sunk into the ground is at its WIDEST at the ground, so one big enough to
	-- cover the ceiling is inside the tunnel underneath it; and one resting ON
	-- the ceiling carries its equator thirty studs up and overhangs the road
	-- like a mushroom.
	--
	-- Stepping it up in courses was tried and is worse: from any camera above
	-- the portal the steps read as a staircase cut into the hillside, which is
	-- a stranger thing to see than a flat top. One course finishing flush with
	-- the masonry reads as the top of a cutting, which is what it is, and the
	-- coping is then the edge the eye follows instead of a green corner.
	--
	-- Half a stud above the lintel rather than level with it, because level
	-- would put the earth's top face and the masonry's at exactly the same
	-- depth over the patch where they overlap, and two surfaces at one depth
	-- give the renderer nothing to sort by. The coping covers the difference.
	earth("HillCap", Vector3.new(mass, HEAD_RISE + 0.5, wide * 2),
		CFrame.new(massX, GROUND_Y + height + (HEAD_RISE + 0.5) / 2, 0))

	-- THE HEADWALL, and it is concrete for a reason.
	--
	-- The earth around a 14-stud bore is a 14-stud wall along the whole length
	-- of it, and no arrangement of domes buries the front of that: a dome close
	-- enough to cover it is standing in the carriageway, because a dome is
	-- widest exactly where the road is. Every version that tried ended up as a
	-- green box beside a green hill, which is the thing being complained about.
	--
	-- A portal wall is not a hole in that argument, it is the answer to it. A
	-- squared-off mass of MASONRY at the mouth is what a road tunnel actually
	-- looks like, so the one shape the domes cannot hide is the one shape that
	-- wants to be seen. It stands taller than the earth behind it, so from the
	-- street the whole silhouette is concrete and hillside with nothing green
	-- and rectangular between them.
	local headTop = height + HEAD_RISE
	local face = mouthX + outward * (HEAD_DEPTH / 2 - HEAD_PROUD)
	for _, side in ipairs({ -1, 1 }) do
		solid("TunnelWing", Vector3.new(HEAD_DEPTH, headTop + BANK_SINK, BANK_SIDE + 2),
			CFrame.new(face, GROUND_Y + (headTop - BANK_SINK) / 2,
				side * (half + (BANK_SIDE + 2) / 2)),
			TUNNEL_STONE, Enum.Material.Concrete)
	end
	solid("TunnelLintel", Vector3.new(HEAD_DEPTH, HEAD_RISE, (wide + 1) * 2),
		CFrame.new(face, GROUND_Y + height + HEAD_RISE / 2, 0),
		TUNNEL_STONE, Enum.Material.Concrete)
	-- A coping over the top edge, standing proud on every side. Without it the
	-- earth meets the wall at a bare seam and the wall reads as a painted
	-- rectangle rather than as something holding a hill back.
	solid("TunnelCoping", Vector3.new(HEAD_DEPTH + 1.6, 1, (wide + 2) * 2),
		CFrame.new(face, GROUND_Y + headTop + 0.5, 0),
		TUNNEL_STONE, Enum.Material.Concrete)

	-- The lining, and the only dark thing here.
	--
	-- Each slab is centred ON the earth face it lines, so half of it is buried
	-- and the visible half stands 0.4 proud. Laying it flush would put two
	-- surfaces at the same depth, which gives the renderer nothing to sort by.
	for _, side in ipairs({ -1, 1 }) do
		solid("TunnelLiner", Vector3.new(depth, height, LINER),
			CFrame.new(midX, GROUND_Y + height / 2, side * half),
			TUNNEL_DARK, Enum.Material.Slate)
	end
	solid("TunnelLiner", Vector3.new(depth, LINER, half * 2),
		CFrame.new(midX, GROUND_Y + height, 0),
		TUNNEL_DARK, Enum.Material.Slate)

	-- The carriageway carries on into the bore.
	--
	-- The road proper stops at the mouth, so without this the tunnel has GRASS
	-- in it and the illusion dies at the threshold. Darker than the road
	-- outside because it is under a roof, which also stops the two slabs
	-- reading as one continuous surface at the seam.
	pave("TunnelFloor", depth, half * 2, midX, 0, LIFT_ROAD,
		Color3.fromRGB(21, 21, 24), Enum.Material.Asphalt)

	-- The void at the back.
	--
	-- Neon on a black colour, which is the one material that ignores the light
	-- falling on it -- a dark SmoothPlastic slab still picks up the sun and
	-- reads as a grey wall at the end of a corridor. This reads as no wall.
	-- Held a hair clear of the earth plug behind it so their faces do not meet.
	local void = solid("TunnelVoid", Vector3.new(1, height, half * 2),
		CFrame.new(mouthX + outward * (depth - 0.6), GROUND_Y + height / 2, 0),
		Color3.new(0, 0, 0), Enum.Material.Neon)
	void.CastShadow = false
end

-- The ridge, parting either side of the mouth.
--
-- Every dome is placed against two things it must not reach: the BORE, which
-- it would fill with grass, and the open ground in front of the mouth, which
-- is the carriageway at one end and the arrival plaza at the other. A sunken
-- sphere is widest at ground level, so a dome that clears the mouth at head
-- height can still be standing in the road -- which is also why the earth over
-- the bore is a block and not a dome.
local function buildHill(m: any, mouthX: number, outward: number, clear: number)
	buildTunnel(m, mouthX, outward)

	local half = m.tunnelHalfWidth
	local backX = mouthX + outward * 54

	-- The shoulders stand hard against the portal, which is what makes the
	-- hill and the tunnel one object rather than two. How far out they sit is
	-- DERIVED from what has to stay open in front of the mouth: a lane's worth
	-- of carriageway at the open end, the whole plaza at the closed one.
	local shoulderZ = math.max(clear + 26, half + 28)

	for _, side in ipairs({ -1, 1 }) do
		mound(mouthX + outward * 14, side * shoulderZ, 26, 0.30, 1)
		mound(mouthX + outward * 44, side * 54, 46, 0.34, 2)
		mound(backX + outward * 14, side * 116, 66, 0.40, 3)
		mound(backX - outward * 2, side * 178, 58, 0.45, 4)
	end
	-- The mass behind the bore, as far forward as the bore allows: any closer
	-- and its own belly is inside the tunnel.
	mound(backX + outward * 46, 0, 72, 0.38, 5)
end

local function buildHills(m: any)
	buildHill(m, m.tunnelEastX, 1, m.roadHalfWidth + 4)
	-- Both ends are open carriageway now that the square has moved to the
	-- middle, so the west hill gets the same clearance as the east one rather
	-- than the whole width of a bulb it is no longer standing behind.
	buildHill(m, m.tunnelWestX, -1, m.roadHalfWidth + 8)
end

-- THE VERGE IS GRASS, AND THERE IS NO PAVING ON IT.
--
-- The town square was a paved rectangle in a hole in the row; closing the row
-- took the hole, and the paving followed it out here as two asphalt aprons
-- under the boards. That was one move too many. A verge is grass -- the lamp
-- posts, the wheelie bins, the mailboxes and now the shops all stand on it
-- without a slab under them, and two rectangles of tarmac in the middle of it
-- read as the last piece of something that had been removed.
--
-- So the only paved things on this street are the ones that are actually
-- road: the carriageway, its kerbs and its centre line, and the driveways
-- each plot lays for itself. Everything else stands on grass.
--
-- The shops keep their own forecourts, which is a different thing: a building
-- meeting a lawn at a made edge is what a forecourt is for, and it belongs to
-- the unit rather than to the street.

-- FOUR SHOPS, ONE PER TAB, ON THE VERGE.
--
-- They stood on the shoulders of the town square, in the hole in the row.
-- With the row closed up they line the STREET instead, in the gaps between
-- driveways -- the same stretch of verge the lamp posts and wheelie bins
-- already use, and the one piece of ground here that belongs to no plot.
--
-- WHERE THEY FIT IS SOLVED, NOT CHOSEN, and the widening is what makes it
-- solvable at all:
--
--   * ACROSS: a driveway is DRIVEWAY_WIDTH on each plot centre, so between
--     two of them the clear gap is `PLOT_SPACING - DRIVEWAY_WIDTH` -- 67 studs
--     at the current spacing, against 51 before the plot was widened. A unit
--     20 across at the midpoint has 23.5 either side. Derived rather than
--     written down, because both of those constants have moved once already.
--   * BACK: the verge runs from the kerb at 8 to the fence line at 46.4. At
--     `shopZ` (fence less 12) the building spans 27..41 -- 5.4 studs off the
--     fence behind, and 12 of pavement in front of its forecourt, which is
--     where the lamp post and the bin stand at 9.8.
--
-- At 104 none of that fitted: the band was 18.4 studs and a unit would have
-- been standing in the carriageway to have its back against the fence.
-- WHAT EACH UNIT IS, not just what it is called.
--
-- `style` picks the roof line, the frontage and the lighting; `display` is
-- the REAL item that stands in its window, built by the same function that
-- puts one on a lawn or under a rider. That is the rule the shop cards
-- already follow -- render the actual thing, because a coloured square cannot
-- tell you what a skin looks like -- applied to a building.
--
-- The garden centre has no `display` on purpose: its style has an open front
-- rather than a window, because its stock IS the frontage.
-- WHAT EACH UNIT LOOKS LIKE, KEYED BY THE TAB ITS DOOR OPENS -- and WHERE
-- it stands is `Config.SHOPS`, which is a change rather than a tidy-up.
--
-- This table used to carry a `gap`, a `side` and a `name` of its own while
-- `Config` carried the same three for the till on each forecourt. Two copies
-- of one arrangement, and for as long as the pig stood outside they could
-- disagree by a stud without anybody noticing. They cannot now: the vault is
-- a PLOT built inside this shell, so a table one gap out of step would put a
-- robbable strongroom in an empty patch of verge and leave the unit next
-- door with nothing in it.
--
-- Style, colour and window display are appearance and stay here. Placement
-- is arithmetic the economy is priced against and lives in Config.
local SHOPS = {
	piggy = {
		style = "boutique", accent = Color3.fromRGB(226, 118, 156),
		-- The mini piggy, the same 11-part model the carried loot uses.
		display = function()
			return PiggyModel.build(Config.DEFAULT_SKIN)
		end,
	},
	home = {
		style = "garden", accent = Color3.fromRGB(104, 172, 116),
	},
	gear = {
		style = "wheels", accent = Color3.fromRGB(232, 162, 72),
		-- A real BMX off RideModel. 23 parts, and it is the machine a player
		-- can actually buy on the tab this door opens.
		display = function()
			return RideModel.build("bmx")
		end,
	},
	defend = {
		style = "security", accent = Color3.fromRGB(96, 146, 216),
		-- A Golden Bone under glass: the most expensive consumable in the
		-- game, and the one thing on this tab that reads at a glance.
		display = function()
			return BoneModel.build("golden", false)
		end,
	},
}

local function buildShops(_m: any)
	for _, placement in ipairs(Config.SHOPS) do
		-- `any`, because the four rows are not one shape -- the garden centre
		-- has an open front and therefore no `display` -- and a fallback row
		-- assigned into an inferred type is a strict-mode fight over a table
		-- that is Config data either way.
		local shop: any = SHOPS[placement.tab]
		if not shop then
			-- A shop with no look is a misconfiguration and losing the unit
			-- is worse than losing its style: it is a robbable plot, and
			-- `PlotService` will have built one inside a building that is not
			-- there. Loud, and it does not skip.
			warn("[NeighborhoodService] no style for shop tab " .. tostring(placement.tab))
			shop = { style = "boutique", accent = Color3.fromRGB(200, 200, 200) }
		end
		-- THE UNIT'S FRAME COMES FROM `Config`, WHICH IS THE SAME CALL
		-- `PlotService` MAKES. Two builders, one placement: the walls and the
		-- vault inside them cannot end up in different gaps, and neither can
		-- drift when the street is next widened.
		--
		-- It sits at the PAVEMENT, half a slab below the plot frame that
		-- shares it -- `ShopFront` measures its own bands from the ground it
		-- stands on.
		local placeAt = Config.shopUnitCFrame(placement)
		local _, door = ShopFront.build(
			placeAt * CFrame.new(0, GROUND_Y, 0),
			GROUND_Y,
			{
				name = placement.name, tab = placement.tab, accent = shop.accent,
				style = shop.style, display = shop.display,
			},
			folder)

		-- Wired HERE, on the server, at the moment the door exists. The
		-- client cannot do this for itself: these are built during startup
		-- and a tag set before parenting never fires
		-- GetInstanceAddedSignal on a peer it replicates to. See ShopFront.
		local prompt = door:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				Remotes.get("ShopDoor"):FireClient(player, placement.tab)
			end)
		end
	end
end

function NeighborhoodService.start()
	local existing = workspace:FindFirstChild("Neighborhood")
	if existing then
		existing:Destroy()
	end

	folder = Instance.new("Folder")
	folder.Name = "Neighborhood"
	folder.Parent = workspace

	local m = metrics()
	buildRoad(m)
	buildTrees(m)
	buildStreetTrees(m)
	buildStreetFurniture(m)
	-- After the furniture, so the band above can be read against what is
	-- actually standing on the verge rather than against what was meant to be.
	buildVergeGrass(m)
	buildHills(m)
	buildShops(m)

	print(("[NeighborhoodService] Built %d scenery parts"):format(#folder:GetChildren()))
end

return NeighborhoodService
