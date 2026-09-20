-- Imported mesh guards, rebuilt from the authored rigid-weight bone assignments.
local Storage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Catalog = require(Shared.GuardCatalog)
local Config = require(Shared.Config)
-- WHICH RIG AND WHAT COLOUR MOVED TO `Shared` SO THE SHOP CAN ASK THE SAME
-- QUESTIONS. Both are pure functions of Config and the catalogue, so they
-- carry nothing server-side with them -- see the header on GuardRig for why
-- copying them to the client instead would have been the wrong half of the
-- trade. This file keeps everything that makes a dog ALIVE.
local GuardRig = require(Shared.GuardRig)
local Visual = {}
-- Tier -> imported breed comes from `Config.DOG_TIERS[level].model`.
--
-- THE TEMPLATES ARE SERVER-SIDE ONLY, and were briefly copied into
-- ReplicatedStorage so the shop's Guard tier cards could render a real dog.
-- The Guard RUNG is retired (`Config.DOG_LEVEL`), so nothing on a client draws
-- a dog any more and eight rigs are no longer replicated to every player for
-- nothing. Anything that wants one again -- a dog-coat card rendering the
-- creature rig it names, say -- needs that copy back.

local function point(v)
	-- Blender +Z up/-Y forward -> game +Y up/+Z forward.
	return Vector3.new(v[1], v[3], -v[2])
end
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

-- Kept as a name this file's callers already use; the rule itself, and the
-- reasoning for it, are in `GuardRig`.
function Visual.key(level, coatKey)
	return GuardRig.key(level, coatKey)
end

-- THE COPY THE SHOP DRAWS FROM, AND THIS FILE'S OWN NOTE ASKED FOR IT BACK.
--
-- The comment at the top of this file has said since the Guard rung was
-- retired that the templates were briefly copied into ReplicatedStorage for
-- the shop, that nothing on a client drew a dog any more, and that "anything
-- that wants one again -- a dog-coat card rendering the creature rig it names,
-- say -- needs that copy back". A dog-coat card rendering its rig is exactly
-- what this is for.
--
-- FOUR RIGS RATHER THAN EIGHT, DERIVED. `GuardRig.previewKeys` walks the coat
-- catalogue for the rigs a card can actually ask for -- the plot's own tier
-- plus the three creature coats -- so the other four never leave the server.
-- That is the objection in this file's note answered rather than ignored:
-- what it objects to is eight rigs replicated for nothing, not one replicated
-- for something.
--
-- A MISSING TEMPLATE WARNS AND CARRIES ON. The shop degrades to the two-tone
-- swatch every one of these cards had until now, which is a card that looks
-- plainer rather than a game that fails to start -- the same call
-- `Decor.prewarm` makes about a lawn ornament never stopping the server.
function Visual.publishPreviews()
	local source = Storage:FindFirstChild("GuardTemplates")
	if not source then
		warn("[GuardVisual] no GuardTemplates to publish; shop dog cards will show their swatch")
		return
	end
	local folder = game:GetService("ReplicatedStorage"):FindFirstChild(GuardRig.PREVIEW_FOLDER)
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = GuardRig.PREVIEW_FOLDER
	local published = 0
	for _, key in ipairs(GuardRig.previewKeys()) do
		local template = source:FindFirstChild(key)
		if template then
			local copy = template:Clone()
			copy.Name = key
			copy.Parent = folder
			published += 1
		else
			warn(("[GuardVisual] no imported guard '%s'; its coat card will show its swatch"):format(key))
		end
	end
	folder.Parent = game:GetService("ReplicatedStorage")
	return published
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
		-- The templates are authored AT THE ORIGIN, feet on y 0, by
		-- blender/guards/build_runtime_assets.py -- the same frame the bone heads
		-- in GuardCatalog use. An `ImportPivot` attribute used to be read here; the
		-- generator never writes one, and the copy left on the place-file templates
		-- was stale (up to 26 studs up and 115 across), which is what floated every
		-- guard dog above the map. Never trust a pivot the repo does not write.
		local sourcePivot = CFrame.identity
		local bbox, bsize = template:GetBoundingBox()
		if math.abs(bbox.Y - bsize.Y / 2) > 0.5 or Vector2.new(bbox.X, bbox.Z).Magnitude > 1 then
			warn(("[GuardVisual] template %s is not seated at the origin (%s); the guard will be offset")
				:format(key, tostring(bbox.Position)))
		end
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
		-- HOW BIG THIS DOG ACTUALLY IS, measured per part in the root's own
		-- frame rather than off a bounding box (which is oriented by the
		-- model's pivot and transposes extents). GuardDog sizes the kennel
		-- from these and seats a sleeping dog inside it, so a rig that is
		-- regenerated larger grows its own doghouse instead of clipping
		-- through the walls.
		local rootCF = bones.Root.CFrame
		local width, back, front = 0, 0, 0
		for _, mesh in meshFolder:GetChildren() do
			local rel = rootCF:ToObjectSpace(mesh.CFrame)
			local half = mesh.Size / 2
			local reachX = math.abs(rel.RightVector.X) * half.X
				+ math.abs(rel.UpVector.X) * half.Y
				+ math.abs(rel.LookVector.X) * half.Z
			local reachZ = math.abs(rel.RightVector.Z) * half.X
				+ math.abs(rel.UpVector.Z) * half.Y
				+ math.abs(rel.LookVector.Z) * half.Z
			width = math.max(width, math.abs(rel.Position.X) + reachX)
			back = math.max(back, -(rel.Position.Z - reachZ))
			front = math.max(front, rel.Position.Z + reachZ)
		end
		-- The Sleep pose stretches the back legs out behind the hips, which on
		-- some rigs reaches further than the tail does.
		local hip = spec.bones.BackL
		if hip then
			local h = point(hip.head)
			back = math.max(back, -h.Z + h.Y + 0.2)
		end
		model:SetAttribute("GuardHalfWidth", width)
		model:SetAttribute("GuardBack", back)
		model:SetAttribute("GuardFront", front)
		weld(dog.body, bones.Root)
		model.Parent = dog.model
		CollectionService:AddTag(model, "AnimatedGuard")
	end
	-- ONE PALETTE, SHARED WITH THE SHOP. Creature skins retaining their own
	-- palette while ordinary coats recolour anything is the interesting half
	-- and it lives in `GuardRig.tones` now, so a card cannot disagree with the
	-- dog it is selling.
	local tones = GuardRig.tones(key, dog.coat)
	for _, mesh in model.Meshes:GetChildren() do
		mesh.Color = assert(tones[mesh:GetAttribute("GuardTone")], mesh.Name)
		mesh:SetAttribute("CalmColor", mesh.Color)
		mesh:SetAttribute("AngryBrowColor", tones.dark)
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
