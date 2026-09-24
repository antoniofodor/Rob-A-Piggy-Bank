# Storm Wolf — repaired back and relocated tail

The old rear vault cut has been removed. The back uses the original painted surface, with a small local repair at the former tail attachment. The original tail is now seated over that repair with a slight underlap; its shape and UVs are preserved. The tail lightning follows the relocated tuft.

## Current files

- `stormwolf-complete.blend`: complete editable model and lightning animation.
- `stormwolf-complete.fbx` / `stormwolf-tail-seated.fbx`: current complete model for Studio import.
- `stormwolf-layout.blend`: current model in native coordinates.
- `stormwolf-body-closed.fbx`: repaired Body only; this file does not include the tail relocation.
- `stormwolf-side.png` and `stormwolf-rear.png`: latest repair and tail previews.
- `stormwolf-layout-checks.json`: geometry, source UV, surface coverage and FBX checks.

## Validation

Body: 17,652 triangles, zero non-manifold edges. Total: 21,496 triangles across 9 meshes. All 360 rays through the former opening hit the closed back. Retained coat UVs outside the small attachment repair have zero measured drift. The complete FBX reimport bounds error is 0.000000954 studs.

## Studio handoff

Uploaded model **114603364441693**, approved by Roblox. Config.LEGENDARIES.stormwolf now uses the repaired Body, relocated Tail and matching Lightning_p4/p5 mesh IDs and measured bounds. The change is synced into Studio. The existing color/emission maps, other five meshes and runtime scale are retained.

Verified in the Rob A Piggy Bank Studio session on both server and client. The real LegendaryModel builder loaded all nine parts at full size and 20% miniature scale, using the original coat. See `../closed-back-roblox-upload.json`, `../closed-back-imported-meshes.json`, and `../closed-back-studio-checks.json` for upload receipts, measured rows and checks. This task did not publish the place.

The existing lightning video and other static views are from the earlier layout; use the side/rear images above for the current tail placement.

## Rebuild

Run `blender/pig/make/build_stormwolf_layout.py` in Blender. `--no-render` exports without refreshing pictures; `--fbx-name` selects a fresh export filename. The builder retains the original third-party source and painted sheet and checks their hashes.
