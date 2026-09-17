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
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local TweenService = game:GetService("TweenService")

-- THE DAY, AS ONE TABLE, because Midnight Heist (step 6.4) has to put these
-- five back EXACTLY when it ends. The reasoning for each value lives beside
-- the line that applies it in `setupLighting`; this is only where the
-- numbers are kept, so the moon's restore and the boot cannot disagree.
local DAY = {
	ClockTime = 14.5,
	Brightness = 2.4,
	Ambient = Color3.fromRGB(92, 98, 124),
	OutdoorAmbient = Color3.fromRGB(88, 100, 132),
	ColorShift_Top = Color3.fromRGB(255, 243, 210),
}

local WorldService = {}

-- Sized to the neighbourhood, not to a big round number. The old 900-stud
-- square left the plots as a small island in an empty field, which read as
-- unfinished no matter how good the plots themselves looked.
local GROUND_X = 780
-- Deep enough for two yards that now run 70 studs back from their plot
-- centres, plus the backdrop treeline beyond them.
local GROUND_Z = 560
-- TAKING THE TEXTURE OFF MADE THESE TOO BRIGHT, AND THAT IS ARITHMETIC
-- RATHER THAN TASTE. A material MULTIPLIES `Part.Color`, so for as long as
-- the ground carried a generated grass texture these values were being pulled
-- down by roughly a third before anybody saw them. Flat, they render at their
-- literal value for the first time -- and (118, 158, 88) rendered flat is an
-- acid pastel that shouted over the trees, the hills and the piggy.
--
-- So they came down about 30%, which is what the texture had been doing for
-- free. Anything that ever puts a texture back here has to put them BACK UP
-- by roughly the same amount, or the street goes dark: the pair of decisions
-- is one decision, and this comment is the only place that says so.
local GRASS = Color3.fromRGB(82, 114, 60)
local GRASS_DARK = Color3.fromRGB(70, 98, 52)

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
	-- The ground surface, both halves from one place in Config so the whole
	-- street switches together. A MaterialVariant is never BUILT here and
	-- could not be: those properties are plugin-gated, so a runtime write
	-- throws from a real Script while passing in the command bar. Rojo owns
	-- any variant under `src/MaterialService/`; this only names one, and a
	-- name MaterialService does not hold falls back to the base material.
	ground.Material = Config.GRASS_MATERIAL.material
	ground.MaterialVariant = Config.GRASS_MATERIAL.name
	ground.Color = GRASS
	ground.TopSurface = Enum.SurfaceType.Smooth
	ground.Parent = folder

	-- A ring of slightly darker grass so the play area has an edge instead of
	-- fading into an infinite green plane.
	--
	-- DELIBERATELY NOT THE LAWN VARIANT. It is LeafyGrass rather than Grass,
	-- so it could not carry one anyway -- a MaterialVariant only applies to
	-- its own BaseMaterial -- and that is the right answer rather than a
	-- limitation to work around. This band exists to read as rougher ground
	-- BEYOND the mown street, and giving it the same painted lawn surface as
	-- the gardens would delete the edge it is here to draw.
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
	-- THE TONEMAPPER WAS `Retro` AND NOBODY IN THIS REPO HAD PUT IT THERE,
	-- WHICH IS THE SINGLE BIGGEST THING THAT WAS MAKING THIS LOOK FLAT.
	--
	-- A `ColorGradingEffect` ships in Lighting on a new place, and its preset
	-- decides how every colour in the game lands: `Retro` is the pre-2023
	-- pipeline, which clips highlights hard and desaturates as it does it.
	-- On a street made of pink pigs and green lawns that is precisely the
	-- wrong end to lose -- measured against the same camera, the far hills
	-- washed to near-white and a full piggy rendered as a white blob with a
	-- pink edge. `Default` rolls the highlights off instead, so the pig stays
	-- pink and the distance keeps its colour.
	--
	-- IT LIVED IN THE PLACE FILE, WHERE NOTHING RECONCILES IT. That is the
	-- `GearPreview` trap this project already records: state that exists in
	-- the .rbxl and in no script, so a fresh place built from this repo would
	-- have got a different look from the one anybody tuned. It is created
	-- here if missing and its preset is set explicitly, which is what makes
	-- "a fresh empty place plus this repo gives the identical world" true of
	-- the lighting as well as of the geometry.
	local grading = Lighting:FindFirstChildOfClass("ColorGradingEffect")
	if not grading then
		grading = Instance.new("ColorGradingEffect")
		grading.Name = "ColorGrading"
		grading.Parent = Lighting
	end
	grading.TonemapperPreset = Enum.TonemapperPreset.Default

	
	-- WARM SUN, COOL SHADOWS. This is the whole of what makes a flat-shaded
	-- world read as stylised rather than as evenly filled, and it is worth
	-- being exact about why it works HERE in particular: every surface in
	-- this game is one flat colour with no texture detail on it, so the only
	-- thing left that can separate a lit face from a shaded one is the colour
	-- of the light landing on each. Give both the same neutral and a cube
	-- reads as a cube-shaped sticker.
	--
	-- So the two ambients are pushed toward BLUE and the sun toward CREAM.
	-- A shaded face is then not merely darker than a lit one, it is a
	-- different temperature, which the eye reads as form far more strongly
	-- than brightness alone. It is also why this can be done without
	-- crushing anything: the shadows stay bright enough for a nine-year-old
	-- to see what is in them, and still read as shadow.
	Lighting.Ambient = DAY.Ambient
	Lighting.OutdoorAmbient = DAY.OutdoorAmbient
	-- THE SUN IS TINTED WARM AND THE SHADOWS ARE LEFT COOL, which is what
	-- makes a flat-shaded street read as sunlit rather than as evenly filled.
	-- Every surface in this game is one flat colour, so the only thing that
	-- can separate a lit face from a shaded one is the LIGHT's own colour --
	-- there is no texture detail to carry it.
	Lighting.ColorShift_Top = DAY.ColorShift_Top
	Lighting.ColorShift_Bottom = Color3.fromRGB(96, 118, 150)
	-- 2.4 IS DELIBERATELY UNCHANGED. Four files reason about this number
	-- against `BloomEffect`'s threshold to decide how a Neon part reads, so
	-- moving it would silently re-tune every emissive surface in the game --
	-- the house light shows, the shop glazing, the neon skins. The exposure
	-- below is the right lever for "the image is too hot", because it acts on
	-- the final picture rather than on the sun's brightness relative to Neon.
	Lighting.Brightness = DAY.Brightness
	Lighting.ExposureCompensation = -0.04
	Lighting.ClockTime = DAY.ClockTime
	Lighting.GeographicLatitude = 12
	Lighting.EnvironmentDiffuseScale = 0.50
	-- Specular pulled back: a bright specular on SmoothPlastic is a white
	-- sheen, and a white sheen on a saturated cartoon surface is the one
	-- thing that reads as "plastic" rather than as "painted".
	Lighting.EnvironmentSpecularScale = 0.08
	-- Soft rather than crisp, deliberately. A hard-edged shadow is a
	-- photographic look; a cartoon wants the shape without the edge.
	Lighting.ShadowSoftness = 0.35
	Lighting.GlobalShadows = true

	-- HAZE WAS EATING THE SATURATION IT WAS MEANT TO ADD DEPTH WITH. At
	-- `Haze` 1.2 over `Density` 0.32 in a near-white atmosphere colour,
	-- everything past about a hundred studs was lerped toward white -- so the
	-- far half of a 350-stud street, which is most of what a player is
	-- looking at while they walk it, arrived desaturated. Atmosphere is kept
	-- because it is what puts air between the street and the hills; it is
	-- turned down until it separates distance without bleaching it, and its
	-- colour moved off white onto the sky's own blue so what it adds reads as
	-- sky rather than as fog.
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Parent = Lighting
	end
	atmosphere.Density = 0.14
	atmosphere.Offset = 0.05
	atmosphere.Haze = 0.18
	atmosphere.Glare = 0.05
	atmosphere.Color = Color3.fromRGB(198, 222, 250)
	atmosphere.Decay = Color3.fromRGB(126, 162, 214)

	-- The saturation pass. It is a GRADE rather than a repaint: pushing the
	-- colours here leaves every authored `Color3` in the game alone, which
	-- matters because the palette is derived in `Theme` and `Config` and a
	-- lot of it is solved against contrast floors that a repaint would break.
	local cc = Lighting:FindFirstChild("Grade") :: ColorCorrectionEffect?
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "Grade"
		cc.Parent = Lighting
	end
	cc.Saturation = 0.38
	-- Contrast is deliberately LOW while saturation is high, which is the
	-- pairing that reads as "cartoon" rather than as "photo with the colour
	-- turned up". Contrast deepens the shadows and crushes the palette
	-- toward black; saturation keeps every surface reading as its own hue.
	-- Pushing both is how a bright scene turns muddy.
	cc.Contrast = 0.08
	cc.Brightness = 0.02

	-- THE THRESHOLD WENT UP RATHER THAN THE INTENSITY DOWN, and that is the
	-- whole difference between a bloom and a blowout. At 1.1 the sunlit face
	-- of an ordinary pale part cleared the bar, so cream walls, the road
	-- markings and a full piggy all bloomed -- which is a wash over the
	-- picture rather than a glow on the things that are meant to be glowing.
	-- At 1.7 only genuinely emissive surfaces reach it, which is the set this
	-- project actually built for it: the Neon house effects, the shop
	-- glazing, the neon skins and the piggy's own coin lamp.
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if not bloom then
		bloom = Instance.new("BloomEffect")
		bloom.Parent = Lighting
	end
	bloom.Intensity = 0.50
	bloom.Size = 28
	bloom.Threshold = 1.8

	-- Sun rays, kept faint. They are the cheapest thing here that says the
	-- light has a DIRECTION, which a flat-shaded world otherwise cannot say
	-- on its own -- and they are the one effect in this block that can look
	-- like a fault if overdone, since an intensity that reads as "sunny" from
	-- one camera reads as a white smear from the one pointing at the sun.
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if not rays then
		rays = Instance.new("SunRaysEffect")
		rays.Parent = Lighting
	end
	rays.Intensity = 0.03
	rays.Spread = 0.8
