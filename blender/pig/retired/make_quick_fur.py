# -*- coding: utf-8 -*-
"""Blender QUICK FUR on the pig -- the real-hair route, tried and measured.

    "/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" \
        --background --python make_quick_fur.py

This is the tutorial route: Object -> Quick Effects -> Quick Fur, a Principled
Hair BSDF, then the two dials that matter (radius on Set Hair Curve Profile,
density on Interpolate Hair Curves). It is built here as its own script rather
than folded into `make_fur_tufts.py` because THE TWO ARE NOT ALTERNATIVES --
see the count this prints.

WHAT QUICK FUR ACTUALLY MAKES. A `Curves` object carrying a geometry-nodes
tree. The strands have no thickness anywhere in the scene: the renderer grows
a tube around each curve at render time from its radius attribute. So the fur
exists in Cycles and in Eevee and NOWHERE ELSE -- there is no mesh to export,
and Roblox has no curve primitive, no hair system and no shader that could
grow one.

SO THE ONLY ROUTE TO ROBLOX IS TO TURN EVERY STRAND INTO TUBES, and that is
the number this script prints. A Roblox MeshPart caps at 10,000 triangles.
Whatever the count comes out at, compare it against that before believing
this is a shippable asset rather than a picture.

WHICH DOES NOT MAKE IT USELESS, AND THAT IS THE POINT OF KEEPING IT. What it
is genuinely for is BAKING: this is the standard game-art pipeline -- simulate
or groom real fur, render it, and bake the result down into the maps a game
engine can actually sample. `skins/animal/pig_fur_normal.png` is a hand-authored
noise map doing that job today, and a bake off this groom would be the honest
version of the same thing.
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

import bpy, math, os
from mathutils import Vector

D = os.path.dirname(os.path.abspath(__file__))

# RENDERS GO IN `renders/`, NEVER BESIDE THE ASSETS. Every picture this script
# writes is reproducible by running it again, and the folder it used to write
# into holds the .obj files that actually ship -- so a session of previewing
# buried the deliverables under 46 screenshots and 17 MB. `.gitignore` already
# refuses *.png outside `skins/`, so nothing here was ever committed; what it
# could not do is stop them piling up on disk.
RENDERS = paths.RENDERS
os.makedirs(RENDERS, exist_ok=True)

bpy.ops.wm.open_mainfile(filepath=paths.RAW)
scene = bpy.context.scene

body = bpy.data.objects["Body"]
trim = bpy.data.objects["Trim"]

# ---------------------------------------------------------------- the dials
# The pig is about 1.0 in radius here and 12 studs across in game, so a LENGTH
# of 0.05 is about a third of a stud -- short fluffy fur rather than a coat.
# The tutorial's default 0.10 is twice that and reads as a long-haired cat.
LENGTH = 0.050

# RADIUS AND DENSITY ARE ONE DECISION, AND THE FIRST BUILD TREATED THEM AS
# NONE. It ran the operator's own defaults and got 98,985 strands at radius
# 0.003 over a body of about 12.6 square units -- which is TWENTY-TWO PER CENT
# of the surface actually covered by a strand. Reported as looking like a
# dropped lollipop, which is exactly what a fifth of a coat is: lint stuck on
# rather than fur grown out.
#
# SO COVERAGE IS SOLVED FOR RATHER THAN TUNED. A strand covers a disc of its
# own radius, tapered along its length, so the surface a groom actually hides
# is `count * pi * (taper * radius)^2 / area`. Real fur overlaps itself many
# times over; anything under 1.0 has bare skin showing between strands BY
# ARITHMETIC, whatever the seed happens to do.
RADIUS = 0.0100     # strand thickness. The operator's default 0.001 is a hair
                    # on a human head; on a twelve-stud animal read from the
                    # pavement it is invisible, and covering the body with
                    # hairs that thin needs millions of them.
COVERAGE = 3.0      # times over. Not 1.0: a Poisson scatter at exactly one
                    # coverage still leaves visible gaps, because random
                    # placement clumps. Two-and-a-bit is where it reads solid.
TAPER = 0.62        # the profile thins root to tip, so a strand's average
                    # radius is well under its stated one. Measured off the
                    # shipped Shape rather than assumed.
DENSITY = 'HIGH'    # the GUIDE density. The interpolated density below is
                    # what actually decides the coat.

def point_at(ob, tgt):
    ob.rotation_euler = (Vector(tgt) - ob.location).to_track_quat('-Z', 'Y').to_euler()


# ------------------------------------------- the surface the fur grows from
# FUR GROWS ON A COPY OF THE BODY, NOT ON THE BODY, and that one decision
# solves three separate problems at once.
#
# ONE: THE EYES. Reported -- the eyes were buried. A density mask is the
# obvious fix and it fights the guide system, which places strands of its own;
# DELETING THE FACES cannot be argued with, because fur has nowhere to grow
# from. Anything else that must stay bald later -- the vault hatch, the coin
# slot -- is one more cone in `BALD` rather than a new mechanism.
#
# TWO: THE COAT CAME OUT IN CONTINENTS, AND THE UV MAP IS WHY. A HAIR ROOT IS
# STORED AS A UV COORDINATE, not as a point on a face, so a groom is only as
# good as the unwrap it is attached through -- and the shipped unwrap is not
# usable for it. `uv_cylinder` fixes the wrap seam by pushing the low corners
# of any face that spans it past 1.0, so u runs to 1.500 and the layout covers
# 1.59 OF THE UNIT SQUARE: it overlaps itself, and a reverse lookup from a UV
# to a surface point is therefore ambiguous across the whole overlap. Measured
# either way on a BLUE pig so a gap shouts -- shipped map, islands of fur on
# bare skin; a clean `smart_project` at 0.66 of the square, a full coat.
#
# THREE: THE SHIPPED BODY KEEPS EXACTLY ONE UV MAP. The first fix for two put
# a second unwrap on the Body itself, which works and quietly makes the asset
# carry a UV set the game will never sample and a Roblox MeshPart cannot even
# hold. On a copy it costs the shipped mesh nothing.
# THE EYEBALLS THEMSELVES, as (centre, radius) in body units, measured off
# `EyePreview` in the blend rather than typed.
#
# A CONE WAS THE WRONG TEST AND EVERY VALUE OF IT WAS WRONG. It went 11, 9,
# then 6.5 degrees against an eye that subtends 5.95, and a bare ring was
# still visible -- because the cut deletes whole FACES, and a face is about
# 2.6 degrees across, so a 6.5-degree cone actually clears to nearly 7.8. The
# margin nobody wanted was granularity rather than the number.
#
# So the test is the EYE SPHERE: a face goes if its centre is inside the ball.
# That is the eyeball's real footprint, it needs no margin to be chosen, and
# it cannot drift if the eye ever moves. The remaining overshoot is one face,
# which the finer scaffold below makes small -- and the gap is MEASURED and
# printed afterwards rather than judged from a render.
EYES = [
    (Vector((-0.3181, -0.8888, 0.3636)), 0.105),
    (Vector((0.3181, -0.8888, 0.3636)), 0.105),
]

surface = body.copy()
surface.data = body.data.copy()
surface.name = "FurSurface"
scene.collection.objects.link(surface)
surface.hide_render = True      # it is scaffolding; the real Body is drawn

import bmesh as _bm

bmsh = _bm.new()
bmsh.from_mesh(surface.data)

# SUBDIVIDED BEFORE CUTTING, because the cut is per FACE and the body is only
# about four faces across an eye. At the shipped density the bald patch came
# out as a visible STAIRCASE -- a rectangular notch on the cheek, which reads
# as a hole in the model rather than as the bare rim an animal has round its
# eye. TWO cuts make the boundary nine times finer and cost nothing: this
# object is scaffolding that is never exported and never rendered.
_bm.ops.subdivide_edges(bmsh, edges=list(bmsh.edges), cuts=2,
                        use_grid_fill=True)
print("fur scaffold subdivided to %d faces" % len(bmsh.faces))

cut = []
kept = []
for f in bmsh.faces:
    c = f.calc_center_median()
    if any((c - eye).length < r for eye, r in EYES):
        cut.append(f)
    else:
        kept.append(c.copy())
_bm.ops.delete(bmsh, geom=cut, context='FACES')
bmsh.to_mesh(surface.data)
bmsh.free()
print("bald patches: cut %d faces, %d remain" % (len(cut), len(kept)))

# HOW BIG IS THE BARE RING, IN STUDS. The eyeball meets the body at a known
# angle; the nearest surviving face centre is where fur can first grow. The
# difference is the gap, and it is the only honest way to answer "is there
# space between the fur and the eye" -- a three-quarter render flatters it and
# a face-on one exaggerates it.
STUDS_PER_UNIT = 6.0        # the pig is 12 studs across and 2.0 units
for i, (eye, r) in enumerate(EYES):
    axis = eye.normalized()
    d = eye.length
    # angular radius of the circle where the eyeball cuts the body surface
    a = (d * d + 1.0 - r * r) / (2.0 * d)
    h = math.sqrt(max(0.0, 1.0 - a * a))
    eye_deg = math.degrees(math.atan2(h, a))
    near = min(math.degrees(math.acos(max(-1.0, min(1.0, c.normalized().dot(axis)))))
               for c in kept)
    gap = math.radians(near - eye_deg) * STUDS_PER_UNIT
    print("  eye %d: rim at %.2f deg, nearest fur at %.2f deg -> gap %.3f studs"
          % (i, eye_deg, near, gap))

ROOT_UV = "FurRoots"
bpy.ops.object.select_all(action='DESELECT')
surface.select_set(True)
bpy.context.view_layer.objects.active = surface
while surface.data.uv_layers:
    surface.data.uv_layers.remove(surface.data.uv_layers[0])
surface.data.uv_layers.new(name=ROOT_UV)
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.01)
bpy.ops.object.mode_set(mode='OBJECT')


def uv_area(ob, name):
    """Total UV area. Over 1.0 means the layout overlaps itself."""
    layer = ob.data.uv_layers[name].data
    tot = 0.0
    for poly in ob.data.polygons:
        pts = [layer[i].uv for i in poly.loop_indices]
        a = 0.0
        for i in range(len(pts)):
            x1, y1 = pts[i]
            x2, y2 = pts[(i + 1) % len(pts)]
            a += x1 * y2 - x2 * y1
        tot += abs(a) * 0.5
    return tot


print("uv area  Body/UVMap %.3f (shipped, self-overlapping)   FurSurface/%s %.3f"
      % (uv_area(body, "UVMap"), ROOT_UV, uv_area(surface, ROOT_UV)))

# ---------------------------------------------------------------- quick fur
bpy.ops.object.quick_fur(density=DENSITY, length=LENGTH, radius=RADIUS,
                         view_percentage=1.0, apply_hair_guides=True,
                         use_noise=True, use_frizz=True)

fur = None
for ob in scene.objects:
    if ob.type == 'CURVES':
        fur = ob
print("fur object:", fur.name if fur else "NONE")
print("modifiers:", [m.name for m in fur.modifiers] if fur else [])

# nailed to the clean map explicitly rather than left on whatever happened to
# be active, so this cannot quietly regress if the layer order ever changes
fur.data.surface_uv_map = ROOT_UV
print("roots attached through:", fur.data.surface_uv_map,
      "| shipped Body still carries:", [l.name for l in body.data.uv_layers])


# ------------------------------------------------ mute the dynamics solver
# HAIR DYNAMICS IS A SIMULATION AND THIS IS A STILL. Left on, it settles the
# strands against gravity from frame 1 -- in a background render that means
# they lie over in whatever half-solved state the first frame reached, which
# CLUMPS them and is the other half of the uneven coat. A groom for baking
# wants the rest pose.
for m in fur.modifiers:
    if m.name == "Hair Dynamics":
        m.show_viewport = False
        m.show_render = False
        print("muted", m.name)


def mod(name):
    return fur.modifiers[name]


def set_in(m, ident, value):
    """Write one geometry-nodes modifier input.

    BLENDER 5.2 MOVED THESE OFF IDPROPERTIES, which is worth a line because
    every tutorial and every answer online still says `modifier["Input_3"]`.
    That now raises `bpy_struct[key] = val: id properties not supported for
    this type` -- an error that names the assignment and says nothing about
    the API having changed. It is
    `modifier.properties.inputs.<identifier>.value` in 5.2.
    """
    setattr(getattr(m.properties.inputs, ident), "value", value)


def get_in(m, ident):
    return getattr(getattr(m.properties.inputs, ident), "value")


def area_of(ob):
    """The body's real surface area, from the mesh rather than from a sphere."""
    dg0 = bpy.context.evaluated_depsgraph_get()
    me = ob.evaluated_get(dg0).to_mesh()
    a = sum(p.area for p in me.polygons)
    ob.evaluated_get(dg0).to_mesh_clear()
    return a


