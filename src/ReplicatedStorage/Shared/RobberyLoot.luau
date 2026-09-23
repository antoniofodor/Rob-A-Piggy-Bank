--!strict
-- Odds text and a non-modal discovery reel. Awards always come from the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local RobberyLoot = {}

function RobberyLoot.layout(view: Vector2): any
	local narrowLandscape = view.X > view.Y and view.X < 620
	local width = if narrowLandscape then math.max(180,view.X-276) else math.min(310,view.X-92)
	local height = if view.Y < 350 then 100 else 124
	return {width=width,height=height,
		x=if narrowLandscape then 72+width/2 else view.X/2,
		y=if view.Y>view.X then 205 else math.min(124,view.Y-96-height)}
end

function RobberyLoot.percent(chance: number): string
	if chance > 0 and chance < .001 then return "<0.1%" end
	local value = string.format("%.1f", chance * 100):gsub("%.0$", "")
	return value .. "%"
end

function RobberyLoot.describe(odds: any): (string, string)
	if not odds then return "", "" end
	local chance = RobberyLoot.percent(odds.chance or 0)
	if odds.kind == "shop" then
		if odds.locked then
			return "ITEM 0% · Requires rank " .. odds.minRank,
				("%d completed robberies · %s item chance when unlocked"):format(
					Config.RAP_SHEET_RANK[odds.minRank+1], RobberyLoot.percent(odds.baseChance))
		end
		local parts = {}
		for _, tier in ipairs(Config.RARITY_ORDER) do
			table.insert(parts,Config.RARITIES[tier].label .. " " .. RobberyLoot.percent((odds.tiers or {})[tier] or 0))
		end
		return "ITEM " .. chance .. " · Finish every slice" .. (if odds.resale then " · Duplicate sells for coins" else ""),
			"If item: " .. table.concat(parts," · ")
	end
	if odds.chance == 1 then
		-- A clean crack takes the worn skin or another one they own, half
		-- and half, and a half with nothing in it gives its share away.
		local others = odds.others or 0
		local pick
		if odds.worn and others > 0 then
			pick = ("%s 50%% · or 1 of %d others"):format(odds.name or "Worn skin", others)
		elseif odds.worn or others == 0 then
			pick = (odds.name or "Skin") .. " · " .. Config.RARITIES[odds.tier].label
		else
			pick = ("A random skin · 1 of %d"):format(others)
		end
		return "SKIN 100% · Finish every slice", pick
	end
	-- A NEIGHBOUR PAYS COINS AND NOTHING ELSE, BY DESIGN, and "0%" read as a
	-- broken skin roll. A skin comes only from a clean crack on a real player
	-- (Config.SKIN_STEAL), so say that instead of printing a chance that was
	-- never on offer.
	if odds.kind == "resident" then
		return "COINS ONLY", "Skins come from robbing players"
	end
	return (if odds.kind == "skin" then "SKIN " else "ITEM ") .. chance, odds.reason or "Coins only"
end

