-- Run on the Studio server. Builds each lobby temporarily, audits clearance,
-- and removes every test model even if an assertion fails. No save changes.
local Shared = game.ReplicatedStorage.Shared
local Stand = require(Shared.BaseShopStand)
local Config = require(Shared.Config)
local Generic = require(Shared.HouseInterior)
local Themed = require(game.ServerScriptService.Services.ThemedInterior)
local folder = Instance.new("Folder")
folder.Name = "BaseShopStandAudit"
folder.Parent = workspace
local checks = 0
local rows = {}
local function check(ok, message)
	assert(ok, message)
	checks += 1
end
local function clear(refs, cf, size, label)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = {refs.model}
	for _, p in workspace:GetPartBoundsInBox(cf, size, params) do
		check(not (p.CanCollide and p.Transparency < 1), label .. " intersects " .. p:GetFullName())
	end
end
local function inspect(builder, tier)
	local refs = builder.build(folder, CFrame.new(0, 1800, 0), tier, 1)
	local id = if tier then tier.id else "generic"
	local positions = Stand.placements(refs.origin, refs.exit.Size.Z)
	for i, at in positions do
		clear(refs, at * CFrame.new(0, 4.3, .22), Vector3.new(8.4, 8.1, 7.1), id .. " stand " .. i)
		clear(refs, at * Stand.APPROACH_AT, Stand.APPROACH_SIZE, id .. " approach " .. i)
		-- Floor exists beneath the worker and the customer, including the largest kits.
		for _, offset in {Stand.NPC_AT, CFrame.new(0, 0, 5.3)} do
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = {refs.model}
			local hit = workspace:Raycast((at * offset).Position + Vector3.new(0, 1, 0), Vector3.new(0, -3, 0), params)
			check(hit ~= nil, id .. " has no floor beneath counter approach / NPC")
		end
	end
	local insideGap = math.abs(refs.origin:PointToObjectSpace(positions[1].Position).Z) * 2 - Stand.SIZE.X
	check(insideGap >= refs.exit.Size.Z + 1, id .. " pinches the doorway")
	-- Build the actual pair once; every theme uses the same shared geometry.
	if not tier then
		for i, kind in {"gadgets", "guardians"} do
			local model, prompt = Stand.build(kind, positions[i], refs.model)
			local npc = model:FindFirstChild("Shopkeeper")
			check(npc ~= nil, "missing static " .. kind .. " shopkeeper")
			local mount = model:FindFirstChild("ShopkeeperMount", true)
			for _, p in npc:GetDescendants() do
				if p:IsA("BasePart") then
					check(p.Anchored and not p.CanCollide, "NPC is simulated or blocks customers")
					for _, x in {-1, 1} do for _, y in {-1, 1} do for _, z in {-1, 1} do
						local corner = mount.WorldCFrame:PointToObjectSpace(p.CFrame:PointToWorldSpace(p.Size * Vector3.new(x,y,z) / 2))
						check(math.abs(corner.X) <= Stand.NPC_SIZE.X/2 and math.abs(corner.Z) <= Stand.NPC_SIZE.Z/2
							and corner.Y >= -.01 and corner.Y <= Stand.NPC_SIZE.Y, "NPC exceeds reserved bay")
					end end end
				end
			end
			check(prompt.HoldDuration == 0 and prompt.MaxActivationDistance == 6, "browse interaction changed")
			if kind == "guardians" then
				local gorilla = model:FindFirstChild("GuardPreview_gorilla")
				check(gorilla ~= nil, "missing creature display")
				local eye = gorilla:FindFirstChild("Eye_L")
				local head = gorilla:FindFirstChild("Head")
				check(eye ~= nil and head ~= nil and (eye.Position - head.Position):Dot(positions[i].ZVector) > 0,
					"gorilla must face the customer, not the shopkeeper")
			end
		end
	end
	table.insert(rows, {id = id, doorway = refs.exit.Size.Z, clearAisle = insideGap})
	refs.model:Destroy()
end
local ok, err = pcall(function()
	inspect(Generic, nil)
	for _, tier in Config.HOUSE_TIERS do
		if Themed.available(tier) then inspect(Themed, tier) end
	end
end)
folder:Destroy()
assert(ok, err)
return {checks = checks, interiors = rows}