AREA = area_of(surface)

# the radius, replacing whatever the operator baked in
prof = mod("Set Hair Curve Profile")
set_in(prof, "Input_6", True)          # Replace Radius
set_in(prof, "Input_3", RADIUS)

# NOISE AND FRIZZ COME DOWN, because both move strands SIDEWAYS off their own
# root -- which is decorative on a sparse groom and is a gap-maker on a dense
# one, since every strand that wanders leaves the spot it was covering bare.
noise = mod("Hair Curves Noise")
set_in(noise, "Input_3", 0.35)
frizz = mod("Frizz Hair Curves")
set_in(frizz, "Input_3", 0.25)

interp = mod("Interpolate Hair Curves")


def strand_count():
    """Evaluate the groom and count what came out.

    `update_tag` AND `depsgraph.update` ARE BOTH REQUIRED, and leaving them
    out does not error -- it silently returns the PREVIOUS count. The first
    solve here read 98,985 strands at density 1000 and 98,985 again at 4442,
    concluded density does nothing, and would have shipped a coverage figure
    that was pure fiction. A stale read looks exactly like a dial that is not
    connected to anything.
    """
    fur.update_tag()
    dg1 = bpy.context.evaluated_depsgraph_get()
    dg1.update()
    return len(fur.evaluated_get(dg1).data.curves)


