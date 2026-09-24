# Arcade Legendary geometry revision v2

Mecha Player, Final Boss and Jackpot have more substantial 3D equipment matched to the approved concept references. Open `index.html` for front, rear, reference, animation pose and previous-build comparisons.

Mecha: fitted shell plates, layered shoulder armor, three-piece boots, raised vents and deep turbine thrusters. Its new pale coat and navy ear rims replace the noisy printed panel seams; eyes are black and the equipment carries the cyan glow.

Final Boss: broader brass-edged pauldrons, large energy gems, fitted shell panels, hip guards and mounted rear crystals. Jackpot: full arched reel casing, lamp sockets, rivets, gold rails and rear shield.

The base pig geometry and UVs are preserved. All meshes are closed, individually below 20,000 triangles, and verified through FBX reimport. Six-second motion retains pivots and parented armor. The three replacement models and two new Mecha maps are approved and installed in Studio. The live place was not published.

`build.py --skin <key>` runs inside background Blender. `tools/upload_arcade_v2.py` keeps v1 upload receipts and resumes v2 uploads. `tools/extract_arcade_runtime.py -- --v2` generates the runtime poses; `tools/install_arcade.py` reads `../arcade-build-v1/active-revisions.json`. `update_review.py` refreshes both preview pages. V1 Blender files, meshes and images remain available.
