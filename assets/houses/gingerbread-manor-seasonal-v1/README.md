# Gingerbread Manor (seasonal) — Blender exterior v1

September 17, 2026. **Actual Blender asset; Studio integration pending. Interiors deferred.**

SEASONAL ASSET ONLY. This file does not approve the unresolved permanent 8M candy registry entry. Sale/availability rules were not changed.

Source reference: `assets/houses/design/fantasy-v2/fantasy-lineup.png`. Doorways are closed decorative geometry, with no furnished rooms, display mounts, entry logic or gameplay scripts.

## Deliverables

- `gingerbread-manor-seasonal.blend`: editable geometry, named sections, materials and review cameras/lights.
- `gingerbread-manor-seasonal-roblox.fbx`: recommended single-material-per-mesh import.
- `gingerbread-manor-seasonal-visual.fbx`, `gingerbread-manor-seasonal-visual.obj`, `gingerbread-manor-seasonal-visual.mtl`: grouped art exchange exports.
- `exterior.png`, `front.png`, `road.png`: actual Blender renders. Road view is an orthographic low-angle study, not a live Studio pavement photograph.
- `geometry-report.json`, `roblox-import-report.json`: source topology, vertex bounds, per-mesh RGB/triangles and FBX round-trip results.
- `animation-handoff.json`: named decorative effects and periods; runtime animation is not installed.
- `gingerbread-manor-seasonal-collision-mounts.rbxmx`: optional generic companion with only an invisible origin root. **No collision boxes or display attachments.**

## Measured output

Static bounds: **33.00 W × 29.80 D × 28.50 H** in units intended as studs. Frontward projection 4.60; rear extent 25.20. All static ornament, approaches and bases are counted. Width ≤60 and total depth ≤57 pass offline.

**22 FBX meshes, 13,144 triangles**. Optional origin root adds one BasePart. Source: 148 primitives merged into 10 editing sections. All exported source meshes have zero non-manifold edges. FBX round-trip maximum bounds error: 0.000003743 units.

Zero route samples were run: these are exterior models, so zero blocked rays is not evidence of avatar clearance. Full coplanar, continuous motion, physics and Studio visual checks remain pending.

## Integration

Blender X is across, Y rearward, Z up. The structural front-wall reference is Y=0; silhouette-specific doors may project forward. Origin is ground level. The export mapping is `(x,y,z)` → Roblox `(-x,z,y)`, front -Z. Confirm scale and orientation before front-pinning with HOUSE_FRONT_LINE. Do not use a whole-model bounding-box center inflated by decorative FX.

Use flat RGB from the material manifest and SmoothPlastic; no texture images are needed. Fishbowl additionally requires its material-overrides.json. Preview emission is stripped on export; restore only named accent effects in integration. Review ground/lights/cameras are excluded. Choose Anchored/collision fidelity and simple collision proxies explicitly; automatic mesh collision is not certified.

Actual plot/fence/lawn/kennel fit, camera, shadows, bloom, native shop framing, motion sweep and mobile performance need Studio verification. Warm accents are assigned explicitly in the Blender source. Game runtime, ownership and economy files were not changed by this batch, and nothing was uploaded or published.

## Rebuild

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b -t 6 --python-exit-code 1 --python assets/houses/tools/build_fantasy_batch.py -- candy
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' -b -t 4 --python-exit-code 1 --python assets/houses/tools/export_house_roblox.py -- candy 1
python assets/houses/tools/build_fantasy_handoff.py
```

Generated FBX files are git-ignored; rebuild after checkout. Source .blend, OBJ/MTL and scripts preserve the asset. Blender's optional OS thumbnail cache was unavailable under sandbox permissions, but sources and exports saved successfully.
