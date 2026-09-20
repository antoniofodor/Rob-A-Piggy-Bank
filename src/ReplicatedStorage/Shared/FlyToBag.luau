--!strict
--[[
	FlyToBag

	AN ITEM YOU JUST GOT FLIES INTO THE SATCHEL. The robbery reveal
	(`LootHaul.revealItem`) ends that way and a crate reveal (`SpinWheel`) did
	not -- it simply faded -- so the same kind of moment ("a new thing is
	yours") ended two different ways depending on where the thing came from.
	The flight is what TEACHES where things go: a nine-year-old who watches the
	prize drop into the satchel knows where to look for it, which a fade cannot
	say.

	Same curve, spin, landing bump and sound as `LootHaul`'s own `flyGhost`, so
	the two read as one gesture. (LootHaul keeps its private copy for now; it is
	the natural caller to move onto this.)

	`BagToggle` is found BY NAME, as LootHaul finds it: it is built in
	ClientMain far from any caller and carries a real name for exactly this.
	A missing or hidden satchel is warned once and the ghost simply fades --
	never aimed at a guessed screen corner.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local SoundKit = require(ReplicatedStorage.Shared.SoundKit)

local FlyToBag = {}

local FLY = 0.55
local warned = false

local function tween(inst: Instance, time: number, props: { [string]: any },
	style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	TweenService:Create(inst,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props):Play()
end

-- Visible all the way up, or a satchel behind a closed menu would swallow it.
local function shown(obj: GuiObject): boolean
	local a: Instance? = obj
	while a and a:IsA("GuiObject") do
		if not a.Visible then
			return false
		end
		a = a.Parent
	end
	return true
end

function FlyToBag.target(gui: Instance): GuiObject?
	local found = gui:FindFirstChild("BagToggle", true)
	if found and found:IsA("GuiObject") and shown(found) then
		return found
	end
	if not warned then
		warned = true
		warn("[FlyToBag] no visible BagToggle to fly the item into")
	end
	return nil
end

-- AbsolutePosition is measured BELOW the top-bar inset, and a ScreenGui with
-- `IgnoreGuiInset` (the HUD) lays its offsets out from the very top of the
-- screen -- so an absolute point is an offset only after the inset is added
-- back. Measured on the HUD: an offset of (100, 100) reads back as (100, 42).
-- Getting the sign wrong lands every flight 58 pixels above the satchel.
local function toOffset(gui: Instance, point: Vector2): Vector2
	if gui:IsA("ScreenGui") and gui.IgnoreGuiInset then
		return point + game:GetService("GuiService"):GetGuiInset()
	end
	return point
end

-- Copies `source` (a tile already on screen) into `gui` at the exact pixels it
-- occupies and flies the copy into the satchel. The copy rather than the tile,
-- because the tile belongs to a panel that is closing around it.
function FlyToBag.fly(gui: Instance, source: GuiObject, onLand: (() -> ())?)
	local size = source.AbsoluteSize
	local centre = toOffset(gui, source.AbsolutePosition + size / 2)
	local ghost = source:Clone()
	ghost.Name = "FlyingPrize"
	ghost.AnchorPoint = Vector2.new(0.5, 0.5)
	ghost.Position = UDim2.fromOffset(centre.X, centre.Y)
	ghost.Size = UDim2.fromOffset(size.X, size.Y)
	ghost.Rotation = 0
	-- Above everything a reveal draws (they sit in the 60s), so the prize is
	-- never under the fading panel it is leaving.
	local base = ghost.ZIndex
	for _, d in ipairs(ghost:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.ZIndex = 90 + math.max(0, d.ZIndex - base)
		end
	end
	ghost.ZIndex = 90
	for _, d in ipairs(ghost:GetDescendants()) do
		if d:IsA("UIScale") then
			d:Destroy()
		end
	end
	ghost.Parent = gui

	local target = FlyToBag.target(gui)
	if not target then
		tween(ghost, 0.3, { BackgroundTransparency = 1 })
		task.delay(0.3, function()
			ghost:Destroy()
			if onLand then onLand() end
		end)
		return
	end

	local shrink = Instance.new("UIScale")
	shrink.Parent = ghost
	local to = toOffset(gui, target.AbsolutePosition + target.AbsoluteSize / 2)
	local px = math.max(size.X, size.Y, 1)
	tween(ghost, FLY, { Position = UDim2.fromOffset(to.X, to.Y) },
		Enum.EasingStyle.Quart, Enum.EasingDirection.In)
	tween(shrink, FLY, { Scale = 18 / px }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
	tween(ghost, FLY, { Rotation = 220 })
	task.delay(FLY + 0.05, function()
		ghost:Destroy()
		-- THE LANDING BUMP, on the thing it landed in: without it the ghost
		-- simply vanishes at the corner and reads as decoration rather than as
		-- something arriving somewhere.
		local bump = target:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		bump.Parent = target
		bump.Scale = 1.22
		tween(bump, 0.24, { Scale = 1 }, Enum.EasingStyle.Back)
		SoundKit.ui(Config.SOUNDS.COIN_DROP, { name = "BagLand", volume = 0.4,
			pitch = Config.semitonePitch(-3) })
		if onLand then onLand() end
	end)
end

return FlyToBag
