--!strict
-- Compact indoor counters. Local +Z faces the customer; the origin is floor level.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local LowPoly = require(Shared.LowPoly)
local GadgetModel = require(Shared.GadgetModel)
local GuardRig = require(Shared.GuardRig)
local ResidentModel = require(Shared.ResidentModel)

local Stand = {}
Stand.SIZE = Vector3.new(8.4, 8.25, 7.1) -- includes the projecting sign emblem
Stand.NPC_SIZE = Vector3.new(3.8, 6, 3)
Stand.NPC_AT = CFrame.new(0, 0.12, -1.35)
Stand.APPROACH_SIZE = Vector3.new(8.4, 6, 4)
Stand.APPROACH_AT = CFrame.new(0, 3, 5.3)

local cream = Color3.fromRGB(244, 222, 176)
local teal = Color3.fromRGB(40, 132, 138)
local dark = Color3.fromRGB(37, 81, 84)
local wood = Color3.fromRGB(154, 98, 53)
local ink = Color3.fromRGB(65, 42, 33)
local gold = Color3.fromRGB(247, 184, 48)
local coral = Color3.fromRGB(222, 100, 79)

local function part(parent: Instance, name: string, size: Vector3, at: CFrame, color: Color3): Part
	local p = LowPoly.part(parent, name, size, at, color, Enum.Material.SmoothPlastic)
	p.CanTouch = false
	return p
end

local function shield(parent: Instance, at: CFrame, scale: number)
	for _, layer in ipairs({{cream, 1, 0}, {teal, .79, .07}}) do
		local s = scale * (layer[2] :: number)
		local cf = at * CFrame.new(0, 0, layer[3] :: number)
		part(parent, "Shield", Vector3.new(s, s * .68, .12), cf, layer[1] :: Color3)
		LowPoly.pediment(parent, s, .12, 0, s * .48, layer[1] :: Color3,
			cf * CFrame.new(0, -s * .34, 0) * CFrame.Angles(0, 0, math.pi))
	end
end

local function dinosaur(parent: Instance, at: CFrame)
	-- Broad cut-out silhouette; no paw/dog branding on the creature counter.
	part(parent, "DinosaurNeck", Vector3.new(.25, .58, .06), at * CFrame.new(-.19, -.10, 0)
		* CFrame.Angles(0, 0, -.4), cream)
	part(parent, "DinosaurHead", Vector3.new(.60, .32, .06), at * CFrame.new(.04, .16, 0), cream)
	part(parent, "DinosaurJaw", Vector3.new(.41, .09, .06), at * CFrame.new(.14, -.08, 0), cream)
	part(parent, "DinosaurEye", Vector3.new(.055, .055, .02), at * CFrame.new(-.06, .22, .05), dark)
end

local function display(model: Model, at: CFrame, height: number, parent: Instance)
	local _, size = model:GetBoundingBox()
	model:ScaleTo(model:GetScale() * height / size.Y)
	local box, scaled = model:GetBoundingBox()
	local relative = model:GetPivot():ToObjectSpace(box)
	model:PivotTo(at * CFrame.new(0, scaled.Y / 2, 0) * relative:Inverse())
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
		end
	end
	model.Parent = parent
end

--[[
	One spot per counter in `Config.BASE_COUNTERS`, facing across the hall.

	DERIVED FROM THE COUNTER LIST RATHER THAN A PAIR OF LITERALS, so a third
	counter is a Config row and not an edit here AND in `InteriorService` --
	the two ends of that would disagree by one and stand a counter nobody can
	see, or leave a spot with nothing on it. They alternate sides of the
	doorway and step outward in pairs, which keeps the first two exactly where
	they were measured.
]]
function Stand.placements(origin: CFrame, aperture: number?): { CFrame }
	-- Both the generic hall and authored kits use +X down the hall. Keep
	-- the entire doorway and jambs clear as the higher-tier entrances widen.
	local offset = math.max(13, (aperture or 6) / 2 + 6)
	local out = {}
	for i = 1, #Config.BASE_COUNTERS do
		-- 1 -> -offset, 2 -> +offset, 3 -> -(offset + pitch), 4 -> +(...).
		local side = if i % 2 == 1 then -1 else 1
		local step = math.floor((i - 1) / 2) * (Stand.SIZE.Z + 3)
		table.insert(out, origin * CFrame.new(3.8, .12, side * (offset + step))
			* CFrame.Angles(0, math.pi / 2, 0))
	end
	return out
end

-- The counter row for a door key, or nil. `InteriorService` builds from the
-- same list, so this is only ever nil for a caller that invented a key.
function Stand.counter(kind: string): any?
	for _, counter in ipairs(Config.BASE_COUNTERS) do
		if counter.tab == kind then
			return counter
		end
	end
	return nil
end

