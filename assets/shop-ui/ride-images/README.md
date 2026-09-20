# Ride catalog images

Six transparent 768 x 512 images, one per row of `Config.RIDES`, rendered in the guardian cards' studio from the same camera. Canonical images and per-image provenance JSON live in `assets/rides/<key>/shop-cards/`.

- The 3D source is `assets/rides/ride-geometry.json`: every BasePart of `RideModel.build(key)` (shape, size, CFrame relative to the model pivot, colour, material, transparency), read out of the shop's previews in a live Studio session. A ride is only Blocks, Cylinders and Balls, so Blender rebuilds it exactly rather than from a second model.
- `manifest.json`: image paths, geometry and PNG hashes, and Roblox IDs.
- `roblox-uploads.json`: uploaded images keyed by ride key.
- `contact-sheet.png`: all six together.

Regenerate from the repository root with `blender --background --python blender/shop/render_ride_images.py`, or `-- <key>[,<key>]` to render only those and merge their rows. **Re-dump `ride-geometry.json` first whenever `RideModel` changes**, or the card keeps showing the old ride. Upload changed images and update `Shared/ShopRideCards.luau` and `roblox-uploads.json` together.

`ShopRideCards.mount` is used by the Rides shop cards, the front-page RIDES shelf and the item reel; a ride with no image falls back to the live `RideModel` preview.
