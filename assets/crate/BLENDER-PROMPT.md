# Acorn storage crate — Blender generation prompt

Create a game-ready, low-poly open wooden storage crate in Blender for a playful Roblox game called Rob a Piggy Bank. It sits beside a small faceted oak and stores collectible Acorns. Match a chunky, friendly low-poly oak with warm orange-brown bark and bright green foliage, plus a small woven carry basket.

**Shape and scale**
- A squat rectangular crate, 3.6 units wide × 2.8 units deep × 1.9 units tall. These are the target Roblox stud dimensions; keep the imported bounding box at that scale.
- Open top, genuinely hollow interior, solid wooden floor. No lid, handles, wheels, legs or attached Acorns. The game adds the contents separately.
- Three broad horizontal planks per wall, narrow gaps, four chunky corner posts, a slightly thicker top rim. Floor thickness 0.25 units; walls about 0.18 units thick. Keep the opening wide enough to see the contents from an elevated gameplay camera.
- Small one-segment bevels and subtle, intentional asymmetry. Flat shading and readable silhouettes. Avoid fine grooves, splinters or photorealistic wood grain.

**Style and colour**
- Warm honey-brown boards, slightly darker corner posts, pale golden bevel faces, darker interior. Use a restrained flat-colour palette and matte surfaces.
- Add a simple flat low-poly Acorn emblem to the centre of the front wall, with a tan nut and dark brown cap. No letters, numbers or baked shadows.
- Keep it clearly recognizable as permanent yard storage and visibly larger than the carry basket.

**Game-ready delivery**
- Keep the entire prop under 1,000 triangles. Use real thickness, outward normals and no hidden duplicate geometry.
- Name the model/collection `AcornStorageCrate`. Use clearly named meshes such as `CrateBody`, `CornerPosts`, `TopRim` and `AcornEmblem`.
- Place the origin at the centre of the bottom contact plane. Blender Z is up; apply rotation and scale before export. Use the normal glTF axis conversion.
- Provide a `.blend`, a `.glb`, and a simple 512×512 flat-colour texture atlas PNG compatible with Roblox import. Ensure every mesh has the correct UVs and material assignments. Do not bake scene lighting into the texture.
- Include a three-quarter preview with neutral lighting and a scale reference, but exclude the camera, lights and reference from the exported model.
