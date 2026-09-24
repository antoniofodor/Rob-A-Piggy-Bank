# Treehouse modular interior — first build

Built from the approved **A Home That Grows** concept. This is a real geometry package, with an upload-free Roblox version, editable Blender source, and separate FBX modules. All preview images are rendered from the delivered Roblox geometry.

## Open and review

- **`treehouse-interior-preview.rbxlx`**: standalone Studio preview place. Open as a separate place; Play spawns inside the entrance. Contains an assembled two-room example, an open connecting gate, a closed end gate, six pedestals in the first room and three in the second.
- **`treehouse-interior-review.rbxmx`**: the same assembled model for inserting into an existing Studio file. Static review poses; no auto-running scripts.
- **`treehouse-interior-kit.rbxmx`**: reusable templates and the `Builder` ModuleScript. Insert this into **ServerStorage**, where templates will not render or collide with the world.
- **`treehouse-interior.blend`**: actual model source. `Assembled Review` is the complete preview; `Reusable Templates` contains the four independent module collections at their local origins. Isolate one template collection to edit it, since their origins intentionally coincide.
- **`exports/`**: separate `RoomShell.fbx`, `Pedestal.fbx`, `RebirthGate.fbx` and `AchievementVestibule.fbx`. Static surfaces are merged by material; moving door sections remain separate. FBX exports are optional art sources; the native RBXMX already includes collision and mounts and needs no asset uploads. FBX alone does not carry the kit's collision, attachments or behavior.
- **`preview/`**: hall, achievement alcove, construction cutaway and pedestal close-up.

The existing live house interiors and economy have not been replaced. The running Studio session was used only for isolated checks, which clean up their temporary models. Final player-camera/mobile performance and integration with live piggy placement, cash collection, teleport transitions and the current `InteriorService` remain separate integration work.

## Four independent pieces

| Model | Purpose |
| --- | --- |
| RoomShell | 38-stud clear width, 32-stud repeat length, 16-stud clear center aisle, six invisible slot attachments; no pedestals baked into the floor |
| Pedestal | Freestanding timber stump with green top, a removable collection plate, and Piggy / CashLabel / Collect attachments |
| RebirthGate | 32.6-stud nominal opening, 13.4-stud clear height; six timber panels stack above the opening, separate lock display and invisible blocking plane |
| AchievementVestibule | 14-stud entrance section with an empty 10 × 6-stud achievement wall, a shelf and a dedicated attachment; no achievement logic or trophies |

Every module is authored in studs. Roblox +Y is up and -Z is forward. Room `Entry` is at its floor origin; `Exit` is 32 studs forward. Align the next room's `Entry` attachment to the last room's `Exit`. No resizing or manual wall surgery is needed. The builder uses attachment transforms, including when the whole hall is moved or rotated.

The windows are intentionally opaque daylight/forest recesses: they suggest the same wooded exterior without showing the off-map void. Canopy leaves, branches and fixtures stay above the walking area. The ceiling uses sloping visual planes; side walls and floors provide collision. The giant gate panels do not collide individually; the independent blocking plane enforces the locked state.

## Server-side assembly

After inserting the kit in ServerStorage, this creates a hall using the game's existing progression configuration. The supplied CFrame marks the **outer entrance at floor height**, with its LookVector pointing into the hall.

```lua
local Config = require(game.ReplicatedStorage.Shared.Config)
local Builder = require(game.ServerStorage.TreehouseInteriorKit.Builder)
local rebirths = 0 -- Read from the owner's server-side saved data.

local hall = Builder.build(workspace, CFrame.new(0, 1000, 0), {
    capacity = Config.indoorPlots(rebirths),
    rebirths = rebirths,
    requirement = Config.indoorDoorRebirths,
})

-- When the owner's server-side progression changes:
Builder.setCapacity(hall, Config.indoorPlots(rebirths))
Builder.setRebirths(hall, rebirths)

-- Optional manual station control for authoring / individual unlocks:
Builder.setSlot(hall, 1, 3, false) -- Removes this entire pedestal and plate.
Builder.setSlot(hall, 1, 3, true)  -- Restores it without duplicates.

-- The mount for placing an actual piggy, if the slot is unlocked:
local mount = Builder.piggyMount(hall, 1, 3)
local piggyFrame = if mount then mount.WorldCFrame else nil

-- Extend without changing the previous room:
Builder.appendRoom(hall)
```

`setCapacity` builds the required room prefix and updates the individual stations. It does not open gates by itself. Gates use the supplied room-number-to-rebirth callback, and never open onto an unbuilt room, even when the rebirth count is met. A callback returning nil marks a terminal gate. The gate label and open state use that same callback. Six slots per room match the current configuration; changing that layout requires another template revision.

`setSlot` is an authoring/integration primitive, not a purchase or persistence API. A later call to `setCapacity` re-applies contiguous slot unlocking. Removing a station destroys its child model, so the eventual piggy-placement integration must reconcile/remove a resident piggy before revoking that slot. Gates currently change pose immediately; animation can be added later without altering the separate panel models.

## Verification and cost

**96 checks passed in Roblox Studio**, including physical floor raycasts, avatar-sized aisle clearance, solid gate jambs and a closed barrier with no side gap. Rojo also successfully parsed the native models and built the standalone preview place.

`studio-checks.json` records engine checks of the assembly, unlocks, connection transforms, six slots, independent removal/restoration, label agreement and open-door clearance. `generate/studio_checks.luau` is the reusable check body. The local runner supplies `SPEC` from `geometry.json` and `BUILDER_SOURCE` from `Builder.luau`; it executes in an isolated folder and always removes its test objects.

`part-budget.json` gives exact native part counts, including each template's invisible root. The native first room plus vestibule, gate and six pedestals is **521 BaseParts**. This version favors direct editing and upload-free review. Use the merged mesh exports, prefix loading and measured profiling before rolling the art out to every player's maximum-length hall. `mesh-budget.json` records the export mesh and triangle counts; it is not a performance benchmark.

## Rebuild

```powershell
python assets/houses/interiors/treehouse-v1/generate/build_kit.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b -t 3 --python-exit-code 1 --python assets/houses/interiors/treehouse-v1/generate/render_kit.py
rojo build assets/houses/interiors/treehouse-v1/preview.project.json -o assets/houses/interiors/treehouse-v1/treehouse-interior-preview.rbxlx
```

`generate/build_kit.py` is the editable geometric source of truth. It emits both native models and `geometry.json`. The Blender renderer consumes that geometry and the assembled RBXMX, preventing a separate illustration from drifting away from the delivered model.
