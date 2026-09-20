--[[
	Run in Studio's command bar (Edit) after importing
	assets/shop-ui/icon-system-v1/models/plunger/plunger.fbx and
	.../bubblegum-bomb/bubblegum-bomb.fbx with the 3D Importer into Workspace.
	Prints the JSON for assets/shop-ui/icon-system-v1/models/gadget-imports.json;
	then run tools/build_gadget_templates.py.

	The importer seats a model wherever the camera was, so each part is moved
	into the AUTHORED frame by lining the parts' combined bounds up with the
	bounds recorded in that model's manifest.json. A size mismatch means the
	importer rotated or rescaled it, and is refused rather than guessed at.
]]
local HttpService = game:GetService("HttpService")

-- style = { workspace model name, authored min, authored max } in Roblox axes.
local WANT = {
	plunger = { "plunger", Vector3.new(-1.105, -1.3365, -1.105), Vector3.new(1.105, 2.48, 1.105) },
	gum = { "bubblegum-bomb", Vector3.new(-0.94, -0.86, -0.78), Vector3.new(0.94, 1.5619, 0.78) },
}

local result = {}
for style, want in pairs(WANT) do
	local model = workspace:FindFirstChild(want[1], true)
	assert(model, "Import " .. want[1] .. ".fbx into Workspace first")
	local parts = {}
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("MeshPart") then
			table.insert(parts, p)
			local cf, s = p.CFrame, p.Size / 2
			for _, c in ipairs({ -1, 1 }) do
				for _, d in ipairs({ -1, 1 }) do
					for _, e in ipairs({ -1, 1 }) do
						local w = cf:PointToWorldSpace(Vector3.new(c * s.X, d * s.Y, e * s.Z))
						lo, hi = lo:Min(w), hi:Max(w)
					end
				end
			end
		end
	end
	local size, authored = hi - lo, want[3] - want[2]
	assert((size - authored).Magnitude < 0.15,
		("%s imported at %s, expected %s -- rotated or rescaled?"):format(style, tostring(size), tostring(authored)))
	local shift = want[2] - lo
	local rows = {}
	for _, p in ipairs(parts) do
		local cf = p.CFrame + shift
		local c = { cf:GetComponents() }
		table.insert(rows, {
			name = p.Name, mesh = p.MeshId, texture = p.TextureID,
			size = { p.Size.X, p.Size.Y, p.Size.Z },
			meshSize = { p.MeshSize.X, p.MeshSize.Y, p.MeshSize.Z },
			cf = c,
			color = { math.round(p.Color.R * 255), math.round(p.Color.G * 255), math.round(p.Color.B * 255) },
			material = p.Material.Value,
		})
	end
	result[style] = rows
end
print(HttpService:JSONEncode(result))
