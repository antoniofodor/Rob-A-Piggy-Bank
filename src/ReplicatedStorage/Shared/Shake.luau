--!strict
-- Five-second ground/crate collection panel. The server schedules and debits each
-- numbered Acorn; this module only draws it and reports the player's gesture.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Config = require(script.Parent.Config)
local Theme = require(script.Parent.Theme)
local Remotes = require(script.Parent.Remotes)

local Shake = {}
local started = false

-- Pure layout/gesture arithmetic, also used by the isolated phone checks.
function Shake.layout(width: number, height: number): any
	local w, h = math.min(440, width - 24), math.min(284, height - 48)
	return { width = w, height = h, targetWidth = math.min(160, w - 32), targetHeight = 50,
		fieldHeight = h - 142, acornSize = 56 }
end
function Shake.contains(point: Vector2, position: Vector2, size: Vector2): boolean
	return point.X >= position.X and point.Y >= position.Y
		and point.X <= position.X + size.X and point.Y <= position.Y + size.Y
end

function Shake.start(parent: Instance)
	if started then return end
	started = true
	local player = Players.LocalPlayer
	local state: any = nil
	local nodes: { any } = {}
	local dragging: any = nil
	local carrying = false
	local ownBasket = false
	local promptSecond = -1
	local cooldowns: { [number]: number } = {}
	local cooldownReceived = false
	-- Whether an acorn-theft event is live (EventState.acornTheft). Another
	-- occupant's tree offers its prompt only while it is.
	local theftOpen = false
	local closedId = 0
	local plots: { [Instance]: any } = {}
	local screen = Instance.new("Frame")
	screen.Name = "ShakeOverlay"
	screen.Size = UDim2.fromScale(1, 1)
	screen.BackgroundTransparency = 1
	screen.ZIndex = 30
	screen.Parent = parent
	local root = Instance.new("Frame")
	root.Name = "ShakePanel"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Visible, root.Active = false, true
	root.ZIndex = 30
	root.Parent = screen
	Theme.card(root)
	local function label(name: string, text: string, position: UDim2, size: UDim2, fontSize: number): TextLabel
		local item = Instance.new("TextLabel")
		item.Name, item.Text, item.Position, item.Size = name, text, position, size
		item.BackgroundTransparency = 1
		item.TextXAlignment = Enum.TextXAlignment.Left
		item.Font, item.TextSize, item.TextColor3 = Enum.Font.GothamBold, fontSize, Theme.INK
		item.ZIndex = 31
		item.Parent = root
		return item
	end
	local title = label("Title", "SHAKE THE TREE", UDim2.fromOffset(14, 10), UDim2.new(1, -118, 0, 25), 19)
	local score = label("Caught", "0 CAUGHT", UDim2.fromOffset(14, 39), UDim2.new(1, -28, 0, 19), 14)
	local hint = label("Hint", "Drag each Acorn into the basket", UDim2.fromOffset(14, 60), UDim2.new(1, -28, 0, 18), 13)
	hint.Font = Enum.Font.Gotham
	local stop = Instance.new("TextButton")
	stop.Name, stop.Text = "Run", "RUN"
	stop.Position, stop.Size = UDim2.new(1, -91, 0, 10), UDim2.fromOffset(77, 44)
	stop.BackgroundColor3, stop.TextColor3 = Theme.INK, Theme.PAPER
	stop.Font, stop.TextSize, stop.ZIndex = Enum.Font.GothamBold, 15, 32
	stop.Parent = root
	Theme.corner(stop, 9)
	local track = Instance.new("Frame")
	track.Name, track.Position, track.Size = "Clock", UDim2.fromOffset(14, 82), UDim2.new(1, -28, 0, 5)
	track.BackgroundColor3, track.BorderSizePixel, track.ZIndex = Theme.MUTED_LIGHT, 0, 31
	track.Parent = root
	local timer = Instance.new("Frame")
	timer.Name, timer.Size, timer.BackgroundColor3 = "Remaining", UDim2.fromScale(1, 1), Theme.ACORN
	timer.BorderSizePixel, timer.ZIndex, timer.Parent = 0, 32, track
	local field = Instance.new("Frame")
	field.Name, field.Position = "LooseAcorns", UDim2.fromOffset(12, 90)
	field.BackgroundTransparency, field.ZIndex = 0.15, 32
	field.BackgroundColor3 = Color3.fromRGB(180, 194, 135)
	Theme.corner(field, 9)
	field.Parent = root
	local basket = Instance.new("Frame")
	basket.Name, basket.AnchorPoint = "CatchBasket", Vector2.new(0.5, 1)
	basket.Position = UDim2.new(0.5, 0, 1, -10)
	basket.BackgroundColor3, basket.ZIndex = Theme.ACORN, 33
	basket.Parent = root
	Theme.corner(basket, 13)
	Theme.outline(basket, 2, Theme.INK)
	local basketText = Instance.new("TextLabel")
	basketText.Name, basketText.Text = "DropHere", "DROP HERE"
	basketText.Size, basketText.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	basketText.TextColor3, basketText.Font, basketText.TextSize = Theme.PAPER, Enum.Font.GothamBold, 16
	basketText.ZIndex, basketText.Parent = 34, basket
	-- Woven lines preserve the same basket silhouette at phone size.
	for i = 1, 3 do
		local weave = Instance.new("Frame")
		weave.Size, weave.Position = UDim2.new(1, -16, 0, 2), UDim2.new(0, 8, 0, i * 12)
		weave.BackgroundColor3, weave.BackgroundTransparency = Theme.PAPER, 0.87
		weave.BorderSizePixel, weave.ZIndex, weave.Parent = 0, 33, basket
	end
	local function resize()
		local spec = Shake.layout(screen.AbsoluteSize.X, screen.AbsoluteSize.Y)
		root.Size = UDim2.fromOffset(spec.width, spec.height)
		field.Size = UDim2.new(1, -24, 0, spec.fieldHeight - 14)
		basket.Size = UDim2.fromOffset(spec.targetWidth, spec.targetHeight)
	end
	screen:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	resize()
	local function refreshPrompts()
		for plot, entry in pairs(plots) do
			local owner = plot:GetAttribute("OwnerUserId")
			local resident = plot:GetAttribute(Config.PLOT_RESIDENT_ATTRIBUTE)
			local occupied = owner ~= nil or resident ~= nil
			local own = owner == player.UserId
			local victimId = owner or plot:GetAttribute(Config.PLOT_RESIDENT_ID_ATTRIBUTE)
			local readyAt = if own then 0 else (cooldowns[victimId] or 0)
			local left = math.max(0, math.ceil(readyAt - workspace:GetServerTimeNow()))
			local cooldownText = if left > 0 then ("Steal ready in %d:%02d"):format(math.floor(left / 60), left % 60) else nil
			if entry.prompt then
				entry.prompt:SetAttribute(Config.PROMPT_COOLDOWN_ATTRIBUTE, cooldownText)
				-- Your own tree always; anybody else's only under the moon
				-- (step 2.6). The server refuses it regardless -- this is the
				-- client not offering a known no.
				entry.prompt.Enabled = not state and occupied and (own or theftOpen)
					and (not carrying or (own and ownBasket))
				local loose = plot:GetAttribute(Config.PLOT_GROUND_ACORNS_ATTRIBUTE) or 0
				local ripe = plot:GetAttribute(Config.PLOT_TREE_ACORNS_ATTRIBUTE) or 0
				entry.prompt.ActionText = if loose > 0 then "Collect Acorns" else "Shake Tree"
				entry.prompt:SetAttribute(Config.PROMPT_AMOUNT_ATTRIBUTE, ("%d %s"):format(if loose > 0 then loose else ripe, if loose > 0 then "ON GROUND" else "RIPE"))
			end
		end
	end
	Remotes.get("EventState").OnClientEvent:Connect(function(event)
		local open = type(event) == "table" and event.acornTheft == true
		if open ~= theftOpen then
			theftOpen = open
			refreshPrompts()
		end
	end)
	local cooldownRemote = Remotes.get("AcornCooldown")
	cooldownRemote.OnClientEvent:Connect(function(snapshot)
		cooldowns = snapshot or {}
		cooldownReceived = true
		refreshPrompts()
	end)
	cooldownRemote:FireServer()
	local function close()
		state, dragging = nil, nil
		root.Visible = false
		for _, node in ipairs(nodes) do node.button:Destroy() end
		table.clear(nodes)
		refreshPrompts()
	end
	local function submit(node: any)
		if not state or node.submitted then return end
		local birth, expires = Config.acornFallWindow(state.startedAt, node.index, state.count)
		local now = workspace:GetServerTimeNow()
		if now < birth + Config.ACORNS.catchMinSeconds or now > expires then return end
		node.submitted = true
		node.button.Visible = false
		Remotes.get("ShakeCatch"):FireServer(state.id, node.index)
	end
	local function point(input: InputObject): Vector2
		return Vector2.new(input.Position.X, input.Position.Y)
	end
	local function move(input: InputObject)
		if not dragging then return end
		if dragging.touch and dragging.input ~= input then return end
		if not dragging.touch and input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		local at = point(input) - field.AbsolutePosition
		dragging.node.button.Position = UDim2.fromOffset(at.X, at.Y)
	end
	Input.InputChanged:Connect(move)
	Input.InputEnded:Connect(function(input)
		local drag = dragging
		if not drag then return end
		if drag.touch then if drag.input ~= input then return end
		elseif input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		dragging = nil
		if Shake.contains(point(input), basket.AbsolutePosition, basket.AbsoluteSize) then submit(drag.node) end
	end)
	stop.Activated:Connect(function()
		if state then closedId = math.max(closedId, state.id); Remotes.get("ShakeStop"):FireServer(state.id); close() end
	end)
	Input.InputBegan:Connect(function(input, processed)
		if state and not processed and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB) then
			closedId = math.max(closedId, state.id); Remotes.get("ShakeStop"):FireServer(state.id); close()
		end
	end)
	Remotes.get("ShakeState").OnClientEvent:Connect(function(payload)
		if not payload then close(); return end
		if payload.ended then
			closedId = math.max(closedId, payload.id or 0)
			if not state or not payload.id or payload.id == state.id then close() end
			return
		end
		if payload.id <= closedId then return end
		if not state or state.id ~= payload.id then
			close()
			state = payload
			root.Visible = true
			title.Text = if payload.source == "storage" then "RAID THE CRATE" else "COLLECT ACORNS"
			field.BackgroundColor3 = if payload.source == "storage" then Color3.fromRGB(164, 118, 74) else Color3.fromRGB(180, 194, 135)
			for index = 1, payload.count do
				local button = Instance.new("TextButton")
				button.Name, button.Text = "Acorn" .. index, ""
				button.AnchorPoint, button.Size = Vector2.new(0.5, 0.5), UDim2.fromOffset(56, 56)
				button.BackgroundColor3, button.BackgroundTransparency = Theme.PAPER, 0.08
				button.ZIndex, button.Visible, button.Parent = 36, true, field
				Theme.corner(button, 28)
				Theme.outline(button, 2, Theme.ACORN_CAP)
				local glyph = Theme.acorn(button, 42)
				glyph.Position = UDim2.fromOffset(7, 7)
				for _, child in ipairs(glyph:GetDescendants()) do if child:IsA("GuiObject") then child.ZIndex += 36 end end
				local node = { button = button, index = index, submitted = false }
				table.insert(nodes, node)
				button.InputBegan:Connect(function(input)
					if dragging or node.submitted or not state then return end
					local touch = input.UserInputType == Enum.UserInputType.Touch
					if not touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
					-- Only a finger that STARTED on this acorn picks it up.
					if require(script.Parent.TouchOrigin).beganElsewhere(input, button) then return end
					dragging = { node = node, input = input, touch = touch }
				end)
				button.Activated:Connect(function(input)
					if input and input.KeyCode == Enum.KeyCode.ButtonA then submit(node) end
				end)
			end
			if Input:GetLastInputType() == Enum.UserInputType.Gamepad1 then
				hint.Text = "Select an Acorn · A to catch · B to run"
				GuiService.SelectedObject = nodes[1] and nodes[1].button
			else hint.Text = if payload.source == "storage" then "Drag from their crate into your basket" else "Drag loose Acorns into your basket" end
		end
		state = payload
		score.Text = ("%d / %d CAUGHT · %s"):format(payload.caught, payload.count, payload.victim)
		score.TextTruncate = Enum.TextTruncate.AtEnd
		refreshPrompts()
	end)
	Remotes.get("CarryUpdate").OnClientEvent:Connect(function(amount, _, _, _, _, own)
		carrying, ownBasket = amount > 0, own == true
		refreshPrompts()
	end)

	local function unwatch(plot: Instance)
		local entry = plots[plot]
		if not entry then return end
		plots[plot] = nil
		for _, connection in ipairs(entry.connections) do connection:Disconnect() end
		if entry.canopy and entry.canopy.Parent and entry.original then entry.canopy.CFrame = entry.original end
	end
	local function watch(plot: Instance)
		if not plot:IsA("Model") or plots[plot] then return end
		local entry: any = { connections = {} }
		plots[plot] = entry
		local function discover()
			local tree = plot:FindFirstChild("AcornOak")
			local collider = tree and tree:FindFirstChild("TrunkCollider")
			entry.prompt = collider and collider:FindFirstChild("ShakePrompt")
			local storage = plot:FindFirstChild("AcornStorage")
			local body = storage and storage:FindFirstChild("Storage")
			local canopy = tree and tree:FindFirstChild("Canopy")
			if canopy ~= entry.canopy then entry.canopy = canopy; entry.original = canopy and canopy.CFrame end
			refreshPrompts()
		end
		for _, key in ipairs({"OwnerUserId", Config.PLOT_RESIDENT_ATTRIBUTE, Config.PLOT_ACORNS_ATTRIBUTE, Config.PLOT_TREE_ACORNS_ATTRIBUTE, Config.PLOT_GROUND_ACORNS_ATTRIBUTE}) do
			table.insert(entry.connections, plot:GetAttributeChangedSignal(key):Connect(refreshPrompts))
		end
		table.insert(entry.connections, plot:GetAttributeChangedSignal(Config.PLOT_SHAKE_ATTRIBUTE):Connect(function()
			entry.at = plot:GetAttribute(Config.PLOT_SHAKE_ATTRIBUTE)
			if not entry.at and entry.canopy and entry.canopy.Parent then entry.canopy.CFrame = entry.original end
		end))
		table.insert(entry.connections, plot.DescendantAdded:Connect(function(item)
			if item.Name == "ShakePrompt" or item.Name == "Canopy" then discover() end
		end))
		discover()
	end
	local folderConnections = {}
	local folder: Instance? = nil
	local function attach(item: Instance)
		if item.Name ~= "Plots" or item == folder then return end
		for _, connection in ipairs(folderConnections) do connection:Disconnect() end
		for plot in pairs(plots) do unwatch(plot) end
		folder = item
		folderConnections = { item.ChildAdded:Connect(watch), item.ChildRemoved:Connect(unwatch) }
		for _, plot in ipairs(item:GetChildren()) do watch(plot) end
	end
	workspace.ChildAdded:Connect(attach)
	workspace.ChildRemoved:Connect(function(item)
		if item ~= folder then return end
		for _, connection in ipairs(folderConnections) do connection:Disconnect() end
		for plot in pairs(plots) do unwatch(plot) end
		folder = nil
	end)
	local folderNow = workspace:FindFirstChild("Plots")
	if folderNow then attach(folderNow) end
	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		if math.floor(now) ~= promptSecond then
			promptSecond = math.floor(now)
			if not cooldownReceived then cooldownRemote:FireServer() end
			refreshPrompts()
		end
		if state then
			local left = state.endsAt - now
			timer.Size = UDim2.fromScale(math.clamp(left / Config.ACORNS.shakeSeconds, 0, 1), 1)
			basketText.Text = ("BASKET · %.1fs"):format(math.max(0, left))
			for _, node in ipairs(nodes) do
				local birth, expires = Config.acornFallWindow(state.startedAt, node.index, state.count)
				local live = now >= birth and now <= expires and not node.submitted
				node.button.Visible = live
				if dragging and dragging.node == node and not live then dragging = nil end
				if live and (not dragging or dragging.node ~= node) then
					local columns = math.min(4, state.count)
					local rows = math.ceil(state.count / columns)
					local col, row = (node.index - 1) % columns, math.floor((node.index - 1) / columns)
					local x = if columns == 1 then field.AbsoluteSize.X / 2 else 28 + col * (field.AbsoluteSize.X - 56) / (columns - 1)
					local y = if rows == 1 then field.AbsoluteSize.Y / 2 else 28 + row * (field.AbsoluteSize.Y - 56) / (rows - 1)
					-- Settle onto the ground once, then remain draggable until time runs out.
					local fall = if state.source == "storage" then 0 else 12 * (1 - math.clamp((now - birth) / Config.ACORNS.fallSeconds, 0, 1))
					node.button.Position = UDim2.fromOffset(x, y - fall)
				end
			end
			if left < -Config.ACORNS.catchGrace - 1 then close() end
		end
		for _, entry in pairs(plots) do
			if entry.at and entry.canopy and entry.canopy.Parent then
				local age = now - entry.at
				if age >= 0 and age <= Config.ACORNS.shakeSeconds then
					entry.canopy.CFrame = entry.original * CFrame.Angles(0, 0, math.sin(age * 32) * 0.035)
				elseif age > Config.ACORNS.shakeSeconds then
					entry.canopy.CFrame = entry.original
					entry.at = nil
				end
			end
		end
	end)
end
return Shake
