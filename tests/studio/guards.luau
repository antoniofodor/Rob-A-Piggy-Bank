-- Run as a temporary server Script in a fresh Studio Play session.
-- Isolated fixtures; no player data, currency, or persistence writes.
local Storage = game:GetService("ServerStorage")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Catalog = require(Shared.GuardCatalog)
local Guard = require(game.ServerScriptService.Services.GuardDog)
local Visual = require(game.ServerScriptService.Services.GuardVisual)
local Animation = require(Shared.GuardAnimation)
local folder = Instance.new("Folder")
folder.Name, folder.Parent = "GuardIntegrationTests", workspace
local function check(ok, msg) assert(ok, "GUARDS: " .. msg) end
local dogs = {}
local counts = {}
for i, key in {"terrier","shepherd","mastiff","direwolf","gorilla","raptor","triceratops","cerberus"} do
	local spec = Catalog[key]
	check(Storage.GuardTemplates:FindFirstChild(key), "missing template " .. key)
	local dog = Guard.build(CFrame.new((i-1)*9, 12, -190), folder)
	dog.ownerHome = true
	dog.coat = if key == "gorilla" or key == "raptor" or key == "triceratops" then key else ""
	Guard.applyTier(dog, spec.tier)
	local m = dog.model.Visual
	check(m:GetAttribute("GuardKey") == key, "tier/skin selection " .. key)
	local meshes, joints = 0, 0
	for _, p in m.Meshes:GetChildren() do
		meshes += 1
		check(p:IsA("MeshPart") and p.MeshId ~= "", "real imported mesh")
		check(not p.Anchored and not p.CanCollide and not p.CanTouch, "mesh physics")
		local role = spec.parts[p.Name]
		local weld = p:FindFirstChildWhichIsA("WeldConstraint")
		check(weld and weld.Part0.Name == role.bone, key .. " joint for " .. p.Name)
		check(p.Color ~= Color3.fromRGB(163,162,165), "importer gray remains")
	end
	for _, d in m:GetDescendants() do
		if d:IsA("Motor6D") then joints += 1; check(d.Part0 and d.Part1, "joint endpoints") end
	end
	local expected = 0; for _ in spec.bones do expected += 1 end
	check(joints == expected - 1, "bone count " .. key)
	check(not dog.model:FindFirstChild("Torso"), "retired primitive torso")
	local head = m.Meshes:FindFirstChild("Head")
	check(m.PrimaryPart.CFrame:PointToObjectSpace(head.Position).Z > 0, "forward +Z " .. key)
	local frame, size = m.Meshes:FindFirstChild("Body").CFrame, m.Meshes.Body.Size
	check(math.abs(m.PrimaryPart.Position.Y - 12) < 0.01, "grounded " .. key)
	counts[key] = {meshes = meshes, joints = joints, height = spec.height}
	dogs[key] = dog
end
check(#Config.DOG_TIERS == 5 and Config.UPGRADES.dog.max == 5, "progression cap")
local d = dogs.terrier
Guard.setName(d, "Fixture")
Guard.setCoat(d, "husky")
check(d.model.Visual.Meshes.Body.Color == Config.DOG_COATS.husky.fur, "coat body")
check(d.model.Visual.Meshes.Eye_L.Color == Color3.fromRGB(18,18,20), "coat preserves eyes")
check(d.nameLabel.Text == "Fixture", "custom name")
check(Guard.setGuardDuty(d, 60), "guard duty")
check(d.model.Visual.DutyVest.Transparency == 0, "duty tell")
Guard.applyTier(d, 2)
check(d.model.Visual:GetAttribute("GuardKey") == "shepherd", "upgrade replacement")
check(d.model.Visual.DutyVest.Transparency == 0, "duty survives upgrade")
Guard.applyTier(d, 0)
check(not d.model:FindFirstChild("Visual") and not d.plate.Enabled, "level zero removes visual")
Guard.applyTier(d, 1)
check(d.model.Visual.Meshes.Body.Color == Config.DOG_COATS.husky.fur, "coat survives reset")
check(Visual.key(3, "gorilla") == "mastiff", "no higher-tier skin at lower tier")
check(Visual.key(5, "gorilla") == "cerberus", "no lower-tier skin at higher tier")
local jaw1 = Animation.pose("Jaw", "Chase", 1, 4.7)
local jaw2 = Animation.pose("Jaw_Left", "Chase", 1, 4.7)
check(jaw1 ~= CFrame.identity and jaw1 ~= jaw2, "independent moving jaws")
-- A real catch invokes the callback once and shows Attack before returning home.
local target = Instance.new("Part")
target.Anchored, target.Transparency, target.CanCollide = true, 1, false
target.Position, target.Parent = dogs.cerberus.body.Position, folder
local caught = 0
local attackAtCatch = false
Guard.chase(dogs.cerberus, function() return target end, function()
	caught += 1
	attackAtCatch = dogs.cerberus.model:GetAttribute("GuardState") == "Attack"
end)
-- Startup world construction can stall a frame; wait for the event rather
-- than assuming one Heartbeat has occurred after a wall-clock delay.
local deadline = os.clock() + 45
repeat game:GetService("RunService").Heartbeat:Wait() until caught > 0 or os.clock() > deadline
check(caught == 1, "catch once")
check(attackAtCatch, "attack state")
task.wait(0.6)
check(caught == 1, "no duplicate catch")
-- A bone takes the guard off duty and sleep remains correctly labeled through a repaint.
local bait = Instance.new("Model")
local baitPart = Instance.new("Part")
baitPart.Anchored, baitPart.CanCollide = true, false
baitPart.Position, baitPart.Parent = dogs.raptor.body.Position, bait
bait.PrimaryPart, bait.Parent = baitPart, folder
local accepted = Guard.lure(dogs.raptor, bait, 20, false)
check(accepted and not bait.Parent and Guard.isOffDuty(dogs.raptor), "bait consumes and naps")
local sleeper = dogs.triceratops
sleeper.ownerHome = false
sleeper.sleeping = true
Guard.setName(sleeper, "Sleep fixture")
check(sleeper.model:GetAttribute("GuardState") == "Sleep" and sleeper.zzz.Enabled, "sleep survives repaint")
-- Sleep, chase and duty fixtures remain for client rendering checks.
for key,dog in dogs do dog.ownerHome = true; dog.busyUntil = 0 end
Visual.state(dogs.cerberus, "Chase")
Visual.state(dogs.direwolf, "Chase")
Visual.state(dogs.gorilla, "Chase")
local result = Instance.new("StringValue")
result.Name, result.Value, result.Parent = "Results", game:GetService("HttpService"):JSONEncode(counts), folder
print("GUARDS PASS: eight models, rig attachments, colors, tiers, skins, duty, reset, catch and animation poses")
