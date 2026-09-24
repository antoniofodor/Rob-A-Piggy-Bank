-- Approved OG ghost and hologram: alpha coats keep their layered silhouette.
-- Effects stay attached to the body and scale with it, including carried minis.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Scan = require(script.Parent.SpectralScanData)
local SpectralFX = {}
local TAG = "SpectralPiggy"
local sets = {}
local pending = {}
local started = false

function SpectralFX.attach(model: Instance, body: BasePart, key: string?)
	local old = model:FindFirstChild(TAG)
	if old then old:Destroy() end
	if key ~= "ghost" and key ~= "hologram" then return end
	local marker = Instance.new("ObjectValue")
	marker.Name = TAG
	marker.Value = body
	marker:SetAttribute("Skin", key)
	marker.Parent = model
	CollectionService:AddTag(marker, TAG)
end

local function dispose(marker)
	local set = sets[marker]
	if not set then return end
	if set.surfaceConnection then set.surfaceConnection:Disconnect() end
	for _, obj in ipairs(set.objects) do obj:Destroy() end
	sets[marker] = nil
end

local function track(marker)
	if sets[marker] or pending[marker] or not marker:IsA("ObjectValue") then return end
	pending[marker] = true
	task.spawn(function()
		-- ObjectValue and the coat templates can arrive after their marker.
		local body
		for _ = 1, 50 do
			if not marker.Parent then pending[marker] = nil; return end
			body = marker.Value
			if body and body:IsA("BasePart") and body.Parent then break end
			task.wait(.1)
		end
		pending[marker] = nil
		if not body or not body.Parent or not marker.Parent or sets[marker] then return end
		local model = marker.Parent
		local key = marker:GetAttribute("Skin")
		if key ~= "ghost" and key ~= "hologram" then return end
		local set = { body = body, model = model, key = key, objects = {}, rings = {}, wisps = {}, surfaces = {} }
		sets[marker] = set
		local function own(obj)
			table.insert(set.objects, obj)
			return obj
		end
		local function attachment(name)
			local a = own(Instance.new("Attachment"));a.Name = name;a.Parent = body
			return a
		end
		local function beam(a, b, color)
			local line = own(Instance.new("Beam"))
			line.Name = "SpectralBeam";line.Attachment0 = a;line.Attachment1 = b
			line.FaceCamera = true;line.LightEmission = 1;line.LightInfluence = 0
			line.Color = ColorSequence.new(color);line.Transparency = NumberSequence.new(.22)
			line.Segments = 6;line.Enabled = false;line.Parent = body
			return line
		end
		local outline = own(Instance.new("Highlight"))
		outline.Name = "SpectralRim";outline.Adornee = model;outline.FillTransparency = 1
		outline.OutlineColor = if key == "ghost" then Color3.fromRGB(154,235,223) else Color3.fromRGB(62,206,245)
		outline.OutlineTransparency = .70;outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Parent = body
		if key == "hologram" then
			for r, count in ipairs(Scan.counts) do
				local ring = { points = {}, beams = {} }
				for j = 1, count do ring.points[j] = attachment("ScanPoint") end
				for j = 1, count do ring.beams[j] = beam(ring.points[j],ring.points[j % count + 1],Color3.fromRGB(97,235,255)) end
				set.rings[r] = ring
			end
		else
			for j = 1, 9 do
				local a,b,c = attachment("WispRoot"),attachment("WispMiddle"),attachment("WispTip")
				local first,second = beam(a,b,Color3.fromRGB(132,242,220)),beam(b,c,Color3.fromRGB(132,242,220))
				first.Transparency = NumberSequence.new(.32);second.Transparency = NumberSequence.new(.42)
				table.insert(set.wisps,{a=a,b=b,c=c,first=first,second=second,index=j-1})
			end
		end
		local function surface(obj)
			if obj:IsA("SurfaceAppearance") and obj.Parent and obj.Parent:IsA("BasePart")
				and obj.Parent.Parent == model then
				set.surfaces[obj] = obj.EmissiveStrength
			end
		end
		for _,obj in ipairs(model:GetDescendants()) do surface(obj) end
		set.surfaceConnection = model.DescendantAdded:Connect(surface)
		marker.Destroying:Once(function()
			if set.surfaceConnection then set.surfaceConnection:Disconnect() end
			dispose(marker)
		end)
	end)
end

function SpectralFX.start()
	if started or not RunService:IsClient() then return end
	started = true
	for _,marker in ipairs(CollectionService:GetTagged(TAG)) do track(marker) end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(marker)
		local set = sets[marker]
		if set and set.surfaceConnection then set.surfaceConnection:Disconnect() end
		dispose(marker)
	end)
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 1/24 then return end
		accumulator = 0
		local t = workspace:GetServerTimeNow() % 6
		local camera = workspace.CurrentCamera
		for marker,set in pairs(sets) do
			local body = set.body
			if not marker.Parent or not body.Parent then dispose(marker);continue end
			local near = not camera or not body:IsDescendantOf(workspace) or (camera.CFrame.Position-body.Position).Magnitude < 180
			local scale = body.Size.X/12
			for sa,base in pairs(set.surfaces) do
				if sa.Parent then sa.EmissiveStrength = base*(1.015-.155*math.cos(t*math.pi*2/3)) else set.surfaces[sa] = nil end
			end
			if set.key == "hologram" then
				local f = t/6*(#Scan.frames-1)
				local index = math.floor(f)+1
				local blend = f-math.floor(f)
				local frameA,frameB = Scan.frames[index],Scan.frames[math.min(index+1,#Scan.frames)]
				for r,ring in ipairs(set.rings) do
					local valid = {}
					for j,a in ipairs(ring.points) do
						local p,q = frameA[r][j],frameB[r][j]
						valid[j] = p and q and near
						if valid[j] then a.Position = p:Lerp(q,blend)*scale end
					end
					for j,line in ipairs(ring.beams) do
						line.Width0 = .13*scale;line.Width1 = .13*scale
						line.Enabled = not not (valid[j] and valid[j % #ring.points+1])
					end
				end
			else
				for _,w in ipairs(set.wisps) do
					local j = w.index;local angle = .16+j*(math.pi-.32)/8
					local r = 1.16+.15*(j%2)
					local z = -.63+.36*(j%3)+.13*math.sin(t*math.pi/3+j*.61)
					local function point(u)
						local x = r*math.cos(angle)+.09*math.sin(u*math.pi*2+j)
						local y = r*math.sin(angle)+.03*math.sin(u*math.pi)
						return Vector3.new(-x*6,(z+u*.48)*6,y*6)*scale
					end
					local function pose(u)
						local right = Vector3.new(-.09*math.pi*2*math.cos(u*math.pi*2+j),.48,.03*math.pi*math.cos(u*math.pi)).Unit
						local ref = Vector3.new(0,0,1)
						local up = (ref-right*ref:Dot(right)).Unit
						return CFrame.fromMatrix(point(u),right,up)
					end
					w.a.CFrame=pose(0);w.b.CFrame=pose(.5);w.c.CFrame=pose(1)
					w.first.CurveSize0=.46*scale;w.first.CurveSize1=.46*scale
					w.second.CurveSize0=.46*scale;w.second.CurveSize1=.46*scale
					w.first.Width0=.012*scale;w.first.Width1=.19*scale
					w.second.Width0=.19*scale;w.second.Width1=.008*scale
					w.first.Enabled=near;w.second.Enabled=near
				end
			end
		end
	end)
end

return SpectralFX
