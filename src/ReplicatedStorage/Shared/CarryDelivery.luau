--!strict
-- Presentation for the server's two destinations. No client-side settlement
-- or distance calculation: arriving inside a ring settles it on the server.
local CarryDelivery = {}
function CarryDelivery.describe(amount: number, haul: any, kind: string?, options: any?): any
	local items = if type(haul) == "table" then #haul else 0
	local visible = amount > 0 or items > 0
	-- ONE CARRY KIND. `kind` used to pick between a stolen pig and an acorn
	-- basket, which went with the currency; it stays in the signature because
	-- the server still sends it and a nil here has always meant a pig.
	local currency = "coins"
	local place = "piggy"
	local info = options or {}
	local action = info.action
	local home = if info.canKeep == false then "RETURN YOUR HAUL HOME"
		else ("KEEP · Your %s\n%d %s%s"):format(place, info.keepWorth or amount, currency,
			if items > 0 then " + all items" else "")
	local returning = if info.canReturn then
		("RETURN · %s %s\n+%d %s bounty"):format(if info.ownReturn then "Your" else (info.victim or "Owner").."'s",
			place, info.bounty or 0, currency)
		else "Return destination unavailable"
	local button = if action == "return" then "RETURN" else "KEEP"
	local banner = if action == "return" then "RETURN THE HAUL!"
		elseif action == "keep" then "DEPOSIT THE HAUL!"
		elseif info.canKeep == false then "WALK INTO YOUR PIGGY'S RING!"
		elseif info.canReturn then "WALK INTO A GLOWING RING!" else "WALK INTO YOUR PIGGY'S RING!"
	return {visible=visible, home=home, returning=returning, button=button,
		banner=banner, showHome=info.canKeep ~= false, showReturn=info.canReturn == true,
		canPress=visible and (action == "keep" or action == "return")}
end
return CarryDelivery
