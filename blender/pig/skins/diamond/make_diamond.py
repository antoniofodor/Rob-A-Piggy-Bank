# -*- coding: utf-8 -*-
"""Bake the DIAMOND skin's facet pack: colour overlay, normal and roughness.

    blender --background --python skins/diamond/make_diamond.py

WHAT IT IS. The Diamond was a light-blue glass pig -- a colour, with nothing
saying "cut stone". Roblox has no faceted material, and a ForceField shell
over the body was tried in Studio and barely showed. So the facets are
baked: the pig is broken into 3D Voronoi cells and each cell becomes one flat
facet.

THREE SHEETS PER PART, AND EACH DOES ONE JOB:

  * NORMAL -- every cell's surface is tipped by its own random angle, so the
    sun catches some facets and not their neighbours. This is what actually
    reads as cut: the facets change as the pig is walked round, where painted
    ones would not.
  * COLOR (`AlphaMode.Overlay`) -- neutral white and black only, so the part's
    own `Color3` (the skin's ice blue) stays the colour: each facet is nudged
    lighter or darker, and a bright line is drawn along every facet edge. Same
    neutral rule `bands` records, for the same reason.
  * ROUGHNESS -- low, so the surface is glossy; edges lowest of all.

THE CELLS ARE 3D, IN OBJECT SPACE, NOT DRAWN ON THE UNWRAP. A pattern drawn on
the cylindrical unwrap would stretch across the crown and seam down the back;
cells cut from the solid have neither, and the bake carries them onto the UVs.

Body and trim bake separately because they are separate MeshParts in game --
see `bake_skin.py`. Both use the same cell field, so a facet running from the
body onto the snout lines up.

Writes into this folder:
    diamond_{body,trim}_color.png      RGBA overlay
    diamond_{body,trim}_normal.png     tangent space, OpenGL (+Y), as Roblox reads it
    diamond_{body,trim}_roughness.png
"""

# --- find the toolkit, wherever this script has been filed ------------------
import os as _os, sys as _sys
_root = _os.path.dirname(_os.path.abspath(__file__))
while not _os.path.exists(_os.path.join(_root, "paths.py")):
    _up = _os.path.dirname(_root)
    if _up == _root:
        raise RuntimeError("cannot find paths.py above %s" % __file__)
    _root = _up
if _root not in _sys.path:
    _sys.path.insert(0, _root)
# ---------------------------------------------------------------------------

import paths   # noqa: E402
import bpy, os
import numpy as np

SKIN = "diamond"
SIZE = 1024
SUPER = SIZE * 2
ROUGH_SIZE = 256

# THE NUMBERS. The body is 2.0 Blender units wide and 12 studs in game, so a
# unit is six studs; a scale of 3.4 gives cells about 1.8 studs across, which
# is roughly twenty facets round the belly -- a cut stone, not a mosaic.
CELL_SCALE = 2.8
TILT = 0.75          # how far a facet's normal leans; 0 is a smooth pig
# LIGHTER FAR MORE OFTEN THAN DARKER. The first bake shaded both ways equally
# and read as crazy paving -- dark tiles in grout. A stone is mostly light
# with the odd deep facet, so the lift reaches 0.50 and the sink only 0.16.
LIFT_SHADE = 0.50
SINK_SHADE = 0.16
EDGE_WIDTH = 0.018   # in cell units -- a hairline, not grout
EDGE_ALPHA = 0.45
ROUGH_FACET = 0.12
ROUGH_EDGE = 0.04

OUT = paths.skin_dir(SKIN)
os.makedirs(OUT, exist_ok=True)

GROUPS = [("body", ["Body"]),
          ("trim", ["Snout", "Ears", "Legs", "Tail"])]

bpy.ops.wm.open_mainfile(filepath=paths.PARTS)
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 1
scene.render.bake.use_selected_to_active = False
scene.render.bake.margin = 12


