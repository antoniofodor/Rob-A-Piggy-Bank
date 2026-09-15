--!strict
--[[
	LowPoly

	The shared low-poly vocabulary: tiled roofs, framed windows, quoins,
	columns, steps, parapets and pediments.

	----------------------------------------------------------------------

	IT LIVES HERE BECAUSE TWO FILES BUILD IN IT, AND THE SECOND ONE ARRIVED
	AFTER THE FIRST.

	Every one of these was written for `House.luau` during the nine-tier
	rebuild and stayed private to it, which was right for as long as houses
	were the only things on this street built that way. Then the shops were
	rebuilt in the same style -- and they stand on the verge, sixty studs from
	the houses, with nothing between them.

	Copying the toolkit across would have been the near-identical duplicate
	this project keeps recording: the mini piggy, `Decor.buildOne`, and
	`RideSound` keeping its own copy of the ride-key grammar and breaking
	within the hour. It is worse here than usual, because the whole POINT of
	the shop rebuild is that a shop and a house look like they come from the
	same world. Two copies of the vocabulary are two ways for that to stop
	being true, silently, the first time either is touched.

	So the code MOVED rather than being copied. `House.luau` keeps one-line
	wrappers passing its own build folder, so not one of the nine tier
	builders changed and every measurement recorded against them still holds.

	----------------------------------------------------------------------

	EVERY FUNCTION TAKES ITS PARENT FIRST.

	`House` builds into a Model it makes per house; `ShopFront` builds into a
	Model it makes per unit. There is no ambient folder either could share,
	and a module-level one would be state two callers could race. The parent
	is an argument, which is the only version that cannot go stale.

	The reasoning under each function is kept verbatim from the house pass --
	it is a record of what was measured and what was got wrong on the way, and
	it is worth more than the code.
]]

local LowPoly = {}

-- The structural colours: what timber, stone and lit glass look like, as
-- opposed to a tier's own walls/roof/trim, which are what make one building
-- differ from the next.
local TIMBER = Color3.fromRGB(84, 58, 44)
local STONE = Color3.fromRGB(152, 148, 140)
-- DEEP ON PURPOSE. Neon renders a colour flat out and the BloomEffect in
-- WorldService takes it from there, so a PALE warm tint is not a warm window,
-- it is a white hole -- the same trap recorded for the first Martian skin,
-- which blew the piggy, the lawn and the fence into one white mass. Measured
-- on the first build: (255, 206, 122) rendered as flat white panes with no
-- hue left in them at all. A saturated amber still reads as lit and keeps
-- being amber at full brightness.
local WARM_GLASS = Color3.fromRGB(236, 158, 46)

-- Daylight glass: what a window reads as when it is NOT lit. `framedWindow`
-- is the only thing that wants it, which is why it travelled with it.
local GLASS = Color3.fromRGB(158, 196, 214)

LowPoly.GLASS = GLASS
LowPoly.TIMBER = TIMBER
LowPoly.STONE = STONE
LowPoly.WARM_GLASS = WARM_GLASS

-- The one primitive everything here is made of. Nothing built by this module
-- collides, answers a raycast or casts a shadow: a house is a status symbol
-- and a shop is scenery, and neither may become cover in a chase or eat a
-- query meant for a piggy.
local function mkpart(parent: Instance, name: string, size: Vector3, cf: CFrame,
	color: Color3, material: Enum.Material): Part
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
	p.Parent = parent
	return p
end

LowPoly.part = mkpart


