# Home catalog images

All 18 currently listed houses use transparent 768×512 renders from the same
authored Blender sources that supply `Shared/HouseTemplates`. The camera uses a
consistent front three-quarter view, upright buildings, and automatic framing.
The source models, doors, materials and exported gameplay geometry are untouched.

- Canonical PNGs: `assets/houses/<model-folder>/shop-cards/<house-id>.png`, beside each source `.blend`. Each image has a matching provenance `.json`.
- `manifest.json`: repository-relative source/image paths, hashes and Roblox IDs.
- `roblox-uploads.json`: image asset IDs keyed by stable house ID.
- `contact-sheet.png`: visual review of all 18 images.
- `blender/shop/render_house_images.py`: reproducible renderer.
- `Shared/ShopHouseCards.luau`: image mapping and card presentation.

Run `blender --background --python blender/shop/render_house_images.py` to
regenerate. Upload changed PNGs and update the module's image mapping together.

Cards use `Config.RARITIES` for their full background color. Owning, equipping or
being unable to afford a house changes the action pill, not its rarity color.
Names wrap to two lines. Images use Fit scaling and preserve the full building.
A newly added house without artwork falls back to its actual 3D preview.

Validated: all 18 uploaded images loaded in Studio; no live model previews remain
on these house cards; no clipped house names at desktop, 740×390, 600×390 or
430×650 menu dimensions. `studio-desktop.png` shows the finished cards. Luau compilation, Rojo
build, and the existing 238 shop UI checks pass. Prices, purchase requests,
ownership and saved house IDs retain their existing behavior.