def build_material():
    """One graph serves all three bakes: `mode` picks what the output shows."""
    mat = bpy.data.materials.new("DiamondBake")
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    N = nt.nodes.new
    L = nt.links.new

    coord = N("ShaderNodeTexCoord")
    cells = N("ShaderNodeTexVoronoi")
    cells.voronoi_dimensions = '3D'
    cells.feature = 'F1'
    cells.inputs["Scale"].default_value = CELL_SCALE
    L(coord.outputs["Object"], cells.inputs["Vector"])
    edges = N("ShaderNodeTexVoronoi")
    edges.voronoi_dimensions = '3D'
    edges.feature = 'DISTANCE_TO_EDGE'
    edges.inputs["Scale"].default_value = CELL_SCALE
    L(coord.outputs["Object"], edges.inputs["Vector"])

    # Facet normal: the geometry normal leaned by the cell's random colour.
    centred = N("ShaderNodeVectorMath"); centred.operation = 'SUBTRACT'
    centred.inputs[1].default_value = (0.5, 0.5, 0.5)
    L(cells.outputs["Color"], centred.inputs[0])
    lean = N("ShaderNodeVectorMath"); lean.operation = 'SCALE'
    lean.inputs["Scale"].default_value = TILT * 2
    L(centred.outputs["Vector"], lean.inputs[0])
    geo = N("ShaderNodeNewGeometry")
    added = N("ShaderNodeVectorMath"); added.operation = 'ADD'
    L(geo.outputs["Normal"], added.inputs[0])
    L(lean.outputs["Vector"], added.inputs[1])
    unit = N("ShaderNodeVectorMath"); unit.operation = 'NORMALIZE'
    L(added.outputs["Vector"], unit.inputs[0])

    bsdf = N("ShaderNodeBsdfPrincipled")
    L(unit.outputs["Vector"], bsdf.inputs["Normal"])

    # Edge mask: 1 on a facet edge, 0 inside.
    edge = N("ShaderNodeMapRange")
    edge.inputs["From Min"].default_value = 0.0
    edge.inputs["From Max"].default_value = EDGE_WIDTH
    edge.inputs["To Min"].default_value = 1.0
    edge.inputs["To Max"].default_value = 0.0
    L(edges.outputs["Distance"], edge.inputs["Value"])

    # Shade: the cell's own random value, 0..1, carried in R; edge in G.
    sep = N("ShaderNodeSeparateColor")
    L(cells.outputs["Color"], sep.inputs["Color"])
    comb = N("ShaderNodeCombineColor")
    L(sep.outputs["Red"], comb.inputs["Red"])
    L(edge.outputs["Result"], comb.inputs["Green"])
    emit = N("ShaderNodeEmission")
    L(comb.outputs["Color"], emit.inputs["Color"])

    out = N("ShaderNodeOutputMaterial")
    image = N("ShaderNodeTexImage")
    nt.nodes.active = image
    return mat, bsdf, emit, out, image


def bake(objects, mat, image_node, kind):
    img = bpy.data.images.new("bake_%s" % kind, SUPER, SUPER, alpha=True, float_buffer=True)
    if kind == "normal":
        img.colorspace_settings.name = "Non-Color"
    image_node.image = img
    bpy.ops.object.select_all(action='DESELECT')
    for ob in objects:
        ob.hide_render = False
        ob.data.materials.clear()
        ob.data.materials.append(mat)
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if kind == "normal":
        scene.render.bake.normal_space = 'TANGENT'
        scene.render.bake.normal_r = 'POS_X'
        scene.render.bake.normal_g = 'POS_Y'   # OpenGL, which Roblox reads
        scene.render.bake.normal_b = 'POS_Z'
        bpy.ops.object.bake(type='NORMAL')
    else:
        bpy.ops.object.bake(type='EMIT')
    img.scale(SIZE, SIZE)
    buf = np.empty(SIZE * SIZE * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    return buf.reshape(SIZE, SIZE, 4)


def save(name, arr, size, non_color):
    img = bpy.data.images.new(name, size, size, alpha=True)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(np.ascontiguousarray(arr, dtype=np.float32).ravel())
    img.filepath_raw = os.path.join(OUT, name + ".png")
    img.file_format = 'PNG'
    img.save()
    print("  wrote", name + ".png", flush=True)


mat, bsdf, emit, out, image_node = build_material()
links = mat.node_tree.links

for group, names in GROUPS:
    objects = [bpy.data.objects[n] for n in names if n in bpy.data.objects]
    if not objects:
        continue

    # 1. Normal map -- the Principled's leaned normal.
    for l in list(out.inputs["Surface"].links):
        links.remove(l)
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    normal = bake(objects, mat, image_node, "normal")
    normal[..., 3] = 1.0
    save("%s_%s_normal" % (SKIN, group), normal, SIZE, True)

    # 2. Shade + edge fields, as emission.
    for l in list(out.inputs["Surface"].links):
        links.remove(l)
    links.new(emit.outputs["Emission"], out.inputs["Surface"])
    field = bake(objects, mat, image_node, "field")
    shade, edgemask = field[..., 0], np.clip(field[..., 1], 0.0, 1.0)

    # Overlay: white lifts a facet, black sinks it, alpha is how far. The edge
    # line is white over whatever the facet was.
    lift = (shade - 0.5) * 2.0                     # -1..1
    rgb = np.where(lift[..., None] >= 0, 1.0, 0.0) * np.ones(3)
    alpha = np.where(lift >= 0, lift * LIFT_SHADE, -lift * SINK_SHADE)
    rgb = rgb * (1 - edgemask[..., None]) + edgemask[..., None]
    alpha = alpha * (1 - edgemask) + EDGE_ALPHA * edgemask
    colour = np.concatenate([rgb, alpha[..., None]], axis=-1)
    save("%s_%s_color" % (SKIN, group), colour, SIZE, False)

    # 3. Roughness, from the edge mask, at a quarter of the size.
    rough = ROUGH_FACET + (ROUGH_EDGE - ROUGH_FACET) * edgemask
    step = SIZE // ROUGH_SIZE
    small = rough[::step, ::step]
    save("%s_%s_roughness" % (SKIN, group),
         np.dstack([small, small, small, np.ones_like(small)]), ROUGH_SIZE, True)

print("DIAMOND DONE")
