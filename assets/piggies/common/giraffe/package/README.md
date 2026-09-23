# Giraffe — complete animal asset v1

**Existing coat packaged as an editable Blender scene and complete static FBX. No runtime installation or new skin design.**


## Deliverables

- `giraffe-complete.blend`: six separated meshes, baked texture materials, packed PNGs and review cameras/lights.
- `giraffe-complete.fbx`: complete pig, with body, snout, ears, legs, tail and optional eyes. Textures embedded; external originals are supplied too.
- `giraffe_body_color.png`, `giraffe_trim_color.png`: exact copies of the existing 1024×1024 coats, verified by SHA-256.
- `giraffe-hero.png`, `-front.png`, `-crown.png`, `-spine.png`: rendered from the exported geometry. Neutral studio lighting for inspection; not a live Roblox screenshot.
- `giraffe-asset-report.json`: mesh/triangle counts, source hashes, texture assignments and FBX round-trip measurements.
- `blender/pig/skins/giraffe/giraffe.blend` and `blender/pig/skins/giraffe/make_giraffe_blend.py`: original procedural coat authoring scene and generator, preserved.

## Geometry and scale

The body is **12 studs wide**. Full static envelope: **12.000 W × 17.076 D × 13.974 H**; 20,670 triangles over six meshes. Highest per-mesh triangle count: 7,152. All source mesh edges are manifold. Each vertex agrees with the existing skin scene after uniform scaling within 0.000001 source units; UV coordinates and ear face assignments were preserved before triangulation. Preview subdivision was removed, so export geometry cannot silently multiply in size.

| Mesh | Texture group | Triangles |
| --- | --- | ---: |
| Body | body | 6,352 |
| Snout | trim | 2,486 |
| Ears | trim | 7,152 |
| Legs | trim | 2,032 |
| Tail | trim | 1,592 |
| Eyes | face | 1,056 |

Blender axes: X across, -Y toward the face, Z upward. Origin stays at the body centre, matching the shared pig's attachment frame; the floor is at Z=-6.1200. FBX declares Y up / -Z forward. Reimport into Blender preserved six meshes, triangles, coat UVs and bounds with maximum error **0.000000477** units. Verify Roblox importer scale/orientation on import.

The body, snout, ears, legs and tail keep their original shapes; this preserves the coin slot and vault opening rather than remodelling them by eye. The original textures, procedural scene and shared pig_parts.blend master were not modified. No fur, mane or crest accessories are added by this base-coat package.

## Integration

For the existing game pig, use the shared mesh IDs already in the project and the two coat textures. A separate mesh upload for every animal is unnecessary. The complete FBX is available for standalone import/review and for a pipeline that explicitly wants the full assembled model.

Apply the body sheet to **Body**, and the trim sheet to **Snout, Ears, Legs and Tail**. Use an opaque SurfaceAppearance on SmoothPlastic; these full-colour maps replace the base part tint. They do not require Neon, Glass, emission or alpha animation. Two texture groups are required; assigning the body map to the trim would use the wrong UV islands.

The **Eyes** mesh is optional: omit it when the runtime builds the eyes, so there is only one pair. Sculpted nostril recesses remain without separate black inserts, matching the existing coat preview convention. Game-built coins, vault plate/dial, interactions and existing accessory sets are not included and should remain managed by the game. No animated rig, fur attachment or new gameplay effect is claimed.

Offline checks passed; actual Studio texture assignment, scale, vault alignment, small shop/held-pig readability and mobile performance remain to be checked. Nothing was uploaded or published, and Config/ownership/economy files were not edited.

## Rebuild

From repository root, after the existing skin scene and two baked maps are available:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b -t 4 --python-exit-code 1 --python blender/pig/make/package_animal.py -- --skin giraffe
python blender/pig/make/build_animal_gallery.py
```

If a source coat needs regeneration, follow blender/pig/WORKFLOW.md. Do not rebuild the shared pig master for a packaging task. Scene, render and FBX outputs are regenerable; the packaging script is the durable source.
