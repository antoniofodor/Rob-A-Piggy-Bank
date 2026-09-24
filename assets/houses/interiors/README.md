# Modular house interiors

**Current game defaults:** [catalogue-v4](catalogue-v4/README.md) supplies all 18 permanent themes. Every successive house tier adds 2 studs of width and 1 stud of ceiling height, starting at 60 × 40 × 32. Room length stays at 40 studs, with pedestal rows at 8, 20 and 32 studs. All retain six separate pedestals and routes for dodging around them. [Browse the gallery](catalogue-v4/gallery.html). `default.project.json` maps these kits into the game; v1, spacious-v2 and wide-default-v3 are earlier versions.

Standalone art kits built from the approved **A Home That Grows** concept. Each contains editable Blender source, separate FBX modules, an upload-free native Roblox kit, a two-room review model, a Studio preview place and assembly/unlock controls.

| House | Package and instructions | Actual geometry preview |
| --- | --- | --- |
| Cardboard Fort | [Kit](cardboard-fort-v1/README.md) | [Hall](cardboard-fort-v1/preview/hall.png) |
| Beehive Cottage | [Kit](beehive-cottage-v1/README.md) | [Hall](beehive-cottage-v1/preview/hall.png) |
| Treehouse | [Kit](treehouse-v1/README.md) | [Hall](treehouse-v1/preview/hall.png) |

All three use a 38-stud clear room width, a 32-stud repeat length, a 16-stud center aisle and six independent pedestal slots. Their room entry, exit and six slot transforms match. Each kit includes an entrance vestibule with an empty achievement area and a separate rebirth gate. The geometry and material treatment vary by house.

The game selects authored themes through `Services/ThemedInterior`. The v4 catalogue is mapped as the default; older per-house instructions record their original standalone scope. Changing the geometry does not enable visitor entry or implement indoor robbery rules.

All permanent houses now have interiors in catalogue-v4. Treehouse was created first as the initial template; the earlier kits below document that work.

A separate [Spacious Treehouse comparison](treehouse-spacious-v2/README.md) tests a 46 × 38-stud room with a 28-stud ridge, six larger removable pedestals and matching original/enlarged camera views. Its room footprint differs from the three v1 kits; it has not been applied to other houses.
