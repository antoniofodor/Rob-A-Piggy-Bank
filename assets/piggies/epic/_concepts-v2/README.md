# Animal epics — approved concept and Blender revision

The four-skin concept was approved in the asset session on 2026-09-22.
`epic-concepts.png` is the concept art. The individual
`preview/*-epic-v2-*.png` files are renders of the actual meshes.

| Skin | Executed design | Existing game aura |
| --- | --- | --- |
| Hedgehog | 87 layered chestnut quills; cream face and paws | fireflies |
| Lion | full mane draft needs manual refinement; editable leaf-tuft workbench supplied without a foundation shell | sunburst |
| Storm Stone | low faceted plates, narrow cyan seams, short lightning, inset glowing eyes | storm |
| Peacock | nine solid eyed feathers and a three-feather crest | prism |

Each skin owns its files in `assets/piggies/epic/<key>/`:

- `generate/make_<key>_epic_v2.py`: reproducible entry point.
- `source/<key>-epic-v2.blend`: packed, editable scene at the original two-unit body width.
- `sheets/<key>-epic-v2-{body,trim,palette}.png`: new coat and accessory colors.
- `preview/<key>-epic-v2-{hero,front,back,crown}.png`: four review angles.
- `package/epic-v2/<key>-epic-v2-complete.fbx`: complete static pig, 12 studs across its body.
- `package/epic-v2/<key>-epic-v2-accessories.fbx`: only the new silhouette/effect meshes.
- `package/epic-v2/asset-report.json`: mesh counts, material roles, measured offsets,
  geometry/UV preservation checks, export hashes and FBX round-trip bounds checks.

The builder is `blender/pig/make/build_epic_v2.py`. It appends the existing
closed-back pig, preserves its base vertices/topology/UVs, authors the new
accessories, bakes coats from 3D coordinates, and checks the exported FBX by
importing it again. Accessory meshes are closed and individually below 20,000
triangles. The full pig consists of multiple meshes; its total is larger.
Each accessory uses a compact palette texture, except the separate emitting
Storm Stone objects. All textures are embedded in the FBX and packed in the blend.

THE LION WAS DELETED ON 2026-09-23 (designer call) and everything this
section used to describe went with it -- the `Config.SKINS.lion` row, its coat
pack, the `lionmane` fur set and the whole `../lion/` folder, workbench and
mane drafts included. Its mane was an unfinished draft that had not been
accepted, so nothing accepted was lost. Do not follow a link into `../lion/`;
there is nothing there.

Rebuild through the running Blender MCP add-on:

```powershell
python tools/blender_mcp_call.py --timeout 600 --file assets/piggies/epic/hedgehog/generate/make_hedgehog_epic_v2.py
```

Replace `hedgehog` in that command to build another skin. This adds/replaces only
the revision's own scene. The user's original unsaved Blender scene was saved
as `session-before-epic-v2.blend` before authoring and remains separate.

## Roblox handoff

Hedgehog, Storm Stone, and Peacock were uploaded on 2026-09-23. Their accessory
models and body/trim images are approved, and all nine coat/palette textures load
successfully in Studio. Lion was excluded from this upload.

**HEDGEHOG AND PEACOCK WERE INSTALLED ON 2026-09-23**, later the same day: two
`SurfacePacks` pairs, two `Config.SURFACE_PACKS` rows, `surface`/`authoredCoat`
on both `Config.SKINS` rows, and their accessory sets in
`Config.SKIN_ACCESSORIES` / `SKIN_ACCESSORY_MODELS`. Step 4 below was done in
the same change -- hedgehog's `pattern = { kind = "shards" }` and peacock's
`fx = "peacock"` are off their rows, so no pig draws both.

**STORM STONE WAS NOT, and is not going to be.** The skin was retired on the
designer's call on 2026-09-23 -- there is no Storm Stone, the skin is
Stormcaller -- so its three uploads stay on the account with nothing reading
them. `assets/piggies/BATCH-FOLDERS.md` records why the folder is kept.

| Skin | Accessory model | Body image | Trim image |
| --- | --- | --- | --- |
| Hedgehog | 72540328543121 | 127860745207025 | 88556242869890 |
| Storm Stone | 118154021021392 | 107757367619801 | 86186391437693 |
| Peacock | 97941702099263 | 119377976943225 | 114128782594906 |

Each uploaded skin has a `roblox-uploads.json` receipt with source hashes and
moderation status. Its `package/epic-v2/mesh-import.json` records the individual
mesh and palette IDs returned by Roblox, plus canonical placement values.
The Open Cloud FBX importer produced mesh sizes 100 times the intended size and
rotated their local geometry 180 degrees around Y relative to the game seat.
Use the recorded canonical sizes/offsets and Y rotation when installing them;
do not use the raw imported model transforms.

1. Use the uploaded accessory IDs above for the three completed uploads. For
   future revisions, import the accessories FBX, retaining mesh names.
   The complete FBX is also available for standalone inspection. Avoid uploading
   duplicate Body/Snout/Ears/Legs/Tail meshes when using the shared piggy system.
2. Capture the imported per-part mesh IDs with `tools/capture_mesh_ids.luau`.
   `asset-report.json` contains sizes and offsets in the game's seat frame:
   `(Blender X * 6, Blender Z * 6 + 6.62, -Blender Y * 6)`.
3. Use the new body/trim sheets as ColorMaps on the existing closed-back body
   and trim UVs. Keep the accessory palette on the opaque accessory meshes.
   Storm Stone's GlowSeams, Lightning and GlowEyes use cyan Neon; the stone
   mesh itself stays opaque SmoothPlastic.
4. Replace the old Hedgehog/Storm Stone shard builders, Lion's existing fur
   set and Peacock's old rod/disc fan with the imported accessory sets. Do not
   draw both old and new accessories. Preserve their existing rarity, scale,
   aura, accessory-slot handling, and the shared body's animations.
5. The exported dark eyes are optional if the game creates its own. For Storm
   Stone, retain dark outer eyes and install GlowEyes as the smaller cyan inset.
   Check the lineup on a pedestal, in the crate viewport and while carried.

Particle auras and motion are game effects and are not baked into these static
FBXs or artificially painted into the Blender review images.
