--!strict
--[[
	LegendaryFX -- starts each legendary's glow helper wherever one is worn.

	The helpers write EmissiveStrength and part colours every frame, which is
	per-machine work for the reason the animated skins are: replicating a
	write per part per frame to say something every client can compute from a
	clock is the wrong trade. So the server only builds the model
	(`Shared/LegendaryModel`) and every client finds it here, by NAME -- a
	folder parented whole, which a scan and a DescendantAdded both see, rather
	than a CollectionService tag, whose added signal does not fire for an
	instance that replicates already tagged.

	Watches the workspace and the player's own gui (the shop and bag
	viewports hold minis too). A helper is started once the folder holds every
	part it announced, and stopped when the folder leaves.

	Started with one statement from ClientMain, which is at the 200-local
	ceiling.
]]

local Players = game:GetService("Players")

local LegendaryModel = require(script.Parent:WaitForChild("LegendaryModel"))
local helpers = script.Parent:WaitForChild("Legendary")

local HELPER = {
	stormwolf = "StormWolfLightning",
	dragon = "DragonGlow",
	phoenix = "PhoenixFrost",
	rainbowtiger = "RainbowTigerGlow",
}

local LegendaryFX = {}
local running: { [Instance]: () -> () } = {}

local function countParts(folder: Instance): number
	local n = 0
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

local function begin(folder: Instance)
	if running[folder] or not folder:IsA("Model") then
		return
	end
	local key = folder:GetAttribute(LegendaryModel.KEY_ATTRIBUTE)
	local name = type(key) == "string" and HELPER[key]
	local module = name and helpers:FindFirstChild(name)
	if not module then
		return
	end
	running[folder] = function() end
	task.spawn(function()
		local want = folder:GetAttribute(LegendaryModel.COUNT_ATTRIBUTE)
		local waited = 0
		while type(want) == "number" and countParts(folder) < want and waited < 10 do
			waited += task.wait(0.2)
		end
		if not folder.Parent then
			running[folder] = nil
			return
		end
		local phase = math.random() * 4
		local ok, stop = pcall(function()
			return (require(module :: ModuleScript) :: any).start(folder, phase)
		end)
		-- The idle sway runs on the same phase as the glow, so a pulse and a
		-- swing that were authored together land together.
		local okIdle, stopIdle = pcall(function()
			return (require(helpers:WaitForChild("Idle")) :: any).start(folder, key, phase)
		end)
		if not okIdle then
			warn(("[LegendaryFX] %s idle did not start: %s"):format(tostring(key), tostring(stopIdle)))
			stopIdle = nil
		end
		if ok and type(stop) == "function" then
			running[folder] = function()
				stop()
				if type(stopIdle) == "function" then stopIdle() end
			end
		else
			running[folder] = nil
			warn(("[LegendaryFX] %s helper did not start: %s"):format(tostring(key), tostring(stop)))
		end
	end)
end

local function watch(root: Instance)
	for _, d in ipairs(root:GetDescendants()) do
		if d.Name == LegendaryModel.NAME then
			begin(d)
		end
	end
	root.DescendantAdded:Connect(function(d)
		if d.Name == LegendaryModel.NAME then
			begin(d)
		end
	end)
	root.DescendantRemoving:Connect(function(d)
		local stop = running[d]
		if stop then
			running[d] = nil
			stop()
		end
	end)
end

function LegendaryFX.start()
	watch(workspace)
	task.spawn(function()
		watch(Players.LocalPlayer:WaitForChild("PlayerGui"))
	end)
end

return LegendaryFX
