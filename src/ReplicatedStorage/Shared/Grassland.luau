--!strict
--[[
	Grassland

	What stands in the grass the herds wander: the band behind the back
	fences on both sides of the street, between the grove's three rows of
	trees. Three ponds a side, flower drifts, low bushes, rocks and fallen logs.
	Pure scenery: every part is CanCollide, CanQuery and CastShadow false,
	anchored, SmoothPlastic and flat colour -- the same rule the whole of
	NeighborhoodService and every lawn ornament already follow, and it
	matters here because this is ground a pack walks and a thief may cross.

	IT IS IN `Shared` FOR THE REASON HOUSE AND DECOR ARE: pure geometry over
	Config with no server-only API in it, so a shop card or a preview can
	build the real thing rather than a copy that drifts.

	NOTHING HERE CAN BE DUG, SO A POND IS AN ILLUSION BUILT THE MOAT'S WAY.
	The ground is one solid Part; setting a water surface below it makes the
	water vanish under the grass, not a hole. So every layer sits PROUD of
	the ground and the depth comes from the rim: a ring of boulders standing
	over a stud above the grass, a bed a hair above it, and a translucent
	surface between the two, well below the rim's top line -- the eye takes
	the highest line as the ground. The bed is opaque and dark, or the water
	tints the grass under it and comes out pond-green.

	A POND IS PLACED BY SCANNING THE BAND AGAINST THE TRUNKS THAT ACTUALLY
	STAND THERE, never by a typed coordinate. NeighborhoodService hands
	`build` where its grove trees went and how far each canopy reaches, and
	`layout` picks the spot whose rim is furthest outside every canopy's
	reach circle -- capped, then biased toward the fence for the first pond
	and away from it for the second, or all four run to the emptiest corner
	of the band (measured: against the valley wall). Handed no trunks it
	still lays out, which is what the suite drives.

	`blocks(position)` is the herd's veto: true inside a pond's stones plus
	a piggy's own radius. Flowers, rocks and the log do not block -- a piggy
	walking through flowers is fine, a piggy standing in a pond is not.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Grassland = {}

export type Obstacle = { x: number, z: number, reach: number }
export type Pond = {
	side: number,
	x: number,
	z: number,
	radius: number,
	-- How far out the rim's boulders can reach from the centre, at most.
	rim: number,
	-- Clearance of the rim from the nearest canopy circle, for the log.
	clear: number,
}

-- ------------------------------------------------------------
-- COLOURS
-- ------------------------------------------------------------
-- Authored for the 2.4 sun and the blue ambient: a flat SmoothPlastic
-- surface renders about a third brighter than its RGB (the lawn's own
-- lesson when its texture came off), so everything here is a step darker
-- and a step more saturated than it would be on paper.
local WATER = Color3.fromRGB(26, 104, 142) -- deep blue-teal, not sky
local BED = Color3.fromRGB(22, 44, 56) -- near-black, opaque, under the water
local STONE = Color3.fromRGB(142, 128, 108) -- warm bank stone
local STONE_2 = Color3.fromRGB(122, 110, 94)
local REED = Color3.fromRGB(58, 112, 50)
local PAD = Color3.fromRGB(70, 140, 64)
local STEM = Color3.fromRGB(60, 126, 54)
local MOUND = Color3.fromRGB(54, 116, 48) -- the leaf mass a drift sits on
local BUSH = Color3.fromRGB(50, 108, 44)
local BUSH_2 = Color3.fromRGB(64, 128, 54)
local ROCK = Color3.fromRGB(124, 114, 102)
local ROCK_2 = Color3.fromRGB(104, 96, 86)
local LOG = Color3.fromRGB(118, 82, 54)
local LOG_END = Color3.fromRGB(172, 136, 92)
-- Saturated, not pastel: a pastel head over a lawn this dark reads as a
-- pale dot, and the drift is meant to read from thirty studs.
local BLOOMS = {
	Color3.fromRGB(228, 56, 112), -- pink
	Color3.fromRGB(246, 190, 36), -- yellow
	Color3.fromRGB(236, 108, 40), -- orange
	Color3.fromRGB(118, 66, 214), -- violet
}

-- ------------------------------------------------------------
-- LAYERS, in studs above the ground's top face
-- ------------------------------------------------------------
-- The bed a hair proud (the road's own lift), the water's TOP a third of a
-- stud up, and the boulders topping out over a stud above that. Nothing
-- flush with anything: two faces at one depth flicker (CLAUDE.md, three
-- times over).
local BED_LIFT = 0.06
local BED_THICK = 0.3
local WATER_TOP = 0.36
local WATER_DEEP = 0.5
local WATER_OUT = 0.5 -- the water reaches this far past the nominal radius
local BED_OUT = 1.0 -- and the bed a little further, so the rim always meets bed
-- A boulder's centre sits this fraction of its radius BELOW the ground, so
-- about two thirds of it shows and its chord at ground level is wide.
local STONE_SINK = 0.35
local PAD_LIFT = 0.06 -- a lily pad floats this far off the water
local PAD_THICK = 0.12

-- ------------------------------------------------------------
-- THE HASH, which is the same one GrassTuft and the grove use
-- ------------------------------------------------------------
-- Every draw is consumed whether or not the thing it describes is placed,
-- so adding an obstacle removes the flowers under it and moves no other
-- blade -- `GrassTuft.scatterRect`'s rule, and the whole reason the layout
-- is stable across a tree moving.
local function rnd(state: { n: number }): number
	state.n += 1
	local v = math.sin(state.n * 12.9898) * 43758.5453
	return v - math.floor(v)
end

local function between(state: { n: number }, lo: number, hi: number): number
	return lo + rnd(state) * (hi - lo)
end

local function dist(ax: number, az: number, bx: number, bz: number): number
	local dx, dz = ax - bx, az - bz
	return math.sqrt(dx * dx + dz * dz)
end

-- ------------------------------------------------------------
-- THE LAYOUT
-- ------------------------------------------------------------
-- The nearest a rim may come to any canopy circle, and how far the scan
-- may reach in each axis. Shared by the pond scan and the flower veto.
local function bounds(g: any)
	local G = Config.GRASSLAND
	return {
		xMax = g.corridorInner - G.entryKeep,
		zLo = g.bandNear + G.nearKeep,
		zHi = math.min(g.bandFar, Config.GROUND_SIZE.Y / 2 - G.farInset),
	}
end

-- The most a rim's boulder can stand out from the pond's centre.
local function rimReach(radius: number): number
	local G = Config.GRASSLAND
	return radius + WATER_OUT + G.stoneRingOut + G.stoneRadius[2]
end

-- How far a point is outside every canopy circle (negative inside one).
local function canopyClearance(x: number, z: number, obstacles: { Obstacle }): number
	local clear = math.huge
	for _, t in ipairs(obstacles) do
		clear = math.min(clear, dist(x, z, t.x, t.z) - t.reach)
	end
	return clear
end

--[[
	Where the ponds go, as plain numbers and with no Instance in it, so the
	suite can drive it under the harness's inert Config. `g` is the table
	`Config.herdGround()` returns; `obstacles` is the grove's trunks with
	each canopy's reach, and may be empty.
]]
function Grassland.layout(g: any, obstacles: { Obstacle }?): { Pond }
	local G = Config.GRASSLAND
	local trees: { Obstacle } = obstacles or {}
	local b = bounds(g)
	local ponds: { Pond } = {}

	for _, side in ipairs({ -1, 1 }) do
		local taken: { Pond } = {}
		for i, radius in ipairs(G.pondRadii) do
			-- The rim, not the water, is what has to clear a canopy.
			local rim = rimReach(radius)
			-- The first pond prefers the fence, the second prefers depth, and
			-- any after that take the clearest spot left.
			local prefer = if i == 1 then -G.preferDepth elseif i == 2 then G.preferDepth else 0
			local xLim = b.xMax - rim
			local zLo, zHi = b.zLo + rim, b.zHi - rim
			local best: Pond? = nil
			local bestScore = -math.huge
			local x = -xLim
			while x <= xLim + 1e-6 do
				local z = zLo
				while z <= zHi + 1e-6 do
					local wz = side * z
					local apart = true
					for _, other in ipairs(taken) do
						if dist(x, wz, other.x, other.z) < G.pondSpacing then
							apart = false
							break
						end
					end
					if apart then
						local clear = canopyClearance(x, wz, trees) - rim
						local score = math.min(clear, G.canopyMargin + G.clearCap)
							+ prefer * (z - g.bandNear)
						if score > bestScore + 1e-9 then
							bestScore = score
							best = { side = side, x = x, z = wz, radius = radius,
								rim = rim, clear = clear }
						end
					end
					z += G.scanStep.z
				end
				x += G.scanStep.x
			end
			if best then
				if best.clear < G.canopyMargin then
					warn(("[Grassland] pond %d on side %d sits %.1f studs inside a canopy's "
						.. "reach: the band is too full of trees for it")
						:format(i, side, G.canopyMargin - best.clear))
				end
				table.insert(taken, best)
				table.insert(ponds, best)
			end
		end
	end
	return ponds
end

-- ------------------------------------------------------------
-- STATE AND THE VETO
-- ------------------------------------------------------------
local placed: { Pond } = {}

-- The ponds the last build stood, for anything that wants to draw them.
function Grassland.ponds(): { Pond }
	return placed
end

-- True inside a pond's rim plus a piggy's own radius. Reads XZ only: the
-- herd asks with a point at its own body height, and the water is flat.
function Grassland.blocks(position: Vector3): boolean
	local margin = Config.GRASSLAND.pondMargin
	for _, pond in ipairs(placed) do
		if dist(position.X, position.Z, pond.x, pond.z) <= pond.rim + margin then
			return true
		end
	end
	return false
end

-- ------------------------------------------------------------
-- PARTS
-- ------------------------------------------------------------
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A flat disc: a Roblox cylinder's axis is its X, so the thickness goes on
-- X and a quarter turn about Z stands the axis up. (CLAUDE.md: five bugs
-- from writing this the other way round.)
local function disc(parent: Instance, name: string, radius: number, thick: number,
	x: number, y: number, z: number, colour: Color3): Part
	local p = part(parent, name, Vector3.new(thick, radius * 2, radius * 2),
		CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2), colour)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(parent: Instance, name: string, radius: number,
	x: number, y: number, z: number, colour: Color3): Part
	local p = part(parent, name, Vector3.new(radius * 2, radius * 2, radius * 2),
		CFrame.new(x, y, z), colour)
	p.Shape = Enum.PartType.Ball
	return p
end

local function buildPond(parent: Instance, pond: Pond, groundY: number, state: { n: number })
	local G = Config.GRASSLAND
	local x, z, r = pond.x, pond.z, pond.radius

	-- Bed, then water. The bed is wider than the water and both are under
	-- the rim, so the only edge the eye can find is the boulders'.
	disc(parent, "PondBed", r + BED_OUT, BED_THICK,
		x, groundY + BED_LIFT - BED_THICK / 2, z, BED)
	local water = disc(parent, "PondWater", r + WATER_OUT, WATER_DEEP,
		x, groundY + WATER_TOP - WATER_DEEP / 2, z, WATER)
	water.Transparency = 0.34
	water.Reflectance = 0.06

	-- THE RIM IS WHAT KEEPS A PATHFINDING AGENT OUT OF THE WATER, AND A
	-- PathfindingModifier IS NOT (measured live, 2026-09-21). The obvious
	-- instrument is a modifier on the water -- `Label = "Water"`,
	-- `PassThrough = false`, plus `Costs.Water = math.huge` on the path --
	-- which is what shipped for one session. Measured on the live street:
	-- a path computed 35 studs either side of pond P1 (r 12) with that spec
	-- passed 1.0 stud from the pond's centre, identical to a path with no
	-- costs; a 26x6x26 non-colliding box over the pond carrying the same
	-- modifier changed nothing at +2, +4 and +8 s; the SAME box made
	-- CanCollide true routed the path 16.1 studs out. On this pipeline a
	-- modifier on a script-built non-colliding part does nothing, however
	-- tall, and only colliding geometry is an obstacle. So the modifier is
	-- gone rather than left claiming to work, and the RIM STONES collide.
	--
	-- AND A COLLIDING STONE IS NOT ENOUGH EITHER, BECAUSE THE NAVMESH STEPS
	-- IT (measured live, same day, fresh boot, all 134 stones colliding):
	-- every pond was still crossed dead centre at +6 s and +16 s. A stone is
	-- a ball 4.96 across sunk to a top 1.6 proud, and 1.6 studs is a STEP to
	-- the navmesh generator, not a wall. Control in the same session: 24
	-- invisible colliding cylinders 7.5 tall on the rim circle pushed the
	-- path 19.1 studs out. So each rim stone carries an invisible colliding
	-- COLUMN whose top is `groundY + Config.jumpReach() + rimJumpMargin` --
	-- the fence's and the trunk colliders' own rule: a wall has to beat a
	-- jump, derived, never a typed height. The stones stay colliding too,
	-- because the visible thing a player bumps should be the rock.
	--
	-- WHAT THAT COSTS, STATED PLAINLY: A POND IS IMPASSABLE TO PLAYERS AS
	-- WELL. With the walls over `jumpReach` nobody hops the rocks into the
	-- water any more -- which is consistent with the designer's call that
	-- impassable objects are things EVERYONE walks round, and it also removes
	-- the one case in which an officer would have waded: a thief standing in
	-- a pond. Bed, water, reeds and lily pads stay non-colliding decoration,
	-- and nothing inside the ring can be reached to make that matter.
	--
	-- Stones and columns take the trunk colliders' exact flag set --
	-- CanCollide true, CanQuery false so no raycast meant for a piggy is
	-- eaten, CanTouch false -- and the ring has no gap wider than an
	-- officer's agent (radius 2): a column stands on its stone's own centre
	-- at its stone's own radius, so at pitch 3.4 with radii 1.9-2.5 the
	-- widest edge-to-edge gap at column level, measured on the built ring
	-- in the suite, is under 4 studs. An officer with `AgentCanJump = false`
	-- goes round; the herd's own veto is `Grassland.blocks`, which reads the
	-- layout and never these parts.

	-- The rim: boulders round the water's edge, pitched so their chords at
	-- ground level overlap, radii and ring distance jittered so the outline
	-- is lumpy rather than a circle of beads.
	local ringR = r + WATER_OUT + G.stoneRingOut
	local count = math.max(6, math.ceil(2 * math.pi * ringR / G.stonePitch))
	for i = 1, count do
		local a = (i - 1) / count * math.pi * 2 + between(state, -0.08, 0.08)
		local sr = between(state, G.stoneRadius[1], G.stoneRadius[2])
		local rr = ringR + between(state, -0.4, 0.4)
		local sx, sz = x + math.cos(a) * rr, z + math.sin(a) * rr
		local stone = ball(parent, "PondStone", sr,
			sx, groundY - sr * STONE_SINK, sz,
			if i % 2 == 0 then STONE else STONE_2)
		-- Colliding, so the thing a player bumps is the rock; see above.
		stone.CanCollide = true

		-- The wall the navmesh cannot step. Sunk a stud into the ground like
		-- a trunk collider and reaching `jumpReach` plus the margin over it;
		-- the height is the difference of two derived numbers and nothing
		-- here is a typed height.
		local wallTop = groundY + Config.jumpReach() + G.rimJumpMargin
		local wallBottom = groundY - 1
		local wall = disc(parent, "RimWall", sr, wallTop - wallBottom,
			sx, (wallTop + wallBottom) / 2, sz, STONE)
		wall.Transparency = 1
		wall.CanCollide = true
	end

	-- Reeds just inside the rim, leaning a little, and lily pads floating
	-- on the water at staggered heights so no two pads share a plane.
	for i = 1, G.reeds do
		local a = between(state, 0, math.pi * 2)
		local h = between(state, 2.2, 3.0)
		local rr = r - 1.2
		part(parent, "Reed", Vector3.new(0.22, h, 0.22),
			CFrame.new(x + math.cos(a) * rr, groundY + h / 2 - 0.1, z + math.sin(a) * rr)
				* CFrame.Angles(math.rad(between(state, -7, 7)), a, math.rad(between(state, -7, 7))),
			REED)
	end
	for i = 1, G.pads do
		local a = between(state, 0, math.pi * 2)
		local rr = between(state, 0.2, 0.6) * r
		local pr = between(state, 0.8, 1.1)
		disc(parent, "LilyPad", pr, PAD_THICK,
			x + math.cos(a) * rr,
			groundY + WATER_TOP + PAD_LIFT + PAD_THICK / 2 + (i - 1) * 0.03,
			z + math.sin(a) * rr, PAD)
	end
end

-- A block half sunk into the grass, turned on two axes so it never lands
-- square to anything beside it.
local function buildRock(parent: Instance, x: number, z: number, groundY: number, state: { n: number }, i: number)
	local sx = between(state, 2.6, 4.2)
	local sy = between(state, 1.6, 2.4)
	local sz = between(state, 2.0, 3.2)
	part(parent, "Rock", Vector3.new(sx, sy, sz),
		CFrame.new(x, groundY + sy / 2 - 0.6, z)
			* CFrame.Angles(math.rad(between(state, -8, 8)), between(state, 0, math.pi * 2),
				math.rad(between(state, -8, 8))),
		if i % 2 == 0 then ROCK else ROCK_2)
end

-- A trunk lying in the grass with one stub branch, plus a paler end so it
-- reads as sawn rather than as a pipe.
local function buildLog(parent: Instance, x: number, z: number, groundY: number, state: { n: number })
	local length = between(state, 6.5, 8.5)
	local d = between(state, 1.5, 1.9)
	local yaw = between(state, 0, math.pi * 2)
	local at = CFrame.new(x, groundY + d / 2 - 0.3, z) * CFrame.Angles(0, yaw, 0)
	local trunk = part(parent, "Log", Vector3.new(length, d, d), at, LOG)
	trunk.Shape = Enum.PartType.Cylinder
	-- The end cap sits a hair inside the trunk's end and a hair narrower, so
	-- neither its face nor its rim shares a plane with the trunk's.
	local cap = part(parent, "LogEnd", Vector3.new(0.12, d - 0.24, d - 0.24),
		at * CFrame.new(length / 2 - 0.02, 0, 0), LOG_END)
	cap.Shape = Enum.PartType.Cylinder
	local branch = part(parent, "LogBranch", Vector3.new(between(state, 1.6, 2.4), 0.6, 0.6),
		at * CFrame.new(between(state, -length / 4, length / 4), d * 0.25, 0)
			* CFrame.Angles(0, math.rad(between(state, 55, 80)), math.rad(between(state, 18, 32)))
			* CFrame.new(0.9, 0, 0),
		LOG)
	branch.Shape = Enum.PartType.Cylinder
end

-- One drift: a green mound with heads nestled on it in two or three
-- colours, and a stem under every `stemEvery`th head standing round the
-- mound's foot so the close read is still flowers. Photographed, four 0.3
-- heads on stems were dots from thirty studs; the mound is what makes a
-- drift a PATCH of colour, and it is one part.
--
-- EVERY NUMBER IS DRAWN WHETHER OR NOT THE DRIFT STANDS, so a drift vetoed
-- by a new tree moves no other drift's flowers. Returns the parts made.
local function buildDrift(parent: Instance, cx: number, cz: number, groundY: number,
	state: { n: number }, ok: boolean): number
	local G = Config.GRASSLAND
	local n = math.floor(between(state, G.flowersPerCluster[1], G.flowersPerCluster[2] + 0.999))
	local base = math.floor(rnd(state) * #BLOOMS)
	local shades = 2 + math.floor(rnd(state) * 2)
	local mr = between(state, G.moundRadius[1], G.moundRadius[2])
	local moundY = groundY + mr * 0.1
	local made = 0
	if ok then
		ball(parent, "Mound", mr, cx, moundY, cz, MOUND)
		made += 1
	end
	for f = 1, n do
		local a = (f - 1) / n * math.pi * 2 + between(state, -0.3, 0.3)
		local hr = between(state, G.headRadius[1], G.headRadius[2])
		local colour = BLOOMS[((base + math.floor(rnd(state) * shades)) % #BLOOMS) + 1]
		local stemmed = f % G.stemEvery == 0
		if stemmed then
			-- Round the mound's foot, standing up beside it.
			local rr = mr + between(state, 0.3, 1.0)
			local h = between(state, G.stemHeight[1], G.stemHeight[2])
			local sink = between(state, 0.05, 0.14)
			if ok then
				local fx, fz = cx + math.cos(a) * rr, cz + math.sin(a) * rr
				part(parent, "Stem", Vector3.new(0.16, h, 0.16),
					CFrame.new(fx, groundY + h / 2 - sink, fz), STEM)
				ball(parent, "Bloom", hr, fx, groundY + h - sink + hr * 0.4, fz, colour)
				made += 2
			end
		else
			-- Nestled on the mound: the head's centre sits on the mound's
			-- surface at its own distance out, so it reads as growing from it.
			local rr = between(state, 0.15, 0.85) * mr
			rnd(state) -- keeps the draw count level with a stemmed head
			rnd(state)
			if ok then
				local fx, fz = cx + math.cos(a) * rr, cz + math.sin(a) * rr
				local surface = moundY + math.sqrt(math.max(0, mr * mr - rr * rr))
				ball(parent, "Bloom", hr, fx, surface + hr * 0.35, fz, colour)
				made += 1
			end
		end
	end
	return made
end

-- A low bush: two or three overlapping green balls, for silhouette where
-- the band would otherwise be flat between the trees. Always draws three
-- balls' worth of numbers so the sequence does not depend on the count.
local function buildBush(parent: Instance, x: number, z: number, groundY: number, state: { n: number }): number
	local G = Config.GRASSLAND
	local count = math.floor(between(state, G.bushBalls[1], G.bushBalls[2] + 0.999))
	local made = 0
	for i = 1, G.bushBalls[2] do
		local r = between(state, G.bushRadius[1], G.bushRadius[2])
		local a = between(state, 0, math.pi * 2)
		local off = if i == 1 then 0 else between(state, 0.45, 0.8) * r
		if i <= count then
			ball(parent, "Bush", r, x + math.cos(a) * off, groundY + r * 0.35, z + math.sin(a) * off,
				if i % 2 == 0 then BUSH_2 else BUSH)
			made += 1
		end
	end
	return made
end

-- ------------------------------------------------------------
-- THE BUILD
-- ------------------------------------------------------------
--[[
	Builds the grassland into a `Grassland` folder under `parent`, records
	the ponds for `blocks`, and returns the folder, the ponds and the part
	count. `obstacles` is the grove: NeighborhoodService passes what
	`buildTrees` actually stood; the suite passes what it likes.
]]
function Grassland.build(parent: Instance, obstacles: { Obstacle }?): (Folder, { Pond }, number)
	local G = Config.GRASSLAND
	local g = Config.herdGround()
	local groundY = g.groundY
	local trees: { Obstacle } = obstacles or {}
	local b = bounds(g)

	local folder = Instance.new("Folder")
	folder.Name = "Grassland"

	local ponds = Grassland.layout(g, trees)
	placed = ponds

	local state = { n = G.seed % 100000 }
	local count = 0
	local function counted(n: number)
		count += n
	end

	for _, pond in ipairs(ponds) do
		local before = #folder:GetChildren()
		buildPond(folder, pond, groundY, state)
		counted(#folder:GetChildren() - before)
	end

	-- Things that must not stand in a pond, in a trunk, or in the corridor
	-- a pack turns out of. Rocks and the log are placed first so a flower
	-- can also keep out of them.
	local rocks: { { x: number, z: number, r: number } } = {}
	local function clearOf(x: number, z: number, keep: number): boolean
		if math.abs(x) > b.xMax then
			return false
		end
		for _, pond in ipairs(ponds) do
			if dist(x, z, pond.x, pond.z) < pond.rim + G.pondKeep + keep then
				return false
			end
		end
		for _, t in ipairs(trees) do
			if dist(x, z, t.x, t.z) < G.trunkKeep + keep then
				return false
			end
		end
		for _, rock in ipairs(rocks) do
			if dist(x, z, rock.x, rock.z) < rock.r + keep then
				return false
			end
		end
		return true
	end

	for _, side in ipairs({ -1, 1 }) do
		-- Rocks: draw, then place if clear. A refused draw is still spent.
		local stood = 0
		for _ = 1, G.rocksPerSide * 4 do
			local x = between(state, -b.xMax, b.xMax)
			local z = side * between(state, b.zLo, b.zHi)
			local pick = math.floor(rnd(state) * 2)
			if stood < G.rocksPerSide and clearOf(x, z, 2.5) then
				local before = #folder:GetChildren()
				buildRock(folder, x, z, groundY, state, pick)
				counted(#folder:GetChildren() - before)
				table.insert(rocks, { x = x, z = z, r = 3 })
				stood += 1
			end
		end
		-- The logs, the same way.
		local logs = 0
		for _ = 1, G.logsPerSide * 4 do
			local x = between(state, -b.xMax, b.xMax)
			local z = side * between(state, b.zLo, b.zHi)
			if logs < G.logsPerSide and clearOf(x, z, 5) then
				local before = #folder:GetChildren()
				buildLog(folder, x, z, groundY, state)
				counted(#folder:GetChildren() - before)
				table.insert(rocks, { x = x, z = z, r = 5 })
				logs += 1
			end
		end
		-- Bushes, the same way again, and recorded so a drift keeps out.
		local bushes = 0
		for _ = 1, G.bushesPerSide * 4 do
			local x = between(state, -b.xMax, b.xMax)
			local z = side * between(state, b.zLo, b.zHi)
			if bushes < G.bushesPerSide and clearOf(x, z, 3) then
				counted(buildBush(folder, x, z, groundY, state))
				table.insert(rocks, { x = x, z = z, r = 3.5 })
				bushes += 1
			end
		end
		-- Flower drifts: a centre, then everything about the drift is drawn
		-- inside `buildDrift` whether or not it stands.
		for _ = 1, G.flowerClustersPerSide do
			local cx = between(state, -b.xMax, b.xMax)
			local cz = side * between(state, b.zLo, b.zHi)
			counted(buildDrift(folder, cx, cz, groundY, state, clearOf(cx, cz, 3)))
		end
	end

	folder.Parent = parent
	return folder, ponds, count
end

return Grassland
