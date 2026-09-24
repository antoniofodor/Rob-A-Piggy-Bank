# Cardboard Fort modular interior — first build

The next interior in the approved house concept series. It matches the existing Cardboard Fort exterior (stable game house ID **`shack`**) with warm cardboard sheets, cream packing tape, folded window flaps, square windows, carton pedestals and the red sun doodle.

This is actual model geometry, not generated concept artwork. The room connections and all six slot transforms match the Treehouse kit exactly. Each house has its own complete art package and can grow using the same room layout.

## Open the result

- **`cardboard-fort-interior-preview.rbxlx`** — standalone Roblox Studio preview place. Open as a separate place and Play to spawn in the entrance.
- **`cardboard-fort-interior-review.rbxmx`** — assembled two-room model: six separate pedestals in room one, three in room two, an open connecting gate, a closed final gate, and the achievement vestibule. This is a static review assembly, with no auto-running scripts.
- **`cardboard-fort-interior-kit.rbxmx`** — reusable templates and the `Builder` ModuleScript. Insert the kit into **ServerStorage** so the overlapping template origins do not appear in the world.
- **`cardboard-fort-interior.blend`** — editable Blender source. `Assembled Review` shows the complete hall; `Reusable Templates` contains the four module collections at their local origins. Isolate a collection to edit one template.
- **`exports/`** — separate `RoomShell.fbx`, `Pedestal.fbx`, `RebirthGate.fbx` and `AchievementVestibule.fbx`. Static art is merged by material; moving door sections stay separate. These are optional art exports. Native RBXMX is the complete version with collision, attachments and builder, requiring no mesh uploads.
- **`preview/`** — renders of the delivered geometry: hall, achievement alcove, construction cutaway and pedestal close-up.

The current game's interiors and economy have not been replaced. Live integration with piggy placement, cash collection, house entry transitions and `InteriorService` is still required. FBX alone does not include the native kit's collision, attachments or behavior.

## Modular layout

| Piece | Contents |
| --- | --- |
| RoomShell | 38-stud clear width, 32-stud repeat length, 16-stud center aisle and six invisible slot anchors. No pedestals merged into the shell. |
| Pedestal | A separate taped carton with cream display top, collection plate, coin medallion and Piggy / CashLabel / Collect attachments. |
| RebirthGate | 32.6-stud clear width and 13.4-stud clear height, solid jambs and a separate blocking plane. Six cardboard sections stack above the opening when unlocked. |
| AchievementVestibule | 14-stud entrance section with an empty 10 × 6-stud display area, taped paper backing, folded shelf and dedicated achievement attachment. |

Models are authored in studs. Roblox +Y is up and -Z points down the hall. Each room's `Entry` is at floor height at its origin; `Exit` is 32 studs forward. The builder aligns attachments rather than assuming world coordinates, so moved or rotated halls can still be extended.

The square windows are opaque daylight recesses, preserving the off-map interior illusion. Wall and roof details stay clear of the walkway. Floors, side walls, entrance walls and gate structure have native collision; decorative sloping ceiling planes do not. All parts are anchored. No achievements, resident piggies or currency interactions are built into the art.

## Assembly and unlocks

In the existing game, place the kit in ServerStorage, then use it from the server with the existing progression configuration:

```lua
local Config = require(game.ReplicatedStorage.Shared.Config)
local Builder = require(game.ServerStorage.CardboardFortInteriorKit.Builder)
local rebirths = 0 -- Use the owner's server-side saved value.

local hall = Builder.build(workspace, CFrame.new(0, 1000, 0), {
    capacity = Config.indoorPlots(rebirths),
    rebirths = rebirths,
    requirement = Config.indoorDoorRebirths,
})

-- When progression changes:
Builder.setCapacity(hall, Config.indoorPlots(rebirths))
Builder.setRebirths(hall, rebirths)

-- Individual slot authoring / integration:
Builder.setSlot(hall, 1, 3, false)
Builder.setSlot(hall, 1, 3, true)
local piggyMount = Builder.piggyMount(hall, 1, 3)

-- Extend the hall at its existing connection:
Builder.appendRoom(hall)
```

The build CFrame marks the outer entrance at floor height, with its LookVector pointing inward. `setCapacity` builds the room prefix and inserts/removes whole pedestal models. Each room supports six slots. `setSlot` is idempotent; `setCapacity` later reapplies contiguous unlocking, so arbitrary per-slot ownership needs its own integration policy.

Gate labels and open states use the same supplied `requirement(roomNumber)` callback. They never open onto an unbuilt room, even if the rebirth count is met. A nil requirement marks the terminal gate. Capacity and rebirths remain separate. Gate poses change immediately in this version; animation can be added without changing the panel models.

Removing a pedestal destroys that model and its child objects. The eventual piggy-placement integration must reconcile/remove a resident piggy before revoking its slot. This builder does not grant purchases, store progression, award achievements or collect money.

## Verification

**90 checks passed in Roblox Studio.** These cover six independent stations; remove/restore without duplicates; translated and rotated connections; gate requirement labels; missing-room protection; panel clearance; continuous floor raycasts; avatar-sized walkway clearance; and closed gate/jamb coverage. Temporary verification objects were removed afterward.

`studio-checks.json` contains the engine results. `geometry-checks.json` records that the entry, exit and all six slot transforms exactly match Treehouse, every part has finite positive dimensions and an orthonormal rotation, and no Treehouse canopy or tree posts remain. Rojo successfully parsed the native models and built the preview place.

The native first room, six pedestals, its gate and the vestibule total **409 BaseParts**, versus 521 for the Treehouse first-room kit. This is an editable review build, not a measured mobile-performance result. `part-budget.json` and `mesh-budget.json` record the native and merged export counts. Use prefix loading and profile the full multiplayer scene before adopting maximum-length halls everywhere. Live player-camera and mobile review remain pending.

## Rebuild

```powershell
python assets/houses/interiors/cardboard-fort-v1/generate/build_kit.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b -t 6 --python-exit-code 1 --python assets/houses/interiors/cardboard-fort-v1/generate/render_kit.py
rojo build assets/houses/interiors/cardboard-fort-v1/preview.project.json -o assets/houses/interiors/cardboard-fort-v1/cardboard-fort-interior-preview.rbxlx
```

Edit **`generate/geometry.py`** for the house-specific art and palette. `generate/build_kit.py` provides the primitive helpers, writes both Roblox models and emits `geometry.json`. The Blender renderer reads the delivered geometry and assembled RBXMX. `Builder.luau` is the standalone assembly/unlock module; its source is embedded in the generated kit.
