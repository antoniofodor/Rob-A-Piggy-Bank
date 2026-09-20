--!nonstrict
-- Dump an imported house out of Studio for `assets/houses/tools/record_house_import.py`.
--
--     1. import <slug>-roblox.fbx in Studio (this uploads one mesh per part)
--     2. run this in Studio with MODEL set to what the importer named it
--     3. python assets/houses/tools/record_house_import.py <slug> <rev> dump.txt
--     4. python assets/houses/tools/build_house_runtime.py <slug> <rev>
--     5. add a Config.HOUSE_TEMPLATE row keyed by the tier's STYLE
--
-- WHY THIS EXISTS AS A FILE. The dump was taken ad hoc the first two times,
-- which was fine for two houses and is the wrong shape for eighteen: the
-- mesh ASSET IDS only exist inside the place after an import, so this dump is
-- the ONLY route from an FBX to a template, and it has to produce exactly the
-- text `record_house_import.py` parses -- a header carrying the model's AABB
-- and one `name|meshid|size|position` line per part.
--
-- THE AABB IS MEASURED PER PART RATHER THAN FROM `GetBoundingBox`, which is
-- the rule this project has already paid for twice: a Model's bounding box is
-- oriented by its PIVOT, so on a model whose first part happens to be rotated
-- it hands back transposed extents -- and the recorder divides those extents
-- by the authored Blender size to derive the import scale, so a transposed
-- box does not fail, it silently scales the house wrong.
--
-- ROTATION AND RESIZE ARE COUNTED, NOT ASSUMED. The recorder carries no
-- rotation and no `Size`, on the stated grounds that an import has identity
-- rotation and `Size == MeshSize`. That is an assumption about the importer,
-- so it is checked here and reported as `bad=` in the header, where the
-- recorder refuses the whole dump rather than writing a template that is
-- quietly wrong.
local MODEL = "shack-roblox"

local model = workspace:FindFirstChild(MODEL)
if not model then
	return ("no %s in Workspace -- set MODEL to what the importer named it"):format(MODEL)
end

local lines = {}
local bad, count = 0, 0
local lo, hi

for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("MeshPart") then
		count += 1
		local size, mesh = d.Size, d.MeshSize
		local rx, ry, rz = d.CFrame:ToEulerAnglesXYZ()
		if math.abs(rx) + math.abs(ry) + math.abs(rz) > 1e-4
			or (size - mesh).Magnitude > 1e-3 then
			bad += 1
		end
		local p, half = d.Position, size / 2
		local a, b = p - half, p + half
		lo = if lo then Vector3.new(math.min(lo.X, a.X), math.min(lo.Y, a.Y), math.min(lo.Z, a.Z)) else a
		hi = if hi then Vector3.new(math.max(hi.X, b.X), math.max(hi.Y, b.Y), math.max(hi.Z, b.Z)) else b
		table.insert(lines, ("%s|%s|%.4f,%.4f,%.4f|%.4f,%.4f,%.4f"):format(
			d.Name, d.MeshId, mesh.X, mesh.Y, mesh.Z, p.X, p.Y, p.Z))
	end
end

if count == 0 then
	return ("%s holds no MeshParts"):format(MODEL)
end

table.insert(lines, 1, ("parts=%d bad=%d lo=%.4f,%.4f,%.4f hi=%.4f,%.4f,%.4f"):format(
	count, bad, lo.X, lo.Y, lo.Z, hi.X, hi.Y, hi.Z))
return table.concat(lines, "\n")