# HOW MANY STRANDS THE COVERAGE ASKS FOR
target = COVERAGE * AREA / (math.pi * (TAPER * RADIUS) ** 2)

# SOLVED IN ONE STEP RATHER THAN SWEPT, because count is LINEAR in density --
# so one measurement of the current pair gives the scale factor exactly. A
# sweep would have been several minutes of evaluation to find a number that
# arithmetic already knows.
set_in(interp, "Input_15", 1000.0)
bpy.context.view_layer.update()
n0 = strand_count()
density = 1000.0 * target / max(1, n0)
set_in(interp, "Input_15", density)
bpy.context.view_layer.update()
n1 = strand_count()

print("")
print("=== COVERAGE SOLVE ===")
print("  body surface        %.3f sq units" % AREA)
print("  radius %.4f taper %.2f -> a strand covers %.3e" % (RADIUS, TAPER, math.pi * (TAPER * RADIUS) ** 2))
print("  want %.1fx coverage -> %s strands" % (COVERAGE, format(int(target), ",")))
print("  density %.1f at 1000 gave %s; solved to %.1f -> %s strands"
      % (COVERAGE, format(n0, ","), density, format(n1, ",")))
print("  actual coverage      %.2fx"
      % (n1 * math.pi * (TAPER * RADIUS) ** 2 / AREA))
