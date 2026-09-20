--!strict
-- Ornamental trees only. AcornTree, TreeService and the plot trees are separate.
local ServerStorage = game:GetService("ServerStorage")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local SceneryTrees = {}
local templates: { [string]: Model } = {}
local missingWarned = false

local function template(species: string): Model?
	if templates[species] then
		return templates[species]
	end
	local library = ServerStorage:FindFirstChild("SceneryTreeTemplates")
	local source = library and library:FindFirstChild(species)
	if not (source and source:IsA("Model")) then
		if not missingWarned then
			warn("[SceneryTrees] scenery templates unavailable; using the previous scenery trees")
			missingWarned = true
		end
		return nil
	end
	local model = source:Clone()
	-- Imported meshes have arbitrary pivots. Normalise around the actual trunk
	-- base, and fit the same envelope used by the existing placement clearances.
	local bounds, size = model:GetBoundingBox()
	if math.min(size.X, size.Y, size.Z) <= 0 then
		model:Destroy()
		return nil
	end
	model.WorldPivot = CFrame.new(bounds.Position.X, bounds.Position.Y - size.Y / 2, bounds.Position.Z)
	model:PivotTo(CFrame.identity)
	local envelope = Config.TREE_MESH
	local fit = math.min(envelope.width / size.X, envelope.canopyDepth / size.Z, envelope.height / size.Y)
	model:ScaleTo(model:GetScale() * fit)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.CastShadow = false
			p.Material = Enum.Material.SmoothPlastic
			p.Reflectance = 0
			-- Remove painted highlights and use the template's fully rough,
			-- nonmetallic surface. SmoothPlastic alone still has a glossy lobe.
			if p:IsA("MeshPart") then p.TextureID = "" end
			p.Color = if string.find(string.lower(p.Name), "foliage", 1, true)
				then (if species == "Evergreen" then Color3.fromRGB(67, 120, 90) else Color3.fromRGB(96, 150, 73))
				else Color3.fromRGB(117, 82, 57)
			local surface = p:FindFirstChild("MatteScenery")
			if surface and surface:IsA("SurfaceAppearance") then surface.Color = p.Color end
			-- RenderFidelity is authored on the template (plugin-only to write).
		end
	end
	templates[species] = model
	return model
end

function SceneryTrees.build(x: number, z: number, seed: number, scale: number, groundY: number, parent: Instance): boolean
	-- Tall silhouettes break up the distant grove. Broadleaf crowns frame the
	-- shopfronts; no evergreens are planted in the shop/driveway verge band.
	local street = seed >= 5000
	local species = if not street and seed % 4 == 0 then "Evergreen" else "Broadleaf"
	local source = template(species)
	if not source then
		return false
	end
	local model = source:Clone()
	model.Name = "SceneryTree"
	model:SetAttribute("Species", species)
	model:SetAttribute("PlacementSeed", seed)
	model:SetAttribute("StreetTree", street)
	model:SetAttribute("SceneryTree", true)
	-- Only shrink from the audited envelope, never stretch beyond it.
	local variation = if street then 0.94 + (seed % 4) * 0.02 else 1
	model:ScaleTo(source:GetScale() * scale * variation)
	model:PivotTo(CFrame.new(x, groundY, z) * CFrame.Angles(0, (seed * 2.39996) % (math.pi * 2), 0))
	local tint = if seed % 3 == 0 then Color3.fromRGB(240, 250, 228)
		elseif seed % 3 == 1 then Color3.fromRGB(249, 244, 229) else Color3.new(1, 1, 1)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Color = Color3.new(p.Color.R * tint.R, p.Color.G * tint.G, p.Color.B * tint.B)
			local surface = p:FindFirstChild("MatteScenery")
			if surface and surface:IsA("SurfaceAppearance") then surface.Color = p.Color end
		end
	end
	model.Parent = parent
	return true
end

return SceneryTrees
