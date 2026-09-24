# House asset library

All house models, exports, previews, concepts, design documents and build tools live here.

**[Browse the walk-in gallery](walk-in.html)** · [Catalogue plan](docs/HOUSE-CATALOGUE-PLAN.md) · [Interior brief](docs/HOUSE-INTERIOR-BRIEF.md)

The current revisions below have empty walk-in interiors and automatic swing-door parts. Your approved Studio exterior sizes are baked into their geometry. Fresh FBX imports are required; these packages have not replaced the live templates. Each includes a Studio helper that applies scale, collision, door pivots and material transparency.

## Models

Each folder keeps its editable Blender source, Roblox export, renders and import instructions together. Use the latest revision listed below. Model availability does not mean the model is already installed in Studio; check its import handoff.

| House | Files and import notes | Blender source | Roblox export |
| --- | --- | --- | --- |
| Cardboard Fort | [v2](cardboard-fort-v2/README.md) | [Blender](cardboard-fort-v2/cardboard-fort.blend) | [FBX](cardboard-fort-v2/cardboard-fort-roblox.fbx) |
| Beehive Cottage | [v2](beehive-cottage-v2/README.md) | [Blender](beehive-cottage-v2/beehive-cottage.blend) | [FBX](beehive-cottage-v2/beehive-cottage-roblox.fbx) |
| Wonky Townhouse | [v2](wonky-townhouse-v2/README.md) | [Blender](wonky-townhouse-v2/wonky-townhouse.blend) | [FBX](wonky-townhouse-v2/wonky-townhouse-roblox.fbx) |
| Toadstool Cottage | [v2](toadstool-cottage-v2/README.md) | [Blender](toadstool-cottage-v2/toadstool-cottage.blend) | [FBX](toadstool-cottage-v2/toadstool-cottage-roblox.fbx) |
| Fairy Lantern Cottage | [v2](fairy-lantern-cottage-v2/README.md) | [Blender](fairy-lantern-cottage-v2/fairy-lantern-cottage.blend) | [FBX](fairy-lantern-cottage-v2/fairy-lantern-cottage-roblox.fbx) |
| Treehouse | [v3](treehouse-v3/README.md) | [Blender](treehouse-v3/treehouse.blend) | [FBX](treehouse-v3/treehouse-roblox.fbx) |
| Haunted Manor | [v2](haunted-manor-v2/README.md) | [Blender](haunted-manor-v2/haunted-manor.blend) | [FBX](haunted-manor-v2/haunted-manor-roblox.fbx) |
| Gloop House | [v3](gloop-house-v3/README.md) | [Blender](gloop-house-v3/gloop-house.blend) | [FBX](gloop-house-v3/gloop-house-roblox.fbx) |
| Fishbowl House | [v2](fishbowl-house-v2/README.md) | [Blender](fishbowl-house-v2/fishbowl-house.blend) | [FBX](fishbowl-house-v2/fishbowl-house-roblox.fbx) |
| Neon Tower | [v2](neon-tower-v2/README.md) | [Blender](neon-tower-v2/neon-tower.blend) | [FBX](neon-tower-v2/neon-tower-roblox.fbx) |
| Crystal Spire | [v2](crystal-spire-v2/README.md) | [Blender](crystal-spire-v2/crystal-spire.blend) | [FBX](crystal-spire-v2/crystal-spire-roblox.fbx) |
| Ice Palace | [v2](ice-palace-v2/README.md) | [Blender](ice-palace-v2/ice-palace.blend) | [FBX](ice-palace-v2/ice-palace-roblox.fbx) |
| Sky Castle | [v2](sky-castle-v2/README.md) | [Blender](sky-castle-v2/sky-castle.blend) | [FBX](sky-castle-v2/sky-castle-roblox.fbx) |
| Beached Galleon | [v2](beached-galleon-v2/README.md) | [Blender](beached-galleon-v2/beached-galleon.blend) | [FBX](beached-galleon-v2/beached-galleon-roblox.fbx) |
| Portal House | [v2](portal-house-v2/README.md) | [Blender](portal-house-v2/portal-house.blend) | [FBX](portal-house-v2/portal-house-roblox.fbx) |
| Thundercloud Fortress | [v2](thundercloud-fortress-v2/README.md) | [Blender](thundercloud-fortress-v2/thundercloud-fortress.blend) | [FBX](thundercloud-fortress-v2/thundercloud-fortress-roblox.fbx) |
| The Void | [v2](the-void-v2/README.md) | [Blender](the-void-v2/the-void.blend) | [FBX](the-void-v2/the-void-roblox.fbx) |
| Golden Piggy — earned | [v2](golden-piggy-v2/README.md) | [Blender](golden-piggy-v2/golden-piggy.blend) | [FBX](golden-piggy-v2/golden-piggy-roblox.fbx) |

**Seasonal only:** [Gingerbread Manor](gingerbread-manor-seasonal-v1/README.md), which is not part of the permanent catalogue. Superseded exterior packages are not kept: each house has exactly one folder, at the revision listed above, and the dead uploads from the earlier ones are ledgered in [docs/ORPHANED-UPLOADS.md](../../docs/ORPHANED-UPLOADS.md).

## Supporting files

- `interiors/`: the modular house interiors. **`interiors/catalogue-v4/` is the only thing in `assets/` the build reads** -- `default.project.json` maps its eighteen `*-interior-kit.rbxmx` files into `ServerStorage`, one per house, and `Services/ThemedInterior` clones them at run time. `v1`, `spacious-v2` and `wide-default-v3` beside it are earlier versions; see [interiors/README.md](interiors/README.md).
- `design/`: reference images, design galleries, interior blockouts and display-station studies. The `concepts/` folder this line used to list is gone; the concept art that survived is under `design/`.
- `docs/`: catalogue, tiers, interiors and trophy-display plans.
- `tools/`: Blender builders, export tools, checks and Studio import helpers.
- `mvp-exterior-manifest.json`: inventory of the 18 permanent models.

## Names and rebuilding

Asset filenames match their house names: for example, `fishbowl-house-v1/fishbowl-house.blend` and `fishbowl-house-roblox.fbx`. Saved-game IDs remain unchanged (`modern`, `slime`, etc.). [house_paths.py](tools/house_paths.py) maps those IDs to readable asset names. Build/export commands continue to accept the stable IDs documented in each house's handoff.

From the repository root, regenerate the complete gallery with:

```powershell
python assets/houses/tools/build_permanent_handoff.py
```

FBX exports are local, generated files ignored by Git. Blender sources and build scripts are retained to rebuild exports on another machine. Runtime house templates remain under `src/ReplicatedStorage/Shared/HouseTemplates/` so Rojo can sync them.
