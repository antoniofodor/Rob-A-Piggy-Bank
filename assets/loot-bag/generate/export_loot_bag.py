# -*- coding: utf-8 -*-
"""Export the shop's own loot sack as a Roblox-ready model.

    blender --background assets/shop-ui/icon-system-v1/sources/sack.blend \
            --python assets/loot-bag/generate/export_loot_bag.py

WHAT THIS IS FOR. `assets/shop-ui/icon-system-v1/sources/sack.blend` is the
scene the Bigger Sack shop icon is rendered from, and the designer's call of
2026-09-22 is that the loot a thief carries home has to look like that picture.
`UpgradePreview.builders.sack` builds it in primitives today so it reads right
before anything is uploaded; this is the same object as a MESH, for the
designer to upload under their own account. Nothing here uploads anything.

SIX MESHES, ONE PER MATERIAL, BECAUSE THE BLEND IS FLAT COLOURS.

There is not one image in that scene -- seven materials, every one a plain
Principled base colour, no texture node anywhere. So there is nothing to bake:
baking flat colour to a map would spend an upload and a UV set to say what a
`Color3` already says, and it would take the colours AWAY from the game, which
is the opposite of what this catalogue wants. Split per material instead and
each piece is a MeshPart the game can tint -- exactly the split
`Config.PIGGY_MESH` already uses for the pig's Body and Trim, one step further.

THE GREEN ARROW IS NOT PART OF THE SACK. It is the icon's own "bigger" tell and
it is excluded here; an arrow welded to a thief's chest would be a HUD element
stuck on the world.

THE TRIANGLE BUDGET IS THE ONE THING THAT MUST BE CHECKED. Roblox refuses a
MeshPart over 10,000 triangles, and the flared fabric opening alone comes in at
about fourteen thousand faces. Anything over `TRI_BUDGET` is decimated until it
fits, and the manifest records the before and after so a piece that lost its
shape can be found rather than discovered.
"""
import json
import math
import os
import sys

import bpy
import mathutils

# --------------------------------------------------------------------------
# WHERE, AND HOW BIG
# --------------------------------------------------------------------------

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(HERE)
PARTS_DIR = os.path.join(OUT, "parts")
PREVIEW_DIR = os.path.join(OUT, "preview")
for d in (OUT, PARTS_DIR, PREVIEW_DIR):
    os.makedirs(d, exist_ok=True)

# THE TARGET IS THE POSE, NOT THE PICTURE. `CarryPose.HOLD` was measured
# against a 2.2-stud mini piggy, and `UpgradePreview.builders.sack` builds its
# body as a 2.4 x 2.6 x 2.2 ball at level 0 (`s` = 0.8 there, so 1.92 x 2.08 x
# 1.76) standing 3.008 studs from the ground to the top of its own frill. A
# mesh that lands on the same overall height drops into the same weld with the
# same clearances.
#
# MEASURED OFF THE BUILDER RATHER THAN TYPED: the primitives sack is dumped
# per part through its own CFrame and its extents taken, which is the only way
# to get the frills right -- they are balls on a wave, so the top of the bag is
# a ball's crown rather than any number in the source.
TARGET_HEIGHT = 3.008

# ROBLOX REFUSES A MESHPART OVER 10,000 TRIANGLES, and that is the hard wall.
# It is not the number that matters here, though: this scene was authored for a
# 768-pixel icon render, and undecimated it is 37,500 triangles for an object
# three studs tall that is welded to a running character. The budgets below are
# what each piece needs to keep its SILHOUETTE -- the cloth carries the whole
# shape and gets most of it, a nostril is a dot and gets almost none -- and the
# manifest records the before and after so a piece that lost its shape can be
# found rather than discovered.
#
# PLANAR FIRST, THEN COLLAPSE. Planar decimation merges faces that are already
# in one plane, which costs nothing at all on the flat-shaded parts of this
# model; collapse is what actually rounds a shape off, so it only runs on what
# planar could not reach.
TRI_BUDGET = {
    "Cloth": 2600, "Lining": 700, "Rope": 1600,
    "Gold": 1200, "GoldDark": 600, "GoldLight": 600, "Nostril": 200,
}

