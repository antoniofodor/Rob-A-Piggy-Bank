--[[
	Run in Studio's command bar (EDIT mode) after importing the meshes in
	import/meshes/ with the 3D Importer. Prints one CSV line per MeshPart the
	importer created, so every mesh id is captured in ONE go instead of being
	copied off parts one at a time:

	    file,part,MeshId,ColorMap,NormalMap,RoughnessMap

	Paste the output into a file (import/mesh-ids.csv is the expected name)
	and hand it over with import/asset-ids.csv; the session that owns Config
	merges the ids into the Config.PIGGY_MESH / LEGENDARIES / LOOT_MESH rows.

	Then DELETE the imported models from Workspace. Anything left in the
	Workspace in Edit is debris Rojo never reconciles (CLAUDE.md, GearPreview).
	`tools/capture_gadget_imports.luau` is the same idea for the gadget FBXs.
]]

-- The FBX / OBJ stems staged by tools/stage_import.py. The importer names the
-- model after the file; a stem is matched case-insensitively as a prefix so
-- "dragon-complete" also finds "dragon-complete (1)".
local STEMS = {
	"pig_body_closedback",
	"dragon-complete",
	"phoenix-complete",
	"rainbowtiger-complete",
	"stormwolf-complete",
	"loot-bag-cloth",
	"loot-bag-lining",
	"loot-bag-rope",
	"loot-bag-gold",
	"loot-bag-golddark",
	"loot-bag-goldlight",
	"loot-bag-nostril",
}

local function id(content: string): string
	if content == nil or content == "" then
		return ""
	end
	return content
end

local function surface(part: MeshPart, field: string): string
	local sa = part:FindFirstChildOfClass("SurfaceAppearance")
	if not sa then
		return ""
	end
	return id((sa :: any)[field])
end

local lines = { "file,part,MeshId,ColorMap,NormalMap,RoughnessMap" }
local seen = 0
for _, stem in ipairs(STEMS) do
	local lower = stem:lower()
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("Model") and inst.Name:lower():sub(1, #lower) == lower then
			for _, p in ipairs(inst:GetDescendants()) do
				if p:IsA("MeshPart") then
					seen += 1
					table.insert(lines, ("%s,%s,%s,%s,%s,%s"):format(
						stem, p.Name, id(p.MeshId),
						surface(p, "ColorMap"), surface(p, "NormalMap"), surface(p, "RoughnessMap")))
				end
			end
		elseif inst:IsA("MeshPart") and inst.Parent == workspace
			and inst.Name:lower():sub(1, #lower) == lower then
			-- An OBJ or a single-part FBX may come in as a bare MeshPart.
			seen += 1
			table.insert(lines, ("%s,%s,%s,%s,%s,%s"):format(
				stem, inst.Name, id(inst.MeshId),
				surface(inst, "ColorMap"), surface(inst, "NormalMap"), surface(inst, "RoughnessMap")))
		end
	end
end

print(("-- %d MeshPart(s) across the staged imports; copy the lines below into import/mesh-ids.csv"):format(seen))
print(table.concat(lines, "\n"))
