# Spellcaster - mage hood revision 5

Adds a raised, lined cloth hood to the accepted v4 model. Both original pig ears pass through fitted openings; their geometry is unchanged. Gold piping follows the face arch, pink rune embroidery follows both hood cheeks, and a pink diamond with a gold setting clasps the brow. The hood back edge seats into the existing robe. Full boots, the covered underside, the original coin slot and the animated gem hardware are retained.

Saved as a separate review package. No asset uploads or installed geometry changes. The display name remains Spellcaster; the compatibility ID remains finalboss.

Validation: the hood is one connected closed mesh with Euler characteristic -2, confirming two through-openings. Ear tips and five face rays remain clear. Twelve coin paths remain unobstructed. Existing nine-pose animation clearance, six-second loop closure, base geometry/UV preservation, and both FBX round trips pass. Total accessories: 78 meshes and 22,782 triangles.

Build: build.py runs geometry.py from the accepted mage-v4 blend, validates, exports, renders, and saves. validate_saved.py reopens the result and checks hood connectivity and openings. show_blender.py safely appends the review scene through Blender MCP.

Preview: http://127.0.0.1:8841/arcade-spellcaster-v5/index.html
Model: ../legendary/finalboss/package/spellcaster-v5/finalboss-spellcaster-v5.blend

Import follow-up after review: upload this accessory revision, preserve the existing Overdrive v3 body/trim maps, and regenerate sampled Arcade motion data. Keep the v4 boot ground-clearance adjustment.
