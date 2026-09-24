# Beehive Cottage modular interior — first build

The third house interior in this series, following Treehouse and Cardboard Fort. This kit matches the existing **Beehive Cottage** exterior (stable game house ID **`cottage`**) with horizontal honey bands, faceted vault ribs, hexagonal windows with three spokes, wax-colored surfaces and teal door panels.

These are actual model assets. All preview images are rendered from the delivered Roblox geometry. The room entry, exit and six slot transforms exactly match the earlier kits, while the vault, pedestals, windows, hanging fixtures, gate and achievement alcove use Beehive-specific geometry.

## Open and review

- **`beehive-cottage-interior-preview.rbxlx`** — standalone Roblox Studio preview place. Open it as a separate place; Play spawns in the entrance.
- **`beehive-cottage-interior-review.rbxmx`** — static assembled review model with two rooms, six separate pedestals in the first room and three in the second, an open connecting gate and a closed end gate. Includes the empty achievement vestibule. No scripts run automatically.
- **`beehive-cottage-interior-kit.rbxmx`** — reusable templates plus `Builder`. Insert the kit into **ServerStorage**, where the template origins can overlap without rendering in the world.
- **`beehive-cottage-interior.blend`** — editable Blender source. `Assembled Review` shows the full hall; `Reusable Templates` contains the four module collections at their local origins. Isolate one collection when editing a template.
- **`exports/`** — independent `RoomShell.fbx`, `Pedestal.fbx`, `RebirthGate.fbx` and `AchievementVestibule.fbx`. Static geometry is merged by material; moving gate sections remain separate.
- **`preview/`** — hall, achievement alcove, construction cutaway and pedestal close-up renders.

The native Roblox kit includes collision, attachment markers and assembly controls, with no mesh uploads required. FBX files are optional art exports and do not contain the complete collision or behavior setup. The current live game has not been changed; connection to house teleporting, piggy placement, cash collection, saved unlocks and `InteriorService` is still required.

## Independent modules

| Model | Contents |
| --- | --- |
| RoomShell | 38-stud clear width, 32-stud repeat length, 16-stud center aisle and six slot attachments. Honey bands and a six-facet vaulted ceiling; no pedestals baked into the shell. |
| Pedestal | Separate hexagonal honeycomb base, cream display top, teal collection plate, coin medallion and Piggy / CashLabel / Collect attachments. |
| RebirthGate | 32.6-stud-wide, 13.4-stud-high passage; solid jambs and an independent blocking plane. Six teal panel sections stack above the opening, with honeycomb ornaments and a hexagonal lock surround. |
| AchievementVestibule | 14-stud entrance section with a reserved 10 × 6-stud display area, empty shelf, gold border, teal shelf edge and achievement attachment. No achievements or trophies yet. |

Every hexagonal prism is constructed from one central rectangle and four triangular wedges. The rendered geometry, native shape and collision surface agree; the bases are not cylinders with hexagonal artwork over them. The windows are opaque amber daylight recesses to preserve the off-map illusion. Hanging comb fixtures and honey drips remain above the walking area.

Coordinates are in studs, with Roblox +Y up and -Z pointing forward. `RoomShell.Entry` is at its floor origin and `Exit` is 32 studs forward. Align the next room's entry attachment to the previous room's exit; the builder does this automatically even after moving or rotating a hall.

Floors, side walls, entrance walls, gate jambs/end walls and the pedestal support surfaces collide. Decorative vault panels, fixtures and trim do not. The gate uses one separate invisible blocking plane rather than collision on the moving panels. No currency, achievement or piggy content is embedded in the art.

## Use the builder

After inserting the kit into ServerStorage in the existing game, assemble it on the server with the existing progression settings:

```lua
local Config = require(game.ReplicatedStorage.Shared.Config)
local Builder = require(game.ServerStorage.BeehiveCottageInteriorKit.Builder)
local rebirths = 0 -- Read the owner's saved server-side value.

local hall = Builder.build(workspace, CFrame.new(0, 1000, 0), {
    capacity = Config.indoorPlots(rebirths),
    rebirths = rebirths,
    requirement = Config.indoorDoorRebirths,
})

-- After a server-approved progression change:
Builder.setCapacity(hall, Config.indoorPlots(rebirths))
Builder.setRebirths(hall, rebirths)

-- Individual station authoring / integration:
Builder.setSlot(hall, 1, 3, false)
Builder.setSlot(hall, 1, 3, true)
local piggyMount = Builder.piggyMount(hall, 1, 3)

-- Add another shell and gate at the existing end connection:
Builder.appendRoom(hall)
```

The supplied CFrame marks the outer entrance at floor height, with its LookVector pointing inward. `setCapacity` builds the required room prefix and adds/removes entire pedestal models. `setSlot` supports individual control and is idempotent, but a later capacity refresh reapplies contiguous slot unlocking. Arbitrary per-slot ownership needs its own integration policy.

The required rebirth number and gate state come from the same `requirement(roomNumber)` callback. Gates never open onto an unbuilt room. A nil requirement marks the terminal gate; reaching the requirement alone does not create missing rooms. Door poses change immediately in this version; animation can be added using the separate panel models.

Removing a pedestal destroys its child objects. The piggy-placement integration must reconcile a resident piggy before revoking that slot. This kit does not grant purchases, collect cash, store progression or implement achievements.

## Verification and cost

**116 checks passed in Roblox Studio.** These include independent station removal/restoration, no duplicate pedestals on refresh, rotated/transformed connections, requirement label agreement, gate relocking, missing-room protection, closed-gate jamb coverage, physical floor raycasts and avatar-sized aisle clearance. Door clearance checks account for the rotation of every decorative wedge, not just its unrotated dimensions.

Additional raycasts near all six vertices verify that the hexagonal display top is solid and level at 1.68 studs above its pedestal origin. Temporary verification models were removed after testing. `studio-checks.json` records the engine results.

`geometry-checks.json` records finite positive geometry, orthonormal part rotations, exact room/slot compatibility with Treehouse and an analytical hexagonal-prism volume check. Rojo successfully parsed the native models and built the preview place. Live avatar-camera and mobile-performance review remain pending.

The native first room, six pedestals, gate and vestibule total **551 BaseParts**. `part-budget.json` and `mesh-budget.json` record native and exported geometry counts. The native version favors independent editing and upload-free review. Use prefix loading, merged mesh exports and measured profiling before adopting long halls for every player. These counts are not a multiplayer-performance benchmark.

## Rebuild

```powershell
python assets/houses/interiors/beehive-cottage-v1/generate/build_kit.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b -t 6 --python-exit-code 1 --python assets/houses/interiors/beehive-cottage-v1/generate/render_kit.py
rojo build assets/houses/interiors/beehive-cottage-v1/preview.project.json -o assets/houses/interiors/beehive-cottage-v1/beehive-cottage-interior-preview.rbxlx
```

Edit `generate/geometry.py` for the Beehive palette and geometry. `generate/build_kit.py` provides the shared primitive helpers and writes the native models and `geometry.json`. The Blender renderer reads these deliverables. `Builder.luau` contains the assembly and unlock controls embedded in the generated kit. The package is self-contained and does not require another house's source folder to rebuild.
