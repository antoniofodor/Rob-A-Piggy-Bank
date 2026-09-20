--!strict
-- Compact catalogue geometry without scaling the text into a blurry thumbnail.
local Layout = {}

function Layout.metrics(width: number, height: number, preferred: Vector2)
	local compact = width < 740 or height < 430
	local targetWidth = if compact then math.min(132, preferred.X) else preferred.X
	return math.max(1, math.floor((width + 8) / (targetWidth + 8))),
		if compact then math.min(144, preferred.Y) else preferred.Y
end

function Layout.bindCard(card: GuiObject, baseHeight: number)
	local originals = {}
	for _, child in ipairs(card:GetChildren()) do
		if child:IsA("GuiObject") then
			table.insert(originals, {child=child, position=child.Position, size=child.Size,
				font=if child:IsA("TextLabel") then child.TextSize else nil})
		end
	end
	local function fit()
		local ratio = math.min(1, card.AbsoluteSize.Y / baseHeight)
		for _, entry in ipairs(originals) do
			local child, p, s = entry.child, entry.position, entry.size
			local h = math.round(s.Y.Offset * ratio)
			if entry.font then
				child.TextSize = if ratio < 1 then math.min(entry.font,13) else entry.font
				if s.Y.Scale == 0 then h = math.max(h, child.TextSize + 2) end
			end
			child.Position = UDim2.new(p.X.Scale,p.X.Offset,p.Y.Scale,math.round(p.Y.Offset*ratio))
			child.Size = UDim2.new(s.X.Scale,s.X.Offset,s.Y.Scale,h)
		end
	end
	local connection=card:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	card.Destroying:Connect(function() connection:Disconnect() end)
	fit()
end

function Layout.hasItems(grid: Instance): boolean
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("GuiObject") and child.Visible then return true end
	end
	return false
end

function Layout.bindSections(scroll: ScrollingFrame)
	local pending=false
	local function refresh()
		pending=false
		local children=scroll:GetChildren()
		table.sort(children,function(a,b)
			return (if a:IsA("GuiObject") then a.LayoutOrder else -1) < (if b:IsA("GuiObject") then b.LayoutOrder else -1)
		end)
		local header: TextLabel?=nil
		local hasItems=false
		local function finish()
			if header then header.Visible=hasItems and header.Text~="" end
		end
		for _,child in ipairs(children) do
			if child:IsA("TextLabel") then
				finish();header=child;hasItems=false
			elseif child:IsA("Frame") and child:FindFirstChildOfClass("UIGridLayout") then
				local populated=Layout.hasItems(child)
				child.Visible=populated;hasItems=hasItems or populated
			end
		end
		finish()
	end
	local function queue()
		if pending then return end
		pending=true;task.defer(refresh)
	end
	local function watch(child: Instance)
		if child:IsA("GuiObject") and child.Parent and child.Parent:FindFirstChildOfClass("UIGridLayout") then
			child:GetPropertyChangedSignal("Visible"):Connect(queue)
		end
	end
	for _,child in ipairs(scroll:GetDescendants()) do watch(child) end
	scroll.DescendantAdded:Connect(function(child) watch(child);queue() end)
	scroll.DescendantRemoving:Connect(queue)
	queue()
end

return Layout
