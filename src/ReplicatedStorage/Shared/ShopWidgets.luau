--!strict
-- Flat, colourful shop furniture. All colours come from the shared theme.
local Shared = game:GetService("ReplicatedStorage").Shared
local Theme = require(Shared.Theme)
local Icons = require(Shared.ShopIcons)
local W = {}
W.colours = Theme.SHOP_COLOURS

function W.icon(parent: GuiObject, key: string, trim: boolean?): ImageLabel?
	return Icons.mount(parent, key, trim)
end

-- Static lighting keeps the art vivid without animating beside purchase controls.
function W.gradient(target: GuiObject, hue: Color3)
	local gradient = target:FindFirstChild("ShopGradient") :: UIGradient?
	if not gradient then
		gradient = Instance.new("UIGradient"); gradient.Name = "ShopGradient"
		gradient.Rotation = 90; gradient.Parent = target
	end
	target.BackgroundColor3 = Color3.new(1, 1, 1)
	gradient.Color = ColorSequence.new(hue:Lerp(Theme.PAPER, .62), hue)
end

function W.selection(parent: GuiObject): TextLabel
	local badge = W.text(parent, "SelectedCheck", utf8.char(0x2713), 21)
	badge.BackgroundTransparency = 0; badge.BackgroundColor3 = Theme.GOOD
	badge.TextColor3 = Theme.PAPER; badge.TextXAlignment = Enum.TextXAlignment.Center
	badge.AnchorPoint = Vector2.new(1, 0); badge.Position = UDim2.new(1, -8, 0, 8)
	badge.Size = UDim2.fromOffset(28, 28); badge.ZIndex = parent.ZIndex + 3
	W.round(badge, 14)
	return badge
end

function W.hero(parent: GuiObject, hue: Color3)
	W.gradient(parent, hue)
	for i = 1, 7 do
		local glow = W.frame(parent, "IconGlow" .. i, Theme.PAPER)
		glow.AnchorPoint = Vector2.new(.5, .5); glow.Position = UDim2.fromScale(.5, .5)
		glow.Size = UDim2.fromScale(.94 - i * .055, .98 - i * .055)
		glow.BackgroundTransparency = .96 - i * .006
		W.round(glow, 1000, false)
	end
	for i, point in ipairs({{.16,.27}, {.82,.30}, {.77,.76}}) do
		local sparkle = W.text(parent, "Glint" .. i, utf8.char(0x2726), if i == 1 then 25 else 17)
		sparkle.TextColor3 = Theme.PAPER; sparkle.TextTransparency = .15
		sparkle.Position = UDim2.fromScale(point[1], point[2]); sparkle.Size = UDim2.fromOffset(26, 26)
		sparkle.TextXAlignment = Enum.TextXAlignment.Center
	end
end

function W.lock(parent: GuiObject): Frame
	local lock = W.frame(parent, "RequirementLock", Theme.PAPER)
	lock.BackgroundTransparency = 1; lock.Size = UDim2.fromOffset(12, 15)
	lock.Position = UDim2.new(0, 9, .5, -8); lock.ZIndex = parent.ZIndex + 1
	local arch = W.frame(lock, "Shackle", Theme.PAPER)
	arch.Position = UDim2.fromOffset(2, 0); arch.Size = UDim2.fromOffset(8, 10)
	W.round(arch, 4, false)
	local cut = W.frame(arch, "Opening", Theme.PRESTIGE)
	cut.Position = UDim2.fromOffset(2, 2); cut.Size = UDim2.fromOffset(4, 7)
	W.round(cut, 2, false)
	local base = W.frame(lock, "Body", Theme.PAPER)
	base.Position = UDim2.fromOffset(0, 6); base.Size = UDim2.fromOffset(12, 9)
	W.round(base, 2, false)
	return lock
end