-- A ROOF LAID AS COURSES OF TILES, which is the detail that separates every
-- one of the reference houses from what this game shipped.
--
-- The bare wedge stays underneath as the SOLID -- tiles are laid proud of it
-- and overlap each other, so a gap between courses shows roof rather than
-- sky. Cheap insurance, and it is why the tiles can be thin.
--
-- The two slopes fall toward +Z and -Z, matching the `gable` helper above:
-- a WedgePart of Size(width, pitch, depth/2) is full height at its -Z edge.
-- A rotation of +theta about X drops a part own +Z edge, so the near slope
-- takes +theta and the far one takes -theta.
function LowPoly.tiledRoof(parent: Instance, width: number, depth: number, baseY: number, pitch: number,
	rows: number, tile: Color3, trim: Color3, at: CFrame)

	local half = depth / 2
	local slope = math.sqrt(pitch * pitch + half * half)
	local theta = math.atan2(pitch, half)

	-- The solid beneath, in a DARKENED VERSION OF THE TILE COLOUR rather than
	-- the timber colour. It is only ever seen through the gaps between
	-- courses, so it has to read as shadow under a tile -- painted timber
	-- brown, the whole roof reads as brown wherever the courses do not quite
	-- meet, which is exactly how this shipped the first time.
	-- Same +Z convention as `gable` above, and this copy inherited its bug:
	-- the courses were laid on the correct plane, rising to the ridge, while
	-- the wedge beneath them rose the other way and stood through them. That
	-- is why a roof with twelve verifiably proud, verifiably placed courses
	-- rendered as one flat slab of body colour.
	local body = tile:Lerp(Color3.new(0, 0, 0), 0.45)
	for _, dir in ipairs({ -1, 1 }) do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "RoofBody"
		wedge.Size = Vector3.new(width, pitch, half)
		wedge.CFrame = at * CFrame.new(0, baseY + pitch / 2, dir * depth / 4)
			* CFrame.Angles(0, if dir > 0 then math.pi else 0, 0)
		wedge.Anchored, wedge.CanCollide, wedge.CanQuery, wedge.CastShadow = true, false, false, false
		wedge.Color, wedge.Material = body, Enum.Material.SmoothPlastic
		wedge.Parent = parent
	end

	-- The courses. Each is 1.45 of a row deep so it laps the one below it,
	-- which is what makes a stepped edge rather than a flat sheet with lines
	-- drawn on it.
	local step = slope / rows
	-- Just over one course deep. The first pass used 1.45, which buried each
	-- lip half a course up under the one above it.
	local tileDepth = step * 1.16

	-- LIFTED ALONG THE SLOPE NORMAL, NOT ALONG WORLD Y, which is the whole
	-- reason the first build of this had no visible tiles at all.
	--
	-- The surface descends toward the eave as (0, -sin, +cos), so the outward
	-- normal is (0, cos, sin) -- it has a Z component, and a lift that ignores
	-- it is not perpendicular to the thing it is trying to stand proud of. At
	-- this pitch a 0.28 lift in world Y is only 0.20 along the normal, against
	-- a tile half-thickness of 0.225: every course sat just INSIDE the wedge,
	-- so the roof rendered as one flat slab of the body colour. Measured, not
	-- guessed -- the courses were built, they were simply buried.
	--
	-- Same family as the moat and the road: a detail part sits PROUD of the
	-- surface it decorates, and proud means along the normal.
	-- AND EACH COURSE STANDS PROUD OF THE ONE BELOW IT, WHICH IS THE HALF THAT
	-- ACTUALLY MAKES A TILED ROOF.
	--
	-- The first working version lifted every course by the SAME amount. That
	-- is geometrically fine and visually nothing: parallel slabs at one offset
	-- are COPLANAR, so six courses merge into a single flat plane and the
	-- overlaps cannot be seen. Measured -- all twelve tiles built, correctly
	-- placed, correctly alternating, and the roof still rendered as one sheet.
	--
	-- A real roof laps each course over the head of the one below, so the lift
	-- CLIMBS toward the ridge and every boundary leaves a lip. That lip is the
	-- whole read: it is what casts the little shadow line that says "tiles"
	-- rather than "ramp".
	local baseLift = 0.30
	local courseLift = 0.22

	for _, dir in ipairs({ -1, 1 }) do
		for i = 0, rows - 1 do
			-- Measured from the EAVE up, so the lowest course sits exactly on
			-- the roof edge however many rows are asked for.
			local along = step * (i + 0.5)
			local lift = baseLift + i * courseLift
			local y = baseY + math.sin(theta) * along + math.cos(theta) * lift
			local z = dir * (half - math.cos(theta) * along + math.sin(theta) * lift)
			local course = mkpart(parent, "RoofTile", Vector3.new(width + 0.12, 0.5, tileDepth),
				at * CFrame.new(0, y, z) * CFrame.Angles(dir * theta, 0, 0),
				tile, Enum.Material.SmoothPlastic)
			-- Alternate courses a shade apart. Flat colour carries no texture
			-- to break it up, so this has to be wide enough to SEE -- the
			-- first pass used 10% and read as one colour from the pavement.
			if i % 2 == 1 then
				course.Color = tile:Lerp(Color3.new(0, 0, 0), 0.20)
			else
				course.Color = tile:Lerp(Color3.new(1, 1, 1), 0.10)
			end
		end
	end

	-- The ridge cap along the top, and a fascia board at each eave.
	mkpart(parent, "Ridge", Vector3.new(width + 0.5, 0.85, 1.5),
		at * CFrame.new(0, baseY + pitch + 0.2, 0), trim, Enum.Material.SmoothPlastic)
	for _, dir in ipairs({ -1, 1 }) do
		mkpart(parent, "Fascia", Vector3.new(width + 0.5, 0.9, 0.55),
			at * CFrame.new(0, baseY - 0.2, dir * (half + 0.1)), trim, Enum.Material.SmoothPlastic)
	end

	-- Bargeboards up the gable ends, which is what gives the roof a drawn
	-- OUTLINE from the side -- the nearest thing to an ink line this engine
	-- offers, and most of why the reference roofs read as illustrations.
	-- Wide enough to genuinely CAP the courses rather than graze them. At 0.5
	-- wide sitting at width/2 + 0.28 the board's inner face landed 0.03 from
	-- the tile ends (which overhang by 0.06), which is inside the depth
	-- buffer's noise and reads as a flickering seam down the gable.
	for _, sx in ipairs({ -1, 1 }) do
		for _, dir in ipairs({ -1, 1 }) do
			mkpart(parent, "Barge", Vector3.new(0.7, 0.85, slope),
				at * CFrame.new(sx * (width / 2 + 0.10), baseY + pitch / 2, dir * depth / 4)
					* CFrame.Angles(dir * theta, 0, 0),
				trim, Enum.Material.SmoothPlastic)
		end
	end
