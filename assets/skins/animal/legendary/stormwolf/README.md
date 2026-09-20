# Storm Wolf — layout revision

The existing Storm Wolf has a hollow chamber and a flush rear vault opening. Its original tail is separated at the root and projects outward just above the opening, with a low 5-degree lift. There is no protruding collar. The mane stays continuous over the coin deposit position, with no visible slot or rim, following the user's review. All six old blue bolt meshes are removed and replaced with eight long, chunky, jagged strikes and eight substantial tapered forks. The largest roots are 0.60 studs across. Painted cyan lightning has a separate emission mask and pulses in sync; the texture pattern stays fixed.

The painted coat and original sources remain unchanged. The retained exterior UV loops were checked against their source values with maximum error 0.000000000. A tiny original mesh pinhole was closed. The rear opening and the largest reference dial plate both passed clearance sampling. Body and Tail are closed manifold meshes.

## Files

- `stormwolf-complete.blend`: packed coat and glow mask, review stage, and a 60-frame lightning preview with stepped visibility and emission, including animated body glow. Meshes are scaled to studs.
- `stormwolf-complete.fbx`: 9 separate static meshes with embedded coat; 23,516 triangles total. Largest mesh is 19,672 triangles.
- `stormwolf-layout.blend`: native editable geometry, before review staging and the 6× stud scale.
- `stormwolf_body_color.png`: the original coat, unchanged. Body and Tail share this sheet; interior and closed root faces use flat materials.
- `stormwolf_body_emissive.png`: grayscale 1024px mask selecting cyan markings on the original UVs. `body-glow-checks.json` records its hash and coverage. The dark coat and grey mane stay non-emissive.
- Six review renders, `index.html` and `stormwolf-layout-checks.json`.
- `stormwolf-lightning.mp4`: a 30 fps motion preview showing two cycles. `lightning-preview-checks.json` records timing; flashes last one or two frames (33–67 ms), with staggered double strikes and fully dark gaps.
- `StormWolfLightning.luau`: client-side Studio playback helper, with the same timing as `lightning-animation.json`.

## Integration

This legendary uses its own Body mesh and separated Tail, plus six new lightning groups and the existing glowing eyes. Do not substitute the common pig's body or UVs. The Blender scene retains `VaultMount` and `CoinSlotMount` reference empties; these are not functional game parts and are omitted from the FBX.

Native axes are X across, -Y toward the face, Z up. FBX declares -Z forward and Y up. The complete export is 6× the native scene. Reimport preserved mesh count, triangles, body/tail UV presence and bounds (maximum error 0.000000954). The vault bore radius is 1.43 studs on the shared rear dial axis. The wolf's body surface differs from the common mesh: fit the runtime vault plate to the flush rim during Studio integration instead of adding a visible neck to bridge the gap. Check the plate at all lock tiers. The coin anchor remains under the mane; no visible slot is intended.

Assign the existing coat to Body and Tail; use the flat material colors for the cavity and sealed tail root. Use the six separate Lightning_p0–p5 groups for glow and flicker, and Bolts_eyes for the eyes. FBX geometry is static; the Blender timeline is retained in the blend file. To reproduce the flicker in Studio, import the six lightning meshes with their exact names, install the supplied helper as a ModuleScript, and call `local stop = require(module).start(stormWolfModel)` from a client cosmetic controller. Call `stop()` when changing skins; destruction also cleans up. The helper drives Neon color and transparency in hard steps, with no fading tween. Tune the game's existing bloom/lighting during Studio review. Do not duplicate the eyes with game-built eyes.

For the painted lightning, assign `stormwolf_body_emissive.png` to the Body and Tail SurfaceAppearances' EmissiveMaskContent in Studio, alongside the original color map. Add the boolean attribute `StormWolfBodyGlow = true` to each prepared SurfaceAppearance. The helper then animates EmissiveStrength from 0.35 between strikes to 5.0 at the strongest strike, with white EmissiveTint. Only mark surfaces after assigning the mask, to keep the whole body from glowing. This changes brightness, not the painted pattern's position. Mask assignment is an editor/import step; the helper changes only runtime strength and tint and restores their previous values on cleanup. Reference: https://create.roblox.com/docs/reference/engine/classes/SurfaceAppearance

No runtime, economy, crate catalogue, uploads or publishing changes were made. Studio vault seating, material/glow, animation and mobile review remain pending.

## Rebuild

Run `blender/pig/make/build_stormwolf_layout.py` in background Blender, then `render_stormwolf_lightning.py` in Blender, then `build_legendary_gallery.py` in Python. `--draft` on the model builder creates only the native scene and three quick renders, not a complete package. Lightning geometry, schedules, and the generated Studio helper are authored by `stormwolf_lightning.py` and its Luau template; `stormwolf_body_glow.py` bakes the mask and keys body emission. The builder asserts that the original Storm Wolf source, coat, bolt source and common master retain their hashes.
