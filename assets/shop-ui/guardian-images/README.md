# Guardian catalog images

Thirteen transparent 768 x 512 images rendered from the actual native rigs, one per row of `Config.DOG_COATS`. Canonical images and per-image provenance JSON live in `assets/guards/<rig>/shop-cards/`, beside the original `.blend` and report. Six coat variants use the Shepherd source; Gorilla, Raptor, Triceratops, Terrier, Mastiff, Dire Wolf and Cerberus retain their own geometry and authored palette.

- `manifest.json`: repository-relative model/image paths, source and PNG hashes, palettes, and Roblox IDs.
- `roblox-uploads.json`: uploaded images keyed by stable guardian ID.
- `contact-sheet.png`: the original nine images together.
- `studio-desktop.png`: the actual Guardians menu in Studio.
- `../../SHOP-RENDER-INDEX.md`: house, guardian and acorn reference index.

Regenerate from the repository root with `blender --background --python blender/shop/render_guardian_images.py`. This does not alter the source rigs. Upload changed images and update `Shared/ShopGuardianCards.luau` and the upload index together.

A NEW COAT RENDERS ALONE: `blender --background --python blender/shop/render_guardian_images.py -- <key>[,<key>]` renders only those and merges their rows, so the already-uploaded cards are not re-rendered out from under their asset ids. The script refuses to finish while any coat in Config has no card. `contact-sheet.png` and `studio-desktop.png` still show the original nine.

The Guardians menu uses ImageLabels and shared `ShopImageCards` styling. Full-card rarity colors stay stable across ownership states. Pets are paused and their purchases retained. Kennel customization is retired; body and trim match the current guardian, while the roof uses its collar or a creature's light accent. Legacy kennel purchases remain saved but inactive.

Validated in Studio: all nine images load, no Guardian ViewportFrames or retired sections, no pet follower folder/attribute, no clipped names at 430 x 650 or 600 x 390 panel sizes. Guardian palette/follower, shop UI, purchase audit and save suites pass (577 checks total); Luau compilation and Rojo build pass.
