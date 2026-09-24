# Wider default house interiors

The default Treehouse, Cardboard Fort and Beehive Cottage interiors now use a **60-stud floor width, 40-stud room length and 32-stud roof ridge**. Their original theme-specific pedestal models stay the same size. The extra room is for moving past another player and circling around a pedestal.

## Movement space

- Six removable stations per room, centered at X ±18 and forward distances 8, 20 and 32.
- A reserved central aisle at least 28 studs wide between collection plates.
- Roughly 8–9 studs between the pedestal backs and wall dressing, with continuous outer routes tested at X ±24.
- Roughly 6 studs between adjacent stations; crossovers run in front, between and behind them.
- Doorways expand to roughly 51.5 studs wide and 19 studs clear height. The raised open panels clear that opening.
- Independent collection plates keep their original size, position relative to each pedestal and attachment names.
- The achievement vestibule retains its blank display wall and entrance/exit attachments.

These dimensions provide movement space; the current house-access and robbery rules are unchanged. This is geometric clearance validation, not a two-player chase balance test. The generic fallback used by houses without authored art is unchanged.

## In the game and in Studio

`default.project.json` now maps all three existing ServerStorage kit names to the packages in this folder. `Services/ThemedInterior` already derives plot positions, exit apertures and estate spacing from the templates, and passed integration checks with these dimensions. No progression or cash rules changed.

Sync the updated Rojo project, then restart Play so cached builders and existing hall instances rebuild. If an already-running Rojo session still shows the old mappings, restart `rojo serve default.project.json` and reconnect. No game was published by this change.

For a standalone walkthrough, open a theme's `*-interior-preview.rbxlx`. Each has two rooms, twelve independently selectable pedestals, an open connecting doorway and a closed terminal door. Block avatars provide scale in Edit mode and are removed locally during Play. These review models are static; use the kit Builder to exercise unlocks. The normal follow camera uses the game's current 11-stud zoom cap.

Native editable kits:

- [Treehouse](treehouse/treehouse-interior-kit.rbxmx)
- [Cardboard Fort](cardboard-fort/cardboard-fort-interior-kit.rbxmx)
- [Beehive Cottage](beehive-cottage/beehive-cottage-interior-kit.rbxmx)

Each contains `Templates.RoomShell`, `Pedestal`, `RebirthGate`, `AchievementVestibule` and `Builder`. Delete `Pedestal.Collect.CollectionPlate` and `CollectionInset` to use your own buttons. Keep `Root.Collect` as the interaction marker. Room extensions align through `Root.Entry` and `Root.Exit`. The Builder API remains the same: `build`, `setCapacity`, `appendRoom`, `setRebirths`, `setSlot` and `piggyMount`. A removed pedestal takes its children with it, so move its piggy before revoking the slot.

Each theme also includes Blender source, FBX modules, a render from the delivered geometry and the native part budget. Native parts retain their individual editability; FBX exports merge static material groups.

## Verification and rebuilding

Studio checks passed: Treehouse **628**, Cardboard Fort **622**, Beehive Cottage **648**, plus **20** checks through the game's actual ThemedInterior wrapper. These cover room extension, slot removal, rebirth gates, door clearance, raised exit markers, derived estate spacing and four-stud-wide collision envelopes along both outer paths and every crossover. Temporary test models were cleaned up. `studio-checks.json` inside each theme and `integration-checks.json` retain the results.

The full project also passed `rojo build`. An attempted offline interior suite could not launch because `luau` was not on PATH; the engine checks above ran in Studio. Part counts remain the same as v1 (first furnished room plus gate and vestibule: Treehouse 521, Cardboard 409, Beehive 551). No multiplayer performance benchmark was run.

Shared sizing is in `generate/resize.py`. Frozen original art and Builders are in `generate/inputs/`, so repeated builds never scale an already-scaled model. Props remain unchanged while architectural dimensions, mounts and gate open offsets change together. Original v1 and the Treehouse v2 comparison remain available.

From the repository root:

```powershell
python assets/houses/interiors/wide-default-v3/generate/build.py
# Repeat for treehouse, cardboard-fort and beehive-cottage:
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b -t 4 --python-exit-code 1 --python assets/houses/interiors/wide-default-v3/generate/render.py -- --theme beehive-cottage
python assets/houses/interiors/wide-default-v3/generate/package.py
```

The packaging script rebuilds the standalone preview places, validates the mapped native files and verification results, and includes all three themes in one archive. To rerun engine checks, supply each theme's geometry as `SPEC` and Builder text as `BUILDER_SOURCE` to its `generate/*-checks.luau` in Studio; these scripts clean up their isolated test objects on success or failure.
