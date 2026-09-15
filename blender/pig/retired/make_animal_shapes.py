# -*- coding: utf-8 -*-
"""Build MODELLED animal markings -- raised low-poly plates, not texture.

    "/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" \
        --background --python make_animal_shapes.py

WHY THIS EXISTS ALONGSIDE `make_animal_maps.py`. A painted marking is flat: it
is the body's own surface with a different colour on it, and at any distance
it reads as a decal. A MODELLED marking stands off the body, catches the sun
on its own facets and breaks the silhouette at the edge of the animal -- which
is the whole reason the fur tufts read and the fur grain did not.

IT IS THE SAME PIPELINE AS THE TUFTS AND DELIBERATELY SO. Every plate is
seated by `body.ray_cast` against the real mesh rather than against a fitted
ellipsoid; the mesh is exported in STUDS with `global_scale`; and it carries
the BODY'S OWN cylindrical UVs so it can wear the same pattern pack if it is
ever wanted. Three separate bugs this project has already paid for, avoided by
copying a file that has them fixed.

WHAT IT COSTS AGAINST A MAP, STATED PLAINLY. A map is one upload, no
triangles, and works on every animal that shares the pattern. A modelled set
is one upload PER PATTERN, costs triangles on every pig on the street, and has
to be swept against all four accessory anchors -- because unlike a texture,
geometry can stand in the place a player's hat goes.
"""

# --- find the toolkit, wherever this script has been filed ------------------
# Walks up from this file until it finds the folder holding `paths.py`. Depth
# independent on purpose: a script in `make/` and a script in `skins/tiger/`
# are two and three levels down, and a hardcoded `..` is a thing that breaks
# silently the first time anything is refiled.
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
D = _root

import paths   # noqa: E402 -- the one place that knows the layout

import bpy, bmesh, math, os, random, sys
from mathutils import Vector

import pig_uv

bpy.ops.wm.open_mainfile(filepath=paths.RAW)

body = bpy.data.objects["Body"]
trim = bpy.data.objects["Trim"]

GAME_BODY_X = 12.0
_bx = [v.co.x for v in body.data.vertices]
SCALE = GAME_BODY_X / (max(_bx) - min(_bx))

SIDES = 8           # a marking is a SHAPE seen flat-on, so its outline is
                    # looked at directly -- more sides than a tuft needs
SEED = 20260908


def surface_hit(direction):
    origin = direction * 4.0
    ok, loc, nor, _ = body.ray_cast(origin, -direction)
    if not ok:
        return None, None
    return loc, nor


def direction(lon_deg, lat_deg):
    if lat_deg > 90.0:
        lat_deg, lon_deg = 180.0 - lat_deg, lon_deg + 180.0
    lon, lat = math.radians(lon_deg), math.radians(lat_deg)
    return Vector((math.cos(lat) * math.sin(lon),
                   -math.cos(lat) * math.cos(lon),
                   math.sin(lat))).normalized()


def add_plate(bm, base, normal, radius, rise, squash, phase):
    """One raised marking: a rim ring sunk into the skin and a domed cap.

    SUNK AT THE RIM AND PROUD AT THE CENTRE, which is what stops it reading as
    a coin lying on the pig. A plate whose whole outline sits on the surface
    shows a hard shadow line all the way round; one whose rim is buried
    appears to GROW out of the body, and only the dome is ever seen.
    """
    up = normal.normalized()
    ref = Vector((0, 0, 1)) if abs(up.z) < 0.9 else Vector((1, 0, 0))
    x = up.cross(ref).normalized()
    y = up.cross(x).normalized()

    rim, cap = [], []
    for i in range(SIDES):
        a = phase + (i / SIDES) * math.tau
        off = x * (math.cos(a) * radius * squash) + y * (math.sin(a) * radius)
        rim.append(bm.verts.new(base + off - up * (radius * 0.22)))
        cap.append(bm.verts.new(base + off * 0.72 + up * rise))
    crown = bm.verts.new(base + up * (rise * 1.35))
    n = 0
    for i in range(SIDES):
        j = (i + 1) % SIDES
        bm.faces.new((rim[i], rim[j], cap[j], cap[i]))
        bm.faces.new((cap[i], cap[j], crown))
        n += 3
    return n


# --------------------------------------------------------------- the sets
# Each entry is one animal's markings. Positions are the SAME lattice the map
# generator uses, so the modelled version and the painted one are the same
# animal rather than two different takes on it.
SETS = {
    # A ladybug's spots are the clearest case for modelling: few, large, and
    # perfectly round, so each one is a shape rather than a texture.
    "ladybug": dict(
        lattice=(6, 4), radius=(0.20, 0.26), rise=(0.035, 0.055),
        # THE TOP TWO ROWS AND THE BOTTOM ROW ARE SKIPPED. Anything on the
        # crown stands in the hat anchor, and the belly is never seen.
        lat=(-6, 62), lon=(-180, 180),
    ),
}


# THE ANCHORS, IN PLOT STUDS, AND A PLATE MAY NOT COME NEAR ONE. This is the
# tax geometry pays and a texture does not: a painted spot behind somebody's
# hat is invisible and harmless, and a MODELLED one is a lump inside a thing
# the player rolled for. The first build put a plate 0.57 studs from the eyes
# anchor and 1.49 from the back one -- glasses and a cape respectively.
ANCHORS = {"hat": Vector((0, 14.15, 0)),
           "eyes": Vector((0, 10.6, 5.9)),
           "back": Vector((0, 11.0, -5.6))}
