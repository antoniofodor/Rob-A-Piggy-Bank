-- Starter motion for the rigid low-poly rigs. Evaluated on every client so
-- Motor6D.Transform never depends on server replication or unpublished clips.
local Animation = {}
function Animation.pose(name: string, state: string, t: number, height: number): CFrame
	local moving = state == "Walk" or state == "Chase"
	local hostile = state == "Chase" or state == "Attack"
	local phase = t * (if state == "Chase" then 12 else 7)
	local size = height / 2.5
	if name == "Body" then
		local bounce = if moving then math.abs(math.sin(phase)) * 0.065 else math.sin(t * 2) * 0.012
		return CFrame.new(0, bounce * size, if state == "Attack" then 0.12 * size * math.sin(t * 18) else 0)
	elseif string.sub(name, 1, 3) == "Jaw" then
		local stagger = if string.find(name, "Left") then 0.8 elseif string.find(name, "Right") then 1.6 else 0
		local angle = if state == "Attack" then 0.48 + 0.2 * math.sin(t * 18 + stagger)
			elseif hostile then 0.26 + 0.1 * math.sin(phase + stagger) else 0
		return CFrame.Angles(angle, 0, 0)
	elseif string.sub(name, 1, 4) == "Head" then
		return CFrame.Angles(if hostile then 0.12 elseif state == "Sleep" then 0.16 else 0.025 * math.sin(t * 1.5),
			if moving or hostile or state == "Sleep" then 0 else 0.06 * math.sin(t), 0)
	elseif string.sub(name, 1, 4) == "Brow" then
		-- Brow_L sits at -X: its inner (+X) end must rotate down toward the snout.
		local sign = if string.sub(name, 1, 6) == "Brow_L" then -1 else 1
		return CFrame.Angles(0, 0, if hostile then sign * 0.3 else 0)
	elseif name == "Tail" then
		return CFrame.Angles(0, math.sin(t * (if moving then 8 else 3)) * 0.13, 0)
	elseif string.sub(name, 1, 5) == "Front" or string.sub(name, 1, 4) == "Back" then
		if not moving then return CFrame.identity end
		local base = string.split(name, "_")[1]
		local offset = if base == "FrontL" or base == "BackR" then 0 else math.pi
		local wave = math.sin(phase + offset)
		return CFrame.Angles(if string.find(name, "Lower") then -0.24 * math.max(wave, 0) else 0.4 * wave, 0, 0)
	end
	return CFrame.identity
end
return Animation