function Stand.build(kind: string, at: CFrame, parent: Instance): (Model, ProximityPrompt)
	local counter = Stand.counter(kind)
	assert(counter, "unknown indoor shop: " .. tostring(kind))
	-- THE ART IS KEYED TO THE COUNTER AND STAYS A BRANCH, deliberately. The
	-- sign, the door key and the shelf it opens are DATA and come off the row;
	-- a dinosaur shield against a bolt and three gadget trays is geometry
	-- somebody drew for one counter, and there is nothing to derive it from.
	local guardian = kind == "guardians"
	local accent = if guardian then coral else gold
	local model = Instance.new("Model")
	model.Name = if guardian then "GuardianStand" else "GadgetStand"
	model:SetAttribute("ShopCategory", kind)
	model:SetAttribute("Envelope", Stand.SIZE)
	local function add(name: string, size: Vector3, localAt: CFrame, color: Color3): Part
		return part(model, name, size, at * localAt, color)
	end
	local floor = add("Plinth", Vector3.new(7.9, .18, 6.1), CFrame.new(0, .09, 0), dark)
	model.PrimaryPart = floor
	add("CounterBody", Vector3.new(7.2, 2.3, 1.55), CFrame.new(0, 1.35, 1.85), teal).CanCollide = true
	add("CounterTop", Vector3.new(7.8, .3, 1.85), CFrame.new(0, 2.65, 1.85), if guardian then gold else teal)
	add("CounterFoot", Vector3.new(7.45, .22, 1.7), CFrame.new(0, .3, 1.85), cream)
	for _, x in ipairs({-3.55, 3.55}) do
		for _, z in ipairs({-2.6, 2.6}) do
			add("Post", Vector3.new(.42, 6.8, .42), CFrame.new(x, 3.6, z), wood)
			add("PostFoot", Vector3.new(.68, .38, .68), CFrame.new(x, .37, z), cream)
			add("PostCap", Vector3.new(.68, .32, .68), CFrame.new(x, 6.8, z), cream)
		end
	end
	add("RearRail", Vector3.new(7.2, .35, .28), CFrame.new(0, 3.2, -2.7), wood)
	LowPoly.capRoof(model, 8.4, 6.6, 7.05, 1.2, accent, at)
	add("RoofTrim", Vector3.new(8.4, .18, .22), CFrame.new(0, 7.03, 3.2), cream)
	local sign = add("Sign", Vector3.new(7.6, 1.25, .22), CFrame.new(0, 7.03, 3.28), cream)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "ShopSign"
	gui.Face = Enum.NormalId.Back -- local +Z is the front of our model
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 70
	gui.LightInfluence = 0
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(.79, .86)
	label.Position = UDim2.fromScale(.20, .07)
	label.Font = Enum.Font.FredokaOne
	label.Text = counter.sign
	label.TextColor3 = ink
	label.TextScaled = true
	label.Parent = gui
	if guardian then
		shield(model, at * CFrame.new(-2.85, 7.15, 3.48), .95)
		dinosaur(model, at * CFrame.new(-2.85, 7.12, 3.64))
		shield(model, at * CFrame.new(0, 1.6, 2.7), 1.6)
		local plinth = add("CreatureDisplay", Vector3.new(1.55, .16, 1.4), CFrame.new(2.25, 2.89, 1.8), cream)
		local gorilla = GuardRig.build("gorilla")
		-- GuardRig's inert gorilla preview faces -Z; our counter faces +Z.
		if gorilla then display(gorilla, plinth.CFrame * CFrame.new(0, .08, 0)
			* CFrame.Angles(0, math.pi, 0), 1.45, model) end
	else
		local bolt = at * CFrame.new(-2.85, 7.06, 3.46)
		part(model, "BoltUpper", Vector3.new(.22, .59, .09), bolt * CFrame.new(.08, .18, 0) * CFrame.Angles(0, 0, -.38), gold)
		part(model, "BoltMiddle", Vector3.new(.48, .18, .09), bolt, gold)
		part(model, "BoltLower", Vector3.new(.22, .53, .09), bolt * CFrame.new(-.08, -.2, 0) * CFrame.Angles(0, 0, -.38), gold)
		add("Drawer", Vector3.new(4.5, 1.1, .15), CFrame.new(0, 1.55, 2.68), cream)
		add("Latch", Vector3.new(.38, .55, .16), CFrame.new(0, 1.55, 2.84), gold)
		for i, key in ipairs({"plunger", "gum", "zapper"}) do
			local x = (i - 2) * 2.35
			add("DisplayTray", Vector3.new(1.45, .12, 1.2), CFrame.new(x, 2.86, 1.9), cream)
			display(GadgetModel.build(key, false), at * CFrame.new(x, 2.93, 1.9), if key == "gum" then .65 else 1.4, model)
		end
	end

	local npcAt = at * Stand.NPC_AT
	local npc = ResidentModel.build(if guardian then 2 else 1, "", npcAt, npcAt.Position.Y, model)
	if npc then
		npc.Name = "Shopkeeper"
		for _, child in npc:GetDescendants() do
			if child:IsA("BillboardGui") then child:Destroy() end
		end
	end
	local npcMount = Instance.new("Attachment")
	npcMount.Name = "ShopkeeperMount"
	npcMount.CFrame = floor.CFrame:ToObjectSpace(npcAt)
	npcMount:SetAttribute("ReservedSize", Stand.NPC_SIZE)
	npcMount.Parent = floor
	local promptMount = Instance.new("Attachment")
	promptMount.Name = "BrowseMount"
	promptMount.CFrame = floor.CFrame:ToObjectSpace(at * CFrame.new(0, 2.9, 3.1))
	promptMount.Parent = floor
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BaseShopPrompt"
	-- The sign's own word, sentence-cased: the fascia and the prompt over it
	-- may not be able to disagree about which counter this is.
	prompt.ObjectText = counter.sign:sub(1, 1) .. counter.sign:sub(2):lower()
	prompt.ActionText = "Browse"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 6
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	Config.setPromptKind(prompt, "shop")
	prompt.Parent = promptMount
	model.Parent = parent
	return model, prompt
end

return Stand
