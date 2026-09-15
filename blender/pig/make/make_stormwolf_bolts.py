# -*- coding: utf-8 -*-
"""The Storm Wolf's LIGHTNING: Neon bolt chains, in regions that flicker apart.

    blender --background --python make/make_stormwolf_bolts.py
    blender --background --python make/make_stormwolf_bolts.py -- --region crest

Writes one `.obj` per region into `pig/` plus `pig/pig_stormwolf_bolts.blend`.

WHY THIS IS NOT A TEXTURE, WHICH IS THE WHOLE REASON THE FILE EXISTS.
`CLAUDE.md` settles it twice over: a `SurfaceAppearance` HAS NO EMISSIVE
CHANNEL, and `Config.skinSurface` refuses `Neon` alongside a surface pack --
measured at 218/255 against a bloom threshold of 1.8. So a bolt painted into
Meshy's 4K colour map is a pale blue stripe on a rock and nothing more. Every
glowing thing in this game is GEOMETRY STANDING PROUD, and that is what this
builds.

WHY IT IS FOUR MESHES AND NOT ONE. The bolts have to FLICKER, and
`HouseFX.MAX_RATE` caps the whole game at three flashes a second -- in the
AGGREGATE, which is the half that bites. One mesh can only flash as a unit,
which is both duller than the reference and spends the entire budget on a
single event. Four regions phase against each other, so the animal crackles
continuously while no viewer ever sees more than three flashes a second.

WHY IT ANCHORS ON MEASURED TIPS RATHER THAN TYPED COORDINATES. A bolt has to
leave a crystal, and the crystals came out of a generator nobody here authored.
So the tips are FOUND -- a vertex standing further from the body's centre than
every neighbour within two edge rings -- and the regions are bands over those.
Re-generate the animal and the bolts follow it; type the coordinates and they
are wrong the first time anybody nudges the mesh.

THE ZIGZAG IS `PiggyModel.boltChain` PORTED, and deliberately so: kink
alternating each segment about one axis, length and width tapering by the same
ratio, the whole chain running along one direction rather than wandering. That
shape was arrived at after this project shipped bolts that read as cyan slabs,
then as spears, then as straight lines -- the note there is that ONE STRAIGHT
PIECE HAS NO JOINTS, and joints are the entire tell.

THIS IS A SECOND IMPLEMENTATION AND IT DECIDES NOTHING. The Luau is what ships
if the bolts are ever code-built; this is what gets uploaded if they ship as
meshes. Where the two disagree, measure the Luau.
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
import bpy, bmesh, math, random                           # noqa: E402
from mathutils import Vector, Matrix                      # noqa: E402

argv = _sys.argv[_sys.argv.index("--") + 1:] if "--" in _sys.argv else []


def arg(name, default):
    return argv[argv.index(name) + 1] if name in argv else default


SRC = paths.pig("pig_stormwolf_20k.blend")
ONLY = arg("--region", "")
SEED = int(arg("--seed", "7"))

# **HOW MANY INDEPENDENTLY-SWITCHABLE GROUPS THE BOLTS ARE DEALT INTO**, which
# is the flicker's whole resolution: one upload each, and one MeshPart each on
# every pig standing on the street. Four region meshes gave four on/off
# switches, so the crest lit as a slab and "not all of it at once" was
# unreachable however the toggle was driven. Six holds about six bolts apiece,
# scattered over the whole animal, which is enough that no two lit arrangements
# look alike and few enough that eight pigs cost 48 parts rather than 280.
PHASES = int(arg("--phases", "6"))

# **GAME SCALE, THE SAME DIVISOR EVERY OTHER EXPORT USES.** The body is 12.0
# studs across and the modelled animal is normalised to 2.0, so this is 6.0 --
# `export_whole.py` measures it the same way rather than pinning it.
GAME_BODY_X = 12.0


# --------------------------------------------------------------- the regions
#
# A band is where the bolts leave from and which way they go. `out` is added to
# the tip's own radial direction, in the pig's frame (+X across, -Y nose, +Z
# up), so a crest bolt can rise and rake backwards while an eye bolt spits
# forwards -- the reference has both, and one shared direction reads as a
# hedgehog.
#
# **A PICK IS IN NORMALISED COORDINATES, NEVER IN BLENDER UNITS, AND THE FIRST
# BUILD LEARNED THAT THE HARD WAY.** These thresholds were originally absolute
# -- `p.z > 1.82`, `p.z < 0.26` -- measured against a mesh whose feet sat at
# z 0. `make_stormwolf.py` then SEATED the animal properly, putting its floor on
# `pig_uv.UV_Z0` at -1.020 so the shared UV cylinder registers, and every one of
# those numbers was suddenly 1.02 studs out. It did not error: crest, face and
# tail silently matched NOTHING, hocks matched fourteen things that were not
# hocks, and the export cheerfully wrote a file.
#
# `n` is the tip in the animal's own box -- x in -1..1 across, y 0 at the snout
# and 1 at the tail, z 0 at the feet and 1 at the highest crystal. A pig that
# moves, grows or gets re-seated carries its regions with it.
#
# `every` thins the TIPS rather than the geometry: the crest alone carries
# fourteen crystals and a bolt on each is a comb, which is the note this
# project already has against the mohawk itself.
REGIONS = [
    dict(name="crest",
         pick=lambda n: n.z > 0.78 and abs(n.x) < 0.45,
         every=2, radial=0.34, out=Vector((0, 1.00, 0.30)), segs=6, total=0.44,
         width=0.055, kink=0.42, taper=0.74, thin=0.78, spread=0.18),
    dict(name="face",
         # The eye flare AND the ear tips: both sit forward of the shoulder and
         # both crackle in the reference, and they are close enough together
         # that flickering them apart would read as a fault rather than detail.
         pick=lambda n: (n.y < 0.19 and 0.42 < n.z < 0.67) or
                        (n.z > 0.83 and abs(n.x) > 0.45),
         # THE FACE RAKES BACK TOO, which reverses what it used to do. It spat
         # FORWARD off the eye flare -- correct if a bolt is being thrown, wrong
         # if it is being TRAILED, and the trailing read is the one that makes
         # the animal look like it is moving. A bolt streaming back over the ear
         # is also the one place the flow is most obvious, because there is a
         # whole head behind it for the eye to measure the sweep against.
         every=1, radial=0.42, out=Vector((0, 0.95, 0.28)), segs=5, total=0.38,
         width=0.038, kink=0.52, taper=0.70, thin=0.76, spread=0.24),
    dict(name="tail",
         pick=lambda n: n.y > 0.80 and n.z > 0.36,
         every=1, radial=0.50, out=Vector((0, 0.95, 0.20)), segs=5, total=0.40,
         width=0.048, kink=0.48, taper=0.72, thin=0.78, spread=0.22),
    dict(name="hocks",
         # The fetlocks. These are what the reference has spitting along the
         # GROUND, so they rake outward and down rather than away from centre.
         pick=lambda n: n.z < 0.12,
         every=3, radial=0.36, out=Vector((0, 0.90, -0.18)), segs=4, total=0.30,
         width=0.034, kink=0.55, taper=0.68, thin=0.74, spread=0.20,
         # **NOTHING BELOW THE FEET, WHICH IS A SEATING PROBLEM WEARING A
         # GEOMETRY DISGUISE.** The fetlock bolts hung up to 0.77 studs under
         # the hide's lowest point, and anything that seats this animal by its
         # MODEL bounding box then stands the whole pig on the lightning --
         # feet hovering, which is exactly what was reported.
         #
         # Seating per part off the hide's own floor is the real fix and is what
         # the Config offsets do. This is the belt to that pair of braces: a
         # bolt buried three quarters of a stud underground is invisible
         # anyway, so it costs nothing to keep them out of it, and it means a
         # future caller that DOES use the bounding box is merely slightly
         # wrong rather than visibly broken.
         nodip=True),
]


def find_tips(ob, merge=0.13):
    """Crystal tips: radius local maxima over two edge rings, thinned so one
    crystal contributes one tip rather than a cluster of near-equal ones."""
    me = ob.data
    M = ob.matrix_world
    co = [M @ v.co for v in me.vertices]
    ys = [c.y for c in co]
    zs = [c.z for c in co]
    centre = Vector((0.0, (min(ys) + max(ys)) / 2, (min(zs) + max(zs)) / 2))

    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()
    rad = [(c - centre).length for c in co]

    tips = []
    for v in bm.verts:
        ring = {e.other_vert(v).index for e in v.link_edges}
        two = set(ring)
        for i in ring:
            two |= {e.other_vert(bm.verts[i]).index
                    for e in bm.verts[i].link_edges}
        two.discard(v.index)
        if two and all(rad[v.index] > rad[j] for j in two):
            tips.append(v.index)
    bm.free()

    tips.sort(key=lambda i: -rad[i])
    keep = []
    for i in tips:
        if all((co[i] - co[j]).length > merge for j in keep):
            keep.append(i)

    # THE NORMALISED BOX, measured off the whole animal rather than off the
    # tips -- the tips do not reach the snout, so normalising over them would
    # put "the nose end" wherever the frontmost crystal happens to be.
    xs = [abs(c.x) for c in co]
    y0, y1 = min(c.y for c in co), max(c.y for c in co)
    z0, z1 = min(c.z for c in co), max(c.z for c in co)
    hx = max(xs) or 1.0

    def norm(c):
        return Vector((c.x / hx,
                       (c.y - y0) / ((y1 - y0) or 1.0),
                       (c.z - z0) / ((z1 - z0) or 1.0)))

    return [(co[i], (co[i] - centre).normalized(), norm(co[i]))
            for i in keep], centre


def add_bolt(bm, at, d0, spec, rng):
    """One chain, swept as a tapering ribbon along a zigzag polyline.

    A CONTINUOUS SWEEP RATHER THAN A ROW OF BOXES, which is the one place this
    departs from the Luau on purpose. `boltChain` emits separate Parts because
    Roblox has nothing else to emit; a mesh can carry the joints, so the ribbon
    is unbroken and there are no corner gaps to hide.

    THE RIBBON IS THIN ALONG THE KINK AXIS, so the flat of the blade CONTAINS
    the zigzag. Thin it the other way and every bolt is edge-on from the one
    angle a player is most likely to be standing at.

    **AND `thin` CANNOT GO MUCH BELOW ABOUT 0.7, WHICH THE FIRST RENDER SAID
    AND THE COMMENT ABOVE DID NOT.** The spin axis is RANDOM per bolt -- that
    is what stops neighbouring bolts zigzagging in one plane -- so with a flat
    enough ribbon some bolt is always presenting its edge to any given camera,
    and an edge-on ribbon is a straight white line with no joints in it. That
    is the exact failure this whole chain shape was built to fix, arriving from
    a direction the shape cannot help with. Measured at 0.42: one bolt in the
    hero shot read as a plain streak. Near-square reads as a bolt from every
    angle and costs nothing, because the cross-section is four verts either way.
    """
    segs = spec["segs"]
    taper = spec["taper"]

    # An axis perpendicular to the run, spun at random about it -- so two bolts
    # leaving neighbouring crystals do not zigzag in the same plane.
    tmp = Vector((0, 0, 1)) if abs(d0.z) < 0.9 else Vector((1, 0, 0))
    axis = d0.cross(tmp).normalized()
    axis = (Matrix.Rotation(rng.uniform(-math.pi, math.pi), 4, d0)
            @ axis).normalized()

    # The same closed form the Luau uses: a geometric run of segment lengths
    # summing to `total`, so tapering never changes how far a bolt reaches.
    if taper >= 0.999:
        seg0 = spec["total"] / segs
    else:
        seg0 = spec["total"] * (1 - taper) / (1 - taper ** segs)

    pts, widths = [at.copy()], [spec["width"]]
    p, L, w = at.copy(), seg0, spec["width"]
    for i in range(segs):
        sign = 1.0 if i % 2 == 0 else -1.0
        d = (Matrix.Rotation(spec["kink"] * sign, 4, axis) @ d0).normalized()
        p = p + d * L
        pts.append(p.copy())
        L *= taper
        w *= taper
        widths.append(w)

    tris = 0
    prev = None
    for i, (c, w) in enumerate(zip(pts, widths)):
        # The ring squares to the LOCAL run direction, so the ribbon does not
        # pinch where the chain changes its mind.
        if i == 0:
            run = (pts[1] - pts[0]).normalized()
        elif i == len(pts) - 1:
            run = (pts[-1] - pts[-2]).normalized()
        else:
            run = (pts[i + 1] - pts[i - 1]).normalized()
        wide = run.cross(axis).normalized()
        thin = axis * (w * spec["thin"])
        ring = [bm.verts.new(c + wide * w + thin),
                bm.verts.new(c + wide * w - thin),
                bm.verts.new(c - wide * w - thin),
                bm.verts.new(c - wide * w + thin)]
        if prev is not None:
            for a in range(4):
                b = (a + 1) % 4
                bm.faces.new((prev[a], prev[b], ring[b], ring[a]))
                tris += 2
        else:
            bm.faces.new(ring[::-1])
            tris += 2
        prev = ring
    bm.faces.new(prev)
    tris += 2
    return tris


def main():
    bpy.ops.wm.open_mainfile(filepath=SRC)
    ob = bpy.data.objects.get("StormWolf")
    if ob is None:
        raise SystemExit("  ! no StormWolf in %s -- run the retopo first" % SRC)

    tips, centre = find_tips(ob)
    print("  %d crystal tips found" % len(tips))

    # THE HIDE'S OWN FLOOR. Nothing may hang below it -- see `nodip`.
    FLOOR = min((ob.matrix_world @ v.co).z for v in ob.data.vertices)

    scale = GAME_BODY_X / ob.dimensions.x

    # ---- author every bolt, remembering only which region shaped it --------
    #
    # EACH BOLT GOES INTO ITS OWN bmesh FIRST, because grouping is a SHIPPING
    # decision and authoring is not. Keeping the two apart is what lets
    # `--phases` change without touching one number that decides how a bolt
    # looks.
    bolts = []
    dipped = [0]
    for spec in REGIONS:
        if ONLY and spec["name"] != ONLY:
            continue
        rng = random.Random(SEED + sum(ord(c) for c in spec["name"]))
        chosen = [t for t in tips if spec["pick"](t[2])][::spec["every"]]
        if not chosen:
            print("  ! %-6s NO TIPS MATCHED -- check the normalised band"
                  % spec["name"])
            continue
        for at, radial, _n in chosen:
            # **THE RADIAL IS WEIGHTED, AND AT 1.0 THE BOLTS STAND STRAIGHT UP.**
            # It used to be `radial + out`, so on the crest -- where the tip's
            # own radial is almost pure +Z -- a rake of 0.45 backwards against a
            # full-strength 1.0 upwards came out at 16 degrees off vertical.
            # Reported, correctly, as the lightning sticking straight up.
            #
            # A bolt TRAILS the thing it is attached to, which means the flow
            # along the body has to beat the surface normal rather than merely
            # nudge it. At 0.34 the radial says "leave the crystal here" and the
            # rake says "and go that way", which is the order those two facts
            # should be in.
            d = (radial * spec.get("radial", 1.0) + spec["out"]).normalized()
            # A little scatter per bolt, or a region reads as a rake.
            d = (d + Vector((rng.uniform(-1, 1), rng.uniform(-1, 1),
                             rng.uniform(-1, 1))) * spec["spread"] * 0.5
                 ).normalized()
            # CLAMPED AFTER THE SCATTER, NOT BEFORE IT. The scatter is where a
            # downward aim actually comes from -- the band's own `out` is only
            # -0.18 -- so clamping the authored direction would have looked
            # right and changed nothing.
            if spec.get("nodip") and d.z < 0.02:
                d = Vector((d.x, d.y, 0.02)).normalized()
            bm = bmesh.new()
            # Start just INSIDE the crystal so the bolt grows out of it rather
            # than floating off the point of it.
            tris = add_bolt(bm, at - d * 0.035, d, spec, rng)

            # **CLAMPED ON THE GEOMETRY, AND CLAMPING THE DIRECTION WAS NOT
            # ENOUGH.** Aiming a fetlock bolt level still put 0.47 studs of it
            # underground, because the KINK is what dips: segments alternate
            # +-0.55 radians about a random axis, which swings one 31 degrees
            # off the run whatever the run is. A mean direction cannot answer
            # that; only the vertices can.
            #
            # Applied to EVERY band rather than only the hocks. It is a no-op
            # anywhere else -- a crest bolt is eight studs clear -- and a global
            # floor is one rule instead of a flag somebody has to remember to
            # set on the next band that happens to sit low.
            _clamped = 0
            for _v in bm.verts:
                if _v.co.z < FLOOR:
                    _v.co.z = FLOOR
                    _clamped += 1
            if _clamped:
                dipped[0] += 1

            bolts.append((spec["name"], bm, tris))
        print("  %-6s %2d bolts authored" % (spec["name"], len(chosen)))

    if not bolts:
        raise SystemExit("  ! no bolts built -- every region matched nothing")
    print("  floor: %d of %d bolts had geometry lifted out of the ground"
          % (dipped[0], len(bolts)))

    # ---- deal them round-robin, WITHIN each region -------------------------
    #
    # Round-robin over the flat list would only spread evenly while the regions
    # happened to be the same size. Dealt within each region, every group holds
    # a share of the crest AND the face AND the tail AND the hocks by
    # construction rather than by luck -- which is the whole point of grouping
    # by phase instead of by place.
    groups = [[] for _ in range(PHASES)]
    seen = {}
    for name, bm, tris in bolts:
        k = seen.get(name, 0)
        seen[name] = k + 1
        groups[k % PHASES].append((name, bm, tris))

    made = []
    for gi, group in enumerate(groups):
        if not group:
            continue
        out_bm = bmesh.new()
        tris = 0
        mix = {}
        dropped = 0
        for name, bm, t in group:
            # **KEYED ON THE VERTEX, NEVER ON `v.index`, AND THAT COST A WHOLE
            # BUILD.** A bmesh assembled with `verts.new` carries index -1 on
            # every vertex until something calls `index_update()`, so a map
            # keyed on the index has ONE entry: -1, pointing at whichever
            # vertex was created last. Every face then asked for four copies of
            # that one vertex, `faces.new` correctly refused the degenerate
            # face, and the `except ValueError: pass` below swallowed all
            # thirty-six of them.
            #
            # It did not error and it did not look wrong in any log: the groups
            # reported the right BOLT and TRIANGLE counts, because those are
            # counted from the source meshes rather than from the merge. Only
            # probing the saved blend said 168 verts and ZERO tris -- a number
            # that does not change when it should, one more time.
            vmap = {v: out_bm.verts.new(v.co) for v in bm.verts}
            for f in bm.faces:
                try:
                    out_bm.faces.new([vmap[v] for v in f.verts])
                except ValueError:
                    # A genuine duplicate face is possible where two bolts
                    # overlap exactly. It is also what a broken map looks like,
                    # so it is COUNTED and reported rather than passed over.
                    dropped += 1
            bm.free()
            tris += t
            mix[name] = mix.get(name, 0) + 1

        nm = "Bolts_p%d" % gi
        me = bpy.data.meshes.new(nm)
        out_bm.to_mesh(me)
        out_bm.free()
        # THE MERGE IS CHECKED RATHER THAN ASSUMED, for the reason
        # `export_whole.py` checks its join: an operation that reports success
        # having done nothing is the failure this project keeps paying for.
        got = sum(len(p.vertices) - 2 for p in me.polygons)
        if got != tris or dropped:
            raise SystemExit("  ! %s merged to %d tris, expected %d (%d faces "
                             "refused) -- the vertex map is wrong"
                             % (nm, got, tris, dropped))
        bo = bpy.data.objects.new(nm, me)
        bpy.context.scene.collection.objects.link(bo)
        made.append((nm, bo, len(group), tris))
        print("  %-10s %2d bolts  %4d tris   %s"
              % (nm, len(group), tris,
                 " ".join(k + ":" + str(v) for k, v in sorted(mix.items()))))

    # ---- export, one mesh per GROUP so each is its own MeshPart ------------
    for name, bo, nb, tris in made:
        bpy.ops.object.select_all(action="DESELECT")
        bo.select_set(True)
        bpy.context.view_layer.objects.active = bo
        out = paths.pig("pig_stormwolf_" + name.lower() + ".obj")
        bpy.ops.wm.obj_export(filepath=out,
                              export_selected_objects=True,
                              forward_axis="NEGATIVE_Z", up_axis="Y",
                              global_scale=scale,
                              export_materials=False,
                              export_normals=True,
                              export_uv=False,
                              export_triangulated_mesh=True)
        print("  wrote %s" % _os.path.relpath(out, _root))

    # ---- the eyes, which glow with the storm rather than with the hide -----
    #
    # **WHERE THEY ARE WAS MEASURED OFF MESHY'S OWN PAINT, NOT EYEBALLED.** The
    # texture stage painted the eyeballs near-white on a near-black animal, so
    # sampling that map at every vertex and keeping the bright, DESATURATED ones
    # on the front half isolates them. Single-link clustering at 0.10 then
    # returns four groups: two at z -0.045 which are the nostrils, and two at
    # z +0.248 with a reach of 0.058 which are the eyes.
    #
    # A LEFT/RIGHT SPLIT WAS TRIED FIRST AND IS NOT A CLUSTER -- it lumps an
    # eyeball in with every stray highlight on that side and reported a "reach"
    # of 1.435 studs on a 0.12-stud eye.
    #
    # Those two clusters are also what found the animal off its own axis: both
    # pairs shared a midpoint of x -0.115 rather than 0. Recentred, they are
    # symmetric at x +-0.386, which is the number below.
    #
    # PINNED WITH A SURFACE CHECK, because re-running the texture sample needs
    # the 4K map and the pre-retopo blend. If the animal is regenerated this
    # reports rather than silently seating an eye in mid-air.
    EYE_X, EYE_Y, EYE_Z, EYE_R = 0.386, -1.135, 0.248, 0.075

    import mathutils
    _bvh = mathutils.bvhtree.BVHTree.FromObject(ob, bpy.context.evaluated_depsgraph_get())
    eye_bm = bmesh.new()
    for sx in (-1.0, 1.0):
        at = Vector((sx * EYE_X, EYE_Y, EYE_Z))
        hit, nor, idx, dist = _bvh.find_nearest(at)
        if hit is None or dist > EYE_R * 1.6:
            raise SystemExit("  ! eye at %s is %.3f from the hide -- the "
                             "landmark has drifted, re-run the texture sample"
                             % (tuple(round(v, 3) for v in at),
                                dist if hit is not None else -1))
        bmesh.ops.create_uvsphere(eye_bm, u_segments=12, v_segments=8,
                                  radius=EYE_R,
                                  matrix=mathutils.Matrix.Translation(at))
    eye_me = bpy.data.meshes.new("Bolts_eyes")
    eye_bm.to_mesh(eye_me)
    eye_bm.free()
    eye_ob = bpy.data.objects.new("Bolts_eyes", eye_me)
    bpy.context.scene.collection.objects.link(eye_ob)
    _et = sum(len(p.vertices) - 2 for p in eye_me.polygons)
    print("  %-10s  2 eyes  %4d tris   at x +-%.3f, seated on the hide"
          % ("Bolts_eyes", _et, EYE_X))

    bpy.ops.object.select_all(action="DESELECT")
    eye_ob.select_set(True)
    bpy.context.view_layer.objects.active = eye_ob
    _eo = paths.pig("pig_stormwolf_bolts_eyes.obj")
    bpy.ops.wm.obj_export(filepath=_eo, export_selected_objects=True,
                          forward_axis="NEGATIVE_Z", up_axis="Y",
                          global_scale=scale, export_materials=False,
                          export_normals=True, export_uv=False,
                          export_triangulated_mesh=True)
    print("  wrote %s" % _os.path.relpath(_eo, _root))

    bpy.ops.wm.save_as_mainfile(filepath=paths.pig("pig_stormwolf_bolts.blend"))
    print("  scale %.4f  (body %.2f studs across)" % (scale, GAME_BODY_X))


main()
