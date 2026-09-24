# Spacious Treehouse comparison — v2

A separate size study of the existing Treehouse interior. The room has roughly 44% more floor area, taller walls and larger display platforms. Original house kits and live gameplay have not been replaced.

## Compare in Studio

Open `treehouse-interior-preview.rbxlx` for the larger room, or `original-preview.rbxlx` for the original dimensions. Press Play to walk around. Both places start the normal follow camera at the same distance with a 70-degree field of view. A removable block avatar provides scale in Edit mode and disappears locally when Play starts. The static review door stays closed; the kit's Builder supplies functional rebirth gating when assembled.

The matching images `preview/hall.png` and `preview/original-hall.png` use the exact same camera and approximately six-stud reference avatar. They render the delivered geometry in Blender; lighting differs from the live game's lighting. The enlarged geometry was also inspected in a temporary Studio client scene, then removed.

| Feature | Original | Spacious comparison |
| --- | --- | --- |
| Clear room width | 38 studs | 46 studs |
| Repeat length | 32 studs | 38 studs |
| Roof ridge height | 22.55 studs | 28 studs |
| Reserved central aisle | 16 studs | 20 studs minimum |
| Pedestal foot diameter | 6.1 studs | 8 studs |
| Piggy attachment height | 1.69 studs | 1.69 studs |
| Collection button | 2.8 × 1.05 studs | Same size |
| Pedestals per room | 6 | 6 |

There are 21.45 studs between the inner edges of the collection plates. Slot centers are at X ±15.5 and forward distances 7.125, 19 and 30.875. The vestibule remains 14 studs long, with a blank achievement panel. Door clear opening is approximately 39.46 × 16.64 studs. Room connections remain `Root.Entry` and `Root.Exit`; v2 is a different footprint from the v1 kits and should use its own matching shell and gate.

## Editable native kit

Insert `treehouse-interior-kit.rbxmx` into ServerStorage. It contains `TreehouseSpaciousInteriorKit`, four independent templates and `Builder`. The native parts are the easiest version for replacing buttons in Studio. Each pedestal has separate `Collect.CollectionPlate` and `Collect.CollectionInset` parts. Remove these and place your own buttons at the `Root.Collect` attachment. `Root.Piggy` remains the piggy placement attachment. None of these visual buttons run currency logic.

```lua
local Builder = require(game.ServerStorage.TreehouseSpaciousInteriorKit.Builder)
local hall = Builder.build(workspace, CFrame.new(0, 0, 0), {
    capacity = 6,
    rebirths = 0,
    requirement = function(roomNumber)
        return (roomNumber - 1) * 2 -- Example only; supply the game's real rules.
    end,
})
Builder.setCapacity(hall, 12) -- Appends the next matching room.
Builder.setRebirths(hall, 2) -- Opens the first gate when the next room exists.
Builder.setSlot(hall, 1, 3, false) -- Removes just this pedestal.
```

The entrance CFrame is floor height, looking inward. `Builder.appendRoom(hall)` aligns another shell through its attachments. Capacity refreshes set contiguous unlocked slots and supersede manual slot changes. Removing a pedestal also removes its children, so relocate a resident piggy first. Gates remain closed when there is no built room beyond them. The final requirement must come from server-owned progression rules. Piggy placement, currency, saves and teleport integration remain separate work.

`treehouse-interior-review.rbxmx` contains one assembled room, six pedestals, a gate, vestibule and scale avatar. It has no running scripts. The preview-only camera LocalScript is confined to the standalone preview place.

## Sources and verification

- `treehouse-interior.blend`: assembled review and reusable template scenes.
- `exports/`: separate FBX modules; material groups are merged, so use the native kit for per-part button edits.
- `generate/build_kit.py`, `resize.py`: native geometry generation and independent architectural/pedestal sizing. Diagonal structural beams keep orthonormal transforms.
- `generate/original-geometry.json`: frozen original dimensions for reproducible comparison.
- `studio-checks.json`: all 96 checks passed, including room extension, collisions, independently removable slots, rebirth locks and raised door clearance.
- `geometry-checks.json`: finite dimensions, orthonormal rotations, button sizes, aisle width and package validation.

Native part count is unchanged: 263 per shell, 18 per pedestal, 57 per gate and 93 per vestibule; 521 for one furnished room with vestibule and gate, excluding the review avatar. This is not a multiplayer performance benchmark.

Rebuild from the repository root:

```powershell
python assets/houses/interiors/treehouse-spacious-v2/generate/build_kit.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b -t 6 --python-exit-code 1 --python assets/houses/interiors/treehouse-spacious-v2/generate/render_kit.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b -t 6 --python-exit-code 1 --python assets/houses/interiors/treehouse-spacious-v2/generate/render_kit.py -- --original
rojo build assets/houses/interiors/treehouse-spacious-v2/preview.project.json -o assets/houses/interiors/treehouse-spacious-v2/treehouse-interior-preview.rbxlx
rojo build assets/houses/interiors/treehouse-spacious-v2/original-preview.project.json -o assets/houses/interiors/treehouse-spacious-v2/original-preview.rbxlx
python assets/houses/interiors/treehouse-spacious-v2/generate/package.py
```