end

-- A window that is a WINDOW: a frame, a sill, lit glass and a mullion cross.
-- The glass is Neon on purpose. There is no night in this game -- `ClockTime`
-- is pinned at 14.5 -- so a lit window is not about darkness, it is about the
-- house looking LIVED IN, and Neon is the one material that reads at full
-- strength in daylight. Every reference house has warm windows.
function LowPoly.framedWindow(parent: Instance, at: CFrame, w: number, h: number, trim: Color3,
	shutter: Color3?, unlit: boolean?)
	mkpart(parent, "WinFrame", Vector3.new(w + 1.0, h + 1.0, 0.45), at, trim, Enum.Material.SmoothPlastic)

	-- A LIT WINDOW IS THE EXCEPTION ON ANYTHING WITH MORE THAN A FEW OF THEM,
	-- AND THAT IS A MEASUREMENT RATHER THAN A PREFERENCE.
	--
	-- Neon renders flat out and the BloomEffect takes it from there, which is
	-- exactly right for the cottage's two windows and exactly wrong once a
	-- tier has eleven: photographed, the manor and the townhouse came out as
	-- rows of white-hot holes with the wall colour bleached between them --
	-- the same blowout this file already records for the first Martian skin
	-- and the palace's first lit colonnade, arriving a third time.
	--
	-- THE RULE IS THAT THE GROUND FLOOR IS LIT AND NOTHING ABOVE IT IS. It is
	-- one sentence, it is symmetric so it cannot fight the manor's and the
	-- palace's whole composition, it leaves the warmth exactly where somebody
	-- standing on the lawn is looking, and it leaves every tier above the
	-- cottage reading by its WALLS rather than by its windows.
	if unlit then
		mkpart(parent, "WinGlass", Vector3.new(w, h, 0.3), at * CFrame.new(0, 0, 0.16),
			GLASS, Enum.Material.SmoothPlastic)
	else
		mkpart(parent, "WinGlass", Vector3.new(w, h, 0.3), at * CFrame.new(0, 0, 0.16),
			WARM_GLASS, Enum.Material.Neon)
	end

	-- THE MULLIONS ARE SHORTER AND SHALLOWER THAN THE GLASS THEY CROSS, AND
	-- SIT AT TWO DIFFERENT DEPTHS.
	--
	-- Authored at exactly the glass's own width and height they shared its
	-- top, bottom and side planes -- four coplanar pairs per window -- and
	-- authored at one depth they shared both Z planes with EACH OTHER, right
	-- across the middle of the pane where the two meet. On a lit window that
	-- is the most visible surface on the building, and it is a large part of
	-- what read as the wood frame flickering.
	mkpart(parent, "MullionV", Vector3.new(0.28, h - 0.14, 0.36), at * CFrame.new(0, 0, 0.28),
		trim, Enum.Material.SmoothPlastic)
	mkpart(parent, "MullionH", Vector3.new(w - 0.14, 0.28, 0.28), at * CFrame.new(0, 0, 0.21),
		trim, Enum.Material.SmoothPlastic)

	mkpart(parent, "Sill", Vector3.new(w + 1.8, 0.42, 0.9),
		at * CFrame.new(0, -(h + 1.0) / 2 - 0.05, 0.2),
		trim, Enum.Material.SmoothPlastic)

	-- SHUTTERS ARE OPTIONAL AND ARE THE CHEAPEST CHARACTER IN THIS FILE.
	-- A board each side with three slats on it triples the number of hard
	-- edges around a window for six parts, which is exactly the trade the
	-- reference art keeps making: SILHOUETTE detail rather than SURFACE
	-- detail, because flat colour has no surface to put anything on.
	if shutter then
		local boardW, boardH = 1.9, h + 0.9
		local bx = (w + 1.0) / 2 + boardW / 2 - 0.05
		for _, sx in ipairs({ -1, 1 }) do
			-- 0.16 rather than 0.10: at 0.10 the board's back face landed
			-- 0.015 from the frame's own, which is inside the depth buffer's
			-- noise and reads as a flickering line down both sides of every
			-- shuttered window.
			mkpart(parent, "Shutter", Vector3.new(boardW, boardH, 0.62),
				at * CFrame.new(sx * bx, 0, 0.16), shutter, Enum.Material.SmoothPlastic)
			for i = -1, 1 do
				-- Standing 0.19 past the board's own face and narrower than it
				-- on both other axes, so nothing here shares a plane with the
				-- board it is nailed to.
				-- 0.34 tall, not 0.26: the middle slat sits on the window's
				-- centreline and at 0.26 its bottom face was 0.01 from the
				-- horizontal mullion's.
				mkpart(parent, "Slat", Vector3.new(boardW - 0.5, 0.34, 0.5),
					at * CFrame.new(sx * bx, i * boardH * 0.26, 0.35),
					shutter:Lerp(Color3.new(0, 0, 0), 0.22), Enum.Material.SmoothPlastic)
			end
		end
	end
