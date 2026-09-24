# Game render reference index

Canonical artwork is stored beside its original 3D source. Each PNG has a matching JSON file recording its source path/hash, image hash, and uploaded Roblox asset ID. The `shop-ui` folders contain indexes and review sheets; they are not duplicate image libraries.

**Every folder below is named after the `Config` KEY, never the display name.**
The Scrappy guardian lives in `guards/terrier/` because its coat key is still
`terrier`; see `assets/README.md`.

- Houses: `houses/<model-folder>/shop-cards/<house-id>.png`
- Guardians: `guards/<rig>/shop-cards/<guardian-id>.png` (six coats share the Shepherd rig). All thirteen `Config.DOG_COATS` rows have a card.
- Rides: `rides/<ride>/shop-cards/<ride>.png`, rebuilt from `rides/ride-geometry.json` (ids mapped in `ShopRideCards`)
- Acorn currency: `acorn/ui/acorn-model-icon.png` -- **RETIRED with the currency (schema 29).** The image is still uploaded and nothing mounts it; the row below is an upload record, not a shop card. See [`acorn/README.md`](acorn/README.md).
- Animal skins: `piggies/<tier>/<skin>/package/shop-cards/<skin>.png`; the ids in `shop-ui/skin-images/roblox-uploads.json` are the count of record, mapped in `ShopSkinCards`. Skins land often enough that pinning a number here would go stale. Everything about a skin -- scene, generator, sheets, previews, the derived import package and the live texture ids -- is under `piggies/<skin>/`; see `piggies/README.md`. The tier galleries stay at `skins/animal/<tier>/index.html`.

Regenerate with Blender using `blender/shop/render_house_images.py`, `blender/shop/render_guardian_images.py`, `blender/shop/render_ride_images.py`, or `blender/shop/render_skin_images.py` from the repository root. (`blender/acorn/render_icon.py` was listed here and is gone with the acorn track, schema 29.) These scripts only read the native models; they never save over them. Upload changed PNGs and update the corresponding `ShopHouseCards`, `ShopGuardianCards`, `ShopRideCards`, or `ShopIcons` mappings. Guardian colors use `Config.DOG_COATS` and each model's authored palette, matching `GuardRig.tones`.

