--!strict
--[[
	SignShine

	The travelling highlight across a VIP owner's name on their plot sign.

	The server dresses the sign (`PlotService.setSignStyle`): it hangs a gold
	UIGradient called `GoldShine` on the name and sets a `SignShine`
	attribute. This only SLIDES that gradient, on every client, for the same
	reason the animated skins and `HouseFX` animate client-side: a per-frame
	write from the server would replicate forever to say something every
	machine can work out from a clock.

	The labels are found by NAME under `workspace.Plots` (the sign's `Owner`
	label) and the attribute is read each frame, rather than collected by tag
	or by attribute signal at startup. A plot changes owner -- and VIP status
	-- long after this starts, and there are ten of these labels at most.
]]

local RunService = game:GetService("RunService")

local SignShine = {}

-- One sweep of the pale band across the name, then a rest. Slow enough to
-- read as a glint rather than a flicker, and nowhere near the three-flashes-
-- a-second ceiling.
local SWEEP = 1.4
local REST = 1.8
local labels: { TextLabel } = {}
local started = false

local function consider(d: Instance)
	if d:IsA("TextLabel") and d.Name == "Owner" and not table.find(labels, d) then
		table.insert(labels, d)
	end
end

function SignShine.start()
	if started then return end
	started = true
	task.spawn(function()
		local plots = workspace:WaitForChild("Plots", 60)
		if not plots then return end
		for _, d in ipairs(plots:GetDescendants()) do
			consider(d)
		end
		plots.DescendantAdded:Connect(consider)

		RunService.Heartbeat:Connect(function()
			local t = os.clock() % (SWEEP + REST)
			-- -1 to +1 carries the band from off one end to off the other.
			local x = if t < SWEEP then -1 + 2 * (t / SWEEP) else 1
			for i = #labels, 1, -1 do
				local label = labels[i]
				if not label.Parent then
					table.remove(labels, i)
				elseif label:GetAttribute("SignShine") then
					local gradient = label:FindFirstChild("GoldShine")
					if gradient and gradient:IsA("UIGradient") then
						gradient.Offset = Vector2.new(x, 0)
					end
				end
			end
		end)
	end)
end

return SignShine
