# Rope lasso coil

First lasso asset: one assembled prop, two separately recolorable meshes.

- `lasso-rope.blend`: editable Blender source with preview camera and lights.
- `lasso-rope.fbx`: assembled export containing only **Rope** and **Grip**.
- `parts/rope.fbx`, `parts/grip.fbx`: individual exports with matching origins.
- `preview/`: transparent hero and front renders.
- `generate/build_lasso.py`: deterministic Blender generator.
- `manifest.json`: colors, dimensions, pivot, and geometry validation.

The rope is one continuous, capped 3.5-turn spiral with a short straight-ended
tail. Its inner end is hidden under the rounded leather band. Plain light tan
rope (RGB 218, 181, 126), dark brown grip (RGB 91, 51, 30); no textures, painted
detail, fibre twists, ground, or base. Both parts use flat face normals.

Rope: 4,776 triangles. Grip: 188 triangles. Both meshes are closed and manifold.
The assembled bounding box is approximately 2.167 wide, 2.750 high, and 0.255
deep in authoring units. Scale the complete assembly together for the held prop.
Both mesh origins are at the assembled bounds center. Export uses Y-up / -Z
forward. Camera and lights are excluded from every FBX.

Import `lasso-rope.fbx` with Roblox Studio's 3D Importer and preserve both parts.
Use the recorded RGB colors for independently tintable MeshParts, with no
TextureID. Individual part files retain shared placement; do not center or
normalize them separately.

This package is local source art. It has not been uploaded or connected to
gameplay yet.

Regenerate from the repository root:

```powershell
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --background --python assets/lassos/rope/generate/build_lasso.py
```
