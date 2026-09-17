--!strict
-- Reconstructs the compact Blender oak from its uploaded textured meshes.
-- One cached pair serves all residential plots; no Studio-only model needed.
local Config = require(script.Parent.Config)

local AcornTree = {}

export type Refs = { model: Model, trunk: BasePart, canopy: BasePart, collider: BasePart }

local templates: { [string]: BasePart }? = nil
local checked = false

function AcornTree.prewarm()
	if checked then return end
	checked = true
	local parts = Config.acornOakMesh()
	if not parts then
		warn("[AcornTree] AcornOak needs both mesh and texture IDs; yard trees are unavailable.")
		return
	end
	local made: { [string]: BasePart } = {}
	local ok, err = pcall(function()
		local insert = game:GetService("InsertService")
		for _, entry in ipairs(parts) do
			local part = insert:CreateMeshPartAsync(entry.id,
				Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
			made[entry.part] = part
			part.TextureID = entry.texture
		end
		assert(made.Trunk and made.Canopy, "AcornOak requires a trunk and canopy")
	end)
	if not ok then
		for _, part in pairs(made) do part:Destroy() end
		warn(("[AcornTree] Could not load AcornOak; yard trees are unavailable: %s"):format(tostring(err)))
		return
	end
	templates = made
end

-- `base` is the trunk's ground contact, already facing with the plot.
function AcornTree.build(parent: Instance, base: CFrame): Refs?
	AcornTree.prewarm()
	local ready = templates
	local parts = Config.acornOakMesh()
	if not ready or not parts then return nil end
	local model = Instance.new("Model")
	model.Name = "AcornOak"
	local built: { [string]: BasePart } = {}
	for _, entry in ipairs(parts) do
		local part = ready[entry.part]:Clone()
		part.Name = entry.part
		part.Size = entry.size * Config.ACORNS.treeScale
		part.CFrame = base * CFrame.new(entry.offset * Config.ACORNS.treeScale)
		part.Color = Color3.new(1, 1, 1)
		part.Material = Enum.Material.Plastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = true
		part.Parent = model
		built[entry.part] = part
	end
	-- Wide forks are visual geometry. Their bounding box must not become an
	-- invisible wall; use the solid lower trunk as the physical/query target.
	local collider = Instance.new("Part")
	collider.Name = "TrunkCollider"
	collider.Size = Config.ACORNS.treeCollisionSize * Config.ACORNS.treeScale
	collider.CFrame = base * CFrame.new(Config.ACORNS.treeCollisionOffset * Config.ACORNS.treeScale)
	collider.Transparency = 1
	collider.Anchored = true
	collider.CanCollide = true
	collider.CanQuery = true
	collider.CanTouch = false
	collider.CastShadow = false
	collider.Parent = model
	model.WorldPivot = base
	model.Parent = parent
	return { model = model, trunk = built.Trunk, canopy = built.Canopy, collider = collider }
end

-- THE PLACEHOLDER GROWTH for a tree level (step 2.7), until brief B5 draws
-- the real five: the two visual meshes stretched about the tree's own ground
-- pivot. The collider is left alone -- it is the lower trunk, the thing a
-- runner bumps into and the shake prompt hangs on, and neither of those
-- should move because somebody bought a rung.
function AcornTree.setGrowth(refs: Refs?, scaleXZ: number, scaleY: number)
	if not refs or not refs.model or not refs.model.Parent then
		return
	end
	local parts = Config.acornOakMesh()
	if not parts then
		return
	end
	local base = refs.model.WorldPivot
	local stretch = Vector3.new(scaleXZ, scaleY, scaleXZ)
	for _, entry in ipairs(parts) do
		local part = refs.model:FindFirstChild(entry.part)
		if part and part:IsA("BasePart") then
			part.Size = entry.size * Config.ACORNS.treeScale * stretch
			part.CFrame = base * CFrame.new(entry.offset * Config.ACORNS.treeScale * stretch)
		end
	end
end

return AcornTree
