--!strict
--[[
	PiggyBank

	Builds the piggy bank that sits on each plot, out of parts, and owns all
	of its feedback -- the coin pile, the glow, the particles and the sounds.

	Part-built BY DEFAULT and mesh-built when the assets exist, which reverses
	half of what this header used to say. It read: "Part-built rather than a
	mesh on purpose: it costs nothing, runs on a school Chromebook, and I can
	change the shape in one edit instead of round-tripping through Blender."

	Two of those three are still true and one was the whole problem. Parts are
	free and they run anywhere; what they cannot do is BLEND. Two Roblox parts
	meet at a hard intersection, so a cylinder snout jammed into a sphere reads
	as assembled however carefully it is placed, and no arrangement fixes it.
	The mesh is four generated MeshParts that carry those fillets already.

	The round-tripping objection is answered rather than accepted, and by a
	shorter route than the one first taken. A Blender pipeline was built and
	abandoned: a committed `bpy` script welded nine primitives with a voxel
	remesh, exported FBX, and the FBX had to be imported by hand -- which is
	where its axis convention flipped the snout to the back of the pig, and
	where a whole session went. Studio's own mesh generator returns the parts
	already separated, already uploaded and already facing +Z, so the shape
	changes in one prompt and the ids land in `Config.PIGGY_MESH`.

	And the primitives piggy is not retired, it is the FALLBACK. With no mesh
	ids in Config this file behaves exactly as it always has, so a fresh empty
	place plus this repo still gives the identical world.

	The coins are individual discs, not one blob. They're positioned by
	sphere-cap volume so each new coin lands on the current surface of the
	pile, which is what makes it read as filling up rather than inflating.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local PiggyModel = require(ReplicatedStorage.Shared.PiggyModel)
local PigGear = require(ReplicatedStorage.Shared.PigGear)
-- The strongroom on a shop's back wall. Geometry only: everything that
-- makes it BEHAVE like a piggy bank -- the fill, the dial, the alarm, the
-- plaster -- is this file's own functions running on its parts. See
-- `PiggyBank.buildVault`.
local VaultModel = require(ReplicatedStorage.Shared.VaultModel)

local PiggyBank = {}

export type Refs = {
	model: Model,
	-- The pig's own origin, kept because accessories are attached long after
	-- build() has returned and every anchor in Config is relative to it.
	origin: Vector3,
	body: Part,
	pile: Folder,
	coins: { Part },
	shown: number,
	glow: PointLight,
	drip: ParticleEmitter,
	burst: ParticleEmitter,
	aura: ParticleEmitter,
	skinAura: ParticleEmitter,
	-- OPTIONAL, BECAUSE A SHOP VAULT HAS NO FACE. `buildVault` returns
	-- this same shape so that not one reader of `plot.piggy` had to learn
	-- there were two kinds of thing standing on a plot -- see the entry
	-- there. What a vault genuinely has is a body, a coin readout, a lock,
	-- a light, sounds and a prompt; what it has none of is a snout.
	snout: Part?,
	tail: Part?,
	ears: { BasePart },
	-- OPTIONAL, BECAUSE ONLY THE MODELLED PIG HAS ONE. The primitives piggy
	-- carries its second tone on four separate parts and the mesh carries it on
	-- a single `Trim` MeshPart; `applySkin` paints whichever it is handed.
	trim: Part?,
	legs: { Part },
	-- The body's resting size, because the milestone squash tweens back to it
	-- and a MeshPart is not a 12-stud cube.
	bodySize: Vector3?,
	-- Body-local correction from the mesh's bounding-box centre back to the
	-- pig's true body centre, so pattern marks seat where they always did.
	patternSeat: CFrame?,
	lock: Model,
	stealPrompt: ProximityPrompt,
	-- THE OTHER WAY IN, AND THE FIRST PROMPT IN THIS GAME THAT IS NOT
	-- EXCLUSIVE WITH ITS NEIGHBOUR. It sits on the same Body as the steal
	-- prompt and is live at the same time for the same player, because the
	-- whole feature is a choice and a choice you cannot see is not one. See
	-- `Config.PROMPT_SLOT_ATTRIBUTE` for what that cost the card renderer.
	smashPrompt: ProximityPrompt,
	sounds: { [string]: Sound },
	-- WHICH OF THE TWO THIS IS, and the only branch the difference costs
	-- anywhere. Three functions in this file dress a piggy -- the skin, the
	-- accessories and the effect -- and all three are meaningless on a
	-- strongroom: a shop wears nothing, and `applySkin` would paint the
	-- carcass pink. Every other function here works on both without asking.
	vault: boolean?,
}

-- All measurements are relative to the top face of the plot base (y = +0.5).
local BODY_R = 6
local BODY_Y = 8.5

-- Legs are placed by their corner offset and thickness; the length that makes
-- them meet the body is solved for at build time, not written down here.
local LEG_X = 3.1 -- offset from the centre line on both X and Z
local LEG_D = 1.6 -- cylinder diameter

-- The plot base is a slab centred on `origin`, so its walkable top -- and the
-- pig's ground line -- is half a slab above it.
local GROUND_Y = Config.PLOT_SIZE.Y / 2
-- THE PILE IS SEEN THROUGH THE VAULT HATCH NOW, NOT THROUGH THE PIG, AND
-- THAT MOVED EVERY ONE OF THESE NUMBERS.
--
-- The body used to be translucent for one reason: so the pile showed through
-- it. Measured against what it actually bought, that was a bad trade -- at
-- 0.30 the coins read as dark smears rather than as gold, the snout floated
-- free of the face, and the neon tower on the next street showed through the
-- pig. The body is opaque now (every skin's `transparency` is 0) and the
-- hatch bored in the back is the window.
--
-- WHICH MEANS THE PILE HAD TO COME DOWN. It sat ABOVE the body centre, on
-- the old argument that the snout hid the lower third from the front; seen
-- through a hatch centred at DIAL_Y it hung in the top of the aperture like
-- coins suspended in mid-air. It fills from the belly now, so the surface
-- rises past the opening as the pig fills.
--
-- AND DENSER BY COIN SIZE RATHER THAN BY COUNT, which is the one thing here
-- that is not free. `Config.COIN_COUNT` is not a density dial: it is the
-- DRIP CADENCE, tuned so a coin lands about every fifteen seconds at every
-- level, and its own comment calls that a heartbeat while `playCoinDrop`
-- warns that anything louder becomes nagging. Doubling the count to fill the
-- hatch would have doubled the chime rate as a side effect. Bigger discs in
-- a smaller volume buy the same picture and touch no cadence at all.
local COIN_R = 3.85 -- radius of the volume coins may occupy
local COIN_SIZE = 2.1
local COIN_THICK = 0.30

-- Below the body's centre, so the pile's surface crosses the hatch. Measured
-- on the shipped mesh: the volume spans y 3.65 to 11.35 against an aperture
-- of roughly 4.6 to 8.6, so the level READS from about 4% full to about 71%
-- and reads as packed above that. The top of the range is carried by `glow`
-- instead, which now spills out of the hatch and the coin slit rather than
-- through the shell.
local COIN_CENTRE_OFFSET = -1.0

-- Snout sits low, like a real pig's, so it stops covering the pile.
local SNOUT_Y = -2.5
local SNOUT_D = 3.6

-- Where the vault dial sits on the body, and how big it can get.
--
-- A quarter turn round from the face, and a stud below the equator. Every
-- other candidate is already taken or already blocked: the top of the body is
-- the hat anchor, the front is the snout and the eyes, the back is the cape
-- and jetpack anchor plus the tail, and the underside is the four legs. This
-- patch of flank is the only surface on the pig that is both empty and turned
-- towards someone walking in from the street.
--
-- DIAL_MAX_R is the largest tier's plate. It is the number the clearances
-- were measured against: at 1.95 the plate's top edge reaches y 9.42 against
-- an eyeball that starts at 9.98, its bottom reaches 5.58 against legs that
-- top out at 4.65, and its inner edge comes no closer than x 2.81 to a snout
-- that ends at 1.8. Growing it past 1.95 breaks the first of those.
-- ON THE BACK, BELOW THE TAIL, and it is a vault DOOR rather than a dial on a
-- flank. The flank versions -- 45 degrees, then 72 -- both read as something
-- bolted to the side of an animal. A hatch in the back of a piggy bank is a
-- thing that already exists in the world, which is why it looks right.
--
-- MEASURED AGAINST WHAT IS ALREADY BACK THERE. The tail is a ball spanning
-- local y 0.35 to 2.05 and the legs top out at local y -4.59, so the window
-- below the tail and above the legs is about five studs tall. At local y
-- -1.9 the largest plate spans -3.85 to 0.05: clear of the tail by 0.30 and
-- of the legs by 0.74.
--
-- IT IS BEHIND THE CAPE, AND THAT IS ACCEPTED RATHER THAN MISSED. The back
-- accessory anchor is right above this and a Hero Cape hangs down to local
-- y -1.77, so a caped piggy hides roughly the top half of its own vault.
-- That is the reverse of the padlock bug this file already records: there,
-- the GAME's part swallowed the PLAYER's hat and ruined something they had
-- rolled for. Here the player's own cape covers the game's tell, on a piggy
-- they chose to put a cape on -- their purchase is intact, and what they lose
-- is advertising their own lock to thieves.
--
-- The cost is real and worth stating: a thief walking up from the street sees
-- the face, not the back, so the metal tier no longer carries from out there.
-- What it buys is that an UNLOCKED vault is now a visible hole, which is the
-- signal that actually changes a thief's mind at the gate.
local DIAL_YAW = math.rad(180)
local DIAL_Y = 6.6
local DIAL_MAX_R = 1.95
-- Thick enough that the rim, which sinks 0.32 into the curve of the body at
-- full size, still has its back face buried rather than floating clear.
local DIAL_THICK = 0.9
-- Segments in the vault's rim. Twelve is enough for the opening to read as
-- round; the cost is twelve parts per piggy, and there are twelve.
local RIM_SEGMENTS = 12

-- THE LADDER LIVES UP HERE BECAUSE THE OPENING IS DERIVED FROM IT, and a
-- `local` declared below a function that reads it is a nil GLOBAL to that
-- function -- the forward-reference trap this project has now hit seven
-- times. `buildLock` sits four hundred lines above where this table used to
-- be, so the derivation below would silently have been `nil.radius`.
local LOCK_TIERS = {
	{ metal = Color3.fromRGB(122, 128, 138), radius = 1.55, spokes = 2 }, -- iron
	{ metal = Color3.fromRGB(176, 122, 66), radius = 1.68, spokes = 3 },  -- bronze
	{ metal = Color3.fromRGB(198, 204, 214), radius = 1.82, spokes = 4 }, -- steel
	{ metal = Color3.fromRGB(240, 198, 76), radius = 1.95, spokes = 5 },  -- gold
}

-- THE HOLE IS SIZED OFF THE SMALLEST DOOR, NOT THE LARGEST, AND THAT IS A
-- BUG FIX RATHER THAN A TIDY-UP.
--
-- It used to be `DIAL_MAX_R`, on the reasoning that an opening clearing the
-- GOLD plate by a fraction reads as "a door sitting IN a hole rather than a
-- disc covering one". That reasoning was measured against exactly one of the
-- four tiers and it silently made the other three a door too small for its
-- own doorway: at iron's 1.55 against an opening of 1.95 there is FOUR
-- TENTHS OF A STUD of bare black showing all the way round the lid --
-- reported, correctly, as the locks not covering the hole.
--
-- Derived off `LOCK_TIERS[1]` so it cannot come back. Every tier now
-- overlaps the opening by at least `VAULT_COVER`, and because the plates
-- still ladder 1.55 to 1.95 the FLANGE grows with the tier: iron is a bare
-- lid sitting in its frame and gold is a heavy door with a wide rim, which
-- is one more thing the metal is saying from the street.
local VAULT_COVER = 0.12
local VAULT_R = LOCK_TIERS[1].radius - VAULT_COVER

local PINK_DARK = Color3.fromRGB(214, 122, 148)
local NEAR_BLACK = Color3.fromRGB(38, 30, 34)
local COIN_GOLD = Color3.fromRGB(238, 194, 72)
local COIN_GOLD_2 = Color3.fromRGB(250, 218, 118)

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local GOLDEN_ANGLE = 2.39996323

local function part(name: string, parent: Instance, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Roblox cylinders have their flat faces on the X axis, so any cylinder that
-- should point some other way needs rotating into place.
local function cylinderUp(pos: Vector3): CFrame
	return CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
end

local function cylinderForward(pos: Vector3): CFrame
	return CFrame.new(pos) * CFrame.Angles(0, math.rad(90), 0)
end

-- ============================================================
-- COIN PILE GEOMETRY
-- ============================================================

-- Height of the spherical cap holding `fraction` of the sphere's volume.
--
-- This is what makes the pile look real. Spacing coins evenly by height would
-- put as many coins in the narrow bottom of the sphere as in the wide middle,
-- so the level would crawl at first and then leap. Spacing them by volume
-- means each coin represents the same amount of money, and the surface rises
-- at the rate a player expects.
local function capHeightForVolume(fraction: number, radius: number): number
	local lo, hi = 0, radius * 2
	for _ = 1, 24 do
		local mid = (lo + hi) / 2
		-- Normalised cap volume: h^2 * (3R - h) / (4R^3)
		local volume = (mid * mid * (3 * radius - mid)) / (4 * radius * radius * radius)
		if volume < fraction then
			lo = mid
		else
			hi = mid
		end
	end
	return (lo + hi) / 2
end

local function buildCoinPile(centre: Vector3, parent: Instance): ({ Part }, Folder)
	local folder = Instance.new("Folder")
	folder.Name = "CoinPile"
	folder.Parent = parent

	-- Seeded so every piggy on every server has the identical pile. A random
	-- scatter per server would mean two players describing the same vault
	-- differently, and would break screenshot comparisons while tuning.
	local rng = Random.new(20260830)
	local coins: { Part } = {}

	for i = 1, Config.COIN_COUNT do
		local fraction = (i - 0.5) / Config.COIN_COUNT
		local height = capHeightForVolume(fraction, COIN_R)
		local y = -COIN_R + height

		-- Radius of the sphere's cross-section at this height, pulled in so
		-- coins never poke through the shell. Widened 0.74 -> 0.82 with the
		-- volume itself shrinking: measured, the furthest a disc's own edge
		-- reaches from the body centre is 4.79 against half-extents of 5.93,
		-- 6.82 and 6.03, so there is over a stud of wall at the worst point.
		local ring = math.sqrt(math.max(0, COIN_R * COIN_R - y * y)) * 0.82
		local theta = i * GOLDEN_ANGLE
		local dist = ring * math.sqrt(rng:NextNumber(0.05, 1))

		local pos = centre + Vector3.new(math.cos(theta) * dist, y, math.sin(theta) * dist)

		local coin = part("Coin", folder, Vector3.new(COIN_THICK, COIN_SIZE, COIN_SIZE),
			CFrame.new(pos)
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
				* CFrame.Angles(0, 0, math.rad(90))
				* CFrame.Angles(math.rad(rng:NextNumber(-22, 22)), 0, math.rad(rng:NextNumber(-22, 22))))
		coin.Shape = Enum.PartType.Cylinder
		coin.Material = Enum.Material.Metal
		coin.Color = if i % 3 == 0 then COIN_GOLD_2 else COIN_GOLD
		coin.Transparency = 1 -- hidden until the vault reaches it
		coin.CastShadow = false

		table.insert(coins, coin)
	end

	return coins, folder
end

-- The frame the whole vault dial is built in, given a piggy's origin.
--
-- Its X axis points straight out of the body, which is what both a Roblox
-- cylinder and the spin in rattleLock want: the plate, face and hub are
-- cylinders along that axis, and turning the wheel is a rotation about it.
-- Y stays as upright as the tilt allows, so the spokes read level.
--
-- CFrame.lookAt aims LookVector, which is -Z, so the extra quarter turn about
-- Y is what swings that onto +X. Without it the dial lies flat against the
-- flank like a sticker.
local function dialCFrame(origin: Vector3): CFrame
	local centre = origin + Vector3.new(0, BODY_Y, 0)
	local drop = DIAL_Y - BODY_Y
	local ring = math.sqrt(math.max(BODY_R * BODY_R - drop * drop, 0))
	local normal = Vector3.new(math.sin(DIAL_YAW) * ring, drop, math.cos(DIAL_YAW) * ring).Unit
	local seat = centre + normal * BODY_R
	return CFrame.lookAt(seat, seat + normal) * CFrame.Angles(0, math.rad(90), 0)
end

-- ============================================================
-- BUILD
-- ============================================================

-- ============================================================
-- THE MESH PIGGY
-- ============================================================
--
-- The piggy is nine primitives welded into one surface by a voxel remesh, so
-- every junction is a fillet rather than the hard intersection two Roblox
-- parts are stuck with. It arrives as two MeshParts split by COLOUR REGION --
-- `Body` (barrel, legs) and `Trim` (ears, muzzle, hooves, tail) -- which is
-- exactly the pair every skin already defines, so nothing about the skin
-- system moves.
--
-- IT IS A SWAP AFTER THE FACT, NOT A BRANCH INSIDE `build`. Branching would
-- have meant four separate guards threaded through 350 lines of load-bearing
-- code, with the eyes and nostrils interleaved between them and every one of
-- them a chance to leave a wedge ear stuck to a smooth head. Building the
-- parts pig and then replacing five of its pieces touches no existing line,
-- and gives the fallback for free: if ANYTHING here fails, what is already
-- standing is a complete, correct, shipped piggy.
--
-- WHICH IS THE `Decor.prewarm` RULE ARRIVING AGAIN. A prettier pig may never
-- stop a plot building, and `PlotService.start` runs in sequence with every
-- other service -- so a mesh that fails to load costs a fillet, never the
-- server.
--
-- `MeshPart.MeshId` CANNOT BE WRITTEN FROM A SCRIPT. Measured: it throws
-- "The current thread cannot write 'MeshId' (lacking capability
-- NotAccessible)", which is the same family as the `RenderFidelity` incident
-- this file already records. So the parts are created by
-- `InsertService:CreateMeshPartAsync`, ONCE, and cloned per piggy -- the same
-- shape `PlayerGear.prewarm` uses for its CSG templates and for the same
-- reason: the call yields, and yielding inside a build loop twelve times is
-- twelve web calls to say one thing.
-- THE GENERATED BODY HAS A HOLE IN THE TOP OF ITS BACK, AND IT IS A
-- THE SEGMENTATION SCAR IS GONE, AND IT WENT BY REGENERATING RATHER THAN BY
-- BEING PATCHED. This is the fix for it, and the several hundred lines it
-- replaces are worth summarising because the diagnosis was right and every
-- remedy built on it was wrong.
--
-- `segmentation: "explicit"` hands back the body, ears, snout and tail as
-- separate MeshParts, so the body is left with a socket wherever a piece came
-- off. The ears and the snout were seated back over theirs. THE TAIL WAS
-- NOT: it was authored at y 9.70 and its socket was at 11.45, so it had been
-- deliberately reseated a stud and three quarters below the hole it came out
-- of, and the hole stayed open. Everything after that -- a ball cap sunk on
-- the socket normal, a marker ladder to find how far out the real skin
-- stands, an ellipsoid matching both principal radii, and finally an
-- EditableMesh repair that closed the topology and still rendered as a
-- dimple -- was an attempt to fill a hole that only existed because the part
-- that plugs it had been moved.
--
-- THE NEW BODY SEATS EVERY PART AT THE OFFSET IT WAS GENERATED AT, so each
-- one covers its own socket and there is nothing left to cap. Photographed
-- from directly behind at two studs and at twelve: the rump is unbroken.
--
-- WHAT THE WHOLE EPISODE IS ACTUALLY ABOUT is that a cap is a smooth Part
-- sitting in a faceted mesh, so it shades differently whatever shape it is
-- given -- proved by matching both measured radii to 0.02 studs and
-- photographing the result INDISTINGUISHABLE from a plain sphere. There was
-- no seating that could have worked. When a fill is visible for a reason no
-- geometry can reach, the thing to fix is the hole.

-- The dial is solved on a 6.00 sphere at BODY_Y and the mesh's back is a long
-- way outside it: at DIAL_Y 6.6 the sphere gives z -5.691 and the measured
-- skin is at z -8.015, so every piece of the vault sits 2.324 studs inside
-- the pig until it is pushed out by the difference.
--
-- THIS NUMBER MOVED BY A FACTOR OF THIRTEEN WITH THE NEW BODY (it was 0.174)
-- and nothing would have said so: the plate would simply have been buried,
-- which is what the whole dial already looked like the last time this was
-- measured against a model of the pig rather than the pig.
-- Re-derived for the modelled body by intersecting `dialCFrame`'s own axis
-- with the real shell: the ball puts the seat 6.00 from its centre and the
-- skin is 6.823 out along that line. It is a much smaller push than the last
-- body needed (1.076) for a good reason rather than by luck -- this pig is
-- built at a scale that makes the 6.00 sphere nearly true of it, so the dial
-- has far less to travel.
--
-- IT IS ALSO WHERE THE HATCH WAS CUT, which is what stops the plate and its
-- hole ever disagreeing: `build_pig.py` solves both from this same axis.
local MESH_DIAL_OUT = 0.823

-- THE FACE IS BUILT ON THE BALL AND HAS TO BE MOVED ONTO THE MESH, because
-- the generated body is four studs longer than the sphere the eyes and the
-- nostrils were solved against. Left alone the eyes sit three studs inside
-- the head -- invisible, on the one part of the pig anybody looks at.
--
-- MEASURED AGAINST THE SKIN, NOT THE BOX. A probe copy of the body at
-- PreciseConvexDecomposition collision was raycast from outside; the shipped
-- body is Box fidelity on purpose, so the real one answers every ray with its
-- bounding box. At x 2.35 the face runs z 6.99 at y 2.6 down to 6.57 at y 3.2
-- in body-local terms, which is where these numbers come from.
--
-- THE EYES SIT HALF IN AND HALF OUT, which is the rule this project already
-- records for the drip statue: a ball whose centre is outside the skull is a
-- googly eye glued on. Measured, the centre is 0.14 inside the skin and the
-- 1.25-stud ball shows about half a stud of disc.
-- THE NUMBERS MOVED TO `Config.PIGGY_MESH_FACE`, AND THE REASONING WENT
-- WITH THEM. Everything above still applies; what changed is that this is
-- no longer the only pig that needs them.
--
-- `PiggyModel` builds a MINI of this same mesh for the previews -- the
-- victim shelf on a lawn, the inventory's collection log, the crate reel --
-- and it has to seat the same eyes on the same face. Two copies of a face
-- seat is the near-identical duplicate this project keeps recording, and it
-- is the worst possible one to let drift: the two pigs would disagree about
-- where a pig's eyes are, on the same asset, with nothing erroring.
--
-- Config is the right home for the same reason `chestEntry` and `chestPool`
-- are there: it requires nothing, and both ends already read it.
local MESH_FACE = Config.PIGGY_MESH_FACE

-- THE VAULT HATCH IS CUT INTO THE ASSET NOW, SO NOTHING IS SUBTRACTED AT
-- RUN TIME AND `boreVault` IS GONE WITH IT.
--
-- It bored the hatch out of the generated body with `SubtractAsync` on the
-- template, and everything that entry recorded is still true: the subtract
-- works on a MeshPart, hands one back, and the old "any subtract breaks
-- this mesh" finding was a fact about one asset rather than about the API.
--
-- What retired it is that the body stopped being generated. The modelled
-- piggy bank is cut in Blender -- the hatch and the coin slot are bored
-- through the shell before it is ever uploaded -- so cutting again here
-- would be a second hole solved against a body that no longer exists.
-- `Config.PIGGY_VAULT` and `Config.PIGGY_SHAVE` went unread with it.

local meshTemplates: { [string]: BasePart }? = nil
local meshChecked = false

local function ensureMeshTemplates(): { [string]: BasePart }?
	if meshChecked then
		return meshTemplates
	end
	meshChecked = true

	local spec = Config.piggyMesh()
	if not spec then
		return nil
	end

	-- THE OPENINGS ARE CUT IN BLENDER, AND NOTHING IS SUBTRACTED HERE.
	--
	-- This is the third position this file has held on that and the first one
	-- that costs nothing, so it is worth keeping the other two.
	--
	-- It bored the hatch at RUN TIME with `SubtractAsync`, and on the
	-- generated body that broke the mesh outright: from a camera behind the
	-- pig at twenty studs the body was not drawn at all -- ears, tail, coin
	-- pile and the world visible straight through it. Every innocent suspect
	-- was cleared first (transparency, render fidelity, double-sided,
	-- occlusion, every size field agreeing), and what settled it was the UNCUT
	-- mesh rendering perfectly from the same camera. A through-bore, a blind
	-- recess and a 0.55 by 3.00 slit each failed alone, so it was never the
	-- size of the opening. The openings went back to being DRAWN -- a
	-- near-black disc and a bar sunk in the spine -- which cost the hatch
	-- being a real window onto the pile.
	--
	-- THAT WAS A FACT ABOUT ONE ASSET RATHER THAN ABOUT THE API, which the
	-- next body proved by taking a subtract cleanly. And this one settles it
	-- for good by not needing one: `blender/pig/build_pig.py` gives the body a
	-- real 0.30-stud wall and bores both openings through it BEFORE it is ever
	-- uploaded. So there is no run-time CSG to break, no cutter solved against
	-- a body that may move, and the hatch is a genuine hole with the hollow
	-- and the coin pile behind it. `Config.PIGGY_VAULT` and
	-- `Config.PIGGY_SHAVE` are unread and have been since the bore was cut in
	-- the model instead.

	local ok, result = pcall(function()
		local insert = game:GetService("InsertService")
		local made: { [string]: BasePart } = {}
		for _, entry in ipairs(spec) do
			-- BOX COLLISION ON PURPOSE. A thief runs at this thing and a dog
			-- patrols round it, and precise collision on a 7,000-triangle
			-- surface buys nothing a box does not already give at twelve studs
			-- across -- while costing every one of those triangles a physics
			-- query.
			--
			-- PRECISE RENDER, though, is the whole point: at Automatic a
			-- MeshPart sheds triangles with distance, and this pig is read from
			-- the pavement. Note this file already records `RenderFidelity`
			-- throwing on a UnionOperation from a real Script while passing in a
			-- sandbox, so it is inside the pcall rather than beside it.
			local part = insert:CreateMeshPartAsync(entry.id,
				Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
			if entry.part == "Body" then
				-- Seated in the template's own frame, which is what the
				-- clone is measured against when it is stood on a plot.
				part.Size = entry.size
				part.CFrame = CFrame.new(entry.offset)
				part.Anchored = true
				-- THERE IS DELIBERATELY NO `DoubleSided` HERE, AND IT WAS
				-- REMOVED BY LOOKING RATHER THAN BY ARGUING.
				--
				-- The last body was a SINGLE SKIN with no thickness, so without
				-- backfaces you looked in the vault hatch and straight out the far
				-- side of the animal, and this line was load-bearing. The modelled
				-- body is a real shell with a 0.30-stud wall, so every surface an
				-- opening reveals already faces the camera.
				--
				-- Checked the only way this can be checked: backfaces turned off on
				-- a live piggy with the hatch OPEN at lock level 0, photographed
				-- from behind. The bore shows the pig's own inner wall with the
				-- coin pile standing in it, and no window through to the street.
				-- It buys drawing this body's 6,368 triangles once instead of
				-- twice, on the object every plot on the map carries.
				--
				-- IF A LATER BODY IS EVER EXPORTED WITHOUT SOLIDIFY, this comes
				-- back -- `blender/pig/build_pig.py` gives the shell its wall, and
				-- a zero-thickness one needs backfaces again.
			end
			made[entry.part] = part
		end
		return made
	end)

	if not ok then
		-- NEVER FAIL SILENTLY. A pig that quietly stayed as primitives after
		-- somebody pasted four ids is indistinguishable from ids that did not
		-- take, and this file's own rule is that a rejection nobody can see
		-- is the same as a broken feature.
		warn(("[PiggyBank] piggy mesh could not be loaded, so the primitives "
			.. "piggy is standing instead: %s"):format(tostring(result)))
		return nil
	end

	meshTemplates = result
	return meshTemplates
end

-- Replaces the body sphere, snout, ears, legs and tail with the four MeshParts.
-- Returns false and changes nothing when there are no ids, which is the
-- default state of the repo.
--
-- THE NEW PARTS TAKE THE OLD PARTS' NAMES, which is what keeps this swap from
-- reaching into `applySkin` or ClientMain at all. `Snout`, `Ear` and `Tail`
-- are already what the trim list collects and what ANIMATED_TRIM drives, so a
-- meshed pig is coloured and animated by the code that was there before the
-- mesh existed. The primitives are therefore destroyed BEFORE the meshes are
-- seated -- two parts called `Snout` in one model is the `Finial` trap this
-- project has already hit, where a lookup by name silently returns whichever
-- one happens to be first.
local function swapToMesh(refs: Refs): boolean
	local spec = Config.piggyMesh()
	local templates = spec and ensureMeshTemplates()
	if not (spec and templates) then
		return false
	end

	local origin = refs.origin
	local old = refs.body

	-- The primitives the mesh now contains. Found by name off the model rather
	-- than only through `refs`, because the four legs and two ears are lists
	-- and a missed one is a cylinder standing inside a smooth leg.
	--
	-- THE COIN SLOT IS BACK ON THAT LIST, BECAUSE THE GENERATOR CUT ONE.
	--
	-- This has been both ways round twice now, so the rule rather than the
	-- history: the primitive goes when the MESH CONTAINS THE THING IT DRAWS,
	-- and stays when it does not. The old body had a shallow groove sculpted
	-- down its spine and no opening, so a dark bar lowered into that groove
	-- was the only slot there was. This one was asked for "a narrow
	-- rectangular coin slot cut into the top of the back" and came back with
	-- a real one -- photographed from above, a genuine slit with the hollow
	-- interior dark inside it. A drawn bar laid on top of that is a second
	-- slot beside the real one.
	--
	-- Same call the snout and the ears have always made.
	for _, child in ipairs(refs.model:GetChildren()) do
		if child:IsA("BasePart")
			and (child.Name == "Snout" or child.Name == "Ear"
				or child.Name == "Leg" or child.Name == "Tail"
				or child.Name == "Slot") then
			child:Destroy()
		end
	end

	local made: { [string]: BasePart } = {}
	local bodyEntry
	for _, entry in ipairs(spec) do
		local template = templates[entry.part]
		if not template then
			warn(("[PiggyBank] no mesh template for %q"):format(entry.part))
			return false
		end
		local p = template:Clone()
		p.Name = entry.part
		-- SIZE BEFORE CFRAME. Resizing a MeshPart scales it about its own
		-- centre, so a part seated first and sized second ends up seated for
		-- the size it used to be.
		p.Size = entry.size
		-- The turn is applied AFTER the seat and in the part's own frame, so
		-- the far row's half-turn -- one PivotTo over the whole plot, long
		-- after this runs -- still carries the tail round with everything
		-- else. A rotation folded into the world seat would not.
		p.CFrame = CFrame.new(origin + entry.offset) * (entry.rot or CFrame.identity)
		p.Anchored = true
		p.CastShadow = false
		p.CanCollide = false
		p.CanQuery = false
		p.Parent = refs.model
		made[entry.part] = p
		if not entry.trim then
			bodyEntry = entry
		end
	end

	-- ONLY THE BODY IS REQUIRED, AND THAT IS THE MODELLED PIG ARRIVING.
	--
	-- This asked for `Snout`, `Tail` AND `Ear` as well, which was right for as
	-- long as every mesh piggy was four generated parts. The modelled body is
	-- ONE MeshPart, so the guard refused a spec that was perfectly good --
	-- after the loop above had already parented the body, which is the worst
	-- shape it could fail in: the mesh was standing in the pig and every
	-- landmark that follows was skipped, so the eyes, the nostrils and the
	-- dial all stayed where the BALL pig had put them, on a body that is two
	-- studs shorter. Nothing errored and the log said the swap was off while
	-- a mesh was plainly standing there.
	--
	-- The trim parts are optional now and `refs` says so below.
	local body = made.Body
	if not (body and bodyEntry) then
		warn("[PiggyBank] piggy mesh has no Body part, so the swap is off")
		return false
	end

	-- The old sphere is carrying the steal prompt, both lights and all three
	-- emitters, and every one of those is held by reference elsewhere in this
	-- file -- so they are MOVED rather than rebuilt. Rebuilding would hand
	-- `refs.glow` and `refs.stealPrompt` instances that are no longer in the
	-- world, which is the "a destroyed instance still answers property reads"
	-- trap one level up: nothing would error and nothing would work.
	for _, child in ipairs(old:GetChildren()) do
		child.Parent = body
	end

	body.CanCollide = old.CanCollide
	body.CanQuery = old.CanQuery

	refs.model.PrimaryPart = body
	old:Destroy()

	refs.body = body :: any
	-- NIL WHEN THE BODY IS ONE PART, which `applySkin` reads to decide what
	-- the skin's second tone is painted onto. A modelled pig has no separate
	-- ear or snout mesh, so there is nothing to paint and the trim tone goes
	-- unused rather than being written into a destroyed primitive.
	refs.snout = made.Snout :: any
	refs.tail = made.Tail :: any
	-- `Ear` IS THE PRIMITIVES' NAME AND `Ears` IS THE SPLIT MESH'S, and both
	-- are read rather than one being renamed. The primitives pig builds a part
	-- per ear; the split trim is one mesh holding both, because they are
	-- always the same colour and two uploads to say that would be one too
	-- many. A rename would have been the tidier diff and would have broken the
	-- pig this game currently ships.
	refs.ears = if made.Ear then { made.Ear }
		elseif made.Ears then { made.Ears }
		else {}
	-- THE WHOLE SECOND TONE ON ONE PART. The modelled pig is a `Body` and a
	-- `Trim`, so the ears, snout, legs and tail a skin paints are one MeshPart
	-- rather than four -- and `applySkin` needs a handle on it or the trim
	-- colour is computed and thrown away, which is the state the last body
	-- shipped in.
	refs.trim = made.Trim :: any
	-- ON THE SPLIT TRIM THE LEGS ARE THEIR OWN MESH, and on the joined one
	-- they are inside `Trim` -- so this is a lookup rather than an empty
	-- literal now. Empty when neither exists, which is the primitives pig,
	-- where the legs are BODY-coloured.
	refs.legs = if made.Legs then { made.Legs } else {}

	-- THE RIM AND THE DARK DISC BOTH GO AGAIN, AND THIS TIME THE HOLE IS
	-- REAL, WHICH IS THE DIFFERENCE THAT MAKES IT THE RIGHT CALL.
	--
	-- Last time they were destroyed it was a bug, and that entry is worth
	-- keeping in mind right here: `buildLock`'s own comment says "a recess is
	-- made by standing something PROUD around the dark, never by sinking the
	-- dark -- the eye takes the highest line as the surface. Set flush
	-- instead, IT IS A BLACK STICKER." Kill the rim and the disc IS flush by
	-- definition, so what was left was a black marking painted on the pig's
	-- backside -- reported as exactly that.
	--
	-- WHAT CHANGED IS THAT THERE IS NOW SOMETHING TO STAND AROUND. The hatch
	-- is bored out of the body itself, so the pig's own surface is the lip and
	-- what is dark inside it is the actual hollow with the coin pile at the
	-- bottom of it. A drawn disc would be a black sticker laid over a real
	-- opening, and twelve flat rim segments would be a fake lip around a true
	-- one.
	--
	-- Everything that REMAINS on the dial -- the plate, the wheel, the spokes
	-- -- is pushed out onto the skin, or it sits two and a third studs inside
	-- the pig.
	if refs.lock then
		for _, piece in ipairs(refs.lock:GetChildren()) do
			if piece.Name == "VaultRim" or piece.Name == "VaultHole" then
				piece:Destroy()
			elseif piece:IsA("BasePart") then
				piece.CFrame = piece.CFrame * CFrame.new(MESH_DIAL_OUT, 0, 0)
			end
		end
	end

	-- The face, moved off the ball and onto the mesh. Found by NAME off the
	-- model rather than through `refs`, because the eyes and the
	-- plaster are both pairs and a missed one is a dark spot floating inside a
	-- pig -- the `Finial` trap this project has already hit twice.
	local faceCentre = origin + MESH_FACE.bodyCentre
	local seen = { Eye = 0, Plaster = 0 }
	for _, child in ipairs(refs.model:GetChildren()) do
		if child:IsA("BasePart") and seen[child.Name] ~= nil then
			seen[child.Name] += 1
			-- The sign of the ORIGINAL x is what says which side a pair member
			-- is on, so a mirrored seat cannot get the two the wrong way round.
			local side = if (child.Position - origin).X < 0 then -1 else 1
			if child.Name == "Eye" then
				local e = MESH_FACE.eye
				child.CFrame = CFrame.new(origin + Vector3.new(side * e.x, e.y, e.z))
			else
				-- Both strips share one seat and keep their own crossed spin,
				-- which is carried in the rotation they were built with. The
				-- second is nudged out a hair so the two cannot z-fight where
				-- they cross, exactly as `build` does.
				local frame = CFrame.lookAt(origin + MESH_FACE.plaster, faceCentre)
				local spin = if seen.Plaster == 1 then 45 else -45
				child.CFrame = frame * CFrame.Angles(0, 0, math.rad(spin))
				if seen.Plaster == 2 then
					child.CFrame = child.CFrame * CFrame.new(0, 0, -0.02)
				end
			end
		end
	end

	refs.bodySize = bodyEntry.size
	refs.patternSeat = CFrame.new(Vector3.new(0, BODY_Y, 0) - bodyEntry.offset)
	return true
end

-- ============================================================
-- SHARED BY BOTH BUILDERS
-- ============================================================
--
-- A piggy bank and a shop vault are two objects and one INTERFACE, so the
-- pieces that carry the interface rather than the shape are built once here.
-- A second near-identical copy is the thing that drifts the first time
-- either is touched -- the lesson `RideSound` learned by keeping its own copy
-- of the ride-key grammar and breaking within the hour.

-- Parented to the body so they are positional. Neighbours hearing your piggy
-- chime is deliberate: it tells a thief where the money is, which turns
-- feedback into information.
local function addSounds(body: BasePart): { [string]: Sound }
	local sounds: { [string]: Sound } = {}
	local function addSound(key: string, id: string, volume: number, distance: number)
		local sound = Instance.new("Sound")
		sound.Name = key
		sound.SoundId = id
		sound.Volume = volume
		sound.RollOffMaxDistance = distance
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.Parent = body
		sounds[key] = sound
	end
	addSound("drop", Config.SOUNDS.COIN_DROP, 0.35, 45)
	addSound("milestone", Config.SOUNDS.MILESTONE, 0.5, 80)
	addSound("bank", Config.SOUNDS.BANK, 0.6, 70)
	addSound("alarm", Config.SOUNDS.ALARM, 0.7, 140)
	return sounds
end

-- Fired in bursts on milestones, banking and the alarm.
-- The smash prompt, built once for both kinds of bank.
--
-- IT IS A FUNCTION RATHER THAN TWO BLOCKS FOR THE REASON THE VAULT ITSELF IS
-- `PiggyBank.buildVault`: a piggy and a strongroom are one thing in fourteen
-- places, and a second copy of six properties is a second copy that drifts
-- the first time either is touched.
--
-- ON ITS OWN KEY, AND THAT IS THE LOAD-BEARING PROPERTY. Every prompt in this
-- game is `E` and `OnePerButton`, so two prompts on one key do not both work
-- -- this project has that measured, from the shop door reaching 9.9 studs
-- into its own room and silently winning against the vault behind it. `G` is
-- the free key: the map is Q dodge/trick, B shop, V garage, R radio, I bag,
-- Escape close, F2 admin, 1-0 the hot bar, and F is the crack's own tap. E
-- opens the lock, F works it, G breaks it -- three adjacent keys for the
-- three things you can do to a pig, which is an accident and a welcome one.
local function buildSmashPrompt(body: BasePart, objectText: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SmashPrompt"
	prompt.ActionText = "Smash It"
	Config.setPromptKind(prompt, "smash")
	prompt.ObjectText = objectText
	prompt:SetAttribute(Config.PROMPT_SLOT_ATTRIBUTE, 1)
	prompt.KeyboardKeyCode = Enum.KeyCode.G
	-- LONGER THAN THE STEAL PROMPT'S OPEN HOLD, deliberately. That one opens a
	-- lock and can be walked away from having taken nothing; this one IS the
	-- robbery, and it drops your shield, wakes the dog and names you to the
	-- owner on a single press. See `Config.SMASH.hold`.
	prompt.HoldDuration = Config.SMASH.hold
	prompt.MaxActivationDistance = Config.STEAL_RANGE
	prompt.RequiresLineOfSight = false
	-- The client enables it exactly where it enables the steal prompt, and the
	-- server re-checks ownership on every trigger regardless.
	prompt.Enabled = false
	prompt.Parent = body
	return prompt
end

local function buildBurst(body: BasePart): ParticleEmitter
	local burst = Instance.new("ParticleEmitter")
	burst.Name = "Burst"
	burst.Texture = SPARKLE
	burst.Color = ColorSequence.new(COIN_GOLD_2, COIN_GOLD)
	burst.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	burst.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	burst.Lifetime = NumberRange.new(0.6, 1.2)
	burst.Rate = 0
	burst.Speed = NumberRange.new(9, 18)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Acceleration = Vector3.new(0, -22, 0)
	burst.LightEmission = 0.8
	burst.Enabled = false
	burst.Parent = body
	return burst
end

function PiggyBank.build(origin: Vector3, parent: Instance): Refs
	local model = Instance.new("Model")
	model.Name = "PiggyBank"

	local function at(x: number, y: number, z: number): Vector3
		return origin + Vector3.new(x, y, z)
	end

	local centre = at(0, BODY_Y, 0)

	-- Body ------------------------------------------------------------
	local body = part("Body", model, Vector3.new(BODY_R * 2, BODY_R * 2, BODY_R * 2), CFrame.new(centre))
	body.Shape = Enum.PartType.Ball
	body.CanCollide = true
	body.CanQuery = true

	local coins, pile = buildCoinPile(centre + Vector3.new(0, COIN_CENTRE_OFFSET, 0), model)

	-- Lights the pile from inside. With an opaque body this stopped being a
	-- glow THROUGH the shell and became light spilling OUT of the hatch and
	-- the coin slit, which is the better signal of the two -- and it is what
	-- carries the top of the range, where the pile has risen past the top of
	-- the aperture and the hatch reads as packed whatever else goes in.
	-- Brightness tracks the fill, and `Shadows` is false, so it still lights
	-- the pig from across the map.
	local glow = Instance.new("PointLight")
	glow.Name = "Glow"
	glow.Color = COIN_GOLD
	glow.Brightness = 0
	glow.Range = 8
	glow.Shadows = false
	glow.Parent = body

	-- Particles -------------------------------------------------------
	-- Ambient trickle at the coin slot: the visual for "you are earning".
	local drip = Instance.new("ParticleEmitter")
	drip.Name = "Drip"
	drip.Texture = SPARKLE
	drip.Color = ColorSequence.new(COIN_GOLD_2, COIN_GOLD)
	drip.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	drip.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	drip.Lifetime = NumberRange.new(0.5, 0.9)
	drip.Rate = 3
	drip.Speed = NumberRange.new(1.5, 3)
	drip.SpreadAngle = Vector2.new(18, 18)
	drip.Acceleration = Vector3.new(0, -6, 0)
	drip.LightEmission = 0.6
	drip.Parent = body

	-- Cosmetic aura, driven entirely by the equipped effect. Off by default.
	--
	-- Emitted from the SURFACE of the body sphere, outward, so every cosmetic
	-- reads as a halo wrapping the piggy. The coin drip and milestone burst
	-- both emit from inside the same part -- with only three built-in particle
	-- textures to go around, emission shape is what keeps a paid effect from
	-- looking like the free coin feedback.
	local aura = Instance.new("ParticleEmitter")
	aura.Name = "Aura"
	aura.Enabled = false
	aura.Shape = Enum.ParticleEmitterShape.Sphere
	aura.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	aura.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	aura.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	aura.LightEmission = 0.55
	aura.Parent = body

	-- THE SKIN'S OWN AURA, WHICH IS A SECOND EMITTER RATHER THAN A SECOND USE
	-- OF THE FIRST. A legendary skin carries particles of its own and they
	-- STACK with whatever the player equipped, so the two cannot share an
	-- emitter -- one object has one Texture, one Color and one Rate.
	--
	-- Built here beside its sibling and always present, for the reason the
	-- tier-0 dog is built and hidden rather than skipped: a nil in `Refs` is a
	-- crash rather than a missing feature, and this one is read by
	-- `applySkin` and `applyEffect` both.
	--
	-- INWARD RATHER THAN OUTWARD, which is the one property that differs and
	-- is doing real work. With only three built-in particle textures, emission
	-- SHAPE is what keeps two effects on one animal from reading as one noisy
	-- one -- the note above says exactly that about the drip and the aura. An
	-- equipped effect blooms outward off the surface; a skin's own aura falls
	-- inward toward it, so a legendary reads as something coming OFF the
	-- animal rather than as a second copy of the same cloud.
	local skinAura = Instance.new("ParticleEmitter")
	skinAura.Name = "SkinAura"
	skinAura.Enabled = false
	skinAura.Shape = Enum.ParticleEmitterShape.Sphere
	skinAura.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	skinAura.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
	skinAura.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	skinAura.LightEmission = 0.55
	skinAura.Parent = body

	-- Separate from `Glow`, which EconomyService drives to show vault fill.
	-- Sharing one light would make a full vault and a lit effect fight over
	-- the same property every frame.
	local auraLight = Instance.new("PointLight")
	auraLight.Name = "AuraLight"
	auraLight.Enabled = false
	auraLight.Shadows = false
	auraLight.Parent = body

	-- Fired in bursts on milestones and banking.
	local burst = buildBurst(body)

	-- Sounds ----------------------------------------------------------
	-- Parented to the body so they're positional. Neighbours hearing your
	-- piggy chime is deliberate: in phase 3 it tells a thief where the
	-- money is, which turns feedback into information.
	local sounds = addSounds(body)

	-- Snout -----------------------------------------------------------
	local snout = part("Snout", model, Vector3.new(2, SNOUT_D, SNOUT_D), cylinderForward(at(0, BODY_Y + SNOUT_Y, BODY_R - 0.4)))
	snout.Shape = Enum.PartType.Cylinder
	snout.Color = PINK_DARK

	-- The mesh snout already has sculpted nostril recesses; no black inserts.

	-- Face ------------------------------------------------------------
	for _, offset in ipairs({ -1, 1 }) do
		local eye = part("Eye", model, Vector3.new(1.25, 1.25, 1.25), CFrame.new(at(offset * 2.35, BODY_Y + 2.1, BODY_R - 1.1)))
		eye.Shape = Enum.PartType.Ball
		eye.Color = NEAR_BLACK
		eye.Material = Enum.Material.SmoothPlastic
	end

	-- Ears are wedges, not blocks. A wedge's triangular faces sit on its X
	-- sides, so rotating 90 degrees about Y turns them to face the camera and
	-- gives the pointed silhouette that reads as "pig" at a distance.
	local ears: { BasePart } = {}
	for _, offset in ipairs({ -1, 1 }) do
		local ear = Instance.new("WedgePart")
		ear.Name = "Ear"
		ear.Size = Vector3.new(0.9, 2.9, 2.5)
		ear.CFrame = CFrame.new(at(offset * 3.2, BODY_Y + 5.1, 1.9))
			* CFrame.Angles(0, math.rad(90), math.rad(offset * 14))
		ear.Anchored = true
		ear.CanCollide = false
		ear.CanQuery = false
		ear.Color = PINK_DARK
		ear.Parent = model
		table.insert(ears, ear)
	end

	-- Legs ------------------------------------------------------------
	--
	-- Length is derived from the body sphere, never hard-coded. The body is a
	-- ball, so its underside climbs steeply away from the centre line: at the
	-- legs' corner offset it sits about 1.9 studs higher than at the middle.
	-- A fixed 2.5-stud leg therefore stopped 1.4 studs short of the body and
	-- every foot hung in mid-air.
	--
	-- `legReach` measures to the leg's OUTER edge rather than its axis, so the
	-- whole top face is buried in the body and no seam opens up when you walk
	-- around the plot. Any future change to BODY_R, BODY_Y or LEG_X now
	-- re-solves this instead of silently detaching the legs again.
	local legs: { Part } = {}
	local legReach = math.sqrt(LEG_X * LEG_X * 2) + LEG_D / 2
	-- The +0.25 buries the top slightly rather than leaving it exactly tangent
	-- to the sphere, so rounding can't open a hairline gap at the outer edge.
	local legTop = BODY_Y - math.sqrt(math.max(BODY_R * BODY_R - legReach * legReach, 0)) + 0.25
	local legHeight = legTop - GROUND_Y

	for _, x in ipairs({ -LEG_X, LEG_X }) do
		for _, z in ipairs({ -LEG_X, LEG_X }) do
			-- Narrow, or a cylinder this short just reads as a cube.
			local leg = part("Leg", model, Vector3.new(legHeight, LEG_D, LEG_D),
				cylinderUp(at(x, GROUND_Y + legHeight / 2, z)))
			leg.Shape = Enum.PartType.Cylinder
			leg.Color = PINK_DARK
			table.insert(legs, leg)
		end
	end

	-- Tail ------------------------------------------------------------
	local tail = part("Tail", model, Vector3.new(1.7, 1.7, 1.7), CFrame.new(at(0, BODY_Y + 1.2, -BODY_R - 0.4)))
	tail.Shape = Enum.PartType.Ball
	tail.Color = PINK_DARK

	-- Coin slot -------------------------------------------------------
	-- Buried in the dome and showing only where its ends break the curve,
	-- which is the one thing that works on a sphere. THE MESH PIGGY DESTROYS
	-- IT: that body has a real slit cut through its crown by the generator,
	-- and a drawn bar on top of one is a second slot beside the real one.
	local slot = part("Slot", model, Vector3.new(0.7, 0.45, 4.2), CFrame.new(at(0, BODY_Y + BODY_R - 0.3, 0)))
	slot.Color = NEAR_BLACK
	slot.Material = Enum.Material.SmoothPlastic

	-- Vault dial ------------------------------------------------------
	--
	-- The lock upgrade already worked -- it triples the crack time -- but a
	-- ProximityPrompt draws the same filling circle whether it takes three
	-- seconds or nine, so nothing about it was visible. A defender could not
	-- see what they had bought and a thief could not see what they were up
	-- against. This is that mechanic given a body.
	--
	-- It used to be a padlock on top of the coin slot, and that was wrong
	-- twice over. It sat at (0, 15.2, 0) -- which is the HAT ANCHOR, so every
	-- hat in the game spawned inside it -- and its shackle was a cylinder
	-- written Vector3.new(1.5, 1.5, 0.55), a 1.5-long rod turned to point at
	-- the camera rather than a U over the body, so the one cue that says
	-- "padlock" was never actually built. It read as a grey lump.
	--
	-- A safe dial says the same thing without needing to be identified, and
	-- the body has room for it where the head does not.
	local lock = Instance.new("Model")
	lock.Name = "VaultLock"

	-- The plate is the mount, and it never moves: every other piece of the
	-- dial is positioned from its CFrame, and the spin in rattleLock turns
	-- about its X axis. Size and colour change with the tier; the CFrame does
	-- not, which is what lets the wheel be rebuilt without recomputing where
	-- the dial lives.
	-- THE HOLE IS ALWAYS THERE; THE LOCK IS WHAT COVERS IT.
	--
	-- Nothing in this world can be DUG -- a Part cannot cut a hole in another
	-- Part -- so the opening is the same illusion the moat uses: a near-black
	-- disc with a rim standing proud of it, because the eye takes the highest
	-- line as the surface and reads everything inside it as depth. Set flush
	-- instead, it is a black sticker.
	--
	-- Built once at full size and never resized, so an unlocked piggy and a
	-- gold-locked one have the same opening and only the door changes.
	local seat = dialCFrame(origin)

	local hole = part("VaultHole", lock, Vector3.new(0.30, VAULT_R * 2, VAULT_R * 2),
		seat * CFrame.new(0.02, 0, 0))
	hole.Shape = Enum.PartType.Cylinder
	hole.Color = Color3.fromRGB(18, 14, 16)
	hole.Material = Enum.Material.SmoothPlastic

	-- THE RIM IS A RING OF SEGMENTS, because one cylinder cannot be an annulus
	-- and a solid disc in front of the hole simply covers it -- which is what
	-- the first build did, hiding the whole opening behind a pale lid.
	--
	-- It stands PROUD of the dark disc, which is the entire illusion: nothing
	-- in this world can be dug, so a recess is made by putting a lip AROUND
	-- the dark rather than sinking the dark, and the eye takes the highest
	-- line as the surface. Exactly the moat's kerbs, at a twentieth of the
	-- scale.
	for i = 0, RIM_SEGMENTS - 1 do
		local a = (i / RIM_SEGMENTS) * math.pi * 2
		local r = VAULT_R + 0.16
		-- ROTATED TO LIE TANGENT, not radial. A segment sits at
		-- (sin a, cos a) * r in the seat's YZ plane, so its radius direction
		-- is that vector and its TANGENT is (cos a, -sin a). Turning by -a
		-- maps the segment's long axis onto the radius instead, which builds
		-- a sunburst of spikes rather than a ring -- measured by looking at
		-- twelve of them sticking straight out of the pig.
		local seg = part("VaultRim", lock,
			Vector3.new(0.42, 0.30, (2 * math.pi * r) / RIM_SEGMENTS + 0.10),
			seat * CFrame.new(0.16, math.sin(a) * r, math.cos(a) * r)
				* CFrame.Angles(-a - math.pi / 2, 0, 0))
		seg.Color = PINK_DARK
		seg.Material = Enum.Material.SmoothPlastic
	end

	local plate = part("DialPlate", lock, Vector3.new(DIAL_THICK, DIAL_MAX_R * 2, DIAL_MAX_R * 2),
		seat)
	plate.Shape = Enum.PartType.Cylinder
	plate.Material = Enum.Material.Metal
	plate.Transparency = 1 -- setLockLevel owns whether it shows

	lock.PrimaryPart = plate
	lock.Parent = model

	-- THE PLASTER: two crossed strips on the forehead, hidden until somebody
	-- gets in. A tell for the street and nothing else -- see
	-- Config.ROBBED_MARK_SECONDS. Placed BY DIRECTION on the body sphere like
	-- the eyes and the mottling, half sunk, so it sits on the curve rather
	-- than floating off it: above the eyes (which top out at BODY_Y + 2.7)
	-- and in front of the ears (which start at z 1.9).
	do
		local dir = Vector3.new(0, 0.62, 0.78).Unit
		-- Seated a shade INSIDE the surface, because a flat strip on a sphere
		-- only touches it in the middle: measured, at +0.03 every corner of
		-- the strip stood 0.06 to 0.24 off the skin. At -0.06 the middle is
		-- sunk and the ends stand about a tenth proud, which is a plaster
		-- stuck to a curve rather than one hovering over it.
		local seat = centre + dir * (BODY_R - 0.06)
		-- lookAt points -Z at the centre, so the strip's thin axis is the
		-- surface normal and its long axis lies along the surface.
		local frame = CFrame.lookAt(seat, centre)
		for i, spin in ipairs({ 45, -45 }) do
			local strip = part("Plaster", model, Vector3.new(2.4, 0.7, 0.16),
				frame * CFrame.Angles(0, 0, math.rad(spin)))
			strip.Color = Color3.fromRGB(226, 196, 156)
			strip.Material = Enum.Material.SmoothPlastic
			strip.Transparency = 1
			-- The second strip sits a hair further out so the two cannot
			-- z-fight where they cross.
			if i == 2 then
				strip.CFrame = strip.CFrame * CFrame.new(0, 0, -0.02)
			end
		end
	end

	-- Interaction -----------------------------------------------------
	-- There is no collect prompt: the pig is the wallet and nothing is
	-- banked. The steal prompt exists on every piggy and the client enables it
	-- for everybody but the owner. The server never trusts that choice -- it
	-- re-checks ownership on every trigger.
	local stealPrompt = Instance.new("ProximityPrompt")
	stealPrompt.Name = "StealPrompt"
	stealPrompt.ActionText = "Steal Coins"
	Config.setPromptKind(stealPrompt, "steal")
	stealPrompt.ObjectText = "Piggy Bank"
	-- Half a second: this hold OPENS the lock, it no longer robs it. What
	-- comes after is Config.CRACK, where the Vault Lock tree now expresses
	-- itself -- so a long hold here would charge for that upgrade twice.
	stealPrompt.HoldDuration = Config.CRACK.openHold
	stealPrompt.MaxActivationDistance = Config.STEAL_RANGE
	stealPrompt.RequiresLineOfSight = false
	stealPrompt.Enabled = false
	stealPrompt.Parent = body

	local smashPrompt = buildSmashPrompt(body, "Piggy Bank")

	model.PrimaryPart = body
	model.Parent = parent

	local refs: Refs = {
		origin = origin,
		model = model,
		body = body,
		pile = pile,
		coins = coins,
		shown = 0,
		glow = glow,
		drip = drip,
		burst = burst,
		aura = aura,
		skinAura = skinAura,
		snout = snout,
		tail = tail,
		ears = ears,
		legs = legs,
		lock = lock,
		stealPrompt = stealPrompt,
		smashPrompt = smashPrompt,
		sounds = sounds,
	}

	-- BEFORE applySkin, so the skin colours whatever is actually standing
	-- there. A no-op unless both mesh ids are filled in.
	swapToMesh(refs)

	PiggyBank.applySkin(refs, Config.DEFAULT_SKIN)
	PiggyBank.applyEffect(refs, Config.DEFAULT_EFFECT)
	return refs
end

-- ============================================================
-- THE SHOP VAULT
-- ============================================================

-- The strongroom on a shop's back wall, returned as the SAME `Refs` a piggy
-- bank is.
--
-- THAT IS THE WHOLE TRICK AND IT IS WORTH BEING EXACT ABOUT WHAT IT BOUGHT.
-- `plot.piggy` is read in fourteen places across three services -- the fill,
-- the dial, the rattle, the plaster, the coin drop, the milestone, the
-- alarm, the raid drone's anchor, the crack panel's camera and the steal
-- prompt -- and not one of them changed. `VaultModel` builds a carcass, a
-- mouth, a stack of `Config.COIN_COUNT` bars and a door with a dial seat on
-- it; this function wraps those in the fields those fourteen readers want,
-- and every behaviour above runs unmodified on different parts.
--
-- The alternative was a second module with the same ten function names and a
-- `bankOf(plot)` dispatch at every call site, which is nine accessors with a
-- piggy-shaped hole under each one -- the exact trade the shops refused
-- when they became plots rather than a third kind of `HeistService.Target`.
-- WHEN A NEW THING HAS TO BEHAVE LIKE AN EXISTING THING IN FOURTEEN PLACES,
-- MAKE IT ONE.
--
-- WHAT IT COSTS IS ONE FLAG, `Refs.vault`, read by exactly three functions:
-- the skin, the accessories and the effect. A vault wears nothing, and those
-- are the only three things a piggy does that a strongroom cannot.
--
-- Takes a CFrame rather than a position, because a vault is TURNED -- it
-- stands on the back wall of a unit that faces the road, and the far row of
-- shops carries a half turn. `PiggyBank.build` can take a bare Vector3 only
-- because a pig is authored symmetrically about its own centre.
function PiggyBank.buildVault(cf: CFrame, parent: Instance): Refs
	local v = VaultModel.build(cf, parent)
	local body = v.body

	-- LIT FROM INSIDE THE MOUTH, WHICH IS THE ONE PLACE THE PIG'S OWN LAMP
	-- COULD NOT BE. That light sits inside a solid body with `Shadows` off,
	-- so it washes the shell it is meant to be seen through -- the measured
	-- reason it came down to a fifth of what it was. Here the opening is a
	-- real one and the light spills OUT of it, which is what the piggy's
	-- glow was doing for the one release its hatch was a genuine bore.
	local glow = Instance.new("PointLight")
	glow.Name = "Glow"
	glow.Color = COIN_GOLD
	glow.Brightness = 0
	glow.Range = 9
	glow.Shadows = false
	glow.Parent = v.mouth

	-- The takings going in. Same cadence as the pig's, because it is the same
	-- drip: `setFill` drives its rate off the fill ratio and nothing here
	-- knows which object it is standing on.
	local drip = Instance.new("ParticleEmitter")
	drip.Name = "Drip"
	drip.Texture = SPARKLE
	drip.Color = ColorSequence.new(COIN_GOLD_2, COIN_GOLD)
	drip.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0),
	})
	drip.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	drip.Lifetime = NumberRange.new(0.5, 0.9)
	drip.Rate = 3
	drip.Speed = NumberRange.new(1.5, 3)
	drip.SpreadAngle = Vector2.new(18, 18)
	drip.Acceleration = Vector3.new(0, -6, 0)
	drip.LightEmission = 0.6
	drip.Parent = body

	local burst = buildBurst(body)
	local sounds = addSounds(body)

	-- BUILT AND NEVER ENABLED, and that is honest rather than lazy. `aura` is
	-- the cosmetic effect emitter and `applyEffect` returns early on a vault,
	-- so nothing will ever switch this on -- it exists because the field is
	-- what makes one `Refs` serve both, and one disabled emitter per shop is
	-- a cheaper price than a nil that four callers would have to guard.
	local aura = Instance.new("ParticleEmitter")
	aura.Name = "Aura"
	aura.Enabled = false
	aura.Parent = body

	-- THE DIAL, ON THE DOOR, BUILT BY THE PIGGY'S OWN LADDER.
	--
	-- `setLockLevel` rebuilds a wheel around whatever `lock.PrimaryPart` is,
	-- reading the metal and the spoke count out of `LOCK_TIERS` -- so a shop
	-- vault and a piggy bank say their tier in exactly the same vocabulary,
	-- and a maxed Lockpicks reading a lock from the pavement means the same
	-- thing at both. Two ladders wearing one set of colours is the failure
	-- this file records for the rarity bands; one ladder read twice is not.
	local lock = Instance.new("Model")
	lock.Name = "Lock"
	local plate = part("DialPlate", lock,
		Vector3.new(DIAL_THICK, DIAL_MAX_R * 2, DIAL_MAX_R * 2), v.dialSeat)
	plate.Shape = Enum.PartType.Cylinder
	plate.Material = Enum.Material.Metal
	plate.Transparency = 1 -- setLockLevel owns whether it shows
	lock.PrimaryPart = plate
	lock.Parent = v.model

	local stealPrompt = Instance.new("ProximityPrompt")
	stealPrompt.Name = "StealPrompt"
	stealPrompt.ActionText = "Steal Coins"
	Config.setPromptKind(stealPrompt, "steal")
	-- NAMED FOR WHAT IT IS. The prompt card prints this over the verb, and a
	-- strongroom in the back of a shop reading "Piggy Bank" would be the one
	-- place in the game still insisting the noun had not changed.
	stealPrompt.ObjectText = "Shop Vault"
	stealPrompt.HoldDuration = Config.CRACK.openHold
	stealPrompt.MaxActivationDistance = Config.STEAL_RANGE
	stealPrompt.RequiresLineOfSight = false
	stealPrompt.Enabled = false
	stealPrompt.Parent = body

	-- A SHOP GETS THE PAIR TOO, AND IT IS THE CHEAPEST SMASH ON THE STREET --
	-- no dog to wake, nobody home to tell, so the alarm costs a thief almost
	-- nothing here. That is the shops being what this project already says they
	-- are: the fast, cheap, loud target against the house's slow, rich, quiet
	-- one, with the choice now available INSIDE one job as well as between two.
	local smashPrompt = buildSmashPrompt(body, "Shop Vault")

	return {
		origin = cf.Position,
		model = v.model,
		body = body,
		pile = v.pile,
		coins = v.bars,
		shown = 0,
		glow = glow,
		drip = drip,
		burst = burst,
		aura = aura,
		ears = {},
		legs = {},
		-- The milestone squash tweens back to this. Read from the part rather
		-- than assumed, for the reason the meshed pig already records: a
		-- hardcoded diameter snaps a carcass into a cube on its first
		-- milestone and then elastic-tweens it back to one.
		bodySize = body.Size,
		lock = lock,
		stealPrompt = stealPrompt,
		smashPrompt = smashPrompt,
		sounds = sounds,
		vault = true,
	}
end

-- ============================================================
-- APPEARANCE
-- ============================================================

-- What a surface pack is called once it is hanging on a part, so it can be
-- found again and taken off when the next skin does not want one.
local SURFACE_NAME = "SkinSurface"

-- Dress one part in a skin's surface pack, or strip whatever it is wearing.
--
-- REUSED RATHER THAN REBUILT, unlike the pattern decals below it. Those are
-- torn down every call because a stripe that accumulated would be a visible
-- bug; a SurfaceAppearance carries four texture ids, and destroying and
-- recreating it makes the engine drop and refetch all four every time
-- somebody tries a skin on in the shop.
--
-- MESHPARTS ONLY, which is not defensiveness. A SurfaceAppearance does
-- nothing on an ordinary Part, so on the primitives fallback pig -- the one
-- that stands up when a mesh id is missing -- attaching one would create
-- instances that silently do nothing on every piggy on the street. The pig
-- renders as a plain skin there instead, which is what the fallback is for.
-- `isTrim` PICKS A DIFFERENT TEMPLATE, AND IT IS NOT A REFINEMENT. The ears,
-- snout, tail and legs share the body's cylindrical unwrap, so handing them a
-- PATTERN map runs tiger bars across a snout and leopard rosettes down a leg.
-- An animal pack names a `trimTemplate` carrying the coat and no markings;
-- anything without one hands both the same template, which is what the metal
-- bands want and why this is opt-in rather than a branch on skin kind.
local function applySurface(part: BasePart, tier, isTrim: boolean?)
	local pack = Config.skinSurface(tier)
	local worn = part:FindFirstChild(SURFACE_NAME)

	if not pack or not part:IsA("MeshPart") then
		if worn then
			worn:Destroy()
		end
		return
	end

	-- CLONED, NEVER BUILT, AND THAT IS A REFUSAL RATHER THAN A PREFERENCE.
	-- `SurfaceAppearance.ColorMap` is plugin-gated: assembling one here threw
	-- `The current thread cannot write 'ColorMap' (lacking capability Plugin)`
	-- from a real server and took the whole of `applySkin` with it, so every
	-- skin change in the game failed. A clone copies the maps without writing
	-- them, which is the same escape `MaterialVariant` had to take.
	local template = ReplicatedStorage:FindFirstChild("Shared")
	template = template and template:FindFirstChild("SurfacePacks")
	template = template and template:FindFirstChild(
		(isTrim and pack.trimTemplate) or pack.template)
	if not template then
		-- A MISSING TEMPLATE IS A PLAIN PIG, NEVER AN ERROR. The skin still
		-- has its colours and its `material`, so what a player sees is an
		-- ordinary skin rather than a broken one -- the same way an empty mesh
		-- id leaves the piggy on primitives instead of standing up half a
		-- model.
		if worn then
			worn:Destroy()
		end
		return
	end

	-- REPLACED RATHER THAN PATCHED, because the properties that would need
	-- patching are the gated ones. Reusing the instance was the original
	-- design -- to stop the engine refetching four textures on every skin
	-- change -- and it is not available: there is no way to change a worn
	-- pack's maps without writing them.
	if worn then
		worn:Destroy()
	end
	local sa = template:Clone()
	sa.Name = SURFACE_NAME
	sa.Parent = part
end

-- ============================================================
-- RAISED FUR
-- ============================================================

local FUR_NAME = "FurTufts"

-- WHICH SET A WORN TUFT CAME FROM, WRITTEN ON THE PART ITSELF.
--
-- A skin is changed INTO rather than applied to a fresh pig, so going from
-- the tiger to the zebra has to SWAP the mesh and not merely recolour it --
-- and there is nothing on a MeshPart that says which set it was cloned from.
-- Comparing `MeshId` would work and is the wrong instrument: it reads an
-- asset id back out of the engine to answer a question about this game's own
-- catalogue, so an unfilled set (id "") has no id to compare and a re-upload
-- of the same mane would read as a different set. An attribute is the fact
-- itself. Same call `SkinKey` already makes on the body.
local FUR_SET_ATTRIBUTE = "FurSet"

-- ONE TEMPLATE PER SET, CACHED SEPARATELY. `CreateMeshPartAsync` yields and
-- there are ten pigs on a street, so this is the same cache the body and trim
-- already keep -- it just has to be keyed now, or the first set loaded would
-- be handed to every animal for the rest of the server's life.
local furTemplates: { [string]: BasePart } = {}
local furChecked: { [string]: boolean } = {}

local function ensureFurTemplate(setName: string): BasePart?
	if furChecked[setName] then
		return furTemplates[setName]
	end
	-- STAMPED BEFORE THE LOAD, NOT AFTER, so a set whose mesh fails to load is
	-- attempted once rather than on every skin change for the rest of the
	-- session -- which on a failing asset is a web call per pig per swap.
	furChecked[setName] = true
	local spec = Config.furMesh(setName)
	if not spec then
		return nil
	end
	local ok, part = pcall(function()
		-- BOX COLLISION AND NO QUERY, because this is decoration standing on
		-- the one object a thief runs at and a dog patrols around. Precise
		-- collision on 6,080 triangles of wool would cost every one of them a
		-- physics query to buy nothing.
		local p = game:GetService("InsertService"):CreateMeshPartAsync(
			spec.id, Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
		-- THE MESH KEEPS ITS OWN SIZE, AND CONFIG'S IS A CHECK RATHER THAN AN
		-- INSTRUCTION. Writing `Size` here scales the mesh to whatever number
		-- happens to be in Config -- so a value measured off an older build
		-- silently SHRINKS the tufts toward their own centre and buries them
		-- in the body, which is precisely what shipped. A wrong number should
		-- be loud; this one was invisible.
		if (p.MeshSize - spec.size).Magnitude > 0.05 then
			warn(string.format(
				"[PiggyBank] Config.FUR_SETS.%s.size is stale: mesh is %.4f,"
				.. " %.4f, %.4f but Config says %.4f, %.4f, %.4f -- re-run"
				.. " make_fur_tufts.py with FUR_SET=%s and paste the block it"
				.. " prints.",
				setName, p.MeshSize.X, p.MeshSize.Y, p.MeshSize.Z,
				spec.size.X, spec.size.Y, spec.size.Z, setName))
		end
		p.Name = FUR_NAME
		p:SetAttribute(FUR_SET_ATTRIBUTE, setName)
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		return p
	end)
	if not ok then
		-- NEVER FAIL SILENTLY, and never take the skin down with it. A pig
		-- with no ruff is a cosmetic fault; `applySkin` throwing is every
		-- skin change in the game failing, which is what the surface pack
		-- already cost once.
		warn(string.format("[PiggyBank] fur mesh for set %q failed to load: %s",
			setName, tostring(part)))
		return nil
	end
	furTemplates[setName] = part
	return part
end

-- Give this piggy its ruff, or take it off.
--
-- STRIPPED ON EVERY SKIN THAT DOES NOT WANT ONE, not only added to those that
-- do. A skin is changed INTO, so a conditional that only ever attaches would
-- leave a Solid Gold pig wearing the tiger's wool -- the same trap
-- `reflectance` already fell into on this function.
local function applyFur(refs: Refs, tier)
	local body = refs.body
	local model = body.Parent
	local worn = model and model:FindFirstChild(FUR_NAME)

	-- THE MESH IS THE FLAG. A skin asks for fur by carrying a `fur` colour,
	-- which is also the colour the lobes are painted -- one field rather than
	-- a boolean and a colour that could disagree.
	local wants = tier and tier.fur ~= nil and body:IsA("MeshPart")
	if not wants then
		if worn then
			worn:Destroy()
		end
		return
	end

	-- THE SET IS A PROPERTY OF THE SKIN AND FALLS BACK TO THE DEFAULT, so the
	-- four skins that predate sets carry no `furSet` and get the mane exactly
	-- as they always did.
	local setName = tier.furSet or Config.DEFAULT_FUR_SET

	-- A WORN TUFT FROM A DIFFERENT SET IS DESTROYED RATHER THAN REUSED, and
	-- this is the whole reason the attribute exists. Reusing it would recolour
	-- the tiger's ruff, seat it at the crest's offset and call it a zebra --
	-- geometry from one animal at another's coordinates, with nothing erroring.
	if worn and worn:GetAttribute(FUR_SET_ATTRIBUTE) ~= setName then
		worn:Destroy()
		worn = nil
	end

	local template = ensureFurTemplate(setName)
	if not template then
		if worn then
			worn:Destroy()
		end
		return
	end

	local part = worn
	if not part then
		part = template:Clone()
		part.Parent = model
	end
	part.Color = tier.fur
	part.Material = tier.material
	part.Transparency = tier.transparency

	-- THE RUFF WEARS THE BODY'S PACK, NOT THE TRIM'S, and that is the whole
	-- reason it can exist on a patterned animal at all. The lobe mesh is
	-- unwrapped on the SAME cylinder as the body, so handing it the body's
	-- ColorMap makes the spots and stripes carry straight over the fur --
	-- where a flat colour was a patch lying on top of the pattern whatever
	-- shade it was given. `false` rather than `true`: the trim template is the
	-- coat WITHOUT markings, which is right for a snout and wrong here.
	applySurface(part, tier, false)

	-- SEATED OFF THE BODY'S OWN CFRAME, never off the plot's. Both meshes come
	-- out of one Blender scene, so the fur's offset and the body's are in the
	-- same frame -- and the far row of plots carries a half turn, which is the
	-- error this file already records three times for anything measured in
	-- world axes.
	local spec = Config.furMesh(setName)
	part.CFrame = body.CFrame * CFrame.new(spec.offset)
end

-- The equipped skin owns the piggy's whole appearance. Rebirth-earned looks
-- are ordinary crate skins now, so there's one
-- system here rather than a tier system fighting a cosmetic one.
function PiggyBank.applySkin(refs: Refs, skinKey: string)
	-- A SHOP VAULT WEARS NOTHING, and this is the only place the two kinds
	-- of thing standing on a plot are told apart. A skin is colour and
	-- material on a piggy's body; run on a strongroom it would paint the
	-- carcass pink and hand it a snout it does not have.
	if refs.vault then
		return
	end

	local tier = Config.getSkin(skinKey)

	-- THE SKIN'S OWN AURA, DRIVEN FROM HERE RATHER THAN FROM `applyEffect`,
	-- because it is a fact about the SKIN and this is the one function that
	-- knows which skin is on. Put in `applyEffect` instead it would have to be
	-- re-derived from a key that function is not given, and the two would
	-- disagree the first time a skin changed without an effect changing.
	--
	-- IT RIDES `refs.vault` BY SITTING INSIDE THIS FUNCTION, which is the
	-- contract rather than a coincidence: a strongroom returns above, so it
	-- can never be reached with one. Relying instead on a vault having no skin
	-- to read an aura from would be leaning on a nil.
	--
	-- NO LIGHT IS TOUCHED HERE AT ALL -- see `Config.skinAura`. `AuraLight`
	-- belongs to the equipped effect and `Glow` belongs to the vault fill; a
	-- third source inside a twelve-stud sphere is the white-blob entry in
	-- CLAUDE.md with two more lamps on top.
	local sa = refs.skinAura
	if sa then
		local spec = Config.skinAura(tier)
		if spec and spec.texture then
			sa.Texture = spec.texture
			sa.Color = spec.color
			sa.Rate = spec.rate
			sa.Speed = spec.speed
			sa.Lifetime = spec.lifetime
			sa.Drag = spec.drag
			sa.Acceleration = spec.accel
			sa.SpreadAngle = Vector2.new(spec.spread, spec.spread)
			sa.Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, spec.size),
				NumberSequenceKeypoint.new(1, 0),
			})
			local spin = spec.rotSpeed or 0
			sa.Rotation = NumberRange.new(0, 360)
			sa.RotSpeed = NumberRange.new(-spin, spin)
			sa.Enabled = true
		else
			sa.Enabled = false
		end
	end

	refs.body.Color = tier.body
	refs.body.Material = tier.material
	refs.body.Transparency = tier.transparency
	-- REFLECTANCE IS WRITTEN ON EVERY SKIN, NOT ONLY ON THE ONES THAT WANT IT,
	-- and the `or 0` is the whole reason. A skin is CHANGED into rather than
	-- applied to a fresh pig, so a field left alone keeps whatever the last
	-- skin set -- switch off Solid Gold and an ordinary plastic pig would go
	-- on wearing its 0.45 for the rest of the session, with nothing in any log.
	-- Same shape as `Transparency` directly above, which is written on all 46
	-- for the same reason.
	refs.body.Reflectance = tier.reflectance or 0

	-- FOUR PARTS OR SEVEN, AND THE CALLER DOES NOT CARE WHICH. The mesh piggy
	-- names its trim meshes `Snout`, `Ear` and `Tail` -- the primitives' own
	-- names -- so this list is built the same way for both and there is no
	-- branch to keep in step. The mesh piggy's legs live inside the body
	-- mesh, so `refs.legs` is simply empty there.
	-- BUILT ONE AT A TIME BECAUSE TWO OF THEM CAN BE NIL. Written as a
	-- literal `{ refs.snout, refs.tail }` a nil snout makes the array start
	-- at a hole, and `ipairs` stops at the first one -- so a pig with a tail
	-- and no snout would silently paint neither.
	local trimParts: { BasePart } = {}
	if refs.trim then
		table.insert(trimParts, refs.trim)
	end
	if refs.snout then
		table.insert(trimParts, refs.snout)
	end
	if refs.tail then
		table.insert(trimParts, refs.tail)
	end
	for _, ear in ipairs(refs.ears) do
		table.insert(trimParts, ear)
	end
	for _, leg in ipairs(refs.legs) do
		table.insert(trimParts, leg)
	end

	-- A PART MAY OVERRIDE THE TRIM TONE BY NAME, WHICH IS WHAT THE SPLIT TRIM
	-- WAS FOR.
	--
	-- `tier.trim` is the second tone and covers every trim part on 45 of the
	-- 46 skins. The bumblebee is the one that cannot be said that way: the
	-- reference has a YELLOW SNOUT beside BLACK EARS, and a MeshPart owns one
	-- `Color`, so no number of texture maps expresses it while the snout and
	-- the ears are the same part. `tier.parts` is a name-keyed override and a
	-- missing name falls through to `tier.trim` -- so a skin says only what
	-- differs, and the other 45 carry no new field at all.
	--
	-- KEYED ON `p.Name`, WHICH IS `entry.part` FROM THE SPEC. `swapToMesh`
	-- names every part after its Config row, so the override table and
	-- `Config.PIGGY_MESH` cannot disagree about what a part is called without
	-- the override simply not applying -- visible, rather than painting the
	-- wrong piece.
	local overrides = tier.parts
	for _, p in ipairs(trimParts) do
		p.Color = (overrides and overrides[p.Name]) or tier.trim
		p.Material = tier.material
		p.Reflectance = tier.reflectance or 0
	end

	-- Reset eye color and glow on every skin change so the previous skin cannot
	-- leave its face treatment behind. Nostrils are sculpted mesh recesses.
	local glowEyes = tier.glowEyes == true
	for _, child in ipairs(refs.model:GetChildren()) do
		if child:IsA("BasePart")
			and child.Name == "Eye" then
			child.Color = (overrides and overrides[child.Name]) or NEAR_BLACK
			child.Material = if glowEyes
				then Enum.Material.Neon
				else Enum.Material.SmoothPlastic
		end
	end

	-- THE SURFACE PACK GOES ON AFTER THE COLOUR, on the body and on every trim
	-- part, because the two tones have to be the same MATERIAL even when they
	-- are different colours -- a gold body with a plain plastic snout is worse
	-- than no pack at all. `applySurface` also removes one, so switching from
	-- a packed skin to an ordinary one undresses the pig rather than leaving
	-- it in metal wearing the wrong colour.
	applySurface(refs.body, tier)
	for _, p in ipairs(trimParts) do
		applySurface(p, tier, true)
	end

	-- AFTER THE SURFACE, because the ruff is painted from the same tier and
	-- reads the body's own CFrame -- which the mesh swap has already settled
	-- by the time a skin is applied.
	applyFur(refs, tier)

	-- MARKINGS, and they are the third channel of a skin rather than a fourth
	-- system. Built by PiggyModel because the shop tile and the carried loot
	-- render the same piggy from the same builder -- see the block at the top
	-- of that file. Torn down and rebuilt on every call, so switching skins
	-- cannot accumulate stripes.
	--
	-- SEATED ON THE BODY PART'S OWN CFRAME, never on `refs.origin`. The far
	-- row of plots is turned half round by one PivotTo after everything on it
	-- is built, so the origin captured at build time points the wrong way for
	-- six of the twelve piggies; the body's frame carries the turn with it and
	-- a stripe stays across the spine on both rows.
	-- AND CORRECTED FOR THE MESH'S OWN SEAT, which is a real bug rather than
	-- tidiness. `refs.body.CFrame` is the BODY CENTRE on the primitives piggy
	-- and the BOUNDING-BOX CENTRE on the mesh one -- measured, y 8.50 against
	-- y 7.86 -- so every spot and stripe would sit two thirds of a stud low on
	-- a meshed pig, on twelve skins, with nothing erroring. The correction is
	-- applied in the BODY'S OWN FRAME rather than in world space, which is
	-- what keeps the far row's half turn working (see below).
	PiggyModel.applyPattern(refs.model, tier, {
		frame = refs.body.CFrame * (refs.patternSeat or CFrame.identity),
		radius = BODY_R,
		anchored = true,
		weldTo = nil,
		material = tier.material,
		transparency = tier.transparency,
	})

	-- The colours above are the STATIC baseline, which is what a client sees
	-- before its animator starts and what it falls back to if the skin has no
	-- animation. The key is published as an attribute so every client can drive
	-- the animation locally: animating server-side would replicate a colour
	-- write per piggy per frame for something each machine can compute alone.
	--
	-- The client animator drives the Body and the four trim names and nothing
	-- else, so a pattern on an animated skin holds its own colour while the
	-- body cycles underneath it. That is the intended read -- a marking on a
	-- glowing pig -- which is why every neon pattern in Config is authored
	-- either near-black or near-white: a mid-tone trace would vanish for the
	-- part of the cycle the body happened to pass through it.
	refs.model:SetAttribute("SkinKey", skinKey)
