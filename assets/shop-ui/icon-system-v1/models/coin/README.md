# Standard snout coin

The approved gold coin with a raised piggy snout and two recessed nostrils,
available as both UI artwork and a standalone game mesh.

- `coin.glb` / `coin.fbx`: one mesh, embedded gold palette.
- `palette.png`: base-color texture.
- `../../sources/coin.blend`: editable source with presentation lighting.
- `../../coin.png`: approved transparent 768px UI icon.
- `../../small/coin-32.png` through `coin-256.png`: smaller UI sizes.
- `manifest.json` / `validation.json`: dimensions and export checks.

Model pivot is at the center of the round rim. Diameter is 2 studs at import
scale 1; the decorated front faces Roblox +Z, and the
back (-Z) carries the same snout, mirrored, so the coin reads from both sides.
The mirror was applied to `coin.blend` by hand; re-running
`blender/shop/build_icon_system.py` for `coin` would bring the flat back back. Resize uniformly for world pickups
or coin effects. Use the PNG for currency labels and buttons. This model is
the same snout-emblem design used throughout the shop icon pack.

Files are ready to import; Roblox uploads and runtime asset IDs are not installed.
