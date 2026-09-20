--!strict
-- Client-only tree, ground and storage contents. Plot attributes are the counts; these
-- decorative parts never participate in collision, collection or currency.
local RunService = game:GetService("RunService")
local Config = require(script.Parent.Config)
local AcornModel = require(script.Parent.AcornModel)

local AcornFill = {}
local started = false

-- THE HEAP GROWS WITH THE BALANCE AND PILES UP OVER THE RIM.
--
-- It used to be eight acorns at most, so a crate holding 8 looked exactly like
-- one holding 1,400. Now the stored amount sets a HEIGHT, on a log curve so
-- the first 63 lie loose on the floor and a big stash towers over the crate:
-- measured above the floor plank, 1.3 studs at 60, over the rim (1.5) by
-- about 120, 3.6 at 1,400 and the ceiling of 4.9 from about 8,000 up. The
-- label always shows the exact balance.
--
-- Only the SURFACE is real acorns. Under it is a solid bed of acorn-brown up to
-- the rim and a squashed dome above it, so a towering pile costs one layer of
-- acorn models (a 9 x 7 grid, `SURFACE_MAX`) and two plain parts, never hundreds of
-- meshes per plot.
local FLOOR_Y = 0.25                   -- top of the crate's floor plank
local RIM_Y = 1.75                     -- the bed stops just under the rim
local HALF_X, HALF_Z = 1.6, 1.2        -- inside the walls
local HEAP_MIN, HEAP_MAX = 0.55, 4.9   -- heap height above the floor plank
local HEAP_FULL_AT = 8000
local SPACING = 0.38
local SURFACE_MAX = 64
local BED_COLOUR = Color3.fromRGB(128, 78, 40)

local function heapHeight(stored: number): number
	local t = math.clamp(math.log(1 + stored) / math.log(1 + HEAP_FULL_AT), 0, 1)
	return HEAP_MIN + (HEAP_MAX - HEAP_MIN) * t ^ 1.6
end

-- The heap's top surface above the floor plank at crate-local (x, z): a flat
-- bed up to `bed`, then a dome of height `dome` over the whole opening.
local function surfaceY(x: number, z: number, bed: number, dome: number): number
	local r = (x / HALF_X) ^ 2 + (z / HALF_Z) ^ 2
	return bed + dome * math.max(0, 1 - r)
end

-- Grid points over the opening, nearest the middle first, so a small stash
-- gathers in the centre rather than along one wall.
local grid: { Vector2 } = {}
do
	local nx = math.floor(HALF_X * 2 / SPACING)
	local nz = math.floor(HALF_Z * 2 / SPACING)
	for ix = 0, nx do
		for iz = 0, nz do
			local x = -HALF_X + 0.2 + ix * (HALF_X * 2 - 0.4) / nx
			local z = -HALF_Z + 0.2 + iz * (HALF_Z * 2 - 0.4) / nz
			table.insert(grid, Vector2.new(x, z))
		end
	end
	table.sort(grid, function(a, b)
		return (a.X / HALF_X) ^ 2 + (a.Y / HALF_Z) ^ 2 < (b.X / HALF_X) ^ 2 + (b.Y / HALF_Z) ^ 2
	end)
end