end

-- Puts the worn accessories on the pig.
--
-- Torn down and rebuilt on every change rather than diffed. A player changes
-- hats a handful of times in a session, each item is a dozen anchored parts,
-- and a diff would have to track which model came from which slot in order to
-- save work nobody can measure -- while being the kind of bookkeeping that
-- quietly leaks a hat when two changes land in the same frame.
function PiggyBank.applyAccessories(refs: Refs, worn: { [string]: string })
	-- A SHOP VAULT WEARS NOTHING, and this is the only place the two kinds
	-- of thing standing on a plot are told apart. A skin is colour and
	-- material on a piggy's body; run on a strongroom it would paint the
	-- carcass pink and hand it a snout it does not have.
	if refs.vault then
		return
	end

	local existing = refs.model:FindFirstChild("Gear")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "Gear"
	folder.Parent = refs.model

	for slotKey, slot in pairs(Config.ACCESSORY_SLOTS) do
		local key = worn[slotKey]
		local spec = key and Config.ACCESSORIES[key]
		-- An item is only worn if it still belongs to the slot claiming it.
		-- Moving an accessory between slots in Config would otherwise leave
		-- saved players wearing a hat on their feet.
		if spec and spec.slot == slotKey then
			-- The slot anchor is the shared attachment point; `offset` is each
			-- item's own nudge off it. One anchor cannot suit a cape that hugs
			-- the back and a jetpack that stands off it.
			local offset = spec.offset or Vector3.zero
			-- WHICH PIG IS STANDING HERE DECIDES WHICH ANCHORS ARE RIGHT.
			-- `refs.bodySize` is set by `swapToMesh` and by nothing else, so
			-- it is the honest test for "the generated body actually stood
			-- up" -- better than asking Config whether ids exist, which is
			-- true even when the load failed and the primitives are out.
			local anchors = (refs.bodySize and slot.meshAnchors) or slot.anchors
			for _, anchor in ipairs(anchors) do
				local model = PigGear.build(key)
				model.Parent = folder
				model:PivotTo(CFrame.new(refs.origin + anchor + offset))
			end
		end
	end
