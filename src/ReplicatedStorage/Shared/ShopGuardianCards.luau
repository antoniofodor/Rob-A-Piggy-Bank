--!strict
-- Native guardian renders: assets/guards/<rig>/shop-cards/<coat>.png.
-- Source models, palettes, hashes and upload IDs: assets/shop-ui/guardian-images.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Presentation = require(ReplicatedStorage.Shared.ShopImageCards)
local Cards = {}
-- BEGIN GUARDIAN IMAGE IDS
Cards.images = {
	raptor = "rbxassetid://139324732339969",
	goldenboy = "rbxassetid://70909885384363",
	dalmatian = "rbxassetid://94466664729438",
	gorilla = "rbxassetid://75445866786877",
	chocolate = "rbxassetid://96443703819078",
	triceratops = "rbxassetid://109345948759219",
	glacier = "rbxassetid://137516871818892",
	shadow = "rbxassetid://127154832312483",
	husky = "rbxassetid://117441561046801",
	terrier = "rbxassetid://126143860962341",
	mastiff = "rbxassetid://79883493152667",
	direwolf = "rbxassetid://110670035166700",
	cerberus = "rbxassetid://112271849554979",
} :: { [string]: string }
-- END GUARDIAN IMAGE IDS

function Cards.image(parent: GuiObject, id: string): ImageLabel?
	return Presentation.image(parent, "Guardian", id, Cards.images[id])
end

function Cards.decorate(entry: any, id: string)
	Presentation.decorate(entry, "Guardian", id)
end

function Cards.paint(entry: any, info: any, coins: number)
	Presentation.paint(entry, {
		rarity = info.rarity, current = info.equipped, owned = info.owned,
		forSale = true, cost = info.cost,
	}, coins)
end

return Cards