end

-- MIDNIGHT HEIST'S DUSK (step 6.4), a tween for the window only. `on`
-- fades to `Config.MIDNIGHT_LIGHT.lighting`; off fades back and then SETS the
-- day values outright, so a tween that was interrupted, overlapped or left a
-- float a hair off still ends on ClockTime 14.5 exactly. There is no night in
-- this game, and this is what keeps that true.
local nightTween: Tween? = nil
local nightToken = 0
function WorldService.setNight(on: boolean)
	nightToken += 1
	local token = nightToken
	if nightTween then
		nightTween:Cancel()
		nightTween = nil
	end
	local spec = Config.MIDNIGHT_LIGHT
	local goal = if on then spec.lighting else DAY
	local tween = TweenService:Create(Lighting,
		TweenInfo.new(spec.fadeSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), goal)
	nightTween = tween
	tween:Play()
	if not on then
		task.delay(spec.fadeSeconds + 0.1, function()
			if nightToken == token then
				WorldService.restoreDay()
			end
		end)
	end
end

-- The day, set outright. Also the teardown if an event errors mid-moon.
function WorldService.restoreDay()
	if nightTween then
		nightTween:Cancel()
		nightTween = nil
	end
	for key, value in pairs(DAY) do
		(Lighting :: any)[key] = value
	end
end

WorldService.DAY = DAY

function WorldService.start()
	clearDefaults()
	buildGround()
	setupLighting()
end

return WorldService
