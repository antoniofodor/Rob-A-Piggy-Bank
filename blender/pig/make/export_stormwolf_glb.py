# -*- coding: utf-8 -*-
"""The finished Storm Wolf as ONE self-contained .glb, for handing to a tool.

    blender --background --python make/export_stormwolf_glb.py
    blender --background --python make/export_stormwolf_glb.py -- --with-bolts

Writes `pig/pig_stormwolf_textured.glb` (and `..._full.glb` with `--with-bolts`).

WHY A GLB AND NOT THE .obj THIS PIPELINE ALREADY WRITES. `pig_stormwolf.obj` is
what the GAME wants and it is deliberately NAKED: `export_materials=False`,
because Roblox reads a mesh and a texture as two separate uploads and an .mtl
pointing at a .png helps nobody. It also carries the SHARED-CYLINDER unwrap
rather than the baked one. So it is exactly the wrong file to hand to anything
that expects to see a finished animal.

A GLB embeds the image INSIDE the file, so there is one thing to upload and no
way for the map and the mesh to arrive separately or disagree. That is the whole
reason this exists rather than a note saying "send these two files".

**THE UVs HERE ARE THE BAKED ONES, WHICH IS THE HALF THAT WOULD BE EASY TO GET
WRONG.** The animal carries two unwraps in two different files: the shared
cylinder in `pig/pig_stormwolf_20k.blend`, which registers against every sheet
in `skins/`, and its own smart-project unwrap in `skins/stormwolf/stormwolf.blend`,
which is what `stormwolf_body_color.png` was actually baked through. Pairing the
sheet with the cylinder mesh renders a smear -- the two are not
interchangeable, and nothing about either file says so. This reads the SKIN
blend for that reason, and checks that the mesh it finds is unwrapped the way
the sheet expects before it writes anything.

WHAT COMES BACK FROM AN EDIT IS NEW TOPOLOGY, so a round trip re-runs the
pipeline rather than patching it. That is four commands and no hand work --
`make_stormwolf.py`, `make_stormwolf_skin.py`, `bake_skin.py --skin stormwolf`,
`make_stormwolf_bolts.py` -- which is the whole reason each of those measures
its own inputs instead of carrying pinned numbers.
"""
import os as _os, sys as _sys
_root = _os.path.dirname(_os.path.abspath(__file__))
while not _os.path.exists(_os.path.join(_root, "paths.py")):
    _up = _os.path.dirname(_root)
    if _up == _root:
        raise RuntimeError("cannot find paths.py above %s" % __file__)
    _root = _up
if _root not in _sys.path:
    _sys.path.insert(0, _root)

import paths                                              # noqa: E402
import bpy                                                # noqa: E402

argv = _sys.argv[_sys.argv.index("--") + 1:] if "--" in _sys.argv else []
WITH_BOLTS = "--with-bolts" in argv

SKIN_BLEND = _os.path.join(paths.skin_dir("stormwolf"), "stormwolf.blend")
SHEET = _os.path.join(paths.skin_dir("stormwolf"), "stormwolf_body_color.png")

for p in (SKIN_BLEND, SHEET):
    if not _os.path.exists(p):
        raise SystemExit("  ! %s missing -- run make_stormwolf_skin.py then "
                         "bake_skin.py -- --skin stormwolf" % p)

bpy.ops.wm.open_mainfile(filepath=SKIN_BLEND)
ob = bpy.data.objects.get("Body")
if ob is None:
    raise SystemExit("  ! no Body in %s" % SKIN_BLEND)

if not ob.data.uv_layers:
    raise SystemExit("  ! %s carries no UV layer -- it cannot wear the bake"
                     % ob.name)

# --- the baked sheet, as a plain image material -----------------------------
#
# The procedural graph is REPLACED rather than kept alongside. A .glb carries
# one material per slot and exports what the Principled node is fed, so leaving
# a 996-line Voronoi network wired in would either export nothing useful or bake
# a second time on the way out. The image IS the finished coat; that is what
# baking it was for.
mat = bpy.data.materials.new("stormwolf")
mat.use_nodes = True
bsdf = mat.node_tree.nodes["Principled BSDF"]
tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
tex.image = bpy.data.images.load(SHEET)
mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.82
if "Specular IOR Level" in bsdf.inputs:
    bsdf.inputs["Specular IOR Level"].default_value = 0.22
ob.data.materials.clear()
ob.data.materials.append(mat)

keep = [ob]
name = "pig_stormwolf_textured.glb"

if WITH_BOLTS:
    # THE BOLTS COME FROM THE BOLT BLEND, which is a different scene -- so they
    # are LINKED IN rather than rebuilt. They carry no UVs and want none: in the
    # game they are `Material.Neon` on a flat colour, and a .glb has no way to
    # say "emissive Roblox Neon", so they arrive as plain cyan geometry. That is
    # a picture of where the lightning is, not a description of how it glows.
    src = paths.pig("pig_stormwolf_bolts.blend")
    if not _os.path.exists(src):
        raise SystemExit("  ! %s missing -- run make_stormwolf_bolts.py" % src)
    with bpy.data.libraries.load(src) as (frm, to):
        to.objects = [n for n in frm.objects if n.startswith("Bolts_")]
    glow = bpy.data.materials.new("stormwolf_bolt")
    glow.use_nodes = True
    gb = glow.node_tree.nodes["Principled BSDF"]
    gb.inputs["Base Color"].default_value = (52 / 255, 200 / 255, 246 / 255, 1)
    if "Emission Color" in gb.inputs:
        gb.inputs["Emission Color"].default_value = (52 / 255, 200 / 255,
                                                     246 / 255, 1)
        gb.inputs["Emission Strength"].default_value = 1.0
    for o in to.objects:
        if o is None:
            continue
        bpy.context.scene.collection.objects.link(o)
        o.data.materials.clear()
        o.data.materials.append(glow)
        keep.append(o)
    name = "pig_stormwolf_full.glb"
    print("  bolts: %d groups linked in" % (len(keep) - 1))

bpy.ops.object.select_all(action='DESELECT')
for o in keep:
    o.select_set(True)
bpy.context.view_layer.objects.active = keep[0]

out = paths.pig(name)
# `export_image_format='AUTO'` embeds the PNG in the binary chunk, which is what
# makes this ONE file rather than a file and an instruction.
bpy.ops.export_scene.gltf(filepath=out,
                          export_format='GLB',
                          use_selection=True,
                          export_yup=True,
                          export_materials='EXPORT',
                          export_image_format='AUTO',
                          export_normals=True,
                          export_texcoords=True)

tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in keep)
mb = _os.path.getsize(out) / (1024.0 * 1024.0)
print("")
print("=== STORM WOLF, TEXTURED ===")
print("  objects: %s" % ", ".join(o.name for o in keep))
print("  %d tris   sheet %s" % (tris, _os.path.basename(SHEET)))
print("  %.1f MB   %s" % (mb, _os.path.relpath(out, _root)))
