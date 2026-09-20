--!strict
--[[
	LegendaryModel -- a legendary skin is a whole model, not a coat of paint.

	The ordinary pig stays built underneath and is HIDDEN, never replaced:
	every prompt, the rob badge, the coin pile, the vault dial and every seat
	in PiggyBank is solved against the ordinary Body, and taking that part away
	would mean re-deriving all of them per skin. So the legendary meshes stand
	over it, seated off the Body's own CFrame, and the Body keeps doing its job
	at Transparency 1.

	THE SEAT IS DERIVED FROM THE LIVE BODY, never from a plot origin. The far
	row of plots is turned half round by one PivotTo after the pig is built,
	and the shop's mini is scaled and re-centred; the Body's own CFrame and
	Size carry both. `Config.LEGENDARIES` is written in the seat frame
	`Config.PIGGY_MESH` uses, so undoing the Body's own offset and turn gives
	the seat back exactly, and a legendary whose Body row matches the ordinary
	one lands on it to the stud.

	Shared because two ends build it: PiggyBank on the plots (anchored) and
	PiggyModel for the carried loot and the shop tile (unanchored, welded).
	Meshes load through `CreateMeshPartAsync`, which yields, so the templates
	are loaded once per id and cloned; `dress` builds at once when they are
	ready and otherwise loads and builds when they arrive, checking the model
	still wants that skin.
]]

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent:WaitForChild("Config"))
local Rigs = require(script.Parent:WaitForChild("Legendary"):WaitForChild("Rigs"))

local LegendaryModel = {}

-- The folder a dressed pig carries. The client's LegendaryFX finds its
-- helpers' targets by this name, so it is an interface, not a label.
LegendaryModel.NAME = "LegendarySkin"
-- Which legendary a folder is, and how many parts it holds -- the client
-- waits for that many to replicate before starting a helper on it.
LegendaryModel.KEY_ATTRIBUTE = "Legendary"
LegendaryModel.COUNT_ATTRIBUTE = "Parts"
-- The invisible anchor `Legendary/Idle` reads the rig frame and scale off.
LegendaryModel.RIG_NAME = "IdleRig"

-- A hidden base part remembers its own transparency on itself, so undressing
-- can put back exactly what was there -- the same stash-on-the-instance rule
-- the ride footsteps follow.
local HIDDEN_ATTRIBUTE = "LegendaryHiddenFrom"
-- The skin a model most recently asked for. An async dress checks it before
-- building, so a skin changed while meshes were loading is not overwritten.
local WANT_ATTRIBUTE = "LegendaryWant"

local HALF_TURN = CFrame.Angles(0, math.pi, 0)
-- Blender's origin in the seat frame: the (x, y, z) -> (x, 6.62 + z, -y)
-- map every `Config.LEGENDARIES` offset was converted with.
local RIG_LIFT = 6.62

-- The ordinary Body row, which is what the seat is recovered from.
local baseBody = (function()
	for _, entry in ipairs(Config.PIGGY_MESH) do
		if entry.part == "Body" then
			return entry
		end
	end
	return nil
end)()

local templates: { [string]: MeshPart } = {}
local ready: { [string]: boolean } = {}
local loading: { [string]: { thread } } = {}
local warned: { [string]: boolean } = {}

local function uri(id: string): string
	return if id:match("^%d+$") then "rbxassetid://" .. id else id
end

-- Loads every mesh a legendary needs, in parallel. Yields; returns whether
-- the whole set is available. A second caller while a load is running waits
-- on the first rather than starting its own.
function LegendaryModel.load(key: string): boolean
	if ready[key] ~= nil then
		return ready[key]
	end
	local rows = Config.LEGENDARIES[key]
	if not rows then
		return false
	end
	local queue = loading[key]
	if queue then
		table.insert(queue, coroutine.running())
		coroutine.yield()
		return ready[key] == true
	end
	queue = {}
	loading[key] = queue

	local me = coroutine.running()
	local remaining = #rows
	local waiting = false
	local failure: string? = nil
	for _, row in ipairs(rows) do
		task.spawn(function()
			if not templates[row.id] then
				local ok, made = pcall(function()
					return InsertService:CreateMeshPartAsync(uri(row.id),
						Enum.CollisionFidelity.Box, Enum.RenderFidelity.Automatic)
				end)
				if ok and made then
					templates[row.id] = made
				else
					failure = ("%s (%s): %s"):format(row.part, row.id, tostring(made))
				end
			end
			remaining -= 1
			if remaining == 0 and waiting then
				task.spawn(me)
			end
		end)
	end
	if remaining > 0 then
		waiting = true
		coroutine.yield()
	end

	ready[key] = failure == nil
	loading[key] = nil
	if failure and not warned[key] then
		warned[key] = true
		warn(("[LegendaryModel] %s could not load, so the pig wears its swatch "
			.. "instead: %s"):format(key, failure))
	end
	for _, t in ipairs(queue) do
		task.spawn(t)
	end
	return ready[key]
end

-- Starts every legendary loading in the background. Called at startup on
-- both ends so a dress is normally synchronous by the time anybody wears one.
function LegendaryModel.prewarm()
	for key in pairs(Config.LEGENDARIES) do
		task.spawn(LegendaryModel.load, key)
	end
end

function LegendaryModel.isReady(skinKey: string?): boolean
	local skin = skinKey and Config.SKINS[skinKey]
	local key = skin and skin.legendary
	return key ~= nil and ready[key] == true
end

-- Takes a legendary off: removes its folder and puts back every part it hid.
function LegendaryModel.undress(model: Instance)
	local worn = model:FindFirstChild(LegendaryModel.NAME)
	if worn then
		worn:Destroy()
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local was = d:GetAttribute(HIDDEN_ATTRIBUTE)
			if type(was) == "number" then
				d.Transparency = was
				d:SetAttribute(HIDDEN_ATTRIBUTE, nil)
			end
		end
	end
