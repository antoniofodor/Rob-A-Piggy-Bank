--!strict
-- The snout coin as a real 3D mesh: `assets/shop-ui/icon-system-v1/models/coin`,
-- the DOUBLE-SIDED version, with the snout on both faces. Same shape as
-- `AcornModel`: the server builds the MeshPart once from `Config.COIN_MESH` and
-- parks it in ReplicatedStorage, and clients clone it. CSG and
-- `CreateMeshPartAsync` are server-only, so the client cannot build its own.
--
-- AN EMPTY ID IS A WORKING STATE: no template is made, `clone` returns nil and
-- the delivery rush falls back to the drawn HUD coin. The id is empty until the
-- mirrored coin has been imported into Studio and its mesh id pasted in.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(script.Parent.Config)

local CoinModel = {}
CoinModel.templateName = "CoinMeshTemplate"
local checked = false

function CoinModel.prewarm()
	if RunService:IsClient() or checked then return end
	checked = true
	local spec = Config.COIN_MESH
	if not spec or spec.id == "" then return end
	local ok, result = pcall(function()
		return game:GetService("InsertService"):CreateMeshPartAsync(spec.id,
			Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
	end)
	if not ok or not result then
		warn("[CoinModel] Could not load the coin mesh: " .. tostring(result))
		return
	end
	local part = result :: MeshPart
	part.Name = CoinModel.templateName
	part.Size = spec.size
	part.TextureID = spec.texture
	part.Color = Color3.new(1, 1, 1)
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.CastShadow = false
	part.Parent = ReplicatedStorage
end

-- A copy `diameter` studs across, or nil while there is no template.
function CoinModel.clone(diameter: number): MeshPart?
	local template = ReplicatedStorage:FindFirstChild(CoinModel.templateName)
	if not template or not template:IsA("MeshPart") then return nil end
	local part = template:Clone()
	part.Size = template.Size * (diameter / math.max(template.Size.X, 1e-3))
	return part
end

return CoinModel
