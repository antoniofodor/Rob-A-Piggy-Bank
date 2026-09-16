--!strict
-- The imported empty basket. Filling and carrying are separate Phase 2 work.
local Config = require(script.Parent.Config)

local AcornBasket = {}
export type Refs = { model: Model, body: BasePart, handles: BasePart }

local templates: { [string]: BasePart }? = nil
local checked = false

function AcornBasket.prewarm()
	if checked then return end
	checked = true
	local parts = Config.acornBasketMesh()
	if not parts then
		warn("[AcornBasket] Missing mesh or texture IDs; yard baskets are unavailable.")
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
		assert(made.Basket and made.BasketDetail2, "basket requires its bowl and handles")
	end)
	if not ok then
		for _, part in pairs(made) do part:Destroy() end
		warn(("[AcornBasket] Could not load basket meshes: %s"):format(tostring(err)))
		return
	end
	templates = made
end

-- `base` is the bowl's ground contact, already rotated with its plot.
function AcornBasket.build(parent: Instance, base: CFrame): Refs?
	AcornBasket.prewarm()
	local ready = templates
	local parts = Config.acornBasketMesh()
	if not ready or not parts then return nil end
	local model = Instance.new("Model")
	model.Name = "AcornBasket"
	local built: { [string]: BasePart } = {}
	for _, entry in ipairs(parts) do
		local part = ready[entry.part]:Clone()
		part.Name = entry.part
		part.Size = entry.size * Config.ACORNS.basketScale
		part.CFrame = base * CFrame.new(entry.offset * Config.ACORNS.basketScale)
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
	model.WorldPivot = base
	model.Parent = parent
	return { model = model, body = built.Basket, handles = built.BasketDetail2 }
end

return AcornBasket
