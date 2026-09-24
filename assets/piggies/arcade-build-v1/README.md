# Arcade — expanded collection

Ten imported Arcade assets: four Rares, three Epics and three Legendaries. This expansion adds Pixel, Circuit Board, Power-Up, Synthwave, Final Boss and Mecha Player.
Player One follows the selected 16-bit concept; the resulting authored coat moves this starter from the original Common proposal to Rare. The wider 24-piggy lineup remains a proposal.

Open `index.html` to compare original concepts and actual model renders. `arcade-collection-v2.blend` contains the overview plus ten individual asset scenes. Individual packed Blender files, source files, static FBXs and baked maps are linked in each card.

Player One approximates sprite shading with fixed pixel clusters, a limited palette, dithered transitions and 1P badges on the existing smooth mesh. Retro Carpet uses printed colored shapes. Respawn has seven small animated cube accessories. Jackpot has three separate rotating symbol reels, a fitted saddle/housing, bulbs and six moving gold tokens.

Mesh/UV preservation, closed meshes, per-mesh triangle limits, FBX round-trip bounds, animation loop closure and legendary face clearance are checked by the builder. The finalizer verifies texture hashes and required files. The aura collections are Blender preview proxies; the six corresponding runtime auras are now installed.

The collection is installed in the repository and synced into Roblox Studio. All 35 maps and five accessory models are approved. The Arcade and Arcade Legendary crates use existing Rare and Legendary odds, with no empty Common tier. Authored six-second motion is sampled into `ArcadeMotionData.luau` and played locally by `ArcadeAnimator.luau` on anchored pigs. Carried pigs keep a welded static pose. Publishing the live place was not performed. See `roblox-integration.json` for validation.

Concepts were generated with built-in image_gen. Exact prompts and originals are in `../arcade-concepts-v1/`; selected references are copied into each asset's preview folder.

Run `python assets/piggies/arcade-build-v1/prepare_builder.py` after editing the spatial-paint or geometry source fragments, then `python assets/piggies/arcade-build-v1/build_batch.py --keys playerone,retrocarpet,respawn,jackpot,pixel,circuitboard,powerup,synthwave,finalboss,mechaplayer` and `python assets/piggies/arcade-build-v1/finalize.py`.
