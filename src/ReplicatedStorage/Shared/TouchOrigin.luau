--!strict
--[[
	TouchOrigin

	A THUMB ON THE STICK IS NOT A PRESS ON WHATEVER IT SLIDES ACROSS.

	Reported on a phone: while moving with the thumbstick, dragging the same
	stroke over a hot bar tile picked the item up. On a touchscreen a finger
	that is ALREADY down can arrive over a button and be delivered to it --
	`InputBegan`, then `Activated` when it lifts -- although it started on the
	other side of the screen and was never aimed at the button at all. Every
	control a player might pass over while walking is exposed: the hot bar,
	the dodge, the sneak and the wheelie.

	The question every one of them has to ask is WHERE THE TOUCH STARTED, and
	nothing on the InputObject says so -- `Position` is where it is now. So
	this records each touch's starting point on `TouchStarted` and answers
	"did this touch begin on that button". A touch nobody has recorded yet is
	treated as brand new: `TouchStarted` and a button's own `InputBegan` can
	arrive in either order in the same frame, and a real tap must never be
	refused for losing that race.

	THE BOUNDS ARE TESTED TWICE, WITH AND WITHOUT THE TOPBAR INSET. An
	InputObject's position and a GuiObject's AbsolutePosition only share an
	origin when the ScreenGui ignores the inset, and a wrong guess here would
	refuse real taps. Accepting either reading costs nothing that matters: a
	thumb that started on the stick is hundreds of pixels away either way.
]]

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local TouchOrigin = {}

-- Strong-keyed and cleared on release. An InputObject is an engine object,
-- so a weak key would be collected while the touch is still down.
local starts: { [InputObject]: Vector2 } = {}
-- A little slack round the button, so a tap on its very edge still counts.
local SLACK = 6

UserInputService.TouchStarted:Connect(function(input)
	starts[input] = Vector2.new(input.Position.X, input.Position.Y)
end)

UserInputService.TouchEnded:Connect(function(input)
	-- Deferred so a button's own InputEnded or Activated for this touch can
	-- still ask where it began.
	task.defer(function()
		starts[input] = nil
	end)
end)

local function inside(point: Vector2, gui: GuiObject): boolean
	local pos, size = gui.AbsolutePosition, gui.AbsoluteSize
	local inset = GuiService:GetGuiInset()
	for _, y in ipairs({ point.Y, point.Y + inset.Y }) do
		if point.X >= pos.X - SLACK and point.X <= pos.X + size.X + SLACK
			and y >= pos.Y - SLACK and y <= pos.Y + size.Y + SLACK then
			return true
		end
	end
	return false
end

-- True when `input` is a touch that started somewhere other than `gui`: a
-- finger that slid onto it rather than one pressed on it. False for a mouse,
-- a key, and a touch too new to have been recorded.
function TouchOrigin.beganElsewhere(input: InputObject, gui: GuiObject): boolean
	if input.UserInputType ~= Enum.UserInputType.Touch then
		return false
	end
	local start = starts[input]
	return start ~= nil and not inside(start, gui)
end

-- A GATE FOR `Activated`, which hands over no InputObject to ask about.
--
-- Watches the button's own touch-downs and returns a check for its
-- `Activated` handler: false when the latest touch to reach this button slid
-- onto it rather than started on it. Keyed on the latest touch-down rather
-- than on "the last finger to lift", because with a thumb on the stick two
-- fingers are always in play and the last to lift may be the wrong one.
-- Mouse, keyboard and gamepad are never refused.
function TouchOrigin.guard(button: GuiObject): () -> boolean
	local pressedAt, strayAt = -math.huge, -math.huge
	button.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if TouchOrigin.beganElsewhere(input, button) then
			strayAt = os.clock()
		else
			pressedAt = os.clock()
		end
	end)
	return function(): boolean
		if UserInputService:GetLastInputType() ~= Enum.UserInputType.Touch then
			return true
		end
		return pressedAt >= strayAt
	end
end

return TouchOrigin