end

-- Cosmetic particle aura around the piggy. Reuses one emitter rather than
-- creating and destroying instances every time someone changes their mind
-- in the shop.
-- A FINISH OVER THE SKIN (Phase 5.4, `Config.FINISHES`). Called AFTER
-- `applySkin` and `applyEffect`, which reset reflectance and eyes and turn
-- the spare light off; this only ADDS: a sheen on top of the skin's own
-- reflectance, Neon eyes in the finish colour, and a dim light on the
-- otherwise unused AuraLight. Never a colour on the body or the trim, and
-- never a particle -- piggy auras are retired. nil or "" takes nothing off,
-- because the skin repaint that precedes every call already did.
function PiggyBank.applyFinish(refs: Refs, finishKey: string?)
	if refs.vault then
		return
	end
	local spec = finishKey and Config.FINISHES[finishKey]
	refs.model:SetAttribute("FinishKey", if spec then finishKey else nil)
	if not spec then
		return
	end

	if spec.reflectance then
		local parts: { BasePart } = { refs.body }
		if refs.trim then table.insert(parts, refs.trim) end
		if refs.snout then table.insert(parts, refs.snout) end
		if refs.tail then table.insert(parts, refs.tail) end
		for _, ear in ipairs(refs.ears) do table.insert(parts, ear) end
		for _, leg in ipairs(refs.legs) do table.insert(parts, leg) end
		for _, part in ipairs(parts) do
			part.Reflectance = math.min(1, part.Reflectance + spec.reflectance)
		end
	end

	if spec.eyes then
		for _, child in ipairs(refs.model:GetChildren()) do
			if child:IsA("BasePart") and child.Name == "Eye" then
				child.Color = spec.eyes
				child.Material = Enum.Material.Neon
			end
		end
	end

	local light = refs.body:FindFirstChild("AuraLight") :: PointLight?
	if light and spec.light then
		light.Color = spec.light.colour
		light.Brightness = spec.light.brightness
		light.Range = spec.light.range
		light.Enabled = true
	end