ANCHOR_KEEPOUT = 2.6        # studs, measured to the anchor POINT


def _to_plot(co, bmid):
    """Blender local -> plot studs, the same transform the export applies."""
    return Vector(((co.x - bmid.x) * SCALE, (co.z - bmid.z) * SCALE,
                   -(co.y - bmid.y) * SCALE)) + Vector((0.0, 6.62, 0.0835))


def build(name, spec):
    rng = random.Random(SEED)
    bm = bmesh.new()
    tris = 0
    placed = 0
    skipped = 0
    bmin_l = Vector((min(v.co.x for v in body.data.vertices),
                     min(v.co.y for v in body.data.vertices),
                     min(v.co.z for v in body.data.vertices)))
    bmax_l = Vector((max(v.co.x for v in body.data.vertices),
                     max(v.co.y for v in body.data.vertices),
                     max(v.co.z for v in body.data.vertices)))
    bmid_local = (bmin_l + bmax_l) * 0.5
    NU, NV = spec["lattice"]
    for i in range(NU):
        for j in range(NV):
            lon = spec["lon"][0] + (spec["lon"][1] - spec["lon"][0]) * (
                (i + 0.28 + 0.44 * rng.random()) / NU)
            lat = spec["lat"][0] + (spec["lat"][1] - spec["lat"][0]) * (
                (j + 0.28 + 0.44 * rng.random()) / NV)
            loc, nor = surface_hit(direction(lon, lat))
            if loc is None:
                continue
            # REFUSED RATHER THAN NUDGED. Moving a plate out of an anchor just
            # moves the problem to wherever it lands; a gap where the hat goes
            # is what the mane already does and it reads as deliberate.
            here = _to_plot(loc, bmid_local)
            if any((here - av).length < ANCHOR_KEEPOUT for av in ANCHORS.values()):
                skipped += 1
                continue
            tris += add_plate(bm, loc, nor,
                              rng.uniform(*spec["radius"]),
                              rng.uniform(*spec["rise"]),
                              rng.uniform(0.86, 1.0),
                              rng.uniform(0, math.tau))
            placed += 1

    me = bpy.data.meshes.new("Marks_" + name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new("Marks_" + name, me)
    bpy.context.scene.collection.objects.link(ob)

    # the body's own cylinder, so a plate can wear the body's pack
    # the shared pinned range, never re-measured here -- see pig_uv.py
    zmin, span = pig_uv.UV_Z0, pig_uv.UV_SPAN
    uvl = me.uv_layers.new(name="UVMap")
    for p in me.polygons:
        us = []
        for li in p.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            u = (math.atan2(co.y, co.x) / (2.0 * math.pi)) + 0.5
            vv = (co.z - zmin) / span
            uvl.data[li].uv = (u, vv)
            us.append((li, u, vv))
        if max(q[1] for q in us) - min(q[1] for q in us) > 0.5:
            for li, u, vv in us:
                if u < 0.5:
                    uvl.data[li].uv = (u + 1.0, vv)

    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.shade_flat()

    print("")
    print("=== %s ===" % name.upper())
    print("  %d plates (%d refused for standing in an anchor), %d verts, %d tris"
          % (placed, skipped, len(me.vertices), tris))

    # THE ANCHOR SWEEP, WHICH A TEXTURE NEVER NEEDS AND GEOMETRY ALWAYS DOES.
    body_off = Vector((0.0, 6.62, 0.0835))
    bmin = Vector((min(v.co.x for v in body.data.vertices),
                   min(v.co.y for v in body.data.vertices),
                   min(v.co.z for v in body.data.vertices)))
    bmax = Vector((max(v.co.x for v in body.data.vertices),
                   max(v.co.y for v in body.data.vertices),
                   max(v.co.z for v in body.data.vertices)))
    bmid = (bmin + bmax) * 0.5
    # NOTE: no local ANCHORS here. Defining one shadowed the module-level
    # table for the WHOLE function, so the keep-out test above it read a local
    # that had not been assigned yet -- Python scoping, not a typo, and it
    # fails at the first plate rather than at the line that looks wrong.
    pts = []
    for v in me.vertices:
        c = v.co
        # blender (x, y, z) -> roblox (x, z, -y), scaled, then seated
        p = Vector(((c.x - bmid.x) * SCALE, (c.z - bmid.z) * SCALE,
                    -(c.y - bmid.y) * SCALE)) + body_off
        pts.append(p)
    for an, av in ANCHORS.items():
        d = min((p - av).length for p in pts)
        flag = "OK" if d >= 1.5 else "TOO CLOSE"
        print("  clearance to the %-4s anchor: %.2f studs   %s" % (an, d, flag))

    path = paths.pig("pig_marks_%s.obj" % name)
    bpy.ops.wm.obj_export(filepath=path, export_selected_objects=True,
                          export_uv=True, export_normals=True,
                          export_materials=False, forward_axis='NEGATIVE_Z',
                          up_axis='Y', global_scale=SCALE,
                          export_triangulated_mesh=True)
    print("  exported", path)
    return ob


for _name, _spec in SETS.items():
    build(_name, _spec)

bpy.ops.wm.save_as_mainfile(filepath=paths.pig("pig_shapes.blend"))
