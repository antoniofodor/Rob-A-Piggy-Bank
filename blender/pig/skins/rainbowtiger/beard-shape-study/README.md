# Rainbow Tiger — isolated beard shape study

The latest reference clarifies the arrangement: a small fan of short tufts at
the top transitions into longer curved strands flowing down the face. Lower
strands must remain readable instead of forming a crowded row of tips.

This is a **separate geometry review**, not a replacement for the active pig
model or its FBX. Neutral clay is used to make curvature and overlapping layers
easy to see; it is not a proposed change to the tiger's charcoal color.

- [Layering study](beard-layering-study.png)
- [One isolated strand](single-lock-study.png)
- [Editable Blender study](beard-shape-study.blend)
- [Study meshes as FBX](beard-shape-study.fbx)

Each strand is built from separately shaped inner and outer contours, with a
rounded cross-section between them. This avoids the tight width clamps and
folding tips of the previous swept-tube approach. Seven visible strands are
arranged over a hidden root patch: two short branching tufts, two curved upper
layers, and three longer lower strands. Each is a separate closed mesh.

The user approved these curves and layering, then requested thicker strands.
The current study responds to the next reference correction: much fuller locks
and overlapping layers with no open background wedges. Visible locks are 2.05x
the original width and 2.70x the original depth (about 77% wider and 69% deeper
than the previous fullness pass). Their individual curve paths are retained;
the middle and lower layers are moved up underneath the layers above. A recessed
root patch fills the upper junction and its root is tucked behind the top fan.
All eight meshes remain closed (18,048 triangles total).
The approved pre-thickening study is preserved in `approved-shape-v1/`.
The previous fullness pass and its builder are preserved in `fullness-v2/`.

The user approved the dense layering. That untextured version is preserved in
`approved-dense-v3/`. The current study adds fine flowing hair strokes using
1024px `beard-flow-color.png` and `beard-flow-normal.png`, both packed into the
Blender file and also supplied separately. The UV direction follows each lock
from root to tip, with varied stroke spacing, gentle drift, and softened ends.
The geometry and layering are unchanged. The UV seam is unwrapped continuously.
These maps use the study's neutral material; the final pig material is still
pending. Use the normal map with the supplied FBX to preserve the surface detail.

The approved textured study has now been fitted to the full pig in
`../legendary-v2-swept/`. The fitting helper imports these exact meshes and UVs,
positions and rotates the locks around each cheek/chin, and binds the two sides
to Ruff_L/R. This folder remains the unchanged isolated source study.

Rebuild with Blender using `blender/pig/make/build_rainbowtiger_beard_study.py`.
