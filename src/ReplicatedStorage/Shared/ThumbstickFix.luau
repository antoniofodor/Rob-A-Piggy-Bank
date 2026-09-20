--!strict
--[[
	ThumbstickFix

	PRESSING ANY BUTTON ON A PHONE STOPPED THE PLAYER, and the fault is in
	Roblox's own DynamicThumbstick, not in any button.

	Reported on the wheelie ("pressing wheelie while riding stops the player on
	mobile"), and it was never about the wheelie. The thumbstick binds one
	ContextActionService action to ALL touch input, and its handler reads:

	    elseif inputState == Enum.UserInputState.Cancel then
	        self:OnInputEnded()

	with no check of WHICH touch was cancelled. Every other branch in that same
	handler compares the input against `self.moveTouchObject`; this one does
	not. So a second finger landing on a GuiButton -- a touch the GUI takes,
	which reaches the action as a Cancel -- zeroes the move vector while the
	thumb is still on the stick. The player stops dead and only moves again
	once they lift and replace their thumb. It hits every on-screen control in
	this game equally: the trick, the dodge, the sneak, the hot bar and the
	garage slot. The dodge hid it best, because its dash drives the move
	direction itself for the length of the window.

	THE FIX GUARDS `OnInputEnded` RATHER THAN RE-BINDING THE ACTION, because
	the handler is a local inside the module and cannot be reached, while the
	method is on the class table that `require` hands back to everybody. The
	guard lets an end through only when it is real:

	  * the move touch itself has ended or been cancelled;
	  * the controller is being disabled (switching to keyboard, a respawn),
	    which is the cleanup `Enable(false)` runs -- flagged around the call;
	  * the Roblox menu is open, which the module also ends movement for.

	Anything else -- a Cancel for some OTHER finger while the thumb is still
	down and moving -- is ignored, and the stick carries on.

	IT FAILS SAFE. If Roblox renames or restructures the module, `start` finds
	nothing to patch, warns once, and the game plays exactly as it did.
]]

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")

local ThumbstickFix = {}
local patched = false

local LIVE = {
	[Enum.UserInputState.Begin] = true,
	[Enum.UserInputState.Change] = true,
}

local function patch(class: any)
	local originalEnded = class.OnInputEnded
	local originalEnable = class.Enable
	if type(originalEnded) ~= "function" or type(originalEnable) ~= "function" then
		warn("[ThumbstickFix] DynamicThumbstick has changed shape; leaving it alone.")
		return
	end

	class.Enable = function(self, ...)
		self.__disabling = true
		local ok, result = pcall(originalEnable, self, ...)
		self.__disabling = nil
		if not ok then
			error(result, 0)
		end
		return result
	end

	class.OnInputEnded = function(self, ...)
		local touch = self.moveTouchObject
		if touch and not self.__disabling and not GuiService.MenuIsOpen
			and LIVE[touch.UserInputState] then
			-- The thumb is still down and moving: this end belongs to a
			-- different finger. Keep walking.
			return
		end
		return originalEnded(self, ...)
	end
	patched = true
end

function ThumbstickFix.start()
	if patched then
		return
	end
	task.spawn(function()
		local player = Players.LocalPlayer
		local scripts = player:WaitForChild("PlayerScripts", 20)
		local playerModule = scripts and scripts:WaitForChild("PlayerModule", 20)
		local controlModule = playerModule and playerModule:WaitForChild("ControlModule", 20)
		local dynamic = controlModule and controlModule:WaitForChild("DynamicThumbstick", 20)
		if not dynamic or not dynamic:IsA("ModuleScript") then
			warn("[ThumbstickFix] no DynamicThumbstick module found; leaving controls alone.")
			return
		end
		-- The same table ControlModule required: modules are cached per peer,
		-- so patching the class here patches the controller already in use.
		local ok, class = pcall(require, dynamic)
		if not ok or type(class) ~= "table" then
			warn("[ThumbstickFix] could not load DynamicThumbstick: " .. tostring(class))
			return
		end
		patch(class)
	end)
end

return ThumbstickFix
