--!strict
-- One objective slot: onboarding, a stolen skin, or its seasonal buy-back.
-- Recovery snapshots are private server state; all purchases stay in Crates.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local HUDLayout = require(ReplicatedStorage.Shared.HUDLayout)
local FirstJob = {}
local started = false

-- Keep the soonest recoverable skin ahead of paid replacements. All other
-- claims remain in the snapshot, so resolving one reveals the next one.
function FirstJob.selectObjective(state: any?, now: number): (any?, string?, number)
	local best, mode, count, priority, deadline = nil, nil, 0, math.huge, math.huge
	for _, row in ipairs(if state then state.claims or {} else {}) do
		local nextMode = row.stage
		local cost = if state.buybacksExpireAt > now then row.cost else nil
		if nextMode == "recover" and (row.expiresAt or 0) <= now then nextMode = "buyback" end
		if nextMode == "buyback" and not cost then continue end
		local rank = ({ home = 1, chase = 2, recover = 3, buyback = 4 })[nextMode]
		if not rank then continue end
		count += 1
		local ends = if nextMode == "recover" then row.expiresAt else math.huge
		if rank < priority or (rank == priority and (ends < deadline
			or (ends == deadline and row.key < best.key))) then
			best, mode, priority, deadline = row, nextMode, rank, ends
		end
	end
	return best, mode, count
end

local function build(parent: ScreenGui): any
	local card = Instance.new("TextButton")
	card.Name = "FirstJob"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.BackgroundColor3 = Theme.PAPER
	card.BorderSizePixel = 0
	card.Text = ""
	card.AutoButtonColor = false
	card.Visible = false
	card.Parent = parent
	Theme.corner(card, 12)
	Theme.outline(card)
	local coin = Theme.coin(card, 28)
	local acorn = Theme.acorn(card, 28)
	local thumbnail = Instance.new("Frame")
	thumbnail.Name, thumbnail.BackgroundTransparency = "StolenSkin", 1
	thumbnail.Size, thumbnail.Position = UDim2.fromOffset(36, 36), UDim2.fromOffset(5, 4)
	thumbnail.Parent = card
	for _, glyph in ipairs({ coin, acorn }) do
		glyph.AnchorPoint = Vector2.new(0, 0.5)
		glyph.Position = UDim2.new(0, 10, 0.5, 0)
	end
	local function label(name: string, size: number): TextLabel
		local text = Instance.new("TextLabel")
		text.Name = name
		text.BackgroundTransparency = 1
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.Text = ""
		text.Parent = card
		Theme.title(text, size, Theme.INK)
		return text
	end
	local line = label("Line", 18)
	line.Position = UDim2.fromOffset(46, 3)
	line.TextScaled = true
	line.TextTruncate = Enum.TextTruncate.AtEnd
	local limit = Instance.new("UITextSizeConstraint")
	limit.MinTextSize = 10
	limit.MaxTextSize = 18
	limit.Parent = line
	local detail = label("Detail", 12)
	detail.Position = UDim2.fromOffset(46, 25)
	detail.Size = UDim2.new(1, -56, 0, 16)
	detail.TextTruncate = Enum.TextTruncate.AtEnd
	Theme.body(detail, 12, Theme.MUTED)
	local amount = label("Amount", 14)
	amount.Position = UDim2.new(1, -101, 0, 3)
	amount.Size = UDim2.fromOffset(91, 21)
	amount.TextXAlignment = Enum.TextXAlignment.Right
	local recoveryMark = label("RecoveryMark", 12)
	recoveryMark.Text, recoveryMark.BackgroundTransparency = "↶", 0
	recoveryMark.BackgroundColor3, recoveryMark.TextColor3 = Theme.STOP_INK, Theme.PAPER
	recoveryMark.Size, recoveryMark.Position = UDim2.fromOffset(18, 18), UDim2.new(0, -5, 0, -5)
	recoveryMark.TextXAlignment = Enum.TextXAlignment.Center
	Theme.corner(recoveryMark, 9)
	local stack = label("MoreClaims", 11)
	stack.Size, stack.Position = UDim2.fromOffset(26, 18), UDim2.new(1, -25, 0, -5)
	stack.TextXAlignment = Enum.TextXAlignment.Right
	local compactTask = false
	local skinTask = false
	local function fit(compact: boolean?, skin: boolean?)
		if compact ~= nil then compactTask = compact end
		if skin ~= nil then skinTask = skin end
		local view = parent.AbsoluteSize
		local m = HUDLayout.metrics(view)
		-- y 88 rather than 50: the standing event countdown sits at the top of
		-- this column and its icon reaches 82. Free because this card and the
		-- rebirth button below it are mutually exclusive in practice -- a
		-- player in their first session cannot afford a rebirth.
		local width, x, y = math.min(470, view.X - 2 * m.bankWidth * m.bankScale - 44), view.X / 2, 88
		if m.compact and not m.portrait then
			-- Between the left boost/menu and the bank on landscape phones.
			local left, right = 172, view.X - m.bankWidth * m.bankScale - 22
			width = math.max(180, math.min(470, right - left))
			x, y = right - width / 2, 62
		elseif m.portrait then
			-- Below the compact bank/rebirth row; keep the menu lane clear.
			width, x, y = math.min(470, view.X - 92), (view.X + 68) / 2, 200
		end
		if compactTask then x = x - width / 2 + 32; width = 64 end
		card.Size = UDim2.fromOffset(width, if skinTask then 68 else 44)
		card.Position = UDim2.fromOffset(x, y)
		thumbnail.Size = UDim2.fromOffset(if compactTask then 54 else 36, if compactTask then 46 else 36)
		line.Visible, detail.Visible = not compactTask, not compactTask
		amount.Position = if compactTask then UDim2.fromOffset(3, 47) else UDim2.new(1, -101, 0, 3)
		amount.Size = if compactTask then UDim2.fromOffset(58, 18) else UDim2.fromOffset(91, 21)
		amount.TextXAlignment = if compactTask then Enum.TextXAlignment.Center else Enum.TextXAlignment.Right
		if skinTask and not compactTask then
			amount.Position, amount.Size = UDim2.fromOffset(46, 45), UDim2.new(1, -56, 0, 18)
			amount.TextXAlignment = Enum.TextXAlignment.Left
		end
	end
	parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	return { card = card, line = line, detail = detail, amount = amount, coin = coin, acorn = acorn,
		thumbnail = thumbnail, recoveryMark = recoveryMark, stack = stack, fit = fit }