function RobberyLoot.start(gui: ScreenGui, iconFor: (string, string, Frame) -> ())
	local queue = {}
	local running = false
	local function show(payload: any)
		local pool, won = payload.pool, payload.won
		if not won or type(pool) ~= "table" or #pool == 0 then return end
		local root = Instance.new("Frame")
		root.Name, root.AnchorPoint = "RobberyDiscovery", Vector2.new(.5,0)
		root.ZIndex, root.Active = 40, false
		root.Parent = gui
		Theme.card(root)
		local function fit()
			local layout = RobberyLoot.layout(gui.AbsoluteSize)
			root.Size = UDim2.fromOffset(layout.width,layout.height)
			root.Position = UDim2.fromOffset(layout.x,layout.y)
			local status = root:FindFirstChild("Status") :: TextLabel?
			if status then status.Position=UDim2.fromOffset(8,layout.height-23) end
			local reel = root:FindFirstChild("Reel") :: Frame?
			if reel then
				local height=layout.height-55
				reel.Size=UDim2.new(1,-16,0,height)
				for _, tile in reel.Strip:GetChildren() do
					if tile:IsA("Frame") then
						tile.Size=UDim2.fromOffset(80,height-1)
						tile.Model.Size=UDim2.new(1,0,0,height-21)
						tile.Caption.Position=UDim2.fromOffset(2,height-21)
					end
				end
			end
		end
		fit()
		local resize = gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
		local function label(name: string, y: number, height: number, size: number): TextLabel
			local l = Instance.new("TextLabel")
			l.Name,l.BackgroundTransparency,l.ZIndex = name,1,42
			l.Position,l.Size = UDim2.fromOffset(8,y),UDim2.new(1,-16,0,height)
			l.Font,l.TextSize,l.TextColor3 = Theme.FONT,size,Theme.INK
			l.Text,l.Parent = "",root
			return l
		end
		local title = label("Title",5,20,15)
		title.Text = "VAULT FIND!"
		local cardHeight = RobberyLoot.layout(gui.AbsoluteSize).height
		local reelHeight = cardHeight-55
		local status = label("Status",cardHeight-23,18,10)
		status.TextScaled = true
		status.Text = if payload.mode=="carried" then "Discovered · Get it home!" else "Discovered in the vault"
		local window = Instance.new("Frame")
		window.Name,window.BackgroundTransparency,window.ClipsDescendants = "Reel",1,true
		window.Position,window.Size,window.ZIndex = UDim2.fromOffset(8,28),UDim2.new(1,-16,0,reelHeight),41
		window.Parent = root
		local strip = Instance.new("Frame")
		strip.Name = "Strip"
		strip.BackgroundTransparency,strip.Size,strip.Parent = 1,UDim2.fromOffset(2000,68),window
		local count = math.min(12,math.max(4,#pool*2))
		local stride = 88
		for i=1,count+2 do
			local entry = if i==count then won else pool[(i-1)%#pool+1]
			local tile = Instance.new("Frame")
			tile.Position,tile.Size = UDim2.fromOffset((i-1)*stride,0),UDim2.fromOffset(80,reelHeight-1)
			tile.BackgroundColor3,tile.BorderSizePixel,tile.Parent = Theme.PAPER_DEEP,0,strip
			Theme.corner(tile,8)
			local holder = Instance.new("Frame")
			holder.Name = "Model"
			holder.BackgroundTransparency,holder.Size,holder.Parent = 1,UDim2.new(1,0,0,reelHeight-21),tile
			pcall(iconFor,entry.kind,entry.key,holder)
			local name = Instance.new("TextLabel")
			name.Name = "Caption"
			name.BackgroundTransparency,name.Font,name.TextSize = 1,Theme.FONT,10
			name.TextColor3,name.Text = Theme.INK,entry.name
			name.Position,name.Size,name.TextTruncate = UDim2.fromOffset(2,reelHeight-21),UDim2.new(1,-4,0,18),Enum.TextTruncate.AtEnd
			name.Parent = tile
			local line = Instance.new("Frame")
			line.BorderSizePixel,line.Size,line.Position = 0,UDim2.new(1,-8,0,3),UDim2.new(0,4,1,-3)
			line.BackgroundColor3,line.Parent = Config.RARITIES[entry.tier].colour,tile
		end
		local pointer = label("Pointer",19,16,16)
		pointer.Text = "▼"
		local tween = TweenService:Create(strip,TweenInfo.new(2.5,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),
			{Position=UDim2.new(.5,-((count-1)*stride+40),0,0)})
		tween:Play();tween.Completed:Wait()
		if root.Parent then
			local tier = Config.RARITIES[won.tier]
			title.Text = string.upper(tier.label) .. " · " .. won.name
			title.TextScaled = true
			local outline = root:FindFirstChildOfClass("UIStroke")
			if outline then outline.Color=tier.colour;outline.Thickness=3 end
			status.Text = if payload.mode=="carried" then "GET IT HOME · It can still be taken!"
				elseif payload.mode=="sold" then "DUPLICATE SOLD · +"
					.. Config.formatCoins(payload.coins) .. " coins"
				else "ADDED TO YOUR INVENTORY"
			local scale=Instance.new("UIScale")
			scale.Scale,scale.Parent=.96,root
			TweenService:Create(scale,TweenInfo.new(.3,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
			task.wait(if won.tier=="legendary" then 2.4 else 1.6)
		end
		resize:Disconnect();root:Destroy()
	end
	Remotes.get("RobberyLoot").OnClientEvent:Connect(function(payload)
		table.insert(queue,payload)
		if running then return end
		running=true
		task.spawn(function()
			while #queue>0 and gui.Parent do
				local ok,err=pcall(show,table.remove(queue,1))
				if not ok then warn("[RobberyLoot] " .. tostring(err)) end
			end
			running=false
		end)
	end)
end

return RobberyLoot