end

function PiggyBank.applyEffect(refs: Refs, _effectKey: string)
	-- Independent piggy auras are retired. Do not touch coin/deposit particles
	-- or skinAura: Legendary skin visuals are owned by applySkin.
	if refs.vault then return end
	refs.aura.Enabled = false
	local light = refs.body:FindFirstChild("AuraLight") :: PointLight?
	if light then light.Enabled = false end
	refs.model:SetAttribute("LightKind", nil)
end

-- ============================================================
-- FILL
-- ============================================================

-- Reveals coins up to the current fill and returns how many newly appeared,
-- so the caller can decide whether that's worth a sound.
--
-- Only the coins that actually changed state get touched. Rewriting all 32
-- transparencies every tick would push pointless replication traffic for
-- twelve piggies, every second, forever.
function PiggyBank.setFill(refs: Refs, vault: number, capacity: number): number
	local ratio = 0
	if vault > 0 and capacity > 0 then
		ratio = math.clamp(vault / capacity, 0, 1)
	end

	local target = math.floor(ratio * Config.COIN_COUNT + 0.0001)
	local previous = refs.shown

	if target > previous then
		for i = previous + 1, target do
			refs.coins[i].Transparency = 0
		end
	elseif target < previous then
		for i = target + 1, previous do
			refs.coins[i].Transparency = 1
		end
	end
	refs.shown = target

	-- THE COIN LAMP IS A FIFTH OF WHAT IT WAS, BECAUSE IT WAS ERASING THE PIG
	-- IT SITS INSIDE.
	--
	-- This was the second half of "the pig disappears at certain angles". The
	-- first half was the subtract; with that fixed the body draws, and at the
	-- top of the old range it drew as a featureless white blob -- no eyes, no
	-- snout, no legs, no hatch. Photographed at the same camera with the one
	-- property toggled: lamp on, the pig is white; lamp off, it is pink with
	-- clean shading and a crisp black hatch. Nothing else changed.
	--
	-- IT IS A LIGHT INSIDE A SOLID, WHICH IS THE WHOLE PROBLEM. `Shadows` is
	-- false, so the shell does not block it and the pig is lit from within at
	-- point-blank range -- measured, the old 3.00 at range 18 also washed out
	-- a separate object 24 studs away. Turning `Shadows` on is not the escape
	-- it looks like: it was the right answer while the hatch and the slit were
	-- real bores for the light to spill out of, and there are no bores any
	-- more.
	--
	-- SOLVED AT THE SHELL RATHER THAN PICKED. A PointLight falls off roughly
	-- as `1 - d/range`, and the body's surface is about 6 studs from its own
	-- centre, so what the pig's own skin takes is `brightness * (1 - 6/range)`
	-- -- 2.00 on the old numbers, against a `BloomEffect` threshold of 1.1 on
	-- a body whose colour already measures 0.73 luminance in a 2.4 sun. At
	-- 0.55 over a range of 14 it is 0.31, which reads as warmth in the pink
	-- rather than as an exposure fault. Verified by photograph at the camera
	-- that showed the blowout.
	--
	-- What this costs is the long-range tell: a full piggy no longer lights
	-- the lawn around it from across the street. That signal is carried by the
	-- rob badge's own figure now, which is more precise than a glow ever was
	-- and reads from the pavement. If it is ever wanted back, the lever is the
	-- RANGE and not the brightness -- range reaches further without adding
	-- anything to what the shell itself receives.
	refs.glow.Brightness = 0.10 + ratio * 0.45
	refs.glow.Range = 9 + ratio * 5
	refs.drip.Rate = if ratio >= 1 then 0 else 2 + ratio * 5

	return math.max(0, target - previous)