end

-- The nearest pig worth walking to.
--
-- NEAREST RATHER THAN RICHEST, deliberately. The job of this marker is to
-- teach that the houses on this street have money in them, and the shortest
-- possible trip is the one most likely to be completed by somebody who has
-- been playing for nine seconds. Richest is the decision they get to make
-- once the badges above every pig have taught them there is one to make.
local function pickTarget(me: Player): (Model?, BasePart?)
	local character = me.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local plots = workspace:FindFirstChild("Plots")
	if not root or not plots then
		return nil, nil
	end

	local bestModel: Model?, bestBody: BasePart?, bestDistance = nil, nil, math.huge
	for _, model in ipairs(plots:GetChildren()) do
		local ownerId = model:GetAttribute("OwnerUserId")
		local residentId = model:GetAttribute(Config.PLOT_RESIDENT_ID_ATTRIBUTE)
		local vault = model:GetAttribute(Config.PLOT_VAULT_ATTRIBUTE) or 0
		-- Somebody to rob, something in the pig, and not your own house.
		if (ownerId or residentId) and ownerId ~= me.UserId and vault > 0 then
			local piggy = model:FindFirstChild("PiggyBank")
			local body = piggy and piggy:FindFirstChild("Body")
			if body and body:IsA("BasePart") then
				local distance = (body.Position - root.Position).Magnitude
				if distance < bestDistance then
					bestModel, bestBody, bestDistance = model :: Model, body, distance
				end
			end
		end
	end
	return bestModel, bestBody
end

-- Chase the actual carrier; after delivery point to that robber's pig.
local function recoveryTarget(me: Player, row: any, mode: string): Instance?
	if mode == "chase" then
		local robber = Players:GetPlayerByUserId(row.robberId)
		return robber and robber.Character
	end
	local userId = if mode == "home" then me.UserId else row.robberId
	local plots = workspace:FindFirstChild("Plots")
	if not plots then return nil end
	for _, plot in ipairs(plots:GetChildren()) do
		if plot:GetAttribute("OwnerUserId") == userId then
			local pig = plot:FindFirstChild("PiggyBank")
			return pig and pig:FindFirstChild("Body")
		end
	end
	return nil
end

