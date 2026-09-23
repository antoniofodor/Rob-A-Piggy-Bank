--!strict
--[[
	GrassTuft

	The little clumps of grass that stand up out of the ground.

	THIS IS THE HALF A MATERIAL CANNOT DO. The painted lawn variant makes the
	ground look like grass; it is still a flat plane, and from standing height
	a flat plane reads as a flat plane however well it is painted. What sells
	a stylised lawn is SILHOUETTE -- blades breaking the line where the ground
	meets everything standing on it. So the material and the tufts are two
	halves of one job rather than alternatives, and neither is worth much
	alone.

	IT IS IN `Shared` FOR ONE REASON: THE TEMPLATE CACHE. Two different
	services plant these -- PlotService on the lawns and NeighborhoodService on
	the verge -- and `InsertService:CreateMeshPartAsync` yields. Two copies of
	this file would mean two web calls for one asset and, worse, two places
	that could disagree about how tall a tuft is. Nothing here is client-side;
	the shop does not render grass. It is shared because the CACHE is shared,
	which is a different reason from the one House, Decor and PiggyModel are
	here for and worth saying out loud.

	EVERY TUFT IS CanCollide, CanQuery AND CastShadow FALSE, and that is not
	tidiness. This is the ground a thief runs across, a dog patrols and a
	defender stands on. A tuft that collided would body-block a chase; one
	that answered a raycast would eat a query meant for a piggy; and a
	thousand shadow casters is a thousand shadow casters. Same rule the whole
	of `NeighborhoodService` and every lawn ornament already follow.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local GrassTuft = {}

local template: BasePart? = nil
local checked = false

-- Built ONCE and cloned, for the reason in the header. Returns nil with a
-- warning rather than throwing: grass is the most cosmetic thing in this game
-- and it may never be the reason a plot or the street fails to build. Same
-- trade as the pcall around `Decor.prewarm`.
function GrassTuft.template(): BasePart?
	if checked then
		return template
	end
	checked = true

	local spec = Config.grassTuft()
	if not spec then
		return nil
	end

	local ok, result = pcall(function()
		local insert = game:GetService("InsertService")
		-- Box collision because it is switched off anyway, and Automatic
		-- render fidelity because there are a thousand of these and shedding
		-- their triangles with distance is exactly what should happen. The
		-- piggy is `Precise` for the opposite reason; see Config.
		local part = insert:CreateMeshPartAsync(spec.id,
			Enum.CollisionFidelity.Box, Enum.RenderFidelity.Automatic)
		-- `CreateMeshPartAsync` carries the MESH and not the map, which is
		-- how the trees shipped flat for a build. The tuft's painted tips are
		-- most of what makes it read as grass rather than as a green wedge.
		if spec.texture then
			part.TextureID = spec.texture
		end
		return part
	end)

	if not ok then
		warn(("[GrassTuft] the grass tuft could not be loaded, so the ground "
			.. "is bare: %s"):format(tostring(result)))
		return nil
	end

	template = result
	return template
end

-- A deterministic scatter, so a plot rebuilt after a rebirth grows back the
-- same grass rather than reshuffling itself under the owner. The same reason
-- `NeighborhoodService.scatter` is a hash of its seed rather than `math.random`.
local function rnd(state: { n: number }): number
	state.n += 1
	local v = math.sin(state.n * 12.9898) * 43758.5453
	return v - math.floor(v)
end

--[[
	Plants tufts across a rectangle, given the CFrame of its TOP SURFACE.

	`accept` is handed a WORLD position and vetoes that spot. It exists
	because the things grass must not grow out of -- a driveway, a forecourt,
	a moat -- are known in world space by the caller and are none of this
	module's business.
]]
function GrassTuft.scatterRect(top: CFrame, width: number, depth: number,
	parent: Instance, seed: number, accept: ((Vector3) -> boolean)?): number

	local spec = Config.grassTuft()
	local tpl = spec and GrassTuft.template()
	if not (spec and tpl) then
		return 0
	end

	local wanted = math.floor(width * depth / spec.perStuds)
	local state = { n = seed * 7919 }
	local planted = 0

	for _ = 1, wanted do
		-- Every draw happens BEFORE the veto, so a rejected spot consumes the
		-- same numbers an accepted one would. Drawing inside the branch makes
		-- the whole scatter shift the moment a driveway moves, which turns a
		-- deterministic layout into one that quietly reshuffles.
		local at = top * CFrame.new((rnd(state) - 0.5) * width, 0, (rnd(state) - 0.5) * depth)
		local scale = spec.minScale + rnd(state) * (spec.maxScale - spec.minScale)
		local yaw = rnd(state) * math.pi * 2
		local tint = if rnd(state) < 0.5 then spec.tint else spec.tint2

		if not accept or accept(at.Position) then
			local part = tpl:Clone()
			part.Name = "Tuft"
			-- SIZE BEFORE CFRAME, the same rule the trees and the piggy
			-- follow: resizing a MeshPart scales it about its own centre, so
			-- a part seated first and scaled after moves off its spot.
			part.Size = spec.size * scale
			-- Seated by its own height so a clump stands ON the ground
			-- whatever it was scaled to, then sunk a little. A Y rotation
			-- cannot change a Y extent, so the yaw is free here.
			part.CFrame = CFrame.new(at.Position
				+ Vector3.new(0, part.Size.Y / 2 - spec.sink, 0))
				* CFrame.Angles(0, yaw, 0)
			part.Color = tint
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CastShadow = false
			part.Parent = parent
			planted += 1
		end
	end

	return planted
end

--[[
	Plants tufts across the top face of a part.

	IT TAKES THE PART RATHER THAN A RECTANGLE, which is what makes it safe on
	both rows of plots. The far row is turned a half turn by one `PivotTo` at
	the end of `buildPlot`, so a caller passing plot-local numbers would have
	to know that and half of them would forget. A part knows its own CFrame
	and its own size, so this is correct under any rotation by construction --
	and it measures the world that actually got built rather than the
	arithmetic that was meant to build it.
]]
function GrassTuft.scatterOn(surface: BasePart, parent: Instance, seed: number,
	accept: ((Vector3) -> boolean)?): number

	return GrassTuft.scatterRect(
		surface.CFrame * CFrame.new(0, surface.Size.Y / 2, 0),
		surface.Size.X, surface.Size.Z, parent, seed, accept)
end

--[[
	WHERE GRASS MAY NOT GROW, MEASURED OFF THE THINGS THAT ARE ACTUALLY
	STANDING THERE.

	Reported as the grass clipping through the collect buttons, and measured
	live that is exactly what it was: a pad face stands 0.06 studs above the
	lawn and a tuft reaches 1.17, so every blade near one grew straight
	through it. The same is true of every pedestal base, the piggy's own
	belly and the house foundation -- the lawn acquired things standing on it
	and the scatter still had the veto it was written with, which was none.

	THE RULE IS A BAND RATHER THAN A LIST, and that is the whole point. The
	old comment in `PlotService` names the two things a lawn could have grass
	growing out of -- a driveway and a moat -- and it was right when it was
	written. A list is wrong now for a reason that will not stop being true:
	six pedestals, seven pads, a kennel, a sign, a mailbox, a crate, nine
	ornaments that change when somebody shops and nine house tiers that
	change when somebody upgrades. Naming them is a list nobody will keep.

	So a part blocks grass when it OCCUPIES THE BAND A TUFT STANDS IN: its
	underside is below the tuft's crown and its top is above the ground. That
	is a restatement of the complaint rather than a heuristic -- a thing
	grass can grow through is a thing with grass-height air under it -- and
	it needs to know nothing about what the part IS.

	IT ALSO ANSWERS THE THINGS THAT MUST NOT BLOCK, for free and by
	measurement rather than by exception:

		* THE STONE TRIM around the yard tops out 0.2 studs BELOW the lawn --
		  it is proud of the world ground, not of the grass -- so it never
		  enters the band and no tuft is ever cut for it.
		* A FENCE, its panels and a moat stand outboard of this grass, so
		  their footprints do not reach it.
		* HOUSE FX, the sign's arm and board, and every billboard hang in the
		  AIR. A band test cannot see them, where a bounding box would --
		  which is the trap that once recorded the Sky Castle as 16.6 studs
		  too wide when it was measuring orbiting shards at altitude.

	AND THE SURFACES BEING PLANTED ARE NAMED RATHER THAN DEDUCED. A lawn
	slab's top IS the ground, so it sits exactly on the band's floor and
	whether it lands inside depends on a float comparison. `ignore` is how
	the caller says which parts are the ground rather than things on it, and
	there are exactly two.

	AN UNANCHORED PART IS NEVER A BLOCKER, WHICH IS THE GUARD DOG. Measured,
	116 of a dog's 118 parts are unanchored while every piece of furniture on
	a plot is anchored -- so the test costs one property read and needs no
	name. It matters because a dog WALKS: a patch cleared under one is a
	patch cleared where it happened to be standing at that instant, and it
	leaves a bald spot in the middle of a lawn that nothing is standing on.

	THE MARGIN IS HALF A TUFT, because a clump is 2.8 studs across at scale 1
	and a blade centred just outside a pad still leans over it. `accept` is
	handed a POSITION and the scale has not been drawn yet, so this is the
	widest a tuft can be rather than the width of the one being placed -- a
	hair of bare lawn at a pad's edge is the safe direction to be wrong in.
]]
function GrassTuft.clearance(model: Instance, surfaceY: number,
	ignore: { [Instance]: boolean }?): ((Vector3) -> boolean)?

	local spec = Config.grassTuft()
	if not spec then
		return nil
	end
	-- How far above the surface the tallest tuft's crown gets, and how far to
	-- either side of its own spot the widest one reaches. Both derived from
	-- the same three numbers the scatter plants with, so a taller or wider
	-- clump widens its own exclusion with nothing to remember here.
	local reach = spec.size.Y * spec.maxScale - spec.sink
	local margin = math.max(spec.size.X, spec.size.Z) * spec.maxScale / 2

	local blocks: { { x: number, z: number, hx: number, hz: number } } = {}
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Anchored
			and not (ignore and ignore[part]) then
			-- PER PART, IN WORLD SPACE, projecting its own size through its own
			-- CFrame. `GetBoundingBox` is oriented by a model's pivot and
			-- transposes extents, which this project has paid for twice.
			local cf, size = part.CFrame, part.Size
			local hx = math.abs(cf.RightVector.X) * size.X / 2
				+ math.abs(cf.UpVector.X) * size.Y / 2
				+ math.abs(cf.LookVector.X) * size.Z / 2
			local hy = math.abs(cf.RightVector.Y) * size.X / 2
				+ math.abs(cf.UpVector.Y) * size.Y / 2
				+ math.abs(cf.LookVector.Y) * size.Z / 2
			local hz = math.abs(cf.RightVector.Z) * size.X / 2
				+ math.abs(cf.UpVector.Z) * size.Y / 2
				+ math.abs(cf.LookVector.Z) * size.Z / 2
			local y = cf.Position.Y
			if y - hy < surfaceY + reach and y + hy > surfaceY then
				table.insert(blocks, { x = cf.Position.X, z = cf.Position.Z,
					hx = hx + margin, hz = hz + margin })
			end
		end
	end

	-- NOTHING IN THE WAY MEANS NO PREDICATE, so a bare plot plants at exactly
	-- the cost it always did rather than paying for a test that can never
	-- refuse anything.
	if #blocks == 0 then
		return nil
	end
	return function(at: Vector3): boolean
		for _, b in ipairs(blocks) do
			if math.abs(at.X - b.x) <= b.hx and math.abs(at.Z - b.z) <= b.hz then
				return false
			end
		end
		return true
	end
end

return GrassTuft