# One mesh per colour the game might want to tint, which is per MATERIAL except
# where two things the game treats differently share one. The nostrils are
# `golddark` in the blend and PINK in `UpgradePreview`, so they come out on
# their own rather than being welded to the coin's recessed field for ever.
#
# `only` and `without` are object-name prefixes; the order is the order the
# manifest and UPLOADS.md list them, cloth outward.
SEGMENTS = [
    ("Cloth", "tan", None, None,
     "the sack itself: body, sat-down base and the outside of the flared mouth"),
    ("Lining", "wood", None, None,
     "the inside of the mouth, seen down the throat"),
    ("Rope", "brown", None, None,
     "the drawstring: the wrap, the knot, both bow loops and both tails"),
    ("Gold", "gold", None, None,
     "the coin's rolled rim and satin face, and the three coins at its foot"),
    ("GoldDark", "golddark", None, "PigSnout_Nostril",
     "the coin's recessed field, behind the snout"),
    ("GoldLight", "goldlight", None, None,
     "the pig snout embossed on the coin"),
    ("Nostril", "golddark", "PigSnout_Nostril", None,
     "the snout's two nostrils, which the game paints a different colour"),
]

# WHAT THE GAME PAINTS EACH PIECE, and it is not what the blend says. The blend
# is lit by Cycles studio lamps, so its raw `tan` is (231, 164, 83) -- an orange
# the artwork does not show. These are `UpgradePreview.builders.sack`'s own
# colours, sampled off the rendered icon, so the mesh and the primitives build
# land on the same object.
GAME_COLOUR = {
    "Cloth": [226, 182, 146],
    "Lining": [198, 138, 110],
    "Rope": [150, 96, 66],
    "Gold": [240, 198, 76],
    "GoldDark": [198, 150, 52],
    "GoldLight": [246, 206, 198],
    "Nostril": [150, 84, 92],
}

# Excluded from the export entirely; see the header.
DROP_OBJECTS = {"IncreaseArrow"}


def srgb(c):
    """A linear Blender channel as an 0-255 sRGB byte -- what a `Color3` wants.
    The two disagree by a long way: linear 0.7991 is 231, not 204."""
    if c <= 0.0031308:
        v = 12.92 * c
    else:
        v = 1.055 * (c ** (1.0 / 2.4)) - 0.055
    return int(round(255 * max(0.0, min(1.0, v))))


def material_colour(name):
    mat = bpy.data.materials.get(name)
    node = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    v = node.inputs["Base Color"].default_value
    return [srgb(v[0]), srgb(v[1]), srgb(v[2])]


def deselect():
    for o in bpy.data.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = None


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


# --------------------------------------------------------------------------
# BUILD ONE JOINED MESH PER MATERIAL
# --------------------------------------------------------------------------

sources = [o for o in bpy.data.objects
           if o.type == "MESH" and o.name not in DROP_OBJECTS]

built = {}
for seg_name, mat_name, only, without, _blurb in SEGMENTS:
    deselect()
    made = []
    for src in sources:
        mats = [m.name if m else None for m in src.data.materials]
        if mat_name not in mats:
            continue
        if only is not None and not src.name.startswith(only):
            continue
        if without is not None and src.name.startswith(without):
            continue
        copy = src.copy()
        copy.data = src.data.copy()
        copy.name = "TMP_%s_%s" % (seg_name, src.name)
        bpy.context.scene.collection.objects.link(copy)

        if len(mats) > 1:
            # Two materials on one object -- the flared opening carries the
            # cloth and its lining. Keep only the faces wearing this one.
            index = mats.index(mat_name)
            mesh = copy.data
            keep = [p.index for p in mesh.polygons if p.material_index == index]
            if not keep:
                bpy.data.objects.remove(copy, do_unlink=True)
                continue
            bpy.context.view_layer.objects.active = copy
            copy.select_set(True)
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.select_all(action="DESELECT")
            bpy.ops.object.mode_set(mode="OBJECT")
            for p in mesh.polygons:
                p.select = p.material_index != index
            bpy.ops.object.mode_set(mode="EDIT")
            bpy.ops.mesh.delete(type="FACE")
            bpy.ops.object.mode_set(mode="OBJECT")
            copy.select_set(False)
            bpy.context.view_layer.objects.active = None
        made.append(copy)

    if not made:
        print("[loot-bag] no geometry for %s (%s)" % (seg_name, mat_name))
        continue

    deselect()
    for o in made:
        o.select_set(True)
    bpy.context.view_layer.objects.active = made[0]
    if len(made) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = seg_name
    obj.data.name = seg_name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    deselect()
    built[seg_name] = obj

