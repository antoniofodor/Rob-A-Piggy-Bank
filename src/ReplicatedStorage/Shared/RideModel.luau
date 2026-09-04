--!strict
--[[
	RideModel

	What each ride looks like, built once and used from both sides -- the board
	under a player's feet on the street (server) and the tile in the shop
	(client, inside a ViewportFrame). Same reason PigGear and BoneModel are
	shared: two builders drift, and a shop picture that does not match the
	thing you end up riding is worse than no picture.

	THE AUTHORING CONTRACT, and it is not the same as PigGear's.

	Every ride is built facing +Z with y = 0 AT THE GROUND -- the underside of
	the wheels. That is the one point placement has to be right about: RideService seats a ride on the
	floor under the character, and a model authored around its own visual
	centre would sink half a wheel into the tarmac. It is the same principle as
	the accessory pivot rule (a hat is authored at its brim so it can sit ON a
	head) applied to the other end of the body.

	The shop icon wants the visual centre instead and computes it for itself in
	makeModelIcon, which re-centres its own copy.

	Nothing here collides or answers a raycast, and every part is Massless.
	A ride is welded to a moving character: give it mass and it changes how the
	character walks, give it collision and it catches on the kerb.

	NO NAMED BRANDS. The scrambler is the genre -- a stubby, torquey electric
	dirt bike -- and not any manufacturer's, for exactly the reason the lawn
	ornaments are originals: Roblox moderation strips branded assets and the
	penalty lands on the experience rather than the one item.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local RideModel = {}

type Add = (name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?) -> Part

-- Roblox cylinders have their flat faces on X.
--
-- For anything facing +Z that means a WHEEL needs no rotation at all -- X is
-- already the axle direction -- while a POST has to be turned onto Y. Written
-- the wrong way round a post becomes a disc as wide as it was tall, which is
-- the single most repeated bug in this project.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local TYRE = Color3.fromRGB(28, 28, 32)
local STEEL = Color3.fromRGB(178, 182, 190)
local DARK_STEEL = Color3.fromRGB(84, 88, 96)
local GRIP = Color3.fromRGB(38, 38, 42)
-- Darker than TYRE on purpose: tread standing 0.06 proud of a carcass the
-- same colour as itself is 0.06 of nothing.
local TREAD = Color3.fromRGB(16, 16, 20)

local builders: { [string]: (any, Add) -> () } = {}

-- A wheel: axle along X, so no rotation. `thickness` is the tyre's width.
local function wheel(add: Add, x: number, y: number, z: number, radius: number,
	thickness: number, rim: Color3?)
	local tyre = add("Tyre", Vector3.new(thickness, radius * 2, radius * 2),
		CFrame.new(x, y, z), TYRE)
	tyre.Shape = Enum.PartType.Cylinder

	if rim then
		local hub = add("Rim", Vector3.new(thickness + 0.06, radius * 1.05, radius * 1.05),
			CFrame.new(x, y, z), rim, Enum.Material.Metal)
		hub.Shape = Enum.PartType.Cylinder
	end
end

-- A round bar standing on Y.
local function post(add: Add, size: number, height: number, cf: CFrame,
	colour: Color3, material: Enum.Material?)
	local p = add("Tube", Vector3.new(height, size, size), cf * UPRIGHT, colour, material)
	p.Shape = Enum.PartType.Cylinder
end

-- ============================================================
-- THE RIDES
-- ============================================================

-- A popsicle trick deck: narrow, rounded at both ends, kicked at both ends.
--
-- The first version was a plank with two slabs floating off the tips, and it
-- was wrong three ways at once. It was far too wide for its length (2.9:1
-- against a real board's 4:1, which reads as a longboard offcut); the kicks
-- were separate blocks with a visible seam instead of the deck itself turning
-- up; and both of them were angled the WRONG WAY, so the nose and tail drooped
-- at the road. That last one is pure CFrame.Angles bookkeeping: rotating about
-- +X sends the part's +Z end DOWN, so the tip at +z needs a NEGATIVE angle to
-- lift and the tip at -z a positive one. It had the sign the other way round
-- on both.
builders.skateboard = function(spec, add)
	local WHEEL_R = 0.33
	local DECK_Y = 0.92
	local WIDTH = 1.5
	-- Roughly 4.9 studs end to end, against 6.9 on the first rewrite.
	--
	-- A real deck is 4:1, and building it at 4:1 was the mistake: at this scale
	-- a board long enough to be proportionally correct reads as a longboard
	-- under a Roblox character, whose own feet are barely a stud apart. 3.3:1
	-- is what looks like a trick board here. Stylised beats accurate when the
	-- two disagree and only one of them is visible.
	local FLAT = 2.7           -- the wheelbase section, between the two kicks
	local KICK_LEN = 1.15
	-- Shallower than a real board's kick. At 19 degrees the nose and tail
	-- turned up hard enough to read as a banana, because at this scale the
	-- deck is short and the same angle covers proportionally more of it.
	local KICK = math.rad(11)
	local URETHANE = Color3.fromRGB(238, 236, 226)

	-- Wheels and trucks first: the deck sits where the wheels put it, rather
	-- than at a guessed ride height. Urethane, not the board's trim colour --
	-- skate wheels are cream or white, and tinting them to match the graphic
	-- was most of why this read as a toy.
	-- Wheelbase, as a fraction of the deck: 2.44 of 4.96, just under half. A
	-- real board is nearer 44%, but the trucks sat visibly bunched at that
	-- ratio here because the deck is short and the wheels are proportionally
	-- large.
	for _, sz in ipairs({ 1.22, -1.22 }) do
		for _, sx in ipairs({ 0.66, -0.66 }) do
			-- ONE cylinder per wheel, not two.
			--
			-- This used to call the shared `wheel` helper -- which lays down a
			-- black tyre -- and then put a white urethane wheel at the same
			-- centre with the same radius. Two coincident cylinders 0.02 apart
			-- in thickness is the coplanar case: the renderer has nothing to
			-- sort by, so the black underneath came through the white in
			-- patches and read as a broken texture. Skate wheels have no tyre
			-- on them anyway.
			local w = add("Wheel", Vector3.new(0.44, WHEEL_R * 2, WHEEL_R * 2),
				CFrame.new(sx, WHEEL_R, sz), URETHANE)
			w.Shape = Enum.PartType.Cylinder
		end
		-- Hanger: the cast axle housing, wider than the deck so the wheels
		-- clear it. Baseplate and kingpin bolt it to the underside.
		local hanger = add("Hanger", Vector3.new(1.34, 0.42, 0.42),
			CFrame.new(0, WHEEL_R + 0.03, sz), STEEL, Enum.Material.Metal)
		hanger.Shape = Enum.PartType.Cylinder
		add("Axle", Vector3.new(1.7, 0.14, 0.14), CFrame.new(0, WHEEL_R, sz), DARK_STEEL, Enum.Material.Metal)
		add("Baseplate", Vector3.new(1.15, 0.14, 1.0), CFrame.new(0, DECK_Y - 0.13, sz),
			DARK_STEEL, Enum.Material.Metal)
		add("Kingpin", Vector3.new(0.5, 0.34, 0.5),
			CFrame.new(0, DECK_Y - 0.34, sz + (if sz > 0 then -0.28 else 0.28)),
			STEEL, Enum.Material.Metal)
	end

	-- The flat middle of the deck, plus grip tape over it.
	add("Deck", Vector3.new(WIDTH, 0.17, FLAT), CFrame.new(0, DECK_Y, 0), spec.colour)
	add("Grip", Vector3.new(WIDTH - 0.06, 0.05, FLAT), CFrame.new(0, DECK_Y + 0.11, 0), GRIP)

	-- Nose and tail. Each one is the deck CONTINUING upward from the end of
	-- the flat, hinged at that seam, so there is no step between them: the
	-- centre is placed half a kick along the rotated direction from the joint.
	for _, sz in ipairs({ 1, -1 }) do
		local joint = sz * FLAT / 2
		-- Negative at the +z end, positive at the -z end. Rotating about +X
		-- drives +Z downward, so the sign has to flip per end to make both
		-- tips rise.
		local pitch = CFrame.Angles(-sz * KICK, 0, 0)

		-- The straight part of the kick STOPS where the round tip starts.
		--
		-- It used to run the full length with the disc laid over its last half,
		-- which rounded nothing: a box is full width at every z, so its two
		-- square corners sat right on the widest point of the circle and stuck
		-- out past it. Ending the box at the disc's centre leaves rectangle
		-- then semicircle, which is the popsicle outline.
		local straight = KICK_LEN - WIDTH / 2
		local boxZ = joint + sz * math.cos(KICK) * straight / 2
		local boxY = DECK_Y + math.sin(KICK) * straight / 2

		add("Kick", Vector3.new(WIDTH, 0.17, straight), CFrame.new(0, boxY, boxZ) * pitch, spec.colour)
		add("KickGrip", Vector3.new(WIDTH - 0.06, 0.05, straight),
			CFrame.new(0, boxY, boxZ) * pitch * CFrame.new(0, 0.11, 0), GRIP)

		-- The round end: a disc the width of the deck, laid flat and carried
		-- up on the same pitch. Its centre is the far end of the straight, so
		-- its outer edge lands exactly where the kick was always going to end
		-- and the overall length is unchanged.
		local discZ = joint + sz * math.cos(KICK) * straight
		local discY = DECK_Y + math.sin(KICK) * straight
		local tip = add("Tip", Vector3.new(0.17, WIDTH, WIDTH),
			CFrame.new(0, discY, discZ) * pitch * UPRIGHT, spec.colour)
		tip.Shape = Enum.PartType.Cylinder
		local tipGrip = add("TipGrip", Vector3.new(0.05, WIDTH - 0.06, WIDTH - 0.06),
			CFrame.new(0, discY, discZ) * pitch * CFrame.new(0, 0.11, 0) * UPRIGHT, GRIP)
		tipGrip.Shape = Enum.PartType.Cylinder
	end
end

-- THE RIDER IS THE SPEC. Every contact point here was measured off a posed
-- R15 rig, not chosen -- see RidePose.
--
-- The old bike was authored at real BMX proportions: 2.5-stud wheels, a
-- 4.3-stud wheelbase, saddle at 3.63 and bars at 3.85. Measured against a
-- character sitting on it, that bike is unrideable and no animation could
-- have fixed it. The saddle sat 1.5 studs BEHIND the rider's hips and 0.89
-- ABOVE their pelvis, and the span from saddle to grips was 3.35 studs
-- against an arm that reaches 2.10 -- so a rider could sit down or hold on,
-- never both. Dropping the rider onto the saddle instead put the pedals 2.5
-- studs below a leg 1.5 studs long.
--
-- None of that is a bug in the bike; it is the rig. A Roblox character is
-- five studs tall with short legs and shorter arms, so a bicycle at honest
-- proportions is simply too big for one. This is the same call the deck above
-- already made -- stylised beats accurate when the two disagree and only one
-- of them is visible -- except here what is visible is a child sitting on it.
--
-- So the wheels and the frame are sized to fit the CONTACTS rather than the
-- other way round:
--
--     grips   (+-1.74, 2.645, 1.12)     the hands, converted to model space
--     saddle   top y 2.225 at z -0.43   the pelvis, resting on it
--     pedals  (+-0.35, 0.387 top, 0.52) the feet
--
-- and `stand` is 0 for this ride, because a seated rider is held up by the
-- saddle rather than stood on the pedals. See the note in Config.
builders.bmx = function(spec, add)
	local WHEEL_R = 0.85
	local FRONT_Z, BACK_Z = 1.5, -1.62

	-- Contact points, from RidePose's measurements. Named rather than inlined
	-- because four other parts are positioned off them, and a hand-tuned bar
	-- height that drifts from the pose is a rider gripping thin air.
	local GRIP_X, GRIP_Y, GRIP_Z = 1.74, 2.645, 1.12
	local SADDLE_TOP, SADDLE_Z = 2.225, -0.43
	local PEDAL_X, PEDAL_TOP, PEDAL_Z = 0.35, 0.387, 0.52

	wheel(add, 0, WHEEL_R, FRONT_Z, WHEEL_R, 0.3, spec.trim)
	wheel(add, 0, WHEEL_R, BACK_Z, WHEEL_R, 0.3, spec.trim)

	-- Forks and stays. Thin boxes rather than angled cylinders: at this scale
	-- the lean reads and the axis bookkeeping does not earn its keep.
	for _, sx in ipairs({ 0.34, -0.34 }) do
		add("Fork", Vector3.new(0.14, 1.5, 0.34),
			CFrame.new(sx, WHEEL_R + 0.5, FRONT_Z - 0.14) * CFrame.Angles(math.rad(-14), 0, 0),
			spec.colour, Enum.Material.Metal)
		add("Stay", Vector3.new(0.14, 0.28, 1.7),
			CFrame.new(sx, WHEEL_R - 0.12, BACK_Z + 0.85) * CFrame.Angles(math.rad(10), 0, 0),
			spec.colour, Enum.Material.Metal)
	end

	-- Frame: down tube, top tube, seat tube. Three bars is the whole diamond,
	-- and all three now run between points the rider actually touches -- the
	-- bottom bracket, the head tube under the grips, and the saddle.
	add("DownTube", Vector3.new(0.2, 0.26, 2.0),
		CFrame.new(0, 1.15, 0.5) * CFrame.Angles(math.rad(26), 0, 0),
		spec.colour, Enum.Material.Metal)
	add("TopTube", Vector3.new(0.2, 0.24, 1.65),
		CFrame.new(0, 1.95, 0.28) * CFrame.Angles(math.rad(6), 0, 0),
		spec.colour, Enum.Material.Metal)
	post(add, 0.22, 1.2, CFrame.new(0, 1.62, SADDLE_Z), spec.colour, Enum.Material.Metal)

	-- Saddle. `SADDLE_TOP` is where the pelvis rests, so the part is seated
	-- half its own thickness below that rather than centred on it.
	local SADDLE_T = 0.24
	add("Saddle", Vector3.new(0.56, SADDLE_T, 1.15),
		CFrame.new(0, SADDLE_TOP - SADDLE_T / 2, SADDLE_Z), GRIP)

	-- Stem and bars, ending at the grips the hands were measured at. The stem
	-- runs from the head tube up to the bar, so its centre is the midpoint of
	-- that run rather than either end -- `post` takes a CENTRE, which the
	-- scooter's stem already learned the hard way.
	post(add, 0.22, 1.5, CFrame.new(0, GRIP_Y - 0.65, FRONT_Z - 0.24) * CFrame.Angles(math.rad(-12), 0, 0),
		STEEL, Enum.Material.Metal)
	add("Bars", Vector3.new(GRIP_X * 2, 0.2, 0.2), CFrame.new(0, GRIP_Y, GRIP_Z), STEEL, Enum.Material.Metal)
	-- The crossbar that makes it read as BMX rather than as a road bike.
	add("BarBrace", Vector3.new(1.0, 0.14, 0.14), CFrame.new(0, GRIP_Y + 0.2, GRIP_Z + 0.16),
		STEEL, Enum.Material.Metal)
	for _, sx in ipairs({ GRIP_X, -GRIP_X }) do
		add("Grip", Vector3.new(0.46, 0.26, 0.26), CFrame.new(sx, GRIP_Y, GRIP_Z), spec.accent)
	end

	-- Cranks and pedals at the bottom bracket. PEDAL_TOP is the surface the
	-- sole sits on, so again the part hangs below it.
	local PEDAL_T = 0.13
	post(add, 0.3, 0.72, CFrame.new(0, PEDAL_TOP + 0.34, PEDAL_Z) * CFrame.Angles(0, 0, math.rad(90)),
		DARK_STEEL, Enum.Material.Metal)
	for _, sx in ipairs({ PEDAL_X, -PEDAL_X }) do
		add("Crank", Vector3.new(0.1, 0.5, 0.16), CFrame.new(sx * 0.7, PEDAL_TOP + 0.3, PEDAL_Z),
			DARK_STEEL, Enum.Material.Metal)
		add("Pedal", Vector3.new(0.6, PEDAL_T, 0.36),
			CFrame.new(sx, PEDAL_TOP - PEDAL_T / 2, PEDAL_Z), GRIP)
	end
end

builders.scooter = function(spec, add)
	local WHEEL_R = 0.66
	local DECK_Y = 0.72
	local STEM_Z = 2.0

	wheel(add, 0, WHEEL_R, STEM_Z, WHEEL_R, 0.36, spec.trim)
	wheel(add, 0, WHEEL_R, -2.0, WHEEL_R, 0.36, spec.trim)

	add("Deck", Vector3.new(1.5, 0.3, 4.0), CFrame.new(0, DECK_Y, 0), spec.colour)
	add("Grip", Vector3.new(1.4, 0.06, 3.7), CFrame.new(0, DECK_Y + 0.18, 0), GRIP)

	-- The battery slung under the deck: the one part that says electric rather
	-- than kick scooter.
	add("Battery", Vector3.new(1.0, 0.34, 2.4), CFrame.new(0, DECK_Y - 0.3, -0.2),
		DARK_STEEL, Enum.Material.Metal)

	-- Stem, leaning back the way a scooter's does.
	--
	-- `post` takes the CENTRE of the tube, not its base. Written as a base
	-- this ran from the deck DOWN through the road -- a metre of handlebar
	-- buried in the tarmac -- and left a gap between the top of the stem and
	-- the bars it was supposed to be holding up.
	-- THE BARS SIT WHERE THE HANDS DO, not at a guessed height. Measured off
	-- the posed rider at (+-1.69, 3.47, 1.36) in model space; they used to be
	-- at y 4.35 and +-1.05, which is most of a stud above the grip and half a
	-- stud inboard of it -- a rider steering thin air with their arms at full
	-- stretch. See RidePose.
	local GRIP_X, GRIP_Y, GRIP_Z = 1.69, 3.47, 1.36

	post(add, 0.34, 3.0, CFrame.new(0, 2.0, STEM_Z + 0.02) * CFrame.Angles(math.rad(-9), 0, 0),
		STEEL, Enum.Material.Metal)
	add("Bars", Vector3.new(GRIP_X * 2, 0.24, 0.24), CFrame.new(0, GRIP_Y, GRIP_Z),
		STEEL, Enum.Material.Metal)
	for _, sx in ipairs({ GRIP_X, -GRIP_X }) do
		add("Grip", Vector3.new(0.5, 0.3, 0.3), CFrame.new(sx, GRIP_Y, GRIP_Z), spec.accent)
	end
	add("Display", Vector3.new(0.9, 0.44, 0.16), CFrame.new(0, GRIP_Y - 0.34, GRIP_Z - 0.1), spec.accent,
		Enum.Material.Neon)

	-- Rear fender over the back wheel, and a headlight at the top of the stem.
	add("Fender", Vector3.new(0.7, 0.16, 1.5), CFrame.new(0, WHEEL_R + 0.62, -2.0), spec.colour)
	add("Light", Vector3.new(0.5, 0.4, 0.22), CFrame.new(0, 2.75, STEM_Z + 0.05),
		Color3.fromRGB(255, 246, 214), Enum.Material.Neon)
end

-- The self-balancing two-wheeler, the kind actually sold as a "hoverboard":
-- a wheel on each side, two foot pads either side of a centre pivot, and you
-- stand on it FACING FORWARD and lean to go.
--
-- The first version was a floating snowboard -- long front-to-back, no wheels,
-- thrusters underneath -- which is the film's hoverboard, not the shop's. The
-- difference is the axis: this one is WIDE and SHALLOW, 5.6 studs across the
-- axle against 2.4 front to back, because the rider's feet sit side by side
-- between the wheels rather than one behind the other.
--
-- That also means no rotation on the wheels. A Roblox cylinder's flat faces
-- are already on X, and on this machine X is the axle, so the wheels are the
-- one part of the whole file that needs no turning at all.
-- ALIEN SET. A disc rather than a plank, and no wheels at all -- the whole
-- point of the silhouette is that nothing touches the road.
--
-- TWO NUMBERS ARE INHERITED AND MUST NOT BE TOUCHED: the standing surface at
-- 0.88 and the foot pads at +-1.08. `POSES.hoverdisc` is an alias of the
-- hoverboard's pose, and that pose was authored by posing a live rig and then
-- moving the BOARD to where the measured feet landed. Move either number here
-- and the alias silently becomes a rider standing on air -- the one-way street
-- RidePose describes: once a pad exists at a measured foot position, a second
-- pose cannot move it.
builders.hoverdisc = function(spec, add)
	local DECK_Y = 0.88
	local PAD_X = 1.08
	local R = 2.6

	local GLOW = spec.trim
	local DARK = Color3.fromRGB(28, 32, 44)

	-- The disc itself. Cylinder: LENGTH on X, so UPRIGHT is what lays it down.
	local deck = add("Disc", Vector3.new(0.34, R * 2, R * 2),
		CFrame.new(0, DECK_Y - 0.17, 0) * UPRIGHT, spec.colour, Enum.Material.Metal)
	deck.Shape = Enum.PartType.Cylinder

	-- A wider, thinner ring just below, so the edge reads from the side rather
	-- than the whole thing being one pill. Proud of the deck, never flush:
	-- two faces at the same depth give the renderer nothing to sort by.
	local rim = add("Rim", Vector3.new(0.16, R * 2.24, R * 2.24),
		CFrame.new(0, DECK_Y - 0.42, 0) * UPRIGHT, DARK, Enum.Material.Metal)
	rim.Shape = Enum.PartType.Cylinder

	-- The underside glow: what a hovering thing has instead of wheels.
	local under = add("Underglow", Vector3.new(0.12, R * 1.7, R * 1.7),
		CFrame.new(0, DECK_Y - 0.56, 0) * UPRIGHT, GLOW, Enum.Material.Neon)
	under.Shape = Enum.PartType.Cylinder

	-- Eight lamps round the rim, so it reads as machinery at a distance.
	for i = 0, 7 do
		local a = (i / 8) * math.pi * 2
		local lamp = add("Lamp", Vector3.new(0.34, 0.34, 0.34),
			CFrame.new(math.sin(a) * (R * 0.96), DECK_Y - 0.3, math.cos(a) * (R * 0.96)),
			GLOW, Enum.Material.Neon)
		lamp.Shape = Enum.PartType.Ball
	end

	-- The two things the rider actually stands on, at the inherited spacing.
	for _, sx in ipairs({ 1, -1 }) do
		add("Pad", Vector3.new(0.94, 0.1, 1.5), CFrame.new(sx * PAD_X, DECK_Y + 0.05, 0),
			DARK, Enum.Material.SmoothPlastic)
		for i = -1, 1 do
			add("Grip", Vector3.new(0.8, 0.05, 0.12),
				CFrame.new(sx * PAD_X, DECK_Y + 0.11, i * 0.42), GLOW, Enum.Material.Neon)
		end
	end
end

builders.hoverboard = function(spec, add)
	-- SHRUNK about a fifth from the first build, which came out 5.4 studs wide
	-- -- wider than the rider is tall, and it read as a piece of gym equipment
	-- rather than something you carry under one arm. 4.3 across is close to
	-- the real thing against a person.
	--
	-- PAD_X is the one number NOT scaled with the rest: it is pinned to where
	-- the posed feet actually land (measured at +-1.08 in root space), because
	-- a foot pad that is merely near the foot is a foot standing on air. See
	-- RidePose -- the ride moves to the rider, never the other way round.
	local WHEEL_R = 0.78
	local WHEEL_X = 1.85
	local DECK_Y = 0.88          -- the standing surface, just below the axle
	local PAD_X = 1.08

	local CHROME = Color3.fromRGB(228, 230, 234)
	local LED = Color3.fromRGB(96, 196, 255)

	for _, sx in ipairs({ 1, -1 }) do
		wheel(add, sx * WHEEL_X, WHEEL_R, 0, WHEEL_R, 0.6, nil)

		-- Chrome hubcap with cut spokes, which is most of what identifies one
		-- of these at a glance: on the real thing the cap is nearly the whole
		-- wheel face and the tyre is a thin band around it.
		local hub = add("Hub", Vector3.new(0.66, WHEEL_R * 1.5, WHEEL_R * 1.5),
			CFrame.new(sx * WHEEL_X, WHEEL_R, 0), CHROME, Enum.Material.Metal)
		hub.Shape = Enum.PartType.Cylinder
		for i = 0, 4 do
			local a = (i / 5) * math.pi * 2
			local r = WHEEL_R * 0.46
			add("Spoke", Vector3.new(0.7, WHEEL_R * 0.62, 0.15),
				CFrame.new(sx * WHEEL_X, WHEEL_R + math.cos(a) * r, math.sin(a) * r)
					* CFrame.Angles(-a, 0, 0), TYRE)
		end
		local boss = add("Boss", Vector3.new(0.72, 0.25, 0.25),
			CFrame.new(sx * WHEEL_X, WHEEL_R, 0), CHROME, Enum.Material.Metal)
		boss.Shape = Enum.PartType.Cylinder

		-- Fender: a rounded shell ARCHING over the wheel, not a box beside it.
		-- Concentric with the axle but lifted, so its underside clears the
		-- road instead of the lower half sinking through it, and inboard of
		-- the tyre so the wheel still stands proud at the outer face.
		local arch = add("Fender", Vector3.new(0.92, WHEEL_R * 2.05, WHEEL_R * 2.05),
			CFrame.new(sx * (WHEEL_X - 0.26), WHEEL_R + 0.26, 0), spec.colour)
		arch.Shape = Enum.PartType.Cylinder
		add("Shoulder", Vector3.new(0.96, 0.86, 1.5),
			CFrame.new(sx * (WHEEL_X - 0.26), WHEEL_R + 0.22, 0), spec.colour)

		-- Foot platform and its rubber pad -- one per foot, which is what the
		-- centre pivot exists to separate. Narrow enough to sit between the
		-- centre barrel and the wheel: inner edge 0.6 against a 0.35 barrel,
		-- outer edge 1.56 against a wheel face at 1.55.
		add("Platform", Vector3.new(1.2, 0.36, 1.7), CFrame.new(sx * PAD_X, DECK_Y - 0.18, 0), spec.colour)
		add("Pad", Vector3.new(0.96, 0.09, 1.45), CFrame.new(sx * PAD_X, DECK_Y + 0.05, 0), GRIP)
		for i = -1, 1 do
			add("Rib", Vector3.new(0.86, 0.06, 0.13),
				CFrame.new(sx * PAD_X, DECK_Y + 0.12, i * 0.4), Color3.fromRGB(58, 58, 64))
		end

		-- Blue LEDs low on the OUTER face of each fender, where the reference
		-- puts them.
		add("Lamp", Vector3.new(0.14, 0.24, 0.58),
			CFrame.new(sx * (WHEEL_X + 0.04), WHEEL_R - 0.32, 0.38), LED, Enum.Material.Neon)
	end

	-- The centre barrel the two halves pivot around: the single part that says
	-- this is a self-balancing board and not a plank on castors.
	local pivot = add("Pivot", Vector3.new(0.56, 1.0, 1.0),
		CFrame.new(0, WHEEL_R - 0.04, 0), DARK_STEEL, Enum.Material.Metal)
	pivot.Shape = Enum.PartType.Cylinder
	add("Bridge", Vector3.new(0.52, 0.4, 1.65), CFrame.new(0, DECK_Y - 0.2, 0), spec.trim,
		Enum.Material.Metal)

	-- Battery strip and power light under the bridge, and rubber bumpers front
	-- and back so the body does not end on a bare edge.
	add("Battery", Vector3.new(1.5, 0.24, 0.85), CFrame.new(0, WHEEL_R - 0.42, 0),
		DARK_STEEL, Enum.Material.Metal)
	add("Power", Vector3.new(0.55, 0.2, 0.12), CFrame.new(0, WHEEL_R - 0.1, 0.86),
		LED, Enum.Material.Neon)
	for _, sz in ipairs({ 1, -1 }) do
		add("Bumper", Vector3.new(3.5, 0.28, 0.18), CFrame.new(0, WHEEL_R + 0.42, sz * 0.98), GRIP)
	end
end

-- An electric enduro: purple bodywork bolted to a lime perimeter frame, fat
-- knobbly tyres, upside-down forks, and a finned battery box where an engine
-- would be.
--
-- STILL AN ORIGINAL. The reference for the shape is a real machine and the
-- colourway is its; neither is property. What IS property is the wordmark on
-- its swingarm and the badge on its shroud, so there is no lettering anywhere
-- on this model and there never should be -- the header above says why, and
-- the lawn ornaments settled it: moderation strips branded assets and the
-- penalty lands on the EXPERIENCE, not the item.
--
-- SIZED TO THE RIDER, like the BMX, and for the same measured reason. The
-- first build had 3.5-stud wheels, a 5.5-stud wheelbase, the seat at y 4.4
-- and the bars at 5.5 -- against a rig five studs tall whose arms reach 2.1.
-- Nobody could sit on it or hold it. Every contact point below comes from
-- RidePose's measurements of the seated pose:
--
--     seat top  y 2.225 at z -0.38     the pelvis rests here
--     grips     (+-1.83, 2.705, 0.87)  the hands
--     pegs      (+-0.35, 0.477 top, 0.65) the feet
--
-- and everything else is built around those.
builders.scrambler = function(spec, add)
	local WHEEL_R = 0.95
	local FRONT_Z, BACK_Z = 2.0, -1.9
	local TYRE_W = 0.5

	-- The three contacts, named because eleven other parts hang off them.
	local SEAT_TOP, SEAT_Z = 2.225, -0.38
	local GRIP_X, GRIP_Y, GRIP_Z = 1.83, 2.705, 0.87
	local PEG_X, PEG_TOP, PEG_Z = 0.35, 0.477, 0.65

	local BODY = spec.colour      -- purple: fenders, shrouds, side panel
	local FRAME = spec.accent     -- lime: perimeter frame, fork lowers, swingarm
	local RIM = spec.trim

	-- ---------- wheels ----------
	for _, z in ipairs({ FRONT_Z, BACK_Z }) do
		wheel(add, 0, WHEEL_R, z, WHEEL_R, TYRE_W, RIM)

		-- Knobbly tread. Set on a radius INSIDE the tyre so each block ends
		-- barely proud of the carcass: centred on WHEEL_R the bottom block
		-- hangs below the road, and flush with it the two faces are coplanar
		-- and z-fight. Proud-but-barely is the only value that is neither.
		local treadR = WHEEL_R - 0.13
		for i = 0, 9 do
			local a = (i / 10) * math.pi * 2
			add("Knobble", Vector3.new(TYRE_W + 0.08, 0.34, 0.22),
				CFrame.new(0, WHEEL_R + math.cos(a) * treadR, z + math.sin(a) * treadR)
					* CFrame.Angles(-a, 0, 0), TREAD)
		end

		-- Brake disc, offset to one side the way a real one is.
		local disc = add("Disc", Vector3.new(0.07, WHEEL_R * 0.92, WHEEL_R * 0.92),
			CFrame.new(-0.34, WHEEL_R, z), STEEL, Enum.Material.Metal)
		disc.Shape = Enum.PartType.Cylinder
	end

	-- Rear sprocket, on the opposite side to the disc.
	local sprocket = add("Sprocket", Vector3.new(0.09, 0.62, 0.62),
		CFrame.new(0.32, WHEEL_R, BACK_Z), FRAME, Enum.Material.Metal)
	sprocket.Shape = Enum.PartType.Cylinder

	-- ---------- forks: black uppers, lime lowers ----------
	--
	-- Upside-down, which is the whole look of the front end: the FAT tube is
	-- on top and the thin slider runs down to the axle. Built the other way up
	-- it reads as a commuter bike.
	local RAKE = math.rad(-19)
	for _, sx in ipairs({ 0.34, -0.34 }) do
		add("ForkUpper", Vector3.new(0.26, 1.5, 0.26),
			CFrame.new(sx, WHEEL_R + 1.42, FRONT_Z - 0.52) * CFrame.Angles(RAKE, 0, 0),
			Color3.fromRGB(32, 32, 38), Enum.Material.Metal)
		add("ForkLower", Vector3.new(0.2, 1.35, 0.2),
			CFrame.new(sx, WHEEL_R + 0.42, FRONT_Z - 0.18) * CFrame.Angles(RAKE, 0, 0),
			FRAME, Enum.Material.Metal)
	end
	-- Triple clamps.
	for _, y in ipairs({ 2.05, 2.55 }) do
		add("Clamp", Vector3.new(1.0, 0.16, 0.34),
			CFrame.new(0, y, FRONT_Z - 0.62 - (y - 2.05) * 0.34) * CFrame.Angles(RAKE, 0, 0),
			Color3.fromRGB(44, 44, 50), Enum.Material.Metal)
	end

	-- ---------- bars, at the measured grips ----------
	add("Bars", Vector3.new(GRIP_X * 2, 0.16, 0.16), CFrame.new(0, GRIP_Y, GRIP_Z),
		Color3.fromRGB(38, 38, 44), Enum.Material.Metal)
	add("BarRise", Vector3.new(0.5, 0.5, 0.16),
		CFrame.new(0, GRIP_Y - 0.24, GRIP_Z + 0.05), Color3.fromRGB(38, 38, 44), Enum.Material.Metal)
	for _, sx in ipairs({ GRIP_X, -GRIP_X }) do
		add("Grip", Vector3.new(0.48, 0.22, 0.22), CFrame.new(sx, GRIP_Y, GRIP_Z), GRIP)
	end
	-- One bar-end mirror, on the left only, exactly as the reference has it.
	add("MirrorStem", Vector3.new(0.08, 0.3, 0.08), CFrame.new(-GRIP_X - 0.12, GRIP_Y + 0.24, GRIP_Z),
		Color3.fromRGB(38, 38, 44), Enum.Material.Metal)
	add("Mirror", Vector3.new(0.26, 0.2, 0.07),
		CFrame.new(-GRIP_X - 0.12, GRIP_Y + 0.42, GRIP_Z) * CFrame.Angles(0, math.rad(28), 0),
		Color3.fromRGB(150, 165, 180), Enum.Material.Metal)

	-- ---------- bodywork ----------
	-- Front fender, riding high over the wheel the way an enduro's does.
	add("FrontFender", Vector3.new(0.86, 0.14, 1.7),
		CFrame.new(0, WHEEL_R + 0.98, FRONT_Z - 0.3) * CFrame.Angles(math.rad(-15), 0, 0), BODY)
	-- The shroud each side of the headstock.
	for _, sx in ipairs({ 0.42, -0.42 }) do
		add("Shroud", Vector3.new(0.16, 0.8, 1.1),
			CFrame.new(sx, 2.0, FRONT_Z - 1.15) * CFrame.Angles(math.rad(-14), 0, 0), BODY)
	end

	-- The battery box: the visual mass, and the finned face is what says
	-- electric rather than four-stroke. Vertical slats, because that is the
	-- one detail the eye actually reads on the reference at any distance.
	add("Battery", Vector3.new(0.92, 1.35, 1.9), CFrame.new(0, 1.5, 0.15), Color3.fromRGB(30, 30, 36))
	for i = -3, 3 do
		add("Fin", Vector3.new(0.98, 1.1, 0.12), CFrame.new(0, 1.5, 0.15 + i * 0.26), FRAME)
	end
	-- Motor, low and behind the box, and the bash plate under it.
	local motor = add("Motor", Vector3.new(0.8, 0.75, 0.75),
		CFrame.new(0, WHEEL_R - 0.15, -0.55), Color3.fromRGB(36, 36, 42), Enum.Material.Metal)
	motor.Shape = Enum.PartType.Cylinder
	add("BashPlate", Vector3.new(0.9, 0.14, 1.5),
		CFrame.new(0, 0.5, -0.1) * CFrame.Angles(math.rad(-6), 0, 0), FRAME)

	-- ---------- perimeter frame ----------
	-- The lime rails that wrap the battery, top and bottom, each side.
	for _, sx in ipairs({ 0.5, -0.5 }) do
		add("RailTop", Vector3.new(0.13, 0.2, 2.3),
			CFrame.new(sx, 1.88, 0.1) * CFrame.Angles(math.rad(4), 0, 0), FRAME, Enum.Material.Metal)
		add("RailDown", Vector3.new(0.13, 1.5, 0.2),
			CFrame.new(sx, 1.55, 1.05) * CFrame.Angles(math.rad(-22), 0, 0), FRAME, Enum.Material.Metal)
		add("RailBottom", Vector3.new(0.13, 0.18, 1.7),
			CFrame.new(sx, 0.78, 0.05), FRAME, Enum.Material.Metal)
	end

	-- ---------- seat and tail ----------
	local SEAT_T = 0.26
	add("Seat", Vector3.new(0.86, SEAT_T, 1.9),
		CFrame.new(0, SEAT_TOP - SEAT_T / 2, SEAT_Z - 0.4), GRIP)
	-- A lighter strip along the top of the seat. Near-black on a dark bike
	-- against a bright sky reads as a GAP between the tank and the tail --
	-- the seat was there and simply could not be seen.
	add("SeatTop", Vector3.new(0.74, 0.07, 1.78),
		CFrame.new(0, SEAT_TOP - 0.02, SEAT_Z - 0.4), Color3.fromRGB(72, 72, 80))
	-- The tank cover, filling the step between the battery box and the seat.
	-- Without it the seat floated over a gap and the frame rails showed
	-- through where a fuel tank would be on a petrol bike.
	add("TankCover", Vector3.new(0.78, 0.5, 1.15),
		CFrame.new(0, 2.0, 0.62) * CFrame.Angles(math.rad(-7), 0, 0), BODY)
	-- The tail rises behind the seat, as the reference's does.
	add("Tail", Vector3.new(0.68, 0.16, 1.45),
		CFrame.new(0, SEAT_TOP + 0.14, SEAT_Z - 1.72) * CFrame.Angles(math.rad(11), 0, 0), BODY)
	add("TailLight", Vector3.new(0.34, 0.16, 0.1),
		CFrame.new(0, SEAT_TOP + 0.2, SEAT_Z - 2.16), Color3.fromRGB(226, 48, 40), Enum.Material.Neon)
	-- Number board on the flank, above the swingarm pivot.
	for _, sx in ipairs({ 0.5, -0.5 }) do
		add("SidePanel", Vector3.new(0.1, 0.78, 1.25),
			CFrame.new(sx, 1.85, -1.05) * CFrame.Angles(math.rad(6), 0, 0), BODY)
	end

	-- ---------- swingarm, shock and pegs ----------
	for _, sx in ipairs({ 0.36, -0.36 }) do
		add("Swingarm", Vector3.new(0.14, 0.26, 1.75),
			CFrame.new(sx, WHEEL_R - 0.06, BACK_Z + 0.9) * CFrame.Angles(math.rad(5), 0, 0),
			FRAME, Enum.Material.Metal)
	end
	add("Shock", Vector3.new(0.2, 0.9, 0.2),
		CFrame.new(0, 1.5, -0.95) * CFrame.Angles(math.rad(18), 0, 0),
		Color3.fromRGB(210, 90, 60), Enum.Material.Metal)

	local PEG_T = 0.12
	for _, sx in ipairs({ PEG_X, -PEG_X }) do
		add("Peg", Vector3.new(0.44, PEG_T, 0.3),
			CFrame.new(sx, PEG_TOP - PEG_T / 2, PEG_Z), STEEL, Enum.Material.Metal)
	end

	-- Headlight last, so it reads over the shrouds rather than through them.
	add("Light", Vector3.new(0.62, 0.5, 0.18),
		CFrame.new(0, 2.42, FRONT_Z - 0.92) * CFrame.Angles(math.rad(-16), 0, 0),
		Color3.fromRGB(255, 248, 220), Enum.Material.Neon)
end

-- ============================================================
-- BUILD
-- ============================================================

function RideModel.build(key: string): Model
	local spec = Config.RIDES[key]
	assert(spec, ("Unknown ride '%s'"):format(tostring(key)))

	local model = Instance.new("Model")
	model.Name = "Ride_" .. key

	local function add(name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		-- Anchored FALSE and Massless TRUE, because this gets welded to a
		-- character rather than left standing in the world. An anchored part
		-- welded to a humanoid pins the humanoid; a heavy one changes how it
		-- walks and jumps, which would make a ride a stat rather than a look.
		p.Anchored = false
		p.Massless = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Color = colour
		p.Material = material or Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end

	-- The chassis: an invisible anchor at the model's own origin, added FIRST
	-- so it exists whatever the builder does.
	--
	-- It is what RideService joints to the character, with everything else
	-- welded rigidly behind it, so the whole ride can be tipped by moving one
	-- Motor6D instead of being frozen to the root part by part. At the origin
	-- and unrotated on purpose: that makes it a safe PrimaryPart, so PivotTo
	-- still behaves exactly as it did under WorldPivot.
	local chassis = add("Chassis", Vector3.new(0.2, 0.2, 0.2), CFrame.new(),
		Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	chassis.Transparency = 1
	model.PrimaryPart = chassis

	local build = builders[spec.style]
	assert(build, ("Ride '%s' has no builder for style '%s'"):format(key, tostring(spec.style)))
	build(spec, add)

	-- The pivot is the AUTHORED ORIGIN -- ground level, centred, facing +Z --
	-- and never the bounding-box centre. RideService seats this on the floor
	-- under a character, and a centre pivot would bury half of it in the road.
	--
	-- The PrimaryPart above is safe only because the chassis sits at that same
	-- origin unrotated. A PrimaryPart pivot REPLACES the part's rotation on
	-- PivotTo rather than adding to it, so choosing one of the rotated parts
	-- would lay every board on its side -- the trap PigGear documents. Setting
	-- WorldPivot too keeps the two agreeing.
	model.WorldPivot = CFrame.new()

	return model
end

-- The speed streak, built only when a ride is actually mounted.
--
-- Kept out of `build` so the shop tile does not draw one: an icon spinning in
-- a 48-pixel viewport with a motion trail attached to it reads as a smear.
function RideModel.addTrail(model: Model, colour: Color3?)
	local anchor = model:FindFirstChildWhichIsA("BasePart")
	if not anchor then
		return
	end

	-- A MISSING COLOUR COSTS A TRAIL, NEVER THE MOUNT.
	--
	-- ColorSequence.new(nil) THROWS, and this is called from inside
	-- RideService.mount -- so a ride added to Config without an `accent`
	-- did not lose its speed streak, it broke mounting outright and left
	-- the rider climbing into the sky. The hoverdisc shipped exactly that
	-- way. Ordering in `mount` is what makes such a throw survivable now;
	-- this is what keeps it from being a throw at all.
	--
	-- Warned rather than defaulted to a colour. A silent fallback is a ride
	-- whose streak is quietly the wrong colour forever, which is the kind of
	-- thing nobody ever files -- and this file's rule is that a rejection
	-- nobody can see is indistinguishable from a broken feature. A dev sees
	-- the warning; a player sees a ride with no streak, which is a whole
	-- working ride.
	if typeof(colour) ~= "Color3" then
		warn(("[RideModel] %s has no `accent` colour, so it gets no trail.")
			:format(model.Name))
		return
	end

	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(-0.9, 0.2, -1.4)
	a0.Parent = anchor
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0.9, 0.2, -1.4)
	a1.Parent = anchor

	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(colour)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime = 0.45
	trail.LightEmission = 0.6
	trail.MinLength = 0.4
	trail.Parent = anchor
end

return RideModel