function FirstJob.start(me: Player, parent: ScreenGui, injected: any?)
	if started then return end
	started = true
	local deps = injected or {}
	local ui = build(parent)
	local snapshot: any = nil
	local expanded = false
	local iconKey: string? = nil
	local icon: GuiObject? = nil
	local mark = Instance.new("Highlight")
	mark.Name = "FirstJobTarget"
	mark.FillColor = Theme.GOLD
	mark.FillTransparency = 0.55
	mark.OutlineColor = Theme.GOLD
	mark.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	mark.Enabled = false
	mark.Parent = workspace
	local function render()
		local row, mode, count = FirstJob.selectObjective(snapshot, workspace:GetServerTimeNow())
		local target: Instance? = nil
		ui.card.Visible = false
		ui.card.Active = row ~= nil
		ui.card.AutoButtonColor = row ~= nil
		local showSkin = row ~= nil and mode ~= "buyback"
		ui.coin.Visible = row == nil
		ui.acorn.Visible = mode == "buyback"
		ui.thumbnail.Visible, ui.recoveryMark.Visible = showSkin, showSkin
		ui.stack.Text = if count > 1 then "+" .. (count - 1) else ""
		local nextKey = if showSkin then row.key else nil
		if nextKey ~= iconKey then
			if icon then icon:Destroy(); icon = nil end
			iconKey, expanded = nextKey, false
			if nextKey and deps.skinIcon then icon = deps.skinIcon(ui.thumbnail, nextKey) end
		end
		ui.stack.Visible = showSkin and count > 1 and not expanded
		ui.amount.Text = ""
		ui.line.Size = UDim2.new(1, -56, 0, 21)
		if row then
			ui.card.Visible = true
			local extra = if count > 1 then ("+%d more · "):format(count - 1) else ""
			ui.detail.Text = extra .. row.name
			if mode == "buyback" then
				ui.line.Text = "BUY IT BACK"
				ui.amount.Text = ("%d ACORNS"):format(row.cost)
				ui.detail.Text ..= " · Tap for Crates"
			elseif mode == "home" then
				ui.line.Text = "GET IT HOME"
				target = recoveryTarget(me, row, mode)
			elseif mode == "chase" then
				ui.line.Text = "RECOVER SKIN"
				if not expanded then ui.amount.Text = "CHASE" end
				ui.detail.Text = extra .. (row.robberName or "Robber") .. " · Nab them now · " .. row.name
				target = recoveryTarget(me, row, mode)
			else
				ui.line.Text = "RECOVER SKIN"
				local seconds = math.max(0, math.ceil(row.expiresAt - workspace:GetServerTimeNow()))
				ui.amount.Text = ("%d:%02d"):format(seconds // 60, seconds % 60)
				ui.detail.Text = extra .. (row.robberName or "Robber") .. " · " .. row.name
				target = recoveryTarget(me, row, mode)
			end
			if mode == "buyback" then ui.line.Size = UDim2.new(1, -149, 0, 21) end
			if mode == "home" and not expanded then ui.amount.Text = "HOME" end
		elseif me:GetAttribute(Config.PLAYER_FIRST_JOB_ATTRIBUTE) == true then
			local model, body = pickTarget(me)
			ui.card.Visible = model ~= nil
			ui.line.Text = "GO AND ROB A PIGGY BANK"
			ui.detail.Text = "Start with the highlighted neighbour."
			target = body
		end
		if deps.canShow and not deps.canShow() then ui.card.Visible = false end
		ui.fit(showSkin and not expanded, showSkin)
		mark.Adornee = target
		mark.Enabled = ui.card.Visible and target ~= nil
	end
	ui.card.Activated:Connect(function()
		-- Re-evaluate now: an expiry or ownership push may have changed the
		-- objective since the last rendered frame. Opening Crates spends nothing.
		local row, mode = FirstJob.selectObjective(snapshot, workspace:GetServerTimeNow())
		if not ui.card.Visible or not row then return end
		if mode == "buyback" and deps.openCrates then deps.openCrates(row.key)
		else expanded = not expanded; render() end
	end)
	local remote = Remotes.get("RecoveryObjective")
	remote.OnClientEvent:Connect(function(state) snapshot = state;render() end)
	me:GetAttributeChangedSignal(Config.PLAYER_FIRST_JOB_ATTRIBUTE):Connect(render)
	local elapsed, awaiting = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if not snapshot then
			awaiting += dt
			if awaiting >= 1 then awaiting = 0;remote:FireServer() end
		end
		if elapsed < 0.25 then return end
		elapsed = 0
		render()
	end)
	-- False retires onboarding alone. Recovery must still work for veterans.
	render()
	remote:FireServer()
end

return FirstJob
