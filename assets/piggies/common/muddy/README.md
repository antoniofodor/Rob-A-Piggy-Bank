# Muddy Piggy — OG splash coat

Concept v1 preserves the shared pink pig and adds irregular earth-brown mud
splashes on all four legs, lower flanks, upper back and rump. The face, snout,
eyes and ears stay clean and readable. The coating follows the body rather
than adding boots or separate floating chunks.

- [Front and rear concept](preview/muddy-concept-v1.png)
- [Exact generation prompt](generate/muddy-concept-v1-prompt.txt)
- Reference: `assets/ui/rebirth-icons-v1/references/classic-piggy-model.png`.
- Method: built-in image_gen with the original pig as the shape reference.

The approved concept is now implemented on the shared closed-back pig.
The mud is baked directly onto its surface: uneven muddy feet, upward
splashes on the lower flanks, scattered droplets, and a connected rear-back
patch. The face, snout and ears remain clean. No additional geometry is used.

Open [the packed review scene](package/muddy-complete.blend) for the finished
pig with its textures embedded, or [the procedural source](source/muddy.blend)
to edit the splash material. [The FBX](package/muddy-complete.fbx) is an
optional standalone import; the game already has the shared meshes.

- [Actual front three-quarter render](preview/muddy-hero.png)
- [Actual rear three-quarter render](preview/muddy-back.png)
- Two 1024 × 1024 ColorMaps in `sheets/`: body and trim.
- Mesh positions/topology and UVs are preserved; no added triangles.
- The FBX round trip and texture copies are checked in `package/muddy-asset-report.json`.
- `manifest.json` records the generated files, hashes and pending upload state.

Rebuild in order with Blender's `--background --python` option:

1. `assets/piggies/common/muddy/generate/make_muddy_blend.py`
2. `blender/pig/make/bake_skin.py -- --skin muddy`
3. `blender/pig/make/package_animal.py -- --skin muddy --name "Muddy Piggy"`
4. `assets/piggies/common/muddy/generate/review_muddy.py`
5. Run `python assets/piggies/common/muddy/generate/finalize_muddy.py`.

Roblox installation is pending; the current game still uses the old spots.
Upload only the two ColorMaps, then create `muddy` and `muddy_trim`
SurfaceAppearance templates using the returned IDs. Add the corresponding
`Config.SURFACE_PACKS.muddy` body/trim row, and replace only
`Config.SKINS.muddy.pattern` with `surface = "muddy"`. Shared meshes, rarity,
price, and pink swatch colors stay the same. No live assets were uploaded here.
