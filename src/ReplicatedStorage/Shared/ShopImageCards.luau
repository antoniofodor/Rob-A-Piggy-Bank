--!strict
-- Shared presentation for static house and guardian artwork.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Cards = {}

function Cards.image(parent: GuiObject, kind: string, id: string, asset: string?): ImageLabel?
	if not asset then return nil end
	local image = Instance.new("ImageLabel")
	image.Name = kind .. "Image"
	image:SetAttribute(kind .. "Id", id)
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = asset
	image.ScaleType = Enum.ScaleType.Fit
	-- The rarity chip is a later sibling and must stay above the artwork.
	image.ZIndex = parent.ZIndex
	image.Parent = parent
	return image
end

function Cards.decorate(entry: any, kind: string, id: string)
	entry.button.Name = kind .. "_" .. id
	entry.button:SetAttribute(kind .. "Id", id)
	entry.title.Name = kind .. "Name"
	entry.title.TextWrapped = true
	entry.title.TextTruncate = Enum.TextTruncate.None
	entry.title.TextSize = 14
	entry.title.Size = UDim2.new(1, -16, 0, 32)
	entry.title.TextColor3 = Theme.INK
	local edge = entry.button:FindFirstChild("RarityEdge")
	if edge and edge:IsA("UIStroke") then
		edge.Color = Theme.INK
		edge.Thickness = 2
	end
	-- Let the full card's rarity color continue behind the transparent render.
	if entry.swatch then
		entry.swatch.BackgroundTransparency = 1
		local stroke = entry.swatch:FindFirstChildOfClass("UIStroke")
		if stroke then stroke:Destroy() end
	end
end

function Cards.paint(entry: any, info: any, coins: number)
	local rarity = Config.RARITIES[info.rarity] or Config.RARITIES.common
	entry.button:SetAttribute("Rarity", info.rarity or "common")
	-- Ownership changes the action pill, never the item's tier color.
	entry.button.BackgroundColor3 = rarity.colour:Lerp(Theme.PAPER, 0.12)
	entry.sub.BackgroundColor3 = rarity.colour:Lerp(Theme.PAPER, 0.78)
	entry.sub.TextColor3 = Theme.INK
	if info.current then
		entry.sub.BackgroundColor3 = Theme.INK
		entry.sub.TextColor3 = Theme.PAPER
	elseif info.forSale and not info.owned and coins < (info.cost or math.huge) then
		entry.sub.TextColor3 = Theme.MUTED
	end
end

return Cards
