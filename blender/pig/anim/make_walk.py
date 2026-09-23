# -*- coding: utf-8 -*-
"""The pig's WALK: a rig, a trot cycle, and the body curve the game plays.

    blender.exe --background --python blender/pig/anim/make_walk.py

WHAT THIS PRODUCES, AND WHICH HALF SHIPS TODAY.

  1. `walk_curve.lua`      -- the BODY's bob / pitch / roll / yaw over one
                              stride, sampled 24 times, in Roblox axes. This is
                              pasted into `Config.PIGGY_WALK.frames` and is what
                              `Shared/PiggyWalk` plays on the herd minis at run
                              time as a RIGID whole-model waddle. No upload.
  2. `pig_walk.blend`      -- the rigged pig with the cycle, for editing.
  3. `pig_walk.fbx`        -- armature + five skinned meshes + the cycle, for
                              the day a skeletal pig is IMPORTED through
                              Roblox's 3D importer (see README.md). Nothing
                              here uploads anything.
  4. `renders/walk_f*.png` -- four frames of the cycle, to LOOK at.

WHY THE SHIPPED HALF IS A WHOLE-MODEL CURVE AND NOT THE LEGS. A herd mini is
`PiggyModel.build`: a `Body` MeshPart, ONE merged `Trim` (ears, snout, legs and
tail welded into a single mesh) and two `Eye`s. There is no leg part to swing
-- `PiggyIdle` records the same finding. And a MeshPart made at run time by
`CreateMeshPartAsync` does not deform under bones (measured, twice), so the only
route to real leg motion is an IMPORTED skinned rig, which is a manual upload
under the developer's own account. That route is PREPARED here (the FBX) and
not taken.

THE SCENE IS `pig_parts.blend`, NEVER `pig.blend`. `build_pig.py` regenerates
the latter and destroys anything shaped by hand in it; the parts file is the
one "no generator ever overwrites". It is opened READ-ONLY here -- this script
saves to its own `anim/pig_walk.blend` and never back.

UNITS: `pig_parts.blend` is in the generator's units where 1 BU = 6 studs
(`SCALE = GAME_BODY_R / BODY_RX`), feet at z = -1.02. Everything is lifted so
the feet stand on z = 0 and scaled by 6 so 1 BU = 1 STUD before rigging, which
is what makes the FBX import at stud size with no scale option to remember.

AXES: Blender is Z-up with the snout at -Y (the generator's convention). Roblox
is Y-up with the snout at +Z; the FBX exporter's default (forward -Z, up Y)
sends blender (x, y, z) to (x, z, -y), the same map `build_pig.py`'s OBJ export
uses. The baked curve is converted to ROBLOX axes before it is written, so the
Lua reads straight: pitch about +X, yaw about +Y, roll about +Z (which is
MINUS the Blender rotation about Y, because Roblox Z = -Blender Y).

THE CYCLE. One stride = 24 frames at 24 fps (one second; the game maps stride
PHASE to distance travelled, so the fps is only a preview speed). A trot:
diagonal leg pairs swing together. The body bobs twice a stride, sways once,
nods twice and its rear swings once; the ears flap against the bob with a lag,
the tail wags twice. Every keyframe below is ONE stride, with frame 25 == frame
1 so the loop closes.

THE BOB IS NOT A SINE, ON PURPOSE. `PiggyIdle` was rewritten after a symmetric
sine read as "the piggies have 0 gravity": the same speed up as down, at rest
nowhere. The lift here leaves the ground FAST and lands FAST with the slow part
at the top -- quad ease-out rising, quad ease-in falling -- which is what a
mass on legs does.
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
import paths  # noqa: E402
import bpy, math, os, sys  # noqa: E402
from mathutils import Vector, Matrix, Euler  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_BLEND = os.path.join(HERE, "pig_walk.blend")
OUT_FBX = os.path.join(HERE, "pig_walk.fbx")
OUT_CURVE = os.path.join(HERE, "walk_curve.lua")

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
NO_RENDER = "--no-render" in argv

# ---------------------------------------------------------------- CONSTANTS
STUDS_PER_BU = 6.0        # build_pig.py: SCALE = GAME_BODY_R / BODY_RX = 6 / 1
LEG_BOTTOM_BU = -1.02     # build_pig.py: LEG_BOTTOM, the ground line
GAME_BODY_R = 6.0         # PiggyBank.BODY_R; the lift is baked in radii of this
FPS = 24
CYCLE = 24                # frames per stride
F0 = 1                    # first frame of the cycle
FMID = F0 + CYCLE // 2    # 13: the opposite foot plants
FQ1 = F0 + CYCLE // 4     # 7: legs pass, body at its highest
FQ3 = F0 + 3 * CYCLE // 4 # 19
FEND = F0 + CYCLE         # 25 == 1

# The performance, in degrees and studs (full-size pig, BODY_R = 6).
LEG_SWING = 22.0          # fore-aft swing of each leg, degrees
BOB = 0.28                # studs the body rises between plants (4.7% of R)
SWAY = 6.0                # roll toward the planted side, degrees
NOD = 2.0                 # pitch: nose dips on each plant, degrees
REAR_SWING = 3.0          # yaw: the rear swings once a stride, degrees
EAR_FLAP = 12.0           # ears flap against the bob, degrees
EAR_LAG = 3               # frames the ears trail the body
TAIL_WAG = 20.0           # degrees, twice a stride
SNOUT_NOD = 2.5           # degrees, trailing the body's nod

# ---------------------------------------------------------------- LOAD
bpy.ops.wm.open_mainfile(filepath=paths.PARTS)
scene = bpy.context.scene
scene.render.fps = FPS
scene.frame_start, scene.frame_end = F0, FEND - 1

PARTS = ("Body", "Snout", "Ears", "Legs", "Tail")
for ob in list(bpy.data.objects):
    if ob.name not in PARTS:
        bpy.data.objects.remove(ob, do_unlink=True)
parts = {n: bpy.data.objects[n] for n in PARTS}

# The Body carries an unapplied SUBSURF in the parts file; the shipped OBJ has
# the file's own 3176 vertices, so the modifier is dropped rather than baked.
for m in list(parts["Body"].modifiers):
    parts["Body"].modifiers.remove(m)

# Feet to the ground, then studs. Applied into the mesh data so the bind pose
# is clean numbers rather than an object transform the importer has to honour.
bpy.ops.object.select_all(action='DESELECT')
for ob in parts.values():
    ob.select_set(True)
    ob.location = Vector((0.0, 0.0, -LEG_BOTTOM_BU))
bpy.context.view_layer.objects.active = parts["Body"]
bpy.ops.object.transform_apply(location=True, rotation=True, scale=False)
for ob in parts.values():
    ob.scale = (STUDS_PER_BU,) * 3
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
for ob in parts.values():
    for vg in list(ob.vertex_groups):
        ob.vertex_groups.remove(vg)

def bounds(ob):
    xs = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    lo = Vector([min(v[i] for v in xs) for i in range(3)])
    hi = Vector([max(v[i] for v in xs) for i in range(3)])
    return lo, hi

blo, bhi = bounds(parts["Body"])
llo, lhi = bounds(parts["Legs"])
elo, ehi = bounds(parts["Ears"])
slo, shi = bounds(parts["Snout"])
tlo, thi = bounds(parts["Tail"])
assert abs(llo.z) < 1e-4, "feet are not on z = 0: %.4f" % llo.z
BODY_C = (blo + bhi) / 2.0
print("body centre (studs) %s   body extents %s .. %s" % (BODY_C, blo, bhi))

# ---------------------------------------------------------------- RIG
# Every bone is placed off the PARTS' OWN BOUNDS rather than typed, so a
# regenerated pig moves the rig with it. Bones point the way their part hangs:
# legs down, ears up, tail back, snout forward -- and the body bone points
# FORWARD (-Y), so that its local X is pitch, local Y is roll and local Z is
# yaw, which is what the curve keys are written against.
arm = bpy.data.armatures.new("PigRig")
rig = bpy.data.objects.new("PigRig", arm)
scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='EDIT')

def bone(name, head, tail, parent=None):
    eb = arm.edit_bones.new(name)
    eb.head, eb.tail = Vector(head), Vector(tail)
    eb.use_connect = False
    if parent:
        eb.parent = arm.edit_bones[parent]
    return eb

leg_top = lhi.z
leg_x = (llo.x + lhi.x) / 2.0 + (lhi.x - llo.x) / 4.0   # a leg's own centre
leg_front_y = llo.y + (lhi.y - llo.y) * 0.15
leg_back_y = lhi.y - (lhi.y - llo.y) * 0.15
ear_x = (ehi.x - elo.x) / 4.0
ear_y = (elo.y + ehi.y) / 2.0
snout_z = (slo.z + shi.z) / 2.0
tail_z = (tlo.z + thi.z) / 2.0

bone("root", (0, 0, 0), (0, 0, 1.0))
bone("body", BODY_C, BODY_C + Vector((0, -3.0, 0)), "root")
bone("snout", (0, blo.y + 1.2, snout_z), (0, slo.y, snout_z), "body")
bone("ear.L", (-ear_x, ear_y, elo.z), (-ear_x, ear_y, ehi.z), "body")
bone("ear.R", (ear_x, ear_y, elo.z), (ear_x, ear_y, ehi.z), "body")
bone("tail", (0, tlo.y, tail_z), (0, thi.y, tail_z), "body")
for side, sx in (("L", -1), ("R", 1)):
    for fb, ly in (("F", leg_front_y), ("B", leg_back_y)):
        bone("leg.%s%s" % (fb, side), (sx * leg_x, ly, leg_top), (sx * leg_x, ly, 0.0), "body")
bpy.ops.object.mode_set(mode='OBJECT')

# Rigid weights: every vertex 100% to one bone, which is exactly what the
# legendary skins' blend files carry and what a cartoon pig wants -- a leg is
# a cylinder that swings, not a thigh that bends.
def assign(ob, groups):
    """groups: list of (boneName, predicate(worldVertex) -> bool)."""
    mw = ob.matrix_world
    buckets = {name: [] for name, _ in groups}
    for v in ob.data.vertices:
        p = mw @ v.co
        for name, pred in groups:
            if pred(p):
                buckets[name].append(v.index)
                break
    for name, idx in buckets.items():
        vg = ob.vertex_groups.new(name=name)
        vg.add(idx, 1.0, 'REPLACE')
        print("  %-6s -> %-6s %5d verts" % (ob.name, name, len(idx)))
    mod = ob.modifiers.new("Armature", 'ARMATURE')
    mod.object = rig
    ob.parent = rig

assign(parts["Body"], [("body", lambda p: True)])
assign(parts["Snout"], [("snout", lambda p: True)])
assign(parts["Tail"], [("tail", lambda p: True)])
assign(parts["Ears"], [("ear.L", lambda p: p.x < 0), ("ear.R", lambda p: True)])
assign(parts["Legs"], [
    ("leg.FL", lambda p: p.x < 0 and p.y < 0), ("leg.BL", lambda p: p.x < 0),
    ("leg.FR", lambda p: p.y < 0), ("leg.BR", lambda p: True)])

# ---------------------------------------------------------------- THE CYCLE
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode='POSE')
pb = rig.pose.bones
for b in pb:
    b.rotation_mode = 'XYZ'

def key(bname, frame, rot=None, loc=None):
    b = pb[bname]
    if rot is not None:
        b.rotation_euler = Euler([math.radians(a) for a in rot], 'XYZ')
        b.keyframe_insert(data_path="rotation_euler", frame=frame)
    if loc is not None:
        b.location = Vector(loc)
        b.keyframe_insert(data_path="location", frame=frame)

def cyc(frame):
    """Wrap a frame into the cycle, so a lagged key past FEND lands early."""
    return F0 + (frame - F0) % CYCLE

# Legs: a trot. FL and BR swing together, FR and BL opposite. A bone pointing
# down has local X across the pig, so rotation about it is fore-aft.
for f, a in ((F0, +LEG_SWING), (FMID, -LEG_SWING), (FEND, +LEG_SWING)):
    key("leg.FL", f, rot=(a, 0, 0)); key("leg.BR", f, rot=(a, 0, 0))
    key("leg.FR", f, rot=(-a, 0, 0)); key("leg.BL", f, rot=(-a, 0, 0))

# The body bone: location Z in its own (bone) space is world Z, because the
# bone lies flat. Rotation: local X = pitch, local Y = roll, local Z = yaw.
#
# THE PITCH KEY IS NEGATED, AND THAT IS A MEASUREMENT RATHER THAN A GUESS. A
# bone pointing -Y with zero roll has its local X at MINUS world X, so a
# positive key about local X is a NEGATIVE rotation about world X -- and the
# first bake came back reading -2.00 at the plant, nose UP on the footfall,
# the reverse of what was asked. In Roblox a positive rotation about +X takes
# +Z (the snout) toward -Y, so nose DOWN is positive there; keying -NOD here
# is what lands +NOD in the table. The snout bone points -Y too and takes the
# same flip.
# Bob, twice a stride: down at every plant, up as the legs pass.
for f, z in ((F0, 0.0), (FQ1, BOB), (FMID, 0.0), (FQ3, BOB), (FEND, 0.0)):
    key("body", f, loc=(0, 0, z))
# Sway once, nod twice, rear swings once.
for f, (pitch, roll, yaw) in ((F0, (NOD, 0, 0)), (FQ1, (-NOD * 0.6, SWAY, REAR_SWING)),
                              (FMID, (NOD, 0, 0)), (FQ3, (-NOD * 0.6, -SWAY, -REAR_SWING)),
                              (FEND, (NOD, 0, 0))):
    key("body", f, rot=(-pitch, roll, yaw))

# Ears flap AGAINST the bob (the body rises, the ears lag and hang back),
# trailing by EAR_LAG frames. An ear bone points up, so local X is across the
# head and rotation about it flops the ear forward or back.
for f, a in ((F0, -EAR_FLAP), (FQ1, +EAR_FLAP), (FMID, -EAR_FLAP), (FQ3, +EAR_FLAP), (FEND, -EAR_FLAP)):
    key("ear.L", cyc(f + EAR_LAG), rot=(a, 0, 0))
    key("ear.R", cyc(f + EAR_LAG), rot=(a, 0, 0))
# The lagged keys leave the cycle's first and last frames unkeyed; close it.
for e in ("ear.L", "ear.R"):
    key(e, F0, rot=(-EAR_FLAP * 0.5, 0, 0)); key(e, FEND, rot=(-EAR_FLAP * 0.5, 0, 0))

# Tail wags twice a stride about its own up axis (the bone points back, so
# local Z is up).
for f, a in ((F0, +TAIL_WAG), (FQ1, -TAIL_WAG), (FMID, +TAIL_WAG), (FQ3, -TAIL_WAG), (FEND, +TAIL_WAG)):
    key("tail", f, rot=(0, 0, a))
# Snout nods with the body, a touch behind it.
for f, a in ((F0, SNOUT_NOD), (FQ1, -SNOUT_NOD), (FMID, SNOUT_NOD), (FQ3, -SNOUT_NOD), (FEND, SNOUT_NOD)):
    key("snout", cyc(f + 2), rot=(-a, 0, 0))
key("snout", F0, rot=(-SNOUT_NOD * 0.7, 0, 0)); key("snout", FEND, rot=(-SNOUT_NOD * 0.7, 0, 0))

bpy.ops.object.mode_set(mode='OBJECT')
action = rig.animation_data.action
action.name = "PigWalk"

# Every fcurve of an action, whichever way this Blender stores them: the
# legacy `action.fcurves` on a single-slot action, or the layered channelbag.
def fcurves_of(act):
    fcs = list(getattr(act, "fcurves", []) or [])
    if fcs:
        return fcs
    for layer in getattr(act, "layers", []):
        for strip in layer.strips:
            for bag in getattr(strip, "channelbags", []):
                fcs.extend(bag.fcurves)
    return fcs

# Easing. Everything is a smooth sine by default -- a swing, a sway, a wag all
# are -- and the BOB is the one curve shaped against gravity: quad ease-OUT
# leaving the ground (fast, then slowing into the top) and quad ease-IN
# landing (slow at the top, then fast into the plant).
for fc in fcurves_of(action):
    is_bob = fc.data_path.endswith('["body"].location') and fc.array_index == 2
    for kp in fc.keyframe_points:
        if is_bob:
            rising = kp.co.x in (float(F0), float(FMID))
            kp.interpolation = 'QUAD'
            kp.easing = 'EASE_OUT' if rising else 'EASE_IN'
        else:
            kp.interpolation = 'SINE'
            kp.easing = 'EASE_IN_OUT'

# ---------------------------------------------------------------- BAKE
# The body bone's pose relative to its rest, per frame, in WORLD axes, then
# converted to Roblox's. Read off the evaluated bone rather than off the keys,
# so what the game plays is what the graph editor shows.
rest = rig.matrix_world @ pb["body"].bone.matrix_local
rows = []
for f in range(F0, FEND + 1):
    scene.frame_set(f)
    world = rig.matrix_world @ pb["body"].matrix
    lift = world.translation.z - rest.translation.z
    R = world.to_3x3() @ rest.to_3x3().inverted()
    e = R.to_euler('XYZ')
    # Blender (x, y, z) -> Roblox (x, z, -y): pitch about X keeps its sign,
    # yaw about Blender Z is yaw about Roblox Y, roll about Blender Y is roll
    # about Roblox -Z, i.e. minus the angle about Roblox +Z.
    rows.append((f, lift, math.degrees(e.x), -math.degrees(e.y), math.degrees(e.z)))
scene.frame_set(F0)

first, last = rows[0], rows[-1]
for a, b, name in zip(first[1:], last[1:], ("lift", "pitch", "roll", "yaw")):
    assert abs(a - b) < 1e-4, "the cycle does not close on %s: %.4f vs %.4f" % (name, a, b)
peak = max(r[1] for r in rows)
assert abs(peak - BOB) < 0.02, "bob peak %.3f is not BOB %.3f" % (peak, BOB)
print("cycle closes; lift peak %.3f studs = %.4f R" % (peak, peak / GAME_BODY_R))

lines = ["-- Baked by blender/pig/anim/make_walk.py from the PigWalk action; do not",
         "-- hand-edit. One stride, %d samples, t = 0..1. `lift` is in BODY RADII" % CYCLE,
         "-- (a full pig's R is %.0f, a herd mini's is its Body's own half width);" % GAME_BODY_R,
         "-- angles are DEGREES about Roblox X (pitch, nose down +), Z (roll) and",
         "-- Y (yaw). Frame %d is frame %d again, so the last row repeats the first." % (FEND, F0),
         "frames = {"]
for f, lift, pitch, roll, yaw in rows[:-1]:
    t = (f - F0) / CYCLE
    lines.append("\t{ t = %.4f, lift = %.4f, pitch = %.2f, roll = %.2f, yaw = %.2f }," % (t, lift / GAME_BODY_R, pitch, roll, yaw))
lines.append("\t{ t = 1.0000, lift = %.4f, pitch = %.2f, roll = %.2f, yaw = %.2f }," % (rows[0][1] / GAME_BODY_R, rows[0][2], rows[0][3], rows[0][4]))
lines.append("},")
with open(OUT_CURVE, "w", newline="\n") as fh:
    fh.write("\n".join(lines) + "\n")
print("\n".join(lines))
print("curve -> %s" % OUT_CURVE)

# ---------------------------------------------------------------- LOOK
if not NO_RENDER:
    try:
        scene.render.engine = 'BLENDER_WORKBENCH'
    except TypeError as err:
        print("workbench refused: %s" % err)
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'MATERIAL'
    scene.render.resolution_x, scene.render.resolution_y = 640, 480
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    for ob in parts.values():
        for slot in ob.material_slots:
            if slot.material:
                pink = (0.93, 0.55, 0.65, 1.0) if ob.name == "Body" else (0.78, 0.36, 0.48, 1.0)
                slot.material.diffuse_color = pink
    # A ground plane so the feet have something to be seen against. Preview
    # only: removed before the save, never exported.
    bpy.ops.mesh.primitive_plane_add(size=80.0, location=(0.0, 0.0, 0.0))
    ground = bpy.context.active_object
    ground.name = "PreviewGround"
    gmat = bpy.data.materials.new("PreviewGround")
    gmat.diffuse_color = (0.45, 0.62, 0.36, 1.0)
    ground.data.materials.append(gmat)
    cam_data = bpy.data.cameras.new("WalkCam")
    cam = bpy.data.objects.new("WalkCam", cam_data)
    scene.collection.objects.link(cam)
    cam_data.lens = 45
    scene.camera = cam
    look = Vector((0.0, 0.0, 5.0))
    # The first frame is the 0.1 stud grazing test against the ground; the
    # three-quarter and the side each show a different half of the cycle --
    # the sway reads from the front, the leg swing from the side.
    for label, at in (("q", Vector((26.0, -30.0, 12.0))), ("s", Vector((40.0, 0.0, 7.0)))):
        cam.location = at
        cam.rotation_euler = (look - cam.location).to_track_quat('-Z', 'Y').to_euler()
        for f in (F0, FQ1, FMID, FQ3):
            scene.frame_set(f)
            scene.render.filepath = paths.render("walk_%s%02d.png" % (label, f))
            bpy.ops.render.render(write_still=True)
            print("render -> %s" % scene.render.filepath)
    scene.frame_set(F0)
    bpy.data.objects.remove(ground, do_unlink=True)
    bpy.data.objects.remove(cam, do_unlink=True)

# ---------------------------------------------------------------- SAVE + EXPORT
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
print("blend -> %s" % OUT_BLEND)

bpy.ops.object.select_all(action='DESELECT')
rig.select_set(True)
for ob in parts.values():
    ob.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.fbx(
    filepath=OUT_FBX,
    use_selection=True,
    object_types={'ARMATURE', 'MESH'},
    axis_forward='-Z', axis_up='Y',
    global_scale=1.0, apply_unit_scale=True, apply_scale_options='FBX_SCALE_ALL',
    use_mesh_modifiers=True, mesh_smooth_type='FACE',
    add_leaf_bones=False, use_armature_deform_only=True,
    bake_anim=True, bake_anim_use_all_actions=False, bake_anim_use_nla_strips=False,
    bake_anim_force_startend_keying=True, bake_anim_step=1.0, bake_anim_simplify_factor=0.0,
    path_mode='STRIP',
)
print("fbx -> %s  (%d bytes)" % (OUT_FBX, os.path.getsize(OUT_FBX)))