end

-- A ROW OF FRAMED WINDOWS ACROSS A FRONTAGE. Every rebuilt tier with more
-- than two windows goes through this, so the spacing rule and the
-- leave-room-for-the-door rule are decided once rather than per builder.
function LowPoly.windowBand(parent: Instance, at: CFrame, span: number, y: number, z: number,
	count: number, w: number, h: number, trim: Color3, skipMiddle: boolean,
	shutter: Color3?, unlit: boolean?)
	-- THE COUNT IS A CEILING, NOT A PROMISE, AND THAT IS WHAT STOPS A BAND
	-- EATING ITSELF.
	--
	-- A window is far wider than its glass: the sill oversails by 0.9 each
	-- side, and a pair of shutters adds another 1.45. Spacing on `w` alone
	-- therefore overlaps the sills long before it overlaps the panes -- which
	-- is a coplanar pair AND, worse, two sills merging into one long ledge
	-- with the windows apparently sharing it. Measured on the first build of
	-- the manor: five windows over a 26-stud span put every frame through its
	-- neighbour, four pairs a rank, on both upper floors.
	--
	-- Solved here rather than at the call sites because the widest part of a
	-- window is a fact about `framedWindow`, and a caller counting studs is a
	-- caller who will be wrong the next time a sill grows.
	local widest = (if shutter then w + 4.7 else w + 1.8) + 0.4
	count = math.max(1, math.min(count, math.floor(span / widest) - 1))
	for i = 1, count do
		local x = -span / 2 + (span / (count + 1)) * i
		if not (skipMiddle and math.abs(x) < w) then
			LowPoly.framedWindow(parent, at * CFrame.new(x, y, z), w, h, trim, shutter, unlit)
		end
	end
