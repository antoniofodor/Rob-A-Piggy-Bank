# Golden Piggy — empty walk-in revision 2

[Exterior preview](exterior.png) · [Inside](interior.png) · [Entrance](entry.png) · [All walk-in houses](../walk-in.html)

The main floor is accessible through a real opening. Bare walls, floor and ceiling; no furniture, trophies, rugs or interior decorations. Existing exterior details are retained. Upper exterior storeys are not additional accessible floors in this revision.

## Import into Studio

1. Import **[golden-piggy-roblox.fbx](golden-piggy-roblox.fbx)** as one model, without rotating or resizing it.
2. **Before preparing or resizing**, record the fresh mesh IDs with [dump_house_import.luau](../tools/dump_house_import.luau), setting `MODEL` to the imported model's name. Save the returned text to `dump.txt`, then run `python assets/houses/tools/record_house_import.py goldenpig 2 dump.txt`. Earlier `studio-import.json` files refer to different geometry and must not be reused. The recorder needs the original unscaled import.
3. For a standalone walk-through, select the imported model and run [prepare-in-studio.luau](prepare-in-studio.luau) in the Studio Command Bar while stopped. It sets stud scale, flat colors, transparency, separate collision boxes, display mounts and door hinges. It moves the prepared house to its authored origin; move the whole model to the desired location afterward. The operation supports Undo.
4. Put the model in Workspace and Play with Rojo connected. `HouseDoorAnimator.client.luau` opens the separate doors as any player approaches and holds them open until everyone has passed. Door leaves never collide and cannot trap players.
5. To replace the live catalogue template after recording the fresh IDs, run `python assets/houses/tools/build_house_runtime.py goldenpig 2`. This generates the template with collision, display mounts, glass properties and hinges directly from the authored report; the standalone helper is not required for that route.

The FBX alone does not install the companion collision or Roblox material properties. The helper above applies them; do not enable collision on the visual meshes, since a convex hull would seal the room again.

## Files and checks

- [golden-piggy.blend](golden-piggy.blend): editable source, doors in closed reference pose.
- `golden-piggy-visual.obj` / `.mtl`: grouped exchange source.
- `golden-piggy-collision-mounts.rbxmx`: collision companion in Blender-to-Roblox axes; the Studio helper also creates the doors' pivot markers.
- `geometry-report.json`: 40 avatar-body samples, room and doorway dimensions, collision boxes, door pivots.
- `roblox-import-report.json`: 54 material-split meshes, 6,324 triangles; FBX round-trip maximum bounds error 0.00000381 studs.
- `door-handoff.json`: 100° outward swing, 10-stud proximity, 0.35-second transition and 1.5-second hold.

Room clear rectangle: **31.7 × 15.9 studs**, floor-to-ceiling **15.0 studs**. Floor at Z=2.21 in Blender. Your approved exterior resize (1.38×) is baked into this source; the runtime display multiplier is **1.0**. `Mount_Wall` and its 180° facing mark the empty display wall without adding any decoration. Static mesh topology and sampled clearance pass. Live avatar/camera, eight-player/mobile performance, door sweep and plot/fence clearance still require Studio playtesting. These files have not uploaded new mesh IDs or replaced existing live templates.

## Rebuild

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b -t 3 --python-exit-code 1 --python assets/houses/tools/build_walkin.py -- goldenpig
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b -t 3 --python-exit-code 1 --python assets/houses/tools/export_house_roblox.py -- goldenpig 2
python assets/houses/tools/build_walkin_handoff.py
```

Previous art is preserved in [golden-piggy-v1](../golden-piggy-v1/README.md). Stable game ID remains `goldenpig`. Gingerbread is seasonal and outside this permanent-house pass.