# Drop everything that is not a segment, a camera or a light, so the FBX
# carries the model and nothing else.
for o in list(bpy.data.objects):
    if o.type == "MESH" and o not in built.values():
        bpy.data.objects.remove(o, do_unlink=True)

# --------------------------------------------------------------------------
# TRIANGULATE, THEN DECIMATE ANYTHING OVER BUDGET
# --------------------------------------------------------------------------

budget = {}
for name, obj in built.items():
    deselect()
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    mod = obj.modifiers.new("Triangulate", "TRIANGULATE")
    mod.quad_method = "BEAUTY"
    bpy.ops.object.modifier_apply(modifier=mod.name)
    before = tri_count(obj)
    limit = TRI_BUDGET[name]
    if before > limit:
        planar = obj.modifiers.new("Planar", "DECIMATE")
        planar.decimate_type = "DISSOLVE"
        planar.angle_limit = math.radians(3.0)
        bpy.ops.object.modifier_apply(modifier=planar.name)
        tri = obj.modifiers.new("Retriangulate", "TRIANGULATE")
        tri.quad_method = "BEAUTY"
        bpy.ops.object.modifier_apply(modifier=tri.name)
    mid = tri_count(obj)
    after = mid
    if mid > limit:
        dec = obj.modifiers.new("Decimate", "DECIMATE")
        dec.decimate_type = "COLLAPSE"
        dec.ratio = float(limit) / float(mid)
        bpy.ops.object.modifier_apply(modifier=dec.name)
        after = tri_count(obj)
    budget[name] = (before, after)
    deselect()

# --------------------------------------------------------------------------
# SIZE AND SEAT: y = 0 AT THE BASE, THE BODY'S OWN CENTRE ON THE AXIS
# --------------------------------------------------------------------------

def world_bounds(objs):
    lo = [1e9] * 3
    hi = [-1e9] * 3
    for o in objs:
        for c in o.bound_box:
            p = o.matrix_world @ mathutils.Vector(c)
            for i in range(3):
                lo[i] = min(lo[i], p[i])
                hi[i] = max(hi[i], p[i])
    return lo, hi


lo, hi = world_bounds(built.values())
scale = TARGET_HEIGHT / (hi[2] - lo[2])
# The SACK's own axis, not the bounding box's: the coins at its foot are off to
# one side on purpose, and centring on them would lean the whole bag.
cloth = built["Cloth"]
clo, chi = world_bounds([cloth])
axis_x = (clo[0] + chi[0]) / 2.0
axis_y = (clo[1] + chi[1]) / 2.0

for obj in built.values():
    obj.scale = (scale, scale, scale)
    obj.location = (
        -axis_x * scale,
        -axis_y * scale,
        -lo[2] * scale,
    )
    deselect()
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    deselect()

# --------------------------------------------------------------------------
# EXPORT
# --------------------------------------------------------------------------
#
# ROBLOX IS Y-UP AND BLENDER IS Z-UP, so every export takes
# axis_up="Y", axis_forward="-Z": Blender (x, y, z) arrives as (x, z, -y). The
# coin is on Blender -Y, so it arrives facing Roblox +Z -- the same way round
# `UpgradePreview` builds it, and the way `CarryPose.HOLD` then turns to face
# the street.

def export_fbx(path, objs):
    deselect()
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(
        filepath=path, use_selection=True, apply_unit_scale=True,
        global_scale=1.0, axis_up="Y", axis_forward="-Z",
        object_types={"MESH"}, use_mesh_modifiers=True,
        mesh_smooth_type="FACE", bake_space_transform=False,
        path_mode="COPY", embed_textures=False,
    )
    deselect()


def export_obj(path, objs):
    deselect()
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    kwargs = dict(filepath=path, export_selected_objects=True,
                  forward_axis="NEGATIVE_Z", up_axis="Y",
                  export_materials=True, export_uv=True, export_normals=True,
                  export_triangulated_mesh=True)
    bpy.ops.wm.obj_export(**kwargs)
    deselect()


order = [row[0] for row in SEGMENTS if row[0] in built]
whole = [built[n] for n in order]

