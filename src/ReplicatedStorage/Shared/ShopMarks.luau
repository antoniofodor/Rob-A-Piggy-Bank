--!strict
-- Small native UI illustrations authored at 96 px; no external image assets.
local Theme = require(script.Parent.Theme)
local W = require(script.Parent.ShopWidgets)
local Marks = {}
function Marks.draw(parent: Instance, kind: string, size: number): Frame
	local root=W.frame(parent,kind.."Icon");root.BackgroundTransparency=1;root.Size=UDim2.fromOffset(size,size)
	local art=W.frame(root,"Art");art.Size=UDim2.fromOffset(96,96);art.BackgroundTransparency=1
	local scale=Instance.new("UIScale");scale.Scale=size/96;scale.Parent=art
	local function shape(name,x,y,w,h,colour,radius,outline)
		local f=W.frame(art,name,colour);f.Position=UDim2.fromOffset(x,y);f.Size=UDim2.fromOffset(w,h)
		W.round(f,radius,outline);return f
	end
	if kind=="basket" then
		local handle=shape("Handle",29,5,39,49,Theme.PAPER,18,true)
		local hole=shape("HandleHole",37,13,23,31,Theme.GOLD,10,false)
		handle.Rotation=-12;hole.Rotation=-12
		local body=shape("Basket",12,39,71,48,Theme.PIG,11,true);body.Rotation=-9
		local rim=shape("Rim",8,31,79,16,Theme.PIG_DEEP,5,true);rim.Rotation=-9
		for i=0,2 do local slot=shape("Slot",27+i*16,53-i*2,6,22,Theme.INK,3,false);slot.Rotation=-9 end
	elseif kind=="piggy" then
		local left=shape("LeftEar",15,24,23,29,Theme.PIG_DEEP,7,true);left.Rotation=-22
		local right=shape("RightEar",60,24,23,29,Theme.PIG_DEEP,7,true);right.Rotation=22
		shape("Head",13,34,70,53,Theme.PIG,22,true)
		shape("Coin",37,4,24,29,Theme.GOLD,12,true)
		shape("CoinInset",43,9,12,18,Theme.GOLD_DEEP,6,false)
		shape("Slot",34,34,29,5,Theme.INK,2,false)
		for _,x in {29,60} do shape("Eye",x,49,7,9,Theme.INK,4,false) end
		shape("Snout",30,61,37,23,Theme.PIG_DEEP,10,true)
		for _,x in {39,54} do shape("Nostril",x,68,5,8,Theme.INK,3,false) end
	elseif kind=="bag" then
		local handle=shape("Handle",33,6,30,29,Theme.GOLD,10,true)
		handle.BackgroundTransparency=1
		handle:FindFirstChildOfClass("UIStroke").Thickness=5
		local inlay=shape("HandleInlay",33,6,30,29,Theme.GOLD,10,true)
		inlay.BackgroundTransparency=1;inlay:FindFirstChildOfClass("UIStroke").Color=Theme.GOLD
		shape("Body",18,25,60,62,Theme.PIG_DEEP,14,true)
		shape("Front",23,31,50,49,Theme.PIG,11,false)
		shape("Flap",20,24,56,29,Theme.GOLD,10,true)
		shape("FlapHighlight",28,29,26,4,Theme.PAPER,2,false)
		shape("Pocket",27,60,42,21,Theme.PIG_DEEP,7,true)
		shape("PocketHighlight",33,64,24,3,Theme.PIG,2,false)
		shape("Clasp",42,44,12,17,Theme.PAPER,4,true)
		shape("ClaspSlot",47,49,2,7,Theme.INK,1,false)
	elseif kind=="trophy" then
		for _,x in {11,62} do
			shape("Handle",x,18,24,33,Theme.GOLD,10,true)
			shape("Opening",x+7,24,10,16,Theme.PAPER,4,false)
		end
		shape("Cup",27,13,42,43,Theme.GOLD,12,true)
		shape("Stem",42,51,12,23,Theme.GOLD,3,true)
		shape("Base",26,75,44,12,Theme.GOLD_DEEP,3,true)
		shape("Glint",35,22,6,20,Theme.PAPER,3,false)
	end
	return root
end
return Marks
