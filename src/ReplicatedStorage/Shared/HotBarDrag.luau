--!strict
-- Pure drop rules, shared by the hotbar and its regression checks.
local HotBarDrag = {}

function HotBarDrag.owns(active: InputObject?, input: InputObject, ending: boolean): boolean
	if not active then return false end
	if active.UserInputType == Enum.UserInputType.Touch then return input == active end
	return input.UserInputType == (if ending then Enum.UserInputType.MouseButton1 else Enum.UserInputType.MouseMovement)
end

-- Move into the closest visible slot. The full arrangement supplies the
-- following key so a drop at a page's end cannot jump to the inventory's end.
function HotBarDrag.before(order: {string}, key: string,
	visible: {{key: string, x: number}}, x: number): string?
	local target, distance = key, math.huge
	for _, candidate in visible do
		local delta = math.abs(candidate.x - x)
		if delta < distance then target, distance = candidate.key, delta end
	end
	local from, to = table.find(order, key), table.find(order, target)
	if not from or not to or from == to then return key end
	return if to > from then order[to + 1] else target
end

function HotBarDrag.contains(point: Vector2, position: Vector2, size: Vector2): boolean
	return point.X >= position.X and point.X <= position.X + size.X
		and point.Y >= position.Y and point.Y <= position.Y + size.Y
end

return HotBarDrag
