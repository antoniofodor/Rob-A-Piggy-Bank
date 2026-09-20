--!strict
-- House artwork rendered from the same Blender sources as HouseTemplates.
-- Rebuild with blender/shop/render_house_images.py; upload provenance lives
-- in assets/shop-ui/house-images/manifest.json and roblox-uploads.json.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Presentation = require(ReplicatedStorage.Shared.ShopImageCards)

local Cards = {}
-- BEGIN HOUSE IMAGE IDS
Cards.images = {
	["shack"] = "rbxassetid://113174635536569",
	["cottage"] = "rbxassetid://106753868152741",
	["townhouse"] = "rbxassetid://78339309144437",
	["mushroom"] = "rbxassetid://130500543862535",
	["villa"] = "rbxassetid://102026091853191",
	["treehouse"] = "rbxassetid://91807335475451",
	["manor"] = "rbxassetid://109401304165023",
	["slime"] = "rbxassetid://96955097964634",
	["modern"] = "rbxassetid://139306301644896",
	["neontower"] = "rbxassetid://106398419714312",
	["crystal"] = "rbxassetid://116973739617551",
	["palace"] = "rbxassetid://132549088501298",
	["skycastle"] = "rbxassetid://80739296348772",
	["galleon"] = "rbxassetid://83653158520840",
	["portal"] = "rbxassetid://108117661847706",
	["thundercloud"] = "rbxassetid://94755671019382",
	["void"] = "rbxassetid://129272397314290",
	["goldenpig"] = "rbxassetid://98340251094000",
} :: { [string]: string }
-- END HOUSE IMAGE IDS

function Cards.image(parent: GuiObject, id: string): ImageLabel?
	return Presentation.image(parent, "House", id, Cards.images[id])
end

function Cards.decorate(entry: any, info: any)
	Presentation.decorate(entry, "House", info.id)
end

Cards.paint = Presentation.paint
return Cards