export_fbx(os.path.join(OUT, "loot-bag.fbx"), whole)
export_obj(os.path.join(OUT, "loot-bag.obj"), whole)
for name in order:
    export_fbx(os.path.join(PARTS_DIR, "loot-bag-%s.fbx" % name.lower()), [built[name]])
    export_obj(os.path.join(PARTS_DIR, "loot-bag-%s.obj" % name.lower()), [built[name]])

# --------------------------------------------------------------------------
# THE MANIFEST: WHAT CONFIG NEEDS, IN ROBLOX'S OWN AXES AND UNITS
# --------------------------------------------------------------------------

manifest = {
    "source": "assets/shop-ui/icon-system-v1/sources/sack.blend",
    "artwork": "assets/shop-ui/icon-system-v1/sack.png",
    "blender": bpy.app.version_string,
    "textured": False,
    "note": ("The blend is flat material colours -- seven Principled base "
             "colours and not one image -- so there is nothing to bake and "
             "the split is per material, the way Config.PIGGY_MESH splits "
             "Body from Trim."),
    "axes": "exported axis_up=Y, axis_forward=-Z; Blender (x, y, z) arrives as (x, z, -y)",
    "scale": round(scale, 6),
    "targetHeightStuds": TARGET_HEIGHT,
    "segments": [],
}

for name, mat_name, _only, _without, blurb in SEGMENTS:
    if name not in built:
        continue
    obj = built[name]
    blo, bhi = world_bounds([obj])
    # Blender -> Roblox
    centre = [(blo[i] + bhi[i]) / 2.0 for i in range(3)]
    size = [bhi[i] - blo[i] for i in range(3)]
    before, after = budget[name]
    manifest["segments"].append({
        "part": name,
        "material": mat_name,
        "what": blurb,
        "blendColour": material_colour(mat_name),
        "gameColour": GAME_COLOUR[name],
        "offset": [round(centre[0], 4), round(centre[2], 4), round(-centre[1], 4)],
        "size": [round(size[0], 4), round(size[2], 4), round(size[1], 4)],
        "triangles": after,
        "trianglesBeforeDecimate": before,
        "fbx": "parts/loot-bag-%s.fbx" % name.lower(),
        "obj": "parts/loot-bag-%s.obj" % name.lower(),
    })

wlo, whi = world_bounds(built.values())
manifest["whole"] = {
    "size": [round(whi[0] - wlo[0], 4), round(whi[2] - wlo[2], 4), round(whi[1] - wlo[1], 4)],
    "baseAtY": round(wlo[2], 4),
    "triangles": sum(budget[n][1] for n in order),
}

with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8") as fh:
    json.dump(manifest, fh, indent=1)
    fh.write("\n")

# --------------------------------------------------------------------------
# PREVIEWS
# --------------------------------------------------------------------------

scene = bpy.context.scene
scene.render.resolution_x = 640
scene.render.resolution_y = 640
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
if scene.render.engine == "CYCLES":
    scene.cycles.samples = 96

cam = bpy.data.objects.get("IconCamera")
if cam is not None:
    scene.camera = cam
    target = mathutils.Vector((0.0, 0.0, TARGET_HEIGHT * 0.45))
    radius = 11.0

    def shoot(name, yaw_deg, pitch_deg):
        yaw = math.radians(yaw_deg)
        pitch = math.radians(pitch_deg)
        eye = target + mathutils.Vector((
            radius * math.cos(pitch) * math.sin(yaw),
            -radius * math.cos(pitch) * math.cos(yaw),
            radius * math.sin(pitch),
        ))
        cam.location = eye
        direction = (target - eye).normalized()
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(PREVIEW_DIR, name)
        bpy.ops.render.render(write_still=True)

    shoot("loot-bag-hero.png", 22.0, 14.0)
    shoot("loot-bag-front.png", 0.0, 4.0)
    shoot("loot-bag-side.png", 90.0, 6.0)

print("[loot-bag] scale %.5f, whole %s studs, %d triangles"
      % (scale, manifest["whole"]["size"], manifest["whole"]["triangles"]))
for s in manifest["segments"]:
    print("[loot-bag]   %-9s %6d tris (was %6d)  size %s  offset %s  rgb %s"
          % (s["part"], s["triangles"], s["trianglesBeforeDecimate"],
             s["size"], s["offset"], s["gameColour"]))
