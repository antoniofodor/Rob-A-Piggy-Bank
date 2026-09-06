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
	snout: Part,
	tail: Part,
	ears: { BasePart },
	legs: { Part },
	-- The body's resting size, because the milestone squash tweens back to it
	-- and a MeshPart is not a 12-stud cube.
	bodySize: Vector3?,
	-- Body-local correction from the mesh's bounding-box centre back to the
	-- pig's true body centre, so pattern marks seat where they always did.
	patternSeat: CFrame?,
	lock: Model,
	stealPrompt: ProximityPrompt,
	sounds: { [string]: Sound },
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
-- Segments in the vault's rim. Twelve is enough for a four-stud opening to
-- read as round; the cost is twelve parts per piggy, and there are twelve.
local RIM_SEGMENTS = 12

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
-- Where the nostril parts sit once the MESH muzzle is standing. Measured
-- against the seated mesh rather than chosen: the muzzle reaches z 7.10, so
-- the shipped nostrils at 6.70 would be four tenths inside it.
local MESH_NOSTRIL = Vector3.new(0.78, BODY_Y + SNOUT_Y + 1.0, 7.15)

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

	-- Cuts the coin slit and the vault hatch out of the body for real.
	-- Returns the ORIGINAL part
	-- untouched on any failure, because a piggy with no slit is a cosmetic
	-- fault and a piggy that did not build is not -- the same trade the pcall
	-- around `Decor.prewarm` already makes.
	--
	-- CSG NEEDS BOTH PARTS PARENTED TO THE DATAMODEL: an unparented pair
	-- throws "CSG API requires at least one object to be linked to a
	-- DataModel", which reads as an API that is missing rather than one that
	-- wants its arguments somewhere. ServerStorage rather than workspace, so
	-- nothing flickers on the lawn while the cut runs.
	local function cutOpenings(body: BasePart): BasePart
		local slot = Config.PIGGY_SLOT
		if not slot then
			return body
		end
		local stage = Instance.new("Folder")
		stage.Name = "PiggySlotCut"
		stage.Parent = game:GetService("ServerStorage")

		local homed = body.Parent
		body.Parent = stage

		local reach = 3
		local cutters = {}

		-- The template is framed as though the plot origin were (0,0,0), which
		-- is how `seat` reads it back, so every cutter is placed in that frame.
		local slit = Instance.new("Part")
		slit.Size = Vector3.new(slot.width, reach, slot.length)
		slit.CFrame = CFrame.new(0, slot.floor + reach / 2, 0)
		slit.Anchored = true
		slit.Parent = stage
		table.insert(cutters, slit)

		-- THE VAULT HATCH, DOWN THE DIAL'S OWN AXIS. `dialCFrame` already
		-- points its X straight out of the body, which is what a Roblox
		-- cylinder wants -- so the bore is one cylinder on that axis and the
		-- recess comes out square to the door that will sit in it.
		local vault = Config.PIGGY_VAULT
		if vault then
			local bore = Instance.new("Part")
			bore.Shape = Enum.PartType.Cylinder
			bore.Size = Vector3.new(reach, vault.radius * 2, vault.radius * 2)
			bore.CFrame = dialCFrame(Vector3.zero)
				* CFrame.new(vault.floor + reach / 2, 0, 0)
			bore.Anchored = true
			bore.Parent = stage
			table.insert(cutters, bore)
		end

		-- ONE SUBTRACT FOR BOTH, because it costs 284 ms whether it takes one
		-- cutter or five.
		--
		-- RENDER FIDELITY IS AN ARGUMENT HERE, NOT A PROPERTY WRITE, AND THAT
		-- IS THE WHOLE DIFFERENCE. This file used to set `cut.RenderFidelity`
		-- afterwards inside a pcall, because that write is capability-gated
		-- and throws from a real Script while passing in an MCP sandbox -- so
		-- live, the pcall swallowed it and the body shipped at `Automatic`,
		-- which is a decimated LOD and is exactly the faceting anybody
		-- standing on the lawn could see. `SubtractAsync` takes both
		-- fidelities as PARAMETERS, so the result is born Precise and nothing
		-- is gated. Measured live: the body read `Automatic` before and
		-- `Precise` after, from the server, with no pcall anywhere.
		--
		-- Collision stays a box for the reason the trim meshes already give:
		-- a thief runs at this and a dog patrols round it, and precise
		-- collision on a 7,000-triangle surface buys nothing at twelve studs
		-- across while costing every triangle a physics query.
		local cutOk, cut = pcall(function()
			return body:SubtractAsync(cutters,
				Enum.CollisionFidelity.Box,
				Enum.RenderFidelity.Precise)
		end)
		for _, c in ipairs(cutters) do
			c:Destroy()
		end

		if not cutOk or not cut then
			warn(("[PiggyBank] the openings could not be cut, so the piggy "
				.. "ships without them: %s"):format(tostring(cut)))
			body.Parent = homed
			stage:Destroy()
			return body
		end

		body:Destroy()
		cut.Parent = homed
		stage:Destroy()
		return cut
	end

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
				-- Seated in the template's own frame first, because the cut
				-- is placed against the plot origin and the result keeps
				-- whatever framing it was given.
				part.Size = entry.size
				part.CFrame = CFrame.new(entry.offset)
				part.Anchored = true
				part = cutOpenings(part)
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
	-- THE COIN SLOT IS ON THAT LIST, AND IT IS THE ONE THAT IS NOT OBVIOUS.
	-- It is a black box seated at `BODY_Y + BODY_R - 0.3`, which on the
	-- primitives pig is INSIDE a sphere whose top is 14.50: it shows as a dark
	-- slit where the ends break the curve, which is the whole trick. The mesh
	-- body's crown is 14.14, and the box reaches 14.425 -- so the same part
	-- stands a third of a stud PROUD along its entire 4.2-stud length and
	-- reads as a bar lying on the pig's back rather than a slot cut into it.
	--
	-- Reseating it was the other option and is the wrong one: the generated
	-- body already has a slot sculpted into its upper back (measured, the
	-- spine dips from 14.11 to 13.73 down the middle), so a part would be a
	-- second slot beside the real one. Same call the snout and ears make --
	-- the mesh contains it, so the primitive goes.
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

	local body = made.Body
	if not (body and bodyEntry and made.Snout and made.Tail and made.Ear) then
		warn("[PiggyBank] piggy mesh is missing a named part, so the swap is off")
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
	refs.snout = made.Snout :: any
	refs.tail = made.Tail :: any
	refs.ears = { made.Ear }
	-- The legs are inside the body mesh, so there is no separate list. They
	-- are BODY-coloured there, which is what the primitives pig already did.
	refs.legs = {}

	-- THE NOSTRILS HAVE TO FOLLOW THE MUZZLE, and this is the one knock-on the
	-- mesh has on a part the mesh does not contain.
	--
	-- The shipped snout tip is z 6.6 with the nostril parts at 6.7, so they
	-- clear it by a tenth of a stud. The mesh's muzzle reaches 7.10, which
	-- leaves the nostrils four tenths INSIDE it. They would not error; they
	-- would simply stop existing, and a pig with no nostrils reads as a pig
	-- with no face.
	for _, child in ipairs(refs.model:GetChildren()) do
		if child:IsA("BasePart") and child.Name == "Nostril" then
			local side = if child.Position.X < origin.X then -1 else 1
			child.CFrame = CFrame.new(origin
				+ Vector3.new(side * MESH_NOSTRIL.X, MESH_NOSTRIL.Y, MESH_NOSTRIL.Z))
		end
	end

	-- THE RIM AND THE DARK DISC BOTH GO, because the mesh now has a real bore
	-- and the opening is simply open.
	--
	-- The rim is twelve FLAT segments, which can only lie true on a sphere --
	-- measured around their own ring on this body, the surface swings 0.72
	-- studs from one side to the other, so a third were buried and the rest
	-- stood off the pig. No offset fixes a ring on a shape that is not round.
	--
	-- The disc was the other half of the same illusion: nothing could be dug,
	-- so an opening was a dark thing with a lip around it. Both were answers
	-- to a question that stopped being asked -- the coin slit in the crown has
	-- nothing in it either, and these are the same object.
	if Config.PIGGY_VAULT and refs.lock then
		for _, piece in ipairs(refs.lock:GetChildren()) do
			if piece.Name == "VaultRim" or piece.Name == "VaultHole" then
				piece:Destroy()
			end
		end
	end

	refs.bodySize = bodyEntry.size
	refs.patternSeat = CFrame.new(Vector3.new(0, BODY_Y, 0) - bodyEntry.offset)
	return true
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

	-- Separate from `Glow`, which EconomyService drives to show vault fill.
	-- Sharing one light would make a full vault and a lit effect fight over
	-- the same property every frame.
	local auraLight = Instance.new("PointLight")
	auraLight.Name = "AuraLight"
	auraLight.Enabled = false
	auraLight.Shadows = false
	auraLight.Parent = body

	-- Fired in bursts on milestones and banking.
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

	-- Sounds ----------------------------------------------------------
	-- Parented to the body so they're positional. Neighbours hearing your
	-- piggy chime is deliberate: in phase 3 it tells a thief where the
	-- money is, which turns feedback into information.
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

	-- Snout -----------------------------------------------------------
	local snout = part("Snout", model, Vector3.new(2, SNOUT_D, SNOUT_D), cylinderForward(at(0, BODY_Y + SNOUT_Y, BODY_R - 0.4)))
	snout.Shape = Enum.PartType.Cylinder
	snout.Color = PINK_DARK

	for _, offset in ipairs({ -1, 1 }) do
		local nostril = part("Nostril", model, Vector3.new(0.5, 0.95, 0.4), CFrame.new(at(offset * 0.8, BODY_Y + SNOUT_Y, BODY_R + 0.7)))
		nostril.Color = NEAR_BLACK
		nostril.Material = Enum.Material.SmoothPlastic
	end

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

	local hole = part("VaultHole", lock, Vector3.new(0.30, DIAL_MAX_R * 2, DIAL_MAX_R * 2),
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
		local r = DIAL_MAX_R + 0.16
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
	stealPrompt.Style = Enum.ProximityPromptStyle.Custom
	stealPrompt:SetAttribute(Config.PROMPT_KIND_ATTRIBUTE, "steal")
	stealPrompt.ObjectText = "Piggy Bank"
	-- Half a second: this hold OPENS the lock, it no longer robs it. What
	-- comes after is Config.CRACK, where the Vault Lock tree now expresses
	-- itself -- so a long hold here would charge for that upgrade twice.
	stealPrompt.HoldDuration = Config.CRACK.openHold
	stealPrompt.MaxActivationDistance = Config.STEAL_RANGE
	stealPrompt.RequiresLineOfSight = false
	stealPrompt.Enabled = false
	stealPrompt.Parent = body

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
		snout = snout,
		tail = tail,
		ears = ears,
		legs = legs,
		lock = lock,
		stealPrompt = stealPrompt,
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
-- APPEARANCE
-- ============================================================

-- The equipped skin owns the piggy's whole appearance. Rebirth-earned looks
-- are just skins with an unlockRebirths instead of a price, so there's one
-- system here rather than a tier system fighting a cosmetic one.
function PiggyBank.applySkin(refs: Refs, skinKey: string)
	local tier = Config.getSkin(skinKey)

	refs.body.Color = tier.body
	refs.body.Material = tier.material
	refs.body.Transparency = tier.transparency

	-- FOUR PARTS OR SEVEN, AND THE CALLER DOES NOT CARE WHICH. The mesh piggy
	-- names its trim meshes `Snout`, `Ear` and `Tail` -- the primitives' own
	-- names -- so this list is built the same way for both and there is no
	-- branch to keep in step. The mesh piggy's legs live inside the body
	-- mesh, so `refs.legs` is simply empty there.
	local trimParts: { BasePart } = { refs.snout, refs.tail }
	for _, ear in ipairs(refs.ears) do
		table.insert(trimParts, ear)
	end
	for _, leg in ipairs(refs.legs) do
		table.insert(trimParts, leg)
	end

	for _, p in ipairs(trimParts) do
		p.Color = tier.trim
		p.Material = tier.material
	end

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
			for _, anchor in ipairs(slot.anchors) do
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
function PiggyBank.applyEffect(refs: Refs, effectKey: string)
	local effect = Config.getEffect(effectKey)
	local aura = refs.aura

	if not effect.texture then
		aura.Enabled = false
		local off = refs.body:FindFirstChild("AuraLight") :: PointLight?
		if off then
			off.Enabled = false
		end
		refs.model:SetAttribute("LightKind", nil)
		return
	end

	aura.Texture = effect.texture
	aura.Color = effect.color
	aura.Rate = effect.rate
	aura.Speed = effect.speed
	aura.Lifetime = effect.lifetime
	aura.Drag = effect.drag
	aura.Acceleration = effect.accel
	aura.SpreadAngle = Vector2.new(effect.spread, effect.spread)
	aura.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, effect.size),
		NumberSequenceKeypoint.new(1, 0),
	})

	-- Tumble. The coin particles never rotate, so any spin at all reads as
	-- "this is the other thing" before you've registered the colour.
	local spin = effect.rotSpeed or 0
	aura.Rotation = NumberRange.new(0, 360)
	aura.RotSpeed = NumberRange.new(-spin, spin)

	aura.Enabled = true

	-- The top two effects throw light. Base brightness is set here; the
	-- flicker is a client concern, driven off the LightKind attribute below.
	local auraLight = refs.body:FindFirstChild("AuraLight") :: PointLight?
	if auraLight then
		if effect.light then
			auraLight.Color = effect.light.colour
			auraLight.Brightness = effect.light.brightness
			auraLight.Range = effect.light.range
			auraLight.Enabled = true
			refs.model:SetAttribute("LightKind", effect.light.kind)
		else
			auraLight.Enabled = false
			refs.model:SetAttribute("LightKind", nil)
		end
	end
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

	refs.glow.Brightness = 0.4 + ratio * 2.6
	refs.glow.Range = 7 + ratio * 11
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
local LOCK_TIERS = {
	{ metal = Color3.fromRGB(122, 128, 138), radius = 1.55, spokes = 2 }, -- iron
	{ metal = Color3.fromRGB(176, 122, 66), radius = 1.68, spokes = 3 },  -- bronze
	{ metal = Color3.fromRGB(198, 204, 214), radius = 1.82, spokes = 4 }, -- steel
	{ metal = Color3.fromRGB(240, 198, 76), radius = 1.95, spokes = 5 },  -- gold
}

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