print("")

# PRINCIPLED HAIR BSDF, which is the shader the tutorial swaps in. It is a
# different BSDF from Principled: it models light travelling ALONG a strand,
# which is what stops fur reading as a bundle of plastic wires.
hair = bpy.data.materials.new("FurHair")
hair.use_nodes = True
nt = hair.node_tree
for n in list(nt.nodes):
    if n.type != 'OUTPUT_MATERIAL':
        nt.nodes.remove(n)
out = [n for n in nt.nodes if n.type == 'OUTPUT_MATERIAL'][0]
bsdf = nt.nodes.new("ShaderNodeBsdfHairPrincipled")
bsdf.location = (-300, 0)
for key, val in (("Color", (0.83, 0.44, 0.12, 1.0)),
                 ("Roughness", 0.42),
                 ("Radial Roughness", 0.32)):
    if key in bsdf.inputs:
        bsdf.inputs[key].default_value = val
nt.links.new(bsdf.outputs[0], out.inputs["Surface"])
fur.data.materials.clear()
fur.data.materials.append(hair)

# ------------------------------------------------------- what it would cost
# THE MEASUREMENT THIS SCRIPT EXISTS FOR. The strands are evaluated through
# the geometry-nodes tree, then counted as though each segment were extruded
# into a four-sided tube -- the cheapest tube anybody would ship.
dg = bpy.context.evaluated_depsgraph_get()
ev = fur.evaluated_get(dg)
curves = ev.data
strands = len(curves.curves)
points = len(curves.points)
segments = max(0, points - strands)
SIDES = 4
tube_tris = segments * SIDES * 2 + strands * (SIDES - 2)

