--!strict
-- Client-only tree, ground and storage contents. Plot attributes are the counts; these
-- decorative parts never participate in collision, collection or currency.
local RunService = game:GetService("RunService")
local Config = require(script.Parent.Config)
local AcornModel = require(script.Parent.AcornModel)

local AcornFill = {}
local started = false

-- A bounded decorative pile; the storage label always shows the exact balance.
local positions = {
	Vector3.new(-0.43, 0.47, -0.38), Vector3.new(0.43, 0.47, -0.38),
	Vector3.new(-0.43, 0.47, 0.38), Vector3.new(0.43, 0.47, 0.38),
	Vector3.new(0, 0.83, 0), Vector3.new(-0.64, 0.84, 0),
	Vector3.new(0.37, 0.84, -0.56), Vector3.new(0.37, 0.84, 0.56),
}

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
				for i = 1, math.min(stored, #positions) do
					local pos = positions[i]
					acorn(fill, base * CFrame.new(pos.X * 2.1, pos.Y + 0.65, pos.Z * 1.7) * CFrame.Angles(0, i * 2.4, 0), 1)
				end
				local gui = Instance.new("BillboardGui")
				gui.Name, gui.Adornee = "StoredCount", body
				gui.Size = UDim2.fromOffset(150, 28)
				gui.StudsOffsetWorldSpace = Vector3.new(0, 2.3, 0)
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
				for i = 1, math.min(count(Config.PLOT_TREE_ACORNS_ATTRIBUTE), Config.ACORNS.growCap) do
					local angle = i * math.pi / 4
					acorn(ripe, base * CFrame.new(math.cos(angle) * 1.65, 3.7 + (i % 2) * 0.5, math.sin(angle) * 1.65), 0.85)
				end
				for i = 1, math.min(count(Config.PLOT_GROUND_ACORNS_ATTRIBUTE), Config.ACORNS.growCap) do
					local angle = i * math.pi / 4
					local landing = base * CFrame.new(math.cos(angle) * 2.25, 0.28, math.sin(angle) * 2.25)
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
			Config.PLOT_GROUND_ACORNS_ATTRIBUTE, Config.PLOT_SHAKE_ATTRIBUTE, "OwnerUserId" }) do
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