end

-- CORNER QUOINS: alternating blocks up every corner of a building.
--
-- This is the cheapest thing in the file that reads as DRAWN. The reference
-- art gets its corners from an ink outline, which this engine will not give
-- you; a hard vertical line of a second colour where two flat walls meet is
-- the nearest equivalent, and without one a flat-shaded building is a box
-- whose corners disappear whenever the two faces catch the sun equally.
--
-- The alternation is not decoration either: blocks all one size read as a
-- pilaster stuck on the corner, where long/short/long reads as masonry.
-- `skipFront` leaves the +Z pair off, which a SHOP wants and a house does
-- not. A house is a box seen from the street and its front corners are
-- corners; a shopfront is a composed thing -- piers, glazing, a stall riser --
-- and a quoin standing in the middle of it is masonry growing through a
-- window. The houses pass nothing and get all four, exactly as measured.
function LowPoly.quoins(parent: Instance, w: number, d: number, baseY: number, height: number,
	colour: Color3, at: CFrame, skipFront: boolean?)
	local rows = math.max(3, math.floor(height / 2.8))
	local block = height / rows
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs(if skipFront then { -1 } else { -1, 1 }) do
			for i = 0, rows - 1 do
				local long = (i % 2 == 0)
				local ex = if long then 2.6 else 1.6
				local ez = if long then 1.6 else 2.6
				-- 0.18 proud on BOTH axes. Sized flush they would land their
				-- outer faces in the wall's own side planes, which is the fault
				-- the cottage's corner posts shipped with.
				mkpart(parent, "Quoin", Vector3.new(ex, block * 0.84, ez),
					at * CFrame.new(sx * (w / 2 + 0.18 - ex / 2), baseY + block * (i + 0.5),
						sz * (d / 2 + 0.18 - ez / 2)),
					colour, Enum.Material.SmoothPlastic)
			end
		end
	end
end

