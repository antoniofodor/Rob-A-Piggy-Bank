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
		-- They sit just off the kerb, in front of whatever else is in the gap:
		-- the verge is 38 studs deep now, so a lamp at 9.8 and a shop at 34
		-- are not competing for the same ground.
		for col = 0, m.perRow - 2 do
			local x = gapX(col)
			scenery("LampPost", Vector3.new(0.6, 14, 0.6),
				CFrame.new(x, GROUND_Y + 7, z), Color3.fromRGB(72, 74, 80), Enum.Material.Metal)
			local head = scenery("LampHead", Vector3.new(2.2, 0.8, 1.4),
				CFrame.new(x, GROUND_Y + 14, z), Color3.fromRGB(255, 240, 190), Enum.Material.Neon)
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

	-- Depths are measured from the BACK FENCE, so the houses -- which all
	-- stand inside it -- are clear by construction. The first row is close
	-- enough to shut the sightline behind a plot without leaning over it.
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
				buildTree(x,
					side * (rear + row.depth + scatter(seed + 97, 8)), seed)
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
		return solid(name, size, cf, HILL_ROCK, Enum.Material.Grass)
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
local SHOPS = {
	{
		gap = 0, side = 1, tab = "piggy", style = "boutique",
		name = "PIGGY OUTFITTERS", accent = Color3.fromRGB(226, 118, 156),
		-- The mini piggy, the same 11-part model the carried loot uses.
		display = function()
			return PiggyModel.build(Config.DEFAULT_SKIN)
		end,
	},
	{
		gap = 2, side = 1, tab = "home", style = "garden",
		name = "HOME & GARDEN", accent = Color3.fromRGB(104, 172, 116),
	},
	{
		gap = 0, side = -1, tab = "gear", style = "wheels",
		name = "WHEELS & KIT", accent = Color3.fromRGB(232, 162, 72),
		-- A real BMX off RideModel. 23 parts, and it is the machine a player
		-- can actually buy on the tab this door opens.
		display = function()
			return RideModel.build("bmx")
		end,
	},
	{
		gap = 2, side = -1, tab = "defend", style = "security",
		name = "LOCK & KEY", accent = Color3.fromRGB(96, 146, 216),
		-- A Golden Bone under glass: the most expensive consumable in the
		-- game, and the one thing on this tab that reads at a glance.
		display = function()
			return BoneModel.build("golden", false)
		end,
	},
}

local function buildShops(m: any)
	for _, shop in ipairs(SHOPS) do
		-- Authored facing +Z, so the far verge turns a half circle to look
		-- back at the road and the near one takes none. Same convention the
		-- plots, the ornaments and the bins all follow.
		local yaw = if shop.side > 0 then math.pi else 0
		local _, door = ShopFront.build(
			CFrame.new(gapX(shop.gap), GROUND_Y, shop.side * m.shopZ) * CFrame.Angles(0, yaw, 0),
			GROUND_Y,
			{
				name = shop.name, tab = shop.tab, accent = shop.accent,
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
				Remotes.get("ShopDoor"):FireClient(player, shop.tab)
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
	buildStreetFurniture(m)
	buildHills(m)
	buildShops(m)

	print(("[NeighborhoodService] Built %d scenery parts"):format(#folder:GetChildren()))
end

return NeighborhoodService