end

-- ============================================================
-- FEEDBACK
-- ============================================================

-- A coin just landed on the pile. Quiet on purpose -- at roughly one every
-- fifteen seconds this is a heartbeat, and anything louder becomes nagging.
function PiggyBank.playCoinDrop(refs: Refs)
	local sound = refs.sounds.drop
	if sound then
		sound.PlaybackSpeed = 0.94 + math.random() * 0.12
		sound:Play()
	end
	refs.burst:Emit(6)
end

-- `index` is which milestone (1-based), `total` how many there are, so the
-- pitch climbs as the vault fills and the last one lands highest.
function PiggyBank.playMilestone(refs: Refs, index: number, total: number)
	local sound = refs.sounds.milestone
	if sound then
		sound.PlaybackSpeed = 0.88 + (index / math.max(total, 1)) * 0.5
		sound:Play()
	end
	refs.burst:Emit(if index >= total then 70 else 26)

	-- A small squash-and-stretch on the body. Cheap, and it makes the piggy
	-- feel like an object reacting rather than a static prop.
	-- THE RESTING SIZE, NOT A 12-STUD CUBE. This was hardcoded to the body
	-- sphere's own diameter, which is right for a ball and wrong for a
	-- MeshPart measuring 11.87 x 12.78 x 12.79 -- so the first milestone on a
	-- meshed pig would have SNAPPED it to a cube and then elastic-tweened it
	-- back to one. Read from the part rather than assumed.
	local base = refs.bodySize or Vector3.new(BODY_R * 2, BODY_R * 2, BODY_R * 2)
	local squash = base * (if index >= total then 1.16 else 1.08)
	refs.body.Size = squash
	TweenService:Create(
		refs.body,
		TweenInfo.new(0.45, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
		{ Size = base }
	):Play()
end

-- Shows or hides the plaster. Found by name rather than held in Refs: two
-- parts, toggled a few times an hour.
function PiggyBank.setRobbed(refs: Refs, on: boolean)
	for _, child in ipairs(refs.model:GetChildren()) do
		if child.Name == "Plaster" and child:IsA("BasePart") then
			child.Transparency = if on then 0 else 1
		end
	end
end

-- Someone is robbing this piggy. Loud and long-range on purpose: the alarm
-- is how the owner and every bystander find out in time to do something.
function PiggyBank.playAlarm(refs: Refs)
	local sound = refs.sounds.alarm
	if sound then
		sound:Play()
	end
	refs.burst:Emit(30)
end

function PiggyBank.playBank(refs: Refs)
	local sound = refs.sounds.bank
	if sound then
		sound:Play()
	end
	refs.burst:Emit(40)
end

-- Standing just in front of the snout, facing the piggy.
-- A pocket-sized piggy for a thief to run off with.
--
-- Wears the VICTIM's skin, which is the whole point: the loot has to be
-- recognisably somebody's property, not a generic bag of money. Someone
-- across the street should be able to look at a fleeing player and know
-- whose piggy that is.
--
-- Unanchored, massless and non-colliding, because it gets welded to a
-- character: mass would change how the thief moves, and collision would
-- catch on doorways and fences.
-- Delegated to Shared/PiggyModel, which the shop also renders. See the note
-- at the top of that file: the carried loot and the shop tile must be the
-- same piggy, or a skin can look like one thing in the catalogue and another
-- on somebody's back.
function PiggyBank.buildMini(skinKey: string): Model
	return PiggyModel.build(skinKey)
end

-- Vault dial appearance per lock level. Level 0 hides it entirely: an
-- unlocked piggy should look unlocked.
--
-- Two things ramp, and they are readable at different distances. The metal
-- carries from outside the fence, where a thief decides whether to come in at
-- all; the spoke count only resolves up close, where they are already
-- deciding whether to commit to the hold. A 2-spoke wheel is a bar handle and
-- a 5-spoke one is a bank vault, so nobody has to actually count them to see
-- which is the bigger job.
-- The wheel is everything that turns: the dark face it is set into stays put.
-- Named so rattleLock can tell the two apart without keeping a list.
local WHEEL_PARTS = { DialSpoke = true, DialHub = true }

-- Distances out from the plate's seat on the body. Each layer clears the one
-- under it -- the face stands off the plate, the spokes off the face, the hub
-- off the spokes -- because two metal discs at the same depth z-fight exactly
-- the way the road did against the grass.
local FACE_OUT = 0.65
local SPOKE_OUT = 0.95
local HUB_OUT = 1.10

local function buildWheel(lock: Model, seat: CFrame, tier: any)
	local face = part("DialFace", lock, Vector3.new(0.5, tier.radius * 1.32, tier.radius * 1.32),
		seat * CFrame.new(FACE_OUT, 0, 0))
	face.Shape = Enum.PartType.Cylinder
	face.Color = NEAR_BLACK
	face.Material = Enum.Material.Metal

	-- Spokes radiate in the plate's own YZ plane, so a rotation about its X
	-- axis spins them in place. Each is authored pointing along +Y and then
	-- turned into position, which is why the offset is applied AFTER the
	-- angle -- swap those and every spoke lands in the same spot.
	local reach = tier.radius * 0.66
	for i = 1, tier.spokes do
		local angle = (i - 1) * (2 * math.pi / tier.spokes)
		local spoke = part("DialSpoke", lock, Vector3.new(0.4, reach, 0.3),
			seat * CFrame.Angles(angle, 0, 0) * CFrame.new(SPOKE_OUT, reach / 2 + 0.24, 0))
		spoke.Color = tier.metal
		spoke.Material = Enum.Material.Metal
	end

	local hub = part("DialHub", lock, Vector3.new(0.5, 0.8, 0.8), seat * CFrame.new(HUB_OUT, 0, 0))
	hub.Shape = Enum.PartType.Cylinder
	hub.Color = tier.metal
	hub.Material = Enum.Material.Metal
end

function PiggyBank.setLockLevel(refs: Refs, level: number)
	local plate = refs.lock.PrimaryPart
	if not plate then
		return
	end

	-- The wheel is rebuilt rather than restyled, because the spoke count is
	-- part of the tier. The plate survives: it is the one piece whose CFrame
	-- everything else is measured from.
	-- The plate, the rim and the hole all survive: the plate is the piece
	-- every other CFrame is measured from, and the other two are the OPENING,
	-- which is there at every level including none. Only the wheel is rebuilt,
	-- because the spoke count is part of the tier.
	for _, piece in ipairs(refs.lock:GetChildren()) do
		if piece ~= plate and piece.Name ~= "VaultRim" and piece.Name ~= "VaultHole" then
			piece:Destroy()
		end
	end

	-- LEVEL 0 IS AN OPEN HOLE, not an absent one. An unlocked piggy used to
	-- show nothing at all, which reads as "this piggy has no vault" rather
	-- than "this piggy is not locked" -- and the second is the thing a thief
	-- at the gate is actually deciding on. Hiding the door leaves the hole.
	if level <= 0 then
		plate.Transparency = 1
		return
	end

	local tier = LOCK_TIERS[math.clamp(level, 1, #LOCK_TIERS)]
	plate.Transparency = 0
	plate.Size = Vector3.new(DIAL_THICK, tier.radius * 2, tier.radius * 2)
	plate.Color = tier.metal:Lerp(Color3.fromRGB(24, 24, 28), 0.45)
	buildWheel(refs.lock, plate.CFrame, tier)
end

-- One spin per hold, so both sides can see the lock being worked rather than
-- watching a silent progress ring.
--
-- It does not spin back. A dial that snapped to its start every time would
-- read as a failed attempt, and leaving it where it lands means a piggy that
-- has been robbed all evening looks like it.
local spinning: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local SPIN_TIME = 1.1
local SPIN_TURN = math.pi * 1.5

function PiggyBank.rattleLock(refs: Refs)
	local plate = refs.lock.PrimaryPart
	if not plate or plate.Transparency >= 1 or spinning[refs.lock] then
		return
	end

	-- Offsets are read off the parts themselves rather than remembered, so a
	-- spin always continues from wherever the last one stopped.
	local seat = plate.CFrame
	local wheel = {}
	for _, piece in ipairs(refs.lock:GetChildren()) do
		if piece:IsA("BasePart") and WHEEL_PARTS[piece.Name] then
			table.insert(wheel, { piece = piece, offset = seat:Inverse() * piece.CFrame })
		end
	end
	if #wheel == 0 then
		return
	end

	spinning[refs.lock] = true
	task.spawn(function()
		local started = os.clock()
		while true do
			local t = (os.clock() - started) / SPIN_TIME
			if t >= 1 then
				break
			end
			-- Eased out: a hand spinning a dial lets go and it coasts.
			local angle = (1 - (1 - t) ^ 3) * SPIN_TURN
			for _, w in ipairs(wheel) do
				w.piece.CFrame = seat * CFrame.Angles(angle, 0, 0) * w.offset
			end
			task.wait()
		end
		for _, w in ipairs(wheel) do
			w.piece.CFrame = seat * CFrame.Angles(SPIN_TURN, 0, 0) * w.offset
		end
		spinning[refs.lock] = nil
	end)
end

-- Takes the plot's CFrame, not its position: a spawn point has to land in
-- front of the piggy on both rows, and the far row's "front" is -Z in world.
function PiggyBank.getViewCFrame(originCF: CFrame): CFrame
	local standing = (originCF * CFrame.new(0, 3.5, BODY_R + 11)).Position
	local looking = (originCF * CFrame.new(0, BODY_Y, 0)).Position
	return CFrame.lookAt(standing, looking)
end

return PiggyBank