local function plain(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, cf
	p.Color, p.Material = BED_COLOUR, Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- Use the imported mesh. Small modeled Acorns remain a network-load fallback.
local function acorn(parent: Instance, cf: CFrame, scale: number): Model
	local imported = AcornModel.build(parent, cf, scale)
	if imported then return imported end
	local model = Instance.new("Model")
	model.Name = "Acorn"
	local function part(name: string, size: Vector3, offset: CFrame, colour: Color3, shape: Enum.PartType)
		local p = Instance.new("Part")
		p.Name, p.Shape = name, shape
		p.Size = size * scale
		p.CFrame = cf * CFrame.new(offset.Position * scale) * offset.Rotation
		p.Color = colour
		p.Material = Enum.Material.SmoothPlastic
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.CastShadow = false
		p.Parent = model
	end
	part("Nut", Vector3.new(0.48, 0.60, 0.48), CFrame.new(), Config.ROLL_CURRENCY.colour, Enum.PartType.Ball)
	part("Cap", Vector3.new(0.58, 0.25, 0.58), CFrame.new(0, 0.23, 0), Color3.fromRGB(87, 55, 32), Enum.PartType.Ball)
	part("Stem", Vector3.new(0.18, 0.09, 0.09), CFrame.new(0.025, 0.40, 0) * CFrame.Angles(0, 0, math.rad(70)), Color3.fromRGB(87, 55, 32), Enum.PartType.Cylinder)
	model.WorldPivot = cf
	model.Parent = parent
	return model
end

function AcornFill.start()
	if started or not RunService:IsClient() then return end
	started = true
	local watched: { [Model]: any } = {}
	local function clear(state: any)
		for _, folder in ipairs(state.folders) do folder:Destroy() end
		table.clear(state.folders)
		table.clear(state.flights)
	end
	local function unwatch(plot: Model)
		local state = watched[plot]
		if not state then return end
		watched[plot] = nil
		for _, connection in ipairs(state.connections) do connection:Disconnect() end
		clear(state)
	end
	local function watch(plot: Instance)
		if not plot:IsA("Model") or watched[plot] then return end
		local state: any = { connections = {}, folders = {}, flights = {}, painting = false }
		watched[plot] = state
		local function repaint(removing: Instance?)
			if state.painting then return end
			state.painting = true
			clear(state)
			local function folder(name: string, parent: Instance): Folder
				local f = Instance.new("Folder")
				f.Name = name
				table.insert(state.folders, f)
				f.Parent = parent
				return f
			end
			local function count(key: string): number
				local raw = plot:GetAttribute(key)
				return if type(raw) == "number" then math.max(0, math.floor(raw)) else 0
			end
			local storage = plot:FindFirstChild("AcornStorage")
			local body = storage and storage:FindFirstChild("Storage")
			if body and body:IsA("BasePart") and body ~= removing and storage ~= removing then
				local fill = folder("AcornFill", storage :: Instance)
				local base = body.CFrame * CFrame.new(0, -0.125, 0)
				local stored = count(Config.PLOT_ACORNS_ATTRIBUTE)
				local top = FLOOR_Y
				if stored > 0 then
					local floor = base * CFrame.new(0, FLOOR_Y, 0)
					-- Counted from the first full layer, so covering the floor and
					-- starting to rise are one continuous growth, not a jump.
					local height = heapHeight(stored - #grid + 1)
					-- A stash too small to cover the floor is loose acorns on
					-- the planks; past that it is a bed with a dome on it.
					local covers = stored >= #grid
					local bed = if covers then math.min(height, RIM_Y - FLOOR_Y) else 0
					local dome = if covers then math.max(0, height - bed) else 0
					if covers then
						local bedTop = bed
						if bedTop > 0.05 then
							plain(fill, "HeapBed", Vector3.new(HALF_X * 2 + 0.1, bedTop, HALF_Z * 2 + 0.1),
								floor * CFrame.new(0, bedTop / 2, 0))
						end
						if dome > 0.05 then
							-- A sphere mesh on a part is the one primitive that
							-- can be SQUASHED; its lower half hides in the bed.
							local cap = plain(fill, "HeapDome", Vector3.new(1, 1, 1),
								floor * CFrame.new(0, bed, 0))
							local mesh = Instance.new("SpecialMesh")
							mesh.MeshType = Enum.MeshType.Sphere
							-- No wider than the inside of the crate, or its lower half
							-- shows through the walls below the rim.
							mesh.Scale = Vector3.new(HALF_X * 2, dome * 2, HALF_Z * 2)
							mesh.Parent = cap
						end
					end
					local rng = Random.new(7)
					for i = 1, math.min(stored, #grid, SURFACE_MAX) do
						local g = grid[i]
						local x = g.X + rng:NextNumber(-0.08, 0.08)
						local z = g.Y + rng:NextNumber(-0.08, 0.08)
						-- Nut centre a little under its own radius above the surface,
						-- so each acorn sits IN the heap rather than on it.
						local y = surfaceY(x, z, bed, dome) + (if covers then 0.2 else 0.27)
						acorn(fill, floor * CFrame.new(x, y, z)
							* CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6.28), rng:NextNumber(-0.5, 0.5)), 1)
						top = math.max(top, FLOOR_Y + y)
					end
				end
				local gui = Instance.new("BillboardGui")
				gui.Name, gui.Adornee = "StoredCount", body
				gui.Size = UDim2.fromOffset(150, 28)
				-- Rides above the heap, so a tall stash never buries its own count.
				gui.StudsOffsetWorldSpace = Vector3.new(0, math.max(2.3, top + 0.9), 0)
				gui.MaxDistance, gui.AlwaysOnTop = 85, false
				local label = Instance.new("TextLabel")
				label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 0.12
				label.BackgroundColor3, label.TextColor3 = Color3.fromRGB(87, 55, 32), Color3.fromRGB(255, 239, 194)
				label.Text, label.TextSize, label.Font = ("%d Acorns"):format(stored), 17, Enum.Font.GothamBold
				label.Parent = gui
				local corner = Instance.new("UICorner")
				corner.CornerRadius, corner.Parent = UDim.new(0, 7), label
				gui.Parent = fill
			end
			local tree = plot:FindFirstChild("AcornOak")
			local trunk = tree and tree:FindFirstChild("TrunkCollider")
			if trunk and trunk:IsA("BasePart") and trunk ~= removing and tree ~= removing then
				local base = trunk.CFrame * CFrame.new(Config.ACORNS.treeCollisionOffset * -1)
				local ripe = folder("RipeAcorns", tree :: Instance)
				local ground = folder("GroundAcorns", tree :: Instance)
				local dropped = plot:GetAttribute(Config.PLOT_SHAKE_ATTRIBUTE)
				-- A taller tree (step 2.7) lifts its crop with the canopy; the
				-- collider this is measured from does not move.
				local growth = tonumber(plot:GetAttribute(Config.PLOT_TREE_GROWTH_ATTRIBUTE)) or 1
				-- THE CROP IS MEASURED IN TREES, NOT IN STUDS. The radius and
				-- height below were solved against the oak at `treeScale` 1 and
				-- were literals -- so scaling the tree up left the crop hanging
				-- inside the trunk, with the ground acorns under a canopy that
				-- had moved out from over them. Scaled here, they ride the tree
				-- however big it gets. The ACORN's own size does not: an acorn
				-- is an object a player catches, not part of the tree.
				local k = Config.ACORNS.treeScale
				for i = 1, math.min(count(Config.PLOT_TREE_ACORNS_ATTRIBUTE), Config.ACORNS.growCap) do
					local angle = i * math.pi / 4
					acorn(ripe, base * CFrame.new(math.cos(angle) * 1.65 * k,
						(3.7 + (i % 2) * 0.5) * k * growth, math.sin(angle) * 1.65 * k), 0.85)
				end
				for i = 1, math.min(count(Config.PLOT_GROUND_ACORNS_ATTRIBUTE), Config.ACORNS.growCap) do
					local angle = i * math.pi / 4
					local landing = base * CFrame.new(math.cos(angle) * 2.25 * k, 0.28, math.sin(angle) * 2.25 * k)
					local model = acorn(ground, landing, 0.9)
					if type(dropped) == "number" and workspace:GetServerTimeNow() < dropped + Config.ACORNS.fallSeconds then
						table.insert(state.flights, { model = model, landing = landing, at = dropped })
					end
				end
			end
			state.painting = false
		end
		state.repaint = repaint
		for _, key in ipairs({ Config.PLOT_ACORNS_ATTRIBUTE, Config.PLOT_TREE_ACORNS_ATTRIBUTE,
			Config.PLOT_GROUND_ACORNS_ATTRIBUTE, Config.PLOT_SHAKE_ATTRIBUTE, "OwnerUserId",
			Config.PLOT_TREE_GROWTH_ATTRIBUTE }) do
			table.insert(state.connections, plot:GetAttributeChangedSignal(key):Connect(repaint))
		end
		local function relevant(item: Instance): boolean
			return item.Name == "Storage" or item.Name == "AcornStorage" or item.Name == "TrunkCollider" or item.Name == "AcornOak"
		end
		table.insert(state.connections, plot.DescendantAdded:Connect(function(item) if relevant(item) then repaint() end end))
		table.insert(state.connections, plot.DescendantRemoving:Connect(function(item)
			if relevant(item) then repaint(item) end
		end))
		repaint()
	end
	local storage = game:GetService("ReplicatedStorage")
	storage.DescendantAdded:Connect(function(item)
		if item.Name == AcornModel.templateName or (item.Parent and item.Parent.Name == AcornModel.templateName) then
			for _, state in pairs(watched) do state.repaint() end
		end
	end)
	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		for _, state in pairs(watched) do
			for i = #state.flights, 1, -1 do
				local flight = state.flights[i]
				local t = math.clamp((now - flight.at) / Config.ACORNS.fallSeconds, 0, 1)
				flight.model:PivotTo(flight.landing * CFrame.new(0, (1 - t * t) * 3.5, 0))
				if t >= 1 then table.remove(state.flights, i) end
			end
		end
	end)
	local activeFolder: Instance? = nil
	local folderConnections: { RBXScriptConnection } = {}
	local function detach()
		for _, connection in ipairs(folderConnections) do connection:Disconnect() end
		table.clear(folderConnections)
		local plots = {}
		for plot in pairs(watched) do table.insert(plots, plot) end
		for _, plot in ipairs(plots) do unwatch(plot) end
		activeFolder = nil
	end
	local function attach(plots: Instance)
		if plots.Name ~= "Plots" or plots == activeFolder then return end
		detach()
		activeFolder = plots
		table.insert(folderConnections, plots.ChildAdded:Connect(watch))
		table.insert(folderConnections, plots.ChildRemoved:Connect(function(plot) if plot:IsA("Model") then unwatch(plot) end end))
		for _, plot in ipairs(plots:GetChildren()) do watch(plot) end
	end
	workspace.ChildAdded:Connect(attach)
	workspace.ChildRemoved:Connect(function(item) if item == activeFolder then detach() end end)
	local plots = workspace:FindFirstChild("Plots")
	if plots then attach(plots) end
end
return AcornFill