function W.frame(parent: Instance, name: string, colour: Color3?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = colour or Theme.PAPER
	f.Parent = parent
	return f
end

function W.round(target: GuiObject, radius: number?, outline: boolean?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 12)
	c.Parent = target
	if outline ~= false then
		local edge = Instance.new("UIStroke")
		edge.Name = "ShopOutline"
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Color = Theme.INK
		edge.Thickness = 2
		edge.Parent = target
	end
end

function W.text(parent: Instance, name: string, value: string, size: number?): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextSize = size or 18
	t.TextColor3 = Theme.INK
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.TextTruncate = Enum.TextTruncate.AtEnd
	t.Text = value
	t.Parent = parent
	return t
end

function W.button(parent: Instance, name: string, value: string, colour: Color3?, action: (() -> ())?): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = value
	b.Font = Enum.Font.FredokaOne
	b.TextSize = 17
	b.TextColor3 = Theme.INK
	b.BackgroundColor3 = colour or Theme.PAPER
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Selectable = true
	b.Parent = parent
	W.round(b)
	if action then b.Activated:Connect(action) end
	return b
end

function W.scroll(parent: Instance, name: string): ScrollingFrame
	local s = Instance.new("ScrollingFrame")
	s.Name = name
	s.Active = true -- Capture touch drags instead of passing them to the world.
	s.BackgroundTransparency = 1
	s.BorderSizePixel = 0
	s.ScrollBarThickness = 5
	s.ScrollBarImageColor3 = Theme.MUTED
	s.ScrollingDirection = Enum.ScrollingDirection.Y
	s.CanvasSize = UDim2.new()
	s.AutomaticCanvasSize = Enum.AutomaticSize.Y
	s.Parent = parent
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, 4)
	p.PaddingRight = UDim.new(0, 10)
	p.PaddingTop = UDim.new(0, 4)
	p.PaddingBottom = UDim.new(0, 8)
	p.Parent = s
	return s
end

function W.grid(parent: Instance, gap: number?): UIGridLayout
	local g = Instance.new("UIGridLayout")
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.CellPadding = UDim2.fromOffset(gap or 12, gap or 12)
	g.Parent = parent
	return g
end

-- Static previews: no continuously rotating icons or RenderStepped connections.
function W.preview(holder: GuiObject, model: Model?)
	local icon = holder:FindFirstChild("ShopIcon")
	if icon then icon:Destroy() end
	local old = holder:FindFirstChild("ShopPreview")
	if old then old:Destroy() end
	-- The tier backdrop is deliberately NOT cleared here: `iconFor` lays it
	-- down before calling this, and ShopSkinCards.backdrop replaces its own.
	local skin = holder:FindFirstChild("SkinImage")
	if skin then skin:Destroy() end
	if not model then return end
	local v = Instance.new("ViewportFrame")
	v.Name = "ShopPreview"
	v.BackgroundTransparency = 1
	v.Size = UDim2.fromScale(1, 1)
	v.Ambient = Theme.PAPER
	v.LightColor = Theme.PAPER
	v.LightDirection = Vector3.new(-1, -1, -1)
	v.Parent = holder
	local world = Instance.new("WorldModel")
	world.Parent = v
	model.Parent = world
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = false end
	end
	local cf, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	local categoryScene = model:GetAttribute("ShopScene") == true
	-- The category stages use a tighter crop than isolated catalogue previews.
	-- Their collision/mesh bounds contain more space than the visible subjects.
	camera.FieldOfView = if categoryScene then (if model.Name == "Category_companions" then 22 else 27) else 35
	if categoryScene then
		v.Ambient = Color3.fromRGB(145,145,145)
		v.LightColor = Color3.new(1,1,1)
	end
	camera.Parent = v
	v.CurrentCamera = camera
	local function fit()
		local aspect = if v.AbsoluteSize.Y > 0 then math.max(.2, v.AbsoluteSize.X / v.AbsoluteSize.Y) else 1
		local halfAngle = math.min(math.rad(camera.FieldOfView / 2), math.atan(math.tan(math.rad(camera.FieldOfView / 2)) * aspect))
		local distance = math.max(.1, size.Magnitude / 2) / math.sin(halfAngle) * 1.08
		local direction = Vector3.new(.65, .45, 1).Unit
		if categoryScene then
			direction = Vector3.new(.18,.30,1).Unit
			local orientation = CFrame.lookAt(cf.Position + direction,cf.Position)
			local right,up=orientation.RightVector,orientation.UpVector
			local projectedX=math.abs(right.X)*size.X+math.abs(right.Y)*size.Y+math.abs(right.Z)*size.Z
			local projectedY=math.abs(up.X)*size.X+math.abs(up.Y)*size.Y+math.abs(up.Z)*size.Z
			local depth=math.abs(direction.X)*size.X+math.abs(direction.Y)*size.Y+math.abs(direction.Z)*size.Z
			distance=math.max(projectedY/2/math.tan(math.rad(17.5)),projectedX/2/math.tan(math.rad(17.5))/aspect)*1.02+depth/2
		end
		camera.CFrame = CFrame.lookAt(cf.Position + direction * distance, cf.Position)
	end
	v:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
end

return W
