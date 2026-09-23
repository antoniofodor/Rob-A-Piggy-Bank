--!strict
-- Blender-rendered artwork. Shop IDs: assets/shop-ui/icon-system-v1/roblox-uploads.json.
--
-- The ACORN row went with the currency. Its artwork is still uploaded and
-- still archived in assets/acorn/ui/acorn-model-icon.json; nothing mounts it.
local Icons = {}
Icons.ids = {
	["locks"] = "rbxassetid://112442325562665",
	["fences"] = "rbxassetid://90879713992858",
	["lockpicks"] = "rbxassetid://77326087433511",
	["sack"] = "rbxassetid://82505441855242",
	["boots"] = "rbxassetid://114479671264679",
	["tiptoe"] = "rbxassetid://70950783190764",
	["plunger"] = "rbxassetid://117055159290810",
	["rides"] = "rbxassetid://77665616074176",
	["style"] = "rbxassetid://123689883262147",
	["coin-front"] = "rbxassetid://81713106992402",
	["capacity"] = "rbxassetid://87288987634095",
	["supplies"] = "rbxassetid://116095837417269",
	["golden-bone"] = "rbxassetid://140048411631583",
	["coin"] = "rbxassetid://114357581414744",
	["income"] = "rbxassetid://84342101453188",
	["crate-common"] = "rbxassetid://99509648335802",
	["crate-legendary"] = "rbxassetid://95514707965117",
	["crate-rare"] = "rbxassetid://136857209566701",
	["upgrades"] = "rbxassetid://93469685522357",
	["bubblegum-bomb"] = "rbxassetid://133065431028531",
	["companions"] = "rbxassetid://99636931382659",
	["home"] = "rbxassetid://132806124510472",
} :: {[string]: string}
local supplies = {plunger = "plunger", gum = "bubblegum-bomb", golden = "golden-bone"}
-- BEGIN GENERATED UPGRADE CROPS
local crops = {
 ["income"] = {85, 57, 597, 629},
 ["capacity"] = {81, 166, 580, 441},
 ["locks"] = {150, 77, 463, 620},
 ["fences"] = {68, 123, 632, 531},
 ["lockpicks"] = {127, 82, 524, 618},
 ["sack"] = {127, 77, 495, 626},
 ["boots"] = {87, 179, 626, 380},
 ["tiptoe"] = {115, 87, 524, 625},
}
-- END GENERATED UPGRADE CROPS

function Icons.mount(parent: GuiObject, key: string, trim: boolean?): ImageLabel?
	local id = Icons.ids[key]
	if not id or not string.match(id, "^rbxassetid://%d+$") then return nil end
	local old = parent:FindFirstChild("ShopIcon")
	if old then old:Destroy() end
	local preview = parent:FindFirstChild("ShopPreview")
	if preview then preview:Destroy() end
	local image = Instance.new("ImageLabel")
	image.Name = "ShopIcon"; image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1); image.Image = id
	image.ScaleType = Enum.ScaleType.Fit; image.ZIndex = parent.ZIndex + 1
	local crop = crops[key]
	if trim and crop then
		image.ImageRectOffset = Vector2.new(crop[1], crop[2])
		image.ImageRectSize = Vector2.new(crop[3], crop[4])
	end
	image:SetAttribute("IconKey", key); image.Parent = parent
	return image
end

function Icons.supply(parent: GuiObject, key: string): ImageLabel?
	local iconKey = supplies[key]
	return if iconKey then Icons.mount(parent, iconKey) else nil
end

return Icons
