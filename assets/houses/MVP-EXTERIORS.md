# Permanent Blender house inventory — September 17

**18/18 permanent houses have distinct Blender models. Seasonal Gingerbread is excluded.**

[Open the complete model gallery](mvp-exteriors.html).

Count reconciliation: 3 earlier models (Mushroom, Treehouse, Gloop) + 9 earlier permanent exteriors + 6 legacy rebuilds = 18. The nine include earned Golden Piggy; the free starter is among the six rebuilds. The earlier ten-model batch included one seasonal Gingerbread, which does not count toward 18.

| Stable ID | Model design | Blender | Meshes | Triangles | Batch |
| --- | --- | --- | ---: | ---: | --- |
| `shack` | Cardboard Fort | [source](cardboard-fort-v1/cardboard-fort.blend) | 18 | 3,932 | new legacy rebuild |
| `cottage` | Beehive Cottage | [source](beehive-cottage-v1/beehive-cottage.blend) | 18 | 13,432 | new legacy rebuild |
| `townhouse` | Wonky Townhouse | [source](wonky-townhouse-v1/wonky-townhouse.blend) | 30 | 10,480 | new legacy rebuild |
| `mushroom` | Toadstool Cottage | [source](toadstool-cottage-v1/toadstool-cottage.blend) | 86 | 5,280 | earlier model |
| `villa` | Fairy Lantern Cottage | [source](fairy-lantern-cottage-v1/fairy-lantern-cottage.blend) | 30 | 12,364 | earlier model |
| `treehouse` | The Treehouse | [source](treehouse-v2/treehouse.blend) | 63 | 29,688 | earlier model |
| `manor` | Haunted Manor | [source](haunted-manor-v1/haunted-manor.blend) | 44 | 17,386 | new legacy rebuild |
| `slime` | Gloop House | [source](gloop-house-v2/gloop-house.blend) | 17 | 34,980 | earlier model |
| `modern` | Fishbowl House | [source](fishbowl-house-v1/fishbowl-house.blend) | 24 | 18,392 | earlier model |
| `neontower` | Neon Tower | [source](neon-tower-v1/neon-tower.blend) | 50 | 14,356 | new legacy rebuild |
| `crystal` | Crystal Spire | [source](crystal-spire-v1/crystal-spire.blend) | 21 | 2,752 | earlier model |
| `palace` | Ice Palace | [source](ice-palace-v1/ice-palace.blend) | 34 | 5,904 | earlier model |
| `skycastle` | Sky Castle | [source](sky-castle-v1/sky-castle.blend) | 55 | 8,280 | new legacy rebuild |
| `galleon` | The Beached Galleon | [source](beached-galleon-v1/beached-galleon.blend) | 37 | 14,276 | earlier model |
| `portal` | Portal House | [source](portal-house-v1/portal-house.blend) | 56 | 13,748 | earlier model |
| `thundercloud` | Thundercloud Fortress | [source](thundercloud-fortress-v1/thundercloud-fortress.blend) | 44 | 6,942 | earlier model |
| `void` | The Void | [source](the-void-v1/the-void.blend) | 52 | 18,362 | earlier model |
| `goldenpig` | The Golden Piggy | [source](golden-piggy-v1/golden-piggy.blend) | 27 | 5,512 | earlier model |

The six newly completed assets are Cardboard Fort (shack), Beehive Cottage (cottage), Wonky Townhouse (townhouse), Haunted Manor (manor), Neon Tower and Sky Castle. These replace the remaining original models as art deliverables, while the original runtime builders remain in place until integration. The first four follow the written optional directions that the user has now authorised building; tower/castle preserve the existing design vocabulary. No dedicated concept bitmaps were found for these six.

Each new folder contains .blend, material-split FBX, grouped OBJ/MTL, three renders, topology and FBX round-trip reports, plus named decorative effect specifications. All six pass offline manifold, per-mesh triangle-limit, static 60×57 footprint and FBX bounds checks. They have closed decorative shells; no interiors, gameplay logic, collision proxies or avatar route tests. Their companion RBXMX contains an invisible origin root only.

Older packages keep their own validation and integration history. Mushroom uses its original visual FBX/package report; Treehouse v2 and Gloop v2 use their existing material-split FBXs. This inventory does not claim that all 18 are installed or approved in Studio. Verify plot fit, scale, collision, camera, motion, lighting and mobile performance during integration.

Runtime IDs, names, economy and ownership were not edited. The registry still carries the seasonal candy slot, so its entry count and completion grant need separate reconciliation; do not infer live catalogue changes from this art inventory. Interiors remain deferred. Seasonal files were not rebuilt or modified.

Rebuild the new six with `assets/houses/tools/build_legacy_exteriors.py -- <id>` in Blender; then `export_house_roblox.py -- <id> 1`. Regenerate this complete inventory using **build_permanent_handoff.py**. Older gallery generators cover partial historical batches. FBXs are git-ignored and rebuildable; .blend/OBJ/MTL and scripts preserve the assets.