| Asset | 3D source | Card image | Roblox image ID |
| --- | --- | --- | --- |
| Cardboard Fort (house) | [Blend](houses/cardboard-fort-v2/cardboard-fort.blend) | [PNG](houses/cardboard-fort-v2/shop-cards/shack.png) | `rbxassetid://113174635536569` |
| Beehive Cottage (house) | [Blend](houses/beehive-cottage-v2/beehive-cottage.blend) | [PNG](houses/beehive-cottage-v2/shop-cards/cottage.png) | `rbxassetid://106753868152741` |
| Wonky Townhouse (house) | [Blend](houses/wonky-townhouse-v2/wonky-townhouse.blend) | [PNG](houses/wonky-townhouse-v2/shop-cards/townhouse.png) | `rbxassetid://78339309144437` |
| Toadstool Cottage (house) | [Blend](houses/toadstool-cottage-v2/toadstool-cottage.blend) | [PNG](houses/toadstool-cottage-v2/shop-cards/mushroom.png) | `rbxassetid://130500543862535` |
| Fairy Lantern Cottage (house) | [Blend](houses/fairy-lantern-cottage-v2/fairy-lantern-cottage.blend) | [PNG](houses/fairy-lantern-cottage-v2/shop-cards/villa.png) | `rbxassetid://102026091853191` |
| Treehouse (house) | [Blend](houses/treehouse-v3/treehouse.blend) | [PNG](houses/treehouse-v3/shop-cards/treehouse.png) | `rbxassetid://91807335475451` |
| Haunted Manor (house) | [Blend](houses/haunted-manor-v2/haunted-manor.blend) | [PNG](houses/haunted-manor-v2/shop-cards/manor.png) | `rbxassetid://109401304165023` |
| Gloop House (house) | [Blend](houses/gloop-house-v3/gloop-house.blend) | [PNG](houses/gloop-house-v3/shop-cards/slime.png) | `rbxassetid://96955097964634` |
| Fishbowl House (house) | [Blend](houses/fishbowl-house-v2/fishbowl-house.blend) | [PNG](houses/fishbowl-house-v2/shop-cards/modern.png) | `rbxassetid://139306301644896` |
| Neon Tower (house) | [Blend](houses/neon-tower-v2/neon-tower.blend) | [PNG](houses/neon-tower-v2/shop-cards/neontower.png) | `rbxassetid://106398419714312` |
| Crystal Spire (house) | [Blend](houses/crystal-spire-v2/crystal-spire.blend) | [PNG](houses/crystal-spire-v2/shop-cards/crystal.png) | `rbxassetid://116973739617551` |
| Ice Palace (house) | [Blend](houses/ice-palace-v2/ice-palace.blend) | [PNG](houses/ice-palace-v2/shop-cards/palace.png) | `rbxassetid://132549088501298` |
| Sky Castle (house) | [Blend](houses/sky-castle-v2/sky-castle.blend) | [PNG](houses/sky-castle-v2/shop-cards/skycastle.png) | `rbxassetid://80739296348772` |
| Beached Galleon (house) | [Blend](houses/beached-galleon-v2/beached-galleon.blend) | [PNG](houses/beached-galleon-v2/shop-cards/galleon.png) | `rbxassetid://83653158520840` |
| Portal House (house) | [Blend](houses/portal-house-v2/portal-house.blend) | [PNG](houses/portal-house-v2/shop-cards/portal.png) | `rbxassetid://108117661847706` |
| Thundercloud Fortress (house) | [Blend](houses/thundercloud-fortress-v2/thundercloud-fortress.blend) | [PNG](houses/thundercloud-fortress-v2/shop-cards/thundercloud.png) | `rbxassetid://94755671019382` |
| The Void (house) | [Blend](houses/the-void-v2/the-void.blend) | [PNG](houses/the-void-v2/shop-cards/void.png) | `rbxassetid://129272397314290` |
| Golden Piggy (house) | [Blend](houses/golden-piggy-v2/golden-piggy.blend) | [PNG](houses/golden-piggy-v2/shop-cards/goldenpig.png) | `rbxassetid://98340251094000` |
| Chocolate (guardian) | [Blend](guards/shepherd/shepherd.blend) | [PNG](guards/shepherd/shop-cards/chocolate.png) | `rbxassetid://96443703819078` |
| Husky (guardian) | [Blend](guards/shepherd/shepherd.blend) | [PNG](guards/shepherd/shop-cards/husky.png) | `rbxassetid://117441561046801` |
| Golden Boy (guardian) | [Blend](guards/shepherd/shepherd.blend) | [PNG](guards/shepherd/shop-cards/goldenboy.png) | `rbxassetid://70909885384363` |
| Spotless Dalmatian (guardian) | [Blend](guards/shepherd/shepherd.blend) | [PNG](guards/shepherd/shop-cards/dalmatian.png) | `rbxassetid://94466664729438` |
| Shadow (guardian) | [Blend](guards/shepherd/shepherd.blend) | [PNG](guards/shepherd/shop-cards/shadow.png) | `rbxassetid://127154832312483` |
| Glacier (guardian) | [Blend](guards/shepherd/shepherd.blend) | [PNG](guards/shepherd/shop-cards/glacier.png) | `rbxassetid://137516871818892` |
| Gorilla (guardian) | [Blend](guards/gorilla/gorilla.blend) | [PNG](guards/gorilla/shop-cards/gorilla.png) | `rbxassetid://75445866786877` |
| Raptor (guardian) | [Blend](guards/raptor/raptor.blend) | [PNG](guards/raptor/shop-cards/raptor.png) | `rbxassetid://139324732339969` |
| Triceratops (guardian) | [Blend](guards/triceratops/triceratops.blend) | [PNG](guards/triceratops/shop-cards/triceratops.png) | `rbxassetid://109345948759219` |
| Scrappy (guardian, key `terrier`) | [Blend](guards/terrier/terrier.blend) | [PNG](guards/terrier/shop-cards/terrier.png) | `rbxassetid://126143860962341` |
| Mastiff (guardian) | [Blend](guards/mastiff/mastiff.blend) | [PNG](guards/mastiff/shop-cards/mastiff.png) | `rbxassetid://79883493152667` |
| Dire Wolf (guardian) | [Blend](guards/direwolf/direwolf.blend) | [PNG](guards/direwolf/shop-cards/direwolf.png) | `rbxassetid://110670035166700` |
| Cerberus (guardian) | [Blend](guards/cerberus/cerberus.blend) | [PNG](guards/cerberus/shop-cards/cerberus.png) | `rbxassetid://112271849554979` |
| Skateboard (ride) | [Geometry](rides/ride-geometry.json) | [PNG](rides/skateboard/shop-cards/skateboard.png) | `rbxassetid://82240531668741` |
| BMX Bike (ride) | [Geometry](rides/ride-geometry.json) | [PNG](rides/bmx/shop-cards/bmx.png) | `rbxassetid://121211067763511` |
| E-Scooter (ride) | [Geometry](rides/ride-geometry.json) | [PNG](rides/scooter/shop-cards/scooter.png) | `rbxassetid://74320112276842` |
| Hoverboard (ride) | [Geometry](rides/ride-geometry.json) | [PNG](rides/hoverboard/shop-cards/hoverboard.png) | `rbxassetid://105930834977872` |
| Volt Scrambler (ride) | [Geometry](rides/ride-geometry.json) | [PNG](rides/scrambler/shop-cards/scrambler.png) | `rbxassetid://129344091194039` |
| Hoverdisc (ride) | [Geometry](rides/ride-geometry.json) | [PNG](rides/hoverdisc/shop-cards/hoverdisc.png) | `rbxassetid://123613429519195` |
| Acorn currency (RETIRED) | [Blend](acorn/acorn.blend) | [PNG](acorn/ui/acorn-model-icon.png) | `rbxassetid://86680018585267` |
