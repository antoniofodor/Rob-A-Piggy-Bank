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

local Config = require(ReplicatedStorage.Shared.Config)

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
	local perRow = Config.PLOTS_PER_ROW
	local halfPlot = Config.PLOT_SIZE.X / 2
	local streetHalf = Config.STREET_SPACING / 2
	local endX = ((perRow - 1) / 2) * Config.PLOT_SPACING

	-- Road and fence geometry comes from Config, not from a second copy of the
	-- same arithmetic here. This file used to derive the carriageway from the
	-- moat itself, which meant widening the street only ever widened the
	-- tarmac and the driveway never grew.
	local street = Config.streetMetrics()

	local plazaSize = 56
	local plazaX = -(endX + halfPlot + 26)

	return {
		perRow = perRow,
		halfPlot = halfPlot,
		-- Centre of the outermost plot on each end of the street.
		endX = endX,
		rowZ = streetHalf,

		-- Fixed carriageway; everything between it and the fence is verge and
		-- driveway, which is where the extra street width goes.
		roadHalfWidth = street.roadHalfWidth,
		vergeOuter = street.fenceLine,

		plazaX = plazaX,
		plazaSize = plazaSize,

		-- The road runs from the lip of the cul-de-sac bulb to past the last
		-- plot. It must not reach INTO the plaza: two slabs at the same lift
		-- z-fight with each other exactly as a slab does against grass.
		roadStartX = plazaX + plazaSize / 2,
		roadEndX = endX + halfPlot + 60,

		-- Clear of the yard fence, which now runs YARD_DEPTH back from each
		-- plot centre to enclose the house.
		backdropZ = streetHalf + Config.YARD_DEPTH + 46,
	}
end

local function columnX(m: any, col: number): number
	return (col - (m.perRow - 1) / 2) * Config.PLOT_SPACING
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

local function buildTree(x: number, z: number, seed: number)
	local height = 9 + (seed % 3) * 2
	scenery("Trunk", Vector3.new(1.6, height, 1.6),
		CFrame.new(x, GROUND_Y + height / 2, z), TRUNK, Enum.Material.Wood)

	local canopy = 8 + (seed % 3)
	local top = scenery("Canopy", Vector3.new(canopy, canopy, canopy),
		CFrame.new(x, GROUND_Y + height + canopy / 3, z),
		if seed % 2 == 0 then LEAF else LEAF_2, Enum.Material.Grass)
	top.Shape = Enum.PartType.Ball
end

local function buildStreetFurniture(m: any)
	for _, side in ipairs({ -1, 1 }) do
		-- On the verge, just off the kerb. This used to be measured from the
		-- old full-corridor road edge, which put every lamp post and mailbox
		-- 4 studs INSIDE the player's fence.
		local z = side * (m.roadHalfWidth + 1.8)

		-- Lamp posts land in the gaps BETWEEN frontages, never in a driveway.
		for col = 0, m.perRow - 2 do
			local x = (columnX(m, col) + columnX(m, col + 1)) / 2
			scenery("LampPost", Vector3.new(0.6, 14, 0.6),
				CFrame.new(x, GROUND_Y + 7, z), Color3.fromRGB(72, 74, 80), Enum.Material.Metal)
			local head = scenery("LampHead", Vector3.new(2.2, 0.8, 1.4),
				CFrame.new(x, GROUND_Y + 14, z), Color3.fromRGB(255, 240, 190), Enum.Material.Neon)
			head.CFrame = CFrame.new(head.Position)
		end

		-- A mailbox beside each driveway.
		for col = 0, m.perRow - 1 do
			local x = columnX(m, col) + 7
			scenery("MailboxPost", Vector3.new(0.4, 4, 0.4),
				CFrame.new(x, GROUND_Y + 2, z), TRUNK, Enum.Material.Wood)
			scenery("Mailbox", Vector3.new(1.6, 1.4, 2.6),
				CFrame.new(x, GROUND_Y + 4.6, z), Color3.fromRGB(168, 78, 68), Enum.Material.Metal)
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

	-- The plot houses stand 70 studs behind their plot centres, and the
	-- biggest tier is 28 deep, so the band 30 to 60 studs past the fence
	-- belongs to them. No row may sit in it: a canopy over a Piggy
	-- Mansion is the one thing here somebody paid five million for.
	{ depth = 14, shift = -0.5, reach = 0, step = 1 },
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

local function buildTrees(m: any)
	-- The back fence line. Nothing here is ever placed inside it: trees are
	-- CanCollide false, but a canopy over a plot still hides a piggy.
	local rear = m.rowZ + m.halfPlot
	local seed = 0

	for _, side in ipairs({ -1, 1 }) do
		for _, row in ipairs(GROVE_ROWS) do
			local col = -row.reach
			while col <= m.perRow + row.reach do
				seed += 1
				local x = columnX(m, col) + row.shift * Config.PLOT_SPACING
				buildTree(x + scatter(seed, 16),
					side * (rear + row.depth + scatter(seed + 97, 8)), seed)
				col += row.step
			end
		end
	end

	-- A screen past the open end of the road, so the street reads as leading
	-- somewhere rather than stopping at the edge of the world. The plaza end
	-- gets none: the leaderboard stands there and must not be occluded.
	for _, side in ipairs({ -1, 1 }) do
		for i = 0, 2 do
			seed += 1
			buildTree(m.roadEndX + 22 + scatter(seed, 14),
				side * (18 + i * 34 + scatter(seed + 41, 8)), seed)
		end
	end
end

-- The closed end of the cul-de-sac: where the leaderboard stands and where
-- players arrive. Kept deliberately open so the board is never occluded.
local function buildPlaza(m: any)
	local x = m.plazaX

	pave("Plaza", m.plazaSize, m.plazaSize, x, 0, LIFT_ROAD, KERB, Enum.Material.Concrete)

	for _, side in ipairs({ -1, 1 }) do
		buildTree(x - 18, side * 20, 2)
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
	buildStreetFurniture(m)
	buildPlaza(m)

	print(("[NeighborhoodService] Built %d scenery parts"):format(#folder:GetChildren()))
end

return NeighborhoodService
