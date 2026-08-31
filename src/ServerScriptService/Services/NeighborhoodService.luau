--!strict
--[[
	NeighborhoodService

	The suburb the plots sit in: road, sidewalks, driveways, backdrop houses,
	street furniture and trees.

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

-- Deliberately desaturated. The piggies are the saturated thing on this map
-- and the houses must never compete with them for attention.
local HOUSE_WALLS = {
	Color3.fromRGB(226, 214, 196),
	Color3.fromRGB(206, 216, 214),
	Color3.fromRGB(222, 206, 200),
	Color3.fromRGB(202, 208, 190),
	Color3.fromRGB(228, 220, 206),
}
local HOUSE_ROOFS = {
	Color3.fromRGB(126, 92, 82),
	Color3.fromRGB(104, 96, 106),
	Color3.fromRGB(118, 106, 88),
	Color3.fromRGB(96, 104, 100),
}

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

	-- The gap between the two rows of lawns.
	local corridor = streetHalf - halfPlot

	-- The carriageway is NOT that whole gap. Two things stick out into it:
	-- fences stand 1.6 studs proud of the plot edge, and a top-tier moat
	-- reaches further in still. Paving the full corridor put tarmac under
	-- every fence and left the road and the moat fighting for depth.
	local topTier = Config.FENCE_TIERS[#Config.FENCE_TIERS]
	local moatWidth = if topTier.moat then topTier.moat.width else 0
	local fenceLine = corridor - 1.6
	local moatInner = fenceLine - 0.5 - moatWidth

	local plazaSize = 56
	local plazaX = -(endX + halfPlot + 26)

	return {
		perRow = perRow,
		halfPlot = halfPlot,
		-- Centre of the outermost plot on each end of the street.
		endX = endX,
		rowZ = streetHalf,

		-- Stops short of the moats, leaving a verge between kerb and fence
		-- for driveways, lamp posts and mailboxes to live on.
		roadHalfWidth = moatInner - 0.9,
		vergeOuter = fenceLine,

		plazaX = plazaX,
		plazaSize = plazaSize,

		-- The road runs from the lip of the cul-de-sac bulb to past the last
		-- plot. It must not reach INTO the plaza: two slabs at the same lift
		-- z-fight with each other exactly as a slab does against grass.
		roadStartX = plazaX + plazaSize / 2,
		roadEndX = endX + halfPlot + 60,

		-- Backdrop sits well clear of the moats.
		backdropZ = streetHalf + halfPlot + 46,
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

local function buildDriveways(m: any)
	for _, side in ipairs({ -1, 1 }) do
		for col = 0, m.perRow - 1 do
			local x = columnX(m, col)
			local from = m.vergeOuter  -- fence line
			local to = m.roadHalfWidth -- kerb
			local length = from - to
			if length > 0 then
				-- Sits above the kerb so it crosses it cleanly, the way a
				-- real dropped kerb does.
				pave("Driveway", 9, length, x, side * (to + length / 2), LIFT_DRIVE,
					KERB, Enum.Material.Concrete)
			end
		end
	end
end

local function buildHouse(cf: CFrame, seed: number)
	local walls = HOUSE_WALLS[(seed % #HOUSE_WALLS) + 1]
	local roof = HOUSE_ROOFS[(seed % #HOUSE_ROOFS) + 1]
	local width = 26 + (seed % 3) * 4
	local depth = 20
	local height = 15 + (seed % 2) * 3

	scenery("House", Vector3.new(width, height, depth),
		cf * CFrame.new(0, height / 2, 0), walls, Enum.Material.Brick)

	-- Roof as two wedges meeting at a ridge over the middle of the house.
	--
	-- A WedgePart is already full height at its -Z edge and slopes to nothing
	-- at +Z, so the near half needs no rotation at all and the far half is
	-- just the same wedge turned around. Rotating on any other axis tips the
	-- slope on its side, which is what gave the street a skyline of slabs.
	for _, dir in ipairs({ -1, 1 }) do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Roof"
		wedge.Size = Vector3.new(width + 2, 7, depth / 2)
		wedge.CFrame = cf
			* CFrame.new(0, height + 3.5, dir * depth / 4)
			* CFrame.Angles(0, if dir > 0 then 0 else math.pi, 0)
		wedge.Anchored = true
		wedge.CanCollide = false
		wedge.CanQuery = false
		wedge.CastShadow = false
		wedge.Color = roof
		wedge.Material = Enum.Material.Slate
		wedge.Parent = folder
	end

	scenery("Door", Vector3.new(4, 7, 0.6), cf * CFrame.new(0, 3.5, depth / 2),
		Color3.fromRGB(112, 78, 60), Enum.Material.WoodPlanks)

	for _, dx in ipairs({ -width / 4, width / 4 }) do
		scenery("Window", Vector3.new(5, 4.5, 0.5), cf * CFrame.new(dx, height * 0.62, depth / 2),
			Color3.fromRGB(158, 196, 214), Enum.Material.Glass)
	end

	scenery("Chimney", Vector3.new(3, 8, 3), cf * CFrame.new(width / 3, height + 5, -depth / 5),
		roof, Enum.Material.Brick)
end

local function buildBackdrop(m: any)
	for _, side in ipairs({ -1, 1 }) do
		-- One house per plot frontage, plus one past each end so the row does
		-- not stop dead level with the last plot.
		for col = -1, m.perRow do
			local x = columnX(m, col)
			-- Houses face the street from behind their row.
			local yaw = if side < 0 then 0 else math.pi
			buildHouse(
				CFrame.new(x, GROUND_Y, side * m.backdropZ) * CFrame.Angles(0, yaw, 0),
				col + (if side < 0 then 0 else 3))
		end
	end
end

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

	-- Trees fill the strip between the backdrop houses and the plots, which is
	-- otherwise the emptiest part of the map.
	local treeZ = (m.rowZ + m.halfPlot + m.backdropZ) / 2
	for _, side in ipairs({ -1, 1 }) do
		for col = 0, m.perRow do
			local x = columnX(m, col) - Config.PLOT_SPACING / 2
			buildTree(x, side * treeZ, col + (if side < 0 then 1 else 4))
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
	buildDriveways(m)
	buildBackdrop(m)
	buildStreetFurniture(m)
	buildPlaza(m)

	print(("[NeighborhoodService] Built %d scenery parts"):format(#folder:GetChildren()))
end

return NeighborhoodService
