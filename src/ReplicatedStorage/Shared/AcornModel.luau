--!strict
-- Imported three-part Acorn. Server loads mesh assets once and replicates a
-- template; clients clone it for tree, ground, storage and carry contents.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(script.Parent.Config)
local AcornModel = {}
AcornModel.templateName = "AcornMeshTemplate"
local checked = false

function AcornModel.prewarm()
	if RunService:IsClient() or checked then return end
	checked = true
	local model = Instance.new("Model")
	model.Name = AcornModel.templateName
	local ok, err = pcall(function()
		for _, spec in ipairs(Config.ACORN_MESH.parts) do
			local part = game:GetService("InsertService"):CreateMeshPartAsync(spec.id,
				Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
			part.Name, part.Size, part.TextureID = spec.part, spec.size, spec.texture
			part.CFrame, part.Color = CFrame.new(spec.offset), Color3.new(1, 1, 1)
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
			part.Material, part.CastShadow = Enum.Material.Plastic, false
			part.Parent = model
			if spec.part == "Nut" then model.PrimaryPart = part end
		end
		assert(model.PrimaryPart, "Acorn requires a Nut")
	end)
	if not ok then model:Destroy(); warn("[AcornModel] Could not load imported Acorn: " .. tostring(err)); return end
	model.Parent = ReplicatedStorage
end

function AcornModel.build(parent: Instance, cf: CFrame, scale: number): Model?
	local template = ReplicatedStorage:FindFirstChild(AcornModel.templateName)
	if not template or not template:IsA("Model") or #template:GetChildren() < #Config.ACORN_MESH.parts then return nil end
	local model = template:Clone()
	model.Name = "Acorn"
	-- Explicit offsets also handle partial/late template replication; the
	-- model pivot is the nut centre and does not depend on a WorldPivot value.
	for _, spec in ipairs(Config.ACORN_MESH.parts) do
		local part = model:FindFirstChild(spec.part)
		if not part or not part:IsA("BasePart") then model:Destroy(); return nil end
		part.Size, part.CFrame = spec.size * scale, cf * CFrame.new(spec.offset * scale)
	end
	model.PrimaryPart = model:FindFirstChild("Nut") :: BasePart
	model.Parent = parent
	return model
end

function AcornModel.fillCarry(model: Model, amount: number)
	local body = model.PrimaryPart
	if not body then return end
	local old = model:FindFirstChild("AcornContents")
	if old then old:Destroy() end
	local contents = Instance.new("Folder")
	contents.Name, contents.Parent = "AcornContents", model
	for i = 1, math.min(amount, Config.ACORNS.growCap) do
		local slot = (i - 1) % 4
		local x, z = (if slot % 2 == 0 then -0.38 else 0.38), (if slot < 2 then -0.34 else 0.34)
		local y = 0.14 + math.floor((i - 1) / 4) * 0.38
		local acorn = AcornModel.build(contents, body.CFrame * CFrame.new(x, y, z), 0.85)
		if acorn then
			for _, part in ipairs(acorn:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored, part.Massless = false, true
					local weld = Instance.new("WeldConstraint")
					weld.Part0, weld.Part1, weld.Parent = body, part, part
				end
			end
		end
	end
end
return AcornModel
