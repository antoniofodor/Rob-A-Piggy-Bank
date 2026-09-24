# OG refresh, revision 2

Ghost and Hologram are installed in the local project and open Roblox Studio place. Their twelve uploaded textures are approved. The exact layered versions selected in the two user screenshots are retained: both restored Blender hero renders match the supplied PNGs pixel for pixel. This is a Studio installation, not a public game publication.

Aurora, Banker, Rockslide, Quartz and Neon Mint remain review assets. Existing tiers and skin keys are retained. The five rares have authored coats, with modest unlit stone accents or selective material shimmer; the two epics have a patterned coat, emission, animation and an aura.

## Installed spectral effects

Ghost has a pale translucent layered coat, dark eyes, fading feet, drifting tapered mint wisps and the wisp aura. Hologram has translucent cyan grids and magenta fragments across body and trim, cyan eyes, a traveling contour scan and the hologram aura. Visible intersections are intentional and match the selected references.

RGBA coats use SurfaceAppearance AlphaMode Transparency. PiggyModel sets spectral MeshPart transparency to 0.02 for smooth alpha blending and restores ordinary opacity when changing skins. White part colors preserve the authored texture colors. Native EmissiveMaskContent and EmissiveStrength provide selective glow. SpectralFX creates client effects attached to the existing body, scales with full-size pigs and minis, and removes its effects when a skin changes. Scan contours were sampled from the original body and trim meshes. Shared geometry, UVs and collisions are preserved.

The matching SurfacePacks live in src/ReplicatedStorage/Shared/SurfacePacks. Upload receipts are in each epic's revisions/og-v2/roblox-uploads.json. tools/install_spectral.py stages the scoped Studio payload. sync_studio.luau patches only these two skins, their four surface templates, the wisp preset and their runtime hooks. HTTP-disabled Studio can receive the same payload inline.

## Review packages

Each model is in ../{tier}/{key}/revisions/og-v2/package/{key}-og-v2.blend, with complete FBX, asset report and accessory FBX where relevant. Baked maps are 1024px. Animated WebPs are six-second loops rendered from 48 source frames; identical frames may be combined by WebP encoding. Blender animation is a reference; Roblox effects run through SpectralFX.

Rockslide adds 192 triangles in 12 shallow embedded plates; Quartz adds 240 triangles in 10 crystals. Their package validation checks closed meshes, preserved geometry/UVs, FBX round-trip bounds and coin-slot clearance. Aurora and Neon Mint material shimmer still needs runtime integration at installation.

prepare_builder.py, build.py, paint.py and geometry.py produce the geometry-preserving assets. render_motion.py creates animated previews. validate_saved.py checks the saved deliverables, and finalize.py checks gallery links, textures and animation duration. show_approved.py appends the approved Ghost/Hologram scenes without replacing or saving the user's open Blender file.

clean_projection.py and finish_epic.py belong to the rejected cleaned-translucency experiment. Do not run them on the approved files. Those alternatives are preserved separately in revisions/og-v2-cleaned-alternative.
