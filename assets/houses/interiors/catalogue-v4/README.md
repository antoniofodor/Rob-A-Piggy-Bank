# Complete permanent house-interior catalogue

All **18 permanent houses** now have a matching interior. The 15 newly built themes join the approved Cardboard, Beehive and Treehouse designs. Every house uses a larger floor and higher ceiling than the preceding tier.

Open [the visual gallery](gallery.html) or [the contact sheet](catalogue-contact-sheet.jpg). The images render the delivered editable models; they are not concept illustrations. Each gallery card links to its Studio preview, native kit and instructions.

## Size progression

The current rule adds **2 studs of width and 1 stud of ceiling height per house tier**, while every room stays **40 studs long**. Pedestal rows stay at **8, 20 and 32 studs** from the room entrance, giving consistent 12-stud spacing and shorter travel through higher-tier halls. It is editable in [tier-sizing.json](tier-sizing.json), and tier order comes directly from `Config.HOUSE_TIERS` so saved IDs do not change.

| Tier | House | Width | Room length | Ceiling |
| --- | --- | ---: | ---: | ---: |
| 1 | Cardboard Fort | 60 | 40 | 32 |
| 2 | Beehive Cottage | 62 | 40 | 33 |
| 3 | Wonky Townhouse | 64 | 40 | 34 |
| 4 | Toadstool Cottage | 66 | 40 | 35 |
| 5 | Fairy Lantern Cottage | 68 | 40 | 36 |
| 6 | Treehouse | 70 | 40 | 37 |
| 7 | Haunted Manor | 72 | 40 | 38 |
| 8 | Gloop House | 74 | 40 | 39 |
| 9 | Fishbowl House | 76 | 40 | 40 |
| 10 | Neon Tower | 78 | 40 | 41 |
| 11 | Crystal Spire | 80 | 40 | 42 |
| 12 | Ice Palace | 82 | 40 | 43 |
| 13 | Sky Castle | 84 | 40 | 44 |
| 14 | Beached Galleon | 86 | 40 | 45 |
| 15 | Portal House | 88 | 40 | 46 |
| 16 | Thundercloud Fortress | 90 | 40 | 47 |
| 17 | The Void | 92 | 40 | 48 |
| 18 | Golden Piggy | 94 | 40 | 49 |

All dimensions are in studs. These are house-tier dimensions; appending a rebirth room repeats that house's module. Higher tiers do not change the six-station room capacity or grant extra unlocks. Gingerbread Manor is retired/seasonal and is not part of the permanent catalogue.

## Layout and editing

Each kit has four templates: `RoomShell`, `Pedestal`, `RebirthGate` and `AchievementVestibule`. All rooms keep six independent slots, three per side. Pedestals and buttons stay at their usable size as the architecture grows. The rows sit 12 studs in from the side walls, leaving outer routes behind the stations; crossovers connect these to the central aisle. Door frames are wider and taller at each tier, and moving panels use matching vertical offsets.

The floor is level in every theme, including Wonky Townhouse. Decorations stay on walls or overhead. Window recesses are opaque decorative scenes, so the off-map exterior is hidden. Each vestibule has a blank framed achievement area. No achievement UI is implemented here.

In Studio, edit the native `.rbxmx` kit. Each pedestal's `Collect.CollectionPlate` and `Collect.CollectionInset` can be removed independently for your own buttons. Keep `Root.Collect` as an interaction marker and `Root.Piggy` as the placement mount. The Builder supports `build`, `appendRoom`, `setCapacity`, `setRebirths`, `setSlot` and `piggyMount`. Removing a pedestal removes its children, so move a resident piggy first.

The `*-interior-preview.rbxlx` files contain two static assembled rooms, an open connecting gate and a closed end gate. Reference avatars disappear locally during Play. Their camera uses the game's current 11-stud zoom cap. Each theme also contains editable Blender source, four FBX modules, part/mesh budgets and a native review model. FBX static groups are merged by material; individual button editing is easiest in the native kit.

## Game integration

`default.project.json`, `Config.HOUSE_INTERIOR_KITS` and `ThemedInterior`'s fallback registry include every permanent house. The wrapper derives plot placement, entrance apertures and off-map estate spacing from each template. Capacity, prices, house ownership and rebirth thresholds are unchanged. Visitor access and robbery rules are outside this art change.

Sync the updated Rojo project and restart Play to rebuild cached hall instances. If Rojo still serves the old project mapping, restart `rojo serve default.project.json` and reconnect in Studio. This task does not publish the game.

## Verification

Every theme has a `studio-checks.json` report from the Roblox engine, covering room connections, floor coverage, independently removable slots, gate locking, raised-panel clearance and four-stud-wide movement envelopes behind and between stations. Crossovers are sampled inside the room, beyond the doorway frame. `integration-checks.json` tests the actual game's wrapper, derived estate bounds, tier-specific repeat lengths and physical support under piggy mounts. Temporary verification models are cleaned up.

The repository interior suite passed **1,462 checks, including 56 sightlines**, with all 18 houses registered. The full Rojo project builds successfully. These checks establish geometry and integration; two-player chase balance and multiplayer/mobile performance still need playtesting. See per-theme budgets rather than assuming every themed room has the same part count.

## Rebuild

From the repository root:

```powershell
python assets/houses/interiors/catalogue-v4/generate/build.py
python assets/houses/interiors/catalogue-v4/generate/install_registry.py
python assets/houses/interiors/catalogue-v4/generate/render_all.py
python assets/houses/interiors/catalogue-v4/generate/package.py
```

`generate/catalogue.py` defines the themes; `geometry.py` builds their architecture. Frozen inputs preserve the three approved designs. `tier_sizes.py` applies the progression to architecture and connections without resizing interaction props. The same size factor drives Builder door travel and the static review's open gates. Regenerate and rerun Studio checks after geometry or sizing changes before packaging.