end

local function packFor(name: string): SurfaceAppearance?
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local packs = shared and shared:FindFirstChild("SurfacePacks")
	local pack = packs and packs:FindFirstChild(name)
	return if pack and pack:IsA("SurfaceAppearance") then pack else nil
end

export type Options = {
	anchored: boolean,
	-- The base parts to hide under the legendary. The caller knows which
	-- parts are "the pig" -- a plot model holds a dial and a coin pile as
	-- well, and those must stay.
	hide: { BasePart },
	-- Give it an idle sway (`Legendary/Rigs`). The plot's pig only: a mini is
	-- a few studs across in a shop tile or a thief's arms, where a 3-degree
	-- sway is noise and a welded part the client moves would fight its weld.
	rig: boolean?,
}

local function build(model: Instance, body: BasePart, key: string, opts: Options)
	local rows = Config.LEGENDARIES[key]
	if not rows or not baseBody then
		return
	end
	local s = body.Size.X / baseBody.size.X
	local seat = body.CFrame * (baseBody.rot or CFrame.identity):Inverse()
		* CFrame.new(-baseBody.offset * s)
	-- A legendary built at the wrong size is grown about a fixed point in the
	-- seat frame (see `Config.LEGENDARY_SCALE`). `grow` maps a seat-frame
	-- point; sizes and the idle rig's scale take `k` alongside `s`.
	local fix = Config.LEGENDARY_SCALE[key]
	local k = if fix then fix.scale else 1
	local pivot = if fix then fix.pivot else Vector3.zero
	local function grow(v: Vector3): Vector3
		return pivot + (v - pivot) * k
	end

	local folder = Instance.new("Model")
	folder.Name = LegendaryModel.NAME
	folder:SetAttribute(LegendaryModel.KEY_ATTRIBUTE, key)

	for _, row in ipairs(rows) do
		local template = templates[row.id]
		if template then
			local p = template:Clone()
			p.Name = row.part
			p.Size = row.size * s * k
			p.CFrame = seat * CFrame.new(grow(row.offset) * s) * HALF_TURN
			p.Anchored = opts.anchored
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Massless = true
			if row.surface then
				p.Color = Color3.new(1, 1, 1)
				p.Material = Enum.Material.SmoothPlastic
				local pack = packFor(row.surface)
				if pack then
					pack:Clone().Parent = p
				end
			else
				p.Color = row.color or Color3.new(1, 1, 1)
				p.Material = if row.neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
			end
			p.Transparency = if row.hidden then 1 else 0
			if not opts.anchored then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = body
				weld.Part1 = p
				weld.Parent = p
			end
			p.Parent = folder
		end
	end

	-- THE IDLE FRAME. `Legendary/Idle` swings whole parts about pivots given
	-- in the rig frame, so it needs that frame on the client: an invisible
	-- anchor on the armature's origin -- Blender (0,0,0), which the seat map
	-- puts at y 6.62 -- turned a half like every part, carrying the scale.
	-- No bones: the meshes are skinned but did not deform under rebuilt
	-- Bones, and every moving piece is one rigid part anyway (see Rigs).
	if opts.rig and Rigs[key] then
		local rigPart = Instance.new("Part")
		rigPart.Name = LegendaryModel.RIG_NAME
		rigPart.Size = Vector3.new(0.2, 0.2, 0.2)
		rigPart.Transparency = 1
		rigPart.CanCollide = false
		rigPart.CanQuery = false
		rigPart.CanTouch = false
		rigPart.CastShadow = false
		rigPart.Massless = true
		rigPart.Anchored = opts.anchored
		rigPart.CFrame = seat * CFrame.new(grow(Vector3.new(0, RIG_LIFT, 0)) * s) * HALF_TURN
		rigPart:SetAttribute("Scale", s * k)
		if not opts.anchored then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = rigPart
			weld.Parent = rigPart
		end
		rigPart.Parent = folder
	end
	local count = 0
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") then count += 1 end
	end
	folder:SetAttribute(LegendaryModel.COUNT_ATTRIBUTE, count)

	for _, part in ipairs(opts.hide) do
		if part.Parent and part:GetAttribute(HIDDEN_ATTRIBUTE) == nil then
			part:SetAttribute(HIDDEN_ATTRIBUTE, part.Transparency)
			part.Transparency = 1
		end
	end
	-- Parented LAST, whole, so it replicates as one piece and a client never
	-- sees a half-built legendary.
	folder.Parent = model
end

-- Puts the legendary for `skinKey` on, or takes any legendary off if the skin
-- is not one. Safe to call on every skin change.
function LegendaryModel.dress(model: Instance, body: BasePart, skinKey: string, opts: Options)
	LegendaryModel.undress(model)
	local skin = Config.SKINS[skinKey]
	local key = skin and skin.legendary
	if not key or not Config.LEGENDARIES[key] or not body:IsA("MeshPart") then
		model:SetAttribute(WANT_ATTRIBUTE, nil)
		return
	end
	model:SetAttribute(WANT_ATTRIBUTE, skinKey)
	if ready[key] == true then
		build(model, body, key, opts)
		return
	end
	task.spawn(function()
		if not LegendaryModel.load(key) then
			return
		end
		-- A mini that has not been parented yet is still wanted; only a
		-- destroyed one is not, and that one has lost its body.
		if not body.Parent then
			return
		end
		if model:GetAttribute(WANT_ATTRIBUTE) ~= skinKey
			or model:FindFirstChild(LegendaryModel.NAME) then
			return
		end
		build(model, body, key, opts)
	end)
end

return LegendaryModel
