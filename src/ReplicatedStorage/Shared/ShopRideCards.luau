--!strict
-- Ride renders: assets/rides/<key>/shop-cards/<key>.png, made by
-- blender/shop/render_ride_images.py from assets/rides/ride-geometry.json --
-- every part of `RideModel.build(key)` read back out of a live session, so the
-- picture is the same Blocks, Cylinders and Balls the street mounts.
-- Hashes and upload IDs: assets/shop-ui/ride-images.
--
-- WHY A PICTURE, when a ride is plain primitives a ViewportFrame can draw: so
-- the Rides shelf matches the guardian and house cards beside it -- lit in the
-- same studio, from the same camera, cropped to the machine -- where
-- `makeModelIcon` frames a ride by its bounding sphere and leaves a flat
-- skateboard a sliver across the middle of its well.
--
-- THE COST IS THAT A PICTURE CAN GO STALE. Change a ride in RideModel and this
-- card goes on showing the old one until the geometry is re-dumped and the
-- render re-run. A ride with no entry here keeps the live 3D preview.
local Cards = {}

-- BEGIN RIDE IMAGE IDS
Cards.images = {
	skateboard = "rbxassetid://82240531668741",
	bmx = "rbxassetid://121211067763511",
	scooter = "rbxassetid://74320112276842",
	hoverboard = "rbxassetid://105930834977872",
	scrambler = "rbxassetid://129344091194039",
	hoverdisc = "rbxassetid://123613429519195",
} :: { [string]: string }
-- END RIDE IMAGE IDS

-- Mounts the render into `holder`, replacing any preview already there, and
-- returns it -- or nil when this ride has no render, so the caller falls back.
function Cards.mount(holder: GuiObject, key: string): ImageLabel?
	local asset = Cards.images[key]
	if not asset then return nil end
	for _, child in ipairs(holder:GetChildren()) do
		if child:IsA("ViewportFrame") or child.Name == "RideImage" then
			child:Destroy()
		end
	end
	local image = Instance.new("ImageLabel")
	image.Name = "RideImage"
	image:SetAttribute("RideKey", key)
	image.BackgroundTransparency = 1
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.Size = UDim2.fromScale(0.96, 0.96)
	image.Image = asset
	image.ScaleType = Enum.ScaleType.Fit
	image.ZIndex = holder.ZIndex
	image.Parent = holder
	return image
end

return Cards
