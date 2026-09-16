-- Imported mesh guards, rebuilt from the authored rigid-weight bone assignments.
local Storage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Catalog = require(Shared.GuardCatalog)
local Config = require(Shared.Config)
local Visual = {}
local defaults = { "terrier", "shepherd", "mastiff", "direwolf", "cerberus" }

local function point(v)
	-- Blender +Z up/-Y forward -> game +Y up/+Z forward.
	return Vector3.new(v[1], v[3], -v[2])
end
local function color(v) return Color3.fromRGB(v[1], v[2], v[3]) end
local function invisible(name, at, parent)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, Vector3.new(0.1, 0.1, 0.1), at
	p.Transparency, p.CanCollide, p.CanQuery, p.CanTouch = 1, false, false, false
	p.Massless = true
	p.Parent = parent
	return p
end
local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1, w.Parent = a, b, b
end

function Visual.key(level, coatKey)
	local coat = Config.DOG_COATS[coatKey or ""]
	local key = coat and coat.guardModel
	if key and Catalog[key] and Catalog[key].tier == level then return key end
	return defaults[level]
end

function Visual.apply(dog, tier, pivotHeight)
	local key = if tier then Visual.key(dog.level, dog.coat) else nil
	local old = dog.model:FindFirstChild("Visual")
	if old and old:GetAttribute("GuardKey") ~= key then old:Destroy(); old = nil end
	if not key then return end
	local spec = assert(Catalog[key], "Unknown guard " .. key)
	local model = old
	if not model then
		local templates = assert(Storage:FindFirstChild("GuardTemplates"), "Missing imported GuardTemplates")
		local template = assert(templates:FindFirstChild(key), "Missing imported guard " .. key)
		model = Instance.new("Model")
		model.Name = "Visual"
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		model:SetAttribute("GuardKey", key)
		model:SetAttribute("GuardHeight", spec.height)
		local bones = {}
		for name, bone in pairs(spec.bones) do
			bones[name] = invisible(name, CFrame.new(point(bone.head)), model)
		end
		for name, bone in pairs(spec.bones) do
			if bone.parent then
				local joint = Instance.new("Motor6D")
				joint.Name, joint.Part0, joint.Part1 = name, bones[bone.parent], bones[name]
				joint.C0 = bones[bone.parent].CFrame:ToObjectSpace(bones[name].CFrame)
				joint.Parent = bones[name]
			end
		end
		local meshFolder = Instance.new("Folder")
		meshFolder.Name, meshFolder.Parent = "Meshes", model
		local sourcePivot = template:GetAttribute("ImportPivot") or CFrame.identity
		for _, source in template:GetDescendants() do
			if source:IsA("MeshPart") then
				local role = assert(spec.parts[source.Name], "Unknown guard mesh " .. source.Name)
				local mesh = source:Clone()
				mesh:ClearAllChildren() -- retire the importer's disconnected Motor6D/Bone mapping
				mesh.CFrame = CFrame.Angles(0, math.pi, 0) * sourcePivot:ToObjectSpace(source.CFrame)
				mesh.Anchored, mesh.Massless = false, true
				mesh.CanCollide, mesh.CanQuery, mesh.CanTouch = false, false, false
				mesh.Material = Enum.Material.SmoothPlastic
				mesh:SetAttribute("GuardTone", role.tone)
				mesh.Parent = meshFolder
				weld(bones[role.bone], mesh)
			end
		end
		-- A separate paid-duty tell, independent of the cosmetic collar and angry eyes.
		local body = meshFolder:FindFirstChild("Body")
		local vest = Instance.new("Part")
		vest.Name = "DutyVest"
		vest.Size = Vector3.new(body.Size.X * 1.04, body.Size.Y * 0.72, body.Size.Z * 0.42)
		vest.CFrame, vest.Color = body.CFrame, Config.DOG_DUTY_VEST
		vest.Material, vest.Transparency = Enum.Material.SmoothPlastic, 1
		vest.CanCollide, vest.CanQuery, vest.CanTouch, vest.Massless = false, false, false, true
		vest.Parent = model
		weld(bones.Body, vest)
		model.PrimaryPart = bones.Root
		model:PivotTo(dog.body.CFrame * CFrame.new(0, -pivotHeight, 0))
		weld(dog.body, bones.Root)
		model.Parent = dog.model
		CollectionService:AddTag(model, "AnimatedGuard")
	end
	local palette = spec.palette
	local coat = Config.DOG_COATS[dog.coat or ""]
	-- Creature skins retain their authored palette; ordinary coats recolor any creature.
	if coat and coat.guardModel then coat = nil end
	local fur = if coat then coat.fur else color(palette.fur)
	local dark = if coat then coat.furDark else color(palette.dark)
	local light = if coat then fur:Lerp(Color3.new(1, 1, 1), 0.35) else color(palette.light)
	local tones = {
		fur = fur, dark = dark, light = light, brow = fur, mask = fur:Lerp(light, 0.4),
		collar = if coat then coat.collar else color(palette.collar or {223,177,44}),
		eye = Color3.fromRGB(18,18,20), nose = Color3.fromRGB(29,27,30),
		mouth = Color3.fromRGB(41,24,31), teeth = Color3.fromRGB(248,232,189),
		inner = Color3.fromRGB(201,126,112), armor = Color3.fromRGB(131,48,78),
		accent = Color3.fromRGB(238,122,64), silver = Color3.fromRGB(171,170,182),
	}
	for _, mesh in model.Meshes:GetChildren() do
		mesh.Color = assert(tones[mesh:GetAttribute("GuardTone")], mesh.Name)
		mesh:SetAttribute("CalmColor", mesh.Color)
		mesh:SetAttribute("AngryBrowColor", dark)
	end
	dog.model:SetAttribute("GuardHeight", spec.height)
end

function Visual.duty(dog, on)
	local model = dog.model:FindFirstChild("Visual")
	if model then model.DutyVest.Transparency = if on then 0 else 1 end
end

function Visual.state(dog, state)
	dog.model:SetAttribute("GuardState", state)
end
return Visual
