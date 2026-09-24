# Overdrive - Arcade Legendary revision 3

The former Final Boss is named Overdrive. Its internal finalboss key remains unchanged to preserve saved skins, template mappings, and existing uploaded asset IDs. Config display names and the Arcade design catalog have been updated. Geometry is a separate review package; v2 geometry remains installed.

The revised model uses fitted plum shields with thin gold edges, layered crown armor, routed pink glow tracks, a rear reactor with rotating gold markers, pulsing diamond cores, mounted rear cartridges, four-cell charge meters, and clean ankle cuffs. The pink face and feet remain exposed. The functional coin slot stays open. Its Legendary traits are substantial accessory geometry, emissive hardware, a six-second motion loop, and the existing sparse pink arcade pixel aura.

73 closed accessory meshes; 13,648 accessory triangles. Base geometry and UVs unchanged. Validated 12 unobstructed coin paths, face clearance at nine animation poses, and six-second loop closure below 0.000001. Accessory and complete FBX round trips match within 0.000002 studs.

Build: build.py executes geometry.py, bakes body and trim color maps, exports and verifies FBX, then renders and saves the Blender file. render_motion.py produces front and rear loop frames; package_motion.py creates animated WebP previews. show_blender.py appends the scene through Blender MCP, preserving all existing scenes.

Preview: http://127.0.0.1:8841/arcade-overdrive-v3/index.html
Model: ../legendary/finalboss/package/overdrive-v3/finalboss-overdrive-v3.blend

Integration follow-up after review: upload revised accessory model and the two new color maps, extract new motion samples, and update finalboss active-revision wiring. No asset uploads or installed geometry changes were made by this review.
