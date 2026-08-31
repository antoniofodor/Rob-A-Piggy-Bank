--!strict
--[[
	WorldService

	Ground and lighting.

	Kept in code rather than built in Studio so the whole look is in source
	control and reviewable -- change a colour here and every server gets it,
	instead of it living only in someone's local .rbxl.

	The default baseplate is removed on start. Its grid texture is the single
	biggest thing that makes a Roblox game read as unfinished.
]]

local Lighting = game:GetService("Lighting")

local WorldService = {}

-- Sized to the neighbourhood, not to a big round number. The old 900-stud
-- square left the plots as a small island in an empty field, which read as
-- unfinished no matter how good the plots themselves looked.
local GROUND_X = 780
-- Deep enough for two yards that now run 70 studs back from their plot
-- centres, plus the backdrop treeline beyond them.
local GROUND_Z = 560
local GRASS = Color3.fromRGB(118, 158, 88)
local GRASS_DARK = Color3.fromRGB(96, 134, 72)

local function clearDefaults()
	for _, child in ipairs(workspace:GetChildren()) do
		if child:IsA("BasePart") and (child.Name == "Baseplate" or child.Name == "SpawnLocation") then
			child:Destroy()
		end
	end
end

local function buildGround()
	local existing = workspace:FindFirstChild("World")
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = "World"
	folder.Parent = workspace

	local ground = Instance.new("Part")
	ground.Name = "Ground"
	ground.Size = Vector3.new(GROUND_X, 8, GROUND_Z)
	ground.Position = Vector3.new(0, -4.5, 0)
	ground.Anchored = true
	ground.Material = Enum.Material.Grass
	ground.Color = GRASS
	ground.TopSurface = Enum.SurfaceType.Smooth
	ground.Parent = folder

	-- A ring of slightly darker grass so the play area has an edge instead of
	-- fading into an infinite green plane.
	local border = Instance.new("Part")
	border.Name = "Border"
	border.Size = Vector3.new(GROUND_X + 140, 6, GROUND_Z + 140)
	border.Position = Vector3.new(0, -6, 0)
	border.Anchored = true
	border.Material = Enum.Material.LeafyGrass
	border.Color = GRASS_DARK
	border.TopSurface = Enum.SurfaceType.Smooth
	border.Parent = folder
end

local function setupLighting()
	Lighting.Ambient = Color3.fromRGB(112, 112, 126)
	Lighting.OutdoorAmbient = Color3.fromRGB(136, 140, 156)
	Lighting.Brightness = 2.4
	Lighting.ClockTime = 14.5
	Lighting.GeographicLatitude = 12
	Lighting.EnvironmentDiffuseScale = 0.45
	Lighting.EnvironmentSpecularScale = 0.35
	Lighting.ShadowSoftness = 0.3
	Lighting.GlobalShadows = true

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.15
	atmosphere.Haze = 1.2
	atmosphere.Glare = 0.2
	atmosphere.Color = Color3.fromRGB(226, 232, 240)
	atmosphere.Decay = Color3.fromRGB(184, 196, 214)

	-- A touch of extra saturation: the piggies are the colourful thing on
	-- screen and they should pop against the grass.
	local cc = Lighting:FindFirstChild("Grade") :: ColorCorrectionEffect?
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "Grade"
		cc.Parent = Lighting
	end
	cc.Saturation = 0.12
	cc.Contrast = 0.06
	cc.Brightness = 0.01

	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.5
	bloom.Size = 20
	bloom.Threshold = 1.1
end

function WorldService.start()
	clearDefaults()
	buildGround()
	setupLighting()
end

return WorldService
