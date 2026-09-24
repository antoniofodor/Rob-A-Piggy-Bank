--!strict
--[[
	LootMesh -- the loot bag as seven MeshParts instead of twenty-odd
	primitives.

	`UpgradePreview.builders.sack` builds the Bigger Sack card AND the bag a
	thief carries home (`HeistService.buildLootBag` goes through that builder,
	which is the whole reason the loot was moved onto it). This is the mesh
	version of exactly that object, exported from the same `sack.blend` the
	shop icon is rendered from and split per material, because a MeshPart takes
	one `Color` and the blend is seven flat Principled colours with not one
	image in it.

	AN EMPTY ROW IS A WORKING STATE, and that is the contract rather than a
	courtesy. `Config.lootMesh()` returns nil for the WHOLE spec unless every
	row carries an id -- a half-uploaded set is a sack with no rope on it and
	nothing in any log to say so -- and a nil here is the primitives build,
	which is the picture the game shipped with. `build` returns false and
	touches nothing; the caller falls back.

	PREWARMED AND CLONED, NEVER BUILT ON DEMAND, the same call `PiggyModel`,
	`CoinModel` and `House` all already make. `InsertService:CreateMeshPartAsync`
	YIELDS and cannot be called from a client at all, while `build` runs inside
	`UpgradePreview.build`'s own pcall and from a render loop repainting shop
	cards -- yielding there would stall a repaint, and throwing there would
	swallow the model. So the server makes the seven parts once into a folder
	in ReplicatedStorage and both ends clone them.

	SCALE 1 IS LEVEL 0, which is the one number a reader of this file has to
	hold. The export stands exactly 3.008 studs to the top of its frill, and so
	does the primitives bag at `s = 0.8` -- its topmost frill ball reaches
	3.76 * s, and 3.76 * 0.8 is 3.008 to the stud. So the assembly is scaled by
	`s / LEVEL0_SCALE` rather than by `s`: passing the builder's own `s`
	straight through would ship a level-0 bag a fifth too small, with every
	clearance `builders.sack` records (the thief's thighs, their head, the
	coins on the ground) measured against a bag that is not the one standing
	there.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent:WaitForChild("Config"))

local LootMesh = {}

-- The folder the templates are parked in. An INTERFACE rather than a label:
-- `build` finds it by this name on both ends, and the absence of it is what
-- `build` reads as "not warmed yet, fall back".
LootMesh.FOLDER = "LootMeshTemplates"

-- What `builders.sack` computes for level 0 (`0.8 + level * 0.18`), and what
-- the export was sized against. Kept here as a named constant rather than
-- inlined so the two ends of that sentence are findable from each other: move
-- the builder's base scale and this moves with it, or the mesh silently stops
-- being the same size as the primitives it replaces.
LootMesh.LEVEL0_SCALE = 0.8

local warned = false
local tried = false

local function templates(): Folder?
	local folder = ReplicatedStorage:FindFirstChild(LootMesh.FOLDER)
	return if folder and folder:IsA("Folder") then folder else nil
end

--[[
	Load the seven meshes once and park them. Server only -- a client cannot
	call `CreateMeshPartAsync` -- and safe to call repeatedly; the second call
	is free. Returns whether the templates are standing.

	PCALLED AS A WHOLE AND NEVER THROWN, for the reason `Decor.prewarm` is: a
	dead asset id, a moderated mesh or a slow web call must cost the loot bag
	its upgrade and must never cost `Main` its boot. The warning is fired ONCE,
	because a warning nobody can read is not a report.
]]
function LootMesh.prewarm(): boolean
	if tried then
		return templates() ~= nil
	end
	if not RunService:IsServer() then
		return templates() ~= nil
	end
	tried = true

	local spec = Config.lootMesh()
	if not spec then
		return false
	end

	local ok, made: any = pcall(function()
		local insert = game:GetService("InsertService")
		local folder = Instance.new("Folder")
		folder.Name = LootMesh.FOLDER
		for _, row in ipairs(spec) do
			-- Box collision because nothing ever queries this -- it is welded
			-- to a thief's chest or standing in a ViewportFrame -- and Precise
			-- render because the card is read at arm's length and the carried
			-- bag is the thing a whole street is watching run home.
			local p = insert:CreateMeshPartAsync(row.id,
				Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
			p.Name = row.part
			-- SIZE BEFORE CFRAME, the rule `PiggyBank.swapToMesh` and
			-- `PiggyModel.prewarm` both keep: resizing a MeshPart scales it
			-- about its own centre, so a part seated first and sized second
			-- ends up seated for the size it used to be. The template is left
			-- at scale 1; `build` sizes and seats each clone.
			p.Size = row.size
			p.Color = row.colour
			-- SmoothPlastic like everything else in this catalogue: this
			-- project has recorded `Material.Metal` rendering gold as olive
			-- beside a flat gold, and `Fabric` rendering a peach sack as mud.
			p.Material = Enum.Material.SmoothPlastic
			-- Exactly what `buildLootBag` writes over the primitives build, so
			-- a clone is already in the state the carry path wants and an
			-- anchored part welded to a humanoid can never pin it.
			p.Anchored = false
			p.Massless = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Parent = folder
		end
		return folder
	end)

	if not ok or not made then
		if not warned then
			warned = true
			warn(("[LootMesh] the loot bag's meshes could not be loaded, so "
				.. "the primitives sack is standing instead: %s"):format(tostring(made)))
		end
		return false
	end

	made.Parent = ReplicatedStorage
	return true
end

--[[
	Clone the seven templates into `model`, at the sack level whose scale is
	`s` -- the same `s` `builders.sack` computes, so the call site reads as one
	line and nothing has to be converted there. Returns false without touching
	the model when there is nothing to clone, which is the caller's signal to
	build the primitives bag.

	NOTHING IS PARENTED UNTIL ALL SEVEN EXIST. A guard that fires after the
	loop has already parented some of them is the worst shape this can fail in
	-- `PiggyBank` paid for exactly that once, where a mesh was standing in the
	pig while every landmark after the guard was skipped and the log said the
	swap was off. Half a bag with a rope and no cloth is worse than no bag.

	THE PART NAMES ARE THE INTERFACE. `Bag` in particular is not a label:
	`HeistService.buildLootBag` renames whichever child is called `Bag` to
	`Body` and makes it the PrimaryPart, so the weld, the carry label, the
	trail and the nab prompt all seat on the cloth mesh with not one line of
	that function changed.
]]
function LootMesh.build(model: Model, s: number): boolean
	local spec = Config.lootMesh()
	local folder = templates()
	if not (spec and folder) then
		return false
	end

	local k = s / LootMesh.LEVEL0_SCALE
	local made: { BasePart } = {}
	for _, row in ipairs(spec) do
		local template = folder:FindFirstChild(row.part)
		if not (template and template:IsA("BasePart")) then
			for _, p in ipairs(made) do
				p:Destroy()
			end
			return false
		end
		local p = (template :: BasePart):Clone()
		p.Name = row.part
		-- Size, then seat. See the template above.
		p.Size = row.size * k
		-- The turn is applied AFTER the seat and in the part's own frame, so a
		-- caller that pivots the whole model later -- the icon helper, or the
		-- weld onto a thief -- carries every piece round together. A rotation
		-- folded into the seat would not. `rot` is a per-row field for the
		-- reason `Config.PIGGY_MESH` has one: the importer mirrors Z on that
		-- pig, and if it does here the half turn goes on ALL seven rows or the
		-- pieces face opposite ways.
		p.CFrame = CFrame.new(row.offset * k) * (row.rot or CFrame.identity)
		table.insert(made, p)
	end

	for _, p in ipairs(made) do
		p.Parent = model
	end
	return true
end

return LootMesh
