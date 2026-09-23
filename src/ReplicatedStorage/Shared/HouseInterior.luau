--!strict
--[[
	HouseInterior -- the hall behind the front door.

	ONE FIXED-SIZE, FIXED-LAYOUT INTERIOR FOR EVERY HOUSE TIER: a wide vaulted
	hall, a raised display platform down each side with the collection standing
	on it, and a cross wall with a door in it between one room and the next.
	See docs/PIGGY-COLLECTION-PLAN.md section 6, rewritten 2026-09-20, and the
	designer's reference of 2026-09-21.

	WHAT A HOUSE BUYS IN HERE IS AN ACCENT AND NEVER THE ROOM. The walls, the
	floor, the platforms and the vault are one neutral stone for every house --
	pale grey-blue with darker grout, the reference's own palette -- and the
	tier's `trim` colours only the joinery: the ribs, the door frames and
	leaves, the light fixtures. The first build derived the WHOLE palette from
	the house row, and photographed on the dev save it came out saturated
	neon purple, because the dev house is a neon tier and a room derived from
	a house palette is a neon room the moment the house is one. A derivation
	can be correct in every line and guarantee the wrong picture.

	Capacity is a separate axis entirely and it comes from REBIRTHS:
	`Config.indoorPlots`.

	THE ROOM CADENCE IS DERIVED, NOT TABLED. `Config.INDOOR.plotsPerRebirth`
	is the single pacing dial; a room holds `Config.INDOOR_ROOM_PLOTS`; and a
	door opens when there is a plot standing BEYOND it, which is exactly
	`Config.indoorRooms(capacity)`. There is no second table saying which
	rebirth opens which door -- and THE DOOR PRINTS ITS OWN NUMBER off the
	same ladder (`Config.indoorDoorRebirths`), so "Need 2 Rebirths" on a leaf
	and the leaf actually opening at two cannot disagree. This project has a
	dozen post-mortems about two tables that can; `RARITY_ORDER` against
	`PIGGY_RARITY_INCOME` is the newest.

	================================================================
	IT IS LIT, AND THAT WAS THE FIRST LIVE FINDING
	================================================================

	An enclosed box four thousand studs off the map receives no outdoor
	ambient at all. Photographed, the first hallway was BLACK: the only things
	on screen were the Neon parts, and the floor plots were six black pits. So
	the second build put a PointLight in every hanging fixture and painted
	every surface pale to receive it -- and photographed as a WHITE-OUT,
	because that diagnosis was wrong: nothing in this repo casts a shadow, so
	the vault never kept the sun out and the first hall was black only because
	a neon house's palette made its walls near-black. THE SUN LIGHTS THIS
	ROOM. The stone is a warm mid value authored for that sun and the blue
	ambient on top of it (see the note over the stone constants), the fixtures
	are geometry with no light in them (see `buildFixture` for the two values
	that were tried), and nothing in here is Neon except the portal in the
	doorway.

	================================================================
	IT IS GEOMETRY AND NOT A SERVICE
	================================================================

	`House.luau` and `Decor.luau` are the model: a builder in `Shared` that
	takes a parent and a CFrame and hands back a Model, with no state, no
	remotes and no idea whose plot it is. `InteriorService` instances these
	off-map, walks players through the door, and is the CONTRACT this file has
	to keep: `Refs.origin`, `Refs.entrance`, `Refs.exit` (a part named
	`Door_Exit` whose `Size.Z` is the aperture and `Size.Y` the headroom),
	`Refs.mount` (`Mount_Wall`), `footprint()`, `setCapacity`, `setDoor`,
	`dress` and `plotGround`. The gate plane stands `Config.HOUSE_DOOR.exitReach`
	down the corridor from `origin`, so `entrance` has to be past it and the
	exit slab short of it, and the estate pitch is `footprint().Z` plus a gap
	-- so a wider hall moves every hallway apart on its own.

	================================================================
	IT IS THE FIRST THING THIS GAME BUILDS THAT YOU STAND INSIDE
	================================================================

	`LowPoly.part` hardcodes `CanCollide = false`, and it is right to: a house
	is a status symbol and a shop is scenery, and neither may become cover in
	a chase. A ROOM IS NOT SCENERY. The shell collides -- floor, walls,
	platforms, vault, cross walls, and a SHUT door -- and every piece of
	dressing on it does not. `solid` and `LowPoly.part` are the two primitives
	and the choice between them is the choice between those two sentences.

	================================================================
	WHAT IT COSTS, MEASURED ON A STUBBED BUILD
	================================================================

	See the figures beside `footprint` and the part-count table in the change
	report: at the shipped dial it is about 315 studs long by 40 wide by 23
	tall, ten rooms, fifty-six plots. That is a long walk and it is the direct
	consequence of "one hall, doors along it" and of the reference's width --
	the levers if it reads as too long are `Config.INDOOR.plotsPerSide` and
	`PLOT_PITCH`, never the plot count, which is the pacing.

	`rooms` on `build` is the one concession to cost: `InteriorService` builds
	the prefix a save has unlocked and rebuilds when it grows. The LAYOUT is
	identical either way -- room 4 lands on the same studs whether or not
	rooms 5 to 10 exist -- so it is an optimisation and never a second layout.

	ZERO SAME-FACING COPLANAR PAIRS across the axis-aligned parts, swept the
	way the house rebuild's own audit sweeps. The vault, the ribs and the
	pediment are rotated and outside that sweep, and are kept apart by
	construction (each rib's outer face sits a hair inside the vault's inner
	face; each facet overlaps its neighbour at the crease on purpose).

	================================================================
	NAMES THAT ARE A CONTRACT
	================================================================

	`Mount_Wall` and `Door_Exit` are the mount names
	`assets/houses/docs/HOUSE-TROPHY-ROOMS.md` fixes; the achievement wall
	keeps its own separate mount in the lobby. NOTHING DRAWS ON IT TODAY:
	the in-house achievement room (`Services/TrophyRoom`) was retired on
	2026-09-22 and the achievements move into this base later, so the mount
	is where that display will hang and is kept for it. Its old wall sweep
	matched `Collide_*side*` and read `Size.X` as a wall's WIDTH, which is
	why nothing here is named with "side" in it -- these walls run along X,
	and the next reader of the mount should keep that rule.

	NOT YET VERIFIED HERE: nothing in this file has been stood in by its
	author. The coordinator holds Studio, stood in the first build, and is
	photographing this one.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LowPoly = require(ReplicatedStorage.Shared.LowPoly)
-- For the font and the ink on the door labels. `Theme` requires nothing, so a
-- server-side builder may take it -- the rule the verge boards got wrong.
local Theme = require(ReplicatedStorage.Shared.Theme)

local HouseInterior = {}

-- ============================================================
-- THE GEOMETRY, AND WHAT IS DERIVED FROM WHAT
-- ============================================================
--
-- `Config.INDOOR` carries the LADDER because the boot audit reads it and it
-- is a pacing decision. Everything below is how big the hall those plots
-- stand in has to be, which is a fact about this builder.

-- The square a piggy stands on. Sized against the reference's pet bases: a
-- little larger than the first build's, because the hall is now read across
-- sixteen studs of lane rather than from four studs away in a corridor.
local PLOT_TILE = 5.4
-- The border that makes a plot a plot -- see `buildPlot`.
local SURROUND = 0.7
-- THE BAY BETWEEN TWO PLOTS, LEFT FOR THE IN-BASE SHOP. The reference stands
-- small stalls between the pets along both walls; those are Stage 5 and are
-- NOT built here, but the wall bay they would stand in is, so a stall lands
-- between plots later without the plot grid moving.
local STALL_BAY = 4.0
local PLOT_PITCH = PLOT_TILE + STALL_BAY

-- The clear walk down the middle, at the reference's proportion -- about
-- three times the first build's eight.
local LANE = 16.0
-- THE RAISED PLATFORM DOWN EACH SIDE, which is what makes this read as a
-- display room rather than a service corridor (the second live finding).
-- Deep enough for a plot, its surround, a label read from the lane and a
-- stall bay behind it.
local PLATFORM_D = 11.0
-- Two studs is the reference; 1.6 plus a half-height step along the front is
-- what a character can actually climb without a jump, and a platform nobody
-- can climb is a plot nobody can place on.
local PLATFORM_H = 1.6
local STEP_D = 1.6
-- INNER width, wall face to wall face: lane plus a platform each side.
local WIDTH = LANE + PLATFORM_D * 2
-- The centre line each row of plots stands on: the middle of its platform.
local PLOT_Z = WIDTH / 2 - PLATFORM_D / 2

local WALL = 1.0
-- The walls stop here and the vault springs from it.
local WALL_H = 12.0
local FLOOR_T = 1.0

-- THE VAULT: a circular arc across the hall, drawn as flat facets, with darker
-- ribs crossing it at intervals and a hanging light under the ridge -- the
-- reference's ceiling. The chord spans the wall centrelines at `WALL_H`.
local VAULT_RISE = 9.0
local VAULT_FACETS = 6
local VAULT_T = 0.6
local RIB_T = 0.8
local RIB_W = 1.0

-- A CROSS WALL BETWEEN ROOMS, with a doorway in it -- and THE DOORWAY IS A
-- SIGHTLINE, NOT A DOOR (designer, 2026-09-21: once rooms are unlocked you
-- see the piggies all the way down the hall from the entrance). The piggies
-- stand on the raised platforms, eleven studs out from the lane each side, so
-- an opening centred on the lane can never show them: the arch clears nearly
-- the whole cross-section, 34 of the 38 inner studs, under a thin header,
-- with the tympanum only up in the vault. Eleven tall clears a pedestal's
-- display on a 1.6 platform with margin. `tests/luau/interior.luau` traces
-- the line from the entrance to the farthest plot through every open door
-- and refuses anything in the model that crosses it.
local CROSS = 1.4
local DOOR_W = 34.0
local DOOR_H = 11.0
local HEADER_T = 0.9
-- The frame round the opening, straddling its edge; a leaf hangs from the
-- frame's inner face and stops at the middle.
local JAMB_W = 0.9
local LEAF = DOOR_W / 2 - JAMB_W / 2
local LEAF_T = 0.5

-- The entrance bay: the way out, the achievement wall, no plots.
local LOBBY = 20.0

-- THE PORTAL: a block of light standing in a doorway. Deep enough that a
-- character walking through it is INSIDE it for a stride, which is what makes
-- the crossing read as being transported rather than as touching a panel.
local PORTAL_DEPTH = 2.2

-- The project convention: anything standing on something sinks about this far
-- into it, so no two parts share the plane where they meet. Two SIBLINGS
-- standing on the same thing have to differ from each other as well, which is
-- why there are two of them.
local SINK = 0.1
local PLOT_SINK = 0.2

-- How far the plot face stands above the surround under it, and how far it
-- bites in. Copied in SHAPE from `Config.PIGGY_PEDESTAL.pad`: a recess is made
-- by standing something PROUD around the dark, never by sinking the dark.
local FACE_SINK = 0.1
local FACE_PROUD = 0.14

-- ============================================================
-- THE STONE, WHICH IS THE SAME FOR EVERY HOUSE
-- ============================================================
--
-- MID-TONE, NOT PALE, AND THE SECOND PHOTOGRAPH IS WHY. The first pass was
-- authored pale on the reasoning that an off-map box gets no light and the
-- walls had to receive the fixtures'. Wrong twice: every part in this repo is
-- `CastShadow = false`, so the vault never blocked the sun and the hall has
-- had full daylight in it the whole time -- the first build read black
-- because a neon house's palette made its walls near-black, not because it
-- was dark. Pale stone under a 2.4 sun, fifteen lights and a bloom threshold
-- of 1.7 then photographed as a WHITE-OUT, every surface over the bar, with
-- the sky's cyan showing on the vault. The shopfront's cream trim did the
-- same at a measured luminance of 0.973.
--
-- So these are authored DARKER AND WARMER than the reference's tiles look,
-- because the number in the source is not the colour on the screen: a flat
-- SmoothPlastic under this sun renders about a third brighter than its RGB
-- says (the lawn's own lesson), and `WorldService`'s ambients are BLUE --
-- Ambient (92, 98, 124), OutdoorAmbient (88, 100, 132) -- so every flat face
-- is lifted and cooled before anybody sees it. The grey-blue of the first
-- two passes (148, 162, 178) photographed as pale blue; these are
-- warm-neutral and about fifteen per cent lower again, and the ambient puts
-- the blue back. NOT a tier colour, for the reason at the top of the file.
-- Grout a clear step under the stone, so the courses read.
local STONE = Color3.fromRGB(126, 132, 138)
local STONE_DEEP = Color3.fromRGB(96, 100, 106)
local GROUT = Color3.fromRGB(70, 74, 80)
local FLOOR = Color3.fromRGB(84, 84, 86)
local PLATFORM = Color3.fromRGB(110, 114, 120)
local VAULT = Color3.fromRGB(128, 134, 140)
-- A plot you may stand something on, and one you may not yet. Dark rather
-- than a second hue: an unlit slab says "nothing here yet" in a vocabulary a
-- nine-year-old already has, where a red plot says "broken".
local PLOT_OPEN = Color3.fromRGB(196, 186, 166)
local PLOT_LOCKED = Color3.fromRGB(70, 72, 80)
-- The fixture's own panel: warm, NOT Neon, and no brighter than the stone
-- round it needs. Only the portal glows.
local FIXTURE = Color3.fromRGB(206, 192, 160)

-- THE PORTAL'S COLOUR IS DEEP ON PURPOSE. Neon renders a colour flat out and
-- the BloomEffect takes it from there, so a PALE yellow is not a warm glow, it
-- is a white hole -- the first Martian skin, the palace's first lit colonnade,
-- the townhouse's window rank and the street lamp all shipped that way.
-- Saturation is what survives the bloom and value is not.
local PORTAL_HUE = 40 / 360
local PORTAL_SAT = 0.94
local PORTAL = Color3.fromHSV(PORTAL_HUE, PORTAL_SAT, 0.92)

local BLACK = Color3.new(0, 0, 0)

export type Theme = {
	-- The tier's joinery colour, on the ribs, the door frames and the
	-- fixture trim. Nothing else in the room reads it.
	accent: Color3,
	accentDeep: Color3,
}

export type Plot = {
	-- 1..Config.indoorPlotCeiling(), in order down the hall: left then right
	-- at each position, position by position, room by room -- the same dense
	-- front-to-back order the lawn's own slots use.
	index: number,
	room: number,
	-- WHERE A PIGGY STANDS: the top of the plot face, on the platform, turned
	-- to look into the lane. A caller seating a `PiggyPedestal` gets the
	-- facing for free -- move the machine to the hand, never the hand to the
	-- machine.
	ground: CFrame,
	face: BasePart,
	surround: BasePart,
	unlocked: boolean,
}

export type Door = {
	-- The room this door opens INTO, 2..rooms.
	room: number,
	-- What it prints: the rebirth count the ladder opens this room at.
	rebirths: number,
	leaves: { BasePart },
	labels: { SurfaceGui },
	shut: { CFrame },
	open: { CFrame },
	isOpen: boolean,
}

export type Refs = {
	model: Model,
	-- The threshold: the middle of the floor at the inner face of the exit
	-- door, floor top at y = 0, +X down the hall. Everything is authored off
	-- it, so the whole room moves with one `PivotTo`.
	origin: CFrame,
	-- WHERE SOMEBODY ARRIVES, ON THE FLOOR, FACING DOWN THE HALL. Past the
	-- gate plane at `Config.HOUSE_DOOR.exitReach`, so arriving does not walk
	-- straight back out. A GROUND CFrame the caller lifts by its own
	-- `HipHeight`, aimed with a CHARACTER'S convention -- its front is its
	-- LookVector, the opposite of every model in this game.
	entrance: CFrame,
	plots: { Plot },
	doors: { Door },
	rooms: number,
	capacity: number,
	mount: BasePart,
	-- `Door_Exit`: its `Size.Z` is the aperture the exit gate uses and its
	-- `Size.Y` the headroom. Move it and the gate moves with it.
	exit: BasePart,
	-- The block of light in the way out.
	portal: BasePart,
	-- Repainted by `dress` and by nothing else. Held by reference rather than
	-- looked up by name, which this project has paid for twice.
	painted: {
		accent: { BasePart },
		accentDeep: { BasePart },
	},
	theme: Theme,
}

-- ============================================================
-- PRIMITIVES
-- ============================================================

-- The shell. `LowPoly.part` with the collision put back on, rather than a
-- second primitive: one function decides what a part in this game looks like.
local function solid(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3): Part
	local p = LowPoly.part(parent, name, size, cf, colour, Enum.Material.SmoothPlastic)
	p.CanCollide = true
	p.CanQuery = true
	return p
end

-- Dressing. Never collides, never answers a query, never casts a shadow.
local function dress(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3): Part
	return LowPoly.part(parent, name, size, cf, colour, Enum.Material.SmoothPlastic)
end

local function paint(refs: Refs, slot: string, p: BasePart): BasePart
	table.insert((refs.painted :: any)[slot], p)
	return p
end

-- ============================================================
-- THE ACCENT, OFF THE HOUSE ROW THAT ALREADY EXISTS
-- ============================================================

function HouseInterior.themeOf(tier: any?): Theme
	local row: any = tier or Config.HOUSE_TIERS[1]
	local accent: Color3 = row.trim or Color3.fromRGB(120, 84, 58)
	return {
		accent = accent,
		-- The ribs and the leaves, a step darker so the joinery reads as
		-- structure against the pale vault rather than as the same paint.
		accentDeep = accent:Lerp(BLACK, 0.30),
	}
end

-- ============================================================
-- THE LAYOUT
-- ============================================================
--
-- Solved once and read by every builder, so none of them can disagree about
-- where room seven starts. The last room is built SHORT rather than full and
-- half locked: a plot that can never unlock, at the rebirth ceiling, behind
-- an open door, is the game promising something that does not exist.
type Room = { index: number, x0: number, x1: number, plots: number, along: number }
type Cross = { room: number, x: number }
type Layout = { rooms: { Room }, crosses: { Cross }, length: number }

local function layout(rooms: number): Layout
	local per = Config.INDOOR_ROOM_PLOTS
	local out: Layout = { rooms = {}, crosses = {}, length = 0 }
	local x = LOBBY
	for r = 1, rooms do
		if r > 1 then
			table.insert(out.crosses, { room = r, x = x + CROSS / 2 })
			x += CROSS
		end
		local n = math.clamp(Config.indoorPlotCeiling() - (r - 1) * per, 0, per)
		local along = math.max(1, math.ceil(n / 2))
		table.insert(out.rooms, { index = r, x0 = x, x1 = x + along * PLOT_PITCH, plots = n, along = along })
		x += along * PLOT_PITCH
	end
	out.length = x
	return out
end

-- The vault's arc, solved from its chord and rise. Read by the vault, the
-- ribs, the end walls and the footprint -- and EXPORTED, so the suite that
-- checks the facets actually lie on it reads the same arc rather than a
-- second copy of this arithmetic.
local function vaultArc(): (number, number, number)
	local half = WIDTH / 2 + WALL / 2
	local radius = (VAULT_RISE * VAULT_RISE + half * half) / (2 * VAULT_RISE)
	local theta = math.asin(half / radius)
	local centreY = WALL_H + VAULT_RISE - radius
	return radius, theta, centreY
end

-- ============================================================
-- THE SHELL
-- ============================================================

-- THE SLAB, RUNNING HALF A STUD UNDER THE WALLS ON EVERY SIDE AND NEVER OUT
-- TO THEIR OUTER FACES: flush with them it shared a plane with every end and
-- side wall in the building.
local function buildFloor(parent: Instance, at: CFrame, len: number)
	solid(parent, "Collide_Floor", Vector3.new(len + WALL, FLOOR_T, WIDTH + WALL),
		at * CFrame.new(len / 2, -FLOOR_T / 2, 0), FLOOR)
end

-- THE VAULT: `VAULT_FACETS` flat slabs the length of the hall, each turned to
-- sit on the arc. Their INNER faces are the ceiling; they collide, because a
-- ceiling a jump could leave through is a room with no lid.
--
-- THE TILT IS `+phi`, AND IT SHIPPED AS `-phi` FOR ONE PHOTOGRAPH. Rotating a
-- slab about X by `a` sends its width axis (local Z) to (z = cos a,
-- y = -sin a); the arc's tangent at `phi` is (z = cos phi, y = -sin phi); so
-- `a = phi`. With the sign flipped every facet's CENTRE sat on the arc and
-- every facet SLOPED AGAINST the curve -- a sawtooth, photographed live with
-- sky wedges between every pair, and vertical rays across the hall reading
-- 20.2 / 17.5 / 12.6 / 16.6, which an arch cannot do. Nothing offline caught
-- it: a straight-up ray stops on the first top face it meets, and no plot
-- sightline crosses the roof. `tests/luau/interior.luau` now checks each
-- facet's width axis against the arc's tangent at its own angle and that the
-- ceiling height falls monotonically from the ridge outward -- and proves
-- both fire by running them against the `-phi` version.
local function buildVault(parent: Instance, at: CFrame, len: number)
	local radius, theta, centreY = vaultArc()
	local step = (2 * theta) / VAULT_FACETS
	-- A hair wider than its chord so neighbouring facets overlap at the
	-- crease instead of leaving a sliver of sky.
	local facetW = 2 * radius * math.sin(step / 2) + 0.3
	for i = 0, VAULT_FACETS - 1 do
		local phi = -theta + step * (i + 0.5)
		local r = radius + VAULT_T / 2
		solid(parent, "Collide_Vault", Vector3.new(len + WALL, VAULT_T, facetW),
			at * CFrame.new(len / 2, centreY + r * math.cos(phi), r * math.sin(phi))
				* CFrame.Angles(phi, 0, 0),
			VAULT)
	end
	-- The ridge beam under the apex, which the fixtures hang from.
	dress(parent, "Ridge", Vector3.new(len + WALL, 0.8, 1.2),
		at * CFrame.new(len / 2, WALL_H + VAULT_RISE - 0.5, 0), VAULT:Lerp(BLACK, 0.18))
end

-- A RIB ACROSS THE VAULT: the same facets, thicker, darker, standing proud of
-- the ceiling into the room. Its outer face sits a hair INSIDE the vault's
-- inner face rather than on it.
local function buildRib(refs: Refs, parent: Instance, x: number)
	local radius, theta, centreY = vaultArc()
	local step = (2 * theta) / VAULT_FACETS
	local facetW = 2 * radius * math.sin(step / 2) + 0.2
	for i = 0, VAULT_FACETS - 1 do
		local phi = -theta + step * (i + 0.5)
		local r = radius - RIB_T / 2 - 0.05
		paint(refs, "accentDeep", dress(parent, "Rib", Vector3.new(RIB_W, RIB_T, facetW),
			refs.origin * CFrame.new(x, centreY + r * math.cos(phi), r * math.sin(phi))
				* CFrame.Angles(phi, 0, 0),
			refs.theme.accentDeep))
	end
end

-- A HANGING LIGHT FIXTURE: two rods off the ridge and a panel. GEOMETRY ONLY;
-- there is no light in it.
--
-- There was, twice. At 1.4 over 34 studs, one per rib bay, fifteen lights on
-- top of the daylight that is already in here (see the stone above) blew the
-- whole hall past the bloom bar; cut to 0.3 over 22 they photographed as
-- nothing -- no pool under any fixture, a flat grey floor. A light that
-- cannot be seen is a cost with no picture, so the fixture is a fixture and
-- the sun does the lighting.
local function buildFixture(refs: Refs, parent: Instance, x: number)
	local at = refs.origin
	local beamBottom = WALL_H + VAULT_RISE - 0.9
	local rodL = 2.6
	for _, s in ipairs({ -1, 1 }) do
		paint(refs, "accent", dress(parent, "Rod", Vector3.new(0.16, rodL, 0.16),
			at * CFrame.new(x, beamBottom - rodL / 2, s * 1.6), refs.theme.accent))
	end
	local panelY = beamBottom - rodL - 0.2
	paint(refs, "accent", dress(parent, "FixtureFrame", Vector3.new(4.6, 0.5, 4.6),
		at * CFrame.new(x, panelY, 0), refs.theme.accent))
	dress(parent, "FixturePanel", Vector3.new(4.0, 0.4, 4.0),
		at * CFrame.new(x, panelY - 0.3, 0), FIXTURE)
end

-- A RUN OF SIDE WALL, in stone with grout lines standing proud of it.
--
-- The grout is the interior's quoin: a hard line of a second colour where
-- two flat surfaces meet, because flat shading gives a wall of one value no
-- courses at all. Two horizontal courses and a few vertical joints on the
-- upper course, which reads as blockwork from the lane and costs about five
-- parts a side. Every strip sits 0.14 proud of the wall face and buries 0.06
-- into it, so it shares no plane with the wall it is drawn on; the verticals
-- stop exactly on the horizontals' faces, which is a butt joint.
local function buildSideWall(refs: Refs, parent: Instance, name: string, x0: number, x1: number,
	floorY: number, grout: boolean, skipSide: number?)
	local at = refs.origin
	local len = x1 - x0
	if len <= 0 then
		return
	end
	local mid = (x0 + x1) / 2
	local course = WALL_H / 3
	for _, s in ipairs({ -1, 1 }) do
		solid(parent, name, Vector3.new(len, WALL_H, WALL),
			at * CFrame.new(mid, WALL_H / 2, s * (WIDTH / 2 + WALL / 2)), STONE)
		-- Skirting, on whatever floor stands against this wall. A shade
		-- SHORTER than the run, as is every strip drawn along one: spanning the
		-- wall's exact length they shared its end planes with the platform
		-- under them, twenty pairs at once.
		-- And BURIED A QUARTER INTO THE WALL rather than standing against its
		-- face: flush, its back was the platform's own outer edge.
		dress(parent, "Skirting", Vector3.new(len - 0.4, 1.1, 0.5),
			at * CFrame.new(mid, floorY + 0.55 - SINK, s * (WIDTH / 2 - 0.15)), STONE_DEEP)
		if grout and s ~= skipSide then
			local gz = s * (WIDTH / 2 - 0.04)
			for c = 1, 2 do
				dress(parent, "Grout", Vector3.new(len - 0.6, 0.12, 0.2),
					at * CFrame.new(mid, course * c, gz), GROUT)
			end
			-- Vertical joints on the upper course only, one per plot pitch,
			-- offset half a pitch so they never land on a plot's centre line.
			local joints = math.floor(len / PLOT_PITCH)
			for j = 1, joints do
				local jx = x0 + (j - 0.5) * PLOT_PITCH
				dress(parent, "Grout", Vector3.new(0.12, course - 0.12, 0.2),
					at * CFrame.new(jx, course * 1.5, gz), GROUT)
			end
		end
	end
end

-- THE RAISED PLATFORM DOWN EACH SIDE OF A ROOM, and the step up onto it.
--
-- The step sinks into the floor and the platform stands on it, so the two
-- undersides are on different planes; the step's back face and the
-- platform's front face point at each other, which is a butt joint.
local function buildPlatforms(parent: Instance, at: CFrame, x0: number, x1: number)
	local len = x1 - x0
	local mid = (x0 + x1) / 2
	for _, s in ipairs({ -1, 1 }) do
		solid(parent, "Collide_Platform", Vector3.new(len, PLATFORM_H, PLATFORM_D),
			at * CFrame.new(mid, PLATFORM_H / 2, s * (WIDTH / 2 - PLATFORM_D / 2)), PLATFORM)
		local stepH = PLATFORM_H / 2
		solid(parent, "Collide_Step", Vector3.new(len, stepH + SINK, STEP_D),
			at * CFrame.new(mid, (stepH - SINK) / 2, s * (WIDTH / 2 - PLATFORM_D - STEP_D / 2)),
			PLATFORM:Lerp(BLACK, 0.12))
	end
end

-- ONE FLOOR PLOT, ON THE PLATFORM: a surround with a face standing proud of
-- it. The same two-part shape `PIGGY_PEDESTAL.pad` arrived at after two wrong
-- builds -- flush, the two tops are one plane and flicker; sunk, the face is
-- INSIDE the surround, because a Part cannot cut a hole in another Part.
local function buildPlot(refs: Refs, parent: Instance, index: number, room: number, x: number, s: number): Plot
	local at = refs.origin
	local z = s * PLOT_Z
	local surroundTop = PLATFORM_H + 0.30
	local faceTop = surroundTop + FACE_PROUD
	local faceThick = FACE_PROUD + FACE_SINK
	local surroundThick = 0.30 + PLOT_SINK

	local surround = dress(parent, "PlotSurround",
		Vector3.new(PLOT_TILE + SURROUND, surroundThick, PLOT_TILE + SURROUND),
		at * CFrame.new(x, surroundTop - surroundThick / 2, z), STONE_DEEP)
	local face = dress(parent, "PlotFace", Vector3.new(PLOT_TILE, faceThick, PLOT_TILE),
		at * CFrame.new(x, faceTop - faceThick / 2, z), PLOT_LOCKED)

	-- Addressable from the instance alone: a client handed this part by a
	-- prompt can say which plot it is with no lookup.
	face:SetAttribute("Plot", index)
	face:SetAttribute("Room", room)

	-- TURNED TO LOOK INTO THE LANE. Every model in this game is authored
	-- facing +Z, so a piggy on the +Z platform takes a half turn to face -Z.
	local yaw = if s > 0 then math.pi else 0
	return {
		index = index,
		room = room,
		ground = at * CFrame.new(x, faceTop, z) * CFrame.Angles(0, yaw, 0),
		face = face,
		surround = surround,
		unlocked = false,
	}
end

-- WHAT A LOCKED DOOR SAYS. A dark inset on the leaf with the rebirth count
-- the ladder opens this room at -- derived, never typed, so the text and the
-- door cannot disagree.
--
-- ON THE FACE THE APPROACH SEES. The leaf is thin on its own X and somebody
-- reaching a shut door is coming from lower x, so the face they read is -X,
-- which Roblox calls `Left`. A SurfaceGui REPLACES the face it is on, so the
-- fill is drawn here rather than left transparent -- the trophy plaques
-- rendered as black panels until that was learned.
local PIXELS_PER_STUD = 100

local function buildDoorLabel(leaf: BasePart, rebirths: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label"
	gui.Face = Enum.NormalId.Left
	gui.CanvasSize = Vector2.new(
		math.floor(leaf.Size.Z * PIXELS_PER_STUD), math.floor(leaf.Size.Y * PIXELS_PER_STUD))
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.LightInfluence = 0.4

	local inset = Instance.new("Frame")
	inset.Name = "Inset"
	inset.BackgroundColor3 = Theme.INK
	inset.BorderSizePixel = 0
	inset.Size = UDim2.fromScale(0.72, 0.30)
	inset.Position = UDim2.fromScale(0.14, 0.34)
	inset.Parent = gui

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(0.9, 0.8)
	text.Position = UDim2.fromScale(0.05, 0.1)
	text.Font = Theme.FONT
	text.TextColor3 = Theme.PAPER
	text.TextScaled = true
	text.Text = ("Need %d %s"):format(rebirths, if rebirths == 1 then "Rebirth" else "Rebirths")
	text.Parent = inset

	gui.Parent = leaf
	return gui
end

-- A CROSS WALL WITH A DOORWAY IN IT: two wall panels, a header, the wall
-- above it up into the vault, a rib over the lot, columns flanking the
-- opening on the far side, and two leaves that meet in the middle.
--
-- THE LEAVES ARE THE ONLY THING IN THIS ROOM THAT COLLIDES CONDITIONALLY, and
-- that is the lock: a locked room is locked because you cannot walk through
-- the leaf, not because something is polling where you are. The header and
-- the wall over it are solid too, so a shut door cannot be hopped --
-- `Config.jumpReach` is over two studs higher than anybody designing against
-- the feet expects.
local function buildCross(refs: Refs, parent: Instance, cross: Cross): Door
	local at = refs.origin
	local xc = cross.x
	local half = DOOR_W / 2

	-- The two panels either side of the opening, buried half a stud into the
	-- side walls so no face of theirs is a side wall's face -- and STANDING ON
	-- THE PLATFORM BRIDGE rather than running down through it: the arch's edge
	-- is over the platform, and a panel from the floor shared the bridge's
	-- own end planes across the whole band, eighteen pairs.
	for _, s in ipairs({ -1, 1 }) do
		local inner = half
		local outer = WIDTH / 2 + WALL / 2
		solid(parent, "Collide_Cross", Vector3.new(CROSS, WALL_H - PLATFORM_H, outer - inner),
			at * CFrame.new(xc, (WALL_H + PLATFORM_H) / 2, s * (inner + outer) / 2), STONE)
		-- Door frame, in the accent: a jamb STRADDLING the reveal, half on the
		-- panel and half into the opening, so it is the door stop the leaf
		-- hinges behind rather than a strip sharing the panel's own edge. Its
		-- foot sinks into the bridge it stands on.
		local jambH = DOOR_H + 0.6 - PLATFORM_H
		paint(refs, "accent", dress(parent, "Jamb", Vector3.new(CROSS + 0.4, jambH, JAMB_W),
			at * CFrame.new(xc, PLATFORM_H + jambH / 2 - SINK, s * half), refs.theme.accent))
	end
	-- The header across the opening, and the wall from it up into the vault.
	-- The header buries a stud into each panel; the slab above spans the whole
	-- hall and is a shade thinner than the panels so its faces are its own.
	paint(refs, "accent", solid(parent, "Collide_Header", Vector3.new(CROSS + 0.2, HEADER_T, DOOR_W + 2.0),
		at * CFrame.new(xc, DOOR_H + HEADER_T / 2, 0), refs.theme.accent))
	local slabTop = WALL_H + VAULT_RISE + VAULT_T
	local slabBottom = DOOR_H + HEADER_T
	solid(parent, "Collide_Tympanum", Vector3.new(CROSS - 0.2, slabTop - slabBottom, WIDTH + WALL * 2),
		at * CFrame.new(xc, (slabTop + slabBottom) / 2, 0), STONE)

	-- THE PLATFORMS CONTINUE THROUGH THE WALL. The door opens across them now,
	-- and the cross-wall band was floor-level between two 1.6 platforms -- a
	-- trench a player would drop into walking along the platform through an
	-- open door, and a step back up that is taller than a character climbs.
	-- Sized exactly to the band, so each face is a butt joint against the
	-- platform and step on either side.
	for _, s in ipairs({ -1, 1 }) do
		solid(parent, "Collide_Bridge", Vector3.new(CROSS, PLATFORM_H, PLATFORM_D),
			at * CFrame.new(xc, PLATFORM_H / 2, s * (WIDTH / 2 - PLATFORM_D / 2)), PLATFORM)
		local stepH = PLATFORM_H / 2
		solid(parent, "Collide_BridgeStep", Vector3.new(CROSS, stepH + SINK, STEP_D),
			at * CFrame.new(xc, (stepH - SINK) / 2, s * (WIDTH / 2 - PLATFORM_D - STEP_D / 2)),
			PLATFORM:Lerp(BLACK, 0.12))
	end

	-- The leaves. Shut, each spans from its jamb to the middle -- the FULL
	-- width of the arch, over the platforms too, so a locked door cannot be
	-- walked round along a platform. Open, IT SINKS INTO THE FLOOR: at this
	-- width a leaf swung a quarter turn is a seventeen-stud slab standing
	-- along the platform, hiding the very piggies the arch exists to show,
	-- and a leaf slid into a two-stud jamb has nowhere to go. Dropped clear
	-- below the slab it is simply gone, collision and label with it, and
	-- `setDoor` stays the one call that moves it.
	local leaves: { BasePart } = {}
	local labels: { SurfaceGui } = {}
	local shut: { CFrame } = {}
	local open: { CFrame } = {}
	local rebirths = Config.indoorDoorRebirths(cross.room) or 0
	for _, s in ipairs({ -1, 1 }) do
		local hinge = at * CFrame.new(xc, DOOR_H / 2, s * (half - JAMB_W / 2))
		local leaf = solid(parent, "DoorLeaf", Vector3.new(LEAF_T, DOOR_H - 0.3, LEAF),
			hinge * CFrame.new(0, 0, -s * LEAF / 2), refs.theme.accentDeep)
		leaf:SetAttribute("Room", cross.room)
		leaf:SetAttribute("Rebirths", rebirths)
		paint(refs, "accentDeep", leaf)
		table.insert(leaves, leaf)
		table.insert(labels, buildDoorLabel(leaf, rebirths))
		table.insert(shut, leaf.CFrame)
		table.insert(open, leaf.CFrame * CFrame.new(0, -(DOOR_H + 0.4), 0))
	end

	-- A column each side of the arch on the approach side, standing ON THE
	-- PLATFORM -- the arch's edge is over the platform now, so a column with
	-- its foot at floor level would stand buried to the waist. `LowPoly.
	-- column` is a column rather than a pipe -- a base and a capital -- and
	-- its `cf` is its FOOT, so it is placed on the platform top.
	for _, s in ipairs({ -1, 1 }) do
		LowPoly.column(parent, DOOR_H - PLATFORM_H + 0.9, 0.9,
			at * CFrame.new(xc - CROSS / 2 - 1.2, PLATFORM_H, s * (half + 0.7)),
			STONE, refs.theme.accent)
	end

	-- NO RIB OVER A CROSS WALL. The tympanum seals the vault above the door,
	-- so a rib there stands entirely inside it -- fifty-four buried parts,
	-- measured -- and the wall is its own break in the ceiling. Ribs cross the
	-- vault at the middle of each room instead, so every bay between a wall
	-- and a rib carries one fixture.

	return { room = cross.room, rebirths = rebirths, leaves = leaves, labels = labels,
		shut = shut, open = open, isOpen = false }
end

-- THE ENTRANCE BAY: the way out, the portal in it, and the achievement wall.
local function buildLobby(refs: Refs, parent: Instance)
	local at = refs.origin
	local endTop = WALL_H + VAULT_RISE + VAULT_T
	-- The end wall behind the exit, up into the vault.
	solid(parent, "Collide_EndWall", Vector3.new(WALL, endTop, WIDTH + WALL * 2),
		at * CFrame.new(-WALL / 2, endTop / 2, 0), STONE)

	-- `Door_Exit` IS A MOUNT NAME AND NOT A DOOR. Its `Size.Z` is the aperture
	-- `InteriorService.exitGate` reads and its `Size.Y` the headroom, and it
	-- stands short of the gate plane at `HOUSE_DOOR.exitReach`.
	local exit = dress(parent, "Door_Exit", Vector3.new(0.5, DOOR_H, 6.0),
		at * CFrame.new(0.3, DOOR_H / 2, 0), refs.theme.accentDeep)
	paint(refs, "accentDeep", exit)
	for _, s in ipairs({ -1, 1 }) do
		paint(refs, "accent", dress(parent, "ExitJamb", Vector3.new(0.9, DOOR_H + 0.6, 0.6),
			at * CFrame.new(0.45, (DOOR_H + 0.6) / 2 - SINK, s * 3.3), refs.theme.accent))
	end
	-- THE PEDIMENT IS TURNED A QUARTER: `LowPoly.pediment` spreads along its
	-- frame's own X, which is this hall's LENGTH -- handed the plain origin it
	-- laid a triangle down the corridor and out through the end wall.
	LowPoly.pediment(parent, 8.6, 0.6, DOOR_H + 0.6, 1.8, refs.theme.accent,
		at * CFrame.new(0.45, 0, 0) * CFrame.Angles(0, math.pi / 2, 0))

	-- The portal, standing in the doorway between the exit slab and the gate
	-- plane, so a character is inside it as they cross.
	refs.portal = HouseInterior.buildPortal(parent,
		at * CFrame.new(0.6 + PORTAL_DEPTH / 2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0),
		exit.Size.Z / 2 - 0.2, DOOR_H - 0.4)

	-- A low threshold just inside the door: `LowPoly.steps`, turned so its
	-- run lies along the hall and its width across it.
	LowPoly.steps(parent, 2, LANE, 1.1, 0.34, 0.0, 5.6, STONE_DEEP,
		at * CFrame.Angles(0, math.pi / 2, 0))

	-- THE ACHIEVEMENT WALL, ON THE LOBBY'S +Z SIDE, CENTRED ON IT.
	-- Nothing draws on this mount yet (the in-house room is retired; the
	-- achievements move into this base later). Its old reader measured the
	-- wall the mount stands on by walking `Collide_` parts for the nearest
	-- one behind it that is tall enough and contains the mount's x, so the
	-- lobby run is its own part and no room wall can be picked instead. That
	-- wall carries no grout, so nothing will cross the panels drawn on it.
	local mount = dress(parent, "Mount_Wall", Vector3.new(LOBBY - 4.0, 6.0, 0.3),
		at * CFrame.new(LOBBY / 2, WALL_H * 0.55, WIDTH / 2 - 0.15)
			* CFrame.Angles(0, math.pi, 0),
		STONE:Lerp(BLACK, 0.10))

	refs.exit = exit
	refs.mount = mount
end

-- ============================================================
-- THE PORTAL
-- ============================================================

--[[
	A block of light filling a doorway.

	`cframe` is the opening's threshold: its centre at FLOOR level, X across
	the opening, Y up, Z through it -- the same frame `Config.crossedDoorway`
	is written in, so the door agent can hand its gate frame straight in.
	`halfWidth` and `height` are the opening's; the block stands `height`
	tall from the threshold and `PORTAL_DEPTH` deep, centred on the plane.

	NEON, DEEP AMBER, PULSING. Deep because saturation is what survives the
	bloom (see `PORTAL` above). The pulse is `HouseFX`'s own `pulse` kind --
	client-side, tagged, and clamped by that module to well under three
	cycles a second -- so it costs the server nothing per frame and cannot be
	asked to strobe. It breathes between `Dim` and full rather than switching.

	NEVER COLLIDES AND NEVER ANSWERS A QUERY, so it cannot block the crossing
	it decorates or eat a raycast meant for the door.

	TAGGED AFTER PARENTING. `HouseFX` picks a part up from the tag's added
	signal, which does not fire for a tag added while the part is detached --
	`Decor.build` and the shop doors both paid for that. If the PARENT handed
	in is itself detached, the caller has to parent it before the animator can
	see this; `build` below does exactly that.

	Exported and NOT wired to the house side from here: `InteriorService`
	owns the door anchor and calls this at it.
]]
function HouseInterior.buildPortal(parent: Instance, cframe: CFrame, halfWidth: number, height: number): BasePart
	-- SUNK A TENTH INTO THE THRESHOLD, the project convention: standing on it
	-- exactly, its underside shared the floor's plane with the lobby steps.
	local p = LowPoly.part(parent, "Portal",
		Vector3.new(halfWidth * 2, height, PORTAL_DEPTH),
		cframe * CFrame.new(0, height / 2 - SINK, 0),
		PORTAL, Enum.Material.Neon)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 0.1
	p:SetAttribute("FX", "pulse")
	p:SetAttribute("Hue", PORTAL_HUE)
	p:SetAttribute("Sat", PORTAL_SAT)
	p:SetAttribute("Dim", 0.62)
	p:SetAttribute("Rate", 0.3)
	CollectionService:AddTag(p, "HouseFX")
	return p
end

-- ============================================================
-- BUILD
-- ============================================================

--[[
	Build the hall.

	`tier` is a row out of `Config.HOUSE_TIERS` -- what `Config.getShownHouse`
	hands back -- or nil for the starter; only its `trim` is read. `rooms`
	builds only that many rooms, defaulting to the whole ceiling.
]]
function HouseInterior.build(parent: Instance, at: CFrame, tier: any?, rooms: number?): Refs
	local ceiling = Config.indoorRoomCeiling()
	local count = math.clamp(math.floor(tonumber(rooms) or ceiling), 1, ceiling)

	local model = Instance.new("Model")
	model.Name = "HouseInterior"

	local refs: Refs = {
		model = model,
		origin = at,
		-- Past the gate plane, facing down the hall with a character's
		-- convention (LookVector = +X). `InteriorService` asserts both at boot.
		entrance = at * CFrame.new(6.0, 0, 0) * CFrame.Angles(0, -math.pi / 2, 0),
		plots = {},
		doors = {},
		rooms = count,
		capacity = 0,
		mount = nil :: any,
		exit = nil :: any,
		portal = nil :: any,
		painted = { accent = {}, accentDeep = {} },
		theme = HouseInterior.themeOf(tier),
	}

	local plan = layout(count)
	buildFloor(model, at, plan.length)
	buildVault(model, at, plan.length)
	buildLobby(refs, model)
	buildSideWall(refs, model, "Collide_Lobby", 0, LOBBY, 0, true, 1)
	buildFixture(refs, model, LOBBY / 2)

	for _, cross in ipairs(plan.crosses) do
		table.insert(refs.doors, buildCross(refs, model, cross))
	end

	local per = Config.INDOOR_ROOM_PLOTS
	for _, room in ipairs(plan.rooms) do
		buildSideWall(refs, model, "Collide_Room", room.x0, room.x1, PLATFORM_H, true)
		buildPlatforms(model, at, room.x0, room.x1)
		-- A rib across the middle of the room and a fixture in each half, so
		-- every rib bay -- rib to cross wall, cross wall to rib -- carries a
		-- light of its own.
		local len = room.x1 - room.x0
		buildRib(refs, model, room.x0 + len / 2)
		buildFixture(refs, model, room.x0 + len * 0.25)
		buildFixture(refs, model, room.x0 + len * 0.75)

		local made = 0
		for i = 1, room.along do
			for _, s in ipairs({ -1, 1 }) do
				if made < room.plots then
					made += 1
					local index = (room.index - 1) * per + made
					table.insert(refs.plots,
						buildPlot(refs, model, index, room.index, room.x0 + (i - 0.5) * PLOT_PITCH, s))
				end
			end
		end
	end

	-- The far end wall, up into the vault, on the room actually built.
	local endTop = WALL_H + VAULT_RISE + VAULT_T
	solid(model, "Collide_FarWall", Vector3.new(WALL, endTop, WIDTH + WALL * 2),
		at * CFrame.new(plan.length + WALL / 2, endTop / 2, 0), STONE)

	model.Parent = parent
	-- AFTER PARENTING: the portal's tag was added while the model was
	-- detached, so the animator's added-signal never saw it. Re-tagging a
	-- tagged part is a no-op on the tag and DOES raise the signal now the part
	-- is in the world -- the same walk `House.build` makes for its FX parts.
	CollectionService:RemoveTag(refs.portal, "HouseFX")
	CollectionService:AddTag(refs.portal, "HouseFX")
	HouseInterior.setCapacity(refs, 0)
	return refs
end

-- ============================================================
-- STATE
-- ============================================================

-- How many plots are standing, and therefore which doors are open. ONE
-- NUMBER IN, BOTH ANSWERS OUT: a caller passes `Config.indoorPlots(rebirths)`
-- and never decides either half itself.
function HouseInterior.setCapacity(refs: Refs, plots: number)
	local cap = math.max(0, math.floor(tonumber(plots) or 0))
	refs.capacity = cap
	for _, plot in ipairs(refs.plots) do
		local unlocked = plot.index <= cap
		plot.unlocked = unlocked
		plot.face.Color = if unlocked then PLOT_OPEN else PLOT_LOCKED
	end
	local openRooms = Config.indoorRooms(cap)
	for _, door in ipairs(refs.doors) do
		HouseInterior.setDoor(door, openRooms >= door.room)
	end
end

-- Open or shut one door. Separate from `setCapacity` because a pursuing
-- officer routed through a door will want to open one for the length of a
-- chase without touching what a player owns.
function HouseInterior.setDoor(door: Door, open: boolean)
	door.isOpen = open
	for i, leaf in ipairs(door.leaves) do
		leaf.CFrame = if open then door.open[i] else door.shut[i]
		-- THE COLLISION IS THE LOCK, so it moves with the leaf.
		leaf.CanCollide = not open
		-- And the label is the lock's own text, so it goes with it.
		local label = door.labels[i]
		if label then
			label.Enabled = not open
		end
	end
end

-- Repaint the accent for a house tier. Never rebuilds: whatever is standing
-- on the plots is welded to geometry a caller holds a reference to.
function HouseInterior.dress(refs: Refs, tier: any?)
	local theme = HouseInterior.themeOf(tier)
	refs.theme = theme
	for slot, list in pairs(refs.painted) do
		local colour = (theme :: any)[slot]
		for _, p in ipairs(list :: { BasePart }) do
			p.Color = colour
		end
	end
	HouseInterior.setCapacity(refs, refs.capacity)
end

function HouseInterior.plotGround(refs: Refs, index: number): CFrame?
	local plot = refs.plots[index]
	return if plot then plot.ground else nil
end

-- How much room one hall takes up, for whoever lays them out off-map.
-- DERIVED, because the length is a function of the rebirth ladder and the
-- width of the reference's proportions: a pinned footprint puts two halls
-- through each other the first time either moves, with nothing in any log.
-- The vault's arc -- radius, half-angle, centre height -- for whoever checks
-- the facets against it. See `vaultArc`.
function HouseInterior.vaultArc(): (number, number, number)
	return vaultArc()
end

function HouseInterior.footprint(): Vector3
	local plan = layout(Config.indoorRoomCeiling())
	return Vector3.new(plan.length + WALL * 2, WALL_H + VAULT_RISE + VAULT_T + FLOOR_T, WIDTH + WALL * 2)
end

return HouseInterior
