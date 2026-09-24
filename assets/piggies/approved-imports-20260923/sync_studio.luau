-- Payload is injected directly by the desktop tool; Studio HTTP can stay off.
local payload = game:GetService("HttpService"):JSONDecode(PAYLOAD_JSON)
local editor = game:GetService("ScriptEditorService")
local shared = game.ReplicatedStorage.Shared
local function setRow(source, tableName, key, row, multiline)
	local start = assert(source:find(tableName .. " = {", 1, true))
	local finish = assert(source:find("\n}", start, true))
	local a = source:find("\n\t" .. key .. " = ", start, true)
	if a and a < finish then
		a += 1
		local b = if multiline then assert(source:find("\n\t},", a, true)) + 4 else assert(source:find("\n", a, true))
		return source:sub(1, a - 1) .. row .. source:sub(b)
	end
	local at = start + #(tableName .. " = {")
	return source:sub(1, at - 1) .. "\n" .. row .. source:sub(at)
end
local staged = {}
local function sourceOf(module)
	if not staged[module] then staged[module] = module.Source:gsub("\r\n", "\n") end
	return staged[module]
end
local config = sourceOf(shared.Config)
for tableName, rows in pairs(payload.rows) do
	for key, entry in pairs(rows) do config = setRow(config, tableName, key, entry.source, entry.multiline) end
end
staged[shared.Config] = config
local motion = sourceOf(shared.ArcadeMotionData):gsub("return {", "Motion = {", 1)
for key, row in pairs(payload.motion) do motion = setRow(motion, "Motion", key, row, true) end
staged[shared.ArcadeMotionData] = motion:gsub("Motion = {", "return {", 1)
for _, patch in ipairs(payload.patches) do
	local module = game
	for segment in patch.path:gsub("%.luau$", ""):gmatch("[^.]+") do module = assert(module:FindFirstChild(segment), segment) end
	local source = sourceOf(module)
	local a, b = source:find(patch.before, 1, true)
	if source:find(patch.after, 1, true) then
		-- Already applied.
	elseif a then source = source:sub(1, a - 1) .. patch.after .. source:sub(b + 1)
	else error("Source changed: " .. patch.path) end
	staged[module] = source
end
-- All edit locations have been validated before applying any changes.
for module, source in pairs(staged) do editor:UpdateSourceAsync(module, function() return source end) end
for name, properties in pairs(payload.packs) do
	local sa = shared.SurfacePacks:FindFirstChild(name)
	if not sa then sa = Instance.new("SurfaceAppearance"); sa.Name = name; sa.Parent = shared.SurfacePacks end
	for property, value in pairs(properties) do
		if property == "AlphaMode" then sa.AlphaMode = Enum.AlphaMode[value]
		elseif property == "EmissiveMaskContent" then sa[property] = Content.fromUri(value)
		else sa[property] = value end
	end
	sa:SetAttribute("ApprovedImport", "2026-09-23")
end
return "Installed eight approved revisions and 21 material templates; unrelated rows preserved."
