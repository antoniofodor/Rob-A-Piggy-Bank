# Plunger — smooth model v1

Red molded rubber bell with a reinforced rim, real hollow underside, wooden
shaft and rounded grip. The same geometry appears in the revised Supplies icon,
beside pink Bubblegum Bomb gum and the golden bone. No potion bottle remains.

- `plunger.glb` / `plunger.fbx`: two meshes, RubberCup and Handle; packed palette.
- `palette.png`: shared swatch texture; rubber and timber use separate roughness.
- `../../sources/plunger.blend`: editable model, camera and studio lighting.
- `../../plunger.png` / `../../plunger-underside.png`: model inspection renders.
- `manifest.json`: actual bounds, triangles and grip/tip markers in Roblox coordinates.
- `validation.json`: manifold geometry, hollow-cup rays and both export round trips.

Import at one unit per stud. Preserve the authored origin, with the handle pointing
Roblox +Y and the cup pointing -Y, matching GadgetModel's existing javelin flight
orientation. The root is not the overall bounding-box center. Meshes are visual;
keep CanCollide, CanTouch and CanQuery disabled when integrated into GadgetModel.

This is a review asset, not yet uploaded or connected to the runtime gadget.
The original plunger remains in game until the mesh is approved and imported.
No changes to throw trajectories, hit detection, prices or inventory.
