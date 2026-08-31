--!strict
--[[
	PlotService

	Owns the pool of plots: builds them, hands one to each arriving player,
	and wipes it when they leave.

	Plots are generated in code rather than built by hand in Studio. That
	keeps the whole layout in source control and means changing the grid is
	a one-line edit instead of an afternoon of dragging parts.

	The piggy bank itself lives in PiggyBank.luau; this file only decides
	where the plots go and who owns which one.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PiggyBank = require(script.Parent.PiggyBank)
local GuardDog = require(script.Parent.GuardDog)
local House = require(script.Parent.House)

local PlotService = {}

export type Plot = {
	index: number,
	model: Model,
	base: Part,
	-- Position AND facing. Anything rebuilt after construction (the fence,
	-- the spawn point) has to work from this, not from base.Position, or it
	-- comes back unrotated on the far row.
	cframe: CFrame,
	piggy: PiggyBank.Refs,
	dog: GuardDog.Dog,
	fence: Folder,
	house: Model?,
	signLabel: TextLabel,
	prompt: ProximityPrompt,
	owner: Player?,
}

local plots: { Plot } = {}
local byPlayer: { [Player]: Plot } = {}
local plotsFolder: Folder

-- Registered by HeistService, which owns walkspeed state. PlotService builds
-- the fence and detects the crossing; it doesn't decide what that costs.
local fencePenaltyHandlers: { (Player, any, any) -> () } = {}

local LAWN = Color3.fromRGB(138, 178, 104)
local TRIM = Color3.fromRGB(196, 178, 148)
local POST = Color3.fromRGB(122, 88, 58)

-- ============================================================
-- CONSTRUCTION
-- ============================================================

-- Where a plot sits AND which way it faces.
--
-- Everything on a plot -- sign, gate, snout, spawn point -- is authored with
-- +Z as its front. The far row is yawed 180 degrees so both rows face the
-- road rather than one row showing the street its back fence. That yaw is the
-- only place in the codebase that has to know the layout has two sides.
local function plotCFrame(index: number): CFrame
	local perRow = Config.PLOTS_PER_ROW
	local row = math.floor((index - 1) / perRow) -- 0 = near side, 1 = far side
	local col = (index - 1) % perRow

	local x = (col - (perRow - 1) / 2) * Config.PLOT_SPACING
	local z = (if row == 0 then -0.5 else 0.5) * Config.STREET_SPACING
	local yaw = if row == 0 then 0 else math.pi

	return CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
end

local function buildPlot(index: number): Plot
	local cf = plotCFrame(index)
	local origin = cf.Position

	local model = Instance.new("Model")
	model.Name = "Plot" .. index

	-- Stone trim sits slightly proud of the lawn so each plot reads as a
	-- separate property rather than a patch of the same field.
	local trim = Instance.new("Part")
	trim.Name = "Trim"
	trim.Size = Config.PLOT_SIZE + Vector3.new(4, 0.4, 4)
	trim.Position = origin - Vector3.new(0, 0.4, 0)
	trim.Anchored = true
	trim.Material = Enum.Material.Concrete
	trim.Color = TRIM
	trim.TopSurface = Enum.SurfaceType.Smooth
	trim.Parent = model

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Config.PLOT_SIZE
	base.Position = origin
	base.Anchored = true
	base.Material = Enum.Material.Grass
	base.Color = LAWN
	base.TopSurface = Enum.SurfaceType.Smooth
	base.Parent = model

	local piggy = PiggyBank.build(origin, model)

	-- Sign on a post, at the front edge facing outward.
	local post = Instance.new("Part")
	post.Name = "SignPost"
	post.Size = Vector3.new(0.8, 6, 0.8)
	post.Position = origin + Vector3.new(0, 3, Config.PLOT_SIZE.Z / 2 - 2)
	post.Anchored = true
	post.CanCollide = false
	post.Material = Enum.Material.Wood
	post.Color = POST
	post.Parent = model

	local sign = Instance.new("Part")
	sign.Name = "Sign"
	sign.Size = Vector3.new(11, 3.6, 0.4)
	sign.Position = origin + Vector3.new(0, 7.4, Config.PLOT_SIZE.Z / 2 - 2)
	sign.Anchored = true
	sign.CanCollide = false
	sign.Material = Enum.Material.WoodPlanks
	sign.Color = POST
	sign.Parent = model

	local surface = Instance.new("SurfaceGui")
	-- Roblox's "Front" face is -Z. The sign sits on the plot's +Z edge and
	-- needs to face outward, so that's Back.
	surface.Face = Enum.NormalId.Back
	surface.CanvasSize = Vector2.new(600, 200)
	surface.AlwaysOnTop = false
	surface.LightInfluence = 0
	surface.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 246, 226)
	label.Text = "EMPTY PLOT"
	label.Parent = surface

	local fence = Instance.new("Folder")
	fence.Name = "Fence"
	fence.Parent = model

	model.PrimaryPart = base
	model.Parent = plotsFolder

	-- Yaw the whole plot into place. Everything above is authored front-to-+Z
	-- around `origin`, so a single pivot turns the far row's sign, gate and
	-- snout to face the street instead of the backdrop.
	model:PivotTo(cf)

	-- One dog per plot, built hidden at tier 0. Cheaper than spawning and
	-- destroying a model every time someone buys or rebirths away the upgrade,
	-- and it means the chase can start the instant an alarm fires.
	--
	-- Built AFTER the pivot on purpose: the dog caches its home as a world
	-- Vector3 and drives itself with PivotTo, so rotating it underneath that
	-- cache would leave it walking back to the wrong corner forever.
	local dog = GuardDog.build((cf * CFrame.new(13, 0, 9)).Position, model)

	return {
		index = index,
		model = model,
		base = base,
		cframe = cf,
		piggy = piggy,
		dog = dog,
		fence = fence,
		house = nil,
		signLabel = label,
		prompt = piggy.prompt,
		owner = nil,
	}
end
-- ============================================================
-- FENCES
-- ============================================================
--
-- Collision and decoration are deliberately separate systems.
--
-- The old fence WAS its rails: two thin bars with a 2.95-stud hole between
-- them and open air above the top one, so a thief could slip straight
-- through. Now every side gets one invisible slab running ground-to-top --
-- the only colliding geometry on the whole fence -- and the visible fence is
-- pure decoration with CanCollide off. Styles can then look like anything
-- without ever changing the jump maths, which depends only on `tier.top`.

-- Fence sits on the world ground outside the plot slab, not on the slab.
local FENCE_BASE_Y = -Config.PLOT_SIZE.Y / 2

local function alongVec(alongX: boolean, t: number): Vector3
	return if alongX then Vector3.new(t, 0, 0) else Vector3.new(0, 0, t)
end

local function spanSize(alongX: boolean, length: number, height: number, depth: number): Vector3
	return if alongX then Vector3.new(length, height, depth) else Vector3.new(depth, height, length)
end

-- Takes a CFrame, not a position: the far row of plots is yawed 180 degrees,
-- and decoration has to arrive already rotated into the plot's own frame.
local function decorPart(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Evenly spaced positions along a side that always include both ends, so
-- corners and gate mouths get a post instead of trailing off into nothing.
local function stepsAlong(length: number, spacing: number): { number }
	local count = math.max(1, math.round(length / spacing))
	local out = {}
	for i = 0, count do
		table.insert(out, -length / 2 + (length / count) * i)
	end
	return out
end

local function decorRickety(parent: Instance, originCF: CFrame, centre: Vector3, length: number, alongX: boolean, tier: any)
	local WOOD = Color3.fromRGB(124, 100, 76)
	local WOOD_PALE = Color3.fromRGB(152, 128, 98)

	-- Rails in broken segments. A rickety fence is defined by what's missing,
	-- so roughly one plank in four is simply never built.
	for row, height in ipairs({ 1.2, 2.5 }) do
		local segments = math.max(3, math.round(length / 5))
		local segLength = length / segments
		for i = 0, segments - 1 do
			if (i + row) % 4 ~= 2 then
				local t = -length / 2 + segLength * (i + 0.5)
				local rail = decorPart(parent, "Rail",
					spanSize(alongX, segLength * 0.9, 0.4, 0.35),
					originCF * CFrame.new(centre + alongVec(alongX, t) + Vector3.new(0, FENCE_BASE_Y + height, 0)))
				rail.Material = Enum.Material.WoodPlanks
				rail.Color = if i % 2 == 0 then WOOD else WOOD_PALE
			end
		end
	end

	for i, t in ipairs(stepsAlong(length, 5)) do
		local post = decorPart(parent, "Post", Vector3.new(0.55, tier.decorTop, 0.55),
			originCF * CFrame.new(centre + alongVec(alongX, t) + Vector3.new(0, FENCE_BASE_Y + tier.decorTop / 2, 0)))
		post.Material = Enum.Material.WoodPlanks
		post.Color = WOOD
		-- A few degrees of lean, alternating, so the line never looks surveyed.
		local lean = math.rad((i % 3 - 1) * 3.5)
		post.CFrame = post.CFrame
			* (if alongX then CFrame.Angles(lean, 0, 0) else CFrame.Angles(0, 0, lean))
	end
end

local function decorPicket(parent: Instance, originCF: CFrame, centre: Vector3, length: number, alongX: boolean, tier: any)
	local WHITE = Color3.fromRGB(246, 246, 240)

	for _, height in ipairs({ 1.3, 3.4 }) do
		local rail = decorPart(parent, "Rail", spanSize(alongX, length, 0.35, 0.28),
			originCF * CFrame.new(centre + Vector3.new(0, FENCE_BASE_Y + height, 0)))
		rail.Material = Enum.Material.SmoothPlastic
		rail.Color = WHITE
	end

	for _, t in ipairs(stepsAlong(length, 2.6)) do
		local base = centre + alongVec(alongX, t)
		local picket = decorPart(parent, "Picket", spanSize(alongX, 0.5, tier.top, 0.22),
			originCF * CFrame.new(base + Vector3.new(0, FENCE_BASE_Y + tier.top / 2, 0)))
		picket.Material = Enum.Material.SmoothPlastic
		picket.Color = WHITE

		-- Rotated cube reads as a point from the front, which is the entire
		-- silhouette of a picket fence, and costs one part instead of two wedges.
		local tip = decorPart(parent, "Tip", Vector3.new(0.42, 0.42, 0.42),
			originCF * CFrame.new(base + Vector3.new(0, FENCE_BASE_Y + tier.top + 0.2, 0)))
		tip.Material = Enum.Material.SmoothPlastic
		tip.Color = WHITE
		tip.CFrame = tip.CFrame
			* (if alongX then CFrame.Angles(0, 0, math.rad(45)) else CFrame.Angles(math.rad(45), 0, 0))
	end
end

local function decorBarbed(parent: Instance, originCF: CFrame, centre: Vector3, length: number, alongX: boolean, tier: any)
	local STEEL = Color3.fromRGB(104, 110, 120)

	for _, height in ipairs({ 1.4, 3.0, 4.6 }) do
		local wire = decorPart(parent, "Wire", spanSize(alongX, length, 0.16, 0.16),
			originCF * CFrame.new(centre + Vector3.new(0, FENCE_BASE_Y + height, 0)))
		wire.Material = Enum.Material.DiamondPlate
		wire.Color = STEEL
	end

	-- The top strand sits above the barrier, so the thing you have to clear is
	-- visibly the nasty bit rather than an invisible line.
	local top = decorPart(parent, "Wire", spanSize(alongX, length, 0.2, 0.2),
		originCF * CFrame.new(centre + Vector3.new(0, FENCE_BASE_Y + tier.decorTop, 0)))
	top.Material = Enum.Material.DiamondPlate
	top.Color = Color3.fromRGB(152, 158, 168)

	for _, t in ipairs(stepsAlong(length, 6)) do
		local post = decorPart(parent, "Post", Vector3.new(0.45, tier.decorTop, 0.45),
			originCF * CFrame.new(centre + alongVec(alongX, t) + Vector3.new(0, FENCE_BASE_Y + tier.decorTop / 2, 0)))
		post.Material = Enum.Material.Metal
		post.Color = STEEL
	end
end

local function decorElectric(parent: Instance, originCF: CFrame, centre: Vector3, length: number, alongX: boolean, tier: any)
	decorBarbed(parent, originCF, centre, length, alongX, tier)

	local LIVE = Color3.fromRGB(255, 226, 92)
	for _, height in ipairs({ 2.2, 4.6, tier.decorTop }) do
		local live = decorPart(parent, "Live", spanSize(alongX, length, 0.2, 0.2),
			originCF * CFrame.new(centre + Vector3.new(0, FENCE_BASE_Y + height, 0)))
		live.Material = Enum.Material.Neon
		live.Color = LIVE
	end

	-- One emitter per side rather than per strand: the arcing is atmosphere,
	-- and four emitters a plot is already plenty of particles.
	local arc = Instance.new("ParticleEmitter")
	arc.Name = "Arc"
	arc.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	arc.Color = ColorSequence.new(Color3.fromRGB(255, 244, 190), LIVE)
	arc.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	arc.Lifetime = NumberRange.new(0.2, 0.45)
	arc.Rate = 6
	arc.Speed = NumberRange.new(0.5, 2)
	arc.SpreadAngle = Vector2.new(180, 180)
	arc.LightEmission = 1
	arc.Parent = parent:FindFirstChild("Live") or parent
end

local function decorMoat(parent: Instance, originCF: CFrame, centre: Vector3, length: number, alongX: boolean, tier: any)
	-- The wall itself is unchanged from Electric; the water is the upgrade,
	-- and it is built once for the whole ring rather than per side.
	decorElectric(parent, originCF, centre, length, alongX, tier)
end

local FENCE_STYLES: { [string]: (Instance, CFrame, Vector3, number, boolean, any) -> () } = {
	rickety = decorRickety,
	picket = decorPicket,
	barbed = decorBarbed,
	electric = decorElectric,
	moat = decorMoat,
}

function PlotService.buildFence(plot: Plot, level: number)
	plot.fence:ClearAllChildren()
	if level <= 0 then
		return
	end

	local tier = Config.FENCE_TIERS[math.clamp(level, 1, #Config.FENCE_TIERS)]
	local decorate = FENCE_STYLES[tier.style] or decorRickety
	local originCF = plot.cframe
	local half = Config.PLOT_SIZE.X / 2 + 1.6
	local gate = tier.gate

	local climbPenalty = {
		label = tier.label,
		slow = tier.slow,
		duration = tier.duration,
		stun = tier.stun or 0,
	}

	local function firePenalty(hit: BasePart, penalty: any)
		local character = hit.Parent
		if not character or not character:FindFirstChildOfClass("Humanoid") then
			return
		end
		local crosser = Players:GetPlayerFromCharacter(character)
		-- Owners cross their own defences freely; they paid for them.
		if not crosser or crosser == plot.owner then
			return
		end
		for _, callback in ipairs(fencePenaltyHandlers) do
			task.spawn(callback, crosser, plot, penalty)
		end
	end

	local function side(centre: Vector3, length: number, alongX: boolean)
		-- The one and only colliding part of the fence. Solid from the ground
		-- to `top` so there is nothing to slip between.
		local barrier = Instance.new("Part")
		barrier.Name = "Barrier"
		barrier.Size = spanSize(alongX, length, tier.top, 0.6)
		barrier.CFrame = originCF * CFrame.new(centre + Vector3.new(0, FENCE_BASE_Y + tier.top / 2, 0))
		barrier.Anchored = true
		barrier.CanCollide = true
		barrier.CanQuery = false
		barrier.Transparency = 1
		barrier.Parent = plot.fence

		decorate(plot.fence, originCF, centre, length, alongX, tier)

		-- Snag volume, sitting above the barrier so it only catches players
		-- coming over the top, never anyone walking in through the gate.
		local zone = Instance.new("Part")
		zone.Name = "ClimbZone"
		zone.Size = spanSize(alongX, length, 5, 3)
		zone.CFrame = originCF * CFrame.new(centre + Vector3.new(0, FENCE_BASE_Y + tier.top + 2.5, 0))
		zone.Anchored = true
		zone.CanCollide = false
		zone.CanQuery = false
		zone.Transparency = 1
		zone.Parent = plot.fence

		zone.Touched:Connect(function(hit)
			firePenalty(hit, climbPenalty)
		end)
	end

	-- Three solid sides, then the front split around the gate.
	side(Vector3.new(0, 0, -half), half * 2, true)
	side(Vector3.new(-half, 0, 0), half * 2, false)
	side(Vector3.new(half, 0, 0), half * 2, false)

	local wing = half - gate / 2
	if wing > 0 then
		local offset = gate / 2 + wing / 2
		side(Vector3.new(-offset, 0, half), wing, true)
		side(Vector3.new(offset, 0, half), wing, true)
	end

	-- Moat ------------------------------------------------------------
	--
	-- Sits in the one-stud step between the world ground and the plot slab, so
	-- it reads as dug rather than poured on top. The gate mouth is left dry:
	-- there is always a clean way in for anyone willing to take the long route.
	if tier.moat then
		local m = tier.moat
		local moatPenalty = { label = "Moat", slow = m.slow, duration = m.duration, stun = 0 }
		local mid = half + 0.5 + m.width / 2
		local reach = half + 0.5 + m.width

		local function water(centre: Vector3, length: number, alongX: boolean)
			local w = Instance.new("Part")
			w.Name = "Moat"
			w.Size = spanSize(alongX, length, 0.5, m.width)
			-- Water surface lands 0.05 PROUD of the grass, not level with it.
			-- Sitting exactly at ground height put two coplanar faces at the
			-- same depth and the lawn flickered through the moat.
			w.CFrame = originCF * CFrame.new(centre + Vector3.new(0, FENCE_BASE_Y - 0.2, 0))
			w.Anchored = true
			w.CanCollide = false
			w.CanQuery = false
			w.CastShadow = false
			-- SmoothPlastic, not Glass. Glass plus reflectance washed out to
			-- near-white against the grass and stopped reading as water.
			w.Material = Enum.Material.SmoothPlastic
			w.Color = Color3.fromRGB(44, 116, 178)
			w.Transparency = 0.3
			w.Reflectance = 0.12
			w.Parent = plot.fence

			w.Touched:Connect(function(hit)
				firePenalty(hit, moatPenalty)
			end)
		end

		water(Vector3.new(0, 0, -mid), reach * 2, true)
		water(Vector3.new(-mid, 0, 0), reach * 2, false)
		water(Vector3.new(mid, 0, 0), reach * 2, false)

		local moatWing = reach - gate / 2
		if moatWing > 0 then
			local offset = gate / 2 + moatWing / 2
			water(Vector3.new(-offset, 0, mid), moatWing, true)
			water(Vector3.new(offset, 0, mid), moatWing, true)
		end
	end
end

function PlotService.onFencePenalty(callback: (Player, any, any) -> ())
	table.insert(fencePenaltyHandlers, callback)
end

-- Rebuilt from scratch on every change, unlike the dog. House tiers differ in
-- footprint, storey count and which details exist at all, so there is no
-- shared skeleton to resize -- and this runs once per purchase, not per frame.
--
-- Sits well behind the plot: clear of the fence at 25.6 and a top-tier moat at
-- 31.1, facing the street so the front is what the road sees.
function PlotService.setHouseLevel(plot: Plot, level: number)
	if plot.house then
		plot.house:Destroy()
		plot.house = nil
	end
	local groundY = -Config.PLOT_SIZE.Y / 2
	plot.house = House.build(level, plot.cframe * CFrame.new(0, groundY, -70), plot.model)
end

function PlotService.setDogLevel(plot: Plot, level: number)
	GuardDog.applyTier(plot.dog, level)
end

-- Publishes the owner's lock level as an attribute rather than only baking it
-- into HoldDuration.
--
-- The client re-times its own prompt for its lockpicks, so if it had to infer
-- the lock level from HoldDuration it would be reading a number it also
-- writes -- and any server change after the first read would get clobbered by
-- the client's stale copy. Replicating the level itself means both sides
-- derive the duration from the same input and neither can drift.
function PlotService.setLockLevel(plot: Plot, level: number)
	plot.model:SetAttribute("LockLevel", level)
	plot.piggy.stealPrompt.HoldDuration = Config.getStealHold(level, 0)
end

-- ============================================================
-- VISUALS
-- ============================================================

-- Returns how many coins newly appeared, so callers can decide whether that
-- deserves a sound.
function PlotService.updatePile(plot: Plot, vault: number, capacity: number): number
	return PiggyBank.setFill(plot.piggy, vault, capacity)
end

function PlotService.playCoinDrop(plot: Plot)
	PiggyBank.playCoinDrop(plot.piggy)
end

function PlotService.playMilestone(plot: Plot, index: number, total: number)
	PiggyBank.playMilestone(plot.piggy, index, total)
end

function PlotService.playBank(plot: Plot)
	PiggyBank.playBank(plot.piggy)
end

function PlotService.playAlarm(plot: Plot)
	PiggyBank.playAlarm(plot.piggy)
end

-- The sign advertises the skin as well as the rebirth count -- a cosmetic
-- nobody can identify from a distance isn't worth grinding for.
function PlotService.updateSign(plot: Plot, ownerName: string?, rebirths: number, skinName: string?)
	if not ownerName then
		plot.signLabel.Text = "EMPTY PLOT"
		return
	end
	if rebirths > 0 then
		plot.signLabel.Text = ("%s\n%s  -  %d*"):format(ownerName, skinName or "", rebirths)
	elseif skinName and skinName ~= Config.getSkin(Config.DEFAULT_SKIN).name then
		plot.signLabel.Text = ("%s\n%s"):format(ownerName, skinName)
	else
		plot.signLabel.Text = ownerName
	end
end

function PlotService.applySkin(plot: Plot, skinKey: string)
	PiggyBank.applySkin(plot.piggy, skinKey)
end

function PlotService.applyEffect(plot: Plot, effectKey: string)
	PiggyBank.applyEffect(plot.piggy, effectKey)
end

-- ============================================================
-- ASSIGNMENT
-- ============================================================

function PlotService.assign(player: Player): Plot?
	if byPlayer[player] then
		return byPlayer[player]
	end

	for _, plot in ipairs(plots) do
		if plot.owner == nil then
			plot.owner = player
			byPlayer[player] = plot
			plot.model:SetAttribute("OwnerUserId", player.UserId)
			PlotService.updateSign(plot, player.DisplayName, 0)
			return plot
		end
	end

	warn(("[PlotService] No free plot for %s"):format(player.Name))
	return nil
end

function PlotService.release(player: Player)
	local plot = byPlayer[player]
	if not plot then
		return
	end

	plot.owner = nil
	byPlayer[player] = nil
	plot.model:SetAttribute("OwnerUserId", nil)
	PlotService.updateSign(plot, nil, 0)
	PlotService.applySkin(plot, Config.DEFAULT_SKIN)
	PlotService.applyEffect(plot, Config.DEFAULT_EFFECT)
	PlotService.updatePile(plot, 0, Config.BASE_CAPACITY)
	-- Wipe the previous owner's defences so the next arrival gets a bare plot.
	PlotService.buildFence(plot, 0)
	PlotService.setDogLevel(plot, 0)
	PlotService.setLockLevel(plot, 0)
end

function PlotService.getPlot(player: Player): Plot?
	return byPlayer[player]
end

function PlotService.getAll(): { Plot }
	return plots
end

function PlotService.getSpawnCFrame(plot: Plot): CFrame
	return PiggyBank.getViewCFrame(plot.cframe)
end

function PlotService.getOwnerOf(model: Model): Player?
	for _, plot in ipairs(plots) do
		if plot.model == model then
			return plot.owner
		end
	end
	return nil
end

function PlotService.start()
	local existing = workspace:FindFirstChild("Plots")
	if existing then
		existing:Destroy()
	end

	plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = workspace

	for index = 1, Config.PLOT_COUNT do
		table.insert(plots, buildPlot(index))
	end

	Players.PlayerRemoving:Connect(function(player)
		PlotService.release(player)
	end)
end

return PlotService
