# Acorn currency icon

`assets/acorn/ui/acorn-model-icon.png` is a transparent 512px render of `assets/acorn/acorn.blend`:
the same olive nut, chestnut cap, raised scales and leaning stem as the collectible.
It replaces the old brown-nut/green-cap drawing through `Theme.acorn`, including
HUD, shop counters, crate prices, shake rewards and rebirth displays.

Reproduce with Blender: `blender --background --python blender/acorn/render_icon.py`.
The renderer reads the source blend without saving over it or changing gameplay meshes.
Upload metadata and image SHA-256 are in `assets/acorn/ui/acorn-model-icon.json`.

Studio verified image loading at 20, 26, 37 and 54 px; see `icon-sizes-review.png`.