-- A COLUMN WITH A BASE AND A CAPITAL, which is the whole difference between
-- a column and a pipe. `cf` is its FOOT, so a caller places it on whatever it
-- is standing on rather than solving for a centre.
--
-- The shaft stops 0.4 short at each end and the two blocks cover the gap, so
-- the cylinder's flat cap never shares a plane with the block sitting on it.
function LowPoly.column(parent: Instance, height: number, diameter: number, cf: CFrame, shaft: Color3, trim: Color3)
	local shaftLen = height - 0.8
	local body = mkpart(parent, "ColumnShaft", Vector3.new(shaftLen, diameter, diameter),
		cf * CFrame.new(0, 0.4 + shaftLen / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		shaft, Enum.Material.SmoothPlastic)
	body.Shape = Enum.PartType.Cylinder
	local block = diameter * 1.34
	mkpart(parent, "ColumnBase", Vector3.new(block, 0.9, block), cf * CFrame.new(0, 0.45, 0),
		trim, Enum.Material.SmoothPlastic)
	mkpart(parent, "ColumnCap", Vector3.new(block * 0.94, 1.0, block * 0.94),
		cf * CFrame.new(0, height - 0.5, 0), trim, Enum.Material.SmoothPlastic)
end

-- A FLIGHT OF STEPS, widest at the bottom, front edge receding as it climbs.
--
-- The obvious construction gives every tread one shared front plane and one
-- shared back plane, which is `count` coplanar pairs on the part of a house
-- somebody stands directly in front of. Here the fronts step back with the
-- climb and the widths shrink, so the only shared plane left is the BACK --
-- and adjacent treads meet there along a line rather than over an area,
-- which is not an overlap.
function LowPoly.steps(parent: Instance, count: number, width: number, tread: number, riser: number,
	baseY: number, zFront: number, colour: Color3, at: CFrame)
	local back = zFront - tread * (count + 1)
	for i = 0, count - 1 do
		local f = zFront - i * tread
		local dd = f - back
		mkpart(parent, "Step", Vector3.new(width + (count - 1 - i) * 1.4, riser, dd),
			at * CFrame.new(0, baseY + riser * (i + 0.5), (f + back) / 2),
			colour, Enum.Material.SmoothPlastic)
	end
end

-- A PARAPET RING round a flat roof: four coping runs standing proud of the
-- slab. The flat-roofed tiers have no gable to draw an outline with, so this
-- is where their hard top edge comes from. The side runs are a shade shorter
-- than the front and back so no two of the four share a top plane.
function LowPoly.parapet(parent: Instance, w: number, d: number, y: number, height: number, thick: number,
	colour: Color3, at: CFrame)
	for _, sz in ipairs({ -1, 1 }) do
		mkpart(parent, "Parapet", Vector3.new(w + thick * 2, height, thick),
			at * CFrame.new(0, y + height / 2, sz * (d / 2 + thick / 2)),
			colour, Enum.Material.SmoothPlastic)
	end
	for _, sx in ipairs({ -1, 1 }) do
		mkpart(parent, "Parapet", Vector3.new(thick, height * 0.94, d),
			at * CFrame.new(sx * (w / 2 + thick / 2), y + height * 0.47, 0),
			colour, Enum.Material.SmoothPlastic)
	end
end

-- A PLAIN PITCHED CAP: two wedges, no courses.
--
-- `tiledRoof` is right for a building and far too many parts for a dormer or
-- a bay window -- fifteen against two, on something four studs across where
-- nobody could resolve a course anyway. `gable` would do the geometry and is
-- deliberately left alone: it is what the eight ORIGINAL builders still stand
-- on, and it hardcodes Slate and the tier's own roof colour.
function LowPoly.capRoof(parent: Instance, width: number, depth: number, baseY: number, pitch: number,
	colour: Color3, at: CFrame)
	for _, dir in ipairs({ -1, 1 }) do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Cap"
		wedge.Size = Vector3.new(width, pitch, depth / 2)
		wedge.CFrame = at * CFrame.new(0, baseY + pitch / 2, dir * depth / 4)
			* CFrame.Angles(0, if dir > 0 then math.pi else 0, 0)
		wedge.Anchored, wedge.CanCollide, wedge.CanQuery, wedge.CastShadow = true, false, false, false
		wedge.Color, wedge.Material = colour, Enum.Material.SmoothPlastic
		wedge.Parent = parent
	end
end

-- A PEDIMENT: the triangle over a portico, as two wedges meeting at an apex.
--
-- `gable` cannot make one, and it is worth being exact about why because they
-- look like the same object. A roof slopes across DEPTH and is as wide as the
-- building; a pediment slopes across WIDTH and is a hand thick. The turn is a
-- quarter about Y, which is what puts a WedgePart's full-height +Z edge onto
-- world X -- the left half takes +90 so its tall edge lands at the centre,
-- and the right half takes -90 for the same reason mirrored.
function LowPoly.pediment(parent: Instance, width: number, thickness: number, baseY: number, rise: number,
	colour: Color3, at: CFrame)
	for _, sx in ipairs({ -1, 1 }) do
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Pediment"
		wedge.Size = Vector3.new(thickness, rise, width / 2)
		wedge.CFrame = at * CFrame.new(sx * width / 4, baseY + rise / 2, 0)
			* CFrame.Angles(0, sx * -math.pi / 2, 0)
		wedge.Anchored, wedge.CanCollide, wedge.CanQuery, wedge.CastShadow = true, false, false, false
		wedge.Color, wedge.Material = colour, Enum.Material.SmoothPlastic
		wedge.Parent = parent
	end
end

return LowPoly
