--!strict
--[[
	GuardRig

	WHICH RIG A DOG WEARS, WHAT COLOUR ITS PIECES ARE, AND A STANDALONE COPY
	OF IT FOR THE SHOP.

	WHY THIS IS IN `Shared` AND `GuardVisual` IS NOT. This project's rule is
	that GEOMETRY THE SHOP RENDERS LIVES IN SHARED -- it is why `House`,
	`Decor` and `PiggyModel` are not services, and it is the reason nineteen
	lawn ornaments stopped being identical grey squares. The dog was the last
	catalogue still falling through to a flat swatch, and ClientMain's own
	comment said why: `GuardDog` is a SERVICE, so a client cannot build one.

	That reasoning was right about `GuardDog` and wrong about the DOG. What a
	guard actually is is three things, and only one of them belongs to the
	server: the BEHAVIOUR (patrol, chase, sleep, bark) which has no business
	on a client and stays where it is; the MESH TEMPLATES, which are imported
	assets; and the two pure questions below -- which rig, and what colour.
	Those two need `Config` and `GuardCatalog` and nothing else, so they are
	moved here rather than copied, and `GuardVisual` calls them.

	MOVED RATHER THAN COPIED IS THE WHOLE POINT. A second palette on the
	client would be the near-identical duplicate this project keeps recording
	as the thing that drifts -- and it would drift on the one screen where a
	player decides whether to spend a million coins, showing them a dog that
	is not the dog they get. One table, two readers.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Catalog = require(ReplicatedStorage.Shared.GuardCatalog)

local GuardRig = {}

-- Where the server leaves the handful of rigs a client is allowed to draw.
-- See `publishPreviews` in GuardVisual for which ones and why not all eight.
GuardRig.PREVIEW_FOLDER = "GuardPreviews"

local function color(v: any): Color3
	return Color3.fromRGB(v[1], v[2], v[3])
end

-- WHICH RIG THIS DOG WEARS: the skin's, if it names one, and the plot's own
-- tier otherwise.
--
-- Moved here from `GuardVisual` unchanged, including its reasoning. The tier
-- check this used to make (`Catalog[key].tier == level`) belonged to a game
-- where the dog was an upgrade and a creature rig was the top rung's reward.
-- The Guard rung is retired -- every plot has the same dog and the skin is
-- the variety -- so a Cerberus skin has to render a Cerberus on an ordinary
-- Shepherd. Nothing about the dog's BEHAVIOUR comes from here: the speed, the
-- catch radius, the hearing and the bone resistance are the tier's
-- (`Config.DOG_LEVEL`), which is what keeps a skin from being power.
function GuardRig.key(level: number, coatKey: string?): string?
	local coat = Config.DOG_COATS[coatKey or ""]
	local key = coat and coat.guardModel
	if key and Catalog[key] then
		return key
	end
	local tier = Config.DOG_TIERS[level]
	return tier and tier.model
end

-- IS THIS GUARD A DOG AT ALL? Three coats swap the rig for a creature, and
-- every sentence in the game that says "your dog" is wrong for those.
function GuardRig.isCreature(coatKey: string?): boolean
	local coat = Config.DOG_COATS[coatKey or ""]
	return (coat ~= nil and coat.guardModel ~= nil and Catalog[coat.guardModel] ~= nil)
end

-- WHAT TO CALL THE THING STANDING ON THE LAWN.
--
-- Reported as the Raptor skin "showing its a shepard": the nameplate prints
-- `tier.breed`, which is the TIER's breed and takes no notice of the coat, so
-- a player wearing the Raptor coat got a raptor labelled SHEPHERD. Every rig
-- but the tier's own was mislabelled and had been since creature coats
-- shipped.
--
-- AND `GuardCatalog[key].label` IS THE WRONG SOURCE, WHICH IS THE TRAP HERE.
-- It looks like the species and is not: it reads "Gorilla", "Raptor" and
-- "Triceratops" for the creatures and "Rex", "Scruffy" and "Titan" for the
-- dogs -- those are the breeds' GIVEN NAMES. Deriving the plate from it would
-- have swapped one mislabel for another and printed REX over every ordinary
-- coat in the game.
--
-- The coat's own `name` is the species for exactly the rows that need one, so
-- a creature is named by the same string the shop card sells it under and the
-- two cannot disagree. Everything else falls through to the tier, unchanged.
function GuardRig.species(coatKey: string?, level: number?): string
	if GuardRig.isCreature(coatKey) then
		return Config.DOG_COATS[coatKey :: string].name
	end
	local tier = Config.DOG_TIERS[level or Config.DOG_LEVEL]
	return (tier and tier.breed) or "Guard"
end

-- EVERY PIECE'S COLOUR, KEYED BY THE TONE THE CATALOGUE STAMPED ON IT.
--
-- Moved from `GuardVisual` for the reason in the header: the shop has to
-- reproduce this EXACTLY or the card lies, and the only way to guarantee that
-- is for there to be one of it.
--
-- CREATURE SKINS KEEP THEIR AUTHORED PALETTE AND ORDINARY COATS RECOLOUR
-- ANYTHING. A coat naming its own rig is that creature -- a Gorilla coat is
-- the gorilla's own grey, not a gorilla painted chocolate -- so the coat is
-- dropped and the rig's palette wins. That asymmetry is the single line
-- `if coat and coat.guardModel then coat = nil end` and it is load-bearing:
-- without it the three creature skins would render as recoloured dogs and be
-- worth nothing over the six that already are.
function GuardRig.tones(rigKey: string, coatKey: string?): { [string]: Color3 }
	local spec = Catalog[rigKey]
	local palette = spec.palette
	local coat = Config.DOG_COATS[coatKey or ""]
	if coat and coat.guardModel then
		coat = nil
	end
	local fur = if coat then coat.fur else color(palette.fur)
	local dark = if coat then coat.furDark else color(palette.dark)
	local light = if coat then fur:Lerp(Color3.new(1, 1, 1), 0.35) else color(palette.light)
	return {
		fur = fur, dark = dark, light = light, brow = fur, mask = fur:Lerp(light, 0.4),
		collar = if coat then coat.collar else color(palette.collar or { 223, 177, 44 }),
		eye = Color3.fromRGB(18, 18, 20), nose = Color3.fromRGB(29, 27, 30),
		mouth = Color3.fromRGB(41, 24, 31), teeth = Color3.fromRGB(248, 232, 189),
		inner = Color3.fromRGB(201, 126, 112), armor = Color3.fromRGB(131, 48, 78),
		accent = Color3.fromRGB(238, 122, 64), silver = Color3.fromRGB(171, 170, 182),
	}
end

-- THE RIGS A CLIENT CAN BE ASKED TO DRAW, DERIVED RATHER THAN LISTED.
--
-- There are eight imported rigs and the shop can only ever show FOUR of them:
-- the default the plot's own tier stands, plus the three creature coats that
-- name a rig of their own. Replicating all eight would put four rigs on every
-- client for nothing -- which is exactly the cost `GuardVisual`'s own note
-- gives for taking the copy away in the first place.
--
-- Derived from the two catalogues, so a coat added with a new `guardModel`
-- is previewable with nothing here to remember. That is the same call
-- `Config.animationKeys` makes about the ride poses, and for the same reason:
-- a hand-kept list is a list that goes stale silently, and the failure here
-- is a shop card that renders nothing.
function GuardRig.previewKeys(): { string }
	local seen: { [string]: boolean } = {}
	local keys: { string } = {}
	local function add(key: string?)
		if key and Catalog[key] and not seen[key] then
			seen[key] = true
			table.insert(keys, key)
		end
	end
	add(GuardRig.key(Config.DOG_LEVEL, nil))
	for coatKey in pairs(Config.DOG_COATS) do
		add(GuardRig.key(Config.DOG_LEVEL, coatKey))
	end
	table.sort(keys)
	return keys
end

-- A STANDALONE, PAINTED DOG FOR A SHOP CARD.
--
-- DELIBERATELY NOT `Visual.apply`, AND THE DIFFERENCE IS THE POINT. That
-- function builds a LIVE dog: bones, welds, a duty vest, a Root the animator
-- drives, an `AnimatedGuard` tag and a pivot seated against a plot. A shop
-- card wants none of it and must not have it -- a tagged rig inside a
-- ViewportFrame would join the guard animator's own sweep and be driven by a
-- state no card has.
--
-- So this clones the MESHES ONLY, anchored and inert, at the template's own
-- layout. The two share the catalogue, the rig choice and the palette, which
-- is everything that decides what the dog LOOKS like; they differ in exactly
-- the machinery that makes one of them alive.
--
-- TURNED THE SAME HALF TURN `Visual.apply` MAKES, so the preview and the real
-- dog agree about which way forward is. Every model in this project is
-- authored facing +Z and this one is not, which is the correction that has
-- bitten five times -- see the `CFrame.lookAt` entries in CLAUDE.md.
--
-- Returns nil rather than throwing when the templates have not been published
-- -- a missing rig is a card that falls back to its swatch, which is what
-- every one of them did until now, and never a HUD that fails to build.
function GuardRig.build(coatKey: string?, parent: Instance?): Model?
	local key = GuardRig.key(Config.DOG_LEVEL, coatKey)
	local spec = key and Catalog[key]
	if not spec then
		return nil
	end
	local folder = ReplicatedStorage:FindFirstChild(GuardRig.PREVIEW_FOLDER)
	local template = folder and folder:FindFirstChild(key)
	if not template then
		return nil
	end

	local tones = GuardRig.tones(key, coatKey)
	local pivot = (template :: Model):GetPivot()
	local turn = CFrame.Angles(0, math.pi, 0)

	local model = Instance.new("Model")
	model.Name = "GuardPreview_" .. key
	for _, source in ipairs((template :: Model):GetDescendants()) do
		if source:IsA("MeshPart") then
			local role = spec.parts[source.Name]
			if role then
				local mesh = source:Clone()
				-- The importer leaves a disconnected Motor6D/Bone mapping on
				-- every mesh. It is meaningless without the bone parts, which
				-- a preview does not build.
				mesh:ClearAllChildren()
				mesh.CFrame = turn * pivot:ToObjectSpace(source.CFrame)
				mesh.Anchored = true
				mesh.CanCollide, mesh.CanQuery, mesh.CanTouch = false, false, false
				mesh.CastShadow = false
				mesh.Material = Enum.Material.SmoothPlastic
				mesh.Color = tones[role.tone] or tones.fur
				mesh.Parent = model
			end
		end
	end
	if #model:GetChildren() == 0 then
		model:Destroy()
		return nil
	end
	model.Parent = parent
	return model
end

return GuardRig
