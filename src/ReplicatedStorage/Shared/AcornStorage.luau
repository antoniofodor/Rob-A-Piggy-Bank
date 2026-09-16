--!strict
-- Imported open crate; its invisible floor retains the gameplay/fill anchor.
local Config = require(script.Parent.Config)
local AcornStorage = {}
export type Refs = { model: Model, body: BasePart }

local templates: { [string]: BasePart }? = nil
local checked = false

function AcornStorage.prewarm()
	if checked then return end
	checked = true
	local parts = Config.acornStorageMesh()
	if not parts then
		warn("[AcornStorage] Missing mesh or texture IDs; using wooden blockout.")
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
		assert(made.CrateBody and made.CornerPosts and made.TopRim and made.AcornEmblem,
			"crate requires all four mesh parts")
	end)
	if not ok then
		for _, part in pairs(made) do part:Destroy() end
		warn(("[AcornStorage] Could not load crate meshes; using wooden blockout: %s"):format(tostring(err)))
		return
	end
	templates = made
end

function AcornStorage.build(parent: Instance, ground: CFrame): Refs
	AcornStorage.prewarm()
	local model = Instance.new("Model")
	model.Name = "AcornStorage"
	local function plank(name: string, size: Vector3, offset: Vector3, shade: number): Part
		local part = Instance.new("Part")
		part.Name, part.Size, part.CFrame = name, size, ground * CFrame.new(offset)
		part.Color = Color3.fromRGB(139 + shade, 88 + shade, 48 + shade)
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		part.Parent = model
		return part
	end
	local body = plank("Storage", Vector3.new(3.6, 0.25, 2.8), Vector3.new(0, 0.125, 0), -12)
	local ready, parts = templates, Config.acornStorageMesh()
	if ready and parts then
		body.Transparency, body.CastShadow = 1, false
		for _, entry in ipairs(parts) do
			local part = ready[entry.part]:Clone()
			part.Name, part.Size = entry.part, entry.size
			part.CFrame = ground * CFrame.new(entry.offset)
			part.Color, part.Material = Color3.new(1, 1, 1), Enum.Material.Plastic
			part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
			part.CastShadow, part.Parent = true, model
		end
		model.PrimaryPart, model.WorldPivot, model.Parent = body, ground, parent
		return { model = model, body = body }
	end
	-- Complete fallback keeps storage usable if Roblox cannot load an asset.
	for row = 1, 3 do
		local y = 0.25 + (row - 0.5) * 0.55
		for _, sign in ipairs({-1, 1}) do
			plank("LongPlank", Vector3.new(3.6, 0.5, 0.18), Vector3.new(0, y, sign * 1.31), row * 4)
			plank("EndPlank", Vector3.new(0.18, 0.5, 2.44), Vector3.new(sign * 1.71, y, 0), row * 3)
		end
	end
	for _, x in ipairs({-1.62, 1.62}) do
		for _, z in ipairs({-1.22, 1.22}) do
			plank("CornerPost", Vector3.new(0.25, 1.9, 0.25), Vector3.new(x, 0.95, z), -18)
		end
	end
	model.PrimaryPart, model.WorldPivot, model.Parent = body, ground, parent
	return { model = model, body = body }
end

return AcornStorage
