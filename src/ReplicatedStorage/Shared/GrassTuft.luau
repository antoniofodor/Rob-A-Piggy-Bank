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

return GrassTuft