print("")
print("=== QUICK FUR, AS GEOMETRY ===")
print("  %d strands, %d points, %d segments" % (strands, points, segments))
print("  as %d-sided tubes: %s triangles" % (SIDES, format(tube_tris, ",")))
print("  a Roblox MeshPart caps at 10,000 -- this is %.0fx over"
      % (tube_tris / 10000.0))
print("")

# ---------------------------------------------------------------- the look
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.60, 0.68, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.55

for nm, loc, en, sz in (("key", (-4.0, -5.0, 4.5), 700, 5.0),
                        ("fill", (5.0, -3.0, 1.5), 260, 7.0),
                        ("rim", (1.0, 4.5, 4.0), 320, 5.0)):
    ld = bpy.data.lights.new(nm, type='AREA')
    ld.energy, ld.size = en, sz
    o = bpy.data.objects.new(nm, ld)
    scene.collection.objects.link(o)
    o.location = Vector(loc)
    point_at(o, (0, 0, 0.05))

cam_d = bpy.data.cameras.new("c")
cam_d.lens = 62
cam = bpy.data.objects.new("c", cam_d)
scene.collection.objects.link(cam)
scene.camera = cam

scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = 64
scene.cycles.use_denoising = True
scene.render.resolution_x = 560
scene.render.resolution_y = 560
scene.view_settings.view_transform = 'Standard'

TIGER = (0.914, 0.478, 0.106, 1)
TIGER_T = (0.980, 0.949, 0.910, 1)


def flat(name, col):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = col
    b.inputs["Roughness"].default_value = 0.78
    b.inputs["Metallic"].default_value = 0.0
    return m


body.data.materials.clear()
body.data.materials.append(flat("qf_body", TIGER))
trim.data.materials.clear()
trim.data.materials.append(flat("qf_trim", TIGER_T))
eye = bpy.data.objects.get("EyePreview")
if eye:
    eye.data.materials.clear()
    eye.data.materials.append(flat("qf_eye", (0.02, 0.02, 0.03, 1)))

for name, loc, tgt in (
        ("quickfur_tiger.png", (-3.9, -5.4, 2.0), (0.0, -0.05, 0.05)),
        ("quickfur_side.png", (-7.2, 0.0, 0.9), (0.0, 0.0, 0.1)),
        ("quickfur_close.png", (-1.9, -2.9, 2.6), (-0.05, -0.15, 0.85)),
        # THE VIEW IT WAS REPORTED FROM: straight down onto the face, where a
        # bare ring round an eye is most obvious and a three-quarter shot
        # flatters it.
        ("quickfur_face.png", (0.0, -2.05, 2.35), (0.0, -0.62, 0.40))):
    cam.location = Vector(loc)
    point_at(cam, tgt)
    scene.render.filepath = os.path.join(RENDERS, name)
    bpy.ops.render.render(write_still=True)
    print("rendered", scene.render.filepath)

# SAVED AS THE BASE COAT. This groom is the "normal fur" animal -- no
# pattern, no markings -- and everything else in the animal pack is that plus
# a colour map. The name says which of those it is.
bpy.ops.wm.save_as_mainfile(filepath=paths.pig("pig_fur_base.blend"))
