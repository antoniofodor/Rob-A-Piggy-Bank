--!strict
--[[
	FencePanel -- the meshed fence panel, built once and cloned by both ends.

	THE FENCE WAS DESCRIBED TWICE AND THE TWO DESCRIPTIONS HAD DRIFTED
	(designer, this session: "that render of the current tier fence is not
	accurate, it doesn't look like the actual fence"). The fence on a lawn is
	a generated MESH -- `Config.FENCE_MESH`, tiled along the run by
	`PlotService.decorMeshPanel`. The fence on the SHOP CARD was a handful of
	primitives in `UpgradePreview.builders.fences`, hand-drawn from the same
	brief: posts and rails for the rickety, seven pickets and two rails for
	the picket, a slab with wires over it for the top three.

	Both were somebody's idea of that tier and only one of them was the tier.
	That is the near-identical second copy this project keeps recording -- the
	mini piggy, `Decor.buildOne`, `RideSound`, `Crates.luau`'s own rarity
	ladder -- arriving on the one surface where being wrong costs a purchase:
	a card showing a fence the buyer will not get.

	SO THE CARD CLONES THE PANEL THE LAWN STANDS. One mesh, one texture, one
	`Config.fenceMesh` row, and a tier whose art changes when the row changes
	rather than when somebody remembers to redraw it.

	WHY A MODULE RATHER THAN A CALL INTO PlotService: that is a server SERVICE
	and the card is drawn on the CLIENT, which is the same reason `House`,
	`Decor` and `PiggyModel` live in `Shared` -- the shop renders the real
	item. `InsertService:CreateMeshPartAsync` yields and is server-only, so the
	server makes one part per style into a folder in ReplicatedStorage and both
	ends clone from it. Exactly the shape `LootMesh`, `Decor` and `PiggyModel`
	already use.

	AN EMPTY ROW IS A WORKING STATE, and so is a dead one. `Config.fenceMesh`
	returns nil for a style with no id, `template` returns nil when nothing is
	parked, and BOTH callers already have a primitive fallback standing --
	`decorMeshPanel` returns false so `buildFence` uses the primitive
	decorator, and `builders.fences` draws the primitives it always drew. A
	moderated mesh costs the fence its upgrade and never its existence.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(script.Parent:WaitForChild("Config"))

local FencePanel = {}

-- The folder the templates are parked in. An INTERFACE rather than a label:
-- `template` finds it by this name on both ends, and its absence is what both
-- callers read as "not warmed, fall back to primitives".
FencePanel.FOLDER = "FencePanelTemplates"

-- EVERY STYLE `Config.FENCE_MESH` CAN ANSWER FOR, derived from the tier table
-- rather than listed, so a sixth tier is warmed with nothing to remember here.
-- `moat` resolves to `electric` inside `Config.fenceMesh` -- the wall is
-- identical and the water is the upgrade -- so the folder is keyed by the
-- style the CALLER asks with and two keys may share one mesh.
local function styles(): { string }
	local seen, out = {}, {}
	for _, tier in ipairs(Config.FENCE_TIERS) do
		if tier.style and not seen[tier.style] then
			seen[tier.style] = true
			table.insert(out, tier.style)
		end
	end
	return out
end

local warned = false
local tried = false

local function folder(): Folder?
	local f = ReplicatedStorage:FindFirstChild(FencePanel.FOLDER)
	return if f and f:IsA("Folder") then f else nil
end

--[[
	Load one MeshPart per style and park them. Server only, and safe to call
	repeatedly -- the second call is free.

	PCALLED AS A WHOLE AND NEVER THROWN, the rule `Decor.prewarm` set: a dead
	asset id, a moderated mesh or a slow web call may cost the fence its mesh
	and may never cost `Main` its boot. Warned ONCE, because a warning nobody
	can read is not a report.

	PER STYLE RATHER THAN ALL-OR-NOTHING, which is the one place this differs
	from `LootMesh`. There, seven parts make ONE object and half a bag is worse
	than no bag. Here each style is a whole fence on its own, so a rickety row
	that fails leaves the other four meshed and stands the primitive rickety --
	the same per-style fallback `buildFence` has always had.
]]
function FencePanel.prewarm(): boolean
	if tried then
		return folder() ~= nil
	end
	if not RunService:IsServer() then
		return folder() ~= nil
	end
	tried = true

	local made = Instance.new("Folder")
	made.Name = FencePanel.FOLDER
	local built, failed = 0, {}

	for _, style in ipairs(styles()) do
		local spec = Config.fenceMesh(style)
		if spec then
			local ok, part: any = pcall(function()
				-- THE SAME TWO FIDELITIES THE LAWN USES. Box collision because
				-- the Barrier beside a real panel is the only thing that
				-- collides and a card collides with nothing; Automatic render
				-- because a fence is backdrop and there are dozens of them --
				-- the argument `RenderFidelity` already settled for the trees.
				local p = game:GetService("InsertService"):CreateMeshPartAsync(spec.id,
					Enum.CollisionFidelity.Box, Enum.RenderFidelity.Automatic)
				-- `CreateMeshPartAsync` CARRIES THE MESH AND NOT THE MAP,
				-- which is how the trees shipped flat for a build with nothing
				-- in the log. The texture is a second asset and a second write.
				if spec.texture then
					p.TextureID = spec.texture
				end
				return p
			end)
			if ok and part then
				part.Name = style
				-- Left at the AUTHORED size. Both callers resize their own
				-- clones -- the lawn to `decorTop` and the run it is tiling,
				-- the card to the same height over a short run -- and a
				-- template sized here would have to be un-sized by each.
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.CastShadow = false
				if spec.tint then
					part.Color = spec.tint
				end
				part.Parent = made
				built += 1
			else
				table.insert(failed, ("%s (%s)"):format(style, tostring(part)))
			end
		end
	end

	if #failed > 0 and not warned then
		warned = true
		warn(("[FencePanel] %d fence panel(s) could not be loaded, so the "
			.. "primitive fence stands for them: %s"):format(#failed, table.concat(failed, ", ")))
	end

	if built == 0 then
		made:Destroy()
		return false
	end
	made.Parent = ReplicatedStorage
	return true
end

--[[
	The template for a style, or nil when there is nothing parked for it --
	which is every caller's signal to build primitives instead.

	THE CLIENT WAITS BRIEFLY RATHER THAN BUILDING NOTHING, the call `Decor`
	makes for the same reason: the shop is drawn at join, which is the one
	moment this can race the server's prewarm. It waits ONCE and remembers,
	so a style with no mesh at all costs one wait rather than one per card
	repaint -- and a repaint runs inside a render loop.
]]
local waited = false

function FencePanel.template(style: string): BasePart?
	local f = folder()
	if not f and not RunService:IsServer() and not waited then
		waited = true
		local found = ReplicatedStorage:WaitForChild(FencePanel.FOLDER, 10)
		f = if found and found:IsA("Folder") then found else nil
	end
	if not f then
		return nil
	end
	local part = f:FindFirstChild(style)
	return if part and part:IsA("BasePart") then part else nil
end

return FencePanel
